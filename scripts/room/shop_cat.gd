class_name ShopCat
extends Node3D
## El gato de la tienda (art/models/cat.glb, de art/blender/make_cat.py), atigrado y tranquilo. Vive por
## toda la sala mientras el jugador ordena, sin estorbar: juega con un ovillo (le da un zarpazo, el ovillo
## rueda y lo persigue al trote), pasea, se sienta a lavarse, amasa, se estira, se tumba y se revuelca panza
## arriba, le dan carreras locas de vez en cuando y se echa la siesta. Solo pisa suelo libre (no
## cruza muebles ni montones de objetos) y se aparta si el jugador se le echa encima. Con las manos
## vacías se le puede acariciar (E): se sienta, cierra los ojos, frota la cabeza y ronronea.
## Va en coordenadas de la sala (es hijo de RoomShell). No tiene cuerpo físico: no bloquea ni empuja nada.
## Animaciones: un AnimationTree con una transición entre poses (paso, trote, de pie, sentado, aseo,
## siesta, caricia, tumbado, revolcarse, estirarse, amasar y galope), el zarpazo encima y, más arriba,
## parpadeo y sacudidas de oreja (filtrados).

const MODEL := "res://art/models/cat.glb"
## El ovillo es uno de los de la tienda: su modelo y el material de su lana.
const YARN_MODEL := "res://art/models/yarn_ball.glb"
const YARN_ITEM := "res://data/items/yarn_red.tres"
const YARN_RADIUS := 0.055
## Donde queda el ovillo respecto al gato sentado para el zarpazo (delante de la pata derecha).
const YARN_AT := Vector3(-0.04, 0.0, 0.27)
## El zarpazo dura 2 s y la pata toca el ovillo a los 13 de sus 24 fotogramas.
const BAT_PERIOD := 2.0
const BAT_TOUCH := 13.0 / 24.0 * BAT_PERIOD
const WALK_SPEED := 0.38
const TROT_SPEED := 0.85
## Carrera loca: galope por la sala, solo con el jugador lejos.
const ZOOM_SPEED := 2.1
const ZOOM_CLEAR := 2.2
## El estiramiento dura sus 30 fotogramas a 12 fps.
const STRETCH_TIME := 2.5
const TURN_SPEED := 5.0
## Distancia al jugador a la que se aparta (si no está dormido ni le están acariciando).
const PERSONAL_SPACE := 0.5
## Margen alrededor de los muebles para el gato y el ovillo.
const CAT_MARGIN := 0.16
const TWITCH_GAP := Vector2(6.0, 10.0)
const BLINK_GAP := Vector2(2.5, 6.0)
const PET_TIME := 3.2
const NAME := "Botón, el gato de la tienda"
const LOOPS := [&"walk", &"trot", &"stand", &"sit", &"groom", &"sleep", &"pet", &"lie", &"roll", &"stretch", &"knead", &"gallop"]
## Poses con los ojos cerrados o entornados (no parpadea).
const EYES_SHUT := [&"sleep", &"pet", &"roll", &"knead", &"stretch"]

## Lo que está haciendo (para las pruebas y para depurar).
var activity := &"sit"
var pets := 0

var _shell: RoomShell
var _anim: AnimationPlayer
var _tree: AnimationTree
var _pose := &""
var _yarn: Node3D
var _yarn_tween: Tween
var _move_to := Vector3.INF
var _speed := 0.0
var _arrived := false
var _gen := 0
var _player: Node3D
var _petting := false
var _pet_until := 0.0
var _purr: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_shell = get_parent() as RoomShell
	_rng.randomize()
	if not ResourceLoader.exists(MODEL):
		push_warning("Falta %s (ejecuta art/blender/make_cat.py)" % MODEL)
		return
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(model)
	_add_yarn()
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		_build_tree()
	_add_pet_area()
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.3, 0.0, -0.4), Vector3(0.6, 0.55, 0.8))
	notifier.screen_entered.connect(func(): _set_animating(true))
	notifier.screen_exited.connect(func(): _set_animating(false))
	add_child(notifier)
	_set_animating(false)
	_set_pose(&"sit")
	_life.call_deferred()


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _move_to != Vector3.INF:
		var to := _move_to - position
		to.y = 0.0
		var dist := to.length()
		var step := _speed * delta
		if dist <= step:
			position = Vector3(_move_to.x, position.y, _move_to.z)
			_move_to = Vector3.INF
			_arrived = true
		else:
			position += to / dist * step
			_face(to, delta)
	# Si el jugador se le echa encima andando, se aparta (no si duerme o le están acariciando; acercarse
	# despacio para acariciarlo no lo espanta).
	if _player != null and _shell != null and not _petting and activity != &"sleep" and activity != &"dodge":
		var away := position - _shell.to_local(_player.global_position)
		away.y = 0.0
		var body := _player as CharacterBody3D
		var vel := _shell.global_basis.inverse() * body.velocity if body != null else Vector3.ZERO
		vel.y = 0.0
		if away.length() < PERSONAL_SPACE and vel.length() > 1.2 and vel.dot(away) > 0.0:
			_dodge(away)


# --- Lo que hace -----------------------------------------------------------

## Bucle de vida: elige algo que hacer, lo hace y vuelve a elegir. Una caricia o un susto lo cortan
## (cambia _gen) y lo vuelven a empezar.
func _life() -> void:
	_gen += 1
	var gen := _gen
	_unstick()
	await _wait(_rng.randf_range(0.5, 2.0))
	while gen == _gen and is_inside_tree():
		var r := _rng.randf()
		if r < 0.32:
			await _play_with_yarn(gen)
		elif r < 0.46:
			await _wander(gen)
		elif r < 0.55:
			await _groom(gen)
		elif r < 0.67:
			await _lounge(gen)
		elif r < 0.75:
			await _knead(gen)
		elif r < 0.81 and not _player_near(ZOOM_CLEAR):
			await _zoomies(gen)
		elif r < 0.9 and not _player_near(1.6):
			await _nap(gen)
		else:
			activity = &"sit"
			_set_pose(&"sit")
			await _wait(_rng.randf_range(4.0, 8.0))


## Juega con el ovillo: va hasta él (al trote si está lejos), se sienta, le da un zarpazo y el ovillo
## rueda; lo mira un momento y repite unas cuantas veces.
func _play_with_yarn(gen: int) -> void:
	if _yarn == null:
		return
	for _i in _rng.randi_range(2, 4):
		if gen != _gen:
			return
		activity = &"chase"
		var ball := _yarn.position
		ball.y = 0.0
		# Sitio junto al ovillo, al otro lado de donde hay sitio para que ruede.
		var spot := _kick_spot(ball)
		if spot == Vector3.INF:
			_yarn_home()
			return
		var far := position.distance_to(spot) > 1.0
		if not await _go_route(spot, TROT_SPEED if far else WALK_SPEED, &"trot" if far else &"walk", gen):
			return
		await _turn_to(ball, gen)
		if gen != _gen:
			return
		activity = &"bat"
		_set_pose(&"sit")
		await _wait(0.4)
		if gen != _gen:
			return
		_tree.set(&"parameters/bat/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		await _wait(BAT_TOUCH)
		if gen != _gen:
			return
		_kick_yarn()
		await _wait(BAT_PERIOD - BAT_TOUCH + _rng.randf_range(0.6, 1.6))


## Dónde sentarse para lanzar el ovillo: detrás de él respecto a una dirección con suelo libre por
## delante (para que ruede) y a la que se pueda llegar. Prefiere las del lado en el que ya está.
func _kick_spot(ball: Vector3) -> Vector3:
	var from := position - ball
	from.y = 0.0
	var base := atan2(-from.x, -from.z) if from.length() > 0.05 else _rng.randf() * TAU
	for k in 12:
		var a := base + (k + 1) / 2 * 0.55 * (1.0 if k % 2 == 0 else -1.0)
		var d := Vector3.BACK.rotated(Vector3.UP, a)
		var spot := ball - d * YARN_AT.z
		if _clear(ball, ball + d * 0.8, 0.1) and not _route(position, spot).is_empty():
			return Vector3(spot.x, 0.0, spot.z)
	return Vector3.INF


func _wander(gen: int) -> void:
	activity = &"wander"
	var to := _free_point(1.2, 3.5)
	if to == Vector3.INF:
		return
	if not await _go_route(to, WALK_SPEED, &"walk", gen):
		return
	activity = &"stand"
	_set_pose(&"stand")
	await _wait(_rng.randf_range(1.0, 2.5))
	# A veces, al pararse, se estira.
	if gen == _gen and _rng.randf() < 0.4:
		await _stretch(gen)


## Se estira con el culete en alto y vuelve a quedarse de pie.
func _stretch(gen: int) -> void:
	activity = &"stretch"
	_set_pose(&"stand")
	await _wait(0.3)
	if gen != _gen:
		return
	_set_pose(&"stretch")
	await _wait(STRETCH_TIME - 0.1)
	if gen == _gen:
		_set_pose(&"stand")
		await _wait(0.6)


## Se tumba de lado y se revuelca panza arriba un rato; luego se vuelve a sentar.
func _lounge(gen: int) -> void:
	activity = &"wander"
	var to := _free_point(0.6, 2.5)
	if to != Vector3.INF and not await _go_route(to, WALK_SPEED, &"walk", gen):
		return
	activity = &"lie"
	_set_pose(&"sit")
	await _wait(0.8)
	if gen != _gen:
		return
	_set_pose(&"lie")
	await _wait(_rng.randf_range(2.5, 4.5))
	for _i in _rng.randi_range(1, 2):
		if gen != _gen:
			return
		activity = &"roll"
		_set_pose(&"roll")
		await _wait(_rng.randf_range(3.0, 6.0))
		if gen != _gen:
			return
		activity = &"lie"
		_set_pose(&"lie")
		await _wait(_rng.randf_range(2.0, 4.0))
	if gen == _gen:
		_set_pose(&"sit")
		await _wait(1.2)


## Amasa sentado, con los ojos entornados.
func _knead(gen: int) -> void:
	activity = &"knead"
	_set_pose(&"sit")
	await _wait(0.6)
	if gen != _gen:
		return
	_set_pose(&"knead")
	await _wait(_rng.randf_range(4.0, 7.0))
	if gen == _gen:
		_set_pose(&"sit")
		await _wait(1.0)


## Carrera loca: galopa por tres o cuatro sitios libres de la sala, se para en seco y se lava, como si
## no hubiera pasado nada. Se corta si el jugador se acerca.
func _zoomies(gen: int) -> void:
	activity = &"zoomies"
	for _i in _rng.randi_range(3, 4):
		if gen != _gen or _player_near(1.4):
			break
		var to := _free_point(1.5, 4.0)
		if to == Vector3.INF or not await _go_route(to, ZOOM_SPEED, &"gallop", gen):
			break
	if gen != _gen:
		return
	_set_pose(&"sit")
	await _wait(0.8)
	if gen == _gen:
		await _groom(gen)


func _groom(gen: int) -> void:
	activity = &"groom"
	_set_pose(&"groom")
	await _wait(_rng.randf_range(4.5, 7.5))
	if gen == _gen:
		_set_pose(&"sit")
		await _wait(1.0)


func _nap(gen: int) -> void:
	activity = &"sleep"
	_set_pose(&"sit")
	await _wait(1.2)
	if gen != _gen:
		return
	_set_pose(&"sleep")
	await _wait(_rng.randf_range(18.0, 35.0))
	if gen == _gen:
		_set_pose(&"sit")
		await _wait(1.5)
	# Al despertar se estira.
	if gen == _gen:
		await _stretch(gen)


## Se aparta del jugador: un trotecito hacia el lado contrario.
func _dodge(away: Vector3) -> void:
	_gen += 1
	var gen := _gen
	activity = &"dodge"
	var dir := away.normalized() if away.length() > 0.05 else Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
	var to := Vector3.INF
	for k in 7:
		var a := (k + 1) / 2 * 0.5 * (1.0 if k % 2 == 0 else -1.0)
		var cand := position + dir.rotated(Vector3.UP, a) * 0.9
		if _clear(position, cand):
			to = cand
			break
	if to != Vector3.INF:
		await _go(to, TROT_SPEED, &"trot", gen)
	if gen == _gen:
		_life()


# --- Caricias --------------------------------------------------------------

func interact_info() -> Dictionary:
	return {"key": "E", "action": "Acariciar", "title": NAME, "detail": "", "hint": "", "kind": "pick"}


## E con las manos vacías apuntando al gato: se para, se sienta mirando al jugador y ronronea.
func interact(_holder = null) -> void:
	pets += 1
	Events.cat_petted.emit()
	_hearts()
	_pet_until = Time.get_ticks_msec() / 1000.0 + PET_TIME
	if _petting:
		return
	_petting = true
	_gen += 1
	var gen := _gen
	_move_to = Vector3.INF
	activity = &"pet"
	if _tree != null:
		_tree.set(&"parameters/bat/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if _player != null and _shell != null:
		var p := _shell.to_local(_player.global_position)
		var to := p - position
		to.y = 0.0
		if to.length() > 0.05:
			rotation.y = atan2(to.x, to.z)
	_set_pose(&"pet")
	AudioManager.play(&"cat_mrrp", global_position + Vector3.UP * 0.3, -4.0, 0.08)
	_start_purr()
	while gen == _gen and Time.get_ticks_msec() / 1000.0 < _pet_until:
		await _wait(0.25)
	_stop_purr()
	_petting = false
	if gen == _gen:
		_set_pose(&"sit")
		await _wait(1.2)
		if gen == _gen:
			_life()


func is_petting() -> bool:
	return _petting


## Dos o tres corazoncitos que suben y se desvanecen sobre su cabeza.
func _hearts() -> void:
	for k in _rng.randi_range(2, 3):
		var h := Label3D.new()
		h.text = "♥"
		h.font_size = 96
		h.pixel_size = 0.0011
		h.modulate = Color("f08a9c")
		h.outline_size = 10
		h.outline_modulate = Color(1, 1, 1, 0.8)
		h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		h.no_depth_test = false
		h.position = Vector3(_rng.randf_range(-0.07, 0.07), 0.42, 0.12)
		h.scale = Vector3.ONE * 0.4
		add_child(h)
		var tw := h.create_tween().set_parallel(true)
		var d := 0.12 * k
		tw.tween_property(h, "scale", Vector3.ONE, 0.25).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "position:y", h.position.y + 0.28, 1.3).set_delay(d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "modulate:a", 0.0, 0.6).set_delay(d + 0.7).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(h.queue_free)


## Volumen de cada ronroneo, igualados por su nivel medido (el segundo tiene unos 6 dB menos de RMS).
const PURR_DB := [-5.0, 0.0]


func _start_purr() -> void:
	if _purr == null:
		_purr = AudioStreamPlayer3D.new()
		_purr.name = "Purr"
		_purr.bus = &"SFX"
		_purr.unit_size = 2.0
		_purr.max_distance = 8.0
		_purr.position = Vector3(0.0, 0.3, 0.1)
		add_child(_purr)
	# Ronroneos grabados de gatos de verdad (art/audio/sfx/cat_purr_*.wav); el segundo es algo más flojo.
	var v := randi() % maxi(AudioManager.variant_count(&"cat_purr"), 1)
	var stream := AudioManager.get_stream(&"cat_purr", v)
	if stream == null:
		return
	_purr.stream = stream
	_purr.volume_db = -30.0
	_purr.play(randf() * 1.5)
	var tw := create_tween()
	tw.tween_property(_purr, "volume_db", PURR_DB[mini(v, PURR_DB.size() - 1)], 0.5).set_trans(Tween.TRANS_SINE)


func _stop_purr() -> void:
	if _purr == null or not _purr.playing:
		return
	var tw := create_tween()
	tw.tween_property(_purr, "volume_db", -40.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_purr.stop)


func _add_pet_area() -> void:
	var area := Area3D.new()
	area.name = "PetArea"
	area.collision_layer = ItemHolder.MASK_PICK
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.42, 0.55)
	cs.shape = box
	cs.position = Vector3(0.0, 0.21, 0.02)
	area.add_child(cs)
	add_child(area)


# --- Movimiento ------------------------------------------------------------

## Va andando (o al trote) hasta `to`. Devuelve false si algo lo interrumpe por el camino.
func _go(to: Vector3, speed: float, pose: StringName, gen: int) -> bool:
	_move_to = Vector3(to.x, 0.0, to.z)
	_speed = speed
	_arrived = false
	_set_pose(pose)
	while gen == _gen and not _arrived:
		await get_tree().process_frame
	if gen != _gen:
		return false
	return true


## Como _go, pero si no hay camino recto (una mesa en medio) da un rodeo por un punto intermedio.
func _go_route(to: Vector3, speed: float, pose: StringName, gen: int) -> bool:
	var route := _route(position, to)
	if route.is_empty():
		return false
	for p in route:
		if not await _go(p, speed, pose, gen):
			return false
	return true


## Camino de `a` a `b` por suelo libre: recto o con un punto intermedio. Vacío si no lo encuentra.
func _route(a: Vector3, b: Vector3) -> Array[Vector3]:
	if _clear(a, b):
		return [b]
	var mid := (a + b) * 0.5
	var span := a.distance_to(b)
	for attempt in 32:
		var m := mid + Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU) * _rng.randf_range(0.3, maxf(span, 1.0))
		m.y = 0.0
		if _clear(a, m) and _clear(m, b):
			return [m, b]
	return []


func _turn_to(target: Vector3, gen: int) -> void:
	var to := target - position
	to.y = 0.0
	if to.length() < 0.01:
		return
	var goal := atan2(to.x, to.z)
	var t := 0.0
	while gen == _gen and absf(angle_difference(rotation.y, goal)) > 0.05 and t < 1.0:
		rotation.y = lerp_angle(rotation.y, goal, 1.0 - exp(-TURN_SPEED * get_process_delta_time()))
		t += get_process_delta_time()
		await get_tree().process_frame


func _face(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-TURN_SPEED * 1.6 * delta))


## Punto libre al azar entre `near` y `far` metros, al que se puede llegar (recto o con un rodeo).
func _free_point(near: float, far: float) -> Vector3:
	for attempt in 24:
		var cand := position + Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU) * _rng.randf_range(near, far)
		if not _route(position, cand).is_empty():
			return Vector3(cand.x, 0.0, cand.z)
	return Vector3.INF


## Sitio libre cerca de `want` con camino despejado (y sin pisar `avoid`, el ovillo).
func _free_near(want: Vector3, avoid: Vector3) -> Vector3:
	for k in 9:
		var a := (k + 1) / 2 * 0.7 * (1.0 if k % 2 == 0 else -1.0)
		var cand := avoid + (want - avoid).rotated(Vector3.UP, a)
		if not _route(position, cand).is_empty():
			return Vector3(cand.x, 0.0, cand.z)
	return Vector3.INF


## ¿Se puede ir de `a` a `b` (coordenadas de la sala) sin cruzar muebles ni objetos sueltos?
func _clear(a: Vector3, b: Vector3, margin: float = CAT_MARGIN) -> bool:
	if _shell == null:
		return false
	var b2 := Vector2(b.x, b.z)
	if not _shell.floor_bounds.has_point(b2):
		return false
	var steps := maxi(1, ceili(a.distance_to(b) / 0.12))
	# El punto de salida no cuenta: si está pegado a un mueble, al menos puede alejarse.
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if _shell.is_blocked(Vector2(p.x, p.z), margin):
			return false
	# Objetos sueltos por el suelo (y paredes o patas): un barrido con una esfera a ras de suelo.
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = margin * 0.8
	q.shape = sphere
	q.collision_mask = 1 | 2
	var from := _shell.to_global(Vector3(a.x, margin + 0.02, a.z))
	var to := _shell.to_global(Vector3(b.x, margin + 0.02, b.z))
	q.transform = Transform3D(Basis(), from)
	q.motion = to - from
	var res := space.cast_motion(q)
	return res.is_empty() or res[0] >= 1.0


## Si está en un sitio que cuenta como mueble (al empezar, o los muebles han cambiado), salta al suelo
## libre más cercano para no quedarse encerrado.
func _unstick() -> void:
	if _shell == null or not _shell.is_blocked(Vector2(position.x, position.z), CAT_MARGIN):
		return
	for r: float in [0.3, 0.6, 0.9, 1.2, 1.6, 2.0, 2.5]:
		for k in 16:
			var cand := position + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0) * r
			var c2 := Vector2(cand.x, cand.z)
			if _shell.floor_bounds.has_point(c2) and not _shell.is_blocked(c2, CAT_MARGIN + 0.05):
				position = Vector3(cand.x, 0.0, cand.z)
				if _yarn != null:
					_yarn.position = position + YARN_AT.rotated(Vector3.UP, rotation.y) + Vector3(0.0, YARN_RADIUS, 0.0)
				return


func _player_near(dist: float) -> bool:
	if _player == null or _shell == null:
		return false
	return _shell.to_local(_player.global_position).distance_to(position) < dist


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


# --- El ovillo -------------------------------------------------------------

func _add_yarn() -> void:
	if not ResourceLoader.exists(YARN_MODEL):
		return
	var ball := (load(YARN_MODEL) as PackedScene).instantiate() as Node3D
	_yarn = Node3D.new()
	_yarn.name = "CatYarn"
	_yarn.add_child(ball)
	ball.position = Vector3(0.0, -YARN_RADIUS, 0.0)
	var data := load(YARN_ITEM) as ItemData
	if data != null:
		var mat := data.get_material()
		for mi in ball.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
	# Hermano del gato (en la sala), no hijo: rueda por su cuenta.
	_yarn.position = position + YARN_AT.rotated(Vector3.UP, rotation.y) + Vector3(0.0, YARN_RADIUS, 0.0)
	_yarn.rotation = Vector3(0.3, 1.1, 0.0)
	get_parent().add_child.call_deferred(_yarn)


## El zarpazo lanza el ovillo: rueda 0,8–1,8 m hacia delante (con algo de ángulo) por suelo libre y frena.
func _kick_yarn() -> void:
	if _yarn == null:
		return
	var fwd := Vector3.BACK.rotated(Vector3.UP, rotation.y)
	var start := _yarn.position
	var to := Vector3.INF
	for attempt in 16:
		# Hacia delante con algo de ángulo; si no hay sitio, más de lado y más corto.
		var spread := 0.5 + attempt * 0.12
		var dir := fwd.rotated(Vector3.UP, _rng.randf_range(-spread, spread))
		var d := _rng.randf_range(0.8, 1.8) * (1.0 - attempt * 0.04)
		var cand := start + dir * d
		cand.y = YARN_RADIUS
		if _clear(start, cand, 0.1):
			to = cand
			break
	AudioManager.play(&"bounce_fabric", global_position + Vector3.UP * 0.1, -14.0, 0.1)
	if to == Vector3.INF:
		# Contra algo: solo un empujoncito.
		to = start + fwd * 0.06
	_roll_yarn(to, clampf(start.distance_to(to) * 0.8, 0.35, 1.5))


func _roll_yarn(to: Vector3, seconds: float) -> void:
	if _yarn_tween != null:
		_yarn_tween.kill()
	var from := _yarn.position
	var path := to - from
	path.y = 0.0
	var axis := Vector3.UP.cross(path.normalized()) if path.length() > 0.01 else Vector3.RIGHT
	var turns := path.length() / YARN_RADIUS
	var start_basis := _yarn.basis
	_yarn_tween = create_tween()
	_yarn_tween.tween_method(func(t: float):
		var e := 1.0 - pow(1.0 - t, 2.4)
		_yarn.position = from.lerp(to, e)
		_yarn.basis = Basis(axis, turns * e) * start_basis, 0.0, 1.0, seconds)


## Si se queda atascado (muebles por todas partes), el ovillo vuelve rodando a un sitio libre.
func _yarn_home() -> void:
	var spot := _free_point(0.4, 1.4)
	if spot != Vector3.INF:
		_roll_yarn(spot + Vector3(0.0, YARN_RADIUS, 0.0), 1.0)


func yarn_position() -> Vector3:
	return _yarn.position if _yarn != null else Vector3.INF


# --- Animación -------------------------------------------------------------

func _build_tree() -> void:
	for n in LOOPS + [&"bat", &"blink", &"ear_twitch_l", &"ear_twitch_r"]:
		if not _anim.has_animation(n):
			push_warning("cat.glb sin la animación %s" % n)
			return
	for n in LOOPS:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var bt := AnimationNodeBlendTree.new()
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = 0.35
	tr.input_count = LOOPS.size()
	for i in LOOPS.size():
		tr.set_input_name(i, String(LOOPS[i]))
		var a := AnimationNodeAnimation.new()
		a.animation = LOOPS[i]
		bt.add_node(LOOPS[i], a)
	bt.add_node(&"pose", tr)
	for i in LOOPS.size():
		bt.connect_node(&"pose", i, LOOPS[i])
	# El zarpazo, entero, encima de la pose (sentado).
	var last := &"pose"
	last = _add_shot(bt, last, &"bat", &"bat", "", 0.15, 0.3)
	last = _add_shot(bt, last, &"blink_shot", &"blink", ":eyes", 0.02, 0.04)
	last = _add_shot(bt, last, &"twitch_l", &"ear_twitch_l", ":ear_l", 0.04, 0.08)
	last = _add_shot(bt, last, &"twitch_r", &"ear_twitch_r", ":ear_r", 0.04, 0.08)
	bt.connect_node(&"output", 0, last)
	_tree = AnimationTree.new()
	_tree.name = "CatAnimation"
	_anim.get_parent().add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	_tree.tree_root = bt
	_tree.active = true
	_timer(TWITCH_GAP, _twitch)
	_timer(BLINK_GAP, _blink)


func _add_shot(bt: AnimationNodeBlendTree, below: StringName, shot_name: StringName, anim_name: StringName, only_suffix: String, fade_in: float, fade_out: float) -> StringName:
	var a := AnimationNodeAnimation.new()
	a.animation = anim_name
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	if only_suffix != "":
		shot.filter_enabled = true
		var anim := _anim.get_animation(anim_name)
		for t in anim.get_track_count():
			var path := anim.track_get_path(t)
			if String(path).ends_with(only_suffix):
				shot.set_filter_path(path, true)
	var src := StringName(String(shot_name) + "_anim")
	bt.add_node(src, a)
	bt.add_node(shot_name, shot)
	bt.connect_node(shot_name, 0, below)
	bt.connect_node(shot_name, 1, src)
	return shot_name


func _timer(gap: Vector2, callback: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.timeout.connect(func():
		callback.call()
		t.start(_rng.randf_range(gap.x, gap.y)))
	add_child(t)
	t.start(_rng.randf_range(gap.x, gap.y))


func _set_pose(pose: StringName) -> void:
	if _tree == null or pose == _pose:
		return
	_pose = pose
	_tree.set(&"parameters/pose/transition_request", String(pose))


func current_pose() -> StringName:
	return _pose


## Una oreja al azar se sacude.
func _twitch() -> void:
	if _tree != null and _tree.active:
		var side := "l" if _rng.randf() < 0.5 else "r"
		_tree.set("parameters/twitch_%s/request" % side, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Parpadea (no con los ojos ya cerrados: dormido o mientras le acarician).
func _blink() -> void:
	if _tree != null and _tree.active and not _pose in EYES_SHUT:
		_tree.set(&"parameters/blink_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func twitch_now() -> void:
	_twitch()


func is_twitching() -> bool:
	if _tree == null:
		return false
	return bool(_tree.get(&"parameters/twitch_l/active")) or bool(_tree.get(&"parameters/twitch_r/active"))


## Fuera de cámara no se anima (sigue moviéndose por la sala, pero sin calcular huesos).
func _set_animating(on: bool) -> void:
	if _tree != null:
		_tree.active = on

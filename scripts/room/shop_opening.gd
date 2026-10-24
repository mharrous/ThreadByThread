class_name ShopOpening
extends Node
## Escena de apertura: con todo colocado, el suelo barrido (el jugador barre con la escoba y el
## recogedor, ShopSweep) y las cajas de cartón aplanadas en el montón de junto a la puerta (ShopBoxes),
## da igual en qué orden, la mercería abre por primera vez.
##   música a silencio · tres campanadas · se abre la puerta · entra la primera clienta (Customer),
##   mira las estanterías, espera y se va · las luces suben, el cartel pasa a ABIERTO, cae confeti y la
##   música vuelve · fundido a negro y pantalla final (scenes/ui/end_screen.tscn).
## El jugador no se mueve ni coge nada mientras dura; la cámara sigue al cliente. Solo se ve una vez:
## al terminar se guarda `shop_opened` y, al cargar esa partida, se va directo a la tienda abierta.
## Con --test-mode, la tecla T la lanza en cualquier momento (y barre el suelo y apila las cajas de golpe).
const SWEEP_HINT := "Solo falta barrer el suelo: la escoba está junto a la ventana sur"
const BOXES_HINT := "Solo faltan las cajas de cartón: aplánalas y déjalas junto a la puerta"

const END_SCREEN := preload("res://scenes/ui/end_screen.tscn")
const OPEN_TEXT := "La mercería está abierta"
const BELLS := 3
const BELL_GAP := 0.85
const WALK_SPEED := 1.5
## Dónde se para el cliente (coordenadas de la sala): suelo libre del centro, entre la alfombra y las mesas.
const STOP_POINT := Vector3(0.9, 0.0, 1.4)
## Distancia mínima al jugador al pararse (para no meterse en él).
const PERSONAL_SPACE := 1.4
## Colores del confeti (los de las guirnaldas).
const CONFETTI := [Color("e8a0b0"), Color("f2c14e"), Color("8ec5e8"), Color("c9a2e0"), Color("f5f0e6"), Color("9cbfae")]

signal finished

var playing := false
## Paso actual de la secuencia (para las pruebas y para depurar).
var step := &""

var _shop: Shop
var _player: Player
var _hud: Node
var _visitor: Customer
var _look := Vector3.ZERO
var _look_goal := Vector3.ZERO
var _veil: CanvasLayer
var _end: Node
var _test_mode := false


func _ready() -> void:
	_test_mode = OS.get_cmdline_user_args().has("--test-mode")
	Events.room_completed.connect(_on_room_completed)
	Events.floor_cleaned.connect(_on_floor_cleaned)
	Events.boxes_done.connect(_on_boxes_done)
	set_process(false)
	_resume_pending.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _test_mode and key != null and key.pressed and not key.echo and key.keycode == KEY_T and not playing:
		get_viewport().set_input_as_handled()
		play()


func _find() -> bool:
	if _shop == null:
		_shop = get_tree().get_first_node_in_group(&"shop") as Shop
		_player = get_tree().get_first_node_in_group(&"player") as Player
		_hud = get_parent().get_node_or_null("HUD")
	return _shop != null and _shop.room != null and _player != null


func _on_room_completed(_room) -> void:
	if not _find() or _shop.shop_opened or playing:
		return
	# Antes, el cartel de mercería ordenada y las guirnaldas (RoomController._announce_completion).
	await _wait(3.4)
	_open_or_hint()


## El último recogedor a la papelera: abre si ya está todo lo demás (o dice qué falta).
func _on_floor_cleaned() -> void:
	if not _find() or _shop.shop_opened or playing or not _shop.room.is_completed:
		return
	await _wait(2.0)
	_open_or_hint()


## El último cartón en el montón (ya atado): abre si ya está todo lo demás.
func _on_boxes_done() -> void:
	if not _find() or _shop.shop_opened or playing or not _shop.room.is_completed or not _floor_clean():
		return
	await _wait(2.0)
	play()


func _open_or_hint() -> void:
	if playing:
		return
	if not _floor_clean():
		Events.hint_requested.emit(SWEEP_HINT)
	elif not _boxes_done():
		Events.hint_requested.emit(BOXES_HINT)
	else:
		play()


func _floor_clean() -> bool:
	var sweep := _shop.floor_sweep()
	return sweep == null or sweep.is_clean()


func _boxes_done() -> bool:
	var boxes := _shop.cardboard()
	return boxes == null or boxes.is_done()


## Partida guardada con la tienda ordenada pero sin haber visto la apertura (se cerró a medias): se ve ahora.
func _resume_pending() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _find() or _shop.shop_opened or not _shop.room.is_completed or playing or not _floor_clean() or not _boxes_done():
		return
	await _wait(1.5)
	play()


func play() -> void:
	if playing or not _find():
		return
	playing = true
	var room := _shop.room
	var shell := room.shell
	var hw := shell.room_w * 0.5
	var dz: float = shell.east_doors[0] if not shell.east_doors.is_empty() else 0.0
	Events.shop_opening_started.emit()
	var holder := _player.get_node_or_null("ItemHolder") as ItemHolder
	if holder != null:
		holder.release_held()
	_player.input_locked = true
	if _hud != null:
		_hud.set_cinematic(true)
	var cam := _player.camera.global_transform
	_look = cam.origin - cam.basis.z * 3.0
	_look_goal = room.to_global(Vector3(hw, 1.45, dz))
	set_process(true)

	# Atajo de pruebas (T) con papelitos aún en el suelo o cajas sin apilar: se termina de golpe.
	var sweep := _shop.floor_sweep()
	if sweep != null and not sweep.is_clean():
		sweep.finish_instantly()
	var boxes := _shop.cardboard()
	if boxes != null and not boxes.is_done():
		boxes.finish_instantly()

	# 2. La música se apaga.
	step = &"silence"
	AudioManager.fade_music_out(1.5)
	await _wait(1.6)

	# 3. La campanilla de la puerta, tres veces.
	step = &"bells"
	# Sin posición: se oye clara esté donde esté el jugador.
	for i in BELLS:
		AudioManager.play(&"shop_bell", null, 0.0, 0.0, 1.0 if i < BELLS - 1 else 0.94)
		await _wait(BELL_GAP)
	await _wait(0.4)

	# 4. Se abre la puerta y llega el primer cliente. La capa "full" vuelve 2 s después; el resto, luego.
	step = &"door"
	_spawn_visitor(room, Vector3(hw + 2.8, 0.0, dz))
	shell.swing_door(true, 2.4)
	AudioManager.fade_music_in(3.0, AudioManager.MUSIC_LAYERS.size() - 1, 2.0)
	AudioManager.fade_music_in(5.0, -1, 5.0)
	await _walk([Vector3(hw + 0.35, 0.0, dz), Vector3(hw - 0.35, 0.0, dz)])

	# 5. Al cruzar la puerta: luces, cartel de ABIERTO, confeti y el letrero grande.
	step = &"enter"
	shell.open_shop(true, 3.0)
	_confetti(room)
	if _hud != null:
		_hud.show_title_card(OPEN_TEXT, 4.0)
	var inside: Array[Vector3] = [Vector3(hw - 1.0, 0.0, dz + 0.25), Vector3(4.4, 0.0, 2.65), Vector3(2.4, 0.0, 2.75)]
	var stop := _stop_point(room, inside[inside.size() - 1])
	var path := inside.duplicate()
	path.append(stop)
	await _walk(path)

	# 6. Mira la estantería más cercana y a su alrededor, y se queda un momento.
	step = &"look"
	if is_instance_valid(_visitor):
		_visitor.look_around()
	await _turn_to(_nearest_unit(room, stop), 1.6)
	await _wait(3.0)

	# 7. Se va por donde vino; la puerta se cierra tras él y todo funde a negro.
	step = &"leave"
	var back: Array[Vector3] = [inside[2], inside[1], inside[0], Vector3(hw - 0.35, 0.0, dz), Vector3(hw + 0.6, 0.0, dz)]
	await _walk(back)
	shell.swing_door(false, 1.8)
	_walk([Vector3(hw + 4.0, 0.0, dz)])
	step = &"fade"
	await _fade_to_black(3.0)

	# 8. Pantalla final. La apertura ya se ha visto: se guarda.
	step = &"end"
	set_process(false)
	if is_instance_valid(_visitor):
		_visitor.queue_free()
	_shop.shop_opened = true
	_shop.save_game()
	_end = END_SCREEN.instantiate()
	_end.continue_requested.connect(_on_continue)
	_end.menu_requested.connect(_on_menu)
	get_parent().add_child(_end)
	await get_tree().process_frame
	if is_instance_valid(_veil):
		_veil.queue_free()
	Events.shop_opening_finished.emit()


func is_end_screen_open() -> bool:
	return is_instance_valid(_end)


## "Seguir explorando": la tienda abierta, iluminada y libre para pasear.
func _on_continue() -> void:
	_player.input_locked = false
	if _hud != null:
		_hud.set_cinematic(false, 1.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	playing = false
	step = &""
	finished.emit()


func _on_menu() -> void:
	_shop.save_game()
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if is_instance_valid(_visitor) and _visitor.visible:
		_look_goal = _shop.room.to_global(_visitor.position + Vector3(0.0, 1.45, 0.0))
	_look = _look.lerp(_look_goal, 1.0 - exp(-2.2 * delta))
	_player.look_at_point(_look)


# --- El cliente ------------------------------------------------------------

func _spawn_visitor(room: RoomController, at: Vector3) -> void:
	_visitor = Customer.new()
	_visitor.name = "FirstCustomer"
	room.add_child(_visitor)
	_visitor.position = at
	_visitor.rotation.y = -PI * 0.5


## Camina por los puntos (coordenadas de la sala), girando hacia donde va.
func _walk(points: Array[Vector3]) -> void:
	if not is_instance_valid(_visitor):
		await _wait(points.size() * 1.0)
		return
	for p in points:
		while is_instance_valid(_visitor):
			var to := p - _visitor.position
			to.y = 0.0
			var dt := get_process_delta_time()
			if to.length() <= maxf(WALK_SPEED * dt, 0.03):
				_visitor.position = Vector3(p.x, _visitor.position.y, p.z)
				break
			var dir := to.normalized()
			_visitor.velocity = dir * WALK_SPEED
			_visitor.rotation.y = lerp_angle(_visitor.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-7.0 * dt))
			await get_tree().process_frame
	if is_instance_valid(_visitor):
		_visitor.velocity = Vector3.ZERO


func _turn_to(target: Vector3, seconds: float) -> void:
	if not is_instance_valid(_visitor):
		return
	var d := target - _visitor.position
	var yaw := _visitor.rotation.y + wrapf(atan2(d.x, d.z) - _visitor.rotation.y, -PI, PI)
	var tw := _visitor.create_tween()
	tw.tween_property(_visitor, "rotation:y", yaw, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Punto donde se para: el centro de la tienda, o algo antes si ahí está el jugador.
func _stop_point(room: RoomController, came_from: Vector3) -> Vector3:
	var p := room.to_local(_player.global_position)
	p.y = 0.0
	if p.distance_to(STOP_POINT) >= PERSONAL_SPACE:
		return STOP_POINT
	var away := came_from - p
	away.y = 0.0
	return p + away.normalized() * PERSONAL_SPACE if away.length() > 0.01 else came_from


func _nearest_unit(room: RoomController, from: Vector3) -> Vector3:
	var best := from + Vector3.FORWARD
	var best_d := INF
	for unit in room.get_units():
		var u := room.to_local(unit.global_position)
		var d := Vector2(u.x - from.x, u.z - from.z).length()
		if d < best_d:
			best_d = d
			best = u
	return best


# --- Efectos ---------------------------------------------------------------

## Confeti que cae del techo sobre toda la tienda.
func _confetti(room: RoomController) -> void:
	var shell := room.shell
	var p := CPUParticles3D.new()
	p.name = "OpeningConfetti"
	p.one_shot = true
	p.explosiveness = 0.75
	p.amount = 320
	p.lifetime = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(shell.room_w * 0.42, 0.05, shell.room_d * 0.38)
	p.direction = Vector3.DOWN
	p.spread = 35.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0.0, -0.22, 0.0)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.85, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in CONFETTI.size():
		offsets.append(float(i) / CONFETTI.size())
		colors.append(CONFETTI[i])
	g.offsets = offsets
	g.colors = colors
	p.color_initial_ramp = g
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.05)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, shell.room_h - 0.15, 0.3)
	room.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _fade_to_black(seconds: float) -> void:
	_veil = CanvasLayer.new()
	_veil.layer = 25
	var rect := ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.add_child(rect)
	add_child(_veil)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 1.0, seconds).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

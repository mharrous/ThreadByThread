class_name ShopSweep
extends Node3D
## El suelo de la mercería y sus herramientas: los papelitos (el MultiMesh "FabricScraps" de la sala),
## la escoba y el recogedor apoyados en la pared sur y la papelera de mimbre a su lado.
## Barre el jugador (Sweeper, en su ItemHolder): coge la escoba y el recogedor con E, cada escobazo mete
## en el recogedor los papelitos que tiene delante y, con el recogedor lleno (o cuando quiera), lo vacía
## en la papelera con una nube de polvo. El suelo limpio (y el recogedor vacío) es una de las dos cosas
## que abren la tienda; la otra, tener todo ordenado (ShopOpening).
## Va en coordenadas de la sala (es hijo de RoomShell); lo que guarda está en capture_state().

const BROOM := "res://art/models/broom.glb"
const DUSTPAN := "res://art/models/dustpan.glb"
const WASTE_BIN := "res://art/models/waste_bin.glb"

## Sitio de descanso, apoyados en la pared sur (posición, giro y): la escoba inclinada hacia la pared.
const BROOM_REST := Vector3(4.6, 0.0, 4.13)
const BROOM_REST_TILT := 0.19
const PAN_REST := Vector3(4.18, 0.0, 4.14)
## Papelera junto a la escoba y el recogedor, bajo la ventana sur (lejos de las cajas y del paso de la puerta).
const BIN_AT := Vector3(3.55, 0.0, 4.12)
const BIN_TOP := 0.35
## Papelitos que caben en el recogedor (unas cuatro vueltas a la papelera para todo el suelo).
const PAN_CAPACITY := 30
## Radio alrededor del punto de barrido que alcanza un escobazo.
const SWEEP_RADIUS := 0.45
## Altura a la que vuelan la escoba y el recogedor al volver a su sitio (por encima de las mesas).
const FLY_HEIGHT := 0.95
const DUST := Color("d8cbb5")

## Un escobazo ha metido papelitos en el recogedor o se ha vaciado: algo que guardar.
signal changed
## Se ha vaciado el recogedor en la papelera (número de vaciados en la partida).
signal load_dumped(index: int)

var broom: Node3D
var dustpan: Node3D
var waste_bin: Node3D
## Las tiene el jugador en la mano (las mueve Sweeper).
var held := false
var loads_done := 0

var _scraps: MultiMesh
var _home: Array[Transform3D] = []
var _gone: PackedByteArray = PackedByteArray()
var _colors: PackedColorArray = PackedColorArray()
## Papelitos que hay ahora mismo en el recogedor (índices), en el orden en que entraron.
var _pan: PackedInt32Array = PackedInt32Array()
var _load_xf: Array[Transform3D] = []
var _pan_load: MultiMesh
var _rack: Area3D
var _dumping := false


func _ready() -> void:
	waste_bin = _model(WASTE_BIN, "WasteBin")
	waste_bin.position = BIN_AT
	broom = _model(BROOM, "Broom")
	_use_vertex_colors(broom)
	dustpan = _model(DUSTPAN, "Dustpan")
	_build_pan_load()
	_build_rack()
	_rest()


## Papelitos del suelo (los crea RoomShell._scatter_scraps): su MultiMesh, sitios y colores.
func bind_scraps(mmi: MultiMeshInstance3D, transforms: Array[Transform3D], colors: PackedColorArray) -> void:
	if mmi == null:
		return
	_scraps = mmi.multimesh
	_home = transforms.duplicate()
	_colors = colors
	_gone.resize(_home.size())
	_gone.fill(0)
	_emit_progress()


func scraps_total() -> int:
	return _gone.size()


## Papelitos que quedan en el suelo (los del recogedor ya no cuentan).
func scraps_left() -> int:
	return _gone.count(0)


func pan_count() -> int:
	return _pan.size()


func pan_full() -> bool:
	return _pan.size() >= PAN_CAPACITY


func is_dumping() -> bool:
	return _dumping


## Suelo sin papelitos y recogedor vacío.
func is_clean() -> bool:
	return scraps_left() == 0 and _pan.is_empty()


## Centro de la boca de la papelera (global): donde se apunta para vaciar.
func bin_top() -> Vector3:
	return to_global(BIN_AT + Vector3(0.0, BIN_TOP, 0.0))


## El papelito del suelo más cercano a `from` (global); Vector3.INF si no queda ninguno.
func nearest_scrap(from: Vector3) -> Vector3:
	var p := to_local(from)
	var best := Vector3.INF
	var best_d := INF
	for i in _gone.size():
		if _gone[i]:
			continue
		var d := Vector2(_home[i].origin.x - p.x, _home[i].origin.z - p.z).length_squared()
		if d < best_d:
			best_d = d
			best = _home[i].origin
	return to_global(best) if best_d < INF else Vector3.INF


## Partida cargada con la tienda ya abierta (o atajo de pruebas): suelo limpio y todo en su sitio.
func finish_instantly() -> void:
	for i in _gone.size():
		_hide_scrap(i)
	_pan.clear()
	_refresh_pan()
	held = false
	_rest()
	_emit_progress()


# --- Coger y dejar (lo llama Sweeper) ---------------------------------------

## Lo que muestra el HUD al apuntar a la escoba y el recogedor con las manos vacías.
func interact_info() -> Dictionary:
	return {"key": "E", "action": "Coger escoba y recogedor", "title": "Escoba y recogedor",
		"detail": "Para barrer los papelitos del suelo", "hint": "", "kind": "pick"}


## E con las manos vacías apuntando a la escoba: pasan a la mano del jugador.
func interact(holder: ItemHolder) -> void:
	if holder != null and holder.sweeper != null:
		holder.sweeper.take(self)


func take() -> void:
	held = true
	_rack.set_deferred(&"monitorable", false)
	_rack.collision_layer = 0
	AudioManager.play(&"pick", to_global(BROOM_REST + Vector3(0, 0.6, 0)), -4.0)


## Vuelven volando a la pared.
func put_back() -> void:
	held = false
	_fly(dustpan, Transform3D(Basis(Vector3.UP, PI), PAN_REST), 0.7)
	await _fly(broom, Transform3D(Basis(Vector3.RIGHT, BROOM_REST_TILT), BROOM_REST), 0.8)
	if held:
		return
	_rack.collision_layer = ItemHolder.MASK_PICK
	AudioManager.play(&"place_wood", to_global(BROOM_REST + Vector3(0, 0.3, 0)), -6.0)


# --- Barrer y vaciar --------------------------------------------------------

## Un escobazo en `center` (local): los papelitos a su alcance resbalan hasta `mouth` (la boca del
## recogedor, local) y entran en él, hasta llenarlo. Devuelve cuántos ha cogido.
func sweep_at(center: Vector3, mouth: Vector3) -> int:
	if _scraps == null:
		return 0
	var room_left := PAN_CAPACITY - _pan.size()
	if room_left <= 0:
		return 0
	var hits: Array[int] = []
	var r2 := SWEEP_RADIUS * SWEEP_RADIUS
	for i in _gone.size():
		if _gone[i]:
			continue
		var o := _home[i].origin
		if Vector2(o.x - center.x, o.z - center.z).length_squared() <= r2:
			hits.append(i)
	# Primero los más cercanos al recogedor.
	hits.sort_custom(func(a: int, b: int): return _home[a].origin.distance_squared_to(mouth) < _home[b].origin.distance_squared_to(mouth))
	hits = hits.slice(0, room_left)
	if hits.is_empty():
		return 0
	var from_xf: Array[Transform3D] = []
	var to_xf: Array[Transform3D] = []
	for i in hits:
		_gone[i] = 1
		_pan.append(i)
		from_xf.append(_home[i])
		var t := Transform3D(Basis(Vector3.UP, randf() * TAU), mouth + Vector3(randf_range(-0.07, 0.07), 0.02, randf_range(-0.03, 0.03)))
		to_xf.append(t)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var e := t * t * (3.0 - 2.0 * t)
		for k in hits.size():
			_scraps.set_instance_transform(hits[k], from_xf[k].interpolate_with(to_xf[k], e)), 0.0, 1.0, 0.22)
	tw.tween_callback(func():
		for i in hits:
			_scraps.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -1, 0)))
		_refresh_pan())
	_emit_progress()
	changed.emit()
	return hits.size()


## Vacía el recogedor en la papelera: el recogedor vuela encima, se inclina, caen los papelitos con una
## nube de polvo y vuelve. Mientras dura, Sweeper no mueve el recogedor.
func dump() -> void:
	if _dumping or _pan.is_empty():
		return
	_dumping = true
	var to_bin := BIN_AT - dustpan.position
	to_bin.y = 0.0
	var d := to_bin.normalized() if to_bin.length() > 0.01 else Vector3.RIGHT
	# El borde (el origen) queda encima del centro de la papelera, la pala hacia fuera.
	var yaw := atan2(-d.x, -d.z)
	var over := BIN_AT + Vector3(0.0, BIN_TOP + 0.14, 0.0) - d * 0.02
	await _fly(dustpan, Transform3D(Basis(Vector3.UP, yaw), over), 0.45, BIN_TOP + 0.4)
	var tilt := create_tween()
	tilt.tween_property(dustpan, "basis", Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 1.05), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tilt.finished
	_pour()
	AudioManager.play(&"dust_dump", to_global(BIN_AT + Vector3(0, BIN_TOP, 0)), -3.0, 0.06)
	_puff(BIN_AT + Vector3(0.0, BIN_TOP + 0.04, 0.0))
	_pan.clear()
	loads_done += 1
	await _wait(0.4)
	var back := create_tween()
	back.tween_property(dustpan, "basis", Basis(Vector3.UP, yaw), 0.2).set_trans(Tween.TRANS_SINE)
	await back.finished
	_dumping = false
	load_dumped.emit(loads_done)
	_emit_progress()
	changed.emit()
	if is_clean():
		Events.floor_cleaned.emit()


# --- Guardado ---------------------------------------------------------------

func capture_state() -> Dictionary:
	var swept: Array = []
	for i in _gone.size():
		if _gone[i]:
			swept.append(i)
	return {"swept": swept, "pan": Array(_pan), "loads": loads_done}


func apply_state(state: Dictionary) -> void:
	for v in state.get("swept", []):
		_hide_scrap(int(v))
	_pan.clear()
	for v in state.get("pan", []):
		var i := int(v)
		if i >= 0 and i < _gone.size() and _gone[i] and _pan.size() < PAN_CAPACITY:
			_pan.append(i)
	loads_done = int(state.get("loads", 0))
	_refresh_pan()
	_emit_progress()


# --- Piezas -----------------------------------------------------------------

func _model(path: String, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	add_child(root)
	if ResourceLoader.exists(path):
		root.add_child((load(path) as PackedScene).instantiate())
	else:
		push_warning("Falta %s (ejecuta art/blender/make_props.py)" % path)
	return root


## La escoba lleva el color en los vértices (veta del mango, tono de cada mechón de paja): sus superficies
## "wood" y "straw" lo usan como albedo. make_props.py escribe colores lineales en un atributo de coma
## flotante y llegan tal cual (vertex_color_is_srgb = false); el gato, con bytes en sRGB, usa true.
func _use_vertex_colors(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat != null and mat.resource_name in ["wood", "straw"]:
				var painted := mat.duplicate() as StandardMaterial3D
				painted.vertex_color_use_as_albedo = true
				painted.vertex_color_is_srgb = false
				painted.albedo_color = Color.WHITE
				(mi as MeshInstance3D).set_surface_override_material(i, painted)


## Volumen para apuntar a la escoba y el recogedor apoyados (capa de "coger" del ItemHolder).
func _build_rack() -> void:
	_rack = Area3D.new()
	_rack.name = "ToolRack"
	_rack.collision_layer = ItemHolder.MASK_PICK
	_rack.collision_mask = 0
	_rack.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.85, 1.3, 0.45)
	cs.shape = box
	cs.position = (BROOM_REST + PAN_REST) * 0.5 + Vector3(0.0, 0.65, -0.05)
	_rack.add_child(cs)
	add_child(_rack)


## La carga del recogedor: copias de los papelitos recogidos, dentro de la pala.
func _build_pan_load() -> void:
	_pan_load = MultiMesh.new()
	_pan_load.transform_format = MultiMesh.TRANSFORM_3D
	_pan_load.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.004, 0.08)
	_pan_load.mesh = bm
	_pan_load.instance_count = PAN_CAPACITY
	_pan_load.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Load"
	mmi.multimesh = _pan_load
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mmi.material_override = mat
	dustpan.add_child(mmi)


func _rest() -> void:
	broom.transform = Transform3D(Basis(Vector3.RIGHT, BROOM_REST_TILT), BROOM_REST)
	dustpan.transform = Transform3D(Basis(Vector3.UP, PI), PAN_REST)


## La pala con los papelitos que lleva (con sus colores), en un montoncito que crece.
func _refresh_pan() -> void:
	var count := mini(_pan.size(), _pan_load.instance_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_load_xf.clear()
	for k in count:
		var y := 0.016 + 0.004 * (k % 6) + 0.002 * (k / 6)
		var p := Vector3(rng.randf_range(-0.09, 0.09), y, rng.randf_range(-0.19, -0.04))
		# Más alto en el centro: un montón, no una capa.
		p.y += 0.02 * (1.0 - absf(p.x) / 0.09) * (1.0 - absf(p.z + 0.115) / 0.075)
		_load_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
		_pan_load.set_instance_transform(k, _load_xf[k])
		var idx := _pan[k]
		_pan_load.set_instance_color(k, _colors[idx] if idx < _colors.size() else Color.WHITE)
	_pan_load.visible_instance_count = count


## Los papelitos de la pala resbalan hacia el borde y caen dentro de la papelera.
func _pour() -> void:
	var count := mini(_pan_load.visible_instance_count, _load_xf.size())
	var start: Array[Transform3D] = _load_xf.duplicate()
	var tw := create_tween()
	tw.tween_method(func(t: float):
		for k in count:
			var lt := clampf(t * 1.6 - float(k) / maxf(count, 1) * 0.6, 0.0, 1.0)
			var xf: Transform3D = start[k]
			xf.origin = xf.origin.lerp(Vector3(xf.origin.x * 0.5, -0.25, 0.08), lt * lt)
			_pan_load.set_instance_transform(k, xf), 0.0, 1.0, 0.4)
	tw.tween_callback(func(): _pan_load.visible_instance_count = 0)


## Nube de polvo pequeña (motas beis que suben, se abren y se desvanecen).
func _puff(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "DustPuff"
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 26
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0.0, 0.05, 0.0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 1.25))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(DUST, 0.0), Color(DUST, 0.55), Color(DUST, 0.0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	tex.gradient = soft
	m.albedo_texture = tex
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Vuelo de un sitio a otro: sube por encima de las mesas, cruza y baja (arco suave).
func _fly(node: Node3D, to: Transform3D, seconds: float, height: float = FLY_HEIGHT) -> void:
	var from := node.transform
	var dist := Vector2(from.origin.x - to.origin.x, from.origin.z - to.origin.z).length()
	seconds = clampf(seconds * (0.6 + dist / 4.0), 0.3, 1.3)
	var lift := maxf(height - maxf(from.origin.y, to.origin.y), 0.0) if dist > 0.6 else 0.0
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var e := t * t * (3.0 - 2.0 * t)
		var xf := from.interpolate_with(to, e)
		xf.origin.y += sin(PI * e) * lift
		node.transform = xf, 0.0, 1.0, seconds)
	await tw.finished


func _hide_scrap(i: int) -> void:
	if _scraps == null or i < 0 or i >= _gone.size() or _gone[i]:
		return
	_gone[i] = 1
	_scraps.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -1, 0)))


## Vuelve a publicar cuánto suelo hay barrido (la interfaz lo pide al empezar).
func emit_progress() -> void:
	_emit_progress()


func _emit_progress() -> void:
	Events.floor_progress_changed.emit(_gone.size() - scraps_left(), _gone.size())


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

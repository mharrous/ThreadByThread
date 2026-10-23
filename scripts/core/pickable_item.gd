class_name PickableItem
extends RigidBody3D
## Objeto recogible. En reposo es un cuerpo CONGELADO (coste de un cuerpo estático)
## que el ItemHolder mueve con animaciones controladas. Solo al lanzarlo se activa
## la simulación, y al quedar quieto se vuelve a congelar. Así cientos de objetos
## siguen siendo baratos. Forma, modelo, material y comportamiento (rebote, aplastamiento,
## sonido) salen de su ItemData: la misma escena sirve para ovillos, botones, telas...

enum State { LOOSE, HELD, MOVING, PLACED, THROWN }

const BASE_RADIUS := 0.055
const LAYER_ITEMS := 2
const LAYER_PICK := 32
const MASK_FLIGHT := 1 | 2
const MAX_FLIGHT_TIME := 12.0
## Por debajo de este radio el objeto es "pequeño": sin sombra y con distancia de dibujado.
const SMALL_RADIUS := 0.035
const SMALL_DRAW_DISTANCE := 11.0

var data: ItemData
var state: State = State.LOOSE
## Radio de la esfera que lo contiene (separaciones, efectos).
var radius := BASE_RADIUS
## Distancia del centro a la superficie sobre la que reposa.
var half_height := BASE_RADIUS
var rest_yaw := 0.0
var jitter := 1.0

## Sala a la que pertenece y posición en su lista (clave del guardado).
var room: RoomController = null
var index := -1
## Copia de un tesoro ya hallado, expuesta en la repisa: se puede examinar pero no cuenta ni se guarda.
var is_display := false

## Hueco que ocupa si está colocado.
var container: StorageUnit = null
var slot_row := -1
var slot_index := -1

var _profile: MotionProfile
var _mesh: MeshInstance3D
var _base_scale := Vector3.ONE
var _overlay: StandardMaterial3D
var _hl_tween: Tween
var _hovered := false
var _hinted := false
var _has_shader_params := false

# Aplastamiento elástico (muelle amortiguado): + aplasta, - estira.
var _sq_x := 0.0
var _sq_v := 0.0
var _sq_normal := Vector3.UP

# Vuelo.
var _prev_velocity := Vector3.ZERO
var _rest_time := 0.0
var _flight_time := 0.0
var _impact_cooldown := 0.0

@onready var _squash: Node3D = $Squash
@onready var _shape: CollisionShape3D = $Shape
@onready var _proxy: Area3D = $PickProxy
@onready var _proxy_shape: CollisionShape3D = $PickProxy/Shape


func setup(item_data: ItemData, size_jitter: float = 1.0, variant: int = 0) -> void:
	data = item_data
	_profile = item_data.get_motion()
	jitter = size_jitter
	half_height = item_data.get_rest_half_height() * size_jitter
	radius = item_data.get_bounding_radius() * size_jitter
	rest_yaw = randf() * TAU

	_mesh = _find_mesh(_squash)
	if _mesh == null and not item_data.variants.is_empty():
		var model := item_data.variants[variant % item_data.variants.size()].instantiate()
		_squash.add_child(model)
		_mesh = _find_mesh(model)
		_base_scale = Vector3.ONE * size_jitter * item_data.model_scale
	else:
		_base_scale = Vector3.ONE * (item_data.radius * size_jitter / BASE_RADIUS)
	_mesh.scale = _base_scale
	_apply_materials()
	# Cientos de objetos en una sola sala: las piezas pequeñas no proyectan sombra (no se notaría) y
	# dejan de dibujarse de lejos, con fundido (a esa distancia ocupan uno o dos píxeles).
	if radius < SMALL_RADIUS:
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh.visibility_range_end = SMALL_DRAW_DISTANCE
		_mesh.visibility_range_end_margin = 1.0
		_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	_shape.shape = _make_shape(item_data, size_jitter)
	_shape.rotation_degrees = item_data.shape_rotation_deg
	var pick := SphereShape3D.new()
	pick.radius = maxf(item_data.pick_radius * size_jitter, 0.02)
	_proxy_shape.shape = pick

	physics_material_override = _profile.get_physics_material()
	mass = _profile.mass
	linear_damp = _profile.linear_damp
	angular_damp = _profile.angular_damp
	set_process(false)
	if item_data.treasure:
		var sparkle := TreasureSparkle.new()
		sparkle.emission_sphere_radius = maxf(radius * 0.9, 0.04)
		add_child(sparkle)


## Malla y escala del modelo (para dibujar la "sombra" translúcida de colocación).
func get_ghost_mesh() -> Mesh:
	return _mesh.mesh


func get_mesh_scale() -> Vector3:
	return _base_scale


## Forma física y su pose para una pose del objeto (consultas de espacio libre).
func get_collision_shape() -> Shape3D:
	return _shape.shape


func shape_transform_at(object_transform: Transform3D) -> Transform3D:
	return object_transform * Transform3D(Basis.from_euler(data.shape_rotation_deg * (PI / 180.0)), Vector3.ZERO)


## Un tesoro recién hallado sube hasta `show_pos` (delante de la cámara), gira un momento y se
## encoge hacia `end_pos` antes de desaparecer en la colección.
func play_collect(show_pos: Vector3, end_pos: Vector3) -> void:
	set_pickable(false)
	freeze = true
	state = State.MOVING
	var move := create_tween()
	move.tween_property(self, "global_position", show_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	move.tween_interval(0.9)
	move.tween_property(self, "global_position", end_pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move.parallel().tween_property(_squash, "scale", Vector3.ONE * 0.05, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move.tween_callback(queue_free)
	var spin := create_tween()
	spin.tween_property(self, "rotation:y", rotation.y + TAU * 1.6, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Examinar un tesoro ya expuesto: sube hasta `show_pos` (delante de la cámara), gira y vuelve a su sitio.
func play_inspect(show_pos: Vector3) -> void:
	var home := global_transform
	set_pickable(false)
	var move := create_tween()
	move.tween_property(self, "global_position", show_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	move.tween_interval(1.3)
	move.tween_property(self, "global_position", home.origin, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	move.tween_callback(func():
		global_transform = home
		set_pickable(true))
	var spin := create_tween()
	spin.tween_property(self, "rotation:y", rotation.y + TAU * 1.5, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_pickable() -> bool:
	return _proxy.collision_layer != 0


## Aparece con un "pop" elástico (decoración desbloqueada, tesoro expuesto).
## Pulso al colocarlo: crece un poco y vuelve con rebote. `strength` 0..1 (sube con la racha).
## Va en el nodo Squash (solo visual), así no mueve la física ni el hueco.
func play_place_pulse(strength: float) -> void:
	var peak := 1.06 + 0.19 * clampf(strength, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_squash, "scale", Vector3.ONE * peak, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_squash, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_appear() -> void:
	_squash.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(_squash, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Activa o desactiva que el objeto pueda ser apuntado y que colisione.
func set_pickable(on: bool) -> void:
	collision_layer = LAYER_ITEMS if on else 0
	_proxy.collision_layer = LAYER_PICK if on else 0


func set_highlighted(on: bool) -> void:
	_hovered = on
	_refresh_glow()


## Pista de "el siguiente de este tipo": brillo cálido que respira, más flojo que el de apuntar.
func set_hinted(on: bool) -> void:
	if on == _hinted:
		return
	_hinted = on
	_refresh_glow()


func is_hinted() -> bool:
	return _hinted


## Apuntar manda sobre la pista; sin ninguna de las dos, el brillo se apaga y se quita el overlay.
func _refresh_glow() -> void:
	if _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay.albedo_color = Color(1.0, 0.96, 0.86, 0.0)
		_overlay.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _hl_tween:
		_hl_tween.kill()
	var a := _overlay.albedo_color.a
	_hl_tween = create_tween()
	if _hovered:
		_mesh.material_overlay = _overlay
		_set_glow_color(Color(1.0, 0.96, 0.86))
		_hl_tween.tween_method(_apply_highlight, a, 0.2, 0.12)
	elif _hinted:
		_mesh.material_overlay = _overlay
		_set_glow_color(Color(1.0, 0.82, 0.5))
		_apply_highlight(minf(a, 0.04))
		_hl_tween.tween_method(_apply_highlight, 0.04, 0.13, 0.9).set_trans(Tween.TRANS_SINE)
		_hl_tween.tween_method(_apply_highlight, 0.13, 0.04, 0.9).set_trans(Tween.TRANS_SINE)
		_hl_tween.set_loops()
	else:
		_hl_tween.tween_method(_apply_highlight, a, 0.0, 0.12)
		_hl_tween.tween_callback(func(): _mesh.material_overlay = null)


func _set_glow_color(c: Color) -> void:
	_overlay.albedo_color = Color(c.r, c.g, c.b, _overlay.albedo_color.a)


## Aplastamiento elástico (strength 1 = el de colocar en una balda).
func squash(strength: float = 1.0, normal: Vector3 = Vector3.UP) -> void:
	_sq_x = 0.16 * strength * maxf(_profile.squash, 0.05)
	_sq_v = 0.0
	_sq_normal = normal
	set_process(true)


## Lanza el objeto: activa la simulación hasta que se quede quieto.
func launch(velocity: Vector3, spin: Vector3) -> void:
	state = State.THROWN
	container = null
	_proxy.collision_layer = 0
	collision_layer = LAYER_ITEMS
	collision_mask = MASK_FLIGHT
	freeze = false
	can_sleep = false   # si el motor lo durmiera, _integrate_forces dejaria de llamarse y no se asentaria nunca
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	linear_velocity = velocity
	angular_velocity = spin * _profile.throw_spin
	_prev_velocity = velocity
	_rest_time = 0.0
	_flight_time = 0.0
	_impact_cooldown = 0.0


func _integrate_forces(ps: PhysicsDirectBodyState3D) -> void:
	if state != State.THROWN:
		return
	var dt := ps.step
	_flight_time += dt
	_impact_cooldown = maxf(0.0, _impact_cooldown - dt)

	for i in ps.get_contact_count():
		if _impact_cooldown > 0.0:
			break
		var n := ps.get_contact_local_normal(i)
		if _prev_velocity.dot(n) > 0.0:
			n = -n   # que apunte desde la superficie hacia el objeto
		var impact := -_prev_velocity.dot(n)
		if impact > _profile.min_impact_speed:
			_impact_cooldown = 0.05
			_on_impact(impact, n, ps.get_contact_local_position(i))
			break
	_prev_velocity = ps.linear_velocity

	if ps.linear_velocity.length() < _profile.rest_speed and ps.angular_velocity.length() < 1.2:
		_rest_time += dt
	else:
		_rest_time = 0.0
	if ps.transform.origin.y < -1.0 or _left_the_building(ps.transform.origin):
		_recover.call_deferred()
	elif _rest_time > 0.4 or _flight_time > MAX_FLIGHT_TIME:
		_settle.call_deferred()


func _on_impact(speed: float, normal: Vector3, contact: Vector3) -> void:
	_sq_x = minf(speed * 0.045 * _profile.squash, 0.4)
	_sq_v = 0.0
	_sq_normal = normal
	set_process(true)
	Events.item_bounced.emit(self, speed, contact, _profile.impact_sound)


## Vuelve a congelarse cuando se queda quieto.
func _settle() -> void:
	if state != State.THROWN:
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	contact_monitor = false
	continuous_cd = false
	can_sleep = true
	state = State.LOOSE
	set_pickable(true)
	Events.item_landed.emit(self)


## ¿Ha salido por alguna pared? No debería pasar nunca; es la red de seguridad.
func _left_the_building(p: Vector3) -> bool:
	if room == null or room.shell == null:
		return false
	var local := room.to_local(p)
	return absf(local.x) > room.shell.room_w * 0.5 + 0.3 or absf(local.z) > room.shell.room_d * 0.5 + 0.3


## Red de seguridad: si se cae del mundo vuelve al suelo de la sala.
func _recover() -> void:
	if state != State.THROWN:
		return
	freeze = true
	var home := room.global_position if room != null else Vector3.ZERO
	global_position = home + Vector3(randf_range(-0.8, 0.8), half_height, randf_range(0.5, 1.5))
	_settle()


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	_sq_v += (-_profile.squash_stiffness * _sq_x - _profile.squash_damping * _sq_v) * dt
	_sq_x += _sq_v * dt
	if absf(_sq_x) < 0.002 and absf(_sq_v) < 0.05:
		_sq_x = 0.0
		_sq_v = 0.0
		_squash.transform = Transform3D.IDENTITY
		set_process(false)
		return
	# El eje del aplastamiento se define en el mundo; se pasa al espacio local del objeto.
	var n := (global_basis.inverse() * _sq_normal).normalized()
	var s_n := 1.0 - _sq_x
	var s_p := 1.0 + _sq_x * 0.5
	var k := s_n - s_p
	var b := Basis(
		Vector3(s_p + k * n.x * n.x, k * n.x * n.y, k * n.x * n.z),
		Vector3(k * n.y * n.x, s_p + k * n.y * n.y, k * n.y * n.z),
		Vector3(k * n.z * n.x, k * n.z * n.y, s_p + k * n.z * n.z))
	# Mantiene el punto de contacto fijo mientras se deforma.
	_squash.transform = Transform3D(b, -n * half_height * _sq_x)


# --- Interno -------------------------------------------------------------

func _apply_highlight(value: float) -> void:
	_overlay.albedo_color.a = value


## Cada superficie del modelo lleva el material que corresponde a su nombre
## ("main", "accent", "metal", "glass"). Los modelos sin nombres reconocidos usan "main".
func _apply_materials() -> void:
	var mesh := _mesh.mesh
	for i in mesh.get_surface_count():
		var src := mesh.surface_get_material(i)
		var surface_name := src.resource_name if src != null else "main"
		_mesh.set_surface_override_material(i, data.get_surface_material(surface_name))
	var main_mat := data.get_surface_material("main")
	_has_shader_params = main_mat is ShaderMaterial
	if _has_shader_params:
		_mesh.set_instance_shader_parameter(&"variation", randf() * 100.0)


func _make_shape(item_data: ItemData, j: float) -> Shape3D:
	match item_data.shape:
		ItemData.Shape.CYLINDER:
			var c := CylinderShape3D.new()
			c.radius = item_data.radius * j
			c.height = item_data.size.y * j
			return c
		ItemData.Shape.BOX:
			var b := BoxShape3D.new()
			b.size = item_data.size * j
			return b
		_:
			var s := SphereShape3D.new()
			s.radius = item_data.radius * j
			return s


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

class_name PickableItem
extends RigidBody3D
## Objeto recogible. En reposo es un cuerpo CONGELADO (coste de un cuerpo estático)
## que el ItemHolder mueve con animaciones controladas. Solo al lanzarlo se activa
## la simulación, y al quedar quieto se vuelve a congelar. Así miles de objetos
## siguen siendo baratos. El comportamiento (rebote, aplastamiento, sonido) viene
## del MotionProfile de su ItemData.

enum State { LOOSE, HELD, MOVING, PLACED, THROWN }

const BASE_RADIUS := 0.055
const LAYER_ITEMS := 2
const LAYER_PICK := 32
const MASK_FLIGHT := 1 | 2
const MAX_FLIGHT_TIME := 12.0

var data: ItemData
var state: State = State.LOOSE
var radius := BASE_RADIUS
var rest_yaw := 0.0

## Hueco de estantería que ocupa (si está colocado).
var shelf: ShelfUnit = null
var slot_row := -1
var slot_index := -1

var _profile: MotionProfile
var _mesh: MeshInstance3D
var _base_scale := Vector3.ONE
var _hl_tween: Tween

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


func setup(item_data: ItemData, size_jitter: float = 1.0) -> void:
	data = item_data
	_profile = item_data.get_motion()
	radius = item_data.radius * size_jitter
	rest_yaw = randf() * TAU
	_base_scale = Vector3.ONE * (radius / BASE_RADIUS)
	_mesh = _find_mesh(_squash)
	_mesh.scale = _base_scale
	_mesh.material_override = item_data.get_material()
	_mesh.set_instance_shader_parameter(&"variation", randf() * 100.0)

	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_shape.shape = sphere
	physics_material_override = _profile.get_physics_material()
	mass = _profile.mass
	linear_damp = _profile.linear_damp
	angular_damp = _profile.angular_damp
	set_process(false)


## Activa o desactiva que el objeto pueda ser apuntado y que colisione.
func set_pickable(on: bool) -> void:
	collision_layer = LAYER_ITEMS if on else 0
	_proxy.collision_layer = LAYER_PICK if on else 0


func set_highlighted(on: bool) -> void:
	if _hl_tween:
		_hl_tween.kill()
	_hl_tween = create_tween()
	_hl_tween.tween_method(_apply_highlight, 1.0 - float(on), float(on), 0.12)


## Aplastamiento elástico (strength 1 = el de colocar en una balda).
func squash(strength: float = 1.0, normal: Vector3 = Vector3.UP) -> void:
	_sq_x = 0.16 * strength * maxf(_profile.squash, 0.05)
	_sq_v = 0.0
	_sq_normal = normal
	set_process(true)


## Lanza el objeto: activa la simulación hasta que se quede quieto.
func launch(velocity: Vector3, spin: Vector3) -> void:
	state = State.THROWN
	_proxy.collision_layer = 0
	collision_layer = LAYER_ITEMS
	collision_mask = MASK_FLIGHT
	freeze = false
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
	if ps.transform.origin.y < -3.0:
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
	state = State.LOOSE
	set_pickable(true)
	Events.item_landed.emit(self)


## Red de seguridad: si se cae del mundo vuelve al suelo de la sala.
func _recover() -> void:
	if state != State.THROWN:
		return
	freeze = true
	global_position = Vector3(randf_range(-0.8, 0.8), radius, randf_range(0.5, 1.5))
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
	_squash.transform = Transform3D(b, -n * radius * _sq_x)


func _apply_highlight(value: float) -> void:
	_mesh.set_instance_shader_parameter(&"highlight", value)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

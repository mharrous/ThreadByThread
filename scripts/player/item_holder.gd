class_name ItemHolder
extends Node
## Interacción en primera persona: apuntar, recoger, sostener, girar, lanzar y colocar.
## Todo el movimiento del objeto es animado (curvas y suavizado exponencial);
## nunca se teletransporta ni se usa física dinámica salvo al lanzar.

enum State { EMPTY, PICKING, HOLDING, PLACING }
enum PlaceKind { STORAGE, SURFACE }

const MASK_WORLD := 1
const MASK_ITEMS := 2
const MASK_STORAGE_AIM := 4
const MASK_SETTABLE := 16
const MASK_PICK := 32

@export var throw_min_speed := 3.2
@export var throw_max_speed := 9.5
@export var charge_time := 0.9
@export var reach := 2.7
@export var hold_distance := 0.60
@export var hold_offset := Vector3(0.19, -0.16, 0.0)
@export var pick_duration := 0.30
@export var place_duration := 0.24
@export var follow_stiffness := 22.0
@export var spin_speed := 2.6

var state: State = State.EMPTY
var held: PickableItem = null
var hover_item: PickableItem = null
## Estado de la puntería sobre contenedores mientras se sostiene un objeto.
var aim_status: StorageUnit.SlotStatus = StorageUnit.SlotStatus.NONE

var _player: Player
var _camera: Camera3D
var _spin := 0.0
var _charging := false
var _charge := 0.0
var _hold_dist := 0.6
var _smooth_pos := Vector3.ZERO
var _wobble := 0.0

var _anim_t := 0.0
var _anim_duration := 0.3
var _anim_from := Transform3D.IDENTITY
var _anim_to := Transform3D.IDENTITY
var _place_kind: PlaceKind = PlaceKind.STORAGE
var _place_unit: StorageUnit
var _place_row := -1
var _place_slot := -1

var _aim: Dictionary = {}
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _last_info: Dictionary = {}


func _ready() -> void:
	_player = get_parent() as Player
	_camera = _player.get_node("CameraRig/Camera3D")
	process_priority = 10   # después del jugador: usa la cámara ya actualizada
	_build_ghost()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released(&"throw") and _charging:
		try_throw()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"throw") and state == State.HOLDING:
		_charging = true
		_charge = 0.0
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"interact"):
		if state == State.EMPTY:
			try_pick()
		elif state == State.HOLDING:
			try_set_down()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"set_down") and state == State.HOLDING:
		try_set_down()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"place") and state == State.HOLDING:
		try_place()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	match state:
		State.EMPTY:
			_process_empty()
		State.PICKING:
			_process_picking(delta)
		State.HOLDING:
			_process_holding(delta)
		State.PLACING:
			_process_placing(delta)


# --- Acciones ------------------------------------------------------------

func try_pick() -> bool:
	if state != State.EMPTY or hover_item == null:
		return false
	var item := hover_item
	_set_hover(null)
	if item.data.treasure:
		_collect_treasure(item)
		return true
	if item.state == PickableItem.State.PLACED and item.container != null:
		var old_unit := item.container
		old_unit.release(item.slot_row, item.slot_index, item)
		item.container = null
		item.slot_row = -1
		item.slot_index = -1
		item.state = PickableItem.State.LOOSE
		Events.item_removed.emit(item, old_unit)
	held = item
	held.state = PickableItem.State.MOVING
	held.set_pickable(false)
	_spin = 0.0
	_wobble = 0.0
	_charging = false
	_charge = 0.0
	_hold_dist = hold_distance
	_smooth_pos = held.global_position
	_ghost.mesh = held.get_ghost_mesh()
	_ghost.visible = false
	_begin_anim(held.global_transform, Transform3D.IDENTITY, pick_duration)
	state = State.PICKING
	Events.item_picked.emit(held)
	Events.held_item_changed.emit(held)
	return true


## Los tesoros escondidos no se sostienen ni se colocan: se enseñan un instante delante de la
## cámara y pasan a la colección de la sala (las manos siguen libres).
func _collect_treasure(item: PickableItem) -> void:
	var cam := _camera.global_transform
	var show_pos := cam.origin - cam.basis.z * 0.55 + cam.basis.y * 0.03
	var end_pos := cam.origin - cam.basis.z * 0.35 - cam.basis.x * 0.28 + cam.basis.y * 0.22
	Events.treasure_found.emit(item)
	item.play_collect(show_pos, end_pos)


func try_place() -> void:
	if state != State.HOLDING:
		return
	match aim_status:
		StorageUnit.SlotStatus.OK:
			var unit: StorageUnit = _aim["unit"]
			var row: int = _aim["row"]
			var slot: int = _aim["slot"]
			unit.reserve(row, slot, held)
			_place_kind = PlaceKind.STORAGE
			_place_unit = unit
			_place_row = row
			_place_slot = slot
			_start_place(_aim["transform"])
		StorageUnit.SlotStatus.WRONG_ROW:
			var unit: StorageUnit = _aim["unit"]
			_reject(unit.wrong_row_hint)
		StorageUnit.SlotStatus.ROW_FULL:
			_reject("Este hueco ya está completo")
		_:
			Events.hint_requested.emit("Apunta a su estantería o bandeja para colocarlo")


## Lanza el objeto sostenido. La fuerza depende de cuánto se mantuvo pulsado (0..1).
func try_throw() -> void:
	var strength := _charge
	_charging = false
	_charge = 0.0
	Events.throw_charge_changed.emit(0.0)
	if state != State.HOLDING:
		return
	var cam := _camera.global_transform
	var speed := lerpf(throw_min_speed, throw_max_speed, strength)
	var direction := (-cam.basis.z + Vector3.UP * 0.12).normalized()
	var velocity := direction * speed + _player.velocity * 0.6
	# Giro hacia delante, como una pelota que rueda por el aire, con algo de azar.
	var spin := -cam.basis.x * speed * 1.2 + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 2.5
	var item := held
	held = null
	state = State.EMPTY
	_ghost.visible = false
	_last_info = {&"stale": true}   # fuerza que se vuelva a publicar el estado
	aim_status = StorageUnit.SlotStatus.NONE
	item.launch(velocity, spin)
	Events.item_thrown.emit(item)
	Events.held_item_changed.emit(null)


func try_set_down() -> void:
	if state != State.HOLDING:
		return
	var hit := _raycast(MASK_SETTABLE)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		Events.hint_requested.emit("Apúntalo al suelo o a una mesa para dejarlo")
		return
	var pos: Vector3 = (hit["position"] as Vector3) + Vector3.UP * held.half_height
	var target := Transform3D(Basis(Vector3.UP, held.rest_yaw), pos)
	if _is_blocked(target):
		Events.hint_requested.emit("Ahí no cabe")
		return
	_place_kind = PlaceKind.SURFACE
	_start_place(target)


# --- Estados -------------------------------------------------------------

func _process_empty() -> void:
	# Los objetos se apuntan con un volumen algo mayor que el físico (más cómodo).
	var hit := _raycast(MASK_WORLD | MASK_PICK, true)
	var item: PickableItem = null
	if not hit.is_empty():
		var proxy := hit["collider"] as Area3D
		if proxy != null:
			item = proxy.get_parent() as PickableItem
	_set_hover(item)
	if item:
		_publish({
			"key": "E", "action": "Recoger",
			"title": item.data.display_name, "detail": item.data.detail,
			"hint": "Tesoro escondido" if item.data.treasure else "",
			"kind": "pick",
		})
	else:
		_publish({})


func _process_picking(delta: float) -> void:
	_anim_t += delta / _anim_duration
	var t := minf(_anim_t, 1.0)
	var e := 1.0 - pow(1.0 - t, 3.0)
	var target := _hold_transform(delta)
	var ctrl := (_anim_from.origin + target.origin) * 0.5 + Vector3.UP * 0.10
	var pos := _bezier(_anim_from.origin, ctrl, target.origin, e)
	var q := _anim_from.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), e)
	held.global_transform = Transform3D(Basis(q), pos)
	_smooth_pos = pos
	_publish_holding_info(StorageUnit.SlotStatus.NONE)
	if t >= 1.0:
		state = State.HOLDING
		held.state = PickableItem.State.HELD


func _process_holding(delta: float) -> void:
	if Input.is_action_pressed(&"rotate_item"):
		_spin += spin_speed * delta
	if _charging:
		_charge = minf(1.0, _charge + delta / charge_time)
		Events.throw_charge_changed.emit(_charge)
	var target := _hold_transform(delta)
	_smooth_pos = _smooth_pos.lerp(target.origin, 1.0 - exp(-follow_stiffness * delta))
	var cur_q := held.global_basis.get_rotation_quaternion()
	var q := cur_q.slerp(target.basis.get_rotation_quaternion(), 1.0 - exp(-16.0 * delta))
	var offset := Vector3.ZERO
	if _wobble > 0.0:
		_wobble = maxf(0.0, _wobble - delta * 3.5)
		offset = _camera.global_basis.x * sin(_wobble * 30.0) * 0.035 * _wobble
	held.global_transform = Transform3D(Basis(q), _smooth_pos + offset)
	_update_aim(delta)


func _process_placing(delta: float) -> void:
	_anim_t += delta / _anim_duration
	var t := minf(_anim_t, 1.0)
	var e := 1.0 - pow(1.0 - t, 3.0)   # llegada suave: frena al encajar
	var ctrl := _anim_from.origin.lerp(_anim_to.origin, 0.5) + Vector3.UP * 0.05
	var pos := _bezier(_anim_from.origin, ctrl, _anim_to.origin, e)
	var q := _anim_from.basis.get_rotation_quaternion().slerp(_anim_to.basis.get_rotation_quaternion(), e)
	held.global_transform = Transform3D(Basis(q), pos)
	if t >= 1.0:
		_finish_place()


func _finish_place() -> void:
	var item := held
	item.global_transform = _anim_to
	item.set_pickable(true)
	held = null
	state = State.EMPTY
	aim_status = StorageUnit.SlotStatus.NONE
	_last_info = {&"stale": true}   # fuerza que se vuelva a publicar el estado
	if _place_kind == PlaceKind.STORAGE:
		item.state = PickableItem.State.PLACED
		item.container = _place_unit
		item.slot_row = _place_row
		item.slot_index = _place_slot
		item.squash(1.0)
		Events.item_placed.emit(item, _place_unit)
	else:
		item.state = PickableItem.State.LOOSE
		item.squash(0.5)
		Events.item_set_down.emit(item)
	Events.held_item_changed.emit(null)


func _start_place(target: Transform3D) -> void:
	_begin_anim(held.global_transform, target, place_duration)
	held.state = PickableItem.State.MOVING
	state = State.PLACING
	_ghost.visible = false


func _reject(reason: String) -> void:
	_wobble = 1.0
	Events.item_rejected.emit(held, reason)
	Events.hint_requested.emit(reason)


# --- Puntería y utilidades ----------------------------------------------

func _update_aim(delta: float) -> void:
	_aim = {}
	aim_status = StorageUnit.SlotStatus.NONE
	var hit := _raycast(MASK_WORLD | MASK_STORAGE_AIM)
	if not hit.is_empty():
		var collider := hit["collider"] as Object
		if collider != null and collider.has_meta(StorageUnit.AIM_META):
			var unit := collider.get_meta(StorageUnit.AIM_META) as StorageUnit
			_aim = unit.query_slot(_camera.global_position, -_camera.global_basis.z, held)
			_aim["unit"] = unit
			aim_status = _aim["status"]
	_update_ghost(delta)
	_publish_holding_info(aim_status)


func _update_ghost(delta: float) -> void:
	if aim_status == StorageUnit.SlotStatus.NONE:
		_ghost.visible = false
		return
	var target: Transform3D = _aim["transform"]
	if not _ghost.visible:
		_ghost.global_transform = target
		_ghost.visible = true
	else:
		var pos := _ghost.global_position.lerp(target.origin, 1.0 - exp(-32.0 * delta))
		var q := _ghost.global_basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), 1.0 - exp(-24.0 * delta))
		_ghost.global_transform = Transform3D(Basis(q), pos)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
	_ghost.scale = held.get_mesh_scale() * (1.0 + 0.03 * pulse)
	if aim_status == StorageUnit.SlotStatus.OK:
		_ghost_mat.albedo_color = Color(0.72, 1.0, 0.78, 0.30 + 0.12 * pulse)
	else:
		_ghost_mat.albedo_color = Color(1.0, 0.50, 0.45, 0.28)


func _publish_holding_info(status: StorageUnit.SlotStatus) -> void:
	var info := {
		"title": held.data.display_name,
		"detail": held.data.detail,
		"hint": "R girar   ·   F lanzar (mantén = más fuerza)   ·   E dejar",
	}
	match status:
		StorageUnit.SlotStatus.OK:
			info["key"] = "Clic"
			info["action"] = "Colocar aquí"
			info["kind"] = "place"
		StorageUnit.SlotStatus.WRONG_ROW:
			info["key"] = ""
			info["action"] = (_aim["unit"] as StorageUnit).wrong_row_hint
			info["kind"] = "deny"
		StorageUnit.SlotStatus.ROW_FULL:
			info["key"] = ""
			info["action"] = "Este hueco ya está completo"
			info["kind"] = "deny"
		_:
			info["key"] = ""
			info["action"] = ""
			info["kind"] = "hold"
	_publish(info)


func _publish(info: Dictionary) -> void:
	if info != _last_info:
		_last_info = info
		Events.target_changed.emit(info)


func _set_hover(item: PickableItem) -> void:
	if item == hover_item:
		return
	if hover_item != null and is_instance_valid(hover_item):
		hover_item.set_highlighted(false)
	hover_item = item
	if item != null:
		item.set_highlighted(true)


func _raycast(mask: int, areas: bool = false) -> Dictionary:
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.collide_with_areas = areas
	return _camera.get_world_3d().direct_space_state.intersect_ray(q)


## Posición/orientación de la "mano": abajo a la derecha, recogida si hay una pared cerca.
func _hold_transform(delta: float) -> Transform3D:
	var cam := _camera.global_transform
	var forward := -cam.basis.z
	var desired := hold_distance
	var q := PhysicsRayQueryParameters3D.create(cam.origin, cam.origin + forward * (hold_distance + 0.15), MASK_WORLD)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var d := cam.origin.distance_to(hit["position"] as Vector3)
		desired = clampf(d - 0.18, 0.28, hold_distance)
	_hold_dist = lerpf(_hold_dist, desired, 1.0 - exp(-14.0 * delta))
	var s := _hold_dist / hold_distance
	var local := Vector3(hold_offset.x * s, hold_offset.y * s, -_hold_dist)
	# Preparación del lanzamiento: la mano se recoge hacia atrás y abajo.
	local += Vector3(0.05, -0.05, 0.14) * _charge
	var basis := cam.basis * Basis(Vector3.UP, _spin)
	return Transform3D(basis, cam.origin + cam.basis * local)


## ¿Hay algo (mundo u otros objetos) ocupando la pose indicada? Usa la forma real del objeto.
func _is_blocked(object_transform: Transform3D) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = held.get_collision_shape()
	var xf := held.shape_transform_at(object_transform)
	xf.origin += Vector3.UP * 0.004   # evita contar el contacto con la superficie de apoyo
	params.transform = xf
	params.collision_mask = MASK_WORLD | MASK_ITEMS
	return not _camera.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _begin_anim(from: Transform3D, to: Transform3D, duration: float) -> void:
	_anim_from = from
	_anim_to = to
	_anim_t = 0.0
	_anim_duration = duration


func _build_ghost() -> void:
	_ghost = MeshInstance3D.new()
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.7, 1.0, 0.8, 0.35)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_ghost.top_level = true


static func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

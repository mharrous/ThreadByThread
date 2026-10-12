class_name ShelfUnit
extends Node3D
## Estantería modular. Se construye por código a partir de parámetros y expone
## huecos (slots) por fila. Cada fila acepta objetos con un `sort_key` concreto.
## Origen: centro de la base, parte trasera pegada a z=0, frente hacia +Z.

enum SlotStatus { NONE, OK, WRONG_ROW, ROW_FULL }

@export var unit_width := 2.1
@export var rows := 5
@export var row_pitch := 0.34
@export var base_height := 0.16
@export var depth := 0.30
@export var slots_per_row := 15
@export var slot_spacing := 0.13
@export var wood_color := Color("e6c995")
@export var back_color := Color("d7b27c")

const BOARD_T := 0.06
const SIDE_T := 0.04
const AIM_LAYER := 4

var _row_data: Array[ItemData] = []     # índice 0 = fila inferior
var _slots: Array = []                  # [fila][hueco] -> PickableItem o null
var _slot_mm: MultiMesh
var _plaque_mats: Array[StandardMaterial3D] = []
var _plaque_meshes: Array[MeshInstance3D] = []
var _plaque_labels: Array[Label3D] = []
var _body: StaticBody3D


func _ready() -> void:
	_row_data.resize(rows)
	for r in rows:
		var row_slots: Array = []
		row_slots.resize(slots_per_row)
		_slots.append(row_slots)
	_build()
	Events.collection_completed.connect(_on_collection_completed)
	Events.room_completed.connect(_on_room_completed)


# --- API pública ---------------------------------------------------------

## Asigna el tipo de objeto de cada fila, empezando por la superior.
func set_rows_top_to_bottom(list: Array) -> void:
	for i in list.size():
		var row := rows - 1 - i
		if row < 0:
			break
		_row_data[row] = list[i] as ItemData
		_refresh_row_visuals(row)


func row_for_key(sort_key: StringName) -> int:
	for r in rows:
		if _row_data[r] != null and _row_data[r].sort_key == sort_key:
			return r
	return -1


func first_free_slot(row: int) -> int:
	return _nearest_free(row, 0)


func slot_local_position(row: int, index: int, item_radius: float) -> Vector3:
	return Vector3(_slot_x(index), _row_top_y(row) + item_radius, _slot_z())


func slot_world_position(row: int, index: int, item_radius: float) -> Vector3:
	return to_global(slot_local_position(row, index, item_radius))


## Resuelve a qué hueco apunta un rayo. Devuelve {status, row, slot, position}.
func query_slot(ray_origin: Vector3, ray_dir: Vector3, item: PickableItem) -> Dictionary:
	var local_origin := to_local(ray_origin)
	var local_dir := global_basis.inverse() * ray_dir
	if absf(local_dir.z) < 0.0001:
		return _no_slot()
	var t := (_slot_z() - local_origin.z) / local_dir.z
	if t < 0.0:
		return _no_slot()
	var p := local_origin + local_dir * t
	var half_w := unit_width * 0.5 - SIDE_T
	if absf(p.x) > half_w + 0.02:
		return _no_slot()
	var row_f := (p.y - (base_height - 0.05)) / row_pitch
	if row_f < 0.0 or row_f >= float(rows):
		return _no_slot()
	var row := int(floor(row_f))
	var wanted := clampi(roundi(p.x / slot_spacing + (slots_per_row - 1) * 0.5), 0, slots_per_row - 1)
	var slot := _nearest_free(row, wanted)
	var status := SlotStatus.OK
	if slot < 0:
		status = SlotStatus.ROW_FULL
		slot = wanted
	elif _row_data[row] == null or _row_data[row].sort_key != item.data.sort_key:
		status = SlotStatus.WRONG_ROW
	return {
		"status": status,
		"row": row,
		"slot": slot,
		"position": slot_world_position(row, slot, item.radius),
	}


func reserve(row: int, index: int, item: PickableItem) -> void:
	_slots[row][index] = item
	_set_marker_visible(row, index, false)


func release(row: int, index: int) -> void:
	_slots[row][index] = null
	_set_marker_visible(row, index, true)


func is_slot_free(row: int, index: int) -> bool:
	return _slots[row][index] == null


## Destello suave en la placa de una fila.
func pulse_row(row: int, delay: float = 0.0) -> void:
	if row < 0 or row >= _plaque_mats.size():
		return
	var mat := _plaque_mats[row]
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(mat, "emission_energy_multiplier", 1.8, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 1.0).set_ease(Tween.EASE_IN_OUT)


## Pequeño salto en cadena de los objetos colocados en una fila.
func celebrate_row(row: int, delay: float = 0.0) -> void:
	for i in slots_per_row:
		var item := _slots[row][i] as PickableItem
		if item == null:
			continue
		var tw := create_tween()
		tw.tween_interval(delay + i * 0.045)
		var base_y := item.global_position.y
		tw.tween_property(item, "global_position:y", base_y + 0.02, 0.11) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(item, "global_position:y", base_y, 0.16) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# --- Construcción --------------------------------------------------------

func _build() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)

	var wood := _wood_material(wood_color)
	var back := _wood_material(back_color)
	var inner_w := unit_width - 2.0 * SIDE_T
	var total_h := base_height + rows * row_pitch + BOARD_T

	# Costados, fondo, zócalo y remate.
	for sign_x in [-1.0, 1.0]:
		_add_box(Vector3(SIDE_T, total_h, depth), Vector3(sign_x * (unit_width * 0.5 - SIDE_T * 0.5), total_h * 0.5, depth * 0.5), wood)
	_add_box(Vector3(inner_w, total_h, 0.02), Vector3(0, total_h * 0.5, 0.01), back)
	_add_box(Vector3(inner_w, base_height - BOARD_T, depth - 0.04), Vector3(0, (base_height - BOARD_T) * 0.5, (depth - 0.04) * 0.5), wood)
	_add_box(Vector3(unit_width + 0.04, BOARD_T, depth + 0.03), Vector3(0, base_height + rows * row_pitch + BOARD_T * 0.5, (depth + 0.03) * 0.5), wood)

	# Baldas y labios frontales.
	for r in rows:
		var top_y := _row_top_y(r)
		_add_box(Vector3(inner_w, BOARD_T, depth), Vector3(0, top_y - BOARD_T * 0.5, depth * 0.5), wood)
		_add_box(Vector3(inner_w, 0.018, 0.014), Vector3(0, top_y + 0.009, depth - 0.007), wood, false)

	_build_aim_volume(inner_w)
	_build_plaques()
	_build_slot_markers()


func _add_box(size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		_body.add_child(cs)


## Volumen invisible que el rayo de puntería detecta solo mientras se sostiene un objeto.
func _build_aim_volume(inner_w: float) -> void:
	var aim := StaticBody3D.new()
	aim.name = "AimVolume"
	aim.collision_layer = AIM_LAYER
	aim.collision_mask = 0
	aim.set_meta(&"shelf", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var h := rows * row_pitch
	bs.size = Vector3(inner_w, h, depth + 0.06)
	cs.shape = bs
	cs.position = Vector3(0, base_height - 0.05 + h * 0.5, (depth + 0.06) * 0.5)
	aim.add_child(cs)
	add_child(aim)


func _build_plaques() -> void:
	for r in rows:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("d9c4a0")
		mat.roughness = 0.7
		mat.emission_enabled = true
		mat.emission = Color("d9c4a0")
		mat.emission_energy_multiplier = 0.0
		_plaque_mats.append(mat)

		var y := _row_top_y(r) - BOARD_T * 0.5
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(unit_width - 2.0 * SIDE_T, 0.046, 0.008)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(0, y, depth + 0.004)
		add_child(mi)
		_plaque_meshes.append(mi)

		var label := Label3D.new()
		label.text = ""
		label.font_size = 30
		label.pixel_size = 0.0014
		label.outline_size = 0
		label.modulate = Color("3a2a1c")
		label.position = Vector3(0, y, depth + 0.0095)
		add_child(label)
		_plaque_labels.append(label)


func _build_slot_markers() -> void:
	_slot_mm = MultiMesh.new()
	_slot_mm.transform_format = MultiMesh.TRANSFORM_3D
	_slot_mm.use_colors = true
	var disc := CylinderMesh.new()
	disc.top_radius = 0.043
	disc.bottom_radius = 0.043
	disc.height = 0.002
	disc.radial_segments = 24
	disc.rings = 1
	_slot_mm.mesh = disc
	_slot_mm.instance_count = rows * slots_per_row
	for r in rows:
		for i in slots_per_row:
			var idx := r * slots_per_row + i
			_slot_mm.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(_slot_x(i), _row_top_y(r) + 0.0016, _slot_z())))
			_slot_mm.set_instance_color(idx, Color(1, 1, 1, 0))

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "SlotMarkers"
	mmi.multimesh = _slot_mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _refresh_row_visuals(row: int) -> void:
	var data := _row_data[row]
	if data == null:
		return
	var mat := _plaque_mats[row]
	mat.albedo_color = data.color
	mat.emission = data.color
	var label := _plaque_labels[row]
	label.text = data.sort_label
	label.modulate = Color("2e2118") if data.color.get_luminance() > 0.55 else Color("fff6e6")
	for i in slots_per_row:
		_set_marker_visible(row, i, _slots[row][i] == null)


func _set_marker_visible(row: int, index: int, show_marker: bool) -> void:
	var data := _row_data[row]
	var c := Color(1, 1, 1, 0)
	if show_marker and data != null:
		c = Color(data.color.r, data.color.g, data.color.b, 0.5)
	_slot_mm.set_instance_color(row * slots_per_row + index, c)


# --- Utilidades ----------------------------------------------------------

func _row_top_y(row: int) -> float:
	return base_height + row * row_pitch


func _slot_x(index: int) -> float:
	return (index - (slots_per_row - 1) * 0.5) * slot_spacing


func _slot_z() -> float:
	return depth * 0.5 + 0.02


func _nearest_free(row: int, wanted: int) -> int:
	for off in slots_per_row:
		var a := wanted - off
		var b := wanted + off
		if a >= 0 and _slots[row][a] == null:
			return a
		if b < slots_per_row and _slots[row][b] == null:
			return b
	return -1


func _no_slot() -> Dictionary:
	return {"status": SlotStatus.NONE}


func _wood_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	return m


func _on_collection_completed(sort_key: StringName) -> void:
	var row := row_for_key(sort_key)
	if row >= 0:
		pulse_row(row)
		celebrate_row(row)


func _on_room_completed() -> void:
	for r in rows:
		pulse_row(r, (rows - 1 - r) * 0.12)
		celebrate_row(r, (rows - 1 - r) * 0.12)

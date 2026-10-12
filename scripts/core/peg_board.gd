class_name PegBoard
extends StorageUnit
## Panel de pared con ganchos (tijeras, metros, reglas, cremalleras...). Cada fila acepta un
## tipo de objeto, que cuelga de los ganchos con la cara hacia delante.
## Origen: centro del borde inferior del panel, pegado a la pared (z=0), frente hacia +Z.

@export var board_width := 2.1
@export var board_height := 1.5
@export var board_bottom := 0.8
@export var row_pitch := 0.29
@export var hook_spacing := 0.24
@export var hook_length := 0.05
@export var wood_color := Color("c9a46f")

const BOARD_T := 0.03

var _tag_mats: Array[StandardMaterial3D] = []
var _tag_labels: Array[Label3D] = []
var _hook_mm: MultiMesh


func _init() -> void:
	rows = 5
	slots_per_row = 7


func row_for_list_index(i: int) -> int:
	return rows - 1 - i    # la lista se reparte de arriba abajo


## Los objetos cuelgan con el eje largo (X del modelo) hacia abajo y la cara hacia +Z.
func slot_transform(row: int, slot: int, item: PickableItem) -> Transform3D:
	var hook := to_global(Vector3(_hook_x(slot), _row_y(row), BOARD_T + hook_length * 0.6))
	var sway := deg_to_rad(float((slot * 31 + row * 13) % 5 - 2) * 1.2)
	var hang := global_basis * Basis(Vector3.BACK, deg_to_rad(-90.0) + sway) * Basis(Vector3.RIGHT, deg_to_rad(90.0))
	var origin := hook - hang * item.data.hang_offset
	return Transform3D(hang, origin)


func stand_hint(row: int, slot: int, item: PickableItem) -> Dictionary:
	var target := slot_transform(row, slot, item).origin
	var front := to_global(Vector3(_hook_x(slot), 0.0, 1.0))
	var floor_y_world := room.global_position.y if room != null else 0.0
	return {"position": Vector3(front.x, floor_y_world, front.z), "look": target}


func query_slot(ray_origin: Vector3, ray_dir: Vector3, item: PickableItem) -> Dictionary:
	var lo := to_local(ray_origin)
	var ld := global_basis.inverse() * ray_dir
	if absf(ld.z) < 0.0001:
		return _no_slot()
	var plane_z := BOARD_T + hook_length * 0.6
	var t := (plane_z - lo.z) / ld.z
	if t < 0.0:
		return _no_slot()
	var p := lo + ld * t
	if absf(p.x) > board_width * 0.5:
		return _no_slot()
	# Los objetos cuelgan bajo su gancho: se apunta a la zona bajo el gancho de la fila.
	var row_f := (p.y - (_row_y(0) - row_pitch * 0.75)) / row_pitch
	if row_f < 0.0 or row_f >= float(rows):
		return _no_slot()
	var row := int(floor(row_f))
	var wanted := clampi(roundi(p.x / hook_spacing + (slots_per_row - 1) * 0.5), 0, slots_per_row - 1)
	var slot := nearest_free_slot(row, wanted)
	var status := _status_for(row, slot, item)
	if slot < 0:
		slot = wanted
	return {
		"status": status,
		"row": row,
		"slot": slot,
		"transform": slot_transform(row, slot, item),
	}


func pulse_row(row: int, delay: float = 0.0) -> void:
	if row < 0 or row >= _tag_mats.size():
		return
	var mat := _tag_mats[row]
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(mat, "emission_energy_multiplier", 1.8, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 1.0).set_ease(Tween.EASE_IN_OUT)


# --- Construcción --------------------------------------------------------

func _build() -> void:
	var wood := MaterialLibrary.get_material(&"peg")
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(board_width, board_height, BOARD_T)
	cs.shape = bs
	cs.position = Vector3(0, board_bottom + board_height * 0.5, BOARD_T * 0.5)
	body.add_child(cs)
	add_child(body)

	_box(Vector3(board_width, board_height, BOARD_T), Vector3(0, board_bottom + board_height * 0.5, BOARD_T * 0.5), wood)
	# Marco
	var frame := MaterialLibrary.get_material(&"shelf")
	_box(Vector3(board_width + 0.06, 0.04, 0.045), Vector3(0, board_bottom + board_height + 0.02, 0.0225), frame)
	_box(Vector3(board_width + 0.06, 0.04, 0.045), Vector3(0, board_bottom - 0.02, 0.0225), frame)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.04, board_height + 0.08, 0.045), Vector3(sx * (board_width * 0.5 + 0.02), board_bottom + board_height * 0.5, 0.0225), frame)

	_build_hooks()
	_make_aim_volume(Vector3(board_width, board_height, hook_length + 0.2),
		Vector3(0, board_bottom + board_height * 0.5, BOARD_T + (hook_length + 0.2) * 0.5))
	_build_tags()


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _build_hooks() -> void:
	_hook_mm = MultiMesh.new()
	_hook_mm.transform_format = MultiMesh.TRANSFORM_3D
	_hook_mm.use_colors = true
	var peg := CylinderMesh.new()
	peg.top_radius = 0.0055
	peg.bottom_radius = 0.0055
	peg.height = hook_length
	peg.radial_segments = 8
	peg.rings = 1
	_hook_mm.mesh = peg
	_hook_mm.instance_count = rows * slots_per_row
	for r in rows:
		for s in slots_per_row:
			var xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(_hook_x(s), _row_y(r), BOARD_T + hook_length * 0.5))
			var idx := r * slots_per_row + s
			_hook_mm.set_instance_transform(idx, xf)
			_hook_mm.set_instance_color(idx, Color(0.78, 0.78, 0.82))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 1.0
	mat.roughness = 0.35
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Hooks"
	mmi.multimesh = _hook_mm
	mmi.material_override = mat
	add_child(mmi)


func _build_tags() -> void:
	for r in rows:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("d9c4a0")
		mat.roughness = 0.7
		mat.emission_enabled = true
		mat.emission = Color("d9c4a0")
		mat.emission_energy_multiplier = 0.0
		_tag_mats.append(mat)
		var tag := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.27, 0.11, 0.006)
		tag.mesh = tm
		tag.material_override = mat
		tag.position = Vector3(-board_width * 0.5 + 0.16, _row_y(r) - 0.02, BOARD_T + 0.003)
		add_child(tag)
		var label := Label3D.new()
		label.font_size = 30
		label.pixel_size = 0.0012
		label.outline_size = 0
		label.width = 210.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color("2e2118")
		label.position = Vector3(-board_width * 0.5 + 0.16, _row_y(r) - 0.02, BOARD_T + 0.0068)
		add_child(label)
		_tag_labels.append(label)


func _refresh_row_visuals(row: int) -> void:
	var data := _row_data[row]
	if data == null:
		return
	var c := data.color
	_tag_mats[row].albedo_color = c
	_tag_mats[row].emission = c
	_tag_labels[row].text = data.sort_label
	_tag_labels[row].modulate = Color("2e2118") if c.get_luminance() > 0.5 else Color("fff6e6")


func _set_marker_visible(row: int, slot: int, show_marker: bool) -> void:
	var idx := row * slots_per_row + slot
	if _row_data[row] == null:
		return
	var tint := Color(1.0, 0.86, 0.45) if show_marker else Color(0.78, 0.78, 0.82)
	_hook_mm.set_instance_color(idx, tint)


func _hook_x(slot: int) -> float:
	return (slot - (slots_per_row - 1) * 0.5) * hook_spacing + 0.16


func _row_y(row: int) -> float:
	# fila 0 = la de abajo
	return board_bottom + 0.15 + row * row_pitch

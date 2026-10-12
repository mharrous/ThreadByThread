class_name ShelfUnit
extends StorageUnit
## Estantería modular. Cada fila acepta un tipo de objeto y tiene huecos en línea.
## Medidas configurables por unidad (hilos, rollos de tela y cajas usan huecos distintos).
## Origen: centro de la base, parte trasera pegada a z=0, frente hacia +Z.

@export var unit_width := 2.1
@export var row_pitch := 0.34
@export var base_height := 0.16
@export var depth := 0.30
@export var slot_spacing := 0.13
## Radio de los discos que marcan cada hueco.
@export var marker_radius := 0.043
@export var wood_color := Color("e6c995")
@export var back_color := Color("d7b27c")

const BOARD_T := 0.06
const SIDE_T := 0.04

var _slot_mm: MultiMesh
var _plaque_mats: Array[StandardMaterial3D] = []
var _plaque_labels: Array[Label3D] = []
var _body: StaticBody3D


# --- Geometría de los huecos ---------------------------------------------

func row_for_list_index(i: int) -> int:
	return rows - 1 - i    # la lista se reparte de arriba abajo


func slot_transform(row: int, slot: int, item: PickableItem) -> Transform3D:
	var stack_h := 0.0
	for other: PickableItem in _slots[row][slot]:
		if other != item:
			stack_h += other.half_height * 2.0
	var local := Vector3(_slot_x(slot), _row_top_y(row) + stack_h + item.half_height, _slot_z())
	var yaw := item.rest_yaw
	if item.data.align_on_shelf:
		yaw = deg_to_rad(((slot * 37 + row * 11) % 7 - 3) * 0.8)   # casi recto, con un pelo de gracia
	return Transform3D(global_basis * Basis(Vector3.UP, yaw), to_global(local))


func stand_hint(row: int, slot: int, item: PickableItem) -> Dictionary:
	var target := slot_transform(row, slot, item).origin
	var front := to_global(Vector3(_slot_x(slot), 0.0, depth + 0.95))
	return {"position": Vector3(front.x, global_position.y, front.z), "look": target}


## Resuelve a qué hueco apunta un rayo.
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

	# Si existe el modelo de Blender para estas medidas se usa; si no, cajas.
	# La colisión siempre es de cajas simples.
	var model := _load_model()
	var visual := model == null
	if model != null:
		add_child(model)
		MaterialLibrary.apply(model, MaterialLibrary.get_material(&"shelf"))

	for sign_x in [-1.0, 1.0]:
		_add_box(Vector3(SIDE_T, total_h, depth), Vector3(sign_x * (unit_width * 0.5 - SIDE_T * 0.5), total_h * 0.5, depth * 0.5), wood, true, visual)
	_add_box(Vector3(inner_w, total_h, 0.02), Vector3(0, total_h * 0.5, 0.01), back, true, visual)
	_add_box(Vector3(inner_w, base_height - BOARD_T, depth - 0.04), Vector3(0, (base_height - BOARD_T) * 0.5, (depth - 0.04) * 0.5), wood, true, visual)
	_add_box(Vector3(unit_width + 0.04, BOARD_T, depth + 0.03), Vector3(0, base_height + rows * row_pitch + BOARD_T * 0.5, (depth + 0.03) * 0.5), wood, true, visual)
	for r in rows:
		var top_y := _row_top_y(r)
		_add_box(Vector3(inner_w, BOARD_T, depth), Vector3(0, top_y - BOARD_T * 0.5, depth * 0.5), wood, true, visual)
		if visual:
			_add_box(Vector3(inner_w, 0.018, 0.014), Vector3(0, top_y + 0.009, depth - 0.007), wood, false)

	var h := rows * row_pitch
	_make_aim_volume(Vector3(inner_w, h, depth + 0.06), Vector3(0, base_height - 0.05 + h * 0.5, (depth + 0.06) * 0.5))
	_build_plaques()
	_build_slot_markers()


## Instancia el modelo de Blender (shelf_<filas>x<ancho cm>x<fondo cm>.glb) si existe.
func _load_model() -> Node3D:
	if not (is_equal_approx(row_pitch, 0.34) and is_equal_approx(base_height, 0.16)):
		return null
	var path := "res://art/models/shelf_%dx%dx%d.glb" % [rows, roundi(unit_width * 100.0), roundi(depth * 100.0)]
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _add_box(size: Vector3, pos: Vector3, mat: Material, collide: bool = true, visual: bool = true) -> void:
	if visual:
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
	disc.top_radius = marker_radius
	disc.bottom_radius = marker_radius
	disc.height = 0.002
	disc.radial_segments = 20
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
		_set_marker_visible(row, i, has_room(row, i))


func _set_marker_visible(row: int, slot: int, show_marker: bool) -> void:
	var data := _row_data[row]
	var c := Color(1, 1, 1, 0)
	if show_marker and data != null:
		c = Color(data.color.r, data.color.g, data.color.b, 0.5)
	_slot_mm.set_instance_color(row * slots_per_row + slot, c)


# --- Utilidades ----------------------------------------------------------

func _row_top_y(row: int) -> float:
	return base_height + row * row_pitch


func _slot_x(index: int) -> float:
	return (index - (slots_per_row - 1) * 0.5) * slot_spacing


func _slot_z() -> float:
	return depth * 0.5 + 0.02


func _wood_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	return m

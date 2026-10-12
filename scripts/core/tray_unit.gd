class_name TrayUnit
extends StorageUnit
## Bandeja con celdas (botones, dedales, agujas...). Cada celda acepta un tipo y los
## objetos se amontonan dentro en cuadrícula con un poco de desorden. Se apoya sobre una mesa.
## Origen: centro de la base de la bandeja; la celda 0 queda a la izquierda; frente hacia +Z.

@export var cell_width := 0.19
@export var tray_depth := 0.34
@export var floor_y := 0.012
@export var columns := 3
@export var wood_color := Color("d8b98a")

const WALL_T := 0.012
const HEIGHT := 0.06
const MODEL_PATH := "res://art/models/button_tray.glb"

var _plaque_mats: Array[StandardMaterial3D] = []
var _plaque_labels: Array[Label3D] = []
var _cell_mats: Array[StandardMaterial3D] = []
var _body: StaticBody3D


func _init() -> void:
	rows = 5
	slots_per_row = 15


func slot_transform(row: int, slot: int, item: PickableItem) -> Transform3D:
	var col := slot % columns
	var line := slot / columns
	var lines := ceili(float(slots_per_row) / columns)
	# Un poco de desorden determinista para que parezca un montón y no una rejilla.
	var jx := (float((slot * 53 + row * 17) % 9) - 4.0) * 0.0016
	var jz := (float((slot * 29 + row * 31) % 9) - 4.0) * 0.0016
	var local := Vector3(
		_cell_cx(row) + (col - (columns - 1) * 0.5) * (cell_width - 0.04) / columns + jx,
		floor_y + item.half_height,
		(line - (lines - 1) * 0.5) * ((tray_depth - 0.05) / lines) + jz)
	return Transform3D(global_basis * Basis(Vector3.UP, item.rest_yaw), to_global(local))


func stand_hint(row: int, slot: int, item: PickableItem) -> Dictionary:
	var target := slot_transform(row, slot, item).origin
	var front := to_global(Vector3(_cell_cx(row) * 0.4, 0.0, tray_depth * 0.5 + 0.8))
	var floor_y_world := room.global_position.y if room != null else 0.0
	return {"position": Vector3(front.x, floor_y_world, front.z), "look": target}


func query_slot(ray_origin: Vector3, ray_dir: Vector3, item: PickableItem) -> Dictionary:
	var lo := to_local(ray_origin)
	var ld := global_basis.inverse() * ray_dir
	if absf(ld.y) < 0.0001:
		return _no_slot()
	var plane_y := floor_y + item.half_height
	var t := (plane_y - lo.y) / ld.y
	if t < 0.0:
		return _no_slot()
	var p := lo + ld * t
	var half_w := rows * cell_width * 0.5
	if absf(p.x) > half_w or absf(p.z) > tray_depth * 0.5:
		return _no_slot()
	var row := clampi(int(floor((p.x + half_w) / cell_width)), 0, rows - 1)
	var slot := first_free_slot(row)
	var status := _status_for(row, slot, item)
	if slot < 0:
		slot = 0
	return {
		"status": status,
		"row": row,
		"slot": slot,
		"transform": slot_transform(row, slot, item),
	}


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
	var width := rows * cell_width
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 1
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, floor_y, tray_depth)
	cs.shape = bs
	cs.position = Vector3(0, floor_y * 0.5, 0)
	_body.add_child(cs)
	# Paredes de la bandeja: los objetos lanzados rebotan en ellas.
	for sx in [-1.0, 1.0]:
		_add_wall(Vector3(WALL_T, HEIGHT, tray_depth), Vector3(sx * (width * 0.5 - WALL_T * 0.5), HEIGHT * 0.5, 0))
	for sz in [-1.0, 1.0]:
		_add_wall(Vector3(width, HEIGHT, WALL_T), Vector3(0, HEIGHT * 0.5, sz * (tray_depth * 0.5 - WALL_T * 0.5)))
	add_child(_body)

	var model := _load_model()
	if model != null:
		add_child(model)
		MaterialLibrary.apply(model, MaterialLibrary.get_material(&"tray"))
	else:
		_build_fallback_visual(width)

	_make_aim_volume(Vector3(width, 0.2, tray_depth), Vector3(0, 0.1, 0))
	_build_labels()


func _add_wall(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	_body.add_child(cs)


func _load_model() -> Node3D:
	if not ResourceLoader.exists(MODEL_PATH) or rows != 5:
		return null
	var scene := load(MODEL_PATH) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _build_fallback_visual(width: float) -> void:
	var mat := MaterialLibrary.get_material(&"tray")
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, floor_y, tray_depth)
	base.mesh = bm
	base.material_override = mat
	base.position = Vector3(0, floor_y * 0.5, 0)
	add_child(base)
	for r in rows + 1:
		var div := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(WALL_T, HEIGHT, tray_depth)
		div.mesh = dm
		div.material_override = mat
		div.position = Vector3(-width * 0.5 + r * cell_width, HEIGHT * 0.5, 0)
		add_child(div)
	for sz in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(width, HEIGHT, WALL_T)
		wall.mesh = wm
		wall.material_override = mat
		wall.position = Vector3(0, HEIGHT * 0.5, sz * (tray_depth * 0.5 - WALL_T * 0.5))
		add_child(wall)


func _build_labels() -> void:
	for r in rows:
		# Fondo de la celda del color de su tipo (se ve a qué celda va cada cosa); sin color hasta que se asigna el tipo.
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color(1, 1, 1, 0.0)
		floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor_mat.roughness = 0.85
		_cell_mats.append(floor_mat)
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(cell_width - 0.03, tray_depth - 0.03)
		quad.mesh = qm
		quad.material_override = floor_mat
		quad.rotation_degrees.x = -90.0
		quad.position = Vector3(_cell_cx(r), floor_y + 0.0012, 0)
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(quad)

		# Etiqueta en el borde delantero.
		var plaque_mat := StandardMaterial3D.new()
		plaque_mat.albedo_color = Color("d9c4a0")
		plaque_mat.roughness = 0.7
		plaque_mat.emission_enabled = true
		plaque_mat.emission = Color("d9c4a0")
		plaque_mat.emission_energy_multiplier = 0.0
		_plaque_mats.append(plaque_mat)
		# Etiqueta en los dos bordes largos: la bandeja está en medio de la mesa y se mira desde ambos lados.
		for side in [1.0, -1.0]:
			var plaque := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(cell_width - 0.02, 0.026, 0.004)
			plaque.mesh = pm
			plaque.material_override = plaque_mat
			plaque.position = Vector3(_cell_cx(r), HEIGHT * 0.5 - 0.005, side * (tray_depth * 0.5 + 0.002))
			add_child(plaque)
			var label := Label3D.new()
			label.font_size = 30
			label.pixel_size = 0.0007
			label.outline_size = 0
			label.modulate = Color("2e2118")
			label.position = Vector3(_cell_cx(r), HEIGHT * 0.5 - 0.005, side * (tray_depth * 0.5 + 0.0048))
			if side < 0.0:
				label.rotation.y = PI
			add_child(label)
			_plaque_labels.append(label)


func _refresh_row_visuals(row: int) -> void:
	var data := _row_data[row]
	if data == null:
		return
	_plaque_mats[row].albedo_color = data.color
	_plaque_mats[row].emission = _plaque_mats[row].albedo_color
	var lum := _plaque_mats[row].albedo_color.get_luminance()
	for label in [_plaque_labels[row * 2], _plaque_labels[row * 2 + 1]]:
		label.text = data.sort_label
		label.modulate = Color("2e2118") if lum > 0.5 else Color("fff6e6")
	# El fondo de la celda lleva el color del tipo (sin transparencia del color: el cristal también se ve).
	var c := _plaque_mats[row].albedo_color
	_cell_mats[row].albedo_color = Color(c.r, c.g, c.b, 1.0)


func _set_marker_visible(_row: int, _slot: int, _visible: bool) -> void:
	# El color de la celda no cambia al llenarse: sigue indicando a qué tipo pertenece.
	pass


func _cell_cx(row: int) -> float:
	return (row - (rows - 1) * 0.5) * cell_width

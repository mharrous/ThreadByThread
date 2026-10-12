class_name RoomShell
extends Node3D
## Geometría procedural de la mercería: suelo de tablas, paredes con ventana,
## vigas, mobiliario básico y decoración visual (MultiMesh, sin lógica por objeto).
## Es un bloqueo provisional con personalidad; en Fase 2 se sustituirá por modelos de Blender.

const ROOM_W := 6.0    # eje X
const ROOM_D := 5.0    # eje Z
const ROOM_H := 2.9
const WALL_T := 0.2

const TABLE_RECT := Rect2(1.55, 0.25, 1.25, 1.1)   # x, z, ancho, fondo
const TABLE_TOP_Y := 0.76
const LAMP_POS := Vector3(0.0, 2.25, 0.3)

## Zonas del suelo ocupadas por mobiliario (x, z, ancho, fondo).
const BLOCKED_RECTS: Array[Rect2] = [
	Rect2(1.55, 0.25, 1.25, 1.1),     # mesa
	Rect2(-2.95, 1.15, 0.95, 1.3),    # cajas de cartón
	Rect2(2.35, 1.8, 0.6, 0.65),      # maceta
	Rect2(2.3, -2.2, 0.7, 0.6),       # cajón derecho
	Rect2(-2.95, -2.2, 0.7, 0.6),     # cajón izquierdo
]

const C_WALL := Color("f5e9d3")
const C_WAINSCOT := Color("9cbfae")
const C_TRIM := Color("ead2a8")
const C_CEILING := Color("fbf3e6")
const C_BEAM := Color("c99a62")
const C_TABLE := Color("cf9a62")
const C_CRATE := Color("d6a96a")
const C_CARDBOARD := Color("c9a26c")
const C_RUG := Color("5f7fa3")
const C_RUG_BORDER := Color("f0dcb8")

var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()


static func is_blocked_floor(p: Vector2, margin: float) -> bool:
	for r in BLOCKED_RECTS:
		if r.grow(margin).has_point(p):
			return true
	return false


func _ready() -> void:
	_rng.seed = 2024
	_build_floor_and_outside()
	_build_walls()
	_build_window()
	_build_ceiling()
	_build_furniture()
	_build_sign()
	_scatter_scraps()
	_scatter_buttons()


# --- Estructura ----------------------------------------------------------

func _build_floor_and_outside() -> void:
	var tex := _make_plank_texture(Color("d9a86c"))
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = tex
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	floor_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	floor_mat.roughness = 0.62
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Capa 1 (mundo) + 16 (superficie donde se pueden dejar objetos).
	_box(self, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0, -0.1, 0), floor_mat, true, 17)


func _build_walls() -> void:
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	var wall := _mat(C_WALL, 1.0)
	var wains := _mat(C_WAINSCOT, 0.85)
	var trim := _mat(C_TRIM, 0.6)

	_box(self, Vector3(ROOM_W + 2 * WALL_T, ROOM_H, WALL_T), Vector3(0, ROOM_H * 0.5, -hd - WALL_T * 0.5), wall)
	_box(self, Vector3(ROOM_W + 2 * WALL_T, ROOM_H, WALL_T), Vector3(0, ROOM_H * 0.5, hd + WALL_T * 0.5), wall)
	_box(self, Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(hw + WALL_T * 0.5, ROOM_H * 0.5, 0), wall)

	# Pared oeste con hueco de ventana: z∈[-0.9, 0.9], y∈[0.9, 2.2].
	var wx := -hw - WALL_T * 0.5
	var side_len := hd - 0.9
	_box(self, Vector3(WALL_T, ROOM_H, side_len), Vector3(wx, ROOM_H * 0.5, -(hd + 0.9) * 0.5), wall)
	_box(self, Vector3(WALL_T, ROOM_H, side_len), Vector3(wx, ROOM_H * 0.5, (hd + 0.9) * 0.5), wall)
	_box(self, Vector3(WALL_T, 0.9, 1.8), Vector3(wx, 0.45, 0), wall)
	_box(self, Vector3(WALL_T, ROOM_H - 2.2, 1.8), Vector3(wx, (2.2 + ROOM_H) * 0.5, 0), wall)

	# Friso inferior, moldura y zócalo (solo visuales).
	_box(self, Vector3(ROOM_W, 0.9, 0.02), Vector3(0, 0.45, -hd + 0.01), wains, false)
	_box(self, Vector3(ROOM_W, 0.9, 0.02), Vector3(0, 0.45, hd - 0.01), wains, false)
	_box(self, Vector3(0.02, 0.9, ROOM_D), Vector3(hw - 0.01, 0.45, 0), wains, false)
	_box(self, Vector3(0.02, 0.9, ROOM_D), Vector3(-hw + 0.01, 0.45, 0), wains, false)

	_box(self, Vector3(ROOM_W, 0.045, 0.045), Vector3(0, 0.92, -hd + 0.0225), trim, false)
	_box(self, Vector3(ROOM_W, 0.045, 0.045), Vector3(0, 0.92, hd - 0.0225), trim, false)
	_box(self, Vector3(0.045, 0.045, ROOM_D), Vector3(hw - 0.0225, 0.92, 0), trim, false)
	_box(self, Vector3(0.045, 0.045, ROOM_D), Vector3(-hw + 0.0225, 0.92, 0), trim, false)

	_box(self, Vector3(ROOM_W, 0.11, 0.03), Vector3(0, 0.055, -hd + 0.015), trim, false)
	_box(self, Vector3(ROOM_W, 0.11, 0.03), Vector3(0, 0.055, hd - 0.015), trim, false)
	_box(self, Vector3(0.03, 0.11, ROOM_D), Vector3(hw - 0.015, 0.055, 0), trim, false)
	_box(self, Vector3(0.03, 0.11, ROOM_D), Vector3(-hw + 0.015, 0.055, 0), trim, false)


func _build_window() -> void:
	var hw := ROOM_W * 0.5
	var frame := _mat(Color("f3e4c8"), 0.55)
	var x := -hw - 0.03
	# Marco
	_box(self, Vector3(0.1, 0.07, 1.96), Vector3(x, 2.2 + 0.03, 0), frame, false)
	_box(self, Vector3(0.1, 1.3, 0.07), Vector3(x, 1.55, -0.92), frame, false)
	_box(self, Vector3(0.1, 1.3, 0.07), Vector3(x, 1.55, 0.92), frame, false)
	# Travesaños
	_box(self, Vector3(0.05, 1.3, 0.045), Vector3(x, 1.55, 0), frame, false)
	_box(self, Vector3(0.05, 0.045, 1.8), Vector3(x, 1.55, 0), frame, false)
	# Alféizar interior
	_box(self, Vector3(0.28, 0.045, 2.06), Vector3(-hw + 0.08, 0.915, 0), frame, false)
	# Cristal
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.93, 1.0, 0.10)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	# Con colisión: los objetos lanzados rebotan en el cristal en vez de salir volando.
	_box(self, Vector3(0.04, 1.3, 1.8), Vector3(-hw - 0.1, 1.55, 0), glass, true, 1, false)


func _build_ceiling() -> void:
	_box(self, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0, ROOM_H + 0.1, 0), _mat(C_CEILING, 1.0), true)
	var beam := _mat(C_BEAM, 0.7)
	for bx in [-1.7, 1.7]:
		_box(self, Vector3(0.2, 0.17, ROOM_D), Vector3(bx, ROOM_H - 0.085, 0), beam, false)
	# Lámpara colgante
	var cord := _mat(Color("5a4630"), 0.8)
	_box(self, Vector3(0.012, ROOM_H - LAMP_POS.y - 0.15, 0.012), Vector3(LAMP_POS.x, (ROOM_H + LAMP_POS.y + 0.15) * 0.5, LAMP_POS.z), cord, false, 1, false)
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.07
	cone.bottom_radius = 0.30
	cone.height = 0.24
	shade.mesh = cone
	var shade_mat := StandardMaterial3D.new()
	shade_mat.albedo_color = Color("f6dcae")
	shade_mat.roughness = 0.6
	shade_mat.emission_enabled = true
	shade_mat.emission = Color("ffd9a0")
	shade_mat.emission_energy_multiplier = 0.35
	shade.material_override = shade_mat
	shade.position = LAMP_POS + Vector3(0, 0.1, 0)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shade)
	var bulb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	bulb.mesh = sph
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color("fff1cf")
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color("ffe2a8")
	bulb_mat.emission_energy_multiplier = 3.0
	bulb.material_override = bulb_mat
	bulb.position = LAMP_POS - Vector3(0, 0.05, 0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulb)


# --- Mobiliario ----------------------------------------------------------

func _build_furniture() -> void:
	_add_rug(Vector3(-0.2, 0.0, 0.75))
	_add_table()
	_add_crate(Vector3(2.65, 0, -1.9), 0.1)
	_add_crate(Vector3(-2.62, 0, -1.92), -0.15)
	_add_cardboard_boxes()
	_add_plant(Vector3(2.65, 0, 2.1))


func _add_rug(center: Vector3) -> void:
	_box(self, Vector3(2.8, 0.012, 1.9), center + Vector3(0, 0.006, 0), _mat(C_RUG_BORDER, 1.0), false, 1, false)
	_box(self, Vector3(2.55, 0.014, 1.65), center + Vector3(0, 0.007, 0), _mat(C_RUG, 1.0), false, 1, false)
	_box(self, Vector3(2.2, 0.016, 1.3), center + Vector3(0, 0.008, 0), _mat(Color("7f9fc0"), 1.0), false, 1, false)


func _add_table() -> void:
	var top := _mat(C_TABLE, 0.6)
	var leg := _mat(C_TABLE.darkened(0.15), 0.7)
	var c := Vector2(TABLE_RECT.get_center().x, TABLE_RECT.get_center().y)
	# Tablero (capa 17: mundo + superficie donde dejar objetos)
	_box(self, Vector3(TABLE_RECT.size.x, 0.06, TABLE_RECT.size.y), Vector3(c.x, TABLE_TOP_Y - 0.03, c.y), top, true, 17)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(self, Vector3(0.07, TABLE_TOP_Y - 0.06, 0.07),
				Vector3(c.x + sx * (TABLE_RECT.size.x * 0.5 - 0.08), (TABLE_TOP_Y - 0.06) * 0.5, c.y + sz * (TABLE_RECT.size.y * 0.5 - 0.08)), leg)


func _add_crate(pos: Vector3, yaw: float) -> void:
	var wood := _mat(C_CRATE, 0.8)
	var size := Vector3(0.62, 0.32, 0.5)
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	_box(root, Vector3(size.x, 0.03, size.z), Vector3(0, 0.015, 0), wood, false)
	_box(root, Vector3(size.x, size.y, 0.025), Vector3(0, size.y * 0.5, size.z * 0.5 - 0.0125), wood, false)
	_box(root, Vector3(size.x, size.y, 0.025), Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.0125), wood, false)
	_box(root, Vector3(0.025, size.y, size.z - 0.05), Vector3(size.x * 0.5 - 0.0125, size.y * 0.5, 0), wood, false)
	_box(root, Vector3(0.025, size.y, size.z - 0.05), Vector3(-size.x * 0.5 + 0.0125, size.y * 0.5, 0), wood, false)
	# Colisión única y simple
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(cs)
	root.add_child(body)


func _add_cardboard_boxes() -> void:
	var card := _mat(C_CARDBOARD, 0.95)
	var dark := _mat(C_CARDBOARD.darkened(0.12), 0.95)
	_box(self, Vector3(0.62, 0.42, 0.5), Vector3(-2.6, 0.21, 2.0), card)
	_box(self, Vector3(0.5, 0.34, 0.42), Vector3(-2.58, 0.59, 2.02), dark)
	_box(self, Vector3(0.55, 0.3, 0.45), Vector3(-2.55, 0.15, 1.35), dark)
	var flap := _box(self, Vector3(0.55, 0.01, 0.2), Vector3(-2.55, 0.31, 1.12), card, false)
	flap.rotation_degrees.x = -35.0


func _add_plant(pos: Vector3) -> void:
	var pot := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.15
	cyl.height = 0.36
	pot.mesh = cyl
	pot.material_override = _mat(Color("c1704a"), 0.85)
	pot.position = pos + Vector3(0, 0.18, 0)
	add_child(pot)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.2
	cap.height = 0.9
	cs.shape = cap
	cs.position = pos + Vector3(0, 0.45, 0)
	body.add_child(cs)
	add_child(body)
	var leaf_mat := _mat(Color("5b9a5a"), 0.8)
	var leaf_mat2 := _mat(Color("77b36a"), 0.8)
	for i in 9:
		var leaf := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		leaf.mesh = s
		leaf.material_override = leaf_mat if i % 2 == 0 else leaf_mat2
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.03, 0.2)
		leaf.position = pos + Vector3(cos(a) * r, 0.5 + _rng.randf_range(0.0, 0.45), sin(a) * r)
		leaf.scale = Vector3(1.0, _rng.randf_range(0.8, 1.3), 1.0)
		add_child(leaf)


func _build_sign() -> void:
	var board := _mat(Color("a8703f"), 0.7)
	_box(self, Vector3(2.9, 0.46, 0.04), Vector3(0, 2.46, -ROOM_D * 0.5 + 0.02), board, false)
	var label := Label3D.new()
	label.text = "THREAD BY THREAD"
	label.font_size = 96
	label.pixel_size = 0.0028
	label.outline_size = 0
	label.modulate = Color("fff3dc")
	label.position = Vector3(0, 2.5, -ROOM_D * 0.5 + 0.045)
	add_child(label)
	var sub := Label3D.new()
	sub.text = "mercería · lanas · botones · telas"
	sub.font_size = 48
	sub.pixel_size = 0.0022
	sub.outline_size = 0
	sub.modulate = Color("f3d7a8")
	sub.position = Vector3(0, 2.34, -ROOM_D * 0.5 + 0.045)
	add_child(sub)


# --- Decoración con MultiMesh (sin nodos ni lógica por objeto) -----------

func _scatter_scraps() -> void:
	var palette: Array[Color] = [
		Color("e86a5f"), Color("f2b84b"), Color("6aa7d8"), Color("8bc080"),
		Color("c78ad6"), Color("f4ecd8"), Color("ef9fbc"),
	]
	var count := 46
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.005, 0.16)
	mm.mesh = bm
	mm.instance_count = count
	for i in count:
		var p := _random_floor_spot()
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, 0.02 + i * 0.0004, p.y))
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, palette[_rng.randi() % palette.size()])
	_add_multimesh(mm, "FabricScraps")


func _scatter_buttons() -> void:
	var palette: Array[Color] = [
		Color("f4ecd8"), Color("c9a26c"), Color("5b6ea3"), Color("d6453d"), Color("3f9a5f"),
	]
	var count := 70
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0115
	cyl.bottom_radius = 0.0115
	cyl.height = 0.004
	cyl.radial_segments = 12
	cyl.rings = 1
	mm.mesh = cyl
	mm.instance_count = count
	for i in count:
		var p := _random_floor_spot()
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, 0.022, p.y)))
		mm.set_instance_color(i, palette[_rng.randi() % palette.size()])
	_add_multimesh(mm, "LooseButtons")


func _add_multimesh(mm: MultiMesh, node_name: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


func _random_floor_spot() -> Vector2:
	for attempt in 30:
		var p := Vector2(_rng.randf_range(-2.6, 2.5), _rng.randf_range(-1.2, 2.2))
		if not is_blocked_floor(p, 0.1):
			return p
	return Vector2(0, 0)


# --- Utilidades ----------------------------------------------------------

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), roughness]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_mats[key] = m
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, collide: bool = true, layers: int = 1, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = layers
		body.collision_mask = 0
		body.position = pos
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		parent.add_child(body)
	return mi


## Textura de tablas de madera generada por código (sin ficheros externos).
func _make_plank_texture(base: Color) -> ImageTexture:
	var size := 512
	var planks := 6
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var pw := size / planks
	for i in planks:
		var tone := rng.randf_range(-0.05, 0.05)
		var c := Color(base.r + tone, base.g + tone * 0.9, base.b + tone * 0.8)
		img.fill_rect(Rect2i(i * pw, 0, pw, size), c)
		for g in 16:
			var gx := i * pw + rng.randi_range(4, pw - 5)
			var gl := rng.randi_range(60, 260)
			var gy := rng.randi_range(0, size - gl)
			img.fill_rect(Rect2i(gx, gy, 1, gl), c.darkened(rng.randf_range(0.04, 0.10)))
		img.fill_rect(Rect2i(i * pw, 0, 2, size), c.darkened(0.30))
		var seam := rng.randi_range(80, size - 80)
		img.fill_rect(Rect2i(i * pw, seam, pw, 2), c.darkened(0.26))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

class_name RoomShell
extends Node3D
## Estructura de la mercería: suelo de tablas, paredes con ventanas, friso, vigas, lámparas, cartel,
## repisa de tesoros y utilidades para amueblar. La subclase rellena `_build_furniture()` con el
## mobiliario (ver room_shell_shop.gd). Los modelos son de Blender; si falta alguno solo se omite
## la parte visual.

const WALL_T := 0.2
## Media anchura del hueco de una ventana (a lo largo de la pared).
const WINDOW_HALF := 0.9
const DOOR_HALF := 0.5
const DOOR_H := 2.15

const C_TRIM := Color("ead2a8")
const C_CEILING := Color("fbf3e6")
const C_BEAM := Color("c99a62")

@export var room_w := 12.0    # eje X
@export var room_d := 9.0     # eje Z
@export var room_h := 3.1
@export var wall_color := Color("f5e9d3")
@export var wainscot_color := Color("9cbfae")
## Centros (Z) de las ventanas de la pared oeste, que da a la calle.
@export var west_windows: Array[float] = [0.0]
## Centros (X) de las ventanas de la pared sur, que da al jardín.
@export var south_windows: Array[float] = []
## Centros (Z) de las puertas de la pared este: hueco de 1 m de ancho y 2,15 m de alto.
@export var east_doors: Array[float] = []
@export var sign_title := "THREAD BY THREAD"
@export var sign_subtitle := "mercería · lanas · botones · telas"
## Centro del cartel principal (X y altura; va en la pared norte).
@export var sign_x := 0.0
@export var sign_y := 2.35
@export var lamp_energy := 0.8
## Lámparas colgantes (posición de la bombilla). Solo las `shadow_lamps` primeras dan sombra.
@export var lamp_positions: Array[Vector3] = [Vector3(0.0, 2.45, 0.0)]
@export var shadow_lamps := 2
## Repisa de los tesoros hallados (pared sur): centro X, altura y número de huecos.
@export var display_x := 0.0
@export var display_y := 1.45
@export var display_count := 2

## Mesas donde caen objetos desordenados: {rect: Rect2 (x, z, ancho, fondo), top_y: float}.
var tables: Array[Dictionary] = []
## Zonas del suelo ocupadas por mobiliario (x, z, ancho, fondo).
var blocked_rects: Array[Rect2] = []
## Zona del suelo donde se reparten montones de objetos (se calcula con el tamaño de la sala).
var floor_bounds := Rect2()
## Sitios donde se esconden los tesoros (base del objeto, coordenadas locales). La subclase los
## define en _build_furniture(); el tesoro n-ésimo (en el orden de las secciones) va al sitio n-ésimo.
var treasure_spots: Array[Vector3] = []
## Papelitos del suelo (MultiMesh "FabricScraps"): su sitio y color. Se guardan aparte porque el
## MultiMesh no los devuelve sin servidor de render (pruebas sin ventana).
var scrap_transforms: Array[Transform3D] = []
var scrap_colors: PackedColorArray = PackedColorArray()
var lamps: Array[OmniLight3D] = []
## Cartel colgado en el cristal de la puerta de la calle (CERRADO hasta ordenar la mercería).
var door_sign: Label3D
## Hoja de la puerta de la calle (pivote en la bisagra) y su giro cerrada.
var door_leaf: Node3D
var _door_closed_yaw := 0.0

var _decor: Dictionary = {}
var _display_slots: Array[Vector3] = []
var _display_pad_mats: Array[StandardMaterial3D] = []
var _display_plates: Array[Label3D] = []
var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2024 + get_index()
	floor_bounds = Rect2(-room_w * 0.5 + 0.45, -room_d * 0.5 + 0.45, room_w - 0.9, room_d - 0.9)
	_build_floor()
	_build_walls()
	_build_windows()
	_build_ceiling()
	_build_furniture()
	_build_sign()
	_build_display_shelf()
	_build_decor()
	_build_atmosphere()


## ¿Está ocupado por mobiliario este punto del suelo (con margen)?
func is_blocked(p: Vector2, margin: float) -> bool:
	for r in blocked_rects:
		if r.grow(margin).has_point(p):
			return true
	return false


# --- Para las subclases --------------------------------------------------

func _build_furniture() -> void:
	pass


func register_table(rect: Rect2, top_y: float) -> void:
	tables.append({"rect": rect, "top_y": top_y})


# --- Estructura ----------------------------------------------------------

func _build_floor() -> void:
	# Capa 1 (mundo) + 16 (superficie donde se pueden dejar objetos).
	_box(self, Vector3(room_w + 0.4, 0.2, room_d + 0.4), Vector3(0, -0.1, 0), MaterialLibrary.get_material(&"floor"), true, 17)


## Aberturas de cada pared: {u0, u1, v0, v1} = tramo a lo largo de la pared y altura.
func _openings_for(wall: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var centers: Array[float] = []
	match wall:
		&"west":
			centers = west_windows
		&"south":
			centers = south_windows
	for c in centers:
		out.append({"u0": c - WINDOW_HALF, "u1": c + WINDOW_HALF, "v0": 0.9, "v1": 2.2})
	if wall == &"east":
		for c in east_doors:
			out.append({"u0": c - DOOR_HALF, "u1": c + DOOR_HALF, "v0": 0.0, "v1": DOOR_H})
	out.sort_custom(func(a, b): return a["u0"] < b["u0"])
	return out


func _build_walls() -> void:
	var hw := room_w * 0.5
	var hd := room_d * 0.5
	var wall := MaterialLibrary.get_tinted(&"wall", wall_color)
	var wains := MaterialLibrary.get_tinted(&"wainscot", wainscot_color)
	var trim := _mat(C_TRIM, 0.6)

	# Norte y sur cubren las esquinas; este y oeste van entre ellas.
	_wall_along(&"x", -hd - WALL_T * 0.5, -hw - WALL_T, hw + WALL_T, _openings_for(&"north"), wall)
	_wall_along(&"x", hd + WALL_T * 0.5, -hw - WALL_T, hw + WALL_T, _openings_for(&"south"), wall)
	_wall_along(&"z", hw + WALL_T * 0.5, -hd, hd, _openings_for(&"east"), wall)
	_wall_along(&"z", -hw - WALL_T * 0.5, -hd, hd, _openings_for(&"west"), wall)

	# Friso inferior, moldura y zócalo (visuales).
	for side: Array in [[&"x", -hd, 1.0, &"north"], [&"x", hd, -1.0, &"south"], [&"z", hw, -1.0, &"east"], [&"z", -hw, 1.0, &"west"]]:
		var axis: StringName = side[0]
		var fixed: float = side[1]
		var inward: float = side[2]
		var wall_name: StringName = side[3]
		var lo := -hw if axis == &"x" else -hd
		var hi := hw if axis == &"x" else hd
		for seg: Vector2 in _free_segments(lo, hi, _openings_for(wall_name), 0.5):
			var len := seg.y - seg.x
			var mid := (seg.x + seg.y) * 0.5
			_strip(axis, fixed, inward, mid, len, 0.9, 0.02, 0.45, wains)
			_strip(axis, fixed, inward, mid, len, 0.045, 0.045, 0.92, trim)
			_strip(axis, fixed, inward, mid, len, 0.11, 0.03, 0.055, trim)


## Pared completa con aberturas: tramos macizos entre aberturas y dinteles/antepechos.
func _wall_along(axis: StringName, fixed: float, lo: float, hi: float, openings: Array[Dictionary], mat: Material) -> void:
	var cursor := lo
	for o: Dictionary in openings:
		_wall_piece(axis, fixed, cursor, o["u0"], 0.0, room_h, mat)
		_wall_piece(axis, fixed, o["u0"], o["u1"], 0.0, o["v0"], mat)
		_wall_piece(axis, fixed, o["u0"], o["u1"], o["v1"], room_h, mat)
		cursor = o["u1"]
	_wall_piece(axis, fixed, cursor, hi, 0.0, room_h, mat)


func _wall_piece(axis: StringName, fixed: float, u0: float, u1: float, v0: float, v1: float, mat: Material) -> void:
	if u1 - u0 < 0.001 or v1 - v0 < 0.001:
		return
	var mid := (u0 + u1) * 0.5
	var len := u1 - u0
	var h := v1 - v0
	var y := (v0 + v1) * 0.5
	if axis == &"x":
		_box(self, Vector3(len, h, WALL_T), Vector3(mid, y, fixed), mat)
	else:
		_box(self, Vector3(WALL_T, h, len), Vector3(fixed, y, mid), mat)


## Tramos de pared sin aberturas que lleguen por debajo de `below_y`.
func _free_segments(lo: float, hi: float, openings: Array[Dictionary], below_y: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cursor := lo
	for o: Dictionary in openings:
		if o["v0"] < below_y:
			if o["u0"] > cursor:
				out.append(Vector2(cursor, o["u0"]))
			cursor = o["u1"]
	if hi > cursor:
		out.append(Vector2(cursor, hi))
	return out


func _strip(axis: StringName, fixed: float, inward: float, mid: float, len: float, h: float, t: float, y: float, mat: Material) -> void:
	if axis == &"x":
		_box(self, Vector3(len, h, t), Vector3(mid, y, fixed + inward * t * 0.5), mat, false)
	else:
		_box(self, Vector3(t, h, len), Vector3(fixed + inward * t * 0.5, y, mid), mat, false)


func _build_windows() -> void:
	for c in west_windows:
		_window(&"west", c)
	for c in south_windows:
		_window(&"south", c)


## Ventana centrada en `c` (Z en la pared oeste, X en la sur).
func _window(wall: StringName, c: float) -> void:
	var hw := room_w * 0.5
	var hd := room_d * 0.5
	var frame := _mat(Color("f3e4c8"), 0.55)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.93, 1.0, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	if wall == &"west":
		var x := -hw - 0.03
		_box(self, Vector3(0.1, 0.07, 1.96), Vector3(x, 2.2 + 0.03, c), frame, false)
		_box(self, Vector3(0.1, 1.3, 0.07), Vector3(x, 1.55, c - 0.92), frame, false)
		_box(self, Vector3(0.1, 1.3, 0.07), Vector3(x, 1.55, c + 0.92), frame, false)
		# Solo montante vertical: un travesaño a 1,55 m quedaría justo a la altura de los ojos y taparía la vista.
		_box(self, Vector3(0.05, 1.3, 0.03), Vector3(x, 1.55, c), frame, false)
		_box(self, Vector3(0.28, 0.045, 2.06), Vector3(-hw + 0.08, 0.915, c), frame, false)
		# Con colisión: los objetos lanzados rebotan en el cristal en vez de salir volando.
		_box(self, Vector3(0.04, 1.3, 1.8), Vector3(-hw - 0.1, 1.55, c), glass, true, 1, false)
	else:
		var z := hd + 0.03
		_box(self, Vector3(1.96, 0.07, 0.1), Vector3(c, 2.2 + 0.03, z), frame, false)
		_box(self, Vector3(0.07, 1.3, 0.1), Vector3(c - 0.92, 1.55, z), frame, false)
		_box(self, Vector3(0.07, 1.3, 0.1), Vector3(c + 0.92, 1.55, z), frame, false)
		# Igual que en la oeste: solo montante vertical, sin travesaño a la altura de los ojos.
		_box(self, Vector3(0.045, 1.3, 0.05), Vector3(c, 1.55, z), frame, false)
		_box(self, Vector3(2.06, 0.045, 0.28), Vector3(c, 0.915, hd - 0.08), frame, false)
		_box(self, Vector3(1.8, 1.3, 0.04), Vector3(c, 1.55, hd + 0.1), glass, true, 1, false)


func _build_ceiling() -> void:
	_box(self, Vector3(room_w + 0.4, 0.2, room_d + 0.4), Vector3(0, room_h + 0.1, 0), _mat(C_CEILING, 1.0), true)
	var beam := _mat(C_BEAM, 0.7)
	var n_beams := maxi(2, roundi(room_w / 3.0))
	for i in n_beams:
		var bx := -room_w * 0.5 + room_w * (i + 0.5) / n_beams
		_box(self, Vector3(0.2, 0.17, room_d), Vector3(bx, room_h - 0.085, 0), beam, false)
	for i in lamp_positions.size():
		_add_lamp(lamp_positions[i], i < shadow_lamps)


## Lámpara colgante con su luz: el modelo esmaltado de Blender si está; si no, un cono sencillo.
func _add_lamp(lamp_pos: Vector3, shadows: bool) -> void:
	var cord := _mat(Color("5a4630"), 0.8)
	var model := _instance_model("res://art/models/pendant_lamp.glb", lamp_pos)
	var cord_from := lamp_pos.y + (0.27 if model != null else 0.15)
	_box(self, Vector3(0.012, room_h - cord_from, 0.012), Vector3(lamp_pos.x, (room_h + cord_from) * 0.5, lamp_pos.z), cord, false, 1, false)
	if model != null:
		_no_shadows(model)
		_add_lamp_light(lamp_pos, shadows)
		return
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.07
	cone.bottom_radius = 0.30
	cone.height = 0.24
	shade.mesh = cone
	shade.material_override = _shade_material()
	shade.position = lamp_pos + Vector3(0, 0.1, 0)
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shade)
	var bulb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	bulb.mesh = sph
	bulb.material_override = _bulb_material()
	bulb.position = lamp_pos - Vector3(0, 0.05, 0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulb)
	_add_lamp_light(lamp_pos, shadows)


func _add_lamp_light(lamp_pos: Vector3, shadows: bool) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "PendantLamp"
	lamp.position = lamp_pos - Vector3(0, 0.08, 0)
	lamp.light_color = Color("ffd9a6")
	lamp.light_energy = lamp_energy
	lamp.omni_range = 7.5
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = shadows
	# Paraboloide doble: 2 pasadas de sombra en vez de 6 (con cientos de objetos en la sala se nota).
	lamp.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	lamp.light_volumetric_fog_energy = 0.4
	add_child(lamp)
	lamps.append(lamp)


func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_no_shadows(c)


func _shade_material() -> StandardMaterial3D:
	if not _mats.has("shade"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("f6dcae")
		m.roughness = 0.6
		m.emission_enabled = true
		m.emission = Color("ffd9a0")
		m.emission_energy_multiplier = 0.35
		_mats["shade"] = m
	return _mats["shade"]


func _bulb_material() -> StandardMaterial3D:
	if not _mats.has("bulb"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("fff1cf")
		m.emission_enabled = true
		m.emission = Color("ffe2a8")
		m.emission_energy_multiplier = 3.0
		_mats["bulb"] = m
	return _mats["bulb"]


func _build_sign() -> void:
	var board := _mat(Color("a8703f"), 0.7)
	_box(self, Vector3(2.9, 0.46, 0.04), Vector3(sign_x, sign_y, -room_d * 0.5 + 0.02), board, false)
	var label := Label3D.new()
	label.text = sign_title
	label.font_size = 96
	label.pixel_size = 0.0028 if sign_title.length() < 20 else 0.0021
	label.outline_size = 0
	label.modulate = Color("fff3dc")
	label.position = Vector3(sign_x, sign_y + 0.04, -room_d * 0.5 + 0.045)
	add_child(label)
	var sub := Label3D.new()
	sub.text = sign_subtitle
	sub.font_size = 48
	sub.pixel_size = 0.0022
	sub.outline_size = 0
	sub.modulate = Color("f3d7a8")
	sub.position = Vector3(sign_x, sign_y - 0.12, -room_d * 0.5 + 0.045)
	add_child(sub)


# --- Utilidades de mobiliario ---------------------------------------------

func _instance_model(path: String, pos: Vector3, yaw: float = 0.0, scale_factor: float = 1.0, material: Material = null) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("Falta el modelo %s (ejecuta art/blender/make_furniture.py)" % path)
		return null
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.position = pos
	model.rotation.y = yaw
	model.scale = Vector3.ONE * scale_factor
	add_child(model)
	if material != null:
		MaterialLibrary.apply(model, material)
	return model


func _static_box(size: Vector3, pos: Vector3, yaw: float = 0.0, layers: int = 1) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layers
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func _add_rug(center: Vector3, size: Vector2 = Vector2(2.8, 1.9)) -> void:
	# Una sola pieza con la textura tejida (orla y rombos). Sin colisión ni sombra.
	_box(self, Vector3(size.x, 0.016, size.y), center + Vector3(0, 0.008, 0), MaterialLibrary.get_material(&"rug"), false, 1, false)


## Mesa de madera; registra su tablero como zona donde caen objetos y su suelo como ocupado.
## Devuelve el centro del tablero (x, z).
func _add_table(center: Vector2, spawn_rects: Array[Rect2] = []) -> Vector2:
	var size := Vector2(1.25, 1.1)
	_instance_model("res://art/models/table.glb", Vector3(center.x, 0.0, center.y), 0.0, 1.0, MaterialLibrary.get_material(&"table"))
	var top_y := 0.76
	# Colisión: tablero (capa 17: mundo + superficie donde dejar objetos) y patas.
	_static_box(Vector3(size.x, 0.06, size.y), Vector3(center.x, top_y - 0.03, center.y), 0.0, 17)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_static_box(Vector3(0.07, top_y - 0.06, 0.07),
				Vector3(center.x + sx * (size.x * 0.5 - 0.08), (top_y - 0.06) * 0.5, center.y + sz * (size.y * 0.5 - 0.08)))
	blocked_rects.append(Rect2(center.x - size.x * 0.5, center.y - size.y * 0.5, size.x, size.y))
	if spawn_rects.is_empty():
		register_table(Rect2(center.x - size.x * 0.5, center.y - size.y * 0.5, size.x, size.y), top_y)
	else:
		for r in spawn_rects:
			register_table(r, top_y)
	return center


func _add_crate(pos: Vector3, yaw: float) -> void:
	_instance_model("res://art/models/crate.glb", pos, yaw, 1.0, MaterialLibrary.get_material(&"crate"))
	_static_box(Vector3(0.62, 0.32, 0.5), pos + Vector3(0, 0.16, 0), yaw)
	blocked_rects.append(Rect2(pos.x - 0.4, pos.z - 0.35, 0.8, 0.7))


func _add_plant(pos: Vector3) -> void:
	_instance_model("res://art/models/plant.glb", pos, 0.6)
	var cap := CylinderShape3D.new()
	cap.radius = 0.2
	cap.height = 0.9
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position = pos + Vector3(0, 0.45, 0)
	body.add_child(cs)
	add_child(body)
	blocked_rects.append(Rect2(pos.x - 0.3, pos.z - 0.3, 0.6, 0.6))


func _add_cardboard_boxes(base: Vector3) -> void:
	var card := MaterialLibrary.get_material(&"cardboard")
	var path := "res://art/models/cardboard_box.glb"
	_instance_model(path, base, 0.12, 1.0, card)
	_static_box(Vector3(0.62, 0.42, 0.5), base + Vector3(0, 0.21, 0), 0.12)
	_instance_model(path, base + Vector3(0.02, 0.42, 0.02), -0.3, 0.8, card)
	_static_box(Vector3(0.5, 0.34, 0.4), base + Vector3(0.02, 0.59, 0.02), -0.3)
	_instance_model(path, base + Vector3(0.1, 0.0, -0.65), 0.5, 0.72, card)
	_static_box(Vector3(0.45, 0.3, 0.36), base + Vector3(0.1, 0.15, -0.65), 0.5)
	blocked_rects.append(Rect2(base.x - 0.45, base.z - 1.0, 0.95, 1.5))


## Cuadro enmarcado en una pared lateral (este: x>0, oeste: x<0).
func _add_picture(wall_x: float, z: float, y: float, w: float, h: float, top: Color, mid: Color, bottom: Color) -> void:
	var inward := -1.0 if wall_x > 0.0 else 1.0
	var frame_mat := _mat(Color("b88a55"), 0.55)
	var x := wall_x + inward * 0.03
	_box(self, Vector3(0.03, h + 0.06, w + 0.06), Vector3(x, y, z), frame_mat, false)
	var art := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	art.mesh = quad
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.add_point(0.55, mid)
	grad.set_color(grad.get_point_count() - 1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.9
	art.material_override = m
	art.position = Vector3(wall_x + inward * 0.0465, y, z)
	art.rotation.y = PI * 0.5 * inward
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(art)


func _add_clock(wall_x: float, z: float, y: float) -> void:
	var inward := -1.0 if wall_x > 0.0 else 1.0
	var frame_mat := _mat(Color("b88a55"), 0.55)
	var x := wall_x + inward * 0.03
	var clock := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.16
	disc.height = 0.04
	disc.radial_segments = 32
	disc.rings = 1
	clock.mesh = disc
	clock.material_override = _mat(Color("f6ecd8"), 0.5)
	clock.position = Vector3(x - inward * 0.0, y, z)
	clock.rotation.z = PI * 0.5
	add_child(clock)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.175
	ring.rings = 32
	ring.ring_segments = 8
	rim.mesh = ring
	rim.material_override = frame_mat
	rim.position = Vector3(x + inward * 0.005, y, z)
	rim.rotation.z = PI * 0.5
	add_child(rim)
	for hand: Array in [[0.11, 0.012, 0.0], [0.075, 0.016, 2.4]]:
		var hm := _box(self, Vector3(0.008, hand[0], hand[1]), Vector3(x + inward * 0.03, y + hand[0] * 0.5 * cos(hand[2]), z + hand[0] * 0.5 * sin(hand[2])), _mat(Color("3a2a1c"), 0.5), false, 1, false)
		hm.rotation.x = hand[2]


# --- Decoración con MultiMesh (sin nodos ni lógica por objeto) -----------

func _scatter_scraps(count: int = 46) -> void:
	var palette: Array[Color] = [
		Color("e86a5f"), Color("f2b84b"), Color("6aa7d8"), Color("8bc080"),
		Color("c78ad6"), Color("f4ecd8"), Color("ef9fbc"),
	]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.005, 0.16)
	mm.mesh = bm
	mm.instance_count = count
	scrap_transforms.clear()
	scrap_colors.clear()
	for i in count:
		var p := _random_floor_spot()
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, 0.02 + i * 0.0004, p.y))
		var c := palette[_rng.randi() % palette.size()]
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, c)
		scrap_transforms.append(t)
		scrap_colors.append(c)
	_add_multimesh(mm, "FabricScraps")


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
		var p := Vector2(_rng.randf_range(floor_bounds.position.x, floor_bounds.end.x), _rng.randf_range(floor_bounds.position.y, floor_bounds.end.y))
		if not is_blocked(p, 0.1):
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


# --- Tesoros y decoración desbloqueable ------------------------------------

## Dónde se exhiben los tesoros hallados: pastillas de fieltro sobre una repisa de la pared sur
## (base del objeto, coordenadas locales). Sirven de pista de que hay algo que buscar.
func display_slot(i: int) -> Vector3:
	if _display_slots.is_empty():
		return Vector3(0.0, 1.5, room_d * 0.5 - 0.1)
	return _display_slots[i % _display_slots.size()]


func _build_display_shelf() -> void:
	var z := room_d * 0.5 - 0.11
	var x0 := display_x
	var y := display_y
	var pitch := 0.28
	var width := pitch * display_count + 0.1
	var wood := MaterialLibrary.get_material(&"shelf")
	_box(self, Vector3(width, 0.035, 0.22), Vector3(x0, y, z), wood, false)
	for sx in [-width * 0.5 + 0.1, width * 0.5 - 0.1]:
		_box(self, Vector3(0.04, 0.12, 0.2), Vector3(x0 + sx, y - 0.075, z), wood, false)
	for i in display_count:
		var sx := (i - (display_count - 1) * 0.5) * pitch
		var felt := StandardMaterial3D.new()
		felt.albedo_color = Color("2f5f58")
		felt.roughness = 0.95
		_display_pad_mats.append(felt)
		var pad := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.075
		cyl.bottom_radius = 0.075
		cyl.height = 0.006
		cyl.radial_segments = 24
		cyl.rings = 1
		pad.mesh = cyl
		pad.material_override = felt
		pad.position = Vector3(x0 + sx, y + 0.0175 + 0.003, z)
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pad)
		_display_slots.append(Vector3(x0 + sx, y + 0.0175 + 0.006, z))
		# Placa con el nombre del tesoro en el canto de la repisa (mira hacia el interior de la sala, -Z).
		var plate := Label3D.new()
		plate.font_size = 26   # huecos a 28 cm: nombres más pequeños para que no se monten
		plate.pixel_size = 0.0007
		plate.outline_size = 0
		plate.modulate = Color("3a2a1c")
		plate.rotation.y = PI
		plate.position = Vector3(x0 + sx, y, z - 0.113)
		add_child(plate)
		_display_plates.append(plate)
		# Y el mismo nombre tumbado sobre la tabla, delante de la pastilla, para leerlo desde arriba.
		var top := Label3D.new()
		top.font_size = 24
		top.pixel_size = 0.0007
		top.outline_size = 0
		top.modulate = Color("3a2a1c")
		top.rotation = Vector3(-PI * 0.5, PI, 0.0)
		top.position = Vector3(x0 + sx, y + 0.0175 + 0.002, z - 0.093)
		add_child(top)
		_display_plates.append(top)


## Cada sitio de la repisa lleva el color del tesoro que le toca (la pastilla) y su nombre en el canto,
## así se sabe qué falta por encontrar.
func set_display_slot(i: int, color: Color, text: String) -> void:
	if i < 0 or i >= _display_pad_mats.size():
		return
	_display_pad_mats[i].albedo_color = Color(color.r, color.g, color.b, 1.0)
	_display_plates[i * 2].text = text
	_display_plates[i * 2 + 1].text = text


const DECOR_LAYER_META := &"decor_layer"


## Caja de colisión de una decoración oculta: sin capa hasta que la decoración aparece.
func add_decor_body(node: Node3D, size: Vector3, pos: Vector3, layers: int = 1) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_meta(DECOR_LAYER_META, layers)
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	node.add_child(body)


## Registra una decoración oculta hasta que se desbloquee (`unlock_decor`).
func add_decor(id: StringName, node: Node3D) -> void:
	node.visible = false
	add_child(node)
	_decor[id] = node


func is_decor_unlocked(id: StringName) -> bool:
	var node := _decor.get(id) as Node3D
	return node != null and node.visible


const OPEN_LIGHT := 1.2
const DOOR_OPEN_ANGLE := deg_to_rad(95.0)


## Muestra una decoración; con `animate`, aparece con un pequeño rebote elástico.
func unlock_decor(id: StringName, animate: bool = true) -> void:
	var node := _decor.get(id) as Node3D
	if node == null or node.visible:
		return
	node.visible = true
	# Su colisión solo existe desde que se ve (ver add_decor_body).
	for body in node.find_children("*", "StaticBody3D", true, false):
		if body.has_meta(DECOR_LAYER_META):
			body.collision_layer = body.get_meta(DECOR_LAYER_META)
	if animate:
		node.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Decoración de la sala; las subclases pueden añadir más con add_decor().
## "bunting": guirnaldas de pared a pared; "open_sign": cartel de ABIERTO bajo el principal.
## Las dos son el premio por ordenar la mercería entera.
func _build_decor() -> void:
	var root := Node3D.new()
	root.name = "Bunting"
	root.position = Vector3(0.0, room_h - 0.12, 0.0)
	var palette: Array[Color] = [wainscot_color, Color("e8a0b0"), Color("f2c14e"), Color("8ec5e8"), Color("c9a2e0"), Color("f5f0e6"), wall_color.darkened(0.12)]
	var half := room_w * 0.5 - 0.04
	var i := 0
	for z in [-room_d * 0.18, room_d * 0.2]:
		root.add_child(Bunting.build(Vector3(-half, 0.0, z), Vector3(half, 0.0, z), 0.42, palette, 77 + i, _mat(Color("5a4630"), 0.8)))
		i += 1
	add_decor(&"bunting", root)
	add_decor(&"open_sign", _make_open_sign())


func _make_open_sign() -> Node3D:
	var root := Node3D.new()
	root.name = "OpenSign"
	root.position = Vector3(sign_x, sign_y - 0.42, -room_d * 0.5 + 0.03)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.24, 0.03)
	board.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2f5f58")
	m.emission_enabled = true
	m.emission = Color("2f5f58")
	m.emission_energy_multiplier = 0.25
	board.material_override = m
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board)
	var label := Label3D.new()
	label.text = "¡ABIERTO!"
	label.font_size = 72
	label.pixel_size = 0.0024
	label.outline_size = 0
	label.modulate = Color("ffe08a")
	label.position = Vector3(0, 0, 0.018)
	root.add_child(label)
	return root


## Final: las lámparas suben un poco (la tienda "se enciende") y el cartel de la puerta pasa a ABIERTO.
## Sin `animate`, de golpe.
func open_shop(animate: bool, seconds: float = 3.0) -> void:
	if door_sign != null:
		door_sign.text = "ABIERTO"
		door_sign.modulate = Color("2f7a4a")
	for lamp in lamps:
		var target := lamp_energy * OPEN_LIGHT
		if animate:
			lamp.create_tween().tween_property(lamp, "light_energy", target, seconds).set_trans(Tween.TRANS_SINE)
		else:
			lamp.light_energy = target


func is_shop_open() -> bool:
	return door_sign != null and door_sign.text == "ABIERTO"


## Abre (hacia dentro) o cierra la puerta de la calle. Devuelve el tween para esperarlo.
func swing_door(open: bool, seconds: float) -> Tween:
	if door_leaf == null:
		return null
	var tw := door_leaf.create_tween()
	var target := _door_closed_yaw + (-DOOR_OPEN_ANGLE if open else 0.0)
	tw.tween_property(door_leaf, "rotation:y", target, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT if open else Tween.EASE_IN)
	return tw


## Ángulo abierta (rad) de la puerta.
func door_open_amount() -> float:
	return absf(door_leaf.rotation.y - _door_closed_yaw) if door_leaf != null else 0.0


# --- Ambiente -----------------------------------------------------------------

## Sonda de reflejos que cubre toda la sala (barniz, metales y cristal reflejan la sala y no el cielo) y
## motas de polvo flotando en la luz que entra por la ventana oeste.
func _build_atmosphere() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "RoomReflections"
	probe.size = Vector3(room_w, room_h, room_d)
	probe.position = Vector3(0.0, room_h * 0.5, 0.0)
	probe.origin_offset = Vector3(0.0, 1.6 - room_h * 0.5, 0.0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(probe)
	for c in west_windows:
		add_child(_make_dust(Vector3(-room_w * 0.5 + 2.2, 1.55, c), Vector3(2.0, 0.75, 1.1)))


## Motas finas, lentas y casi transparentes: solo se notan a contraluz.
func _make_dust(center: Vector3, extents: Vector3) -> GPUParticles3D:
	var dust := GPUParticles3D.new()
	dust.name = "Dust"
	dust.position = center
	dust.amount = 90
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.visibility_aabb = AABB(-extents - Vector3.ONE * 0.5, (extents + Vector3.ONE * 0.5) * 2.0)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3(0.0, -0.004, 0.0)
	pm.direction = Vector3(1.0, 0.2, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.005
	pm.initial_velocity_max = 0.03
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_speed_random = 0.2
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.006, 0.006)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.93, 0.78, 0.18)
	quad.material = m
	dust.draw_pass_1 = quad
	return dust

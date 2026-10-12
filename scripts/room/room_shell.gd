class_name RoomShell
extends Node3D
## Estructura de una sala de la mercería: suelo de tablas, paredes con aberturas (puertas y
## ventanas), friso, vigas, lámpara, cartel y utilidades para amueblar. Cada sala hereda
## de esta clase y rellena `_build_furniture()` con su mobiliario (ver room_shell_*.gd).
## Los modelos son de Blender; si falta alguno solo se omite la parte visual.

const ROOM_W := 6.0    # eje X
const ROOM_D := 5.0    # eje Z
const ROOM_H := 2.9
const WALL_T := 0.2

## Puerta corredera: misma posición en todas las salas, para que encajen entre sí.
const DOOR_Z := -0.9

const C_TRIM := Color("ead2a8")
const C_CEILING := Color("fbf3e6")
const C_BEAM := Color("c99a62")

@export var wall_color := Color("f5e9d3")
@export var wainscot_color := Color("9cbfae")
@export var door_east := false
@export var door_west := false
@export var window_west := false
@export var window_south := false
@export var sign_title := "THREAD BY THREAD"
@export var sign_subtitle := "mercería · lanas · botones · telas"
@export var lamp_energy := 0.8
## Posiciones X de focos que iluminan la pared norte (estanterías).
@export var spot_xs: Array[float] = [-1.2, 1.2]

## Mesas donde caen objetos desordenados: {rect: Rect2 (x, z, ancho, fondo), top_y: float}.
var tables: Array[Dictionary] = []
## Zonas del suelo ocupadas por mobiliario (x, z, ancho, fondo).
var blocked_rects: Array[Rect2] = []
## Zona del suelo donde se reparten montones de objetos.
var floor_bounds := Rect2(-2.55, -1.15, 5.0, 3.3)
var east_door: Door
## Sitios donde se esconden los tesoros de la sala (base del objeto, coordenadas locales).
## Cada sala los define en _build_furniture(); el tesoro n-ésimo del catálogo va al sitio n-ésimo.
var treasure_spots: Array[Vector3] = []

var _decor: Dictionary = {}
var _display_slots: Array[Vector3] = []
var _display_pad_mats: Array[StandardMaterial3D] = []
var _display_plates: Array[Label3D] = []
var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2024 + get_index()
	_build_floor()
	_build_walls()
	_build_windows()
	_build_ceiling()
	_build_furniture()
	_build_sign()
	_build_display_shelf()
	_build_decor()


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
	_box(self, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0, -0.1, 0), MaterialLibrary.get_material(&"floor"), true, 17)


## Aberturas de cada pared: {u0, u1, v0, v1} = tramo a lo largo de la pared y altura.
func _openings_for(wall: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half_door := Door.WIDTH * 0.5
	match wall:
		&"east":
			if door_east:
				out.append({"u0": DOOR_Z - half_door, "u1": DOOR_Z + half_door, "v0": 0.0, "v1": Door.HEIGHT})
		&"west":
			if door_west:
				out.append({"u0": DOOR_Z - half_door, "u1": DOOR_Z + half_door, "v0": 0.0, "v1": Door.HEIGHT})
			if window_west:
				out.append({"u0": -0.9, "u1": 0.9, "v0": 0.9, "v1": 2.2})
		&"south":
			if window_south:
				out.append({"u0": -0.9, "u1": 0.9, "v0": 0.9, "v1": 2.2})
	out.sort_custom(func(a, b): return a["u0"] < b["u0"])
	return out


func _build_walls() -> void:
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	var wall := MaterialLibrary.get_tinted(&"wall", wall_color)
	var wains := MaterialLibrary.get_tinted(&"wainscot", wainscot_color)
	var trim := _mat(C_TRIM, 0.6)

	# Norte y sur cubren las esquinas; este y oeste van entre ellas.
	_wall_along(&"x", -hd - WALL_T * 0.5, -hw - WALL_T, hw + WALL_T, _openings_for(&"north"), wall)
	_wall_along(&"x", hd + WALL_T * 0.5, -hw - WALL_T, hw + WALL_T, _openings_for(&"south"), wall)
	_wall_along(&"z", hw + WALL_T * 0.5, -hd, hd, _openings_for(&"east"), wall)
	_wall_along(&"z", -hw - WALL_T * 0.5, -hd, hd, _openings_for(&"west"), wall)

	# Friso inferior, moldura y zócalo (visuales), interrumpidos por las puertas.
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

	# Marco de las puertas.
	if door_east:
		_door_frame(hw, -1.0)
	if door_west:
		_door_frame(-hw, 1.0)

	if door_east:
		east_door = Door.new()
		east_door.name = "EastDoor"
		east_door.position = Vector3(hw + WALL_T * 0.5, 0.0, DOOR_Z)
		add_child(east_door)


## Pared completa con aberturas: tramos macizos entre aberturas y dinteles/antepechos.
func _wall_along(axis: StringName, fixed: float, lo: float, hi: float, openings: Array[Dictionary], mat: Material) -> void:
	var cursor := lo
	for o: Dictionary in openings:
		_wall_piece(axis, fixed, cursor, o["u0"], 0.0, ROOM_H, mat)
		_wall_piece(axis, fixed, o["u0"], o["u1"], 0.0, o["v0"], mat)
		_wall_piece(axis, fixed, o["u0"], o["u1"], o["v1"], ROOM_H, mat)
		cursor = o["u1"]
	_wall_piece(axis, fixed, cursor, hi, 0.0, ROOM_H, mat)


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


## Jambas y dintel de una puerta en la cara interior de un muro lateral (x = ±hw).
func _door_frame(wall_x: float, inward: float) -> void:
	var frame := MaterialLibrary.get_tinted(&"shelf", Color(0.82, 0.64, 0.46))
	var half := Door.WIDTH * 0.5
	var x := wall_x + inward * 0.03
	_box(self, Vector3(0.06, Door.HEIGHT + 0.06, 0.08), Vector3(x, (Door.HEIGHT + 0.06) * 0.5, DOOR_Z - half - 0.04), frame, false)
	_box(self, Vector3(0.06, Door.HEIGHT + 0.06, 0.08), Vector3(x, (Door.HEIGHT + 0.06) * 0.5, DOOR_Z + half + 0.04), frame, false)
	_box(self, Vector3(0.06, 0.08, Door.WIDTH + 0.16), Vector3(x, Door.HEIGHT + 0.04, DOOR_Z), frame, false)


func _build_windows() -> void:
	if window_west:
		_window(&"west")
	if window_south:
		_window(&"south")


func _window(wall: StringName) -> void:
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	var frame := _mat(Color("f3e4c8"), 0.55)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.93, 1.0, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	if wall == &"west":
		var x := -hw - 0.03
		_box(self, Vector3(0.1, 0.07, 1.96), Vector3(x, 2.2 + 0.03, 0), frame, false)
		_box(self, Vector3(0.1, 1.3, 0.07), Vector3(x, 1.55, -0.92), frame, false)
		_box(self, Vector3(0.1, 1.3, 0.07), Vector3(x, 1.55, 0.92), frame, false)
		# Solo montante vertical: un travesaño a 1,55 m quedaría justo a la altura de los ojos y taparía la calle.
		_box(self, Vector3(0.05, 1.3, 0.03), Vector3(x, 1.55, 0), frame, false)
		_box(self, Vector3(0.28, 0.045, 2.06), Vector3(-hw + 0.08, 0.915, 0), frame, false)
		# Con colisión: los objetos lanzados rebotan en el cristal en vez de salir volando.
		_box(self, Vector3(0.04, 1.3, 1.8), Vector3(-hw - 0.1, 1.55, 0), glass, true, 1, false)
	else:
		var z := hd + 0.03
		_box(self, Vector3(1.96, 0.07, 0.1), Vector3(0, 2.2 + 0.03, z), frame, false)
		_box(self, Vector3(0.07, 1.3, 0.1), Vector3(-0.92, 1.55, z), frame, false)
		_box(self, Vector3(0.07, 1.3, 0.1), Vector3(0.92, 1.55, z), frame, false)
		_box(self, Vector3(0.045, 1.3, 0.05), Vector3(0, 1.55, z), frame, false)
		_box(self, Vector3(1.8, 0.045, 0.05), Vector3(0, 1.55, z), frame, false)
		_box(self, Vector3(2.06, 0.045, 0.28), Vector3(0, 0.915, hd - 0.08), frame, false)
		_box(self, Vector3(1.8, 1.3, 0.04), Vector3(0, 1.55, hd + 0.1), glass, true, 1, false)


func _build_ceiling() -> void:
	_box(self, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0, ROOM_H + 0.1, 0), _mat(C_CEILING, 1.0), true)
	var beam := _mat(C_BEAM, 0.7)
	for bx in [-1.7, 1.7]:
		_box(self, Vector3(0.2, 0.17, ROOM_D), Vector3(bx, ROOM_H - 0.085, 0), beam, false)

	# Lámpara colgante con su luz.
	var lamp_pos := Vector3(0.0, 2.25, 0.3)
	var cord := _mat(Color("5a4630"), 0.8)
	_box(self, Vector3(0.012, ROOM_H - lamp_pos.y - 0.15, 0.012), Vector3(lamp_pos.x, (ROOM_H + lamp_pos.y + 0.15) * 0.5, lamp_pos.z), cord, false, 1, false)
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
	shade.position = lamp_pos + Vector3(0, 0.1, 0)
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
	bulb.position = lamp_pos - Vector3(0, 0.05, 0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulb)

	var lamp := OmniLight3D.new()
	lamp.name = "PendantLamp"
	lamp.position = lamp_pos
	lamp.light_color = Color("ffd9a6")
	lamp.light_energy = lamp_energy
	lamp.omni_range = 9.0
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = true
	lamp.light_volumetric_fog_energy = 0.4
	add_child(lamp)

	# Focos suaves sobre las estanterías para resaltar los colores.
	for x in spot_xs:
		var spot := SpotLight3D.new()
		spot.light_color = Color("ffe2b8")
		spot.light_energy = 1.0
		spot.spot_range = 4.2
		spot.spot_angle = 52.0
		spot.spot_attenuation = 0.9
		spot.light_volumetric_fog_energy = 0.0
		spot.transform = Transform3D(
			Basis.looking_at(Vector3(0, -0.55, -1.0).normalized(), Vector3.UP),
			Vector3(x, 2.35, -0.9))
		add_child(spot)


func _build_sign() -> void:
	var board := _mat(Color("a8703f"), 0.7)
	_box(self, Vector3(2.9, 0.46, 0.04), Vector3(0, 2.46, -ROOM_D * 0.5 + 0.02), board, false)
	var label := Label3D.new()
	label.text = sign_title
	label.font_size = 96
	label.pixel_size = 0.0028 if sign_title.length() < 20 else 0.0021
	label.outline_size = 0
	label.modulate = Color("fff3dc")
	label.position = Vector3(0, 2.5, -ROOM_D * 0.5 + 0.045)
	add_child(label)
	var sub := Label3D.new()
	sub.text = sign_subtitle
	sub.font_size = 48
	sub.pixel_size = 0.0022
	sub.outline_size = 0
	sub.modulate = Color("f3d7a8")
	sub.position = Vector3(0, 2.34, -ROOM_D * 0.5 + 0.045)
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
	for i in count:
		var p := _random_floor_spot()
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, 0.02 + i * 0.0004, p.y))
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, palette[_rng.randi() % palette.size()])
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
		return Vector3(0.0, 1.5, ROOM_D * 0.5 - 0.1)
	return _display_slots[i % _display_slots.size()]


func _build_display_shelf() -> void:
	var z := ROOM_D * 0.5 - 0.11
	var x0 := -1.85
	var y := 1.45
	var wood := MaterialLibrary.get_material(&"shelf")
	_box(self, Vector3(1.1, 0.035, 0.22), Vector3(x0, y, z), wood, false)
	for sx in [-0.42, 0.42]:
		_box(self, Vector3(0.04, 0.12, 0.2), Vector3(x0 + sx, y - 0.075, z), wood, false)
	for sx in [-0.26, 0.26]:
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
		plate.font_size = 34
		plate.pixel_size = 0.0007
		plate.outline_size = 0
		plate.modulate = Color("3a2a1c")
		plate.rotation.y = PI
		plate.position = Vector3(x0 + sx, y, z - 0.113)
		add_child(plate)
		_display_plates.append(plate)


## Cada sitio de la repisa lleva el color del tesoro que le toca (la pastilla) y su nombre en el canto,
## así se sabe qué falta por encontrar.
func set_display_slot(i: int, color: Color, text: String) -> void:
	if i < 0 or i >= _display_pad_mats.size():
		return
	_display_pad_mats[i].albedo_color = Color(color.r, color.g, color.b, 1.0)
	_display_plates[i].text = text


## Registra una decoración oculta hasta que se desbloquee (`unlock_decor`).
func add_decor(id: StringName, node: Node3D) -> void:
	node.visible = false
	add_child(node)
	_decor[id] = node


func is_decor_unlocked(id: StringName) -> bool:
	var node := _decor.get(id) as Node3D
	return node != null and node.visible


## Muestra una decoración; con `animate`, aparece con un pequeño rebote elástico.
func unlock_decor(id: StringName, animate: bool = true) -> void:
	var node := _decor.get(id) as Node3D
	if node == null or node.visible:
		return
	node.visible = true
	if animate:
		node.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Decoración de la sala; las subclases pueden añadir más con add_decor().
func _build_decor() -> void:
	add_decor(&"bunting", _make_bunting())


## Guirnalda de banderines entre las dos paredes laterales: premio por ordenar la sala entera.
func _make_bunting() -> Node3D:
	var root := Node3D.new()
	root.name = "Bunting"
	root.position = Vector3(0.0, ROOM_H - 0.28, 0.0)
	var palette: Array[Color] = [wainscot_color, Color("e8a0b0"), Color("f2c14e"), Color("8ec5e8"), Color("c9a2e0"), Color("f5f0e6"), wall_color.darkened(0.12)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + get_index()

	var tri := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.075, 0.0, 0.0), Vector3(0.075, 0.0, 0.0), Vector3(0.0, -0.2, 0.0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.vertex_color_use_as_albedo = true
	flag_mat.vertex_color_is_srgb = true
	flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag_mat.roughness = 0.85

	var rows: Array[Dictionary] = [{"z": -0.6, "sag": 0.28}, {"z": 1.2, "sag": 0.22}]
	var segs := 24
	var half := ROOM_W * 0.5 - 0.04
	var flag_t: Array[Transform3D] = []
	var flag_c: Array[Color] = []
	var seg_t: Array[Transform3D] = []
	for row in rows:
		var pts: Array[Vector3] = []
		for i in segs + 1:
			var x := lerpf(-half, half, float(i) / segs)
			pts.append(Vector3(x, -float(row["sag"]) * (1.0 - pow(x / half, 2.0)), float(row["z"])))
		for i in segs:
			var a := pts[i]
			var b := pts[i + 1]
			var dir := b - a
			seg_t.append(Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, dir.length())), (a + b) * 0.5))
		for i in range(2, segs - 1, 2):
			flag_t.append(Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)), pts[i]))
			flag_c.append(palette[rng.randi() % palette.size()])

	var flags := MultiMesh.new()
	flags.transform_format = MultiMesh.TRANSFORM_3D
	flags.use_colors = true
	flags.mesh = tri
	flags.instance_count = flag_t.size()
	for i in flag_t.size():
		flags.set_instance_transform(i, flag_t[i])
		flags.set_instance_color(i, flag_c[i])
	var fm := MultiMeshInstance3D.new()
	fm.multimesh = flags
	fm.material_override = flag_mat
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fm)

	var strings := MultiMesh.new()
	strings.transform_format = MultiMesh.TRANSFORM_3D
	var sm := BoxMesh.new()
	sm.size = Vector3(0.006, 0.006, 1.0)
	strings.mesh = sm
	strings.instance_count = seg_t.size()
	for i in seg_t.size():
		strings.set_instance_transform(i, seg_t[i])
	var st := MultiMeshInstance3D.new()
	st.multimesh = strings
	st.material_override = _mat(Color("5a4630"), 0.8)
	st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(st)
	return root

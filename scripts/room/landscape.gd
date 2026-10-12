class_name Landscape
extends Node3D
## Lo que se ve por la ventana oeste de la primera sala: jardín con valla, acera, calle con vida
## (StreetLife), casas de barrio enfrente con setos y árboles, un hueco con prado, estanque,
## colinas con bruma y montañas azuladas al fondo. Se genera todo por código a partir de los
## modelos de art/models/street (Blender) y unas pocas mallas procedurales; sin colisiones ni sombras,
## así que cuesta poco y no tapa el sol que entra en la sala.
##
## Geometría (el edificio ocupa x > -3.6, la ventana mira hacia -X):
##   jardín -3.6..-4.8 | valla -4.8 | acera -7.3..-5.5 | calzada -13.3..-7.3 | acera -15.1..-13.3
##   setos -16 | jardines -15.1..-18.8 | casas con la fachada en x = -18.8 | traseras, árboles y colinas.

@export var seed_value := 7

const GROUND := -0.14
const HAZE := Color("cfe5f2")
const GRASS_A := Color("5c9642")
const GRASS_B := Color("487f34")
const ROCK := Color("6f7b8e")
const SNOW := Color("f1f5fa")
const SAND := Color("d9c79a")
const POND_CENTER := Vector2(-54.0, 3.0)

const ROAD_X0 := -13.3
const ROAD_X1 := -7.3
const WALK_W := 1.8
const STREET_HALF_LEN := 110.0
const ROAD_Y := -0.08
const WALK_TOP := 0.02
const HOUSE_FRONT_X := -18.8
const HEDGE_X := -16.0                # setos de los jardines de enfrente, junto a la acera lejana
const FENCE_X := -4.8                 # valla del jardín de la sala

## Casas de enfrente, de norte a sur. `w` = anchura de la fachada (a lo largo de Z).
const HOUSES: Array[Dictionary] = [
	{"model": "house_a", "z": -55.0, "w": 9.5, "depth": 7.0, "wall": Color("ecd9b8"), "roof": Color("b25a3c"), "door": Color("3f6a5a")},
	{"model": "house_b", "z": -41.5, "w": 11.0, "depth": 7.5, "wall": Color("d9e2e6"), "roof": Color("6d6f76"), "door": Color("8a2f2f")},
	{"model": "house_a", "z": -27.5, "w": 9.5, "depth": 7.0, "wall": Color("f2e2a8"), "roof": Color("a8482f"), "door": Color("2f4a7a")},
	{"model": "house_c", "z": -14.5, "w": 8.0, "depth": 7.0, "wall": Color("e9c6b0"), "roof": Color("7a4a3a"), "door": Color("4a6a3a")},
	{"model": "house_a", "z": 15.5, "w": 9.5, "depth": 7.0, "wall": Color("cdd9c4"), "roof": Color("a65440"), "door": Color("7a3a5a")},
	{"model": "house_b", "z": 29.0, "w": 11.0, "depth": 7.5, "wall": Color("efe6d2"), "roof": Color("8a4636"), "door": Color("2f5a7a")},
	{"model": "house_c", "z": 42.0, "w": 8.0, "depth": 7.0, "wall": Color("d6cfe0"), "roof": Color("5e6068"), "door": Color("8a5a2a")},
	{"model": "house_a", "z": 55.0, "w": 9.5, "depth": 7.0, "wall": Color("f0d9b0"), "roof": Color("b0603f"), "door": Color("3a5a6a")},
]

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _peaks := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _foliage_mat: ShaderMaterial
var _terrain_mat: ShaderMaterial
var _street_life: StreetLife


func _ready() -> void:
	_rng.seed = seed_value
	_hills.seed = seed_value
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.011
	_hills.fractal_octaves = 3
	_detail.seed = seed_value + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.08
	_peaks.seed = seed_value + 2
	_peaks.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_peaks.frequency = 0.006
	_peaks.fractal_octaves = 4

	_foliage_mat = ShaderMaterial.new()
	_foliage_mat.shader = preload("res://shaders/foliage_sway.gdshader")
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = preload("res://shaders/terrain.gdshader")
	_set_texture(_terrain_mat, "detail_tex", "res://art/textures/grass_albedo.png")
	_set_texture(_terrain_mat, "detail_nrm", "res://art/textures/grass_normal.png")

	_build_terrain(Rect2(-64.0, -STREET_HALF_LEN, 61.0, STREET_HALF_LEN * 2.0), 1.5)       # cerca: detalle fino
	_build_terrain(Rect2(-330.0, -210.0, 266.0, 420.0), 8.0)                               # lejos: colinas y montañas
	_build_pond()
	_build_street()
	_build_houses()
	_build_hedges()
	_build_street_lamps()
	_build_trees()
	_build_flowers()
	_build_fence()
	_build_fill_light()

	_street_life = StreetLife.new()
	_street_life.name = "StreetLife"
	add_child(_street_life)


func get_street_life() -> StreetLife:
	return _street_life


func height_at(x: float, z: float) -> float:
	var pd := Vector2(x - POND_CENTER.x, z - POND_CENTER.y).length_squared()
	var rough := 1.0 - _flat_weight(x, z, pd)
	var h := GROUND
	h += _hills.get_noise_2d(x, z) * 5.0 * rough
	h += _detail.get_noise_2d(x, z) * 0.28 * rough
	h -= 2.4 * exp(-pd / 110.0)
	var m := smoothstep(95.0, 215.0, -x)
	var ridge := 1.0 - absf(_peaks.get_noise_2d(x, z))
	h += m * (ridge * ridge * 52.0 + 10.0)
	return h


## 1 donde el suelo es llano (jardines, calle, solares de las casas y alrededor del estanque).
func _flat_weight(x: float, z: float, pond_dist_sq: float) -> float:
	var street := 1.0 - smoothstep(9.0, 22.0, absf(x + 13.0))
	var plots := (1.0 - smoothstep(-34.0, -50.0, x)) * (1.0 - smoothstep(60.0, 95.0, absf(z)))
	var pond := exp(-pond_dist_sq / 500.0)
	return maxf(street, maxf(plots, pond))


# --- Terreno -------------------------------------------------------------

func _build_terrain(area: Rect2, cell: float) -> void:
	var nx := int(area.size.x / cell)
	var nz := int(area.size.y / cell)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize((nx + 1) * (nz + 1))
	normals.resize(verts.size())
	colors.resize(verts.size())
	for j in nz + 1:
		for i in nx + 1:
			var x := area.position.x + i * cell
			var z := area.position.y + j * cell
			var h := height_at(x, z)
			var idx := j * (nx + 1) + i
			verts[idx] = Vector3(x, h, z)
			var e := cell
			normals[idx] = Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()
			colors[idx] = _terrain_color(x, z, h)
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + (nx + 1)
			var dd := c + 1
			indices.append_array([a, b, c, b, dd, c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = _terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _terrain_color(x: float, z: float, h: float) -> Color:
	var n := _detail.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var c := GRASS_A.lerp(GRASS_B, n)
	# Franjas de prado más claro y más oscuro.
	c = c.lerp(c.lightened(0.12), smoothstep(0.55, 0.9, _hills.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5))
	# Orilla del estanque.
	c = c.lerp(SAND, smoothstep(-0.7, -1.4, h) * 0.9)
	# Roca y nieve en altura.
	c = c.lerp(ROCK, smoothstep(22.0, 40.0, h))
	c = c.lerp(SNOW, smoothstep(46.0, 58.0, h))
	# Bruma de distancia: las colinas lejanas se funden con el cielo.
	var dist := Vector2(x + 3.0, z).length()
	return c.lerp(HAZE, smoothstep(35.0, 280.0, dist) * 0.82)


func _build_pond() -> void:
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 11.5
	disc.bottom_radius = 11.5
	disc.height = 0.02
	disc.radial_segments = 48
	disc.rings = 1
	water.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5fa8c7")
	mat.roughness = 0.06
	mat.metallic = 0.15
	mat.metallic_specular = 0.8
	water.material_override = mat
	water.position = Vector3(POND_CENTER.x, -1.1, POND_CENTER.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# --- Calle ---------------------------------------------------------------

func _build_street() -> void:
	var asphalt := _textured_material("asphalt", 0.22, Color(0.92, 0.92, 0.95), 0.85)
	var pavement := _textured_material("pavement", 0.4, Color(1.0, 0.98, 0.95), 0.9)
	var curb_mat := StreetAssets.flat(Color("c4c1b8"), 0.85)
	var paint_mat := StreetAssets.flat(Color("efefe6"), 0.75)
	var street_len := STREET_HALF_LEN * 2.0

	# Calzada.
	_add_box("Road", Vector3((ROAD_X0 + ROAD_X1) * 0.5, ROAD_Y - 0.05, 0.0), Vector3(ROAD_X1 - ROAD_X0, 0.1, street_len), asphalt)
	# Aceras y bordillos (la acera cercana y la lejana).
	for side in [{"x0": ROAD_X1, "x1": ROAD_X1 + WALK_W, "curb": ROAD_X1 + 0.09}, {"x0": ROAD_X0 - WALK_W, "x1": ROAD_X0, "curb": ROAD_X0 - 0.09}]:
		var cx: float = (float(side["x0"]) + float(side["x1"])) * 0.5
		_add_box("Sidewalk", Vector3(cx, WALK_TOP - 0.1, 0.0), Vector3(WALK_W, 0.2, street_len), pavement)
		_add_box("Curb", Vector3(float(side["curb"]), WALK_TOP - 0.035, 0.0), Vector3(0.18, 0.07, street_len), curb_mat)

	# Marcas viales: línea central discontinua, líneas de borde y un paso de cebra delante de la ventana.
	var mid_x := (ROAD_X0 + ROAD_X1) * 0.5
	var dashes := MultiMesh.new()
	dashes.transform_format = MultiMesh.TRANSFORM_3D
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.14, 0.012, 2.4)
	dashes.mesh = dash_mesh
	var dash_z: Array[float] = []
	var z := -STREET_HALF_LEN + 3.0
	while z < STREET_HALF_LEN:
		if absf(z - 8.0) > 3.5:    # sin discontinua sobre el paso de cebra
			dash_z.append(z)
		z += 6.0
	dashes.instance_count = dash_z.size()
	for i in dash_z.size():
		dashes.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(mid_x, ROAD_Y + 0.004, dash_z[i])))
	_add_multimesh(dashes, "RoadDashes", paint_mat)
	for edge_x in [ROAD_X0 + 0.35, ROAD_X1 - 0.35]:
		_add_box("RoadEdge", Vector3(edge_x, ROAD_Y + 0.004, 0.0), Vector3(0.1, 0.012, street_len), paint_mat)
	var stripes := MultiMesh.new()
	stripes.transform_format = MultiMesh.TRANSFORM_3D
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.5, 0.012, 3.0)
	stripes.mesh = stripe_mesh
	stripes.instance_count = 6
	for k in 6:
		stripes.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(ROAD_X0 + 0.5 + k * 1.0, ROAD_Y + 0.004, 8.0)))
	_add_multimesh(stripes, "Crosswalk", paint_mat)


func _build_houses() -> void:
	var path_mat := _textured_material("pavement", 0.4, Color(1.0, 0.98, 0.95), 0.9)
	for entry in HOUSES:
		var depth: float = entry["depth"]
		var house := StreetAssets.model(entry["model"])
		var wall_c: Color = entry["wall"]
		StreetAssets.skin(house, {
			"wall": StreetAssets.wall(wall_c),
			"roof": StreetAssets.roof(entry["roof"]),
			"door": StreetAssets.flat(entry["door"], 0.6),
		})
		# El modelo mira a +Z; girado 90° mira a +X, hacia la calle.
		house.rotation.y = PI * 0.5
		house.position = Vector3(HOUSE_FRONT_X - depth * 0.5, GROUND, float(entry["z"]))
		house.name = "House_%s_%d" % [entry["model"], int(entry["z"])]
		add_child(house)
		# Camino desde la acera hasta la puerta.
		var door_z := _door_z(entry)
		_add_box("DoorPath", Vector3((ROAD_X0 - WALK_W + HOUSE_FRONT_X) * 0.5 - 0.1, GROUND + 0.015, door_z), Vector3(absf(HOUSE_FRONT_X - (ROAD_X0 - WALK_W)) + 0.2, 0.05, 1.3), path_mat)


## Posición Z de la puerta de una casa (el modelo la coloca algo desplazada del centro).
func _door_z(entry: Dictionary) -> float:
	var width: float = entry["w"]
	var cols := 3 if width > 9.0 else 2
	var dx := (float(cols >> 1) - float(cols - 1) / 2.0) * (width / (float(cols) + 0.3))
	return float(entry["z"]) - dx     # girada +90° sobre Y, +X local pasa a -Z del mundo


func _build_hedges() -> void:
	var mesh := _first_mesh(StreetAssets.model("hedge"))
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var spots: Array[Transform3D] = []
	var colors: Array[Color] = []
	var greens: Array[Color] = [Color("3f7a35"), Color("4b8a3c"), Color("37692f"), Color("558f40")]
	var door_zs: Array[float] = []
	for entry in HOUSES:
		door_zs.append(_door_z(entry))
	var z := -66.0
	while z <= 66.0:
		var gap := false
		for dz in door_zs:
			if absf(z - dz) < 1.2:
				gap = true
		if not gap and not (z > -9.5 and z < 9.5):
			var s := _rng.randf_range(0.85, 1.25)
			var b := Basis(Vector3.UP, PI * 0.5 + _rng.randf_range(-0.05, 0.05)).scaled(Vector3(s, _rng.randf_range(0.9, 1.3), s))
			spots.append(Transform3D(b, Vector3(HEDGE_X + _rng.randf_range(-0.08, 0.08), GROUND, z)))
			colors.append(greens[_rng.randi() % greens.size()])
		z += 0.95
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
		mm.set_instance_color(i, colors[i])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	_add_multimesh(mm, "Hedges", mat, true)


func _build_street_lamps() -> void:
	# Aceras alternas: la cercana lleva el brazo hacia la calzada (−X), la lejana hacia +X.
	var near_z: Array[float] = [-45.0, -27.0, -9.0, 9.0, 27.0, 45.0]
	var far_z: Array[float] = [-54.0, -36.0, -18.0, 0.0, 18.0, 36.0, 54.0]
	for z in near_z:
		_add_lamp(Vector3(ROAD_X1 + WALK_W - 0.2, WALK_TOP, z), PI)
	for z in far_z:
		_add_lamp(Vector3(ROAD_X0 - WALK_W + 0.2, WALK_TOP, z), 0.0)


func _add_lamp(pos: Vector3, yaw: float) -> void:
	var lamp := StreetAssets.model("street_lamp")
	StreetAssets.skin(lamp)
	lamp.position = pos
	lamp.rotation.y = yaw
	add_child(lamp)


# --- Vegetación ----------------------------------------------------------

func _build_flowers() -> void:
	var palette: Array[Color] = [
		Color("f4e3f0"), Color("f2c14e"), Color("ef7f9f"), Color("ffffff"),
		Color("b79bea"), Color("f59e5b"),
	]
	# Zonas con flores: jardín de la sala, jardines de enfrente, hueco del parque y prado del fondo.
	var zones: Array[Dictionary] = [
		{"rect": Rect2(-4.7, -40.0, 1.1, 80.0), "n": 260},
		{"rect": Rect2(-18.8, -62.0, 2.8, 124.0), "n": 450},
		{"rect": Rect2(-48.0, -9.5, 26.0, 19.0), "n": 420},
		{"rect": Rect2(-80.0, -70.0, 30.0, 140.0), "n": 380},
	]
	var total := 0
	for zone in zones:
		total += int(zone["n"])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sph := SphereMesh.new()
	sph.radius = 0.045
	sph.height = 0.07
	sph.radial_segments = 6
	sph.rings = 3
	mm.mesh = sph
	mm.instance_count = total
	var placed := 0
	for zone in zones:
		var rect: Rect2 = zone["rect"]
		var wanted: int = zone["n"]
		var got := 0
		var guard := 0
		while got < wanted and guard < wanted * 8:
			guard += 1
			var x := _rng.randf_range(rect.position.x, rect.end.x)
			var z := _rng.randf_range(rect.position.y, rect.end.y)
			var h := height_at(x, z)
			if h < -0.9 or _blocked_by_house(x, z):
				continue
			var s := _rng.randf_range(0.7, 1.4)
			mm.set_instance_transform(placed, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, h + 0.08, z)))
			mm.set_instance_color(placed, palette[_rng.randi() % palette.size()])
			placed += 1
			got += 1
	mm.instance_count = placed
	_add_multimesh(mm, "Flowers", _color_material())


## Cierto si el punto cae dentro de la huella de una casa (para no plantar nada dentro).
func _blocked_by_house(x: float, z: float) -> bool:
	for entry in HOUSES:
		var depth: float = entry["depth"]
		if x < HOUSE_FRONT_X + 0.6 and x > HOUSE_FRONT_X - depth - 0.6 and absf(z - float(entry["z"])) < float(entry["w"]) * 0.5 + 0.6:
			return true
	return false


func _color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.8
	return m


func _build_trees() -> void:
	var trunk_mesh := _first_mesh(StreetAssets.model("tree_trunk"))
	var round_mesh := _first_mesh(StreetAssets.model("tree_leaves_round"))
	var tall_mesh := _first_mesh(StreetAssets.model("tree_leaves_tall"))
	if trunk_mesh == null or round_mesh == null or tall_mesh == null:
		return
	var trunks := _tree_multimesh(trunk_mesh)
	var rounds := _tree_multimesh(round_mesh)
	var talls := _tree_multimesh(tall_mesh)
	var greens: Array[Color] = [Color("3d8a3a"), Color("4c9b45"), Color("32743a"), Color("5ea64a"), Color("6aa84f")]
	var blossoms: Array[Color] = [Color("f4b6cc"), Color("f7c9d6"), Color("f2d98a")]

	var spots := _tree_spots()
	var trunk_t: Array[Transform3D] = []
	var round_t: Array[Transform3D] = []
	var round_c: Array[Color] = []
	var tall_t: Array[Transform3D] = []
	var tall_c: Array[Color] = []
	for spot in spots:
		var x: float = spot.x
		var z: float = spot.y
		var h := height_at(x, z)
		var sc := _rng.randf_range(0.8, 1.45) * float(spot.z)
		var yaw := _rng.randf() * TAU
		trunk_t.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)), Vector3(x, h, z)))
		var leaf: Color = blossoms[_rng.randi() % blossoms.size()] if _rng.randf() < 0.2 else greens[_rng.randi() % greens.size()]
		if _rng.randf() < 0.3:
			var s := Vector3(sc * 0.95, sc * _rng.randf_range(0.9, 1.15), sc * 0.95)
			tall_t.append(Transform3D(Basis(Vector3.UP, yaw).scaled(s), Vector3(x, h + 4.7 * sc, z)))
			tall_c.append(leaf.darkened(0.08))
		else:
			var s2 := Vector3(sc * 1.1, sc * 0.95, sc * 1.1)
			round_t.append(Transform3D(Basis(Vector3.UP, yaw).scaled(s2), Vector3(x, h + 3.6 * sc, z)))
			round_c.append(leaf)

	trunks.instance_count = trunk_t.size()
	for i in trunk_t.size():
		trunks.set_instance_transform(i, trunk_t[i])
		trunks.set_instance_color(i, Color(0.88 + _rng.randf() * 0.2, 0.88 + _rng.randf() * 0.15, 0.9))
	rounds.instance_count = round_t.size()
	for i in round_t.size():
		rounds.set_instance_transform(i, round_t[i])
		rounds.set_instance_color(i, round_c[i])
	talls.instance_count = tall_t.size()
	for i in tall_t.size():
		talls.set_instance_transform(i, tall_t[i])
		talls.set_instance_color(i, tall_c[i])
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.4, 0.3, 0.21)
	bark.vertex_color_use_as_albedo = true
	bark.vertex_color_is_srgb = true
	bark.roughness = 0.95
	_add_multimesh(trunks, "TreeTrunks", bark, true)
	_add_multimesh(rounds, "TreeCrownsRound", _foliage_mat, true)
	_add_multimesh(talls, "TreeCrownsTall", _foliage_mat, true)


func _tree_multimesh(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	return mm


## Lugares de los árboles como (x, z, escala). Algunos enmarcan la ventana; otros llenan los jardines.
func _tree_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = [
		# Árboles de la acera cercana (pequeños y lejos del centro de la ventana).
		Vector3(-6.4, -12.5, 0.65), Vector3(-6.4, 13.0, 0.7), Vector3(-6.4, -29.0, 0.7), Vector3(-6.4, 30.0, 0.7), Vector3(-6.4, 46.0, 0.7), Vector3(-6.4, -46.0, 0.65),
		# Hueco del parque, justo enfrente de la ventana.
		Vector3(-29.0, -3.5, 1.2), Vector3(-33.0, 4.5, 1.4), Vector3(-40.0, -1.0, 1.1), Vector3(-26.5, 7.0, 0.9),
		# Jardines de enfrente.
		Vector3(-17.4, -20.5, 0.9), Vector3(-17.2, -34.5, 0.9), Vector3(-17.3, -48.0, 1.0), Vector3(-17.4, 22.5, 0.9), Vector3(-17.3, 35.5, 0.95), Vector3(-17.6, 48.5, 0.9),
	]
	# Arboleda del fondo y entre las casas.
	var guard := 0
	while spots.size() < 62 and guard < 800:
		guard += 1
		var x := _rng.randf_range(-84.0, -33.0)
		var z := _rng.randf_range(-68.0, 68.0)
		if Vector2(x - POND_CENTER.x, z - POND_CENTER.y).length() < 14.0:
			continue
		var ok := true
		for s in spots:
			if Vector2(s.x - x, s.y - z).length() < 6.0:
				ok = false
				break
		if ok:
			spots.append(Vector3(x, z, _rng.randf_range(1.0, 1.7)))
	return spots


func _build_fence() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("f1e6d0")
	wood.roughness = 0.8
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.1, 0.9, 0.1)
	posts.mesh = post_mesh
	var zs: Array[float] = []
	var z := -44.2
	while z <= 44.2:
		zs.append(z)
		z += 1.3
	posts.instance_count = zs.size()
	for i in zs.size():
		var h := height_at(FENCE_X, zs[i])
		posts.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(FENCE_X, h + 0.45, zs[i])))
	_add_multimesh(posts, "FencePosts", wood)
	for rail_y in [0.35, 0.7]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.05, 0.06, 88.6)
		rail.mesh = rb
		rail.material_override = wood
		rail.position = Vector3(FENCE_X, height_at(FENCE_X, 0.0) + rail_y, 0.0)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rail)


## Luz de relleno solo para los objetos de la calle (capa 2): el sol de la sala entra desde el oeste
## y deja a oscuras las caras que miran a la ventana. Es casi horizontal para no sobreexponer el suelo.
func _build_fill_light() -> void:
	var fill := DirectionalLight3D.new()
	fill.name = "StreetFill"
	fill.light_color = Color("fff3de")
	fill.light_energy = 0.75
	fill.light_specular = 0.25
	fill.shadow_enabled = false
	fill.light_cull_mask = 2
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.93, -0.22, -0.2).normalized(), Vector3.UP), Vector3.ZERO)
	add_child(fill)


# --- Utilidades ----------------------------------------------------------

func _add_box(box_name: String, center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## `fill`: recibe la luz de relleno de la calle (para lo que tiene caras verticales: árboles, setos).
func _add_multimesh(mm: MultiMesh, node_name: String, mat: Material, fill := false) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if fill:
		mmi.layers = StreetAssets.FILL_LAYERS
	add_child(mmi)


## Material con textura en proyección triplanar de mundo (la malla no necesita UV).
func _textured_material(base_name: String, scale: float, tint: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	var albedo := "res://art/textures/%s_albedo.png" % base_name
	var normal := "res://art/textures/%s_normal.png" % base_name
	if ResourceLoader.exists(albedo):
		m.albedo_texture = load(albedo)
	if ResourceLoader.exists(normal):
		m.normal_enabled = true
		m.normal_texture = load(normal)
		m.normal_scale = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _set_texture(mat: ShaderMaterial, param: String, path: String) -> void:
	if ResourceLoader.exists(path):
		mat.set_shader_parameter(param, load(path))


## Primera malla de un modelo importado (los de árboles y setos tienen una sola superficie).
func _first_mesh(root: Node) -> Mesh:
	var found: Mesh = null
	if root is MeshInstance3D:
		found = (root as MeshInstance3D).mesh
	else:
		for child in root.get_children():
			found = _first_mesh(child)
			if found != null:
				break
	if root.get_parent() == null and not root.is_inside_tree():
		root.free()
	return found

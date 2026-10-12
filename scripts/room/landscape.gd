class_name Landscape
extends Node3D
## Paisaje que se ve por la ventana oeste: prado con flores, estanque, valla, árboles
## (algunos en flor), colinas con bruma, montañas azuladas al fondo y nubes que se mueven.
## Todo se genera por código: dos mallas de terreno + MultiMesh. Sin sombras ni colisiones,
## así que no cuesta casi nada y no tapa el sol que entra en la sala.

@export var seed_value := 7

const HAZE := Color("cfe5f2")
const GRASS_A := Color("5e9a3f")
const GRASS_B := Color("468433")
const ROCK := Color("6f7b8e")
const SNOW := Color("f1f5fa")
const SAND := Color("d9c79a")
const POND_CENTER := Vector2(-26.0, 10.0)

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _peaks := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _clouds: Array[Node3D] = []
var _foliage_mat: ShaderMaterial


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

	_build_terrain(Rect2(-64.0, -60.0, 61.0, 120.0), 1.5)       # cerca: detalle fino
	_build_terrain(Rect2(-330.0, -210.0, 266.0, 420.0), 8.0)    # lejos: colinas y montañas
	_build_pond()
	_build_flowers()
	_build_trees()
	_build_fence()
	_build_clouds()


func _process(delta: float) -> void:
	# Las nubes se desplazan despacio con el viento.
	for cloud in _clouds:
		cloud.position.z += delta * 1.1
		cloud.position.x += delta * 0.25
		if cloud.position.z > 220.0:
			cloud.position.z -= 440.0


func height_at(x: float, z: float) -> float:
	var d := Vector2(x + 3.0, z).length()
	var near_flat := smoothstep(7.0, 32.0, d)
	var h := -0.14
	h += _hills.get_noise_2d(x, z) * 5.0 * near_flat
	h += _detail.get_noise_2d(x, z) * 0.28 * smoothstep(3.0, 14.0, d)
	var pd := Vector2(x - POND_CENTER.x, z - POND_CENTER.y).length_squared()
	h -= 2.4 * exp(-pd / 110.0)
	var m := smoothstep(95.0, 215.0, -x)
	var ridge := 1.0 - absf(_peaks.get_noise_2d(x, z))
	h += m * (ridge * ridge * 52.0 + 10.0)
	return h


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

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
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


# --- Vegetación ----------------------------------------------------------

func _build_flowers() -> void:
	var palette: Array[Color] = [
		Color("f4e3f0"), Color("f2c14e"), Color("ef7f9f"), Color("ffffff"),
		Color("b79bea"), Color("f59e5b"),
	]
	var count := 1600
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sph := SphereMesh.new()
	sph.radius = 0.045
	sph.height = 0.07
	sph.radial_segments = 6
	sph.rings = 3
	mm.mesh = sph
	mm.instance_count = count
	var placed := 0
	var guard := 0
	while placed < count and guard < count * 8:
		guard += 1
		var x := _rng.randf_range(-48.0, -4.2)
		var z := _rng.randf_range(-38.0, 38.0)
		var h := height_at(x, z)
		if h < -0.9:
			continue
		var s := _rng.randf_range(0.7, 1.4)
		mm.set_instance_transform(placed, Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, h + 0.08, z)))
		mm.set_instance_color(placed, palette[_rng.randi() % palette.size()])
		placed += 1
	mm.instance_count = placed
	_add_multimesh(mm, "Flowers", _flower_material())


func _flower_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	return m


func _build_trees() -> void:
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.use_colors = true
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.1
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 2.2
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	trunks.mesh = trunk_mesh

	var canopies := MultiMesh.new()
	canopies.transform_format = MultiMesh.TRANSFORM_3D
	canopies.use_colors = true
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.4
	canopy_mesh.height = 2.5
	canopy_mesh.radial_segments = 10
	canopy_mesh.rings = 6
	canopies.mesh = canopy_mesh

	var greens: Array[Color] = [Color("3d8a3a"), Color("4c9b45"), Color("32743a"), Color("5ea64a")]
	var blossoms: Array[Color] = [Color("f4b6cc"), Color("f7c9d6"), Color("f2d98a")]
	var spots: Array[Vector3] = []
	var tree_count := 30
	trunks.instance_count = tree_count
	canopies.instance_count = tree_count * 2
	var t := 0
	var guard := 0
	while t < tree_count and guard < 400:
		guard += 1
		# Algunos árboles enmarcan la vista cerca de la ventana; el resto se reparte por el prado.
		var x := _rng.randf_range(-46.0, -9.0)
		var z := _rng.randf_range(-36.0, 36.0)
		if Vector2(x - POND_CENTER.x, z - POND_CENTER.y).length() < 13.5:
			continue
		var ok := true
		for s in spots:
			if Vector2(s.x - x, s.z - z).length() < 5.0:
				ok = false
				break
		if not ok:
			continue
		spots.append(Vector3(x, 0, z))
		var h := height_at(x, z)
		var sc := _rng.randf_range(0.8, 1.6)
		trunks.set_instance_transform(t, Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(x, h + 1.1 * sc, z)))
		trunks.set_instance_color(t, Color("7a5a3c"))
		var leaf: Color = blossoms[_rng.randi() % blossoms.size()] if _rng.randf() < 0.25 else greens[_rng.randi() % greens.size()]
		var big := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc * 1.1, sc * 0.9, sc * 1.1))
		canopies.set_instance_transform(t * 2, Transform3D(big, Vector3(x, h + 2.7 * sc, z)))
		canopies.set_instance_color(t * 2, leaf)
		var small := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc * 0.7, sc * 0.65, sc * 0.7))
		canopies.set_instance_transform(t * 2 + 1, Transform3D(small, Vector3(x + _rng.randf_range(-0.7, 0.7) * sc, h + 3.6 * sc, z + _rng.randf_range(-0.7, 0.7) * sc)))
		canopies.set_instance_color(t * 2 + 1, leaf.lightened(0.08))
		t += 1
	trunks.instance_count = t
	canopies.instance_count = t * 2
	_add_multimesh(trunks, "TreeTrunks", _flower_material())
	_add_multimesh(canopies, "TreeCanopies", _foliage_mat)


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
	var z := -16.0
	while z <= 16.0:
		zs.append(z)
		z += 1.3
	posts.instance_count = zs.size()
	for i in zs.size():
		var h := height_at(-6.5, zs[i])
		posts.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-6.5, h + 0.45, zs[i])))
	_add_multimesh(posts, "FencePosts", wood)
	for rail_y in [0.35, 0.7]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.05, 0.06, 32.4)
		rail.mesh = rb
		rail.material_override = wood
		rail.position = Vector3(-6.5, height_at(-6.5, 0.0) + rail_y, 0.0)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rail)


func _build_clouds() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color("eef6ff")
	mat.emission_energy_multiplier = 0.55
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 14
	puff.rings = 8
	for c in 10:
		var cloud := Node3D.new()
		cloud.position = Vector3(_rng.randf_range(-260.0, -70.0), _rng.randf_range(60.0, 120.0), _rng.randf_range(-220.0, 220.0))
		var parts := _rng.randi_range(4, 7)
		for p in parts:
			var mi := MeshInstance3D.new()
			mi.mesh = puff
			mi.material_override = mat
			var s := _rng.randf_range(9.0, 17.0)
			mi.scale = Vector3(s * 1.5, s * 0.55, s)
			mi.position = Vector3(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-2.0, 3.0), _rng.randf_range(-10.0, 10.0))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(mi)
		add_child(cloud)
		_clouds.append(cloud)


func _add_multimesh(mm: MultiMesh, node_name: String, mat: Material) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

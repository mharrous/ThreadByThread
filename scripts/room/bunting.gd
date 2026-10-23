class_name Bunting
extends RefCounted
## Guirnalda de banderines colgada entre dos puntos, con su cordel combado. Dos MultiMesh (banderines
## y tramos de cordel): cuesta lo mismo con 10 banderines que con 100.

const FLAG_SPACING := 0.26


## `a` y `b` son los extremos del cordel (coordenadas locales del nodo devuelto, que va en el origen
## de su padre). `sag` = cuánto cuelga el centro.
static func build(a: Vector3, b: Vector3, sag: float, palette: Array[Color], seed_value: int, cord_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Bunting"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

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

	var length := a.distance_to(b)
	var segs := maxi(4, int(length / (FLAG_SPACING * 0.5)))
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / segs
		var u := t * 2.0 - 1.0
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * (1.0 - u * u))
	# Los banderines miran perpendiculares al cordel (en horizontal).
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var face := Basis(along, Vector3.UP, along.cross(Vector3.UP)) if along.length() > 0.5 else Basis.IDENTITY
	var flag_t: Array[Transform3D] = []
	var flag_c: Array[Color] = []
	var seg_t: Array[Transform3D] = []
	for i in segs:
		var p := pts[i]
		var q := pts[i + 1]
		var dir := q - p
		seg_t.append(Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, dir.length())), (p + q) * 0.5))
	for i in range(2, segs - 1, 2):
		flag_t.append(Transform3D(face * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)), pts[i]))
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
	st.material_override = cord_material
	st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(st)
	return root

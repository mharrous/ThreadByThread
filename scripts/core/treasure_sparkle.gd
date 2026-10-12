class_name TreasureSparkle
extends CPUParticles3D
## Destellos dorados muy discretos sobre un tesoro escondido: lo bastante visibles para quien
## mira de cerca, sin delatar su sitio desde el otro lado de la sala.

static var _mesh: QuadMesh


func _init() -> void:
	amount = 5
	lifetime = 2.6
	preprocess = 2.6
	randomness = 1.0
	emission_shape = EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.05
	direction = Vector3.UP
	spread = 35.0
	initial_velocity_min = 0.015
	initial_velocity_max = 0.045
	gravity = Vector3.ZERO
	scale_amount_min = 0.6
	scale_amount_max = 1.3
	color_ramp = _ramp()
	mesh = _shared_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Solo se dibuja a pocos metros.
	visibility_range_end = 6.0
	visibility_range_end_margin = 1.0
	visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 0.85, 0.4, 0.0), Color(1, 0.9, 0.55, 1.0), Color(1, 0.8, 0.35, 0.7), Color(1, 0.75, 0.3, 0.0)])
	return g


static func _shared_mesh() -> QuadMesh:
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(0.035, 0.035)
		var tex := GradientTexture2D.new()
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		tex.gradient = grad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = tex
		mat.no_depth_test = false
		_mesh.material = mat
	return _mesh

class_name RoomLighting
extends Node3D
## Iluminación global del mundo: sol cálido entrando por la ventana oeste y luz ambiente cálida.
## (La lámpara y los focos de cada sala los crea su RoomShell.)

@export var sun_direction := Vector3(0.80, -0.53, 0.29)
@export var volumetric_fog := true


func _ready() -> void:
	_build_environment()
	_build_sun()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6fb4e8")
	sky_mat.sky_horizon_color = Color("d4e8f4")
	sky_mat.ground_horizon_color = Color("d4e8f4")
	sky_mat.ground_bottom_color = Color("a5c47f")
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff0dc")
	env.ambient_light_energy = 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	if volumetric_fog:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.006
		env.volumetric_fog_albedo = Color("fff2dc")
		env.volumetric_fog_length = 14.0

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("ffe9c4")
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 14.0
	sun.light_volumetric_fog_energy = 1.0
	sun.transform = Transform3D(Basis.looking_at(sun_direction.normalized(), Vector3.UP), Vector3.ZERO)
	add_child(sun)

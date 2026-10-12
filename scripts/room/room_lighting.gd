class_name RoomLighting
extends Node3D
## Iluminación acogedora: sol cálido entrando por la ventana oeste, luz ambiente
## cálida, lámpara colgante y focos suaves sobre las estanterías.

@export var sun_direction := Vector3(0.80, -0.53, 0.29)
@export var volumetric_fog := true


func _ready() -> void:
	_build_environment()
	_build_sun()
	_build_lamps()


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


func _build_lamps() -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "PendantLamp"
	lamp.position = RoomShell.LAMP_POS
	lamp.light_color = Color("ffd9a6")
	lamp.light_energy = 0.8
	lamp.omni_range = 9.0
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = true
	lamp.light_volumetric_fog_energy = 0.4
	add_child(lamp)

	# Focos suaves sobre cada estantería para resaltar los colores.
	for x in [-1.2, 1.2]:
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

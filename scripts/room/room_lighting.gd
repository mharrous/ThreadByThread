class_name RoomLighting
extends Node3D
## Iluminación global del mundo: sol cálido entrando por la ventana oeste, luz rebotada (SDFGI) y luz
## ambiente cálida. (Las lámparas y los focos los crean RoomShell y las secciones.)
## Con "Iluminación avanzada" desactivada (ajustes) se apagan SDFGI, SSAO, niebla volumétrica y brillo.

@export var sun_direction := Vector3(0.80, -0.53, 0.29)
@export var volumetric_fog := true


var _env: Environment


func _ready() -> void:
	_build_environment()
	_build_sun()
	apply_quality()
	GameSettings.changed.connect(apply_quality)


## Ambiente según la calidad elegida. Con SDFGI la luz rebota en suelo y paredes (tonos cálidos en las
## sombras), así que la luz ambiente plana baja para no lavar la imagen.
func apply_quality() -> void:
	var high := GameSettings.high_quality
	_env.sdfgi_enabled = high
	_env.ssao_enabled = high
	_env.glow_enabled = high
	_env.volumetric_fog_enabled = high and volumetric_fog
	_env.ambient_light_energy = 0.22 if high else 0.42


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("sun_dir", -sun_direction.normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	# Las nubes se mueven con TIME: la radiancia (reflejos) se refresca de a poco, una cara por fotograma.
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	_env = env
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
	# Luz rebotada en tiempo real (sin hornear): celdas finas para una sala de interior.
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.12
	env.sdfgi_energy = 1.1
	env.sdfgi_bounce_feedback = 0.45
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

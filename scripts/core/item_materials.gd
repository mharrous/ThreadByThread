class_name ItemMaterials
extends RefCounted
## Fábrica de materiales de los objetos a partir de su ItemData. Un solo material por
## tipo (se comparte entre todas las copias). Los modelos de Blender nombran sus
## superficies "main", "accent", "metal" o "glass" y aquí se decide qué material lleva cada una.

const YARN_SHADER := preload("res://shaders/yarn.gdshader")
const THREAD_SHADER := preload("res://shaders/thread.gdshader")
const FABRIC_SHADER := preload("res://shaders/fabric.gdshader")
const RIBBON_SHADER := preload("res://shaders/ribbon.gdshader")
const WOOD_TEXTURE := "res://art/textures/wood_light_albedo.png"
const CARDBOARD_TEXTURE := "res://art/textures/cardboard_albedo.png"

static var _cache: Dictionary = {}


static func surface_material(data: ItemData, surface_name: String) -> Material:
	match surface_name:
		"metal":
			return _shared(&"steel", func(): return _metal(Color(0.80, 0.81, 0.84), 0.28))
		"glass":
			return _shared(&"glass", func(): return _glass(Color(0.85, 0.95, 1.0, 0.35)))
		"accent":
			return _cached("%s:accent" % data.id, func(): return _simple(data.accent_kind, data.accent_color, data))
		_:
			return _cached("%s:main" % data.id, func(): return _main(data))


static func _cached(key: String, build: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = build.call()
	return _cache[key]


static func _shared(key: StringName, build: Callable) -> Material:
	return _cached(String(key), build)


static func _kind_of(data: ItemData) -> StringName:
	if data.material_kind != &"":
		return data.material_kind
	match data.family:
		ItemData.Family.YARN:
			return &"yarn"
		ItemData.Family.THREAD:
			return &"thread"
		ItemData.Family.FABRIC:
			return &"fabric"
		ItemData.Family.RIBBON:
			return &"ribbon"
		_:
			return &"plastic"


static func _main(data: ItemData) -> Material:
	match _kind_of(data):
		&"yarn":
			var m := ShaderMaterial.new()
			m.shader = YARN_SHADER
			m.set_shader_parameter(&"base_color", data.color)
			m.set_shader_parameter(&"thread_density", data.thread_density)
			return m
		&"thread":
			var m := ShaderMaterial.new()
			m.shader = THREAD_SHADER
			m.set_shader_parameter(&"base_color", data.color)
			m.set_shader_parameter(&"metallic_sheen", data.metallic)
			m.set_shader_parameter(&"roughness_value", data.roughness)
			return m
		&"fabric":
			var m := ShaderMaterial.new()
			m.shader = FABRIC_SHADER
			m.set_shader_parameter(&"color_a", data.color)
			m.set_shader_parameter(&"color_b", data.color_b)
			m.set_shader_parameter(&"color_c", data.color_c)
			m.set_shader_parameter(&"pattern", data.pattern)
			m.set_shader_parameter(&"pattern_scale", data.pattern_scale)
			m.set_shader_parameter(&"mapping", data.pattern_mapping)
			m.set_shader_parameter(&"roughness_value", data.roughness)
			return m
		&"ribbon":
			var m := ShaderMaterial.new()
			m.shader = RIBBON_SHADER
			m.set_shader_parameter(&"color_a", data.color)
			m.set_shader_parameter(&"color_b", data.color_b)
			m.set_shader_parameter(&"color_c", data.color_c)
			m.set_shader_parameter(&"pattern", data.pattern)
			m.set_shader_parameter(&"pattern_scale", data.pattern_scale)
			m.set_shader_parameter(&"metallic_sheen", data.metallic)
			m.set_shader_parameter(&"roughness_value", data.roughness)
			return m
		var kind:
			return _simple(kind, data.color, data)


## Materiales estándar (PBR) por tipo de superficie.
static func _simple(kind: StringName, color: Color, data: ItemData) -> Material:
	match kind:
		&"wood":
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			if ResourceLoader.exists(WOOD_TEXTURE):
				m.albedo_texture = load(WOOD_TEXTURE)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 6.0
			m.roughness = maxf(data.roughness, 0.55)
			return m
		&"metal":
			return _metal(color, data.roughness if data.roughness < 0.6 else 0.3)
		&"glass":
			return _glass(color)
		&"pearl":
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			m.metallic = 0.35
			m.roughness = 0.22
			m.clearcoat_enabled = true
			m.clearcoat = 0.7
			m.rim_enabled = true
			m.rim = 0.6
			m.rim_tint = 0.4
			return m
		&"cardboard":
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			if ResourceLoader.exists(CARDBOARD_TEXTURE):
				m.albedo_texture = load(CARDBOARD_TEXTURE)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 3.0
			m.roughness = 0.95
			return m
		&"paper":
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			m.roughness = 0.88
			return m
		&"cloth":
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			m.roughness = 0.97
			m.rim_enabled = true
			m.rim = 0.5
			m.rim_tint = 0.6
			return m
		_:  # plastic y por defecto
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			m.roughness = data.roughness if data.roughness < 0.9 else 0.35
			m.clearcoat_enabled = true
			m.clearcoat = 0.35
			m.metallic = data.metallic
			return m


static func _metal(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 1.0
	m.metallic_specular = 0.8
	m.roughness = rough
	return m


static func _glass(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.4
	return m

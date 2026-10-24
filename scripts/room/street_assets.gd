class_name StreetAssets
extends RefCounted
## Modelos y materiales de la calle (coches, personas, casas, farolas...). Los modelos de Blender
## nombran sus superficies ("paint", "glass", "tire", "skin"...) y aquí se decide qué material lleva
## cada una. Los materiales compartidos se crean una vez; la pintura y la ropa varían por ejemplar.

const DIR := "res://art/models/street/"

## Capas visuales de los objetos de la calle: la 1 (normal) y la 2, que recibe una luz de relleno
## sin sombras desde el este para que las fachadas y los coches que miran a la ventana no queden
## a contraluz (el sol de la sala entra desde el oeste).
const FILL_LAYERS := 3

static var _scenes: Dictionary = {}
static var _mats: Dictionary = {}


## Instancia un modelo de la calle por su nombre de fichero (sin .glb).
static func model(model_name: String) -> Node3D:
	if not _scenes.has(model_name):
		var path := DIR + model_name + ".glb"
		if not ResourceLoader.exists(path):
			push_warning("Falta el modelo de calle %s (ejecuta art/blender/make_street.py)" % path)
			_scenes[model_name] = null
		else:
			_scenes[model_name] = load(path)
	var scene := _scenes[model_name] as PackedScene
	if scene == null:
		return Node3D.new()
	return scene.instantiate() as Node3D


## Un nodo que sigue a un hueso del esqueleto del modelo (la mano de un peatón, la pata de un perro...).
static func bone_node(model: Node, bone_name: String) -> Node3D:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var ba := BoneAttachment3D.new()
	ba.name = bone_name
	ba.bone_name = bone_name
	skeletons[0].add_child(ba)
	return ba


## Aplica materiales por nombre de superficie a todas las mallas de un modelo; el resto usa
## los materiales compartidos de la calle. Desactiva las sombras (la calle no tapa el sol de la sala).
static func skin(node: Node, overrides: Dictionary = {}) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = FILL_LAYERS
		var mesh := mi.mesh
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			var surface_name := src.resource_name if src != null else ""
			if overrides.has(surface_name):
				mi.set_surface_override_material(i, overrides[surface_name])
			else:
				var shared := shared_material(surface_name)
				if shared != null:
					mi.set_surface_override_material(i, shared)
	for child in node.get_children():
		skin(child, overrides)


## Sin sombras y con la luz de relleno de la calle, para cualquier malla (también las que no pasan por skin()).
static func tag(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.layers = FILL_LAYERS
	for child in node.get_children():
		tag(child)


static func shared_material(surface_name: String) -> Material:
	if _mats.has(surface_name):
		return _mats[surface_name]
	var m: StandardMaterial3D = null
	match surface_name:
		"glass":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.07, 0.09, 0.12)
			m.metallic = 0.85
			m.roughness = 0.07
		"trim":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.05, 0.05, 0.06)
			m.roughness = 0.6
		"tire":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.045, 0.045, 0.05)
			m.roughness = 0.9
		"chrome":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.82, 0.83, 0.86)
			m.metallic = 1.0
			m.roughness = 0.28
		"light_front":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.96, 0.82)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.92, 0.7)
			m.emission_energy_multiplier = 0.8
		"light_rear":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.8, 0.04, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.05, 0.05)
			m.emission_energy_multiplier = 0.5
		"bark":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.34, 0.25, 0.18)
			m.roughness = 0.95
		"leaf":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.32, 0.55, 0.28)
			m.roughness = 0.9
		"hair", "shoes":
			return null
	if m != null:
		_mats[surface_name] = m
	return m


## Material de pintura de coche (metalizada con barniz).
static func paint(color: Color) -> StandardMaterial3D:
	var key := "paint@" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.55
		m.roughness = 0.3
		m.clearcoat_enabled = true
		m.clearcoat = 0.7
		m.clearcoat_roughness = 0.12
		_mats[key] = m
	return _mats[key]


## Material mate sencillo de un color (ropa, piel, pelo, pared...).
static func flat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "flat@%s@%s" % [color.to_html(), roughness]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


static func roof(color: Color) -> StandardMaterial3D:
	var key := "roof@" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		var tex := "res://art/textures/roof_tiles_albedo.png"
		if ResourceLoader.exists(tex):
			m.albedo_texture = load(tex)
		var nrm := "res://art/textures/roof_tiles_normal.png"
		if ResourceLoader.exists(nrm):
			m.normal_enabled = true
			m.normal_texture = load(nrm)
			m.normal_scale = 0.8
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.45
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = 0.8
		_mats[key] = m
	return _mats[key]


static func wall(color: Color) -> StandardMaterial3D:
	return MaterialLibrary.get_tinted(&"wall", color)

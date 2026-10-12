class_name MaterialLibrary
extends RefCounted
## Materiales compartidos de la sala, con las texturas de art/textures/ (generadas por
## tools/make_textures.gd). Una sola instancia por material: se reutiliza en todos los objetos.
## Si falta una textura, el material funciona igualmente con su color base.

const TEX := "res://art/textures/"

static var _cache: Dictionary = {}


static func get_material(key: StringName) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


## Aplica un material a todas las mallas de un modelo importado.
static func apply(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		apply(child, material)


static func _build(key: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match key:
		&"floor":
			_texture(m, "wood_planks", 0.7)
			_triplanar(m, 0.5)
			m.roughness = 0.58
		&"wall":
			_texture(m, "plaster", 0.45)
			_triplanar(m, 0.6)
			m.albedo_color = RoomShell.C_WALL
			m.roughness = 1.0
		&"wainscot":
			_texture(m, "beadboard", 0.9)
			_triplanar(m, 2.0)
			m.albedo_color = RoomShell.C_WAINSCOT
			m.roughness = 0.7
		&"shelf":
			_texture(m, "wood_light", 0.6)
			m.albedo_color = Color(1.0, 0.97, 0.92)
			m.roughness = 0.68
		&"table":
			_texture(m, "wood_light", 0.6)
			m.albedo_color = Color(0.88, 0.66, 0.48)
			m.roughness = 0.55
		&"crate":
			_texture(m, "wood_light", 0.7)
			m.albedo_color = Color(0.94, 0.78, 0.56)
			m.roughness = 0.82
		&"cardboard":
			_texture(m, "cardboard", 0.8)
			m.roughness = 0.95
		&"rug":
			_texture(m, "rug", 0.8)
			m.roughness = 1.0
		_:
			push_warning("MaterialLibrary: material desconocido '%s'" % key)
	return m


static func _texture(m: StandardMaterial3D, base_name: String, normal_scale: float) -> void:
	var albedo := TEX + base_name + "_albedo.png"
	if ResourceLoader.exists(albedo):
		m.albedo_texture = load(albedo)
	var normal := TEX + base_name + "_normal.png"
	if ResourceLoader.exists(normal):
		m.normal_enabled = true
		m.normal_texture = load(normal)
		m.normal_scale = normal_scale


## Textura en coordenadas del mundo: no se estira con el tamaño de la pieza.
static func _triplanar(m: StandardMaterial3D, tiles_per_meter: float) -> void:
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tiles_per_meter

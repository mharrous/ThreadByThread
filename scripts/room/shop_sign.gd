class_name ShopSign
extends RefCounted
## Carteles de la mercería: tablas de madera con moldura, iconos pirograbados y placas esmaltadas
## (modelos de art/blender/make_signs.py). El texto va encima en Label3D para que se traduzca: aquí se
## ajusta su tamaño para que quepa en la tabla tanto en español como en inglés.
## Los modelos nombran sus superficies ("wood", "frame", "burn", "enamel", "rim", "cord", "thread",
## "metal") y aquí se decide su material; lo que no se cambia usa el color que trae el GLB.

const DIR := "res://art/models/"
const BURN := Color("4a2c19")
const INK := Color("3b2416")
const INK_SOFT := Color("5e3f2a")
const OAK := Color(1.0, 0.9, 0.76)
const ENAMEL := Color("f6eedb")
const GREEN := Color("2f5f4f")
const BURGUNDY := Color("8e3b46")

## Icono pirograbado de cada sección.
const SECTION_ICONS := {&"yarn": "yarn", &"buttons": "button", &"fabrics": "fabric", &"store": "scissors"}

static var _scenes: Dictionary = {}
static var _mats: Dictionary = {}
static var _english: Array[Translation] = []
static var _english_loaded := false


## Instancia un modelo de cartel por su nombre de fichero (sin .glb). Sin el modelo, un nodo vacío.
static func model(model_name: String) -> Node3D:
	if not _scenes.has(model_name):
		var path := DIR + model_name + ".glb"
		if ResourceLoader.exists(path):
			_scenes[model_name] = load(path)
		else:
			push_warning("Falta el modelo %s (ejecuta art/blender/make_signs.py)" % path)
			_scenes[model_name] = null
	var scene := _scenes[model_name] as PackedScene
	if scene == null:
		return Node3D.new()
	return scene.instantiate() as Node3D


## Modelo con los materiales cambiados por nombre de superficie ({"wood": material, ...}) y sin sombra.
static func skinned(model_name: String, overrides: Dictionary = {}) -> Node3D:
	var node := model(model_name)
	_skin(node, overrides)
	return node


static func _skin(node: Node, overrides: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var surface_name := src.resource_name if src != null else ""
			if overrides.has(surface_name):
				mi.set_surface_override_material(i, overrides[surface_name])
			elif surface_name == "burn":
				mi.set_surface_override_material(i, paint(BURN, 0.95))
	for child in node.get_children():
		_skin(child, overrides)


# --- Materiales ----------------------------------------------------------------

## Madera con la veta de art/textures (la misma que las estanterías), teñida.
static func wood(tint: Color) -> Material:
	var key := "wood@" + tint.to_html()
	if not _mats.has(key):
		var m := MaterialLibrary.get_material(&"shelf").duplicate() as StandardMaterial3D
		m.albedo_color = tint
		m.roughness = 0.62
		_mats[key] = m
	return _mats[key]


## Color liso (pintura, esmalte, cordel).
static func paint(color: Color, roughness: float = 0.6) -> Material:
	var key := "paint@%s@%.2f" % [color.to_html(), roughness]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


# --- Letras ----------------------------------------------------------------------

## Label3D sin contorno que cabe en `max_size` (metros) en español y en inglés: si el texto es más
## largo, encoge `pixel_size`. Solo se ve por delante (los carteles de doble cara llevan dos).
static func label(text: String, kind: StringName, font_size: int, color: Color, pixel_size: float, max_size: Vector2) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiStyle.font(kind)
	l.font_size = font_size
	l.outline_size = 0
	l.modulate = color
	l.double_sided = false
	l.pixel_size = pixel_size
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fit(l, max_size)
	return l


## Encoge el texto de un Label3D (si hace falta) para que quepa en `max_size` en cualquier idioma.
static func fit(l: Label3D, max_size: Vector2) -> void:
	var px := Vector2.ZERO
	for s in [l.text, english(l.text)]:
		var sz := l.font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, l.font_size)
		px = px.max(sz)
	if px.x <= 0.0:
		return
	var best := minf(max_size.x / px.x, max_size.y / px.y if max_size.y > 0.0 and px.y > 0.0 else INF)
	l.pixel_size = minf(l.pixel_size, best)


## Traducción inglesa de un texto del juego (o el mismo texto si no la tiene).
static func english(text: String) -> String:
	if not _english_loaded:
		_english_loaded = true
		for path in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
			var t := load(path) as Translation
			if t != null and t.locale.begins_with("en"):
				_english.append(t)
	for t in _english:
		var msg := String(t.get_message(text))
		if msg != "":
			return msg
	return text


# --- Carteles ---------------------------------------------------------------------

## Icono pirograbado (yarn, button, fabric, scissors, box) apoyado en la cara de la tabla.
static func icon(icon_name: String, pos: Vector3, size: float = 1.0) -> Node3D:
	var node := skinned("sign_icon_" + icon_name)
	node.position = pos
	node.scale = Vector3.ONE * size
	return node

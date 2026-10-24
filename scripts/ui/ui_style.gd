class_name UiStyle
extends RefCounted
## Estilo común de la interfaz (HUD, título, pausa, final): papel crema, tinta marrón, hilo rojo y
## turquesa, fuentes redondeadas. Fuentes con licencia OFL en art/fonts (Nunito para el texto, Fredoka
## para títulos y cifras, Patrick Hand para notas escritas a mano).

const PAPER := Color("f6ecd6")
const PAPER_EDGE := Color("e3d1ad")
const INK := Color("3b2a1d")
const INK_SOFT := Color("7a634d")
const RED := Color("c4433a")
const TEAL := Color("2f7a74")
const BROWN := Color("8a6a4a")
const GOLD := Color("d9a21b")
const GOLD_INK := Color("9a6a0c")
const THREAD := Color("e0766b")
const CREAM := Color("fff4e0")
const SOFT := Color("ecdcc0")
## Fondo oscuro cálido para lo que va encima del juego (indicador de la mira, controles).
const DARK := Color(0.2, 0.13, 0.08, 0.8)

static var _fonts: Dictionary = {}


## "body" (Nunito normal), "bold" (Nunito negrita), "title" (Fredoka seminegrita), "hand" (Patrick Hand).
static func font(kind: StringName) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	match kind:
		&"hand":
			f = load("res://art/fonts/PatrickHand.ttf")
		&"title":
			f = _weighted("res://art/fonts/Fredoka.ttf", 600)
		&"bold":
			f = _weighted("res://art/fonts/Nunito.ttf", 800)
		_:
			f = _weighted("res://art/fonts/Nunito.ttf", 600)
	_fonts[kind] = f
	return f


static func _weighted(path: String, weight: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv


static func label(text: String, size: int, color: Color, kind: StringName = &"body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font(kind))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Tarjeta de papel: crema, borde algo más oscuro y una sombra suave.
static func paper(radius: int = 16, alpha: float = 0.95, margin: Vector4 = Vector4(20, 14, 20, 16)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER, alpha)
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.shadow_color = Color(0.1, 0.05, 0.0, 0.28)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	sb.anti_aliasing = true
	return sb


## Píldora oscura y cálida para textos encima del juego.
static func dark(radius: int = 14, margin: Vector4 = Vector4(14, 8, 16, 9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DARK
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.anti_aliasing = true
	return sb


## Tecla dibujada: cuadradito crema con el borde de abajo más grueso (como una tecla de verdad).
static func keycap(text: String, size: int = 15) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.border_color = Color("c9b28c")
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	sb.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", sb)
	var l := label(text, size, INK, &"title")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.name = "Key"
	p.add_child(l)
	p.custom_minimum_size = Vector2(28, 0)
	return p


## Botón cosido de los menús: píldora de color con puntadas por dentro, que crece un poco al pasar el ratón.
static func button(text: String, color: Color, size: int = 22, height: int = 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override(&"font", font(&"title"))
	b.add_theme_font_size_override(&"font_size", size)
	for state in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_disabled_color"]:
		b.add_theme_color_override(state, Color("fff6e6"))
	for state in [["normal", color], ["hover", color.lightened(0.1)], ["pressed", color.darkened(0.12)],
			["focus", color.lightened(0.1)], ["disabled", color.darkened(0.25)]]:
		var s := StyleBoxFlat.new()
		s.bg_color = state[1]
		s.set_corner_radius_all(height / 2)
		s.border_color = color.darkened(0.35)
		s.set_border_width_all(2)
		s.border_width_bottom = 4
		s.shadow_color = Color(0, 0, 0, 0.18)
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 2)
		s.anti_aliasing = true
		b.add_theme_stylebox_override(StringName(state[0]), s)
	var stitch := PauseMenu.Stitch.new()
	stitch.color = Color(1, 0.95, 0.88, 0.55)
	stitch.inset = 6.0
	stitch.radius = height * 0.5 - 6.0
	stitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(stitch)
	b.mouse_entered.connect(func(): hover_pop(b, true))
	b.mouse_exited.connect(func(): hover_pop(b, false))
	b.focus_entered.connect(func(): hover_pop(b, true))
	b.focus_exited.connect(func(): hover_pop(b, false))
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	return b


static func hover_pop(c: Control, on: bool) -> void:
	if not c.is_inside_tree():
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * (1.035 if on else 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

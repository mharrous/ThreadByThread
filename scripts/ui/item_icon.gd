class_name ItemIcon
extends Control
## Dibujo esquemático de un objeto de la mercería (ovillo, carrete, botón, tela, cinta, tijeras...)
## en los colores de su ItemData. Lo usa el libro de colecciones. Con `silhouette` se dibuja como una
## sombra con una interrogación: el tesoro que aún no se ha encontrado.
## Todo son primitivas de dibujo: sin imágenes. Las coordenadas van de 0 a 1 dentro de un cuadrado.

const TREASURE_KINDS := {
	&"tr_golden_yarn": &"yarn", &"tr_silver_yarn": &"yarn", &"tr_sapphire_button": &"button",
	&"tr_gold_spool": &"spool", &"tr_royal_ribbon": &"reel", &"tr_silk_bow": &"bow",
	&"tr_gold_thimble": &"thimble", &"tr_pearl_scissors": &"scissors",
}
const SHADOW := Color(0.30, 0.22, 0.15, 0.55)
const STEEL := Color(0.80, 0.82, 0.86)
const CREAM := Color("f6ecd6")

var data: ItemData
var silhouette := false

var _s := 56.0
var _o := Vector2.ZERO


func _init(item_data: ItemData = null, hidden: bool = false, icon_size: float = 56.0) -> void:
	data = item_data
	silhouette = hidden
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if data == null:
		return
	_s = minf(size.x, size.y)
	_o = (size - Vector2(_s, _s)) * 0.5
	# Suave sombra bajo el objeto.
	draw_set_transform(_p(0.5, 0.9), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, _s * 0.32, Color(0, 0, 0, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var base := data.color
	match _kind():
		&"yarn":
			_yarn(base)
		&"spool":
			_spool(base)
		&"button":
			_button(base)
		&"bolt":
			_bolt()
		&"folded":
			_folded()
		&"reel":
			_reel(base)
		&"bow":
			_bow(base)
		&"scissors":
			_scissors(base)
		&"tape":
			_tape(base)
		&"ruler":
			_ruler(base)
		&"zipper":
			_zipper(base)
		&"thimble":
			_thimble(base)
		&"needle_case":
			_needle_case(base)
		&"pincushion":
			_pincushion(base)
		&"chalk":
			_chalk(base)
		&"sewing_box":
			_sewing_box(base)
		&"tin":
			_tin(base)
		&"pattern":
			_pattern_envelope(base)
		&"hoop":
			_hoop()
		&"iron":
			_iron(base)
		_:
			_rect(0.2, 0.2, 0.6, 0.6, base)
	if silhouette:
		var font := ThemeDB.fallback_font
		var fs := int(_s * 0.55)
		var ts := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, _p(0.5, 0.5) + Vector2(-ts.x * 0.5, fs * 0.33), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff0c8"))


func _kind() -> StringName:
	if TREASURE_KINDS.has(data.id):
		return TREASURE_KINDS[data.id]
	var id := String(data.id)
	if id.begins_with("bolt_"):
		return &"bolt"
	if id.begins_with("fold_"):
		return &"folded"
	if id == "ribbon_bow":
		return &"bow"
	if id.begins_with("ribbon_"):
		return &"reel"
	if id.begins_with("scissors"):
		return &"scissors"
	if id.begins_with("thimble"):
		return &"thimble"
	match id:
		"tape": return &"tape"
		"ruler": return &"ruler"
		"zipper": return &"zipper"
		"needle_case": return &"needle_case"
		"pincushion": return &"pincushion"
		"chalk": return &"chalk"
		"sewing_box": return &"sewing_box"
		"sewing_tin": return &"tin"
		"pattern": return &"pattern"
		"hoop": return &"hoop"
		"iron": return &"iron"
	match data.family:
		ItemData.Family.YARN: return &"yarn"
		ItemData.Family.THREAD: return &"spool"
		ItemData.Family.BUTTON: return &"button"
	return &"generic"


# --- Ayudas de dibujo --------------------------------------------------------

func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _c(c: Color) -> Color:
	return SHADOW if silhouette else Color(c.r, c.g, c.b, 1.0)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(_p(x, y), Vector2(w, h) * _s), _c(color))


func _poly(points: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for v: Vector2 in points:
		pts.append(_p(v.x, v.y))
	draw_colored_polygon(pts, _c(color))


func _circle(x: float, y: float, r: float, color: Color) -> void:
	draw_circle(_p(x, y), r * _s, _c(color))


func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.5) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), _c(color), maxf(width * _s / 56.0, 1.0), true)


func _arc(center: Vector2, r: float, from: float, to: float, color: Color, width: float = 1.5) -> void:
	draw_arc(_p(center.x, center.y), r * _s, from, to, 20, _c(color), maxf(width * _s / 56.0, 1.0), true)


func _ellipse(cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var pts: Array = []
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	_poly(pts, color)


# --- Objetos -----------------------------------------------------------------

func _yarn(base: Color) -> void:
	_circle(0.5, 0.52, 0.34, base)
	_circle(0.4, 0.4, 0.1, base.lightened(0.3))
	var dark := base.darkened(0.3)
	for k in 5:
		var a := -0.4 + float(k) * 0.9
		_arc(Vector2(0.5, 0.52) + Vector2(cos(a), sin(a)) * 0.28, 0.3, a + PI * 0.62, a + PI * 1.38, dark, 1.6)
	# Hebra suelta.
	var tail := PackedVector2Array()
	for i in 10:
		var t := float(i) / 9.0
		tail.append(_p(0.74 + t * 0.2, 0.74 + sin(t * 5.0) * 0.05 + t * 0.12))
	draw_polyline(tail, _c(base.darkened(0.15)), maxf(2.0 * _s / 56.0, 1.0), true)


func _spool(base: Color) -> void:
	var wood: Color = data.accent_color
	_rect(0.26, 0.2, 0.48, 0.6, base)
	for k in 7:
		var y := 0.24 + float(k) * 0.08
		_line(Vector2(0.27, y + 0.05), Vector2(0.73, y), base.darkened(0.3), 1.2)
	_rect(0.2, 0.12, 0.6, 0.09, wood)
	_rect(0.2, 0.79, 0.6, 0.09, wood)
	_rect(0.2, 0.12, 0.6, 0.025, wood.lightened(0.3))
	if not silhouette:
		_line(Vector2(0.73, 0.5), Vector2(0.9, 0.62), base.darkened(0.15), 1.6)


func _button(base: Color) -> void:
	_circle(0.5, 0.5, 0.4, base.darkened(0.25))
	_circle(0.5, 0.5, 0.35, base)
	_arc(Vector2(0.5, 0.5), 0.27, 0.0, TAU, base.darkened(0.2), 1.4)
	var hole := base.darkened(0.6)
	for h in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_circle(0.5 + h.x * 0.09, 0.5 + h.y * 0.09, 0.04, hole)
	if not silhouette:
		_arc(Vector2(0.5, 0.5), 0.3, PI * 1.15, PI * 1.45, Color(1, 1, 1, 0.8), 1.6)
		_line(Vector2(0.41, 0.41), Vector2(0.59, 0.59), Color("f6ecd6"), 1.1)
		_line(Vector2(0.59, 0.41), Vector2(0.41, 0.59), Color("f6ecd6"), 1.1)


## Relleno de una tela con su dibujo (liso, rayas, vichy, lunares, flores, tartán, vaquero...).
func _fabric(x: float, y: float, w: float, h: float) -> void:
	var a: Color = data.color
	var b: Color = data.color_b
	var c: Color = data.color_c
	_rect(x, y, w, h, a)
	if silhouette:
		return
	match data.pattern:
		1:
			for i in 5:
				_rect(x + w * (0.1 + 0.2 * i), y, w * 0.1, h, b)
		2:
			for i in 4:
				_rect(x + w * (0.1 + 0.25 * i), y, w * 0.12, h, Color(b.r, b.g, b.b, 1.0))
				_rect(x, y + h * (0.1 + 0.25 * i), w, h * 0.12, Color(b.r * 0.9, b.g * 0.9, b.b * 0.9, 1.0))
		3:
			for i in 4:
				for j in 3:
					_circle(x + w * (0.14 + 0.24 * i), y + h * (0.2 + 0.3 * j), 0.035, b)
		4:
			for i in 3:
				for j in 2:
					var fx := x + w * (0.2 + 0.3 * i)
					var fy := y + h * (0.27 + 0.45 * j)
					for k in 5:
						var ang := TAU * float(k) / 5.0
						_circle(fx + cos(ang) * 0.035, fy + sin(ang) * 0.035, 0.022, b)
					_circle(fx, fy, 0.018, c)
		5:
			for i in 3:
				_rect(x + w * (0.12 + 0.3 * i), y, w * 0.1, h, Color(b.r, b.g, b.b, 1.0))
				_rect(x, y + h * (0.12 + 0.3 * i), w, h * 0.1, Color(c.r, c.g, c.b, 1.0))
		6:
			for i in 6:
				_line(Vector2(x + w * 0.16 * i, y + h), Vector2(x + w * (0.16 * i + 0.3), y), b, 1.0)
		7:
			_rect(x, y + h * 0.15, w, h * 0.18, a.lightened(0.25))
		8:
			for i in 7:
				_line(Vector2(x + w * (0.08 + 0.14 * i), y), Vector2(x + w * (0.08 + 0.14 * i), y + h), a.darkened(0.25), 1.2)
		9:
			for i in 6:
				_circle(x + w * (0.1 + 0.16 * i), y + h * 0.1, 0.03, Color("fffaf0"))
				_circle(x + w * (0.1 + 0.16 * i), y + h * 0.9, 0.03, Color("fffaf0"))


func _bolt() -> void:
	# Rollo de tela tumbado: cuerpo con dibujo, tapa con espiral y tubo de cartón.
	_fabric(0.1, 0.3, 0.64, 0.4)
	_ellipse(0.74, 0.5, 0.1, 0.2, Color(data.color).lightened(0.15))
	_arc(Vector2(0.74, 0.5), 0.1, 0.0, TAU, Color(data.color).darkened(0.3), 1.2)
	_ellipse(0.74, 0.5, 0.04, 0.08, Color("c9a874"))
	_arc(Vector2(0.1, 0.5), 0.2, PI * 0.5, PI * 1.5, Color(data.color).darkened(0.35), 1.4)


func _folded() -> void:
	_fabric(0.14, 0.58, 0.72, 0.22)
	_fabric(0.18, 0.38, 0.64, 0.22)
	_fabric(0.12, 0.18, 0.72, 0.22)
	_line(Vector2(0.14, 0.8), Vector2(0.86, 0.8), Color(data.color).darkened(0.35), 1.4)


func _reel(base: Color) -> void:
	_circle(0.44, 0.5, 0.36, base)
	_circle(0.44, 0.5, 0.36 - 0.0, base)
	_arc(Vector2(0.44, 0.5), 0.28, 0.0, TAU, base.darkened(0.25), 1.2)
	_circle(0.44, 0.5, 0.1, CREAM)
	_arc(Vector2(0.44, 0.5), 0.1, 0.0, TAU, Color("c9a874"), 1.2)
	_poly([Vector2(0.62, 0.74), Vector2(0.94, 0.7), Vector2(0.88, 0.8), Vector2(0.94, 0.9), Vector2(0.6, 0.88)], base)


func _bow(base: Color) -> void:
	_poly([Vector2(0.5, 0.5), Vector2(0.14, 0.26), Vector2(0.1, 0.62)], base)
	_poly([Vector2(0.5, 0.5), Vector2(0.86, 0.26), Vector2(0.9, 0.62)], base)
	_poly([Vector2(0.46, 0.56), Vector2(0.3, 0.92), Vector2(0.46, 0.84), Vector2(0.52, 0.94)], base.darkened(0.12))
	_poly([Vector2(0.54, 0.56), Vector2(0.7, 0.92), Vector2(0.54, 0.84), Vector2(0.48, 0.94)], base.darkened(0.12))
	_circle(0.5, 0.5, 0.09, base.lightened(0.15))
	_arc(Vector2(0.5, 0.5), 0.09, 0.0, TAU, base.darkened(0.3), 1.2)


func _scissors(base: Color) -> void:
	# Dos hojas cruzadas y dos anillas de colores.
	_line(Vector2(0.36, 0.64), Vector2(0.86, 0.12), STEEL, 4.0)
	_line(Vector2(0.64, 0.64), Vector2(0.14, 0.12), STEEL.darkened(0.12), 4.0)
	_circle(0.5, 0.52, 0.045, Color("6a6f78"))
	_arc(Vector2(0.3, 0.8), 0.13, 0.0, TAU, base, 4.0)
	_arc(Vector2(0.7, 0.8), 0.13, 0.0, TAU, base, 4.0)
	_line(Vector2(0.36, 0.7), Vector2(0.46, 0.58), base, 3.0)
	_line(Vector2(0.64, 0.7), Vector2(0.54, 0.58), base, 3.0)


func _tape(base: Color) -> void:
	_poly([Vector2(0.14, 0.2), Vector2(0.72, 0.2), Vector2(0.8, 0.28), Vector2(0.8, 0.8), Vector2(0.14, 0.8)], base)
	_circle(0.45, 0.5, 0.2, CREAM)
	_arc(Vector2(0.45, 0.5), 0.2, 0.0, TAU, base.darkened(0.3), 1.2)
	_circle(0.45, 0.5, 0.05, base.darkened(0.3))
	_rect(0.78, 0.6, 0.18, 0.1, CREAM)
	for k in 4:
		_line(Vector2(0.8 + 0.04 * k, 0.6), Vector2(0.8 + 0.04 * k, 0.64 + (0.04 if k % 2 == 0 else 0.0)), Color("5a3b12"), 1.0)


func _ruler(base: Color) -> void:
	_rect(0.06, 0.38, 0.88, 0.26, base)
	for k in 12:
		var x := 0.1 + 0.07 * float(k)
		_line(Vector2(x, 0.38), Vector2(x, 0.38 + (0.12 if k % 2 == 0 else 0.07)), Color("5a3b12"), 1.0)
	_line(Vector2(0.06, 0.64), Vector2(0.94, 0.64), base.darkened(0.3), 1.4)


func _zipper(base: Color) -> void:
	_rect(0.3, 0.1, 0.4, 0.8, base)
	for k in 8:
		var y := 0.16 + 0.095 * float(k)
		_rect(0.42 if k % 2 == 0 else 0.5, y, 0.08, 0.06, STEEL)
	_poly([Vector2(0.4, 0.1), Vector2(0.6, 0.1), Vector2(0.64, 0.3), Vector2(0.5, 0.36), Vector2(0.36, 0.3)], STEEL.darkened(0.1))
	_arc(Vector2(0.5, 0.2), 0.05, 0.0, TAU, Color("6a6f78"), 1.6)


func _thimble(base: Color) -> void:
	_poly([Vector2(0.24, 0.8), Vector2(0.28, 0.4), Vector2(0.38, 0.26), Vector2(0.62, 0.26), Vector2(0.72, 0.4), Vector2(0.76, 0.8)], base)
	_rect(0.22, 0.74, 0.56, 0.1, base.lightened(0.2))
	var dimple := base.darkened(0.35)
	for r in 3:
		for k in 4 - (1 if r == 0 else 0):
			_circle(0.32 + 0.12 * float(k) + (0.04 if r == 1 else 0.0), 0.38 + 0.11 * float(r), 0.022, dimple)
	_arc(Vector2(0.5, 0.3), 0.12, PI * 1.1, PI * 1.45, base.lightened(0.5), 1.6)


func _needle_case(base: Color) -> void:
	_poly([Vector2(0.34, 0.2), Vector2(0.66, 0.2), Vector2(0.66, 0.88), Vector2(0.34, 0.88)], base)
	_rect(0.32, 0.12, 0.36, 0.14, base.darkened(0.25))
	_line(Vector2(0.42, 0.34), Vector2(0.42, 0.8), base.lightened(0.4), 1.2)
	_line(Vector2(0.84, 0.12), Vector2(0.84, 0.72), STEEL, 1.6)
	_arc(Vector2(0.84, 0.16), 0.02, 0.0, TAU, Color("6a6f78"), 1.0)


func _pincushion(base: Color) -> void:
	_ellipse(0.5, 0.58, 0.34, 0.28, base)
	_arc(Vector2(0.5, 0.58), 0.3, PI * 1.1, PI * 1.9, base.lightened(0.3), 1.6)
	_poly([Vector2(0.5, 0.3), Vector2(0.62, 0.34), Vector2(0.54, 0.4), Vector2(0.5, 0.46), Vector2(0.44, 0.4), Vector2(0.38, 0.34)], Color("3f8a3a"))
	for k in 5:
		var ang := PI * (1.15 + 0.14 * float(k))
		var from := Vector2(0.5, 0.6) + Vector2(cos(ang), sin(ang)) * 0.26
		var to := Vector2(0.5, 0.6) + Vector2(cos(ang), sin(ang)) * 0.4
		_line(from, to, STEEL, 1.1)
		_circle(to.x, to.y, 0.025, [Color("f2c14e"), Color("e0766b"), Color("8ec5e8"), Color("f6ecd6"), Color("c9a2e0")][k])


func _chalk(base: Color) -> void:
	_poly([Vector2(0.14, 0.6), Vector2(0.62, 0.22), Vector2(0.86, 0.4), Vector2(0.38, 0.78)], base)
	_poly([Vector2(0.62, 0.22), Vector2(0.86, 0.4), Vector2(0.82, 0.48), Vector2(0.58, 0.3)], base.lightened(0.3))
	_line(Vector2(0.16, 0.6), Vector2(0.38, 0.77), base.darkened(0.25), 1.2)


func _sewing_box(base: Color) -> void:
	_rect(0.14, 0.44, 0.72, 0.4, base)
	_rect(0.1, 0.34, 0.8, 0.14, base.lightened(0.15))
	_rect(0.14, 0.7, 0.72, 0.04, base.darkened(0.3))
	_arc(Vector2(0.5, 0.34), 0.2, PI, TAU, base.darkened(0.35), 3.0)
	_rect(0.46, 0.46, 0.08, 0.1, Color("e6c26a"))


func _tin(base: Color) -> void:
	_rect(0.2, 0.34, 0.6, 0.46, base)
	_ellipse(0.5, 0.34, 0.3, 0.1, base.lightened(0.2))
	_ellipse(0.5, 0.8, 0.3, 0.09, base.darkened(0.1))
	_rect(0.2, 0.5, 0.6, 0.1, CREAM)
	for k in 5:
		_circle(0.3 + 0.1 * float(k), 0.55, 0.018, base)


func _pattern_envelope(base: Color) -> void:
	_rect(0.2, 0.12, 0.6, 0.76, base)
	_rect(0.2, 0.12, 0.6, 0.04, base.darkened(0.2))
	_circle(0.5, 0.34, 0.07, CREAM)
	_poly([Vector2(0.4, 0.44), Vector2(0.6, 0.44), Vector2(0.7, 0.8), Vector2(0.3, 0.8)], CREAM)
	_line(Vector2(0.4, 0.44), Vector2(0.6, 0.44), base.darkened(0.4), 1.0)
	_line(Vector2(0.3, 0.8), Vector2(0.7, 0.8), base.darkened(0.4), 1.0)


func _hoop() -> void:
	_circle(0.5, 0.5, 0.36, CREAM)
	_circle(0.5, 0.5, 0.36, CREAM)
	_arc(Vector2(0.5, 0.5), 0.36, 0.0, TAU, Color("c9955c"), 4.5)
	_arc(Vector2(0.5, 0.5), 0.3, 0.0, TAU, Color("a87a44"), 1.2)
	_rect(0.46, 0.08, 0.08, 0.1, Color("8a6238"))
	for k in 6:
		var ang := TAU * float(k) / 6.0
		_circle(0.5 + cos(ang) * 0.1, 0.5 + sin(ang) * 0.1, 0.045, Color("e0766b"))
	_circle(0.5, 0.5, 0.04, Color("f2c14e"))


func _iron(base: Color) -> void:
	_poly([Vector2(0.1, 0.8), Vector2(0.16, 0.52), Vector2(0.62, 0.42), Vector2(0.92, 0.8)], base)
	_poly([Vector2(0.1, 0.8), Vector2(0.92, 0.8), Vector2(0.9, 0.88), Vector2(0.1, 0.88)], base.darkened(0.3))
	_arc(Vector2(0.42, 0.42), 0.2, PI * 1.05, PI * 1.95, base.darkened(0.2), 4.0)
	_line(Vector2(0.24, 0.5), Vector2(0.58, 0.46), base.lightened(0.25), 1.4)

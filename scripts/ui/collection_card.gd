class_name CollectionCard
extends Control
## Ficha del libro de colecciones: el dibujo del objeto, su nombre y una barra de hilo con el progreso.
## Con `treasure` es una ficha ancha con marco dorado (el tesoro de la sala); sin encontrar se ve como
## una silueta con interrogación y no revela su nombre.

const PAPER_LIGHT := Color("fbf4e2")

var data: ItemData
var label := ""
var placed := 0
var total := 0
var treasure := false
var found := true
var detail := ""

var _icon: ItemIcon


func _ready() -> void:
	custom_minimum_size = Vector2(380, 92) if treasure else Vector2(124, 124)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = ItemIcon.new(data, treasure and not found, 66.0 if treasure else 54.0)
	_icon.position = Vector2(12, 12) if treasure else Vector2((custom_minimum_size.x - 54.0) * 0.5, 7)
	add_child(_icon)


func _draw() -> void:
	var done := total > 0 and placed >= total
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_LIGHT
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if (treasure or done) else 2)
	sb.border_color = Color("e0a92e") if treasure else (PauseMenu.TEAL if done else PauseMenu.PAPER_EDGE)
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	if treasure:
		_draw_treasure_text(font)
		return
	# Nombre (hasta dos líneas) y progreso.
	draw_multiline_string(font, Vector2(4, 76), label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, 13, 2, PauseMenu.INK)
	var ratio := 0.0 if total == 0 else clampf(float(placed) / float(total), 0.0, 1.0)
	var bar := Rect2(Vector2(12, size.y - 20), Vector2(size.x - 24, 7))
	draw_rect(bar, PauseMenu.PAPER_EDGE)
	var fill_color: Color = PauseMenu.TEAL if done else (data.color.darkened(0.1) if data != null else PauseMenu.RED)
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color(fill_color.r, fill_color.g, fill_color.b, 1.0))
	var count := "%d/%d" % [placed, total]
	var cs := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2((size.x - cs.x) * 0.5, size.y - 25), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PauseMenu.INK_SOFT)
	if done:
		_rosette(Vector2(size.x - 15, 15))


func _draw_treasure_text(font: Font) -> void:
	var x := 92.0
	if found:
		draw_string(font, Vector2(x, 32), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 10, 17, PauseMenu.GOLD_INK)
		draw_multiline_string(font, Vector2(x, 54), detail, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 12, 13, 2, PauseMenu.INK_SOFT)
		_rosette(Vector2(size.x - 18, 18))
	else:
		draw_string(font, Vector2(x, 32), "???", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PauseMenu.INK_SOFT)
		draw_multiline_string(font, Vector2(x, 54), "Escondido en algún rincón de la sala. Busca destellos dorados.", HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 12, 13, 2, PauseMenu.INK_SOFT)


## Escarapela dorada con una marca de verificación (colección completa, tesoro hallado).
func _rosette(center: Vector2) -> void:
	for k in 8:
		var a := TAU * float(k) / 8.0
		draw_circle(center + Vector2(cos(a), sin(a)) * 9.0, 4.0, Color("e0a92e"))
	draw_circle(center, 9.0, Color("f2c14e"))
	draw_arc(center, 7.0, 0.0, TAU, 20, Color("b57d12"), 1.2, true)
	draw_polyline(PackedVector2Array([center + Vector2(-4, 0), center + Vector2(-1, 3.5), center + Vector2(5, -3.5)]), Color("fff6e6"), 2.2, true)


## Barra de progreso de la sala: hilo que se va rellenando, con su porcentaje.
class ThreadBar extends Control:
	var ratio := 0.0
	var color := Color("c4433a")
	var text := ""

	func _init() -> void:
		custom_minimum_size = Vector2(0, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var bar := Rect2(Vector2(0, 7), Vector2(size.x, 8))
		draw_rect(bar, PauseMenu.PAPER_EDGE)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)), color)
		PauseMenu.draw_dashed(self, PackedVector2Array([Vector2(0, 11), Vector2(size.x * clampf(ratio, 0.0, 1.0), 11)]), Color(1, 1, 1, 0.55), 1.2, 4.0, 3.0)
		if text != "":
			var font := ThemeDB.fallback_font
			var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(font, Vector2(size.x - ts.x, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PauseMenu.INK_SOFT)


## Candado de una sala que aún no se ha desbloqueado.
class Padlock extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(40, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2(20, 18), 9.0, PI, TAU, 16, PauseMenu.BROWN, 4.0, true)
		draw_line(Vector2(11, 18), Vector2(11, 22), PauseMenu.BROWN, 4.0)
		draw_line(Vector2(29, 18), Vector2(29, 22), PauseMenu.BROWN, 4.0)
		draw_rect(Rect2(8, 22, 24, 18), PauseMenu.BROWN)
		draw_rect(Rect2(8, 22, 24, 4), PauseMenu.BROWN.lightened(0.15))
		draw_circle(Vector2(20, 30), 3.0, Color("3b2a1d"))
		draw_line(Vector2(20, 31), Vector2(20, 36), Color("3b2a1d"), 2.2)

class_name PauseMenu
extends CanvasLayer
## Menú de pausa con aspecto de mercería: una pieza de tela de bordes en zigzag (como cortada con
## tijeras dentadas) con puntadas rojas, un título sobre cinta de raso, botones cosidos, deslizadores
## que son cintas métricas y casillas que son botones de costura. Incluye el libro de colecciones.
## Todo se dibuja por código, sin imágenes; las fuentes son las de la interfaz (UiStyle).
## Desde el título se abre como "Ajustes" (open(true)): sin pausar el juego y volviendo al título al cerrar.

## Se cierra (para quien lo abrió desde el título).
signal closed

const PAPER := Color("f6ecd6")
const PAPER_EDGE := Color("e3d1ad")
const INK := Color("3b2a1d")
const INK_SOFT := Color("7a634d")
const RED := Color("c4433a")
const RED_DARK := Color("98302b")
const TEAL := Color("2f7a74")
const TEAL_DARK := Color("215c57")
const BROWN := Color("8a6a4a")
const GOLD_INK := Color("9a6a0c")
const THREAD := Color("e0766b")

var _root: Control
var _resume: Button
var _main_panel: Control
var _book_panel: Control
var _book_content: VBoxContainer
var _opened := false
var _from_title := false
var _auto_pause := true
var _lang_buttons: Dictionary = {}
var _ribbon: Ribbon
var _open_tween: Tween


# --- Piezas dibujadas ------------------------------------------------------

## Línea de puntadas: rectángulo redondeado (o una línea horizontal) discontinuo, como cosido a máquina.
class Stitch extends Control:
	var color := Color("e0766b")
	var inset := 8.0
	var radius := 14.0
	var dash := 7.0
	var gap := 5.0
	var width := 2.0
	var line_only := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if line_only:
			PauseMenu.draw_dashed(self, PackedVector2Array([Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5)]), color, width, dash, gap)
		else:
			var r := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
			PauseMenu.draw_dashed(self, PauseMenu.rounded_rect(r, radius), color, width, dash, gap)


## Tela de bordes dentados con una costura roja por dentro y algo de sombra.
class PinkedPanel extends PanelContainer:
	var tooth := 11.0
	var depth := 5.0

	func _init() -> void:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 44
		empty.content_margin_right = 44
		empty.content_margin_top = 34
		empty.content_margin_bottom = 40
		add_theme_stylebox_override(&"panel", empty)

	func _draw() -> void:
		draw_colored_polygon(_zigzag(Vector2(6.0, 8.0)), Color(0.05, 0.03, 0.02, 0.35))
		var shape := _zigzag(Vector2.ZERO)
		draw_colored_polygon(shape, PauseMenu.PAPER)
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, PauseMenu.PAPER_EDGE, 2.0, true)
		var inner := Rect2(Vector2.ONE * 17.0, size - Vector2.ONE * 34.0)
		PauseMenu.draw_dashed(self, PauseMenu.rounded_rect(inner, 10.0), PauseMenu.THREAD, 2.0, 9.0, 6.0)

	func _zigzag(offset: Vector2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var nx := maxi(int(size.x / tooth) / 2 * 2, 2)
		var ny := maxi(int(size.y / tooth) / 2 * 2, 2)
		for i in nx:
			pts.append(Vector2(size.x * i / nx, depth * (i % 2)) + offset)
		for j in ny:
			pts.append(Vector2(size.x - depth * (j % 2), size.y * j / ny) + offset)
		for i in nx:
			pts.append(Vector2(size.x - size.x * i / nx, size.y - depth * (i % 2)) + offset)
		for j in ny:
			pts.append(Vector2(depth * (j % 2), size.y - size.y * j / ny) + offset)
		return pts


## Título sobre una cinta de raso con las puntas en V y un botón cosido a cada lado.
class Ribbon extends Control:
	const TEXT_SHADOW := Color(0.4, 0.1, 0.08, 0.7)
	var text := ""
	var font_size := 34

	func _init() -> void:
		custom_minimum_size = Vector2(420, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var tail := 34.0
		var notch := 22.0
		var body := PackedVector2Array([
			Vector2(0, 0), Vector2(w, 0), Vector2(w - notch, h * 0.5), Vector2(w, h),
			Vector2(0, h), Vector2(notch, h * 0.5)])
		var shade := PackedVector2Array()
		for p in body:
			shade.append(p + Vector2(3, 4))
		draw_colored_polygon(shade, Color(0, 0, 0, 0.25))
		draw_colored_polygon(body, PauseMenu.RED)
		# Brillo de raso: banda más clara arriba y filo oscuro abajo.
		draw_rect(Rect2(tail * 0.6, 5, w - tail * 1.2, h * 0.28), Color(1, 1, 1, 0.12))
		draw_line(Vector2(notch, h - 3), Vector2(w - notch, h - 3), PauseMenu.RED_DARK, 3.0)
		var closed := body.duplicate()
		closed.append(body[0])
		draw_polyline(closed, PauseMenu.RED_DARK, 2.0, true)
		PauseMenu.draw_sewn_button(self, Vector2(tail + 8.0, h * 0.5), 11.0, PauseMenu.PAPER)
		PauseMenu.draw_sewn_button(self, Vector2(w - tail - 8.0, h * 0.5), 11.0, PauseMenu.PAPER)
		var font := UiStyle.font(&"title")
		var shown := tr(text)
		var ts := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var base := Vector2((w - ts.x) * 0.5, h * 0.5 + font_size * 0.35)
		draw_string(font, base + Vector2(1, 1), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_SHADOW)
		draw_string(font, base, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff6e6"))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()


# --- Ayudas estáticas ------------------------------------------------------

## Contorno cerrado de un rectángulo con las esquinas redondeadas.
static func rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(r, r), PI],
		[rect.position + Vector2(rect.size.x - r, r), PI * 1.5],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
	]
	for c in corners:
		for k in 7:
			var a: float = c[1] + (PI * 0.5) * float(k) / 6.0
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	return pts


## Recorre una línea quebrada dibujando trazos y huecos alternados.
static func draw_dashed(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var drawing := true
	var remaining := dash
	var pos := points[0]
	for i in range(1, points.size()):
		var target := points[i]
		var seg := target - pos
		var seg_len := seg.length()
		if seg_len <= 0.0001:
			continue
		var dir := seg / seg_len
		var travelled := 0.0
		while travelled < seg_len - 0.0001:
			var step := minf(remaining, seg_len - travelled)
			var next := pos + dir * step
			if drawing:
				ci.draw_line(pos, next, color, width, true)
			pos = next
			travelled += step
			remaining -= step
			if remaining <= 0.0001:
				drawing = not drawing
				remaining = dash if drawing else gap
		pos = target


## Botón de costura dibujado: disco con borde y cuatro agujeros.
static func draw_sewn_button(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	ci.draw_circle(center + Vector2(1, 1.5), radius, Color(0, 0, 0, 0.25))
	ci.draw_circle(center, radius, color)
	ci.draw_arc(center, radius - 1.5, 0.0, TAU, 24, color.darkened(0.2), 1.5, true)
	for h in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		ci.draw_circle(center + h * radius * 0.32, radius * 0.13, color.darkened(0.55))


## Textura de botón de costura (agujeros y, si `checked`, cruz de hilo): casillas y tirador de los deslizadores.
static func button_texture(diameter: int, fill: Color, checked: bool) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := Vector2(diameter, diameter) * 0.5 - Vector2(0.5, 0.5)
	var r := diameter * 0.5 - 1.0
	var hole_offsets := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for y in diameter:
		for x in diameter:
			var p := Vector2(x, y)
			var d := p.distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= r + 0.5:
				col = fill.darkened(0.25) if d > r - 1.8 else fill
				for h in hole_offsets:
					if p.distance_to(c + h * r * 0.34) < r * 0.14:
						col = fill.darkened(0.6)
				if checked:
					# Cruz de hilo rojo que atraviesa los agujeros.
					var on_diag := absf((p.x - c.x) - (p.y - c.y)) < 1.1 or absf((p.x - c.x) + (p.y - c.y)) < 1.1
					if on_diag and d < r * 0.62:
						col = Color("c4433a")
				col.a *= clampf(r - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Cinta métrica: con marcas cada pocos píxeles (se repite a lo ancho).
static func tape_texture(color: Color, height: int) -> ImageTexture:
	var img := Image.create(64, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in 64:
			var col := color
			if y == 0 or y == height - 1:
				col = color.darkened(0.25)
			else:
				var tick := 0.0
				if x % 16 == 0:
					tick = 0.55
				elif x % 8 == 0:
					tick = 0.32
				elif x % 4 == 0:
					tick = 0.16
				if tick > 0.0 and y < height * tick + 1.0:
					col = Color("5a3b12")
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# --- Ciclo de vida -----------------------------------------------------------

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_auto_pause = not OS.get_cmdline_user_args().has("--no-autopause")
	_build()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if _opened:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _auto_pause and not _opened and is_inside_tree() \
			and get_tree().get_first_node_in_group(&"title_screen") == null:
		open()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _book_panel != null and _book_panel.visible:
		_fill_book()


func is_open() -> bool:
	return _opened


## from_title: abierto desde el título como "Ajustes" (el juego sigue detrás y al cerrar se vuelve al título).
func open(from_title: bool = false) -> void:
	if _opened:
		return
	_opened = true
	_from_title = from_title
	_root.visible = true
	_show_book(false)
	_resume.text = "Volver" if from_title else "Continuar"
	_ribbon.text = "Ajustes" if from_title else "Pausa"
	_ribbon.queue_redraw()
	_style_languages()
	if not from_title:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.pause_toggled.emit(true)
	_resume.grab_focus()
	# La tela aparece con un pequeño asentamiento.
	if _open_tween:
		_open_tween.kill()
	_root.modulate.a = 0.0
	_main_panel.pivot_offset = _main_panel.size * 0.5
	_main_panel.scale = Vector2(0.96, 0.96)
	_open_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_open_tween.tween_property(_root, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	_open_tween.tween_property(_main_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _opened:
		return
	_opened = false
	_root.visible = false
	GameSettings.save_settings()
	if _from_title:
		_from_title = false
		closed.emit()
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.pause_toggled.emit(false)
	closed.emit()


# --- Construcción --------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = _make_theme()
	_root.add_child(center)

	_main_panel = _build_main()
	center.add_child(_main_panel)
	_book_panel = _build_book()
	center.add_child(_book_panel)


func _build_main() -> Control:
	var panel := PinkedPanel.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 18)
	panel.add_child(vb)

	var ribbon := Ribbon.new()
	ribbon.text = "Pausa"
	_ribbon = ribbon
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ribbon)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 40)
	vb.add_child(cols)

	# Columna izquierda: lo que se hace con el juego.
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 14)
	left.custom_minimum_size = Vector2(250, 0)
	cols.add_child(left)
	_resume = _sewn_button("Continuar", RED, RED_DARK)
	_resume.pressed.connect(func():
		AudioManager.play(&"ui_click")
		close())
	left.add_child(_resume)
	var book_btn := _sewn_button("Libro de colecciones", TEAL, TEAL_DARK)
	book_btn.pressed.connect(func():
		AudioManager.play(&"ui_click")
		_show_book(true))
	left.add_child(book_btn)
	# Atajo de desarrollo/pruebas: da por ordenada la sección en la que estás (la del objeto en la mano o la más cercana).
	# Solo en el editor y en pruebas: en el ejecutable para jugadores no sale.
	var skip_btn := _sewn_button("Completar esta sección", Color("c98a1e"), Color("94620f"))
	skip_btn.pressed.connect(func():
		AudioManager.play(&"ui_click")
		var shop := get_tree().get_first_node_in_group(&"shop") as Shop
		close()   # primero se reanuda: los avisos de "sección completada" usan temporizadores que respetan la pausa
		if shop != null:
			shop.skip_section())
	if OS.is_debug_build() or OS.get_cmdline_user_args().has("--test-mode"):
		left.add_child(skip_btn)
	else:
		skip_btn.queue_free()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(_keys_card())
	var quit := _sewn_button("Salir del juego", BROWN, BROWN.darkened(0.25))
	quit.pressed.connect(func():
		GameSettings.save_settings()
		get_tree().quit())
	left.add_child(quit)

	# Columna derecha: ajustes.
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 9)
	right.custom_minimum_size = Vector2(430, 0)
	cols.add_child(right)
	right.add_child(_section("Idioma"))
	right.add_child(_language_row())
	right.add_child(_section("Manos"))
	right.add_child(_slider_row("Sensibilidad del ratón", 0.2, 3.0, 0.05, GameSettings.mouse_sensitivity,
		func(v: float): GameSettings.mouse_sensitivity = v))
	right.add_child(_section("Sonido"))
	right.add_child(_slider_row("Volumen general", 0.0, 1.0, 0.05, GameSettings.master_volume,
		func(v: float): GameSettings.master_volume = v))
	right.add_child(_slider_row("Efectos", 0.0, 1.0, 0.05, GameSettings.sfx_volume,
		func(v: float): GameSettings.sfx_volume = v))
	right.add_child(_slider_row("Música", 0.0, 1.0, 0.05, GameSettings.music_volume,
		func(v: float): GameSettings.music_volume = v))
	right.add_child(_section("Pantalla"))
	right.add_child(_check_row("Pantalla completa", GameSettings.fullscreen,
		func(on: bool): GameSettings.fullscreen = on))
	right.add_child(_check_row("Sincronización vertical", GameSettings.vsync,
		func(on: bool): GameSettings.vsync = on))
	right.add_child(_check_row("Bordes suaves (MSAA 4x)", GameSettings.msaa,
		func(on: bool): GameSettings.msaa = on))
	right.add_child(_check_row("Iluminación avanzada", GameSettings.high_quality,
		func(on: bool): GameSettings.high_quality = on))
	right.add_child(_section("Accesibilidad"))
	right.add_child(_slider_row("Tamaño del texto", 1.0, 1.5, 0.1, GameSettings.text_scale,
		func(v: float): GameSettings.text_scale = v))
	right.add_child(_check_row("Colores para daltonismo (azul / naranja)", GameSettings.colorblind,
		func(on: bool): GameSettings.colorblind = on))
	return panel


## Idioma: una pastilla por idioma (escrita en ese idioma); la elegida, rellena de rojo.
func _language_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	for code in GameSettings.LANGUAGES:
		var b := Button.new()
		b.text = {"es": "Español", "en": "English"}.get(code, code)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(140, 38)
		b.add_theme_font_override(&"font", UiStyle.font(&"title"))
		b.add_theme_font_size_override(&"font_size", 17)
		b.pressed.connect(func():
			AudioManager.play(&"ui_click")
			GameSettings.language = code
			GameSettings.apply_language()
			GameSettings.changed.emit()
			_style_languages())
		row.add_child(b)
		_lang_buttons[code] = b
	_style_languages()
	return row


func _style_languages() -> void:
	for code in _lang_buttons:
		var b: Button = _lang_buttons[code]
		var on: bool = code == GameSettings.language
		b.add_theme_stylebox_override(&"normal", _pill(RED if on else Color("efe0c2"), RED_DARK if on else PAPER_EDGE.darkened(0.15)))
		b.add_theme_stylebox_override(&"hover", _pill(RED.lightened(0.1) if on else Color("f5e8cf"), RED_DARK))
		b.add_theme_stylebox_override(&"pressed", _pill(RED.darkened(0.1), RED_DARK))
		b.add_theme_stylebox_override(&"focus", _pill(RED.lightened(0.1) if on else Color("f5e8cf"), Color("fff0c8")))
		for c in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color"]:
			b.add_theme_color_override(c, Color("fff6e6") if on else INK)


## Tarjeta con las teclas, como una etiqueta de patrón pegada.
func _keys_card() -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_EDGE
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override(&"panel", sb)
	var l := Label.new()
	l.text = "WASD mover · Shift correr\nCtrl agacharse · R girar\nE recoger / dejar\nClic izq. colocar · F lanzar\nEsc pausa"
	l.add_theme_font_size_override(&"font_size", 13)
	l.add_theme_color_override(&"font_color", INK_SOFT)
	card.add_child(l)
	return card


func _build_book() -> Control:
	var panel := PinkedPanel.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 14)
	panel.add_child(vb)
	var ribbon := Ribbon.new()
	ribbon.text = "Libro de colecciones"
	ribbon.custom_minimum_size = Vector2(600, 70)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ribbon)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_book_content = VBoxContainer.new()
	_book_content.add_theme_constant_override(&"separation", 8)
	_book_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_book_content)
	var back := _sewn_button("Volver", TEAL, TEAL_DARK)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(240, 50)
	back.pressed.connect(func():
		AudioManager.play(&"ui_click")
		_show_book(false))
	vb.add_child(back)
	return panel


func _show_book(on: bool) -> void:
	_book_panel.visible = on
	_main_panel.visible = not on
	if on:
		_fill_book()
	else:
		_resume.grab_focus()


## Rellena el libro con el estado actual: por sección, una cabecera con su dibujo y su barra de progreso,
## una ficha ilustrada por cada colección y los tesoros (silueta hasta que se encuentran).
func _fill_book() -> void:
	for c in _book_content.get_children():
		c.queue_free()
	var shop := get_tree().get_first_node_in_group(&"shop") as Shop
	if shop == null or shop.room == null:
		return
	var room := shop.room
	var summary := _book_label(tr("Ordenados %d de %d  ·  Tesoros encontrados: %d de %d") % [room.placed_items, room.total_items, room.treasures_found(), room.treasures_total()], 18, GOLD_INK)
	_book_content.add_child(summary)
	for section in room.sections:
		_book_content.add_child(_thread_line())
		_book_content.add_child(_section_header(section))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 10)
		flow.add_theme_constant_override(&"v_separation", 10)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for entry in section.collection_status():
			var card := CollectionCard.new()
			card.data = entry["data"]
			card.label = entry["label"]
			card.placed = entry["placed"]
			card.total = entry["total"]
			flow.add_child(card)
		_book_content.add_child(flow)
		var gems := HFlowContainer.new()
		gems.add_theme_constant_override(&"h_separation", 10)
		gems.add_theme_constant_override(&"v_separation", 10)
		gems.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for treasure in section.treasure_status():
			var card := CollectionCard.new()
			card.treasure = true
			card.found = treasure["found"]
			card.data = treasure["data"]
			card.label = treasure["name"]
			card.detail = treasure["detail"]
			gems.add_child(card)
		_book_content.add_child(gems)


## Cabecera de sección: dibujo de uno de sus objetos, nombre, barra de hilo con el progreso y su estado.
func _section_header(section: ShopSection) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var first: ItemData = section.catalog.items[0]
	row.add_child(ItemIcon.new(first, false, 46.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override(&"separation", 2)
	row.add_child(col)
	col.add_child(_book_label(tr(section.display_name) + (tr("  ·  ¡completada!") if section.is_completed else ""), 19, RED_DARK))
	var bar := CollectionCard.ThreadBar.new()
	bar.ratio = 0.0 if section.total_items == 0 else float(section.placed_items) / float(section.total_items)
	bar.color = TEAL if section.is_completed else RED
	bar.text = tr("ordenados %d de %d") % [section.placed_items, section.total_items]
	col.add_child(bar)
	return row


func _book_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Separador de puntadas.
func _thread_line() -> Control:
	var line := Stitch.new()
	line.line_only = true
	line.custom_minimum_size = Vector2(0, 10)
	line.color = THREAD
	line.dash = 6.0
	line.gap = 5.0
	line.width = 1.6
	return line


func _section(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 17)
	l.add_theme_color_override(&"font_color", RED_DARK)
	row.add_child(l)
	var line := _thread_line()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


## Botón "cosido": relleno de color con una puntada clara por dentro.
func _sewn_button(text: String, color: Color, dark: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override(&"font_size", 19)
	b.add_theme_stylebox_override(&"normal", _pill(color, dark))
	b.add_theme_stylebox_override(&"hover", _pill(color.lightened(0.12), dark))
	b.add_theme_stylebox_override(&"pressed", _pill(color.darkened(0.12), dark))
	b.add_theme_stylebox_override(&"focus", _pill(color.lightened(0.12), Color("fff0c8")))
	b.add_theme_color_override(&"font_color", Color("fff6e6"))
	b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	b.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	b.add_theme_color_override(&"font_focus_color", Color.WHITE)
	var stitch := Stitch.new()
	stitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	stitch.inset = 6.0
	stitch.radius = 18.0
	stitch.dash = 6.0
	stitch.gap = 4.0
	stitch.width = 1.6
	stitch.color = Color(1, 0.96, 0.88, 0.75)
	b.add_child(stitch)
	return b


func _pill(color: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(3)
	sb.border_color = border
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _slider_row(text: String, min_v: float, max_v: float, step: float, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(185, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(150, 28)
	row.add_child(s)
	var val := Label.new()
	val.custom_minimum_size = Vector2(46, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.text = "%.2f" % value
	row.add_child(val)
	s.value_changed.connect(func(v: float):
		val.text = "%.2f" % v
		on_change.call(v)
		GameSettings.notify_changed())
	return row


func _check_row(text: String, value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(func(on: bool):
		AudioManager.play(&"ui_click")
		on_change.call(on)
		GameSettings.notify_changed())
	return c


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = UiStyle.font(&"body")
	t.set_color(&"font_color", &"Label", INK)
	t.set_font_size(&"font_size", &"Label", 17)
	t.set_color(&"font_color", &"CheckBox", INK)
	t.set_color(&"font_hover_color", &"CheckBox", RED_DARK)
	t.set_color(&"font_pressed_color", &"CheckBox", INK)
	t.set_color(&"font_focus_color", &"CheckBox", INK)
	t.set_color(&"font_hover_pressed_color", &"CheckBox", RED_DARK)
	t.set_font_size(&"font_size", &"CheckBox", 17)
	t.set_constant(&"h_separation", &"CheckBox", 12)
	# Casillas: botones de costura, con una cruz de hilo cuando están marcadas.
	var off := button_texture(26, Color("e9d7b2"), false)
	var on := button_texture(26, Color("e9d7b2"), true)
	t.set_icon(&"unchecked", &"CheckBox", off)
	t.set_icon(&"checked", &"CheckBox", on)
	t.set_icon(&"radio_unchecked", &"CheckBox", off)
	t.set_icon(&"radio_checked", &"CheckBox", on)
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		t.set_stylebox(state, &"CheckBox", empty)
	# Deslizadores: cinta métrica con un botón como tirador.
	var tape := StyleBoxTexture.new()
	tape.texture = tape_texture(Color("f2c14e"), 14)
	tape.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	tape.content_margin_top = 7
	tape.content_margin_bottom = 7
	var tape_fill := StyleBoxTexture.new()
	tape_fill.texture = tape_texture(Color("e5883f"), 14)
	tape_fill.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	tape_fill.content_margin_top = 7
	tape_fill.content_margin_bottom = 7
	t.set_stylebox(&"slider", &"HSlider", tape)
	t.set_stylebox(&"grabber_area", &"HSlider", tape_fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", tape_fill)
	var knob := button_texture(26, Color("c4433a"), false)
	var knob_hi := button_texture(26, Color("d8574d"), false)
	t.set_icon(&"grabber", &"HSlider", knob)
	t.set_icon(&"grabber_highlight", &"HSlider", knob_hi)
	t.set_icon(&"grabber_disabled", &"HSlider", knob)
	# Barras de desplazamiento del libro, discretas.
	var sbar := StyleBoxFlat.new()
	sbar.bg_color = Color(0.7, 0.58, 0.4, 0.25)
	sbar.set_corner_radius_all(4)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.77, 0.4, 0.33, 0.8)
	grab.set_corner_radius_all(4)
	t.set_stylebox(&"scroll", &"VScrollBar", sbar)
	t.set_stylebox(&"grabber", &"VScrollBar", grab)
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", grab)
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", grab)
	return t

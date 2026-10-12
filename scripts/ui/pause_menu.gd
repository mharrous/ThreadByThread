extends CanvasLayer
## Menú de pausa con ajustes de sensibilidad, audio y gráficos (Esc).

const CREAM := Color("fff4e0")
const SOFT := Color("e9d3b0")
const ACCENT := Color("f2a65a")

var _root: Control
var _resume: Button
var _main_panel: PanelContainer
var _book_panel: PanelContainer
var _book_content: VBoxContainer
var _opened := false
var _auto_pause := true


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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _auto_pause and not _opened and is_inside_tree():
		open()


func open() -> void:
	if _opened:
		return
	_opened = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.pause_toggled.emit(true)
	_show_book(false)
	_resume.grab_focus()


func close() -> void:
	if not _opened:
		return
	_opened = false
	_root.visible = false
	GameSettings.save_settings()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.pause_toggled.emit(false)


# --- Construcción --------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.theme = _make_theme()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.17, 0.12, 0.08, 0.96)
	psb.set_corner_radius_all(20)
	psb.content_margin_left = 44
	psb.content_margin_right = 44
	psb.content_margin_top = 32
	psb.content_margin_bottom = 36
	panel.add_theme_stylebox_override(&"panel", psb)
	center.add_child(panel)
	_main_panel = panel
	_build_book(center, psb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 10)
	vb.custom_minimum_size = Vector2(480, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Pausa"
	title.add_theme_font_size_override(&"font_size", 38)
	title.add_theme_color_override(&"font_color", Color("ffe7b8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_resume = Button.new()
	_resume.text = "Continuar"
	_resume.pressed.connect(func():
		AudioManager.play(&"ui_click")
		close())
	vb.add_child(_resume)

	var book_btn := Button.new()
	book_btn.text = "Libro de colecciones"
	book_btn.pressed.connect(func():
		AudioManager.play(&"ui_click")
		_show_book(true))
	vb.add_child(book_btn)

	vb.add_child(_section("Controles"))
	vb.add_child(_slider_row("Sensibilidad del ratón", 0.2, 3.0, 0.05, GameSettings.mouse_sensitivity,
		func(v: float): GameSettings.mouse_sensitivity = v))

	vb.add_child(_section("Audio"))
	vb.add_child(_slider_row("Volumen general", 0.0, 1.0, 0.05, GameSettings.master_volume,
		func(v: float): GameSettings.master_volume = v))
	vb.add_child(_slider_row("Efectos", 0.0, 1.0, 0.05, GameSettings.sfx_volume,
		func(v: float): GameSettings.sfx_volume = v))

	vb.add_child(_section("Gráficos"))
	vb.add_child(_check_row("Pantalla completa", GameSettings.fullscreen,
		func(on: bool): GameSettings.fullscreen = on))
	vb.add_child(_check_row("Sincronización vertical", GameSettings.vsync,
		func(on: bool): GameSettings.vsync = on))
	vb.add_child(_check_row("Suavizado de bordes (MSAA 4x)", GameSettings.msaa,
		func(on: bool): GameSettings.msaa = on))

	vb.add_child(_section("Teclas"))
	var keys := Label.new()
	keys.text = "WASD mover  ·  Shift correr  ·  Ctrl agacharse\nE recoger / dejar  ·  Clic izq. colocar  ·  R girar\nF lanzar (mantén = más fuerza)  ·  Esc pausa"
	keys.add_theme_font_size_override(&"font_size", 14)
	keys.add_theme_color_override(&"font_color", SOFT)
	vb.add_child(keys)

	var quit := Button.new()
	quit.text = "Salir del juego"
	quit.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit)


# --- Libro de colecciones --------------------------------------------------

func _build_book(parent: Control, style: StyleBox) -> void:
	_book_panel = PanelContainer.new()
	_book_panel.theme = _make_theme()
	_book_panel.add_theme_stylebox_override(&"panel", style)
	parent.add_child(_book_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 10)
	_book_panel.add_child(vb)
	var title := Label.new()
	title.text = "Libro de colecciones"
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Color("ffe7b8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_book_content = VBoxContainer.new()
	_book_content.add_theme_constant_override(&"separation", 8)
	_book_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_book_content)
	var back := Button.new()
	back.text = "Volver"
	back.pressed.connect(func():
		AudioManager.play(&"ui_click")
		_show_book(false))
	vb.add_child(back)


func _show_book(on: bool) -> void:
	_book_panel.visible = on
	_main_panel.visible = not on
	if on:
		_fill_book()


## Rellena el libro con el estado actual: por sala, las colecciones (tipos de objeto) y los tesoros.
func _fill_book() -> void:
	for c in _book_content.get_children():
		c.queue_free()
	var shop := get_tree().get_first_node_in_group(&"shop") as Shop
	if shop == null:
		return
	var found_total := 0
	var treasure_total := 0
	for room in shop.rooms:
		found_total += room.treasures_found()
		treasure_total += room.treasures_total()
	_book_content.add_child(_book_label("Tesoros encontrados: %d de %d" % [found_total, treasure_total], 17, Color("f6c453")))
	for room in shop.rooms:
		_book_content.add_child(HSeparator.new())
		if not room.is_unlocked:
			_book_content.add_child(_book_label("%s  ·  sala por descubrir" % room.display_name, 18, SOFT))
			continue
		var head := "%s  ·  ordenados %d de %d" % [room.display_name, room.placed_items, room.total_items]
		if room.is_completed:
			head += "  ·  completada"
		_book_content.add_child(_book_label(head, 19, ACCENT))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 14)
		flow.add_theme_constant_override(&"v_separation", 4)
		for entry in room.collection_status():
			var chip := _book_label("%s %d/%d" % [entry["label"], entry["placed"], entry["total"]], 14, Color("b8f0c0") if entry["done"] else SOFT)
			chip.autowrap_mode = TextServer.AUTOWRAP_OFF
			flow.add_child(chip)
		_book_content.add_child(flow)
		for treasure in room.treasure_status():
			if treasure["found"]:
				_book_content.add_child(_book_label("Tesoro: %s  ·  %s" % [treasure["name"], treasure["detail"]], 15, Color("f6c453")))
			else:
				_book_content.add_child(_book_label("Tesoro: ???  ·  escondido en algún rincón de la sala", 15, Color(0.7, 0.6, 0.5)))


func _book_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 0)
	return l


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 15)
	l.add_theme_color_override(&"font_color", ACCENT)
	return l


func _slider_row(text: String, min_v: float, max_v: float, step: float, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(150, 24)
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
	t.set_color(&"font_color", &"Label", CREAM)
	t.set_font_size(&"font_size", &"Label", 17)
	for cls in [&"Button", &"CheckBox"]:
		t.set_color(&"font_color", cls, CREAM)
		t.set_color(&"font_hover_color", cls, Color.WHITE)
		t.set_color(&"font_pressed_color", cls, Color.WHITE)
		t.set_color(&"font_focus_color", cls, Color.WHITE)
		t.set_font_size(&"font_size", cls, 18)
	t.set_stylebox(&"normal", &"Button", _button_box(Color(0.30, 0.21, 0.13, 1)))
	t.set_stylebox(&"hover", &"Button", _button_box(Color(0.42, 0.29, 0.16, 1)))
	t.set_stylebox(&"pressed", &"Button", _button_box(Color(0.55, 0.37, 0.18, 1)))
	t.set_stylebox(&"focus", &"Button", _button_box(Color(0.42, 0.29, 0.16, 1)))
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.3, 0.22, 0.15, 1)
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = ACCENT
	slider_fill.set_corner_radius_all(3)
	slider_fill.content_margin_top = 3
	slider_fill.content_margin_bottom = 3
	t.set_stylebox(&"slider", &"HSlider", slider_bg)
	t.set_stylebox(&"grabber_area", &"HSlider", slider_fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", slider_fill)
	return t


func _button_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb

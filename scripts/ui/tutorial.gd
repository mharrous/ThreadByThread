extends CanvasLayer
## Tutorial mínimo: una tarjeta arriba con el paso actual. Avanza sola al hacer
## cada cosa (recoger, apuntar, colocar, lanzar) y no vuelve a aparecer.

const CREAM := Color("fff4e0")
const SOFT := Color("e9d3b0")
const ACCENT := Color("f2a65a")
const GOOD := Color("b8f0c0")
const INK := Color(0.14, 0.09, 0.05, 0.95)

const STEPS := [
	{"text": "Acércate a un ovillo y pulsa E para cogerlo", "event": "pick"},
	{"text": "Llévalo a una estantería y apunta a la fila de su mismo color", "event": "aim"},
	{"text": "Haz clic izquierdo para colocarlo", "event": "place"},
	{"text": "Truco: coge otro y pulsa F para lanzarlo (mantén F = más fuerza)", "event": "throw"},
]

var _index := 0
var _busy := false
var _panel: PanelContainer
var _step_label: Label
var _text_label: Label


func _ready() -> void:
	layer = 6
	if GameSettings.tutorial_done:
		queue_free()
		return
	_build()
	_show_step(0, false)
	Events.item_picked.connect(func(_i): _complete(&"pick"))
	Events.item_placed.connect(func(_i, _s): _complete(&"place"))
	Events.item_thrown.connect(func(_i): _complete(&"throw"))
	Events.target_changed.connect(func(info: Dictionary):
		if info.get("kind", "") == "place":
			_complete(&"aim"))


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.06, 0.55)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 22
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 13
	_panel.add_theme_stylebox_override(&"panel", sb)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_top = 28
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	root.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	_panel.add_child(row)
	_step_label = _label("1 / %d" % STEPS.size(), 15, ACCENT)
	row.add_child(_step_label)
	_text_label = _label("", 19, CREAM)
	row.add_child(_text_label)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", INK)
	l.add_theme_constant_override(&"outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _show_step(index: int, animate: bool = true) -> void:
	_index = index
	_step_label.text = "%d / %d" % [index + 1, STEPS.size()]
	_text_label.text = STEPS[index]["text"]
	_text_label.add_theme_color_override(&"font_color", CREAM)
	if animate:
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.35)
	_busy = false


func _complete(event: StringName) -> void:
	if _busy or _index >= STEPS.size() or StringName(STEPS[_index]["event"]) != event:
		return
	_busy = true
	_text_label.add_theme_color_override(&"font_color", GOOD)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_next)


func _next() -> void:
	if _index + 1 < STEPS.size():
		_show_step(_index + 1)
		return
	_step_label.text = "Listo"
	_text_label.text = "Ya sabes jugar. Ordena toda la sala"
	_text_label.add_theme_color_override(&"font_color", GOOD)
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35)
	tw.tween_interval(4.5)
	tw.tween_property(_panel, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func():
		GameSettings.tutorial_done = true
		GameSettings.save_settings()
		queue_free())

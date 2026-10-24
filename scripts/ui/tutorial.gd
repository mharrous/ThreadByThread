extends CanvasLayer
## Tutorial mínimo: una tarjeta de papel arriba con el paso actual. Avanza sola al hacer
## cada cosa (recoger, apuntar, colocar, lanzar) y no vuelve a aparecer.

const INK := UiStyle.INK
const ACCENT := UiStyle.RED
const GOOD := UiStyle.TEAL

const STEPS := [
	{"text": "Acércate a cualquier cosa del suelo y pulsa E para cogerla", "event": "pick"},
	{"text": "Busca su sección (mira los carteles de las paredes) y apunta a su fila", "event": "aim"},
	{"text": "Haz clic izquierdo para colocarlo", "event": "place"},
	{"text": "Truco: coge otro y pulsa F para lanzarlo (mantén F = más fuerza)", "event": "throw"},
]

var _index := 0
var _busy := false
var _seen: Dictionary = {}   # eventos ya ocurridos: si pasan antes de su paso, ese paso se da por hecho al llegar
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
	# Durante la escena de apertura no se ve (si no se terminó, vuelve después).
	Events.shop_opening_started.connect(func(): _panel.visible = false)
	Events.shop_opening_finished.connect(func(): _panel.visible = true)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", UiStyle.paper(18, 0.95, Vector4(16, 10, 26, 11)))
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
	# Número del paso en una pastilla roja (o "Listo" al final).
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = ACCENT
	bsb.set_corner_radius_all(14)
	bsb.content_margin_left = 12
	bsb.content_margin_right = 12
	bsb.content_margin_top = 2
	bsb.content_margin_bottom = 3
	bsb.anti_aliasing = true
	badge.add_theme_stylebox_override(&"panel", bsb)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	_step_label = UiStyle.label("1 / %d" % STEPS.size(), 16, Color("fff6e6"), &"title")
	badge.add_child(_step_label)
	_text_label = UiStyle.label("", 20, INK, &"bold")
	row.add_child(_text_label)


func _show_step(index: int, animate: bool = true) -> void:
	_index = index
	_step_label.text = "%d / %d" % [index + 1, STEPS.size()]
	_text_label.text = STEPS[index]["text"]
	_text_label.add_theme_color_override(&"font_color", INK)
	if animate:
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	_busy = false
	var step_event := StringName(STEPS[index]["event"])
	if _seen.has(step_event):
		_complete.call_deferred(step_event)


func _complete(event: StringName) -> void:
	_seen[event] = true
	if _busy or _index >= STEPS.size() or StringName(STEPS[_index]["event"]) != event:
		return
	_busy = true
	_text_label.add_theme_color_override(&"font_color", GOOD)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_next)


func _next() -> void:
	if _index + 1 < STEPS.size():
		_show_step(_index + 1)
		return
	_step_label.text = "Listo"
	_text_label.text = "Ya sabes jugar. ¡Ordena toda la mercería! Hay tesoros escondidos en lo alto"
	_text_label.add_theme_color_override(&"font_color", GOOD)
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(4.5)
	tw.tween_property(_panel, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		GameSettings.tutorial_done = true
		GameSettings.save_settings()
		queue_free())

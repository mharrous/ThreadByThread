extends CanvasLayer
## Pantalla de título: tarjeta de papel sobre la tienda desenfocada. Jugar / Continuar, Nueva partida
## (borra el guardado) y Salir. Pausa el juego mientras está abierta. En pruebas (--test-mode) no sale.

const PAPER := Color("f6ecd6")
const PAPER_EDGE := Color("e3d1ad")
const INK := Color("3b2a1d")
const INK_SOFT := Color("7a634d")
const RED := Color("c4433a")
const TEAL := Color("2f7a74")
const BROWN := Color("8a6a4a")

## Tras "Nueva partida" la escena se recarga: esta vez se entra directamente al juego.
static var _skip_next := false

var _root: Control
var _card: PanelContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--test-mode") or _skip_next:
		_skip_next = false
		queue_free()
		return
	_build()
	get_tree().paused = true
	# Diferido: la escena principal captura el ratón en su _ready, que llega después que este.
	(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE).call_deferred()
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Esc no abre el menú de pausa mientras está el título.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.08, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 64
	sb.content_margin_right = 64
	sb.content_margin_top = 44
	sb.content_margin_bottom = 40
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	_card.add_theme_stylebox_override(&"panel", sb)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.resized.connect(func(): _card.pivot_offset = _card.size * 0.5)
	_root.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	col.custom_minimum_size = Vector2(460, 0)
	_card.add_child(col)
	col.add_child(_label("THREAD BY THREAD", 54, INK))
	col.add_child(_label("una mercería por ordenar, hilo a hilo", 20, INK_SOFT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	col.add_child(gap)

	var has_save := SaveGame.has_save()
	var play := _button("Continuar" if has_save else "Jugar", RED)
	play.pressed.connect(_start)
	col.add_child(play)
	if has_save:
		var fresh := _button("Nueva partida", TEAL)
		fresh.pressed.connect(_new_game)
		col.add_child(fresh)
	var quit := _button("Salir", BROWN)
	quit.pressed.connect(func():
		GameSettings.save_settings()
		get_tree().quit())
	col.add_child(quit)
	col.add_child(_label("Demo · 15–25 minutos · Esc: pausa, ajustes y libro de colecciones", 15, INK_SOFT))
	play.grab_focus.call_deferred()


func _start() -> void:
	AudioManager.play(&"ui_click")
	set_process_input(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.35)
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func():
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		queue_free())


## Borra la partida y recarga la escena; el tutorial vuelve a empezar.
func _new_game() -> void:
	AudioManager.play(&"ui_click")
	SaveGame.delete_save()
	GameSettings.tutorial_done = false
	GameSettings.save_settings()
	_skip_next = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override(&"font_size", 21)
	b.add_theme_color_override(&"font_color", Color("fff6e6"))
	b.add_theme_color_override(&"font_hover_color", Color("fff6e6"))
	b.add_theme_color_override(&"font_focus_color", Color("fff6e6"))
	b.add_theme_color_override(&"font_pressed_color", Color("fff6e6"))
	for state in [["normal", color], ["hover", color.lightened(0.12)], ["pressed", color.darkened(0.12)], ["focus", color.lightened(0.12)]]:
		var s := StyleBoxFlat.new()
		s.bg_color = state[1]
		s.set_corner_radius_all(27)
		s.border_color = color.darkened(0.3)
		s.set_border_width_all(2)
		b.add_theme_stylebox_override(StringName(state[0]), s)
	return b

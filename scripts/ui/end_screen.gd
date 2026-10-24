extends CanvasLayer
## Pantalla final tras la apertura de la tienda: de negro a crema, el nombre de la tienda y las gracias.
## "Seguir explorando" vuelve a la tienda abierta (se desvanece y deja jugar); "Menú principal" recarga
## la escena y sale el título. La música sigue sonando por debajo.

signal continue_requested
signal menu_requested

const CREAM := Color("f6ecd6")
const INK := Color("3b2a1d")
const INK_SOFT := Color("7a634d")
const RED := Color("c4433a")
const BROWN := Color("8a6a4a")
const ICON_ITEMS := ["res://data/items/yarn_red.tres", "res://data/items/spool_blue.tres", "res://data/items/btn_wood_light.tres"]

var _bg: ColorRect
var _content: VBoxContainer
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 30
	# Main recaptura el ratón con cualquier clic; con este grupo deja los clics para los botones.
	add_to_group(&"modal_ui")
	_build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_bg.color = Color.BLACK
	_content.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_bg, "color", CREAM, 2.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_content, "modulate:a", 1.0, 1.4).set_delay(1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _buttons[0].grab_focus())


## Esc no abre el menú de pausa encima.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", 16)
	_content.custom_minimum_size = Vector2(520, 0)
	center.add_child(_content)

	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override(&"separation", 18)
	for path in ICON_ITEMS:
		if ResourceLoader.exists(path):
			icons.add_child(ItemIcon.new(load(path), false, 56.0))
	_content.add_child(icons)
	_content.add_child(_label("Thread by Thread", 96, INK, UiStyle.font(&"title")))
	var thanks := _label("Gracias por ordenar la mercería", 34, INK_SOFT, UiStyle.font(&"hand"))
	_content.add_child(thanks)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	_content.add_child(gap)
	var keep := _button("Seguir explorando", RED)
	keep.pressed.connect(_on_continue)
	_content.add_child(keep)
	var menu := _button("Menú principal", BROWN)
	menu.pressed.connect(_on_menu)
	_content.add_child(menu)
	_buttons = [keep, menu]


func _on_continue() -> void:
	AudioManager.play(&"ui_click")
	for b in _buttons:
		b.disabled = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_content, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bg, "color:a", 0.0, 1.4).set_delay(0.2).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func():
		continue_requested.emit()
		queue_free())


func _on_menu() -> void:
	AudioManager.play(&"ui_click")
	for b in _buttons:
		b.disabled = true
	menu_requested.emit()


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _button(text: String, color: Color) -> Button:
	return UiStyle.button(text, color, 22, 56)

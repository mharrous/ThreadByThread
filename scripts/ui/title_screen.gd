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
## Frames de la vuelta de cámara bajo el velo (ver _warm_up).
const WARM_STEPS := 16

## Dibujos decorativos de la tarjeta (los mismos del libro de colecciones).
const ICON_ITEMS := ["res://data/items/yarn_red.tres", "res://data/items/spool_blue.tres", "res://data/items/btn_wood_light.tres"]

var _root: Control
var _card: PanelContainer
var _veil: ColorRect
var _confirm_new := false
var _new_btn: Button
var _play_btn: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	# En pruebas no sale, salvo con --show-title (prueba de la pantalla final y la vuelta al menú).
	if (args.has("--test-mode") and not args.has("--show-title")) or _skip_next:
		_skip_next = false
		queue_free()
		return
	_build()
	get_tree().paused = true
	# Diferido: la escena principal captura el ratón en su _ready, que llega después que este.
	(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE).call_deferred()
	# Entra desde negro: primero se aclara la pantalla, luego aparece la tarjeta.
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	_veil.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 1.0, 0.6).set_delay(0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "scale", Vector2.ONE, 0.7).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_warm_up()


## Bajo el velo negro, la cámara da una vuelta completa en pocos frames: así se compilan antes los
## shaders de lo que aún no se ha visto y no hay tirón la primera vez que se gira jugando.
func _warm_up() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var rest := cam.transform
	for i in WARM_STEPS:
		var yaw := TAU * i / WARM_STEPS
		var pitch := -0.5 if i % 2 == 0 else 0.15
		cam.global_basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
		await get_tree().process_frame
		if not is_instance_valid(cam):
			return
	cam.transform = rest


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
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override(&"separation", 18)
	for path in ICON_ITEMS:
		if ResourceLoader.exists(path):
			icons.add_child(ItemIcon.new(load(path), false, 52.0))
	col.add_child(icons)
	col.add_child(_label("THREAD BY THREAD", 54, INK))
	col.add_child(_label("una mercería por ordenar, hilo a hilo", 20, INK_SOFT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	col.add_child(gap)

	var has_save := SaveGame.has_save()
	var play := _button("Continuar" if has_save else "Jugar", RED)
	play.pressed.connect(_start)
	_play_btn = play
	col.add_child(play)
	if has_save:
		_new_btn = _button("Nueva partida", TEAL)
		_new_btn.pressed.connect(_new_game)
		col.add_child(_new_btn)
	var quit := _button("Salir", BROWN)
	quit.pressed.connect(func():
		GameSettings.save_settings()
		get_tree().quit())
	col.add_child(quit)
	col.add_child(_label("Demo · 15–25 minutos · Esc: pausa, ajustes y libro de colecciones", 15, INK_SOFT))
	play.grab_focus.call_deferred()
	# Velo negro por encima de todo para los fundidos de entrada y salida.
	_veil = ColorRect.new()
	_veil.color = Color(0.05, 0.035, 0.02, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_veil)


func _start() -> void:
	AudioManager.play(&"ui_click")
	# La campanilla de la puerta: entras en la tienda.
	AudioManager.play(&"shop_bell", null, 0.0, 0.0)
	set_process_input(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_root, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func():
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		queue_free())


## Borra la partida y recarga la escena; el tutorial vuelve a empezar.
## Pide un segundo clic: borra la partida guardada.
func _new_game() -> void:
	AudioManager.play(&"ui_click")
	if not _confirm_new:
		_confirm_new = true
		_new_btn.text = "¿Seguro? Se borra la partida"
		return
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

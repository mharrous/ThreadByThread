extends CanvasLayer
## Pantalla de título: la tienda de verdad detrás, con una cámara que se mece despacio por la sala (el gato
## sigue a lo suyo), un velo cálido a la izquierda y encima el nombre del juego con un hilo que se cose
## solo y los botones cosidos: Jugar / Continuar, Nueva partida (pide confirmación y borra el guardado),
## Ajustes (el menú de pausa) y Salir. Arriba a la derecha, el idioma. Al jugar, la cámara vuela hasta
## los ojos del jugador. En pruebas (--test-mode) no sale, salvo con --show-title.

const INK := UiStyle.INK
const CREAM := Color("fff1d8")
## Tras "Nueva partida" la escena se recarga: esta vez se entra directamente al juego.
static var _skip_next := false
## Frames de la vuelta de cámara bajo el velo (ver _warm_up).
const WARM_STEPS := 16
## Dos encuadres de la sala (posición y punto al que mira); la cámara va y viene entre ellos.
const SHOT_A := [Vector3(4.7, 1.5, 3.3), Vector3(-2.6, 0.75, -1.2)]
const SHOT_B := [Vector3(3.6, 1.2, 3.8), Vector3(-3.4, 0.95, 0.3)]
const DRIFT_PERIOD := 46.0
const FLY_TIME := 1.6
## Dibujos decorativos (los mismos del libro de colecciones).
const ICON_ITEMS := ["res://data/items/yarn_red.tres", "res://data/items/spool_blue.tres", "res://data/items/btn_wood_light.tres"]
const LANG_NAMES := {"es": "Español", "en": "English"}


## Hilo rojo que se cose solo bajo el título: una línea ondulada de puntadas que termina en una aguja.
class ThreadLine extends Control:
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(540, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pts := PackedVector2Array()
		var n := 80
		var end := int(n * progress)
		for i in end + 1:
			var x := size.x * float(i) / n
			pts.append(Vector2(x, size.y * 0.5 + sin(x * 0.045) * 7.0))
		if pts.size() > 1:
			PauseMenu.draw_dashed(self, pts, UiStyle.THREAD, 3.0, 10.0, 7.0)
			# La aguja, al final del hilo, inclinada en la dirección de la puntada.
			var tip := pts[pts.size() - 1]
			var dir := (tip - pts[pts.size() - 2]).normalized()
			var back := tip - dir * 34.0
			draw_line(back, tip, Color("dcdcd6"), 3.0, true)
			draw_circle(tip, 1.6, Color("dcdcd6"))
			draw_arc(back + dir * 5.0, 3.0, 0.0, TAU, 12, Color("a9a9a2"), 1.4, true)


var _root: Control
var _card: VBoxContainer
var _veil: ColorRect
var _shade: TextureRect
var _thread: ThreadLine
var _confirm_new := false
var _new_btn: Button
var _play_btn: Button
var _settings_btn: Button
var _buttons: Array[Control] = []
var _lang_buttons: Dictionary = {}
var _cam: Camera3D
var _drift := 0.0
var _player: Player
var _leaving := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	# En pruebas no sale, salvo con --show-title (prueba de la pantalla final y la vuelta al menú).
	if (args.has("--test-mode") and not args.has("--show-title")) or _skip_next:
		_skip_next = false
		queue_free()
		return
	add_to_group(&"title_screen")
	# Main deja los clics para los botones (no captura el ratón) mientras hay una pantalla así.
	add_to_group(&"modal_ui")
	_build()
	# Diferido: la escena principal captura el ratón en su _ready, que llega después que este.
	(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE).call_deferred()
	_enter.call_deferred()
	GameSettings.changed.connect(_refresh_language)


## La tienda sigue viva detrás (el gato pasea, la luz entra por la ventana); el jugador no se mueve y la
## interfaz de juego no se ve hasta jugar.
func _enter() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		_player.input_locked = true
	_set_game_ui(false)
	_veil.color.a = 1.0
	_card.modulate.a = 0.0
	await _warm_up()
	_cam = Camera3D.new()
	_cam.name = "TitleCamera"
	_cam.fov = 58.0
	get_parent().add_child(_cam)
	_place_cam(0.0)
	_cam.make_current()
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_card, "modulate:a", 1.0, 0.5).set_delay(0.5)
	# El título baja un poco, el hilo se cose y los botones entran uno tras otro desde la izquierda.
	tw.parallel().tween_property(_thread, "progress", 1.0, 1.3).set_delay(0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _buttons.size():
		var b := _buttons[i]
		b.modulate.a = 0.0
		tw.parallel().tween_property(b, "modulate:a", 1.0, 0.35).set_delay(1.0 + i * 0.09)
	tw.tween_callback(func(): _play_btn.grab_focus())


func _process(delta: float) -> void:
	if _cam == null or _leaving:
		return
	_drift += delta
	_place_cam(_drift)


## Cámara del título: va y viene entre los dos encuadres, muy despacio, con un leve balanceo.
func _place_cam(t: float) -> void:
	var k := 0.5 - 0.5 * cos(TAU * t / DRIFT_PERIOD)
	var room := _room_node()
	var pos: Vector3 = (SHOT_A[0] as Vector3).lerp(SHOT_B[0], k) + Vector3(0.0, sin(t * 0.5) * 0.03, 0.0)
	var look: Vector3 = (SHOT_A[1] as Vector3).lerp(SHOT_B[1], k)
	var xf := Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)
	_cam.global_transform = room.global_transform * xf if room != null else xf


func _room_node() -> Node3D:
	var shop := get_tree().get_first_node_in_group(&"shop") as Shop
	return shop.room if shop != null else null


## Bajo el velo negro, la cámara del jugador da una vuelta completa en pocos frames: así se compilan antes
## los shaders de lo que aún no se ha visto y no hay tirón la primera vez que se gira jugando.
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


## Esc no abre el menú de pausa mientras está el título (salvo para cerrar los ajustes abiertos desde aquí).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not _pause_menu_open():
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# Velo cálido: oscuro a la izquierda (donde va el texto) y transparente hacia la tienda.
	_shade = TextureRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.38, 0.75])
	grad.colors = PackedColorArray([Color(0.13, 0.07, 0.04, 0.82), Color(0.13, 0.07, 0.04, 0.55), Color(0.13, 0.07, 0.04, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 16
	_shade.texture = tex
	_root.add_child(_shade)

	_card = VBoxContainer.new()
	_card.add_theme_constant_override(&"separation", 12)
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left = 130
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.custom_minimum_size = Vector2(560, 0)
	_root.add_child(_card)

	var head := VBoxContainer.new()
	head.add_theme_constant_override(&"separation", 0)
	_card.add_child(head)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override(&"separation", 14)
	for path in ICON_ITEMS:
		if ResourceLoader.exists(path):
			icons.add_child(ItemIcon.new(load(path), false, 46.0))
	head.add_child(icons)
	var title := UiStyle.label("Thread by Thread", 96, CREAM, &"title")
	title.add_theme_color_override(&"font_shadow_color", Color(0.1, 0.04, 0.0, 0.55))
	title.add_theme_constant_override(&"shadow_offset_x", 0)
	title.add_theme_constant_override(&"shadow_offset_y", 5)
	title.add_theme_constant_override(&"shadow_outline_size", 10)
	head.add_child(title)
	_thread = ThreadLine.new()
	head.add_child(_thread)
	var sub := UiStyle.label("una mercería por ordenar, hilo a hilo", 32, Color("f2d7ad"), &"hand")
	head.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	_card.add_child(gap)

	var has_save := SaveGame.has_save()
	_play_btn = _menu_button("Continuar" if has_save else "Jugar", UiStyle.RED)
	_play_btn.pressed.connect(_start)
	if has_save:
		_new_btn = _menu_button("Nueva partida", UiStyle.TEAL)
		_new_btn.pressed.connect(_new_game)
	_settings_btn = _menu_button("Ajustes", UiStyle.BROWN)
	_settings_btn.pressed.connect(_open_settings)
	var quit := _menu_button("Salir", Color("6e5440"))
	quit.pressed.connect(func():
		GameSettings.save_settings()
		get_tree().quit())

	var foot := UiStyle.label("Demo · 15–25 minutos · Esc: pausa, ajustes y libro de colecciones", 20, Color("e6cfa8"), &"hand")
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 130
	foot.offset_top = -64
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(foot)

	_root.add_child(_build_languages())

	# Velo negro por encima de todo para los fundidos de entrada y salida.
	_veil = ColorRect.new()
	_veil.color = Color(0.05, 0.035, 0.02, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_veil)


func _menu_button(text: String, color: Color) -> Button:
	var b := UiStyle.button(text, color, 24, 60)
	b.custom_minimum_size = Vector2(400, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_entered.connect(func(): AudioManager.play(&"aim_ok", null, -18.0, 0.04))
	_card.add_child(b)
	_buttons.append(b)
	return b


## Arriba a la derecha: una pastilla por idioma; la elegida va rellena.
func _build_languages() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.offset_right = -40
	row.offset_top = 36
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	for code in GameSettings.LANGUAGES:
		var b := Button.new()
		b.text = LANG_NAMES.get(code, code)
		# El nombre de cada idioma se escribe siempre en ese idioma.
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.add_theme_font_override(&"font", UiStyle.font(&"title"))
		b.add_theme_font_size_override(&"font_size", 18)
		b.custom_minimum_size = Vector2(118, 40)
		b.pressed.connect(func():
			AudioManager.play(&"ui_click")
			GameSettings.language = code
			GameSettings.apply_language()
			GameSettings.save_settings()
			GameSettings.changed.emit())
		row.add_child(b)
		_lang_buttons[code] = b
	_style_languages()
	return row


func _style_languages() -> void:
	for code in _lang_buttons:
		var b: Button = _lang_buttons[code]
		var on: bool = code == GameSettings.language
		for state in [&"normal", &"hover", &"pressed", &"focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = Color(UiStyle.PAPER, 0.95) if on else Color(0.13, 0.07, 0.04, 0.45 if state != &"hover" else 0.65)
			s.border_color = UiStyle.PAPER_EDGE if on else Color(1, 0.9, 0.75, 0.5)
			s.set_border_width_all(2)
			s.set_corner_radius_all(20)
			s.anti_aliasing = true
			b.add_theme_stylebox_override(state, s)
		for c in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color"]:
			b.add_theme_color_override(c, INK if on else CREAM)


func _refresh_language() -> void:
	_style_languages()
	if _confirm_new and _new_btn != null:
		_new_btn.text = tr("¿Seguro? Se borra la partida")


func _start() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.play(&"ui_click")
	# La campanilla de la puerta: entras en la tienda.
	AudioManager.play(&"shop_bell", null, 0.0, 0.0)
	set_process_input(false)
	for b in _buttons:
		(b as Button).disabled = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_root, "modulate:a", 0.0, 0.7).set_delay(0.2).set_trans(Tween.TRANS_SINE)
	# La cámara del título vuela hasta los ojos del jugador.
	if _cam != null and _player != null:
		var from := _cam.global_transform
		var to := _player.camera.global_transform
		tw.tween_method(func(t: float):
			var e := t * t * (3.0 - 2.0 * t)
			_cam.global_transform = from.interpolate_with(to, e)
			_cam.fov = lerpf(58.0, _player.camera.fov, e), 0.0, 1.0, FLY_TIME)
	tw.chain().tween_callback(func():
		if _player != null:
			_player.camera.make_current()
			_player.input_locked = false
		if _cam != null:
			_cam.queue_free()
		_set_game_ui(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		queue_free())


## Borra la partida y recarga la escena; el tutorial vuelve a empezar.
## Pide un segundo clic: borra la partida guardada.
func _new_game() -> void:
	AudioManager.play(&"ui_click")
	if not _confirm_new:
		_confirm_new = true
		_new_btn.text = tr("¿Seguro? Se borra la partida")
		return
	SaveGame.delete_save()
	GameSettings.tutorial_done = false
	GameSettings.save_settings()
	_skip_next = true
	get_tree().paused = false
	get_tree().reload_current_scene()


## Ajustes: el menú de pausa (sonido, pantalla, idioma, accesibilidad) encima del título.
func _open_settings() -> void:
	AudioManager.play(&"ui_click")
	var menu := get_parent().get_node_or_null("PauseMenu") as PauseMenu
	if menu == null:
		return
	# El título queda debajo del menú (comparten capa) mientras están abiertos los ajustes.
	_card.visible = false
	layer = menu.layer - 1
	menu.open(true)
	await menu.closed
	layer = 20
	_card.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settings_btn.grab_focus()


func _pause_menu_open() -> bool:
	var menu := get_parent().get_node_or_null("PauseMenu") as PauseMenu
	return menu != null and menu.is_open()


## La interfaz de juego (HUD y tutorial) se esconde bajo el título.
func _set_game_ui(on: bool) -> void:
	var hud := get_parent().get_node_or_null("HUD")
	if hud != null:
		hud.visible = on
	var tut := get_parent().get_node_or_null("Tutorial") as CanvasLayer
	if tut != null:
		tut.visible = on

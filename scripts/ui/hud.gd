extends CanvasLayer
## Interfaz de juego, cozy y en papel: arriba a la izquierda una nota con el progreso y la lista de tareas
## (ordenar, barrer, las cajas y los tesoros), bajo la mira una píldora con la tecla y lo que hace, los
## avisos en una tarjetita abajo, la racha como una cinta arriba a la derecha y los controles al empezar.
## Se construye por código, solo reacciona a eventos (no consulta al juego) y se traduce sola al cambiar
## de idioma (los textos en español son las claves de data/i18n).

const CREAM := UiStyle.CREAM
const SOFT := UiStyle.SOFT
const INK := UiStyle.INK
const GOLD := Color("f6c453")

const OBJECTIVE_SORT := "Lleva cada cosa a su sección: mira los carteles"
const OBJECTIVE_DONE := "¡Mercería ordenada!"
## Todo colocado pero quedan papelitos en el suelo (o en el recogedor).
const OBJECTIVE_SWEEP := "La escoba y el recogedor están junto a la ventana sur"
## Ordenado y barrido, pero quedan cajas de cartón por aplanar y llevar al montón.
const OBJECTIVE_BOXES := "Aplana las cajas y déjalas junto a la puerta"
const CONTROLS := [["WASD", "mover"], ["Shift", "correr"], ["Ctrl", "agacharse"], ["E", "coger / usar"],
	["Clic", "colocar"], ["R", "girar"], ["F", "lanzar"], ["Esc", "pausa"]]


class Crosshair extends Control:
	var active := 0.0
	var target := 0.0
	var deny := false
	## Carga del lanzamiento (0..1): arco que se rellena alrededor del punto.
	var charge := 0.0

	func _process(delta: float) -> void:
		var prev := active
		active = lerpf(active, target, 1.0 - exp(-14.0 * delta))
		if absf(active - prev) > 0.001:
			queue_redraw()
		else:
			# Quieto: no se recalcula hasta que cambie lo que se apunta.
			active = target
			queue_redraw()
			set_process(false)

	func aim(value: float, is_deny: bool) -> void:
		if is_equal_approx(value, target) and is_deny == deny:
			return
		target = value
		deny = is_deny
		set_process(true)
		queue_redraw()

	func set_charge(value: float) -> void:
		if not is_equal_approx(value, charge):
			charge = value
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 3.0, Color(0, 0, 0, 0.30))
		draw_circle(c, 2.0, Color(1, 1, 1, 0.85))
		if active > 0.01:
			var col := Color(GameSettings.aim_deny_color(), 0.9 * active) if deny else Color(1, 1, 1, 0.9 * active)
			draw_arc(c, lerpf(5.0, 10.0, active), 0.0, TAU, 32, col, 1.6, true)
			if deny:
				# "Aquí no": además del color, una X dentro del aro.
				var k := 4.0 * active
				draw_line(c + Vector2(-k, -k), c + Vector2(k, k), col, 1.8, true)
				draw_line(c + Vector2(-k, k), c + Vector2(k, -k), col, 1.8, true)
		if charge > 0.01:
			draw_arc(c, 16.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(0, 0, 0, 0.35), 5.0, true)
			draw_arc(c, 16.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color("f2a65a"), 3.0, true)


## Casilla de la lista de tareas: círculo de hilo vacío, el de la tarea en curso en rojo y, hecha, un
## botón turquesa con una marca (salta un poco al marcarse).
class CheckDot extends Control:
	var done := false
	var current := false
	var gold := false
	var _pop := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(is_done: bool, is_current: bool) -> void:
		if is_done and not done and is_inside_tree():
			_pop = 1.0
			var tw := create_tween()
			tw.tween_property(self, "_pop", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_method(func(_v): queue_redraw(), 0.0, 1.0, 0.45)
		done = is_done
		current = is_current
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := 8.0 * (1.0 + 0.35 * _pop)
		if gold:
			# Estrellita dorada para los tesoros.
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + PI * i / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
			draw_colored_polygon(pts, UiStyle.GOLD)
			return
		if done:
			draw_circle(c, r, UiStyle.TEAL)
			draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3.5), c + Vector2(4.5, -3.5)]), Color.WHITE, 2.2, true)
		else:
			draw_arc(c, r - 1.0, 0.0, TAU, 28, UiStyle.RED if current else UiStyle.INK_SOFT, 2.0, true)
			if current:
				draw_circle(c, 2.5, UiStyle.RED)


var _root: Control
var _crosshair: Crosshair
var _pointer: TargetPointer
var _prompt_card: PanelContainer
var _prompt_box: VBoxContainer
var _prompt_key: PanelContainer
var _prompt_action: Label
var _prompt_title: Label
var _prompt_detail: Label
var _prompt_hint: Label
var _card: PanelContainer
var _title_label: Label
var _count_label: Label
var _percent_label: Label
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat
## Siguiente paso, escrito a mano al pie de la nota.
var _objective: Label
## Lista de tareas: casilla, nombre y valor de cada una.
var _rows: Dictionary = {}
var _floor_label: Label
var _boxes_label: Label
var _treasure_label: Label
var _floor_clean := true
var _boxes_done := true
var _all_placed := false
## Con un objeto en la mano: su sección y cuánto le falta (así se sabe a qué pared llevarlo).
var _section_label: Label
var _held_section: ShopSection
## "Racha ×N" (cinta arriba a la derecha) cuando se colocan cosas seguidas.
var _streak_label: PanelContainer
var _streak_text: Label
var _streak_tween: Tween
var _streak_rest_x := 0.0
var _streak_count := 0
var _room: RoomController
var _toast: PanelContainer
var _toast_text: Label
var _toast_sb: StyleBoxFlat
var _toast_raw := ""
var _banner: PanelContainer
var _controls: PanelContainer
var _toast_tween: Tween
var _prompt_tween: Tween
var _bar_tween: Tween
var _prompt_visible := false
var _info: Dictionary = {}
var _placed := 0
var _total := 0
var _swept := 0
var _scraps := 0
var _stacked := 0
var _boxes_total := 0
## Letrero grande de la escena de apertura (fuera de _root: sigue visible con la interfaz apagada).
var _title_card: Label
var _title_raw := ""
var _cinematic_tween: Tween


func _ready() -> void:
	layer = 5
	_build()
	Events.target_changed.connect(_on_target_changed)
	Events.progress_changed.connect(_on_progress_changed)
	Events.active_room_changed.connect(_on_active_room_changed)
	Events.game_saved.connect(func(): _on_hint("Partida guardada"))
	Events.hint_requested.connect(_on_hint)
	Events.throw_charge_changed.connect(func(v: float): _crosshair.set_charge(v))
	Events.room_completed.connect(_on_room_completed)
	Events.treasure_found.connect(_on_treasure_found)
	Events.held_item_changed.connect(_on_held_item_changed)
	Events.section_progress_changed.connect(func(section, _p, _t):
		if section == _held_section:
			_update_section_label())
	Events.section_completed.connect(_on_section_completed)
	Events.streak_changed.connect(_on_streak_changed)
	Events.floor_progress_changed.connect(_on_floor_progress_changed)
	Events.floor_cleaned.connect(func():
		_floor_clean = true
		_update_objective())
	Events.boxes_progress_changed.connect(_on_boxes_progress_changed)
	_on_progress_changed(0, 0)
	_fade_prompt(false)


## Cambio de idioma: los textos fijos se traducen solos; los compuestos se rehacen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _card != null:
		_refresh_texts()


func _refresh_texts() -> void:
	_set_counts()
	_on_floor_progress_changed(_swept, _scraps)
	_on_boxes_progress_changed(_stacked, _boxes_total)
	_update_treasure_label()
	_update_section_label()
	_update_objective()
	if not _info.is_empty():
		_on_target_changed(_info)
	if _streak_count > 0:
		_streak_text.text = tr("Racha ×%d") % _streak_count
	if _toast_raw != "":
		_toast_text.text = tr(_toast_raw)
	if _title_card != null and _title_raw != "":
		_title_card.text = tr(_title_raw)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Flecha hacia la estantería del objeto en la mano cuando no está a la vista
	_pointer = TargetPointer.new()
	_root.add_child(_pointer)

	# Punto de mira
	_crosshair = Crosshair.new()
	_crosshair.custom_minimum_size = Vector2(48, 48)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	_build_prompt()
	_build_card()
	_build_streak()
	_build_toast()
	_build_controls()
	_build_banner()


## Bajo la mira: píldora oscura con la tecla dibujada y lo que hace; debajo, el nombre y el detalle.
func _build_prompt() -> void:
	_prompt_box = VBoxContainer.new()
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_theme_constant_override(&"separation", 4)
	_prompt_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_prompt_box.anchor_left = 0.5
	_prompt_box.anchor_right = 0.5
	_prompt_box.anchor_top = 0.585
	_prompt_box.anchor_bottom = 0.585
	_prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_box.grow_vertical = Control.GROW_DIRECTION_END
	_prompt_box.custom_minimum_size = Vector2(760, 0)
	_root.add_child(_prompt_box)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_child(center)
	_prompt_card = PanelContainer.new()
	_prompt_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_card.add_theme_stylebox_override(&"panel", UiStyle.dark(18, Vector4(10, 6, 18, 7)))
	center.add_child(_prompt_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_card.add_child(row)
	_prompt_key = UiStyle.keycap("E", 16)
	row.add_child(_prompt_key)
	_prompt_action = UiStyle.label("", 21, CREAM, &"title")
	row.add_child(_prompt_action)
	_prompt_title = _outlined("", 20, CREAM, &"title", 6)
	_prompt_detail = _outlined("", 15, SOFT, &"body", 5)
	_prompt_hint = _outlined("", 14, SOFT, &"body", 5)
	for l in [_prompt_title, _prompt_detail, _prompt_hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt_box.add_child(l)


## La nota de papel de arriba a la izquierda: nombre de la tienda, cuánto hay ordenado y la lista de tareas.
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = Vector2(26, 24)
	_card.add_theme_stylebox_override(&"panel", UiStyle.paper(16, 0.93, Vector4(22, 14, 22, 16)))
	_root.add_child(_card)
	var stitch := PauseMenu.Stitch.new()
	stitch.color = Color(UiStyle.THREAD, 0.55)
	stitch.cover_parent = true
	stitch.inset = 7.0
	stitch.radius = 10.0
	stitch.dash = 6.0
	stitch.gap = 4.0
	stitch.width = 1.6
	_card.add_child(stitch)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 5)
	vb.custom_minimum_size = Vector2(318, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(vb)

	_title_label = UiStyle.label("Thread by Thread · Mercería", 17, UiStyle.INK_SOFT, &"hand")
	vb.add_child(_title_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	_count_label = UiStyle.label("", 23, INK, &"title")
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_count_label)
	_percent_label = UiStyle.label("0 %", 23, UiStyle.RED, &"title")
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_percent_label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiStyle.PAPER_EDGE, 0.9)
	bg.set_corner_radius_all(5)
	bg.anti_aliasing = true
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = UiStyle.RED
	_bar_fill.set_corner_radius_all(5)
	_bar_fill.border_color = UiStyle.RED.darkened(0.2)
	_bar_fill.border_width_bottom = 2
	_bar_fill.anti_aliasing = true
	_bar.add_theme_stylebox_override(&"background", bg)
	_bar.add_theme_stylebox_override(&"fill", _bar_fill)
	vb.add_child(_bar)

	_section_label = UiStyle.label("", 15, UiStyle.RED, &"bold")
	_section_label.visible = false
	vb.add_child(_section_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	vb.add_child(gap)
	for r in [[&"sort", "Cada cosa a su sitio"], [&"sweep", "Barrer el suelo"], [&"boxes", "Cajas al montón"],
			[&"treasure", "Tesoros escondidos"]]:
		vb.add_child(_task_row(r[0], r[1]))
	_floor_label = _rows[&"sweep"]["value"]
	_boxes_label = _rows[&"boxes"]["value"]
	_treasure_label = _rows[&"treasure"]["value"]
	_rows[&"treasure"]["row"].visible = false

	_objective = UiStyle.label("", 19, UiStyle.TEAL, &"hand")
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(318, 0)
	vb.add_child(_objective)


func _task_row(id: StringName, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := CheckDot.new()
	dot.gold = id == &"treasure"
	row.add_child(dot)
	var name_label := UiStyle.label(text, 16, INK, &"body")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := UiStyle.label("", 16, UiStyle.INK_SOFT, &"title")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	_rows[id] = {"row": row, "dot": dot, "name": name_label, "value": value}
	return row


## Cinta roja arriba a la derecha (lejos de la mira, de los letreros del centro y del tutorial).
func _build_streak() -> void:
	_streak_label = PanelContainer.new()
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiStyle.RED
	sb.border_color = UiStyle.RED.darkened(0.3)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	sb.anti_aliasing = true
	_streak_label.add_theme_stylebox_override(&"panel", sb)
	_streak_text = UiStyle.label("", 26, Color("fff2d6"), &"title")
	_streak_label.add_child(_streak_text)
	var stitch := PauseMenu.Stitch.new()
	stitch.color = Color(1, 0.92, 0.8, 0.6)
	stitch.cover_parent = true
	stitch.inset = 5.0
	stitch.radius = 17.0
	_streak_label.add_child(stitch)
	_streak_label.modulate.a = 0.0
	_streak_label.anchor_left = 1.0
	_streak_label.anchor_right = 1.0
	_streak_label.offset_right = -34
	_streak_label.offset_top = 30
	_streak_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_streak_label.grow_vertical = Control.GROW_DIRECTION_END
	_streak_label.resized.connect(func():
		# Crece hacia la izquierda al saltar: nunca se sale por el borde.
		_streak_label.pivot_offset = Vector2(_streak_label.size.x, _streak_label.size.y * 0.5)
		_streak_rest_x = _streak_label.position.x)
	_root.add_child(_streak_label)


## Aviso temporal: tarjetita de papel abajo en el centro (dorada para los logros).
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_sb = UiStyle.paper(20, 0.95, Vector4(22, 8, 22, 10))
	_toast.add_theme_stylebox_override(&"panel", _toast_sb)
	_toast_text = UiStyle.label("", 19, INK, &"bold")
	_toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_text)
	_toast.modulate.a = 0.0
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.82
	_toast.anchor_bottom = 0.82
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_END
	_root.add_child(_toast)


## Controles abajo a la izquierda, con sus teclas dibujadas (desaparecen solos).
func _build_controls() -> void:
	_controls = PanelContainer.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_theme_stylebox_override(&"panel", UiStyle.dark(16, Vector4(12, 7, 14, 8)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_child(row)
	for i in CONTROLS.size():
		if i > 0:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(8, 0)
			row.add_child(sep)
		row.add_child(UiStyle.keycap(CONTROLS[i][0], 13))
		row.add_child(UiStyle.label(CONTROLS[i][1], 14, SOFT, &"body"))
	_controls.anchor_top = 1.0
	_controls.anchor_bottom = 1.0
	_controls.offset_left = 26
	_controls.offset_top = -62
	_controls.offset_bottom = -24
	_controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_controls)
	var ctw := create_tween()
	ctw.tween_interval(18.0)
	ctw.tween_property(_controls, "modulate:a", 0.0, 2.5).set_trans(Tween.TRANS_SINE)


## Banner del final: toda la mercería ordenada (tarjeta de papel cosida).
func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override(&"panel", UiStyle.paper(24, 0.97, Vector4(60, 30, 60, 34)))
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.28
	_banner.anchor_bottom = 0.28
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_END
	_banner.modulate.a = 0.0
	_banner.visible = false
	_root.add_child(_banner)
	var stitch := PauseMenu.Stitch.new()
	stitch.color = UiStyle.THREAD
	stitch.cover_parent = true
	stitch.inset = 10.0
	stitch.radius = 14.0
	_banner.add_child(stitch)
	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override(&"separation", 6)
	_banner.add_child(bvb)
	var t := UiStyle.label("¡La mercería está lista!", 48, UiStyle.RED, &"title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bvb.add_child(t)
	var s := UiStyle.label("Cada cosa tiene su sitio. La tienda vuelve a abrir sus puertas.", 20, UiStyle.INK_SOFT, &"body")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bvb.add_child(s)
	_banner.resized.connect(func(): _banner.pivot_offset = _banner.size * 0.5)


## Texto con contorno (lo que va suelto encima del juego, sin tarjeta).
func _outlined(text: String, size: int, color: Color, kind: StringName, outline: int) -> Label:
	var l := UiStyle.label(text, size, color, kind)
	l.add_theme_color_override(&"font_outline_color", Color(0.14, 0.09, 0.05, 0.9))
	l.add_theme_constant_override(&"outline_size", outline)
	return l


# --- Eventos -------------------------------------------------------------

func _on_target_changed(info: Dictionary) -> void:
	_info = info
	if info.is_empty():
		_crosshair.aim(0.0, false)
		_fade_prompt(false)
		return
	var key: String = info.get("key", "")
	var action: String = info.get("action", "")
	var kind: String = info.get("kind", "")
	_prompt_key.visible = key != ""
	(_prompt_key.get_node("Key") as Label).text = tr(key)
	_prompt_action.text = tr(action)
	_prompt_card.visible = action != ""
	match kind:
		"place":
			_prompt_action.add_theme_color_override(&"font_color", GameSettings.aim_ok_color().lerp(Color.WHITE, 0.35))
		"deny":
			_prompt_action.add_theme_color_override(&"font_color", GameSettings.aim_deny_color().lerp(Color.WHITE, 0.35))
		_:
			_prompt_action.add_theme_color_override(&"font_color", CREAM)
	for pair in [[_prompt_title, "title"], [_prompt_detail, "detail"], [_prompt_hint, "hint"]]:
		var l: Label = pair[0]
		var text: String = info.get(pair[1], "")
		l.text = tr(text)
		l.visible = text != ""
	_crosshair.aim(1.0 if kind in ["pick", "place", "deny"] else 0.0, kind == "deny")
	_fade_prompt(true)


func _on_progress_changed(placed: int, total: int) -> void:
	var changed := placed != _placed
	_placed = placed
	_total = total
	_set_counts()
	var ratio := 0.0 if total == 0 else float(placed) / float(total)
	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(_bar, "value", ratio, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if changed:
		_count_label.pivot_offset = Vector2(0, _count_label.size.y * 0.5)
		var pop := create_tween()
		pop.tween_property(_count_label, "scale", Vector2(1.06, 1.06), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(_count_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_all_placed = total > 0 and placed == total
	_bar_fill.bg_color = UiStyle.TEAL if _all_placed else UiStyle.RED
	_update_objective()


func _set_counts() -> void:
	_count_label.text = tr("Organizados  %d / %d") % [_placed, _total]
	var ratio := 0.0 if _total == 0 else float(_placed) / float(_total)
	_percent_label.text = "%d %%" % roundi(ratio * 100.0)
	_percent_label.add_theme_color_override(&"font_color", UiStyle.TEAL if _all_placed else UiStyle.RED)
	_rows[&"sort"]["value"].text = "%d %%" % roundi(ratio * 100.0)


## La tarea en curso (la primera sin hacer) va en rojo; las hechas, marcadas. Al pie, qué hacer ahora.
func _update_objective() -> void:
	var tasks := [[&"sort", _all_placed], [&"sweep", _floor_clean], [&"boxes", _boxes_done]]
	var current := &""
	for t in tasks:
		if not t[1] and current == &"":
			current = t[0]
	for t in tasks:
		var r: Dictionary = _rows[t[0]]
		(r["dot"] as CheckDot).set_state(t[1], t[0] == current)
		var color := UiStyle.INK_SOFT if t[1] else (INK if t[0] == current else Color(INK, 0.8))
		(r["name"] as Label).add_theme_color_override(&"font_color", color)
		(r["value"] as Label).add_theme_color_override(&"font_color", UiStyle.TEAL if t[1] else UiStyle.INK_SOFT)
	if not _all_placed:
		_objective.text = OBJECTIVE_SORT
	elif not _floor_clean:
		_objective.text = OBJECTIVE_SWEEP
	elif not _boxes_done:
		_objective.text = OBJECTIVE_BOXES
	else:
		_objective.text = OBJECTIVE_DONE
	_objective.add_theme_color_override(&"font_color", UiStyle.GOLD_INK if current == &"" else UiStyle.TEAL)


func _on_floor_progress_changed(swept: int, total: int) -> void:
	_swept = swept
	_scraps = total
	_rows[&"sweep"]["row"].visible = total > 0
	_floor_clean = swept >= total
	var pct := 100 if total == 0 else floori(100.0 * swept / total)
	_floor_label.text = "%d %%" % pct
	_update_objective()


func _on_boxes_progress_changed(stacked: int, total: int) -> void:
	_stacked = stacked
	_boxes_total = total
	_boxes_done = stacked >= total
	_rows[&"boxes"]["row"].visible = total > 0
	_boxes_label.text = "%d / %d" % [stacked, total] if total > 0 else ""
	_update_objective()


func _on_active_room_changed(room: RoomController) -> void:
	_room = room
	_title_label.text = tr(room.display_name)
	_update_objective()
	_update_treasure_label()


func _on_held_item_changed(item) -> void:
	_held_section = null
	if item != null and is_instance_valid(item) and item.data != null and item.room != null and not item.data.treasure:
		_held_section = item.room.section_for_key(item.data.sort_key)
	_update_section_label()


func _update_section_label() -> void:
	_section_label.visible = _held_section != null
	if _held_section != null:
		_section_label.text = tr("Va en:  %s   %d / %d") % [tr(_held_section.display_name), _held_section.placed_items, _held_section.total_items]


## Desde la tercera colocación seguida: salta, crece un poco con la racha y se apaga si se corta.
func _on_streak_changed(count: int) -> void:
	# Ni en la escena de apertura ni con la pantalla final abierta.
	if count < 3 or is_cinematic() or get_tree().get_first_node_in_group(&"modal_ui") != null:
		return
	_streak_count = count
	_streak_label.visible = true
	_streak_text.text = tr("Racha ×%d") % count
	if _streak_tween:
		_streak_tween.kill()
	var peak := minf(1.0 + count * 0.02, 1.3)
	_streak_label.scale = Vector2.ONE * (peak + 0.2)
	# Destello: blanco al saltar y vuelta a su color.
	_streak_label.modulate = Color(1.5, 1.5, 1.5, 1.0)
	_streak_tween = create_tween()
	_streak_tween.set_parallel(true)
	_streak_tween.tween_property(_streak_label, "scale", Vector2.ONE * peak, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_streak_tween.tween_property(_streak_label, "modulate", Color.WHITE, 0.3)
	# Temblor: seno amortiguado en horizontal (más fuerte con la racha) que acaba en reposo.
	var amp := minf(4.0 + count * 0.8, 12.0)
	_streak_tween.tween_method(func(t: float):
		_streak_label.position.x = _streak_rest_x + sin(t * 38.0) * amp * (1.0 - t / 0.3), 0.0, 0.3, 0.3)
	_streak_tween.chain().tween_interval(4.5)
	_streak_tween.chain().tween_property(_streak_label, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)


func _on_section_completed(section) -> void:
	_on_hint(tr("¡Sección completa: %s!") % tr(section.display_name), 3.2, true)


func _update_treasure_label() -> void:
	var on := _room != null and _room.treasures_total() > 0
	_rows[&"treasure"]["row"].visible = on
	if on:
		_treasure_label.text = "%d / %d" % [_room.treasures_found(), _room.treasures_total()]
		_treasure_label.add_theme_color_override(&"font_color", UiStyle.GOLD_INK)


func _on_treasure_found(item) -> void:
	_update_treasure_label()
	_on_hint(tr("¡Tesoro encontrado!  %s") % tr(item.data.display_name), 3.2, true)
	var row: Control = _rows[&"treasure"]["row"]
	row.pivot_offset = Vector2(0, row.size.y * 0.5)
	var pop := create_tween()
	pop.tween_property(row, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(row, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Aviso: sube un poco y aparece; dorado para los logros (sección completa, tesoro).
func _on_hint(text: String, seconds: float = 1.8, golden: bool = false) -> void:
	_toast_raw = text
	_toast_text.text = tr(text)
	_toast_sb.border_color = UiStyle.GOLD if golden else UiStyle.PAPER_EDGE
	_toast_sb.set_border_width_all(3 if golden else 2)
	_toast_text.add_theme_color_override(&"font_color", UiStyle.GOLD_INK if golden else INK)
	if _toast_tween:
		_toast_tween.kill()
	var rest := _toast.position.y
	_toast_tween = create_tween()
	if _toast.modulate.a < 0.05:
		_toast.position.y = rest + 10.0
		_toast_tween.parallel().tween_property(_toast, "position:y", rest, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(_toast, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _on_room_completed(_room_done) -> void:
	_banner.visible = true
	_banner.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.5)
	tw.chain().tween_property(_banner, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE)


## Escena de apertura: se apaga la interfaz de juego (mira, textos, progreso) y se vuelve a encender al final.
func set_cinematic(on: bool, seconds: float = 1.2) -> void:
	if _cinematic_tween != null:
		_cinematic_tween.kill()
	_cinematic_tween = create_tween()
	_cinematic_tween.tween_property(_root, "modulate:a", 0.0 if on else 1.0, seconds).set_trans(Tween.TRANS_SINE)
	if on:
		# La racha no vuelve a asomar al encender la interfaz: se apaga del todo.
		if _streak_tween:
			_streak_tween.kill()
		_streak_label.visible = false
		_streak_label.modulate.a = 0.0


func is_cinematic() -> bool:
	return _root.modulate.a < 0.5


## Letrero grande y cálido en el centro: aparece, se queda `hold` segundos y se va.
func show_title_card(text: String, hold: float = 4.0) -> void:
	if _title_card == null:
		_title_card = UiStyle.label("", 82, Color("ffe9c4"), &"title")
		_title_card.add_theme_color_override(&"font_outline_color", Color(0.24, 0.13, 0.06, 0.75))
		_title_card.add_theme_constant_override(&"outline_size", 14)
		_title_card.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.35))
		_title_card.add_theme_constant_override(&"shadow_offset_y", 4)
		_title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
		_title_card.offset_bottom = -180
		add_child(_title_card)
	_title_raw = text
	_title_card.text = tr(text)
	_title_card.modulate.a = 0.0
	_title_card.pivot_offset = _title_card.size * 0.5
	_title_card.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title_card, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_title_card, "scale", Vector2.ONE, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(_title_card, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)


func _fade_prompt(show_prompt: bool) -> void:
	if show_prompt == _prompt_visible and _prompt_tween != null:
		return
	_prompt_visible = show_prompt
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_prompt_box, "modulate:a", 1.0 if show_prompt else 0.0, 0.12).set_trans(Tween.TRANS_SINE)

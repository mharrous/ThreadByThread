extends CanvasLayer
## Interfaz mínima: punto de mira, nombre del objeto, progreso y objetivo.
## Se construye por código y solo reacciona a eventos (no consulta al juego).

const CREAM := Color("fff4e0")
const INK := Color(0.14, 0.09, 0.05, 0.95)
const SOFT := Color("e9d3b0")
const ACCENT := Color("f2a65a")
const GOLD := Color("f6c453")
const PANEL_BG := Color(0.13, 0.09, 0.06, 0.42)

const OBJECTIVE_DONE := "¡Mercería ordenada!"
## Todo colocado pero quedan papelitos en el suelo (o en el recogedor).
const OBJECTIVE_SWEEP := "Objetivo: barrer el suelo (escoba junto a la ventana sur)"
## Ordenado y barrido, pero quedan cajas de cartón por aplanar y llevar al montón.
const OBJECTIVE_BOXES := "Objetivo: aplanar las cajas de cartón y dejarlas junto a la puerta"


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


var _root: Control
var _crosshair: Crosshair
var _pointer: TargetPointer
var _prompt_box: VBoxContainer
var _prompt_action: Label
var _prompt_title: Label
var _prompt_detail: Label
var _prompt_hint: Label
var _count_label: Label
var _percent_label: Label
var _bar: ProgressBar
var _objective: Label
var _treasure_label: Label
## "Suelo barrido N %": los papelitos fuera del suelo.
var _floor_label: Label
var _floor_clean := true
## "Cajas al montón N / M": cartones aplanados junto a la puerta.
var _boxes_label: Label
var _boxes_done := true
var _boxes_started := false
var _all_placed := false
## Con un objeto en la mano: su sección y cuánto le falta (así se sabe a qué pared llevarlo).
var _section_label: Label
var _held_section: ShopSection
## "Racha ×N" bajo la mira cuando se colocan cosas seguidas.
var _streak_label: Label
var _streak_tween: Tween
var _streak_rest_x := 0.0
var _room: RoomController
var _toast: Label
var _banner: PanelContainer
var _controls: Label
var _toast_tween: Tween
var _prompt_tween: Tween
var _bar_tween: Tween
var _prompt_visible := false
var _title_label: Label
var _objective_text := ""
## Letrero grande de la escena de apertura (fuera de _root: sigue visible con la interfaz apagada).
var _title_card: Label
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

	# Indicador de interacción
	_prompt_box = VBoxContainer.new()
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_theme_constant_override(&"separation", 2)
	_prompt_box.anchor_left = 0.5
	_prompt_box.anchor_right = 0.5
	_prompt_box.anchor_top = 0.60
	_prompt_box.anchor_bottom = 0.60
	_prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_box.grow_vertical = Control.GROW_DIRECTION_END
	_prompt_box.custom_minimum_size = Vector2(700, 0)
	_root.add_child(_prompt_box)
	_prompt_action = _label("", 24, CREAM)
	_prompt_title = _label("", 21, CREAM)
	_prompt_detail = _label("", 16, SOFT, 4)
	_prompt_hint = _label("", 15, SOFT, 4)
	for l in [_prompt_action, _prompt_title, _prompt_detail, _prompt_hint]:
		_prompt_box.add_child(l)

	# Panel de progreso (arriba a la izquierda)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(28, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override(&"panel", sb)
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override(&"separation", 6)
	vb.custom_minimum_size = Vector2(300, 0)
	panel.add_child(vb)

	_title_label = _label("", 15, SOFT, 0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(_title_label)

	var row := HBoxContainer.new()
	vb.add_child(row)
	_count_label = _label("Organizados  0 / 0", 22, CREAM, 0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_count_label)
	_percent_label = _label("0 %", 22, ACCENT, 0)
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_percent_label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(0, 8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.14, 0.1, 0.55)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override(&"background", bg)
	_bar.add_theme_stylebox_override(&"fill", fill)
	vb.add_child(_bar)

	_objective = _label("", 15, SOFT, 0)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(_objective)

	_section_label = _label("", 16, ACCENT, 0)
	_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_section_label.visible = false
	vb.add_child(_section_label)

	_treasure_label = _label("", 14, GOLD, 0)
	_treasure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_treasure_label.visible = false
	vb.add_child(_treasure_label)

	_floor_label = _label("", 14, SOFT, 0)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_floor_label.visible = false
	vb.add_child(_floor_label)

	_boxes_label = _label("", 14, SOFT, 0)
	_boxes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boxes_label.visible = false
	vb.add_child(_boxes_label)

	# Racha: arriba a la derecha, lejos de la mira, de los letreros del centro y del tutorial (arriba al centro).
	_streak_label = _label("", 28, Color("ffd27a"))
	_streak_label.modulate.a = 0.0
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_streak_label.anchor_left = 1.0
	_streak_label.anchor_right = 1.0
	_streak_label.anchor_top = 0.0
	_streak_label.anchor_bottom = 0.0
	_streak_label.offset_right = -36
	_streak_label.offset_top = 30
	_streak_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_streak_label.grow_vertical = Control.GROW_DIRECTION_END
	_streak_label.resized.connect(func():
		# Crece hacia la izquierda al saltar: nunca se sale por el borde.
		_streak_label.pivot_offset = Vector2(_streak_label.size.x, _streak_label.size.y * 0.5)
		_streak_rest_x = _streak_label.position.x)
	_root.add_child(_streak_label)

	# Aviso temporal
	_toast = _label("", 20, CREAM)
	_toast.modulate.a = 0.0
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.80
	_toast.anchor_bottom = 0.80
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_END
	_root.add_child(_toast)

	# Controles (desaparecen solos)
	_controls = _label("WASD mover  ·  Shift correr  ·  Ctrl agacharse  ·  E recoger / dejar  ·  Clic izq. colocar  ·  R girar  ·  F lanzar  ·  Esc pausa", 15, SOFT, 4)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_controls.anchor_top = 1.0
	_controls.anchor_bottom = 1.0
	_controls.offset_left = 28
	_controls.offset_top = -48
	_controls.offset_bottom = -20
	_controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_controls)
	var ctw := create_tween()
	ctw.tween_interval(16.0)
	ctw.tween_property(_controls, "modulate:a", 0.0, 2.5).set_trans(Tween.TRANS_SINE)

	# Banner del final: toda la mercería ordenada
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.13, 0.09, 0.06, 0.62)
	bsb.set_corner_radius_all(22)
	bsb.content_margin_left = 54
	bsb.content_margin_right = 54
	bsb.content_margin_top = 28
	bsb.content_margin_bottom = 30
	_banner.add_theme_stylebox_override(&"panel", bsb)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.30
	_banner.anchor_bottom = 0.30
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_END
	_banner.modulate.a = 0.0
	_banner.visible = false
	_root.add_child(_banner)
	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override(&"separation", 8)
	_banner.add_child(bvb)
	bvb.add_child(_label("¡La mercería está lista!", 46, Color("ffe7b8"), 0))
	bvb.add_child(_label("Cada cosa tiene su sitio. La tienda vuelve a abrir sus puertas.", 20, CREAM, 0))
	_banner.resized.connect(func(): _banner.pivot_offset = _banner.size * 0.5)


func _label(text: String, font_size: int, color: Color, outline: int = 5) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", INK)
	l.add_theme_constant_override(&"outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Eventos -------------------------------------------------------------

func _on_target_changed(info: Dictionary) -> void:
	if info.is_empty():
		_crosshair.aim(0.0, false)
		_fade_prompt(false)
		return
	var key: String = info.get("key", "")
	var action: String = info.get("action", "")
	var kind: String = info.get("kind", "")
	_prompt_action.text = ("[%s]  %s" % [key, action]) if key != "" else action
	_prompt_action.visible = action != ""
	match kind:
		"place":
			_prompt_action.add_theme_color_override(&"font_color", GameSettings.aim_ok_color().lerp(Color.WHITE, 0.35))
		"deny":
			_prompt_action.add_theme_color_override(&"font_color", GameSettings.aim_deny_color().lerp(Color.WHITE, 0.35))
		_:
			_prompt_action.add_theme_color_override(&"font_color", CREAM)
	_prompt_title.text = info.get("title", "")
	_prompt_title.visible = _prompt_title.text != ""
	_prompt_detail.text = info.get("detail", "")
	_prompt_detail.visible = _prompt_detail.text != ""
	_prompt_hint.text = info.get("hint", "")
	_prompt_hint.visible = _prompt_hint.text != ""
	_crosshair.aim(1.0 if kind in ["pick", "place", "deny"] else 0.0, kind == "deny")
	_fade_prompt(true)


func _on_progress_changed(placed: int, total: int) -> void:
	_count_label.text = "Organizados  %d / %d" % [placed, total]
	var ratio := 0.0 if total == 0 else float(placed) / float(total)
	_percent_label.text = "%d %%" % roundi(ratio * 100.0)
	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(_bar, "value", ratio, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_label.pivot_offset = Vector2(0, _count_label.size.y * 0.5)
	var pop := create_tween()
	pop.tween_property(_count_label, "scale", Vector2(1.08, 1.08), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(_count_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_all_placed = total > 0 and placed == total
	_update_objective()


func _update_objective() -> void:
	if not _all_placed:
		_objective.text = _objective_text
	else:
		_objective.text = OBJECTIVE_SWEEP if not _floor_clean else (OBJECTIVE_BOXES if not _boxes_done else OBJECTIVE_DONE)
	# La línea de las cajas sale al terminar de barrer (o en cuanto se ha llevado alguna al montón).
	_boxes_label.visible = _boxes_label.text != "" and (_floor_clean or _boxes_started)


func _on_floor_progress_changed(swept: int, total: int) -> void:
	_floor_label.visible = total > 0
	_floor_clean = swept >= total
	var pct := 100 if total == 0 else floori(100.0 * swept / total)
	_floor_label.text = "Suelo barrido  %d %%" % pct
	_floor_label.add_theme_color_override(&"font_color", GOLD if swept >= total else SOFT)
	_update_objective()


func _on_boxes_progress_changed(stacked: int, total: int) -> void:
	_boxes_done = stacked >= total
	_boxes_started = stacked > 0
	_boxes_label.text = "Cajas al montón  %d / %d" % [stacked, total] if total > 0 else ""
	_boxes_label.add_theme_color_override(&"font_color", GOLD if _boxes_done else SOFT)
	_update_objective()


func _on_active_room_changed(room: RoomController) -> void:
	_room = room
	_title_label.text = room.display_name
	_objective_text = room.objective
	_objective.text = _objective_text
	_update_treasure_label()


func _on_held_item_changed(item) -> void:
	_held_section = null
	if item != null and is_instance_valid(item) and item.data != null and item.room != null and not item.data.treasure:
		_held_section = item.room.section_for_key(item.data.sort_key)
	_update_section_label()


func _update_section_label() -> void:
	_section_label.visible = _held_section != null
	if _held_section != null:
		_section_label.text = "Va en:  %s   %d / %d" % [_held_section.display_name, _held_section.placed_items, _held_section.total_items]


## Desde la tercera colocación seguida: salta, crece un poco con la racha y se apaga si se corta.
func _on_streak_changed(count: int) -> void:
	# Ni en la escena de apertura ni con la pantalla final abierta.
	if count < 3 or is_cinematic() or get_tree().get_first_node_in_group(&"modal_ui") != null:
		return
	_streak_label.visible = true
	_streak_label.text = "Racha ×%d" % count
	if _streak_tween:
		_streak_tween.kill()
	var peak := minf(1.0 + count * 0.03, 1.45)
	_streak_label.scale = Vector2.ONE * (peak + 0.25)
	# Destello: blanco al saltar y vuelta al dorado.
	_streak_label.modulate = Color(1.6, 1.6, 1.6, 1.0)
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
	_toast.add_theme_color_override(&"font_color", GOLD)
	_on_hint("¡Sección completa: %s!" % section.display_name, 3.2)


func _update_treasure_label() -> void:
	_treasure_label.visible = _room != null and _room.treasures_total() > 0
	if _treasure_label.visible:
		_treasure_label.text = "Tesoros escondidos  %d / %d" % [_room.treasures_found(), _room.treasures_total()]


func _on_treasure_found(item) -> void:
	_update_treasure_label()
	_toast.add_theme_color_override(&"font_color", GOLD)
	_on_hint("¡Tesoro encontrado!  %s" % item.data.display_name, 3.2)
	_treasure_label.pivot_offset = Vector2(0, _treasure_label.size.y * 0.5)
	var pop := create_tween()
	pop.tween_property(_treasure_label, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(_treasure_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_hint(text: String, seconds: float = 1.8) -> void:
	_toast.text = text
	if seconds <= 1.8:
		_toast.add_theme_color_override(&"font_color", CREAM)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _on_room_completed(_room) -> void:
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


## Letrero grande, cálido y con serifa en el centro: aparece, se queda `hold` segundos y se va.
func show_title_card(text: String, hold: float = 4.0) -> void:
	if _title_card == null:
		_title_card = Label.new()
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])
		_title_card.add_theme_font_override(&"font", font)
		_title_card.add_theme_font_size_override(&"font_size", 78)
		_title_card.add_theme_color_override(&"font_color", Color("ffe9c4"))
		_title_card.add_theme_color_override(&"font_outline_color", Color(0.24, 0.13, 0.06, 0.75))
		_title_card.add_theme_constant_override(&"outline_size", 12)
		_title_card.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.35))
		_title_card.add_theme_constant_override(&"shadow_offset_y", 4)
		_title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
		_title_card.offset_bottom = -180
		_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title_card)
	_title_card.text = text
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

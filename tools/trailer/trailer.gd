extends Node
## Tráiler del juego, grabado con el Movie Maker de Godot (vídeo y sonido del propio juego, a 30 fps fijos).
## Monta la tienda de verdad y la "juega" con un guion de planos: la tienda hecha un lío, colocar ovillos
## en primera persona, antes y después, el gato (revolcándose, la caricia con su ronroneo), barrer, aplanar
## las cajas, la apertura de la tienda y el logotipo. Los rótulos salen en el idioma de --lang.
## Uso (ver tools/trailer/grabar_trailer.ps1, que también lo pasa a mp4):
##   godot --path . --resolution 1920x1080 --write-movie <salida.avi> --fixed-fps 30 \
##         res://tools/trailer/trailer.tscn -- --test-mode --no-autopause --lang=es

const FADE := 0.45

var main: Node
var shop: Shop
var room: RoomController
var player: Player
var holder: ItemHolder
var hud: Node
var _cam: Camera3D
var _black: ColorRect
var _caption: Label
var _caption_box: PanelContainer
var _end_card: Control


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_build_overlay()
	_black.color.a = 1.0
	for i in 20:
		await get_tree().process_frame
	shop = main.get_node("Shop")
	room = shop.room
	player = main.get_node("Player")
	holder = player.get_node("ItemHolder")
	hud = main.get_node("HUD")
	var tut := main.get_node_or_null("Tutorial") as CanvasLayer
	if tut != null:
		tut.visible = false
	# Los controles de abajo no salen en el tráiler.
	hud._controls.visible = false
	# Toda la música desde el principio (en el juego entra con el progreso).
	AudioManager.fade_music_in(2.0, -1)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	room.add_child(_cam)

	await _shot_mess()
	await _shot_place()
	await _shot_before_after()
	await _shot_cat()
	await _shot_sweep()
	await _shot_boxes()
	await _shot_opening()
	await _shot_logo()
	get_tree().quit()


# --- Planos ----------------------------------------------------------------

## 1. La tienda hecha un lío: travelling lento por la sala.
func _shot_mess() -> void:
	_cinematic(true)
	_cam.make_current()
	_fade(false)
	_caption_in("Una mercería hecha un lío…", 0.8, 3.6)
	await _dolly(Vector3(4.8, 1.55, 3.4), Vector3(-2.4, 0.6, -1.4), Vector3(2.4, 1.15, 3.6), Vector3(-3.6, 0.7, 0.2), 6.0)
	await _fade(true)


## 2. Colocar ovillos en primera persona: los coge del suelo y los mete en su fila (con su racha).
func _shot_place() -> void:
	var yarn := room.section_by_id(&"yarn")
	var key: StringName = yarn.catalog.items[0].sort_key
	var found := room.find_row(key)
	var unit: StorageUnit = found["unit"]
	var row: int = found["row"]
	var items: Array[PickableItem] = []
	for it in room.get_items():
		if it.data.sort_key == key and it.state == PickableItem.State.LOOSE and items.size() < 5:
			items.append(it)
	var hint := unit.stand_hint(row, unit.first_free_slot(row), items[0])
	var stand: Vector3 = hint["position"]
	var back := (stand - (hint["look"] as Vector3))
	back.y = 0.0
	back = back.normalized()
	var side := back.cross(Vector3.UP)
	# Los ovillos se dejan a los pies del jugador, entre él y la estantería y a los lados.
	for i in items.size():
		var at := stand - back * 0.55 + side * (i - 2) * 0.22 + back * absf(i - 2) * 0.12
		items[i].global_position = Vector3(at.x, room.global_position.y + items[i].half_height, at.z)
		items[i].rotation = Vector3(0.0, randf() * TAU, 0.0)
	player.teleport(stand)
	await _settle()
	player.look_at_point(hint["look"])
	_cinematic(false)
	player.camera.make_current()
	await _frames(4)
	_fade(false)
	_caption_in("Coloca cada cosa en su sitio", 0.4, 3.0)
	for it in items:
		await _look_smooth(it.global_position, 0.35)
		await _frames(3)
		await _press(&"interact")
		await _wait_until(func(): return holder.state == ItemHolder.State.HOLDING, 1.5)
		var slot := unit.first_free_slot(row)
		if slot < 0:
			break
		var h := unit.stand_hint(row, slot, it)
		await _look_smooth(h["look"], 0.45)
		await _frames(4)
		if holder.aim_status == StorageUnit.SlotStatus.OK:
			await _press(&"place")
			await _wait_until(func(): return holder.state == ItemHolder.State.EMPTY, 1.5)
		await _wait(0.12)
	await _wait(0.8)
	await _fade(true)


## 3. Antes y después: la pared de botones y carretes, hecha un lío y luego ordenada.
func _shot_before_after() -> void:
	_cinematic(true)
	_cam.make_current()
	_place_cam(Vector3(2.7, 1.45, -1.2), Vector3(2.7, 1.05, -4.5))
	_fade(false)
	_caption_in("Hilo a hilo", 0.3, 3.4)
	await _wait(1.5)
	room.solve_instantly(room.section_by_id(&"buttons"))
	await _flash()
	await _drift(Vector3(2.7, 1.45, -1.2), Vector3(2.4, 1.4, -1.6), Vector3(2.7, 1.05, -4.5), 2.2)
	await _fade(true)


## 4. El gato: revolcándose panza arriba y la caricia (con su ronroneo y corazones).
func _shot_cat() -> void:
	var cat := room.shell.get_node("ShopCat") as ShopCat
	var at := Vector3(0.6, 0.0, 1.9)
	cat._gen += 1
	cat._move_to = Vector3.INF
	cat.position = at
	cat.rotation.y = PI * 0.5
	cat._set_animating(true)
	cat._set_pose(&"roll")
	# El jugador junto a la cámara: el gato le mira al acariciarlo.
	player.teleport(room.to_global(at + Vector3(0.0, 0.0, 1.3)))
	_place_cam(at + Vector3(0.15, 0.42, 1.25), at + Vector3(0.0, 0.16, 0.0))
	_cam.fov = 42.0
	await _frames(10)
	_fade(false)
	_caption_in("Mima a Botón, el gato de la tienda", 0.5, 5.5)
	await _drift(at + Vector3(0.15, 0.42, 1.25), at + Vector3(-0.2, 0.36, 1.1), at + Vector3(0.0, 0.16, 0.0), 3.2)
	cat.interact()
	await _wait(3.0)
	await _fade(true)
	_cam.fov = 55.0
	cat._life()


## 5. Barrer: escobazos en primera persona y vaciar el recogedor en la papelera.
func _shot_sweep() -> void:
	var sweep := shop.floor_sweep()
	var target := Vector3(2.2, 0.0, 2.9)
	player.teleport(room.to_global(target + Vector3(-0.6, 0.0, -0.9)))
	await _settle()
	player.look_at_point(room.to_global(target))
	holder.sweeper.take(sweep)
	_cinematic(false)
	player.camera.make_current()
	await _wait(0.5)
	_fade(false)
	_caption_in("Barre los retales del suelo", 0.3, 3.4)
	# Mantiene el clic mientras pasea la mirada por el suelo.
	_hold(&"place", true)
	for p in [target + Vector3(0.6, 0, 0.1), target + Vector3(0.0, 0, 0.5), target + Vector3(-0.6, 0, 0.2), target]:
		await _look_smooth(room.to_global(p), 0.9)
	_hold(&"place", false)
	await _wait(0.3)
	await _fade(true)
	if sweep.pan_count() == 0:
		sweep.sweep_at(sweep.to_local(sweep.nearest_scrap(player.global_position)), ShopSweep.BIN_AT)
	player.teleport(room.to_global(ShopSweep.BIN_AT + Vector3(-0.4, 0.0, -1.2)))
	await _settle()
	player.look_at_point(sweep.bin_top())
	await _frames(4)
	_fade(false)
	await _wait(0.3)
	await _press(&"place", 2)
	await _wait(2.2)
	holder.sweeper.put_back()
	await _fade(true)


## 6. Las cajas: aplanar una (crujido y polvo), llevarla y dejarla en el montón de junto a la puerta.
func _shot_boxes() -> void:
	var boxes := shop.cardboard()
	var b := boxes.boxes[3]
	player.teleport(room.to_global(b.position + Vector3(-0.2, 0.0, 1.35)))
	await _settle()
	player.look_at_point(b.global_position + Vector3.UP * 0.12)
	await _wait(1.2)
	_fade(false)
	_caption_in("Y recoge las cajas", 0.3, 3.2)
	await _wait(0.5)
	await _press(&"interact")
	await _wait(1.6)
	await _fade(true)
	# El resto ya en el montón, menos este: el último cartón ata el montón.
	for o in boxes.boxes:
		if o != b and o.state != CardboardBox.State.STACKED:
			o.flatten_instantly()
			o.set_stacked()
			o.transform = boxes.pile_slot(boxes.stacked_count() - 1, o)
	player.teleport(room.to_global(ShopBoxes.PILE_AT + Vector3(-1.7, 0.0, -0.5)))
	await _settle()
	player.look_at_point(boxes.pile_target())
	await _frames(6)
	_fade(false)
	await _wait(0.5)
	await _press(&"place")
	await _wait(1.6)
	await _fade(true)


## 7. La apertura: todo listo, suenan las campanillas, se abre la puerta y entra la primera clienta.
func _shot_opening() -> void:
	var opening := main.get_node("ShopOpening") as ShopOpening
	shop.floor_sweep().finish_instantly()
	shop.cardboard().finish_instantly()
	room.solve_instantly()
	player.teleport(room.to_global(Vector3(1.6, 0.0, -0.6)))
	await _settle()
	player.look_at_point(room.to_global(Vector3(6.0, 1.3, 2.2)))
	player.camera.make_current()
	# Solo la escena: sin la nota, la racha ni los avisos (el letrero grande sí sale, va fuera).
	_cinematic(false)
	hud.set_cinematic(true, 0.01)
	# Sin la espera del juego tras ordenar: empieza ya. La primera campanada suena sobre negro.
	opening.play()
	while opening.step != &"bells":
		await get_tree().process_frame
	await _wait(0.6)
	_fade(false, 0.8)
	while opening.step != &"look":
		await get_tree().process_frame
	await _wait(1.5)
	await _fade(true, 0.9)


## 8. Logotipo, frase y "próximamente".
func _shot_logo() -> void:
	AudioManager.fade_music_in(1.0, -1)
	_end_card.visible = true
	_end_card.modulate.a = 0.0
	_black.color = Color("f6ecd6")
	var tw := create_tween()
	tw.tween_property(_end_card, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await _wait(4.2)
	var out := create_tween().set_parallel(true)
	out.tween_property(_end_card, "modulate", Color(0, 0, 0, 1), 1.2).set_trans(Tween.TRANS_SINE)
	out.tween_property(_black, "color", Color(0, 0, 0, 1), 1.2).set_trans(Tween.TRANS_SINE)
	AudioManager.fade_music_out(1.2)
	await out.finished
	await _wait(0.3)


# --- Cámara ----------------------------------------------------------------

func _place_cam(pos: Vector3, look: Vector3) -> void:
	_cam.position = pos
	_cam.look_at(room.to_global(look), Vector3.UP)


## Travelling: de (pos_a, mira a look_a) a (pos_b, look_b) en `secs` con suavizado.
func _dolly(pos_a: Vector3, look_a: Vector3, pos_b: Vector3, look_b: Vector3, secs: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var e := t * t * (3.0 - 2.0 * t)
		_place_cam(pos_a.lerp(pos_b, e), look_a.lerp(look_b, e)), 0.0, 1.0, secs)
	await tw.finished


func _drift(pos_a: Vector3, pos_b: Vector3, look: Vector3, secs: float) -> void:
	await _dolly(pos_a, look, pos_b, look, secs)


## Gira la mirada del jugador hacia un punto, suave.
func _look_smooth(point: Vector3, secs: float) -> void:
	var cam := player.camera.global_transform
	var start := cam.origin - cam.basis.z * cam.origin.distance_to(point)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var e := t * t * (3.0 - 2.0 * t)
		player.look_at_point(start.lerp(point, e)), 0.0, 1.0, secs)
	await tw.finished


## En los planos de cámara libre no se ve la interfaz de juego.
func _cinematic(on: bool) -> void:
	hud.visible = not on


# --- Rótulos y fundidos ------------------------------------------------------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color(0.03, 0.02, 0.01, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	_caption_box = PanelContainer.new()
	_caption_box.add_theme_stylebox_override(&"panel", UiStyle.paper(26, 0.94, Vector4(42, 14, 42, 18)))
	_caption_box.anchor_left = 0.5
	_caption_box.anchor_right = 0.5
	_caption_box.anchor_top = 0.78
	_caption_box.anchor_bottom = 0.78
	_caption_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caption_box.modulate.a = 0.0
	layer.add_child(_caption_box)
	var stitch := PauseMenu.Stitch.new()
	stitch.color = UiStyle.THREAD
	stitch.inset = -32.0
	stitch.radius = 18.0
	_caption_box.add_child(stitch)
	_caption = UiStyle.label("", 52, UiStyle.INK, &"title")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_box.add_child(_caption)
	_caption_box.resized.connect(func(): _caption_box.pivot_offset = _caption_box.size * 0.5)

	_end_card = CenterContainer.new()
	_end_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_card.visible = false
	layer.add_child(_end_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	_end_card.add_child(col)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override(&"separation", 22)
	for path in ["res://data/items/yarn_red.tres", "res://data/items/spool_blue.tres", "res://data/items/btn_wood_light.tres"]:
		icons.add_child(ItemIcon.new(load(path), false, 70.0))
	col.add_child(icons)
	var title := UiStyle.label("Thread by Thread", 140, UiStyle.INK, &"title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UiStyle.label("una mercería por ordenar, hilo a hilo", 48, UiStyle.RED, &"hand")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)
	var soon := UiStyle.label("Próximamente", 40, UiStyle.TEAL, &"title")
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(soon)


## Rótulo: aparece con un pequeño salto a los `delay` segundos y se va tras `hold` (sin esperar).
func _caption_in(text: String, delay: float, hold: float) -> void:
	_caption.text = text
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): _caption_box.scale = Vector2(0.9, 0.9))
	tw.tween_property(_caption_box, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_caption_box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_caption_box, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## Fundido a negro (to_black) o desde negro.
func _fade(to_black: bool, secs: float = FADE) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0 if to_black else 0.0, secs).set_trans(Tween.TRANS_SINE)
	await tw.finished


## Destello blanco corto (el "después").
func _flash() -> void:
	_black.color = Color(1, 0.97, 0.9, 0.85)
	var tw := create_tween()
	tw.tween_property(_black, "color", Color(1, 0.97, 0.9, 0.0), 0.5).set_trans(Tween.TRANS_SINE)
	AudioManager.play(&"collection", null, -4.0, 0.0)
	await tw.finished
	_black.color = Color(0.03, 0.02, 0.01, 0.0)


# --- Entrada simulada --------------------------------------------------------

func _press(action: StringName, hold_frames: int = 1) -> void:
	_hold(action, true)
	for i in hold_frames:
		await get_tree().process_frame
	_hold(action, false)


func _hold(action: StringName, on: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = on
	Input.parse_input_event(ev)


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

extends Node
## Prueba de humo de extremo a extremo (sin ventana): arranca la escena principal,
## y con eventos de entrada reales recoge, rechaza, deja, recoloca y ordena todos los objetos.
## Ejecutar:  godot --headless --path . res://tests/smoke_test.tscn
## Código de salida 0 = todo correcto.

var _failures := 0
var _rejected := 0
var _collections := 0
var _room_done := false
var _placed_events := 0
var _bounces := 0
var _throws := 0
var _landed := 0

var main: Node
var room: RoomController
var player: Player
var holder: ItemHolder


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK    ", msg)
	else:
		_failures += 1
		print("  FALLO ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_until(cond: Callable, timeout: float = 4.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


## Deja que la física resuelva colisiones tras un teletransporte antes de apuntar.
func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var rel := InputEventAction.new()
	rel.action = action
	rel.pressed = false
	Input.parse_input_event(rel)


func _stand_and_look_at_item(item: PickableItem) -> bool:
	var p := item.global_position
	var base := Vector3(p.x, 0.0, p.z)
	var toward := Vector3(-p.x, 0.0, 1.0 - p.z)
	toward = toward.normalized() if toward.length() > 0.1 else Vector3(0, 0, 1)
	for d: Vector3 in [toward, Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
		player.teleport(base + d * 0.9)
		await _settle()
		player.look_at_point(p)
		await _frames(3)
		if holder.hover_item == item:
			return true
	print("    (diagnóstico) objeto en ", item.global_position, " hover=", holder.hover_item, " jugador=", player.global_position)
	return false


func _stand_at_slot(shelf: ShelfUnit, row: int, slot: int, radius: float) -> void:
	var target := shelf.slot_world_position(row, slot, radius)
	player.teleport(Vector3(target.x, 0.0, shelf.global_position.z + shelf.depth + 0.95))
	await _settle()
	player.look_at_point(target)
	await _frames(3)


func _pick(item: PickableItem) -> bool:
	if not await _stand_and_look_at_item(item):
		return false
	await _press(&"interact")
	var ok := await _wait_until(func(): return holder.state == ItemHolder.State.HOLDING)
	if not (ok and holder.held == item):
		print("    (diagnóstico) tras E: estado=", holder.state, " sostenido=", holder.held, " objetivo=", item, " item.state=", item.state,
			" hover=", holder.hover_item, " jugador=", player.global_position, " objeto=", item.global_position, " capa=", item.collision_layer)
	return ok and holder.held == item


func _place_on_correct_row(item: PickableItem) -> bool:
	var found := room.find_row(item.data.sort_key)
	var shelf: ShelfUnit = found["shelf"]
	var row: int = found["row"]
	var slot := shelf.first_free_slot(row)
	await _stand_at_slot(shelf, row, slot, item.radius)
	if holder.aim_status != ShelfUnit.SlotStatus.OK:
		return false
	await _press(&"place")
	return await _wait_until(func(): return holder.state == ItemHolder.State.EMPTY)


func _run() -> void:
	print("== Thread by Thread · prueba de humo ==")
	var packed := load("res://scenes/main.tscn") as PackedScene
	main = packed.instantiate()
	# --items-per-color=N  (por defecto 1 = 10 objetos; 15 = 150 objetos)
	var per_color := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--items-per-color="):
			per_color = int(arg.trim_prefix("--items-per-color="))
	(main.get_node("Room") as RoomController).items_per_color = per_color
	var total := per_color * 10
	add_child(main)
	await _frames(10)
	room = main.get_node("Room")
	player = main.get_node("Player")
	holder = player.get_node("ItemHolder")

	Events.item_rejected.connect(func(_i, _r): _rejected += 1)
	Events.item_placed.connect(func(_i, _s): _placed_events += 1)
	Events.collection_completed.connect(func(_k): _collections += 1)
	Events.room_completed.connect(func(): _room_done = true)
	Events.item_bounced.connect(func(_i, _s, _p, _snd): _bounces += 1)
	Events.item_thrown.connect(func(_i): _throws += 1)
	Events.item_landed.connect(func(_i): _landed += 1)

	print("-- Arranque")
	var items := room.get_items().duplicate()
	_check(items.size() == total, "la sala genera %d ovillos (%d)" % [total, items.size()])
	_check(room.total_items == total and room.placed_items == 0, "progreso inicial 0/%d" % total)
	_check(room.get_shelves().size() == 2, "hay 2 estanterías")
	var keys := {}
	for it: PickableItem in items:
		keys[it.data.sort_key] = true
		_check(not room.find_row(it.data.sort_key).is_empty(), "fila disponible para '%s'" % it.data.sort_key)
	_check(keys.size() == 10, "10 colores distintos")
	var spread_ok := true
	for it: PickableItem in items:
		var q := it.global_position
		if absf(q.x) > 3.0 or absf(q.z) > 2.5 or q.y < 0.0 or q.y > 1.0:
			spread_ok = false
	_check(spread_ok, "todos los objetos nacen dentro de la sala")
	await _wait_until(func(): return AudioManager.ready_to_play, 6.0)
	_check(AudioManager.ready_to_play, "sonidos cargados")
	print("        bancos con audio editado (art/audio/sfx): %d  %s" % [AudioManager.overridden.size(), str(AudioManager.overridden)])

	print("-- Recoger y rechazo en fila equivocada")
	var first: PickableItem = items[0]
	_check(await _pick(first), "recoger ovillo con E (estado HOLDING)")
	_check(first.state == PickableItem.State.HELD, "el ovillo queda en estado HELD")
	var wrong_key: StringName = first.data.sort_key
	for other: PickableItem in items:
		if other.data.sort_key != first.data.sort_key:
			wrong_key = other.data.sort_key
			break
	var wrong := room.find_row(wrong_key)
	var wshelf: ShelfUnit = wrong["shelf"]
	await _stand_at_slot(wshelf, wrong["row"], 7, first.radius)
	_check(holder.aim_status == ShelfUnit.SlotStatus.WRONG_ROW, "la puntería detecta fila equivocada")
	await _press(&"place")
	await _frames(4)
	_check(holder.state == ItemHolder.State.HOLDING, "sigue sostenido tras clic en fila equivocada")
	_check(_rejected == 1 and room.placed_items == 0, "evento de rechazo emitido y progreso intacto")

	print("-- Dejar sobre una superficie")
	player.teleport(Vector3(0.0, 0.0, 1.3))
	await _settle()
	player.look_at_point(Vector3(0.0, 0.0, 0.4))
	await _frames(3)
	await _press(&"set_down")
	_check(await _wait_until(func(): return first.state == PickableItem.State.LOOSE), "dejar en el suelo con clic derecho")
	_check(holder.state == ItemHolder.State.EMPTY, "las manos quedan libres")
	_check(absf(first.global_position.y - first.radius) < 0.01, "el ovillo reposa sobre el suelo")

	print("-- Lanzar: rebote y reposo")
	_check(await _pick(first), "recoger el ovillo del suelo otra vez")
	player.teleport(Vector3(-1.0, 0.0, 1.5))
	await _settle()
	player.look_at_point(Vector3(-0.6, 0.6, -0.8))
	await _frames(2)
	await _press(&"throw")
	await _frames(1)
	_check(first.state == PickableItem.State.THROWN or first.state == PickableItem.State.LOOSE, "al lanzar el objeto sale de la mano")
	_check(_throws == 1, "evento item_thrown emitido")
	_check(holder.state == ItemHolder.State.EMPTY, "las manos quedan libres tras lanzar")
	var squash_node: Node3D = first.get_node("Squash")
	var max_squash := 0.0
	var waited := 0.0
	while first.state == PickableItem.State.THROWN and waited < 12.0:
		var s := squash_node.transform.basis.get_scale()
		max_squash = maxf(max_squash, maxf(absf(s.x - 1.0), maxf(absf(s.y - 1.0), absf(s.z - 1.0))))
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(first.state == PickableItem.State.LOOSE, "el ovillo se detiene y vuelve a congelarse")
	_check(max_squash > 0.02, "el ovillo se aplasta al rebotar (deformación máx. %.3f)" % max_squash)
	_check(_bounces >= 1, "hubo al menos un rebote (%d)" % _bounces)
	_check(_throws == 1 and _landed == 1, "eventos de lanzamiento y aterrizaje")
	var p := first.global_position
	_check(absf(p.x) < 3.0 and absf(p.z) < 2.5 and p.y > -0.05 and p.y < 2.0, "queda dentro de la sala (%s)" % str(p.snapped(Vector3.ONE * 0.01)))
	_check(first.collision_layer == PickableItem.LAYER_ITEMS and first.freeze, "vuelve a ser recogible y está congelado")

	print("-- Ordenar los %d ovillos" % total)
	for i in items.size():
		var it: PickableItem = items[i]
		var picked := await _pick(it)
		_check(picked, "recoger #%d (%s)" % [i + 1, it.data.sort_key])
		if not picked:
			continue
		var placed := await _place_on_correct_row(it)
		_check(placed and it.state == PickableItem.State.PLACED, "colocar #%d en su fila" % (i + 1))
		_check(room.placed_items == i + 1, "progreso %d/%d" % [i + 1, total])
	_check(_placed_events == total, "%d eventos item_placed" % total)
	_check(_collections == 9, "9 colecciones completadas antes de la última (%d)" % _collections)
	await _wait_until(func(): return _room_done, 3.0)
	_check(_room_done, "evento room_completed emitido")
	_check(room.is_completed, "sala marcada como completada")

	print("-- Sacar y recolocar un objeto ya colocado")
	var again: PickableItem = items[mini(3, items.size() - 1)]
	_check(await _pick(again), "recoger un ovillo ya colocado")
	_check(room.placed_items == total - 1, "el progreso baja en uno")
	_check(again.shelf == null and again.slot_row == -1, "el hueco de la estantería queda libre")
	_check(await _place_on_correct_row(again), "volver a colocarlo")
	_check(room.placed_items == total, "progreso otra vez %d/%d" % [total, total])

	print("-- Menú de pausa")
	var menu: CanvasLayer = main.get_node("PauseMenu")
	await _press(&"pause")
	await _frames(2)
	_check(get_tree().paused and menu.get_child(0).visible, "Esc abre el menú y pausa el juego")
	await _press(&"pause")
	await _frames(2)
	_check(not get_tree().paused and not menu.get_child(0).visible, "Esc otra vez reanuda")

	print("")
	if _failures == 0:
		print("RESULTADO: TODO CORRECTO")
	else:
		print("RESULTADO: %d FALLOS" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

extends Node
## Prueba de humo de extremo a extremo (sin ventana): arranca la escena principal y, con
## eventos de entrada reales, recoge, rechaza, deja, lanza, recoloca y ordena TODOS los objetos
## de TODAS las salas, comprobando que las puertas se abren al completar cada una.
## Ejecutar:  godot --headless --path . res://tests/smoke_test.tscn -- --test-mode [--count=N] [--rooms=K]
##   --count=N  cada tipo de objeto genera N unidades (por defecto 1; 0 = las del juego completo)
##   --rooms=K  prueba solo las K primeras salas
## Código de salida 0 = todo correcto.

var _failures := 0
var _rejected := 0
var _placed_events := 0
var _collections := 0
var _completed_rooms: Array = []
var _bounces := 0
var _throws := 0
var _landed := 0

var main: Node
var shop: Shop
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


func _stand_and_look_at_item(room: RoomController, item: PickableItem) -> bool:
	var p := item.global_position
	var base := Vector3(p.x, room.global_position.y, p.z)
	var toward := (room.global_position + Vector3(0, 0, 1.0) - base)
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else Vector3(0, 0, 1)
	var dirs: Array[Vector3] = [toward, Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0), (toward + Vector3(0, 0, 1)).normalized()]
	for dist: float in [0.9, 1.3, 0.6]:
		for d in dirs:
			player.teleport(base + d * dist)
			await _settle()
			player.look_at_point(p)
			await _frames(3)
			if holder.hover_item == item:
				return true
	print("    (diagnóstico) objeto %s en %s hover=%s jugador=%s" % [item.data.id, item.global_position, holder.hover_item, player.global_position])
	return false


func _stand_at_slot(unit: StorageUnit, row: int, slot: int, item: PickableItem) -> void:
	var hint := unit.stand_hint(row, slot, item)
	player.teleport(hint["position"])
	await _settle()
	player.look_at_point(hint["look"])
	await _frames(3)


func _pick(room: RoomController, item: PickableItem) -> bool:
	if not await _stand_and_look_at_item(room, item):
		return false
	await _press(&"interact")
	var ok := await _wait_until(func(): return holder.state == ItemHolder.State.HOLDING)
	if not (ok and holder.held == item):
		print("    (diagnóstico) tras E: estado=", holder.state, " sostenido=", holder.held, " item.state=", item.state, " hover=", holder.hover_item)
	return ok and holder.held == item


func _place_on_correct_row(room: RoomController, item: PickableItem) -> bool:
	var found := room.find_row(item.data.sort_key)
	var unit: StorageUnit = found["unit"]
	var row: int = found["row"]
	var slot := unit.first_free_slot(row)
	await _stand_at_slot(unit, row, slot, item)
	if holder.aim_status != StorageUnit.SlotStatus.OK:
		print("    (diagnóstico) apuntando a %s fila %d hueco %d: estado=%d" % [unit.name, row, slot, holder.aim_status])
		return false
	await _press(&"place")
	return await _wait_until(func(): return holder.state == ItemHolder.State.EMPTY)


func _run() -> void:
	print("== Thread by Thread · prueba de humo ==")
	var per_color := 1
	var max_rooms := 99
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			per_color = int(arg.trim_prefix("--count="))
		elif arg.begins_with("--rooms="):
			max_rooms = int(arg.trim_prefix("--rooms="))
	var packed := load("res://scenes/main.tscn") as PackedScene
	main = packed.instantiate()
	shop = main.get_node("Shop")
	for r in shop.get_children():
		if r is RoomController:
			(r as RoomController).count_override = per_color
	add_child(main)
	await _frames(10)
	player = main.get_node("Player")
	holder = player.get_node("ItemHolder")

	Events.item_rejected.connect(func(_i, _r): _rejected += 1)
	Events.item_placed.connect(func(_i, _s): _placed_events += 1)
	Events.collection_completed.connect(func(_k): _collections += 1)
	Events.room_completed.connect(func(room): _completed_rooms.append(room))
	Events.item_bounced.connect(func(_i, _s, _p, _snd): _bounces += 1)
	Events.item_thrown.connect(func(_i): _throws += 1)
	Events.item_landed.connect(func(_i): _landed += 1)

	await _wait_until(func(): return AudioManager.ready_to_play, 8.0)
	_check(AudioManager.ready_to_play, "sonidos cargados")
	print("        bancos con audio editado (art/audio/sfx): %d" % AudioManager.overridden.size())
	_check(shop.rooms.size() >= 1, "la mercería tiene %d sala(s)" % shop.rooms.size())
	_check(shop.rooms[0].is_unlocked and (shop.rooms.size() < 2 or not shop.rooms[1].is_unlocked), "solo la primera sala empieza desbloqueada")

	for room_i in mini(shop.rooms.size(), max_rooms):
		await _test_room(shop.rooms[room_i], room_i)

	print("-- Menú de pausa")
	var menu: CanvasLayer = main.get_node("PauseMenu")
	await _press(&"pause")
	await _frames(2)
	_check(get_tree().paused and menu.get_child(0).visible, "Esc abre el menú y pausa el juego")
	await _press(&"pause")
	await _frames(2)
	_check(not get_tree().paused and not menu.get_child(0).visible, "Esc otra vez reanuda")

	print("-- Guardado")
	_check(shop.save_game(), "guardar partida")
	var data := SaveGame.read()
	_check(not data.is_empty() and data.get("rooms", {}).size() == shop.rooms.size(), "el guardado se puede leer y contiene todas las salas")

	print("")
	if _failures == 0:
		print("RESULTADO: TODO CORRECTO")
	else:
		print("RESULTADO: %d FALLOS" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_room(room: RoomController, room_i: int) -> void:
	print("== Sala %d: %s ==" % [room_i + 1, room.display_name])
	player.teleport(room.entry_point())
	await _settle()
	await _frames(4)
	var items := room.get_items().duplicate()
	var expected := 0
	for data in room.catalog.items:
		expected += room.count_override if room.count_override > 0 else data.spawn_count
	var total := items.size()
	_check(total == expected and room.total_items == total, "la sala genera %d objetos (%d)" % [expected, total])
	_check(room.placed_items == 0, "progreso inicial 0/%d" % total)
	_check(shop.active_room == room, "el mercader detecta la sala activa")
	var keys := {}
	for it: PickableItem in items:
		keys[it.data.sort_key] = true
		if room.find_row(it.data.sort_key).is_empty():
			_check(false, "fila disponible para '%s'" % it.data.sort_key)
	_check(keys.size() == room.catalog.items.size(), "%d tipos distintos, todos con su hueco" % keys.size())
	var local_bounds_ok := true
	for it: PickableItem in items:
		var q := room.to_local(it.global_position)
		if absf(q.x) > 3.0 or absf(q.z) > 2.5 or q.y < 0.0 or q.y > 1.2:
			local_bounds_ok = false
			print("    fuera de la sala: ", it.data.id, " ", q)
	_check(local_bounds_ok, "todos los objetos nacen dentro de la sala")

	var first: PickableItem = items[0]
	var placed_before := _placed_events
	var collections_before := _collections

	if room_i == 0:
		print("-- Recoger y rechazo en fila equivocada")
		_check(await _pick(room, first), "recoger objeto con E (estado HOLDING)")
		_check(first.state == PickableItem.State.HELD, "el objeto queda en estado HELD")
		var wrong_key: StringName = first.data.sort_key
		for other: PickableItem in items:
			if other.data.sort_key != first.data.sort_key:
				wrong_key = other.data.sort_key
				break
		var wrong := room.find_row(wrong_key)
		var wunit: StorageUnit = wrong["unit"]
		await _stand_at_slot(wunit, wrong["row"], mini(7, wunit.slots_per_row - 1), first)
		_check(holder.aim_status == StorageUnit.SlotStatus.WRONG_ROW, "la puntería detecta fila equivocada")
		await _press(&"place")
		await _frames(4)
		_check(holder.state == ItemHolder.State.HOLDING, "sigue sostenido tras clic en fila equivocada")
		_check(_rejected == 1 and room.placed_items == 0, "evento de rechazo emitido y progreso intacto")

		print("-- Dejar sobre una superficie")
		player.teleport(room.global_position + Vector3(0.0, 0.0, 1.3))
		await _settle()
		player.look_at_point(room.global_position + Vector3(0.0, 0.0, 0.4))
		await _frames(3)
		await _press(&"set_down")
		_check(await _wait_until(func(): return first.state == PickableItem.State.LOOSE), "dejar en el suelo con clic derecho")
		_check(holder.state == ItemHolder.State.EMPTY, "las manos quedan libres")
		_check(absf(first.global_position.y - first.half_height - room.global_position.y) < 0.01, "el objeto reposa sobre el suelo")

		print("-- Lanzar: rebote y reposo")
		_check(await _pick(room, first), "recoger el objeto del suelo otra vez")
		player.teleport(room.global_position + Vector3(-1.0, 0.0, 1.5))
		await _settle()
		player.look_at_point(room.global_position + Vector3(-0.6, 0.6, -0.8))
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
		_check(first.state == PickableItem.State.LOOSE, "el objeto se detiene y vuelve a congelarse")
		_check(max_squash > 0.02, "el objeto se aplasta al rebotar (deformación máx. %.3f)" % max_squash)
		_check(_bounces >= 1, "hubo al menos un rebote (%d)" % _bounces)
		_check(_throws == 1 and _landed == 1, "eventos de lanzamiento y aterrizaje")
		var p := room.to_local(first.global_position)
		_check(absf(p.x) < 3.0 and absf(p.z) < 2.5 and p.y > -0.05 and p.y < 2.0, "queda dentro de la sala (%s)" % str(p.snapped(Vector3.ONE * 0.01)))
		_check(first.collision_layer == PickableItem.LAYER_ITEMS and first.freeze, "vuelve a ser recogible y está congelado")

	print("-- Ordenar los %d objetos" % total)
	var failed_items := 0
	for i in items.size():
		var it: PickableItem = items[i]
		var picked := await _pick(room, it)
		if not picked:
			failed_items += 1
			_check(false, "recoger #%d (%s)" % [i + 1, it.data.id])
			continue
		var placed := await _place_on_correct_row(room, it)
		if not (placed and it.state == PickableItem.State.PLACED and room.placed_items == i + 1):
			failed_items += 1
			_check(false, "colocar #%d (%s) en su sitio (progreso %d)" % [i + 1, it.data.id, room.placed_items])
	_check(failed_items == 0, "los %d objetos se recogieron y colocaron" % total)
	_check(_placed_events - placed_before == total, "%d eventos item_placed" % total)
	_check(_collections - collections_before == room.catalog.items.size() - 1, "%d colecciones completadas antes de la última (%d)" % [room.catalog.items.size() - 1, _collections - collections_before])
	await _wait_until(func(): return _completed_rooms.has(room), 3.0)
	_check(_completed_rooms.has(room) and room.is_completed, "sala completada")

	if room_i + 1 < shop.rooms.size():
		var next := shop.rooms[room_i + 1]
		await _wait_until(func(): return next.is_unlocked, 2.0)
		_check(next.is_unlocked, "la sala siguiente se desbloquea")
		var door := room.shell.east_door
		_check(door != null, "la sala tiene puerta al este")
		if door != null:
			await _wait_until(func(): return door.is_open and door._leaf.collision_layer == 0, 4.0)
			_check(door.is_open and door._leaf.collision_layer == 0, "la puerta se abre y deja de bloquear el paso")

	if room_i == 0:
		print("-- Sacar y recolocar un objeto ya colocado")
		var again: PickableItem = items[mini(3, items.size() - 1)]
		_check(await _pick(room, again), "recoger un objeto ya colocado")
		_check(room.placed_items == total - 1, "el progreso baja en uno")
		_check(again.container == null and again.slot_row == -1, "el hueco queda libre")
		_check(await _place_on_correct_row(room, again), "volver a colocarlo")
		_check(room.placed_items == total, "progreso otra vez %d/%d" % [total, total])

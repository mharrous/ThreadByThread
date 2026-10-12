extends Node
## Prueba de humo de extremo a extremo (sin ventana): arranca la escena principal y, con
## eventos de entrada reales, recoge, rechaza, deja, lanza, recoloca y ordena TODOS los objetos
## de TODAS las salas, comprobando que las puertas se abren al completar cada una.
## Ejecutar:  godot --headless --path . res://tests/smoke_test.tscn -- --test-mode [--count=N] [--rooms=K] [--from=J]
##   --count=N  cada tipo de objeto genera N unidades (por defecto 1; 0 = las del juego completo)
##   --rooms=K  prueba solo las K primeras salas
##   --from=J   empieza en la sala J (0 = la primera); con --rooms=K prueba las salas J..K-1
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


func _stand_and_look_at_item(room: RoomController, item: PickableItem, attempt: int = 0) -> bool:
	var p := item.global_position
	var base := Vector3(p.x, room.global_position.y, p.z)
	var toward := (room.global_position + Vector3(0, 0, 1.0) - base)
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else Vector3(0, 0, 1)
	var dirs: Array[Vector3] = [toward, Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0), (toward + Vector3(0, 0, 1)).normalized()]
	var dists: Array[float] = [0.9, 1.3, 0.6]
	if attempt % 2 == 1:
		dists.reverse()
	for dist: float in dists:
		for d in dirs:
			# No se intenta de pie dentro de un mueble: la colisión empujaría al jugador y perdería el objeto de vista.
			var spot := room.to_local(base + d * dist)
			if room.shell.is_blocked(Vector2(spot.x, spot.z), 0.0):
				continue
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
	# Hasta tres intentos desde sitios distintos (el harness, no el juego, puede perder el objeto de vista).
	for attempt in 3:
		if not await _stand_and_look_at_item(room, item, attempt):
			continue
		await _press(&"interact")
		var ok := await _wait_until(func(): return holder.state == ItemHolder.State.HOLDING, 2.5)
		if ok and holder.held == item:
			return true
		print("    (diagnóstico) intento %d tras E: objeto=%s en %s jugador=%s estado=%d sostenido=%s item.state=%d hover=%s" % [attempt + 1, item.data.id, item.global_position.snapped(Vector3.ONE * 0.01), player.global_position.snapped(Vector3.ONE * 0.01), holder.state, holder.held, item.state, holder.hover_item])
		if holder.state != ItemHolder.State.EMPTY:
			return false
	return false

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
	var first_room := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			per_color = int(arg.trim_prefix("--count="))
		elif arg.begins_with("--rooms="):
			max_rooms = int(arg.trim_prefix("--rooms="))
		elif arg.begins_with("--from="):
			first_room = int(arg.trim_prefix("--from="))
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

	for room_i in range(first_room, mini(shop.rooms.size(), max_rooms)):
		await _test_room(shop.rooms[room_i], room_i)

	print("-- Calle")
	await _test_street()

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


## Cada tipo de suceso de la calle se crea, avanza, anima sus ruedas o miembros y lleva su sonido.
func _test_street() -> void:
	var landscape := main.get_node("World/Landscape") as Landscape
	var life := landscape.get_street_life()
	_check(life != null, "el paisaje tiene su StreetLife")
	if life == null:
		return
	life.enabled = false
	for stray in life._actors.duplicate():
		stray.queue_free()
	life._actors.clear()
	for kind: StringName in [&"car", &"van", &"bike", &"moto", &"walker", &"dogwalker"]:
		var actor := life.spawn(kind)
		var z0 := actor.position.z
		var moved := await _wait_until(func(): return is_instance_valid(actor) and absf(actor.position.z - z0) > 0.05, 4.0)
		_check(moved, "'%s' avanza por la calle" % kind)
		if kind in [&"car", &"van", &"bike", &"moto"]:
			_check(actor.wheels.size() == (2 if kind in [&"bike", &"moto"] else 4), "'%s' tiene sus ruedas (%d)" % [kind, actor.wheels.size()])
			_check(absf(actor.wheels[0].rotation.x) > 0.001, "las ruedas de '%s' giran" % kind)
			_check(actor.engine != null and actor.engine.stream != null, "'%s' lleva su sonido de motor/rodadura" % kind)
		else:
			_check(actor.legs.size() == 2 and absf(actor.legs[0].rotation.x) > 0.001, "'%s' mueve las piernas" % kind)
		if kind == &"dogwalker":
			_check(actor.dog_legs.size() == 4 and absf(actor.dog_legs[0].rotation.x) > 0.001, "el perro mueve las patas")
		actor.queue_free()
		life._actors.erase(actor)
	_check(life._actors.is_empty(), "la calle queda vacía tras retirar los sucesos de prueba")


## Tesoros escondidos: cada uno tiene un apoyo bajo él, se puede apuntar y recoger, no cuenta
## para ordenar la sala, se expone en la repisa y queda guardado en el estado de la sala.
func _test_treasures(room: RoomController) -> void:
	print("-- Tesoros escondidos")
	var total := room.treasures_total()
	_check(total == 2, "la sala esconde %d tesoros" % total)
	var spots: Array = room._treasures.duplicate()
	_check(spots.size() == total, "todos los tesoros están en su sitio sin recoger")
	for t: PickableItem in spots:
		var space := room.get_world_3d().direct_space_state
		var from := t.global_position + Vector3(0, 0.1, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -0.4, 0), 1 | 16)
		var hit := space.intersect_ray(q)
		_check(not hit.is_empty() and from.y - hit["position"].y < t.half_height + 0.1 + 0.03, "'%s' reposa sobre un apoyo (a %.3f m)" % [t.data.id, (from.y - hit["position"].y) if not hit.is_empty() else -1.0])
	var total_before := room.total_items
	var seen: Array = []
	var handler := func(item): seen.append(item)
	Events.treasure_found.connect(handler)
	for i in spots.size():
		var t: PickableItem = spots[i]
		var tdata := t.data
		var tid := t.get_instance_id()
		var ok := await _stand_and_look_at_item(room, t)
		_check(ok, "se puede apuntar al tesoro '%s'" % tdata.id)
		if not ok:
			continue
		await _press(&"interact")
		await _wait_until(func(): return room.treasures_found() == i + 1, 2.0)
		_check(room.treasures_found() == i + 1, "recoger '%s' lo cuenta como hallado (%d/%d)" % [tdata.id, room.treasures_found(), total])
		_check(holder.state == ItemHolder.State.EMPTY, "las manos siguen libres tras coger un tesoro")
		await _wait_until(func(): return not is_instance_valid(instance_from_id(tid)), 4.0)
		_check(not is_instance_valid(instance_from_id(tid)), "el tesoro desaparece tras enseñarlo")
	Events.treasure_found.disconnect(handler)
	_check(seen.size() == spots.size(), "evento treasure_found emitido %d veces" % seen.size())
	_check(room.total_items == total_before and room.placed_items == 0, "los tesoros no cuentan para ordenar la sala")
	await _wait_until(func(): return room._displays.size() == total, 4.0)
	_check(room._displays.size() == total, "los tesoros hallados se exponen en la repisa")
	var st := room.capture_state()
	_check((st["treasures"] as Array).size() == total, "el estado de la sala guarda los tesoros hallados")


## Deja el objeto sostenido en algún punto libre del suelo (con las cantidades del juego completo el
## suelo está lleno de objetos y un punto fijo puede estar ocupado: se prueban varios).
func _set_down_somewhere_free(room: RoomController, item: PickableItem) -> bool:
	var candidates: Array[Vector2] = []
	for gz in [0.4, 1.0, -0.4, 1.5]:
		for gx in [0.0, -1.0, 1.0, -1.8, 1.8, -0.5, 0.5]:
			if room.shell.floor_bounds.has_point(Vector2(gx, gz)) and not room.shell.is_blocked(Vector2(gx, gz), 0.35):
				candidates.append(Vector2(gx, gz))
	for c in candidates:
		player.teleport(room.global_position + Vector3(c.x, 0.0, c.y + 0.9))
		await _settle()
		player.look_at_point(room.global_position + Vector3(c.x, 0.0, c.y))
		await _frames(3)
		await _press(&"set_down")
		if await _wait_until(func(): return item.state == PickableItem.State.LOOSE, 1.2):
			return true
	return false

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
	await _test_treasures(room)
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
		_check(await _set_down_somewhere_free(room, first), "dejar en el suelo con clic derecho")
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
	await _wait_until(func(): return room.shell.is_decor_unlocked(&"bunting"), 4.0)
	_check(room.shell.is_decor_unlocked(&"bunting"), "la guirnalda de banderines se desbloquea al completar la sala")

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

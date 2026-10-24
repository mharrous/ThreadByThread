extends Node
## Prueba de humo de extremo a extremo (sin ventana): arranca la escena principal y, con
## eventos de entrada reales, recoge, rechaza, deja, lanza, recoloca y ordena TODOS los objetos
## de la mercería, sección a sección, comprobando los premios de cada sección y el final.
## Ejecutar:  godot --headless --path . res://tests/smoke_test.tscn -- --test-mode [--count=N] [--sections=K]
##   --count=N     cada tipo de objeto genera N unidades (por defecto 1; 0 = las del juego completo)
##   --sections=K  ordena a mano solo las K primeras secciones; el resto se completa con el atajo
## Código de salida 0 = todo correcto.

var _failures := 0
var _rejected := 0
var _placed_events := 0
var _collections := 0
var _completed_rooms: Array = []
var _completed_sections: Array = []
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


func _press(action: StringName, hold_frames: int = 1) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in hold_frames:
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
		# En un montón denso el harness puede coger el vecino (el jugador se recoloca entre fotogramas al
		# chocar con los objetos). Ese objeto se lleva a su sitio, como haría un jugador, y se reintenta.
		if holder.state == ItemHolder.State.HOLDING and holder.held != null and holder.held != item:
			var other := holder.held
			if not await _place_on_correct_row(room, other):
				return false
			print("    (diagnóstico) se colocó antes '%s' (cogido por error)" % other.data.id)
		elif holder.state != ItemHolder.State.EMPTY:
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
	var max_sections := 99
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			per_color = int(arg.trim_prefix("--count="))
		elif arg.begins_with("--sections="):
			max_sections = int(arg.trim_prefix("--sections="))
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
	Events.section_completed.connect(func(section): _completed_sections.append(section))
	Events.item_bounced.connect(func(_i, _s, _p, _snd): _bounces += 1)
	Events.item_thrown.connect(func(_i): _throws += 1)
	Events.item_landed.connect(func(_i): _landed += 1)

	await _wait_until(func(): return AudioManager.ready_to_play, 8.0)
	_check(AudioManager.ready_to_play, "sonidos cargados")
	var layers_ok := AudioManager._music.size() == 3
	for mp in AudioManager._music:
		layers_ok = layers_ok and mp.stream != null and mp.playing
	_check(layers_ok, "las 3 capas de música suenan a la vez")
	_check(AudioManager._banks.has(&"shop_bell") and AudioManager._banks.has(&"sparkle"), "campanilla de la puerta y destello de racha disponibles")
	print("        bancos con audio editado (art/audio/sfx): %d" % AudioManager.overridden.size())
	_check(shop.room != null, "la mercería tiene su sala")
	_check(shop.room.sections.size() == 4, "la sala tiene %d secciones" % shop.room.sections.size())

	await _test_room(shop.room, max_sections)

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
	_check(not data.is_empty() and data.get("room", {}).get("items", []).size() == shop.room.total_items, "el guardado se puede leer y contiene todos los objetos")

	print("-- Atajo de pruebas")
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	_check((main.get_node("ShopOpening") as ShopOpening).playing, "con --test-mode, T lanza la escena de apertura")

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
	_check(total == 8, "la mercería esconde %d tesoros" % total)
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
		if t.global_position.y - room.global_position.y > 1.0:
			# Tesoro alto (encima de una estantería): debe poder apuntarse de pie a una distancia normal,
			# desde el lado de la sala.
			var inward := room.global_position - t.global_position
			inward.y = 0.0
			inward = inward.normalized()
			player.teleport(Vector3(t.global_position.x, room.global_position.y, t.global_position.z) + inward * 1.8)
			await _settle()
			player.look_at_point(t.global_position)
			await _frames(3)
			_check(holder.hover_item == t, "el tesoro alto '%s' se apunta desde 1,8 m (aparece la acción de recoger)" % tdata.id)
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
	var book_found := 0
	for section in room.sections:
		book_found += section.treasures_found()
	_check(book_found == total, "cada sección cuenta sus tesoros hallados (%d)" % book_found)


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

## Lanzar a máxima fuerza desde pegado a las paredes, esquinas y la ventana: ningún objeto debe atravesar
## el muro y salir del edificio (se encontró con la prueba de "mono": la mano pegada a una esquina
## sacaba el objeto por fuera de la pared).
func _test_wall_throws(room: RoomController, items: Array) -> void:
	print("-- Lanzar contra paredes, esquinas y ventana")
	var hw := room.shell.room_w * 0.5
	var hd := room.shell.room_d * 0.5
	var cases: Array = [
		["pared sur", Vector3(3.8, 0, hd - 0.4), Vector3(3.8, 1.0, hd + 0.2)],
		["ventana sur", Vector3(2.4, 0, hd - 0.5), Vector3(2.4, 1.5, hd + 0.3)],
		["pared oeste", Vector3(-hw + 0.45, 0, -1.5), Vector3(-hw - 0.1, 1.0, -1.5)],
		["ventana oeste", Vector3(-hw + 0.5, 0, 0.0), Vector3(-hw - 0.3, 1.3, 0.0)],
		["pared este", Vector3(hw - 0.45, 0, 2.2), Vector3(hw + 0.1, 1.0, 2.2)],
		["esquina norte (planta)", Vector3(-0.45, 0, -hd + 1.0), Vector3(-0.1, 0.9, -hd - 0.2)],
		["suelo pegado a la pared", Vector3(3.8, 0, hd - 0.35), Vector3(3.8, 0.1, hd + 0.2)],
	]
	var next_item := 2
	for c in cases:
		var item: PickableItem = items[next_item % items.size()]
		next_item += 1
		if not await _pick(room, item):
			_check(false, "preparar el lanzamiento (%s)" % c[0])
			continue
		player.teleport(room.global_position + c[1])
		await _settle()
		player.look_at_point(room.global_position + c[2])
		await _frames(3)
		await _press(&"throw", 60)
		var flew := await _wait_until(func(): return item.state == PickableItem.State.THROWN or item.state == PickableItem.State.LOOSE, 2.0)
		_check(flew, "el lanzamiento contra '%s' sale de la mano" % c[0])
		await _wait_until(func(): return item.state != PickableItem.State.THROWN, 14.0)
		var local := room.to_local(item.global_position)
		var inside := absf(local.x) <= hw + 0.1 and absf(local.z) <= hd + 0.05 and local.y > -0.05 and local.y < room.shell.room_h
		_check(inside, "lanzado contra '%s' sigue dentro de la sala (%s)" % [c[0], str(local.snapped(Vector3.ONE * 0.01))])
		# Si se escapó, o rodó debajo de un mueble (un jugador se agacharía; el harness no), se devuelve
		# a un hueco del suelo para no contaminar el resto de la prueba.
		if not inside or (local.y < 0.5 and room.shell.is_blocked(Vector2(local.x, local.z), 0.0)):
			item.global_position = room.to_global(Vector3(-2.0 + 0.45 * next_item, item.half_height, 3.3))


## Un objeto que cae en el hueco entre una estantería y la pared no se puede coger: se saca delante.
func _test_stuck_rescue(room: RoomController, items: Array) -> void:
	print("-- Objeto colado detrás de un mueble")
	var item: PickableItem
	for it: PickableItem in items:
		if it.state == PickableItem.State.LOOSE:
			item = it
			break
	var unit: ShelfUnit
	for u in room.get_units():
		if u is ShelfUnit:
			unit = u
			break
	if item == null or unit == null:
		_check(false, "preparar el objeto colado")
		return
	item.global_position = unit.to_global(Vector3(0.3, item.half_height, -0.03))
	Events.item_landed.emit(item)
	await get_tree().create_timer(0.8).timeout
	var local := unit.to_local(item.global_position)
	_check(local.z > unit.depth and item.state == PickableItem.State.LOOSE and item.is_pickable(),
		"sale delante de la estantería y se puede coger (z=%.2f)" % local.z)
	# Metido en el grueso de la pared sur (lo que dejó un lanzamiento contra el rodapié).
	var hd := room.shell.room_d * 0.5
	item.global_position = room.to_global(Vector3(3.7, -0.009, hd + 0.03))
	Events.item_landed.emit(item)
	await get_tree().create_timer(0.8).timeout
	var in_room := room.to_local(item.global_position)
	_check(in_room.z < hd - item.radius and item.is_pickable(), "un objeto metido en la pared vuelve dentro (z=%.2f)" % in_room.z)
	# Detrás de la planta de la pared norte, entre la maceta y la pared (no se ve desde la sala).
	item.global_position = room.to_global(Vector3(0.05, item.half_height, -4.4))
	Events.item_landed.emit(item)
	await _wait_until(func(): return item.state == PickableItem.State.LOOSE and item.is_pickable(), 3.0)
	var behind := room.to_local(item.global_position)
	_check(room.shell.floor_bounds.has_point(Vector2(behind.x, behind.z)) and item.is_pickable(), "un objeto escondido detrás de la planta sale al suelo libre (z=%.2f)" % behind.z)


## Un objeto que cae dentro de la estantería de su tipo entra solo en un hueco (canasta); en la de otro
## tipo se queda suelto.
func _test_basket(room: RoomController, items: Array) -> void:
	print("-- Canasta: lanzar a la estantería")
	var it: PickableItem = null
	var other: PickableItem = null
	for c: PickableItem in items:
		if c.state != PickableItem.State.LOOSE or room.find_row(c.data.sort_key).is_empty():
			continue
		if it == null:
			it = c
		elif other == null and room.find_row(c.data.sort_key)["unit"] != room.find_row(it.data.sort_key)["unit"]:
			other = c
	if it == null or other == null:
		_check(false, "hay objetos para la canasta")
		return
	var found := room.find_row(it.data.sort_key)
	var unit: StorageUnit = found["unit"]
	var target := unit.slot_world_position(found["row"], unit.first_free_slot(found["row"]), it)
	var before := room.placed_items
	it.global_position = target + Vector3.UP * 0.05
	it.launch(Vector3.ZERO, Vector3.ZERO)
	var ok := await _wait_until(func(): return it.state == PickableItem.State.PLACED, 4.0)
	_check(ok and it.container == unit and room.placed_items == before + 1, "un objeto que cae en su estantería entra en un hueco (%s)" % it.data.id)
	other.global_position = target + Vector3.UP * 0.05
	other.launch(Vector3.ZERO, Vector3.ZERO)
	await _wait_until(func(): return other.state != PickableItem.State.THROWN, 4.0)
	await _frames(25)
	_check(other.state == PickableItem.State.LOOSE and room.placed_items == before + 1, "en la estantería de otro tipo se queda suelto (%s)" % other.data.id)
	other.global_position = room.to_global(Vector3(-1.0, other.half_height, 3.3))


## Con un objeto en la mano y su estantería a la espalda sale la flecha del borde; mirándola, se apaga.
func _test_pointer(room: RoomController, items: Array) -> void:
	print("-- Flecha hacia la estantería")
	var hud := main.get_node("HUD")
	var it: PickableItem = null
	for c: PickableItem in items:
		if c.state == PickableItem.State.LOOSE and not room.find_row(c.data.sort_key).is_empty():
			it = c
			break
	var home := it.global_transform if it != null else Transform3D()
	if it == null or not await _pick(room, it):
		_check(false, "coger un objeto para la flecha")
		return
	var found := room.find_row(it.data.sort_key)
	var unit: StorageUnit = found["unit"]
	var shelf := unit.slot_world_position(found["row"], 0, it)
	var eye := player.global_position
	player.look_at_point(eye + (eye - shelf) * Vector3(1, 0, 1))
	await get_tree().create_timer(TargetPointer.DELAY + 0.8).timeout
	_check(hud._pointer._alpha > 0.5, "con la estantería a la espalda sale la flecha (%.2f)" % hud._pointer._alpha)
	player.look_at_point(shelf)
	await get_tree().create_timer(0.6).timeout
	_check(hud._pointer._alpha < 0.05, "mirando a la estantería la flecha se apaga (%.2f)" % hud._pointer._alpha)
	holder.release_held()
	it.global_transform = home
	await _frames(5)


## En un montón (telas dobladas apiladas) solo se puede coger la de arriba: si se apunta a la de abajo,
## el juego coge la de arriba y las demás no quedan flotando.
func _test_stacks(room: RoomController) -> void:
	for unit in room.get_units():
		if unit.stack_capacity <= 1:
			continue
		for row in unit.rows:
			for slot in unit.slots_per_row:
				if unit.stack_size(row, slot) < 2:
					continue
				var stack: Array = unit._slots[row][slot]
				var bottom: PickableItem = stack[0]
				var top: PickableItem = stack.back()
				var before := stack.size()
				print("-- Montón de %d en %s (fila %d, hueco %d)" % [stack.size(), unit.name, row, slot])
				# Se fuerza el objeto apuntado (el rayo normal acertaria antes en el de arriba) y se pulsa coger.
				player.teleport(unit.stand_hint(row, slot, top)["position"])
				await _settle()
				holder.hover_item = bottom
				holder.try_pick()
				var ok := await _wait_until(func(): return holder.state == ItemHolder.State.HOLDING, 3.0)
				_check(ok and holder.held == top, "apuntando a la pieza de abajo se coge la de arriba del montón")
				_check(unit.stack_size(row, slot) == before - 1, "el montón conserva el resto (%d piezas)" % unit.stack_size(row, slot))
				# Se devuelve a su sitio para dejar la sala como estaba.
				if holder.state == ItemHolder.State.HOLDING:
					_check(await _place_on_correct_row(room, holder.held), "la pieza vuelve al montón")
				return


func _test_room(room: RoomController, max_sections: int) -> void:
	print("== %s ==" % room.display_name)
	player.teleport(room.entry_point())
	await _settle()
	await _frames(4)
	var items := room.get_items().duplicate()
	var expected := 0
	var types := 0
	for section in room.sections:
		var section_expected := 0
		for data in section.catalog.items:
			section_expected += room._count_for(data)
			types += 1
		_check(section.total_items == section_expected and section.placed_items == 0, "la sección %s espera %d objetos" % [section.display_name, section_expected])
		expected += section_expected
	var total := items.size()
	_check(total == expected and room.total_items == total, "la mercería genera %d objetos (%d)" % [expected, total])
	_check(room.placed_items == 0, "progreso inicial 0/%d" % total)
	var keys := {}
	for it: PickableItem in items:
		keys[it.data.sort_key] = true
		if room.find_row(it.data.sort_key).is_empty():
			_check(false, "fila disponible para '%s'" % it.data.sort_key)
		if room.section_for_key(it.data.sort_key) == null:
			_check(false, "sección para '%s'" % it.data.sort_key)
	_check(keys.size() == types, "%d tipos distintos, todos con su hueco" % keys.size())
	await _test_treasures(room)
	var hw := room.shell.room_w * 0.5
	var hd := room.shell.room_d * 0.5
	var local_bounds_ok := true
	for it: PickableItem in items:
		var q := room.to_local(it.global_position)
		if absf(q.x) > hw or absf(q.z) > hd or q.y < 0.0 or q.y > 1.2:
			local_bounds_ok = false
			print("    fuera de la sala: ", it.data.id, " ", q)
	_check(local_bounds_ok, "todos los objetos nacen dentro de la sala")

	# Un objeto blando (lana) para las pruebas de rebote: el aplastamiento depende del material.
	var first: PickableItem = items[0]
	for it: PickableItem in items:
		if it.data.get_motion().squash >= 1.0:
			first = it
			break
	var placed_before := _placed_events
	var collections_before := _collections

	print("-- Recoger y rechazo en fila equivocada")
	_check(await _pick(room, first), "recoger objeto con E (estado HOLDING)")
	_check(first.state == PickableItem.State.HELD, "el objeto queda en estado HELD")
	var hud := main.get_node("HUD")
	await _frames(2)
	var first_section := room.section_for_key(first.data.sort_key)
	_check(hud._section_label.visible and hud._section_label.text.contains(first_section.display_name), "el HUD dice a qué sección va (" + hud._section_label.text + ")")
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
	await _frames(2)
	_check(not hud._section_label.visible, "sin nada en la mano el HUD no muestra sección")
	_check(absf(first.global_position.y - first.half_height - room.global_position.y) < 0.01, "el objeto reposa sobre el suelo")

	print("-- Lanzar: rebote y reposo")
	_check(await _pick(room, first), "recoger el objeto del suelo otra vez")
	# Guardar con un objeto en la mano no lo deja flotando: se guarda apoyado en lo que haya debajo.
	var saved_items: Array = room.capture_state()["items"]
	var saved_y := float((saved_items[items.find(first)]["p"] as Array)[1])
	_check(saved_y < 0.9 and saved_y > -0.05, "un objeto sostenido se guarda apoyado en el suelo (y=%.2f)" % saved_y)
	player.teleport(room.global_position + Vector3(-1.0, 0.0, 2.6))
	await _settle()
	player.look_at_point(room.global_position + Vector3(-0.6, 0.6, 0.4))
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
		var sc := squash_node.transform.basis.get_scale()
		max_squash = maxf(max_squash, maxf(absf(sc.x - 1.0), maxf(absf(sc.y - 1.0), absf(sc.z - 1.0))))
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(first.state == PickableItem.State.LOOSE, "el objeto se detiene y vuelve a congelarse")
	_check(max_squash > 0.02, "el objeto se aplasta al rebotar (deformación máx. %.3f)" % max_squash)
	_check(_bounces >= 1, "hubo al menos un rebote (%d)" % _bounces)
	_check(_throws == 1 and _landed == 1, "eventos de lanzamiento y aterrizaje")
	var p := room.to_local(first.global_position)
	_check(absf(p.x) < hw and absf(p.z) < hd and p.y > -0.05 and p.y < 2.0, "queda dentro de la sala (%s)" % str(p.snapped(Vector3.ONE * 0.01)))
	_check(first.collision_layer == PickableItem.LAYER_ITEMS and first.freeze, "vuelve a ser recogible y está congelado")

	await _test_wall_throws(room, items)
	await _test_stuck_rescue(room, items)
	await _test_basket(room, items)
	await _test_pointer(room, items)

	var failed_items := 0
	var done := 0
	for si in room.sections.size():
		var section := room.sections[si]
		if si >= max_sections:
			print("-- %s: completada con el atajo" % section.display_name)
			room.solve_instantly(section)
			done += section.total_items
			continue
		var section_items: Array = []
		for it: PickableItem in items:
			if room.section_for_key(it.data.sort_key) == section:
				section_items.append(it)
		print("-- %s: ordenar %d objetos" % [section.display_name, section_items.size()])
		for i in section_items.size():
			var it: PickableItem = section_items[i]
			# Ya colocado si el harness lo cogió por error antes (ver _pick).
			if it.state == PickableItem.State.PLACED:
				continue
			var picked := await _pick(room, it)
			if not picked:
				failed_items += 1
				_check(false, "recoger #%d (%s)" % [i + 1, it.data.id])
				if holder.state != ItemHolder.State.EMPTY:
					holder.release_held()
				continue
			var before := room.placed_items
			var placed := await _place_on_correct_row(room, it)
			if not (placed and it.state == PickableItem.State.PLACED and room.placed_items == before + 1):
				failed_items += 1
				_check(false, "colocar #%d (%s) en su sitio (progreso %d)" % [i + 1, it.data.id, room.placed_items])
			elif i == 0:
				await _check_next_hint(room, it)
		done = room.placed_items
		await _wait_until(func(): return _completed_sections.has(section), 2.0)
		_check(_completed_sections.has(section) and section.is_completed, "sección %s completada" % section.display_name)
		await _wait_until(func(): return section.is_bunting_visible(), 3.0)
		_check(section.is_bunting_visible(), "la guirnalda de la sección %s aparece" % section.display_name)
		await _wait_until(func(): return room.shell.is_decor_unlocked(section.section_id), 3.0)
		_check(room.shell.is_decor_unlocked(section.section_id), "aparece el premio de la sección %s" % section.display_name)
	_check(failed_items == 0, "los %d objetos ordenados a mano se recogieron y colocaron" % (done - _skipped(room, max_sections)))
	_check(_placed_events - placed_before == total, "%d eventos item_placed" % total)
	var expected_collections := types - room.sections.size()
	_check(_collections - collections_before == expected_collections, "%d colecciones completadas sin contar las que cierran sección (%d)" % [expected_collections, _collections - collections_before])
	_check(_completed_sections.size() == room.sections.size(), "las %d secciones se completan una vez cada una" % _completed_sections.size())
	await _wait_until(func(): return _completed_rooms.has(room), 4.0)
	_check(_completed_rooms.has(room) and room.is_completed, "mercería completada")
	await _frames(2)
	_check(hud._count_label.text == "Organizados  %d / %d" % [total, total], "el HUD muestra el progreso total (" + hud._count_label.text + ")")
	await _test_opening(room, hud)
	await _test_cat(room)
	await _test_stacks(room)
	await _wait_until(func(): return room.shell.is_decor_unlocked(&"bunting") and room.shell.is_decor_unlocked(&"open_sign"), 5.0)
	_check(room.shell.is_decor_unlocked(&"bunting"), "las guirnaldas de pared a pared aparecen al terminar")
	_check(room.shell.is_decor_unlocked(&"open_sign"), "el cartel de ABIERTO aparece al terminar")

	print("-- Sacar y recolocar un objeto ya colocado")
	var again: PickableItem = items[mini(3, items.size() - 1)]
	_check(await _pick(room, again), "recoger un objeto ya colocado")
	_check(room.placed_items == total - 1, "el progreso baja en uno")
	_check(again.container == null and again.slot_row == -1, "el hueco queda libre")
	_check(await _place_on_correct_row(room, again), "volver a colocarlo")
	_check(room.placed_items == total, "progreso otra vez %d/%d" % [total, total])


## La escena de apertura al ordenarlo todo: música, puerta, cliente, luces, cartel, confeti, letrero,
## pantalla final, guardado y vuelta al juego con "Seguir explorando".
func _test_opening(room: RoomController, hud: Node) -> void:
	print("-- Apertura de la tienda")
	var opening := main.get_node("ShopOpening") as ShopOpening
	var shell := room.shell
	_check(shell.door_sign.text == "CERRADO", "antes de la apertura la puerta dice CERRADO")
	# Todo colocado pero con papelitos en el suelo: todavía no abre; el objetivo pasa a barrer.
	await get_tree().create_timer(4.5).timeout
	_check(not opening.playing, "con el suelo sin barrer la tienda no abre")
	_check(hud._objective.text == hud.OBJECTIVE_SWEEP, "el objetivo pasa a barrer el suelo (%s)" % hud._objective.text)
	await _test_sweep(room, hud)
	_check(await _wait_until(func(): return opening.playing, 8.0), "con el suelo barrido empieza la escena de apertura")
	_check(not holder.sweeper.active, "la escoba vuelve a la pared al empezar la escena")
	_check(player.input_locked, "el jugador no se mueve ni coge nada durante la escena")
	await _wait_until(func(): return hud.is_cinematic(), 2.0)
	_check(hud.is_cinematic(), "la interfaz de juego se apaga")
	_check(not hud._streak_label.visible, "la racha no se ve durante la escena")
	_check(await _wait_until(func(): return opening.step == &"door", 8.0), "suenan las campanadas y se abre la puerta")
	_check(AudioManager.is_music_silent(), "la música está en silencio antes de abrir")
	var max_open := 0.0
	var saw_visitor := false
	var visitor_inside := false
	var saw_card := false
	var saw_confetti := false
	var anims := {}
	var t := 0.0
	while not opening.is_end_screen_open() and t < 45.0:
		max_open = maxf(max_open, shell.door_open_amount())
		var v := room.get_node_or_null("FirstCustomer") as Customer
		if v != null:
			saw_visitor = true
			visitor_inside = visitor_inside or v.position.x < 2.0
			anims[v.current_animation()] = true
		if hud._title_card != null and hud._title_card.modulate.a > 0.9:
			saw_card = saw_card or hud._title_card.text == ShopOpening.OPEN_TEXT
		saw_confetti = saw_confetti or room.get_node_or_null("OpeningConfetti") != null
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(max_open > deg_to_rad(80.0), "la puerta se abre (%.0f°)" % rad_to_deg(max_open))
	_check(saw_visitor and visitor_inside, "entra la clienta y llega al centro de la tienda")
	_check(anims.has(&"walk") and anims.has(&"look_around"), "la clienta anda y mira a su alrededor (%s)" % ", ".join(anims.keys()))
	_check(shell.door_sign.text == "ABIERTO", "el cartel de la puerta pasa a ABIERTO")
	_check(shell.lamps[0].light_energy >= shell.lamp_energy * 1.19, "las luces suben un 20 %% (%.2f)" % shell.lamps[0].light_energy)
	_check(saw_confetti, "cae confeti del techo")
	_check(saw_card, "letrero grande: «%s»" % ShopOpening.OPEN_TEXT)
	_check(opening.is_end_screen_open(), "fundido a negro y pantalla final (%.1f s)" % t)
	_check(shell.door_open_amount() < 0.05, "la puerta se cierra tras el cliente")
	_check(room.get_node_or_null("FirstCustomer") == null, "el cliente se ha ido")
	_check(shop.shop_opened and bool(SaveGame.read().get("shop_opened", false)), "se guarda shop_opened")
	await _wait_until(func(): return not AudioManager.is_music_silent(), 4.0)
	_check(not AudioManager.is_music_silent(), "la música vuelve")
	opening._end._on_continue()
	_check(await _wait_until(func(): return not opening.playing, 4.0), "«Seguir explorando» vuelve a la tienda")
	_check(not player.input_locked, "el jugador se puede mover otra vez")
	await _wait_until(func(): return not hud.is_cinematic(), 3.0)
	_check(not hud.is_cinematic(), "vuelve la interfaz de juego")
	# Con la apertura ya vista, al cargar no se repite.
	var saved := SaveGame.read()
	_check(bool(saved.get("shop_opened", false)) and bool(saved.get("room", {}).get("completed", false)), "el guardado tiene la tienda ordenada y abierta")
	opening._resume_pending()
	await _frames(4)
	await get_tree().create_timer(2.0).timeout
	_check(not opening.playing, "al cargar no se repite la escena")


## El gato de la tienda: anda por suelo libre, persigue el ovillo (de la tienda) y le da zarpazos, sacude
## las orejas y se deja acariciar con E.
func _test_cat(room: RoomController) -> void:
	print("-- Gato")
	var shell := room.shell
	var cat := shell.get_node_or_null("ShopCat") as ShopCat
	_check(cat != null, "hay un gato en la tienda")
	if cat == null:
		return
	var yarn := shell.get_node_or_null("CatYarn") as Node3D
	_check(yarn != null, "tiene un ovillo para jugar")
	if yarn == null:
		return
	var meshes := yarn.find_children("*", "MeshInstance3D", true, false)
	_check(not meshes.is_empty() and (meshes[0] as MeshInstance3D).material_override == (load(ShopCat.YARN_ITEM) as ItemData).get_material(), "el ovillo es uno de la tienda (su modelo y su lana)")
	var skel := cat.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skel != null and skel.find_bone("leg_fr") >= 0 and skel.find_bone("tail_3") >= 0, "tiene esqueleto con patas y cola")
	if skel == null:
		return
	cat._set_animating(true)
	# Pasea: se le manda a un punto libre y se mira que nunca pise un mueble.
	cat._gen += 1
	var gen := cat._gen
	var to := cat._free_point(1.5, 3.0)
	_check(to != Vector3.INF, "encuentra un sitio libre al que ir (desde %s)" % cat.position)
	if to == Vector3.INF:
		return
	var start := cat.position
	var on_furniture := 0
	var saw_walk := false
	cat._go_route(to, ShopCat.WALK_SPEED, &"walk", gen)
	var t := 0.0
	await _frames(1)
	while cat._move_to != Vector3.INF and t < 16.0:
		if shell.is_blocked(Vector2(cat.position.x, cat.position.z), 0.0):
			on_furniture += 1
		saw_walk = saw_walk or cat.current_pose() == &"walk"
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(cat.position.distance_to(start) > 1.0, "anda por la sala (%.2f m)" % cat.position.distance_to(start))
	_check(saw_walk, "con la animación de andar")
	_check(on_furniture == 0, "sin pisar muebles (%d fotogramas)" % on_furniture)
	# Juega con el ovillo: va hasta él, le da un zarpazo (la pata gira) y el ovillo rueda.
	var leg := skel.find_bone("leg_fr")
	var yarn_from := yarn.position
	var lo := INF
	var hi := -INF
	cat._gen += 1
	gen = cat._gen
	# Si el ovillo quedó donde no llega, lo devuelve rodando a un sitio libre y lo intenta otra vez.
	var reached := false
	for attempt in 3:
		cat._gen += 1
		gen = cat._gen
		cat._play_with_yarn(gen)
		if await _wait_until(func(): return cat.activity == &"bat", 14.0):
			reached = true
			break
		await get_tree().create_timer(1.2).timeout
	_check(reached, "va hasta el ovillo")
	yarn_from = yarn.position
	t = 0.0
	var moved := 0.0
	while t < 2.6:
		var a := skel.get_bone_pose_rotation(leg).get_angle()
		lo = minf(lo, a)
		hi = maxf(hi, a)
		moved = yarn.position.distance_to(yarn_from)
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(moved >= 0.3, "le da un zarpazo y el ovillo rueda (%.2f m)" % moved)
	_check(hi - lo > 0.6, "la pata del zarpazo gira (%.2f rad)" % (hi - lo))
	await get_tree().create_timer(1.6).timeout
	_check(shell.floor_bounds.has_point(Vector2(yarn.position.x, yarn.position.z)) and not shell.is_blocked(Vector2(yarn.position.x, yarn.position.z), 0.0), "el ovillo acaba en suelo libre")
	cat._gen += 1
	cat._move_to = Vector3.INF
	# Orejas.
	var ear := skel.find_bone("ear_l")
	var ear_r := skel.find_bone("ear_r")
	var ear_moved := 0.0
	cat.twitch_now()
	for i in 10:
		await get_tree().create_timer(0.05).timeout
		ear_moved = maxf(ear_moved, maxf(skel.get_bone_pose_rotation(ear).get_angle(), skel.get_bone_pose_rotation(ear_r).get_angle()))
	_check(ear_moved > 0.2, "sacude una oreja (%.2f rad)" % ear_moved)
	# Caricia: apuntarle con las manos vacías y E.
	var c := cat.global_position
	var aimed := false
	for d: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0.7, 0, 0.7), Vector3(-0.7, 0, -0.7)]:
		var spot := room.to_local(c + d * 1.1)
		if shell.is_blocked(Vector2(spot.x, spot.z), 0.1) or not shell.floor_bounds.has_point(Vector2(spot.x, spot.z)):
			continue
		player.teleport(c + d * 1.1)
		await _settle()
		player.look_at_point(c + Vector3(0.0, 0.2, 0.0))
		await _frames(3)
		if holder.hover_target == cat:
			aimed = true
			break
	_check(aimed, "al apuntarle sale «Acariciar»")
	var pets := cat.pets
	await _press(&"interact")
	_check(await _wait_until(func(): return cat.is_petting(), 1.0), "E le acaricia")
	_check(cat.pets == pets + 1 and cat.current_pose() == &"pet", "se sienta, cierra los ojos y ronronea (%s)" % cat.current_pose())
	_check(await _wait_until(func(): return not cat.is_petting(), ShopCat.PET_TIME + 2.0), "luego vuelve a lo suyo")
	cat._set_animating(false)


## Barrer a mano: coger la escoba y el recogedor (E), barrer todos los papelitos, vaciar el recogedor en
## la papelera cada vez que se llena (con polvo) y dejar el suelo limpio.
func _test_sweep(room: RoomController, hud: Node) -> void:
	print("-- Barrer el suelo")
	var sweep := shop.floor_sweep()
	_check(sweep != null, "hay escoba, recogedor y papelera")
	if sweep == null:
		return
	var total := sweep.scraps_total()
	_check(sweep.scraps_left() > 50, "papelitos en el suelo antes de barrer (%d)" % sweep.scraps_left())
	_check(sweep.broom.visible and sweep.broom.position.distance_to(ShopSweep.BROOM_REST) < 0.01, "la escoba y el recogedor están apoyados en la pared")
	var boxes := Rect2(5.4 - 0.45, 3.85 - 1.0, 0.95, 1.5)
	_check(not boxes.grow(0.05).has_point(Vector2(ShopSweep.BIN_AT.x, ShopSweep.BIN_AT.z)), "la papelera no está dentro de las cajas")
	player.teleport(room.to_global(ShopSweep.BROOM_REST + Vector3(-0.3, 0.0, -1.3)))
	await _settle()
	player.look_at_point(room.to_global(ShopSweep.BROOM_REST + Vector3(-0.2, 0.6, 0.0)))
	await _frames(3)
	_check(holder.hover_target == sweep, "al apuntar a la escoba sale «Coger escoba y recogedor»")
	await _press(&"interact")
	_check(await _wait_until(func(): return holder.sweeper.active, 1.0), "E coge la escoba y el recogedor")
	await get_tree().create_timer(Sweeper.TAKE_TIME + 0.1).timeout
	var dumps := [0]
	var puffs := 0
	var max_pan := 0
	var strokes := 0
	var stuck := 0
	var t0 := Time.get_ticks_msec()
	var on_dump := func(_n: int): dumps[0] += 1
	sweep.load_dumped.connect(on_dump)
	while sweep.scraps_left() > 0 and stuck < 6 and Time.get_ticks_msec() - t0 < 400000:
		if sweep.pan_full():
			puffs += await _dump_pan(room, sweep)
			continue
		var target := sweep.nearest_scrap(player.global_position)
		var left := sweep.scraps_left()
		if not await _stand_to_sweep(room, target):
			stuck += 1
			print("    (diagnóstico) no hay sitio para barrer el papelito en %s" % room.to_local(target).snapped(Vector3.ONE * 0.01))
			sweep._hide_scrap(_scrap_at(sweep, target))
			continue
		await _press(&"place", 3)
		await _wait_until(func(): return holder.sweeper._stroke < 0.0, 1.0)
		strokes += 1
		max_pan = maxi(max_pan, sweep.pan_count())
		if sweep.scraps_left() == left and not sweep.pan_full():
			stuck += 1
			print("    (diagnóstico) el escobazo no cogió el papelito en %s (jugador %s)" % [room.to_local(target).snapped(Vector3.ONE * 0.01), room.to_local(player.global_position).snapped(Vector3.ONE * 0.01)])
			sweep._hide_scrap(_scrap_at(sweep, target))
	if sweep.pan_count() > 0:
		puffs += await _dump_pan(room, sweep)
	sweep.load_dumped.disconnect(on_dump)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	_check(stuck == 0, "todos los papelitos se pueden barrer (%d no)" % stuck)
	_check(sweep.scraps_left() == 0, "suelo sin papelitos (%d escobazos, %.0f s)" % [strokes, secs])
	_check(max_pan == ShopSweep.PAN_CAPACITY, "el recogedor se llena (%d)" % max_pan)
	_check(dumps[0] >= ceili(float(total) / ShopSweep.PAN_CAPACITY), "%d vaciados en la papelera" % dumps[0])
	_check(puffs == dumps[0], "nube de polvo en cada vaciado (%d)" % puffs)
	_check(sweep.is_clean(), "suelo limpio y recogedor vacío")
	_check(hud._floor_label.text == "Suelo barrido  100 %", "el HUD lo cuenta (%s)" % hud._floor_label.text)
	await _frames(3)
	var floor_state: Dictionary = SaveGame.read().get("floor", {})
	_check((floor_state.get("swept", []) as Array).size() == total, "el guardado tiene el suelo barrido")


## Se pone a 1 m del papelito, mirándolo en el suelo, desde un sitio libre.
func _stand_to_sweep(room: RoomController, target: Vector3) -> bool:
	var local := room.to_local(target)
	var dirs: Array[Vector3] = []
	for k in 12:
		dirs.append(Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 12.0))
	for dist: float in [1.0, 1.3, 0.85]:
		for d in dirs:
			var spot := local + d * dist
			if room.shell.is_blocked(Vector2(spot.x, spot.z), 0.25) or not room.shell.floor_bounds.has_point(Vector2(spot.x, spot.z)):
				continue
			player.teleport(room.to_global(Vector3(spot.x, 0.0, spot.z)))
			await _settle()
			var at := room.to_local(player.global_position)
			if Vector2(at.x - spot.x, at.z - spot.z).length() > 0.2:
				continue
			player.look_at_point(target)
			await _frames(4)
			return true
	return false


func _scrap_at(sweep: ShopSweep, global_pos: Vector3) -> int:
	var p := sweep.to_local(global_pos)
	for i in sweep._home.size():
		if not sweep._gone[i] and sweep._home[i].origin.distance_to(p) < 0.01:
			return i
	return -1


## Va a la papelera, la apunta y vacía el recogedor con un clic. Devuelve 1 si salió la nube de polvo.
func _dump_pan(room: RoomController, sweep: ShopSweep) -> int:
	player.teleport(room.to_global(ShopSweep.BIN_AT + Vector3(-0.4, 0.0, -1.2)))
	await _settle()
	player.look_at_point(sweep.bin_top())
	await _frames(3)
	_check(holder.sweeper._aiming_at_bin(), "apunta a la papelera con el recogedor lleno")
	await _press(&"place", 2)
	var puff := await _wait_until(func(): return sweep.get_node_or_null("DustPuff") != null, 2.0)
	await _wait_until(func(): return not sweep.is_dumping(), 3.0)
	_check(sweep.pan_count() == 0, "el recogedor se vacía en la papelera")
	return 1 if puff else 0


## Tras colocar, si queda otro suelto del mismo tipo, ese (el más cercano) brilla como pista.
func _check_next_hint(room: RoomController, placed: PickableItem) -> void:
	var hint := main.get_node("World/NextItemHint") as NextItemHint
	var same: Array = []
	for other: PickableItem in room.get_items():
		if other.state == PickableItem.State.LOOSE and other.data.sort_key == placed.data.sort_key:
			same.append(other)
	if same.is_empty():
		_check(hint._target == null, "sin más '%s' sueltos no hay pista" % placed.data.sort_key)
		return
	_check(hint._target != null and same.has(hint._target) and hint._target.is_hinted(), "pista en el siguiente '%s' suelto" % placed.data.sort_key)


func _skipped(room: RoomController, max_sections: int) -> int:
	var n := 0
	for si in room.sections.size():
		if si >= max_sections:
			n += room.sections[si].total_items
	return n

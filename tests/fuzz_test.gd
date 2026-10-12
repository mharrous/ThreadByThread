extends Node
## Prueba de "mono": acciones aleatorias (andar, mirar, recoger, colocar, dejar, lanzar, pausar, guardar,
## teletransportarse entre salas) durante muchos pasos, comprobando invariantes del juego: nada fuera del
## mundo, ningún objeto en el aire para siempre, contadores coherentes, un solo objeto por hueco, el jugador
## siempre dentro del edificio. Los errores de Godot (SCRIPT ERROR, etc.) quedan en el log.
##   godot --headless --path . res://tests/fuzz_test.tscn -- --test-mode [--steps=N] [--seed=S] [--count=K]
## Código de salida 0 = sin violaciones.

var main: Node
var shop: Shop
var player: Player
var holder: ItemHolder
var rng := RandomNumberGenerator.new()
var violations: Dictionary = {}
var _stuck_since: Dictionary = {}
var _steps := 600
var _counts: Dictionary = {}
var _last_action := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _violation(msg: String) -> void:
	if not violations.has(msg):
		violations[msg] = 0
		print("  VIOLACIÓN: ", msg, "   [última acción: ", _last_action, "]")
	violations[msg] += 1


func _run() -> void:
	var count := 2
	var seed_value := 12345
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--steps="):
			_steps = int(arg.trim_prefix("--steps="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--count="):
			count = int(arg.trim_prefix("--count="))
	rng.seed = seed_value
	print("== Prueba de mono · %d pasos · semilla %d ==" % [_steps, seed_value])
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	shop = main.get_node("Shop")
	for r in shop.get_children():
		if r is RoomController:
			(r as RoomController).count_override = count
	add_child(main)
	await _frames(20)
	player = main.get_node("Player")
	holder = player.get_node("ItemHolder")
	# Todas las salas abiertas para poder pasear por ellas.
	for i in range(1, shop.rooms.size()):
		shop.unlock_room(i, false)
	await _wait_audio()

	for step in _steps:
		await _random_action(step)
		_check_invariants(step)
	await _frames(60)
	_check_invariants(_steps)

	print("-- Acciones realizadas: ", _counts)
	print("")
	if violations.is_empty():
		print("RESULTADO: SIN VIOLACIONES")
	else:
		print("RESULTADO: %d TIPOS DE VIOLACIÓN" % violations.size())
	get_tree().quit(1 if not violations.is_empty() else 0)


func _wait_audio() -> void:
	var t := 0.0
	while not AudioManager.ready_to_play and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()


func _press(action: StringName, hold_frames: int = 1) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(hold_frames)
	var rel := InputEventAction.new()
	rel.action = action
	rel.pressed = false
	Input.parse_input_event(rel)
	await get_tree().process_frame


func _count(kind: String, detail: String = "") -> void:
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	_last_action = "%s %s" % [kind, detail]


func _random_room() -> RoomController:
	return shop.rooms[rng.randi() % shop.rooms.size()]


## Mantiene una posiciÃ³n dentro de las paredes de la sala (el juego real nunca coloca al jugador fuera).
func _inside(room: RoomController, p: Vector3) -> Vector3:
	var local := room.to_local(p)
	return room.to_global(Vector3(clampf(local.x, -2.7, 2.7), local.y, clampf(local.z, -2.2, 2.2)))


func _random_floor_point(room: RoomController) -> Vector3:
	var b := room.shell.floor_bounds
	return room.global_position + Vector3(rng.randf_range(b.position.x, b.end.x), 0.0, rng.randf_range(b.position.y, b.end.y))


func _random_action(step: int) -> void:
	var r := rng.randf()
	if get_tree().paused:
		# Con el juego en pausa solo se reanuda.
		await _press(&"pause")
		await _frames(2)
		_count("reanudar")
		return
	if r < 0.14:
		# Ir a un sitio de una sala al azar.
		var room := _random_room()
		player.teleport(_random_floor_point(room))
		await _frames(2)
		player.look_at_point(room.global_position + Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(0.0, 2.2), rng.randf_range(-2.5, 2.5)))
		_count("teletransporte", str(player.global_position.snapped(Vector3.ONE * 0.1)))
	elif r < 0.30:
		# Mirar a un objeto suelto cercano y recogerlo.
		var item := _random_loose_item()
		if item != null:
			var p := item.global_position
			var from := _inside(item.room, Vector3(p.x + rng.randf_range(-0.9, 0.9), item.room.global_position.y, p.z + rng.randf_range(-0.9, 0.9)))
			player.teleport(from)
			await _frames(2)
			player.look_at_point(p)
			await _frames(3)
			await _press(&"interact")
			await _frames(18)
			_count("recoger", str(player.global_position.snapped(Vector3.ONE * 0.1)))
	elif r < 0.46 and holder.state == ItemHolder.State.HOLDING:
		# Colocar en una estantería o bandeja al azar (el juego rechaza la fila equivocada).
		var room := shop.active_room if shop.active_room != null else _random_room()
		var units := room.get_units()
		if not units.is_empty():
			var unit: StorageUnit = units[rng.randi() % units.size()]
			var row := rng.randi() % unit.rows
			var slot := rng.randi() % maxi(unit.slots_per_row, 1)
			var hint := unit.stand_hint(row, slot, holder.held)
			player.teleport(_inside(room, hint["position"]))
			await _frames(2)
			player.look_at_point(hint["look"])
			await _frames(3)
			await _press(&"place")
			await _frames(18)
			_count("colocar", str(player.global_position.snapped(Vector3.ONE * 0.1)))
	elif r < 0.56 and holder.state == ItemHolder.State.HOLDING:
		player.look_at_point(player.global_position + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.8, 0.4), rng.randf_range(-1, 1)).normalized() * 2.0)
		await _frames(2)
		await _press(&"set_down")
		await _frames(10)
		_count("dejar")
	elif r < 0.70 and holder.state == ItemHolder.State.HOLDING:
		# Lanzar en una dirección cualquiera (también hacia ventanas y puertas), con carga distinta.
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 0.8), rng.randf_range(-1, 1)).normalized()
		player.look_at_point(player.global_position + Vector3.UP * 1.5 + dir * 3.0)
		await _frames(2)
		await _press(&"throw", rng.randi_range(1, 40))
		await _frames(rng.randi_range(5, 60))
		_count("lanzar", "desde " + str(player.global_position.snapped(Vector3.ONE * 0.1)))
	elif r < 0.78:
		# Pasear: andar y correr unos fotogramas en una dirección al azar.
		var action: StringName = [&"move_forward", &"move_back", &"move_left", &"move_right"][rng.randi() % 4]
		player.look_at_point(player.global_position + Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)).normalized() * 2.0 + Vector3.UP * 1.5)
		if rng.randf() < 0.3:
			Input.action_press(&"sprint")
		if rng.randf() < 0.2:
			Input.action_press(&"crouch")
		Input.action_press(action)
		await _frames(rng.randi_range(10, 90))
		Input.action_release(action)
		Input.action_release(&"sprint")
		Input.action_release(&"crouch")
		_count("pasear", action + " desde " + str(player.global_position.snapped(Vector3.ONE * 0.1)))
	elif r < 0.84:
		await _press(&"pause")
		await _frames(3)
		_count("pausar")
	elif r < 0.88:
		shop.save_game()
		_count("guardar")
	elif r < 0.92 and holder.state == ItemHolder.State.HOLDING:
		await _press(&"rotate_item", rng.randi_range(2, 30))
		_count("girar")
	else:
		await _frames(rng.randi_range(2, 25))
		_count("esperar")


func _random_loose_item() -> PickableItem:
	var room := shop.active_room if (shop.active_room != null and rng.randf() < 0.7) else _random_room()
	var list := room.get_items()
	if list.is_empty():
		return null
	for attempt in 12:
		var it := list[rng.randi() % list.size()]
		if it.state == PickableItem.State.LOOSE or it.state == PickableItem.State.PLACED:
			return it
	return null


func _check_invariants(step: int) -> void:
	var held := holder.held
	if holder.state == ItemHolder.State.HOLDING and (held == null or not is_instance_valid(held)):
		_violation("estado HOLDING sin objeto sostenido")
	var slots := {}
	for room in shop.rooms:
		var placed := 0
		for it in room.get_items():
			var p := it.global_position
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
				_violation("posición no finita en %s" % it.data.id)
				continue
			# Dentro del edificio (4 salas en fila) con algo de margen; por debajo del suelo es un objeto caído al vacío.
			var local := room.to_local(p)
			if p.y < -0.3:
				_violation("objeto %s por debajo del suelo (y=%.2f)" % [it.data.id, p.y])
			if absf(local.z) > 3.0 or p.x < -3.6 or p.x > room.global_position.x + 3.6 + 100.0:
				_violation("objeto %s fuera del recinto (%s)" % [it.data.id, str(p.snapped(Vector3.ONE * 0.1))])
			if p.y > 3.2:
				_violation("objeto %s por encima del techo (y=%.2f)" % [it.data.id, p.y])
			if it.state == PickableItem.State.PLACED:
				placed += 1
				if it.container == null or it.slot_row < 0 or it.slot_index < 0:
					_violation("objeto PLACED sin contenedor/hueco: %s" % it.data.id)
				else:
					var key := "%s|%d|%d" % [it.container.get_path(), it.slot_row, it.slot_index]
					if slots.has(key) and slots[key] != it and it.container.stack_capacity <= 1:
						_violation("dos objetos en el mismo hueco (%s)" % key)
					slots[key] = it
			elif it.state == PickableItem.State.THROWN:
				var since: int = _stuck_since.get(it, step)
				_stuck_since[it] = since
				if step - since > 400:
					_violation("objeto %s lleva demasiado tiempo en vuelo" % it.data.id)
			else:
				_stuck_since.erase(it)
		if placed != room.placed_items:
			_violation("contador de sala %s (%d) distinto de los objetos colocados (%d)" % [room.room_id, room.placed_items, placed])
	# El jugador no sale del edificio ni cae.
	var pp := player.global_position
	if pp.y < -0.5 or pp.y > 1.0:
		_violation("jugador fuera de altura razonable (y=%.2f)" % pp.y)
	if pp.x < -3.6 or pp.x > 22.8 or absf(pp.z) > 2.9:
		_violation("jugador fuera del edificio (%s)" % str(pp.snapped(Vector3.ONE * 0.1)))


var _hist: Dictionary = {}
var _reported_escape: Dictionary = {}


## Vigila cada fotograma los objetos en vuelo y, si uno sale del edificio, cuenta cómo lo hizo.
func _process(_delta: float) -> void:
	if shop == null:
		return
	for room in shop.rooms:
		for it in room.get_items():
			if it.state != PickableItem.State.THROWN:
				_hist.erase(it)
				continue
			var h: Array = _hist.get(it, [])
			h.append(it.global_position)
			if h.size() > 8:
				h.pop_front()
			_hist[it] = h
			var local := room.to_local(it.global_position)
			var outside_ns := absf(local.z) > 2.75
			if outside_ns and not _reported_escape.has(it):
				_reported_escape[it] = true
				var snapped: Array = []
				for p in h:
					snapped.append((p as Vector3).snapped(Vector3.ONE * 0.01))
				print("  ESCAPE: %s (sala %s) velocidad=%s últimas posiciones=%s" % [it.data.id, room.room_id, str(it.linear_velocity.snapped(Vector3.ONE * 0.1)), str(snapped)])

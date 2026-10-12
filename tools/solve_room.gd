extends Node
## Herramienta de desarrollo: ordena de golpe una sala (coloca todos sus objetos en su sitio como
## si el jugador lo hubiera hecho), deja que se complete y desbloquee la siguiente, y guarda en la
## partida REAL. Sirve para ver las salas siguientes sin jugar la anterior.
##   (con el juego cerrado)
##   godot --headless --path . res://tools/solve_room.tscn -- --room=0
## --room=N  índice de la sala a ordenar (0 = ovillos; por defecto 0). Se mantiene el progreso ya guardado.

func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var index := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			index = int(arg.trim_prefix("--room="))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(30)
	var shop: Shop = main.get_node("Shop")
	var player: Player = main.get_node("Player")
	if index < 0 or index >= shop.rooms.size():
		print("Sala %d no existe" % index)
		get_tree().quit(1)
		return
	var room := shop.rooms[index]
	var placed := 0
	for it in room.get_items():
		if it.state == PickableItem.State.PLACED:
			continue
		var found := room.find_row(it.data.sort_key)
		if found.is_empty():
			continue
		var unit: StorageUnit = found["unit"]
		var row: int = found["row"]
		var slot := unit.first_free_slot(row)
		if slot < 0:
			continue
		unit.reserve(row, slot, it)
		it.container = unit
		it.slot_row = row
		it.slot_index = slot
		it.state = PickableItem.State.PLACED
		it.global_transform = unit.slot_transform(row, slot, it)
		Events.item_placed.emit(it, unit)
		placed += 1
	print("Colocados %d objetos de '%s' (%d/%d)" % [placed, room.display_name, room.placed_items, room.total_items])
	# La sala anuncia su final con retardos (cartel, desbloqueo de la puerta, guirnalda).
	var waited := 0.0
	while waited < 6.0 and not (room.is_completed and (index + 1 >= shop.rooms.size() or shop.rooms[index + 1].is_unlocked)):
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(2.5).timeout
	# El jugador aparece en la sala siguiente (la partida guarda la sala activa).
	if index + 1 < shop.rooms.size():
		player.teleport(shop.rooms[index + 1].entry_point())
		await _frames(10)
	var ok := shop.save_game()
	print("Sala completada: %s · siguiente desbloqueada: %s · guardado: %s" % [room.is_completed, index + 1 >= shop.rooms.size() or shop.rooms[index + 1].is_unlocked, ok])
	get_tree().quit(0 if ok and room.is_completed else 1)

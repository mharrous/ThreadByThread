extends Node
## Herramienta de desarrollo: ordena de golpe una sección de la mercería (coloca todos sus objetos en su
## sitio como si el jugador lo hubiera hecho), deja que se complete y guarda en la partida REAL. Sirve para
## ver los premios y el final sin jugar.
##   (con el juego cerrado)
##   godot --headless --path . res://tools/solve_room.tscn -- --section=0
## --section=N  índice de la sección (0 = lanas, 1 = botones, 2 = telas, 3 = sastrería; por defecto 0).
##              --section=all ordena toda la mercería. Se mantiene el progreso ya guardado.

func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var arg_value := "0"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="):
			arg_value = arg.trim_prefix("--section=")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(30)
	var shop: Shop = main.get_node("Shop")
	var room := shop.room
	var section: ShopSection = null
	if arg_value != "all":
		var index := int(arg_value)
		if index < 0 or index >= room.sections.size():
			print("La sección %d no existe" % index)
			get_tree().quit(1)
			return
		section = room.sections[index]
	var before := room.placed_items
	room.solve_instantly(section)
	print("Colocados %d objetos de '%s' (%d/%d)" % [room.placed_items - before, section.display_name if section else "toda la mercería", room.placed_items, room.total_items])
	# Los premios llegan con retardos (focos, cartel, guirnaldas).
	await get_tree().create_timer(4.0).timeout
	var ok := shop.save_game()
	var done := room.is_completed if section == null else section.is_completed
	print("Completada: %s · guardado: %s" % [done, ok])
	get_tree().quit(0 if ok and done else 1)

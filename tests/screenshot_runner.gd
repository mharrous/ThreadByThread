extends Node
## Captura imágenes del juego (necesita ventana, no headless).
##   godot --path . res://tests/screenshot_runner.tscn -- --out=<carpeta> --test-mode --no-autopause [--filled]
## Por cada sala: vista de entrada, estanterías, mesa y detalle. Con --filled primero coloca todos
## los objetos de golpe (sin animar) para ver los contenedores llenos.

const POSES := [
	{"name": "entrada", "pos": Vector3(0, 0, 1.9), "look": Vector3(0, 1.1, -2.5)},
	{"name": "izq", "pos": Vector3(-0.9, 0, -0.1), "look": Vector3(-1.3, 1.0, -2.3)},
	{"name": "der", "pos": Vector3(0.9, 0, -0.1), "look": Vector3(1.3, 1.0, -2.3)},
	{"name": "centro", "pos": Vector3(0.0, 0, 2.1), "look": Vector3(0.0, 0.7, 0.6)},
	{"name": "esquina", "pos": Vector3(1.8, 0, 0.9), "look": Vector3(-1.5, 0.6, 0.4)},
]

var _out_dir := ""
var _filled := false
var _only_room := -1
var _treasures := false  # --treasures: tesoros escondidos, repisa con los hallados y guirnalda de cada sala
var _book := false      # --book: libro de colecciones del menú de pausa
var _street := false    # --street: solo fotografía la vista de la ventana con cada tipo de suceso de la calle


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg == "--filled":
			_filled = true
		elif arg.begins_with("--room="):
			_only_room = int(arg.trim_prefix("--room="))
		elif arg == "--street":
			_street = true
		elif arg == "--book":
			_book = true
		elif arg == "--treasures":
			_treasures = true
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	print("captura ", path, " -> ", error_string(err))


func _fill_room(room: RoomController) -> void:
	for it in room.get_items():
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


## Cada sala: el escondite de un tesoro (sin hallar), luego la repisa con los dos hallados y la guirnalda.
func _run_treasures(shop: Shop, player: Player) -> void:
	for room in shop.rooms:
		if _only_room >= 0 and room.index != _only_room:
			continue
		room.visible = true
		var spot := room.shell.treasure_spots[0]
		var stand := Vector3(spot.x, 0.0, minf(spot.z + 1.5, 1.6))
		player.teleport(room.to_global(stand))
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.look_at_point(room.to_global(spot + Vector3(0, 0.1, 0)))
		for i in 12:
			await get_tree().process_frame
		await _shot("sala%d_tesoro_escondido" % (room.index + 1))
		for data in room.treasure_catalog.items:
			room._restore_treasure(data.id)
		room.shell.unlock_decor(&"bunting", false)
		player.teleport(room.to_global(Vector3(-0.6, 0.0, 0.4)))
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.look_at_point(room.to_global(Vector3(-1.85, 1.55, 2.4)))
		for i in 12:
			await get_tree().process_frame
		await _shot("sala%d_repisa" % (room.index + 1))
		player.teleport(room.to_global(Vector3(0.0, 0.0, 2.0)))
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.look_at_point(room.to_global(Vector3(0.0, 2.3, -1.5)))
		for i in 12:
			await get_tree().process_frame
		await _shot("sala%d_guirnalda" % (room.index + 1))

## Vista de la ventana: primero la calle vacía y luego cada tipo de suceso congelado delante de la ventana.
func _run_street(main: Node, player: Player) -> void:
	var landscape := main.get_node("World/Landscape") as Landscape
	var life := landscape.get_street_life()
	life.enabled = false
	player.teleport(Vector3(-2.3, 0.0, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(Vector3(-12.0, 1.5, 0.0))
	for i in 10:
		await get_tree().process_frame
	await _shot("ventana_vacia")
	player.look_at_point(Vector3(-12.0, 1.9, 6.0))
	for i in 6:
		await get_tree().process_frame
	await _shot("ventana_lado")
	player.look_at_point(Vector3(-12.0, 1.5, 0.0))
	for kind: StringName in [&"car", &"van", &"bike", &"moto", &"walker", &"dogwalker"]:
		var actor := life.spawn(kind)
		# Se lleva al centro de la ventana y se avanza el paso a mano; luego se congela para la foto.
		# Termina a 2 m del centro de la ventana (a la derecha): el montante no tapa el motivo.
		actor.position.z = -2.0 - actor.velocity.z * 0.96
		for i in 8:
			actor._process(0.12)
		actor.set_process(false)
		for i in 6:
			await get_tree().process_frame
		await _shot("ventana_%s" % kind)
		actor.queue_free()
		life._actors.erase(actor)
	# Ventanas sur de las demás salas: el jardín trasero.
	var shop := main.get_node("Shop") as Shop
	for room in shop.rooms:
		if room.index == 0:
			continue
		room.visible = true
		player.teleport(room.to_global(Vector3(0.0, 0.0, 1.3)))
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.look_at_point(room.to_global(Vector3(0.0, 1.55, 6.0)))
		for i in 8:
			await get_tree().process_frame
		await _shot("ventana_sur_sala%d" % (room.index + 1))
	print("rendimiento: fps=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 30:
		await get_tree().process_frame
	var shop: Shop = main.get_node("Shop")
	var player: Player = main.get_node("Player")
	if _street:
		await _run_street(main, player)
		get_tree().quit()
		return
	if _book:
		var room: RoomController = shop.rooms[0]
		room._restore_treasure(room.treasure_catalog.items[0].id)
		# Para ver el libro con contenido: media sala 1 colocada, la sala 2 abierta y un tesoro en cada una.
		var placed_n := 0
		for it in room.get_items():
			var found := room.find_row(it.data.sort_key)
			if found.is_empty() or placed_n >= 100:
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
			placed_n += 1
		for k in range(1, shop.rooms.size()):
			shop.unlock_room(k, false)
		var room2: RoomController = shop.rooms[1]
		room2._restore_treasure(room2.treasure_catalog.items[1].id)
		var menu := main.get_node("PauseMenu")
		menu.open()
		menu._show_book(true)
		for i in 12:
			await get_tree().process_frame
		await _shot("libro")
		var scroll := menu._book_content.get_parent() as ScrollContainer
		for pos in [560, 1120, 1680, 2240]:
			scroll.scroll_vertical = pos
			for i in 6:
				await get_tree().process_frame
			await _shot("libro_%d" % pos)
		menu._show_book(false)
		for i in 12:
			await get_tree().process_frame
		await _shot("menu")
		get_tree().quit()
		return
	if _treasures:
		await _run_treasures(shop, player)
		get_tree().quit()
		return
	var tag := "lleno" if _filled else "caos"
	for room in shop.rooms:
		if _only_room >= 0 and room.index != _only_room:
			continue
		if _filled:
			_fill_room(room)
		# Para fotografiar, todas las salas visibles y puertas abiertas.
		room.visible = true
		if room.shell.east_door != null:
			room.shell.east_door.unlock(false)
		for pose: Dictionary in POSES:
			player.teleport(room.to_global(pose["pos"]))
			await get_tree().physics_frame
			await get_tree().physics_frame
			player.look_at_point(room.to_global(pose["look"]))
			for i in 8:
				await get_tree().process_frame
			await _shot("sala%d_%s_%s" % [room.index + 1, pose["name"], tag])
	print("rendimiento: fps=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()

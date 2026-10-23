extends Node
## Captura imágenes del juego (necesita ventana, no headless).
##   godot --path . res://tests/screenshot_runner.tscn -- --out=<carpeta> --test-mode --no-autopause [--filled]
## Vistas de la mercería: entrada, cada pared y el suelo. Con --filled primero coloca todos
## los objetos de golpe (sin animar) para ver los contenedores llenos.

const POSES := [
	{"name": "entrada", "pos": Vector3(0, 0, 2.9), "look": Vector3(0, 1.1, -4.5)},
	{"name": "norte_lanas", "pos": Vector3(-2.6, 0, -2.4), "look": Vector3(-2.6, 1.0, -4.5)},
	{"name": "norte_carretes", "pos": Vector3(2.6, 0, -2.4), "look": Vector3(2.6, 1.0, -4.5)},
	{"name": "este_sastreria", "pos": Vector3(2.6, 0, -0.4), "look": Vector3(6.0, 1.2, -0.7)},
	{"name": "sur_telas", "pos": Vector3(-1.6, 0, 1.0), "look": Vector3(-2.0, 1.0, 4.5)},
	{"name": "oeste_ventana", "pos": Vector3(-2.4, 0, 0.8), "look": Vector3(-6.0, 1.2, 1.4)},
	{"name": "suelo", "pos": Vector3(2.0, 0, 2.6), "look": Vector3(-1.5, 0.0, 0.0)},
	{"name": "esquina", "pos": Vector3(4.6, 0, 2.6), "look": Vector3(-5.5, 0.6, -3.5)},
]

var _out_dir := ""
var _filled := false
var _treasures := false  # --treasures: tesoros escondidos, repisa con los hallados y guirnaldas
var _book := false      # --book: libro de colecciones del menú de pausa
var _street := false    # --street: solo fotografía la vista de la ventana con cada tipo de suceso de la calle


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg == "--filled":
			_filled = true
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


func _look_from(player: Player, room: RoomController, stand: Vector3, at: Vector3) -> void:
	player.teleport(room.to_global(stand))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(room.to_global(at))
	for i in 12:
		await get_tree().process_frame


## Cada escondite de tesoro (sin hallar), luego la repisa con todos los hallados y las guirnaldas.
func _run_treasures(shop: Shop, player: Player) -> void:
	var room := shop.room
	for i in room.shell.treasure_spots.size():
		var spot := room.shell.treasure_spots[i]
		var inward := -Vector3(spot.x, 0.0, spot.z).normalized()
		await _look_from(player, room, Vector3(spot.x, 0.0, spot.z) + inward * 1.6, spot + Vector3(0, 0.1, 0))
		await _shot("tesoro_escondido_%d" % (i + 1))
	for data in room._treasure_list:
		room._restore_treasure(data.id)
	for section in room.sections:
		section.show_completed(false)
	room.shell.unlock_decor(&"bunting", false)
	room.shell.unlock_decor(&"open_sign", false)
	room.shell.open_shop(false)
	await _look_from(player, room, Vector3(3.6, 0.0, 2.6), Vector3(4.6, 1.55, 4.4))
	await _shot("repisa")
	await _look_from(player, room, Vector3(0.0, 0.0, 3.4), Vector3(0.0, 2.4, -3.0))
	await _shot("guirnaldas_y_abierto")
	await _look_from(player, room, Vector3(3.0, 0.0, -0.6), Vector3(6.0, 2.4, -0.7))
	await _shot("cartel_seccion_completa")


## Vista de la ventana: primero la calle vacía y luego cada tipo de suceso congelado delante de la ventana.
func _run_street(main: Node, player: Player) -> void:
	var landscape := main.get_node("World/Landscape") as Landscape
	var life := landscape.get_street_life()
	life.enabled = false
	# La ventana oeste está en x = -6 (el paisaje va desplazado 3 m al oeste).
	player.teleport(Vector3(-5.3, 0.0, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(Vector3(-15.0, 1.5, 0.0))
	for i in 10:
		await get_tree().process_frame
	await _shot("ventana_vacia")
	player.look_at_point(Vector3(-15.0, 1.9, 6.0))
	for i in 6:
		await get_tree().process_frame
	await _shot("ventana_lado")
	player.look_at_point(Vector3(-15.0, 1.5, 0.0))
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
	# Ventana sur: el jardín trasero.
	var shop := main.get_node("Shop") as Shop
	for x in shop.room.shell.south_windows:
		await _look_from(player, shop.room, Vector3(x, 0.0, 2.8), Vector3(x, 1.55, 10.0))
		await _shot("ventana_sur")
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
		var room: RoomController = shop.room
		room._restore_treasure(room._treasure_list[0].id)
		room._restore_treasure(room._treasure_list[3].id)
		# Para ver el libro con contenido: 100 objetos colocados y dos tesoros hallados.
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
	var room := shop.room
	if _filled:
		_fill_room(room)
	for pose: Dictionary in POSES:
		await _look_from(player, room, pose["pos"], pose["look"])
		await _shot("%s_%s" % [pose["name"], tag])
	print("rendimiento: fps=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()

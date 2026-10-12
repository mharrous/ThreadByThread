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


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg == "--filled":
			_filled = true
		elif arg.begins_with("--room="):
			_only_room = int(arg.trim_prefix("--room="))
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


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 30:
		await get_tree().process_frame
	var shop: Shop = main.get_node("Shop")
	var player: Player = main.get_node("Player")
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

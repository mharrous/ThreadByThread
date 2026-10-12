extends Node
## Captura imágenes del juego desde varias posiciones (necesita ventana, no headless).
## godot --path . res://tests/screenshot_runner.tscn -- --out=<carpeta> --no-autopause

const POSES := [
	{"name": "01_entrada", "pos": Vector3(0, 0, 1.9), "look": Vector3(0, 1.1, -2.5)},
	{"name": "02_estanterias", "pos": Vector3(-0.3, 0, -0.7), "look": Vector3(-1.2, 1.0, -2.3)},
	{"name": "03_mesa", "pos": Vector3(0.6, 0, 0.9), "look": Vector3(2.2, 0.8, 0.8)},
	{"name": "04_ventana", "pos": Vector3(1.2, 0, 0.2), "look": Vector3(-3.0, 1.4, 0.0)},
	{"name": "04b_paisaje", "pos": Vector3(-2.0, 0, 0.1), "look": Vector3(-12.0, 1.7, 0.0)},
	{"name": "04c_paisaje_ancho", "pos": Vector3(-1.5, 0, -0.5), "look": Vector3(-20.0, 2.6, 6.0)},
	{"name": "05_rincon", "pos": Vector3(0.5, 0, 0.5), "look": Vector3(-2.6, 0.5, 1.9)},
]

var _out_dir := ""
var _holder_item_shot := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(name + ".png")
	var err := img.save_png(path)
	print("captura ", path, " -> ", error_string(err))


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var player: Player = main.get_node("Player")
	var room: RoomController = main.get_node("Room")
	for pose: Dictionary in POSES:
		player.teleport(pose["pos"])
		player.look_at_point(pose["look"])
		for i in 8:
			await get_tree().process_frame
		await _shot(pose["name"])

	# Sosteniendo un ovillo frente a la estantería, apuntando a su fila.
	var holder: ItemHolder = player.get_node("ItemHolder")
	var item := room.get_items()[0]
	var p := item.global_position
	player.teleport(Vector3(p.x, 0, p.z) + Vector3(0, 0, 0.9))
	player.look_at_point(p)
	for i in 4:
		await get_tree().process_frame
	await _shot("06_apuntando_ovillo")
	holder.try_pick()
	for i in 40:
		await get_tree().process_frame
	var found := room.find_row(item.data.sort_key)
	var shelf: ShelfUnit = found["shelf"]
	var target := shelf.slot_world_position(found["row"], 4, item.radius)
	player.teleport(Vector3(target.x, 0, shelf.global_position.z + shelf.depth + 1.0))
	player.look_at_point(target)
	for i in 40:
		await get_tree().process_frame
	await _shot("07_sosteniendo_apuntando")
	holder.try_place()
	for i in 14:
		await get_tree().process_frame
	await _shot("08_colocando")
	for i in 30:
		await get_tree().process_frame
	await _shot("09_colocado")

	# Lanzamiento: en el aire, primer rebote y reposo.
	var toss: PickableItem = room.get_items()[1]
	var tp := toss.global_position
	player.teleport(Vector3(tp.x, 0, tp.z) + Vector3(0, 0, 0.9))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(tp)
	for i in 4:
		await get_tree().process_frame
	holder.try_pick()
	while holder.state != ItemHolder.State.HOLDING:
		await get_tree().process_frame
	player.teleport(Vector3(0.6, 0, 1.7))
	await get_tree().physics_frame
	player.look_at_point(Vector3(0.0, 0.5, -0.4))
	for i in 20:
		await get_tree().process_frame
	await _shot("09b_antes_de_lanzar")
	holder.try_throw()
	for i in 14:
		await get_tree().process_frame
	await _shot("09c_en_el_aire")
	for i in 14:
		await get_tree().process_frame
	await _shot("09d_rebote")
	for i in 120:
		await get_tree().process_frame
	await _shot("09e_reposo")

	# Ordena el resto para ver la recompensa final.
	var rest := room.get_items().duplicate()
	rest.erase(item)
	for other: PickableItem in rest:
		await _order(player, holder, room, other)
	for i in 120:
		await get_tree().process_frame
	await _shot("10_sala_completada")
	for i in 90:
		await get_tree().process_frame
	await _shot("11_sala_completada_calma")
	_report_performance()
	get_tree().quit()


func _order(player: Player, holder: ItemHolder, room: RoomController, item: PickableItem) -> void:
	var p := item.global_position
	var toward := Vector3(-p.x, 0.0, 1.0 - p.z).normalized()
	player.teleport(Vector3(p.x, 0, p.z) + toward * 0.9)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(p)
	for i in 3:
		await get_tree().process_frame
	holder.try_pick()
	while holder.state != ItemHolder.State.HOLDING:
		await get_tree().process_frame
	var found := room.find_row(item.data.sort_key)
	var shelf: ShelfUnit = found["shelf"]
	var slot := shelf.first_free_slot(found["row"])
	var target := shelf.slot_world_position(found["row"], slot, item.radius)
	player.teleport(Vector3(target.x, 0, shelf.global_position.z + shelf.depth + 0.95))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(target)
	for i in 3:
		await get_tree().process_frame
	holder.try_place()
	while holder.state != ItemHolder.State.EMPTY:
		await get_tree().process_frame


func _report_performance() -> void:
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("rendimiento: fps=", Engine.get_frames_per_second(), " draw_calls=", draw_calls, " objetos=", objects, " primitivas=", prims)

extends Node
## Mide rendimiento con TODA la mercería cargada (necesita ventana). Sin VSync para ver el límite real:
##   godot --path . --windowed --resolution 1920x1080 --disable-vsync res://tests/perf_test.tscn -- --test-mode --no-vsync
## Imprime FPS medios, percentil 95 del tiempo de frame y llamadas de dibujo por escena.

const SAMPLE_FRAMES := 240

const VIEWS := [
	{"name": "entrada", "pos": Vector3(0, 0, 1.9), "look": Vector3(0, 1.1, -2.5)},
	{"name": "estanterías", "pos": Vector3(-0.3, 0, -0.7), "look": Vector3(-1.2, 1.0, -2.3)},
	{"name": "suelo", "pos": Vector3(0.5, 0, 0.5), "look": Vector3(-1.5, 0.0, 1.2)},
]


func _ready() -> void:
	_run.call_deferred()


func _measure(label: String) -> void:
	var times: Array[float] = []
	for i in SAMPLE_FRAMES:
		await get_tree().process_frame
		times.append(get_process_delta_time())
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	var avg_ms := total / times.size() * 1000.0
	var p95_ms: float = times[int(times.size() * 0.95)] * 1000.0
	var worst_ms: float = times[times.size() - 1] * 1000.0
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("%-30s fps=%6.1f  frame medio=%5.2f ms  p95=%5.2f ms  peor=%6.2f ms  draw calls=%d" % [
		label, 1000.0 / avg_ms, avg_ms, p95_ms, worst_ms, calls])


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 90:
		await get_tree().process_frame
	var player: Player = main.get_node("Player")
	var shop: Shop = main.get_node("Shop")
	var objects := 0
	for r in shop.rooms:
		objects += r.total_items
	print("== Rendimiento · %d objetos en %d salas · ventana %s ==" % [objects, shop.rooms.size(), str(get_window().size)])
	for room in shop.rooms:
		for v: Dictionary in VIEWS:
			player.teleport(room.to_global(v["pos"]))
			player.look_at_point(room.to_global(v["look"]))
			for i in 25:
				await get_tree().process_frame
			await _measure("sala %d · %s" % [room.index + 1, v["name"]])

	# Peor caso: todas las salas visibles a la vez.
	for r in shop.rooms:
		r.visible = true
	shop.set_process(false)
	player.teleport(shop.rooms[1].to_global(Vector3(-2.6, 0, -0.9)))
	player.look_at_point(shop.rooms[1].to_global(Vector3(6.0, 1.2, -0.9)))
	for i in 25:
		await get_tree().process_frame
	await _measure("todas visibles (pasillo)")

	# 40 objetos rebotando a la vez en la sala 1.
	shop.set_process(true)
	var room := shop.rooms[0]
	player.teleport(room.to_global(Vector3(0.5, 0, 1.9)))
	player.look_at_point(room.to_global(Vector3(0, 0.3, 0.2)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var items := room.get_items()
	for i in mini(40, items.size()):
		var it: PickableItem = items[i]
		it.global_position += Vector3(0, 0.6 + rng.randf() * 0.8, 0)
		it.launch(Vector3(rng.randf_range(-2, 2), rng.randf_range(2, 5), rng.randf_range(-2, 2)), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)))
	await _measure("40 objetos rebotando")
	get_tree().quit()

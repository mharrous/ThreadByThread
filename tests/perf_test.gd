extends Node
## Mide rendimiento con 150 objetos (necesita ventana). Sin VSync para ver el límite real:
##   godot --path . --windowed --resolution 1920x1080 --disable-vsync res://tests/perf_test.tscn -- --test-mode
## Imprime FPS medios, percentil 95 del tiempo de frame y llamadas de dibujo por escena.

const SAMPLE_FRAMES := 240

const SCENES := [
	{"name": "entrada (vista general)", "pos": Vector3(0, 0, 1.9), "look": Vector3(0, 1.1, -2.5)},
	{"name": "estanterías (cerca)", "pos": Vector3(-0.3, 0, -0.7), "look": Vector3(-1.2, 1.0, -2.3)},
	{"name": "ventana y paisaje", "pos": Vector3(-1.5, 0, -0.5), "look": Vector3(-20.0, 2.6, 6.0)},
	{"name": "suelo lleno de ovillos", "pos": Vector3(0.5, 0, 0.5), "look": Vector3(-1.5, 0.0, 1.2)},
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
	print("%-28s fps=%6.1f  frame medio=%5.2f ms  p95=%5.2f ms  peor=%5.2f ms  draw calls=%d" % [
		label, 1000.0 / avg_ms, avg_ms, p95_ms, worst_ms, calls])


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 90:
		await get_tree().process_frame
	var player: Player = main.get_node("Player")
	var room: RoomController = main.get_node("Room")
	print("== Rendimiento · %d objetos · ventana %s ==" % [room.total_items, str(get_window().size)])
	for s: Dictionary in SCENES:
		player.teleport(s["pos"])
		player.look_at_point(s["look"])
		for i in 20:
			await get_tree().process_frame
		await _measure(s["name"])

	# Lluvia de ovillos: 40 objetos simulándose a la vez.
	var items := room.get_items()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		var it: PickableItem = items[i]
		it.global_position += Vector3(0, 0.6 + rng.randf() * 0.8, 0)
		it.launch(Vector3(rng.randf_range(-2, 2), rng.randf_range(2, 5), rng.randf_range(-2, 2)), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)))
	player.teleport(Vector3(0.5, 0, 1.9))
	player.look_at_point(Vector3(0, 0.3, 0.2))
	await _measure("40 ovillos rebotando")
	await _measure("(los mismos, asentándose)")
	get_tree().quit()

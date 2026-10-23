extends Node
## Mide rendimiento con TODA la mercería cargada (necesita ventana). Sin VSync para ver el límite real:
##   godot --path . --windowed --resolution 1920x1080 --disable-vsync res://tests/perf_test.tscn -- --test-mode --no-vsync
## Imprime FPS medios, percentil 95 del tiempo de frame y llamadas de dibujo por escena.

const SAMPLE_FRAMES := 240

const VIEWS := [
	{"name": "entrada (toda la sala)", "pos": Vector3(0, 0, 2.9), "look": Vector3(0, 1.0, -4.5)},
	{"name": "centro hacia el norte", "pos": Vector3(0, 0, 0.3), "look": Vector3(-1.5, 1.0, -4.5)},
	{"name": "esquina sureste (peor caso)", "pos": Vector3(4.6, 0, 2.6), "look": Vector3(-5.5, 0.6, -3.5)},
	{"name": "suelo con montones", "pos": Vector3(0.5, 0, 0.5), "look": Vector3(-1.5, 0.0, 1.8)},
	{"name": "ventana a la calle", "pos": Vector3(-4.0, 0, 0.0), "look": Vector3(-12.0, 1.2, 0.0)},
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
	# --low: mide con "Iluminación avanzada" apagada (modo para equipos modestos).
	if OS.get_cmdline_user_args().has("--low"):
		GameSettings.high_quality = false
		GameSettings.notify_changed()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 90:
		await get_tree().process_frame
	var player: Player = main.get_node("Player")
	var shop: Shop = main.get_node("Shop")
	var room := shop.room
	print("== Rendimiento · %d objetos en una sala · ventana %s ==" % [room.total_items, str(get_window().size)])
	for v: Dictionary in VIEWS:
		player.teleport(room.to_global(v["pos"]))
		player.look_at_point(room.to_global(v["look"]))
		for i in 25:
			await get_tree().process_frame
		await _measure(v["name"])

	# 40 objetos rebotando a la vez.
	player.teleport(room.to_global(Vector3(0.5, 0, 2.9)))
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

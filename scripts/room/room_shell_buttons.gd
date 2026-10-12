class_name RoomShellButtons
extends RoomShell
## Sala 2: carretes de hilo y botones. Dos mesas con bandejas de celdas para los botones,
## dos estanterías de carretes en la pared norte y ventana al jardín (sur).

const TABLE_CENTERS: Array[Vector2] = [Vector2(-1.4, 0.95), Vector2(1.45, 0.95)]


func _build_furniture() -> void:
	_add_rug(Vector3(0.0, 0.0, 0.9))
	for c in TABLE_CENTERS:
		# Zonas libres de la mesa (delante y detrás de la bandeja) para los botones sueltos.
		var spawn: Array[Rect2] = [
			Rect2(c.x - 0.55, c.y - 0.5, 1.1, 0.26),
			Rect2(c.x - 0.55, c.y + 0.24, 1.1, 0.26),
		]
		_add_table(c, spawn)
	_add_crate(Vector3(2.65, 0, -1.9), 0.1)
	_add_crate(Vector3(-2.62, 0, -1.92), -0.15)
	_add_plant(Vector3(2.65, 0, 2.1))
	_add_plant(Vector3(-2.65, 0, 2.1))
	_add_picture(ROOM_W * 0.5, 0.9, 1.8, 0.5, 0.4, Color("f3c98b"), Color("e08a5c"), Color("8e3b46"))
	_add_picture(ROOM_W * 0.5, 1.7, 1.75, 0.34, 0.46, Color("a8d5ba"), Color("5fa37b"), Color("2f5e4a"))
	_add_clock(-ROOM_W * 0.5, 1.8, 2.15)
	_scatter_scraps(24)

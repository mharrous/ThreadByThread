class_name RoomShellStore
extends RoomShell
## Sala 4: almacén de sastrería. Panel de ganchos y estantería en el norte, mesa central con
## bandeja de piezas pequeñas, cajas y cajones por todas partes.


func _build_furniture() -> void:
	_add_rug(Vector3(0.0, 0.0, 1.0))
	var c := Vector2(0.0, 1.0)
	# Zonas libres de la mesa, alrededor de la bandeja.
	var spawn: Array[Rect2] = [
		Rect2(c.x - 0.55, c.y - 0.5, 1.1, 0.26),
		Rect2(c.x - 0.55, c.y + 0.24, 1.1, 0.26),
	]
	_add_table(c, spawn)
	_add_crate(Vector3(2.65, 0, -1.9), 0.1)
	_add_crate(Vector3(-2.62, 0, -1.92), -0.15)
	_add_crate(Vector3(2.6, 0, 1.0), 1.57)
	_add_crate(Vector3(2.6, 0, 1.7), 1.6)
	_add_cardboard_boxes(Vector3(-2.6, 0.0, 2.0))
	_add_plant(Vector3(2.65, 0, 2.15))
	_add_picture(ROOM_W * 0.5, -0.2, 1.8, 0.42, 0.32, Color("2f4f7a"), Color("a0522d"), Color("e0824a"))
	_add_clock(-ROOM_W * 0.5, 1.2, 2.2)
	# Tesoros escondidos: encima de la estantería y en lo alto de las cajas de cartón.
	treasure_spots.append(Vector3(1.2, 1.92, -2.16))
	treasure_spots.append(Vector3(-2.58, 0.76, 2.02))
	_scatter_scraps(40)

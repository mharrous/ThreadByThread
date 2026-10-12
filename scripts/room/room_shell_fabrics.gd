class_name RoomShellFabrics
extends RoomShell
## Sala 3: telas y cintas. Mesa de corte central, bastidores de rollos en el norte, un mueble
## de telas dobladas en la pared oeste y otro de cintas en la este.


func _build_furniture() -> void:
	_add_rug(Vector3(0.0, 0.0, 0.8))
	# Mesa de corte: se pueden dejar piezas sobre ella.
	_add_table(Vector2(0.0, 0.9))
	_add_crate(Vector3(2.65, 0, -1.9), 0.05)
	_add_crate(Vector3(-2.62, 0, -1.92), -0.1)
	_add_plant(Vector3(0.0, 0, 2.15))
	# Los muebles laterales ocupan sitio en el suelo.
	blocked_rects.append(Rect2(-3.0, 0.2, 0.7, 2.4))
	blocked_rects.append(Rect2(2.4, 0.2, 0.7, 2.4))
	_add_picture(ROOM_W * 0.5, -2.0, 1.9, 0.34, 0.46, Color("f3b6c8"), Color("e58f9f"), Color("f7e6c4"))
	_add_clock(-ROOM_W * 0.5, -2.0, 2.15)
	# Tesoros escondidos: encima del bastidor derecho y sobre el cajón de la esquina.
	treasure_spots.append(Vector3(1.2, 1.92, -2.08))
	treasure_spots.append(Vector3(-2.62, 0.32, -1.92))
	_scatter_scraps(60)

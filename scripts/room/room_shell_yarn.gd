class_name RoomShellYarn
extends RoomShell
## Sala 1: ovillos de lana. Ventana a la calle (oeste), mesa, cajones, cajas de cartón y planta.


func _build_furniture() -> void:
	_add_rug(Vector3(-0.2, 0.0, 0.75))
	_add_table(Vector2(2.175, 0.8))
	_add_crate(Vector3(2.65, 0, -1.9), 0.1)
	_add_crate(Vector3(-2.62, 0, -1.92), -0.15)
	_add_cardboard_boxes(Vector3(-2.6, 0.0, 2.0))
	_add_plant(Vector3(2.65, 0, 2.1))
	# Cuadros sobre la mesa y reloj sobre el cajón: personalidad.
	_add_picture(ROOM_W * 0.5, 0.55, 1.75, 0.5, 0.4, Color("8ec5e8"), Color("7fb069"), Color("e9d38a"))
	_add_picture(ROOM_W * 0.5, 1.25, 1.9, 0.34, 0.46, Color("f3b6c8"), Color("e58f9f"), Color("f7e6c4"))
	_add_picture(ROOM_W * 0.5, 1.95, 1.7, 0.42, 0.32, Color("2f4f7a"), Color("a0522d"), Color("e0824a"))
	_add_clock(ROOM_W * 0.5, -2.0, 2.15)
	_scatter_scraps()

class_name RoomShellShop
extends RoomShell
## La mercería entera en una sola sala de 12 × 9 m. Cada pared es de una familia:
##   norte  lanas (oeste) y carretes (este), con el cartel principal en medio
##   este   sastrería (panel de ganchos y estantería)
##   sur    telas y cintas, ventana al jardín y repisa de tesoros
##   oeste  ventana a la calle y el mueble de telas dobladas
## Las mesas del centro tienen las bandejas de botones y de piezas pequeñas; el resto del suelo es
## para los montones de objetos desordenados. Los muebles donde se ordena están en la escena
## (shop_floor.tscn), dentro de su sección; aquí solo va el mobiliario fijo.


func _build_furniture() -> void:
	var hw := room_w * 0.5
	_add_rug(Vector3(0.0, 0.0, 0.6), Vector2(4.6, 3.2))
	# Mesas: lanas y botones (delante de la pared norte), piezas de sastrería (este) y corte de telas (sur-oeste).
	_add_table(Vector2(-3.4, -1.7))
	for c: Vector2 in [Vector2(1.6, -1.7), Vector2(3.8, -1.7), Vector2(3.6, 1.4)]:
		# Zonas libres de la mesa (delante y detrás de la bandeja) para los objetos sueltos.
		var spawn: Array[Rect2] = [
			Rect2(c.x - 0.55, c.y - 0.5, 1.1, 0.26),
			Rect2(c.x - 0.55, c.y + 0.24, 1.1, 0.26),
		]
		_add_table(c, spawn)
	_add_table(Vector2(-3.0, 1.9))
	# Rincones: cajas de cartón (noroeste y sureste), cajón (noreste) y planta en el centro de la pared norte.
	_add_cardboard_boxes(Vector3(-5.45, 0.0, -3.3))
	_add_cardboard_boxes(Vector3(5.4, 0.0, 3.85))
	_add_crate(Vector3(5.45, 0, -4.0), 0.1)
	_add_plant(Vector3(0.0, 0, -4.05))
	_add_picture(hw, 2.6, 1.75, 0.5, 0.4, Color("8ec5e8"), Color("7fb069"), Color("e9d38a"))
	_add_picture(-hw, -2.3, 2.0, 0.34, 0.46, Color("f3b6c8"), Color("e58f9f"), Color("f7e6c4"))
	_add_picture(-hw, 1.4, 2.35, 0.42, 0.32, Color("2f4f7a"), Color("a0522d"), Color("e0824a"))
	_add_clock(-hw, -3.6, 2.3)
	# Tesoros escondidos, dos por sección y en el orden de las secciones (lanas, botones, telas, sastrería):
	# encima de las estanterías altas, de los cajones y de las pilas de cajas.
	treasure_spots.append(Vector3(-1.25, 1.92, -4.3))     # lanas: encima de la segunda estantería de ovillos
	treasure_spots.append(Vector3(-5.43, 0.76, -3.28))    # lanas: sobre las cajas del rincón noroeste
	treasure_spots.append(Vector3(4.0, 1.92, -4.3))       # botones: encima de la segunda estantería de carretes
	treasure_spots.append(Vector3(5.45, 0.32, -4.0))      # botones: sobre el cajón del rincón noreste
	treasure_spots.append(Vector3(-4.5, 1.92, 4.3))       # telas: encima del primer bastidor de rollos
	treasure_spots.append(Vector3(-5.8, 1.92, 2.9))       # telas: encima del mueble de telas dobladas
	treasure_spots.append(Vector3(5.42, 0.76, 3.87))      # sastrería: sobre las cajas del rincón sureste
	treasure_spots.append(Vector3(5.8, 1.92, 0.8))        # sastrería: encima de su estantería
	_scatter_scraps(110)

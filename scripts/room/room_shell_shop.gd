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
	# Mesa del rincón de lanas, con la caja registradora en la esquina del fondo.
	var yarn_t := Vector2(-3.4, -1.7)
	_add_table(yarn_t, [Rect2(yarn_t.x - 0.15, yarn_t.y - 0.5, 0.7, 1.0), Rect2(yarn_t.x - 0.57, yarn_t.y + 0.05, 0.4, 0.45)])
	_add_prop("res://art/models/cash_register.glb", Vector3(yarn_t.x - 0.36, 0.76, yarn_t.y - 0.3), 0.35, Vector3(0.4, 0.4, 0.36))
	for c: Vector2 in [Vector2(1.6, -1.7), Vector2(3.8, -1.7), Vector2(3.6, 1.4)]:
		# Zonas libres de la mesa (delante y detrás de la bandeja) para los objetos sueltos.
		var spawn: Array[Rect2] = [
			Rect2(c.x - 0.55, c.y - 0.5, 1.1, 0.26),
			Rect2(c.x - 0.55, c.y + 0.24, 1.1, 0.26),
		]
		_add_table(c, spawn)
	# Mesa de corte con la máquina de coser al fondo; las telas caen en la mitad delantera.
	var cut_t := Vector2(-3.0, 1.9)
	_add_table(cut_t, [Rect2(cut_t.x - 0.57, cut_t.y - 0.05, 1.14, 0.55)])
	_add_prop("res://art/models/sewing_machine.glb", Vector3(cut_t.x, 0.76, cut_t.y - 0.3), 0.0, Vector3(0.44, 0.32, 0.2))
	# Maniquí en el rincón suroeste y puerta de la calle en la pared este (decorativa).
	_add_prop("res://art/models/dress_form.glb", Vector3(-5.6, 0.0, 3.95), 0.6, Vector3(0.36, 1.5, 0.3))
	blocked_rects.append(Rect2(-5.95, 3.6, 0.7, 0.75))
	_add_shop_door(Vector3(hw, 0.0, 2.2))
	# Rincones: cajas de cartón (noroeste y sureste), cajón (noreste) y planta en el centro de la pared norte.
	_add_cardboard_boxes(Vector3(-5.45, 0.0, -3.3))
	_add_cardboard_boxes(Vector3(5.4, 0.0, 3.85))
	_add_crate(Vector3(5.45, 0, -4.0), 0.1)
	_add_plant(Vector3(0.0, 0, -4.05))
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


## Premios de sección (Blender): ocultos hasta completar la sección, que los desbloquea con su id.
## Gato dormido junto a la ventana (lanas), radio y jarrón en la mesa de corte (botones, telas) y
## juego de té en el alféizar de la ventana sur (sastrería).
const REWARDS := [
	[&"yarn", "res://art/models/cat_basket.glb", Vector3(-5.45, 0.0, -1.25), PI * 0.5, Vector3(0.56, 0.26, 0.56)],
	[&"buttons", "res://art/models/radio.glb", Vector3(-2.55, 0.76, 1.6), PI, Vector3(0.32, 0.22, 0.17)],
	[&"fabrics", "res://art/models/flower_vase.glb", Vector3(-3.5, 0.76, 1.58), 0.0, Vector3(0.14, 0.4, 0.14)],
	[&"store", "res://art/models/tea_set.glb", Vector3(2.4, 0.94, 4.43), PI, Vector3(0.26, 0.15, 0.28)],
]


func _build_decor() -> void:
	super()
	for r: Array in REWARDS:
		if not ResourceLoader.exists(r[1]):
			push_warning("Falta el modelo %s (ejecuta art/blender/make_props.py)" % r[1])
			continue
		var root := Node3D.new()
		root.name = "Reward_" + String(r[0])
		root.position = r[2]
		root.rotation.y = r[3]
		root.add_child((load(r[1]) as PackedScene).instantiate())
		add_decor_body(root, r[4], Vector3(0.0, r[4].y * 0.5, 0.0))
		add_decor(r[0], root)
		# Que no caigan objetos donde aparecerá el premio del suelo.
		if r[2].y < 0.1:
			blocked_rects.append(Rect2(r[2].x - r[4].x * 0.5, r[2].z - r[4].z * 0.5, r[4].x, r[4].z))


## Atrezo de Blender con su caja de colisión (para que los objetos no lo atraviesen al caer o dejarlos).
func _add_prop(path: String, base: Vector3, yaw: float, box: Vector3) -> void:
	_instance_model(path, base, yaw)
	_static_box(box, base + Vector3(0.0, box.y * 0.5, 0.0), yaw)


## Puerta de entrada (no se abre) con el cartel de CERRADO/ABIERTO colgado tras el cristal.
func _add_shop_door(at_wall: Vector3) -> void:
	_instance_model("res://art/models/shop_door.glb", at_wall, -PI * 0.5)
	door_sign = Label3D.new()
	door_sign.text = "CERRADO"
	door_sign.font_size = 64
	door_sign.pixel_size = 0.0022
	door_sign.outline_size = 8
	door_sign.outline_modulate = Color("f6ecd8")
	door_sign.modulate = Color("8e3b46")
	door_sign.rotation.y = -PI * 0.5
	door_sign.position = at_wall + Vector3(-0.045, 1.5, 0.0)
	add_child(door_sign)

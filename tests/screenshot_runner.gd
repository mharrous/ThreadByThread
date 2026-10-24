extends Node
## Captura imágenes del juego (necesita ventana, no headless).
##   godot --path . res://tests/screenshot_runner.tscn -- --out=<carpeta> --test-mode --no-autopause [--filled]
## Vistas de la mercería: entrada, cada pared y el suelo. Con --filled primero coloca todos
## los objetos de golpe (sin animar) para ver los contenedores llenos.

const POSES := [
	{"name": "entrada", "pos": Vector3(0, 0, 2.9), "look": Vector3(0, 1.1, -4.5)},
	{"name": "norte_lanas", "pos": Vector3(-2.6, 0, -2.4), "look": Vector3(-2.6, 1.0, -4.5)},
	{"name": "norte_carretes", "pos": Vector3(2.6, 0, -2.4), "look": Vector3(2.6, 1.0, -4.5)},
	{"name": "este_sastreria", "pos": Vector3(2.6, 0, -0.4), "look": Vector3(6.0, 1.2, -0.7)},
	{"name": "sur_telas", "pos": Vector3(-1.6, 0, 1.0), "look": Vector3(-2.0, 1.0, 4.5)},
	{"name": "oeste_ventana", "pos": Vector3(-2.4, 0, 0.8), "look": Vector3(-6.0, 1.2, 1.4)},
	{"name": "suelo", "pos": Vector3(2.0, 0, 2.6), "look": Vector3(-1.5, 0.0, 0.0)},
	{"name": "esquina", "pos": Vector3(4.6, 0, 2.6), "look": Vector3(-5.5, 0.6, -3.5)},
]
## Premios de sección (solo con --filled, cuando ya han aparecido).
const REWARD_POSES := [
	{"name": "premio_gato", "pos": Vector3(-4.2, 0, -0.5), "look": Vector3(-5.45, 0.1, -1.25)},
	{"name": "premio_mesa_corte", "pos": Vector3(-3.0, 0, 0.5), "look": Vector3(-3.0, 0.8, 1.6)},
	{"name": "premio_te", "pos": Vector3(2.0, 0, 3.2), "look": Vector3(2.4, 0.95, 4.39)},
	# Bandejas de cerca (con --filled): si lo de dentro toca el fondo y si las etiquetas caben.
	{"name": "bandeja_botones", "pos": Vector3(1.6, 0, -0.95), "look": Vector3(1.6, 0.78, -1.7)},
	{"name": "bandeja_sastreria", "pos": Vector3(3.6, 0, 2.15), "look": Vector3(3.6, 0.78, 1.4)},
]

var _out_dir := ""
var _filled := false
var _treasures := false  # --treasures: tesoros escondidos, repisa con los hallados y guirnaldas
var _book := false      # --book: libro de colecciones del menú de pausa
var _opening := false  # --opening: escena de apertura de la tienda y pantalla final
var _hud := false      # --hud: la interfaz con todo a la vez (racha, aviso, tutorial, indicador) para ver solapes
var _customer := false  # --customer: la clienta de la apertura (quieta, andando, mirando) y su esqueleto
var _cat := false       # --cat: el gato en cada pose (de lado y de frente), el zarpazo y la caricia
var _sweep := false     # --sweep: barrer en primera persona (coger, barrer, recogedor lleno, vaciar)
var _access := false    # --access: menú de pausa y HUD con el texto a ×1,5 y colores para daltonismo
var _menu := false      # --menu (con --show-title): la pantalla de título en español e inglés y los ajustes
var _boxes := false     # --boxes: cajas de cartón (tiradas, aplanar, llevar, montón y atadas)
var _top := false       # --top: planta de la sala desde arriba (cámara ortográfica) para colocar cosas
var _signs := false     # --signs: los carteles de cerca (principal, secciones, puerta girando, montón de cartón)
var _street := false    # --street: solo fotografía la vista de la ventana con cada tipo de suceso de la calle


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg == "--filled":
			_filled = true
		elif arg == "--street":
			_street = true
		elif arg == "--book":
			_book = true
		elif arg == "--treasures":
			_treasures = true
		elif arg == "--opening":
			_opening = true
		elif arg == "--customer":
			_customer = true
		elif arg == "--cat":
			_cat = true
		elif arg == "--sweep":
			_sweep = true
		elif arg == "--access":
			_access = true
		elif arg == "--hud":
			_hud = true
		elif arg == "--top":
			_top = true
		elif arg == "--boxes":
			_boxes = true
		elif arg == "--menu":
			_menu = true
		elif arg == "--signs":
			_signs = true
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	print("captura ", path, " -> ", error_string(err))


func _fill_room(room: RoomController) -> void:
	for it in room.get_items():
		var found := room.find_row(it.data.sort_key)
		if found.is_empty():
			continue
		var unit: StorageUnit = found["unit"]
		var row: int = found["row"]
		var slot := unit.first_free_slot(row)
		if slot < 0:
			continue
		unit.reserve(row, slot, it)
		it.container = unit
		it.slot_row = row
		it.slot_index = slot
		it.state = PickableItem.State.PLACED
		it.global_transform = unit.slot_transform(row, slot, it)


func _look_from(player: Player, room: RoomController, stand: Vector3, at: Vector3) -> void:
	player.teleport(room.to_global(stand))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(room.to_global(at))
	for i in 12:
		await get_tree().process_frame


## Cada escondite de tesoro (sin hallar), luego la repisa con todos los hallados y las guirnaldas.
func _run_treasures(shop: Shop, player: Player) -> void:
	var room := shop.room
	for i in room.shell.treasure_spots.size():
		var spot := room.shell.treasure_spots[i]
		var inward := -Vector3(spot.x, 0.0, spot.z).normalized()
		await _look_from(player, room, Vector3(spot.x, 0.0, spot.z) + inward * 1.6, spot + Vector3(0, 0.1, 0))
		await _shot("tesoro_escondido_%d" % (i + 1))
	for data in room._treasure_list:
		room._restore_treasure(data.id)
	for section in room.sections:
		section.show_completed(false)
	room.shell.unlock_decor(&"bunting", false)
	room.shell.unlock_decor(&"open_sign", false)
	room.shell.open_shop(false)
	await _look_from(player, room, Vector3(3.6, 0.0, 2.6), Vector3(4.6, 1.55, 4.4))
	await _shot("repisa")
	await _look_from(player, room, Vector3(0.0, 0.0, 3.4), Vector3(0.0, 2.4, -3.0))
	await _shot("guirnaldas_y_abierto")
	await _look_from(player, room, Vector3(3.0, 0.0, -0.6), Vector3(6.0, 2.4, -0.7))
	await _shot("cartel_seccion_completa")


## Vista de la ventana: primero la calle vacía y luego cada tipo de suceso congelado delante de la ventana.
func _run_street(main: Node, player: Player) -> void:
	var landscape := main.get_node("World/Landscape") as Landscape
	var life := landscape.get_street_life()
	life.enabled = false
	# La ventana oeste está en x = -6 (el paisaje va desplazado 3 m al oeste).
	player.teleport(Vector3(-5.3, 0.0, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.look_at_point(Vector3(-15.0, 1.5, 0.0))
	for i in 10:
		await get_tree().process_frame
	await _shot("ventana_vacia")
	player.look_at_point(Vector3(-15.0, 1.9, 6.0))
	for i in 6:
		await get_tree().process_frame
	await _shot("ventana_lado")
	player.look_at_point(Vector3(-15.0, 1.5, 0.0))
	for kind: StringName in [&"car", &"van", &"bike", &"moto", &"walker", &"dogwalker"]:
		var actor := life.spawn(kind)
		# Se lleva al centro de la ventana y se avanza el paso a mano; luego se congela para la foto.
		# Termina a 2 m del centro de la ventana (a la derecha): el montante no tapa el motivo.
		actor.position.z = -2.0 - actor.velocity.z * 0.96
		for i in 8:
			actor._process(0.12)
		actor.set_process(false)
		for i in 6:
			await get_tree().process_frame
		await _shot("ventana_%s" % kind)
		actor.queue_free()
		life._actors.erase(actor)
	# Ventana sur: el jardín trasero.
	var shop := main.get_node("Shop") as Shop
	for x in shop.room.shell.south_windows:
		await _look_from(player, shop.room, Vector3(x, 0.0, 2.8), Vector3(x, 1.55, 10.0))
		await _shot("ventana_sur")
	await _street_people_closeup(shop.room, life, player)
	print("rendimiento: fps=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


## Los peatones de la calle y el perro de cerca, dentro de la tienda junto a la clienta, para comparar
## el estilo: quietos a media zancada, de frente, de tres cuartos y de perfil.
func _street_people_closeup(room: RoomController, life: StreetLife, player: Player) -> void:
	var c := Customer.new()
	room.add_child(c)
	c.position = Vector3(0.0, 0.0, 0.6)
	var actors: Array[StreetActor] = []
	for kind: StringName in [&"walker", &"dogwalker"]:
		var actor := life.spawn(kind)
		actor.set_process(false)
		actor.global_position = room.to_global(Vector3(-0.9 if kind == &"walker" else 1.0, 0.0, 0.6))
		actor.global_rotation = Vector3.ZERO
		actors.append(actor)
	await get_tree().process_frame
	for actor in actors:
		for r in actor.rigs:
			var p: AnimationPlayer = r["player"]
			p.seek(p.current_animation_length * 0.25, true)
			p.pause()
	await _look_from(player, room, Vector3(0.0, 0.0, 3.4), Vector3(0.0, 0.9, 0.6))
	await get_tree().create_timer(0.3).timeout
	await _shot("peatones_frente")
	await _look_from(player, room, Vector3(2.4, 0.0, 2.8), Vector3(0.0, 0.9, 0.6))
	await _shot("peatones_tres_cuartos")
	for actor in actors:
		actor.global_rotation.y = PI * 0.5
	c.rotation.y = PI * 0.5
	await _look_from(player, room, Vector3(0.0, 0.0, 3.4), Vector3(0.0, 0.9, 0.6))
	await get_tree().create_timer(0.2).timeout
	await _shot("peatones_perfil")
	for actor in actors:
		actor.queue_free()
		life._actors.erase(actor)
	c.queue_free()


func _run_customer(shop: Shop, player: Player) -> void:
	var room := shop.room
	var c := Customer.new()
	room.add_child(c)
	c.position = Vector3(0.0, 0.0, 0.6)
	await _look_from(player, room, Vector3(0.0, 0.0, 2.6), Vector3(0.0, 1.0, 0.6))
	await get_tree().create_timer(0.5).timeout
	await _shot("clienta_frente")
	c.rotation.y = PI * 0.5
	await _shot("clienta_perfil")
	c.velocity = Vector3(0.001, 0, 0)
	c._play(&"walk", 1.0)
	c.velocity = Vector3.ZERO
	c.set_process(false)
	for t in [0.0, 0.17, 0.33, 0.5]:
		c._anim.seek(t, true)
		await _shot("clienta_paso_%d" % int(t * 100))
	c.rotation.y = 0.0
	c.set_process(true)
	c.look_around()
	await get_tree().create_timer(1.2).timeout
	await _shot("clienta_mira")
	await _look_from(player, room, Vector3(1.2, 0.0, 1.4), Vector3(0.0, 1.0, 0.6))
	await _shot("clienta_cesta")


## El gato quieto en cada pose (se le para la vida), de lado y de frente; luego suelto un rato.
func _run_cat(shop: Shop, player: Player) -> void:
	var room := shop.room
	var cat := room.shell.get_node("ShopCat") as ShopCat
	var at := Vector3(1.0, 0.0, 1.5)
	cat._gen += 1
	cat._move_to = Vector3.INF
	cat.position = at
	cat.rotation.y = PI * 0.5
	await _look_from(player, room, Vector3(1.05, 0.0, 2.55), at + Vector3(0.0, 0.2, 0.0))
	# Cámara de cerca, a la altura del gato.
	var close := Camera3D.new()
	close.fov = 40.0
	room.add_child(close)
	close.position = at + Vector3(0.0, 0.32, 1.25)
	close.look_at(room.to_global(at + Vector3(0.0, 0.2, 0.0)))
	close.make_current()
	await get_tree().create_timer(0.3).timeout
	cat._set_animating(true)
	for pose in [&"stand", &"walk", &"trot", &"sit", &"groom", &"sleep", &"pet", &"lie", &"roll", &"knead", &"gallop", &"stretch"]:
		cat._set_pose(pose)
		await get_tree().create_timer(0.9).timeout
		await _shot("gato_%s" % pose)
	cat.rotation.y = 0.0
	for pose in [&"stand", &"sit", &"pet"]:
		cat._set_pose(pose)
		await get_tree().create_timer(0.9).timeout
		await _shot("gato_frente_%s" % pose)
	cat._set_pose(&"sit")
	cat.rotation.y = PI * 0.5
	await get_tree().create_timer(0.6).timeout
	cat._tree.set(&"parameters/bat/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	await get_tree().create_timer(0.75).timeout
	await _shot("gato_zarpazo_arriba")
	await get_tree().create_timer(0.35).timeout
	await _shot("gato_zarpazo_golpe")
	cat.interact()
	await get_tree().create_timer(0.5).timeout
	await _shot("gato_caricia")
	close.position = at + Vector3(0.9, 0.5, 0.9)
	close.look_at(room.to_global(at + Vector3(0.0, 0.2, 0.0)))
	cat._set_pose(&"sit")
	await get_tree().create_timer(0.9).timeout
	await _shot("gato_tres_cuartos")
	close.queue_free()
	player.camera.make_current()
	cat._life()
	await get_tree().create_timer(14.0).timeout
	await _look_from(player, room, Vector3(0.0, 0.0, 2.9), room.to_local(cat.global_position) + Vector3(0, 0.2, 0))
	await _shot("gato_suelto")


## Barrer en primera persona: coger la escoba, barrer unos papelitos, el recogedor lleno y vaciarlo.
func _run_sweep(shop: Shop, player: Player) -> void:
	var room := shop.room
	var sweep := shop.floor_sweep()
	var holder := player.get_node("ItemHolder") as ItemHolder
	await _look_from(player, room, Vector3(3.9, 0.0, 2.9), ShopSweep.BROOM_REST + Vector3(-0.2, 0.6, 0.0))
	await _shot("barrer_1_herramientas")
	holder.sweeper.take(sweep)
	await get_tree().create_timer(0.8).timeout
	# Al papelito más cercano, mirando al suelo.
	var target := room.to_local(sweep.nearest_scrap(player.global_position))
	var feet := target + Vector3(0.0, 0.0, -1.0)
	await _look_from(player, room, feet, target)
	await get_tree().create_timer(0.5).timeout
	await _shot("barrer_2_en_mano")
	for k in 6:
		var t := room.to_local(sweep.nearest_scrap(player.global_position))
		await _look_from(player, room, t + (room.to_local(player.global_position) - t).normalized() * 1.0 * Vector3(1, 0, 1), t)
		holder.sweeper._stroke = 0.0
		holder.sweeper._stroke_hit_done = false
		await get_tree().create_timer(0.2).timeout
		if k == 0:
			await _shot("barrer_3_escobazo")
		await get_tree().create_timer(0.4).timeout
	await _shot("barrer_4_recogedor_%d" % sweep.pan_count())
	await _look_from(player, room, ShopSweep.BIN_AT + Vector3(-0.3, 0.0, -1.3), ShopSweep.BIN_AT + Vector3(0.0, ShopSweep.BIN_TOP, 0.0))
	await get_tree().create_timer(0.4).timeout
	await _shot("barrer_5_papelera")
	sweep.dump()
	await get_tree().create_timer(0.7).timeout
	await _shot("barrer_6_vaciar")
	await get_tree().create_timer(1.2).timeout
	holder.sweeper.put_back()
	await get_tree().create_timer(1.5).timeout
	await _look_from(player, room, Vector3(3.9, 0.0, 2.9), ShopSweep.BROOM_REST + Vector3(-0.2, 0.6, 0.0))
	await _shot("barrer_7_devuelta")


## Cajas de cartón: una tirada, aplanándose, el cartón en la mano, el montón y todas atadas.
func _run_boxes(shop: Shop, player: Player) -> void:
	var room := shop.room
	var boxes := shop.cardboard()
	var holder := player.get_node("ItemHolder") as ItemHolder
	var b := boxes.boxes[0]
	await _look_from(player, room, b.position + Vector3(0.3, 0.0, 1.6), b.position + Vector3(0, 0.2, 0))
	await _shot("cajas_1_tirada")
	var b4 := boxes.boxes[4]
	await _look_from(player, room, b4.position + Vector3(-1.4, 0.0, -0.6), b4.position + Vector3(0, 0.2, 0))
	await _shot("cajas_1b_tumbada")
	await _look_from(player, room, b.position + Vector3(0.3, 0.0, 1.6), b.position + Vector3(0, 0.2, 0))
	holder.carrier.take(b)
	await get_tree().create_timer(0.22).timeout
	await _shot("cajas_2_aplastando")
	await get_tree().create_timer(1.0).timeout
	await _shot("cajas_3_en_mano")
	await _look_from(player, room, ShopBoxes.PILE_AT + Vector3(-1.9, 0.0, -0.3), ShopBoxes.PILE_AT + Vector3(0, 0.4, 0))
	await get_tree().create_timer(0.4).timeout
	await _shot("cajas_4_al_monton")
	holder.carrier.click()
	await get_tree().create_timer(0.8).timeout
	await _shot("cajas_5_primera")
	for i in range(1, boxes.boxes.size()):
		boxes.boxes[i].flatten_instantly()
		boxes.boxes[i].set_stacked()
		boxes.boxes[i].transform = boxes.pile_slot(i, boxes.boxes[i])
	boxes._tie(true)
	await get_tree().create_timer(0.8).timeout
	await _shot("cajas_6_atadas")
	await _look_from(player, room, ShopBoxes.PILE_AT + Vector3(-1.2, 0.0, 0.9), ShopBoxes.PILE_AT + Vector3(0, 0.35, 0))
	await _shot("cajas_7_lado")


## Carteles de cerca, con una cámara suelta: la pared norte entera, el principal, cada sección, la placa
## de la puerta (cerrada, girando y abierta), la tablilla del montón de cartón y el premio de ¡ABIERTO!.
func _run_signs(shop: Shop, player: Player) -> void:
	var room := shop.room
	var shell := room.shell
	var cam := Camera3D.new()
	cam.fov = 55.0
	room.add_child(cam)
	cam.make_current()
	var frame := func(from: Vector3, at: Vector3) -> void:
		cam.position = from
		cam.look_at(room.to_global(at))
	frame.call(Vector3(0.0, 1.7, 0.2), Vector3(0.0, 2.3, -4.5))
	await get_tree().create_timer(0.5).timeout
	await _shot("carteles_1_norte")
	frame.call(Vector3(-0.3, 2.1, -2.2), Vector3(0.0, 2.45, -4.5))
	await _shot("carteles_2_principal")
	for section in room.sections:
		var sign := section.get_node("Sign") as Node3D
		var p := room.to_local(sign.global_position)
		var out := room.global_basis.inverse() * sign.global_basis.z
		frame.call(p + out * 1.7 + Vector3(0.0, -0.25, 0.0), p)
		await get_tree().create_timer(0.2).timeout
		await _shot("carteles_3_seccion_%s" % section.section_id)
	var door := room.to_local(shell.door_sign.global_position) + Vector3(0.0, DoorSign.PLATE_Y, 0.0)
	frame.call(door + Vector3(-0.85, -0.12, 0.35), door)
	await get_tree().create_timer(0.2).timeout
	await _shot("carteles_4_puerta_cerrado")
	shell.door_sign.set_open(true, true)
	await get_tree().create_timer(0.3).timeout
	await _shot("carteles_5_puerta_girando")
	await get_tree().create_timer(2.0).timeout
	await _shot("carteles_6_puerta_abierto")
	var pile := ShopBoxes.PILE_AT + Vector3(0.0, 1.15, 0.0)
	frame.call(pile + Vector3(-1.0, -0.1, -0.35), pile)
	await get_tree().create_timer(0.2).timeout
	await _shot("carteles_7_carton")
	shell.unlock_decor(&"open_sign", false)
	room.sections[0].show_completed(false)
	frame.call(Vector3(-0.8, 1.9, -1.9), Vector3(-0.6, 2.2, -4.5))
	await get_tree().create_timer(0.3).timeout
	await _shot("carteles_8_abierto_y_completa")
	cam.queue_free()
	player.camera.make_current()


func _run_opening(main: Node, shop: Shop, player: Player) -> void:
	var opening := main.get_node("ShopOpening") as ShopOpening
	player.teleport(shop.room.to_global(Vector3(1.6, 0.0, -0.6)))
	player.look_at_point(shop.room.to_global(Vector3(6.0, 1.3, 2.2)))
	shop.floor_sweep().finish_instantly()
	# Sin las cajas en el montón la apertura no empieza.
	shop.cardboard().finish_instantly()
	shop.room.solve_instantly()
	for s in [[&"door", 2.6, "apertura_1_puerta"], [&"enter", 1.6, "apertura_2_letrero"], [&"look", 1.8, "apertura_3_cliente"]]:
		while opening.step != s[0]:
			await get_tree().process_frame
		await get_tree().create_timer(s[1]).timeout
		await _shot(s[2])
	while not opening.is_end_screen_open():
		await get_tree().process_frame
	await get_tree().create_timer(4.5).timeout
	await _shot("apertura_4_final")
	opening._end._on_continue()
	await get_tree().create_timer(2.5).timeout
	await _shot("apertura_5_seguir")


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 30:
		await get_tree().process_frame
	var shop: Shop = main.get_node("Shop")
	var player: Player = main.get_node("Player")
	if _menu:
		var title := main.get_node_or_null("TitleScreen")
		await get_tree().create_timer(3.8).timeout
		await _shot("menu_titulo_es")
		GameSettings.language = "en"
		GameSettings.apply_language()
		GameSettings.changed.emit()
		await get_tree().create_timer(0.6).timeout
		await _shot("menu_titulo_en")
		if title != null:
			title._open_settings()
			await get_tree().create_timer(0.6).timeout
			await _shot("menu_ajustes_en")
			var menu := get_tree().get_first_node_in_group(&"pause_menu")
			if menu == null:
				menu = main.find_child("PauseMenu", true, false)
			if menu != null:
				menu._show_controls(true)
				await get_tree().create_timer(0.4).timeout
				await _shot("menu_controles_en")
				GameSettings.language = "es"
				GameSettings.apply_language()
				await get_tree().create_timer(0.4).timeout
				await _shot("menu_controles_es")
		GameSettings.language = "es"
		GameSettings.apply_language()
		get_tree().quit()
		return
	if _boxes:
		await _run_boxes(shop, player)
		get_tree().quit()
		return
	if _signs:
		await _run_signs(shop, player)
		get_tree().quit()
		return
	if _top:
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 9.6
		cam.near = 0.05
		shop.room.add_child(cam)
		cam.position = Vector3(0.0, 2.35, 0.0)
		cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		cam.make_current()
		for i in 20:
			await get_tree().process_frame
		await _shot("planta")
		get_tree().quit()
		return
	if _street:
		await _run_street(main, player)
		get_tree().quit()
		return
	if _customer:
		await _run_customer(shop, player)
		get_tree().quit()
		return
	if _cat:
		await _run_cat(shop, player)
		get_tree().quit()
		return
	if _sweep:
		await _run_sweep(shop, player)
		get_tree().quit()
		return
	if _access:
		GameSettings.text_scale = 1.5
		GameSettings.colorblind = true
		GameSettings.notify_changed()
		var menu := main.get_node("PauseMenu")
		menu.open()
		await get_tree().create_timer(0.5).timeout
		await _shot("accesibilidad_menu")
		menu.close()
		await _look_from(player, shop.room, Vector3(0, 0, 2.9), Vector3(0, 0.4, 0.6))
		Events.streak_changed.emit(12)
		await get_tree().create_timer(0.5).timeout
		await _shot("accesibilidad_hud")
		GameSettings.text_scale = 1.0
		GameSettings.colorblind = false
		GameSettings.save_settings()
		get_tree().quit()
		return
	if _hud:
		await _look_from(player, shop.room, Vector3(0, 0, 2.9), Vector3(0, 0.4, 0.6))
		Events.streak_changed.emit(12)
		Events.hint_requested.emit("Partida guardada", 3.0)
		await get_tree().create_timer(0.6).timeout
		await _shot("hud_todo")
		get_tree().quit()
		return
	if _opening:
		await _run_opening(main, shop, player)
		get_tree().quit()
		return
	if _book:
		var room: RoomController = shop.room
		room._restore_treasure(room._treasure_list[0].id)
		room._restore_treasure(room._treasure_list[3].id)
		# Para ver el libro con contenido: 100 objetos colocados y dos tesoros hallados.
		var placed_n := 0
		for it in room.get_items():
			var found := room.find_row(it.data.sort_key)
			if found.is_empty() or placed_n >= 100:
				continue
			var unit: StorageUnit = found["unit"]
			var row: int = found["row"]
			var slot := unit.first_free_slot(row)
			if slot < 0:
				continue
			unit.reserve(row, slot, it)
			it.container = unit
			it.slot_row = row
			it.slot_index = slot
			it.state = PickableItem.State.PLACED
			it.global_transform = unit.slot_transform(row, slot, it)
			Events.item_placed.emit(it, unit)
			placed_n += 1
		var menu := main.get_node("PauseMenu")
		menu.open()
		menu._show_book(true)
		for i in 12:
			await get_tree().process_frame
		await _shot("libro")
		var scroll := menu._book_content.get_parent() as ScrollContainer
		for pos in [560, 1120, 1680, 2240]:
			scroll.scroll_vertical = pos
			for i in 6:
				await get_tree().process_frame
			await _shot("libro_%d" % pos)
		menu._show_book(false)
		for i in 12:
			await get_tree().process_frame
		await _shot("menu")
		get_tree().quit()
		return
	if _treasures:
		await _run_treasures(shop, player)
		get_tree().quit()
		return
	var tag := "lleno" if _filled else "caos"
	var room := shop.room
	var poses: Array = POSES.duplicate()
	if _filled:
		_fill_room(room)
		for s in room.sections:
			room.shell.unlock_decor(s.section_id, false)
		poses.append_array(REWARD_POSES)
	for pose: Dictionary in poses:
		await _look_from(player, room, pose["pos"], pose["look"])
		await _shot("%s_%s" % [pose["name"], tag])
	print("rendimiento: fps=", Engine.get_frames_per_second(), " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()

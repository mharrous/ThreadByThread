extends Node
## Guardado y carga entre procesos distintos. Se ejecuta dos veces (ver run_persist.ps1):
##   --phase=write  coloca objetos, deja uno suelto en otro sitio, encuentra un tesoro, guarda y sale.
##   --phase=read   arranca de cero y comprueba que todo se ha restaurado (y borra el guardado de pruebas).
## Uso: godot --headless --path . res://tests/persist_test.tscn -- --test-mode --phase=write
## Código de salida 0 = todo correcto.

const EXPECT_PATH := "user://persist_expect_test.json"
const PLACED := 3
const COUNT := 2

var _failures := 0
var main: Node
var shop: Shop
var room: RoomController


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK    ", msg)
	else:
		_failures += 1
		print("  FALLO ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var phase := "write"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	print("== Guardado entre procesos · fase %s ==" % phase)
	if phase == "write":
		SaveGame.delete_save()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	shop = main.get_node("Shop")
	for r in shop.get_children():
		if r is RoomController:
			(r as RoomController).count_override = COUNT
	add_child(main)
	await _frames(20)
	room = shop.room
	if phase == "write":
		await _write()
	else:
		await _read()
	print("")
	print("RESULTADO: TODO CORRECTO" if _failures == 0 else "RESULTADO: %d FALLOS" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _write() -> void:
	var items := room.get_items()
	var expect := {"slots": [], "loose": {}}
	for i in PLACED:
		var it := items[i]
		var found := room.find_row(it.data.sort_key)
		var unit: StorageUnit = found["unit"]
		var row: int = found["row"]
		var slot := unit.first_free_slot(row)
		unit.reserve(row, slot, it)
		it.container = unit
		it.slot_row = row
		it.slot_index = slot
		it.state = PickableItem.State.PLACED
		it.global_transform = unit.slot_transform(row, slot, it)
		Events.item_placed.emit(it, unit)
		expect["slots"].append({"i": i, "u": room.get_units().find(unit), "r": row, "k": slot})
	_check(room.placed_items == PLACED, "colocados %d objetos" % PLACED)
	# Una sección entera completada (con el atajo): su premio debe seguir tras reiniciar.
	var last := room.sections.back() as ShopSection
	room.solve_instantly(last)
	await _frames(2)
	_check(last.is_completed and last.placed_items == last.total_items, "sección %s completada" % last.display_name)
	expect["placed"] = room.placed_items
	expect["section"] = String(last.section_id)

	# Un objeto suelto en un sitio reconocible.
	# El primero sin colocar a partir de PLACED + 2 (la sección completada ya ha colocado los suyos).
	var loose_i := PLACED + 2
	while items[loose_i].state == PickableItem.State.PLACED:
		loose_i += 1
	var loose := items[loose_i]
	var target := room.to_global(Vector3(-1.0, loose.half_height, 1.4))
	loose.global_position = target
	Events.item_set_down.emit(loose)
	var lp := room.to_local(loose.global_position)
	expect["loose"] = {"i": loose_i, "x": lp.x, "y": lp.y, "z": lp.z}

	# Un tesoro, recogido como lo hace el jugador.
	var holder: ItemHolder = main.get_node("Player/ItemHolder")
	var treasure: PickableItem = room._treasures[0]
	expect["treasure"] = String(treasure.data.id)
	holder._collect_treasure(treasure)
	await _frames(3)
	_check(room.treasures_found() == 1, "un tesoro encontrado")

	# Medio suelo barrido: unos papelitos en la papelera y otros en el recogedor.
	var sweep := shop.floor_sweep()
	for k in 2:
		var at: Vector3 = sweep._home[sweep._gone.find(0)].origin
		sweep.sweep_at(at, at)
		if k == 0:
			sweep.dump()
			await get_tree().create_timer(2.0).timeout
	await get_tree().create_timer(0.4).timeout
	expect["floor"] = {"left": sweep.scraps_left(), "pan": sweep.pan_count(), "loads": sweep.loads_done}
	_check(sweep.scraps_left() < sweep.scraps_total() and sweep.pan_count() > 0 and sweep.loads_done == 1, "medio suelo barrido (%d papelitos, %d en el recogedor)" % [sweep.scraps_left(), sweep.pan_count()])

	# Cajas de cartón: dos en el montón y una aplanada y soltada en el suelo.
	var boxes := shop.cardboard()
	for k in [3, 1]:
		boxes.boxes[k].flatten_instantly()
		await boxes.stack(boxes.boxes[k])
	boxes.boxes[0].flatten_instantly()
	boxes.boxes[0].lay_flat(Vector3(0.5, 0.0, 2.6), 0.7)
	expect["boxes"] = {"stacked": [3, 1], "flat": [0.5, 2.6]}
	_check(boxes.stacked_count() == 2, "dos cajas en el montón y una aplanada en el suelo")

	var f := FileAccess.open(EXPECT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()
	_check(shop.save_game(), "partida guardada")
	await _frames(5)
	_check(SaveGame.has_save(), "existe el fichero de guardado")


func _read() -> void:
	var f := FileAccess.open(EXPECT_PATH, FileAccess.READ)
	_check(f != null, "existe el fichero de expectativas de la fase anterior")
	if f == null:
		return
	var expect: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var items := room.get_items()
	_check(room.placed_items == int(expect["placed"]), "tras reiniciar hay %d objetos colocados (%d)" % [int(expect["placed"]), room.placed_items])
	var done := room.section_by_id(StringName(expect["section"]))
	_check(done != null and done.is_completed and done.is_bunting_visible() and room.shell.is_decor_unlocked(done.section_id), "la sección completada conserva su guirnalda y su premio")
	for s in room.sections:
		if s != done:
			_check(not s.is_completed and not s.is_bunting_visible() and not room.shell.is_decor_unlocked(s.section_id), "la sección %s sigue sin completar (ni premio)" % s.display_name)
	for s: Dictionary in expect["slots"]:
		var it := items[int(s["i"])]
		var unit_i := room.get_units().find(it.container) if it.container != null else -1
		_check(it.state == PickableItem.State.PLACED and unit_i == int(s["u"]) and it.slot_row == int(s["r"]) and it.slot_index == int(s["k"]),
			"objeto #%d en su mismo hueco (contenedor %d, fila %d, hueco %d)" % [int(s["i"]), int(s["u"]), int(s["r"]), int(s["k"])])
	var l: Dictionary = expect["loose"]
	var loose := items[int(l["i"])]
	var lp := room.to_local(loose.global_position)
	_check(Vector3(lp.x - float(l["x"]), lp.y - float(l["y"]), lp.z - float(l["z"])).length() < 0.01, "el objeto suelto sigue donde se dejó")
	_check(room.treasures_found() == 1, "el tesoro sigue contado como hallado")
	var still_hidden := false
	for t in room._treasures:
		if String(t.data.id) == String(expect["treasure"]):
			still_hidden = true
	_check(not still_hidden, "el tesoro hallado ya no está en su escondite")
	_check(room._displays.has(StringName(expect["treasure"])), "el tesoro hallado está en la repisa")
	_check(room.shell.is_decor_unlocked(&"bunting") == room.is_completed, "la decoración coincide con el estado de la sala")
	var fl: Dictionary = expect["floor"]
	var sweep := shop.floor_sweep()
	_check(sweep.scraps_left() == int(fl["left"]) and sweep.pan_count() == int(fl["pan"]) and sweep.loads_done == int(fl["loads"]),
		"el suelo sigue medio barrido (%d papelitos, %d en el recogedor)" % [sweep.scraps_left(), sweep.pan_count()])
	var bx: Dictionary = expect["boxes"]
	var boxes := shop.cardboard()
	var in_pile := true
	for k in bx["stacked"]:
		in_pile = in_pile and boxes.boxes[int(k)].state == CardboardBox.State.STACKED
	_check(boxes.stacked_count() == 2 and in_pile, "las dos cajas siguen en el montón")
	var flat := boxes.boxes[0]
	_check(flat.state == CardboardBox.State.FLAT and Vector2(flat.position.x - float(bx["flat"][0]), flat.position.z - float(bx["flat"][1])).length() < 0.02,
		"el cartón aplanado sigue en el suelo donde se soltó")
	_check(boxes.boxes[2].state == CardboardBox.State.LOOSE and boxes.boxes[4].state == CardboardBox.State.LOOSE, "las demás cajas siguen montadas")
	SaveGame.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPECT_PATH))

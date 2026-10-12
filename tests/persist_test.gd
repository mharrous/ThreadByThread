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
	room = shop.rooms[0]
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

	# Un objeto suelto en un sitio reconocible.
	var loose := items[PLACED + 2]
	var target := room.to_global(Vector3(-1.0, loose.half_height, 1.4))
	loose.global_position = target
	Events.item_set_down.emit(loose)
	var lp := room.to_local(loose.global_position)
	expect["loose"] = {"i": PLACED + 2, "x": lp.x, "y": lp.y, "z": lp.z}

	# Un tesoro, recogido como lo hace el jugador.
	var holder: ItemHolder = main.get_node("Player/ItemHolder")
	var treasure: PickableItem = room._treasures[0]
	expect["treasure"] = String(treasure.data.id)
	holder._collect_treasure(treasure)
	await _frames(3)
	_check(room.treasures_found() == 1, "un tesoro encontrado")

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
	_check(room.placed_items == PLACED, "tras reiniciar hay %d objetos colocados (%d)" % [PLACED, room.placed_items])
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
	SaveGame.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPECT_PATH))

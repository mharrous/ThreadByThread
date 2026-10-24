class_name Shop
extends Node3D
## La mercería: una sola sala (RoomController) con todo desordenado por el suelo. Arranca la partida,
## guarda y carga, y ofrece el atajo de completar la sección que tiene delante el jugador.

signal state_saved

const AUTOSAVE_SECONDS := 20.0

var room: RoomController
## Ya se vio la escena de apertura: al cargar se va directo a la tienda abierta, sin repetirla.
var shop_opened := false

var _player: Player
var _dirty := false
var _loaded := false


func _ready() -> void:
	add_to_group(&"shop")
	for child in get_children():
		if child is RoomController:
			room = child
			break
	Events.section_completed.connect(func(_s): save_game.call_deferred())
	Events.room_completed.connect(func(_r): save_game())
	Events.item_placed.connect(func(_i, _u): _dirty = true)
	Events.item_removed.connect(func(_i, _u): _dirty = true)
	Events.item_set_down.connect(func(_i): _dirty = true)
	Events.item_landed.connect(func(_i): _dirty = true)
	Events.treasure_found.connect(func(_i): save_game())
	Events.floor_progress_changed.connect(func(_s, _t): _dirty = true)
	Events.floor_cleaned.connect(func(): save_game.call_deferred())
	Events.boxes_progress_changed.connect(func(_s, _t): _dirty = true)
	Events.boxes_done.connect(func(): save_game.call_deferred())
	Events.pause_toggled.connect(func(paused: bool):
		if paused:
			save_game())
	_start.call_deferred()


func _start() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	load_game()
	_loaded = true
	# Autoguardado con un temporizador (no cuenta en cada fotograma); solo guarda si algo cambió.
	var autosave := Timer.new()
	autosave.name = "Autosave"
	autosave.wait_time = AUTOSAVE_SECONDS
	autosave.timeout.connect(func():
		if _dirty:
			save_game())
	add_child(autosave)
	autosave.start()
	if room != null:
		Events.active_room_changed.emit(room)
		Events.progress_changed.emit(room.placed_items, room.total_items)
		var sweep := floor_sweep()
		if sweep != null:
			sweep.emit_progress()
		var boxes := cardboard()
		if boxes != null:
			boxes.emit_progress()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _loaded:
		save_game()


## Sección en la que está trabajando el jugador: la del objeto que lleva en la mano o, con las manos
## vacías, la de los muebles que tiene más cerca.
func current_section() -> ShopSection:
	if room == null or _player == null:
		return null
	var holder := _player.get_node_or_null("ItemHolder") as ItemHolder
	if holder != null and holder.held != null and is_instance_valid(holder.held) and holder.held.data != null:
		var s := room.section_for_key(holder.held.data.sort_key)
		if s != null:
			return s
	return room.section_near(_player.global_position)


## Da por ordenada la sección en la que está el jugador (botón del menú de pausa). Suelta antes lo que
## lleve en la mano para que también cuente.
func skip_section() -> void:
	var section := current_section()
	if section == null:
		return
	if section.is_completed and section.placed_items == section.total_items:
		Events.hint_requested.emit("La sección %s ya está completa" % section.display_name)
		return
	var holder := _player.get_node_or_null("ItemHolder") as ItemHolder if _player != null else null
	if holder != null:
		holder.release_held()
	room.solve_instantly(section)
	Events.hint_requested.emit("%s: completada con el atajo" % section.display_name)


# --- Guardado ------------------------------------------------------------

func save_game() -> bool:
	if not _loaded or room == null:
		return false
	var data := {"room": room.capture_state(), "shop_opened": shop_opened}
	var sweep := floor_sweep()
	if sweep != null:
		data["floor"] = sweep.capture_state()
	var boxes := cardboard()
	if boxes != null:
		data["boxes"] = boxes.capture_state()
	var ok := SaveGame.write(data)
	if ok:
		_dirty = false
		Events.game_saved.emit()
		state_saved.emit()
	return ok


func load_game() -> bool:
	var data := SaveGame.read()
	if data.is_empty() or room == null:
		return false
	var st: Variant = data.get("room")
	if not (st is Dictionary) or not room.apply_state(st):
		push_warning("El guardado no encaja con el contenido actual de la mercería; se ignora")
		return false
	shop_opened = bool(data.get("shop_opened", false)) and room.is_completed
	var sweep := floor_sweep()
	if sweep != null:
		var fl: Variant = data.get("floor")
		if shop_opened:
			# La tienda solo abre con el suelo barrido.
			sweep.finish_instantly()
		elif fl is Dictionary:
			sweep.apply_state(fl)
	var boxes := cardboard()
	if boxes != null:
		var bx: Variant = data.get("boxes")
		if shop_opened:
			boxes.finish_instantly()
		elif bx is Dictionary:
			boxes.apply_state(bx)
	return true


## Las cajas de cartón tiradas y su montón para tirar.
func cardboard() -> ShopBoxes:
	if room == null or room.shell == null:
		return null
	return room.shell.get_node_or_null("ShopBoxes") as ShopBoxes


## El suelo y sus herramientas (escoba, recogedor y papelera).
func floor_sweep() -> ShopSweep:
	if room == null or room.shell == null:
		return null
	return room.shell.get_node_or_null("ShopSweep") as ShopSweep

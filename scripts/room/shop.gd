class_name Shop
extends Node3D
## La mercería: una sola sala (RoomController) con todo desordenado por el suelo. Arranca la partida,
## guarda y carga, y ofrece el atajo de completar la sección que tiene delante el jugador.

signal state_saved

const AUTOSAVE_SECONDS := 20.0

var room: RoomController

var _player: Player
var _dirty := false
var _autosave_timer := AUTOSAVE_SECONDS
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
	Events.pause_toggled.connect(func(paused: bool):
		if paused:
			save_game())
	_start.call_deferred()


func _start() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	load_game()
	_loaded = true
	if room != null:
		Events.active_room_changed.emit(room)
		Events.progress_changed.emit(room.placed_items, room.total_items)


func _process(delta: float) -> void:
	if not _loaded:
		return
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		if _dirty:
			save_game()


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
	var ok := SaveGame.write({"room": room.capture_state()})
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
	return true

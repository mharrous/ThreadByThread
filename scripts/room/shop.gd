class_name Shop
extends Node3D
## La mercería completa: varias salas en fila. Las salas empiezan bloqueadas (puerta cerrada)
## y se abren al ordenar la anterior. Sabe en qué sala está el jugador, oculta las lejanas
## (rendimiento) y guarda y carga la partida.

signal state_saved

const AUTOSAVE_SECONDS := 20.0
const NEAR_ROOMS := 1

var rooms: Array[RoomController] = []
var active_room: RoomController

var _player: Player
var _dirty := false
var _autosave_timer := AUTOSAVE_SECONDS
var _loaded := false


func _ready() -> void:
	add_to_group(&"shop")
	for child in get_children():
		if child is RoomController:
			rooms.append(child)
	for i in rooms.size():
		rooms[i].index = i
		rooms[i].is_unlocked = i == 0
	Events.room_completed.connect(_on_room_completed)
	Events.item_placed.connect(func(_i, _u): _dirty = true)
	Events.item_removed.connect(func(_i, _u): _dirty = true)
	Events.item_set_down.connect(func(_i): _dirty = true)
	Events.item_landed.connect(func(_i): _dirty = true)
	Events.pause_toggled.connect(func(paused: bool):
		if paused:
			save_game())
	_start.call_deferred()


func _start() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	load_game()
	_loaded = true
	_update_active_room(true)


func _process(delta: float) -> void:
	if not _loaded:
		return
	_update_active_room(false)
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		if _dirty:
			save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _loaded:
		save_game()


func room_by_id(id: StringName) -> RoomController:
	for r in rooms:
		if r.room_id == id:
			return r
	return null


## Índice de la sala en la que está el jugador (cada sala ocupa 6.4 m en X).
func room_index_at(world_x: float) -> int:
	var spacing := 6.4
	return clampi(floori((world_x - global_position.x + 3.2) / spacing), 0, rooms.size() - 1)


func unlock_room(index: int, animate: bool = true) -> void:
	if index <= 0 or index >= rooms.size():
		return
	var room := rooms[index]
	if room.is_unlocked:
		return
	room.is_unlocked = true
	var door := rooms[index - 1].shell.east_door
	if door != null:
		door.unlock(animate)
	Events.room_unlocked.emit(room)


func _on_room_completed(room: RoomController) -> void:
	var next := room.index + 1
	if next < rooms.size():
		unlock_room(next, true)
		Events.hint_requested.emit("¡Puerta abierta! Hay una sala nueva por explorar")
	save_game()


func _update_active_room(force: bool) -> void:
	if _player == null or rooms.is_empty():
		return
	var idx := room_index_at(_player.global_position.x)
	var room := rooms[idx]
	if room != active_room or force:
		active_room = room
		for r in rooms:
			r.visible = absi(r.index - idx) <= NEAR_ROOMS
		Events.active_room_changed.emit(room)
		Events.progress_changed.emit(room.placed_items, room.total_items)


# --- Guardado ------------------------------------------------------------

func save_game() -> bool:
	if not _loaded:
		return false
	var data := {"rooms": {}, "unlocked": [], "active": active_room.room_id if active_room else &""}
	for r in rooms:
		data["rooms"][String(r.room_id)] = r.capture_state()
		if r.is_unlocked:
			data["unlocked"].append(String(r.room_id))
	data["active"] = String(data["active"])
	var ok := SaveGame.write(data)
	if ok:
		_dirty = false
		Events.game_saved.emit()
		state_saved.emit()
	return ok


func load_game() -> bool:
	var data := SaveGame.read()
	if data.is_empty():
		return false
	var saved_rooms: Dictionary = data.get("rooms", {})
	for r in rooms:
		var st: Variant = saved_rooms.get(String(r.room_id))
		if st is Dictionary:
			if not r.apply_state(st):
				push_warning("El guardado de la sala %s no encaja con su contenido actual; se ignora" % r.room_id)
	for id in data.get("unlocked", []):
		var r := room_by_id(StringName(id))
		if r != null and r.index > 0:
			unlock_room(r.index, false)
	var active := room_by_id(StringName(data.get("active", "")))
	if active != null and _player != null:
		_player.teleport(active.entry_point())
	return true

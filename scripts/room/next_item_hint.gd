class_name NextItemHint
extends Node
## Tras colocar un objeto, señala con un brillo suave el objeto suelto más cercano del mismo tipo, para
## seguir la racha sin buscar. Se retira si coges cualquier cosa, si ese objeto deja de estar suelto, si
## lo has visto y apartas la vista, o si no lo miras en un rato. Solo escucha eventos.

## Ángulo (desde el centro de la mirada) para contar como "visto" y para contar como "mirar a otro lado".
const SEEN_DEG := 35.0
const AWAY_DEG := 80.0
## Sin llegar a mirarlo, la pista se retira sola pasado este tiempo.
const TIMEOUT := 12.0

var _target: PickableItem
var _seen := false
var _age := 0.0
var _camera: Camera3D
var _player: Node3D


func _ready() -> void:
	Events.item_placed.connect(_on_item_placed)
	Events.item_picked.connect(func(_item): _clear())
	set_process(false)


func _on_item_placed(item: PickableItem, _unit) -> void:
	_clear()
	if item.room == null or item.data == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		_camera = get_viewport().get_camera_3d()
	if _player == null:
		return
	var from := _player.global_position
	var best: PickableItem = null
	var best_d := INF
	for it in item.room.get_items():
		if it.state != PickableItem.State.LOOSE or it.data.sort_key != item.data.sort_key or not it.is_pickable():
			continue
		var d := it.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = it
	if best == null:
		return
	_target = best
	_seen = false
	_age = 0.0
	_target.set_hinted(true)
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_target) or _target.state != PickableItem.State.LOOSE:
		_clear()
		return
	_age += delta
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
	if _camera != null:
		var to := (_target.global_position - _camera.global_position).normalized()
		var ang := rad_to_deg(acos(clampf(-_camera.global_basis.z.dot(to), -1.0, 1.0)))
		if ang < SEEN_DEG:
			_seen = true
		elif _seen and ang > AWAY_DEG:
			_clear()
			return
	if not _seen and _age > TIMEOUT:
		_clear()


func _clear() -> void:
	if is_instance_valid(_target):
		_target.set_hinted(false)
	_target = null
	set_process(false)

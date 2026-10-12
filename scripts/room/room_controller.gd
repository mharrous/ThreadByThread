class_name RoomController
extends Node3D
## Lógica de una sala: reparte filas de estantería, genera los objetos
## desordenados y lleva la cuenta de progreso (global y por colección).

@export var catalog: ItemCatalog
@export var item_scene: PackedScene
@export_range(1, 30) var items_per_color := 1
@export var rng_seed := 4242

var total_items := 0
var placed_items := 0
var is_completed := false

const CLUSTER_COUNT := 8
const TABLE_CAPACITY := 30

var _clusters: Array[Vector2] = []
var _on_table := 0
var _items: Array[PickableItem] = []
var _shelves: Array[ShelfUnit] = []
var _total_by_key: Dictionary = {}
var _placed_by_key: Dictionary = {}

@onready var _items_root: Node3D = $Items
@onready var _shelves_root: Node3D = $Shelves


func _ready() -> void:
	for child in _shelves_root.get_children():
		if child is ShelfUnit:
			_shelves.append(child)
	_assign_rows()
	_spawn_items()
	Events.item_placed.connect(_on_item_placed)
	Events.item_removed.connect(_on_item_removed)
	Events.progress_changed.emit.call_deferred(placed_items, total_items)


func get_items() -> Array[PickableItem]:
	return _items


func get_shelves() -> Array[ShelfUnit]:
	return _shelves


## Devuelve {shelf, row} de la fila que acepta `sort_key`, o {} si no existe.
func find_row(sort_key: StringName) -> Dictionary:
	for shelf in _shelves:
		var row := shelf.row_for_key(sort_key)
		if row >= 0:
			return {"shelf": shelf, "row": row}
	return {}


# --- Preparación ---------------------------------------------------------

func _assign_rows() -> void:
	var idx := 0
	for shelf in _shelves:
		var slice: Array = []
		for r in shelf.rows:
			if idx < catalog.items.size():
				slice.append(catalog.items[idx])
				idx += 1
		shelf.set_rows_top_to_bottom(slice)


func _spawn_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var list: Array[ItemData] = []
	for data in catalog.items:
		_total_by_key[data.sort_key] = items_per_color
		_placed_by_key[data.sort_key] = 0
		for i in items_per_color:
			list.append(data)
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := list[i]
		list[i] = list[j]
		list[j] = tmp

	var taken: Array[Vector3] = []
	for data in list:
		var scene := data.scene if data.scene != null else item_scene
		var item := scene.instantiate() as PickableItem
		_items_root.add_child(item)
		item.setup(data, rng.randf_range(0.95, 1.05))
		item.position = _find_spot(rng, taken, item.radius)
		# Orientación libre: cada ovillo muestra una cara distinta de su dibujo de hebras.
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		item.basis = Basis(axis, rng.randf() * TAU)
		_items.append(item)
	total_items = _items.size()


## Busca un hueco libre sin solaparse con otros objetos. El suelo se llena por montones
## (como si alguien hubiera volcado cajas); una parte va sobre la mesa.
func _find_spot(rng: RandomNumberGenerator, taken: Array[Vector3], radius: float) -> Vector3:
	if _clusters.is_empty():
		_make_clusters(rng)
	for attempt in 120:
		var p: Vector3
		if _on_table < TABLE_CAPACITY and rng.randf() < 0.22:
			var r := RoomShell.TABLE_RECT
			p = Vector3(
				rng.randf_range(r.position.x + 0.12, r.end.x - 0.12),
				RoomShell.TABLE_TOP_Y + radius,
				rng.randf_range(r.position.y + 0.12, r.end.y - 0.12))
			if not _is_free(taken, p, radius):
				continue
			_on_table += 1
			taken.append(p)
			return p
		var c := _clusters[rng.randi() % _clusters.size()]
		var spread := 0.35 + attempt * 0.006   # si el montón está lleno, se ensancha
		var flat := Vector2(c.x + rng.randfn(0.0, spread), c.y + rng.randfn(0.0, spread))
		if flat.x < -2.55 or flat.x > 2.45 or flat.y < -1.15 or flat.y > 2.15:
			continue
		if RoomShell.is_blocked_floor(flat, 0.12):
			continue
		p = Vector3(flat.x, radius, flat.y)
		if _is_free(taken, p, radius):
			taken.append(p)
			return p
	return Vector3(rng.randf_range(-1.0, 1.0), radius, rng.randf_range(0.0, 1.5))


func _is_free(taken: Array[Vector3], p: Vector3, radius: float) -> bool:
	var min_sq := pow(radius * 2.2, 2.0)
	for q in taken:
		if q.distance_squared_to(p) < min_sq:
			return false
	return true


func _make_clusters(rng: RandomNumberGenerator) -> void:
	var tries := 0
	while _clusters.size() < CLUSTER_COUNT and tries < 200:
		tries += 1
		var c := Vector2(rng.randf_range(-2.0, 1.9), rng.randf_range(-0.6, 1.7))
		if not RoomShell.is_blocked_floor(c, 0.3):
			_clusters.append(c)


# --- Progreso ------------------------------------------------------------

func _on_item_placed(item: PickableItem, _shelf: ShelfUnit) -> void:
	placed_items += 1
	var key := item.data.sort_key
	_placed_by_key[key] = int(_placed_by_key.get(key, 0)) + 1
	Events.progress_changed.emit(placed_items, total_items)
	if placed_items == total_items and not is_completed:
		is_completed = true
		_announce_completion()
	elif _placed_by_key[key] == _total_by_key.get(key, -1):
		Events.collection_completed.emit(key)


func _on_item_removed(item: PickableItem, _shelf: ShelfUnit) -> void:
	placed_items = maxi(0, placed_items - 1)
	var key := item.data.sort_key
	_placed_by_key[key] = maxi(0, int(_placed_by_key.get(key, 0)) - 1)
	Events.progress_changed.emit(placed_items, total_items)


func _announce_completion() -> void:
	await get_tree().create_timer(0.7).timeout
	Events.room_completed.emit()

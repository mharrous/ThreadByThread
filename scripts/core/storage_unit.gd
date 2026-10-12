class_name StorageUnit
extends Node3D
## Base de los contenedores donde se colocan objetos: estanterías, bandejas de botones,
## paneles de ganchos... Cada "fila" (o celda) acepta un tipo de objeto (`sort_key`),
## tiene `slots_per_row` huecos y cada hueco admite `stack_capacity` objetos apilados.
## Las subclases definen la forma (dónde está cada hueco y cómo se apunta a él).

enum SlotStatus { NONE, OK, WRONG_ROW, ROW_FULL }

const AIM_LAYER := 4
const AIM_META := &"storage"

@export var rows := 5
@export var slots_per_row := 15
@export var stack_capacity := 1
@export var wrong_row_hint := "Esta fila es de otro tipo"

## Sala a la que pertenece (se busca hacia arriba en el árbol).
var room: RoomController

var _row_data: Array[ItemData] = []     # una entrada por fila; null si no está asignada
var _slots: Array = []                  # [fila][hueco] -> Array[PickableItem] (la pila del hueco)


func _ready() -> void:
	_row_data.resize(rows)
	for r in rows:
		var row_slots: Array = []
		for s in slots_per_row:
			row_slots.append([])
		_slots.append(row_slots)
	room = _find_room()
	_build()
	Events.collection_completed.connect(_on_collection_completed)
	Events.room_completed.connect(_on_room_completed)


# --- A implementar por cada tipo de contenedor ---------------------------

## Crea la geometría, el volumen de puntería y las marcas de los huecos.
func _build() -> void:
	pass


## A qué hueco apunta un rayo. Devuelve {status, row, slot, transform} (transform = pose final).
func query_slot(_ray_origin: Vector3, _ray_dir: Vector3, _item: PickableItem) -> Dictionary:
	return {"status": SlotStatus.NONE}


## Pose final (mundo) que tendría `item` en el hueco indicado.
func slot_transform(_row: int, _slot: int, _item: PickableItem) -> Transform3D:
	return global_transform


## Fila a la que va el elemento `i` de la lista de tipos al repartirla.
func row_for_list_index(i: int) -> int:
	return i


## Dónde ponerse y qué mirar para apuntar a un hueco (lo usan las pruebas automáticas).
func stand_hint(_row: int, _slot: int, _item: PickableItem) -> Dictionary:
	return {"position": global_position + Vector3(0, 0, 1.0), "look": global_position}


func _refresh_row_visuals(_row: int) -> void:
	pass


func _set_marker_visible(_row: int, _slot: int, _visible: bool) -> void:
	pass


func pulse_row(_row: int, _delay: float = 0.0) -> void:
	pass


# --- API común -----------------------------------------------------------

## Asigna el tipo de objeto de cada fila siguiendo el orden de la lista.
func assign_rows(list: Array) -> void:
	for i in list.size():
		var row := row_for_list_index(i)
		if row < 0 or row >= rows:
			break
		_row_data[row] = list[i] as ItemData
		_refresh_row_visuals(row)


func row_data(row: int) -> ItemData:
	return _row_data[row]


func row_for_key(sort_key: StringName) -> int:
	for r in rows:
		if _row_data[r] != null and _row_data[r].sort_key == sort_key:
			return r
	return -1


func capacity(row: int) -> int:
	return slots_per_row * stack_capacity


func stack_size(row: int, slot: int) -> int:
	return (_slots[row][slot] as Array).size()


func has_room(row: int, slot: int) -> bool:
	return stack_size(row, slot) < stack_capacity


func first_free_slot(row: int) -> int:
	return nearest_free_slot(row, 0)


## Hueco con sitio más cercano a `wanted`; -1 si la fila está llena.
func nearest_free_slot(row: int, wanted: int) -> int:
	for off in slots_per_row:
		var a := wanted - off
		var b := wanted + off
		if a >= 0 and has_room(row, a):
			return a
		if b < slots_per_row and has_room(row, b):
			return b
	return -1


func items_in_row(row: int) -> Array[PickableItem]:
	var out: Array[PickableItem] = []
	for slot_stack: Array in _slots[row]:
		for it: PickableItem in slot_stack:
			out.append(it)
	return out


func slot_world_position(row: int, slot: int, item: PickableItem) -> Vector3:
	return slot_transform(row, slot, item).origin


func reserve(row: int, slot: int, item: PickableItem) -> void:
	(_slots[row][slot] as Array).append(item)
	_set_marker_visible(row, slot, has_room(row, slot))


func release(row: int, slot: int, item: PickableItem) -> void:
	(_slots[row][slot] as Array).erase(item)
	_set_marker_visible(row, slot, true)


## Pequeño salto en cadena de los objetos colocados en una fila.
func celebrate_row(row: int, delay: float = 0.0) -> void:
	var n := 0
	for it in items_in_row(row):
		var tw := create_tween()
		tw.tween_interval(delay + n * 0.04)
		n += 1
		var base_y := it.global_position.y
		tw.tween_property(it, "global_position:y", base_y + 0.02, 0.11) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(it, "global_position:y", base_y, 0.16) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _no_slot() -> Dictionary:
	return {"status": SlotStatus.NONE}


func _status_for(row: int, slot: int, item: PickableItem) -> SlotStatus:
	if slot < 0:
		return SlotStatus.ROW_FULL
	if _row_data[row] == null or _row_data[row].sort_key != item.data.sort_key:
		return SlotStatus.WRONG_ROW
	return SlotStatus.OK


func _find_room() -> RoomController:
	var n := get_parent()
	while n != null:
		if n is RoomController:
			return n
		n = n.get_parent()
	return null


## Volumen invisible que el rayo de puntería detecta solo mientras se sostiene un objeto.
func _make_aim_volume(size: Vector3, center: Vector3) -> void:
	var aim := StaticBody3D.new()
	aim.name = "AimVolume"
	aim.collision_layer = AIM_LAYER
	aim.collision_mask = 0
	aim.set_meta(AIM_META, self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	aim.add_child(cs)
	add_child(aim)


func _on_collection_completed(sort_key: StringName) -> void:
	var row := row_for_key(sort_key)
	if row >= 0:
		pulse_row(row)
		celebrate_row(row)


func _on_room_completed(completed_room: RoomController) -> void:
	if completed_room != room:
		return
	for r in rows:
		pulse_row(r, r * 0.1)
		celebrate_row(r, r * 0.1)

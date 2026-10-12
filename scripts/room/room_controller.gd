class_name RoomController
extends Node3D
## Lógica de una sala: reparte los tipos de objeto entre sus contenedores, genera los
## objetos desordenados (en montones por el suelo y sobre las mesas) y lleva la cuenta de
## progreso (global y por colección). También captura y restaura su estado para guardar.

@export var room_id: StringName = &"yarn"
@export var display_name := "Sala de ovillos"
@export var objective := "Objetivo: ordena los ovillos por color"
@export var catalog: ItemCatalog
## Escena por defecto de los objetos (la de cada ItemData la sustituye si la tiene).
@export var item_scene: PackedScene
## Tesoros escondidos de la sala (opcionales: no cuentan para ordenarla).
@export var treasure_catalog: ItemCatalog
## > 0: cada tipo genera exactamente este número de objetos (pruebas). 0 = el `spawn_count` de cada tipo.
@export var count_override := 0
@export var rng_seed := 4242

var index := 0
var total_items := 0
var placed_items := 0
var is_completed := false
## Los contenedores y objetos de una sala bloqueada existen pero no se pueden alcanzar.
var is_unlocked := true

const CLUSTER_COUNT := 8
const ROOM_FALLBACK_Z := 1.9

var shell: RoomShell
var _clusters: Array[Vector2] = []
var _taken: Array[Vector4] = []        # x, y, z, radio de lo ya colocado en el reparto
var _items: Array[PickableItem] = []
var _treasures: Array[PickableItem] = []      # tesoros aún sin encontrar
var _found: Dictionary = {}                   # id del tesoro -> true
var _displays: Dictionary = {}                # id del tesoro -> copia expuesta en la repisa
var _units: Array[StorageUnit] = []
var _total_by_key: Dictionary = {}
var _placed_by_key: Dictionary = {}

@onready var _items_root: Node3D = $Items
@onready var _units_root: Node3D = $Units


func _ready() -> void:
	shell = $Shell as RoomShell
	for child in _units_root.get_children():
		if child is StorageUnit:
			_units.append(child)
	_assign_rows()
	_spawn_items()
	_spawn_treasures()
	Events.item_placed.connect(_on_item_placed)
	Events.item_removed.connect(_on_item_removed)
	Events.treasure_found.connect(_on_treasure_found)
	_emit_progress.call_deferred()


func get_items() -> Array[PickableItem]:
	return _items


func get_units() -> Array[StorageUnit]:
	return _units


## Devuelve {unit, row} del contenedor/fila que acepta `sort_key`, o {} si no existe.
func find_row(sort_key: StringName) -> Dictionary:
	for unit in _units:
		var row := unit.row_for_key(sort_key)
		if row >= 0:
			return {"unit": unit, "row": row}
	return {}


## Punto de entrada de la sala (donde aparece el jugador al llegar).
func entry_point() -> Vector3:
	return global_position + Vector3(0.0, 0.0, 1.9)


# --- Preparación ---------------------------------------------------------

## Reparte los tipos del catálogo entre los contenedores, en orden: cada contenedor
## se queda con tantos tipos como filas tenga.
func _assign_rows() -> void:
	var idx := 0
	for unit in _units:
		var slice: Array = []
		for r in unit.rows:
			if idx < catalog.items.size():
				slice.append(catalog.items[idx])
				idx += 1
		unit.assign_rows(slice)


func _count_for(data: ItemData) -> int:
	return count_override if count_override > 0 else data.spawn_count


func _spawn_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var list: Array[ItemData] = []
	for data in catalog.items:
		var n := _count_for(data)
		_total_by_key[data.sort_key] = n
		_placed_by_key[data.sort_key] = 0
		for i in n:
			list.append(data)
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := list[i]
		list[i] = list[j]
		list[j] = tmp

	for data in list:
		var variant := rng.randi()
		var item := _instantiate_item(data, rng.randf_range(0.93, 1.07), variant)
		item.index = _items.size()
		item.position = _find_spot(rng, item)
		item.basis = _random_basis(rng, data)
		_items.append(item)
	total_items = _items.size()


func _instantiate_item(data: ItemData, jitter: float, variant: int) -> PickableItem:
	var scene := data.scene if data.scene != null else item_scene
	var item := scene.instantiate() as PickableItem
	_items_root.add_child(item)
	item.room = self
	item.setup(data, jitter, variant)
	return item


## Esferas con orientación libre (cada ovillo enseña otra cara); el resto, de pie y con giro al azar.
func _random_basis(rng: RandomNumberGenerator, data: ItemData) -> Basis:
	if data.shape == ItemData.Shape.SPHERE:
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		return Basis(axis, rng.randf() * TAU)
	return Basis(Vector3.UP, rng.randf() * TAU)


## Busca un hueco libre sin solaparse con otros objetos: sobre una mesa o en el suelo,
## por montones (como si alguien hubiera volcado cajas), según la zona del tipo de objeto.
func _find_spot(rng: RandomNumberGenerator, item: PickableItem) -> Vector3:
	if _clusters.is_empty():
		_make_clusters(rng)
	var data := item.data
	var r := item.radius
	var h := item.half_height
	var tables := shell.tables
	# Primero con la separación normal entre objetos; si la sala está muy llena (telas largas,
	# muchas piezas), se aprieta un poco. Así nunca queda nada inalcanzable.
	for spacing in [1.15, 0.9, 0.7]:
		for attempt in 160:
			var want_table := false
			match data.spawn_zone:
				ItemData.SpawnZone.TABLE:
					want_table = not tables.is_empty()
				ItemData.SpawnZone.ANY:
					want_table = not tables.is_empty() and rng.randf() < 0.25
			var p: Vector3
			if want_table:
				var t: Dictionary = tables[rng.randi() % tables.size()]
				var rect: Rect2 = t["rect"]
				var m := minf(r + 0.02, rect.size.x * 0.4)
				p = Vector3(
					rng.randf_range(rect.position.x + m, rect.end.x - m),
					float(t["top_y"]) + h,
					rng.randf_range(rect.position.y + m, rect.end.y - m))
			else:
				var c := _clusters[rng.randi() % _clusters.size()]
				var spread := 0.35 + attempt * 0.005   # si el montón está lleno, se ensancha
				var flat := Vector2(c.x + rng.randfn(0.0, spread), c.y + rng.randfn(0.0, spread))
				if not shell.floor_bounds.has_point(flat) or shell.is_blocked(flat, r):
					continue
				p = Vector3(flat.x, h, flat.y)
			if _is_free(p, r, spacing):
				_taken.append(Vector4(p.x, p.y, p.z, r))
				return p
	# Último recurso: cualquier punto del suelo que no esté dentro de un mueble (nunca bajo una mesa).
	var b := shell.floor_bounds
	for attempt in 600:
		var flat := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
		if not shell.is_blocked(flat, r):
			var q := Vector3(flat.x, h, flat.y)
			_taken.append(Vector4(q.x, q.y, q.z, r))
			return q
	push_warning("Sala %s: no hay sitio libre para %s" % [room_id, data.id])
	return Vector3(0.0, h, ROOM_FALLBACK_Z)


func _is_free(p: Vector3, radius: float, spacing: float = 1.15) -> bool:
	for q in _taken:
		var min_d := (radius + q.w) * spacing
		if Vector3(q.x, q.y, q.z).distance_squared_to(p) < min_d * min_d:
			return false
	return true

func _make_clusters(rng: RandomNumberGenerator) -> void:
	var b := shell.floor_bounds
	var tries := 0
	while _clusters.size() < CLUSTER_COUNT and tries < 300:
		tries += 1
		var c := Vector2(rng.randf_range(b.position.x + 0.4, b.end.x - 0.4), rng.randf_range(b.position.y + 0.4, b.end.y - 0.4))
		if not shell.is_blocked(c, 0.3):
			_clusters.append(c)
	if _clusters.is_empty():
		_clusters.append(Vector2(0.0, 0.8))


# --- Progreso ------------------------------------------------------------

func _emit_progress() -> void:
	Events.room_progress_changed.emit(self, placed_items, total_items)


func _on_item_placed(item: PickableItem, _unit: StorageUnit) -> void:
	if item.room != self:
		return
	placed_items += 1
	var key := item.data.sort_key
	_placed_by_key[key] = int(_placed_by_key.get(key, 0)) + 1
	_emit_progress()
	if placed_items == total_items and not is_completed:
		is_completed = true
		_announce_completion()
	elif _placed_by_key[key] == _total_by_key.get(key, -1):
		Events.collection_completed.emit(key)


func _on_item_removed(item: PickableItem, _unit: StorageUnit) -> void:
	if item.room != self:
		return
	placed_items = maxi(0, placed_items - 1)
	var key := item.data.sort_key
	_placed_by_key[key] = maxi(0, int(_placed_by_key.get(key, 0)) - 1)
	_emit_progress()


func _announce_completion() -> void:
	await get_tree().create_timer(0.7).timeout
	Events.room_completed.emit(self)
	# Premio visual: la guirnalda de banderines aparece cuando ya se ha leído el cartel de sala ordenada.
	await get_tree().create_timer(1.6).timeout
	shell.unlock_decor(&"bunting", true)
	Events.decor_unlocked.emit(self, &"bunting")


# --- Tesoros y colecciones -------------------------------------------------

func treasures_total() -> int:
	return treasure_catalog.items.size() if treasure_catalog != null else 0


func treasures_found() -> int:
	return _found.size()


## Para el libro de colecciones: nombre, detalle y si ya se encontró cada tesoro.
func treasure_status() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if treasure_catalog == null:
		return out
	for data in treasure_catalog.items:
		out.append({"name": data.display_name, "detail": data.detail, "found": _found.has(data.id)})
	return out


## Para el libro de colecciones: cada tipo de objeto con cuántos hay ya colocados.
func collection_status() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for data in catalog.items:
		var total: int = _total_by_key.get(data.sort_key, 0)
		var placed: int = _placed_by_key.get(data.sort_key, 0)
		out.append({"label": data.sort_label, "placed": placed, "total": total, "done": total > 0 and placed == total})
	return out


func _spawn_treasures() -> void:
	if treasure_catalog == null or shell == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed + 99
	for i in treasure_catalog.items.size():
		if i >= shell.treasure_spots.size():
			push_warning("La sala %s no tiene sitio para el tesoro %d" % [room_id, i])
			break
		var item := _instantiate_item(treasure_catalog.items[i], 1.0, 0)
		item.position = shell.treasure_spots[i] + Vector3(0.0, item.half_height, 0.0)
		item.basis = Basis(Vector3.UP, rng.randf() * TAU)
		_treasures.append(item)


func _on_treasure_found(item: PickableItem) -> void:
	if item.room != self or not item.data.treasure or _found.has(item.data.id):
		return
	_found[item.data.id] = true
	_treasures.erase(item)
	_show_display(item.data, true)


## Copia del tesoro sobre la repisa de la sala (solo decorativa: no se puede recoger).
func _show_display(data: ItemData, animate: bool) -> void:
	if _displays.has(data.id) or shell == null:
		return
	var item := _instantiate_item(data, 1.0, 0)
	item.set_pickable(false)
	item.freeze = true
	var slot := shell.display_slot(treasure_catalog.items.find(data))
	item.position = slot + Vector3(0.0, item.half_height, 0.0)
	item.rotation.y = 0.5
	_displays[data.id] = item
	if animate:
		# Aparece cuando el tesoro recién hallado ya se ha enseñado y guardado.
		item.visible = false
		await get_tree().create_timer(1.9).timeout
		item.visible = true
		item.play_appear()


## Marca un tesoro como encontrado al cargar una partida: desaparece del sitio donde estaba y se expone.
func _restore_treasure(id: StringName) -> void:
	if treasure_catalog == null or _found.has(id):
		return
	for data in treasure_catalog.items:
		if data.id != id:
			continue
		_found[id] = true
		for it in _treasures.duplicate():
			if it.data.id == id:
				_treasures.erase(it)
				it.queue_free()
		_show_display(data, false)


# --- Guardado ------------------------------------------------------------

## Firma del contenido de la sala: si cambia el catálogo o los recuentos, un guardado viejo no vale.
func signature() -> String:
	var parts: PackedStringArray = []
	for data in catalog.items:
		parts.append("%s:%d" % [data.id, _count_for(data)])
	return "%d|%s" % [rng_seed, ",".join(parts)]


## Estado de la sala para guardar: qué objetos están colocados (y dónde) y dónde están los sueltos.
func capture_state() -> Dictionary:
	var items_state: Array = []
	for it in _items:
		if it.state == PickableItem.State.PLACED and it.container != null:
			items_state.append({"s": "p", "u": _units.find(it.container), "r": it.slot_row, "k": it.slot_index})
		else:
			var t := it.global_transform
			var q := t.basis.get_rotation_quaternion()
			var local := to_local(t.origin)
			items_state.append({
				"s": "l",
				"p": [snappedf(local.x, 0.001), snappedf(local.y, 0.001), snappedf(local.z, 0.001)],
				"q": [snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)],
			})
	var found_ids: Array = []
	for id in _found:
		found_ids.append(String(id))
	return {"sig": signature(), "completed": is_completed, "items": items_state, "treasures": found_ids}


## Restaura el estado guardado. Devuelve false (sin tocar nada) si no encaja con esta sala.
func apply_state(state: Dictionary) -> bool:
	if state.get("sig", "") != signature():
		return false
	var saved: Array = state.get("items", [])
	if saved.size() != _items.size():
		return false
	placed_items = 0
	for key in _placed_by_key.keys():
		_placed_by_key[key] = 0
	for i in _items.size():
		var it := _items[i]
		var s: Dictionary = saved[i]
		if s.get("s", "l") == "p":
			var unit_i := int(s.get("u", -1))
			if unit_i < 0 or unit_i >= _units.size():
				continue
			var unit := _units[unit_i]
			var row := int(s["r"])
			var slot := int(s["k"])
			unit.reserve(row, slot, it)
			it.container = unit
			it.slot_row = row
			it.slot_index = slot
			it.state = PickableItem.State.PLACED
			it.global_transform = unit.slot_transform(row, slot, it)
			placed_items += 1
			_placed_by_key[it.data.sort_key] = int(_placed_by_key[it.data.sort_key]) + 1
		else:
			var p: Array = s["p"]
			var q: Array = s["q"]
			it.global_transform = Transform3D(
				Basis(Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized()),
				to_global(Vector3(float(p[0]), float(p[1]), float(p[2]))))
	is_completed = bool(state.get("completed", false)) or placed_items == total_items
	for id in state.get("treasures", []):
		_restore_treasure(StringName(id))
	if is_completed:
		shell.unlock_decor(&"bunting", false)
	_emit_progress()
	return true

class_name RoomController
extends Node3D
## Lógica de la mercería (una sola sala con varias secciones): reparte los tipos de objeto de cada
## sección entre sus muebles, genera todos los objetos desordenados (en montones por el suelo y sobre
## las mesas, mezclando familias) y lleva la cuenta de progreso (global, por sección y por colección).
## También captura y restaura su estado para guardar.

@export var display_name := "Thread by Thread · Mercería"
@export var objective := "Objetivo: cada cosa a su sitio"
## Escena por defecto de los objetos (la de cada ItemData la sustituye si la tiene).
@export var item_scene: PackedScene
## > 0: cada tipo genera exactamente este número de objetos (pruebas). 0 = el `spawn_count` de cada tipo.
@export var count_override := 0
## Escala de las cantidades de cada tipo (`spawn_count`) para ajustar la duración de la demo sin tocar
## los datos. Cada tipo genera al menos 2.
@export_range(0.1, 1.0, 0.05) var spawn_scale := 1.0
@export var rng_seed := 4242

var total_items := 0
var placed_items := 0
var is_completed := false
var sections: Array[ShopSection] = []

const CLUSTER_COUNT := 14
const FALLBACK_Z := 1.9
## Espacio libre que se deja delante de cada mueble de pared al repartir objetos (para poder llegar a él).
const UNIT_FRONT_CLEARANCE := 0.75
## Celda de la rejilla espacial del reparto: cada comprobación de hueco libre mira solo las celdas vecinas.
const GRID_CELL := 0.25

var shell: RoomShell
var _clusters: Array[Vector2] = []
var _grid: Dictionary = {}                     # Vector2i -> Array[Vector4] (x, y, z, radio) de lo ya repartido
var _grid_max_r := 0.0
var _items: Array[PickableItem] = []
var _treasure_list: Array[ItemData] = []       # tesoros de todas las secciones, en orden (índice = sitio y repisa)
var _treasures: Array[PickableItem] = []       # tesoros aún sin encontrar
var _found: Dictionary = {}                    # id del tesoro -> true
var _displays: Dictionary = {}                 # id del tesoro -> copia expuesta en la repisa
var _units: Array[StorageUnit] = []
var _section_by_key: Dictionary = {}           # sort_key -> ShopSection
var _scene_by_id: Dictionary = {}              # id de ItemData -> escena de su sección
var _total_by_key: Dictionary = {}
var _placed_by_key: Dictionary = {}

@onready var _items_root: Node3D = $Items
@onready var _sections_root: Node3D = $Sections


func _ready() -> void:
	shell = $Shell as RoomShell
	for child in _sections_root.get_children():
		if child is ShopSection:
			var s := child as ShopSection
			s.room = self
			sections.append(s)
			_units.append_array(s.get_units())
			for data in s.catalog.items:
				_section_by_key[data.sort_key] = s
				if s.item_scene != null:
					_scene_by_id[data.id] = s.item_scene
			if s.treasure_catalog != null:
				_treasure_list.append_array(s.treasure_catalog.items)
				for data in s.treasure_catalog.items:
					if s.item_scene != null:
						_scene_by_id[data.id] = s.item_scene
	_block_unit_fronts()
	_assign_rows()
	_spawn_items()
	_spawn_treasures()
	Events.item_placed.connect(_on_item_placed)
	Events.item_removed.connect(_on_item_removed)
	Events.item_picked.connect(_on_item_picked)
	Events.treasure_found.connect(_on_treasure_found)
	Events.item_landed.connect(_on_item_landed)
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


func section_for_key(sort_key: StringName) -> ShopSection:
	return _section_by_key.get(sort_key) as ShopSection


func section_by_id(id: StringName) -> ShopSection:
	for s in sections:
		if s.section_id == id:
			return s
	return null


## Sección cuyos muebles quedan más cerca de `world_pos` (la que tiene delante el jugador).
func section_near(world_pos: Vector3) -> ShopSection:
	var best: ShopSection = null
	var best_d := INF
	for s in sections:
		var d := s.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = s
	return best


## Colocados y total de un tipo de objeto (x = colocados, y = total).
func collection_count(sort_key: StringName) -> Vector2i:
	return Vector2i(int(_placed_by_key.get(sort_key, 0)), int(_total_by_key.get(sort_key, 0)))


## Punto donde aparece el jugador: junto a la pared sur, mirando a la sala.
func entry_point() -> Vector3:
	return global_position + Vector3(0.0, 0.0, shell.room_d * 0.5 - 1.6)


# --- Preparación ---------------------------------------------------------

## Reparte los tipos de cada sección entre sus muebles, en orden: cada mueble se queda con tantos
## tipos como filas tenga.
func _assign_rows() -> void:
	for s in sections:
		var idx := 0
		for unit in s.get_units():
			var slice: Array = []
			for r in unit.rows:
				if idx < s.catalog.items.size():
					slice.append(s.catalog.items[idx])
					idx += 1
			unit.assign_rows(slice)
		if idx < s.catalog.items.size():
			push_warning("La sección %s tiene %d tipos sin fila" % [s.section_id, s.catalog.items.size() - idx])


## Delante de cada mueble de pared no se reparten objetos: así siempre se puede llegar a colocar.
func _block_unit_fronts() -> void:
	for unit in _units:
		var size := Vector2.ZERO
		if unit is ShelfUnit:
			size = Vector2((unit as ShelfUnit).unit_width, (unit as ShelfUnit).depth)
		elif unit is PegBoard:
			size = Vector2((unit as PegBoard).board_width, 0.12)
		else:
			continue
		var corners: Array[Vector3] = []
		for cx in [-size.x * 0.5, size.x * 0.5]:
			for cz in [0.0, size.y + UNIT_FRONT_CLEARANCE]:
				corners.append(to_local(unit.to_global(Vector3(cx, 0.0, cz))))
		var r := Rect2(Vector2(corners[0].x, corners[0].z), Vector2.ZERO)
		for c in corners:
			r = r.expand(Vector2(c.x, c.z))
		shell.blocked_rects.append(r)


func _count_for(data: ItemData) -> int:
	return count_override if count_override > 0 else maxi(2, roundi(data.spawn_count * spawn_scale))


func _spawn_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var list: Array[ItemData] = []
	for s in sections:
		var section_total := 0
		for data in s.catalog.items:
			var n := _count_for(data)
			_total_by_key[data.sort_key] = n
			_placed_by_key[data.sort_key] = 0
			section_total += n
			for i in n:
				list.append(data)
		s.total_items = section_total
		s.placed_items = 0
	# Todas las familias mezcladas: el caos es parte del juego.
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
	_grid.clear()


func _instantiate_item(data: ItemData, jitter: float, variant: int) -> PickableItem:
	var scene: PackedScene = data.scene if data.scene != null else _scene_by_id.get(data.id, item_scene)
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
	# Primero con la separación normal entre objetos; si el suelo está muy lleno (telas largas,
	# muchas piezas), se aprieta un poco. Así nunca queda nada inalcanzable.
	for spacing in [1.15, 0.9, 0.7]:
		for attempt in 160:
			var want_table := false
			match data.spawn_zone:
				ItemData.SpawnZone.TABLE:
					want_table = not tables.is_empty()
				ItemData.SpawnZone.ANY:
					want_table = not tables.is_empty() and rng.randf() < 0.2
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
				var spread := 0.4 + attempt * 0.006   # si el montón está lleno, se ensancha
				var flat := Vector2(c.x + rng.randfn(0.0, spread), c.y + rng.randfn(0.0, spread))
				if not shell.floor_bounds.has_point(flat) or shell.is_blocked(flat, r):
					continue
				p = Vector3(flat.x, h + shell.floor_height(Vector3(flat.x, 0.0, flat.y)), flat.y)
			if _is_free(p, r, spacing):
				_take(p, r)
				return p
	# Último recurso: cualquier punto del suelo que no esté dentro de un mueble (nunca bajo una mesa).
	var b := shell.floor_bounds
	for attempt in 600:
		var flat := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
		if not shell.is_blocked(flat, r):
			var q := Vector3(flat.x, h + shell.floor_height(Vector3(flat.x, 0.0, flat.y)), flat.y)
			_take(q, r)
			return q
	push_warning("Sin sitio libre para %s" % data.id)
	return Vector3(0.0, h, FALLBACK_Z)


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / GRID_CELL), floori(z / GRID_CELL))


func _take(p: Vector3, radius: float) -> void:
	var key := _cell_of(p.x, p.z)
	if not _grid.has(key):
		_grid[key] = []
	(_grid[key] as Array).append(Vector4(p.x, p.y, p.z, radius))
	_grid_max_r = maxf(_grid_max_r, radius)


## ¿Cabe un objeto de radio `radius` en `p`? Solo mira las celdas a las que puede llegar un vecino.
func _is_free(p: Vector3, radius: float, spacing: float = 1.15) -> bool:
	var reach := (radius + _grid_max_r) * spacing
	var c0 := _cell_of(p.x - reach, p.z - reach)
	var c1 := _cell_of(p.x + reach, p.z + reach)
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var cell: Variant = _grid.get(Vector2i(cx, cz))
			if cell == null:
				continue
			for q: Vector4 in cell:
				var min_d := (radius + q.w) * spacing
				if Vector3(q.x, q.y, q.z).distance_squared_to(p) < min_d * min_d:
					return false
	return true


func _make_clusters(rng: RandomNumberGenerator) -> void:
	var b := shell.floor_bounds
	var tries := 0
	while _clusters.size() < CLUSTER_COUNT and tries < 600:
		tries += 1
		var c := Vector2(rng.randf_range(b.position.x + 0.5, b.end.x - 0.5), rng.randf_range(b.position.y + 0.5, b.end.y - 0.5))
		if shell.is_blocked(c, 0.3):
			continue
		# Montones separados entre sí: el desorden ocupa toda la sala, no un rincón.
		var far := true
		for o in _clusters:
			if o.distance_to(c) < 1.6:
				far = false
				break
		if far:
			_clusters.append(c)
	if _clusters.is_empty():
		_clusters.append(Vector2(0.0, 0.8))


# --- Progreso ------------------------------------------------------------

func _emit_progress() -> void:
	Events.room_progress_changed.emit(self, placed_items, total_items)
	Events.progress_changed.emit(placed_items, total_items)


func _emit_section_progress(s: ShopSection) -> void:
	Events.section_progress_changed.emit(s, s.placed_items, s.total_items)


func _on_item_placed(item: PickableItem, _unit: StorageUnit) -> void:
	if item.room != self:
		return
	placed_items += 1
	var key := item.data.sort_key
	_placed_by_key[key] = int(_placed_by_key.get(key, 0)) + 1
	var s := section_for_key(key)
	if s != null:
		s.placed_items += 1
		_emit_section_progress(s)
	_emit_progress()
	# Solo suena un premio por colocación: el final de la mercería, el de la sección o el de la colección.
	if placed_items == total_items and not is_completed:
		is_completed = true
		if s != null and not s.is_completed:
			_complete_section(s)
		_announce_completion()
	elif s != null and s.placed_items == s.total_items and not s.is_completed:
		_complete_section(s)
	elif _placed_by_key[key] == _total_by_key.get(key, -1):
		Events.collection_completed.emit(key)


## Pista al coger algo: su fila destino da un pulso de luz (en una sala grande ayuda a encontrarla).
func _on_item_picked(item: PickableItem) -> void:
	if item.room != self or item.data == null or item.data.treasure:
		return
	var found := find_row(item.data.sort_key)
	if not found.is_empty():
		(found["unit"] as StorageUnit).pulse_row(found["row"])


func _on_item_removed(item: PickableItem, _unit: StorageUnit) -> void:
	if item.room != self:
		return
	placed_items = maxi(0, placed_items - 1)
	var key := item.data.sort_key
	_placed_by_key[key] = maxi(0, int(_placed_by_key.get(key, 0)) - 1)
	var s := section_for_key(key)
	if s != null:
		s.placed_items = maxi(0, s.placed_items - 1)
		_emit_section_progress(s)
	_emit_progress()


## Una sección completa se queda completa (sus premios no se retiran si luego se saca un objeto).
func _complete_section(s: ShopSection) -> void:
	s.is_completed = true
	Events.section_completed.emit(s)
	await get_tree().create_timer(0.7, false).timeout
	s.show_completed(true)
	shell.unlock_decor(s.section_id, true)
	Events.decor_unlocked.emit(self, s.section_id)


func _announce_completion() -> void:
	await get_tree().create_timer(1.6, false).timeout
	Events.room_completed.emit(self)
	# Premio final: guirnaldas de pared a pared y cartel de ABIERTO, cuando ya se ha leído el cartel de
	# mercería ordenada. La puerta, las luces y el cartel de la puerta los abre la escena de apertura
	# (ShopOpening, en main.tscn).
	await get_tree().create_timer(1.6, false).timeout
	shell.unlock_decor(&"bunting", true)
	shell.unlock_decor(&"open_sign", true)
	Events.decor_unlocked.emit(self, &"bunting")


## Coloca de golpe los objetos de una sección (o de toda la mercería con `section` nulo), como si el
## jugador lo hubiera hecho: los eventos son los mismos (contadores, colecciones, premios y guardado).
func solve_instantly(section: ShopSection = null) -> void:
	for it in _items:
		if it.state == PickableItem.State.PLACED:
			continue
		if section != null and section_for_key(it.data.sort_key) != section:
			continue
		if it.state == PickableItem.State.THROWN:
			it.freeze = true
			it._settle()
		var found := find_row(it.data.sort_key)
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
		it.set_pickable(true)
		it.global_transform = unit.slot_transform(row, slot, it)
		Events.item_placed.emit(it, unit)


## Un objeto lanzado que se queda dentro de la estantería de su tipo entra solo en el hueco libre más
## cercano, como una canasta. En la estantería de otro tipo, o con su fila llena, se queda suelto.
func _on_item_landed(it: PickableItem) -> void:
	if it.room != self or it.is_display or it.state != PickableItem.State.LOOSE:
		return
	var q := PhysicsPointQueryParameters3D.new()
	q.position = it.global_position
	q.collision_mask = StorageUnit.AIM_LAYER
	for hit in get_world_3d().direct_space_state.intersect_point(q, 4):
		var body := hit["collider"] as Node
		if body == null or not body.has_meta(StorageUnit.AIM_META):
			continue
		var unit := body.get_meta(StorageUnit.AIM_META) as StorageUnit
		var row := unit.row_for_key(it.data.sort_key)
		var slot := _nearest_free_slot(unit, row, it.global_position, it) if row >= 0 else -1
		if slot < 0:
			return
		unit.reserve(row, slot, it)
		it.container = unit
		it.slot_row = row
		it.slot_index = slot
		it.state = PickableItem.State.MOVING
		it.set_pickable(false)
		var tw := it.create_tween()
		tw.tween_property(it, "global_transform", unit.slot_transform(row, slot, it), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			it.state = PickableItem.State.PLACED
			it.set_pickable(true)
			it.squash(1.0)
			Events.item_placed.emit(it, unit)
			Events.hint_requested.emit(tr("¡Canasta!")))
		return
	_rescue_if_stuck(it)


## Un objeto lanzado que cae detrás de una estantería o un panel (en el hueco con la pared), o que se
## queda metido en el grueso de una pared, no se puede ver ni coger: la partida no se podría terminar.
## Se desliza a un sitio alcanzable y se avisa.
func _rescue_if_stuck(it: PickableItem) -> void:
	for unit in _units:
		var width := 0.0
		if unit is ShelfUnit:
			width = (unit as ShelfUnit).unit_width
		elif unit is PegBoard:
			width = (unit as PegBoard).board_width
		else:
			continue
		var ul := unit.to_local(it.global_position)
		if absf(ul.x) > width * 0.5 + 0.04 or ul.z > 0.04 or ul.z < -0.3 or ul.y > 2.4:
			continue
		var out := unit.to_global(Vector3(clampf(ul.x, -width * 0.5 + 0.15, width * 0.5 - 0.15), 0.0, 0.0))
		var front := unit.global_basis.z.normalized()
		var depth := (unit as ShelfUnit).depth if unit is ShelfUnit else 0.12
		out += front * (depth + 0.35)
		out.y = global_position.y + it.half_height
		_slide_out(it, out, "Se había colado detrás del mueble: aquí lo tienes")
		return
	# Si no hay mueble delante y está metido en el grueso de una pared (un lanzamiento contra el rodapié): se aparta hacia dentro.
	var local := to_local(it.global_position)
	var lim := Vector2(shell.room_w * 0.5, shell.room_d * 0.5) - Vector2.ONE * (it.radius + 0.04)
	var in_wall := absf(local.x) > lim.x or absf(local.z) > lim.y
	if in_wall:
		local = Vector3(clampf(local.x, -lim.x, lim.x), maxf(local.y, it.half_height), clampf(local.z, -lim.y, lim.y))
	# En el suelo junto a la pared y tapado por algo (detrás de la planta, de un cajón o de las cajas): si
	# desde un paso más adentro no se ve, sale al suelo libre.
	var fb := shell.floor_bounds
	if local.y < 0.3 and not fb.has_point(Vector2(local.x, local.z)):
		var inner := Vector2(clampf(local.x, fb.position.x, fb.end.x), clampf(local.z, fb.position.y, fb.end.y))
		var inward := (inner - Vector2(local.x, local.z)).normalized()
		inner += inward * 0.1
		var eye := inner + inward * 0.6
		var q := PhysicsRayQueryParameters3D.create(to_global(Vector3(eye.x, 1.5, eye.y)), to_global(local), 1)
		q.exclude = [it.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			var spot := inner
			for r: float in [0.0, 0.3, 0.6, 0.9, 1.2]:
				var found := false
				for k in 8:
					var c := inner + Vector2.from_angle(TAU * k / 8.0) * r
					if fb.has_point(c) and not shell.is_blocked(c, 0.05):
						spot = c
						found = true
						break
				if found:
					break
			_slide_out(it, to_global(Vector3(spot.x, it.half_height, spot.y)), "Se había quedado escondido: aquí lo tienes")
			return
	if in_wall:
		_slide_out(it, to_global(local), "Se había quedado pegado a la pared: aquí lo tienes")


func _slide_out(it: PickableItem, to: Vector3, message: String) -> void:
	it.state = PickableItem.State.MOVING
	it.set_pickable(false)
	var tw := it.create_tween()
	tw.tween_property(it, "global_position", to, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		it.state = PickableItem.State.LOOSE
		it.set_pickable(true)
		it.squash(0.6)
		Events.hint_requested.emit(tr(message)))


func _nearest_free_slot(unit: StorageUnit, row: int, pos: Vector3, it: PickableItem) -> int:
	var best := -1
	var best_d := INF
	for slot in unit.slots_per_row:
		if not unit.has_room(row, slot):
			continue
		var d := unit.slot_world_position(row, slot, it).distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = slot
	return best


# --- Tesoros ---------------------------------------------------------------

## Tesoros que se pueden apuntar ahora: los escondidos y las copias expuestas (que se examinan).
func get_treasure_candidates() -> Array[PickableItem]:
	var out: Array[PickableItem] = []
	for t in _treasures:
		if is_instance_valid(t) and t.is_pickable():
			out.append(t)
	for id in _displays:
		var d: PickableItem = _displays[id]
		if is_instance_valid(d) and d.is_pickable() and d.visible:
			out.append(d)
	return out


func treasures_total() -> int:
	return _treasure_list.size()


func treasures_found() -> int:
	return _found.size()


func is_treasure_found(id: StringName) -> bool:
	return _found.has(id)


func _spawn_treasures() -> void:
	if shell == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed + 99
	for i in _treasure_list.size():
		shell.set_display_slot(i, _treasure_list[i].color, _treasure_list[i].display_name)
	for i in _treasure_list.size():
		if i >= shell.treasure_spots.size():
			push_warning("No hay sitio para el tesoro %d" % i)
			break
		var item := _instantiate_item(_treasure_list[i], 1.0, 0)
		item.position = shell.treasure_spots[i] + Vector3(0.0, item.half_height, 0.0)
		item.basis = Basis(Vector3.UP, rng.randf() * TAU)
		_treasures.append(item)


func _on_treasure_found(item: PickableItem) -> void:
	if item.room != self or not item.data.treasure or _found.has(item.data.id):
		return
	_found[item.data.id] = true
	_treasures.erase(item)
	_show_display(item.data, true)


## Copia del tesoro sobre la repisa (solo decorativa: se puede examinar pero no recoger).
func _show_display(data: ItemData, animate: bool) -> void:
	if _displays.has(data.id) or shell == null:
		return
	var item := _instantiate_item(data, 1.0, 0)
	item.is_display = true
	item.set_pickable(not animate)
	item.freeze = true
	var slot := shell.display_slot(_treasure_list.find(data))
	item.position = slot + Vector3(0.0, item.half_height, 0.0)
	item.rotation.y = 0.5
	_displays[data.id] = item
	if animate:
		# Aparece cuando el tesoro recién hallado ya se ha enseñado y guardado.
		item.visible = false
		await get_tree().create_timer(1.9, false).timeout
		item.visible = true
		item.play_appear()
		item.set_pickable(true)


## Marca un tesoro como encontrado al cargar una partida: desaparece del sitio donde estaba y se expone.
func _restore_treasure(id: StringName) -> void:
	if _found.has(id):
		return
	for data in _treasure_list:
		if data.id != id:
			continue
		_found[id] = true
		for it in _treasures.duplicate():
			if it.data.id == id:
				_treasures.erase(it)
				it.queue_free()
		_show_display(data, false)


# --- Guardado ------------------------------------------------------------

## Firma del contenido: si cambian las secciones, sus catálogos o los recuentos, un guardado viejo no vale.
func signature() -> String:
	var parts: PackedStringArray = []
	for s in sections:
		parts.append(String(s.section_id))
		for data in s.catalog.items:
			parts.append("%s:%d" % [data.id, _count_for(data)])
	return "%d|%s" % [rng_seed, ",".join(parts)]


## Estado para guardar: qué objetos están colocados (y dónde), dónde están los sueltos y qué tesoros
## y secciones se han completado.
func capture_state() -> Dictionary:
	var items_state: Array = []
	for it in _items:
		if it.state == PickableItem.State.PLACED and it.container != null:
			items_state.append({"s": "p", "u": _units.find(it.container), "r": it.slot_row, "k": it.slot_index})
		else:
			var t := _resting_transform(it)
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
	var done: Array = []
	for s in sections:
		if s.is_completed:
			done.append(String(s.section_id))
	return {"sig": signature(), "completed": is_completed, "sections": done, "items": items_state, "treasures": found_ids}


## Pose con la que se guarda un objeto que no está colocado. Si está en la mano o en el aire (se guarda
## a mitad de un lanzamiento o con algo sostenido) se deja sobre lo que haya debajo, para que al cargar no
## quede flotando.
func _resting_transform(it: PickableItem) -> Transform3D:
	if it.state == PickableItem.State.LOOSE:
		return it.global_transform
	var from := it.global_position + Vector3(0.0, 0.05, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1 | 16)
	# Las estanterias no cuentan: una mano pegada a una balda no debe dejar el objeto dentro de ella.
	var skip: Array[RID] = []
	for unit in _units:
		var body := unit.get_node_or_null("Body") as CollisionObject3D
		if body != null:
			skip.append(body.get_rid())
	query.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ground_y: float = hit["position"].y if not hit.is_empty() else global_position.y
	var yaw := it.global_basis.get_euler().y
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(from.x, ground_y + it.half_height, from.z))


## Restaura el estado guardado. Devuelve false (sin tocar nada) si no encaja con esta mercería.
func apply_state(state: Dictionary) -> bool:
	if state.get("sig", "") != signature():
		return false
	var saved: Array = state.get("items", [])
	if saved.size() != _items.size():
		return false
	placed_items = 0
	for key in _placed_by_key.keys():
		_placed_by_key[key] = 0
	for s in sections:
		s.placed_items = 0
	for i in _items.size():
		var it := _items[i]
		var st: Dictionary = saved[i]
		if st.get("s", "l") == "p":
			var unit_i := int(st.get("u", -1))
			if unit_i < 0 or unit_i >= _units.size():
				continue
			var unit := _units[unit_i]
			var row := int(st["r"])
			var slot := int(st["k"])
			# Un guardado que no encaja con la disposicion actual de la unidad (o editado a mano) no debe romper la carga.
			if row < 0 or row >= unit.rows or slot < 0 or slot >= unit.slots_per_row or not unit.has_room(row, slot):
				continue
			if unit.row_data(row) == null or unit.row_data(row).sort_key != it.data.sort_key:
				continue
			unit.reserve(row, slot, it)
			it.container = unit
			it.slot_row = row
			it.slot_index = slot
			it.state = PickableItem.State.PLACED
			it.global_transform = unit.slot_transform(row, slot, it)
			placed_items += 1
			_placed_by_key[it.data.sort_key] = int(_placed_by_key[it.data.sort_key]) + 1
			var sec := section_for_key(it.data.sort_key)
			if sec != null:
				sec.placed_items += 1
		else:
			var p: Array = st["p"]
			var q: Array = st["q"]
			it.global_transform = Transform3D(
				Basis(Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized()),
				to_global(Vector3(float(p[0]), float(p[1]), float(p[2]))))
	var done: Array = state.get("sections", [])
	for s in sections:
		if done.has(String(s.section_id)) or (s.total_items > 0 and s.placed_items == s.total_items):
			s.show_completed(false)
			shell.unlock_decor(s.section_id, false)
		_emit_section_progress(s)
	is_completed = bool(state.get("completed", false)) or placed_items == total_items
	for id in state.get("treasures", []):
		_restore_treasure(StringName(id))
	if is_completed:
		shell.unlock_decor(&"bunting", false)
		shell.unlock_decor(&"open_sign", false)
		shell.open_shop(false)
	_emit_progress()
	return true

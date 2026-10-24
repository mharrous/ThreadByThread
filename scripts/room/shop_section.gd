class_name ShopSection
extends Node3D
## Sección de la mercería: una familia de objetos (su catálogo y sus tesoros) con los muebles donde se
## ordena, que son sus hijos StorageUnit. Pone su cartel en la pared, un foco sobre cada mueble de pared
## y, al completarla, el premio: los focos se calientan, el cartel lo celebra y aparece una guirnalda.
## El recuento lo lleva RoomController; la sección solo lo guarda y lo enseña.

@export var section_id: StringName = &"yarn"
@export var display_name := "Lanas"
@export var catalog: ItemCatalog
## Tesoros escondidos de esta familia (opcionales: no cuentan para ordenarla).
@export var treasure_catalog: ItemCatalog
## Escena de los objetos de esta sección (y sus tesoros) si su ItemData no trae una propia.
@export var item_scene: PackedScene
@export var accent := Color("9cbfae")
@export var sign_subtitle := ""
## Centro del cartel (coordenadas de la sala). Mira hacia el interior según `sign_yaw_deg`.
@export var sign_position := Vector3(0.0, 2.35, -4.48)
@export var sign_yaw_deg := 0.0
@export var sign_width := 2.0
## Extremos de la guirnalda que aparece al completar la sección (coordenadas de la sala).
@export var bunting_from := Vector3.ZERO
@export var bunting_to := Vector3.ZERO

const SPOT_ENERGY := 0.9
const SPOT_ENERGY_DONE := 1.7
const SPOT_COLOR := Color("ffe2b8")
const SPOT_COLOR_DONE := Color("ffcf8a")
## Grosor de la tabla del cartel (modelo sign_section) y color del "¡sección completa!".
const SIGN_THICK := 0.03
const DONE_INK := Color("962c1f")

var room: RoomController
var units: Array[StorageUnit] = []
var placed_items := 0
var total_items := 0
var is_completed := false

var _spots: Array[SpotLight3D] = []
var _sign_sub: Label3D
var _sign_sub_width := 1.0
var _bunting: Node3D


func _ready() -> void:
	for child in get_children():
		if child is StorageUnit:
			units.append(child)
	_build_spots()
	_build_sign()
	_build_bunting()


func get_units() -> Array[StorageUnit]:
	return units


func has_key(sort_key: StringName) -> bool:
	for data in catalog.items:
		if data.sort_key == sort_key:
			return true
	return false


## Punto del suelo más cercano a `world_pos` de entre los muebles de la sección (para saber cuál tienes delante).
func distance_to(world_pos: Vector3) -> float:
	var best := INF
	for u in units:
		var p := u.global_position
		best = minf(best, Vector2(p.x - world_pos.x, p.z - world_pos.z).length())
	return best


# --- Libro de colecciones ---------------------------------------------------

## Cada tipo de objeto con cuántos hay ya colocados.
func collection_status() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for data in catalog.items:
		var c := room.collection_count(data.sort_key)
		out.append({"label": data.sort_label, "placed": c.x, "total": c.y, "done": c.y > 0 and c.x == c.y, "data": data})
	return out


## Nombre, detalle y si ya se encontró cada tesoro.
func treasure_status() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if treasure_catalog == null:
		return out
	for data in treasure_catalog.items:
		out.append({"name": data.display_name, "detail": data.detail, "found": room.is_treasure_found(data.id), "data": data})
	return out


func treasures_total() -> int:
	return treasure_catalog.items.size() if treasure_catalog != null else 0


func treasures_found() -> int:
	var n := 0
	if treasure_catalog != null:
		for data in treasure_catalog.items:
			if room.is_treasure_found(data.id):
				n += 1
	return n


# --- Premio ------------------------------------------------------------------

## Celebra la sección completa. Sin `animate` (al cargar partida) deja directamente el estado final.
func show_completed(animate: bool) -> void:
	is_completed = true
	_sign_sub.text = "¡sección completa!"
	_sign_sub.modulate = DONE_INK
	ShopSign.fit(_sign_sub, Vector2(_sign_sub_width, 0.09))
	var dur := 1.4 if animate else 0.0
	for spot in _spots:
		if animate:
			var tw := spot.create_tween().set_parallel(true)
			tw.tween_property(spot, "light_energy", SPOT_ENERGY_DONE, dur).set_trans(Tween.TRANS_SINE)
			tw.tween_property(spot, "light_color", SPOT_COLOR_DONE, dur).set_trans(Tween.TRANS_SINE)
		else:
			spot.light_energy = SPOT_ENERGY_DONE
			spot.light_color = SPOT_COLOR_DONE
	if _bunting != null and not _bunting.visible:
		_bunting.visible = true
		if animate:
			_bunting.scale = Vector3.ONE * 0.01
			_bunting.create_tween().tween_property(_bunting, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if animate:
		_sign_sub.scale = Vector3.ONE * 0.6
		_sign_sub.create_tween().tween_property(_sign_sub, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_bunting_visible() -> bool:
	return _bunting != null and _bunting.visible


# --- Construcción --------------------------------------------------------------

## Un foco por mueble de pared, desde el techo y algo separado, apuntando al centro del mueble.
## Sin sombras: son de relleno y hay muchos.
func _build_spots() -> void:
	for u in units:
		if u is TrayUnit:
			continue
		var spot := SpotLight3D.new()
		spot.light_color = SPOT_COLOR
		spot.light_energy = SPOT_ENERGY
		spot.spot_range = 4.6
		spot.spot_angle = 48.0
		spot.spot_attenuation = 0.9
		spot.light_volumetric_fog_energy = 0.0
		add_child(spot)
		var from := u.to_global(Vector3(0.0, 2.85, 1.35))
		var at := u.to_global(Vector3(0.0, 1.0, 0.1))
		spot.global_transform = Transform3D(Basis.looking_at((at - from).normalized(), Vector3.UP), from)
		_spots.append(spot)


## Tabla de roble con la moldura del color de la sección (modelo sign_section) y su icono pirograbado
## a la izquierda; el título y el subtítulo van encima, centrados en el hueco que queda.
func _build_sign() -> void:
	var holder := Node3D.new()
	holder.name = "Sign"
	holder.position = sign_position
	holder.rotation.y = deg_to_rad(sign_yaw_deg)
	add_child(holder)
	var board := ShopSign.skinned("sign_section", {
		"wood": ShopSign.wood(ShopSign.OAK),
		"frame": ShopSign.paint(accent.darkened(0.3), 0.55),
	})
	# El modelo mide 2 m de ancho: se estira en X si la sección pide otro ancho.
	board.scale.x = sign_width / 2.0
	holder.add_child(board)
	var face := SIGN_THICK * 0.5 + 0.001
	var icon_x := -sign_width * 0.5 + 0.24
	holder.add_child(ShopSign.icon(ShopSign.SECTION_ICONS.get(section_id, "yarn"), Vector3(icon_x, 0.0, face), 1.12))
	var text_left := icon_x + 0.17
	var text_right := sign_width * 0.5 - 0.08
	var text_x := (text_left + text_right) * 0.5
	var text_w := text_right - text_left
	var title := ShopSign.label(display_name.to_upper(), &"title", 80, ShopSign.INK, 0.0024, Vector2(text_w, 0.17))
	title.position = Vector3(text_x, 0.045, face + 0.002)
	holder.add_child(title)
	_sign_sub = ShopSign.label(sign_subtitle, &"hand", 44, ShopSign.INK_SOFT, 0.0019, Vector2(text_w, 0.09))
	_sign_sub_width = text_w
	_sign_sub.position = Vector3(text_x, -0.105, face + 0.002)
	holder.add_child(_sign_sub)


func _build_bunting() -> void:
	if bunting_from == bunting_to:
		return
	var palette: Array[Color] = [accent, Color("e8a0b0"), Color("f2c14e"), Color("8ec5e8"), Color("c9a2e0"), Color("f5f0e6")]
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color("5a4630")
	cord.roughness = 0.8
	# Centrada en su punto medio para que el rebote al aparecer crezca desde ahí.
	var mid := (bunting_from + bunting_to) * 0.5
	_bunting = Bunting.build(bunting_from - mid, bunting_to - mid, 0.14, palette, hash(section_id), cord)
	_bunting.name = "SectionBunting"
	_bunting.position = mid
	_bunting.visible = false
	add_child(_bunting)

class_name CardboardBox
extends Node3D
## Una caja de cartón vacía tirada por el suelo de la tienda (la reparte ShopBoxes). Con E se aplana
## (salta, se aplasta con un crujido y queda un cartón plano) y pasa a la mano del jugador (BoxCarrier).
## El cartón se puede soltar en el suelo (E) y volver a coger, o dejar en el montón para tirar de junto
## a la puerta. Va en coordenadas de ShopBoxes (su padre).

enum State { LOOSE, FLAT, CARRIED, STACKED }

const MODEL := "res://art/models/cardboard_box.glb"
## Medidas del modelo con tamaño 1 (ancho, alto, fondo).
const BOX := Vector3(0.62, 0.42, 0.5)

var index := 0
var state := State.LOOSE
var size := 1.0
## Tumbada de lado (la boca hacia un lado) en vez de derecha.
var tipped := false
var boxes: ShopBoxes
## Mientras dura la animación de aplanarse: aún no se puede llevar.
var busy := false

var _squash: Node3D
var _visual: Node3D
var _sheet: Node3D
var _body: StaticBody3D
var _area: Area3D
var _area_shape: BoxShape3D


func setup(i: int, at: Vector3, yaw: float, is_tipped: bool, scale_factor: float) -> void:
	index = i
	position = at
	rotation.y = yaw
	tipped = is_tipped
	size = scale_factor


func _ready() -> void:
	var dims := _dims()
	_squash = Node3D.new()
	_squash.name = "Squash"
	add_child(_squash)
	# Centro de la caja: girar alrededor de él para tumbarla.
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position = Vector3(0.0, dims.y * 0.5, 0.0)
	if tipped:
		_visual.rotation.x = PI * 0.5
	_squash.add_child(_visual)
	if ResourceLoader.exists(MODEL):
		var model := (load(MODEL) as PackedScene).instantiate() as Node3D
		model.scale = Vector3.ONE * size
		model.position = Vector3(0.0, -BOX.y * size * 0.5, 0.0)
		MaterialLibrary.apply(model, MaterialLibrary.get_material(&"cardboard"))
		_visual.add_child(model)
	_sheet = _build_sheet()
	_sheet.visible = false
	add_child(_sheet)
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = ItemHolder.MASK_WORLD
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = dims
	cs.shape = bs
	cs.position = Vector3(0.0, dims.y * 0.5, 0.0)
	_body.add_child(cs)
	add_child(_body)
	_area = Area3D.new()
	_area.name = "PickArea"
	_area.collision_layer = ItemHolder.MASK_PICK
	_area.collision_mask = 0
	_area.monitoring = false
	var acs := CollisionShape3D.new()
	_area_shape = BoxShape3D.new()
	_area_shape.size = dims + Vector3.ONE * 0.08
	acs.shape = _area_shape
	acs.position = Vector3(0.0, dims.y * 0.5, 0.0)
	_area.add_child(acs)
	add_child(_area)


## Tamaño que ocupa en el suelo (ancho, alto, fondo), derecha o tumbada.
func _dims() -> Vector3:
	var d := BOX * size
	return Vector3(d.x, d.z, d.y) if tipped else d


## Lo que muestra el HUD al apuntarle con las manos vacías.
func interact_info() -> Dictionary:
	if state == State.LOOSE:
		return {"key": "E", "action": "Aplanar caja", "title": "Caja de cartón vacía",
			"detail": "Aplánala y déjala junto a la puerta para tirarla", "hint": "", "kind": "pick"}
	return {"key": "E", "action": "Coger cartón", "title": "Cartón aplanado",
		"detail": "Al montón de junto a la puerta", "hint": "", "kind": "pick"}


func interact(holder: ItemHolder) -> void:
	if holder != null and holder.carrier != null and not busy and state in [State.LOOSE, State.FLAT]:
		holder.carrier.take(self)


## Se aplana donde está: da un saltito, se aplasta con un crujido y una nube de polvo, y queda el cartón.
func flatten() -> void:
	if state != State.LOOSE:
		return
	busy = true
	state = State.FLAT
	_set_solid(false)
	if boxes != null:
		boxes.drop_items_on(self)
		boxes.drop_boxes_on(self)
	var tw := create_tween()
	tw.tween_property(_squash, "position:y", 0.07, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_squash, "scale", Vector3(0.92, 1.12, 0.92), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_squash, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_squash, "scale", Vector3(1.35, 0.06, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	AudioManager.play(&"cardboard_fold", global_position + Vector3.UP * 0.2, -2.0, 0.08)
	await tw.finished
	if boxes != null:
		boxes.puff(position + Vector3(0.0, 0.03, 0.0))
	_squash.visible = false
	_sheet.visible = true
	_sheet.scale = Vector3(1.08, 1.0, 1.08)
	var pop := create_tween()
	pop.tween_property(_sheet, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	busy = false


## Plana de golpe (cargar partida o atajos de prueba).
func flatten_instantly() -> void:
	state = State.FLAT
	busy = false
	_set_solid(false)
	_squash.visible = false
	_sheet.visible = true
	_sheet.scale = Vector3.ONE


## Cartón aplanado en el suelo (soltado por el jugador): se puede volver a coger con E.
func lay_flat(at: Vector3, yaw: float) -> void:
	state = State.FLAT
	transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.0, at.z))
	_sheet.position = Vector3(0.0, sheet_size().y * 0.5, 0.0)
	_sheet.basis = Basis.IDENTITY
	_set_pickable(true)
	_area_shape.size = sheet_size() + Vector3(0.06, 0.1, 0.06)
	(_area.get_child(0) as Node3D).position = Vector3(0.0, 0.05, 0.0)


## En la mano o en el montón: no se apunta.
func set_carried() -> void:
	state = State.CARRIED
	_set_pickable(false)


func set_stacked() -> void:
	state = State.STACKED
	_set_pickable(false)


## Largo, grosor y ancho del cartón aplanado (lados de la caja desplegados en dos capas).
func sheet_size() -> Vector3:
	return Vector3((BOX.x + BOX.z) * 0.95, 0.024, BOX.y * 1.3) * Vector3(size, 1.0, size)


## El cartón plano (su origen en el centro): dos capas con el pliegue en medio y una tira de cinta.
func _build_sheet() -> Node3D:
	var root := Node3D.new()
	root.name = "Sheet"
	var s := sheet_size()
	root.position = Vector3(0.0, s.y * 0.5, 0.0)
	var card := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	card.mesh = bm
	card.material_override = MaterialLibrary.get_material(&"cardboard")
	root.add_child(card)
	var fold := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.008, 0.002, s.z * 0.98)
	fold.mesh = fm
	fold.position = Vector3(s.x * 0.08, s.y * 0.5, 0.0)
	var fold_mat := StandardMaterial3D.new()
	fold_mat.albedo_color = Color("8a6238")
	fold_mat.roughness = 1.0
	fold.material_override = fold_mat
	root.add_child(fold)
	var tape := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(s.x * 0.62, 0.003, 0.055)
	tape.mesh = tm
	tape.position = Vector3(-s.x * 0.06, s.y * 0.5 + 0.0012, s.z * 0.12)
	var tape_mat := StandardMaterial3D.new()
	tape_mat.albedo_color = Color("d9b98a")
	tape_mat.roughness = 0.35
	tape.material_override = tape_mat
	root.add_child(tape)
	return root


func _set_solid(on: bool) -> void:
	_body.collision_layer = ItemHolder.MASK_WORLD if on else 0


func _set_pickable(on: bool) -> void:
	_area.collision_layer = ItemHolder.MASK_PICK if on else 0

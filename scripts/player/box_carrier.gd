class_name BoxCarrier
extends Node
## Llevar un cartón aplanado (hijo del ItemHolder, que le pasa el control mientras lo lleva). Al coger
## una caja de cartón (CardboardBox) primero se aplana donde está y luego viene a la mano: va de pie bajo
## el brazo derecho. Clic apuntando al montón de junto a la puerta lo deja allí (ShopBoxes.stack); E lo
## suelta plano en el suelo, delante.

## Cuánto hay que acertar al montón (distancia del rayo de la mirada) y desde qué distancia; muy cerca
## del montón vale aunque no se apunte.
const PILE_AIM := 0.8
const PILE_REACH := 3.0
const PILE_NEAR := 1.4
const TAKE_TIME := 0.35
## Sitio del cartón respecto a la cámara (girada solo en horizontal): abajo a la derecha.
const HOLD := Vector3(0.46, -0.78, -0.42)

var active := false
var box: CardboardBox
var boxes: ShopBoxes

var _holder: ItemHolder
var _player: Player
var _camera: Camera3D
var _take_t := 1.0
var _from := Transform3D.IDENTITY
var _last_info: Dictionary = {}
var _guide_on := false


func _ready() -> void:
	_holder = get_parent() as ItemHolder
	_player = _holder.get_parent() as Player
	_camera = _player.get_node("CameraRig/Camera3D")


## Coge una caja (la aplana antes si está montada) o un cartón ya aplanado del suelo.
func take(b: CardboardBox) -> void:
	if active or b == null:
		return
	box = b
	boxes = b.boxes
	active = true
	_take_t = -1.0
	Events.held_item_changed.emit(null)
	if b.state == CardboardBox.State.LOOSE:
		_publish({"key": "", "action": "", "title": "", "detail": "", "hint": "", "kind": "hold"})
		await b.flatten()
		if not active or box != b:
			return
	AudioManager.play(&"pick", b.global_position, -4.0)
	b.set_carried()
	_from = b.global_transform
	_take_t = 0.0
	if boxes != null and boxes.stacked_count() == 0:
		Events.hint_requested.emit("Llévalo al montón de junto a la puerta y haz clic para dejarlo")


## E: lo suelta plano en el suelo, delante del jugador.
func drop() -> void:
	if not active or box == null or _take_t < 0.0:
		return
	var fwd := _flat_forward()
	var at := boxes.to_local(_player.global_position + fwd * 0.85)
	box.lay_flat(boxes._inside(at), atan2(fwd.x, fwd.z) + PI * 0.5)
	AudioManager.play(&"cardboard_drop", box.global_position, -4.0, 0.08)
	boxes.changed.emit()
	_end()


## Suelta lo que lleve sin animar (la escena de apertura o coger otra cosa).
func release() -> void:
	if not active:
		return
	if box != null and _take_t >= 0.0:
		drop()
	else:
		_end()


## Clic: al montón si se apunta a él (o se está al lado).
func click() -> void:
	if not active or box == null or _take_t < 1.0:
		return
	if _at_pile():
		var b := box
		_end()
		boxes.stack(b)
	else:
		Events.hint_requested.emit("Déjalo en el montón de junto a la puerta de la calle")


## Cada fotograma con el cartón en la mano (lo llama ItemHolder._process).
func tick(delta: float) -> void:
	if box == null or not is_instance_valid(box):
		_end()
		return
	if _take_t < 0.0:
		return
	var cam := _camera.global_transform
	var fwd := _flat_forward()
	var yaw_basis := Basis(Vector3.UP, atan2(-fwd.x, -fwd.z))
	# De pie bajo el brazo: el largo hacia delante, el ancho hacia arriba, algo inclinado.
	var sheet_basis := yaw_basis * Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)) * Basis(Vector3.RIGHT, 0.12) * Basis(Vector3.UP, 0.25)
	var target := Transform3D(sheet_basis, cam.origin + yaw_basis * HOLD)
	if _take_t < 1.0:
		_take_t = minf(_take_t + delta / TAKE_TIME, 1.0)
		var e := _take_t * _take_t * (3.0 - 2.0 * _take_t)
		var xf := _from.interpolate_with(target, e)
		xf.origin.y += sin(PI * e) * 0.25
		box.global_transform = xf
	else:
		box.global_transform = box.global_transform.interpolate_with(target, 1.0 - exp(-20.0 * delta))
	var at_pile := _at_pile()
	if at_pile:
		_publish({"key": "Clic", "action": "Dejar en el montón para tirar", "title": "", "detail": "", "hint": "", "kind": "place"})
	else:
		_publish({"key": "", "action": "Cartón: al montón de junto a la puerta   ·   E soltar", "title": "", "detail": "", "hint": "", "kind": "hold"})
	_set_guide(not at_pile)


func _at_pile() -> bool:
	if boxes == null:
		return false
	var top := boxes.pile_target()
	var feet := _player.global_position
	if Vector2(top.x - feet.x, top.z - feet.z).length() < PILE_NEAR:
		return true
	var cam := _camera.global_transform
	var to := top - cam.origin
	if to.length() > PILE_REACH:
		return false
	var fwd := -cam.basis.z
	var along := to.dot(fwd)
	return along > 0.0 and (to - fwd * along).length() < PILE_AIM


func _flat_forward() -> Vector3:
	var f := -_camera.global_basis.z
	f.y = 0.0
	if f.length() < 0.05:
		f = -_player.global_basis.z
		f.y = 0.0
	return f.normalized()


func _end() -> void:
	active = false
	box = null
	_take_t = 1.0
	_set_guide(false)
	_last_info = {}
	Events.target_changed.emit({})


func _publish(info: Dictionary) -> void:
	if info != _last_info:
		_last_info = info
		Events.target_changed.emit(info)


func _set_guide(on: bool) -> void:
	if on == _guide_on:
		return
	_guide_on = on
	Events.guide_target_changed.emit(on, boxes.pile_target() if on and boxes != null else Vector3.ZERO)

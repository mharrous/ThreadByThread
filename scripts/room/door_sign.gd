class_name DoorSign
extends Node3D
## Placa esmaltada de CERRADO/ABIERTO colgada de un cordel tras el cristal de la puerta de la calle.
## Tiene una cara de cada: "CERRADO" mira a la sala hasta la apertura, y al abrir la placa da media
## vuelta sobre su cordel. El origen es el punto del gancho (el giro es alrededor de su vertical).

const CLOSED_TEXT := "CERRADO"
const OPEN_TEXT := "ABIERTO"
## Centro de la placa respecto al gancho (ver make_signs.py, sign_door).
const PLATE_Y := -0.30
const FACE_Z := 0.0064

## Lo que se lee desde la sala ("CERRADO" o "ABIERTO"). Asignarlo da la vuelta a la placa de golpe.
var text: String = CLOSED_TEXT:
	set(value):
		set_open(value == OPEN_TEXT, false)
	get:
		return OPEN_TEXT if _open else CLOSED_TEXT

var _open := false
var _spin: Node3D
var _tween: Tween


func _init() -> void:
	name = "DoorSign"
	_spin = Node3D.new()
	_spin.name = "Spin"
	add_child(_spin)
	_spin.add_child(ShopSign.skinned("sign_door", {
		"enamel": ShopSign.paint(ShopSign.ENAMEL, 0.32),
		"rim": ShopSign.paint(ShopSign.GREEN, 0.35),
	}))
	var max_size := Vector2(0.23, 0.085)
	var closed := ShopSign.label(CLOSED_TEXT, &"title", 64, ShopSign.BURGUNDY, 0.0022, max_size)
	closed.name = "Closed"
	closed.position = Vector3(0.0, PLATE_Y, FACE_Z)
	_spin.add_child(closed)
	var open := ShopSign.label(OPEN_TEXT, &"title", 64, ShopSign.GREEN, 0.0022, max_size)
	open.name = "Open"
	open.position = Vector3(0.0, PLATE_Y, -FACE_Z)
	open.rotation.y = PI
	_spin.add_child(open)


## Da la vuelta a la placa. Con `animate`, un giro de media vuelta con un pequeño vaivén al final.
func set_open(open: bool, animate: bool) -> void:
	if _spin == null:
		_open = open
		return
	if open == _open and not animate:
		_spin.rotation.y = PI if open else 0.0
		return
	_open = open
	var target := PI if open else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or not is_inside_tree():
		_spin.rotation.y = target
		return
	# Media vuelta que se pasa un poco y vuelve, como una placa que gira colgada de su cordel.
	_tween = create_tween()
	_tween.tween_property(_spin, "rotation:y", target + (0.32 if open else -0.32), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_spin, "rotation:y", target - (0.12 if open else -0.12), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_spin, "rotation:y", target, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

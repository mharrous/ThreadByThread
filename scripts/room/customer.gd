class_name Customer
extends Node3D
## La primera clienta (art/models/customer.glb, de art/blender/make_customer.py). La mueve quien la crea
## (ShopOpening) poniendo `velocity`; ella sola elige la animación: "walk" al andar (al ritmo de su
## velocidad), "idle" quieta, y "look_around" cuando se le pide mirar las estanterías.
## No tiene cuerpo físico: no empuja ni toca los objetos de la tienda.

const MODEL := "res://art/models/customer.glb"
## Velocidad a la que el ciclo de paso del modelo va a su ritmo natural (m/s).
const WALK_NATURAL_SPEED := 1.4
const BLEND := 0.25

var velocity := Vector3.ZERO

var _anim: AnimationPlayer
var _looking := false


func _ready() -> void:
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		return
	for anim_name in [&"walk", &"idle"]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(func(n: StringName):
		if n == &"look_around":
			_looking = false)
	_play(&"idle")


func _process(delta: float) -> void:
	position += velocity * delta
	var speed := velocity.length()
	if speed > 0.05:
		_looking = false
		_play(&"walk", speed / WALK_NATURAL_SPEED)
	elif not _looking:
		_play(&"idle")


## Gira la cabeza a un lado y al otro (unos 5 s); luego vuelve a quedarse quieta.
func look_around() -> void:
	_looking = true
	_play(&"look_around")


func is_walking() -> bool:
	return _anim != null and _anim.current_animation == &"walk"


func current_animation() -> StringName:
	return _anim.current_animation if _anim != null else &""


func _play(anim_name: StringName, speed := 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, BLEND)
	_anim.speed_scale = speed

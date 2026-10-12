class_name Player
extends CharacterBody3D
## Controlador en primera persona.
## La física corre a tick fijo; la cámara se interpola entre ticks para que el
## movimiento sea fluido a cualquier tasa de refresco del monitor.

@export var walk_speed := 3.0
@export var run_speed := 4.9
@export var crouch_speed := 1.5
@export var acceleration := 12.0
@export var gravity := 22.0
@export var stand_eye_height := 1.62
@export var crouch_eye_height := 1.02
@export var stand_height := 1.75
@export var crouch_height := 1.1
@export var base_fov := 68.0

const BASE_SENSITIVITY := 0.0022
const MAX_PITCH := 1.5

var yaw := 0.0
var pitch := 0.0
var crouching := false

var _eye := 1.62
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _bob_phase := 0.0
var _bob_amount := 0.0
var _step_dist := 0.0
var _fov := 75.0
var _capsule: CapsuleShape3D

@onready var rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var _shape_node: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(&"player")
	_capsule = _shape_node.shape as CapsuleShape3D
	_eye = stand_eye_height
	_fov = base_fov
	_prev_pos = global_position
	_curr_pos = global_position
	_update_rig(0.0)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := BASE_SENSITIVITY * GameSettings.mouse_sensitivity
		yaw -= motion.relative.x * s
		pitch = clampf(pitch - motion.relative.y * s, -MAX_PITCH, MAX_PITCH)


func _physics_process(delta: float) -> void:
	_update_crouch()
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif Input.is_action_pressed(&"sprint"):
		speed = run_speed
	var target := wish * speed
	var k := 1.0 - exp(-acceleration * delta)
	velocity.x = lerpf(velocity.x, target.x, k)
	velocity.z = lerpf(velocity.z, target.z, k)
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	_prev_pos = _curr_pos
	move_and_slide()
	_curr_pos = global_position


func _process(delta: float) -> void:
	_update_rig(delta)


## Teletransporte instantáneo (usado por pruebas y futuras puertas).
func teleport(pos: Vector3) -> void:
	global_position = pos
	_prev_pos = pos
	_curr_pos = pos
	velocity = Vector3.ZERO
	_update_rig(0.0)


## Orienta la cámara hacia un punto del mundo.
func look_at_point(point: Vector3) -> void:
	var from := global_position + Vector3(0.0, _eye, 0.0)
	var d := point - from
	yaw = atan2(-d.x, -d.z)
	pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -MAX_PITCH, MAX_PITCH)
	_update_rig(0.0)


func _update_crouch() -> void:
	var want := Input.is_action_pressed(&"crouch")
	if want == crouching:
		return
	if not want and not _can_stand():
		return
	crouching = want
	var h := crouch_height if crouching else stand_height
	_capsule.height = h
	_shape_node.position.y = h * 0.5


func _can_stand() -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.3,
		global_position + Vector3.UP * (stand_height + 0.05), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _update_rig(delta: float) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	var moving := horiz > 0.3 and is_on_floor()

	var target_eye := crouch_eye_height if crouching else stand_eye_height
	_eye = lerpf(_eye, target_eye, 1.0 - exp(-10.0 * delta))

	# Balanceo de cabeza y pasos.
	var bob_target := clampf(horiz / run_speed, 0.0, 1.0) if moving else 0.0
	_bob_amount = lerpf(_bob_amount, bob_target, 1.0 - exp(-8.0 * delta))
	_bob_phase += horiz * delta * 2.1
	var bob := Vector3(cos(_bob_phase) * 0.007, sin(_bob_phase * 2.0) * 0.011, 0.0) * _bob_amount
	if moving:
		_step_dist += horiz * delta
		var stride := 1.8 if Input.is_action_pressed(&"sprint") and not crouching else 1.35
		if _step_dist > stride:
			_step_dist = 0.0
			AudioManager.play(&"step", null, -6.0 if crouching else 0.0)
	else:
		_step_dist = 0.0

	var f := Engine.get_physics_interpolation_fraction()
	var p := _prev_pos.lerp(_curr_pos, f)
	var yaw_basis := Basis(Vector3.UP, yaw)
	rig.global_transform = Transform3D(yaw_basis, p + Vector3(0.0, _eye, 0.0) + yaw_basis * bob)
	camera.rotation = Vector3(pitch, 0.0, 0.0)

	var sprinting := Input.is_action_pressed(&"sprint") and horiz > run_speed * 0.7
	_fov = lerpf(_fov, base_fov + (3.0 if sprinting else 0.0), 1.0 - exp(-6.0 * delta))
	camera.fov = _fov

class_name PickableItem
extends StaticBody3D
## Objeto recogible. No usa físicas dinámicas: es un cuerpo estático que el
## ItemHolder mueve con animaciones controladas. Esto mantiene miles de objetos baratos.

enum State { LOOSE, HELD, MOVING, PLACED }

const BASE_RADIUS := 0.055
const LAYER_ITEMS := 2

var data: ItemData
var state: State = State.LOOSE
var radius := BASE_RADIUS
var rest_yaw := 0.0

## Hueco de estantería que ocupa (si está colocado).
var shelf: ShelfUnit = null
var slot_row := -1
var slot_index := -1

var _base_scale := Vector3.ONE
var _hl_tween: Tween
var _squash_tween: Tween

@onready var _mesh: MeshInstance3D = $Mesh


func setup(item_data: ItemData, size_jitter: float = 1.0) -> void:
	data = item_data
	radius = item_data.radius * size_jitter
	rest_yaw = randf() * TAU
	_base_scale = Vector3.ONE * (radius / BASE_RADIUS)
	_mesh.scale = _base_scale
	_mesh.material_override = item_data.get_material()
	_mesh.set_instance_shader_parameter(&"variation", randf() * 100.0)


func set_pickable(on: bool) -> void:
	collision_layer = LAYER_ITEMS if on else 0


func set_highlighted(on: bool) -> void:
	if _hl_tween:
		_hl_tween.kill()
	_hl_tween = create_tween()
	_hl_tween.tween_method(_apply_highlight, 1.0 - float(on), float(on), 0.12)


## Aplastamiento elástico al encajar (strength 1 = completo).
func squash(strength: float = 1.0) -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_method(_apply_squash, strength, 0.0, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _apply_highlight(value: float) -> void:
	_mesh.set_instance_shader_parameter(&"highlight", value)


func _apply_squash(amount: float) -> void:
	var sy := 1.0 - 0.16 * amount
	var sxz := 1.0 + 0.10 * amount
	_mesh.scale = _base_scale * Vector3(sxz, sy, sxz)
	# Mantiene la base apoyada mientras se aplasta.
	_mesh.position.y = -radius * (1.0 - sy)

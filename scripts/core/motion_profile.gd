class_name MotionProfile
extends Resource
## Cómo se mueve y suena un material al lanzarlo: rebote, fricción, aplastamiento
## elástico y sonido de impacto. Cada ItemData apunta a un perfil; añadir un material
## nuevo (botón de metal, tela, madera...) = nuevo .tres, sin tocar código.

@export var id: StringName = &"default"
## Rebote: 0 = se queda pegado, 1 = rebote perfecto.
@export_range(0.0, 1.0) var bounce := 0.5
@export_range(0.0, 2.0) var friction := 0.8
@export var mass := 0.05
## Frenado en el aire y del giro (cuánto rueda antes de pararse).
@export var linear_damp := 0.3
@export var angular_damp := 2.2
## Intensidad del aplastamiento al impactar (0 = rígido).
@export var squash := 1.0
@export var squash_stiffness := 420.0
@export var squash_damping := 17.0
## Impactos más lentos que esto no suenan ni animan.
@export var min_impact_speed := 0.7
## Por debajo de esta velocidad (m/s) durante un rato, el objeto se considera quieto.
@export var rest_speed := 0.12
## Giro que recibe al lanzarlo.
@export var throw_spin := 1.0
## Banco de sonido de AudioManager: bounce_soft, bounce_hard, bounce_wood, bounce_metal, bounce_fabric.
@export var impact_sound: StringName = &"bounce_soft"

var _physics_material: PhysicsMaterial


func get_physics_material() -> PhysicsMaterial:
	if _physics_material == null:
		_physics_material = PhysicsMaterial.new()
		_physics_material.bounce = bounce
		_physics_material.friction = friction
	return _physics_material

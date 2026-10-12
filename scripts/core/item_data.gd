class_name ItemData
extends Resource
## Datos de un tipo de objeto. Añadir una variante = crear un .tres nuevo, sin código.
## Los objetos con el mismo `sort_key` pertenecen a la misma fila de estantería.

enum Family { YARN, THREAD, BUTTON, FABRIC, RIBBON, ACCESSORY }

const YARN_SHADER := preload("res://shaders/yarn.gdshader")

## Material compartido por todas las instancias del mismo tipo.
static var _material_cache: Dictionary = {}

@export var id: StringName = &""
@export var display_name := "Ovillo de lana"
@export var detail := ""
@export var family: Family = Family.YARN
@export var sort_key: StringName = &""
@export var sort_label := ""
@export var color := Color.WHITE
## Radio base en metros.
@export var radius := 0.055
## Densidad de las hebras en el shader (más alto = hilo más fino).
@export var thread_density := 26.0
## Escena propia; si es null se usa la escena por defecto de la sala.
@export var scene: PackedScene
## Cómo rebota, rueda y suena al lanzarlo. Null = perfil por defecto.
@export var motion: MotionProfile

static var _default_motion: MotionProfile


func get_motion() -> MotionProfile:
	if motion != null:
		return motion
	if _default_motion == null:
		_default_motion = MotionProfile.new()
	return _default_motion


func get_material() -> Material:
	var key := String(id)
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = YARN_SHADER
	mat.set_shader_parameter(&"base_color", color)
	mat.set_shader_parameter(&"thread_density", thread_density)
	_material_cache[key] = mat
	return mat

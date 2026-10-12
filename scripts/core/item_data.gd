class_name ItemData
extends Resource
## Datos de un tipo de objeto. Añadir una variante = crear un .tres nuevo, sin código.
## Los objetos con el mismo `sort_key` pertenecen a la misma fila/celda de un contenedor.
## Cubre todas las familias: lanas, hilos (carretes), botones, telas, cintas y accesorios.

enum Family { YARN, THREAD, BUTTON, FABRIC, RIBBON, ACCESSORY }
enum Shape { SPHERE, CYLINDER, BOX }
## Dónde aparece desordenado dentro de la sala.
enum SpawnZone { ANY, FLOOR, TABLE }

const YARN_SHADER := preload("res://shaders/yarn.gdshader")

@export_group("Identidad")
@export var id: StringName = &""
@export var display_name := "Ovillo de lana"
@export var detail := ""
@export var family: Family = Family.YARN
@export var sort_key: StringName = &""
@export var sort_label := ""
## Objeto especial escondido (colecciones y secretos).
@export var treasure := false

@export_group("Geometría")
@export var shape: Shape = Shape.SPHERE
## Radio: de la esfera, o del cilindro.
@export var radius := 0.055
## Cilindro: y = alto. Caja: tamaño completo en x, y, z (en la pose natural del modelo).
@export var size := Vector3(0.11, 0.11, 0.11)
## Giro del collider respecto al eje por defecto (un cilindro tumbado, por ejemplo).
@export var shape_rotation_deg := Vector3.ZERO
## Distancia del centro a la superficie en la que reposa. -1 = se calcula de la forma.
@export var rest_half_height := -1.0
## Radio del volumen de puntería (más generoso que el físico, para objetos pequeños).
@export var pick_radius := 0.075
## Modelos 3D (glb). Si hay varios, cada objeto usa uno al azar (variedad visual).
@export var variants: Array[PackedScene] = []
@export var model_scale := 1.0
## En estanterías: true = alineado con el mueble; false = giro libre (ovillos, botones).
@export var align_on_shelf := false
## Punto del que cuelga en un panel de ganchos (espacio del modelo).
@export var hang_offset := Vector3.ZERO

@export_group("Material")
## "" = por familia. Valores: yarn, thread, fabric, ribbon, wood, plastic, metal, glass, pearl, paper, cardboard, cloth.
@export var material_kind: StringName = &""
@export var color := Color.WHITE
@export var color_b := Color.WHITE
@export var color_c := Color.WHITE
@export var accent_color := Color("e8d3a8")
@export var accent_kind: StringName = &"wood"
## Dibujo de la tela/cinta: 0 liso, 1 rayas, 2 vichy, 3 lunares, 4 flores, 5 tartán, 6 vaquero, 7 terciopelo, 8 pana, 9 encaje.
@export var pattern := 0
@export var pattern_scale := 1.0
## Cómo se proyecta el dibujo: 0 plano XZ (telas dobladas), 1 cilíndrico alrededor de Z (rollos), 2 plano XY.
@export var pattern_mapping := 0
@export var metallic := 0.0
@export var roughness := 0.6
## Densidad de las hebras en el shader (más alto = hilo más fino).
@export var thread_density := 26.0

@export_group("Movimiento y reparto")
## Escena propia; si es null se usa la escena por defecto de la sala.
@export var scene: PackedScene
## Cómo rebota, rueda y suena al lanzarlo. Null = perfil por defecto.
@export var motion: MotionProfile
@export var spawn_count := 1
@export var spawn_zone: SpawnZone = SpawnZone.ANY

static var _default_motion: MotionProfile


func get_motion() -> MotionProfile:
	if motion != null:
		return motion
	if _default_motion == null:
		_default_motion = MotionProfile.new()
	return _default_motion


## Altura del centro sobre la superficie en la que reposa (pose natural).
func get_rest_half_height() -> float:
	if rest_half_height >= 0.0:
		return rest_half_height
	match shape:
		Shape.SPHERE:
			return radius
		_:
			return size.y * 0.5


## Radio de la esfera que contiene al objeto (para efectos, separaciones y huecos).
func get_bounding_radius() -> float:
	match shape:
		Shape.SPHERE:
			return radius
		Shape.CYLINDER:
			return sqrt(radius * radius + size.y * size.y * 0.25)
		_:
			return size.length() * 0.5


## Material de una superficie del modelo ("main", "accent", "metal", "glass").
func get_surface_material(surface_name: String) -> Material:
	return ItemMaterials.surface_material(self, surface_name)


## Material principal (compatibilidad con el ovillo, que usa un único material).
func get_material() -> Material:
	return ItemMaterials.surface_material(self, "main")

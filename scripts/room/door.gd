class_name Door
extends Node3D
## Puerta corredera entre salas. Cerrada mientras la sala no esté ordenada; al desbloquearla
## desliza la hoja dentro del muro con un sonido de madera y una pequeña animación.
## Origen: centro de la abertura, en el plano del muro. El eje de apertura es +Z local.

signal opened

const WIDTH := 1.1
const HEIGHT := 2.1
const LEAF_T := 0.05

var locked := true
var is_open := false

var _leaf: StaticBody3D
var _plaque: Label3D
var _plaque_bg: MeshInstance3D
var _lock_node: Node3D


func _ready() -> void:
	_leaf = StaticBody3D.new()
	_leaf.collision_layer = 1
	_leaf.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LEAF_T, HEIGHT, WIDTH + 0.08)
	cs.shape = bs
	cs.position = Vector3(0, HEIGHT * 0.5, 0)
	_leaf.add_child(cs)
	add_child(_leaf)

	var wood := MaterialLibrary.get_tinted(&"shelf", Color(0.78, 0.6, 0.42))
	_visual_box(Vector3(LEAF_T, HEIGHT, WIDTH + 0.08), Vector3(0, HEIGHT * 0.5, 0), wood)
	# Entrepaños en relieve de la hoja
	var panel := MaterialLibrary.get_tinted(&"shelf", Color(0.7, 0.52, 0.36))
	for py in [0.55, 1.5]:
		for pz in [-0.26, 0.26]:
			_visual_box(Vector3(LEAF_T + 0.012, 0.7 if py < 1.0 else 0.62, 0.38), Vector3(0, py + 0.2, pz), panel)
	# Tirador
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("c9a24a")
	brass.metallic = 1.0
	brass.roughness = 0.3
	_visual_box(Vector3(0.05, 0.05, 0.05), Vector3(-0.04, 1.0, 0.32), brass)
	_visual_box(Vector3(0.05, 0.05, 0.05), Vector3(0.04, 1.0, 0.32), brass)

	# Candado y cartel por el lado de la sala que se está ordenando (-X local... el interior).
	_lock_node = Node3D.new()
	_lock_node.position = Vector3(-LEAF_T * 0.5 - 0.004, 1.35, 0.0)
	add_child(_lock_node)
	var shackle := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.035
	tor.outer_radius = 0.05
	tor.rings = 20
	tor.ring_segments = 8
	shackle.mesh = tor
	shackle.material_override = brass
	shackle.rotation_degrees = Vector3(0, 90, 0)
	shackle.position = Vector3(-0.012, 0.06, 0)
	_lock_node.add_child(shackle)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.03, 0.1, 0.09)
	body.mesh = bb
	body.material_override = brass
	body.position = Vector3(-0.012, -0.01, 0)
	_lock_node.add_child(body)

	_plaque = Label3D.new()
	_plaque.text = "Ordena esta sala\npara abrir la puerta"
	_plaque.font_size = 28
	_plaque.pixel_size = 0.0011
	_plaque.outline_size = 0
	_plaque.modulate = Color("fff3dc")
	_plaque.rotation_degrees.y = -90.0
	_plaque.position = Vector3(-LEAF_T * 0.5 - 0.009, 0.95, 0.0)
	add_child(_plaque)
	_plaque_bg = MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.006, 0.17, 0.46)
	_plaque_bg.mesh = pb
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.22, 0.15, 0.1)
	bg_mat.roughness = 0.8
	_plaque_bg.material_override = bg_mat
	_plaque_bg.position = Vector3(-LEAF_T * 0.5 - 0.004, 0.95, 0.0)
	add_child(_plaque_bg)


func _visual_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_leaf.add_child(mi)


## Abre la puerta (con animación y sonido). `animate = false` la deja abierta al instante (cargar partida).
func unlock(animate: bool = true) -> void:
	if is_open:
		return
	locked = false
	is_open = true
	_plaque.text = "Abierta"
	_lock_node.visible = false
	var target := Vector3(0, 0, WIDTH + 0.12)
	if not animate:
		_leaf.position = target
		_finish_open()
		return
	AudioManager.play(&"door_open", global_position)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_leaf, "position", target, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_finish_open)


func _finish_open() -> void:
	_leaf.collision_layer = 0
	_plaque.visible = false
	_plaque_bg.visible = false
	opened.emit()

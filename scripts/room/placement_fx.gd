class_name PlacementFx
extends Node3D
## Efectos visuales de colocación: ráfaga de chispas suaves y onda circular.
## Escucha Events.item_placed; el gameplay no lo llama directamente.

const POOL_SIZE := 4
const DUST_POOL := 6

var _bursts: Array[CPUParticles3D] = []
var _rings: Array[MeshInstance3D] = []
var _dust: Array[CPUParticles3D] = []
var _next := 0
var _next_dust := 0


func _ready() -> void:
	var spark_tex := GradientTexture2D.new()
	spark_tex.fill = GradientTexture2D.FILL_RADIAL
	spark_tex.fill_from = Vector2(0.5, 0.5)
	spark_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	spark_tex.gradient = g
	spark_tex.width = 64
	spark_tex.height = 64

	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.albedo_texture = spark_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	quad.material = spark_mat

	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.2))

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.048
	ring_mesh.outer_radius = 0.054
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6

	for i in POOL_SIZE:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 14
		p.lifetime = 0.75
		p.mesh = quad
		p.direction = Vector3.UP
		p.spread = 75.0
		p.initial_velocity_min = 0.25
		p.initial_velocity_max = 0.7
		p.gravity = Vector3(0, -1.2, 0)
		p.scale_amount_curve = shrink
		p.color_ramp = fade
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_bursts.append(p)

		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.visible = false
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rmat
		add_child(ring)
		_rings.append(ring)

	# Polvillo suave en los rebotes.
	var dust_fade := Gradient.new()
	dust_fade.set_color(0, Color(1, 1, 1, 0.55))
	dust_fade.set_color(1, Color(1, 1, 1, 0))
	var dust_quad := QuadMesh.new()
	dust_quad.size = Vector2(0.07, 0.07)
	dust_quad.material = spark_mat
	for i in DUST_POOL:
		var d := CPUParticles3D.new()
		d.emitting = false
		d.one_shot = true
		d.explosiveness = 1.0
		d.amount = 7
		d.lifetime = 0.5
		d.mesh = dust_quad
		d.direction = Vector3.UP
		d.spread = 85.0
		d.initial_velocity_min = 0.12
		d.initial_velocity_max = 0.4
		d.gravity = Vector3(0, -0.15, 0)
		d.scale_amount_min = 0.7
		d.scale_amount_max = 1.5
		d.color_ramp = dust_fade
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		_dust.append(d)

	Events.item_placed.connect(_on_item_placed)
	Events.item_bounced.connect(_on_item_bounced)


func _on_item_bounced(item: PickableItem, speed: float, pos: Vector3, _sound: StringName) -> void:
	if speed < 1.4:
		return
	var d := _dust[_next_dust]
	_next_dust = (_next_dust + 1) % DUST_POOL
	d.global_position = pos
	d.color = item.data.color.lerp(Color.WHITE, 0.75)
	d.amount = clampi(int(speed * 1.6), 4, 10)
	d.restart()
	d.emitting = true


func _on_item_placed(item: PickableItem, _unit: StorageUnit) -> void:
	var color := item.data.color.lightened(0.35)
	var pos := item.global_position
	var idx := _next
	_next = (_next + 1) % POOL_SIZE

	var p := _bursts[idx]
	p.global_position = pos + Vector3(0, item.radius * 0.6, 0.02)
	p.color = color
	p.restart()
	p.emitting = true

	var ring := _rings[idx]
	var mat := ring.material_override as StandardMaterial3D
	ring.global_position = pos - Vector3(0, item.radius - 0.004, 0)
	ring.scale = Vector3(0.6, 0.6, 0.6)
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	ring.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.9, 1.0, 1.9), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func(): ring.visible = false)

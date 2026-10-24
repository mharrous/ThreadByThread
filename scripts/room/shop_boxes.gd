class_name ShopBoxes
extends Node3D
## Cajas de cartón vacías tiradas por la tienda (CardboardBox). El jugador las aplana con E, lleva el
## cartón (BoxCarrier) al rincón de junto a la puerta de la calle y lo deja con un clic en el montón para
## tirar, apoyado en la pared. Con todas en el montón se atan con un cordel. Es la tercera cosa que hace
## falta para abrir la tienda (ShopOpening), con todo ordenado y el suelo barrido.
## Va en coordenadas de la sala (hijo de RoomShell); lo que guarda está en capture_state().

## Dónde están tiradas: x, z, giro y, tumbada de lado y tamaño.
const SPOTS := [
	[-1.0, -3.0, 0.4, false, 0.78],
	[2.4, -3.2, -0.7, true, 0.72],
	[-4.6, 0.3, 1.1, false, 0.8],
	[2.75, -0.2, 0.25, false, 0.7],
	[1.2, 3.2, 2.2, true, 0.76],
]
## Montón para tirar: los cartones de pie apoyados en la pared este, al sur de la puerta de la calle.
const PILE_AT := Vector3(5.95, 0.0, 3.2)
## Inclinación hacia la pared y separación entre cartones.
const PILE_LEAN := 0.16
const PILE_STEP := 0.034
const DUST := Color("cdb48e")

## Cambia cuántos hay en el montón o dónde está algún cartón (algo que guardar).
signal changed

var boxes: Array[CardboardBox] = []
var _twine: Node3D
var _marker: Node3D
var _note: Label3D


## Zonas del suelo ocupadas (para que no caigan objetos ni papelitos debajo de las cajas ni del montón).
static func blocked_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for s: Array in SPOTS:
		var r := 0.42 * float(s[4]) + 0.12
		out.append(Rect2(s[0] - r, s[1] - r, r * 2.0, r * 2.0))
	out.append(Rect2(PILE_AT.x - 0.55, PILE_AT.z - 0.5, 0.55, 1.0))
	return out


func _ready() -> void:
	for i in SPOTS.size():
		var s: Array = SPOTS[i]
		var b := CardboardBox.new()
		b.name = "Box%d" % i
		b.setup(i, Vector3(s[0], 0.0, s[1]), s[2], s[3], s[4])
		b.boxes = self
		add_child(b)
		boxes.append(b)
	_build_marker()
	_build_twine()


func total() -> int:
	return boxes.size()


func stacked_count() -> int:
	var n := 0
	for b in boxes:
		if b.state == CardboardBox.State.STACKED:
			n += 1
	return n


## Todas en el montón.
func is_done() -> bool:
	return stacked_count() == boxes.size()


## Centro del montón (global): donde se apunta para dejar el cartón y adonde va la flecha del borde.
func pile_target() -> Vector3:
	return to_global(PILE_AT + Vector3(-0.12, 0.35, 0.0))


## Sitio del cartón k-ésimo en el montón: de pie, el largo a lo largo de la pared, apoyado en ella.
func pile_slot(k: int, b: CardboardBox) -> Transform3D:
	var s := b.sheet_size()
	var lean := PILE_LEAN + 0.015 * float(k % 2)
	# Ejes del cartón: largo (x) a lo largo de la pared, ancho (z) hacia arriba inclinado hacia la pared
	# (+x) y grosor (y) hacia la pared.
	var up := Vector3(sin(lean), cos(lean), 0.0)
	var along := Vector3(0.0, 0.0, 1.0)
	var basis := Basis(along, up.cross(along), up)
	# Borde de abajo en el suelo, cada cartón algo más separado de la pared que el anterior.
	var foot := PILE_AT + Vector3(-0.05 - k * PILE_STEP - s.z * sin(lean) * 0.5, 0.0, (k % 3 - 1) * 0.025)
	return Transform3D(basis, foot + up * s.z * 0.5)


## Deja el cartón en el montón: vuela desde la mano, se apoya y suena. Con el último, el cordel.
func stack(b: CardboardBox) -> void:
	var k := stacked_count()
	b.set_stacked()
	var to := pile_slot(k, b)
	var from := b.transform
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var e := 1.0 - pow(1.0 - t, 3.0)
		var xf := from.interpolate_with(to, e)
		xf.origin.y += sin(PI * t) * 0.12
		b.transform = xf, 0.0, 1.0, 0.32)
	await tw.finished
	AudioManager.play(&"cardboard_drop", b.global_position + Vector3.UP * 0.3, -2.0, 0.08)
	_emit_progress()
	changed.emit()
	if is_done():
		await _wait(0.35)
		_tie(true)
		Events.boxes_done.emit()


## Tienda abierta al cargar (o atajo de pruebas): todas aplanadas y atadas en el montón.
func finish_instantly() -> void:
	for b in boxes:
		if b.state != CardboardBox.State.STACKED:
			b.flatten_instantly()
			b.set_stacked()
	for b in boxes:
		b.transform = pile_slot(b.index, b)
	_tie(false)
	_emit_progress()


## Objetos que se habían quedado encima de una caja: al aplanarla, caen.
func drop_items_on(b: CardboardBox) -> void:
	var room := get_parent().get_parent() as RoomController
	if room == null:
		return
	var center := b.global_position
	for it in room.get_items():
		if it.state != PickableItem.State.LOOSE:
			continue
		var d := it.global_position - center
		if Vector2(d.x, d.z).length() < 0.45 * b.size + 0.1 and d.y > 0.12:
			it.launch(Vector3.ZERO, Vector3.ZERO)


# --- Guardado ---------------------------------------------------------------

## Qué cajas están en el montón (en orden) y dónde está cada cartón suelto por el suelo.
func capture_state() -> Dictionary:
	var stacked: Array = []
	var order: Array = boxes.filter(func(b: CardboardBox): return b.state == CardboardBox.State.STACKED)
	order.sort_custom(func(a: CardboardBox, c: CardboardBox): return a.position.x > c.position.x)
	for b: CardboardBox in order:
		stacked.append(b.index)
	var flat: Array = []
	for b in boxes:
		if b.state in [CardboardBox.State.FLAT, CardboardBox.State.CARRIED]:
			flat.append([b.index, snappedf(b.position.x, 0.01), snappedf(b.position.z, 0.01), snappedf(b.rotation.y, 0.01)])
	return {"stacked": stacked, "flat": flat}


func apply_state(state: Dictionary) -> void:
	var k := 0
	for v in state.get("stacked", []):
		var i := int(v)
		if i < 0 or i >= boxes.size() or boxes[i].state == CardboardBox.State.STACKED:
			continue
		boxes[i].flatten_instantly()
		boxes[i].set_stacked()
		boxes[i].transform = pile_slot(k, boxes[i])
		k += 1
	for v in state.get("flat", []):
		if not (v is Array) or (v as Array).size() < 4:
			continue
		var i := int(v[0])
		if i < 0 or i >= boxes.size() or boxes[i].state != CardboardBox.State.LOOSE:
			continue
		boxes[i].flatten_instantly()
		boxes[i].lay_flat(_inside(Vector3(float(v[1]), 0.0, float(v[2]))), float(v[3]))
	if is_done():
		_tie(false)
	_emit_progress()


## Un punto dentro del suelo de la sala.
func _inside(p: Vector3) -> Vector3:
	var shell := get_parent() as RoomShell
	if shell == null:
		return p
	var r := shell.floor_bounds.grow(0.2)
	return Vector3(clampf(p.x, r.position.x, r.end.x), 0.0, clampf(p.z, r.position.y, r.end.y))


func emit_progress() -> void:
	_emit_progress()


func _emit_progress() -> void:
	Events.boxes_progress_changed.emit(stacked_count(), boxes.size())
	_marker.visible = not is_done()


# --- Piezas -----------------------------------------------------------------

## Rincón del montón: una alfombrilla de cartón marcada en el suelo y una nota en la pared.
func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "PileMarker"
	add_child(_marker)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.78, 0.45, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var edge := 0.025
	var w := 0.5
	var d := 0.95
	var c := PILE_AT + Vector3(-w * 0.5 - 0.02, 0.004, 0.0)
	for e in [[Vector3(w, 0.002, edge), Vector3(0, 0, -d * 0.5)], [Vector3(w, 0.002, edge), Vector3(0, 0, d * 0.5)],
			[Vector3(edge, 0.002, d), Vector3(-w * 0.5, 0, 0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = e[0]
		mi.mesh = bm
		mi.material_override = mat
		mi.position = c + e[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker.add_child(mi)
	# Nota de papel clavada en la pared con el texto escrito a mano.
	var paper := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.01, 0.2, 0.34)
	paper.mesh = pm
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color("fbf3e2")
	paper_mat.roughness = 0.95
	paper.material_override = paper_mat
	paper.position = Vector3(PILE_AT.x - 0.03, 1.05, PILE_AT.z)
	paper.rotation.x = 0.04
	_marker.add_child(paper)
	_note = Label3D.new()
	_note.text = "Cartón\npara tirar"
	_note.font_size = 40
	_note.font = UiStyle.font(&"hand")
	_note.pixel_size = 0.0021
	_note.modulate = Color("6b4a2b")
	_note.outline_size = 0
	_note.line_spacing = -4.0
	_note.position = Vector3(PILE_AT.x - 0.037, 1.05, PILE_AT.z)
	_note.rotation.y = -PI * 0.5
	_note.rotation.z = 0.04
	_marker.add_child(_note)


## Cordel atado alrededor del montón (dos vueltas), oculto hasta que están todos.
func _build_twine() -> void:
	_twine = Node3D.new()
	_twine.name = "Twine"
	_twine.visible = false
	add_child(_twine)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c8ad7f")
	mat.roughness = 0.9
	# Inclinado como los cartones, con la base en el centro del montón.
	var n := SPOTS.size()
	var thick := 0.05 + PILE_STEP * n
	var h := 0.0
	for s: Array in SPOTS:
		h = maxf(h, CardboardBox.BOX.y * 1.3 * float(s[4]))
	_twine.position = PILE_AT + Vector3(-0.05 - PILE_STEP * (n - 1) * 0.5, 0.0, 0.0)
	_twine.rotation.z = -PILE_LEAN
	for z in [-0.2, 0.2]:
		for part in [[Vector3(thick, 0.012, 0.014), Vector3(0.0, h + 0.004, z)],
				[Vector3(0.012, h, 0.014), Vector3(-thick * 0.5, h * 0.5, z)]]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = part[0]
			mi.mesh = bm
			mi.material_override = mat
			mi.position = part[1]
			_twine.add_child(mi)
	# Lazo en la cara de delante, arriba.
	for side in [-1.0, 1.0]:
		var bow := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.012
		tm.outer_radius = 0.03
		bow.mesh = tm
		bow.material_override = mat
		bow.position = Vector3(-thick * 0.5 - 0.01, h - 0.05, 0.2 + side * 0.03)
		bow.rotation = Vector3(0.0, 0.0, PI * 0.5)
		bow.scale = Vector3(1.0, 1.0, 0.6)
		_twine.add_child(bow)


func _tie(animate: bool) -> void:
	_twine.visible = true
	_marker.visible = false
	if animate:
		_twine.scale = Vector3(1.0, 1.0, 0.2)
		var tw := create_tween()
		tw.tween_property(_twine, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		AudioManager.play(&"decor_unlock", pile_target(), -6.0, 0.0)


## Nube de polvo pequeña al aplanar una caja (motas de cartón que se abren en el suelo).
func puff(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "CardPuff"
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 22
	p.lifetime = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.3
	p.emission_ring_inner_radius = 0.15
	p.emission_ring_height = 0.02
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0.0, -0.2, 0.0)
	p.damping_min = 1.0
	p.damping_max = 1.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(DUST, 0.0), Color(DUST, 0.5), Color(DUST, 0.0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	tex.gradient = soft
	m.albedo_texture = tex
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

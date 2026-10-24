class_name TargetPointer
extends Control
## Con un objeto en la mano, si su estantería queda fuera de la vista (o a la espalda), una flecha suave
## en el borde de la pantalla señala hacia ella. Aparece tras un momento sostenido, para no estorbar a
## quien ya sabe adónde va, y se apaga en cuanto la estantería entra en pantalla.
## Con la escoba en la mano señala lo que pida Sweeper (Events.guide_target_changed): la papelera con el
## recogedor lleno o el papelito más cercano cuando quedan pocos.

const GUIDE_COLOR := Color("e9c98f")

## Segundos con el objeto en la mano antes de que la flecha pueda salir.
const DELAY := 1.2
## Margen desde el borde de la pantalla (píxeles de la vista base).
const MARGIN := 64.0
## Distancia dentro del borde a la que se considera "en pantalla".
const ON_SCREEN_INSET := 0.08

var _item: PickableItem
var _target := Vector3.ZERO
var _color := Color.WHITE
var _held_time := 0.0
var _alpha := 0.0
var _pos := Vector2.ZERO
var _angle := 0.0
var _bob := 0.0
var _guide_on := false
var _guide := Vector3.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Events.held_item_changed.connect(_on_held_item_changed)
	Events.guide_target_changed.connect(_on_guide_changed)


func _on_guide_changed(active: bool, pos: Vector3) -> void:
	if active and not _guide_on:
		_held_time = 0.0
	_guide_on = active
	_guide = pos
	if active:
		set_process(true)


func _on_held_item_changed(item) -> void:
	_item = null
	_held_time = 0.0
	set_process(true)
	if item == null or not is_instance_valid(item) or item.data == null or item.room == null or item.data.treasure:
		return
	var found: Dictionary = item.room.find_row(item.data.sort_key)
	if found.is_empty():
		return
	var unit: StorageUnit = found["unit"]
	var row: int = found["row"]
	var slot := unit.first_free_slot(row)
	_target = unit.slot_world_position(row, maxi(slot, 0), item)
	var section: ShopSection = item.room.section_for_key(item.data.sort_key)
	_color = section.accent.lightened(0.25) if section != null else Color("f2a65a")
	_item = item


func _process(delta: float) -> void:
	var want := 0.0
	var cam := get_viewport().get_camera_3d()
	var has_item := is_instance_valid(_item) and _item.state == PickableItem.State.HELD
	if (has_item or _guide_on) and cam != null:
		if not has_item:
			_target = _guide
			_color = GUIDE_COLOR
		_held_time += delta
		var rect := get_viewport().get_visible_rect()
		var center := rect.size * 0.5
		var behind := cam.is_position_behind(_target)
		var p := cam.unproject_position(_target)
		var inset := rect.size * ON_SCREEN_INSET
		var on_screen := not behind and Rect2(inset, rect.size - inset * 2.0).has_point(p)
		if not on_screen and _held_time > DELAY:
			want = 1.0
			var dir := p - center
			if behind:
				dir = -dir
			if dir.length_squared() < 1.0:
				dir = Vector2.DOWN
			# Hasta el borde del rectángulo con margen, en la dirección del objetivo.
			var half := center - Vector2(MARGIN, MARGIN)
			var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
			_pos = center + dir * k
			_angle = dir.angle()
	_alpha = move_toward(_alpha, want, delta * (3.0 if want > 0.0 else 5.0))
	_bob += delta
	if _alpha > 0.0 or want > 0.0:
		queue_redraw()
	elif not is_instance_valid(_item) and not _guide_on:
		# Sin objeto en la mano y ya apagada: duerme hasta que se coja otro.
		queue_redraw()
		set_process(false)


func _draw() -> void:
	if _alpha <= 0.001:
		return
	var a := _alpha * 0.85
	var push := sin(_bob * 4.0) * 5.0
	var fwd := Vector2.from_angle(_angle)
	var side := fwd.orthogonal()
	var tip := _pos + fwd * (14.0 + push)
	var pts := PackedVector2Array([tip, tip - fwd * 22.0 + side * 15.0, tip - fwd * 15.0, tip - fwd * 22.0 - side * 15.0])
	var shadow := PackedVector2Array()
	for v in pts:
		shadow.append(v + Vector2(2, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.3 * a))
	draw_colored_polygon(pts, Color(_color, a))
	draw_circle(_pos - fwd * 6.0, 5.0, Color(_color, a * 0.7))

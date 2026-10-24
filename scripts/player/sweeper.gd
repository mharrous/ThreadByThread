class_name Sweeper
extends Node
## Barrer en primera persona (hijo del ItemHolder, que le pasa el control mientras tiene las herramientas).
## Con la escoba y el recogedor en la mano (ShopSweep): el recogedor va por el suelo delante del jugador,
## la escoba donde mira; mantener el clic da escobazos y cada uno mete en el recogedor los papelitos a su
## alcance. Apuntando a la papelera con algo en el recogedor, el clic lo vacía. E las devuelve a la pared.

## Distancia al jugador (en el suelo) a la que puede ir la escoba.
const REACH_MIN := 0.75
const REACH_MAX := 1.55
## Un escobazo: la escoba va de delante hacia el recogedor y vuelve.
const STROKE_TIME := 0.42
## Momento del escobazo en que los papelitos entran en el recogedor.
const STROKE_HIT := 0.5
## La boca del recogedor queda a esta distancia del punto de barrido, hacia el jugador.
const PAN_BACK := 0.3
## Cuánto hay que acertar a la papelera (distancia del rayo de la mirada a su boca) y desde qué distancia.
const BIN_AIM := 0.42
const BIN_REACH := 2.4
## Con menos papelitos que estos en el suelo, la flecha del borde señala al más cercano.
const GUIDE_BELOW := 10
## Al coger las herramientas: vuelan de la pared a la mano.
const TAKE_TIME := 0.4

var active := false
var sweep: ShopSweep

var _holder: ItemHolder
var _player: Player
var _camera: Camera3D
var _target := Vector3.ZERO
var _fwd := Vector3.FORWARD
var _stroke := -1.0
var _stroke_hit_done := false
var _take_t := 1.0
var _broom_from := Transform3D.IDENTITY
var _pan_from := Transform3D.IDENTITY
var _last_info: Dictionary = {}
var _full_hint_shown := false
var _guide_on := false
var _guide_pos := Vector3.ZERO


func _ready() -> void:
	_holder = get_parent() as ItemHolder
	_player = _holder.get_parent() as Player
	_camera = _player.get_node("CameraRig/Camera3D")


## Coge la escoba y el recogedor de la pared.
func take(s: ShopSweep) -> void:
	if active or s == null or s.held:
		return
	sweep = s
	active = true
	_stroke = -1.0
	_full_hint_shown = false
	s.take()
	_broom_from = s.broom.transform
	_pan_from = s.dustpan.transform
	_take_t = 0.0
	_aim(true)
	Events.held_item_changed.emit(null)
	if not GameSettings.tutorial_done or s.loads_done == 0:
		Events.hint_requested.emit(tr("Mantén el clic para barrer · Recogedor lleno: a la papelera"))


## Las devuelve a la pared (E, coger otra cosa o la escena de apertura).
func put_back() -> void:
	if not active:
		return
	active = false
	_stroke = -1.0
	_set_guide(false)
	_last_info = {}
	Events.target_changed.emit({})
	sweep.put_back()


## Cada fotograma con las herramientas en la mano (lo llama ItemHolder._process).
func tick(delta: float) -> void:
	if sweep == null or not is_instance_valid(sweep):
		active = false
		return
	_aim(false, delta)
	var at_bin := _aiming_at_bin()
	var dumping := sweep.is_dumping()
	if not dumping and _take_t >= 1.0 and Input.is_action_pressed(&"place") and not _player.input_locked:
		if at_bin and sweep.pan_count() > 0:
			_stroke = -1.0
			sweep.dump()
			dumping = true
		elif _stroke < 0.0:
			_stroke = 0.0
			_stroke_hit_done = false
			AudioManager.play(&"sweep", sweep.to_global(_target), -6.0, 0.08)
	if _stroke >= 0.0:
		_stroke += delta / STROKE_TIME
		if not _stroke_hit_done and _stroke >= STROKE_HIT:
			_stroke_hit_done = true
			_hit()
		if _stroke >= 1.0:
			_stroke = -1.0
	_pose(delta, dumping)
	_publish(at_bin)
	_update_guide()


## Punto de barrido: donde la mirada corta el suelo, a una distancia cómoda del jugador.
func _aim(snap: bool, delta: float = 0.0) -> void:
	var cam := _camera.global_transform
	var o := sweep.to_local(cam.origin)
	var dir := sweep.global_basis.inverse() * (-cam.basis.z)
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.05:
		flat = sweep.global_basis.inverse() * _player.global_basis * Vector3.FORWARD
		flat.y = 0.0
	flat = flat.normalized()
	var feet := sweep.to_local(_player.global_position)
	feet.y = 0.0
	var want := feet + flat * REACH_MAX
	if dir.y < -0.05:
		var hit := o + dir * (-o.y / dir.y)
		hit.y = 0.0
		var d := clampf((hit - feet).length(), REACH_MIN, REACH_MAX)
		want = feet + flat * d
	var shell := sweep.get_parent() as RoomShell
	if shell != null:
		var b := shell.floor_bounds.grow(0.2)
		want.x = clampf(want.x, b.position.x, b.end.x)
		want.z = clampf(want.z, b.position.y, b.end.y)
	if snap:
		_target = want
		_fwd = flat
	else:
		var k := 1.0 - exp(-14.0 * delta)
		_target = _target.lerp(want, k)
		_fwd = _fwd.slerp(flat, k).normalized() if _fwd.dot(flat) > -0.9 else flat


## La mitad del escobazo: lo que hay alrededor de la escoba entra en el recogedor.
func _hit() -> void:
	var mouth := _target - _fwd * PAN_BACK
	var got := sweep.sweep_at(_target, mouth)
	if got > 0:
		AudioManager.play(&"sweep", sweep.to_global(_target), -2.0, 0.1, 1.12)
		_full_hint_shown = false
	elif sweep.pan_full() and not _full_hint_shown:
		_full_hint_shown = true
		AudioManager.play(&"deny", sweep.to_global(mouth), -8.0)
		Events.hint_requested.emit(tr("Recogedor lleno: vacíalo en la papelera"))


## La escoba va al punto de barrido inclinada hacia la mano del jugador; el recogedor, en el suelo,
## con la boca hacia la escoba.
func _pose(delta: float, dumping: bool) -> void:
	var feet := sweep.to_local(_player.global_position)
	var right := Vector3(-_fwd.z, 0.0, _fwd.x)
	var hand := Vector3(feet.x, 1.05, feet.z) + right * 0.28 + _fwd * 0.15
	var push := 0.0
	if _stroke >= 0.0:
		# De delante hacia el recogedor (rápido) y vuelta (lento).
		push = sin(PI * clampf(_stroke / STROKE_HIT, 0.0, 1.0) * 0.5) if _stroke < STROKE_HIT else 1.0 - smoothstep(STROKE_HIT, 1.0, _stroke)
	var foot := _target + _fwd * lerpf(0.22, -0.12, push)
	var pan_at := _target - _fwd * PAN_BACK
	# Encima de la alfombra el suelo está algo más alto: ni la escoba ni el recogedor se meten en ella.
	var shell := sweep.get_parent() as RoomShell
	if shell != null:
		foot.y = shell.floor_height(foot)
		pan_at.y = shell.floor_height(pan_at)
	var up := (hand - foot).normalized()
	var face := (-_fwd - up * up.dot(-_fwd)).normalized()
	var broom_xf := Transform3D(Basis(up.cross(face), up, face).orthonormalized(), foot)
	var pan_xf := Transform3D(Basis(Vector3.UP, atan2(_fwd.x, _fwd.z)), pan_at)
	if _take_t < 1.0:
		_take_t = minf(_take_t + delta / TAKE_TIME, 1.0)
		var e := _take_t * _take_t * (3.0 - 2.0 * _take_t)
		var lift := sin(PI * e) * 0.5
		broom_xf = _broom_from.interpolate_with(broom_xf, e)
		broom_xf.origin.y += lift
		pan_xf = _pan_from.interpolate_with(pan_xf, e)
		pan_xf.origin.y += lift
		sweep.broom.transform = broom_xf
		sweep.dustpan.transform = pan_xf
		return
	var k := 1.0 - exp(-24.0 * delta)
	sweep.broom.transform = sweep.broom.transform.interpolate_with(broom_xf, k)
	if not dumping:
		sweep.dustpan.transform = sweep.dustpan.transform.interpolate_with(pan_xf, 1.0 - exp(-12.0 * delta))


func _aiming_at_bin() -> bool:
	if sweep.pan_count() == 0:
		return false
	var cam := _camera.global_transform
	var top := sweep.bin_top()
	var to := top - cam.origin
	if to.length() > BIN_REACH:
		return false
	var fwd := -cam.basis.z
	var along := to.dot(fwd)
	if along <= 0.0:
		return false
	return (to - fwd * along).length() < BIN_AIM


func _publish(at_bin: bool) -> void:
	# Una sola línea bajo la mira: las herramientas ya ocupan la parte de abajo de la pantalla.
	var n := sweep.pan_count()
	var load_text := tr("Recogedor %d / %d") % [n, ShopSweep.PAN_CAPACITY]
	var info := {"title": "", "detail": "", "hint": ""}
	if sweep.is_dumping():
		info.merge({"key": "", "action": "", "kind": "hold"})
	elif at_bin:
		info.merge({"key": "Clic", "action": "Vaciar en la papelera", "kind": "place"})
	elif sweep.pan_full():
		info.merge({"key": "", "action": "Recogedor lleno: vacíalo en la papelera", "kind": "deny"})
	elif sweep.scraps_left() == 0 and n > 0:
		info.merge({"key": "", "action": "Suelo limpio: vacía el recogedor en la papelera", "kind": "hold"})
	else:
		info.merge({"key": "Clic", "action": tr("Barrer   ·   %s   ·   E dejar") % load_text, "kind": "hold"})
	if info != _last_info:
		_last_info = info
		Events.target_changed.emit(info)


## La flecha del borde: a la papelera con el recogedor lleno (o el suelo ya limpio), o al papelito más
## cercano cuando quedan pocos.
func _update_guide() -> void:
	if sweep.pan_count() > 0 and (sweep.pan_full() or sweep.scraps_left() == 0):
		_set_guide(true, sweep.bin_top())
	elif sweep.scraps_left() > 0 and sweep.scraps_left() < GUIDE_BELOW:
		_set_guide(true, sweep.nearest_scrap(_player.global_position))
	else:
		_set_guide(false)


func _set_guide(on: bool, pos: Vector3 = Vector3.ZERO) -> void:
	if on == _guide_on and (not on or pos.distance_squared_to(_guide_pos) < 0.01):
		return
	_guide_on = on
	_guide_pos = pos
	Events.guide_target_changed.emit(on, pos)

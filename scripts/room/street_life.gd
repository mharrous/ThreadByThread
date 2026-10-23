class_name StreetLife
extends Node3D
## La vida de la calle vista desde la ventana: coches, furgonetas, bicicletas (con timbre), motos,
## gente paseando y perros (que a veces ladran). Es tranquila: un suceso cada 14-40 s, como mucho
## tres a la vez, nunca el mismo tipo dos veces seguidas, y las bocinas, timbres y ladridos
## son ocasionales. El sonido sale por el bus "Outdoor" (filtrado, como a través del cristal).
## La calle corre a lo largo de Z; el carril cercano (X=-9.0) va hacia -Z y el lejano hacia +Z.

const NEAR_LANE_X := -9.0
const FAR_LANE_X := -11.6
const NEAR_WALK_X := -6.4
const FAR_WALK_X := -14.2
const Z_LIMIT := 75.0

@export var enabled := true
@export var min_gap := 14.0
@export var max_gap := 40.0
@export var first_event_delay := 6.0

const WEIGHTS := {
	&"car": 38, &"walker": 22, &"dogwalker": 10, &"bike": 14, &"moto": 8, &"van": 8,
}
const CAR_COLORS: Array[Color] = [
	Color("b3202a"), Color("2d4f8a"), Color("e6e6e2"), Color("2b2b2f"), Color("6f7c86"),
	Color("d9a62a"), Color("2f6b4a"), Color("8a4b2d"), Color("c9cdd1"),
]
const SHIRTS: Array[Color] = [
	Color("c0392b"), Color("2e86c1"), Color("f4d03f"), Color("27ae60"), Color("8e44ad"), Color("f5f5f0"), Color("e67e22"), Color("34495e"),
]
const PANTS: Array[Color] = [Color("2c3e50"), Color("4a4a52"), Color("6e5a46"), Color("1f2a3a"), Color("8a8f98")]
const SKINS: Array[Color] = [Color("f0c8a0"), Color("d9a67a"), Color("b07a52"), Color("7a4e32"), Color("f6d7bd")]
const HAIRS: Array[Color] = [Color("2b1b10"), Color("5a3a1e"), Color("c9a05a"), Color("1a1a1a"), Color("8a8a8a"), Color("7a2a14")]
const FUR: Array[Color] = [Color("b98a55"), Color("e8dcc4"), Color("3a2c22"), Color("8a6a45"), Color("d9b27a")]

var _next := 6.0
var _last_kind: StringName = &""
var _actors: Array[StreetActor] = []


func _ready() -> void:
	_next = first_event_delay


func _process(delta: float) -> void:
	# Hasta que los sonidos estén sintetizados no pasa nada: así el primer coche ya suena.
	if not enabled or not AudioManager.ready_to_play:
		return
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(min_gap, max_gap)
		if _actors.size() < 3:
			spawn(_pick_kind())


func _pick_kind() -> StringName:
	var total := 0
	for k in WEIGHTS:
		if k != _last_kind:
			total += int(WEIGHTS[k])
	var roll := randi() % maxi(total, 1)
	for k in WEIGHTS:
		if k == _last_kind:
			continue
		roll -= int(WEIGHTS[k])
		if roll < 0:
			return k
	return &"car"


## Crea un suceso de la calle. `kind`: car, van, bike, moto, walker, dogwalker.
func spawn(kind: StringName) -> StreetActor:
	_last_kind = kind
	var actor: StreetActor
	match kind:
		&"van":
			actor = _make_vehicle(&"car_van", &"wheel_van", 0.36, 0.9, [1.55, -1.5], &"van_loop", -19.0)
			_place_on_lane(actor, randf_range(5.5, 8.0))
			_maybe_honk(actor, 0.08)
		&"bike":
			actor = _make_bike()
		&"moto":
			actor = _make_moto()
			_place_on_lane(actor, randf_range(9.0, 12.0))
		&"walker":
			actor = _make_walker(false)
		&"dogwalker":
			actor = _make_walker(true)
		_:
			var sedan := randf() < 0.4
			actor = _make_vehicle(&"car_sedan" if sedan else &"car_hatch", &"wheel_car", 0.31, 0.78, [1.4, -1.4] if sedan else [1.25, -1.2], &"car_loop", -20.0)
			_place_on_lane(actor, randf_range(6.0, 9.5))
			_maybe_honk(actor, 0.12)
	actor.kind = kind
	actor.z_limit = Z_LIMIT
	StreetAssets.tag(actor)
	add_child(actor)
	_actors.append(actor)
	actor.finished.connect(func(a): _actors.erase(a))
	return actor


# --- Vehículos -----------------------------------------------------------

func _make_vehicle(body_name: StringName, wheel_name: StringName, wheel_r: float, track: float, axles: Array, loop: StringName, volume_db: float) -> StreetActor:
	var a := StreetActor.new()
	var body := StreetAssets.model(String(body_name))
	StreetAssets.skin(body, {"paint": StreetAssets.paint(CAR_COLORS[randi() % CAR_COLORS.size()])})
	a.add_child(body)
	for ax: float in axles:
		for sx in [-1.0, 1.0]:
			var w := StreetAssets.model(String(wheel_name))
			StreetAssets.skin(w)
			w.position = Vector3(sx * track, wheel_r, ax)
			a.add_child(w)
			a.wheels.append(w)
	a.wheel_radius = wheel_r
	a.engine = _attach_engine(a, loop, volume_db)
	a.engine_pitch = randf_range(0.93, 1.08)
	return a


func _make_moto() -> StreetActor:
	var a := StreetActor.new()
	var body := StreetAssets.model("moto_body")
	StreetAssets.skin(body, {"paint": StreetAssets.paint(CAR_COLORS[randi() % CAR_COLORS.size()])})
	a.add_child(body)
	for az in [0.72, -0.72]:
		var w := StreetAssets.model("wheel_moto")
		StreetAssets.skin(w)
		w.position = Vector3(0, 0.3, az)
		a.add_child(w)
		a.wheels.append(w)
	a.wheel_radius = 0.3
	var rider := _make_person(0.35, true)
	rider.position = Vector3(0, 0.88, -0.22)
	a.add_child(rider)
	for leg in rider.get_meta(&"legs"):
		(leg as Node3D).rotation.x = -1.15
	for arm in rider.get_meta(&"arms"):
		(arm as Node3D).rotation.x = -1.2
	var helmet := StreetAssets.model("moto_helmet")
	StreetAssets.skin(helmet)
	helmet.position = Vector3(0, 0.78, 0.0)
	(rider.get_meta(&"torso") as Node3D).add_child(helmet)
	a.engine = _attach_engine(a, &"moto_loop", -18.0)
	a.engine_pitch = randf_range(0.9, 1.15)
	return a


func _make_bike() -> StreetActor:
	var a := StreetActor.new()
	var frame := StreetAssets.model("bike_frame")
	StreetAssets.skin(frame, {"paint": StreetAssets.paint(CAR_COLORS[randi() % CAR_COLORS.size()])})
	a.add_child(frame)
	for az in [0.52, -0.52]:
		var w := StreetAssets.model("bike_wheel")
		StreetAssets.skin(w)
		w.position = Vector3(0, 0.34, az)
		a.add_child(w)
		a.wheels.append(w)
	a.wheel_radius = 0.34
	var rider := _make_person(0.28, false)
	rider.position = Vector3(0, 0.9, -0.17)
	a.add_child(rider)
	for arm in rider.get_meta(&"arms"):
		(arm as Node3D).rotation.x = -0.85
	for leg in rider.get_meta(&"legs"):
		a.legs.append(leg)
	a.gait = StreetActor.Gait.PEDAL
	a.engine = _attach_engine(a, &"bike_loop", -17.0)
	a.engine_pitch = randf_range(0.95, 1.08)
	# En el carril de su sentido, pegada al bordillo derecho.
	var south := randf() < 0.5
	var speed := randf_range(3.6, 5.2)
	a.position = Vector3(-8.1 if not south else -12.5, 0.0, Z_LIMIT if not south else -Z_LIMIT)
	a.velocity = Vector3(0, 0, -speed if not south else speed)
	a.rotation.y = PI if not south else 0.0
	# Timbre: a veces, una vez cuando pasa por delante.
	if randf() < 0.45:
		a.scheduled.append({"z": randf_range(-14.0, 6.0) if not south else randf_range(-6.0, 14.0), "sound": &"bike_bell", "volume": -2.0, "done": false})
	return a


# --- Personas y perros ---------------------------------------------------

func _make_walker(with_dog: bool) -> StreetActor:
	var a := StreetActor.new()
	var person := _make_person(0.0, false)
	a.add_child(person)
	for leg in person.get_meta(&"legs"):
		a.legs.append(leg)
	for arm in person.get_meta(&"arms"):
		a.arms.append(arm)
	a.gait = StreetActor.Gait.WALK
	a.bob_target = person
	a.bob_base_y = 0.9
	a.bob_amount = 0.025
	a.limb_rate = 2.6
	person.position = Vector3(0, 0.9, 0)
	var speed := randf_range(1.15, 1.5)
	var south := randf() < 0.5
	var near_side := randf() < 0.65
	var x := (NEAR_WALK_X if near_side else FAR_WALK_X) + randf_range(-0.3, 0.3)
	a.position = Vector3(x, 0.0, -Z_LIMIT if south else Z_LIMIT)
	a.velocity = Vector3(0, 0, speed if south else -speed)
	a.rotation.y = 0.0 if south else PI
	if with_dog:
		var dog := _make_dog()
		var world_side := -1.0 if near_side else 1.0        # la calzada queda al oeste de la acera cercana y al este de la lejana
		var side := world_side if south else -world_side    # si el actor va hacia -Z está girado media vuelta
		dog.position = Vector3(side * 0.8, 0.0, 0.6)
		a.add_child(dog)
		for leg in dog.get_meta(&"dog_legs"):
			a.dog_legs.append(leg)
		a.add_child(_make_leash(Vector3(side * 0.3, 0.8, 0.12), Vector3(side * 0.8, 0.52, 0.5)))
		if randf() < 0.6:
			var z0 := randf_range(-13.0, 8.0) if south else randf_range(-8.0, 13.0)
			var count := randi_range(1, 3)
			var dir := 1.0 if south else -1.0
			for i in count:
				a.scheduled.append({"z": z0 + dir * 1.6 * i, "sound": &"dog_bark", "volume": -3.0, "done": false})
	return a


func _make_person(lean: float, rider: bool) -> Node3D:
	var root := Node3D.new()
	var torso := StreetAssets.model("person_torso")
	var skin_c: Color = SKINS[randi() % SKINS.size()]
	var shirt: Color = SHIRTS[randi() % SHIRTS.size()]
	var pants: Color = PANTS[randi() % PANTS.size()]
	var hair: Color = HAIRS[randi() % HAIRS.size()]
	var mats := {
		"skin": StreetAssets.flat(skin_c, 0.6), "hair": StreetAssets.flat(hair, 0.8),
		"shirt": StreetAssets.flat(shirt, 0.85), "pants": StreetAssets.flat(pants, 0.85),
		"shoes": StreetAssets.flat(Color(0.12, 0.1, 0.1), 0.6),
	}
	StreetAssets.skin(torso, mats)
	torso.rotation.x = lean
	root.add_child(torso)
	var arms: Array[Node3D] = []
	var legs: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var arm := StreetAssets.model("person_arm")
		StreetAssets.skin(arm, mats)
		arm.position = Vector3(sx * 0.235, 0.58, 0.0)
		torso.add_child(arm)
		arms.append(arm)
		var leg := StreetAssets.model("person_leg")
		StreetAssets.skin(leg, mats)
		leg.position = Vector3(sx * 0.1, -0.02, 0.0)
		root.add_child(leg)
		legs.append(leg)
	var scale_f := randf_range(0.94, 1.06)
	root.scale = Vector3.ONE * scale_f
	root.set_meta(&"torso", torso)
	root.set_meta(&"arms", arms)
	root.set_meta(&"legs", legs)
	return root


func _make_dog() -> Node3D:
	var root := Node3D.new()
	var fur := StreetAssets.flat(FUR[randi() % FUR.size()], 0.95)
	var mats := {"fur": fur, "skin": StreetAssets.flat(Color(0.1, 0.07, 0.06), 0.5)}
	var body := StreetAssets.model("dog_body")
	StreetAssets.skin(body, mats)
	body.position.y = 0.36
	root.add_child(body)
	var legs: Array[Node3D] = []
	for z in [0.2, -0.2]:
		for sx in [-1.0, 1.0]:
			var leg := StreetAssets.model("dog_leg")
			StreetAssets.skin(leg, mats)
			leg.position = Vector3(sx * 0.09, 0.28, z)
			root.add_child(leg)
			legs.append(leg)
	root.scale = Vector3.ONE * randf_range(0.8, 1.2)
	root.set_meta(&"dog_legs", legs)
	return root


## Correa: una varilla fina entre la mano y el collar.
func _make_leash(from: Vector3, to: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.014, 0.014, from.distance_to(to))
	mi.mesh = box
	mi.material_override = StreetAssets.flat(Color(0.75, 0.15, 0.12), 0.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
	return mi


# --- Utilidades ----------------------------------------------------------

## Coloca un vehículo en su carril: el cercano va hacia -Z, el lejano hacia +Z.
func _place_on_lane(actor: StreetActor, speed: float) -> void:
	var near := randf() < 0.55
	actor.position = Vector3(NEAR_LANE_X if near else FAR_LANE_X, 0.0, Z_LIMIT if near else -Z_LIMIT)
	actor.velocity = Vector3(0, 0, -speed if near else speed)
	actor.rotation.y = PI if near else 0.0


func _maybe_honk(actor: StreetActor, chance: float) -> void:
	if randf() < chance:
		actor.scheduled.append({"z": randf_range(-12.0, 12.0), "sound": &"horn", "volume": -10.0, "done": false})


func _attach_engine(actor: StreetActor, loop: StringName, volume_db: float) -> AudioStreamPlayer3D:
	var p := AudioManager.make_outdoor_player(loop, volume_db)
	if p.stream == null:
		p.queue_free()     # los sonidos aún no están listos: sin motor audible esta vez
		return null
	p.autoplay = true
	actor.add_child(p)
	return p

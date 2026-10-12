class_name StreetActor
extends Node3D
## Un vehículo, persona o perro que cruza la calle. Se mueve en línea recta a lo largo de Z,
## gira sus ruedas / balancea sus miembros y dispara sonidos puntuales (bocina, timbre, ladrido)
## cuando pasa por la zona de la ventana. Se destruye al salir del área visible.

signal finished(actor)

enum Gait { NONE, WALK, DOG, PEDAL, SIT }

var kind: StringName = &""
var velocity := Vector3.ZERO
var wheels: Array[Node3D] = []
var wheel_radius := 0.31
var gait: Gait = Gait.NONE
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var cranks: Array[Node3D] = []
## Las cuatro patas de un perro que acompaña a la persona (orden: delante izq/der, detrás izq/der).
var dog_legs: Array[Node3D] = []
var bob_target: Node3D
var bob_base_y := 0.0
var bob_amount := 0.0
var limb_rate := 2.4          # fase por metro recorrido
var z_limit := 75.0
var engine: AudioStreamPlayer3D
var engine_pitch := 1.0
## Sonidos puntuales: {z: float (posición en la que suena), sound: StringName, volume: float, done: bool}
var scheduled: Array[Dictionary] = []

var _phase := 0.0
var _last_z := 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_last_z = position.z


func _process(delta: float) -> void:
	position += velocity * delta
	var speed := velocity.length()
	for w in wheels:
		w.rotation.x += speed / wheel_radius * delta
	_phase += speed * limb_rate * delta
	_animate()
	if engine != null:
		engine.pitch_scale = engine_pitch * (0.92 + minf(speed, 16.0) * 0.012)
	_run_scheduled()
	_last_z = position.z
	if absf(position.z) > z_limit and signf(position.z) == signf(velocity.z):
		finished.emit(self)
		queue_free()


func _animate() -> void:
	match gait:
		Gait.WALK:
			var s := sin(_phase)
			legs[0].rotation.x = s * 0.55
			legs[1].rotation.x = -s * 0.55
			arms[0].rotation.x = -s * 0.45
			arms[1].rotation.x = s * 0.45
			if bob_target != null:
				bob_target.position.y = bob_base_y + absf(s) * bob_amount
		Gait.DOG:
			var s := sin(_phase * 1.6)
			# Trote: patas en diagonal.
			legs[0].rotation.x = s * 0.6
			legs[3].rotation.x = s * 0.6
			legs[1].rotation.x = -s * 0.6
			legs[2].rotation.x = -s * 0.6
			if bob_target != null:
				bob_target.position.y = bob_base_y + absf(s) * bob_amount
		Gait.PEDAL:
			var s := sin(_phase * 1.2)
			legs[0].rotation.x = -0.95 + s * 0.45
			legs[1].rotation.x = -0.95 - s * 0.45
			for c in cranks:
				c.rotation.x = _phase * 1.2
	if dog_legs.size() == 4:
		# Trote del perro: patas en diagonal, más rápido que el paso de la persona.
		var d := sin(_phase * 1.9)
		dog_legs[0].rotation.x = d * 0.6
		dog_legs[3].rotation.x = d * 0.6
		dog_legs[1].rotation.x = -d * 0.6
		dog_legs[2].rotation.x = -d * 0.6


func _run_scheduled() -> void:
	for ev in scheduled:
		if ev["done"]:
			continue
		var ez: float = ev["z"]
		# Se dispara al cruzar la posición z indicada, en cualquier sentido de marcha.
		if (_last_z - ez) * (position.z - ez) <= 0.0 and _last_z != position.z:
			ev["done"] = true
			AudioManager.play(ev["sound"], global_position, ev["volume"], 0.08, 1.0, true)

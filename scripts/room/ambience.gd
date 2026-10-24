class_name Ambience
extends Node3D
## Ambiente del paisaje: brisa continua que entra por la ventana y pájaros lejanos
## que cantan de vez en cuando. Posicional: se oye más cerca de la ventana.

@export var window_position := Vector3(-3.4, 1.5, 0.0)
@export var wind_volume_db := -20.0
@export var bird_volume_db := -15.0
@export var bird_min_gap := 5.0
@export var bird_max_gap := 14.0

var _wind: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _birds: Timer


func _ready() -> void:
	_rng.randomize()
	# Los pájaros, con un temporizador (nada corre en cada fotograma).
	_birds = Timer.new()
	_birds.one_shot = true
	_birds.timeout.connect(_bird)
	add_child(_birds)
	# Espera a que AudioManager termine de sintetizar.
	if AudioManager.ready_to_play:
		_start()
	else:
		AudioManager.sounds_ready.connect(_start, CONNECT_ONE_SHOT)


func _bird() -> void:
	var pos := Vector3(
		window_position.x - _rng.randf_range(6.0, 16.0),
		_rng.randf_range(2.5, 6.0),
		_rng.randf_range(-8.0, 8.0))
	AudioManager.play(&"bird", pos, bird_volume_db, 0.12)
	_birds.start(_rng.randf_range(bird_min_gap, bird_max_gap))


func _start() -> void:
	_birds.start(3.0)
	var stream := AudioManager.get_stream(&"wind")
	if stream == null:
		return
	_wind = AudioStreamPlayer3D.new()
	_wind.stream = stream
	_wind.bus = AudioManager.SFX_BUS
	_wind.volume_db = wind_volume_db
	_wind.unit_size = 6.0
	_wind.max_distance = 40.0
	_wind.position = window_position
	add_child(_wind)
	_wind.play()

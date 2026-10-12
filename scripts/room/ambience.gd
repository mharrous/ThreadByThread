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
var _next_bird := 3.0
var _started := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if not _started:
		# Espera a que AudioManager termine de sintetizar.
		if AudioManager.ready_to_play:
			_start()
		return
	_next_bird -= delta
	if _next_bird <= 0.0:
		_next_bird = _rng.randf_range(bird_min_gap, bird_max_gap)
		var pos := Vector3(
			window_position.x - _rng.randf_range(6.0, 16.0),
			_rng.randf_range(2.5, 6.0),
			_rng.randf_range(-8.0, 8.0))
		AudioManager.play(&"bird", pos, bird_volume_db, 0.12)


func _start() -> void:
	_started = true
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

extends Node
## Reproduce efectos con variación de tono/volumen para que no suenen repetidos.
## Escucha el bus de eventos: el gameplay no sabe nada de audio.
## Los sonidos se sintetizan en un hilo al arrancar (ver SfxSynth).

const SFX_BUS := &"SFX"
## Semitonos de la escala pentatónica que suena al ir llenando una fila.
const PENTATONIC: Array[int] = [0, 2, 4, 7, 9, 12]
const SFX_DIR := "res://art/audio/sfx/"
const POOL_3D := 10
const POOL_2D := 6

var ready_to_play := false
## Bancos cuyo sonido viene de un fichero editado en vez de la síntesis.
var overridden: Array[StringName] = []

var _banks: Dictionary = {}
var _last_variant: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_2d := 0
var _synth_task := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_setup_bus()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = SFX_BUS
		p.unit_size = 5.0
		p.max_distance = 14.0
		p.panning_strength = 0.5
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = SFX_BUS
		add_child(p2)
		_pool_2d.append(p2)
	GameSettings.changed.connect(_apply_volumes)
	_apply_volumes()
	_connect_events()
	_synth_task = WorkerThreadPool.add_task(_synthesize_all, false, "Sintetizar efectos")


func _exit_tree() -> void:
	if _synth_task != -1:
		WorkerThreadPool.wait_for_task_completion(_synth_task)


## Reproduce un efecto. `pos` = Vector3 para sonido posicional, null para sonido plano.
func play(sound: StringName, pos: Variant = null, volume_db: float = 0.0, pitch_variation: float = 0.06, pitch_base: float = 1.0) -> void:
	if not ready_to_play or not _banks.has(sound):
		return
	var variants: Array = _banks[sound]
	var idx := _rng.randi() % variants.size()
	if variants.size() > 1 and idx == int(_last_variant.get(sound, -1)):
		idx = (idx + 1) % variants.size()
	_last_variant[sound] = idx
	var pitch := pitch_base * (1.0 + _rng.randf_range(-pitch_variation, pitch_variation))
	var vol := volume_db + _rng.randf_range(-1.0, 0.5)
	if pos is Vector3:
		var p := _pool_3d[_next_3d]
		_next_3d = (_next_3d + 1) % POOL_3D
		p.stream = variants[idx]
		p.global_position = pos
		p.pitch_scale = pitch
		p.volume_db = vol
		p.play()
	else:
		var p2 := _pool_2d[_next_2d]
		_next_2d = (_next_2d + 1) % POOL_2D
		p2.stream = variants[idx]
		p2.pitch_scale = pitch
		p2.volume_db = vol
		p2.play()


## Devuelve el primer stream de un banco (para sonidos en bucle que gestiona otro nodo).
func get_stream(sound: StringName) -> AudioStream:
	if not _banks.has(sound):
		return null
	return (_banks[sound] as Array)[0]


func _setup_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, SFX_BUS)
	AudioServer.set_bus_send(idx, &"Master")


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameSettings.master_volume, 0.0001)))
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	if sfx != -1:
		AudioServer.set_bus_volume_db(sfx, linear_to_db(maxf(GameSettings.sfx_volume, 0.0001)))


func _connect_events() -> void:
	Events.item_picked.connect(func(item): play(&"pick", item.global_position))
	Events.item_placed.connect(func(item, shelf):
		# Cada hueco tiene su nota: rellenar una fila de izquierda a derecha toca una escala.
		var steps := PENTATONIC.size()
		var degree := clampi(int(float(item.slot_index) / float(shelf.slots_per_row) * steps), 0, steps - 1)
		play(&"place", item.global_position, 0.0, 0.01, pow(2.0, PENTATONIC[degree] / 12.0)))
	Events.item_set_down.connect(func(item): play(&"set_down", item.global_position))
	Events.item_rejected.connect(func(_item, _reason): play(&"deny"))
	Events.item_thrown.connect(func(item): play(&"throw", item.global_position))
	Events.item_bounced.connect(func(_item, speed, pos, sound):
		# Más fuerte cuanto más fuerte el golpe.
		play(sound, pos, lerpf(-22.0, 0.0, clampf(speed / 6.0, 0.0, 1.0)), 0.08))
	Events.collection_completed.connect(func(_key): play(&"collection", null, -2.0, 0.0))
	Events.room_completed.connect(func(_room): play(&"room_complete", null, -1.0, 0.0))


# Corre en un hilo de trabajo.
func _synthesize_all() -> void:
	_publish_banks.call_deferred(SfxSynth.build_banks())


func _publish_banks(banks: Dictionary) -> void:
	_apply_overrides(banks)
	_banks = banks
	ready_to_play = true


## Si existe art/audio/sfx/<sonido>_<n>.wav (editado en Audacity u otro programa),
## sustituye a la variante n sintetizada. Se pueden reemplazar solo algunas variantes
## o añadir más. Los sonidos no editados siguen siendo los sintetizados.
func _apply_overrides(banks: Dictionary) -> void:
	for sound: StringName in banks.keys():
		var variants: Array = banks[sound]
		var i := 1
		var replaced := false
		while i <= variants.size() or ResourceLoader.exists("%s%s_%d.wav" % [SFX_DIR, sound, i]):
			var path := "%s%s_%d.wav" % [SFX_DIR, sound, i]
			if ResourceLoader.exists(path):
				var stream := load(path) as AudioStreamWAV
				if stream != null:
					if sound == &"wind":
						stream = _looped(stream)
					if i <= variants.size():
						variants[i - 1] = stream
					else:
						variants.append(stream)
					replaced = true
			i += 1
		if replaced:
			overridden.append(sound)


func _looped(stream: AudioStreamWAV) -> AudioStreamWAV:
	var s := stream.duplicate() as AudioStreamWAV
	var bytes_per_frame := (2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if s.stereo else 1)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / bytes_per_frame
	return s

extends Node
## Reproduce efectos con variación de tono/volumen para que no suenen repetidos.
## Escucha el bus de eventos: el gameplay no sabe nada de audio.
## Los sonidos se sintetizan en un hilo al arrancar (ver SfxSynth).

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
## Música de la tienda (bucle original, generado con tools/make_music.gd).
const MUSIC_PATH := "res://art/audio/music/shop_loop.wav"
## Sonidos de la calle: pasan por un filtro que simula el cristal de la ventana.
const OUTDOOR_BUS := &"Outdoor"
const POOL_OUT := 8
## Sonido de colocar según el sonido de impacto del material.
const PLACE_BANKS := {
	&"bounce_soft": &"place",
	&"bounce_hard": &"place_click",
	&"bounce_wood": &"place_wood",
	&"bounce_metal": &"place_metal",
	&"bounce_fabric": &"place_soft",
}
## Escala pentatónica (octava y media) que sube con cada colocación seguida: la racha "toca" una melodía.
const COMBO_SCALE: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16]
## Tiempo máximo entre dos colocaciones para que la racha siga subiendo.
const COMBO_WINDOW_MS := 6000
## Fracciones de una sección que suenan como hito.
const MILESTONES: Array[float] = [0.25, 0.5, 0.75]
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
var _pool_out: Array[AudioStreamPlayer3D] = []
var _next_out := 0
var _next_3d := 0
var _next_2d := 0
var _synth_task := -1
var _rng := RandomNumberGenerator.new()
var _combo := -1
var _last_place_ms := -100000
var _aiming_ok := false
var _music: AudioStreamPlayer


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
	for i in POOL_OUT:
		var po := make_outdoor_player()
		add_child(po)
		_pool_out.append(po)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = SFX_BUS
		add_child(p2)
		_pool_2d.append(p2)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	GameSettings.changed.connect(_apply_volumes)
	_apply_volumes()
	_connect_events()
	_synth_task = WorkerThreadPool.add_task(_synthesize_all, false, "Sintetizar efectos")


func _exit_tree() -> void:
	if _synth_task != -1:
		WorkerThreadPool.wait_for_task_completion(_synth_task)


## Reproduce un efecto. `pos` = Vector3 para sonido posicional, null para sonido plano.
## `variant` >= 0 fuerza una variante concreta (melodías: misma nota base siempre).
func play(sound: StringName, pos: Variant = null, volume_db: float = 0.0, pitch_variation: float = 0.06, pitch_base: float = 1.0, outdoor: bool = false, variant: int = -1) -> void:
	if not ready_to_play or not _banks.has(sound):
		return
	var variants: Array = _banks[sound]
	var idx := _rng.randi() % variants.size()
	if variant >= 0:
		idx = variant % variants.size()
	elif variants.size() > 1 and idx == int(_last_variant.get(sound, -1)):
		idx = (idx + 1) % variants.size()
	_last_variant[sound] = idx
	var pitch := pitch_base * (1.0 + _rng.randf_range(-pitch_variation, pitch_variation))
	var vol := volume_db + _rng.randf_range(-1.0, 0.5)
	if pos is Vector3 and outdoor:
		var po := _pool_out[_next_out]
		_next_out = (_next_out + 1) % POOL_OUT
		po.stream = variants[idx]
		po.global_position = pos
		po.pitch_scale = pitch
		po.volume_db = vol
		po.play()
	elif pos is Vector3:
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


## Reproductor posicional de largo alcance para sonidos de la calle (bucles de motor, etc.).
func make_outdoor_player(sound: StringName = &"", volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = OUTDOOR_BUS
	p.unit_size = 14.0
	p.max_distance = 160.0
	p.panning_strength = 0.6
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
	p.volume_db = volume_db
	if sound != &"":
		p.stream = get_stream(sound)
	return p


func _setup_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, &"Master")
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		var m_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(m_idx, MUSIC_BUS)
		AudioServer.set_bus_send(m_idx, &"Master")
	if AudioServer.get_bus_index(OUTDOOR_BUS) == -1:
		AudioServer.add_bus()
		var out_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(out_idx, OUTDOOR_BUS)
		AudioServer.set_bus_send(out_idx, SFX_BUS)
		AudioServer.set_bus_volume_db(out_idx, -3.0)
		var lpf := AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 3200.0
		AudioServer.add_bus_effect(out_idx, lpf)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.35
		reverb.wet = 0.1
		reverb.dry = 0.95
		AudioServer.add_bus_effect(out_idx, reverb)


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameSettings.master_volume, 0.0001)))
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	if sfx != -1:
		AudioServer.set_bus_volume_db(sfx, linear_to_db(maxf(GameSettings.sfx_volume, 0.0001)))
	var music := AudioServer.get_bus_index(MUSIC_BUS)
	if music != -1:
		AudioServer.set_bus_volume_db(music, linear_to_db(maxf(GameSettings.music_volume, 0.0001)))


func _connect_events() -> void:
	Events.item_picked.connect(func(item): play(&"pick", item.global_position))
	Events.item_placed.connect(_on_item_placed)
	Events.section_progress_changed.connect(_on_section_progress)
	Events.target_changed.connect(func(info: Dictionary):
		# Tic suave al pasar a apuntar a un hueco correcto (la mira se pone verde).
		var ok: bool = info.get("kind", "") == "place"
		if ok and not _aiming_ok:
			play(&"aim_ok", null, -16.0, 0.03)
		_aiming_ok = ok)
	Events.item_set_down.connect(func(item): play(&"set_down", item.global_position))
	Events.item_rejected.connect(func(_item, _reason): play(&"deny"))
	Events.item_thrown.connect(func(item): play(&"throw", item.global_position))
	Events.item_bounced.connect(func(_item, speed, pos, sound):
		# Más fuerte cuanto más fuerte el golpe.
		play(sound, pos, lerpf(-22.0, 0.0, clampf(speed / 6.0, 0.0, 1.0)), 0.08))
	Events.collection_completed.connect(func(_key): play(&"collection", null, -2.0, 0.0))
	Events.section_completed.connect(func(_section): play(&"room_complete", null, -1.0, 0.0))
	# El final de la mercería: la misma melodía, más grave y solemne.
	Events.room_completed.connect(func(_room): play(&"room_complete", null, 0.0, 0.0, 0.84))
	Events.treasure_found.connect(func(_item): play(&"treasure", null, -2.0, 0.0))
	Events.decor_unlocked.connect(func(_room, _id): play(&"decor_unlock", null, -3.0, 0.0))


## Colocar: el sonido del material afinado en la escala de la racha. Cada colocación seguida (menos de
## 6 s entre una y otra) sube una nota; desde la tercera se suma un destello de campanillas que crece con
## la racha. Al cortar la racha se vuelve a la nota base.
func _on_item_placed(item, _shelf) -> void:
	var now := Time.get_ticks_msec()
	_combo = _combo + 1 if now - _last_place_ms < COMBO_WINDOW_MS else 0
	_last_place_ms = now
	Events.streak_changed.emit(_combo + 1)
	var top := COMBO_SCALE.size() - 1
	# Arriba del todo alterna las dos últimas notas en vez de seguir subiendo.
	var step := _combo if _combo <= top else top - (_combo - top) % 2
	var pitch := pow(2.0, COMBO_SCALE[step] / 12.0)
	# El sonido depende del material del objeto: lana, plástico, madera, metal o tela.
	var bank: StringName = PLACE_BANKS.get(item.data.get_motion().impact_sound, &"place")
	play(bank, item.global_position, 0.0, 0.0, pitch, false, 0)
	if _combo >= 2:
		play(&"sparkle", item.global_position, minf(-16.0 + _combo * 1.2, -5.0), 0.0, pitch, false, 0)


## Hitos de una sección (25 %, 50 %, 75 %): arpegio corto, más agudo cuanto más avanzada.
func _on_section_progress(_section, placed: int, total: int) -> void:
	if total <= 0:
		return
	for i in MILESTONES.size():
		if placed == ceili(total * MILESTONES[i]):
			play(&"collection", null, -7.0, 0.0, pow(2.0, (2 + i * 2) / 12.0))
			return


# Corre en un hilo de trabajo.
func _synthesize_all() -> void:
	_publish_banks.call_deferred(SfxSynth.build_banks())


func _publish_banks(banks: Dictionary) -> void:
	_apply_overrides(banks)
	_banks = banks
	ready_to_play = true
	_start_music()


## La música entra despacio un poco después de arrancar (no compite con el primer vistazo a la sala).
func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream := load(MUSIC_PATH) as AudioStreamWAV
	if stream == null:
		return
	_music.stream = stream   # el bucle viene del .import (loop_mode = adelante)
	_music.volume_db = -40.0
	_music.play()
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_music, "volume_db", -6.0, 6.0).set_trans(Tween.TRANS_SINE)


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

extends SceneTree
## Compone y sintetiza la música de la tienda (original) y la guarda en art/audio/music/.
##   godot --headless --path . --script res://tools/make_music.gd
## Es un bucle tranquilo de 16 compases a 72 ppm: piano eléctrico suave con acordes de séptima, bajo
## redondo, una melodía pentatónica que va y viene y un shaker muy bajo. Las colas que pasan del final
## se suman al principio, así el bucle no tiene corte. Se genera aquí (no al arrancar) porque cuesta
## unos segundos; el juego solo carga el WAV.

const RATE := 44100
const BPM := 72.0
const BARS := 16
const OUT := "res://art/audio/music/shop_loop.wav"

## Progresión (Do mayor, cálida): Cmaj7 · Am7 · Fmaj7 · G6, luego Em7 · Am7 · Dm7 · G7sus.
const CHORDS := [
	[48, 52, 55, 59], [45, 52, 55, 60], [41, 52, 57, 60], [43, 50, 55, 59],
	[40, 50, 55, 59], [45, 52, 55, 60], [38, 50, 53, 57], [43, 50, 53, 60],
]
const PENTA := [60, 62, 64, 67, 69, 72, 74, 76]

var _buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1977
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	_buf.resize(int(bar * BARS * RATE))
	for b in BARS:
		var chord: Array = CHORDS[b % CHORDS.size()]
		var t0 := b * bar
		# Bajo: fundamental en el 1 y quinta (o la misma) en el 3.
		_note(t0, _midi(chord[0] - 12), 0.32, 1.4, 1)
		_note(t0 + beat * 2.0, _midi(chord[0] - 12 + (7 if b % 2 == 0 else 0)), 0.22, 1.1, 1)
		# Piano eléctrico: acorde en el 1 y un eco suave en el "y" del 2.
		for i in range(1, 4):
			_note(t0 + i * 0.012, _midi(chord[i]), 0.12, 2.4, 0)
			_note(t0 + beat * 1.5 + i * 0.01, _midi(chord[i]), 0.06, 1.2, 0)
		# Melodía: a ratos, notas de la escala cerca del acorde (la segunda mitad responde a la primera).
		if b >= 2:
			for k in 4:
				if _rng.randf() < (0.55 if b % 4 != 3 else 0.3):
					var n: int = PENTA[_rng.randi_range(2, PENTA.size() - 1)]
					_note(t0 + k * beat + (beat * 0.5 if _rng.randf() < 0.3 else 0.0), _midi(n), 0.09, 1.6, 2)
		# Shaker en corcheas, muy bajito, con acento en el contratiempo.
		for k in 8:
			_shaker(t0 + k * beat * 0.5, 0.025 if k % 2 == 0 else 0.04)
	var stream := _to_stream(0.55)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := stream.save_to_wav(ProjectSettings.globalize_path(OUT))
	print("Música: %s (%.1f s) -> %s" % [OUT, _buf.size() / float(RATE), error_string(err)])
	quit()


func _midi(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


## timbre 0 = piano eléctrico, 1 = bajo, 2 = campanita de la melodía.
func _note(start: float, freq: float, amp: float, decay: float, timbre: int) -> void:
	var n := _buf.size()
	var s0 := int(start * RATE)
	var length := int(minf(decay * 4.0, 6.0) * RATE)
	for i in length:
		var t := float(i) / RATE
		var env := minf(t / 0.006, 1.0) * exp(-t / decay)
		var v := 0.0
		match timbre:
			0:
				v = sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) * exp(-t / 0.4) + 0.08 * sin(TAU * freq * 3.0 * t) * exp(-t / 0.15)
				v *= 1.0 + 0.06 * sin(TAU * 4.5 * t)
			1:
				v = sin(TAU * freq * t) + 0.2 * sin(TAU * freq * 2.0 * t) * exp(-t / 0.2)
			2:
				v = sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.76 * t) * exp(-t / 0.3)
		_buf[(s0 + i) % n] += v * env * amp


func _shaker(start: float, amp: float) -> void:
	var n := _buf.size()
	var s0 := int(start * RATE)
	var hp := 0.0
	var prev := 0.0
	for i in int(0.09 * RATE):
		var t := float(i) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		hp = 0.92 * (hp + x - prev)
		prev = x
		_buf[(s0 + i) % n] += hp * amp * minf(t / 0.008, 1.0) * exp(-t / 0.025)


func _to_stream(peak: float) -> AudioStreamWAV:
	var m := 0.0001
	for v in _buf:
		m = maxf(m, absf(v))
	var gain := peak / m
	var data := PackedByteArray()
	data.resize(_buf.size() * 2)
	for i in _buf.size():
		data.encode_s16(i * 2, int(clampf(_buf[i] * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s

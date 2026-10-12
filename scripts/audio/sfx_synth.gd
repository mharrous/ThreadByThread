class_name SfxSynth
extends RefCounted
## Síntesis procedural de efectos de sonido. 100 % original: sin muestras externas,
## sin problemas de licencia. Cada función devuelve un AudioStreamWAV mono 16 bit.
## Pensado como sustituto temporal: se pueden reemplazar por audio editado en Audacity.

const RATE := 44100
const NOTE_C5 := 523.25
const NOTE_D5 := 587.33
const NOTE_E5 := 659.25
const NOTE_G5 := 783.99
const NOTE_A5 := 880.0
const NOTE_C6 := 1046.5
const NOTE_E6 := 1318.5


## Recoger: roce suave de lana + pequeño "whup" ascendente.
static func pick(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.22)
	var lp := 0.0
	var ph := 0.0
	var f0 := rng.randf_range(300.0, 360.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.10
		ph += TAU * f0 * (1.0 + 1.4 * minf(t / 0.12, 1.0)) / RATE
		b[i] = lp * 1.6 * _ad(t, 0.006, 0.05) + sin(ph) * 0.30 * _ad(t, 0.01, 0.07)
	return _to_stream(b, 0.45)


## Colocar bien: "tok" de madera suave + campanita agradable.
static func place(seed_value: int, note: float) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(1.0)
	var ph := 0.0
	var lp := 0.0
	for i in int(0.25 * RATE):
		var t := float(i) / RATE
		ph += TAU * (115.0 + 95.0 * exp(-t / 0.018)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		b[i] = sin(ph) * 0.9 * _ad(t, 0.001, 0.05) + lp * 0.35 * _ad(t, 0.0005, 0.006)
	_add_bell(b, 0.02, note, 0.30, 0.28)
	return _to_stream(b, 0.6)


## Rechazo: "boop" grave y amable, sin estridencia.
static func deny(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.30)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (200.0 - 70.0 * minf(t / 0.2, 1.0)) / RATE
		b[i] = (sin(ph) + 0.25 * sin(ph * 2.0)) * _ad(t, 0.006, 0.09)
	return _to_stream(b, 0.35 + rng.randf() * 0.02)


## Dejar sobre una superficie: golpe sordo de madera.
static func set_down(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.22)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (62.0 + 48.0 * exp(-t / 0.03)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.18
		b[i] = sin(ph) * 0.8 * _ad(t, 0.002, 0.06) + lp * 0.5 * _ad(t, 0.001, 0.012)
	return _to_stream(b, 0.5)


## Colección completa: arpegio breve de tres notas.
static func collection() -> AudioStreamWAV:
	var b := _buf(1.8)
	var notes := [NOTE_C5, NOTE_E5, NOTE_G5]
	for k in notes.size():
		_add_bell(b, k * 0.11, notes[k], 0.35, 0.5)
	return _to_stream(b, 0.6)


## Sala completa: melodía ascendente y acorde sostenido.
static func room_complete() -> AudioStreamWAV:
	var b := _buf(3.6)
	var run := [NOTE_C5, NOTE_E5, NOTE_G5, NOTE_C6, NOTE_E6]
	for k in run.size():
		_add_bell(b, k * 0.14, run[k], 0.30, 0.55)
	for n: float in [NOTE_C5, NOTE_E5, NOTE_G5, NOTE_C6]:
		_add_bell(b, 0.78, n, 0.20, 1.1)
	return _to_stream(b, 0.65)


## Paso sobre suelo de madera.
static func step(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.18)
	var ph := 0.0
	var lp := 0.0
	var f0 := rng.randf_range(80.0, 100.0)
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (f0 - 30.0 * minf(t / 0.1, 1.0)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.07
		b[i] = lp * 2.2 * _ad(t, 0.002, 0.025) + sin(ph) * 0.55 * _ad(t, 0.002, 0.04)
	return _to_stream(b, 0.22)


## Clic de interfaz.
static func ui_click() -> AudioStreamWAV:
	var b := _buf(0.07)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 1100.0 * t) * 0.5 + sin(TAU * 2200.0 * t) * 0.2) * _ad(t, 0.001, 0.012)
	return _to_stream(b, 0.3)


# --- Utilidades DSP ------------------------------------------------------

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Envolvente ataque lineal + caída exponencial.
static func _ad(t: float, attack: float, decay: float) -> float:
	var a := minf(t / attack, 1.0) if attack > 0.0 else 1.0
	return a * exp(-maxf(t - attack, 0.0) / decay)


## Suma una nota de campana (parciales ligeramente inarmónicos) al buffer.
static func _add_bell(buf: PackedFloat32Array, start: float, freq: float, amp: float, decay: float) -> void:
	var s0 := int(start * RATE)
	var ratios := [1.0, 2.76, 5.4]
	var amps := [1.0, 0.22, 0.07]
	var decs := [1.0, 0.45, 0.2]
	for i in range(s0, buf.size()):
		var t := float(i - s0) / RATE
		if t > decay * 6.0:
			break
		var v := 0.0
		for k in 3:
			v += sin(TAU * freq * ratios[k] * t) * amps[k] * exp(-t / (decay * decs[k]))
		buf[i] += v * amp * minf(t / 0.004, 1.0)


static func _to_stream(buf: PackedFloat32Array, peak: float) -> AudioStreamWAV:
	var m := 0.0001
	for v in buf:
		m = maxf(m, absf(v))
	var gain := peak / m
	var n := buf.size()
	var fade := mini(300, n)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := buf[i] * gain
		if i > n - fade:
			v *= float(n - i) / fade
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

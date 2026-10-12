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


## Todos los bancos de sonido del juego: nombre -> variantes. Lo usan AudioManager
## (al arrancar) y tools/export_sfx.gd (para sacarlos a WAV y editarlos en Audacity).
static func build_banks() -> Dictionary:
	return {
		&"pick": [pick(11), pick(23), pick(37)],
		&"place": [place(5, NOTE_E5), place(17, NOTE_G5), place(29, NOTE_A5)],
		&"deny": [deny(3), deny(8)],
		&"set_down": [set_down(2), set_down(9), set_down(14)],
		&"collection": [collection()],
		&"room_complete": [room_complete()],
		&"step": [step(1), step(4), step(7), step(12)],
		&"wind": [wind_loop()],
		&"bird": [bird(4), bird(15), bird(26), bird(41)],
		&"throw": [throw_whoosh(3), throw_whoosh(9)],
		&"bounce_soft": [bounce_soft(2), bounce_soft(6), bounce_soft(13)],
		&"bounce_hard": [bounce_hard(2), bounce_hard(6), bounce_hard(13)],
		&"bounce_wood": [bounce_wood(2), bounce_wood(6), bounce_wood(13)],
		&"bounce_metal": [bounce_metal(2), bounce_metal(6), bounce_metal(13)],
		&"bounce_fabric": [bounce_fabric(2), bounce_fabric(6)],
		&"door_open": [door_open(5)],
		&"ui_click": [ui_click()],
	}


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


## Lanzamiento: soplo de aire corto.
static func throw_whoosh(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.34)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var shape := sin(PI * minf(t / 0.3, 1.0))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (0.03 + 0.2 * shape)
		b[i] = lp * shape * 1.6
	return _to_stream(b, 0.32)


## Rebote de lana: golpe sordo y mullido.
static func bounce_soft(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.26)
	var ph := 0.0
	var lp := 0.0
	var f0 := rng.randf_range(135.0, 165.0)
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (f0 - 70.0 * minf(t / 0.12, 1.0)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.10
		b[i] = sin(ph) * 0.9 * _ad(t, 0.002, 0.055) + lp * 0.9 * _ad(t, 0.001, 0.03)
	return _to_stream(b, 0.5)


## Rebote duro (botón de plástico): "tic" corto y brillante.
static func bounce_hard(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.16)
	var f := rng.randf_range(1500.0, 1900.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.3 * t) * 0.25) * _ad(t, 0.0005, 0.014) \
			+ rng.randf_range(-1.0, 1.0) * 0.25 * _ad(t, 0.0003, 0.003)
	return _to_stream(b, 0.4)


## Rebote de madera: "tok" redondo.
static func bounce_wood(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.22)
	var f := rng.randf_range(290.0, 350.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
		b[i] = sin(TAU * f * t) * 0.8 * _ad(t, 0.001, 0.04) \
			+ sin(TAU * f * 2.1 * t) * 0.3 * _ad(t, 0.001, 0.022) \
			+ lp * 0.3 * _ad(t, 0.0005, 0.006)
	return _to_stream(b, 0.45)


## Rebote de metal: "tin" con parciales inarmónicos.
static func bounce_metal(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.5)
	var f := rng.randf_range(1900.0, 2300.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * f * t) * _ad(t, 0.0004, 0.12) \
			+ sin(TAU * f * 2.32 * t) * 0.5 * _ad(t, 0.0004, 0.07) \
			+ sin(TAU * f * 4.1 * t) * 0.25 * _ad(t, 0.0004, 0.04)) * 0.6
	return _to_stream(b, 0.36)


## Caída de tela: roce suave sin rebote.
static func bounce_fabric(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.06
		b[i] = lp * 2.0 * _ad(t, 0.012, 0.05)
	return _to_stream(b, 0.22)


## Brisa suave en bucle (ruido filtrado con ondulaciones lentas), sin saltos al repetir.
static func wind_loop() -> AudioStreamWAV:
	var rng := _rng(77)
	var loop_len := int(8.0 * RATE)
	var fade := int(0.6 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + fade)
	var lp := 0.0
	var lp2 := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		var gust := 0.55 + 0.45 * sin(t * 0.8 + 0.5 * sin(t * 0.31))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (0.012 + 0.012 * gust)
		lp2 += (lp - lp2) * 0.25
		raw[i] = lp2 * gust
	# Mezcla el final con el principio para que el bucle sea continuo.
	var b := PackedFloat32Array()
	b.resize(loop_len)
	for i in loop_len:
		if i < fade:
			var w := float(i) / fade
			b[i] = raw[i] * w + raw[loop_len + i] * (1.0 - w)
		else:
			b[i] = raw[i]
	var stream := _to_stream(b, 0.5)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_len
	return stream


## Pájaro lejano: pequeña serie de trinos con modulación de frecuencia.
static func bird(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(1.4)
	var cursor := 0.0
	var ph := 0.0
	for c in rng.randi_range(2, 5):
		var dur := rng.randf_range(0.07, 0.14)
		var f0 := rng.randf_range(2600.0, 4300.0)
		var f1 := f0 * rng.randf_range(0.7, 1.5)
		var s0 := int(cursor * RATE)
		for i in range(s0, mini(s0 + int(dur * RATE), b.size())):
			var tt := float(i - s0) / RATE
			var f := lerpf(f0, f1, tt / dur)
			ph += TAU * f / RATE
			var env := sin(PI * tt / dur)
			b[i] += sin(ph + 1.4 * sin(TAU * 38.0 * tt)) * env * 0.5
		cursor += dur + rng.randf_range(0.06, 0.15)
	return _to_stream(b, 0.35)


## Puerta corredera de madera: clic del cierre, rodadura grave y golpe suave al llegar al tope.
static func door_open(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(2.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var swell := sin(PI * clampf((t - 0.3) / 1.2, 0.0, 1.0))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.3
		b[i] = lp2 * swell * 3.0
		# Cerrojo: dos clics al principio.
		for click_t: float in [0.05, 0.2]:
			var tt := t - click_t
			if tt >= 0.0 and tt < 0.05:
				b[i] += sin(TAU * 1500.0 * tt) * exp(-tt / 0.006) * 0.5
		# Tope final.
		var ts := t - 1.62
		if ts >= 0.0:
			b[i] += sin(TAU * 92.0 * ts) * exp(-ts / 0.07) * 0.9
	return _to_stream(b, 0.5)


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

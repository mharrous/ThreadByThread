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
		&"place_click": [place_click(5, NOTE_E5), place_click(17, NOTE_G5), place_click(29, NOTE_A5)],
		&"place_wood": [place_wood(5, NOTE_E5), place_wood(17, NOTE_G5), place_wood(29, NOTE_A5)],
		&"place_soft": [place_soft(5, NOTE_E5), place_soft(17, NOTE_G5), place_soft(29, NOTE_A5)],
		&"place_metal": [place_metal(5, NOTE_E5), place_metal(17, NOTE_G5), place_metal(29, NOTE_A5)],
		&"deny": [deny(3), deny(8)],
		&"set_down": [set_down(2), set_down(9), set_down(14)],
		&"collection": [collection()],
		&"room_complete": [room_complete()],
		&"treasure": [treasure()],
		&"decor_unlock": [decor_unlock()],
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
		&"car_loop": [engine_loop(31, 46.0, 0.5, 0.55, 7)],
		&"van_loop": [engine_loop(32, 36.0, 0.8, 0.5, 8)],
		&"moto_loop": [moto_loop()],
		&"bike_loop": [bike_loop()],
		&"horn": [horn(2, 0.32), horn(3, 0.6)],
		&"bike_bell": [bike_bell(3), bike_bell(8)],
		&"dog_bark": [dog_bark(2, 330.0), dog_bark(5, 480.0), dog_bark(7, 650.0)],
		&"ui_click": [ui_click()],
		&"sparkle": [sparkle(NOTE_E5)],
		&"aim_ok": [aim_tick()],
		&"shop_bell": [shop_bell()],
		&"sweep": [sweep(3), sweep(11), sweep(19)],
		&"dust_dump": [dust_dump(5), dust_dump(13)],
		&"cat_purr": [cat_purr(7)],
		&"cat_mrrp": [cat_mrrp(3), cat_mrrp(9)],
		&"cardboard_fold": [cardboard_fold(4), cardboard_fold(10)],
		&"cardboard_drop": [cardboard_drop(6), cardboard_drop(15)],
	}


## Destello de una racha: dos campanillas agudas (octava y dos octavas) con un brillo que se apaga.
static func sparkle(note: float) -> AudioStreamWAV:
	var b := _buf(1.2)
	_add_bell(b, 0.0, note * 2.0, 0.35, 0.22)
	_add_bell(b, 0.045, note * 4.0, 0.18, 0.16)
	_add_partials(b, 0.0, note * 3.0, 0.08, 0.3, [1.0, 1.5], [1.0, 0.5], [1.0, 0.6])
	return _to_stream(b, 0.45)


## Campanilla de la puerta de la tienda: dos golpes de badajo sobre una campana de latón, claros y con
## cola larga, el segundo un poco más flojo (la puerta rebota).
static func shop_bell() -> AudioStreamWAV:
	var b := _buf(2.4)
	for hit: Array in [[0.0, 1.0], [0.16, 0.6], [0.31, 0.3]]:
		_add_partials(b, hit[0], 1568.0, 0.5 * float(hit[1]), 0.55, [1.0, 2.0, 2.76, 4.07], [1.0, 0.45, 0.3, 0.12], [1.0, 0.6, 0.45, 0.25])
	return _to_stream(b, 0.7)


## Tic de "aquí sí": clic muy corto y agudo, casi un pestañeo.
static func aim_tick() -> AudioStreamWAV:
	var b := _buf(0.08)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1760.0 * t) * _ad(t, 0.001, 0.012) + sin(TAU * 2640.0 * t) * 0.4 * _ad(t, 0.001, 0.008)
	return _to_stream(b, 0.3)


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


## Colocar un botón o pieza dura: pequeño clic con una nota muy suave detrás.
static func place_click(seed_value: int, note: float) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.55)
	for i in int(0.14 * RATE):
		var t := float(i) / RATE
		b[i] = (sin(TAU * 2400.0 * t) * 0.6 + sin(TAU * 3600.0 * t) * 0.2) * _ad(t, 0.0004, 0.008) \
			+ rng.randf_range(-1.0, 1.0) * 0.2 * _ad(t, 0.0003, 0.003) \
			+ sin(TAU * 320.0 * t) * 0.45 * _ad(t, 0.001, 0.02)
	_add_bell(b, 0.015, note * 2.0, 0.10, 0.14)
	return _to_stream(b, 0.4)


## Colocar en madera (carretes, cajas): "tok" hueco y cálido.
static func place_wood(seed_value: int, note: float) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.7)
	var ph := 0.0
	var lp := 0.0
	for i in int(0.22 * RATE):
		var t := float(i) / RATE
		ph += TAU * (150.0 + 90.0 * exp(-t / 0.02)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
		b[i] = sin(ph) * 0.9 * _ad(t, 0.001, 0.06) + sin(ph * 2.3) * 0.25 * _ad(t, 0.001, 0.03) + lp * 0.3 * _ad(t, 0.0005, 0.007)
	_add_bell(b, 0.02, note, 0.16, 0.22)
	return _to_stream(b, 0.55)


## Colocar tela o cinta: golpecito mullido, casi sin eco.
static func place_soft(seed_value: int, note: float) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.7)
	var lp := 0.0
	var ph := 0.0
	for i in int(0.2 * RATE):
		var t := float(i) / RATE
		ph += TAU * (95.0 + 40.0 * exp(-t / 0.03)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.07
		b[i] = lp * 1.8 * _ad(t, 0.004, 0.05) + sin(ph) * 0.5 * _ad(t, 0.003, 0.05)
	_add_bell(b, 0.03, note, 0.12, 0.25)
	return _to_stream(b, 0.45)


## Colocar metal (tijeras, planchas, dedales): "tin" corto con resonancia.
static func place_metal(seed_value: int, note: float) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.8)
	var f := rng.randf_range(1700.0, 2100.0)
	for i in int(0.4 * RATE):
		var t := float(i) / RATE
		b[i] = (sin(TAU * f * t) * _ad(t, 0.0004, 0.09) + sin(TAU * f * 2.4 * t) * 0.45 * _ad(t, 0.0004, 0.05) \
			+ sin(TAU * f * 0.5 * t) * 0.3 * _ad(t, 0.001, 0.06)) * 0.6
	_add_bell(b, 0.01, note, 0.14, 0.3)
	return _to_stream(b, 0.45)


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


## Tesoro encontrado: destello de campanillas que suben y un brillo final.
static func treasure() -> AudioStreamWAV:
	var b := _buf(2.6)
	var run := [NOTE_E5, NOTE_G5, NOTE_C6, NOTE_E6, NOTE_G5 * 2.0]
	for k in run.size():
		_add_bell(b, k * 0.085, run[k], 0.26, 0.42)
	# Brillo: dos campanillas muy agudas que se apagan despacio.
	_add_bell(b, 0.46, NOTE_C6 * 2.0, 0.12, 0.9)
	_add_bell(b, 0.50, NOTE_E6 * 2.0, 0.08, 1.1)
	return _to_stream(b, 0.55)


## Decoración desbloqueada: pequeño "pop" suave y una nota cálida.
static func decor_unlock() -> AudioStreamWAV:
	var rng := _rng(21)
	var b := _buf(1.1)
	var ph := 0.0
	var lp := 0.0
	for i in int(0.12 * RATE):
		var t := float(i) / RATE
		ph += TAU * (180.0 + 520.0 * minf(t / 0.08, 1.0)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.2
		b[i] = (sin(ph) * 0.7 + lp * 0.2) * _ad(t, 0.004, 0.05)
	_add_bell(b, 0.09, NOTE_G5, 0.3, 0.45)
	_add_bell(b, 0.17, NOTE_C6, 0.22, 0.55)
	return _to_stream(b, 0.5)


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


## Escobazo: roce de paja sobre la madera (ruido agudo y granulado que sube y baja).
static func sweep(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.46)
	var lp := 0.0
	var slow := 0.0
	var grit := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var shape := pow(sin(PI * minf(t / 0.44, 1.0)), 1.5)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.55
		slow += (lp - slow) * 0.04
		# Las briznas se enganchan en las juntas del suelo: chasquidos sueltos.
		if rng.randf() < 0.0025:
			grit = 1.0
		grit *= 0.993
		b[i] = (lp - slow) * shape * (0.75 + 0.6 * grit)
	return _to_stream(b, 0.3)


## Vaciar el recogedor en la papelera: golpecito sordo y papeles que caen y se asientan.
static func dust_dump(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.7)
	var lp := 0.0
	var crinkle := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (110.0 - 40.0 * minf(t / 0.08, 1.0)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
		if rng.randf() < 0.004 * exp(-t / 0.25):
			crinkle = rng.randf_range(0.5, 1.0)
		crinkle *= 0.996
		b[i] = sin(ph) * 0.8 * _ad(t, 0.003, 0.05) + lp * (0.25 * _ad(t, 0.01, 0.2) + crinkle * 0.9)
	return _to_stream(b, 0.3)


## Ronroneo del gato (bucle de 2 s): pulsos graves de unos 25 por segundo, más fuertes al espirar.
static func cat_purr(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(2.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		# Dos respiraciones por bucle: espirar (fuerte) e inspirar (más suave y algo más agudo).
		var breath := 0.62 + 0.38 * sin(TAU * t / 2.0)
		var rate := 25.0 if fmod(t, 2.0) < 1.0 else 27.0
		var pulse := pow(maxf(0.0, sin(PI * t * rate)), 3.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.2
		b[i] = (lp2 * 2.4 + sin(TAU * 50.0 * t) * 0.18) * pulse * breath
	var stream := _to_stream(b, 0.5)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = b.size()
	return stream


## "Mrrp" del gato al acariciarlo: trino corto que sube, con la boca cerrada (pocos armónicos).
static func cat_mrrp(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.36)
	var ph := 0.0
	var f0 := rng.randf_range(360.0, 420.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := minf(t / 0.3, 1.0)
		var f := f0 * (1.0 + 0.55 * k * k) * (1.0 + 0.03 * sin(TAU * 28.0 * t) * (1.0 - k))
		ph += TAU * f / RATE
		var env := minf(t / 0.03, 1.0) * clampf((0.36 - t) / 0.12, 0.0, 1.0)
		var voice := sin(ph) + 0.45 * sin(2.0 * ph) + 0.18 * sin(3.0 * ph)
		lp += (voice - lp) * 0.35
		b[i] = lp * env
	return _to_stream(b, 0.35)


## Aplanar una caja de cartón: crujido de las solapas al doblarse, el cartón que cede y un golpe sordo
## al quedar plana contra el suelo.
static func cardboard_fold(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.62)
	var lp := 0.0
	var crack := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.45
		# Crujidos sueltos mientras se dobla (los primeros 0,35 s), cada vez más seguidos.
		if t < 0.36 and rng.randf() < 0.0012 + 0.004 * t:
			crack = rng.randf_range(0.5, 1.0)
		crack *= 0.985
		var bend := lp * crack * 0.9 + lp * 0.12 * _ad(t, 0.05, 0.18)
		# El golpe final: cartón plano contra la madera.
		var hit_t := t - 0.38
		var thump := 0.0
		if hit_t > 0.0:
			ph += TAU * (95.0 - 35.0 * minf(hit_t / 0.06, 1.0)) / RATE
			thump = sin(ph) * _ad(hit_t, 0.002, 0.05) + lp * 0.5 * _ad(hit_t, 0.001, 0.03)
		b[i] = bend + thump
	return _to_stream(b, 0.34)


## Dejar el cartón aplanado en el montón: palmada plana y un roce.
static func cardboard_drop(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(0.32)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		ph += TAU * (140.0 - 50.0 * minf(t / 0.05, 1.0)) / RATE
		b[i] = sin(ph) * 0.7 * _ad(t, 0.002, 0.04) + lp * (0.8 * _ad(t, 0.001, 0.025) + 0.15 * _ad(t, 0.02, 0.12))
	return _to_stream(b, 0.3)


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


# --- Calle: vehículos, timbre, bocina y perros ------------------------------

## Motor de coche + ruido de rodadura, en bucle. `f0` = frecuencia de giro (Hz), `rough` = aspereza.
static func engine_loop(seed_value: int, f0: float, rough: float, tyre: float, harmonics: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var loop_len := int(3.0 * RATE)
	var fade := int(0.4 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + fade)
	var lp_fast := 0.0
	var lp_slow := 0.0
	var phase := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		# Pequeña irregularidad del régimen del motor.
		var wobble := 1.0 + 0.03 * sin(t * 2.1) + 0.015 * sin(t * 5.3 + 1.0)
		phase += TAU * f0 * wobble / RATE
		var v := 0.0
		for h in range(1, harmonics + 1):
			v += sin(phase * h + h * 0.7) * (1.0 / pow(float(h), 1.25))
		# Pulsos de combustión: modulación de amplitud al ritmo del motor.
		var pulse := 1.0 - rough * 0.5 * (0.5 + 0.5 * sin(phase * 0.5))
		v *= pulse
		# Rodadura: ruido de banda media-alta.
		var n := rng.randf_range(-1.0, 1.0)
		lp_fast += (n - lp_fast) * 0.35
		lp_slow += (n - lp_slow) * 0.06
		v += (lp_fast - lp_slow) * tyre
		raw[i] = v
	return _looped(raw, loop_len, fade, 0.5)


## Motocicleta: régimen más alto y "zumbido" de dos tiempos.
static func moto_loop() -> AudioStreamWAV:
	var rng := _rng(61)
	var loop_len := int(3.0 * RATE)
	var fade := int(0.4 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + fade)
	var phase := 0.0
	var lp := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		phase += TAU * 118.0 * (1.0 + 0.02 * sin(t * 3.1)) / RATE
		var v := 0.0
		for h in range(1, 13):
			v += sin(phase * h) * (1.0 / pow(float(h), 0.9))        # diente de sierra suave
		v *= 0.7 + 0.3 * sin(phase * 0.5)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		v += lp * 0.5
		raw[i] = v
	return _looped(raw, loop_len, fade, 0.45)


## Bicicleta: carraca de la rueda libre y un siseo suave.
static func bike_loop() -> AudioStreamWAV:
	var rng := _rng(71)
	var loop_len := int(2.4 * RATE)
	var fade := int(0.3 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + fade)
	var lp := 0.0
	var tick_phase := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		var v := lp * 0.5
		tick_phase = fmod(t * 11.0, 1.0)                              # ~11 clics por segundo
		v += sin(TAU * 2400.0 * tick_phase * 0.01) * exp(-tick_phase * 90.0) * 0.5 \
			+ rng.randf_range(-1.0, 1.0) * exp(-tick_phase * 140.0) * 0.4
		raw[i] = v
	return _looped(raw, loop_len, fade, 0.3)


## Bocina de coche: dos tonos con armónicos. `length` en segundos.
static func horn(seed_value: int, length: float) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(length + 0.1)
	var f1 := rng.randf_range(395.0, 420.0)
	var f2 := f1 * 1.26
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(t / 0.015, 1.0) * clampf((length - t) / 0.06, 0.0, 1.0) if t < length else 0.0
		var v := 0.0
		for f in [f1, f2]:
			v += sin(TAU * f * t) + 0.35 * sin(TAU * f * 3.0 * t) + 0.18 * sin(TAU * f * 5.0 * t)
		b[i] = v * env * (1.0 + 0.05 * sin(t * 40.0))
	return _to_stream(b, 0.45)


## Timbre de bicicleta: dos "ding" metálicos seguidos.
static func bike_bell(seed_value: int) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var b := _buf(1.3)
	var f := rng.randf_range(2650.0, 2900.0)
	for strike_t: float in [0.0, 0.30]:
		_add_partials(b, strike_t, f, 0.5, 0.4, [1.0, 1.51, 2.37, 3.1], [1.0, 0.55, 0.3, 0.12], [1.0, 0.7, 0.45, 0.3])
	return _to_stream(b, 0.4)


## Ladrido: voz con dos formantes y un poco de aire. `f0` grave = perro grande.
static func dog_bark(seed_value: int, f0: float) -> AudioStreamWAV:
	var rng := _rng(seed_value)
	var dur := 0.2 + 120.0 / f0 * 0.0
	var b := _buf(0.32)
	var phase := 0.0
	var lp := 0.0
	for i in int(dur * RATE):
		var t := float(i) / RATE
		var f := f0 * (1.0 + 0.35 * exp(-t / 0.05) - 0.25 * t / dur)    # empieza alto y cae
		phase += TAU * f / RATE
		var v := 0.0
		for h in range(1, 10):
			var fh := f * h
			var formant := exp(-pow((fh - 750.0) / 450.0, 2.0)) + 0.55 * exp(-pow((fh - 1700.0) / 650.0, 2.0)) + 0.08
			v += sin(phase * h) * formant / float(h) * 1.6
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
		b[i] = (v + lp * 0.5) * _ad(t, 0.008, 0.075)
	return _to_stream(b, 0.5)


## Suma una nota con parciales a medida (timbres, campanas pequeñas...).
static func _add_partials(buf: PackedFloat32Array, start: float, freq: float, amp: float, decay: float, ratios: Array, amps: Array, decs: Array) -> void:
	var s0 := int(start * RATE)
	for i in range(s0, buf.size()):
		var t := float(i - s0) / RATE
		if t > decay * 6.0:
			break
		var v := 0.0
		for k in ratios.size():
			v += sin(TAU * freq * ratios[k] * t) * amps[k] * exp(-t / (decay * decs[k]))
		buf[i] += v * amp * minf(t / 0.002, 1.0)


## Convierte un buffer en un bucle continuo (mezcla el final con el principio).
static func _looped(raw: PackedFloat32Array, loop_len: int, fade: int, peak: float) -> AudioStreamWAV:
	var b := PackedFloat32Array()
	b.resize(loop_len)
	for i in loop_len:
		if i < fade:
			var w := float(i) / fade
			b[i] = raw[i] * w + raw[loop_len + i] * (1.0 - w)
		else:
			b[i] = raw[i]
	var stream := _to_stream(b, peak)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_len
	return stream


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

extends SceneTree
## Genera las texturas del juego (originales, sin recursos de terceros) en art/textures/.
## Son PNG normales: se pueden abrir y retocar en Krita o GIMP.
##   godot --headless --path . --script res://tools/make_textures.gd
## Cada textura es "tileable" (se repite sin costuras). Los mapas de normales se
## calculan a partir de un mapa de alturas.

const OUT := "res://art/textures/"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_rng.seed = 2026
	_make_wood_planks()
	_make_wood_light()
	_make_cardboard()
	_make_plaster()
	_make_beadboard()
	_make_rug()
	_make_asphalt()
	_make_pavement()
	_make_grass()
	_make_roof_tiles()
	print("Texturas generadas en ", OUT)
	quit()


# --- Utilidades ----------------------------------------------------------

func _noise(seed_value: int, freq: float, size: int, octaves: int = 3) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n.get_seamless_image(size, size, false, false, 0.1, true)


func _sample(img: Image, x: int, y: int) -> float:
	var w := img.get_width()
	var h := img.get_height()
	return img.get_pixel(posmod(x, w), posmod(y, h)).r


func _height_to_normal(h: Image, strength: float) -> Image:
	var w := h.get_width()
	var ht := h.get_height()
	var out := Image.create(w, ht, true, Image.FORMAT_RGB8)
	for y in ht:
		for x in w:
			var l := h.get_pixel(posmod(x - 1, w), y).r
			var r := h.get_pixel(posmod(x + 1, w), y).r
			var u := h.get_pixel(x, posmod(y - 1, ht)).r
			var d := h.get_pixel(x, posmod(y + 1, ht)).r
			var nrm := Vector3((l - r) * strength, (d - u) * strength, 1.0).normalized()
			out.set_pixel(x, y, Color(nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, nrm.z * 0.5 + 0.5))
	return out


func _save(img: Image, file_name: String, mipmaps: bool = true) -> void:
	if mipmaps:
		img.generate_mipmaps()
	var path := ProjectSettings.globalize_path(OUT + file_name)
	var err := img.save_png(path)
	print("  ", file_name, " -> ", error_string(err))


# --- Texturas ------------------------------------------------------------

## Suelo de tablas de roble claro: veta, anillos, nudos, juntas y holguras.
func _make_wood_planks() -> void:
	var n := 1024
	var planks := 6
	var pw := n / planks
	var grain := _noise(11, 0.05, n, 3)
	var fine := _noise(12, 0.2, n, 2)
	var knots := _noise(13, 0.012, n, 1)
	var base := Color("d9a86c")
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for i in planks:
		var tone := _rng.randf_range(-0.07, 0.07)
		var off_x := _rng.randi_range(0, n - 1)
		var off_y := _rng.randi_range(0, n - 1)
		var seam := _rng.randi_range(120, n - 120)
		var phase := _rng.randf() * TAU
		for y in n:
			for x in pw:
				var px := i * pw + x
				var g := _sample(grain, x * 4 + off_x, int(y * 0.14) + off_y)
				var f := _sample(fine, px * 2, y * 2)
				var k := _sample(knots, px, y)
				var ring := 0.5 + 0.5 * sin(x * 0.42 + g * 8.0 + phase)
				var shade := 0.84 + 0.26 * g + 0.05 * (f - 0.5) + 0.045 * ring
				shade -= 0.14 * smoothstep(0.93, 0.99, k)   # nudos ocasionales
				var c := Color(base.r + tone, base.g + tone * 0.9, base.b + tone * 0.8) * shade
				var hgt := 0.62 + 0.08 * g
				if x < 2 or x >= pw - 1:        # holgura entre tablas
					c *= 0.5
					hgt = 0.0
				elif x == 2:
					c *= 1.07
				if y >= seam and y < seam + 2:  # junta de testa
					c *= 0.55
					hgt = 0.1
				albedo.set_pixel(px, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
				height.set_pixel(px, y, Color(hgt, hgt, hgt))
	_save(albedo, "wood_planks_albedo.png")
	_save(_height_to_normal(height, 5.0), "wood_planks_normal.png")


## Madera clara de mobiliario (veta vertical fina).
func _make_wood_light() -> void:
	var n := 512
	var grain := _noise(21, 0.06, n, 3)
	var fine := _noise(22, 0.3, n, 2)
	var base := Color("e6c995")
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var g := _sample(grain, x * 5, int(y * 0.12))
			var f := _sample(fine, x * 2, y)
			var ring := 0.5 + 0.5 * sin(x * 0.5 + g * 9.0)
			var shade := 0.88 + 0.2 * g + 0.04 * (f - 0.5) + 0.04 * ring
			var c := base * shade
			albedo.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
			var hg := 0.5 + 0.2 * ring * g
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "wood_light_albedo.png")
	_save(_height_to_normal(height, 2.5), "wood_light_normal.png")


## Cartón ondulado.
func _make_cardboard() -> void:
	var n := 512
	var fibre := _noise(31, 0.18, n, 3)
	var blotch := _noise(32, 0.02, n, 2)
	var base := Color("c9a26c")
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var wave := 0.5 + 0.5 * sin(float(y) / n * TAU * 22.0)
			var f := _sample(fibre, x, y)
			var b := _sample(blotch, x, y)
			var shade := 0.9 + 0.07 * wave + 0.1 * (f - 0.5) + 0.12 * (b - 0.5)
			var c := base * shade
			albedo.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
			var hg := 0.4 + 0.3 * wave + 0.1 * f
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "cardboard_albedo.png")
	_save(_height_to_normal(height, 2.0), "cardboard_normal.png")


## Pintura rugosa de pared (casi blanca: el color lo pone el material).
func _make_plaster() -> void:
	var n := 512
	var coarse := _noise(41, 0.04, n, 4)
	var fine := _noise(42, 0.35, n, 2)
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var c := _sample(coarse, x, y)
			var f := _sample(fine, x, y)
			var v := 0.965 + 0.03 * (c - 0.5) + 0.016 * (f - 0.5)
			albedo.set_pixel(x, y, Color(v, v, v))
			var hg := 0.5 + 0.35 * (c - 0.5) + 0.25 * (f - 0.5)
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "plaster_albedo.png")
	_save(_height_to_normal(height, 1.6), "plaster_normal.png")


## Friso de tablas machihembradas con ranura en V y bocel central.
func _make_beadboard() -> void:
	var n := 512
	var boards := 8
	var bw := n / boards
	var grain := _noise(51, 0.08, n, 3)
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var bx := x % bw
			var g := _sample(grain, x * 3, int(y * 0.2))
			var v := 0.94 + 0.06 * (g - 0.5)
			var hg := 0.8
			if bx < 3 or bx >= bw - 3:        # ranura en V entre tablas
				v *= 0.68
				hg = 0.0
			elif bx == 3 or bx == bw - 4:
				v *= 0.88
				hg = 0.45
			var d := absf(bx - bw * 0.5)       # bocel central
			if d < 2.5:
				hg += 0.12
				v *= 1.03
			albedo.set_pixel(x, y, Color(v, v, v))
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "beadboard_albedo.png")
	_save(_height_to_normal(height, 4.0), "beadboard_normal.png")


## Alfombra tejida con orla y rombos.
func _make_rug() -> void:
	var w := 1024
	var h := 704
	var cream := Color("f0dcb8")
	var navy := Color("34506f")
	var terra := Color("c9694b")
	var blue := Color("5f7fa3")
	var light := Color("86a6c4")
	var fibre := _noise(61, 0.3, 1024, 2)
	var albedo := Image.create(w, h, true, Image.FORMAT_RGB8)
	var height := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var u := float(x) / w
			var v := float(y) / h
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v) * float(h) / w * 1.45)
			var c: Color
			if edge < 0.025:
				c = cream
			elif edge < 0.05:
				c = navy
			elif edge < 0.085:
				c = terra
			elif edge < 0.10:
				c = cream
			elif edge < 0.115:
				c = navy
			else:
				var du := absf(fposmod(u * 6.0, 1.0) - 0.5)
				var dv := absf(fposmod(v * 4.0, 1.0) - 0.5)
				var diamond := du + dv
				if diamond < 0.18:
					c = cream
				elif diamond < 0.32:
					c = terra
				elif diamond < 0.42:
					c = light
				else:
					c = blue
			var weave := 0.94 + 0.06 * float((x + y) % 2) + 0.05 * float((x / 2 + y / 2) % 2)
			var f := _sample(fibre, x, y)
			var shade := weave + 0.08 * (f - 0.5)
			c = c * shade
			albedo.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
			var hg := 0.5 + 0.25 * float((x + y) % 2) + 0.15 * float((x / 2 + y / 2) % 2)
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "rug_albedo.png")
	_save(_height_to_normal(height, 2.0), "rug_normal.png")


# --- Exterior (calle y jardín) ---------------------------------------------

## Asfalto: gravilla fina, parches y alguna grieta. Gris oscuro.
func _make_asphalt() -> void:
	var n := 512
	var coarse := _noise(71, 0.015, n, 3)
	var grit := _noise(72, 0.45, n, 2)
	var crack := _noise(73, 0.03, n, 2)
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var c := _sample(coarse, x, y)
			var g := _sample(grit, x, y)
			var k := absf(_sample(crack, x, y) - 0.5)
			var v := 0.30 + 0.07 * (c - 0.5) + 0.12 * (g - 0.5)
			if k < 0.012:
				v *= 0.55          # grieta
			var col := Color(v, v * 1.01, v * 1.04)
			albedo.set_pixel(x, y, col)
			var hg := 0.5 + 0.3 * (g - 0.5) - (0.25 if k < 0.012 else 0.0)
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "asphalt_albedo.png")
	_save(_height_to_normal(height, 2.4), "asphalt_normal.png")


## Acera de losetas de hormigón (4 x 4 losetas por azulejo) con juntas y manchas.
func _make_pavement() -> void:
	var n := 512
	var cells := 4
	var cw := n / cells
	var blotch := _noise(81, 0.02, n, 3)
	var grit := _noise(82, 0.4, n, 2)
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	var tone: Array[float] = []
	for i in cells * cells:
		tone.append(_rng.randf_range(-0.04, 0.04))
	for y in n:
		for x in n:
			var cx := x / cw
			var cy := y / cw
			var b := _sample(blotch, x, y)
			var g := _sample(grit, x, y)
			var v := 0.66 + tone[cy * cells + cx] + 0.08 * (b - 0.5) + 0.06 * (g - 0.5)
			var hg := 0.8
			var lx := x % cw
			var ly := y % cw
			if lx < 3 or ly < 3:       # junta entre losetas
				v *= 0.62
				hg = 0.1
			albedo.set_pixel(x, y, Color(v, v * 0.99, v * 0.96))
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "pavement_albedo.png")
	_save(_height_to_normal(height, 3.0), "pavement_normal.png")


## Hierba para el terreno (casi blanca/verde claro: el color grande lo pone el vértice).
func _make_grass() -> void:
	var n := 512
	var blades := _noise(91, 0.35, n, 3)
	var tufts := _noise(92, 0.05, n, 3)
	var fine := _noise(93, 0.9, n, 1)
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var b := _sample(blades, x * 2, y)    # hojas algo alargadas
			var t := _sample(tufts, x, y)
			var f := _sample(fine, x, y)
			var v := 0.80 + 0.28 * (b - 0.5) + 0.20 * (t - 0.5) + 0.08 * (f - 0.5)
			v = clampf(v, 0.0, 1.0)
			albedo.set_pixel(x, y, Color(v * 0.97, v, v * 0.90))
			height.set_pixel(x, y, Color(b, b, b))
	_save(albedo, "grass_albedo.png")
	_save(_height_to_normal(height, 3.0), "grass_normal.png")


## Tejas curvas solapadas (hileras de arcos). Casi blancas: el tinte lo pone el material.
func _make_roof_tiles() -> void:
	var n := 512
	var rows := 8
	var cols := 8
	var rh := n / rows
	var cw := n / cols
	var grit := _noise(101, 0.3, n, 2)
	var blotch := _noise(102, 0.03, n, 3)
	var albedo := Image.create(n, n, true, Image.FORMAT_RGB8)
	var height := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var row := y / rh
			var shift := (cw / 2) if row % 2 == 1 else 0
			var lx := float((x + shift) % cw) / cw     # 0..1 a lo ancho de la teja
			var ly := float(y % rh) / rh                # 0..1 a lo largo (arriba = bajo la teja de encima)
			var curve := sin(lx * PI)                   # sección curva de la teja
			var shade := 0.74 + 0.22 * curve + 0.16 * ly
			if ly < 0.12:
				shade *= 0.55                           # sombra bajo la hilera superior
			var g := _sample(grit, x, y)
			var b := _sample(blotch, x, y)
			shade += 0.06 * (g - 0.5) + 0.12 * (b - 0.5)
			shade = clampf(shade, 0.0, 1.0)
			albedo.set_pixel(x, y, Color(shade, shade, shade))
			var hg := 0.3 + 0.45 * curve + 0.25 * ly
			height.set_pixel(x, y, Color(hg, hg, hg))
	_save(albedo, "roof_tiles_albedo.png")
	_save(_height_to_normal(height, 4.0), "roof_tiles_normal.png")

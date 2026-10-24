extends SceneTree
## Genera los ItemData (.tres) y los catálogos de las salas de botones/carretes, telas/cintas
## y almacén de sastrería. Todos los datos de la mercería viven aquí, en una tabla; para añadir
## una variante basta con añadir una fila y volver a ejecutar:
##   godot --headless --path . --script res://tools/make_item_data.gd
## (Los ovillos de la sala 1 son anteriores y siguen en data/items/yarn_*.tres.)

const M := "res://art/models/items/"

var _motion := {}
var _by_id := {}


func _init() -> void:
	for id in ["wool", "plastic", "wood", "metal", "fabric", "box"]:
		_motion[id] = load("res://data/motion/%s.tres" % id)

	_make_spools_and_buttons()
	_make_fabrics_and_ribbons()
	_make_store()
	_make_treasures()
	print("Datos de objetos generados.")
	quit()


# --- Constructores -------------------------------------------------------

func _base(id: String, label: String, display: String, detail: String, family: ItemData.Family, color: Color, motion: String) -> ItemData:
	var d := ItemData.new()
	d.id = StringName(id)
	d.sort_key = StringName(id)
	d.sort_label = label
	d.display_name = display
	d.detail = detail
	d.family = family
	d.color = color
	d.motion = _motion[motion]
	_by_id[id] = d
	return d


func _cyl(d: ItemData, radius: float, height: float, model: String, pick: float, scale: float = 1.0) -> void:
	d.shape = ItemData.Shape.CYLINDER
	d.radius = radius * scale
	d.size = Vector3(radius * scale, height * scale, radius * scale)
	d.variants = [load(M + model + ".glb")]
	d.model_scale = scale
	d.pick_radius = pick


func _box(d: ItemData, size: Vector3, model: String, pick: float, scale: float = 1.0) -> void:
	d.shape = ItemData.Shape.BOX
	d.size = size * scale
	d.variants = [load(M + model + ".glb")]
	d.model_scale = scale
	d.pick_radius = pick


func _save(d: ItemData) -> void:
	var path := "res://data/items/%s.tres" % d.id
	var err := ResourceSaver.save(d, path)
	if err != OK:
		push_error("No se pudo guardar %s (%s)" % [path, error_string(err)])


func _catalog(file: String, ids: Array) -> void:
	var cat := ItemCatalog.new()
	var list: Array[ItemData] = []
	for id in ids:
		list.append(_by_id[id])
	cat.items = list
	var err := ResourceSaver.save(cat, "res://data/%s.tres" % file)
	if err != OK:
		push_error("No se pudo guardar el catálogo %s" % file)
	print("  catálogo %s: %d tipos" % [file, list.size()])


# --- Sala 2: carretes de hilo y botones ----------------------------------

func _make_spools_and_buttons() -> void:
	var spools := [
		["red", "Hilo rojo", Color(0.85, 0.18, 0.20), 0.0],
		["yellow", "Hilo amarillo", Color(0.95, 0.78, 0.20), 0.0],
		["green", "Hilo verde", Color(0.25, 0.60, 0.30), 0.0],
		["blue", "Hilo azul", Color(0.25, 0.45, 0.80), 0.0],
		["violet", "Hilo violeta", Color(0.55, 0.35, 0.75), 0.0],
		["pink", "Hilo rosa", Color(0.93, 0.55, 0.70), 0.0],
		["white", "Hilo blanco", Color(0.95, 0.94, 0.90), 0.0],
		["black", "Hilo negro", Color(0.12, 0.12, 0.14), 0.0],
		["gold", "Hilo dorado", Color(0.90, 0.72, 0.25), 0.9],
		["silver", "Hilo plateado", Color(0.80, 0.82, 0.86), 0.9],
	]
	var ids := []
	for s in spools:
		var d := _base("spool_" + s[0], s[1], "Carrete de " + s[1].to_lower(), "Hilo metálico · brillante" if s[3] > 0.0 else "Hilo de algodón · 200 m", ItemData.Family.THREAD, s[2], "wood")
		_cyl(d, 0.026, 0.056, "spool", 0.05, 1.35)
		d.material_kind = &"thread"
		d.metallic = s[3]
		d.roughness = 0.45 if s[3] > 0.0 else 0.75
		d.accent_kind = &"wood"
		d.accent_color = Color(0.88, 0.76, 0.55)
		d.spawn_count = 6
		d.spawn_zone = ItemData.SpawnZone.ANY
		_save(d)
		ids.append(d.id)

	var buttons := [
		["wood_light", "Madera clara", "Botón de madera clara", "Madera de haya", &"wood", Color(0.92, 0.76, 0.52), "wood", 0.6],
		["wood_dark", "Madera oscura", "Botón de madera oscura", "Madera de nogal", &"wood", Color(0.50, 0.30, 0.17), "wood", 0.6],
		["plastic_white", "Plástico blanco", "Botón de plástico blanco", "Camisería", &"plastic", Color(0.96, 0.96, 0.94), "plastic", 0.28],
		["plastic_red", "Plástico rojo", "Botón de plástico rojo", "Abrigo", &"plastic", Color(0.85, 0.18, 0.20), "plastic", 0.28],
		["brass", "Latón", "Botón de latón", "Chaqueta · dorado", &"metal", Color(0.86, 0.66, 0.30), "metal", 0.3],
		["silver", "Plata", "Botón plateado", "Chaqueta · plata", &"metal", Color(0.82, 0.84, 0.88), "metal", 0.3],
		["glass_blue", "Cristal azul", "Botón de cristal azul", "Cristal tallado", &"glass", Color(0.40, 0.60, 0.95, 0.6), "plastic", 0.1],
		["glass_green", "Cristal verde", "Botón de cristal verde", "Cristal tallado", &"glass", Color(0.35, 0.80, 0.55, 0.6), "plastic", 0.1],
		["pearl", "Nácar", "Botón de nácar", "Nácar natural", &"pearl", Color(0.95, 0.92, 0.88), "plastic", 0.22],
		["vintage", "Vintage", "Botón vintage de baquelita", "Colección vintage", &"plastic", Color(0.22, 0.11, 0.07), "plastic", 0.12],
	]
	for b in buttons:
		var d := _base("btn_" + b[0], b[1], b[2], b[3], ItemData.Family.BUTTON, b[5], b[6])
		_cyl(d, 0.02, 0.006, "button_flat2", 0.038)
		d.variants = [load(M + "button_flat2.glb"), load(M + "button_flat4.glb"), load(M + "button_rim4.glb"), load(M + "button_shank.glb")]
		d.rest_half_height = 0.003
		d.material_kind = b[4]
		d.roughness = b[7]
		d.accent_kind = &"plastic"
		d.accent_color = Color(0.1, 0.07, 0.05)
		d.spawn_count = 9
		d.spawn_zone = ItemData.SpawnZone.TABLE
		_save(d)
		ids.append(d.id)
	_catalog("catalog_buttons_spools", ids)


# --- Sala 3: telas y cintas -----------------------------------------------

func _make_fabrics_and_ribbons() -> void:
	# [id, etiqueta, nombre, detalle, patrón, color a, color b, color c, escala, brillo]
	var bolts := [
		["linen", "Lino natural", "Rollo de lino natural", "Tela lisa", 0, Color(0.86, 0.80, 0.66), Color.WHITE, Color.WHITE, 1.0],
		["gingham", "Vichy rojo", "Rollo de vichy rojo", "Tela estampada · cuadros", 2, Color(0.97, 0.95, 0.92), Color(0.92, 0.58, 0.58), Color(0.80, 0.20, 0.20), 1.0],
		["stripes", "Rayas azules", "Rollo de rayas azules", "Tela estampada · rayas", 1, Color(0.95, 0.95, 0.93), Color(0.25, 0.40, 0.70), Color.WHITE, 1.2],
		["floral", "Flores rosas", "Rollo de flores rosas", "Tela estampada · floral", 4, Color(0.98, 0.92, 0.90), Color(0.90, 0.45, 0.60), Color(0.95, 0.80, 0.30), 1.0],
		["polka", "Lunares marino", "Rollo de lunares marino", "Tela estampada · lunares", 3, Color(0.15, 0.20, 0.40), Color(0.95, 0.93, 0.88), Color.WHITE, 1.0],
		["tartan", "Tartán verde", "Rollo de tartán verde", "Lana escocesa", 5, Color(0.15, 0.40, 0.25), Color(0.10, 0.20, 0.45), Color(0.90, 0.85, 0.40), 1.0],
		["denim", "Vaquero", "Rollo de tela vaquera", "Algodón grueso", 6, Color(0.20, 0.32, 0.55), Color(0.45, 0.58, 0.80), Color.WHITE, 1.0],
		["velvet", "Terciopelo violeta", "Rollo de terciopelo violeta", "Tela suave", 7, Color(0.40, 0.20, 0.55), Color.WHITE, Color.WHITE, 1.0],
		["cord", "Pana mostaza", "Rollo de pana mostaza", "Pana de cordón ancho", 8, Color(0.82, 0.62, 0.20), Color.WHITE, Color.WHITE, 1.0],
		["lace", "Encaje crema", "Rollo de encaje crema", "Encaje de algodón", 9, Color(0.97, 0.94, 0.86), Color.WHITE, Color.WHITE, 1.0],
	]
	var ids := []
	for f in bolts:
		var d := _base("bolt_" + f[0], f[1], f[2], f[3], ItemData.Family.FABRIC, f[5], "fabric")
		_cyl(d, 0.055, 0.42, "bolt", 0.10)
		d.shape_rotation_deg = Vector3(90, 0, 0)       # el modelo yace a lo largo de Z
		d.rest_half_height = 0.055
		d.pattern = f[4]
		d.color_b = f[6]
		d.color_c = f[7]
		d.pattern_scale = f[8]
		d.pattern_mapping = 1
		d.roughness = 0.93
		d.accent_kind = &"cardboard"
		d.accent_color = Color(0.78, 0.62, 0.42)
		d.align_on_shelf = true
		d.spawn_count = 4
		d.spawn_zone = ItemData.SpawnZone.FLOOR
		_save(d)
		ids.append(d.id)

	var folded := [
		["gingham", "Vichy amarillo", "Tela doblada de vichy amarillo", 2, Color(0.99, 0.97, 0.88), Color(0.97, 0.82, 0.35), Color(0.92, 0.65, 0.15)],
		["floral", "Flores azules", "Tela doblada de flores azules", 4, Color(0.96, 0.96, 0.98), Color(0.35, 0.55, 0.85), Color(0.95, 0.85, 0.35)],
		["stripes", "Rayas rojas", "Tela doblada de rayas rojas", 1, Color(0.97, 0.95, 0.92), Color(0.82, 0.22, 0.25), Color.WHITE],
		["tartan", "Tartán rojo", "Tela doblada de tartán rojo", 5, Color(0.65, 0.12, 0.15), Color(0.12, 0.18, 0.35), Color(0.92, 0.85, 0.5)],
		["polka", "Lunares rosa", "Tela doblada de lunares rosa", 3, Color(0.96, 0.72, 0.80), Color(0.99, 0.96, 0.94), Color.WHITE],
	]
	for f in folded:
		var d := _base("fold_" + f[0], f[1], f[2], "Tela doblada · corte de 1 m", ItemData.Family.FABRIC, f[4], "fabric")
		_box(d, Vector3(0.34, 0.045, 0.27), "folded", 0.12)
		d.pattern = f[3]
		d.color_b = f[5]
		d.color_c = f[6]
		d.pattern_mapping = 0
		d.roughness = 0.95
		d.align_on_shelf = true
		d.spawn_count = 3
		d.spawn_zone = ItemData.SpawnZone.ANY
		_save(d)
		ids.append(d.id)

	# Cintas: [id, etiqueta, nombre, detalle, patrón, a, b, c, metálico, escala, modelo]
	var ribbons := [
		["red", "Satén rojo", "Carrete de cinta de satén rojo", "Cinta de satén · 10 m", 0, Color(0.80, 0.12, 0.18), Color.WHITE, Color.WHITE, 0.0, 1.0, "ribbon_reel"],
		["gingham", "Vichy rosa", "Carrete de cinta vichy rosa", "Cinta decorativa", 2, Color(0.98, 0.95, 0.95), Color(0.95, 0.70, 0.78), Color(0.88, 0.45, 0.60), 0.0, 1.0, "ribbon_reel"],
		["lace", "Encaje blanco", "Carrete de encaje blanco", "Encaje de algodón", 9, Color(0.97, 0.95, 0.90), Color.WHITE, Color.WHITE, 0.0, 1.0, "ribbon_reel"],
		["gold", "Cinta dorada", "Carrete de cinta dorada", "Cinta metalizada", 1, Color(0.85, 0.68, 0.25), Color(0.98, 0.9, 0.55), Color.WHITE, 0.7, 1.0, "ribbon_reel"],
		["bow", "Lazos", "Lazo decorativo", "Lazo de cinta · regalo", 0, Color(0.85, 0.20, 0.30), Color.WHITE, Color.WHITE, 0.0, 0.7, "bow"],
	]
	for r in ribbons:
		var d := _base("ribbon_" + r[0], r[1], r[2], r[3], ItemData.Family.RIBBON, r[5], "fabric")
		if r[10] == "bow":
			_box(d, Vector3(0.113, 0.015, 0.071), "bow", 0.06, r[9])
			d.material_kind = &"ribbon"
		else:
			_cyl(d, 0.034, 0.028, "ribbon_reel", 0.05)
			d.rest_half_height = 0.014
		d.pattern = r[4]
		d.color_b = r[6]
		d.color_c = r[7]
		d.metallic = r[8]
		d.material_kind = &"ribbon"
		d.roughness = 0.32
		d.accent_kind = &"plastic"
		d.accent_color = Color(0.95, 0.95, 0.92)
		d.spawn_count = 6
		d.spawn_zone = ItemData.SpawnZone.ANY
		_save(d)
		ids.append(d.id)
	_catalog("catalog_fabrics_ribbons", ids)


# --- Sala 4: almacén de sastrería -----------------------------------------

func _make_store() -> void:
	var ids := []
	# Cuelgan del panel de ganchos.
	var hangers := [
		["scissors_large", "Tijeras de sastre", "Tijeras de sastre", "Acero · 24 cm", Color(0.75, 0.15, 0.15), 1.35, "scissors", Vector3(-0.0625, 0, -0.018), Vector3(0.168, 0.007, 0.068)],
		["scissors_small", "Tijeras de bordar", "Tijeritas de bordar", "Acero · 11 cm", Color(0.20, 0.50, 0.70), 0.85, "scissors", Vector3(-0.0625, 0, -0.018), Vector3(0.168, 0.007, 0.068)],
		["tape", "Cintas métricas", "Cinta métrica enrollable", "150 cm", Color(0.85, 0.70, 0.20), 1.0, "tape_measure", Vector3(-0.0505, 0, 0), Vector3(0.103, 0.018, 0.069)],
		["ruler", "Reglas de madera", "Regla de madera", "30 cm", Color(0.90, 0.78, 0.45), 1.0, "ruler", Vector3(-0.138, 0, 0), Vector3(0.300, 0.005, 0.036)],
		["zipper", "Cremalleras", "Cremallera", "Cremallera de metal · 20 cm", Color(0.15, 0.20, 0.45), 1.0, "zipper", Vector3(-0.077, 0, 0), Vector3(0.210, 0.007, 0.032)],
	]
	for h in hangers:
		var d := _base(h[0], h[1], h[2], h[3], ItemData.Family.ACCESSORY, h[4], "metal")
		_box(d, h[8], h[6], 0.09, h[5])
		d.hang_offset = h[7] * h[5]
		d.material_kind = &"plastic"
		d.roughness = 0.35
		d.accent_kind = &"paper" if h[0] == "tape" else &"plastic"
		d.accent_color = Color(0.95, 0.92, 0.78) if h[0] == "tape" else Color(0.12, 0.09, 0.06)
		if h[0] == "ruler":
			d.material_kind = &"wood"
		if h[0] == "zipper":
			d.material_kind = &"cloth"
		d.spawn_count = 4
		d.spawn_zone = ItemData.SpawnZone.ANY
		_save(d)
		ids.append(d.id)

	# Piezas pequeñas: bandeja de celdas.
	var smalls := [
		["thimble_silver", "Dedales de plata", "Dedal de plata", "Plata · talla M", Color(0.85, 0.86, 0.90), "thimble", &"metal", 0.0155, 0.028, 1.0, "metal"],
		["thimble_brass", "Dedales de latón", "Dedal de latón", "Latón · talla S", Color(0.86, 0.66, 0.30), "thimble", &"metal", 0.0155, 0.028, 1.0, "metal"],
		["needle_case", "Estuches de agujas", "Estuche de agujas", "Agujas surtidas", Color(0.25, 0.50, 0.70), "needle_case", &"plastic", 0.0105, 0.098, 1.0, "plastic"],
		["pincushion", "Acericos", "Acerico de tomate", "Con alfileres", Color(0.80, 0.15, 0.18), "pincushion", &"cloth", 0.036, 0.049, 0.7, "fabric"],
		["chalk", "Tizas de sastre", "Tiza de sastre", "Para marcar patrones", Color(0.90, 0.55, 0.65), "chalk", &"paper", 0.030, 0.007, 0.85, "plastic"],
	]
	for s in smalls:
		var d := _base(s[0], s[1], s[2], s[3], ItemData.Family.ACCESSORY, s[4], s[10])
		if s[0] == "chalk":
			_box(d, Vector3(0.060, 0.007, 0.043), "chalk", 0.04, s[9])
		else:
			_cyl(d, s[7], s[8], s[5], 0.035, s[9])
		d.material_kind = s[6]
		d.roughness = 0.3 if s[6] == &"metal" else 0.8
		d.accent_kind = &"cloth" if s[0] == "pincushion" else &"plastic"
		d.accent_color = Color(0.25, 0.55, 0.25) if s[0] == "pincushion" else Color(0.92, 0.85, 0.70)
		d.spawn_count = 5
		d.spawn_zone = ItemData.SpawnZone.TABLE
		_save(d)
		ids.append(d.id)

	# Piezas grandes: estanterías (la primera, cinco tipos; la segunda, junto al rincón, otros cinco).
	# Las cajas, latas, la plancha y la bobina usan el perfil "box": pesan, apenas rebotan y frenan pronto
	# (se deslizan o vuelcan en vez de salir despedidas).
	var bigs := [
		["sewing_box", "Cajas de costura", "Caja de costura de madera", "Con asa y cierres", Color(0.78, 0.55, 0.36), "sewing_box", ItemData.Shape.BOX, Vector3(0.31, 0.212, 0.21), &"wood", "box", 4],
		["sewing_tin", "Latas de costura", "Lata de costura", "Hojalata decorada", Color(0.75, 0.20, 0.25), "sewing_tin", ItemData.Shape.CYLINDER, Vector3(0.088, 0.063, 0.088), &"metal", "box", 4],
		["pattern", "Patrones", "Sobre de patrón de costura", "Patrón de vestido", Color(0.90, 0.75, 0.55), "pattern_envelope", ItemData.Shape.BOX, Vector3(0.22, 0.005, 0.32), &"paper", "fabric", 4],
		["hoop", "Bastidores", "Bastidor de bordado", "Con tela tensada", Color(0.95, 0.90, 0.80), "embroidery_hoop", ItemData.Shape.CYLINDER, Vector3(0.095, 0.024, 0.095), &"cloth", "wood", 4],
		["iron", "Planchas de hierro", "Plancha de hierro vintage", "Hierro fundido", Color(0.22, 0.22, 0.25), "iron", ItemData.Shape.BOX, Vector3(0.150, 0.119, 0.075), &"metal", "box", 4],
		["button_box", "Cajas de botones", "Caja de botones grande", "Muestrario surtido", Color(0.55, 0.70, 0.62), "button_box", ItemData.Shape.BOX, Vector3(0.24, 0.094, 0.17), &"paper", "box", 3],
		["interfacing_roll", "Rollos de entretela", "Rollo de entretela", "Entretela termoadhesiva · 10 m", Color(0.95, 0.94, 0.90), "interfacing_roll", ItemData.Shape.CYLINDER, Vector3(0.063, 0.282, 0.063), &"cloth", "fabric", 3],
		["stuffing_bag", "Bolsas de relleno", "Bolsa de relleno", "Fibra para cojines y peluches", Color(0.97, 0.97, 0.98), "stuffing_bag", ItemData.Shape.BOX, Vector3(0.21, 0.189, 0.156), &"cloth", "fabric", 3],
		["needle_box", "Cajas de agujas", "Caja de agujas surtidas", "Agujas de mano y de máquina", Color(0.20, 0.35, 0.55), "needle_box", ItemData.Shape.BOX, Vector3(0.2, 0.045, 0.14), &"metal", "box", 3],
		["industrial_cone", "Bobinas industriales", "Bobina industrial", "Hilo de poliéster · 5000 m", Color(0.85, 0.30, 0.25), "industrial_cone", ItemData.Shape.CYLINDER, Vector3(0.052, 0.221, 0.052), &"thread", "box", 3],
	]
	for b in bigs:
		var d := _base(b[0], b[1], b[2], b[3], ItemData.Family.ACCESSORY, b[4], b[9])
		if b[6] == ItemData.Shape.BOX:
			_box(d, b[7], b[5], 0.12)
		else:
			_cyl(d, b[7].x, b[7].y, b[5], 0.1)
		d.material_kind = b[8]
		d.roughness = 0.5
		d.accent_kind = &"wood" if b[0] in ["sewing_box", "iron", "hoop"] else (&"cloth" if b[0] == "stuffing_bag" else &"paper")
		d.accent_color = Color(0.55, 0.38, 0.25) if b[0] == "sewing_box" else (Color(0.45, 0.30, 0.20) if b[0] == "iron" else (Color(0.82, 0.62, 0.38) if b[0] == "hoop" else Color(0.97, 0.95, 0.90)))
		if b[0] == "stuffing_bag":
			d.accent_color = Color(0.86, 0.36, 0.40)
		elif b[0] == "interfacing_roll":
			d.accent_color = Color(0.62, 0.48, 0.32)
		d.align_on_shelf = true
		d.spawn_count = b[10]
		d.spawn_zone = ItemData.SpawnZone.FLOOR
		_save(d)
		ids.append(d.id)
	_catalog("catalog_store", ids)


# --- Tesoros escondidos -----------------------------------------------------

## Versiones de lujo y mayor tamaño de objetos de cada sala. No cuentan para ordenar la sala:
## se esconden en un sitio alto o apartado y, al encontrarlos, se exponen en la repisa de la sala.
func _make_treasures() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/treasures")
	# [sala, id, objeto base, nombre, detalle, factor de tamaño, color, metálico (-1 = el del objeto base)]
	var table := [
		["yarn", "tr_golden_yarn", "yarn_red", "Ovillo de lana dorada", "Hilada a mano con hebras de oro", 1.3, Color(0.97, 0.76, 0.25), -1.0],
		["yarn", "tr_silver_yarn", "yarn_white", "Ovillo de seda plateada", "Seda de luna, suave como una nube", 1.3, Color(0.78, 0.82, 0.92), -1.0],
		["buttons", "tr_sapphire_button", "btn_glass_blue", "Botón de zafiro", "El botón más bonito de la tienda", 2.6, Color(0.12, 0.28, 0.9, 0.75), -1.0],
		["buttons", "tr_gold_spool", "spool_gold", "Carrete de oro macizo", "Hilo de oro para vestidos de gala", 1.6, Color(1.0, 0.78, 0.22), 1.0],
		["fabrics", "tr_royal_ribbon", "ribbon_gold", "Cinta real", "Seda bordada con hilo de oro", 1.7, Color(0.78, 0.10, 0.28), 0.7],
		["fabrics", "tr_silk_bow", "ribbon_bow", "Lazo de seda de gala", "Se estrenó en un baile de 1925", 2.2, Color(0.95, 0.80, 0.85), -1.0],
		["store", "tr_gold_thimble", "thimble_brass", "Dedal de oro", "Perteneció a una gran modista", 2.6, Color(1.0, 0.80, 0.28), 1.0],
		["store", "tr_pearl_scissors", "scissors_small", "Tijeras de nácar", "Cortaron el primer vestido de la tienda", 1.5, Color(0.94, 0.92, 0.88), 0.3],
	]
	var by_room := {}
	for t in table:
		var base: ItemData = _by_id.get(t[2], null)
		if base == null:
			base = load("res://data/items/%s.tres" % t[2])
		var d := base.duplicate() as ItemData
		var k: float = t[5]
		d.id = StringName(t[1])
		d.sort_key = d.id
		d.sort_label = t[3]
		d.display_name = t[3]
		d.detail = t[4]
		d.treasure = true
		d.spawn_count = 1
		d.spawn_zone = ItemData.SpawnZone.ANY
		d.radius = base.radius * k
		d.size = base.size * k
		if base.rest_half_height >= 0.0:
			d.rest_half_height = base.rest_half_height * k
		d.pick_radius = maxf(base.pick_radius * k, 0.07)
		d.model_scale = base.model_scale * k
		d.color = t[6]
		if t[7] >= 0.0:
			d.metallic = t[7]
		if t[1] == "tr_silk_bow":
			d.color_b = Color(0.98, 0.9, 0.7)
		var err := ResourceSaver.save(d, "res://data/treasures/%s.tres" % d.id)
		if err != OK:
			push_error("No se pudo guardar el tesoro %s" % d.id)
		if not by_room.has(t[0]):
			by_room[t[0]] = []
		by_room[t[0]].append(d)
	for room_id in by_room:
		var cat := ItemCatalog.new()
		var list: Array[ItemData] = []
		for d in by_room[room_id]:
			list.append(d)
		cat.items = list
		ResourceSaver.save(cat, "res://data/treasures/catalog_%s.tres" % room_id)
		print("  tesoros %s: %d" % [room_id, list.size()])

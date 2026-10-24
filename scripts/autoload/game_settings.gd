extends Node
## Configuración del jugador. Se guarda en user://settings.cfg.
## Tolerante a ficheros corruptos o incompletos: usa valores por defecto.

signal changed

const PATH := "user://settings.cfg"
const TEST_PATH := "user://settings_test.cfg"

var mouse_sensitivity := 1.0
var master_volume := 0.8
var sfx_volume := 1.0
var music_volume := 0.5
var fullscreen := false
var vsync := true
var msaa := true
## Iluminación avanzada: luz rebotada (SDFGI), oclusión ambiental, niebla volumétrica y brillo.
## Desactivada = modo para equipos modestos.
var high_quality := true
var tutorial_done := false
## Accesibilidad: tamaño de toda la interfaz (textos incluidos), de 1.0 a 1.5.
var text_scale := 1.0
## Colores para daltonismo: la mira y el objeto fantasma usan azul (cabe) y naranja (no cabe) en vez
## de verde y rojo. La forma también cambia siempre (una X cuando no cabe), así no depende solo del color.
var colorblind := false
## Idioma de todos los textos (interfaz, carteles de la tienda y nombres de los objetos): "es" o "en".
## Los textos del juego están escritos en español y son la clave de las traducciones (data/i18n/*.csv).
var language := "es"
const LANGUAGES := ["es", "en"]

## Las pruebas automáticas (--test-mode) usan otro fichero para no tocar tu configuración.
var _path := PATH


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--test-mode"):
		_path = TEST_PATH
	# Sin ajustes guardados: el idioma del sistema (español, o inglés para cualquier otro).
	language = "es" if OS.get_locale_language() == "es" else "en"
	load_settings()
	# Las pruebas comprueban los textos en español (salvo que se pida otro con --lang=).
	if _path == TEST_PATH:
		language = "es"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			language = arg.trim_prefix("--lang=")
	apply_language()
	apply_display()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(_path) != OK:
		return
	mouse_sensitivity = clampf(float(cf.get_value("controls", "mouse_sensitivity", 1.0)), 0.2, 3.0)
	master_volume = clampf(float(cf.get_value("audio", "master", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", 0.5)), 0.0, 1.0)
	fullscreen = bool(cf.get_value("graphics", "fullscreen", false))
	vsync = bool(cf.get_value("graphics", "vsync", true))
	msaa = bool(cf.get_value("graphics", "msaa", true))
	high_quality = bool(cf.get_value("graphics", "high_quality", true))
	tutorial_done = bool(cf.get_value("progress", "tutorial_done", false))
	text_scale = clampf(float(cf.get_value("accessibility", "text_scale", 1.0)), 1.0, 1.5)
	colorblind = bool(cf.get_value("accessibility", "colorblind", false))
	var lang := str(cf.get_value("general", "language", language))
	if lang in LANGUAGES:
		language = lang


## Cerrar la ventana con Alt+F4 o la X tambien guarda los ajustes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("graphics", "fullscreen", fullscreen)
	cf.set_value("graphics", "vsync", vsync)
	cf.set_value("graphics", "msaa", msaa)
	cf.set_value("graphics", "high_quality", high_quality)
	cf.set_value("progress", "tutorial_done", tutorial_done)
	cf.set_value("accessibility", "text_scale", text_scale)
	cf.set_value("accessibility", "colorblind", colorblind)
	cf.set_value("general", "language", language)
	var err := cf.save(_path)
	if err != OK:
		push_warning("No se pudo guardar la configuración (%s)" % error_string(err))


func apply_display() -> void:
	# La interfaz se dibuja sobre una vista base de 1920×1080 que se estira: el factor la agranda entera.
	get_tree().root.content_scale_factor = text_scale
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	var use_vsync := vsync and not OS.get_cmdline_user_args().has("--no-vsync")
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if use_vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().msaa_3d = Viewport.MSAA_4X if msaa else Viewport.MSAA_DISABLED


## Color de "cabe aquí" y de "aquí no" (mira, objeto fantasma y textos del indicador).
func aim_ok_color() -> Color:
	return Color(0.48, 0.78, 1.0) if colorblind else Color(0.72, 1.0, 0.78)


func aim_deny_color() -> Color:
	return Color(1.0, 0.64, 0.16) if colorblind else Color(1.0, 0.50, 0.45)


## Cambia el idioma de todo el juego. Los textos que se escriben solos (Label, Button, Label3D con el
## texto tal cual) se traducen al momento; los que se componen por código escuchan NOTIFICATION_TRANSLATION_CHANGED.
func apply_language() -> void:
	if not language in LANGUAGES:
		language = "es"
	TranslationServer.set_locale(language)


## El siguiente idioma de la lista (botón del menú).
func cycle_language() -> void:
	language = LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()]
	apply_language()
	changed.emit()


## Llamar tras modificar cualquier valor desde la interfaz.
func notify_changed() -> void:
	apply_display()
	changed.emit()

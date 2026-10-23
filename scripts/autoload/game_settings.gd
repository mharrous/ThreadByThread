extends Node
## Configuración del jugador. Se guarda en user://settings.cfg.
## Tolerante a ficheros corruptos o incompletos: usa valores por defecto.

signal changed

const PATH := "user://settings.cfg"
const TEST_PATH := "user://settings_test.cfg"

var mouse_sensitivity := 1.0
var master_volume := 0.8
var sfx_volume := 1.0
var fullscreen := false
var vsync := true
var msaa := true
## Iluminación avanzada: luz rebotada (SDFGI), oclusión ambiental, niebla volumétrica y brillo.
## Desactivada = modo para equipos modestos.
var high_quality := true
var tutorial_done := false

## Las pruebas automáticas (--test-mode) usan otro fichero para no tocar tu configuración.
var _path := PATH


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--test-mode"):
		_path = TEST_PATH
	load_settings()
	apply_display()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(_path) != OK:
		return
	mouse_sensitivity = clampf(float(cf.get_value("controls", "mouse_sensitivity", 1.0)), 0.2, 3.0)
	master_volume = clampf(float(cf.get_value("audio", "master", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	fullscreen = bool(cf.get_value("graphics", "fullscreen", false))
	vsync = bool(cf.get_value("graphics", "vsync", true))
	msaa = bool(cf.get_value("graphics", "msaa", true))
	high_quality = bool(cf.get_value("graphics", "high_quality", true))
	tutorial_done = bool(cf.get_value("progress", "tutorial_done", false))


## Cerrar la ventana con Alt+F4 o la X tambien guarda los ajustes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("graphics", "fullscreen", fullscreen)
	cf.set_value("graphics", "vsync", vsync)
	cf.set_value("graphics", "msaa", msaa)
	cf.set_value("graphics", "high_quality", high_quality)
	cf.set_value("progress", "tutorial_done", tutorial_done)
	var err := cf.save(_path)
	if err != OK:
		push_warning("No se pudo guardar la configuración (%s)" % error_string(err))


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	var use_vsync := vsync and not OS.get_cmdline_user_args().has("--no-vsync")
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if use_vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().msaa_3d = Viewport.MSAA_4X if msaa else Viewport.MSAA_DISABLED


## Llamar tras modificar cualquier valor desde la interfaz.
func notify_changed() -> void:
	apply_display()
	changed.emit()

extends Node
## Guardado de partida en JSON, resistente a errores: se escribe a un fichero temporal
## y se renombra (nunca queda un fichero a medias), se conserva una copia .bak del guardado
## anterior y, si el principal está corrupto, se recupera la copia.
## En pruebas automáticas (--test-mode) usa otros ficheros y empieza sin partida.

const VERSION := 1
const PATH := "user://savegame.json"
const TEST_PATH := "user://savegame_test.json"

var _path := PATH


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--test-mode"):
		_path = TEST_PATH
		if not args.has("--keep-save"):
			delete_save()


func has_save() -> bool:
	return FileAccess.file_exists(_path) or FileAccess.file_exists(_path + ".bak")


func delete_save() -> void:
	for p in [_path, _path + ".bak", _path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Guarda `data` (se le añaden versión y fecha). Devuelve true si se escribió bien.
func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	var text := JSON.stringify(data)
	var tmp := _path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo abrir %s para guardar (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	# Comprueba que lo escrito se puede leer antes de reemplazar el guardado bueno.
	if _parse(tmp).is_empty():
		push_warning("El guardado temporal no es válido; se conserva el anterior")
		return false
	var abs_path := ProjectSettings.globalize_path(_path)
	var abs_bak := ProjectSettings.globalize_path(_path + ".bak")
	if FileAccess.file_exists(_path):
		if FileAccess.file_exists(_path + ".bak"):
			DirAccess.remove_absolute(abs_bak)
		DirAccess.rename_absolute(abs_path, abs_bak)
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	if err != OK:
		push_warning("No se pudo completar el guardado (%s)" % error_string(err))
		return false
	return true


## Lee la partida. Devuelve {} si no hay o no es válida (prueba también la copia .bak).
func read() -> Dictionary:
	for p in [_path, _path + ".bak"]:
		var d := _parse(p)
		if not d.is_empty() and int(d.get("version", 0)) == VERSION:
			return d
	return {}


func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}

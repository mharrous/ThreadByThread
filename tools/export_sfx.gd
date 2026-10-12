extends SceneTree
## Saca todos los sonidos sintetizados a WAV (art/audio/raw/) para editarlos en Audacity.
##   godot --headless --path . --script res://tools/export_sfx.gd
## Flujo: abre un WAV de art/audio/raw/, edítalo (reverb, ecualizador, recorte...) y expórtalo
## con el MISMO nombre a art/audio/sfx/ (WAV 16 bit, mono, 44100 Hz). El juego usará tu
## versión en lugar de la sintetizada. Borra el fichero de sfx/ para volver a la original.

const RAW_DIR := "res://art/audio/raw/"
const SFX_DIR := "res://art/audio/sfx/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RAW_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR))
	var banks := SfxSynth.build_banks()
	var count := 0
	for sound: StringName in banks.keys():
		var variants: Array = banks[sound]
		for i in variants.size():
			var path := ProjectSettings.globalize_path("%s%s_%d.wav" % [RAW_DIR, sound, i + 1])
			var err := (variants[i] as AudioStreamWAV).save_to_wav(path)
			if err != OK:
				push_error("No se pudo guardar %s (%s)" % [path, error_string(err)])
			count += 1
	print("Exportados %d sonidos a %s" % [count, RAW_DIR])
	quit()

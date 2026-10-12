extends Node
## Bus global de eventos. Desacopla jugabilidad, interfaz, audio y efectos.
## Quien produce un evento no sabe quién lo escucha.

@warning_ignore_start("unused_signal")

## Qué hay bajo la mirada. `info` vacío = nada que mostrar.
## Claves: key, action, title, detail, hint, kind ("pick", "place", "deny", "hold").
signal target_changed(info: Dictionary)
signal held_item_changed(item)

signal item_picked(item)
signal item_removed(item, shelf)
signal item_placed(item, shelf)
signal item_set_down(item)
signal item_rejected(item, reason: String)
signal item_thrown(item)
## Impacto de un objeto lanzado: velocidad de choque, punto de contacto y banco de sonido.
signal item_bounced(item, speed: float, position: Vector3, sound: StringName)
signal item_landed(item)
## Carga del lanzamiento, de 0 a 1.
signal throw_charge_changed(value: float)

## Progreso de la sala activa (la que muestra la interfaz).
signal progress_changed(placed: int, total: int)
## Progreso de cualquier sala (guardado, desbloqueos).
signal room_progress_changed(room, placed: int, total: int)
signal collection_completed(sort_key: StringName)
signal room_completed(room)
signal room_unlocked(room)
signal active_room_changed(room)
signal treasure_found(item)
signal game_saved

signal hint_requested(text: String)
signal pause_toggled(paused: bool)

@warning_ignore_restore("unused_signal")

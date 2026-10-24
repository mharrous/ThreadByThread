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

## Progreso de toda la mercería (lo que muestra la interfaz).
signal progress_changed(placed: int, total: int)
signal room_progress_changed(room, placed: int, total: int)
## Progreso de una sección (una familia de objetos con sus muebles).
signal section_progress_changed(section, placed: int, total: int)
signal collection_completed(sort_key: StringName)
## Racha de colocaciones seguidas (1 = la primera). La cuenta AudioManager, que la usa para afinar.
signal streak_changed(count: int)
signal section_completed(section)
## Toda la mercería ordenada (final de la demo).
signal room_completed(room)
signal active_room_changed(room)
signal treasure_found(item)
signal decor_unlocked(room, id: StringName)
## Escena de apertura de la tienda (al ordenarla entera): empieza y termina (pantalla final a la vista).
signal shop_opening_started
signal shop_opening_finished
signal game_saved
## Papelitos fuera del suelo (barridos) de los que había; y suelo limpio con el recogedor vacío.
signal floor_progress_changed(swept: int, total: int)
signal floor_cleaned
## Flecha del borde de la pantalla hacia algo que no es la estantería del objeto en la mano
## (con la escoba: el papelito más cercano o la papelera). `active` false la apaga.
signal guide_target_changed(active: bool, position: Vector3)
## Caricia al gato de la tienda.
signal cat_petted

signal hint_requested(text: String)
signal pause_toggled(paused: bool)

@warning_ignore_restore("unused_signal")

extends Node
## Pantalla final con clics de verdad (lo que hace el jugador), con main.tscn como escena actual:
##   título → Jugar · apertura · clic en "Seguir explorando" (vuelve a la tienda abierta y libre) ·
##   apertura otra vez · clic en "Menú principal" (recarga limpia, sale el título y no quedan nodos sueltos).
## Uso: powershell -File tests\run_end_screen.ps1   (código de salida 0 = todo correcto)
## Este nodo cuelga de la raíz (no es la escena actual): sigue vivo cuando la escena se recarga.

const MAIN := "res://scenes/main.tscn"

static var _launched := false
var _failures := 0


func _ready() -> void:
	if not _launched:
		_launched = true
		var probe: Node = (get_script() as Script).new()
		probe.name = "EndScreenProbe"
		probe.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(probe)
		get_tree().change_scene_to_file.call_deferred(MAIN)
		return
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  OK    ", msg)
	else:
		_failures += 1
		print("  FALLO ", msg)


## Espera en tiempo real (no le afecta Engine.time_scale).
func _wait_until(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Clic izquierdo (pulsar y soltar) en el centro del botón, por la misma vía que el ratón.
func _click(b: Button) -> void:
	var at := b.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
		await get_tree().process_frame


func _opening() -> ShopOpening:
	var main := get_tree().current_scene
	return main.get_node_or_null("ShopOpening") as ShopOpening if main != null else null


func _play_until_end_screen() -> bool:
	var opening := _opening()
	opening.play()
	if not await _wait_until(func(): return opening.is_end_screen_open(), 90.0):
		return false
	# Los botones aparecen con un fundido.
	await _wait_until(func(): return opening._end._content.modulate.a > 0.99, 10.0)
	return true


func _press_play(title: Node) -> void:
	await _wait_until(func(): return title._card.modulate.a > 0.99, 5.0)
	var gone := _freed(title)
	await _click(title._play_btn)
	await _wait_until(gone, 5.0)


func _run() -> void:
	print("== Pantalla final: botones ==")
	await _wait_until(func(): return _opening() != null, 10.0)
	var main := get_tree().current_scene
	await _frames(10)
	var title := main.get_node_or_null("TitleScreen")
	_check(title != null and get_tree().paused, "al empezar sale el título y el juego está en pausa")
	if title != null:
		await _press_play(title)
	_check(not get_tree().paused, "clic en Jugar: se quita la pausa")
	Engine.time_scale = 3.0

	var shop := main.get_node("Shop") as Shop
	var player := main.get_node("Player") as Player
	var hud := main.get_node("HUD")
	# La tienda abre con todo colocado y el suelo barrido.
	shop.floor_sweep().finish_instantly()
	shop.room.solve_instantly()
	await _wait_until(func(): return _opening().playing, 15.0)
	_check(await _play_until_end_screen(), "la apertura llega a la pantalla final")
	var opening := _opening()
	var end: Node = opening._end
	_check(end.is_in_group(&"modal_ui"), "la pantalla final está en el grupo modal_ui")

	# --- Seguir explorando
	var end_gone := _freed(end)
	await _click(end._buttons[0])
	_check(await _wait_until(end_gone, 6.0), "clic en «Seguir explorando»: la pantalla final se cierra")
	_check(not player.input_locked, "el jugador vuelve a moverse")
	_check(not opening.playing, "la escena de apertura ha terminado")
	await _wait_until(func(): return not hud.is_cinematic(), 4.0)
	_check(not hud.is_cinematic(), "vuelve la interfaz de juego")
	_check(shop.room.shell.is_shop_open() and shop.room.shell.door_sign.text == "ABIERTO", "la tienda sigue abierta e iluminada")
	_check(not get_tree().paused, "el juego no queda en pausa")

	# --- Menú principal (la apertura se puede repetir a mano, como con la tecla T)
	_check(await _play_until_end_screen(), "la apertura llega otra vez a la pantalla final")
	end = _opening()._end
	# La condición se prepara antes del clic: la recarga puede liberar la escena mientras se hace.
	var old_gone := _freed(main)
	await _click(end._buttons[1])
	_check(await _wait_until(old_gone, 6.0), "clic en «Menú principal»: la escena anterior se libera entera")
	Engine.time_scale = 1.0
	await _wait_until(func(): return get_tree().current_scene != null, 5.0)
	await _frames(10)
	main = get_tree().current_scene
	_check(main != null and main.scene_file_path == MAIN, "se carga la tienda de nuevo")
	title = main.get_node_or_null("TitleScreen") if main != null else null
	_check(title != null and title.visible, "sale la pantalla de título")
	_check(get_tree().paused, "el juego está en pausa bajo el título")
	_check(get_tree().get_nodes_in_group(&"modal_ui").is_empty(), "no queda ninguna pantalla final")
	var shop2 := main.get_node("Shop") as Shop
	_check(shop2.shop_opened and shop2.room.shell.is_shop_open(), "la partida cargada recuerda la tienda abierta")
	var sweep := shop2.room.shell.get_node_or_null("ShopSweep") as ShopSweep
	_check(sweep != null and sweep.is_clean() and sweep.broom.visible, "suelo barrido y la escoba en su rincón al cargar")
	_check(get_tree().root.get_child_count() == _expected_root_children(), "en la raíz solo quedan los autoloads, la prueba y la escena")
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(orphans == 0, "sin nodos huérfanos tras la recarga (%d)" % orphans)
	if title != null:
		await _press_play(title)
	_check(not get_tree().paused, "clic en Continuar: vuelta al juego")
	await _frames(60)
	_check(not _opening().playing, "con la tienda ya abierta la apertura no se repite")

	SaveGame.delete_save()
	print("RESULTADO: ", "TODO CORRECTO" if _failures == 0 else "%d FALLOS" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _expected_root_children() -> int:
	var n := 2  # esta prueba y la escena actual
	for prop in ProjectSettings.get_property_list():
		if String(prop.name).begins_with("autoload/"):
			n += 1
	return n


## Condición "ya se ha liberado" sin capturar el objeto (una lambda que lo captura avisa al liberarse).
func _freed(obj: Object) -> Callable:
	var ref: WeakRef = weakref(obj)
	return func(): return ref.get_ref() == null

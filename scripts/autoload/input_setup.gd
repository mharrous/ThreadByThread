extends Node
## Registra las acciones de entrada por código. Usa teclas físicas (independiente
## de la distribución del teclado). Punto único para añadir rebinding más adelante.

const KEY_BINDINGS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"sprint": [KEY_SHIFT],
	&"crouch": [KEY_CTRL],
	&"interact": [KEY_E],
	&"set_down": [KEY_Q],
	&"rotate_item": [KEY_R],
	&"pause": [KEY_ESCAPE],
}

const MOUSE_BINDINGS := {
	&"place": [MOUSE_BUTTON_LEFT],
	&"set_down": [MOUSE_BUTTON_RIGHT],
}


func _enter_tree() -> void:
	for action: StringName in KEY_BINDINGS:
		_ensure_action(action)
		for keycode: Key in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
	for action: StringName in MOUSE_BINDINGS:
		_ensure_action(action)
		for button: MouseButton in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)

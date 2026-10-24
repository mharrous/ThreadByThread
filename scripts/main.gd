extends Node3D
## Escena principal: captura el ratón al empezar y lo recupera con un clic
## si se perdió (por ejemplo al volver de otra ventana). Ese clic se consume
## en `_input`, antes de que lo vea la lógica de juego. Con una pantalla con botones abierta
## (grupo `modal_ui`, p. ej. la pantalla final) el clic es para sus botones y no se toca.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or get_tree().paused:
		return
	if get_tree().get_first_node_in_group(&"modal_ui") == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

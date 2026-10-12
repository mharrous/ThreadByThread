extends Node3D
## Escena principal: captura el ratón al empezar y lo recupera con un clic
## si se perdió (por ejemplo al volver de otra ventana). Ese clic se consume
## en `_input`, antes de que lo vea la lógica de juego.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

extends Node3D

@export var angulo_inicial_y: float = -175.0  # Frente del carro con vista 3/4 de medio lado hacia la cámara
@export var velocidad_giro_max: float = 2.2   # Radianes por segundo al mantener presionado
@export var suavizado_giro: float = 8.0       # Qué tan rápido acelera y frena el giro
@export var sentido_horario: float = -1.0     # -1.0 o 1.0 según hacia dónde quieras que gire

@onready var area_carro: Area3D = get_node_or_null("Area3D")

var _presionando_carro: bool = false
var _velocidad_actual: float = 0.0

func _ready() -> void:
	# Ángulo inicial: frente del carro hacia la cámara en 3/4 (~ -152° / 208°)
	rotation_degrees.y = angulo_inicial_y
	if area_carro:
		area_carro.input_ray_pickable = true
		area_carro.input_event.connect(_on_area_3d_input_event)
		area_carro.mouse_entered.connect(_on_area_mouse_entered)
		area_carro.mouse_exited.connect(_on_area_mouse_exited)

func _on_area_mouse_entered() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_area_mouse_exited() -> void:
	if not _presionando_carro:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_area_3d_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_presionando_carro = true

func _unhandled_input(event: InputEvent) -> void:
	# Se detecta aquí para soltar el giro incluso si el mouse sale del carro mientras se mantiene clic
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_presionando_carro = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif event is InputEventMouseMotion and _presionando_carro:
		# Arrastre interactivo con el ratón hacia izquierda o derecha
		if absf(event.relative.x) > 0.8:
			rotate_y(event.relative.x * 0.007)
			_velocidad_actual = clampf(event.relative.x * 0.2, -velocidad_giro_max * 1.5, velocidad_giro_max * 1.5)

func _process(delta: float) -> void:
	var velocidad_objetivo: float = 0.0
	if _presionando_carro:
		velocidad_objetivo = velocidad_giro_max * sentido_horario

	# Interpolación suave tanto al arrancar como al soltar el clic
	var factor: float = 1.0 - exp(-suavizado_giro * delta)
	_velocidad_actual = lerpf(_velocidad_actual, velocidad_objetivo, factor)
	rotate_y(_velocidad_actual * delta)

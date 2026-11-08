class_name SistemaEventos
extends Node

@export var luz_evento: OmniLight3D
@export var pico_destello := 4.0
@export var k_destello := 7.5 # 1/s: a los 0.4 s queda 4 × e^(-3) = 0.2 (el 5 % del pico)

# --- Variables y propiedades para el Nivel 3 (Luz que sigue una variable) ---
@export var color_bajo := Color(0.0, 0.9, 1.0) # Azul neón
@export var color_alto := Color(1.0, 0.3, 0.1) # Naranja/Rojo de nitro o alerta
@export var k_variable := 4.0
var variable := 0.0 # De 0 a 1: estado del nitro o prueba con teclas

func _ready() -> void:
	for d in get_tree().get_nodes_in_group("disparadores"):
		d.evento.connect(_on_evento)
	if luz_evento != null:
		luz_evento.light_energy = 0.0

func _process(delta: float) -> void:
	# 1. Manejo del destello de eventos (Lógica existente)
	if luz_evento != null:
		luz_evento.light_energy = decaer(luz_evento.light_energy, 0.0, k_destello, delta)
	
	# 2. Manejo de la luz del nitro usando las acciones del Input Map (W / S / Flechas)
	var luz_nitro = get_node_or_null("../Personaje/LuzNitro")
	if luz_nitro != null:
		if Input.is_action_pressed("move_up"):
			variable = minf(1.0, variable + delta * 0.5)
		elif Input.is_action_pressed("move_down"):
			variable = maxf(0.0, variable - delta * 0.5)
			
		# Interpolación de color según la variable
		luz_nitro.light_color = color_bajo.lerp(color_alto, clampf(variable, 0.0, 1.0))
		
		# Energía deseada y persecución suave usando la función decaer
		var energia_deseada := 1.0 + 3.0 * variable
		luz_nitro.light_energy = decaer(luz_nitro.light_energy, energia_deseada, k_variable, delta)

func _on_evento(posicion: Vector3) -> void:
	if luz_evento != null:
		luz_evento.global_position = posicion + Vector3.UP * 1.5
		luz_evento.light_energy = pico_destello

static func decaer(actual: float, base: float, k: float, dt: float) -> float:
	var alpha := 1.0 - exp(-k * dt)
	return actual + (base - actual) * alpha

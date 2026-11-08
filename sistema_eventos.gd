class_name SistemaEventos
extends Node

@export var luz_evento: OmniLight3D
@export var pico_destello := 4.0
@export var k_destello := 7.5 # 1/s: a los 0.4 s queda 4 × e^(-3) = 0.2 (el 5 % del pico)

func _ready() -> void:
	for d in get_tree().get_nodes_in_group("disparadores"):
		d.evento.connect(_on_evento)
	if luz_evento != null:
		luz_evento.light_energy = 0.0

func _process(delta: float) -> void:
	if luz_evento == null:
		return
	luz_evento.light_energy = decaer(luz_evento.light_energy, 0.0, k_destello, delta)

func _on_evento(posicion: Vector3) -> void:
	if luz_evento != null:
		luz_evento.global_position = posicion + Vector3.UP * 1.5
		luz_evento.light_energy = pico_destello

static func decaer(actual: float, base: float, k: float, dt: float) -> float:
	var alpha := 1.0 - exp(-k * dt)
	return actual + (base - actual) * alpha

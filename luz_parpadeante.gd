class_name LuzParpadeante
extends OmniLight3D

@export var energia_base := 2.0
@export var amplitud := 0.3
@export var velocidad := 4.0
@export var semilla := 7

var ruido := FastNoiseLite.new()
var t := 0.0

func _ready() -> void:
	ruido.seed = semilla
	ruido.frequency = 1.0

func _process(delta: float) -> void:
	t += delta
	light_energy = energia(energia_base, amplitud, ruido.get_noise_1d(t * velocidad))

static func energia(base: float, amp: float, valor_ruido: float) -> float:
	return maxf(0.0, base * (1.0 + amp * valor_ruido))

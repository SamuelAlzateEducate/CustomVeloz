class_name Nitro
extends Node

# Sistema de Nitro / Turbo de CustomVeloz:
#  - velocidad: 120 km/h (33.33 m/s) en vez de 90 km/h (25 m/s) -> +30 km/h (+33 %).
#    Esa cifra vive en personaje.gd (speed_correr); aquí no se repite.
#  - duración: 2.5 s con la carga llena
#  - recarga: de 0 a 1 tarda 5 s
#  - luz: SpotLight3D rojo fuego (#FF2600) que ilumina potentemente el asfalto detrás del carro
@export var luz: SpotLight3D
@export var duracion := 2.5 # s para gastar la carga completa
@export var recarga := 5.0 # s para recuperar la carga completa
@export var carga_minima := 0.20 # tras vaciarse, no se puede usar hasta recuperar esto
@export var energia_luz := 16.0 # Energía potente para que el óvalo rojo brille en el asfalto oscuro
@export var k_luz := 12.0

var carga := 1.0 # 0 a 1 (la barra de nitro de la UI)
var activo := false
var bloqueado := false
var _reloj_turbo := 0.0

@onready var pj := get_parent()

func _ready() -> void:
	if luz:
		# Apunta hacia atrás (+Z local) e inclinada al suelo (-28°) para proyectar
		# el óvalo rojo nítido y brillante justo detrás del carro como en zona_b
		luz.rotation_degrees = Vector3(-28.0, 180.0, 0.0)
		luz.spot_range = 12.0
		luz.spot_angle = 38.0
		luz.spot_attenuation = 1.2

func _physics_process(delta: float) -> void:
	activo = Input.is_action_pressed("correr") and carga > 0.0 and not bloqueado
	if activo:
		carga = maxf(0.0, carga - delta / duracion)
		if carga <= 0.0:
			bloqueado = true
	else:
		carga = minf(1.0, carga + delta / recarga)
		if bloqueado and carga >= carga_minima:
			bloqueado = false
	
	# personaje.gd solo usa speed_correr mientras haya nitro
	pj.nitro_ok = carga > 0.0 and not bloqueado
	
	# Animación y color del turbo: al presionar Shift proyecta la luz roja/coral
	# brillante con una sutil pulsación de combustión ("llama de nitro")
	if luz:
		var alpha := 1.0 - exp(-k_luz * delta)
		if activo:
			_reloj_turbo += delta
			var pulso := 1.0 + 0.12 * sin(_reloj_turbo * 32.0)
			luz.light_color = Color(1.0, 0.22, 0.10)
			luz.light_energy = lerpf(luz.light_energy, energia_luz * pulso, alpha)

func recargar_nitro(cantidad: float = 1.0) -> void:
	carga = minf(1.0, carga + cantidad)
	bloqueado = false

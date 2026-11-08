class_name Nitro
extends Node

# Decisión de diseño del nitro (vacío de los Talleres 4 y 7):
#  - velocidad: 120 km/h (33.33 m/s) en vez de 90 km/h (25 m/s) -> +30 km/h (+33 %).
#    Esa cifra vive en personaje.gd (speed_correr); aquí no se repite.
#  - duración: 2 s con la carga llena
#  - recarga: de 0 a 1 tarda 6 s
#  - luz: SpotLight3D amarillo (#FFEA00) detrás del carro
@export var luz: SpotLight3D
@export var duracion := 2.0 # s para gastar la carga completa
@export var recarga := 6.0 # s para recuperar la carga completa
@export var carga_minima := 0.25 # tras vaciarse, no se puede usar hasta recuperar esto
@export var energia_luz := 6.0
@export var k_luz := 10.0

var carga := 1.0 # 0 a 1 (la barra de nitro de la UI)
var activo := false
var bloqueado := false

@onready var pj := get_parent()

func _ready() -> void:
	if luz:
		# apunta hacia atrás (+Z local, hacia la cámara) y un poco hacia el piso
		luz.rotation_degrees = Vector3(-20.0, 180.0, 0.0)
		luz.light_energy = 0.0

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
	if luz:
		var objetivo := energia_luz if activo else 0.0
		var alpha := 1.0 - exp(-k_luz * delta)
		luz.light_energy = luz.light_energy + (objetivo - luz.light_energy) * alpha

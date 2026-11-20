class_name Nitro
extends Node

# Sistema de Nitro / Turbo de CustomVeloz:
#  - velocidad: 120 km/h (33.33 m/s) en vez de 90 km/h (25 m/s) -> +30 km/h (+33 %).
#  - duración: 2.5 s con la carga llena
#  - recarga: de 0 a 1 tarda 5 s
#  - La luz (azul neón -> rojo fuego) la controla sistema_eventos.gd exactamente igual que en zona_b.
@export var luz: SpotLight3D
@export var duracion := 2.5 # s para gastar la carga completa
@export var recarga := 5.0 # s para recuperar la carga completa
@export var carga_minima := 0.20 # tras vaciarse, no se puede usar hasta recuperar esto

var carga := 1.0 # 0 a 1 (la barra de nitro de la UI)
var activo := false
var bloqueado := false

@onready var pj := get_parent()

func _ready() -> void:
	if luz:
		# Configuración exacta original de zona_b (Taller 4 / Taller 8):
		# apunta hacia atrás (+Z local) y un poco hacia el piso
		luz.rotation_degrees = Vector3(-20.0, 180.0, 0.0)
		luz.spot_range = 10.0
		luz.spot_angle = 35.0

func _physics_process(delta: float) -> void:
	var tecla_shift := Input.is_action_pressed("correr") or Input.is_key_pressed(KEY_SHIFT)
	activo = tecla_shift and carga > 0.0 and not bloqueado
	if activo:
		carga = maxf(0.0, carga - delta / duracion)
		if carga <= 0.0:
			bloqueado = true
	else:
		carga = minf(1.0, carga + delta / recarga)
		if bloqueado and carga >= carga_minima:
			bloqueado = false
	
	# personaje.gd usa speed_correr mientras haya nitro
	pj.nitro_ok = carga > 0.0 and not bloqueado

func recargar_nitro(cantidad: float = 1.0) -> void:
	carga = minf(1.0, carga + cantidad)
	bloqueado = false

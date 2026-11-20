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
@export var energia_luz := 8.0
@export var k_luz := 10.0

var carga := 1.0 # 0 a 1 (la barra de nitro de la UI)
var activo := false
var bloqueado := false

@onready var pj := get_parent()

func _ready() -> void:
	if luz:
		# apunta hacia atrás (+Z local, hacia la cámara) e ilumina el suelo
		luz.rotation_degrees = Vector3(-20.0, 180.0, 0.0)
		# NO forzar light_energy a 0: sistema_eventos.gd controla el brillo base
		# con la progresión cyan→rojo al acelerar (W). Solo ajustamos rango/angulo.
		luz.spot_range = 16.0
		luz.spot_angle = 50.0

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
	
	# La luz base (cyan→rojo progresivo al acelerar) la controla sistema_eventos.gd.
	# Aquí solo sumamos el extra de energía cuando Shift está presionado.
	if luz:
		var alpha := 1.0 - exp(-k_luz * delta)
		if activo:
			# Al presionar Shift: color rojo intenso y energía máxima del turbo
			luz.light_color = Color(1.0, 0.15, 0.02)
			luz.light_energy = lerpf(luz.light_energy, energia_luz, alpha)

func recargar_nitro(cantidad: float = 1.0) -> void:
	carga = minf(1.0, carga + cantidad)
	bloqueado = false

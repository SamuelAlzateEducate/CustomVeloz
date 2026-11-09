class_name LuzJugador
extends SpotLight3D

# Tarea C - La luz que acompaña al jugador (CustomVeloz).
# Los faros del carro: dos SpotLight3D hacia adelante, 8 m de alcance.
# Cada faro es una instancia de este script; "lado" dice cuál es (-1 izquierdo, +1 derecho).

@export var rango := 8.0 # m: hasta dónde alumbra
@export var altura := 0.65 # m sobre los pies del jugador
@export var lado := 1.0 # -1 = faro izquierdo, +1 = faro derecho
@export var separacion := 0.7 # m del centro del carro a cada faro
@export var adelante := 2.0 # m por delante del centro (así la luz sale fuera del cuerpo)
@export var inclinacion := 6.0 # grados hacia el piso (0 = horizontal)
@export var probar_funciones := true # imprime las pruebas numéricas al empezar (solo el faro izquierdo)

func _ready() -> void:
	position = Vector3(lado * separacion, altura, -adelante)
	rotation_degrees = Vector3(-inclinacion, 0.0, 0.0)
	spot_range = rango
	spot_attenuation = 2.0 # la que se parece a 1/d²
	if probar_funciones and lado < 0.0:
		print("[luz_jugador] atenuacion 1, 2, 4 m: ", atenuacion(1.0), " ", atenuacion(2.0), " ", atenuacion(4.0))
		# Nivel 3: pruebas de Blinn-Phong con los numeros de la guia (n = arriba, l = (0,1,1))
		var n := Vector3(0, 1, 0)
		var l := Vector3(0, 1, 1)
		print("[luz_jugador] blinn_phong v=(0,1,-1) brillo 32: ", blinn_phong(n, l, Vector3(0, 1, -1), 32.0))
		print("[luz_jugador] blinn_phong v=(0,1,0)  brillo 32: ", blinn_phong(n, l, Vector3(0, 1, 0), 32.0))

# Cuánta luz llega a la distancia d, si a 1 m llega "1". Con exponente 2 es 1/d².
static func atenuacion(d: float, exponente: float = 2.0) -> float:
	return 1.0 / pow(maxf(d, 0.0001), exponente)

# Nivel 3: brillo de una superficie lisa (Blinn-Phong) = max(0, n · h) ^ brillo,
# con h = el vector medio entre "hacia la luz" y "hacia el ojo".
static func blinn_phong(normal: Vector3, hacia_luz: Vector3, hacia_ojo: Vector3, brillo: float) -> float:
	var n := normal.normalized()
	var l := hacia_luz.normalized()
	var v := hacia_ojo.normalized()
	var h := (l + v).normalized()
	return pow(maxf(0.0, n.dot(h)), brillo)

extends CharacterBody3D

enum Estado { CORRER, ATACAR, LENTO }

@export var velocidad_maxima = 12.0
@export var aceleracion = 5.0
@export var velocidad_giro = 2.0
@export var distancia_llegada = 5.0
@export var ruta: Array[Vector3] = [
	Vector3(10, 0, 0), Vector3(10, 0, -12), Vector3(-10, 0, -12),
	Vector3(-10, 0, 0)
]

@export var radio_onda = 5.0
@export var recarga_onda = 5.0
@export var castigo = 2.78
@export var tiempo_lento = 3.0

var estado = Estado.CORRER
var velocidad_actual = 0.0
var indice = 0
var vueltas = 0

var reloj_onda = 0.0
var reloj_lento = 0.0
var jugador: Node3D = null

func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")

func _physics_process(delta):
	reloj_onda = maxf(reloj_onda - delta, 0.0)
	reloj_lento = maxf(reloj_lento - delta, 0.0)
	
	var nuevo = decidir()
	if nuevo != estado:
		estado = nuevo
		print(name, " -> ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames())
	
	var tope = velocidad_maxima
	match estado:
		Estado.ATACAR:
			if jugador:
				var d = plana(global_position, jugador.global_position)
				print(name, " lanza la onda a ", snappedf(d, 0.01), " m")
			reloj_onda = recarga_onda
		Estado.LENTO:
			tope = velocidad_maxima - castigo
	
	var destino = ruta[indice]
	if plana(global_position, destino) < distancia_llegada:
		indice = (indice + 1) % ruta.size()
		print(name, " va al punto ", indice, " cuadro ", Engine.get_physics_frames())
		if indice == 0:
			vueltas += 1
			print(name, " vuelta ", vueltas)
		destino = ruta[indice]
	
	var hacia = destino - global_position
	hacia.y = 0.0
	var local = transform.basis.inverse() * hacia
	var volante = clampf(-local.x, -1.0, 1.0)
	
	velocidad_actual = move_toward(velocidad_actual, tope, aceleracion * delta)
	var proporcion = velocidad_actual / velocidad_maxima if velocidad_maxima > 0.0 else 0.0
	rotate_y(volante * velocidad_giro * proporcion * delta)
	velocity += get_gravity() * delta
	var adelante = -transform.basis.z * velocidad_actual
	velocity.x = adelante.x
	velocity.z = adelante.z
	move_and_slide()

func decidir():
	if reloj_lento > 0.0:
		return Estado.LENTO
	if jugador:
		var d = plana(global_position, jugador.global_position)
		if d <= radio_onda and reloj_onda <= 0.0:
			return Estado.ATACAR
	return Estado.CORRER

func recibir_impacto():
	reloj_lento = tiempo_lento
	print(name, " recibe un impacto")

func plana(a, b):
	return Vector2(a.x - b.x, a.z - b.z).length()

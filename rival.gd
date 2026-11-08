extends CharacterBody3D

@export var velocidad_maxima = 12.0
@export var aceleracion = 5.0
@export var velocidad_giro = 2.0
@export var distancia_llegada = 5.0
@export var ruta: Array[Vector3] = [
	Vector3(10, 0, 0), Vector3(10, 0, -12), Vector3(-10, 0, -12),
	Vector3(-10, 0, 0)
]

var velocidad_actual = 0.0
var indice = 0
var vueltas = 0

func _physics_process(delta):
	var destino = ruta[indice]
	if plana(global_position, destino) < distancia_llegada:
		indice = (indice + 1) % ruta.size()
		print(name, " va al punto ", indice, " cuadro ", Engine.get_physics_frames())
		if indice == 0:
			vueltas += 1
			print(name, " vuelta ", vueltas)
		destino = ruta[indice]
	
	# La flecha, vista DESDE el carro: x positivo = está a su derecha.
	var hacia = destino - global_position
	hacia.y = 0.0
	var local = transform.basis.inverse() * hacia
	var volante = clampf(-local.x, -1.0, 1.0)
	
	# De aquí abajo, igual que el kart del jugador.
	velocidad_actual = move_toward(velocidad_actual, velocidad_maxima, aceleracion * delta)
	var proporcion = velocidad_actual / velocidad_maxima if velocidad_maxima > 0.0 else 0.0
	rotate_y(volante * velocidad_giro * proporcion * delta)
	velocity += get_gravity() * delta
	var adelante = -transform.basis.z * velocidad_actual
	velocity.x = adelante.x
	velocity.z = adelante.z
	move_and_slide()

func plana(a, b):
	return Vector2(a.x - b.x, a.z - b.z).length()

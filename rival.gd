extends CharacterBody3D

@export var rapidez = 8.0
@export var distancia_llegada = 3.0

# Posiciones absolutas: la ruta es del mundo, no de este NPC.
@export var ruta: Array[Vector3] = [
	Vector3(12, 0, 0), Vector3(12, 0, -12),
	Vector3(-12, 0, -12), Vector3(-12, 0, 0)
]

var indice = 0
var vueltas = 0

func _physics_process(delta):
	velocity += get_gravity() * delta
	var destino = ruta[indice]
	var hacia = destino - global_position
	hacia.y = 0.0
	if hacia.length() < distancia_llegada:
		indice = (indice + 1) % ruta.size()
		print(name, " va al punto ", indice, " cuadro ", Engine.get_physics_frames())
		if indice == 0:
			vueltas += 1
			print(name, " vuelta ", vueltas)
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	if dir.length_squared() > 0.001:
		basis = Basis.looking_at(dir)
	move_and_slide()

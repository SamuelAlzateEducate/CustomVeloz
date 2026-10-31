extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 12, 4)
@export var suavizado = 3.0

@export var limite_min = Vector2(-3, -10)
@export var limite_max = Vector2(3, 10)

func _ready():
	top_level = true
	look_at_from_position(objetivo.global_position + distancia, objetivo.global_position)

func _physics_process(delta):
	var foco = objetivo.global_position
	foco.x = clamp(foco.x, limite_min.x, limite_max.x)
	foco.z = clamp(foco.z, limite_min.y, limite_max.y)
	
	var destino = foco + distancia
	global_position = global_position.lerp(destino, suavizado * delta)

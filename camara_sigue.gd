extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 12, 4)
@export var suavizado = 3.0

func _ready():
	top_level = true
	# Se orienta una sola vez mirando al objetivo
	look_at_from_position(objetivo.global_position + distancia, objetivo.global_position)

func _physics_process(delta):
	var destino = objetivo.global_position + distancia
	global_position = global_position.lerp(destino, suavizado * delta)
	
	# Medida (bórrenla al terminar las pruebas):
	if Engine.get_physics_frames() % 30 == 0:
		print("cámara ", global_position.snappedf(0.01))

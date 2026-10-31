extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 12, 4)

func _ready():
	top_level = true
	look_at_from_position(objetivo.global_position + distancia, objetivo.global_position)

func _physics_process(delta):
	global_position = objetivo.global_position + distancia
	# Medida (la borras cuando termines de probar):
	if Engine.get_physics_frames() % 30 == 0:
		print("cámara ", global_position.snappedf(0.01))

extends Camera3D

@export var objetivo: Node3D
@export var distancia := Vector3(0, 3, 7) # desfase tercera persona de CustomVeloz (Taller 4)
@export var suavizado := 3.0
@export var limite_min := Vector2(-14, -14) # x y z mínimas del foco (el suelo de zona_a mide 30 x 30)
@export var limite_max := Vector2(14, 14) # x y z máximas del foco

func _ready() -> void:
	top_level = true
	if objetivo:
		# Se orienta UNA vez, mirando al objetivo.
		look_at_from_position(objetivo.global_position + distancia, objetivo.global_position)

func _physics_process(delta: float) -> void:
	if not objetivo:
		return
	var foco := objetivo.global_position
	foco.x = clampf(foco.x, limite_min.x, limite_max.x)
	foco.z = clampf(foco.z, limite_min.y, limite_max.y)
	var destino := foco + distancia
	global_position = global_position.lerp(destino, suavizado * delta)

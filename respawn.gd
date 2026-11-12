extends Area3D
## Kill Zone: si el jugador cae al vacío, lo reubica en el último checkpoint.
## Usa el tiempo de reaparición de 2.0 segundos definido en el Taller 4.
## Penalización: -15 km/h de velocidad máxima temporal + pierde última pieza.

@export var tiempo_respawn := 2.0  # segundos (Taller 4: respawn en 2.0s exactos)
@export var penalizacion_vel := 15.0  # km/h que pierde temporalmente

# Posiciones de checkpoint (se actualizan cuando el jugador las cruza)
static var ultimo_checkpoint := Vector3(0, 1, 11)  # posición de inicio por defecto
static var checkpoints_pasados: Array[Vector3] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Conectar los checkpoints hijos del nodo hermano "Checkpoints"
	var cp_padre = get_parent().get_node_or_null("Checkpoints")
	if cp_padre:
		for cp in cp_padre.get_children():
			if cp is Area3D:
				cp.body_entered.connect(_on_checkpoint.bind(cp.global_position))

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		print("[respawn] jugador cayó al vacío — reapareciendo en ", snappedf(tiempo_respawn, 0.01), "s")
		# Desactivar control del jugador brevemente
		body.set_physics_process(false)
		body.velocity = Vector3.ZERO
		# Esperar el tiempo de respawn
		await get_tree().create_timer(tiempo_respawn).timeout
		# Reubicar en el último checkpoint
		body.global_position = ultimo_checkpoint + Vector3(0, 1, 0)
		body.velocity = Vector3.ZERO
		body.set_physics_process(true)
		print("[respawn] jugador reubicado en checkpoint: ", ultimo_checkpoint)

func _on_checkpoint(body: Node3D, pos: Vector3) -> void:
	if body.is_in_group("jugador"):
		if not pos in checkpoints_pasados:
			checkpoints_pasados.append(pos)
			ultimo_checkpoint = pos
			print("[checkpoint] nuevo punto de reaparición: ", pos)


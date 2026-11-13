extends Area3D
## Kill Zone: si el jugador cae al vacío, lo reubica en el último checkpoint.
## Usa el tiempo de reaparición de 2.0 segundos definido en el Taller 4.
## Penalización: -15 km/h de velocidad máxima temporal + pierde última pieza.

@export var tiempo_respawn := 2.0  # segundos (Taller 4: respawn en 2.0s exactos)
@export var penalizacion_vel := 15.0  # km/h que pierde temporalmente
## Respaldo: si el jugador baja más de estos metros por debajo de esta zona sin haberla
## tocado (cayó por un lado, o la atravesó muy rápido), reaparece igual.
@export var profundidad_respaldo := 2.0

# Posiciones de checkpoint (se actualizan cuando el jugador las cruza)
static var ultimo_checkpoint := Vector3(0, 1, 11)  # posición de inicio por defecto
static var ultimo_yaw := 0.0  # hacia dónde miraba el carro en ese checkpoint
static var tiene_yaw := false
static var checkpoints_pasados: Array[Vector3] = []

var reapareciendo := false

func _ready() -> void:
	# Las variables static sobreviven al reiniciar la escena: se limpian en cada intento
	ultimo_checkpoint = Vector3(0, 1, 11)
	ultimo_yaw = 0.0
	tiene_yaw = false
	checkpoints_pasados.clear()
	body_entered.connect(_on_body_entered)
	# Conectar los checkpoints hijos del nodo hermano "Checkpoints"
	var cp_padre = get_parent().get_node_or_null("Checkpoints")
	if cp_padre:
		for cp in cp_padre.get_children():
			if cp is Area3D:
				cp.body_entered.connect(_on_checkpoint.bind(cp.global_position))

func _physics_process(_delta: float) -> void:
	if reapareciendo:
		return
	var limite := global_position.y - profundidad_respaldo
	for j in get_tree().get_nodes_in_group("jugador"):
		if not (j is Node3D):
			continue
		# Primer cuadro: guardar hacia dónde mira el carro al empezar
		if not tiene_yaw:
			ultimo_yaw = j.global_rotation.y
			tiene_yaw = true
		if j.global_position.y < limite:
			_reaparecer(j)
			break

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador"):
		_reaparecer(body)

func _reaparecer(body: Node3D) -> void:
	if reapareciendo:
		return
	reapareciendo = true
	print("[respawn] jugador cayó al vacío — reapareciendo en ", snappedf(tiempo_respawn, 0.01), "s")
	# Desactivar control del jugador brevemente
	body.set_physics_process(false)
	_frenar_jugador(body)
	# Esperar el tiempo de respawn
	await get_tree().create_timer(tiempo_respawn).timeout
	if not is_instance_valid(body):
		reapareciendo = false
		return
	# Reubicar en el último checkpoint, derecho y mirando hacia donde iba la pista
	body.global_position = ultimo_checkpoint + Vector3(0, 1, 0)
	if tiene_yaw:
		body.global_transform.basis = Basis(Vector3.UP, ultimo_yaw)
	# Borrar también la velocidad "interna" del carro: si no, sale disparado otra vez
	_frenar_jugador(body)
	body.set_physics_process(true)
	reapareciendo = false
	print("[respawn] jugador reubicado en checkpoint: ", ultimo_checkpoint)

func _frenar_jugador(body: Node3D) -> void:
	body.set("velocity", Vector3.ZERO)
	# Estado interno de personaje.gd (la rapidez que el carro "recuerda")
	body.set("rapidez_actual", 0.0)
	body.set("volante_actual", 0.0)
	body.set("angulo_ruedas_actual", 0.0)
	body.set("avance", Vector3.ZERO)
	body.set("empuje", Vector3.ZERO)

func _on_checkpoint(body: Node3D, pos: Vector3) -> void:
	if body.is_in_group("jugador"):
		if not pos in checkpoints_pasados:
			checkpoints_pasados.append(pos)
			ultimo_checkpoint = pos
			ultimo_yaw = body.global_rotation.y
			tiene_yaw = true
			print("[checkpoint] nuevo punto de reaparición: ", pos)

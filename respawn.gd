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
	add_to_group("respawn")
	# Las variables static sobreviven al reiniciar la escena: se limpian en cada intento
	ultimo_checkpoint = Vector3(0, 1, 11)
	ultimo_yaw = 0.0
	tiene_yaw = false
	checkpoints_pasados.clear()
	body_entered.connect(_on_body_entered)
	# Conectar los checkpoints hijos del nodo hermano "Checkpoints"
	var cp_padre = get_parent().get_node_or_null("Checkpoints")
	if cp_padre == null:
		cp_padre = get_parent().get_node_or_null("Pista/Checkpoints")
	if cp_padre:
		for cp in cp_padre.get_children():
			if cp is Area3D:
				cp.body_entered.connect(_on_checkpoint.bind(cp.global_position))

func registrar_checkpoint(pos: Vector3, yaw: float) -> void:
	ultimo_checkpoint = pos
	ultimo_yaw = yaw
	tiene_yaw = true
	if not pos in checkpoints_pasados:
		checkpoints_pasados.append(pos)
	print("[respawn] nuevo checkpoint registrado: ", pos)

func registrar_checkpoint_jugador(body: Node3D, pos: Vector3, yaw: float) -> void:
	if is_instance_valid(body):
		body.set_meta("ultimo_cp", pos)
		body.set_meta("ultimo_yaw", yaw)
		if not pos in checkpoints_pasados:
			checkpoints_pasados.append(pos)
		print("[respawn] nuevo checkpoint para ", body.name, ": ", pos)

func _physics_process(_delta: float) -> void:
	var limite := global_position.y - profundidad_respaldo
	for j in get_tree().get_nodes_in_group("jugador"):
		if not (j is Node3D):
			continue
		if not j.has_meta("ultimo_cp"):
			var default_inicio := Vector3(3.5, 0.05, 11.0) if j.get("jugador_id") == 2 else Vector3(0.0, 0.05, 11.0)
			j.set_meta("ultimo_cp", default_inicio)
			j.set_meta("ultimo_yaw", j.global_rotation.y)
		if j.global_position.y < limite and not j.get_meta("reapareciendo", false):
			_reaparecer(j)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("jugador") and not body.get_meta("reapareciendo", false):
		_reaparecer(body)

func _reaparecer(body: Node3D) -> void:
	body.set_meta("reapareciendo", true)
	print("[respawn] ", body.name, " cayó al vacío — reapareciendo en ", snappedf(tiempo_respawn, 0.01), "s")
	# Desactivar control del jugador brevemente
	body.set_physics_process(false)
	_frenar_jugador(body)
	# Esperar el tiempo de respawn
	await get_tree().create_timer(tiempo_respawn).timeout
	if not is_instance_valid(body):
		return
	# Mecánica 5: al reaparecer pierde la última pieza obtenida
	if body.has_method("quitar_ultima_mejora"):
		body.quitar_ultima_mejora()
	# Reubicar en su último checkpoint respectivo
	var default_cp := Vector3(3.5, 0.05, 11.0) if body.get("jugador_id") == 2 else Vector3(0.0, 0.05, 11.0)
	var pos: Vector3 = body.get_meta("ultimo_cp", default_cp)
	var yaw: float = body.get_meta("ultimo_yaw", 0.0)
	body.global_position = pos + Vector3(0, 0.8, 0)
	body.global_transform.basis = Basis(Vector3.UP, yaw)
	# Borrar también la velocidad interna del carro
	_frenar_jugador(body)
	body.set_physics_process(true)
	body.set_meta("reapareciendo", false)
	print("[respawn] ", body.name, " reubicado en checkpoint: ", pos)

func _frenar_jugador(body: Node3D) -> void:
	body.set("velocity", Vector3.ZERO)
	# Estado interno de personaje.gd (la rapidez que el carro "recuerda")
	body.set("rapidez_actual", 0.0)
	body.set("volante_actual", 0.0)
	body.set("angulo_ruedas_actual", 0.0)
	body.set("giro_angular_actual", 0.0)
	body.set("esta_derrapando", false)
	body.set("intensidad_derrape", 0.0)
	body.set("comp_lateral_actual", 0.0)
	if body.has_method("detener_sonido_derrape"):
		body.detener_sonido_derrape()
	body.set("avance", Vector3.ZERO)
	body.set("empuje", Vector3.ZERO)

func _on_checkpoint(body: Node3D, pos: Vector3) -> void:
	if body.is_in_group("jugador"):
		if not pos in checkpoints_pasados:
			checkpoints_pasados.append(pos)
		# Siempre se actualiza: en la vuelta 2 y 3 el último checkpoint es el de esa vuelta
		ultimo_checkpoint = pos
		ultimo_yaw = body.global_rotation.y
		tiene_yaw = true
		print("[checkpoint] nuevo punto de reaparición: ", pos)

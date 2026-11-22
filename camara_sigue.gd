extends Camera3D

# Camara de persecucion (Taller 8, tarea A): va detras y arriba del carro y gira con el.
# distancia = desfase del Documento de concepto (0, 3, 7), medido en el marco del carro.

@export var objetivo: Node3D
@export var distancia := Vector3(0, 3, 7) # desfase tercera persona de CustomVeloz (Taller 4)
@export var suavizado := 10.0 # que tan rapido alcanza su sitio (mas alto = mas pegada)
@export var suavizado_giro := 4.0 # que tan rapido se acomoda detras del carro al girar
@export var altura_mirada := 1.0 # m sobre el carro hacia donde mira
@export var usar_limites := false # limites del nivel (Nivel 3): apagados en el circuito
@export var limite_min := Vector2(-14, -14) # x y z minimas del foco
@export var limite_max := Vector2(14, 14) # x y z maximas del foco

@export var fov_normal := 75.0
@export var fov_turbo := 88.0
@export var suavizado_fov := 7.0
@export var temblor_fuerza := 0.035

var yaw := 0.0
var _nitro_nodo: Node

func _yaw_del_objetivo() -> float:
	var ade := -objetivo.global_transform.basis.z
	return atan2(-ade.x, -ade.z)

func _ready() -> void:
	top_level = true
	fov = fov_normal
	if objetivo:
		yaw = _yaw_del_objetivo()
		var foco := objetivo.global_position
		look_at_from_position(foco + Basis(Vector3.UP, yaw) * distancia, foco + Vector3.UP * altura_mirada)

func _physics_process(delta: float) -> void:
	if not objetivo:
		return
	
	if _nitro_nodo == null and is_instance_valid(objetivo):
		_nitro_nodo = objetivo.get_node_or_null("Nitro")
	
	var es_turbo := false
	if _nitro_nodo and "activo" in _nitro_nodo:
		es_turbo = bool(_nitro_nodo.activo)
	
	# Efecto Burnout: Expansión de FOV al activar turbo
	var target_fov := fov_turbo if es_turbo else fov_normal
	fov = lerpf(fov, target_fov, 1.0 - exp(-suavizado_fov * delta))

	yaw = lerp_angle(yaw, _yaw_del_objetivo(), 1.0 - exp(-suavizado_giro * delta))
	var foco := objetivo.global_position
	if usar_limites:
		foco.x = clampf(foco.x, limite_min.x, limite_max.x)
		foco.z = clampf(foco.z, limite_min.y, limite_max.y)
	var destino := foco + Basis(Vector3.UP, yaw) * distancia

	# Vibración arcade de alta velocidad con turbo
	if es_turbo:
		var temblor := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * temblor_fuerza
		destino += Basis(Vector3.UP, yaw) * temblor

	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))
	look_at(foco + Vector3.UP * altura_mirada, Vector3.UP)

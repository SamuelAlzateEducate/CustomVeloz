class_name SistemaSol
extends Node3D

signal cambio_noche(es_noche: bool)

@export var sol: DirectionalLight3D
@export var entorno: WorldEnvironment
@export var energia_sol := 1.0
@export var azimut := 0.0 # grados en Y: 0 = el sol de frente (hacia -Z), como pide la zona
@export var ambiente_dia := 1.0
@export var ambiente_noche := 0.2

@onready var ciclo: CicloDia = $CicloDia

var era_noche := false

func _ready() -> void:
	aplicar_hora()
	era_noche = CicloDia.factor_sol(ciclo.hora) <= 0.0
	# Prueba del aviso (descomentar un momento, con Pausado desmarcado y Duracion Dia 12):
	# cambio_noche.connect(func(n): print("noche: ", n, " a las ", snappedf(ciclo.hora, 0.1)))

func _process(delta: float) -> void:
	ciclo.avanzar(delta)
	aplicar_hora()
	var es_noche := CicloDia.factor_sol(ciclo.hora) <= 0.0
	if es_noche != era_noche:
		era_noche = es_noche
		cambio_noche.emit(es_noche)

func aplicar_hora() -> void:
	var h := ciclo.hora
	var f := CicloDia.factor_sol(h)
	if sol:
		sol.rotation_degrees = Vector3(-CicloDia.elevacion(h), azimut, 0.0)
		sol.light_energy = energia_sol * f
		sol.light_color = CicloDia.color_sol(h)
	if entorno and entorno.environment:
		entorno.environment.ambient_light_energy = lerpf(ambiente_noche, ambiente_dia, f)

# --- Nivel 3: Lambert y predicción ---
static func lambert(normal: Vector3, hacia_luz: Vector3) -> float:
	var n := normal.normalized()
	var l := hacia_luz.normalized()
	return maxf(0.0, n.dot(l))

func prediccion_piso() -> float:
	var hacia_luz := sol.global_transform.basis.z
	return sol.light_energy * sol.light_color.r * lambert(Vector3.UP, hacia_luz)

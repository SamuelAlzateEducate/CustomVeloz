class_name SistemaSol
extends Node3D

@export var sol: DirectionalLight3D
@export var entorno: WorldEnvironment

var ciclo: CicloDia
var era_noche: bool = false

signal cambio_noche(es_noche: bool)

func _ready() -> void:
	ciclo = CicloDia.new()
	if not sol:
		sol = get_node_or_null("../DirectionalLight3D")
	if not entorno:
		entorno = get_node_or_null("../WorldEnvironment")
	
	# Prueba de la señal en consola (puedes borrar o comentar esta línea después de probar)
	cambio_noche.connect(func(n): print("noche: ", n, " a las ", snappedf(ciclo.hora, 0.1)))

func _process(delta: float) -> void:
	ciclo.avanzar(delta)
	aplicar_hora()

func aplicar_hora() -> void:
	var h = ciclo.hora
	var elv = CicloDia.elevacion(h)
	var factor = CicloDia.factor_sol(h)
	var col = CicloDia.color_sol(h)
	
	if sol:
		sol.rotation_degrees.x = -elv
		sol.light_energy = factor * 2.0
		sol.light_color = col
		
	var es_noche = h < 6.0 or h > 18.0
	if es_noche != era_noche:
		era_noche = es_noche
		cambio_noche.emit(es_noche)

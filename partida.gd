extends Node

enum Estado { JUGANDO, GANO, PERDIO }

@export var tiempo_limite = 300.0
@export var gana_con_tiempo = false
@export var metas = 3
@export var espera_reinicio = 2.0

static var intentos = 1
static var mejor = 0.0

var estado = Estado.JUGANDO
var tiempo = 0.0
var hechas = 0
var reloj = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("partida")
	tiempo = tiempo_limite
	print("intento ", intentos, " · mejor tiempo ", snappedf(mejor, 0.01))

func _physics_process(delta):
	if estado != Estado.JUGANDO:
		reloj -= delta
		if reloj <= 0.001:
			reiniciar()
		return
	
	tiempo = maxf(tiempo - delta, 0.0)
	if tiempo <= 0.001:
		if gana_con_tiempo:
			ganar()
		else:
			perder("se acabó el tiempo")

func avisar_meta():
	if estado != Estado.JUGANDO:
		return
	hechas += 1
	print("meta ", hechas, " de ", metas)
	if metas > 0 and hechas >= metas:
		ganar()

func ganar():
	terminar(Estado.GANO, "ganó")

func perder(motivo):
	terminar(Estado.PERDIO, motivo)

func terminar(nuevo, motivo):
	if estado != Estado.JUGANDO:
		return
	estado = nuevo
	print("fin: ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames(), " (", motivo, ")")
	get_tree().paused = true
	reloj = espera_reinicio
	var usado = tiempo_limite - tiempo
	if estado == Estado.GANO and (mejor == 0.0 or usado < mejor):
		mejor = usado

func reiniciar():
	intentos += 1
	get_tree().paused = false
	get_tree().reload_current_scene()

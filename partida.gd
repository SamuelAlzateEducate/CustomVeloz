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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		capturar_pantalla("capturas/c4_escenario_manual.png")

func capturar_pantalla(ruta: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(ruta)
		print("[captura] guardada en ", ruta)

func _physics_process(delta):
	if estado != Estado.JUGANDO:
		reloj -= delta
		if reloj <= 0.001:
			reiniciar()
		return
	
	var pista := get_tree().get_first_node_in_group("pista")
	if pista and pista.get("en_cuenta") == true:
		return # No descontar tiempo durante la cuenta regresiva del semaforo
	
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

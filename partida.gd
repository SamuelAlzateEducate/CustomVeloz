extends Node

# CustomVeloz - Sistema de Modo Time Trial y Gestión de Carrera
# - Cronómetro de vuelta y carrera (cuenta progresiva con centésimas)
# - Guardado persistente de Récords (PB Mejor Vuelta y Mejor Tiempo Total) en user://records.cfg
# - Sistema de Deltas en Checkpoints (comparativa en tiempo real contra el récord: -verde / +rojo)
# - Reinicio instantáneo con tecla R

enum Estado { JUGANDO, GANO, PERDIO }

const RUTA_RECORDS := "user://records.cfg"

@export var metas: int = 3
@export var espera_reinicio: float = 2.5

static var intentos: int = 1

var estado = Estado.JUGANDO
var hechas: int = 0
var reloj: float = 0.0

# Cronómetros Time Trial
var tiempo_carrera: float = 0.0
var tiempo_vuelta: float = 0.0
var carrera_iniciada: bool = false

# Récords persistentes (Cargados de user://records.cfg)
var mejor_vuelta: float = 0.0
var mejor_total: float = 0.0
var splits_mejor_vuelta: Dictionary = {} # cp_index -> float (tiempo de vuelta en ese CP)
var splits_actuales: Dictionary = {}

# Feedback visual de deltas
var delta_cp: float = 0.0
var mostrar_delta_t: float = 0.0
var aviso_record_t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("partida")
	cargar_records()
	print("[TimeTrial] Intento ", intentos, " | PB Vuelta: ", formato_tiempo(mejor_vuelta, true), " | PB Total: ", formato_tiempo(mejor_total, true))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			reiniciar()
		elif event.keycode == KEY_F12:
			capturar_pantalla("capturas/c4_escenario_manual.png")

func _physics_process(delta: float) -> void:
	# Decrementar temporizadores de aviso en HUD
	if mostrar_delta_t > 0.0:
		mostrar_delta_t = maxf(0.0, mostrar_delta_t - delta)
	if aviso_record_t > 0.0:
		aviso_record_t = maxf(0.0, aviso_record_t - delta)

	if estado != Estado.JUGANDO:
		reloj -= delta
		if reloj <= 0.001:
			reiniciar()
		return
	
	var pista := get_tree().get_first_node_in_group("pista")
	if pista and pista.get("en_cuenta") == true:
		carrera_iniciada = false
		return
	
	carrera_iniciada = true
	tiempo_carrera += delta
	tiempo_vuelta += delta

func registrar_checkpoint_split(cp_index: int) -> void:
	splits_actuales[cp_index] = tiempo_vuelta
	if splits_mejor_vuelta.has(cp_index):
		var t_ref: float = float(splits_mejor_vuelta[cp_index])
		delta_cp = tiempo_vuelta - t_ref
		mostrar_delta_t = 2.8 # Mostrar 2.8 segundos en el HUD
		print("[TimeTrial] CP %d: %.2fs (%s%.2fs)" % [cp_index + 1, tiempo_vuelta, "+" if delta_cp > 0 else "", delta_cp])

func avisar_meta() -> void:
	if estado != Estado.JUGANDO:
		return
	hechas += 1
	var tiempo_esta_vuelta := tiempo_vuelta
	print("[TimeTrial] Vuelta %d completada en %s" % [hechas, formato_tiempo(tiempo_esta_vuelta)])
	
	# Verificar si bate el récord de vuelta
	if mejor_vuelta <= 0.001 or tiempo_esta_vuelta < mejor_vuelta:
		mejor_vuelta = tiempo_esta_vuelta
		splits_mejor_vuelta = splits_actuales.duplicate()
		aviso_record_t = 3.5
		guardar_records()
		print("[TimeTrial] ¡¡¡NUEVO RÉCORD PERSONAL DE VUELTA: %s!!!" % formato_tiempo(mejor_vuelta))
	
	splits_actuales.clear()
	tiempo_vuelta = 0.0
	
	if metas > 0 and hechas >= metas:
		ganar()

func ganar() -> void:
	if mejor_total <= 0.001 or tiempo_carrera < mejor_total:
		mejor_total = tiempo_carrera
		guardar_records()
		print("[TimeTrial] ¡¡¡NUEVO RÉCORD TOTAL DE CARRERA: %s!!!" % formato_tiempo(mejor_total))
	terminar(Estado.GANO, "¡Carrera completada!")

func perder(motivo: String) -> void:
	terminar(Estado.PERDIO, motivo)

func terminar(nuevo: Estado, motivo: String) -> void:
	if estado != Estado.JUGANDO:
		return
	estado = nuevo
	print("fin: ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames(), " (", motivo, ")")
	get_tree().paused = true
	reloj = espera_reinicio

func reiniciar() -> void:
	intentos += 1
	get_tree().paused = false
	get_tree().reload_current_scene()

# ------------------------------------------------------------------ Persistencia
func cargar_records() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(RUTA_RECORDS)
	if err == OK:
		mejor_vuelta = float(cfg.get_value("records", "mejor_vuelta", 0.0))
		mejor_total = float(cfg.get_value("records", "mejor_total", 0.0))
		var sp = cfg.get_value("records", "splits_mejor_vuelta", {})
		if sp is Dictionary:
			splits_mejor_vuelta = sp
	else:
		mejor_vuelta = 0.0
		mejor_total = 0.0
		splits_mejor_vuelta = {}

func guardar_records() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "mejor_vuelta", mejor_vuelta)
	cfg.set_value("records", "mejor_total", mejor_total)
	cfg.set_value("records", "splits_mejor_vuelta", splits_mejor_vuelta)
	cfg.save(RUTA_RECORDS)

static func formato_tiempo(segundos: float, es_record: bool = false) -> String:
	if es_record and segundos <= 0.001:
		return "--:--.--"
	var total_seg := maxf(0.0, segundos)
	var mins := int(total_seg / 60.0)
	var segs := int(total_seg) % 60
	var cent := int((total_seg - floorf(total_seg)) * 100.0)
	return "%d:%02d.%02d" % [mins, segs, cent]

func capturar_pantalla(ruta: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(ruta)
		print("[captura] guardada en ", ruta)

extends Node

# CustomVeloz - Sistema de Modo Time Trial y Gestión de Carrera

enum Estado { JUGANDO, GANO, PERDIO }

const RUTA_RECORDS := "user://records.cfg"

@export var metas: int = 3
@export var espera_reinicio: float = 2.5

static var intentos: int = 1

var estado = Estado.JUGANDO
var hechas: int = 0
var reloj: float = 0.0

# Modo 2 jugadores: vueltas individuales
var vueltas_p1: int = 0
var vueltas_p2: int = 0

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


## Solo en modo 2 jugadores: cada jugador reporta sus vueltas individualmente.
func avisar_meta_jugador(jugador_id: int) -> void:
	if estado != Estado.JUGANDO:
		return
	var vueltas_max := metas
	if jugador_id == 1:
		vueltas_p1 += 1
		hechas = vueltas_p1
		tiempo_vuelta = 0.0
		print("[2J] J1 Vuelta %d completada" % vueltas_p1)
		if vueltas_p1 >= vueltas_max:
			ConfigJuego.ganador = 1
			_mostrar_ganador(1)
			terminar(Estado.GANO, "¡JUGADOR 1 GANA!")
	elif jugador_id == 2:
		vueltas_p2 += 1
		print("[2J] J2 Vuelta %d completada" % vueltas_p2)
		if vueltas_p2 >= vueltas_max:
			ConfigJuego.ganador = 2
			_mostrar_ganador(2)
			terminar(Estado.GANO, "¡JUGADOR 2 GANA!")

func _mostrar_ganador(jid: int) -> void:
	var c := CanvasLayer.new()
	c.layer = 100
	
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.82)
	panel.add_theme_stylebox_override("panel", sb)
	c.add_child(panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var l_cup := Label.new()
	l_cup.text = "🏆"
	l_cup.add_theme_font_size_override("font_size", 68)
	l_cup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l_cup)

	var l := Label.new()
	l.text = "¡JUGADOR %d GANA LA CARRERA!" % jid
	l.add_theme_font_size_override("font_size", 42)
	var col_ganador := Color(1.0, 0.92, 0.0) if jid == 1 else Color(1.0, 0.25, 0.25)
	l.add_theme_color_override("font_color", col_ganador)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)

	var l_sub := Label.new()
	l_sub.text = "3 vueltas completadas con éxito — Presiona [R] para reiniciar"
	l_sub.add_theme_font_size_override("font_size", 18)
	l_sub.add_theme_color_override("font_color", Color(0, 0.9, 1, 1))
	l_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l_sub)

	get_tree().root.add_child(c)

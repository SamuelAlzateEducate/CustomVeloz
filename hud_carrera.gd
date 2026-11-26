extends CanvasLayer

# HUD de la carrera: vuelta, cronómetros Time Trial, récords, deltas, velocidad y turbo.

const C_UI := Color("#FFEA00")
const C_AMBIENTE := Color("#00E5FF")
const C_VERDE_DELTA := Color("#00E676")
const C_ROJO_DELTA := Color("#FF5252")
const C_DORADO := Color("#FFD700")

var l_vuelta: Label
var l_tiempo_vuelta: Label
var l_tiempo_total: Label
var l_pb: Label
var l_delta: Label
var l_ayuda: Label

var l_vel: Label
var l_cuenta: Label
var l_nitro: Label
var l_aleron: Label
var l_rebufo: Label
var pb_nitro: ProgressBar

func _etiqueta(tam: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Panel superior izquierdo: Vueltas, tiempos y PB
	l_vuelta = _etiqueta(32, C_UI)
	l_vuelta.position = Vector2(24, 16)
	
	l_tiempo_vuelta = _etiqueta(24, C_AMBIENTE)
	l_tiempo_vuelta.position = Vector2(24, 56)
	
	l_tiempo_total = _etiqueta(18, Color("#B0BEC5"))
	l_tiempo_total.position = Vector2(24, 88)
	
	l_pb = _etiqueta(18, C_DORADO)
	l_pb.position = Vector2(24, 114)
	
	# Indicador central de Deltas y Nuevo Récord
	l_delta = _etiqueta(38, C_VERDE_DELTA)
	l_delta.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l_delta.offset_left = -300
	l_delta.offset_right = 300
	l_delta.offset_top = 210
	l_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_delta.add_theme_constant_override("outline_size", 8)
	
	# Ayuda en la esquina inferior izquierda
	l_ayuda = _etiqueta(15, Color("#78909C"))
	l_ayuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	l_ayuda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l_ayuda.offset_left = 24
	l_ayuda.offset_bottom = -16
	l_ayuda.offset_top = -42
	l_ayuda.offset_right = 600
	l_ayuda.text = "[R] Reiniciar   [ESPACIO] Derrapar   [SHIFT] Turbo"

	# Panel inferior derecho: Velocímetro y Turbo
	l_vel = _etiqueta(44, C_UI)
	l_vel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	l_vel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l_vel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l_vel.offset_left = -300
	l_vel.offset_top = -80
	l_vel.offset_right = -24
	l_vel.offset_bottom = -20
	l_vel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	l_nitro = _etiqueta(18, C_UI)
	l_nitro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	l_nitro.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l_nitro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l_nitro.offset_left = -300
	l_nitro.offset_top = -120
	l_nitro.offset_right = -24
	l_nitro.offset_bottom = -96
	l_nitro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_nitro.text = "TURBO [SHIFT]"
	
	l_aleron = _etiqueta(16, Color(0.0, 1.0, 0.25))
	l_aleron.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	l_aleron.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l_aleron.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l_aleron.offset_left = -300
	l_aleron.offset_top = -148
	l_aleron.offset_right = -24
	l_aleron.offset_bottom = -124
	l_aleron.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_aleron.text = ""
	
	l_rebufo = _etiqueta(16, Color("#00E5FF"))
	l_rebufo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	l_rebufo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l_rebufo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l_rebufo.offset_left = -300
	l_rebufo.offset_top = -174
	l_rebufo.offset_right = -24
	l_rebufo.offset_bottom = -150
	l_rebufo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_rebufo.text = ""
	
	pb_nitro = ProgressBar.new()
	pb_nitro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pb_nitro.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pb_nitro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pb_nitro.offset_left = -300
	pb_nitro.offset_top = -94
	pb_nitro.offset_right = -24
	pb_nitro.offset_bottom = -84
	pb_nitro.show_percentage = false
	pb_nitro.max_value = 100.0
	pb_nitro.value = 100.0
	
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = C_UI
	sb_fill.set_corner_radius_all(3)
	pb_nitro.add_theme_stylebox_override("fill", sb_fill)
	
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.12, 0.14, 0.8)
	sb_bg.set_corner_radius_all(3)
	pb_nitro.add_theme_stylebox_override("background", sb_bg)
	add_child(pb_nitro)
	
	l_cuenta = _etiqueta(120, C_UI)
	l_cuenta.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l_cuenta.offset_left = -200
	l_cuenta.offset_right = 200
	l_cuenta.offset_top = 90
	l_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	layer = 10
	if ConfigJuego.dos_jugadores:
		# Adaptar posiciones para la mitad superior de la pantalla
		var mitad_y := 360.0
		l_vuelta.text = "J1: VUELTA 1 / 3"
		
		l_vel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		l_vel.offset_left = -260
		l_vel.offset_right = -24
		l_vel.offset_top = mitad_y - 65
		l_vel.offset_bottom = mitad_y - 20
		l_vel.add_theme_font_size_override("font_size", 38)
		
		l_nitro.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		l_nitro.offset_left = -260
		l_nitro.offset_right = -24
		l_nitro.offset_top = mitad_y - 98
		l_nitro.offset_bottom = mitad_y - 76
		l_nitro.add_theme_font_size_override("font_size", 14)
		
		pb_nitro.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pb_nitro.offset_left = -260
		pb_nitro.offset_right = -24
		pb_nitro.offset_top = mitad_y - 75
		pb_nitro.offset_bottom = mitad_y - 67
		
		l_aleron.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		l_aleron.offset_left = -260
		l_aleron.offset_right = -24
		l_aleron.offset_top = mitad_y - 120
		l_aleron.offset_bottom = mitad_y - 100
		
		l_ayuda.set_anchors_preset(Control.PRESET_TOP_LEFT)
		l_ayuda.grow_vertical = Control.GROW_DIRECTION_END
		l_ayuda.offset_left = 24
		l_ayuda.offset_right = 650
		l_ayuda.offset_top = mitad_y - 34
		l_ayuda.offset_bottom = mitad_y - 14
		l_ayuda.add_theme_font_size_override("font_size", 12)
		l_ayuda.text = "[W/A/S/D] Conducir   [ESPACIO] Derrape   [SHIFT] Turbo   [E] Misil"
		
		l_delta.offset_top = 110
		l_delta.add_theme_font_size_override("font_size", 28)
		
		l_cuenta.offset_top = 60
		l_cuenta.add_theme_font_size_override("font_size", 72)

func _process(_delta: float) -> void:
	var partida := get_tree().get_first_node_in_group("partida")
	var pista := get_tree().get_first_node_in_group("pista")
	var jugador := get_tree().get_first_node_in_group("jugador")
	
	if partida:
		var v := mini(int(partida.hechas) + 1, int(partida.metas))
		if ConfigJuego.dos_jugadores:
			l_vuelta.text = "J1: VUELTA %d / %d" % [v, int(partida.metas)]
		else:
			l_vuelta.text = "VUELTA %d / %d" % [v, int(partida.metas)]
		
		var t_v: float = partida.get("tiempo_vuelta") if partida.get("tiempo_vuelta") != null else 0.0
		var t_c: float = partida.get("tiempo_carrera") if partida.get("tiempo_carrera") != null else 0.0
		var pb_v: float = partida.get("mejor_vuelta") if partida.get("mejor_vuelta") != null else 0.0
		
		l_tiempo_vuelta.text = "VUELTA  %s" % partida.formato_tiempo(t_v)
		l_tiempo_total.text  = "TOTAL    %s" % partida.formato_tiempo(t_c)
		l_pb.text            = "RÉCORD  %s" % partida.formato_tiempo(pb_v, true)
		
		# Feedback de Split / Récord
		if partida.get("aviso_record_t") != null and partida.aviso_record_t > 0.0:
			l_delta.text = "¡NUEVO RÉCORD DE VUELTA!"
			l_delta.add_theme_color_override("font_color", C_DORADO)
		elif partida.get("mostrar_delta_t") != null and partida.mostrar_delta_t > 0.0:
			var d: float = partida.delta_cp
			if d <= 0.0:
				l_delta.text = "%.2fs" % d
				l_delta.add_theme_color_override("font_color", C_VERDE_DELTA)
			else:
				l_delta.text = "+%.2fs" % d
				l_delta.add_theme_color_override("font_color", C_ROJO_DELTA)
		else:
			l_delta.text = ""

	if jugador:
		var kmh := Vector2(jugador.velocity.x, jugador.velocity.z).length() * 3.6
		l_vel.text = "%d km/h" % int(round(kmh))
		if jugador.has_node("Nitro"):
			var n = jugador.get_node("Nitro")
			pb_nitro.value = n.carga * 100.0
			var sb := pb_nitro.get_theme_stylebox("fill") as StyleBoxFlat
			if n.activo:
				l_nitro.text = "¡TURBO ACTIVO!"
				l_nitro.add_theme_color_override("font_color", Color("#FF5722"))
				if sb: sb.bg_color = Color("#FF5722")
			elif n.bloqueado:
				l_nitro.text = "TURBO AGOTADO (RECARGANDO)"
				l_nitro.add_theme_color_override("font_color", Color("#90A4AE"))
				if sb: sb.bg_color = Color("#546E7A")
			else:
				l_nitro.text = "TURBO [SHIFT] %d%%" % int(round(n.carga * 100.0))
				l_nitro.add_theme_color_override("font_color", C_UI)
				if sb: sb.bg_color = C_UI
		if jugador.get("mejoras_t") != null and jugador.mejoras_t.size() > 0:
			var t_max: float = 0.0
			for t_val in jugador.mejoras_t:
				t_max = maxf(t_max, float(t_val))
			if t_max > 0.05:
				if t_max < 2.5:
					l_aleron.text = "ALERÓN EXPIRANDO: %.1fs" % t_max
					l_aleron.add_theme_color_override("font_color", Color("#FF5722"))
				else:
					l_aleron.text = "ALERÓN [+15 km/h]: %.1fs" % t_max
					l_aleron.add_theme_color_override("font_color", Color(0.0, 1.0, 0.25))
			else:
				l_aleron.text = ""
		else:
			l_aleron.text = ""
		if l_rebufo:
			if jugador.get("impulso_rebase") != null and jugador.impulso_rebase > 0.0:
				l_rebufo.text = "¡¡REBASE ACTIVADO!!"
				l_rebufo.add_theme_color_override("font_color", Color("#FFD700"))
			elif jugador.get("en_rebufo") == true:
				l_rebufo.text = ">> REBUFO (SUCCIÓN) <<"
				l_rebufo.add_theme_color_override("font_color", Color("#00E5FF"))
			else:
				l_rebufo.text = ""
		if "cohetes_cargados" in jugador and jugador.cohetes_cargados > 0:
			if ConfigJuego.dos_jugadores:
				l_ayuda.text = "[W/A/S/D] Conducir   [ESPACIO] Derrape   [SHIFT] Turbo   [E] MISIL x%d" % jugador.cohetes_cargados
			else:
				l_ayuda.text = "[R] Reiniciar   [ESPACIO] Derrapar   [SHIFT] Turbo   [E] MISIL x%d" % jugador.cohetes_cargados
		else:
			if ConfigJuego.dos_jugadores:
				l_ayuda.text = "[W/A/S/D] Conducir   [ESPACIO] Derrape   [SHIFT] Turbo"
			else:
				l_ayuda.text = "[R] Reiniciar   [ESPACIO] Derrapar   [SHIFT] Turbo"
	if pista:
		l_cuenta.text = pista.texto_cuenta
		l_cuenta.add_theme_color_override("font_color", C_UI if pista.en_cuenta else Color("#76FF03"))

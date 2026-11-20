extends CanvasLayer

# HUD de la carrera: vuelta, tiempo, velocidad y cuenta atras del semaforo (amarillo #FFEA00 = UI).

const C_UI := Color("#FFEA00")
const C_AMBIENTE := Color("#00E5FF")

var l_vuelta: Label
var l_tiempo: Label
var l_vel: Label
var l_cuenta: Label
var l_nitro: Label
var l_aleron: Label
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
	l_vuelta = _etiqueta(34, C_UI)
	l_vuelta.position = Vector2(24, 16)
	l_tiempo = _etiqueta(30, C_AMBIENTE)
	l_tiempo.position = Vector2(24, 62)
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

func _process(_delta: float) -> void:
	var partida := get_tree().get_first_node_in_group("partida")
	var pista := get_tree().get_first_node_in_group("pista")
	var jugador := get_tree().get_first_node_in_group("jugador")
	if partida:
		var v := mini(int(partida.hechas) + 1, int(partida.metas))
		l_vuelta.text = "VUELTA %d / %d" % [v, int(partida.metas)]
		var t := int(ceil(partida.tiempo))
		l_tiempo.text = "TIEMPO %d:%02d" % [int(float(t) / 60.0), t % 60]
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
	if pista:
		l_cuenta.text = pista.texto_cuenta
		l_cuenta.add_theme_color_override("font_color", C_UI if pista.en_cuenta else Color("#76FF03"))

extends CanvasLayer

# HUD de la carrera: vuelta, tiempo, velocidad y cuenta atras del semaforo (amarillo #FFEA00 = UI).

const C_UI := Color("#FFEA00")
const C_AMBIENTE := Color("#00E5FF")

var l_vuelta: Label
var l_tiempo: Label
var l_vel: Label
var l_cuenta: Label

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
	if pista:
		l_cuenta.text = pista.texto_cuenta
		l_cuenta.add_theme_color_override("font_color", C_UI if pista.en_cuenta else Color("#76FF03"))

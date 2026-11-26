extends Node

## SplitScreenCarrera - Orquesta la pantalla dividida horizontal para 2 jugadores.

var _vbox: VBoxContainer = null
var _svc_p1: SubViewportContainer = null
var _svc_p2: SubViewportContainer = null
var _sv_p1: SubViewport = null
var _sv_p2: SubViewport = null
var _cam_p1: Camera3D = null
var _cam_p2: Camera3D = null
var _jugador1: CharacterBody3D = null
var _jugador2: CharacterBody3D = null
var _viewport_cl: CanvasLayer = null
var _hud_p2_cl: CanvasLayer = null

# HUD labels P2
var _l2_vel: Label = null
var _l2_vuelta: Label = null
var _l2_nitro: Label = null
var _l2_cohete: Label = null
var _pb2_nitro: ProgressBar = null

func _ready() -> void:
	if not ConfigJuego.dos_jugadores:
		queue_free()
		return
	await get_tree().process_frame
	_configurar()

func _configurar() -> void:
	var root_scene: Node = get_parent()
	if not root_scene:
		return

	# --- 1. Jugador 1 ---
	_jugador1 = root_scene.get_node_or_null("Personaje") as CharacterBody3D
	if not _jugador1:
		push_error("[SplitScreen] No se encontró el nodo Personaje")
		return
	_jugador1.set("jugador_id", 1)

	# --- 2. Deshabilitar Rival1_Fenyr de la IA (sustituido por Jugador 2) ---
	var rival1: Node = root_scene.get_node_or_null("Rival1_Fenyr")
	if rival1:
		rival1.set_physics_process(false)
		rival1.set_process(false)
		rival1.hide()
		if rival1.is_in_group("rival"):
			rival1.remove_from_group("rival")

	# --- 3. Instanciar Jugador 2 con modelo Fenyr ---
	var pj_scn: PackedScene = load("res://personaje.tscn") as PackedScene
	if pj_scn:
		_jugador2 = pj_scn.instantiate() as CharacterBody3D
		_jugador2.name = "Personaje2"
		_jugador2.set("jugador_id", 2)
		_jugador2.transform = Transform3D(Basis(), Vector3(3.5, 0.0, 11.0))
		
		# Sustituir modelo visual por Fenyr antes de añadirlo a la escena
		var mod_rally: Node = _jugador2.get_node_or_null("Modelo")
		if mod_rally:
			mod_rally.name = "ModeloViejo"
			mod_rally.queue_free()
		var fenyr_path: String = "res://Modelos_Carros/Carro_Contrincante1/fenyr.glb"
		if ResourceLoader.exists(fenyr_path):
			var fenyr_scn: PackedScene = load(fenyr_path) as PackedScene
			if fenyr_scn:
				var fenyr_inst: Node = fenyr_scn.instantiate()
				fenyr_inst.name = "Modelo"
				fenyr_inst.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), Vector3.ZERO)
				_jugador2.add_child(fenyr_inst)
				_jugador2.modelo_nodo = fenyr_inst
		
		root_scene.add_child(_jugador2)
		if not _jugador2.is_in_group("jugador"):
			_jugador2.add_to_group("jugador")
		
		# Congelar si la carrera está en cuenta regresiva
		var pista: Node = root_scene.get_node_or_null("Pista")
		if pista and pista.get("en_cuenta") == true:
			_jugador2.set_physics_process(false)

	# --- 4. Encontrar la cámara original ---
	var cam_original: Camera3D = root_scene.get_node_or_null("Camera3D") as Camera3D
	if not cam_original:
		push_error("[SplitScreen] No se encontró Camera3D")
		return
	var cam_script: Script = cam_original.get_script() as Script

	# --- 5. Capa de renderizado de SubViewports (Layer 0 para que los HUDs queden encima) ---
	_viewport_cl = CanvasLayer.new()
	_viewport_cl.layer = 0
	root_scene.add_child(_viewport_cl)

	# Contenedor VBox vertical para dividir exactamente 50% arriba y 50% abajo
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 0)
	_viewport_cl.add_child(_vbox)

	var compartido_world: World3D = get_viewport().find_world_3d()

	# SubViewport P1 (Arriba)
	_svc_p1 = SubViewportContainer.new()
	_svc_p1.stretch = true
	_svc_p1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sv_p1 = SubViewport.new()
	_sv_p1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv_p1.world_3d = compartido_world
	_sv_p1.transparent_bg = false
	_svc_p1.add_child(_sv_p1)
	_vbox.add_child(_svc_p1)

	# Separador Neón Cian (#00E5FF)
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 4)
	sep.color = Color(0, 0.9, 1, 1)
	_vbox.add_child(sep)

	# SubViewport P2 (Abajo)
	_svc_p2 = SubViewportContainer.new()
	_svc_p2.stretch = true
	_svc_p2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sv_p2 = SubViewport.new()
	_sv_p2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv_p2.world_3d = compartido_world
	_sv_p2.transparent_bg = false
	_svc_p2.add_child(_sv_p2)
	_vbox.add_child(_svc_p2)

	# --- 6. Cámaras independientes ---
	# Cámara P1 dentro del SubViewport 1
	cam_original.reparent(_sv_p1)
	cam_original.current = true
	_cam_p1 = cam_original
	if "camara" in _jugador1:
		_jugador1.camara = _cam_p1

	# Cámara P2 dentro del SubViewport 2
	_cam_p2 = Camera3D.new()
	_cam_p2.fov = cam_original.fov
	if cam_script:
		_cam_p2.set_script(cam_script)
	_cam_p2.set("objetivo", _jugador2)
	_sv_p2.add_child(_cam_p2)
	_cam_p2.current = true
	if _jugador2 and "camara" in _jugador2:
		_jugador2.camara = _cam_p2

	# --- 7. Crear HUD de Jugador 2 (mitad inferior) ---
	_crear_hud_p2(root_scene)

	print("[SplitScreen] Pantalla dividida inicializada con éxito (P1=Rally, P2=Fenyr).")

func _crear_hud_p2(root: Node) -> void:
	_hud_p2_cl = CanvasLayer.new()
	_hud_p2_cl.layer = 15
	root.add_child(_hud_p2_cl)

	_l2_vuelta = _etiqueta(_hud_p2_cl, 24, Color(1, 0.92, 0, 1))
	_l2_vuelta.position = Vector2(24, 385)
	_l2_vuelta.text = "J2: VUELTA 1 / 3"

	# Velocímetro P2 (abajo derecha)
	_l2_vel = _etiqueta(_hud_p2_cl, 38, Color(1, 0.92, 0, 1))
	_l2_vel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_l2_vel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_l2_vel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_l2_vel.offset_left = -260
	_l2_vel.offset_top = -65
	_l2_vel.offset_right = -24
	_l2_vel.offset_bottom = -20
	_l2_vel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_l2_vel.text = "0 km/h"

	# Barra de Nitro P2
	_l2_nitro = _etiqueta(_hud_p2_cl, 14, Color(1, 0.92, 0, 1))
	_l2_nitro.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_l2_nitro.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_l2_nitro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_l2_nitro.offset_left = -260
	_l2_nitro.offset_top = -98
	_l2_nitro.offset_right = -24
	_l2_nitro.offset_bottom = -76
	_l2_nitro.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_l2_nitro.text = "TURBO [NUM 1] 100%"

	_pb2_nitro = ProgressBar.new()
	_pb2_nitro.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pb2_nitro.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pb2_nitro.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pb2_nitro.offset_left = -260
	_pb2_nitro.offset_top = -75
	_pb2_nitro.offset_right = -24
	_pb2_nitro.offset_bottom = -67
	_pb2_nitro.show_percentage = false
	_pb2_nitro.max_value = 100.0
	_pb2_nitro.value = 100.0
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(1, 0.92, 0, 1)
	sb_fill.set_corner_radius_all(2)
	_pb2_nitro.add_theme_stylebox_override("fill", sb_fill)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.12, 0.14, 0.8)
	sb_bg.set_corner_radius_all(2)
	_pb2_nitro.add_theme_stylebox_override("background", sb_bg)
	_hud_p2_cl.add_child(_pb2_nitro)

	# Cohete P2
	_l2_cohete = _etiqueta(_hud_p2_cl, 14, Color(1, 0.35, 0, 1))
	_l2_cohete.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_l2_cohete.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_l2_cohete.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_l2_cohete.offset_left = -260
	_l2_cohete.offset_top = -120
	_l2_cohete.offset_right = -24
	_l2_cohete.offset_bottom = -100
	_l2_cohete.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_l2_cohete.text = ""

	# Controles P2 abajo a la izquierda
	var l_ctrl := _etiqueta(_hud_p2_cl, 12, Color(0.5, 0.65, 0.75, 1))
	l_ctrl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	l_ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l_ctrl.offset_left = 24
	l_ctrl.offset_top = -34
	l_ctrl.offset_right = 650
	l_ctrl.offset_bottom = -14
	l_ctrl.text = "[FLECHAS] Conducir   [NUM 0] Derrape   [NUM 1] Turbo   [NUM 2] Misil"

func _etiqueta(parent: Node, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l

func _process(_delta: float) -> void:
	if not ConfigJuego.dos_jugadores:
		return
	_actualizar_hud_p2()

func _actualizar_hud_p2() -> void:
	if not _jugador2 or not is_instance_valid(_jugador2):
		return

	# Velocidad P2
	var kmh: float = Vector2(_jugador2.velocity.x, _jugador2.velocity.z).length() * 3.6
	if _l2_vel:
		_l2_vel.text = "%d km/h" % int(round(kmh))

	# Nitro P2
	if _jugador2.has_node("Nitro"):
		var n = _jugador2.get_node("Nitro")
		if _pb2_nitro:
			_pb2_nitro.value = n.carga * 100.0
		if _l2_nitro:
			if n.activo:
				_l2_nitro.text = "¡TURBO ACTIVO!"
				_l2_nitro.add_theme_color_override("font_color", Color(1, 0.35, 0, 1))
			elif n.bloqueado:
				_l2_nitro.text = "TURBO AGOTADO"
				_l2_nitro.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65, 1))
			else:
				_l2_nitro.text = "TURBO [NUM 1] %d%%" % int(round(n.carga * 100.0))
				_l2_nitro.add_theme_color_override("font_color", Color(1, 0.92, 0, 1))

	# Cohetes P2
	if _l2_cohete:
		var cohetes: int = _jugador2.get("cohetes_cargados") if "cohetes_cargados" in _jugador2 else 0
		if cohetes > 0:
			_l2_cohete.text = "MISIL [NUM 2] x%d" % cohetes
		else:
			_l2_cohete.text = ""

	# Vueltas P2
	var partida: Node = get_tree().get_first_node_in_group("partida")
	if _l2_vuelta and partida:
		var vp2: int = partida.get("vueltas_p2") if "vueltas_p2" in partida else 0
		var vmax: int = partida.metas
		_l2_vuelta.text = "J2: VUELTA %d / %d" % [mini(vp2 + 1, vmax), vmax]

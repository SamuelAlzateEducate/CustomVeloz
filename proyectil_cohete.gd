extends Area3D

## ---- Proyectil Cohete ---- ##
## Lógica completa del misil disparado:
##   - Vuelo hacia adelante a alta velocidad (75 m/s)
##   - Leve guiado hacia el rival más cercano adelante del jugador
##   - Estela de humo y chispas naranja/cian (CPUParticles3D generadas en código)
##   - Al impactar rival: llama recibir_impacto(), detona explosión visual, suena boom
##   - Se autodestruye tras 4 s si no golpea nada

const VELOCIDAD := 75.0          # m/s de vuelo
const GUIADO_FUERZA := 2.5       # rad/s máximos de guiado lateral
const VIDA_MAX := 4.0            # segundos hasta autodestrucción
const RADIO_GUIADO := 40.0       # metros de búsqueda de rival

var _vida := 0.0
var _disparador: Node3D = null   # referencia al Personaje que disparó
var _modelo: Node3D = null
var _snd_vuelo: AudioStreamPlayer3D = null
var _impactado := false

func _ready() -> void:
	# Importar el modelo 3D del cohete
	var cohete_escena_path := "res://Modelos_Armas/cohete.glb"
	if ResourceLoader.exists(cohete_escena_path):
		var cohete_scn = load(cohete_escena_path)
		if cohete_scn:
			_modelo = cohete_scn.instantiate()
			_modelo.position = Vector3.ZERO
			add_child(_modelo)
			# Quitar Soporte_Techo del proyectil en vuelo (se queda solo en el carro)
			var soporte = _modelo.get_node_or_null("Soporte_Techo")
			if soporte:
				soporte.queue_free()
			# Centrar el nodo Cohete en el Area3D y orientar su punta hacia -Z (adelante)
			var nodo_cohete = _modelo.get_node_or_null("Cohete")
			if nodo_cohete:
				nodo_cohete.position = Vector3.ZERO
				nodo_cohete.rotation_degrees = Vector3.ZERO

	# Colisión: cápsula orientada al eje Z del proyectil
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.12
	cap.height = 0.9
	cs.shape = cap
	cs.rotation_degrees = Vector3(90, 0, 0)
	add_child(cs)

	# Capa 4: proyectiles. Detecta cuerpos en capas 1 (pista) y 8 (rivales)
	collision_layer = 4
	collision_mask = 1 | 8

	# Estela de humo gris (atrás del cohete)
	_crear_estela_humo()

	# Chispas naranja de la tobera (propulsor)
	_crear_chispas_tobera()

	# Sonido de vuelo (loop)
	var snd_path := "res://Sonidos_Armas/cohete_vuelo.mp3"
	if ResourceLoader.exists(snd_path):
		_snd_vuelo = AudioStreamPlayer3D.new()
		_snd_vuelo.stream = load(snd_path)
		_snd_vuelo.volume_db = -4.0
		_snd_vuelo.max_distance = 60.0
		_snd_vuelo.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(_snd_vuelo)
		_snd_vuelo.play()

	body_entered.connect(_on_cuerpo_entrado)

func inicializar(disparador: Node3D) -> void:
	_disparador = disparador

func _physics_process(delta: float) -> void:
	if _impactado:
		return
	_vida += delta
	if _vida >= VIDA_MAX:
		_detonar(false)
		return

	# Guiado suave hacia el rival más cercano que esté adelante del proyectil
	var rival_dir := _buscar_rival()
	if rival_dir.length_squared() > 0.001:
		var angulo_max := GUIADO_FUERZA * delta
		var local := to_local(global_position + rival_dir)
		var giro_y := clampf(-local.x * 0.08, -angulo_max, angulo_max)
		rotate_y(giro_y)

	# Mover hacia adelante (-Z en Godot)
	global_position += -global_transform.basis.z * VELOCIDAD * delta

func _buscar_rival() -> Vector3:
	# Encontrar el primer rival que esté adelante del proyectil (dentro del cono frontal)
	var mejor_dist := RADIO_GUIADO
	var dir_obj := Vector3.ZERO
	for rival in get_tree().get_nodes_in_group("rival"):
		if not rival is Node3D:
			continue
		var diff: Vector3 = rival.global_position - global_position
		# Solo guiamos si está adelante (producto punto positivo con -Z del misil)
		var adelante := -global_transform.basis.z
		if diff.normalized().dot(adelante) < 0.3:
			continue
		var dist := diff.length()
		if dist < mejor_dist:
			mejor_dist = dist
			dir_obj = diff.normalized()
	return dir_obj

func _on_cuerpo_entrado(body: Node) -> void:
	if _impactado:
		return
	# No chocar con el propio disparador
	if body == _disparador:
		return
	_impactado = true
	# Si golpea a un rival, aplicar impacto
	if body.has_method("recibir_impacto"):
		body.recibir_impacto()
	_detonar(true)

func _detonar(con_boom: bool) -> void:
	_impactado = true
	# Silenciar vuelo
	if is_instance_valid(_snd_vuelo):
		_snd_vuelo.stop()
	# Ocultar modelo
	if is_instance_valid(_modelo):
		_modelo.visible = false
	# Deshabilitar física
	set_physics_process(false)
	set_deferred("monitoring", false)

	if con_boom:
		_explosion_visual()
		_sonido_boom()

	# Autodestruir tras 1.5s (deja que el boom suene)
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _explosion_visual() -> void:
	# Destellos de partículas de la explosión (naranja, rojo, cian)
	for i in 3:
		var p := CPUParticles3D.new()
		p.local_coords = false
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = [32, 20, 16][i]
		p.lifetime = [0.6, 0.4, 0.8][i]
		p.randomness = 0.5
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3(0.0, -6.0, 0.0)
		p.initial_velocity_min = [8.0, 12.0, 4.0][i]
		p.initial_velocity_max = [22.0, 28.0, 10.0][i]
		p.scale_amount_min = [0.08, 0.06, 0.12][i]
		p.scale_amount_max = [0.22, 0.14, 0.30][i]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = [Color(1.0, 0.35, 0.0), Color(1.0, 0.1, 0.0), Color(0.0, 0.9, 1.0)][i]
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = [5.0, 4.0, 6.0][i]
		var quad := QuadMesh.new()
		quad.size = Vector2(0.18, 0.18)
		quad.material = mat
		p.mesh = quad
		get_tree().root.add_child(p)
		p.global_position = global_position
		p.emitting = true
		# Autolimpiar
		get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

	# Luz puntual de flash de explosión
	var luz := OmniLight3D.new()
	luz.omni_range = 12.0
	luz.light_color = Color(1.0, 0.5, 0.1)
	luz.light_energy = 10.0
	get_tree().root.add_child(luz)
	luz.global_position = global_position
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.4)
	tw.tween_callback(luz.queue_free)

func _sonido_boom() -> void:
	var snd_path := "res://Sonidos_Armas/cohete_impacto.mp3"
	if not ResourceLoader.exists(snd_path):
		return
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load(snd_path)
	snd.volume_db = 2.0
	snd.max_distance = 80.0
	get_tree().root.add_child(snd)
	snd.global_position = global_position
	snd.play()
	snd.finished.connect(snd.queue_free)

func _crear_estela_humo() -> void:
	var p := CPUParticles3D.new()
	p.name = "EstelaCohete"
	p.local_coords = false
	p.amount = 24
	p.lifetime = 0.7
	p.explosiveness = 0.0
	p.randomness = 0.4
	p.direction = Vector3(0.0, 0.3, 1.0) # hacia atrás en espacio local
	p.spread = 20.0
	p.gravity = Vector3(0.0, 0.5, 0.0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.22
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 0.6, 0.65, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(0.20, 0.20)
	quad.material = mat
	p.mesh = quad
	p.position = Vector3(0.0, 0.0, 0.5) # tobera trasera
	add_child(p)

func _crear_chispas_tobera() -> void:
	var p := CPUParticles3D.new()
	p.name = "ChispasMotor"
	p.local_coords = false
	p.amount = 16
	p.lifetime = 0.25
	p.explosiveness = 0.0
	p.randomness = 0.3
	p.direction = Vector3(0.0, 0.0, 1.0) # hacia atrás
	p.spread = 12.0
	p.gravity = Vector3(0.0, -4.0, 0.0)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.10
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.0, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.9, 1.0)
	mat.emission_energy_multiplier = 5.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	quad.material = mat
	p.mesh = quad
	p.position = Vector3(0.0, 0.0, 0.5) # tobera trasera
	add_child(p)

extends Area3D

## ---- Proyectil Cohete ---- ##
## Lógica completa del misil disparado:
##   - Vuelo hacia adelante a alta velocidad (75 m/s)
##   - Leve guiado hacia el rival más cercano adelante del jugador
##   - Estela de humo y chispas naranja/cian (CPUParticles3D generadas en código)
##   - Al impactar rival: llama recibir_impacto(), detona explosión visual, suena boom
##   - Se autodestruye tras 4 s si no golpea nada

const VELOCIDAD := 48.0          # m/s de vuelo (arcade equilibrado)
const GUIADO_FUERZA := 9.5       # rad/s de guiado fluido hacia el rival
const VIDA_MAX := 4.0            # segundos hasta autodestrucción
const RADIO_GUIADO := 95.0       # metros de alcance frontal para fijar objetivo

var _vida := 0.0
var _disparador: Node3D = null   # referencia al Personaje que disparó
var _modelo: Node3D = null
var _snd_vuelo: AudioStreamPlayer3D = null
var _impactado := false
var _objetivo: Node3D = null

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
				nodo_cohete.rotation_degrees = Vector3(0.0, 180.0, 0.0)

	# Colisión: cápsula orientada al eje Z del proyectil con tamaño generoso para evitar atravesar
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.65
	cap.height = 1.4
	cs.shape = cap
	cs.rotation_degrees = Vector3(90, 0, 0)
	add_child(cs)

	# Capa 4: proyectiles. Detecta cuerpos en capas 1 (pista y carros) y 8 (rivales)
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
		_detonar(true)
		return

	# Buscar objetivo continuamente si aún no tenemos o se perdió
	if not is_instance_valid(_objetivo):
		_objetivo = _buscar_rival_frontal()

	# Guiado teledirigido suave y preciso
	if is_instance_valid(_objetivo):
		var target_pos: Vector3 = _objetivo.global_position + Vector3(0.0, 0.7, 0.0)
		var diff: Vector3 = target_pos - global_position
		var dist: float = diff.length()

		# Detonación inmediata por proximidad al objetivo (garantiza impacto)
		if dist <= 2.4:
			if _objetivo.has_method("recibir_impacto"):
				_objetivo.recibir_impacto()
			_detonar(true)
			return

		var dir: Vector3 = diff.normalized()
		var fwd: Vector3 = -global_transform.basis.z

		# Si el rival quedó claramente atrás, desvincular objetivo
		if fwd.dot(dir) < -0.15:
			_objetivo = null
		else:
			var nuevo_fwd: Vector3 = fwd.slerp(dir, GUIADO_FUERZA * delta).normalized()
			var up: Vector3 = Vector3.UP
			var side: Vector3 = nuevo_fwd.cross(up)
			if side.length_squared() > 0.0001:
				side = side.normalized()
				up = side.cross(nuevo_fwd).normalized()
				global_transform.basis = Basis(side, up, -nuevo_fwd)

	# Raycast de barrido continuo (evita que a alta velocidad atraviese el carro)
	var fwd_mov := -global_transform.basis.z
	var pos_nueva := global_position + fwd_mov * VELOCIDAD * delta
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var exclusions: Array[RID] = []
		if is_instance_valid(self):
			exclusions.append(get_rid())
		if is_instance_valid(_disparador) and _disparador is CollisionObject3D:
			exclusions.append(_disparador.get_rid())
		var ray := PhysicsRayQueryParameters3D.create(global_position, pos_nueva, 1 | 8, exclusions)
		var hit := space_state.intersect_ray(ray)
		if hit and hit.collider:
			var col = hit.collider
			if col != _disparador:
				if col.has_method("recibir_impacto"):
					col.recibir_impacto()
				global_position = hit.position
				_detonar(true)
				return

	# Detección de proximidad con todos los vehículos rivales y jugadores
	for auto in get_tree().get_nodes_in_group("rival") + get_tree().get_nodes_in_group("jugador"):
		if auto == _disparador or not is_instance_valid(auto) or not (auto is Node3D):
			continue
		var dist_auto: float = global_position.distance_to(auto.global_position + Vector3(0.0, 0.7, 0.0))
		if dist_auto <= 2.3:
			if auto.has_method("recibir_impacto"):
				auto.recibir_impacto()
			_detonar(true)
			return

	# Avanzar a la nueva posición
	global_position = pos_nueva

func _buscar_rival_frontal() -> Node3D:
	var fwd: Vector3 = -global_transform.basis.z
	var mejor_dist := RADIO_GUIADO
	var mejor_rival: Node3D = null

	# Buscar en ambos grupos: rivales IA y jugadores humanos
	var candidatos: Array = []
	candidatos.append_array(get_tree().get_nodes_in_group("rival"))
	candidatos.append_array(get_tree().get_nodes_in_group("jugador"))

	for rival in candidatos:
		if not is_instance_valid(rival) or not (rival is Node3D) or rival == _disparador:
			continue
		var diff: Vector3 = rival.global_position - global_position
		var dist := diff.length()
		if dist > mejor_dist:
			continue
		# Cono amplio (~70 grados: dot >= 0.30) para captar al rival en carriles contiguos
		var dir := diff.normalized()
		if fwd.dot(dir) >= 0.30:
			mejor_dist = dist
			mejor_rival = rival as Node3D

	if mejor_rival:
		print("[cohete] ¡ENEMIGO AL FRENTE! Misil teledirigido fijado a: ", mejor_rival.name, " a ", snappedf(mejor_dist, 0.1), " m")

	return mejor_rival

func _on_cuerpo_entrado(body: Node) -> void:
	if _impactado:
		return
	# No chocar con el propio disparador
	if body == _disparador:
		return
	_impactado = true
	# Si golpea a un rival o jugador, aplicar impacto
	if body.has_method("recibir_impacto"):
		body.recibir_impacto()
	_detonar(true)

func _detonar(con_boom: bool) -> void:
	_impactado = true
	# Cortar y liberar el sonido de vuelo de inmediato para evitar bugs de audio residual
	if is_instance_valid(_snd_vuelo):
		_snd_vuelo.stop()
		_snd_vuelo.queue_free()
		_snd_vuelo = null
	# Ocultar y liberar el modelo visual de inmediato
	if is_instance_valid(_modelo):
		_modelo.visible = false
		_modelo.queue_free()
		_modelo = null
	# Deshabilitar física
	set_physics_process(false)
	set_deferred("monitoring", false)

	if con_boom:
		_explosion_visual()
		_sonido_boom()

	# Autodestruir tras 1.6s (para dar tiempo exacto a que termine el boom)
	await get_tree().create_timer(1.6).timeout
	queue_free()

func _explosion_visual() -> void:
	# 1. Onda expansiva esférica/anular naranja fuego (#FF5722)
	var onda := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.7
	var mat_onda := StandardMaterial3D.new()
	mat_onda.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_onda.albedo_color = Color(1.0, 0.35, 0.0)
	mat_onda.emission_enabled = true
	mat_onda.emission = Color(1.0, 0.35, 0.0)
	mat_onda.emission_energy_multiplier = 6.0
	onda.mesh = tm
	get_tree().root.add_child(onda)
	onda.global_position = global_position
	var tw_onda := onda.create_tween()
	tw_onda.tween_property(onda, "scale", Vector3(8.0, 1.0, 8.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_onda.parallel().tween_property(mat_onda, "albedo_color:a", 0.0, 0.4)
	tw_onda.tween_callback(onda.queue_free)

	# 2. Destellos de partículas de la explosión (naranja fuego, humo denso, chispas cian)
	for i in 3:
		var p := CPUParticles3D.new()
		p.local_coords = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = [36, 24, 20][i]
		p.lifetime = [0.65, 0.45, 0.85][i]
		p.randomness = 0.5
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3(0.0, -6.5, 0.0)
		p.initial_velocity_min = [10.0, 14.0, 5.0][i]
		p.initial_velocity_max = [26.0, 30.0, 12.0][i]
		p.scale_amount_min = [0.10, 0.07, 0.14][i]
		p.scale_amount_max = [0.26, 0.16, 0.35][i]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = [Color(1.0, 0.35, 0.0), Color(1.0, 0.1, 0.0), Color(0.0, 0.9, 1.0)][i]
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = [5.5, 4.5, 6.5][i]
		var quad := QuadMesh.new()
		quad.size = Vector2(0.20, 0.20)
		quad.material = mat
		p.mesh = quad
		get_tree().root.add_child(p)
		p.global_position = global_position
		p.emitting = true
		get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

	# 3. Luz puntual de flash de explosión
	var luz := OmniLight3D.new()
	luz.omni_range = 15.0
	luz.light_color = Color(1.0, 0.5, 0.1)
	luz.light_energy = 12.0
	get_tree().root.add_child(luz)
	luz.global_position = global_position
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.4)
	tw.tween_callback(luz.queue_free)

func _sonido_boom() -> void:
	var snd_path := "res://Sonidos_Armas/cohete_impacto.wav"
	if not ResourceLoader.exists(snd_path):
		snd_path = "res://Sonidos_Armas/cohete_impacto.mp3"
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

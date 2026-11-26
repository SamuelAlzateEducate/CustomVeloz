extends CharacterBody3D

# ---- Nivel 3: estados con un número cada uno (CustomVeloz) ----
enum Estado { QUIETO, ANDANDO, NITRO }
# El número de cada estado es su rapidez máxima en km/h, en el orden del enum
const VELOCIDAD_KMH = [0.0, 90.0, 120.0]
const COHETE_SCN := preload("res://proyectil_cohete.tscn")

# ---- Nivel 1 y 2: rapidez y arranque (números del juego, ver tabla del Taller 7) ----
@export var camara: Camera3D
@export var speed_caminar = 25.0 # 90 km/h ÷ 3.6 = 25 m/s (rapidez máxima de base)
@export var speed_correr = 33.33 # 120 km/h ÷ 3.6 = 33.33 m/s (con nitro, tecla Shift)
@export var tiempo_arranque = 3.0 # s en llegar a la rapidez máxima

## Jugador 1 usa WASD+SHIFT+ESPACIO+E; Jugador 2 usa Flechas+KP1+KP0+KP2
@export var jugador_id: int = 1

@export var estado := Estado.QUIETO

@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s", "Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba: String = "Ninguna"
@export var accion_prueba = ""

# ---- Ajustes de Manejo e Interpolación del Carro ----
@export_group("Manejo e Interpolación")
@export var velocidad_giro: float = 2.4 # Radianes/s de rotación al voltear
@export var suavizado_volante_entrada: float = 4.8 # Suavizado al presionar tecla de giro (más bajo = más progresivo en teclado)
@export var suavizado_volante_retorno: float = 9.5 # Suavizado al soltar la tecla (retorno rápido al centro)
@export var factor_atenuacion_alta_vel: float = 0.58 # Sensibilidad en curvas a alta velocidad (evita trompos en teclado)
@export var suavizado_inercia_giro: float = 10.0 # Factor de inercia y fluidez en la rotación del carro
@export var max_angulo_ruedas: float = 0.50 # ~28° ángulo máximo de dirección de ruedas
@export var agarre_lateral: float = 9.0 # Factor de agarre lateral en conducción normal (firme y preciso)
@export var agarre_derrape: float = 2.2 # Fricción lateral en derrape (permite deslizarse de lado con espacio)
@export var max_angulo_derrape_deg: float = 36.0 # Ángulo máximo de derrape para evitar trompos incontrolables
@export var velocidad_min_derrape: float = 2.0 # Rapidez mínima (~7 km/h) para derrape o freno de mano
@export var impulso_salida_derrape: float = 1.08 # Impulso de tracción al soltar el derrape acelerando
@export var suavizado_suspension: float = 8.5 # Factor de interpolación (lerpf) de la suspensión
@export var radio_rueda: float = 0.35 # Radio estimado de llanta para rodamiento realista
@export var gravedad_en_aire: float = 2.5 # Multiplicador de gravedad cuando está en el aire (más alto = cae más rápido)
@export var pegado_al_suelo: float = 3.0 # Metros que "chupa" al suelo en bajadas y baches (floor_snap_length)
@export var suavizado_volante: float = 12.0 # Mantenido por retrocompatibilidad

@export_group("Sonido de Derrape")
@export var ruta_sonido_derrape: String = "res://Sonidos_Carros/CarroRally_Personaje/Derrape_Rally.mp3"

# Los tres enchufes (otros scripts los cambian; no se borran)
var multiplicador = 1.0 # 1 = normal, 0.5 = mitad, 0 = quieto
var empuje = Vector3.ZERO # m/s que se suman (dash, retroceso)
var accion = "" # nombre de una animación que pisa idle/walk

var avance = Vector3.ZERO # la parte de la velocidad que dan las teclas
var nitro_ok = true # lo pone el nodo Nitro: false si no queda carga
var quiere_nitro = false # leído por nitro.gd para activar el turbo
var corre = false # true mientras Shift está presionada y hay nitro
var kmh = 0.0 # rapidez máxima del estado actual

# Checkpoint y vueltas (para modo 2J)
var siguiente_cp: int = 0
var vueltas_completadas: int = 0

# Estado de impacto (trompo por cohete)
var _impacto_t: float = 0.0
var _impacto_dura: float = 1.8

# Referencias a componentes y ruedas
@onready var modelo_nodo: Node3D = get_node_or_null("Modelo")
@onready var anim = get_node_or_null("Modelo/AnimationPlayer")

# ---- Sistema de Armas (Cohete) ----
# (sin preload: se carga en runtime para evitar parse errors al arrancar)
var cohetes_cargados := 0          # Inicia en 0 (solo se adquieren recogiendo esferas rojas, máx 3)
var _cohete_montado: Node3D = null # nodo visual del cohete en el techo
var _snd_equipado: AudioStreamPlayer = null
var _cohete_tecla_previa: bool = false # para detectar just_pressed manual en P2

var rueda_del_izq: Node3D = null # wheels_019
var rueda_del_der: Node3D = null # wheels_040
var rueda_tras_izq: Node3D = null # wheels_018
var rueda_tras_der: Node3D = null # wheels_041

# Estados internos de interpolación
var rapidez_actual: float = 0.0
var volante_actual: float = 0.0
var giro_angular_actual: float = 0.0
var angulo_ruedas_actual: float = 0.0
var rotacion_rodaje: float = 0.0
var roll_chasis: float = 0.0
var pitch_chasis: float = 0.0
var esta_derrapando: bool = false
var intensidad_derrape: float = 0.0
var comp_lateral_actual: float = 0.0
var sonido_derrape: AudioStreamPlayer = null

func _ready():
	floor_snap_length = pegado_al_suelo
	# Capa 1 (pista, muros y carros) + Capa 8 (rivales).
	# Nota: Los conos están en capa 2 y se detectan por Area3D dinámica,
	# evitando que move_and_slide frene el auto bruscamente o altere el motor.
	collision_mask = 1 | 8
	floor_constant_speed = true # misma rapidez en subida y bajada
	if camara == null:
		camara = get_viewport().get_camera_3d()
	
	_buscar_ruedas()
	_inicializar_sonido_derrape()
	
	if prueba != "Ninguna":
		_aplicar_prueba(1)

func _inicializar_sonido_derrape() -> void:
	sonido_derrape = AudioStreamPlayer.new()
	sonido_derrape.name = "SonidoDerrape"
	var stream: Resource = null
	if ResourceLoader.exists(ruta_sonido_derrape):
		stream = load(ruta_sonido_derrape)
		if stream is AudioStreamMP3:
			stream.loop = true
	elif ResourceLoader.exists("res://Sonidos_Carros/CarroRally_Personaje/derrape_loop.wav"):
		stream = load("res://Sonidos_Carros/CarroRally_Personaje/derrape_loop.wav")
	
	if stream:
		sonido_derrape.stream = stream
		print("[personaje] Sonido de derrape inicializado en CharacterBody3D: ", stream.resource_path)
	sonido_derrape.volume_db = -80.0
	sonido_derrape.bus = "Master"
	add_child(sonido_derrape)

func detener_sonido_derrape() -> void:
	if sonido_derrape and is_instance_valid(sonido_derrape):
		sonido_derrape.volume_db = -80.0
		if sonido_derrape.playing:
			sonido_derrape.stop()

func _buscar_ruedas() -> void:
	if not modelo_nodo:
		return
	
	# Búsqueda directa por jerarquía conocida
	rueda_del_izq = modelo_nodo.get_node_or_null("rally/wheels_019")
	rueda_del_der = modelo_nodo.get_node_or_null("rally/wheels_040")
	rueda_tras_izq = modelo_nodo.get_node_or_null("rally/wheels_018")
	rueda_tras_der = modelo_nodo.get_node_or_null("rally/wheels_041")
	
	# Búsqueda de respaldo recursiva si cambian los nombres o jerarquía (Rally y Fenyr)
	if not rueda_del_izq or not rueda_del_der:
		for c in modelo_nodo.find_children("*wheel*", "Node3D", true, false):
			var n = c.name.to_lower()
			if "19" in n or "21" in n:
				rueda_del_izq = c
			elif "40" in n or "39" in n:
				rueda_del_der = c
			elif "18" in n or "20" in n:
				rueda_tras_izq = c
			elif "41" in n or "38" in n:
				rueda_tras_der = c

func _physics_process(delta):
	_actualizar_mejoras(delta)
	_actualizar_cohete(delta)
	# Trompo de impacto: si está siendo impactado bloquear controles
	if _impacto_t > 0.0:
		_impacto_t = maxf(0.0, _impacto_t - delta)
		var factor_gravedad2 = 1.0 if is_on_floor() else gravedad_en_aire
		velocity += get_gravity() * factor_gravedad2 * delta
		move_and_slide()
		return
	# Gravedad: en el aire cae más rápido (arcade) para que el carro no flote
	var factor_gravedad = 1.0 if is_on_floor() else gravedad_en_aire
	velocity += get_gravity() * factor_gravedad * delta
	
	if camara == null:
		camara = get_viewport().get_camera_3d()
	
	# Entradas de control separadas por jugador_id
	var input_x: float
	var acelerar: bool
	var frenar: bool
	var tecla_derrape: bool
	var tecla_nitro: bool
	
	if jugador_id == 2:
		# Jugador 2: Flechas + Numpad o Teclas cercanas (M / N / B)
		input_x = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
		acelerar = Input.is_key_pressed(KEY_UP)
		frenar = Input.is_key_pressed(KEY_DOWN)
		tecla_derrape = (
			Input.is_key_pressed(KEY_KP_0) 
			or Input.is_key_pressed(KEY_0) 
			or Input.is_key_pressed(KEY_M)
		)
		tecla_nitro = (
			Input.is_key_pressed(KEY_KP_1) 
			or Input.is_key_pressed(KEY_1) 
			or Input.is_key_pressed(KEY_N)
			or Input.is_key_pressed(KEY_ENTER)
			or Input.is_key_pressed(KEY_KP_ENTER)
		)
	else:
		# Jugador 1: WASD + Shift + Espacio + E
		if ConfigJuego.dos_jugadores:
			# Separar flechas de WASD en modo 2J
			input_x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
			acelerar = Input.is_key_pressed(KEY_W)
			frenar = Input.is_key_pressed(KEY_S)
			tecla_derrape = Input.is_key_pressed(KEY_SPACE)
			tecla_nitro = Input.is_key_pressed(KEY_SHIFT)
		else:
			# Modo 1J: actions normales
			input_x = Input.get_axis("move_left", "move_right")
			acelerar = Input.is_action_pressed("move_up")
			frenar = Input.is_action_pressed("move_down")
			tecla_derrape = Input.is_action_pressed("derrapar") if InputMap.has_action("derrapar") else Input.is_key_pressed(KEY_SPACE)
			tecla_nitro = Input.is_action_pressed("correr") or Input.is_key_pressed(KEY_SHIFT)
	
	quiere_nitro = tecla_nitro
	corre = tecla_nitro and nitro_ok
	var speed_max: float = (speed_correr if corre else speed_caminar) * multiplicador
	
	# Control de estado de derrape activo (Mecánica de rally arcade / Freno de mano)
	var puede_derrapar := absf(rapidez_actual) >= velocidad_min_derrape and is_on_floor()
	var derrape_previo := esta_derrapando
	# Se activa derrape / freno de mano si se pulsa espacio y hay velocidad suficiente (en recta o en curva)
	if tecla_derrape and puede_derrapar:
		esta_derrapando = true
	elif not tecla_derrape:
		esta_derrapando = false
	
	# Salida del derrape con empuje de tracción si el jugador sigue acelerando
	if derrape_previo and not esta_derrapando and acelerar and absf(rapidez_actual) > 8.0:
		rapidez_actual = minf(rapidez_actual * impulso_salida_derrape, speed_max)
	
	# 1. INTERPOLACIÓN ASIMÉTRICA DEL VOLANTE (Entrada progresiva y retorno ágil para teclado)
	var tasa_volante := suavizado_volante_entrada
	# Si se suelta la tecla o se contravolantea hacia el lado opuesto, regresa con mayor agilidad
	if absf(input_x) < 0.01 or (signf(input_x) != signf(volante_actual) and absf(volante_actual) > 0.05):
		tasa_volante = suavizado_volante_retorno
	volante_actual = lerpf(volante_actual, input_x, clampf(tasa_volante * delta, 0.0, 1.0))
	
	# Curva de respuesta progresiva: toques suaves dan microajustes; mantener presionado da giro completo
	var volante_curva := signf(volante_actual) * pow(absf(volante_actual), 1.25)
	
	# Atenuación de sensibilidad dependiente de velocidad (speed-sensitive steering):
	# A alta velocidad (90-120 km/h) modera la sensibilidad para evitar derrapes bruscos o choques en teclado.
	# Si se está derrapando activamente, se libera para permitir contravolantear y controlar la cruzada.
	var factor_alta_vel := 1.0
	if not esta_derrapando:
		var t_vel = clampf((absf(rapidez_actual) - 8.0) / maxf(speed_correr - 8.0, 1.0), 0.0, 1.0)
		factor_alta_vel = lerpf(1.0, factor_atenuacion_alta_vel, t_vel)
	
	# 2. INTERPOLACIÓN DEL ÁNGULO DE LAS RUEDAS DELANTERAS (lerpf)
	# Nota: Se invierte el signo (-volante_curva) porque el modelo 3D hijo está rotado 180° en Y;
	# así, girar a la derecha apunta las ruedas a la derecha y a la izquierda hacia la izquierda.
	var angulo_obj = -volante_curva * max_angulo_ruedas * factor_alta_vel
	# Durante el derrape en curva, añade asistencia de contravolante visual si hay deslizamiento lateral
	if esta_derrapando and absf(comp_lateral_actual) > 0.8:
		var contravolante = clampf((comp_lateral_actual / maxf(absf(rapidez_actual), 3.0)) * max_angulo_ruedas * 1.2, -max_angulo_ruedas, max_angulo_ruedas)
		angulo_obj = clampf(angulo_obj + contravolante * 0.4, -max_angulo_ruedas, max_angulo_ruedas)
	angulo_ruedas_actual = lerpf(angulo_ruedas_actual, angulo_obj, clampf(suavizado_volante_retorno * delta, 0.0, 1.0))
	
	# 3. ACELERACIÓN, FRENADO Y MARCHA ATRÁS (Con freno de mano funcional en recta y curva)
	var tasa_acel = speed_max / maxf(tiempo_arranque, 0.05)
	if tecla_derrape and is_on_floor() and absf(rapidez_actual) > 0.5:
		# Freno de mano: bloqueo de neumáticos traseros -> frenada brusca con derrape / chillido
		var tasa_freno_mano = (speed_max / 1.1)
		rapidez_actual = move_toward(rapidez_actual, 0.0, tasa_freno_mano * delta)
	elif acelerar or corre:
		rapidez_actual = move_toward(rapidez_actual, speed_max, tasa_acel * delta)
	elif frenar:
		if rapidez_actual > 0.5:
			# Frenada normal hacia 0
			rapidez_actual = move_toward(rapidez_actual, 0.0, (speed_max / 0.75) * delta)
		else:
			# Reversa controlada
			rapidez_actual = move_toward(rapidez_actual, -speed_max * 0.35, (speed_max / 1.8) * delta)
	else:
		# Desaceleración natural por rozamiento
		rapidez_actual = move_toward(rapidez_actual, 0.0, (speed_max / 3.5) * delta)
	
	# 4. INTERPOLACIÓN DEL GIRO / ROTACIÓN DEL VEHÍCULO CON CONTROL DE ÁNGULO EN DERRAPE
	# El giro es proporcional a la velocidad (un carro no gira quieto en su propio eje)
	var factor_velocidad_giro = clampf(absf(rapidez_actual) / maxf(speed_caminar * 0.25, 1.0), 0.15, 1.0)
	var signo_direccion = -1.0 if rapidez_actual < -0.1 else 1.0
	
	# Control de derrape: limita el ángulo de deslizamiento para que el carro no trompee ni se descontrole
	var max_slip_rad := deg_to_rad(max_angulo_derrape_deg)
	var factor_limite_derrape := 1.0
	if esta_derrapando:
		var vel_h_norm = Vector3(velocity.x, 0.0, velocity.z)
		if vel_h_norm.length_squared() > 4.0:
			var dir_fwd = -transform.basis.z
			dir_fwd.y = 0.0
			dir_fwd = dir_fwd.normalized()
			var dir_mov = vel_h_norm.normalized()
			var slip_actual = dir_fwd.signed_angle_to(dir_mov, Vector3.UP)
			var sentido_giro = -signf(volante_curva)
			# Si el volante intenta sobrevirar más allá del límite, amortiguar progresivamente el giro
			if signf(slip_actual) == sentido_giro:
				var margen = clampf(1.0 - (absf(slip_actual) / max_slip_rad), 0.0, 1.0)
				factor_limite_derrape = pow(margen, 0.6)
	
	var mult_giro = (1.35 * factor_limite_derrape) if esta_derrapando else 1.0
	var factor_alta = 1.0 if esta_derrapando else factor_alta_vel
	var giro_objetivo = -volante_curva * velocidad_giro * factor_velocidad_giro * factor_alta * signo_direccion * mult_giro
	giro_angular_actual = lerpf(giro_angular_actual, giro_objetivo, clampf(suavizado_inercia_giro * delta, 0.0, 1.0))
	if absf(rapidez_actual) < 0.05:
		giro_angular_actual = 0.0
	rotate_y(giro_angular_actual * delta)
	
	# 5. ADAPTACIÓN SUAVE A LA INCLINACIÓN DEL SUELO Y PEGADO A LA PENDIENTE
	var space_state := get_world_3d().direct_space_state
	var sobre_pista := false
	var normal_piso := Vector3.UP
	var dist_piso := 999.0
	if space_state:
		var origen_rayo := global_position + Vector3.UP * 0.6
		var destino_rayo := global_position + Vector3.DOWN * 4.5
		var query := PhysicsRayQueryParameters3D.create(origen_rayo, destino_rayo, 1) # capa 1 = pista
		var hit := space_state.intersect_ray(query)
		if hit:
			sobre_pista = true
			normal_piso = hit.normal
			dist_piso = maxf(0.0, origen_rayo.y - hit.position.y - 0.6)
	
	if is_on_floor():
		var nf := get_floor_normal()
		if nf.y > 0.3:
			normal_piso = nf
			dist_piso = 0.0
			sobre_pista = true

	var up_actual = transform.basis.y
	var up_suave = up_actual.lerp(normal_piso if sobre_pista and dist_piso < 2.5 else Vector3.UP, clampf(12.0 * delta, 0.0, 1.0)).normalized()
	var adelante_vector = -transform.basis.z
	adelante_vector = (adelante_vector - up_suave * adelante_vector.dot(up_suave)).normalized()
	if adelante_vector.length_squared() > 0.001:
		var lateral = adelante_vector.cross(up_suave).normalized() # derecha del carro (base sin espejo)
		transform.basis = Basis(lateral, up_suave, -adelante_vector).orthonormalized()
	
	# 6. VELOCIDAD Y AGARRE LATERAL / DERRAPE
	# Descomponemos la velocidad sobre el plano horizontal de la pista en componentes frontal y lateral
	var v_fwd = -transform.basis.z
	v_fwd = (v_fwd - up_suave * v_fwd.dot(up_suave)).normalized()
	var v_lat = transform.basis.x
	v_lat = (v_lat - up_suave * v_lat.dot(up_suave)).normalized()
	
	var vel_plano = Vector3(velocity.x, 0.0, velocity.z)
	var comp_fwd = vel_plano.dot(v_fwd)
	var comp_lat = vel_plano.dot(v_lat)
	
	if esta_derrapando:
		if absf(volante_actual) < 0.1 and absf(input_x) < 0.1:
			# Derrape en recta (freno de mano): las ruedas bloquean, deslizamiento frontal sin trompo
			comp_lat = lerpf(comp_lat, 0.0, clampf(agarre_lateral * delta, 0.0, 1.0))
			comp_fwd = move_toward(comp_fwd, rapidez_actual, (speed_max / 1.1) * delta)
		else:
			# Derrape en curva: fricción lateral controlada con deslizamiento hacia afuera
			comp_lat = lerpf(comp_lat, 0.0, clampf(agarre_derrape * delta, 0.0, 1.0))
			var slide_target = -signf(volante_curva) * minf(absf(rapidez_actual) * 0.38, 8.5)
			comp_lat = lerpf(comp_lat, slide_target, clampf(3.2 * delta, 0.0, 1.0))
			comp_fwd = lerpf(comp_fwd, rapidez_actual * 0.93, clampf(4.5 * delta, 0.0, 1.0))
	else:
		# Conducción normal con agarre total
		comp_lat = lerpf(comp_lat, 0.0, clampf(agarre_lateral * delta, 0.0, 1.0))
		comp_fwd = lerpf(comp_fwd, rapidez_actual, clampf(agarre_lateral * delta, 0.0, 1.0))
	
	comp_lateral_actual = comp_lat
	intensidad_derrape = 0.9 if (esta_derrapando and absf(volante_actual) < 0.1 and absf(rapidez_actual) > 2.0) else clampf(absf(comp_lat) / maxf(absf(comp_fwd) * 0.4, 2.5), 0.0, 1.0)
	
	var nueva_vel: Vector3 = v_fwd * comp_fwd + v_lat * comp_lat
	avance.x = nueva_vel.x
	avance.z = nueva_vel.z
	velocity.x = nueva_vel.x + empuje.x
	velocity.z = nueva_vel.z + empuje.z
	
	# Pegado firme al suelo: en pendientes, bajadas y crestas el carro sigue la superficie y no "flota"
	if sobre_pista and dist_piso < 2.5 and normal_piso.y > 0.25:
		var vel_y_pendiente = -(normal_piso.x * velocity.x + normal_piso.z * velocity.z) / normal_piso.y
		if is_on_floor():
			velocity.y = vel_y_pendiente
		else:
			# Si está cerca del piso pero perdiendo contacto en bajada, lo succiona a la pista
			velocity.y = minf(velocity.y, vel_y_pendiente) - (dist_piso * 8.0)
	elif is_on_floor():
		velocity.y = nueva_vel.y
	# 7. ANIMACIÓN E INTERPOLACIÓN DE LAS 4 LLANTAS SEPARADAS
	if radio_rueda > 0.01:
		rotacion_rodaje -= (rapidez_actual / radio_rueda) * delta
	
	if rueda_del_izq:
		rueda_del_izq.rotation = Vector3(rotacion_rodaje, angulo_ruedas_actual, 0.0)
	if rueda_del_der:
		rueda_del_der.rotation = Vector3(rotacion_rodaje, angulo_ruedas_actual, 0.0)
	if rueda_tras_izq:
		rueda_tras_izq.rotation = Vector3(rotacion_rodaje, 0.0, 0.0)
	if rueda_tras_der:
		rueda_tras_der.rotation = Vector3(rotacion_rodaje, 0.0, 0.0)
	
	# 8. INTERPOLACIÓN DEL BALANCEO DE CARROCERÍA (Suspensión activa con lerpf)
	if modelo_nodo:
		# Roll: inclinación lateral centrífuga en curvas y derrapes
		var factor_roll = 1.35 if esta_derrapando else 1.0
		var roll_obj = clampf(-volante_curva * (rapidez_actual / speed_caminar) * 0.05 * factor_roll, -0.09, 0.09)
		roll_chasis = lerpf(roll_chasis, roll_obj, clampf(suavizado_suspension * delta, 0.0, 1.0))
		
		# Pitch: cabeceo al acelerar (squat), frenar (dive) o freno de mano
		var pitch_obj = 0.0
		if acelerar:
			pitch_obj = -0.03 if not corre else -0.05
		elif (frenar or (tecla_derrape and absf(volante_actual) < 0.2)) and absf(rapidez_actual) > 1.0:
			pitch_obj = 0.04
		pitch_chasis = lerpf(pitch_chasis, pitch_obj, clampf(suavizado_suspension * delta, 0.0, 1.0))
		
		modelo_nodo.rotation = Vector3(pitch_chasis, PI, roll_chasis)
	
	# Ejecutar movimiento físico
	move_and_slide()
	
	# Empuje físico dinámico a obstáculos (conos RigidBody3D)
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider is RigidBody3D:
			if collider.has_method("al_chocar"):
				collider.al_chocar(self)
			else:
				var dir_empuje := -col.get_normal()
				var fuerza := maxf(velocity.length(), 10.0) * 3.5
				collider.apply_central_impulse(dir_empuje * fuerza + Vector3(0, 3.5, 0))
	if sobre_pista and dist_piso < 2.5:
		apply_floor_snap()
		if is_on_floor() and velocity.y > 0.0 and normal_piso.y > 0.3:
			velocity.y = minf(velocity.y, 0.0)
	var antes = estado
	estado = elegir_estado()
	kmh = VELOCIDAD_KMH[estado]
	if estado != antes:
		print("estado ", Estado.keys()[estado], " · rapidez máxima ", kmh, " km/h = ", snappedf(kmh / 3.6, 0.01), " m/s")
		animar()
	
	# 9. CONTROL DIRECTO DEL SONIDO DE DERRAPE (Derrape_Rally.mp3 en el momento exacto)
	if sonido_derrape and sonido_derrape.stream:
		var en_freno_mano = tecla_derrape and absf(rapidez_actual) > 1.2
		var en_derrape_curva = esta_derrapando and (absf(comp_lateral_actual) > 0.6 or intensidad_derrape > 0.15)
		var debe_sonar = is_on_floor() and (en_freno_mano or en_derrape_curva)
		
		if debe_sonar:
			if not sonido_derrape.playing:
				sonido_derrape.play()
			if sonido_derrape.volume_db < -25.0:
				sonido_derrape.volume_db = -10.0 # Ataque sonoro instantáneo en el momento justo
			
			var factor_vel = clampf(absf(rapidez_actual) / 22.0, 0.25, 1.0)
			var boost_mano = 3.0 if en_freno_mano else 0.0
			var target_vol = lerpf(-4.0, 3.5, factor_vel) + boost_mano
			sonido_derrape.volume_db = lerpf(sonido_derrape.volume_db, target_vol, clampf(delta * 18.0, 0.0, 1.0))
			sonido_derrape.pitch_scale = lerpf(0.96, 1.15, factor_vel)
		else:
			sonido_derrape.volume_db = lerpf(sonido_derrape.volume_db, -80.0, clampf(delta * 12.0, 0.0, 1.0))
			if sonido_derrape.volume_db < -50.0 and sonido_derrape.playing:
				sonido_derrape.stop()
	
	_prueba()

@export var duracion_mejora := 8.0 # s que dura el extra de velocidad de cada esfera verde (el alerón se desvanece con él)
var mejoras: Array = [] # km/h de cada esfera verde recogida (la última se pierde al reaparecer)
var piezas: Array = [] # alerones visibles, uno por mejora
var mejoras_t: Array = [] # segundos que le quedan a cada mejora
var mejoras_ap: Array = [] # m/s que cada mejora está sumando ahora mismo (baja poco a poco hasta 0)
var mats_aleron: Array = [] # materiales de cada alerón (para desvanecerlos)

# La mejora se va gastando: el extra de velocidad baja linealmente y el alerón se desvanece
# encogiéndose y parpadeando en los últimos segundos hasta desaparecer.
func _actualizar_mejoras(delta: float) -> void:
	var i := mejoras_t.size() - 1
	while i >= 0:
		mejoras_t[i] -= delta
		var f := clampf(mejoras_t[i] / duracion_mejora, 0.0, 1.0)
		var objetivo: float = float(mejoras[i]) / 3.6 * f
		var d: float = objetivo - float(mejoras_ap[i])
		speed_caminar += d
		speed_correr += d
		mejoras_ap[i] = objetivo
		
		# Feedback visual inconfundible del alerón
		var pieza = piezas[i]
		if is_instance_valid(pieza):
			# En los últimos 2.5s parpadea avisando que se apaga
			if mejoras_t[i] < 2.5:
				var parpadeo := sin(Time.get_ticks_msec() * 0.025) > 0.0
				pieza.visible = parpadeo
			else:
				pieza.visible = true
			# Encogimiento suave progresivo para que se vea cómo se desvanece
			var escala := clampf(f * 1.25, 0.05, 1.0)
			pieza.scale = Vector3(escala, escala, escala)
			
		for mat in mats_aleron[i]:
			if mat is StandardMaterial3D:
				var c: Color = mat.albedo_color
				c.a = f
				mat.albedo_color = c
				mat.emission = Color(0.0, 1.0, 0.25) * f
				mat.emission_energy_multiplier = 2.5 * f
				
		if mejoras_t[i] <= 0.0:
			var pieza_fin = piezas[i]
			if is_instance_valid(pieza_fin):
				pieza_fin.queue_free()
			mejoras.remove_at(i)
			piezas.remove_at(i)
			mejoras_t.remove_at(i)
			mejoras_ap.remove_at(i)
			mats_aleron.remove_at(i)
			print("[mejora] el alerón se desvaneció: base ", snappedf(speed_caminar * 3.6, 0.1), " km/h")
		i -= 1

# Esfera verde (Documento de concepto, mecánica 1): +15 km/h de velocidad máxima y una pieza visible (alerón)
func aplicar_mejora(kmh_extra: float) -> void:
	mejoras.append(kmh_extra)
	mejoras_t.append(duracion_mejora)
	mejoras_ap.append(kmh_extra / 3.6)
	speed_caminar += kmh_extra / 3.6
	speed_correr += kmh_extra / 3.6
	
	# Construir alerón deportivo estilizado (soporte + alerón)
	var contenedor := Node3D.new()
	contenedor.name = "Aleron_%d" % piezas.size()
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.25) # Verde Neón Esmeralda Puro
	mat.emission_enabled = true
	mat.emission = Color(0.0, 1.0, 0.25)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Ala principal
	var ala := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.06, 0.45)
	ala.mesh = bm
	ala.material_override = mat
	ala.position = Vector3(0.0, 0.22, 0.0)
	contenedor.add_child(ala)
	
	# Soportes laterales
	var mat_soporte := StandardMaterial3D.new()
	mat_soporte.albedo_color = Color(0.1, 0.12, 0.14)
	mat_soporte.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for lado in [-0.5, 0.5]:
		var soporte := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.06, 0.24, 0.12)
		soporte.mesh = sm
		soporte.material_override = mat_soporte
		soporte.position = Vector3(lado, 0.11, 0.0)
		contenedor.add_child(soporte)
		
	# Aletas laterales verticales
	for lado in [-0.75, 0.75]:
		var aleta := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.04, 0.15, 0.5)
		aleta.mesh = am
		aleta.material_override = mat
		aleta.position = Vector3(lado, 0.25, 0.0)
		contenedor.add_child(aleta)
	
	add_child(contenedor)
	# Posicionado sobre el maletero trasero
	contenedor.position = Vector3(0.0, 1.05 + 0.15 * piezas.size(), 1.65)
	piezas.append(contenedor)
	mats_aleron.append([mat, mat_soporte])
	
	# Destello blanco de 0.3s (Documento de concepto: "destello blanco de 0.3s en la pieza recién instalada")
	var destello := StandardMaterial3D.new()
	destello.albedo_color = Color(1.0, 1.0, 1.0)
	destello.emission_enabled = true
	destello.emission = Color(1.0, 1.0, 1.0)
	destello.emission_energy_multiplier = 4.0
	ala.material_override = destello
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func(): if is_instance_valid(ala): ala.material_override = mat)
	
	# Efecto de sonido al recoger la esfera de mejora (Chime arcade suave y limpio)
	var snd := AudioStreamPlayer.new()
	var s_path := "res://Sonidos_Carros/CarroRally_Personaje/mejora_pickup.wav"
	if ResourceLoader.exists(s_path):
		snd.stream = load(s_path)
		snd.pitch_scale = 1.0
		snd.volume_db = -12.0
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)
	
	print("[mejora] esfera verde recogida -> velocidad máxima base ", snappedf(speed_caminar * 3.6, 0.1), " km/h")

# Reaparición (mecánica 5): pierde la última pieza obtenida
func quitar_ultima_mejora() -> void:
	if mejoras.is_empty():
		return
	mejoras.pop_back()
	mejoras_t.pop_back()
	mats_aleron.pop_back()
	var ap_ms: float = mejoras_ap.pop_back() # lo que ese alerón sumaba en este momento
	speed_caminar -= ap_ms
	speed_correr -= ap_ms
	var pieza = piezas.pop_back()
	if is_instance_valid(pieza):
		pieza.queue_free()
	print("[mejora] pierde la última pieza: base ", snappedf(speed_caminar * 3.6, 0.1), " km/h")

func elegir_estado():
	var rapidez = Vector2(velocity.x, velocity.z).length()
	if rapidez < 0.1:
		return Estado.QUIETO
	if rapidez > speed_caminar + 0.1:
		return Estado.NITRO
	return Estado.ANDANDO

func animar():
	if accion != "":
		_reproducir(accion)
		return
	match estado:
		Estado.QUIETO:
			_reproducir("idle")
		Estado.ANDANDO:
			_reproducir("walk")
		Estado.NITRO:
			_reproducir("sprint")

func _reproducir(nombre):
	if anim and anim.has_animation(nombre):
		anim.play(nombre)

# ================================================================
# SISTEMA DE COHETE
# ================================================================

## Llamado desde pista.gd (_on_esfera_cohete) cuando el jugador recoge
## una esfera roja de combate. Puede almacenar hasta 3 cohetes.
func recoger_cohete() -> void:
	if cohetes_cargados >= 3:
		return
	cohetes_cargados += 1
	_montar_cohete_visual()
	_sonido_equipado()
	print("[cohete] recogido – cargados: ", cohetes_cargados)

## Llamado por _actualizar_cohete cada frame; gestiona la tecla E.
func _actualizar_cohete(_delta: float) -> void:
	var disparo_ok := false
	if jugador_id == 2:
		disparo_ok = (
			Input.is_key_pressed(KEY_KP_2) 
			or Input.is_key_pressed(KEY_2) 
			or Input.is_key_pressed(KEY_B) 
			or Input.is_key_pressed(KEY_COMMA) 
			or Input.is_key_pressed(KEY_PERIOD)
		)
		# Detectar just_pressed manualmente para evitar disparo continuo
		if disparo_ok and not _cohete_tecla_previa:
			_cohete_tecla_previa = true
			_disparar_cohete()
		elif not disparo_ok:
			_cohete_tecla_previa = false
	else:
		if Input.is_action_just_pressed("disparar_cohete"):
			_disparar_cohete()

func _disparar_cohete() -> void:
	if cohetes_cargados <= 0:
		return
	cohetes_cargados -= 1

	# Crear proyectil en la posición frontal del carro
	var p = COHETE_SCN.instantiate()
	p.inicializar(self)
	get_tree().root.add_child(p)

	# Posicionar en el morro/techo, apuntando hacia adelante del carro
	p.global_transform = global_transform
	p.global_position = global_position + (-global_transform.basis.z * 2.2) + Vector3(0, 0.9, 0)

	# Sonido de disparo (en el mundo para que tenga atenuación espacial)
	var snd_path := "res://Sonidos_Armas/cohete_disparo.mp3"
	if ResourceLoader.exists(snd_path):
		var snd := AudioStreamPlayer3D.new()
		snd.stream = load(snd_path)
		snd.volume_db = 2.0
		snd.max_distance = 60.0
		get_tree().root.add_child(snd)
		snd.global_position = global_position
		snd.play()
		snd.finished.connect(snd.queue_free)

	# Actualizar o quitar el cohete montado en el techo
	if cohetes_cargados <= 0:
		_desmontar_cohete_visual()
	print("[cohete] ¡DISPARADO! restantes: ", cohetes_cargados)

## Llamado por proyectil_cohete cuando impacta a este jugador.
func recibir_impacto() -> void:
	_impacto_t = _impacto_dura
	# Detener carro bruscamente
	rapidez_actual = minf(rapidez_actual * 0.15, 3.0)
	velocity = velocity * 0.1
	velocity.y = 5.0
	floor_snap_length = 0.0
	# Trompo del modelo
	_animar_trompo_impacto()
	# Partículas de daño
	_generar_particulas_danio()
	# Sonido de impacto
	_sonido_impacto_jugador()
	print("[cohete] ¡Jugador ", jugador_id, " impactado! Trompo ", _impacto_dura, "s")

func _animar_trompo_impacto() -> void:
	var mod := get_node_or_null("Modelo")
	if not mod:
		return
	var tw := create_tween()
	var orig_y: float = mod.rotation_degrees.y
	tw.set_parallel(true)
	tw.tween_property(mod, "rotation_degrees:y", orig_y + 720.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mod, "rotation_degrees:z", 28.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(mod, "rotation_degrees:z", -16.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(mod, "rotation_degrees:z", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.0).timeout
	floor_snap_length = pegado_al_suelo

func _generar_particulas_danio() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 24
	p.lifetime = 0.8
	p.direction = Vector3.UP
	p.spread = 55.0
	p.gravity = Vector3(0, -4.0, 0)
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.22
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.35, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.0)
	mat.emission_energy_multiplier = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = mat
	p.mesh = q
	p.position = Vector3(0, 0.6, 0)
	add_child(p)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
	)

func _sonido_impacto_jugador() -> void:
	var snd_path := "res://Sonidos_Armas/cohete_impacto.mp3"
	if ResourceLoader.exists(snd_path):
		var snd := AudioStreamPlayer3D.new()
		snd.stream = load(snd_path)
		snd.volume_db = 1.0
		snd.max_distance = 60.0
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)

## Montar el modelo visual del cohete sobre el techo del carro.
## Solo muestra un cohete (el primero); si ya hay uno montado no duplica.
func _montar_cohete_visual() -> void:
	if is_instance_valid(_cohete_montado):
		return # ya hay uno visible
	var path := "res://Modelos_Armas/cohete.glb"
	if not ResourceLoader.exists(path):
		return
	var scn = load(path)
	if scn == null:
		return
	_cohete_montado = scn.instantiate()
	add_child(_cohete_montado)
	# El GLB ya tiene los nodos internos posicionados en Blender:
	#   Cohete -> Y=1.575, Z=-0.3 (techo del carro, levemente hacia el centro)
	#   Soporte_Techo -> Y=1.425, Z=-0.3
	# Colocamos el raíz en el origen del Personaje y rotamos 180° en Y para que apunte hacia -Z (adelante).
	_cohete_montado.position = Vector3(0.0, 0.0, 0.0)
	_cohete_montado.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	print("[cohete] modelo montado en el techo")

func _desmontar_cohete_visual() -> void:
	if is_instance_valid(_cohete_montado):
		_cohete_montado.queue_free()
		_cohete_montado = null

func _sonido_equipado() -> void:
	var snd_path := "res://Sonidos_Armas/cohete_equipado.mp3"
	if not ResourceLoader.exists(snd_path):
		return
	if is_instance_valid(_snd_equipado):
		_snd_equipado.stop()
		_snd_equipado.queue_free()
	_snd_equipado = AudioStreamPlayer.new()
	_snd_equipado.stream = load(snd_path)
	_snd_equipado.volume_db = -8.0
	add_child(_snd_equipado)
	_snd_equipado.play()
	_snd_equipado.finished.connect(_snd_equipado.queue_free)

# ---------------- Prueba automática ----------------
var _cuadro = 0
var _terminada = false
var _estados_previos = {}

func _plan(f):
	# devuelve [w, d, accion, total] para el cuadro f
	match prueba:
		"Avanzar 60 cuadros":
			return [f <= 60, false, false, 60]
		"Avanzar 60 y soltar":
			return [f <= 60, false, false, 90]
		"Avanzar y la acción desde el cuadro 30":
			return [f <= 90, false, f >= 31, 90]
		"Mantener la acción 2 s":
			return [false, false, f <= 120, 120]
		"Avanzar con la acción 60 cuadros":
			return [f <= 60, false, f <= 60, 60]
		"Diagonal W+D 60 cuadros":
			return [f <= 60, f <= 60, false, 60]
	return [false, false, false, 0]

func _set_accion(nombre, presionada):
	if nombre == "" or not InputMap.has_action(nombre):
		return
	if presionada:
		Input.action_press(nombre)
	else:
		Input.action_release(nombre)

func _aplicar_prueba(f):
	var p = _plan(f)
	_set_accion("move_up", p[0])
	_set_accion("move_right", p[1])
	_set_accion(accion_prueba, p[2])

func _nombre_estado(nodo, valor):
	if nodo == self:
		return Estado.keys()[valor]
	var scr = nodo.get_script()
	if scr:
		var mapa = scr.get_script_constant_map()
		if mapa.has("Estado"):
			var clave = mapa["Estado"].find_key(valor)
			if clave != null:
				return clave
	return str(valor)

func _prueba():
	if prueba == "Ninguna":
		_cuadro = 0
		_terminada = false
		_estados_previos.clear()
		return
	if _terminada:
		return
	
	if _cuadro == 0:
		if prueba.contains("acción") and accion_prueba == "":
			print("[prueba] escriban el nombre de la acción en 'Accion Prueba'")
		elif accion_prueba != "" and not InputMap.has_action(accion_prueba):
			print("[prueba] falta la acción '", accion_prueba, "' en el Input Map")
	
	_cuadro += 1
	var total = _plan(_cuadro)[3]
	
	# cambios de estado (del Personaje y de sus nodos hijos que tengan 'estado')
	var nodos = [self]
	nodos.append_array(get_children())
	for n in nodos:
		if "estado" in n:
			var previo = _estados_previos.get(n.name, null)
			if previo != null and previo != n.estado:
				print("[prueba] cuadro ", _cuadro, ": ", n.name, ".estado cambia a ", _nombre_estado(n, n.estado))
			_estados_previos[n.name] = n.estado
	
	var mostrar = [1, 2, 3, 5, 10, 15, 20, 30, 31, 32, 35, 40, 45, 50, 59, 60, 61, 62, 65, 70, 75, 80, 90, 120]
	if _cuadro in mostrar or _cuadro == total:
		var rapidez = Vector2(velocity.x, velocity.z).length()
		var p = global_position
		var nombre_anim = anim.current_animation if anim else "-"
		print("[prueba] cuadro ", _cuadro, ": posición (", snappedf(p.x, 0.01), ", ", snappedf(p.y, 0.01), ", ", snappedf(p.z, 0.01),
			") · rapidez ", snappedf(rapidez, 0.01), " · y ", snappedf(p.y, 0.01), " · animación ", nombre_anim, " · Personaje.estado ", Estado.keys()[estado])
	
	if _cuadro >= total:
		_set_accion("move_up", false)
		_set_accion("move_right", false)
		_set_accion(accion_prueba, false)
		print("[prueba] fin. Dejen Prueba en Ninguna.")
		_terminada = true
	else:
		_aplicar_prueba(_cuadro + 1)

extends CharacterBody3D

# ---- Nivel 3: estados con un número cada uno (CustomVeloz) ----
enum Estado { QUIETO, ANDANDO, NITRO }
# El número de cada estado es su rapidez máxima en km/h, en el orden del enum
const VELOCIDAD_KMH = [0.0, 90.0, 120.0]

# ---- Nivel 1 y 2: rapidez y arranque (números del juego, ver tabla del Taller 7) ----
@export var camara: Camera3D
@export var speed_caminar = 25.0 # 90 km/h ÷ 3.6 = 25 m/s (rapidez máxima de base)
@export var speed_correr = 33.33 # 120 km/h ÷ 3.6 = 33.33 m/s (con nitro, tecla Shift)
@export var tiempo_arranque = 3.0 # s en llegar a la rapidez máxima

@export var estado := Estado.QUIETO

@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s", "Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba: String = "Ninguna"
@export var accion_prueba = ""

# ---- Ajustes de Manejo e Interpolación del Carro ----
@export_group("Manejo e Interpolación")
@export var velocidad_giro: float = 2.4 # Radianes/s de rotación al voltear
@export var suavizado_volante: float = 12.0 # Factor de interpolación (lerpf) para la dirección
@export var max_angulo_ruedas: float = 0.50 # ~28° ángulo máximo de dirección de ruedas
@export var agarre_lateral: float = 8.0 # Factor de interpolación (lerpf) para agarre en curvas
@export var agarre_derrape: float = 2.5 # Agarre reducido durante el derrape (Barra Espaciadora)
@export var suavizado_suspension: float = 8.5 # Factor de interpolación (lerpf) de la suspensión
@export var radio_rueda: float = 0.35 # Radio estimado de llanta para rodamiento realista

# Los tres enchufes (otros scripts los cambian; no se borran)
var multiplicador = 1.0 # 1 = normal, 0.5 = mitad, 0 = quieto
var empuje = Vector3.ZERO # m/s que se suman (dash, retroceso)
var accion = "" # nombre de una animación que pisa idle/walk

var avance = Vector3.ZERO # la parte de la velocidad que dan las teclas
var nitro_ok = true # lo pone el nodo Nitro: false si no queda carga
var corre = false # true mientras Shift está presionada y hay nitro
var kmh = 0.0 # rapidez máxima del estado actual

# Referencias a componentes y ruedas
@onready var modelo_nodo: Node3D = get_node_or_null("Modelo")
@onready var anim = get_node_or_null("Modelo/AnimationPlayer")

var rueda_del_izq: Node3D = null # wheels_019
var rueda_del_der: Node3D = null # wheels_040
var rueda_tras_izq: Node3D = null # wheels_018
var rueda_tras_der: Node3D = null # wheels_041

# Estados internos de interpolación
var rapidez_actual: float = 0.0
var volante_actual: float = 0.0
var angulo_ruedas_actual: float = 0.0
var rotacion_rodaje: float = 0.0
var roll_chasis: float = 0.0
var pitch_chasis: float = 0.0

func _ready():
	if camara == null:
		camara = get_viewport().get_camera_3d()
	
	_buscar_ruedas()
	
	if prueba != "Ninguna":
		_aplicar_prueba(1)

func _buscar_ruedas() -> void:
	if not modelo_nodo:
		return
	
	# Búsqueda directa por jerarquía conocida
	rueda_del_izq = modelo_nodo.get_node_or_null("rally/wheels_019")
	rueda_del_der = modelo_nodo.get_node_or_null("rally/wheels_040")
	rueda_tras_izq = modelo_nodo.get_node_or_null("rally/wheels_018")
	rueda_tras_der = modelo_nodo.get_node_or_null("rally/wheels_041")
	
	# Búsqueda de respaldo recursiva si cambian los nombres o jerarquía
	if not rueda_del_izq or not rueda_del_der:
		for c in modelo_nodo.find_children("*wheel*", "Node3D", true, false):
			var n = c.name.to_lower()
			if "19" in n:
				rueda_del_izq = c
			elif "40" in n:
				rueda_del_der = c
			elif "18" in n:
				rueda_tras_izq = c
			elif "41" in n:
				rueda_tras_der = c

func _physics_process(delta):
	# Gravedad estándar
	velocity += get_gravity() * delta
	
	if camara == null:
		camara = get_viewport().get_camera_3d()
	
	# Entradas de control
	var input_x = Input.get_axis("move_left", "move_right")
	var acelerar = Input.is_action_pressed("move_up")
	var frenar = Input.is_action_pressed("move_down")
	var derrapando = Input.is_action_pressed("derrapar") if InputMap.has_action("derrapar") else Input.is_key_pressed(KEY_SPACE)
	
	corre = Input.is_action_pressed("correr") and nitro_ok
	var speed_max = speed_correr if corre else speed_caminar
	speed_max *= multiplicador
	
	# 1. INTERPOLACIÓN DEL VOLANTE (Entrada suavizada con lerpf)
	volante_actual = lerpf(volante_actual, input_x, clampf(suavizado_volante * delta, 0.0, 1.0))
	
	# 2. INTERPOLACIÓN DEL ÁNGULO DE LAS RUEDAS DELANTERAS (lerpf)
	# Al doblar hacia la derecha (input_x > 0), el ángulo orienta las ruedas hacia la derecha
	var angulo_obj = -volante_actual * max_angulo_ruedas
	angulo_ruedas_actual = lerpf(angulo_ruedas_actual, angulo_obj, clampf(suavizado_volante * delta, 0.0, 1.0))
	
	# 3. ACELERACIÓN, FRENADO Y MARCHA ATRÁS
	var tasa_acel = speed_max / maxf(tiempo_arranque, 0.05)
	if acelerar:
		rapidez_actual = move_toward(rapidez_actual, speed_max, tasa_acel * delta)
	elif frenar:
		if rapidez_actual > 0.5:
			# Frenada enérgica hacia 0
			rapidez_actual = move_toward(rapidez_actual, 0.0, (speed_max / 0.75) * delta)
		else:
			# Reversa controlada
			rapidez_actual = move_toward(rapidez_actual, -speed_max * 0.35, (speed_max / 1.8) * delta)
	else:
		# Desaceleración natural por rozamiento
		rapidez_actual = move_toward(rapidez_actual, 0.0, (speed_max / 3.5) * delta)
	
	# 4. INTERPOLACIÓN DEL GIRO / ROTACIÓN DEL VEHÍCULO
	# El giro es proporcional a la velocidad (un carro no gira quieto en su propio eje)
	var factor_velocidad_giro = clampf(absf(rapidez_actual) / maxf(speed_caminar * 0.25, 1.0), 0.15, 1.0)
	var signo_direccion = -1.0 if rapidez_actual < -0.1 else 1.0
	var delta_giro = -volante_actual * velocidad_giro * factor_velocidad_giro * signo_direccion * delta
	rotate_y(delta_giro)
	
	# 5. ADAPTACIÓN SUAVE A LA INCLINACIÓN DEL SUELO (Rampas de zona_c)
	var n = get_floor_normal() if is_on_floor() else Vector3.UP
	if n.y < 0.2:
		n = Vector3.UP
	var up_actual = transform.basis.y
	var up_suave = up_actual.lerp(n, clampf(10.0 * delta, 0.0, 1.0)).normalized()
	var adelante_vector = -transform.basis.z
	adelante_vector = (adelante_vector - up_suave * adelante_vector.dot(up_suave)).normalized()
	if adelante_vector.length_squared() > 0.001:
		var lateral = up_suave.cross(adelante_vector).normalized()
		transform.basis = Basis(lateral, up_suave, -adelante_vector).orthonormalized()
	
	# 6. VELOCIDAD Y AGARRE LATERAL / DERRAPE (Interpolación lerpf)
	var adelante_objetivo = -transform.basis.z * rapidez_actual
	avance.x = adelante_objetivo.x
	avance.z = adelante_objetivo.z
	
	var agarre = agarre_derrape if derrapando else agarre_lateral
	velocity.x = lerpf(velocity.x, avance.x + empuje.x, clampf(agarre * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, avance.z + empuje.z, clampf(agarre * delta, 0.0, 1.0))
	
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
		# Roll: inclinación lateral centrífuga en curvas
		var roll_obj = clampf(-volante_actual * (rapidez_actual / speed_caminar) * 0.05, -0.07, 0.07)
		roll_chasis = lerpf(roll_chasis, roll_obj, clampf(suavizado_suspension * delta, 0.0, 1.0))
		
		# Pitch: cabeceo al acelerar (squat) o frenar (dive)
		var pitch_obj = 0.0
		if acelerar:
			pitch_obj = -0.03 if not corre else -0.05
		elif frenar and rapidez_actual > 1.0:
			pitch_obj = 0.035
		pitch_chasis = lerpf(pitch_chasis, pitch_obj, clampf(suavizado_suspension * delta, 0.0, 1.0))
		
		modelo_nodo.rotation = Vector3(pitch_chasis, PI, roll_chasis)
	
	# Ejecutar movimiento físico
	move_and_slide()
	
	# Máquina de estados oficial
	var antes = estado
	estado = elegir_estado()
	kmh = VELOCIDAD_KMH[estado]
	if estado != antes:
		print("estado ", Estado.keys()[estado], " · rapidez máxima ", kmh, " km/h = ", snappedf(kmh / 3.6, 0.01), " m/s")
		animar()
	
	_prueba()

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

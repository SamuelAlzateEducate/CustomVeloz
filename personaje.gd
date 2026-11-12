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

# Los tres enchufes (otros scripts los cambian; no se borran)
var multiplicador = 1.0 # 1 = normal, 0.5 = mitad, 0 = quieto
var empuje = Vector3.ZERO # m/s que se suman (dash, retroceso)
var accion = "" # nombre de una animación que pisa idle/walk

var avance = Vector3.ZERO # la parte de la velocidad que dan las teclas
var nitro_ok = true # lo pone el nodo Nitro: false si no queda carga
var corre = false # true mientras Shift está presionada y hay nitro
var kmh = 0.0 # rapidez máxima del estado actual

@onready var anim = get_node_or_null("Modelo/AnimationPlayer")

func _ready():
	if camara == null:
		camara = get_viewport().get_camera_3d()
	if prueba != "Ninguna":
		_aplicar_prueba(1)

func _physics_process(delta):
	velocity += get_gravity() * delta
	
	if camara == null:
		camara = get_viewport().get_camera_3d()
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var entrada = Vector3(input_dir.x, 0.0, input_dir.y)
	
	# La entrada se gira solo con el giro horizontal de la cámara
	var giro_cam = camara.global_rotation.y if camara else 0.0
	var direction = entrada.rotated(Vector3.UP, giro_cam).normalized()
	
	corre = Input.is_action_pressed("correr") and nitro_ok
	var speed = speed_correr if corre else speed_caminar
	
	# Arranque y frenado suaves
	var objetivo = direction * speed * multiplicador
	var paso = speed / maxf(tiempo_arranque, 0.05) * delta
	avance = avance.move_toward(objetivo, paso)
	
	velocity.x = avance.x + empuje.x
	velocity.z = avance.z + empuje.z
	
	if direction.length() > 0:
		var n = get_floor_normal() if is_on_floor() else Vector3.UP
		if n.y < 0.2:
			n = Vector3.UP
		var fwd = (direction - n * direction.dot(n)).normalized()
		if fwd.length_squared() > 0.001:
			basis = Basis.looking_at(fwd, n)
		else:
			basis = Basis.looking_at(direction)
	
	move_and_slide()
	
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

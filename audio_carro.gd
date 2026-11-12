class_name AudioCarro
extends Node

## Sistema de Sonido Realista de Rally para CustomVeloz
## - Simulación de caja de cambios de 6 velocidades con subida y caída de RPM
## - Motor agresivo y ronco con modulación dinámica de tono (pitch scale)
## - Sistema Antilag (ALS) y explosiones de escape (pops and bangs) al soltar gas o cambiar de marcha
## - Chillido de neumáticos en derrape (al girar fuerte o presionar barra espaciadora)

@export var activar_sonido := true

# 6 Velocidades (m/s): 25 m/s = 90 km/h, 33.3 m/s = 120 km/h (nitro)
const VELOCIDAD_MARCHAS = [
	Vector2(0.0, 6.0),    # 1ra: 0 a 22 km/h
	Vector2(5.0, 11.0),   # 2da: 18 a 40 km/h
	Vector2(9.5, 16.5),   # 3ra: 34 a 59 km/h
	Vector2(15.0, 22.0),  # 4ta: 54 a 79 km/h
	Vector2(20.5, 27.5),  # 5ta: 74 a 99 km/h
	Vector2(26.0, 36.0)   # 6ta: 94 a 130 km/h
]

@onready var pj: CharacterBody3D = get_parent()

var motor_rev: AudioStreamPlayer
var motor_idle: AudioStreamPlayer
var derrape: AudioStreamPlayer
var lista_pops: Array[AudioStreamPlayer] = []

var marcha_actual := 1
var rpm := 0.15 # 0.0 a 1.0 (ralentí a línea roja)
var acelerando_antes := false
var tiempo_corte_cambio := 0.0

# Ráfagas de antilag (ALS)
var pops_pendientes := 0
var temporizador_pop := 0.0

func _ready() -> void:
	if not activar_sonido:
		set_physics_process(false)
		return
	
	_crear_reproductores()

func _crear_reproductores() -> void:
	var path_base = "res://Sonidos_Carros/CarroRally_Personaje/"
	
	# 1. Motor acelerando (loop continuo)
	motor_rev = AudioStreamPlayer.new()
	motor_rev.name = "MotorRev"
	if ResourceLoader.exists(path_base + "motor_loop.wav"):
		motor_rev.stream = load(path_base + "motor_loop.wav")
	elif ResourceLoader.exists(path_base + "rally-1-1.mp3"):
		motor_rev.stream = load(path_base + "rally-1-1.mp3")
	motor_rev.volume_db = -80.0
	motor_rev.autoplay = false
	add_child(motor_rev)
	motor_rev.play()

	# 2. Motor ralentí (idle)
	motor_idle = AudioStreamPlayer.new()
	motor_idle.name = "MotorIdle"
	if ResourceLoader.exists(path_base + "motor_idle.wav"):
		motor_idle.stream = load(path_base + "motor_idle.wav")
	elif ResourceLoader.exists(path_base + "rally.mp3"):
		motor_idle.stream = load(path_base + "rally.mp3")
	motor_idle.volume_db = -3.0
	motor_idle.autoplay = false
	add_child(motor_idle)
	motor_idle.play()

	# 3. Derrape / Skid de neumáticos
	derrape = AudioStreamPlayer.new()
	derrape.name = "Derrape"
	if ResourceLoader.exists(path_base + "derrape_loop.wav"):
		derrape.stream = load(path_base + "derrape_loop.wav")
	elif ResourceLoader.exists(path_base + "Derrape_Rally.mp3"):
		derrape.stream = load(path_base + "Derrape_Rally.mp3")
	derrape.volume_db = -80.0
	derrape.autoplay = false
	add_child(derrape)
	derrape.play()

	# 4. Banco de explosiones / pops de escape (ALS)
	for i in range(1, 6):
		var p_path = path_base + "pop_als_%d.wav" % i
		if ResourceLoader.exists(p_path):
			var p = AudioStreamPlayer.new()
			p.name = "Pop_%d" % i
			p.stream = load(p_path)
			p.volume_db = 0.0
			add_child(p)
			lista_pops.append(p)

func _physics_process(delta: float) -> void:
	if not pj:
		return
	
	var vel_h = Vector2(pj.velocity.x, pj.velocity.z).length()
	var acelerando = Input.is_action_pressed("move_up")
	var frenando = Input.is_action_pressed("move_down")
	var nitro = pj.corre if "corre" in pj else false
	var direccion_giro = Input.get_axis("move_left", "move_right")
	var tecla_derrape = Input.is_action_pressed("derrapar") if InputMap.has_action("derrapar") else Input.is_key_pressed(KEY_SPACE)

	# --- 1. SIMULACIÓN DE MARCHAS (1 a 6) ---
	var rango = VELOCIDAD_MARCHAS[marcha_actual - 1]
	
	# Subir de marcha (Upshift)
	if marcha_actual < 6 and vel_h > rango.y:
		cambiar_marcha(marcha_actual + 1, true)
	# Reducir de marcha (Downshift)
	elif marcha_actual > 1 and vel_h < rango.x - 1.0:
		cambiar_marcha(marcha_actual - 1, false)

	# --- 2. CÁLCULO DE RPM Y RÉGIMEN DE REVOLUCIONES ---
	rango = VELOCIDAD_MARCHAS[marcha_actual - 1]
	var ratio_vel = clampf((vel_h - rango.x) / maxf(0.1, rango.y - rango.x), 0.0, 1.0)
	
	var rpm_objetivo = 0.15
	if acelerando:
		rpm_objetivo = lerpf(0.40, 1.0, ratio_vel)
		if nitro:
			rpm_objetivo = 1.18 # Sobrealimentación con nitro
	elif frenando:
		rpm_objetivo = maxf(0.15, ratio_vel * 0.6)
	else:
		# Al soltar el acelerador las RPM caen
		rpm_objetivo = maxf(0.15, ratio_vel * 0.45)
	
	var tasa_rpm = 4.2 if acelerando else 2.6
	rpm = move_toward(rpm, rpm_objetivo, tasa_rpm * delta)

	# --- 3. DETECCIÓN DE SOLTADA DE GAS -> ANTILAG (ALS) / POPS & BANGS ---
	if acelerando_antes and not acelerando and rpm > 0.45:
		pops_pendientes = randi_range(2, 4)
		temporizador_pop = randf_range(0.04, 0.10)

	acelerando_antes = acelerando

	# Procesar ráfaga de explosiones ALS
	if pops_pendientes > 0:
		temporizador_pop -= delta
		if temporizador_pop <= 0.0:
			disparar_pop_als()
			pops_pendientes -= 1
			temporizador_pop = randf_range(0.11, 0.19)

	# --- 4. MODULACIÓN DE TONO Y VOLUMEN DEL MOTOR ---
	if tiempo_corte_cambio > 0.0:
		tiempo_corte_cambio -= delta

	# Tono (Pitch Scale): desde 0.85 (ralentí ronco) hasta 1.82 (rugido a tope)
	var pitch_final = lerpf(0.85, 1.82, rpm)
	if nitro:
		pitch_final = 2.10
	if tiempo_corte_cambio > 0.0:
		pitch_final *= 0.87 # Caída momentánea en el cambio de marcha

	motor_rev.pitch_scale = lerpf(motor_rev.pitch_scale, pitch_final, delta * 14.0)

	# Control de volumen
	var factor_carga = clampf((vel_h / 5.0) + (0.45 if acelerando else 0.0), 0.0, 1.0)
	var vol_rev_db = lerpf(-22.0, 1.0, factor_carga)
	if acelerando:
		vol_rev_db += 2.0
	if nitro:
		vol_rev_db += 3.5
	motor_rev.volume_db = lerpf(motor_rev.volume_db, vol_rev_db, delta * 12.0)

	# Ralentí (suena más cuando el auto está detenido o a muy baja velocidad)
	var vol_idle_db = lerpf(0.0, -36.0, factor_carga)
	motor_idle.volume_db = lerpf(motor_idle.volume_db, vol_idle_db, delta * 8.0)
	motor_idle.pitch_scale = lerpf(0.95, 1.10, rpm * 0.4)

	# --- 5. AUDIO DE DERRAPE (CHILLIDO DE NEUMÁTICOS) ---
	var derrapando = (tecla_derrape and vel_h > 4.0) or (absf(direccion_giro) > 0.35 and vel_h > 11.0)
	if derrapando and pj.is_on_floor():
		var vol_skid = lerpf(-12.0, 3.0, clampf(vel_h / 25.0, 0.0, 1.0))
		derrape.volume_db = lerpf(derrape.volume_db, vol_skid, delta * 16.0)
		derrape.pitch_scale = lerpf(0.92, 1.20, clampf(vel_h / 25.0, 0.0, 1.0))
	else:
		derrape.volume_db = lerpf(derrape.volume_db, -80.0, delta * 10.0)

func cambiar_marcha(nueva: int, subiendo: bool) -> void:
	marcha_actual = nueva
	tiempo_corte_cambio = 0.08
	
	if subiendo:
		disparar_pop_als(0.95, 1.15)
	else:
		if randf() > 0.35:
			disparar_pop_als(0.85, 1.05)

func disparar_pop_als(p_min: float = 0.88, p_max: float = 1.18) -> void:
	if lista_pops.is_empty():
		return
	var p = lista_pops.pick_random()
	if p:
		p.pitch_scale = randf_range(p_min, p_max)
		p.volume_db = randf_range(0.0, 4.0)
		p.play()

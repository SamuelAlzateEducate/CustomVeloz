class_name AudioCarro
extends Node

## Sistema de Sonido Realista de Rally para CustomVeloz
## - Diseñado con las grabaciones reales de rally.mp3, rally-1-1.mp3 y rally-2.mp3
## - Ralentí profundo y muscular en reposo (64 Hz)
## - Rugido auténtico bajo carga al acelerar
## - Progresión natural de marchas: 1ra, 2da y 3ra para aceleración contundente (0 a 90 km/h)
## - 4ta de crucero y 5ta/6ta con modo Nitro (hasta 120+ km/h)
## - Sonido mecánico de cambio secuencial (cambio_marcha.wav) con corte de inyección
## - Cero ruidos extraños o 'pedos' en parado (anti-lag solo activo > 50 km/h en alta velocidad)
## - Soporte para cambios manuales opcionales con la rueda del ratón

@export var activar_sonido := true
@export var modo_manual := false # false = automático (por defecto), true = control manual

# Escalonamiento realista de velocidades (en m/s):
# 1ra: 0 a 34 km/h (arranque con empuje largo y audible)
# 2da: 29 a 61 km/h
# 3ra: 54 a 86 km/h
# 4ta: 79 a 102 km/h (crucero en velocidad máxima de base 90 km/h)
# 5ta: 97 a 122 km/h (Modo Nitro)
# 6ta: 115 a 140 km/h (Nitro a fondo)
const REV_START_OFFSET = 2.5

const VELOCIDAD_MARCHAS = [
	Vector2(0.0, 9.5),    # 1ra: 0 a 34 km/h
	Vector2(8.0, 17.0),   # 2da: 29 a 61 km/h
	Vector2(15.0, 24.0),  # 3ra: 54 a 86 km/h
	Vector2(22.0, 28.5),  # 4ta: 79 a 102 km/h
	Vector2(27.0, 34.0),  # 5ta: 97 a 122 km/h (Nitro)
	Vector2(32.0, 40.0)   # 6ta: 115 a 144 km/h (Nitro máximo)
]

# Tono (pitch) de entrada y salida por marcha:
# Al cambiar de marcha se percibe una caída de tono pronunciada y natural
const PITCH_MARCHAS = [
	Vector2(0.55, 0.88),  # 1ra
	Vector2(0.62, 0.92),  # 2da
	Vector2(0.66, 0.95),  # 3ra
	Vector2(0.68, 0.97),  # 4ta
	Vector2(0.70, 0.99),  # 5ta: Nitro
	Vector2(0.72, 1.00)   # 6ta: Nitro tope
]
# Cada marcha termina un poco más grave y la siguiente arranca ~10% más abajo:
# el tono ya no pega un salto grande al cambiar.
const PITCH_MAXIMO := 1.0

# Duración del cambio de marcha (el "bache" de volumen/tono es una curva suave)
const DURACION_CAMBIO := 0.30

@onready var pj: CharacterBody3D = get_parent()

var motor_rev: AudioStreamPlayer
var filtro_motor: AudioEffectLowPassFilter
var motor_idle: AudioStreamPlayer
var derrape: AudioStreamPlayer
var sonido_cambio: AudioStreamPlayer
var lista_pops: Array[AudioStreamPlayer] = []

var marcha_actual := 1
var rpm := 0.20 # 0.0 a 1.0
var acelerando_antes := false
var tiempo_corte_cambio := 0.0

# Sonido de ralentí/arranque: una vez al inicio, y en bucle solo con F en parado
var idle_stream_unica: AudioStream
var idle_stream_bucle: AudioStream
var idle_en_bucle := false

# Anti-lag (ALS)
var pops_pendientes := 0
var temporizador_pop := 0.0

func _ready() -> void:
	if not activar_sonido:
		set_physics_process(false)
		return
	_crear_reproductores()

func _wav_en_bucle(stream: AudioStreamWAV) -> AudioStreamWAV:
	# loop_end = -1 solo sirve en el importador; en runtime hay que poner el
	# final real en muestras, si no el bucle queda roto y no suena nada.
	var s := stream.duplicate() as AudioStreamWAV
	var muestras := int(round(s.get_length() * float(s.mix_rate)))
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = maxi(muestras, 1)
	return s

func _configurar_stream_en_bucle(stream: Resource) -> Resource:
	if stream is AudioStreamWAV:
		return _wav_en_bucle(stream)
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream

func _crear_reproductores() -> void:
	var path_base = "res://Sonidos_Carros/CarroRally_Personaje/"
	
	# 1. Motor acelerando (loop continuo con la grabación real de aceleración)
	motor_rev = AudioStreamPlayer.new()
	motor_rev.name = "MotorRev"
	var rev_path = path_base + "motor_rev.wav"
	if ResourceLoader.exists(rev_path):
		var rev_stream = load(rev_path)
		if rev_stream is AudioStreamWAV:
			motor_rev.stream = _wav_en_bucle(rev_stream)
			print("[audio_carro] motor_rev WAV cargado con bucle, muestras: ", motor_rev.stream.loop_end)
		else:
			motor_rev.stream = rev_stream
			print("[audio_carro] motor_rev loaded (non‑WAV)" )
	else:
		push_error("[audio_carro] motor_rev.wav not found at " + rev_path)
		# fallback to the original loop file to avoid crash
		if ResourceLoader.exists(path_base + "motor_loop.wav"):
			motor_rev.stream = _configurar_stream_en_bucle(load(path_base + "motor_loop.wav"))
			print("[audio_carro] fallback to motor_loop.wav")
	# Bus propio del motor con filtro pasa-bajos: recorta los agudos chillones
	var bus_idx := AudioServer.get_bus_index("MotorCarro")
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "MotorCarro")
		AudioServer.set_bus_send(bus_idx, "Master")
		var filtro := AudioEffectLowPassFilter.new()
		filtro.cutoff_hz = 3200.0
		filtro.db = AudioEffectFilter.FILTER_24DB # corte más fuerte: quita el "chillido"
		AudioServer.add_bus_effect(bus_idx, filtro)
		# Limitador suave: evita que los picos del motor se distorsionen/saturen
		var limitador := AudioEffectLimiter.new()
		limitador.ceiling_db = -2.0
		limitador.threshold_db = -6.0
		limitador.soft_clip_db = 2.0
		AudioServer.add_bus_effect(bus_idx, limitador)
	filtro_motor = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectLowPassFilter
	motor_rev.bus = "MotorCarro"
	motor_rev.volume_db = -30.0
	motor_rev.autoplay = false
	add_child(motor_rev)
	# se reproducirá al acelerar



	# 2. Motor ralentí (loop continuo con la grabación real de ralentí 64 Hz)
	motor_idle = AudioStreamPlayer.new()
	motor_idle.name = "MotorIdle"
	if ResourceLoader.exists(path_base + "motor_idle.wav"):
		idle_stream_unica = load(path_base + "motor_idle.wav") # sin bucle: suena una vez
		idle_stream_bucle = _configurar_stream_en_bucle(load(path_base + "motor_idle.wav"))
		motor_idle.stream = idle_stream_unica
	motor_idle.volume_db = 0.0
	motor_idle.autoplay = false
	add_child(motor_idle)
	motor_idle.play()

	# 3. Sonido mecánico de cambio de marcha (clack de transmisión secuencial de rally)
	sonido_cambio = AudioStreamPlayer.new()
	sonido_cambio.name = "SonidoCambio"
	if ResourceLoader.exists(path_base + "cambio_marcha.wav"):
		sonido_cambio.stream = load(path_base + "cambio_marcha.wav")
	sonido_cambio.volume_db = -10.0
	add_child(sonido_cambio)

	# 4. Derrape / Chillido de neumáticos
	derrape = AudioStreamPlayer.new()
	derrape.name = "Derrape"
	if ResourceLoader.exists(path_base + "derrape_loop.wav"):
		derrape.stream = _configurar_stream_en_bucle(load(path_base + "derrape_loop.wav"))
	elif ResourceLoader.exists(path_base + "Derrape_Rally.mp3"):
		derrape.stream = _configurar_stream_en_bucle(load(path_base + "Derrape_Rally.mp3"))
	derrape.volume_db = -80.0
	derrape.autoplay = false
	add_child(derrape)
	derrape.play()

	# 5. Banco de detonaciones de escape (Anti-Lag ALS)
	for i in range(1, 6):
		var p_path = path_base + "pop_als_%d.wav" % i
		if ResourceLoader.exists(p_path):
			var p = AudioStreamPlayer.new()
			p.name = "Pop_%d" % i
			p.stream = load(p_path)
			p.volume_db = 0.0
			add_child(p)
			lista_pops.append(p)

func _unhandled_input(event: InputEvent) -> void:
	# Soporte opcional para hacer los cambios con la rueda del ratón
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			subir_marcha_manual()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			bajar_marcha_manual()

func subir_marcha_manual() -> void:
	if marcha_actual < 6:
		cambiar_marcha(marcha_actual + 1, true)

func bajar_marcha_manual() -> void:
	if marcha_actual > 1:
		cambiar_marcha(marcha_actual - 1, false)

func _physics_process(delta: float) -> void:
	if not pj:
		return
	
	# Asegurar que los bucles nunca se detengan
	if motor_rev and not motor_rev.playing:
		motor_rev.play()
	if derrape and not derrape.playing:
		derrape.play()

	var vel_h = Vector2(pj.velocity.x, pj.velocity.z).length()
	var acelerando = Input.is_action_pressed("move_up")
	var frenando = Input.is_action_pressed("move_down")
	var nitro = pj.corre if "corre" in pj else false
	var direccion_giro = Input.get_axis("move_left", "move_right")
	var tecla_derrape = Input.is_action_pressed("derrapar") if InputMap.has_action("derrapar") else Input.is_key_pressed(KEY_SPACE)
	var tecla_f = tecla_derrape or Input.is_key_pressed(KEY_F)

	# --- 1. GESTIÓN AUTOMÁTICA DE MARCHAS ---
	if not modo_manual:
		var rango = VELOCIDAD_MARCHAS[marcha_actual - 1]
		# Subir de marcha al estirar la velocidad actual acelerando
		if marcha_actual < 6 and vel_h > rango.y and acelerando:
			cambiar_marcha(marcha_actual + 1, true)
		# Reducir marcha al desacelerar
		elif marcha_actual > 1 and vel_h < rango.x - 1.2 and not acelerando:
			cambiar_marcha(marcha_actual - 1, false)

	# --- 2. RÉGIMEN DE RPM Y SUBIDA/CAÍDA DINÁMICA ---
	var rango_act = VELOCIDAD_MARCHAS[marcha_actual - 1]
	var ratio_vel = clampf((vel_h - rango_act.x) / maxf(0.5, rango_act.y - rango_act.x), 0.0, 1.0)
	
	var rpm_objetivo = 0.15
	if acelerando:
		# Respuesta inmediata del acelerador: sube revoluciones con fuerza
		# En marchas altas el motor "descansa" en crucero (no se queda al tope)
		var rpm_tope := 1.0 if marcha_actual < 4 else 0.80
		rpm_objetivo = lerpf(0.35, rpm_tope, ratio_vel)
		if nitro:
			rpm_objetivo = 0.92
	elif frenando:
		rpm_objetivo = maxf(0.10, ratio_vel * 0.40)
	else:
		# Al soltar el acelerador las revoluciones caen suavemente
		rpm_objetivo = maxf(0.10, ratio_vel * 0.30)
	
	# Durante el cambio de marcha solo avanza el temporizador; el "bache" se
	# aplica como curva suave (env_cambio) en tono y volumen, sin cortes bruscos.
	var env_cambio := 0.0
	if tiempo_corte_cambio > 0.0:
		tiempo_corte_cambio = maxf(tiempo_corte_cambio - delta, 0.0)
		env_cambio = sin(PI * (1.0 - tiempo_corte_cambio / DURACION_CAMBIO))

	var tasa_rpm = 4.0 if tiempo_corte_cambio > 0.0 else (5.5 if acelerando else 2.5)
	rpm = move_toward(rpm, rpm_objetivo, tasa_rpm * delta)

	# --- 3. ANTI-LAG (ALS) CONTROLADO (CERO RUIDOS EN PARADO) ---
	# Solo a alta velocidad (> 50 km/h = 14 m/s) en 3ra marcha o superior
	if acelerando_antes and not acelerando and rpm > 0.65 and vel_h > 14.0 and marcha_actual >= 3:
		pops_pendientes = randi_range(2, 4)
		temporizador_pop = randf_range(0.04, 0.09)

	acelerando_antes = acelerando

	if pops_pendientes > 0:
		temporizador_pop -= delta
		if temporizador_pop <= 0.0:
			disparar_pop_als(1.05, 1.30, -2.0)
			pops_pendientes -= 1
			temporizador_pop = randf_range(0.08, 0.15)

	# --- 4. TONO (PITCH SCALE) DEL MOTOR ---
	var tonos_marcha = PITCH_MARCHAS[marcha_actual - 1]
	var pitch_final = lerpf(tonos_marcha.x, tonos_marcha.y, clampf(rpm, 0.0, 1.0))
	
	if nitro:
		pitch_final *= 1.03
	
	# Leve caída de tono al cambiar (suave, ida y vuelta)
	pitch_final *= 1.0 - 0.06 * env_cambio
	
	pitch_final = minf(pitch_final, PITCH_MAXIMO)
	motor_rev.pitch_scale = lerpf(motor_rev.pitch_scale, pitch_final, clampf(delta * 20.0, 0.0, 1.0))

	# Filtro dinámico: en marchas altas se cierra más para quitar el chillido/saturación
	if filtro_motor:
		var cutoff_obj := lerpf(3200.0, 2000.0, clampf((marcha_actual - 1) / 5.0, 0.0, 1.0))
		filtro_motor.cutoff_hz = lerpf(filtro_motor.cutoff_hz, cutoff_obj, clampf(delta * 4.0, 0.0, 1.0))

	# Ensure engine rev sound is playing when accelerating
	if acelerando and not motor_rev.playing:
		motor_rev.play()

	var target_vol_rev = -32.0
	if acelerando:
		# Presencia inmediata sin pasarse de 0 dB (evita saturar)
		target_vol_rev = -1.0 if not nitro else 0.0
		# En marchas altas el sonido se aprieta y satura: se baja un poco cada marcha
		if marcha_actual > 3:
			target_vol_rev -= (marcha_actual - 3) * 2.0
	elif vel_h > 1.5:
		# Retención y rodamiento a velocidad
		target_vol_rev = lerpf(-12.0, -4.0, clampf(vel_h / 25.0, 0.0, 1.0))
	
	# Leve bajada de volumen en el cambio (máx. -2.5 dB, curva suave): el motor no se apaga
	target_vol_rev -= 2.5 * env_cambio
	
	motor_rev.volume_db = lerpf(motor_rev.volume_db, target_vol_rev, clampf(delta * 15.0, 0.0, 1.0))

	# Ralentí / sonido de arranque: solo suena (a) una vez al empezar y
	# (b) cuando el carro está quieto y mantienes F (o la tecla de derrapar).
	var quieto = vel_h < 1.5 and not acelerando
	var target_vol_idle = -60.0
	if quieto and tecla_f:
		if not idle_en_bucle:
			idle_en_bucle = true
			motor_idle.stream = idle_stream_bucle
			motor_idle.volume_db = -20.0
			motor_idle.play()
		elif not motor_idle.playing:
			motor_idle.play()
		target_vol_idle = 0.0
	elif idle_en_bucle:
		# Soltaste F o el carro se mueve: se apaga y se detiene
		if motor_idle.volume_db < -50.0:
			motor_idle.stop()
			motor_idle.stream = idle_stream_unica
			idle_en_bucle = false
	elif quieto and motor_idle.playing:
		target_vol_idle = 0.0 # sonido inicial, una sola vez
	elif motor_idle.playing and motor_idle.volume_db < -50.0:
		motor_idle.stop()
	motor_idle.volume_db = lerpf(motor_idle.volume_db, target_vol_idle, clampf(delta * 12.0, 0.0, 1.0))
	motor_idle.pitch_scale = lerpf(0.96, 1.06, clampf(rpm, 0.0, 1.0) * 0.25)

	# --- 6. CHILLIDO DE NEUMÁTICOS EN DERRAPES ---
	var derrapando = (tecla_derrape and vel_h > 4.0) or (absf(direccion_giro) > 0.35 and vel_h > 12.0)
	if derrapando and pj.is_on_floor():
		var vol_skid = lerpf(-14.0, -3.0, clampf(vel_h / 25.0, 0.0, 1.0))
		derrape.volume_db = lerpf(derrape.volume_db, vol_skid, clampf(delta * 18.0, 0.0, 1.0))
		derrape.pitch_scale = lerpf(0.92, 1.22, clampf(vel_h / 25.0, 0.0, 1.0))
	else:
		derrape.volume_db = lerpf(derrape.volume_db, -80.0, clampf(delta * 12.0, 0.0, 1.0))

func cambiar_marcha(nueva: int, subiendo: bool) -> void:
	if nueva == marcha_actual:
		return
	var marcha_previa = marcha_actual
	marcha_actual = nueva
	tiempo_corte_cambio = DURACION_CAMBIO
	print("[audio_carro] CAMBIO DE MARCHA: ", marcha_previa, " -> ", marcha_actual, " (", "subiendo" if subiendo else "bajando", ") cuadro ", Engine.get_physics_frames())
	
	# Sonido mecánico auténtico de caja de cambios de rally
	if sonido_cambio:
		sonido_cambio.pitch_scale = randf_range(0.96, 1.08)
		sonido_cambio.play()
	
	# Explosión deportiva en marchas altas (3ra en adelante)
	if subiendo and marcha_actual >= 3 and randf() > 0.35:
		disparar_pop_als(1.10, 1.35, -2.5)
	elif not subiendo and marcha_actual >= 3 and randf() > 0.5:
		disparar_pop_als(0.95, 1.15, -3.5)

func disparar_pop_als(p_min: float = 1.0, p_max: float = 1.30, vol_offset: float = 0.0) -> void:
	if lista_pops.is_empty():
		return
	var p = lista_pops.pick_random()
	if p:
		p.pitch_scale = randf_range(p_min, p_max)
		p.volume_db = randf_range(-1.0, 2.5) + vol_offset
		p.play()

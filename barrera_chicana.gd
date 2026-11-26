class_name BarreraChicana
extends RigidBody3D

## BarreraChicana - Obstáculo pesado de obra vial para chicanas (zig-zag).
## Diseñado para que el jugador deba frenar y doblar ágilmente en eslalon (zig-zag).
## Si se estrella de frente sin frenar, sufre una penalización fuerte de velocidad
## (aprox. 40 km/h) y la barrera se desplaza con impacto contundente.

var fue_golpeada := false
var luz_advertencia: OmniLight3D = null
var _tiempo_luz := 0.0

func _ready() -> void:
	mass = 140.0 # Barrera de concreto/polímero pesado de seguridad vial
	gravity_scale = 2.0
	collision_layer = 2 # Capa 2 (obstáculos)
	collision_mask = 1 | 2 # Pista (1), carros (1), otros obstáculos (2)
	contact_monitor = true
	max_contacts_reported = 4
	
	# Detector de impacto mediante Area3D
	var detector := Area3D.new()
	detector.name = "DetectorCarro"
	detector.collision_layer = 0
	detector.collision_mask = 1 # Carros en capa 1 (jugador y rivales)
	
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.6, 1.3, 1.1)
	col.shape = box
	col.position = Vector3(0.0, 0.65, 0.0)
	detector.add_child(col)
	add_child(detector)
	detector.body_entered.connect(_on_detector_body_entered)

func _process(delta: float) -> void:
	# Parpadeo de baliza ámbar en la parte superior
	if luz_advertencia and is_instance_valid(luz_advertencia):
		_tiempo_luz += delta
		luz_advertencia.light_energy = 3.8 if fmod(_tiempo_luz, 0.40) < 0.20 else 0.4

func _on_detector_body_entered(body: Node) -> void:
	if body.is_in_group("jugador") or body.is_in_group("rival"):
		al_chocar(body)

func al_chocar(carro: Node) -> void:
	if not fue_golpeada:
		fue_golpeada = true
		_reproducir_impacto()
		
		# Penalización severa por comerse la barrera de lleno sin frenar ni zigzaguear:
		# Resta 11.0 m/s (≈ 40 km/h). Obliga a frenar a tiempo.
		var penalizacion_ms := 11.0
		if "rapidez_actual" in carro:
			if carro.rapidez_actual > 0.0:
				carro.rapidez_actual = maxf(carro.rapidez_actual - penalizacion_ms, 3.0)
			elif carro.rapidez_actual < 0.0:
				carro.rapidez_actual = minf(carro.rapidez_actual + penalizacion_ms, -3.0)
		elif "velocidad_actual" in carro:
			carro.velocidad_actual = maxf(carro.velocidad_actual - penalizacion_ms, 2.0)
		
		# Impulso físico a la barrera pesada: deslizamiento con volteo
		var vel_carro: Vector3 = Vector3.ZERO
		if "velocity" in carro and carro.velocity.length() > 1.0:
			vel_carro = carro.velocity
		else:
			vel_carro = -carro.global_transform.basis.z * 20.0
		
		var dir := vel_carro.normalized()
		apply_central_impulse(dir * 50.0 + Vector3(0.0, 5.0, 0.0))
		apply_torque_impulse(Vector3(randf_range(-12, 12), randf_range(-20, 20), randf_range(-12, 12)))

func _reproducir_impacto() -> void:
	var snd_path := "res://Sonidos_Armas/cohete_impacto.mp3"
	if ResourceLoader.exists(snd_path):
		var p := AudioStreamPlayer3D.new()
		p.stream = load(snd_path)
		p.pitch_scale = randf_range(1.35, 1.55) # Impacto contundente metálico/pesado
		p.volume_db = 1.5
		p.max_distance = 60.0
		get_tree().root.add_child(p)
		p.global_position = global_position
		p.play()
		p.finished.connect(p.queue_free)

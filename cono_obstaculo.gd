class_name ConoObstaculo
extends RigidBody3D

## ConoObstaculo - Cono de tráfico dinámico con física realista
## Reacciona al impacto de los carros volando y rodando por la pista
## en lugar de comportarse como una pared fija de concreto.

var fue_golpeado := false
var _cooldown_sonido := 0.0

func _ready() -> void:
	mass = 2.0
	gravity_scale = 1.6
	collision_layer = 2 # Capa 2 (conos / obstáculos)
	collision_mask = 1 | 2 # Pista (1), carros (1), y otros conos (2)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _cooldown_sonido > 0.0:
		_cooldown_sonido = maxf(0.0, _cooldown_sonido - delta)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("jugador") or body.is_in_group("rival"):
		al_chocar(body)

func al_chocar(carro: Node) -> void:
	var vel_carro: Vector3 = Vector3.ZERO
	if "velocity" in carro and carro.velocity.length() > 0.5:
		vel_carro = carro.velocity
	else:
		vel_carro = -carro.global_transform.basis.z * 15.0
	
	var speed: float = vel_carro.length()
	var dir: Vector3 = vel_carro.normalized()
	
	if not fue_golpeado:
		fue_golpeado = true
		_reproducir_sonido()
		# Penalización ligera y realista al carro (resistencia leve al impacto, ~8%)
		if "rapidez_actual" in carro:
			carro.rapidez_actual = maxf(carro.rapidez_actual * 0.92, 0.0)
	elif _cooldown_sonido <= 0.0:
		_reproducir_sonido()
	
	_cooldown_sonido = 0.35
	
	# Impulso físico espectacular en la dirección del impacto con elevación y volteo
	var impulso := dir * maxf(speed * 0.85, 12.0) + Vector3(randf_range(-1.5, 1.5), randf_range(3.5, 6.5), randf_range(-1.5, 1.5))
	apply_central_impulse(impulso)
	var torque := Vector3(randf_range(-14.0, 14.0), randf_range(-18.0, 18.0), randf_range(-14.0, 14.0))
	apply_torque_impulse(torque)

func _reproducir_sonido() -> void:
	var snd_path := "res://Sonidos_Carros/CarroRally_Personaje/pop_als_1.wav"
	if ResourceLoader.exists(snd_path):
		var p := AudioStreamPlayer3D.new()
		p.stream = load(snd_path)
		p.pitch_scale = randf_range(1.4, 1.8) # Tono plástico agudo característico
		p.volume_db = 2.0
		p.max_distance = 50.0
		get_tree().root.add_child(p)
		p.global_position = global_position
		p.play()
		p.finished.connect(p.queue_free)

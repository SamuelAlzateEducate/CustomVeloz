extends CharacterBody3D

enum Estado { CORRER, ATACAR, LENTO, IMPACTADO }

@export var velocidad_maxima = 12.0
@export var aceleracion = 5.0
@export var velocidad_giro = 2.0
@export var distancia_llegada = 5.0
@export var ruta: Array[Vector3] = [
	Vector3(10, 0, 0), Vector3(10, 0, -12), Vector3(-10, 0, -12),
	Vector3(-10, 0, 0)
]

@export var radio_onda = 5.0
@export var recarga_onda = 5.0
@export var castigo = 2.78
@export var tiempo_lento = 3.0

var estado = Estado.CORRER
var velocidad_actual = 0.0
var indice = 0
var vueltas = 0

var reloj_onda = 15.0
var reloj_lento = 0.0
var reloj_impactado = 0.0
var jugador: Node3D = null

func _ready():
	add_to_group("rival")
	floor_snap_length = 3.0
	floor_constant_speed = true
	jugador = get_tree().get_first_node_in_group("jugador")

func _physics_process(delta):
	reloj_impactado = maxf(reloj_impactado - delta, 0.0)
	reloj_onda = maxf(reloj_onda - delta, 0.0)
	reloj_lento = maxf(reloj_lento - delta, 0.0)
	
	var nuevo = decidir()
	if nuevo != estado:
		estado = nuevo
		print(name, " -> ", Estado.keys()[estado], " cuadro ", Engine.get_physics_frames())
	
	var tope = velocidad_maxima
	match estado:
		Estado.IMPACTADO:
			tope = 1.0 # Frenado drástico por impacto
		Estado.ATACAR:
			if jugador:
				var d = plana(global_position, jugador.global_position)
				print(name, " lanza la onda a ", snappedf(d, 0.01), " m")
			reloj_onda = recarga_onda
		Estado.LENTO:
			tope = velocidad_maxima - castigo
	
	var destino = ruta[indice]
	if plana(global_position, destino) < distancia_llegada:
		indice = (indice + 1) % ruta.size()
		print(name, " va al punto ", indice, " cuadro ", Engine.get_physics_frames())
		if indice == 0:
			vueltas += 1
			print(name, " vuelta ", vueltas)
		destino = ruta[indice]
	
	var hacia = destino - global_position
	hacia.y = 0.0
	var local = transform.basis.inverse() * hacia
	var volante = clampf(-local.x, -1.0, 1.0)
	
	# Sin control de dirección durante el trompo del impacto
	if estado == Estado.IMPACTADO:
		volante = 0.0
	
	velocidad_actual = move_toward(velocidad_actual, tope, aceleracion * delta)
	var proporcion = velocidad_actual / velocidad_maxima if velocidad_maxima > 0.0 else 0.0
	rotate_y(volante * velocidad_giro * proporcion * delta)
	velocity += get_gravity() * delta
	var adelante = -transform.basis.z * velocidad_actual
	velocity.x = adelante.x
	velocity.z = adelante.z
	
	if is_on_floor() and estado != Estado.IMPACTADO:
		floor_snap_length = 3.0
		var nf = get_floor_normal()
		if nf.y > 0.3:
			velocity.y = -(nf.x * velocity.x + nf.z * velocity.z) / nf.y
			
	move_and_slide()
	if not is_on_floor() and estado != Estado.IMPACTADO:
		apply_floor_snap()

func decidir():
	if reloj_impactado > 0.0:
		return Estado.IMPACTADO
	if reloj_lento > 0.0:
		return Estado.LENTO
	if jugador:
		var d = plana(global_position, jugador.global_position)
		if d <= radio_onda and reloj_onda <= 0.0:
			return Estado.ATACAR
	return Estado.CORRER

func recibir_impacto():
	estado = Estado.IMPACTADO
	reloj_impactado = 1.8 # 1.8 s de trompo e incapacidad
	reloj_lento = tiempo_lento + 1.8 # después queda lento
	
	# Reducción brusca de velocidad
	velocidad_actual = maxf(velocidad_actual * 0.15, 1.5)
	
	# Salto vertical arcade (despegue del asfalto)
	floor_snap_length = 0.0
	velocity.y = 6.2
	
	# Animación de trompo acrobático y vuelco en el modelo 3D
	_animar_trompo_impacto()
	
	# Fuego y humo saliendo del carro
	_generar_particulas_daño()
	
	print(name, " ¡IMPACTADO POR COHETE! Entra en trompo acrobático y pierde el control")

func _animar_trompo_impacto() -> void:
	var modelo = get_node_or_null("Modelo")
	if not modelo:
		return
	var tw = create_tween()
	var rot_y_orig: float = modelo.rotation_degrees.y
	tw.set_parallel(true)
	# 2 vueltas completas de trompo (720 grados) desacelerando
	tw.tween_property(modelo, "rotation_degrees:y", rot_y_orig + 720.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Alabeo / inclinación lateral en el aire (vuelco)
	tw.tween_property(modelo, "rotation_degrees:z", 32.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(modelo, "rotation_degrees:z", -18.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(modelo, "rotation_degrees:z", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _generar_particulas_daño() -> void:
	# 1. Humo negro espeso saliendo del motor
	var p_humo := CPUParticles3D.new()
	p_humo.name = "HumoImpactoRival"
	p_humo.amount = 22
	p_humo.lifetime = 0.9
	p_humo.explosiveness = 0.0
	p_humo.direction = Vector3.UP
	p_humo.spread = 40.0
	p_humo.gravity = Vector3(0, 3.0, 0)
	p_humo.initial_velocity_min = 2.0
	p_humo.initial_velocity_max = 5.0
	p_humo.scale_amount_min = 0.18
	p_humo.scale_amount_max = 0.45
	var mat_humo := StandardMaterial3D.new()
	mat_humo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_humo.albedo_color = Color(0.12, 0.12, 0.15, 0.75)
	mat_humo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var q_humo := QuadMesh.new()
	q_humo.size = Vector2(0.35, 0.35)
	q_humo.material = mat_humo
	p_humo.mesh = q_humo
	p_humo.position = Vector3(0, 0.7, 0)
	add_child(p_humo)

	# 2. Chispas de fuego naranja (#FF5722 peligro)
	var p_fuego := CPUParticles3D.new()
	p_fuego.name = "FuegoImpactoRival"
	p_fuego.amount = 16
	p_fuego.lifetime = 0.35
	p_fuego.explosiveness = 0.2
	p_fuego.direction = Vector3.UP
	p_fuego.spread = 50.0
	p_fuego.gravity = Vector3(0, -4.0, 0)
	p_fuego.initial_velocity_min = 3.0
	p_fuego.initial_velocity_max = 7.0
	p_fuego.scale_amount_min = 0.05
	p_fuego.scale_amount_max = 0.14
	var mat_fuego := StandardMaterial3D.new()
	mat_fuego.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fuego.albedo_color = Color(1.0, 0.35, 0.0) # Naranja Fuego oficial
	mat_fuego.emission_enabled = true
	mat_fuego.emission = Color(1.0, 0.35, 0.0)
	mat_fuego.emission_energy_multiplier = 4.0
	var q_fuego := QuadMesh.new()
	q_fuego.size = Vector2(0.1, 0.1)
	q_fuego.material = mat_fuego
	p_fuego.mesh = q_fuego
	p_fuego.position = Vector3(0, 0.5, 0)
	add_child(p_fuego)

	# Auto-destrucción de las partículas al terminar el impacto
	get_tree().create_timer(1.9).timeout.connect(func():
		if is_instance_valid(p_humo): p_humo.queue_free()
		if is_instance_valid(p_fuego): p_fuego.queue_free()
	)

func _reproducir_sonido_impacto() -> void:
	var snd_path := "res://Sonidos_Armas/cohete_impacto.mp3"
	if ResourceLoader.exists(snd_path):
		var snd := AudioStreamPlayer3D.new()
		snd.stream = load(snd_path)
		snd.volume_db = 1.0
		snd.max_distance = 60.0
		add_child(snd)
		snd.play()
		snd.finished.connect(snd.queue_free)

func plana(a, b):
	return Vector2(a.x - b.x, a.z - b.z).length()

class_name Nitro
extends Node

# Sistema de Nitro / Turbo de CustomVeloz:
#  - velocidad: 120 km/h (33.33 m/s) en vez de 90 km/h (25 m/s) -> +30 km/h (+33 %).
#  - duración: 2.5 s con la carga llena
#  - recarga: de 0 a 1 tarda 5 s (si recarga_automatica = true, como en zona_b)
#  - La luz (azul neón -> rojo fuego) la controla sistema_eventos.gd exactamente igual que en zona_b.
#  - Con llama_visible = true (zona_c) además salen llamas y una luz trasera que pasan de azul a rojo
#    mientras se mantiene Shift, para que el efecto se vea sobre cualquier pista.
@export var luz: SpotLight3D
@export var duracion := 2.5 # s para gastar la carga completa
@export var recarga := 5.0 # s para recuperar la carga completa
@export var carga_minima := 0.20 # tras vaciarse, no se puede usar hasta recuperar esto
@export var recarga_automatica := true # false = el turbo solo se recarga con las esferas amarillas
@export var llama_visible := false # true = llamas y luz trasera emisivas (zona_c)
@export var color_llama_bajo := Color(0.0, 0.9, 1.0)
@export var color_llama_alto := Color(1.0, 0.15, 0.05)

var carga := 1.0 # 0 a 1 (la barra de nitro de la UI)
var activo := false
var bloqueado := false

const EstelaLuzScript = preload("res://estela_luz.gd")

var _llamas: Array[MeshInstance3D] = []
var _mat_llama: StandardMaterial3D
var _luz_trasera: OmniLight3D
var _calor := 0.0 # 0 a 1: se calienta (azul -> rojo) mientras el turbo está activo
var _chispas: Array[CPUParticles3D] = []
var _estela: MeshInstance3D

@onready var pj := get_parent()

func _ready() -> void:
	if luz:
		# Configuración exacta original de zona_b (Taller 4 / Taller 8):
		# apunta hacia atrás (+Z local) y un poco hacia el piso
		luz.rotation_degrees = Vector3(-20.0, 180.0, 0.0)
		luz.spot_range = 10.0
		luz.spot_angle = 35.0
	if llama_visible:
		_crear_llamas()

func _crear_llamas() -> void:
	_mat_llama = StandardMaterial3D.new()
	_mat_llama.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_llama.emission_enabled = true
	_mat_llama.albedo_color = color_llama_bajo
	_mat_llama.emission = color_llama_bajo
	_mat_llama.emission_energy_multiplier = 0.0
	for x in [-0.45, 0.45]:
		var m := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.16
		cono.height = 1.0
		cono.radial_segments = 8
		m.mesh = cono
		m.material_override = _mat_llama
		m.name = "LlamaTurbo"
		m.visible = false
		pj.add_child.call_deferred(m)
		_llamas.append(m)
		# el cilindro apunta en Y: se gira para que la punta quede hacia atrás (+Z)
		m.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		m.position = Vector3(x, 0.55, 2.5)
	_luz_trasera = OmniLight3D.new()
	_luz_trasera.name = "LuzTraseraTurbo"
	_luz_trasera.omni_range = 9.0
	_luz_trasera.light_energy = 0.0
	_luz_trasera.position = Vector3(0.0, 0.8, 3.0)
	pj.add_child.call_deferred(_luz_trasera)

	# Chispas estilo Burnout para cada escape
	for x in [-0.38, 0.38]:
		var p := CPUParticles3D.new()
		p.name = "ChispasTurbo"
		p.emitting = false
		p.local_coords = false # En el espacio del mundo para que queden flotando atrás
		p.amount = 32
		p.lifetime = 0.35
		p.explosiveness = 0.0
		p.randomness = 0.3
		p.direction = Vector3(0.0, 0.15, 1.0) # Hacia atrás del carro
		p.spread = 15.0
		p.gravity = Vector3(0.0, -3.5, 0.0)
		p.initial_velocity_min = 14.0
		p.initial_velocity_max = 26.0
		p.scale_amount_min = 0.06
		p.scale_amount_max = 0.16
		var mat_p := StandardMaterial3D.new()
		mat_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_p.albedo_color = Color(1.0, 0.8, 0.2)
		mat_p.emission_enabled = true
		mat_p.emission = Color(1.0, 0.6, 0.1)
		mat_p.emission_energy_multiplier = 3.5
		var quad := QuadMesh.new()
		quad.size = Vector2(0.12, 0.12)
		quad.material = mat_p
		p.mesh = quad
		p.position = Vector3(x, 0.58, 1.82)
		pj.add_child.call_deferred(p)
		_chispas.append(p)
	
	# Estela de luz neón detrás del carro
	_estela = EstelaLuzScript.new()
	_estela.name = "EstelaLuzTurbo"
	pj.add_child.call_deferred(_estela)

func _actualizar_llamas(delta: float) -> void:
	if _mat_llama == null:
		return
	_calor = move_toward(_calor, 1.0 if activo else 0.0, delta * 1.2)
	var encendido := _calor > 0.02
	var c := color_llama_bajo.lerp(color_llama_alto, _calor)
	_mat_llama.albedo_color = c
	_mat_llama.emission = c
	_mat_llama.emission_energy_multiplier = 1.0 + 5.0 * _calor
	var parpadeo := 1.0 + 0.2 * sin(Time.get_ticks_msec() * 0.04)
	var largo := (0.3 + 1.6 * _calor) * parpadeo
	for m in _llamas:
		if not is_instance_valid(m):
			continue
		m.visible = encendido
		m.scale = Vector3(1.0, largo, 1.0)
		m.position.z = 2.45 + largo * 0.5
	if is_instance_valid(_luz_trasera):
		_luz_trasera.light_color = c
		_luz_trasera.light_energy = (1.0 + 7.0 * _calor) if encendido else 0.0
	for p in _chispas:
		if is_instance_valid(p):
			p.emitting = encendido and activo
	if is_instance_valid(_estela):
		_estela.actualizar_estela(activo, _calor)

func _physics_process(delta: float) -> void:
	var tecla_nitro := false
	if "quiere_nitro" in pj:
		tecla_nitro = pj.quiere_nitro
	else:
		tecla_nitro = Input.is_action_pressed("correr") or Input.is_key_pressed(KEY_SHIFT)
	activo = tecla_nitro and carga > 0.0 and not bloqueado
	if activo:
		carga = maxf(0.0, carga - delta / duracion)
		if carga <= 0.0:
			bloqueado = true
	elif recarga_automatica:
		carga = minf(1.0, carga + delta / recarga)
		if bloqueado and carga >= carga_minima:
			bloqueado = false
	
	# Sin recarga automática: queda bloqueado hasta que una esfera amarilla recargue la carga
	_actualizar_llamas(delta)
	
	# personaje.gd usa speed_correr mientras haya nitro
	pj.nitro_ok = carga > 0.0 and not bloqueado

func recargar_nitro(cantidad: float = 1.0) -> void:
	carga = minf(1.0, carga + cantidad)
	bloqueado = false

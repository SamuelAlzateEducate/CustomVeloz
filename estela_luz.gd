class_name EstelaLuz
extends MeshInstance3D

# Estela de luz neón estilo Burnout / Blur para CustomVeloz
# Genera dos cintas de luz brillantes que se extienden detrás de las luces traseras
# del vehículo mientras el turbo está activo.

@export var max_puntos := 24
@export var ancho_cinta := 0.20
@export var desfase_izq := Vector3(-0.55, 0.65, 1.80)
@export var desfase_der := Vector3(0.55, 0.65, 1.80)
@export var color_estela := Color(1.0, 0.15, 0.1, 0.85)

var _historial_izq: Array[Vector3] = []
var _historial_der: Array[Vector3] = []
var _mat_estela: StandardMaterial3D
var _inm: ImmediateMesh
var _pj: Node3D

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_pj = get_parent() as Node3D
	_inm = ImmediateMesh.new()
	mesh = _inm
	
	_mat_estela = StandardMaterial3D.new()
	_mat_estela.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_estela.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_estela.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_estela.emission_enabled = true
	_mat_estela.albedo_color = color_estela
	_mat_estela.emission = color_estela
	_mat_estela.emission_energy_multiplier = 4.0
	material_override = _mat_estela

func actualizar_estela(turbo_activo: bool, calor: float) -> void:
	if not is_instance_valid(_pj):
		return
	
	# Asegurar que la malla esté exactamente anclada en el origen global (evita doble transformación)
	global_transform = Transform3D.IDENTITY

	var trans := _pj.global_transform
	var pos_izq := trans * desfase_izq
	var pos_der := trans * desfase_der

	# Color dinámico (azul neón -> rojo fuego) según la temperatura del turbo
	var col_actual := Color(0.0, 0.9, 1.0, 0.85).lerp(color_estela, calor)
	if _mat_estela:
		_mat_estela.albedo_color = col_actual
		_mat_estela.emission = col_actual
		_mat_estela.emission_energy_multiplier = 2.0 + 3.0 * calor

	if turbo_activo:
		_historial_izq.push_front(pos_izq)
		_historial_der.push_front(pos_der)
		if _historial_izq.size() > max_puntos:
			_historial_izq.resize(max_puntos)
			_historial_der.resize(max_puntos)
	else:
		# Retraer suavemente la estela cuando se suelta el turbo
		if _historial_izq.size() > 0:
			_historial_izq.pop_back()
			_historial_der.pop_back()
		if _historial_izq.size() > 0:
			_historial_izq.pop_back()
			_historial_der.pop_back()

	_dibujar_cintas()

func _dibujar_cintas() -> void:
	_inm.clear_surfaces()
	var n := _historial_izq.size()
	if n < 2:
		return

	_inm.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat_estela)
	
	# Dibujar cinta izquierda y cinta derecha
	_dibujar_tira(_historial_izq)
	_dibujar_tira(_historial_der)
	
	_inm.surface_end()

func _dibujar_tira(puntos: Array[Vector3]) -> void:
	var total := puntos.size()
	for i in range(total - 1):
		var p0: Vector3 = puntos[i]
		var p1: Vector3 = puntos[i + 1]
		
		var frac0 := 1.0 - (float(i) / float(total))
		var frac1 := 1.0 - (float(i + 1) / float(total))
		
		var h0 := ancho_cinta * frac0 * 0.5
		var h1 := ancho_cinta * frac1 * 0.5
		
		# Quads verticales para que se vean bien desde cualquier ángulo
		var v0_up := p0 + Vector3(0, h0, 0)
		var v0_dn := p0 - Vector3(0, h0, 0)
		var v1_up := p1 + Vector3(0, h1, 0)
		var v1_dn := p1 - Vector3(0, h1, 0)
		
		_inm.surface_set_color(Color(1, 1, 1, frac0))
		_inm.surface_add_vertex(v0_up)
		_inm.surface_add_vertex(v1_up)
		_inm.surface_add_vertex(v0_dn)
		
		_inm.surface_set_color(Color(1, 1, 1, frac1))
		_inm.surface_add_vertex(v0_dn)
		_inm.surface_add_vertex(v1_up)
		_inm.surface_add_vertex(v1_dn)

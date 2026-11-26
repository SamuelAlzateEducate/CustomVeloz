@tool
class_name EscenarioFondo
extends Node3D

# CustomVeloz - Generador de Escenario Low Poly y Fondo
# Basado en la estética "Blur con mutación de vehículo en tiempo real y estética Low Poly"
# y las recomendaciones del consolidado de recursos (Toon shading, ACES, atmósfera arcade).
#
# Genera proceduralmente:
# 1. Cuenca de terreno base (valle poligonal facetado bajo la pista)
# 2. Anillo de cordilleras / montañas low poly en el horizonte (360°)
# 3. Pilares estructurales de soporte bajo los tramos elevados del circuito
# 4. Pórtico de meta arcade con neón
# 5. Arcos de velocidad en la cima de la colina
# 6. Balizas de luz perimetrales a lo largo del circuito

const C_TERRENO := Color(0.13, 0.15, 0.20) # Roca pizarra oscura / suelo arcade
const C_MONTANA := Color(0.20, 0.16, 0.30) # Montañas lejanas violeta / crepúsculo
const C_ESTRUCTURA := Color(0.18, 0.21, 0.25) # Concreto / metal estructural
const C_NEON_AZUL := Color(0.0, 0.9, 1.0) # Neón azul de CustomVeloz (#00E5FF)
const C_NEON_ORO := Color(1.0, 0.85, 0.0) # Dorado turbo

@export var pista_nodo: NodePath = ^"../Pista"
@export var altura_suelo_base := -3.0
@export var radio_montanas := 680.0

var _pista: Node3D

func _ready() -> void:
	_pista = get_node_or_null(pista_nodo) as Node3D
	_limpiar_hijos()
	_construir_terreno_base()
	_construir_montanas_horizonte()
	if _pista:
		if "centro" in _pista and _pista.centro.size() > 0:
			_construir_elementos_pista()
		else:
			call_deferred("_construir_elementos_pista")

func _construir_elementos_pista() -> void:
	if _pista and "centro" in _pista and _pista.centro.size() > 0:
		_construir_pilares()
		_construir_portico_meta()
		_construir_lowcity()
		_construir_publico()

func _distancia_a_pista_2d(pos: Vector2) -> float:
	if not _pista or not ("centro" in _pista) or _pista.centro.is_empty():
		return 999.0
	var d_min := 99999.0
	for p in _pista.centro:
		var d := pos.distance_to(Vector2(p.x, p.z))
		if d < d_min:
			d_min = d
	return d_min

func _limpiar_hijos() -> void:
	for c in get_children():
		c.queue_free()

# ------------------------------------------------------------------ Auxiliares de Mallas
static func _crear_malla(vertices: PackedVector3Array, normales: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_NORMAL] = normales
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi

static func _agregar_triangulo_plano(v: PackedVector3Array, nr: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		v.append(p)
		nr.append(n)

static func _agregar_quad_plano(v: PackedVector3Array, nr: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_agregar_triangulo_plano(v, nr, a, b, c)
	_agregar_triangulo_plano(v, nr, a, c, d)

# ------------------------------------------------------------------ 1. Terreno Base Facetado
func _construir_terreno_base() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = C_TERRENO
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_BACK

	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()

	var centro_x := 145.0
	var centro_z := 30.0
	var paso_grid := 40.0
	var nx := 28 # ~1120 metros de ancho
	var nz := 28 # ~1120 metros de largo

	var grid: Array = []
	for ix in range(nx + 1):
		var fila: Array[Vector3] = []
		for iz in range(nz + 1):
			var x := centro_x + (float(ix) - float(nx) * 0.5) * paso_grid
			var z := centro_z + (float(iz) - float(nz) * 0.5) * paso_grid
			var pos2d := Vector2(x, z)
			var dist_pista := _distancia_a_pista_2d(pos2d)
			var d_centro := Vector2(x - centro_x, z - centro_z).length()

			# Altura del terreno:
			# Si está cerca de la pista (< 45m), el suelo se mantiene completamente plano
			# a Y = -3.0m (3 metros abajo del asfalto) para evitar que jamás tape la carretera.
			var h := altura_suelo_base
			if dist_pista >= 45.0 and d_centro > 350.0:
				var factor_borde := clampf((d_centro - 350.0) / 220.0, 0.0, 1.0)
				var factor_pista := clampf((dist_pista - 45.0) / 60.0, 0.0, 1.0)
				var factor := factor_borde * factor_pista
				var ruido := sin(x * 0.02) * cos(z * 0.02) * 6.0
				h += factor * (15.0 + ruido)
			fila.append(Vector3(x, h, z))
		grid.append(fila)

	for ix in range(nx):
		for iz in range(nz):
			var p00: Vector3 = grid[ix][iz]
			var p10: Vector3 = grid[ix + 1][iz]
			var p11: Vector3 = grid[ix + 1][iz + 1]
			var p01: Vector3 = grid[ix][iz + 1]
			_agregar_quad_plano(vertices, normales, p00, p10, p11, p01)

	add_child(_crear_malla(vertices, normales, mat))

# ------------------------------------------------------------------ 2. Montañas Low Poly de Horizonte
func _construir_montanas_horizonte() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = C_MONTANA
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_BACK

	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()

	var centro_x := 145.0
	var centro_z := 30.0
	var total_montanas := 40
	var lados := 7

	for i in range(total_montanas):
		var frac := float(i) / float(total_montanas)
		var angulo := frac * TAU + sin(float(i) * 3.7) * 0.06
		# Distancia en dos anillos (cercano y lejano)
		var es_segundo_anillo := (i % 2 == 1)
		var radio := radio_montanas * (1.18 if es_segundo_anillo else 0.92) + sin(float(i) * 5.2) * 50.0
		var mx := centro_x + cos(angulo) * radio
		var mz := centro_z + sin(angulo) * radio
		var altura := (90.0 if not es_segundo_anillo else 140.0) + absf(sin(float(i) * 8.1)) * 50.0
		var radio_base := (80.0 if not es_segundo_anillo else 115.0) + absf(cos(float(i) * 4.3)) * 30.0
		var pico := Vector3(mx, altura + altura_suelo_base, mz)

		# Puntos base poligonales
		var base_pts: Array[Vector3] = []
		for l in range(lados):
			var a_l := float(l) / float(lados) * TAU + sin(float(l + i) * 2.1) * 0.2
			var r_l := radio_base * (0.8 + absf(cos(float(l * 3 + i))) * 0.4)
			var bx := mx + cos(a_l) * r_l
			var bz := mz + sin(a_l) * r_l
			base_pts.append(Vector3(bx, altura_suelo_base - 1.0, bz))

		for l in range(lados):
			var b1: Vector3 = base_pts[l]
			var b2: Vector3 = base_pts[(l + 1) % lados]
			_agregar_triangulo_plano(vertices, normales, b1, b2, pico)

	add_child(_crear_malla(vertices, normales, mat))

# ------------------------------------------------------------------ 3. Pilares de Soporte de Puente
func _construir_pilares() -> void:
	var mat_concreto := StandardMaterial3D.new()
	mat_concreto.albedo_color = C_ESTRUCTURA
	mat_concreto.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat_concreto.roughness = 0.9

	var mat_acento := StandardMaterial3D.new()
	mat_acento.albedo_color = C_NEON_AZUL
	mat_acento.emission_enabled = true
	mat_acento.emission = C_NEON_AZUL
	mat_acento.emission_energy_multiplier = 2.0

	var v_concreto := PackedVector3Array()
	var n_concreto := PackedVector3Array()
	var v_acento := PackedVector3Array()
	var n_acento := PackedVector3Array()

	var m: int = _pista.centro.size()
	var distancia_entre_pilares := 28.0 # metros entre pares de pilares
	var acumulado := 0.0

	for i in range(m):
		var p_act: Vector3 = _pista.centro[i]
		var p_sig: Vector3 = _pista.centro[(i + 1) % m]
		acumulado += p_act.distance_to(p_sig)

		# Colocar pilar solo en secciones elevadas (Y >= 1.5m)
		if p_act.y >= 1.5 and acumulado >= distancia_entre_pilares:
			acumulado = 0.0
			var der: Vector3 = _pista.derecha[i]
			var ade := Vector3.UP.cross(der).normalized()

			# Dos columnas robustas (a los lados bajo la calzada)
			for lado: float in [-4.5, 4.5]:
				var base_col: Vector3 = p_act + der * lado
				var y_tope: float = p_act.y - 0.2
				var y_piso: float = altura_suelo_base
				var radio_col: float = 0.9

				# Columna cuadrada facetada
				var c1 := Vector3(base_col.x - radio_col, y_piso, base_col.z - radio_col)
				var c2 := Vector3(base_col.x + radio_col, y_piso, base_col.z - radio_col)
				var c3 := Vector3(base_col.x + radio_col, y_piso, base_col.z + radio_col)
				var c4 := Vector3(base_col.x - radio_col, y_piso, base_col.z + radio_col)

				var t1 := Vector3(c1.x, y_tope, c1.z)
				var t2 := Vector3(c2.x, y_tope, c2.z)
				var t3 := Vector3(c3.x, y_tope, c3.z)
				var t4 := Vector3(c4.x, y_tope, c4.z)

				_agregar_quad_plano(v_concreto, n_concreto, c1, c2, t2, t1)
				_agregar_quad_plano(v_concreto, n_concreto, c2, c3, t3, t2)
				_agregar_quad_plano(v_concreto, n_concreto, c3, c4, t4, t3)
				_agregar_quad_plano(v_concreto, n_concreto, c4, c1, t1, t4)

				# Banda de neón horizontal en el tercio superior de cada pilar
				var y_banda1: float = lerpf(y_piso, y_tope, 0.75)
				var y_banda2: float = y_banda1 + 0.5
				var b1_1 := Vector3(c1.x, y_banda1, c1.z)
				var b2_1 := Vector3(c2.x, y_banda1, c2.z)
				var b3_1 := Vector3(c3.x, y_banda1, c3.z)
				var b4_1 := Vector3(c4.x, y_banda1, c4.z)
				var b1_2 := Vector3(c1.x, y_banda2, c1.z)
				var b2_2 := Vector3(c2.x, y_banda2, c2.z)
				var b3_2 := Vector3(c3.x, y_banda2, c3.z)
				var b4_2 := Vector3(c4.x, y_banda2, c4.z)
				_agregar_quad_plano(v_acento, n_acento, b1_1, b2_1, b2_2, b1_2)
				_agregar_quad_plano(v_acento, n_acento, b2_1, b3_1, b3_2, b2_2)
				_agregar_quad_plano(v_acento, n_acento, b3_1, b4_1, b4_2, b3_2)
				_agregar_quad_plano(v_acento, n_acento, b4_1, b1_1, b1_2, b4_2)

			# Viga transversal horizontal conectando las dos columnas
			var v1: Vector3 = p_act + der * -5.0 + Vector3(0, -0.6, 0) - ade * 0.8
			var v2: Vector3 = p_act + der * 5.0 + Vector3(0, -0.6, 0) - ade * 0.8
			var v3: Vector3 = p_act + der * 5.0 + Vector3(0, -0.6, 0) + ade * 0.8
			var v4: Vector3 = p_act + der * -5.0 + Vector3(0, -0.6, 0) + ade * 0.8
			var vb1 := v1 + Vector3(0, -0.8, 0)
			var vb2 := v2 + Vector3(0, -0.8, 0)
			var vb3 := v3 + Vector3(0, -0.8, 0)
			var vb4 := v4 + Vector3(0, -0.8, 0)
			_agregar_quad_plano(v_concreto, n_concreto, vb1, vb2, v2, v1)
			_agregar_quad_plano(v_concreto, n_concreto, vb2, vb3, v3, v2)
			_agregar_quad_plano(v_concreto, n_concreto, vb3, vb4, v4, v3)
			_agregar_quad_plano(v_concreto, n_concreto, vb4, vb1, v1, v4)
			_agregar_quad_plano(v_concreto, n_concreto, vb1, vb4, vb3, vb2)

	if v_concreto.size() > 0:
		add_child(_crear_malla(v_concreto, n_concreto, mat_concreto))
	if v_acento.size() > 0:
		add_child(_crear_malla(v_acento, n_acento, mat_acento))

# ------------------------------------------------------------------ 4. Pórtico de Meta con Neón
func _construir_portico_meta() -> void:
	var s_meta: float = _pista.s_meta
	var p: Vector3 = _pista.pos_en(s_meta)
	var der: Vector3 = _pista.der_en(s_meta)
	var ade: Vector3 = _pista.adelante_en(s_meta)

	var ancho_pista: float = _pista.ancho
	var alto_portico := 6.5
	var ancho_medio := ancho_pista * 0.5 + 1.2

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.15, 0.18, 0.22)
	mat_metal.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON

	var mat_neon := StandardMaterial3D.new()
	mat_neon.albedo_color = C_NEON_AZUL
	mat_neon.emission_enabled = true
	mat_neon.emission = C_NEON_AZUL
	mat_neon.emission_energy_multiplier = 3.0

	var v_m := PackedVector3Array()
	var n_m := PackedVector3Array()
	var v_n := PackedVector3Array()
	var n_n := PackedVector3Array()

	# Postes laterales del arco
	for lado: float in [-ancho_medio, ancho_medio]:
		var base: Vector3 = p + der * lado
		var _tope := base + Vector3(0, alto_portico, 0)
		var grosor := 0.5
		var c1 := base - der * (grosor * 0.5 * signf(lado)) - ade * grosor
		var c2 := base + der * (grosor * 0.5 * signf(lado)) - ade * grosor
		var c3 := base + der * (grosor * 0.5 * signf(lado)) + ade * grosor
		var c4 := base - der * (grosor * 0.5 * signf(lado)) + ade * grosor

		var t1 := c1 + Vector3(0, alto_portico, 0)
		var t2 := c2 + Vector3(0, alto_portico, 0)
		var t3 := c3 + Vector3(0, alto_portico, 0)
		var t4 := c4 + Vector3(0, alto_portico, 0)

		_agregar_quad_plano(v_m, n_m, c1, c2, t2, t1)
		_agregar_quad_plano(v_m, n_m, c2, c3, t3, t2)
		_agregar_quad_plano(v_m, n_m, c3, c4, t4, t3)
		_agregar_quad_plano(v_m, n_m, c4, c1, t1, t4)

	# Viga transversal superior del arco
	var _y_viga := p.y + alto_portico - 0.5
	var g_izq := p + der * -ancho_medio + Vector3(0, alto_portico, 0)
	var g_der := p + der * ancho_medio + Vector3(0, alto_portico, 0)
	var v_front_izq := g_izq - ade * 0.4
	var v_front_der := g_der - ade * 0.4
	var v_back_izq := g_izq + ade * 0.4
	var v_back_der := g_der + ade * 0.4
	var v_bot_front_izq := v_front_izq - Vector3(0, 1.0, 0)
	var v_bot_front_der := v_front_der - Vector3(0, 1.0, 0)
	var v_bot_back_izq := v_back_izq - Vector3(0, 1.0, 0)
	var v_bot_back_der := v_back_der - Vector3(0, 1.0, 0)

	_agregar_quad_plano(v_m, n_m, v_bot_front_izq, v_bot_front_der, v_front_der, v_front_izq)
	_agregar_quad_plano(v_m, n_m, v_front_izq, v_front_der, v_back_der, v_back_izq)
	_agregar_quad_plano(v_m, n_m, v_bot_back_der, v_bot_back_izq, v_back_izq, v_back_der)
	_agregar_quad_plano(v_m, n_m, v_bot_back_izq, v_bot_back_der, v_bot_front_der, v_bot_front_izq)

	# Letrero de Neón en la cara frontal del arco (mirando hacia los corredores que se acercan)
	var n_f_izq := v_bot_front_izq + Vector3(0, 0.2, 0) - ade * 0.05 + der * 1.5
	var n_f_der := v_bot_front_der + Vector3(0, 0.2, 0) - ade * 0.05 - der * 1.5
	var n_t_izq := n_f_izq + Vector3(0, 0.6, 0)
	var n_t_der := n_f_der + Vector3(0, 0.6, 0)
	_agregar_quad_plano(v_n, n_n, n_f_izq, n_f_der, n_t_der, n_t_izq)

	add_child(_crear_malla(v_m, n_m, mat_metal))
	add_child(_crear_malla(v_n, n_n, mat_neon))

# ------------------------------------------------------------------ 5. Low-City (Edificios, Skyline, Farolas, Gruas)
func _construir_lowcity() -> void:
	var escena_a: PackedScene = load("res://Modelos_Escenario/edificio_a.glb")
	var escena_b: PackedScene = load("res://Modelos_Escenario/edificio_b.glb")
	var escena_c: PackedScene = load("res://Modelos_Escenario/edificio_c.glb")
	var escena_grua: PackedScene = load("res://Modelos_Escenario/grua_torre.glb")
	var escena_farola: PackedScene = load("res://Modelos_Escenario/farola_urbana.glb")

	var mesh_a := _obtener_mesh_de_escena(escena_a)
	var mesh_b := _obtener_mesh_de_escena(escena_b)
	var mesh_c := _obtener_mesh_de_escena(escena_c)
	var mesh_grua := _obtener_mesh_de_escena(escena_grua)
	var mesh_farola := _obtener_mesh_de_escena(escena_farola)

	var largo_pista: float = _pista.largo if "largo" in _pista else 1500.0
	var mitad_pista: float = (_pista.ancho * 0.5) if "ancho" in _pista else 7.0
	var s_meta: float = _pista.s_meta if "s_meta" in _pista else 0.0

	# 1. FAROLAS URBANAS (a lo largo de las barandas, paso ~28m)
	if mesh_farola:
		var paso_f := 28.0
		var n_farolas := int(floor(largo_pista / paso_f))
		var mm_farola := MultiMesh.new()
		mm_farola.transform_format = MultiMesh.TRANSFORM_3D
		mm_farola.mesh = mesh_farola
		mm_farola.instance_count = n_farolas

		for i in range(n_farolas):
			var s := float(i) * paso_f
			var p: Vector3 = _pista.pos_en(s)
			var der: Vector3 = _pista.der_en(s)
			var lado: float = 1.0 if (i % 2 == 0) else -1.0
			var pos_f: Vector3 = p + der * ((mitad_pista + 0.8) * lado)
			var hacia_pista: Vector3 = (p - pos_f).normalized()

			var t := Transform3D()
			t.basis.x = hacia_pista
			t.basis.y = Vector3.UP
			t.basis.z = hacia_pista.cross(Vector3.UP).normalized()
			t.origin = pos_f
			mm_farola.set_instance_transform(i, t)

		var mmi_f := MultiMeshInstance3D.new()
		mmi_f.name = "FarolasMultiMesh"
		mmi_f.multimesh = mm_farola
		add_child(mmi_f)

	# 2. EDIFICIOS MEDIOS (Edificio A y Edificio B flanqueando el circuito)
	var paso_edif := 34.0
	var n_pasos := int(floor(largo_pista / paso_edif))
	
	var transforms_a: Array[Transform3D] = []
	var transforms_b: Array[Transform3D] = []

	for i in range(n_pasos):
		var s := float(i) * paso_edif
		var p: Vector3 = _pista.pos_en(s)
		var der: Vector3 = _pista.der_en(s)

		# Colocar edificios en ambos lados con variaciones
		for lado in [-1.0, 1.0]:
			var seed_val := float(i * 3 + int(lado * 2.0) + 17)
			var r1 := fposmod(sin(seed_val * 12.9898) * 43758.5453, 1.0)
			var r2 := fposmod(sin((seed_val + 3.1) * 78.233) * 21345.1234, 1.0)

			var dist: float = 16.0 + r1 * 10.0
			var pos_ed: Vector3 = p + der * (dist * lado)
			pos_ed.y = minf(p.y - 0.2, altura_suelo_base)

			var hacia_p: Vector3 = (p - pos_ed)
			hacia_p.y = 0.0
			hacia_p = hacia_p.normalized()

			var escala_y := 0.85 + r2 * 0.5
			var escala_xz := 0.9 + r1 * 0.25

			var basis_e := Basis.looking_at(-hacia_p, Vector3.UP)
			basis_e = basis_e.scaled(Vector3(escala_xz, escala_y, escala_xz))
			var t := Transform3D(basis_e, pos_ed)

			if int(seed_val) % 2 == 0:
				transforms_a.append(t)
			else:
				transforms_b.append(t)

	if mesh_a and transforms_a.size() > 0:
		var mm_a := MultiMesh.new()
		mm_a.transform_format = MultiMesh.TRANSFORM_3D
		mm_a.mesh = mesh_a
		mm_a.instance_count = transforms_a.size()
		for i in range(transforms_a.size()):
			mm_a.set_instance_transform(i, transforms_a[i])
		var mmi_a := MultiMeshInstance3D.new()
		mmi_a.name = "EdificiosA_MultiMesh"
		mmi_a.multimesh = mm_a
		add_child(mmi_a)

	if mesh_b and transforms_b.size() > 0:
		var mm_b := MultiMesh.new()
		mm_b.transform_format = MultiMesh.TRANSFORM_3D
		mm_b.mesh = mesh_b
		mm_b.instance_count = transforms_b.size()
		for i in range(transforms_b.size()):
			mm_b.set_instance_transform(i, transforms_b[i])
		var mmi_b := MultiMeshInstance3D.new()
		mmi_b.name = "EdificiosB_MultiMesh"
		mmi_b.multimesh = mm_b
		add_child(mmi_b)

	# 3. RASCACIELOS DE FONDO / SKYLINE (Edificio C - torres monumentales)
	if mesh_c:
		var paso_c := 60.0
		var n_c := int(floor(largo_pista / paso_c))
		var transforms_c: Array[Transform3D] = []

		for i in range(n_c):
			var s := float(i) * paso_c + 12.0
			var p: Vector3 = _pista.pos_en(s)
			var der: Vector3 = _pista.der_en(s)
			var lado := 1.0 if (i % 2 == 0) else -1.0
			var r := fposmod(sin(float(i) * 37.123) * 65432.1, 1.0)

			var dist: float = 50.0 + r * 45.0
			var pos_c: Vector3 = p + der * (dist * lado)
			pos_c.y = altura_suelo_base

			var escala_y := 1.2 + r * 1.4
			var escala_xz := 1.1 + r * 0.4

			var rot_y := r * TAU
			var basis_c := Basis(Vector3.UP, rot_y)
			basis_c = basis_c.scaled(Vector3(escala_xz, escala_y, escala_xz))
			transforms_c.append(Transform3D(basis_c, pos_c))

		if transforms_c.size() > 0:
			var mm_c := MultiMesh.new()
			mm_c.transform_format = MultiMesh.TRANSFORM_3D
			mm_c.mesh = mesh_c
			mm_c.instance_count = transforms_c.size()
			for i in range(transforms_c.size()):
				mm_c.set_instance_transform(i, transforms_c[i])
			var mmi_c := MultiMeshInstance3D.new()
			mmi_c.name = "Skyline_MultiMesh"
			mmi_c.multimesh = mm_c
			add_child(mmi_c)

	# 4. GRUAS TORRE (gruas en construccion con luces amarillas en el horizonte)
	if mesh_grua:
		var mm_grua := MultiMesh.new()
		mm_grua.transform_format = MultiMesh.TRANSFORM_3D
		mm_grua.mesh = mesh_grua
		mm_grua.instance_count = 4

		var puntos_grua: Array[float] = [
			s_meta + 80.0,
			s_meta + 450.0,
			s_meta + 850.0,
			s_meta + 1250.0
		]
		for g in range(4):
			var s := puntos_grua[g]
			var p: Vector3 = _pista.pos_en(s)
			var der: Vector3 = _pista.der_en(s)
			var lado := 1.0 if (g % 2 == 0) else -1.0
			var pos_g: Vector3 = p + der * ((45.0 + float(g) * 8.0) * lado)
			pos_g.y = altura_suelo_base

			var rot_y := float(g) * 1.6 + 0.5
			var basis_g := Basis(Vector3.UP, rot_y).scaled(Vector3(1.3, 1.4, 1.3))
			mm_grua.set_instance_transform(g, Transform3D(basis_g, pos_g))

		var mmi_grua := MultiMeshInstance3D.new()
		mmi_grua.name = "GruasTorre_MultiMesh"
		mmi_grua.multimesh = mm_grua
		add_child(mmi_grua)

	# 5. LETREROS NEON CUSTOMVELOZ
	_crear_letrero_neon(s_meta + 25.0, -18.0, 7.5)
	_crear_letrero_neon(s_meta + 300.0, 20.0, 9.0)
	_crear_letrero_neon(s_meta + 700.0, -22.0, 8.0)

func _crear_letrero_neon(s: float, lado_dist: float, altura: float) -> void:
	if not _pista:
		return
	var p: Vector3 = _pista.pos_en(s)
	var der: Vector3 = _pista.der_en(s)
	var pos: Vector3 = p + der * lado_dist + Vector3(0, altura, 0)

	var hacia_pista: Vector3 = (p - pos)
	hacia_pista.y = 0.0
	hacia_pista = hacia_pista.normalized()

	var lbl := Label3D.new()
	lbl.text = "CUSTOMVELOZ"
	lbl.font_size = 54
	lbl.modulate = C_NEON_AZUL
	lbl.outline_modulate = Color(0.0, 0.3, 0.4)
	lbl.outline_size = 8
	lbl.position = pos
	lbl.basis = Basis.looking_at(-hacia_pista, Vector3.UP)
	add_child(lbl)

# ------------------------------------------------------------------ 6. Público Animado (MultiMesh Low-Poly)
var _publico_salto: MultiMeshInstance3D
var _publico_arriba: MultiMeshInstance3D
var _tiempo_publico := 0.0

func _construir_publico() -> void:
	var esc_arriba: PackedScene = load("res://Modelos_Escenario/espectador_brazos_arriba.glb")
	var esc_aplauso: PackedScene = load("res://Modelos_Escenario/espectador_aplaudiendo.glb")
	var esc_mira: PackedScene = load("res://Modelos_Escenario/espectador_mirando.glb")
	var esc_salto: PackedScene = load("res://Modelos_Escenario/espectador_saltando.glb")

	var m_arriba := _obtener_mesh_de_escena(esc_arriba)
	var m_aplauso := _obtener_mesh_de_escena(esc_aplauso)
	var m_mira := _obtener_mesh_de_escena(esc_mira)
	var m_salto := _obtener_mesh_de_escena(esc_salto)

	if not (m_arriba and m_aplauso and m_mira and m_salto):
		return

	var mms: Array[MultiMesh] = []
	var mmis: Array[MultiMeshInstance3D] = []
	var meshes: Array[Mesh] = [m_arriba, m_aplauso, m_mira, m_salto]

	var cantidad_por_pose := 50
	for idx in range(4):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[idx]
		mm.instance_count = cantidad_por_pose
		mms.append(mm)

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Publico_Pose_%d" % idx
		mmi.multimesh = mm
		add_child(mmi)
		mmis.append(mmi)

	_publico_arriba = mmis[0]
	_publico_salto = mmis[3]

	var mitad_pista: float = (_pista.ancho * 0.5) if "ancho" in _pista else 7.0
	var largo_pista: float = _pista.largo if "largo" in _pista else 1500.0
	var s_meta: float = _pista.s_meta if "s_meta" in _pista else 0.0

	var conteo := [0, 0, 0, 0]

	# Distribucion de ~200 espectadores:
	# 120 concentrados en la recta de meta (tribunas a ambos lados)
	# 80 distribuidos en curvas clave
	var puntos_s: Array[float] = []
	# Recta meta
	for i in range(60):
		var offset_s := (float(i) - 30.0) * 3.5
		puntos_s.append(s_meta + offset_s)
		puntos_s.append(s_meta + offset_s)

	# Curvas
	for c in [0.25, 0.45, 0.70, 0.85]:
		for i in range(10):
			puntos_s.append(largo_pista * c + float(i) * 3.0)
			puntos_s.append(largo_pista * c + float(i) * 3.0)

	var total_puntos := puntos_s.size()
	for i in range(total_puntos):
		var pose_idx := i % 4
		if conteo[pose_idx] >= cantidad_por_pose:
			continue

		var s: float = puntos_s[i]
		var p: Vector3 = _pista.pos_en(s)
		var der: Vector3 = _pista.der_en(s)
		var lado := 1.0 if (i % 2 == 0) else -1.0

		var r_dist: float = fposmod(sin(float(i) * 19.123) * 31415.9, 1.0)
		var dist: float = mitad_pista + 1.2 + r_dist * 1.8
		var pos_esp: Vector3 = p + der * (dist * lado)
		pos_esp.y = p.y

		var hacia_p: Vector3 = (p - pos_esp)
		hacia_p.y = 0.0
		hacia_p = hacia_p.normalized()

		# Variacion sutil de rotacion para naturalidad
		var ang_var := (r_dist - 0.5) * 0.4
		var basis_esp := Basis.looking_at(-hacia_p, Vector3.UP).rotated(Vector3.UP, ang_var)
		var t := Transform3D(basis_esp, pos_esp)

		mms[pose_idx].set_instance_transform(conteo[pose_idx], t)
		conteo[pose_idx] += 1

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_tiempo_publico += delta
	if _publico_salto:
		_publico_salto.position.y = sin(_tiempo_publico * 5.2) * 0.09
	if _publico_arriba:
		_publico_arriba.position.y = sin(_tiempo_publico * 4.4 + 1.0) * 0.07

static func _obtener_mesh_de_escena(escena: PackedScene) -> Mesh:
	if not escena:
		return null
	var inst: Node = escena.instantiate()
	var mesh: Mesh = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var actual = stack.pop_back()
		if actual is MeshInstance3D and actual.mesh:
			mesh = actual.mesh
			break
		for c in actual.get_children():
			stack.append(c)
	inst.queue_free()
	return mesh

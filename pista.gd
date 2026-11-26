@tool
extends Node3D

# CustomVeloz - Circuito cerrado low poly (Documento de concepto: "una pista cerrada en Low Poly",
# 3 vueltas, esfera verde +15 km/h, tramo de conos, semaforo en la grilla).
# La pista se genera sola a partir de una lista de puntos (curva suave Catmull-Rom):
# para cambiar el trazado solo se editan "puntos" (x, z en metros) y "alturas" (y en metros).
# La meta esta en el punto "indice_meta"; el carro arranca 11 m antes de la meta, mirando a -Z.

const C_ASFALTO := Color("#263238")
const C_BORDE := Color("#00E5FF")
const C_VERDE := Color(0.0, 1.0, 0.25) # Verde Neón Esmeralda Puro (Alerón / Mejora) - Cero Rojo
const C_AMARILLO := Color(1.0, 0.85, 0.0) # Amarillo Dorado / Fuego (Turbo)
const C_DANO := Color("#FF5722")
const C_LINEA := Color("#90A4AE")
const C_ROJO_COMBATE := Color(1.0, 0.1, 0.05) # Rojo neón para esfera de cohete
const PASOS_DENSOS := 40

@export var ancho := 14.0 # m de ancho de la pista
@export var paso := 5.0 # m entre cortes (low poly: mas grande = mas faceteado)
@export var alto_muro := 1.4
@export var grosor_muro := 0.5
@export var segmentos_por_tramo := 20 # cada tramo es una malla aparte (para que las luces no se salten)
@export var vueltas := 3
@export var cuenta_atras := 3.0 # s del semaforo antes de arrancar
@export var checkpoints_n := 8
@export var indice_meta := 1
# Trazado (x, z). Va hacia -Z en la meta y gira a la derecha (sentido horario visto desde arriba).
@export var puntos := PackedVector2Array([
	Vector2(0, 100), Vector2(0, 0), Vector2(0, -110), Vector2(30, -200), Vector2(100, -260),
	Vector2(200, -270), Vector2(280, -220), Vector2(310, -140), Vector2(280, -60), Vector2(210, -30),
	Vector2(140, -50), Vector2(90, 15), Vector2(110, 95), Vector2(185, 150), Vector2(255, 220),
	Vector2(230, 300), Vector2(140, 330), Vector2(50, 290), Vector2(-15, 220), Vector2(-15, 150)])
# Altura (y) de cada punto: loma este suave y continua (evita saltos bruscos).
@export var alturas := PackedFloat32Array([
	0.0, 0.0, 0.0, 0.0, 1.5, 4.5, 8.5, 12.0, 10.5, 7.5,
	4.5, 2.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
# Posicion de las 6 esferas verdes de ALERON (escasas, cada ~290 m)
@export var esferas_s := PackedFloat32Array([
	140.0, 440.0, 740.0, 1040.0, 1340.0, 1640.0])
@export var esferas_lado := PackedFloat32Array([
	-2.5, 2.5, -3.0, 3.0, 0.0, 2.5])
@export var mejora_kmh := 15.0
# Posicion de las 6 esferas amarillas de TURBO (escasas, cada ~290 m, desfasadas)
@export var esferas_nitro_s := PackedFloat32Array([
	280.0, 580.0, 880.0, 1180.0, 1480.0, 1750.0])
@export var esferas_nitro_lado := PackedFloat32Array([
	2.5, -2.5, 3.0, -3.0, 2.5, -2.5])

var centro: Array[Vector3] = []
var derecha: Array[Vector3] = []
var largo := 0.0
var s_meta := 0.0

# Estado de la carrera (lo lee el HUD)
var en_cuenta := true
var texto_cuenta := ""
var siguiente_cp := 0
var n_cp := 0
var vuelta_pendiente := false

var _t_cuenta := 0.0
var _t_ya := 0.0
var _lamparas: Array[MeshInstance3D] = []
var _mats_lampara: Array[StandardMaterial3D] = []
var _esferas: Array[Node3D] = []
var _reloj := 0.0

func _ready() -> void:
	add_to_group("pista")
	_muestrear()
	_construir_visual()
	if Engine.is_editor_hint():
		return
	_construir_juego.call_deferred()

# ------------------------------------------------------------------ trazado
static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)

func _muestrear() -> void:
	centro.clear()
	derecha.clear()
	var n := puntos.size()
	var densos: Array[Vector3] = []
	var meta_denso := 0
	for i in n:
		if i == indice_meta:
			meta_denso = densos.size()
		var a := puntos[(i - 1 + n) % n]
		var b := puntos[i]
		var c := puntos[(i + 1) % n]
		var d := puntos[(i + 2) % n]
		var ya := alturas[(i - 1 + n) % n]
		var yb := alturas[i]
		var yc := alturas[(i + 1) % n]
		var yd := alturas[(i + 2) % n]
		for k in PASOS_DENSOS:
			var t := float(k) / float(PASOS_DENSOS)
			densos.append(Vector3(_cr(a.x, b.x, c.x, d.x, t), _cr(ya, yb, yc, yd, t), _cr(a.y, b.y, c.y, d.y, t)))
	var nd := densos.size()
	var acum: Array[float] = [0.0]
	for i in range(1, nd + 1):
		acum.append(acum[i - 1] + densos[i - 1].distance_to(densos[i % nd]))
	largo = acum[nd]
	s_meta = acum[meta_denso]
	var m := maxi(8, roundi(largo / paso))
	var idx := 0
	for j in m:
		var objetivo := largo * float(j) / float(m)
		while idx < nd - 1 and acum[idx + 1] < objetivo:
			idx += 1
		var f := inverse_lerp(acum[idx], acum[idx + 1], objetivo)
		centro.append(densos[idx].lerp(densos[(idx + 1) % nd], f))
	for j in m:
		var tg := centro[(j + 1) % m] - centro[(j - 1 + m) % m]
		tg.y = 0.0
		tg = tg.normalized()
		derecha.append(Vector3(-tg.z, 0.0, tg.x))

# Posicion sobre la linea central a s metros desde el inicio del trazado (con vuelta)
func pos_en(s: float) -> Vector3:
	var m := centro.size()
	var u := fposmod(s, largo) / largo * float(m)
	var i := int(floor(u)) % m
	return centro[i].lerp(centro[(i + 1) % m], u - floor(u))

func der_en(s: float) -> Vector3:
	var m := centro.size()
	var u := fposmod(s, largo) / largo * float(m)
	var i := int(floor(u)) % m
	return derecha[i].lerp(derecha[(i + 1) % m], u - floor(u)).normalized()

func adelante_en(s: float) -> Vector3:
	return Vector3.UP.cross(der_en(s)).normalized()

# ------------------------------------------------------------------ mallas
static func _quad(v: PackedVector3Array, nr: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, arriba: bool = false) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 0.000001:
		n = (c - a).cross(d - a)
	n = n.normalized()
	if arriba and n.y < 0.0:
		n = -n
	for p in [a, b, c, a, c, d]:
		v.append(p)
		nr.append(n)

func _malla(v: PackedVector3Array, nr: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi

func _construir_visual() -> void:
	var m := centro.size()
	var mat_pista := StandardMaterial3D.new()
	mat_pista.albedo_color = C_ASFALTO
	mat_pista.roughness = 0.9
	mat_pista.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_linea := StandardMaterial3D.new()
	mat_linea.albedo_color = C_LINEA
	mat_linea.roughness = 0.9
	mat_linea.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_muro := StandardMaterial3D.new()
	mat_muro.albedo_color = C_BORDE
	mat_muro.emission_enabled = true
	mat_muro.emission = C_BORDE
	mat_muro.emission_energy_multiplier = 1.5
	mat_muro.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mitad := ancho * 0.5
	var i0 := 0
	while i0 < m:
		var i1 := mini(i0 + segmentos_por_tramo, m)
		var vp := PackedVector3Array()
		var np := PackedVector3Array()
		var vl := PackedVector3Array()
		var nl := PackedVector3Array()
		var vm := PackedVector3Array()
		var nm := PackedVector3Array()
		for i in range(i0, i1):
			var j := (i + 1) % m
			var l_i := centro[i] - derecha[i] * mitad
			var r_i := centro[i] + derecha[i] * mitad
			var l_j := centro[j] - derecha[j] * mitad
			var r_j := centro[j] + derecha[j] * mitad
			_quad(vp, np, l_i, r_i, r_j, l_j, true)
			# linea central discontinua (un tramo si, uno no)
			if i % 2 == 0:
				var sube := Vector3(0, 0.04, 0)
				var ci := centro[i] + sube
				var cj := centro[j] + sube
				_quad(vl, nl, ci - derecha[i] * 0.17, ci + derecha[i] * 0.17, cj + derecha[j] * 0.17, cj - derecha[j] * 0.17, true)
			# muros de los dos bordes
			for signo in [-1.0, 1.0]:
				var e_i: Vector3 = centro[i] + derecha[i] * mitad * signo
				var e_j: Vector3 = centro[j] + derecha[j] * mitad * signo
				var o_i: Vector3 = e_i + derecha[i] * grosor_muro * signo
				var o_j: Vector3 = e_j + derecha[j] * grosor_muro * signo
				var up := Vector3.UP * alto_muro
				_quad(vm, nm, e_i, e_i + up, e_j + up, e_j)
				_quad(vm, nm, e_i + up, o_i + up, o_j + up, e_j + up)
				_quad(vm, nm, o_i + up, o_i, o_j, o_j + up)
		add_child(_malla(vp, np, mat_pista))
		add_child(_malla(vl, nl, mat_linea))
		# Muro visual solido celeste reemplazado por barandas metalicas modulares
		# (la colision invisible de vm se mantiene abajo en caras)
		# colision: piso y muros del tramo
		var caras := PackedVector3Array()
		caras.append_array(vp)
		caras.append_array(vm)
		var forma := ConcavePolygonShape3D.new()
		forma.set_faces(caras)
		forma.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.shape = forma
		var cuerpo := StaticBody3D.new()
		cuerpo.add_child(cs)
		add_child(cuerpo)
		i0 = i1
	_linea_de_meta()
	_construir_barandas()

func _construir_barandas() -> void:
	var escena_baranda: PackedScene = load("res://Modelos_Escenario/baranda_modulo.glb")
	if not escena_baranda:
		return
	var malla_baranda := _obtener_mesh_de_escena(escena_baranda)
	if not malla_baranda:
		return

	var paso_baranda := 2.7
	var cantidad_por_lado := int(floor(largo / paso_baranda))
	if cantidad_por_lado <= 0:
		return

	var total_instancias := cantidad_por_lado * 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malla_baranda
	mm.instance_count = total_instancias

	var mitad := ancho * 0.5
	var idx := 0

	for k in range(cantidad_por_lado):
		var s := float(k) * paso_baranda
		var p1 := pos_en(s)
		var p2 := pos_en(s + 1.0)
		var fwd := (p2 - p1).normalized()
		var der := der_en(s)
		var up := der.cross(fwd).normalized()
		var side := fwd.cross(up).normalized()

		# Lado izquierdo (signo -1.0)
		var pos_izq := p1 - der * mitad
		var t_izq := Transform3D()
		t_izq.basis.x = fwd
		t_izq.basis.y = up
		t_izq.basis.z = side
		t_izq.origin = pos_izq
		mm.set_instance_transform(idx, t_izq)
		idx += 1

		# Lado derecho (signo 1.0)
		var pos_der := p1 + der * mitad
		var t_der := Transform3D()
		t_der.basis.x = -fwd
		t_der.basis.y = up
		t_der.basis.z = -side
		t_der.origin = pos_der
		mm.set_instance_transform(idx, t_der)
		idx += 1

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "BarandasMultiMesh"
	mmi.multimesh = mm
	add_child(mmi)

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

func _linea_de_meta() -> void:
	var p := pos_en(s_meta)
	var der := der_en(s_meta)
	var ade := adelante_en(s_meta)
	var vb := PackedVector3Array()
	var nb := PackedVector3Array()
	var vn := PackedVector3Array()
	var nn := PackedVector3Array()
	var cols := int(ancho)
	for c in cols:
		for r in 2:
			var a := p + der * (-ancho * 0.5 + float(c)) + ade * (float(r) - 1.0) + Vector3(0, 0.05, 0)
			var b := a + der
			var d := a + ade
			var e := b + ade
			if (c + r) % 2 == 0:
				_quad(vb, nb, a, b, e, d, true)
			else:
				_quad(vn, nn, a, b, e, d, true)
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.95, 0.95, 0.95)
	mb.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mn := StandardMaterial3D.new()
	mn.albedo_color = Color(0.03, 0.03, 0.04)
	mn.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(_malla(vb, nb, mb))
	add_child(_malla(vn, nn, mn))

# ------------------------------------------------------------------ juego (solo al jugar)
func _material_brillo(color: Color, energia: float = 1.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energia
	return mat

func _area(padre: Node, pos: Vector3, yaw: float, tam: Vector3) -> Area3D:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	a.add_child(cs)
	padre.add_child(a)
	a.position = pos
	a.rotation.y = yaw
	return a

func _yaw(ade: Vector3) -> float:
	return atan2(-ade.x, -ade.z)

func _construir_juego() -> void:
	_semaforo()
	_checkpoints_y_meta()
	_esferas_verdes()
	_esferas_amarillas()
	_esferas_cohete()
	_conos()
	_chicanas()
	_luces_neon()
	_preparar_carrera()

func _semaforo() -> void:
	var p := pos_en(s_meta)
	var der := der_en(s_meta)
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.1, 0.12, 0.14)
	for signo in [-1.0, 1.0]:
		var poste := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 7.0, 0.5)
		bm.material = mat_metal
		poste.mesh = bm
		add_child(poste)
		poste.position = p + der * (ancho * 0.5 + 1.2) * signo + Vector3(0, 3.5, 0)
	var barra := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(ancho + 3.0, 0.7, 0.7)
	bb.material = mat_metal
	barra.mesh = bb
	add_child(barra)
	barra.position = p + Vector3(0, 7.0, 0)
	for k in 3:
		var lampara := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		var mat := _material_brillo(Color(0.12, 0.05, 0.05), 0.0)
		sm.material = mat
		lampara.mesh = sm
		add_child(lampara)
		lampara.position = p + der * (float(k) - 1.0) * 2.4 + Vector3(0, 6.0, 0)
		_lamparas.append(lampara)
		_mats_lampara.append(mat)

func _checkpoints_y_meta() -> void:
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	add_child(cps)
	n_cp = checkpoints_n - 1
	for k in n_cp:
		var s := s_meta + largo * float(k + 1) / float(checkpoints_n)
		var a := _area(cps, pos_en(s) + Vector3(0, 1.5, 0), _yaw(adelante_en(s)), Vector3(ancho + 2.0, 6.0, 2.0))
		a.name = "CP%d" % (k + 1)
		a.body_entered.connect(_on_cp.bind(k))
	var meta := _area(self, pos_en(s_meta) + Vector3(0, 2.0, 0), _yaw(adelante_en(s_meta)), Vector3(ancho + 2.0, 5.0, 2.0))
	meta.name = "Meta"
	meta.body_entered.connect(_on_meta)

func _on_cp(body: Node3D, k: int) -> void:
	if body.is_in_group("jugador"):
		# Seguimiento de checkpoint por carro individual
		var cp_actual: int = body.get("siguiente_cp") if body.get("siguiente_cp") != null else siguiente_cp
		if k == cp_actual:
			if body.get("siguiente_cp") != null:
				body.siguiente_cp += 1
			else:
				siguiente_cp += 1
			var partida := get_tree().get_first_node_in_group("partida")
			if partida and partida.has_method("registrar_checkpoint_split"):
				# Solo registrar split para Jugador 1
				if body.get("jugador_id") == null or body.get("jugador_id") == 1:
					partida.registrar_checkpoint_split(k)
		var respawn = get_tree().get_first_node_in_group("respawn")
		if respawn:
			if respawn.has_method("registrar_checkpoint_jugador"):
				respawn.registrar_checkpoint_jugador(body, body.global_position, body.global_rotation.y)
			elif respawn.has_method("registrar_checkpoint"):
				respawn.registrar_checkpoint(body.global_position, body.global_rotation.y)

func _on_meta(body: Node3D) -> void:
	if not body.is_in_group("jugador"):
		return
	# Usar checkpoint por carro individual
	var cp_actual: int = body.get("siguiente_cp") if body.get("siguiente_cp") != null else siguiente_cp
	if cp_actual >= n_cp:
		if body.get("siguiente_cp") != null:
			body.siguiente_cp = 0
		else:
			siguiente_cp = 0
		# Reactivar las esferas para la siguiente vuelta
		for e in _esferas:
			e.visible = true
			e.set_deferred("monitoring", true)
		var partida := get_tree().get_first_node_in_group("partida")
		var jid: int = body.get("jugador_id") if body.get("jugador_id") != null else 1
		if ConfigJuego.dos_jugadores:
			if partida and partida.has_method("avisar_meta_jugador"):
				partida.avisar_meta_jugador(jid)
		else:
			if partida and partida.has_method("avisar_meta"):
				partida.avisar_meta()

func _esferas_verdes() -> void:
	for k in esferas_s.size():
		var s := s_meta + esferas_s[k]
		var pos := pos_en(s) + der_en(s) * esferas_lado[k] + Vector3(0, 1.2, 0)
		var a := _area(self, pos, 0.0, Vector3(2.6, 2.6, 2.6))
		a.name = "EsferaVerde%d" % (k + 1)
		# Esfera verde esmeralda pura (Alerón = +velocidad temporal)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		sm.radial_segments = 12
		sm.rings = 6
		sm.material = _material_brillo(C_VERDE, 2.8)
		mi.mesh = sm
		a.add_child(mi)
		_esferas.append(a)
		a.body_entered.connect(_on_esfera.bind(a))

func _reaparecer_esfera(a: Area3D, demora: float = 1.0) -> void:
	get_tree().create_timer(demora).timeout.connect(func():
		if is_instance_valid(a):
			a.visible = true
			a.set_deferred("monitoring", true)
	)

func _on_esfera(body: Node3D, a: Area3D) -> void:
	if not body.is_in_group("jugador") or not a.visible:
		return
	a.visible = false
	a.set_deferred("monitoring", false)
	_reaparecer_esfera(a, 1.0)
	if body.has_method("aplicar_mejora"):
		body.aplicar_mejora(mejora_kmh)
	var eventos = get_tree().get_first_node_in_group("eventos")
	if eventos and eventos.has_method("_on_evento"):
		eventos._on_evento(a.global_position)
	print("[pista] esfera verde: +", mejora_kmh, " km/h de velocidad maxima")

func _esferas_amarillas() -> void:
	for k in esferas_nitro_s.size():
		var s := s_meta + esferas_nitro_s[k]
		var pos := pos_en(s) + der_en(s) * esferas_nitro_lado[k] + Vector3(0, 1.2, 0)
		var a := _area(self, pos, 0.0, Vector3(3.2, 3.2, 3.2))
		a.name = "EsferaTurbo%d" % (k + 1)
		# Esfera central dorada de turbo
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.50
		sm.height = 1.0
		sm.radial_segments = 12
		sm.rings = 6
		sm.material = _material_brillo(C_AMARILLO, 3.2)
		mi.mesh = sm
		a.add_child(mi)
		# Anillo orbital dorado (TorusMesh) para que se distinga instantáneamente
		var anillo := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.65
		tm.outer_radius = 0.90
		tm.rings = 16
		tm.ring_segments = 8
		tm.material = _material_brillo(C_AMARILLO, 2.5)
		anillo.mesh = tm
		anillo.name = "AnilloTurbo"
		anillo.rotation_degrees = Vector3(45.0, 0.0, 0.0)
		a.add_child(anillo)
		_esferas.append(a)
		a.body_entered.connect(_on_esfera_nitro.bind(a))

func _on_esfera_nitro(body: Node3D, a: Area3D) -> void:
	if not body.is_in_group("jugador") or not a.visible:
		return
	a.visible = false
	a.set_deferred("monitoring", false)
	_reaparecer_esfera(a, 1.0)
	var n = body.get_node_or_null("Nitro")
	if n and n.has_method("recargar_nitro"):
		n.recargar_nitro(1.0)
	body.velocity += -body.global_transform.basis.z * 5.5
	var eventos = get_tree().get_first_node_in_group("eventos")
	if eventos and eventos.has_method("_on_evento"):
		eventos._on_evento(a.global_position)
	print("[pista] esfera amarilla: TURBO 100% recargado + impulso")

# ------------------------------------------------------------------ esferas de cohete (rojo combate)
# Se colocan 4 esferas rojas escasas en puntos clave del circuito (cada ~440 m)
# Al recogerla entrega 1 cohete (máx 3 almacenados).
func _esferas_cohete() -> void:
	var posiciones_s := PackedFloat32Array([
		210.0, 660.0, 1110.0, 1560.0
	])
	var lados := PackedFloat32Array([
		0.0, 3.0, -3.0, 0.0
	])
	for k in posiciones_s.size():
		var s := s_meta + posiciones_s[k]
		var pos := pos_en(s) + der_en(s) * lados[k] + Vector3(0, 1.3, 0)
		var a := _area(self, pos, 0.0, Vector3(3.0, 3.0, 3.0))
		a.name = "EsferaCohete%d" % (k + 1)
		# Esfera roja central
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.48
		sm.height = 0.96
		sm.radial_segments = 10
		sm.rings = 5
		sm.material = _material_brillo(C_ROJO_COMBATE, 3.5)
		mi.mesh = sm
		a.add_child(mi)
		# Anillo orbital rojo (lo diferencia visualmente de las otras esferas)
		var anillo := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.62
		tm.outer_radius = 0.86
		tm.rings = 14
		tm.ring_segments = 7
		tm.material = _material_brillo(C_ROJO_COMBATE, 2.0)
		anillo.mesh = tm
		anillo.name = "AnilloCohete"
		anillo.rotation_degrees = Vector3(45.0, 0.0, 0.0)
		a.add_child(anillo)
		# Icono de cohete: pequeño cilindro naranja apuntando arriba
		var icono := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.08
		cm.height = 0.28
		cm.radial_segments = 6
		cm.material = _material_brillo(Color(1.0, 0.45, 0.0), 2.5)
		icono.mesh = cm
		icono.position = Vector3(0.0, 0.0, 0.0)
		icono.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		a.add_child(icono)
		_esferas.append(a)
		a.body_entered.connect(_on_esfera_cohete.bind(a))

func _on_esfera_cohete(body: Node3D, a: Area3D) -> void:
	if not body.is_in_group("jugador") or not a.visible:
		return
	a.visible = false
	a.set_deferred("monitoring", false)
	_reaparecer_esfera(a, 1.0)
	if body.has_method("recoger_cohete"):
		body.recoger_cohete()
	var eventos = get_tree().get_first_node_in_group("eventos")
	if eventos and eventos.has_method("_on_evento"):
		eventos._on_evento(a.global_position)
	print("[pista] esfera roja: cohete recogido")

func _conos() -> void:
	# Conos de tráfico dinámicos con física realista distribuidos por todo el circuito
	var mat_naranja := StandardMaterial3D.new()
	mat_naranja.albedo_color = Color(1.0, 0.28, 0.0) # Naranja seguridad
	mat_naranja.roughness = 0.35
	mat_naranja.emission_enabled = true
	mat_naranja.emission = Color(1.0, 0.2, 0.0)
	mat_naranja.emission_energy_multiplier = 0.3

	var mat_blanco := StandardMaterial3D.new()
	mat_blanco.albedo_color = Color(0.96, 0.96, 0.98) # Franja reflectante blanca
	mat_blanco.roughness = 0.2
	mat_blanco.emission_enabled = true
	mat_blanco.emission = Color(0.9, 0.9, 0.9)
	mat_blanco.emission_energy_multiplier = 0.4

	# Mallas compartidas para alto rendimiento
	var mesh_base := BoxMesh.new()
	mesh_base.size = Vector3(0.58, 0.05, 0.58)
	mesh_base.material = mat_naranja

	var mesh_cuerpo := CylinderMesh.new()
	mesh_cuerpo.top_radius = 0.04
	mesh_cuerpo.bottom_radius = 0.26
	mesh_cuerpo.height = 0.72
	mesh_cuerpo.radial_segments = 10
	mesh_cuerpo.material = mat_naranja

	var mesh_franja := CylinderMesh.new()
	mesh_franja.top_radius = 0.12
	mesh_franja.bottom_radius = 0.18
	mesh_franja.height = 0.20
	mesh_franja.radial_segments = 10
	mesh_franja.material = mat_blanco

	var col_shape := CylinderShape3D.new()
	col_shape.height = 0.75
	col_shape.radius = 0.28

	var pares: Array = [
		# Zona 1: Slalom inicial tras la meta (s = 115m a 185m)
		[115.0, -3.2], [115.0, -4.2],
		[132.0, 3.2], [132.0, 4.2],
		[150.0, -3.0], [150.0, -4.0],
		[168.0, 3.0], [168.0, 4.0],
		[185.0, 0.0],

		# Zona 2: Ápice y recorte de la Curva 1 (s = 345m a 375m)
		[345.0, -4.2], [355.0, -3.8], [365.0, -3.6], [375.0, -4.0],

		# Zona 3: Obstáculo en la loma este / subida empinada (s = 495m a 525m)
		[495.0, -1.0], [495.0, 1.0],
		[510.0, -1.4], [510.0, 0.0], [510.0, 1.4],
		[525.0, -1.0], [525.0, 1.0],

		# Zona 4: Chicane en S en sector técnico (s = 790m a 835m)
		[790.0, 3.2], [805.0, -3.2], [820.0, 3.0], [835.0, -3.0],

		# Zona 5: Chicane rápida en descenso (s = 965m a 1005m)
		[965.0, -2.8], [975.0, -2.8],
		[985.0, 2.8], [995.0, 2.8],
		[1005.0, 0.0],

		# Zona 6: Reducción de calzada en puente/curvas medias (s = 1245m a 1275m)
		[1245.0, 4.2], [1255.0, 3.4], [1265.0, 2.6], [1275.0, 3.4],

		# Zona 7: Conos en ápice de horquilla norte (s = 1425m a 1455m)
		[1425.0, -3.8], [1435.0, -3.4], [1445.0, -3.4], [1455.0, -3.8],

		# Zona 8: Slalom previo a la recta de meta (s = 1695m a 1725m)
		[1695.0, -2.6], [1705.0, 2.6], [1715.0, -2.6], [1725.0, 2.6]
	]

	for par in pares:
		var s: float = s_meta + float(par[0])
		var cono := ConoObstaculo.new()
		cono.position = pos_en(s) + der_en(s) * float(par[1]) + Vector3(0.0, 0.38, 0.0)
		cono.rotation.y = _yaw(adelante_en(s))

		# 1. Base cuadrada
		var mi_base := MeshInstance3D.new()
		mi_base.mesh = mesh_base
		mi_base.position = Vector3(0.0, -0.355, 0.0)
		cono.add_child(mi_base)

		# 2. Cono naranja
		var mi_cono := MeshInstance3D.new()
		mi_cono.mesh = mesh_cuerpo
		mi_cono.position = Vector3.ZERO
		cono.add_child(mi_cono)

		# 3. Franja blanca reflectante
		var mi_franja := MeshInstance3D.new()
		mi_franja.mesh = mesh_franja
		mi_franja.position = Vector3(0.0, 0.02, 0.0)
		cono.add_child(mi_franja)

		# Colisión física del cono
		var cs := CollisionShape3D.new()
		cs.shape = col_shape
		cono.add_child(cs)

		add_child(cono)

func _chicanas() -> void:
	# Obstáculos pesados de obras viales (Barreras de Chicana / Zig-Zag).
	# Se colocan en 3 zonas estratégicas del circuito donde la pista es ancha
	# forzando a los jugadores a frenar y zigzaguear (eslalon) entre ellas.
	
	# Textura procedural de franjas diagonales de obra (Naranja seguridad y blanco reflectante)
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for x in 128:
		for y in 32:
			var stripe := ((x + y) / 12) % 2 == 0
			var col := Color(0.98, 0.35, 0.05) if stripe else Color(0.96, 0.96, 0.96)
			if y < 3 or y >= 29:
				col = Color(0.12, 0.12, 0.14)
			img.set_pixel(x, y, col)
	var tex_rayas := ImageTexture.create_from_image(img)
	
	var mat_rayas := StandardMaterial3D.new()
	mat_rayas.albedo_texture = tex_rayas
	mat_rayas.roughness = 0.5
	mat_rayas.uv1_scale = Vector3(2.5, 1.0, 1.0)
	
	var mat_concreto := StandardMaterial3D.new()
	mat_concreto.albedo_color = Color(0.22, 0.24, 0.26)
	mat_concreto.roughness = 0.85
	
	var mat_baliza := StandardMaterial3D.new()
	mat_baliza.albedo_color = Color(1.0, 0.55, 0.0)
	mat_baliza.emission_enabled = true
	mat_baliza.emission = Color(1.0, 0.55, 0.0)
	mat_baliza.emission_energy_multiplier = 3.0

	var mesh_base := BoxMesh.new()
	mesh_base.size = Vector3(5.5, 0.35, 0.75)
	mesh_base.material = mat_concreto

	var mesh_cuerpo := BoxMesh.new()
	mesh_cuerpo.size = Vector3(5.4, 0.75, 0.45)
	mesh_cuerpo.material = mat_rayas

	var mesh_baliza := CylinderMesh.new()
	mesh_baliza.top_radius = 0.12
	mesh_baliza.bottom_radius = 0.14
	mesh_baliza.height = 0.25
	mesh_baliza.material = mat_baliza

	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(5.5, 1.2, 0.8)

	# Definición de Chicanas (s_relativo, desplazamiento_lateral, evadir_a_derecha)
	# Ancho de pista = 14m (va de -7.0m a +7.0m).
	# Una barrera de 5.5m colocada en -3.8m cubre de -6.5m a -1.1m (obliga a pasar por la derecha).
	# Una barrera de 5.5m colocada en +3.8m cubre de +1.1m a +6.5m (obliga a pasar por la izquierda).
	var chicanas_data = [
		# --- CHICANA 1: Sector Descenso de Colina (s = 500m a 550m) ---
		[500.0, -3.8, true],   # Barrera 1 izquierda -> evadir a derecha
		[522.0,  3.8, false],  # Barrera 2 derecha   -> evadir a izquierda
		[544.0, -3.8, true],   # Barrera 3 izquierda -> evadir a derecha

		# --- CHICANA 2: Sector Este - Recta de Alta Velocidad (s = 1140m a 1190m) ---
		[1140.0,  3.8, false], # Barrera 1 derecha   -> evadir a izquierda
		[1162.0, -3.8, true],  # Barrera 2 izquierda -> evadir a derecha
		[1184.0,  3.8, false], # Barrera 3 derecha   -> evadir a izquierda

		# --- CHICANA 3: Tramo Técnico Sur previo a la Meta (s = 1530m a 1575m) ---
		[1530.0, -3.8, true],  # Barrera 1 izquierda -> evadir a derecha
		[1555.0,  3.8, false], # Barrera 2 derecha   -> evadir a izquierda
		[1575.0, -3.8, true]   # Barrera 3 izquierda -> evadir a derecha
	]

	for item in chicanas_data:
		var s: float = s_meta + float(item[0])
		var lado_x: float = float(item[1])
		
		var barrera := BarreraChicana.new()
		barrera.position = pos_en(s) + der_en(s) * lado_x + Vector3(0.0, 0.20, 0.0)
		barrera.rotation.y = _yaw(adelante_en(s))
		
		# 1. Base pesada de concreto
		var m_base := MeshInstance3D.new()
		m_base.mesh = mesh_base
		m_base.position = Vector3(0.0, 0.175, 0.0)
		barrera.add_child(m_base)

		# 2. Cuerpo de seguridad con franjas diagonales de obra
		var m_cuerpo := MeshInstance3D.new()
		m_cuerpo.mesh = mesh_cuerpo
		m_cuerpo.position = Vector3(0.0, 0.70, 0.0)
		barrera.add_child(m_cuerpo)

		# 3. Balizas luminosas de advertencia en los extremos superiores
		for bx in [-2.3, 2.3]:
			var m_baliza := MeshInstance3D.new()
			m_baliza.mesh = mesh_baliza
			m_baliza.position = Vector3(bx, 1.15, 0.0)
			barrera.add_child(m_baliza)

		# 4. Luz de advertencia parpadeante en el centro
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.55, 0.0)
		luz.light_energy = 3.5
		luz.omni_range = 8.0
		luz.position = Vector3(0.0, 1.4, 0.0)
		barrera.add_child(luz)
		barrera.luz_advertencia = luz

		# 5. Colisión física del RigidBody3D
		var cs := CollisionShape3D.new()
		cs.shape = col_shape
		cs.position = Vector3(0.0, 0.60, 0.0)
		barrera.add_child(cs)

		add_child(barrera)

func _luces_neon() -> void:
	var n := 8
	var mat := _material_brillo(C_BORDE, 2.0)
	for k in n:
		var s := largo * float(k) / float(n) + 40.0
		var lado := 1.0 if k % 2 == 0 else -1.0
		var base := pos_en(s) + der_en(s) * (ancho * 0.5 + 2.2) * lado
		var poste := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 4.0, 0.3)
		bm.material = mat
		poste.mesh = bm
		add_child(poste)
		poste.position = base + Vector3(0, 2.0, 0)
		var luz := LuzParpadeante.new()
		luz.light_color = C_BORDE
		luz.omni_range = 18.0
		luz.omni_attenuation = 2.0
		luz.energia_base = 3.0
		luz.amplitud = 0.25
		luz.semilla = 7 + k
		add_child(luz)
		luz.position = base + Vector3(0, 4.3, 0)

# Coloca la ruta de los rivales sobre la pista y congela la grilla hasta que el semaforo se ponga en verde
func _preparar_carrera() -> void:
	var rivales := get_tree().get_nodes_in_group("rival")
	var lados := [2.5, -2.5, 0.0]
	for k in rivales.size():
		var r: Node = rivales[k]
		var ruta: Array[Vector3] = []
		var lado: float = lados[k % lados.size()]
		var s := s_meta + 4.0
		while s < s_meta + largo - 4.0:
			ruta.append(pos_en(s) + der_en(s) * (lado + sin(s * 0.03 + float(k)) * 1.0))
			s += 14.0
		r.set("ruta", ruta)
		r.set("indice", 0)
		r.set("reloj_onda", 15.0) # Espera 15s antes del primer ataque segun la documentacion
	for j in get_tree().get_nodes_in_group("jugador"):
		j.set_physics_process(false)
	for r in rivales:
		r.set_physics_process(false)

func _arrancar() -> void:
	for j in get_tree().get_nodes_in_group("jugador"):
		j.set_physics_process(true)
	for r in get_tree().get_nodes_in_group("rival"):
		r.set_physics_process(true)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_reloj += delta
	for k in _esferas.size():
		var e := _esferas[k]
		if e.visible:
			e.rotate_y(delta * 1.5)
			var anillo = e.get_node_or_null("AnilloTurbo")
			if anillo:
				anillo.rotate_x(delta * 2.8)
				anillo.rotate_z(delta * 1.4)
	if en_cuenta:
		_t_cuenta += delta
		if _t_cuenta < cuenta_atras:
			var rojas := clampi(int(floor(_t_cuenta)) + 1, 0, 3)
			texto_cuenta = str(int(ceil(cuenta_atras - _t_cuenta)))
			for k in 3:
				var enc := k < rojas
				_mats_lampara[k].albedo_color = Color(1, 0.1, 0.05) if enc else Color(0.12, 0.05, 0.05)
				_mats_lampara[k].emission = Color(1, 0.1, 0.05) if enc else Color(0, 0, 0)
				_mats_lampara[k].emission_energy_multiplier = 3.0 if enc else 0.0
		else:
			en_cuenta = false
			texto_cuenta = "¡YA!"
			for k in 3:
				_mats_lampara[k].albedo_color = C_VERDE
				_mats_lampara[k].emission = C_VERDE
				_mats_lampara[k].emission_energy_multiplier = 3.0
			_arrancar()
	elif texto_cuenta != "":
		_t_ya += delta
		if _t_ya > 1.5:
			texto_cuenta = ""
			for k in 3:
				_mats_lampara[k].emission_energy_multiplier = 0.0
				_mats_lampara[k].albedo_color = Color(0.12, 0.05, 0.05)

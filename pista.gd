@tool
extends Node3D

# CustomVeloz - Circuito cerrado low poly (Documento de concepto: "una pista cerrada en Low Poly",
# 3 vueltas, esfera verde +15 km/h, tramo de conos, semaforo en la grilla).
# La pista se genera sola a partir de una lista de puntos (curva suave Catmull-Rom):
# para cambiar el trazado solo se editan "puntos" (x, z en metros) y "alturas" (y en metros).
# La meta esta en el punto "indice_meta"; el carro arranca 11 m antes de la meta, mirando a -Z.

const C_ASFALTO := Color("#263238")
const C_BORDE := Color("#00E5FF")
const C_VERDE := Color("#76FF03")
const C_DANO := Color("#FF5722")
const C_LINEA := Color("#90A4AE")
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
# Posicion (en metros desde la meta) de las esferas verdes y su desvio lateral.
@export var esferas_s := PackedFloat32Array([220.0, 580.0, 950.0, 1400.0])
@export var esferas_lado := PackedFloat32Array([-3.0, 3.0, -2.5, 2.5])
@export var mejora_kmh := 15.0

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
		add_child(_malla(vm, nm, mat_muro))
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
	_conos()
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
		if k == siguiente_cp:
			siguiente_cp += 1
		var respawn = get_tree().get_first_node_in_group("respawn")
		if respawn and respawn.has_method("registrar_checkpoint"):
			respawn.registrar_checkpoint(body.global_position, body.global_rotation.y)

func _on_meta(body: Node3D) -> void:
	if not body.is_in_group("jugador"):
		return
	if siguiente_cp >= n_cp:
		siguiente_cp = 0
		var partida := get_tree().get_first_node_in_group("partida")
		if partida and partida.has_method("avisar_meta"):
			partida.avisar_meta()

func _esferas_verdes() -> void:
	for k in esferas_s.size():
		var s := s_meta + esferas_s[k]
		var pos := pos_en(s) + der_en(s) * esferas_lado[k] + Vector3(0, 1.2, 0)
		var a := _area(self, pos, 0.0, Vector3(2.4, 2.4, 2.4))
		a.name = "EsferaVerde%d" % (k + 1)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 8
		sm.rings = 4
		sm.material = _material_brillo(C_VERDE, 2.0)
		mi.mesh = sm
		a.add_child(mi)
		_esferas.append(a)
		a.body_entered.connect(_on_esfera.bind(a))

func _on_esfera(body: Node3D, a: Area3D) -> void:
	if not body.is_in_group("jugador") or not a.visible:
		return
	a.visible = false
	a.set_deferred("monitoring", false)
	if body.has_method("aplicar_mejora"):
		body.aplicar_mejora(mejora_kmh)
	print("[pista] esfera verde: +", mejora_kmh, " km/h de velocidad maxima")

func _conos() -> void:
	# Tramo de conos sencillos despues de la meta (Beat 4 del Taller 5)
	var mat := _material_brillo(C_DANO, 0.4)
	var pares := [[120.0, -3.0], [138.0, 3.0], [156.0, -3.0], [174.0, 3.0]]
	for par in pares:
		var s := s_meta + float(par[0])
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = 2 # capa 2: solo el jugador choca con los conos (los rivales los esquivan)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.3
		cm.height = 0.7
		cm.radial_segments = 8
		cm.material = mat
		mi.mesh = cm
		cuerpo.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.height = 0.7
		sh.radius = 0.3
		cs.shape = sh
		cuerpo.add_child(cs)
		add_child(cuerpo)
		cuerpo.position = pos_en(s) + der_en(s) * float(par[1]) + Vector3(0, 0.35, 0)

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
			e.position.y += sin(_reloj * 3.0 + float(k)) * delta * 0.4
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

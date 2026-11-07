class_name CicloDia
extends Node

var hora: float = 6.0
var duracion_dia: float = 48.0
var pausado: bool = false

func avanzar(dt: float) -> void:
	if pausado:
		return
	var horas_por_segundo = 24.0 / duracion_dia
	hora += dt * horas_por_segundo
	if hora >= 24.0:
		hora -= 24.0

static func elevacion(h: float) -> float:
	return (h - 6.0) * 15.0

static func factor_sol(h: float) -> float:
	var elv = elevacion(h)
	var rad = deg_to_rad(elv)
	return max(0.0, sin(rad))

static func color_sol(h: float) -> Color:
	var f = factor_sol(h)
	var color_horizonte = Color(1.0, 0.55, 0.3)
	var color_cenit = Color(1.0, 1.0, 1.0)
	return color_horizonte.lerp(color_cenit, f)

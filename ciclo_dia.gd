class_name CicloDia
extends Node

# Color bajo de la paleta de CustomVeloz: #FF5722 mezclado con naranja (1, 0.55, 0.3)
const NARANJA := Color(1.0, 0.4456, 0.2167)

@export var hora := 8.0 # h, al empezar
@export var duracion_dia := 48.0 # s reales que dura un día de 24 h
@export var pausado := false

func avanzar(dt: float) -> void:
	if not pausado:
		hora = fposmod(hora + 24.0 * dt / duracion_dia, 24.0)

static func elevacion(h: float) -> float:
	return (h - 6.0) * 15.0 # 6 h → 0°, 12 h → 90°, 18 h → 180°

static func factor_sol(h: float) -> float:
	return maxf(0.0, sin(deg_to_rad(elevacion(h))))

static func color_sol(h: float) -> Color:
	return NARANJA.lerp(Color.WHITE, factor_sol(h))

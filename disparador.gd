class_name Disparador
extends Area3D

signal evento(posicion: Vector3)

@export var tecla := KEY_T
@export var que_representa := "tomar esfera de mejora" # la mecánica de tu recuadro

var antes := false

func _enter_tree() -> void:
	add_to_group("disparadores") # el grupo que escucha SistemaEventos

func _ready() -> void:
	body_entered.connect(func(_cuerpo: Node3D) -> void: evento.emit(global_position))

func _physics_process(_delta: float) -> void:
	var ahora := Input.is_key_pressed(tecla)
	if ahora and not antes:
		evento.emit(global_position)
	antes = ahora

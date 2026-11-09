extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	if body.is_in_group("jugador"):
		var p = get_tree().get_first_node_in_group("partida")
		if p and p.has_method("avisar_meta"):
			p.avisar_meta()

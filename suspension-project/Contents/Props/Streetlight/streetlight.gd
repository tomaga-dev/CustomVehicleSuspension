extends RigidBody3D


func _on_body_entered(body: Node) -> void:
	if body.has_node("Motor"):
		freeze = false
		call_deferred("set_contact_monitor", false)

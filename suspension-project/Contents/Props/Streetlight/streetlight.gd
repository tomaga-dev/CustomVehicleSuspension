extends RigidBody3D


func _on_body_entered(body: Node) -> void:
	if body.has_node("Motor"):
		freeze = false
		contact_monitor = false
		max_contacts_reported = 0

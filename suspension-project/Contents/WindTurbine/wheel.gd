extends MeshInstance3D

var angle: float = 0

func _physics_process(_delta: float) -> void:
	rotation.x -= deg_to_rad(0.5)

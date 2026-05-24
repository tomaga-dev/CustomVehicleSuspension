extends Node3D

@onready var mesh_instance: MeshInstance3D = get_node("Plate")

var material: Material
var offset: Vector3

func _ready() -> void:
		material = mesh_instance.get_active_material(0)
		offset = material.uv1_offset

func _physics_process(_delta: float) -> void:
	offset.x += 0.016
	material.uv1_offset = offset

extends Node3D

class_name Exhaust

@export var pitch_factor: float = 1

@onready var acceleration: AudioStreamPlayer3D = get_node("Acceleration")
@onready var deceleration: AudioStreamPlayer3D = get_node("Deceleration")

func _ready() -> void:
	acceleration.play()
	deceleration.play()

func update(car: VehicleController) -> void:
	acceleration.volume_db = car.motor.volume_acceleration_db
	deceleration.volume_db = car.motor.volume_deceleration_db
	var pitch: float = car.rev_normalized * pitch_factor
	acceleration.pitch_scale = pitch
	deceleration.pitch_scale = pitch

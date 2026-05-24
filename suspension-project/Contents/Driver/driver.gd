extends Node

class_name Driver

signal handling_updated(vehicle: VehicleController)

var controlled_car: VehicleController

var did_accelerate: bool = false
var did_brake: bool = false
var did_reverse: bool = false
var did_steer_left: bool = false
var did_steer_right: bool = false


func clear_input() -> void:
	did_accelerate = false
	did_brake = false
	did_reverse = false
	did_steer_left = false
	did_steer_right = false

func get_input() -> void:
	if Input.is_action_pressed("accelerate"):
		did_accelerate = true
	if Input.is_action_pressed("brake"):
		did_brake = true
	if Input.is_action_pressed("reverse"):
		did_reverse = true
	if Input.is_action_pressed("left"):
		did_steer_left = true
	if Input.is_action_pressed("right"):
		did_steer_right = true

func _on_vehicle_suspension_updated(delta: float, vehicle: VehicleController) -> void:
		var handling: VehicleHandling = vehicle.get_node_or_null("VehicleHandling")
		if handling:
			if vehicle == controlled_car:
				clear_input()
				get_input()
				vehicle.motor.did_rev_up = did_accelerate
				handling.did_accelerate = did_accelerate
				handling.did_brake = did_brake
				handling.did_reverse = did_reverse
				handling.did_steer_left = did_steer_left
				handling.did_steer_right = did_steer_right
				handling.control(delta, vehicle)
				handling_updated.emit(vehicle)
			else:
				handling.did_brake = true
				handling.control(delta, vehicle)

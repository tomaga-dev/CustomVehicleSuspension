extends Node3D

class_name WheelController

@export var wheel_radius: float = 0.35
@export var spring_stiffness_curve: Curve

@onready var wheel: Node3D = get_node("Wheel")
@onready var ray: RayCast3D = get_node("RayCast3D")

var circumference: float
var camber_rotation: Quaternion
var steering_rotation: Quaternion
var spring_distance_max_in: float
var spring_distance_max_out: float
var spring_constant: float
var spring_damping: float
var spring_distance: float
var spring_rest_position: float
var spring_distance_now: float
var spring_velocity: float
var spring_force: float
var force: Vector3
var offset: Vector3
var wheel_position: Vector3

func _ready() -> void:
	circumference = 2 * PI * wheel_radius
	camber_rotation = wheel.quaternion
	steering_rotation = wheel.quaternion

func init_suspension(rest_force: float, arg_spring_distance_max_in: float, arg_spring_distance_max_out: float, arg_spring_constant: float, arg_spring_damping: float) -> void:
	spring_distance_max_in = arg_spring_distance_max_in
	spring_distance_max_out = arg_spring_distance_max_out
	spring_constant = arg_spring_constant
	spring_damping = arg_spring_damping
	ray.target_position = Vector3(0, -(wheel_radius + spring_distance_max_out), 0)
	spring_distance = 0
	spring_rest_position = rest_force / spring_constant

func apply_spring_force(delta: float, vehicle_body: RigidBody3D, ani_roll_force: float) -> bool:
	var stiffness_factor: float = 1
	var has_contact: bool = ray.is_colliding()
	if has_contact:
		var contact_point: Vector3 = ray.get_collision_point()
		var contact_point_vehicle: Vector3 = vehicle_body.to_local(contact_point)
		spring_distance_now = contact_point_vehicle.y + wheel_radius
		spring_velocity = (spring_distance_now - spring_distance) / delta
		spring_distance = spring_distance_now
		if spring_distance > 0:
			var arg: float = spring_distance / spring_distance_max_in
			stiffness_factor = spring_stiffness_curve.sample(arg)
		spring_force = stiffness_factor * spring_constant * (spring_distance + spring_rest_position) # Hooke's Law
		spring_force += ani_roll_force
		var damping_force: float = spring_damping * spring_velocity
		force = Vector3(0, spring_force + damping_force, 0)
		offset = contact_point - vehicle_body.global_position
		vehicle_body.apply_force(force, offset)
		wheel_position = Vector3(0, spring_distance, 0)
	else:
		spring_distance = 0
		wheel_position = Vector3(0, -spring_distance_max_out, 0)
	wheel.transform.origin = wheel_position
	return has_contact

func rotate_wheel(delta: float, total_distance_moved: float, steering_angle: float) -> void:
	var wanted_steering_rotation: Quaternion
	var steering_max: float = deg_to_rad(45)
	var rotation_angle: float = 2 * PI * total_distance_moved / circumference
	var movement_rotation: Quaternion = Quaternion(Vector3.LEFT, rotation_angle)
	if steering_angle > steering_max:
		wanted_steering_rotation = Quaternion(Vector3.UP, steering_max)
		steering_rotation = steering_rotation.slerp(wanted_steering_rotation, 6 * delta)
	else: if steering_angle < -steering_max:
		wanted_steering_rotation = Quaternion(Vector3.UP, -steering_max)
		steering_rotation = steering_rotation.slerp(wanted_steering_rotation, 6 * delta)
	else:
		wanted_steering_rotation = Quaternion(Vector3.UP, steering_angle)
		steering_rotation = steering_rotation.slerp(wanted_steering_rotation, 6 * delta)
	steering_rotation = steering_rotation.normalized()
	var wheel_rotation: Quaternion = steering_rotation * camber_rotation * movement_rotation
	wheel.quaternion = wheel_rotation

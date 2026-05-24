extends Node

class_name VehicleHandling

@onready var omega_controller: PIDController = get_node("OmegaController")
@onready var grip_controller: PIDController = get_node("GripController")

@export var force_max: float = 20000
@export var brake_max: float = 40000
@export var boost_factor: float = 1.7
@export var drift_sensitivity: float = 5
@export var omega_max: float = 0.6
@export var omega_max_drift: float = 1.7
@export var omega_curve: Curve
@export var kp_drift: float = 1500
@export var kp_steering: float = 5000

var vehicle: VehicleController
var did_accelerate: bool = false
var did_brake: bool = false
var did_reverse: bool = false
var did_steer_left: bool = false
var did_steer_right: bool = false
var is_cornering: bool
var apply_boost: bool
var acceleration_force: float
var brake_force: float
var omega_reference: float
var grip_force: float

func control(delta: float, vehicle_controller: VehicleController) -> void:
	vehicle = vehicle_controller
	apply_boost = false
	if vehicle.on_ground:
		control_drift(delta)
	else:
		reset_pid_controllers()
	finalize_state()

func accelerate(force: float) -> void:
	if vehicle.gearbox.gear_changing:
		acceleration_force = 0
	else:
		acceleration_force = force
	if apply_boost:
		acceleration_force *= boost_factor
	var rotation_vehicle: Quaternion = vehicle.quaternion
	var direction_vehicle: Vector3 = rotation_vehicle * Vector3.FORWARD
	var force_vector: Vector3 = direction_vehicle * acceleration_force
	vehicle.apply_force(force_vector, vehicle.offset_drive)

func brake(force: float) -> void:
	did_brake = true
	acceleration_force = 0
	brake_force = force
	var brake_force_vector: Vector3
	if vehicle.linear_velocity.length() > 0.5:
		var direction: Vector3 = vehicle.linear_velocity.normalized()
		brake_force_vector = brake_force * direction
	else:
		brake_force_vector = brake_force * vehicle.linear_velocity
	vehicle.apply_force(-brake_force_vector, vehicle.offset_drive)

func apply_lateral_force() -> void:
	grip_force = grip_controller.adjust(0, vehicle.sideways_velocity)
	var direction: Vector3 = vehicle.quaternion * Vector3.LEFT
	var grip_force_vector: Vector3 = direction * grip_force
	vehicle.apply_force(grip_force_vector, vehicle.offset_drive)

func apply_torque() -> void:
	var torque: float = omega_controller.adjust(omega_reference, vehicle.angular_velocity.y)
	var torque_vector: Vector3 = vehicle.quaternion * Vector3.UP * torque
	vehicle.apply_torque(torque_vector)

func control_omega(delta: float, velocity: float, omega_wanted: float, time_factor: float) -> void:
	var value: float = omega_curve.sample(velocity * 0.2)
	if did_steer_left:
		if omega_reference < 0: # countersteer
			apply_boost = true
			time_factor = 0.9
		omega_reference = lerp(omega_reference, omega_wanted * value, time_factor * delta)
	else: if did_steer_right:
		if omega_reference > 0: # countersteer
			apply_boost = true
			time_factor = 0.9
		omega_reference = lerp(omega_reference, -omega_wanted * value, time_factor * delta)
	else:
		if is_cornering:
			omega_reference = lerp(omega_reference, 0.0, 0.1 * delta)
		else:
			omega_reference = lerp(omega_reference, 0.0, 9 * delta)

func is_drift_agle_less_than(angle: float) -> bool:
	if vehicle.drift_angle_measurement > -angle && vehicle.drift_angle_measurement < angle:
		return true
	return false

func control_drift(delta: float) -> void:
	var speed: float = vehicle.linear_velocity.length()
	var steering: float = vehicle.drift_angle_measurement
	var forward: float = 1
	if !vehicle.moving_forward:
		forward = -1
	if did_accelerate:
		if did_steer_left || did_steer_right:
			if is_cornering:
				vehicle.has_grip = false
		else:
			if is_drift_agle_less_than(deg_to_rad(3)):
				vehicle.has_grip = true
				is_cornering = false
	else:
		if did_steer_left || did_steer_right:
			is_cornering = true
		else:
			is_cornering = false
			vehicle.has_grip = true
	if vehicle.has_grip:
		grip_controller.kp = lerp(grip_controller.kp, kp_steering, 20 * delta)
		steering = vehicle.steering_angle
		control_omega(delta, speed, forward * omega_max, 3)
	else:
		if did_accelerate:
			grip_controller.kp = lerp(grip_controller.kp, kp_drift, 20 * delta)
		else:
			grip_controller.kp = lerp(grip_controller.kp, kp_steering, 2 * delta)
			steering = vehicle.steering_angle
		control_omega(delta, speed, forward * omega_max_drift, drift_sensitivity)
	if did_brake:
		brake(brake_max)
	else: if did_accelerate:
		var force: float = force_max * vehicle.gearbox.force_max_value[vehicle.gearbox.gear - 1]
		accelerate(force)
	else: if did_reverse:
		accelerate(-3000)
	else:
		acceleration_force = 0
	apply_torque()
	apply_lateral_force()
	vehicle.update_wheel_rotation(delta, steering)

func reset_pid_controllers() -> void:
	omega_controller.reset()
	grip_controller.reset()
	vehicle.anti_roll_controller.reset()

func finalize_state() -> void:
	if vehicle.taillights_material:
		vehicle.taillights_material.emission_enabled = true
		if did_brake:
			vehicle.taillights_material.emission_energy_multiplier = vehicle.brakelights_intensity
		else:
			vehicle.taillights_material.emission_energy_multiplier = 0.0

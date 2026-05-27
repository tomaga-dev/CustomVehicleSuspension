extends RigidBody3D

class_name  VehicleController

signal suspension_updated(delta: float, vehicle: VehicleController)

@export var spring_distance_max_in: float = 0.07
@export var spring_distance_max_out: float = 0.14
@export var spring_constant: float = 42214 # Hard spring.
@export var spring_damping: float = 7904
@export var taillights_mesh: MeshInstance3D
@export var taillights_material_index: int = 0
@export var brakelights_intensity: float = 0.5

@onready var fl: WheelController = get_node("FL")
@onready var fr: WheelController = get_node("FR")
@onready var rl: WheelController = get_node("RL")
@onready var rr: WheelController = get_node("RR")

@onready var anti_roll_controller: PIDController = get_node("AntiRollController")
@onready var gearbox: Gearbox = get_node("Gearbox")
@onready var motor: Motor = get_node("Motor")
@onready var exhaust:Exhaust = get_node("Exhaust")

var turn_radius: float
var wheelbase: float
var driving_force_position: Vector3
var offset_drive: Vector3
var front_rolling_measurement: float
var anti_roll_force: float
var on_ground: bool
var has_grip: bool = true
var moving_forward: bool
var sideways_velocity: float
var total_distance_moved: float
var drift_angle_threshold: float = 20 # degree
var drift_angle_measurement: float
var steering_angle: float
var taillights_material: BaseMaterial3D
var rev_normalized: float
var last_skidmark_position: Vector3
var min_skidmark_distance: float
var smoke_left: GPUParticles3D
var smoke_right: GPUParticles3D
var unflip: bool
var is_unflipping: bool = false
var last_rotation: Quaternion

func _ready() -> void:
	var weight: float = mass * ProjectSettings.get_setting("physics/3d/default_gravity")
	anti_roll_force = 0
	wheelbase = rl.transform.origin.z - fl.transform.origin.z
	driving_force_position = Vector3(0, -rl.wheel_radius, wheelbase * 0.5) # At the rear axis and at the contact point of the wheel.
	fl.init_suspension(weight / 4, spring_distance_max_in, spring_distance_max_out, spring_constant, spring_damping)
	fr.init_suspension(weight / 4, spring_distance_max_in, spring_distance_max_out, spring_constant, spring_damping)
	rl.init_suspension(weight / 4, spring_distance_max_in, spring_distance_max_out, spring_constant, spring_damping)
	rr.init_suspension(weight / 4, spring_distance_max_in, spring_distance_max_out, spring_constant, spring_damping)
	if taillights_mesh:
		taillights_material = taillights_mesh.get_active_material(taillights_material_index)
		if taillights_material:
			taillights_material.emission_enabled = false
			taillights_material.emission = Color(1, 0, 0)
	smoke_left = get_node_or_null("RL/TyreSmoke")
	smoke_right = get_node_or_null("RR/TyreSmoke")
	last_rotation = Quaternion(Vector3.UP, 0)
#	make_transparent(0.5)

func make_transparent(value: float) -> void:
	for child in find_children("*", "MeshInstance3D"):
		child.transparency = value

func _process(_delta: float) -> void:
	if on_ground:
		is_unflipping = false
		unflip = false
	if is_unflipping:
		freeze = false
		unflip = false
	if unflip:
		is_unflipping = true
		freeze = true
		position = global_position + Vector3.UP * 0.5
		quaternion = last_rotation
		angular_velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	turn_radius = get_turn_radius()
	offset_drive = to_global(driving_force_position) - global_position
	on_ground = update_suspension(delta)
	if on_ground:
		last_rotation = quaternion
	var rotation_vehicle: Quaternion = quaternion
	var direction_vehicle: Vector3 = rotation_vehicle * Vector3.FORWARD
	var direction_velocity: Vector3 = linear_velocity.normalized()
	var cross_product: Vector3 = direction_vehicle.cross(direction_velocity)
	var vehicle_direction_sideways: Vector3 = quaternion * Vector3.LEFT
	sideways_velocity = linear_velocity.dot(vehicle_direction_sideways)
	moving_forward = direction_vehicle.dot(direction_velocity) > 0
	drift_angle_measurement = asin(cross_product.y)
	var velocity: float = linear_velocity.dot(direction_vehicle)
	if linear_velocity.length() > 0.01:
		steering_angle = asin(wheelbase / turn_radius)
		if !moving_forward:
			steering_angle = -steering_angle
	else:
		steering_angle = 0
	total_distance_moved += delta * velocity
	rev_normalized = motor.update(self)
	gearbox.select_gear(linear_velocity.length(), motor.did_rev_up)
	exhaust.update(self)
	update_tyre_smoke(on_ground)
	suspension_updated.emit(delta, self)

func update_suspension(delta: float) -> bool:
	var contact_front: bool
	var contact_rear: bool
	var four_wheels_have_contact: bool
	contact_front = fl.apply_spring_force(delta, self, -anti_roll_force)
	contact_front = fr.apply_spring_force(delta, self, anti_roll_force) && contact_front
	contact_rear = rl.apply_spring_force(delta, self, 0)
	contact_rear = rr.apply_spring_force(delta, self, 0) && contact_rear
	four_wheels_have_contact = contact_front && contact_rear
	if four_wheels_have_contact:
		front_rolling_measurement = fl.spring_distance - fr.spring_distance
		anti_roll_force = anti_roll_controller.adjust(0, front_rolling_measurement)
	else:
		anti_roll_force = 0
		anti_roll_controller.reset()
	return four_wheels_have_contact

func update_wheel_rotation(delta: float, steering: float) -> void:
	fl.rotate_wheel(delta, total_distance_moved, steering)
	fr.rotate_wheel(delta, total_distance_moved, steering)
	rl.rotate_wheel(delta, total_distance_moved, 0)
	rr.rotate_wheel(delta, total_distance_moved, 0)

func update_tyre_smoke(is_on_ground: bool) -> void:
	if smoke_left && smoke_right:
		var drift_angle: float = rad_to_deg(drift_angle_measurement)
		var is_drifting: bool = drift_angle < -drift_angle_threshold || drift_angle > drift_angle_threshold
		if is_on_ground && is_drifting:
			smoke_left.emitting = true
			smoke_right.emitting = true
		else:
			smoke_left.emitting = false
			smoke_right.emitting = false

func get_turn_radius() -> float:
	var radius: float
	var radius_min: float = 1.1 * wheelbase
	radius = 999
	if linear_velocity.length() > 0.05:
		if angular_velocity.y > 0:
			radius = min(999, linear_velocity.length() / angular_velocity.y)
			if radius < radius_min:
				radius = radius_min
		else: if angular_velocity.y < 0:
			radius = max(-999, linear_velocity.length() / angular_velocity.y)
			if radius > -radius_min:
				radius = -radius_min
	if radius > -radius_min && radius < radius_min:
		print_debug("turn radius?")
	return radius

extends Node

@onready var fps_label: Label = get_node("Status/Horzontal/FPS")
@onready var debug_label: Label = get_node("Status/Vertical/Debug")
@onready var camera: Camera3D = get_node("Camera3D")
@onready var driver: Driver = get_node("Driver")
@export var players_car: VehicleController

var handling: VehicleHandling

func _ready() -> void:
	var view: Viewport = get_viewport()
	view.grab_focus()
	driver.controlled_car = players_car
	camera.setup(players_car)
	handling = players_car.get_node("VehicleHandling")


func _physics_process(_delta: float) -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	fps_label.text = "FPS: %2.0f" % fps
	var drift_angle: float = players_car.drift_angle_measurement
	var drift_angle_degree = rad_to_deg(drift_angle)
	var sideways_velocity: float = players_car.sideways_velocity
	var gear: int = players_car.gearbox.gear
	var force: float = handling.acceleration_force
	var velocity: float = players_car.linear_velocity.length()
	var data: Array = [drift_angle_degree, sideways_velocity, gear, force, players_car.rev_normalized, velocity, players_car.has_grip]
	var format: String = "Drift Angle: %.0f\n"
	format += "Sideways Velocity: %.f\n"
	format += "Gear: %d\n"
	format += "Acceleration Force: %.0f\n"
	format += "Rev: %.2f\n"
	format += "Velocity: %.f\n"
	format += "Grip: %s\n"
	debug_label.text = format % data
	if Input.is_action_just_released("ui_cancel"):
		var scene: SceneTree = get_tree()
		scene.quit()

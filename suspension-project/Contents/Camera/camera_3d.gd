extends Camera3D

@export var first_person: bool = false

var target: VehicleController
var camera_basis: Basis
var camera_offset: Vector3

func setup(car:VehicleController) -> void:
	target = car
	var distance_measured: Vector3 = target.global_transform.origin - global_transform.origin
	var distance_magnitude: float = distance_measured.length()
	camera_basis = transform.basis
	camera_offset = camera_basis * Vector3.FORWARD * distance_magnitude

func _physics_process(_delta: float) -> void:
	if !target:
		return
	if Input.is_action_just_pressed("camera"):
		first_person = !first_person
	if first_person:
		target.visible = false
		first_person_view()
	else:
		target.visible = true
		fixed_angle_view()

func fixed_angle_view() -> void:
	transform.basis = camera_basis
	transform.origin = target.global_transform.origin - camera_offset

func first_person_view() -> void:
	transform.basis = target.global_transform.basis
	transform.origin = target.global_transform.origin + Vector3.UP * 0.5

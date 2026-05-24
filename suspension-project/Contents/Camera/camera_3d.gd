extends Camera3D

var target: VehicleController

var distance_measured: Vector3
var distance_magnitude: float

func setup(car:VehicleController) -> void:
	target = car
	distance_measured = target.global_transform.origin - global_transform.origin
	distance_magnitude = distance_measured.length()

func _physics_process(_delta: float) -> void:
	if !target:
		return
	var r = Quaternion(transform.basis)
	transform.origin = target.global_transform.origin - r * Vector3.FORWARD * distance_magnitude

extends Node

class_name Motor
@export var rev_mmin: float = 800 # U/min
@export var rev_max: float = 9000 # U/min

var m: float = (rev_max - rev_mmin) / rev_max
var b: float = rev_mmin / rev_max
var did_rev_up: bool = false
var volume_acceleration_db: float = 0
var volume_deceleration_db: float = 0
var time_start: int = Time.get_ticks_msec()
var time_now: int
var time_diff: int = 52 # milliseconds
var speed_rear_axle: float = 0
var speed_now: float = 0
var speed_delta: float = 0.3

func update(car: VehicleController) -> float:
	var cut_off: bool
	var vmax: float = car.gearbox.get_vmax()
	var v_cut_off: float = vmax * 0.97
	var rev_normalized: float
	time_now = Time.get_ticks_msec()
	if time_now >= time_start + 2 * time_diff:
		time_start = time_now
	if time_now >= time_start + time_diff:
		cut_off = true
	else:
		cut_off = false
	rev_normalized = get_rev_from_speed(car, v_cut_off, cut_off)
	return rev_normalized

func get_rev_from_speed(car: VehicleController, v_cut_off: float, cut_off: bool) -> float:
	var vmax: float = car.gearbox.get_vmax()
	update_speed(car, v_cut_off, cut_off)
	speed_rear_axle = speed_now
	if !car.moving_forward:
		speed_rear_axle = -speed_rear_axle
	var rev_normalized: float = b + m * speed_now / vmax
	set_volume(car, speed_now, v_cut_off)
	return rev_normalized

func update_speed(car: VehicleController, v_cut_off: float, cut_off: bool) -> void:
	var speed: float = car.linear_velocity.length()
	if did_rev_up && !car.has_grip:
		speed_now += speed_delta
	else:
		speed_now = speed
	if speed_now > v_cut_off && cut_off:
		speed_now = v_cut_off

func set_volume(car: VehicleController, speed: float, v_cut_off: float) -> void:
	var car_speed: float = car.linear_velocity.length()
	var delta: float = get_physics_process_delta_time()
	var acceleration_db: float = volume_acceleration_db
	if car_speed > 1.5:
		volume_acceleration_db = lerp(acceleration_db, -20.0, 6 * delta)
	else:
		volume_acceleration_db = lerp(acceleration_db, -3.0, 6 * delta)
	volume_deceleration_db = -20
	if car.gearbox.gear_changing:
		volume_acceleration_db = -40
	else: if !car.on_ground:
		volume_acceleration_db = -40
	else: if did_rev_up:
		if speed > v_cut_off:
			volume_acceleration_db = -40
		else:
			volume_acceleration_db = -3

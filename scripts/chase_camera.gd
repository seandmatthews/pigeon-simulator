class_name ChaseCamera
extends Node3D
## Third-person chase camera (T-002). A top-level rig that position-follows the
## pigeon with exponential damping; yaw/pitch/roll are softened fractions of the
## body attitude so fast maneuvers never snap the view. The SpringArm3D keeps
## world geometry from clipping the lens; FOV widens with forward speed and the
## rig tucks in closer, lower and lazier while grounded.

@export_group("Follow")
@export var position_rate: float = 12.0 ## 1/s exponential follow of the pigeon's position.
@export var yaw_rate_air: float = 4.5 ## 1/s rig yaw damping while airborne.
@export var yaw_rate_ground: float = 2.0 ## Lazier rig yaw while grounded.
@export var pitch_rate: float = 3.5 ## 1/s rig pitch damping.
@export var pitch_follow: float = 0.45 ## Fraction of the body's pitch the rig adopts.
@export var roll_follow: float = 0.15 ## Fraction of the body's bank applied as cosmetic roll.

@export_group("Framing")
@export var base_pitch_deg: float = -18.0 ## Rest rig pitch: negative pitches the arm up so the camera sits above, looking slightly down.
@export var pivot_height_air: float = 1.4 ## Rig height above the pigeon in flight.
@export var pivot_height_ground: float = 0.6 ## Rig height above the pigeon while grounded.
@export var arm_length_air: float = 6.5
@export var arm_length_ground: float = 3.5
@export var framing_rate: float = 4.0 ## 1/s damping of arm length and pivot height.

@export_group("Speed feel")
@export var fov_air: float = 72.0
@export var fov_max: float = 86.0
@export var fov_ground: float = 65.0
@export var fov_speed: float = 20.0 ## Forward speed at which the FOV kick is fully on.
@export var fov_rate: float = 4.0 ## 1/s FOV damping.

var _yaw: float = 0.0
var _pitch: float = 0.0
var _pivot_height: float = 1.4

@onready var _player: Player = get_parent() as Player
@onready var _spring: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


## Current vertical FOV — the sim harness reads this.
var fov: float:
	get: return _camera.fov


## Current spring arm length — the sim harness reads this.
var arm_length: float:
	get: return _spring.spring_length


func _ready() -> void:
	var fwd := -_player.transform.basis.z
	if Vector2(fwd.x, fwd.z).length() > 0.1:
		_yaw = atan2(-fwd.x, -fwd.z)
	_pitch = deg_to_rad(base_pitch_deg)
	global_position = _player.global_position


func _physics_process(delta: float) -> void:
	var grounded := _player.is_on_floor()
	var fwd := -_player.transform.basis.z

	global_position = global_position.lerp(
			_player.global_position + Vector3.UP * _pivot_height,
			1.0 - exp(-position_rate * delta))

	if Vector2(fwd.x, fwd.z).length() > 0.1:
		var target_yaw := atan2(-fwd.x, -fwd.z)
		var yaw_rate := yaw_rate_ground if grounded else yaw_rate_air
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_rate * delta))

	# Rig pitch: base look-down offset plus a softened slice of the body pitch —
	# diving swings the camera up above the bird, climbing swings it low.
	var body_pitch := asin(clampf(fwd.y, -1.0, 1.0))
	var target_pitch := deg_to_rad(base_pitch_deg) + body_pitch * pitch_follow
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-pitch_rate * delta))

	rotation = Vector3(_pitch, _yaw, _player.bank_angle * roll_follow)

	_pivot_height = lerpf(_pivot_height,
			pivot_height_ground if grounded else pivot_height_air,
			1.0 - exp(-framing_rate * delta))
	_spring.spring_length = lerpf(_spring.spring_length,
			arm_length_ground if grounded else arm_length_air,
			1.0 - exp(-framing_rate * delta))

	var fov_target := fov_ground if grounded else lerpf(
			fov_air, fov_max, clampf(_player.forward_speed / fov_speed, 0.0, 1.0))
	_camera.fov = lerpf(_camera.fov, fov_target, 1.0 - exp(-fov_rate * delta))

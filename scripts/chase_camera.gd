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
@export var arm_length_air_fast: float = 5.8 ## Airborne arm length at the kick's saturation speed (fov_speed): the rig pulls in with speed so the bird reads bigger exactly when landing judgement happens at pace (T-044).
@export var arm_length_ground: float = 3.5
@export var framing_rate: float = 4.0 ## 1/s damping of arm length and pivot height.

@export_group("Speed feel")
@export var fov_air: float = 72.0
@export var fov_max: float = 79.0 ## Capped below the old 86: at cruise the pinned kick shrank the bird exactly when roof/landing judgement matters (T-044).
@export var fov_ground: float = 65.0
@export var fov_speed: float = 20.0 ## Forward speed at which the FOV kick is fully on.
@export var fov_rate: float = 4.0 ## 1/s FOV damping.

@export_group("Shake") ## T-013: tiny and cozy — landings and your own splat hits, never nauseating.
@export var shake_max_offset: float = 0.18 ## Lens offset (m) at full trauma.
@export var shake_max_roll: float = 0.03 ## Lens roll (rad) at full trauma.
@export var shake_decay: float = 1.4 ## Trauma fractions shed per second — a hit's tick lasts ~0.2 s.
@export var shake_rate: float = 24.0 ## How fast the shake pattern wanders (noise units/s).

var _yaw: float = 0.0
var _pitch: float = 0.0
var _pivot_height: float = 1.4
var _trauma: float = 0.0 ## 0..1; the shake strength is trauma² so small hits stay tiny.
var _shake_clock: float = 0.0
## Fixed-seed noise: the shake pattern is identical run to run, so a sim
## failure is a real regression, never per-run noise.
var _noise := FastNoiseLite.new()

@onready var _player: Player = get_parent() as Player
@onready var _spring: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


## Current vertical FOV — the sim harness reads this.
var fov: float:
	get: return _camera.fov


## Current spring arm length — the sim harness reads this.
var arm_length: float:
	get: return _spring.spring_length


## Current trauma (0..1) — tests and the autoplay DONE line report peak shake through it.
var trauma: float:
	get: return _trauma


## The live lens shake offset (m) — the sim harness asserts the shake is felt.
var shake_offset: Vector2:
	get: return Vector2(_camera.h_offset, _camera.v_offset)


func _ready() -> void:
	var fwd := -_player.transform.basis.z
	if Vector2(fwd.x, fwd.z).length() > 0.1:
		_yaw = atan2(-fwd.x, -fwd.z)
	_pitch = deg_to_rad(base_pitch_deg)
	global_position = _player.global_position
	_noise.seed = 20260928
	_noise.frequency = 1.0


## Kicks the shake up by `amount` trauma fractions (clamped to 1) — the juice
## pass (T-013) shakes hard landings (player) and scored splat hits (Main).
func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## (T-087) Teleports the rig onto the follow target it already chases and zeros
## the lens shake — Main calls this from the off-world guard's return beat, so
## the next `_physics_process` dampens in place from the respawn corridor
## instead of exponentially lerping hundreds of metres across the world (the
## blank chase frames the beat exists to cover). Yaw/pitch stay damped: they
## catch up in a few frames from wherever the pigeon now faces.
func snap_home() -> void:
	global_position = _player.global_position + Vector3.UP * _pivot_height
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_camera.rotation.z = 0.0


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
	## T-044: the airborne arm target pulls in with speed on the same ramp the
	## FOV kick rides — from arm_length_air at rest to arm_length_air_fast at
	## fov_speed — so the bird keeps a readable silhouette at cruise. The
	## grounded branch and the SpringArm3D's ownership of clipping are untouched.
	var arm_air := lerpf(arm_length_air, arm_length_air_fast,
			clampf(_player.forward_speed / fov_speed, 0.0, 1.0))
	_spring.spring_length = lerpf(_spring.spring_length,
			arm_length_ground if grounded else arm_air,
			1.0 - exp(-framing_rate * delta))

	var fov_target := fov_ground if grounded else lerpf(
			fov_air, fov_max, clampf(_player.forward_speed / fov_speed, 0.0, 1.0))
	_camera.fov = lerpf(_camera.fov, fov_target, 1.0 - exp(-fov_rate * delta))

	# T-013 shake: trauma decays linearly, the applied strength is trauma² so
	# small hits stay proportionally tiny, and the lens rides a fixed-seed noise
	# pattern. The offsets go on the CAMERA (image shift), never on this rig —
	# the rig's damped transform stays exact for the T-002 checks.
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	_shake_clock += delta * shake_rate
	var strength := _trauma * _trauma
	_camera.h_offset = shake_max_offset * strength * _noise.get_noise_2d(_shake_clock, 0.0)
	_camera.v_offset = shake_max_offset * strength * _noise.get_noise_2d(31.7, _shake_clock)
	_camera.rotation.z = shake_max_roll * strength * _noise.get_noise_2d(63.4, _shake_clock)

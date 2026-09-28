class_name Player
extends CharacterBody3D
## Arcade flight model for the pigeon (T-001): paced flap impulses, speed-generated
## lift, dive/pull-up energy exchange, banked turns and a stall below minimum
## airspeed. Every tunable is an @export for live tweaking.

@export_group("Flap")
@export var flap_impulse: float = 13.0 ## Up+forward impulse of a fully rested flap (m/s).
@export var flap_interval: float = 0.35 ## Seconds since the last flap for full strength; faster flaps are weaker.
@export var flap_min_fraction: float = 0.25 ## Impulse fraction when mash-spamming with no rest.
@export var flap_cooldown: float = 0.12 ## Hard floor between two flaps.

@export_group("Lift & stall")
@export var gravity: float = 12.0
@export var glide_speed: float = 17.0 ## Forward speed at which lift is maximal.
@export var min_gravity_fraction: float = 0.2 ## Gravity fraction left at full lift (never fully cancels).
@export var stall_speed: float = 5.0 ## Below this airspeed lift collapses and the nose drops.
@export var stall_gravity_scale: float = 1.7 ## Gravity multiplier while stalled.
@export var stall_nose_drop_rate: float = 1.1 ## Rad/s the nose pitches down while stalled.

@export_group("Handling")
@export var max_speed: float = 30.0
@export var drag: float = 0.06
@export var max_bank_deg: float = 40.0
@export var bank_rate: float = 3.5 ## Rad/s the body rolls toward the target bank.
@export var full_bank_yaw_rate: float = 1.5 ## Yaw rate (rad/s) at full bank, before authority scaling.
@export var pitch_speed: float = 2.2 ## Rad/s pitch rate, before authority scaling.
@export var min_control_authority: float = 0.35 ## Control floor at zero airspeed so stall recovery inputs still work.
@export var velocity_align_rate: float = 3.5 ## How hard velocity chases the nose (1/s); this is the energy exchange.
@export var ground_friction: float = 14.0 ## Horizontal decel while grounded; landings slide to a stop.

var forward_speed: float
var stalled: bool

## Current bank angle in radians — the chase camera and later HUD read this.
var bank_angle: float:
	get: return _roll

@onready var chase_camera: ChaseCamera = $ChaseCamera

var _flap_timer: float = 0.0
var _time_since_flap: float = 10.0
var _roll: float = 0.0


## Hard-reset position, orientation and motion (sim harness, later restart flow).
func reset_flight(pos: Vector3, yaw_deg: float = 0.0) -> void:
	position = pos
	rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	velocity = Vector3.ZERO
	_roll = 0.0
	_flap_timer = 0.0
	_time_since_flap = 10.0
	forward_speed = 0.0
	stalled = false


func _physics_process(delta: float) -> void:
	_flap_timer = maxf(_flap_timer - delta, 0.0)
	_time_since_flap += delta
	var grounded := is_on_floor()
	if not grounded:
		_steer(delta)
	_flap()
	_apply_flight_forces(delta, grounded)
	move_and_slide()


func _flap() -> void:
	if not Input.is_action_just_pressed("flap") or _flap_timer > 0.0:
		return
	var rested := clampf(_time_since_flap / flap_interval, flap_min_fraction, 1.0)
	var flap_dir := (transform.basis.y - transform.basis.z).normalized()
	velocity += flap_dir * flap_impulse * rested
	_flap_timer = flap_cooldown
	_time_since_flap = 0.0


func _steer(delta: float) -> void:
	var authority := clampf(forward_speed / glide_speed, min_control_authority, 1.0)
	var turn_input := Input.get_axis("turn_right", "turn_left")
	var max_bank := deg_to_rad(max_bank_deg)
	var target_roll := turn_input * max_bank
	var new_roll := move_toward(_roll, target_roll, bank_rate * authority * delta)
	rotate_object_local(Vector3.BACK, new_roll - _roll)
	_roll = new_roll
	if absf(_roll) > 0.01:
		# Yaw follows the bank: pigeon-like, not tank-like.
		rotate_y((_roll / max_bank) * full_bank_yaw_rate * authority * delta)
	var pitch_input := Input.get_axis("pitch_down", "pitch_up")
	rotate_object_local(Vector3.RIGHT, pitch_input * pitch_speed * authority * delta)


func _apply_flight_forces(delta: float, grounded: bool) -> void:
	forward_speed = velocity.dot(-transform.basis.z)
	stalled = forward_speed < stall_speed and not grounded
	var lift := clampf(forward_speed / glide_speed, 0.0, 1.0)
	var softening := 1.0 - (1.0 - min_gravity_fraction) * lift
	if stalled:
		velocity += Vector3.DOWN * (gravity * (stall_gravity_scale - 1.0)) * delta
		rotate_object_local(Vector3.RIGHT, -stall_nose_drop_rate * delta)
	var speed := velocity.length()
	if speed > 0.05:
		var vdir := velocity / speed
		var along := -vdir.y ## >0 descending, <0 climbing.
		# Gravity along the flight path is never softened: dives accelerate and
		# climbs pay, whatever the speed. Only the path-bending (sinking) part
		# yields to lift — that is the "lift softens gravity" feel.
		var g_along := vdir * (gravity * along)
		var g_perp := Vector3.DOWN * gravity - g_along
		velocity += (g_along + g_perp * softening) * delta
	velocity *= 1.0 - drag * delta
	# Velocity direction chases the nose (magnitude preserved — a lerp here would
	# bleed speed during maneuvers): pitching down converts height into speed,
	# pulling up converts it back. This is the arcade energy exchange.
	speed = velocity.length()
	if speed > 0.05:
		var dir := (velocity / speed).slerp(-transform.basis.z, clampf(velocity_align_rate * delta, 0.0, 1.0)).normalized()
		velocity = dir * speed
	velocity = velocity.limit_length(max_speed)
	if grounded:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)

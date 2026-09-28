class_name Player
extends CharacterBody3D
## Arcade flight model for the pigeon (T-001) plus the ground game (T-003):
## paced flap impulses, speed-generated lift, dive/pull-up energy exchange,
## banked turns and a stall below minimum airspeed in the air; gentle floor
## touches settle into a slow comedic waddle and flap takes off again. Hard
## touchdowns just skid — no damage model in M1. Every tunable is an @export
## for live tweaking.

## Emitted when the pigeon lands or takes off — the HUD swaps its control hint.
signal grounding_changed(grounded: bool)

## Emitted every time a flap impulse actually fires — hunger (T-005) drains
## faster while flapping, and the juice pass (T-013) hooks into it too.
signal flapped

## AIR covers flying *and* the skid after a hard touchdown; GROUND is the waddle.
enum State { AIR, GROUND }

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
@export var ground_friction: float = 14.0 ## Horizontal decel while sliding on the ground; landings skid to a stop.

@export_group("Landing & waddle")
@export var max_land_speed: float = 12.0 ## Total speed below which a floor touch settles into the waddle; faster ones skid.
@export var max_land_angle_deg: float = 30.0 ## Steepest descent angle that still counts as a gentle touchdown.
@export var walk_speed: float = 2.2 ## Waddle speed (m/s) — slow on purpose.
@export var walk_accel: float = 10.0 ## How fast waddling reaches walk speed (m/s²).
@export var walk_decel: float = 22.0 ## How fast waddling kills leftover landing momentum (m/s²).
@export var waddle_turn_rate: float = 2.6 ## Rad/s turn rate while waddling.
@export var ground_level_rate: float = 6.0 ## Rad/s the body rights its pitch/roll while on a floor.

@export_group("Ground pose")
@export var grounded_squat: float = 0.82 ## Mesh Y scale while grounded — readable "I'm walking now" pose.
@export var waddle_bob_rate: float = 10.0 ## Bob cycles per second while waddling.
@export var waddle_bob_height: float = 0.03 ## Vertical bob amplitude (m).
@export var waddle_sway: float = 0.1 ## Cosmetic roll amplitude of the waddle bob (rad).

var forward_speed: float
var stalled: bool
var state: State = State.AIR

## Current bank angle in radians — the chase camera and later HUD read this.
var bank_angle: float:
	get: return _roll


## True while the pigeon is in the grounded waddle state — HUD and tests read this.
var is_grounded: bool:
	get: return state == State.GROUND

@onready var chase_camera: ChaseCamera = $ChaseCamera
@onready var _mesh: MeshInstance3D = $Mesh

var _flap_timer: float = 0.0
var _time_since_flap: float = 10.0
var _roll: float = 0.0
var _air_grace: int = 0 ## Frames after a teleport where is_on_floor() is stale and must not trigger a landing.
var _waddle_phase: float = 0.0


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
	_waddle_phase = 0.0
	_air_grace = 2
	_set_state(State.AIR)
	_mesh.scale = Vector3.ONE
	_mesh.position = Vector3.ZERO
	_mesh.rotation = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_flap_timer = maxf(_flap_timer - delta, 0.0)
	_time_since_flap += delta
	if _air_grace > 0:
		_air_grace -= 1
	if state == State.GROUND:
		_flap() ## A grounded flap is a takeoff; it flips the state to AIR.
	if state == State.GROUND:
		_waddle(delta)
		move_and_slide()
		if not is_on_floor():
			_set_state(State.AIR) ## Waddled off a ledge — back to flight.
	else:
		_air_physics(delta)
	_update_pose(delta)


## The airborne half of the state machine: the full flight model, or the skid
## after a hard touchdown (flight forces + friction, no steering, body levels).
func _air_physics(delta: float) -> void:
	var was_on_floor := is_on_floor()
	if not was_on_floor:
		_steer(delta)
	else:
		_level_attitude(delta)
	_flap()
	_apply_flight_forces(delta, was_on_floor)
	var pre_vy := velocity.y
	var pre_speed := velocity.length()
	move_and_slide()
	if is_on_floor() and _air_grace <= 0:
		_try_settle(pre_vy, pre_speed)


## Floor contact while airborne: a shallow, slow enough touch settles into the
## waddle; anything harder keeps skidding until it has bled its speed.
func _try_settle(impact_vy: float, impact_speed: float) -> void:
	if impact_vy > 1.0: ## Moving up — a takeoff touch, not a landing.
		return
	if impact_speed > max_land_speed:
		return
	if impact_speed > 0.5 \
			and rad_to_deg(asin(clampf(-impact_vy / impact_speed, -1.0, 1.0))) > max_land_angle_deg:
		return
	_set_state(State.GROUND)


## Grounded locomotion: W/S shuffles along the body axis, A/D turns in place.
func _waddle(delta: float) -> void:
	stalled = false
	forward_speed = 0.0
	velocity.y = -2.0 ## Keep floor contact while waddling.
	var walk_input := Input.get_axis("pitch_down", "pitch_up")
	var turn_input := Input.get_axis("turn_right", "turn_left")
	rotate_y(turn_input * waddle_turn_rate * delta)
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var target_vel := fwd * walk_input * walk_speed
	# Slowing down is not the same as speeding up: a landing slide must stop
	# briskly or the pigeon ice-skates off whatever it landed on.
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var rate := walk_decel if hspeed > target_vel.length() + 0.1 else walk_accel
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta)
	_level_attitude(delta)


## On the floor the body rights itself: pitch and roll ease back to level so
## the waddle stands upright instead of face-planting.
func _level_attitude(delta: float) -> void:
	var fwd := -transform.basis.z
	var pitch := asin(clampf(fwd.y, -1.0, 1.0))
	var step := clampf(ground_level_rate * delta, 0.0, 1.0)
	if absf(pitch) > 0.001:
		rotate_object_local(Vector3.RIGHT, -pitch * step)
	var new_roll := move_toward(_roll, 0.0, ground_level_rate * delta)
	rotate_object_local(Vector3.BACK, new_roll - _roll)
	_roll = new_roll


## Cheap readability for the grounded state: a squat plus a bobbing sway while
## waddling (the real pose/animation arrives with T-011).
func _update_pose(delta: float) -> void:
	var k := 1.0 - exp(-10.0 * delta)
	_mesh.scale.y = lerpf(_mesh.scale.y, grounded_squat if state == State.GROUND else 1.0, k)
	var walking := state == State.GROUND and Vector2(velocity.x, velocity.z).length() > 0.3
	if walking:
		_waddle_phase += waddle_bob_rate * delta
		_mesh.position.y = waddle_bob_height * sin(_waddle_phase)
		_mesh.rotation.z = waddle_sway * sin(_waddle_phase)
	else:
		_mesh.position.y = lerpf(_mesh.position.y, 0.0, k)
		_mesh.rotation.z = lerpf(_mesh.rotation.z, 0.0, k)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	grounding_changed.emit(new_state == State.GROUND)


func _flap() -> void:
	if not Input.is_action_just_pressed("flap") or _flap_timer > 0.0:
		return
	var rested := clampf(_time_since_flap / flap_interval, flap_min_fraction, 1.0)
	var flap_dir := (transform.basis.y - transform.basis.z).normalized()
	if state == State.GROUND:
		# A startled takeoff fires up-and-forward from level attitude — the body
		# may still be nose-down right after a touchdown, and flapping along it
		# would lunge along the pavement instead of launching.
		var fwd := -transform.basis.z
		fwd.y = 0.0
		flap_dir = (Vector3.UP + fwd.normalized()).normalized()
	velocity += flap_dir * flap_impulse * rested
	_flap_timer = flap_cooldown
	_time_since_flap = 0.0
	if state == State.GROUND:
		_set_state(State.AIR) ## Takeoff.
	flapped.emit()


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

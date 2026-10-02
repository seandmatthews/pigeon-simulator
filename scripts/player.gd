class_name Player
extends CharacterBody3D
## Arcade flight model for the pigeon (T-001) plus the ground game (T-003):
## paced flap impulses, speed-generated lift, dive/pull-up energy exchange,
## banked turns and a stall below minimum airspeed in the air; gentle floor
## touches settle into a slow comedic waddle and flap takes off again. Hard
## touchdowns just skid — no damage model in M1. Every tunable is an @export
## for live tweaking. Since T-015 the airborne flap is mostly lift: its
## forward shove fades out across `flap_push_taper`, and since T-043 the
## impulse itself fades with the same blend (`flap_sustained_fade`) — pacing
## flaps converge in the low 20s of m/s and dives own the top end. Since T-036
## a fall past the `off_world_y` guard line — off the world's edge — quietly
## snaps home to `respawn_point` (Main wires the spawn corridor in). Since
## T-083 the input pitch term fades to zero across `pitch_auth_full_deg` /
## `pitch_auth_zero_deg` of |body pitch|, so held pitch-up asymptotes the nose
## just under the zero line instead of stacking degrees past vertical —
## symmetric, so steep dive entries past -50° fade progressively too. Since
## T-082 a RELEASED pitch input eases the nose toward the velocity vector
## (`trim_rate`) — hands-off flight settles into a real glide instead of
## preserving whatever deck angle the last input left. Since T-081 the
## velocity-align chase itself is graded by lift deficiency: below
## `glide_speed` its rate fades toward `mush_align_fraction`, so a slow,
## nose-high mush heaves over into a real sink instead of the aligner bending
## the fall back along the nose into a hover (the stall machinery is untouched).

## Emitted when the pigeon lands or takes off — the HUD swaps its control hint.
signal grounding_changed(grounded: bool)

## Emitted every time a flap impulse actually fires — hunger (T-005) drains
## faster while flapping, and the juice pass (T-013) hooks into it too.
signal flapped

## Emitted every time a poop drop leaves the pigeon (T-006) — tests and the
## autoplay pilot count drops through it; HUD/ammo readouts may later too.
signal pooped(poop: Poop)

## Emitted when the off-world guard snaps the pigeon home (T-095) — fired right
## before `reset_flight(respawn_point)`, so a synchronous handler still reads
## the void position. Since T-087 the emission carries that departure position
## as `from`; Main's return-beat handler (the feather poof marks it) and the
## sim/pilot evidence listen.
signal off_world_reset(from: Vector3)

## AIR covers flying *and* the skid after a hard touchdown; GROUND is the waddle.
enum State { AIR, GROUND }

@export_group("Flap")
@export var flap_impulse: float = 13.0 ## Up+forward impulse of a fully rested flap (m/s).
@export var flap_interval: float = 0.35 ## Seconds since the last flap for full strength; faster flaps are weaker.
@export var flap_min_fraction: float = 0.25 ## Impulse fraction when mash-spamming with no rest.
@export var flap_cooldown: float = 0.12 ## Hard floor between two flaps.
@export var flap_push_taper: float = 10.0 ## (T-015) m/s band over which the airborne flap's forward shove fades: full 45° shove at glide_speed - taper, pure lift at glide_speed — flaps climb and pace, dives add speed. Tune-safe: values ≤ 0 degrade to the old fixed 45° flap.
@export var flap_sustained_fade: float = 0.5 ## (T-043) Fraction of the flap impulse removed at full taper blend, so sustained flapping converges below the dive cap instead of at it. Tune 0.35–0.6 in playtest; 0 keeps the old full-power flap. Ground takeoffs and stall-recovery flaps (blend == 0) keep full power by construction.

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
@export var pitch_auth_full_deg: float = 50.0 ## (T-083) |Body pitch| at or below which the input pitch term keeps full authority; symmetric — the falloff bites pitch-down past -50° too.
@export var pitch_auth_zero_deg: float = 85.0 ## (T-083) |Body pitch| at or above which the input pitch term reaches zero — the attitude bound that stops held pitch-up from parking the nose at or past vertical.
@export var velocity_align_rate: float = 3.5 ## How hard velocity chases the nose (1/s); this is the energy exchange.
@export var mush_align_fraction: float = 0.15 ## (T-081) Fraction of `velocity_align_rate` left at total lift deficiency (zero or backward forward speed; the clamp catches backward drift). The align rate fades linearly in `forward_speed / glide_speed` from full authority at glide speed down to this floor, so sub-glide flight's sink develops instead of being bent back along a nose-high attitude into a hover — T-061's lane-tested tail value.
@export var trim_rate: float = 0.7 ## (T-082) Rad/s the nose eases toward the velocity vector on released pitch input, before `authority` scaling — a hands-off glide settles onto its flow instead of freezing the deck angle. 0 disables the trim.
@export var ground_friction: float = 14.0 ## Horizontal decel while sliding on the ground; landings skid to a stop.

@export_group("Flare") ## T-022: pitch-up in a shallow descent sheds airspeed into a nose-high sink instead of trading it all into a climb.
@export var flare_drag: float = 0.8 ## Extra 1/s drag on the horizontal velocity while flaring, scaled by pitch input (tune 0.5–0.8; 0.8 tuned — see T-022).
@export var flare_max_sink: float = 8.0 ## Lower edge of the flare band (m/s): sinks steeper than this are dives — the speed tool — and keep their speed.

@export_group("Bounds") ## T-042: the off-world guard — under the world there is no floor and no fail state but starvation.
@export var off_world_y: float = -5.0 ## The guard line (m). Unreachable over real terrain — the lowest walkable surface is the ground slab top at y = 0 — so only the void past the apron ever dips below it.

## Where the guard sends the pigeon (T-042): LOCAL coordinates, matching
## reset_flight's position convention. Main wires the spawn corridor in _ready()
## (Player has no City reference); the sim harness sets it directly.
var respawn_point: Vector3 = Vector3.ZERO
## Times the guard has fired this run (T-042): test evidence, and proof the
## reset cannot oscillate — the corridor sits ~360 m inside the world box, so a
## second fire would mean the respawn point itself is off-world.
var off_world_resets: int = 0

@export_group("Landing & waddle")
@export var max_land_speed: float = 16.0 ## Total speed below which a floor touch settles into the waddle; faster ones skid. (T-021 raised 12 → 16: the model's own trim glide touches down at 15.3–17.2 m/s, so the bar must sit above the natural arrival.)
@export var max_land_angle_deg: float = 30.0 ## Steepest descent angle that still counts as a gentle touchdown.
@export var skid_settle_speed: float = 2.0 ## (T-021) Speed a rejected touch's skid must bleed under before it may still settle near rest — the touch itself was already judged (and rejected) on first contact.
@export var walk_speed: float = 2.2 ## Waddle speed (m/s) — slow on purpose.
@export var walk_accel: float = 10.0 ## How fast waddling reaches walk speed (m/s²).
@export var walk_decel: float = 22.0 ## How fast waddling kills leftover landing momentum (m/s²).
@export var waddle_turn_rate: float = 2.6 ## Rad/s turn rate while waddling.
@export var ground_level_rate: float = 6.0 ## Rad/s the body rights its pitch/roll while on a floor.

@export_group("Pose") ## The visual pose thresholds (T-011) — when the wings read as a dive.
@export var dive_pose_nose: float = -0.35 ## Nose-pitch sine below which the wings sweep into the dive pose (~20° down).
@export var dive_pose_min_speed: float = 9.0 ## Forward speed (m/s) the dive pose demands — slow mushes stay glide.

@export_group("Poop")
@export var poop_scene: PackedScene = preload("res://scenes/poop.tscn") ## Projectile the poop action spawns.
@export var poop_cooldown: float = 1.0 ## Seconds between drops — mashing F stays at one dropping per second.
@export var poop_drop_offset: float = 0.3 ## Spawn distance below the body (m).

@export_group("Audio") ## T-012: the sounds ride the state machine's own events.
@export var effort_climb_speed: float = 2.0 ## Upward speed (m/s) the pigeon must ALREADY be climbing at for a flap to also play the strained wing-beat effort sound (the impulse itself would flatter every flap).

@export_group("Juice") ## T-013: the one-shots ride the same state events.
@export var feather_scene: PackedScene = preload("res://scenes/feather_poof.tscn") ## Feathers poof off a hard flap.
@export var dust_scene: PackedScene = preload("res://scenes/dust_puff.tscn") ## Dust kicks up on a touchdown.
@export var feather_flap_fraction: float = 0.85 ## Rested fraction a flap needs before it poofs feathers.
@export var feather_min_interval: float = 0.9 ## Hard floor between feather poofs — paced flapping never featherscreens.
@export var dust_impact_min: float = 1.5 ## Downward speed (m/s) a touchdown needs to kick up dust — just under the flight model's natural glide-touchdown sink (~1.8), so every real landing puffs.
@export var land_shake: float = 0.45 ## Camera-shake fraction of a max-speed touchdown (the camera scales it by impact).

var forward_speed: float
var stalled: bool
var state: State = State.AIR

## Current bank angle in radians — the chase camera and later HUD read this.
var bank_angle: float:
	get: return _roll


## True while the pigeon is in the grounded waddle state — HUD and tests read this.
var is_grounded: bool:
	get: return state == State.GROUND


## True while the poop cooldown has elapsed — the F readiness cue (T-077) reads this.
var poop_ready: bool:
	get: return _poop_timer <= 0.0

@onready var chase_camera: ChaseCamera = $ChaseCamera
@onready var pigeon: PigeonVisual = $Pigeon ## The T-011 presentation, driven from this state machine.

var _flap_timer: float = 0.0
var _time_since_flap: float = 10.0
var _poop_timer: float = 0.0
var _time_since_poof: float = 10.0 ## Seconds since the last feather poof — throttles the flap juice (T-013).
var _touchdown_velocity: Vector3 = Vector3.ZERO ## Velocity of the first floor contact in flight — the landing juice reads this, not the skid's leftovers (T-013).
var _roll: float = 0.0
var _air_grace: int = 0 ## Frames after a teleport where is_on_floor() is stale and must not trigger a landing.


func _ready() -> void:
	flapped.connect(pigeon.trigger_flap) ## Every real flap impulse plays a wing beat (T-011).


## Hard-reset position, orientation and motion (sim harness, later restart flow).
func reset_flight(pos: Vector3, yaw_deg: float = 0.0) -> void:
	position = pos
	rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	velocity = Vector3.ZERO
	_roll = 0.0
	_flap_timer = 0.0
	_poop_timer = 0.0
	_time_since_flap = 10.0
	_time_since_poof = 10.0
	_touchdown_velocity = Vector3.ZERO
	forward_speed = 0.0
	stalled = false
	_air_grace = 2
	_set_state(State.AIR)
	pigeon.reset_pose()


func _physics_process(delta: float) -> void:
	## (T-042, adopting T-036) Off-world guard: past the apron there is no floor
	## and no fail state but starvation, so the fall would run for minutes with
	## the HUD alive. Below the line, walk the fall back to the respawn corridor
	## with the existing hard reset — quietly (no sound, no popup; the return is
	## the beat) — after which the pigeon drops the short spawn drop and lands
	## normally. The counter makes a double fire loud: the corridor sits ~360 m
	## inside the world box, so a second fire would mean the respawn point
	## itself is off-world.
	if global_position.y < off_world_y:
		off_world_resets += 1
		off_world_reset.emit(global_position) ## (T-095, T-087) Beside the increment, before the reset — handlers see the void position, carried as `from`.
		reset_flight(respawn_point)
	_flap_timer = maxf(_flap_timer - delta, 0.0)
	_poop_timer = maxf(_poop_timer - delta, 0.0)
	_time_since_flap += delta
	_time_since_poof = minf(_time_since_poof + delta, 10.0)
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
		if velocity.y < 0.0:
			_touchdown_velocity = velocity ## Descending toward something — remember how hard (T-013).
	else:
		_level_attitude(delta)
	_flap()
	_try_poop()
	_apply_flight_forces(delta, was_on_floor)
	var pre_vy := velocity.y
	var pre_speed := velocity.length()
	move_and_slide()
	if not is_on_floor() or _air_grace > 0:
		return
	if not was_on_floor:
		## (T-021) First floor-contact frame: judge the touch itself on the
		## pre-move velocity — the same touch velocity `_touchdown_velocity`
		## recorded. Judging it once here is what makes a shallow glide settle
		## on the contact frame instead of ghost-sliding through it in AIR.
		_try_settle(pre_vy, pre_speed)
	elif velocity.length() < skid_settle_speed:
		## (T-021) A later AIR frame on the floor is the T-003 skid: its touch
		## was already judged and rejected, so it may only settle near rest.
		_try_settle(velocity.y, velocity.length())


## Floor contact while airborne: the touch frame judges the pre-move velocity —
## a shallow, slow enough touch settles into the waddle; anything harder keeps
## skidding (flight forces + friction) and only settles again once the skid has
## bled under `skid_settle_speed`.
func _try_settle(impact_vy: float, impact_speed: float) -> void:
	if impact_vy > 1.0: ## Moving up — a takeoff touch, not a landing.
		return
	if impact_speed > max_land_speed:
		return
	if impact_speed > 0.5 \
			and rad_to_deg(asin(clampf(-impact_vy / impact_speed, -1.0, 1.0))) > max_land_angle_deg:
		return
	_land_effects(impact_vy, impact_speed) ## Dust + shake, scaled by the touchdown (T-013).
	_set_state(State.GROUND)


## Landing juice (T-013): a puff of dust at the feet when the drop was real,
## and a small camera shake scaled by how hard the pigeon arrived — a tick,
## not a jolt. The impact is the recorded first-contact velocity: a straight
## drop settles a frame later with its speed already eaten by the slide, and
## the juice must still read the hit that actually happened.
func _land_effects(impact_vy: float, impact_speed: float) -> void:
	var impact := _touchdown_velocity if _touchdown_velocity != Vector3.ZERO \
			else Vector3(0.0, impact_vy, 0.0).limit_length(impact_speed)
	_touchdown_velocity = Vector3.ZERO
	if -impact.y >= dust_impact_min:
		var puff: OneShotBurst = dust_scene.instantiate()
		add_child(puff)
		puff.global_position = global_position - Vector3(0.0, 0.15, 0.0)
	chase_camera.add_shake(land_shake * clampf(impact.length() / max_land_speed, 0.15, 1.0))


## Flap juice (T-013): feathers poof off a fully-rested "hard" flap, throttled
## by `feather_min_interval` so paced flapping never featherscreens.
func _poof_feathers() -> void:
	_time_since_poof = 0.0
	var poof: OneShotBurst = feather_scene.instantiate()
	add_child(poof)
	poof.global_transform = Transform3D(OneShotBurst.basis_from_dir(global_transform.basis.y),
			global_position + global_transform.basis.y * 0.2)


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


## The presentation (T-011) mirrors this state machine every physics frame:
## glide/dive in the air, waddle/stand on the ground — the picture is derived
## from the physics state, so pose and model cannot desync. Flap beats ride on
## the `flapped` signal (wired in _ready); the eat peck arrives via `peck()`.
func _update_pose(delta: float) -> void:
	var walking := state == State.GROUND and Vector2(velocity.x, velocity.z).length() > 0.3
	var diving := state == State.AIR and not stalled \
			and forward_speed > dive_pose_min_speed \
			and (-transform.basis.z).y < dive_pose_nose
	pigeon.drive(state == State.GROUND, walking, diving, delta)


## The eat peck (T-011): Main wires the bread service's crumb_eaten relay here,
## so every swallowed crumb plays the comedic head-slam. The defaulted argument
## lets the crumb's restore-amount signal connect directly.
func peck(_amount: float = 0.0) -> void:
	pigeon.trigger_peck()
	Sfx.play("peck") ## The beak tap is audible too (T-012).


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	grounding_changed.emit(new_state == State.GROUND)


func _flap() -> void:
	if not Input.is_action_just_pressed("flap") or _flap_timer > 0.0:
		return
	var rested := clampf(_time_since_flap / flap_interval, flap_min_fraction, 1.0)
	var power := 1.0
	var flap_dir: Vector3
	if state == State.GROUND:
		# A startled takeoff fires up-and-forward from level attitude — the body
		# may still be nose-down right after a touchdown, and flapping along it
		# would lunge along the pavement instead of launching. Full power: the
		# sustained fade below is airborne-branch-only by construction.
		var fwd := -transform.basis.z
		fwd.y = 0.0
		flap_dir = (Vector3.UP + fwd.normalized()).normalized()
	else:
		# In the air the flap is mostly lift (T-015): its forward shove fades
		# out across `flap_push_taper` — the full 45° shove at low speed (so
		# stall recovery keeps its old bite), pure body-up lift at cruise. A
		# flap buys climb and pacing, never the top end; only diving adds real
		# speed. The maxf guard makes taper ≤ 0 degrade to the old fixed flap.
		# Since T-043 the impulse itself also fades with the same blend — at
		# cruise a flap is half strength, so sustained flapping converges below
		# the dive cap instead of at it (`flap_sustained_fade`; the ground
		# branch never computes `blend`, so takeoffs and blend == 0 recoveries
		# keep the exact old bite).
		var blend := clampf(
				(forward_speed - (glide_speed - flap_push_taper)) / maxf(flap_push_taper, 0.5),
				0.0, 1.0)
		power = 1.0 - flap_sustained_fade * blend
		flap_dir = (transform.basis.y - transform.basis.z).normalized().slerp(
				transform.basis.y, blend).normalized()
	var pre_vy := velocity.y ## The climb the pigeon was already working with.
	velocity += flap_dir * flap_impulse * rested * power
	_flap_timer = flap_cooldown
	_time_since_flap = 0.0
	if state == State.GROUND:
		_set_state(State.AIR) ## Takeoff.
	flapped.emit()
	Sfx.play("flap") ## Every impulse whooshes (T-012).
	if pre_vy >= effort_climb_speed:
		Sfx.play("effort") ## Paced flaps up a real climb earn the strained wing-beat too.
	if rested >= feather_flap_fraction and _time_since_poof >= feather_min_interval:
		_poof_feathers() ## Fully-rested flaps shed a feather or two (T-013).


## The poop action (T-006): air-only. The dropping inherits the pigeon's full
## velocity — the pilot leads moving targets with it — and gravity does the
## rest. Grounded pigeons don't drop; mashing is throttled by the cooldown.
func _try_poop() -> void:
	if not Input.is_action_just_pressed("poop") or _poop_timer > 0.0:
		return
	var poop: Poop = poop_scene.instantiate()
	add_child(poop)
	poop.top_level = true
	poop.global_position = global_position - global_transform.basis.y * poop_drop_offset
	poop.linear_velocity = velocity
	_poop_timer = poop_cooldown
	pooped.emit(poop)


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
	# (T-083, adopting T-062) Bound the attitude at the input: the pitch term
	# fades to zero across the band from `pitch_auth_full_deg` to
	# `pitch_auth_zero_deg` of |body pitch| — the same nose-sine read the sim's
	# `_pitch_until` uses — so held or tapped W asymptotes the nose just under
	# the zero line instead of stacking degrees past vertical. Symmetric by
	# design (the tested variant): steep dive entries past -50° lose authority
	# progressively too. Roll is already bounded by `max_bank_deg` above; the
	# falloff scales the input term only — the stall nose drop in
	# `_apply_flight_forces` and the no-input attitude freeze are untouched.
	var pitch := asin(clampf((-transform.basis.z).y, -1.0, 1.0))
	var fade := clampf(
			(deg_to_rad(pitch_auth_zero_deg) - absf(pitch))
					/ deg_to_rad(pitch_auth_zero_deg - pitch_auth_full_deg),
			0.0, 1.0)
	rotate_object_local(Vector3.RIGHT, pitch_input * pitch_speed * authority * fade * delta)
	# (T-082) Hands-off trim: with the pitch input released, ease the nose toward
	# the velocity direction (shortest arc, no roll component — the trim never
	# fights the bank), so a released glide settles onto its flow instead of
	# preserving whatever deck angle the last input left. The guards keep every
	# existing owner in charge: the stall path owns the nose (its own drop rate
	# below), a held input keeps full manual authority — the trim never fights
	# the pilot — and a degenerate flow vector (at or under stall speed) never
	# steers. Scaled by the same `authority` as the input terms so slow flight
	# trims gently. No auto-centering to the horizon: the trim targets the flow,
	# so a hands-off dive stays a dive.
	if not stalled and absf(pitch_input) < 0.01 and velocity.length() > stall_speed:
		var nose := -transform.basis.z
		var flow := velocity.normalized()
		var target := nose.slerp(flow, clampf(trim_rate * authority * delta, 0.0, 1.0)).normalized()
		transform.basis = Basis(Quaternion(nose, target)) * transform.basis


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
	# Flare (T-022): holding pitch-up while descending in the shallow band bleeds
	# HORIZONTAL speed, scaled by the input — the brake-sink that makes slow
	# landings settable instead of trading the whole glide into a balloon. The
	# band keeps both neighbors honest: climbs and level flight sit above it
	# (no mid-flight airbrake — the flare only ever fires while descending),
	# dives sit below `flare_max_sink` (the speed tool keeps its speed), and the
	# grounded skid keeps its own friction.
	var pitch_input := Input.get_axis("pitch_down", "pitch_up")
	if not grounded and pitch_input > 0.0 \
			and velocity.y < 0.0 and velocity.y > -flare_max_sink:
		var bleed := 1.0 - flare_drag * pitch_input * delta
		velocity.x *= bleed
		velocity.z *= bleed
	# Velocity direction chases the nose (magnitude preserved — a lerp here would
	# bleed speed during maneuvers): pitching down converts height into speed,
	# pulling up converts it back. This is the arcade energy exchange.
	# (T-081) The chase is graded by lift deficiency: at or above glide_speed the
	# wing carries the flow and keeps the full rate; below it the rate fades to
	# `mush_align_fraction`, so the above-stall-speed mush (lift only ~0.39 at
	# fwd ~6.6, `stalled` still false) can no longer bend its own sink back
	# along the nose every frame — gravity accumulates into a real fall. Keyed
	# on lift, not stall depth: the mush equilibrium sits ABOVE `stall_speed`,
	# where a depth key is exactly 0 by construction. The stall machinery
	# (stall gravity, nose drop, the flap's recovery bite) is untouched; this
	# only stops the wing from steering a fall it is not carrying.
	speed = velocity.length()
	if speed > 0.05:
		var deficiency := 1.0 - clampf(forward_speed / glide_speed, 0.0, 1.0)
		var align_rate := velocity_align_rate * lerpf(1.0, mush_align_fraction, deficiency)
		var dir := (velocity / speed).slerp(-transform.basis.z, clampf(align_rate * delta, 0.0, 1.0)).normalized()
		velocity = dir * speed
	velocity = velocity.limit_length(max_speed)
	if grounded:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)

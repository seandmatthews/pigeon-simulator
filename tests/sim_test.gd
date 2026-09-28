extends Node3D
## Headless sim harness (VERIFICATION.md Gate 1b): drives the Player with synthetic
## input and asserts flight-model behavior one scenario at a time. Run from the
## repo root:
##   godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
## Prints one "SIM PASS/FAIL <name>" line per scenario; exits 0 only when all pass.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

## Set SIM_DEBUG=1 to print per-scenario trajectory samples.
var _debug: bool = OS.get_environment("SIM_DEBUG") == "1"

var _player: Player
var _failures: int = 0


func _ready() -> void:
	_build_ground()
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_run_scenarios()


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	add_child(body)


func _run_scenarios() -> void:
	await _scenario_takeoff()
	await _scenario_lift()
	await _scenario_energy_exchange()
	await _scenario_banking()
	await _scenario_stall()
	await _scenario_landing_slide()
	await _scenario_chase_camera()
	print("SIM SUMMARY: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## --- helpers -------------------------------------------------------------


func _check(scenario: String, ok: bool, detail: String) -> void:
	if ok:
		print("SIM PASS %s" % scenario)
	else:
		_failures += 1
		print("SIM FAIL %s: %s" % [scenario, detail])


func _wait_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


## Resets the pigeon, optionally hands it an initial velocity, then lets the
## physics settle for a couple of frames.
func _set_up(airborne: bool, pos: Vector3, vel: Vector3) -> void:
	_player.reset_flight(pos)
	if airborne:
		_player.velocity = vel
	await _wait_frames(2)


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _wait_frames(frames)
	Input.action_release(action)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _wait_frames(1)
	Input.action_release(action)


## Holds a pitch action until the nose crosses target_pitch (given as the sine of
## the pitch angle: negative = below horizon), with a frame budget so a broken
## model can't hang the harness.
func _pitch_until(action: String, target_pitch: float, max_frames: int) -> void:
	var rising := action == "pitch_up"
	Input.action_press(action)
	for _i in max_frames:
		await get_tree().physics_frame
		var nose := (-_player.transform.basis.z).y
		if (rising and nose >= target_pitch) or (not rising and nose <= target_pitch):
			break
	Input.action_release(action)


func _dbg(msg: String) -> void:
	if _debug:
		print("[dbg] %s" % msg)


## Specific energy in metres: height plus speed squared over twice gravity.
func _energy(y: float, speed: float) -> float:
	return y + speed * speed / (2.0 * _player.gravity)


## --- scenarios (T-001 flight model) --------------------------------------


## Two–three paced flaps from the ground must reach climbing flight.
func _scenario_takeoff() -> void:
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	for _i in 3:
		await _tap("flap")
		await _wait_frames(24)
		_dbg("post-flap %d: y=%.2f vy=%.2f speed=%.2f since_flap=%.3f grounded=%s" % [
				_i + 1, _player.position.y, _player.velocity.y, _player.velocity.length(),
				_player._time_since_flap, _player.is_on_floor()])
	await _wait_frames(60)
	var altitude := _player.position.y
	var finite := _player.velocity.is_finite()
	_dbg("measure: y=%.2f vy=%.2f speed=%.2f" % [altitude, _player.velocity.y, _player.velocity.length()])
	_check("takeoff_3_flaps", altitude > 1.0 and finite,
			"altitude %.2f m after 3 flaps + 1 s (finite=%s)" % [altitude, finite])


## At cruise speed, lift must noticeably soften gravity: a 1.5 s glide sinks
## far less than free fall would.
func _scenario_lift() -> void:
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _wait_frames(90)
	var sink := 20.0 - _player.position.y
	_check("lift_softens_gravity", sink < 6.0 and _player.velocity.is_finite(),
			"sank %.1f m in 1.5 s at 12 m/s" % sink)


## Dive converts height into speed; pulling up converts it back into a visible
## climb that costs speed. Pitch is feedback-controlled to a nose angle rather
## than timed, so the scenario survives pitch-rate retunes.
func _scenario_energy_exchange() -> void:
	await _set_up(true, Vector3(0.0, 36.0, 0.0), Vector3(0.0, 0.0, -8.0))
	await _wait_frames(30)
	var y0 := _player.position.y
	var s0 := _player.velocity.length()
	_dbg("settle: e=%.1f y=%.1f v=%.1f" % [_energy(y0, s0), y0, s0])
	await _pitch_until("pitch_down", -0.85, 90)
	_dbg("nose-down: e=%.1f y=%.1f v=%.1f nose=%.2f" % [_energy(_player.position.y, _player.velocity.length()), _player.position.y, _player.velocity.length(), (-_player.transform.basis.z).y])
	await _wait_frames(60)
	var y1 := _player.position.y
	var s1 := _player.velocity.length()
	_dbg("dive-end: e=%.1f y=%.1f v=%.1f" % [_energy(y1, s1), y1, s1])
	_check("dive_gains_speed", s1 > s0 + 4.0 and y1 < y0 - 4.0,
			"speed %.1f->%.1f, height %.1f->%.1f" % [s0, s1, y0, y1])
	await _pitch_until("pitch_up", 0.42, 120)
	_dbg("pull-end: e=%.1f y=%.1f v=%.1f nose=%.2f" % [_energy(_player.position.y, _player.velocity.length()), _player.position.y, _player.velocity.length(), (-_player.transform.basis.z).y])
	var peak_y := _player.position.y
	var peak_speed := _player.velocity.length()
	for _i in 150:
		await get_tree().physics_frame
		_dbg("y=%.1f speed=%.1f nose=%.2f" % [_player.position.y, _player.velocity.length(), (-_player.transform.basis.z).y])
		if _player.position.y > peak_y:
			peak_y = _player.position.y
			peak_speed = _player.velocity.length()
	_check("pullup_gains_height", peak_y > y1 + 2.0 and peak_speed < s1 - 3.0,
			"peak %.1f m vs pull-start %.1f m, speed %.1f->%.1f at peak" % [peak_y, y1, s1, peak_speed])


## A held turn must bank the body and yaw with the bank (left turn: right wing
## up, nose swings toward -X).
func _scenario_banking() -> void:
	await _set_up(true, Vector3(0.0, 15.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _hold("turn_left", 60)
	var fwd := -_player.transform.basis.z
	var right_wing := _player.transform.basis.x.y
	_check("banked_left_turn", fwd.x < -0.3 and right_wing > 0.05,
			"forward (%.2f, %.2f, %.2f), right wing y %.2f" % [fwd.x, fwd.y, fwd.z, right_wing])


## Too slow: lift collapses — the stall leg must sink far harder than a glide leg
## at cruise speed — and the nose drops. Recovery is proven by stall_recovers.
func _scenario_stall() -> void:
	# Baseline: gliding at cruise speed sinks gently.
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _wait_frames(90)
	var glide_sink := 30.0 - _player.position.y
	# Stall leg: nearly no airspeed, no flaps.
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(0.0, 0.0, -1.0))
	var min_nose := 0.0
	for _i in 90:
		await get_tree().physics_frame
		min_nose = minf(min_nose, (-_player.transform.basis.z).y)
	var stall_sink := 30.0 - _player.position.y
	_check("stall_drops", stall_sink > 5.0 and stall_sink > 2.5 * glide_sink and min_nose < -0.2,
			"stall sank %.1f m vs glide %.1f m, min nose pitch %.2f" % [stall_sink, glide_sink, min_nose])
	await _tap("flap")
	await _wait_frames(30)
	var speed := _player.velocity.length()
	_check("stall_recovers", speed > 5.0 and _player.velocity.is_finite(),
			"speed %.1f m/s after recovery flap" % speed)


## A low, slow touchdown slides to a stop: no bounce, no tunneling, no NaNs.
func _scenario_landing_slide() -> void:
	await _set_up(true, Vector3(0.0, 0.4, 0.0), Vector3(0.0, 0.0, -7.0))
	await _wait_frames(150)
	var pos := _player.position
	var vel := _player.velocity
	var ok := vel.is_finite() and pos.is_finite() and vel.length() < 1.0 \
			and pos.y > -0.5 and pos.y < 0.6
	_check("landing_slides_to_stop", ok,
			"rest at y=%.2f, speed %.2f m/s" % [pos.y, vel.length()])


## --- scenarios (T-002 chase camera) --------------------------------------


## The rig swings around behind a turning pigeon, kicks FOV with speed and
## tucks in while grounded.
func _scenario_chase_camera() -> void:
	var cam: ChaseCamera = _player.chase_camera
	await _set_up(true, Vector3(0.0, 15.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _wait_frames(30)
	await _hold("turn_left", 90)
	await _wait_frames(30)
	var fwd := -_player.transform.basis.z
	var player_yaw := atan2(-fwd.x, -fwd.z)
	var gap := absf(angle_difference(cam.rotation.y, player_yaw))
	_check("camera_follows_yaw", gap < deg_to_rad(25.0),
			"rig trails heading by %.1f deg after a 1.5 s turn" % [rad_to_deg(gap)])
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -8.0))
	await _wait_frames(60)
	var fov_cruise := cam.fov
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -26.0))
	await _wait_frames(60)
	_check("camera_fov_kick", cam.fov > fov_cruise + 4.0,
			"fov %.1f at 8 m/s vs %.1f at 26 m/s" % [fov_cruise, cam.fov])
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	await _wait_frames(60)
	_check("camera_tucks_in_grounded", cam.arm_length < 4.5,
			"arm length %.2f m while grounded" % cam.arm_length)

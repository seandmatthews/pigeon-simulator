extends Node3D
## Headless sim harness (VERIFICATION.md Gate 1b): drives the Player with synthetic
## input and asserts flight, ground, city, hunger and poop behavior one scenario
## at a time.
## Run from the repo root:
##   godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
## Prints one "SIM PASS/FAIL <name>" line per scenario; exits 0 only when all pass.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CITY_SCENE: PackedScene = preload("res://scenes/city.tscn")
const CRUMB_SCENE: PackedScene = preload("res://scenes/bread_crumb.tscn")
const SPLAT_TARGET_SCRIPT := preload("res://tests/splat_target.gd")

## Set SIM_DEBUG=1 to print per-scenario trajectory samples.
var _debug: bool = OS.get_environment("SIM_DEBUG") == "1"

var _player: Player
var _city: City
var _ground: StaticBody3D ## The flat test-world floor — poop splat scenarios assert hits on it.
var _failures: int = 0
var _game_over_fires: int = 0 ## Signal counters survive inside lambdas only as members.
var _dropped: Array[Poop] = [] ## Poops the test player released (T-006).
var _splat_events: Array[Dictionary] = [] ## {target, velocity} per splatted hit of the poop under test.


func _ready() -> void:
	_build_world()
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_player.pooped.connect(_on_test_pooped)
	_run_scenarios()


## Flat ground plus a raised roof and a thin bench seat — the three landable
## surface types of T-003, all plain layer-1 world boxes. A full generated city
## joins them far away (T-004); its scenarios teleport the pigeon over there, so
## the flight-model scenarios above keep their clean flat world.
func _build_world() -> void:
	_ground = _add_box("Ground", Vector3(200.0, 1.0, 200.0), Vector3(0.0, -0.5, 0.0))
	_add_box("Roof", Vector3(8.0, 1.0, 8.0), Vector3(12.0, 5.0, -12.0)) ## top at y 5.5
	_add_box("Bench", Vector3(1.8, 0.1, 0.5), Vector3(0.0, 0.55, -8.0)) ## top at y 0.6
	_city = CITY_SCENE.instantiate() as City
	_city.position = Vector3(2000.0, 0.0, 2000.0)
	add_child(_city)


func _add_box(box_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)
	return body


func _run_scenarios() -> void:
	await _scenario_takeoff()
	await _scenario_lift()
	await _scenario_energy_exchange()
	await _scenario_banking()
	await _scenario_stall()
	await _scenario_landing_slide()
	await _scenario_chase_camera()
	await _scenario_ground_waddle()
	await _scenario_roof_landing()
	await _scenario_bench_landing()
	await _scenario_hard_landing()
	await _scenario_city_layout()
	await _scenario_city_plaza()
	await _scenario_city_street_flyover()
	await _scenario_city_roof()
	await _scenario_city_sidewalk()
	await _scenario_hunger_drain()
	await _scenario_hunger_game_over()
	await _scenario_bread_eating()
	await _scenario_bread_respawn()
	await _scenario_poop_lob()
	await _scenario_poop_grounded()
	await _scenario_poop_cooldown()
	await _scenario_poop_splat_ground()
	await _scenario_poop_splat_wall()
	await _scenario_poop_event_target()
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


## Resets the pigeon, optionally hands it an initial velocity and heading, then
## lets the physics settle for a couple of frames.
func _set_up(airborne: bool, pos: Vector3, vel: Vector3, yaw_deg: float = 0.0) -> void:
	_player.reset_flight(pos, yaw_deg)
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


## Waits until the pigeon settles into the grounded waddle state, with a frame
## budget so a broken landing can't hang the harness.
func _await_grounded(max_frames: int) -> void:
	for _i in max_frames:
		await get_tree().physics_frame
		if _player.is_grounded:
			return


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


## --- scenarios (T-003 land, walk, take off) -------------------------------


## A gentle drop onto flat ground settles into the waddle; W walks forward at
## waddle pace and A turns in place.
func _scenario_ground_waddle() -> void:
	await _set_up(true, Vector3(0.0, 3.0, 0.0), Vector3.ZERO)
	await _await_grounded(120)
	var pos0: Vector3 = _player.position
	var landed := _player.is_grounded and absf(_player.position.y - 0.3) < 0.15
	await _hold("pitch_up", 20)
	var walked: Vector3 = _player.position - pos0
	var hspeed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_check("waddles_on_ground",
			landed and _player.is_grounded and walked.length() > 0.2
					and hspeed < _player.walk_speed + 0.6,
			"landed=%s walked %.2f m at %.2f m/s horizontal" % [landed, walked.length(), hspeed])
	await _hold("turn_left", 30)
	var yaw := _player.rotation.y
	_check("waddle_turns", _player.is_grounded and absf(angle_difference(yaw, 0.0)) > deg_to_rad(25.0),
			"turned %.0f deg in 0.5 s, grounded=%s" % [rad_to_deg(angle_difference(yaw, 0.0)), _player.is_grounded])
	await _tap("flap")
	var peak_y := _player.position.y
	for _i in 60:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, _player.position.y)
		if not _player.is_grounded and peak_y > 0.8:
			break
	_check("flap_takes_off_ground", not _player.is_grounded and peak_y > 0.8,
			"airborne again, peaked at %.2f m after a grounded flap" % peak_y)


## A raised box models a building roof: the pigeon lands on it and flaps off it
## — takeoff from a roof works the same as from the pavement.
func _scenario_roof_landing() -> void:
	await _set_up(true, Vector3(12.0, 6.3, -12.0), Vector3.ZERO)
	await _await_grounded(150)
	_check("roof_landing", _player.is_grounded and absf(_player.position.y - 5.8) < 0.25,
			"grounded at y=%.2f on the roof (top 5.5)" % _player.position.y)
	await _tap("flap")
	var peak_y := _player.position.y
	for _i in 60:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, _player.position.y)
	_check("roof_takeoff", not _player.is_grounded and peak_y > 6.4,
			"airborne again, peaked at %.2f m (roof top 5.5)" % peak_y)


## A thin raised box models a bench seat: land on it, walk along it, flap off.
func _scenario_bench_landing() -> void:
	await _set_up(true, Vector3(0.0, 1.4, -8.0), Vector3.ZERO, 90.0) ## face along the bench
	await _await_grounded(150)
	await _wait_frames(15) ## let the touchdown slide bleed before the walk leg
	var pos0: Vector3 = _player.position
	var on_bench := _player.is_grounded and absf(_player.position.y - 0.9) < 0.2
	await _hold("pitch_up", 14)
	var walked: Vector3 = _player.position - pos0
	_check("bench_landing", on_bench and _player.is_grounded and walked.length() > 0.15
			and absf(_player.position.y - 0.9) < 0.2,
			"grounded on the bench at y=%.2f, walked %.2f m" % [_player.position.y, walked.length()])
	await _tap("flap")
	var peak_y := _player.position.y
	for _i in 60:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, _player.position.y)
	_check("bench_takeoff", not _player.is_grounded and peak_y > 1.5,
			"airborne again, peaked at %.2f m (bench top 0.6)" % peak_y)


## A steep, fast dive into the pavement must never instantly ground, never
## tunnel through the world and never NaN — it skids, bleeds speed, settles.
func _scenario_hard_landing() -> void:
	await _set_up(true, Vector3(0.0, 35.0, 0.0), Vector3(0.0, 0.0, -14.0))
	await _pitch_until("pitch_down", -0.85, 90)
	var min_y := 100.0
	var all_finite := true
	var skid_was_air := false
	for _i in 360:
		await get_tree().physics_frame
		min_y = minf(min_y, _player.position.y)
		all_finite = all_finite and _player.velocity.is_finite() and _player.position.is_finite()
		if _player.is_on_floor() and not _player.is_grounded \
				and _player.velocity.length() > _player.max_land_speed:
			skid_was_air = true
		if _player.is_grounded and _player.velocity.length() < 0.8:
			break
	var ok := skid_was_air and min_y > 0.1 and all_finite \
			and _player.is_grounded and _player.velocity.length() < 0.8
	_check("hard_landing_skids", ok,
			"fast touch stayed AIR=%s, min y %.2f, finite=%s, rest %.2f m/s grounded=%s" % [
					skid_was_air, min_y, all_finite, _player.velocity.length(), _player.is_grounded])


## --- scenarios (T-004 city blockout) ---------------------------------------


## The seed-independent guarantees of `City.report()`: a clear spawn plaza,
## flyable street widths, roof heights under the cruise ceiling and enough
## bread-capable surfaces — for the default seed and for a foreign one.
func _report_holds(report: Dictionary) -> bool:
	return report.plaza_clear \
			and report.street_width >= _city.min_flyable_street \
			and report.max_roof_height <= _city.max_roof_height \
			and report.bread_surfaces >= _city.min_bread_surfaces \
			and report.buildings > 0 and report.benches > 0


## Determinism: the same seed regenerates the identical layout, a foreign seed
## changes it without breaking the guarantees, and the default seed comes back
## byte-for-byte afterwards (the "restart twice" check, machine-shaped).
func _scenario_city_layout() -> void:
	var default_seed: int = _city.seed_value ## generate() overwrites seed_value — capture first.
	var fp_first: int = _city.fingerprint
	var report_a: Dictionary = _city.last_report
	_city.generate(default_seed)
	_check("city_same_seed_deterministic", _city.fingerprint == fp_first,
			"fingerprint %d vs %d" % [fp_first, _city.fingerprint])
	_city.generate(424242)
	var foreign: Dictionary = _city.last_report
	_check("city_new_seed_guarantees", _report_holds(foreign) and _city.fingerprint != fp_first,
			"foreign-seed report %s" % [foreign])
	_city.generate(default_seed)
	_check("city_regenerate_restores_layout",
			_city.fingerprint == fp_first and _report_holds(report_a)
					and _report_holds(_city.last_report),
			"fingerprint %d vs %d after foreign-seed regen" % [fp_first, _city.fingerprint])


## The spawn plaza: a short straight drop settles grounded on the pavement.
func _scenario_city_plaza() -> void:
	var plaza := _city.spawn_point - Vector3.UP * _city.spawn_drop_height
	await _set_up(true, plaza + Vector3.UP * 3.0, Vector3.ZERO)
	await _await_grounded(150)
	var y := _player.position.y
	var ok := _player.is_grounded and y > 0.3 and y < 0.6 and _player.velocity.is_finite()
	_check("city_plaza_spawn", ok, "grounded=%s at y=%.2f (slab top %.2f)" % [
			_player.is_grounded, y, _city.block_slab_height])


## Fly the length of an entire street corridor without touching anything —
## the "end-to-end across the city" acceptance criterion, machine-shaped.
func _scenario_city_street_flyover() -> void:
	var road_x := _city.position.x + _city.block_size * 0.5 + _city.road_width * 0.5
	var z_start := _city.position.z - _city.city_span * 0.5 + 4.0
	var z_end := _city.position.z + _city.city_span * 0.5 - 4.0
	await _set_up(true, Vector3(road_x, 26.0, z_start), Vector3(0.0, 0.0, 14.0), 180.0)
	var min_y := 1000.0
	var max_drift := 0.0
	var finite := true
	var crossed := false
	for i in 1500:
		await get_tree().physics_frame
		if i % 24 == 0 and _player.position.y < 28.0:
			await _tap("flap") ## Paced pulses keep it in the 24–30 m cruise band.
		min_y = minf(min_y, _player.position.y)
		max_drift = maxf(max_drift, absf(_player.position.x - road_x))
		finite = finite and _player.velocity.is_finite() and _player.position.is_finite()
		if _player.position.z >= z_end:
			crossed = true
			break
	_check("city_street_flyover", crossed and min_y > 5.0 and max_drift < 6.0 and finite,
			"crossed=%s, min y %.1f, max drift %.1f m, finite=%s" % [crossed, min_y, max_drift, finite])


## A generated building roof is landable and walkable (pairs with T-003), and
## flapping off it works like off any other floor.
func _scenario_city_roof() -> void:
	var roof: Dictionary = {}
	for info in _city.buildings:
		var c: Vector3 = info.center
		var dist := Vector2(c.x - _city.position.x, c.z - _city.position.z).length()
		if info.top <= 12.0 and dist > 20.0 and dist < 90.0:
			roof = info
			break
	if roof.is_empty():
		_check("city_roof_landable", false, "no low building generated near the plaza")
		_check("city_roof_takeoff", false, "no low building generated near the plaza")
		return
	var top: float = roof.top
	await _set_up(true, Vector3(roof.center.x, top + 0.35, roof.center.z), Vector3.ZERO)
	await _await_grounded(120)
	var y := _player.position.y
	var on_roof := _player.is_grounded and absf(y - (top + 0.3)) < 0.2
	await _wait_frames(10)
	var pos0: Vector3 = _player.position
	await _hold("pitch_up", 14)
	var walked := _player.position.distance_to(pos0)
	_check("city_roof_landable", on_roof and _player.is_grounded and walked > 0.15
			and absf(_player.position.y - (top + 0.3)) < 0.3,
			"grounded at y=%.2f (roof top %.2f), walked %.2f m" % [y, top, walked])
	await _tap("flap")
	var peak := _player.position.y
	for _i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, _player.position.y)
	_check("city_roof_takeoff", not _player.is_grounded and peak > top + 0.6,
			"airborne again, peaked at %.2f m (roof top %.2f)" % [peak, top])


## The sidewalk ring: the pigeon waddles up the low curb from the road and
## along the raised pavement.
func _scenario_city_sidewalk() -> void:
	var road_x := _city.position.x + _city.block_size * 0.5 + _city.road_width * 0.5
	await _set_up(true, Vector3(road_x, 1.2, _city.position.z), Vector3.ZERO, 90.0) ## face the curb
	await _await_grounded(120)
	await _wait_frames(10)
	await _hold("pitch_up", 180) ## 3 s of waddling west across the curb
	var walked := road_x - _player.position.x
	var y := _player.position.y
	_check("city_sidewalk_walkable", _player.is_grounded and walked > 5.0
			and absf(y - (_city.block_slab_height + 0.3)) < 0.05,
			"walked %.2f m west, grounded=%s at y=%.2f (slab top %.2f)" % [
					walked, _player.is_grounded, y, _city.block_slab_height])


## --- scenarios (T-005 bread & hunger) --------------------------------------


## The hunger clock ticks in flight, visibly faster while flapping than while
## gliding, and slowest of all while resting grounded.
func _scenario_hunger_drain() -> void:
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	var v0: float = hunger.value
	await _wait_frames(90)
	var glide_loss: float = v0 - hunger.value
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	v0 = hunger.value
	for _i in 3: ## Paced taps keep the flap-heat window alive for the whole leg.
		await _tap("flap")
		await _wait_frames(29)
	var flap_loss: float = v0 - hunger.value
	await _set_up(true, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	v0 = hunger.value
	await _wait_frames(90)
	var rest_loss: float = v0 - hunger.value
	_check("hunger_drain_flap_vs_glide",
			glide_loss > 0.2 and flap_loss > glide_loss * 1.4 and rest_loss < glide_loss,
			"lost %.2f gliding, %.2f flapping, %.2f resting in 1.5 s each" % [
					glide_loss, flap_loss, rest_loss])
	hunger.free()


## Hunger empties, clamps at zero and fires game_over EXACTLY once — eating
## afterwards refills the bar but the latch holds (T-010 builds on this).
func _scenario_hunger_game_over() -> void:
	var hunger := Hunger.new()
	hunger.player = _player
	hunger.drain_per_second = 60.0 ## Time-compressed: zero crossed ~1.7 s in.
	_game_over_fires = 0
	hunger.game_over.connect(func() -> void: _game_over_fires += 1)
	add_child(hunger)
	await _set_up(true, Vector3(0.0, 25.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _wait_frames(150) ## 2.5 s at 60/s: long past zero.
	var crossed_once: bool = _game_over_fires == 1 and hunger.value == 0.0
	hunger.eat(30.0)
	var restored: bool = hunger.value == 30.0
	await _wait_frames(30) ## Drains right back to zero — a second fire would prove the latch broken.
	_check("hunger_game_over_once",
			crossed_once and restored and _game_over_fires == 1 and hunger.value <= 0.5,
			"fires=%d crossed=%s restored=%s value=%.1f" % [
					_game_over_fires, crossed_once, restored, hunger.value])
	hunger.free()


## Eating is land-and-peck only: a low pass OVER a crumb never feeds, but a
## grounded pigeon that waddles into it eats it — hunger restored, crumb gone.
func _scenario_bread_eating() -> void:
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	var crumb: BreadCrumb = CRUMB_SCENE.instantiate()
	crumb.position = Vector3(0.0, 0.16, 0.0)
	add_child(crumb)
	crumb.eaten.connect(hunger.eat)
	await _set_up(true, Vector3(0.0, 2.4, 4.0), Vector3(0.0, 0.0, -8.0)) ## Overfly.
	var overfly_start: float = hunger.value
	await _wait_frames(40)
	var flew_over_uneaten: bool = is_instance_valid(crumb) and hunger.value < overfly_start - 0.05
	await _set_up(true, Vector3(0.0, 0.4, 1.8), Vector3.ZERO) ## Drop beside it…
	await _await_grounded(90)
	hunger.value = 40.0 ## Mid-bar so the +30 restore is measurable (a full bar would just clamp).
	var waddle_start: float = hunger.value
	await _hold("pitch_up", 90) ## …and waddle in (facing -Z, crumb ahead).
	var ate: bool = not is_instance_valid(crumb) and hunger.value > waddle_start + 10.0
	_check("crumb_eaten_grounded_only", flew_over_uneaten and ate,
			"overfly kept crumb=%s (hunger %.1f→%.1f), waddle ate=%s (hunger %.1f→%.1f)" % [
					flew_over_uneaten, overfly_start, waddle_start, ate, waddle_start, hunger.value])
	hunger.free()


## The bread service keeps `target_count` crumbs alive: eaten crumbs are
## forgotten, then replaced somewhere within one respawn interval.
func _scenario_bread_respawn() -> void:
	var spawner := BreadSpawner.new()
	spawner.city = _city
	spawner.target_count = 6
	spawner.respawn_interval = 0.5
	add_child(spawner)
	await _wait_frames(4)
	var initial: int = spawner.living_crumbs().size()
	var eaten_batch := spawner.living_crumbs().slice(0, 3)
	for crumb in eaten_batch:
		crumb.eaten.emit(crumb.restore) ## Same path a grounded pigeon triggers.
		crumb.free()
	await _wait_frames(2)
	var after_eating: int = spawner.living_crumbs().size()
	await _wait_frames(45) ## 0.75 s > respawn_interval.
	var respawned: int = spawner.living_crumbs().size()
	_check("crumbs_respawn",
			initial == 6 and after_eating == 3 and respawned == 6 and spawner.eaten_count == 3,
			"initial %d → eaten down to %d → topped back up to %d (eaten_count %d)" % [
					initial, after_eating, respawned, spawner.eaten_count])
	spawner.free()


## --- scenarios (T-006 poop mechanic) ----------------------------------------


## The harness listens to every drop the test player releases.
func _on_test_pooped(poop: Poop) -> void:
	_dropped.append(poop)


## The harness listens to the splat of the one poop a scenario is tracking.
func _on_test_splatted(target: Node, impact_velocity: Vector3) -> void:
	_splat_events.append({"target": target, "velocity": impact_velocity})


## An airborne drop inherits the pigeon's full velocity: the lob keeps the
## horizontal lead (moving targets can be led) and only ever falls — it can
## never hit anything above the pigeon.
func _scenario_poop_lob() -> void:
	_dropped.clear()
	_splat_events.clear()
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	var drop_y: float = _player.position.y - _player.poop_drop_offset
	await _tap("poop")
	await _wait_frames(2)
	var spawned := _dropped.size() == 1
	var poop: Poop = _dropped[0] if spawned else null
	var inherited := false
	var start_y := 0.0
	var start_flat := Vector2.ZERO
	if poop != null:
		var hv := poop.linear_velocity
		inherited = hv.is_finite() and Vector2(hv.x, hv.z).length() > 10.0
		start_y = poop.position.y
		start_flat = Vector2(poop.position.x, poop.position.z)
	var peak_y := start_y
	var fell := 0.0
	var led := 0.0
	for _i in 45: ## 0.75 s of ballistics.
		await get_tree().physics_frame
		if poop == null or not is_instance_valid(poop):
			break
		peak_y = maxf(peak_y, poop.position.y)
	if poop != null and is_instance_valid(poop):
		fell = start_y - poop.position.y
		led = Vector2(poop.position.x, poop.position.z).distance_to(start_flat)
	var air_only := peak_y <= start_y + 0.05
	_check("poop_inherits_and_arcs", spawned and inherited and fell > 2.0 and led > 5.0 and air_only,
			"spawned=%s inherited=%s fell %.1f m, led %.1f m sideways, peak vs drop %+0.2f m" % [
					spawned, inherited, fell, led, peak_y - start_y])


## F while grounded does nothing — droppings exist only in the air.
func _scenario_poop_grounded() -> void:
	_dropped.clear()
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	await _tap("poop")
	await _wait_frames(10)
	await _tap("poop")
	await _wait_frames(10)
	_check("poop_grounded_no_drop", _player.is_grounded and _dropped.is_empty(),
			"%d drops while grounded=%s" % [_dropped.size(), _player.is_grounded])


## Mashing F yields exactly one dropping; the next one comes only after the
## cooldown has fully elapsed.
func _scenario_poop_cooldown() -> void:
	_dropped.clear()
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _tap("poop")
	await _tap("poop") ## Mash: lands inside the cooldown window.
	await _wait_frames(3)
	var mashed: int = _dropped.size()
	await _wait_frames(70) ## 1.17 s > poop_cooldown.
	await _tap("poop")
	await _wait_frames(3)
	var after: int = _dropped.size()
	_check("poop_cooldown_blocks_stream", mashed == 1 and after == 2,
			"mash spawned %d, next tap made %d total" % [mashed, after])


## A drop onto the floor resolves the hit: splatted fires once with the floor
## as target and a falling impact velocity, the splat sticks to the hit body
## face-up at the surface, fades, and cleans itself up.
func _scenario_poop_splat_ground() -> void:
	_dropped.clear()
	_splat_events.clear()
	await _set_up(true, Vector3(0.0, 4.0, 0.0), Vector3(1.5, 0.0, 0.0))
	await _tap("poop")
	await _wait_frames(2)
	var dropped := _dropped.size() == 1
	var poop: Poop = _dropped[0] if dropped else null
	var splat: MeshInstance3D = null
	if poop != null:
		poop.fade_seconds = 1.5 ## Time-compressed fade.
		poop.splatted.connect(_on_test_splatted)
		splat = poop.splat_mesh
	await _wait_frames(90) ## Fall (~0.8 s) plus part of the fade.
	var fired := _splat_events.size() == 1
	var target: Node = _splat_events[0].target if fired else null
	var impact: Vector3 = _splat_events[0].velocity if fired else Vector3.ZERO
	var stuck := false
	var placed := false
	var fading := false
	if splat != null and is_instance_valid(splat):
		stuck = splat.get_parent() == _ground
		placed = absf(splat.global_position.y) < 0.1 \
				and splat.global_transform.basis.y.dot(Vector3.UP) > 0.95
		var mat := splat.material_override as StandardMaterial3D
		fading = mat != null and mat.albedo_color.a < 0.85 and mat.albedo_color.a >= 0.0
	await _wait_frames(90) ## Past the end of the fade.
	var cleaned := (splat == null or not is_instance_valid(splat)) \
			and (poop == null or not is_instance_valid(poop))
	var impact_ok := fired and impact.is_finite() and impact.y < -1.0
	_check("poop_splats_ground_and_fades",
			dropped and fired and target == _ground and impact_ok and stuck and placed and fading and cleaned,
			"dropped=%s fired=%s floor_target=%s impact_y=%.1f stuck=%s placed=%s fading=%s cleaned=%s" % [
					dropped, fired, target == _ground, impact.y, stuck, placed, fading, cleaned])


## A drop onto a vertical wall sticks to the wall: the splat faces along the
## wall's horizontal normal, proving splats read the surface they hit.
func _scenario_poop_splat_wall() -> void:
	_dropped.clear()
	_splat_events.clear()
	await _set_up(true, Vector3(6.2, 6.2, -12.0), Vector3(7.0, -3.0, 0.0)) ## Dive past the roof box's west face.
	await _tap("poop")
	await _wait_frames(2)
	var splat: MeshInstance3D = null
	if _dropped.size() == 1:
		_dropped[0].splatted.connect(_on_test_splatted)
		splat = _dropped[0].splat_mesh
	await _wait_frames(40) ## The wall is ~0.27 s of flight away.
	var fired := _splat_events.size() == 1
	var faced := false
	var on_wall := false
	var nx := 9.9
	var ny := 9.9
	var nz := 9.9
	var sx := 999.0
	var sy := 999.0
	var sz := 999.0
	if splat != null and is_instance_valid(splat):
		var n := splat.global_transform.basis.y
		nx = n.x
		ny = n.y
		nz = n.z
		sx = splat.global_position.x
		sy = splat.global_position.y
		sz = splat.global_position.z
		faced = n.x < -0.8 and absf(n.y) < 0.3
		## On the west face (x 8, y 4.5–5.5, z −16..−8). The z band allows for
		## the small −Z drift inherited from the player's nose-steering during
		## the settle frames — inheritance is the mechanic working, not noise.
		on_wall = splat.global_position.x < 8.15 \
				and absf(splat.global_position.y - 5.0) < 0.5 \
				and absf(splat.global_position.z + 12.0) < 0.8
	_check("poop_splats_wall", fired and faced and on_wall,
			"fired=%s normal=(%.2f, %.2f, %.2f) splat=(%.2f, %.2f, %.2f) on_wall=%s" % [
					fired, nx, ny, nz, sx, sy, sz, on_wall])


## Any body on the projectile's layers can receive the hit duck-typed
## (on_splatted) without importing the pigeon — and poop.gd references no
## player type at all, so targets and scoring stay decoupled.
func _scenario_poop_event_target() -> void:
	_dropped.clear()
	_splat_events.clear()
	var pad := SPLAT_TARGET_SCRIPT.new() ## Untyped: its script is a test asset, not a static type.
	pad.name = "SplatPad"
	pad.collision_layer = 1
	pad.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.0, 4.0)
	shape.shape = box
	pad.add_child(shape)
	pad.position = Vector3(40.0, 0.5, 0.0)
	add_child(pad)
	await _set_up(true, Vector3(40.0, 4.5, 0.0), Vector3.ZERO)
	await _tap("poop")
	await _wait_frames(2)
	if _dropped.size() == 1:
		_dropped[0].splatted.connect(_on_test_splatted)
	await _wait_frames(120) ## Fall (~0.75 s) plus margin.
	var fired: bool = _splat_events.size() == 1 and _splat_events[0].target == pad
	var pad_hits: int = pad.hits.size()
	var duck_typed: bool = pad_hits == 1 and pad.hits[0].y < -1.0
	var decoupled: bool = not (load("res://scripts/poop.gd") as GDScript).source_code.contains("Player")
	pad.queue_free()
	_check("poop_event_reaches_any_body", fired and duck_typed and decoupled,
			"signal_hit_pad=%s duck_typed=%s (hits %d) no_player_import=%s" % [
					fired, duck_typed, pad_hits, decoupled])

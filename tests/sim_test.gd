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
const POPUP_SCENE: PackedScene = preload("res://scenes/score_popup.tscn")
const SPLAT_TARGET_SCRIPT := preload("res://tests/splat_target.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const POOP_SCENE: PackedScene = preload("res://scenes/poop.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/menu.tscn")

## The Game autoload's high score file is redirected here for the scoring
## scenarios, so a sim run never touches the real record in user://.
const SIM_SAVE_PATH := "user://sim_highscore.cfg"

## (T-015) Forward-speed ceiling four paced ground flaps may pump. Measured
## 25.04 m/s under the tapered flap (fixed-fps sim); the old fixed 45° flap
## reached 28.7 m/s at THREE flaps and rode the 30 cap at four, so 26.0 both
## passes the new model with margin and fails the old one.
const FLAP_PUMP_CEIL := 26.0

## Set SIM_DEBUG=1 to print per-scenario trajectory samples.
var _debug: bool = OS.get_environment("SIM_DEBUG") == "1"

var _player: Player
var _city: City
var _ground: StaticBody3D ## The flat test-world floor — poop splat scenarios assert hits on it.
var _failures: int = 0
var _game_over_fires: int = 0 ## Signal counters survive inside lambdas only as members.
var _dropped: Array[Poop] = [] ## Poops the test player released (T-006).
var _splat_events: Array[Dictionary] = [] ## {target, velocity} per splatted hit of the poop under test.
var _tourist_relay: int = 0 ## tourist_splatted relays caught from the spawner under test (T-007).
var _car_relay: int = 0 ## car_splatted relays caught from the spawner under test (T-008).
var _score_events: Array[Dictionary] = [] ## hit_scored payloads caught from the Game autoload (T-009).
var _main_game: MainGame ## The real main.tscn instance the T-010 flow scenarios share.
var _bread_shared: Array[Dictionary] = [] ## bread_shared relays caught from the elder spawner under test (T-020).
var _regen_relay: int = 0 ## regenerated relays caught from the city under restart (T-033) — signal counters survive inside lambdas only as members.


func _ready() -> void:
	## Redirect the Game autoload's high-score file for the WHOLE run: several
	## scenarios score real hits through it, and none of them may ever touch
	## the player's actual record in user://highscore.cfg.
	Game.save_path = SIM_SAVE_PATH
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
	await _scenario_flap_speed_envelope()
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
	await _scenario_trim_glide_lands_clean()
	await _scenario_flare_sheds_speed_low() ## T-022 — pitch-up low brakes into a nose-high sink instead of ballooning.
	await _scenario_off_world_fall_respawns() ## T-042 — flight-model guard: the void past the apron walks home.
	await _scenario_city_layout()
	await _scenario_city_plaza()
	await _scenario_city_street_flyover()
	await _scenario_city_roof()
	await _scenario_city_sidewalk()
	await _scenario_city_district_palettes()
	await _scenario_city_shopfronts()
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
	await _scenario_poop_ball_visible() ## T-086 — the drop reads from the chase cam: bigger emissive ball, collider untouched.
	await _scenario_poop_ready_indicator_tracks_cooldown() ## T-077 — unpaused tree, no live Main, like the poop block.
	await _scenario_tourists_walk()
	await _scenario_tourist_splat()
	await _scenario_tourist_buzz()
	await _scenario_tourists_recycle()
	await _scenario_cars_traffic()
	await _scenario_car_splat_honk()
	await _scenario_traffic_recycle_keeps_flow() ## T-089 — the recycle insertion path must not clot a ring.
	await _scenario_scoring_values()
	await _scenario_high_score_persists()
	await _scenario_score_popup()
	await _scenario_pause_freezes()
	await _scenario_title_escape_does_not_quit() ## T-097 — Esc at the title must not hard-quit.
	await _scenario_game_over_screen()
	await _scenario_restart_resets()
	await _scenario_restart_same_seed_skips_rebuild()
	await _scenario_hud_bread_pointer_tracks_nearest_crumb() ## T-037 — T-019 window: unpaused tree, no live Main.
	await _scenario_hud_hunger_tiers() ## T-019 — must follow the restart scenarios: unpaused tree, no live Main.
	await _scenario_elder_placement_no_rng()
	await _scenario_elder_shares_bread_after_hangout()
	await _scenario_elder_no_bread_airborne()
	await _scenario_elder_cooldown_blocks_second_share()
	await _scenario_city_cafe_tables() ## T-031 — after the elder block, same rig pattern.
	await _scenario_city_roofs_inhabited() ## T-032 — after the cafe block, same audit pattern.
	await _scenario_city_crosswalks() ## T-069 — after the roofs block, same audit pattern.
	await _scenario_city_apron_rim() ## T-088 commit 1 — after the crosswalks block, same audit pattern.
	await _scenario_city_horizon_skyline() ## T-088 commit 2 — after the rim, same audit pattern.
	await _scenario_pigeon_air_poses()
	await _scenario_pigeon_ground_poses()
	await _scenario_pigeon_peck()
	await _scenario_pigeon_silhouette_contrast()
	await _scenario_juice_splat_burst()
	await _scenario_juice_feather_poof()
	await _scenario_juice_dust_puff()
	await _scenario_juice_landing_shake()
	await _scenario_juice_hit_shake_pulse()
	await _scenario_audio_buses()
	await _scenario_audio_boots_muted() ## T-101 — after the bus mix, same audio block.
	await _scenario_audio_flap_effort()
	await _scenario_audio_peck()
	await _scenario_audio_hit_sounds()
	await _scenario_ambience_bed()
	await _scenario_density_cpu_budget()
	await _scenario_off_world_fall_returns_home() ## T-036 — last: bends _player.respawn_point for its own window.
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


## (T-015) The flap is lift-first, not throttle: four paced flaps from the
## ground climb without pumping forward speed toward the cap, and at cruise a
## flap adds climb, not forward speed. The cruise tap is sampled at +1 and +2
## frames after a 30-frame settled glide — the magnitude-preserving nose-chase
## converts lift into forward speed within a few frames, and the envelope
## claim is about the impulse, not that conversion.
func _scenario_flap_speed_envelope() -> void:
	# Leg 1 — four paced flaps from the ground, no pitch input. The pump
	# ceiling is the largest forward speed seen through the cadence and the
	# second after it (the old fixed 45° flap hit the cap here).
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	var pump_speed := 0.0
	for _i in 4:
		await _tap("flap")
		await _wait_frames(24)
		pump_speed = maxf(pump_speed, _player.forward_speed)
	for _i in 60:
		await get_tree().physics_frame
		pump_speed = maxf(pump_speed, _player.forward_speed)
	var pump_y := _player.position.y
	var finite := _player.velocity.is_finite()
	_dbg("envelope pump: y=%.2f pump_fwd=%.2f speed=%.2f" % [
			pump_y, pump_speed, _player.velocity.length()])
	# Leg 2 — one fully-rested flap at cruise, measured from a settled glide.
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -17.0))
	await _wait_frames(30)
	var fwd0 := _player.forward_speed
	var vy0 := _player.velocity.y
	await _tap("flap")
	await _wait_frames(1)
	var fwd1 := _player.forward_speed
	var vy1 := _player.velocity.y
	await _wait_frames(1)
	var fwd2 := _player.forward_speed
	var vy2 := _player.velocity.y
	_dbg("envelope cruise tap: fwd %.2f -> %.2f -> %.2f, vy %.2f -> %.2f -> %.2f" % [
			fwd0, fwd1, fwd2, vy0, vy1, vy2])
	var fwd_gain := maxf(fwd1, fwd2) - fwd0
	var vy_gain := vy1 - vy0
	_check("flap_speed_envelope",
			pump_speed < FLAP_PUMP_CEIL and pump_y > 1.0 and fwd_gain < 2.0 and vy_gain > 4.0
					and finite,
			"pump %.1f m/s (ceil %.1f) at y %.1f, cruise tap fwd +%.2f vy +%.2f" % [
					pump_speed, FLAP_PUMP_CEIL, pump_y, fwd_gain, vy_gain])


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
	## (T-044) Absolute bounds on the 26 m/s leg, not a relative margin: with
	## fov_max 79 the damped 26 m/s read sits ~78.9 — under ~4.2 of margin
	## against the old 4.0 threshold, so the relative assert had gone blind.
	## The bounds prove the kick survives (fov_air 72 sits below the floor)
	## but stops pinning at cruise (the old pinned fov_max 86 measured 85.9
	## here and failed), and the arm must read pulled in with speed (the old
	## fixed 6.5 m target measured 6.50 here and failed < 6.2).
	_check("camera_fov_kick",
			cam.fov <= 80.0 and cam.fov >= 74.0 and cam.arm_length < 6.2,
			"fov %.1f at 26 m/s (bounds 74.0-80.0; 8 m/s leg read %.1f), arm %.2f m (< 6.2)" % [
					cam.fov, fov_cruise, cam.arm_length])
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
		## (T-021) The skid detector reads the skid bar, not the settle bar:
		## an AIR frame on the floor above `skid_settle_speed` means the touch
		## was rejected and the pigeon is still skidding. (The old bar,
		## `max_land_speed`, went blind when the settle bar rose to 16 — the
		## dive's floor speeds sit below it — while the behavior stayed correct.)
		if _player.is_on_floor() and not _player.is_grounded \
				and _player.velocity.length() > _player.skid_settle_speed:
			skid_was_air = true
		if _player.is_grounded and _player.velocity.length() < 0.8:
			break
	var ok := skid_was_air and min_y > 0.1 and all_finite \
			and _player.is_grounded and _player.velocity.length() < 0.8
	_check("hard_landing_skids", ok,
			"fast touch stayed AIR=%s, min y %.2f, finite=%s, rest %.2f m/s grounded=%s" % [
					skid_was_air, min_y, all_finite, _player.velocity.length(), _player.is_grounded])


## (T-021) A natural trim-speed glide touchdown settles into the waddle ON the
## contact frame: the pigeon ends GROUNDED having spent zero airborne
## floor-contact frames above the skid bar — the old model ghost-slid ~3 m in
## AIR past the touch because the settle bar sat under the glide's own arrival
## speed. Started low (~1.5–2 m) so the touch arrives ≈ 15.3 m/s: higher starts
## bleed less and can exceed the 16 m/s settle bar (SIM_DEBUG prints the touch).
func _scenario_trim_glide_lands_clean() -> void:
	await _set_up(true, Vector3(0.0, 1.8, 0.0), Vector3(0.0, 0.0, -17.0))
	var air_floor_frames: int = 0
	var first_air_floor_speed := 0.0 ## Speed of the first AIR frame on the floor — the touch, if the settle missed it.
	var settle_speed := 0.0 ## Speed at the grounding frame — with a contact-frame settle this IS the touch speed.
	for _i in 300:
		await get_tree().physics_frame
		if _player.is_on_floor() and not _player.is_grounded:
			if first_air_floor_speed <= 0.0:
				first_air_floor_speed = _player.velocity.length()
			if _player.velocity.length() > _player.skid_settle_speed:
				air_floor_frames += 1
		if _player.is_grounded:
			settle_speed = _player.velocity.length()
			break
	var finite := _player.velocity.is_finite() and _player.position.is_finite()
	_dbg("trim glide: touch %.2f m/s, %d air floor frames, grounded=%s, settled at %.2f m/s" % [
			first_air_floor_speed, air_floor_frames, _player.is_grounded, settle_speed])
	_check("trim_glide_lands_clean", _player.is_grounded and air_floor_frames == 0 and finite,
			"grounded=%s, %d airborne floor frames above %.1f m/s (first AIR-floor speed %.2f, settled at %.2f m/s, finite=%s)" % [
					_player.is_grounded, air_floor_frames, _player.skid_settle_speed,
					first_air_floor_speed, settle_speed, finite])


## (T-022) Holding pitch-up low sheds speed into a nose-high sink instead of
## ballooning: from a settled ~15 m/s glide at ~6 m, 45 frames (0.75 s) of held
## pitch-up must gain < 2.5 m of height AND end below 11 m/s. Before the flare
## the same input traded the whole glide speed into a rocket climb (the ticket
## measured ~+10 m of balloon on this very input).
func _scenario_flare_sheds_speed_low() -> void:
	await _set_up(true, Vector3(0.0, 6.0, 0.0), Vector3(0.0, 0.0, -15.0))
	await _wait_frames(30) ## Settle into the trim glide.
	var y0 := _player.position.y
	var s0 := _player.velocity.length()
	await _hold("pitch_up", 45)
	var y1 := _player.position.y
	var s1 := _player.velocity.length()
	var finite := _player.velocity.is_finite()
	_dbg("flare: y %.2f -> %.2f, speed %.2f -> %.2f, end vy %.2f" % [
			y0, y1, s0, s1, _player.velocity.y])
	_check("flare_sheds_speed_low",
			s0 > 13.0 and y1 - y0 < 2.5 and s1 < 11.0 and finite,
			"settled speed %.2f m/s, height %+.2f m over the hold, ended %.2f m/s (finite=%s)" % [
					s0, y1 - y0, s1, finite])


## --- scenario (T-042 off-world guard) ---------------------------------------


## Flying off the world — past the ±(city_span/2 + ground_extra) = ±367 m apron
## — must not strand the pigeon under an empty plane until starvation: below
## `off_world_y` (−5) the guard walks the fall back to `respawn_point` with the
## existing hard reset, exactly once (a second fire would mean the respawn
## point itself is off-world), while the hunger clock keeps draining straight
## through it. The harness player has no city wired (`_build_world` above), so
## the scenario sets the respawn point itself over the flat test ground,
## mirroring what Main does. Start BELOW the guard (y −10) and past where any
## floor exists (the harness ground spans ±100), so without the guard the
## pigeon falls forever. (The planning sketch's y −2 start was broken as
## written: the sink only reaches ≈ −2.4 by frame 30 and the −5 guard never
## fires.) Hunger rides the `_scenario_hunger_drain` local-clock pattern.
func _scenario_off_world_fall_respawns() -> void:
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	_player.respawn_point = Vector3(0.0, 0.3, 0.0) ## Flat test ground, standing height.
	var hunger0: float = hunger.value
	await _set_up(true, Vector3(0.0, -10.0, -400.0), Vector3.ZERO) ## Below the guard, past every floor.
	var all_finite := true
	var grounded := false
	for _i in 120: ## ~2 s to land on the corridor.
		await get_tree().physics_frame
		all_finite = all_finite and _player.velocity.is_finite()
		if _player.is_grounded \
				and _player.global_position.distance_to(_player.respawn_point) < 2.0:
			grounded = true
			break
	var landed := grounded and _player.off_world_resets == 1 \
			and _player.velocity.is_finite()
	var stable := true
	var rest_distance := INF
	for _i in 120: ## ~2 s more: no second fire, no drift off the corridor.
		await get_tree().physics_frame
		all_finite = all_finite and _player.velocity.is_finite()
		if _player.off_world_resets != 1:
			stable = false
	rest_distance = _player.global_position.distance_to(_player.respawn_point)
	stable = stable and rest_distance < 0.5
	var kept_draining := hunger0 - hunger.value > 0.2
	_check("off_world_fall_respawns",
			landed and stable and kept_draining and all_finite,
			"grounded=%s resets=%d stable=%s (rest %.2f m) hunger_loss=%.2f finite=%s" % [
					grounded, _player.off_world_resets, stable, rest_distance,
					hunger0 - hunger.value, all_finite])
	hunger.free()
	_player.respawn_point = Vector3.ZERO ## Housekeeping — later scenarios wire none.


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
	var builds_before: int = _city.build_count ## T-033: every real rebuild below must bump it.
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces the layout.
	_check("city_same_seed_deterministic", _city.fingerprint == fp_first
			and _city.build_count == builds_before + 1,
			"fingerprint %d vs %d" % [fp_first, _city.fingerprint])
	_city.generate(424242)
	var foreign: Dictionary = _city.last_report
	_check("city_new_seed_guarantees", _report_holds(foreign) and _city.fingerprint != fp_first
			and _city.build_count == builds_before + 2,
			"foreign-seed report %s" % [foreign])
	_city.generate(default_seed, true) ## Real rebuild, for consistent teardown semantics.
	_check("city_regenerate_restores_layout",
			_city.fingerprint == fp_first and _report_holds(report_a)
					and _report_holds(_city.last_report)
					and _city.build_count == builds_before + 3,
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
			await _tap("flap") ## T-015: taps pace the climb toward the band; the crossing itself rides a glide flaps can no longer throttle past ~25.
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


## The district palettes (T-013): every building wears a color from ITS
## district's palette, all four districts actually appear in the city, the
## palettes are measurably distinct from each other, and the district mapping
## is the pure quadrant function it claims to be.
func _scenario_city_district_palettes() -> void:
	var districts_seen := {}
	var members_ok := true
	for info in _city.buildings:
		var district: int = info.district
		districts_seen[district] = true
		var member := false
		for c: Color in _city.DISTRICT_PALETTES[district]:
			member = member or (info.color as Color).is_equal_approx(c)
		members_ok = members_ok and member
	var means: Array[Color] = []
	for palette: Array in _city.DISTRICT_PALETTES:
		var sum := Color(0.0, 0.0, 0.0)
		for c: Color in palette:
			sum += c
		means.append(sum / float(palette.size()))
	var distinct := true
	for i in means.size():
		for j in range(i + 1, means.size()):
			var a := means[i]
			var b := means[j]
			distinct = distinct and Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) > 0.1
	var mapping_ok := _city.district_of(0, 0) == 0 \
			and _city.district_of(_city.blocks_per_side - 1, 0) == 1 \
			and _city.district_of(0, _city.blocks_per_side - 1) == 2 \
			and _city.district_of(_city.blocks_per_side - 1, _city.blocks_per_side - 1) == 3
	var all_four := districts_seen.size() == _city.DISTRICT_PALETTES.size()
	_check("city_district_palettes_distinct", members_ok and distinct and mapping_ok and all_four,
			"members=%s distinct=%s mapping=%s districts_seen=%d/%d" % [
					members_ok, distinct, mapping_ok,
					districts_seen.size(), _city.DISTRICT_PALETTES.size()])


## --- scenarios (T-017 shopfront ground floors) ------------------------------


## Every building wears a ground-floor shop band, a door on one of its two
## street-facing faces, and the seeded share of awnings; the shopfront palette
## stays measurably distinct from all four district palettes. Under the fixed
## seed every roll is deterministic, so coverage is asserted at 100% and the
## awning count is pinned to the seed's exact draw (104 of 146 = 71.2% for
## awning_chance 0.6 at seed 20260928 — retune the pin if the chance changes).
func _scenario_city_shopfronts() -> void:
	var members_ok := true
	var doors_on_street := true
	var awnings := 0
	for info in _city.buildings:
		var shop := false
		for c: Color in _city.SHOPFRONT_PALETTE:
			shop = shop or (info.shop_color as Color).is_equal_approx(c)
		members_ok = members_ok and shop
		## The lot's street faces are the two whose outward normal points away
		## from the block center; the other two look into the alley.
		var lot: Vector2 = info.lot_offset
		var street_faces: Array[int] = []
		if lot.x > 0.0:
			street_faces.append(0)
		elif lot.x < 0.0:
			street_faces.append(1)
		if lot.y > 0.0:
			street_faces.append(2)
		elif lot.y < 0.0:
			street_faces.append(3)
		doors_on_street = doors_on_street and street_faces.has(int(info.door_face))
		if info.has_awning:
			awnings += 1
	var count := _city.buildings.size()
	var awn_share := float(awnings) / float(maxi(count, 1))
	## Shop palette vs district palette means — mirrors the T-013 distinctness read.
	var shop_mean := Color(0.0, 0.0, 0.0)
	for c: Color in _city.SHOPFRONT_PALETTE:
		shop_mean += c
	shop_mean /= float(_city.SHOPFRONT_PALETTE.size())
	var palette_distinct := true
	for palette: Array in _city.DISTRICT_PALETTES:
		var sum := Color(0.0, 0.0, 0.0)
		for c: Color in palette:
			sum += c
		var mean := sum / float(palette.size())
		var shop_v := Vector3(shop_mean.r, shop_mean.g, shop_mean.b)
		var district_v := Vector3(mean.r, mean.g, mean.b)
		palette_distinct = palette_distinct and shop_v.distance_to(district_v) > 0.1
	var coverage_ok := count > 0 and members_ok and doors_on_street and palette_distinct
	## The seed's exact deterministic draw — an extra (or missing) _shop_rng roll
	## anywhere upstream would shift this count and fail here.
	var awn_ok := awnings == 104
	_check("city_shopfronts_present", coverage_ok and awn_ok,
			"buildings=%d members=%s doors_on_street=%s palette_distinct=%s awnings=%d (%.1f%%)"
					% [count, members_ok, doors_on_street, palette_distinct,
					awnings, awn_share * 100.0])
	## Same seed → every shopfront roll reproduces identically.
	var default_seed: int = _city.seed_value
	var snapshot: Array = []
	for info in _city.buildings:
		snapshot.append([info.shop_color, info.door_face, info.has_awning])
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces the rolls.
	var reproduced := snapshot.size() == _city.buildings.size()
	if reproduced:
		for i in snapshot.size():
			var info: Dictionary = _city.buildings[i]
			var same_color: bool = (snapshot[i][0] as Color).is_equal_approx(info.shop_color)
			var same_face: bool = snapshot[i][1] == int(info.door_face)
			var same_awning: bool = snapshot[i][2] == bool(info.has_awning)
			reproduced = reproduced and same_color and same_face and same_awning
	_check("city_shopfronts_deterministic", reproduced,
			"snapshot %d vs regenerated %d" % [snapshot.size(), _city.buildings.size()])


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


## The falling drop reads from the chase cam (T-086, adopting T-025): the ball
## mesh is at least a readable dot (SphereMesh radius >= 0.10), Mat_ball carries
## the soft warm self-glow in the parse-safe 4-arg Color form (a 3-arg Color in
## a .tscn fails resource parsing outright — load() returns null — so this
## scenario running at all, plus the reported emission alpha of 1.0, is that
## proof), and the albedo keeps >= 0.25 Euclidean RGB from both wash-out
## backdrops (sunlit grass, plaza), distances printed informationally. The
## collider stays pinned at its landed 0.07 — the visible ball overhangs it on
## purpose, and every hit-registration scenario above is untouched by that.
func _scenario_poop_ball_visible() -> void:
	var poop: Poop = POOP_SCENE.instantiate() as Poop
	var ball := poop.get_node("BallMesh") as MeshInstance3D
	var sphere := ball.mesh as SphereMesh
	var mat := sphere.material as StandardMaterial3D
	var albedo := _rgb(_mesh_albedo(poop, "BallMesh"))
	var vs_grass := albedo.distance_to(_rgb(City.COLOR_GRASS))
	var vs_plaza := albedo.distance_to(_rgb(City.COLOR_PLAZA))
	var collider := (poop.get_node("BallShape") as CollisionShape3D).shape as SphereShape3D
	var emission_ok := mat.emission_enabled \
			and absf(mat.emission.r - 0.85) < 0.005 and absf(mat.emission.g - 0.78) < 0.005 \
			and absf(mat.emission.b - 0.55) < 0.005 and absf(mat.emission.a - 1.0) < 0.005
	print("SIM INFO poop ball radius=%.2f emission=%s energy=%.2f collider radius=%.2f albedo vs grass=%.3f vs plaza=%.3f" % [
			sphere.radius, mat.emission, mat.emission_energy_multiplier,
			collider.radius, vs_grass, vs_plaza])
	_check("poop_ball_visible",
			sphere.radius >= 0.10 and emission_ok and vs_grass >= 0.25 and vs_plaza >= 0.25
					and absf(collider.radius - 0.07) < 0.005, ## float32-stored 0.07 sits a hair above the literal.
			"radius=%.2f emission_enabled=%s emission=%s grass=%.3f plaza=%.3f collider=%.2f" % [
					sphere.radius, mat.emission_enabled, mat.emission, vs_grass, vs_plaza,
					collider.radius])
	poop.free()


## The F readiness glyph (T-077), through the REAL main scene: airborne with a
## rested drop it shows lit at full alpha, a REAL poop tap dims it to a quarter
## immediately, it stays dim while the cooldown runs and freezes with a paused
## tree, it relights only after poop_cooldown of game time with no further
## press, it hides entirely while grounded, and restart_run() mid-cooldown
## relights it. Registered beside the other poop scenarios — this stretch has
## an unpaused tree and no live Main, and the scenario leaves it exactly that.
func _scenario_poop_ready_indicator_tracks_cooldown() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(3500.0, 0.0, 3500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var pigeon: Player = main_game.player
	var glyph: Label = main_game.poop_ready_label
	var spawn_local: Vector3 = main_game.city.to_local(main_game.city.spawn_point)
	var hover: Vector3 = spawn_local + Vector3(0.0, 5.0, 0.0) ## Above the clear spawn corridor.
	## Airborne fresh run: hold flight the elder_no_bread_airborne way — a
	## reset_flight per frame (which also zeroes the cooldown, keeping it
	## "ready") — then give the driver's tick to light the glyph.
	for _i in 8:
		pigeon.reset_flight(hover)
		await get_tree().physics_frame
	var lit_ok: bool = glyph.visible and not pigeon.is_grounded \
			and absf(glyph.modulate.a - 1.0) <= 0.01
	## Style: plain "F" carrying the T-019 outline treatment at font 16 —
	## equality against the tuned values, like the other HUD scenarios.
	var style_ok: bool = glyph.text == "F" \
			and glyph.get_theme_color("font_outline_color").is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and glyph.get_theme_constant("outline_size") == 4 \
			and glyph.get_theme_font_size("font_size") == 16
	## A REAL poop action: the drop fires, the glyph dims immediately.
	await _tap("poop")
	await _wait_frames(2)
	var dim_ok: bool = not pigeon.is_grounded and pigeon._poop_timer > 0.9 \
			and glyph.visible and absf(glyph.modulate.a - 0.25) <= 0.01
	## Hold the pigeon at the hover by pinning pose+velocity — reset_flight here
	## would wipe the very cooldown being tracked — and prove it stays dim
	## through the first 50 of the 60-frame cooldown (no early relight).
	var early_lit := false
	for _i in 50:
		pigeon.velocity = Vector3(0.0, -1.0, 0.0)
		pigeon.position = hover
		await get_tree().physics_frame
		early_lit = early_lit or absf(glyph.modulate.a - 1.0) <= 0.01
	## Pause mid-cooldown: the whole tree freezes, so the glyph's dim state must
	## hold past the point the cooldown would have expired (pause_freezes proves
	## the mechanism; this proves the glyph freezes with it).
	main_game.pause_menu.toggle()
	var paused: bool = get_tree().paused and main_game.pause_menu.is_open
	var timer_at_pause: float = pigeon._poop_timer
	var alpha_at_pause: float = glyph.modulate.a
	for _i in 80: ## 1.33 s paused — longer than the whole cooldown.
		await get_tree().physics_frame
	var frozen_ok: bool = paused and glyph.visible \
			and absf(glyph.modulate.a - alpha_at_pause) < 0.001 \
			and absf(pigeon._poop_timer - timer_at_pause) < 0.001
	main_game.pause_menu.toggle()
	await _wait_frames(2)
	var resumed_ok: bool = not get_tree().paused and not main_game.pause_menu.is_open
	## The cooldown finishes in game time → lit again, no further press.
	var relit := false
	for _i in 30:
		pigeon.velocity = Vector3(0.0, -1.0, 0.0)
		pigeon.position = hover
		await get_tree().physics_frame
		if absf(glyph.modulate.a - 1.0) <= 0.01:
			relit = true
			break
	## Land on the spawn plaza: hidden entirely — no dim ghost.
	pigeon.reset_flight(spawn_local + Vector3(0.0, 0.4, 0.0))
	var landed := false
	for _i in 300:
		await get_tree().physics_frame
		if pigeon.is_grounded:
			landed = true
			break
	await _wait_frames(3) ## The driver's next tick hides it.
	var hidden_ok: bool = landed and pigeon.is_grounded and not glyph.visible
	## Take off, drop for real, and restart_run() MID-COOLDOWN: reset_flight
	## zeroes the timer and returns to AIR, so the next tick relights it.
	await _tap("flap")
	var airborne_again := false
	for _i in 60:
		await get_tree().physics_frame
		if not pigeon.is_grounded:
			airborne_again = true
			break
	await _tap("poop")
	await _wait_frames(2)
	var cooling_again: bool = glyph.visible and absf(glyph.modulate.a - 0.25) <= 0.01 \
			and pigeon._poop_timer > 0.9
	main_game.restart_run()
	await _wait_frames(3)
	var restart_lit: bool = not get_tree().paused and glyph.visible \
			and absf(glyph.modulate.a - 1.0) <= 0.01 and not main_game.player.is_grounded
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("poop_ready_indicator_tracks_cooldown",
			lit_ok and style_ok and dim_ok and not early_lit and frozen_ok and resumed_ok
					and relit and hidden_ok and airborne_again and cooling_again and restart_lit,
			"lit=%s style=%s dim=%s early_lit=%s frozen=%s resumed=%s relit=%s hidden=%s air=%s cooling=%s restart_lit=%s" % [
					lit_ok, style_ok, dim_ok, early_lit, frozen_ok, resumed_ok,
					relit, hidden_ok, airborne_again, cooling_again, restart_lit])


## --- scenarios (T-020 park elders) ------------------------------------------


## The elder scenarios share one rig over the real generated city: an elder
## spawner under test and an empty bread service, so every living crumb below
## is a tossed one. The spawner's relays land in `_bread_shared`.
func _add_elder_rig() -> Array:
	_bread_shared.clear()
	var crumbs := BreadSpawner.new()
	crumbs.city = _city
	crumbs.target_count = 0 ## No seeded crumbs — only tossed ones exist.
	crumbs.respawn_interval = 9999.0
	add_child(crumbs)
	var spawner := ElderSpawner.new()
	spawner.city = _city
	spawner.player = _player
	spawner.bread_spawner = crumbs
	add_child(spawner)
	spawner.bread_shared.connect(func(elder: Elder, count: int) -> void:
		_bread_shared.append({"elder": elder, "crumbs": count}))
	return [spawner, crumbs]


func _spots_equal(a: Array[Transform3D], b: Array[Transform3D]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


## The elders' plaza placement is pure layout: `elder_spots` records one spot
## per plaza-ring bench (8), appended with zero RNG, and the spawner seats 4
## elders on every second bench (indices 0, 2, 4, 6 — 90° apart, on the seat
## line). Regenerating the same seed reproduces the fingerprint, the
## bench/lamp/bin counts AND the spot list byte-identically, every seed still
## gets its ring, and the spawner seats one elder per chosen spot on the real
## city.
func _scenario_elder_placement_no_rng() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var spots_a := _city.elder_spots.duplicate()
	var report_a: Dictionary = _city.last_report
	var shape_ok: bool = spots_a.size() == 8
	var angles: Array[float] = []
	for spot in spots_a:
		var origin: Vector3 = (spot as Transform3D).origin
		shape_ok = shape_ok and absf(Vector2(origin.x, origin.z).length() - 8.0) < 0.01 \
				and absf(origin.y - (_city.block_slab_height + 0.60)) < 0.001
		angles.append(atan2(origin.z, origin.x))
	var spread := true
	angles.sort()
	for i in angles.size():
		spread = spread and absf(wrapf(angles[(i + 1) % angles.size()] - angles[i],
				-PI, PI) - PI * 0.25) < 0.01
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces the spots.
	var spots_b := _city.elder_spots.duplicate()
	var typed_b: Array[Transform3D] = []
	for spot in spots_b:
		typed_b.append(spot)
	var typed_a: Array[Transform3D] = []
	for spot in spots_a:
		typed_a.append(spot)
	var deterministic: bool = _city.fingerprint == fp_first \
			and report_a.benches == _city.last_report.benches \
			and report_a.lamps == _city.last_report.lamps \
			and report_a.bins == _city.last_report.bins \
			and _spots_equal(typed_a, typed_b)
	_city.generate(424242)
	var foreign_ok := _city.elder_spots.size() == 8 and _city.fingerprint != fp_first
	_city.generate(default_seed)
	var rig := _add_elder_rig()
	var spawner: ElderSpawner = rig[0]
	await _wait_frames(4)
	var elders := spawner.living_elders()
	var seated := elders.size() == 4
	for i in elders.size():
		seated = seated and elders[i].global_position.distance_to(
				_city.to_global((city_spot(_city, i) as Transform3D).origin)) < 0.01
	_check("elder_placement_no_rng",
			shape_ok and spread and deterministic and foreign_ok and seated,
			"spots %d, on-ring=%s, spread=%s, deterministic=%s, foreign=%s, seated=%d/4" % [
					spots_a.size(), shape_ok, spread, deterministic, foreign_ok, elders.size()])
	spawner.free()
	(rig[1] as Node).free()


## The bench spot the i-th elder sits on: every second entry of `elder_spots`
## (the spawner's ring rule, mirrored for the assertion).
func city_spot(city: City, elder_index: int) -> Variant:
	return city.elder_spots[elder_index * 2]


## A GROUNDED pigeon parked in an elder's PresenceZone fills trust; a short
## walk-about decays it without wiping; back for the full hangout the elder
## tosses two ordinary T-005 crumbs (restore 30, hand-placed, respawn-
## accounted) onto the pavement in front of the bench and relays exactly once.
func _scenario_elder_shares_bread_after_hangout() -> void:
	var rig := _add_elder_rig()
	var spawner: ElderSpawner = rig[0]
	var crumbs: BreadSpawner = rig[1]
	await _wait_frames(4)
	var elders := spawner.living_elders()
	if elders.is_empty():
		_check("elder_shares_bread_after_hangout", false, "no elder spawned")
		spawner.free()
		(rig[1] as Node).free()
		return
	var elder: Elder = elders[0]
	## Park 2.6 m in front of the elder's facing — inside the PresenceZone,
	## clear of the 1.1 m crumb eat radius (the toss lands 1.2 m out ±0.4).
	var park := elder.global_position - elder.global_transform.basis.z * 2.6
	park.y = elder.global_position.y - Elder.SEAT_HEIGHT + 0.5
	await _set_up(true, park, Vector3.ZERO)
	await _await_grounded(90)
	var parked := _player.is_grounded and _player.position.distance_to(park) < 0.5
	await _wait_frames(130) ## ~2.2 s of company banks ~2 trust.
	var banked: float = elder._trust
	var away := park + Vector3(6.0, 0.0, 0.0) ## Outside the 3.0 m zone, still on the plaza.
	await _set_up(true, away, Vector3.ZERO)
	await _await_grounded(90)
	await _wait_frames(30) ## ~0.7 s alone decays it but must not wipe it.
	var decayed: float = elder._trust
	await _set_up(true, park, Vector3.ZERO)
	await _await_grounded(90)
	await _wait_frames(280) ## trust_needed (4 s) of company plus margin — the share fires mid-wait.
	var shared_once: bool = _bread_shared.size() == 1 and _bread_shared[0].elder == elder \
			and int(_bread_shared[0].crumbs) == elder.crumbs_per_share
	var live := 0
	var ordinary := true
	for crumb in crumbs.living_crumbs():
		var flat := Vector2(crumb.global_position.x - elder.global_position.x,
				crumb.global_position.z - elder.global_position.z)
		if flat.length() <= elder.toss_distance + elder.toss_spread + 0.05:
			live += 1
			ordinary = ordinary and crumb.restore == 30.0 and crumb.spot_index == -1
	_check("elder_shares_bread_after_hangout",
			parked and banked > 1.5 and decayed > 0.1 and decayed < banked - 0.5
					and shared_once and live >= 2 and ordinary,
			"parked=%s trust %.2f→%.2f decay, relays %d, live crumbs in reach %d, ordinary=%s" % [
					parked, banked, decayed, _bread_shared.size(), live, ordinary])
	spawner.free()
	(rig[1] as Node).free()


## A FLYING pigeon held inside the same PresenceZone for longer than
## trust_needed banks nothing: zero crumbs, zero relays, trust never leaves 0.
func _scenario_elder_no_bread_airborne() -> void:
	var rig := _add_elder_rig()
	var spawner: ElderSpawner = rig[0]
	var crumbs: BreadSpawner = rig[1]
	await _wait_frames(4)
	var elders := spawner.living_elders()
	if elders.is_empty():
		_check("elder_no_bread_airborne", false, "no elder spawned")
		spawner.free()
		(rig[1] as Node).free()
		return
	var elder: Elder = elders[0]
	var hold := elder.global_position - elder.global_transform.basis.z * 1.5
	hold.y = elder.global_position.y + 1.2 ## In the zone, above the pavement.
	for _i in 300: ## 5 s of held flight — longer than trust_needed.
		_player.reset_flight(hold)
		await get_tree().physics_frame
	var clean := _bread_shared.is_empty() and crumbs.living_crumbs().is_empty() \
			and elder._trust <= 0.0 and not _player.is_grounded
	_check("elder_no_bread_airborne", clean,
			"relays %d, crumbs %d, trust %.2f, held airborne=%s" % [
					_bread_shared.size(), crumbs.living_crumbs().size(),
					elder._trust, not _player.is_grounded])
	spawner.free()
	(rig[1] as Node).free()


## After a share the elder goes quiet: the pigeon hanging out CONTINUOUSLY
## through the whole share_cooldown earns nothing until it expires — then one
## more share, exactly.
func _scenario_elder_cooldown_blocks_second_share() -> void:
	var rig := _add_elder_rig()
	var spawner: ElderSpawner = rig[0]
	var crumbs: BreadSpawner = rig[1]
	await _wait_frames(4)
	var elders := spawner.living_elders()
	if elders.is_empty():
		_check("elder_cooldown_blocks_second_share", false, "no elder spawned")
		spawner.free()
		(rig[1] as Node).free()
		return
	var elder: Elder = elders[0]
	var park := elder.global_position - elder.global_transform.basis.z * 2.6
	park.y = elder.global_position.y - Elder.SEAT_HEIGHT + 0.5
	await _set_up(true, park, Vector3.ZERO)
	await _await_grounded(90)
	var first_at := -1
	for f in 600:
		await get_tree().physics_frame
		if _bread_shared.size() >= 1:
			first_at = f
			break
	var shared_first: bool = _bread_shared.size() == 1 and _bread_shared[0].elder == elder
	## Keep hanging straight through the cooldown window (stop just before it
	## expires): not one further relay.
	var quiet := true
	for _f in int(elder.share_cooldown * 60.0) - maxi(first_at, 0) - 30:
		await get_tree().physics_frame
		if _bread_shared.size() != 1:
			quiet = false
			break
	var second_at := -1
	for f in 600: ## Trust refills in trust_needed — the second share must come.
		await get_tree().physics_frame
		if _bread_shared.size() >= 2:
			second_at = f
			break
	_check("elder_cooldown_blocks_second_share",
			shared_first and quiet and second_at > 0 and _bread_shared.size() == 2
					and _bread_shared[1].elder == elder,
			"first relay at f%d, quiet through cooldown=%s, second at f%d, relays %d" % [
					first_at, quiet, second_at, _bread_shared.size()])
	spawner.free()
	(rig[1] as Node).free()


## --- scenarios (T-031 cafe tables) ------------------------------------------


## The cafe table transform the ticket's pure math claims for one awninged
## building — an independent re-derivation (the harness owns its copy of the
## layout numbers) so the scenario proves the spots, not just the city
## function that filled them.
func _expected_cafe_spot(city: City, info: Dictionary) -> Transform3D:
	var normal: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][
			int(info.door_face)]
	var lot: Vector2 = info.lot_offset
	var face_axis_x := absf(normal.x) > 0.5
	var along := Vector3(0.0, 0.0, signf(lot.y)) if face_axis_x \
			else Vector3(signf(lot.x), 0.0, 0.0)
	var pos: Vector3 = city.to_local(info.center) \
			+ normal * ((info.size as Vector2).x * 0.5 + 0.12 + 1.9) \
			+ along * 2.2
	pos.y = city.block_slab_height
	return Transform3D(Basis(Vector3.UP, atan2(-normal.x, -normal.z)), pos)


## Cafe tables (T-031): the city records one pure-layout spot per awninged
## building (the pinned 104 at the M1 seed; non-awninged buildings get none),
## every spot recomputable from its building's `door_face`/`size`/`lot_offset`,
## same-seed regeneration reproducing the spot list byte-identically, and a
## spawner rig seating tables-with-sitters exactly on the spots
## (`elder_placement_no_rng` template). Placement holds the street clearances:
## on the sidewalk band with the table center ≥ 0.5 m inside the tourist
## loop's 10.9 m curb line (square metrics — the loop legs are lines), ≥ 1.0 m
## off the block's bread spots (bench seats; corner bread-ring spots lie
## outside every block's radius), ≥ 1.2 m edge-to-edge off the door line.
## Sitters are layer-3 `npc` static bodies (mask 0), 1-2 per table by the
## even/odd spot rule (104 tables → 156), shirts straight from the tourist
## palette by spot index — and a grounded pigeon can waddle up and perch
## beside a table, which stops the waddle dead (solid layer-1 furniture).
func _scenario_city_cafe_tables() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed)
	var spots: Array[Transform3D] = _city.cafe_spots.duplicate()
	var awnings := 0
	for info in _city.buildings:
		if info.has_awning:
			awnings += 1
	var count_ok: bool = spots.size() == awnings and awnings == 104
	var recompute_ok := spots.size() > 0
	var band_ok := spots.size() > 0
	var bread_ok := spots.size() > 0
	var door_ok := spots.size() > 0
	var spot_i := 0
	for info in _city.buildings:
		if not info.has_awning:
			continue
		var spot: Transform3D = spots[spot_i]
		var expected: Transform3D = _expected_cafe_spot(_city, info)
		recompute_ok = recompute_ok \
				and spot.origin.distance_to(expected.origin) < 0.01 \
				and spot.basis.get_euler().distance_to(expected.basis.get_euler()) < 0.01
		## Street-face geometry, re-derived from the building record.
		var lot: Vector2 = info.lot_offset
		var block_center: Vector3 = _city.to_local(info.center) \
				- Vector3(lot.x, 0.0, lot.y)
		## Square metrics — the slab, the sidewalk band and the tourist loop are
		## all squares: the loop legs run at block_size * 0.5 - 0.1 = 10.9 m.
		var out_line: float = maxf(absf(spot.origin.x - block_center.x),
				absf(spot.origin.z - block_center.z))
		band_ok = band_ok and out_line <= _city.block_size * 0.5 - 0.1 - 0.5
		## The block's own bread spots stay ≥ 1.0 m off — block membership by the
		## block's radius (spots beyond it, notably the corner bread-ring spots at
		## radial ~11.7 m, belong to no block). Bench-seat clearance is structural:
		## the ±4 m bench jitter can never reach the corner-ward table line.
		var nearest: Vector3 = _city.block_centers[0]
		var best := INF
		for center in _city.block_centers:
			var d: float = Vector2(spot.origin.x - center.x,
					spot.origin.z - center.z).length_squared()
			if d < best:
				best = d
				nearest = center
		for bread: Vector3 in _city.bread_spots:
			if Vector2(bread.x - nearest.x, bread.z - nearest.z).length() \
					<= _city.block_size * 0.5:
				bread_ok = bread_ok \
						and Vector2(spot.origin.x - bread.x,
								spot.origin.z - bread.z).length() >= 1.0
		## Door line: the centered 0.95 m door vs the table's along-face edge.
		var normal: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][
				int(info.door_face)]
		var face_axis_x := absf(normal.x) > 0.5
		var along_dir := Vector3(0.0, 0.0, signf(lot.y)) if face_axis_x \
				else Vector3(signf(lot.x), 0.0, 0.0)
		var face_center: Vector3 = _city.to_local(info.center) \
				+ normal * ((info.size as Vector2).x * 0.5 + 0.12)
		var along_dist: float = absf((spot.origin - face_center).dot(along_dir))
		door_ok = door_ok and along_dist - 0.475 - 0.45 >= 1.2
		spot_i += 1
	_city.generate(default_seed)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _spots_equal(spots, _city.cafe_spots)
	## Spawner rig over the real generated city (the elder-rig template).
	var spawner := CafeSpawner.new()
	spawner.city = _city
	add_child(spawner)
	await _wait_frames(4)
	var tables := spawner.living_tables()
	var seated: bool = tables.size() == spots.size()
	var count_ok_rig := seated
	var shirts_ok := seated
	var layers_ok := seated
	var total_sitters := 0
	for i in tables.size():
		var table: CafeTable = tables[i]
		seated = seated and table.global_position.distance_to(
				_city.to_global((spots[i] as Transform3D).origin)) < 0.01
		count_ok_rig = count_ok_rig and table.sitters.size() == (2 if i % 2 == 0 else 1)
		for j in table.sitters.size():
			var sitter: CafeSitter = table.sitters[j]
			total_sitters += 1
			layers_ok = layers_ok and sitter.collision_layer == 4 \
					and sitter.collision_mask == 0
			var mat := sitter._torso.material_override as StandardMaterial3D
			shirts_ok = shirts_ok and mat != null and mat.albedo_color.is_equal_approx(
					Tourist.SHIRT_PALETTE[(i + j) % Tourist.SHIRT_PALETTE.size()])
	## A grounded pigeon waddles up and perches beside table 0 …
	var table0: CafeTable = tables[0]
	var seat: Vector3 = _city.to_global((spots[0] as Transform3D).origin)
	var table_basis: Basis = (spots[0] as Transform3D).basis
	var beside := seat + table_basis.x * 1.5 + Vector3(0.0, 0.5, 0.0)
	await _set_up(true, beside, Vector3.ZERO)
	await _await_grounded(120)
	var flat := Vector2(_player.position.x - seat.x, _player.position.z - seat.z)
	var perch_ok: bool = _player.is_grounded and flat.length() > 0.55 and flat.length() < 2.0
	## … and the table itself is solid: a waddle aimed straight into it stops at
	## its edge (parked street-side, past the tabletop, before the sitters' line).
	var street_side := seat - table_basis.z * 1.0 + Vector3(0.0, 0.5, 0.0)
	var to_table := seat - street_side
	to_table.y = 0.0
	await _set_up(true, street_side, Vector3.ZERO,
			rad_to_deg(atan2(-to_table.x, -to_table.z)))
	await _await_grounded(120)
	await _hold("pitch_up", 25)
	flat = Vector2(_player.position.x - seat.x, _player.position.z - seat.z)
	perch_ok = perch_ok and _player.is_grounded \
			and flat.length() > 0.5 and flat.length() < 0.8
	_check("city_cafe_tables_present",
			count_ok and recompute_ok and band_ok and bread_ok and door_ok
					and deterministic and seated and count_ok_rig and shirts_ok
					and layers_ok and perch_ok,
			("spots %d vs awnings %d, recompute=%s band=%s bread=%s door=%s det=%s, "
				+ "seated=%d tables, sitters=%d (rule=%s shirts=%s layers=%s), perch=%s") % [
						spots.size(), awnings, recompute_ok, band_ok, bread_ok, door_ok,
						deterministic, tables.size(), total_sitters, count_ok_rig, shirts_ok,
						layers_ok, perch_ok])
	spawner.free()


## --- scenarios (T-032 rooftop clutter) --------------------------------------


## The low roof near the plaza, by the `city_roof_landable` selection: the
## first generated building under 12 m tall, 20–90 m out from the city origin.
func _low_roof_building() -> Dictionary:
	for info in _city.buildings:
		var c: Vector3 = info.center
		var dist := Vector2(c.x - _city.position.x, c.z - _city.position.z).length()
		if info.top <= 12.0 and dist > 20.0 and dist < 90.0:
			return info
	return {}


## The `roof_props` entries of one building: centers inside its footprint XZ,
## in array order. Prop insets keep every center ≤ 2.81 m from the footprint
## center, so a prop can never sit inside a neighbor (lot centers are 8.5 m
## apart, footprints 7.1 m wide).
func _props_of(building: Dictionary) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var half: float = (building.size as Vector2).x * 0.5
	var c: Vector3 = building.center
	for prop in _city.roof_props:
		var p: Vector3 = prop.center
		if absf(p.x - c.x) <= half and absf(p.z - c.z) <= half:
			props.append(prop)
	return props


## The roof-corner bread spots: `bread_spots` entries at crumb height on a roof
## (y > 1.0 — every ground spot sits at or below the 0.72 m bench seats).
func _roof_bread_spots() -> Array[Vector3]:
	var roof_spots: Array[Vector3] = []
	for spot in _city.bread_spots:
		if spot.y > 1.0:
			roof_spots.append(spot)
	return roof_spots


## Byte-identical `roof_props` comparison — exact equality on every member
## (the layout math is deterministic, so a real rebuild must produce
## bit-identical values, not approximately equal ones).
func _props_reproduced(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var pa: Dictionary = a[i]
		var pb: Dictionary = b[i]
		if pa.center != pb.center or pa.size != pb.size \
				or pa.top != pb.top or pa.kind != pb.kind:
			return false
	return true


## Exact comparison for the roof-spot snapshots (the `_spots_equal` pattern).
func _vec_spots_equal(a: Array[Vector3], b: Array[Vector3]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


## Rooftop clutter (T-032): every building carries 1-3 roof props — fully on
## its roof (≥ 1.0 m from every edge), centers ≥ 2.5 m from the footprint
## center (the `city_roof_landable` drop point at the exact center stays
## clear) with one layer-1 `world` collider each — and exactly one crumb spot
## in the never-propped (+,+) quadrant at roof-top + 0.06, so city-wide
## `bread_spots` grows by exactly the building count (8 ring spots × 49 blocks
## + one per bench seat + one per building). A crumb instantiated at a low
## roof's spot is an ordinary crumb: a dropped pigeon waddling in eats it
## through the existing eaten path (+30 via Hunger, no BreadSpawner involved).
## A drop onto the low roof's first prop settles grounded on its top
## (bench-landing template). Same-seed regeneration reproduces `roof_props`
## and the roof spots byte-identically and the fingerprint holds.
func _scenario_city_roofs_inhabited() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var props_snapshot := _city.roof_props.duplicate()
	var spots_snapshot := _roof_bread_spots()
	## --- layout audit: prop and spot geometry across every building ----------
	var props_ok: bool = _city.roof_props.size() >= _city.buildings.size()
	var spots_ok: bool = spots_snapshot.size() == _city.buildings.size() \
			and spots_snapshot.size() >= 20
	## City-wide pool: the T-005 ground spots plus exactly the new roof spots.
	var total_ok: bool = _city.bread_spots.size() \
			== _city.blocks_per_side * _city.blocks_per_side * 8 \
			+ int(_city.last_report.benches) + _city.buildings.size()
	var one_per_building := true
	for info in _city.buildings:
		var props := _props_of(info)
		var half: float = (info.size as Vector2).x * 0.5
		props_ok = props_ok and props.size() >= 1 and props.size() <= 3
		for prop in props:
			var c: Vector3 = prop.center
			var s: Vector3 = prop.size
			var flat := Vector2(c.x - info.center.x, c.z - info.center.z)
			props_ok = props_ok \
					and flat.length() >= 2.5 \
					and half - absf(flat.x) - s.x * 0.5 >= 1.0 \
					and half - absf(flat.y) - s.z * 0.5 >= 1.0 \
					and absf((prop.top as float) - (info.top as float) - s.y) < 0.001
		## Exactly one roof spot per building, in the (+,+) quadrant mirrored by
		## lot_offset at ±0.28·footprint per axis — never a prop quadrant.
		var found := 0
		for spot in spots_snapshot:
			var g := _city.to_global(spot)
			var flat_s := Vector2(g.x - info.center.x, g.z - info.center.z)
			if absf(g.y - (info.top as float) - 0.06) > 0.001 \
					or absf(flat_s.x) > half or absf(flat_s.y) > half:
				continue
			found += 1
			var lot: Vector2 = info.lot_offset
			one_per_building = one_per_building \
					and signf(flat_s.x) == signf(lot.x) \
					and signf(flat_s.y) == signf(lot.y) \
					and absf(absf(flat_s.x) - (info.size as Vector2).x * 0.28) < 0.001 \
					and absf(absf(flat_s.y) - (info.size as Vector2).x * 0.28) < 0.001
		one_per_building = one_per_building and found == 1
	## --- colliders: one layer-1 body per prop, high above the street props ---
	var high_bodies := 0
	var layers_ok := true
	for body in (_city.get_node("Static/Props") as Node3D).get_children():
		var static_body := body as StaticBody3D
		if static_body != null and static_body.position.y > 5.0:
			high_bodies += 1
			layers_ok = layers_ok and static_body.collision_layer == 1
	var colliders_ok := high_bodies == _city.roof_props.size() and layers_ok
	## --- determinism: a real rebuild reproduces props and roof spots ---------
	_city.generate(default_seed, true)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _props_reproduced(props_snapshot, _city.roof_props) \
			and _vec_spots_equal(spots_snapshot, _roof_bread_spots())
	## --- the physical legs, on the low roof near the plaza --------------------
	var roof := _low_roof_building()
	var physical_ok := not roof.is_empty()
	var eat_ok := false
	var prop_ok := false
	if physical_ok:
		## Leg 1 — the roof crumb is an ordinary crumb (the T-005 template):
		## instantiated at the spot, eaten by a dropped-then-waddling pigeon.
		var hunger := Hunger.new()
		hunger.player = _player
		add_child(hunger)
		var half: float = (roof.size as Vector2).x * 0.5
		var center_local := _city.to_local(roof.center)
		var spot_local := Vector3.INF
		for spot in _city.bread_spots:
			if spot.y > 1.0 and absf(spot.x - center_local.x) <= half \
					and absf(spot.z - center_local.z) <= half:
				spot_local = spot
				break
		physical_ok = spot_local.is_finite()
		if physical_ok:
			var spot_global := _city.to_global(spot_local)
			var crumb: BreadCrumb = CRUMB_SCENE.instantiate()
			crumb.position = spot_global
			add_child(crumb)
			crumb.eaten.connect(hunger.eat)
			## Drop 1.8 m from the crumb along z, toward the footprint center
			## (the spot sits 0.28·footprint ≈ 2.0 m out per axis, so the drop
			## stays on the roof, clear of the propped quadrants), facing it.
			var dir_z := signf(spot_global.z - (roof.center as Vector3).z)
			var walk_dir := Vector3(0.0, 0.0, dir_z)
			await _set_up(true, spot_global + Vector3(0.0, 0.4, -dir_z * 1.8),
					Vector3.ZERO, rad_to_deg(atan2(-walk_dir.x, -walk_dir.z)))
			await _await_grounded(90)
			hunger.value = 40.0 ## Mid-bar so the +30 restore is measurable.
			var hunger0 := hunger.value
			Input.action_press("pitch_up") ## Waddle in.
			for _i in 120:
				await get_tree().physics_frame
				eat_ok = not is_instance_valid(crumb) and hunger.value > hunger0 + 10.0
				if eat_ok:
					break
			Input.action_release("pitch_up")
		hunger.free()
		## Leg 2 — a drop onto the low roof's first prop settles grounded on
		## its top (the bench-landing template): props are landable cover.
		var props := _props_of(roof)
		if not props.is_empty():
			var prop: Dictionary = props[0]
			await _set_up(true, (prop.center as Vector3) + Vector3(0.0, 0.8, 0.0),
					Vector3.ZERO)
			await _await_grounded(150)
			prop_ok = _player.is_grounded \
					and absf(_player.position.y - ((prop.top as float) + 0.3)) < 0.2
	_check("city_roofs_inhabited",
			props_ok and spots_ok and total_ok and one_per_building and colliders_ok
					and deterministic and physical_ok and eat_ok and prop_ok,
			("props_ok=%s spots=%d/%d total_ok=%s one_per_building=%s colliders=%s (%d high) "
			+ "det=%s physical=%s eat=%s prop=%s") % [
					props_ok, spots_snapshot.size(), _city.buildings.size(),
					total_ok, one_per_building, colliders_ok, high_bodies,
					deterministic, physical_ok, eat_ok, prop_ok])
	## Informational: the M1-seed surface counts (146 buildings → 259 props,
	## 533 → 679 bread spots) — the ticket's tuned numbers, re-printed on every
	## re-verification.
	print("SIM DATA roofs_inhabited: buildings=%d roof_props=%d roof_spots=%d bread_spots=%d fingerprint=%d" % [
			_city.buildings.size(), _city.roof_props.size(), spots_snapshot.size(),
			_city.bread_spots.size(), fp_first])


## Zebra crosswalks (T-069): the `Visuals/Crosswalk` MultiMesh carries exactly
## 1,120 stripes with default exports (224 bands x 5 — every unblocked
## intersection approach, the 32 rim outward approaches skipped), every stripe
## is an axis-aligned 0.4 x road_width x 0.01 box at the right dash-family
## height, every stripe center sits >= 5.0 m from every intersection node in XZ
## (the 3.5 m corner-cut swing area stays clear) and inside its approach road's
## asphalt rect, the stripe multiset matches an independent recomputation
## (5 stripes per unblocked approach at 5.2 / 5.7 / 6.2 / 6.7 / 7.2 m on the
## approach axis, on the road centerline — the `_expected_cafe_spot` pattern),
## a forced same-seed rebuild reproduces all transforms byte-identically
## (`_spots_equal`, the `elder_placement_no_rng` pattern), the paint is
## visual-only (no StaticBody3D anywhere under `Visuals`), and the fingerprint
## stays byte-identical (zero RNG, zero `_fp` entries).
##
## Transform source: `MultiMesh.get_instance_transform` reads back identity for
## EVERY key in headless runs (the dummy RenderingServer never uploads the
## instance buffer — verified for the pre-existing `Dash` key too), so the
## per-stripe walk uses the queue that feeds this exact MultiMesh
## (`_spawn_visuals` copies `_visuals[key].xfs` into the node verbatim, same
## build, same order); `instance_count` IS readable off the node and must
## agree with the queue at both snapshots.
func _scenario_city_crosswalks() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var mm := (_city.get_node("Visuals/Crosswalk") as MultiMeshInstance3D).multimesh
	var queue: Array = _city._visuals["crosswalk"].xfs
	var count_ok: bool = mm.instance_count == 1120 and queue.size() == 1120
	var xfs: Array[Transform3D] = []
	for xf: Transform3D in queue:
		xfs.append(xf)
	## The layout math, re-derived here from the default exports (independent of
	## the builder's own constants): 8 road centers per axis -> 64 nodes.
	var half: float = _city.city_span * 0.5
	var road_w: float = _city.road_width
	var slab_y: float = _city.road_slab_height
	var centers: Array[float] = []
	for j in _city.blocks_per_side + 1:
		centers.append(-half + road_w * 0.5 + j * _city.block_pitch)
	var nodes: Array[Vector2] = []
	for cx: float in centers:
		for cz: float in centers:
			nodes.append(Vector2(cx, cz))
	## Expected stripe centers: per node, per approach whose band stays on the
	## asphalt (outer band edge node + side * 7.4 m inside ± half), five stripes
	## at 5.2–7.2 m out along the approach axis.
	var expected: Array[Vector3] = []
	for cx: float in centers:
		for cz: float in centers:
			for axis: int in 2: ## 0 = ±x approaches (horizontal road), 1 = ±z (vertical road).
				for side: float in [1.0, -1.0]:
					var node_c: float = cx if axis == 0 else cz
					if absf(node_c + side * 7.4) > half:
						continue ## The band would leave the asphalt.
					for k in 5:
						var out: float = side * (6.2 + (float(k) - 2.0) * 0.5)
						expected.append(Vector3(
								cx + (out if axis == 0 else 0.0),
								slab_y if axis == 0 else slab_y + 0.005,
								cz + (0.0 if axis == 0 else out)))
	count_ok = count_ok and expected.size() == 1120
	## Per-stripe geometry / y-family / clearance / asphalt-rect criteria, plus a
	## multiset match against the expected centers (each expected stripe exactly
	## once proves the 5-per-unblocked-approach placement).
	var matched: Array[bool] = []
	matched.resize(expected.size())
	matched.fill(false)
	var geometry_ok := true
	var y_ok := true
	var clear_ok := true
	var asphalt_ok := true
	for xf in xfs:
		var o: Vector3 = xf.origin
		var sc: Vector3 = xf.basis.get_scale()
		var along_x := absf(sc.x - 0.4) < 0.001 and absf(sc.z - road_w) < 0.001
		var along_z := absf(sc.z - 0.4) < 0.001 and absf(sc.x - road_w) < 0.001
		geometry_ok = geometry_ok and (along_x or along_z) and absf(sc.y - 0.01) < 0.001
		y_ok = y_ok and absf(o.y - (slab_y if along_x else slab_y + 0.005)) < 0.001
		var nearest := INF
		for node_pos in nodes:
			nearest = minf(nearest, Vector2(o.x - node_pos.x, o.z - node_pos.y).length())
		clear_ok = clear_ok and nearest >= 5.0
		var on_centerline := false
		for c: float in centers:
			on_centerline = on_centerline or absf((o.z if along_x else o.x) - c) < 0.001
		asphalt_ok = asphalt_ok and on_centerline \
				and absf((o.x if along_x else o.z)) <= half + 0.001
		for e in expected.size():
			if not matched[e] and (expected[e] - o).length_squared() < 1e-8:
				matched[e] = true
				break
	var placement_ok: bool = count_ok
	for m in matched:
		placement_ok = placement_ok and m
	## A forced same-seed rebuild reproduces all 1,120 transforms byte-identically.
	var xfs_a := xfs.duplicate()
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces them.
	var mm_b := (_city.get_node("Visuals/Crosswalk") as MultiMeshInstance3D).multimesh
	var queue_b: Array = _city._visuals["crosswalk"].xfs
	var xfs_b: Array[Transform3D] = []
	for xf: Transform3D in queue_b:
		xfs_b.append(xf)
	var deterministic: bool = mm_b.instance_count == 1120 and queue_b.size() == 1120 \
			and _city.fingerprint == fp_first and _spots_equal(xfs_a, xfs_b)
	## Visual-only (T-017): no StaticBody3D anywhere under the city's Visuals root.
	var visuals := _city.get_node("Visuals") as Node3D
	var colliders := visuals.find_children("*", "StaticBody3D", true, false)
	var visual_only := colliders.is_empty()
	_check("city_crosswalks_present",
			count_ok and geometry_ok and y_ok and clear_ok and asphalt_ok
					and placement_ok and deterministic and visual_only,
			"count=%d/%d geometry=%s y=%s clear=%s asphalt=%s placement=%s det=%s colliders=%d" % [
					xfs.size(), expected.size(), geometry_ok, y_ok, clear_ok, asphalt_ok,
					placement_ok, deterministic, colliders.size()])
	## Informational: the M1-seed paint counts — the ticket's tuned numbers,
	## re-printed on every re-verification.
	print("SIM DATA city_crosswalks: stripes=%d bands=%d fingerprint=%d" % [
			xfs.size(), xfs.size() / 5, fp_first])


## City-edge rim (T-088 commit 1): the rim is pure layout — audited like the
## crosswalks. Counts (4 hedges, 2·4·(blocks_per_side+1) trees), hedge
## placement on the boundary line (|x| or |z| = city_span·0.5 + 0.5, oriented
## (city_span, 1.2, 0.8) size), tree placement against an independent
## recomputation from the default exports (two per street exit at
## road_width·0.5 + 1.5 m along the side axis, on the apron at y 0), trunk and
## crown geometry off the actual MultiMesh queues (trunk center 1.1 m up,
## crown 3.3 m up, every crown over a tree spot), the rim green ≥ 0.15
## Euclidean RGB from COLOR_GRASS (distances printed informationally), zero
## CollisionObject3D under the Visuals root, a forced same-seed rebuild
## reproducing both spot lists byte-identically, and the layout fingerprint
## still equal to the cross-version pins recorded by T-047 (seed 20260928 →
## 2492360539, seed 424242 → 2662825400 — re-derived on the untouched tree
## 2026-10-01 with a headless `City.generate` probe before this scenario
## landed; zero RNG draws, zero `_fp` entries).
##
## Transform source: the public `rim_hedge_spots`/`rim_tree_spots` arrays for
## the placement legs; the trunk/crown legs walk the queues that feed the
## RimTrunk/RimCrown MultiMeshes (`MultiMesh.get_instance_transform` reads
## back identity headless — the `city_crosswalks_present` note).
## The albedo of the shared mesh behind a MultiMeshInstance3D — how the rim's
## greens are authored (`_mesh_albedo` is for MeshInstance3D; a MultiMesh
## instance is NOT one, so the cast there would yield Nil).
func _mm_mesh_albedo(root: Node, node_path: String) -> Color:
	var mm: MultiMesh = (root.get_node(node_path) as MultiMeshInstance3D).multimesh
	return (mm.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color


func _scenario_city_apron_rim() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var hedges: Array[Transform3D] = []
	for xf: Transform3D in _city.rim_hedge_spots:
		hedges.append(xf)
	var trees: Array[Transform3D] = []
	for xf: Transform3D in _city.rim_tree_spots:
		trees.append(xf)
	## --- counts --------------------------------------------------------------
	var expected_trees := 2 * 4 * (_city.blocks_per_side + 1)
	var count_ok: bool = hedges.size() == 4 and trees.size() == expected_trees
	## --- hedge placement: boundary line, band height, oriented size ----------
	var line := _city.city_span * 0.5 + 0.5
	var hedge_place_ok: bool = hedges.size() == 4
	for xf: Transform3D in hedges:
		var o: Vector3 = xf.origin
		var sc: Vector3 = xf.basis.get_scale()
		hedge_place_ok = hedge_place_ok \
				and (absf(absf(o.x) - line) < 0.01 or absf(absf(o.z) - line) < 0.01) \
				and absf(o.y - 0.6) < 0.01 and absf(sc.y - 1.2) < 0.01 \
				and ((absf(sc.x - _city.city_span) < 0.01 and absf(sc.z - 0.8) < 0.01) \
						or (absf(sc.z - _city.city_span) < 0.01 and absf(sc.x - 0.8) < 0.01))
	## --- tree placement vs an independent recomputation -----------------------
	var edge := _city.city_span * 0.5
	var centers: Array[float] = []
	for i in _city.blocks_per_side + 1:
		centers.append(-edge + _city.road_width * 0.5 + i * _city.block_pitch)
	var expected: Array[Vector3] = []
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var along := Vector3(-normal.z, 0.0, normal.x)
		for c: float in centers:
			for s: float in [1.0, -1.0]:
				expected.append(normal * line
						+ along * (c + s * (_city.road_width * 0.5 + 1.5)))
	var tree_place_ok: bool = expected.size() == trees.size()
	var matched: Array[bool] = []
	matched.resize(expected.size())
	matched.fill(false)
	for spot: Transform3D in trees:
		var o: Vector3 = spot.origin
		var hit := false
		for e in expected.size():
			if not matched[e] and (expected[e] - o).length_squared() < 1e-6:
				matched[e] = true
				hit = true
				break
		tree_place_ok = tree_place_ok and hit and absf(o.y) < 0.001 ## On the apron (y 0).
	## --- trunks and crowns, off the actual MultiMesh queues -------------------
	var trunk_xfs: Array[Transform3D] = []
	var crown_xfs: Array[Transform3D] = []
	if _city._visuals.has("rim_trunk"):
		for xf: Transform3D in _city._visuals["rim_trunk"].xfs:
			trunk_xfs.append(xf)
	if _city._visuals.has("rim_crown"):
		for xf: Transform3D in _city._visuals["rim_crown"].xfs:
			crown_xfs.append(xf)
	var trees_3d_ok: bool = trunk_xfs.size() == expected_trees \
			and crown_xfs.size() == expected_trees
	var crown_matched: Array[bool] = []
	crown_matched.resize(trees.size())
	crown_matched.fill(false)
	for xf: Transform3D in trunk_xfs:
		trees_3d_ok = trees_3d_ok and absf(xf.origin.y - 1.1) < 0.001
	for cf: Transform3D in crown_xfs:
		trees_3d_ok = trees_3d_ok and absf(cf.origin.y - 3.3) < 0.001
		for t in trees.size():
			var spot_o: Vector3 = (trees[t] as Transform3D).origin
			var flat := Vector2(cf.origin.x - spot_o.x, cf.origin.z - spot_o.z)
			if not crown_matched[t] and flat.length_squared() < 1e-6:
				crown_matched[t] = true
				break
	for m in crown_matched:
		trees_3d_ok = trees_3d_ok and m
	## --- the rim reads against its own apron: green vs COLOR_GRASS ------------
	var hedge_green := _mm_mesh_albedo(_city, "Visuals/RimHedge")
	var crown_green := _mm_mesh_albedo(_city, "Visuals/RimCrown")
	var grass_v := _rgb(_city.COLOR_GRASS)
	var hedge_dist := _rgb(hedge_green).distance_to(grass_v)
	var crown_dist := _rgb(crown_green).distance_to(grass_v)
	var green_ok := hedge_dist >= 0.15 and crown_dist >= 0.15
	## --- visual-only: zero colliders anywhere under the Visuals root ----------
	var visuals := _city.get_node("Visuals") as Node3D
	var colliders := visuals.find_children("*", "CollisionObject3D", true, false)
	var visual_only := colliders.is_empty()
	## --- determinism: a real rebuild reproduces both spot lists ---------------
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces them.
	var deterministic: bool = _city.fingerprint == fp_first \
			and _spots_equal(hedges, _city.rim_hedge_spots) \
			and _spots_equal(trees, _city.rim_tree_spots) \
			and (_city._visuals["rim_trunk"].xfs as Array).size() == expected_trees \
			and (_city._visuals["rim_crown"].xfs as Array).size() == expected_trees
	## --- cross-version pins: the fingerprint never moved ----------------------
	_city.generate(424242)
	var pin_foreign: bool = _city.fingerprint == 2662825400
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	var pin_default: bool = _city.fingerprint == 2492360539
	var rim_detail := "hedges=%d trees=%d/%d hedge_place=%s tree_place=%s trees_3d=%s green=%s (%.3f/%.3f) colliders=%d det=%s pins_foreign=%s pins_default=%s" % [
			hedges.size(), trees.size(), expected_trees, hedge_place_ok,
			tree_place_ok, trees_3d_ok, green_ok, hedge_dist, crown_dist,
			colliders.size(), deterministic, pin_foreign, pin_default]
	_check("city_apron_rim_present",
			count_ok and hedge_place_ok and tree_place_ok and trees_3d_ok and green_ok
					and visual_only and deterministic and pin_foreign and pin_default,
			rim_detail)
	## Informational: the rim's tuned numbers — the ticket's counts and green
	## distances, re-printed on every re-verification.
	var rim_data := "SIM DATA city_apron_rim: hedges=4 trees=%d hedge_green_dist=%.3f crown_green_dist=%.3f fingerprint=%d" % [
			trees.size(), hedge_dist, crown_dist, fp_first]
	print(rim_data)


## Distant skyline (T-088 commit 2): layout asserts on the standing City — no
## flight, the `_scenario_city_district_palettes` access pattern, audited like
## the crosswalks. `Skyline`/`SkylineTall` MultiMesh nodes exist under
## `Visuals`; total instances in [40, 80] with tall landmarks in [2, 8]; every
## origin's XZ radius in the band recomputed from the default exports
## (192-347 m at defaults — beyond the blocks, strictly inside the apron box
## including the tower's own ≤ 9 m half-width) with box origins at height/2
## (the apron top is y 0); every scale.y in [15, 60] and XZ extents 6-18 m;
## zero CollisionObject3D anywhere under the Visuals root; a forced same-seed
## rebuild reproduces both instance sets byte-identically; and the fingerprint
## still equals the cross-version pins (see `_scenario_city_apron_rim`).
##
## Transform source: the queues that feed the two MultiMeshes
## (`MultiMesh.get_instance_transform` reads back identity headless — the
## `city_crosswalks_present` note).
func _scenario_city_horizon_skyline() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var nodes_ok: bool = _city.get_node_or_null("Visuals/Skyline") is MultiMeshInstance3D \
			and _city.get_node_or_null("Visuals/SkylineTall") is MultiMeshInstance3D
	var skyline_xfs: Array[Transform3D] = []
	var tall_xfs: Array[Transform3D] = []
	if _city._visuals.has("skyline"):
		for xf: Transform3D in _city._visuals["skyline"].xfs:
			skyline_xfs.append(xf)
	if _city._visuals.has("skyline_tall"):
		for xf: Transform3D in _city._visuals["skyline_tall"].xfs:
			tall_xfs.append(xf)
	var total := skyline_xfs.size() + tall_xfs.size()
	var count_ok: bool = nodes_ok and total >= 40 and total <= 80 \
			and tall_xfs.size() >= 2 and tall_xfs.size() <= 8
	## --- placement and size legs, off the actual instance transforms ---------
	var inner := _city.city_span * 0.5 + _city.ground_extra * 0.3
	var outer := _city.city_span * 0.5 + _city.ground_extra - 20.0
	var apron_half := _city.city_span * 0.5 + _city.ground_extra
	var place_ok := count_ok
	var size_ok := true
	for source: Array in [skyline_xfs, tall_xfs]:
		for xf: Transform3D in source:
			var o: Vector3 = xf.origin
			var sc: Vector3 = xf.basis.get_scale()
			var radius := Vector2(o.x, o.z).length()
			place_ok = place_ok and radius >= inner - 0.001 and radius <= outer + 0.001 \
					and absf(o.x) + 9.0 <= apron_half and absf(o.z) + 9.0 <= apron_half
			size_ok = size_ok and sc.y >= 15.0 - 0.001 and sc.y <= 60.0 + 0.001 \
					and sc.x >= 6.0 - 0.001 and sc.x <= 18.0 + 0.001 \
					and sc.z >= 6.0 - 0.001 and sc.z <= 18.0 + 0.001 \
					and absf(o.y - sc.y * 0.5) < 0.001
	## --- visual-only: zero colliders anywhere under the Visuals root ----------
	var visuals := _city.get_node("Visuals") as Node3D
	var collider_count := 0
	for node in visuals.find_children("*", "", true, false):
		if node is CollisionObject3D:
			collider_count += 1
	var visual_only := collider_count == 0
	## --- determinism: a real rebuild reproduces both instance sets ------------
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces them.
	var skyline_b: Array[Transform3D] = []
	var tall_b: Array[Transform3D] = []
	if _city._visuals.has("skyline"):
		for xf: Transform3D in _city._visuals["skyline"].xfs:
			skyline_b.append(xf)
	if _city._visuals.has("skyline_tall"):
		for xf: Transform3D in _city._visuals["skyline_tall"].xfs:
			tall_b.append(xf)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _spots_equal(skyline_xfs, skyline_b) and _spots_equal(tall_xfs, tall_b)
	## --- cross-version pins and the foreign-seed contract ---------------------
	_city.generate(424242)
	var pin_foreign: bool = _city.fingerprint == 2662825400 \
			and _city._visuals["skyline_tall"].xfs.size() != tall_xfs.size()
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	var pin_default: bool = _city.fingerprint == 2492360539
	var skyline_detail := "nodes=%s total=%d tall=%d place=%s size=%s colliders=%d det=%s pins_foreign=%s pins_default=%s" % [
			nodes_ok, total, tall_xfs.size(), place_ok, size_ok, collider_count,
			deterministic, pin_foreign, pin_default]
	_check("city_horizon_skyline",
			count_ok and place_ok and size_ok and visual_only and deterministic
					and pin_foreign and pin_default,
			skyline_detail)
	## Informational: the skyline's tuned numbers — the ticket's bands, re-printed
	## on every re-verification.
	var skyline_data := "SIM DATA city_horizon_skyline: total=%d tall=%d inner=%.0f outer=%.0f fingerprint=%d" % [
			total, tall_xfs.size(), inner, outer, fp_first]
	print(skyline_data)


## --- scenarios (T-007 tourists) ---------------------------------------------


## Full density: `target_count` tourists seeded in loose groups around the
## player's area, actually strolling their sidewalk loops at slab level.
func _scenario_tourists_walk() -> void:
	await _set_up(true, _city.position + Vector3(0.0, 25.0, 0.0), Vector3.ZERO)
	var spawner := TouristSpawner.new()
	spawner.city = _city
	spawner.player = _player
	add_child(spawner)
	await _wait_frames(4)
	var tourists := spawner.living_tourists()
	var last: Array[Vector3] = []
	for tourist in tourists:
		last.append(tourist.global_position)
	var travel: Array[float] = []
	travel.resize(tourists.size())
	for f in 240: ## 4 s of strolling; accumulate real path length per tourist.
		await get_tree().physics_frame
		for i in tourists.size():
			var t: Tourist = tourists[i]
			if is_instance_valid(t):
				travel[i] += last[i].distance_to(t.global_position)
				last[i] = t.global_position
		if _debug and f % 60 == 0:
			for i in tourists.size():
				var t: Tourist = tourists[i]
				if is_instance_valid(t) and t.global_position.y < 0.05:
					_dbg("sink f%d t%d y=%.4f vel=%s pos=%s" % [f, i, t.global_position.y,
							t.velocity, t.global_position])
	var moved := 0
	var on_slab := true
	var finite := true
	var grouped := false
	var by_block := {}
	for i in tourists.size():
		var tourist: Tourist = tourists[i]
		if not is_instance_valid(tourist):
			continue
		## Path length, not net displacement: a tourist that rounded a waypoint
		## and is heading back can legitimately have a tiny net displacement.
		if travel[i] > 2.0:
			moved += 1
		else:
			_dbg("t%d stalled: travel=%.2f pos=%s path=%d mood=%s vel=%s" % [
					i, travel[i], tourist.global_position, tourist.path.size(),
					tourist.mood, tourist.velocity])
		var local_y := tourist.global_position.y - _city.position.y
		if absf(local_y - _city.block_slab_height) >= 0.2:
			_dbg("t%d off-slab: y=%.2f pos=%s mood=%s" % [i, local_y, tourist.global_position, tourist.mood])
		on_slab = on_slab and absf(local_y - _city.block_slab_height) < 0.2
		finite = finite and tourist.velocity.is_finite()
		var key := Vector2(tourist.block_center.x, tourist.block_center.z)
		by_block[key] = int(by_block.get(key, 0)) + 1
	for key in by_block:
		grouped = grouped or by_block[key] >= 2
	_check("tourists_walk_loose_groups",
			tourists.size() == 18 and moved == tourists.size() and on_slab and finite and grouped,
			"count %d, moved %d, on_slab=%s finite=%s grouped=%s" % [
					tourists.size(), moved, on_slab, finite, grouped])
	spawner.free()


## A real lobbed dropping hits a tourist: the duck-typed on_splatted panics it
## (sprint + score event relayed), and a second synthetic sideways hit proves
## the panic flees along the impact velocity's horizontal mirror.
func _scenario_tourist_splat() -> void:
	_dropped.clear()
	_splat_events.clear()
	_tourist_relay = 0
	var spawner := TouristSpawner.new()
	spawner.city = _city
	spawner.player = _player
	spawner.target_count = 1
	spawner.spawn_min_dist = 0.0
	spawner.spawn_max_dist = 10.0 ## Pin the loop to the plaza block, under the drop.
	add_child(spawner)
	await _wait_frames(4)
	var tourists := spawner.living_tourists()
	if tourists.is_empty():
		_check("tourist_splat_panics_scores", false, "no tourist spawned")
		spawner.free()
		return
	var tourist: Tourist = tourists[0]
	spawner.tourist_splatted.connect(func(_t: Tourist) -> void: _tourist_relay += 1)
	## T-009: Main's exact wiring — the spawner relay feeds the Game autoload —
	## so the real lob below scores end to end: the first (real) hit pays 100
	## at ×1 and the synthetic second hit is the chain's ×2 → 300 total.
	Game.reset_run()
	spawner.tourist_splatted.connect(func(t: Tourist) -> void:
			Game.add_tourist_hit(t.global_position))
	tourist.path = PackedVector3Array() ## Freeze the target under the drop.
	await _set_up(true, tourist.global_position + Vector3(0.0, 4.0, 0.0), Vector3.ZERO)
	await _tap("poop")
	await _wait_frames(2)
	var dropped := _dropped.size() == 1
	if dropped:
		_dropped[0].splatted.connect(_on_test_splatted)
	var panicked := false
	var max_hspeed := 0.0
	for _i in 120: ## The drop falls ~0.7 s; the panic sprint follows it.
		await get_tree().physics_frame
		panicked = panicked or tourist.mood == Tourist.Mood.PANIC
		max_hspeed = maxf(max_hspeed, Vector2(tourist.velocity.x, tourist.velocity.z).length())
		if _debug and _i % 20 == 0:
			_dbg("splat poll %d: poop=%s tourist_pos=%s mood=%s hspeed=%.2f" % [_i,
					_dropped[0].global_position if dropped and is_instance_valid(_dropped[0]) else Vector3.INF,
					tourist.global_position, tourist.mood,
					Vector2(tourist.velocity.x, tourist.velocity.z).length()])
	var fired: bool = _splat_events.size() == 1 and _splat_events[0].target == tourist
	var sprinted := panicked and max_hspeed > 2.5
	# Second hit through the same duck-typed entry, with a sideways impact:
	# the panic direction must mirror it horizontally.
	tourist.on_splatted(Vector3(6.0, -2.0, 0.0))
	await _wait_frames(2)
	var flees_impact := tourist._panic_dir.dot(Vector3(-1.0, 0.0, 0.0)) > 0.95
	_check("tourist_splat_panics_scores",
			dropped and fired and _tourist_relay == 2 and sprinted and flees_impact
					and Game.score == 300,
			"dropped=%s fired=%s relay=%d panicked=%s sprint %.1f m/s flees=%s score=%d" % [
					dropped, fired, _tourist_relay, panicked, max_hspeed, flees_impact,
					Game.score])
	spawner.free()


## A slow pass through the buzz zone earns nothing; a fast one earns a flinch
## duck — never a full panic (that takes a splat).
func _scenario_tourist_buzz() -> void:
	var spawner := TouristSpawner.new()
	spawner.city = _city
	spawner.player = _player
	spawner.target_count = 1
	spawner.spawn_min_dist = 0.0
	spawner.spawn_max_dist = 10.0
	add_child(spawner)
	await _wait_frames(4)
	var tourists := spawner.living_tourists()
	if tourists.is_empty():
		_check("tourist_buzz_flinch", false, "no tourist spawned")
		spawner.free()
		return
	var tourist: Tourist = tourists[0]
	tourist.path = PackedVector3Array() ## A standing target for repeatable passes.
	var pass_start: Vector3 = tourist.global_position + Vector3(0.0, 2.2, -5.0)
	await _set_up(true, pass_start, Vector3(0.0, 0.0, 9.0), 180.0)
	await _wait_frames(110) ## ~1.8 s: drifts through the zone slowly and lands beyond it.
	var slow_clean := tourist.buzz_count == 0 and tourist.mood != Tourist.Mood.PANIC
	await _set_up(true, pass_start, Vector3(0.0, 0.0, 18.0), 180.0)
	var saw_flinch := false
	for _i in 120:
		await get_tree().physics_frame
		saw_flinch = saw_flinch or tourist.mood == Tourist.Mood.FLINCH
		if tourist.buzz_count >= 1 and saw_flinch:
			break
	var fast_ok := tourist.buzz_count == 1 and saw_flinch \
			and tourist.mood != Tourist.Mood.PANIC
	_check("tourist_buzz_flinch", slow_clean and fast_ok,
			"slow pass clean=%s · fast pass buzzes=%d flinch_seen=%s panicked=%s" % [
					slow_clean, tourist.buzz_count, saw_flinch,
					tourist.mood == Tourist.Mood.PANIC])
	spawner.free()


## Density survives a move: teleporting the player across the city recycles
## the whole crowd — the SAME tourist nodes — into the spawn band around the
## new position.
func _scenario_tourists_recycle() -> void:
	await _set_up(true, _city.position + Vector3(0.0, 25.0, 0.0), Vector3.ZERO)
	var spawner := TouristSpawner.new()
	spawner.city = _city
	spawner.player = _player
	add_child(spawner)
	await _wait_frames(4)
	var tourists := spawner.living_tourists()
	var full := tourists.size() == spawner.target_count
	var ids: Array[int] = []
	for tourist in tourists:
		ids.append(tourist.get_instance_id())
	await _set_up(true, _city.position + Vector3(-90.0, 25.0, 0.0), Vector3.ZERO)
	await _wait_frames(45) ## 0.75 s > recycle_interval — one scan must move them all.
	var reused := true
	var placed := true
	var after := spawner.living_tourists()
	var anchor := Vector2(_city.position.x - 90.0, _city.position.z)
	for tourist in after:
		reused = reused and ids.has(tourist.get_instance_id())
		var flat := Vector2(tourist.global_position.x - anchor.x,
				tourist.global_position.z - anchor.y)
		var center := Vector2(tourist.block_center.x - anchor.x, tourist.block_center.z - anchor.y)
		# The recycle contract: every tourist is EITHER already within the
		# recycle radius of the moved player (legitimately kept — density
		# stays where the player is) OR recycled onto a loop in the spawn band.
		placed = placed and (flat.length() <= spawner.recycle_radius
				or (center.length() >= spawner.spawn_min_dist
						and center.length() <= spawner.spawn_max_dist))
	_check("tourists_recycle_around_player",
			full and after.size() == spawner.target_count and reused and placed,
			"full=%s count %d reused=%s placed=%s" % [
					full, after.size(), reused, placed])
	spawner.free()


## --- scenarios (T-008 cars) --------------------------------------------------


## Full density: the traffic fleet loops its block rings at lane speed — every
## car covers ground (nothing gridlocks), the fleet rounds corners (waypoints
## advance, the right-turn-only cuts work) and no two cars ever overlap —
## while the parked fleet sits exactly where it was seeded. The test pigeon
## settles GROUNDED on the plaza first: a standing bird pins the spawner's
## recycle anchor in place, so nothing recycles mid-scenario and a parked car
## drifting would be a real bug, not the anchor wandering.
func _scenario_cars_traffic() -> void:
	await _set_up(true, _city.position + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	var spawner := CarSpawner.new()
	spawner.city = _city
	spawner.player = _player
	add_child(spawner)
	await _wait_frames(4)
	var cars := spawner.living_cars()
	var moving: Array[Car] = []
	var parked: Array[Car] = []
	for car in cars:
		if car.mode == Car.Mode.TRAFFIC:
			moving.append(car)
		else:
			parked.append(car)
	if cars.is_empty() or moving.size() != spawner.target_moving \
			or parked.size() != spawner.target_parked or cars[0].collision_layer != 8:
		_check("cars_traffic_loops_blocks", false,
				"fleet %d (moving %d, parked %d, want %d/%d), layer %s" % [
						cars.size(), moving.size(), parked.size(),
						spawner.target_moving, spawner.target_parked,
						str(cars[0].collision_layer) if not cars.is_empty() else "?"])
		spawner.free()
		return
	var last: Array[Vector3] = []
	var start: Array[Vector3] = []
	var travel: Array[float] = []
	var corners: Array[int] = []
	var last_index: Array[int] = []
	for car in cars:
		last.append(car.global_position)
		start.append(car.global_position)
		travel.append(0.0)
		corners.append(0)
		last_index.append(car.waypoint_index)
	var min_gap := 100.0
	var gap_pair := Vector2i(-1, -1)
	for f in 480: ## 8 s of traffic.
		await get_tree().physics_frame
		for i in cars.size():
			var car: Car = cars[i]
			if not is_instance_valid(car):
				continue
			travel[i] += last[i].distance_to(car.global_position)
			if _debug and last[i].distance_to(car.global_position) > 5.0:
				_dbg("car %d TELEPORTED %s -> %s (player at %s)" % [
						i, last[i], car.global_position, _player.global_position])
			last[i] = car.global_position
			if car.waypoint_index != last_index[i]:
				corners[i] += 1
				last_index[i] = car.waypoint_index
		if f % 8 == 0: ## Sampled pairwise gaps — no transient car overlap.
			for i in cars.size():
				for j in range(i + 1, cars.size()):
					var a := cars[i].global_position
					var b := cars[j].global_position
					var gap := Vector2(a.x - b.x, a.z - b.z).length()
					if gap < min_gap:
						min_gap = gap
						gap_pair = Vector2i(i, j)
	var cruised := true
	var finite := true
	var corner_sum := 0
	for i in moving.size():
		## Path length over the run, not end speed: a car queued behind another
		## still accumulates travel — only a gridlock leaves it short.
		cruised = cruised and travel[i] > 8.0
		finite = finite and moving[i].velocity.is_finite()
		corner_sum += corners[i]
	var parked_ok := true
	for i in parked.size():
		var p := moving.size() + i
		parked_ok = parked_ok and travel[p] < 0.05 \
				and start[p].distance_to(parked[i].global_position) < 0.05
		if _debug and (travel[p] >= 0.05 or start[p].distance_to(parked[i].global_position) >= 0.05):
			_dbg("parked %d moved: travel %.3f drift %.3f start %s now %s" % [
					i, travel[p], start[p].distance_to(parked[i].global_position),
					start[p], parked[i].global_position])
	if _debug:
		for i in moving.size():
			_dbg("car %d: travel %.1f corners %d pos %s block %s" % [
					i, travel[i], corners[i], moving[i].global_position,
					moving[i].block_center])
			if travel[i] < 8.0:
				var self_hits := 0
				for body in moving[i].get_node("FrontZone").get_overlapping_bodies():
					if body == moving[i]:
						self_hits += 1
					else:
						_dbg("  car %d blocked by %s (%s) at %s layer %d" % [
								i, body.name, body.get_class(), body.global_position,
								body.collision_layer])
				_dbg("  car %d mode=%d vel=%s yaw=%.2f wp=%d/%d target=%s blocker_d=%.2f self_in_zone=%d" % [
						i, moving[i].mode, moving[i].velocity, moving[i].rotation.y,
						moving[i].waypoint_index, moving[i].path.size(),
						moving[i].path[moving[i].waypoint_index] if moving[i].path.size() > 0 else Vector3.INF,
						moving[i]._blocker_distance(), self_hits])
		_dbg("min gap %.2f between %d and %d" % [min_gap, gap_pair.x, gap_pair.y])
	_check("cars_traffic_loops_blocks",
			cruised and finite and corner_sum >= moving.size() and parked_ok and min_gap > 2.0,
			"moving %d cruised=%s finite=%s corners=%d (want ≥%d) parked_ok=%s min gap %.2f m (cars %d/%d)" % [
					moving.size(), cruised, finite, corner_sum, moving.size(),
					parked_ok, min_gap, gap_pair.x, gap_pair.y])
	spawner.free()


## A parked car takes a real lobbed splat — the duck-typed honk fires, the
## score event relays and the car stays parked. A traffic car hit through the
## same entry keeps driving its loop — getting splatted never derails traffic.
func _scenario_car_splat_honk() -> void:
	_dropped.clear()
	_splat_events.clear()
	_car_relay = 0
	## The pigeon grounds on the plaza first so the spawner's recycle anchor
	## stays put while the cars seed and drive.
	await _set_up(true, _city.position + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	var spawner := CarSpawner.new()
	spawner.city = _city
	spawner.player = _player
	spawner.target_moving = 1
	spawner.target_parked = 1
	spawner.spawn_min_dist = 0.0
	spawner.spawn_max_dist = 10.0 ## Pin both cars to the plaza block, under the drop.
	add_child(spawner)
	await _wait_frames(4)
	spawner.car_splatted.connect(func(_car: Car) -> void: _car_relay += 1)
	## T-009: Main's exact wiring on the car relay too — the real lob on the
	## parked car pays 30 at ×1 and the synthetic traffic hit is the chain's
	## ×2 → 90 total through the Game autoload.
	Game.reset_run()
	spawner.car_splatted.connect(func(car: Car) -> void:
			Game.add_car_hit(car.global_position))
	var parked: Car = null
	var traffic: Car = null
	for car in spawner.living_cars():
		if car.mode == Car.Mode.PARKED:
			parked = car
		else:
			traffic = car
	if parked == null or traffic == null:
		_check("car_splat_honk_and_continue", false,
				"parked=%s traffic=%s" % [parked != null, traffic != null])
		spawner.free()
		return
	var parked_start := parked.global_position
	await _set_up(true, parked_start + Vector3(0.0, 5.0, 0.0), Vector3.ZERO)
	await _tap("poop")
	await _wait_frames(2)
	if _dropped.size() == 1:
		_dropped[0].splatted.connect(_on_test_splatted)
	await _wait_frames(120) ## The drop falls ~0.5 s; margin for the honk.
	var fired: bool = _splat_events.size() == 1 and _splat_events[0].target == parked
	var parked_honked := parked.honk_count == 1
	var stayed := parked.global_position.distance_to(parked_start) < 0.05
	await _set_up(true, _city.position + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90) ## Back to the plaza — off the ring, anchor pinned.
	traffic.on_splatted(Vector3(0.0, -5.0, 0.0)) ## The same duck-typed entry the dropping calls.
	var drove := 0.0
	var last := traffic.global_position
	for _i in 120: ## 2 s after the splat.
		await get_tree().physics_frame
		drove += last.distance_to(traffic.global_position)
		last = traffic.global_position
	var traffic_honked := traffic.honk_count == 1
	var kept_driving := drove > 2.0 and traffic.velocity.is_finite()
	_check("car_splat_honk_and_continue",
			fired and parked_honked and stayed and traffic_honked and _car_relay == 2
					and kept_driving and Game.score == 90,
			"parked fired=%s honk=%d stayed=%s · traffic honked=%s relay=%d drove %.1f m after score=%d" % [
					fired, parked.honk_count, stayed, traffic_honked, _car_relay, drove,
					Game.score])
	spawner.free()


## The recycle insertion path keeps traffic flowing while the player stands
## still (T-089): five traffic cars re-seated onto ONE plaza-adjacent ring
## through the exact call `_recycle_far` makes — probed follow-gap-clear
## rejoin points — all keep looping with the pigeon parked on the plaza. The
## bars discriminate: a flowing car covers 50+ m of a ~116 m ring in 10 s,
## the mined standing clots crept ≈ 0.5 m per 10 s, and a healthy follow-gap
## queue holds 5.6 m — so travel < 8 m means a standing clot and a seeded
## gap < 4 m means an overlap. The whole chosen ring lies inside the recycle
## radius, so the scanner must leave everyone alone all run: any single-frame
## jump > 5 m is a recycle teleport, not a legit recycle.
func _scenario_traffic_recycle_keeps_flow() -> void:
	await _set_up(true, _city.position + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	var spawner := CarSpawner.new()
	spawner.city = _city
	spawner.player = _player
	add_child(spawner)
	await _wait_frames(4)
	## A block whose whole ring sits inside the recycle radius of the plaza
	## anchor — prefer one the initial seeding left traffic-free, so the run
	## reads as exactly the five re-seated cars on the ring.
	var plaza := Vector2(_city.position.x, _city.position.z)
	var fleet: Array[Car] = spawner.living_cars()
	var candidates: Array[Vector3] = []
	for center in _city.block_centers:
		var worst := 0.0
		for corner in spawner._loop_for(center):
			worst = maxf(worst, Vector2(corner.x - plaza.x, corner.z - plaza.y).length())
		if worst < spawner.recycle_radius:
			candidates.append(center)
	var block := Vector3.ZERO
	var found := false
	for candidate in candidates:
		var ring_global := _city.to_global(candidate)
		var occupied := false
		for car in fleet:
			occupied = occupied or (car.mode == Car.Mode.TRAFFIC
					and car.block_center == ring_global)
		if not occupied:
			block = candidate
			found = true
			break
	if not found and not candidates.is_empty():
		block = candidates[0]
		found = true
	if not found:
		_check("traffic_recycle_keeps_flow", false,
				"no block ring inside the recycle radius of the plaza")
		spawner.free()
		return
	var loop := spawner._loop_for(block)
	var block_global := _city.to_global(block)
	if _debug:
		_dbg("ring block %s global %s worst-corner candidates %d" % [
				block, block_global, candidates.size()])
		_dbg("loop corners: %s" % str(loop))
	var seeded: Array[Car] = []
	for car in fleet:
		if seeded.size() >= 5:
			break
		if car.mode == Car.Mode.TRAFFIC:
			## The exact insertion `_recycle_far` performs on a drifted car.
			car.recycle_to(spawner._clear_rejoin_point(loop, block_global, car),
					loop, block_global)
			seeded.append(car)
	if seeded.size() < 5:
		_check("traffic_recycle_keeps_flow", false,
				"fleet holds only %d traffic cars to seed" % seeded.size())
		spawner.free()
		return
	if _debug:
		for i in seeded.size():
			_dbg("seeded %d start %s yaw %.2f wp %d" % [
					i, seeded[i].global_position, seeded[i].rotation.y,
					seeded[i].waypoint_index])
	var cars := spawner.living_cars()
	var last: Array[Vector3] = []
	var travel: Array[float] = []
	var seeded_index: Array[int] = []
	for car in cars:
		last.append(car.global_position)
		travel.append(0.0)
		seeded_index.append(seeded.find(car))
	var min_gap_seeded := 100.0
	var min_gap_fleet := 100.0
	var max_frame_move := 0.0
	for f in 600: ## 10 s at the fixed 60 Hz step.
		await get_tree().physics_frame
		for i in cars.size():
			var car: Car = cars[i]
			if not is_instance_valid(car):
				continue
			var moved := last[i].distance_to(car.global_position)
			travel[i] += moved
			max_frame_move = maxf(max_frame_move, moved)
			last[i] = car.global_position
		if f % 8 == 0: ## Sampled pairwise gaps — no transient overlap.
			for i in cars.size():
				for j in range(i + 1, cars.size()):
					var a := cars[i].global_position
					var b := cars[j].global_position
					var gap := Vector2(a.x - b.x, a.z - b.z).length()
					min_gap_fleet = minf(min_gap_fleet, gap)
					if seeded_index[i] >= 0 and seeded_index[j] >= 0:
						min_gap_seeded = minf(min_gap_seeded, gap)
	var seeded_travel_ok := true
	var finite := true
	var seeded_travels: Array[float] = []
	for i in cars.size():
		finite = finite and cars[i].velocity.is_finite()
		if seeded_index[i] >= 0:
			seeded_travel_ok = seeded_travel_ok and travel[i] >= 8.0
			seeded_travels.append(travel[i])
	## Ring preference (T-089): the seeded ring now holds 5 traffic cars (>= the
	## soft cap), so a recycle draw over it and any lighter in-radius block must
	## land ONLY on the lighter one; a lone over-cap block is still draw-able.
	var preference_ok := true
	for candidate in candidates:
		if candidate != block:
			for _i in 30:
				preference_ok = preference_ok \
						and spawner._pick_recycle_block([block, candidate]) == candidate
			break
	preference_ok = preference_ok and spawner._pick_recycle_block([block]) == block
	var ok := seeded_travel_ok and preference_ok \
			and min_gap_seeded >= 4.0 and min_gap_fleet > 2.0 \
			and finite and max_frame_move <= 5.0
	if _debug:
		_dbg("ring block %s (global %s)" % [block, block_global])
		_dbg("pigeon at %s grounded=%s" % [_player.global_position, _player.is_grounded])
		for i in seeded.size():
			var sc := seeded[i]
			_dbg("seeded %d: travel %.1f pos %s vel %s wp %d/%d blocker_d %.2f" % [
					i, seeded_travels[i], sc.global_position, sc.velocity,
					sc.waypoint_index, sc.path.size(), sc._blocker_distance()])
			for body in sc.get_node("FrontZone").get_overlapping_bodies():
				_dbg("  seeded %d sees %s (%s) at %s layer %d" % [
						i, body.name, body.get_class(), body.global_position,
						body.collision_layer])
	_check("traffic_recycle_keeps_flow", ok,
			"seeded travels %s (all >= 8.0: %s) · ring preference %s · min seeded gap %.2f (want >= 4.0) · fleet gap %.2f (want > 2.0) · finite=%s · max frame move %.2f (want <= 5.0)" % [
					str(seeded_travels), seeded_travel_ok, preference_ok, min_gap_seeded,
					min_gap_fleet, finite, max_frame_move])
	spawner.free()


## --- scenarios (T-009 scoring & combos) -------------------------------------


## The harness listens to every hit the Game autoload resolves.
func _on_test_hit_scored(points: int, multiplier: int, pos: Vector3, style: bool) -> void:
	_score_events.append({"points": points, "multiplier": multiplier, "pos": pos, "style": style})


## The scoring state machine (T-009), driven straight through the Game
## autoload's public surface: DESIGN values (tourist 100, car 30), the chain
## escalating ×1 → ×2 → ×3 across target kinds, landing and window resets, and
## the +50% style bonus gated on a release that is fast, low and fresh.
func _scenario_scoring_values() -> void:
	Game.save_path = SIM_SAVE_PATH ## Never touch the real record.
	Game.reset_run()
	Game.high_score = 0
	_score_events.clear()
	Game.hit_scored.connect(_on_test_hit_scored)
	var p1: int = Game.add_tourist_hit(Vector3(1.0, 0.5, 2.0)) ## No release recorded yet — plain ×1.
	var p2: int = Game.add_car_hit(Vector3(2.0, 0.5, 3.0)) ## The chain crosses target kinds: 30 × 2.
	var p3: int = Game.add_tourist_hit(Vector3(3.0, 0.5, 4.0)) ## ×3.
	var chain := p1 == 100 and p2 == 60 and p3 == 300 and Game.score == 460
	Game.on_grounding_changed(true) ## Landing always resets the chain.
	var p4: int = Game.add_car_hit(Vector3.ZERO) ## Back to base: the DESIGN car value, ×1.
	var landed := p4 == 30 and Game.score == 490
	Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -18.0)) ## Fast AND low.
	var p5: int = Game.add_tourist_hit(Vector3.ZERO) ## 100 × 2 × 1.5.
	var p6: int = Game.add_tourist_hit(Vector3.ZERO) ## 100 × 3 × 1.5.
	var styled := p5 == 300 and p6 == 450
	Game.on_poop_released(Vector3(0.0, 10.0, 0.0), Vector3(0.0, 0.0, -18.0)) ## Fast but high.
	var p7: int = Game.add_tourist_hit(Vector3.ZERO)
	Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -5.0)) ## Low but slow.
	var p8: int = Game.add_tourist_hit(Vector3.ZERO)
	var gated := p7 == 400 and p8 == 500 ## Neither gate alone earns the bonus.
	Game.style_release_window = 0.4
	Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -18.0))
	await _wait_frames(35) ## 0.58 s — the release goes stale.
	var p9: int = Game.add_tourist_hit(Vector3.ZERO)
	Game.style_release_window = 3.0
	var stale_ok := p9 == 600 ## ×6, no style — too old to count as "the dive".
	Game.combo_window = 0.2
	await _wait_frames(15) ## 0.25 s — the chain times out.
	Game.combo_window = 20.0
	Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -18.0)) ## A fresh dive.
	var p10: int = Game.add_tourist_hit(Vector3.ZERO) ## The reset chain's first hit, styled: 150.
	var timed_out := p10 == 150 and Game.combo_multiplier() == 1
	var events_ok: bool = _score_events.size() == 10 \
			and _score_events[0].points == 100 and _score_events[0].multiplier == 1 \
			and _score_events[0].pos == Vector3(1.0, 0.5, 2.0) \
			and _score_events[4].style and _score_events[5].style \
			and not _score_events[6].style and not _score_events[8].style \
			and _score_events[9].style
	Game.hit_scored.disconnect(_on_test_hit_scored)
	_check("score_combo_style_values",
			chain and landed and styled and gated and stale_ok and timed_out and events_ok
					and Game.score == 2890 and Game.high_score == 2890,
			"chain=%s landed=%s styled=%s gated=%s stale=%s timed_out=%s events=%s score=%d high=%d" % [
					chain, landed, styled, gated, stale_ok, timed_out, events_ok,
					Game.score, Game.high_score])


## The high score (T-009) persists: beating the record writes user:// at once
## (an Alt-F4 keeps it), and a fresh Game — what a relaunch constructs — loads
## it back.
func _scenario_high_score_persists() -> void:
	Game.save_path = SIM_SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SIM_SAVE_PATH))
	Game.reset_run()
	Game.high_score = 0
	Game.add_tourist_hit(Vector3.ZERO)
	var wrote := Game.high_score == 100 and FileAccess.file_exists(SIM_SAVE_PATH)
	Game.reset_run() ## A fresh boot starts scoreless…
	Game.high_score = 0
	Game.load_high_score() ## …but reads the persisted record back.
	var reloaded := Game.high_score == 100
	_check("score_high_score_persists", wrote and reloaded,
			"wrote=%s reloaded=%s (high %d)" % [wrote, reloaded, Game.high_score])


## The popup (T-009): the ticket's "+100 ×2" format at the hit position, then
## float up, fade out and clean itself up after its lifetime.
func _scenario_score_popup() -> void:
	var popup: ScorePopup = POPUP_SCENE.instantiate()
	popup.lifetime = 0.5 ## Time-compressed.
	popup.setup(100, 2, Vector3(3.0, 2.0, 4.0))
	add_child(popup) ## _ready applies the setup and starts the tween from _pos.
	var text_ok := popup.label.text == "+100 ×2"
	var at_pos := popup.global_position.distance_to(Vector3(3.0, 2.0, 4.0)) < 0.01
	await _wait_frames(16) ## 0.27 s in — risen, fade under way.
	var risen := popup.global_position.y > 2.6
	var fading := popup.label.modulate.a < 1.0
	await _wait_frames(30) ## Past the 0.5 s lifetime.
	var cleaned := not is_instance_valid(popup)
	_check("score_popup_floats_and_fades", text_ok and at_pos and risen and fading and cleaned,
			"text=%s at_pos=%s risen=%s fading=%s cleaned=%s" % [
					text_ok, at_pos, risen, fading, cleaned])


## --- scenarios (T-010 game flow) --------------------------------------------


## Esc-pausing through the REAL PauseMenu script: the whole tree freezes — the
## flying pigeon stops dead mid-air and the hunger clock stops ticking — and
## resuming hands both back.
func _scenario_pause_freezes() -> void:
	var pause_menu := PauseMenu.new()
	add_child(pause_menu)
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	pause_menu.toggle()
	var paused := get_tree().paused and pause_menu.is_open
	var air_pos: Vector3 = _player.position
	var hunger_at_pause: float = hunger.value
	await _wait_frames(30)
	var frozen := _player.position.distance_to(air_pos) < 0.001 \
			and absf(hunger.value - hunger_at_pause) < 0.0001
	pause_menu.toggle()
	var resumed := not get_tree().paused and not pause_menu.is_open
	await _wait_frames(10)
	var flew_on := _player.position.distance_to(air_pos) > 0.5
	_check("pause_freezes_world", paused and frozen and resumed and flew_on,
			"paused=%s frozen=%s resumed=%s flew_on=%s (drift %.4f m, hunger Δ %.4f)" % [
					paused, frozen, resumed, flew_on,
					_player.position.distance_to(air_pos),
					absf(hunger.value - hunger_at_pause)])
	hunger.free()
	pause_menu.free()
	get_tree().paused = false ## Never leak a pause into later scenarios.


## (T-097) Esc at the title must not hard-quit the app: a synthetic `pause`
## action fed straight to the REAL menu scene's `_unhandled_input` neither quits
## the process nor pauses the tree — the menu instance survives and the harness
## keeps running. A regression re-adding the quit branch kills the whole Gate 1b
## run at that line, so the missing check IS the loud failure. `flap` and `quit`
## are deliberately never fed — they would change the harness's scene / quit it.
func _scenario_title_escape_does_not_quit() -> void:
	var menu: Control = MENU_SCENE.instantiate()
	add_child(menu)
	await _wait_frames(2)
	var esc_event := InputEventAction.new()
	esc_event.action = "pause"
	esc_event.pressed = true
	menu._unhandled_input(esc_event)
	await _wait_frames(5)
	var menu_alive := is_instance_valid(menu)
	var tree_unpaused := not get_tree().paused
	menu.free()
	_check("title_escape_does_not_quit", menu_alive and tree_unpaused,
			"menu_alive=%s tree_unpaused=%s (a quit here would kill the whole run)" % [
					menu_alive, tree_unpaused])


## The fail state, end to end through the REAL main scene (parked far from the
## test world): starving opens the score screen with the run's numbers — score,
## high score, tourist/car breakdown — freezes the run dead, and Esc stays
## locked while the run is over.
func _scenario_game_over_screen() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	_main_game = MAIN_SCENE.instantiate()
	_main_game.position = Vector3(-2500.0, 0.0, 2500.0) ## Own space, clear of the test world.
	add_child(_main_game)
	await _wait_frames(4)
	var drain_default: float = Game.hunger.drain_per_second
	Game.add_tourist_hit(Vector3(-2500.0, 0.5, 2500.0))
	Game.add_tourist_hit(Vector3(-2498.0, 0.5, 2501.0))
	Game.add_car_hit(Vector3(-2502.0, 0.5, 2499.0))
	var score_at_open: int = Game.score
	var high_at_open: int = Game.high_score
	Game.hunger.drain_per_second = 60.0 ## Time-compressed starvation: zero ~1.7 s in.
	var screen: GameOverScreen = _main_game.game_over_screen
	var opened := false
	for _i in 600: ## 10 s budget.
		await get_tree().physics_frame
		if get_tree().paused and screen.is_open:
			opened = true
			break
	var labels_ok := opened \
			and screen.score_label.text == "Score: %d" % score_at_open \
			and screen.high_label.text == "High score: %d" % high_at_open \
			and screen.breakdown_label.text.contains("Tourists splatted: 2") \
			and screen.breakdown_label.text.contains("Cars splatted: 1")
	var pigeon: Player = _main_game.get_node("Player")
	var frozen_pos: Vector3 = pigeon.position
	await _wait_frames(30)
	var frozen := pigeon.position.distance_to(frozen_pos) < 0.001 and get_tree().paused
	var pause_menu: PauseMenu = _main_game.get_node("PauseMenu")
	pause_menu.toggle() ## Esc on a dead run must be refused.
	var esc_locked := get_tree().paused
	Game.hunger.drain_per_second = drain_default ## Put the autoload's clock back.
	_check("game_over_shows_score_screen", opened and labels_ok and frozen and esc_locked,
			"opened=%s labels=%s frozen=%s esc_locked=%s (screen '%s' / '%s')" % [
					opened, labels_ok, frozen, esc_locked,
					screen.score_label.text if opened else "-",
					screen.breakdown_label.text if opened else "-"])


## Restart from the score screen (T-010): Main.restart_run() — the exact path
## the screen's Space button drives — zeroes score/breakdown, refills hunger,
## clears the one-shot game-over latch, regenerates the SAME-seed city and
## re-seeds every spawner with fresh nodes back around the spawn corridor.
func _scenario_restart_resets() -> void:
	var main_game: MainGame = _main_game
	var city: City = main_game.city
	var pigeon: Player = main_game.get_node("Player")
	var old_tourist_ids: Array[int] = []
	for tourist in main_game.tourist_spawner.living_tourists():
		old_tourist_ids.append(tourist.get_instance_id())
	var fp_before: int = city.fingerprint
	main_game.restart_run()
	var state_ok := not get_tree().paused \
			and not main_game.game_over_screen.visible \
			and Game.score == 0 and Game.tourist_hits == 0 and Game.car_hits == 0 \
			and Game.hunger.value >= Game.hunger.start_value - 0.001 \
			and not Game.hunger.game_over_emitted
	await _wait_frames(3) ## Let the queue_free'd old spawns flush out.
	var city_ok := city.fingerprint == fp_before ## Same M1 seed — comparable scores.
	var respawn_ok := pigeon.global_position.distance_to(city.spawn_point) < 1.0
	var fresh_tourists: Array[Tourist] = main_game.tourist_spawner.living_tourists()
	var reused := false
	for tourist in fresh_tourists:
		reused = reused or old_tourist_ids.has(tourist.get_instance_id())
	var spawns_ok := fresh_tourists.size() == main_game.tourist_spawner.target_count \
			and not reused \
			and main_game.bread_spawner.living_crumbs().size() == main_game.bread_spawner.target_count \
			and main_game.car_spawner.living_cars().size() \
					== main_game.car_spawner.target_moving + main_game.car_spawner.target_parked
	_check("restart_resets_run", state_ok and city_ok and respawn_ok and spawns_ok,
			"state=%s city=%s respawn=%s spawns=%s (tourists %d, crumbs %d, cars %d)" % [
					state_ok, city_ok, respawn_ok, spawns_ok,
					fresh_tourists.size(), main_game.bread_spawner.living_crumbs().size(),
					main_game.car_spawner.living_cars().size()])
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	main_game.free()
	_main_game = null


## Restart over the standing city (T-033): Main.restart_run() on the same seed
## must take the City fast path — no teardown, no rebuild (`build_count` stays
## 1, `fingerprint`/`spawn_point`/`last_report` untouched, exactly one
## `regenerated`) — while every spawner still re-seeds fresh tourist AND car
## nodes and the pigeon returns to the spawn corridor. If the fast path forgot
## to emit `regenerated`, the spawners would keep their old nodes and the
## instance-id overlap check below would fail the scenario.
func _scenario_restart_same_seed_skips_rebuild() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(2500.0, 0.0, 2500.0) ## Own space, clear of the test world.
	add_child(main_game)
	await _wait_frames(4) ## Boot build: the city stands exactly once.
	var city: City = main_game.city
	var pigeon: Player = main_game.player
	var boot_count: int = city.build_count
	var fp_before: int = city.fingerprint
	var spawn_before: Vector3 = city.spawn_point
	var report_before: int = city.last_report.hash()
	_regen_relay = 0
	city.regenerated.connect(func() -> void: _regen_relay += 1)
	var old_tourist_ids: Array[int] = []
	for tourist in main_game.tourist_spawner.living_tourists():
		old_tourist_ids.append(tourist.get_instance_id())
	var old_car_ids: Array[int] = []
	for car in main_game.car_spawner.living_cars():
		old_car_ids.append(car.get_instance_id())
	## Park the pigeon high above the corridor first, so "back at the spawn
	## point" can only come from restart_run's reset_flight.
	pigeon.reset_flight(city.to_local(spawn_before) + Vector3(0.0, 22.0, 0.0))
	await _wait_frames(10)
	main_game.restart_run()
	await _wait_frames(3) ## Let the queue_free'd old spawns flush out.
	var city_ok := boot_count == 1 and city.build_count == boot_count \
			and city.fingerprint == fp_before \
			and city.spawn_point == spawn_before \
			and city.last_report.hash() == report_before
	var respawn_ok := pigeon.global_position.distance_to(city.spawn_point) < 1.0
	var fresh_tourists: Array[Tourist] = main_game.tourist_spawner.living_tourists()
	var fresh_cars: Array[Car] = main_game.car_spawner.living_cars()
	var reused := false
	for tourist in fresh_tourists:
		reused = reused or old_tourist_ids.has(tourist.get_instance_id())
	for car in fresh_cars:
		reused = reused or old_car_ids.has(car.get_instance_id())
	var spawns_ok := fresh_tourists.size() == main_game.tourist_spawner.target_count \
			and fresh_cars.size() == main_game.car_spawner.target_moving \
					+ main_game.car_spawner.target_parked \
			and not reused
	var regen_ok := _regen_relay == 1
	_check("restart_same_seed_skips_rebuild",
			city_ok and respawn_ok and spawns_ok and regen_ok,
			"city=%s respawn=%s spawns=%s regen=%d (tourists %d, cars %d, build_count %d)" % [
					city_ok, respawn_ok, spawns_ok, _regen_relay,
					fresh_tourists.size(), fresh_cars.size(), city.build_count])
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	main_game.free()


## --- scenario (T-037 HUD bread pointer) --------------------------------------


## Independent nearest-crumb scan for the pointer scenario: computed from
## living_crumbs() distances — deliberately never through nearest_crumb()
## itself, which is the code under test.
func _scan_nearest_crumb(spawner: BreadSpawner, pos: Vector3) -> BreadCrumb:
	var nearest: BreadCrumb = null
	var best := INF
	for crumb in spawner.living_crumbs():
		var d := pos.distance_squared_to(crumb.global_position)
		if d < best:
			best = d
			nearest = crumb
	return nearest


## Reads the "<what> <n> m[ ▲|▼]" distance out of the pointer text — -1.0 when
## the text is not in an expected shape (hidden, empty, malformed). The fourth
## part is the T-098 climb cue and is optional; any other fourth part (or a
## missing "m") stays malformed.
func _pointer_distance_m(text: String) -> float:
	var parts := text.strip_edges().split(" ")
	if parts.size() == 3 and parts[2] == "m":
		return float(parts[1])
	if parts.size() == 4 and parts[2] == "m" \
			and (parts[3] == "▲" or parts[3] == "▼"):
		return float(parts[1])
	return -1.0


## Wraps a degree value into (-180, 180] so two chevron rotations compare
## across the ±180 seam.
func _wrap180(deg: float) -> float:
	return fposmod(deg + 180.0, 360.0) - 180.0


## T-037: the HUD bread pointer through the REAL main scene. Registered in the
## T-019 window — immediately after _scenario_restart_resets, before
## _scenario_hud_hunger_tiers: the only spot with an unpaused tree and no live
## Main (the pointer updates in _process), with the same cleanup tail (free() →
## Game.hunger.player = null → Game.reset_run()) handing the window back.
## Assertions: nearest_crumb() matches an independent scan over living_crumbs()
## (and returns null when none is alive); bread mode names the nearest crumb
## within 1 m and carries the bearing from the nose (flipping ~180° when the
## yaw flips at the same spot); the readout decreases on approach; eating the
## pointed-at crumb through the real grounded waddle-in re-aims at the
## next-nearest; beyond half the city span the same slot names "city" with the
## horizontal distance to city.spawn_point (± 2 m), chevron pointing back; the
## label carries the T-019 outline treatment. Since T-098 the readout also
## carries the climb cue, scan-decided like every arm: " ▲" with a hand-placed
## crumb ~10 m over a grounded pigeon, " ▼" from ~10 m above a street crumb,
## no arrow within the ±3 m band, and city mode never arrowed
## (_pointer_distance_m accepts both shapes).
func _scenario_hud_bread_pointer_tracks_nearest_crumb() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(3500.0, 0.0, -3500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var city: City = main_game.city
	var pigeon: Player = main_game.player
	var spawner: BreadSpawner = main_game.bread_spawner
	var pointer: Label = main_game.bread_pointer
	var chevron: Polygon2D = main_game.bread_pointer_chevron
	## Aim the scenario at a ground-level crumb near the spawn: y < 0.3 keeps
	## bench-seat crumbs (0.72) out, so the waddle-in happens on pavement, and
	## ring spots sit outside every building footprint (9.75 m from the block
	## centre vs the 7.8 m facade reach), so the hover column is always clear.
	var target: BreadCrumb = null
	var best := INF
	for crumb in spawner.living_crumbs():
		if crumb.global_position.y > 0.3:
			continue
		var d := city.spawn_point.distance_squared_to(crumb.global_position)
		if d < best:
			best = d
			target = crumb
	var spread_ok: bool = target != null
	## --- bread mode: the query, the distance, the bearing ---------------------
	## Hover south-east of the crumb (never dead above: a target straight below
	## zeroes the flat bearing — Main keeps the last chevron rotation there).
	var hover := city.to_local(target.global_position + Vector3(0.0, 8.0, 6.0))
	pigeon.reset_flight(hover, 0.0)
	await _wait_frames(2)
	var at := pigeon.global_position
	var want: BreadCrumb = _scan_nearest_crumb(spawner, at)
	var query_ok: bool = spawner.nearest_crumb(at) == want and want == target
	var d_true := at.distance_to(target.global_position)
	var shown := _pointer_distance_m(pointer.text)
	var dist_ok: bool = pointer.visible and shown >= 0.0 and absf(shown - d_true) <= 1.0
	var heading := -pigeon.transform.basis.z
	heading.y = 0.0
	var to_crumb := target.global_position - at
	to_crumb.y = 0.0
	var want_rot := _wrap180(-rad_to_deg(heading.signed_angle_to(to_crumb, Vector3.UP)))
	var rot_a := _wrap180(chevron.rotation_degrees)
	var bearing_ok: bool = absf(rot_a - want_rot) <= 2.0
	## --- the 180° flip: same spot, nose the other way --------------------------
	pigeon.reset_flight(hover, 180.0)
	await _wait_frames(2)
	var rot_b := _wrap180(chevron.rotation_degrees)
	var flip_ok: bool = absf(_wrap180(rot_a - rot_b)) > 150.0
	## --- approaching the pointed-at crumb decreases the readout ----------------
	pigeon.reset_flight(city.to_local(target.global_position + Vector3(2.6, 2.0, 0.0)), 0.0)
	await _wait_frames(2)
	var d_near := pigeon.global_position.distance_to(target.global_position)
	var shown_near := _pointer_distance_m(pointer.text)
	var approach_ok: bool = shown_near >= 0.0 and shown_near < shown \
			and absf(shown_near - d_near) <= 1.0 and d_near < d_true
	## (T-098) This approach hover sits 2 m above the crumb — inside the ±3 m
	## cue band — so the readout must carry no trailing arrow here.
	var level_text := pointer.text
	var level_ok: bool = not (level_text.ends_with(" ▲") or level_text.ends_with(" ▼"))
	## --- eat the pointed-at crumb through the real grounded waddle-in ----------
	## The drop mirrors _scenario_bread_eating: 1.8 m ahead (yaw 0 walks -Z,
	## straight into the crumb), settle grounded, then waddle until it is eaten.
	pigeon.reset_flight(city.to_local(target.global_position + Vector3(0.0, 0.4, 1.8)))
	for _i in 90:
		await get_tree().physics_frame
		if pigeon.is_grounded:
			break
	Input.action_press("pitch_up")
	var eaten := false
	for _i in 120:
		await get_tree().physics_frame
		eaten = not is_instance_valid(target)
		if eaten:
			break
	Input.action_release("pitch_up")
	await _wait_frames(2) ## Pointer refresh + the queue_free flush.
	var at2 := pigeon.global_position
	var want2: BreadCrumb = _scan_nearest_crumb(spawner, at2)
	var reaim_ok: bool = eaten and want2 != null and want2 != target \
			and pointer.visible \
			and absf(_pointer_distance_m(pointer.text)
					- at2.distance_to(want2.global_position)) <= 1.0
	## --- T-098 climb cue: " ▲" for a named crumb well ABOVE the pigeon ---------
	## The roof-crumb failure shape: a GROUNDED pigeon, a hand-placed crumb
	## ~10 m overhead (drop_crumb — the T-020 hand-placed path). Pre-pick a
	## street spot whose ground column is ≥ 12 m from every living crumb, so
	## from the column the placed crumb (~10 m) beats every other crumb
	## (≥ ~11.7 m) in the 3D scan; if the scan still names something else, a
	## bounded search re-grounds around the column and re-scans — decided
	## against the scan oracle, never against nearest_crumb().
	var cue_ground := Vector3.ZERO
	for spot in city.bread_spots:
		var spot_world := city.to_global(spot)
		if spot_world.y > 0.3:
			continue
		## Stay well inside the pointer's bread-mode ring (some street spots sit
		## past half the city span, where the slot flips to "city" and — by
		## design — drops the cue).
		var off_centre: Vector3 = spot_world - city.global_position
		off_centre.y = 0.0
		if off_centre.length() > city.city_span * 0.35:
			continue
		var column_clear := true
		for crumb in spawner.living_crumbs():
			if spot_world.distance_to(crumb.global_position) < 12.0:
				column_clear = false
				break
		if column_clear:
			cue_ground = spot_world
			break
	var placed: BreadCrumb = null
	if cue_ground != Vector3.ZERO:
		spawner.drop_crumb(cue_ground + Vector3(0.0, 10.0, 0.0))
		for crumb in spawner.living_crumbs():
			if crumb.global_position.distance_to(
					cue_ground + Vector3(0.0, 10.0, 0.0)) < 0.5:
				placed = crumb
				break
	var cue_up_ok := false
	var cue_up_shown := -1.0
	var cue_up_true := -1.0
	var cue_up_text := ""
	if placed != null:
		for nudge: Vector2 in [Vector2.ZERO, Vector2(0.6, 0.0), Vector2(-0.6, 0.0),
				Vector2(0.0, 0.6), Vector2(0.0, -0.6)]:
			pigeon.reset_flight(city.to_local(
					cue_ground + Vector3(nudge.x, 0.4, nudge.y)))
			for _i in 90:
				await get_tree().physics_frame
				if pigeon.is_grounded:
					break
			await _wait_frames(2)
			var at_up := pigeon.global_position
			if not pigeon.is_grounded or _scan_nearest_crumb(spawner, at_up) != placed:
				continue
			cue_up_true = at_up.distance_to(placed.global_position)
			cue_up_text = pointer.text
			cue_up_shown = _pointer_distance_m(cue_up_text)
			cue_up_ok = pointer.visible and cue_up_text.ends_with(" ▲") \
					and cue_up_shown >= 0.0 and absf(cue_up_shown - cue_up_true) <= 1.0
			break
	## --- T-098 climb cue: " ▼" for a named crumb well BELOW the pigeon ---------
	## The airborne mirror: reset_flight ~10 m above a street crumb (6 m south
	## so the flat bearing stays defined); probe candidates until the scan names
	## one from its own probe point — again scan-decided. The placed ▲ crumb
	## (~10 m up) cannot pass the y < 0.3 street filter.
	var cue_down_crumb: BreadCrumb = null
	var cue_down_at := Vector3.ZERO
	for crumb in spawner.living_crumbs():
		if crumb.global_position.y > 0.3:
			continue
		pigeon.reset_flight(city.to_local(
				crumb.global_position + Vector3(0.0, 10.0, 6.0)))
		await _wait_frames(2)
		cue_down_at = pigeon.global_position
		if _scan_nearest_crumb(spawner, cue_down_at) == crumb:
			cue_down_crumb = crumb
			break
	var cue_down_ok := false
	var cue_down_shown := -1.0
	var cue_down_true := -1.0
	var cue_down_text := ""
	if cue_down_crumb != null:
		cue_down_true = cue_down_at.distance_to(cue_down_crumb.global_position)
		cue_down_text = pointer.text
		cue_down_shown = _pointer_distance_m(cue_down_text)
		cue_down_ok = pointer.visible and cue_down_text.ends_with(" ▼") \
				and cue_down_shown >= 0.0 and absf(cue_down_shown - cue_down_true) <= 1.0
	## --- city mode beyond the ring ---------------------------------------------
	pigeon.reset_flight(Vector3(city.city_span * 0.5 + 40.0, 30.0, 0.0), 0.0)
	await _wait_frames(2)
	var home := city.spawn_point
	var flat_home := Vector2(home.x - pigeon.global_position.x,
			home.z - pigeon.global_position.z)
	var to_home := home - pigeon.global_position
	to_home.y = 0.0
	var heading_out := -pigeon.transform.basis.z
	heading_out.y = 0.0
	var want_city_rot := _wrap180(-rad_to_deg(heading_out.signed_angle_to(to_home, Vector3.UP)))
	var city_ok: bool = pointer.visible and pointer.text.begins_with("city ") \
			and not (pointer.text.ends_with(" ▲") or pointer.text.ends_with(" ▼")) \
			and absf(_pointer_distance_m(pointer.text) - flat_home.length()) <= 2.0 \
			and absf(_wrap180(chevron.rotation_degrees) - want_city_rot) <= 2.0
	## --- the T-019 outline treatment -------------------------------------------
	var style_ok: bool = \
			pointer.get_theme_color("font_outline_color").is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and pointer.get_theme_constant("outline_size") == 4 \
			and pointer.get_theme_font_size("font_size") == 14 \
			and pointer.get_theme_color("font_color").is_equal_approx(Color(1.0, 1.0, 1.0, 0.75))
	## --- nearest_crumb()'s null arm: an empty spawner has no nearest -----------
	var empty := BreadSpawner.new()
	var none_ok: bool = empty.nearest_crumb(Vector3.ZERO) == null
	empty.free()
	_check("hud_bread_pointer_tracks_nearest_crumb",
			spread_ok and query_ok and dist_ok and bearing_ok and flip_ok and approach_ok
					and level_ok and reaim_ok and cue_up_ok and cue_down_ok
					and city_ok and style_ok and none_ok,
			"spread=%s query=%s dist=%s (%.1f true, shows %.0f) bearing=%s (%.1f vs %.1f) flip=%s (%.1f→%.1f) approach=%s (%.0f→%.0f, near true %.1f) level=%s ('%s') reaim=%s (eaten %s) cue_up=%s ('%s' %.1f true, shows %.0f) cue_down=%s ('%s' %.1f true, shows %.0f) city=%s ('%s' %.1f vs %.1f) style=%s none=%s" % [
					spread_ok, query_ok, dist_ok, d_true, shown,
					bearing_ok, rot_a, want_rot,
					flip_ok, rot_a, rot_b,
					approach_ok, shown, shown_near, d_near,
					level_ok, level_text,
					reaim_ok, eaten,
					cue_up_ok, cue_up_text, cue_up_true, cue_up_shown,
					cue_down_ok, cue_down_text, cue_down_true, cue_down_shown,
					city_ok, pointer.text, _pointer_distance_m(pointer.text), flat_home.length(),
					style_ok, none_ok])
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()


## T-019: the HUD stays readable and the hunger bar warns in tiers, through the
## REAL main scene. Registered immediately after the two restart scenarios —
## that is the only stretch with an unpaused tree and no live Main
## (game_over_screen ends paused; the restart scenarios unpause, detach the
## clock and free their instances), so this fresh instance's _process pulse
## actually advances and it is the sole listener on Game.hunger.changed.
func _scenario_hud_hunger_tiers() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-3500.0, 0.0, -3500.0) ## Own space, clear of the test world.
	add_child(main_game)
	await _wait_frames(4)
	var stats: Label = main_game.stats_label
	var hint: Label = main_game.hint_label
	var bar: ProgressBar = main_game.hunger_bar
	## Outlines resolve through the theme stack — there is no per-override
	## getter, and the default Label theme defines font_outline_color, so
	## equality against the tuned values is the reliable read.
	var outline_ok: bool = \
			stats.get_theme_color("font_outline_color").is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and stats.get_theme_constant("outline_size") == 6 \
			and hint.get_theme_color("font_outline_color").is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and hint.get_theme_constant("outline_size") == 4
	## T-080: the bar carries its own track/fill styleboxes, resolved through
	## the theme stack (there is no per-override getter). The fill must be pure
	## WHITE — the tier-modulate invariant, since hunger_bar.modulate
	## multiplies the whole node — and both styleboxes the dark-outline family
	## with ≥ 1 px borders on all four sides, so the bar stays a bounded
	## element in every tier (black × anything is still black).
	var track_box: StyleBoxFlat = bar.get_theme_stylebox("background") as StyleBoxFlat
	var fill_box: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	var styleboxes_ok: bool = track_box != null and fill_box != null \
			and track_box.bg_color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.35)) \
			and track_box.border_color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and fill_box.border_color.is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and track_box.border_width_left >= 1 and track_box.border_width_top >= 1 \
			and track_box.border_width_right >= 1 and track_box.border_width_bottom >= 1 \
			and fill_box.border_width_left >= 1 and fill_box.border_width_top >= 1 \
			and fill_box.border_width_right >= 1 and fill_box.border_width_bottom >= 1 \
			and fill_box.bg_color.is_equal_approx(Color.WHITE)
	## Tier bands through the real signal path: the value setter emits
	## synchronously, so set→read same-frame is exact; probes sit mid-band so
	## the live drain (~0.27/s grounded) can't cross a boundary mid-scenario.
	var probes := {80: 0, 40: 1, 20: 2, 8: 3}
	var tiers_ok := true
	for probe_value in probes:
		Game.hunger.value = float(probe_value)
		tiers_ok = tiers_ok and main_game.hud_warning_tier == probes[probe_value]
	## Quiet tiers park the bar on their rest color — sample a window to prove
	## nothing animates it.
	Game.hunger.value = 80.0
	var quiet_static := true
	for _i in 10:
		await get_tree().process_frame
		quiet_static = quiet_static and bar.modulate.is_equal_approx(MainGame.TIER_REST_COLORS[0])
	## Danger tiers pulse in game time — sample ~0.5 s each, assert the channel
	## spread (never sampled at the flash's rest point) and that tier 3 flashes
	## FASTER than tier 2 via zero crossings of the green channel.
	Game.hunger.value = 20.0
	var tier2_lo := 1.0
	var tier2_hi := 0.0
	var tier2_last := -1.0
	var tier2_crossings := 0
	for _i in 30:
		await get_tree().process_frame
		var g2 := bar.modulate.g
		tier2_lo = minf(tier2_lo, g2)
		tier2_hi = maxf(tier2_hi, g2)
		if tier2_last >= 0.0 and (g2 - 0.55) * (tier2_last - 0.55) < 0.0:
			tier2_crossings += 1
		tier2_last = g2
	Game.hunger.value = 8.0
	var tier3_lo := 1.0
	var tier3_hi := 0.0
	var tier3_last := -1.0
	var tier3_crossings := 0
	for _i in 30:
		await get_tree().process_frame
		var g3 := bar.modulate.g
		tier3_lo = minf(tier3_lo, g3)
		tier3_hi = maxf(tier3_hi, g3)
		if tier3_last >= 0.0 and (g3 - 0.5) * (tier3_last - 0.5) < 0.0:
			tier3_crossings += 1
		tier3_last = g3
	var pulse2 := tier2_hi - tier2_lo > 0.1
	var pulse3 := tier3_hi - tier3_lo > 0.1
	var faster := tier3_crossings > tier2_crossings
	## Falling back to a lower tier restores that tier's rest color — the crumb
	## path (a refill through changed)…
	Game.hunger.value = 80.0
	var refill_rest := bar.modulate.is_equal_approx(MainGame.TIER_REST_COLORS[0])
	## …and the restart path re-fires full hunger through the same handler.
	main_game.restart_run()
	var restart_rest := not get_tree().paused \
			and main_game.hud_warning_tier == 0 \
			and bar.modulate.is_equal_approx(MainGame.TIER_REST_COLORS[0])
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("hud_hunger_warning_tiers",
			outline_ok and styleboxes_ok and tiers_ok and quiet_static and pulse2 and pulse3 \
					and faster and refill_rest and restart_rest,
			"outline=%s styleboxes=%s tiers=%s quiet_static=%s pulse2=%s (g %.2f..%.2f, %d x) pulse3=%s (g %.2f..%.2f, %d x) faster=%s refill_rest=%s restart_rest=%s" % [
					outline_ok, styleboxes_ok, tiers_ok, quiet_static,
					pulse2, tier2_lo, tier2_hi, tier2_crossings,
					pulse3, tier3_lo, tier3_hi, tier3_crossings,
					faster, refill_rest, restart_rest])


## --- scenarios (T-011 pigeon presentation) ----------------------------------


## The pose mirrors the flight state: wings out in a glide, a wing beat on
## every real flap impulse (and the beat ends), wings swept back in a dive.
func _scenario_pigeon_air_poses() -> void:
	var bird: PigeonVisual = _player.pigeon
	## Glide leg: cruise at lift speed — wings extended, unswept.
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _wait_frames(45) ## The wing joints ease to the pose targets.
	var gliding := bird.pose == PigeonVisual.Pose.GLIDE \
			and bird.wing_sweep < 0.3 and bird.wing_lift > 0.05
	## Flap leg: a real flap plays a wing beat, and the beat finishes.
	await _tap("flap")
	var beat_seen := false
	for _i in 10:
		await get_tree().physics_frame
		beat_seen = beat_seen or bird.flap_beating
	await _wait_frames(30) ## 0.5 s > flap_beat_seconds.
	var beat_done := not bird.flap_beating and bird.pose == PigeonVisual.Pose.GLIDE
	## Dive leg: nose down past the pose threshold — the wings sweep back.
	await _set_up(true, Vector3(0.0, 32.0, 0.0), Vector3(0.0, 0.0, -10.0))
	await _pitch_until("pitch_down", -0.85, 90)
	await _wait_frames(25)
	var diving := bird.pose == PigeonVisual.Pose.DIVE and bird.wing_sweep > 0.7
	_check("pigeon_air_poses_track_flight", gliding and beat_seen and beat_done and diving,
			"glide=%s (pose %d sweep %.2f lift %.2f) beat=%s done=%s dive=%s (pose %d sweep %.2f)" % [
					gliding, bird.pose, bird.wing_sweep, bird.wing_lift,
					beat_seen, beat_done, diving, bird.pose, bird.wing_sweep])


## The grounded poses follow the waddle: folded wings standing still, the
## waddle pose while walking, back to stand when the waddle stops.
func _scenario_pigeon_ground_poses() -> void:
	var bird: PigeonVisual = _player.pigeon
	await _set_up(true, Vector3(0.0, 3.0, 0.0), Vector3.ZERO)
	await _await_grounded(120)
	await _wait_frames(45) ## Let the touchdown slide bleed and the wings fold.
	var standing := bird.pose == PigeonVisual.Pose.STAND \
			and bird.wing_sweep > 0.7 and bird.wing_lift < 0.0
	await _hold("pitch_up", 30) ## Half a second of waddling.
	var waddling := bird.pose == PigeonVisual.Pose.WADDLE
	await _wait_frames(50) ## Past the walk_decel stop.
	var rested := bird.pose == PigeonVisual.Pose.STAND
	_check("pigeon_ground_poses_track_waddle", standing and waddling and rested,
			"stand=%s (pose %d sweep %.2f lift %.2f) waddle=%s rested=%s (pose %d)" % [
					standing, bird.pose, bird.wing_sweep, bird.wing_lift,
					waddling, rested, bird.pose])


## Eating a crumb plays the peck — the same wiring Main uses (crumb.eaten →
## Player.peck): the overlay fires and the beak visibly dives at the ground.
func _scenario_pigeon_peck() -> void:
	var bird: PigeonVisual = _player.pigeon
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	var crumb: BreadCrumb = CRUMB_SCENE.instantiate()
	crumb.position = Vector3(0.0, 0.16, 0.0)
	add_child(crumb)
	crumb.eaten.connect(hunger.eat)
	crumb.eaten.connect(_player.peck) ## Main's exact wiring.
	await _set_up(true, Vector3(0.0, 0.4, 1.8), Vector3.ZERO) ## Drop ahead of the crumb…
	await _await_grounded(90)
	await _wait_frames(10)
	hunger.value = 40.0 ## Mid-bar so the +30 restore is measurable (a full bar would just clamp).
	var hunger0: float = hunger.value
	var pecked := false
	var beak_down := false
	Input.action_press("pitch_up") ## Waddle in and watch for the peck overlay and the beak dive.
	for _i in 120:
		await get_tree().physics_frame
		pecked = pecked or bird.pecking
		beak_down = beak_down or (bird.pecking and bird.head_pitch < -0.8)
		if pecked and beak_down:
			break
	Input.action_release("pitch_up")
	var ate := not is_instance_valid(crumb) and hunger.value > hunger0 + 10.0
	await _wait_frames(30) ## Past the peck length.
	var peck_ended := not bird.pecking
	_check("pigeon_pecks_when_eating", ate and pecked and beak_down and peck_ended,
			"ate=%s pecked=%s beak_down=%s ended=%s (head pitch %.2f)" % [
					ate, pecked, beak_down, peck_ended, bird.head_pitch])
	hunger.free()


## --- scenarios (T-016 pigeon silhouette) ------------------------------------


## The albedo of a mesh instance's first surface — how the bird's look is
## authored (materials live on the Mesh sub-resources in pigeon_visual.tscn).
func _mesh_albedo(root: Node, node_path: String) -> Color:
	var mesh_instance: MeshInstance3D = root.get_node(node_path) as MeshInstance3D
	var mesh: Mesh = mesh_instance.mesh
	return (mesh.surface_get_material(0) as StandardMaterial3D).albedo_color


func _rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)


## The player bird must carry its own silhouette (T-016): the play pass showed
## the old body albedo ≈ the sidewalk albedo and lighter than the cream
## facades, so the bird washed out exactly where it flies most. Gates the two
## named wash-out backdrops at Euclidean RGB ≥ 0.20 (sidewalk + the sandy-cream
## family), demands luminance ≥ 0.05 darker than EVERY district backdrop's mean,
## and keeps the identity accents (wingtips a readable step darker, head a step
## lighter). The full 12-color sweep prints informationally — a per-channel gate
## across all 13 backdrops is only satisfiable by a near-black bird.
##
## T-026 re-valued the ground planes (darker sidewalk/plaza, lighter asphalt)
## and pins them apart here so a future tweak cannot silently re-merge the
## surfaces: sidewalk ↔ asphalt ≥ 0.30 (the retune narrows the old 0.62 gap on
## purpose, but the road must keep reading darker than the pavement) and
## sidewalk ↔ body ≥ 0.20 (the T-016 floor, re-asserted explicitly on the
## ground pair because the darker sidewalk is what makes it load-bearing).
##
## T-045/T-085 add the dark-ground leg: the gray body melts into asphalt/roof
## (0.225 / 0.151 at the retuned values), so the bird must always carry ONE
## bright anchor over that family — the head (already a dark-backdrop anchor
## with almost no projected area) and the new pale rump/underwing patches
## (Mat_rump) each sit ≥ 0.30 Euclidean RGB from COLOR_ASPHALT and COLOR_ROOF;
## the four distances print informationally. The patch rig is also pinned
## here: both underwings wear the exact Mat_rump sub-resource the Rump wears,
## and the bird scene stays visual-only (Node3D/MeshInstance3D, no physics).
func _scenario_pigeon_silhouette_contrast() -> void:
	var bird: PigeonVisual = load("res://scenes/pigeon_visual.tscn").instantiate() as PigeonVisual
	add_child(bird)
	var body := _rgb(_mesh_albedo(bird, "Body"))
	var head := _rgb(_mesh_albedo(bird, "HeadPivot/Head"))
	var tip := _rgb(_mesh_albedo(bird, "WingL/Tip"))
	var rump := _rgb(_mesh_albedo(bird, "Rump"))
	var rump_mat: Material = (bird.get_node("Rump") as MeshInstance3D).mesh.surface_get_material(0)
	var under_l_mat: Material = (bird.get_node("WingL/Under") as MeshInstance3D).mesh.surface_get_material(0)
	var under_r_mat: Material = (bird.get_node("WingR/Under") as MeshInstance3D).mesh.surface_get_material(0)
	var patches_wear_rump := under_l_mat == rump_mat and under_r_mat == rump_mat
	var visual_only := bird.get_class() == "Node3D"
	for node: Node in bird.find_children("*", "Node", true, false):
		visual_only = visual_only and node.get_class() in ["Node3D", "MeshInstance3D"]
	bird.free()
	var sidewalk := _rgb(City.COLOR_SIDEWALK)
	var near_backdrops: Array[Vector3] = [sidewalk]
	for backdrop: Color in City.DISTRICT_PALETTES[1]: ## The sandy-cream family.
		near_backdrops.append(_rgb(backdrop))
	var near_gate := true
	var distances := []
	for backdrop: Vector3 in near_backdrops:
		var d := body.distance_to(backdrop)
		distances.append("%.2f" % d)
		near_gate = near_gate and d >= 0.2
	var body_mean := (body.x + body.y + body.z) / 3.0
	var worst_margin := INF
	var luminance_gate := true
	for family: Array in City.DISTRICT_PALETTES:
		for backdrop: Color in family:
			var margin := (backdrop.r + backdrop.g + backdrop.b) / 3.0 - body_mean
			worst_margin = minf(worst_margin, margin)
			luminance_gate = luminance_gate and margin >= 0.05
	var tip_step := tip.distance_to(body) >= 0.15
	var head_step := head.x > body.x and head.y > body.y and head.z > body.z
	var sidewalk_asphalt := sidewalk.distance_to(_rgb(City.COLOR_ASPHALT))
	var sidewalk_body := sidewalk.distance_to(body)
	var ground_gate := sidewalk_asphalt >= 0.3 and sidewalk_body >= 0.2
	var asphalt := _rgb(City.COLOR_ASPHALT)
	var roof := _rgb(City.COLOR_ROOF)
	var head_asphalt := head.distance_to(asphalt)
	var head_roof := head.distance_to(roof)
	var rump_asphalt := rump.distance_to(asphalt)
	var rump_roof := rump.distance_to(roof)
	var dark_ground_gate := head_asphalt >= 0.3 and head_roof >= 0.3 \
			and rump_asphalt >= 0.3 and rump_roof >= 0.3
	var sweep := []
	for family: Array in City.DISTRICT_PALETTES:
		for backdrop: Color in family:
			sweep.append("%.2f" % body.distance_to(_rgb(backdrop)))
	print("SIM INFO silhouette distances to all 12 district colors: [%s]" % [", ".join(sweep)])
	print("SIM INFO ground pairs (T-026): sidewalk-asphalt=%.3f (>= 0.30) sidewalk-body=%.3f (>= 0.20)"
			% [sidewalk_asphalt, sidewalk_body])
	print(("SIM INFO dark-ground anchors (T-045/T-085): head-asphalt=%.3f head-roof=%.3f "
			+ "rump-asphalt=%.3f rump-roof=%.3f (all >= 0.30)")
			% [head_asphalt, head_roof, rump_asphalt, rump_roof])
	_check("pigeon_silhouette_contrast", near_gate and luminance_gate and tip_step and head_step
			and ground_gate and dark_ground_gate and patches_wear_rump and visual_only,
			("sidewalk+cream=[%s] worst luminance margin %.3f tip_step=%s head_step=%s "
			+ "ground sidewalk-asphalt=%.3f sidewalk-body=%.3f "
			+ "dark-ground head-asphalt=%.3f head-roof=%.3f rump-asphalt=%.3f rump-roof=%.3f "
			+ "patches_wear_rump=%s visual_only=%s") % [
					", ".join(distances), worst_margin, tip_step, head_step,
					sidewalk_asphalt, sidewalk_body,
					head_asphalt, head_roof, rump_asphalt, rump_roof,
					patches_wear_rump, visual_only])


## --- scenarios (T-013 juice pass) -------------------------------------------


## Counts live one-shot juice bursts by their scene file name — the shared
## `juice_effects` group carries all three looks.
func _count_effects(scene_suffix: String) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("juice_effects"):
		if is_instance_valid(node) and (node as Node).scene_file_path.ends_with(scene_suffix):
			count += 1
	return count


## A real lobbed splat fires a one-shot droplet burst at the hit point, facing
## along the surface, and cleans itself up once the payload has burnt out.
func _scenario_juice_splat_burst() -> void:
	_dropped.clear()
	await _set_up(true, Vector3(0.0, 4.0, 6.0), Vector3.ZERO) ## Clear of the bench at z −8.
	await _tap("poop")
	await _wait_frames(55) ## The drop falls ~0.78 s before contact.
	var burst: OneShotBurst = null
	for child in _ground.get_children():
		if child is OneShotBurst and child.scene_file_path.ends_with("splat_burst.tscn"):
			burst = child
	var spawned := burst != null
	var emitting := spawned and burst.emitting
	var at_hit := spawned \
			and absf(burst.global_position.x) < 0.4 \
			and absf(burst.global_position.z - 6.0) < 0.4 \
			and burst.global_position.y > 0.0 and burst.global_position.y < 0.3
	await _wait_frames(60) ## Past the 0.55 s lifetime + burnout margin.
	var cleaned := burst == null or not is_instance_valid(burst)
	_check("juice_splat_burst_fires", spawned and emitting and at_hit and cleaned,
			"spawned=%s emitting=%s at_hit=%s cleaned=%s pos=%s" % [
					spawned, emitting, at_hit, cleaned,
					burst.global_position if spawned and is_instance_valid(burst) else Vector3.INF])


## A fully-rested flap poofs feathers; a second flap while the poof throttle is
## still warm does NOT — paced flapping never featherscreens.
func _scenario_juice_feather_poof() -> void:
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	await _wait_frames(10)
	var before := _count_effects("feather_poof.tscn")
	await _tap("flap") ## Fully rested (reset_flight zeroes the clock): the hard flap poofs.
	await _wait_frames(4)
	var poofed := _count_effects("feather_poof.tscn") == before + 1
	await _wait_frames(24) ## 0.4 s: past the flap cooldown, inside feather_min_interval.
	await _tap("flap")
	await _wait_frames(4)
	var no_spam := _count_effects("feather_poof.tscn") == before + 1
	_check("juice_feather_poofs_on_hard_flap", poofed and no_spam,
			"hard flap poofed=%s, throttled re-flap stayed at %d (before %d)" % [
					poofed, _count_effects("feather_poof.tscn"), before])


## A gentle-but-real touchdown kicks up a dust puff at the feet, which then
## cleans itself up. The input is a proper glide arrival: forward speed and a
## shallow sink, so the FIRST floor contact settles (a straight vertical drop
## would skid a frame and let the slide eat the hit before the juice sees it).
func _scenario_juice_dust_puff() -> void:
	var before := _count_effects("dust_puff.tscn")
	await _set_up(true, Vector3(0.0, 2.8, 4.0), Vector3(0.0, -3.5, -8.0))
	await _await_grounded(120)
	var puffed := _count_effects("dust_puff.tscn") == before + 1 and _player.is_grounded
	await _wait_frames(55) ## Past the 0.5 s lifetime + burnout margin.
	var cleaned := _count_effects("dust_puff.tscn") == before
	_check("juice_dust_puff_on_landing", puffed and cleaned,
			"puffed=%s cleaned=%s (before %d)" % [puffed, cleaned, before])


## A touchdown shakes the camera — a tick, never full-blown — and the trauma
## decays back to dead still.
func _scenario_juice_landing_shake() -> void:
	await _set_up(true, Vector3(0.0, 3.6, 4.0), Vector3(0.0, -3.0, -9.0))
	await _await_grounded(150)
	var cam: ChaseCamera = _player.chase_camera
	var kicked := cam.trauma > 0.1 and cam.trauma <= 0.5 ## Felt, but cozy — never full trauma.
	var moved := cam.shake_offset.length() > 0.0005
	for _i in 10:
		await get_tree().physics_frame
		moved = moved or cam.shake_offset.length() > 0.0005
	await _wait_frames(180) ## 3 s of decay clears any landing shake.
	var settled := cam.trauma == 0.0 and cam.shake_offset == Vector2.ZERO
	_check("juice_landing_shake_decays", kicked and moved and settled,
			"kicked=%s (trauma %.2f) lens moved=%s settled=%s" % [
					kicked, cam.trauma, moved, settled])


## Your own scored hits, through the REAL Main scene: a combo escalation
## shakes the chase camera, pulses the HUD score line, and both settle back.
## Also checks the lighting pass actually shipped (the warm sun, and since
## T-016 capped at 1.15 energy so mid-gray albedos stop clipping to white).
func _scenario_juice_hit_shake_pulse() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	Game.high_score = 0
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(3500.0, 0.0, -3500.0) ## Own space, clear of the test world.
	add_child(main_game)
	await _wait_frames(4)
	var pigeon: Player = main_game.get_node("Player")
	var cam: ChaseCamera = pigeon.chase_camera
	var label: Label = main_game.stats_label
	var sun := main_game.get_node("Sun") as DirectionalLight3D
	var warm_sun := sun.light_color.r >= sun.light_color.g and sun.light_color.g > sun.light_color.b
	var sun_capped := sun.light_energy <= 1.15
	Game.add_tourist_hit(Vector3(3500.0, 0.5, -3500.0))
	await _wait_frames(3) ## Let _process show the ×1 before the escalation.
	Game.add_tourist_hit(Vector3(3500.0, 0.5, -3501.0))
	await _wait_frames(3) ## The escalation frame: the pulse fires, the shake lands.
	var pulsed := label.scale.x > 1.03
	var shook := cam.trauma > 0.05
	var combo_shown := label.text.contains("×2 combo")
	await _wait_frames(90) ## 1.5 s: pulse and shake have both settled.
	var settled := label.scale.is_equal_approx(Vector2.ONE) and cam.trauma == 0.0
	var scale_after: float = label.scale.x
	var trauma_after: float = cam.trauma
	var sun_energy: float = sun.light_energy ## Read before the scene frees the Sun.
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("hit_shake_and_score_pulse", pulsed and shook and combo_shown and settled and warm_sun and sun_capped,
			"pulsed=%s shook=%s combo_shown=%s settled=%s (scale %.3f trauma %.3f) warm_sun=%s sun_energy=%.2f" % [
					pulsed, shook, combo_shown, settled, scale_after, trauma_after, warm_sun, sun_energy])


## --- scenarios (T-012 audio) -------------------------------------------------


## The bus mix exists (Master · SFX · Ambience, the bed quieter than effects)
## and every sound the ticket lists loads as a real, positive-length stream;
## the two ambience beds are flagged to loop forever.
func _scenario_audio_buses() -> void:
	var buses := {}
	for i in AudioServer.get_bus_count():
		buses[AudioServer.get_bus_name(i)] = i
	var present: bool = buses.has("Master") and buses.has("SFX") and buses.has("Ambience")
	var mix_sane: bool = present \
			and AudioServer.get_bus_volume_db(buses["Ambience"]) \
					< AudioServer.get_bus_volume_db(buses["SFX"])
	var sfx_streams := true
	for sound_name in Sfx.SOUNDS:
		var stream: AudioStream = Sfx.SOUNDS[sound_name].stream
		sfx_streams = sfx_streams and stream != null and stream.get_length() > 0.05
	var beds_loop := true
	for bed_name in Sfx.AMBIENCE:
		var bed_stream: AudioStream = Sfx.AMBIENCE[bed_name].stream
		beds_loop = beds_loop and bed_stream != null and Sfx.stream_is_looping(bed_stream)
	_check("audio_buses_and_assets", present and mix_sane and sfx_streams and beds_loop,
			"buses=%s ambience_quieter=%s sfx_streams=%s beds_loop=%s" % [
					present, mix_sane, sfx_streams, beds_loop])


## T-101: the game boots MUTED — the real autoload path muted Master in this very
## process (this scenario runs under no opt-in, so Game._ready decided "mute"),
## and the opt-in contract holds as documented: PIGEON_SOUND=1 opts in, the
## pilot's PIGEON_MUTE=1 wins over everything, the `--sound` user arg opts in,
## and no opt-in stays silent. The truth table switches the process env and
## restores it, so the game boot itself is only ever sampled, never re-run.
func _scenario_audio_boots_muted() -> void:
	var master := AudioServer.get_bus_index("Master")
	var muted_at_boot: bool = AudioServer.is_bus_mute(master)
	var saved_sound := OS.get_environment("PIGEON_SOUND")
	var saved_mute := OS.get_environment("PIGEON_MUTE")
	OS.set_environment("PIGEON_SOUND", "1")
	var env_opts_in: bool = not Game.boot_muted(PackedStringArray())
	OS.set_environment("PIGEON_MUTE", "1")
	var pilot_mute_wins: bool = Game.boot_muted(PackedStringArray(["--sound"]))
	OS.set_environment("PIGEON_MUTE", saved_mute)
	OS.set_environment("PIGEON_SOUND", saved_sound)
	var arg_opts_in: bool = not Game.boot_muted(PackedStringArray(["--sound"]))
	var silent_by_default: bool = Game.boot_muted(PackedStringArray())
	_check("audio_boots_muted",
			muted_at_boot and env_opts_in and pilot_mute_wins and arg_opts_in and silent_by_default,
			"muted_at_boot=%s env_opts_in=%s pilot_mute_wins=%s arg_opts_in=%s silent_by_default=%s" % [
					muted_at_boot, env_opts_in, pilot_mute_wins, arg_opts_in, silent_by_default])


## The wing sounds ride the real flap impulses: a grounded takeoff flap whooshes
## but doesn't strain, a flap mid-climb adds the effort beat, and a flap past
## the apex (falling, not climbing) stays quiet.
func _scenario_audio_flap_effort() -> void:
	Sfx.reset_counts()
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	Sfx.reset_counts()
	await _tap("flap")
	await _wait_frames(6)
	var flap_n: int = Sfx.played_counts.get("flap", 0)
	var effort_n: int = Sfx.played_counts.get("effort", 0)
	var took_off := not _player.is_grounded
	for _i in 60: ## Still rising? Tap again — this flap comes on a real climb.
		await get_tree().physics_frame
		if _player.velocity.y > _player.effort_climb_speed:
			break
	Sfx.reset_counts()
	await _tap("flap")
	await _wait_frames(6)
	var climb_flap: int = Sfx.played_counts.get("flap", 0)
	var climb_effort: int = Sfx.played_counts.get("effort", 0)
	for _i in 120: ## Past the apex: falling now.
		await get_tree().physics_frame
		if _player.velocity.y < 0.5:
			break
	Sfx.reset_counts()
	await _tap("flap")
	await _wait_frames(6)
	var fall_flap: int = Sfx.played_counts.get("flap", 0)
	var fall_effort: int = Sfx.played_counts.get("effort", 0)
	_check("sfx_flap_effort_fires",
			flap_n == 1 and effort_n == 0 and took_off \
					and climb_flap == 1 and climb_effort == 1 \
					and fall_flap == 1 and fall_effort == 0,
			"takeoff flap=%d effort=%d off=%s · climb flap=%d effort=%d · fall flap=%d effort=%d" % [
					flap_n, effort_n, took_off, climb_flap, climb_effort,
					fall_flap, fall_effort])


## The bread peck is audible through Main's exact eat wiring (crumb.eaten →
## Player.peck): a grounded pigeon waddling into a crumb plays exactly one peck.
func _scenario_audio_peck() -> void:
	Sfx.reset_counts()
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	var crumb: BreadCrumb = CRUMB_SCENE.instantiate()
	crumb.position = Vector3(0.0, 0.16, 0.0)
	add_child(crumb)
	crumb.eaten.connect(hunger.eat)
	crumb.eaten.connect(_player.peck) ## Main's exact wiring.
	await _set_up(true, Vector3(0.0, 0.4, 1.8), Vector3.ZERO) ## Drop ahead of the crumb…
	await _await_grounded(90)
	await _wait_frames(10)
	Input.action_press("pitch_up") ## …and waddle in.
	for _i in 120:
		await get_tree().physics_frame
		if not is_instance_valid(crumb):
			break
	Input.action_release("pitch_up")
	await _wait_frames(2) ## Let the eaten flush settle.
	var ate := not is_instance_valid(crumb)
	var peck_n: int = Sfx.played_counts.get("peck", 0)
	_check("sfx_peck_plays_on_eat", ate and peck_n == 1,
			"ate=%s peck plays=%d" % [ate, peck_n])
	hunger.free()


## The city hit sounds ride the real events: a lobbed splat plays the splat and
## panics its tourist (yelp at the hit), the indignant shout joins the fist
## shake ~1.8 s later, and a car honk through the same duck-typed entry honks.
func _scenario_audio_hit_sounds() -> void:
	_dropped.clear()
	_splat_events.clear()
	Sfx.reset_counts()
	## The pigeon grounds on the plaza first, so both spawner anchors stay put.
	await _set_up(true, _city.position + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	var tourists := TouristSpawner.new()
	tourists.city = _city
	tourists.player = _player
	tourists.target_count = 1
	tourists.spawn_min_dist = 0.0
	tourists.spawn_max_dist = 10.0 ## Pin the loop to the plaza block, under the drop.
	add_child(tourists)
	var cars := CarSpawner.new()
	cars.city = _city
	cars.player = _player
	cars.target_moving = 0
	cars.target_parked = 1
	cars.spawn_min_dist = 0.0
	cars.spawn_max_dist = 10.0
	add_child(cars)
	await _wait_frames(4)
	var living := tourists.living_tourists()
	var parked := cars.living_cars()
	if living.is_empty() or parked.is_empty():
		_check("sfx_splat_yelp_panic_honk", false,
				"tourist=%d parked_car=%d" % [living.size(), parked.size()])
		tourists.free()
		cars.free()
		return
	var tourist: Tourist = living[0]
	tourist.path = PackedVector3Array() ## Freeze the target under the drop.
	await _set_up(true, tourist.global_position + Vector3(0.0, 4.0, 0.0), Vector3.ZERO)
	await _tap("poop")
	await _wait_frames(2)
	var splat_n := 0
	var yelp_n := 0
	var panic_n := 0
	for _i in 240: ## Fall (~0.75 s) + panic until the shout joins the fist shake.
		await get_tree().physics_frame
		splat_n = Sfx.played_counts.get("splat", 0)
		yelp_n = Sfx.played_counts.get("yelp", 0)
		panic_n = Sfx.played_counts.get("panic", 0)
		if splat_n >= 1 and yelp_n >= 1 and panic_n >= 1:
			break
	var panicked := tourist.mood == Tourist.Mood.PANIC or tourist._shouted
	Sfx.reset_counts()
	parked[0].on_splatted(Vector3(0.0, -5.0, 0.0)) ## The same duck-typed entry a dropping calls.
	await _wait_frames(2)
	var honk_n: int = Sfx.played_counts.get("honk", 0)
	_check("sfx_splat_yelp_panic_honk",
			splat_n == 1 and yelp_n == 1 and panic_n == 1 and panicked and honk_n == 1
					and parked[0].honk_count == 1,
			"splat=%d yelp=%d panic=%d (panicking=%s) honk=%d car_honks=%d" % [
					splat_n, yelp_n, panic_n, panicked, honk_n, parked[0].honk_count])
	tourists.free()
	cars.free()


## The city bed loops under the real game: main.tscn starts both beds on the
## Ambience bus, start_ambience() is idempotent (a restart never stacks beds),
## and the bed lives in the autoload — it survives the scene being torn down.
func _scenario_ambience_bed() -> void:
	Sfx.stop_ambience() ## Known-silent starting state.
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(2500.0, 0.0, -2500.0) ## Own space, clear of the test world.
	add_child(main_game)
	await _wait_frames(4)
	var started := Sfx.ambience_playing
	var on_bus := true
	var all_playing := true
	for player in Sfx.ambience_players():
		on_bus = on_bus and player.bus == &"Ambience"
		all_playing = all_playing and player.playing
	var bed_count := Sfx.ambience_players().size()
	Sfx.start_ambience() ## Idempotent: the restart path calls it again.
	var no_duplicates: bool = Sfx.ambience_players().size() == bed_count
	main_game.free()
	var survives := Sfx.ambience_playing
	Sfx.stop_ambience()
	_check("ambience_loops_under_game",
			started and on_bus and all_playing and no_duplicates and survives,
			"started=%s on_bus=%s playing=%s idempotent=%s survives_scene_free=%s (%d beds)" % [
					started, on_bus, all_playing, no_duplicates, survives, bed_count])


## --- scenario (T-018 performance budget) ------------------------------------


## The calibrated absolute CPU budget for one physics frame at full density:
## median wall-time of a 100-frame window must stay under this many ms.
## CALIBRATED, not predicted — the number comes from the headless run of this
## very scenario on the dev machine: median 247.5 ms (spread 233.7-264.2) per
## 100 frames at full density; the budget is ~3x that, rounded up, so only
## gross regressions trip it. See docs/tickets/T-018 for the table.
const DENSITY_BUDGET_MS_PER_100_FRAMES := 750.0


## Full-density CPU budget (T-018): the REAL main scene — city, 18 tourists,
## 36 cars, bread, pigeon — must keep the calibrated headless CPU cost per
## physics frame. Headless renders nothing, so this gates the CPU half of the
## frame (scripts + physics + scene); draw calls and primitives stay with
## Gate 2's autoplay DONE line and Gate 3's human pass (VERIFICATION.md).
## Method: Main parked in its own space, the pigeon on a synthetic level
## cruise above the spawn corridor — velocity RE-IMPOSED at every window
## start, because the flight model bleeds speed and would otherwise mix
## cruise, stall and grounded states into the windows — 120 warm-up frames,
## then three 100-frame wall-time windows under --fixed-fps 60 (headless runs
## unthrottled, so wall time IS the CPU cost). Absolute and machine-relative:
## a busy machine can false-FAIL this gate (rerun when idle); a generous
## budget means percent-level drift passes by design.
func _scenario_density_cpu_budget() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	_main_game = MAIN_SCENE.instantiate()
	## Own space: clear of the test world at the origin, the harness city at
	## (2000, 0, 2000) and every other instanced Main offset in this file.
	_main_game.position = Vector3(-3500.0, 0.0, 3500.0)
	add_child(_main_game)
	await _wait_frames(4) ## City builds; spawners seed the band around the corridor.
	var main_game: MainGame = _main_game
	var city: City = main_game.city
	var pigeon: Player = main_game.player
	## Level cruise 22 m up — above every roof (generation caps them under
	## 20 m) and high enough that no window can reach the ground. reset_flight
	## takes LOCAL coordinates (player.gd:108), exactly why main.gd:60 wraps
	## the global spawn point in city.to_local().
	var cruise_pos := city.to_local(city.spawn_point) + Vector3(0.0, 22.0, 0.0)
	var cruise_vel := Vector3(0.0, 0.0, -18.0)
	pigeon.reset_flight(cruise_pos)
	pigeon.velocity = cruise_vel
	await _wait_frames(120) ## Warm-up: broadphase, materials, first-frame allocations.
	var windows: Array[float] = []
	for _w in 3:
		pigeon.reset_flight(cruise_pos)
		pigeon.velocity = cruise_vel
		await _wait_frames(2) ## Settle the teleport before the clock starts.
		var t0 := Time.get_ticks_usec()
		await _wait_frames(100)
		windows.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	windows.sort()
	var median_ms: float = windows[1]
	## The gate must measure what it claims: a half-seeded city would pass a
	## budget it does not deserve.
	var tourists: Array[Tourist] = main_game.tourist_spawner.living_tourists()
	var cars: Array[Car] = main_game.car_spawner.living_cars()
	var density_ok := tourists.size() == main_game.tourist_spawner.target_count \
			and cars.size() == main_game.car_spawner.target_moving \
					+ main_game.car_spawner.target_parked
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var phys_active := Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	print("SIM DATA density_cpu_budget: windows ms %.1f/%.1f/%.1f, median %.1f ms per 100 physics frames (budget %.0f), nodes %d, physics-active %d, tourists %d, cars %d" % [
			windows[0], windows[1], windows[2], median_ms,
			DENSITY_BUDGET_MS_PER_100_FRAMES, nodes, phys_active,
			tourists.size(), cars.size()])
	_check("density_cpu_budget",
			median_ms > 0.0 and median_ms <= DENSITY_BUDGET_MS_PER_100_FRAMES and density_ok,
			"median %.1f ms per 100 frames vs budget %.0f, density_ok=%s (tourists %d, cars %d)" % [
					median_ms, DENSITY_BUDGET_MS_PER_100_FRAMES, density_ok,
					tourists.size(), cars.size()])
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	main_game.free()
	_main_game = null


## --- scenario (T-036 off-world fall guard) ----------------------------------


## A fall past the world's edge must not fall forever: below `off_world_y` the
## reset fires EXACTLY once, snaps the pigeon to `respawn_point`, and it lands
## grounded there within ~2 s — while the hunger clock keeps draining straight
## through the teleport (the fail state stays hunger-only). No oscillation over
## the following ~2 s: the corridor sits far inside the world, so a second fire
## would mean the respawn point itself is off-world. The standalone harness
## player has no city, so the scenario points `respawn_point` at a known spot
## over the flat test ground itself — mirroring what Main wires in.
func _scenario_off_world_fall_returns_home() -> void:
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	_player.respawn_point = Vector3(0.0, 0.4, 0.0) ## The spawn-drop height over the flat test ground.
	## The harness player is shared across scenarios and T-042's
	## `off_world_fall_respawns` (which runs earlier) already fired the guard
	## once — zero the counter so this window asserts its OWN exactly-one fire.
	_player.off_world_resets = 0
	var home: Vector3 = _player.respawn_point
	var hunger0: float = hunger.value
	## Below the guard (−5) AND past where any floor exists (the test ground
	## ends at ±100): without the guard the pigeon falls forever from here.
	await _set_up(true, Vector3(0.0, -10.0, -400.0), Vector3.ZERO)
	var grounded_home := false
	for _i in 120: ## ~2 s to fire the guard and land the short spawn drop.
		await get_tree().physics_frame
		if _player.is_grounded and _player.position.distance_to(home) < 1.0:
			grounded_home = true
			break
	var fired_once := _player.off_world_resets == 1
	var landed := _player.is_grounded
	## No oscillation: two more seconds parked home — the counter must not move.
	await _wait_frames(120)
	var stable := fired_once and grounded_home and _player.is_grounded \
			and _player.position.distance_to(home) < 1.0 \
			and _player.off_world_resets == 1
	var hunger_loss: float = hunger0 - hunger.value
	var finite := _player.velocity.is_finite() and _player.position.is_finite()
	var at_rest := _player.velocity.length() < 1.0
	hunger.free()
	_check("off_world_fall_returns_home",
			fired_once and grounded_home and landed and stable and hunger_loss > 0.2
					and finite and at_rest,
			"counter=%d grounded_home=%s stable=%s hunger lost %.2f, rest %.2f m/s at %s (finite=%s)" % [
					_player.off_world_resets, grounded_home, stable, hunger_loss,
					_player.velocity.length(), _player.position, finite])

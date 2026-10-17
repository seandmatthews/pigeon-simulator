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
const POOP_RETICLE_SCENE: PackedScene = preload("res://scenes/poop_reticle.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/menu.tscn")
const TOUCH_SCENE: PackedScene = preload("res://scenes/touch_controls.tscn") ## (T-119) Driven with synthetic screen contacts, never by poking its methods.

## (T-119) The shipped non-builtin InputMap set. The touch layer must add
## NOTHING — `touch_layer_desktop_inert` reads the live InputMap against this
## list so a smuggled-in action fails the gate the same night it lands.
const GAME_ACTIONS: Array[String] = [
	"flap", "poop", "pitch_up", "pitch_down", "turn_left", "turn_right",
	"boost", "pause", "restart", "to_menu", "quit",
]

## The Game autoload's high score file is redirected here for the scoring
## scenarios, so a sim run never touches the real record in user://.
const SIM_SAVE_PATH := "user://sim_highscore.cfg"
const SIM_SETTINGS_PATH := "user://sim_settings.cfg" ## (T-122) Same isolation rule as the high score.

## (T-015) Forward-speed ceiling four paced ground flaps may pump. Measured
## 25.04 m/s under the tapered flap (fixed-fps sim); the old fixed 45° flap
## reached 28.7 m/s at THREE flaps and rode the 30 cap at four, so 26.0 both
## passes the new model with margin and fails the old one.
const FLAP_PUMP_CEIL := 26.0

## (T-083) The pitch attitude bound: `pitch_auth_zero_deg` — |body pitch| may
## never cross this under held pitch-up input. The balloon-outcome bars below
## are taken from the PRE-FIX tree's own measured run (red-before /
## green-after, both runs recorded in the ticket): peak climb vy 8.85 m/s and
## post-release mush 247/300 frames before the falloff — 8.48 and 240 after
## it. Note the pitch assert itself reads 79.9° on the pre-fix tree (green at
## the 85° bar — the authority decay from bleeding forward speed slows the
## rotation well below the naive 2.2 rad/s × 50 frames ≈ 105°); the
## scenario's red-before comes from the balloon bars.
const PITCH_BOUND_DEG := 85.0
const BALLOON_VY_BAR := 8.7 ## Pre-fix measured 8.85 (fails), post-fix 8.48 (passes).
const BALLOON_MUSH_BAR := 244 ## Pre-fix measured 247 (fails), post-fix 240 (passes).

## (T-082) The hands-off trim scenario's re-derived bars. The originally drafted
## "< 3 deg at 90 frames" end bar was flagged by the backlog audit as
## mechanistically unfounded and is RE-DERIVED from the measured runs, not
## weakened to pass: the released glide sits at an angle-of-attack equilibrium —
## gap* = g_softened / (v · (velocity_align_rate + trim_rate)) — that only drops
## under 3 deg at fully settled cruise speed, and the balloon the release
## induces bleeds 17 → ~11.7 m/s, an ~10 s recovery the 1.5 s window cannot
## out-run (measured at trim_rate 0.7: end angle −5.72 deg; at 0.5/1.0/3.0:
## −6.50/−5.26/−3.16 — no rate reaches 3 deg; cutting velocity_align_rate 3.5 →
## 1.5 leaves it at −7.2 because the flow then droops away faster). The honest
## convergence contract at the landed trim_rate 0.7: the nose — FROZEN at 15.6
## deg on the pre-fix tree for the whole window while the end angle diverges
## −6.95 → −10.4 by f145 — must measurably ease toward the flow (measured
## travel 15.5 → 11.0 deg = 4.5) and the end angle must stay bounded under the
## pre-fix tree's own measured divergence point (6.95). The tail of the angle
## widens slowly at every rate while speed recovers, so a "final 30 frames
## approach the flow" arm is not usable; nose travel is the monotone arm — the
## trim is the only air-frame rotator without input, so zero travel is the
## structural pre-fix signature.
const HSO_END_ANGLE_BAR := 8.4 ## |End nose-to-flow signed angle| bound: measured 5.72 at trim_rate 0.7 pre-T-117 (bar 7.0), re-derived ×1.2 for T-117 — the ×1.2 pitch rate deepens the 8-frame entry (14.54° → 17.35°) and the 90-frame window cannot out-run the deeper residual (measured 7.59); a settle probe showed the trim still converges to the same ≈5° equilibrium by 360 frames (−7.59 @90 → −11.13 @180 → −4.82 @360), so the bar tracks the window-relative residual, not a moved equilibrium. The trim_rate 0.7 physics is untouched by T-117.
const HSO_NOSE_TRAVEL_BAR := 2.5 ## Min nose-pitch travel (deg) toward the flow over the window: measured 4.5 at trim_rate 0.7; pre-fix measured 0.0 (the attitude freeze — the red-before signature).

## (T-081) The mush-exit bars, verbatim from the ticket: over a 240-frame
## hands-off window from the 0.29-rad nose-up attitude at fwd 6.6, the pigeon
## must lose real height and reach a real sink. Measured runs recorded in the
## ticket: the pre-fix tree hovers near the aligner's zero-sink equilibrium
## (RED), the lift-keyed cut lets the fall develop (GREEN).
const MUSH_DY_BAR := -3.0 ## Min height lost (m) over the 240-frame window.
const MUSH_MIN_VY_BAR := -2.0 ## Most-negative vy (m/s) the window must reach.

## (T-029) The plaza-anchor drop offset: the plaza-anchor scenarios ground the
## pigeon ON the plaza but no longer AT its center — the T-029 landmark plinth
## stands there now. The offset puts the drop 5.0 m out from the center: clear
## of the 2.4 m plinth footprint (1.70 m half-diagonal) and — the bins pushed
## outside the 8 m bench ring by T-104, to (±7.0, ±7.0) — 5.0 m clear of the
## nearest diagonal bin. The anchor's meaning is "grounded on the plaza (block
## under the center)", not "at the exact center".
const PLAZA_DROP_OFFSET := Vector3(4.0, 0.0, 3.0)

## Set SIM_DEBUG=1 to print per-scenario trajectory samples.
var _debug: bool = OS.get_environment("SIM_DEBUG") == "1"

var _player: Player
var _city: City
var _ground: StaticBody3D ## The flat test-world floor — poop splat scenarios assert hits on it.
var _failures: int = 0
var _game_over_fires: int = 0 ## Signal counters survive inside lambdas only as members.
var _hunger_changed_fires: int = 0 ## (T-075) Storm counter for hunger_game_over_once — member for the same reason.
var _dropped: Array[Poop] = [] ## Poops the test player released (T-006).
var _splat_events: Array[Dictionary] = [] ## {target, velocity} per splatted hit of the poop under test.
var _tourist_relay: int = 0 ## tourist_splatted relays caught from the spawner under test (T-007).
var _car_relay: int = 0 ## car_splatted relays caught from the spawner under test (T-008).
var _score_events: Array[Dictionary] = [] ## hit_scored payloads caught from the Game autoload (T-009).
var _crumb_favor_events: Array[int] = [] ## (T-114) crumb_favor relays caught from the spawner under test.
var _favor_delta_events: Array[int] = [] ## (T-115) favor_changed deltas caught from the Game autoload.
var _favor_maxed_fires: int = 0 ## (T-115) favor_maxed emissions caught from the Game autoload — signal counters survive inside lambdas only as members.
var _main_game: MainGame ## The real main.tscn instance the T-010 flow scenarios share.
var _bread_shared: Array[Dictionary] = [] ## bread_shared relays caught from the elder spawner under test (T-020).
var _regen_relay: int = 0 ## regenerated relays caught from the city under restart (T-033) — signal counters survive inside lambdas only as members.
var _off_world_signal_fires: int = 0 ## `off_world_reset` emissions caught in the T-036 scenario (T-095) — same member rule as `_regen_relay`.
var _return_signal_fires: int = 0 ## (T-087) `off_world_reset(from)` emissions caught in the return-beat scenario — same member rule.
var _return_signal_from: Vector3 ## (T-087) The departure position carried by the last caught emission.
var _touch_flap_events: int = 0 ## (T-119) `flapped` relays caught for the touch-button/multitouch scenarios — member so lambda handlers can count.


func _ready() -> void:
	## Redirect the Game autoload's high-score file for the WHOLE run: several
	## scenarios score real hits through it, and none of them may ever touch
	## the player's actual record in user://highscore.cfg.
	Game.save_path = SIM_SAVE_PATH
	Game.settings_path = SIM_SETTINGS_PATH ## (T-122) Settings never touch the real file either.
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
	await _scenario_sustained_flap_ceiling()
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
	await _scenario_pitch_attitude_bounded() ## T-083 — held pitch-up caps out near vertical instead of stacking past it.
	await _scenario_hands_off_glide_trims() ## T-082 — a released pitch input trims the nose onto the velocity vector instead of freezing it.
	await _scenario_hands_off_mush_exits() ## T-081 — a slow nose-high hands-off mush falls into a sink instead of hovering at the aligner's equilibrium.
	await _scenario_stall_falls_develops() ## T-081/T-061 — a stalled climb develops a real fall within ~0.75 s of the stall flag.
	await _scenario_loop_over_top_roll_recovers() ## T-106 — the owner's loop repro leaves no persistent roll cant, and the landing stands level with its heading kept.
	await _scenario_off_world_fall_respawns() ## T-042 — flight-model guard: the void past the apron walks home.
	await _scenario_edge_nudge_turns_home() ## T-023 — the prevention layer ahead of the guard: past the apron the course bends home.
	await _scenario_city_layout()
	await _scenario_city_plaza()
	await _scenario_city_street_flyover()
	await _scenario_city_roof()
	await _scenario_city_sidewalk()
	await _scenario_city_district_palettes()
	await _scenario_city_facades_fit_floors() ## T-049 — after the palettes, same standing-city audit shape.
	await _scenario_city_footprints_vary() ## T-051 — after the facades, same audit shape; leaves the default city standing.
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
	await _scenario_poop_ball_visible() ## T-086 — the drop reads from the chase cam: bigger emissive ball; collider re-pinned to 0.30 by T-060.
	await _scenario_reticle_frozen_pin_matches_damped_fall() ## T-105 — bare rig, direct instantiation, no Main alive.
	await _scenario_reticle_main_lifecycle() ## T-105 — real-Main rig, the T-077 parked pattern.
	await _scenario_reticle_live_refresh_lock() ## T-110 — the tuned live cadence, bare-rig value lock.
	await _scenario_poop_ready_indicator_tracks_cooldown() ## T-077 — unpaused tree, no live Main, like the poop block.
	await _scenario_coach_hint_shows_until_first_hit() ## T-060 — after the T-077 rig: owns one instanced Main in its own space, leaves the stretch as it found it.
	await _scenario_tourists_walk()
	await _scenario_tourist_splat()
	await _scenario_poop_hits_tourist_within_lead_window() ## T-060 — the lead shot with the stroll ALIVE, beside the frozen-target splat.
	await _scenario_tourist_buzz()
	await _scenario_tourists_recycle()
	await _scenario_cars_traffic()
	await _scenario_car_splat_honk()
	await _scenario_traffic_recycle_keeps_flow() ## T-089 — the recycle insertion path must not clot a ring.
	await _scenario_cars_recycle() ## T-054 — the end-to-end timer-driven car recycle closes its contract.
	await _scenario_citizen_classes_spawn_deterministic() ## T-113 — the class multiset is a seeded law on both rigs.
	await _scenario_citizen_classes_readable() ## T-113 — the uniform reads: pairings, props, flags, contrast.
	await _scenario_civilian_palette_reserved() ## T-121 — the reservation law + the grown flag, bare value pins.
	await _scenario_splat_favor_follows_citizen_class() ## T-114 — the favor book pays through the real main scene's chain.
	await _scenario_elder_bread_gates_on_favor() ## T-114 — the elder share gates on the favor balance, staged at setup.
	await _scenario_bread_steal_favor_deltas() ## T-114 — the steal surfaces over a real city, tailgates included.
	await _scenario_favor_max_ends_run_victory() ## T-115 — the ceiling ends the run as a victory through the real main scene; starvation coexists in one Main.
	await _scenario_favor_meter_names_the_ceiling() ## T-116 — the meter reads against the ceiling and the caption row states the win.
	await _scenario_scoring_values()
	await _scenario_high_score_persists()
	await _scenario_highscore_save_throttled() ## T-073 — directly after the persists scenario: same unpaused tree, no live Main.
	await _scenario_favor_max_book_clamps_and_flushes() ## T-115 — directly after the throttle: same bare-autoload window, the victory flush is its twin.
	await _scenario_score_popup()
	await _scenario_pause_freezes()
	await _scenario_title_escape_does_not_quit() ## T-097 — Esc at the title must not hard-quit.
	await _scenario_game_over_screen()
	await _scenario_restart_resets()
	await _scenario_restart_same_seed_skips_rebuild()
	await _scenario_hud_bread_pointer_tracks_nearest_crumb() ## T-037, re-armed by T-111 — T-019 window: unpaused tree, no live Main.
	await _scenario_hud_hunger_tiers() ## T-019 — must follow the restart scenarios: unpaused tree, no live Main.
	await _scenario_combo_strip_reports_last_hit() ## T-040 — same T-019 window: unpaused tree, no live Main.
	await _scenario_combo_note_on_landing() ## T-079 — same T-019 window: unpaused tree, no live Main.
	await _scenario_pause_menu_shows_controls() ## T-099 — same T-019 window: unpaused tree, no live Main.
	await _scenario_touch_layer_desktop_inert() ## T-119 — the desktop/headless path is byte-unchanged: hidden layer, zero safe-area offsets, no new actions.
	await _scenario_touch_stick_drives_action_axes() ## T-119 — a synthetic screen-drag steers the pigeon through the polled axes, analog included.
	await _scenario_touch_stick_rest_reads_exactly_zero() ## T-119 — touch end zeroes all four steering actions; the T-082 trim arm survives.
	await _scenario_touch_buttons_fire_real_actions() ## T-119 — the Flap/Poop TouchScreenButtons fire the real actions (a drop actually falls).
	await _scenario_touch_pause_button_toggles_real_pause() ## T-119 — the Pause button pauses through the REAL PauseMenu; the panel's Resume tap unpauses.
	await _scenario_touch_multitouch_steer_and_flap() ## T-119 — overlapping contacts: the held stick stays live while a second finger flaps.
	await _scenario_title_screen_teaches_controls() ## T-039 — same T-019 window: unpaused tree, no live Main.
	await _scenario_elder_placement_no_rng()
	await _scenario_elder_shares_bread_after_hangout()
	await _scenario_elder_no_bread_airborne()
	await _scenario_elder_cooldown_blocks_second_share()
	await _scenario_city_cafe_tables() ## T-031 — after the elder block, same rig pattern.
	await _scenario_city_roofs_inhabited() ## T-032 — after the cafe block, same audit pattern.
	await _scenario_bread_distribution_weighted() ## T-112 — the weighted spread over a real city.
	await _scenario_city_crosswalks() ## T-069 — after the roofs block, same audit pattern.
	await _scenario_city_apron_rim() ## T-088 commit 1 — after the crosswalks block, same audit pattern.
	await _scenario_city_horizon_skyline() ## T-088 commit 2 — after the rim, same audit pattern.
	await _scenario_city_park_trees() ## T-030 — after the skyline, same audit pattern.
	await _scenario_city_plaza_landmark() ## T-029 — after the park trees, same audit chain.
	await _scenario_city_plaza_props_clear() ## T-104 — after the plaza landmark, same audit chain.
	await _scenario_city_district_anchors() ## T-091 — after the plaza landmark, same audit chain.
	await _scenario_pigeon_air_poses()
	await _scenario_pigeon_ground_poses()
	await _scenario_pigeon_peck()
	await _scenario_pigeon_realistic_visual()
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
	await _scenario_settings_persist_and_invert() ## T-122 — after the audio block: it touches the buses and restores them.
	await _scenario_sfx_coos_and_stingers() ## T-123 — the new voice: coos, the smug parity, and both stingers.
	await _scenario_boot_splash_pinned() ## T-125 — no Godot logo, splash = the title navy.
	await _scenario_density_cpu_budget()
	await _scenario_off_world_fall_returns_home() ## T-036 — last: bends _player.respawn_point for its own window.
	await _scenario_off_world_return_beat() ## T-087 — after its bare-harness sibling: owns one instanced Main in its own space.
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


## The player's flat heading (radians): atan2 over the level-projected forward,
## the same read `reset_flight`'s yaw convention and the chase rig's target use.
func _flat_yaw() -> float:
	var fwd := -_player.transform.basis.z
	return atan2(-fwd.x, -fwd.z)


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


## (T-043) The pacing ceiling: TWELVE paced flaps from the ground — the takeoff
## cadence, 24-frame waits keeping every flap fully rested — must converge
## below the pump ceiling instead of riding toward `max_speed`. The convergence
## only shows after ~12 flaps (the envelope scenario's 4-flap pump leg cannot
## see it), so the peak forward speed is tracked through the whole cadence AND
## a 3 s no-input coast: neither a mid-cadence spike nor the arc-over's
## speed conversion may duck under the bar.
func _scenario_sustained_flap_ceiling() -> void:
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO)
	var peak_fwd := 0.0
	for _i in 12:
		await _tap("flap")
		await _wait_frames(24)
		peak_fwd = maxf(peak_fwd, _player.forward_speed)
		_dbg("sustained flap %d: fwd=%.2f y=%.2f" % [
				_i + 1, _player.forward_speed, _player.position.y])
	for _i in 180: ## 3 s no-input coast through the arc-over.
		await get_tree().physics_frame
		peak_fwd = maxf(peak_fwd, _player.forward_speed)
	var finite := _player.velocity.is_finite()
	_dbg("sustained: peak_fwd=%.2f end speed=%.2f end y=%.2f" % [
			peak_fwd, _player.velocity.length(), _player.position.y])
	_check("sustained_flap_ceiling", peak_fwd < FLAP_PUMP_CEIL and finite,
			"12 paced flaps peaked %.2f m/s fwd (ceil %.1f), finite=%s" % [
					peak_fwd, FLAP_PUMP_CEIL, finite])


## At cruise speed, lift must noticeably soften gravity: a 1.5 s glide sinks
## far less than free fall would.
func _scenario_lift() -> void:
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _wait_frames(90)
	var sink := 20.0 - _player.position.y
	print("SIM DATA lift_softens_gravity: sank %.2f m in 90 frames at 12 m/s" % sink) ## (T-081) margin evidence
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
	print("SIM DATA dive_gains_speed: speed %.2f->%.2f m/s, height %.2f->%.2f m" % [s0, s1, y0, y1]) ## (T-081) margin evidence
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
	print("SIM DATA pullup_gains_height: peak %+.2f m above pull-start, speed at peak %.2f (pull-start speed %.2f)" % [peak_y - y1, peak_speed, s1]) ## (T-081) margin evidence
	_check("pullup_gains_height", peak_y > y1 + 2.0 and peak_speed < s1 - 3.0,
			"peak %.1f m vs pull-start %.1f m, speed %.1f->%.1f at peak" % [peak_y, y1, s1, peak_speed])


## A held turn must bank the body and yaw with the bank (left turn: right wing
## up, nose swings toward -X).
func _scenario_banking() -> void:
	await _set_up(true, Vector3(0.0, 15.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _hold("turn_left", 60)
	var fwd := -_player.transform.basis.z
	var right_wing := _player.transform.basis.x.y
	_dbg("banked: fwd (%.2f, %.2f, %.2f), right wing y %.2f" % [fwd.x, fwd.y, fwd.z, right_wing])
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
	print("SIM DATA stall_drops: stall sank %.2f m vs glide %.2f m, min nose %.2f" % [stall_sink, glide_sink, min_nose]) ## (T-081) margin evidence
	_check("stall_drops", stall_sink > 5.0 and stall_sink > 2.5 * glide_sink and min_nose < -0.2,
			"stall sank %.1f m vs glide %.1f m, min nose pitch %.2f" % [stall_sink, glide_sink, min_nose])
	await _tap("flap")
	await _wait_frames(30)
	var speed := _player.velocity.length()
	_dbg("stall recovers: speed %.2f m/s (bar > 5.0)" % speed)
	print("SIM DATA stall_recovers: speed %.2f m/s after recovery flap" % speed) ## (T-081) margin evidence
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
	print("SIM DATA waddles_on_ground: landed=%s walked %.2f m at %.2f m/s horizontal" % [
			landed, walked.length(), hspeed]) ## (T-106) margin evidence
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
	_dbg("hard landing: min y %.2f (bar > 0.1), rest %.2f m/s (bar < 0.8)" % [
			min_y, _player.velocity.length()])
	print("SIM DATA hard_landing_skids: min y %.2f, rest %.2f m/s" % [min_y, _player.velocity.length()]) ## (T-081) margin evidence
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
	print("SIM DATA trim_glide_lands_clean: arrival %.2f m/s, %d air floor frames, settled %.2f m/s" % [first_air_floor_speed, air_floor_frames, settle_speed]) ## (T-081) margin evidence
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


## (T-083) A held pitch-up can no longer stack degrees without limit: from a
## settled cruise glide, 50 frames (0.83 s) of held pitch-up must keep |body
## pitch| at or under `pitch_auth_zero_deg` (85°) on EVERY frame of the hold
## and for 30 frames after release — the falloff asymptotes the nose just
## under the zero-authority line instead of walking it toward vertical
## (measured: the pre-fix tree walked this exact hold to 79.9° and froze the
## nose there; with the falloff it tops out at 70.7°, real margin under the
## line). The same scenario bounds the balloon outcome: peak climb rate (vy)
## during the hold and post-release mush time (frames with |vy| < 1 m/s over
## a 5 s window) stay under bars taken from the pre-fix tree's measured run —
## red-before / green-after, both measured runs recorded in the ticket.
func _scenario_pitch_attitude_bounded() -> void:
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -17.0))
	await _wait_frames(30) ## Settle into the trim glide.
	var max_pitch_deg := 0.0
	var peak_vy := -INF
	Input.action_press("pitch_up")
	for _i in 50:
		await get_tree().physics_frame
		max_pitch_deg = maxf(max_pitch_deg,
				absf(rad_to_deg(asin(clampf((-_player.transform.basis.z).y, -1.0, 1.0)))))
		peak_vy = maxf(peak_vy, _player.velocity.y)
	Input.action_release("pitch_up")
	for _i in 30:
		await get_tree().physics_frame
		max_pitch_deg = maxf(max_pitch_deg,
				absf(rad_to_deg(asin(clampf((-_player.transform.basis.z).y, -1.0, 1.0)))))
	var mush_frames := 0
	for _i in 300:
		await get_tree().physics_frame
		if absf(_player.velocity.y) < 1.0:
			mush_frames += 1
	var finite := _player.velocity.is_finite()
	_dbg("pitch bound: max |pitch| %.1f deg, peak vy %.2f m/s, mush %d/300 frames" % [
			max_pitch_deg, peak_vy, mush_frames])
	_check("pitch_attitude_bounded",
			max_pitch_deg <= PITCH_BOUND_DEG and peak_vy < BALLOON_VY_BAR
					and mush_frames < BALLOON_MUSH_BAR and finite,
			"max |pitch| %.1f deg (bar %.0f), peak vy %.2f m/s (bar %.1f), mush %d/300 frames (bar %d), finite=%s" % [
					max_pitch_deg, PITCH_BOUND_DEG, peak_vy, BALLOON_VY_BAR,
					mush_frames, BALLOON_MUSH_BAR, finite])


## (T-082) Releasing pitch input must hand the nose a hands-off trim toward the
## velocity vector, not freeze the deck angle: from a settled cruise glide (the
## flap_speed_envelope leg 2 recipe), a short 8-frame pitch-up hold genuinely
## displaces the nose off the flow (> 10° at release — the hold sits inside
## pitch_auth_full_deg's 50° band where the T-083 fade is still 1.0, so the
## displacement happens at the raw pitch_speed rate), and 90 frames (1.5 s) of
## hands-off flight show the trim owning the nose: it eases measurably toward
## the flow (bar HSO_NOSE_TRAVEL_BAR; the pre-fix tree freezes it — 0.0 travel)
## and the signed nose-to-flow angle stays bounded (HSO_END_ANGLE_BAR, derived
## from the measured runs above — the audit-flagged "< 3°" original bar was
## re-derived, not weakened; red-before / green-after with both measured runs
## recorded in the ticket. T-117 re-derived the bar ×1.2 again when the faster
## pitch rate deepened the entry the window cannot out-run — provenance on the
## const).
func _scenario_hands_off_glide_trims() -> void:
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -17.0))
	await _wait_frames(30) ## Settle into the trim glide.
	await _hold("pitch_up", 8)
	var nose0_deg := rad_to_deg(asin(clampf((-_player.transform.basis.z).y, -1.0, 1.0)))
	var start_deg := rad_to_deg((-_player.transform.basis.z).angle_to(_player.velocity.normalized()))
	await _wait_frames(90) ## Hands off: every input released.
	var nose1_deg := rad_to_deg(asin(clampf((-_player.transform.basis.z).y, -1.0, 1.0)))
	var travel_deg := nose0_deg - nose1_deg ## Positive = the nose dropped toward the flow below it.
	var end_signed_deg := rad_to_deg((-_player.transform.basis.z).signed_angle_to(
			_player.velocity.normalized(), Vector3.RIGHT))
	var finite := _player.velocity.is_finite()
	_dbg("hands-off: start %.2f deg off the flow, nose %.2f -> %.2f deg, end signed %.2f deg, speed %.2f, y %.2f" % [
			start_deg, nose0_deg, nose1_deg, end_signed_deg, _player.velocity.length(),
			_player.position.y])
	print("SIM DATA hands_off_glide_trims: start %.2f deg, nose travel %.2f deg, end signed %.2f deg" % [
			start_deg, travel_deg, end_signed_deg])
	_check("hands_off_glide_trims",
			start_deg > 10.0 and travel_deg >= HSO_NOSE_TRAVEL_BAR
					and absf(end_signed_deg) <= HSO_END_ANGLE_BAR and finite,
			"start %.2f deg off the flow (bar > 10), nose travel %.2f deg (bar >= %.1f), end signed %.2f deg (bar <= %.1f), finite=%s" % [
					start_deg, travel_deg, HSO_NOSE_TRAVEL_BAR, end_signed_deg,
					HSO_END_ANGLE_BAR, finite])


## (T-081) A slow, nose-high hands-off mush must FALL, not hover: at the mush
## equilibrium (fwd ~6.6, lift only ~0.39, `stalled` still false) the full-rate
## velocity-align slerp preserves |v| while bending the tiny sink back along
## the nose every frame, so gravity never accumulates — the sweep-2 trace held
## ~168 s of near-zero sink drifting off the map. Tipping the nose up 0.29 rad
## from a 6.6 m/s level glide (the positive-pitch convention `_level_attitude`
## counters) and going hands-off for a 240-frame budget must lose real height
## (Δy <= MUSH_DY_BAR) and reach a real sink (min vy <= MUSH_MIN_VY_BAR):
## the lift-deficiency cut on the aligner is what lets the sink develop.
## Red-before / green-after with both measured runs recorded in the ticket.
func _scenario_hands_off_mush_exits() -> void:
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(0.0, 0.0, -6.6))
	_player.rotate_object_local(Vector3.RIGHT, 0.29) ## Nose up — the mush attitude.
	var y0 := _player.position.y
	var min_vy := 0.0
	var min_nose := 0.0
	for _i in 240:
		await get_tree().physics_frame
		min_vy = minf(min_vy, _player.velocity.y)
		min_nose = minf(min_nose, (-_player.transform.basis.z).y)
	var dy := _player.position.y - y0
	var finite := _player.velocity.is_finite() and _player.position.is_finite()
	_dbg("mush exit: dy %.2f m, min vy %.2f m/s, min nose %.2f, fwd end %.2f, stalled end %s" % [
			dy, min_vy, min_nose, _player.forward_speed, _player.stalled])
	print("SIM DATA hands_off_mush_exits: dy %.2f m, min vy %.2f m/s, min nose %.2f rad" % [
			dy, min_vy, min_nose])
	_check("hands_off_mush_exits", dy <= MUSH_DY_BAR and min_vy <= MUSH_MIN_VY_BAR and finite,
			"lost %.2f m over 240 frames (bar <= %.1f), min vy %.2f m/s (bar <= %.1f), finite=%s" % [
					dy, MUSH_DY_BAR, min_vy, MUSH_MIN_VY_BAR, finite])


## (T-081, landing T-061's scenario) A stalled climb must develop a real fall:
## ballooning a settled climb into the stall (45 frames of held pitch-up) and
## waiting for `stalled == true` with a frame budget, the sink must reach
## vy <= -6.0 within 45 further frames — the below-stall fall the lift-
## deficiency key must not weaken (at fwd < stall_speed the deficiency is 1.0,
## so the cut there runs at `mush_align_fraction` — deeper than the stall-depth
## key T-061 proposed). Red-before / green-after with frames-to-fall recorded
## in the ticket; the premise is that today's tree hovers.
func _scenario_stall_falls_develops() -> void:
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -15.0))
	await _hold("pitch_up", 45) ## Balloon the climb into the stall.
	var stall_frame := -1
	for _i in 300:
		await get_tree().physics_frame
		if _player.stalled:
			stall_frame = _i
			break
	var fell := false
	var fall_frame := -1
	if stall_frame >= 0:
		for _i in 45:
			await get_tree().physics_frame
			fall_frame = _i + 1
			if _player.velocity.y <= -6.0:
				fell = true
				break
	var finite := _player.velocity.is_finite()
	_dbg("stall fall: stalled at frame %d, vy %.2f after %d further frames, fwd %.2f" % [
			stall_frame, _player.velocity.y, fall_frame, _player.forward_speed])
	print("SIM DATA stall_falls_develops: stalled at frame %d, fell in %d frames (end vy %.2f, fwd %.2f)" % [
			stall_frame, fall_frame, _player.velocity.y, _player.forward_speed])
	_check("stall_falls_develops", fell and finite,
			"stalled at frame %d of 300, vy reached %.2f m/s in %d/45 frames (bar <= -6.0), finite=%s" % [
					stall_frame, _player.velocity.y, fall_frame, finite])


## (T-106) The post-loop roll cant, dead: the owner's repro — hold pitch-up
## through a loop until the bird goes over the top — used to leave a persistent
## one-way cant, because roll lived in a bookkept float the other rotation
## paths never reported into (the released-pitch trim's shortest arc, the
## body-axis pitch terms). This scenario flies that repro on the paced flap
## (the only thrust source; `boost` is declared-but-unimplemented). Measured
## natural history on the pre-fix tree (both runs recorded in the ticket): the
## held input asymptotes the nose at the T-083 park (|pitch| → 85°, nose
## frozen) while each flap kick swings the FLOW past vertical (~24°) and the
## aligner sags it back — so the over-the-top NOSE crossing is a RELEASE
## phenomenon: the released trim slerps the nose after a freshly-kicked,
## over-the-top flow, through exactly the shortest-arc geometry that leaks
## roll. Recipe: settled cruise glide, a short turn_left hold seeding a real
## loop entry's asymmetry, then pitch_up held directly (the `_hold` helper
## cannot overlap the flap cadence) with a near-fully-rested flap tap every 21
## frames until the nose has parked at the asymptote (nose.y ≥ sin 84° for 20
## frames), ending the hold ON a cadence tap so the release rides a fresh
## full-power kick. The STEERING input (pitch, turn) then releases for the
## 120-frame recovery window while the repro's own paced flap cadence CONTINUES
## — re-derived, not silently weakened: with the flap also dead the bird has no
## boost (declared-but-unimplemented) and no thrust left, stalls at the top,
## and the stall unwind carries the nose back down the near side, un-doing the
## leak (measured pre-fix all-input-dead run: end |roll| 1.16° — a vacuous
## green that hides the defect; both runs recorded in the ticket). With the
## repro's own throttle alive the bird stays in flight, the nose demonstrably
## sweeps past vertical onto the far side — `dot(nose, entry_fwd) < 0` within
## 240 frames, bank-tolerant and unambiguous where the pitch sine is not (0.99
## is both 81.9° and 98.1°), with a sanity arm that nose.y exceeded +0.9
## somewhere (a yaw-around, not a loop, must fail loudly — the precondition is
## asserted, never skipped) — and the MEASURED roll (atan2(basis.x.y,
## basis.y.y) — what the fixed controllers close on) must sit ≤ 5° at window
## end and be non-increasing across its last 60 frames (hands-off steering the
## target roll is 0, so leaked cant becomes a transient the closed loop eats
## at bank_rate). The ground leg then demands a LEVEL stand (|roll| ≤ 2°) with
## the heading kept through the leveling (touchdown-to-read change ≤ 2°).
## Measured on the pre-fix tree, no descent of the parked bird can carry the
## cant to touchdown — every path back down traverses the measurement pole and
## the leak self-erases there (all-input-dead stall tumble 176.8° → 1.4°,
## input-driven dive 155.5° → 1.0°), and the pole reading itself is
## azimuth-like (an inverted bird, not the owner's "canted to one side") — so
## the leg REPLAYS the defect class: a full-envelope flying cant the book
## cannot see, on a fresh low cruise glide descended passively, exactly the
## flying-with-leaked-cant state the owner landed with. The pre-fix leveler
## (bookkept) leaves that bird standing skewed; the measured controller eats
## the cant in flight and Fix 3 levels whatever the skid leaves.
func _scenario_loop_over_top_roll_recovers() -> void:
	await _set_up(true, Vector3(0.0, 25.0, 0.0), Vector3(0.0, 0.0, -17.0))
	await _wait_frames(30) ## Settle into the trim glide (the flap_speed_envelope leg-2 recipe).
	await _hold("turn_left", 15) ## Seed the asymmetry a real loop entry has.
	var entry_fwd := -_player.transform.basis.z
	var over_top := false
	var frames_to_top := -1
	var max_nose_y := -INF
	var max_steep_roll_deg := 0.0 ## |Measured roll| while |pitch| > ~80° — the near-pole jitter probe behind Fix 1's no-gating default.
	var parked := false ## The T-083 asymptote park: nose.y ≥ sin 84° held for 20 frames.
	var park_frame := -1
	Input.action_press("pitch_up")
	for _i in 600:
		if _i % 21 == 0:
			Input.action_press("flap") ## Paced, near-fully-rested taps (flap_interval 0.35 s = 21 frames).
		elif _i % 21 == 1:
			Input.action_release("flap")
		await get_tree().physics_frame
		var nose := -_player.transform.basis.z
		max_nose_y = maxf(max_nose_y, nose.y)
		if absf(nose.y) > 0.17:
			max_steep_roll_deg = maxf(max_steep_roll_deg, absf(rad_to_deg(
					atan2(_player.transform.basis.x.y, _player.transform.basis.y.y))))
		if _debug and _i % 10 == 0:
			print("[dbg] hold f%d nose (%.2f, %.2f, %.2f) flow (%.2f, %.2f, %.2f) speed %.1f roll %.1f deg pitch %.1f deg" % [
					_i, nose.x, nose.y, nose.z, _player.velocity.x, _player.velocity.y,
					_player.velocity.z, _player.velocity.length(),
					rad_to_deg(atan2(_player.transform.basis.x.y, _player.transform.basis.y.y)),
					rad_to_deg(asin(clampf(nose.y, -1.0, 1.0)))])
		if nose.dot(entry_fwd) < 0.0:
			over_top = true
			frames_to_top = _i
			break
		if not parked and nose.y >= 0.9945:
			parked = true
			park_frame = _i
		## End the hold ON a cadence tap frame (a fresh, fully-rested kick just
		## fired — the flow is swinging over the top NOW), so the released trim
		## chases a flow that starts past vertical, exactly the leak geometry.
		if parked and park_frame >= 0 and _i >= park_frame + 20 and _i % 21 == 0:
			break
	Input.action_release("pitch_up")
	Input.action_release("flap")
	var roll_samples: Array[float] = []
	for _i in 240: ## Steering hands off; the released trim takes the nose over the top and the closed roll loop must eat the leak.
		if _i < 120 and _i % 21 == 0:
			Input.action_press("flap") ## The repro's own throttle — keeps the bird alive to BE corrected (re-derived recipe, see above).
		elif _i < 120 and _i % 21 == 1:
			Input.action_release("flap")
		await get_tree().physics_frame
		var nose := -_player.transform.basis.z
		var roll_deg := absf(rad_to_deg(atan2(
				_player.transform.basis.x.y, _player.transform.basis.y.y)))
		if _i < 120:
			roll_samples.append(roll_deg)
			if absf(nose.y) > 0.17:
				max_steep_roll_deg = maxf(max_steep_roll_deg, roll_deg)
		if frames_to_top < 0 and nose.dot(entry_fwd) < 0.0:
			frames_to_top = _i
			over_top = true
		if _debug and _i % 10 == 0:
			print("[dbg] release f%d nose (%.2f, %.2f, %.2f) flow (%.2f, %.2f, %.2f) speed %.1f roll %.1f deg grounded=%s" % [
					_i, nose.x, nose.y, nose.z, _player.velocity.x, _player.velocity.y,
					_player.velocity.z, _player.velocity.length(), roll_deg,
					_player.is_grounded])
		if _i >= 120:
			Input.action_release("flap")
			if over_top:
				break
	var end_roll_deg := roll_samples[119]
	var roll_trend_deg := roll_samples[119] - roll_samples[59] ## ≤ 0 = non-increasing across the last 60 frames.
	var reached := over_top and max_nose_y > 0.9 ## The repro precondition — a fail here is loud, never vacuous.
	var air_ok := reached and end_roll_deg <= 5.0 and roll_trend_deg <= 0.0
	print("SIM DATA loop_over_top_roll_recovers: over top %s %d frames after release (max nose.y %.2f), max steep |roll| %.1f deg, end |roll| %.2f deg (60 frames earlier %.2f deg)" % [
			over_top, frames_to_top, max_nose_y, max_steep_roll_deg, end_roll_deg, roll_samples[59]])
	_check("loop_over_top_roll_recovers", air_ok,
			"precondition over_top=%s, max nose.y %.2f (sanity bar > 0.9), crossed %s frames after release — a repro that cannot reach vertical is a different bug; end |roll| %.2f deg (bar <= 5.0), trend %+.2f deg over the last 60 frames (bar <= 0.0)" % [
					over_top, max_nose_y, frames_to_top, end_roll_deg, roll_trend_deg])
	## Ground leg — RE-DERIVED, both measured runs recorded in the ticket: from
	## the window-end state EVERY descent path traverses the measurement pole
	## whose leak self-erases on the pre-fix tree (all-input-dead stall tumble
	## 176.8° → 1.4°; input-driven dive 155.5° → 1.0° — the near-pole rotations
	## un-roll the bird symmetrically on the way down), and the pole reading
	## itself (176.9°) is azimuth-like — an inverted bird, not the owner's
	## "canted to one side". The leg therefore REPLAYS the defect class the
	## owner landed with — a full-envelope flying cant the book cannot see —
	## onto a fresh low cruise glide and descends it passively. The pre-fix
	## bank controller cannot see the cant, the shallow touchdown gives the old
	## leveler's pitch arm nothing to couple through, and the bookkept roll arm
	## no-ops: the bird stands skewed (red on the level arm — "the cant
	## persists even on the ground"). The measured controller eats the cant in
	## flight and Fix 3 levels whatever the skid leaves.
	var replay_roll := deg_to_rad(_player.max_bank_deg)
	_player.reset_flight(Vector3(0.0, 2.5, 0.0), 0.0) ## Low start: the canted trim glide sinks only ~1.5 m/s, so a high start glides past the test slab's -100 edge and the T-042 guard's upright reset vacuously greens the stand read (measured).
	_player.velocity = Vector3(0.0, 0.0, -17.0) ## Cruise along the (still level-projected) nose.
	_player.rotate_object_local(Vector3.BACK, replay_roll)
	await _wait_frames(2)
	for _i in 1200:
		await get_tree().physics_frame
		if _player.is_grounded:
			break
		if _debug and _i % 40 == 0:
			var fwd := -_player.transform.basis.z
			print("[dbg] replay f%d pos (%.1f, %.1f, %.1f) nose (%.2f, %.2f, %.2f) speed %.1f fwd %.1f stalled=%s roll %.2f deg on_floor=%s grounded=%s" % [
					_i, _player.position.x, _player.position.y, _player.position.z,
					fwd.x, fwd.y, fwd.z, _player.velocity.length(), _player.forward_speed,
					_player.stalled,
					rad_to_deg(atan2(_player.transform.basis.x.y, _player.transform.basis.y.y)),
					_player.is_on_floor(), _player.is_grounded])
	var touch_yaw := _flat_yaw()
	await _wait_frames(60)
	var stand_roll_deg := absf(rad_to_deg(atan2(
			_player.transform.basis.x.y, _player.transform.basis.y.y)))
	var yaw_drift_deg := absf(rad_to_deg(angle_difference(touch_yaw, _flat_yaw())))
	var finite := _player.velocity.is_finite() and _player.position.is_finite()
	print("SIM DATA loop_lands_level_keeps_yaw: grounded=%s stand |roll| %.2f deg (replayed %.1f deg), yaw drift %.2f deg" % [
			_player.is_grounded, stand_roll_deg, rad_to_deg(replay_roll), yaw_drift_deg])
	_check("loop_lands_level_keeps_yaw",
			_player.is_grounded and stand_roll_deg <= 2.0 and yaw_drift_deg <= 2.0 and finite,
			"grounded=%s, stand |roll| %.2f deg (bar <= 2.0; replayed cant %.1f deg), heading moved %.2f deg touchdown-to-read (bar <= 2.0), finite=%s" % [
					_player.is_grounded, stand_roll_deg, rad_to_deg(replay_roll),
					yaw_drift_deg, finite])


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


## (T-023) The edge nudge, the prevention layer ahead of the T-042 guard:
## reset 300 m past the city edge — 417 m from the home center, 50 m past the
## 367 m apron radius, mid-ramp — flying straight out (nose +X, dead away from
## home: the bearing sine's zero, so the scenario also proves the steer does
## not stall there) and hands-off for 3 s (180 frames), the heading must rotate
## ≥ 30° back toward home while y never drops below 0. The guard cannot fire
## inside the window (from y 30 the flight model's softened gravity sinks
## roughly 10 m, far above the −5 line — `min_gravity_fraction` 0.2), so the
## heading assertion is what bites: today's tree has no homing term in _steer
## and keeps the nose on +X. The scenario wires `home_center`/`home_radius`
## itself — the only one that does, which is what keeps every other scenario's
## in-city handling untouched by construction (radius 0.0 disables entirely).
func _scenario_edge_nudge_turns_home() -> void:
	## The shared harness player carries `off_world_resets` == 1 out of
	## `off_world_fall_respawns` (it runs immediately before and never zeroes
	## it — the same reason the later `off_world_fall_returns_home` sibling
	## zeroes it for its own window): zero it so this scenario's quiet arm
	## asserts ITS OWN window fired nothing.
	_player.off_world_resets = 0
	var home: Vector3 = _city.global_position
	_player.home_center = home
	_player.home_radius = _city.city_span * 0.5 + _city.ground_extra
	var half: float = _city.city_span * 0.5
	await _set_up(true, home + Vector3(half + 300.0, 30.0, 0.0), Vector3(17.0, 0.0, 0.0), -90.0)
	var start_fwd := -_player.transform.basis.z
	start_fwd.y = 0.0
	var min_y := INF
	for _i in 180: ## 3 s hands off.
		await get_tree().physics_frame
		min_y = minf(min_y, _player.global_position.y)
	var end_fwd := -_player.transform.basis.z
	end_fwd.y = 0.0
	var turned_deg := rad_to_deg(start_fwd.normalized().angle_to(end_fwd.normalized()))
	var to_home := home - _player.global_position
	to_home.y = 0.0
	var end_bearing_deg := rad_to_deg(end_fwd.normalized().angle_to(to_home.normalized()))
	var finite := _player.velocity.is_finite() and _player.global_position.is_finite()
	var quiet := _player.off_world_resets == 0 ## The guard never fired — the nudge alone did the turning.
	print("SIM DATA edge_nudge_turns_home: turned %.1f deg, end bearing %.1f deg, min y %.2f m, resets %d" % [
			turned_deg, end_bearing_deg, min_y, _player.off_world_resets])
	_check("edge_nudge_turns_home",
			turned_deg >= 30.0 and end_bearing_deg < 180.0 and min_y >= 0.0
					and quiet and finite,
			"turned %.1f deg (bar >= 30 toward home), end bearing %.1f deg, min y %.2f m (bar >= 0), resets %d, finite=%s" % [
					turned_deg, end_bearing_deg, min_y, _player.off_world_resets, finite])
	_player.home_center = Vector3.ZERO ## Housekeeping — later scenarios run with the nudge disabled.
	_player.home_radius = 0.0


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


## --- scenario (T-049 facades fit floors) -------------------------------------


## The standing `Visuals/Facade<N>` node for floor count `f` — resolved FRESH
## on every call, because `City.generate()` frees and rebuilds the whole
## Visuals root, so any node reference held across a rebuild dangles.
func _facade_node(f: int) -> MultiMeshInstance3D:
	var visuals := _city.get_node_or_null("Visuals") as Node3D
	if visuals == null:
		return null
	return visuals.get_node_or_null(("facade%d" % f).to_pascal_case()) as MultiMeshInstance3D


## The facade windows fit each building's real floor count (T-049): one
## `Visuals/Facade<N>` MultiMesh per floor count actually present in
## `buildings[]` — none for a count no building has — each class carrying as
## many instances as it has buildings, every instance transform equal to its
## building's expected facade box (recomputed from the record's public
## center/size/top, floors derived per record), and each class material
## reporting its floor count as `window_rows` metadata, distinct across
## classes. A forced same-seed rebuild reproduces every class's instance set
## byte-identically (`_spots_equal`) and the fingerprint stays at the pre-T-049
## baseline pins — the change is keys/materials only: zero RNG draws, zero
## `_fp` entries. Layout asserts on the standing city, no flight (the
## district-palettes scenario shape).
func _scenario_city_facades_fit_floors() -> void:
	var pin_default := 4045370482 ## Fingerprint baseline — moved for T-051's two-axis footprint `_fp` entry, again for T-029's plaza-landmark `_fp` entry, again for T-091's four district-anchor `_fp` entries, and again for T-104's four plaza-bin `_fp` x/z entries, each re-derived with a headless City.generate probe (pre-T-051: 2492360539; pre-T-029: 4188136223; pre-T-091: 1006789400; pre-T-104: 650664268).
	var pin_foreign := 533171164 ## Foreign-seed fingerprint, ditto (pre-T-051: 2662825400; pre-T-029: 547420287; pre-T-091: 3359332191; pre-T-104: 4031380170).
	var baseline_ok: bool = _city.fingerprint == pin_default
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	## Tally the buildings by floor count, derived from each record alone.
	var per_floors: Dictionary = {} ## floors -> Array[Dictionary], in buildings[] order.
	for info in _city.buildings:
		var floors := roundi((float(info.top) - _city.block_slab_height
				- _city.roof_slab_height) / _city.floor_height)
		if not per_floors.has(floors):
			per_floors[floors] = []
		(per_floors[floors] as Array).append(info)
	var visuals := _city.get_node("Visuals") as Node3D
	var facade_nodes: Array[MultiMeshInstance3D] = []
	for child in visuals.get_children():
		if child is MultiMeshInstance3D and (child as Node).name.begins_with("Facade"):
			facade_nodes.append(child)
	var names_ok: bool = facade_nodes.size() == per_floors.size()
	var counts_ok := true
	var transforms_ok := true
	var meta_ok := true
	var rows_seen: Array[int] = []
	var sets_before: Dictionary = {} ## floors -> Array[Transform3D], the standing class queues.
	for f: int in per_floors:
		var records: Array = per_floors[f]
		var node := _facade_node(f)
		names_ok = names_ok and node != null
		if node == null:
			continue
		counts_ok = counts_ok and node.multimesh.instance_count == records.size()
		## Instance transforms read from the class queue — the exact arrays fed
		## into `set_instance_transform` (the park-trees/crosswalks channel):
		## `MultiMesh.get_instance_transform` reads back identity on this
		## engine build, so the node itself cannot answer per-instance data.
		var xfs: Array[Transform3D] = []
		for xf: Transform3D in _city._visuals["facade%d" % f].xfs:
			xfs.append(xf)
		counts_ok = counts_ok and xfs.size() == records.size()
		for i in records.size():
			var info: Dictionary = records[i]
			var center := info.center as Vector3
			var size := info.size as Vector2
			var expected_origin := _city.to_local(center) \
					+ Vector3(0.0, _city.block_slab_height + float(f) * _city.floor_height * 0.5, 0.0)
			var expected_scale := Vector3(size.x, float(f) * _city.floor_height, size.y)
			var xf := xfs[i]
			transforms_ok = transforms_ok \
					and xf.origin.distance_to(expected_origin) < 0.01 \
					and absf(xf.basis.get_scale().x - expected_scale.x) < 0.01 \
					and absf(xf.basis.get_scale().y - expected_scale.y) < 0.01 \
					and absf(xf.basis.get_scale().z - expected_scale.z) < 0.01
		var mat := node.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
		meta_ok = meta_ok and mat != null and mat.has_meta("window_rows") \
				and int(mat.get_meta("window_rows")) == f
		rows_seen.append(int(mat.get_meta("window_rows")))
		sets_before[f] = xfs
	var rows_distinct := true
	for i in rows_seen.size():
		for j in range(i + 1, rows_seen.size()):
			rows_distinct = rows_distinct and rows_seen[i] != rows_seen[j]
	## Determinism: a real rebuild reproduces every class's instance set byte-identically.
	_city.generate(default_seed, true)
	var deterministic: bool = _city.fingerprint == fp_first and not per_floors.is_empty()
	for f: int in per_floors:
		var node := _facade_node(f)
		if node == null:
			deterministic = false
			continue
		var xfs_after: Array[Transform3D] = []
		for xf: Transform3D in _city._visuals["facade%d" % f].xfs:
			xfs_after.append(xf)
		deterministic = deterministic and _spots_equal(sets_before[f], xfs_after)
	## A foreign seed keeps the same law — its own floor classes, each present.
	_city.generate(424242)
	var foreign_floors: Dictionary = {}
	for info in _city.buildings:
		var foreign_floors_i := roundi((float(info.top) - _city.block_slab_height
				- _city.roof_slab_height) / _city.floor_height)
		foreign_floors[foreign_floors_i] = true
	var foreign_ok: bool = not foreign_floors.is_empty()
	for f: int in foreign_floors:
		foreign_ok = foreign_ok and _facade_node(f) != null
	var pin_foreign_ok: bool = _city.fingerprint == pin_foreign
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	var pin_default_ok: bool = _city.fingerprint == pin_default
	var counts_line := PackedStringArray()
	for f: int in per_floors:
		counts_line.append("%d:%d" % [f, (per_floors[f] as Array).size()])
	_check("city_facades_fit_floors",
			baseline_ok and names_ok and counts_ok and transforms_ok and meta_ok
					and rows_distinct and deterministic and foreign_ok
					and pin_foreign_ok and pin_default_ok,
			"baseline=%s nodes=%d/%d counts=%s transforms=%s meta=%s rows=%s det=%s foreign=%s pins=%s/%s" % [
					baseline_ok, facade_nodes.size(), per_floors.size(),
					" ".join(counts_line), transforms_ok, meta_ok, rows_seen,
					deterministic, foreign_ok, pin_foreign_ok, pin_default_ok])
	## Informational: the per-class tally — the ticket's roofscape read, re-printed.
	print("SIM DATA city_facades_fit_floors: classes=%d tally=[%s] fingerprint=%d" % [
			per_floors.size(), " ".join(counts_line), fp_first])


## --- scenario (T-051 varied footprints) --------------------------------------


## The per-lot, per-axis footprint scale the ticket's pure hash claims — the
## harness owns its copy of the fold (the `_expected_cafe_spot`
## harness-owns-its-copy pattern) so the scenario proves the sizes, not just
## the city function that filled them. Same fold as `City._lot_footprint_scale`:
## (bx, bz, quadrant folded as qx·2+qz, axis+1) hashed, folded once with the
## seed, mapped to [0.78, 1.0].
func _expected_footprint_scale(bx: int, bz: int, qx: int, qz: int, axis: int,
		seed_value: int) -> float:
	var h := hash(Vector4i(bx, bz, qx * 2 + qz, axis + 1))
	h = hash(h ^ seed_value)
	return 0.78 + 0.22 * float(h % 1001) / 1000.0


## Varied footprints (T-051): the roofscape is no longer a waffle grid of equal
## 7.1 m squares — ≥ 3 distinct footprint sizes city-wide, every footprint
## fully inside its lot with the `lot_gap` kept (per axis
## `size ≤ (block_size − sidewalk_width·2)·0.5 − lot_gap`, size > 0), and every
## record's size recomputable from the pure per-block/quadrant/axis hash plus
## the seed (within 0.01) — with the observed scales spread across the mapped
## [0.78, 1.0] band, not degenerate. The hash draws from NO RNG stream: the
## pinned 104-of-146 awning count (`city_shopfronts_present`) and the byte
## counts elsewhere prove both streams untouched; a forced same-seed rebuild
## reproduces every size exactly and the fingerprint holds. Layout asserts on
## the standing city, no flight (the facades-audit pattern).
func _scenario_city_footprints_vary() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var sizes: Array[Vector2] = []
	var distinct := {}
	for info in _city.buildings:
		var size: Vector2 = info.size
		sizes.append(size)
		distinct[size] = true
	var distinct_ok := distinct.size() >= 3
	## Every footprint inside its lot with the gap kept, per axis, and positive.
	var size_max := (_city.block_size - _city.sidewalk_width * 2.0) * 0.5 - _city.lot_gap
	var bounds_ok := not sizes.is_empty()
	for size in sizes:
		bounds_ok = bounds_ok and size.x > 0.0 and size.y > 0.0 \
				and size.x <= size_max and size.y <= size_max
	## Every record's size recomputable from the harness-owned hash fold.
	var half_blocks := float(_city.blocks_per_side - 1) * 0.5
	var footprint_max := (_city.block_size - _city.sidewalk_width * 2.0) * 0.5 - _city.lot_gap
	var recompute_ok := not sizes.is_empty()
	var min_scale := INF
	var max_scale := -INF
	for info in _city.buildings:
		var center_local := _city.to_local(info.center)
		var bx := roundi(center_local.x / _city.block_pitch + half_blocks)
		var bz := roundi(center_local.z / _city.block_pitch + half_blocks)
		var lot: Vector2 = info.lot_offset
		var qx := int(signf(lot.x))
		var qz := int(signf(lot.y))
		var expected := Vector2(
				footprint_max * _expected_footprint_scale(bx, bz, qx, qz, 0, default_seed),
				footprint_max * _expected_footprint_scale(bx, bz, qx, qz, 1, default_seed))
		var size: Vector2 = info.size
		recompute_ok = recompute_ok \
				and absf(size.x - expected.x) < 0.01 and absf(size.y - expected.y) < 0.01
		min_scale = minf(min_scale, size.x / footprint_max)
		min_scale = minf(min_scale, size.y / footprint_max)
		max_scale = maxf(max_scale, size.x / footprint_max)
		max_scale = maxf(max_scale, size.y / footprint_max)
	## Uniform-ish across the mapped band: with 292 axis samples over 146
	## buildings the extremes must reach both ends of [0.78, 1.0].
	var spread_ok := min_scale <= 0.80 and max_scale >= 0.98
	## Determinism: a real rebuild reproduces every size exactly, fp self-to-self.
	_city.generate(default_seed, true)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _city.buildings.size() == sizes.size()
	if deterministic:
		for i in sizes.size():
			deterministic = deterministic \
					and (_city.buildings[i].size as Vector2) == sizes[i]
	_check("city_footprints_vary",
			distinct_ok and bounds_ok and recompute_ok and spread_ok and deterministic,
			"sizes=%d distinct=%d bounds=%s recompute=%s spread=[%.3f..%.3f] det=%s" % [
					sizes.size(), distinct.size(), bounds_ok, recompute_ok,
					min_scale, max_scale, deterministic])
	## Informational: the ticket's roofscape read, re-printed on every re-run.
	print("SIM DATA city_footprints_vary: buildings=%d distinct_sizes=%d scale_range=[%.3f..%.3f] fingerprint=%d"
			% [sizes.size(), distinct.size(), min_scale, max_scale, fp_first])


## --- scenarios (T-017 shopfront ground floors) ------------------------------


## The signboard plaque transform the ticket's pure math claims for one
## building — an independent re-derivation (the harness owns its copy of the
## layout numbers, the `_expected_cafe_spot` pattern) so the scenario proves
## the plaques, not just the city function that filled them. The face distance
## uses the footprint component ALONG the door-face normal (T-051: `size.x` on
## ±x faces, `size.y` on ±z), and the size MUST encode the flush convention —
## the thin 0.08 m depth on the face-normal axis, the 2.2 m width along the
## wall, the AWNING's convention (shared by the door since T-103's fix): a
## perpendicular plank has the same origin and euler (both builds are
## unrotated diagonal bases), so only the per-axis scale compare keeps it
## failing.
func _expected_sign_plaque(city: City, info: Dictionary) -> Transform3D:
	var normal: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][
			int(info.door_face)]
	var face_axis_x := absf(normal.x) > 0.5
	var face_out: float = (info.size as Vector2).x if face_axis_x \
			else (info.size as Vector2).y
	var size := Vector3(0.08, 0.5, 2.2) if face_axis_x else Vector3(2.2, 0.5, 0.08)
	var pos: Vector3 = city.to_local(info.center) \
			+ normal * (face_out * 0.5 + 0.12 + 0.05) \
			+ Vector3(0.0, city.block_slab_height + 2.55, 0.0)
	return Transform3D(Basis.from_scale(size), pos)


## The door transform T-103's fixed math claims for one building — an
## independent re-derivation (the `_expected_sign_plaque` pattern) so the
## scenario proves the doors, not just the city function that filled them.
## The face distance uses the footprint component ALONG the door-face normal
## (T-051: `size.x` on ±x faces, `size.y` on ±z), and the size MUST encode the
## flush convention T-103 fixed — the thin 0.1 m depth on the face-normal
## axis, the 0.95 m width along the wall, the awning's convention — NOT the
## landed inverted swap: a fin has the same origin and euler (both builds are
## unrotated diagonal bases), so only the per-axis scale compare keeps it
## failing.
func _expected_door(city: City, info: Dictionary) -> Transform3D:
	var normal: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][
			int(info.door_face)]
	var face_axis_x := absf(normal.x) > 0.5
	var face_out: float = (info.size as Vector2).x if face_axis_x \
			else (info.size as Vector2).y
	var size := Vector3(0.1, 2.05, 0.95) if face_axis_x else Vector3(0.95, 2.05, 0.1)
	var pos: Vector3 = city.to_local(info.center) \
			+ normal * (face_out * 0.5 + 0.12 + 0.01) \
			+ Vector3(0.0, city.block_slab_height + 1.025, 0.0)
	return Transform3D(Basis.from_scale(size), pos)


## Every building wears a ground-floor shop band, a door on one of its two
## street-facing faces, and the seeded share of awnings; the shopfront palette
## stays measurably distinct from all four district palettes. Under the fixed
## seed every roll is deterministic, so coverage is asserted at 100% and the
## awning count is pinned to the seed's exact draw (104 of 146 = 71.2% for
## awning_chance 0.6 at seed 20260928 — retune the pin if the chance changes).
## Since T-103 the door geometry is asserted too: every queued `door` transform
## decomposes as a pure scale with the ≈0.1 m thin axis ON the face-normal
## direction and the 0.95 m width along the wall (a flush slab, not a fin).
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
	## Signboard plaques (T-090): the `sign` visual queue holds exactly one
	## plaque per building — the queue that feeds the MultiMesh, read like the
	## crosswalk paint's (MultiMesh.get_instance_transform reads back identity
	## headless) — and every transform is recomputable from its building record
	## (order pairs 1:1: both lists append once per `_add_building`). The
	## re-derivation's per-axis scale compare is the perpendicular-plank guard.
	var sign_queue: Array = _city._visuals.get("sign", {}).get("xfs", [])
	var signs_ok: bool = sign_queue.size() == count
	if signs_ok:
		var sign_i := 0
		for info in _city.buildings:
			var xf: Transform3D = sign_queue[sign_i]
			var expected: Transform3D = _expected_sign_plaque(_city, info)
			signs_ok = signs_ok \
					and xf.origin.distance_to(expected.origin) < 0.01 \
					and (xf.basis.get_scale() - expected.basis.get_scale()).length() < 0.01 \
					and xf.basis.get_euler().distance_to(expected.basis.get_euler()) < 0.01
			sign_i += 1
	## Door geometry (T-103): the `door` visual queue holds exactly one door
	## per building (146 at the M1 seed, paired 1:1 in order like the sign
	## queue), and every transform is a FLUSH slab — the basis decomposes as
	## pure scale, no rotation (per `_box_xf`), with the ≈0.1 m thin axis ON
	## the face-normal direction and the 0.95 m width along the wall, re-derived
	## per building from its `door_face` record (the `_expected_door` re-derivation
	## pins origin too). The landed inverted swap kept origin and euler and only
	## swapped the per-axis scales — exactly what this leg reads — so a fin
	## fails here on both the raw-axis compare and the expected-scale compare.
	var door_queue: Array = _city._visuals.get("door", {}).get("xfs", [])
	var doors_ok: bool = door_queue.size() == 146 and door_queue.size() == count
	if doors_ok:
		var door_i := 0
		for info in _city.buildings:
			var xf: Transform3D = door_queue[door_i]
			var normal: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][
					int(info.door_face)]
			var door_scale: Vector3 = xf.basis.get_scale()
			var normal_axis: float = door_scale.x if absf(normal.x) > 0.5 else door_scale.z
			var wall_axis: float = door_scale.z if absf(normal.x) > 0.5 else door_scale.x
			var expected: Transform3D = _expected_door(_city, info)
			doors_ok = doors_ok \
					and xf.basis.get_euler().length() < 0.01 \
					and absf(normal_axis - 0.1) < 0.01 \
					and absf(wall_axis - 0.95) < 0.01 \
					and absf(door_scale.y - 2.05) < 0.01 \
					and xf.origin.distance_to(expected.origin) < 0.01
			door_i += 1
	_check("city_shopfronts_present", coverage_ok and awn_ok and signs_ok and doors_ok,
			"buildings=%d members=%s doors_on_street=%s palette_distinct=%s awnings=%d (%.1f%%) signs=%d/%d %s door_xfs=%d/%d %s"
					% [count, members_ok, doors_on_street, palette_distinct,
					awnings, awn_share * 100.0, sign_queue.size(), count, signs_ok,
					door_queue.size(), count, doors_ok])
	## Same seed → every shopfront roll reproduces identically — and the sign
	## plaque and door queues byte-identically (the `_spots_equal` exact-compare
	## pattern).
	var default_seed: int = _city.seed_value
	var snapshot: Array = []
	for info in _city.buildings:
		snapshot.append([info.shop_color, info.door_face, info.has_awning])
	var sign_snapshot: Array[Transform3D] = []
	for xf: Transform3D in sign_queue:
		sign_snapshot.append(xf)
	var door_snapshot: Array[Transform3D] = []
	for xf: Transform3D in door_queue:
		door_snapshot.append(xf)
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces the rolls.
	var reproduced := snapshot.size() == _city.buildings.size()
	if reproduced:
		for i in snapshot.size():
			var info: Dictionary = _city.buildings[i]
			var same_color: bool = (snapshot[i][0] as Color).is_equal_approx(info.shop_color)
			var same_face: bool = snapshot[i][1] == int(info.door_face)
			var same_awning: bool = snapshot[i][2] == bool(info.has_awning)
			reproduced = reproduced and same_color and same_face and same_awning
	var signs_reproduced: bool = _city._visuals.has("sign")
	if signs_reproduced:
		var sign_rebuild: Array[Transform3D] = []
		for xf: Transform3D in _city._visuals["sign"].xfs:
			sign_rebuild.append(xf)
		signs_reproduced = _spots_equal(sign_snapshot, sign_rebuild)
	var doors_reproduced: bool = _city._visuals.has("door")
	if doors_reproduced:
		var door_rebuild: Array[Transform3D] = []
		for xf: Transform3D in _city._visuals["door"].xfs:
			door_rebuild.append(xf)
		doors_reproduced = _spots_equal(door_snapshot, door_rebuild)
	reproduced = reproduced and signs_reproduced and doors_reproduced
	_check("city_shopfronts_deterministic", reproduced,
			"snapshot %d vs regenerated %d signs_reproduced=%s doors_reproduced=%s" % [
					snapshot.size(), _city.buildings.size(), signs_reproduced,
					doors_reproduced])


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
## (T-075) With the bar parked at zero and the player still attached, 120
## further drained frames must produce ZERO changed emissions — the guarded
## setter stays silent where the unguarded one re-broadcast every tick.
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
	_hunger_changed_fires = 0
	hunger.changed.connect(func(_v: float, _m: float) -> void: _hunger_changed_fires += 1)
	await _wait_frames(120) ## Two seconds of live drain-at-zero, player still attached.
	_check("hunger_game_over_once",
			crossed_once and restored and _game_over_fires == 1 and hunger.value <= 0.5
					and _hunger_changed_fires == 0,
			"fires=%d crossed=%s restored=%s value=%.1f changed_fires=%d" % [
					_game_over_fires, crossed_once, restored, hunger.value,
					_hunger_changed_fires])
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
## (T-081) The setup is a 7 m flyover, not the old zero-velocity hover: on the
## fall tree a stalled pigeon (zero airspeed -> the untouched 1.7x stall
## gravity) drops onto the pad BELOW its own dropping — measured pad hit
## (0.0, -0.13, 0.0) against the < -1.0 bar, the impact resolved through the
## pigeon standing on the target. The flyover keeps every assertion identical
## and the lob real: the drop inherits 7 m/s of forward flight, arcs onto the
## pad (measured impact vy -3.55) while the pigeon passes 3+ m overhead and
## lands past it.
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
	await _set_up(true, Vector3(40.0, 7.0, 6.0), Vector3(0.0, 0.0, -7.0)) ## Fly over the pad; the lob lands under the flight line.
	await _tap("poop")
	await _wait_frames(2)
	if _dropped.size() == 1:
		_dropped[0].splatted.connect(_on_test_splatted)
	await _wait_frames(120) ## Arc (~1 s) plus margin.
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
## collider stays pinned at T-060's retuned 0.30 (the landed 0.07 pin amended
## in place — the pin's purpose survives: the collider still deliberately
## differs from the 0.12 mesh, the overhang direction flipped, and every
## hit-registration scenario keeps its layer/mask meaning).
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
					and absf(collider.radius - 0.30) < 0.005, ## float32-stored 0.30 sits a hair above the literal.
			"radius=%.2f emission_enabled=%s emission=%s grass=%.3f plaza=%.3f collider=%.2f" % [
					sphere.radius, mat.emission_enabled, mat.emission, vs_grass, vs_plaza,
					collider.radius])
	poop.free()


## One axis of the T-105 damped closed form, p(t) = p0 + (v0 − G/d)·(1 −
## e^(−d·t))/d + (G/d)·t, with `g_axis` the signed gravity along that axis
## (−g on y, 0 horizontal) — re-implemented HERE, never read from the reticle
## (the no-self-test rule); d ≈ 0 falls back to the pure parabola (T-046's
## undamped form).
func _damped_axis(p0: float, v0: float, g_axis: float, damp: float, t: float) -> float:
	if damp < 0.0001:
		return p0 + v0 * t + 0.5 * g_axis * t * t
	var k := (1.0 - exp(-damp * t)) / damp
	return p0 + (v0 - g_axis / damp) * k + (g_axis / damp) * t


## The damped impact of a release from (p0, v0) under `gravity` and the project's
## effective linear damp, onto whatever surface a straight-down WORLD ray from
## p0 finds — the scenario's own independent prediction: its own ray, its own
## closed form, its own bisection on y(t) = ground_y (the damped form has no
## closed-form inverse for t). `horizon` bounds the search (the drop's
## max_lifetime). The damp comes straight from the project setting, never from
## the reticle.
func _damped_impact(p0: Vector3, v0: Vector3, gravity: float, horizon: float) -> Vector3:
	var damp: float = ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(p0, p0 + Vector3(0.0, -60.0, 0.0), 1)
	var hit := space.intersect_ray(query)
	var ground_y: float = hit["position"].y if not hit.is_empty() else p0.y - 60.0
	var lo := 0.0
	var hi := maxf(horizon, 0.1)
	for _i in 60: ## Bisection to ~1e-14 s — the fall is monotonic down at these speeds.
		var mid := 0.5 * (lo + hi)
		if _damped_axis(p0.y, v0.y, -gravity, damp, mid) > ground_y:
			lo = mid
		else:
			hi = mid
	var t := 0.5 * (lo + hi)
	return Vector3(
			_damped_axis(p0.x, v0.x, 0.0, damp, t),
			ground_y,
			_damped_axis(p0.z, v0.z, 0.0, damp, t))


## The reticle's current albedo alpha — read through the one duplicated
## material the dim write drives, via the Ring mesh's override.
func _reticle_alpha(reticle: PoopReticle) -> float:
	var ring := reticle.get_node_or_null("Ring") as MeshInstance3D
	if ring == null:
		return -1.0
	var mat := ring.material_override as StandardMaterial3D
	if mat == null:
		return -1.0
	return mat.albedo_color.a


## The poop target reticle (T-105) — the aiming-contract leg, bare rig. The
## reticle is instantiated DIRECTLY (no Main alive, so no lock wiring runs) and
## freezes onto the one drop a real poop tap produced from the cooldown
## scenario's exact set-up. The frozen pin is compared against an impact
## recomputed INDEPENDENTLY in the scenario by the DAMPED closed form from the
## drop's own p0/v0 — read fresh from the drop, never through the reticle's
## march (the `_scan_nearest_crumb` no-self-test rule). This is the damping-fix
## leg: the old undamped T-046 point sits ~1.3–1.5 m from the damped impact at
## this release, well outside the 0.5 m bar, so the leg FAILS an unfixed march
## by construction. Plus two legs in the same scenario: the pin is stable
## through the fall (frozen means frozen), and after the splat the reticle is
## back in live mode within 0.5 s — still alive itself, it never frees mid-run.
func _scenario_reticle_frozen_pin_matches_damped_fall() -> void:
	_dropped.clear()
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _tap("poop")
	await _wait_frames(2) ## The poop_lob read shape — the drop exists by here.
	var spawned := _dropped.size() == 1
	var drop: Poop = _dropped[0] if spawned else null
	var reticle: PoopReticle = null
	var splat: MeshInstance3D = null
	if drop != null:
		splat = drop.splat_mesh ## Valid after the splat (reparented, fading) — the informational reality-check read.
		reticle = POOP_RETICLE_SCENE.instantiate() as PoopReticle
		add_child(reticle)
		reticle.lock_to(drop)
	await _wait_frames(4) ## The reticle marches on its first physics frame after the lock.
	var frozen_ok := false
	var matched := false
	var pin := Vector3.ZERO
	var impact := Vector3.ZERO
	var undamped := Vector3.ZERO
	var stability_ok := false
	if reticle != null and drop != null:
		frozen_ok = reticle.is_frozen and reticle.visible
		pin = reticle.global_position
		## The independent recompute: the drop's own p0/v0 and gravity, the
		## project's damp — none of it read from the reticle.
		var g: float = drop.fall_gravity
		var horizon: float = drop.max_lifetime
		impact = _damped_impact(drop.global_position, drop.linear_velocity, g, horizon)
		## The old undamped T-046 point, for the red-before evidence print only.
		var v0: Vector3 = drop.linear_velocity
		var p0: Vector3 = drop.global_position
		var t_undamped := (v0.y + sqrt(v0.y * v0.y + 2.0 * g * p0.y)) / g
		undamped = Vector3(p0.x + v0.x * t_undamped, 0.0, p0.z + v0.z * t_undamped)
		matched = pin.distance_to(impact) <= 0.5
		print("SIM INFO reticle pin=%s damped_impact=%s (%.2f m, bar 0.5) undamped=%s (damped-vs-undamped %.2f m)" % [
				pin, impact, pin.distance_to(impact), undamped, impact.distance_to(undamped)])
		await _wait_frames(30) ## Frozen means frozen: ≥30 frames through the fall.
		stability_ok = reticle.is_frozen and reticle.global_position.distance_to(pin) <= 0.05
	var drop_gone := false
	for _i in 180: ## 3 s budget — the damped fall is ~1.9 s.
		await get_tree().physics_frame
		if not is_instance_valid(drop):
			drop_gone = true
			break
	if drop_gone and splat != null and is_instance_valid(splat) and reticle != null:
		## Informational reality check (Gate 3 territory, never asserted): the
		## pin against where the ball actually landed.
		var splat_at := splat.global_position
		print("SIM INFO reality check: pin=%s actual_splat=%s (%.2f m)" % [
				pin, splat_at, pin.distance_to(splat_at)])
	var live_again := false
	if drop_gone:
		for _i in 31: ## 0.5 s budget after the splat.
			await get_tree().physics_frame
			if reticle != null and not reticle.is_frozen:
				live_again = true
				break
	var still_alive := reticle != null and is_instance_valid(reticle)
	if reticle != null:
		reticle.free() ## The reticle never frees itself — the rig cleans up its own instance.
	_check("reticle_frozen_pin_matches_damped_fall",
			spawned and frozen_ok and matched and stability_ok and drop_gone
					and live_again and still_alive,
			"spawned=%s frozen=%s matched=%s (%.2f m, bar 0.5) stable=%s drop_gone=%s live_again=%s alive=%s" % [
					spawned, frozen_ok, matched,
					pin.distance_to(impact) if reticle != null and drop != null else -1.0,
					stability_ok, drop_gone, live_again, still_alive])


## The poop target reticle (T-105) — the lifecycle leg through the REAL main
## scene (the T-077 instanced-Main pattern, parked in its own corner, the bare
## test pigeon parked grounded first so a tap can only fire through Main's own
## player). Exactly ONE reticle node serves the WHOLE scenario: live mode at a
## constant-velocity hover pins within 1.0 m of the hover state's hypothetical
## damped impact (looser bar — the 10 Hz refresh may lag one tick); one REAL
## tap freezes it and dims it to ≈ 0.25 immediately (the T-077 dim shape);
## hovering high enough that the cooldown expires before the drop lands
## relights it while still frozen; the splat returns it to live with the node
## count unchanged (persistence — the anti-assertion to T-046's "group empties
## again"); grounding hides it entirely; and restart_run() mid-freeze recovers
## it on its own — visible, live, full alpha (no restart-specific code). Leaves
## the tree unpaused with no live Main, like the rest of this block.
func _scenario_reticle_main_lifecycle() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	await _set_up(false, Vector3(0.0, 0.4, 0.0), Vector3.ZERO) ## Park the bare pigeon grounded…
	await _await_grounded(90) ## …so the tap cannot fire through it.
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(4500.0, 0.0, 4500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var pigeon: Player = main_game.player
	var reticle: PoopReticle = main_game.poop_reticle
	var spawn_local: Vector3 = main_game.city.to_local(main_game.city.spawn_point)
	var hover: Vector3 = spawn_local + Vector3(0.0, 10.0, 0.0) ## High enough that the cooldown expires before the drop lands.
	## Live leg: hold the pigeon airborne the T-077 way — a reset_flight per
	## frame (which also zeroes the cooldown, keeping the tap fresh).
	for _i in 12:
		pigeon.reset_flight(hover)
		await get_tree().physics_frame
	var count_live := get_tree().get_nodes_in_group("poop_reticles").size()
	var live_ok: bool = count_live == 1 and reticle.visible and not reticle.is_frozen \
			and absf(_reticle_alpha(reticle) - 1.0) <= 0.01
	var pin := reticle.global_position
	## The hover state's independent hypothetical: reset_flight pins the pose and
	## zeroes the velocity, so the release point is the level pigeon's spawn
	## offset and v0 is zero — a straight-down damped fall onto the plaza.
	var probe: Poop = POOP_SCENE.instantiate() ## The template's exports, read free-standing like the reticle does.
	var g: float = probe.fall_gravity
	var horizon: float = probe.max_lifetime
	probe.free()
	var release := pigeon.global_position - pigeon.global_transform.basis.y * pigeon.poop_drop_offset
	var impact := _damped_impact(release, Vector3.ZERO, g, horizon)
	var hover_pin_ok: bool = pin.distance_to(impact) <= 1.0
	print("SIM INFO hover pin=%s damped_impact=%s (%.2f m, bar 1.0)" % [
			pin, impact, pin.distance_to(impact)])
	## One REAL drop through Main's own wiring: frozen + dimmed immediately.
	await _tap("poop")
	await _wait_frames(2) ## lock_to fires mid-step; the frozen march runs the next physics frame.
	var frozen_dim_ok: bool = get_tree().get_nodes_in_group("poop_reticles").size() == 1 \
			and reticle.is_frozen and reticle.visible \
			and absf(_reticle_alpha(reticle) - 0.25) <= 0.01 \
			and not get_tree().get_nodes_in_group("poops").is_empty()
	## Hold the hover WITHOUT reset_flight (it would wipe the very cooldown being
	## tracked) and wait for the relight while the drop is still airborne.
	var relit := false
	for _i in 75: ## 1.25 s budget — the cooldown is 1.0 s; the fall from 10 m takes ~1.5 s.
		pigeon.velocity = Vector3(0.0, -1.0, 0.0)
		pigeon.position = hover
		await get_tree().physics_frame
		if reticle.is_frozen and absf(_reticle_alpha(reticle) - 1.0) <= 0.01:
			relit = true
			break
	## The splat returns the reticle to live — and the node count never changed.
	var drop_gone := false
	for _i in 240: ## 4 s budget — the drop is a few metres up when the cooldown expires, with margin.
		await get_tree().physics_frame
		if get_tree().get_nodes_in_group("poops").is_empty():
			drop_gone = true
			break
	await _wait_frames(2) ## The reticle's next physics tick flips it home.
	var count_splat := get_tree().get_nodes_in_group("poop_reticles").size()
	var splat_live_ok: bool = drop_gone and count_splat == 1 and not reticle.is_frozen \
			and reticle.visible and absf(_reticle_alpha(reticle) - 1.0) <= 0.01
	## Grounded → hidden entirely (pooping is air-only).
	pigeon.reset_flight(spawn_local + Vector3(0.0, 0.4, 0.0))
	var landed := false
	for _i in 300:
		await get_tree().physics_frame
		if pigeon.is_grounded:
			landed = true
			break
	await _wait_frames(3) ## The driver's next tick hides it.
	var hidden_ok: bool = landed and pigeon.is_grounded and not reticle.visible
	## Take off, drop for real, and restart_run() MID-FREEZE: the poops loop
	## frees the locked drop, the validity poll flips the reticle to live, and
	## reset_flight returns the pigeon to AIR with a zeroed cooldown — the next
	## tick drives visible + live + full alpha with no restart-specific code.
	await _tap("flap")
	var airborne_again := false
	for _i in 60:
		await get_tree().physics_frame
		if not pigeon.is_grounded:
			airborne_again = true
			break
	await _tap("poop")
	await _wait_frames(2)
	var freezing: bool = reticle.is_frozen
	main_game.restart_run()
	await _wait_frames(3)
	var count_restart := get_tree().get_nodes_in_group("poop_reticles").size()
	var restart_ok: bool = freezing and not get_tree().paused and count_restart == 1 \
			and reticle.visible and not reticle.is_frozen \
			and absf(_reticle_alpha(reticle) - 1.0) <= 0.01 \
			and not main_game.player.is_grounded
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("reticle_main_lifecycle",
			live_ok and hover_pin_ok and frozen_dim_ok and relit and splat_live_ok
					and hidden_ok and airborne_again and restart_ok,
			"live=%s hover_pin=%s (%.2f m, bar 1.0) frozen_dim=%s relit=%s splat_live=%s hidden=%s air=%s restart=%s" % [
					live_ok, hover_pin_ok,
					pin.distance_to(impact) if reticle != null else -1.0,
					frozen_dim_ok, relit, splat_live_ok, hidden_ok, airborne_again, restart_ok])


## The reticle's live re-march cadence (T-110): the tuned 30 Hz is a whole-tick
## lock on the fixed 60 Hz step — 2 ticks. A silent revert of the export (the
## T-105 10.0 resolves to 6) FAILs both arms. Bare rig, no player: the
## derivation runs in _ready, while live-mode marching itself needs a moving
## pigeon — the feel leg is the ticket's Gate 3 line, not this scenario.
func _scenario_reticle_live_refresh_lock() -> void:
	var reticle: PoopReticle = POOP_RETICLE_SCENE.instantiate() as PoopReticle
	add_child(reticle)
	await _wait_frames(2) ## _ready resolves _refresh_ticks from the export.
	var hz: float = reticle.live_refresh_hz
	var ticks: int = reticle._refresh_ticks
	reticle.free()
	_check("reticle_live_refresh_30hz",
			is_equal_approx(hz, 30.0) and ticks == 2,
			"hz=%.1f ticks=%d (want 30.0 / 2)" % [hz, ticks])


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


## The lead coach (T-060), through the REAL main scene (the T-077 instanced-Main
## pattern — own space, the spawner tightened to ONE tourist before _ready so
## the coach's scan has exactly one candidate): held airborne well out of
## coach_range the slot shows the plain air hint; held airborne ~20 m ahead of
## the tourist (within coach_range, ahead-ish) it teaches the lead —
## MainGame.COACH_POOP; one synthetic `Game.add_tourist_hit` (the scoring
## relay's exact entry — the coach is keyed on `tourist_hits`, never on a
## signal, so nothing but a real tourist splat retires it) silences it back to
## HINT_AIR while still airborne and in range; and landing grounded — beside
## the tourist, still within range, i.e. ineligible only by grounding — shows
## HINT_GROUND regardless. Registered beside the other poop scenarios —
## unpaused tree, no live Main — and it leaves it exactly that.
func _scenario_coach_hint_shows_until_first_hit() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	var spawner: TouristSpawner = main_game.get_node("TouristSpawner") as TouristSpawner
	spawner.target_count = 1
	spawner.spawn_min_dist = 0.0
	spawner.spawn_max_dist = 10.0 ## One candidate, seeded near the spawn corridor before _ready populates.
	main_game.position = Vector3(5500.0, 0.0, -5500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var hint: Label = main_game.hint_label
	var pigeon: Player = main_game.player
	var spawn_local: Vector3 = main_game.city.to_local(main_game.city.spawn_point)
	var tourists := main_game.tourist_spawner.living_tourists()
	if tourists.is_empty():
		_check("coach_hint_shows_until_first_hit", false, "no tourist spawned")
		main_game.free()
		Game.hunger.player = null
		Game.reset_run()
		return
	var tourist: Tourist = tourists[0]
	var tourist_local: Vector3 = main_game.to_local(tourist.global_position)
	## Out of range: held airborne ~60 m north of the only tourist — the T-077
	## way, a reset_flight per frame — the coach has nobody to teach, the plain
	## air hint owns the slot.
	var far_hover: Vector3 = spawn_local + Vector3(0.0, 12.0, 60.0)
	for _i in 8:
		pigeon.reset_flight(far_hover)
		await get_tree().physics_frame
	await _wait_frames(2) ## The _process driver's ticks.
	var far_ok: bool = not pigeon.is_grounded and hint.text == MainGame.HINT_AIR
	## In range, ahead-ish (yaw 0 flies −Z; the tourist sits 20 m dead ahead):
	## the lead lesson shows.
	var near_hover: Vector3 = tourist_local + Vector3(0.0, 8.0, 20.0)
	for _i in 8:
		pigeon.reset_flight(near_hover)
		await get_tree().physics_frame
	await _wait_frames(2)
	var coach_ok: bool = not pigeon.is_grounded and Game.tourist_hits == 0 \
			and hint.text == MainGame.COACH_POOP
	## One synthetic tourist hit through the scoring relay's exact entry: the
	## coach is dead for the rest of the run — the slot falls back to the air
	## hint while still airborne, still in range, tourist still ahead.
	Game.add_tourist_hit(tourist.global_position)
	await _wait_frames(2)
	var after_hit_ok: bool = Game.tourist_hits == 1 and hint.text == MainGame.HINT_AIR
	## Grounded (a 0.4 m drop beside the tourist, still within coach_range —
	## ineligible only by grounding): the ground hint shows regardless.
	pigeon.reset_flight(tourist_local + Vector3(0.0, 0.4, 5.0))
	var landed := false
	for _i in 300:
		await get_tree().physics_frame
		if pigeon.is_grounded:
			landed = true
			break
	await _wait_frames(3) ## The driver's next ticks reconcile the slot.
	var grounded_ok: bool = landed and pigeon.is_grounded \
			and hint.text == MainGame.HINT_GROUND
	var final_hint: String = hint.text ## Read before the teardown — the label dies with the scene.
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("coach_hint_shows_until_first_hit",
			far_ok and coach_ok and after_hit_ok and grounded_ok,
			"far=%s coach=%s after_hit=%s grounded=%s (hint '%s')" % [
					far_ok, coach_ok, after_hit_ok, grounded_ok, final_hint])


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
## Since T-078 the near arm tracks all of it: part-raised (and still rising)
## while company banks trust, never up while the pigeon is absent, and pinned
## down through the post-share cooldown even after trust has re-pinned.
func _scenario_elder_shares_bread_after_hangout() -> void:
	var rig := _add_elder_rig()
	var spawner: ElderSpawner = rig[0]
	var crumbs: BreadSpawner = rig[1]
	Game.favor = 8 ## (T-114) Staged explicitly — the rig inherits whatever the previous scenario left otherwise; 8 funds the share with change to spare.
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
	## T-078: the arm IS the trust meter — part-raised mid-hangout and still
	## creeping up as trust grows toward `trust_needed`.
	var raise_banked: float = elder._arm_raise
	await _wait_frames(10)
	var raise_later: float = elder._arm_raise
	var arm_meters_trust := banked > 1.5 and raise_banked > 0.2 and raise_banked < 0.9 \
			and raise_later > raise_banked
	var away := park + Vector3(6.0, 0.0, 0.0) ## Outside the 3.0 m zone, still on the plaza.
	await _set_up(true, away, Vector3.ZERO)
	await _await_grounded(90)
	var raise_absent_max := -1.0
	for _i in 30: ## ~0.7 s alone decays it but must not wipe it — and from frame 10 on
		## (the part-raised pose needs ~5 frames to ease down) the arm never rises.
		await get_tree().physics_frame
		if _i >= 10:
			raise_absent_max = maxf(raise_absent_max, elder._arm_raise)
	var arm_down_while_away := raise_absent_max <= 0.0
	var decayed: float = elder._trust
	await _set_up(true, park, Vector3.ZERO)
	await _await_grounded(90)
	await _wait_frames(280) ## trust_needed (4 s) of company plus margin — the share fires mid-wait.
	await _wait_frames(300) ## T-078, still parked: the 0.5 s beat passes and the cooldown
	## pins the arm down while trust refills and re-pins at `trust_needed`.
	var still_parked := _player.is_grounded and _player.position.distance_to(park) < 0.5
	var shared_once: bool = _bread_shared.size() == 1 and _bread_shared[0].elder == elder \
			and int(_bread_shared[0].crumbs) == elder.crumbs_per_share
	## (T-114) The share IS the purchase: the exact `elder_loaf_cost ×
	## crumbs_per_share` favor left the balance at the share.
	var spend_ok: bool = Game.favor == 8 - Game.elder_loaf_cost * elder.crumbs_per_share
	var arm_cooldown_pins := still_parked and elder._arm_raise < 0.1 \
			and elder._trust >= elder.trust_needed
	var live := 0
	var ordinary := true
	for crumb in crumbs.living_crumbs():
		var flat := Vector2(crumb.global_position.x - elder.global_position.x,
				crumb.global_position.z - elder.global_position.z)
		if flat.length() <= elder.toss_distance + elder.toss_spread + 0.05:
			live += 1
			ordinary = ordinary and crumb.restore == 30.0 and crumb.spot_index == -1
			ordinary = ordinary and crumb.favor_delta == 0 ## (T-114) Elder loaves stay unowned — paid at the share.
	_check("elder_shares_bread_after_hangout",
			parked and banked > 1.5 and decayed > 0.1 and decayed < banked - 0.5
					and shared_once and live >= 2 and ordinary and spend_ok
					and arm_meters_trust and arm_down_while_away and arm_cooldown_pins,
			"parked=%s trust %.2f→%.2f decay, relays %d, live crumbs in reach %d, ordinary=%s, spend 8→%d ok=%s, arm %.2f→%.2f rising, absent max %.2f, post-share arm %.2f at trust %.2f" % [
					parked, banked, decayed, _bread_shared.size(), live, ordinary,
					Game.favor, spend_ok, raise_banked, raise_later, raise_absent_max,
					elder._arm_raise, elder._trust])
	spawner.free()
	(rig[1] as Node).free()


## A FLYING pigeon held inside the same PresenceZone for longer than
## trust_needed banks nothing: zero crumbs, zero relays, trust never leaves 0.
func _scenario_elder_no_bread_airborne() -> void:
	var rig := _add_elder_rig()
	var spawner: ElderSpawner = rig[0]
	var crumbs: BreadSpawner = rig[1]
	Game.favor = 0 ## (T-114) Staged explicitly — a broke pigeon could never have paid anyway.
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
	Game.favor = 40 ## (T-114) Staged explicitly — enough favor for both shares and their spends.
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
## function that filled them. The face distance uses the footprint component
## ALONG the door-face normal (T-051: `size.x` on ±x faces, `size.y` on ±z).
func _expected_cafe_spot(city: City, info: Dictionary) -> Transform3D:
	var normal: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][
			int(info.door_face)]
	var lot: Vector2 = info.lot_offset
	var face_axis_x := absf(normal.x) > 0.5
	var along := Vector3(0.0, 0.0, signf(lot.y)) if face_axis_x \
			else Vector3(signf(lot.x), 0.0, 0.0)
	var face_out: float = (info.size as Vector2).x if face_axis_x \
			else (info.size as Vector2).y
	var pos: Vector3 = city.to_local(info.center) \
			+ normal * (face_out * 0.5 + 0.12 + 1.9) \
			+ along * 2.2
	pos.y = city.block_slab_height
	return Transform3D(Basis(Vector3.UP, atan2(-normal.x, -normal.z)), pos)


## Cafe tables (T-031, batched T-094): the city records one pure-layout spot
## per awninged building (the pinned 104 at the M1 seed; non-awninged
## buildings get none), every spot recomputable from its building's
## `door_face`/`size`/`lot_offset`, same-seed regeneration reproducing the
## spot list byte-identically, and a spawner rig seating the batched furniture
## exactly on the spots (`elder_placement_no_rng` template). Placement holds
## the street clearances: on the sidewalk band with the table center ≥ 0.5 m
## inside the tourist loop's 10.9 m curb line (square metrics — the loop legs
## are lines), ≥ 1.0 m off the block's PAVEMENT bread spots (bench seats; corner
## bread-ring spots lie outside every block's radius; since T-112 the pool read
## skips the kind-TABLE entries — a table's own tabletop crumb riding 0.25 m
## from its own spot is the feature, not a failure), ≥ 1.2 m edge-to-edge
## off the door line. Since T-094 the rig reads the batch: one positioned
## shape per piece under the two merged bodies (`Tables` layer 1 `world`,
## `Sitters` collision-layer value 4 — the retired scenes' value — mask 0
## both), sitters 1-2 per table by the even/odd spot rule (104 tables → 156)
## counted through the spawner exposure, shirts straight from the tourist
## palette by spot index read off the torso/arm MultiMesh instance colors —
## and a grounded pigeon can waddle up and perch beside a table, which stops
## the waddle dead (solid layer-1 furniture).
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
		## (T-112) The pool read SKIPS kind-TABLE entries: the clearance this leg
		## guards is cafe furniture vs pavement bread, and a table's own crumb
		## riding 0.25 m from its own spot is the feature, not a failure — the
		## skip restores the leg's exact pre-T-112 pool and semantics.
		var nearest: Vector3 = _city.block_centers[0]
		var best := INF
		for center in _city.block_centers:
			var d: float = Vector2(spot.origin.x - center.x,
					spot.origin.z - center.z).length_squared()
			if d < best:
				best = d
				nearest = center
		for b_i in _city.bread_spots.size():
			if _city.bread_spot_kinds[b_i] == City.BreadKind.TABLE:
				continue
			var bread: Vector3 = _city.bread_spots[b_i]
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
		## T-051: the face plane sits at the footprint extent along the normal.
		var face_out: float = (info.size as Vector2).x if face_axis_x \
				else (info.size as Vector2).y
		var face_center: Vector3 = _city.to_local(info.center) \
				+ normal * (face_out * 0.5 + 0.12)
		var along_dist: float = absf((spot.origin - face_center).dot(along_dir))
		door_ok = door_ok and along_dist - 0.475 - 0.45 >= 1.2
		spot_i += 1
	_city.generate(default_seed)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _spots_equal(spots, _city.cafe_spots)
	## Spawner rig over the real generated city (the elder-rig template). The
	## T-094 batch replaces the per-table nodes: the reads go through the
	## spawner's exposures — the two merged bodies (one shape per piece, in
	## build order = spot/seat order), the per-sitter records, and the
	## torso/arm per-instance shirt colors off the spawner's queues (the exact
	## values fed into `set_instance_color` — this engine build's headless
	## RenderingServer answers instance readbacks with identity/black, the
	## `city_crosswalks_present` caveat, so the queue is the per-instance
	## channel that can be asserted here; instance COUNTS do read back, and
	## the queue↔instance correspondence is anchored by them below).
	var spawner := CafeSpawner.new()
	spawner.city = _city
	add_child(spawner)
	await _wait_frames(4)
	var tables_body: StaticBody3D = spawner.tables_body
	var sitters_body: StaticBody3D = spawner.sitters_body
	var torso_mm: MultiMeshInstance3D = spawner.visual("sitter_torso")
	var arm_mm: MultiMeshInstance3D = spawner.visual("sitter_arm")
	var seated: bool = tables_body != null and sitters_body != null \
			and tables_body.get_child_count() == spots.size()
	var layers_ok: bool = tables_body != null and sitters_body != null \
			and tables_body.collision_layer == 1 and tables_body.collision_mask == 0 \
			and sitters_body.collision_layer == 4 and sitters_body.collision_mask == 0
	var count_ok_rig: bool = seated and spawner.sitters.size() > 0
	var shirts_ok: bool = seated
	var total_sitters := 0
	for i in spots.size():
		## The table's merged shape sits at the spot — the batched "seated"
		## read: the shape is the table footprint at (0, 0.36, 0) above it.
		var shape := tables_body.get_child(i) as CollisionShape3D
		seated = seated and shape.global_position.distance_to(
				_city.to_global((spots[i] as Transform3D).origin + Vector3(0.0, 0.36, 0.0))) < 0.01
		## The sitter side: count by the pure even/odd rule, then each seat's
		## shape on its seat transform and its shirt off the instance colors —
		## torso at the sitter's own ordinal, arms at 2× and 2×+1.
		count_ok_rig = count_ok_rig and spawner.sitter_count(i) == (2 if i % 2 == 0 else 1)
		for seat in spawner.sitter_count(i):
			var rec: Dictionary = spawner.sitters[total_sitters]
			var sitter_shape := sitters_body.get_child(total_sitters) as CollisionShape3D
			var sitter_xf: Transform3D = (spots[i] as Transform3D) * Transform3D(
					Basis(Vector3.UP, CafeSpawner.SITTER_YAWS[seat]),
					CafeSpawner.SITTER_SEATS[seat])
			seated = seated and rec.get("spot") == i and rec.get("seat") == seat \
					and sitter_shape.global_position.distance_to(
							_city.to_global(sitter_xf * CafeSpawner.SITTER_SHAPE_OFFSET)) < 0.01
			var expected: Color = Tourist.SHIRT_PALETTE[(i + seat) % Tourist.SHIRT_PALETTE.size()]
			shirts_ok = shirts_ok \
					and spawner.instance_color("sitter_torso", total_sitters).is_equal_approx(expected) \
					and spawner.instance_color("sitter_arm", total_sitters * 2).is_equal_approx(expected) \
					and spawner.instance_color("sitter_arm", total_sitters * 2 + 1).is_equal_approx(expected)
			total_sitters += 1
	## The batch is complete: one shape and one record per sitter, the torso
	## MultiMesh carrying one instance per sitter and the arm key one per arm
	## (anchoring the queue indices above to the live MultiMeshes), and the
	## even/odd total: 104 tables → 52 even × 2 + 52 odd × 1 = 156 sitters.
	count_ok_rig = count_ok_rig \
			and sitters_body.get_child_count() == total_sitters \
			and spawner.sitters.size() == total_sitters \
			and torso_mm.multimesh.instance_count == total_sitters \
			and arm_mm.multimesh.instance_count == 2 * total_sitters \
			and total_sitters == awnings + awnings / 2
	## A grounded pigeon waddles up and perches beside table 0 …
	var seat0: Vector3 = _city.to_global((spots[0] as Transform3D).origin)
	var table_basis: Basis = (spots[0] as Transform3D).basis
	var beside := seat0 + table_basis.x * 1.5 + Vector3(0.0, 0.5, 0.0)
	await _set_up(true, beside, Vector3.ZERO)
	await _await_grounded(120)
	var flat := Vector2(_player.position.x - seat0.x, _player.position.z - seat0.z)
	var perch_ok: bool = _player.is_grounded and flat.length() > 0.55 and flat.length() < 2.0
	## … and the table itself is solid: a waddle aimed straight into it stops at
	## its edge (parked street-side, past the tabletop, before the sitters' line).
	var street_side := seat0 - table_basis.z * 1.0 + Vector3(0.0, 0.5, 0.0)
	var to_table := seat0 - street_side
	to_table.y = 0.0
	await _set_up(true, street_side, Vector3.ZERO,
			rad_to_deg(atan2(-to_table.x, -to_table.z)))
	await _await_grounded(120)
	await _hold("pitch_up", 25)
	flat = Vector2(_player.position.x - seat0.x, _player.position.z - seat0.z)
	perch_ok = perch_ok and _player.is_grounded \
			and flat.length() > 0.5 and flat.length() < 0.8
	_check("city_cafe_tables_present",
			count_ok and recompute_ok and band_ok and bread_ok and door_ok
					and deterministic and seated and count_ok_rig and shirts_ok
					and layers_ok and perch_ok,
			("spots %d vs awnings %d, recompute=%s band=%s bread=%s door=%s det=%s, "
				+ "seated=%d tables, sitters=%d (rule=%s shirts=%s layers=%s), perch=%s") % [
						spots.size(), awnings, recompute_ok, band_ok, bread_ok, door_ok,
						deterministic, tables_body.get_child_count(), total_sitters,
						count_ok_rig, shirts_ok, layers_ok, perch_ok])
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
## in array order. Prop insets keep every center ≤ √2·0.25·footprint from the
## footprint center (≤ 2.51 m pre-T-051, ≤ 1.96 m at the 0.78-scaled minimum),
## so a prop can never sit inside a neighbor (lot centers are 8.5 m apart,
## footprints ≤ 7.1 m wide). T-051: the halves are per-axis — footprints vary
## per axis.
func _props_of(building: Dictionary) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var size: Vector2 = building.size
	var c: Vector3 = building.center
	for prop in _city.roof_props:
		var p: Vector3 = prop.center
		if absf(p.x - c.x) <= size.x * 0.5 and absf(p.z - c.z) <= size.y * 0.5:
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
## its roof (≥ 0.6 m from every edge since T-051, re-derived for the varying
## footprints: 0.25·5.54 − 0.7 ≈ 0.685 m at the 0.78-scaled minimum), centers
## at the exact corner-relative ±0.25·footprint inset per axis (≥ 1.9 m from
## the footprint center at the smallest — the `city_roof_landable` drop point
## at the exact center stays ≥ 0.96 m clear of the worst prop) with one
## layer-1 `world` shape each under the single Props group body (T-093) —
## and exactly one crumb spot
## in the never-propped (+,+) quadrant at roof-top + 0.06, so city-wide
## `bread_spots` grows by exactly the building count (8 ring spots × 49 blocks
## + one per bench seat + one per building) — plus, since T-091, one crumb per
## district anchor (4 at the M1 seed), the same y > 1.0 roof-spot population
## this scenario counts. A crumb instantiated at a low
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
	## T-091: the 4 district-anchor cap crumbs ride the same y > 1.0 population.
	var spots_ok: bool = spots_snapshot.size() \
			== _city.buildings.size() + _city.anchors.size() \
			and spots_snapshot.size() >= 20
	## City-wide pool: the T-005 ground spots, exactly the new roof spots and
	## exactly one crumb per district anchor (T-091) — plus, since T-112, one
	## TABLE spot per awninged building riding its own cafe table (the pool's
	## tail section; the y > 1.0 population above is untouched — tabletops sit
	## at slab + 0.78 < 1.0).
	var total_ok: bool = _city.bread_spots.size() \
			== _city.blocks_per_side * _city.blocks_per_side * 8 \
			+ int(_city.last_report.benches) + _city.buildings.size() \
			+ _city.anchors.size() + _city.cafe_spots.size()
	var one_per_building := true
	for info in _city.buildings:
		var props := _props_of(info)
		var size: Vector2 = info.size
		props_ok = props_ok and props.size() >= 1 and props.size() <= 3
		for prop in props:
			var c: Vector3 = prop.center
			var s: Vector3 = prop.size
			var flat := Vector2(c.x - info.center.x, c.z - info.center.z)
			## T-051 re-derivation (footprints vary per axis in [0.78, 1.0]·7.1):
			## the corner-relative inset law is pinned exactly per axis
			## (√2·0.25·5.54 ≈ 1.96 m at the smallest footprint — the exact-center
			## `city_roof_landable` drop stays ≥ 0.96 m clear of the worst prop,
			## the tank's 0.99 m half-diagonal), and the on-roof margin floor is
			## re-derived to 0.6 m (2.77 − 1.385 − 0.7 ≈ 0.685 m at the minimum).
			props_ok = props_ok \
					and flat.length() >= 1.9 \
					and absf(absf(flat.x) - size.x * 0.25) < 0.001 \
					and absf(absf(flat.y) - size.y * 0.25) < 0.001 \
					and size.x * 0.5 - absf(flat.x) - s.x * 0.5 >= 0.6 \
					and size.y * 0.5 - absf(flat.y) - s.z * 0.5 >= 0.6 \
					and absf((prop.top as float) - (info.top as float) - s.y) < 0.001
		## Exactly one roof spot per building, in the (+,+) quadrant mirrored by
		## lot_offset at ±0.28·footprint per axis — never a prop quadrant.
		var found := 0
		for spot in spots_snapshot:
			var g := _city.to_global(spot)
			var flat_s := Vector2(g.x - info.center.x, g.z - info.center.z)
			if absf(g.y - (info.top as float) - 0.06) > 0.001 \
					or absf(flat_s.x) > size.x * 0.5 or absf(flat_s.y) > size.y * 0.5:
				continue
			found += 1
			var lot: Vector2 = info.lot_offset
			one_per_building = one_per_building \
					and signf(flat_s.x) == signf(lot.x) \
					and signf(flat_s.y) == signf(lot.y) \
					and absf(absf(flat_s.x) - size.x * 0.28) < 0.001 \
					and absf(absf(flat_s.y) - size.y * 0.28) < 0.001
		one_per_building = one_per_building and found == 1
	## --- colliders (T-093): five group bodies under Static/, props as shapes ---
	## Static/ holds exactly one StaticBody3D per group — Ground/Roads/Blocks/
	## Buildings/Props, each layer 1 `world` mask 0 — and every collider is now
	## a shape child of its group body (no body nests under a body; the Ground
	## body's one extra child is the grass mesh). The Props body's shapes above
	## y 5.0 are the roof props — exactly roof_props.size() — plus, since T-091,
	## each district anchor's shaft/head/cap tiers (3 per anchor; the plinth's
	## center sits at slab+0.5, below the window).
	var static_root: Node = _city.get_node("Static")
	var bodies := 0
	var body_names := {}
	var layers_ok := true
	var shapes_only_ok := true
	for child in static_root.get_children():
		var group_body := child as StaticBody3D
		if group_body != null:
			bodies += 1
		body_names[child.name] = true
		layers_ok = layers_ok and group_body != null \
				and group_body.collision_layer == 1 and group_body.collision_mask == 0
		for nested in child.get_children():
			shapes_only_ok = shapes_only_ok and not (nested is StaticBody3D)
	var five_ok := bodies == 5 \
			and body_names.has("Ground") and body_names.has("Roads") \
			and body_names.has("Blocks") and body_names.has("Buildings") \
			and body_names.has("Props")
	var props_body := static_root.get_node_or_null("Props") as StaticBody3D
	var props_body_ok := props_body != null \
			and props_body.collision_layer == 1 and props_body.collision_mask == 0
	var high_shapes := 0
	if props_body_ok:
		for child in props_body.get_children():
			var prop_shape := child as CollisionShape3D
			if prop_shape != null and prop_shape.position.y > 5.0:
				high_shapes += 1
	var colliders_ok := five_ok and layers_ok and shapes_only_ok and props_body_ok \
			and high_shapes == _city.roof_props.size() + 3 * _city.anchors.size()
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
		var roof_size: Vector2 = roof.size
		var center_local := _city.to_local(roof.center)
		var spot_local := Vector3.INF
		for spot in _city.bread_spots:
			if spot.y > 1.0 and absf(spot.x - center_local.x) <= roof_size.x * 0.5 \
					and absf(spot.z - center_local.z) <= roof_size.y * 0.5:
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
			## (the spot sits 0.28·footprint ≈ 1.55–2.0 m out per axis — T-051:
			## footprints vary — so the drop stays on the roof, clear of the
			## propped quadrants), facing it.
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
					total_ok, one_per_building, colliders_ok, high_shapes,
					deterministic, physical_ok, eat_ok, prop_ok])
	## Informational: the M1-seed surface counts (146 buildings → 259 props,
	## 533 → 679 bread spots, +4 anchor crumbs since T-091 → 683, +104 tabletop
	## spots since T-112 → 787) — the tickets' tuned numbers, re-printed on
	## every re-verification.
	print("SIM DATA roofs_inhabited: buildings=%d roof_props=%d roof_spots=%d bread_spots=%d fingerprint=%d" % [
			_city.buildings.size(), _city.roof_props.size(), spots_snapshot.size(),
			_city.bread_spots.size(), fp_first])


## --- scenarios (T-112 weighted bread distribution) ---------------------------


## The live-crumb tally per bread kind, read through the scenario's OWN kind
## array read (`City.bread_spot_kinds[crumb.spot_index]`) — never through
## spawner internals. Hand-placed crumbs (spot_index < 0) belong to no class.
func _live_tally(city: City, spawner: BreadSpawner) -> Array[int]:
	var tally: Array[int] = [0, 0, 0] ## BreadKind order: GROUND, TABLE, ROOF.
	for crumb in spawner.living_crumbs():
		if crumb.spot_index >= 0 and crumb.spot_index < city.bread_spot_kinds.size():
			tally[city.bread_spot_kinds[crumb.spot_index]] += 1
	return tally


## The living crumbs' world positions as a sorted multiset — the byte-identical
## compare of the determinism leg (the `_vec_spots_equal` pattern).
func _crumb_multiset(spawner: BreadSpawner) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for crumb in spawner.living_crumbs():
		out.append(crumb.global_position)
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		if a.x != b.x:
			return a.x < b.x
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z)
	return out


## The T-112 weighted spread (Gate 1b): on a real generated City + a
## `BreadSpawner` rig at the shipped target 40, `_populate` opens the class
## quotas — exactly 36 TABLE / 3 GROUND / 1 ROOF at the M1 seed AND at seed
## 424242 — with every crumb sitting exactly on its spot's `to_global`.
## City-side, `bread_spot_kinds` stays index-aligned with `bread_spots`, the
## M1 class tally is exact (GROUND 533 = 392 ring + 141 bench, ROOF 150 =
## 146 + 4 anchors, TABLE 104 = the awninged buildings — 787 total) and every
## TABLE spot sits exactly at the tabletop law recomputed from the building
## record (`cafe_spot.origin + basis.x * 0.25 + UP * 0.78`, XZ inside the
## 0.9 m top). Determinism: a force-rebuild re-populates the identical crumb
## position multiset with the fingerprint pinned. Top-ups follow the same law:
## 10 eaten TABLE crumbs (the `crumbs_respawn` path) refill TABLE to quota in
## one `respawn_interval`, GROUND and ROOF untouched. The overflow safety net:
## the TABLE class synthetically shrunk to 10 free spots (arrays reassigned on
## the city object, then re-populate) spills its deficit to GROUND (3 + 26 =
## 29) while ROOF stays capped at its quota — "rare" is a ceiling; ROOF never
## exceeds 1 live crumb in any leg. And a tabletop crumb is an ordinary
## reachable crumb: the pigeon drops onto the tabletop beside it (the
## bench-landing geometry), settles grounded and feeds +30 through the Main
## wiring (`crumb_eaten` → Hunger.eat) — the 0.9 m top sits fully inside the
## crumb's 1.4 m grounded eat reach, so the feed can fire on the settle frame;
## the waddle-in drive is still held, only its timing is not pinned.
func _scenario_bread_distribution_weighted() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	## --- city-side audit: kinds aligned, M1 tally exact, TABLE spots exact ---
	var kinds_ok: bool = _city.bread_spot_kinds.size() == _city.bread_spots.size()
	var tally: Array[int] = [0, 0, 0] ## BreadKind order: GROUND, TABLE, ROOF.
	var table_indices: Array[int] = []
	for i in _city.bread_spots.size():
		var kind: int = _city.bread_spot_kinds[i]
		kinds_ok = kinds_ok and kind >= City.BreadKind.GROUND and kind <= City.BreadKind.ROOF
		tally[kind] += 1
		if kind == City.BreadKind.TABLE:
			table_indices.append(i)
	var awninged: Array[Dictionary] = []
	for info in _city.buildings:
		if info.has_awning:
			awninged.append(info)
	var ground_expected: int = _city.blocks_per_side * _city.blocks_per_side * 8 \
			+ int(_city.last_report.benches)
	var tally_ok: bool = tally[City.BreadKind.GROUND] == 533 \
			and tally[City.BreadKind.TABLE] == 104 and tally[City.BreadKind.ROOF] == 150 \
			and _city.bread_spots.size() == 787 \
			and tally[City.BreadKind.GROUND] == ground_expected \
			and tally[City.BreadKind.ROOF] == _city.buildings.size() + _city.anchors.size() \
			and tally[City.BreadKind.TABLE] == awninged.size()
	## Every TABLE spot exactly at the tabletop law, recomputed from the
	## building record (the `_expected_cafe_spot` pattern) — and its XZ inside
	## the 0.9 m top (|local offset| ≤ 0.45 per axis in the table frame).
	var spots_exact := table_indices.size() == awninged.size()
	for k in table_indices.size():
		var cafe: Transform3D = _expected_cafe_spot(_city, awninged[k])
		var want: Vector3 = cafe.origin + cafe.basis.x * 0.25 + Vector3(0.0, 0.78, 0.0)
		var got: Vector3 = _city.bread_spots[table_indices[k]]
		var local: Vector3 = got - _city.cafe_spots[k].origin
		var in_top := Vector2(local.dot(_city.cafe_spots[k].basis.x),
				local.dot(_city.cafe_spots[k].basis.z))
		spots_exact = spots_exact and got.distance_to(want) < 0.01 \
				and absf(got.y - (_city.block_slab_height + 0.78)) < 0.001 \
				and absf(in_top.x) <= 0.45 and absf(in_top.y) <= 0.45
	## --- the seeded rig at the shipped target: 36 TABLE / 3 GROUND / 1 ROOF --
	var rig := BreadSpawner.new()
	rig.city = _city
	rig.respawn_interval = 0.5 ## The top-up leg's cadence (the respawn-rig value).
	add_child(rig)
	await _wait_frames(4)
	var open_tally := _live_tally(_city, rig)
	var dist_ok: bool = open_tally[City.BreadKind.TABLE] == 36 \
			and open_tally[City.BreadKind.GROUND] == 3 \
			and open_tally[City.BreadKind.ROOF] == 1 \
			and rig.living_crumbs().size() == 40
	var on_spots := dist_ok
	for crumb in rig.living_crumbs():
		if crumb.spot_index < 0:
			on_spots = false
			continue
		on_spots = on_spots and crumb.global_position.distance_to(
				_city.to_global(_city.bread_spots[crumb.spot_index])) < 0.01
	var roof_seen: int = open_tally[City.BreadKind.ROOF]
	## --- determinism: force-rebuild + re-populate → identical multiset -------
	var before := _crumb_multiset(rig)
	_city.generate(default_seed, true) ## regenerated → the rig re-populates.
	var deterministic: bool = _city.fingerprint == fp_first \
			and _vec_spots_equal(before, _crumb_multiset(rig)) \
			and _live_tally(_city, rig) == open_tally
	## --- top-ups follow the law: 10 eaten TABLE crumbs refill from tables ----
	var eaten_tables: Array[BreadCrumb] = []
	for crumb in rig.living_crumbs():
		if crumb.spot_index >= 0 \
				and _city.bread_spot_kinds[crumb.spot_index] == City.BreadKind.TABLE:
			eaten_tables.append(crumb)
			if eaten_tables.size() == 10:
				break
	var topup_ok := eaten_tables.size() == 10
	for crumb in eaten_tables:
		crumb.eaten.emit(crumb.restore) ## Same path a grounded pigeon triggers.
		crumb.free()
	await _wait_frames(45) ## 0.75 s > respawn_interval.
	var after_tally := _live_tally(_city, rig)
	topup_ok = topup_ok and after_tally[City.BreadKind.TABLE] == 36 \
			and after_tally[City.BreadKind.GROUND] == 3 \
			and after_tally[City.BreadKind.ROOF] == 1 \
			and rig.living_crumbs().size() == 40 and rig.eaten_count == 10
	roof_seen = maxi(roof_seen, after_tally[City.BreadKind.ROOF])
	rig.respawn_interval = 60.0 ## No further top-up inside the shrink leg's window.
	## --- overflow: the TABLE class shrunk to 10 free spots, re-populate ------
	var shrunk_spots: Array[Vector3] = []
	var shrunk_kinds: Array[int] = []
	var kept := 0
	for i in _city.bread_spots.size():
		if _city.bread_spot_kinds[i] == City.BreadKind.TABLE:
			kept += 1
			if kept > 10:
				continue
		shrunk_spots.append(_city.bread_spots[i])
		shrunk_kinds.append(_city.bread_spot_kinds[i])
	_city.bread_spots = shrunk_spots
	_city.bread_spot_kinds = shrunk_kinds
	rig._populate() ## The re-populate under the shrunken class.
	var over_tally := _live_tally(_city, rig)
	var overflow_ok: bool = over_tally[City.BreadKind.TABLE] == 10 \
			and over_tally[City.BreadKind.GROUND] == 29 \
			and over_tally[City.BreadKind.ROOF] == 1 \
			and rig.living_crumbs().size() == 40
	roof_seen = maxi(roof_seen, over_tally[City.BreadKind.ROOF])
	## --- the physical leg: a tabletop crumb feeds a grounded pigeon ----------
	_city.generate(default_seed, true) ## Restore the full pool (undoes the shrink).
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	rig.crumb_eaten.connect(hunger.eat) ## The Main wiring, on the same rig.
	## A living TABLE crumb, read through the kind array (the shuffle decides
	## WHICH table) — its spot's TABLE ordinal recovers the table's own
	## transform (append-order parity: the k-th TABLE spot is cafe_spots[k]).
	var table_crumb: BreadCrumb = null
	var table_ordinal := -1
	for crumb in rig.living_crumbs():
		if crumb.spot_index >= 0 \
				and _city.bread_spot_kinds[crumb.spot_index] == City.BreadKind.TABLE:
			table_crumb = crumb
			table_ordinal = 0
			for i in crumb.spot_index:
				if _city.bread_spot_kinds[i] == City.BreadKind.TABLE:
					table_ordinal += 1
			break
	var eat_ok := table_crumb != null
	var grounded_on_top := false
	if eat_ok:
		## The tabletop is a solid layer-1 box only once the cafe batch stands —
		## the `city_cafe_tables_present` rig pattern (that scenario frees its
		## own rig at its end, so this leg seats a fresh one).
		var cafe_rig := CafeSpawner.new()
		cafe_rig.city = _city
		add_child(cafe_rig)
		await _wait_frames(4)
		var cafe: Transform3D = _city.cafe_spots[table_ordinal]
		var spot_global := _city.to_global(_city.bread_spots[table_crumb.spot_index])
		var toward := -cafe.basis.x ## From the crumb back across the tabletop.
		var walk_dir := -toward ## The waddle aims at the crumb (+basis.x).
		hunger.value = 40.0 ## Mid-bar so the +30 restore is measurable.
		var hunger0 := hunger.value ## Baseline BEFORE the drop: the feed can fire
		## on the settle frame (the whole top sits inside the crumb's grounded
		## eat reach), so a post-grounding baseline would already hold the +30.
		await _set_up(true, spot_global + toward * 0.6 + Vector3(0.0, 0.9, 0.0),
				Vector3.ZERO, rad_to_deg(atan2(-walk_dir.x, -walk_dir.z)))
		await _await_grounded(150) ## The bench_landing budget (softened-gravity fall).
		grounded_on_top = _player.is_grounded \
				and absf(_player.position.y - (spot_global.y + 0.24)) < 0.25
		Input.action_press("pitch_up") ## The waddle-in drive.
		for _i in 120:
			await get_tree().physics_frame
			eat_ok = not is_instance_valid(table_crumb) \
					and hunger.value > hunger0 + 10.0
			if eat_ok:
				break
		Input.action_release("pitch_up")
		cafe_rig.free()
	hunger.free()
	## --- the foreign seed opens the same law: 36 / 3 / 1 at seed 424242 ------
	_city.generate(424242, true)
	var foreign_rig := BreadSpawner.new()
	foreign_rig.city = _city
	foreign_rig.respawn_interval = 60.0
	add_child(foreign_rig)
	await _wait_frames(4)
	var foreign_tally := _live_tally(_city, foreign_rig)
	var foreign_ok: bool = foreign_tally[City.BreadKind.TABLE] == 36 \
			and foreign_tally[City.BreadKind.GROUND] == 3 \
			and foreign_tally[City.BreadKind.ROOF] == 1 \
			and foreign_rig.living_crumbs().size() == 40 \
			and _city.bread_spot_kinds.size() == _city.bread_spots.size()
	var foreign_awnings := 0
	var foreign_tables := 0
	for i in _city.buildings.size():
		if _city.buildings[i].has_awning:
			foreign_awnings += 1
	for kind: int in _city.bread_spot_kinds:
		if kind == City.BreadKind.TABLE:
			foreign_tables += 1
	foreign_ok = foreign_ok and foreign_tables == foreign_awnings
	roof_seen = maxi(roof_seen, foreign_tally[City.BreadKind.ROOF])
	foreign_rig.free()
	_city.generate(default_seed, true) ## Leave the M1 city standing, pool restored.
	_check("bread_distribution_weighted",
			kinds_ok and tally_ok and spots_exact and dist_ok and on_spots
					and deterministic and topup_ok and overflow_ok
					and grounded_on_top and eat_ok and foreign_ok and roof_seen <= 1,
			("kinds=%s tally(G/T/R)=%s spots_exact=%s open 36/3/1=%s on_spots=%s "
				+ "det=%s topup=%s overflow 10/29/1=%s grounded_top=%s eat=%s "
				+ "foreign 36/3/1=%s roof_max=%d") % [
					kinds_ok, tally, spots_exact, dist_ok, on_spots, deterministic,
					topup_ok, overflow_ok, grounded_on_top, eat_ok, foreign_ok,
					roof_seen])
	rig.free()


## Zebra crosswalks (T-069, bars re-oriented longitudinal by T-102): the
## `Visuals/Crosswalk` MultiMesh carries exactly 2,240 bars with default exports
## (224 bands x 10 — every unblocked intersection approach, the 32 rim outward
## approaches skipped), every bar is an axis-aligned 2.4 along-road x 0.5
## across x 0.01 box at the right dash-family height (horizontal roads at
## `road_slab_height`, vertical at `road_slab_height + 0.005`), every bar center
## sits >= 5.0 m from every intersection node in XZ (the 3.5 m corner-cut swing
## area stays clear), every bar stays on its approach road's asphalt (its
## across-extent inside the road edges, its along-coordinate inside the city),
## the bar multiset matches an independent recomputation (per unblocked
## approach, one 2.4 m-deep band centered 6.2 m out on the road centerline,
## tiled by road_width / 1.0 = 10 bars running WITH the road, repeating ACROSS
## it at a 1.0 m pitch on centers — the `_expected_cafe_spot` pattern), a forced
## same-seed rebuild reproduces all transforms byte-identically (`_spots_equal`,
## the `elder_placement_no_rng` pattern), the paint is visual-only (no
## StaticBody3D anywhere under `Visuals`), and the fingerprint stays
## byte-identical (zero RNG, zero `_fp` entries).
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
	var count_ok: bool = mm.instance_count == 2240 and queue.size() == 2240
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
	## Expected bar centers: per node, per approach whose band stays on the
	## asphalt (outer band edge node + side * 7.4 m inside ± half), one 2.4 m
	## deep band centered 6.2 m out — ten bars running WITH the road, repeating
	## ACROSS it at a 1.0 m pitch on centers (T-102 longitudinal zebra).
	var expected: Array[Vector3] = []
	for cx: float in centers:
		for cz: float in centers:
			for axis: int in 2: ## 0 = ±x approaches (horizontal road), 1 = ±z (vertical road).
				for side: float in [1.0, -1.0]:
					var node_c: float = cx if axis == 0 else cz
					if absf(node_c + side * 7.4) > half:
						continue ## The band would leave the asphalt.
					var out: float = side * 6.2
					for k in 10:
						var across: float = (float(k) - 4.5) * 1.0
						expected.append(Vector3(
								cx + (out if axis == 0 else across),
								slab_y if axis == 0 else slab_y + 0.005,
								cz + (across if axis == 0 else out)))
	count_ok = count_ok and expected.size() == 2240
	## Per-bar geometry / y-family / clearance / asphalt-rect criteria, plus a
	## multiset match against the expected centers (each expected bar exactly
	## once proves the 10-per-unblocked-approach placement at the 1.0 m pitch).
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
		## Bars run ALONG the road (2.4 m deep) and repeat ACROSS it (0.5 m wide)
		## — the T-102 flip of T-069's transverse piano-key band.
		var along_x := absf(sc.x - 2.4) < 0.001 and absf(sc.z - 0.5) < 0.001
		var along_z := absf(sc.z - 2.4) < 0.001 and absf(sc.x - 0.5) < 0.001
		geometry_ok = geometry_ok and (along_x or along_z) and absf(sc.y - 0.01) < 0.001
		y_ok = y_ok and absf(o.y - (slab_y if along_x else slab_y + 0.005)) < 0.001
		var nearest := INF
		for node_pos in nodes:
			nearest = minf(nearest, Vector2(o.x - node_pos.x, o.z - node_pos.y).length())
		clear_ok = clear_ok and nearest >= 5.0
		## On its approach road's asphalt: the across-extent (center ± 0.25 m)
		## stays inside that road's edges, the along-coordinate inside the city.
		var across_c: float = o.z if along_x else o.x
		var along_c: float = o.x if along_x else o.z
		var near_center: float = centers[0]
		for c: float in centers:
			if absf(across_c - c) < absf(across_c - near_center):
				near_center = c
		asphalt_ok = asphalt_ok \
				and absf(across_c - near_center) + 0.25 <= road_w * 0.5 + 0.001 \
				and absf(along_c) <= half + 0.001
		for e in expected.size():
			if not matched[e] and (expected[e] - o).length_squared() < 1e-8:
				matched[e] = true
				break
	var placement_ok: bool = count_ok
	for m in matched:
		placement_ok = placement_ok and m
	## A forced same-seed rebuild reproduces all 2,240 transforms byte-identically.
	var xfs_a := xfs.duplicate()
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces them.
	var mm_b := (_city.get_node("Visuals/Crosswalk") as MultiMeshInstance3D).multimesh
	var queue_b: Array = _city._visuals["crosswalk"].xfs
	var xfs_b: Array[Transform3D] = []
	for xf: Transform3D in queue_b:
		xfs_b.append(xf)
	var deterministic: bool = mm_b.instance_count == 2240 and queue_b.size() == 2240 \
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
	print("SIM DATA city_crosswalks: bars=%d bands=%d fingerprint=%d" % [
			xfs.size(), xfs.size() / 10, fp_first])


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
## 4045370482, seed 424242 → 533171164 — the values moved for T-051's
## mandated two-axis footprint `_fp` entry, re-derived 2026-10-01 with a
## headless `City.generate` probe (pre-T-051: 2492360539 / 2662825400), again
## for T-029's plaza-landmark `_fp` entry, same probe (pre-T-029:
## 4188136223 / 547420287), again for T-091's four district-anchor `_fp`
## entries, same probe (pre-T-091: 1006789400 / 3359332191), and again for
## T-104's four plaza-bin `_fp` x/z entries, same probe
## (pre-T-104: 650664268 / 4031380170)).
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
	## --- cross-version pins (moved for T-051's `_fp` entry, T-029's and -------
	## T-091's four district-anchor entries, T-104's four plaza-bin entries)
	_city.generate(424242)
	var pin_foreign: bool = _city.fingerprint == 533171164
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	var pin_default: bool = _city.fingerprint == 4045370482
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
	var pin_foreign: bool = _city.fingerprint == 533171164 \
			and _city._visuals["skyline_tall"].xfs.size() != tall_xfs.size()
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	var pin_default: bool = _city.fingerprint == 4045370482
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


## Park trees (T-030): four per park block at the fixed (±5, ±5) offsets —
## audited like the rim (`city_apron_rim_present` pattern). Counts = 4 × the
## reported park count off the TreeTrunk/TreeCrown MultiMesh queues; the park
## blocks recomputed independently from the slab queue (exactly the slabs
## wearing COLOR_PARK); every trunk (1.1 m up on the slab) and crown (3.3 m
## up, bottom at trunk top) over exactly one expected offset, every tree fully
## inside its block footprint; the crown green ≥ 0.15 Euclidean RGB from
## COLOR_PARK (the lawn — distance printed informationally); every tree ≥ 2.0 m
## XZ from every `bread_spots` entry at the M1 seed (includes the bench seats)
## plus the constants-level ≥ 1.5 m lamp/bin arithmetic that holds at every
## seed; zero CollisionObject3D under the Visuals root; a forced same-seed
## rebuild reproducing both instance queues byte-identically; a foreign seed
## keeping the 4 × parks law; and the layout fingerprint still equal to the
## cross-version pins (see `_scenario_city_apron_rim`).
##
## Transform source: the queues that feed the two MultiMeshes
## (`MultiMesh.get_instance_transform` reads back identity headless — the
## `city_crosswalks_present` note).
func _scenario_city_park_trees() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var parks: int = _city.last_report.parks
	## Park block centers, recomputed independently: the slab queue wears
	## COLOR_PARK on exactly the park blocks (plaza wears COLOR_PLAZA, every
	## other block COLOR_SIDEWALK). The slab instance sits at center
	## + UP * block_slab_height * 0.5.
	var park_centers: Array[Vector3] = []
	var slab_xfs: Array = _city._visuals["slab"].xfs
	var slab_colors: Array = _city._visuals["slab"].colors
	for i in slab_xfs.size():
		if slab_colors[i] == _city.COLOR_PARK:
			park_centers.append((slab_xfs[i] as Transform3D).origin)
	var expected_count := 4 * parks
	var count_ok: bool = park_centers.size() == parks \
			and (_city._visuals["tree_trunk"].xfs as Array).size() == expected_count \
			and (_city._visuals["tree_crown"].xfs as Array).size() == expected_count
	## Expected tree bases: the four fixed offsets of every park center, on the
	## slab (y = block_slab_height).
	var expected_pos: Array[Vector3] = []
	var expected_center: Array[Vector3] = []
	for c: Vector3 in park_centers:
		for sx: float in [1.0, -1.0]:
			for sz: float in [1.0, -1.0]:
				expected_pos.append(Vector3(
						c.x + sx * _city.PARK_TREE_OFFSET, _city.block_slab_height,
						c.z + sz * _city.PARK_TREE_OFFSET))
				expected_center.append(c)
	## --- trunks and crowns, off the actual MultiMesh queues -------------------
	var trunk_xfs: Array[Transform3D] = []
	var crown_xfs: Array[Transform3D] = []
	if _city._visuals.has("tree_trunk"):
		for xf: Transform3D in _city._visuals["tree_trunk"].xfs:
			trunk_xfs.append(xf)
	if _city._visuals.has("tree_crown"):
		for xf: Transform3D in _city._visuals["tree_crown"].xfs:
			crown_xfs.append(xf)
	## --- geometry: heights, one offset each, fully inside the block ----------
	var trees_3d_ok: bool = count_ok
	for xf: Transform3D in trunk_xfs:
		trees_3d_ok = trees_3d_ok and absf(xf.origin.y
				- (_city.block_slab_height + _city.PARK_TRUNK_SIZE.y * 0.5)) < 0.001
	for xf: Transform3D in crown_xfs:
		trees_3d_ok = trees_3d_ok and absf(xf.origin.y
				- (_city.block_slab_height + _city.PARK_CROWN_CENTER_Y)) < 0.001
	var place_ok: bool = count_ok
	var inside_ok: bool = count_ok
	var crown_matched: Array[bool] = []
	crown_matched.resize(expected_pos.size())
	crown_matched.fill(false)
	var crown_half := _city.PARK_CROWN_SIZE.x * 0.5
	for xf: Transform3D in crown_xfs:
		var o: Vector3 = xf.origin
		var hit := false
		for e in expected_pos.size():
			if crown_matched[e]:
				continue
			var ep: Vector3 = expected_pos[e]
			if Vector2(o.x - ep.x, o.z - ep.z).length_squared() < 1e-8:
				crown_matched[e] = true
				hit = true
				var c: Vector3 = expected_center[e]
				inside_ok = inside_ok \
						and absf(o.x - c.x) + crown_half <= _city.block_size * 0.5 + 0.001 \
						and absf(o.z - c.z) + crown_half <= _city.block_size * 0.5 + 0.001
				break
		place_ok = place_ok and hit
	var trunk_matched: Array[bool] = []
	trunk_matched.resize(expected_pos.size())
	trunk_matched.fill(false)
	for xf: Transform3D in trunk_xfs:
		var o: Vector3 = xf.origin
		var hit := false
		for e in expected_pos.size():
			if trunk_matched[e]:
				continue
			var ep: Vector3 = expected_pos[e]
			if Vector2(o.x - ep.x, o.z - ep.z).length_squared() < 1e-8:
				trunk_matched[e] = true
				hit = true
				break
		place_ok = place_ok and hit
	## --- the crowns read against their own lawn: green vs COLOR_PARK ---------
	var crown_green := _mm_mesh_albedo(_city, "Visuals/TreeCrown")
	var crown_dist := _rgb(crown_green).distance_to(_rgb(_city.COLOR_PARK))
	var green_ok := crown_dist >= 0.15
	## --- clearance: trees vs everything sharing a park block ------------------
	var clear_ok := true
	var worst_bread := INF
	for xf: Transform3D in trunk_xfs:
		for spot: Vector3 in _city.bread_spots:
			var d := Vector2(xf.origin.x - spot.x, xf.origin.z - spot.z).length()
			worst_bread = minf(worst_bread, d)
			clear_ok = clear_ok and d >= 2.0
	## The lamp/bin half at every seed: worst center-to-center approach is a
	## max-jitter bin at (9−1, 9−1) from a tree at (5, 5) — 4.24 m — against
	## the crown's horizontal half-diagonal plus a ~0.9 m worst prop
	## half-extent (the bench).
	var center_dist := Vector2(5.0, 5.0).distance_to(Vector2(8.0, 8.0))
	var crown_half_diag := sqrt(2.0) * crown_half
	var arithmetic_ok := center_dist - crown_half_diag - 0.9 >= 1.5
	## --- visual-only: zero colliders anywhere under the Visuals root ----------
	var visuals := _city.get_node("Visuals") as Node3D
	var colliders := visuals.find_children("*", "CollisionObject3D", true, false)
	var visual_only := colliders.is_empty()
	## --- determinism: a real rebuild reproduces both queues byte-identically --
	var trunk_a := trunk_xfs.duplicate()
	var crown_a := crown_xfs.duplicate()
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces them.
	var trunk_b: Array[Transform3D] = []
	var crown_b: Array[Transform3D] = []
	for xf: Transform3D in _city._visuals["tree_trunk"].xfs:
		trunk_b.append(xf)
	for xf: Transform3D in _city._visuals["tree_crown"].xfs:
		crown_b.append(xf)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _spots_equal(trunk_a, trunk_b) and _spots_equal(crown_a, crown_b)
	## --- foreign seed keeps the 4 × parks law; cross-version pins hold --------
	_city.generate(424242)
	var foreign_parks: int = _city.last_report.parks
	var foreign_ok: bool = (_city._visuals["tree_trunk"].xfs as Array).size() == 4 * foreign_parks \
			and (_city._visuals["tree_crown"].xfs as Array).size() == 4 * foreign_parks
	var pin_foreign: bool = _city.fingerprint == 533171164
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	var pin_default: bool = _city.fingerprint == 4045370482
	var trees_detail := "parks=%d trees=%d/%d centers=%d place=%s inside=%s trees_3d=%s green=%s (%.3f) clear=%s (worst %.2f m) arith=%s (%.2f m margin) colliders=%d det=%s foreign=%s pins=%s/%s" % [
			parks, trunk_xfs.size(), expected_count, park_centers.size(), place_ok,
			inside_ok, trees_3d_ok, green_ok, crown_dist, clear_ok, worst_bread,
			arithmetic_ok, center_dist - crown_half_diag - 0.9, colliders.size(),
			deterministic, foreign_ok, pin_foreign, pin_default]
	_check("city_park_trees_present",
			count_ok and place_ok and inside_ok and trees_3d_ok and green_ok
					and clear_ok and arithmetic_ok and visual_only and deterministic
					and foreign_ok and pin_foreign and pin_default,
			trees_detail)
	## Informational: the park trees' tuned numbers — the ticket's counts and
	## distances, re-printed on every re-verification.
	print("SIM DATA city_park_trees: parks=%d trees=%d crown_green_dist=%.3f worst_bread_dist=%.2f fingerprint=%d" % [
			parks, trunk_xfs.size(), crown_dist, worst_bread, fp_first])


## --- scenario (T-029 plaza landmark) -----------------------------------------


## The plaza landmark: exactly one bronze-pigeon-on-a-plinth statue stands at
## the plaza center every run, built like every city visual — MultiMesh boxes
## at fixed offsets, zero RNG anywhere (one `_fp` entry, so the same-seed
## fingerprint tracks it). The legs: layout — the plinth and figure boxes sit
## on the plaza center, the whole footprint inside `spawn_clear_radius`, the
## top under both `max_roof_height` and the 23 m cruise floor, the stone read
## against the pale slab, the `_fp` entry singular; collision — ONE layer-1
## `Props` box over the plinth whose top face is the cap top, and nothing
## solid higher in the center column (the figure is visual-only, the T-017
## decision); determinism — a forced same-seed rebuild reproduces every
## landmark transform byte-identically; landing — a drop onto the cap settles
## grounded at cap height and a flap takes off again (the bench template);
## flyover — a flap-assisted straight pass along x THROUGH the plaza center
## at cruise altitude crosses the city without touching anything (the
## `city_street_flyover` template, flown over the landmark's column).
func _scenario_city_plaza_landmark() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var plaza: Vector3 = _city._plaza_center ## City-local origin of the plaza block.
	var slab: float = _city.block_slab_height
	## --- the landmark queues: plinth + figure boxes, one XZ position ----------
	var plinth_xfs: Array[Transform3D] = []
	var figure_xfs: Array[Transform3D] = []
	if _city._visuals.has("plinth"):
		for xf: Transform3D in _city._visuals["plinth"].xfs:
			plinth_xfs.append(xf)
	if _city._visuals.has("figure"):
		for xf: Transform3D in _city._visuals["figure"].xfs:
			figure_xfs.append(xf)
	var count_ok: bool = plinth_xfs.size() == 2 and figure_xfs.size() >= 5
	var landmark_fp := 0
	for entry in _city._fp:
		if (entry as Array)[0] == "landmark":
			landmark_fp += 1
	var fp_ok: bool = landmark_fp == 1
	## --- placement: centered, inside the spawn-clear radius, under the roofs -
	var place_ok: bool = count_ok
	var inside_ok: bool = count_ok
	var top := 0.0
	for source: Array in [plinth_xfs, figure_xfs]:
		for xf: Transform3D in source:
			var o: Vector3 = xf.origin
			var sc: Vector3 = xf.basis.get_scale()
			var center_dist := Vector2(o.x - plaza.x, o.z - plaza.z).length()
			place_ok = place_ok and center_dist <= 2.5
			var half_diag := 0.5 * sqrt(sc.x * sc.x + sc.z * sc.z)
			inside_ok = inside_ok and center_dist + half_diag <= _city.spawn_clear_radius
			top = maxf(top, o.y + sc.y * 0.5)
	var height_ok: bool = top < _city.max_roof_height and top < 23.0 and top <= slab + 5.5
	## --- the stone reads against the pale slab -------------------------------
	var stone := _mm_mesh_albedo(_city, "Visuals/Plinth")
	var bronze := _mm_mesh_albedo(_city, "Visuals/Figure")
	var color_ok: bool = stone.is_equal_approx(_city.COLOR_STONE) \
			and bronze.is_equal_approx(_city.COLOR_BRONZE) \
			and _rgb(stone).distance_to(_rgb(_city.COLOR_PLAZA)) >= 0.15
	## --- collision: ONE plinth box, nothing solid higher in the column --------
	var props := _city.get_node("Static/Props") as StaticBody3D
	var plinth_colliders := 0
	for shape in props.find_children("*", "CollisionShape3D", true, false):
		var shape3d := (shape as CollisionShape3D)
		var box := shape3d.shape as BoxShape3D
		if box == null:
			continue
		var pos := shape3d.position
		if Vector2(pos.x - plaza.x, pos.z - plaza.z).length() < 0.01 \
				and box.size.distance_to(Vector3(
						_city.LANDMARK_PLINTH_BASE.x, _city.LANDMARK_PLINTH_TOP,
						_city.LANDMARK_PLINTH_BASE.z)) < 0.01 \
				and absf(pos.y - (plaza.y + slab + _city.LANDMARK_PLINTH_TOP * 0.5)) < 0.01:
			plinth_colliders += 1
	var cap_top: float = plaza.y + slab + _city.LANDMARK_PLINTH_TOP
	var column_clear: bool = plinth_colliders == 1
	for body in _city.get_node("Static").get_children():
		for shape in (body as Node).find_children("*", "CollisionShape3D", true, false):
			var shape3d := (shape as CollisionShape3D)
			var pos := shape3d.position
			if Vector2(pos.x - plaza.x, pos.z - plaza.z).length() >= 2.0:
				continue
			var solid_top := -INF
			if shape3d.shape is BoxShape3D:
				solid_top = pos.y + (shape3d.shape as BoxShape3D).size.y * 0.5
			elif shape3d.shape is CylinderShape3D:
				solid_top = pos.y + (shape3d.shape as CylinderShape3D).height * 0.5
			elif shape3d.shape is SphereShape3D:
				solid_top = pos.y + (shape3d.shape as SphereShape3D).radius
			if solid_top > cap_top + 0.01:
				column_clear = false
	## --- determinism: a real rebuild reproduces the landmark byte-identically -
	var plinth_a := plinth_xfs.duplicate()
	var figure_a := figure_xfs.duplicate()
	_city.generate(default_seed, true) ## force_rebuild: prove a REAL rebuild reproduces them.
	var plinth_b: Array[Transform3D] = []
	var figure_b: Array[Transform3D] = []
	for xf: Transform3D in _city._visuals["plinth"].xfs:
		plinth_b.append(xf)
	for xf: Transform3D in _city._visuals["figure"].xfs:
		figure_b.append(xf)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _spots_equal(plinth_a, plinth_b) and _spots_equal(figure_a, figure_b)
	## --- flyover: straight pass along x THROUGH the plaza center --------------
	var half: float = _city.city_span * 0.5
	var x_start: float = _city.position.x - half + 4.0
	var x_end: float = _city.position.x + half - 4.0
	var z_center: float = _city.position.z + plaza.z
	await _set_up(true, Vector3(x_start, 26.0, z_center), Vector3(14.0, 0.0, 0.0), -90.0)
	var min_y := 1000.0
	var max_drift := 0.0
	var finite := true
	var crossed := false
	for i in 1500:
		await get_tree().physics_frame
		if i % 24 == 0 and _player.position.y < 28.0:
			await _tap("flap") ## The flyover cadence — pace the climb, ride the glide across.
		min_y = minf(min_y, _player.position.y)
		max_drift = maxf(max_drift, absf(_player.position.z - z_center))
		finite = finite and _player.velocity.is_finite() and _player.position.is_finite()
		if _player.position.x >= x_end:
			crossed = true
			break
	var flyover_ok: bool = crossed and min_y > 20.0 and max_drift < 6.0 and finite
	## --- landing: the plinth cap is a perch (the bench-landing template) ------
	await _set_up(true, _city.to_global(Vector3(plaza.x, cap_top + 0.5, plaza.z)), Vector3.ZERO)
	await _await_grounded(150)
	var on_cap: bool = _player.is_grounded \
			and absf(_player.position.y - (cap_top + 0.3)) < 0.2 \
			and _player.velocity.is_finite()
	await _wait_frames(10) ## let the touchdown slide bleed before the takeoff leg
	await _tap("flap")
	var peak_y := _player.position.y
	for _i in 60:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, _player.position.y)
	var took_off: bool = not _player.is_grounded and peak_y > cap_top + 0.9
	_check("city_plaza_landmark",
			count_ok and fp_ok and place_ok and inside_ok and height_ok and color_ok
					and column_clear and deterministic and flyover_ok
					and on_cap and took_off,
			"boxes=%d/%d fp=%d center=%s inside=%s top=%.2f colors=%s colliders=%d column=%s det=%s flyover=%s (crossed min y %.1f drift %.1f) land=%s takeoff=%s" % [
					plinth_xfs.size(), figure_xfs.size(), landmark_fp, place_ok,
					inside_ok, top, color_ok, plinth_colliders, column_clear,
					deterministic, flyover_ok, min_y, max_drift, on_cap, took_off])
	## Informational: the landmark's tuned numbers — the ticket's bars, re-printed.
	print("SIM DATA city_plaza_landmark: top=%.2f cap=%.2f clear_radius=%.1f fingerprint=%d" % [
			top, cap_top, _city.spawn_clear_radius, fp_first])


## --- scenario (T-104 plaza props clear) --------------------------------------


## (T-104) Audit scope around `_plaza_center`: the 8 m bench ring, the bins at
## (±7.0, ±7.0) (r ≈ 9.9) and the corner lamps (r ≈ 13.86) all fit inside; the
## nearest foreign prop (a neighbor block's bench, worst case
## block_size + road_width − 9.75 − 4.0 = 18.25 m out) stays outside, so the
## census is exactly the plaza's 17 shapes.
const PLAZA_AUDIT_RADIUS := 16.0
## (T-104) Shapes may kiss within this much; deeper interpenetration fails.
const PLAZA_TOUCH_TOLERANCE := 0.01
## (T-104) Bin-beside-bench clear space — the research note's 0.3–1 m band floor
## (measured 0.611 m at the (±7.0, ±7.0) fix).
const PLAZA_BIN_BENCH_GAP := 0.3
## (T-104) The bin collider's half-diagonal (0.275·√2) — its worst per-axis
## reach at any yaw, the conservative on-slab pin bound.
const PLAZA_BIN_HALF_DIAG := 0.389


## The two XZ face normals of a yawed box (the `Basis(Vector3.UP, yaw)` columns
## projected to the ground plane) — the SAT candidate axes for the pair verdict.
func _plaza_box_axes(box: Dictionary) -> Array[Vector2]:
	var c := cos(float(box.yaw))
	var s := sin(float(box.yaw))
	return [Vector2(c, -s), Vector2(s, c)]


## Half-extent of a yawed box projected on a unit XZ axis — the SAT support width.
func _plaza_box_extent(box: Dictionary, axis: Vector2) -> float:
	var axes := _plaza_box_axes(box)
	return float(box.half_x) * absf(axes[0].dot(axis)) \
			+ float(box.half_z) * absf(axes[1].dot(axis))


## A world XZ point in a yawed box's local frame — the yaw's transpose applied.
func _plaza_box_to_local(box: Dictionary, p: Vector2) -> Vector2:
	var d := p - Vector2(float(box.center.x), float(box.center.z))
	var axes := _plaza_box_axes(box)
	return Vector2(d.dot(axes[0]), d.dot(axes[1]))


## XZ verdict for one pair of plaza audit shapes (keyed on `kind` — "box" or
## "cyl"): yawed-box SAT over both boxes' face normals — the returned `gap` is
## the max per-axis separation (a lower bound of the true distance, exact for
## the face-to-corner bin/bench case); a cylinder reads as a circle —
## circle-vs-OBB against a box (closest point on the box, exact) or
## circle-circle against a cylinder. Y-range overlap is required on top; any
## XZ axis separating by more than `PLAZA_TOUCH_TOLERANCE` (or a Y miss) clears
## the pair. Returns {intersects, gap} — `gap` negative means penetration.
func _plaza_pair_verdict(a: Dictionary, b: Dictionary) -> Dictionary:
	var ac: Vector3 = a.center
	var bc: Vector3 = b.center
	var y_gap: float = absf(ac.y - bc.y) - (float(a.half_y) + float(b.half_y))
	if y_gap > PLAZA_TOUCH_TOLERANCE:
		return {"intersects": false, "gap": y_gap}
	var dxz := Vector2(bc.x - ac.x, bc.z - ac.z)
	if a.kind == "cyl" and b.kind == "cyl":
		var cc_gap: float = dxz.length() - float(a.radius) - float(b.radius)
		return {"intersects": cc_gap < -PLAZA_TOUCH_TOLERANCE, "gap": cc_gap}
	if a.kind == "cyl" or b.kind == "cyl":
		var cyl: Dictionary = a if a.kind == "cyl" else b
		var box: Dictionary = b if a.kind == "cyl" else a
		var local := _plaza_box_to_local(box,
				Vector2(float(cyl.center.x), float(cyl.center.z)))
		var nearest := local.clamp(Vector2(-float(box.half_x), -float(box.half_z)),
				Vector2(float(box.half_x), float(box.half_z)))
		var obb_gap := (local - nearest).length() - float(cyl.radius)
		return {"intersects": obb_gap < -PLAZA_TOUCH_TOLERANCE, "gap": obb_gap}
	var worst := -INF
	for axis: Vector2 in _plaza_box_axes(a) + _plaza_box_axes(b):
		var sep: float = absf(dxz.dot(axis)) \
				- _plaza_box_extent(a, axis) - _plaza_box_extent(b, axis)
		worst = maxf(worst, sep)
		if sep > PLAZA_TOUCH_TOLERANCE:
			return {"intersects": false, "gap": worst}
	return {"intersects": true, "gap": worst}


## One pass of the T-104 audit over the standing city: every `CollisionShape3D`
## under `Static/Props` (one body per group, T-093 — shapes carry city-local
## transforms) whose XZ center lies within `PLAZA_AUDIT_RADIUS` of
## `_plaza_center`, classified bench/bin/lamp/plinth by collider geometry.
## Returns {clear, pins, count, worst, clashes, slab}: `clear` = no pair
## intersects (`_plaza_pair_verdict`); `pins` = the census is exactly
## 8 benches / 4 bins / 4 lamps / 1 plinth, every bin ≥ `PLAZA_BIN_BENCH_GAP`
## clear of every bench (`worst` gap), every bin on the slab (`slab`);
## `clashes` names the intersecting pairs for the failure detail.
func _plaza_props_audit() -> Dictionary:
	var plaza: Vector3 = _city._plaza_center
	var shapes: Array[Dictionary] = []
	var seen := {}
	var props := _city.get_node("Static/Props") as StaticBody3D
	for node: Node in props.find_children("*", "CollisionShape3D", true, false):
		var col := node as CollisionShape3D
		var pos := col.position
		if Vector2(pos.x - plaza.x, pos.z - plaza.z).length() > PLAZA_AUDIT_RADIUS:
			continue
		var item := {"center": pos}
		var group := ""
		var box := col.shape as BoxShape3D
		if box != null:
			item["kind"] = "box"
			item["half_x"] = box.size.x * 0.5
			item["half_z"] = box.size.z * 0.5
			item["half_y"] = box.size.y * 0.5
			item["yaw"] = col.rotation.y
			if absf(box.size.x - 1.8) < 0.01 and absf(box.size.y - 0.55) < 0.01:
				group = "bench" ## The `_add_bench` collider.
			elif absf(box.size.x - 0.55) < 0.01 and absf(box.size.y - 0.8) < 0.01:
				group = "bin" ## The `_add_bin` collider.
			elif absf(box.size.x - _city.LANDMARK_PLINTH_BASE.x) < 0.01 \
					and absf(box.size.y - _city.LANDMARK_PLINTH_TOP) < 0.01:
				group = "plinth" ## The `_add_landmark` collider.
		elif col.shape is CylinderShape3D:
			var cyl := col.shape as CylinderShape3D
			item["kind"] = "cyl"
			item["radius"] = cyl.radius
			item["half_y"] = cyl.height * 0.5
			group = "lamp" ## The `_add_lamp` collider.
		else:
			continue ## No such shape under Props today; a new kind needs a label.
		item["group"] = group
		seen[group] = int(seen.get(group, 0)) + 1
		item["label"] = "%s#%d" % [group, int(seen[group]) - 1]
		shapes.append(item)
	var census := {"bench": 0, "bin": 0, "lamp": 0, "plinth": 0}
	for a: Dictionary in shapes:
		census[a.group] = int(census[a.group]) + 1
	var census_ok: bool = census == {"bench": 8, "bin": 4, "lamp": 4, "plinth": 1}
	var clashes: Array[String] = []
	var clear := true
	var worst := INF
	for i in shapes.size():
		for j in range(i + 1, shapes.size()):
			var v := _plaza_pair_verdict(shapes[i], shapes[j])
			if v.intersects:
				clear = false
				clashes.append("%s×%s @%.2f m" % [shapes[i].label, shapes[j].label, -v.gap])
			elif shapes[i].group == "bin" and shapes[j].group == "bench" \
					or shapes[i].group == "bench" and shapes[j].group == "bin":
				worst = minf(worst, v.gap)
	var slab_ok := true
	for a: Dictionary in shapes:
		if a.group != "bin":
			continue
		var c: Vector3 = a.center
		slab_ok = slab_ok \
				and absf(c.x - plaza.x) + PLAZA_BIN_HALF_DIAG <= _city.block_size * 0.5 \
				and absf(c.z - plaza.z) + PLAZA_BIN_HALF_DIAG <= _city.block_size * 0.5
	return {"clear": clear, "pins": census_ok and worst >= PLAZA_BIN_BENCH_GAP and slab_ok,
			"count": shapes.size(), "worst": worst,
			"clashes": " ".join(clashes), "slab": slab_ok}


## The plaza's props never interpenetrate (T-104): every collider under
## `Static/Props` within `PLAZA_AUDIT_RADIUS` of `_plaza_center` is checked
## pairwise (`_plaza_pair_verdict` — yawed-box SAT, circle-vs-OBB lamps, Y
## overlap required, touch tolerated) with the intent pins riding along — the
## 8/4/4/1 census, bin-beside-bench clear space, bins on the slab. The plaza
## layout is RNG-free, so the audit must hold at the default seed AND one
## foreign seed, and a same-seed rebuild still reproduces the fingerprint (the
## elder scenario's double-seed shape).
func _scenario_city_plaza_props_clear() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var default_run := _plaza_props_audit()
	_city.generate(424242)
	var foreign_run := _plaza_props_audit()
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	var deterministic: bool = _city.fingerprint == fp_first
	_check("city_plaza_props_clear",
			default_run.clear and default_run.pins and foreign_run.clear
					and foreign_run.pins and deterministic,
			"shapes=%d clash='%s' bin_bench=%.3f slab=%s det=%s foreign=[shapes=%d clash='%s' bin_bench=%.3f slab=%s]" % [
					default_run.count, default_run.clashes, default_run.worst,
					default_run.slab, deterministic,
					foreign_run.count, foreign_run.clashes, foreign_run.worst,
					foreign_run.slab])
	## Informational: the audit's tuned numbers — the ticket's bars, re-printed.
	print("SIM DATA city_plaza_props_clear: shapes=%d worst_bin_bench=%.3f fingerprint=%d" % [
			default_run.count, default_run.worst, fp_first])


## --- scenario (T-091 district anchors) ---------------------------------------


## Byte-identical `anchors` comparison (the `_props_reproduced` pattern).
func _anchors_reproduced(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var pa: Dictionary = a[i]
		var pb: Dictionary = b[i]
		if pa.center != pb.center or pa.district != pb.district \
				or pa.top != pb.top or pa.cap_top != pb.cap_top:
			return false
	return true


## One tall anchor per district (T-091): exactly four deterministic clock posts,
## one per district quadrant, at the pinned blocks' alley-cross centers —
## audited like the plaza landmark (the `city_plaza_landmark` pattern). The
## legs: records — `anchors` holds exactly 4 entries, one per district, each at
## a pinned block's center re-derived from the block grid, `top` the harness's
## own tier-constant sum (1.0 + 13.6 + 2.2 + 0.5 = 17.3 above the slab) under
## `max_roof_height`; the do-not-fold rule — `report.max_roof_height` still
## equals the BUILDING roofs only (max(buildings[].top) − block_slab_height;
## newly guarded here, nothing pinned it before); clearance — the 1.4 m
## plinth's per-axis daylight re-derived from `buildings[]` so a bad seed fails
## loudly (worst 0.024 m at the M1 seed, 0.0016 m at the foreign one — flush,
## never overlapping), no bread spot but the anchor's own cap crumb within 5 m
## XZ (measured) and the bench line / lamps+bins / tourist loop / park-tree
## crown distances held by constants arithmetic; the cap crumb sitting in
## `bread_spots` at cap_top + 0.06; `last_report.plaza_clear` still true;
## visuals — the four tier queues hold 4 instances each, over the anchor
## centers at the tier scales and stacked y, every head tinted one of the four
## districts' first palette colors with all four present; collision — one
## layer-1 `Props` box per tier under the shared group body, exactly 3 of them
## above the y 5.0 window per anchor (the plinth sits below it); determinism —
## a forced same-seed rebuild reproduces `anchors` and `bread_spots`
## byte-identically, and the foreign seed raises the same four posts; physical
## — a drop onto a cap settles grounded at cap_top + 0.3 (the prop-landing
## template) and the anchor crumb is an ordinary crumb a grounded pigeon on the
## cap eats (+30 through Hunger). No pinned block is a park at either pinned
## seed (parks sit at (0,0)/(3,1) on 20260928 and (3,5)/(6,2)/(6,4) on 424242),
## so the stands-in-parks guarantee rests on the code structure (the gate sits
## OUTSIDE the plaza/park/building branch) plus the constants arithmetic — the
## (±5, ±5) park trees leave ≈ 2.2 m per axis clear of the plinth.
func _scenario_city_district_anchors() -> void:
	var default_seed: int = _city.seed_value
	var fp_first: int = _city.fingerprint
	_city.generate(default_seed, true) ## force_rebuild: baseline off a real rebuild.
	var anchors_snapshot := _city.anchors.duplicate()
	var bread_snapshot := _city.bread_spots.duplicate()
	## The harness's own copy of the tier layout numbers (the
	## `_expected_sign_plaque` pattern): key + size, stacked from the slab top.
	var tiers := [
		["anchor_plinth", Vector3(1.4, 1.0, 1.4)],
		["anchor_shaft", Vector3(0.7, 13.6, 0.7)],
		["anchor_head", Vector3(1.8, 2.2, 1.8)],
		["anchor_cap", Vector3(2.0, 0.5, 2.0)],
	]
	## --- records: exactly 4, one per district, at the pinned block centers ---
	var pins: Array[Vector2i] = [Vector2i(1, 1), Vector2i(5, 1), Vector2i(1, 5), Vector2i(5, 5)]
	var half_blocks := float(_city.blocks_per_side - 1) * 0.5
	var count_ok: bool = _city.anchors.size() == 4
	var districts_seen := {}
	var pins_ok := count_ok
	var height_ok := count_ok
	var recompute_ok := count_ok
	for rec in _city.anchors:
		var district: int = rec.district
		districts_seen[district] = true
		height_ok = height_ok and (rec.top as float) <= _city.max_roof_height
		var c: Vector3 = rec.center
		var matched := false
		for pin in pins:
			var g := _city.to_global(Vector3(
					(pin.x - half_blocks) * _city.block_pitch, 0.0,
					(pin.y - half_blocks) * _city.block_pitch))
			if Vector2(g.x - c.x, g.z - c.z).length() < 0.01:
				matched = true
				pins_ok = pins_ok and district == _city.district_of(pin.x, pin.y)
				recompute_ok = recompute_ok \
						and absf((rec.top as float) - 17.3) < 0.001 \
						and absf((rec.cap_top as float)
								- (_city.block_slab_height + 17.3)) < 0.001
		pins_ok = pins_ok and matched
	var districts_ok := districts_seen.size() == 4
	## --- the do-not-fold rule: the report stays the BUILDING roofs ------------
	var max_top := 0.0
	for info in _city.buildings:
		max_top = maxf(max_top, info.top)
	var report_pin: bool = count_ok \
			and absf((_city.last_report.max_roof_height as float)
					- (max_top - _city.block_slab_height)) < 0.001
	## --- plinth daylight, re-derived per seed from buildings[] ----------------
	var standoff_ok := count_ok
	var worst_daylight := INF
	for rec in _city.anchors:
		var c: Vector3 = rec.center
		for info in _city.buildings:
			var bc: Vector3 = info.center
			if absf(bc.x - c.x) > _city.block_size * 0.5 \
					or absf(bc.z - c.z) > _city.block_size * 0.5:
				continue ## Not this block's lot.
			var size: Vector2 = info.size
			var face_x := absf(bc.x - c.x) - size.x * 0.5 - 0.7
			var face_z := absf(bc.z - c.z) - size.y * 0.5 - 0.7
			standoff_ok = standoff_ok and face_x >= 0.0 and face_z >= 0.0
			worst_daylight = minf(worst_daylight, minf(face_x, face_z))
	## --- bread clearance: nothing but the anchor's own crumb near the post ----
	var clear_ok := count_ok
	var worst_bread := INF
	for rec in _city.anchors:
		var local := _city.to_local(rec.center)
		for spot in _city.bread_spots:
			var flat := Vector2(spot.x - local.x, spot.z - local.z).length()
			if flat < 0.5:
				continue ## The anchor's own cap crumb rides the center.
			worst_bread = minf(worst_bread, flat)
			clear_ok = clear_ok and flat >= 5.0
	## Constants arithmetic, holding at EVERY seed: the 10.9 m tourist-loop
	## line, the 6.5 m inner ground bread-ring axis, the 9.75 m bench line less
	## the bench's 0.9 m half-depth, and the park-tree crown half-diagonal at
	## its fixed ±5 offset — all vs the plinth's 0.99 m half-diagonal.
	var plinth_half_diag := sqrt(2.0) * 0.7
	var arithmetic_ok: bool = _city.block_size * 0.5 - 0.1 - plinth_half_diag >= 1.0 \
			and _city.block_size * 0.5 - 4.5 - plinth_half_diag >= 1.0 \
			and _city.block_size * 0.5 - 1.25 - 0.9 - plinth_half_diag >= 1.0 \
			and _city.PARK_TREE_OFFSET - _city.PARK_CROWN_SIZE.x * sqrt(2.0) * 0.5 \
					- plinth_half_diag >= 1.0
	## --- the cap crumb sits in bread_spots at cap_top + 0.06 ------------------
	var crumb_ok := count_ok
	for rec in _city.anchors:
		var local := _city.to_local(rec.center)
		var want_y: float = (rec.cap_top as float) + 0.06
		var found := false
		for spot in _city.bread_spots:
			found = found or (Vector2(spot.x - local.x, spot.z - local.z).length() < 0.001
					and absf(spot.y - want_y) < 0.001)
		crumb_ok = crumb_ok and found
	var plaza_ok: bool = _city.last_report.plaza_clear
	## --- the tier queues: 4 instances each, over the centers, stacked ---------
	var visuals_ok := count_ok
	var head_colors := {}
	var tier_base := 0.0
	for tier in tiers:
		var key: String = tier[0]
		var size: Vector3 = tier[1]
		var queue: Array = _city._visuals[key].xfs if _city._visuals.has(key) else []
		var colors: Array = _city._visuals[key].colors if _city._visuals.has(key) else []
		visuals_ok = visuals_ok and queue.size() == 4
		var want_y := _city.block_slab_height + tier_base + size.y * 0.5
		for i in queue.size():
			var o: Vector3 = (queue[i] as Transform3D).origin
			var sc: Vector3 = (queue[i] as Transform3D).basis.get_scale()
			var over_anchor := false
			for rec in _city.anchors:
				var local := _city.to_local(rec.center)
				over_anchor = over_anchor \
						or Vector2(o.x - local.x, o.z - local.z).length() < 0.01
			visuals_ok = visuals_ok and over_anchor \
					and sc.distance_to(size) < 0.001 \
					and absf(o.y - want_y) < 0.001
			if key == "anchor_head":
				head_colors[colors[i]] = true
		tier_base += size.y
	var all_four := head_colors.size() == 4
	for palette: Array in _city.DISTRICT_PALETTES:
		all_four = all_four and head_colors.has(palette[0])
	visuals_ok = visuals_ok and all_four
	## --- collision: one Props box per tier, 3 above the y 5.0 window ----------
	var props_body := _city.get_node("Static/Props") as StaticBody3D
	var colliders_ok := props_body != null \
			and props_body.collision_layer == 1 and props_body.collision_mask == 0
	var high_shapes := 0
	if colliders_ok:
		for rec in _city.anchors:
			var local := _city.to_local(rec.center)
			var per_anchor := 0
			for shape_node in props_body.find_children("*", "CollisionShape3D", true, false):
				var shape := shape_node as CollisionShape3D
				var box := shape.shape as BoxShape3D
				if box == null:
					continue
				var pos := shape.position
				if Vector2(pos.x - local.x, pos.z - local.z).length() > 1.5:
					continue
				var tier_floor := 0.0
				for tier in tiers:
					var size: Vector3 = tier[1]
					if box.size.distance_to(size) < 0.001 \
							and absf(pos.y - (_city.block_slab_height + tier_floor
									+ size.y * 0.5)) < 0.001:
						per_anchor += 1
						if pos.y > 5.0:
							high_shapes += 1
					tier_floor += size.y
			colliders_ok = colliders_ok and per_anchor == 4
		colliders_ok = colliders_ok and high_shapes == 3 * _city.anchors.size()
	## --- determinism: a real rebuild reproduces anchors and bread spots ------
	_city.generate(default_seed, true)
	var deterministic: bool = _city.fingerprint == fp_first \
			and _anchors_reproduced(anchors_snapshot, _city.anchors) \
			and _vec_spots_equal(bread_snapshot, _city.bread_spots)
	## --- foreign seed: the same four posts stand at the pinned blocks --------
	_city.generate(424242)
	var foreign_ok: bool = _city.anchors.size() == 4
	for rec in _city.anchors:
		var c: Vector3 = rec.center
		var matched := false
		for pin in pins:
			var g := _city.to_global(Vector3(
					(pin.x - half_blocks) * _city.block_pitch, 0.0,
					(pin.y - half_blocks) * _city.block_pitch))
			matched = matched or Vector2(g.x - c.x, g.z - c.z).length() < 0.01
		foreign_ok = foreign_ok and matched
	_city.generate(default_seed, true) ## Real rebuild: leaves the default city standing.
	## --- the physical legs, on the first anchor (NW quadrant) -----------------
	var land_ok := false
	var eat_ok := false
	if count_ok:
		var rec: Dictionary = _city.anchors[0]
		var cap_center: Vector3 = rec.center
		var cap_top: float = rec.cap_top
		var hunger := Hunger.new()
		hunger.player = _player
		add_child(hunger)
		## Mid-bar BEFORE the drop so the +30 restore is measurable: unlike the
		## roof-crumb leg (a waddle away), this crumb is underfoot at touchdown,
		## so the eat can land the very frame grounding lands.
		hunger.value = 40.0
		var hunger0 := hunger.value
		var crumb: BreadCrumb = CRUMB_SCENE.instantiate()
		crumb.position = Vector3(cap_center.x, cap_top + 0.06, cap_center.z)
		add_child(crumb)
		crumb.eaten.connect(hunger.eat)
		await _set_up(true, Vector3(cap_center.x, cap_top + 0.5, cap_center.z),
				Vector3.ZERO)
		await _await_grounded(150)
		land_ok = _player.is_grounded \
				and absf(_player.position.y - (cap_top + 0.3)) < 0.2 \
				and _player.velocity.is_finite()
		for _i in 90:
			await get_tree().physics_frame
			eat_ok = not is_instance_valid(crumb) and hunger.value > hunger0 + 10.0
			if eat_ok:
				break
		hunger.free()
	_check("city_district_anchors_present",
			count_ok and districts_ok and pins_ok and height_ok and recompute_ok
					and report_pin and standoff_ok and clear_ok and arithmetic_ok
					and crumb_ok and plaza_ok and visuals_ok and colliders_ok
					and deterministic and foreign_ok and land_ok and eat_ok,
			("count=%s districts=%d pins=%s height=%s recompute=%s report=%s "
			+ "standoff=%s (worst %.4f m) clear=%s (worst %.2f m) arith=%s "
			+ "crumb=%s plaza=%s visuals=%s colliders=%s (%d high) det=%s "
			+ "foreign=%s land=%s eat=%s") % [
					count_ok, districts_seen.size(), pins_ok, height_ok,
					recompute_ok, report_pin, standoff_ok, worst_daylight,
					clear_ok, worst_bread, arithmetic_ok, crumb_ok, plaza_ok,
					visuals_ok, colliders_ok, high_shapes, deterministic,
					foreign_ok, land_ok, eat_ok])
	## Informational: the anchors' tuned numbers — the ticket's bars, re-printed.
	print("SIM DATA city_district_anchors: anchors=%d top=%.2f cap=%.2f worst_daylight=%.4f m worst_bread=%.2f m fingerprint=%d" % [
			_city.anchors.size(),
			_city.anchors[0].top if not _city.anchors.is_empty() else 0.0,
			_city.anchors[0].cap_top if not _city.anchors.is_empty() else 0.0,
			worst_daylight, worst_bread, fp_first])


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
	## T-055: the shirt flush is a binary write — calm is exactly the tourist's
	## palette shirt_color, mid-panic exactly PANIC_TINT — read through the
	## established `material_override as StandardMaterial3D` pattern (cafe
	## sitter, splat fade). Calm is sampled before the drop; the panic arm is
	## confirmed inside the poll below (the write lands on the first _animate
	## tick that sees mood == PANIC, so it may lag the mood flip by a frame).
	var shirt_mat: StandardMaterial3D = tourist._body_mesh.material_override \
			as StandardMaterial3D
	var calm_ok: bool = shirt_mat != null \
			and shirt_mat.albedo_color.is_equal_approx(tourist.shirt_color)
	var flush_ok := false
	var flush_color := Color()
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
		if tourist.mood == Tourist.Mood.PANIC and not flush_ok and shirt_mat != null:
			flush_color = shirt_mat.albedo_color
			flush_ok = flush_color.is_equal_approx(Tourist.PANIC_TINT)
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
					and Game.score == 300 and calm_ok and flush_ok,
			"dropped=%s fired=%s relay=%d panicked=%s sprint %.1f m/s flees=%s score=%d calm=%s flush=%s (%s)" % [
					dropped, fired, _tourist_relay, panicked, max_hspeed, flees_impact,
					Game.score, calm_ok, flush_ok, flush_color])
	spawner.free()


## The retuned hit tolerance makes the LEAD shot real (T-060): a tourist KEEPING
## its stroll loop (never frozen), a drop released 4 m above the predicted
## impact — the autoplay formula, live flat position + live flat velocity × the
## 0.8165 s a 4 m fall takes at poop.gd's `fall_gravity` 12 — CONNECTS through
## the 0.30 collider (contact reach 0.30 + 0.25 capsule = 0.55 m): splatted
## fires, the tourist panics. The same drop aimed 1.5 m lateral of the
## prediction does NOT — 0.95 m of clean margin outside the reach keeps the
## lead a skill, not a shotgun: the stray drop may splat the ground, but no
## event targets the tourist and the mood never reaches PANIC. And the
## criterion's own bar — 0.4 m lateral, inside the reach — connects again.
func _scenario_poop_hits_tourist_within_lead_window() -> void:
	_dropped.clear()
	_splat_events.clear()
	var spawner := TouristSpawner.new()
	spawner.city = _city
	spawner.player = _player
	spawner.target_count = 1
	spawner.spawn_min_dist = 0.0
	spawner.spawn_max_dist = 10.0 ## Pin the loop to the plaza block, like the frozen-target scenario.
	add_child(spawner)
	await _wait_frames(4)
	var tourists := spawner.living_tourists()
	if tourists.is_empty():
		_check("poop_hits_tourist_within_lead_window", false, "no tourist spawned")
		spawner.free()
		return
	var tourist: Tourist = tourists[0]
	var fall := sqrt(2.0 * 4.0 / 12.0) ## ≈ 0.8165 s: the 4 m release fall at fall_gravity 12.
	## Positive arm — dead on the prediction: seat mid-leg (straight walking for
	## the whole fall window), read the LIVE stroll velocity, drop from 4.3 m
	## (the drop leaves 0.3 m under the body — poop_drop_offset).
	_seat_mid_leg(tourist)
	await _wait_frames(3) ## Straight-leg stroll ticks to settle the velocity read.
	var lead_spot := _predict_lead_spot(tourist, fall)
	await _set_up(true, lead_spot + Vector3(0.0, 4.3, 0.0), Vector3.ZERO)
	await _tap("poop")
	await _wait_frames(2)
	var dropped := _dropped.size() == 1
	if dropped:
		_dropped[0].splatted.connect(_on_test_splatted)
	var panicked := false
	for _i in 120: ## Contact ~0.7 s in; the panic sprint follows it.
		await get_tree().physics_frame
		panicked = panicked or tourist.mood == Tourist.Mood.PANIC
	var lead_hit: bool = _splat_events.size() == 1 \
			and _splat_events[0].target == tourist
	var events_after_lead := _splat_events.size()
	## Negative arm — the same prediction 1.5 m lateral (perpendicular to the
	## stroll): let the panic burn out first (bounded — a second splat would
	## restart it, and none can fire here), re-seat mid-leg, read the live
	## velocity again at THIS release.
	for _i in 200:
		if tourist.mood != Tourist.Mood.PANIC:
			break
		await get_tree().physics_frame
	_seat_mid_leg(tourist)
	await _wait_frames(3)
	var tv := Vector2(tourist.velocity.x, tourist.velocity.z)
	var perp := Vector2(-tv.y, tv.x).normalized()
	var stray_spot := _predict_lead_spot(tourist, fall) + Vector3(
			perp.x * 1.5, 0.0, perp.y * 1.5)
	await _set_up(true, stray_spot + Vector3(0.0, 4.3, 0.0), Vector3.ZERO)
	await _tap("poop")
	await _wait_frames(2)
	if _dropped.size() == 2:
		_dropped[1].splatted.connect(_on_test_splatted)
	var clean_mood := true
	for _i in 120: ## The stray's whole fall plus margin — panic must never come.
		await get_tree().physics_frame
		clean_mood = clean_mood and tourist.mood != Tourist.Mood.PANIC
	var no_stray_tourist := true
	for i in range(events_after_lead, _splat_events.size()):
		no_stray_tourist = no_stray_tourist and _splat_events[i].target != tourist
	var strays := _splat_events.size() - events_after_lead
	## Half-way arm — the acceptance bar itself: the same drop 0.4 m lateral of
	## the prediction must STILL connect (the criterion's "≤ 0.4 m lateral aim
	## error" — under the 0.55 m contact reach). The stray left the tourist
	## calm and strolling, so the live re-read needs no panic burn-out here.
	_seat_mid_leg(tourist)
	await _wait_frames(3)
	var tv_half := Vector2(tourist.velocity.x, tourist.velocity.z)
	var perp_half := Vector2(-tv_half.y, tv_half.x).normalized()
	var near_spot := _predict_lead_spot(tourist, fall) + Vector3(
			perp_half.x * 0.4, 0.0, perp_half.y * 0.4)
	await _set_up(true, near_spot + Vector3(0.0, 4.3, 0.0), Vector3.ZERO)
	await _tap("poop")
	await _wait_frames(2)
	if _dropped.size() == 3:
		_dropped[2].splatted.connect(_on_test_splatted)
	var half_panicked := false
	for _i in 120:
		await get_tree().physics_frame
		half_panicked = half_panicked or tourist.mood == Tourist.Mood.PANIC
	var half_events := _splat_events.size() - events_after_lead - strays
	var half_hit: bool = half_events == 1 \
			and _splat_events[_splat_events.size() - 1].target == tourist
	_check("poop_hits_tourist_within_lead_window",
			dropped and lead_hit and panicked and clean_mood and no_stray_tourist
					and strays <= 1 and half_hit and half_panicked,
			"dropped=%s lead_hit=%s panicked=%s stray_mood_clean=%s stray_tourist_free=%s stray_events=%d half_hit=%s half_panicked=%s" % [
					dropped, lead_hit, panicked, clean_mood, no_stray_tourist, strays,
					half_hit, half_panicked])
	spawner.free()


## Seats a stroller mid-leg between two loop waypoints and retargets: the
## sidewalk ring's legs are ~21.8 m, so the next ~10 m of walking is dead
## straight — a corner turn cannot bend the stroll off the lead prediction
## mid-fall. (The splat scenarios freeze targets with an empty path; this one
## needs the loop ALIVE, so it curates the walk instead.)
func _seat_mid_leg(tourist: Tourist) -> void:
	var path := tourist.path
	if path.size() < 2:
		return
	tourist.global_position = path[0].lerp(path[1], 0.5)
	tourist._retarget_nearest_waypoint()


## The autoplay's lead prediction (tests/autoplay.gd `_tourist_in_lead`): where
## the tourist will have strolled to when the drop lands — live flat position
## plus live flat velocity times the fall time, read at the release frame.
func _predict_lead_spot(tourist: Tourist, fall: float) -> Vector3:
	var v := Vector2(tourist.velocity.x, tourist.velocity.z)
	var spot := Vector2(tourist.global_position.x, tourist.global_position.z) + v * fall
	return Vector3(spot.x, tourist.global_position.y, spot.y)


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
## settles GROUNDED on the plaza first — since T-029 at the PLAZA_DROP_OFFSET
## point, not the exact center, because the landmark plinth owns the middle:
## a standing bird pins the spawner's
## recycle anchor in place, so nothing recycles mid-scenario and a parked car
## drifting would be a real bug, not the anchor wandering.
func _scenario_cars_traffic() -> void:
	await _set_up(true, _city.position + PLAZA_DROP_OFFSET + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	## (T-081) Pin the spawner anchor: the seed band hangs on the player's XZ
	## (`CarSpawner._anchor_flat`), and sub-metre shifts of that anchor flip
	## the band's block membership — the fleet draw, and with it the cruise
	## bars, was silently coupled to wherever the drop's drift parked the bird.
	## Measured on this very drop: the pre-fix hover drifted the landing ~1.1 m
	## and drew a healthy fleet; any landing within ~1 m of the drop point drew
	## two short cars (probed across landing z 1997.8-2003.8). Standing the
	## GROUNDED bird at a fixed plaza point keeps every scenario assert
	## untouched and makes the draw a scenario constant — (4, 2) city-local:
	## 5.4 m from the plaza center, clear of the plinth footprint, inside the
	## bench ring, on a probed-healthy draw.
	_player.global_position = _city.position + Vector3(4.0, 0.0, 2.0) \
			+ Vector3(0.0, _player.position.y - _city.position.y, 0.0)
	await _wait_frames(2)
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
	## The pigeon grounds on the plaza first (since T-029 at PLAZA_DROP_OFFSET,
	## clear of the landmark plinth) so the spawner's recycle anchor
	## stays put while the cars seed and drive.
	await _set_up(true, _city.position + PLAZA_DROP_OFFSET + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
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
	await _set_up(true, _city.position + PLAZA_DROP_OFFSET + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90) ## Back to the plaza (off-center — clear of the landmark) — off the ring, anchor pinned.
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
## rejoin points — all keep looping with the pigeon parked on the plaza (the
## T-029 off-center drop — on the plaza block, clear of the landmark). The
## bars discriminate: a flowing car covers 50+ m of a ~116 m ring in 10 s,
## the mined standing clots crept ≈ 0.5 m per 10 s, and a healthy follow-gap
## queue holds 5.6 m — so travel < 8 m means a standing clot and a seeded
## gap < 4 m means an overlap. The whole chosen ring lies inside the recycle
## radius, so the scanner must leave everyone alone all run: any single-frame
## jump > 5 m is a recycle teleport, not a legit recycle.
func _scenario_traffic_recycle_keeps_flow() -> void:
	await _set_up(true, _city.position + PLAZA_DROP_OFFSET + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
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


## The end-to-end timer-driven car recycle (T-054 — until now only the tourist
## twin was machine-proven and T-089's `traffic_recycle_keeps_flow` pinned the
## rejoin-insertion half): teleporting the player beyond the car
## `recycle_radius` (100 m) lets the scan `_physics_process` fire
## `_recycle_far` for real and recycle the SAME car nodes into the spawn band
## around the new anchor — no respawn churn, the fleet still 20 traffic + 16
## parked, every car inside the radius of the new anchor or on a 30–70 m band
## block, and the curb exclusivity (`_spot_taken`'s 4.5 m rule) surviving the
## whole recycle — no double-booked parking spot.
func _scenario_cars_recycle() -> void:
	## The pigeon grounds on the plaza first (the anchor pin `cars_traffic`
	## uses — since T-029 at PLAZA_DROP_OFFSET, clear of the landmark plinth):
	## a standing bird pins the spawner's recycle anchor in place while the
	## fleet seeds, so nothing recycles before the scenario moves it.
	await _set_up(true, _city.position + PLAZA_DROP_OFFSET + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
	await _await_grounded(90)
	var spawner := CarSpawner.new()
	spawner.city = _city
	spawner.player = _player
	add_child(spawner)
	await _wait_frames(4)
	var cars := spawner.living_cars()
	var full := cars.size() == spawner.target_moving + spawner.target_parked
	var ids: Array[int] = []
	for car in cars:
		ids.append(car.get_instance_id())
	## ~120 m west — beyond `recycle_radius` 100 so cars genuinely recycle,
	## but close enough that block centers still sit inside the 30–70 m spawn
	## band (centers span ±96 city-local; from the new anchor the nearest sit
	## 40–68 m flat away — a 200 m hop would empty the band and legitimately
	## recycle nobody).
	await _set_up(true, _city.position + Vector3(-120.0, 25.0, 0.0), Vector3.ZERO)
	await _wait_frames(90) ## 3 recycle scans at the fixed 60 Hz step (0.5 s interval = 30 frames); a parked car whose drawn spot was taken legitimately skips one.
	var after := spawner.living_cars()
	var reused := true
	var placed := true
	var traffic := 0
	var parked := 0
	var anchor := Vector2(_city.position.x - 120.0, _city.position.z)
	for car in after:
		reused = reused and ids.has(car.get_instance_id())
		if car.mode == Car.Mode.TRAFFIC:
			traffic += 1
		else:
			parked += 1
		var flat := Vector2(car.global_position.x - anchor.x,
				car.global_position.z - anchor.y)
		var center := Vector2(car.block_center.x - anchor.x, car.block_center.z - anchor.y)
		# The recycle contract, as for tourists: every car is EITHER already
		# within the recycle radius of the moved player (legitimately kept) OR
		# recycled onto a block in the spawn band.
		placed = placed and (flat.length() <= spawner.recycle_radius
				or (center.length() >= spawner.spawn_min_dist
						and center.length() <= spawner.spawn_max_dist))
	var counts_ok := traffic == spawner.target_moving and parked == spawner.target_parked
	## Curb exclusivity survives the recycle: no two parked cars within the
	## 4.5 m `_spot_taken` threshold of each other.
	var min_parked_gap := 100.0
	for i in after.size():
		if after[i].mode != Car.Mode.PARKED:
			continue
		for j in range(i + 1, after.size()):
			if after[j].mode != Car.Mode.PARKED:
				continue
			min_parked_gap = minf(min_parked_gap,
					after[i].global_position.distance_to(after[j].global_position))
	_check("cars_recycle_around_player",
			full and after.size() == spawner.target_moving + spawner.target_parked
					and reused and counts_ok and placed and min_parked_gap >= 4.5,
			"full=%s count %d (traffic %d, parked %d, want %d/%d) reused=%s placed=%s min parked gap %.2f (want >= 4.5)" % [
					full, after.size(), traffic, parked, spawner.target_moving,
					spawner.target_parked, reused, placed, min_parked_gap])
	spawner.free()


## --- scenarios (T-113 citizen classes) --------------------------------------


## The scenario's own class tally — recomputed from the living nodes, never
## from spawner internals (the T-112 determinism-law shape).
func _class_tally(nodes: Array) -> Array[int]:
	var tally: Array[int] = [0, 0, 0] ## CitizenClass.Kind order: CIVILIAN, VISITOR, SUPERFAN.
	for node in nodes:
		tally[node.citizen_class] += 1
	return tally


## The per-node uniform multiset as sortable strings — "byte-identical" is a
## sorted-string compare over class + colors (+ finger for pedestrians).
func _tourist_uniform_rows(tourists: Array[Tourist]) -> Array[String]:
	var rows: Array[String] = []
	for tourist in tourists:
		rows.append("%d|%s|%s" % [tourist.citizen_class,
				tourist.shirt_color.to_html(), tourist.carries_finger])
	rows.sort()
	return rows


func _car_uniform_rows(cars: Array[Car]) -> Array[String]:
	var rows: Array[String] = []
	for car in cars:
		rows.append("%d|%s" % [car.citizen_class, car.body_color.to_html()])
	rows.sort()
	return rows


func _rows_equal(a: Array[String], b: Array[String]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


## True when the drawn count sits inside the nearest-integer band around the
## share's expectation — "within integer rounding" (T-113 acceptance bar).
func _within_integer_rounding(count: int, expected: float) -> bool:
	return count >= floori(expected) and count <= ceili(expected)


## T-113: the class multiset is a seeded law. A real generated City plus both
## spawner rigs at the shipped targets (18 tourists · 20 traffic + 16 parked):
## the tallies match the share knobs within integer rounding at the M1 seed
## AND at seed 424242; a forced same-seed rebuild + re-populate reproduces the
## uniform multisets byte-identically; and a forced recycle of the far nodes
## keeps every node's class and colors (same node, same uniform).
func _scenario_citizen_classes_spawn_deterministic() -> void:
	var default_seed: int = _city.seed_value
	_city.generate(default_seed, true) ## Force a real rebuild baseline.
	## One static airborne anchor serves both rigs (the `tourists_walk` hover):
	## determinism only needs the band draw identical across the rebuild, and
	## the anchor reads the player's XZ alone.
	await _set_up(true, _city.position + Vector3(0.0, 25.0, 0.0), Vector3.ZERO)
	var tourist_rig := TouristSpawner.new()
	tourist_rig.city = _city
	tourist_rig.player = _player
	add_child(tourist_rig)
	var car_rig := CarSpawner.new()
	car_rig.city = _city
	car_rig.player = _player
	add_child(car_rig)
	await _wait_frames(4)
	var tourists: Array[Tourist] = tourist_rig.living_tourists()
	var cars: Array[Car] = car_rig.living_cars()
	var t_tally := _class_tally(tourists)
	var c_tally := _class_tally(cars)
	var t_counts_ok: bool = tourists.size() == tourist_rig.target_count \
			and _within_integer_rounding(t_tally[CitizenClass.Kind.VISITOR],
					tourists.size() * tourist_rig.visitor_share) \
			and _within_integer_rounding(t_tally[CitizenClass.Kind.SUPERFAN],
					tourists.size() * tourist_rig.superfan_share) \
			and t_tally[CitizenClass.Kind.CIVILIAN] == tourists.size() \
					- t_tally[CitizenClass.Kind.VISITOR] - t_tally[CitizenClass.Kind.SUPERFAN]
	var c_counts_ok: bool = cars.size() == car_rig.target_moving + car_rig.target_parked \
			and _within_integer_rounding(c_tally[CitizenClass.Kind.VISITOR],
					cars.size() * car_rig.visitor_share) \
			and _within_integer_rounding(c_tally[CitizenClass.Kind.SUPERFAN],
					cars.size() * car_rig.superfan_share) \
			and c_tally[CitizenClass.Kind.CIVILIAN] == cars.size() \
					- c_tally[CitizenClass.Kind.VISITOR] - c_tally[CitizenClass.Kind.SUPERFAN]
	var t_rows := _tourist_uniform_rows(tourists)
	var c_rows := _car_uniform_rows(cars)
	## Forced same-seed rebuild: `regenerated` fires, both rigs re-populate.
	_city.generate(default_seed, true)
	await _wait_frames(4)
	var rebuilt_tourists: Array[Tourist] = tourist_rig.living_tourists()
	var rebuilt_cars: Array[Car] = car_rig.living_cars()
	var deterministic: bool = _rows_equal(t_rows, _tourist_uniform_rows(rebuilt_tourists)) \
			and _rows_equal(c_rows, _car_uniform_rows(rebuilt_cars))
	## Forced recycle: move the pigeon beyond both recycle radii (100/80) and
	## call each scan directly — every far node teleports, the SAME nodes, and
	## none may lose its uniform.
	var t_uniforms := {}
	var t_before := {}
	for tourist in rebuilt_tourists:
		t_uniforms[tourist.get_instance_id()] = "%d|%s" % [tourist.citizen_class,
				tourist.shirt_color.to_html()]
		t_before[tourist.get_instance_id()] = tourist.global_position
	var c_uniforms := {}
	var c_before := {}
	for car in rebuilt_cars:
		c_uniforms[car.get_instance_id()] = "%d|%s" % [car.citizen_class,
				car.body_color.to_html()]
		c_before[car.get_instance_id()] = car.global_position
	await _set_up(true, _city.position + Vector3(-120.0, 25.0, 0.0), Vector3.ZERO)
	await _wait_frames(2)
	tourist_rig._recycle_far()
	car_rig._recycle_far()
	await _wait_frames(2)
	var after_tourists: Array[Tourist] = tourist_rig.living_tourists()
	var after_cars: Array[Car] = car_rig.living_cars()
	var kept_uniform := true
	var moved_tourists := 0
	var moved_cars := 0
	for tourist in after_tourists:
		kept_uniform = kept_uniform \
				and t_uniforms.get(tourist.get_instance_id(), "?") \
						== "%d|%s" % [tourist.citizen_class, tourist.shirt_color.to_html()]
		if tourist.global_position.distance_to(
				t_before.get(tourist.get_instance_id(), tourist.global_position)) > 10.0:
			moved_tourists += 1
	for car in after_cars:
		kept_uniform = kept_uniform \
				and c_uniforms.get(car.get_instance_id(), "?") \
						== "%d|%s" % [car.citizen_class, car.body_color.to_html()]
		if car.global_position.distance_to(
				c_before.get(car.get_instance_id(), car.global_position)) > 10.0:
			moved_cars += 1
	## The foreign seed opens the same law.
	_city.generate(424242, true)
	await _wait_frames(4)
	var f_tourists: Array[Tourist] = tourist_rig.living_tourists()
	var f_cars: Array[Car] = car_rig.living_cars()
	var f_t := _class_tally(f_tourists)
	var f_c := _class_tally(f_cars)
	var foreign_ok: bool = f_tourists.size() == tourist_rig.target_count \
			and _within_integer_rounding(f_t[CitizenClass.Kind.VISITOR],
					f_tourists.size() * tourist_rig.visitor_share) \
			and _within_integer_rounding(f_t[CitizenClass.Kind.SUPERFAN],
					f_tourists.size() * tourist_rig.superfan_share) \
			and f_cars.size() == car_rig.target_moving + car_rig.target_parked \
			and _within_integer_rounding(f_c[CitizenClass.Kind.VISITOR],
					f_cars.size() * car_rig.visitor_share) \
			and _within_integer_rounding(f_c[CitizenClass.Kind.SUPERFAN],
					f_cars.size() * car_rig.superfan_share)
	print("SIM DATA citizen_classes_spawn_deterministic: seed %d t c/v/s %d/%d/%d · c c/v/s %d/%d/%d | seed 424242 t c/v/s %d/%d/%d · c c/v/s %d/%d/%d | recycle moved t%d c%d kept=%s" % [
			default_seed, t_tally[0], t_tally[1], t_tally[2],
			c_tally[0], c_tally[1], c_tally[2],
			f_t[0], f_t[1], f_t[2], f_c[0], f_c[1], f_c[2],
			moved_tourists, moved_cars, kept_uniform])
	_check("citizen_classes_spawn_deterministic",
			t_counts_ok and c_counts_ok and deterministic and kept_uniform
					and moved_tourists > 0 and moved_cars > 0 and foreign_ok,
			"tallies_ok t=%s c=%s · deterministic=%s · recycle kept_uniform=%s moved t%d c%d · foreign_ok=%s" % [
					t_counts_ok, c_counts_ok, deterministic, kept_uniform,
					moved_tourists, moved_cars, foreign_ok])
	tourist_rig.free()
	car_rig.free()
	_city.generate(default_seed, true) ## Leave the standing city as found.
	await _wait_frames(2)


## True when the mesh's material_override albedo is exactly one of the two
## invader class colors (T-113).
func _is_team_color(mesh: MeshInstance3D) -> bool:
	var mat := mesh.material_override as StandardMaterial3D
	if mat == null:
		return false
	return mat.albedo_color.is_equal_approx(CitizenClass.TEAM_GOLD) \
			or mat.albedo_color.is_equal_approx(CitizenClass.VISITOR_BLACK)


## The pairing read (T-113's load-bearing finding): torso and arm materials
## differ — two team colors STACKED on one body, never a single garment.
func _pairing_reads(tourist: Tourist) -> bool:
	var torso := tourist._body_mesh.material_override as StandardMaterial3D
	var arm := tourist._arm_l.material_override as StandardMaterial3D
	return torso != null and arm != null and torso != arm \
			and not torso.albedo_color.is_equal_approx(arm.albedo_color)


## The foam finger points straight up and breaks the head line: its top edge
## sits ≥ 0.15 m above the 1.27 m head sphere (research orientation fact 1).
func _mitt_reads_up(tourist: Tourist) -> bool:
	var vertical: bool = tourist._mitt.global_transform.basis.y.y >= 0.95
	var above: bool = tourist._mitt.to_global(Vector3(0.0, 0.25, 0.0)).y >= 1.42
	return vertical and above


func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## T-113: the uniform reads. Three tourist rigs (all-visitor, all-superfan,
## all-civilian via the share knobs) and three car rigs give per-class machine
## reads: the invader pairing (torso ≠ arm, both ∈ {gold, black}), the
## superfan stack (cardinal torso, gold arms, gold cap, always-carried mitt
## pointing up past the head line), the civilian plain-clothes control (one
## palette shirt, no props), visitor/superfan cars in class body paint with
## the flag meshes visible and the banner top ≥ 2.2 m, and the civilian fleet
## unflagged in BODY_PALETTE — plus the contrast leg of every class color
## against the T-026 grounds (sidewalk, plaza, asphalt ≥ 0.20 Euclidean RGB).
func _scenario_citizen_classes_readable() -> void:
	await _set_up(true, _city.position + Vector3(0.0, 25.0, 0.0), Vector3.ZERO)
	## --- VISITOR pedestrians: the two-color pairing on every tourist --------
	var visitors_ok := true
	var finger_seen := false
	var rig := TouristSpawner.new()
	rig.city = _city
	rig.player = _player
	rig.visitor_share = 1.0
	rig.superfan_share = 0.0
	add_child(rig)
	await _wait_frames(4)
	var visitor_tourists: Array[Tourist] = rig.living_tourists()
	for tourist in visitor_tourists:
		visitors_ok = visitors_ok and tourist.citizen_class == CitizenClass.Kind.VISITOR \
				and _is_team_color(tourist._body_mesh) and _is_team_color(tourist._arm_l) \
				and _pairing_reads(tourist)
		if tourist.carries_finger:
			finger_seen = true
			visitors_ok = visitors_ok and tourist._mitt.visible and _mitt_reads_up(tourist)
		else:
			visitors_ok = visitors_ok and not tourist._mitt.visible \
					and not tourist._cap.visible
	visitors_ok = visitors_ok and finger_seen
	rig.free()
	## --- SUPERFAN pedestrians: the head-to-toe stack, always ----------------
	var superfan_ok := true
	rig = TouristSpawner.new()
	rig.city = _city
	rig.player = _player
	rig.visitor_share = 0.0
	rig.superfan_share = 1.0
	add_child(rig)
	await _wait_frames(4)
	for tourist in rig.living_tourists():
		var torso := tourist._body_mesh.material_override as StandardMaterial3D
		var arm_l := tourist._arm_l.material_override as StandardMaterial3D
		var arm_r := tourist._arm_r.material_override as StandardMaterial3D
		superfan_ok = superfan_ok and tourist.citizen_class == CitizenClass.Kind.SUPERFAN \
				and torso != null and torso.albedo_color.is_equal_approx(CitizenClass.SUPERFAN_CARDINAL) \
				and arm_l != null and arm_l.albedo_color.is_equal_approx(CitizenClass.TEAM_GOLD) \
				and arm_r != null and arm_r.albedo_color.is_equal_approx(CitizenClass.TEAM_GOLD) \
				and tourist._cap.visible and tourist._mitt.visible \
				and tourist.carries_finger and _mitt_reads_up(tourist)
	superfan_ok = superfan_ok and rig.living_tourists().size() == rig.target_count
	rig.free()
	## --- CIVILIAN pedestrians: the plain-clothes control --------------------
	var civilian_ok := true
	rig = TouristSpawner.new()
	rig.city = _city
	rig.player = _player
	rig.visitor_share = 0.0
	rig.superfan_share = 0.0
	add_child(rig)
	await _wait_frames(4)
	for tourist in rig.living_tourists():
		var torso := tourist._body_mesh.material_override as StandardMaterial3D
		var arm := tourist._arm_l.material_override as StandardMaterial3D
		var in_palette := false
		for shirt in Tourist.SHIRT_PALETTE:
			in_palette = in_palette or (torso != null
					and torso.albedo_color.is_equal_approx(shirt))
		civilian_ok = civilian_ok and tourist.citizen_class == CitizenClass.Kind.CIVILIAN \
				and in_palette and torso != null and arm != null \
				and arm.albedo_color.is_equal_approx(torso.albedo_color) \
				and not tourist._mitt.visible and not tourist._cap.visible
	civilian_ok = civilian_ok and rig.living_tourists().size() == rig.target_count
	rig.free()
	## --- VISITOR cars: full team paint, flag up, pairing carried ------------
	var visitor_cars_ok := true
	var car_rig := CarSpawner.new()
	car_rig.city = _city
	car_rig.player = _player
	car_rig.visitor_share = 1.0
	car_rig.superfan_share = 0.0
	add_child(car_rig)
	await _wait_frames(4)
	for car in car_rig.living_cars():
		var body := car._body_mesh.material_override as StandardMaterial3D
		var banner := car._flag_banner.material_override as StandardMaterial3D
		var body_is_gold: bool = body != null \
				and body.albedo_color.is_equal_approx(CitizenClass.TEAM_GOLD)
		var body_is_black: bool = body != null \
				and body.albedo_color.is_equal_approx(CitizenClass.VISITOR_BLACK)
		visitor_cars_ok = visitor_cars_ok and car.citizen_class == CitizenClass.Kind.VISITOR \
				and (body_is_gold or body_is_black) \
				and car._flag_pole.visible and car._flag_banner.visible \
				and banner != null \
				and banner.albedo_color.is_equal_approx(
						CitizenClass.VISITOR_BLACK if body_is_gold else CitizenClass.TEAM_GOLD) \
				and car._flag_banner.to_global(Vector3(0.0, 0.23, 0.0)).y >= 2.2
	visitor_cars_ok = visitor_cars_ok and car_rig.living_cars().size() \
			== car_rig.target_moving + car_rig.target_parked
	car_rig.free()
	## --- SUPERFAN cars: the faithful vehicle --------------------------------
	var superfan_cars_ok := true
	car_rig = CarSpawner.new()
	car_rig.city = _city
	car_rig.player = _player
	car_rig.visitor_share = 0.0
	car_rig.superfan_share = 1.0
	add_child(car_rig)
	await _wait_frames(4)
	for car in car_rig.living_cars():
		var body := car._body_mesh.material_override as StandardMaterial3D
		var banner := car._flag_banner.material_override as StandardMaterial3D
		superfan_cars_ok = superfan_cars_ok \
				and car.citizen_class == CitizenClass.Kind.SUPERFAN \
				and body != null and body.albedo_color.is_equal_approx(CitizenClass.SUPERFAN_CARDINAL) \
				and car._flag_pole.visible and car._flag_banner.visible \
				and banner != null and banner.albedo_color.is_equal_approx(CitizenClass.TEAM_GOLD) \
				and car._flag_banner.to_global(Vector3(0.0, 0.23, 0.0)).y >= 2.2
	superfan_cars_ok = superfan_cars_ok and car_rig.living_cars().size() \
			== car_rig.target_moving + car_rig.target_parked
	car_rig.free()
	## --- CIVILIAN cars: the unflagged palette fleet -------------------------
	var civilian_cars_ok := true
	car_rig = CarSpawner.new()
	car_rig.city = _city
	car_rig.player = _player
	car_rig.visitor_share = 0.0
	car_rig.superfan_share = 0.0
	add_child(car_rig)
	await _wait_frames(4)
	for car in car_rig.living_cars():
		var body := car._body_mesh.material_override as StandardMaterial3D
		var in_palette := false
		for paint in Car.BODY_PALETTE:
			in_palette = in_palette or (body != null
					and body.albedo_color.is_equal_approx(paint))
		civilian_cars_ok = civilian_cars_ok \
				and car.citizen_class == CitizenClass.Kind.CIVILIAN and in_palette \
				and not car._flag_pole.visible and not car._flag_banner.visible
	civilian_cars_ok = civilian_cars_ok and car_rig.living_cars().size() \
			== car_rig.target_moving + car_rig.target_parked
	car_rig.free()
	## --- the contrast leg: every class color vs every T-026 ground ----------
	var contrast_ok := true
	var gold_sidewalk := 0.0
	var black_asphalt := 0.0
	var cardinal_worst := 100.0
	for class_color: Color in [CitizenClass.TEAM_GOLD, CitizenClass.VISITOR_BLACK,
			CitizenClass.SUPERFAN_CARDINAL]:
		for ground_color: Color in [City.COLOR_SIDEWALK, City.COLOR_PLAZA,
				City.COLOR_ASPHALT]:
			var d := _rgb_dist(class_color, ground_color)
			contrast_ok = contrast_ok and d >= 0.20
			if class_color == CitizenClass.TEAM_GOLD \
					and ground_color == City.COLOR_SIDEWALK:
				gold_sidewalk = d
			if class_color == CitizenClass.VISITOR_BLACK \
					and ground_color == City.COLOR_ASPHALT:
				black_asphalt = d
			if class_color == CitizenClass.SUPERFAN_CARDINAL:
				cardinal_worst = minf(cardinal_worst, d)
	print("SIM DATA citizen_classes_readable: gold↔sidewalk %.3f black↔asphalt %.3f cardinal worst %.3f" % [
			gold_sidewalk, black_asphalt, cardinal_worst])
	_check("citizen_classes_readable",
			visitors_ok and superfan_ok and civilian_ok and visitor_cars_ok
					and superfan_cars_ok and civilian_cars_ok and contrast_ok,
			"visitors=%s (finger_seen=%s) superfans=%s civilians=%s · cars v=%s s=%s c=%s · contrast=%s" % [
					visitors_ok, finger_seen, superfan_ok, civilian_ok,
					visitor_cars_ok, superfan_cars_ok, civilian_cars_ok, contrast_ok])


## The T-121 reservation law, pinned bare: the civilian BODY_PALETTE carries
## NO team hue — exactly 5 entries, every one ≥ 0.20 Euclidean RGB from BOTH
## TEAM_GOLD and VISITOR_BLACK (the citizen_classes_readable contrast leg's
## own bar) — and the scene keeps the grown tell: pole 0.06×0.9×0.06, banner
## 0.62×0.9×0.03, flags hidden at rest, banner top 2.75 m (≥ the T-113 2.2 m
## read line). A palette revert (the old gold or near-black sneaking back) or
## a shrunken flag fails here.
func _scenario_civilian_palette_reserved() -> void:
	var palette := Car.BODY_PALETTE
	var size_ok := palette.size() == 5
	var worst_gold := 10.0
	var worst_black := 10.0
	for body: Color in palette:
		worst_gold = minf(worst_gold, _rgb_dist(body, CitizenClass.TEAM_GOLD))
		worst_black = minf(worst_black, _rgb_dist(body, CitizenClass.VISITOR_BLACK))
	var reserved_ok := worst_gold >= 0.20 and worst_black >= 0.20
	var car: Car = (load("res://scenes/car.tscn") as PackedScene).instantiate() as Car
	var pole: MeshInstance3D = car.get_node("Visual/FlagPole")
	var banner: MeshInstance3D = car.get_node("Visual/FlagBanner")
	var pole_mesh: BoxMesh = pole.mesh
	var banner_mesh: BoxMesh = banner.mesh
	var flag_ok := not pole.visible and not banner.visible \
			and pole_mesh.size.is_equal_approx(Vector3(0.06, 0.9, 0.06)) \
			and banner_mesh.size.is_equal_approx(Vector3(0.62, 0.9, 0.03))
	var banner_top := banner.position.y + banner_mesh.size.y * 0.5
	car.free()
	_check("civilian_palette_reserved",
			size_ok and reserved_ok and flag_ok and banner_top >= 2.2,
			"palette_n=%d worst_gold=%.3f worst_black=%.3f flag=%s banner_top=%.2f" % [
					palette.size(), worst_gold, worst_black, flag_ok, banner_top])


## The T-122 settings, pinned at the Game seam plus an end-to-end nose flip
## through the REAL player: with NO settings file load_settings() early-outs
## (boot mute stands, identity controls); pitch_axis() reads the raw axis and
## NEGATES with invert_pitch; the live pigeon's nose answers the SAME held
## key in OPPOSITE vertical directions across the toggle — the
## convention-free proof the helper feeds every flight consumer; a save
## round-trips through an independent ConfigFile read and load_settings()
## restores it onto the live state AND the buses. Every touched bus and the
## boot mute are restored before returning.
func _scenario_settings_persist_and_invert() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	Game.settings_path = SIM_SETTINGS_PATH
	if FileAccess.file_exists(SIM_SETTINGS_PATH):
		DirAccess.remove_absolute(SIM_SETTINGS_PATH)
	## Leg 1 — no file: identity. load_settings() early-outs, nothing applies.
	Game.invert_pitch = false
	Game.load_settings()
	var axis_rest := Game.pitch_axis()
	Input.action_press("pitch_up")
	await _wait_frames(2)
	var axis_raw := Game.pitch_axis()
	Input.action_release("pitch_up")
	## Leg 2 — the end-to-end sign flip through the real player.
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -16.0), 0.0)
	var nose0 := -_player.transform.basis.z.y
	for _i in 20:
		Input.action_press("pitch_up")
		await _wait_frames(1)
	Input.action_release("pitch_up")
	var nose_off := -_player.transform.basis.z.y
	var raises := nose_off > nose0 + 0.05
	Game.invert_pitch = true
	Input.action_press("pitch_up")
	await _wait_frames(2)
	var axis_inv := Game.pitch_axis()
	Input.action_release("pitch_up")
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -16.0), 0.0)
	var nose1 := -_player.transform.basis.z.y
	for _i in 20:
		Input.action_press("pitch_up")
		await _wait_frames(1)
	Input.action_release("pitch_up")
	var nose_on := -_player.transform.basis.z.y
	var lowers := nose_on < nose1 - 0.05
	Game.invert_pitch = false
	## Leg 3 — persistence round-trip + bus application + restore.
	Game.invert_pitch = true
	Game.volume_sfx = 0.5
	Game.settings_muted = false
	Game.save_settings()
	var check := ConfigFile.new()
	var round_trip := check.load(SIM_SETTINGS_PATH) == OK \
			and bool(check.get_value("controls", "invert_pitch", true)) \
			and is_equal_approx(float(check.get_value("audio", "sfx", 1.0)), 0.5) \
			and not bool(check.get_value("audio", "muted", true))
	Game.invert_pitch = false
	Game.volume_sfx = 1.0
	Game.settings_muted = true
	Game.load_settings() ## The boot path: restore from disk.
	var restored := Game.invert_pitch and is_equal_approx(Game.volume_sfx, 0.5) \
			and not Game.settings_muted \
			and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	var bus_ok := is_equal_approx(
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),
			linear_to_db(0.5))
	## Restore the harness audio state exactly (boot-muted, stock dB).
	Game.volume_master = 1.0
	Game.volume_sfx = 1.0
	Game.volume_ambience = 1.0
	Game.settings_muted = true
	Game.apply_audio_settings()
	DirAccess.remove_absolute(SIM_SETTINGS_PATH)
	_check("settings_persist_and_invert",
			axis_rest == 0.0 and axis_raw > 0.9 and axis_inv < -0.9 \
					and raises and lowers and round_trip and restored and bus_ok,
			"rest=%.2f raw=%.2f inv=%.2f raises=%s lowers=%s roundtrip=%s restored=%s bus=%s" % [
					axis_rest, axis_raw, axis_inv, raises, lowers, round_trip,
					restored, bus_ok])


## T-123's additions, driven end to end: the grounded pigeon coos on the idle
## cadence and chats faster while waddling; the SECOND splat (and only that
## parity) earns the smug coo; and each ending — victory then starvation
## through ONE real Main, the favor scenario's coexistence pattern — plays its
## stinger exactly once, audible even though the screen pauses the tree the
## same frame (the always-on ending voice). Restores the hunger knob, the
## staged Main and the run state.
func _scenario_sfx_coos_and_stingers() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	Sfx.reset_counts()
	## Leg A — idle coo: grounded, hands off, past the idle cadence.
	await _set_up(false, Vector3(0.0, 0.1, 0.0), Vector3.ZERO, 0.0)
	for _i in 600: ## 10 s of fixed frames — coo_idle_interval 9.0 fires once.
		await get_tree().physics_frame
	var idle_ok := int(Sfx.played_counts.get("coo_idle", 0)) >= 1 \
			and not Sfx.played_counts.has("coo_waddle")
	## Leg B — waddle coo: the clock just reset, so walking reaches ITS
	## cadence (6.0) before the idle one can re-arm.
	Input.action_press("pitch_up") ## The waddle-forward key.
	for _i in 400:
		await get_tree().physics_frame
	Input.action_release("pitch_up")
	var waddle_ok := int(Sfx.played_counts.get("coo_waddle", 0)) >= 1
	## Leg C — the smug coo rides tourist-splat parity (2nd, 4th, …).
	var tourist: Tourist = (load("res://scenes/tourist.tscn") as PackedScene) \
			.instantiate() as Tourist
	add_child(tourist)
	await _wait_frames(2)
	Game.tourist_hits = 1
	tourist.on_splatted(Vector3(0.0, 0.0, -3.0))
	var no_smug := not Sfx.played_counts.has("coo_smug")
	Game.tourist_hits = 2
	tourist.on_splatted(Vector3(0.0, 0.0, -3.0))
	var smug_once := int(Sfx.played_counts.get("coo_smug", 0)) == 1
	tourist.free()
	Game.reset_run() ## Zeroes the staged tourist_hits before the ending legs.
	## Leg D — the stingers, one real Main, both registers.
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(4500.0, 0.0, 4500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	Sfx.reset_counts()
	Game.favor = Game.favor_max - 1
	Game.add_favor(1) ## The real ceiling crossing — Main ends the run as a win.
	var win_ok := int(Sfx.played_counts.get("stinger_win", 0)) == 1 \
			and not Sfx.played_counts.has("stinger_lose") \
			and main_game.game_over_screen.is_open
	main_game.restart_run() ## Re-arms both endings (the favor scenario's path).
	Sfx.reset_counts()
	var saved_drain: float = Game.hunger.drain_per_second
	Game.hunger.drain_per_second = 60.0
	var starved := false
	for _i in 300:
		await get_tree().physics_frame
		if main_game.game_over_screen.is_open:
			starved = true
			break
	var lose_ok := starved and int(Sfx.played_counts.get("stinger_lose", 0)) == 1 \
			and not Sfx.played_counts.has("stinger_win")
	Game.hunger.drain_per_second = saved_drain
	main_game.free()
	get_tree().paused = false ## The starved screen paused the tree — the harness flies on unpaused.
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("sfx_coos_and_stingers",
			idle_ok and waddle_ok and no_smug and smug_once and win_ok and lose_ok,
			"idle=%s waddle=%s no_smug=%s smug_once=%s win=%s lose=%s (counts=%s)" % [
					idle_ok, waddle_ok, no_smug, smug_once, win_ok, lose_ok,
					Sfx.played_counts])


## T-125's boot-splash swap, pinned as project settings: the splash shows NO
## image (the Godot logo is gone) and its background is exactly the title
## screen's navy — a silent revert to the engine defaults fails here.
func _scenario_boot_splash_pinned() -> void:
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	var show_image: bool = ProjectSettings.get_setting("application/boot_splash/show_image")
	var menu: Control = (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	var menu_bg: Color = menu.get_node("Background").color
	menu.free()
	_check("boot_splash_pinned",
			not show_image and bg.is_equal_approx(Color(0.16, 0.22, 0.33)) \
					and bg.is_equal_approx(menu_bg),
			"bg=%s show_image=%s menu_bg=%s" % [bg, show_image, menu_bg])


## --- scenarios (T-114 favor economy) -----------------------------------------


## The favor book pays through the REAL chain (T-114), through the real main
## scene (the instanced-Main pattern, its own corner). Boot leg pins the main
## scene's spread at the T-114 law: the 6 parked-visitor tailgate crumbs are
## hand-placed, the spawned budget holds at 34 → 31 TABLE / 2 GROUND / 1 ROOF,
## 40 living crumbs total (the `restart_resets` contract intact). The splat
## legs force each share knob to a single-class rig (the
## `citizen_classes_readable` pattern) and re-populate, then drive the relay
## at a REAL living node — visitor, civilian and superfan tourists, then
## parked visitor and civilian cars: favor moves by EXACTLY that class's
## export every leg (asserted against the exports, never literals), the
## cumulative sum exact, and a synthetic `Game.add_tourist_hit` (the coach
## leg's entry) stays favor-silent. A landing between legs zeroes the combo
## while favor stands still — splat favor never touches the combo. The HUD
## legs drive `Game.add_favor` directly and read the label text, the
## gain/loss tints and the 2.5 s game-time expiry, then the restart_run
## reset. The pigeon is held airborne throughout so no elder trust can bank
## and no crumb can feed — the only favor movements are the driven ones.
func _scenario_splat_favor_follows_citizen_class() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	var tourists: TouristSpawner = main_game.get_node("TouristSpawner") as TouristSpawner
	var cars: CarSpawner = main_game.get_node("CarSpawner") as CarSpawner
	main_game.position = Vector3(6500.0, 0.0, -6500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	var pigeon: Player = main_game.player
	var hover: Vector3 = main_game.city.to_local(main_game.city.spawn_point) \
			+ Vector3(0.0, 60.0, 0.0)
	pigeon.reset_flight(hover) ## Airborne for the whole scenario — no trust, no crumbs eaten.
	await _wait_frames(6)
	var label: Label = main_game.favor_label
	## Boot leg: the shipped-knob spread.
	var tally := _live_tally(main_game.city, main_game.bread_spawner)
	var tailgates := 0
	for crumb in main_game.bread_spawner.living_crumbs():
		if crumb.spot_index < 0 and crumb.favor_delta == Game.favor_steal_visitor:
			tailgates += 1
	var boot_ok: bool = tally[City.BreadKind.TABLE] == 31 \
			and tally[City.BreadKind.GROUND] == 2 and tally[City.BreadKind.ROOF] == 1 \
			and tailgates == roundi(main_game.car_spawner.target_parked
					* main_game.car_spawner.visitor_share) \
			and main_game.bread_spawner.living_crumbs().size() \
					== main_game.bread_spawner.target_count \
			and label.text == "Favor: %d / %d" % [Game.favor, Game.favor_max]
	## The synthetic scoring entry stays favor-silent (the T-060 coach leg's call).
	Game.add_tourist_hit(main_game.city.spawn_point)
	var synthetic_silent := Game.favor == 0
	## Splat legs — tourist classes in turn.
	var expected := 0
	var visitor_ok := false
	tourists.visitor_share = 1.0
	tourists.superfan_share = 0.0
	tourists._populate()
	await _wait_frames(2)
	for tourist in tourists.living_tourists():
		if tourist.citizen_class == CitizenClass.Kind.VISITOR:
			expected += Game.favor_visitor_splat
			tourist.on_splatted(Vector3(3.0, -5.0, 0.0)) ## The duck-typed entry the drop calls.
			visitor_ok = Game.favor == expected
			break
	var civilian_ok := false
	tourists.visitor_share = 0.0
	tourists.superfan_share = 0.0
	tourists._populate()
	await _wait_frames(2)
	for tourist in tourists.living_tourists():
		if tourist.citizen_class == CitizenClass.Kind.CIVILIAN:
			expected += Game.favor_civilian_splat
			tourist.on_splatted(Vector3(3.0, -5.0, 0.0))
			civilian_ok = Game.favor == expected
			break
	var superfan_ok := false
	tourists.visitor_share = 0.0
	tourists.superfan_share = 1.0
	tourists._populate()
	await _wait_frames(2)
	for tourist in tourists.living_tourists():
		if tourist.citizen_class == CitizenClass.Kind.SUPERFAN:
			expected += Game.favor_superfan_splat
			tourist.on_splatted(Vector3(3.0, -5.0, 0.0))
			superfan_ok = Game.favor == expected
			break
	## A landing between legs: the combo zeroes while the favor balance stands.
	main_game.player.grounding_changed.emit(true)
	var landing_ok := Game.combo_multiplier() == 0 and Game.favor == expected
	## Splat legs — parked car classes in turn.
	var visitor_car_ok := false
	cars.visitor_share = 1.0
	cars.superfan_share = 0.0
	cars._populate()
	await _wait_frames(2)
	for car in cars.living_cars():
		if car.mode == Car.Mode.PARKED and car.citizen_class == CitizenClass.Kind.VISITOR:
			expected += Game.favor_visitor_car_splat
			car.on_splatted(Vector3(0.0, -5.0, 0.0))
			visitor_car_ok = Game.favor == expected
			break
	var civilian_car_ok := false
	cars.visitor_share = 0.0
	cars.superfan_share = 0.0
	cars._populate()
	await _wait_frames(2)
	for car in cars.living_cars():
		if car.mode == Car.Mode.PARKED and car.citizen_class == CitizenClass.Kind.CIVILIAN:
			expected += Game.favor_civilian_car_splat
			car.on_splatted(Vector3(0.0, -5.0, 0.0))
			civilian_car_ok = Game.favor == expected
			break
	var legs_ok: bool = visitor_ok and civilian_ok and superfan_ok and landing_ok \
			and visitor_car_ok and civilian_car_ok and synthetic_silent
	## HUD legs — drive the autoload directly, read the label: rest form,
	## gold gain note, the 2.5 s game-time expiry, red loss note, restart reset.
	## The splat legs left a delta note live — hold airborne past its 2.5 s
	## window first so the rest read is the genuine at-rest form.
	var rest_color := MainGame.FAVOR_REST_COLOR ## The column's scene fill.
	var high := main_game.city.to_local(main_game.city.spawn_point) \
			+ Vector3(0.0, 60.0, 0.0)
	for _i in 190: ## 2.5 s of game time at the fixed 60 Hz + margin — held airborne.
		pigeon.reset_flight(high)
		await get_tree().physics_frame
	var rest_ok: bool = label.text == "Favor: %d / %d" % [Game.favor, Game.favor_max] \
			and label.get_theme_color("font_color").is_equal_approx(rest_color)
	Game.add_favor(6)
	var gain_ok: bool = label.text == "Favor: %d / %d  (+6)" % [Game.favor, Game.favor_max] \
			and label.get_theme_color("font_color").is_equal_approx(MainGame.FAVOR_GAIN_COLOR)
	for _i in 190: ## The expiry: back to the rest text and the rest tint.
		pigeon.reset_flight(high)
		await get_tree().physics_frame
	var expired_ok: bool = label.text == "Favor: %d / %d" % [Game.favor, Game.favor_max] \
			and label.get_theme_color("font_color").is_equal_approx(rest_color)
	Game.add_favor(-1)
	var loss_ok: bool = label.text == "Favor: %d / %d  (-1)" % [Game.favor, Game.favor_max] \
			and label.get_theme_color("font_color").is_equal_approx(MainGame.FAVOR_LOSS_COLOR)
	main_game.restart_run()
	var restart_ok: bool = label.text == "Favor: 0 / %d" % Game.favor_max \
			and label.get_theme_color("font_color").is_equal_approx(rest_color)
	var final_text: String = label.text ## Read before the free below.
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("splat_favor_follows_citizen_class",
			boot_ok and legs_ok and rest_ok and gain_ok and expired_ok and loss_ok
					and restart_ok,
			"boot 31/2/1+6=%s synthetic-silent=%s legs v=%s c=%s s=%s landing=%s vc=%s cc=%s · HUD rest=%s gain=%s expired=%s loss=%s restart=%s ('%s')" % [
					boot_ok, synthetic_silent, visitor_ok, civilian_ok, superfan_ok,
					landing_ok, visitor_car_ok, civilian_car_ok, rest_ok, gain_ok,
					expired_ok, loss_ok, restart_ok, final_text])


## --- scenario (T-116 the meter names the prize) ------------------------------


## The goal layer announces itself (T-116), through the REAL main scene (the
## instanced-Main pattern, pigeon held airborne so no ambient crumb feed can
## move the balance mid-read): the favor meter reads against the elders'
## ceiling — rest "Favor: <n> / <max>", gold gain "Favor: <n> / <max>  (+6)"
## — interpolated from `Game.favor_max` (the value-lock pins T-115's tuning
## at 100; a silent retune FAILs the leg by design), debt still reads
## ("Favor: -3 / <max>" — the T-114 no-floor lock, shown not hidden), and
## restart_run() resets to "Favor: 0 / <max>". The scene-static %FavorGoal
## caption row under the meter states the win rule with the column's outline
## treatment at its dimmer caption fill — the scene owns the text and no code
## writes it, so these asserts ARE the whole contract. Cleanup matches the
## T-114 sibling: free() → Game.hunger.player = null → Game.reset_run().
func _scenario_favor_meter_names_the_ceiling() -> void:
	var favor_max_ok: bool = Game.favor_max == 100 ## (T-115) The tuning, locked.
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-2500.0, 0.0, 2500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var pigeon: Player = main_game.player
	var label: Label = main_game.favor_label
	var goal: Label = main_game.get_node("%FavorGoal") as Label
	var high := main_game.city.to_local(main_game.city.spawn_point) \
			+ Vector3(0.0, 60.0, 0.0)
	pigeon.reset_flight(high)
	await get_tree().physics_frame
	var rest_ok: bool = label.text == "Favor: %d / %d" % [Game.favor, Game.favor_max]
	var goal_ok: bool = goal != null \
			and goal.visible and goal.is_visible_in_tree() \
			and goal.text == "max the elders' favor to take the town" \
			and goal.offset_top >= label.offset_bottom \
			and goal.get_theme_font_size("font_size") == 14 \
			and goal.get_theme_constant("outline_size") == 4 \
			and goal.get_theme_color("font_color").is_equal_approx(Color(1.0, 1.0, 1.0, 0.6)) ## Under the meter, same column, the caption fill.
	Game.add_favor(6)
	var gain_ok: bool = label.text == "Favor: %d / %d  (+6)" % [Game.favor, Game.favor_max]
	Game.favor = -3 ## Staged directly — no emit — a zero add re-renders the rest form over it.
	Game.add_favor(0)
	var debt_ok: bool = label.text == "Favor: -3 / %d" % Game.favor_max
	main_game.restart_run()
	var restart_ok: bool = label.text == "Favor: 0 / %d" % Game.favor_max
	var final_text: String = label.text ## Read before the free below.
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("favor_meter_names_the_ceiling",
			favor_max_ok and rest_ok and goal_ok and gain_ok and debt_ok and restart_ok,
			"max=100=%s rest=%s goal=%s gain=%s debt=%s restart=%s ('%s')" % [
					favor_max_ok, rest_ok, goal_ok, gain_ok, debt_ok, restart_ok,
					final_text])


## The elder gate (T-114), on the `_add_elder_rig` rig with favor STAGED at
## setup: with `Game.favor = 0`, a grounded pigeon hangs the full
## `trust_needed` + 5 s margin — trust pins at `trust_needed` but NO share
## fires, no crumbs land, no favor is charged; then one
## `Game.add_favor(elder_loaf_cost * crumbs_per_share)` unblocks exactly one
## share within 3 physics frames (trust is still pinned — the gate was the
## only blocker) and favor reads exactly `elder_loaf_cost * crumbs_per_share`
## lower afterwards — the spend booked at the share, not the eat.
func _scenario_elder_bread_gates_on_favor() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.favor = 0 ## (T-114) Staged explicitly — the rig inherits otherwise.
	var rig := _add_elder_rig()
	var spawner: ElderSpawner = rig[0]
	var crumbs: BreadSpawner = rig[1]
	await _wait_frames(4)
	var elders := spawner.living_elders()
	if elders.is_empty():
		_check("elder_bread_gates_on_favor", false, "no elder spawned")
		spawner.free()
		(rig[1] as Node).free()
		return
	var elder: Elder = elders[0]
	var park := elder.global_position - elder.global_transform.basis.z * 2.6
	park.y = elder.global_position.y - Elder.SEAT_HEIGHT + 0.5
	await _set_up(true, park, Vector3.ZERO)
	await _await_grounded(90)
	var parked := _player.is_grounded and _player.position.distance_to(park) < 0.5
	var pinned := false
	for _i in int(elder.trust_needed * 60.0) + 300: ## trust_needed + the 5 s margin.
		await get_tree().physics_frame
		pinned = elder._trust >= elder.trust_needed - 0.001
	var broke_ok: bool = parked and pinned and _bread_shared.is_empty() \
			and crumbs.living_crumbs().is_empty() and elder.share_count == 0 \
			and Game.favor == 0
	Game.add_favor(Game.elder_loaf_cost * elder.crumbs_per_share) ## The gate money.
	var favor_after_pay := Game.favor
	var trust_at_pay := elder._trust ## Pinned — the gate was the only blocker.
	await _wait_frames(3) ## The share fires within 3 physics frames.
	## The share's own reset signature: trust was pinned at the pay, and the
	## share has since zeroed it (the post-share refill is single frames).
	var spent_ok: bool = _bread_shared.size() == 1 and _bread_shared[0].elder == elder \
			and int(_bread_shared[0].crumbs) == elder.crumbs_per_share \
			and trust_at_pay >= elder.trust_needed \
			and elder._trust < elder.trust_needed \
			and crumbs.living_crumbs().size() == elder.crumbs_per_share \
			and Game.favor == favor_after_pay - Game.elder_loaf_cost * elder.crumbs_per_share
	_check("elder_bread_gates_on_favor", broke_ok and spent_ok,
			"parked=%s trust pinned=%s (%.2f) broke: relays %d crumbs %d favor %d charged=%s · paid: shared=%d favor %.0f→%.0f (spend %d)" % [
					parked, pinned, elder._trust, _bread_shared.size(),
					crumbs.living_crumbs().size(), Game.favor, Game.favor != 0,
					_bread_shared.size(), float(favor_after_pay), float(Game.favor),
					Game.elder_loaf_cost * elder.crumbs_per_share])
	spawner.free()
	(rig[1] as Node).free()


## The steal surfaces (T-114), bare rigs over a real City, favor staged by
## `reset_run()`: a live TABLE crumb eaten grounded (the tabletop feed path)
## emits `crumb_favor` with exactly `Game.favor_steal_table` and the Main
## wiring (connect → `Game.add_favor`) books it; a hand-dropped
## `drop_crumb(pos, Game.favor_steal_visitor)` crumb eaten the same grounded
## way pays exactly `+favor_steal_visitor`; an ordinary GROUND crumb pays 0
## and emits nothing. Then the real tailgate surface on a `CarSpawner` rig at
## the shipped knobs: the scenario's own tally of living parked VISITOR cars
## (the exact integer quota of the knobs) equals the favor-marked crumb
## count, and every crumb sits at the documented gutter offset in its own
## car's frame — 0.45 m off the 0.95 m half-width body (the ≥ 0.45 m leg),
## 0.75 m back, at ground + the 0.06 lift, body-surface distance inside
## [0.45, 1.0] m — one crumb per car, bijection enforced. A forced
## `_recycle_far` re-anchor keeps the law: one crumb per living parked
## visitor after the shuffle. Zero RNG is structural (placement derives from
## the car transforms) — the seeded class multisets stay byte-identical via
## `citizen_classes_spawn_deterministic`, which re-runs green in every full
## suite pass.
func _scenario_bread_steal_favor_deltas() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run() ## Favor 0; the legs assert exact deltas against the exports.
	var rig := BreadSpawner.new()
	rig.city = _city
	rig.respawn_interval = 60.0 ## No top-ups inside the scenario.
	add_child(rig)
	await _wait_frames(4)
	_crumb_favor_events.clear()
	rig.crumb_favor.connect(func(delta: int) -> void: _crumb_favor_events.append(delta))
	rig.crumb_favor.connect(Game.add_favor) ## The Main wiring, on the bare rig.
	## Leg A — the TABLE steal through the real tabletop feed path.
	var table_crumb: BreadCrumb = null
	var table_ordinal := -1
	for crumb in rig.living_crumbs():
		if crumb.spot_index >= 0 \
				and _city.bread_spot_kinds[crumb.spot_index] == City.BreadKind.TABLE:
			table_crumb = crumb
			table_ordinal = 0
			for i in crumb.spot_index:
				if _city.bread_spot_kinds[i] == City.BreadKind.TABLE:
					table_ordinal += 1
			break
	var table_ok := false
	if table_crumb != null:
		var cafe_rig := CafeSpawner.new()
		cafe_rig.city = _city
		add_child(cafe_rig)
		await _wait_frames(4) ## The tabletop must stand before the drop (the distribution scenario's physical leg).
		var cafe: Transform3D = _city.cafe_spots[table_ordinal]
		var spot_global := _city.to_global(_city.bread_spots[table_crumb.spot_index])
		var toward := -cafe.basis.x ## From the crumb back across the tabletop.
		var walk_dir := -toward
		await _set_up(true, spot_global + toward * 0.6 + Vector3(0.0, 0.9, 0.0),
				Vector3.ZERO, rad_to_deg(atan2(-walk_dir.x, -walk_dir.z)))
		await _await_grounded(150)
		Input.action_press("pitch_up") ## The waddle-in drive; the feed may fire on the settle frame.
		for _i in 120:
			await get_tree().physics_frame
			table_ok = not is_instance_valid(table_crumb) \
					and Game.favor == Game.favor_steal_table \
					and _crumb_favor_events == [Game.favor_steal_table]
			if table_ok:
				break
		Input.action_release("pitch_up")
		cafe_rig.free()
	else:
		_check("bread_steal_favor_deltas", false, "no live TABLE crumb on the rig")
	## Leg B — the visitor steal: a favor-stamped drop eaten grounded pays +.
	await _set_up(false, Vector3(0.0, 0.4, 1.8), Vector3.ZERO) ## The bread_eating recipe.
	await _await_grounded(90)
	var favor_b := Game.favor
	var steal_crumb := rig.drop_crumb(Vector3(0.0, 0.16, 0.0), Game.favor_steal_visitor)
	await _hold("pitch_up", 90) ## Waddle in (facing -Z, crumb ahead).
	var steal_ok: bool = not is_instance_valid(steal_crumb) \
			and Game.favor == favor_b + Game.favor_steal_visitor \
			and _crumb_favor_events == [Game.favor_steal_table, Game.favor_steal_visitor]
	## Leg C — the GROUND control: an ordinary crumb pays 0 and emits nothing.
	var favor_c := Game.favor
	var plain_crumb := rig.drop_crumb(_player.global_position \
			- _player.transform.basis.z * 1.2 + Vector3(0.0, 0.1, 0.0))
	await _hold("pitch_up", 90)
	var plain_ok: bool = not is_instance_valid(plain_crumb) \
			and Game.favor == favor_c \
			and _crumb_favor_events == [Game.favor_steal_table, Game.favor_steal_visitor]
	## Leg D — the real tailgate surface: parked VISITOR cars anchor the crumbs.
	await _set_up(true, _city.position + PLAZA_DROP_OFFSET + Vector3(0.0, 25.0, 0.0),
			Vector3.ZERO)
	await _wait_frames(2)
	var car_rig := CarSpawner.new()
	car_rig.city = _city
	car_rig.player = _player
	car_rig.bread_spawner = rig ## The harness assigns directly (the elder-rig pattern).
	add_child(car_rig)
	await _wait_frames(6) ## Populate + the deferred dressing pass.
	var parked_visitors := 0
	for car in car_rig.living_cars():
		if car.mode == Car.Mode.PARKED and car.citizen_class == CitizenClass.Kind.VISITOR:
			parked_visitors += 1
	var tailgate_crumbs: Array[BreadCrumb] = []
	for crumb in rig.living_crumbs():
		if crumb.favor_delta == Game.favor_steal_visitor:
			tailgate_crumbs.append(crumb)
	var count_ok: bool = parked_visitors == tailgate_crumbs.size() \
			and parked_visitors == roundi(float(car_rig.target_parked) * car_rig.visitor_share)
	var geometry_ok := count_ok
	var claimed := {} ## car instance_id -> one crumb each — the bijection half.
	for crumb in tailgate_crumbs:
		var nearest: Car = null
		var best := INF
		for car in car_rig.living_cars():
			if car.mode != Car.Mode.PARKED:
				continue
			var d := crumb.global_position.distance_to(car.global_position)
			if d < best:
				best = d
				nearest = car
		if nearest == null or nearest.citizen_class != CitizenClass.Kind.VISITOR \
				or claimed.has(nearest.get_instance_id()):
			geometry_ok = false
			break
		claimed[nearest.get_instance_id()] = true
		## The documented gutter offset, read in the car's own frame: 0.45 m
		## off the 0.95 m half-width body, 0.75 m back, ground + 0.06 lift.
		## The body-surface distance lands inside [0.45, 1.0] m — off the
		## body, never buried into the car.
		var local := nearest.to_local(crumb.global_position)
		var dx := maxf(absf(local.x) - 0.95, 0.0)
		var dz := maxf(absf(local.z) - 2.2, 0.0)
		var body_dist := sqrt(dx * dx + dz * dz)
		geometry_ok = geometry_ok \
				and absf(local.x) >= 1.35 and absf(local.x) <= 1.45 \
				and absf(local.z) >= 0.65 and absf(local.z) <= 0.85 \
				and absf(local.y) <= 0.25 \
				and body_dist >= 0.44 and body_dist <= 1.0
	## The recycle re-anchor: force the scan from beyond the recycle radius —
	## re-parked visitors re-anchor, traffic-bound visitors release, and the
	## one-crumb-per-parked-visitor law holds afterwards.
	await _set_up(true, _city.position + Vector3(-120.0, 25.0, 0.0), Vector3.ZERO)
	await _wait_frames(2)
	car_rig._recycle_far()
	await _wait_frames(6)
	var parked_after := 0
	for car in car_rig.living_cars():
		if car.mode == Car.Mode.PARKED and car.citizen_class == CitizenClass.Kind.VISITOR:
			parked_after += 1
	var tailgates_after := 0
	for crumb in rig.living_crumbs():
		if crumb.favor_delta == Game.favor_steal_visitor:
			tailgates_after += 1
	var recycle_ok := tailgates_after == parked_after
	_check("bread_steal_favor_deltas",
			table_ok and steal_ok and plain_ok and count_ok and geometry_ok and recycle_ok,
			"table=%s (favor %d, events %s) steal=%s plain=%s · tailgates %d/%d (quota %d) geometry=%s bijection=%d · recycle %d/%d" % [
					table_ok, Game.favor, _crumb_favor_events, steal_ok, plain_ok,
					tailgate_crumbs.size(), parked_visitors,
					roundi(float(car_rig.target_parked) * car_rig.visitor_share),
					geometry_ok, claimed.size(), tailgates_after, parked_after])
	car_rig.free()
	rig.free()


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


## (T-073) The save throttle: only the run's FIRST record-beating hit pays the
## synchronous disk write — every further beat in the same run just marks the
## dirty flag — and the game-over flush (Game connects its own
## hunger.game_over to _flush_high_score in _ready) writes the file once more
## with the final score. The series runs on 20 bare add_tourist_hit calls,
## which escalate the combo (points 100×1 … 100×20, cumulative score 21,000 at
## hit 20); no landing or release is staged, so _release_age stays stale and
## the style gate cannot contaminate the series. Hit 1 scores 100 — not > the
## planted record, so no beat and no save; hit 2 is the FIRST beat (file = 300).
## The file is read back through an independent ConfigFile — never through
## Game.load_high_score(), which would overwrite Game.high_score itself. No
## live Main exists at this call slot (the T-077 scenario freed its instance
## and detached the hunger player), so Game's own flush is the only
## hunger.game_over listener the emit reaches.
func _scenario_highscore_save_throttled() -> void:
	Game.save_path = SIM_SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SIM_SAVE_PATH))
	Game.reset_run()
	Game.high_score = 100 ## The old record the chain must beat.
	var saves_before: int = Game._save_count
	for _i in 20:
		Game.add_tourist_hit(Vector3.ZERO)
	var file_at_beat: int = _read_sim_high()
	var beat_ok := Game._save_count == saves_before + 1 \
			and Game.score == 21000 and Game.high_score == 21000 \
			and file_at_beat == 300 ## The file holds the FIRST-beat score, not the final one.
	Game.hunger.game_over.emit() ## The game-over flush — exactly one more disk write.
	var file_at_flush: int = _read_sim_high()
	var flush_ok := Game._save_count == saves_before + 2 \
			and Game.high_score == 21000 \
			and file_at_flush == 21000 ## The flush wrote the final score.
	_check("highscore_save_throttled", beat_ok and flush_ok,
			"beat=%s flush=%s saves %d→%d score %d high %d file_beat %d file_flush %d" % [
					beat_ok, flush_ok, saves_before, Game._save_count,
					Game.score, Game.high_score, file_at_beat, file_at_flush])


## Reads the sim high-score file back independently of the Game autoload —
## never through Game.load_high_score(), which would overwrite
## Game.high_score. Returns -1 when the file is missing or unreadable.
func _read_sim_high() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SIM_SAVE_PATH) != OK:
		return -1
	return int(cfg.get_value("score", "high", -1))


## (T-115) The ceiling's book legs, bare autoload in the `highscore_save_throttled`
## window (directly after it: unpaused tree, no live Main): from `reset_run()`
## a −50 add reads −50 and emits delta −50 — the T-114 no-floor lock intact.
## Then with the balance re-staged at 0 and the T-073 dirty state staged
## (`_saved_this_run` true, `_high_score_dirty` true, a beaten record at 4200)
## one `add_favor(favor_max + 25)` overshoots and leaves favor EXACTLY
## `favor_max` (never over), emits the APPLIED delta (100, not the requested
## 125), pays exactly ONE disk write and the file reads the final 4200 back
## through an independent ConfigFile — the victory path's flush, the hunger
## path's twin. A further add clamps silently and fires NO second favor_maxed
## (and no further write — the latch owns both); and `reset_run()` re-arms: a
## second climb re-fires exactly once, its flush a no-op while the record is
## clean.
func _scenario_favor_max_book_clamps_and_flushes() -> void:
	Game.save_path = SIM_SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SIM_SAVE_PATH))
	Game.reset_run()
	_favor_delta_events.clear()
	_favor_maxed_fires = 0
	var changed_cb := func(_favor: int, delta: int) -> void: _favor_delta_events.append(delta)
	var maxed_cb := func() -> void: _favor_maxed_fires += 1
	Game.favor_changed.connect(changed_cb)
	Game.favor_maxed.connect(maxed_cb)
	var saves_before: int = Game._save_count
	Game.add_favor(-50)
	var floor_ok := Game.favor == -50 \
			and not _favor_delta_events.is_empty() \
			and _favor_delta_events[_favor_delta_events.size() - 1] == -50
	## Stage the T-073 dirty end-of-run state (and the balance at zero — the
	## climb must START at 0 so `favor_max + 25` overshoots and the clamp
	## engages; leg A's −50 debt is its own leg); the maxing add is the flush.
	Game.favor = 0
	Game.score = 4200
	Game.high_score = 4200
	Game.record_beaten = true
	Game._saved_this_run = true
	Game._high_score_dirty = true
	Game.add_favor(Game.favor_max + 25)
	var file_at_flush: int = _read_sim_high()
	var climb_ok := Game.favor == Game.favor_max \
			and _favor_delta_events[_favor_delta_events.size() - 1] == Game.favor_max \
			and Game._save_count == saves_before + 1 \
			and _favor_maxed_fires == 1 \
			and file_at_flush == 4200
	Game.add_favor(10)
	var silent_ok := Game.favor == Game.favor_max and _favor_maxed_fires == 1 \
			and Game._save_count == saves_before + 1
	Game.reset_run() ## Re-arms the latch beside favor = 0.
	var fires_at_rearm: int = _favor_maxed_fires
	Game.add_favor(Game.favor_max)
	var rearm_ok := Game.favor == Game.favor_max \
			and _favor_maxed_fires == fires_at_rearm + 1 \
			and Game._save_count == saves_before + 1 ## The latch flush is dirty-guarded: nothing clean to write.
	Game.favor_changed.disconnect(changed_cb)
	Game.favor_maxed.disconnect(maxed_cb)
	Game.reset_run() ## Leave the autoload as the next scenario expects it.
	_check("favor_max_book_clamps_and_flushes", floor_ok and climb_ok and silent_ok and rearm_ok,
			"floor=%s climb=%s silent=%s rearm=%s (favor %d, saves %d→%d, maxed fires %d, file %d)" % [
					floor_ok, climb_ok, silent_ok, rearm_ok, Game.favor,
					saves_before, Game._save_count, _favor_maxed_fires, file_at_flush])


## The popup (T-009): the ticket's "+100 ×2" format at the hit position, then
## float up, fade out and clean itself up after its lifetime. (T-038) The
## static STYLE-tag format variants get their own cheap (no instancing) check
## so the floats-and-fades assertions below stay byte-identical. (T-059) A
## second arm drives a REAL Main's own hit_scored spawn path with two hits 8 m
## apart in depth inside one second (well inside the 20 s combo window): the
## chained popups must carry distinct rise_totals exactly rise_step apart —
## the labels are the BARE combo payouts "+100" then "+200 ×2", because no
## poop release is ever staged (reset_run() re-stales _release_age to 999 and
## it only grows), so the style gate cannot fire and ×2 pays a plain 200.
func _scenario_score_popup() -> void:
	var plain_one := ScorePopup.format_text(150, 1) == "+150"
	var plain_two := ScorePopup.format_text(150, 2) == "+150 ×2"
	var styled_one := ScorePopup.format_text(150, 1, true) == "+150 STYLE"
	var styled_two := ScorePopup.format_text(150, 2, true) == "+150 ×2 STYLE"
	_check("score_popup_style_tag_format", plain_one and plain_two and styled_one and styled_two,
			"plain_one=%s plain_two=%s styled_one=%s styled_two=%s" % [
					plain_one, plain_two, styled_one, styled_two])
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
	## (T-059) The chained arm, through a REAL Main so the popups come through
	## Main's own hit_scored spawn path — instanced into its own space, clear of
	## the test world, and seeded by Game.reset_run() first. The lone popup
	## above freed (cleaned), so the group starts empty and the first hit takes
	## index 0 (rise_height), the second index 1 (rise_height + rise_step).
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-3500.0, 0.0, 3500.0) ## Own space, clear of the test world.
	add_child(main_game)
	await _wait_frames(4)
	var hit_base := main_game.global_position
	Game.add_tourist_hit(hit_base + Vector3(0.0, 0.5, 0.0))
	Game.add_tourist_hit(hit_base + Vector3(0.0, 0.5, 8.0)) ## 8 m deeper, same second.
	await _wait_frames(2) ## The popups' _ready has joined the group and indexed.
	## Read through the score_popups group BEFORE the scene frees the popups.
	var chain := get_tree().get_nodes_in_group("score_popups")
	var first: ScorePopup = null
	var second: ScorePopup = null
	for node in chain:
		var chained := node as ScorePopup
		if chained.label.text == "+100":
			first = chained
		elif chained.label.text == "+200 ×2":
			second = chained
	var chained_ok := chain.size() == 2 and first != null and second != null \
			and is_equal_approx(first.rise_total, first.rise_height) \
			and is_equal_approx(second.rise_total, first.rise_height + first.rise_step)
	var rise_first := first.rise_total if first != null else -1.0
	var rise_second := second.rise_total if second != null else -1.0
	var text_first := first.label.text if first != null else "?"
	var text_second := second.label.text if second != null else "?"
	var step_seen := first.rise_step if first != null else -1.0
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("score_popup_chain_stagger", chained_ok,
			"popups=%d first='%s' second='%s' rise_first=%.2f rise_second=%.2f rise_step=%.2f" % [
					chain.size(), text_first, text_second,
					rise_first, rise_second, step_seen])


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


## (T-115) The victory ending, end to end through the REAL main scene
## (instanced-Main pattern, pigeon held airborne): favor staged 2 under the
## ceiling, the parked fleet forced all-VISITOR (the T-114 rig pattern), and
## ONE real parked visitor car driven through Main's relay — favor reads
## EXACTLY `favor_max` (the clamp in the real chain), the tree pauses, the
## score screen opens in the VICTORY register (title, gold dim, note, the
## run's real splat counts plus the favor total) while hunger stands — this
## ending is NOT starvation — and Esc stays locked; a further splat books
## nothing past the clamp and fires no second `favor_maxed`. Coexistence: a
## direct `hunger.game_over` emit with the victory screen up changes NOTHING
## (first-wins); `restart_run()` unpauses, closes, zeroes and re-arms (a
## staged sub-max add fires nothing); then favor staged LOW, the T-010
## `drain_per_second` compression starves the run and the SAME screen opens
## in the STARVED! register — dark red dim, no note, plain breakdown — both
## entries having rewritten every mode-dependent property in one Main.
func _scenario_favor_max_ends_run_victory() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	_favor_maxed_fires = 0
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(6500.0, 0.0, 6500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	var pigeon: Player = main_game.player
	var cars: CarSpawner = main_game.get_node("CarSpawner") as CarSpawner
	var hover: Vector3 = main_game.city.to_local(main_game.city.spawn_point) \
			+ Vector3(0.0, 60.0, 0.0)
	pigeon.reset_flight(hover) ## Airborne for the whole scenario — no trust, no crumbs eaten.
	await _wait_frames(6)
	var maxed_cb := func() -> void: _favor_maxed_fires += 1
	Game.favor_maxed.connect(maxed_cb)
	Game.favor = Game.favor_max - Game.favor_visitor_car_splat ## Two under the ceiling: one jackpot wins.
	cars.visitor_share = 1.0
	cars.superfan_share = 0.0
	cars._populate()
	await _wait_frames(2)
	var first_car: Car = null
	for car in cars.living_cars():
		if car.mode == Car.Mode.PARKED and car.citizen_class == CitizenClass.Kind.VISITOR:
			first_car = car
			break
	var screen: GameOverScreen = main_game.game_over_screen
	var pause_menu: PauseMenu = main_game.get_node("PauseMenu")
	if first_car == null:
		_check("favor_max_ends_run_victory", false, "no parked VISITOR car after the all-visitor populate")
		Game.favor_maxed.disconnect(maxed_cb)
		main_game.free()
		Game.hunger.player = null
		Game.reset_run()
		return
	first_car.on_splatted(Vector3(0.0, -5.0, 0.0)) ## The duck-typed entry the drop calls — through Main's relay.
	pause_menu.toggle() ## Esc on a dead run must be refused.
	var victory_ok := Game.favor == Game.favor_max \
			and get_tree().paused and screen.is_open \
			and screen.title_label.text == GameOverScreen.VICTORY_TITLE \
			and screen.dim_rect.color.is_equal_approx(screen.victory_dim) \
			and screen.victory_note.visible \
			and screen.breakdown_label.text \
					== "Tourists splatted: 0    Cars splatted: 1    Favor: %d" % Game.favor_max \
			and not Game.hunger.game_over_emitted and Game.hunger.value > 0.0 \
			and pause_menu.locked
	## The latch is one-shot: a further splat books nothing past the clamp.
	var second_car: Car = null
	for car in cars.living_cars():
		if car != first_car and car.mode == Car.Mode.PARKED \
				and car.citizen_class == CitizenClass.Kind.VISITOR:
			second_car = car
			break
	var latch_ok := second_car != null
	if second_car != null:
		second_car.on_splatted(Vector3(0.0, -5.0, 0.0))
		latch_ok = latch_ok and Game.favor == Game.favor_max \
				and _favor_maxed_fires == 1 and screen.is_open and get_tree().paused
	## Coexistence leg 1 — starvation knocking on a won run changes nothing.
	Game.hunger.game_over.emit()
	var first_wins_ok := get_tree().paused and screen.is_open \
			and screen.title_label.text == GameOverScreen.VICTORY_TITLE \
			and screen.dim_rect.color.is_equal_approx(screen.victory_dim) \
			and screen.victory_note.visible \
			and screen.breakdown_label.text.contains("Favor:") \
			and _favor_maxed_fires == 1
	## Coexistence leg 2 — restart unpauses, closes, zeroes and re-arms.
	main_game.restart_run()
	var restart_ok := not get_tree().paused and not screen.is_open \
			and not screen.visible and Game.favor == 0 \
			and not Game.hunger.game_over_emitted
	Game.add_favor(Game.favor_max - 1) ## A staged sub-max add fires nothing.
	var submax_ok := Game.favor == Game.favor_max - 1 \
			and _favor_maxed_fires == 1 and not screen.is_open and not get_tree().paused
	## Coexistence leg 3 — the SAME Main starves into the STARVED! register.
	Game.favor = 2 ## Staged LOW: the register rewrite must not care about the balance.
	var drain_default: float = Game.hunger.drain_per_second
	Game.hunger.drain_per_second = 60.0 ## Time-compressed starvation (the T-010 scenario's compression).
	var starved := false
	for _i in 600: ## 10 s budget.
		await get_tree().physics_frame
		if get_tree().paused and screen.is_open:
			starved = true
			break
	var starved_ok := starved \
			and screen.title_label.text == GameOverScreen.STARVED_TITLE \
			and screen.dim_rect.color.is_equal_approx(GameOverScreen.STARVED_DIM) \
			and not screen.victory_note.visible \
			and screen.breakdown_label.text == "Tourists splatted: 0    Cars splatted: 0" \
			and Game.hunger.game_over_emitted
	Game.hunger.drain_per_second = drain_default ## Put the autoload's clock back.
	var text_at_read: String = screen.title_label.text
	Game.favor_maxed.disconnect(maxed_cb)
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	get_tree().paused = false ## Never leak a pause into later scenarios.
	_check("favor_max_ends_run_victory",
			victory_ok and latch_ok and first_wins_ok and restart_ok and submax_ok and starved_ok,
			"victory=%s latch=%s first_wins=%s restart=%s submax=%s starved=%s (end title '%s', fires %d)" % [
					victory_ok, latch_ok, first_wins_ok, restart_ok, submax_ok, starved_ok,
					text_at_read, _favor_maxed_fires])


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


## Reads the "<what> <n> m" distance out of the pointer text — -1.0 when the
## text is not in that exact shape (hidden, empty, malformed). STRICT since
## T-111: exactly three parts, "m" last. The T-098 climb cue and the T-058
## stern suffix are deleted from the game, so ANY re-introduced trailing
## decoration — " ▲", " ▼", " — turn around" — turns every distance readout
## into -1.0 and fails every arm that asserts a distance.
func _pointer_distance_m(text: String) -> float:
	var parts := text.strip_edges().split(" ")
	if parts.size() == 3 and parts[2] == "m":
		return float(parts[1])
	return -1.0


## T-111 (formerly the T-037/T-057/T-098/T-058 chevron scenario): the HUD
## bread pointer through the REAL main scene, on the bread globe. Registered in
## the T-019 window — immediately after _scenario_restart_resets, before
## _scenario_hud_hunger_tiers: the only spot with an unpaused tree and no live
## Main (the pointer updates in _process), with the same cleanup tail (free() →
## Game.hunger.player = null → Game.reset_run()) handing the window back.
## THE WIDGET READS NO CAMERA — the T-057 chase-camera convergence loops are
## gone: every arm is reset_flight → 2-frame wait → sample. All expectations
## come from the scenario's own recompute off the LIVE player basis and crumb
## positions — never through the widget's code (the no-self-test rule):
## `basis.inverse() * delta.normalized()` dotted against the published
## `dir_local` (≥ 0.999), and the formula-free screen properties below.
## Arms, in run order:
## - dead-ahead-level: a drop_crumb 10 m down the nose axis at hover height,
##   scan-decided — dir_local matches its recompute (dot ≥ 0.999), the tip
##   lands on the fly-to pip within 1 px, screen_offset points up (y < 0) and
##   axial (|x| < 1), the text parses strict "<what> <n> m" ± 1 m with no
##   ▲/▼/suffix (T-098/T-058 retired); the STRICT form — dir_local (0, 0, −1)
##   within 0.01, the machine form of "steer along the segment and you
##   intersect the bread" — is sampled same-frame as a fresh reset_flight
##   through the real aim path, because one free-fall tick of T-082
##   nose-toward-fall trim (~1°/tick) would honestly tip a pigeon-frame read
##   off world-level dead ahead; then the SAME crumb at yaw 180 — dir_local
##   tracks its own recompute (the yaw-follow arm) and now reads stern
##   (dir_local.z > 0.9, screen down).
## - approach countdown + eat-and-re-aim through the real grounded waddle-in;
##   the just-eaten re-aim FLASHES (a freed previous counts as a change).
## - overhead (the T-098 motivating case): grounded pigeon, a placed crumb
##   ~10 m up, scan-decided — |screen_offset| strictly exceeds the dead-ahead
##   arm's (foreshortening orders ahead < above: the tilt is load-bearing).
## - stern (the T-058 motivating case): hover 10 m up, a placed crumb 5 m
##   behind-below — dir_local.z > 0 and screen_offset.y > 0, bare text.
## - flash state machine: crumb A named and at rest (no flash on steady
##   same-crumb frames), a nearer B dropped — flash_active flips true
##   immediately and the text re-aims ± 1 m; after flash_seconds (0.4 s) of
##   game time it is back at rest.
## - city mode at the yaw-90 edge hover: "city <n> m" ± 2 m of the horizontal
##   distance, the globe aims at city.spawn_point through the same mapping
##   (dot ≥ 0.999), and city frames never flash.
## - restart_run(): the first acquisition after the reset never flashes.
## - zero-delta guard: a direct `_aim_bread_pointer(pigeon_pos, "bread", 0.0)`
##   keeps the last drawn direction, finite — never a NaN (the call and the
##   read-back share one frame, no await between).
## - nearest_crumb()'s null arm and the label's T-019 theme read.
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
	var globe: BreadGlobe = main_game.bread_globe
	## Independent expectation, recomputed from the LIVE pose and the crumb's
	## live position — never through the widget's code.
	var recompute_dot := func(from: Player, target: Vector3) -> float:
		var want: Vector3 = from.global_transform.basis.inverse() \
				* (target - from.global_position).normalized()
		return globe.dir_local.dot(want)
	## --- dead-ahead-level + yaw follow -----------------------------------------
	## An in-ring street spot whose 8 m hover sits ≥ 12 m from every living
	## crumb in 3D, so the placed crumb — exactly 10 m down the nose axis at
	## hover height — wins the independent 3D scan by construction.
	var ahead_ground := Vector3.ZERO
	for spot in city.bread_spots:
		var spot_world := city.to_global(spot)
		if spot_world.y > 0.3:
			continue
		var off_centre: Vector3 = spot_world - city.global_position
		off_centre.y = 0.0
		if off_centre.length() > city.city_span * 0.35:
			continue
		var probe_hover := spot_world + Vector3(0.0, 8.0, 0.0)
		var clear := true
		for crumb in spawner.living_crumbs():
			if probe_hover.distance_to(crumb.global_position) < 12.0:
				clear = false
				break
		if clear:
			ahead_ground = spot_world
			break
	var ahead_placed: BreadCrumb = null
	var ahead_ok := false
	var ahead_yaw_ok := false
	var ahead_exact := false
	var ahead_on_pip := false
	var ahead_screen := Vector2.ZERO
	var ahead_text := ""
	var ahead_dot := -2.0
	var yaw_dot := -2.0
	if ahead_ground != Vector3.ZERO:
		pigeon.reset_flight(city.to_local(ahead_ground + Vector3(0.0, 8.0, 0.0)), 0.0)
		var nose_pos: Vector3 = pigeon.global_position \
				- pigeon.global_transform.basis.z * 10.0
		spawner.drop_crumb(nose_pos)
		for crumb in spawner.living_crumbs():
			if crumb.global_position.distance_to(nose_pos) < 0.5:
				ahead_placed = crumb
				break
		await _wait_frames(2)
		var at_ahead := pigeon.global_position
		var want: BreadCrumb = _scan_nearest_crumb(spawner, at_ahead)
		if ahead_placed != null and want == ahead_placed:
			ahead_dot = recompute_dot.call(pigeon, ahead_placed.global_position)
			ahead_screen = globe.screen_offset
			ahead_text = pointer.text
			var shown := _pointer_distance_m(ahead_text)
			var dist_ok := pointer.visible and globe.visible and shown >= 0.0 \
					and absf(shown - at_ahead.distance_to(ahead_placed.global_position)) <= 1.0
			var bare_ok := shown >= 0.0 and not ahead_text.contains("▲") \
					and not ahead_text.contains("▼") and not ahead_text.contains("—")
			## The strict form — dir_local (0, 0, −1) within 0.01 — needs the
			## pigeon's pose EXACTLY at its reset frame: one physics tick of
			## free fall develops ~1° of nose-toward-fall trim (the T-082
			## aligner), which a pigeon-frame read HONESTLY reports. So the
			## strict leg samples the same frame as a fresh reset_flight —
			## no await between, no tick, pitch exactly 0 — through the real
			## _aim_bread_pointer path (the zero-delta arm's call shape).
			pigeon.reset_flight(city.to_local(ahead_ground + Vector3(0.0, 8.0, 0.0)), 0.0)
			main_game._aim_bread_pointer(ahead_placed.global_position, "bread",
					pigeon.global_position.distance_to(ahead_placed.global_position))
			ahead_exact = globe.dir_local.distance_to(Vector3(0.0, 0.0, -1.0)) <= 0.01
			ahead_on_pip = ahead_screen.distance_to(Vector2(
					0.0, -globe.segment_px * sin(deg_to_rad(globe.vantage_tilt_deg)))) <= 1.0
			ahead_ok = ahead_dot >= 0.999 and ahead_exact and ahead_on_pip \
					and ahead_screen.y < 0.0 and absf(ahead_screen.x) < 1.0 \
					and dist_ok and bare_ok
			## --- yaw follow: the same crumb, nose the other way ------------------
			pigeon.reset_flight(city.to_local(ahead_ground + Vector3(0.0, 8.0, 0.0)), 180.0)
			await _wait_frames(2)
			var at_yaw := pigeon.global_position
			if _scan_nearest_crumb(spawner, at_yaw) == ahead_placed:
				yaw_dot = recompute_dot.call(pigeon, ahead_placed.global_position)
				ahead_yaw_ok = yaw_dot >= 0.999 \
						and globe.dir_local.z > 0.9 \
						and globe.screen_offset.y > 0.0
	## --- approaching the pointed-at crumb decreases the readout ----------------
	var approach_ok := false
	var shown_near := -1.0
	var d_near := -1.0
	if ahead_placed != null:
		pigeon.reset_flight(city.to_local(
				ahead_placed.global_position + Vector3(2.6, 2.0, 0.0)), 0.0)
		await _wait_frames(2)
		var at_near := pigeon.global_position
		if _scan_nearest_crumb(spawner, at_near) == ahead_placed:
			d_near = at_near.distance_to(ahead_placed.global_position)
			shown_near = _pointer_distance_m(pointer.text)
			approach_ok = shown_near >= 0.0 and shown_near < _pointer_distance_m(ahead_text) \
					and absf(shown_near - d_near) <= 1.0 and d_near < 10.0
	## --- eat the pointed-at crumb through the real grounded waddle-in ----------
	## The drop mirrors _scenario_bread_eating: 1.8 m ahead (yaw 0 walks -Z,
	## straight into the crumb), settle grounded, then waddle until it is
	## eaten. (T-111) The re-aim at the next-nearest must FLASH: the eaten
	## previous counts as a change even though it is freed.
	var eat_target: BreadCrumb = null
	var best_eat := INF
	for crumb in spawner.living_crumbs():
		if crumb.global_position.y > 0.3:
			continue
		var d := city.spawn_point.distance_squared_to(crumb.global_position)
		if d < best_eat:
			best_eat = d
			eat_target = crumb
	var reaim_ok := false
	var eaten := false
	var reaim_flashed := false
	if eat_target != null:
		pigeon.reset_flight(city.to_local(eat_target.global_position + Vector3(0.0, 0.4, 1.8)))
		for _i in 90:
			await get_tree().physics_frame
			if pigeon.is_grounded:
				break
		Input.action_press("pitch_up")
		for _i in 120:
			await get_tree().physics_frame
			eaten = not is_instance_valid(eat_target)
			if eaten:
				break
		Input.action_release("pitch_up")
		await _wait_frames(2) ## Pointer refresh + the queue_free flush.
		var at2 := pigeon.global_position
		var want2: BreadCrumb = _scan_nearest_crumb(spawner, at2)
		reaim_flashed = globe.flash_active
		## A freed previous compares equal to null in Godot 4 — `want2 != eat_target`
		## holds against the freed instance either way.
		reaim_ok = eaten and want2 != null and (want2 != eat_target) \
				and pointer.visible \
				and absf(_pointer_distance_m(pointer.text)
						- at2.distance_to(want2.global_position)) <= 1.0
	## --- overhead: the T-098 motivating case on the globe ----------------------
	## The roof-crumb failure shape: a GROUNDED pigeon, a hand-placed crumb
	## ~10 m overhead (drop_crumb). Pre-pick an in-ring street spot whose
	## GROUND column is ≥ 12 m from every living crumb, so the placed crumb
	## (~10 m up) beats every other crumb in the 3D scan from the grounded
	## pigeon — scan-decided against the scan oracle, never nearest_crumb().
	var up_ground := Vector3.ZERO
	for spot in city.bread_spots:
		var spot_world := city.to_global(spot)
		if spot_world.y > 0.3:
			continue
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
			up_ground = spot_world
			break
	var up_placed: BreadCrumb = null
	var up_ok := false
	var up_screen_len := -1.0
	var up_dot := -2.0
	var up_text := ""
	if up_ground != Vector3.ZERO:
		pigeon.reset_flight(city.to_local(up_ground + Vector3(0.0, 0.4, 0.0)))
		spawner.drop_crumb(up_ground + Vector3(0.0, 10.0, 0.0))
		for crumb in spawner.living_crumbs():
			if crumb.global_position.distance_to(up_ground + Vector3(0.0, 10.0, 0.0)) < 0.5:
				up_placed = crumb
				break
		for _i in 90:
			await get_tree().physics_frame
			if pigeon.is_grounded:
				break
		await _wait_frames(2)
		var at_up := pigeon.global_position
		if up_placed != null and pigeon.is_grounded \
				and _scan_nearest_crumb(spawner, at_up) == up_placed:
			up_dot = recompute_dot.call(pigeon, up_placed.global_position)
			up_screen_len = globe.screen_offset.length()
			up_text = pointer.text
			var up_shown := _pointer_distance_m(up_text)
			up_ok = up_dot >= 0.999 \
					and up_screen_len > ahead_screen.length() \
					and pointer.visible and globe.visible and up_shown >= 0.0 \
					and absf(up_shown - at_up.distance_to(up_placed.global_position)) <= 1.0 \
					and not up_text.contains("▲") and not up_text.contains("▼") \
					and not up_text.contains("—")
	## --- stern: the T-058 motivating case on the globe --------------------------
	## An in-ring street spot whose 10 m hover sits ≥ 14 m from every living
	## crumb, so the hand-placed crumb — 5 m due +Z at street level, ~11.2 m
	## from the hover — wins the scan. The hover's nose faces −Z (yaw 0), so
	## the crumb rides strictly BEHIND the pigeon: dir_local.z > 0 and the
	## drawn segment points DOWN (screen_offset.y > 0), bare text.
	var stern_ground := Vector3.ZERO
	for spot in city.bread_spots:
		var spot_world := city.to_global(spot)
		if spot_world.y > 0.3:
			continue
		var stern_off: Vector3 = spot_world - city.global_position
		stern_off.y = 0.0
		if stern_off.length() > city.city_span * 0.35:
			continue
		var stern_hover := spot_world + Vector3(0.0, 10.0, 0.0)
		var hover_clear := true
		for crumb in spawner.living_crumbs():
			if stern_hover.distance_to(crumb.global_position) < 14.0:
				hover_clear = false
				break
		if hover_clear:
			stern_ground = spot_world
			break
	var stern_placed: BreadCrumb = null
	var stern_ok := false
	var stern_dot := -2.0
	var stern_text := ""
	var stern_screen_y := 0.0
	if stern_ground != Vector3.ZERO:
		pigeon.reset_flight(city.to_local(stern_ground + Vector3(0.0, 10.0, 0.0)), 0.0)
		spawner.drop_crumb(stern_ground + Vector3(0.0, 0.3, 5.0))
		for crumb in spawner.living_crumbs():
			if crumb.global_position.distance_to(
					stern_ground + Vector3(0.0, 0.3, 5.0)) < 0.5:
				stern_placed = crumb
				break
		await _wait_frames(2)
		var at_stern := pigeon.global_position
		if stern_placed != null and _scan_nearest_crumb(spawner, at_stern) == stern_placed:
			stern_dot = recompute_dot.call(pigeon, stern_placed.global_position)
			stern_text = pointer.text
			stern_screen_y = globe.screen_offset.y
			var stern_shown := _pointer_distance_m(stern_text)
			stern_ok = stern_dot >= 0.999 \
					and globe.dir_local.z > 0.0 and globe.screen_offset.y > 0.0 \
					and pointer.visible and stern_shown >= 0.0 \
					and absf(stern_shown - at_stern.distance_to(stern_placed.global_position)) <= 1.0 \
					and not stern_text.contains("—")
	## --- flash state machine ----------------------------------------------------
	## Crumb A named and at rest (no flash on steady same-crumb frames), then
	## a nearer B on the same axis: flash_active flips true immediately and
	## the text re-aims ± 1 m; after flash_seconds (0.4 s = 24 frames) of game
	## time it is back at rest. All waits re-pin the hover, so the pose and
	## the named crumb stay put while the flash runs down in game time.
	var flash_ground := Vector3.ZERO
	for spot in city.bread_spots:
		var spot_world := city.to_global(spot)
		if spot_world.y > 0.3:
			continue
		var flash_off: Vector3 = spot_world - city.global_position
		flash_off.y = 0.0
		if flash_off.length() > city.city_span * 0.35:
			continue
		var flash_hover := spot_world + Vector3(0.0, 8.0, 0.0)
		var flash_clear := true
		for crumb in spawner.living_crumbs():
			if flash_hover.distance_to(crumb.global_position) < 12.0:
				flash_clear = false
				break
		if flash_clear:
			flash_ground = spot_world
			break
	var flash_a: BreadCrumb = null
	var flash_b: BreadCrumb = null
	var flash_ok := false
	var steady_quiet := false
	var flash_fired := false
	var flash_text_ok := false
	var flash_settled := false
	if flash_ground != Vector3.ZERO:
		var flash_hover_local := city.to_local(flash_ground + Vector3(0.0, 8.0, 0.0))
		pigeon.reset_flight(flash_hover_local, 0.0)
		var a_pos: Vector3 = pigeon.global_position \
				- pigeon.global_transform.basis.z * 10.0
		spawner.drop_crumb(a_pos)
		for crumb in spawner.living_crumbs():
			if crumb.global_position.distance_to(a_pos) < 0.5:
				flash_a = crumb
				break
		await _wait_frames(2)
		if flash_a != null and _scan_nearest_crumb(spawner, pigeon.global_position) == flash_a:
			for _i in 5: ## Wait out any arrival flash (25 frames, re-pinned).
				pigeon.reset_flight(flash_hover_local, 0.0)
				await _wait_frames(5)
			steady_quiet = not globe.flash_active
			for _i in 1: ## Steady same-crumb frames never re-flash.
				pigeon.reset_flight(flash_hover_local, 0.0)
				await _wait_frames(5)
			steady_quiet = steady_quiet and not globe.flash_active
			var b_pos: Vector3 = pigeon.global_position \
					- pigeon.global_transform.basis.z * 5.0
			spawner.drop_crumb(b_pos)
			for crumb in spawner.living_crumbs():
				if crumb.global_position.distance_to(b_pos) < 0.5:
					flash_b = crumb
					break
			await _wait_frames(2)
			var at_b := pigeon.global_position
			var shown_b := _pointer_distance_m(pointer.text)
			flash_fired = flash_b != null \
					and _scan_nearest_crumb(spawner, at_b) == flash_b \
					and globe.flash_active
			flash_text_ok = flash_b != null and shown_b >= 0.0 \
					and absf(shown_b - at_b.distance_to(flash_b.global_position)) <= 1.0
			for _i in 3: ## 24 more frames = flash_seconds of game time, re-pinned.
				pigeon.reset_flight(flash_hover_local, 0.0)
				await _wait_frames(8)
			flash_settled = not globe.flash_active
			flash_ok = steady_quiet and flash_fired and flash_text_ok and flash_settled
	## --- city mode beyond the ring ----------------------------------------------
	## The existing yaw-90 hover geometry: home (city.spawn_point) sits due
	## −X from the (span/2+40, 30, 0) city-edge hover, dead ahead. The globe
	## must aim at home through the same mapping, the text must parse strict
	## "city <n> m" ± 2 m of the horizontal distance — no suffix, no cue —
	## and city-mode frames never flash and never touch the flash memory.
	var city_hover := Vector3(city.city_span * 0.5 + 40.0, 30.0, 0.0)
	pigeon.reset_flight(city_hover, 90.0)
	await _wait_frames(2)
	var home := city.spawn_point
	var flat_home := Vector2(home.x - pigeon.global_position.x,
			home.z - pigeon.global_position.z)
	var city_dot: float = recompute_dot.call(pigeon, home)
	var city_text := pointer.text
	var city_shown := _pointer_distance_m(city_text)
	var city_ok: bool = pointer.visible and globe.visible \
			and city_text.begins_with("city ") and city_shown >= 0.0 \
			and not city_text.contains("—") \
			and absf(city_shown - flat_home.length()) <= 2.0 \
			and city_dot >= 0.999 \
			and not globe.flash_active
	## --- restart: the first acquisition never flashes ----------------------------
	main_game.restart_run()
	await _wait_frames(3) ## The queue_free'd old spawns flush out.
	var restart_ok: bool = not globe.flash_active and pointer.visible and globe.visible
	## --- zero-delta guard: keep the last drawn direction, never a NaN -----------
	## The call and the read-back share one frame — no await between, so no
	## _process tick can interleave. Aiming at the pigeon's own position hits
	## the length² < 0.0001 bail: the published direction must hold exactly.
	var dir_before := globe.dir_local
	var screen_before := globe.screen_offset
	main_game._aim_bread_pointer(pigeon.global_position, "bread", 0.0)
	var guard_ok: bool = globe.dir_local == dir_before \
			and globe.screen_offset == screen_before \
			and is_finite(globe.dir_local.x) and is_finite(globe.dir_local.y) \
			and is_finite(globe.dir_local.z)
	## --- the T-019 outline treatment --------------------------------------------
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
			ahead_ok and ahead_yaw_ok and approach_ok and reaim_ok and reaim_flashed
					and up_ok and stern_ok and flash_ok and city_ok and restart_ok
					and guard_ok and style_ok and none_ok,
			"ahead=%s (dot %.4f exact %s pip %s screen %s text '%s') yaw=%s (dot %.4f) approach=%s (%.0f→%.0f) reaim=%s (eaten %s flashed %s) up=%s (dot %.4f len %.1f) stern=%s (dot %.4f screen_y %s) flash=%s (quiet %s fired %s text %s settled %s) city=%s (dot %.4f '%s') restart=%s guard=%s style=%s none=%s" % [
					ahead_ok, ahead_dot, ahead_exact, ahead_on_pip, ahead_screen, ahead_text,
					ahead_yaw_ok, yaw_dot,
					approach_ok, _pointer_distance_m(ahead_text), shown_near,
					reaim_ok, eaten, reaim_flashed,
					up_ok, up_dot, up_screen_len,
					stern_ok, stern_dot, stern_screen_y,
					flash_ok, steady_quiet, flash_fired, flash_text_ok, flash_settled,
					city_ok, city_dot, city_text,
					restart_ok, guard_ok, style_ok, none_ok])
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
	## (T-075) The tier-OR-percent bar-write guard's load-bearing half: a tier
	## boundary crossed while the rounded percent STANDS STILL must still
	## rewrite the bar and repaint — 50.4% (percent 50, tier 0) sliding to
	## 49.98% (percent 50 still, tier 1 now). A percent-only guard would leave
	## hunger_bar.value parked at 50.4 here.
	Game.hunger.value = 50.4
	var boundary_bar_before: float = bar.value
	Game.hunger.value = 49.98
	var boundary_ok: bool = main_game.hud_warning_tier == 1 \
			and not is_equal_approx(bar.value, boundary_bar_before) \
			and bar.modulate.is_equal_approx(MainGame.TIER_REST_COLORS[1])
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
					and faster and boundary_ok and refill_rest and restart_rest,
				"outline=%s styleboxes=%s tiers=%s quiet_static=%s pulse2=%s (g %.2f..%.2f, %d x) pulse3=%s (g %.2f..%.2f, %d x) faster=%s boundary=%s refill_rest=%s restart_rest=%s" % [
					outline_ok, styleboxes_ok, tiers_ok, quiet_static,
					pulse2, tier2_lo, tier2_hi, tier2_crossings,
					pulse3, tier3_lo, tier3_hi, tier3_crossings,
					faster, boundary_ok, refill_rest, restart_rest])


## --- scenario (T-099 pause-menu controls recap) ------------------------------


## The pause panel recap (T-099), through the REAL main scene: a fresh run has
## the panel — and the two recap lines riding its CanvasLayer — hidden;
## pause_menu.toggle() pauses the tree and shows both lines under the buttons;
## toggle() again hides them and unpauses. The key families (W/S, A/D, Space,
## F) are matched BI-DIRECTIONALLY against MainGame.HINT_AIR / HINT_GROUND, so
## a future constant edit that drops or gains a family — or a scene edit that
## drops one from the recap — fails the gate (scene files cannot reference
## script constants, T-039's precedent, so the duplicated copy needs this
## guard). Both lines also carry the T-019 treatment, exactly like the hint
## line. Registered in the T-019 window: unpaused tree, no live Main; leaves
## it exactly that — the pause is toggled back off before the instance frees.
func _scenario_pause_menu_shows_controls() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-2500.0, 0.0, -2500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var box: VBoxContainer = main_game.get_node("PauseMenu/Center/PausePanel/Box")
	var air_controls: Label = main_game.get_node("%AirControls") as Label
	var ground_controls: Label = main_game.get_node("%GroundControls") as Label
	var buttons := box.get_child_count()
	var placed_ok: bool = air_controls != null and ground_controls != null \
			and air_controls.get_parent() == box and ground_controls.get_parent() == box \
			and box.get_child(buttons - 2) == air_controls \
			and box.get_child(buttons - 1) == ground_controls ## Appended below the buttons.
	var hidden_at_rest: bool = not main_game.pause_menu.visible ## Fresh run: recap rides the hidden panel.
	main_game.pause_menu.toggle()
	var shown_ok: bool = get_tree().paused and main_game.pause_menu.is_open \
			and main_game.pause_menu.visible \
			and air_controls.visible and ground_controls.visible
	## Divergence guard: each line must carry exactly the key families its
	## constant teaches — a family in one and not the other fails either way.
	var families: Array[String] = ["W/S", "A/D", "Space", "F"]
	var air_families_ok := true
	var ground_families_ok := true
	for family: String in families:
		air_families_ok = air_families_ok \
				and MainGame.HINT_AIR.contains(family) == air_controls.text.contains(family)
		ground_families_ok = ground_families_ok \
				and MainGame.HINT_GROUND.contains(family) == ground_controls.text.contains(family)
	## T-019 treatment on both lines: 14 px, outline 4, black-0.85 outline,
	## white-0.75 fill — resolved through the theme stack like the other HUD
	## scenarios (equality against the tuned values is the reliable read).
	var recap_style_ok := true
	for recap: Label in [air_controls, ground_controls]:
		recap_style_ok = recap_style_ok \
				and recap.get_theme_color("font_outline_color").is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
				and recap.get_theme_constant("outline_size") == 4 \
				and recap.get_theme_font_size("font_size") == 14 \
				and recap.get_theme_color("font_color").is_equal_approx(Color(1.0, 1.0, 1.0, 0.75))
	var air_text: String = air_controls.text
	var ground_text: String = ground_controls.text
	main_game.pause_menu.toggle()
	var resumed_ok: bool = not get_tree().paused and not main_game.pause_menu.is_open \
			and not main_game.pause_menu.visible ## Hidden with the panel again.
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	get_tree().paused = false ## Never leak a pause into later scenarios.
	_check("pause_menu_shows_controls",
			placed_ok and hidden_at_rest and shown_ok and air_families_ok
					and ground_families_ok and recap_style_ok and resumed_ok,
			"placed=%s hidden_at_rest=%s shown=%s air_families=%s ground_families=%s style=%s resumed=%s (air '%s' / ground '%s')" % [
					placed_ok, hidden_at_rest, shown_ok, air_families_ok,
					ground_families_ok, recap_style_ok, resumed_ok, air_text, ground_text])


## --- scenarios (T-119 touch controls) ----------------------------------------
##
## The touch layer is driven the way a finger drives it: synthetic
## InputEventScreenTouch / InputEventScreenDrag through the REAL input
## pipeline (`Input.parse_input_event` + `Input.flush_buffered_events`), never
## by poking the widget's methods. Two probed headless facts shape this block
## (probes recorded in the ticket):
##  1. The stub display server's window is 64×64, and the GUI drops every
##     contact whose position falls outside it — so the touch block sizes the
##     window to the desktop default 1280×720 first (restored after; the other
##     scenarios keep today's exact conditions).
##  2. On that sized headless window the pipeline delivers GUI touches and
##     TouchScreenButton actions, but a synthetic screen touch does NOT
##     emulate mouse — so the ordinary Pause button is driven with the
##     synthetic mouse click a tap produces on-device through the default
##     touch→mouse emulation (`emulate_mouse_from_touch` is true in
##     project.godot and on iOS Safari).
## Also probed: `Input.action_press(a, s)` strength bypasses the InputMap
## deadzone (0.2 reads 0.2, 1.0 reads 1.0) — what the stick feeds IS what the
## player polls, and a release reads exactly 0.0.


## Sizes the (stub) window to the desktop default for one touch scenario and
## returns the previous size for the restore. GUI contact routing needs a
## window big enough to contain the widgets — see the block comment.
func _size_window_for_touch() -> Vector2i:
	var window := get_tree().root
	var previous := window.size
	window.size = Vector2i(1280, 720)
	return previous


func _restore_window_size(previous: Vector2i) -> void:
	get_tree().root.size = previous


## One finger-down contact, through the real pipeline (flushed synchronously
## so the following reads are deterministic — no frame-timing wait).
func _touch_press(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## One finger-move contact for the stick's held finger.
func _touch_drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## One finger-up contact.
func _touch_release(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## A left-click press+release pair — the event a tap on an ordinary Button
## produces on-device through touch→mouse emulation.
func _mouse_click(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


## The T-119 rest contract as one read: all four steering actions at exactly
## 0.0 — strengths AND both axis compositions — the shape the T-082 trim arm
## (`absf(pitch_input) < 0.01`) keys on.
func _steering_axes_all_zero() -> bool:
	for action: String in ["turn_left", "turn_right", "pitch_up", "pitch_down"]:
		if Input.get_action_strength(action) != 0.0:
			return false
	return Input.get_axis("turn_right", "turn_left") == 0.0 \
			and Input.get_axis("pitch_down", "pitch_up") == 0.0


## (T-119) The desktop path stays byte-identical: with no touchscreen the
## layer is HIDDEN and inert (a contact at the stick spot moves nothing), the
## safe-area layout is a no-op (zero offsets on the touch SafeArea, zero
## offset on the HUD layer, the T-087 return fade un-expanded, the StatsLabel
## still at its scene spot), and the InputMap's non-builtin action set is
## EXACTLY the shipped eleven — zero new actions, read live so a smuggled-in
## action fails here.
func _scenario_touch_layer_desktop_inert() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(4500.0, 0.0, 4500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var touch: TouchControls = main_game.get_node("TouchControls") as TouchControls
	var hud_layer: CanvasLayer = main_game.get_node("HUD") as CanvasLayer
	var hidden_ok: bool = not touch.visible
	var prev_size := _size_window_for_touch()
	var base: Control = touch.get_node("SafeArea/StickBase") as Control
	var stick_center := base.get_global_rect().get_center()
	_touch_press(0, stick_center)
	_touch_drag(0, stick_center + Vector2(-60.0, 0.0))
	await _wait_frames(2)
	var inert_ok: bool = Input.get_axis("turn_right", "turn_left") == 0.0 \
			and Input.get_axis("pitch_down", "pitch_up") == 0.0
	_touch_release(0, stick_center)
	var safe_area: Control = touch.get_node("SafeArea") as Control
	var safe_zero: bool = safe_area.offset_left == 0.0 and safe_area.offset_top == 0.0 \
			and safe_area.offset_right == 0.0 and safe_area.offset_bottom == 0.0 \
			and hud_layer.offset == Vector2.ZERO
	var fade: ColorRect = main_game.get_node("%ReturnFade") as ColorRect
	var fade_unexpanded: bool = fade.offset_left == 0.0 and fade.offset_top == 0.0 \
			and fade.offset_right == 0.0 and fade.offset_bottom == 0.0
	var stats: Label = main_game.stats_label
	var hud_intact: bool = stats.position == Vector2(16.0, 12.0) \
			and stats.get_theme_font_size("font_size") == 22 \
			and main_game.hunger_bar.position == Vector2(16.0, 48.0)
	var seen: Dictionary = {}
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			seen[String(action)] = true
	var actions_ok := seen.size() == GAME_ACTIONS.size()
	for action: String in GAME_ACTIONS:
		actions_ok = actions_ok and seen.has(action)
	_restore_window_size(prev_size)
	await _wait_frames(1)
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("touch_layer_desktop_inert",
			hidden_ok and inert_ok and safe_zero and fade_unexpanded and hud_intact
					and actions_ok,
			"hidden=%s inert=%s safe_zero=%s fade_unexpanded=%s hud_intact=%s actions_ok=%s (seen %d, want %d)" % [
					hidden_ok, inert_ok, safe_zero, fade_unexpanded, hud_intact,
					actions_ok, seen.size(), GAME_ACTIONS.size()])


## (T-119) The stick steers through the SAME action axes the player polls: a
## synthetic screen-drag on the joystick drives the four existing steering
## actions with analog strength — a gentle deflection reads clearly non-zero
## (the deadzone trap: it must not read zero), strictly weaker than full, with
## the other axis pair exactly at rest — and the PIGEON ITSELF yaws and banks
## on a held full-left drag and pitches up on a held full-up drag.
func _scenario_touch_stick_drives_action_axes() -> void:
	var prev_size := _size_window_for_touch()
	var touch: TouchControls = TOUCH_SCENE.instantiate() as TouchControls
	touch.force_show = true ## The sim runs where no touchscreen exists — force the layer live.
	add_child(touch)
	await _wait_frames(2)
	var base: Control = touch.get_node("SafeArea/StickBase") as Control
	var center := base.get_global_rect().get_center()
	## Gentle (40 % radius) deflection: non-zero turn, other axis at rest.
	_touch_press(0, center)
	_touch_drag(0, center + Vector2(-touch.stick_radius * 0.4, 0.0))
	var gentle_turn := Input.get_axis("turn_right", "turn_left")
	var gentle_pitch := Input.get_axis("pitch_down", "pitch_up")
	_touch_release(0, center + Vector2(-touch.stick_radius * 0.4, 0.0))
	## Full deflection: full strength, same cleanliness.
	_touch_press(0, center)
	_touch_drag(0, center + Vector2(-touch.stick_radius, 0.0))
	var full_turn := Input.get_axis("turn_right", "turn_left")
	var full_turn_pitch := Input.get_axis("pitch_down", "pitch_up")
	var analog_ok := gentle_turn > 0.05 and gentle_turn < full_turn \
			and gentle_pitch == 0.0 and full_turn > 0.9 and full_turn_pitch == 0.0
	## The pigeon flies the held drag: banks left and yaws like the keyboard hold.
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(17.0, 0.0, 0.0))
	var yaw0 := _flat_yaw()
	for _i in 60:
		await get_tree().physics_frame
	var banked_left := _player.transform.basis.x.y
	var yaw_delta := absf(wrapf(_flat_yaw() - yaw0, -PI, PI))
	_touch_release(0, center + Vector2(-touch.stick_radius, 0.0))
	await _wait_frames(2)
	var released_zero := _steering_axes_all_zero()
	## Full-up stick: the nose rises through the polled pitch axis.
	_touch_press(0, center)
	_touch_drag(0, center + Vector2(0.0, -touch.stick_radius))
	var full_pitch := Input.get_axis("pitch_down", "pitch_up")
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(0.0, 0.0, -17.0))
	var nose0 := (-_player.transform.basis.z).y
	for _i in 40:
		await get_tree().physics_frame
	var nose1 := (-_player.transform.basis.z).y
	_touch_release(0, center + Vector2(0.0, -touch.stick_radius))
	await _wait_frames(2)
	var rest_after := _steering_axes_all_zero()
	_restore_window_size(prev_size)
	await _wait_frames(1)
	touch.free()
	_check("touch_stick_drives_action_axes",
			analog_ok and full_pitch > 0.9 and banked_left > 0.2 and yaw_delta > 0.3
					and released_zero and nose1 - nose0 > 0.15 and rest_after,
			"analog=%s full_pitch=%.2f bank=%.2f yaw=%.2f rad released_zero=%s nose rise %.2f rest=%s" % [
					analog_ok, full_pitch, banked_left, yaw_delta, released_zero,
					nose1 - nose0, rest_after])


## (T-119) The stick at rest reads EXACTLY zero — the T-082 hands-off trim
## arm (`absf(pitch_input) < 0.01`) survives the touch path: never-touched
## reads zero; a held full-up drag then finger-up returns every steering
## action to exactly 0.0; and the end-to-end proof — a settled cruise given an
## 8-frame stick pitch-up and released by lifting the finger — shows the nose
## easing back toward the flow over 90 hands-off frames at the same bar the
## keyboard scenario (`hands_off_glide_trims`) pins.
func _scenario_touch_stick_rest_reads_exactly_zero() -> void:
	var prev_size := _size_window_for_touch()
	var touch: TouchControls = TOUCH_SCENE.instantiate() as TouchControls
	touch.force_show = true
	add_child(touch)
	await _wait_frames(2)
	var base: Control = touch.get_node("SafeArea/StickBase") as Control
	var center := base.get_global_rect().get_center()
	var idle_zero := _steering_axes_all_zero()
	_touch_press(0, center)
	_touch_drag(0, center + Vector2(0.0, -touch.stick_radius))
	await _wait_frames(2)
	var held_pitch := Input.get_axis("pitch_down", "pitch_up")
	_touch_release(0, center + Vector2(0.0, -touch.stick_radius))
	await _wait_frames(1)
	var rest_zero := _steering_axes_all_zero()
	## The trim arm, end to end through the touch layer (the keyboard recipe).
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -17.0))
	await _wait_frames(30) ## Settle into the trim glide.
	_touch_press(0, center)
	_touch_drag(0, center + Vector2(0.0, -touch.stick_radius))
	await _wait_frames(8) ## The same entry hold hands_off_glide_trims uses.
	_touch_release(0, center + Vector2(0.0, -touch.stick_radius))
	var released_to_zero := _steering_axes_all_zero()
	var nose0_deg := rad_to_deg(asin(clampf((-_player.transform.basis.z).y, -1.0, 1.0)))
	await _wait_frames(90) ## Hands off: every input released.
	var nose1_deg := rad_to_deg(asin(clampf((-_player.transform.basis.z).y, -1.0, 1.0)))
	var travel_deg := nose0_deg - nose1_deg ## Positive = the nose dropped toward the flow.
	var finite := _player.velocity.is_finite()
	_restore_window_size(prev_size)
	await _wait_frames(1)
	touch.free()
	_check("touch_stick_rest_reads_exactly_zero",
			idle_zero and held_pitch > 0.9 and rest_zero and released_to_zero
					and travel_deg >= HSO_NOSE_TRAVEL_BAR and finite,
			"idle_zero=%s held_pitch=%.2f rest_zero=%s released_to_zero=%s nose travel %.2f deg (bar >= %.1f) finite=%s" % [
					idle_zero, held_pitch, rest_zero, released_to_zero,
					travel_deg, HSO_NOSE_TRAVEL_BAR, finite])


## (T-119) The Flap and Poop buttons fire the REAL actions: a synthetic screen
## touch on the Flap TouchScreenButton produces a flapped impulse through the
## player's own polled `_flap`, and one on Poop drops a real falling Poop
## through the polled `_try_poop` (relayed by the harness's `pooped` listener
## into `_dropped`). No new input path — the buttons are the actions.
func _scenario_touch_buttons_fire_real_actions() -> void:
	var prev_size := _size_window_for_touch()
	var touch: TouchControls = TOUCH_SCENE.instantiate() as TouchControls
	touch.force_show = true
	add_child(touch)
	await _wait_frames(2)
	var flap_center: Vector2 = (touch.get_node("SafeArea/FlapButton") as Node2D).global_position
	var poop_center: Vector2 = (touch.get_node("SafeArea/PoopButton") as Node2D).global_position
	_touch_flap_events = 0
	var flap_cb := func() -> void: _touch_flap_events += 1
	_player.flapped.connect(flap_cb)
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(0.0, 0.0, -17.0))
	_touch_press(0, flap_center)
	await _wait_frames(2)
	_touch_release(0, flap_center)
	await _wait_frames(2)
	var flap_ok := _touch_flap_events == 1
	var drops_before := _dropped.size()
	_touch_press(1, poop_center)
	await _wait_frames(2)
	_touch_release(1, poop_center)
	await _wait_frames(2)
	var dropped := _dropped.size() - drops_before
	var drop: Poop = _dropped[_dropped.size() - 1] if dropped > 0 else null
	var poop_ok := dropped == 1 and drop != null and is_instance_valid(drop) \
			and drop.linear_velocity.is_finite()
	_player.flapped.disconnect(flap_cb)
	_restore_window_size(prev_size)
	await _wait_frames(1)
	touch.free()
	_check("touch_buttons_fire_real_actions", flap_ok and poop_ok,
			"flap=%s (events %d), poop=%s (drops %d, finite velocity=%s)" % [
					flap_ok, _touch_flap_events, poop_ok, dropped,
					drop != null and drop.linear_velocity.is_finite()])


## (T-119) The Pause button pauses through the REAL PauseMenu: a tap on the
## ordinary Button of an instanced main scene's touch layer opens the real
## pause overlay (tree frozen, `is_open`), and a tap on the panel's own Resume
## button unpauses — the full touch pause loop, no keyboard involved. Driven
## with the synthetic mouse click a tap emulates (probed: synthetic screen
## touches do not emulate mouse headless — see the block comment).
func _scenario_touch_pause_button_toggles_real_pause() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var prev_size := _size_window_for_touch()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-4500.0, 0.0, -4500.0) ## Own space, clear of every other instanced Main.
	var touch: TouchControls = main_game.get_node("TouchControls") as TouchControls
	touch.force_show = true ## Before add_child: the layer's _ready visibility read sees it.
	add_child(main_game)
	await _wait_frames(4)
	var pause_button: Button = touch.get_node("SafeArea/PauseButton") as Button
	_mouse_click(pause_button.get_global_rect().get_center())
	await _wait_frames(2)
	var paused_ok: bool = get_tree().paused and main_game.pause_menu.is_open
	var resume: Button = main_game.get_node("%ResumeButton") as Button
	_mouse_click(resume.get_global_rect().get_center())
	await _wait_frames(2)
	var resumed_ok: bool = not get_tree().paused and not main_game.pause_menu.is_open
	_restore_window_size(prev_size)
	await _wait_frames(1)
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	get_tree().paused = false ## Never leak a pause into later scenarios.
	_check("touch_pause_button_toggles_real_pause", paused_ok and resumed_ok,
			"paused=%s resumed=%s (the tap's emulated click drives the real toggle)" % [
					paused_ok, resumed_ok])


## (T-119) Overlapping contacts steer AND flap at once: finger 0 holds a
## full-left stick drag while finger 1 lands on Flap — the turn axis stays
## live THROUGH the second contact, a real flap impulse fires in the same
## window, the pigeon actually yaws under both, and lifting both fingers
## returns the axes to exactly zero.
func _scenario_touch_multitouch_steer_and_flap() -> void:
	var prev_size := _size_window_for_touch()
	var touch: TouchControls = TOUCH_SCENE.instantiate() as TouchControls
	touch.force_show = true
	add_child(touch)
	await _wait_frames(2)
	var base: Control = touch.get_node("SafeArea/StickBase") as Control
	var stick_center := base.get_global_rect().get_center()
	var flap_center: Vector2 = (touch.get_node("SafeArea/FlapButton") as Node2D).global_position
	_touch_flap_events = 0
	var flap_cb := func() -> void: _touch_flap_events += 1
	_player.flapped.connect(flap_cb)
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(17.0, 0.0, 0.0))
	var yaw0 := _flat_yaw()
	_touch_press(0, stick_center)
	_touch_drag(0, stick_center + Vector2(-touch.stick_radius, 0.0))
	_touch_press(1, flap_center) ## Overlapping contact: the stick stays held.
	await _wait_frames(2)
	_touch_release(1, flap_center)
	var steering_live := Input.get_axis("turn_right", "turn_left")
	for _i in 40:
		await get_tree().physics_frame
	var yaw_delta := absf(wrapf(_flat_yaw() - yaw0, -PI, PI))
	_touch_release(0, stick_center + Vector2(-touch.stick_radius, 0.0))
	await _wait_frames(1)
	var rest_after := _steering_axes_all_zero()
	_restore_window_size(prev_size)
	await _wait_frames(1)
	touch.free()
	_player.flapped.disconnect(flap_cb)
	_check("touch_multitouch_steer_and_flap",
			steering_live > 0.9 and _touch_flap_events >= 1 and yaw_delta > 0.3
					and rest_after,
			"steering_live=%.2f flaps=%d yaw=%.2f rad rest=%s" % [
					steering_live, _touch_flap_events, yaw_delta, rest_after])


## --- scenario (T-039 title-screen controls line) -----------------------------


## The title screen teaches the controls (T-039): the REAL menu scene carries a
## ControlsLabel under the Footer whose text names every action family a first
## run needs (pitch / turn / flap / poop / pause with their printed keycaps),
## and every keycap it teaches resolves to a real InputMap action — the seven
## `flap`/`poop`/`pitch_up`/`pitch_down`/`turn_left`/`turn_right`/`pause` — the
## divergence guard for the by-design duplicated copy (scene files cannot
## reference main.gd's HINT_AIR constant). The line carries its own treatment:
## 15 px, white @ 0.7, NO outline (the T-019 finding — the flat dark-navy title
## background needs none), which is asserted as the absence of a local override
## plus a zero effective outline. The same run reads the game-over Hint through
## a REAL main scene: reworded to player language with no dev jargon ("seed" /
## "regenerate" must both be gone). Registered in the T-019 window: unpaused
## tree, no live Main; the menu instance touches no Main state and frees
## itself, the Main instance gets the T-099 cleanup tail.
func _scenario_title_screen_teaches_controls() -> void:
	var menu: Control = MENU_SCENE.instantiate()
	add_child(menu)
	await _wait_frames(2)
	var controls: Label = menu.get_node("%ControlsLabel") as Label
	var footer: Label = menu.get_node("Footer") as Label
	var placed_ok: bool = controls != null and footer != null \
			and controls.get_parent() == menu and footer.get_parent() == menu \
			and controls.offset_top >= footer.offset_bottom ## Under the footer line.
	var visible_ok: bool = controls != null and controls.visible \
			and controls.is_visible_in_tree()
	## The copy must name every family AND print its keycap — a reword that
	## drops either half of a pair fails the gate.
	var text_ok := controls != null
	if text_ok:
		for taught: String in ["pitch", "turn", "flap", "poop", "pause"]:
			text_ok = text_ok and controls.text.contains(taught)
		for keycap: String in ["W/S", "A/D", "Space", "F", "Esc"]:
			text_ok = text_ok and controls.text.contains(keycap)
	var actions_ok := true
	for action: String in ["flap", "poop", "pitch_up", "pitch_down", "turn_left", "turn_right", "pause"]:
		actions_ok = actions_ok and InputMap.has_action(action)
	## (T-116) The footer is the game's rules line — the win rule must be on it
	## beside the survival and splat-value clauses: "favor" and "town" both named.
	var win_rule_ok: bool = footer != null \
			and footer.text.contains("favor") and footer.text.contains("town")
	## 15 px white @ 0.7, no outline — resolved through the theme stack like the
	## T-099 recap assert; "no outline" is the absence of a local override AND a
	## zero effective size.
	var style_ok := controls != null \
			and controls.get_theme_font_size("font_size") == 15 \
			and controls.get_theme_color("font_color").is_equal_approx(Color(1.0, 1.0, 1.0, 0.7)) \
			and not controls.has_theme_constant_override("outline_size") \
			and controls.get_theme_constant("outline_size") == 0
	var menu_text: String = controls.text if controls != null else "-"
	menu.free()
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-2500.0, 0.0, 2500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var hint: Label = main_game.get_node("GameOverScreen/Center/ScorePanel/Box/Hint") as Label
	var hint_text: String = hint.text if hint != null else "-"
	var hint_ok: bool = hint != null \
			and hint.text == "same city every run — race your best" \
			and not hint.text.contains("seed") \
			and not hint.text.contains("regenerate")
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("title_screen_teaches_controls",
			placed_ok and visible_ok and text_ok and actions_ok and style_ok and hint_ok
					and win_rule_ok,
			"placed=%s visible=%s text=%s actions=%s style=%s hint=%s win_rule=%s (controls '%s' / hint '%s')" % [
					placed_ok, visible_ok, text_ok, actions_ok, style_ok, hint_ok,
					win_rule_ok, menu_text, hint_text])


## --- scenario (T-040 HUD combo strip & hit marker) ---------------------------


## Finds a live hit_marker.tscn burst parented to `body` via the shared
## `juice_effects` group — the same group scan _count_effects uses, plus the
## parenting half of the assert.
func _find_hit_marker_on(body: Node) -> OneShotBurst:
	for node in get_tree().get_nodes_in_group("juice_effects"):
		if node is OneShotBurst and node.scene_file_path.ends_with("hit_marker.tscn") \
				and node.get_parent() == body:
			return node
	return null


## T-040: the HUD combo strip and the hit-marker burst through the REAL main
## scene. Registered in the T-019 window — immediately after
## _scenario_hud_hunger_tiers, which frees its instance: unpaused tree, no live
## Main — with the same cleanup tail (free() → Game.hunger.player = null →
## Game.reset_run()). The splat relays are EMITTED, not simulated: real
## tourists/cars picked off the spawners, tourist_splatted / car_splatted
## emitted straight, so the full handler → Game → hit_scored chain runs with no
## physics. Assertions: the strip sits under the pointer block with the T-019
## outline treatment and starts empty; a tourist splat reads "Tourist +100",
## the chained second one "Tourist +200 ×2", and a car splat after a landing
## replaces it with "Car +30"; every hit spawns a hit_marker.tscn burst ON the
## hit body (parent + position asserted, found via the group like
## juice_splat_burst_fires) that cleans itself up; the strip clears itself
## after combo_strip_seconds of game time and stays cleared; one more hit then
## restart_run() proves the restart clear mid-display (_scenario_restart_resets
## itself stays untouched).
func _scenario_combo_strip_reports_last_hit() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-3500.0, 0.0, 3500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var strip: Label = main_game.combo_strip
	## Park the pigeon high so its spawn drop (and the combo-ending landing it
	## fires) cannot land inside the chain legs below — every combo state here
	## is set explicitly, never by the pigeon's own touchdown.
	main_game.player.reset_flight(main_game.city.to_local(
			main_game.city.spawn_point) + Vector3(0.0, 40.0, 0.0))
	## Under the pointer block, the T-019 outline treatment, empty at rest.
	var style_ok: bool = \
			strip.get_theme_color("font_outline_color").is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and strip.get_theme_constant("outline_size") == 4 \
			and strip.get_theme_font_size("font_size") == 14 \
			and strip.get_theme_color("font_color").is_equal_approx(Color(1.0, 1.0, 1.0, 0.75))
	var placed_ok: bool = strip.offset_top >= main_game.bread_pointer.offset_bottom
	var empty_at_rest: bool = strip.text == ""
	var tourists: Array[Tourist] = main_game.tourist_spawner.living_tourists()
	var cars: Array[Car] = main_game.car_spawner.living_cars()
	var spread_ok: bool = tourists.size() >= 2 and not cars.is_empty()
	var before := _count_effects("hit_marker.tscn")
	## Leg 1 — first tourist hit: kind + points, no multiplier yet, marker on
	## the hit body at the hit point.
	main_game.tourist_spawner.tourist_splatted.emit(tourists[0])
	var text_a := strip.text
	var marker_a: OneShotBurst = _find_hit_marker_on(tourists[0])
	var at_hit: bool = marker_a != null and marker_a.global_position \
			.distance_to(tourists[0].global_position) < 0.1
	## Leg 2 — the chained second tourist: the ×N suffix replaces the line.
	main_game.tourist_spawner.tourist_splatted.emit(tourists[1])
	var text_b := strip.text
	## Leg 3 — a landing ends the chain; the car hit replaces the line at ×1.
	Game.on_grounding_changed(true)
	main_game.car_spawner.car_splatted.emit(cars[0])
	var text_c := strip.text
	var marker_c: OneShotBurst = _find_hit_marker_on(cars[0])
	var texts_ok: bool = text_a == "Tourist +100" and text_b == "Tourist +200 ×2" \
			and text_c == "Car +30"
	var markers_ok: bool = marker_a != null and marker_c != null and at_hit \
			and _count_effects("hit_marker.tscn") == before + 3
	## Game-time expiry: ~3.1 s at the fixed 60 Hz pace clears the strip and it
	## stays cleared; the bursts have burnt out by then too (0.35 s + margin).
	await _wait_frames(187)
	var expired: bool = strip.text == ""
	await _wait_frames(30)
	var stays_cleared: bool = strip.text == ""
	var cleaned: bool = _count_effects("hit_marker.tscn") == before
	## One more hit (chain ended first, so plain ×1 again), then the restart
	## clear mid-display.
	Game.on_grounding_changed(true)
	main_game.car_spawner.car_splatted.emit(cars[0])
	var refilled := strip.text == "Car +30"
	main_game.restart_run()
	var restart_cleared := strip.text == ""
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("combo_strip_reports_last_hit",
			spread_ok and style_ok and placed_ok and empty_at_rest and texts_ok
					and markers_ok and expired and stays_cleared and cleaned
					and refilled and restart_cleared,
			"spread=%s style=%s placed=%s empty=%s texts=%s ('%s' → '%s' → '%s') markers=%s at_hit=%s expired=%s stays=%s cleaned=%s refilled=%s restart=%s" % [
					spread_ok, style_ok, placed_ok, empty_at_rest, texts_ok,
					text_a, text_b, text_c, markers_ok, at_hit, expired,
					stays_cleared, cleaned, refilled, restart_cleared])


## --- scenario (T-079 combo landing note) -------------------------------------


## The landing-cost note (T-079), through the REAL main scene: a landing while
## a ×2+ combo is live shows "landing ended the ×2 combo" for 2.5 s of game
## time, then clears itself; a landing with no live combo shows nothing;
## restart_run() mid-display clears it. Own-space Main, same T-019 window as
## _scenario_hud_hunger_tiers, with the same cleanup tail (free() →
## Game.hunger.player = null → Game.reset_run()). THE LOAD-BEARING PART: the
## landing is the REAL `grounding_changed` signal — `emit(true)`, never a
## direct `_on_grounding_changed` call — so both _ready connects fire in
## connect order and Main's handler provably reads the PRE-reset streak before
## Game._end_combo zeroes it; a future connect reorder fails the `shown` leg.
## The streak is built with synthetic add_tourist_hit calls (the
## scoring_values pattern) — the note itself is presentation-only, so no
## physics is needed anywhere.
func _scenario_combo_note_on_landing() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(-7500.0, 0.0, 7500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var note: Label = main_game.combo_note
	## Park the pigeon high so its spawn drop (and the real combo-ending landing
	## it eventually fires) cannot land inside the streak-live legs below — the
	## streak state here is set explicitly, never by the pigeon's own touchdown.
	main_game.player.reset_flight(main_game.city.to_local(
			main_game.city.spawn_point) + Vector3(0.0, 40.0, 0.0))
	## Under the strip row, the T-019 outline treatment, empty and hidden at rest.
	var style_ok: bool = \
			note.get_theme_color("font_outline_color").is_equal_approx(Color(0.0, 0.0, 0.0, 0.85)) \
			and note.get_theme_constant("outline_size") == 4 \
			and note.get_theme_font_size("font_size") == 14 \
			and note.get_theme_color("font_color").is_equal_approx(Color(1.0, 1.0, 1.0, 0.75))
	var placed_ok: bool = note.offset_top >= main_game.combo_strip.offset_bottom
	var empty_at_rest: bool = note.text == "" and not note.visible
	## Leg 1 — synthetic streak → 2, then the REAL landing signal: the note
	## names the pre-reset multiplier exactly.
	Game.add_tourist_hit(Vector3(-7500.0, 0.5, 7500.0))
	Game.add_tourist_hit(Vector3(-7500.0, 0.5, 7501.0))
	main_game.player.grounding_changed.emit(true)
	var shown: bool = note.text == "landing ended the ×2 combo" and note.visible
	## 2.5 s of game time at the fixed 60 Hz is 150 frames — 190 crosses it.
	await _wait_frames(190)
	var expired: bool = note.text == "" and not note.visible
	## Leg 2 — a landing with no live combo shows nothing.
	main_game.player.grounding_changed.emit(true)
	var stays_empty: bool = note.text == "" and not note.visible
	## Leg 3 — rebuild the streak, land again, and the restart clear mid-display.
	Game.add_tourist_hit(Vector3(-7500.0, 0.5, 7500.0))
	Game.add_tourist_hit(Vector3(-7500.0, 0.5, 7501.0))
	main_game.player.grounding_changed.emit(true)
	var reshot: bool = note.text == "landing ended the ×2 combo" and note.visible
	main_game.restart_run()
	var restart_cleared: bool = note.text == "" and not note.visible
	var note_after_restart: String = note.text ## Read before the free below.
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("combo_note_on_landing",
			style_ok and placed_ok and empty_at_rest and shown and expired
					and stays_empty and reshot and restart_cleared,
			"style=%s placed=%s empty=%s shown=%s expired=%s stays_empty=%s reshot=%s restart=%s ('%s')" % [
					style_ok, placed_ok, empty_at_rest, shown, expired,
					stays_empty, reshot, restart_cleared, note_after_restart])


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
## waddle pose while walking, back to stand when the waddle stops. Since
## T-048 the fold also thins the wing chord (the pivots' eased Z scale): the
## grounded legs assert it settled ≤ 0.5 (default 0.35), a fresh airborne
## set-up eases it back to ≥ 0.95, and reset_pose() returns it to exactly
## 1.0 — wing pivots included, which the root-only `scale = Vector3.ONE`
## never reached — so no restart can leave a folded chord in the air.
func _scenario_pigeon_ground_poses() -> void:
	var bird: PigeonVisual = _player.pigeon
	await _set_up(true, Vector3(0.0, 3.0, 0.0), Vector3.ZERO)
	await _await_grounded(120)
	await _wait_frames(45) ## Let the touchdown slide bleed and the wings fold.
	var stand_pose: PigeonVisual.Pose = bird.pose
	var stand_sweep: float = bird.wing_sweep
	var stand_lift: float = bird.wing_lift
	var stand_chord: float = bird.wing_chord
	var standing := stand_pose == PigeonVisual.Pose.STAND \
			and stand_sweep > 0.7 and stand_lift < 0.0 and stand_chord <= 0.5
	await _hold("pitch_up", 30) ## Half a second of waddling.
	var waddle_pose: PigeonVisual.Pose = bird.pose
	var waddle_chord: float = bird.wing_chord
	var waddling := waddle_pose == PigeonVisual.Pose.WADDLE and waddle_chord <= 0.5
	await _wait_frames(50) ## Past the walk_decel stop.
	var rest_pose: PigeonVisual.Pose = bird.pose
	var rest_chord: float = bird.wing_chord
	var rested := rest_pose == PigeonVisual.Pose.STAND and rest_chord <= 0.5
	## The airborne leg: a fresh airborne set-up, joints eased ~45 frames.
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	await _wait_frames(45) ## The wing joints ease to the glide targets.
	var air_pose: PigeonVisual.Pose = bird.pose
	var air_chord: float = bird.wing_chord
	var reopened := air_pose == PigeonVisual.Pose.GLIDE and air_chord >= 0.95
	## The restart path: reset_pose() must land the chord on exactly 1.0 —
	## and on the pivots themselves, the root-only-reset gap this closes.
	bird.reset_pose()
	var wing_l: Node3D = bird.get_node("WingL")
	var wing_r: Node3D = bird.get_node("WingR")
	var reset_ok := bird.wing_chord == 1.0 \
			and wing_l.scale.z == 1.0 and wing_r.scale.z == 1.0
	_check("pigeon_ground_poses_track_waddle",
			standing and waddling and rested and reopened and reset_ok,
			"stand=%s (pose %d sweep %.2f lift %.2f chord %.2f) waddle=%s (pose %d chord %.2f) rested=%s (pose %d chord %.2f) reopened=%s (pose %d chord %.3f) reset=%s (chord %.2f pivots %.2f/%.2f)" % [
					standing, stand_pose, stand_sweep, stand_lift, stand_chord,
					waddling, waddle_pose, waddle_chord, rested, rest_pose,
					rest_chord, reopened, air_pose, air_chord, reset_ok,
					bird.wing_chord, wing_l.scale.z, wing_r.scale.z])


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


## The presentation (T-109) is the rigged realistic Blender pigeon: one skinned
## textured mesh instanced from assets/models/pigeon_realistic/pigeon_realistic.glb
## under the unchanged PigeonVisual drive() contract, carrying the six pose
## clips the state machine mirrors (glide/dive/stand/waddle holds, flap/peck
## one-shots). This replaces the T-108 static-mesh check — palette contrast
## for the sculpt is a Gate 3 read now (VERIFICATION.md, T-108/T-109). The
## T-026 ground-pair floors and the T-045/T-085 dark-anchor analysis were
## properties of the old primitive palette; bring them back as a render-based
## scenario if a future sculpt needs automated contrast.
func _scenario_pigeon_realistic_visual() -> void:
	var bird: PigeonVisual = load("res://scenes/pigeon_visual.tscn").instantiate() as PigeonVisual
	add_child(bird)
	var model_source := ""
	for child in bird.get_children():
		if child.scene_file_path.contains("pigeon_realistic"):
			model_source = child.scene_file_path
	var mesh_count := 0
	for mesh in bird.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
	## The rig ships the six clips the presentation drives (T-109).
	var anim: AnimationPlayer = bird.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips := 0
	if anim != null:
		for clip_name: String in ["pigeon_glide", "pigeon_dive", "pigeon_flap",
				"pigeon_peck", "pigeon_stand", "pigeon_waddle"]:
			if anim.has_animation(clip_name):
				clips += 1
	## The drive() contract still tracks flight poses on the retained pivots.
	for _i in 45:
		bird.drive(false, false, false, 1.0 / 60.0) ## Airborne: glide targets.
	var glide_sweep: float = bird.wing_sweep
	for _i in 45:
		bird.drive(true, false, false, 1.0 / 60.0) ## Grounded: fold targets.
	var fold_sweep: float = bird.wing_sweep
	bird.free()
	_check("pigeon_realistic_visual",
			model_source != "" and mesh_count > 0 and clips == 6
					and glide_sweep < 0.3 and fold_sweep > 0.7,
			"source=%s meshes=%d clips=%d/6 glide_sweep=%.2f (< 0.3) fold_sweep=%.2f (> 0.7)" % [
					model_source, mesh_count, clips, glide_sweep, fold_sweep])


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
	## (T-081) Pin the ×2 window AFTER the scene pigeon's opening drop lands:
	## it spawns ~0.6 m up and its grounding — which fires the chain reset
	## through the real Main wiring — used to graze in just after the read on
	## the hover tree and lands at the read frame itself on the fall tree
	## (measured: grounded f11 of a hit1 f5 / hit2 f8 / read f11 window —
	## pulsed=true, combo_shown=false). Waiting out the grounded state (the
	## `_await_grounded` pattern, on the scene's own Player) detaches the
	## escalation from the flight model; the explicit reset below stays as the
	## idempotent insurance the T-038 leg uses too.
	for _i in 90:
		await get_tree().physics_frame
		if pigeon.is_grounded:
			break
	Game.on_grounding_changed(true)
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
	## (T-038) The STYLE tag, through the REAL Main signal path — the two hits
	## above never recorded a poop release, so `_release_age` sits at its stale
	## 999 and the style gate could never fire on its own. Stage the chain state
	## explicitly instead of trusting the landing's frame: the Player's opening
	## drop is pinned grounded before the ×2 leg (the T-081 wait above), so the
	## chain is already dead — `on_grounding_changed(true)` is the idempotent
	## insurance reset the scoring scenario uses. Then a fresh fast AND low
	## release makes
	## the next hit the chain's first, styled: ×1 pays roundi(100 × 1 × 1.5)
	## = 150 — the Why's bare-150 case, now labelled "+150 STYLE". A slow
	## release before the second hit leaves it ×2 plain: 200 → "+200 ×2".
	Game.on_grounding_changed(true)
	Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -18.0)) ## Fast AND low.
	var styled_points: int = Game.add_tourist_hit(Vector3(3500.0, 0.5, -3502.0))
	Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -5.0)) ## Low but slow.
	var plain_points: int = Game.add_tourist_hit(Vector3(3500.0, 0.5, -3503.0))
	await _wait_frames(2) ## The popups' _ready applies text and tint.
	## Read the popups through the score_popups group BEFORE the scene frees
	## them. The two earlier popups have freed by now (1.2 s lifetime vs ~1.6 s
	## elapsed), so exactly these two are alive: one styled, one plain — and
	## the earlier ×2 popup also read "+200 ×2", hence the exact-count leg.
	var styled_text := ""
	var plain_text := ""
	var styled_gold := false
	var plain_untinted := false
	var group := get_tree().get_nodes_in_group("score_popups")
	for node in group:
		var popup := node as ScorePopup
		if popup.label.text == "+150 STYLE":
			styled_text = popup.label.text
			styled_gold = popup.label.modulate == ScorePopup.STYLE_COLOR
		elif popup.label.text == "+200 ×2":
			plain_text = popup.label.text
			plain_untinted = popup.label.modulate != ScorePopup.STYLE_COLOR
	var style_ok := styled_points == 150 and plain_points == 200 \
			and group.size() == 2 \
			and styled_text == "+150 STYLE" and plain_text == "+200 ×2" \
			and styled_gold and plain_untinted
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("hit_shake_and_score_pulse", pulsed and shook and combo_shown and settled and warm_sun and sun_capped,
			"pulsed=%s shook=%s combo_shown=%s settled=%s (scale %.3f trauma %.3f) warm_sun=%s sun_energy=%.2f" % [
					pulsed, shook, combo_shown, settled, scale_after, trauma_after, warm_sun, sun_energy])
	_check("score_popup_style_tag_live", style_ok,
			"styled_points=%d plain_points=%d popups=%d styled_text='%s' plain_text='%s' styled_gold=%s plain_untinted=%s" % [
					styled_points, plain_points, group.size(), styled_text, plain_text,
					styled_gold, plain_untinted])


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
	## The pigeon grounds on the plaza first (since T-029 at PLAZA_DROP_OFFSET,
	## clear of the landmark plinth), so both spawner anchors stay put.
	await _set_up(true, _city.position + PLAZA_DROP_OFFSET + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)
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
## over the flat test ground itself — mirroring what Main wires in. Since T-095
## the exactly-once claim is double-checked through the guard's new
## `off_world_reset` signal: emissions counted beside the counter, exactly one
## across the whole window.
func _scenario_off_world_fall_returns_home() -> void:
	var hunger := Hunger.new()
	hunger.player = _player
	add_child(hunger)
	_player.respawn_point = Vector3(0.0, 0.4, 0.0) ## The spawn-drop height over the flat test ground.
	## The harness player is shared across scenarios and T-042's
	## `off_world_fall_respawns` (which runs earlier) already fired the guard
	## once — zero the counter so this window asserts its OWN exactly-one fire.
	_player.off_world_resets = 0
	## (T-095) The guard also emits `off_world_reset` now — count the emissions
	## beside the counter. The connect precedes `_set_up` because the guard can
	## already fire inside its 2 settle frames; the lambda lives in a var so the
	## scenario can disconnect it (the harness player is shared across
	## scenarios, like the `hunger.free()` housekeeping below).
	_off_world_signal_fires = 0
	var on_off_world_reset := func(_from: Vector3) -> void: _off_world_signal_fires += 1
	_player.off_world_reset.connect(on_off_world_reset)
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
	var fired_once := _player.off_world_resets == 1 and _off_world_signal_fires == 1
	var landed := _player.is_grounded
	## No oscillation: two more seconds parked home — the counter must not move.
	await _wait_frames(120)
	var stable := fired_once and grounded_home and _player.is_grounded \
			and _player.position.distance_to(home) < 1.0 \
			and _player.off_world_resets == 1 \
			and _off_world_signal_fires == 1
	var hunger_loss: float = hunger0 - hunger.value
	var finite := _player.velocity.is_finite() and _player.position.is_finite()
	var at_rest := _player.velocity.length() < 1.0
	_player.off_world_reset.disconnect(on_off_world_reset) ## Housekeeping: the shared player must not carry this scenario's listener on.
	hunger.free()
	_check("off_world_fall_returns_home",
			fired_once and grounded_home and landed and stable and hunger_loss > 0.2
					and finite and at_rest,
			"counter=%d signal=%d grounded_home=%s stable=%s hunger lost %.2f, rest %.2f m/s at %s (finite=%s)" % [
					_player.off_world_resets, _off_world_signal_fires, grounded_home, stable, hunger_loss,
					_player.velocity.length(), _player.position, finite])


## --- scenario (T-087 off-world return beat) ---------------------------------


## The PRESENTED return through the real main scene (T-087): the guard fires,
## and Main answers with the whole "came home" beat — a feather poof at the
## departure point, a warm HUD fade that is up right after the reset and fully
## gone within ~1 s of game time, the chase camera already home on the first
## frame after the reset (the snap, not a ~755 m lerp), and the "home again"
## note showing its exact text — while the T-042/T-036 machine contract keeps
## holding through the presented return: exactly one guard fire (counter AND
## signal, `from` equal to the void departure position), grounded on the
## respawn corridor within ~2 s, no second fire across a further ~2 s, and
## Game.hunger (attached by Main._ready()) draining > 0.2 across the window.
## The bare-harness sibling above stays untouched: there the signal has zero
## listeners, proving the emit alone is a no-op. A second deliberate fire then
## re-runs the beat and restart_run() mid-note clears it unpaused (the T-100
## fold). Registered after that sibling: it owns one instanced Main in its own
## space and leaves the tree unpaused with no live Main (cleanup tail per the
## poop_ready_indicator precedent).
func _scenario_off_world_return_beat() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(4500.0, 0.0, -4500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var pigeon: Player = main_game.player
	var fade: ColorRect = main_game.return_fade
	var note: Label = main_game.home_note
	## Signal evidence: count the emissions and keep the last `from` — member
	## vars, because locals do not survive inside lambdas. The connect precedes
	## the drive because the guard fires inside the first post-reset frame.
	_return_signal_fires = 0
	var on_return := func(from: Vector3) -> void:
		_return_signal_fires += 1
		_return_signal_from = from
	pigeon.off_world_reset.connect(on_return)
	var rest_ok: bool = not note.visible and fade.color.a <= 0.01
	var hunger0: float = Game.hunger.value
	## Drive the pigeon below the guard line directly (local convention —
	## global y −10 against the −5 line, under the instanced city, no floor):
	## the exact T-042 entry, played through the full game shell this time.
	pigeon.reset_flight(Vector3(0.0, -10.0, 0.0))
	var departure: Vector3 = pigeon.global_position ## The void position the guard will emit — no physics frame has run since the reset.
	await _wait_frames(2) ## The guard fires inside the first of these frames.
	var fired_once: bool = pigeon.off_world_resets == 1 and _return_signal_fires == 1
	var from_ok: bool = _return_signal_from.distance_to(departure) < 0.1
	## First-frame camera: already snapped onto the corridor rig position
	## (pigeon + UP * pivot_height_air 1.4 — the pigeon has never grounded), not
	## mid-lerp across the world.
	var cam_ok: bool = pigeon.chase_camera.global_position \
			.distance_to(pigeon.global_position + Vector3.UP * 1.4) < 1.5
	## The feather poof exists AT the departure point on the reset frame —
	## found through the juice_effects group like the other juice scenarios.
	var poof: OneShotBurst = null
	for node in get_tree().get_nodes_in_group("juice_effects"):
		if node is OneShotBurst and node.scene_file_path.ends_with("feather_poof.tscn") \
				and node.global_position.distance_to(departure) < 0.5:
			poof = node
	var poof_ok: bool = poof != null
	var note_shown_ok: bool = note.visible and note.text == "home again — mind the edge"
	var fade_up_early: bool = fade.color.a > 0.0
	## Ground on the respawn corridor within ~2 s, watching the fade: it must
	## climb past a readable alpha and then be fully gone (≤ 0.01) within ~1 s
	## of game time (~66 frames) of the fire.
	var home: Vector3 = pigeon.global_position ## The corridor, one settle frame after the snap.
	var grounded := false
	var fade_seen := false
	var fade_cleared_frame := -1
	var frames_since_fire := 0
	for _i in 120:
		await get_tree().physics_frame
		frames_since_fire += 1
		if not grounded and pigeon.is_grounded \
				and pigeon.global_position.distance_to(home) < 2.0:
			grounded = true
		if fade.color.a > 0.3:
			fade_seen = true
		if fade_seen and fade_cleared_frame < 0 and fade.color.a <= 0.01:
			fade_cleared_frame = frames_since_fire
		if grounded and fade_cleared_frame >= 0:
			break
	var fade_cleared_ok: bool = fade_seen and fade_cleared_frame >= 0 \
			and fade_cleared_frame <= 66
	## ~2 s more parked home: no second fire (counter or signal), still
	## grounded — and the note has expired on its own (~150 game-time frames
	## have passed by the end of this window, whichever way the loops broke).
	await _wait_frames(120)
	var stable: bool = fired_once and grounded and pigeon.is_grounded \
			and pigeon.global_position.distance_to(home) < 1.0 \
			and pigeon.off_world_resets == 1 and _return_signal_fires == 1 \
			and not note.visible
	var hunger_loss: float = hunger0 - Game.hunger.value
	## (T-100 fold) A second deliberate fire re-runs the beat; restart_run()
	## mid-note clears note and fade and leaves the tree unpaused.
	pigeon.reset_flight(Vector3(0.0, -10.0, 0.0))
	await _wait_frames(2)
	var rebeat_ok: bool = note.visible and _return_signal_fires == 2 \
			and fade.color.a > 0.0
	main_game.restart_run()
	await _wait_frames(3)
	var restart_ok: bool = not get_tree().paused and not note.visible \
			and fade.color.a <= 0.01
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	_check("off_world_return_beat",
			rest_ok and fired_once and from_ok and cam_ok and poof_ok and note_shown_ok
					and fade_up_early and fade_cleared_ok and grounded and stable
					and hunger_loss > 0.2 and rebeat_ok and restart_ok,
			"rest=%s fires=%d from_ok=%s cam=%s poof=%s note=%s fade_up=%s fade_clear@%s grounded=%s stable=%s hunger_loss=%.2f rebeat=%s restart=%s" % [
					rest_ok, _return_signal_fires, from_ok, cam_ok, poof_ok, note_shown_ok,
					fade_up_early, fade_cleared_frame, grounded, stable, hunger_loss,
					rebeat_ok, restart_ok])

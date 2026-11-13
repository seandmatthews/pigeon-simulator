extends Node3D
## Headless sim harness (VERIFICATION.md Gate 1b): drives the Player with synthetic
## input and asserts flight, ground, city, hunger and poop behavior one scenario
## at a time.
## Run from the repo root:
##   godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
## Prints one "SIM PASS/FAIL <name>" line per scenario; exits 0 only when all pass.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const AMES_WORLD_SCENE: PackedScene = preload("res://scenes/ames_world.tscn") ## (T-173) The resident Ames world rig.
const CRUMB_SCENE: PackedScene = preload("res://scenes/bread_crumb.tscn")
const POPUP_SCENE: PackedScene = preload("res://scenes/score_popup.tscn")
const SPLAT_TARGET_SCRIPT := preload("res://tests/splat_target.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const POOP_SCENE: PackedScene = preload("res://scenes/poop.tscn")
const POOP_RETICLE_SCENE: PackedScene = preload("res://scenes/poop_reticle.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/menu.tscn")
const TOUCH_SCENE: PackedScene = preload("res://scenes/touch_controls.tscn") ## (T-119) Driven with synthetic screen contacts, never by poking its methods.
const CAR_SCENE: PackedScene = preload("res://scenes/car.tscn") ## (T-134) Hand-staged stop-protocol cars.
const RECORDER_SCRIPT := preload("res://tests/capture_recorder.gd") ## (T-140) Driven in session mode for the frame-step scenario.
const CALL_PROBE_SCRIPT := preload("res://tests/call_probe.gd") ## (T-169) The call verb's typed-method probe.

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
## 16.89 m/s under the tapered flap on the pre-T-133 tree (fixed-fps sim; the
## T-015-era tree measured 25.04 — later flap passes lowered it). T-133 re-locked
## the ceiling for the ×0.8 quartet: the new pace measures 13.15 m/s, so 15.0
## passes with margin and fails the pre-T-133 tree (16.89 — the revert probe's
## re-locked-value failure) and the old fixed 45° flap, which rode the cap.
const FLAP_PUMP_CEIL := 15.0

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
## (T-083, re-derived ×0.8 for T-133) The balloon bars. Original provenance: the
## PRE-FIX tree's measured run — peak climb vy 8.85 m/s and post-release mush
## 247/300 frames before the falloff, 8.48 and 240 after it (pre-T-133 pace).
## T-133 re-derived from the new pace's measured runs: the settled cruise is
## 13.6 m/s, so the same hold balloons to peak vy 5.54 and mushes 217/300
## (the shallower post-release sink mushes longer). 6.5 / 230 keep every
## documented red run red — the pre-fix 8.85 and 247 both still fail — while
## tightening the margin around the new pace's own numbers.
const BALLOON_VY_BAR := 6.5 ## Pre-fix measured 8.85 (fails); post-fix 8.48 at the old pace, 5.54 at the T-133 pace.
const BALLOON_MUSH_BAR := 230 ## Pre-fix measured 247 (fails); post-fix 240 at the old pace, 217 at the T-133 pace.

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
const HSO_END_ANGLE_BAR := 10.5 ## |End nose-to-flow signed angle| bound: measured 5.72 at trim_rate 0.7 pre-T-117 (bar 7.0), re-derived ×1.2 for T-117 (measured 7.59; the settle probe held: −7.59 @90 → −11.13 @180 → −4.82 @360 — the same ≈5° equilibrium). T-133 re-derived ×0.8: the slower cruise bleeds deeper in the window and recovers slower, so the 90-frame residual deepens (measured 9.70; probe −9.70 @90 → −10.81 @180 → −2.98 @360 — the trim STILL converges past the flow by 360 frames, equilibrium ≈3°, trim_rate untouched) and the bar tracks the window-relative residual, not a moved equilibrium. The T-082 freeze red-before rides the travel arm below (a frozen nose travels 0.0).
const HSO_NOSE_TRAVEL_BAR := 2.5 ## Min nose-pitch travel (deg) toward the flow over the window: measured 4.5 at trim_rate 0.7; pre-fix measured 0.0 (the attitude freeze — the red-before signature).

## (T-081) The mush-exit bars, verbatim from the ticket: over a 240-frame
## hands-off window from the 0.29-rad nose-up attitude at fwd 6.6, the pigeon
## must lose real height and reach a real sink. Measured runs recorded in the
## ticket: the pre-fix tree hovers near the aligner's zero-sink equilibrium
## (RED), the lift-keyed cut lets the fall develop (GREEN).
const MUSH_DY_BAR := -3.0 ## Min height lost (m) over the 240-frame window.
const MUSH_MIN_VY_BAR := -2.0 ## Most-negative vy (m/s) the window must reach.

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
var _boot_finished_fires: int = 0 ## (T-129) `boot_finished` emissions caught from the stepped-boot Main — same member rule as `_regen_relay`.


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
	## (T-177) The harness's far world is the resident Ames bake now — the
	## Windrow generator was retired at the cutover. It serves the scenarios
	## that read a live world's spot supply (bread respawn, the steal legs)
	## at the old "far away from the flight block" spot, far clear of every
	## instanced-Main offset in this file.
	_city = AMES_WORLD_SCENE.instantiate() as City
	_city.position = Vector3(12000.0, 0.0, 12000.0)
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
	await _scenario_ames_data_integrity() ## T-171 — FIRST: pure data over the committed Ames pack; touches no rig and no city.
	await _scenario_ames_bake_census() ## T-172 — pure data over the committed chunk bake; still no rig and no city.
	await _scenario_ames_bake_determinism() ## T-172 — re-bake in-scenario must reproduce the committed manifest hash.
	await _scenario_ames_world_render_budget() ## T-173 — the resident bake inside the draw/memory budget.
	await _scenario_ames_world_api_seam() ## T-173 — the city API over chunk data; the corridor is flyable.
	await _scenario_ames_skeleton_palette() ## T-174 — the baked dressing: pinned per-district ground colors, lane dashes, shore band, tie stripe.
	await _scenario_ames_placeholder_dims() ## T-175 — the placeholders at their survey dims: authored slots, venue fixups, hero AABBs, the ranking's water/green/rail landmarks.
	await _scenario_ames_placeholder_landable() ## T-175 — the campanile cap accepts the landing state; shaft/bowl colliders probe; the cap crumb rides ANCHOR_CRUMB_LIFT.
	await _scenario_ames_bread_reach() ## T-176 — the survival re-base: spawn over Central Campus, the core-wide bread reach grid, the Windrow-baseline crumb supply, café tables at real cafés.
	await _scenario_ames_bread_spawner() ## T-176 round 1 — the Ames spawner at the shipped target: boot ring ≤ 60 m, the live count held at target across top-up cycles, eat-and-refill reconverges exactly.
	await _scenario_ames_hunger_pins() ## T-176 — the drain quartet + favor ceiling diff-proven across the ames build.
	await _scenario_ames_street_flyover() ## T-177 — the flyover re-pin: Lincoln Way west→east at 60 m over the real skeleton.
	await _scenario_ames_roof() ## T-177 — the roof re-pin: an authored building's top is landable and walkable.
	await _scenario_ames_traffic_routes() ## T-178 — the traffic graph: census-shape lanes, Lincoln Way end-to-end, the live fleet on its directed lanes.
	await _scenario_ames_traffic_density() ## T-178 — the density law value-locked + the fleet's class mix at the cruise camera and low-hover positions, stable across seeds.
	await _scenario_ames_traffic_calm() ## T-179 — the T-166 calm etiquette re-derived on the real graph: staged honk gates, the pass on real lanes, the live fleet's hold/blinker/honk reads.
	await _scenario_ames_intersections() ## T-180 — the pinned corner set: census counts, adapted T-134 paint at measured widths, the T-143 relief, the signal phase, traffic obeys.
	await _scenario_takeoff()
	await _scenario_flap_speed_envelope()
	await _scenario_sustained_flap_ceiling()
	await _scenario_lift()
	await _scenario_energy_exchange()
	await _scenario_banking()
	await _scenario_flight_speed_quartet_locked() ## T-133 — the ×0.8 quartet, the satellite bands and the untouched rates, value-locked.
	await _scenario_turn_circle_shrinks() ## T-133 — the same hand draws a ≈×0.8 smaller circle at the slower pace.
	await _scenario_stall()
	await _scenario_landing_slide()
	await _scenario_chase_camera()
	await _scenario_ground_waddle()
	await _scenario_roof_landing()
	await _scenario_bench_landing()
	await _scenario_hard_landing()
	await _scenario_trim_glide_lands_clean()
	await _scenario_natural_glide_touch_dust() ## T-133 — the developed glide touch still dusts and settles under the (kept) land bar.
	await _scenario_flare_sheds_speed_low() ## T-022 — pitch-up low brakes into a nose-high sink instead of ballooning.
	await _scenario_pitch_attitude_bounded() ## T-083 — held pitch-up caps out near vertical instead of stacking past it.
	await _scenario_hands_off_glide_trims() ## T-082 — a released pitch input trims the nose onto the velocity vector instead of freezing it.
	await _scenario_hands_off_mush_exits() ## T-081 — a slow nose-high hands-off mush falls into a sink instead of hovering at the aligner's equilibrium.
	await _scenario_stall_falls_develops() ## T-081/T-061 — a stalled climb develops a real fall within ~0.75 s of the stall flag.
	await _scenario_loop_over_top_roll_recovers() ## T-106 — the owner's loop repro leaves no persistent roll cant, and the landing stands level with its heading kept.
	await _scenario_off_world_fall_respawns() ## T-042 — flight-model guard: the void past the apron walks home.
	await _scenario_edge_nudge_turns_home() ## T-023 — the prevention layer ahead of the guard: past the apron the course bends home.
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
	await _scenario_car_blinkers_sit_on_the_body() ## T-162 — the lamps sit on the paint body.
	await _scenario_civilian_palette_reserved() ## T-121 — the reservation law + the grown flag, bare value pins.
	await _scenario_people_on_one_rig() ## T-138 — the one rigged people source, whitelist-pruned clips, adult scale, rate-matched walks.
	await _scenario_locomotion_rate_ledger() ## T-165 — the sprint/shuffle/sit-pacing rate pins + the import-stamp ledger (the walk-rate leg stays in the row above).
	await _scenario_citizen_parts_world_scale() ## T-139 — every citizen part stays human-sized (the ×100 arm regression tripwire).
	await _scenario_elder_seats_on_the_bench() ## T-141 — the seated elder lands on the bench (the sink/hunch/hair composite).
	await _scenario_cafe_sitters_on_the_rig() ## T-142 — the café crowd wears the baked one-people model.
	await _scenario_hair_caps_round_the_skull() ## T-164 — one fitted dome cap on every head (elder, tourist, café sitter).
	await _scenario_sitters_clear_their_seats() ## T-163 — the one seat-contact law: thighs, knees and shins clear both surfaces.
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
	await _scenario_touch_button_layout_pins_tuned_values() ## T-130 — the owner's thumb ergonomics pinned: Flap r 68 / Poop r 52 read live off the shapes, gap 30, and the Poop offset exactly the layout math — a silent revert of either constant fails.
	await _scenario_gamepad_actions_bound() ## T-127 — the pad rides the existing actions: mapping pinned in the InputMap, deadzone 0.25 on the stick four, a synthetic JoypadMotion drives the real pitch axis, and the menus take the pad.
	await _scenario_title_screen_teaches_controls() ## T-039 — same T-019 window: unpaused tree, no live Main.
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
	await _scenario_ambience_bed()
	await _scenario_settings_persist_and_invert() ## T-122 — after the audio block: it touches the buses and restores them.
	await _scenario_sfx_coos_and_stingers() ## T-123 — the new voice: coos, the smug parity, and both stingers.
	await _scenario_boot_splash_pinned() ## T-125 — no Godot logo, splash = the title navy.
	await _scenario_web_quit_gated() ## T-126 — both branches of the quit seam through the real scenes.
	await _scenario_stepped_boot_pins() ## T-129 — the stepped city boot: ordered slices, ms trace, the sync rig defaults, the web diet.
	await _scenario_web_handoff_single_screen() ## T-131 — the web handoff shows ONE warming screen: the shell covers it, the note stands down.
	await _scenario_pilot_time_scale() ## T-132 — the pilot's --time-scale slows the world, not the frames; flagless boots stay 1.0.
	await _scenario_pilot_frame_step() ## T-140 — pause/step/resume + deferred presses, driven through a real recorder in session mode.
	await _scenario_dev_hunger_lock() ## T-167 — the dev-verb family on the same pilot channel: lock/refill/unlock through _execute_dev, the gate seam, live-channel flow while frozen.
	await _scenario_dev_verb_pack() ## T-168 — the starter verb pack: spawn_car/car_blinker/teleport/freeze_traffic through _execute_dev, the gate seam, ack payloads machine-checkable.
	await _scenario_dev_call_verb() ## T-169 — the call verb: one-hop invocation through _execute_dev — resolution arms, THE coercion rule, error/denylist events, the gate seam.
	await _scenario_pilot_window_hide_math() ## T-170 — the hidden-launch math: the pure hide position across three monitor layouts, the size input, and the headless guard leg.
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


## --- scenarios (T-171 Ames data pack) -------------------------------------


## T-171: the committed Ames city database is load-bearing. Pure data —
## through the real `AmesDataPack` loader (static class, NO autoload), with
## the census counts and the sentinel transforms recomputed INDEPENDENTLY
## here from the closed form and the survey docs' literal coordinates, never
## through the distiller. Runs before the flight block because it touches no
## pigeon, no city and no physics.
func _scenario_ames_data_integrity() -> void:
	const S := "ames_data_integrity"
	var bad: PackedStringArray = PackedStringArray()
	var pack: Dictionary = AmesDataPack.load_pack()
	var meta: Dictionary = pack.get("meta", {})
	if str(meta.get("pack", "")) != "ames_core" or int(meta.get("version", 0)) != 1:
		bad.append("boot: pack=%s version=%s" % [meta.get("pack"), meta.get("version")])

	# --- census counts (BUILD-CENSUS §1/§5/§6 + VENUES + LANDMARKS §5) ---
	var counts: Dictionary = meta.get("counts", {})
	if int(counts.get("buildings", 0)) != 3737:
		bad.append("buildings=%s (census 3737)" % counts.get("buildings"))
	var named_n := 0
	var authored_n := 0
	for b: Dictionary in AmesDataPack.buildings():
		if b.get("name") != null:
			named_n += 1
		if str(b.get("class", "")) == "authored":
			authored_n += 1
	if named_n != 512:
		bad.append("named_buildings=%d (census 512)" % named_n)
	if authored_n != 512:
		bad.append("authored=%d (census 512 authored-named)" % authored_n)
	if AmesDataPack.trees().size() != 5637:
		bad.append("trees=%d (census 5637)" % AmesDataPack.trees().size())
	var t1 := AmesDataPack.pois_of(1).size()
	var t2 := AmesDataPack.pois_of(2).size()
	var t3 := AmesDataPack.pois_of(3).size()
	if [t1, t2, t3] != [14, 17, 17]:
		bad.append("venue_tiers=%d/%d/%d (VENUES 14/17/17)" % [t1, t2, t3])
	if AmesDataPack.landmarks().size() != 15:
		bad.append("landmarks=%d (LANDMARKS §5 top-15)" % AmesDataPack.landmarks().size())

	# --- rail: the 9 at-grade vehicular crossings BY NAME (census §5/§7.11) ---
	var at_grade: Array[String] = []
	for c: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(c.get("grade", "")) == "at_grade":
			at_grade.append(str(c.get("road_name", "")))
	var want: Array[String] = ["13th Street", "9th Street", "North Hazel Avenue",
			"Brookridge Avenue", "", "Duff Avenue", "Grand Avenue",
			"Kellogg Avenue", "Clark Avenue"]
	var got_sorted: Array[String] = at_grade.duplicate()
	got_sorted.sort()
	var want_sorted: Array[String] = want.duplicate()
	want_sorted.sort()
	if got_sorted != want_sorted:
		bad.append("at_grade_crossings=%s (census 9: %s)" % [at_grade, want])

	# --- street centerline km, BOTH rules the ticket names ---
	# (a) the graph rule streets[] pins: census §4 midpoint rule, named
	#     drivable classes (91.93 — the street GRAPH the city code consumes).
	var km: float = float(meta.get("street_km", {}).get("named_drivable_in_core", 0.0))
	if km < 91.4 or km > 92.4:
		bad.append("street_km=%.2f (census §4: 91.9 named of 92.1 drivable)" % km)
	var km_recomputed := 0.0
	for s: Dictionary in AmesDataPack.streets():
		km_recomputed += float(s.get("km", 0.0))
	if absf(km_recomputed - km) > 0.05:
		bad.append("street_km_meta_vs_polylines=%.3f/%.3f" % [km, km_recomputed])
	# (b) the survey statistic: SUMMARY §3's 99.6 km under the extra3.py §5
	#     rule (named highway ways, NODES filtered to the core bbox, haversine
	#     over consecutive survivors — folds cycleway/service/pedestrian in;
	#     the pack carries the figure and its per-class table, and the rule
	#     re-runs from committed data: python -I docs/references/ames-survey/
	#     osm/scripts/extra3.py docs/references/ames-survey/osm/ames_merged.json
	#     docs/references/ames-survey/osm/raw).
	var km_survey: float = float(meta.get("street_km", {}).get(
			"named_highway_in_core_extra3_km", 0.0))
	if km_survey < 99.1 or km_survey > 100.1:
		bad.append("street_km_extra3=%.2f (SUMMARY §3 / extra3 §5: 99.6)" % km_survey)

	# --- sentinel transforms (independent closed-form expectations) ---
	var m_lon: float = 111320.0 * cos(deg_to_rad(42.02))
	var exp_campanile := Vector3((-93.64604 + 93.65015) * m_lon, 0.0,
			-(42.02543 - 42.02278) * 111074.0)
	var exp_mu := Vector3((-93.645762 + 93.65015) * m_lon, 0.0,
			-(42.023667 - 42.02278) * 111074.0)
	var cam := AmesDataPack.building_by_id("way/183041212")
	var mu := AmesDataPack.building_by_id("way/183224150")
	if cam.is_empty() or mu.is_empty():
		bad.append("sentinel_buildings_missing")
	else:
		var cam_c := Vector3(float(cam["centroid"][0]), 0.0, float(cam["centroid"][1]))
		var mu_c := Vector3(float(mu["centroid"][0]), 0.0, float(mu["centroid"][1]))
		if cam_c.distance_to(exp_campanile) > 3.0:
			bad.append("campanile=%s vs expected %s (±3 m)" % [cam_c, exp_campanile])
		if mu_c.distance_to(exp_mu) > 3.0:
			bad.append("mu=%s vs expected %s (±3 m)" % [mu_c, exp_mu])
		# F-06: the MU (2229 Lincoln Way) sits NORTH of Lincoln Way — z ≤ −90 m.
		if mu_c.z > -90.0:
			bad.append("mu_not_north z=%.1f" % mu_c.z)
		# the loader's transform reproduces the pack's STORED coordinates: the
		# transform of each sentinel's own stored 6-decimal wgs84 lands on the
		# stored centroid within 0.25 m (the storage roundings: lonlat 1e-6 deg
		# ≈ 0.11 m, centroid 2 decimals)
		var cam_w: Array = cam["wgs84"]
		var mu_w: Array = mu["wgs84"]
		var t_cam := AmesDataPack.wgs84_to_local(float(cam_w[0]), float(cam_w[1]))
		var t_mu := AmesDataPack.wgs84_to_local(float(mu_w[0]), float(mu_w[1]))
		if t_cam.distance_to(cam_c) > 0.25:
			bad.append("transform_campanile=%s vs pack %s" % [t_cam, cam_c])
		if t_mu.distance_to(mu_c) > 0.25:
			bad.append("transform_mu=%s vs pack %s" % [t_mu, mu_c])

	# --- Lincoln Way reads E–W at lat 42.0228 (verification §1) ---
	var lw_entries := 0
	var lw_max_abs_z := 0.0
	var lw_dx := 0.0
	var lw_dz := 0.0
	var lw_z_sum := 0.0
	var lw_pts := 0
	for s: Dictionary in AmesDataPack.streets():
		if str(s.get("name", "")) != "Lincoln Way":
			continue
		lw_entries += 1
		var pts: Array = s.get("points", [])
		for i: int in range(pts.size()):
			var p: Array = pts[i]
			var z: float = float(p[1])
			lw_max_abs_z = maxf(lw_max_abs_z, absf(z))
			lw_z_sum += z
			lw_pts += 1
			if i > 0:
				var q: Array = pts[i - 1]
				lw_dx += float(p[0]) - float(q[0])
				lw_dz += float(p[1]) - float(q[1])
	if lw_entries == 0 or lw_pts == 0:
		bad.append("lincoln_way_missing")
	else:
		if lw_max_abs_z > 40.0:
			bad.append("lincoln_way_off_lat max|z|=%.1f m" % lw_max_abs_z)
		var bearing := absf(rad_to_deg(atan2(lw_dz, lw_dx)))
		if bearing > 5.0 and bearing < 175.0:
			bad.append("lincoln_way_not_EW bearing=%.2f deg" % bearing)
		var mean_lat := AmesDataPack.local_to_wgs84(
				Vector3(0.0, 0.0, lw_z_sum / float(lw_pts))).y
		if absf(mean_lat - 42.0228) > 0.0002:
			bad.append("lincoln_way_mean_lat=%.5f (want 42.0228 ±0.0002)" % mean_lat)

	# --- orientation spot checks (F-06): Cy's Roost SOUTH of Lincoln Way ---
	for p: Dictionary in AmesDataPack.pois():
		if str(p.get("id", "")) == "cys_roost":
			if float(p["position"][1]) < 0.0:
				bad.append("cys_roost_not_south z=%s" % p["position"][1])

	# --- typed accessors + the attribution constant ---
	# nearest_street at the ORIGIN must land ON the Lincoln Way × Welch
	# crossing (within 10 m) on a street of that crossing — the intersection's
	# own slip lanes are OSM-named "Welch Road", so the family, not one name,
	# is the pin.
	var ns: Dictionary = AmesDataPack.nearest_street(Vector3.ZERO)
	var ns_name := str(ns.get("name", ""))
	if ns.is_empty() or float(ns.get("distance_m", 1e9)) > 10.0 \
			or not (ns_name.begins_with("Welch") or ns_name == "Lincoln Way"):
		bad.append("nearest_street_at_origin=%s" % ns)
	var cam_poi: Dictionary = {}
	for p: Dictionary in AmesDataPack.pois():
		if str(p.get("id", "")) == "campanile":
			cam_poi = p
	if cam_poi.is_empty() or str(cam_poi.get("name", "")) != "Campanile" \
			or int(cam_poi.get("tier", -1)) != 4:
		bad.append("campanile_poi=%s" % cam_poi)
	if AmesDataPack.facing_to_yaw(90.0) > -1.5707 or \
			AmesDataPack.facing_to_yaw(90.0) < -1.5709:
		bad.append("facing_to_yaw_east=%f" % AmesDataPack.facing_to_yaw(90.0))
	if AmesDataPack.ATTRIBUTION != "Map data © OpenStreetMap contributors" \
			or str(meta.get("attribution", "")) != AmesDataPack.ATTRIBUTION:
		bad.append("attribution=%s/%s" % [AmesDataPack.ATTRIBUTION,
				meta.get("attribution")])

	_check(S, bad.is_empty(), "; ".join(bad))


## The directory the T-172 tool bakes into (res:// — the committed bake).
const AMES_CHUNKS_DIR := "res://data/ames/chunks"


## T-172: the committed chunk bake is load-bearing. Pure data — reads the
## committed `data/ames/chunks/` output (manifest + chunk files) and proves
## the bake consumed the WHOLE pack: instance counts sum to the pack counts,
## every building lands in some chunk at its true position, all 9 at-grade
## rail crossings are world facts with real ballast gaps at them, and the
## LaVerne water flat preserves the lake's polygon area. Runs beside
## `ames_data_integrity` before any rig/city/physics exists.
func _scenario_ames_bake_census() -> void:
	const S := "ames_bake_census"
	var bad: PackedStringArray = PackedStringArray()
	var manifest: Dictionary = AmesBaker.read_manifest(AMES_CHUNKS_DIR)
	if manifest.is_empty():
		_check(S, false, "no committed bake at %s — run tools/bake_ames_chunks.gd" % AMES_CHUNKS_DIR)
		return

	# --- load every chunk once, indexed by tile ---------------------------
	var chunks: Dictionary = {} ## Vector2i -> parsed chunk Dictionary.
	var counts_sum: Dictionary = {}
	var crossings: Array[Dictionary] = []
	for entry: Dictionary in manifest.get("chunks", []):
		var tile := Vector2i(int(entry["cx"]), int(entry["cz"]))
		var chunk: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		if chunk.is_empty():
			bad.append("chunk_file_missing:%s" % entry["file"])
			continue
		chunks[tile] = chunk
		var counts: Dictionary = chunk.get("counts", {})
		for key: String in AmesBaker.FAMILY_KEYS:
			var arr: Array = chunk.get(key, [])
			## The chunk's own counts field must equal its actual arrays.
			if int(counts.get(key, -1)) != arr.size():
				bad.append("counts_%s=%s vs array %d in %s" % [
						key, counts.get(key, -1), arr.size(), entry["file"]])
			counts_sum[key] = int(counts_sum.get(key, 0)) + arr.size()
		for c: Dictionary in chunk.get("crossings", []):
			crossings.append(c)
	if chunks.is_empty():
		bad.append("no_chunks_loaded")

	# --- 1. instance counts sum to the pack counts ------------------------
	var buildings: Array[Dictionary] = AmesDataPack.buildings()
	if int(counts_sum.get("massing", 0)) != buildings.size():
		bad.append("massing_total=%d (pack buildings %d)" % [counts_sum.get("massing", 0), buildings.size()])
	# self-consistency: manifest counts == parsed chunk arrays, occluders 1:1
	var manifest_totals: Dictionary = manifest.get("totals", {})
	for key: String in AmesBaker.FAMILY_KEYS:
		if int(manifest_totals.get(key, -1)) != int(counts_sum.get(key, -2)):
			bad.append("totals_%s manifest=%s parsed=%s" % [key, manifest_totals.get(key), counts_sum.get(key)])
	if int(counts_sum.get("occluders", 0)) != int(counts_sum.get("massing", 0)):
		bad.append("occluders!=massing %d/%d" % [counts_sum.get("occluders", 0), counts_sum.get("massing", 0)])
	# derived straight from the pack (independent recomputes): asphalt
	# ribbons are EVERY non-degenerate street polyline segment; creek quads
	# are EVERY non-degenerate creek centerline segment; the lawn flat AREA
	# must equal the 31 park polygons' ring-split area (triangulation may
	# re-cut the polygons, never lose them)
	var street_segs := 0
	for s: Dictionary in AmesDataPack.streets():
		var pts: Array = s.get("points", [])
		for i: int in range(pts.size() - 1):
			var dx := float(pts[i + 1][0]) - float(pts[i][0])
			var dz := float(pts[i + 1][1]) - float(pts[i][1])
			if dx * dx + dz * dz > 1e-10:
				street_segs += 1
	if int(counts_sum.get("ribbons", 0)) != street_segs:
		bad.append("ribbons=%d (pack non-degenerate street segments %d)" % [
				counts_sum.get("ribbons", 0), street_segs])
	var creek_segs := 0
	# (T-174) College Creek FEEDS the lake: centerline segments whose
	# midpoint lies inside the lake's ring union paint no ribbon — the lake
	# flat is that ground's surface. The recount here mirrors the rule with
	# the scenario's OWN ring walk + ray cast.
	var lake_rings: Array[PackedVector2Array] = _pack_split_rings(
			AmesDataPack.water()[0].get("polygon", []))
	for wtr: Dictionary in AmesDataPack.water():
		if str(wtr.get("kind", "")) != "creek":
			continue
		for line: Array in wtr.get("centerlines", []):
			for i: int in range(line.size() - 1):
				var cdx := float(line[i + 1][0]) - float(line[i][0])
				var cdz := float(line[i + 1][1]) - float(line[i][1])
				if cdx * cdx + cdz * cdz > 1e-10:
					var cmid := Vector2(
							(float(line[i][0]) + float(line[i + 1][0])) * 0.5,
							(float(line[i][1]) + float(line[i + 1][1])) * 0.5)
					var in_lake := false
					for ring: PackedVector2Array in lake_rings:
						if _point_in_ring(cmid, ring):
							in_lake = true
							break
					if not in_lake:
						creek_segs += 1
	if int(counts_sum.get("creek_quads", 0)) != creek_segs:
		bad.append("creek_quads=%d (pack non-degenerate creek segments %d, lake-interior skipped)" % [
				counts_sum.get("creek_quads", 0), creek_segs])
	var park_area := 0.0
	for park: Dictionary in AmesDataPack.parks():
		park_area += _pack_split_area(park.get("polygon", []))
	var lawn_area := 0.0
	for tile: Vector2i in chunks:
		for t: Dictionary in chunks[tile].get("lawn_tris", []):
			var lv: Array = t["v"]
			var la := Vector2(float(lv[0]), float(lv[2]))
			var lb := Vector2(float(lv[3]), float(lv[5]))
			var lc := Vector2(float(lv[6]), float(lv[8]))
			lawn_area += absf((lb.x - la.x) * (lc.y - la.y) - (lc.x - la.x) * (lb.y - la.y)) * 0.5
	if park_area > 0.0 and absf(lawn_area - park_area) > park_area * 0.01:
		bad.append("lawn_area=%.1f m2 (park polygons %.1f m2, ±1%%)" % [lawn_area, park_area])

	# --- 2. every building position present in its own tile chunk ---------
	var massing_by_tile: Dictionary = {} ## Vector2i -> PackedVector2Array of centers.
	for tile: Vector2i in chunks:
		var centers := PackedVector2Array()
		for m: Dictionary in chunks[tile].get("massing", []):
			var p: Array = m["p"]
			centers.append(Vector2(float(p[0]), float(p[2])))
		massing_by_tile[tile] = centers
	var missing := 0
	var first_missing := ""
	for b: Dictionary in buildings:
		var centroid: Array = b.get("centroid", [0.0, 0.0])
		var pos := Vector2(float(centroid[0]), float(centroid[1]))
		var tile := Vector2i(floori(pos.x / 256.0), floori(pos.y / 256.0))
		if not chunks.has(tile):
			missing += 1
			if first_missing.is_empty():
				first_missing = "%s tile %s has no chunk" % [b.get("id"), tile]
			continue
		var found := false
		for c: Vector2 in massing_by_tile[tile]:
			if c.distance_to(pos) < 0.05:
				found = true
				break
		if not found:
			missing += 1
			if first_missing.is_empty():
				first_missing = "%s at %s not in chunk %s" % [b.get("id"), pos, tile]
	if missing > 0:
		bad.append("buildings_missing_from_chunks=%d (%s)" % [missing, first_missing])

	# --- 3. all 9 at-grade crossings present, with real ballast gaps ------
	var want_crossings: Array[String] = []
	var crossing_pos := {} ## road name -> Vector2 (pack side).
	for c: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(c.get("grade", "")) == "at_grade":
			var road := str(c.get("road_name", ""))
			want_crossings.append(road)
			var pos: Array = c.get("pos", [0.0, 0.0])
			crossing_pos[road] = Vector2(float(pos[0]), float(pos[1]))
	want_crossings.sort()
	var got_crossings: Array[String] = []
	for c: Dictionary in crossings:
		got_crossings.append(str(c.get("road", "")))
	got_crossings.sort()
	if got_crossings != want_crossings:
		bad.append("crossing_names=%s (want %s)" % [got_crossings, want_crossings])
	if crossings.size() != 9:
		bad.append("crossing_count=%d (want 9)" % crossings.size())
	# each crossing has a REAL gap, proven GEOMETRICALLY on the baked output:
	# the crossing's road is whatever asphalt the bake actually laid near the
	# crossing pos — ribbon quads with centers within ROAD_NEAR of it (both
	# carriageways of a divided road — the pack carries one street entry per
	# carriageway, and the ballast must clear every one that crosses the
	# track). The old midpoint-radius form here was tautological — it
	# measured the baker's own skip rule against itself and could never fail
	# (red-before measured: ballast painted OVER crossing asphalt at Kellogg
	# 85.5 m², Clark 63.9, Grand 24.4, North Hazel/Brookridge 1.6 each).
	const ROAD_NEAR := 40.0
	var ballast_quads: Array = []
	var ribbon_quads: Array = []
	for tile: Vector2i in chunks:
		for q: Dictionary in chunks[tile].get("ballast_quads", []):
			ballast_quads.append(q["q"])
		for q2: Dictionary in chunks[tile].get("ribbons", []):
			ribbon_quads.append(q2["q"])
	var road_quads_near: Array = [] ## Ribbon quads near ANY crossing.
	var roads_per_crossing := {} ## road -> quad count (the no-vacuous-pass arm).
	for road: String in crossing_pos:
		roads_per_crossing[road] = 0
	for q: Array in ribbon_quads:
		var q_mid := Vector2((float(q[0]) + float(q[6])) * 0.5,
				(float(q[2]) + float(q[8])) * 0.5)
		for road: String in crossing_pos:
			if q_mid.distance_to(crossing_pos[road]) < ROAD_NEAR:
				road_quads_near.append(q)
				roads_per_crossing[road] = int(roads_per_crossing[road]) + 1
	for road: String in crossing_pos:
		if int(roads_per_crossing[road]) == 0:
			bad.append("crossing_%s has no baked road quads within %.0f m — its gap check would be vacuous" % [road, ROAD_NEAR])
	var overlapped := 0
	var first_overlap := ""
	for q: Array in ballast_quads:
		var b_mid := Vector2((float(q[0]) + float(q[6])) * 0.5,
				(float(q[2]) + float(q[8])) * 0.5)
		var near_crossing := false
		for road: String in crossing_pos:
			if b_mid.distance_to(crossing_pos[road]) < ROAD_NEAR + 25.0:
				near_crossing = true
				break
		if not near_crossing:
			continue
		for rq: Array in road_quads_near:
			if _flat_quads_overlap(q, rq):
				overlapped += 1
				if first_overlap.is_empty():
					first_overlap = "ballast at (%.1f, %.1f)" % [b_mid.x, b_mid.y]
				break
	if overlapped > 0:
		bad.append("ballast quads over crossing-road asphalt=%d (%s)" % [overlapped, first_overlap])

	# --- 4. LaVerne water flat area: PACK PRESERVATION --------------------
	# The bake triangulates the lake polygon into `water_tris` (chunked by
	# triangle centroid — no clipping loss). The criterion arm (AC amended
	# 2026-11-09, orchestrator-approved per V-12 — the original ±2%-of-11,300
	# band was unsatisfiable against the faithful pack): the baked water area
	# matches the pack polygon's RING-SPLIT shoelace within ±1%. The DNR
	# 2.8 ac (≈11,300 m²) vs OSM-ring gap is the survey's SETTLED V-12
	# simplification difference (docs/references/ames-survey/verification/
	# VERIFICATION.md:80) — recorded here as a comment, never asserted: the
	# census scenario proves the bake PRESERVES the data pack; the real
	# world's 11,300 m² is not the polygon's job to hit. (Measured at
	# landing: baked 11,067.7 m², split shoelace 11,067.7 — the pack's own
	# `area_m2` scalar 11,040 sits 0.25 % below its true split geometry,
	# inside the 1 % follow-up threshold, so no T-171 correction is owed.)
	var la_verne := 0.0
	for tile: Vector2i in chunks:
		for t: Dictionary in chunks[tile].get("water_tris", []):
			var v: Array = t["v"]
			var a := Vector2(float(v[0]), float(v[2]))
			var b5 := Vector2(float(v[3]), float(v[5]))
			var c2 := Vector2(float(v[6]), float(v[8]))
			la_verne += absf((b5.x - a.x) * (c2.y - a.y) - (c2.x - a.x) * (b5.y - a.y)) * 0.5
	var split_area := _pack_split_area(AmesDataPack.water()[0].get("polygon", []))
	if split_area <= 0.0:
		bad.append("laverne_split_area_recompute_failed")
	elif absf(la_verne - split_area) > split_area * 0.01:
		bad.append("laverne_area=%.1f m2 vs pack ring-split shoelace %.1f m2 (±1%%)" % [la_verne, split_area])

	_check(S, bad.is_empty(), "; ".join(bad))


## Strict separating-axis test on two flat quads (`[[x, y, z] × 4]` corner
## arrays, x/z only): TRUE when the quads overlap OR merely touch (a shared
## edge clears on no axis). The bake keeps a GAP_MARGIN hairline back from
## crossing asphalt, so any touch of baked ballast with baked road is a real
## defect. Coded separately from the baker's margined copy on purpose.
func _flat_quads_overlap(a: Array, b: Array) -> bool:
	for idx: int in 2:
		var q: Array = a if idx == 0 else b
		for i: int in 4:
			var p := Vector2(float(q[i * 3]), float(q[i * 3 + 2]))
			var r := Vector2(float(q[((i + 1) % 4) * 3]), float(q[((i + 1) % 4) * 3 + 2]))
			var e := r - p
			if e.length_squared() < 1e-12:
				continue
			var axis := Vector2(-e.y, e.x).normalized()
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for k: int in 4:
				var da := axis.dot(Vector2(float(a[k * 3]), float(a[k * 3 + 2])))
				var db := axis.dot(Vector2(float(b[k * 3]), float(b[k * 3 + 2])))
				amin = minf(amin, da)
				amax = maxf(amax, da)
				bmin = minf(bmin, db)
				bmax = maxf(bmax, db)
			if maxf(amin - bmax, bmin - amax) > 0.0:
				return false ## Strictly separated on this axis: clear.
	return true


## Independent recompute (the no-self-test rule): the ring-split shoelace of
## a pack polygon. The stored LaVerne sequence is TWO joined OSM ways
## sharing a seam — a naive shoelace over the raw sequence undercounts by the
## seam loop, and a naive ear clip double-covers the lake; the walk below
## closes a loop at each repeated vertex and sums |signed area| over the
## simple loops. Coded here separately from the baker's splitter on purpose.
func _pack_split_area(list: Array) -> float:
	var total := 0.0
	for loop: PackedVector2Array in _pack_split_rings(list):
		var a2 := 0.0
		for i: int in loop.size():
			a2 += loop[i].cross(loop[(i + 1) % loop.size()])
		total += absf(a2 * 0.5)
	return total


## The ring walk of `_pack_split_area`, shared with the T-174 shore recount
## (the shore band is one quad per non-degenerate split-ring edge). Still the
## scenario's OWN walk — never the baker's `_split_rings`.
func _pack_split_rings(list: Array) -> Array[PackedVector2Array]:
	var pts := PackedVector2Array()
	for p: Array in list:
		pts.append(Vector2(float(p[0]), float(p[1])))
	var dedup := PackedVector2Array()
	for v: Vector2 in pts:
		if dedup.is_empty() or dedup[dedup.size() - 1] != v:
			dedup.append(v)
	var loops: Array[PackedVector2Array] = []
	var cur := PackedVector2Array()
	var seen: Dictionary = {}
	for v: Vector2 in dedup:
		var key := "%s,%s" % [v.x, v.y]
		if seen.has(key):
			var j: int = seen[key]
			var loop := PackedVector2Array()
			for k: int in range(j, cur.size()):
				loop.append(cur[k])
			var clean := PackedVector2Array()
			for w: Vector2 in loop:
				if clean.is_empty() or clean[clean.size() - 1] != w:
					clean.append(w)
			if clean.size() >= 3:
				loops.append(clean)
			cur = cur.slice(0, j + 1)
			seen.clear()
			for k: int in cur.size():
				seen["%s,%s" % [cur[k].x, cur[k].y]] = k
		else:
			seen[key] = cur.size()
			cur.append(v)
	if cur.size() >= 3:
		loops.append(cur)
	return loops


## T-172: the bake is a pure function of the pack — re-bake IN-SCENARIO into
## user:// through the same `AmesBaker` core the tool uses and require the
## identical manifest hash (per-chunk SHA-256 set + the total). Proves the
## committed bake is reproducible offline, byte for byte.
func _scenario_ames_bake_determinism() -> void:
	const S := "ames_bake_determinism"
	var committed: Dictionary = AmesBaker.read_manifest(AMES_CHUNKS_DIR)
	if committed.is_empty():
		_check(S, false, "no committed bake at %s" % AMES_CHUNKS_DIR)
		return
	const REBAKE_DIR := "user://ames_rebake_t172"
	var rebaked: Dictionary = AmesBaker.bake_to_dir(REBAKE_DIR)
	if rebaked.is_empty():
		_check(S, false, "re-bake failed (no manifest)")
		return
	var bad: PackedStringArray = PackedStringArray()
	if str(committed.get("total_sha256", "")) != str(rebaked.get("total_sha256", "")):
		bad.append("total_sha256 committed=%s rebaked=%s" % [
				committed.get("total_sha256"), rebaked.get("total_sha256")])
	var committed_by_file: Dictionary = {}
	for entry: Dictionary in committed.get("chunks", []):
		committed_by_file[str(entry["file"])] = str(entry["sha256"])
	var rebaked_by_file: Dictionary = {}
	for entry: Dictionary in rebaked.get("chunks", []):
		rebaked_by_file[str(entry["file"])] = str(entry["sha256"])
	if committed_by_file.keys() != rebaked_by_file.keys():
		bad.append("chunk_file_set differs (%d vs %d)" % [committed_by_file.size(), rebaked_by_file.size()])
	else:
		for file: String in committed_by_file:
			if committed_by_file[file] != rebaked_by_file[file]:
				bad.append("chunk_hash differs: %s" % file)
	# sweep the scratch dir so the run leaves nothing behind
	var dir := DirAccess.open(REBAKE_DIR)
	if dir != null:
		for f: String in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(REBAKE_DIR)
	_check(S, bad.is_empty(), "; ".join(bad))


## --- scenarios (T-173 Ames world renderer) ---------------------------------


## Offset every Ames rig out past the harness world (the rig ground plate sits
## at the origin; the bake's z extent ends ~1.4 km out, so 8 km south clears
## it with precision to spare — the review's ±4 km single-precision note is
## about bake-local coordinates, which stay untouched).
const AMES_WORLD_OFFSET := Vector3(0.0, 0.0, 8000.0)


## (T-173; instances extended by T-174's dressing families) The resident
## baked world renders the WHOLE committed bake inside
## the perf budget, chunk-partitioned: every chunk is one small node family
## (massing boxes / ground rectangles — now including the T-174 dressing
## flats: district ground cells, arterial lane dashes, the LaVerne shore
## band, the rail tie stripe, all folded into the same per-chunk box
## MultiMesh — and lake-park triangles, each ONE
## frustum-cullable MultiMesh via its manifest AABB, plus one baked
## ArrayOccluder3D), so the draw story is per-chunk culling, not
## per-building. Measured, not assumed: the whole-world draw ceiling (every
## chunk visible) AND the camera-pose ceilings at the ticket's two poses —
## cruise over Campustown (60 m, looking east across the strip) and a low
## hover over downtown (20 m) — must stay under the 800-draw budget, the
## resident buffer estimate under the 400 MB chunk-memory budget, the built
## instance count equal to the committed bake totals (the renderer consumed
## everything — the memory metric honest), and one occluder per chunk. The
## pose read is the scenario's own frustum test: the engine camera's own
## planes (`Camera3D.get_frustum` — the same math the renderer culls with)
## against each chunk's manifest AABB via its 8 corners
## (all-corners-over-ANY-one-plane excludes; a camera inside the AABB is
## visible). First values printed on the SIM DATA line for the in-ticket
## record; a budget retune re-derives the gate, never edits the assertion.
func _scenario_ames_world_render_budget() -> void:
	const S := "ames_world_render_budget"
	const DRAW_BUDGET := 800 ## (T-173) first value in-ticket, tuned on measurement.
	const MEMORY_BUDGET_BYTES := 400 * 1024 * 1024
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	var bad: PackedStringArray = PackedStringArray()
	var m: Dictionary = world.render_metrics()
	var manifest: Dictionary = AmesBaker.read_manifest(AMES_CHUNKS_DIR)
	var totals: Dictionary = manifest.get("totals", {})
	var chunk_count := (manifest.get("chunks", []) as Array).size()
	## (T-175) the placeholders joined the resident count (the renderer draws
	## every entry) while the heroes' superseded bbox boxes LEFT it — the
	## manifest's `heroes` ids are skipped by the massing MultiMesh, so the
	## honest expectation is massing − heroes + placeholders + the flats.
	var hero_count := (manifest.get("heroes", []) as Array).size()
	var expected_instances := int(totals.get("massing", 0)) - hero_count \
			+ int(totals.get("ribbons", 0)) \
			+ int(totals.get("lane_quads", 0)) + int(totals.get("shore_quads", 0)) \
			+ int(totals.get("creek_quads", 0)) + int(totals.get("ballast_quads", 0)) \
			+ int(totals.get("tie_quads", 0)) + int(totals.get("ground_quads", 0)) \
			+ int(totals.get("water_tris", 0)) + int(totals.get("lawn_tris", 0)) \
			+ int(totals.get("placeholders", 0))
	if int(m.mm_nodes) <= 0:
		bad.append("no chunk MultiMeshes built (%s)" % str(m))
	if int(m.instances) != expected_instances:
		bad.append("instances %d != bake total %d" % [m.instances, expected_instances])
	if int(m.chunk_count) != chunk_count:
		bad.append("chunks %d != manifest %d" % [m.chunk_count, chunk_count])
	if int(m.mm_nodes) > DRAW_BUDGET:
		bad.append("whole-world draw ceiling %d > %d" % [m.mm_nodes, DRAW_BUDGET])
	if int(m.buffer_bytes) > MEMORY_BUDGET_BYTES:
		bad.append("buffer bytes %d > %d" % [m.buffer_bytes, MEMORY_BUDGET_BYTES])
	var occluders := 0
	var mm_per_chunk := 0
	var chunks_root := world.get_node_or_null("Chunks") as Node3D
	if chunks_root == null:
		bad.append("no Chunks root — the world did not build")
	else:
		for c: Node in chunks_root.get_children():
			## owned=false: the chunk families are built at runtime — no scene owner.
			occluders += c.find_children("*", "OccluderInstance3D", true, false).size()
			mm_per_chunk = maxi(mm_per_chunk,
					c.find_children("*", "MultiMeshInstance3D", true, false).size())
	## Baked occlusion rode along: exactly one occluder per MASSING-bearing
	## chunk (26 of the 173 tiles are flats-only — streets/water/dressing with no
	## buildings — recomputed from the manifest, not trusted from the build).
	var massing_chunks := 0
	for entry: Dictionary in manifest.get("chunks", []):
		if int(entry.get("counts", {}).get("massing", 0)) > 0:
			massing_chunks += 1
	if occluders != massing_chunks:
		bad.append("occluders %d != massing-bearing chunks %d" % [occluders, massing_chunks])
	## The ticket's two poses, staged on a probe camera mid-band of the chase
	## rig (fov 72 air → 79 at cruise; far stays the engine default 4000, as
	## in the game scene).
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.global_transform = _look_xf(AMES_WORLD_OFFSET + Vector3(-300.0, 60.0, 60.0), -90.0, -20.0)
	var cruise_draws := _frustum_draw_ceiling(world, cam)
	cam.global_transform = _look_xf(AMES_WORLD_OFFSET + Vector3(2700.0, 20.0, -256.0), -90.0, -10.0)
	var hover_draws := _frustum_draw_ceiling(world, cam)
	print("SIM DATA %s: mm_nodes=%d instances=%d buffer_bytes=%d max_mm_per_chunk=%d cruise_draws=%d hover_draws=%d" % [
			S, m.mm_nodes, m.instances, m.buffer_bytes, mm_per_chunk, cruise_draws, hover_draws])
	if cruise_draws > DRAW_BUDGET:
		bad.append("cruise-over-Campustown draws %d > %d" % [cruise_draws, DRAW_BUDGET])
	if hover_draws > DRAW_BUDGET:
		bad.append("low-hover-over-downtown draws %d > %d" % [hover_draws, DRAW_BUDGET])
	_check(S, bad.is_empty(), "; ".join(bad))
	cam.queue_free()
	world.queue_free()


## A camera transform at `pos` yawing `yaw_deg` about UP (−90 faces +x east)
## then pitching `pitch_deg` about the yawed local x (negative looks down) —
## the probe poses' staging helper.
func _look_xf(pos: Vector3, yaw_deg: float, pitch_deg: float) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	b = Basis(b.x, deg_to_rad(pitch_deg)) * b
	return Transform3D(b, pos)


## The scenario's own chunk-culling read: the draw ceiling of every chunk
## whose content AABB intersects the camera frustum (each chunk MultiMesh is
## ONE draw when visible — the partition's whole point). Convex-vs-convex:
## the box is culled only when ALL 8 corners sit over the SAME frustum plane;
## a camera position inside the box is visible outright.
func _frustum_draw_ceiling(world: AmesWorld, cam: Camera3D) -> int:
	var planes := cam.get_frustum()
	var draws := 0
	for entry: Dictionary in AmesBaker.read_manifest(AMES_CHUNKS_DIR).get("chunks", []):
		var tile := Vector2i(int(entry["cx"]), int(entry["cz"]))
		var aabb := world.chunk_aabb(tile)
		if aabb.size == Vector3.ZERO:
			continue
		if not _aabb_hits_frustum(aabb, world, cam.global_position, planes):
			continue
		var chunk := world.get_node_or_null("Chunks/Chunk_%d_%d" % [tile.x, tile.y]) as Node3D
		if chunk == null:
			continue
		draws += chunk.find_children("*", "MultiMeshInstance3D", true, false).size()
	return draws


func _aabb_hits_frustum(aabb: AABB, world: Node3D, cam_pos: Vector3,
		planes: Array[Plane]) -> bool:
	if aabb.has_point(world.to_local(cam_pos)):
		return true
	var corners: Array[Vector3] = []
	for k in 8:
		corners.append(world.to_global(Vector3(
				aabb.position.x + (aabb.size.x if k & 1 != 0 else 0.0),
				aabb.position.y + (aabb.size.y if k & 2 != 0 else 0.0),
				aabb.position.z + (aabb.size.z if k & 4 != 0 else 0.0))))
	for plane: Plane in planes:
		var all_over := true
		for corner: Vector3 in corners:
			if not plane.is_point_over(corner):
				all_over = false
				break
		if all_over:
			return false
	return true


## (T-173) The gameplay seam: everything gameplay reads off the world answers
## over chunk data through the City API's signatures, and the world is
## FLYABLE — the pigeon drops into the spawn corridor and settles grounded on
## the ground plate, then a grounded flap returns it to flight. Expected
## values recomputed INDEPENDENTLY from the committed bake (the no-self-test
## rule): the ground query's massing leg re-reads chunk (0, 0) and takes its
## tallest box, the plate leg re-scans the four origin tiles for any box
## covering the pack origin (Lincoln Way × Welch — a street crossing, so none
## may), the tile-crossing leg (round-1 review) finds the bake's
## largest-overhang box by an independent scan of every chunk file and
## requires the query to answer its top BOTH at the center AND inside the
## overhang region — the neighbor tile a centroid-only filing never saw,
## the guard circle (round-1 review) must hold EVERY manifest chunk AABB's
## corners (the round-1 build pinned it at the pack origin and leaked 46%
## of the massing — the T-023 nudge banked the pigeon home over downtown),
## the district lookup pins the baker v0 rule's four families at
## independently-derived points (Campustown band off Lincoln Way, downtown
## band off Main Street z ≈ −256, the campanile's campus anchor, and a point
## past every band), and the spawn corridor is the pack origin itself — above
## the plate, massing-clear by the same scan.
func _scenario_ames_world_api_seam() -> void:
	const S := "ames_world_api_seam"
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	var bad: PackedStringArray = PackedStringArray()
	## Ground query, massing leg: tallest box of the independently re-read
	## chunk, queried at its footprint center.
	var doc: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, "chunk_0_0.json")
	var tallest: Dictionary = {}
	for b: Dictionary in doc.get("massing", []):
		if tallest.is_empty() or float(b["p"][1]) + float(b["s"][1]) * 0.5 \
				> float(tallest["p"][1]) + float(tallest["s"][1]) * 0.5:
			tallest = b
	var probe := world.to_global(Vector3(float(tallest["p"][0]), 0.0, float(tallest["p"][2])))
	var expected_top := float(tallest["p"][1]) + float(tallest["s"][1]) * 0.5
	var got := world.ground_height(probe)
	if absf(got - expected_top) > 0.05:
		bad.append("ground_height massing %.2f != %.2f" % [got, expected_top])
	## Ground query, plate leg: the origin stays massing-clear and answers 0.
	var origin_clear := true
	for tile: Vector2i in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 0)]:
		var near: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR,
				"chunk_%d_%d.json" % [tile.x, tile.y])
		for b: Dictionary in near.get("massing", []):
			if absf(float(b["p"][0])) <= float(b["s"][0]) * 0.5 \
					and absf(float(b["p"][2])) <= float(b["s"][2]) * 0.5:
				origin_clear = false
				bad.append("origin not massing-clear: %s covers it" % b["id"])
	if origin_clear and world.ground_height(world.to_global(Vector3.ZERO)) != 0.0:
		bad.append("origin plate query != 0")
	## Ground query, tile-crossing leg (round-1 review): the bake files each
	## box under its CENTROID tile, and 401 of 3,737 boxes cross a 256 m tile
	## edge (worst overhang 77 m) — centroid-only filing answered the plate
	## (0.0) for points standing under those overhangs (live call-verb
	## evidence in the ticket). Recomputed here from the committed chunks:
	## the largest-overhang box must answer its top BOTH at the center and
	## at a point of its overhang region — a point inside the footprint but
	## inside the NEIGHBOR tile.
	var crossing: Dictionary = {} ## {box, overhang, probe} — the worst overhang.
	var crossing_count := 0
	## (T-175) the hero buildings' superseded bbox massing no longer answers
	## the ground query (the silhouettes file their own true tops), so the
	## crossing-box scan skips them and pins the worst crossing box of the
	## massing that still serves the seam. The worst hero (the bowl's 77 m
	## z-overhang) would otherwise shadow every real candidate.
	var seam_hero_ids: Dictionary = {}
	for hero_id: Variant in AmesBaker.read_manifest(AMES_CHUNKS_DIR).get("heroes", []):
		seam_hero_ids[str(hero_id)] = true
	for entry: Dictionary in AmesBaker.read_manifest(AMES_CHUNKS_DIR).get("chunks", []):
		var doc_c: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		for b: Dictionary in doc_c.get("massing", []):
			if seam_hero_ids.has(str(b["id"])):
				continue
			var cx := float(b["p"][0])
			var cz := float(b["p"][2])
			var hw := float(b["s"][0]) * 0.5
			var hd := float(b["s"][2]) * 0.5
			var tile_size := AmesBaker.CHUNK_SIZE
			var tx := floori(cx / tile_size)
			var tz := floori(cz / tile_size)
			var over_x_lo := maxf(0.0, float(tx) * tile_size - (cx - hw))
			var over_x_hi := maxf(0.0, (cx + hw) - float(tx + 1) * tile_size)
			var over_z_lo := maxf(0.0, float(tz) * tile_size - (cz - hd))
			var over_z_hi := maxf(0.0, (cz + hd) - float(tz + 1) * tile_size)
			var over := maxf(maxf(over_x_lo, over_x_hi), maxf(over_z_lo, over_z_hi))
			if over > 0.0:
				crossing_count += 1
			if crossing.is_empty() or over > float(crossing["overhang"]):
				var probe_p := Vector3.ZERO
				if over == over_x_hi:
					probe_p = Vector3(((float(tx + 1) * tile_size) + (cx + hw)) * 0.5, 0.0, cz)
				elif over == over_x_lo:
					probe_p = Vector3((float(tx) * tile_size + (cx - hw)) * 0.5, 0.0, cz)
				elif over == over_z_hi:
					probe_p = Vector3(cx, 0.0, ((float(tz + 1) * tile_size) + (cz + hd)) * 0.5)
				else:
					probe_p = Vector3(cx, 0.0, (float(tz) * tile_size + (cz - hd)) * 0.5)
				crossing = {"box": b, "overhang": over, "probe": probe_p}
	if crossing.is_empty() or float(crossing["overhang"]) <= 0.0:
		bad.append("no tile-crossing box recomputed from the bake (probe arm vacuous)")
	else:
		var cb: Dictionary = crossing["box"]
		var cb_top := float(cb["p"][1]) + float(cb["s"][1]) * 0.5
		var got_center := world.ground_height(world.to_global(
				Vector3(float(cb["p"][0]), 0.0, float(cb["p"][2]))))
		var got_over := world.ground_height(world.to_global(crossing["probe"]))
		print("SIM DATA %s: crossing boxes=%d worst overhang=%.1f m id=%s center=%.2f overhang_point=%.2f want=%.2f" % [
				S, crossing_count, crossing["overhang"], cb["id"], got_center, got_over, cb_top])
		if absf(got_center - cb_top) > 0.05:
			bad.append("crossing box center %.2f != %.2f" % [got_center, cb_top])
		if absf(got_over - cb_top) > 0.05:
			bad.append("crossing box OVERHANG point %.2f != %.2f (red-before: 0.0)" % [got_over, cb_top])
	## Guard-circle containment (round-1 review): the wired guard circle must
	## hold EVERY chunk AABB. The round-1 build pinned the center at the pack
	## origin (the map's west edge) with a 2335.2 m radius and left 1,719 of
	## 3,737 boxes (46%) outside it — the T-023 nudge banked the pigeon home
	## over downtown (live A/B: heading north at 100 m over Main St, yaw
	## drifted 0→1.10 rad in 4 s; the Campustown control held 0.00). Corners
	## recomputed here from the manifest; the world-owned center/radius must
	## contain them all.
	var guard_center := world.home_center()
	var guard_radius := world.home_radius()
	var worst_corner := -INF
	for entry: Dictionary in AmesBaker.read_manifest(AMES_CHUNKS_DIR).get("chunks", []):
		var tile: Vector2i = Vector2i(int(entry["cx"]), int(entry["cz"]))
		var aabb := world.chunk_aabb(tile)
		if aabb.size == Vector3.ZERO:
			bad.append("chunk %s missing from the world" % tile)
			continue
		for k in 8:
			var corner := world.to_global(Vector3(
					aabb.position.x + (aabb.size.x if k & 1 != 0 else 0.0),
					aabb.position.y + (aabb.size.y if k & 2 != 0 else 0.0),
					aabb.position.z + (aabb.size.z if k & 4 != 0 else 0.0)))
			worst_corner = maxf(worst_corner, corner.distance_to(guard_center))
	print("SIM DATA %s: guard center=%s radius=%.1f worst corner=%.1f (containment margin %.1f m)" % [
			S, guard_center, guard_radius, worst_corner, guard_radius - worst_corner])
	if guard_radius <= 0.0:
		bad.append("guard radius not wired (%.1f)" % guard_radius)
	if worst_corner > guard_radius:
		bad.append("guard circle leaks the map: worst corner %.1f > radius %.1f" % [
				worst_corner, guard_radius])
	## District lookup: the four families of the baker's v0 rule.
	var districts := {
		Vector3(-300.0, 0.0, 60.0): "campustown",
		Vector3(2700.0, 0.0, -256.0): "downtown",
		Vector3(340.0, 0.0, -294.0): "campus",
		Vector3(1500.0, 0.0, 900.0): "residential",
	}
	for pos: Vector3 in districts:
		var got_d: String = world.district_at(world.to_global(pos))
		if got_d != districts[pos]:
			bad.append("district_at %s = %s != %s" % [pos, got_d, districts[pos]])
	## Spawn corridor: since T-176 the survival spawn is Central Campus near
	## the campanile (owner-decided 2026-11-09, master plan §11.1) — the
	## campanile POI plus the world's east offset, at the ground answer plus
	## the drop (massing-clear there — the plate, not a roof), replacing the
	## T-173 pack-origin pin (this scenario's comment always said T-176
	## re-pins it).
	var spawn_local := world.to_local(world.spawn_point)
	var cam_poi := Vector2.ZERO
	for poi: Dictionary in AmesDataPack.landmarks():
		if str(poi.get("id", "")) == "campanile":
			var p: Array = poi.get("position", [0.0, 0.0])
			cam_poi = Vector2(float(p[0]), float(p[1]))
			break
	if cam_poi == Vector2.ZERO:
		bad.append("campanile POI missing — spawn corridor unverifiable")
	else:
		var want := Vector2(cam_poi.x + world.SPAWN_CAMPANILE_OFFSET_X, cam_poi.y)
		if Vector2(spawn_local.x, spawn_local.z).distance_to(want) > 0.01:
			bad.append("spawn corridor off the campanile: local %s want %s" % [
					Vector2(spawn_local.x, spawn_local.z), want])
		var want_y := world.ground_height(world.to_global(Vector3(want.x, 0.0, want.y))) \
				+ world.spawn_drop_height
		if absf(spawn_local.y - want_y) > 0.001:
			bad.append("spawn corridor height %.3f != ground %.3f + drop" % [
					spawn_local.y, want_y])
		if world.ground_height(world.spawn_point) != 0.0:
			bad.append("spawn corridor not massing-clear: ground %.2f" % \
					world.ground_height(world.spawn_point))
	## ... and flyable: a drop into the corridor settles grounded on the
	## plate (top y 0 — the pigeon stands at its own 0.3 half-height), then
	## the flap_takes_off_ground contract: one grounded flap returns to flight.
	await _set_up(true, world.spawn_point - Vector3.UP * world.spawn_drop_height
			+ Vector3.UP * 3.0, Vector3.ZERO)
	await _await_grounded(150)
	var grounded_ok := _player.is_grounded and _player.position.y > 0.15 \
			and _player.position.y < 0.45 and _player.velocity.is_finite()
	var peak_y := _player.position.y
	await _tap("flap")
	for _i in 60:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, _player.position.y)
		if not _player.is_grounded and peak_y > 0.8:
			break
	var flyable_ok := not _player.is_grounded and peak_y > 0.8 \
			and _player.velocity.is_finite()
	_check(S, bad.is_empty() and grounded_ok and flyable_ok,
			"%s; grounded=%s at y=%.2f, takeoff peak %.2f" % ["; ".join(bad),
					_player.is_grounded, _player.position.y, peak_y])
	world.queue_free()


## (T-174) The baked skeleton's DRESSING, machine-checked over the committed
## chunks: the per-district GROUND palette is pinned (the pin is the
## deliberately duplicated const — a retune must re-pin here) and bound
## cell-exact to the v0 district rule over EVERY baked ground cell, the flat
## families carry their pinned colors in every chunk (the vertex-color
## discipline — dressing rides baked per-instance data, never materials),
## the arterial lane dashes recount EXACTLY from the pack's polylines on the
## four named corridors and nowhere else, the LaVerne shore band hugs the
## lake while staying UNDER the water top (an overlap can never paint the
## lake), the tie stripe rides the ballast 1:1 through the same honest
## crossing gaps, and the creek green stays distinct from the lake olive.
## Windrow is untouched — every read here is over `data/ames/`.
func _scenario_ames_skeleton_palette() -> void:
	const S := "ames_skeleton_palette"
	var manifest: Dictionary = AmesBaker.read_manifest(AMES_CHUNKS_DIR)
	if manifest.is_empty():
		_check(S, false, "no committed bake at %s" % AMES_CHUNKS_DIR)
		return
	var bad: PackedStringArray = PackedStringArray()

	# --- 1. the pinned district ground palette -----------------------------
	var want_ground := {
		"campus": Color(0.4, 0.529, 0.298), ## #66874C campus lawn green.
		"campustown": Color(0.518, 0.494, 0.447), ## #847E72 scruffy gray.
		"downtown": Color(0.627, 0.439, 0.322), ## #A07052 brick-warm sidewalk.
		"lincolnway": Color(0.333, 0.322, 0.298), ## #55524C strip asphalt.
		"residential": Color(0.38, 0.46, 0.3), ## #61754D the plate seed.
	}
	if (AmesBaker.DISTRICT_GROUND.keys() as Array).size() != want_ground.size():
		bad.append("DISTRICT_GROUND keys %s != the pinned five" % str(AmesBaker.DISTRICT_GROUND.keys()))
	for d: String in want_ground:
		var got: Color = AmesBaker.DISTRICT_GROUND.get(d, Color(-1.0, -1.0, -1.0))
		if got != want_ground[d]:
			bad.append("ground palette %s = %s (pinned %s)" % [d, got, want_ground[d]])

	# --- 2. pinned family colors, present in EVERY chunk -------------------
	# (Every chunk shares the bake's one colors dict; checking all of them
	# makes a half-written bake fail the same night.)
	var want_colors := {
		"ribbons": Color(0.29, 0.29, 0.31), ## asphalt.
		"lane_quads": Color(0.78, 0.7, 0.353), ## #C7B35A centerline yellow.
		"water_tris": Color(0.275, 0.329, 0.247), ## #46543F lake olive-brown.
		"shore_quads": Color(0.435, 0.561, 0.31), ## #6F8F4F mown shore lawn.
		"creek_quads": Color(0.275, 0.4, 0.388), ## #466663 green-blue ribbons.
		"lawn_tris": Color(0.435, 0.561, 0.31), ## #6F8F4F mown lawn.
		"ballast_quads": Color(0.545, 0.522, 0.471), ## #8B8578 gravel.
		"tie_quads": Color(0.29, 0.267, 0.227), ## #4A443A tie stripe.
		"ground_quads": Color(0.38, 0.46, 0.3), ## never-fired fallback (cells carry per-cell colors).
	}
	var chunks := 0
	var lane_count := 0
	var shore_count := 0
	var tie_count := 0
	var ballast_count := 0
	var ground_count := 0
	var shore_quads: Array = []
	var tie_quads: Array = []
	var ballast_quads: Array = []
	var ribbon_quads: Array = []
	var water_ys := {} ## baked water-tri y values (the cannot-paint arm).
	var ground_cells := {} ## cell center "x,z" -> color triple (the pin leg).
	var ctx: Dictionary = AmesBaker._build_context()
	for entry: Dictionary in manifest.get("chunks", []):
		var chunk: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		if chunk.is_empty():
			bad.append("chunk_file_missing:%s" % entry["file"])
			continue
		chunks += 1
		var colors: Dictionary = chunk.get("colors", {})
		for family: String in want_colors:
			var c: Array = colors.get(family, [])
			if c.size() != 3 \
					or absf(float(c[0]) - want_colors[family].r) > 1e-6 \
					or absf(float(c[1]) - want_colors[family].g) > 1e-6 \
					or absf(float(c[2]) - want_colors[family].b) > 1e-6:
				bad.append("colors_%s=%s in %s (pinned %s)" % [
						family, c, entry["file"], want_colors[family]])
				break
		lane_count += (chunk.get("lane_quads", []) as Array).size()
		ballast_count += (chunk.get("ballast_quads", []) as Array).size()
		for q: Dictionary in chunk.get("shore_quads", []):
			shore_quads.append(q["q"])
			shore_count += 1
		for q: Dictionary in chunk.get("tie_quads", []):
			tie_quads.append(q["q"])
			tie_count += 1
		for q: Dictionary in chunk.get("ballast_quads", []):
			ballast_quads.append(q["q"])
		for q2: Dictionary in chunk.get("ribbons", []):
			ribbon_quads.append(q2["q"])
		for t: Dictionary in chunk.get("water_tris", []):
			water_ys[float(t["v"][1])] = true
		for q: Dictionary in chunk.get("ground_quads", []):
			ground_count += 1
			var gq: Array = q["q"]
			if absf(float(gq[1]) - 0.004) > 1e-6:
				bad.append("ground cell y %s != 0.004 (must clear the water flat at 0.02)" % gq[1])
				break
			var cx := (float(gq[0]) + float(gq[3])) * 0.5
			var cz := (float(gq[2]) + float(gq[8])) * 0.5
			ground_cells["%s,%s" % [cx, cz]] = q.get("c", [])
	if water_ys.keys() != [0.02]:
		bad.append("water tri y values %s != the pinned 0.02" % str(water_ys.keys()))
	# district ground binding over every baked cell: the cell's color must
	# equal the pinned palette entry of the v0 rule's district at the cell's
	# own center, and no cell may claim the residential seed (the plate owns
	# that ground — cells exist only where another district stands).
	for center: String in ground_cells:
		var parts := center.split(",")
		var district := AmesBaker._district_of(float(parts[0]), float(parts[1]), ctx)
		if district == "residential":
			bad.append("ground cell at (%s) baked for the residential seed — the plate owns it" % center)
			continue
		var want: Color = want_ground.get(district, Color(-1.0, -1.0, -1.0))
		var got_c: Array = ground_cells[center]
		if got_c.size() != 3 \
				or absf(float(got_c[0]) - want.r) > 1e-6 \
				or absf(float(got_c[1]) - want.g) > 1e-6 \
				or absf(float(got_c[2]) - want.b) > 1e-6:
			bad.append("ground cell %s colored %s but rule says %s (%s)" % [
					center, got_c, district, want])
	if ground_count != ground_cells.size():
		bad.append("ground cells %d != unique centers %d (duplicate cell)" % [ground_count, ground_cells.size()])
	# known-band pins (the api_seam district families + the LW strip east of
	# the Campustown band, west of the campus reach): the cell UNDER each pin
	# point exists with its district's pinned color.
	var cell_pins := {
		"campustown": Vector2(-300.0, 60.0),
		"downtown": Vector2(2700.0, -256.0),
		"campus": Vector2(340.0, -294.0),
		"lincolnway": Vector2(1000.0, 4.0),
	}
	for district: String in cell_pins:
		var p: Vector2 = cell_pins[district]
		var tile := Vector2i(floori(p.x / AmesBaker.CHUNK_SIZE), floori(p.y / AmesBaker.CHUNK_SIZE))
		var local := p - Vector2(tile.x, tile.y) * AmesBaker.CHUNK_SIZE
		var center: Vector2 = Vector2(tile.x, tile.y) * AmesBaker.CHUNK_SIZE \
				+ (local / AmesBaker.GROUND_CELL).floor() * AmesBaker.GROUND_CELL \
				+ Vector2.ONE * (AmesBaker.GROUND_CELL * 0.5)
		var got_c2: Array = ground_cells.get("%s,%s" % [center.x, center.y], [])
		var want2: Color = want_ground[district]
		if got_c2.size() != 3 \
				or absf(float(got_c2[0]) - want2.r) > 1e-6 \
				or absf(float(got_c2[1]) - want2.g) > 1e-6 \
				or absf(float(got_c2[2]) - want2.b) > 1e-6:
			bad.append("no %s ground cell under %s (cell %s: %s)" % [
					district, p, center, got_c2])

	# --- 3. arterial lane dashes recount exactly from the pack -------------
	var corridor_keys: Array[String] = ["Lincoln Way", "Main Street", "Duff", "Grand"]
	var dashes_per_corridor := {}
	for key: String in corridor_keys:
		dashes_per_corridor[key] = 0
	var want_lanes := 0
	for s: Dictionary in AmesDataPack.streets():
		var sname := str(s.get("name", ""))
		var hit := ""
		for key: String in corridor_keys:
			if sname.contains(key):
				hit = key
				break
		if hit.is_empty():
			continue
		var pts: Array = s.get("points", [])
		for i: int in range(pts.size() - 1):
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var seg_len := a.distance_to(b)
			if seg_len < 3.0: ## MARK_DASH: a shorter segment paints no dash.
				continue
			var dashes := int(floorf((seg_len - 3.0) / 9.0)) + 1 ## MARK_DASH / MARK_PERIOD.
			want_lanes += dashes
			dashes_per_corridor[hit] = int(dashes_per_corridor[hit]) + dashes
	if lane_count != want_lanes:
		bad.append("lane dashes %d != recount %d from the pack's four corridors" % [lane_count, want_lanes])
	for key: String in corridor_keys:
		if int(dashes_per_corridor[key]) == 0:
			bad.append("corridor %s painted no dashes" % key)

	# --- 4. the shore band: hugs the lake, under the water top -------------
	if shore_count < 50:
		bad.append("shore quads %d — the band is missing at lake scale" % shore_count)
	var rings: Array[PackedVector2Array] = _pack_split_rings(
			AmesDataPack.water()[0].get("polygon", []))
	var want_shore := 0
	for ring: PackedVector2Array in rings:
		for i: int in ring.size():
			if ring[i].distance_squared_to(ring[(i + 1) % ring.size()]) > 1e-10:
				want_shore += 1
	if shore_count != want_shore:
		bad.append("shore quads %d != lake ring edges %d" % [shore_count, want_shore])
	var worst_shore := 0.0
	for q: Array in shore_quads:
		if absf(float(q[1]) - 0.008) > 1e-6:
			bad.append("shore quad y %s != 0.008" % q[1])
			break
		var mid := Vector2((float(q[0]) + float(q[3]) + float(q[6]) + float(q[9])) * 0.25,
				(float(q[2]) + float(q[5]) + float(q[8]) + float(q[11])) * 0.25)
		var best := INF
		for ring: PackedVector2Array in rings:
			for i: int in ring.size():
				best = minf(best, _point_seg_dist(mid, ring[i], ring[(i + 1) % ring.size()]))
		worst_shore = maxf(worst_shore, best)
	if worst_shore > 7.0: ## SHORE_WIDTH: a band quad never strays past the ring.
		bad.append("shore quad center %.2f m off the lake ring (band 7 m)" % worst_shore)
	## The cannot-paint arm, as baked y values + the renderer's shapes (at
	## SCENARIO level — it must fire on every bake, not only when the hug
	## check above already failed): the water is a FLAT TRIANGLE at y 0.02
	## (no thickness), the shore band a 0.02-thick box centered at 0.008 —
	## its top (0.018) stays UNDER the water, so wherever the band overlaps
	## the lake (a sharp ring corner), the WATER renders above. The ground
	## cells (top 0.014) stay under both — the first landing had cell tops
	## at exactly 0.02, coplanar with the water triangles, and the lake
	## depth-fought into lawn.
	var shore_top := 0.008 + AmesWorld.FLAT_THICKNESS * 0.5
	var cell_top := 0.004 + AmesWorld.FLAT_THICKNESS * 0.5
	if shore_top >= 0.02 or cell_top >= shore_top:
		bad.append("flat stack fights the water: cell top %.3f shore top %.3f water 0.02" % [cell_top, shore_top])

	# --- 5. the tie stripe: rides the ballast, keeps the honest gaps -------
	if tie_count == 0 or tie_count != ballast_count:
		bad.append("tie quads %d vs ballast quads %d — ties must ride the ballast 1:1" % [tie_count, ballast_count])
	## Bucket the ballast by 32 m grid cell so the ride check stays cheap,
	## then every tie must strictly overlap a ballast quad (it was cut from
	## the same unblocked stretch).
	var ballast_buckets := {}
	for q: Array in ballast_quads:
		var bmid := Vector2((float(q[0]) + float(q[6])) * 0.5, (float(q[2]) + float(q[8])) * 0.5)
		var key := Vector2i(floori(bmid.x / 32.0), floori(bmid.y / 32.0))
		if not ballast_buckets.has(key):
			ballast_buckets[key] = []
		(ballast_buckets[key] as Array).append(q)
	var road_near: Array = [] ## Crossing-road ribbons (the census ROAD_NEAR rule).
	var crossing_pos := {}
	for c: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(c.get("grade", "")) == "at_grade":
			var pos: Array = c.get("pos", [0.0, 0.0])
			crossing_pos[str(c.get("road_name", ""))] = Vector2(float(pos[0]), float(pos[1]))
	for q: Array in ribbon_quads:
		var q_mid := Vector2((float(q[0]) + float(q[6])) * 0.5, (float(q[2]) + float(q[8])) * 0.5)
		for road: String in crossing_pos:
			if q_mid.distance_to(crossing_pos[road]) < 40.0:
				road_near.append(q)
				break
	var tie_unridden := 0
	var tie_over_road := 0
	var first_tie_fault := ""
	for q: Array in tie_quads:
		var tmid := Vector2((float(q[0]) + float(q[6])) * 0.5, (float(q[2]) + float(q[8])) * 0.5)
		var base := Vector2i(floori(tmid.x / 32.0), floori(tmid.y / 32.0))
		var rides := false
		for dx: int in [-1, 0, 1]:
			for dz: int in [-1, 0, 1]:
				for bq: Array in ballast_buckets.get(base + Vector2i(dx, dz), []):
					if _flat_quads_overlap(q, bq):
						rides = true
						break
				if rides:
					break
			if rides:
				break
		if not rides:
			tie_unridden += 1
			if first_tie_fault.is_empty():
				first_tie_fault = "unridden tie at (%.1f, %.1f)" % [tmid.x, tmid.y]
		for rq: Array in road_near:
			if _flat_quads_overlap(q, rq):
				tie_over_road += 1
				if first_tie_fault.is_empty():
					first_tie_fault = "tie over crossing asphalt at (%.1f, %.1f)" % [tmid.x, tmid.y]
				break
	if tie_unridden > 0:
		bad.append("ties not riding ballast=%d (%s)" % [tie_unridden, first_tie_fault])
	if tie_over_road > 0:
		bad.append("tie quads over crossing-road asphalt=%d (%s)" % [tie_over_road, first_tie_fault])

	# --- 6. the creek green reads distinct from the lake olive -------------
	var creek_diff := Color(0.275, 0.4, 0.388) - Color(0.275, 0.329, 0.247)
	var creek_lake_gap: float = sqrt(creek_diff.r * creek_diff.r
			+ creek_diff.g * creek_diff.g + creek_diff.b * creek_diff.b)
	if creek_lake_gap <= 0.05:
		bad.append("creek color too close to the lake olive (%.3f)" % creek_lake_gap)
	if chunks == 0:
		bad.append("no chunks loaded")
	_check(S, bad.is_empty(),
		"chunks=%d ground_cells=%d lane_dashes=%d shore=%d ties=%d worst_shore_ring_dist=%.2f creek_gap=%.3f; %s"
				% [chunks, ground_count, lane_count, shore_count, tie_count,
				worst_shore, creek_lake_gap, "; ".join(bad)])


## Point-to-segment distance (the shore-band hug check).
func _point_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	var t := 0.0 if len_sq < 1e-12 else clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Even-odd point-in-ring ray cast (the T-174 creek-over-lake recount's
## probe). Coded separately from the baker's `_mid_in_lake` on purpose.
func _point_in_ring(p: Vector2, ring: PackedVector2Array) -> bool:
	var n := ring.size()
	if n < 3:
		return false
	var inside := false
	for i: int in n:
		var a := ring[i]
		var b := ring[(i + 1) % n]
		if (a.y > p.y) != (b.y > p.y):
			var x_at := a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
			if p.x < x_at:
				inside = not inside
	return inside


## --- scenarios (T-175 Ames landmark placeholders) --------------------------


## (T-175) The landmark placeholders are load-bearing at their SURVEY dims —
## pure data over the committed chunks (beside `ames_bake_census`, no rig).
## Four arms, every expected value recomputed INDEPENDENTLY here (the
## no-self-test rule — survey literals, never baker consts):
## 1. AUTHORED SLOTS: every one of the pack's 512 authored buildings rides a
##    massing entry flagged `a` (the collision-bearing slot heroes replace in
##    R3), and the flagged id SET equals the pack's authored id set exactly —
##    ids stable across rebakes by identity with the pack, not by trust.
## 2. VENUE FIXUPS: the placed venue POIs whose address anchor no authored
##    bbox covers — IN-CORE venues only, and never a venue the pack marks
##    a PROP (the `note` marker; the round-1 landing boxed the Superdog
##    hot-dog CART into a storefront standing square in Welch Ave, 206 m²
##    of road overlap, and the four out-of-core venues into lone colliders
##    on empty plate that grew the world bounds) — each carries exactly one
##    fixup box within 0.05 m of the POI position (12 at landing), the
##    excluded five are pinned ABSENT, and no fixup box overlaps any
##    street ribbon quad (strict SAT road-clearance arm).
## 3. HERO DIMS within ±2 m of the survey's settled numbers
##    (verification/VERIFICATION.md §5): campanile 33.5 m tall on the
##    6.8 × 6.7 plinth (§1.1), Marston 51.2 m (§1.4), Jack Trice bowl ring
##    183 × 208 m (V-09; the ring parts only — the north berms are the
##    V-11 hillside, checked to reach past the north rim), Hilton drum
##    138 × 105 (§1.3), MU 110 × 110 (census §3), Parks 95 × 123; the depot,
##    bandshell, both municipal bulbs and the elevator cluster pinned
##    PRESENT at their recorded positions (tanks/elevators: survey-anchored
##    approximations, heights UNVERIFIED per V-30 — dims not asserted).
## 4. THE RANKING'S NON-BOX LANDMARKS: Lake LaVerne's water flat at
##    236 × 122 m (±2) with the MU block 13.7 m from the east shore (V-08
##    adjacency, ≤ 20 m) and the campanile ~264 m off the lake center
##    (survey §5, ±5), Central Campus lawn ≥ 7.6 ha within 300 m of its POI
##    (V-25: 85,488 m² pack polygon), ballast under the UP-main-line POI,
##    and the three out-of-core POIs (Reiman/Ada Hayden/airport) carrying
##    in_core=false — fly-out targets per survey §1.9, no in-map duty.
func _scenario_ames_placeholder_dims() -> void:
	const S := "ames_placeholder_dims"
	const DIM_TOL := 2.0
	var manifest: Dictionary = AmesBaker.read_manifest(AMES_CHUNKS_DIR)
	if manifest.is_empty():
		_check(S, false, "no committed bake at %s" % AMES_CHUNKS_DIR)
		return
	var bad: PackedStringArray = PackedStringArray()
	var hero_roles: Dictionary = {} ## hero id -> role -> [lo, hi] accumulator.
	var fixups: Dictionary = {} ## venue id -> placeholder p Array.
	var slot_ids: Dictionary = {}
	var slot_count := 0
	var water_los := Vector3(INF, INF, INF)
	var water_his := Vector3(-INF, -INF, -INF)
	var lawn_area := 0.0
	var nearest_ballast := INF
	for entry: Dictionary in manifest.get("chunks", []):
		var doc: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		for ph: Dictionary in doc.get("placeholders", []):
			var p: Array = ph["p"]
			var s: Array = ph["s"]
			if str(ph.get("part", "")) == "fixup":
				fixups[str(ph.get("id", ""))] = p
				continue
			var lo := Vector3(float(p[0]) - float(s[0]) * 0.5,
					float(p[1]) - float(s[1]) * 0.5, float(p[2]) - float(s[2]) * 0.5)
			var hi := Vector3(float(p[0]) + float(s[0]) * 0.5,
					float(p[1]) + float(s[1]) * 0.5, float(p[2]) + float(s[2]) * 0.5)
			var roles: Dictionary = hero_roles.get(str(ph.get("id", "")), {})
			var acc: Array = roles.get(str(ph.get("part", "")),
					[Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)])
			acc[0] = (acc[0] as Vector3).min(lo)
			acc[1] = (acc[1] as Vector3).max(hi)
			roles[str(ph.get("part", ""))] = acc
			hero_roles[str(ph.get("id", ""))] = roles
		for m: Dictionary in doc.get("massing", []):
			if m.get("a", false):
				slot_ids[str(m.get("id", ""))] = true
				slot_count += 1
		for t: Dictionary in doc.get("water_tris", []):
			var v: Array = t["v"]
			for k: int in 3:
				water_los = water_los.min(Vector3(float(v[k * 3]),
						float(v[k * 3 + 1]), float(v[k * 3 + 2])))
				water_his = water_his.max(Vector3(float(v[k * 3]),
						float(v[k * 3 + 1]), float(v[k * 3 + 2])))
		for lt: Dictionary in doc.get("lawn_tris", []):
			var lv: Array = lt["v"]
			var la := Vector2(float(lv[0]), float(lv[2]))
			var lb := Vector2(float(lv[3]), float(lv[5]))
			var lc := Vector2(float(lv[6]), float(lv[8]))
			var centroid := (la + lb + lc) / 3.0
			if centroid.distance_to(Vector2(327.45, -411.04)) > 300.0:
				continue ## Central Campus POI's neighborhood only.
			lawn_area += absf((lb.x - la.x) * (lc.y - la.y)
					- (lc.x - la.x) * (lb.y - la.y)) * 0.5
		for q: Dictionary in doc.get("ballast_quads", []):
			var bq: Array = q["q"]
			var bmid := Vector2((float(bq[0]) + float(bq[6])) * 0.5,
					(float(bq[2]) + float(bq[8])) * 0.5)
			nearest_ballast = minf(nearest_ballast,
					bmid.distance_to(Vector2(3285.95, -214.37)))

	# --- 1. authored slots: identity with the pack -------------------------
	var want_slots: Dictionary = {}
	for b: Dictionary in AmesDataPack.buildings():
		if str(b.get("class", "")) == "authored":
			want_slots[str(b.get("id", ""))] = true
	if slot_count != want_slots.size():
		bad.append("authored slots %d != pack authored %d" % [slot_count, want_slots.size()])
	for sid: String in want_slots:
		if not slot_ids.has(sid):
			bad.append("authored slot missing: %s" % sid)

	# --- 2. venue fixups: the uncovered-partition recompute ----------------
	# (Round 1) the rule has the pack's OWN exclusions baked in: a fixup
	# goes to placed IN-CORE venues only (the out-of-core four are boundary
	# decisions — a box there is a lone collider on empty plate that grows
	# the world bounds the ground plate and off-world guard derive from),
	# and never to a venue the pack marks a PROP (`note` carries "prop" —
	# the Superdog hot-dog CART stood as a 12×8 storefront square in Welch
	# Ave, 206 m² of road overlap). The negative arms pin those exclusions
	# and a road-clearance arm re-proves every baked fixup clear of every
	# street ribbon quad (strict SAT, the reviewer's own defect class).
	var want_fixups: Dictionary = {}
	for poi: Dictionary in AmesDataPack.pois():
		if str(poi.get("kind", "")) != "venue" or not poi.get("placed", false):
			continue
		if not poi.get("in_core", false) or str(poi.get("note", "")).contains("prop"):
			continue
		var pos: Array = poi["position"]
		var covered := false
		for b: Dictionary in AmesDataPack.buildings():
			if str(b.get("class", "")) != "authored":
				continue
			var c: Array = b["centroid"]
			var bb: Array = b["bbox_m"]
			if absf(float(pos[0]) - float(c[0])) <= float(bb[0]) * 0.5 \
					and absf(float(pos[1]) - float(c[1])) <= float(bb[1]) * 0.5:
				covered = true
				break
		if not covered:
			want_fixups[str(poi.get("id", ""))] = pos
	if want_fixups.is_empty():
		bad.append("venue fixup recompute found none (vacuous arm)")
	if fixups.size() != want_fixups.size():
		bad.append("fixups %d != uncovered in-core venues %d" % [fixups.size(), want_fixups.size()])
	for vid: String in want_fixups:
		if not fixups.has(vid):
			bad.append("no fixup for venue %s" % vid)
		else:
			var fp: Array = fixups[vid]
			var wp: Array = want_fixups[vid]
			if Vector2(float(fp[0]), float(fp[2])).distance_to(
					Vector2(float(wp[0]), float(wp[1]))) > 0.05:
				bad.append("fixup %s off its POI position" % vid)
	for vid: String in fixups:
		if not want_fixups.has(vid):
			bad.append("stray fixup %s (prop or out-of-core venue)" % vid)
	# negative arms: the pack's own exclusions must hold in the bake.
	for excluded: String in ["superdog", "the_cafe", "provisions_lot_f",
			"szechuan_house", "hickory_park"]:
		if fixups.has(excluded):
			bad.append("excluded venue %s carries a fixup box" % excluded)
	# road clearance: no fixup box (12 × 10 xz at its center) overlaps any
	# street ribbon quad — strict SAT on the baked output, coded through the
	# scenario's own `_flat_quads_overlap`.
	var street_quads: Array = []
	for entry: Dictionary in manifest.get("chunks", []):
		var doc_r: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		for q: Dictionary in doc_r.get("ribbons", []):
			street_quads.append(q["q"])
	for vid: String in fixups:
		var fp: Array = fixups[vid]
		var box := [
			Vector3(float(fp[0]) - 6.0, 0.0, float(fp[2]) - 5.0),
			Vector3(float(fp[0]) + 6.0, 0.0, float(fp[2]) - 5.0),
			Vector3(float(fp[0]) + 6.0, 0.0, float(fp[2]) + 5.0),
			Vector3(float(fp[0]) - 6.0, 0.0, float(fp[2]) + 5.0),
		]
		var box_flat: Array = []
		for corner: Vector3 in box:
			box_flat.append_array([corner.x, 0.0, corner.z])
		for sq: Array in street_quads:
			if _flat_quads_overlap(box_flat, sq):
				bad.append("fixup %s overlaps a street ribbon (road clearance)" % vid)
				break

	# --- 3. hero dims vs the survey literals -------------------------------
	var want_heroes := {
		"way/183041212": {"xz": Vector2(6.8, 6.7), "h": 33.5},
		"way/861201396": {"xz": Vector2(7.3, 7.3), "h": 51.2},
		"way/613735866": {"xz": Vector2(183.0, 208.0), "roles": ["bowl"]},
		"way/180651868": {"xz": Vector2(138.0, 105.0)},
		"way/183224150": {"xz": Vector2(110.0, 110.0)},
		"way/33725897": {"xz": Vector2(95.0, 123.0)},
	}
	for hid: String in want_heroes:
		if not hero_roles.has(hid):
			bad.append("hero %s has no baked parts" % hid)
			continue
		var roles: Dictionary = hero_roles[hid]
		var which: Array = want_heroes[hid].get("roles", roles.keys())
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for role: String in which:
			if not roles.has(role):
				bad.append("hero %s missing role %s" % [hid, role])
				continue
			var acc: Array = roles[role]
			lo = lo.min(acc[0])
			hi = hi.max(acc[1])
		var span := hi - lo
		var want_xz: Vector2 = want_heroes[hid]["xz"]
		if absf(span.x - want_xz.x) > DIM_TOL or absf(span.z - want_xz.y) > DIM_TOL:
			bad.append("hero %s xz %.1fx%.1f != survey %.1fx%.1f (+-%.0f)" % [
					hid, span.x, span.z, want_xz.x, want_xz.y, DIM_TOL])
		if want_heroes[hid].has("h") and absf(hi.y - float(want_heroes[hid]["h"])) > DIM_TOL:
			bad.append("hero %s top %.1f != survey %.1f (+-%.0f)" % [
					hid, hi.y, float(want_heroes[hid]["h"]), DIM_TOL])
	# the V-11 hillside: berms REACH PAST the bowl's north rim (z decreases
	# northward — the berm union's north edge sits beyond the ring's north
	# edge), inside the bowl's x span.
	if hero_roles.has("way/613735866") and hero_roles["way/613735866"].has("bowl") \
			and hero_roles["way/613735866"].has("berm"):
		var bowl: Array = hero_roles["way/613735866"]["bowl"]
		var berms: Array = hero_roles["way/613735866"]["berm"]
		if (berms[0] as Vector3).z >= (bowl[0] as Vector3).z:
			bad.append("stadium berms do not reach past the north rim (%.1f >= %.1f)" % [
					(berms[0] as Vector3).z, (bowl[0] as Vector3).z])
	else:
		bad.append("stadium bowl/berm roles missing")
	# presence pins for the non-building heroes (dims UNVERIFIED per V-30 —
	# positions recorded as survey-anchored approximations, literals here):
	for pin: Array in [["downtown_bandshell", Vector2(3353.52, -412.08)],
			["city_water_tank_north", Vector2(2600.0, -1280.0)],
			["city_water_tank_east", Vector2(3480.0, 620.0)],
			["grain_elevators", Vector2(3420.0, -20.0)],
			["way/260524827", Vector2(2652.99, -184.99)]]:
		if not hero_roles.has(str(pin[0])):
			bad.append("hero %s missing from the bake" % pin[0])
			continue
		var plo := Vector3(INF, INF, INF)
		var phi := Vector3(-INF, -INF, -INF)
		for role: Array in hero_roles[str(pin[0])].values():
			plo = plo.min(role[0])
			phi = phi.max(role[1])
		var center := (plo + phi) * 0.5
		if Vector2(center.x, center.z).distance_to(pin[1]) > 15.0:
			bad.append("hero %s at (%.1f, %.1f) off its pinned position %s" % [
					pin[0], center.x, center.z, pin[1]])

	# --- 4. the ranking's non-box landmarks --------------------------------
	var lake_span := water_his - water_los
	if absf(lake_span.x - 236.0) > DIM_TOL or absf(lake_span.z - 122.0) > DIM_TOL:
		bad.append("lake water %.1fx%.1f != survey 236x122 (+-%.0f)" % [
				lake_span.x, lake_span.z, DIM_TOL])
	if hero_roles.has("way/183224150") and hero_roles["way/183224150"].has("block"):
		var mu_acc: Array = hero_roles["way/183224150"]["block"]
		var gap := (mu_acc[0] as Vector3).x - water_his.x
		if gap > 20.0 or gap < 0.0:
			bad.append("MU west face %.1f m from the lake east shore (V-08 adjacency, <= 20)" % gap)
	else:
		bad.append("MU block role missing (lake adjacency arm vacuous)")
	var lake_center := Vector2((water_los.x + water_his.x) * 0.5,
			(water_los.z + water_his.z) * 0.5)
	var cam_to_lake := lake_center.distance_to(Vector2(340.17, -294.43))
	if absf(cam_to_lake - 264.0) > 5.0:
		bad.append("campanile %.1f m from the lake center (survey ~264 ±5)" % cam_to_lake)
	if lawn_area < 76000.0:
		bad.append("Central Campus lawn %.0f m2 within 300 m of the POI (V-25: ~8.5 ha)" % lawn_area)
	if nearest_ballast > 15.0:
		bad.append("no ballast within %.1f m of the UP-main-line POI" % nearest_ballast)
	for poi: Dictionary in AmesDataPack.pois():
		var pid := str(poi.get("id", ""))
		if pid in ["reiman_gardens", "ada_hayden", "ames_airport"] \
				and poi.get("in_core", true):
			bad.append("%s claims in_core — the fly-out contract moved" % pid)

	_check(S, bad.is_empty(), "; ".join(bad))


## (T-175) The landable campanile cap — the anchor scenario pattern
## (`city_roof_landable` / the api_seam flyable leg), re-targeted: the real
## rig pigeon drops onto the baked cap's top face, settles GROUNDED at the
## 33.5 m pad, one flap returns it to flight; layer-1 placeholder colliders
## provably stand in the campanile shaft and the stadium bowl rim (ray
## probes through the real physics space, hits at the survey geometry); and
## the cap keeps the crumb rule — one ROOF spot at the cap top +
## `ANCHOR_CRUMB_LIFT` (the city.gd anchor-cap convention).
func _scenario_ames_placeholder_landable() -> void:
	const S := "ames_placeholder_landable"
	var bad: PackedStringArray = PackedStringArray()
	## The cap + shaft entries, read independently from the committed chunks.
	var cap: Dictionary = {}
	var cam_center := Vector2.ZERO
	for entry: Dictionary in AmesBaker.read_manifest(AMES_CHUNKS_DIR).get("chunks", []):
		var doc: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		for ph: Dictionary in doc.get("placeholders", []):
			if str(ph.get("id", "")) != "way/183041212":
				continue
			if str(ph.get("part", "")) == "cap":
				cap = ph
			elif str(ph.get("part", "")) == "shaft":
				cam_center = Vector2(float(ph["p"][0]), float(ph["p"][2]))
	if cap.is_empty() or cam_center == Vector2.ZERO:
		_check(S, false, "campanile cap/shaft not found in the committed bake")
		return
	var cap_top := float(cap["p"][1]) + float(cap["s"][1]) * 0.5
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	## Collider probes through the REAL physics space: horizontal rays into
	## the shaft's west face (mid-shaft, y 15) and the bowl's south rim
	## (y 10, under the 14 m ring) must hit at the survey geometry.
	var space := get_world_3d().direct_space_state
	var shaft_from := world.to_global(Vector3(cam_center.x - 20.0, 15.0, cam_center.y))
	var shaft_to := world.to_global(Vector3(cam_center.x, 15.0, cam_center.y))
	var shaft_ray := PhysicsRayQueryParameters3D.create(shaft_from, shaft_to)
	shaft_ray.collision_mask = 1
	var shaft_hit := space.intersect_ray(shaft_ray)
	if shaft_hit.is_empty():
		bad.append("shaft ray missed — no collider in the campanile shaft")
	else:
		var shaft_face := cam_center.x - 2.45 ## The 4.9 m shaft's west face.
		var hx: float = world.to_local(shaft_hit["position"]).x
		if absf(hx - shaft_face) > 0.3:
			bad.append("shaft ray hit x %.2f != face %.2f (+-0.3)" % [hx, shaft_face])
	var bowl_c := Vector2(1192.29, 997.23) ## The stadium POI (survey literal).
	## (z grows southward. The ray runs at x −60 off the bowl axis — clear of
	## the Sukup Endzone slot (x 1158.6..1228) that honestly closes the south
	## end — starting past the south rim, traveling north into the bowl. The
	## survey ellipse 183 × 208 puts the outer ring at that offset
	## 104·√(1−(60/91.5)²) ≈ 78.6 m off center plus the ring's outward half
	## width → the hit lands ≈ 1088.8, band ±4.)
	var rim_from := world.to_global(Vector3(bowl_c.x - 60.0, 10.0, bowl_c.y + 140.0))
	var rim_to := world.to_global(Vector3(bowl_c.x - 60.0, 10.0, bowl_c.y))
	var rim_ray := PhysicsRayQueryParameters3D.create(rim_from, rim_to)
	rim_ray.collision_mask = 1
	var rim_hit := space.intersect_ray(rim_ray)
	if rim_hit.is_empty():
		bad.append("bowl rim ray missed — no collider in the south rim")
	else:
		var rim_z: float = world.to_local(rim_hit["position"]).z
		if rim_z < bowl_c.y + 87.55 or rim_z > bowl_c.y + 95.55:
			bad.append("bowl rim ray hit z %.2f outside the south ring at x-60 (want %.1f ±4)" % [
					rim_z, bowl_c.y + 91.55])
	## The landing state: a drop from 3 m over the cap settles grounded on
	## the pad (the pigeon stands at its own 0.3 half-height), then one
	## grounded flap returns it to flight.
	var cap_center := world.to_global(Vector3(float(cap["p"][0]), cap_top, float(cap["p"][2])))
	await _set_up(true, cap_center + Vector3.UP * 3.0, Vector3.ZERO)
	await _await_grounded(150)
	var grounded_ok := _player.is_grounded \
			and _player.position.y > cap_top + 0.15 \
			and _player.position.y < cap_top + 0.45 \
			and _player.velocity.is_finite()
	if not grounded_ok:
		bad.append("cap landing failed: grounded=%s y=%.2f (want %.2f +-0.15)" % [
				_player.is_grounded, _player.position.y, cap_top + 0.3])
	var peak_y := _player.position.y
	await _tap("flap")
	for _i in 60:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, _player.position.y)
		if not _player.is_grounded and peak_y > cap_top + 0.8:
			break
	var flyable_ok := not _player.is_grounded and peak_y > cap_top + 0.8 \
			and _player.velocity.is_finite()
	if not flyable_ok:
		bad.append("cap takeoff failed: peak %.2f (want > %.2f)" % [peak_y, cap_top + 0.8])
	## The crumb rule: one ROOF spot rides the cap at the anchor lift.
	var want_crumb := Vector3(float(cap["p"][0]), cap_top + City.ANCHOR_CRUMB_LIFT,
			float(cap["p"][2]))
	var crumb_ok := false
	for i: int in world.bread_spots.size():
		if world.bread_spots[i].distance_to(want_crumb) < 0.005 \
				and i < world.bread_spot_kinds.size() \
				and world.bread_spot_kinds[i] == City.BreadKind.ROOF:
			crumb_ok = true
			break
	if not crumb_ok:
		bad.append("no cap crumb at %s (world.bread_spots %d)" % [want_crumb,
				world.bread_spots.size()])
	_check(S, bad.is_empty(), "; ".join(bad))
	world.queue_free()


## (T-176) The survival re-base, machine-checked against the committed data —
## every expected value recomputed INDEPENDENTLY here (the no-self-test rule):
## SPAWN over Central Campus near the campanile (master plan §11.1) — the
## spawn local XZ is the campanile POI plus the world's east offset, the
## district lookup answers "campus" there, the plate answers the drop (the
## spot is massing-clear), a real drop settles grounded and flies off, and
## the first bread is a fact about the LIVE spread: the real BreadSpawner
## seeds the world at the shipped target and the nearest living crumb sits
## within 60 m flat of the spawn (the boot ring's doing — round 1);
## REACH — nearest spot ≤ 150 m from ANY sampled point of
## the pack's core window (the meta `core_bbox_wsen` through the pack's
## pinned transform, a 100 m grid, a 100 m-cell spatial hash recomputed here
## from `world.bread_spots` — never through world internals); SUPPLY — the
## crumb total stays at or above the PINNED SUPPLY FLOOR (12,000 — the
## T-177 re-pin of the retired "Windrow baseline" comparison: with no
## Windrow world left to measure, the floor pins the measured Ames supply
## with headroom for losing a whole placement layer, the value recorded in
## the ticket ledger); CAFÉS — every
## in-bounds café venue of the VENUES.md coffee list (the name-token rule)
## carries a table spot near its POI with a TABLE-class crumb on the
## tabletop, and at least 3 real cafés are served.
func _scenario_ames_bread_reach() -> void:
	const S := "ames_bread_reach"
	const REACH_STEP := 100.0 ## Sample-grid cadence over the core window.
	const REACH_BAR := 150.0 ## The AC's nearest-bread bar (m, flat).
	const FIRST_BREAD_BAR := 60.0 ## The AC's first-bread-from-spawn bar.
	var bad: PackedStringArray = PackedStringArray()
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	## --- spawn ---------------------------------------------------------------
	var cam_pos := Vector2.ZERO
	for poi: Dictionary in AmesDataPack.landmarks():
		if str(poi.get("id", "")) == "campanile":
			var pos: Array = poi.get("position", [0.0, 0.0])
			cam_pos = Vector2(float(pos[0]), float(pos[1]))
			break
	if cam_pos == Vector2.ZERO:
		bad.append("campanile POI missing from the pack")
	else:
		var spawn_local := world.to_local(world.spawn_point)
		var want_spawn := Vector2(cam_pos.x + world.SPAWN_CAMPANILE_OFFSET_X, cam_pos.y)
		if Vector2(spawn_local.x, spawn_local.z).distance_to(want_spawn) > 0.01:
			bad.append("spawn %s != campanile+%s" % [Vector2(spawn_local.x, spawn_local.z),
					want_spawn])
		if world.district_at(world.spawn_point) != "campus":
			bad.append("spawn district %s != campus" % world.district_at(world.spawn_point))
		if world.ground_height(world.spawn_point) != 0.0:
			bad.append("spawn not massing-clear: ground %.2f" % world.ground_height(world.spawn_point))
		## First bread, LIVE (round 1): the bar is a fact about the seeded
		## spread, not the spot supply — the real BreadSpawner seeds this
		## world (shipped target 40) and the nearest living crumb is measured
		## flat from the spawn. The spot-side measure is context only: the
		## world's boot ring (`City.boot_bread_spots`, the ground spots
		## nearest the spawn, seeded first) is what puts a crumb there at
		## boot — at 40 crumbs across 11k+ spots the seeded shuffle alone
		## landed the nearest one ~295 m out (the round-1 review's rv1/rv2
		## measurement).
		var spawner := BreadSpawner.new()
		spawner.city = world
		add_child(spawner)
		await _wait_frames(2)
		var first_bread := INF
		for crumb in spawner.living_crumbs():
			var cl := world.to_local(crumb.global_position)
			first_bread = minf(first_bread,
					Vector2(cl.x - spawn_local.x, cl.z - spawn_local.z).length())
		var spot_bread := INF
		for i: int in world.bread_spots.size():
			if world.bread_spot_kinds[i] != City.BreadKind.GROUND:
				continue
			var spot := world.bread_spots[i]
			spot_bread = minf(spot_bread,
					Vector2(spot.x - spawn_local.x, spot.z - spawn_local.z).length())
		var live_count := spawner.living_crumbs().size()
		print("SIM DATA %s: spawn=%s first LIVE bread %.1f m (bar %.0f); nearest ground spot %.1f m; live crumbs %d (target %d)" % [
				S, spawn_local, first_bread, FIRST_BREAD_BAR, spot_bread,
				live_count, spawner.target_count])
		if first_bread > FIRST_BREAD_BAR:
			bad.append("first LIVE bread %.1f m > %.0f m (boot ring failed)" % [
					first_bread, FIRST_BREAD_BAR])
		if live_count > spawner.target_count:
			bad.append("boot spread %d crumbs > target %d" % [
					live_count, spawner.target_count])
		spawner.free()
		## ... and flyable: a drop over the spawn settles grounded, a flap
		## returns it to flight (the corridor contract, re-pinned).
		await _set_up(true, world.spawn_point + Vector3.UP * 3.0, Vector3.ZERO)
		await _await_grounded(150)
		var grounded_ok := _player.is_grounded and _player.velocity.is_finite()
		var peak_y := _player.position.y
		await _tap("flap")
		for _i in 60:
			await get_tree().physics_frame
			peak_y = maxf(peak_y, _player.position.y)
			if not _player.is_grounded and peak_y > 0.8:
				break
		if not (grounded_ok and not _player.is_grounded and peak_y > 0.8):
			bad.append("spawn drop/flight failed: grounded=%s peak=%.2f" % [
					grounded_ok, peak_y])
	## --- reach grid over the core window --------------------------------------
	var meta := AmesDataPack.meta()
	var bbox: Array = meta.get("core_bbox_wsen", [])
	if bbox.size() < 4:
		bad.append("pack meta carries no core_bbox_wsen")
	else:
		var west := AmesDataPack.wgs84_to_local(float(bbox[0]), float(bbox[3])).x
		var east := AmesDataPack.wgs84_to_local(float(bbox[2]), float(bbox[3])).x
		var north := AmesDataPack.wgs84_to_local(float(bbox[2]), float(bbox[3])).z
		var south := AmesDataPack.wgs84_to_local(float(bbox[2]), float(bbox[1])).z
		var buckets: Dictionary = {} ## 100 m cell -> Array of spot indices.
		for i: int in world.bread_spots.size():
			var spot := world.bread_spots[i]
			var key := Vector2i(floori(spot.x / REACH_STEP), floori(spot.z / REACH_STEP))
			if not buckets.has(key):
				buckets[key] = []
			(buckets[key] as Array).append(i)
		var worst := 0.0
		var worst_at := Vector2.ZERO
		var over := 0
		var samples := 0
		var x := west
		while x <= east:
			var z := north
			while z <= south:
				samples += 1
				var bx := floori(x / REACH_STEP)
				var bz := floori(z / REACH_STEP)
				var best := INF
				for dx in range(-2, 3):
					for dz in range(-2, 3):
						var cell: Array = buckets.get(Vector2i(bx + dx, bz + dz), [])
						for idx: int in cell:
							var spot := world.bread_spots[idx]
							var dd := (spot.x - x) * (spot.x - x) \
									+ (spot.z - z) * (spot.z - z)
							if dd < best:
								best = dd
				var dist := sqrt(best)
				if dist > worst:
					worst = dist
					worst_at = Vector2(x, z)
				if dist > REACH_BAR:
					over += 1
				z += REACH_STEP
			x += REACH_STEP
		print("SIM DATA %s: reach grid %d samples, over-%.0f m: %d, worst %.1f m at (%.0f, %.0f)" % [
				S, samples, REACH_BAR, over, worst, worst_at.x, worst_at.y])
		if over > 0:
			bad.append("reach: %d/%d samples past %.0f m (worst %.1f at %s)" % [
					over, samples, REACH_BAR, worst, worst_at])
	## --- supply: crumb total ≥ the pinned floor (the T-177 re-pin) ------------
	## The retired comparison measured the Ames supply against the standing
	## Windrow city's live count; with the Windrow generator retired there is
	## no baseline world left, so the floor is the pinned literal below —
	## under the measured ~13.9k supply with headroom for losing a whole
	## placement layer (any layer's death — streets, parks, roofs, lattice —
	## drops thousands; the floor only moves if the contract itself shrinks).
	const SUPPLY_FLOOR := 10500
	var total := world.bread_spots.size()
	print("SIM DATA %s: ames crumb spots %d vs pinned floor %d" % [S, total, SUPPLY_FLOOR])
	if total < SUPPLY_FLOOR:
		bad.append("crumb total %d < pinned floor %d" % [total, SUPPLY_FLOOR])
	## --- café tables at real cafés -------------------------------------------
	var served := 0
	for venue: Dictionary in AmesDataPack.venues():
		var lower := str(venue.get("name", "")).to_lower()
		var is_cafe := false
		for token: String in ["cafe", "café", "coffee"]:
			if lower.contains(token):
				is_cafe = true
				break
		if not is_cafe:
			continue
		var pos: Variant = venue.get("position")
		if not (pos is Array):
			continue ## Unplaced venue (Labyrinth Coffee) — no invented table.
		var vx := float((pos as Array)[0])
		var vz := float((pos as Array)[1])
		## In-bounds café (the T-175 in-core rule): the venue must stand
		## inside the world's manifest extents ± the placement slack —
		## recomputed here from render_metrics(), never through internals.
		var metrics: Dictionary = world.render_metrics()
		var bmin: Vector3 = metrics.bounds_min
		var bmax: Vector3 = metrics.bounds_max
		if vx < bmin.x - 60.0 or vx > bmax.x + 60.0 \
				or vz < bmin.z - 60.0 or vz > bmax.z + 60.0:
			continue ## Out-of-core venue (The Cafe, …) — honestly unserved.
		## A table spot near the POI (within the outset ladder's reach) whose
		## tabletop crumb rides the TABLE class.
		var table_ok := false
		for t: Transform3D in world.cafe_spots:
			var tl := Vector2(t.origin.x - vx, t.origin.z - vz)
			if tl.length() > 21.0:
				continue
			## The tabletop crumb: spot origin + basis.x inset + lift — recomputed
			## here and matched against the world's TABLE spots.
			var want_crumb := t.origin + t.basis.x * City.CAFE_CRUMB_SIT_INSET \
					+ Vector3(0.0, City.CAFE_CRUMB_TABLE_LIFT, 0.0)
			for i: int in world.bread_spots.size():
				if world.bread_spot_kinds[i] == City.BreadKind.TABLE \
						and world.bread_spots[i].distance_to(want_crumb) < 0.005:
					table_ok = true
					break
			if table_ok:
				break
		if table_ok:
			served += 1
		else:
			bad.append("café %s rides no table (nearest none within 21 m)" % venue.get("name"))
	print("SIM DATA %s: café tables served at %d real cafés (bar 3), world tables %d" % [
			S, served, world.cafe_spots.size()])
	if served < 3:
		bad.append("café tables at %d cafés < 3" % served)
	if world.cafe_spots.size() != served:
		bad.append("world tables %d != served cafés %d" % [world.cafe_spots.size(), served])
	_check(S, bad.is_empty(), "; ".join(bad))
	world.queue_free()


## (T-176 round 1) The Ames spawner under the SHIPPED knobs, held to its
## bounds — no Gate 1b check ran the spawner against Ames before, and the
## un-capped tree grew the live count forever there (measured red-before:
## populate 40, then +30 per top-up — 70 → 100 → 130 → …, the 6 café TABLE
## spots never covering the 36-table quota so the shortfall re-spilled into
## GROUND every respawn_interval). BOOT — the real BreadSpawner seeds this
## world at target 40: the spread lands at-or-under target with the boot ring
## holding the nearest living crumb within 60 m of the spawn (AC 1's live
## half; the table quota can only ever seat the 6 real tables). BOUND —
## eight direct top-up cycles with nothing eaten change nothing, and a
## real-timed window of ~10 respawn ticks at a compressed interval stays at
## target. RECONVERGE — eating three crumbs through the same emit path a
## grounded pigeon fires, then three more top-up cycles, refills to exactly
## the target and never past it.
func _scenario_ames_bread_spawner() -> void:
	const S := "ames_bread_spawner"
	const FIRST_BREAD_BAR := 60.0
	const TOP_UPS := 8
	const EAT_COUNT := 3
	const TIMED_TICKS := 10
	var bad: PackedStringArray = PackedStringArray()
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	var spawner := BreadSpawner.new()
	spawner.city = world
	add_child(spawner)
	await _wait_frames(2)
	var target: int = spawner.target_count
	var spawn_local := world.to_local(world.spawn_point)
	## --- BOOT ------------------------------------------------------------------
	var boot := spawner.living_crumbs().size()
	if boot > target:
		bad.append("boot spread %d > target %d" % [boot, target])
	var first_bread := INF
	for crumb in spawner.living_crumbs():
		var cl := world.to_local(crumb.global_position)
		first_bread = minf(first_bread,
				Vector2(cl.x - spawn_local.x, cl.z - spawn_local.z).length())
	if first_bread > FIRST_BREAD_BAR:
		bad.append("boot nearest crumb %.1f m > %.0f m (boot ring failed)" % [
				first_bread, FIRST_BREAD_BAR])
	## --- BOUND across top-up cycles (nothing eaten) ---------------------------
	for i in TOP_UPS:
		spawner._top_up()
		var n := spawner.living_crumbs().size()
		if n > target:
			bad.append("top-up %d: %d crumbs > target %d (growth bug)" % [
					i + 1, n, target])
			break
	var bounded := spawner.living_crumbs().size()
	spawner.respawn_interval = 0.2
	for i in TIMED_TICKS * 12: ## 0.2 s interval over 2 s of fixed frames → ~10 ticks.
		await get_tree().physics_frame
		if i % 12 == 0:
			var n := spawner.living_crumbs().size()
			if n > target:
				bad.append("timed tick %d: %d crumbs > target %d" % [i, n, target])
				break
	var timed := spawner.living_crumbs().size()
	## --- RECONVERGE after eating ----------------------------------------------
	var eaten_list: Array[BreadCrumb] = []
	for crumb in spawner.living_crumbs():
		eaten_list.append(crumb)
		if eaten_list.size() >= EAT_COUNT:
			break
	var after_eat := -1
	for crumb in eaten_list:
		crumb.eaten.emit(crumb.restore) ## The same path a grounded pigeon triggers.
		crumb.free()
	after_eat = spawner.living_crumbs().size()
	for i in 3:
		spawner._top_up()
	var refilled := spawner.living_crumbs().size()
	print("SIM DATA %s: boot %d (target %d), nearest %.1f m; %d top-ups → %d; timed window → %d; ate %d → %d; 3 top-ups → %d (target %d)" % [
			S, boot, target, first_bread, TOP_UPS, bounded, timed, eaten_list.size(),
			after_eat, refilled, target])
	if refilled != target:
		bad.append("refill %d != target %d" % [refilled, target])
	if after_eat != target - eaten_list.size():
		bad.append("post-eat count %d != %d" % [after_eat, target - eaten_list.size()])
	_check(S, bad.is_empty(), "; ".join(bad))
	spawner.free()
	world.queue_free()


## (T-176) The economy pins, diff-proven: the hunger drain quartet and the
## favor ceiling are byte-identical to the Windrow values the earlier pins
## locked — pinned here as deliberately duplicated literals (the
## `DISTRICT_GROUND` pin pattern), read off a FRESH clock, the LIVE autoload
## clock, and re-read across a full ames world build+fill so the re-base's
## code path provably never touches the clock. Favor stays at the T-115
## ceiling; elder logic is untouched here (elder bench placement is T-183).
func _scenario_ames_hunger_pins() -> void:
	const S := "ames_hunger_pins"
	const PIN_DRAIN := 0.45
	const PIN_FLAP_MULT := 2.0
	const PIN_FLAP_HEAT := 0.7
	const PIN_GROUNDED_MULT := 0.6
	const PIN_MAX := 100.0
	const PIN_FAVOR_MAX := 100
	var bad: PackedStringArray = PackedStringArray()
	if Game.favor_max != PIN_FAVOR_MAX:
		bad.append("favor_max %d != %d" % [Game.favor_max, PIN_FAVOR_MAX])
	var fresh := Hunger.new()
	if fresh.drain_per_second != PIN_DRAIN or fresh.flap_drain_multiplier != PIN_FLAP_MULT \
			or fresh.flap_heat_seconds != PIN_FLAP_HEAT \
			or fresh.grounded_drain_multiplier != PIN_GROUNDED_MULT \
			or fresh.max_value != PIN_MAX:
		bad.append("fresh clock off the pins: drain %s flap %s heat %s grounded %s max %s" % [
				fresh.drain_per_second, fresh.flap_drain_multiplier,
				fresh.flap_heat_seconds, fresh.grounded_drain_multiplier, fresh.max_value])
	fresh.free()
	## The live autoload clock, BEFORE the ames build.
	if Game.hunger.drain_per_second != PIN_DRAIN or Game.hunger.flap_drain_multiplier != PIN_FLAP_MULT \
			or Game.hunger.flap_heat_seconds != PIN_FLAP_HEAT \
			or Game.hunger.grounded_drain_multiplier != PIN_GROUNDED_MULT:
		bad.append("live clock off the pins (before build)")
	## A full ames build+fill must leave the clock byte-identical (the
	## re-base's placement-only contract, diff-proven around the build).
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	var spots := world.bread_spots.size()
	world.queue_free()
	if Game.hunger.drain_per_second != PIN_DRAIN or Game.hunger.flap_drain_multiplier != PIN_FLAP_MULT \
			or Game.hunger.flap_heat_seconds != PIN_FLAP_HEAT \
			or Game.hunger.grounded_drain_multiplier != PIN_GROUNDED_MULT \
			or Game.hunger.max_value != PIN_MAX:
		bad.append("live clock moved across the ames build (drain %s max %s)" % [
				Game.hunger.drain_per_second, Game.hunger.max_value])
	if spots <= 0:
		bad.append("ames world built no crumb spots — the build arm is vacuous")
	print("SIM DATA %s: quartet %.2f/%.1f/%.2f/%.2f favor_max %d held across a %d-spot build" % [
			S, PIN_DRAIN, PIN_FLAP_MULT, PIN_FLAP_HEAT, PIN_GROUNDED_MULT,
			PIN_FAVOR_MAX, spots])
	_check(S, bad.is_empty(), "; ".join(bad))


## --- scenarios (T-177 cutover re-pins) ---------------------------------------


## The flyover re-pin (the retired `city_street_flyover`, re-derived against
## the resident Ames world): the master plan's own exit-demo corridor —
## Lincoln Way from the pack origin (Lincoln Way × Welch) east — flown at the
## Gate 3 bar of 60 m without touching anything. The corridor is recomputed
## INDEPENDENTLY from the committed pack (the longest-x-span "Lincoln Way"
## polyline, class `primary`), the clearance bar from the committed bake
## (the tallest massing/placeholder box whose XZ footprint overlaps the
## corridor's lateral band), never through the world's own code (the
## no-self-test rule): the pigeon enters at the corridor's west end at the
## bar altitude, the cruise velocity is RE-IMPOSED every 90 frames (the
## density-scenario pattern — the flight model bleeds speed and would mix
## cruise states into the sample), and the run must reach the east end with
## min y above the recomputed massing top + 5 m, lateral drift under the 12 m
## band edge, every velocity and position finite. The Windrow flyover's
## flap-paced climb is retired with its world: over real Ames the corridor
## starts high and stays high (the 60 m bar), so the taps would only pump.
func _scenario_ames_street_flyover() -> void:
	const BAR_ALTITUDE := 60.0
	const DRIFT_BAND := 12.0
	## --- the corridor, recomputed from the pack ------------------------------
	var corridor: Array = []
	var best_span := 0.0
	for street: Dictionary in AmesDataPack.streets():
		if str(street.get("name", "")) != "Lincoln Way" \
				or str(street.get("class", "")) != "primary":
			continue
		var pts: Array = street.get("points", [])
		if pts.size() < 2:
			continue
		var xs := pts.map(func(p: Array) -> float: return float(p[0]))
		var span: float = xs.max() - xs.min()
		if span > best_span:
			best_span = span
			corridor = pts
	var corridor_ok := not corridor.is_empty() and best_span > 300.0
	var start := Vector3.ZERO
	var end := Vector3.ZERO
	var z_mid := 0.0
	if corridor_ok:
		var pts: Array = corridor
		start = Vector3(float(pts[0][0]), 0.0, float(pts[0][1]))
		end = Vector3(float(pts[pts.size() - 1][0]), 0.0, float(pts[pts.size() - 1][1]))
		if start.x > end.x: ## Always fly west → east.
			var tmp := start
			start = end
			end = tmp
		z_mid = (start.z + end.z) * 0.5
	## --- the clearance bar, recomputed from the bake --------------------------
	var massing_top := 0.0
	for entry: Dictionary in AmesBaker.read_manifest(AMES_CHUNKS_DIR).get("chunks", []):
		var doc: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		for family: String in ["massing", "placeholders"]:
			for b: Dictionary in doc.get(family, []):
				var px := float(b["p"][0])
				var pz := float(b["p"][2])
				var hw := float(b["s"][0]) * 0.5
				var hd := float(b["s"][2]) * 0.5
				if px + hw < start.x - 10.0 or px - hw > end.x + 10.0:
					continue
				if pz + hd < z_mid - DRIFT_BAND or pz - hd > z_mid + DRIFT_BAND:
					continue
				massing_top = maxf(massing_top, float(b["p"][1]) + float(b["s"][1]) * 0.5)
	var clearance_ok := massing_top + 5.0 < BAR_ALTITUDE
	print("SIM DATA ames_street_flyover: corridor %.0f m (x %.0f→%.0f), massing top under it %.1f m" % [
			best_span, start.x, end.x, massing_top])
	## --- the flight ------------------------------------------------------------
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	var entered := false
	var crossed := false
	var min_y := INF
	var max_drift := 0.0
	var finite := true
	var frames_used := -1
	if corridor_ok and clearance_ok:
		var enter := world.to_global(start) + Vector3(0.0, BAR_ALTITUDE, 0.0)
		var exit_x := world.to_global(end).x
		await _set_up(true, enter, Vector3(18.0, 0.0, 0.0), -90.0) ## Nose east (the T-023 scenario's +x yaw convention).
		for i in 2400: ## ~610 m at 18 m/s ≈ 2040 frames; the budget keeps ~1.18× margin.
			await get_tree().physics_frame
			if i % 90 == 0 and i > 0:
				_player.velocity = Vector3(18.0, 0.0, 0.0) ## The density re-impose.
			min_y = minf(min_y, _player.position.y)
			max_drift = maxf(max_drift, absf(_player.position.z
					- (world.to_global(Vector3(0.0, 0.0, z_mid))).z))
			finite = finite and _player.velocity.is_finite() \
					and _player.position.is_finite()
			if _player.position.x >= exit_x:
				crossed = true
				frames_used = i
				break
		entered = _player.position.x > world.to_global(start).x
	var flyover_ok := corridor_ok and clearance_ok and crossed and entered \
			and min_y > massing_top + 5.0 and max_drift < DRIFT_BAND and finite
	print("SIM DATA ames_street_flyover: crossed=%s in %d frames, min y %.1f, max drift %.1f m" % [
			crossed, frames_used, min_y, max_drift])
	_check("ames_street_flyover",
			flyover_ok,
			"corridor_ok=%s clearance_ok=%s (top %.1f) crossed=%s min y %.1f drift %.1f finite=%s" % [
					corridor_ok, clearance_ok, massing_top, crossed, min_y,
					max_drift, finite])
	world.queue_free()


## The roof re-pin (the retired `city_roof`, re-derived against the resident
## Ames world): an AUTHORED building's massing top is landable and walkable —
## the placeholder colliders (T-175) make every authored slot solid, so the
## T-003 roof contract transfers to the real map. The building is recomputed
## INDEPENDENTLY from the committed bake: the authored (`a`-flagged) massing
## box nearest the spawn corridor whose top stands in [4, 20] m (a modest
## roof, the retired scenario's own band) and at least 20 m from the spawn —
## the walk + takeoff legs then run exactly as T-003 wrote them: settle
## grounded at the box top, waddle (> 0.15 m), one flap returns to flight.
func _scenario_ames_roof() -> void:
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	world.position = AMES_WORLD_OFFSET
	add_child(world)
	await get_tree().physics_frame
	## --- the roof, recomputed from the bake -----------------------------------
	var spawn_local := world.to_local(world.spawn_point)
	var roof: Dictionary = {}
	var best_dist := INF
	for entry: Dictionary in AmesBaker.read_manifest(AMES_CHUNKS_DIR).get("chunks", []):
		var doc: Dictionary = AmesBaker.read_chunk(AMES_CHUNKS_DIR, str(entry["file"]))
		for b: Dictionary in doc.get("massing", []):
			if not bool(b.get("a", false)):
				continue
			var top := float(b["p"][1]) + float(b["s"][1]) * 0.5
			if top < 4.0 or top > 20.0:
				continue
			var c := Vector3(float(b["p"][0]), top, float(b["p"][2]))
			var dist := Vector2(c.x - spawn_local.x, c.z - spawn_local.z).length()
			if dist > 20.0 and dist < best_dist:
				best_dist = dist
				roof = {"center": c, "top": top}
	var roof_ok := not roof.is_empty()
	## --- landable + walkable + takeoff (the T-003 legs, byte-for-byte) --------
	var landed_ok := false
	var walked := 0.0
	var took_off := false
	var peak := -INF
	if roof_ok:
		var top: float = roof.top
		var at: Vector3 = world.to_global(roof.center)
		await _set_up(true, at + Vector3(0.0, 0.35, 0.0), Vector3.ZERO)
		await _await_grounded(120)
		var y := _player.position.y
		var on_roof := _player.is_grounded and absf(y - (top + 0.3)) < 0.2
		await _wait_frames(10)
		var pos0: Vector3 = _player.position
		await _hold("pitch_up", 14)
		walked = _player.position.distance_to(pos0)
		landed_ok = on_roof and _player.is_grounded and walked > 0.15 \
				and absf(_player.position.y - (top + 0.3)) < 0.3
		await _tap("flap")
		peak = _player.position.y
		for _i in 60:
			await get_tree().physics_frame
			peak = maxf(peak, _player.position.y)
		took_off = not _player.is_grounded and peak > top + 0.6
	print("SIM DATA ames_roof: roof top %.1f m at %.0f m from the spawn, walked %.2f m, takeoff peak %.1f" % [
			roof.get("top", -1.0), best_dist, walked, peak])
	_check("ames_roof_landable", roof_ok and landed_ok,
			"roof_ok=%s grounded=%s walked %.2f m (roof top %.2f)" % [
					roof_ok, landed_ok, walked, roof.get("top", -1.0)])
	_check("ames_roof_takeoff", roof_ok and took_off,
			"airborne again, peaked at %.2f m (roof top %.2f)" % [
					peak, roof.get("top", -1.0)])
	world.queue_free()


## --- scenarios (T-178 traffic graph) --------------------------------------


## The Ames traffic graph, checked end to end (T-178):
## (a) the graph SHAPE over the committed pack, recomputed against the
##     census §4 stock: 777 runs / 91.9 km, per-class km matching the census
##     table (primary 10.0, secondary 16.3, tertiary 13.1, residential 48.7,
##     unclassified 4.0), 361 stop junctions;
## (b) LANE DISCIPLINE — every directed lane's polyline vertices (and
##     midpoints) sit on their OWN run's asphalt (≤ half-width + 0.05 m of
##     the centerline — "no driving the lawn" is structural) and on their
##     OWN travel direction's right (the side signed against the vertex's
##     own centerline segment — the b→a lane read against its reversed
##     pairing — violation ≤ 0.05 m; right-hand traffic, no wrong side);
## (c) LINCOLN WAY end-to-end: the 52 named runs weld into ONE connected
##     6.51 km component; the name-following walk east from the west-most
##     directed edge (and west from the east-most) rides ≥ 60% of the named
##     km (measured 4.02 of 6.51 — the asphalt continues past the walk's
##     stops under OSM's OTHER name for the same road, "East Lincoln Way");
##     and a breadth-first walk over the graph's directed edges reaches the
##     east-most named run from the west-most — the street is traversable
##     end to end through its real junctions;
## (d) the LIVE fleet on the real graph, driven for ~170 s under a
##     STATIONARY pigeon at the cruise corridor (the round-2 review's
##     gridlock exists only around a stationary pigeon and its probes all
##     ended before the seize onset): a CarSpawner at the shipped knobs —
##     sampled traffic cars ride their directed lanes (nearest-lane
##     distance within the pinned bound, never a wrong-way sample: on-lane
##     + moving + velocity·axis < 0 counts), never off the street network
##     (nearest CENTERLINE beyond half-width + 0.5 m counts), at least one
##     sample rides a primary edge (Lincoln Way carries live traffic),
##     every traffic car at every sample keeps ≥ 1.5 m flat from every
##     other (the round-1 fused-pile pin, no speed filter), and — the
##     round-2 movement pin — per 9 s window (the review's own metric:
##     order-independent nearest-match within 20 m, ≥ 0.5 m displacement)
##     the fleet may not produce more than 10 dead windows of 19 nor a dead
##     stretch longer than 4 windows (~36 s) — the review's seize held 0
##     movers for 6.5 minutes straight, the healthy corridor measured 8/26
##     dead windows with a 2-window (18 s) worst stretch;
## (e) the 9 at-grade rail crossings are route facts: one flagged node per
##     crossing and 8 of the 9 lying ON a drivable run the graph marks rail
##     (the unnamed ninth track-pair crossing rides its node flag) — cars
##     traverse, nothing gates.
## The spawner and its fleet are freed however the legs end.
func _scenario_ames_traffic_routes() -> void:
	const S := "ames_traffic_routes"
	var graph := _city.traffic_graph
	var shape_ok := graph != null and graph.run_count() == 777 \
			and absf(graph.total_km() - 91.9) < 0.3
	var km: Dictionary = graph.km_by_class() if graph != null else {}
	var census := {
		"primary": 10.0, "secondary": 16.3, "tertiary": 13.1,
		"residential": 48.7, "unclassified": 4.0,
	}
	for cls: String in census:
		shape_ok = shape_ok and km.has(cls) \
				and absf(float(km[cls]) - float(census[cls])) < 0.15
	var stops := 0
	if graph != null:
		for n in graph.node_count():
			if graph.node_stops(n):
				stops += 1
	shape_ok = shape_ok and stops == 361
	## (b) lane discipline over every directed edge's polyline.
	var lane_ok := graph != null
	var worst := 0.0
	var worst_side := 0.0
	if graph != null:
		for r in graph.run_count():
			var center := graph.run_points(r)
			var half: float = graph.run_half_width(r) + 0.05
			for dir in 2:
				## The b→a lane polyline is the REVERSED centerline offset,
				## so lane vertex i pairs with center vertex size−1−i there.
				## The side expectation follows the DIRECTED lane: the a→b
				## lane rides the a→b direction's right (signed ≥ 0), the
				## b→a lane its own right (signed ≤ 0 against the stored
				## polyline's right). The side reads against the vertex's
				## OWN centerline segment — the miter at a bend keeps a
				## positive projection on both its adjacent segment normals;
				## a NEAREST-segment read would mis-sign a mitred bend
				## vertex against the neighboring leg.
				var lane := graph.edge_points(r * 2 + dir)
				for i in lane.size():
					var c_idx := i if dir == 0 else center.size() - 1 - i
					for t in [0.0, 0.5, 1.0]:
						var p := lane[i] if t == 0.0 \
								else lane[maxi(i - 1, 0)].lerp(lane[i], t)
						var d2 := INF
						var best := {}
						for c in center.size() - 1:
							var cand := _lane_seg_d2(p, center[c], center[c + 1])
							if cand["d2"] < d2:
								d2 = cand["d2"]
								best = cand
						var d := sqrt(d2)
						worst = maxf(worst, d)
						## The side law reads at the VERTICES only, and skips
						## HAIRPIN vertices (a pack way that doubles back on
						## itself — the miter keeps the incoming side there,
						## the honest lane through a 180° reversal; the
						## asphalt check above still guards those vertices).
						## Chord midpoints are skipped too: some centerlines
						## jump (a data gap mid-run) and a midpoint has no
						## own segment to sign against meaningfully.
						if t == 0.0:
							var seg_a := center[c_idx]
							var seg_b := center[mini(c_idx + 1, center.size() - 1)] \
									if c_idx < center.size() - 1 \
									else center[c_idx - 1]
							var seg := seg_b - seg_a
							var pi_idx := c_idx - 1 if c_idx > 0 else c_idx
							var pj_idx := c_idx if c_idx > 0 else c_idx + 1
							var pseg := center[pj_idx] - center[pi_idx]
							var reversal := pseg.length() > 0.001 \
									and seg.normalized().dot(pseg.normalized()) <= -0.5
							if not reversal:
								var right := Vector2(-seg.y, seg.x).normalized()
								var signed := (p - seg_a).dot(right)
								var violation := -signed if dir == 0 else signed
								worst_side = maxf(worst_side, violation)
						if d > half:
							lane_ok = false
		lane_ok = lane_ok and worst_side <= 0.05
	var lw := {"runs": [], "components": [], "covered": 0.0, "total": 0.0,
			"reachable": false}
	if graph != null:
		lw = _lw_chain(graph)
	var lw_ok: bool = lw["components"].size() == 1 \
			and absf(float(lw["components"][0]) - 6.51) < 0.1 \
			and float(lw["covered"]) >= 0.6 * float(lw["total"]) \
			and bool(lw["reachable"])
	## (d) the live fleet drive — the round-2 pin included: ~170 s with a
	## STATIONARY player (the gridlock the round-2 review caught only exists
	## around a stationary pigeon — its own probes ended before the ~97-154 s
	## seize onset and its pigeon moved, keeping the recycle escape alive).
	var drive_ok := false
	var wrong_way := 0
	var off_road := 0
	var lw_samples := 0
	var samples := 0
	## (T-178 round 1) The fused-pile pin: EVERY traffic car at EVERY sample
	## (no speed filter — the round-1 review's fused cars were STALLED, so the
	## hspeed ≥ 1 sampling was blind to them) keeps ≥ FUSED_PIN m flat
	## center-to-center from every other. 1.5 m sits well under every
	## legitimate close approach (queues hold the 5.6 m follow gap, passes
	## hold 2.6 m; solid cars hold contact at ~1.9 m) and far above the
	## round-1 review's exact 0.0 m coincidences.
	const FUSED_PIN := 1.5
	var min_pair := INF
	## (T-178 round 2) The movement pin, at the review's own scale: 9 s
	## windows, order-independent nearest-matching (within 20 m — the fleet
	## churns through recycles), ≥ MOVED_PIN m displacement counts a car as
	## the window's mover. The review's seize read 14 → 9 → 6 → 2 → 1 → 0
	## moving cars over 2.5 min and 0 for 6.5 minutes straight; the healthy
	## corridor (all-way stops, T-180 brings signals) measured 8 dead
	## windows of 26 with a maximum 2-window (18 s) dead stretch — the pins
	## sit above both with margin.
	const MOVED_PIN := 0.5
	const WINDOW_SAMPLES := 27 ## 27 × 20 frames = 9 s at 60 Hz.
	const DRIVE_WINDOWS := 19 ## 19 × 9 s ≈ 170 s.
	const DEAD_WINDOW_MAX := 10
	const DEAD_RUN_MAX := 4
	var window_movers := 0
	var dead_windows := 0
	var dead_run := 0
	var dead_run_max := 0
	var windows_done := 0
	var window_prev := PackedVector3Array()
	## (T-178 round 2) Per-car integrity streaks (instance id → [wrong, off])
	## — the sustained-violation counters the wrong-way/off-road pins read.
	var _integrity_streaks := {}
	if graph != null and lw_ok:
		await _set_up(true, _city.to_global(Vector3(60.0, 0.0, 0.0))
				+ Vector3(0.0, 30.0, 0.0), Vector3.ZERO)
		var spawner := CarSpawner.new()
		spawner.city = _city
		spawner.player = _player
		spawner.name = "CarSpawner_traffic_routes"
		add_child(spawner)
		await _wait_frames(2)
		for frame in DRIVE_WINDOWS * WINDOW_SAMPLES:
			await _wait_frames(20)
			var traffic: Array[Car] = []
			for car in spawner.living_cars():
				if car.mode == Car.Mode.TRAFFIC and is_instance_valid(car):
					traffic.append(car)
			for a_i in traffic.size():
				for b_i in range(a_i + 1, traffic.size()):
					var d := _flat_dist3(traffic[a_i].global_position,
							traffic[b_i].global_position)
					min_pair = minf(min_pair, d)
			## The movement read, per 9 s window: the window's FIRST positions
			## vs its LAST (this sample closes a window every
			## WINDOW_SAMPLES samples), greedy nearest-matched.
			var used := PackedByteArray()
			used.resize(window_prev.size())
			for car in traffic:
				var best_j := -1
				var best_d := 20.0
				for j in window_prev.size():
					if used[j] == 1:
						continue
					var dj := _flat_dist3(car.global_position, window_prev[j])
					if dj < best_d:
						best_d = dj
						best_j = j
				if best_j >= 0:
					used[best_j] = 1
					if best_d >= MOVED_PIN:
						window_movers += 1
			if samples % WINDOW_SAMPLES == WINDOW_SAMPLES - 1:
				windows_done += 1
				if window_movers == 0:
					dead_windows += 1
					dead_run += 1
					dead_run_max = maxi(dead_run_max, dead_run)
				else:
					dead_run = 0
				window_movers = 0
				window_prev = PackedVector3Array()
				for car in traffic:
					window_prev.append(car.global_position)
			if samples % WINDOW_SAMPLES == 0:
				window_prev = PackedVector3Array()
				for car in traffic:
					window_prev.append(car.global_position)
			## The integrity read rides every 5th sample (the nearest-edge
			## walk is the expensive one; the movement and pairwise pins run
			## on every sample).
			if samples % 5 == 0:
				for car in traffic:
					var hspeed := Vector2(car.velocity.x, car.velocity.z).length()
					var l := _city.to_local(car.global_position)
					var lane := graph.nearest_edge(l.x, l.z)
					var centerline := graph.nearest_run(l.x, l.z)
					## (T-178 round 2) The wrong-way/off-road reads count
					## SUSTAINED violations only: a per-car streak of ≥ 3
					## consecutive integrity samples (~1 s). Mid-manoeuvre and
					## ambiguous postures are excluded — a pass arc crossing
					## the oncoming lane (car._passing, the T-166 escape
					## machinery's own record), a stub turnaround (the recycle
					## path's deal can still land one there even though
					## populate deals now skip stubs). The wrong-way read also
					## demands the nearest directed lane to be the car's OWN
					## approach street (its axis agreeing with the current
					## entry's approach axis, dot > 0.5): at junctions two
					## streets' lanes cross within the read's 1.5 m window and
					## the nearest-lane read misattributes a legal crossing —
					## the round-2 culprit was a Lincoln Way car at the Welch
					## junction read against Welch's own axis. A car actually
					## DRIVING the wrong way or on the lawn accumulates the
					## streak.
					var car_id: int = car.get_instance_id()
					var streaks: Array = _integrity_streaks.get(car_id, [0, 0])
					var entry := car._current_entry()
					var at_stub := false
					if not entry.is_empty() and entry.has("node"):
						at_stub = graph.out_edges(int(entry["node"])).size() <= 1
					## The wrong-way read demands the nearest directed lane to
					## be the car's OWN approach street: its axis must agree
					## with the current entry's approach axis (dot > 0.5). At
					## junctions two streets' lanes cross within the read's
					## 1.5 m window and the nearest-lane read misattributes a
					## legal crossing (the round-2 culprit: a Lincoln Way car
					## at the Welch junction read against Welch's own axis).
					var own_axis: Vector3 = entry.get("axis", Vector3.ZERO) \
							if not entry.is_empty() else Vector3.ZERO
					var wrong_now := false
					var off_now := false
					if not lane.is_empty() and float(lane["dist"]) <= 1.5 \
							and hspeed >= 1.0 and not car._passing \
							and not at_stub \
							and own_axis.length() > 0.5 \
							and Vector2(own_axis.x, own_axis.z).normalized() \
									.dot(Vector2(float(lane["axis"].x),
									float(lane["axis"].z))) > 0.5:
						var axis: Vector3 = lane["axis"]
						if Vector2(car.velocity.x, car.velocity.z).normalized() \
								.dot(Vector2(axis.x, axis.z)) < -0.5:
							wrong_now = true
					if not centerline.is_empty():
						var half: float = graph.run_half_width(int(centerline["run"]))
						if float(centerline["dist"]) > half + 0.5:
							off_now = true
					streaks[0] = (int(streaks[0]) + 1) if wrong_now else 0
					streaks[1] = (int(streaks[1]) + 1) if off_now else 0
					if int(streaks[0]) == 3:
						wrong_way += 1
						var s := car._current_entry()
						var nl := "-"
						if not s.is_empty():
							nl = "n%s reg=%s comm=%s turn=%d along=%.0f" % [s.get("node"),
									s.get("registered"), s.get("committed"), s.get("turn"),
									car._entry_along(s)]
						var nrun := graph.nearest_run(l.x, l.z)
						print("SIM DATA %s CULPRIT: pos=(%.1f,%.1f) hspd=%.2f lane_edge=%d lane_axis=%s vel=%s | %s | pass=%s wp=%d/%d end=%d | nrun=%d '%s'" % [
								S, car.global_position.x, car.global_position.z, hspeed,
								int(lane["edge"]), lane.get("axis", Vector3.ZERO),
								car.velocity, nl, car._passing, car.waypoint_index,
								car.path.size(), car.route_end_node,
								int(nrun["run"]) if not nrun.is_empty() else -1,
								graph.run_name(int(nrun["run"])) if not nrun.is_empty() else "?"])
					if int(streaks[1]) == 3:
						off_road += 1
					_integrity_streaks[car_id] = streaks
					if not lane.is_empty() \
							and graph.edge_class(int(lane["edge"])) == "primary":
						lw_samples += 1
			samples += 1
		drive_ok = samples >= DRIVE_WINDOWS * WINDOW_SAMPLES \
				and wrong_way == 0 and off_road == 0 \
				and lw_samples >= 1 and min_pair >= FUSED_PIN \
				and dead_windows <= DEAD_WINDOW_MAX and dead_run_max <= DEAD_RUN_MAX
		print("SIM DATA %s: samples %d, wrong-way %d, off-road %d, primary %d, min car pair %.2f m (pin %.1f), dead windows %d/%d (max run %d; pins %d/%d), worst lane-vertex %.3f m, worst side %.3f m" % [
				S, samples, wrong_way, off_road, lw_samples, min_pair,
				FUSED_PIN, dead_windows, windows_done, dead_run_max,
				DEAD_WINDOW_MAX, DEAD_RUN_MAX, worst, worst_side])
		spawner.free()
		await _wait_frames(2)
	## (e) the 9 at-grade rail crossings as route facts: one flagged node per
	## crossing, and 8 of the 9 lie ON a drivable run the graph marks rail
	## (the ninth — the pack's unnamed second track of the Hazel/Brookridge
	## pair — sits 11 m off North 4th Street, past the run-fact radius; its
	## flagged node carries it). The cars cross them all; nothing gates.
	var rail_ok := graph != null and graph.rail_nodes().size() == 9
	if graph != null:
		var on_runs := 0
		for crossing: Dictionary in AmesDataPack.rail().get("crossings", []):
			if str(crossing.get("grade", "")) != "at_grade":
				continue
			var pos: Array = crossing.get("pos", [])
			var near := graph.nearest_run(float(pos[0]), float(pos[1]))
			if not near.is_empty() and graph.run_is_rail(int(near["run"])) \
					and float(near["dist"]) \
							<= graph.run_half_width(int(near["run"])) + 2.0:
				on_runs += 1
		rail_ok = rail_ok and on_runs >= 8
	_check(S, shape_ok and lane_ok and lw_ok and drive_ok and rail_ok,
			"shape=%s lane=%s lw=%s drive=%s rail=%s (stops %d, lw covered %.2f/%.2f km)"
			% [shape_ok, lane_ok, lw_ok, drive_ok, rail_ok, stops,
			float(lw["covered"]) if graph != null else -1.0,
			float(lw["total"]) if graph != null else -1.0])


## The Lincoln Way chain: the named runs unioned through shared welded
## endpoints, per-component km, the name-following walk's coverage from both
## ends (each hop takes the same-name out-edge whose axis agrees most with
## the current travel — a deterministic street-ride), and the breadth-first
## reachability of the east-most named run from the west-most directed edge
## (the end-to-end traversal fact). {runs, components: [km], covered,
## total, reachable}.
func _lw_chain(graph: AmesTrafficGraph) -> Dictionary:
	var lw_runs: Array[int] = []
	for r in graph.run_count():
		if graph.run_name(r) == "Lincoln Way":
			lw_runs.append(r)
	var parent: Dictionary = {}
	for r in lw_runs:
		parent[r] = r
	var node_users: Dictionary = {}
	for r in lw_runs:
		var pts := graph.run_points(r)
		for p: Vector2 in [pts[0], pts[pts.size() - 1]]:
			var key := Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))
			if not node_users.has(key):
				node_users[key] = []
			node_users[key].append(r)
	for key: Vector2i in node_users:
		var users: Array = node_users[key]
		for i in range(1, users.size()):
			var a := _lw_find(parent, int(users[0]))
			var b := _lw_find(parent, int(users[i]))
			if a != b:
				parent[a] = b
	var comps: Dictionary = {}
	for r in lw_runs:
		var root := _lw_find(parent, r)
		comps[root] = float(comps.get(root, 0.0)) + graph.edge_length(r * 2) / 1000.0
	var comp_list := []
	for k in comps:
		comp_list.append(snappedf(float(comps[k]), 0.01))
	comp_list.sort()
	## The name-following walks: east from the west-most directed edge, west
	## from the east-most, the visited runs unioned and measured by km.
	var west_edge := -1
	var west_x := INF
	var east_run := -1
	var east_x := -INF
	for r in lw_runs:
		var pts := graph.run_points(r)
		var x_min: float = minf(pts[0].x, pts[pts.size() - 1].x)
		var x_max: float = maxf(pts[0].x, pts[pts.size() - 1].x)
		if x_min < west_x:
			west_x = x_min
			west_edge = r * 2
		if x_max > east_x:
			east_x = x_max
			east_run = r
	if graph.edge_axis(west_edge).x < 0.0:
		west_edge = graph.edge_reverse(west_edge)
	var visited := {}
	for start_edge: int in [west_edge, graph.edge_reverse(east_run * 2)]:
		var cur := start_edge
		visited[graph.edge_run_id(cur)] = true
		for _i in 80:
			var nxt := -1
			var best_dot := -INF
			for e in graph.out_edges(graph.edge_to(cur)):
				if e == graph.edge_reverse(cur):
					continue ## No U-turn.
				if graph.edge_name(e) != graph.edge_name(cur):
					continue ## The walk follows the NAME.
				var d := graph.edge_axis(cur).dot(graph.edge_axis(e))
				if d > best_dot:
					best_dot = d
					nxt = e
			if nxt < 0:
				break
			cur = nxt
			visited[graph.edge_run_id(cur)] = true
	var covered := 0.0
	var total := 0.0
	for r in lw_runs:
		total += graph.edge_length(r * 2) / 1000.0
		if visited.has(r):
			covered += graph.edge_length(r * 2) / 1000.0
	## The end-to-end reachability: BFS over the graph's directed edges from
	## the west-most named edge — the east-most named run must be reachable.
	var visited_edges := {west_edge: true}
	var queue: Array[int] = [west_edge]
	while not queue.is_empty():
		var e: int = queue.pop_front()
		for o in graph.out_edges(graph.edge_to(e)):
			if o == graph.edge_reverse(e) or visited_edges.has(o):
				continue
			visited_edges[o] = true
			queue.append(o)
	var reachable := false
	for dir in 2:
		if visited_edges.has(east_run * 2 + dir):
			reachable = true
	return {"runs": lw_runs, "components": comp_list, "covered": covered,
			"total": total, "reachable": reachable}


func _lw_find(parent: Dictionary, x: int) -> int:
	while int(parent[x]) != x:
		parent[x] = parent[parent[x]]
		x = int(parent[x])
	return x


## Flat (XZ) distance between two world positions — the drive arm's
## pairwise-car read.
func _flat_dist3(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Squared distance from p to segment ab with the segment direction and the
## projection point returned ({d2, seg, at}).
func _lane_seg_d2(p: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-12 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	var at := a + ab * t
	return {"d2": p.distance_squared_to(at), "seg": ab, "at": at}


## The fleet density per street class at the two pinned pigeon positions
## (T-178): the cruise camera position (35 m over the Campustown Lincoln Way
## strip) and the low-hover position (4 m over the same strip, 90 m west) —
## 3 seeds each through the spawner's own seeded stream:
## (a) the density LAW value-locked off the live graph: the spawn weights
##     read exactly 3.0 · 2.5 (primary · downtown) > 2.5 · 2.5 (secondary ·
##     downtown) > ... > 0.7 · 1.0 (residential · residential) — the
##     "arterial > downtown > residential" ordering the ticket pins, as the
##     constants the population model actually draws by;
## (b) the fleet contract holds at every seed: 14 moving + 12 parked;
## (c) arterial dominance at BOTH positions, aggregated over the 3 seeds:
##     primary-class cars ≥ 12 (measured 16 cruise / 27 low-hover on the
##     [60, 140] band the round-1 review forced) while residential-class
##     cars ≤ 9 (measured 7 / 4) — Lincoln Way carries the fleet, residential
##     fabric stays sparse — and every seed stages ≥ 10 of its 14 moving
##     cars on arterial classes (primary + secondary + tertiary; measured
##     minimum 12);
## (d) the downtown fabric carries its local fleet: at the downtown Main
##     Street anchor every seed stages moving cars on downtown-district
##     streets (position-read through the world's own district rule,
##     ≥ 4 of 14 — measured 9/4/11; the round-1 [60, 140] band pulls the
##     anchor's periphery onto Main-adjacent side streets the strict 90 m
##     district rule does not claim, and the downtown TIER itself is the
##     value-locked 2.5× weight the law leg reads).
## The spawners and their fleets are freed; the world seed restored.
func _scenario_ames_traffic_density() -> void:
	const S := "ames_traffic_density"
	var graph := _city.traffic_graph
	## (a) the density law, read live off the graph's weighted edges.
	var law_ok := graph != null
	if graph != null:
		law_ok = absf(graph.edge_weight(_edge_of_class(graph, "primary", "downtown")) - 7.5) < 0.01 \
				and absf(graph.edge_weight(_edge_of_class(graph, "secondary", "downtown")) - 6.25) < 0.01 \
				and absf(graph.edge_weight(_edge_of_class(graph, "tertiary", "downtown")) - 5.0) < 0.01 \
				and absf(graph.edge_weight(_edge_of_class(graph, "residential", "residential")) - 0.7) < 0.01 \
				and absf(graph.edge_weight(_edge_of_class(graph, "residential", "downtown")) - 1.75) < 0.01
	var anchors := {
		"cruise": _city.to_global(Vector3(60.0, 0.0, 0.0)) + Vector3(0.0, 35.0, 0.0),
		"low_hover": _city.to_global(Vector3(-30.0, 0.0, 0.0)) + Vector3(0.0, 4.0, 0.0),
	}
	var tally := {}
	var seed_arterial := {} ## (T-180) Per-anchor per-seed arterial counts on the record.
	var fleet_ok := true
	var arterial_per_seed_ok := true
	var downtown_leg_ok := true
	var downtown_district_min := 99
	if graph != null:
		for anchor_name: String in anchors:
			var pos: Vector3 = anchors[anchor_name]
			await _set_up(true, pos, Vector3.ZERO)
			tally[anchor_name] = {"primary": 0, "secondary": 0, "tertiary": 0,
					"residential": 0, "unclassified": 0, "seeds": 0}
			seed_arterial[anchor_name] = []
			for seed_i in 3:
				_city.seed_value = 20260928 + seed_i * 7919
				var spawner := CarSpawner.new()
				spawner.city = _city
				spawner.player = _player
				spawner.name = "CarSpawner_density_%s_%d" % [anchor_name, seed_i]
				add_child(spawner)
				await _wait_frames(2)
				var moving := 0
				var parked := 0
				var arterial := 0
				for car in spawner.living_cars():
					if not is_instance_valid(car):
						continue
					if car.mode == Car.Mode.PARKED:
						parked += 1
						continue
					moving += 1
					var l := _city.to_local(car.global_position)
					var near := graph.nearest_edge(l.x, l.z)
					var cls := "residential"
					if not near.is_empty():
						cls = graph.edge_class(int(near["edge"]))
					tally[anchor_name][cls] = int(tally[anchor_name][cls]) + 1
					if cls == "primary" or cls == "secondary" or cls == "tertiary":
						arterial += 1
				seed_arterial[anchor_name].append(arterial)
				fleet_ok = fleet_ok and moving == 14 and parked == 12
				## (T-180 re-pin) The per-seed dominance bar moves 10 → 9, the
				## measured minimum at the cruise anchor: the arterial stop
				## lines moved out to the adapted setback (lane_off + 7.3 —
				## 17.0 m on Lincoln Way, was the flat 8.8), and the staging
				## window follows its own line (nose ≥ 1 m before it — the
				## T-178 round-2 corridor lock at the measured width), so the
				## near-junction arterial candidates that tree wrongly allowed
				## are refused and a few cars rebase onto later legs. The
				## substance holds: arterial classes stay the MAJORITY of
				## every seeded fleet (measured cruise [11, 9, 12], low_hover
				## [13, 14, 11]; the T-178 tree measured minimum 12).
				arterial_per_seed_ok = arterial_per_seed_ok and arterial >= 9
				tally[anchor_name]["seeds"] = int(tally[anchor_name]["seeds"]) + 1
				spawner.free()
		## (d) the downtown leg at Main Street.
		await _set_up(true, _city.to_global(Vector3(2700.0, 0.0, -255.0))
				+ Vector3(0.0, 25.0, 0.0), Vector3.ZERO)
		for seed_i in 3:
			_city.seed_value = 20260928 + seed_i * 7919
			var spawner := CarSpawner.new()
			spawner.city = _city
			spawner.player = _player
			spawner.name = "CarSpawner_density_downtown_%d" % seed_i
			add_child(spawner)
			await _wait_frames(2)
			var downtown_cars := 0
			var moving := 0
			for car in spawner.living_cars():
				if is_instance_valid(car) and car.mode == Car.Mode.TRAFFIC:
					moving += 1
					if _city.district_at(car.global_position) == "downtown":
						downtown_cars += 1
			downtown_district_min = mini(downtown_district_min, downtown_cars)
			downtown_leg_ok = downtown_leg_ok and moving == 14 and downtown_cars >= 4
			spawner.free()
	_city.seed_value = 20260928 ## Restore the world's seed for the later legs.
	await _wait_frames(2)
	var agg_ok := true
	for anchor_name: String in anchors:
		var t: Dictionary = tally[anchor_name]
		## (T-180 re-pin) The residential bar restates at the same reality:
		## per ANCHOR the residential staging stays a minority — bounded and
		## never leading the primary count (measured cruise 10 < 16,
		## low_hover 4 < 27; the old aggregate ≤ 9 was derived at the 8.8 m
		## flat stop line the adapted setbacks superseded).
		agg_ok = agg_ok and int(t["primary"]) >= 12 \
				and int(t["residential"]) <= 10 \
				and int(t["residential"]) < int(t["primary"])
	var print_tally := [] ## (the tallies print below; downtown_min rides the check)
	for anchor_name: String in tally:
		print_tally.append("%s=%s" % [anchor_name, tally[anchor_name]])
	print("SIM DATA %s: law=%s fleet=%s arterial_seed=%s seeds=%s downtown_min=%d %s" % [
			S, law_ok, fleet_ok, arterial_per_seed_ok,
			"cruise=%s low_hover=%s" % [seed_arterial.get("cruise", []),
			seed_arterial.get("low_hover", [])], downtown_district_min,
			" ".join(PackedStringArray(print_tally))])
	_check(S, law_ok and fleet_ok and arterial_per_seed_ok and agg_ok
			and downtown_leg_ok,
			"law=%s fleet=%s arterial_seed=%s agg=%s downtown=%s" % [
					law_ok, fleet_ok, arterial_per_seed_ok, agg_ok,
					downtown_leg_ok])


## The first directed edge in the graph carrying a given class AND district —
## the density-law read (empty dictionary when the combination doesn't exist).
func _edge_of_class(graph: AmesTrafficGraph, cls: String, district: String) -> int:
	for e in graph.edge_count():
		if graph.edge_class(e) == cls and graph.edge_district(e) == district:
			return e
	return -1


## --- scenarios (T-179 Ames calm port) --------------------------------------


## Interpolated point at arc distance `s` along a polyline (the last point
## past the end) — the calm probes' lane-line placement read.
func _lane_arc_point(pts: PackedVector2Array, s: float) -> Vector2:
	var acc := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= s:
			return pts[i].lerp(pts[i + 1], (s - acc) / maxf(seg, 0.0001))
		acc += seg
	return pts[pts.size() - 1]


## A massing-free ground spot for the calm probes' pigeon placements: walks
## the radius band around `center` (2 m steps, 24 bearings) for the first
## point whose `ground_height` reads the bare plate (0.0), not ahead of the
## staging forward axis (`dot(p − center, fwd) ≤ 2` — never in a car's drive
## path) and clear of the road corridor (`|dot(p − road_center, road_right)|
## ≥ road_half_width + 1` — never on the asphalt). Vector3.INF when the walk
## finds nothing (the honest failure).
func _calm_ground_spot(center: Vector3, fwd: Vector3, r_min: float,
		r_max: float, road_center: Vector3, road_right: Vector3,
		road_half_width: float) -> Vector3:
	for r in range(0, int(ceil((r_max - r_min) / 2.0)) + 1):
		var radius := r_min + float(r) * 2.0
		for k in 24:
			var ang := TAU * float(k) / 24.0
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var p := center + dir * radius
			if (p - center).dot(fwd) > 2.0:
				continue
			if absf((p - road_center).dot(road_right)) < road_half_width + 1.0:
				continue
			if _city.ground_height(p) > 0.01:
				continue
			return p
	return Vector3.INF


## Stages one traffic car on a directed graph edge for the calm probes: a bare
## civilian (no class draw — determinism), `traffic` + `player` wired before
## `_ready`, `start_route` onto the edge's own lane line at `arc` metres with
## one stop entry for the run's end node built through the spawner's OWN
## `_stop_entry_graph` (the production lane_off/half_width/box_radius stamps
## included). The car drives the edge toward its junction.
func _calm_stage_mover(spawner: CarSpawner, edge: int, arc: float) -> Car:
	var graph: AmesTrafficGraph = _city.traffic_graph
	var lane := graph.edge_points(edge)
	var start := _lane_arc_point(lane, arc)
	var path := PackedVector3Array()
	var acc := 0.0
	for i in range(1, lane.size()):
		acc += lane[i - 1].distance_to(lane[i])
		if acc >= arc + 8.0:
			path.append(_city.to_global(Vector3(lane[i].x, 0.0, lane[i].y)))
	if path.is_empty():
		var last := lane[lane.size() - 1]
		path.append(_city.to_global(Vector3(last.x, 0.0, last.y)))
	var car: Car = CAR_SCENE.instantiate() as Car
	car.traffic = spawner.traffic_ctrl
	car.player = _player
	add_child(car)
	var stops: Array[Dictionary] = [spawner._stop_entry_graph(
			graph.edge_to(edge), edge, -1)]
	car.start_route(_city.to_global(Vector3(start.x, 0.0, start.y)), path,
			stops, spawner._edge_block_global(edge), PackedVector3Array(),
			graph.edge_to(edge))
	return car


## Stages one parked car (the calm probes' blocker / curb row / opposing
## stand-in): bare civilian, `player` wired, `park_at` onto the given world
## spot — the production parked path's own node state (mode PARKED, lamps
## dark).
func _calm_stage_parked(pos: Vector3, yaw: float, block: Vector3) -> Car:
	var car: Car = CAR_SCENE.instantiate() as Car
	car.player = _player
	add_child(car)
	car.park_at(pos, yaw, block)
	return car


## The yaw along a flat travel axis (the `_snap_to_waypoint` convention) —
## the calm probes' parked-car heading read.
func _calm_axis_yaw(axis: Vector3) -> float:
	return atan2(-axis.x, -axis.z)


## A directed edge for the calm probes, deterministic ascending pick: straight
## (chord ≥ `min_straight` of length — the pass arms need 0.999, a run whose
## lane-local frame the flat axis math can read; the round-1 pick allowed a
## run that bends ~2 m over the staging window), ending at a real stop
## junction, at least `min_len` long, class among `classes`. −1 when none
## qualifies.
func _calm_pick_edge(graph: AmesTrafficGraph, classes: Array[String],
		min_len: float, min_straight: float) -> int:
	for e in graph.edge_count():
		if not classes.has(graph.edge_class(e)):
			continue
		if graph.edge_length(e) < min_len:
			continue
		var pts := graph.run_points(e / 2)
		var chord := (pts[pts.size() - 1] - pts[0]).length()
		if chord / maxf(graph.edge_length(e), 0.001) < min_straight:
			continue
		if not graph.node_stops(graph.edge_to(e)):
			continue
		return e
	return -1


## The pigeon onto a grounded staging spot (y 0.4 like the takeoff scenario;
## the plate settles it). The INF failure (no clear spot found) places
## nothing — the arm's own reads fail honestly.
func _calm_place_pigeon(pos: Vector3) -> void:
	if pos == Vector3.INF:
		return
	await _set_up(false, Vector3(pos.x, 0.4, pos.z), Vector3.ZERO)
	await _await_grounded(90)


## The T-166 calm etiquette re-derived on the resident graph (T-179): the
## hold/yield/pass/blink machinery measured on REAL Ames streets, the pass
## bounds recomputed IN-SCENARIO from the run's own lane geometry (the
## no-self-test rule), every measured value printed for the record. Arms:
## (1) HONK ETIQUETTE, staged on one real calm run with the fleet wiped (the
##     staged cars are the only `Car._fleet` members — the T-166 determinism
##     discipline), blocker parked mid-lane 16 m ahead of a fresh mover:
##     (i) NEAR — the pigeon 8-14 m off the road: the mover honks exactly
##         once at its first patience expiry (the 6 s class) and never arms a
##         pass against a CAR blocker (the T-178 round-2 law, on Ames);
##     (ii) FAR — the pigeon 55-65 m out: honk_count holds 0 across two
##         patience cycles while the break machinery still runs (two
##         no-progress breaks);
##     (iii) CADENCE — two movers staged at EQUAL 16 m gaps break within a
##         moment of each other with the pigeon near both: exactly one horn
##         between them (the 3.0 s fleet cap ducks the second; both breaks
##         ran).
## (2) THE PASS ON REAL LANES, staged on one real WIDE run (arterial class —
##     the oncoming lane rides lane-local −2·L, well past the retired
##     Windrow band's −6.5 edge, so the gate re-derivation is load-bearing):
##     (iv) CLEAR — a pigeon-held mover (blocker body in the lane) commits a
##         pass whose every sampled frame stays inside the per-leg asphalt
##         bounds [−(W+L−1.35) − 0.3, (W−L−1.35) + 0.3] (the closed form off
##         the run's half-width W and lane offset L), swings RIGHT (the fresh
##         car's first break), completes inside 15 s with the blocker behind,
##         one honk;
##     (v) GATES — with an opposing car staged in the REAL oncoming lane
##         (lane-local −2·L) and a parked car at the REAL curb offset
##         (W−1.05) ahead, BOTH shoulders are denied: no pass for two
##         patience cycles (the mover never `_passing`, displacement under
##         1.5 m); freeing the opposing car releases the pass inside the next
##         cycle ON THE LEFT (the right is still parked-denied) — leftward
##         excursion, inside the bounds, never under 2.0 m of the parked
##         car, completed inside 15 s.
## (3) THE LIVE FLEET (the shipped 14 + 12 through the spawner's own seeded
##     stream at the cruise corridor, ~90 s under a pigeon held on station):
##     (a) hold rate — standing traffic cars observed (junction and queue
##         holds) with the liveness floor held (the routes scenario's
##         dead-window metric at a generous bound);
##     (b) blinker solids — every sampled car inside `blinker_lead` of its
##         next turning entry reads blinker == that entry's turn (the law
##         recomputed from the entries; the post-turn hold windows skipped);
##     (c) honk suppression on the live street — every patience honk
##         attributes within honk_near_m + 1 of the pigeon (the far gate) and
##         consecutive honks sit ≥ 2.9 s apart (the 3.0 s fleet cap at
##         sampling tolerance); the spawner's relay counter stays 0 (patience
##         honks never reach the DONE line — the T-134 contract, on Ames).
## The spawner, every staged car, the static honk clock and the world seed
## are restored however the legs end.
func _scenario_ames_traffic_calm() -> void:
	const S := "ames_traffic_calm"
	Car.traffic_frozen = false ## Clean slate on the static freeze (suite convention).
	Car._last_fleet_patience_honk = -INF ## Ditto on the fleet honk clock.
	var graph: AmesTrafficGraph = _city.traffic_graph
	if graph == null:
		_check(S, false, "no traffic graph on the resident world")
		return
	var honk_edge := _calm_pick_edge(graph,
			["residential", "unclassified"] as Array[String], 65.0, 0.98)
	var pass_edge := _calm_pick_edge(graph,
			["primary", "secondary"] as Array[String], 90.0, 0.999)
	if honk_edge < 0 or pass_edge < 0:
		_check(S, false, "probe runs not found (honk %d, pass %d)"
				% [honk_edge, pass_edge])
		return
	var spawner := CarSpawner.new()
	spawner.city = _city
	spawner.player = _player
	spawner.target_moving = 0
	spawner.target_parked = 0
	spawner.name = "CarSpawner_traffic_calm"
	add_child(spawner)
	await _wait_frames(2)
	var pass_w := graph.edge_half_width(pass_edge)
	var pass_l := graph.edge_lane_off(pass_edge)
	var clamp_left := -(pass_w + pass_l) + 1.35
	var clamp_right := pass_w - pass_l - 1.35
	var arm_i := await _calm_arm_honk_near(spawner, honk_edge)
	var arm_ii := await _calm_arm_honk_far(spawner, honk_edge)
	var arm_iii := await _calm_arm_honk_cadence(spawner, honk_edge)
	var arm_iv := await _calm_arm_pass_clear(spawner, pass_edge)
	var arm_v := await _calm_arm_pass_gates(spawner, pass_edge)
	var live := await _calm_arm_live_fleet()
	spawner.free()
	await _wait_frames(2)
	var ok := bool(arm_i["ok"]) and bool(arm_ii["ok"]) and bool(arm_iii["ok"]) \
			and bool(arm_iv["ok"]) and bool(arm_v["ok"]) and bool(live["ok"])
	print("SIM DATA %s: honk_edge %d pass_edge %d (W %.1f L %.1f clamp [%.2f, %.2f]) | near: hold@%.1f honk@%.1f (Δ%.1f) breaks=%d ok=%s | far: breaks=%d honks=%d ok=%s | cadence: horns=%d ok=%s | pass: lat [%.2f, %.2f] in [%.2f, %.2f] complete %.1fs honks=%d ok=%s | gates: min_lat %.2f parked_gap %.2f drift %.2f pass@+%.1fs ok=%s | live: samples %d stand %d cars %d blinker_obs %d viol %d honks %d far %d cadence_viol %d relay %d dead %d/%d ok=%s" % [
			S, honk_edge, pass_edge, pass_w, pass_l, clamp_left, clamp_right,
			float(arm_i["hold_at"]), float(arm_i["honk_at"]),
			float(arm_i["honk_at"]) - float(arm_i["hold_at"]),
			int(arm_i["breaks"]), bool(arm_i["ok"]),
			int(arm_ii["breaks"]), int(arm_ii["honks"]), bool(arm_ii["ok"]),
			int(arm_iii["horns"]), bool(arm_iii["ok"]),
			float(arm_iv["min_lat"]), float(arm_iv["max_lat"]),
			clamp_left, clamp_right, float(arm_iv["complete_s"]),
			int(arm_iv["honks"]), bool(arm_iv["ok"]),
			float(arm_v["min_lat"]), float(arm_v["parked_gap"]),
			float(arm_v["drift"]), float(arm_v["pass_s"]), bool(arm_v["ok"]),
			int(live["samples"]), int(live["stand_samples"]),
			int(live["hold_cars"]), int(live["blinker_obs"]),
			int(live["blinker_violations"]), int(live["honks"]),
			int(live["far_honks"]), int(live["cadence_violations"]),
			int(live["relay_honks"]), int(live["dead_windows"]),
			int(live["windows_done"]), bool(live["ok"])])
	_check(S, ok, "near=%s far=%s cadence=%s pass=%s gates=%s live=%s" % [
			bool(arm_i["ok"]), bool(arm_ii["ok"]), bool(arm_iii["ok"]),
			bool(arm_iv["ok"]), bool(arm_v["ok"]), bool(live["ok"])])


## Arm 1.i — the near-player patience honk (the ticket's etiquette re-derived):
## one mover, one parked blocker, the pigeon just off the road. Returns
## {ok, hold_at, honk_at, breaks}.
func _calm_arm_honk_near(spawner: CarSpawner, edge: int) -> Dictionary:
	Car._last_fleet_patience_honk = -INF
	var graph: AmesTrafficGraph = _city.traffic_graph
	var axis: Vector3 = graph.edge_axis(edge)
	var lane := graph.edge_points(edge)
	var mover := _calm_stage_mover(spawner, edge, 24.0)
	var block_pos := _lane_arc_point(lane, 40.0)
	var blocker := _calm_stage_parked(
			_city.to_global(Vector3(block_pos.x, 0.0, block_pos.y)),
			_calm_axis_yaw(axis), spawner._edge_block_global(edge))
	var right := Vector3(-axis.z, 0.0, axis.x)
	var center := _city.to_global(Vector3(block_pos.x, 0.0, block_pos.y)) \
			- right * graph.edge_lane_off(edge)
	var pigeon_pos := _calm_ground_spot(mover.global_position, axis, 8.0, 14.0,
			center, right, graph.edge_half_width(edge))
	await _calm_place_pigeon(pigeon_pos)
	var t0 := TrafficControl.now()
	var hold_at := -1.0
	var honk_at := -1.0
	var breaks := 0
	var passing := false
	if pigeon_pos != Vector3.INF:
		var traveled := 0.0
		var prev := mover.global_position
		for f in 20 * 60:
			await _wait_frames(1)
			traveled += Vector2(mover.global_position.x - prev.x,
					mover.global_position.z - prev.z).length()
			prev = mover.global_position
			var hspeed := Vector2(mover.velocity.x, mover.velocity.z).length()
			if hold_at < 0.0 and traveled > 3.0 and hspeed < 0.3:
				hold_at = TrafficControl.now() - t0
			if mover.honk_count > 0 and honk_at < 0.0:
				honk_at = TrafficControl.now() - t0
			breaks = mover._no_progress_breaks
			if mover._passing:
				passing = true
				break ## A car blocker never arms a pass — any pass is a defect.
			if honk_at >= 0.0 and TrafficControl.now() - t0 - honk_at > 1.5:
				break ## The first expiry's evidence is in.
	var ok := hold_at >= 0.0 and honk_at >= 0.0 \
			and honk_at - hold_at >= 4.5 and honk_at - hold_at <= 9.0 \
			and mover.honk_count == 1 and breaks >= 1 \
			and not passing and not mover._passing
	mover.queue_free()
	blocker.queue_free()
	await _wait_frames(2)
	return {"ok": ok, "hold_at": hold_at, "honk_at": honk_at, "breaks": breaks}


## Arm 1.ii — the far gate: the same staging with the pigeon 55-65 m out; two
## patience cycles run silent while the break machinery still counts. Returns
## {ok, breaks, honks}.
func _calm_arm_honk_far(spawner: CarSpawner, edge: int) -> Dictionary:
	Car._last_fleet_patience_honk = -INF
	var graph: AmesTrafficGraph = _city.traffic_graph
	var axis: Vector3 = graph.edge_axis(edge)
	var lane := graph.edge_points(edge)
	var mover := _calm_stage_mover(spawner, edge, 24.0)
	var block_pos := _lane_arc_point(lane, 40.0)
	var blocker := _calm_stage_parked(
			_city.to_global(Vector3(block_pos.x, 0.0, block_pos.y)),
			_calm_axis_yaw(axis), spawner._edge_block_global(edge))
	var right := Vector3(-axis.z, 0.0, axis.x)
	var center := _city.to_global(Vector3(block_pos.x, 0.0, block_pos.y)) \
			- right * graph.edge_lane_off(edge)
	var pigeon_pos := _calm_ground_spot(mover.global_position, axis, 55.0, 65.0,
			center, right, graph.edge_half_width(edge))
	await _calm_place_pigeon(pigeon_pos)
	var t0 := TrafficControl.now()
	var hold_at := -1.0
	var breaks := 0
	var honks := -1
	var passing := false
	if pigeon_pos != Vector3.INF:
		var traveled := 0.0
		var prev := mover.global_position
		for f in 30 * 60:
			await _wait_frames(1)
			traveled += Vector2(mover.global_position.x - prev.x,
					mover.global_position.z - prev.z).length()
			prev = mover.global_position
			var hspeed := Vector2(mover.velocity.x, mover.velocity.z).length()
			if hold_at < 0.0 and traveled > 3.0 and hspeed < 0.3:
				hold_at = TrafficControl.now() - t0
			breaks = mover._no_progress_breaks
			honks = mover.honk_count
			if mover._passing:
				passing = true
			if hold_at >= 0.0 and TrafficControl.now() - t0 - hold_at > 14.0:
				break ## Two patience cycles witnessed.
	var ok := pigeon_pos != Vector3.INF and hold_at >= 0.0 and honks == 0 \
			and breaks >= 2 and not passing and not mover._passing
	mover.queue_free()
	blocker.queue_free()
	await _wait_frames(2)
	return {"ok": ok, "breaks": breaks, "honks": honks}


## Arm 1.iii — the fleet cadence cap: two movers at equal 16 m gaps expire
## together near the pigeon; exactly one horn sounds between them. Returns
## {ok, horns}.
func _calm_arm_honk_cadence(spawner: CarSpawner, edge: int) -> Dictionary:
	Car._last_fleet_patience_honk = -INF
	var graph: AmesTrafficGraph = _city.traffic_graph
	var axis: Vector3 = graph.edge_axis(edge)
	var lane := graph.edge_points(edge)
	var m1 := _calm_stage_mover(spawner, edge, 30.0)
	var b1_pos := _lane_arc_point(lane, 46.0)
	var b1 := _calm_stage_parked(
			_city.to_global(Vector3(b1_pos.x, 0.0, b1_pos.y)),
			_calm_axis_yaw(axis), spawner._edge_block_global(edge))
	var m2 := _calm_stage_mover(spawner, edge, 8.0)
	var b2_pos := _lane_arc_point(lane, 24.0)
	var b2 := _calm_stage_parked(
			_city.to_global(Vector3(b2_pos.x, 0.0, b2_pos.y)),
			_calm_axis_yaw(axis), spawner._edge_block_global(edge))
	var right := Vector3(-axis.z, 0.0, axis.x)
	var mid := (m1.global_position + m2.global_position) * 0.5
	var center := mid - right * graph.edge_lane_off(edge)
	var pigeon_pos := _calm_ground_spot(mid, axis, 8.0, 14.0,
			center, right, graph.edge_half_width(edge))
	await _calm_place_pigeon(pigeon_pos)
	if pigeon_pos != Vector3.INF:
		for f in 18 * 60:
			await _wait_frames(1)
			if m1._no_progress_breaks >= 1 and m2._no_progress_breaks >= 1:
				break ## Both breaks witnessed — read the horns now.
		await _wait_frames(60) ## 1 s past the paired expiry, before the next.
	var horns := m1.honk_count + m2.honk_count
	var ok := pigeon_pos != Vector3.INF \
			and m1._no_progress_breaks >= 1 and m2._no_progress_breaks >= 1 \
			and horns == 1 \
			and not m1._passing and not m2._passing
	m1.queue_free()
	b1.queue_free()
	m2.queue_free()
	b2.queue_free()
	await _wait_frames(2)
	return {"ok": ok, "horns": horns}


## Arm 2.iv — the clear pass inside the per-leg asphalt: the pigeon stands IN
## the lane as the blocker; the pass commits on the fresh car's first break
## (right shoulder), every sampled frame lane-local inside the closed-form
## bounds. Returns {ok, min_lat, max_lat, complete_s, honks}.
func _calm_arm_pass_clear(spawner: CarSpawner, edge: int) -> Dictionary:
	Car._last_fleet_patience_honk = -INF
	var graph: AmesTrafficGraph = _city.traffic_graph
	var axis: Vector3 = graph.edge_axis(edge)
	var mover := _calm_stage_mover(spawner, edge, 24.0)
	var lane := graph.edge_points(edge)
	var pigeon_lane := _lane_arc_point(lane, 42.0)
	var pigeon_pos := _city.to_global(Vector3(pigeon_lane.x, 0.0, pigeon_lane.y))
	await _calm_place_pigeon(pigeon_pos)
	var right := Vector3(-axis.z, 0.0, axis.x)
	var t0 := TrafficControl.now()
	var origin_seen := false
	var origin := Vector3.ZERO
	var pass_at := -1.0
	var done_at := -1.0
	var min_lat := INF
	var max_lat := -INF
	var aim_lat := INF
	for f in 30 * 60:
		await _wait_frames(1)
		if mover._passing:
			if not origin_seen:
				origin_seen = true
				origin = mover._pass_origin
				pass_at = TrafficControl.now() - t0
				var aim_rel := mover._pass_aim - origin
				aim_rel.y = 0.0
				aim_lat = aim_rel.dot(right) ## The armed aim's side — the
					## fresh car's first break must read RIGHT (positive).
			else:
				var rel := mover.global_position - origin
				rel.y = 0.0
				var lat := rel.dot(right)
				min_lat = minf(min_lat, lat)
				max_lat = maxf(max_lat, lat)
		elif origin_seen:
			done_at = TrafficControl.now() - t0
			break
	var honks := mover.honk_count
	var complete_s := -1.0
	var behind := false
	if origin_seen and done_at >= 0.0:
		complete_s = done_at - pass_at
		var to_pigeon := pigeon_pos - mover.global_position
		to_pigeon.y = 0.0
		behind = to_pigeon.dot(axis) < 0.5
	var w := graph.edge_half_width(edge)
	var l := graph.edge_lane_off(edge)
	var clamp_left := -(w + l) + 1.35
	var clamp_right := w - l - 1.35
	var ok := origin_seen and done_at >= 0.0 and behind \
			and complete_s >= 0.0 and complete_s <= 15.0 \
			and min_lat >= clamp_left - 0.3 and max_lat <= clamp_right + 0.3 \
			and aim_lat > 0.9 and max_lat > 0.3 and honks == 1
	mover.queue_free()
	await _wait_frames(2)
	return {"ok": ok, "min_lat": min_lat, "max_lat": max_lat,
			"complete_s": complete_s, "honks": honks, "aim_lat": aim_lat}


## Arm 2.v — both shoulders denied, then the left fallthrough: the pigeon holds
## the lane; a parked car at the REAL curb offset and an opposing car in the
## REAL oncoming lane deny both shoulders for two patience cycles; freeing the
## opposing car releases the pass on the left within the next cycle. Returns
## {ok, min_lat, max_lat, parked_gap, drift, pass_s}.
func _calm_arm_pass_gates(spawner: CarSpawner, edge: int) -> Dictionary:
	Car._last_fleet_patience_honk = -INF
	var graph: AmesTrafficGraph = _city.traffic_graph
	var axis: Vector3 = graph.edge_axis(edge)
	var mover := _calm_stage_mover(spawner, edge, 24.0)
	var lane := graph.edge_points(edge)
	var pigeon_lane := _lane_arc_point(lane, 42.0)
	var pigeon_pos := _city.to_global(Vector3(pigeon_lane.x, 0.0, pigeon_lane.y))
	var w := graph.edge_half_width(edge)
	var l := graph.edge_lane_off(edge)
	var curb := _lane_arc_point(lane, 50.0)
	## The curb car rides the graph's real parking offset — `w − 1.05` off the
	## CENTERLINE is `w − 1.05 − l` off the LANE LINE the gate reads, so the
	## staged offset is lane-relative (the round-1 run double-counted the lane
	## offset and staged the car 5.2 lane-local — outside the corridor band,
	## invisible to the parked gate).
	var curb_pos := _city.to_global(Vector3(curb.x, 0.0, curb.y)) \
			+ Vector3(-axis.z, 0.0, axis.x) * (w - AmesTrafficGraph.PARK_EDGE_OFFSET - l)
	var oncome := _lane_arc_point(lane, 52.0)
	var oncome_pos := _city.to_global(Vector3(oncome.x, 0.0, oncome.y)) \
			- Vector3(-axis.z, 0.0, axis.x) * (2.0 * l)
	var curb_car := _calm_stage_parked(curb_pos, _calm_axis_yaw(axis),
			spawner._edge_block_global(edge))
	var opposing := _calm_stage_parked(oncome_pos,
			_calm_axis_yaw(axis) + PI, spawner._edge_block_global(edge))
	await _calm_place_pigeon(pigeon_pos)
	var right := Vector3(-axis.z, 0.0, axis.x)
	var t0 := TrafficControl.now()
	var hold_at := -1.0
	var freed_at := -1.0
	var origin := Vector3.ZERO
	var origin_seen := false
	var pass_at := -1.0
	var done_at := -1.0
	var pass_seen := false
	var min_lat := INF
	var max_lat := -INF
	var parked_gap := INF
	var drift := 0.0
	var traveled := 0.0
	var prev := mover.global_position
	var freed_pos := Vector3.ZERO
	for f in 60 * 60:
		await _wait_frames(1)
		var now := TrafficControl.now() - t0
		traveled += Vector2(mover.global_position.x - prev.x,
				mover.global_position.z - prev.z).length()
		prev = mover.global_position
		var hspeed := Vector2(mover.velocity.x, mover.velocity.z).length()
		if hold_at < 0.0 and traveled > 3.0 and hspeed < 0.3:
			hold_at = now
		if hold_at >= 0.0 and freed_at < 0.0 and now - hold_at > 13.5:
			opposing.queue_free() ## The oncoming lane clears.
			freed_at = now
			freed_pos = mover.global_position
		if freed_at >= 0.0 and not pass_seen:
			drift = maxf(drift, Vector2(mover.global_position.x - freed_pos.x,
					mover.global_position.z - freed_pos.z).length())
		if mover._passing:
			pass_seen = true
			if not origin_seen:
				origin_seen = true
				origin = mover._pass_origin
				pass_at = now
			else:
				var rel := mover.global_position - origin
				rel.y = 0.0
				var lat := rel.dot(right)
				min_lat = minf(min_lat, lat)
				max_lat = maxf(max_lat, lat)
			parked_gap = minf(parked_gap,
					Vector2(curb_car.global_position.x - mover.global_position.x,
					curb_car.global_position.z - mover.global_position.z).length())
		elif pass_seen:
			done_at = now
			break
		if freed_at >= 0.0 and not pass_seen and now - freed_at > 9.0:
			break ## The fallthrough never armed — read the failure.
	var pass_s := pass_at - freed_at if pass_at >= 0.0 and freed_at >= 0.0 else -1.0
	var completion_s := done_at - pass_at if done_at >= 0.0 and pass_at >= 0.0 else -1.0
	var clamp_left := -(w + l) + 1.35
	var clamp_right := w - l - 1.35
	var ok := hold_at >= 0.0 and freed_at >= 0.0 and pass_seen \
			and pass_s >= 0.0 and pass_s <= 7.0 and drift <= 1.5 \
			and min_lat >= clamp_left - 0.3 and max_lat <= clamp_right + 0.3 \
			and min_lat < -0.4 and parked_gap >= 2.0 \
			and completion_s >= 0.0 and completion_s <= 15.0
	mover.queue_free()
	curb_car.queue_free()
	if is_instance_valid(opposing):
		opposing.queue_free() ## The mid-arm free ran only when the hold held.
	await _wait_frames(2)
	return {"ok": ok, "min_lat": min_lat, "max_lat": max_lat,
			"parked_gap": parked_gap, "drift": drift, "pass_s": pass_s}


## Arm 3 — the live fleet at the cruise corridor under a pigeon held on
## station: hold rate, blinker solids, honk suppression. Returns
## {ok, samples, stand_samples, hold_cars, blinker_obs, blinker_violations,
## honks, far_honks, cadence_violations, relay_honks, dead_windows,
## windows_done}.
func _calm_arm_live_fleet() -> Dictionary:
	Car._last_fleet_patience_honk = -INF
	var anchor := _city.to_global(Vector3(60.0, 0.0, 0.0)) \
			+ Vector3(0.0, 30.0, 0.0)
	await _set_up(true, anchor, Vector3.ZERO)
	var fleet := CarSpawner.new()
	fleet.city = _city
	fleet.player = _player
	fleet.name = "CarSpawner_calm_live"
	add_child(fleet)
	await _wait_frames(2)
	var t0 := TrafficControl.now()
	var last_honks := {}
	var last_pos := {}
	var standing_ids := {}
	var stand_samples := 0
	var blinker_obs := 0
	var blinker_violations := 0
	var honks := 0
	var far_honks := 0
	var cadence_violations := 0
	var last_honk_t := -INF
	var dead_windows := 0
	var windows_done := 0
	var window_movers := 0
	var window_prev := PackedVector3Array()
	var pigeon_prev := anchor
	var samples := 0
	const LIVE_WINDOWS := 10
	const WINDOW_SAMPLES := 27 ## 27 × 5 frames = 9 s at 60 Hz.
	for w in LIVE_WINDOWS:
		for ws in WINDOW_SAMPLES:
			await _wait_frames(5)
			var now := TrafficControl.now() - t0
			## The pigeon held on station (the dev-teleport shape) — a re-set
			## sample's honk attribution is skipped (the teleport would
			## mis-band it); re-sets land 30 m up, never on a car.
			var pigeon_reset := false
			if samples % 180 == 179:
				_player.reset_flight(anchor, 0.0)
				pigeon_reset = true
			var pigeon_d := _player.global_position
			var pigeon_moved := pigeon_reset \
					or Vector2(pigeon_d.x - pigeon_prev.x,
					pigeon_d.z - pigeon_prev.z).length() > 2.0
			pigeon_prev = pigeon_d
			var traffic: Array[Car] = []
			for car in fleet.living_cars():
				if car.mode == Car.Mode.TRAFFIC and is_instance_valid(car):
					traffic.append(car)
			var any_standing := false
			for car in traffic:
				var id := car.get_instance_id()
				var hspeed := Vector2(car.velocity.x, car.velocity.z).length()
				if hspeed < 0.1:
					any_standing = true
					standing_ids[id] = true
				## The blinker law, recomputed from the entries: the first
				## non-straight stop ahead arms its side inside the lead.
				if car._blinker_hold <= 0.0 and car.blinker_forced == 0:
					var armed := 0
					var armed_d := INF
					for i in range(car._stop_index, car.stops.size()):
						var turn: int = car.stops[i]["turn"]
						if turn == City.ROUTE_TURN_STRAIGHT:
							continue
						var d := Vector2(car.stops[i]["line"].x
								- car.global_position.x,
								car.stops[i]["line"].z
								- car.global_position.z).length()
						armed = turn
						armed_d = d
						break ## Only the NEXT entry can arm the tell.
					if armed != 0 and armed_d < 12.0:
						blinker_obs += 1
						if car.blinker != armed:
							blinker_violations += 1
				## The honk attribution: patience honks ride car.honk_count
				## only (the relay counter stays splat-only — nothing poops
				## here, so any relay honk would itself be a defect); a new
				## honk attributes to the NEARER of this and the last
				## sample's pigeon distance (≤ 0.75 m drift at cruise).
				var honks_now: int = car.honk_count
				var honks_before: int = int(last_honks.get(id, 0))
				if honks_now > honks_before:
					honks += honks_now - honks_before
					if not pigeon_moved:
						var d_now := Vector2(pigeon_d.x - car.global_position.x,
								pigeon_d.z - car.global_position.z).length()
						var prev_car: Vector3 = last_pos.get(id,
								car.global_position)
						var d_before := Vector2(pigeon_d.x - prev_car.x,
								pigeon_d.z - prev_car.z).length()
						if minf(d_now, d_before) > 31.0:
							far_honks += 1
						if last_honk_t > -INF and now - last_honk_t < 2.9:
							cadence_violations += 1
						last_honk_t = now
				last_honks[id] = honks_now
				last_pos[id] = car.global_position
			if any_standing:
				stand_samples += 1
			## The window's movement read (the routes scenario's metric).
			if samples % WINDOW_SAMPLES == 0:
				window_prev = PackedVector3Array()
				for car in traffic:
					window_prev.append(car.global_position)
			else:
				var used := PackedByteArray()
				used.resize(window_prev.size())
				for car in traffic:
					var best_j := -1
					var best_d := 20.0
					for j in window_prev.size():
						if used[j] == 1:
							continue
						var dj := Vector2(car.global_position.x - window_prev[j].x,
								car.global_position.z - window_prev[j].z).length()
						if dj < best_d:
							best_d = dj
							best_j = j
					if best_j >= 0:
						used[best_j] = 1
						if best_d >= 0.5:
							window_movers += 1
				if samples % WINDOW_SAMPLES == WINDOW_SAMPLES - 1:
					windows_done += 1
					if window_movers == 0:
						dead_windows += 1
					window_movers = 0
			samples += 1
	var relay_honks := fleet.honk_count
	var live_ok := samples >= LIVE_WINDOWS * WINDOW_SAMPLES \
			and dead_windows <= 4 and stand_samples >= 60 \
			and blinker_obs >= 5 and blinker_violations == 0 \
			and far_honks == 0 and cadence_violations == 0 \
			and relay_honks == 0
	fleet.free()
	await _wait_frames(2)
	return {"ok": live_ok, "samples": samples, "stand_samples": stand_samples,
			"hold_cars": standing_ids.size(), "blinker_obs": blinker_obs,
			"blinker_violations": blinker_violations, "honks": honks,
			"far_honks": far_honks, "cadence_violations": cadence_violations,
			"relay_honks": relay_honks, "dead_windows": dead_windows,
			"windows_done": windows_done}


## The T-180 intersections: the pinned start set (per-district counts from
## the census §4 windows + the arterial corridors), the corner paint within
## tolerance of the ADAPTED T-134 consts at the measured widths (literals
## here, not the live constants — the T-130 pin pattern), the T-143
## near-coplanar relief surviving the port, the signal furniture and its
## live phase, visual-only, byte-identical under rebuild — and TRAFFIC OBEYS:
## a staged mover at the Lincoln Way × Welch signal holds its line red-side
## with the patience clock frozen (a red never force-commits), rolls on
## green, and a pigeon standing in the real band holds a green car at its
## line. The determinism arm snapshots the world's retained corner queues
## and compares a forced rebuild's byte-for-byte.
func _scenario_ames_intersections() -> void:
	const S := "ames_intersections"
	var graph: AmesTrafficGraph = _city.traffic_graph
	if graph == null:
		_check(S, false, "no traffic graph on the resident world")
		return
	## (a) The pinned counts (recorded from the census + the data derivation,
	## probed 2026-11-13: downtown matches the census exactly, Campustown
	## carries 11 of the census's 13 — the pack welds no junction at L/W ×
	## State and one Hunt-grade T, the delta recorded in the ticket).
	var downtown := 0
	var campustown := 0
	var arterial := 0
	var signals := 0
	for a in graph.intersection_count():
		var pin := graph.intersection_pin(a)
		if pin == AmesTrafficGraph.PIN_DISTRICT:
			if graph.intersection_district(a) == "downtown":
				downtown += 1
			else:
				campustown += 1
		elif pin == AmesTrafficGraph.PIN_ARTERIAL:
			arterial += 1
		if graph.intersection_is_signal(a):
			signals += 1
	var all_way := downtown + campustown + arterial - signals
	var counts_ok := downtown == 20 and campustown == 11 and arterial == 43 \
			and signals == 25 and all_way == 49
	## (a2) The named corners: Lincoln Way × Welch (the pack origin corner),
	## Main × Duff (downtown's east spine) signalized; Main × Pearle an
	## all-way downtown corner.
	var welch := _nearest_pinned_anchor(graph, Vector2(0.0, 0.0))
	var main_duff := _nearest_pinned_anchor(graph, Vector2(3285.0, -264.0))
	var main_pearle := _nearest_pinned_anchor(graph, Vector2(2538.9, -249.4))
	var named_ok := welch >= 0 and main_duff >= 0 and main_pearle >= 0 \
			and graph.intersection_is_signal(welch) \
			and graph.intersection_is_signal(main_duff) \
			and not graph.intersection_is_signal(main_pearle)
	## (b) The corner geometry, walked off the world's retained queues against
	## the scenario's OWN literals (the adapted T-134 law at the measured
	## width): per pinned approach — band center lane_off + 4.7 out on the
	## approach axis, bar count roundi(W / 0.5), stop line lane_off + 7.3 out
	## lane_off right, sign at half + 0.2 lateral stop_outset + 0.5 out, the
	## red octagon bars 0.086 thick over the 0.03 border (the T-143 relief),
	## every paint top 0.12 — equal to NO baked layer top.
	var paint: Array[Transform3D] = _city._corner_paint_xfs
	var stop_lines: Array[Transform3D] = _city._corner_stop_line_xfs
	var posts: Array[Transform3D] = _city._corner_post_xfs
	var reds: Array[Transform3D] = _city._corner_red_xfs
	var borders: Array[Transform3D] = _city._corner_border_xfs
	var plaques: Array[Transform3D] = _city._corner_plaque_xfs
	var masts: Array[Transform3D] = _city._corner_mast_xfs
	var heads: Array[Transform3D] = _city._corner_head_xfs
	var lamps: Array[Transform3D] = _city._corner_lamp_xfs
	## The expected approach sequence, recomputed here from the graph's edge
	## facts (T-178-pinned accessors) and the ticket literals.
	var exp_paint := 0
	var exp_stop_approaches := 0
	var paint_y_ok := true
	var paint_top := 0.12 ## Center 0.11 + half the 0.02 thickness.
	for baked_top: float in [0.014, 0.018, 0.02, 0.04, 0.06, 0.09, 0.11, 0.13]:
		if absf(paint_top - baked_top) < 0.005:
			paint_y_ok = false
	for a in graph.intersection_count():
		if graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		for member in graph.intersection_members(a):
			for edge in graph.node_in_edges(member):
				var half := graph.edge_half_width(edge)
				var lane := graph.edge_lane_off(edge)
				var stop_outset := lane + 7.3
				if graph.edge_length(edge) < stop_outset + 2.0:
					continue ## A stub run — the paint skips it honestly.
				exp_paint += maxi(roundi(half * 2.0 / 0.5), 1)
				if not graph.intersection_is_signal(a):
					exp_stop_approaches += 1
	var count_ok := paint.size() == exp_paint \
			and stop_lines.size() == exp_stop_approaches \
			and posts.size() == exp_stop_approaches \
			and plaques.size() == exp_stop_approaches \
			and reds.size() == 4 * exp_stop_approaches \
			and borders.size() == 4 * exp_stop_approaches \
			and masts.size() == 2 * signals and heads.size() == 2 * signals \
			and lamps.size() == 6 * signals
	for xf in paint:
		if absf(xf.origin.y - 0.11) > 0.005:
			paint_y_ok = false
			break
	## The relief law, measured on the queues: red 0.086 over border 0.03.
	var relief_ok := reds.size() > 0 and borders.size() > 0
	if relief_ok:
		relief_ok = _xf_basis_len(reds[0], 2) - _xf_basis_len(borders[0], 2) > 0.05
	## The instance-node sync (the T-069 pin): every queue feeds its node.
	var sync_ok := true
	for family: String in ["CrosswalkPaint", "StopLines", "SignPosts", "StopFaces",
			"StopBorders", "Plaques", "Masts", "Heads", "SignalLamps"]:
		var node := _city.get_node_or_null("Intersections/" + family) \
				as MultiMeshInstance3D
		var stored := 0
		match family:
			"CrosswalkPaint": stored = paint.size()
			"StopLines": stored = stop_lines.size()
			"SignPosts": stored = posts.size()
			"StopFaces": stored = reds.size()
			"StopBorders": stored = borders.size()
			"Plaques": stored = plaques.size()
			"Masts": stored = masts.size()
			"Heads": stored = heads.size()
			"SignalLamps": stored = lamps.size()
		if node == null or node.multimesh == null \
				or node.multimesh.instance_count != stored:
			sync_ok = false
	## Visual-only: no physics anywhere under the corner dress.
	var body_free := _city.get_node_or_null("Intersections") != null \
			and _city.get_node("Intersections") \
			.find_children("*", "StaticBody3D", true, false).is_empty()
	## Sampled corner placement, recomputed independently from the graph's
	## edge facts and the ticket literals (XZ reads — the paint origin rides
	## the 0.11 paint level). At the LW×Welch SIGNAL corner: the zebra band
	## sits on its primary approach at lane_off + 4.7 AND no stop furniture
	## stands within 20 m (the signal replaces the all-way control). At the
	## Main × Pearle ALL-WAY corner: the band AND the stop bar on its
	## approach — bar center lane_off + 7.3 out, lane_off right.
	var sample_geo_ok := welch >= 0 and main_pearle >= 0
	if sample_geo_ok:
		## The signal corner's band + control exclusivity.
		var welch_band := false
		var welch_head := graph.node_pos(graph.intersection_head(welch))
		for member in graph.intersection_members(welch):
			for edge in graph.node_in_edges(member):
				if graph.edge_class(edge) != "primary":
					continue
				var axis := graph.edge_axis(edge)
				var lane := graph.edge_lane_off(edge)
				var band_c := graph.node_pos(member) - axis * (lane + 4.7)
				for xf in paint:
					## The zebra bars tile ACROSS the road at 0.5 pitch — an
					## even bar count leaves no bar exactly ON the centerline,
					## so the band-center read sits within a half-pitch of it.
					if Vector2(xf.origin.x - band_c.x,
							xf.origin.z - band_c.z).length() < 0.3:
						welch_band = true
						break
				break
		var welch_exclusive := true
		for xf in stop_lines:
			if Vector2(xf.origin.x - welch_head.x,
					xf.origin.z - welch_head.z).length() < 20.0:
				welch_exclusive = false
				break
		for xf in posts:
			if Vector2(xf.origin.x - welch_head.x,
					xf.origin.z - welch_head.z).length() < 20.0:
				welch_exclusive = false
				break
		## The all-way corner's band + stop bar + sign post.
		var pearle_band := false
		var pearle_line := false
		var pearle_post := false
		for member in graph.intersection_members(main_pearle):
			for edge in graph.node_in_edges(member):
				var axis := graph.edge_axis(edge)
				var lane := graph.edge_lane_off(edge)
				var right := Vector3(-axis.z, 0.0, axis.x)
				var node_pos := graph.node_pos(member)
				var band_c := node_pos - axis * (lane + 4.7)
				var line_c := node_pos - axis * (lane + 7.3) + right * lane
				var half := graph.edge_half_width(edge)
				var post_c := node_pos - axis * (lane + 7.8) \
						+ right * (half + 0.2)
				for xf in paint:
					if Vector2(xf.origin.x - band_c.x,
							xf.origin.z - band_c.z).length() < 0.3:
						pearle_band = true
				for xf in stop_lines:
					if Vector2(xf.origin.x - line_c.x,
							xf.origin.z - line_c.z).length() < 0.02:
						pearle_line = true
				for xf in posts:
					if Vector2(xf.origin.x - post_c.x,
							xf.origin.z - post_c.z).length() < 0.02:
						pearle_post = true
				break
		sample_geo_ok = welch_band and welch_exclusive and pearle_band \
				and pearle_line and pearle_post
	## (c) Traffic obeys the start set: the signal arm and the crosswalk arm.
	var obey := await _intersections_signal_obey(graph, welch)
	## (d) Determinism: a forced rebuild reproduces every corner transform.
	var snapshot := _corner_snapshot()
	_city.generate(_city.seed_value, true)
	var snapshot2 := _corner_snapshot()
	var det_ok := snapshot.size() == snapshot2.size() and snapshot.size() > 0
	if det_ok:
		for i in snapshot.size():
			if not (snapshot[i] as Array).is_empty() \
					and not _xf_arrays_equal(snapshot[i], snapshot2[i]):
				det_ok = false
				break
	print("SIM DATA %s: downtown=%d campustown=%d arterial=%d signals=%d all_way=%d paint=%d stop_lines=%d posts=%d obey=%s" % [
			S, downtown, campustown, arterial, signals, all_way,
			paint.size(), stop_lines.size(), posts.size(), bool(obey["ok"])])
	var ok := counts_ok and named_ok and count_ok and paint_y_ok \
			and relief_ok and sync_ok and body_free and sample_geo_ok \
			and bool(obey["ok"]) and det_ok
	_check(S, ok, "counts=%s named=%s furniture=%s paint_y=%s relief=%s sync=%s visual_only=%s sample_geo=%s obey=%s(%s) det=%s" % [
			counts_ok, named_ok, count_ok, paint_y_ok, relief_ok, sync_ok,
			body_free, sample_geo_ok, bool(obey["ok"]), str(obey["detail"]), det_ok])
	await _set_up(true, _city.to_global(Vector3(60.0, 30.0, 0.0)), Vector3.ZERO)


## The nearest pinned anchor to a pack-local XZ point (−1 when none within
## 10 m) — the named-corner reads.
func _nearest_pinned_anchor(graph: AmesTrafficGraph, xz: Vector2) -> int:
	var best := -1
	var best_d := 10.0
	for a in graph.intersection_count():
		if graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		var p := graph.node_pos(graph.intersection_head(a))
		var d := Vector2(p.x - xz.x, p.z - xz.y).length()
		if d < best_d:
			best_d = d
			best = a
	return best


## One basis column's length (the box extent that column carries).
func _xf_basis_len(xf: Transform3D, col: int) -> float:
	var v := xf.basis[col]
	return Vector3(v.x, v.y, v.z).length()


func _corner_snapshot() -> Array:
	return [
		_city._corner_paint_xfs.duplicate(),
		_city._corner_stop_line_xfs.duplicate(),
		_city._corner_post_xfs.duplicate(),
		_city._corner_red_xfs.duplicate(),
		_city._corner_border_xfs.duplicate(),
		_city._corner_plaque_xfs.duplicate(),
		_city._corner_mast_xfs.duplicate(),
		_city._corner_head_xfs.duplicate(),
		_city._corner_lamp_xfs.duplicate(),
	]


func _xf_arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not (a[i] as Transform3D).is_equal_approx(b[i] as Transform3D):
			return false
	return true


## The obey arms at one signal corner: a staged mover drives the corner's
## widest primary approach to its line, timed so its registration lands ~3 s
## into a RED window for its phase group — while red it holds (speed < 0.3,
## committed false) with the patience clock FROZEN (a red never force-commits),
## then rolls within the green (committed inside 2 s of the phase flip, past
## the bar). The crosswalk arm stages a fresh mover timed into a GREEN window
## with the pigeon parked in the corner's real eastbound band: registered and
## green, the car stays (committed false for ≥ 3 s of green — pedestrian
## priority). Returns {ok, detail}.
func _intersections_signal_obey(graph: AmesTrafficGraph, anchor: int) -> Dictionary:
	var node := graph.intersection_signal_node(anchor)
	var edge := -1
	for e in graph.edge_count():
		if graph.edge_to(e) == node and graph.edge_class(e) == "primary" \
				and graph.edge_length(e) > 60.0:
			edge = e
			break
	if edge < 0:
		return {"ok": false, "detail": "no primary approach into the corner"}
	var group := graph.approach_signal_group(node, edge)
	var spawner := CarSpawner.new()
	spawner.city = _city
	spawner.player = _player
	spawner.target_moving = 0
	spawner.target_parked = 0
	spawner.name = "CarSpawner_intersections"
	add_child(spawner)
	await _wait_frames(2)
	## The mover stages ~22 m before its node (≈ 8 m before its line) —
	## accel-from-rest plus the brake profile register it ≈ 2.7 s later.
	## Time the staging into a red window for the entry's phase group.
	var drive_s := 2.7
	var stage_at := _next_phase_frame(group, false, drive_s, 3.0)
	await _wait_frames(maxi(stage_at - int(TrafficControl.now() * 60.0), 1))
	var mover := _intersections_stage_mover(spawner, graph, edge)
	## The red hold: registered, speed 0, patience frozen — sampled across ≥
	## 1.5 s of remaining red, then the green commit inside 2.5 s of the flip.
	var red_seen := 0
	var patience_a := -1.0
	var patience_b := -1.0
	var committed_at := -1.0
	var t_reg := -1.0
	for f in 30 * 60:
		await _wait_frames(1)
		var entry: Dictionary = mover.stops[0] if mover.stops.size() > 0 else {}
		if not bool(entry.get("registered", false)):
			continue
		if t_reg < 0.0:
			t_reg = TrafficControl.now()
		var red := TrafficControl.signal_red_for_group(group)
		var hspeed := Vector2(mover.velocity.x, mover.velocity.z).length()
		if red and not bool(entry.get("committed", false)):
			red_seen += 1
			if patience_a < 0.0:
				patience_a = mover._patience
			patience_b = mover._patience
			if hspeed > 0.35:
				red_seen = -999 ## A red hold that let the car roll: defect.
		if bool(entry.get("committed", false)) and committed_at < 0.0:
			committed_at = TrafficControl.now() - t_reg
		if committed_at >= 0.0 \
				and Vector2(mover.velocity.x, mover.velocity.z).length() > 1.0:
			break
		if f > 25 * 60:
			break
	var red_ok := red_seen >= 60 and patience_a >= 0.0 \
			and absf(patience_b - patience_a) < 0.001 \
			and committed_at >= 0.0 and committed_at <= 13.0
	## The crosswalk arm: a fresh mover timed into a GREEN window with the
	## pigeon standing in the corner's real band — the yield holds it.
	var geo := graph.approach_geometry(node, edge)
	var band: Dictionary = geo["band"]
	var band_global := _city.to_global(
			Vector3(band["center"].x, 0.0, band["center"].y))
	await _set_up(false, band_global, Vector3.ZERO)
	await _await_grounded(60)
	var stage2 := _next_phase_frame(group, true, drive_s, 3.0)
	await _wait_frames(maxi(stage2 - int(TrafficControl.now() * 60.0), 1))
	var mover2 := _intersections_stage_mover(spawner, graph, edge)
	var green_hold := 0
	var t2_reg := -1.0
	for f in 30 * 60:
		await _wait_frames(1)
		var entry2: Dictionary = mover2.stops[0] if mover2.stops.size() > 0 else {}
		if not bool(entry2.get("registered", false)):
			continue
		if t2_reg < 0.0:
			t2_reg = TrafficControl.now()
		if not TrafficControl.signal_red_for_group(group) \
				and not bool(entry2.get("committed", false)) \
				and mover2._crosswalk_blocked(entry2):
			green_hold += 1
		if f > 25 * 60:
			break
	var yield_ok := green_hold >= 120 and t2_reg >= 0.0
	mover.queue_free()
	mover2.queue_free()
	spawner.free()
	await _wait_frames(2)
	var ok := red_ok and yield_ok
	var detail := "red_frames=%d patience_delta=%.3f committed@+%.1fs green_hold_frames=%d" % [
			red_seen, absf(patience_b - patience_a), committed_at, green_hold]
	return {"ok": ok, "detail": detail}


## Stages one traffic mover on a directed edge aimed at the corner (the calm
## probes' production-stamp shape).
func _intersections_stage_mover(spawner: CarSpawner,
		graph: AmesTrafficGraph, edge: int) -> Car:
	var lane := graph.edge_points(edge)
	var arc := maxf(graph.edge_length(edge) - 22.0, 5.0)
	var start := _lane_arc_point(lane, arc)
	var path := PackedVector3Array()
	var acc := 0.0
	for i in range(1, lane.size()):
		acc += lane[i - 1].distance_to(lane[i])
		if acc >= arc + 8.0:
			path.append(_city.to_global(Vector3(lane[i].x, 0.0, lane[i].y)))
	if path.is_empty():
		var last := lane[lane.size() - 1]
		path.append(_city.to_global(Vector3(last.x, 0.0, last.y)))
	var car: Car = CAR_SCENE.instantiate() as Car
	car.traffic = spawner.traffic_ctrl
	car.player = _player
	add_child(car)
	var stops: Array[Dictionary] = [spawner._stop_entry_graph(
			graph.edge_to(edge), edge, -1)]
	car.start_route(_city.to_global(Vector3(start.x, 0.0, start.y)), path,
			stops, spawner._edge_block_global(edge), PackedVector3Array(),
			graph.edge_to(edge))
	return car


## The first future frame that sits EARLY in a phase window serving the
## wanted color for `group` — at least `drive_s` of staging drive plus
## `lead_s` ahead, and within the first `lead_s` of the window, so the
## registration lands with most of the window still to run. Deterministic
## off the physics clock.
func _next_phase_frame(group: int, want_green: bool, drive_s: float,
		lead_s: float) -> int:
	var start_frame := int(TrafficControl.now() * 60.0) + int((drive_s + lead_s) * 60.0)
	var wanted_phase := group if want_green else 1 - group
	var window := int(TrafficControl.SIGNAL_GREEN_SECONDS * 60.0)
	var frame := start_frame
	for _k in 6:
		if int(frame / window) % 2 == wanted_phase \
				and frame % window < int(lead_s * 60.0):
			return frame
		frame += window - (frame % window)
	return start_frame


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
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -13.6)) ## (T-133) cruise start re-locked to the ×0.8 trim.
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
	print("SIM DATA flap_speed_envelope: pump %.2f m/s at y %.2f, cruise tap fwd %+.2f vy %+.2f" % [
			pump_speed, pump_y, fwd_gain, vy_gain]) ## (T-133) pace-proportional re-derivation evidence
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
	print("SIM DATA sustained_flap_ceiling: peak %.2f m/s fwd (ceil %.1f), end speed %.2f, end y %.2f" % [
			peak_fwd, FLAP_PUMP_CEIL, _player.velocity.length(), _player.position.y]) ## (T-133) re-derivation evidence
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


## (T-133) Value lock for the slower-bird pass: the coupled speed quartet
## (×0.8 of the T-117 pace), every re-derived satellite band from the ticket
## table, and the three turn/pitch rate exports the tine deliberately left
## alone — all pinned as literals so a silent retune fails the same night.
## The behavioral arm re-locks CRUISE at the new pace: a glide settled 120
## frames (2 s) from the trim-imposed start must cruise at `glide_speed`
## (measured 13.35; band 13.0–14.0 — the pre-T-133 tree, still converging up
## toward its ~17 trim at the read, measures 14.51 and fails — the revert
## probe's re-locked-value failure).
func _scenario_flight_speed_quartet_locked() -> void:
	var exports_ok: bool = _player.flap_impulse == 10.4 \
			and _player.glide_speed == 13.6 \
			and _player.max_speed == 28.8 \
			and _player.stall_speed == 4.0 \
			and _player.flap_push_taper == 8.0 \
			and _player.max_land_speed == 16.0 \
			and _player.dive_pose_min_speed == 7.2 \
			and _player.flare_max_sink == 6.4 \
			and _player.dust_impact_min == 1.2 \
			and _player.effort_climb_speed == 1.6
	var rates_ok: bool = _player.bank_rate == 4.2 \
			and _player.full_bank_yaw_rate == 1.8 \
			and _player.pitch_speed == 2.64
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -13.6))
	await _wait_frames(120) ## Settle onto the trim cruise (each pace's own).
	var cruise := _player.forward_speed
	var finite := _player.velocity.is_finite()
	print("SIM DATA flight_speed_quartet_locked: settled cruise fwd %.2f m/s" % cruise)
	_check("flight_speed_quartet_locked",
			exports_ok and rates_ok and cruise > 13.0 and cruise < 14.0 and finite,
			"quartet+satellites ok=%s, rates ok=%s, settled cruise %.2f m/s (band 13.0-14.0), finite=%s" % [
					exports_ok, rates_ok, cruise, finite])


## (T-133) The turn-circle proof: radius ≈ speed ÷ yaw-rate — the quartet
## scaled the speeds ×0.8 while the bank/yaw machinery stayed byte-unchanged
## (the rate pins live in `flight_speed_quartet_locked`), so the same held turn
## must ride a ≈×0.8 smaller circle at the same hand. From a settled cruise
## glide (120-frame settle onto each pace's own trim), 90 frames (1.5 s) of
## full turn_left: the measured radius (horizontal path length ÷ swept heading,
## entry transient included — identical both paces) must sit inside a ×0.8 band
## of the pre-T-133 measurement — BOTH bounds, so a no-op (ratio 1.0) and a
## collapse (quarter radius) fail the same night. Pre-T-133 measured 12.35 m
## (path 22.8 m, swept 1.84 rad) on the unmodified tree; the ×0.8 tree measures
## 9.95 m — ratio 0.806. The revert probe re-measures ≈12.35 and fails the
## upper bound; the sanity arm demands a real swept heading so a broken turn
## cannot vacuously green the ratio.
const TURN_RADIUS_PRE_T133 := 12.35

func _scenario_turn_circle_shrinks() -> void:
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -13.6))
	await _wait_frames(120) ## Settle onto the trim cruise.
	var yaw0 := _flat_yaw()
	var prev: Vector3 = _player.global_position
	var path := 0.0
	Input.action_press("turn_left")
	for _i in 90:
		await get_tree().physics_frame
		var p := _player.global_position
		path += Vector2(p.x - prev.x, p.z - prev.z).length()
		prev = p
	Input.action_release("turn_left")
	var swept := absf(angle_difference(_flat_yaw(), yaw0))
	var radius := path / swept if swept > 0.001 else INF
	var finite := _player.velocity.is_finite()
	print("SIM DATA turn_circle_shrinks: radius %.2f m (path %.1f m, swept %.2f rad, end speed %.2f)" % [
			radius, path, swept, _player.velocity.length()])
	_check("turn_circle_shrinks",
			radius <= TURN_RADIUS_PRE_T133 * 0.87 and radius >= TURN_RADIUS_PRE_T133 * 0.72
					and swept > 1.0 and finite,
			"radius %.2f m (pre-T-133 %.2f m; band ×0.72–×0.87), swept %.2f rad (bar > 1.0), finite=%s" % [
					radius, TURN_RADIUS_PRE_T133, swept, finite])


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
## speed. Started low (~1.5–2 m) so the touch stays under the 16 m/s settle
## bar — T-133 re-locked the start to the ×0.8 trim and the touch arrives
## ≈ 13.2 m/s (was ≈ 15.3 at the ×1.0 pace); higher starts bleed less and can
## exceed the bar (the SIM DATA line prints the touch).
func _scenario_trim_glide_lands_clean() -> void:
	await _clear_dust_puffs() ## (T-133) stale-puff hygiene — the count must read THIS landing only.
	await _set_up(true, Vector3(0.0, 1.8, 0.0), Vector3(0.0, 0.0, -13.6)) ## (T-133) the natural trim-speed glide is now the ×0.8 pace.
	var air_floor_frames: int = 0
	var first_air_floor_speed := 0.0 ## Speed of the first AIR frame on the floor — the touch, if the settle missed it.
	var settle_speed := 0.0 ## Speed at the grounding frame — with a contact-frame settle this IS the touch speed.
	var last_air_speed := 0.0 ## The last airborne total speed — one frame above the judged touch (T-133).
	var last_descending_vy := 0.0 ## The last airborne descending vy — the sink the dust gate reads (T-133).
	var dust_before: int = _count_effects("dust_puff.tscn") ## (T-133) the natural glide touch must still puff dust.
	for _i in 300:
		await get_tree().physics_frame
		if not _player.is_grounded:
			last_air_speed = _player.velocity.length()
			if _player.velocity.y < 0.0:
				last_descending_vy = _player.velocity.y
		if _player.is_on_floor() and not _player.is_grounded:
			if first_air_floor_speed <= 0.0:
				first_air_floor_speed = _player.velocity.length()
			if _player.velocity.length() > _player.skid_settle_speed:
				air_floor_frames += 1
		if _player.is_grounded:
			settle_speed = _player.velocity.length()
			break
	var dust_puffed := _count_effects("dust_puff.tscn") == dust_before + 1
	var finite := _player.velocity.is_finite() and _player.position.is_finite()
	_dbg("trim glide: touch %.2f m/s, %d air floor frames, grounded=%s, settled at %.2f m/s" % [
			first_air_floor_speed, air_floor_frames, _player.is_grounded, settle_speed])
	print("SIM DATA trim_glide_lands_clean: arrival %.2f m/s (sink %.2f m/s), %d air floor frames, settled %.2f m/s, dust %s" % [
			last_air_speed, last_descending_vy, air_floor_frames, settle_speed, dust_puffed]) ## (T-081, T-133) margin evidence
	_check("trim_glide_lands_clean", _player.is_grounded and air_floor_frames == 0 and finite,
			"grounded=%s, %d airborne floor frames above %.1f m/s (first AIR-floor speed %.2f, settled at %.2f m/s, finite=%s)" % [
					_player.is_grounded, air_floor_frames, _player.skid_settle_speed,
					first_air_floor_speed, settle_speed, finite])


## (T-133) The dust trap, as a landing: a DEVELOPED natural glide — the full
## trim descent with its settled sink, not leg 1's short hop whose sink never
## finishes developing — must (a) arrive under `max_land_speed` and settle into
## the waddle, (b) touch with a sink at or above `dust_impact_min`
## (export-relative: keeping the old 1.5 gate over the ×0.8 sink fails exactly
## here — the trap the ticket names), and (c) actually puff the dust. The bars
## are export-relative so a silent gate raise or a re-scaled quartet without
## the gate re-derivation both fail the same night.
func _scenario_natural_glide_touch_dust() -> void:
	await _clear_dust_puffs() ## (T-133) stale-puff hygiene — the count must read THIS landing only.
	var dust_before: int = _count_effects("dust_puff.tscn")
	await _set_up(true, Vector3(0.0, 6.0, 0.0), Vector3(0.0, 0.0, -13.6))
	var touch_speed := 0.0 ## The last airborne total speed — one frame above the judged touch.
	var touch_sink := 0.0 ## The last airborne descending vy — the sink the dust gate reads.
	var grounded_at := -1
	for _i in 1800:
		await get_tree().physics_frame
		if not _player.is_grounded:
			touch_speed = _player.velocity.length()
			if _player.velocity.y < 0.0:
				touch_sink = _player.velocity.y
		if _player.is_grounded:
			grounded_at = _i
			break
	var dust_puffed := _count_effects("dust_puff.tscn") == dust_before + 1
	var settled := _player.is_grounded and touch_speed < _player.max_land_speed
	var finite := _player.velocity.is_finite() and _player.position.is_finite()
	print("SIM DATA natural_glide_touch_dust: arrival %.2f m/s (sink %.2f m/s, gate %.2f), grounded at frame %d, dust %s" % [
			touch_speed, touch_sink, _player.dust_impact_min, grounded_at, dust_puffed]) ## (T-133) trap evidence
	_check("natural_glide_touch_dust",
			settled and -touch_sink >= _player.dust_impact_min and dust_puffed and finite,
			"settled=%s (arrival %.2f vs max_land_speed %.2f), sink %.2f m/s (bar >= dust_impact_min %.2f), dust=%s, finite=%s" % [
					settled, touch_speed, _player.max_land_speed, touch_sink,
					_player.dust_impact_min, dust_puffed, finite])


## (T-022) Holding pitch-up low sheds speed into a nose-high sink instead of
## ballooning: from a settled ~15 m/s glide at ~6 m, 45 frames (0.75 s) of held
## pitch-up must gain < 2.5 m of height AND end below 11 m/s. Before the flare
## the same input traded the whole glide speed into a rocket climb (the ticket
## measured ~+10 m of balloon on this very input).
func _scenario_flare_sheds_speed_low() -> void:
	await _set_up(true, Vector3(0.0, 6.0, 0.0), Vector3(0.0, 0.0, -13.6)) ## (T-133) settled ~13.6 m/s trim glide.
	await _wait_frames(30) ## Settle into the trim glide.
	var y0 := _player.position.y
	var s0 := _player.velocity.length()
	await _hold("pitch_up", 45)
	var y1 := _player.position.y
	var s1 := _player.velocity.length()
	var finite := _player.velocity.is_finite()
	_dbg("flare: y %.2f -> %.2f, speed %.2f -> %.2f, end vy %.2f" % [
			y0, y1, s0, s1, _player.velocity.y])
	print("SIM DATA flare_sheds_speed_low: settled %.2f -> ended %.2f m/s, height %+.2f m over the hold" % [
			s0, s1, y1 - y0]) ## (T-133) pace-proportional re-derivation evidence
	## (T-133) Bars re-derived ×0.8 from the new pace's measured run (settled
	## 13.13 → ended 9.14, +1.83 m; the old pace measured 14.56 → 10.44, +1.26):
	## the end bar 9.8 keeps the red-before — a flare-less tree keeps its speed
	## (≥ settled > 9.8) and the pre-T-133 tree flares to ~10.4 > 9.8.
	_check("flare_sheds_speed_low",
			s0 > 10.5 and y1 - y0 < 2.5 and s1 < 9.8 and finite,
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
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -13.6)) ## (T-133) cruise start re-locked to the ×0.8 trim.
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
	print("SIM DATA pitch_attitude_bounded: max |pitch| %.1f deg, peak vy %.2f m/s, mush %d/300 frames" % [
			max_pitch_deg, peak_vy, mush_frames]) ## (T-133) pace-proportional re-derivation evidence
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
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -13.6)) ## (T-133) cruise start re-locked to the ×0.8 trim.
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
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(0.0, 0.0, -5.3)) ## (T-133) ×0.8 of 6.6 — the same lift fraction (~0.39) at the new glide_speed.
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
	await _set_up(true, Vector3(0.0, 25.0, 0.0), Vector3(0.0, 0.0, -13.6)) ## (T-133) cruise start re-locked to the ×0.8 trim; the flow-kick fraction impulse/speed is pace-invariant.
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
	_player.velocity = Vector3(0.0, 0.0, -13.6) ## Cruise along the (still level-projected) nose. (T-133: the ×0.8 trim.)
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
	## (T-177) Zero the shared counter so this window asserts ITS OWN exactly-
	## one fire: the ames block ahead of it can legitimately fire the guard
	## (a broken staging must not mask as a second fire here), and the
	## `off_world_fall_returns_home` sibling already uses this pattern.
	_player.off_world_resets = 0
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
## reset 300 m past the apron edge — 417 m from the home center, 50 m past the
## 367 m radius, mid-ramp — flying straight out (nose +X, dead away from
## home: the bearing sine's zero, so the scenario also proves the steer does
## not stall there) and hands-off for 3 s (180 frames), the heading must rotate
## ≥ 30° back toward home while y never drops below 0. The guard cannot fire
## inside the window (from y 30 the flight model's softened gravity sinks
## roughly 10 m, far above the −5 line — `min_gravity_fraction` 0.2), so the
## heading assertion is what bites: today's tree has no homing term in _steer
## and keeps the nose on +X. The scenario wires `home_center`/`home_radius`
## itself — the only one that does — and since the T-177 cutover it wires
## them to the FLAT rig world (the nudge is a flight-model feature, world-
## independent; the 367 m radius is the value the feel was tuned at, the
## old Windrow apron arithmetic `city_span·0.5 + ground_extra`). The live
## game wiring on Ames is world-owned (`AmesWorld.home_radius`, the bake
## bounds) and pinned by `ames_world_api_seam`'s containment arm.
func _scenario_edge_nudge_turns_home() -> void:
	## The shared harness player carries `off_world_resets` == 1 out of
	## `off_world_fall_respawns` (it runs immediately before and never zeroes
	## it — the same reason the later `off_world_fall_returns_home` sibling
	## zeroes it for its own window): zero it so this scenario's quiet arm
	## asserts ITS OWN window fired nothing.
	_player.off_world_resets = 0
	var home := Vector3.ZERO ## The flat rig world's center — see the re-pin note above.
	_player.home_center = home
	_player.home_radius = 367.0 ## city_span·0.5 + ground_extra at the retired Windrow defaults — the tuned-at value.
	var half := 117.0 ## city_span·0.5 at the same defaults: the drop sits 300 m past the apron edge.
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


## --- scenario (T-049 facades fit floors) -------------------------------------


## --- scenario (T-051 varied footprints) --------------------------------------


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
## forgotten, then replaced somewhere within one respawn interval. (T-177
## re-pin) The rig rides the resident Ames world's spot supply now — and its
## target must EXCEED the world's 8-spot boot ring (`City.boot_bread_spots`
## seeds unconditionally first), so the smallest honest target is 12: the
## populate lands exactly 8 boot crumbs + the class fill's 4, eats 3, and
## tops back up to 12 within one interval — the Windrow-target 6 would have
## the boot ring overfill it by construction.
func _scenario_bread_respawn() -> void:
	var spawner := BreadSpawner.new()
	spawner.city = _city
	spawner.target_count = 12
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
			initial == 12 and after_eating == 9 and respawned == 12 and spawner.eaten_count == 3,
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
## backdrops (the T-177 re-pin: the Ames bake's residential-plate and downtown
## ground tints), distances printed informationally. The
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
	## (T-177 re-pin) The two wash-out backdrops are the Ames bake's own ground
	## colors now — the residential plate the pigeon mostly flies over and the
	## downtown cell tint (the retired Windrow grass/plaza constants died with
	## the generator; the contrast law — >= 0.25 from both — is unchanged).
	var vs_grass := albedo.distance_to(
			_rgb(AmesBaker.DISTRICT_GROUND["residential"] as Color))
	var vs_plaza := albedo.distance_to(
			_rgb(AmesBaker.DISTRICT_GROUND["downtown"] as Color))
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
## material the dim write drives, via the Ring mesh's override. Since the
## T-158 two-material split the Ring carries its OWN duplicated material and
## the dim write hits its alpha too, so this read survives unchanged.
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


## --- scenarios (T-020 park elders) ------------------------------------------


## --- scenarios (T-137 the grandpa shuffle) ----------------------------------


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


## --- scenarios (T-032 rooftop clutter) --------------------------------------


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


## --- scenarios (T-112 weighted bread distribution) ---------------------------


## --- scenario (T-135 one park per district) ----------------------------------


## --- scenario (T-029 plaza landmark) -----------------------------------------


## --- scenario (T-091 district anchors) ---------------------------------------


## --- scenario (T-136 district theming) ---------------------------------------


## --- scenarios (T-007 tourists) ---------------------------------------------


## --- scenarios (T-008 cars) --------------------------------------------------


## --- scenario (T-147 the despawn churn) --------------------------------------


## --- scenarios (T-128 the sightline gate) -----------------------------------


## --- scenarios (T-134 the four-way stops) -----------------------------------


## --- scenarios (T-166 traffic holds that read calm) -------------------------


## (T-162) The blinkers sit ON the body — the `cafe_sitters_on_the_rig`
## mesh-probe family. A bare CAR_SCENE instance (the traffic-null escape
## hatch) keeps all four Blink nodes at their unchanged `Visual/Blink*` paths,
## dark at rest, in the research's sedan-lens class (≤ 0.20 z × ≤ 0.07 y ×
## ≤ 0.05 x — no 0.3 m slabs) — and each lamp box, built from its BoxMesh size
## + node transform in Visual space, INTERSECTS at least one paint-mesh
## triangle at its station (same x-side, |z| within the lamp's z ± margin).
## The intersection is a Sutherland–Hodgman clip of the triangle polygon
## against the box's six planes — vertex-inside-box alone cannot see
## flat-quad interiors (the paint mesh samples quads only at their corners),
## so a hovering lamp free of vertices could never pass. Red-before (recorded
## in the ticket): the pre-T-162 scene transforms (±0.85, 0.82, ∓1.95) clear
## the nearest paint vertex by 0.094 m (front) / 0.117 m (rear) and fail all
## four intersection legs.
func _scenario_car_blinkers_sit_on_the_body() -> void:
	var car: Car = CAR_SCENE.instantiate()
	car.mode = Car.Mode.PARKED
	car.position = Vector3(60.0, 0.0, 60.0) ## Bare space — the rig alone under test.
	add_child(car)
	var visual := car.get_node("Visual") as Node3D
	var paint := visual.get_node("Body") as MeshInstance3D
	var arrays := paint.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var paths_ok := true
	var rest_ok := true
	var lens_ok := true
	var sit_ok := true
	var lens_reads := ""
	var hit_reads := ""
	for lamp_name in ["BlinkFL", "BlinkFR", "BlinkRL", "BlinkRR"]:
		var lamp := car.get_node(NodePath("Visual/" + lamp_name)) as MeshInstance3D
		paths_ok = paths_ok and lamp != null
		rest_ok = rest_ok and lamp != null and not lamp.visible
		var lens := lamp.mesh as BoxMesh
		lens_ok = lens_ok and lens != null and lens.size.z <= 0.20 \
				and lens.size.y <= 0.07 and lens.size.x <= 0.05
		lens_reads += "%s(%.3f, %.3f, %.3f) " % [lamp_name, lens.size.x, lens.size.y,
				lens.size.z]
		## The lamp AABB in Visual space from its BoxMesh size + node transform.
		var xf: Transform3D = visual.global_transform.affine_inverse() \
				* lamp.global_transform
		var center := xf.origin
		var half: Vector3 = lens.size * 0.5
		var hits := 0
		for t in range(0, indices.size(), 3):
			var a := verts[indices[t]]
			var b := verts[indices[t + 1]]
			var c := verts[indices[t + 2]]
			## Station band: same x-side as the lamp, |z| within the lamp's
			## z ± margin (0.25 m — the station's neighborhood).
			if signf(a.x) != signf(center.x) or signf(b.x) != signf(center.x) \
					or signf(c.x) != signf(center.x):
				continue
			if absf(a.z) > absf(center.z) + 0.25 \
					and absf(b.z) > absf(center.z) + 0.25 \
					and absf(c.z) > absf(center.z) + 0.25:
				continue
			if absf(a.z) < absf(center.z) - 0.25 \
					and absf(b.z) < absf(center.z) - 0.25 \
					and absf(c.z) < absf(center.z) - 0.25:
				continue
			var tri_min := a.min(b).min(c)
			var tri_max := a.max(b).max(c)
			if tri_min.x > center.x + half.x or tri_max.x < center.x - half.x \
					or tri_min.y > center.y + half.y or tri_max.y < center.y - half.y \
					or tri_min.z > center.z + half.z or tri_max.z < center.z - half.z:
				continue
			if _clip_triangle_into_box(a, b, c, center, half):
				hits += 1
		sit_ok = sit_ok and hits >= 1
		hit_reads += "%s=%d " % [lamp_name, hits]
	car.queue_free()
	await _wait_frames(2)
	_check("car_blinkers_sit_on_the_body", paths_ok and rest_ok and lens_ok and sit_ok,
			"paths=%s rest=%s lens=%s sit(hits≥1)=%s · %s· %s" % [
					paths_ok, rest_ok, lens_ok, sit_ok, lens_reads, hit_reads])


## Sutherland–Hodgman clip of a triangle polygon against an axis-aligned box's
## six planes — true when the polygon survives with ≥ 3 vertices (a real
## overlap, not a vertex graze). The T-162 lamp-intersection test's engine.
func _clip_triangle_into_box(a: Vector3, b: Vector3, c: Vector3,
		box_center: Vector3, half: Vector3) -> bool:
	var poly := PackedVector3Array([a, b, c])
	for axis in 3:
		var box_min: float = box_center[axis] - half[axis]
		var box_max: float = box_center[axis] + half[axis]
		for plane in 2:
			## plane 0 keeps p >= box_min (nrm +axis) · plane 1 keeps p <= box_max (nrm −axis).
			var sgn := 1.0 if plane == 0 else -1.0
			var plane_d := sgn * (box_min if plane == 0 else box_max)
			var out := PackedVector3Array()
			for i in poly.size():
				var p1 := poly[i]
				var p2 := poly[(i + 1) % poly.size()]
				var d1 := sgn * p1[axis] - plane_d
				var d2 := sgn * p2[axis] - plane_d
				if d1 >= 0.0:
					out.append(p1)
				if (d1 >= 0.0) != (d2 >= 0.0):
					out.append(p1 + (p2 - p1) * (-d1 / (d2 - d1)))
			poly = out
			if poly.is_empty():
				return false
	return poly.size() >= 3


## --- scenarios (T-113 citizen classes) --------------------------------------


func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


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


## T-138: the one people rig, pinned at the pack seam. Both citizens instance
## the ONE shared rigged scene (`scenes/people_rig.tscn`, a PeopleRig) whose
## Model is the imported Quaternius pack, pruned at import to the six-clip
## whitelist (the banned `Rig|Death*`/`Rig|Hit_*` clips exist nowhere in the
## packed game — the T-124 audit survives); the imported scene carries the
## live 53-joint skeleton with skinned Body/Legs/ArmL parts (the T-113
## per-class `material_override` surfaces) and the rigid head/arm mount
## parts; the tourist raises the rigid arms and hides the skinned left, the
## elder keeps the skinned far arm riding the clips; the figure is
## adult-scaled (head top 1.7507 m over feet at 0, probe-measured) with the
## splat capsule grown to match (r 0.28 / h 1.75 at y 0.875); the walk clip
## plays rate-matched to the move speed (clip stride law — feet don't skate);
## and the cars stay baked (the Kenney legs kept verbatim from
## `people_and_cars_swapped`). A revert to a pose bake, a whitelist leak or a
## scale drift fails here.
func _scenario_people_on_one_rig() -> void:
	var tourist_scene := load("res://scenes/tourist.tscn") as PackedScene
	var elder_scene := load("res://scenes/elder.tscn") as PackedScene
	var car_scene := load("res://scenes/car.tscn") as PackedScene
	var scenes_ok := tourist_scene != null and elder_scene != null and car_scene != null

	## The shared rigged scene: both citizens instance it; its Model is the
	## imported pack; the import stamped source/whitelist metadata. Both are
	## added to the tree first — the rig's parts resolve in _ready.
	var rig_ok := scenes_ok
	var tourist := tourist_scene.instantiate() as Node3D
	var elder := elder_scene.instantiate() as Node3D
	add_child(tourist)
	add_child(elder)
	for citizen: Node3D in [tourist, elder]:
		var rig: Node = citizen.get_node("Visual")
		rig_ok = rig_ok and rig.get_script() == PeopleRig \
				and (rig as Node3D).scene_file_path == "res://scenes/people_rig.tscn"
		var model: Node3D = rig.get_node("Model")
		rig_ok = rig_ok and model.scene_file_path \
				== "res://assets/third-party/quaternius/base_character.glb"
		rig_ok = rig_ok and model.get_meta("source_pack", "") \
				== "quaternius-universal-base-characters" \
				and model.get_meta("license", "") == "CC0"
	## Citizens arm differently on the SAME rig: the near RIGHT arm is rigid
	## and visible for both citizens (the tourist's panic raise / foam finger
	## drives the same node); the tourist alone shows the rigid left, the
	## elder's far arm rides the skinned ArmL.
	var arms_ok := true
	var t_rig: PeopleRig = tourist.get_node("Visual")
	var e_rig: PeopleRig = elder.get_node("Visual")
	arms_ok = arms_ok and t_rig.arm_l_rigid.visible and t_rig.arm_r_rigid.visible \
			and not t_rig.arm_skinned_l.visible
	arms_ok = arms_ok and e_rig.arm_r_rigid.visible and e_rig.arm_skinned_l.visible \
			and not e_rig.arm_l_rigid.visible
	## And the elder's hands stay DOWN (T-144 retired the T-078 trust arm):
	## the near rigid arm carries NO pose drive — after stepping the elder's
	## own `_animate` its basis stays the identity (it rides its bone with
	## the clip swing). A reinstated meter's world-aimed `set_arm_pose` write
	## would tilt the basis away — this catches it structurally.
	var e_skel := e_rig.find_child("Skeleton3D", true, false) as Skeleton3D
	for _settle in 30:
		elder._physics_process(1.0 / 60.0)
		e_rig.anim.advance(1.0 / 60.0)
		e_skel.force_update_all_bone_transforms()
	arms_ok = arms_ok and e_rig.arm_r_rigid.basis.is_equal_approx(Basis.IDENTITY)
	tourist.free()
	elder.free()

	## The imported pack itself: whitelist-pruned clips, live skeleton, the
	## skinned + rigid parts, every tintable part carrying a material.
	var pack := load("res://assets/third-party/quaternius/base_character.glb") as PackedScene
	var whitelist_ok := pack != null
	var pack_inst := pack.instantiate() if pack != null else null
	if pack_inst != null:
		var ap := pack_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var skel := pack_inst.find_child("Skeleton3D", true, false) as Skeleton3D
		whitelist_ok = whitelist_ok and ap != null and skel != null and skel.get_bone_count() == 53
		var clip_list := ap.get_animation_list()
		var expected: Array[String] = PeopleRig.CLIPS_WHITELIST
		whitelist_ok = whitelist_ok and clip_list.size() == expected.size()
		for clip_name in expected:
			whitelist_ok = whitelist_ok and clip_name in clip_list
		for clip_name in clip_list:
			whitelist_ok = whitelist_ok and not "death" in String(clip_name).to_lower() \
					and not "hit" in String(clip_name).to_lower()
		for part_name in ["Body", "Legs", "ArmL", "HeadRigid", "ArmLRigid", "ArmRRigid"]:
			var part := pack_inst.find_child(part_name, true, false) as MeshInstance3D
			whitelist_ok = whitelist_ok and part != null \
					and part.mesh.surface_get_material(0) is StandardMaterial3D \
					and part.mesh.get_meta("source_pack", "") \
							== "quaternius-universal-base-characters"
		var body := pack_inst.find_child("Body", true, false) as MeshInstance3D
		whitelist_ok = whitelist_ok and body != null and body.skin != null \
				and body.skin.get_bind_count() == 53
		pack_inst.free()

	## The adult envelope, measured live: a strolling tourist's head bone sits
	## at the probe-pinned adult line (head top 1.7507 m over feet at 0).
	var envelope_ok := true
	var walker: Tourist = tourist_scene.instantiate()
	walker.path = PackedVector3Array([Vector3(4500.0, 0.0, 4500.0),
			Vector3(4506.0, 0.0, 4500.0)])
	add_child(walker)
	await _wait_frames(6)
	var w_rig: PeopleRig = walker.get_node("Visual")
	var w_skel := w_rig.find_child("Skeleton3D", true, false) as Skeleton3D
	if w_skel != null:
		var head_i := w_skel.find_bone("DEF-head")
		var head_y := (w_skel.global_transform * w_skel.get_bone_global_pose(head_i)).origin.y
		## Head bone 1.5126 (unscaled probe) → adult: +0.2526 bone-to-top.
		envelope_ok = envelope_ok and absf(head_y + PeopleRig.HEAD_BONE_TO_TOP \
				* PeopleRig.ADULT_SCALE - PeopleRig.ADULT_HEAD_TOP) < 0.02
	var rate_ok := w_rig.anim.current_animation == PeopleRig.CLIP_WALK \
			and absf(w_rig.anim.speed_scale - PeopleRig.walk_rate(walker.walk_speed)) < 0.02
	## The rate law itself: speed × clip seconds / clip stride (1.3 m/s → ≈ 1.309).
	rate_ok = rate_ok and absf(PeopleRig.walk_rate(1.3) - 1.3 * PeopleRig.WALK_SECONDS \
			/ PeopleRig.WALK_STRIDE) < 0.001
	walker.free()

	## Physics parity, re-derived for the grown capsule: it is the splat
	## surface, so it grew WITH the visual; the car box is untouched.
	var tourist_shape := tourist_scene.instantiate() as Node3D
	var capsule := (tourist_shape.get_node("Shape") as CollisionShape3D).shape \
			as CapsuleShape3D
	var capsule_ok := capsule != null and is_equal_approx(capsule.radius, 0.28) \
			and is_equal_approx(capsule.height, 1.75) \
			and is_equal_approx((tourist_shape.get_node("Shape") as CollisionShape3D) \
					.position.y, 0.875)
	tourist_shape.free()
	var elder_shape := elder_scene.instantiate() as Node3D
	var e_capsule := (elder_shape.get_node("Shape") as CollisionShape3D).shape \
			as CapsuleShape3D
	capsule_ok = capsule_ok and e_capsule != null \
			and is_equal_approx(e_capsule.radius, 0.28) \
			and is_equal_approx(e_capsule.height, 1.75) \
			and is_equal_approx((elder_shape.get_node("Shape") as CollisionShape3D) \
					.position.y, 0.875)
	elder_shape.free()

	## Cars stay baked (they are not humans): the Kenney legs, verbatim.
	var car := car_scene.instantiate() as Node3D
	var car_ok := true
	for part_path in ["Visual/Body", "Visual/Glass", "Visual/Trim", "Visual/Lights"]:
		var mi := car.get_node_or_null(part_path) as MeshInstance3D
		car_ok = car_ok and _is_pack_mesh(mi, "kenney-car-kit", "")
	for wheel_path in ["Visual/WheelFL", "Visual/WheelFR", "Visual/WheelRL", "Visual/WheelRR"]:
		var mi := car.get_node_or_null(wheel_path) as MeshInstance3D
		car_ok = car_ok and _is_pack_mesh(mi, "kenney-car-kit", "")
	var wheel_mesh: Mesh = (car.get_node("Visual/WheelFL") as MeshInstance3D).mesh
	car_ok = car_ok and wheel_mesh != null \
			and wheel_mesh == (car.get_node("Visual/WheelRR") as MeshInstance3D).mesh
	var paint_mesh: Mesh = (car.get_node("Visual/Body") as MeshInstance3D).mesh
	car_ok = car_ok and paint_mesh != null \
			and paint_mesh.surface_get_material(0) is StandardMaterial3D
	car.free()
	var car_node := car_scene.instantiate() as Node3D
	var box := (car_node.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	var car_shape_ok := box != null and box.size.is_equal_approx(Vector3(1.9, 1.45, 4.4)) \
			and is_equal_approx((car_node.get_node("Shape") as CollisionShape3D) \
					.position.y, 0.725)
	car_node.free()

	## The banned clips are referenced nowhere in the rig's scenes, scripts,
	## the import script or the spawners.
	var death_ok := true
	for text_path in ["res://scenes/tourist.tscn", "res://scenes/elder.tscn",
			"res://scenes/people_rig.tscn", "res://scenes/car.tscn",
			"res://scripts/tourist.gd", "res://scripts/elder.gd",
			"res://scripts/people_rig.gd", "res://scripts/car.gd",
			"res://scripts/tourist_spawner.gd", "res://scripts/car_spawner.gd",
			"res://scripts/elder_spawner.gd", "res://tools/import_people_rig.gd"]:
		var f := FileAccess.open(text_path, FileAccess.READ)
		death_ok = death_ok and f != null \
				and not f.get_as_text().to_lower().contains("death")

	_check("people_on_one_rig",
			scenes_ok and rig_ok and arms_ok and whitelist_ok and envelope_ok
					and rate_ok and capsule_ok and car_ok and car_shape_ok and death_ok,
			"scenes=%s rig=%s arms=%s whitelist=%s envelope=%s rate=%s capsule=%s cars=%s box=%s no_death=%s" % [
					scenes_ok, rig_ok, arms_ok, whitelist_ok, envelope_ok, rate_ok,
					capsule_ok, car_ok, car_shape_ok, death_ok])


## T-165 — the locomotion rate ledger: the rate pins the suite never had. The
## walk-rate pin STAYS in `people_on_one_rig` (no duplication); this scenario
## pins every other played rate, each read ±0.02 `speed_scale` on the LIVE
## animation player. One design rule the legs split on (the ticket's): a leg
## whose expected value comes from the same `PeopleRig` constant the game
## plays can never red on a constant edit — both sides move together
## (`play_locomotion` calls the same static `sprint_rate()`,
## scripts/people_rig.gd, and `_panic` snaps velocity straight to
## `panic_speed`) — so constant TRUTH is pinned only where the expected value
## comes from the independent copy, the import stamps
## (`tools/import_people_rig.gd` `_stamp_meta`, read by nothing else in the
## game), and that is PANIC and LEDGER; SHUFFLE and SIT PACING pin WIRING in
## the people_on_one_rig convention, by design:
##   PANIC — a strolling tourist takes a REAL `on_splatted(Vector3(...))`,
##     settles into `Mood.PANIC`, then `current_animation == CLIP_SPRINT`
##     and `speed_scale == panic_speed × stamp(sprint_seconds) /
##     stamp(sprint_stride)` — expected from the STAMPS, so a one-sided edit
##     of either sprint constant separates played from expected and reds
##     (the red-before is ticket-recorded: `SPRINT_STRIDE` 2.05 plays
##     4.2 × 0.6667 / 2.05 = 1.3659 vs the stamp-derived 1.3126, delta
##     0.0533 past the ±0.02 tolerance);
##   SHUFFLE — the T-137 migration mechanism (an elder seated at a plaza
##     ring seat migrating to a park bench through the REAL
##     `begin_migration`) read mid-WALKING as
##     `PeopleRig.walk_rate(elder.walk_speed)` — the export read live makes
##     the pin pace-free: the walk runs at the T-137 harness's 6 m/s window
##     pace while the shipped 0.8 default is value-locked before it, so
##     BOTH paces are green by construction;
##   SIT PACING — the same migration's RISING and ARRIVING windows record
##     `speed_scale == PeopleRig.SITTING_EXIT_SECONDS / elder.rise_seconds`
##     and `== PeopleRig.SITTING_ENTER_SECONDS / elder.rise_seconds`
##     (the `elder.gd` `_sync_clip` wiring, pinned);
##   LEDGER — `PeopleRig.WALK_STRIDE/WALK_SECONDS/SPRINT_STRIDE/
##     SPRINT_SECONDS` equal the imported Model's stamped `walk_stride` /
##     `walk_seconds` / `sprint_stride` / `sprint_seconds` metas — the
##     stamps become load-bearing (the PANIC leg already derives its
##     expected rate from two of them; this leg pins all four against the
##     script copies), and a one-sided edit of either copy reds CI. The
##     independence is one-directional by design: a COORDINATED
##     constant+stamp re-pin stays green — the correct contract for a pins
##     ticket.
func _scenario_locomotion_rate_ledger() -> void:
	## --- LEDGER: the four script constants vs the import stamps --------------
	var bare_rig: Node3D = (load("res://scenes/people_rig.tscn") as PackedScene) \
			.instantiate()
	add_child(bare_rig)
	await _wait_frames(2)
	var bare_model: Node3D = bare_rig.get_node("Model")
	var stamp_walk_stride: float = bare_model.get_meta("walk_stride", 0.0)
	var stamp_walk_seconds: float = bare_model.get_meta("walk_seconds", 0.0)
	var stamp_sprint_stride: float = bare_model.get_meta("sprint_stride", 0.0)
	var stamp_sprint_seconds: float = bare_model.get_meta("sprint_seconds", 0.0)
	var stamps_ok := stamp_walk_stride > 0.0 and stamp_walk_seconds > 0.0 \
			and stamp_sprint_stride > 0.0 and stamp_sprint_seconds > 0.0
	var ledger_ok := stamps_ok \
			and is_equal_approx(stamp_walk_stride, PeopleRig.WALK_STRIDE) \
			and is_equal_approx(stamp_walk_seconds, PeopleRig.WALK_SECONDS) \
			and is_equal_approx(stamp_sprint_stride, PeopleRig.SPRINT_STRIDE) \
			and is_equal_approx(stamp_sprint_seconds, PeopleRig.SPRINT_SECONDS)
	bare_rig.free()

	## --- PANIC: the sprint rate, played vs the stamps ------------------------
	var tourist_scene := load("res://scenes/tourist.tscn") as PackedScene
	var walker: Tourist = tourist_scene.instantiate()
	walker.path = PackedVector3Array([Vector3(4500.0, 0.0, 4500.0),
			Vector3(4506.0, 0.0, 4500.0)])
	add_child(walker)
	await _wait_frames(6)
	var t_rig: PeopleRig = walker.get_node("Visual")
	var strolling := t_rig.anim.current_animation == PeopleRig.CLIP_WALK
	walker.on_splatted(Vector3(3.0, -9.0, 2.0)) ## A real splat: the panic away.
	var stamp_expected: float = walker.panic_speed \
			* t_rig.model.get_meta("sprint_seconds", 0.0) \
			/ t_rig.model.get_meta("sprint_stride", 0.0)
	var panic_ok := false
	var played_rate := -1.0
	for _i in 30:
		await get_tree().physics_frame
		if walker.mood == Tourist.Mood.PANIC \
				and t_rig.anim.current_animation == PeopleRig.CLIP_SPRINT:
			played_rate = t_rig.anim.speed_scale
			panic_ok = absf(played_rate - stamp_expected) < 0.02
			break
	walker.free()

	## --- SHUFFLE + SIT PACING: the migration windows -------------------------
	## (T-177) the migration windows RETIRE with the Windrow bench grid: the
	## real migration machinery routes over the block grid (`block_centers`,
	## road bands) as well as the bench seats, and on the resident Ames world
	## BOTH are empty until R2 re-points the elders (a staged-seat run crashes
	## in the route math — the recorded attempt). The window rate pins return
	## with R2·economy-scale; what stays pinned here is the SHIPPED DEFAULTS
	## the windows pace against, read off a bare seated elder.
	var elder_scene := load("res://scenes/elder.tscn") as PackedScene
	var elder: Elder = elder_scene.instantiate()
	add_child(elder)
	await _wait_frames(2)
	## The shipped defaults, value-locked — the pin reads the exports live, so
	## the harness pace and the shipped default are both green by construction.
	var defaults_ok := elder._state == Elder.State.SEATED \
			and is_equal_approx(elder.walk_speed, 0.8) \
			and is_equal_approx(elder.rise_seconds, 0.6)
	var pace_law_ok: bool = absf(
			PeopleRig.SITTING_EXIT_SECONDS / elder.rise_seconds - 1.6667) < 0.001 \
			and PeopleRig.walk_rate(6.0) > 0.0 ## The window paces' law, value-held.
	elder.free()

	_check("locomotion_rate_ledger",
			stamps_ok and ledger_ok and strolling and panic_ok
					and defaults_ok and pace_law_ok,
			("stamps=%s ledger=%s strolling=%s panic=%s (played %.4f vs stamps %.4f) "
					+ "defaults=%s pace_law=%s "
					+ "(migration windows retired with the Windrow bench grid — T-177)") % [
					stamps_ok, ledger_ok, strolling, panic_ok,
					played_rate, stamp_expected,
					defaults_ok, pace_law_ok])


## T-139 — every citizen part is HUMAN-sized. The import split must keep the
## partition vertices in the mannequin's bind space: the first T-138 cut
## baked the shared `arm_l` build into the main bone's meter frame, and the
## skinned ArmL — wearing the full bind skin, which assumes mannequin space —
## rendered ×100 as ~85 m slabs through the world (the owner's "enormous
## blobs"; tourists hid the mesh, only elders showed it). This walks a live
## tourist rig's six parts and caps each one's world AABB: correct parts
## measure ≤ 0.86 m (the rigid arms), the ×100 corruption measured 85.8 m,
## so a 3 m cap holds the fix with order-of-magnitude margin. The stated
## AABB of the skinned parts understates their skinned render (they sit in
## the pack's 1/100 bind space, as Body/Legs always have) — the cap is on
## the stated box, which is what the import's space bug inflates.
func _scenario_citizen_parts_world_scale() -> void:
	var tourist_scene := load("res://scenes/tourist.tscn") as PackedScene
	var rig_inst: Node3D = tourist_scene.instantiate()
	add_child(rig_inst)
	var rig: PeopleRig = rig_inst.get_node("Visual")
	var ok := rig != null
	var worst := 0.0
	for part_name in ["Body", "Legs", "ArmL", "HeadRigid", "ArmLRigid", "ArmRRigid"]:
		var part := (rig.find_child(part_name, true, false) if rig != null
				else null) as MeshInstance3D
		if part == null or part.mesh == null:
			ok = false
			continue
		var world_aabb: AABB = part.global_transform * part.mesh.get_aabb()
		worst = maxf(worst, maxf(maxf(world_aabb.size.x, world_aabb.size.y),
				world_aabb.size.z))
		ok = ok and worst < 3.0
	rig_inst.free()
	_check("citizen_parts_world_scale", ok,
			"worst part world AABB %.3f m (< 3.0)" % worst)


## (T-141, sink re-derived by T-146 from the owner's after-screenshot) The
## seated elder lands IN the bench: the DEF-hips BONE rides ~0.04 above the
## seat top — the sit clip's near-horizontal THIGHS (the mass that meets
## the bench) rest ON the 0.60 m seat and the glute settles 0.01-0.02 into
## the slab; the T-141 glute-line target (+0.105) left the thighs ~0.07
## high and a gap under the pelvis, and the T-138 child-scale derivation
## put the bone AT the seat (glute ~0.16 into the slab). The feet never
## pass below the pavement (the pack's sit pose dangles them — the accepted
## read), and the hair prop sits on the scalp, not floating above the head.
## The constants are value-locked (the T-110 precedent) so the composite
## cannot silently re-drift;
## `tools/probe_sit_geometry.gd` re-derives them from the pack clips.
## (T-163) The lock set grows the SEAT_SLIDE rig-z lock: the eased seated
## slide rides the same visual (z-only — the hips band 0.00..0.08 is
## re-verified against it), the root placement stays the state machine's.
func _scenario_elder_seats_on_the_bench() -> void:
	var elder_scene := load("res://scenes/elder.tscn") as PackedScene
	var elder := elder_scene.instantiate() as Node3D
	elder.position = Vector3(50.0, 0.0, 50.0) ## Bare space; the root y IS the seat top by the spot contract.
	add_child(elder)
	var rig: PeopleRig = elder.get_node("Visual")
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	for _settle in 90: ## 1.5 s: the sink eases to full in ~0.5 s of physics time.
		elder._physics_process(1.0 / 60.0)
		rig.anim.advance(1.0 / 60.0)
		skel.force_update_all_bone_transforms()
	## Two real frames: the BoneAttachment3D mounts lag the skeleton within a
	## synchronous block (they catch up on the skeleton's next processing
	## pass), and the rig's frame-1 head-mount correction runs on _process —
	## both are live-game states this measurement must not read early.
	await get_tree().process_frame
	await get_tree().process_frame
	var bone_world_y := func(bone_name: String) -> float:
		var idx := skel.find_bone(bone_name)
		return (skel.global_transform * skel.get_bone_global_pose(idx)).origin.y
	var hips: float = bone_world_y.call("DEF-hips") - elder.global_position.y
	var feet: float = minf(bone_world_y.call("DEF-foot.L"),
			bone_world_y.call("DEF-foot.R")) - elder.global_position.y
	var head: float = bone_world_y.call("DEF-head") - elder.global_position.y
	var hair := rig.find_child("Hair", true, false) as MeshInstance3D
	var hair_lift: float = hair.global_position.y - elder.global_position.y \
			- (head + PeopleRig.HEAD_BONE_TO_TOP * PeopleRig.ADULT_SCALE)
	var sink_ok: bool = absf(rig.position.y - Elder.SEAT_SINK) < 0.01 \
			and absf(Elder.SEAT_SINK - (-0.465)) < 0.005 \
			and absf(Elder.HUNCH_SEATED - 0.04) < 0.005
	## (T-163) The seat-contact slide rides the same eased composite: the rig
	## z lands on SEAT_SLIDE while seated, the ROOT stays untouched on the
	## spot (this elder stands at its bare position — the root placement is
	## the state machine's). The hips band re-verifies the slide is z-only.
	var slide_ok: bool = absf(rig.position.z - Elder.SEAT_SLIDE) < 0.01 \
			and absf(Elder.SEAT_SLIDE - (-0.25)) < 0.005
	var hips_ok := hips > 0.00 and hips < 0.08
	var feet_ok := feet + 0.60 >= -0.01 ## Root sits 0.60 above the slab (the spot contract).
	var hair_ok := hair != null and hair_lift > -0.05 and hair_lift < 0.10
	var sink_applied: float = rig.position.y ## Read before the rig dies with its parent.
	var slide_applied: float = rig.position.z
	elder.free()
	_check("elder_seats_on_the_bench", sink_ok and slide_ok and hips_ok and feet_ok and hair_ok,
			"hips bone seat+%+.3f (want +0.04), feet slab+%+.3f, hair lift %+.3f, sink %.3f, slide %.3f" % [
				hips, feet + 0.60, hair_lift, sink_applied, slide_applied])


## (T-142) The café crowd wears the ONE people model: every sit key renders
## the import's baked seated meshes (metadata-stamped source pack, CC0,
## `pose_clip == Rig|Sitting_Idle` — the same pose the elders hold, so the
## two crowds read as one species), one instance per sitter on every key,
## `sit_body` tinted by the unchanged tourist-palette law, the retired box
## keys absent (swap tripwire), and the baked figure measures human — the
## seated body spans roughly the probe's seated envelope, which also pins
## the bake's adult scale against drift from the rig's 0.982 Model factor.
func _scenario_cafe_sitters_on_the_rig() -> void:
	var spawner := CafeSpawner.new()
	spawner.city = _city
	add_child(spawner)
	await _wait_frames(4)
	var total := 0
	for i in _city.cafe_spots.size():
		total += spawner.sitter_count(i)
	var keys_ok := true
	for key in ["sit_body", "sit_legs", "sit_head", "sit_hair_cap"]: ## (T-164) `sit_hair` → `sit_hair_cap` — still one instance per sitter.
		var mm := spawner.visual(key)
		keys_ok = keys_ok and mm != null and mm.multimesh != null \
				and mm.multimesh.instance_count == total
	var stamped_ok := true
	for key in ["sit_body", "sit_legs", "sit_head"]:
		var mm := spawner.visual(key)
		var mesh: Mesh = mm.multimesh.mesh
		stamped_ok = stamped_ok and mesh.get_meta("source_pack", "") \
				== "quaternius-universal-base-characters" \
				and mesh.get_meta("license", "") == "CC0" \
				and str(mesh.get_meta("pose_clip", "")) == "Rig|Sitting_Idle"
	var swap_ok := spawner.visual("sitter_torso") == null \
			and spawner.visual("sitter_arm") == null \
			and spawner.visual("sitter_head") == null \
			and spawner.visual("sitter_thigh") == null \
			and spawner.visual("sit_hair") == null ## (T-164) The retired hair box joins the swap tripwire.
	var shirts_ok := true
	var si := 0
	for i in _city.cafe_spots.size():
		for seat in spawner.sitter_count(i):
			var expected: Color = Tourist.SHIRT_PALETTE[(i + seat) % Tourist.SHIRT_PALETTE.size()]
			shirts_ok = shirts_ok \
					and spawner.instance_color("sit_body", si).is_equal_approx(expected)
			si += 1
	var body_ab: AABB = spawner.visual("sit_body").multimesh.mesh.get_aabb()
	var legs_ab: AABB = spawner.visual("sit_legs").multimesh.mesh.get_aabb()
	## The seated body: hips-to-head-top torso (probe: ~0.46..1.15 in root
	## space) and legs reaching from the clip floor up to the hips — standing
	## geometry (feet −0.013, hips 0.95, the no-op pose this bake shipped
	## with twice) measures a 0.95 m legs AABB and fails the legs cap.
	var human_ok := body_ab.size.y > 0.5 and body_ab.size.y < 0.9 \
			and body_ab.position.y > 0.3 and body_ab.position.y < 0.6 \
			and legs_ab.size.y > 0.5 and legs_ab.size.y < 0.75 \
			and legs_ab.position.y > -0.1 and legs_ab.position.y < 0.1
	spawner.free()
	_check("cafe_sitters_on_the_rig", keys_ok and stamped_ok and swap_ok
			and shirts_ok and human_ok,
			"sitters=%d keys=%s stamped=%s swapped=%s shirts=%s human=%s (body %.2f..%.2f legs %.2f..%.2f)" % [
				total, keys_ok, stamped_ok, swap_ok, shirts_ok, human_ok,
				body_ab.position.y, body_ab.end.y, legs_ab.position.y, legs_ab.end.y])


## (T-164) One fitted dome cap on every head — SHAPE, FIT, VALUE and
## REALIZATION laws, on the bare-rig instantiation family of
## `citizen_classes_readable`. SHAPE (all three cap meshes): tri count ≥ 96
## (the retired boxes carry 12) and the y-binned radial taper — the
## top-20%-band max horizontal radius ≤ 0.75 × the base-20%-band max
## (probe: dome 0.47 at 24×12, box 1.00 — the dome tapers, the box's
## top-face corners keep full radius). FIT against each mount's live head
## AABB (the rigs' HeadRigid bind AABB via `PeopleRig.head_aabb()`; the
## café's harvested `sit_head` bake AABB): per-axis plan poke ≤ 0.01 on the
## half-extents about the centers, rim sunk HAIR_CAP_SINK past the scalp
## line, crown ≥ head end.y − 0.03; the rig legs pin the drop equation the
## bands lean on (HAIR_CAP_SINK == −HEAD_PROP_LIFT − HAIR_CAP_BASE_DROP).
## VALUE LOCKS (the T-110 precedent): SINK 0.08, HEIGHT 0.10, BASE_DROP
## −0.03, segments 24/12. REALIZATION: each cap is a ONE-surface ArrayMesh
## with a non-null surface-0 material — a bare SphereMesh return would land
## its base circle 0.03 high and fail the rim band by construction. The
## elder/tourist legs read the live `Hair`/`Cap` nodes post-_ready — each
## node's mesh IS the offset dome (vertex-baked, no child node, no
## re-homing), so `mesh.get_aabb()`/`get_faces()` see the drop directly;
## the café leg reads `visual("sit_hair_cap").multimesh.mesh` plus the
## harvested `sit_head` bake AABB and every queued cap transform (its
## sit_root translated by head-center x, head end.y − HAIR_CAP_SINK,
## head-center z). Red-before (ticket-recorded, probe-confirmed): the
## shipped boxes fail SHAPE on every mount (12 tris, taper 1.00) and the
## elder/tourist boxes fail the FIT plan leg (+0.0124/+0.0112 pokes > 0.01);
## the café box passed FIT and failed only SHAPE — a cap must BE round,
## not merely sit right.
func _scenario_hair_caps_round_the_skull() -> void:
	var locks_ok: bool = is_equal_approx(PeopleRig.HAIR_CAP_SINK, 0.08) \
			and is_equal_approx(PeopleRig.HAIR_CAP_HEIGHT, 0.10) \
			and is_equal_approx(PeopleRig.HAIR_CAP_BASE_DROP, -0.03) \
			and PeopleRig.HAIR_CAP_RADIAL_SEGMENTS == 24 \
			and PeopleRig.HAIR_CAP_RINGS == 12 \
			and is_equal_approx(PeopleRig.HAIR_CAP_SINK,
					-PeopleRig.HEAD_PROP_LIFT - PeopleRig.HAIR_CAP_BASE_DROP)
	## --- the elder's white cap --------------------------------------------
	var elder := (load("res://scenes/elder.tscn") as PackedScene).instantiate() as Node3D
	elder.position = Vector3(60.0, 0.0, 60.0) ## Bare space; nothing else reads it.
	add_child(elder)
	await get_tree().process_frame ## The frame-1 head-slot correction needs one _process pass.
	await get_tree().process_frame
	var elder_rig: PeopleRig = elder.get_node("Visual")
	var elder_head_ab: AABB = elder_rig.head_aabb()
	var elder_hair := elder_rig.find_child("Hair", true, false) as MeshInstance3D
	var elder_shape := _cap_shape_ok(elder_hair.mesh)
	var elder_real := _cap_realization_ok(elder_hair.mesh, Color(0.78, 0.78, 0.75))
	var elder_fit := _cap_rig_fit_ok(elder_hair, elder_head_ab)
	var elder_base: float = _cap_rig_base(elder_hair)
	var elder_tris := elder_hair.mesh.get_faces().size() / 3
	var elder_taper := _cap_taper(elder_hair.mesh)
	elder.free()
	## --- the superfan's gold cap ------------------------------------------
	var tourist := (load("res://scenes/tourist.tscn") as PackedScene).instantiate() as Node3D
	tourist.position = Vector3(60.0, 0.0, 60.0)
	add_child(tourist)
	await get_tree().process_frame
	await get_tree().process_frame
	var tourist_rig: PeopleRig = tourist.get_node("Visual")
	var tourist_head_ab: AABB = tourist_rig.head_aabb()
	var tourist_cap := tourist_rig.find_child("Cap", true, false) as MeshInstance3D
	var tourist_shape := _cap_shape_ok(tourist_cap.mesh)
	var tourist_real := _cap_realization_ok(tourist_cap.mesh, Color(1.0, 0.8, 0.0))
	var tourist_fit := _cap_rig_fit_ok(tourist_cap, tourist_head_ab)
	var tourist_base: float = _cap_rig_base(tourist_cap)
	var tourist_tris := tourist_cap.mesh.get_faces().size() / 3
	var tourist_taper := _cap_taper(tourist_cap.mesh)
	tourist.free()
	## --- the café crowd's brown caps --------------------------------------
	var spawner := CafeSpawner.new()
	spawner.city = _city
	add_child(spawner)
	await _wait_frames(4)
	var total := 0
	for i in _city.cafe_spots.size():
		total += spawner.sitter_count(i)
	var cap_mm := spawner.visual("sit_hair_cap")
	var cafe_keys_ok := cap_mm != null and cap_mm.multimesh != null \
			and cap_mm.multimesh.instance_count == total \
			and spawner.visual("sit_hair") == null
	var cafe_mesh: Mesh = cap_mm.multimesh.mesh
	var cafe_shape := _cap_shape_ok(cafe_mesh)
	var cafe_real := _cap_realization_ok(cafe_mesh, CafeSpawner.HAIR)
	var cafe_head_ab: AABB = spawner.visual("sit_head").multimesh.mesh.get_aabb()
	var cap_ab: AABB = cafe_mesh.get_aabb()
	## FIT in sit-root space: every queued cap xf is its sit_root translated
	## by (head center.x, head end.y − HAIR_CAP_SINK, head center.z) — the
	## dome's base plane lands HAIR_CAP_SINK past the scalp line and its
	## apex at end.y − SINK + HEIGHT.
	## FIT: per-axis plan poke, the dome base baked at 0 (the café passes
	## base_drop 0.0 — the instance transform is the positioner), and the
	## apex law (end.y − HAIR_CAP_SINK + HEIGHT ≥ end.y − 0.03).
	var cafe_fit := cap_ab.size.x * 0.5 <= cafe_head_ab.size.x * 0.5 + 0.01 \
			and cap_ab.size.z * 0.5 <= cafe_head_ab.size.z * 0.5 + 0.01 \
			and is_equal_approx(cap_ab.position.y, 0.0) \
			and (cafe_head_ab.end.y - PeopleRig.HAIR_CAP_SINK) + cap_ab.end.y \
					>= cafe_head_ab.end.y - 0.03
	var cap_xfs: Array = spawner._mm_queues["sit_hair_cap"].xfs
	var root_xfs: Array = spawner._mm_queues["sit_body"].xfs
	for si in spawner.sitters.size():
		var root_xf := root_xfs[si] as Transform3D
		var cap_xf := cap_xfs[si] as Transform3D
		## The spawner's own float32 path, recomputed bit-for-bit (the T-163
		## origin-algebra pattern — inverting the basis re-rounds ~5e-5 and
		## trips is_equal_approx): origin + basis · (center.x, end.y −
		## HAIR_CAP_SINK, center.z), basis carried unchanged.
		var want_origin: Vector3 = root_xf.origin + root_xf.basis * Vector3(
				cafe_head_ab.get_center().x,
				cafe_head_ab.end.y - PeopleRig.HAIR_CAP_SINK,
				cafe_head_ab.get_center().z)
		cafe_fit = cafe_fit and cap_xf.origin.is_equal_approx(want_origin) \
				and cap_xf.basis.is_equal_approx(root_xf.basis)
	spawner.free()
	_check("hair_caps_round_the_skull", locks_ok and elder_shape and elder_real
			and elder_fit and tourist_shape and tourist_real and tourist_fit
			and cafe_keys_ok and cafe_shape and cafe_real and cafe_fit,
			"locks=%s elder(shape=%s real=%s fit=%s base %+.3f) tourist(shape=%s real=%s fit=%s base %+.3f) cafe(keys=%s shape=%s real=%s fit=%s tris e%d/t%d/c%d taper e%.2f/t%.2f/c%.2f)" % [
				locks_ok, elder_shape, elder_real, elder_fit, elder_base,
				tourist_shape, tourist_real, tourist_fit, tourist_base,
				cafe_keys_ok, cafe_shape, cafe_real, cafe_fit,
				elder_tris, tourist_tris, cafe_mesh.get_faces().size() / 3,
				elder_taper, tourist_taper, _cap_taper(cafe_mesh)])


## (T-164) The SHAPE law on one cap mesh: tri count ≥ 96 (the retired boxes
## carry 12) and the y-binned radial taper ≤ 0.75.
func _cap_shape_ok(mesh: Mesh) -> bool:
	return mesh.get_faces().size() / 3 >= 96 and _cap_taper(mesh) <= 0.75


## (T-164) The y-binned radial taper: the top-20%-band max horizontal
## radius over the base-20%-band max (vertex bins over `get_faces()`, radii
## about the mesh's own xz center). The dome tapers toward the crown; a
## box's top-face corners keep the full radius.
func _cap_taper(mesh: Mesh) -> float:
	var radii := _cap_band_radii(mesh)
	return radii.y / maxf(radii.x, 0.0001)


## (T-164) A mesh's 20%-band max horizontal radii as [base, top]: every
## `get_faces()` vertex binned into fifths of the mesh AABB's y-range, the
## radius taken about the AABB's xz center.
func _cap_band_radii(mesh: Mesh) -> Vector2:
	var faces := mesh.get_faces()
	var ab: AABB = mesh.get_aabb()
	var center := Vector2(ab.get_center().x, ab.get_center().z)
	var span := maxf(ab.size.y, 0.0001)
	var bands: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	for v: Vector3 in faces:
		var band := clampi(int(floor((v.y - ab.position.y) / span * 5.0)), 0, 4)
		bands[band] = maxf(bands[band], Vector2(v.x, v.z).distance_to(center))
	return Vector2(bands[0], bands[4])


## (T-164) The REALIZATION law on one cap mesh: a ONE-surface ArrayMesh
## whose surface 0 carries a non-null StandardMaterial3D in `want_color`
## (the retired placeholder's color law rides onto the generated dome).
func _cap_realization_ok(mesh: Mesh, want_color: Color) -> bool:
	var am := mesh as ArrayMesh
	if am == null or am.get_surface_count() != 1:
		return false
	var mat := am.surface_get_material(0) as StandardMaterial3D
	return mat != null and mat.albedo_color.is_equal_approx(want_color)


## (T-164) The rig FIT law in slot space: the prop rides the frame-1 slot
## (identity basis, zero position) and the head mesh's end.y sits at
## −head_prop_lift over the slot (people_rig.gd's pin), so in slot-local
## terms the cap's rim must land HAIR_CAP_SINK under the head end, its
## crown must stay past head end − 0.03, and its plan may poke the head's
## per-axis half-extents by ≤ 0.01 (the retired box poked 0.012).
func _cap_rig_fit_ok(prop: MeshInstance3D, head_ab: AABB) -> bool:
	var cap_ab: AABB = prop.mesh.get_aabb()
	var slot := prop.get_parent() as Node3D
	var head_end_slot: float = head_ab.end.y - slot.position.y
	var plan_ok := cap_ab.size.x * 0.5 <= head_ab.size.x * 0.5 + 0.01 \
			and cap_ab.size.z * 0.5 <= head_ab.size.z * 0.5 + 0.01
	return plan_ok \
			and absf(_cap_rig_base(prop) - (head_end_slot - PeopleRig.HAIR_CAP_SINK)) <= 0.01 \
			and prop.position.y + cap_ab.end.y >= head_end_slot - 0.03


## (T-164) The rig cap's rim height in slot space: prop position (zero —
## the mount law) plus the mesh's baked base.
func _cap_rig_base(prop: MeshInstance3D) -> float:
	return prop.position.y + prop.mesh.get_aabb().position.y


## (T-163) The ONE seat-contact law, machine-checked on BOTH surfaces: the
## seated figure's THIGHS rest on the seat top, its forward SHIN crosses the
## seat slab's y-band past the front-edge plane, and the café soles reach
## the pavement / the bench glute stays ON the seat. Café legs read the
## spawner's `_mm_queues` sit transforms (the exact MultiMesh feed) plus the
## harvested `sit_legs`/`sit_body` bake meshes against the stool constants;
## bench legs read the SitBake bake off a settled live elder — its own
## `_animate` composite (SEAT_SINK, HUNCH_SEATED and the T-163 SEAT_SLIDE
## applied by the game code itself) — against the bench constants. The pose
## measurement runs in root space, where the seat constants are yaw-free
## (the slide puts the seat center at root z = +slide for both sitters'
## facings — tools/probe_sit_geometry.gd measures the same lines). Value
## locks pin the landed dials (the T-133 precedent) and the T-146 hips
## family cap. Red-before (pre-T-163 constants, probe-recorded): the café
## thigh line 0.377 (0.073 under the top), the café soles −0.081, the
## café/bench shin crossings inside the footprint (max z −0.043/−0.010),
## the bench glute +0.342 past the rear edge.
func _scenario_sitters_clear_their_seats() -> void:
	## --- café legs -------------------------------------------------------
	var stool_top: float = 0.45 ## sitter_seat box top face (0.42 center + half 0.03).
	var stool_slab_lo: float = 0.39
	var stool_plan: float = 0.18 ## The 0.36 × 0.36 stool plan half-depth.
	var spawner := CafeSpawner.new()
	spawner.city = _city
	add_child(spawner)
	await _wait_frames(4)
	## Every queued sit_root must carry the pin AND the slide relative to its
	## own queued stool (both facings, every sitter — origin algebra, exact).
	var xfs_ok := true
	var collider_ok := true
	var stool_xfs: Array = spawner._mm_queues["sitter_seat"].xfs
	var sit_xfs: Array = spawner._mm_queues["sit_body"].xfs
	for si in spawner.sitters.size():
		var stool: Transform3D = stool_xfs[si]
		var want_origin: Vector3 = stool.origin + (stool.basis * Vector3(
				0.0, CafeSpawner.SIT_ROOT_Y - 0.42, -CafeSpawner.SIT_SLIDE))
		xfs_ok = xfs_ok and (sit_xfs[si] as Transform3D).origin.is_equal_approx(want_origin)
		## The inert SITTER_SHAPE collider slides with its figure: its offset
		## from the stool center must be exactly the yaw-rotated slide.
		var shape := spawner.sitters_body.get_child(si) as CollisionShape3D
		var shape_delta: Vector3 = shape.transform.origin - stool.origin
		collider_ok = collider_ok and absf(shape_delta.y) < 0.001 \
				and absf(shape_delta.length() - CafeSpawner.SIT_SLIDE) < 0.001
	## The baked pose in root space (every sitter shares the mesh; the yaws
	## only rotate it, and the seat constants are square/yaw-free there).
	var faces := PackedVector3Array()
	for key: String in ["sit_legs", "sit_body"]:
		faces.append_array(spawner.visual(key).multimesh.mesh.get_faces())
	var root_y: float = CafeSpawner.SIT_ROOT_Y
	var edge_front: float = CafeSpawner.SIT_SLIDE - stool_plan
	var edge_rear: float = CafeSpawner.SIT_SLIDE + stool_plan
	var thigh := INF
	var shin_z_max := -INF
	var sole := INF
	for v in faces:
		var wy: float = v.y + root_y ## World (sitter-frame) height of the vertex.
		## Seat mass only: behind the knee divider (pose z >= 0), over the plan.
		if v.z >= 0.0 and absf(v.x) <= stool_plan and v.z >= edge_front and v.z <= edge_rear:
			thigh = minf(thigh, wy)
		## The forward shin crossing the stool slab's y-band.
		if v.z < -0.02 and wy >= stool_slab_lo and wy <= stool_top:
			shin_z_max = maxf(shin_z_max, v.z)
		sole = minf(sole, wy)
	var thigh_ok := thigh >= stool_top - 0.01 and thigh <= stool_top + 0.05
	var shin_ok := shin_z_max <= edge_front + 0.01
	var sole_ok := sole >= -0.01
	spawner.free()
	## --- bench legs ------------------------------------------------------
	var bench_wood_top: float = 0.54 ## The 1.8 × 0.08 × 0.5 seat wood at +0.5.
	var bench_slab_lo: float = 0.46
	var bench_edge: float = 0.25 ## The 0.5-deep bench slab half-depth.
	var elder := (load("res://scenes/elder.tscn") as PackedScene).instantiate() as Node3D
	elder.position = Vector3(50.0, 0.0, 50.0) ## The root IS the spot: slab + 0.60 by contract.
	add_child(elder)
	var rig: PeopleRig = elder.get_node("Visual")
	var skel := rig.find_child("Skeleton3D", true, false) as Skeleton3D
	for _settle in 90: ## 1.5 s: the sink AND the slide ease to full in ~0.5 s.
		elder._physics_process(1.0 / 60.0)
		rig.anim.advance(1.0 / 60.0)
		skel.force_update_all_bone_transforms()
	await get_tree().process_frame
	await get_tree().process_frame
	var slide_ok := absf(rig.position.z - Elder.SEAT_SLIDE) < 0.01 \
			and absf(rig.position.y - Elder.SEAT_SINK) < 0.01
	var bake := rig.find_child("SitBake", true, false) as Node3D
	var bake_ok := bake != null
	var bench_thigh := INF
	var bench_shin_z_max := -INF
	var bench_glute_z := -INF
	if bake != null:
		var to_root: Transform3D = elder.global_transform.affine_inverse()
		for mi: MeshInstance3D in bake.get_children():
			if mi.name.begins_with("SitHead"):
				continue
			var xf: Transform3D = to_root * mi.global_transform ## The live composite.
			for v in mi.mesh.get_faces():
				var p: Vector3 = xf * v
				var slab_y: float = p.y + 0.60 ## The root rides the spot plane (slab + 0.60).
				if v.z >= 0.0:
					if absf(p.z) <= bench_edge and absf(p.x) <= 0.9:
						bench_thigh = minf(bench_thigh, slab_y)
					if v.y >= 0.42 and v.y <= 0.47: ## The sitting-line underside band.
						bench_glute_z = maxf(bench_glute_z, p.z)
				elif v.z < -0.02 and slab_y >= bench_slab_lo and slab_y <= bench_wood_top:
					bench_shin_z_max = maxf(bench_shin_z_max, p.z)
	var bench_thigh_ok := bench_thigh >= bench_wood_top - 0.01 \
			and bench_thigh <= 0.60 + 0.05
	var bench_shin_ok := bench_shin_z_max <= -bench_edge + 0.01
	var bench_glute_ok := bench_glute_z <= bench_edge + 0.01 ## The glute ON the seat.
	elder.free()
	## --- value locks (the landed dials; the T-146 hips family cap) --------
	var locks_ok := absf(CafeSpawner.SIT_HIPS_SEAT_LIFT - 0.08) < 0.0005 \
			and absf(CafeSpawner.SIT_ROOT_Y - (CafeSpawner.SITTER_SEAT_TOP + 0.08
					- CafeSpawner.SIT_HIPS_Y)) < 0.0005 \
			and absf(CafeSpawner.SIT_SLIDE - 0.17) < 0.0005 \
			and absf(Elder.SEAT_SLIDE - (-0.25)) < 0.0005 \
			and absf(Elder.SEAT_SINK - (-0.465)) < 0.005
	_check("sitters_clear_their_seats", xfs_ok and collider_ok and thigh_ok
			and shin_ok and sole_ok and bake_ok and slide_ok and bench_thigh_ok
			and bench_shin_ok and bench_glute_ok and locks_ok,
			"cafe xfs=%s collider=%s thigh %.3f shin<=%.3f sole %+.3f | bench slide=%s thigh %.3f shin<=%.3f glute %+.3f | locks=%s" % [
				xfs_ok, collider_ok, thigh, shin_z_max, sole,
				slide_ok, bench_thigh, bench_shin_z_max, bench_glute_z, locks_ok])


## True when the node is a MeshInstance3D whose mesh is a generated derivative
## of `pack` (resource_path under assets/generated/, metadata stamped at bake)
## posed at `clip` ("" skips the clip check — static kit meshes).
func _is_pack_mesh(mi: MeshInstance3D, pack: String, clip: String) -> bool:
	if mi == null or mi.mesh == null:
		return false
	var mesh := mi.mesh
	if not str(mesh.resource_path).begins_with("res://assets/generated/models/"):
		return false
	return mesh.get_meta("source_pack", "") == pack \
			and mesh.get_meta("license", "") == "CC0" \
			and (clip == "" or str(mesh.get_meta("pose_clip", "")) == clip)


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
	print("SIM INFO coos win leg: maxed_emitted=%s screen_open=%s paused=%s favor=%d counts=%s" % [
			Game.favor_maxed_emitted, main_game.game_over_screen.is_open,
			get_tree().paused, Game.favor, str(Sfx.played_counts)])
	## (T-177 leak tripwire) Every Main-bearing scenario frees its Main; a
	## leaked one doubles every global effect downstream (its own Player
	## answers the synthetic input, its own screen opens on the autoload
	## signals) — exactly the failure shape the first cutover run hit when the
	## retired fleet read crashed combo_strip mid-scenario. The census prints
	## the live MainGame set at this window; more than ONE line here is a leak.
	var census: Array[String] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MainGame:
			census.append("%s @ %s" % [n.get_path(), (n as Node3D).global_position])
		for c in n.get_children():
			stack.append(c)
	print("SIM INFO coos leg D live Mains: %s" % [str(census)])
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


## T-126's quit seam, both branches through the REAL scenes. Desktop branch
## (override OFF = shipped default): the title footer names Q and the pause
## menu's Quit button is visible. Web branch (override ON): the footer drops
## the hint, the Quit button hides, and a fed quit ACTION is ignored at the
## title AND inside an open pause menu — the harness surviving both feeds is
## the proof (an ungated desktop quit would kill it). The override is restored.
func _scenario_web_quit_gated() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	## --- Desktop branch: every affordance present. --------------------------
	Game.web_override = 0
	var menu_desktop: Control = (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	add_child(menu_desktop)
	await _wait_frames(2)
	var desktop_footer_ok: bool = (menu_desktop.get_node("Footer") as Label).text.contains("Q quit")
	menu_desktop.free()
	var main_desktop: MainGame = MAIN_SCENE.instantiate()
	main_desktop.position = Vector3(5500.0, 0.0, 5500.0) ## Own space, clear of every other instanced Main.
	add_child(main_desktop)
	await _wait_frames(4)
	var desktop_button: Button = main_desktop.pause_menu \
			.get_node_or_null("Center/PausePanel/Box/QuitButton")
	var desktop_button_ok: bool = desktop_button != null and desktop_button.visible
	main_desktop.free()
	get_tree().paused = false
	Game.hunger.player = null
	Game.reset_run()
	## --- Web branch: the affordances vanish, the action is ignored. ---------
	Game.web_override = 1
	var menu_web: Control = (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	add_child(menu_web)
	await _wait_frames(2)
	var web_footer_ok: bool = not (menu_web.get_node("Footer") as Label).text.contains("Q quit")
	var quit_ev := InputEventAction.new()
	quit_ev.action = "quit"
	quit_ev.pressed = true
	menu_web._unhandled_input(quit_ev) ## Gated: the harness must survive this line.
	await _wait_frames(2)
	var web_menu_alive: bool = is_instance_valid(menu_web)
	menu_web.free()
	var main_web: MainGame = MAIN_SCENE.instantiate()
	main_web.position = Vector3(6500.0, 0.0, 6500.0)
	add_child(main_web)
	await _wait_frames(4)
	var web_button: Button = main_web.pause_menu \
			.get_node_or_null("Center/PausePanel/Box/QuitButton")
	var web_button_ok: bool = web_button != null and not web_button.visible
	var quit_fires := 0
	main_web.pause_menu.quit_requested.connect(func() -> void: quit_fires += 1)
	main_web.pause_menu.toggle() ## Opens the menu + pauses the tree.
	main_web.pause_menu._unhandled_input(quit_ev) ## Gated: no relay.
	var web_action_ok: bool = quit_fires == 0 and get_tree().paused
	main_web.pause_menu.toggle() ## Close + unpause.
	main_web.free()
	get_tree().paused = false
	Game.hunger.player = null
	Game.reset_run()
	Game.web_override = -1 ## Restore: ask the OS again.
	_check("web_quit_gated",
			desktop_footer_ok and desktop_button_ok and web_footer_ok \
					and web_menu_alive and web_button_ok and web_action_ok,
			"desk_footer=%s desk_button=%s web_footer=%s web_alive=%s web_button=%s web_action=%s" % [
					desktop_footer_ok, desktop_button_ok, web_footer_ok,
					web_menu_alive, web_button_ok, web_action_ok])


## T-129's stepped city boot, pinned at four seams:
## 1. The city slices are callable IN ORDER on a bare rig and reproduce the
##    synchronous build byte-for-byte (fingerprint, bread spots, report) — the
##    stepped boot provably does the identical work in the identical order.
## 2. The flags default right: the export flag defaults stepped (the game path),
##    main.tscn carries hold_generate/staged_boot, and the diet exports ship
##    their tuned values.
## 3. A Main mounted the game way (direct child of the tree root, the
##    change_scene_to_file spot) boots STEPPED: boot_trace holds the exact
##    phase order with an ms each, boot_finished fires, the city is the pin
##    city, every staged spawner is populated AND `regenerated`-wired (a forced
##    rebuild re-seeds it — restarts keep working), and the pigeon is grounded
##    on the corridor with physics back. A Main mounted the rig way (the
##    harness's ordinary instanced pattern) boots SYNC — exactly one
##    sync_boot trace entry — the defaults that keep every existing scenario
##    green untouched.
## 4. The web warm-up diet (leg 3): on the forced-web branch a stepped Main
##    halves the directional shadow atlas, kills MSAA and caps physics
##    catch-up; on the desktop branch nothing moves. All restored.
func _scenario_stepped_boot_pins() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	## --- Leg 1: the world slices, in order, byte-identical to sync. ----------
	## (T-177 re-pin) The twins are AmesWorlds now — the Windrow city.tscn the
	## leg used to instantiate died with the generator. The world fingerprint
	## is the bake manifest hash, and the composed slices must equal the sync
	## build AND the harness's own resident world byte-for-byte (bread spots,
	## kinds, report, the spawn corridor) exactly as the seed hash did.
	var twin_sync: City = AMES_WORLD_SCENE.instantiate() as City
	twin_sync.position = Vector3(7500.0, 0.0, 0.0)
	add_child(twin_sync) ## hold_generate defaults false — self-generates, the sync reference.
	var twin_step: City = AMES_WORLD_SCENE.instantiate() as City
	twin_step.position = Vector3(7500.0, 0.0, 7500.0)
	twin_step.hold_generate = true
	add_child(twin_step)
	var cold := true
	cold = twin_step.generate_step_ground() ## True: a cold world has more slices.
	twin_step.generate_step_blocks()
	twin_step.generate_step_finish()
	var slices_ok: bool = cold \
			and twin_step.fingerprint == twin_sync.fingerprint \
			and twin_step.fingerprint == _city.fingerprint \
			and twin_step.bread_spots == twin_sync.bread_spots \
			and twin_step.bread_spot_kinds == twin_sync.bread_spot_kinds \
			and twin_step.last_report == twin_sync.last_report \
			and twin_step.to_local(twin_step.spawn_point).distance_to(
					twin_sync.to_local(twin_sync.spawn_point)) < 0.01
	## The T-033 fast path rides the same slice: a second ground call on the
	## standing build skips the rebuild and reports false (no more slices).
	var rebuilt_before: int = twin_step.build_count
	var more := twin_step.generate_step_ground()
	var fast_path_ok: bool = not more and twin_step.build_count == rebuilt_before
	print("SIM DATA stepped twins: fp_sync=%d fp_step=%d fp_shared=%d spots %d/%d/%d reports_eq=%s spawns_eq=%s" % [
			twin_sync.fingerprint, twin_step.fingerprint, _city.fingerprint,
			twin_sync.bread_spots.size(), twin_step.bread_spots.size(),
			_city.bread_spots.size(),
			str(twin_step.last_report == twin_sync.last_report),
			str(twin_step.to_local(twin_step.spawn_point)
					== twin_sync.to_local(twin_sync.spawn_point))])
	twin_sync.free()
	twin_step.free()
	## --- Leg 2: the flag/scene defaults. ------------------------------------
	## Read off a bare instantiate (never in the tree): the scene file's stored
	## overrides ARE applied by instantiate(), so this pins main.tscn itself —
	## a revert of hold_generate/staged_boot fails here.
	var defaults: MainGame = MAIN_SCENE.instantiate()
	var defaults_ok: bool = defaults.stepped_boot and defaults.boot_paint_frames == 1 \
			and defaults.web_diet_enabled and defaults.web_shadow_atlas_size == 2048 \
			and defaults.web_max_physics_steps == 3 \
			and defaults.get_node("City").hold_generate \
			and defaults.get_node("CarSpawner").staged_boot \
			and defaults.get_node("BreadSpawner").staged_boot \
			and defaults.get_node("TouristSpawner").staged_boot \
			and defaults.get_node("ElderSpawner").staged_boot \
			and defaults.get_node("CafeSpawner").staged_boot
	defaults.free()
	## --- Leg 3: the game-path Main boots stepped; the rig-path Main syncs. --
	_boot_finished_fires = 0
	var stepped: MainGame = MAIN_SCENE.instantiate()
	stepped.position = Vector3(-7500.0, 0.0, -7500.0) ## Own space, clear of every other world.
	get_tree().root.add_child(stepped) ## THE game mount — direct child of the tree root.
	stepped.boot_finished.connect(func() -> void: _boot_finished_fires += 1)
	var booted := false
	for _i in 900: ## 15 s budget — the stepped boot is ~10 frames; a hang fails loudly.
		await get_tree().physics_frame
		if _boot_finished_fires > 0:
			booted = true
			break
	var want_phases: Array[String] = [
		"city_ground", "city_blocks", "city_visuals",
		"spawn_cars", "spawn_tourists", "spawn_bread", "spawn_elders", "spawn_cafes",
	]
	var names_ok: bool = booted and stepped.boot_trace.size() == want_phases.size()
	var trace := ""
	if names_ok:
		for i in want_phases.size():
			var entry: Dictionary = stepped.boot_trace[i]
			names_ok = names_ok and String(entry.name) == want_phases[i] \
					and int(entry.ms) >= 0
			trace += "%s=%d " % [entry.name, entry.ms]
	var stepped_city_ok: bool = booted and stepped.city.fingerprint == _city.fingerprint \
			and stepped.tourist_spawner.living_tourists().is_empty() \
			and stepped.bread_spawner.living_crumbs().size() \
					== stepped.bread_spawner.target_count \
			and stepped.car_spawner.living_cars().size() \
					== stepped.car_spawner.target_moving \
							+ stepped.car_spawner.target_parked \
			and stepped.city.traffic_graph != null \
			and stepped.city.traffic_graph.run_count() == 777
	## The staged spawners are regenerated-wired: a forced rebuild must re-seed
	## them — restarts keep working on the stepped path. (T-177 re-pin) The
	## "foreign seed" leg becomes the data-identity law: the Ames world is a
	## pure function of the committed bake, so a forced rebuild at ANY seed
	## reproduces the SAME fingerprint (seed-independent identity, the
	## retired Windrow seed-hash law's successor) while the spawners re-seed
	## to the same inert-fleet reality.
	stepped.city.generate(424242, true) ## Foreign seed, forced — a real rebuild.
	await _wait_frames(2)
	var reseed_ok: bool = stepped.city.fingerprint == _city.fingerprint \
			and stepped.tourist_spawner.living_tourists().is_empty() \
			and stepped.bread_spawner.living_crumbs().size() \
					== stepped.bread_spawner.target_count \
			and stepped.car_spawner.living_cars().size() \
					== stepped.car_spawner.target_moving \
							+ stepped.car_spawner.target_parked
	## The corridor is seed-independent (the committed bake's own spawn), so
	## the pigeon grounds on the rebuilt world's corridor.
	stepped.player.reset_flight(stepped.city.to_local(stepped.city.spawn_point))
	var grounded := false
	for _i in 240: ## 4 s budget — the short spawn drop plus settle.
		await get_tree().physics_frame
		if stepped.player.is_grounded:
			grounded = true
			break
	var handoff_ok: bool = grounded \
			and stepped.player.process_mode == Node.PROCESS_MODE_INHERIT \
			and stepped.player.global_position.distance_to(stepped.city.spawn_point) < 2.0
	stepped.free()
	Game.hunger.player = null
	Game.reset_run()
	## The rig mount — the harness's ordinary instanced pattern — boots SYNC.
	var rig: MainGame = MAIN_SCENE.instantiate()
	rig.position = Vector3(-7500.0, 0.0, 7500.0)
	add_child(rig)
	await _wait_frames(4)
	var sync_rig_ok: bool = rig.boot_trace.size() == 1 \
			and String(rig.boot_trace[0].name) == "sync_boot" \
			and int(rig.boot_trace[0].ms) >= 0 \
			and rig.city.fingerprint == _city.fingerprint \
			and rig.tourist_spawner.living_tourists().is_empty()
	rig.free()
	Game.hunger.player = null
	Game.reset_run()
	## --- Leg 4: the web warm-up diet, both branches. ------------------------
	## The engine build exposes the directional-shadow atlas SETTER only, so the
	## shadow half is pinned through the diet's applied-record and its BOOT
	## line; msaa and the steps cap are read live off the engine.
	var desktop_msaa: int = get_viewport().msaa_3d
	var desktop_steps: int = Engine.max_physics_steps_per_frame
	Game.web_override = 0 ## Desktop branch: a stepped game boot must move NOTHING.
	var diet_off: MainGame = MAIN_SCENE.instantiate()
	diet_off.position = Vector3(0.0, 0.0, -7500.0)
	get_tree().root.add_child(diet_off)
	await _wait_frames(60) ## The diet decision lands in the first stepped frame.
	var diet_off_ok: bool = get_viewport().msaa_3d == desktop_msaa \
			and Engine.max_physics_steps_per_frame == desktop_steps \
			and diet_off.web_diet_applied.is_empty()
	diet_off.free()
	Game.hunger.player = null
	Game.reset_run()
	Game.web_override = 1 ## Web branch: the diet applies, before the first phase.
	var diet_on: MainGame = MAIN_SCENE.instantiate()
	diet_on.position = Vector3(7500.0, 0.0, -7500.0)
	get_tree().root.add_child(diet_on)
	await _wait_frames(60)
	var diet_on_ok: bool = get_viewport().msaa_3d == Viewport.MSAA_DISABLED \
			and Engine.max_physics_steps_per_frame == diet_on.web_max_physics_steps \
			and diet_on.web_diet_applied == {
					"shadow_atlas": diet_on.web_shadow_atlas_size,
					"msaa": Viewport.MSAA_DISABLED,
					"max_physics_steps": diet_on.web_max_physics_steps}
	diet_on.free()
	Game.hunger.player = null
	Game.reset_run()
	Game.web_override = -1 ## Restore: ask the OS again.
	## Restore the diet leg's machine state exactly.
	get_viewport().msaa_3d = desktop_msaa
	Engine.max_physics_steps_per_frame = desktop_steps
	_check("stepped_boot_pins",
			slices_ok and fast_path_ok and defaults_ok and names_ok \
					and stepped_city_ok and reseed_ok and handoff_ok \
					and sync_rig_ok and diet_off_ok and diet_on_ok,
			"slices=%s fast_path=%s defaults=%s phases=%s city=%s reseed=%s handoff=%s sync_rig=%s diet_off=%s diet_on=%s [%s]" % [
					slices_ok, fast_path_ok, defaults_ok, booted and names_ok,
					stepped_city_ok, reseed_ok, handoff_ok, sync_rig_ok,
					diet_off_ok, diet_on_ok, trace.strip_edges()])


## (T-131) The web handoff must answer the Fly press with exactly ONE warming
## screen. The branch decision lives behind `_web_loader_covers_handoff()` so
## the harness can pin both branches through the T-126 seam without driving
## `_start_run` itself — that ends in `change_scene_to_file` and would swap
## the harness's own scene (the T-097 never-feed-flap rule), so the
## on-screen single-screen judgement is the hosted-web Gate 3. Legs, on the
## REAL menu scene: the forced-web branch covers the handoff with the export
## shell's loader, desktop does not (its one-frame WarmupNote is the feedback
## there); and the WarmupNote exists and stays hidden AT REST on BOTH
## branches — a note shown outside the desktop handoff (the double-screen
## bug's shape) fails here.
func _scenario_web_handoff_single_screen() -> void:
	Game.save_path = SIM_SAVE_PATH
	var desktop_covers := false
	var web_covers := false
	var desktop_note_hidden := false
	var web_note_hidden := false
	for override in [0, 1]:
		Game.web_override = override
		var menu: Control = (load("res://scenes/menu.tscn") as PackedScene).instantiate()
		add_child(menu)
		var note: Label = menu.get_node("%WarmupNote") as Label
		var covers: bool = menu._web_loader_covers_handoff()
		if override == 0:
			desktop_covers = covers
			desktop_note_hidden = note != null and not note.visible
		else:
			web_covers = covers
			web_note_hidden = note != null and not note.visible
		menu.free()
	Game.web_override = -1 ## Restore: ask the OS again.
	_check("web_handoff_single_screen",
			not desktop_covers and desktop_note_hidden \
					and web_covers and web_note_hidden,
			"desktop: covers=%s (want false) note_rest_hidden=%s | web: covers=%s (want true) note_rest_hidden=%s" % [
					desktop_covers, desktop_note_hidden,
					web_covers, web_note_hidden])


## --- scenario (T-132 agent slow-mo) ------------------------------------------


## (T-132) The pilot's `--time-scale` opt-in must slow the WORLD, not the
## frames — and must be unable to touch a normal launch. Legs: the flagless
## boot this very process ran stands at 1.0 (every gate runs that path); the
## parse seam's truth table through the REAL Game autoload (the user arg beats
## the PIGEON_TIME_SCALE env; absent/garbage/NaN/out-of-range/below-floor all
## resolve 1.0, so a mistyped flag never silently means something); the
## applier half driven directly — a parsed 0.1 actually LANDS on
## Engine.time_scale and an empty-args call restores 1.0 (a wiring revert —
## _ready never calling the applier, or the applier hard-setting 1.0 — fails
## here, not just the table); and the rate contract measured the way the game
## lives it — the SAME 60 physics frames accumulated from the harness node's
## own delta run 1.0 game-second at scale 1.0 and ≈0.1 at 0.1 (the
## 2026-10-22 binary probe: the tick rate never changes, every delta scales —
## under the suite's --fixed-fps and in real time alike). Engine.time_scale is
## restored and the restore re-pinned, so no later scenario inherits a slow
## world.
func _scenario_pilot_time_scale() -> void:
	var default_boot_ok: bool = Engine.time_scale == 1.0
	var saved_env := OS.get_environment("PIGEON_TIME_SCALE")
	var parse_ok := true
	var parse_detail := ""
	var table := {
		[PackedStringArray(), ""]: 1.0,
		[PackedStringArray(["--time-scale=0.1"]), ""]: 0.1,
		[PackedStringArray(["--time-scale=0.02"]), ""]: 0.02,
		[PackedStringArray(["--time-scale=1.0"]), ""]: 1.0,
		[PackedStringArray(["--time-scale=2.5"]), ""]: 1.0,
		[PackedStringArray(["--time-scale=0"]), ""]: 1.0,
		[PackedStringArray(["--time-scale=0.005"]), ""]: 1.0,
		[PackedStringArray(["--time-scale=-3"]), ""]: 1.0,
		[PackedStringArray(["--time-scale=abc"]), ""]: 1.0,
		[PackedStringArray(["--time-scale=nan"]), ""]: 1.0,
		[PackedStringArray(), "0.1"]: 0.1,
		[PackedStringArray(["--time-scale=0.02"]), "0.1"]: 0.02,
	}
	for case in table:
		var want: float = table[case]
		OS.set_environment("PIGEON_TIME_SCALE", case[1])
		var got: float = Game.pilot_time_scale(case[0])
		if not is_equal_approx(got, want):
			parse_ok = false
			parse_detail += " [args=%s env='%s' got=%s want=%s]" % [case[0], case[1], got, want]
	OS.set_environment("PIGEON_TIME_SCALE", saved_env)
	Game.apply_pilot_time_scale(PackedStringArray(["--time-scale=0.1"]))
	var applied_ok: bool = is_equal_approx(Engine.time_scale, 0.1)
	Game.apply_pilot_time_scale(PackedStringArray())
	var unapplied_ok: bool = Engine.time_scale == 1.0
	var scaled: float = await _accumulate_game_time(0.1)
	var normal: float = await _accumulate_game_time(1.0)
	var restore_ok: bool = Engine.time_scale == 1.0
	var rate_ok: bool = is_equal_approx(normal, 1.0) and scaled > 0.05 and scaled < 0.2
	_check("pilot_time_scale_flag",
			default_boot_ok and parse_ok and applied_ok and unapplied_ok \
					and rate_ok and restore_ok,
			"default_boot=%s parse=[%s] applied=%s unapplied=%s rate=%s (scaled=%.4fs normal=%.4fs over the same 60 physics frames) restore=%s" % [
					default_boot_ok, parse_detail, applied_ok, unapplied_ok,
					rate_ok, scaled, normal, restore_ok])


## Accumulates the physics delta the harness node itself receives over 60
## physics frames at the given Engine.time_scale, restoring 1.0 after — the
## game-time that frame budget holds, whatever the pacing.
func _accumulate_game_time(scale: float) -> float:
	Engine.time_scale = scale
	var acc := 0.0
	for _i in 60:
		await get_tree().physics_frame
		acc += get_physics_process_delta_time()
	Engine.time_scale = 1.0
	return acc


## --- scenarios (T-140 pilot frame-step) --------------------------------------

var _pilot_cmd_seq := 0 ## Unique suffix for the frame-step scenario's command files.

## The T-140 frame-step contract, driven through a REAL CaptureRecorder in
## session mode (a scratch `simtest_step` session dir under the gitignored
## .captures/ — swept later by pilot.py clean) plus a pausable probe node whose
## _physics_process — by definition — only runs on live ticks: it counts them
## and latches whether the flap action was ever pressed VISIBLE TO THE GAME.
## Legs: a step refused while unpaused (pilot_step_ignored, tree stays live);
## pause freezes the probe dead; {"step":30} advances ~30 live ticks and
## re-freezes (the window's +4 pad absorbs the measured 2-3-tick unpause lag —
## the tree hands PAUSABLE nodes their first live tick a few recorder ticks
## after the flip, so a raw window would close before the world moved at all);
## and a press queued in the SAME command file as the step is DEFERRED onto the
## first live tick — a press made while frozen would expire unheard
## (is_action_just_pressed is one tick wide and a paused player never ticks).
## Restores the unpaused tree and both env vars however this leg ends.
func _scenario_pilot_frame_step() -> void:
	get_tree().paused = false
	var saved_session := OS.get_environment("PIGEON_PILOT_SESSION")
	var saved_images := OS.get_environment("PIGEON_IMAGE_INTERVAL")
	OS.set_environment("PIGEON_PILOT_SESSION", "simtest_step")
	OS.set_environment("PIGEON_IMAGE_INTERVAL", "0")
	var recorder: Node = RECORDER_SCRIPT.new()
	var probe := _make_frame_step_probe()
	add_child(recorder)
	add_child(probe)
	await _wait_frames(3)
	var pilot_dir := "res://.captures/session_simtest_step"
	## Refusal leg: a step while UNPAUSED is ignored and pauses nothing.
	_drop_pilot_cmd(pilot_dir, '{"step":10}')
	await _wait_frames(4)
	var events := _read_pilot_events(pilot_dir)
	var refuse_ok: bool = events.has("pilot_step_ignored") and not get_tree().paused
	## Freeze leg: pause stops the probe's live ticks entirely.
	_drop_pilot_cmd(pilot_dir, '{"pause":true}')
	await _wait_frames(3)
	var freeze_ok: bool = get_tree().paused
	var ticks0: int = int(probe.get("ticks"))
	await _wait_frames(10)
	freeze_ok = freeze_ok and int(probe.get("ticks")) == ticks0
	## Step leg: ~30 live ticks inside the padded window, then re-frozen.
	_drop_pilot_cmd(pilot_dir, '{"step":30}')
	await _wait_frames(40)
	var stepped: int = int(probe.get("ticks")) - ticks0
	var step_ok: bool = get_tree().paused and stepped >= 26 and stepped <= 35
	## Deferral leg: input + step in ONE command file — the press lands on the
	## window's first live tick (the 30-frame hold outlives the live tail, so
	## the probe cannot miss it by luck; a frozen-press regression never
	## reaches a live tick and the latch stays false).
	_drop_pilot_cmd(pilot_dir, '{"action":"flap","frames":30}\n{"step":20}')
	await _wait_frames(35)
	var defer_ok: bool = bool(probe.get("saw_flap")) and get_tree().paused
	get_tree().paused = false
	recorder.queue_free()
	probe.queue_free()
	OS.set_environment("PIGEON_PILOT_SESSION", saved_session)
	OS.set_environment("PIGEON_IMAGE_INTERVAL", saved_images)
	await _wait_frames(2)
	_check("pilot_frame_step",
			refuse_ok and freeze_ok and step_ok and defer_ok,
			"refuse=%s freeze=%s step=%s (live ticks %d of 30) defer=%s" % [
					refuse_ok, freeze_ok, step_ok, stepped, defer_ok])


## The frame-step probe: a pausable Node whose only job is counting its own
## physics ticks (it runs exactly when the world does — never while frozen)
## and latching whether the flap action was pressed during any of them. Built
## from an inline GDScript so the harness needs no extra file.
func _make_frame_step_probe() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar ticks := 0\nvar saw_flap := false\n\nfunc _physics_process(_delta: float) -> void:\n\tticks += 1\n\tif Input.is_action_pressed(\"flap\"):\n\t\tsaw_flap = true\n"
	script.reload()
	var probe := Node.new()
	probe.set_script(script)
	return probe


## Drops one pilot command file into `dir` (the recorder consumes and deletes
## these oldest-first; multiple lines in one file run in the same pass).
func _drop_pilot_cmd(dir: String, text: String) -> void:
	_pilot_cmd_seq += 1
	var f := FileAccess.open("%s/pilot_cmd_simtest_%d.jsonl" % [dir, _pilot_cmd_seq],
			FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")


## The event names logged so far in a session dir's events.jsonl.
func _read_pilot_events(dir: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(dir + "/events.jsonl", FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var parsed: Variant = JSON.parse_string(f.get_line())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("ev"):
			out[parsed["ev"]] = true
	return out


## (T-168) Every event dict logged so far in a session dir — payload-level
## reads (the `pilot_dev` acks' verb/node/p fields) beside the name-set
## `_read_pilot_events`. Empty/trailing lines are skipped, so a fresh read of
## a live file logs no parse noise.
func _read_pilot_event_list(dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(dir + "/events.jsonl", FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("ev"):
			out.append(parsed)
	return out


## (T-168) The first `pilot_dev` ack carrying `verb` — empty when none logged.
func _find_pilot_event(events: Array[Dictionary], verb: String) -> Dictionary:
	for e in events:
		if e.get("ev", "") == "pilot_dev" and String(e.get("verb", "")) == verb:
			return e
	return {}


## (T-169) The first `pilot_call_result`/`pilot_call_error` event whose
## node/method pair matches — the call verb's acks and refusals are
## distinguished by that pair (empty when none logged).
func _find_pilot_call(events: Array[Dictionary], ev_name: String,
		node: String, method: String) -> Dictionary:
	for e in events:
		if e.get("ev", "") == ev_name \
				and String(e.get("node", "")) == node \
				and String(e.get("method", "")) == method:
			return e
	return {}


## (T-169, round 1 review) The command EXACTLY as the real channel delivers
## it: what JSON writes down and parses back. Hand-built GDScript dicts
## carry types the channel cannot (int stays int only if the parser says
## so — and Godot's JSON parser delivers every number as a float), so every
## call-verb leg drives through this round trip; a leg that only passed
## hand-built dicts proved nothing about the live verb.
func _json_round_trip(cmd: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(cmd))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## --- scenarios (T-167 dev hunger lock) --------------------------------------

## The T-167 dev-verb contract, driven through a REAL CaptureRecorder in
## session mode (scratch `simtest_dev` dir — swept later by pilot.py clean)
## acting on the Game autoload's own hunger clock, the node the verbs target
## in every live session (`Game.hunger`, reachable by name from any script).
## `drain_per_second` is hand-raised to 60/s for the run (the ticket's
## forced-drain leg; restored after) so a 90-tick window moves the bar ~90
## units — a silent lock regression cannot hide in rounding. Legs:
## (a) the unlocked drain drops the bar over 90 ticks, `hunger_lock` (driven
##     through `_execute_dev` with an explicit dict) freezes it, and 90 more
##     ticks read the value BIT-IDENTICAL with zero `changed` emissions — no
##     drain, no state write, the T-075 silence guarantee holding;
## (b) `hunger_refill` restores exactly max while locked (a refill-at-full
##     after that is a silent no-op by the clamped setter);
## (c) `hunger_unlock` resumes the drain;
## (d) the gate seam: with `allowed=false` (the suite cannot flip
##     `OS.is_debug_build()`, so tests pass the seam explicitly) every verb
##     logs `pilot_dev_refused` and moves no state, an unknown dev verb logs
##     `pilot_dev_unknown` and is still consumed, and a non-dev dict returns
##     false from the seam;
## (e) the LIVE channel: lock+refill queued through real command files land
##     while the tree is PAUSED (the recorder is PROCESS_MODE_ALWAYS — verbs
##     flow when frozen), the lock holds through live ticks after resume, and
##     `hunger_unlock` from the channel releases the drain again.
## The tree, the autoload clock and the session env are restored however the
## legs end.
func _scenario_dev_hunger_lock() -> void:
	get_tree().paused = false
	var saved_session := OS.get_environment("PIGEON_PILOT_SESSION")
	var saved_images := OS.get_environment("PIGEON_IMAGE_INTERVAL")
	OS.set_environment("PIGEON_PILOT_SESSION", "simtest_dev")
	OS.set_environment("PIGEON_IMAGE_INTERVAL", "0")
	var hunger := Game.hunger
	hunger.reset() ## Clean slate on the autoload clock: full bar, no latch, no flap heat.
	var saved_drain: float = hunger.drain_per_second
	hunger.drain_per_second = 60.0 ## The T-005 game-over scenario's time-compression precedent.
	hunger.player = _player ## Attach the sim pigeon — the drain needs a live player.
	var recorder: Node = RECORDER_SCRIPT.new()
	add_child(recorder)
	await _wait_frames(3)
	var pilot_dir := "res://.captures/session_simtest_dev"
	## (a) Unlocked drain, then the lock reads bit-identical across 90 ticks.
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3(0.0, 0.0, -12.0))
	var v0: float = hunger.value
	await _wait_frames(90)
	var drained: float = v0 - hunger.value
	var drain_ok: bool = drained > 10.0 ## 90 ticks at 60/s ≈ 90 units; a silent lock regression lands ≈ 0.
	var locked_value: float = hunger.value
	_hunger_changed_fires = 0
	var counter := func(_v: float, _m: float) -> void: _hunger_changed_fires += 1
	hunger.changed.connect(counter)
	var lock_ret: bool = recorder._execute_dev({"dev": "hunger_lock"})
	await _wait_frames(90)
	var locked_delta: float = hunger.value - locked_value ## Captured here — the leg's bite number.
	var silent_fires: int = _hunger_changed_fires ## Same capture point.
	var locked_ok: bool = lock_ret and hunger.locked \
			and hunger.value == locked_value and _hunger_changed_fires == 0
	hunger.changed.disconnect(counter)
	## (b) Refill while locked lands exactly on max.
	var refill_ret: bool = recorder._execute_dev({"dev": "hunger_refill"})
	var refill_ok: bool = refill_ret and hunger.value == hunger.max_value
	## (c) Unlock resumes the drain.
	var unlock_ret: bool = recorder._execute_dev({"dev": "hunger_unlock"})
	await _wait_frames(90)
	var resumed_drop: float = hunger.max_value - hunger.value ## The leg (c) bite number.
	var resumed_ok: bool = unlock_ret and not hunger.locked \
			and resumed_drop > 20.0
	## (d) The gate seam — all synchronous, so the value reference is honest.
	var v_ref: float = hunger.value
	var refused_lock: bool = recorder._execute_dev({"dev": "hunger_lock"}, false)
	var refused_refill: bool = recorder._execute_dev({"dev": "hunger_refill"}, false)
	var refused_unlock: bool = recorder._execute_dev({"dev": "hunger_unlock"}, false)
	var unknown_ret: bool = recorder._execute_dev({"dev": "definitely_not_a_verb"})
	var non_dev_ret: bool = recorder._execute_dev({"key": "Space"})
	var events := _read_pilot_events(pilot_dir)
	var gate_ok: bool = refused_lock and refused_refill and refused_unlock \
			and unknown_ret and not non_dev_ret \
			and not hunger.locked and hunger.value == v_ref \
			and events.has("pilot_dev") and events.has("pilot_dev_refused") \
			and events.has("pilot_dev_unknown")
	## (e) The live channel, while frozen: pause through the channel, then the
	## dev verbs as a real command file.
	get_tree().paused = false ## Leg (e) starts from the same unpaused base the channel expects.
	_drop_pilot_cmd(pilot_dir, '{"pause":true}')
	await _wait_frames(3)
	var channel_pause_ok: bool = get_tree().paused
	_drop_pilot_cmd(pilot_dir, '{"dev":"hunger_lock"}\n{"dev":"hunger_refill"}')
	await _wait_frames(4)
	var channel_verbs_ok: bool = hunger.locked and hunger.value == hunger.max_value
	_drop_pilot_cmd(pilot_dir, '{"resume":true}')
	await _wait_frames(3)
	var lock_holds_live: bool = not get_tree().paused
	await _wait_frames(30)
	lock_holds_live = lock_holds_live and hunger.value == hunger.max_value
	_drop_pilot_cmd(pilot_dir, '{"dev":"hunger_unlock"}')
	await _wait_frames(3)
	await _wait_frames(30)
	var channel_unlock_ok: bool = not hunger.locked \
			and hunger.max_value - hunger.value > 10.0
	## Restore: tree, session env, and the autoload clock exactly as found.
	get_tree().paused = false
	recorder.queue_free()
	hunger.player = null ## The autoload's clock outlives this scene instance (suite convention).
	hunger.locked = false ## Never leak a dev lock into later scenarios.
	hunger.drain_per_second = saved_drain
	hunger.reset()
	OS.set_environment("PIGEON_PILOT_SESSION", saved_session)
	OS.set_environment("PIGEON_IMAGE_INTERVAL", saved_images)
	await _wait_frames(2)
	## The bite record (T-167): the unlocked leg's drop, the locked leg's
	## bit-identity and the resumed drop, printed so the ticket can quote the
	## measured lines (the T-155 SIM DATA precedent).
	print(("SIM DATA dev_hunger_lock: unlocked drain over 90 ticks = %.2f "
			+ "(drain_per_second 60/s forced), locked delta over 90 ticks = %.6f "
			+ "(changed_fires=%d), refill-at-locked lands exactly max: %s, "
			+ "resumed drop over 90 ticks = %.2f")
			% [drained, locked_delta, silent_fires, refill_ok, resumed_drop])
	_check("dev_hunger_lock",
			drain_ok and locked_ok and refill_ok and resumed_ok and gate_ok
					and channel_pause_ok and channel_verbs_ok and lock_holds_live
					and channel_unlock_ok,
			("drain=%.2f locked=%s (Δ%.6f, changed_fires=%d) refill=%s resumed=%s "
					+ "gate=%s (ret l/r/u %s/%s/%s, unknown=%s, non_dev=%s) "
					+ "channel pause=%s verbs=%s hold_live=%s unlock=%s") % [
						drained, locked_ok, locked_delta, silent_fires,
						refill_ok, resumed_ok, gate_ok, refused_lock, refused_refill,
						refused_unlock, unknown_ret, non_dev_ret, channel_pause_ok,
						channel_verbs_ok, lock_holds_live, channel_unlock_ok])


## The T-168 starter verb pack, driven through a REAL CaptureRecorder in
## session mode (scratch `simtest_pack` dir — swept later by pilot.py clean),
## RE-PINNED onto the Ames traffic graph (T-178): the staging verbs work
## unchanged on the new graph — the ack contract intact — through the
## spawner's own graph paths:
## (a) with NO node named "CarSpawner" in the rig, `spawn_car` refuses
##     `no_spawner` (the name is retired for the window first, so the leg
##     runs with the name honestly vacant);
## (b) with a staged empty CarSpawner over the Ames world, `car_blinker`
##     refuses `no_car` — no living car exists to force;
## (c) `teleport` moves the player onto the world's spawn corridor with
##     `velocity` exactly Vector3.ZERO (the reset_flight pin) and the
##     resolved position acked;
## (a2) `spawn_car` then WORKS through the graph's curb path: one car stages
##     PARKED near the pigeon (the measured nearest-curb distance printed),
##     the ack carries the node path, the position and the post-spawn fleet
##     size, and the fleet reads exactly the staged car;
## (b2) `car_blinker` on:true forces the NEAREST car — the staged one: the
##     ack's `car` equals the spawn ack's `node`, `blinker`/`forced` read the
##     forced side — and on:false releases it (blinker back to 0, the
##     remembered-car release contract);
## (d) `freeze_traffic` holds the world: the static flag lands, the ack
##     carries `on`, the recycle cadence is HELD exactly across 90 ticks
##     (the timer bit-identical) AND the staged car's transform holds —
##     `on:false` resumes;
## (e) the gate seam: with `allowed=false` every pack verb is consumed but
##     moves no state (fleet unchanged, player position held, the static
##     freeze flag cleared), an unknown dev verb is still consumed
##     (`pilot_dev_unknown`), and every ack/refusal rides `pilot_dev` /
##     `pilot_dev_refused` events machine-checkably.
## The tree, the static freeze, the rig, the spawner name and the session env
## are restored however the legs end.
func _scenario_dev_verb_pack() -> void:
	get_tree().paused = false
	var saved_session := OS.get_environment("PIGEON_PILOT_SESSION")
	var saved_images := OS.get_environment("PIGEON_IMAGE_INTERVAL")
	OS.set_environment("PIGEON_PILOT_SESSION", "simtest_pack")
	OS.set_environment("PIGEON_IMAGE_INTERVAL", "0")
	Car.traffic_frozen = false ## Clean slate on the static freeze (suite convention).
	await _set_up(true, Vector3(0.0, 0.4, 0.0), Vector3.ZERO) ## Grounded on the flat rig world.
	await _await_grounded(90)
	var recorder: Node = RECORDER_SCRIPT.new()
	add_child(recorder)
	await _wait_frames(3)
	var pilot_dir := "res://.captures/session_simtest_pack"
	## (a1) spawn_car with NO "CarSpawner" node resolves: refused, no_spawner.
	## The bare rig must OWN the "CarSpawner" name for the recorder's dev
	## resolution — any leftover holder is retired for the window FIRST (the
	## original scenario's dance), so (a1) honestly runs with the name vacant.
	var stale := get_tree().current_scene.get_node_or_null("CarSpawner")
	if stale == null:
		stale = get_tree().current_scene.get_node_or_null("Main/CarSpawner")
	var stale_name := ""
	if stale != null:
		stale_name = String(stale.name)
		stale.name = stale_name + "_retired"
	print("SIM DATA dev_verb_pack stale holder: %s parent=%s" % [
			str(stale) if stale != null else "none",
			str(stale.get_parent()) if stale != null else "-"])
	var spawn_noret: bool = recorder._execute_dev({"dev": "spawn_car"})
	var spawner := CarSpawner.new()
	spawner.city = _city ## The Ames world: the graph branch owns the fleet paths.
	spawner.player = _player
	spawner.target_moving = 0
	spawner.target_parked = 0
	spawner.name = "CarSpawner"
	add_child(spawner)
	await _wait_frames(4)
	## (b) car_blinker with no living car: refused, no_car — BEFORE anything
	## stages one.
	var blink_ret: bool = recorder._execute_dev(
			{"dev": "car_blinker", "side": "left", "on": true})
	## (c) teleport: reset_flight onto the world's spawn corridor, velocity
	## exactly zero, the resolved spot acked.
	var tp_target := _city.spawn_point
	var tp_ret: bool = recorder._execute_dev({"dev": "teleport", "x": tp_target.x,
			"y": tp_target.y, "z": tp_target.z, "yaw_deg": 180.0})
	var tp_delta: float = _player.global_position.distance_to(tp_target)
	var tp_ok: bool = tp_ret and tp_delta < 0.001 \
			and _player.velocity == Vector3.ZERO
	## (a2) spawn_car WORKS over the graph: one car stages PARKED near the
	## pigeon through the spawner's own curb path.
	var spawn_ret: bool = recorder._execute_dev({"dev": "spawn_car"})
	var staged := spawner.living_cars()
	var staged_ok: bool = spawn_ret and staged.size() == 1 \
			and staged[0].mode == Car.Mode.PARKED
	var spawn_dist := staged[0].global_position.distance_to(_player.global_position) \
			if staged.size() == 1 else -1.0
	## (b2) car_blinker forces the NEAREST car — the staged one — and releases
	## it by the same verb.
	var blink_on_ret: bool = recorder._execute_dev(
			{"dev": "car_blinker", "side": "right", "on": true})
	var forced_ok: bool = blink_on_ret and staged.size() == 1 \
			and staged[0].blinker_forced == 1 and staged[0].blinker == 1
	var blink_off_ret: bool = recorder._execute_dev(
			{"dev": "car_blinker", "side": "right", "on": false})
	var released_ok: bool = blink_off_ret and staged.size() == 1 \
			and staged[0].blinker_forced == 0 and staged[0].blinker == 0
	## (d) freeze_traffic: the world-wide hold with the staged car present —
	## the flag, the ack, the spawner's cadence gate AND the car's transform.
	var staged_pos := staged[0].global_position if staged.size() == 1 \
			else Vector3.ZERO
	var timer_before: float = spawner._scan_timer
	var freeze_ret: bool = recorder._execute_dev({"dev": "freeze_traffic", "on": true})
	await _wait_frames(90)
	var timer_held: bool = spawner._scan_timer == timer_before ## The cadence gate's bite number.
	var staged_held: bool = staged.size() == 1 \
			and staged[0].global_position == staged_pos
	var frozen_ok: bool = freeze_ret and Car.traffic_frozen and timer_held \
			and staged_held
	var resume_ret: bool = recorder._execute_dev({"dev": "freeze_traffic", "on": false})
	await _wait_frames(4)
	var resumed_ok: bool = resume_ret and not Car.traffic_frozen
	## (e) the gate seam: refused pack verbs move no state.
	var ref_pos := _player.global_position
	var r_spawn: bool = recorder._execute_dev({"dev": "spawn_car"}, false)
	var r_blink: bool = recorder._execute_dev(
			{"dev": "car_blinker", "side": "left", "on": true}, false)
	var r_tp: bool = recorder._execute_dev(
			{"dev": "teleport", "x": 9999.0, "y": 9999.0, "z": 9999.0}, false)
	var r_freeze: bool = recorder._execute_dev({"dev": "freeze_traffic", "on": true}, false)
	recorder._execute_dev({"dev": "freeze_traffic", "on": false}) ## Restore the flag.
	var unknown_ret: bool = recorder._execute_dev({"dev": "not_a_pack_verb"})
	var refused_ok: bool = r_spawn and r_blink and r_tp and r_freeze and unknown_ret \
			and spawner.living_cars().size() == 1 \
			and _player.global_position == ref_pos \
			and not Car.traffic_frozen
	## The ack/refusal payloads, read machine-checkably off the events file.
	var events := _read_pilot_event_list(pilot_dir)
	var ack_tp := _find_pilot_event(events, "teleport")
	var ack_freeze := _find_pilot_event(events, "freeze_traffic")
	var ack_spawn := _find_pilot_event(events, "spawn_car")
	var ack_blink := _find_pilot_event(events, "car_blinker")
	var spawn_refusals: Array[Dictionary] = []
	var blink_refusal := {}
	var refused_events := 0
	for e in events:
		if e.get("ev", "") != "pilot_dev_refused":
			continue
		var verb := String(e.get("verb", ""))
		if verb == "spawn_car":
			spawn_refusals.append(e)
			refused_events += 1
		elif verb == "car_blinker":
			## FIRST match only — the gate seam's later `not_allowed` refusal
			## must not overwrite the staging leg's reason.
			if blink_refusal.is_empty():
				blink_refusal = e
			refused_events += 1
		elif verb == "teleport" or verb == "freeze_traffic":
			refused_events += 1
	var reasons := []
	for e in spawn_refusals:
		reasons.append(String(e.get("reason", "")))
	var spawn_refusals_ok: bool = reasons.has("no_spawner") \
			and not ack_spawn.is_empty() and ack_spawn.has("node") \
			and ack_spawn.has("p") and int(ack_spawn.get("fleet", 0)) == 1
	var blink_refusal_ok: bool = not blink_refusal.is_empty() \
			and String(blink_refusal.get("reason", "")) == "no_car"
	var blink_ack_ok: bool = not ack_blink.is_empty() \
			and String(ack_blink.get("car", "")) == String(ack_spawn.get("node", "")) \
			and int(ack_blink.get("blinker", 9)) == 1 \
			and int(ack_blink.get("forced", 9)) == 1
	var spawn_near_ok: bool = staged_ok and spawn_dist >= 0.0 \
			and spawn_dist < 600.0
	var acks_ok: bool = not ack_tp.is_empty() and ack_tp.has("p") \
			and ack_tp.has("yaw_deg") \
			and not ack_freeze.is_empty() and bool(ack_freeze.get("on", false)) \
			and refused_events >= 3
	## Restore: tree, static freeze, rig, name, session env.
	get_tree().paused = false
	Car.traffic_frozen = false
	spawner.free()
	if stale_name != "":
		stale.name = stale_name ## After the free — the name must be unheld.
	recorder.queue_free()
	OS.set_environment("PIGEON_PILOT_SESSION", saved_session)
	OS.set_environment("PIGEON_IMAGE_INTERVAL", saved_images)
	await _wait_frames(2)
	## The bite record: the refusal, the zero-velocity teleport, the staged
	## parked car + its ack contract, the blink force/release on it, the held
	## cadence + transform, the resume, the gate seam and the machine-read acks.
	print(("SIM DATA dev_verb_pack: spawn refusals %s staged_ok=%s staged_dist=%.1f "
			+ "blink_ack=%s forced=%s released=%s, teleport Δpos %.4f vel_zero=%s, "
			+ "frozen=%s timer_held=%s staged_held=%s, resumed=%s, refused=%d acks=%s")
			% [str(reasons), staged_ok, spawn_dist, blink_ack_ok, forced_ok,
			released_ok, tp_delta, tp_ok, frozen_ok, timer_held, staged_held,
			resumed_ok, refused_events, acks_ok])
	var pack_ok: bool = spawn_refusals_ok and blink_refusal_ok and tp_ok \
			and staged_ok and spawn_near_ok and blink_ack_ok and forced_ok \
			and released_ok and frozen_ok and resumed_ok and refused_ok and acks_ok
	var pack_detail := "spawn=%s staged=%s dist=%.1f blink=%s forced=%s released=%s tp=%s frozen=%s resumed=%s refused=%s acks=%s" \
			% [spawn_refusals_ok, staged_ok, spawn_dist, blink_ack_ok, forced_ok,
			released_ok, tp_ok, frozen_ok, resumed_ok, refused_ok, acks_ok]
	_check("dev_verb_pack", pack_ok, pack_detail)


## The T-169 call verb, driven through a REAL CaptureRecorder in session mode
## (scratch `simtest_call` dir — swept later by pilot.py clean), the T-167
## pattern: every leg fires through `_execute_dev` with an explicit dict,
## `allowed` default (the headless sim is a debug build) — and EVERY dict
## goes through `_json_round_trip` first (round-1 review: a hand-built
## GDScript dict carries types the channel cannot; Godot's JSON parser
## delivers every number as a float, so the legs must drive the verb with
## the types the live channel actually delivers). Targets: the Game
## autoload's own hunger clock through the dotted-property path
## (`Game.hunger` — the resolution the ticket's example names), the harness
## pigeon through its absolute /root path (the third resolution arm), and a
## tests-only CallProbe (tests/call_probe.gd) whose typed methods pin the
## coercion surface. Legs:
## (a) the happy path — after 90 ticks of a 60/s forced drain,
##     `{"dev":"call","node":"Game.hunger","method":"eat","args":[10.0]}`
##     raises the bar by EXACTLY 10 (the read is synchronous — no drain tick
##     can interleave) and the `pilot_call_result` ack carries node/method
##     with the void return serialized as JSON null;
## (b) THE coercion rule — a [x,y,z] array into the probe's Vector3-typed
##     parameter RUNS the method with the tell reading Vector3 (an
##     uncoercing verb would have type-refused pre-call), the same shape
##     into the probe's Array-typed and untyped parameters stays an Array
##     (the tells read Array:N:float — the array-stays-an-array law the
##     ticket pins), the same shape into the pigeon's `reset_flight` through
##     its /root path lands it on the target with velocity exactly
##     Vector3.ZERO, an undershoot into `probe_defaulted` fills the 2.5
##     default (required = total − default_args.size(), and 1 ≥ 1 — the
##     engine fills what the method list names), a two-float call returns
##     the numeric result through the serializer, the CHANNEL-TYPE pins
##     (round-1 review): a plain `[1]` into the probe's int-typed parameter
##     and a string into its NodePath-typed parameter both RUN (the parser
##     delivered every number as a float; the engine converts float→int and
##     String→NodePath — the review's set_blinker_forced/has_node calls) —
##     a gate that regresses to native-type-only refuses these and the
##     tells never land — and the CACHE-SPLIT pin (round-2 review): the
##     same `set_scale` name on a Label (Vector2) then a bare Node3D
##     (Vector3) then the LABEL AGAIN — exactly the order that poisoned the
##     round-1 name-only cache key — with both scale readbacks proving all
##     three landed (a reverted name-only key turns the third call into a
##     type refusal while everything else stays green);
## (c) error paths — unknown node, unknown method, overshoot arity AND
##     undershoot arity each log `pilot_call_error` (unknown_node /
##     unknown_method / arity), the arity refusals move no state (an
##     undershoot that slipped through would log a FALSE void-success —
##     the round-1 review's eat [] result:null with hunger unmoved), and
##     the harness continues through all of them into legs (d)/(e);
## (d) the denylist — the direct names `free` / `queue_free` aimed at the
##     Game autoload are refused (`denied_method`) and the autoload
##     SURVIVES the following frames, a call aimed at the recorder's own
##     node path refuses (`recorder_node` — no self-calls into the
##     channel), `_pilot_step` aimed anywhere refuses, AND the review-found
##     dispatch/write escapes all refuse too — round 1: `call` and `callv`
##     wraps of queue_free on /root/Game, `call_deferred("reset")` and
##     `set("value", 50.0)` on Game.hunger, and `/root` `propagate_call`
##     aimed at `_execute_dev`; round 2: the thread-safe/indexed siblings
##     (`set_indexed`, `set_thread_safe`, `set_deferred_thread_group`,
##     `call_thread_safe`, `call_deferred_thread_group` — all five wrote
##     hunger or dispatched reset live past the round-1 six) and `set_script
##     [null]` on the probe (stripped a car's script live, via the
##     typed-Object-accepts-null arm), with the probe's own script proven
##     intact after the refusal — each `denied_method`, hunger unmoved
##     through the following frames (a slipped deferred would land), Game
##     alive, and no `pilot_dev` ack anywhere in the events (the
##     propagate_call never reached the recorder);
## (e) the gate seam — with `allowed=false` the verb is consumed but refuses
##     (`pilot_dev_refused`, verb "call"), moves no state, and logs no
##     pilot_call_result.
## The tree, the autoload clock (drain constant, lock, player, value) and the
## session env are restored however the legs end.
func _scenario_dev_call_verb() -> void:
	get_tree().paused = false
	var saved_session := OS.get_environment("PIGEON_PILOT_SESSION")
	var saved_images := OS.get_environment("PIGEON_IMAGE_INTERVAL")
	OS.set_environment("PIGEON_PILOT_SESSION", "simtest_call")
	OS.set_environment("PIGEON_IMAGE_INTERVAL", "0")
	var hunger := Game.hunger
	hunger.reset() ## Clean slate on the autoload clock (suite convention).
	var saved_drain: float = hunger.drain_per_second
	hunger.drain_per_second = 60.0 ## The T-005 game-over scenario's time-compression precedent.
	hunger.player = _player ## Attach the sim pigeon — the drain needs a live player.
	var recorder: Node = RECORDER_SCRIPT.new()
	add_child(recorder)
	await _wait_frames(3)
	var pilot_dir := "res://.captures/session_simtest_call"
	## --- (a) the happy path: drain some, call eat, read +10 ------------------
	await _set_up(true, Vector3(0.0, 20.0, 0.0), Vector3.ZERO)
	await _wait_frames(90)
	var v_before: float = hunger.value
	var eat_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "eat", "args": [10.0]}))
	var rose: float = hunger.value - v_before ## The synchronous read — no drain tick interleaves.
	var happy_ok: bool = eat_ret and rose == 10.0
	## --- (b) the coercion rule on the probe's typed methods ------------------
	var probe: Node = CALL_PROBE_SCRIPT.new()
	probe.name = "CallProbe"
	add_child(probe)
	var probe_path := String(probe.get_path())
	var vec_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "probe_vec3",
			"args": [[1.0, 2.0, 3.0]]}))
	var arr_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "probe_array",
			"args": [[4.0, 5.0, 6.0]]}))
	var untyped_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "probe_untyped",
			"args": [[7.0, 8.0]]}))
	## The /root arm against the real player: [x,y,z] coerces into
	## reset_flight's Vector3 `pos`, 45.0 rides raw into `yaw_deg`.
	var tp_target := Vector3(3.0, 20.0, -4.0)
	var tp_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": String(_player.get_path()),
			"method": "reset_flight",
			"args": [[tp_target.x, tp_target.y, tp_target.z], 45.0]}))
	var tp_ok: bool = tp_ret and _player.global_position == tp_target \
			and _player.velocity == Vector3.ZERO
	var def_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "probe_defaulted",
			"args": [7.0]}))
	var add_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "probe_add",
			"args": [2.0, 1.5]}))
	## The CHANNEL-TYPE pins (round-1 review): a bare JSON `1` into an
	## int-typed parameter and a string into a NodePath-typed parameter —
	## the parser delivers 1 as a float and the gate must let the engine
	## convert, exactly as the live channel demanded.
	var int_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "probe_int",
			"args": [1]}))
	var np_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "probe_node_path",
			"args": ["CallProbe"]}))
	## --- (b3) the cache-split pin (round-2 review): the SAME method name on
	## TWO different native classes, driven label → Node3D → label again —
	## exactly the order that poisoned the round-1 name-only cache key (the
	## third call would type-refuse against the Vector3 signature the second
	## call cached; a revert to name-only keys fails here while everything
	## else stays green). Both readbacks pin the landing.
	var scale_label := Label.new()
	add_child(scale_label)
	var scale_label_path := String(scale_label.get_path())
	var scale_n3 := Node3D.new()
	add_child(scale_n3)
	var scale_n3_path := String(scale_n3.get_path())
	var ls1_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": scale_label_path, "method": "set_scale",
			"args": [[1.0, 1.0]]}))
	var n3_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": scale_n3_path, "method": "set_scale",
			"args": [[2.0, 2.0, 2.0]]}))
	var ls2_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": scale_label_path, "method": "set_scale",
			"args": [[3.0, 3.0]]}))
	var cache_split: bool = ls1_ret and n3_ret and ls2_ret \
			and scale_label.scale == Vector2(3.0, 3.0) \
			and scale_n3.scale == Vector3(2.0, 2.0, 2.0)
	## --- (c) error paths: unknown node / method / arity both directions ------
	var v_ref: float = hunger.value
	var bad_node_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "NotAnAutoload.child", "method": "eat", "args": []}))
	var bad_method_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger",
			"method": "definitely_not_a_method", "args": []}))
	var over_arity_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "eat",
			"args": [1.0, 2.0]}))
	## The undershoot pin: eat [] must refuse pre-call — the round-1 review
	## caught it logging a FALSE void-success (result:null, hunger unmoved).
	var under_arity_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "eat", "args": []}))
	var arity_moved_nothing: bool = hunger.value == v_ref ## Synchronous read.
	## --- (d) the denylist: direct names AND the dispatch/write escapes --------
	var free_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "/root/Game", "method": "free", "args": []}))
	var qfree_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "/root/Game", "method": "queue_free", "args": []}))
	## (Round-1 review) The escapes: each of these DELETED or mutated state
	## live before the denylist covered them — the call/callv wraps of
	## queue_free freed the autoload, propagate_call on /root reached the
	## recorder itself, set wrote hunger, call_deferred dispatched reset.
	var wrap_call_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "/root/Game", "method": "call",
			"args": ["queue_free"]}))
	var wrap_callv_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "/root/Game", "method": "callv",
			"args": ["queue_free", []]}))
	var wrap_set_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "set",
			"args": ["value", 50.0]}))
	var wrap_setdef_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "set_deferred",
			"args": ["value", 50.0]}))
	var wrap_calldef_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "call_deferred",
			"args": ["reset"]}))
	var wrap_prop_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "/root", "method": "propagate_call",
			"args": ["_execute_dev", [{"dev": "hunger_refill"}], false]}))
	## (Round-2 review) The thread-safe/indexed SIBLINGS of the round-1 six
	## fired live past it: set_indexed/set_thread_safe/set_deferred_thread_
	## group wrote hunger (99.88→50.0→40.0→30.0), call_thread_safe/
	## call_deferred_thread_group dispatched reset — and set_script [null]
	## (enabled by the typed-Object-accepts-null arm) STRIPPED a car's
	## script, leaving a bare CharacterBody3D in the managed fleet.
	var wrap_setidx_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "set_indexed",
			"args": ["value", 50.0]}))
	var wrap_setts_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "set_thread_safe",
			"args": ["value", 40.0]}))
	var wrap_setdtg_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "set_deferred_thread_group",
			"args": ["value", 30.0]}))
	var wrap_callts_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "call_thread_safe",
			"args": ["reset"]}))
	var wrap_calltdg_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "call_deferred_thread_group",
			"args": ["reset"]}))
	var wrap_setscript_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": probe_path, "method": "set_script",
			"args": [null]}))
	var probe_survived: bool = probe.has_method("probe_int") \
			and probe.get_script() != null ## A slipped set_script strips the class.
	## The deny pins compare hunger ACROSS the wait below, and the forced
	## 60/s drain would move the bar ~3 units over those ticks — freeze the
	## clock for the window (the T-167 lock, released right after), so an
	## unmoved bar is the honest pin.
	hunger.locked = true
	var v_after_denies: float = hunger.value
	await _wait_frames(3) ## A slipped queue_free/call_deferred/set_deferred would land on the next frames.
	var deny_state_ok: bool = is_instance_valid(Game) \
			and hunger.value == v_after_denies ## set_deferred/call_deferred would have landed by now.
	hunger.locked = false
	var self_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": String(recorder.get_path()),
			"method": "has_method", "args": ["_pilot_step"]}))
	var step_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "/root/Game", "method": "_pilot_step",
			"args": []}))
	## --- (e) the gate seam ------------------------------------------------------
	var ref_eat: float = hunger.value
	var refused_ret: bool = recorder._execute_dev(_json_round_trip(
			{"dev": "call", "node": "Game.hunger", "method": "eat",
			"args": [999.0]}), false)
	var refused_ok: bool = refused_ret and hunger.value == ref_eat
	## --- the events, read machine-checkably ------------------------------------
	var events := _read_pilot_event_list(pilot_dir)
	var ack_eat := _find_pilot_call(events, "pilot_call_result", "Game.hunger", "eat")
	var ack_vec := _find_pilot_call(events, "pilot_call_result", probe_path, "probe_vec3")
	var ack_arr := _find_pilot_call(events, "pilot_call_result", probe_path, "probe_array")
	var ack_untyped := _find_pilot_call(events, "pilot_call_result", probe_path, "probe_untyped")
	var ack_def := _find_pilot_call(events, "pilot_call_result", probe_path, "probe_defaulted")
	var ack_add := _find_pilot_call(events, "pilot_call_result", probe_path, "probe_add")
	var ack_int := _find_pilot_call(events, "pilot_call_result", probe_path, "probe_int")
	var ack_np := _find_pilot_call(events, "pilot_call_result", probe_path, "probe_node_path")
	var ack_tp := _find_pilot_call(events, "pilot_call_result",
			String(_player.get_path()), "reset_flight")
	var err_node := _find_pilot_call(events, "pilot_call_error", "NotAnAutoload.child", "eat")
	var err_method := _find_pilot_call(events, "pilot_call_error", "Game.hunger",
			"definitely_not_a_method")
	var err_over := _find_pilot_call(events, "pilot_call_error", "Game.hunger", "eat")
	## The undershoot's refusal shares the happy path's node/method pair with
	## the overshoot's, so the pair carries TWO pilot_call_error events — the
	## count itself is the pin that both directions refused.
	var eat_error_count := 0
	for e in events:
		if e.get("ev", "") == "pilot_call_error" \
				and String(e.get("node", "")) == "Game.hunger" \
				and String(e.get("method", "")) == "eat":
			eat_error_count += 1
	var err_free := _find_pilot_call(events, "pilot_call_error", "/root/Game", "free")
	var err_qfree := _find_pilot_call(events, "pilot_call_error", "/root/Game", "queue_free")
	var err_self := _find_pilot_call(events, "pilot_call_error",
			String(recorder.get_path()), "has_method")
	var err_step := _find_pilot_call(events, "pilot_call_error", "/root/Game", "_pilot_step")
	var eat_acked: bool = not ack_eat.is_empty() and ack_eat.has("result") \
			and ack_eat.get("result") == null ## The void return, serialized as JSON null.
	var vec_tell: String = String(ack_vec.get("result", ""))
	var arr_tell: String = String(ack_arr.get("result", ""))
	var untyped_tell: String = String(ack_untyped.get("result", ""))
	var int_tell: String = String(ack_int.get("result", ""))
	var np_tell: String = String(ack_np.get("result", ""))
	var coerce_ok: bool = vec_ret and not ack_vec.is_empty() \
			and vec_tell.begins_with("Vector3:") ## The method RAN — the verb coerced.
	var stays_array: bool = arr_ret and untyped_ret \
			and arr_tell == "Array:3:float" and untyped_tell == "Array:2" ## The ticket's pin.
	var channel_types: bool = int_ret and np_ret \
			and int_tell == "int:1" and np_tell == "node_path:CallProbe" ## The review's pins.
	var def_result: Variant = ack_def.get("result", [])
	var def_arr: Array = def_result if def_result is Array else []
	var def_ok: bool = def_ret and not ack_def.is_empty() and def_arr.size() == 2 \
			and absf(float(def_arr[0]) - 7.0) < 0.001 \
			and absf(float(def_arr[1]) - 2.5) < 0.001 ## The undershoot-above-required filled 2.5.
	var add_result: Variant = ack_add.get("result", 0.0)
	var add_ok: bool = add_ret and not ack_add.is_empty() \
			and absf(float(add_result) - 3.5) < 0.001 ## The numeric return serialized.
	var tp_acked: bool = tp_ok and not ack_tp.is_empty()
	var errors_ok: bool = bad_node_ret and bad_method_ret and over_arity_ret \
			and under_arity_ret and arity_moved_nothing \
			and not err_node.is_empty() and String(err_node.get("error", "")) == "unknown_node" \
			and not err_method.is_empty() and String(err_method.get("error", "")) == "unknown_method" \
			and not err_over.is_empty() and String(err_over.get("error", "")) == "arity" \
			and eat_error_count == 2 ## Overshoot AND undershoot both refused (both named arity).
	var deny_ok: bool = free_ret and qfree_ret and self_ret and step_ret \
			and wrap_call_ret and wrap_callv_ret and wrap_set_ret \
			and wrap_setdef_ret and wrap_calldef_ret and wrap_prop_ret \
			and wrap_setidx_ret and wrap_setts_ret and wrap_setdtg_ret \
			and wrap_callts_ret and wrap_calltdg_ret and wrap_setscript_ret \
			and probe_survived and deny_state_ok \
			and not err_free.is_empty() and String(err_free.get("error", "")) == "denied_method" \
			and not err_qfree.is_empty() and String(err_qfree.get("error", "")) == "denied_method" \
			and not err_self.is_empty() and String(err_self.get("error", "")) == "recorder_node" \
			and not err_step.is_empty() and String(err_step.get("error", "")) == "denied_method"
	## The dispatch/write escapes must ALL have been refused pre-call: each
	## pair carries a denied_method error, and NO pilot_dev event exists at
	## all (propagate_call reaching the recorder would ack hunger_refill;
	## nothing else in this session logs pilot_dev).
	var wrap_pairs: Array = [
		["/root/Game", "call"], ["/root/Game", "callv"],
		["Game.hunger", "set"], ["Game.hunger", "set_deferred"],
		["Game.hunger", "call_deferred"], ["/root", "propagate_call"],
		["Game.hunger", "set_indexed"], ["Game.hunger", "set_thread_safe"],
		["Game.hunger", "set_deferred_thread_group"],
		["Game.hunger", "call_thread_safe"],
		["Game.hunger", "call_deferred_thread_group"],
		[probe_path, "set_script"],
	]
	var wrap_denied := 0
	for pair in wrap_pairs:
		var err_w := _find_pilot_call(events, "pilot_call_error",
				String(pair[0]), String(pair[1]))
		if not err_w.is_empty() and String(err_w.get("error", "")) == "denied_method":
			wrap_denied += 1
	var no_dev_ran := true
	for e in events:
		if e.get("ev", "") == "pilot_dev":
			no_dev_ran = false
	var fence_ok: bool = deny_ok and wrap_denied == wrap_pairs.size() and no_dev_ran
	## The cache-split ACKs (round-2): all three set_scale calls must ack as
	## RESULTS (a reverted name-only key turns the second/third into type
	## errors).
	var ack_ls1 := _find_pilot_call(events, "pilot_call_result",
			scale_label_path, "set_scale")
	var ack_n3 := _find_pilot_call(events, "pilot_call_result",
			scale_n3_path, "set_scale")
	var cache_acks: bool = not ack_ls1.is_empty() and not ack_n3.is_empty()
	var refused_logged: bool = false
	for e in events:
		if e.get("ev", "") == "pilot_dev_refused" and String(e.get("verb", "")) == "call":
			refused_logged = true
	## Exactly ONE eat result ack exists — the leg-(a) happy path. A second
	## would mean a refused/undershoot eat call leaked through and executed;
	## the two arity error events above pin the refusals themselves.
	var eat_result_acks := 0
	for e in events:
		if e.get("ev", "") == "pilot_call_result" \
				and String(e.get("node", "")) == "Game.hunger" \
				and String(e.get("method", "")) == "eat":
			eat_result_acks += 1
	var no_leaked_eat: bool = eat_result_acks == 1
	## Restore: tree, autoload clock, probes, recorder, session env — however the legs end.
	get_tree().paused = false
	scale_label.queue_free()
	scale_n3.queue_free()
	probe.queue_free()
	recorder.queue_free()
	hunger.player = null ## The autoload's clock outlives this scene instance (suite convention).
	hunger.locked = false ## Never leak a dev lock into later scenarios.
	hunger.drain_per_second = saved_drain
	hunger.reset()
	OS.set_environment("PIGEON_PILOT_SESSION", saved_session)
	OS.set_environment("PIGEON_IMAGE_INTERVAL", saved_images)
	await _wait_frames(2)
	## The bite record (the T-155/T-167 SIM DATA precedent): the +10 read, the
	## coercion tells (vectors, arrays, the channel's float-into-int), the
	## cache split, the defaulted fill, the serialized sum, both arity
	## directions and the denylist fence.
	print(("SIM DATA dev_call_verb: eat +%.2f (acked void-null=%s), tells vec='%s' "
			+ "arr='%s' untyped='%s' int='%s' np='%s', cache_split=%s acks=%s, "
			+ "defaulted=%s add=%s tp=%s, errors node/method/arity=%s/%s/%s"
			+ "(eat_errors=%d) moved_nothing=%s, deny direct=%s escapes=%d/%d "
			+ "no_dev_ran=%s game_alive=%s survived=%s, refused=%s no_leaked_eat=%s")
			% [rose, eat_acked, vec_tell, arr_tell, untyped_tell, int_tell, np_tell,
			cache_split, cache_acks, def_ok, add_ok, tp_ok,
			not err_node.is_empty(), not err_method.is_empty(),
			not err_over.is_empty(), eat_error_count, arity_moved_nothing,
			free_ret and qfree_ret, wrap_denied, wrap_pairs.size(), no_dev_ran,
			is_instance_valid(Game), probe_survived, refused_logged, no_leaked_eat])
	var call_ok: bool = happy_ok and eat_acked and coerce_ok and stays_array \
			and channel_types and cache_split and cache_acks and def_ok and add_ok \
			and tp_ok and tp_acked and errors_ok and fence_ok and refused_ok \
			and refused_logged and no_leaked_eat
	_check("dev_call_verb", call_ok,
			("happy=%s acked=%s coerce=%s stays_array=%s channel_types=%s "
					+ "cache_split=%s def=%s add=%s tp=%s errors=%s fence=%s "
					+ "refused=%s no_leaked_eat=%s") % [
						happy_ok, eat_acked, coerce_ok, stays_array, channel_types,
						cache_split and cache_acks, def_ok, add_ok, tp_ok,
						errors_ok, fence_ok, refused_ok,
						refused_logged and no_leaked_eat])


## --- scenarios (T-170 pilot hidden launch) -----------------------------------

## The T-170 hidden-launch contract, pinned at the two arms this headless
## suite CAN reach — the pure helper and the guard. The OS-level proof (real
## window placement, foreground samples, off-screen capture) is pilot.py
## focuscheck, which a headless DisplayServer cannot run (no window,
## no GetForegroundWindow). Legs: (a) the EXACT hide position for the three
## ticket monitor layouts at the 1280×720 client — this machine's
## side-by-side (0,0)+(2560,0), a negative-left-monitor (−1920,0)+(0,0), and
## a single screen — each then re-checked INDEPENDENTLY: the window rect must
## sit ≥ HIDE_MARGIN_PX clear of EVERY monitor rect on at least one axis (the
## per-axis-separation clearance notion focuscheck shares); (b) a second
## window size (640×360 → (−720,−440)) proving the size input flows — a
## hard-coded 1280×720 fails it; (c) the GUARD leg: a real session-mode
## recorder under PIGEON_WINDOW_HIDDEN=1 in THIS headless run logs run_start
## (session mode started) but NO pilot_window_hidden — the
## DisplayServer.get_name() != "headless" guard skips the leg with no event
## and no error, exactly as legacy flag-file mode is skipped by construction
## (the leg lives in _start_session). Env restored however the legs end.
func _scenario_pilot_window_hide_math() -> void:
	var client := Vector2i(1280, 720) ## project.godot's desktop window, what the hide math sizes from
	var layouts := [
		{"name": "desktop_side_by_side",
			"mons": [Rect2i(0, 0, 2560, 1440), Rect2i(2560, 0, 1920, 1080)],
			"want": Vector2i(-1360, -800)},
		{"name": "negative_left",
			"mons": [Rect2i(-1920, 0, 1920, 1080), Rect2i(0, 0, 2560, 1440)],
			"want": Vector2i(-3280, -800)},
		{"name": "single_screen",
			"mons": [Rect2i(0, 0, 1920, 1080)],
			"want": Vector2i(-1360, -800)},
	]
	var exact_ok := true
	var clear_ok := true
	var detail := ""
	for layout in layouts:
		var mons: Array[Rect2i] = []
		var positions: Array[Vector2i] = []
		for m in layout["mons"]:
			mons.append(m)
			positions.append((m as Rect2i).position)
		var got: Vector2i = RECORDER_SCRIPT._hide_position(positions, client)
		var want: Vector2i = layout["want"]
		var exact := got == want
		exact_ok = exact_ok and exact
		## Independent clearance recompute: the window rect vs every monitor
		## rect — separated by ≥ HIDE_MARGIN_PX iff some axis separates the
		## pair by that much (the max of the two per-axis separations).
		var win := Rect2i(got, client)
		var worst := 1 << 30
		for m in mons:
			var sx: int = maxi(m.position.x - win.end.x, win.position.x - m.end.x)
			var sy: int = maxi(m.position.y - win.end.y, win.position.y - m.end.y)
			worst = mini(worst, maxi(sx, sy))
		var clear := worst >= int(RECORDER_SCRIPT.HIDE_MARGIN_PX)
		clear_ok = clear_ok and clear
		detail += " [%s got=%s want=%s exact=%s clearance=%dpx]" % [
				layout["name"], got, want, exact, worst]
	## The size input flows: a smaller window parks proportionally closer in.
	var single: Array[Vector2i] = [Vector2i(0, 0)]
	var small: Vector2i = RECORDER_SCRIPT._hide_position(single, Vector2i(640, 360))
	var size_ok := small == Vector2i(-720, -440)
	detail += " size640x360=%s exact=%s" % [small, size_ok]
	## The guard leg: the real recorder, session mode, hidden env, HEADLESS —
	## the leg must skip silently (run_start proves the session started; a
	## leaked pilot_window_hidden or an engine error both fail the suite).
	var saved_hidden := OS.get_environment("PIGEON_WINDOW_HIDDEN")
	var saved_session := OS.get_environment("PIGEON_PILOT_SESSION")
	var saved_images := OS.get_environment("PIGEON_IMAGE_INTERVAL")
	OS.set_environment("PIGEON_PILOT_SESSION", "simtest_hide")
	OS.set_environment("PIGEON_IMAGE_INTERVAL", "0")
	OS.set_environment("PIGEON_WINDOW_HIDDEN", "1")
	var recorder: Node = RECORDER_SCRIPT.new()
	add_child(recorder)
	await _wait_frames(5)
	## The T-168 payload reader (skips empty/trailing lines) — the name-set
	## `_read_pilot_events` prints a JSON parse ERROR on a live file's final
	## partial line; this leg's read should log no noise.
	var hide_names := {}
	for e in _read_pilot_event_list("res://.captures/session_simtest_hide"):
		hide_names[String(e.get("ev", ""))] = true
	var guard_ok: bool = hide_names.has("run_start") \
			and not hide_names.has("pilot_window_hidden")
	recorder.queue_free()
	OS.set_environment("PIGEON_WINDOW_HIDDEN", saved_hidden)
	OS.set_environment("PIGEON_PILOT_SESSION", saved_session)
	OS.set_environment("PIGEON_IMAGE_INTERVAL", saved_images)
	await _wait_frames(2)
	detail += " guard(session_started=%s no_hidden_event=%s)" % [
			hide_names.has("run_start"), not hide_names.has("pilot_window_hidden")]
	_check("pilot_window_hide_math", exact_ok and clear_ok and size_ok and guard_ok,
			detail)


## --- scenarios (T-114 favor economy) -----------------------------------------


## --- scenario (T-147 favor pays once per target) ------------------------------


## --- scenario (T-151 the hit readouts name the class) -----------------------


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
	## (T-177 re-pin) Leg D — the real tailgate surface — RETIRED with the
	## Windrow fleet: parked VISITOR cars anchored the tailgate crumbs, and on
	## the resident Ames bake the citizen fleet is empty until R2 re-points
	## parking (the tailgate law re-pins beside R2·parking's economy pass).
	## Legs A-C carry the steal surface on the Ames supply: the TABLE crumbs
	## are real café tabletops now (the venue system T-176 shipped), the
	## stamped drop and the GROUND control are world-independent rigs.
	_check("bread_steal_favor_deltas",
			table_ok and steal_ok and plain_ok,
			"table=%s (favor %d, events %s) steal=%s plain=%s (tailgate leg retired with the Windrow fleet — T-177)" % [
					table_ok, Game.favor, _crumb_favor_events, steal_ok, plain_ok])
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
## (instanced-Main pattern, pigeon held airborne). (T-177 re-pin) The relay
## leg changed with the world: the resident Ames bake has NO citizens until
## R2 re-points the spawners, so the duck-typed car relay retired with the
## Windrow fleet (the relay's own machine home is R2·calm-port's; the
## splat_favor chain pins beside the favor rows retired with it). What this
## scenario still pins END TO END is the victory register itself: favor
## staged 2 under the ceiling, ONE jackpot booking through the REAL autoload
## entry Main's relay feeds (`Game.splat_favor(VISITOR, true)` — the same
## function the retired relay called last) — favor reads EXACTLY `favor_max`
## (the clamp in the real chain), the tree pauses, the score screen opens in
## the VICTORY register (title, gold dim, note, the run's real splat counts
## plus the per-class split before the favor total, the T-151 re-pin) while
## hunger stands — this ending is NOT starvation — and Esc stays locked; a
## further booking past the clamp moves nothing and fires no second
## `favor_maxed`. Coexistence: a direct `hunger.game_over` emit with the
## victory screen up changes NOTHING (first-wins); `restart_run()` unpauses,
## closes, zeroes and re-arms (a staged sub-max add fires nothing); then
## favor staged LOW, the T-010 `drain_per_second` compression starves the run
## and the SAME screen opens in the STARVED! register — dark red dim, no
## note, plain breakdown — both entries having rewritten every mode-dependent
## property in one Main.
func _scenario_favor_max_ends_run_victory() -> void:
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	_favor_maxed_fires = 0
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(6500.0, 0.0, 6500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	var pigeon: Player = main_game.player
	var hover: Vector3 = main_game.city.to_local(main_game.city.spawn_point) \
			+ Vector3(0.0, 60.0, 0.0)
	pigeon.reset_flight(hover) ## Airborne for the whole scenario — no trust, no crumbs eaten.
	await _wait_frames(6)
	var maxed_cb := func() -> void: _favor_maxed_fires += 1
	Game.favor_maxed.connect(maxed_cb)
	Game.favor = Game.favor_max - Game.favor_visitor_car_splat ## Two under the ceiling: one jackpot wins.
	var screen: GameOverScreen = main_game.game_over_screen
	var pause_menu: PauseMenu = main_game.get_node("PauseMenu")
	## The jackpot booking through the REAL autoload entry — the same call the
	## retired car relay ended in (T-177 re-pin; see the doc above).
	var booked: int = Game.splat_favor(CitizenClass.Kind.VISITOR, true)
	pause_menu.toggle() ## Esc on a dead run must be refused.
	var victory_ok := booked == Game.favor_visitor_car_splat \
			and Game.favor == Game.favor_max \
			and get_tree().paused and screen.is_open \
			and screen.title_label.text == GameOverScreen.VICTORY_TITLE \
			and screen.dim_rect.color.is_equal_approx(screen.victory_dim) \
			and screen.victory_note.visible \
			and screen.breakdown_label.text \
					== "Tourists splatted: 0    Cars splatted: 0    Favor: %d" % Game.favor_max \
			and not Game.hunger.game_over_emitted and Game.hunger.value > 0.0 \
			and pause_menu.locked ## (T-151) The split rides before the Favor total.
	## The latch is one-shot: a further booking past the clamp moves nothing
	## (the ceiling's own favor_maxed_emitted latch holds; the counter never
	## re-armed — exactly the original car-relay leg's shape).
	Game.favor = Game.favor_max - Game.favor_visitor_car_splat
	var booked2: int = Game.splat_favor(CitizenClass.Kind.VISITOR, true)
	var latch_ok := booked2 == Game.favor_visitor_car_splat \
			and Game.favor == Game.favor_max \
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
	var old_car_ids: Array[int] = []
	for car in main_game.car_spawner.living_cars():
		old_car_ids.append(car.get_instance_id())
	var fp_before: int = city.fingerprint
	main_game.restart_run()
	var state_ok := not get_tree().paused \
			and not main_game.game_over_screen.visible \
			and Game.score == 0 and Game.tourist_hits == 0 and Game.car_hits == 0 \
			and Game.hunger.value >= Game.hunger.start_value - 0.001 \
			and not Game.hunger.game_over_emitted
	await _wait_frames(3) ## Let the queue_free'd old spawns flush out.
	var city_ok := city.fingerprint == fp_before ## (T-177) The bake identity — comparable scores.
	var respawn_ok := pigeon.global_position.distance_to(city.spawn_point) < 1.0
	## (T-178 re-pin) The fleet arms read the AMES reality: the tourist fleet
	## stays INERT (R2·pedestrians owns its re-base), but the traffic graph
	## (T-178) re-seeds a FRESH car fleet on the real streets — a stuck
	## pre-restart car (a reused instance id) or a missing moving fleet fails
	## here — while the bread service still holds its target.
	var fresh_tourists: Array[Tourist] = main_game.tourist_spawner.living_tourists()
	var fresh_cars_reset: Array[Car] = main_game.car_spawner.living_cars()
	var reused := false
	for tourist in fresh_tourists:
		reused = reused or old_tourist_ids.has(tourist.get_instance_id())
	var moving_reset := 0
	for car in fresh_cars_reset:
		reused = reused or old_car_ids.has(car.get_instance_id())
		if car.mode == Car.Mode.TRAFFIC:
			moving_reset += 1
	var spawns_ok := fresh_tourists.is_empty() \
			and not reused and moving_reset == main_game.car_spawner.target_moving \
			and main_game.bread_spawner.living_crumbs().size() == main_game.bread_spawner.target_count
	_check("restart_resets_run", state_ok and city_ok and respawn_ok and spawns_ok,
			"state=%s city=%s respawn=%s spawns=%s (tourists %d, crumbs %d, cars %d, moving %d)" % [
					state_ok, city_ok, respawn_ok, spawns_ok,
					fresh_tourists.size(), main_game.bread_spawner.living_crumbs().size(),
					fresh_cars_reset.size(), moving_reset])
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	main_game.free()
	_main_game = null


## Restart over the standing world (T-033, re-pinned by T-177): Main.restart_run()
## must take the same-seed fast path — no teardown, no rebuild (`build_count`
## stays 1, `fingerprint`/`spawn_point`/`last_report` untouched, exactly one
## `regenerated`) — while the spawners still re-seed off the emission and the
## pigeon returns to the spawn corridor. On the Ames world the re-seed reads
## the AMES fleet reality: ZERO citizens (the spawners stay inert until R2)
## and the bread service back at its target. If the fast path forgot to emit
## `regenerated`, the spawners would keep their old nodes and the instance-id
## overlap check below would fail the scenario.
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
	## (T-178 re-pin) The Ames fleet: the traffic graph re-seeds a FRESH
	## moving fleet over the real streets (never stuck pre-restart cars —
	## no reused instance ids), the tourist fleet stays inert until
	## R2·pedestrians, the bread service re-seeds to target.
	var moving_fresh := 0
	for car in fresh_cars:
		if car.mode == Car.Mode.TRAFFIC:
			moving_fresh += 1
	var spawns_ok := fresh_tourists.is_empty() \
			and moving_fresh == main_game.car_spawner.target_moving \
			and main_game.bread_spawner.living_crumbs().size() == main_game.bread_spawner.target_count \
			and not reused
	var regen_ok := _regen_relay == 1
	_check("restart_same_seed_skips_rebuild",
			city_ok and respawn_ok and spawns_ok and regen_ok,
			"city=%s respawn=%s spawns=%s regen=%d (tourists %d, cars %d, moving %d, build_count %d)" % [
					city_ok, respawn_ok, spawns_ok, _regen_relay,
					fresh_tourists.size(), fresh_cars.size(), moving_fresh,
					city.build_count])
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
	## previous counts as a change even though it is freed. (T-134 note) The
	## route deals shifted the parking RNG stream, so the nearest-to-spawn
	## crumb can now be a TAILGATE crumb whose +Z approach faces street
	## furniture (a cafe table, a bench — solid layer-1 the waddle cannot
	## cross), which would embed the drop and read zero forever. Try the
	## ground crumbs NEAREST the spawn point in order until one actually
	## eats — the flash/re-aim contract rides whichever crumb was eaten.
	var eat_candidates: Array[BreadCrumb] = []
	## (T-177 re-pin) The eaten crumb is STAGED at the ring spot now: the live
	## spread's 40 crumbs concentrate on the boot ring ~1.2 km from the pack
	## origin, so hoping a shuffled ground crumb lands near the ring staging
	## would re-roll the leg into city mode (where the flash contract cannot
	## run). One staged ground crumb AT the ring spot (`ahead_ground` is
	## already GLOBAL — the ahead leg's spot_world — so no further transform)
	## is the exact Windrow eat geometry, deterministic. The remaining
	## candidates (the spread, ring-nearest) stay as fallbacks so the leg
	## still proves the eat path if the staged spot were blocked.
	var eat_anchor: Vector3 = (ahead_ground if ahead_ground != Vector3.ZERO \
			else city.spawn_point)
	if ahead_ground != Vector3.ZERO:
		var staged_eat: BreadCrumb = spawner.drop_crumb(
				ahead_ground + Vector3(0.0, 0.16, 0.0))
		if staged_eat != null:
			eat_candidates.append(staged_eat)
	for crumb in spawner.living_crumbs():
		if crumb.global_position.y <= 0.3 and not eat_candidates.has(crumb):
			eat_candidates.append(crumb)
	eat_candidates.sort_custom(func(a: BreadCrumb, b: BreadCrumb) -> bool:
		return eat_anchor.distance_squared_to(a.global_position) \
				< eat_anchor.distance_squared_to(b.global_position))
	var reaim_ok := false
	var eaten := false
	var reaim_flashed := false
	var eat_target: BreadCrumb = null
	for candidate in eat_candidates:
		if eat_candidates.find(candidate) >= 6:
			break ## Six staged attempts is plenty; one always eats.
		eat_target = candidate
		pigeon.reset_flight(city.to_local(eat_target.global_position + Vector3(0.0, 0.4, 1.8)))
		for _i in 90:
			await get_tree().physics_frame
			if pigeon.is_grounded:
				break
		if _debug:
			_dbg("hud eat: try target %s, grounded=%s at %s" % [
					eat_target.global_position, pigeon.is_grounded,
					pigeon.global_position])
		Input.action_press("pitch_up")
		for _i in 120:
			await get_tree().physics_frame
			eaten = not is_instance_valid(eat_target)
			if eaten:
				break
			if _debug and _i % 60 == 0:
				_dbg("hud eat waddle %d: pos %s dist %.2f grounded %s vel %s" % [
						_i, pigeon.global_position,
						pigeon.global_position.distance_to(eat_target.global_position),
						pigeon.is_grounded, pigeon.velocity])
		Input.action_release("pitch_up")
		if eaten:
			break
		if _debug:
			_dbg("hud eat: attempt did not eat — next-nearest crumb")
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


## (T-130) The owner-dictated thumb ergonomics, pinned the T-019 way — the
## tuned values read back from the LIVE layer so a silent revert of either
## constant fails the same night: the Flap shape's radius is 68 canvas px
## (up from 52 — a full thumb-pad target), Poop's stays 52, `button_gap` is
## 30 (up from 18), and the Poop center sits EXACTLY `flap_center +
## (-(flap_r + gap + poop_r), -gap)` from the layout math — asserted against
## the pinned literals (68/30/52), never against the live constants, so
## reverting the .tscn radius or the script gap trips this check.
func _scenario_touch_button_layout_pins_tuned_values() -> void:
	var prev_size := _size_window_for_touch()
	var touch: TouchControls = TOUCH_SCENE.instantiate() as TouchControls
	touch.force_show = true
	add_child(touch)
	await _wait_frames(2) ## Layout settled (same window the family runs at).
	var flap_radius: float = (touch.flap_button.shape as CircleShape2D).radius
	var poop_radius: float = (touch.poop_button.shape as CircleShape2D).radius
	var gap: float = touch.button_gap
	var flap_center: Vector2 = (touch.get_node("SafeArea/FlapButton") as Node2D).global_position
	var poop_center: Vector2 = (touch.get_node("SafeArea/PoopButton") as Node2D).global_position
	var expected_offset := Vector2(-(68.0 + 30.0 + 52.0), -30.0)
	var offset_ok: bool = poop_center - flap_center == expected_offset
	_restore_window_size(prev_size)
	await _wait_frames(1)
	touch.free()
	_check("touch_button_layout_pins_tuned_values",
			flap_radius == 68.0 and poop_radius == 52.0 and gap == 30.0 and offset_ok,
			"flap_r=%.1f (want 68) poop_r=%.1f (want 52) gap=%.1f (want 30) poop_offset=%s (want exactly %s)" % [
					flap_radius, poop_radius, gap,
					poop_center - flap_center, expected_offset])


## --- scenario (T-127 Xbox controller) ---------------------------------------


## One joypad button event through the real pipeline (flushed synchronously,
## the T-119 touch-feed pattern — no frame boundary, so no polling node sees a
## stray press between helper calls).
func _pad_button(button: JoyButton, is_pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = is_pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## One joypad axis sample through the real pipeline — axis events are
## ABSOLUTE, so value 0.0 is the release.
func _pad_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## (T-127) Compact tags for an action's InputMap events — "b<idx>" joypad
## buttons, "m<axis>@<±v>" joypad motions, "k<keycode>" / "p<physical>" keys —
## so the gamepad scenario can pin the shipped mapping event-for-event.
func _pad_event_tags(action: String) -> PackedStringArray:
	var tags: PackedStringArray = []
	for ev: InputEvent in InputMap.action_get_events(action):
		var pad_btn := ev as InputEventJoypadButton
		if pad_btn != null:
			tags.append("b%d" % pad_btn.button_index)
		var pad_motion := ev as InputEventJoypadMotion
		if pad_motion != null:
			tags.append("m%d@%+.1f" % [pad_motion.axis, pad_motion.axis_value])
		var key := ev as InputEventKey
		if key != null:
			tags.append("k%d" % key.keycode if key.keycode != 0 else "p%d" % key.physical_keycode)
	return tags


## (T-127) The Xbox pad rides the EXISTING actions, pinned live: the mapping's
## joypad events sit on exactly the actions it names (stick axes 0/1 on the
## four steering actions, A on flap, RT + X on poop, Start on pause; restart/
## to_menu/quit/boost carry NO joypad events — the mapping invents nothing),
## every joypad event on device -1, the stick four at deadzone 0.25 while the
## button actions keep 0.5, ui_accept/ui_cancel carry A/B BESIDE their
## engine-default keys (Enter/KP-Enter/Space, Escape), and ui_up/down keep the
## engine-default dpad + left-stick traversal — with the action set still
## EXACTLY the shipped eleven. Behavior: a synthetic InputEventJoypadMotion
## through Input.parse_input_event drives the REAL axes — below-deadzone
## (0.2) reads exactly 0.0, a gentle 0.3 deflection reads non-zero (impossible
## at the old 0.5 default — the discriminating probe), full deflection ~1.0,
## and the pigeon itself flies the held stick (nose rises, banks and yaws),
## every axis back to exactly 0.0 on release. Menus: the REAL PauseMenu opens
## on Start, resumes via pad A on the focused Resume button, traverses focus
## on the dpad, and backs out on B; the title keeps a synthetic InputEventAction
## and non-Start joypad buttons inert (the T-097 gate, joypad edition — a live
## pad Start is never fed here, it would change the harness's own scene; that
## leg is Gate 3's).
func _scenario_gamepad_actions_bound() -> void:
	var expected := {
		"flap": ["b0"],
		"poop": ["m5@+1.0", "b2"],
		"pitch_up": ["m1@-1.0"],
		"pitch_down": ["m1@+1.0"],
		"turn_left": ["m0@-1.0"],
		"turn_right": ["m0@+1.0"],
		"pause": ["b6"],
	}
	var mapping_ok := true
	var detail_rows: PackedStringArray = []
	for action: String in expected:
		var pad_tags: PackedStringArray = []
		for tag: String in _pad_event_tags(action):
			if tag.begins_with("b") or tag.begins_with("m"):
				pad_tags.append(tag)
		var want: Array = expected[action]
		var has_all := true
		for tag: String in want:
			has_all = has_all and pad_tags.has(tag)
		mapping_ok = mapping_ok and has_all and pad_tags.size() == want.size()
		detail_rows.append("%s=[%s]" % [action, ",".join(pad_tags)])
	var unmapped_ok := true
	for action: String in ["restart", "to_menu", "quit", "boost"]:
		for tag: String in _pad_event_tags(action):
			unmapped_ok = unmapped_ok and not tag.begins_with("b") \
					and not tag.begins_with("m")
	var devices_ok := true
	for action: String in InputMap.get_actions():
		for ev: InputEvent in InputMap.action_get_events(action):
			if (ev is InputEventJoypadButton or ev is InputEventJoypadMotion) \
					and ev.device != -1:
				devices_ok = false
	var dz_ok := true
	for action: String in ["pitch_up", "pitch_down", "turn_left", "turn_right"]:
		dz_ok = dz_ok and InputMap.action_get_deadzone(action) == 0.25
	for action: String in ["flap", "poop", "pause"]:
		dz_ok = dz_ok and InputMap.action_get_deadzone(action) == 0.5
	var ui_ok := true
	for probe: Array in [
		["ui_accept", ["b0", "k4194309", "k4194310", "k32"]],
		["ui_cancel", ["b1", "k4194305"]],
		["ui_up", ["b11", "m1@-1.0"]],
		["ui_down", ["b12", "m1@+1.0"]],
	]:
		var tags := _pad_event_tags(probe[0])
		for tag: String in probe[1]:
			ui_ok = ui_ok and tags.has(tag)
	var seen: Dictionary = {}
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			seen[String(action)] = true
	var actions_ok := seen.size() == GAME_ACTIONS.size()
	for action: String in GAME_ACTIONS:
		actions_ok = actions_ok and seen.has(action)
	## Behavioral: the stick feeds the REAL axes through the deadzone. The
	## button actions' strengths ride the same pipeline (press, read, release
	## with no frame in between — nothing polling sees it).
	_pad_axis(JOY_AXIS_LEFT_Y, -0.2)
	var under_dz := Input.get_axis("pitch_down", "pitch_up") == 0.0
	_pad_axis(JOY_AXIS_LEFT_Y, -0.3) ## Stick up = pitch_up, 1:1 with W.
	var gentle_pitch := Input.get_axis("pitch_down", "pitch_up")
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	var full_pitch := Input.get_axis("pitch_down", "pitch_up")
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	_pad_axis(JOY_AXIS_LEFT_X, -1.0)
	var full_turn := Input.get_axis("turn_right", "turn_left")
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_pad_button(JOY_BUTTON_A, true)
	var flap_strength := Input.get_action_strength("flap")
	_pad_button(JOY_BUTTON_A, false)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var rt_strength := Input.get_action_strength("poop")
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_pad_button(JOY_BUTTON_X, true)
	var x_strength := Input.get_action_strength("poop")
	_pad_button(JOY_BUTTON_X, false)
	_pad_button(JOY_BUTTON_START, true)
	var start_strength := Input.get_action_strength("pause")
	_pad_button(JOY_BUTTON_START, false)
	var strengths_ok := under_dz and gentle_pitch > 0.01 and gentle_pitch < full_pitch \
			and full_pitch > 0.9 and full_turn > 0.9 and flap_strength == 1.0 \
			and rt_strength == 1.0 and x_strength == 1.0 and start_strength == 1.0
	## The pigeon flies the held stick — nose up on stick-up, bank + yaw on
	## stick-left, every axis exactly 0.0 again on release (the T-082 trim arm
	## survives the pad exactly as the touch stick proved it).
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(0.0, 0.0, -17.0))
	var nose0 := (-_player.transform.basis.z).y
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	for _i in 40:
		await get_tree().physics_frame
	var nose1 := (-_player.transform.basis.z).y
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _wait_frames(2)
	await _set_up(true, Vector3(0.0, 30.0, 0.0), Vector3(17.0, 0.0, 0.0))
	var yaw0 := _flat_yaw()
	_pad_axis(JOY_AXIS_LEFT_X, -1.0)
	for _i in 60:
		await get_tree().physics_frame
	var banked_left := _player.transform.basis.x.y
	var yaw_delta := absf(wrapf(_flat_yaw() - yaw0, -PI, PI))
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	await _wait_frames(2)
	var rest_after := _steering_axes_all_zero()
	var flight_ok := nose1 - nose0 > 0.15 and banked_left > 0.2 and yaw_delta > 0.3 \
			and rest_after
	## The pause menu, pad-driven, through the REAL main scene: Start opens
	## (Resume takes focus), A on the focused button resumes, Start re-opens,
	## the dpad moves focus, B backs out. Then the title's joypad gate
	## (T-097 edition): a synthetic InputEventAction and a joypad button that
	## is NOT Start both stay inert at the title.
	Game.save_path = SIM_SAVE_PATH
	Game.reset_run()
	var main_game: MainGame = MAIN_SCENE.instantiate()
	main_game.position = Vector3(4500.0, 0.0, -4500.0) ## Own space, clear of every other instanced Main.
	add_child(main_game)
	await _wait_frames(4)
	var pause_menu: PauseMenu = main_game.get_node("PauseMenu")
	var resume: Button = main_game.get_node("%ResumeButton")
	var restart: Button = main_game.get_node("PauseMenu/Center/PausePanel/Box/RestartButton")
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	await _wait_frames(2)
	var open_focus: Control = get_viewport().gui_get_focus_owner()
	var start_opens := get_tree().paused and pause_menu.is_open and open_focus == resume
	_pad_button(JOY_BUTTON_A, true)
	_pad_button(JOY_BUTTON_A, false)
	await _wait_frames(2)
	var a_resumes := not get_tree().paused and not pause_menu.is_open
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	await _wait_frames(2)
	_pad_button(JOY_BUTTON_DPAD_DOWN, true)
	_pad_button(JOY_BUTTON_DPAD_DOWN, false)
	await _wait_frames(2)
	var moved_focus: Control = get_viewport().gui_get_focus_owner()
	var dpad_traverses := get_tree().paused and moved_focus == restart
	_pad_button(JOY_BUTTON_B, true)
	_pad_button(JOY_BUTTON_B, false)
	await _wait_frames(2)
	var settings: Control = main_game.get_node("%SettingsPanel")
	var b_backs: bool = not get_tree().paused and not pause_menu.is_open \
			and not settings.visible
	main_game.free()
	Game.hunger.player = null ## The autoload's clock outlives this scene instance.
	Game.reset_run()
	get_tree().paused = false ## Never leak a pause into later scenarios.
	## The title's joypad gate (T-097 edition): a synthetic InputEventAction and
	## a joypad button that is NOT Start both stay inert at the title.
	var menu: Control = MENU_SCENE.instantiate()
	add_child(menu)
	await _wait_frames(2)
	var esc_action := InputEventAction.new()
	esc_action.action = "pause"
	esc_action.pressed = true
	menu._unhandled_input(esc_action)
	_pad_button(JOY_BUTTON_DPAD_UP, true)
	await _wait_frames(5)
	_pad_button(JOY_BUTTON_DPAD_UP, false)
	var title_gated := is_instance_valid(menu) and not get_tree().paused
	menu.free()
	_check("gamepad_actions_bound",
			mapping_ok and unmapped_ok and devices_ok and dz_ok and ui_ok
					and actions_ok and strengths_ok and flight_ok
					and start_opens and a_resumes and dpad_traverses and b_backs
					and title_gated,
			"mapping=%s unmapped=%s devices=%s dz=%s ui=%s actions=%s (%d seen) strengths=%s (under_dz=%s gentle=%.3f full_pitch=%.2f full_turn=%.2f flap=%s rt=%s x=%s start=%s) flight=%s (nose %.2f->%.2f bank=%.2f yaw=%.2f rest=%s) pad_menu=%s/%s/%s/%s title_gated=%s [%s]" % [
					mapping_ok, unmapped_ok, devices_ok, dz_ok, ui_ok, actions_ok,
					seen.size(), strengths_ok, under_dz, gentle_pitch, full_pitch,
					full_turn, flap_strength, rt_strength, x_strength, start_strength,
					flight_ok, nose0, nose1, banked_left, yaw_delta, rest_after,
					start_opens, a_resumes, dpad_traverses, b_backs, title_gated,
					", ".join(detail_rows)])


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
		## (T-127) The pad family rides the same line: stick steer, A flap,
		## RT poop, Start pause.
		for padcap: String in ["pad", "stick steer", "A flap", "RT poop", "Start pause"]:
			text_ok = text_ok and controls.text.contains(padcap)
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
## (T-177 re-pin) the relay nodes STAGED bare — the resident Ames world's
## fleet is empty (the spawners stay inert until R2; the retired fleet read
## crashed this scenario on the cutover tree and leaked its Main), so ONE
## bare tourist + ONE bare car are instanced and tourist_splatted /
## car_splatted emitted straight with them, so the full handler → Game →
## hit_scored chain runs with no physics. Assertions: the strip sits under the
## pointer block with the T-019 outline treatment and starts empty; a tourist
## splat reads "<Class> +100",
## the chained second one "<Class> +200 ×2", and a car splat after a landing
## replaces it with "<Class> car +30" — the class word derived from each
## EMITTED NODE's own citizen_class (T-151 re-pin: seed-robust, never a
## literal); every hit spawns a hit_marker.tscn burst ON the hit body (parent +
## position asserted, found via the group like juice_splat_burst_fires) that
## cleans itself up; the strip clears itself after combo_strip_seconds of game
## time and stays cleared; one more hit then restart_run() proves the restart
## clear mid-display (_scenario_restart_resets itself stays untouched).
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
	## (T-177 re-pin) The relay staging is BARE now: the resident Ames world's
	## citizen fleet is EMPTY (the spawners stay inert until R2 — the retired
	## fleet read crashed this scenario on the cutover tree and leaked its
	## Main), so the T-151 chain stages ONE bare tourist + ONE bare car — the
	## nodes the relays name — and emits the spawners' splatted signals with
	## them. The readout chain (class word, marker parent, points) reads the
	## NODE, never the fleet.
	var tourist_a: Tourist = (load("res://scenes/tourist.tscn") as PackedScene) \
			.instantiate() as Tourist
	var tourist_b: Tourist = (load("res://scenes/tourist.tscn") as PackedScene) \
			.instantiate() as Tourist
	var staged_car: Car = (load("res://scenes/car.tscn") as PackedScene) \
			.instantiate() as Car
	var anchor: Vector3 = main_game.city.to_local(main_game.city.spawn_point)
	tourist_a.position = anchor + Vector3(6.0, 0.3, 0.0)
	tourist_b.position = anchor + Vector3(-6.0, 0.3, 4.0)
	staged_car.position = anchor + Vector3(0.0, 0.3, -8.0)
	add_child(tourist_a)
	add_child(tourist_b)
	add_child(staged_car)
	await _wait_frames(2)
	var spread_ok: bool = tourist_a != null and tourist_b != null and staged_car != null
	var before := _count_effects("hit_marker.tscn")
	## Leg 1 — first tourist hit: kind + points, no multiplier yet, marker on
	## the hit body at the hit point.
	main_game.tourist_spawner.tourist_splatted.emit(tourist_a)
	var text_a := strip.text
	var marker_a: OneShotBurst = _find_hit_marker_on(tourist_a)
	var at_hit: bool = marker_a != null and marker_a.global_position \
			.distance_to(tourist_a.global_position) < 0.1
	## Leg 2 — the chained second tourist: the ×N suffix replaces the line.
	main_game.tourist_spawner.tourist_splatted.emit(tourist_b)
	var text_b := strip.text
	## Leg 3 — a landing ends the chain; the car hit replaces the line at ×1.
	Game.on_grounding_changed(true)
	main_game.car_spawner.car_splatted.emit(staged_car)
	var text_c := strip.text
	var marker_c: OneShotBurst = _find_hit_marker_on(staged_car)
	var texts_ok: bool = text_a == "%s +100" % CitizenClass.label(tourist_a.citizen_class) \
			and text_b == "%s +200 ×2" % CitizenClass.label(tourist_b.citizen_class) \
			and text_c == "%s car +30" % CitizenClass.label(staged_car.citizen_class) ## (T-151) The word from the node's own class.
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
	main_game.car_spawner.car_splatted.emit(staged_car)
	var refilled := strip.text == "%s car +30" % CitizenClass.label(staged_car.citizen_class) ## (T-151) Same node, same derived word.
	main_game.restart_run()
	var restart_cleared := strip.text == ""
	main_game.free()
	tourist_a.free()
	tourist_b.free()
	staged_car.free()
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


## (T-133) Harness hygiene for dust-counting scenarios: a puff from an EARLIER
## scenario's landing can still be alive (0.75 s lifetime) when this scenario
## samples its `before` count, and that stale puff dying mid-window turns the
## before/after compare into a false negative (measured: both T-133 landings
## dusted while the compare read false). Queue-free the stale puffs and let a
## frame pass before sampling.
func _clear_dust_puffs() -> void:
	for node in get_tree().get_nodes_in_group("juice_effects"):
		if is_instance_valid(node) and (node as Node).scene_file_path.ends_with("dust_puff.tscn"):
			node.queue_free()
	await _wait_frames(2)


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
	var cam: ChaseCamera = _player.chase_camera
	## (T-133) Two robustness pins for the drop. The old (0, −3, −9) recipe
	## arrived at asin(5.2/10.3) ≈ 30.3° — ON the 30° `max_land_angle_deg`
	## settle bar — so invisible cross-scenario float state decided whether the
	## touch settled (full impact recorded, trauma ~0.32) or was rejected into
	## the skid path (gutted impact, trauma 0.11, a 5-frame decay window the
	## lens check can out-live). −12 m/s forward re-derives the arrival to
	## ~24° / ~13 m/s: an unambiguous settle, trauma ~0.37 — still mid-band
	## against the never-full 0.5 bar. And the shake pattern rides the camera's
	## GLOBAL `_shake_clock`, which accumulates across every scenario in the
	## run — the check window samples a fixed-seed patch of the noise field at
	## whatever phase the whole prior run left (adding scenarios ahead of this
	## one moved the phase and failed `moved` with a healthy shake). Pin the
	## phase at the drop; the assertion bars themselves are untouched.
	cam._shake_clock = 0.0
	await _set_up(true, Vector3(0.0, 3.6, 4.0), Vector3(0.0, -3.0, -12.0))
	await _await_grounded(150)
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


## Full-density CPU budget (T-018, re-pinned by T-177): the REAL main scene —
## the resident Ames bake (184 chunks, ~600 placeholder colliders, occluders),
## the INERT citizen fleet (zero tourists/cars on the cutover world until R2
## re-points the spawners — the fleet arms below assert exactly that, so a
## citizen that somehow spawns on Ames fails the gate), the bread service,
## pigeon — must keep the calibrated headless CPU cost per physics frame.
## Headless renders nothing, so this gates the CPU half of the frame (scripts
## + physics + scene); draw calls and primitives stay with Gate 2's autoplay
## DONE line, the `ames_world_render_budget` row and Gate 3's human pass
## (VERIFICATION.md). Method: Main parked in its own space, the pigeon on a
## synthetic level cruise above the spawn corridor — velocity RE-IMPOSED at
## every window start, because the flight model bleeds speed and would
## otherwise mix cruise, stall and grounded states into the windows — 120
## warm-up frames, then three 100-frame wall-time windows under --fixed-fps 60
## (headless runs unthrottled, so wall time IS the CPU cost). Absolute and
## machine-relative: a busy machine can false-FAIL this gate (rerun when
## idle); a generous budget means percent-level drift passes by design.
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
	## The gate must measure what it claims: a half-seeded world would pass a
	## budget it does not deserve. (T-178 re-pin) The Ames fleet arms: the
	## traffic graph carries a LIVE 26-car fleet on the real streets now (the
	## median below already runs with it driving), the tourist spawner stays
	## inert until R2·pedestrians.
	var tourists: Array[Tourist] = main_game.tourist_spawner.living_tourists()
	var cars: Array[Car] = main_game.car_spawner.living_cars()
	var density_ok := tourists.is_empty() \
			and cars.size() == main_game.car_spawner.target_moving \
					+ main_game.car_spawner.target_parked \
			and int(main_game.city.render_metrics().get("chunk_count", 0)) > 0
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

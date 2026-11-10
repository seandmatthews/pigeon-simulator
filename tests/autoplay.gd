extends Node3D
## Autoplay smoke test (VERIFICATION.md Gate 2): boots the REAL game
## (scenes/main.tscn) and plays it with a scripted pilot for ~30 seconds,
## saving a screenshot every 5 s to .godot/autoplay/. Since T-010 it then ends
## the run on purpose: the pilot starves the pigeon, waits for the score
## screen, restarts through the same path the screen's Space button drives and
## verifies the fresh run before DONE. Exits 0 when the run completes with the
## pigeon alive and the restart clean; the caller greps the output for
## SCRIPT ERROR lines. Run windowed so it renders for real:
##   godot --path . res://tests/autoplay.tscn
##
## World-scoped Ames run (T-176, the ONLY run since the T-177 cutover): the
## SAME pilot plays the resident Ames world — spawn over Central Campus,
## the cruise band over the real massing, and a survival loop that FLIES to
## the nearest ground-class crumb, LANDS beside it, WADDLES in and EATS it
## (the Gate 2 pattern). `AMES_AUTOPLAY=1` in the environment (or
## `PIGEON_WORLD=ames`) still works and is now redundant: `Game.world`
## defaults "ames" and the Windrow generate path was retired at the cutover,
## so every boot is the Ames boot. The run uses the SHIPPED BreadSpawner
## target (40) — the world's boot ring (`City.boot_bread_spots`, the ground
## spots nearest the spawn, seeded first on every populate) puts real bread
## ~20 m out at boot, so one loop fits the window with nothing staged; the
## district-wide crumb SUPPLY itself is `ames_bread_reach`'s contract and the
## live-count bound is `ames_bread_spawner`'s. The Ames gate adds
## `eaten >= 1` to ok — the loop must actually close.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const RUN_SECONDS: float = 30.0
const SHOT_INTERVAL: float = 5.0
## T-010 restart phase: after RUN_SECONDS the pilot starves on purpose, waits
## this long for the score screen (timeout = gate failure), restarts and then
## cruises a few more seconds on the fresh run before DONE.
const RESTART_TIMEOUT: float = 6.0
const RESTART_PLAY_SECONDS: float = 3.0
const GROUND_VISIT_START: float = 8.0 ## T-003 excursion: descend to the plaza, land, waddle, take off.
const GROUND_VISIT_END: float = 29.0
const WADDLE_UNTIL: float = 28.6
## City-aware cruising (T-004): the cruise floor sits above every generated
## roof, so the only way to meet a wall is to stop believing in it.
const CRUISE_FLOOR: float = 23.0
const CRUISE_CEIL: float = 30.0
const DIVE_GATE: float = 29.0
const HOME_RADIUS: float = 40.0
## T-005: while grounded the waddle homes in on the nearest living crumb within
## this radius, so the land-and-peck eat path is actually exercised.
const CRUMB_SEEK_RADIUS: float = 22.0
## T-006: while airborne the pilot drops a poop every POOP_PERIOD seconds from
## POOP_START on — live splat projectiles now, counted for the DONE line.
const POOP_START: float = 4.0
const POOP_PERIOD: float = 2.0

## --- T-176 world-scoped Ames run (T-177: the ONLY run) ----------------------
## The env switch that used to scope the pilot to the resident Ames world —
## accepted and redundant since the cutover (every run is the Ames run).
const AMES_ENV := "AMES_AUTOPLAY"
## Ames cruise band (m): above the district massing (the bake's height cap is
## 40; the hero silhouettes top at Marston's 51 — the band stays under the
## cruise-relevant campus roofline and the pilot's steer-at-bread legs keep
## it clear of the towers it flies toward).
const AMES_CRUISE_FLOOR: float = 30.0
const AMES_CRUISE_CEIL: float = 38.0
## Ames run window (s): the world's boot ring puts bread ~20 m out at boot,
## so the loop closes many times over; the restart leg follows unchanged.
const AMES_RUN_SECONDS: float = 100.0
## Flat distance from the target crumb where the descent commits (m) and the
## final landing ring it steers into; the waddle covers the last metres.
const AMES_APPROACH: float = 110.0
const AMES_LAND_RING: float = 28.0
## Grounded waddle budget per touchdown (s) before the pilot flaps back out.
const AMES_WADDLE_SECONDS: float = 7.0

var _game: Node
var _player: Player
var _hunger: Hunger
var _spawner: BreadSpawner
var _tourists: TouristSpawner
var _cars: CarSpawner
var _elders: ElderSpawner
## (T-176) The world this run plays (true on the AMES_AUTOPLAY/PIGEON_WORLD
## ames boot) and its pilot anchors: the home flat (the spawn area on ames,
## the plaza on windrow — byte-identical there) and the crumb the flight leg
## is currently working toward.
var _ames: bool = false
var _home_flat: Vector2 = Vector2.ZERO
var _ames_target: BreadCrumb
var _touchdown_at: float = -1.0
var _eaten_at_touchdown: int = 0
var _elapsed: float = 0.0
var _next_shot: float = 1.0
var _shot_dir: String = ""
var _fps_sum: float = 0.0
var _fps_samples: int = 0
var _splats: int = 0 ## Poop splats that landed during the run (T-006 evidence).
var _poses_seen: Dictionary = {} ## Pigeon poses the run showed (T-011 evidence).
var _max_live_effects: int = 0 ## Peak one-shot juice bursts alive at once (T-013 evidence).
var _peak_trauma: float = 0.0 ## Peak camera shake trauma the run hit (T-013 evidence).
var _visit_gliding: bool = false ## Latched once the landing glide begins.
## Lead-shot altitude ceiling (m). High over the roofs the pilot's own banking
## makes the fall-time prediction garbage, so cruise keeps the T-007/T-008
## 14 m gate; the ground visit is a steady approach, so T-009 raises the gate
## to 18 m there and the poop triggers (T-007/T-008 leads plus the 5 m
## pursuit window) get more honest chances to earn real score.
var _lead_ceiling: float = 14.0
## T-010 restart phase machine: 0 cruise → 1 starving/waiting for the score
## screen → 2 restarted, final cruise. `_restart_ok` is the gate: DONE only
## passes when the screen showed the right numbers and the reset is clean.
var _restart_phase: int = 0
var _restart_deadline: float = 0.0
var _pre_score: int = 0
var _pre_tourists: int = 0
var _pre_cars: int = 0
var _screen_labels_ok: bool = false
var _restart_ok: bool = false


func _ready() -> void:
	## The pilot must keep driving while the game is frozen — the pause and
	## score screens stop every PAUSABLE node, this driver stays ALWAYS and
	## the game subtree is pinned back to PAUSABLE explicitly (it would
	## otherwise inherit ALWAYS from here).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shot_dir = ProjectSettings.globalize_path("res://.godot/autoplay")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	## (T-176, T-177) The world-scope switch, BEFORE Main instantiates — the
	## same seam the T-173 boot flag drives. Since the cutover the default IS
	## ames and "windrow" is no longer a legal world value, so every boot is
	## the Ames boot; the env switches remain accepted aliases.
	_ames = OS.get_environment(AMES_ENV) == "1" \
			or OS.get_environment("PIGEON_WORLD") == "ames" \
			or Game.world == "ames"
	if _ames:
		Game.world = "ames"
	_game = MAIN_SCENE.instantiate()
	add_child(_game)
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	_player = _game.get_node("Player") as Player
	_hunger = Game.hunger ## The hunger clock lives in the Game autoload (T-009).
	_spawner = _game.get_node("BreadSpawner") as BreadSpawner
	_tourists = _game.get_node("TouristSpawner") as TouristSpawner
	_cars = _game.get_node("CarSpawner") as CarSpawner
	_elders = _game.get_node("ElderSpawner") as ElderSpawner
	if _ames:
		## The Ames anchor: the survival spawn over Central Campus (the world
		## swap already happened inside Main's _ready, so `city` IS the Ames
		## world here — every boot since the T-177 cutover).
		var spawn: Vector3 = _game.city.spawn_point
		_home_flat = Vector2(spawn.x, spawn.z)
	_player.pooped.connect(_on_pilot_pooped)


## Every drop the pilot releases reports its splats back to the DONE line.
func _on_pilot_pooped(poop: Poop) -> void:
	poop.splatted.connect(func(_target: Node, _impact: Vector3) -> void: _splats += 1)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_fps_sum += Engine.get_frames_per_second()
	_fps_samples += 1
	_trace(_elapsed)
	if _ames:
		_drive_ames(_elapsed, delta)
	else:
		_drive(_elapsed, delta)
	_watch_poses()
	_watch_juice()
	if _elapsed >= _next_shot:
		_next_shot += SHOT_INTERVAL
		_capture(int(_elapsed))
	match _restart_phase:
		0:
			if _elapsed >= _run_seconds():
				_begin_restart_phase()
		1:
			_watch_score_screen()
		2:
			if _elapsed >= _run_seconds() + RESTART_PLAY_SECONDS:
				_finish()


## The run window: the Ames world gets the district-scale budget (see the
## header); the Windrow run keeps its 30 s.
func _run_seconds() -> float:
	return AMES_RUN_SECONDS if _ames else RUN_SECONDS


## The DONE line: alive + a clean T-010 restart + live audio (T-012) all gate
## the exit code; the restart stats join the reported run stats.
func _finish() -> void:
	var alive: bool = _player != null and is_instance_valid(_player) \
			and _player.velocity.is_finite() and _player.position.y > -10.0 \
			and _hunger != null and is_instance_valid(_hunger)
	var where: Vector3 = _player.position if _player != null and is_instance_valid(_player) else Vector3.ZERO
	var fps: float = _fps_sum / maxf(_fps_samples, 1)
	var eaten: int = _spawner.eaten_count if _spawner != null and is_instance_valid(_spawner) else -1
	var tourists: int = _tourists.living_tourists().size() if _tourists != null and is_instance_valid(_tourists) else -1
	var panics: int = _tourists.splat_count if _tourists != null and is_instance_valid(_tourists) else -1
	var honks: int = _cars.honk_count if _cars != null and is_instance_valid(_cars) else -1
	var shares: int = _elders.share_count if _elders != null and is_instance_valid(_elders) else -1
	var relocations: int = _elders.relocation_count if _elders != null and is_instance_valid(_elders) else -1
	## T-012: every event the pilot drove should have fired its sound. The bed
	## must be looping and at least the flap whoosh must have played — the pilot
	## flaps on every climb, so zero whooshes means the wiring is dead.
	var sfx_bits := PackedStringArray()
	for sound_name in Sfx.played_counts:
		sfx_bits.append("%s:%d" % [sound_name, Sfx.played_counts[sound_name]])
	sfx_bits.sort()
	var audio_ok: bool = Sfx.ambience_playing \
			and int(Sfx.played_counts.get("flap", 0)) >= 1
	var ok: bool = alive and _restart_ok and audio_ok
	## (T-176) The Ames loop must CLOSE: the run proves the survival circle —
	## fly, land, waddle, EAT — not just flight. `eaten >= 1` is the gate.
	var loop_ok: bool = not _ames or eaten >= 1
	var poses := _poses_seen.keys()
	poses.sort()
	print("AUTOPLAY DONE ok=%s world=%s crumb_target=%d loop_ok=%s t=%.1f fps=%.0f player=(%.1f, %.1f, %.1f) speed=%.2f hunger=%.0f eaten=%d splats=%d tourists=%d panics=%d honks=%d shares=%d relocations=%d score=%d high=%d restart=%s run_score=%d run_tourists=%d run_cars=%d poses=%s effects=%d shake_peak=%.2f sfx=%s ambience=%s" % [
			ok, "ames" if _ames else "windrow",
			_spawner.target_count if _spawner != null and is_instance_valid(_spawner) else -1, loop_ok,
			_elapsed, fps, where.x, where.y, where.z,
			_player.velocity.length() if alive else 0.0, _hunger.value, eaten, _splats,
			tourists, panics, honks, shares, relocations, Game.score, Game.high_score,
			_restart_ok, _pre_score, _pre_tourists, _pre_cars, ",".join(poses),
			_max_live_effects, _peak_trauma,
			",".join(sfx_bits), Sfx.ambience_playing])
	get_tree().quit(0 if ok and loop_ok else 1)


## T-010 restart phase, step 1: starve the pigeon on purpose (the score screen
## must come to US) and record the run's final numbers for the label check.
func _begin_restart_phase() -> void:
	_pre_score = Game.score
	_pre_tourists = Game.tourist_hits
	_pre_cars = Game.car_hits
	Game.hunger.value = 0.0 ## The game_over latch fires on the next hunger tick.
	_restart_deadline = _elapsed + RESTART_TIMEOUT
	_restart_phase = 1
	print("AUTOPLAY restart: starving on purpose at t=%.1f — score=%d tourists=%d cars=%d" % [
			_elapsed, _pre_score, _pre_tourists, _pre_cars])


## T-010 restart phase, step 2: the score screen opens (and freezes the run);
## check its numbers, then restart through the same path the screen's Space
## button drives and verify the fresh run synchronously.
func _watch_score_screen() -> void:
	var screen: GameOverScreen = _game.game_over_screen
	if get_tree().paused and screen.is_open:
		_screen_labels_ok = screen.score_label.text == "Score: %d" % _pre_score \
				and screen.high_label.text == "High score: %d" % Game.high_score \
				and screen.breakdown_label.text.contains("Tourists splatted: %d" % _pre_tourists) \
				and screen.breakdown_label.text.contains("Cars splatted: %d" % _pre_cars)
		print("AUTOPLAY restart: score screen up at t=%.1f — labels_ok=%s, restarting" % [
				_elapsed, _screen_labels_ok])
		_game.restart_run()
		_restart_ok = _screen_labels_ok \
				and not get_tree().paused and not screen.visible \
				and Game.score == 0 and Game.tourist_hits == 0 and Game.car_hits == 0 \
				and _hunger.value > 90.0 \
				and _player.position.distance_to(_game.city.spawn_point) < 1.0
		if not _restart_ok:
			print("AUTOPLAY restart: FAILED — paused=%s visible=%s score=%d hunger=%.0f spawn_dist=%.1f" % [
					get_tree().paused, screen.visible, Game.score, _hunger.value,
					_player.position.distance_to(_game.city.spawn_point)])
		_restart_phase = 2
	elif _elapsed >= _restart_deadline:
		print("AUTOPLAY restart: TIMEOUT — no score screen within %.0f s" % RESTART_TIMEOUT)
		_restart_phase = 2 ## Finishes with restart_ok=false — the gate fails.


## T-011 evidence: record which pigeon poses the run actually shows, so the
## DONE line can prove the presentation is live (flap beats, dive sweep, the
## waddle and the eat peck all leave a trace here).
func _watch_poses() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var bird: PigeonVisual = _player.pigeon
	if bird.flap_beating:
		_poses_seen["FLAP"] = true
	if bird.pecking:
		_poses_seen["PECK"] = true
	_poses_seen[String(PigeonVisual.Pose.find_key(bird.pose))] = true


## T-013 evidence: the peak number of one-shot juice bursts alive at once
## (splats, feathers, dust — proves the pass fired without spamming) and the
## peak camera shake trauma (proves the shake stayed a tick, never full).
func _watch_juice() -> void:
	_max_live_effects = maxi(_max_live_effects,
			get_tree().get_nodes_in_group("juice_effects").size())
	if _player != null and is_instance_valid(_player):
		_peak_trauma = maxf(_peak_trauma, _player.chase_camera.trauma)


## One-line-per-second progress trace — evidence for the gate log.
func _trace(t: float) -> void:
	if fmod(t, 1.0) >= (1.0 / 60.0):
		return
	print("AUTOPLAY t=%02.0f pos=(%.0f, %.0f, %.0f) speed=%.0f vy=%.1f nose=%.2f grounded=%s hunger=%.0f" % [
			t, _player.position.x, _player.position.y, _player.position.z,
			_player.velocity.length(), _player.velocity.y, _nose_y(), _player.is_grounded,
			_hunger.value if _hunger != null and is_instance_valid(_hunger) else -1.0])


## The shared poop trigger (T-006/T-007/T-008): air-only dropping, released
## wherever the bird happens to be flying, with the early lead-shot trigger
## when a strolling tourist (or car — the wider tolerance) lines up under the
## predicted impact, plus the cadence tap. Both pilots call it; on the Ames
## run the tourist/car spawners simply hold nobody (they early-return on the
## empty world arrays), so the cadence taps cover the lob evidence.
func _maybe_poop(t: float, delta: float) -> void:
	_lead_ceiling = 18.0 if (t >= GROUND_VISIT_START and t < GROUND_VISIT_END) else 14.0
	if t >= POOP_START and not _player.is_grounded \
			and (_tourist_in_lead() or _car_in_lead() or _pursuit_shot()
					or fmod(t - POOP_START, POOP_PERIOD) < delta):
		Input.action_press("poop")


## City-aware flight pattern (T-004). The pilot flies state-based, never
## timed-into-a-loop: below the cruise band it climbs hard (the spawn faces up
## the road corridor, clear of buildings at every height); at cruise it holds a
## 24–30 m band — above every generated roof — with paced flaps and a banked
## zigzag plus one bounded dive pulse; beyond HOME_RADIUS it arcs home; and from
## GROUND_VISIT_START it makes a ground visit: arc to the plaza, descend at a
## governed rate, touch down, waddle, take off again. On top of any airborne
## branch it drops a poop every POOP_PERIOD seconds (T-006 — the lob is live,
## splats are counted for the DONE line). All pitch commands are vy-bounded so
## the nose can never ratchet into a loop or a stall-mush.
func _drive(t: float, delta: float) -> void:
	for action in ["flap", "poop", "turn_left", "turn_right", "pitch_up", "pitch_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)

	_maybe_poop(t, delta)

	if t >= GROUND_VISIT_START and t < GROUND_VISIT_END:
		_drive_ground_visit(t, delta)
		return
	_visit_gliding = false

	var flat := Vector2(_player.position.x, _player.position.z)
	var vy := _player.velocity.y
	var speed := _player.velocity.length()

	# Low mode: below the cruise band, climb. Straight ahead is the road
	# corridor; near the plaza at roof height it also pulls toward the center.
	# Nose capped at ~27° up and flaps gated to vy < 5 (each flap now lifts
	# harder — T-015), so the climb eases into the band instead of zooming or
	# looping.
	if _player.position.y < CRUISE_FLOOR:
		if _nose_y() < 0.45:
			Input.action_press("pitch_up")
		if _player.position.y < 18.0 and flat.length() > 12.0:
			_steer_toward(flat)
		if vy < 5.0 and fmod(t, 0.4) < delta:
			Input.action_press("flap")
		return

	# Drifted too far — arc home above the skyline, with the same pitch
	# discipline as the cruise governor so the arc never zooms or dives.
	if flat.length() > HOME_RADIUS:
		_steer_toward(flat)
		var arc_pitch := _governor_pitch(vy, speed)
		if arc_pitch > 0.0:
			Input.action_press("pitch_up")
		elif arc_pitch < 0.0:
			Input.action_press("pitch_down")
		if _player.position.y < CRUISE_CEIL and vy < 6.0 and fmod(t, 0.5) < delta:
			Input.action_press("flap")
		return

	# Cruise governor: hold the 24–30 m band, keep airspeed near glide speed,
	# garnish with a bank and a bounded dive pulse. The steep-dive pull-out has
	# priority, and every pitch command is nose-bounded, so nothing can
	# ratchet the attitude into a loop or a sustained dive.
	var phase := fmod(t, 15.0)
	var turn := "turn_left" if int(t / 15.0) % 2 == 0 else "turn_right"
	var pitch := _governor_pitch(vy, speed)
	if phase >= 7.0 and phase < 7.6 and _player.position.y > DIVE_GATE \
			and vy > -6.0 and _nose_y() > -0.55:
		pitch = -1.0 ## The showy pulse — bounded, from over the roofs.
	if pitch > 0.0:
		Input.action_press("pitch_up")
	elif pitch < 0.0:
		Input.action_press("pitch_down")
	if phase >= 5.0 and phase < 7.0:
		Input.action_press(turn) ## Alternate the bank each loop so it zigzags.
	# T-015: flaps no longer throttle toward the old 28 m/s cap — their shove
	# fades out at glide_speed — so the governor flaps to hold the cruise band
	# itself (glide speed plus margin); beyond that, speed comes from the
	# bounded dive pulse below.
	if _player.position.y < CRUISE_CEIL and speed < _player.glide_speed + 3.0 \
			and fmod(t, 0.5) < delta:
		Input.action_press("flap")


## Banks toward the plaza center (the generator's one guaranteed-clear spot).
func _steer_toward(_flat: Vector2) -> void:
	_steer_toward_point(Vector2.ZERO)


## T-007: true when a strolling tourist sits within tolerance of the predicted
## poop impact — fall time from the pigeon's height times its velocity, plus
## the tourist's own stroll. A chance shot (drag ignored, pacing free): some
## runs connect, some tourists walk on — the DONE line reports `panics`.
func _tourist_in_lead() -> bool:
	if _tourists == null or not is_instance_valid(_tourists):
		return false
	if _player.position.y > _lead_ceiling:
		return false ## High lobs drift too far for a chance shot.
	var v := _player.velocity
	if Vector2(v.x, v.z).length() < 5.0:
		return false ## No lead to speak of — the cadence taps cover this.
	var fall := sqrt(2.0 * maxf(_player.position.y - 1.2, 0.0) / 12.0)
	var impact := Vector2(_player.position.x, _player.position.z) + Vector2(v.x, v.z) * fall
	for tourist in _tourists.living_tourists():
		var spot := Vector2(tourist.global_position.x, tourist.global_position.z) \
				+ Vector2(tourist.velocity.x, tourist.velocity.z) * fall
		if impact.distance_to(spot) < 1.5:
			return true
	return false


## T-008: the car version of the lead shot — same prediction, wider tolerance,
## because cars are the deliberately bigger, easier target (pillar 3). Only
## TRAFFIC cars move to lead; parked ones get hit whenever the impact drifts
## over them. The DONE line reports `honks`.
func _car_in_lead() -> bool:
	if _cars == null or not is_instance_valid(_cars):
		return false
	if _player.position.y > _lead_ceiling:
		return false ## High lobs drift too far for a chance shot.
	var v := _player.velocity
	if Vector2(v.x, v.z).length() < 5.0:
		return false ## No lead to speak of — the cadence taps cover this.
	var fall := sqrt(2.0 * maxf(_player.position.y - 1.5, 0.0) / 12.0)
	var impact := Vector2(_player.position.x, _player.position.z) + Vector2(v.x, v.z) * fall
	for car in _cars.living_cars():
		var spot := Vector2(car.global_position.x, car.global_position.z) \
				+ Vector2(car.velocity.x, car.velocity.z) * fall
		if impact.distance_to(spot) < 2.2:
			return true
	return false


## T-009: the pursuit pass's own trigger — the same prediction as
## `_car_in_lead` with a wider window (5 m, about a car length), live whenever
## the pigeon is low enough for the fall-time prediction to be honest. A 5 m
## prediction error still lands metal on a ~4.5 m car about half the time, so
## while the bird weaves through the ring-road traffic this roughly doubles
## the honk opportunities without steering the visit at all.
func _pursuit_shot() -> bool:
	if _cars == null or not is_instance_valid(_cars):
		return false
	if _player.position.y > _lead_ceiling:
		return false
	var v := _player.velocity
	var hv := Vector2(v.x, v.z)
	if hv.length() < 6.0:
		return false
	var fall := sqrt(2.0 * maxf(_player.position.y - 1.5, 0.0) / 12.0)
	var impact := Vector2(_player.position.x, _player.position.z) + hv * fall
	for car in _cars.living_cars():
		var spot := Vector2(car.global_position.x, car.global_position.z) \
				+ Vector2(car.velocity.x, car.velocity.z) * fall
		if impact.distance_to(spot) < 5.0:
			return true
	return false


## Banks (or waddle-turns) toward a world XZ point — one bang-bang convention
## shared by the plaza steering and the T-005 crumb homing.
func _steer_toward_point(target_flat: Vector2) -> void:
	var flat := Vector2(_player.position.x, _player.position.z)
	var to_target := (target_flat - flat).normalized()
	var fwd := Vector2(-_player.transform.basis.z.x, -_player.transform.basis.z.z)
	if fwd.cross(to_target) < 0.0:
		Input.action_press("turn_left")
	else:
		Input.action_press("turn_right")


## Nearest living breadcrumb within max_dist, or null — the ground-visit
## waddle homes in on it so the eat path is exercised, not just walked.
func _nearest_crumb(max_dist: float) -> BreadCrumb:
	if _spawner == null or not is_instance_valid(_spawner):
		return null
	var best: BreadCrumb = null
	var best_d := max_dist
	for crumb in _spawner.living_crumbs():
		var d := _player.position.distance_to(crumb.global_position)
		if d < best_d:
			best_d = d
			best = crumb
	return best


## Nearest crumb INSIDE the plaza block footprint (flat radius ≤ 13 m — the
## generator's guaranteed building-free zone), or null. Landing-aim targets
## only ever come from here, so the descent can never be dragged toward a
## neighboring block's walls.
func _plaza_crumb() -> BreadCrumb:
	if _spawner == null or not is_instance_valid(_spawner):
		return null
	var best: BreadCrumb = null
	var best_d := INF
	for crumb in _spawner.living_crumbs():
		var crumb_flat := Vector2(crumb.global_position.x, crumb.global_position.z)
		if crumb_flat.length() > 13.0:
			continue
		var d := _player.position.distance_to(crumb.global_position)
		if d < best_d:
			best_d = d
			best = crumb
	return best


## Sine of the nose pitch (positive = nose above the horizon). Every pitch
## command in the pilot is gated on this: the flight model has no attitude
## limits of its own, so an unbounded pitch_up would just loop the pigeon.
func _nose_y() -> float:
	return (-_player.transform.basis.z).y


## Cruise pitch decision shared by the governor and the arc-home branch:
## pull out of steep dives first, then keep the 24–30 m band, then keep
## airspeed up, then arrest zooms. All branches are nose-bounded.
func _governor_pitch(vy: float, speed: float) -> float:
	if vy < -6.0 and _nose_y() < 0.45:
		return 1.0 ## Pull out of any steep dive — always.
	if _player.position.y < 28.0 and vy < 1.0 and _nose_y() < 0.45:
		return 1.0 ## Keep the band.
	if speed < 15.0 and vy > -6.0 and _nose_y() > -0.55:
		return -1.0 ## Too slow: trade a little height for airspeed.
	if vy > 4.0 and _nose_y() > -0.55:
		return -1.0 ## Arrest zooms (the vy −6 pull-out bounds the resulting dive).
	return 0.0


## The T-003 excursion onto the spawn plaza, run as ONE attitude-target
## controller: always steer toward the plaza, bleed speed while fast (a slow
## bird can orbit the building-free ring instead of flying through it), then
## hold a ~20° glide down to the pavement. The only climbs are safety nets:
## under the roof-line floor outside the ring, and the final climb-out at
## t >= 27. Touchdown may skid, which is acceptable; then waddle — homing in
## on the nearest breadcrumb (T-005) so the land-and-peck loop runs for real —
## and flap back out. T-009 touches this visit only through the poop trigger
## above: the lead-shot ceiling rises to 18 m in the visit window (the
## descent is steady, so the fall-time prediction holds) and the pursuit
## trigger gets a car-length window — target hits stay chance shots, and the
## deterministic scoring proof lives in the sim harness (Gate 1b).
## All pitch is nose-bounded via the attitude holds.
func _drive_ground_visit(t: float, delta: float) -> void:
	if _player.is_grounded:
		_visit_gliding = false
		if t < WADDLE_UNTIL:
			var crumb := _nearest_crumb(CRUMB_SEEK_RADIUS)
			if crumb != null:
				_steer_toward_point(Vector2(crumb.global_position.x, crumb.global_position.z))
			Input.action_press("pitch_up") ## Waddle forward — toward the crumb when one is near.
		elif fmod(t, 0.4) < delta:
			Input.action_press("flap") ## Take off again.
		return
	var flat := Vector2(_player.position.x, _player.position.z)
	var vy := _player.velocity.y
	## Landing target: a crumb inside the building-free plaza block when one
	## exists (T-005), else the plaza center. Every range gate below is
	## relative to THIS target, so the orbit-bleed and glide latch agree with
	## wherever the bird is actually aimed.
	var land_crumb := _plaza_crumb()
	var target := Vector2.ZERO
	if land_crumb != null:
		target = Vector2(land_crumb.global_position.x, land_crumb.global_position.z)
	var target_dist := flat.distance_to(target)
	if t >= 27.0:
		_steer_toward_point(target)
		## Climb back out (missed landing or just took off) — nose- and
		## flap-capped so the climb eases into the cruise band.
		if _nose_y() < 0.45 and vy < 6.0:
			Input.action_press("pitch_up")
		if vy < 5.0 and fmod(t, 0.4) < delta:
			Input.action_press("flap")
		return
	var speed := _player.velocity.length()
	if speed <= 16.0 and target_dist <= 21.0 and _player.position.y > 8.0:
		_visit_gliding = true ## Committed: inside the ring and slow enough
		## that the steering radius stays inside it — fly the glide down.
	var target_nose: float
	if target_dist > 21.0 and _player.position.y < 18.5:
		target_nose = 0.10 ## Outside the ring, under the roof line: climb.
		if vy < 5.0 and fmod(t, 0.4) < delta:
			Input.action_press("flap")
	elif _player.position.y < 4.0:
		target_nose = -0.02 ## Flare the last metres: the skid eats the speed.
	elif _visit_gliding:
		target_nose = -0.35 ## The ~20° glide, all the way down; the dive gains
		## speed and the touchdown skid eats it — by design.
	elif speed > 14.0:
		target_nose = 0.02 ## Level orbit-bleed: circle the plaza, no flaps, no
		## thrust — the turn radius shrinks with speed until the spiral in.
	else:
		target_nose = -0.35
	if vy < -10.0:
		Input.action_press("pitch_up") ## Safety pull-up beats any target.
	else:
		_hold_nose(target_nose)
	_steer_toward_point(target)


## Bang-bang attitude hold around `target` (sine of the nose pitch). Holding
## the nose steady is what keeps vy steady — chasing vy directly with a 2.2
## rad/s actuator just oscillates.
func _hold_nose(target: float) -> void:
	var nose := _nose_y()
	if nose > target + 0.03:
		Input.action_press("pitch_down")
	elif nose < target - 0.03:
		Input.action_press("pitch_up")


## --- (T-176) the Ames survival-loop pilot ----------------------------------


## One survival loop over the real map, world-scoped: fly the band toward the
## nearest living GROUND-class crumb (the class a grounded pigeon eats from —
## the only "reachable" bread for this pilot), commit the descent inside
## AMES_APPROACH, steer into the landing ring, touchdown, waddle in, EAT
## (the crumb_eaten → Hunger.eat chain through the real Main wiring), flap
## back out, repeat until the window closes. Poop rides the shared trigger.
## All pitch stays nose-bounded like the Windrow pilot.
func _drive_ames(t: float, delta: float) -> void:
	for action in ["flap", "poop", "turn_left", "turn_right", "pitch_up", "pitch_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	_maybe_poop(t, delta)
	var target := _ames_ground_crumb()
	if target != _ames_target:
		_ames_target = target
		_touchdown_at = -1.0 ## A fresh crumb re-arms the waddle budget.
	if _player.is_grounded:
		_drive_ames_ground(t, delta)
	else:
		_drive_ames_air(t, delta)


## The working target: the nearest living crumb seeded on a GROUND-class spot.
## Hand-placed crumbs (spot_index < 0) are skipped — on this world they do not
## exist yet (no elders, no tailgates), and the guard keeps the class read
## honest against the live city arrays.
func _ames_ground_crumb() -> BreadCrumb:
	if _spawner == null or not is_instance_valid(_spawner):
		return null
	var city: City = _game.city
	if city == null or not is_instance_valid(city):
		return null
	var best: BreadCrumb = null
	var best_d := INF
	for crumb in _spawner.living_crumbs():
		if crumb.spot_index < 0 or crumb.spot_index >= city.bread_spot_kinds.size():
			continue
		if city.bread_spot_kinds[crumb.spot_index] != City.BreadKind.GROUND:
			continue
		var d := _player.position.distance_to(crumb.global_position)
		if d < best_d:
			best_d = d
			best = crumb
	return best


## Grounded leg: waddle toward the target crumb (home when none — the T-005
## land-and-peck path), flap back out once the eat booked or the waddle budget
## burned.
func _drive_ames_ground(t: float, delta: float) -> void:
	if _touchdown_at < 0.0:
		_touchdown_at = t
		_eaten_at_touchdown = _spawner.eaten_count
	var dest := _home_flat
	if _ames_target != null and is_instance_valid(_ames_target):
		dest = Vector2(_ames_target.global_position.x, _ames_target.global_position.z)
	_steer_toward_point(dest)
	Input.action_press("pitch_up") ## Waddle forward — toward the crumb.
	if _spawner.eaten_count > _eaten_at_touchdown \
			or t - _touchdown_at >= AMES_WADDLE_SECONDS:
		if fmod(t, 0.4) < delta:
			Input.action_press("flap") ## The eat is in; take off again.


## Airborne leg: cruise the band toward the crumb, commit the descent at
## AMES_APPROACH, flare into the landing ring; a no-bread frame keeps the
## band near home instead.
func _drive_ames_air(t: float, delta: float) -> void:
	var vy := _player.velocity.y
	var speed := _player.velocity.length()
	if _ames_target == null or not is_instance_valid(_ames_target):
		## Nothing to work toward — keep the band near the spawn area.
		var flat_home := Vector2(_player.position.x - _home_flat.x,
				_player.position.z - _home_flat.y)
		if flat_home.length() > HOME_RADIUS or _player.position.y < AMES_CRUISE_FLOOR:
			_steer_toward_point(_home_flat)
			var hold := _governor_pitch_ames(vy, speed)
			if hold > 0.0:
				Input.action_press("pitch_up")
			elif hold < 0.0:
				Input.action_press("pitch_down")
			if _player.position.y < AMES_CRUISE_CEIL and vy < 5.0 \
					and fmod(t, 0.4) < delta:
				Input.action_press("flap")
		return
	var tp := Vector2(_ames_target.global_position.x, _ames_target.global_position.z)
	var d := Vector2(_player.position.x - tp.x, _player.position.z - tp.y).length()
	if vy < -10.0 and _nose_y() < 0.45:
		Input.action_press("pitch_up") ## Safety pull-up beats any target.
		_steer_toward_point(tp)
		return
	if d > AMES_APPROACH or _player.position.y > AMES_CRUISE_CEIL + 8.0:
		## Cruise leg: hold the band, steer at the crumb.
		_steer_toward_point(tp)
		var pitch := _governor_pitch_ames(vy, speed)
		if pitch > 0.0:
			Input.action_press("pitch_up")
		elif pitch < 0.0:
			Input.action_press("pitch_down")
		if _player.position.y < AMES_CRUISE_CEIL and vy < 6.0 \
				and fmod(t, 0.5) < delta:
			Input.action_press("flap")
		return
	## Descent leg: commit, glide down, flare into the ring; bleed speed first
	## when the arrival is hot.
	_steer_toward_point(tp)
	var target_nose: float
	if d > AMES_LAND_RING:
		target_nose = -0.30 if _player.position.y > 14.0 else -0.12
	else:
		target_nose = -0.05 if _player.position.y > 5.0 else -0.02
	if speed > 17.0 and _player.position.y < 25.0:
		target_nose = maxf(target_nose, 0.05)
	_hold_nose(target_nose)


## The Ames cruise governor — the Windrow one's band values re-pinned to the
## district massing (AMES_CRUISE_FLOOR/CEIL), same discipline.
func _governor_pitch_ames(vy: float, speed: float) -> float:
	if vy < -6.0 and _nose_y() < 0.45:
		return 1.0 ## Pull out of any steep dive — always.
	if _player.position.y < AMES_CRUISE_FLOOR and vy < 1.0 and _nose_y() < 0.45:
		return 1.0 ## Keep the band.
	if speed < 15.0 and vy > -6.0 and _nose_y() > -0.55:
		return -1.0 ## Too slow: trade a little height for airspeed.
	if vy > 4.0 and _nose_y() > -0.55:
		return -1.0 ## Arrest zooms.
	return 0.0


func _capture(at_seconds: int) -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/shot-%03ds.png" % [_shot_dir, at_seconds])

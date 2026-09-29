extends Node3D
## Autoplay smoke test (VERIFICATION.md Gate 2): boots the REAL game
## (scenes/main.tscn) and plays it with a scripted pilot for ~30 seconds,
## saving a screenshot every 5 s to .godot/autoplay/. Exits 0 when the run
## completes with the pigeon alive and finite; the caller greps the output for
## SCRIPT ERROR lines. Run windowed so it renders for real:
##   godot --path . res://tests/autoplay.tscn
## Note: when T-010 adds the game-over flow this driver must learn to restart
## from the score screen.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const RUN_SECONDS: float = 30.0
const SHOT_INTERVAL: float = 5.0
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

var _game: Node
var _player: Player
var _hunger: Hunger
var _spawner: BreadSpawner
var _tourists: TouristSpawner
var _cars: CarSpawner
var _elapsed: float = 0.0
var _next_shot: float = 1.0
var _shot_dir: String = ""
var _fps_sum: float = 0.0
var _fps_samples: int = 0
var _splats: int = 0 ## Poop splats that landed during the run (T-006 evidence).
var _visit_gliding: bool = false ## Latched once the landing glide begins.
## Lead-shot altitude ceiling (m). High over the roofs the pilot's own banking
## makes the fall-time prediction garbage, so cruise keeps the T-007/T-008
## 14 m gate; the ground visit is a steady approach, so T-009 raises the gate
## to 18 m there and the poop triggers (T-007/T-008 leads plus the 5 m
## pursuit window) get more honest chances to earn real score.
var _lead_ceiling: float = 14.0


func _ready() -> void:
	_shot_dir = ProjectSettings.globalize_path("res://.godot/autoplay")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	_game = MAIN_SCENE.instantiate()
	add_child(_game)
	_player = _game.get_node("Player") as Player
	_hunger = Game.hunger ## The hunger clock lives in the Game autoload (T-009).
	_spawner = _game.get_node("BreadSpawner") as BreadSpawner
	_tourists = _game.get_node("TouristSpawner") as TouristSpawner
	_cars = _game.get_node("CarSpawner") as CarSpawner
	_player.pooped.connect(_on_pilot_pooped)


## Every drop the pilot releases reports its splats back to the DONE line.
func _on_pilot_pooped(poop: Poop) -> void:
	poop.splatted.connect(func(_target: Node, _impact: Vector3) -> void: _splats += 1)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_fps_sum += Engine.get_frames_per_second()
	_fps_samples += 1
	_trace(_elapsed)
	_drive(_elapsed, delta)
	if _elapsed >= _next_shot:
		_next_shot += SHOT_INTERVAL
		_capture(int(_elapsed))
	if _elapsed >= RUN_SECONDS:
		var alive: bool = _player != null and is_instance_valid(_player) \
				and _player.velocity.is_finite() and _player.position.y > -10.0 \
				and _hunger != null and is_instance_valid(_hunger)
		var where: Vector3 = _player.position if _player != null and is_instance_valid(_player) else Vector3.ZERO
		var fps: float = _fps_sum / maxf(_fps_samples, 1)
		var eaten: int = _spawner.eaten_count if _spawner != null and is_instance_valid(_spawner) else -1
		var tourists: int = _tourists.living_tourists().size() if _tourists != null and is_instance_valid(_tourists) else -1
		var panics: int = _tourists.splat_count if _tourists != null and is_instance_valid(_tourists) else -1
		var honks: int = _cars.honk_count if _cars != null and is_instance_valid(_cars) else -1
		print("AUTOPLAY DONE ok=%s t=%.1f fps=%.0f player=(%.1f, %.1f, %.1f) speed=%.2f hunger=%.0f eaten=%d splats=%d tourists=%d panics=%d honks=%d score=%d high=%d" % [
				alive, _elapsed, fps, where.x, where.y, where.z,
				_player.velocity.length() if alive else 0.0, _hunger.value, eaten, _splats,
				tourists, panics, honks, Game.score, Game.high_score])
		get_tree().quit(0 if alive else 1)


## One-line-per-second progress trace — evidence for the gate log.
func _trace(t: float) -> void:
	if fmod(t, 1.0) >= (1.0 / 60.0):
		return
	print("AUTOPLAY t=%02.0f pos=(%.0f, %.0f, %.0f) speed=%.0f vy=%.1f nose=%.2f grounded=%s hunger=%.0f" % [
			t, _player.position.x, _player.position.y, _player.position.z,
			_player.velocity.length(), _player.velocity.y, _nose_y(), _player.is_grounded,
			_hunger.value if _hunger != null and is_instance_valid(_hunger) else -1.0])


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

	# T-006: air-only dropping, released wherever the bird happens to be
	# flying — over the roofs, over the plaza, on the way down to land —
	# with the T-007 addition that the pilot pulls the trigger early when a
	# walking tourist lines up under the predicted impact point, and the T-008
	# addition that cars count too (bigger tolerance — the easy targets).
	# Grounded taps are skipped (the pigeon doesn't poop on the ground).
	_lead_ceiling = 18.0 if (t >= GROUND_VISIT_START and t < GROUND_VISIT_END) else 14.0
	if t >= POOP_START and not _player.is_grounded \
			and (_tourist_in_lead() or _car_in_lead() or _pursuit_shot()
					or fmod(t - POOP_START, POOP_PERIOD) < delta):
		Input.action_press("poop")

	if t >= GROUND_VISIT_START and t < GROUND_VISIT_END:
		_drive_ground_visit(t, delta)
		return
	_visit_gliding = false

	var flat := Vector2(_player.position.x, _player.position.z)
	var vy := _player.velocity.y
	var speed := _player.velocity.length()

	# Low mode: below the cruise band, climb. Straight ahead is the road
	# corridor; near the plaza at roof height it also pulls toward the center.
	# Nose capped at ~27° up and flaps capped at vy 8, so the climb eases into
	# the band instead of zooming or looping.
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

	# Cruise governor: hold the 24–30 m band, keep airspeed up, garnish with a
	# bank and a bounded dive pulse. The steep-dive pull-out has priority, and
	# every pitch command is nose-bounded, so nothing can ratchet the attitude
	# into a loop or a sustained dive.
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
	if _player.position.y < CRUISE_CEIL and speed < 28.0 and fmod(t, 0.5) < delta:
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


func _capture(at_seconds: int) -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/shot-%03ds.png" % [_shot_dir, at_seconds])

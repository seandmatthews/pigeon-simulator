extends Node
## The Game autoload (T-009): all game-wide state lives here — the score table
## (DESIGN: tourist 100, car 30), the combo (consecutive hits without landing
## escalate ×1 → ×2 → ×3 …, reset by landing or by combo_window), the +50%
## style bonus for hits born of a fast/low dive, the high score persisted to
## user:// the moment a run FIRST beats it (T-073: further beats in the same
## run only mark a dirty flag, flushed at game over or quit), the Hunger
## clock (T-005, moved off Main) and the park elders' favor (T-114 — a
## per-run currency the splat handlers, the bread steals and the elder share
## all book through). Main wires the player and the city services
## into it and renders the results (HUD line, world-space popups); the autoload
## itself stays presentation-free so the sim harness can drive it headless.

## Fired on every resolved hit: the points scored, the combo multiplier that
## applied, the world-space hit position (popups spawn there) and whether the
## style bonus applied. Main listens; the juice pass (T-013) may too.
signal hit_scored(points: int, multiplier: int, pos: Vector3, style: bool)

## (T-114) Fired on every favor change: the new balance and the delta that
## moved it (negatives allowed). Main listens and renders the HUD meter; the
## autoload itself stays presentation-free — it only books and emits.
signal favor_changed(favor: int, delta: int)

@export_group("Points")
@export var tourist_points: int = 100 ## Splatting a tourist (DESIGN table — the skill shot).
@export var car_points: int = 30 ## Splatting a car — the deliberately cheap target (DESIGN pillar 3).

@export_group("Combo")
@export var combo_window: float = 20.0 ## Seconds without a hit that end the chain.
@export var combo_max: int = 0 ## Multiplier cap; 0 = escalates forever.

@export_group("Style bonus")
@export var style_bonus_fraction: float = 0.5 ## +50% for a fast/low dive hit (DESIGN table).
@export var style_min_speed: float = 14.0 ## Poop release speed (m/s) that counts as "fast".
@export var style_max_height: float = 6.0 ## Poop release height (m) that counts as "low".
@export var style_release_window: float = 3.0 ## A release only styles hits resolved within this many seconds.

@export_group("Favor (T-114)")
@export var favor_visitor_splat: int = 3 ## Splatting a VISITOR pedestrian.
@export var favor_visitor_car_splat: int = 6 ## The jackpot — a visitor vehicle.
@export var favor_civilian_splat: int = -1 ## Friendly fire on a local pedestrian.
@export var favor_civilian_car_splat: int = -2 ## Friendly fire on a local car.
@export var favor_superfan_splat: int = -8 ## The rare loyalist — costs a lot, pedestrian or car.
@export var favor_steal_table: int = -1 ## Stealing a café tabletop crumb (civilians' bread).
@export var favor_steal_visitor: int = 1 ## Stealing a tailgate crumb (visitors' bread).
@export var elder_loaf_cost: int = 2 ## Favor per crumb the elders share (a 2-crumb share spends 4).

## Where the high score persists. Sim scenarios redirect it so test runs never
## touch the real record.
var save_path: String = "user://highscore.cfg"

## Play sessions launched by tests/tools/pilot.py set PIGEON_NO_PERSIST=1 so N
## concurrent agent-driven runs never fight over (or wipe) the real record.
var _persistence_enabled: bool = OS.get_environment("PIGEON_NO_PERSIST") != "1"

## Boot audio policy (T-101): the game starts MUTED — a normal launch or editor
## run is silent so nobody gets ambushed by audio, and a sound-design session
## opts in explicitly. Priority order: the pilot's PIGEON_MUTE=1 always mutes;
## PIGEON_SOUND=1 or a `--sound` user arg (after `--` on the CLI, or the
## editor's Main Run Args) opts in; anything else mutes. Applied once in _ready.
func boot_muted(user_args: PackedStringArray) -> bool:
	if OS.get_environment("PIGEON_MUTE") == "1":
		return true
	if OS.get_environment("PIGEON_SOUND") == "1":
		return false
	return not user_args.has("--sound")

## Points this run so far — zeroed only by reset_run().
var score: int = 0

## The park elders' favor (T-114) — the per-run currency earned by splatting
## black-and-gold visitors and stolen visitor bread, spent on the bread they
## share, nicked by every local you hit or rob. Zeroed only by reset_run().
var favor: int = 0

## Tourists splatted this run — the game-over score screen's breakdown (T-010).
var tourist_hits: int = 0
## Cars splatted this run — the game-over score screen's breakdown (T-010).
var car_hits: int = 0

## Best score ever seen. The record is written to save_path the moment a run
## FIRST beats it (T-073) — that write keeps a crash or an Alt-F4 safe as of
## the first beat. Further beats in the same run only mark
## `_high_score_dirty`, flushed at game over or on quit — so a crash mid-chain
## keeps the record as of the first beat, not the last.
var high_score: int = 0

## True once this run pushed the record up — the score screen's "new high
## score" banner reads this, so an exact tie can't fake it.
var record_beaten: bool = false

## (T-073) True after this run's FIRST record-beating write, so every later
## beat in the same run skips the synchronous disk write and only marks the
## dirty flag instead.
var _saved_this_run: bool = false

## (T-073) True while a run has beats past the first that save_path has not
## seen yet — `_flush_high_score()` writes and clears it.
var _high_score_dirty: bool = false

## (T-073) Real disk writes performed by `_save_high_score()` since boot, past
## the `_persistence_enabled` guard — the sim harness's throttle assertion
## counts this, never the beat count.
var _save_count: int = 0

## The hunger clock (T-005), created in _ready — Main attaches the player to
## it; the sim harness builds its own instances directly.
var hunger: Hunger

var _streak: int = 0 ## Consecutive hits since the last landing/window reset.
var _combo_idle: float = 0.0 ## Seconds since the last hit.
var _release_pos: Vector3 = Vector3.ZERO
var _release_speed: float = 0.0
var _release_age: float = 999.0 ## Seconds since the last poop release; starts stale.


func _ready() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), boot_muted(OS.get_cmdline_user_args()))
	hunger = Hunger.new()
	hunger.name = "Hunger"
	add_child(hunger)
	hunger.game_over.connect(_flush_high_score) ## (T-073) Starvation flushes the run's dirty beats.
	load_high_score()


func _physics_process(delta: float) -> void:
	_release_age += delta
	if _streak > 0:
		_combo_idle += delta
		if _combo_idle >= combo_window:
			_end_combo()


## The multiplier the most recent hit was worth (and the next chain hit will
## beat): 1, 2, 3 … capped by combo_max when set. 0 = no chain live.
func combo_multiplier() -> int:
	if combo_max > 0:
		return mini(_streak, combo_max)
	return _streak


## Scores a tourist splat at `pos` — the DESIGN skill shot, 100 base.
func add_tourist_hit(pos: Vector3) -> int:
	tourist_hits += 1
	return _register_hit(tourist_points, pos)


## Scores a car splat at `pos` — the cheap target, 30 base.
func add_car_hit(pos: Vector3) -> int:
	car_hits += 1
	return _register_hit(car_points, pos)


## (T-114) Books a favor delta — negatives allowed, no floor and no cap: a
## floor would make civilian splats free once you are broke, and the ceiling
## is T-115's to define. Emits favor_changed; Main renders the meter.
func add_favor(delta: int) -> void:
	favor += delta
	favor_changed.emit(favor, delta)


## (T-114) The favor a splat is worth: the per-class delta table, cars
## included — the visitor vehicle is the jackpot and the superfan pays the
## same on foot or on wheels. Books through add_favor and returns the delta.
func splat_favor(kind: CitizenClass.Kind, vehicle: bool) -> int:
	var delta: int
	match kind:
		CitizenClass.Kind.VISITOR:
			delta = favor_visitor_car_splat if vehicle else favor_visitor_splat
		CitizenClass.Kind.SUPERFAN:
			delta = favor_superfan_splat
		_:
			delta = favor_civilian_car_splat if vehicle else favor_civilian_splat
	add_favor(delta)
	return delta


## Records the release conditions of a poop (Main relays player.pooped): the
## "fast/low dive" half of the style test is judged here, at drop time, not at
## impact — gravity gives every falling drop speed, but only a dive releases
## it fast AND low.
func on_poop_released(pos: Vector3, velocity: Vector3) -> void:
	_release_pos = pos
	_release_speed = velocity.length()
	_release_age = 0.0


## A landing always ends the chain (Main relays grounding_changed).
func on_grounding_changed(grounded: bool) -> void:
	if grounded:
		_end_combo()


## Fresh-run state (restarts, the sim harness): zeroes the score, the
## tourist/car breakdown and the combo, refills hunger. The high score is
## deliberately kept — it persists — and so is any not-yet-flushed beat (T-073:
## only the per-run beat bookkeeping clears; a dirty record still flushes).
## (T-114) Favor is per-run state too — zeroed with the score.
func reset_run() -> void:
	score = 0
	favor = 0
	tourist_hits = 0
	car_hits = 0
	record_beaten = false
	_saved_this_run = false
	_high_score_dirty = false
	_end_combo()
	_release_age = 999.0
	hunger.reset()


## Reads the persisted record (boot, and the sim harness's restart round-trip).
func load_high_score() -> void:
	if not _persistence_enabled:
		return
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		high_score = int(cfg.get_value("score", "high", 0))


func _register_hit(base_points: int, pos: Vector3) -> int:
	_streak += 1
	_combo_idle = 0.0
	var style := _is_style_hit()
	var bonus := (1.0 + style_bonus_fraction) if style else 1.0
	var points := roundi(float(base_points) * combo_multiplier() * bonus)
	score += points
	if score > high_score:
		high_score = score
		record_beaten = true
		if not _saved_this_run: ## (T-073) The FIRST beat writes on its frame — a crash keeps the record.
			_saved_this_run = true
			_save_high_score()
		else: ## Further beats in the same run only mark the flag; game over or quit flushes.
			_high_score_dirty = true
	hit_scored.emit(points, combo_multiplier(), pos, style)
	return points


## The +50% style bonus: the hit came from a poop released during a fast, low
## pass, and released recently — a stale drop from a forgotten dive pays plain.
func _is_style_hit() -> bool:
	return _release_age <= style_release_window \
			and _release_speed >= style_min_speed \
			and _release_pos.y <= style_max_height


func _end_combo() -> void:
	_streak = 0
	_combo_idle = 0.0


## (T-073) Writes the run's accumulated beats past the first-beat save — at
## game over (hunger.game_over), at the window close request, or at teardown.
## A no-op while nothing is dirty.
func _flush_high_score() -> void:
	if not _high_score_dirty:
		return
	_save_high_score()
	_high_score_dirty = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush_high_score() ## (T-073) Alt-F4 / quit paths flush too; the dirty guard makes it a no-op when clean.


func _save_high_score() -> void:
	if not _persistence_enabled:
		return
	_save_count += 1
	var cfg := ConfigFile.new()
	cfg.set_value("score", "high", high_score)
	cfg.save(save_path)

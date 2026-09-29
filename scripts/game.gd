extends Node
## The Game autoload (T-009): all game-wide state lives here — the score table
## (DESIGN: tourist 100, car 30), the combo (consecutive hits without landing
## escalate ×1 → ×2 → ×3 …, reset by landing or by combo_window), the +50%
## style bonus for hits born of a fast/low dive, the high score persisted to
## user:// the moment a run beats it, and the Hunger clock (T-005, moved off
## Main). Main wires the player and the city services into it and renders the
## results (HUD line, world-space popups); the autoload itself stays
## presentation-free so the sim harness can drive it headless.

## Fired on every resolved hit: the points scored, the combo multiplier that
## applied, the world-space hit position (popups spawn there) and whether the
## style bonus applied. Main listens; the juice pass (T-013) may too.
signal hit_scored(points: int, multiplier: int, pos: Vector3, style: bool)

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

## Where the high score persists. Sim scenarios redirect it so test runs never
## touch the real record.
var save_path: String = "user://highscore.cfg"

## Points this run so far — zeroed only by reset_run().
var score: int = 0

## Tourists splatted this run — the game-over score screen's breakdown (T-010).
var tourist_hits: int = 0
## Cars splatted this run — the game-over score screen's breakdown (T-010).
var car_hits: int = 0

## Best score ever seen; written to save_path as soon as a run beats it, so a
## crash or an Alt-F4 still keeps the record.
var high_score: int = 0

## True once this run pushed the record up — the score screen's "new high
## score" banner reads this, so an exact tie can't fake it.
var record_beaten: bool = false

## The hunger clock (T-005), created in _ready — Main attaches the player to
## it; the sim harness builds its own instances directly.
var hunger: Hunger

var _streak: int = 0 ## Consecutive hits since the last landing/window reset.
var _combo_idle: float = 0.0 ## Seconds since the last hit.
var _release_pos: Vector3 = Vector3.ZERO
var _release_speed: float = 0.0
var _release_age: float = 999.0 ## Seconds since the last poop release; starts stale.


func _ready() -> void:
	hunger = Hunger.new()
	hunger.name = "Hunger"
	add_child(hunger)
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
## deliberately kept — it persists.
func reset_run() -> void:
	score = 0
	tourist_hits = 0
	car_hits = 0
	record_beaten = false
	_end_combo()
	_release_age = 999.0
	hunger.reset()


## Reads the persisted record (boot, and the sim harness's restart round-trip).
func load_high_score() -> void:
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
		_save_high_score()
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


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "high", high_score)
	cfg.save(save_path)

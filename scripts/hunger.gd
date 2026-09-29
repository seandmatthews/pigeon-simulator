class_name Hunger
extends Node
## The survival clock (T-005). Hunger drains every physics tick — faster for a
## flap-paced climb, slowest while resting on the ground — and hits game over
## exactly once at zero (T-010 turns the signal into a screen). Eating bread
## (T-005 crumbs) restores a chunk. Owned by the Game autoload since T-009
## (score, combo and high score live there too); Main and the sim harness
## attach a player to it — attach_player() for late wiring, or plain
## assignment before add_child.

## Emitted on every value change — the HUD bar (and later the game-over flow)
## listens to this.
signal changed(value: float, max_value: float)

## Emitted exactly once, the tick hunger reaches zero. Never again until
## reset() — starvation is a one-way door within a run.
signal game_over

@export_group("Bar")
@export var max_value: float = 100.0 ## Full-bar size; all drains and restores are in these units.
@export var start_value: float = 100.0 ## Value after spawn or reset().

@export_group("Drain")
## Gliding/idle drain per second. A pure glide from full lasts
## max_value / drain_per_second ≈ 3.7 min; the design's "~3 min of lazy
## flying" is a flap-glide mix (see the ticket for the tuned mix).
@export var drain_per_second: float = 0.45
@export var flap_drain_multiplier: float = 2.0 ## Drain scale while flap heat is up — climbing costs.
@export var flap_heat_seconds: float = 0.7 ## Window after a flap impulse that still counts as "flapping".
@export var grounded_drain_multiplier: float = 0.6 ## Drain scale while resting on the ground.

## The pigeon whose effort drives the drain — Main wires this via
## `player_path`; the sim harness assigns it directly.
var player: Player
@export var player_path: NodePath

## Current hunger, always clamped to [0, max_value]; every write emits changed.
var value: float:
	get: return _value
	set(new_value):
		_value = clampf(new_value, 0.0, max_value)
		changed.emit(_value, max_value)

## True once game_over has fired; stays true until reset().
var game_over_emitted: bool = false

var _value: float
var _flap_heat: float = 0.0


func _ready() -> void:
	if player == null and not player_path.is_empty():
		player = get_node(player_path) as Player
	if player != null:
		attach_player(player)
	value = start_value


## Hooks the drain clock up to a player — safe to call again (idempotent) and
## safe to call after _ready, which is how Main attaches the player to the
## autoload-owned clock.
func attach_player(new_player: Player) -> void:
	player = new_player
	if new_player != null and not new_player.flapped.is_connected(_on_player_flapped):
		new_player.flapped.connect(_on_player_flapped)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_flap_heat = maxf(_flap_heat - delta, 0.0)
	var rate := drain_per_second
	if player.is_grounded:
		rate *= grounded_drain_multiplier
	elif _flap_heat > 0.0:
		rate *= flap_drain_multiplier
	value = value - rate * delta
	if value <= 0.0 and not game_over_emitted:
		game_over_emitted = true
		game_over.emit()


## Restores a chunk of hunger — wired to the bread service's crumb_eaten.
func eat(amount: float) -> void:
	value = value + amount


## Fresh run state for restarts and the sim harness: refills the bar, clears
## the one-shot game-over latch and any flap heat.
func reset() -> void:
	_flap_heat = 0.0
	game_over_emitted = false
	value = start_value


func _on_player_flapped() -> void:
	_flap_heat = flap_heat_seconds

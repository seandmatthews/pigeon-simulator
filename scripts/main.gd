extends Node3D
## Game shell: wires the survival loop together — the Hunger clock (T-005), the
## bread service that feeds it, the tourist crowd (T-007), and the HUD. Score
## lives here until the Game autoload arrives with the scoring ticket (T-009);
## the fail state (T-010) listens to Hunger.game_over.

const HINT_AIR := "W/S pitch · A/D turn · Space flap · F poop · land by bread to eat"
const HINT_GROUND := "Grounded! W/S waddle · A/D turn · Space flap off · walk into crumbs to eat"

@onready var stats_label: Label = %StatsLabel
@onready var hint_label: Label = %HintLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var player: Player = $Player
@onready var city: City = $City
@onready var hunger: Hunger = $Hunger
@onready var bread_spawner: BreadSpawner = $BreadSpawner
@onready var tourist_spawner: TouristSpawner = $TouristSpawner
@onready var car_spawner: CarSpawner = $CarSpawner

var score: int = 0

func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	player.grounding_changed.connect(_on_grounding_changed)
	bread_spawner.crumb_eaten.connect(hunger.eat)
	tourist_spawner.tourist_splatted.connect(_on_tourist_splatted)
	car_spawner.car_splatted.connect(_on_car_splatted)
	hunger.changed.connect(_on_hunger_changed)
	hunger.game_over.connect(_on_game_over)
	## Spawn on the road corridor by the plaza (T-004): a short drop onto the
	## asphalt, in the one corridor the generator guarantees is clear of
	## buildings at every height.
	player.reset_flight(city.spawn_point)
	_on_hunger_changed(hunger.value, hunger.max_value)

func _process(_delta: float) -> void:
	stats_label.text = "Score: %d    Hunger: %d%%" % [score, roundi(hunger.value)]

## The hunger bar mirrors Hunger.changed — the number stays on the stats line.
func _on_hunger_changed(value: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = value

## Token score per tourist splat so the hit event is live and visible in the
## HUD; T-009 replaces this with the real score table and combos.
func _on_tourist_splatted(_tourist: Tourist) -> void:
	score += 1

## The car splat's 30 base points straight from the DESIGN table (pillar 3:
## cars are the cheap target); T-009 folds this into the real table.
func _on_car_splatted(car: Car) -> void:
	score += car.points_value

## T-010 replaces this with the real game-over screen; until then the signal
## still fires exactly once at zero and the HUD says so.
func _on_game_over() -> void:
	hint_label.text = "Starved! The pigeons mourn you. (game-over screen: T-010)"
	print("HUNGER: game over — signal fired at zero")

## The player signals every landing/takeoff so the hint always shows the
## controls that currently do something (T-003 grounded readability).
func _on_grounding_changed(grounded: bool) -> void:
	hint_label.text = HINT_GROUND if grounded else HINT_AIR

extends Node3D
## Placeholder game shell: owns the survival stats and paints them on the HUD.
## Score, hunger and the fail state move into a Game autoload when the
## scoring ticket (T-009) lands.

const HINT_AIR := "W/S pitch · A/D turn · Space flap · F poop (soon)"
const HINT_GROUND := "Grounded! W/S waddle · A/D turn · Space flap off"

@onready var stats_label: Label = %StatsLabel
@onready var hint_label: Label = %HintLabel
@onready var player: Player = $Player
@onready var city: City = $City

var score: int = 0
var hunger: float = 100.0

func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	player.grounding_changed.connect(_on_grounding_changed)
	## Spawn on the road corridor by the plaza (T-004): a short drop onto the
	## asphalt, in the one corridor the generator guarantees is clear of
	## buildings at every height.
	player.reset_flight(city.spawn_point)

func _process(delta: float) -> void:
	hunger = maxf(hunger - 1.0 * delta, 0.0)
	stats_label.text = "Score: %d    Hunger: %d%%" % [score, roundi(hunger)]

## The player signals every landing/takeoff so the hint always shows the
## controls that currently do something (T-003 grounded readability).
func _on_grounding_changed(grounded: bool) -> void:
	hint_label.text = HINT_GROUND if grounded else HINT_AIR

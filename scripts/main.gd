extends Node3D
## Placeholder game shell: owns the survival stats and paints them on the HUD.
## Score, hunger and the fail state move into a Game autoload when the
## scoring ticket (T-009) lands.

@onready var stats_label: Label = %StatsLabel

var score: int = 0
var hunger: float = 100.0

func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)

func _process(delta: float) -> void:
	hunger = maxf(hunger - 1.0 * delta, 0.0)
	stats_label.text = "Score: %d    Hunger: %d%%" % [score, roundi(hunger)]

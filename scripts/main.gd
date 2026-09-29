extends Node3D
## Game shell: wires the survival loop together — the player, the city services
## (bread T-005, tourists T-007, cars T-008) and the HUD. All game-wide state —
## score, combo, high score and the Hunger clock — lives in the Game autoload
## since T-009; Main attaches the player and the services to it and renders the
## results: the HUD stats line and world-space score popups at each splat.
## The fail state (T-010) listens to Game.hunger.game_over.

const HINT_AIR := "W/S pitch · A/D turn · Space flap · F poop · land by bread to eat"
const HINT_GROUND := "Grounded! W/S waddle · A/D turn · Space flap off · walk into crumbs to eat"
const SCORE_POPUP_SCENE: PackedScene = preload("res://scenes/score_popup.tscn")

@onready var stats_label: Label = %StatsLabel
@onready var hint_label: Label = %HintLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var player: Player = $Player
@onready var city: City = $City
@onready var bread_spawner: BreadSpawner = $BreadSpawner
@onready var tourist_spawner: TouristSpawner = $TouristSpawner
@onready var car_spawner: CarSpawner = $CarSpawner


func _ready() -> void:
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	player.grounding_changed.connect(_on_grounding_changed)
	player.grounding_changed.connect(Game.on_grounding_changed) ## Landing ends the combo.
	player.pooped.connect(_on_player_pooped) ## Release conditions feed the style bonus.
	bread_spawner.crumb_eaten.connect(Game.hunger.eat)
	tourist_spawner.tourist_splatted.connect(_on_tourist_splatted)
	car_spawner.car_splatted.connect(_on_car_splatted)
	Game.hit_scored.connect(_on_hit_scored)
	Game.hunger.attach_player(player)
	Game.hunger.changed.connect(_on_hunger_changed)
	Game.hunger.game_over.connect(_on_game_over)
	## Spawn on the road corridor by the plaza (T-004): a short drop onto the
	## asphalt, in the one corridor the generator guarantees is clear of
	## buildings at every height.
	player.reset_flight(city.spawn_point)
	_on_hunger_changed(Game.hunger.value, Game.hunger.max_value)


func _process(_delta: float) -> void:
	var combo := Game.combo_multiplier()
	var combo_text := ("    ×%d combo" % combo) if combo >= 2 else ""
	stats_label.text = "Score: %d%s    Hunger: %d%%" % [
			Game.score, combo_text, roundi(Game.hunger.value)]


## The hunger bar mirrors Game.hunger.changed — the number stays on the stats line.
func _on_hunger_changed(value: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = value


## Release conditions for the style bonus: where and how fast the poop left
## the pigeon — the Game autoload judges "fast/low dive" from this.
func _on_player_pooped(poop: Poop) -> void:
	Game.on_poop_released(poop.global_position, poop.linear_velocity)


## Tourist splats feed the Game autoload's table (100 base, DESIGN); the popup
## spawns from the hit_scored event.
func _on_tourist_splatted(tourist: Tourist) -> void:
	Game.add_tourist_hit(tourist.global_position)


## Car splats feed the Game autoload's table (30 base — the cheap target,
## DESIGN pillar 3); the popup spawns from the hit_scored event.
func _on_car_splatted(car: Car) -> void:
	Game.add_car_hit(car.global_position)


## Every scored hit gets a floating "+100 ×2" at the splat (T-009).
func _on_hit_scored(points: int, multiplier: int, pos: Vector3, _style: bool) -> void:
	var popup: ScorePopup = SCORE_POPUP_SCENE.instantiate()
	popup.setup(points, multiplier, pos)
	add_child(popup)


## T-010 replaces this with the real game-over screen; until then the signal
## still fires exactly once at zero and the HUD says so.
func _on_game_over() -> void:
	hint_label.text = "Starved! The pigeons mourn you. (game-over screen: T-010)"
	print("HUNGER: game over — signal fired at zero")


## The player signals every landing/takeoff so the hint always shows the
## controls that currently do something (T-003 grounded readability).
func _on_grounding_changed(grounded: bool) -> void:
	hint_label.text = HINT_GROUND if grounded else HINT_AIR

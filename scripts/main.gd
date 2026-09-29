class_name MainGame
extends Node3D
## Game shell: wires the survival loop together — the player, the city services
## (bread T-005, tourists T-007, cars T-008) and the HUD. All game-wide state —
## score, combo, high score and the Hunger clock — lives in the Game autoload
## since T-009; Main attaches the player and the services to it and renders the
## results: the HUD stats line and world-space score popups at each splat.
## The fail state (T-010) listens to Game.hunger.game_over and opens the score
## screen; restart_run() rebuilds the run in place and menu.tscn sits in front.

const HINT_AIR := "W/S pitch · A/D turn · Space flap · F poop · land by bread to eat"
const HINT_GROUND := "Grounded! W/S waddle · A/D turn · Space flap off · walk into crumbs to eat"
const SCORE_POPUP_SCENE: PackedScene = preload("res://scenes/score_popup.tscn")
const MENU_SCENE_PATH := "res://scenes/menu.tscn"

@onready var stats_label: Label = %StatsLabel
@onready var hint_label: Label = %HintLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var game_over_screen: GameOverScreen = $GameOverScreen
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
	bread_spawner.crumb_eaten.connect(player.peck) ## Every swallowed crumb plays the eat peck (T-011).
	tourist_spawner.tourist_splatted.connect(_on_tourist_splatted)
	car_spawner.car_splatted.connect(_on_car_splatted)
	Game.hit_scored.connect(_on_hit_scored)
	Game.hunger.attach_player(player)
	Game.hunger.changed.connect(_on_hunger_changed)
	Game.hunger.game_over.connect(_on_game_over)
	pause_menu.restart_requested.connect(restart_run)
	pause_menu.menu_requested.connect(_to_menu)
	pause_menu.quit_requested.connect(_quit)
	game_over_screen.restart_requested.connect(restart_run)
	game_over_screen.menu_requested.connect(_to_menu)
	## Spawn on the road corridor by the plaza (T-004): a short drop onto the
	## asphalt, in the one corridor the generator guarantees is clear of
	## buildings at every height. to_local: spawn_point is global, reset_flight
	## positions locally — identical while Main sits at the origin, correct
	## wherever the scene is instanced (the sim harness moves it far away).
	player.reset_flight(city.to_local(city.spawn_point))
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


## The fail state (T-010): starvation opens the score screen — final score,
## the persisted high score and the tourist/car breakdown — and freezes the
## run (the screen owns the pause; Esc-pausing is locked out by PauseMenu).
## The signal fires exactly once per run (T-005 latch).
func _on_game_over() -> void:
	pause_menu.locked = true
	game_over_screen.open(Game.score, Game.high_score,
			Game.tourist_hits, Game.car_hits, Game.record_beaten)
	print("HUNGER: game over — signal fired at zero")


## In-place fresh run (T-010): zeroes the autoload state, regenerates the SAME
## M1 seed city (the `regenerated` signal re-seeds every spawner, so the layout
## — and the score comparability — matches the old city street for street),
## clears transient effects and drops the pigeon back on the spawn corridor.
## Deliberately not a scene reload: this exact path is what the score screen's
## restart and the autoplay pilot drive, headless-safe.
func restart_run() -> void:
	Game.reset_run()
	get_tree().paused = false
	pause_menu.locked = false
	pause_menu.close()
	game_over_screen.close()
	for popup in get_tree().get_nodes_in_group("score_popups"):
		popup.queue_free()
	for poop in get_tree().get_nodes_in_group("poops"):
		poop.queue_free()
	city.generate(city.seed_value)
	player.reset_flight(city.to_local(city.spawn_point))
	_on_hunger_changed(Game.hunger.value, Game.hunger.max_value)


## Back to the title screen — the other half of the menu.tscn ↔ main.tscn flow.
func _to_menu() -> void:
	Game.reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _quit() -> void:
	get_tree().quit()


## The player signals every landing/takeoff so the hint always shows the
## controls that currently do something (T-003 grounded readability).
func _on_grounding_changed(grounded: bool) -> void:
	hint_label.text = HINT_GROUND if grounded else HINT_AIR

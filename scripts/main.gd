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

## Hunger warning tiers (T-019): the bar is the fail state's messenger, so it
## changes color — and then pulses — as the clock runs down. All driven in
## game time so the flash stays deterministic under --fixed-fps and freezes
## with the world when the run is paused or over.
const HUNGER_TIER_WARN := 0.5 ## Below half the bar turns amber.
const HUNGER_TIER_DANGER := 0.25 ## Below a quarter it turns red and starts pulsing.
const HUNGER_TIER_CRITICAL := 0.10 ## Under 10% it flashes fast, from a darker red.
const TIER_REST_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), ## Tier 0 — healthy: untouched white.
	Color(1.0, 0.72, 0.35), ## Tier 1 — amber: start thinking about bread.
	Color(1.0, 0.32, 0.25), ## Tier 2 — red: pulsing alarm.
	Color(1.0, 0.16, 0.14), ## Tier 3 — dark red base: fast flash, still distinct if a beat is missed.
]
const TIER_PULSE_HZ: Array[float] = [0.0, 0.0, 3.0, 6.0] ## Flash rate per tier — 0 = static color.
const TIER_PULSE_TO := Color(1.0, 0.85, 0.8) ## The bright end both pulsing tiers breathe toward.

@export_group("Juice") ## T-013
@export var hit_shake: float = 0.3 ## Camera-shake fraction per scored splat — your hits land with a tick.
@export var pulse_base_scale: float = 1.14 ## HUD pulse size at a ×2 escalation, growing per extra combo step.
@export var pulse_seconds: float = 0.3 ## Seconds the HUD pulse takes to settle back.

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

var _combo_shown: int = 0 ## The multiplier the HUD last displayed — escalations past it pulse.
var _score_pulse: Tween
var hud_warning_tier: int = 0 ## The hunger warning band the bar currently shows (0 healthy … 3 critical).
var _pulse_phase: float = 0.0 ## Game-time phase of the tier flash — advanced only while a tier pulses.


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
	Sfx.start_ambience() ## The looping city bed under everything (T-012).
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


func _process(delta: float) -> void:
	var combo := Game.combo_multiplier()
	var combo_text := ("    ×%d combo" % combo) if combo >= 2 else ""
	stats_label.text = "Score: %d%s    Hunger: %d%%" % [
			Game.score, combo_text, roundi(Game.hunger.value)]
	if combo >= 2 and combo > _combo_shown:
		_pulse_score(combo) ## Escalation — the score line pulses (T-013).
	_combo_shown = combo
	var pulse_hz: float = TIER_PULSE_HZ[hud_warning_tier]
	if pulse_hz > 0.0: ## Danger tiers breathe between their rest color and the bright end.
		_pulse_phase += delta * pulse_hz * TAU
		var beat := 0.5 + 0.5 * sin(_pulse_phase)
		hunger_bar.modulate = TIER_REST_COLORS[hud_warning_tier].lerp(TIER_PULSE_TO, beat)


## The HUD pulse (T-013): a combo escalation bumps the score line up a size —
## a bit more with every extra step, capped — flashes it gold, then the whole
## thing eases back to rest within pulse_seconds. Scale arcs up (TRANS_BACK,
## a little overshoot) and back in two sequential steps; the color fade runs
## alongside the settle. A new escalation mid-pulse kills and restarts it, so
## the label always ends back at rest.
func _pulse_score(combo: int) -> void:
	stats_label.pivot_offset = stats_label.size * 0.5
	stats_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	var peak := Vector2.ONE * (pulse_base_scale + 0.05 * clampf(combo - 2, 0.0, 4.0))
	if _score_pulse != null and _score_pulse.is_valid():
		_score_pulse.kill()
	_score_pulse = create_tween()
	_score_pulse.tween_property(stats_label, "scale", peak, pulse_seconds * 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_pulse.tween_property(stats_label, "scale", Vector2.ONE, pulse_seconds * 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_score_pulse.parallel().tween_property(stats_label, "theme_override_colors/font_color",
			Color.WHITE, pulse_seconds)


## The hunger bar mirrors Game.hunger.changed — the number stays on the stats
## line, and the bar carries the T-019 warning tiers. The setter emits on
## EVERY drain tick (~60/s), so this only touches state on a tier CHANGE:
## entering a tier paints its rest color and rewinds the pulse phase (entering
## a quiet tier leaves the bar parked there — never stranded mid-flash), while
## the _process pulse owns the animation between ticks.
func _on_hunger_changed(value: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = value
	var fraction := value / max_value if max_value > 0.0 else 0.0
	var tier := 3
	if fraction > HUNGER_TIER_CRITICAL:
		tier = 2
	if fraction > HUNGER_TIER_DANGER:
		tier = 1
	if fraction > HUNGER_TIER_WARN:
		tier = 0
	if tier != hud_warning_tier:
		hud_warning_tier = tier
		_pulse_phase = 0.0
		hunger_bar.modulate = TIER_REST_COLORS[tier]


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


## Every scored hit gets a floating "+100 ×2" at the splat (T-009), a tiny
## camera shake on the pigeon's own handiwork (T-013) and the HUD pulse when
## the combo escalates (fired from _process).
func _on_hit_scored(points: int, multiplier: int, pos: Vector3, _style: bool) -> void:
	var popup: ScorePopup = SCORE_POPUP_SCENE.instantiate()
	popup.setup(points, multiplier, pos)
	add_child(popup)
	player.chase_camera.add_shake(hit_shake)


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
	Sfx.stop_ambience() ## The title screen isn't the city (T-012).
	Game.reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _quit() -> void:
	get_tree().quit()


## The player signals every landing/takeoff so the hint always shows the
## controls that currently do something (T-003 grounded readability).
func _on_grounding_changed(grounded: bool) -> void:
	hint_label.text = HINT_GROUND if grounded else HINT_AIR

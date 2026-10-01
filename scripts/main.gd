class_name MainGame
extends Node3D
## Game shell: wires the survival loop together — the player, the city services
## (bread T-005, tourists T-007, cars T-008) and the HUD. All game-wide state —
## score, combo, high score and the Hunger clock — lives in the Game autoload
## since T-009; Main attaches the player and the services to it and renders the
## results: the HUD stats line, the bread pointer's wayfinding (T-037) and
## world-space score popups at each splat.
## The fail state (T-010) listens to Game.hunger.game_over and opens the score
## screen; restart_run() rebuilds the run in place and menu.tscn sits in front.

const HINT_AIR := "W/S pitch · A/D turn · Space flap · F poop · land by bread to eat"
const HINT_GROUND := "Grounded! W/S waddle · A/D turn · Space flap off · walk into crumbs to eat"
const SCORE_POPUP_SCENE: PackedScene = preload("res://scenes/score_popup.tscn")
const HIT_MARKER_SCENE: PackedScene = preload("res://scenes/hit_marker.tscn")
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
const POOP_READY_DIM_ALPHA := 0.25 ## (T-077) The F glyph's alpha while the poop cooldown runs — dim, but readable.
const POINTER_CLIMB_CUE_M := 3.0 ## (T-098) Vertical delta beyond which the bread readout carries the ▲/▼ climb cue.

@export_group("Juice") ## T-013
@export var hit_shake: float = 0.3 ## Camera-shake fraction per scored splat — your hits land with a tick.
@export var pulse_base_scale: float = 1.14 ## HUD pulse size at a ×2 escalation, growing per extra combo step.
@export var pulse_seconds: float = 0.3 ## Seconds the HUD pulse takes to settle back.
@export var combo_strip_seconds: float = 2.5 ## (T-040) Seconds the HUD combo strip keeps showing the last hit — game time, so it freezes with a paused or ended run.

@onready var stats_label: Label = %StatsLabel
@onready var hint_label: Label = %HintLabel
## The F readiness glyph (T-077) — sits beside the hint line it qualifies.
@onready var poop_ready_label: Label = %PoopReady
@onready var bread_pointer: Label = %BreadPointer
## The last-hit line (T-040) — sits under the pointer slot in the left column.
@onready var combo_strip: Label = %ComboStrip
## The pointer's rotatable chevron (T-037): 0 = screen-up, clockwise positive
## on screen. Since T-057 it carries the target's direction ON SCREEN —
## where the target actually sits in the frame — not a bearing from the nose.
## Hides with the label (it is its child).
@onready var bread_pointer_chevron: Polygon2D = bread_pointer.get_node("Chevron")
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var game_over_screen: GameOverScreen = $GameOverScreen
@onready var player: Player = $Player
@onready var city: City = $City
@onready var bread_spawner: BreadSpawner = $BreadSpawner
@onready var tourist_spawner: TouristSpawner = $TouristSpawner
@onready var car_spawner: CarSpawner = $CarSpawner
@onready var elder_spawner: ElderSpawner = $ElderSpawner

var _combo_shown: int = 0 ## The multiplier the HUD last displayed — escalations past it pulse.
var _stats_cache: String = "" ## (T-055) The stats line last pushed to the label — the string is recomposed every frame but assigned only when score, combo or the rounded hunger percent actually moved.
var _score_pulse: Tween
var hud_warning_tier: int = 0 ## The hunger warning band the bar currently shows (0 healthy … 3 critical).
var _pulse_phase: float = 0.0 ## Game-time phase of the tier flash — advanced only while a tier pulses.
var _last_hit_kind: String = "" ## (T-040) "Tourist"/"Car", stashed by the splat handlers — hit_scored carries points but not the target kind.
var _combo_strip_left: float = 0.0 ## (T-040) Game-time seconds left before the strip clears; 0 = at rest, empty.


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
	## (T-042, adopting T-036) The same point feeds the off-world guard: hand
	## the player that corridor in its own local space — the same point the
	## opening drop starts from — so flying past the apron walks the fall back
	## here. Player has no City reference, so only Main can compute this. It
	## never goes stale in M1 — restart_run() always keeps the same seed, so
	## spawn_point (and with it the guard's target) is identical across restarts.
	player.respawn_point = city.to_local(city.spawn_point)
	player.reset_flight(player.respawn_point)
	_on_hunger_changed(Game.hunger.value, Game.hunger.max_value)


func _process(delta: float) -> void:
	var combo := Game.combo_multiplier()
	var combo_text := ("    ×%d combo" % combo) if combo >= 2 else ""
	## (T-055) The content moves at human pace (score, combo, rounded hunger %),
	## so the label write happens only on change — the composition stays local.
	var stats := "Score: %d%s    Hunger: %d%%" % [
			Game.score, combo_text, roundi(Game.hunger.value)]
	if stats != _stats_cache:
		_stats_cache = stats
		stats_label.text = stats
	if combo >= 2 and combo > _combo_shown:
		_pulse_score(combo) ## Escalation — the score line pulses (T-013).
	_combo_shown = combo
	var pulse_hz: float = TIER_PULSE_HZ[hud_warning_tier]
	if pulse_hz > 0.0: ## Danger tiers breathe between their rest color and the bright end.
		_pulse_phase += delta * pulse_hz * TAU
		var beat := 0.5 + 0.5 * sin(_pulse_phase)
		hunger_bar.modulate = TIER_REST_COLORS[hud_warning_tier].lerp(TIER_PULSE_TO, beat)
	_update_bread_pointer() ## Wayfinding (T-037) — refreshed alongside the stats line.
	_update_poop_ready() ## The F readiness glyph (T-077) — same game-time cadence.
	if _combo_strip_left > 0.0: ## (T-040) The strip expires in game time like the tier pulse —
		_combo_strip_left -= delta ## deterministic under --fixed-fps, frozen while paused/over.
		if _combo_strip_left <= 0.0:
			_combo_strip_left = 0.0
			combo_strip.text = ""


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


## The bread pointer (T-037): one HUD slot under the hint block, two modes, no
## minimap. Inside the city ring it aims the chevron at the nearest living
## crumb and counts the metres down ("bread 23 m", plus the T-098 climb cue —
## " ▲"/" ▼" when that crumb sits well above/below the pigeon); beyond half the
## city span the ring is lost and the same slot points home instead
## ("city 131 m", horizontal distance to city.spawn_point, never arrowed).
## Hidden whenever it has nothing to say. Since T-057 the chevron's
## rotation_degrees carries the target's direction ON SCREEN — both ends
## unprojected through the live chase camera, 0° = screen-up, clockwise
## positive — so the chevron points where the target actually sits in the
## frame, whatever the pigeon's nose or the camera's yaw is doing.
func _update_bread_pointer() -> void:
	var pigeon_pos := player.global_position
	var off_centre := pigeon_pos - city.global_position
	off_centre.y = 0.0
	if off_centre.length() > city.city_span * 0.5:
		var home := city.spawn_point
		var flat_home := Vector2(home.x - pigeon_pos.x, home.z - pigeon_pos.z)
		_aim_bread_pointer(home, "city", flat_home.length())
		return
	var crumb := bread_spawner.nearest_crumb(pigeon_pos)
	if crumb == null:
		bread_pointer.visible = false
		return
	_aim_bread_pointer(crumb.global_position, "bread",
			pigeon_pos.distance_to(crumb.global_position), true)


## Points the shared slot at `target`: text "<what> <m> m", chevron along the
## target's on-screen direction from the pigeon (T-057): both ends unprojected
## through the live chase camera, 0° = screen-up (+90 over the atan2 because
## canvas y is down). Off-camera protection: with no camera, a target behind
## the lens (anything sterner than roughly abeam — its unprojection would be
## mirrored garbage), or a degenerate delta (the target unprojects onto the
## pigeon's anchor), the last chevron rotation is kept instead — never a
## mirrored direction, never a NaN.
## The climb cue (T-098): only the bread mode opts in — a named crumb more than
## POINTER_CLIMB_CUE_M above/below the pigeon gets a trailing " ▲"/" ▼", so a
## roof crumb stops reading like a blank wall it points into. City mode never
## carries the cue: its target is always street level.
func _aim_bread_pointer(target: Vector3, what: String, distance: float,
		with_climb_cue: bool = false) -> void:
	bread_pointer.visible = true
	var climb_cue := ""
	if with_climb_cue:
		var dy := target.y - player.global_position.y
		if dy > POINTER_CLIMB_CUE_M:
			climb_cue = " ▲"
		elif dy < -POINTER_CLIMB_CUE_M:
			climb_cue = " ▼"
	bread_pointer.text = "%s %d m%s" % [what, roundi(distance), climb_cue]
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(target):
		return
	var target_s := camera.unproject_position(target)
	var anchor_s := camera.unproject_position(player.global_position)
	var d := target_s - anchor_s
	if d.length_squared() < 1.0:
		return
	bread_pointer_chevron.rotation_degrees = rad_to_deg(atan2(d.y, d.x)) + 90.0


## The F readiness glyph (T-077): the scoring verb fails three silent ways —
## grounded (by design), mid-cooldown, or both — and the little "F" beside the
## hint line says which. Hidden while grounded (F cannot answer there), lit at
## full alpha while airborne with a rested drop, dimmed to a quarter while the
## cooldown runs. Game time like the rest of _process: pausing stops this
## method, so the glyph freezes with the world, and restart_run() zeroes the
## cooldown through reset_flight, so the next tick relights it on its own.
## Both writes are guarded (the T-035/T-055 redundant-write concern): idle
## frames touch nothing.
func _update_poop_ready() -> void:
	var airborne := not player.is_grounded
	if poop_ready_label.visible != airborne:
		poop_ready_label.visible = airborne
	var want_alpha := 1.0 if player.poop_ready else POOP_READY_DIM_ALPHA
	if not is_equal_approx(poop_ready_label.modulate.a, want_alpha):
		poop_ready_label.modulate.a = want_alpha


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
## spawns from the hit_scored event. (T-040) hit_scored carries points but not
## the target kind, so the kind word for the HUD combo strip is stashed here —
## the synchronous add_tourist_hit → hit_scored chain reads it right back.
func _on_tourist_splatted(tourist: Tourist) -> void:
	_last_hit_kind = "Tourist"
	_spawn_hit_marker(tourist) ## The ring marks WHICH body took the hit (T-040).
	Game.add_tourist_hit(tourist.global_position)


## Car splats feed the Game autoload's table (30 base — the cheap target,
## DESIGN pillar 3); the popup spawns from the hit_scored event. Same kind
## stash and marker as the tourist path (T-040).
func _on_car_splatted(car: Car) -> void:
	_last_hit_kind = "Car"
	_spawn_hit_marker(car) ## The ring marks WHICH body took the hit (T-040).
	Game.add_car_hit(car.global_position)


## The hit marker (T-040): a one-shot ring burst at the hit point, parented to
## the hit body (the poop.gd burst-parenting pattern) so it rides a moving
## tourist/car for its brief life; OneShotBurst frees it when it burns out.
func _spawn_hit_marker(target: Node3D) -> void:
	var marker: OneShotBurst = HIT_MARKER_SCENE.instantiate()
	target.add_child(marker)
	marker.global_transform = Transform3D(Basis.IDENTITY, target.global_position)


## Every scored hit gets a floating "+100 ×2" at the splat (T-009), a tiny
## camera shake on the pigeon's own handiwork (T-013) and the HUD pulse when
## the combo escalates (fired from _process). (T-040) It also composes the HUD
## combo strip — kind + points, " ×N" once chained — the "what/worth" line that
## outlives the world popup's short life on screen. The STYLE suffix is
## T-038's, once that lands.
func _on_hit_scored(points: int, multiplier: int, pos: Vector3, _style: bool) -> void:
	var popup: ScorePopup = SCORE_POPUP_SCENE.instantiate()
	popup.setup(points, multiplier, pos)
	add_child(popup)
	player.chase_camera.add_shake(hit_shake)
	combo_strip.text = "%s +%d" % [_last_hit_kind, points]
	if multiplier >= 2:
		combo_strip.text += " ×%d" % multiplier
	_combo_strip_left = combo_strip_seconds


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
	combo_strip.text = "" ## (T-040) A fresh run starts with no last hit on the strip.
	_combo_strip_left = 0.0
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

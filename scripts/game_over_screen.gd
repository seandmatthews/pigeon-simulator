class_name GameOverScreen
extends CanvasLayer
## The run-ending score screen. Opened by Main in one of two registers (T-115):
## starvation (T-010 — the hunger clock fired game_over) shows "STARVED!" over
## the scene's dark red wash, and victory shows "THE TOWN IS YOURS!" over a
## warm gold wash with a comedy line and the favor balance in the breakdown.
## Both registers carry the same contract: the final score, the persisted high
## score and the tourist-vs-car splat breakdown, then a frozen run (the same
## `get_tree().paused` contract as the pause menu). Space or R restarts
## through Main.restart_run(); M returns to the title screen. Runs in
## PROCESS_MODE_ALWAYS so it listens while the world is frozen. Each open
## writes EVERY mode-dependent property (title, dim, note, breakdown suffix),
## so the two registers can never leak into each other across restarts.

signal restart_requested
signal menu_requested

const STARVED_TITLE := "STARVED!"
const VICTORY_TITLE := "THE TOWN IS YOURS!"
## The starvation register's dark red wash — the scene's own Dim color
## (scenes/main.tscn), rewritten by open() so a victory screen can never
## leak into a later starvation screen across restarts in one session.
const STARVED_DIM := Color(0.12, 0.02, 0.02, 0.7)

## (T-115) The victory register's warm gold wash — tunable; Gate 3 judges.
@export var victory_dim: Color = Color(0.44, 0.32, 0.06, 0.65)

@onready var score_label: Label = %ScoreLabel
@onready var high_label: Label = %HighLabel
@onready var breakdown_label: Label = %BreakdownLabel
@onready var new_record_label: Label = %NewRecordLabel
@onready var title_label: Label = %Title
## (T-115) The victory note under the breakdown — shown only by open_victory.
@onready var victory_note: Label = %VictoryNote
## Direct child (no unique name — PauseMenu's sibling `Dim` would collide on
## the shared one).
@onready var dim_rect: ColorRect = $Dim

var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Opens the screen over a frozen run. `beaten` highlights a freshly raised
## record. The labels carry the numbers the sim harness asserts.
func open(score: int, high_score: int, tourist_hits: int, car_hits: int, beaten: bool) -> void:
	_open(score, high_score, tourist_hits, car_hits, beaten, false, 0)


## (T-115) Opens the screen in the victory register — the ceiling moment.
## `favor` (always the clamped `Game.favor_max` on a real win) joins the
## breakdown; the title, dim and note switch to the victory dressing. Same
## freeze contract as open().
func open_victory(score: int, high_score: int, tourist_hits: int, car_hits: int,
		favor: int, beaten: bool) -> void:
	_open(score, high_score, tourist_hits, car_hits, beaten, true, favor)


## The shared open core: both registers write EVERY mode-dependent property —
## neither relies on scene defaults — so no register leaks across restarts.
func _open(score: int, high_score: int, tourist_hits: int, car_hits: int,
		beaten: bool, victory: bool, favor: int) -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	score_label.text = "Score: %d" % score
	high_label.text = "High score: %d" % high_score
	title_label.text = VICTORY_TITLE if victory else STARVED_TITLE
	dim_rect.color = victory_dim if victory else STARVED_DIM
	victory_note.visible = victory
	if victory:
		breakdown_label.text = "Tourists splatted: %d    Cars splatted: %d    Favor: %d" % [
				tourist_hits, car_hits, favor]
	else:
		breakdown_label.text = "Tourists splatted: %d    Cars splatted: %d" % [
				tourist_hits, car_hits]
	new_record_label.visible = beaten
	var again := get_node_or_null("%AgainButton") as Button
	if again != null:
		again.grab_focus()


## Closes the screen; the caller owns the pause state (restart_run unpauses).
func close() -> void:
	is_open = false
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("flap") or event.is_action_pressed("restart"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("to_menu"):
		menu_requested.emit()
		get_viewport().set_input_as_handled()


## Button plumbing — the .tscn connections land here.
func _on_again_pressed() -> void:
	restart_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()

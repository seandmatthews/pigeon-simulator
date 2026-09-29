class_name GameOverScreen
extends CanvasLayer
## The starvation score screen (T-010). Opened by Main when the hunger clock
## fires game_over: shows the final score, the persisted high score and the
## tourist-vs-car splat breakdown, then freezes the run (same
## `get_tree().paused` contract as the pause menu). Space or R restarts
## through Main.restart_run(); M returns to the title screen. Runs in
## PROCESS_MODE_ALWAYS so it listens while the world is frozen.

signal restart_requested
signal menu_requested

@onready var score_label: Label = %ScoreLabel
@onready var high_label: Label = %HighLabel
@onready var breakdown_label: Label = %BreakdownLabel
@onready var new_record_label: Label = %NewRecordLabel

var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Opens the screen over a frozen run. `beaten` highlights a freshly raised
## record. The labels carry the numbers the sim harness asserts.
func open(score: int, high_score: int, tourist_hits: int, car_hits: int, beaten: bool) -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	score_label.text = "Score: %d" % score
	high_label.text = "High score: %d" % high_score
	breakdown_label.text = "Tourists splatted: %d    Cars splatted: %d" % [tourist_hits, car_hits]
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

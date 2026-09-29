extends Control
## Title screen (T-010): placeholder logo text, the persisted high score and
## "press Space to fly". Space (the `flap` action) starts a run in
## main.tscn — the same key that flaps, so the hand never moves. Q quits and
## Esc is an alias from the menu. Scene flow: menu.tscn ↔ main.tscn.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

@onready var high_score_label: Label = %HighScoreLabel


func _ready() -> void:
	## The record was loaded by the Game autoload at boot; a beaten-and-quit
	## session shows it here (T-009 persistence made visible).
	high_score_label.text = "High score: %d" % Game.high_score \
			if Game.high_score > 0 else "No high score yet — go be a menace"
	%FlyButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flap"):
		_start_run()
	elif event.is_action_pressed("pause") or event.is_action_pressed("quit"):
		get_tree().quit()


## The one way into the game — shared by the Space shortcut and the button.
func _start_run() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

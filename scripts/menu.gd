extends Control
## Title screen (T-010): placeholder logo text, the persisted high score and
## "press Space to fly". Space (the `flap` action) starts a run in
## main.tscn — the same key that flaps, so the hand never moves. Q quits.
## Esc does nothing here (T-097) — it is the in-run pause only.
## Scene flow: menu.tscn ↔ main.tscn.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

@onready var high_score_label: Label = %HighScoreLabel


func _ready() -> void:
	## The record was loaded by the Game autoload at boot; a beaten-and-quit
	## session shows it here (T-009 persistence made visible).
	high_score_label.text = "High score: %d" % Game.high_score \
			if Game.high_score > 0 else "No high score yet — go be a menace"
	%SettingsPanel.closed.connect(_close_settings) ## (T-122)
	## (T-126) The Q hint is a desktop affordance — strip it on the web.
	if Game.is_web():
		$Footer.text = $Footer.text.replace(" · Q quit", "")
	%FlyButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flap"):
		_start_run()
	elif event is InputEventJoypadButton and event.is_action_pressed("pause"):
		## (T-127) Pad Start is the Fly button. The joypad gate keeps the
		## keyboard's Esc (the same `pause` action) inert here — T-097.
		_start_run()
	elif event.is_action_pressed("quit") and not Game.is_web(): ## (T-126) Gated on web.
		get_tree().quit()


## (T-122) The title screen hosts the same settings panel as the pause menu.
func _on_settings_pressed() -> void:
	%SettingsPanel.visible = true


func _close_settings() -> void:
	%SettingsPanel.visible = false


## The one way into the game — shared by the Space shortcut and the button.
func _start_run() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

extends Control
## Title screen (T-010): placeholder logo text, the persisted high score and
## "press Space to fly". Space (the `flap` action) starts a run in
## main.tscn — the same key that flaps, so the hand never moves. Q quits.
## Esc does nothing here (T-097) — it is the in-run pause only.
## Scene flow: menu.tscn ↔ main.tscn.
## (T-129) The Fly press answers INSTANTLY: the "warming up the city" beat
## shows in the title's own navy, paints one frame, and only then does the
## scene hand off — main.tscn's stepped boot builds the world in slices behind
## the swap (and behind the web shell's loader) instead of stalling.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

@onready var high_score_label: Label = %HighScoreLabel
## The T-129 handoff beat — hidden at rest, shown for one painted frame between
## the Fly press and the scene swap.
@onready var warmup_note: Label = %WarmupNote

var _handing_off: bool = false ## One run handoff per press — guards the await frame against re-entry.


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
	_fade_web_loader() ## (T-129) The title's own half of the two-sided web contract.


## (T-129, leg 2) The web export shell's loader covered the whole engine boot;
## once THIS scene has painted its first warm frames the title is live, so the
## loader may fade out over it. The run-side half rides main.gd's
## `boot_finished` (and `_start_run` brings the loader back for the city
## warm-up). Desktop builds never reach the bridge.
func _fade_web_loader() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pigeonReady && window.pigeonReady();", true)


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
## (T-129) The beat paints before the handoff: show "warming up the city",
## yield one frame so it reaches the screen, then change scene — the press
## answered with visible feedback, not a frozen last frame. On the web the
## handoff also brings the export shell's loader back (the two-sided T-129
## contract: the loader covered the boot to this title and returns to cover
## the city warm-up until Main's `boot_finished` fades it over the world).
func _start_run() -> void:
	if _handing_off:
		return
	_handing_off = true
	warmup_note.visible = true
	await get_tree().process_frame
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pigeonLoading && window.pigeonLoading();", true)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

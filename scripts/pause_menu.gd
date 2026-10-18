class_name PauseMenu
extends CanvasLayer
## The Esc pause overlay (T-010). Freezes the whole tree via
## `get_tree().paused` — every pausable node (physics, hunger clock, spawners,
## popups) stops dead; this layer and the game-over screen run in
## PROCESS_MODE_ALWAYS so they can still listen. Offers resume / restart /
## menu / quit by key (Esc · R · M · Q) and by mouse button. `locked` is set
## by Main once the run is over — a dead run unpauses only through the score
## screen's restart, never by mashing Esc.

signal restart_requested
signal menu_requested
signal quit_requested

@export var locked: bool = false ## Set while the score screen owns the run — Esc refuses to unpause.

## Whether the overlay is up AND the tree is frozen — the sim harness asserts
## on the real thing (`get_tree().paused`), this mirrors it for the UI.
var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	## (T-122) The settings panel exists only in the full main.tscn scene —
	## bare script rigs (the sim harness builds one) carry no panel.
	var panel := get_node_or_null("%SettingsPanel")
	if panel != null:
		panel.closed.connect(_close_settings)
	## (T-126) No quit affordance on the web — a browser tab cannot close
	## itself, so the button would be a dead control.
	var quit_button := get_node_or_null("Center/PausePanel/Box/QuitButton")
	if quit_button != null and Game.is_web():
		quit_button.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		## (T-127) Pad B backs out of the open menu. Keyboard Esc never reaches
		## this branch — it is the `pause` action, handled (and consumed) above.
		toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart"):
		_request_restart()
	elif event.is_action_pressed("to_menu"):
		menu_requested.emit()
	elif event.is_action_pressed("quit") and not Game.is_web(): ## (T-126) Gated on web.
		quit_requested.emit()


## Flips the pause state — the one place `get_tree().paused` is written for
## pausing (the game-over screen owns its own pause). Public so the sim
## harness can drive the real script with synthetic input.
func toggle() -> void:
	if locked:
		return
	is_open = not is_open
	visible = is_open
	get_tree().paused = is_open
	if is_open:
		var resume := get_node_or_null("%ResumeButton") as Button
		if resume != null:
			resume.grab_focus()
	else:
		_close_settings() ## (T-122) Closing the menu closes the panel with it.


## (T-122) The settings panel — the button shows it, its `closed` signal and
## a menu close hide it. Nothing else here touches Game directly; the panel
## owns the write-through. All lookups are bare-rig tolerant (see _ready).
func _on_settings_pressed() -> void:
	var panel := get_node_or_null("%SettingsPanel")
	if panel != null:
		panel.visible = true


func _close_settings() -> void:
	var panel := get_node_or_null("%SettingsPanel")
	if panel != null:
		panel.visible = false


## Closes the overlay and unpauses without emitting anything — used by
## Main's restart path (restart_run unpauses the run itself).
func close() -> void:
	is_open = false
	visible = false


func _request_restart() -> void:
	close()
	restart_requested.emit()


## Button plumbing — the .tscn connections land here.
func _on_menu_pressed() -> void:
	menu_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()

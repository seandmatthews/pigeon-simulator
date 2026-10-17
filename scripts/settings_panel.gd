class_name SettingsPanel
extends PanelContainer
## The settings panel (T-122): invert pitch, the three bus volumes and a mute
## toggle, write-through to the Game autoload (which persists to
## user://settings.cfg). Hosted by the pause menu AND the title screen — the
## host only shows/hides the panel; every control talks straight to Game.
## Sliders and checkboxes are seeded with `*_no_signal` setters in _ready so
## syncing the UI never writes settings back.

## Emitted when the Back button is pressed — the host hides the panel.
signal closed


func _ready() -> void:
	%InvertPitch.set_pressed_no_signal(Game.invert_pitch)
	%MuteCheck.set_pressed_no_signal(Game.settings_muted)
	%MasterSlider.set_value_no_signal(Game.volume_master)
	%SfxSlider.set_value_no_signal(Game.volume_sfx)
	%AmbienceSlider.set_value_no_signal(Game.volume_ambience)
	%InvertPitch.toggled.connect(_on_invert_toggled)
	%MuteCheck.toggled.connect(_on_mute_toggled)
	%MasterSlider.value_changed.connect(_on_volume_changed.bind("Master"))
	%SfxSlider.value_changed.connect(_on_volume_changed.bind("SFX"))
	%AmbienceSlider.value_changed.connect(_on_volume_changed.bind("Ambience"))
	%SettingsBackButton.pressed.connect(func() -> void: closed.emit())


func _on_invert_toggled(on: bool) -> void:
	Game.invert_pitch = on
	Game.save_settings()


func _on_mute_toggled(on: bool) -> void:
	Game.settings_muted = on
	Game.apply_audio_settings()
	Game.save_settings()


func _on_volume_changed(value: float, bus: String) -> void:
	match bus:
		"Master":
			Game.volume_master = value
		"SFX":
			Game.volume_sfx = value
		"Ambience":
			Game.volume_ambience = value
	Game.apply_audio_settings()
	Game.save_settings()

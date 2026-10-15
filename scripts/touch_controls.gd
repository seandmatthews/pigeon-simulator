class_name TouchControls
extends CanvasLayer
## The touch layer (T-119): a virtual joystick and big Flap/Poop buttons for
## the phone, plus a small Pause button — the owner-directed scheme over tilt
## and drag-anywhere. Zero new InputMap actions: the joystick feeds the FOUR
## EXISTING steering actions with analog strength (`Input.action_press`),
## so the flight model polls exactly the axes the keyboard drives and never
## learns touch exists; Flap/Poop are TouchScreenButtons bound to the existing
## `flap`/`poop` actions (the player's polled `_flap`/`_try_poop` see them
## directly, multitouch included); the Pause button is an ordinary `Button`
## because a TouchScreenButton press would never reach `PauseMenu`'s
## `_unhandled_input` — it emits `pause_requested`, and main.tscn wires that
## to `PauseMenu.toggle()`.
##
## The layer shows only when touch is real (`DisplayServer.is_touchscreen_available()`),
## so the desktop stays keyboard-first and every pre-touch read of the game is
## untouched. Two deliberate rest guarantees live here: a released (or
## below-deadzone) stick presses NOTHING — `action_release` on all four
## steering actions, so they read exactly 0.0 and the T-082 hands-off trim arm
## (`absf(pitch_input) < 0.01`) keeps arming — and the stick's own touch
## deadzone is handled INSIDE the widget, before any action is fed.
##
## Desktop debugging: set the `force_show` export, or launch with
## `PIGEON_TOUCH=1` (which also enables touch-from-mouse emulation so a real
## mouse drives the whole layer — see the README controls table).

## Emitted when the Pause button is tapped — main.tscn connects this to the
## real PauseMenu's `toggle()` (an ordinary Button reaches the menu through a
## signal; an action press would not reach `_unhandled_input`).
signal pause_requested

@export_group("Layout")
@export var edge_margin: float = 28.0 ## Distance (canvas px) every widget keeps from its safe-area edge.
@export var stick_radius: float = 62.0 ## Stick deflection (canvas px, from base center) that reads full strength.
@export var stick_touch_deadzone: float = 0.18 ## Fraction of `stick_radius` treated as finger jitter — handled INSIDE the stick so the actions rest at exactly 0. Output past the deadzone is rescaled to the full 0..1 strength band (see Tuned values, T-119).
@export var button_gap: float = 18.0 ## Gap (canvas px) between the Flap and Poop buttons' rings.

@export_group("Debug")
@export var force_show: bool = false ## Show the layer without a touchscreen (editor/sim debugging; `PIGEON_TOUCH=1` also enables touch-from-mouse).

@onready var safe_area: Control = $SafeArea
@onready var stick_base: Control = $SafeArea/StickBase
@onready var stick_ring: Polygon2D = $SafeArea/StickBase/StickRing
@onready var stick_knob: Control = $SafeArea/StickBase/Knob
@onready var knob_ring: Polygon2D = $SafeArea/StickBase/Knob/KnobRing
@onready var flap_button: TouchScreenButton = $SafeArea/FlapButton
@onready var flap_visual: Polygon2D = $SafeArea/FlapButton/FlapVisual
@onready var flap_label: Label = $SafeArea/FlapButton/FlapLabel
@onready var poop_button: TouchScreenButton = $SafeArea/PoopButton
@onready var poop_visual: Polygon2D = $SafeArea/PoopButton/PoopVisual
@onready var poop_label: Label = $SafeArea/PoopButton/PoopLabel
@onready var pause_button: Button = $SafeArea/PauseButton

## The touch index currently driving the stick, or -1 when no finger holds it.
## Per-index tracking is what makes the multitouch contract work: a second
## finger landing on Flap never touches the stick's state, and drags of the
## stick's index keep arriving even when the finger leaves the base control
## (the viewport keeps delivering them to the touch's captured control).
var _stick_touch: int = -1

var _forced: bool = false ## The resolved force flag (export OR the env recipe).


func _ready() -> void:
	_forced = force_show or OS.get_environment("PIGEON_TOUCH") == "1"
	if OS.get_environment("PIGEON_TOUCH") == "1":
		Input.emulate_touch_from_mouse = true ## The desktop try-it recipe: a real mouse drives the layer.
	visible = _forced or DisplayServer.is_touchscreen_available()
	_build_visuals()
	_layout()
	get_viewport().size_changed.connect(_layout)
	stick_base.gui_input.connect(_on_stick_gui_input)


func _exit_tree() -> void:
	## A freed layer must never leave strength behind on the shared Input
	## actions — later scenarios (and a later run) read the same singleton.
	_release_axes()
	_stick_touch = -1


## Builds the two ring visuals (the stick base and its knob) and the button
## circles. Polygons are generated, not hand-computed into the .tscn — the
## scene files stay free of baked vertex lists (the Sun rotation pattern). The
## ring nodes are centered on their parents' origins; the button visuals sit
## on the TouchScreenButton origin, which is already its circle's center.
func _build_visuals() -> void:
	stick_ring.position = stick_base.size * 0.5
	stick_ring.polygon = _circle_points(_safe_ring_radius())
	knob_ring.position = stick_knob.size * 0.5
	knob_ring.polygon = _circle_points(stick_knob.size.x * 0.5)
	flap_visual.polygon = _circle_points(_button_radius(flap_button))
	poop_visual.polygon = _circle_points(_button_radius(poop_button))
	_center_label(flap_label)
	_center_label(poop_label)


## Lays every widget out against the display safe area (T-119): the stick hugs
## the bottom-left corner, Flap/Poop the bottom-right, Pause the top-right —
## nothing sits under the notch or the home indicator in landscape. On desktop
## the safe area is the whole window, so the insets are all zero and this
## produces the same rect as the raw canvas — the layout is byte-identical.
func _layout() -> void:
	var canvas := get_viewport().get_visible_rect().size
	var safe := canvas_safe_rect(get_viewport())
	var inset_left := maxf(safe.position.x, 0.0)
	var inset_top := maxf(safe.position.y, 0.0)
	var inset_right := maxf(canvas.x - safe.end.x, 0.0)
	var inset_bottom := maxf(canvas.y - safe.end.y, 0.0)
	safe_area.offset_left = inset_left
	safe_area.offset_top = inset_top
	safe_area.offset_right = -inset_right
	safe_area.offset_bottom = -inset_bottom
	var inner: Vector2 = safe_area.size ## The safe rect the widgets live in.
	var m := edge_margin
	stick_base.position = Vector2(m, inner.y - m - stick_base.size.y)
	var flap_center := Vector2(inner.x - m - _button_radius(flap_button),
			inner.y - m - _button_radius(flap_button))
	flap_button.position = flap_center
	poop_button.position = flap_center + Vector2(
			-(_button_radius(flap_button) + button_gap + _button_radius(poop_button)),
			-button_gap)
	pause_button.position = Vector2(inner.x - m - pause_button.size.x, m)


## The display safe area in the canvas coordinates this layer lays out in.
## `DisplayServer` reports window pixels; the viewport's final transform maps
## them onto the stretched canvas. Where the display server knows nothing
## (headless, plain desktop windows) it reports an empty rect and the whole
## canvas is safe — every inset comes out zero.
static func canvas_safe_rect(viewport: Viewport) -> Rect2:
	var canvas := viewport.get_visible_rect()
	var area := DisplayServer.get_display_safe_area()
	if area.size.x <= 0 or area.size.y <= 0:
		return canvas ## No safe-area information: the whole canvas is the safe rect.
	var to_canvas := viewport.get_final_transform().affine_inverse()
	var top_left := to_canvas * Vector2(area.position)
	var bottom_right := to_canvas * (Vector2(area.position) + Vector2(area.size))
	var mapped := Rect2(top_left, bottom_right - top_left).abs()
	var clipped := mapped.intersection(canvas)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else canvas


## The stick's touch handling: capture the first finger that lands on the base,
## follow only that finger's drags (per-index — the multitouch contract), and
## release everything the moment it lifts. Touches and drags arrive here
## through the viewport's GUI routing, in the base's local coordinates.
func _on_stick_gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _stick_touch == -1:
			_stick_touch = touch.index
			_apply_stick(touch.position)
		elif not touch.pressed and touch.index == _stick_touch:
			_stick_touch = -1
			_apply_stick(stick_base.size * 0.5) ## Back to center: nothing pressed.
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _stick_touch:
		_apply_stick(drag.position)


## Drives the knob visual and the four steering actions from a stick contact
## position (local to the base). Below the touch deadzone the axis pair is
## RELEASED — never pressed with a small strength — so the polled reads stay
## exactly 0.0 and the hands-off trim keeps arming (the T-119 trap).
func _apply_stick(local_pos: Vector2) -> void:
	var center := stick_base.size * 0.5
	var offset := local_pos - center
	var deflection := offset.limit_length(stick_radius)
	stick_knob.position = center + deflection - stick_knob.size * 0.5
	var magnitude := offset.length() / stick_radius
	if _stick_touch == -1 or magnitude <= stick_touch_deadzone:
		_release_axes()
		return
	## Rescale past the deadzone so the thumb's usable band maps onto the full
	## 0..1 strength the flight model expects (T-119 Tuned values).
	var scaled := clampf(
			(magnitude - stick_touch_deadzone) / (1.0 - stick_touch_deadzone), 0.0, 1.0)
	var direction := offset / offset.length()
	## Pushing LEFT (−x) is turn_left, DOWN (+y) is pitch_down — the same
	## screen directions the WASD keys already mean (W = pitch up).
	_feed_axis("turn_left", "turn_right", direction.x * scaled)
	_feed_axis("pitch_up", "pitch_down", direction.y * scaled)


## Feeds one analog axis pair: value > 0 presses the positive action, value < 0
## the negative one, and 0 (or below-deadzone) releases BOTH — an axis pair is
## never left half-pressed. The probed fact this leans on: `Input.action_press`
## strength bypasses the InputMap deadzone (0.2 reads 0.2), so this value IS
## what `Input.get_axis` hands the player.
func _feed_axis(negative_action: String, positive_action: String, value: float) -> void:
	if value > 0.0:
		Input.action_release(negative_action)
		Input.action_press(positive_action, value)
	elif value < 0.0:
		Input.action_release(positive_action)
		Input.action_press(negative_action, -value)
	else:
		Input.action_release(negative_action)
		Input.action_release(positive_action)


## Releases all four steering actions — the at-rest contract (exactly 0.0 on
## every axis, the T-082 trim arm keeps arming).
func _release_axes() -> void:
	Input.action_release("turn_left")
	Input.action_release("turn_right")
	Input.action_release("pitch_up")
	Input.action_release("pitch_down")


## The Pause button's relay (wired by the sub-scene connection): the layer is
## generic; main.tscn connects `pause_requested` to the real PauseMenu.
func _on_pause_pressed() -> void:
	pause_requested.emit()


## The stick ring's visual radius — kept just inside the base control so the
## knob never draws past it.
func _safe_ring_radius() -> float:
	return minf(stick_base.size.x, stick_base.size.y) * 0.5 - 4.0


## A TouchScreenButton's reach radius, read back from its own shape — one
## source of truth for both the hit test and the drawn circle.
func _button_radius(button: TouchScreenButton) -> float:
	var circle := button.shape as CircleShape2D
	return circle.radius if circle != null else 48.0


func _center_label(label: Label) -> void:
	label.reset_size()
	label.position = -label.size * 0.5


func _circle_points(radius: float, segments: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points

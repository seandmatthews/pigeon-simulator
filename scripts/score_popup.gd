class_name ScorePopup
extends Node3D
## Floating "+100 ×2" score popup (T-009): a billboarded world-space Label3D
## spawned at the splat when the Game autoload fires hit_scored (Main
## instantiates it — the autoload stays presentation-free). It floats up a
## little, fades out and frees itself. setup() must run BEFORE add_child so
## the float tween starts from the hit position, not the origin.
## (T-038) A styled hit — the fast/low dive bonus — appends a " STYLE" tag and
## tints the label the HUD pulse gold, so every popup on screen decomposes into
## base × combo + style.

## The HUD pulse gold (`_pulse_score`'s flash color in main.gd) — a styled
## popup wears the same "special payout" language (T-038).
const STYLE_COLOR := Color(1.0, 0.85, 0.3)

@export var lifetime: float = 1.2 ## Seconds from spawn to gone.
@export var rise_height: float = 1.8 ## How far up it drifts over its lifetime (m).

## The text node — public so the sim harness can assert what it shows.
@onready var label: Label3D = %Text

var _points: int = 0
var _multiplier: int = 1
var _pos: Vector3 = Vector3.ZERO
var _style: bool = false ## (T-038) The fast/low dive bonus applied to this hit.


## "+100" or "+100 ×2" — the ticket's popup format; static so tests can
## assert it without instancing the 3D node. (T-038) The style flag appends
## the STYLE tag in both multiplier shapes: "+150 STYLE" / "+150 ×2 STYLE";
## unstyled output stays byte-identical.
static func format_text(points: int, multiplier: int, style: bool = false) -> String:
	var tag := " STYLE" if style else ""
	if multiplier > 1:
		return "+%d ×%d%s" % [points, multiplier, tag]
	return "+%d%s" % [points, tag]


## Stores the payload; _ready applies it and runs the float+fade tween.
func setup(points: int, multiplier: int, pos: Vector3, style: bool = false) -> void:
	_points = points
	_multiplier = multiplier
	_pos = pos
	_style = style


func _ready() -> void:
	add_to_group("score_popups") ## The restart flow (T-010) clears popups mid-float.
	global_position = _pos
	label.text = format_text(_points, _multiplier, _style)
	if _style:
		## (T-038) Tint the RGB only — the fade below owns the alpha channel.
		label.modulate = STYLE_COLOR
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", _pos + Vector3.UP * rise_height, lifetime)
	# The fade owns the back stretch — the number stays solid while it reads.
	tween.tween_property(label, "modulate:a", 0.0, lifetime * 0.6).set_delay(lifetime * 0.4)
	tween.chain().tween_callback(queue_free)

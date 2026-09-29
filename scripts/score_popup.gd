class_name ScorePopup
extends Node3D
## Floating "+100 ×2" score popup (T-009): a billboarded world-space Label3D
## spawned at the splat when the Game autoload fires hit_scored (Main
## instantiates it — the autoload stays presentation-free). It floats up a
## little, fades out and frees itself. setup() must run BEFORE add_child so
## the float tween starts from the hit position, not the origin.

@export var lifetime: float = 1.2 ## Seconds from spawn to gone.
@export var rise_height: float = 1.8 ## How far up it drifts over its lifetime (m).

## The text node — public so the sim harness can assert what it shows.
@onready var label: Label3D = %Text

var _points: int = 0
var _multiplier: int = 1
var _pos: Vector3 = Vector3.ZERO


## "+100" or "+100 ×2" — the ticket's popup format; static so tests can
## assert it without instancing the 3D node.
static func format_text(points: int, multiplier: int) -> String:
	if multiplier > 1:
		return "+%d ×%d" % [points, multiplier]
	return "+%d" % points


## Stores the payload; _ready applies it and runs the float+fade tween.
func setup(points: int, multiplier: int, pos: Vector3) -> void:
	_points = points
	_multiplier = multiplier
	_pos = pos


func _ready() -> void:
	global_position = _pos
	label.text = format_text(_points, _multiplier)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", _pos + Vector3.UP * rise_height, lifetime)
	# The fade owns the back stretch — the number stays solid while it reads.
	tween.tween_property(label, "modulate:a", 0.0, lifetime * 0.6).set_delay(lifetime * 0.4)
	tween.chain().tween_callback(queue_free)

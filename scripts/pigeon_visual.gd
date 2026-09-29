class_name PigeonVisual
extends Node3D
## The low-poly pigeon presentation (T-011), hand-built from primitives in
## `scenes/pigeon_visual.tscn` — gray body, darker wingtips and tail, green
## metallic neck sheen, orange feet. The player's flight state machine drives
## it through `drive()` every physics frame: the pose always mirrors the
## physics state (GLIDE wings-out / DIVE wings-swept in the air, WADDLE /
## STAND folded on the ground), so picture and model cannot desync for long.
## Two timed overlays ride on top of the base pose: the flap beat, triggered
## on every real flap impulse, and the comedic head-slam peck, triggered when
## a crumb is eaten. All tunables are @export for live tweaking.

## The base poses — which one is active follows the player's state machine.
enum Pose { GLIDE, DIVE, WADDLE, STAND }

@export_group("Waddle")
@export var grounded_squat: float = 0.82 ## Root Y scale while grounded — readable "I'm walking now" pose.
@export var waddle_bob_rate: float = 10.0 ## Bob cycles per second while waddling.
@export var waddle_bob_height: float = 0.03 ## Vertical bob amplitude (m).
@export var waddle_sway: float = 0.1 ## Cosmetic roll amplitude of the waddle bob (rad).
@export var head_thrust: float = 0.05 ## Forward head-thrust amplitude while waddling (m) — the pigeon head-bob.

@export_group("Wing poses")
@export var glide_lift: float = 0.14 ## Wing dihedral (rad above horizontal) in the glide pose.
@export var dive_lift: float = 0.05 ## Wing lift while diving — near the body plane.
@export var folded_lift: float = -0.08 ## Wing lift when folded on the ground (tucked along the flanks).
@export var glide_sweep: float = 0.0 ## Wing sweep-back (rad) in the glide pose.
@export var dive_sweep: float = 1.0 ## Wing sweep-back while diving — wings pinned, dive pose.
@export var folded_sweep: float = 1.3 ## Wing sweep-back when folded on the ground.
@export var pose_lerp_rate: float = 9.0 ## 1/s the wing joints ease toward the pose targets.

@export_group("Flap beat")
@export var flap_beat_seconds: float = 0.32 ## Length of one wing beat — mirrors the flap pacing feel.
@export var flap_lift_amplitude: float = 0.95 ## Wing lift swing (rad) at the middle of a beat.

@export_group("Peck")
@export var peck_seconds: float = 0.4 ## Length of the whole peck (down and back up).
@export var peck_angle: float = 1.9 ## How far the head dives down (rad) at the peck's bottom.
@export var peck_body_pitch: float = 0.22 ## Forward body lean (rad) at the peck's bottom.
@export var peck_head_lunge: float = 0.06 ## Forward head lunge (m) at the peck's bottom.

@export_group("Idle")
@export var idle_head_bob: float = 0.012 ## Standing head-bob amplitude (m) — a pigeon never sits still.
@export var idle_head_rate: float = 2.2 ## Standing head-bob cycles per second.

## The pose currently mirrored from the flight state machine.
var pose: Pose = Pose.GLIDE

## True while a flap beat overlay is playing.
var flap_beating: bool:
	get: return _flap_left > 0.0


## True while a peck overlay is playing.
var pecking: bool:
	get: return _peck_left > 0.0


## Smoothed wing lift angle (rad) — the pose read the sim harness asserts on.
var wing_lift: float:
	get: return _lift


## Smoothed wing sweep-back angle (rad) — the pose read the sim harness asserts on.
var wing_sweep: float:
	get: return _sweep


## Current head pitch (rad; negative = beak toward the ground).
var head_pitch: float:
	get: return _head.rotation.x if _head != null else 0.0

var _lift: float = 0.0
var _sweep: float = 0.0
var _flap_left: float = 0.0
var _peck_left: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _head_base_z: float = -0.24 ## Matches HeadPivot's scene position; re-read in _ready().

@onready var _head: Node3D = $HeadPivot
@onready var _wing_l: Node3D = $WingL
@onready var _wing_r: Node3D = $WingR


func _ready() -> void:
	## Static rigging the scene file keeps rotation-free (repo convention):
	## the cone beak points forward, the tail fans up, the wingtips sweep back.
	$HeadPivot/Beak.rotation.x = -PI / 2.0
	$Tail.rotation.x = -0.16 ## Tail tips up (a +Z-backward mesh pitches down under +X rotation).
	$WingL/Tip.rotation.y = 0.3
	$WingR/Tip.rotation.y = -0.3
	_head_base_z = _head.position.z


## Mirror the flight state machine (called by the player every physics frame):
## picks the base pose from the grounded/moving/diving flags, eases the wing
## joints toward its targets and plays the ground cosmetics — the waddle bob,
## sway and squat, the head-thrust bob and the idle head-bob.
func drive(grounded: bool, moving: bool, diving: bool, delta: float) -> void:
	_time += delta
	pose = Pose.WADDLE if grounded and moving else (Pose.STAND if grounded else (Pose.DIVE if diving else Pose.GLIDE))
	var lift_target := 0.0
	var sweep_target := 0.0
	match pose:
		Pose.DIVE:
			lift_target = dive_lift
			sweep_target = dive_sweep
		Pose.WADDLE, Pose.STAND:
			lift_target = folded_lift
			sweep_target = folded_sweep
		_:
			lift_target = glide_lift
			sweep_target = glide_sweep
	var k := 1.0 - exp(-pose_lerp_rate * delta)
	_lift = lerpf(_lift, lift_target, k)
	_sweep = lerpf(_sweep, sweep_target, k)

	_flap_left = maxf(_flap_left - delta, 0.0)
	_peck_left = maxf(_peck_left - delta, 0.0)
	var flap_add := 0.0
	if _flap_left > 0.0:
		var beat := 1.0 - _flap_left / flap_beat_seconds ## 0 → 1 over the beat.
		flap_add = sin(beat * TAU) * flap_lift_amplitude
	var peck := 0.0
	if _peck_left > 0.0:
		peck = sin(PI * (1.0 - _peck_left / peck_seconds)) ## Smooth down-and-back envelope.

	## Wing joints. Left extends along −X, right along +X — mirrored signs.
	var lift := _lift + flap_add
	_wing_l.rotation.z = -lift
	_wing_r.rotation.z = lift
	_wing_l.rotation.y = _sweep
	_wing_r.rotation.y = -_sweep

	## Root cosmetics (moved verbatim from player.gd's old sphere handling):
	## the grounded squat, the waddle bob + sway, the peck's forward lean.
	scale.y = lerpf(scale.y, grounded_squat if grounded else 1.0, k)
	rotation.x = lerpf(rotation.x, -peck * peck_body_pitch, k)
	if grounded and moving:
		_phase += waddle_bob_rate * delta
		position.y = waddle_bob_height * sin(_phase)
		rotation.z = waddle_sway * sin(_phase)
	else:
		position.y = lerpf(position.y, 0.0, k)
		rotation.z = lerpf(rotation.z, 0.0, k)

	## The head: thrust-bobs while waddling (the pigeon head-bob), idles with a
	## slow bob while standing, lunges down and forward for the peck.
	var head_fwd := 0.0
	if grounded and moving:
		head_fwd = head_thrust * maxf(sin(_phase), 0.0)
	elif grounded:
		head_fwd = idle_head_bob * sin(_time * idle_head_rate)
	_head.position.z = _head_base_z - head_fwd - peck * peck_head_lunge
	_head.rotation.x = lerpf(_head.rotation.x, -peck * peck_angle,
			1.0 - exp(-25.0 * delta))


## Plays one wing beat — the player fires this on every real flap impulse.
func trigger_flap() -> void:
	_flap_left = flap_beat_seconds


## Plays the peck — Main wires the bread service's crumb_eaten relay to it.
func trigger_peck() -> void:
	_peck_left = peck_seconds


## Hard-resets the whole presentation (flight reset, restart flow): base pose,
## overlays, joint angles, root cosmetics and the head rig.
func reset_pose() -> void:
	pose = Pose.GLIDE
	_lift = glide_lift
	_sweep = glide_sweep
	_flap_left = 0.0
	_peck_left = 0.0
	_phase = 0.0
	_time = 0.0
	scale = Vector3.ONE
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	if _head != null:
		_head.rotation = Vector3.ZERO
		_head.position.z = _head_base_z

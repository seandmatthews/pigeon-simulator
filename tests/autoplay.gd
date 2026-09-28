extends Node3D
## Autoplay smoke test (VERIFICATION.md Gate 2): boots the REAL game
## (scenes/main.tscn) and plays it with a scripted pilot for ~30 seconds,
## saving a screenshot every 5 s to .godot/autoplay/. Exits 0 when the run
## completes with the pigeon alive and finite; the caller greps the output for
## SCRIPT ERROR lines. Run windowed so it renders for real:
##   godot --path . res://tests/autoplay.tscn
## Note: when T-010 adds the game-over flow this driver must learn to restart
## from the score screen.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const RUN_SECONDS: float = 30.0
const SHOT_INTERVAL: float = 5.0

var _game: Node
var _player: Player
var _elapsed: float = 0.0
var _next_shot: float = 1.0
var _shot_dir: String = ""


func _ready() -> void:
	_shot_dir = ProjectSettings.globalize_path("res://.godot/autoplay")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	_game = MAIN_SCENE.instantiate()
	add_child(_game)
	_player = _game.get_node("Player") as Player


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_drive(_elapsed, delta)
	if _elapsed >= _next_shot:
		_next_shot += SHOT_INTERVAL
		_capture(int(_elapsed))
	if _elapsed >= RUN_SECONDS:
		var alive: bool = _player != null and is_instance_valid(_player) \
				and _player.velocity.is_finite() and _player.position.y > -10.0
		var where: Vector3 = _player.position if _player != null and is_instance_valid(_player) else Vector3.ZERO
		print("AUTOPLAY DONE ok=%s t=%.1f player=(%.1f, %.1f, %.1f) speed=%.2f" % [
				alive, _elapsed, where.x, where.y, where.z, _player.velocity.length() if alive else 0.0])
		get_tree().quit(0 if alive else 1)


## A repeating flight pattern: flap-climb, bank, a short dive pulse, pull up,
## glide and drop the occasional poop (inert until T-006 wires it up). Safety
## reflexes keep it alive: below 5 m and descending it pulls up and flaps, and
## beyond 40 m from the origin it steers home — so it never leaves the finite
## placeholder ground.
func _drive(t: float, delta: float) -> void:
	for action in ["flap", "poop", "turn_left", "turn_right", "pitch_up", "pitch_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)

	if _player.position.y < 5.0 and _player.velocity.y < -2.0:
		Input.action_press("pitch_up")
		if fmod(t, 0.4) < delta:
			Input.action_press("flap")
		return

	var flat := Vector2(_player.position.x, _player.position.z)
	if flat.length() > 40.0:
		var to_origin := -flat.normalized()
		var fwd := Vector2(-_player.transform.basis.z.x, -_player.transform.basis.z.z)
		if fwd.cross(to_origin) < 0.0:
			Input.action_press("turn_left")
		else:
			Input.action_press("turn_right")
		if fmod(t, 0.5) < delta:
			Input.action_press("flap")
		return

	var phase := fmod(t, 15.0)
	# Alternate the bank each loop so the pigeon zigzags while near the middle.
	var turn := "turn_left" if int(t / 15.0) % 2 == 0 else "turn_right"
	if phase < 5.0:
		if fmod(t, 0.5) < delta:
			Input.action_press("flap")
	elif phase < 7.0:
		Input.action_press(turn)
	elif phase < 7.6:
		Input.action_press("pitch_down")
	elif phase < 9.1:
		Input.action_press("pitch_up")
	else:
		if fmod(t, 2.0) < delta:
			Input.action_press("poop")


func _capture(at_seconds: int) -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/shot-%03ds.png" % [_shot_dir, at_seconds])

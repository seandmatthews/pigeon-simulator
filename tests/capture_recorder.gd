extends Node
## In-process run recorder for agent-driven playtesting (verification tooling,
## not gameplay). Inert unless `res://.captures/record.flag` exists when the
## game launches: then every play session gets its own folder under
## `.captures/` holding a JPEG stream (~10 Hz) plus a per-physics-frame JSONL
## state dump and an events JSONL, so a run can be replayed and reviewed
## offline without hammering the MCP screenshot tool (which wedges after game
## events). Enable by creating the flag file; first line may hold a custom
## image interval in seconds.

const FLAG_PATH := "res://.captures/record.flag"
const PILOT_DIR := "res://.captures"
const DEFAULT_IMAGE_INTERVAL := 0.1
const CRUMB_LIMIT := 15

var _dir: String = ""
var _state_file: FileAccess
var _events_file: FileAccess
var _image_interval: float = DEFAULT_IMAGE_INTERVAL
var _frame: int = 0
var _connected: Dictionary = {}
var _holds: Dictionary = {}

@onready var _image_timer := Timer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not FileAccess.file_exists(FLAG_PATH):
		return
	if FileAccess.file_exists("res://.captures/mute.flag"):
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var interval_text := FileAccess.get_file_as_string(FLAG_PATH).strip_edges()
	if interval_text.is_valid_float() and interval_text.to_float() > 0.0:
		_image_interval = interval_text.to_float()
	var stamp := Time.get_datetime_string_from_system(true)
	stamp = stamp.replace(":", "").replace("-", "").replace("T", "_")
	_dir = "res://.captures/run_%s" % stamp
	var global_dir := ProjectSettings.globalize_path(_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)
	_state_file = FileAccess.open(_dir + "/state.jsonl", FileAccess.WRITE)
	_events_file = FileAccess.open(_dir + "/events.jsonl", FileAccess.WRITE)
	_log_event("run_start", {"image_interval": _image_interval, "dir": _dir})
	_image_timer.wait_time = _image_interval
	_image_timer.timeout.connect(_save_image)
	add_child(_image_timer)
	_image_timer.start()


func _physics_process(_delta: float) -> void:
	if _state_file == null:
		return
	_pilot_step()
	_frame += 1
	_state_file.store_line(JSON.stringify(_snapshot()))
	if _frame % 30 == 0:
		_state_file.flush()
		_events_file.flush()


## Pilot channel: an external driver drops one-shot command files named
## `pilot_cmd_*.jsonl` into `.captures/` (atomic new files — a live process
## appending to one file is never seen until exit on Windows, so appends are
## out). The game executes each file oldest-first and deletes it as the ack.
## Command formats: {"action": "flap", "frames": 7} (hold N physics frames),
## {"key": "Space", "frames": 2} (a real InputEventKey for menu screens),
## {"quit": true}. Holds can overlap.
func _pilot_step() -> void:
	var dir := DirAccess.open("res://.captures")
	if dir == null:
		return
	var names := dir.get_files_at("res://.captures")
	var cmds: PackedStringArray = PackedStringArray()
	for fname in names:
		if fname.begins_with("pilot_cmd_") and fname.ends_with(".jsonl"):
			cmds.append(fname)
	cmds.sort()
	for fname in cmds:
		var text := FileAccess.get_file_as_string("res://.captures/" + fname)
		for line in text.split("\n"):
			if line.is_empty():
				continue
			var cmd: Variant = JSON.parse_string(line)
			if typeof(cmd) != TYPE_DICTIONARY:
				continue
			if cmd.get("quit", false):
				_log_event("pilot_quit", {})
				_state_file.flush()
				get_tree().quit()
				return
			var frames := int(cmd.get("frames", 1))
			if cmd.has("key"):
				var key_name := String(cmd["key"])
				var keycode := OS.find_keycode_from_string(key_name)
				if keycode == KEY_NONE:
					_log_event("pilot_bad_key", {"key": key_name})
					continue
				_send_key(keycode, true)
				_holds["key:%s" % key_name] = {"frames": frames, "keycode": keycode}
				_log_event("pilot_key", {"key": key_name, "frames": frames})
			else:
				var action := String(cmd.get("action", ""))
				if action != "" and frames > 0:
					Input.action_press(action)
					_holds["action:%s" % action] = {"frames": frames, "keycode": 0}
					_log_event("pilot_press", {"action": action, "frames": frames})
		dir.remove(fname)
	for name_key in _holds.keys():
		var hold: Dictionary = _holds[name_key]
		var left := int(hold["frames"]) - 1
		if left <= 0:
			if int(hold["keycode"]) != 0:
				_send_key(int(hold["keycode"]), false)
			else:
				Input.action_release(String(name_key).trim_prefix("action:"))
			_holds.erase(name_key)
		else:
			hold["frames"] = left


## A real key event through the input pipeline — reaches _unhandled_input
## handlers (menus) and updates action state via the InputMap, unlike
## Input.action_press which only feeds polling code.
func _send_key(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	ev.physical_keycode = keycode as Key
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _state_file != null:
			_state_file.flush()
		if _events_file != null:
			_events_file.flush()


## One JSONL line of world state. Positions are absolute; consumers compute
## distances themselves so nothing here depends on what the player is near.
func _snapshot() -> Dictionary:
	var tree := get_tree()
	var player := _find_player() as Node3D
	var hunger_node := tree.root.get_node_or_null("Game/Hunger")
	var game := tree.root.get_node_or_null("Game")
	var out := {
		"t_ms": Time.get_ticks_msec(),
		"frame": _frame,
		"scene": String(tree.current_scene.name) if tree.current_scene != null else "",
	}
	if player != null:
		var yaw_wrapped := wrapf(player.rotation.y, -PI, PI)
		var pitch_wrapped := wrapf(player.rotation.x, -PI, PI)
		out["player"] = {
			"p": _v(player.global_position),
			"yaw": snappedf(yaw_wrapped, 0.01),
			"pitch": snappedf(pitch_wrapped, 0.01),
			"vel": _v((player as CharacterBody3D).velocity),
			"fwd": snappedf(player.get("forward_speed"), 0.01),
			"grounded": player.get("state") == 1,
			"stalled": player.get("stalled"),
		}
		out["poops"] = _collect_poops(player)
	if hunger_node != null:
		out["hunger"] = snappedf(hunger_node.get("value"), 0.01)
	if game != null:
		out["score"] = game.get("score")
		out["streak"] = game.get("_streak")
	out["tourists"] = _collect_children(_spawner("TouristSpawner"))
	out["cars"] = _collect_children(_spawner("CarSpawner"))
	if player != null:
		out["crumbs"] = _nearest_crumbs(player.global_position)
	_ensure_connections(player)
	return out


## Works both for a normal run (current scene IS Main) and the autoplay
## harness (Main instantiated under the autoplay scene root).
func _find_player() -> Node:
	var tree := get_tree()
	for path in ["Main/Player", "Player"]:
		var node := tree.current_scene.get_node_or_null(path)
		if node != null:
			return node
	return null


func _spawner(node_name: String) -> Node:
	var tree := get_tree()
	for path in ["Main/%s" % node_name, node_name]:
		var node := tree.current_scene.get_node_or_null(path)
		if node != null:
			return node
	return null


func _v(p: Vector3) -> Array:
	return [
		snappedf(p.x, 0.01),
		snappedf(p.y, 0.01),
		snappedf(p.z, 0.01),
	]


func _collect_children(spawner: Node) -> Array:
	var list: Array = []
	if spawner == null:
		return list
	for child in spawner.get_children():
		if child is Node3D:
			list.append(_v(child.global_position))
	return list


func _collect_poops(player: Node) -> Array:
	var list: Array = []
	for child in player.get_children():
		if child.get_script() != null and String(child.get_script().resource_path).ends_with("poop.gd"):
			list.append(_v((child as Node3D).global_position))
	return list


func _nearest_crumbs(centre: Vector3) -> Array:
	var spawner := _spawner("BreadSpawner")
	var entries: Array = []
	if spawner == null:
		return entries
	for crumb in spawner.get_children():
		if crumb is Node3D and not crumb.get("_consumed"):
			entries.append([centre.distance_squared_to(crumb.global_position), crumb])
	entries.sort_custom(func(a, b): return a[0] < b[0])
	var list: Array = []
	for i in mini(CRUMB_LIMIT, entries.size()):
		list.append(_v((entries[i][1] as Node3D).global_position))
	return list


## Wire event signals the first time each node shows up (scene changes between
## menu, main and the game-over screen, so this runs until everything sticks).
func _ensure_connections(player: Node) -> void:
	if player != null:
		_connect_once(player, "flapped", func(): _log_event("flap", {}))
		_connect_once(player, "pooped", func(p): _log_event("poop", {"p": _v((p as Node3D).global_position)}))
		_connect_once(player, "grounding_changed", func(g): _log_event("grounded" if g else "airborne", {}))
	var hunger := get_tree().root.get_node_or_null("Game/Hunger")
	if hunger != null:
		_connect_once(hunger, "game_over", func(): _log_event("game_over", {}))
	var tourist_spawner := _spawner("TouristSpawner")
	if tourist_spawner != null:
		_connect_once(tourist_spawner, "tourist_splatted", func(t):
			_log_event("tourist_splatted", {"p": _v((t as Node3D).global_position)}))
	var car_spawner := _spawner("CarSpawner")
	if car_spawner != null:
		_connect_once(car_spawner, "car_splatted", func(c):
			_log_event("car_splatted", {"p": _v((c as Node3D).global_position)}))
	var bread_spawner := _spawner("BreadSpawner")
	if bread_spawner != null:
		_connect_once(bread_spawner, "crumb_eaten", func(amount):
			_log_event("crumb_eaten", {"amount": snappedf(amount, 0.01)}))
	var game := get_tree().root.get_node_or_null("Game")
	if game != null:
		_connect_once(game, "hit_scored", func(points, multiplier, pos, style):
			_log_event("hit_scored", {"points": points, "multiplier": multiplier, "p": _v(pos), "style": style}))


func _connect_once(node: Node, signal_name: String, handler: Callable) -> void:
	var key := "%d:%s" % [node.get_instance_id(), signal_name]
	if _connected.has(key) or not node.has_signal(signal_name):
		return
	node.connect(signal_name, handler)
	_connected[key] = true


func _log_event(name: String, data: Dictionary) -> void:
	if _events_file == null:
		return
	var line := {"ev": name, "t_ms": Time.get_ticks_msec()}
	line.merge(data, true)
	_events_file.store_line(JSON.stringify(line))
	_events_file.flush()


func _save_image() -> void:
	if _dir.is_empty():
		return
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty() or img.get_width() == 0:
		return
	img.save_png("%s/f%08d.png" % [_dir, _frame])

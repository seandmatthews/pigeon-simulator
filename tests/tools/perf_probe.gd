extends Node3D
## T-214 data-gathering probe: the resident Ames world's RENDERED cost per
## pose and per family, measured on real hardware (the T-209 audit counts
## structure; this one counts what the GPU actually draws). Run from the repo
## root on any machine with a display:
##   godot --rendering-driver opengl3 --path . res://tests/tools/perf_probe.tscn
## Prints CSV-ish `PERF pose=... fps= draws= prims= vmem_mb= objects= nodes=`
## lines (60-frame average per pose, sampled mid-run), then a family sweep at
## the recorded hotspot pose — for each family root: `PERF hide=<family>
## draws= delta=` while hidden (then restored). The deltas rank the perf
## avenues; every number is from Performance.get_monitor at settled frames.

const AMES_WORLD_SCENE: PackedScene = preload("res://scenes/ames_world.tscn")

## The recorded ledger poses (vantage name → camera transform origin + yaw deg).
const POSES: Array = [
	["spawn_ground", Vector3(380.17, 1.5, -294.45), 0.0],
	["campus_hover", Vector3(362.8, 70.0, -378.6), 90.0],
	["campustown_strip", Vector3(220.0, 45.0, -180.0), 180.0],
	["stadium", Vector3(1192.0, 60.0, 997.0), 315.0],
	["downtown", Vector3(2870.0, 40.0, -252.0), 270.0],
	["laverne", Vector3(260.0, 50.0, -520.0), 0.0],
	["overview_high", Vector3(0.0, 400.0, 0.0), 0.0],
]
const HOTSPOT := "campustown_strip"
const SETTLE_FRAMES := 40

var _cam: Camera3D
var _world: AmesWorld
var _sun: DirectionalLight3D


func _ready() -> void:
	_world = AMES_WORLD_SCENE.instantiate() as AmesWorld
	add_child(_world)
	_cam = Camera3D.new()
	_cam.current = true
	add_child(_cam)
	await get_tree().physics_frame
	await get_tree().process_frame
	for pose: Array in POSES:
		await _measure_pose(String(pose[0]), pose[1], float(pose[2]))
	await _ground_bisect()
	await _family_sweep()
	get_tree().quit()


## The spawn_ground fps=1 bisect: shadow toggle, pitch variants, altitude
## ladder — isolating shadow-pass vs overdraw vs family cost at ground level.
func _ground_bisect() -> void:
	_sun = null
	for light: Node in _world.find_children("*", "DirectionalLight3D", true, false):
		_sun = light
	var was_shadow := _sun != null and _sun.shadow_enabled
	_place("bisect_spawn", Vector3(380.17, 1.5, -294.45), 0.0)
	if _sun != null:
		_sun.shadow_enabled = false
		await _sample("bisect_spawn_no_shadow")
		_sun.shadow_enabled = true
	_place("bisect_spawn", Vector3(380.17, 1.5, -294.45), 0.0)
	_cam.rotation = Vector3(deg_to_rad(-35.0), 0.0, 0.0)
	await _sample("bisect_spawn_pitch_down35")
	_cam.rotation = Vector3(0.0, deg_to_rad(180.0), 0.0)
	await _sample("bisect_spawn_yaw_south")
	for alt: float in [10.0, 25.0, 60.0]:
		_place("bisect_alt_" + String.num(alt, 0), Vector3(380.17, alt, -294.45), 0.0)
		_cam.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)
		await _sample("bisect_alt_%d" % int(alt))
	if _sun != null:
		_sun.shadow_enabled = was_shadow


func _place(name: String, origin: Vector3, yaw_deg: float) -> void:
	_cam.global_position = origin
	_cam.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	_cam.name = "ProbeCam"


func _sample(name: String) -> void:
	# 40 settled frames, then the average of the LAST 10 samples (avoids the
	# teleport spike).
	var draws: Array[float] = []
	var prims: Array[float] = []
	var fps: Array[float] = []
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
		if i >= SETTLE_FRAMES - 10:
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			fps.append(Performance.get_monitor(Performance.TIME_FPS))
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var nodes := Performance.get_monitor(Performance.OBJECT_COUNT)
	var avg := func(arr: Array[float]) -> int:
		var s := 0.0
		for v: float in arr:
			s += v
		return int(round(s / arr.size()))
	print("PERF pose=%s fps=%d draws=%d prims=%d vmem_mb=%d objects=%d nodes=%d" % [
			name, avg.call(fps), avg.call(draws), avg.call(prims),
			int(vmem / 1048576.0), objects, nodes])


func _measure_pose(name: String, origin: Vector3, yaw_deg: float) -> void:
	_place(name, origin, yaw_deg)
	await _sample(name)


func _family_sweep() -> void:
	var buckets: Dictionary = {}
	_bucket(_world, buckets)
	_place("bisect_spawn", Vector3(380.17, 1.5, -294.45), 0.0)
	var keys: Array = buckets.keys()
	keys.sort()
	for key: String in keys:
		var b: Dictionary = buckets[key]
		if b.roots.is_empty() or key == "ProbeCam":
			continue
		for root: Node in b.roots:
			root.visible = false
		# 3 warm frames then sample, so the visibility change is reflected.
		for i: int in 3:
			await get_tree().process_frame
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		print("PERF hide=%s draws=%d prims=%d fps=%d" % [key, draws, prims, int(fps)])
		for root: Node in b.roots:
			root.visible = true


## The T-209 audit's family bucketing: a direct child of the world root or of
## a chunk node buckets under the nearest family root (trailing digits merged).
func _bucket(root: Node, buckets: Dictionary) -> void:
	var re := RegEx.new()
	re.compile("[0-9]+$")
	for child: Node in root.get_children():
		var key: String = re.sub(child.name, "", true)
		if not buckets.has(key):
			buckets[key] = {"roots": [], "nodes": 0}
		buckets[key].roots.append(child)
		var stack: Array[Node] = [child]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			buckets[key].nodes += 1
			for sub: Node in n.get_children():
				stack.append(sub)
		if child.name.begins_with("Chunk"):
			_bucket(child, buckets)

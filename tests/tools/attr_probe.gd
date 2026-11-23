extends Node3D
## Attribution probe (T-215): toggles each system off one at a time and measures the per-tick cost by difference: boots main.tscn
## headless, measures median wall-ms per physics tick, then toggles whole
## systems off one at a time (process_mode DISABLED) to attribute the tick
## cost by difference. Diagnostic only — never shipped.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SETTLE_TICKS := 300
const WARM_TICKS := 40
const MEASURE_TICKS := 240

var _main: Node


func _ready() -> void:
	Engine.max_fps = 0
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	for i in SETTLE_TICKS:
		await get_tree().physics_frame
	await _run("base", [])
	await _run("cars_off", [["Car"]])
	await _run("tourists_off", [["Tourist"]])
	await _run("elders_off", [["Elder"]])
	await _run("spawners_off", [["CarSpawner"], ["TouristSpawner"], ["ElderSpawner"], ["BreadSpawner"], ["CafeSpawner"]])
	await _run("train_off", [["AmesTrain"]])
	await _run("player_off", [["Player"], ["ChaseCamera"]])
	await _run("swan_butterfly_off", [["Swan"], ["Butterfly"]])
	await _run("crumbs_poop_off", [["BreadCrumb"], ["Poop"]])
	get_tree().quit(0)


func _by_class(klass: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [_main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() != null and n.get_script().get_global_name() == klass:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _set_group(klass: String, off: bool) -> int:
	var mode := Node.PROCESS_MODE_DISABLED if off else Node.PROCESS_MODE_INHERIT
	var nodes := _by_class(klass)
	for n in nodes:
		n.process_mode = mode
	return nodes.size()


func _run(label: String, groups: Array) -> void:
	var counts := {}
	for g in groups:
		counts[g[0]] = _set_group(g[0], true)
	for i in WARM_TICKS:
		await get_tree().physics_frame
	var samples: Array[float] = []
	for i in MEASURE_TICKS:
		var t0 := Time.get_ticks_usec()
		await get_tree().physics_frame
		samples.append((Time.get_ticks_usec() - t0) / 1000.0)
	var wall := _nearest_rank(samples, 0.5)
	print("ATTR %s wall=%.2f nodes=%s" % [label, wall, str(counts)])
	for g in groups:
		_set_group(g[0], false)


func _nearest_rank(samples: Array[float], q: float) -> float:
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[ceili(q * sorted.size()) - 1]

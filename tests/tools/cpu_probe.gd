extends Node3D
## T-214 data-gathering probe #2: the simulation's HEADLESS frame rate — the
## same world, no rendering at all. Isolates CPU/main-thread cost from GPU
## cost: if headless crawls too, the bottleneck is the simulation + scene
## processing (nodes, physics, citizen systems); if headless is fast, it is
## the render path. Run:
##   godot --headless --path . res://tests/tools/cpu_probe.tscn
## Prints `CPUPROBE frames=N wall_s=X.X fps_eq=X.X nodes=N physics=N` after
## 300 process frames, with a warm-up block before the measurement window.

const AMES_WORLD_SCENE: PackedScene = preload("res://scenes/ames_world.tscn")
const WARMUP_FRAMES := 60
const MEASURE_FRAMES := 300

var _world: AmesWorld


func _ready() -> void:
	_world = AMES_WORLD_SCENE.instantiate() as AmesWorld
	add_child(_world)
	await get_tree().physics_frame
	await get_tree().process_frame
	for i: int in WARMUP_FRAMES:
		await get_tree().process_frame
	var start := Time.get_ticks_msec()
	for i: int in MEASURE_FRAMES:
		await get_tree().process_frame
	var wall_s := (Time.get_ticks_msec() - start) / 1000.0
	var nodes := Performance.get_monitor(Performance.OBJECT_COUNT)
	var physics := "active=%d pairs=%d" % [
			Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
			Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)]
	print("CPUPROBE frames=%d wall_s=%.2f fps_eq=%.1f nodes=%d physics=%s" % [
			MEASURE_FRAMES, wall_s, MEASURE_FRAMES / maxf(wall_s, 0.001),
			nodes, physics])
	get_tree().quit()

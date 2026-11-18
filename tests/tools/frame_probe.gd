extends Node
## T-215 submit-path probe: boots the real game (main.tscn), then samples the
## render-side monitors EVERY frame for a fixed window — draw calls, the four
## PIPELINE_COMPILATIONS_* counters (cumulative engine-wide), the frame's wall
## delta and the process/physics script times — so a per-frame pipeline-compile
## stall (the 960 ms process phase the storm_probe caught on the gate box)
## is distinguishable from a plain slow driver. Prints one
## `FRAME n= fps= dt_ms= draws= pipes_draw= pipes_surf= pipes_mesh= proc_ms= phys_ms=`
## line per sampled frame. Env: FRAME_FRAMES (default 300).
## Run:
##   godot --path . res://tests/tools/frame_probe.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.world = "ames"
	_game = MAIN_SCENE.instantiate()
	add_child(_game)
	var car_spawner := _game.get_node("CarSpawner") as CarSpawner
	var tourist_spawner := _game.get_node("TouristSpawner") as TouristSpawner
	var ready_frames: int = 0
	for i: int in 2400: ## ~40 s watchdog
		await get_tree().physics_frame
		if car_spawner.living_cars().size() > 0 \
				and tourist_spawner.get_child_count() > 0:
			ready_frames += 1
			if ready_frames >= 30:
				break
		else:
			ready_frames = 0
	Game.hunger.locked = true
	var frames := int(OS.get_environment("FRAME_FRAMES")) if OS.get_environment(
			"FRAME_FRAMES") != "" else 300
	var last_ticks := Time.get_ticks_usec()
	for i: int in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		print("FRAME n=%d fps=%d dt_ms=%.1f draws=%d pipes_draw=%d pipes_surf=%d pipes_mesh=%d pipes_canvas=%d proc_ms=%.1f phys_ms=%.1f" % [
				i, Performance.get_monitor(Performance.TIME_FPS),
				(now - last_ticks) / 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		last_ticks = now
	print("FRAME DONE")
	get_tree().quit()

extends Node
## T-215 storm-attribution probe: boots the real game (main.tscn), teleports
## the pigeon into the tailgate zone and measures _physics_process-side frame
## cost per window while toggling the suspect systems one at a time — the A/B
## that attributes the T-209/T-214 storm's 330–530 ms of script physics time.
## Prints one `STORM window=<name> phys_ms=… proc_ms=… fps=… pairs=…` line per
## window (phys_ms = Performance.TIME_PHYSICS_PROCESS averaged over the
## window's physics frames, ×1000; pairs = PHYSICS_3D_COLLISION_PAIRS avg).
## Every toggle restores exactly what it disabled before the next window.
##
## Env knobs (all optional):
##   STORM_POSE="x,y,z"       the zone pose (default the SE residential edge
##                            1500,40,900 — the pose that reproduced the storm)
##   STORM_CONTROL="x,y,z"    the out-of-zone control pose (default the spawn
##                            corridor 380.17,1.5,-294.45)
##   STORM_FRAMES=N           physics frames per window (default 120 = 2 s)
##   STORM_SETTLE=S           seconds to settle after each teleport (default 4)
## Run:
##   godot --path . res://tests/tools/storm_probe.tscn
## Headless also works (every monitor here is CPU-side).

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _game: Node
var _player: Player
var _car_spawner: CarSpawner
var _tourist_spawner: TouristSpawner


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.world = "ames"
	_game = MAIN_SCENE.instantiate()
	add_child(_game)
	## An instanced-Main rig takes the SYNC boot path (`_boot_is_stepped`
	## needs the scene mounted under root), which never emits boot_finished —
	## wait for the built world's own tell instead: the car and tourist
	## populations exist. A watchdog keeps a hung boot bounded.
	_car_spawner = _game.get_node("CarSpawner") as CarSpawner
	_tourist_spawner = _game.get_node("TouristSpawner") as TouristSpawner
	var ready_frames: int = 0
	for i: int in 2400: ## ~40 s at 60 Hz
		await get_tree().physics_frame
		if _car_spawner.living_cars().size() > 0 \
				and _tourist_spawner.get_child_count() > 0:
			ready_frames += 1
			if ready_frames >= 30: ## A settled second after the populates.
				break
		else:
			ready_frames = 0
	if ready_frames < 30:
		print("STORM ERROR boot_timeout")
		get_tree().quit(1)
		return
	_player = _game.get_node("Player") as Player
	Game.hunger.locked = true
	var pose := _pose_env("STORM_POSE", Vector3(1500.0, 40.0, 900.0))
	var control := _pose_env("STORM_CONTROL", Vector3(380.17, 1.5, -294.45))
	var settle := float(OS.get_environment("STORM_SETTLE")) if OS.get_environment(
			"STORM_SETTLE") != "" else 4.0
	var frames := int(OS.get_environment("STORM_FRAMES")) if OS.get_environment(
			"STORM_FRAMES") != "" else 120

	## 1 · The control pose first — the fleet is boot-seeded around it.
	_player.reset_flight(control)
	await get_tree().create_timer(settle).timeout
	await _window("control_out", frames)

	## 2 · The zone pose — the storm re-fires on every arrival.
	_player.reset_flight(pose)
	await get_tree().create_timer(settle).timeout
	await _window("zone_base", frames)

	## 3 · The bisect. Every toggle restores before the next window.
	var cars := _car_spawner.living_cars()
	var moving: Array[Car] = []
	var parked: Array[Car] = []
	for car: Car in cars:
		if car.mode == Car.Mode.PARKED:
			parked.append(car)
		else:
			moving.append(car)
	print("STORM fleet=%d moving=%d parked=%d blocks=%d nodes=%d" % [
			cars.size(), moving.size(), parked.size(),
			(_car_spawner.get("_block_centers_cache") as PackedVector3Array).size(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])

	_set_cars_physics(cars, false)
	await _window("zone_cars_all_off", frames)
	_set_cars_physics(moving, true)
	await _window("zone_cars_parked_only_off", frames)
	_set_cars_physics(moving, false)
	_set_cars_physics(cars, true)

	_car_spawner.set_physics_process(false)
	await _window("zone_spawner_off", frames)
	_car_spawner.set_physics_process(true)

	if _tourist_spawner != null:
		_tourist_spawner.set_physics_process(false)
		for tourist: Node in _tourist_spawner.get_children():
			tourist.set_physics_process(false)
		await _window("zone_tourists_off", frames)
		for tourist: Node in _tourist_spawner.get_children():
			tourist.set_physics_process(true)
		_tourist_spawner.set_physics_process(true)

	_player.set_physics_process(false)
	await _window("zone_player_off", frames)
	_player.set_physics_process(true)

	## The _refresh_block hypothesis: the per-frame nearest-block scan walks
	## EVERY city block center on EVERY moving car — truncate each car's list
	## to its current assignment alone, measure, restore.
	var saved: Array[PackedVector3Array] = []
	for car: Car in cars:
		saved.append(car._block_centers)
		car._block_centers = PackedVector3Array([car.block_center])
	await _window("zone_blocks_truncated", frames)
	for i: int in cars.size():
		if is_instance_valid(cars[i]):
			cars[i]._block_centers = saved[i]

	## The freeze A/B (the T-209 bisect): hold everything the dev freeze holds.
	Car.traffic_frozen = true
	await _window("zone_freeze_on", frames)
	Car.traffic_frozen = false

	await _window("zone_restored", frames)
	_bench_placement(pose)
	print("STORM DONE")
	get_tree().quit()


## The Avenue-A bench: the reads the recycle/placement machinery pays inside
## the zone, timed directly — `park_spots_near` (the dressed-lot offer), the
## graph's curb-spot deal and one full recycle scan against the zone anchor.
func _bench_placement(pose: Vector3) -> void:
	var city := _game.get("city") as City
	if city == null:
		return
	var anchor := Vector2(pose.x, pose.z)
	var lxz := Vector2(city.to_local(Vector3(pose.x, 0.0, pose.z)).x,
			city.to_local(Vector3(pose.x, 0.0, pose.z)).z)
	if city.parking != null:
		var spots := city.parking.park_spots_near(lxz,
				AmesParking.LOT_PARK_RADIUS)
		var t0 := Time.get_ticks_usec()
		for i: int in 20:
			city.parking.park_spots_near(lxz, AmesParking.LOT_PARK_RADIUS)
		print("STORM bench=park_spots_near spots=%d us_per_call=%.0f tailgate_dressed=%d" % [
				spots.size(),
				float(Time.get_ticks_usec() - t0) / 20.0,
				city.parking.dressed_tailgate()])
	var t1 := Time.get_ticks_usec()
	for i: int in 5:
		_car_spawner._recycle_far()
	print("STORM bench=recycle_scan us_per_scan=%.0f" % [
			float(Time.get_ticks_usec() - t1) / 5.0])
	var t2 := Time.get_ticks_usec()
	for i: int in 5:
		city.traffic_graph.nearest_runs(lxz.x, lxz.y, 12)
	print("STORM bench=nearest_runs12 us_per_call=%.0f" % [
			float(Time.get_ticks_usec() - t2) / 5.0])


func _pose_env(key: String, fallback: Vector3) -> Vector3:
	var raw := OS.get_environment(key)
	if raw == "":
		return fallback
	var parts := raw.split(",")
	if parts.size() != 3:
		print("STORM ERROR bad_pose %s=%s" % [key, raw])
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


## Flips `set_physics_process` on exactly the given cars.
func _set_cars_physics(cars: Array[Car], enabled: bool) -> void:
	for car: Car in cars:
		if is_instance_valid(car):
			car.set_physics_process(enabled)


## One measurement window: `frames` physics frames, monitors sampled each
## frame, one averaged STORM line.
func _window(label: String, frames: int) -> void:
	var phys_sum := 0.0
	var phys_max := 0.0
	var proc_sum := 0.0
	var fps_sum := 0.0
	var pairs_sum := 0.0
	var n := 0
	for i: int in frames:
		await get_tree().physics_frame
		phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		phys_max = maxf(phys_max,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
		fps_sum += float(Performance.get_monitor(Performance.TIME_FPS))
		pairs_sum += float(Performance.get_monitor(
				Performance.PHYSICS_3D_COLLISION_PAIRS))
		n += 1
	print("STORM window=%s phys_ms=%.1f phys_max_ms=%.1f proc_ms=%.1f fps=%.0f pairs=%.0f" % [
			label, phys_sum / n * 1000.0, phys_max * 1000.0,
			proc_sum / n * 1000.0, fps_sum / n, pairs_sum / n])

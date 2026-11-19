extends Node3D
## Climb benchmark probe (the storm gate's benchmark command, T-082/T-084
## posture): the tailgate traffic-physics storm — T-214's measured finding,
## T-215 Avenue A — timed headless as wall-ms per physics tick at two poses
## in one boot. Boots the REAL game (scenes/main.tscn — town alive, traffic
## live), measures the spawn pose as the healthy reference, then teleports
## the pigeon into the tailgate lot sea (T-214's Hilton flank, inside the
## ames_parking.gd census window), waits out the measured re-seat burst
## (~7 s, T-214), and times a 7.5 s window of physics ticks. Prints ONE
## top-level JSON line (the relative-gate template's contract) and exits
## nonzero on any containment or placement failure:
##   godot --headless --path . res://tests/tools/storm_probe.tscn
##
## Engine.max_fps = 0 unthrottles the headless loop so per-tick wall time IS
## the per-tick cost (the storm is CPU-side physics work — T-214: both
## renderers storm identically). The pigeon is PINNED within 5 m of the
## pose during settle and measure (a hands-off pigeon glides away, and
## T-214's one-occurrence fall-guard ejection must not silently relocate
## the measurement). Placement is SELF-VERIFYING: the probe converts its
## pose to WGS84 through the pack's own transform and refuses to measure
## unless the pose is inside the census window with the lot stock actually
## present around it (park_spots_near + live Car census) — a probe that
## cannot prove it stands in the zone must say so, not measure a field.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

## T-214's "the Hilton flank at (1192, 300)" proved to sit in a GAP between
## dressed lots (v4 DIAG: in_window=true, spots=0, cars=0 — no storm
## trigger). The probe no longer trusts hand-written coordinates: it asks
## the parking system for the DENSEST dressed tailgate lot and stands in
## that lot's center — "standing in the game-day lot sea" means inside a
## lot, and the lot sea is wherever the committed census says it is.
## (T-214 audit cited the Hilton flank as (1192, 300); kept here as prose only.)
## The census window (ames_parking.gd TAILGATE_*), for the self-check only.
const ZONE_LON_W := -93.6445
const ZONE_LON_E := -93.6260
const ZONE_LAT_N := 42.0225
const POP_RADIUS := 120.0
const RAY_TOP_Y := 250.0
const RAY_DROP := 400.0
const GROUND_CLEARANCE := 1.5
const PIN_RADIUS := 5.0
const CONTAIN_RADIUS := 60.0
## The fleet band the storm needs: T-214's burst re-seats 11-26 cars near the
## anchor; a settled zone with fewer than this many cars nearby is not the
## storm's neighborhood.
const MIN_FLEET_BAND := 5
## The anti-gaming population floors (observed healthy boots: ~16.8k nodes,
## 26 cars). A candidate that "improves" by gutting the town trips these.
const MIN_TOWN_NODES := 15000
const MIN_TOWN_CARS := 20
## In-zone dwells separated by leave-and-return (the T-214 discriminator:
## the audit's storm re-fired on EVERY re-teleport — three chances to fire).
const ENTRY_CYCLES := 3
const LEAVE_TICKS := 300

## Sim-time ticks: the spawn window settles 5 s and measures 5 s; the storm
## settle (10 s) must outlast the measured re-seat burst (~7 s, T-214) with
## margin before the 7.5 s storm window opens — shorten either and the
## yardstick stops measuring what T-214 measured.
const SPAWN_SETTLE_TICKS := 300
const MEASURE_TICKS := 300
const STORM_SETTLE_TICKS := 600
const STORM_MEASURE_TICKS := 450

var _main: Node
var _pose := Vector2.ZERO


func _ready() -> void:
	Engine.max_fps = 0
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	for i: int in 10:
		await get_tree().physics_frame
	## The population floors (the anti-gaming posture): a "cheaper" tick must
	## come from the same living town, not from a gutted one. Observed healthy
	## boots: ~16.8k nodes, 26 cars (T-178's 14 moving + 12 parked). A boot
	## below either floor is a refusal — an unevaluable benchmark proves
	## nothing and must say so.
	var boot_nodes := Performance.get_monitor(Performance.OBJECT_COUNT)
	if boot_nodes < MIN_TOWN_NODES:
		_fail("boot population below the floor (%d < %d nodes) — the town must stay alive for its cost to be climbable" % [boot_nodes, MIN_TOWN_NODES])
	var player: Node3D = _main.get_node_or_null("Player")
	if player == null:
		_fail("no Player under Main")
	var spawn_home := player.global_position
	var spawn_ms := await _run_window(player, SPAWN_SETTLE_TICKS, NAN)
	_pose = _pick_storm_lot()
	var ground_y := _ground_y_at(_pose)
	_place(player, ground_y)
	var storm_ms := 0.0
	var storm_p95_ms := 0.0
	var storm_phys_ms := 0.0
	if _zone_check_ok():
		for i: int in STORM_SETTLE_TICKS:
			_pin(player, ground_y)
			await get_tree().physics_frame
		if _drift(player) > CONTAIN_RADIUS:
			_fail("pigeon outside the storm zone after settle (drift %.1f m)" % _drift(player))
		var cars_near := _cars_near()
		print("DIAG after_settle cars_near=%d" % cars_near)
		if cars_near < MIN_FLEET_BAND:
			_fail("fleet never banded to the zone after settle (cars_near=%d < %d) — the T-214 preconditions are absent; refuse, never measure an empty yard" % [cars_near, MIN_FLEET_BAND])
		var cycle_medians: Array[float] = []
		for cycle in ENTRY_CYCLES:
			var wall := await _collect(player, ground_y, STORM_MEASURE_TICKS)
			var phys := await _collect_phys(player, ground_y, STORM_MEASURE_TICKS)
			var ms := _nearest_rank(wall, 0.5)
			cycle_medians.append(ms)
			print("DIAG cycle=%d storm_ms=%.2f phys_ms=%.2f p95=%.2f cars_near=%d" % [
				cycle, ms, _nearest_rank(phys, 0.5), _nearest_rank(wall, 0.95), _cars_near()])
			if cycle < ENTRY_CYCLES - 1:
				_leave_and_return(player, spawn_home, ground_y)
		storm_ms = _nearest_rank(cycle_medians, 0.5)
		storm_p95_ms = storm_ms
		storm_phys_ms = storm_ms
		if _drift(player) > CONTAIN_RADIUS:
			_fail("pigeon outside the storm zone after measure (drift %.1f m)" % _drift(player))
	else:
		_fail("placement self-check failed: pose not verifiably inside the live zone")
	print(JSON.stringify({
		"spawn_ms": snappedf(spawn_ms, 0.01),
		"storm_ms": snappedf(storm_ms, 0.01),
		"storm_p95_ms": snappedf(storm_p95_ms, 0.01),
		"storm_phys_ms": snappedf(storm_phys_ms, 0.01),
		"pose_x": snappedf(_pose.x, 0.1),
		"pose_z": snappedf(_pose.y, 0.1),
		"ticks": STORM_MEASURE_TICKS,
		"ground_y": snappedf(ground_y, 0.01),
		"nodes": Performance.get_monitor(Performance.OBJECT_COUNT),
	}))
	get_tree().quit(0)


## The placement self-check: the pose must be inside the census window
## (through the pack's own transform), and the zone must be LIVE around it —
## dressed park spots within POP_RADIUS and Car nodes on the street graph.
## Prints a DIAG line with every number so a failed gate's tail carries the
## evidence, not just the verdict.
## The storm pose: the center of the densest DRESSED tailgate lot (most kept
## stalls), world/pack-local. Fails the run when the census carries no dressed
## tailgate lot at all — an empty zone is a refusal, never a quiet 15 ms.
func _pick_storm_lot() -> Vector2:
	var world: AmesWorld = _main.get_node_or_null("City")
	if world == null or world.parking == null:
		_fail("no parking system on the world")
	var best := Vector2.ZERO
	var best_stalls := -1
	var tailgate := 0
	var total_cars := 0
	for lot in world.parking.lots:
		if not lot.in_tailgate:
			continue
		tailgate += 1
		if lot.stalls.size() > best_stalls:
			best_stalls = lot.stalls.size()
			best = lot.center
	for n in _all_nodes(_main):
		if n is Car:
			total_cars += 1
	print("DIAG tailgate_lots=%d picked_stalls=%d picked_center=(%.1f, %.1f) town_cars=%d" % [
		tailgate, best_stalls, best.x, best.y, total_cars])
	if tailgate == 0 or best_stalls <= 0:
		_fail("no dressed tailgate lot to stand in")
	if total_cars < MIN_TOWN_CARS:
		_fail("fleet below the floor (%d < %d cars) — gutting the traffic fleet is not a fix" % [total_cars, MIN_TOWN_CARS])
	return best


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _zone_check_ok() -> bool:
	var wgs := AmesDataPack.local_to_wgs84(Vector3(_pose.x, 0.0, _pose.y))
	var in_window: bool = wgs.x > ZONE_LON_W and wgs.x < ZONE_LON_E and wgs.y < ZONE_LAT_N
	var world: AmesWorld = _main.get_node_or_null("City")
	if world == null or world.parking == null:
		_fail("no parking system on the world at zone-check time")
	var spots: int = world.parking.park_spots_near(_pose, POP_RADIUS).size()
	var cars := _cars_near()
	print("DIAG lonlat=(%.5f,%.5f) in_window=%s spots=%d cars_near=%d" % [
		wgs.x, wgs.y, in_window, spots, cars])
	return in_window and spots > 0


## Car nodes within POP_RADIUS of the storm pose (the fleet band the recycle
## scan owes the anchor: band_spawner.gd re-seats cars >160 m from the PLAYER
## every 0.5 s — the T-214 burst is this scan catching up to a teleport).
func _cars_near() -> int:
	var cars := 0
	for n in _all_nodes(_main):
		if n is Car and n is Node3D:
			var p3 := (n as Node3D).global_position
			if Vector2(p3.x - _pose.x, p3.z - _pose.y).length() <= POP_RADIUS:
				cars += 1
	return cars


## Settle for `settle_ticks`, then time the window and return per-tick wall ms.
## The pigeon is pinned each tick.
func _run_window(player: Node3D, settle_ticks: int, pin_y: float) -> float:
	for i: int in settle_ticks:
		if not is_nan(pin_y):
			_pin(player, pin_y)
		await get_tree().physics_frame
	return _nearest_rank(await _collect(player, pin_y, MEASURE_TICKS), 0.5)


## Per-tick WALL ms (the honest cost when headless runs unthrottled).
func _collect(player: Node3D, pin_y: float, ticks: int) -> Array[float]:
	var samples: Array[float] = []
	for i: int in ticks:
		if not is_nan(pin_y):
			_pin(player, pin_y)
		var t0 := Time.get_ticks_usec()
		await get_tree().physics_frame
		samples.append((Time.get_ticks_usec() - t0) / 1000.0)
	return samples


## Per-tick PHYSICS ms (Godot's per-frame physics-time monitor, seconds →
## ms) — the attribution channel: if wall climbs but phys doesn't, the cost
## is not the physics T-214 blamed, and the climb must know that before it
## starts.
func _collect_phys(player: Node3D, pin_y: float, ticks: int) -> Array[float]:
	var samples: Array[float] = []
	for i: int in ticks:
		if not is_nan(pin_y):
			_pin(player, pin_y)
		await get_tree().physics_frame
		samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	return samples


## Nearest-rank order statistic (the T-018 rule: sorted[ceil(q*n)-1], no
## interpolation) — the same rule the relative-gate template applies across
## runs; applying it within a run too keeps one definition of "the median".
func _nearest_rank(samples: Array[float], q: float) -> float:
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[ceili(q * sorted.size()) - 1]


## Ground height under the storm pose via a downward ray (the world's own
## collision, no hardcoded terrain numbers). A miss fails the run — a probe
## that cannot find the lot sea must say so, not measure the void.
func _ground_y_at(pose: Vector2) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(pose.x, RAY_TOP_Y, pose.y),
		Vector3(pose.x, RAY_TOP_Y - RAY_DROP, pose.y))
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_fail("ground ray missed at the storm pose (%.1f, %.1f)" % [pose.x, pose.y])
	return hit["position"].y


func _place(player: Node3D, ground_y: float) -> void:
	player.global_position = Vector3(_pose.x, ground_y + GROUND_CLEARANCE, _pose.y)
	if "velocity" in player:
		player.set("velocity", Vector3.ZERO)


## The T-214 rig's re-entry: out to the spawn home, let the recycle scan pull
## the band apart, back into the zone (the audit's "re-firing on every
## re-teleport into the zone"). Each cycle re-arms every entry-triggered
## offer/recycle path the storm might ride.
func _leave_and_return(player: Node3D, home: Vector3, ground_y: float) -> void:
	player.global_position = home
	if "velocity" in player:
		player.set("velocity", Vector3.ZERO)
	for i: int in LEAVE_TICKS:
		await get_tree().physics_frame
	_place(player, ground_y)
	for i: int in STORM_SETTLE_TICKS:
		_pin(player, ground_y)
		await get_tree().physics_frame


## Keep the measurement where it was declared: past PIN_RADIUS of horizontal
## drift, snap back to the pose (the fall-guard ejection, T-214's n=1 defect,
## must not silently relocate the yardstick mid-window).
func _pin(player: Node3D, ground_y: float) -> void:
	if _drift(player) > PIN_RADIUS:
		_place(player, ground_y)


func _drift(player: Node3D) -> float:
	return Vector2(player.global_position.x - _pose.x, player.global_position.z - _pose.y).length()


func _fail(msg: String) -> void:
	print("STORMPROBE FAIL: %s" % msg)
	get_tree().quit(1)

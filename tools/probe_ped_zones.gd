extends Node3D
## (T-181 diagnostic) Builds the resident Ames world and prints the pedestrian
## zone derivation: per zone the path/vertex/bench stock, the road-contact
## read over every path vertex (crossing legs excluded — the fence), the
## bench ground state and the rebuild determinism — so the zone constants
## stay checkable against the committed pack. Run (a SCENE run — the world
## chain needs the autoloads, the `--script` mode has none):
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . ##     res://tools/probe_ped_zones.tscn

var _world: AmesWorld


func _ready() -> void:
	_world = (load("res://scenes/ames_world.tscn") as PackedScene) 			.instantiate() as AmesWorld
	get_tree().root.add_child.call_deferred(_world) ## Builds on add.
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var zones: AmesPedZones = _world.ped_zones
	if zones == null:
		push_error("PROBE FAIL: no ped zones on the built world")
		get_tree().quit(1)
		return
	var graph: AmesTrafficGraph = _world.traffic_graph
	## DEBUG: the per-side walks for Welch.
	for side: Vector2 in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]:
		var w: PackedVector2Array = zones._side_walk("Welch Avenue",
				Vector2(-30.0, 30.0), Vector2(0.0, 460.0), side, Vector2(0.0, 1.0))
		var minx := INF
		var maxx := -INF
		for q: Vector2 in w:
			minx = minf(minx, q.x)
			maxx = maxf(maxx, q.x)
		print("  welch side walk %s: %d pts x %.1f..%.1f" % [side, w.size(), minx, maxx])
	print("zones: %d | benches: %d" % [zones.zones.size(), _bench_count(zones)])
	for zone: AmesPedZones.Zone in zones.zones:
		print("zone %s (%s cap %d): paths %d benches %d" % [
				zone.id, zone.klass, zone.cap, zone.paths.size(), zone.benches.size()])
		for pi in zone.paths.size():
			var path: PackedVector2Array = zone.paths[pi]
			var crosses: Array = zone.crosses[pi] if pi < zone.crosses.size() else []
			var minx := INF
			var maxx := -INF
			var minz := INF
			var maxz := -INF
			for p: Vector2 in path:
				minx = minf(minx, p.x)
				maxx = maxf(maxx, p.x)
				minz = minf(minz, p.y)
				maxz = maxf(maxz, p.y)
			var cross_txt := "none"
			if not crosses.is_empty():
				cross_txt = str(crosses)
			print("  path %d: %d pts x %.0f..%.0f z %.0f..%.0f crosses %s" % [
					pi, path.size(), minx, maxx, minz, maxz, cross_txt])
			var road_hits := 0
			var band_hits := 0
			for i in path.size():
				var cross := i < crosses.size() and bool(crosses[i])
				var hit := graph.nearest_run(path[i].x, path[i].y)
				if hit.is_empty():
					continue
				var half := graph.run_half_width(int(hit["run"]))
				if float(hit["dist"]) < half + 0.5:
					if cross or _in_any_band(graph, path[i]):
						band_hits += 1
					else:
						road_hits += 1
						if road_hits <= 4:
							print("    ROAD contact at (%.1f, %.1f) run '%s' d=%.2f half=%.2f" % [
									path[i].x, path[i].y, graph.run_name(int(hit["run"])),
									float(hit["dist"]), half])
			print("    road-contact: mid-block %d, band-legal %d" % [road_hits, band_hits])
		for b: Transform3D in zone.benches:
			var ground: float = _world.ground_height(Vector3(b.origin.x, 0.0, b.origin.z))
			print("  bench at (%.1f, %.1f) seat-y %.2f ground %.2f" % [
					b.origin.x, b.origin.z, b.origin.y, ground])
	var paths_before: Array[String] = []
	for zone: AmesPedZones.Zone in zones.zones:
		for path: PackedVector2Array in zone.paths:
			paths_before.append(str(path))
	_world.generate(_world.seed_value, true)
	var same := true
	var i2 := 0
	for zone: AmesPedZones.Zone in zones.zones:
		for path: PackedVector2Array in zone.paths:
			if i2 >= paths_before.size() or str(paths_before[i2]) != str(path):
				same = false
			i2 += 1
	print("rebuild determinism: %s" % same)
	_world.queue_free()
	print("PROBE DONE")
	get_tree().quit(0)


func _bench_count(zones: AmesPedZones) -> int:
	var n := 0
	for zone: AmesPedZones.Zone in zones.zones:
		n += zone.benches.size()
	return n


## True when the point sits inside ANY pinned anchor's crosswalk band.
func _in_any_band(graph: AmesTrafficGraph, p: Vector2) -> bool:
	for a in graph.intersection_count():
		if graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		for member in graph.intersection_members(a):
			for edge in graph.node_in_edges(member):
				var geo := graph.approach_geometry(member, edge)
				if not bool(geo["fits"]):
					continue
				var band: Dictionary = geo["band"]
				var rel := p - (band["center"] as Vector2)
				var axis := (band["axis"] as Vector2)
				if absf(rel.dot(axis)) <= float(band["half_along"]) 						and absf(rel.dot(Vector2(-axis.y, axis.x))) 								<= float(band["half_across"]):
					return true
	return false

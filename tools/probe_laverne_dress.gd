extends Node3D
## (T-185 diagnostic) Builds the resident Ames world and prints the lake-dress
## derivation: per ring-split loop its size/bbox, the pale/reed stock, every
## reed sliver's in-water read and its edge distance, the pale fringe hug and
## the swan circuit's clearance/span. Run (a SCENE run — the world chain
## needs the autoloads, `--script` mode has none):
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://tools/probe_laverne_dress.tscn

var _world: AmesWorld


func _ready() -> void:
	_world = (load("res://scenes/ames_world.tscn") as PackedScene) \
			.instantiate() as AmesWorld
	get_tree().root.add_child.call_deferred(_world) ## Builds on add.
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var rings: Array[PackedVector2Array] = []
	for water: Dictionary in AmesDataPack.water():
		if str(water.get("name", "")) != "Lake LaVerne" or not water.has("polygon"):
			continue
		rings.append_array(AmesBaker._split_rings(AmesBaker._pack_points(
				water.get("polygon", []))))
	print("PROBE rings=%d" % rings.size())
	var basin := PackedVector2Array()
	var island := PackedVector2Array()
	for ring: PackedVector2Array in rings:
		if ring.size() > basin.size():
			island = basin
			basin = ring
		else:
			island = ring
	for r: int in rings.size():
		var ring2 := rings[r]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p: Vector2 in ring2:
			lo = lo.min(p)
			hi = hi.max(p)
		print("  ring %d: %d pts bbox %s .. %s" % [r, ring2.size(), lo, hi])
	print("PROBE pale=%d reeds=%d" % [_world._pale_edge_xfs.size(),
			_world._reed_xfs.size()])
	## The in-water read per reed sliver (own even-odd over both loops).
	var wet_ok := 0
	var worst := 0.0
	for xf: Transform3D in _world._reed_xfs:
		var p := Vector2(xf.origin.x, xf.origin.z)
		if _in_ring(p, basin) and not _in_ring(p, island):
			wet_ok += 1
		else:
			print("  reed OFF-WATER at (%.1f, %.1f) y=%.2f" % [p.x, p.y, xf.origin.y])
		worst = maxf(worst, _edge_dist(p, basin))
		worst = minf(worst, maxf(worst, 0.0))
	print("PROBE reeds in-water %d/%d worst basin-edge dist %.2f" % [
			wet_ok, _world._reed_xfs.size(), worst])
	var pale_worst := 0.0
	for xf2: Transform3D in _world._pale_edge_xfs:
		pale_worst = maxf(pale_worst, _edge_dist(
				Vector2(xf2.origin.x, xf2.origin.z), basin))
	print("PROBE pale worst basin-edge dist %.2f" % pale_worst)
	var circuit: PackedVector3Array = _world.swan_circuit
	var clo := Vector2(INF, INF)
	var chi := Vector2(-INF, -INF)
	var cworst := INF
	var cout := 0
	for pv: Vector3 in circuit:
		var p2 := Vector2(pv.x, pv.z)
		clo = clo.min(p2)
		chi = chi.max(p2)
		if not _in_ring(p2, basin) or _in_ring(p2, island):
			cout += 1
		cworst = minf(cworst, _edge_dist(p2, basin))
	print("PROBE circuit n=%d span %.1fx%.1f out=%d worst clearance %.2f" % [
			circuit.size(), chi.x - clo.x, chi.y - clo.y, cout, cworst])
	if _world.swans.size() == 2:
		for s: int in 2:
			var swan: Swan = _world.swans[s]
			print("PROBE swan %s at %s yaw %.2f" % [swan.name,
					swan.global_position, swan.rotation.y])
	print("PROBE DONE")
	get_tree().quit(0)


func _in_ring(p: Vector2, ring: PackedVector2Array) -> bool:
	var inside := false
	for i: int in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		if (a.y > p.y) != (b.y > p.y) \
				and p.x < a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x):
			inside = not inside
	return inside


func _edge_dist(p: Vector2, ring: PackedVector2Array) -> float:
	var best := INF
	for i: int in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0 if l2 < 1e-12 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

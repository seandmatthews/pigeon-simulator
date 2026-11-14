extends Node3D
## (T-182 diagnostic) Builds the resident Ames world and prints the parking
## derivation: the census curb marking (per-district run counts + the bay
## runs), the dressed lots (per-lot stall grids), the per-district dressing
## populations and the guard rejections — so the population record stays
## checkable against the committed pack. Run (a SCENE run — the world chain
## needs the autoloads, the `--script` mode has none):
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     res://tools/probe_parking.tscn

var _world: AmesWorld


func _ready() -> void:
	_world = (load("res://scenes/ames_world.tscn") as PackedScene) \
			.instantiate() as AmesWorld
	get_tree().root.add_child.call_deferred(_world) ## Builds on add.
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var parking: AmesParking = _world.parking
	if parking == null:
		push_error("PROBE FAIL: no parking on the built world")
		get_tree().quit(1)
		return
	print("PROBE parking: dressed lots %d, dressed cars %d (tailgate %d), curb runs %d"
			% [parking.lot_count(), parking.dressed_car_count(),
			parking.dressed_tailgate(), parking.curb_run_count()])
	print("PROBE parking per-district: %s" % [parking.dressed_by_district()])
	var graph: AmesTrafficGraph = _world.traffic_graph
	var curb_by_district := {}
	for r in graph.run_count():
		if parking.run_is_curb(r):
			var d: String = graph.run_district(r)
			curb_by_district[d] = int(curb_by_district.get(d, 0)) + 1
	print("PROBE curb runs by district: %s" % [curb_by_district])
	var bay_names := {}
	for r in graph.run_count():
		if parking.run_is_curb(r) \
				and not AmesParking.CURB_DISTRICTS.has(graph.run_district(r)):
			bay_names[graph.run_name(r)] = int(bay_names.get(graph.run_name(r), 0)) + 1
	print("PROBE bay-marked (non-district) runs by name: %s" % [bay_names])
	var raw := 0
	var kept := 0
	for lot: AmesParking.Lot in parking.lots.slice(0, 12):
		raw += lot.stalls_raw
		kept += lot.stalls.size()
	print("PROBE top-12 lots: raw stalls %d, kept %d (fill %.2f)" % [
			raw, kept, float(kept) / maxf(float(raw), 1.0)])
	for lot: AmesParking.Lot in parking.lots.slice(0, 8):
		print("  lot %s (%s, %s, %d m2): raw %d kept %d gaps %d"
				% [lot.id, lot.kind, lot.district, lot.area_m2,
				lot.stalls_raw, lot.stalls.size(), lot.gaps.size()])
	get_tree().quit(0)

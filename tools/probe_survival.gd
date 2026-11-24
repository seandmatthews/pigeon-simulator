extends Node3D
## (Research probe — the Ames difficulty pass, 2026-11-23.) Builds the REAL
## main scene headless (the instanced-Main synchronous boot the sim harness
## uses) and dumps the survival + favor geography to JSON: the spawn, each
## pedestrian zone with its benches and path extent, every elder (zone, seat,
## state), every bread spot (kind + boot-ring flag), and the crumbs, the fleet
## and the tourist crowd the populate actually staged. Evidence for the
## difficulty plan — it reads only. Run (a SCENE run: the world chain needs the
## autoloads, the `--script` mode has none):
##   PIGEON_NO_PERSIST=1 ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless \
##     --path . res://tools/probe_survival.tscn -- <absolute output path>

var _main: Node3D


func _ready() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main) ## Not under the tree root: Main keeps its synchronous rig boot.
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var city: AmesWorld = _main.city
	if city == null or city.ped_zones == null:
		push_error("PROBE FAIL: the world did not build")
		get_tree().quit(1)
		return
	var out: Dictionary = {}
	out["spawn"] = _v(city.spawn_point)
	out["home_center"] = _v(city.home_center())
	out["home_radius"] = city.home_radius()
	out["bounds_min"] = _v(city.get("_bounds_min"))
	out["bounds_max"] = _v(city.get("_bounds_max"))

	var zones: Array = []
	for zone: AmesPedZones.Zone in city.ped_zones.zones:
		var z: Dictionary = {"id": zone.id, "klass": zone.klass, "cap": zone.cap}
		var benches: Array = []
		for xf: Transform3D in zone.benches:
			benches.append(_v((city.global_transform * xf).origin))
		z["benches"] = benches
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var length := 0.0
		var pts: Array = []
		for path: PackedVector2Array in zone.paths:
			for i in path.size():
				var p: Vector2 = path[i]
				lo = lo.min(p)
				hi = hi.max(p)
				pts.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
				if i > 0:
					length += path[i - 1].distance_to(path[i])
		z["path_min"] = [lo.x, lo.y]
		z["path_max"] = [hi.x, hi.y]
		z["path_length_m"] = snappedf(length, 0.1)
		z["path_points"] = pts
		zones.append(z)
	out["zones"] = zones

	var elders: Array = []
	for elder: Elder in _main.elder_spawner.living_elders():
		elders.append({
			"pos": _v(elder.global_position),
			"zone": elder.zone_id,
			"favor_seat": elder._has_favor_seat(),
			"state": int(elder._state),
		})
	out["elders"] = elders

	var spots: Array = []
	for i in city.bread_spots.size():
		spots.append({
			"p": _v(city.to_global(city.bread_spots[i])),
			"kind": city.bread_spot_kinds[i],
			"boot": city.boot_bread_spots.has(i),
		})
	out["bread_spots"] = spots
	var cafes: Array = []
	for xf: Transform3D in city.cafe_spots:
		cafes.append(_v((city.global_transform * xf).origin))
	out["cafe_spots"] = cafes

	var crumbs: Array = []
	for crumb: BreadCrumb in _main.bread_spawner.living_crumbs():
		crumbs.append({
			"p": _v(crumb.global_position),
			"spot": crumb.spot_index,
			"favor": crumb.favor_delta,
		})
	out["crumbs_at_boot"] = crumbs

	var cars: Array = []
	for car: Car in _main.car_spawner.get_children():
		if not (car is Car):
			continue
		cars.append({
			"p": _v(car.global_position),
			"mode": int(car.mode),
			"klass": int(car.citizen_class),
		})
	out["cars"] = cars

	var tourists: Array = []
	for tourist: Tourist in _main.tourist_spawner.living_tourists():
		tourists.append({
			"p": _v(tourist.global_position),
			"klass": int(tourist.citizen_class),
			"zone": tourist.zone_id,
		})
	out["tourists"] = tourists

	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://probe_survival.json"
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("PROBE FAIL: cannot write %s" % out_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(out, " "))
	file.close()
	print("PROBE OK: %s | elders %d | bread spots %d | crumbs at boot %d | cars %d | tourists %d" % [
			out_path, elders.size(), spots.size(), crumbs.size(), cars.size(), tourists.size()])
	get_tree().quit(0)


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

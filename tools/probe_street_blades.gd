extends SceneTree
## (T-200 diagnostic) Exercises the street-blade derivation over the resident
## graph: the pinned-corner spine walk, the module's mount derivation (mast
## stacks / posts), plate fits and yaw laws — plus the mast-const twin
## equality against the world. Run:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/probe_street_blades.gd

const SPINE_NAMES: Array[String] = [
	"Lincoln Way", "East Lincoln Way",
	"Welch Avenue", "Hayward Avenue", "Sheldon Avenue", "Stanton Avenue",
	"Main Street", "Duff Avenue", "South Duff Avenue",
	"Grand Avenue", "South Grand Avenue",
	"University Boulevard", "Mortensen Road",
	"South 16th Street", "Southeast 16th Street",
	"Stange Road", "Clark Avenue", "Burnett Avenue", "Douglas Avenue",
]


func _init() -> void:
	var graph := AmesTrafficGraph.new()
	var root := Node3D.new()
	get_root().add_child(root)
	var records := AmesStreetBlades.build(graph, root)
	var lines: Array[String] = []
	var post_count := 0
	var mast_count := 0
	var seam := 0
	for rec: Dictionary in records:
		if str(rec["mount"]) == "post":
			post_count += 1
		else:
			mast_count += 1
		if str(rec["street"]) == "East Lincoln Way":
			seam += 1
		lines.append("  a=%4d %-22s %-5s k=%d edge=%4d yaw=%6.2f y=%5.2f %s"
				% [int(rec["anchor"]), str(rec["street"]), str(rec["mount"]),
				int(rec["stack"]), int(rec["edge"]), float(rec["yaw"]),
				(rec["pos"] as Vector3).y, str(rec["plate"])])
	lines.sort()
	print("blades: %d (mast %d / post %d) | East Lincoln Way blades: %d"
			% [records.size(), mast_count, post_count, seam])
	## The mast twins must equal the world's consts (the drift gate).
	var twins_ok := AmesStreetBlades.MAST_ARM_Y == AmesWorld.MAST_ARM_Y \
			and AmesStreetBlades.MAST_POLE_CLEAR == AmesWorld.MAST_POLE_CLEAR \
			and AmesStreetBlades.MAST_POLE_SIDE == AmesWorld.MAST_POLE_SIDE \
			and AmesStreetBlades.MAST_ARM_END_CLEAR == AmesWorld.MAST_ARM_END_CLEAR
	print("mast twins equal world consts: %s" % twins_ok)
	## The spine set pinned in the module equals this probe's own list.
	var module_spine := AmesStreetBlades.SPINE_NAMES
	var spine_ok := module_spine.size() == SPINE_NAMES.size()
	if spine_ok:
		for nm in SPINE_NAMES:
			if not module_spine.has(nm):
				spine_ok = false
	print("spine set pinned: %s" % spine_ok)
	## Node shape under the root.
	var blades := 0
	var posts := 0
	for c in root.get_children():
		if c.name.begins_with("Blade_"):
			blades += 1
		if c.name.begins_with("Post_"):
			posts += 1
	print("root nodes: %d blades / %d posts" % [blades, posts])
	## The corner count over the pinned set.
	var corners := 0
	for a in graph.intersection_count():
		if graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		for nm in graph.intersection_streets(a):
			if SPINE_NAMES.has(nm):
				corners += 1
				break
	print("pinned corners touching the spine: %d" % corners)
	for line: String in lines:
		print(line)
	quit(0)

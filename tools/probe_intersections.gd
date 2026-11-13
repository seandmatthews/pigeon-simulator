extends SceneTree
## (T-180 diagnostic) Prints the resident graph's T-180 intersection
## classification — the merged anchors, the pinned start set (district +
## arterial), the signal subset and a per-anchor dump — so the constants in
## `scripts/ames_traffic_graph.gd` stay checkable against the census §4
## record (downtown 20 / Campustown 13; the landed deltas noted in the
## ticket). Run:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/probe_intersections.gd


func _init() -> void:
	var graph := AmesTrafficGraph.new()
	var downtown := 0
	var campustown := 0
	var arterial := 0
	var signals := 0
	var lines: Array[String] = []
	for a in graph.intersection_count():
		var pin := graph.intersection_pin(a)
		var kind := "none"
		if pin == AmesTrafficGraph.PIN_DISTRICT:
			kind = graph.intersection_district(a)
		elif pin == AmesTrafficGraph.PIN_ARTERIAL:
			kind = "arterial"
		var pos := graph.node_pos(graph.intersection_head(a))
		if graph.intersection_is_signal(a):
			kind += "+SIGNAL"
			signals += 1
		if kind.begins_with("downtown"):
			downtown += 1
		elif kind.begins_with("campustown"):
			campustown += 1
		elif kind.begins_with("arterial"):
			arterial += 1
		lines.append("  %-20s a=%4d head=%4d (%8.1f, %8.1f) %s" % [kind, a,
				graph.intersection_head(a), pos.x, pos.z,
				graph.intersection_streets(a)])
	print("anchors: %d | downtown: %d | campustown: %d | arterial: %d | signals: %d"
			% [graph.intersection_count(), downtown, campustown, arterial, signals])
	lines.sort()
	for line: String in lines:
		print(line)
	quit(0)

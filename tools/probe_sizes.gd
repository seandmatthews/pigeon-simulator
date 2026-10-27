extends SceneTree
## One-shot size audit (T-138 follow-up review): boots Main headless, walks
## every visual (MeshInstance3D + every MultiMesh instance) and prints the
## instances whose largest world-space dimension exceeds THRESHOLD — the
## "enormous blobs" census. Run:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/probe_sizes.gd

const THRESHOLD := 8.0 ## Report anything whose max world dimension exceeds this (m).
const TOP_N := 60

var _main: Node
var _frames_waited := 0


func _initialize() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames_waited += 1
	if _frames_waited < 5:
		return false
	_audit()
	return true


func _audit() -> void:
	var rows: Array[Dictionary] = []
	_walk(_main, rows)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dim"] > b["dim"])
	print("=== instances with max world dimension > %.1f m (top %d of %d over threshold) ===" % [
			THRESHOLD, TOP_N, rows.size()])
	for i: int in mini(TOP_N, rows.size()):
		var r: Dictionary = rows[i]
		print("%7.2f m  %-28s  at (%7.1f, %6.1f, %7.1f)  %s" % [
				r["dim"], r["kind"], r["pos"].x, r["pos"].y, r["pos"].z, r["path"]])
	quit(0)


## Wraps one visual's world AABB into the row list.
func _collect(rows: Array[Dictionary], path: String, kind: String,
		local_aabb: AABB, xf: Transform3D) -> void:
	var world_aabb := xf * local_aabb
	var dim := world_aabb.size
	var biggest: float = maxf(maxf(dim.x, dim.y), dim.z)
	if biggest <= THRESHOLD:
		return
	rows.append({
		"dim": biggest,
		"kind": kind,
		"pos": world_aabb.get_center(),
		"path": path,
	})


func _walk(node: Node, rows: Array[Dictionary]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			_collect(rows, _path_of(mi), "Mesh", mesh.get_aabb(), mi.global_transform)
	elif node is MultiMeshInstance3D:
		var mmi := node as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm != null and mm.mesh != null:
			var mesh_aabb := mm.mesh.get_aabb()
			var count := mm.instance_count
			for i: int in count:
				_collect(rows, "%s#%d" % [_path_of(mmi), i], "MM:" + _mm_key(mmi),
						mesh_aabb, mmi.global_transform * mm.get_instance_transform(i))
	for child: Node in node.get_children():
		_walk(child, rows)


## The city's MultiMesh nodes are nameless children of one holder — use the
## parent holder name + index as a stable stand-in key.
func _mm_key(mmi: MultiMeshInstance3D) -> String:
	if mmi.name != "" and not String(mmi.name).begins_with("@"):
		return String(mmi.name)
	return "%s/%d" % [_path_of(mmi.get_parent()), mmi.get_index()]


func _path_of(node: Node) -> String:
	var parts: Array[String] = []
	var cur: Node = node
	while cur != null and cur != _main:
		parts.push_front(String(cur.name))
		cur = cur.get_parent()
	return "Main/" + "/".join(parts)

extends Node3D
## T-209 memory-audit tool: the resident Ames world's per-family cost table,
## measured headless (no assertions — a measurement tool, the ledger's source).
## Run from the repo root:
##   godot --headless --path . res://tests/tools/ames_audit.tscn
## Prints one `AUDIT family=<name> nodes=N mm=N mm_inst=N mesh=N` line per
## family root (direct child of the world root or of a chunk node), plus
## `AUDIT totals` lines — render_metrics' bake-metric numbers (the same
## buffer_bytes the render-budget gate pins), the whole-subtree node/instance
## counts, the physics-shape count and the engine's memory info. The bake
## families (Massing/Ribbons/Patches/Placeholders) and the runtime hero/dress
## families separate cleanly, so the chunk payload vs hero scene cost split is
## readable straight off the table.

const AMES_WORLD_SCENE: PackedScene = preload("res://scenes/ames_world.tscn")

## Trailing digit runs are merged (Clock0/Clock1, Butterfly3, LotFlats2 …)
## so repeated family members bucket under one name.
func _family_key(node: Node) -> String:
	var re := RegEx.new()
	re.compile("[0-9]+$")
	return re.sub(node.name, "", true)


func _ready() -> void:
	var world := AMES_WORLD_SCENE.instantiate() as AmesWorld
	add_child(world)
	await get_tree().physics_frame
	await get_tree().process_frame
	var m: Dictionary = world.render_metrics()
	print("AUDIT render_metrics mm_nodes=%d instances=%d buffer_bytes=%d chunks=%d" % [
			m.mm_nodes, m.instances, m.buffer_bytes, m.chunk_count])
	var buckets: Dictionary = {}
	_bucket(world, buckets)
	var total_nodes := 0
	var total_mm := 0
	var total_mm_inst := 0
	var total_mesh := 0
	var total_shapes := 0
	var keys: Array = buckets.keys()
	keys.sort()
	for key: String in keys:
		var b: Dictionary = buckets[key]
		print("AUDIT family=%s nodes=%d mm=%d mm_inst=%d mesh=%d shapes=%d" % [
				key, b.nodes, b.mm, b.mm_inst, b.mesh, b.shapes])
		total_nodes += b.nodes
		total_mm += b.mm
		total_mm_inst += b.mm_inst
		total_mesh += b.mesh
		total_shapes += b.shapes
	print("AUDIT totals nodes=%d mm=%d mm_inst=%d mesh=%d shapes=%d" % [
			total_nodes, total_mm, total_mm_inst, total_mesh, total_shapes])
	var mem: Dictionary = OS.get_memory_info()
	print("AUDIT engine_mem static=%d physical=%d stack=%d" % [
			mem.get("static", 0), mem.get("physical", 0), mem.get("stack", 0)])
	get_tree().quit()


## Every node under `root` buckets under the nearest family root: a direct
## child of the world root, or a direct child of a chunk node (the bake
## families and the mounted heroes both live there). The family roots
## themselves count into their own bucket.
func _bucket(world: Node3D, buckets: Dictionary) -> void:
	var chunks_root: Node = world.get_node_or_null("Chunks")
	var stack: Array[Array] = [[world, "_world_root"]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var key: String = entry[1]
		if node != world:
			var b: Dictionary = buckets.get_or_add(key, _new_bucket())
			b.nodes += 1
			if node is MultiMeshInstance3D:
				b.mm += 1
				var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
				if mm != null:
					b.mm_inst += mm.instance_count
			elif node is MeshInstance3D:
				b.mesh += 1
			elif node is CollisionShape3D or node is CollisionObject3D:
				b.shapes += 1
		for child in node.get_children():
			var child_key := key
			if node == world or node == chunks_root:
				child_key = _family_key(child)
			stack.append([child, child_key])


func _new_bucket() -> Dictionary:
	return {"nodes": 0, "mm": 0, "mm_inst": 0, "mesh": 0, "shapes": 0}

class_name AmesWorld
extends City
## The resident Ames world root (T-173) — the runtime half of bake-then-render.
## Instantiates the committed T-172 chunk bake (`data/ames/chunks/`, the
## `AmesBaker` output) once at build: ~172 chunks, each a small node family of
## frustum-cullable MultiMeshes (massing boxes, ground rectangles, lake/park
## triangles) plus one baked `ArrayOccluder3D` — resident, NO streaming
## (master plan §2: streaming is the conditional upgrade path, built only if
## the perf gate demands, never on spec). Massing fades by distance band;
## heroes mount into their chunk (`mount_hero`, T-175+); lighting stays the
## one-sun contract — vertex-colored massing, no per-building lights, ever.
##
## Selection: the `world` setting (`Game.world`, "windrow" | "ames", default
## "windrow" — the suite stays byte-green until T-177 flips the default).
## main.tscn keeps the Windrow `City` scene; `Main._ready` swaps THIS root in
## when the setting says "ames". Gameplay never knows which world is live: the
## class extends `City`, so every public API gameplay reads — the spawn
## corridor, `home_radius()`, `to_global`/`to_local`, `regenerated`, the
## stepped-boot slices — answers with identical signatures, implemented over
## chunk data. The Windrow arrays that have no Ames counterpart yet (the block
## grid, bread spots, cafe tables, the route graph) stay EMPTY until their
## re-base tickets (T-176/T-178+) fill them; every consumer already handles an
## empty world (the spawners early-return on empty block centers / spot lists).
##
## Collision story (the bake bakes none, by ticket): the world carries ONE
## flat ground plate (physics + visual, bounds derived from the manifest)
## under the bake's stacked flats (water 0.02 … ballast 0.1 — the baker's y
## conventions leave y 0 for exactly this plate), and the gameplay seam
## answers "how high is the massing here" as a query, not geometry:
## `ground_height()` scans the retained per-chunk ground records. Roofs become
## landable in T-175 (placeholder collision), not here.
##
## Boot cost discipline: each chunk file is read once, its SHA-256 checked
## against the bake manifest (a corrupted bake refuses the chunk, loudly), the
## geometry becomes GPU buffers + compact ground records, and the parsed JSON
## is DROPPED — the resident footprint stays proportional to the geometry, not
## the JSON. `render_metrics()` is the machine-readable feed the perf gate
## (`ames_world_render_budget`) holds under budget.

const WORLD_ID := "ames"
const CHUNKS_DIR := "res://data/ames/chunks"

## The ground plate grows this far beyond the manifest's outermost chunk AABB
## on every side (m) — the same apron idea as City.ground_extra, sized off the
## bake instead of the grid.
const GROUND_MARGIN := 250.0
## Ground rectangle boxes (street ribbons, creeks, ballast) are baked flat at
## one y; they render as boxes this thick, centered on the baked y (each
## family keeps its 0.02+ m stack separation — no z-fighting).
const FLAT_THICKNESS := 0.02
## Plate visual/physics thickness (m) — top face at y 0.
const PLATE_THICKNESS := 1.0
## (T-173 first values, tuned on measurement) Massing fades out between
## MASSING_RANGE_END − MASSING_RANGE_FADE and MASSING_RANGE_END from the
## camera, dithered. Ribbons/tri patches never fade — the ground read is the
## skeleton's recognition layer (T-174 dresses it). Retune at Gate 3.
const MASSING_RANGE_END := 1800.0
const MASSING_RANGE_FADE := 250.0
## Plate ground color — a muted lawn base under the bake's stacked flats.
## T-174's district ground palettes own the real dressing.
const COLOR_GROUND := Color(0.38, 0.46, 0.30)

## Per-chunk ground records, keyed by tile Vector2i(cx, cz): `ground` —
## PackedFloat32Array, 5 floats per massing box (x, z, half_w, half_d, top)
## in world-local coordinates — the `ground_height()` feed.
var _chunks: Dictionary = {}
var _chunks_root: Node3D
## The bake manifest as read (`{}` = no bake — the world builds empty and
## every gate fails loudly on the missing chunks).
var _manifest: Dictionary = {}
## Cached baker district-rule context (`AmesBaker._build_context`), built once
## on first `district_at()`.
var _district_ctx: Dictionary = {}
## Per-chunk MultiMesh tally — the worst-case draw-call ceiling.
var _mm_count: int = 0
## Chunk NODES built — distinct from `_chunks.size()`, which since the
## round-1 tile-crossing fix counts ground-record TILES (a tile also gains
## an entry when a neighbor's box crosses into it, and a flats-only chunk
## has no record at all).
var _chunk_count: int = 0
## Total MultiMesh instances built (massing + ground rectangles + tris).
var _instance_count: int = 0
## Resident buffer estimate (bytes): MultiMesh transforms+colors, occluder
## vertices and the ground records.
var _buffer_bytes: int = 0
## World bounds (world-local) over the manifest chunk AABBs; the ground plate
## and `home_radius()` derive from it.
var _bounds_min := Vector3.ZERO
var _bounds_max := Vector3.ZERO

@onready var _box_mesh: BoxMesh = _make_box_mesh()
@onready var _tri_mesh: ArrayMesh = _make_tri_mesh()


## The world id this class serves (the `Game.world` value that selects it).
func world_id() -> String:
	return WORLD_ID


## The map's ground answers "how high is the walkable surface at this world
## position": the top of the tallest massing box covering the XZ point, or
## 0.0 (the ground plate) where no box stands. The T-176 bread/roof re-base
## and the traffic re-base build on this instead of physics raycasts.
func ground_height(pos: Vector3) -> float:
	var local := to_local(pos)
	var record: Dictionary = _chunks.get(_tile_of_local(local), {})
	var boxes: PackedFloat32Array = record.get("ground", PackedFloat32Array())
	var top := 0.0
	for i in range(0, boxes.size(), 5):
		if local.x >= boxes[i] - boxes[i + 2] and local.x <= boxes[i] + boxes[i + 2] \
				and local.z >= boxes[i + 1] - boxes[i + 3] and local.z <= boxes[i + 1] + boxes[i + 3]:
			top = maxf(top, boxes[i + 4])
	return top


## Which chunk tile a world position falls in (the baker's floor division).
func chunk_of(pos: Vector3) -> Vector2i:
	return _tile_of_local(to_local(pos))


## The district the baker's v0 rule assigns a world position to — the SAME
## rule that colored the chunk massing (`AmesBaker._district_of` over the pack
## street/anchor clouds), so a lookup never disagrees with the baked dressing.
func district_at(pos: Vector3) -> String:
	var local := to_local(pos)
	if _district_ctx.is_empty():
		_district_ctx = AmesBaker._build_context()
	return AmesBaker._district_of(local.x, local.z, _district_ctx)


## The chunk's world-space content AABB (from the manifest), or an empty AABB
## for an unknown tile.
func chunk_aabb(tile: Vector2i) -> AABB:
	var entry := _manifest_entry(tile)
	if entry.is_empty():
		return AABB()
	var aabb: Dictionary = entry["aabb"]
	var lo := Vector3(aabb["min"][0], aabb["min"][1], aabb["min"][2])
	var hi := Vector3(aabb["max"][0], aabb["max"][1], aabb["max"][2])
	return AABB(lo, hi - lo)


## Mounts an authored hero scene INTO its chunk (T-175+): the instance is
## parented under the chunk's node — chunk lifecycle, culling and LOD swaps
## are the chunk's business — and offset by the tile center so an origin
## authored in world coordinates stays at its true world position. Returns
## the instance (null when the tile has no chunk — nothing was mounted).
func mount_hero(tile: Vector2i, scene: PackedScene) -> Node3D:
	var chunk := get_node_or_null("Chunks/Chunk_%d_%d" % [tile.x, tile.y]) as Node3D
	if chunk == null:
		push_warning("AmesWorld: no chunk %s — hero not mounted" % tile)
		return null
	var hero := scene.instantiate() as Node3D
	chunk.add_child(hero)
	hero.position += _tile_center(tile) ## Authored world origins stay world-space.
	return hero


## The off-world guard's home center — the BAKE BOUNDS center, world-owned.
## NOT the world origin: the pack origin (Lincoln Way × Welch) sits on the
## map's west edge, and a guard circle pinned there left 46% of the massing
## outside the radius — the T-023 nudge banked the pigeon home over half the
## skeleton and the edge hint showed over downtown (round-1 review, live
## A/B recorded). The bounds center holds the whole map.
func home_center() -> Vector3:
	return to_global((_bounds_min + _bounds_max) * 0.5)


## The off-world guard's home radius (m) — Main wires it once at boot. The
## half-DIAGONAL of the bake bounds plus the apron margin: a circle around
## the bounds center must reach every chunk AABB's corners, not just the
## farthest axis extent (the round-1 review's containment arm asserts it).
func home_radius() -> float:
	var half := (_bounds_max - _bounds_min) * 0.5
	return Vector2(half.x, half.z).length() + GROUND_MARGIN


## The resident render metrics — the perf gate's feed: `mm_nodes` (chunk
## MultiMeshes = the worst-case draw-call ceiling, every chunk visible),
## `instances`, `buffer_bytes`, `chunk_count`.
func render_metrics() -> Dictionary:
	return {
		"mm_nodes": _mm_count,
		"instances": _instance_count,
		"buffer_bytes": _buffer_bytes,
		"chunk_count": _chunk_count,
		"bounds_min": _bounds_min,
		"bounds_max": _bounds_max,
	}


## --- the stepped build (the City slice contract, over the bake) ----------


## Slice 1 of 3 — "ground/slabs": state reset, manifest read, the ground plate
## (physics + visual). Same-seed fast path identical to the parent's (restarts
## skip the rebuild and re-emit `regenerated` only).
func generate_step_ground(new_seed: int = seed_value, force_rebuild: bool = false) -> bool:
	if fingerprint != 0 and new_seed == seed_value and not force_rebuild:
		regenerated.emit()
		return false
	seed_value = new_seed
	build_count += 1
	_clear()
	_chunks = {}
	_chunks_root = null
	_district_ctx = {}
	_mm_count = 0
	_chunk_count = 0
	_instance_count = 0
	_buffer_bytes = 0
	_bounds_min = Vector3.ZERO
	_bounds_max = Vector3.ZERO
	_manifest = AmesBaker.read_manifest(CHUNKS_DIR)
	if _manifest.is_empty():
		push_error("AmesWorld: no chunk bake at %s — world builds empty" % CHUNKS_DIR)
		return true
	if (_manifest.get("chunks", []) as Array).is_empty():
		push_error("AmesWorld: bake manifest carries no chunks — world builds empty")
		return true
	_bounds_from_manifest()
	_build_static_root()
	_build_ground_plate()
	_chunks_root = _make_chunks_root()
	return true


## Slice 2 of 3 — "buildings": every chunk of the bake becomes its node family.
func generate_step_blocks() -> void:
	for entry: Dictionary in _manifest.get("chunks", []):
		_build_chunk(entry)


## Slice 3 of 3 — "visuals" analog: the spawn corridor, the report, the
## fingerprint and the `regenerated` emission close the build exactly as the
## parent's slice does.
func generate_step_finish() -> void:
	## The spawn corridor equivalent (T-173): a drop over the pack origin —
	## Lincoln Way × Welch, the campus/Campustown seam. Streets carry no
	## building footprints, so the crossing is massing-clear by construction
	## (`ames_world_api_seam` asserts it from the committed data); T-176 moves
	## the survival spawn to Central Campus and re-pins this.
	spawn_point = to_global(Vector3(0.0, spawn_drop_height, 0.0))
	last_report = {
		"world": WORLD_ID,
		"chunks": _chunks.size(),
		"buildings": int(_manifest.get("totals", {}).get("massing", 0)),
		"instances": _instance_count,
		"mm_nodes": _mm_count,
		"buffer_bytes": _buffer_bytes,
		"span_x": _bounds_max.x - _bounds_min.x,
		"span_z": _bounds_max.z - _bounds_min.z,
	}
	## Deterministic identity: the bake manifest's total hash — a re-bake that
	## moves a byte moves the fingerprint, exactly the layout-fingerprint
	## discipline the parent's seed hash serves.
	fingerprint = str(_manifest.get("total_sha256", "")).hash()
	regenerated.emit()


## The synchronous build — the parent's exact slice composition.
func generate(new_seed: int = seed_value, force_rebuild: bool = false) -> void:
	if generate_step_ground(new_seed, force_rebuild):
		generate_step_blocks()
		generate_step_finish()


## --- construction ---------------------------------------------------------


func _bounds_from_manifest() -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for entry: Dictionary in _manifest.get("chunks", []):
		var aabb: Dictionary = entry["aabb"]
		lo = lo.min(Vector3(aabb["min"][0], aabb["min"][1], aabb["min"][2]))
		hi = hi.max(Vector3(aabb["max"][0], aabb["max"][1], aabb["max"][2]))
	_bounds_min = lo
	_bounds_max = hi


## One layer-1 `world` StaticBody root so the inherited `_add_collider`
## helpers keep the Windrow physics conventions (the `_group` pattern).
func _build_static_root() -> void:
	_static_root = Node3D.new()
	_static_root.name = "Static"
	add_child(_static_root)


func _make_chunks_root() -> Node3D:
	var root := Node3D.new()
	root.name = "Chunks"
	add_child(root)
	return root


## The ground plate: one physics box (top at y 0, layer 1) + one visual slab
## under the bake's stacked flats (the baker's y conventions reserve y 0 for
## exactly this plate). Bounds = manifest extents + GROUND_MARGIN per side.
func _build_ground_plate() -> void:
	var size := _bounds_max - _bounds_min + Vector3.ONE * (GROUND_MARGIN * 2.0)
	var center := (_bounds_min + _bounds_max) * 0.5
	_add_collider("Ground", Vector3(size.x, PLATE_THICKNESS, size.z),
			Vector3(center.x, -PLATE_THICKNESS * 0.5, center.z))
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, PLATE_THICKNESS, size.z)
	mesh.material = _flat_material(COLOR_GROUND)
	slab.mesh = mesh
	slab.position = Vector3(center.x, -PLATE_THICKNESS * 0.5, center.z)
	_static_root.add_child(slab)


## One chunk of the bake → one node family. The chunk node sits at the tile
## center (visibility ranges and the custom AABBs measure from it), all
## geometry chunk-local. The file's SHA-256 must match the manifest before it
## renders — a corrupted bake refuses the chunk loudly, never silently.
func _build_chunk(entry: Dictionary) -> void:
	var tile := Vector2i(int(entry["cx"]), int(entry["cz"]))
	var path := CHUNKS_DIR.path_join(str(entry["file"]))
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("AmesWorld: cannot read %s — chunk skipped" % path)
		return
	var sha := _sha256(text.to_utf8_buffer())
	if sha != str(entry["sha256"]):
		push_error("AmesWorld: %s sha mismatch (%s != %s) — chunk skipped"
				% [path, sha, entry["sha256"]])
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("AmesWorld: %s is not a chunk document — chunk skipped" % path)
		return
	var chunk: Dictionary = parsed
	var center := _tile_center(tile)
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [tile.x, tile.y]
	chunk_root.position = center
	_chunks_root.add_child(chunk_root)
	_chunk_count += 1
	var aabb := _local_aabb(entry, center)

	var massing := _massing_multimesh(chunk, center)
	if massing != null:
		_add_chunk_mm(chunk_root, "Massing", massing, aabb,
				MASSING_RANGE_END, MASSING_RANGE_FADE)

	var flats := _flats_multimesh(chunk, center)
	if flats != null:
		_add_chunk_mm(chunk_root, "Ribbons", flats, aabb, 0.0, 0.0)

	var tris := _tris_multimesh(chunk, center)
	if tris != null:
		_add_chunk_mm(chunk_root, "Patches", tris, aabb, 0.0, 0.0)

	_build_chunk_occluder(chunk_root, chunk, center)
	_build_ground_record(chunk)


## One vertex-color unit-box MultiMesh from the chunk's massing entries
## (position/size/vertex color straight from the bake — the city.gd house
## style, ported to data).
func _massing_multimesh(chunk: Dictionary, center: Vector3) -> MultiMesh:
	var massing: Array = chunk.get("massing", [])
	if massing.is_empty():
		return null
	var mm := _new_multimesh(massing.size())
	for i in massing.size():
		var m: Dictionary = massing[i]
		var p: Array = m["p"]
		var s: Array = m["s"]
		var c: Array = m["c"]
		mm.set_instance_transform(i, Transform3D(
				Basis.from_scale(Vector3(s[0], s[1], s[2])),
				Vector3(p[0], p[1], p[2]) - center))
		mm.set_instance_color(i, Color(c[0], c[1], c[2]))
	return mm


## One vertex-color unit-box MultiMesh of every baked ground rectangle —
## street ribbons, creek quads and rail ballast are all rectangles, so all
## three families share the massing's box mesh at their own per-instance
## baked family color (`chunk.colors`). Never fades: the ground read stays.
func _flats_multimesh(chunk: Dictionary, center: Vector3) -> MultiMesh:
	var colors: Dictionary = chunk.get("colors", {})
	var entries: Array = []
	for family: String in ["ribbons", "creek_quads", "ballast_quads"]:
		var flat_color: Array = colors.get(family, [0.5, 0.5, 0.5])
		for q: Dictionary in chunk.get(family, []):
			entries.append([q["q"], flat_color])
	if entries.is_empty():
		return null
	var mm := _new_multimesh(entries.size())
	for i in entries.size():
		var e: Array = entries[i]
		mm.set_instance_transform(i, _flat_quad_box_xf(e[0], center))
		var c: Array = e[1]
		mm.set_instance_color(i, Color(c[0], c[1], c[2]))
	return mm


## One vertex-color unit-triangle MultiMesh of the lake/park flats — arbitrary
## triangles, so they get their own primitive (double-sided material; winding
## never hides a flat). Per-instance baked family color.
func _tris_multimesh(chunk: Dictionary, center: Vector3) -> MultiMesh:
	var colors: Dictionary = chunk.get("colors", {})
	var entries: Array = []
	for family: String in ["water_tris", "lawn_tris"]:
		var flat_color: Array = colors.get(family, [0.5, 0.5, 0.5])
		for t: Dictionary in chunk.get(family, []):
			entries.append([t["v"], flat_color])
	if entries.is_empty():
		return null
	var mm := _new_multimesh(entries.size(), _tri_mesh)
	for i in entries.size():
		var e: Array = entries[i]
		var v: Array = e[0]
		var p0 := Vector3(v[0], v[1], v[2])
		var p1 := Vector3(v[3], v[4], v[5])
		var p2 := Vector3(v[6], v[7], v[8])
		mm.set_instance_transform(i, Transform3D(
				Basis(p1 - p0, Vector3.UP, p2 - p0), p0 - center))
		var c: Array = e[1]
		mm.set_instance_color(i, Color(c[0], c[1], c[2]))
	return mm


## The baked occluders: one ArrayOccluder3D per chunk — each massing box's
## four side walls as triangle soup (both windings; the engine's occlusion
## raster culls whichever facing it wants). Heights ride the index-aligned
## massing entry (the bake writes one outline per box, 1:1).
func _build_chunk_occluder(chunk_root: Node3D, chunk: Dictionary, center: Vector3) -> void:
	var outlines: Array = chunk.get("occluders", [])
	var massing: Array = chunk.get("massing", [])
	if outlines.is_empty():
		return
	var verts := PackedVector3Array()
	for i in outlines.size():
		var o: Array = outlines[i]
		var top := 0.0
		if i < massing.size():
			top = float(massing[i]["s"][1])
		var corners: Array[Vector2] = []
		for k in 4:
			corners.append(Vector2(float(o[k * 2]), float(o[k * 2 + 1]))
					- Vector2(center.x, center.z))
		for k in 4:
			var a := corners[k]
			var b := corners[(k + 1) % 4]
			var a_lo := Vector3(a.x, 0.0, a.y)
			var b_lo := Vector3(b.x, 0.0, b.y)
			var a_hi := a_lo + Vector3.UP * top
			var b_hi := b_lo + Vector3.UP * top
			verts.append_array([a_lo, b_lo, b_hi, a_lo, b_hi, a_hi]) ## Outward.
			verts.append_array([a_lo, b_hi, b_lo, a_lo, a_hi, b_hi]) ## Inward twin.
	var occ := ArrayOccluder3D.new()
	occ.vertices = verts ## Godot 4.7's ArrayOccluder3D: vertex soup + sequential indices.
	var idx := PackedInt32Array()
	idx.resize(verts.size())
	for i in verts.size():
		idx[i] = i
	occ.indices = idx
	var occ_instance := OccluderInstance3D.new()
	occ_instance.name = "Occluder"
	occ_instance.occluder = occ
	chunk_root.add_child(occ_instance)
	_buffer_bytes += verts.size() * 3 * 4 ## PackedVector3Array: 3 floats/vertex.


## The compact ground record the seam queries: per box (x, z, half_w, half_d,
## top) in WORLD-LOCAL coordinates (the `ground_height()` query frame). Each
## box is indexed into EVERY tile its footprint touches — 401 of 3,737 baked
## boxes cross a 256 m tile edge (round-1 review: worst overhang 77 m), and a
## centroid-tile-only filing answered the plate (0.0) for points standing
## under those overhangs. The parsed JSON is dropped after this, so the
## resident footprint stays proportional to the geometry (the crossing
## duplicates add ~25 KB).
func _build_ground_record(chunk: Dictionary) -> void:
	var tiles: Dictionary = {} ## tile Vector2i -> Array of floats, packed below.
	var bytes := 0
	for m: Dictionary in chunk.get("massing", []):
		var p: Array = m["p"]
		var s: Array = m["s"]
		var cx := float(p[0])
		var cz := float(p[2])
		var hw := float(s[0]) * 0.5
		var hd := float(s[2]) * 0.5
		var top := float(p[1]) + float(s[1]) * 0.5
		var entry: Array = [cx, cz, hw, hd, top]
		var s_size := AmesBaker.CHUNK_SIZE
		var tx0 := floori((cx - hw) / s_size)
		var tx1 := floori((cx + hw) / s_size)
		var tz0 := floori((cz - hd) / s_size)
		var tz1 := floori((cz + hd) / s_size)
		for tx in range(tx0, tx1 + 1):
			for tz in range(tz0, tz1 + 1):
				var key := Vector2i(tx, tz)
				var arr: Array = tiles.get(key, [])
				arr.append_array(entry)
				tiles[key] = arr
				bytes += entry.size() * 4
	for key: Vector2i in tiles:
		var packed := PackedFloat32Array(tiles[key])
		var record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = record.get("ground", PackedFloat32Array())
		ground.append_array(packed)
		record["ground"] = ground
		_chunks[key] = record
	_buffer_bytes += bytes


## --- chunk node plumbing ---------------------------------------------------


func _new_multimesh(count: int, mesh: Mesh = null) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh if mesh != null else _box_mesh
	mm.instance_count = count
	return mm


## One chunk MultiMeshInstance3D: frustum-cullable via the chunk's manifest
## AABB (`custom_aabb`, chunk-local), optional distance fade (the massing
## band). Updates the resident metrics.
func _add_chunk_mm(chunk_root: Node3D, node_name: String, mm: MultiMesh,
		aabb: AABB, range_end: float, range_fade: float) -> void:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	mm.custom_aabb = aabb
	if range_end > 0.0:
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = range_fade
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	chunk_root.add_child(node)
	_mm_count += 1
	_instance_count += mm.instance_count
	_buffer_bytes += mm.instance_count * (12 + 4) * 4 ## Transform + color floats.


func _tile_center(tile: Vector2i) -> Vector3:
	var s := AmesBaker.CHUNK_SIZE
	return Vector3((float(tile.x) + 0.5) * s, 0.0, (float(tile.y) + 0.5) * s)


func _tile_of_local(local: Vector3) -> Vector2i:
	var s := AmesBaker.CHUNK_SIZE
	return Vector2i(floori(local.x / s), floori(local.z / s))


func _local_aabb(entry: Dictionary, center: Vector3) -> AABB:
	var aabb: Dictionary = entry["aabb"]
	var lo := Vector3(aabb["min"][0], aabb["min"][1], aabb["min"][2]) - center
	var hi := Vector3(aabb["max"][0], aabb["max"][1], aabb["max"][2]) - center
	return AABB(lo, hi - lo)


func _manifest_entry(tile: Vector2i) -> Dictionary:
	for entry: Dictionary in _manifest.get("chunks", []):
		if Vector2i(int(entry["cx"]), int(entry["cz"])) == tile:
			return entry
	return {}


## A baked ground rectangle (4 corners) as one thin box: the quad's own axes
## are orthogonal (`AmesBaker._extrude_quad` extrudes across the segment
## normal), so the instance basis is the quad frame scaled to its extents,
## centered on the baked y (thickness stacks clear of the neighbors).
func _flat_quad_box_xf(q: Array, center: Vector3) -> Transform3D:
	var c0 := Vector3(q[0], q[1], q[2])
	var c1 := Vector3(q[3], q[4], q[5])
	var c2 := Vector3(q[6], q[7], q[8])
	var c3 := Vector3(q[9], q[10], q[11])
	var across := c1 - c0
	var along := c3 - c0
	var center_quad := (c0 + c1 + c2 + c3) * 0.25
	return Transform3D(
			Basis(across.normalized() * across.length(),
					Vector3.UP * FLAT_THICKNESS,
					along.normalized() * along.length()),
			center_quad - center)


## --- shared meshes/materials ----------------------------------------------


func _make_box_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = _make_vertex_color_material()
	return mesh


## One unit right triangle; instances map it onto each baked triangle.
## Double-sided so winding never hides a flat.
func _make_tri_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP,
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := _make_vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh


func _make_vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	return mat


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat


func _sha256(bytes: PackedByteArray) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(bytes)
	return hc.finish().hex_encode()

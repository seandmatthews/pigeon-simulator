class_name AmesWorld
extends City
## The resident Ames world root (T-173) — the runtime half of bake-then-render.
## Instantiates the committed T-172 chunk bake (`data/ames/chunks/`, the
## `AmesBaker` output) once at build: ~172 chunks, each a small node family of
## frustum-cullable MultiMeshes (massing boxes, ground rectangles, lake/park
## triangles) plus one baked `ArrayOccluder3D` — resident, NO streaming
## (master plan §2: streaming is the conditional upgrade path, built only if
## the perf gate demands, never on spec). Massing fades by distance band
## (the T-175 placeholder silhouettes never fade — the from-the-air read is
## the point); authored hero SCENES mount into their chunk (`mount_hero`,
## R3); lighting stays the
## one-sun contract — vertex-colored massing, no per-building lights, ever.
##
## Selection: the `world` setting (`Game.world`, default AND only value "ames"
## since the T-177 cutover — the Windrow generate path was retired, no debug
## toggle; main.tscn keeps the staged Windrow `City` scene and `Main._ready`
## swaps THIS root in on every boot). Gameplay never knows which world is live: the
## class extends `City`, so every public API gameplay reads — the spawn
## corridor, `home_radius()`, `to_global`/`to_local`, `regenerated`, the
## stepped-boot slices — answers with identical signatures, implemented over
## chunk data. The Windrow arrays that have no Ames counterpart yet (the block
## grid, bread spots, cafe tables, the route graph) stay EMPTY until their
## re-base tickets (T-176/T-178+) fill them; every consumer already handles an
## empty world (the spawners early-return on empty block centers / spot lists).
##
## Collision story (T-175): the world carries ONE flat ground plate (physics +
## visual, bounds derived from the manifest) under the bake's stacked flats
## (water 0.02 … ballast 0.1 — the baker's y conventions leave y 0 for exactly
## this plate), the gameplay seam answers "how high is the massing here" as a
## query, not geometry (`ground_height()` scans the retained per-chunk ground
## records), and every AUTHORED position is solid — one placeholder StaticBody
## per chunk carrying box shapes for the authored massing slots (the bake's
## `a` flag), the hero silhouette parts (true-dim stand-ins for the R3 hero
## scenes — the campanile cap's top face is the landable pad, crumb spot at
## `ANCHOR_CRUMB_LIFT`) and the venue fixups. Procedural filler stays
## visual-only.
##
## Boot cost discipline: each chunk file is read once, its SHA-256 checked
## against the bake manifest (a corrupted bake refuses the chunk, loudly), the
## geometry becomes GPU buffers + compact ground records, and the parsed JSON
## is DROPPED — the resident footprint stays proportional to the geometry, not
## the JSON. `render_metrics()` is the machine-readable feed the perf gate
## (`ames_world_render_budget`) holds under budget.
##
## Survival re-base (T-176): the world FILLS the arrays the survival loop
## reads — `bread_spots`/`bread_spot_kinds` and `cafe_spots` were empty until
## this ticket — and re-pins `spawn_point` over Central Campus near the
## campanile (owner-decided 2026-11-09, master plan §11.1). Everything is a
## pure function of the committed data (pack + bake), zero RNG of any stream:
## the Windrow T-005/T-031/T-032 placement patterns re-targeted onto the real
## map. Ground rings run the named anchor streets (downtown Main, Campustown
## Welch) dense, every other named street and the creek centerlines wide, the
## four pinned parks (the census §5 named-park stock's top four: Brookside,
## ISU Arboretum, Stuart Smith, Central Campus) as a grid clipped to their
## polygons, and the Lake LaVerne shore as an outward ring; roof crumbs ride
## every authored building (the bake's `a` slots — the T-032 pattern over the
## 512-name list) plus large filler, with the hero silhouettes filing their
## own true-dim tops (the campanile keeps its pinned cap crumb); café tables
## re-target the sidewalk-café system onto the VENUES.md café list — a table
## just out from each café venue's street-facing door, one TABLE bread spot
## riding the tabletop exactly as `City._build_cafe_spots` seats it. A final
## field lattice pins the district-wide reach bar (`ames_bread_reach`:
## nearest spot ≤ 150 m from ANY sampled point of the pack's core window —
## the open prairie/farmland tracts host no buildings or streets, and the
## master plan's own line is "bread must exist district-wide, not
## plaza-only"). Hunger and favor are untouched here: the drain quartet and
## the ceiling-100 economy stay the Windrow pins, byte-identical
## (`ames_hunger_pins` diff-proves it).

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
## skeleton's recognition layer (T-174 dressed it). Retune at Gate 3.
const MASSING_RANGE_END := 1800.0
const MASSING_RANGE_FADE := 250.0
## The flat rect families the renderer folds into ONE box MultiMesh per
## chunk — the bake's ribbons plus the T-174 dressing (district ground
## cells, arterial lane dashes, LaVerne shore band, rail tie stripe). All
## are baked rectangles with a family color from `chunk.colors` (ground
## cells override per entry with their district color).
const FLAT_FAMILIES: Array[String] = [
	"ground_quads", "ribbons", "lane_quads", "shore_quads", "creek_quads",
	"ballast_quads", "tie_quads",
]

## --- T-176 survival re-base constants --------------------------------------
## Every value below is placement data law, pinned by `ames_bread_reach` /
## `ames_hunger_pins` the way the bake pins pin the renderer. Hunger and favor
## constants are deliberately NOT here — the ticket freezes them.

## The spawn (master plan §11.1): the campanile POI's position plus this far
## EAST, at the ground plate plus `spawn_drop_height` — over the Central
## Campus lawn, massing-clear by construction, the lake + campanile on one
## screen behind the pigeon's west-facing nose, Lincoln Way one dive south.
const SPAWN_CAMPANILE_OFFSET_X := 40.0
## The campanile POI id in the pack (its `position` is the census literal the
## spawn derives from; the hero placeholder/cap collider sits on the same way).
const CAMPANILE_POI_ID := "campanile"
## The four pinned parks (census §5 named-park stock's top four) — ground-ring
## grids clipped to their own pack polygons.
const PINNED_PARKS: Array[String] = [
	"Brookside Park", "ISU Arboretum", "Stuart Smith Park", "Central Campus",
]
## The venue-name tokens that mark a real café (VENUES.md's coffee inventory:
## Café Beaudelaire, The Cafe, The Grove Cafe, Stomping Grounds Cafe,
## Cafe Diem, Morning Bell Coffee Roasters, Mother's Pub & Coffee; Labyrinth
## Coffee is unplaced in the pack and rides no table). Matched lowercase.
const CAFE_NAME_TOKENS: Array[String] = ["cafe", "café", "coffee"]
## Ground-ring cadence and curb offset per layer. The named anchors are dense
## (Main Street downtown, Welch Avenue Campustown); every other named street
## serves its district wide; the creek centerlines thread the green corridors.
const ANCHOR_RING_STEP := 30.0
const ANCHOR_RING_OFFSET := 4.0
const STREET_RING_STEP := 150.0
const CREEK_RING_STEP := 100.0
const CREEK_RING_OFFSET := 3.0
## Park grid cadence (polygon-clipped) and the shore ring's offset off the
## lake edge.
const PARK_GRID_STEP := 100.0
const SHORE_OFFSET := 6.0
## The field lattice that pins the district-wide reach bar: one ground spot
## per cell over the pack's core window (one cell past each edge, so the
## window's own boundary samples stay covered — worst sample-to-spot is the
## half-cell diagonal, 141 m < the 150 m bar).
const FIELD_LATTICE_STEP := 200.0
## Roof crumbs ride every authored massing slot plus filler boxes at least
## this wide (the T-032 pattern over the 512-name list + the big sheds).
const FILLER_ROOF_MIN_DIM := 12.0
## Crumb lift over every surface the spots sit on — the T-032 roof-corner /
## ANCHOR_CRUMB_LIFT convention (City's constant is the cap crumb's same 0.06).
const SPOT_LIFT := 0.06
## The boot ring (round 1): how many of the GROUND spots nearest the spawn the
## BreadSpawner seeds FIRST on every populate (`City.boot_bread_spots`). At 40
## live crumbs across 11k+ spots the seeded shuffle alone landed the nearest
## crumb ~300 m out — the "first bread reachable ≤ 60 m" acceptance bar was a
## fact about the spot supply, not the spread. The nearest boot spot measured
## 20.6 m from the spawn; every populate re-seeds the ring, so the guarantee
## renews across restarts.
const BOOT_BREAD_COUNT := 8
## A ground-ring/lattice point whose query answers taller than this is inside
## a building footprint — dropped (the box's own roof spot serves it).
const GROUND_COVER_MAX := 0.5
## Café table outset off the venue POI along its street-facing direction (the
## venue fixup box is 10 m deep — 7 m clears its face by 2 m), walked out
## farther when another box still covers the point. The downtown Main wall is
## the deep case (Cafe Diem / Morning Bell sit mid-block on 14-15 m-deep
## lots, the sidewalk band 14-22 m out), so the ladder runs to 20 m — every
## step ground-guarded, nothing ever lands inside a box.
const CAFE_VENUE_OUTSET_STEPS: Array[float] = [7.0, 9.0, 11.0, 13.0, 16.0, 20.0]
## A café venue's table is placed only when the venue itself stands inside
## the baked world bounds (plus this slack) — the T-175 in-core rule: the
## out-of-core venues (The Cafe, Provisions, …) ride no furniture on land
## the world does not carry.
const CAFE_BOUNDS_SLACK := 60.0

## Per-chunk ground records, keyed by tile Vector2i(cx, cz): `ground` —
## PackedFloat32Array, 5 floats per massing box (x, z, half_w, half_d, top)
## in world-local coordinates — the `ground_height()` feed.
var _chunks: Dictionary = {}
var _chunks_root: Node3D
## The bake manifest as read (`{}` = no bake — the world builds empty and
## every gate fails loudly on the missing chunks).
var _manifest: Dictionary = {}
## (T-175) the hero building ids whose bbox massing the placeholder
## silhouettes supersede (the bake manifest's `heroes` list, as a set) —
## those boxes are skipped for drawing, occluding, ground records and slot
## colliders alike, so the silhouette IS the hero at every layer.
var _hero_ids: Dictionary = {}
## (T-175) the campanile cap's world-local position — the landable pad; the
## finish step hangs the cap crumb at `ANCHOR_CRUMB_LIFT` above it (the
## anchor-cap rule, re-targeted).
var _campanile_cap := Vector3.ZERO
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
## (T-176) Roof-crumb staging, filled while each chunk is built (the parsed
## chunk doc is only in hand there) and consumed by `generate_step_finish`:
## authored + large-filler massing tops, and the per-hero tallest placeholder
## part (true-dim silhouettes file their own tops — the superseded bbox
## massing is skipped). Cleared with the rest of the build state.
var _roof_spots: Array[Vector3] = []
var _hero_roof_tops: Dictionary = {}

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


## Mounts an authored hero scene INTO its chunk (R3 — T-175 bakes the
## placeholder stand-ins; this is the authored-scene seam): the instance is
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
	_hero_ids = {}
	_campanile_cap = Vector3.ZERO
	_roof_spots = []
	_hero_roof_tops = {}
	_manifest = AmesBaker.read_manifest(CHUNKS_DIR)
	if _manifest.is_empty():
		push_error("AmesWorld: no chunk bake at %s — world builds empty" % CHUNKS_DIR)
		return true
	if (_manifest.get("chunks", []) as Array).is_empty():
		push_error("AmesWorld: bake manifest carries no chunks — world builds empty")
		return true
	for hero_id: Variant in _manifest.get("heroes", []):
		_hero_ids[str(hero_id)] = true
	_bounds_from_manifest()
	_build_static_root()
	_build_ground_plate()
	_chunks_root = _make_chunks_root()
	return true


## Slice 2 of 3 — "buildings": every chunk of the bake becomes its node family.
func generate_step_blocks() -> void:
	for entry: Dictionary in _manifest.get("chunks", []):
		_build_chunk(entry)


## Slice 3 of 3 — "visuals" analog: the survival re-base (T-176 — spawn,
## bread spots, café tables), then the report, the fingerprint and the
## `regenerated` emission close the build exactly as the parent's slice does.
func generate_step_finish() -> void:
	_build_survival()
	last_report = {
		"world": WORLD_ID,
		"chunks": _chunks.size(),
		"buildings": int(_manifest.get("totals", {}).get("massing", 0)),
		"instances": _instance_count,
		"mm_nodes": _mm_count,
		"buffer_bytes": _buffer_bytes,
		"span_x": _bounds_max.x - _bounds_min.x,
		"span_z": _bounds_max.z - _bounds_min.z,
		"crumb_spots": bread_spots.size(),
		"cafe_tables": cafe_spots.size(),
	}
	## Deterministic identity: the bake manifest's total hash — a re-bake that
	## moves a byte moves the fingerprint, exactly the layout-fingerprint
	## discipline the parent's seed hash serves.
	fingerprint = str(_manifest.get("total_sha256", "")).hash()
	regenerated.emit()


## --- T-176 survival re-base ------------------------------------------------


## Fills everything the survival loop reads, as a pure function of the
## committed pack + bake (zero RNG of any stream — the seeded bread spread
## stays deterministic per fingerprint): spawn over Central Campus near the
## campanile, then the crumb supply in fixed layer order, then the café
## tables. Runs inside `generate_step_finish`, BEFORE the spawners populate.
func _build_survival() -> void:
	bread_spots.clear()
	bread_spot_kinds.clear()
	cafe_spots.clear()
	boot_bread_spots.clear()
	## The spawn (master plan §11.1, owner-decided 2026-11-09): the campanile
	## POI + SPAWN_CAMPANILE_OFFSET_X east, at the plate plus the drop. The
	## offset clears the campanile shaft's own collider (the 4.9 m shaft is
	## solid — the drop lands on open lawn beside it); `ames_bread_reach`
	## asserts the district, the massing-clear drop and the ≤ 60 m first
	## bread.
	var spawn_local := Vector3(0.0, spawn_drop_height, 0.0)
	for poi: Dictionary in AmesDataPack.landmarks():
		if str(poi.get("id", "")) == CAMPANILE_POI_ID:
			var pos: Array = poi.get("position", [0.0, 0.0])
			var gx := float(pos[0]) + SPAWN_CAMPANILE_OFFSET_X
			var gz := float(pos[1])
			spawn_local = Vector3(gx, ground_height(to_global(Vector3(gx, 0.0, gz)))
					+ spawn_drop_height, gz)
			break
	spawn_point = to_global(spawn_local)
	_add_ground_rings()
	_append_roof_spots()
	_add_field_lattice()
	_add_cafe_tables()
	## (T-176 round 1) The boot ring: the BOOT_BREAD_COUNT GROUND spots nearest
	## the spawn become `City.boot_bread_spots` — the BreadSpawner seeds them
	## FIRST on every populate, so real bread (not just spot supply) sits
	## within reach at boot. Sorted by flat distance with index tiebreaks —
	## deterministic per fingerprint; the nearest boot spot is the world's
	## nearest ground spot (20.6 m at the spawn), well inside the 60 m bar the
	## `ames_bread_reach` row now measures against the LIVE spread.
	var ground_order: Array[int] = []
	for i: int in bread_spots.size():
		if bread_spot_kinds[i] == BreadKind.GROUND:
			ground_order.append(i)
	ground_order.sort_custom(func(a: int, b: int) -> bool:
		var da := (bread_spots[a].x - spawn_local.x) * (bread_spots[a].x - spawn_local.x) \
				+ (bread_spots[a].z - spawn_local.z) * (bread_spots[a].z - spawn_local.z)
		var db := (bread_spots[b].x - spawn_local.x) * (bread_spots[b].x - spawn_local.x) \
				+ (bread_spots[b].z - spawn_local.z) * (bread_spots[b].z - spawn_local.z)
		if da != db:
			return da < db
		return a < b)
	boot_bread_spots = ground_order.slice(0, BOOT_BREAD_COUNT)
	## (T-175, kept) the landable campanile cap keeps the crumb rule: one ROOF
	## spot at the cap top + ANCHOR_CRUMB_LIFT — the city.gd anchor-cap
	## pattern. The hero-top pass below deliberately skips the campanile (its
	## cap spot IS the hero-top crumb, pinned at this exact position).
	if _campanile_cap != Vector3.ZERO:
		bread_spots.append(_campanile_cap + Vector3.UP * ANCHOR_CRUMB_LIFT)
		bread_spot_kinds.append(BreadKind.ROOF)


## The ground-ring layers, in fixed order: the two named anchor streets dense
## (downtown Main, Campustown Welch — the ticket's named ground rings), every
## other named street wide (the district service layer the reach bar needs —
## the residential fabric), the creek centerlines, the four pinned parks as
## polygon-clipped grids, and the Lake LaVerne shore ring.
func _add_ground_rings() -> void:
	var lake := _lake_ring()
	var anchor_names: Array[String] = ["Main Street", "Welch Avenue"]
	for street: Dictionary in AmesDataPack.streets():
		var street_name := str(street.get("name", ""))
		if street_name.is_empty():
			continue
		var pts: Array = street.get("points", [])
		if anchor_names.has(street_name):
			_add_line_ring(pts, ANCHOR_RING_STEP, ANCHOR_RING_OFFSET, lake)
		else:
			_add_line_ring(pts, STREET_RING_STEP, ANCHOR_RING_OFFSET, lake)
	for water: Dictionary in AmesDataPack.water():
		for centerline: Variant in water.get("centerlines", []):
			var pts: Array = (centerline as Dictionary).get("points", []) \
					if centerline is Dictionary else centerline
			_add_line_ring(pts, CREEK_RING_STEP, CREEK_RING_OFFSET, lake)
	for park: Dictionary in AmesDataPack.parks():
		if not PINNED_PARKS.has(str(park.get("name", ""))):
			continue
		_add_polygon_grid(park.get("polygon", []), PARK_GRID_STEP)
	_add_shore_ring(lake)


## One polyline's ring: points every `step` metres along each segment,
## alternating sides at `offset` off the centerline (the curb line), lake
## interior skipped, each survivor ground-guarded and appended GROUND.
func _add_line_ring(pts: Array, step: float, offset: float,
		lake: PackedVector2Array) -> void:
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var ax := float(a[0])
		var az := float(a[1])
		var seg := Vector2(float(b[0]) - ax, float(b[1]) - az)
		var length := seg.length()
		if length < 0.001:
			continue
		var normal := Vector2(-seg.y, seg.x) / length
		var count := maxi(int(round(length / step)), 1)
		for k in count + 1:
			var t := float(k) / float(count)
			var side := 1.0 if k % 2 == 0 else -1.0
			var ox := ax + seg.x * t + normal.x * side * offset
			var oz := az + seg.y * t + normal.y * side * offset
			if _in_polygon(ox, oz, lake):
				continue
			_add_ground_spot(ox, oz)


## One park polygon's clipped grid: `step`-spaced points over the polygon
## bbox, kept only inside the polygon, ground-guarded.
func _add_polygon_grid(poly: Array, step: float) -> void:
	if poly.size() < 3:
		return
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for q: Variant in poly:
		var px := float((q as Array)[0])
		var pz := float((q as Array)[1])
		min_x = minf(min_x, px)
		min_z = minf(min_z, pz)
		max_x = maxf(max_x, px)
		max_z = maxf(max_z, pz)
	var x := ceilf(min_x / step) * step
	while x <= max_x:
		var z := ceilf(min_z / step) * step
		while z <= max_z:
			if _in_polygon(x, z, poly):
				_add_ground_spot(x, z)
			z += step
		x += step


## The lake shore ring: one spot per polygon edge midpoint, SHORE_OFFSET out
## on the outward (centroid-facing) normal, never inside the water.
func _add_shore_ring(lake: PackedVector2Array) -> void:
	if lake.size() < 3:
		return
	var center := Vector2.ZERO
	for p: Vector2 in lake:
		center += p
	center /= float(lake.size())
	for i in lake.size():
		var a := lake[i]
		var b := lake[(i + 1) % lake.size()]
		var edge := b - a
		var length := edge.length()
		if length < 0.001:
			continue
		var mid := (a + b) * 0.5
		var normal := Vector2(-edge.y, edge.x) / length
		if (mid - center).dot(normal) < 0.0:
			normal = -normal
		var ox := mid.x + normal.x * SHORE_OFFSET
		var oz := mid.y + normal.y * SHORE_OFFSET
		if _in_polygon(ox, oz, lake):
			continue
		_add_ground_spot(ox, oz)


## Consumes the per-chunk roof staging: authored + large-filler massing tops,
## then each hero silhouette's tallest placeholder part (the superseded hero
## bbox massing files nothing — its silhouette IS the hero; the campanile's
## cap crumb is pinned separately at the exact cap position). Appended ROOF
## at top + SPOT_LIFT, the T-032 roof-corner convention.
func _append_roof_spots() -> void:
	for top: Vector3 in _roof_spots:
		bread_spots.append(Vector3(top.x, top.y + SPOT_LIFT, top.z))
		bread_spot_kinds.append(BreadKind.ROOF)
	for id: String in _hero_roof_tops:
		var pos: Vector3 = _hero_roof_tops[id]
		bread_spots.append(Vector3(pos.x, pos.y + SPOT_LIFT, pos.z))
		bread_spot_kinds.append(BreadKind.ROOF)


## The district-wide reach bar's last layer: one ground spot per
## FIELD_LATTICE_STEP cell over the pack's core window (meta
## `core_bbox_wsen` through the pack's own transform), extended one cell past
## each edge so the window's boundary samples stay inside the half-cell
## diagonal (141 m < 150 m). Lake interior skipped; points that fall inside a
## building footprint drop through the ground guard — their box's own roof
## spot serves the neighborhood.
func _add_field_lattice() -> void:
	var lake := _lake_ring()
	var meta := AmesDataPack.meta()
	var bbox: Array = meta.get("core_bbox_wsen", [])
	if bbox.size() < 4:
		return
	## The window corners through the pack's own transform — each call reads
	## only the axis its lon/lat drives (x from lon, z from lat).
	var west := AmesDataPack.wgs84_to_local(float(bbox[0]), float(bbox[3])).x
	var east := AmesDataPack.wgs84_to_local(float(bbox[2]), float(bbox[3])).x
	var north := AmesDataPack.wgs84_to_local(float(bbox[2]), float(bbox[3])).z
	var south := AmesDataPack.wgs84_to_local(float(bbox[2]), float(bbox[1])).z
	var x := (ceilf(west / FIELD_LATTICE_STEP) - 1.0) * FIELD_LATTICE_STEP
	while x <= east + FIELD_LATTICE_STEP:
		var z := (ceilf(north / FIELD_LATTICE_STEP) - 1.0) * FIELD_LATTICE_STEP
		while z <= south + FIELD_LATTICE_STEP:
			if not _in_polygon(x, z, lake):
				_add_ground_spot(x, z)
			z += FIELD_LATTICE_STEP
		x += FIELD_LATTICE_STEP


## Ground-guarded GROUND append: a point the ground query answers taller than
## GROUND_COVER_MAX sits inside a building footprint — dropped.
func _add_ground_spot(x: float, z: float) -> void:
	var top := ground_height(to_global(Vector3(x, 0.0, z)))
	if top > GROUND_COVER_MAX:
		return
	bread_spots.append(Vector3(x, top + SPOT_LIFT, z))
	bread_spot_kinds.append(BreadKind.GROUND)


## The sidewalk-café system re-targeted onto the real cafés (the ticket's
## "crumb tables at real cafés"): one table per placed café venue, CAFE_VENUE_
## OUTSET out from the POI along its street-facing direction (`facing_deg`,
## the storefront normal — the venue fixup box is 10 m deep, so 7 m clears
## its face; walked out farther when another box still covers the point),
## yaw facing the street exactly as `City.cafe_spot_for` orients the Windrow
## tables. Each table seeds one TABLE bread spot on its own tabletop — the
## same `CAFE_CRUMB_SIT_INSET`/`CAFE_CRUMB_TABLE_LIFT` law `City._build_cafe_
## spots` rides — so the CafeSpawner seats furniture and sitters there for
## free and the spawner's table quota has a home. Unplaced venues (Labyrinth
## Coffee) ride no table — no invented positions.
func _add_cafe_tables() -> void:
	for venue: Dictionary in AmesDataPack.venues():
		var lower := str(venue.get("name", "")).to_lower()
		var is_cafe := false
		for token: String in CAFE_NAME_TOKENS:
			if lower.contains(token):
				is_cafe = true
				break
		if not is_cafe:
			continue
		var pos: Variant = venue.get("position")
		if not (pos is Array):
			continue
		var vx := float((pos as Array)[0])
		var vz := float((pos as Array)[1])
		if vx < _bounds_min.x - CAFE_BOUNDS_SLACK or vx > _bounds_max.x + CAFE_BOUNDS_SLACK \
				or vz < _bounds_min.z - CAFE_BOUNDS_SLACK or vz > _bounds_max.z + CAFE_BOUNDS_SLACK:
			continue ## Out-of-core venue — the world carries no land for it.
		var facing := float(venue.get("facing_deg", 0.0))
		var dir := Vector3(sin(deg_to_rad(facing)), 0.0, -cos(deg_to_rad(facing)))
		for dist: float in CAFE_VENUE_OUTSET_STEPS:
			var px := vx + dir.x * dist
			var pz := vz + dir.z * dist
			var top := ground_height(to_global(Vector3(px, 0.0, pz)))
			if top > GROUND_COVER_MAX:
				continue
			var spot := Transform3D(
					Basis(Vector3.UP, AmesDataPack.facing_to_yaw(facing)),
					Vector3(px, top, pz))
			cafe_spots.append(spot)
			bread_spots.append(spot.origin + spot.basis.x * CAFE_CRUMB_SIT_INSET
					+ Vector3(0.0, CAFE_CRUMB_TABLE_LIFT, 0.0))
			bread_spot_kinds.append(BreadKind.TABLE)
			break


## The Lake LaVerne ring as a closed polygon in world-local metres — the
## skip-interior test every ground layer shares.
func _lake_ring() -> PackedVector2Array:
	var ring := PackedVector2Array()
	for water: Dictionary in AmesDataPack.water():
		if str(water.get("name", "")) != "Lake LaVerne":
			continue
		for q: Variant in water.get("polygon", []):
			ring.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
	return ring


## Even-odd point-in-polygon over a local-metres ring (`poly` may be an Array
## of [x, z] pairs or an already-packed PackedVector2Array).
func _in_polygon(x: float, z: float, poly: Variant) -> bool:
	var inside := false
	var count := 0
	if poly is PackedVector2Array:
		count = (poly as PackedVector2Array).size()
	else:
		count = (poly as Array).size()
	var j := count - 1
	for i in count:
		var xi: float
		var zi: float
		var xj: float
		var zj: float
		if poly is PackedVector2Array:
			var pi := (poly as PackedVector2Array)[i]
			var pj := (poly as PackedVector2Array)[j]
			xi = pi.x
			zi = pi.y
			xj = pj.x
			zj = pj.y
		else:
			xi = float((poly as Array)[i][0])
			zi = float((poly as Array)[i][1])
			xj = float((poly as Array)[j][0])
			zj = float((poly as Array)[j][1])
		if (zi > z) != (zj > z) \
				and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
			inside = not inside
		j = i
	return inside


## (T-176) Roof staging per chunk — the parsed doc is only in hand here, so
## the roof-crumb hosts are collected where the geometry is read: authored
## (`a`) massing tops and filler boxes at least FILLER_ROOF_MIN_DIM wide
## (their id-paired silhouette rule: hero ids are skipped — their true-dim
## placeholder parts file their own tallest top below), plus per-hero tallest
## placeholder part positions for `_append_roof_spots`.
func _collect_roof_spots(chunk: Dictionary) -> void:
	for m: Dictionary in chunk.get("massing", []):
		var id := str(m.get("id", ""))
		if m.get("a", false) and _hero_ids.has(id):
			continue
		if m.get("a", false) or maxf(float(m["s"][0]), float(m["s"][2])) >= FILLER_ROOF_MIN_DIM:
			_roof_spots.append(Vector3(float(m["p"][0]),
					float(m["p"][1]) + float(m["s"][1]) * 0.5, float(m["p"][2])))
	for ph: Dictionary in chunk.get("placeholders", []):
		var hero_id := str(ph.get("id", ""))
		if not _hero_ids.has(hero_id) or hero_id == "way/183041212":
			continue ## The campanile's cap crumb is the pinned hero-top spot.
		var top := float(ph["p"][1]) + float(ph["s"][1]) * 0.5
		var pos := Vector3(float(ph["p"][0]), top, float(ph["p"][2]))
		var current: Variant = _hero_roof_tops.get(hero_id)
		if current == null or top > (current as Vector3).y:
			_hero_roof_tops[hero_id] = pos


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
## The plate IS the residential district's ground (T-174): the bake's ground
## cells only tint where the v0 rule says another district stands, so the
## plate color and the un-tinted cells are the same seed by construction —
## one source of truth in `AmesBaker.DISTRICT_GROUND`.
func _build_ground_plate() -> void:
	var size := _bounds_max - _bounds_min + Vector3.ONE * (GROUND_MARGIN * 2.0)
	var center := (_bounds_min + _bounds_max) * 0.5
	_add_collider("Ground", Vector3(size.x, PLATE_THICKNESS, size.z),
			Vector3(center.x, -PLATE_THICKNESS * 0.5, center.z))
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, PLATE_THICKNESS, size.z)
	var seed_ground: Color = AmesBaker.DISTRICT_GROUND["residential"]
	mesh.material = _flat_material(seed_ground)
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

	var placeholders := _placeholders_multimesh(chunk, center)
	if placeholders != null:
		## Never fades: the silhouettes ARE the from-the-air read (T-175).
		_add_chunk_mm(chunk_root, "Placeholders", placeholders, aabb, 0.0, 0.0)

	var flats := _flats_multimesh(chunk, center)
	if flats != null:
		_add_chunk_mm(chunk_root, "Ribbons", flats, aabb, 0.0, 0.0)

	var tris := _tris_multimesh(chunk, center)
	if tris != null:
		_add_chunk_mm(chunk_root, "Patches", tris, aabb, 0.0, 0.0)

	_build_chunk_occluder(chunk_root, chunk, center)
	_build_chunk_colliders(chunk_root, chunk, center)
	_build_ground_record(chunk)
	_collect_roof_spots(chunk) ## (T-176) the roof-crumb hosts, while the doc is in hand.


## One vertex-color unit-box MultiMesh from the chunk's massing entries
## (position/size/vertex color straight from the bake — the city.gd house
## style, ported to data). (T-175) the hero buildings' bbox boxes are
## skipped: their true-dim silhouettes supersede them in the placeholders
## family, and a hero must not render twice (the bowl's solid bbox would
## fill the ellipse the ring is there to draw).
func _massing_multimesh(chunk: Dictionary, center: Vector3) -> MultiMesh:
	var massing: Array = chunk.get("massing", [])
	var count := 0
	for m: Dictionary in massing:
		if not _is_hero_massing(m):
			count += 1
	if count == 0:
		return null
	var mm := _new_multimesh(count)
	var i := 0
	for m: Dictionary in massing:
		if _is_hero_massing(m):
			continue
		var p: Array = m["p"]
		var s: Array = m["s"]
		var c: Array = m["c"]
		mm.set_instance_transform(i, Transform3D(
				Basis.from_scale(Vector3(s[0], s[1], s[2])),
				Vector3(p[0], p[1], p[2]) - center))
		mm.set_instance_color(i, Color(c[0], c[1], c[2]))
		i += 1
	return mm


## (T-175) TRUE when a massing entry is one of the hero buildings whose
## bbox massing the placeholder silhouettes supersede.
func _is_hero_massing(m: Dictionary) -> bool:
	return _hero_ids.has(str(m.get("id", "")))


## (T-175) One vertex-color unit-box MultiMesh of the chunk's placeholder
## entries — the hero silhouette parts (true-dim gray masses) and the venue
## fixup boxes. Per-entry baked colors; never fades (the silhouette read is
## the deliverable this ring). Slot collision comes from
## `_build_chunk_colliders`, which consumes the same entries.
func _placeholders_multimesh(chunk: Dictionary, center: Vector3) -> MultiMesh:
	var placeholders: Array = chunk.get("placeholders", [])
	if placeholders.is_empty():
		return null
	var mm := _new_multimesh(placeholders.size())
	for i in placeholders.size():
		var ph: Dictionary = placeholders[i]
		var p: Array = ph["p"]
		var s: Array = ph["s"]
		var c: Array = ph["c"]
		mm.set_instance_transform(i, Transform3D(
				Basis.from_scale(Vector3(s[0], s[1], s[2])),
				Vector3(p[0], p[1], p[2]) - center))
		mm.set_instance_color(i, Color(c[0], c[1], c[2]))
	return mm


## One vertex-color unit-box MultiMesh of every baked ground rectangle —
## street ribbons, creek quads, rail ballast and the T-174 dressing (district
## ground cells, arterial lane dashes, the LaVerne shore band, the rail tie
## stripe) are all rectangles, so all seven families share the massing's box
## mesh at their own per-instance baked family color (`chunk.colors`; ground
## cells carry a per-cell district color that overrides it). Never fades: the
## ground read stays.
func _flats_multimesh(chunk: Dictionary, center: Vector3) -> MultiMesh:
	var colors: Dictionary = chunk.get("colors", {})
	var entries: Array = []
	for family: String in FLAT_FAMILIES:
		var flat_color: Array = colors.get(family, [0.5, 0.5, 0.5])
		for q: Dictionary in chunk.get(family, []):
			entries.append([q["q"], q.get("c", flat_color)])
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
## massing entry (the bake writes one outline per box, 1:1). (T-175) hero
## outlines are skipped with their boxes: the superseded bbox must not
## occlude for a silhouette that no longer fills it.
func _build_chunk_occluder(chunk_root: Node3D, chunk: Dictionary, center: Vector3) -> void:
	var outlines: Array = chunk.get("occluders", [])
	var massing: Array = chunk.get("massing", [])
	if outlines.is_empty():
		return
	var verts := PackedVector3Array()
	for i in outlines.size():
		var o: Array = outlines[i]
		if i < massing.size() and _is_hero_massing(massing[i]):
			continue
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


## (T-175) The placeholder collision, per chunk: ONE layer-1 `world`
## StaticBody3D under the chunk node (chunk lifecycle owns it), carrying one
## box CollisionShape3D per placeholder — every authored building's massing
## slot (the bake's `a` flag), every hero silhouette part and every venue
## fixup. Solid at flight speeds; the campanile cap's top face is the
## landable pad (the anchor-cap rule). Procedural filler stays visual-only
## massing — the ticket's scope is the ~540 authored positions. (The ~600
## shapes are not counted in `render_metrics().buffer_bytes` — the metric
## covers the GPU-side resident estimate, not physics shapes.)
func _build_chunk_colliders(chunk_root: Node3D, chunk: Dictionary, center: Vector3) -> void:
	var entries: Array = []
	for m: Dictionary in chunk.get("massing", []):
		if m.get("a", false) and not _is_hero_massing(m):
			entries.append(m)
	for ph: Dictionary in chunk.get("placeholders", []):
		entries.append(ph)
	if entries.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Placeholders"
	body.collision_layer = 1 ## world
	body.collision_mask = 0
	chunk_root.add_child(body)
	for e: Dictionary in entries:
		var p: Array = e["p"]
		var s: Array = e["s"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
		shape.shape = box
		shape.position = Vector3(float(p[0]), float(p[1]), float(p[2])) - center
		body.add_child(shape)
		if str(e.get("id", "")) == "way/183041212" and str(e.get("part", "")) == "cap":
			_campanile_cap = Vector3(float(p[0]), float(p[1]) + float(s[1]) * 0.5,
					float(p[2]))


## The compact ground record the seam queries: per box (x, z, half_w, half_d,
## top) in WORLD-LOCAL coordinates (the `ground_height()` query frame). Each
## box is indexed into EVERY tile its footprint touches — 401 of 3,737 baked
## boxes cross a 256 m tile edge (round-1 review: worst overhang 77 m), and a
## centroid-tile-only filing answered the plate (0.0) for points standing
## under those overhangs. The parsed JSON is dropped after this, so the
## resident footprint stays proportional to the geometry (the crossing
## duplicates add ~25 KB). (T-175) hero massing boxes are skipped (the
## silhouettes file their own true tops instead — the bowl interior must
## answer the plate, not its superseded 25 m bbox) and the placeholder
## entries file alongside.
func _build_ground_record(chunk: Dictionary) -> void:
	var tiles: Dictionary = {} ## tile Vector2i -> Array of floats, packed below.
	var bytes := 0
	for m: Dictionary in chunk.get("massing", []):
		if _is_hero_massing(m):
			continue
		bytes += _file_ground_box(tiles, m["p"], m["s"])
	for ph: Dictionary in chunk.get("placeholders", []):
		bytes += _file_ground_box(tiles, ph["p"], ph["s"])
	for key: Vector2i in tiles:
		var packed := PackedFloat32Array(tiles[key])
		var record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = record.get("ground", PackedFloat32Array())
		ground.append_array(packed)
		record["ground"] = ground
		_chunks[key] = record
	_buffer_bytes += bytes


## One box into the per-tile ground accumulator (shared by the massing and
## placeholder families); returns the bytes it appended (ints pass by
## value — the caller adds the return to its own total).
func _file_ground_box(tiles: Dictionary, p: Array, s: Array) -> int:
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
	var bytes := 0
	for tx in range(tx0, tx1 + 1):
		for tz in range(tz0, tz1 + 1):
			var key := Vector2i(tx, tz)
			var arr: Array = tiles.get(key, [])
			arr.append_array(entry)
			tiles[key] = arr
			bytes += entry.size() * 4
	return bytes


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

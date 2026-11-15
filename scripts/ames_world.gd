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
## (T-186) The campanile hero's bake id — the placeholder slot (the T-175
## plinth/shaft/head/cap stack in its chunk) this hero supersedes 1:1: same
## id, same slot, same collision class. Every placeholder family that renders,
## collides or files ground tops skips exactly this id; the hero build files
## its own.
const CAMPANILE_HERO_ID := "way/183041212"
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
## (T-185) The lake dress + swan staging, retained after the build in the
## corner-dress retention law (headless runs cannot read MultiMesh instances
## back — the gate walks the queues that fed the exact nodes). The pale-edge
## and reed transform queues are world-local; `swan_circuit` is the closed
## loop the swans swim (world-local, == pack-local — the world node IS the
## pack frame); `swans` holds the two live birds.
var _pale_edge_xfs: Array[Transform3D] = []
var _reed_xfs: Array[Transform3D] = []
var swan_circuit: PackedVector3Array = PackedVector3Array()
var swans: Array[Swan] = []
## (T-186) The campanile hero's part record, retained after the build in the
## same headless-visibility law as the T-185 queues: every box the hero build
## emitted — `{band, p, s, color, collide}` in world-local (pack) coordinates,
## `band` one of the pinned palette bands. The cap frustum and the clock dials
## are not boxes; they file their band and color with s ZERO so the palette
## arm sees them while the dims arm ignores them.
var campanile_hero_parts: Array[Dictionary] = []
## (T-187) The Central Campus lawn dress, retained for the gates under the
## same headless-visibility law: `campus_ribbon_xfs` — every path-ribbon box
## transform (world-local, one per data-chain segment); `campus_slab_tris` /
## `campus_plaza_tris` — the flat-tri counts (the gate recomputes the
## ear-clip counts from the pack/lawn polygons); `fountain_parts` — every
## fountain box `{kind, p, s, color, collide}` (the data-position prop's
## schedule, with the rim-collider flags).
var campus_ribbon_xfs: Array[Transform3D] = []
var campus_slab_tris: int = 0
var campus_plaza_tris: int = 0
var fountain_parts: Array[Dictionary] = []
## (T-188) The campus row west heroes' part record, retained on the same law:
## every box and mesh-bounding extra the four builds emitted —
## `{hero, band, p, s, color, collide}` in world-local (pack) coordinates,
## `hero` one of `beardshear` / `morrill` / `farm_house` / `marston_hall`.
## The dome cap, the two roofs and the turret drum/cone file their band and
## bounding `s` at their mesh centers so the dims and palette arms walk one
## record; the LIVE material arms re-prove the meshes themselves.
var campus_row_hero_parts: Array[Dictionary] = []

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
	_lamp_mm = null ## (T-180) The corner-dress lamp state rebuilds with the world.
	_lamp_kinds = PackedInt32Array()
	_signal_phase = -1
	_corner_paint_xfs = []
	_corner_stop_line_xfs = []
	_corner_post_xfs = []
	_corner_red_xfs = []
	_corner_border_xfs = []
	_corner_plaque_xfs = []
	_corner_mast_xfs = []
	_corner_head_xfs = []
	_corner_lamp_xfs = []
	_bench_seat_xfs = [] ## (T-181) The zone-bench queues rebuild with the world.
	_bench_leg_xfs = []
	_lot_body_xfs = [] ## (T-182) The lot-dressing queues rebuild with the world.
	_lot_cabin_xfs = []
	_pale_edge_xfs = [] ## (T-185) The lake-dress queues and swan staging rebuild.
	_reed_xfs = []
	swan_circuit = PackedVector3Array()
	swans = []
	campanile_hero_parts = [] ## (T-186) The hero part record rebuilds with the world.
	campus_ribbon_xfs = [] ## (T-187) The lawn-dress records rebuild with the world.
	campus_slab_tris = 0
	campus_plaza_tris = 0
	fountain_parts = []
	campus_row_hero_parts = [] ## (T-188) The row-hero record rebuilds with the world.
	ped_zones = null
	parking = null
	traffic_graph = null ## (T-178) The graph rebuilds with the world.
	_manifest = AmesBaker.read_manifest(CHUNKS_DIR)
	if _manifest.is_empty():
		push_error("AmesWorld: no chunk bake at %s — world builds empty" % CHUNKS_DIR)
		return true
	if (_manifest.get("chunks", []) as Array).is_empty():
		push_error("AmesWorld: bake manifest carries no chunks — world builds empty")
		return true
	for hero_id: Variant in _manifest.get("heroes", []):
		_hero_ids[str(hero_id)] = true
	## (T-188) The campus row west heroes swap AUTHORED massing slots (Morrill,
	## Farm House, Marston Hall), not placeholder parts — their ids join the
	## same hero set at runtime so every massing-family skip (render, occluder,
	## collision, ground record, roof spots) applies unchanged; Beardshear
	## already rides the bake's own `heroes` list. Each hero files its own true
	## tops in its build below.
	for hero_id: String in CAMPUS_ROW_RUNTIME_HERO_IDS:
		_hero_ids[hero_id] = true
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
## bread spots, café tables), the traffic graph (T-178 — the car fleet's
## route system over the real streets), then the report, the fingerprint and
## the `regenerated` emission close the build exactly as the parent's slice
## does.
func generate_step_finish() -> void:
	_build_survival()
	_build_traffic_graph()
	_build_intersection_furniture() ## (T-180) The pinned corners' paint/signs/signals.
	_build_ped_zones() ## (T-181) The pedestrian zones + their bench furniture.
	_add_favor_bench_spots() ## (T-183) The elders' bread spots at their benches.
	_build_parking() ## (T-182) The parking system + the big-lot dressing rows.
	_build_lake_dress() ## (T-185) The LaVerne shore polish: pale edge + reed hint.
	_build_swans() ## (T-185) Lancelot & Elaine on their lake circuit.
	_build_campus_lawn() ## (T-187) The lawn slab, the crossing axes' ribbons, the fountain.
	var pinned := 0
	var signalized := 0
	if traffic_graph != null:
		for a in traffic_graph.intersection_count():
			if traffic_graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
				continue
			pinned += 1
			if traffic_graph.intersection_is_signal(a):
				signalized += 1
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
		"traffic_nodes": traffic_graph.node_count() if traffic_graph != null else 0,
		"traffic_runs": traffic_graph.run_count() if traffic_graph != null else 0,
		"traffic_km": snappedf(traffic_graph.total_km(), 0.01) if traffic_graph != null else 0.0,
		"intersections_pinned": pinned,
		"intersections_signals": signalized,
		"ped_zones": ped_zones.zones.size() if ped_zones != null else 0,
		"ped_benches": _bench_seat_xfs.size(),
		"parking_lots": parking.lot_count() if parking != null else 0,
		"parking_curb_runs": parking.curb_run_count() if parking != null else 0,
		"parking_dressed": parking.dressed_car_count() if parking != null else 0,
		"lake_pale_quads": _pale_edge_xfs.size(),
		"lake_reeds": _reed_xfs.size(),
		"swans": swans.size(),
		"campanile_parts": campanile_hero_parts.size(), ## (T-186) The hero swap is live.
		"campus_row_parts": campus_row_hero_parts.size(), ## (T-188) The row heroes are live.
		"campus_ribbons": campus_ribbon_xfs.size(), ## (T-187) The lawn dress is live.
		"campus_slab_tris": campus_slab_tris,
		"campus_plaza_tris": campus_plaza_tris,
		"fountain_parts": fountain_parts.size(),
	}
	## Deterministic identity: the bake manifest's total hash — a re-bake that
	## moves a byte moves the fingerprint, exactly the layout-fingerprint
	## discipline the parent's seed hash serves.
	fingerprint = str(_manifest.get("total_sha256", "")).hash()
	regenerated.emit()


## (T-178) The traffic graph: welded junctions, right-hand lane polylines,
## speed classes and the rail-crossing facts over the committed pack — a pure
## function of that data (zero RNG of any stream), built once per world build
## BEFORE the spawners populate, so the car fleet deals routes off it on the
## first `regenerated`.
func _build_traffic_graph() -> void:
	traffic_graph = AmesTrafficGraph.new()


## --- T-180 intersection furniture -------------------------------------------
## The corner dress the pinned start set earns, built straight off the graph's
## classification (the same derivation the stop entries stamp, so paint and
## cars can never disagree): zebra bands at every pinned approach (T-069's
## longitudinal zebra, the worn-white read), stop lines + T-134 stop-sign
## assemblies (the T-143 red-face relief) at the all-way corners, and one
## mast-arm signal per signal corner whose head lamps run the city-wide
## phase (`TrafficControl.signal_phase`) — the same clock the cars' gate
## reads. Visual-only throughout (the T-017 decision): zero colliders, zero
## RNG of any stream — a rebuild reproduces every transform byte-identically.

## Corner paint + sign colors (the T-069/T-134 palette, ported).
const COLOR_CROSSWALK := Color(0.78, 0.78, 0.75) ## T-069's worn white.
const COLOR_SIGN_WHITE := Color(0.94, 0.94, 0.92) ## T-134 sign faces.
const COLOR_STOP_SIGN := Color(0.78, 0.10, 0.10) ## T-134's red octagon.
const COLOR_SIGN_POST := Color(0.25, 0.25, 0.28)
const COLOR_MAST := Color(0.22, 0.23, 0.25)
const COLOR_HEAD := Color(0.13, 0.13, 0.15)

## The mast's lamp colors per kind (0 red / 1 amber / 2 green): [lit, off].
## Amber never lights — the phase model is a two-state green/red cycle.
const SIGNAL_LAMP_COLORS: Dictionary = {
	0: [Color(0.85, 0.08, 0.06), Color(0.18, 0.05, 0.05)],
	1: [Color(0.9, 0.55, 0.08), Color(0.16, 0.12, 0.05)],
	2: [Color(0.1, 0.8, 0.18), Color(0.05, 0.15, 0.08)],
}

## Mast geometry (m): pole 5.8 tall standing 0.6 past the arterial stop line
## at the road edge + 0.7; the arm spans to 1.2 m short of the far asphalt
## edge at 5.6; the two heads hang at 4.9 over the arterial's two lane lines.
const MAST_HEIGHT := 5.8
const MAST_ARM_Y := 5.6
const MAST_HEAD_Y := 4.9
const MAST_POLE_CLEAR := 0.6
const MAST_POLE_SIDE := 0.7
const MAST_ARM_END_CLEAR := 1.2
const MAST_HEAD_DEPTH := 0.30
const MAST_LAMP_PITCH := 0.33
const MAST_LAMP_OUT := 0.18

## The sign assembly's heights (m over the ground plate): octagon face center
## 2.5 (the T-134 read — bottom ≈ 2.1 over the asphalt), plaque just below.
const SIGN_FACE_Y := 2.5
const SIGN_POST_HEIGHT := 2.5
const SIGN_PLAQUE_Y := 2.0

## (T-180) Live lamp state: the lamp MultiMesh + its per-lamp kind (0 red /
## 1 amber / 2 green), and the last painted phase (−1 until the first
## `_process` pass paints it).
var _lamp_mm: MultiMesh = null
var _lamp_kinds: PackedInt32Array = PackedInt32Array()
var _signal_phase: int = -1

## (T-180) The corner-dress transform queues, retained after the build in the
## T-069 `_visuals[key].xfs` pattern: headless runs cannot read a MultiMesh's
## instances back (the dummy RenderingServer uploads nothing), so the gate
## walks the queues that fed the exact nodes — kept in sync by construction
## (the spawn step copies them verbatim) and pinned by the instance-count
## asserts. World-local coordinates.
var _corner_paint_xfs: Array[Transform3D] = []
var _corner_stop_line_xfs: Array[Transform3D] = []
var _corner_post_xfs: Array[Transform3D] = []
var _corner_red_xfs: Array[Transform3D] = []
var _corner_border_xfs: Array[Transform3D] = []
var _corner_plaque_xfs: Array[Transform3D] = []
var _corner_mast_xfs: Array[Transform3D] = []
var _corner_head_xfs: Array[Transform3D] = []
var _corner_lamp_xfs: Array[Transform3D] = []

## (T-181) The zone-bench transform queues (the same retention law as the
## corner dress): one seat-slab and one leg-pair transform per bench, plus
## the count the spawners seat against. World-local coordinates.
var _bench_seat_xfs: Array[Transform3D] = []
var _bench_leg_xfs: Array[Transform3D] = []

## (T-182) The lot-dressing transform queues (the same retention law): one
## body and one cabin transform per dressed stall, pack-local converted to
## WORLD-LOCAL (the stalls are pack-local; the world node IS the pack frame,
## so the conversion is identity here — retained for the gate's read anyway).
var _lot_body_xfs: Array[Transform3D] = []
var _lot_cabin_xfs: Array[Transform3D] = []


func _process(_delta: float) -> void:
	if _lamp_mm == null:
		return
	var phase := TrafficControl.signal_phase()
	if phase == _signal_phase:
		return
	_signal_phase = phase
	for i in _lamp_kinds.size():
		var kind := _lamp_kinds[i]
		var lit: bool = kind == (2 if phase == 0 else 0) ## Green on the
			## arterial's phase, red on the cross street's — the mast serves
			## the arterial's two approaches, so both heads flip together.
		var colors: Array = SIGNAL_LAMP_COLORS[kind]
		_lamp_mm.set_instance_color(i, colors[0] if lit else colors[1])


## Builds the whole corner dress off the graph's pinned anchors (the finish
## slice, after the graph exists).
func _build_intersection_furniture() -> void:
	var graph := traffic_graph
	if graph == null:
		return
	var paint: Array[Transform3D] = []
	var stop_lines: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var red_bars: Array[Transform3D] = []
	var border_bars: Array[Transform3D] = []
	var plaques: Array[Transform3D] = []
	var masts: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	_lamp_kinds = PackedInt32Array()
	for a in graph.intersection_count():
		if graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		var signalized := graph.intersection_is_signal(a)
		for member: int in graph.intersection_members(a):
			for edge in graph.node_in_edges(member):
				var geo := graph.approach_geometry(member, edge)
				if not bool(geo["fits"]):
					continue
				_queue_corner_paint(paint, graph.node_pos(member), geo)
				if signalized:
					continue ## Signals replace the all-way stop furniture.
				_queue_corner_stop(stop_lines, posts, red_bars, border_bars,
						plaques, graph.node_pos(member), geo)
		if signalized:
			_queue_signal_mast(masts, heads, lamps, a, graph)
	_spawn_corner_visuals(paint, stop_lines, posts, red_bars, border_bars,
			plaques, masts, heads, lamps)


## One approach's zebra band (T-069/T-102 geometry at the measured width):
## `bars` longitudinal bars tiled across the asphalt at BAR_PITCH on centers,
## each a BAND_DEPTH-long × BAR_WIDTH-wide box riding the paint level.
func _queue_corner_paint(paint: Array[Transform3D], node_pos: Vector3,
		geo: Dictionary) -> void:
	var axis := (geo["axis"] as Vector3)
	var across := Vector3(-axis.z, 0.0, axis.x)
	var band: Dictionary = geo["band"]
	var center := Vector3(band["center"].x, AmesTrafficGraph.PAINT_CENTER_Y,
			band["center"].y)
	var bars := int(geo["bars"])
	var pitch := AmesTrafficGraph.CROSSWALK_BAR_PITCH
	var depth := AmesTrafficGraph.CROSSWALK_BAND_DEPTH
	var width := AmesTrafficGraph.CROSSWALK_BAR_WIDTH
	var basis := Basis(axis * depth, Vector3.UP * AmesTrafficGraph.PAINT_THICKNESS,
			across * width)
	for k in bars:
		var lateral := (float(k) - float(bars - 1) * 0.5) * pitch
		paint.append(Transform3D(basis, center + across * lateral))


## One approach's all-way-stop furniture: the stop bar across the incoming
## lane (centered on the lane line at the adapted outset — the exact line the
## stop entries stamp) plus the T-134 sign assembly on the approach's right
## (post, the four-bar red octagon over its white border — the T-143 relief
## — and the all-way plaque).
func _queue_corner_stop(stop_lines: Array[Transform3D],
		posts: Array[Transform3D], red_bars: Array[Transform3D],
		border_bars: Array[Transform3D], plaques: Array[Transform3D],
		node_pos: Vector3, geo: Dictionary) -> void:
	var axis := (geo["axis"] as Vector3)
	var lane := float(geo["lane_off"])
	var half := float(geo["half_width"])
	var stop_outset := float(geo["stop_outset"])
	var right := Vector3(-axis.z, 0.0, axis.x)
	## The stop bar: 0.4 along travel × 2.8 across the lane, paint level.
	var line_pos := node_pos - axis * stop_outset + right * lane
	stop_lines.append(Transform3D(
			Basis(axis * AmesTrafficGraph.STOP_LINE_WIDTH,
					Vector3.UP * AmesTrafficGraph.PAINT_THICKNESS,
					right * AmesTrafficGraph.STOP_LINE_SPAN),
			Vector3(line_pos.x, AmesTrafficGraph.PAINT_CENTER_Y, line_pos.z)))
	## The sign assembly on the approach's right, just past the stop line.
	var post_pos := node_pos - axis * (stop_outset + AmesTrafficGraph.SIGN_OUTSET_GAP) \
			+ right * (half + AmesTrafficGraph.SIGN_EDGE_OFFSET)
	posts.append(Transform3D(
			Basis(Vector3.RIGHT * 0.08, Vector3.UP * SIGN_POST_HEIGHT,
					Vector3.BACK * 0.08),
			Vector3(post_pos.x, SIGN_POST_HEIGHT * 0.5, post_pos.z)))
	var face := Vector3(post_pos.x, SIGN_FACE_Y, post_pos.z)
	var normal := -axis ## The face looks back at the approaching driver.
	var plane := Basis(right, Vector3.UP, normal)
	_queue_octagon(red_bars, face, plane, normal,
			Vector3(0.75, 0.31, AmesTrafficGraph.STOP_SIGN_THICKNESS))
	_queue_octagon(border_bars, face, plane, normal,
			Vector3(0.81, 0.34, AmesTrafficGraph.STOP_SIGN_BORDER_THICKNESS))
	plaques.append(Transform3D(
			Basis(right * 0.42, Vector3.UP * 0.14, normal
					* AmesTrafficGraph.STOP_SIGN_BORDER_THICKNESS),
			Vector3(post_pos.x, SIGN_PLAQUE_Y, post_pos.z)))


## The T-134 octagon read as the union of FOUR equal bars — one axis-aligned
## with its long side across the approach, one at 90°, one ±45° — queued at
## `center` in the sign's face plane (`plane` carries the un-rotated frame,
## `normal` the face normal the bars rotate about).
func _queue_octagon(queue: Array[Transform3D], center: Vector3,
		plane: Basis, normal: Vector3, size: Vector3) -> void:
	for theta: float in [0.0, PI * 0.5, PI * 0.25, PI * 0.75]:
		var rot := Basis(normal, theta)
		queue.append(Transform3D(
				Basis(rot * plane.x * size.x, rot * plane.y * size.y,
						normal * size.z),
				center))


## One signal corner's mast-arm assembly: the pole on the arterial approach's
## right corner, the arm spanning the asphalt, and two three-lamp heads over
## the arterial's two lane lines — lamps queued in RED/AMBER/GREEN order per
## head, each facing its own direction's drivers.
func _queue_signal_mast(masts: Array[Transform3D], heads: Array[Transform3D],
		lamps: Array[Transform3D], anchor: int, graph: AmesTrafficGraph) -> void:
	var axis := graph.intersection_signal_axis(anchor)
	if axis == Vector3.ZERO:
		return
	var half := graph.intersection_signal_half_width(anchor)
	var lane := graph.intersection_signal_lane_off(anchor)
	var node := graph.intersection_signal_node(anchor)
	var node_pos := graph.node_pos(node)
	var stop_outset := lane + AmesTrafficGraph._STOP_OUTSET_TAIL
	var right := Vector3(-axis.z, 0.0, axis.x)
	var along := stop_outset + MAST_POLE_CLEAR
	## The pole, just past the arterial's stop line on its right.
	var pole_pos := node_pos - axis * along + right * (half + MAST_POLE_SIDE)
	masts.append(Transform3D(
			Basis(Vector3.RIGHT * 0.16, Vector3.UP * MAST_HEIGHT,
					Vector3.BACK * 0.16),
			Vector3(pole_pos.x, MAST_HEIGHT * 0.5, pole_pos.z)))
	## The arm: from the pole across the asphalt, ending clear of the far edge.
	var arm_len := (half + MAST_POLE_SIDE) + half - MAST_ARM_END_CLEAR
	var arm_center := pole_pos - right * (arm_len * 0.5)
	masts.append(Transform3D(
			Basis(Vector3.RIGHT * 0.16, Vector3.UP * 0.16, right * arm_len),
			Vector3(arm_center.x, MAST_ARM_Y, arm_center.z)))
	## Two heads over the arterial's two lane lines, each with its three
	## lamps facing the drivers it serves (red top, amber mid, green bottom).
	for side: float in [1.0, -1.0]:
		var head_pos := node_pos - axis * along + right * (lane * side)
		var face := -axis * float(signf(side)) ## Head over the +lane serves
			## the +axis direction: its face (and lamps) look back down −axis.
		heads.append(Transform3D(
				Basis(right * 0.42, Vector3.UP * 1.05, face * MAST_HEAD_DEPTH),
				Vector3(head_pos.x, MAST_HEAD_Y, head_pos.z)))
		for lamp_i in 3:
			var dy := MAST_LAMP_PITCH * (1.0 - float(lamp_i))
			var lamp_pos := head_pos + Vector3(0.0, dy, 0.0) \
					+ face * (MAST_HEAD_DEPTH * 0.5 + 0.02)
			lamps.append(Transform3D(
					Basis(right * 0.26, Vector3.UP * 0.26, face * 0.05),
					lamp_pos))
			_lamp_kinds.append(lamp_i) ## 0 red, 1 amber, 2 green.


## Spawns the corner-dress MultiMeshes (one node per family under
## `Intersections/`), retaining the transform queues for the gate (the T-069
## headless read pattern) and the lamp family's MultiMesh for the live phase
## paint. Every instance is colored per family (the vertex-color box mesh),
## no colliders anywhere.
func _spawn_corner_visuals(paint: Array[Transform3D],
		stop_lines: Array[Transform3D], posts: Array[Transform3D],
		red_bars: Array[Transform3D], border_bars: Array[Transform3D],
		plaques: Array[Transform3D], masts: Array[Transform3D],
		heads: Array[Transform3D], lamps: Array[Transform3D]) -> void:
	_corner_paint_xfs = paint
	_corner_stop_line_xfs = stop_lines
	_corner_post_xfs = posts
	_corner_red_xfs = red_bars
	_corner_border_xfs = border_bars
	_corner_plaque_xfs = plaques
	_corner_mast_xfs = masts
	_corner_head_xfs = heads
	_corner_lamp_xfs = lamps
	var root := Node3D.new()
	root.name = "Intersections"
	add_child(root)
	_spawn_corner_family(root, "CrosswalkPaint", paint, COLOR_CROSSWALK)
	_spawn_corner_family(root, "StopLines", stop_lines, COLOR_CROSSWALK)
	_spawn_corner_family(root, "SignPosts", posts, COLOR_SIGN_POST)
	_spawn_corner_family(root, "StopFaces", red_bars, COLOR_STOP_SIGN)
	_spawn_corner_family(root, "StopBorders", border_bars, COLOR_SIGN_WHITE)
	_spawn_corner_family(root, "Plaques", plaques, COLOR_SIGN_WHITE)
	_spawn_corner_family(root, "Masts", masts, COLOR_MAST)
	_spawn_corner_family(root, "Heads", heads, COLOR_HEAD)
	var lamp_mm := _new_multimesh(lamps.size())
	for i in lamps.size():
		lamp_mm.set_instance_transform(i, lamps[i])
		var colors: Array = SIGNAL_LAMP_COLORS[_lamp_kinds[i]]
		lamp_mm.set_instance_color(i, colors[1]) ## Off until _process paints.
	var lamp_node := MultiMeshInstance3D.new()
	lamp_node.name = "SignalLamps"
	lamp_node.multimesh = lamp_mm
	root.add_child(lamp_node)
	_lamp_mm = lamp_mm
	_signal_phase = -1


## One colored corner family: a MultiMeshInstance3D of the given transforms.
func _spawn_corner_family(root: Node3D, node_name: String,
		xfs: Array[Transform3D], color: Color) -> void:
	if xfs.is_empty():
		return
	var mm := _new_multimesh(xfs.size())
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, color)
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	root.add_child(node)


## --- T-181 pedestrian zones -------------------------------------------------


## Builds the zone set (after the traffic graph — the crossing legs derive
## from its pinned bands) and spawns the zones' bench furniture: the retired
## Windrow `_add_bench` recipe verbatim (seat slab 1.8 × 0.08 × 0.5, top 0.54
## — the T-163 law's wood top — over two legs; collider 1.8 × 0.55 × 0.5), so
## the T-141 sit system and the T-163 seat-contact law carry over unchanged
## onto the new benches. One MultiMesh per family under `PedZones/` plus one
## merged layer-1 StaticBody (the T-093 one-body-per-group pattern), the
## seat/leg queues retained for the gate. Zero RNG of any stream.
func _build_ped_zones() -> void:
	if traffic_graph == null:
		return
	ped_zones = AmesPedZones.new(self, traffic_graph)
	var seats: Array[Transform3D] = []
	var legs: Array[Transform3D] = []
	var grounds: Array[Transform3D] = []
	for zone: AmesPedZones.Zone in ped_zones.zones:
		for bench: Transform3D in zone.benches:
			## The bench record rides the SEAT LINE (ground + 0.60, the
			## `elder_spots` convention) in world-local coordinates — the
			## furniture derives its ground origin 0.60 under it.
			var xf := Transform3D(Basis(Vector3.UP, bench.basis.get_euler().y),
					bench.origin - Vector3(0.0, AmesPedZones.BENCH_SEAT_LINE, 0.0))
			grounds.append(xf)
			seats.append(xf * Transform3D(
					Basis.from_scale(Vector3(1.8, 0.08, 0.5)),
					Vector3(0.0, 0.5, 0.0)))
			legs.append(xf * Transform3D(
					Basis.from_scale(Vector3(0.1, 0.5, 0.44)),
					Vector3(-0.75, 0.25, 0.0)))
			legs.append(xf * Transform3D(
					Basis.from_scale(Vector3(0.1, 0.5, 0.44)),
					Vector3(0.75, 0.25, 0.0)))
	_bench_seat_xfs = seats
	_bench_leg_xfs = legs
	if seats.is_empty():
		return
	var root := Node3D.new()
	root.name = "PedZones"
	add_child(root)
	_spawn_corner_family(root, "BenchSeats", seats, AmesPedZones.BENCH_WOOD)
	_spawn_corner_family(root, "BenchLegs", legs, AmesPedZones.BENCH_METAL)
	## One merged world body: every bench's box, one shape per bench (the
	## retired bench collider recipe), on layer 1 `world`.
	var body := StaticBody3D.new()
	body.name = "BenchProps"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for ground: Transform3D in grounds:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.8, 0.55, 0.5)
		shape.shape = box
		shape.transform = ground * Transform3D(
				Basis.IDENTITY, Vector3(0.0, 0.275, 0.0))
		body.add_child(shape)


## --- T-183 the favor-bench bread spots ---------------------------------------


## The bench-front spot outset off the seat line (m) — the elder toss line
## itself (`Elder.toss_distance` 1.2): the seeded spot is where the elders'
## shared loaves land, so the spend target sits ON its bread supply.
const FAVOR_BENCH_SPOT_OUTSET := 1.2


## (T-183) The elders' bread spots (the ticket's bread economy — "the
## elders' bread spots at the real cafés/benches"): one TABLE crumb spot at
## every `ElderSpawner.FAVOR_ZONE_IDS` bench front, on the toss line, so
## the favor loop's spend target (the seated elder) sits beside its bread —
## stealing the locals' own bench bread books the T-114 `favor_steal_table`
## exactly like a café tabletop crumb. The café TABLE spots themselves are
## T-176's untouched layer. Runs after the ped zones build (the benches
## derive there), before the spawners populate. Zero RNG.
func _add_favor_bench_spots() -> void:
	if ped_zones == null:
		return
	for zone: AmesPedZones.Zone in ped_zones.zones:
		if not zone.id in ElderSpawner.FAVOR_ZONE_IDS:
			continue
		for bench: Transform3D in zone.benches:
			var facing := -bench.basis.z ## The bench's facing (the toss
				## direction — the elder seats onto this exact transform).
			facing.y = 0.0
			facing = facing.normalized()
			var xz := Vector2(bench.origin.x, bench.origin.z) \
					+ Vector2(facing.x, facing.z) * FAVOR_BENCH_SPOT_OUTSET
			var top := ground_height(to_global(Vector3(xz.x, 0.0, xz.y)))
			if top > GROUND_COVER_MAX:
				continue ## A guarded-over bench front stays spot-less (never
					## with the shipped derivation — the toss lands there).
			bread_spots.append(Vector3(xz.x, top + SPOT_LIFT, xz.y))
			bread_spot_kinds.append(BreadKind.TABLE)


## --- T-182 parking ----------------------------------------------------------


## Builds the parking system (after the graph and the zones — the curb
## marking walks its runs, the dressing guards use the ground query) and
## spawns the big-lot dressing rows: one body + one cabin box per kept
## stall, palette-cycled like the real fleet's civilians, under `Parking/`.
## Visual-only dressing (the T-180 corner-dress pattern): zero colliders,
## zero RNG of any stream — a rebuild reproduces every transform
## byte-identically. The splat/favor stock stays the CarSpawner's T-147
## fleet; the dressing is the "tailgate stock reads full-ish year-round"
## scenery (events are R5/T-208's business).
func _build_parking() -> void:
	if traffic_graph == null:
		return
	parking = AmesParking.new(self, traffic_graph)
	var bodies: Array[Transform3D] = []
	var cabins: Array[Transform3D] = []
	for lot: AmesParking.Lot in parking.lots:
		for xf: Transform3D in lot.stalls:
			bodies.append(xf * Transform3D(
					Basis.from_scale(AmesParking.DRESS_BODY_SIZE),
					Vector3(0.0, AmesParking.DRESS_BODY_CY, 0.0)))
			cabins.append(xf * Transform3D(
					Basis.from_scale(AmesParking.DRESS_CABIN_SIZE),
					Vector3(0.0, AmesParking.DRESS_CABIN_CY, 0.0)))
	_lot_body_xfs = bodies
	_lot_cabin_xfs = cabins
	if bodies.is_empty():
		return
	var root := Node3D.new()
	root.name = "Parking"
	add_child(root)
	var body_aabb := _queue_aabb(bodies)
	var cabin_aabb := _queue_aabb(cabins)
	_spawn_lot_family(root, "LotBodies", bodies, body_aabb)
	_spawn_lot_family(root, "LotCabins", cabins, cabin_aabb)


## One colored dressing family: a MultiMeshInstance3D of the given
## transforms, each instance palette-cycled off the civilian body palette
## (deterministic by stall index), with the queue's AABB as the custom bound.
func _spawn_lot_family(root: Node3D, node_name: String,
		xfs: Array[Transform3D], aabb: AABB) -> void:
	var mm := _new_multimesh(xfs.size())
	var palette := Car.BODY_PALETTE
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, palette[i % palette.size()])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	mm.custom_aabb = aabb
	root.add_child(node)


## The world-local AABB covering every transform origin in the queue (the
## dressing boxes are small against the lots — the origins' bounds plus a
## 3 m pad bound them).
func _queue_aabb(xfs: Array[Transform3D]) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for xf: Transform3D in xfs:
		lo = lo.min(xf.origin)
		hi = hi.max(xf.origin)
	return AABB(lo - Vector3.ONE * 3.0, (hi - lo) + Vector3.ONE * 6.0)


## --- T-185 Lake LaVerne: the shore polish + the swans -----------------------
## The lake cluster's R3 ticket. The WATER body stays T-174's baked flat and
## the T-175 slots stay untouched — this ticket owns the SHORE + the BIRDS,
## both as runtime dressing over the committed bake (the T-180 corner-dress
## pattern: pure pack-derived geometry, zero colliders, zero RNG of any
## stream — a rebuild reproduces every transform byte-identically; the
## transform queues are retained for the gate). "Swap discipline" here: the
## polish replaces the T-174/T-175-era bare mown-band shore read AT the same
## waterline slot (the pack's own lake ring — no id moves, no new bake).

## The pale waterline fringe's width (m) — the proper shore read between the
## mown band and the water, per the ticket ("pale edge"). The survey's shore
## is lawn straight to the water with a few boulders and NO beach; a 1.2 m
## mineral fringe is the shoreline read, not a beach.
const PALE_EDGE_WIDTH := 1.2
## The pale fringe's box CENTER y. The house flat stack runs cell 0.014 <
## shore 0.018 < water 0.02 (box tops); the fringe rides ABOVE both at the
## road-paint clearance discipline (paint sits 10–20 mm over its ground):
## top at 0.03 — 12 mm over the shore band, 10 mm over the water top, and
## wherever a sharp ring corner folds it over the lake it reads as exactly
## what it is: the waterline fringe, never interior paint (bounded by
## PALE_EDGE_WIDTH everywhere).
const PALE_EDGE_CENTER_Y := 0.02
const COLOR_PALE_EDGE := Color(0.78, 0.755, 0.70) ## #C7C1B3 pale mineral gray.

## The reed hint: clumps of thin green slivers standing IN the water right
## at the shore (the `20-lake-laverne-swans-wide-bw.jpg` far-shore read).
## Placement is a stable hash of the ring edge — no RNG of any stream.
const COLOR_REED := Color(0.33, 0.42, 0.18) ## #546B2E reed green.
const REED_INSET := 1.0 ## m INTO the water off the ring edge (in-shore stand).
const REED_HASH_MOD := 3 ## Every ring edge whose stable hash says so carries ONE clump.
const REED_MIN_EDGE := 6.0 ## m — a shorter ring edge carries no clump.
const REED_SLIVER := 0.05 ## Sliver square section (m).
const REED_BASE_Y := 0.0 ## Sliver base (2 cm under the water top — rooted).

## The swan circuit (probe-derived 2026-11-14, pinned the T-181 insets way):
## the widest inscribed round in the lake's south basin — a 27 m circle at
## (230, −118) pack-local whose dense ring sample stays inside the water
## with a 2.67 m minimum shore clearance (and clear of Swan Island by
## construction — the basin's east side). Span 54 m ≤ the AC's 122 m bar;
## every point in-polygon is re-proved by `laverne_swans_present` from the
## committed pack (the scenario's own ring walk), so a pack change fails the
## same night.
const SWAN_CIRCUIT_CENTER := Vector2(230.0, -118.0)
const SWAN_CIRCUIT_RADIUS := 27.0
const SWAN_CIRCUIT_POINTS := 64
const SWAN_SPEED := 0.8 ## Paddle pace (m/s) — the slow lake circuit.
const SWAN_PHASES: Array[float] = [0.0, 0.45] ## Lancelot leads, Elaine follows.
const SWAN_TUCK_PHASES: Array[float] = [0.0, 0.5] ## Their idles desynced.

const SWAN_SCENE: PackedScene = preload("res://scenes/swan.tscn")


## The lake dress (the finish slice): along EVERY ring-split edge of the
## Lake LaVerne polygon — basin and Swan Island alike — one pale waterline
## fringe quad extruded onto the shore band, plus hash-picked reed clumps
## standing in the water just off the shore. Reeds sit IN-water at
## REED_INSET, which keeps them clear of the T-181 shore walk path (6.0 m
## OUT on the band), the T-176 shore bread ring (the same 6.0) and the swan
## circuit (≥ 1.6 m inside of the reeds).
func _build_lake_dress() -> void:
	var rings: Array[PackedVector2Array] = []
	for water: Dictionary in AmesDataPack.water():
		if str(water.get("name", "")) != "Lake LaVerne" or not water.has("polygon"):
			continue
		rings.append_array(AmesBaker._split_rings(AmesBaker._pack_points(
				water.get("polygon", []))))
	if rings.is_empty():
		return
	var pale: Array[Transform3D] = []
	var reeds: Array[Transform3D] = []
	var edge_counter := 0
	for ring: PackedVector2Array in rings:
		if ring.size() < 3:
			continue
		## The outward normal rides the ring's WINDING — the baker's own
		## shore-band rule (`_signed_area`), not a centroid facing: the
		## crescent's concave shores face away from any ring centroid, and
		## the reeds need the true water side (the round-1 probe caught
		## centroid-facing clumps standing on land in the north bay).
		var ccw := AmesBaker._signed_area(ring) >= 0.0
		for i: int in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			var edge := b - a
			if edge.length_squared() < 1e-10:
				continue ## The baker's own degenerate-edge law.
			var length := edge.length()
			var normal := (Vector2(edge.y, -edge.x) if ccw
					else Vector2(-edge.y, edge.x)) / length
			_queue_pale_edge(pale, a, b, normal)
			var h := hash(str(edge_counter))
			edge_counter += 1
			if h % REED_HASH_MOD != 0 or length < REED_MIN_EDGE:
				continue
			_queue_reed_clump(reeds, (a + b) * 0.5 - normal * REED_INSET, h)
	_pale_edge_xfs = pale
	_reed_xfs = reeds
	if pale.is_empty():
		return
	var root := Node3D.new()
	root.name = "Lake"
	add_child(root)
	var pale_aabb := _queue_aabb(pale)
	var mm := _new_multimesh(pale.size())
	for i: int in pale.size():
		mm.set_instance_transform(i, pale[i])
		mm.set_instance_color(i, COLOR_PALE_EDGE)
	mm.custom_aabb = pale_aabb
	var node := MultiMeshInstance3D.new()
	node.name = "PaleEdge"
	node.multimesh = mm
	root.add_child(node)
	if reeds.is_empty():
		return
	var reed_aabb := _queue_aabb(reeds)
	var rmm := _new_multimesh(reeds.size())
	var shade := COLOR_REED
	for i: int in reeds.size():
		rmm.set_instance_transform(i, reeds[i])
		## A stable per-sliver shade nudge (±5 %) so a stand reads as blades,
		## not one green box — hash-derived, still zero RNG.
		var v := 0.95 + float(hash(str(i)) % 11) * 0.01
		rmm.set_instance_color(i, Color(shade.r * v, shade.g * v, shade.b * v))
	rmm.custom_aabb = reed_aabb
	var rnode := MultiMeshInstance3D.new()
	rnode.name = "Reeds"
	rnode.multimesh = rmm
	root.add_child(rnode)


## One pale fringe quad: the ring edge extruded OUTWARD (onto the shore
## band), rendered as a thin box at the fringe's pinned stack level.
func _queue_pale_edge(queue: Array[Transform3D], a: Vector2, b: Vector2,
		normal: Vector2) -> void:
	var q0 := a + normal * PALE_EDGE_WIDTH
	var q1 := b + normal * PALE_EDGE_WIDTH
	var across := q1 - q0
	var along := a - q0
	var center := (a + b + q0 + q1) * 0.25
	queue.append(Transform3D(
			Basis(Vector3(across.x, 0.0, across.y), Vector3.UP * FLAT_THICKNESS,
					Vector3(along.x, 0.0, along.y)),
			Vector3(center.x, PALE_EDGE_CENTER_Y, center.y)))


## One reed clump: three slivers in a loose triangle around `pos`, heights
## and yaw derived from the edge hash `h` (deterministic, spread by design).
func _queue_reed_clump(queue: Array[Transform3D], pos: Vector2, h: int) -> void:
	for k: int in 3:
		var kh := hash(str(h, ":", k))
		var height := 0.6 + float((kh >> 4) % 5) * 0.12 ## 0.6 .. 1.08 m.
		var yaw := float(kh % 628) * 0.01 ## 0 .. 6.28 rad.
		var off := Vector2(
				float((kh >> 8) % 9 - 4) * 0.055, float((kh >> 12) % 9 - 4) * 0.055)
		var base := pos + off
		queue.append(Transform3D(
				Basis(Vector3.UP, yaw) * Basis.from_scale(
						Vector3(REED_SLIVER, height, REED_SLIVER)),
				Vector3(base.x, REED_BASE_Y + height * 0.5, base.y)))


## The swans (the finish slice): the probe-pinned circuit polyline at the
## water top, then exactly TWO ambient birds — Lancelot leads, Elaine
## follows — parented under `Swans/`, each handed the circuit, the pace and
## its own idle phase before entering the tree. No colliders, no bread
## spots, no citizen machinery: the T-185 scope guard lives in `swan.gd`.
func _build_swans() -> void:
	if _lake_ring().size() < 3:
		return ## No lake in the pack — no birds (the gate fails loudly).
	swan_circuit = PackedVector3Array()
	for i: int in SWAN_CIRCUIT_POINTS:
		var t := TAU * float(i) / float(SWAN_CIRCUIT_POINTS)
		swan_circuit.append(Vector3(
				SWAN_CIRCUIT_CENTER.x + SWAN_CIRCUIT_RADIUS * cos(t),
				AmesBaker.WATER_Y,
				SWAN_CIRCUIT_CENTER.y + SWAN_CIRCUIT_RADIUS * sin(t)))
	var root := Node3D.new()
	root.name = "Swans"
	add_child(root)
	swans = []
	var names: Array[String] = ["Lancelot", "Elaine"]
	for b: int in names.size():
		var swan: Swan = SWAN_SCENE.instantiate()
		swan.name = names[b]
		swan.circuit = swan_circuit
		swan.speed = SWAN_SPEED
		swan.phase = SWAN_PHASES[b]
		swan.tuck_phase = SWAN_TUCK_PHASES[b]
		root.add_child(swan)
		swans.append(swan)


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
		if not _hero_ids.has(hero_id) or hero_id == CAMPANILE_HERO_ID \
				or hero_id == BEARDSHEAR_HERO_ID:
			continue ## (T-186/T-188) the campanile's cap crumb is pinned; the
			## Beardshear hero files its own dome-top spot in its build below.
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
	var chunk_body := _build_chunk_colliders(chunk_root, chunk, center)
	_build_ground_record(chunk)
	_collect_roof_spots(chunk) ## (T-176) the roof-crumb hosts, while the doc is in hand.
	_build_campanile_hero(chunk_root, chunk, center, chunk_body) ## (T-186) the hero swap rides its own chunk.
	_build_campus_row_heroes(chunk_root, chunk, center, chunk_body) ## (T-188) the row heroes ride theirs.


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
## `_build_chunk_colliders`, which consumes the same entries. (T-186) the
## campanile's four placeholder parts are skipped — its hero supersedes the
## slot 1:1 and a hero must not render twice.
func _placeholders_multimesh(chunk: Dictionary, center: Vector3) -> MultiMesh:
	var placeholders: Array = chunk.get("placeholders", [])
	var count := 0
	for ph: Dictionary in placeholders:
		if not _row_superseded_placeholder(str(ph.get("id", ""))):
			count += 1
	if count == 0:
		return null
	var mm := _new_multimesh(count)
	var i := 0
	for ph: Dictionary in placeholders:
		if _row_superseded_placeholder(str(ph.get("id", ""))):
			continue
		var p: Array = ph["p"]
		var s: Array = ph["s"]
		var c: Array = ph["c"]
		mm.set_instance_transform(i, Transform3D(
				Basis.from_scale(Vector3(s[0], s[1], s[2])),
				Vector3(p[0], p[1], p[2]) - center))
		mm.set_instance_color(i, Color(c[0], c[1], c[2]))
		i += 1
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
## landable pad (the anchor-cap rule). (T-186) the campanile's placeholder
## boxes are superseded by its hero's own shapes on this same body — the
## capture above still reads the bake's cap part to pin the crumb anchor.
## Procedural filler stays visual-only
## massing — the ticket's scope is the ~540 authored positions. (The ~600
## shapes are not counted in `render_metrics().buffer_bytes` — the metric
## covers the GPU-side resident estimate, not physics shapes.) Returns the
## body (null when the chunk had no entries) — the T-186 hero appends its own
## shapes to the SAME body, the 1:1 swap's collision class; the name lookup
## cannot serve here (the gray `Placeholders` MultiMeshInstance3D already
## took the name, and Godot auto-renames the second child).
func _build_chunk_colliders(chunk_root: Node3D, chunk: Dictionary, center: Vector3) -> StaticBody3D:
	var entries: Array = []
	for m: Dictionary in chunk.get("massing", []):
		if m.get("a", false) and not _is_hero_massing(m):
			entries.append(m)
	for ph: Dictionary in chunk.get("placeholders", []):
		entries.append(ph)
	if entries.is_empty():
		return null
	var body := StaticBody3D.new()
	body.name = "Placeholders"
	body.collision_layer = 1 ## world
	body.collision_mask = 0
	chunk_root.add_child(body)
	for e: Dictionary in entries:
		var pid := str(e.get("id", ""))
		if pid == CAMPANILE_HERO_ID:
			## (T-186) The hero's own collision supersedes the placeholder
			## boxes 1:1 (same body, same layer-1 `world` class) — the build
			## below files it. The cap capture stays: the crumb pin rides the
			## bake's cap part, exactly the T-175 anchor convention.
			if str(e.get("part", "")) == "cap":
				var cp: Array = e["p"]
				var cs: Array = e["s"]
				_campanile_cap = Vector3(float(cp[0]), float(cp[1]) + float(cs[1]) * 0.5,
						float(cp[2]))
			continue
		if pid == BEARDSHEAR_HERO_ID:
			## (T-188) The Beardshear hero's own collision supersedes its slot's
			## block/dome/dome_cap placeholder parts the same 1:1 way — its
			## build files the shapes; the dome-top crumb comes from the hero's
			## own schedule, so no capture is needed here.
			continue
		var p: Array = e["p"]
		var s: Array = e["s"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
		shape.shape = box
		shape.position = Vector3(float(p[0]), float(p[1]), float(p[2])) - center
		body.add_child(shape)
	return body


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
## entries file alongside — (T-186) except the campanile's: its hero files
## those tops itself.
func _build_ground_record(chunk: Dictionary) -> void:
	var tiles: Dictionary = {} ## tile Vector2i -> Array of floats, packed below.
	var bytes := 0
	for m: Dictionary in chunk.get("massing", []):
		if _is_hero_massing(m):
			continue
		bytes += _file_ground_box(tiles, m["p"], m["s"])
	for ph: Dictionary in chunk.get("placeholders", []):
		if _row_superseded_placeholder(str(ph.get("id", ""))):
			continue ## (T-186/T-188) those heroes file their own true tops below.
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


## --- T-187 Central Campus: the lawn slab, the axes, the fountain -----------
## The lawn cluster's R3 ticket. The bake's park polygon already renders the
## mown-lawn flat (`lawn_tris`, #6F8F4F) — this ticket owns the LAWN READ:
## the quad-green slab tint, the pale concrete path ribbons over the committed
## lawn layer's walk chains (the two crossing sight axes among them), and the
## Four Seasons fountain as the data-position prop. All runtime dressing over
## the committed bake (the T-180 corner-dress pattern: pure data-derived
## geometry, zero RNG of any stream — a rebuild reproduces every transform
## byte-identically; the transform queues are retained for the gate). The
## dress families live OUTSIDE the bake-derived render metric exactly like
## the T-180/T-181/T-185 corner dresses.

## The quad lawn green — MODELING-SPECS §1.4's campus-buildings palette row
## ("Quad lawn #5F7F42"), tinted over the bake's generic mown lawn so the
## biggest single open shape in town wears its own green.
const COLOR_QUAD_LAWN := Color(0.373, 0.498, 0.259) ## #5F7F42.
## The path ribbons' pale concrete — the same palette row ("paths #C9C3B4").
const COLOR_CAMPUS_PATH := Color(0.788, 0.765, 0.706) ## #C9C3B4.
## The slab flat rides ABOVE the bake's lawn tris (box top 0.04) — at 30 mm,
## the clearance the ribbon read proved depth-safe at 200+ m (a 10 mm stack
## loses the depth fight against the bake flat at range and the tint
## vanishes; the paths at the old 30 mm stayed crisp). The plaza paving
## paints one step above the slab it sits IN (the plaza is inside the lawn
## polygon's south tip), and the ribbon boxes stack their top (center 0.075
## + half thickness) between the slab and the road paint (top 0.09), so
## paths paint over the lawn and UNDER the roads they cross.
const SLAB_TRI_Y := 0.07
const PLAZA_TRI_Y := 0.08
const RIBBON_CENTER_Y := 0.075

## The Four Seasons fountain (geometry-hint level; figures = simplified, the
## ticket's own scope line). Proportions off the data ring's bbox
## (~11.7 x 5.9 m — a long low basin) and `images/campus/21`/`24`: a
## knee-height stone rim, water inside, the tall thin center jet, four
## kneeling-figure blocks standing on the rim coping.
const FOUNTAIN_RIM_TOP := 0.55
const FOUNTAIN_RIM_T := 0.5 ## Rim wall thickness (m).
const FOUNTAIN_WATER_TOP := 0.35
const FOUNTAIN_JET_SIZE := Vector3(0.35, 1.5, 0.35) ## The thin spray column.
const FOUNTAIN_FIGURE_SIZE := Vector3(0.55, 0.95, 0.45) ## A kneeling figure block.
const COLOR_FOUNTAIN_STONE := Color(0.776, 0.753, 0.698) ## #C6C0B2 limestone trim (§1.1).
const COLOR_FOUNTAIN_WATER := Color(0.275, 0.329, 0.247) ## #46543F olive-brown (§1.2 lake).
const COLOR_FOUNTAIN_JET := Color(0.82, 0.86, 0.88) ## The spray's pale read (photo 24).


## The lawn dress (the finish slice). Everything derives from the committed
## lawn layer (`AmesDataPack.campus_lawn()`) and the pack's own Central
## Campus polygon; nothing here reads the world's own constants back.
func _build_campus_lawn() -> void:
	var lawn: Dictionary = AmesDataPack.campus_lawn()
	if lawn.is_empty():
		return ## The layer is missing — the dress builds empty, the gate fails loudly.
	var root := Node3D.new()
	root.name = "CampusLawn"
	add_child(root)
	_build_campus_slab(root, lawn)
	_build_campus_ribbons(root, lawn)
	_build_campus_fountain(root, lawn)


## The quad-green slab: the pack's Central Campus polygon ear-clipped into
## flat tris one FLAT step above the bake's mown-lawn flat (the tint), plus
## the fountain plaza's paving flat from the lawn layer's plaza ring.
func _build_campus_slab(root: Node3D, lawn: Dictionary) -> void:
	var slab_tris := _campus_flat_tris(root, "SlabTris", _campus_polygon(),
			COLOR_QUAD_LAWN, SLAB_TRI_Y)
	campus_slab_tris = slab_tris
	var ring := _lawn_ring(lawn, "plaza_ring")
	if ring.size() >= 3:
		campus_plaza_tris = _campus_flat_tris(root, "PlazaTris", ring,
				COLOR_CAMPUS_PATH, PLAZA_TRI_Y)


## One polygon's flat-tri family: ear-clipped (the baker's own triangulator,
## the same code the bake used for the parks — fed through the baker's own
## ring-split first, so the OSM closure duplicate never reaches the clip:
## a degenerate ring stalls it into the fan fallback and the family paints
## giant sweep triangles over the lawn), rendered as ONE vertex-colored
## ArrayMesh on a MeshInstance3D — the T-186 CapRoof's proven runtime
## pattern (the world's unit-tri MultiMesh path renders the bake's
## chunk-mounted families but went invisible under this dress's own node;
## the mesh-carried vertex colors need no instance buffer at all). One node
## per family, at the family's own stack level.
func _campus_flat_tris(root: Node3D, node_name: String, poly: PackedVector2Array,
		color: Color, tri_y: float) -> int:
	var tris := AmesBaker._triangulate(poly)
	if tris.is_empty():
		return 0
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for t: Vector3i in tris:
		for idx: int in [t.x, t.y, t.z]:
			verts.append(Vector3(poly[idx].x, tri_y, poly[idx].y))
			## Mesh-carried vertex colors ride the shader as LINEAR values,
			## while the MultiMesh instance-color families (the bake's flats,
			## the ribbons, the benches) take their sRGB numbers as-is — the
			## same hex renders washed-bright through this path otherwise
			## (the round-1 screenshots: the tint read pale, the district
			## cells next to it dark). Convert once, at the mesh build.
			colors.append(_srgb_to_linear(color))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := _make_vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	root.add_child(node)
	return tris.size()


## The path ribbons: one pale concrete box per chain segment of every lawn
## layer chain, extruded to the chain's data width at the pinned stack level
## (the T-185 pale-edge extrusion, centered). Visual-only — the walks are
## dressing, not a collision or ground layer.
func _build_campus_ribbons(root: Node3D, lawn: Dictionary) -> void:
	var xfs: Array[Transform3D] = []
	for path: Dictionary in lawn.get("paths", []):
		var chain_pts := _lawn_chain(path)
		var width := float(path.get("width_m", 3.0))
		for i in chain_pts.size() - 1:
			_queue_ribbon(xfs, chain_pts[i], chain_pts[i + 1], width)
	campus_ribbon_xfs = xfs
	if xfs.is_empty():
		return
	var mm := _new_multimesh(xfs.size())
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, COLOR_CAMPUS_PATH)
	mm.custom_aabb = _queue_aabb(xfs)
	var node := MultiMeshInstance3D.new()
	node.name = "PathRibbons"
	node.multimesh = mm
	root.add_child(node)


## One ribbon segment box: the chain segment extruded symmetric to its
## centerline (the walk reads as a path of the data width), rendered at the
## pinned ribbon level above the slab.
func _queue_ribbon(queue: Array[Transform3D], a: Vector2, b: Vector2,
		width: float) -> void:
	var seg := b - a
	if seg.length_squared() < 1e-10:
		return
	var dir := seg / seg.length()
	var n := Vector2(dir.y, -dir.x)
	var center := (a + b) * 0.5
	var seg3 := Vector3(seg.x, 0.0, seg.y)
	queue.append(Transform3D(
			Basis(Vector3(n.x, 0.0, n.y) * width, Vector3.UP * FLAT_THICKNESS, seg3),
			Vector3(center.x, RIBBON_CENTER_Y, center.y)))


## The Four Seasons fountain: the data ring's bbox block schedule at the
## ring's own center (the data position — never a moved or hand-picked one),
## with a real rim collider (the §1.1 rim-perch note) whose solid boxes file
## their ground tops (the T-186 hero's walkability law, scoped to the prop).
func _build_campus_fountain(root: Node3D, lawn: Dictionary) -> void:
	var ring := _lawn_ring(lawn, "ring")
	if ring.size() < 3:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var acc := Vector2.ZERO
	for p: Vector2 in ring:
		lo = lo.min(p)
		hi = hi.max(p)
		acc += p
	var c := acc / float(ring.size()) ## The data position: the ring's vertex mean.
	var bw := hi.x - lo.x
	var bd := hi.y - lo.y
	var parts: Array[Dictionary] = []
	## The rim: four stone walls hugging the data ring's bbox (the oval's
	## block-schedule read; the short walls run between the long ones).
	var dw := bw * 0.5 - FOUNTAIN_RIM_T * 0.5
	var dd := bd * 0.5 - FOUNTAIN_RIM_T * 0.5
	var long_len := bw - FOUNTAIN_RIM_T * 2.0
	var short_len := bd - FOUNTAIN_RIM_T * 2.0
	_add_fountain_part(parts, "rim", Vector3(c.x, FOUNTAIN_RIM_TOP * 0.5, c.y + dd),
			Vector3(long_len, FOUNTAIN_RIM_TOP, FOUNTAIN_RIM_T), COLOR_FOUNTAIN_STONE)
	_add_fountain_part(parts, "rim", Vector3(c.x, FOUNTAIN_RIM_TOP * 0.5, c.y - dd),
			Vector3(long_len, FOUNTAIN_RIM_TOP, FOUNTAIN_RIM_T), COLOR_FOUNTAIN_STONE)
	_add_fountain_part(parts, "rim", Vector3(c.x + dw, FOUNTAIN_RIM_TOP * 0.5, c.y),
			Vector3(FOUNTAIN_RIM_T, FOUNTAIN_RIM_TOP, short_len), COLOR_FOUNTAIN_STONE)
	_add_fountain_part(parts, "rim", Vector3(c.x - dw, FOUNTAIN_RIM_TOP * 0.5, c.y),
			Vector3(FOUNTAIN_RIM_T, FOUNTAIN_RIM_TOP, short_len), COLOR_FOUNTAIN_STONE)
	## The water inside the rim, under the coping.
	_add_fountain_part(parts, "water",
			Vector3(c.x, FOUNTAIN_WATER_TOP * 0.5, c.y),
			Vector3(long_len, FOUNTAIN_WATER_TOP, short_len), COLOR_FOUNTAIN_WATER,
			false, false)
	## The center jet: the tall thin spray column (photo 24).
	_add_fountain_part(parts, "jet",
			Vector3(c.x, FOUNTAIN_WATER_TOP + FOUNTAIN_JET_SIZE.y * 0.5, c.y),
			FOUNTAIN_JET_SIZE, COLOR_FOUNTAIN_JET, false, false)
	## The four kneeling figures (simplified blocks) standing on the rim
	## coping, one per wall midpoint — the photo's four-station read.
	_add_fountain_part(parts, "figure",
			Vector3(c.x, FOUNTAIN_RIM_TOP + FOUNTAIN_FIGURE_SIZE.y * 0.5, c.y + dd),
			FOUNTAIN_FIGURE_SIZE, COLOR_FOUNTAIN_STONE)
	_add_fountain_part(parts, "figure",
			Vector3(c.x, FOUNTAIN_RIM_TOP + FOUNTAIN_FIGURE_SIZE.y * 0.5, c.y - dd),
			FOUNTAIN_FIGURE_SIZE, COLOR_FOUNTAIN_STONE)
	_add_fountain_part(parts, "figure",
			Vector3(c.x + dw, FOUNTAIN_RIM_TOP + FOUNTAIN_FIGURE_SIZE.y * 0.5, c.y),
			FOUNTAIN_FIGURE_SIZE, COLOR_FOUNTAIN_STONE)
	_add_fountain_part(parts, "figure",
			Vector3(c.x - dw, FOUNTAIN_RIM_TOP + FOUNTAIN_FIGURE_SIZE.y * 0.5, c.y),
			FOUNTAIN_FIGURE_SIZE, COLOR_FOUNTAIN_STONE)
	fountain_parts = parts
	## Render + collide: one vertex-color box MM, and the `collide` boxes as
	## shapes on one layer-1 body (the rim IS the perch).
	var mm := _new_multimesh(parts.size())
	var collide_parts: Array[Dictionary] = []
	for i in parts.size():
		var b: Dictionary = parts[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(b["s"]), b["p"]))
		mm.set_instance_color(i, b["color"])
		if bool(b["collide"]):
			collide_parts.append(b)
	mm.custom_aabb = _queue_aabb_from_dict_parts(parts)
	var node := MultiMeshInstance3D.new()
	node.name = "FountainBoxes"
	node.multimesh = mm
	root.add_child(node)
	if collide_parts.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "FountainRim"
	body.collision_layer = 1 ## world
	body.collision_mask = 0
	root.add_child(body)
	for b: Dictionary in collide_parts:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b["s"]
		shape.shape = box
		shape.position = b["p"]
		body.add_child(shape)
	## Ground tops: the rim and the figures answer the walkability query (the
	## bread lattice drops points inside the basin; the staging guards read
	## the solid prop the same way they read any massing).
	var tiles: Dictionary = {}
	var bytes := 0
	for b: Dictionary in collide_parts:
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		bytes += _file_ground_box(tiles, [p.x, p.y, p.z], [s.x, s.y, s.z])
	for key: Vector2i in tiles:
		var record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = record.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		record["ground"] = ground
		_chunks[key] = record
	_buffer_bytes += bytes


## One fountain part record: `{kind, p, s, color, collide}` in world-local
## (pack) coordinates; `collide` boxes join the rim body; `ground` boxes file
## their walkability tops.
func _add_fountain_part(out: Array[Dictionary], kind: String, p: Vector3,
		s: Vector3, color: Color, collide := true, ground := true) -> void:
	out.append({"kind": kind, "p": p, "s": s, "color": color,
			"collide": collide, "ground": ground})


## The exact sRGB -> linear transfer (the IEC piecewise curve) — the mesh
## path's color conversion (`Color` carries no `to_linear` in 4.7).
func _srgb_to_linear(c: Color) -> Color:
	var channel := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return Color(channel.call(c.r), channel.call(c.g), channel.call(c.b), c.a)


## The pack's Central Campus polygon, ring-split (the bake's own helpers).
func _campus_polygon() -> PackedVector2Array:
	var biggest := PackedVector2Array()
	for park: Dictionary in AmesDataPack.parks():
		if str(park.get("name", "")) != "Central Campus":
			continue
		for r: PackedVector2Array in AmesBaker._split_rings(
				AmesBaker._pack_points(park.get("polygon", []))):
			if r.size() > biggest.size():
				biggest = r
	return biggest


## One lawn-layer ring by field name, packed and RING-SPLIT (the baker's own
## dedupe law — the OSM closure duplicate is a degenerate vertex for the
## ear-clip; the split also handles any self-touching seam the way the bake
## prepared every stored polygon).
func _lawn_ring(lawn: Dictionary, field: String) -> PackedVector2Array:
	var fountain: Dictionary = lawn.get("fountain", {})
	var raw := PackedVector2Array()
	for q: Variant in fountain.get(field, []):
		raw.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
	var biggest := PackedVector2Array()
	for ring: PackedVector2Array in AmesBaker._split_rings(raw):
		if ring.size() > biggest.size():
			biggest = ring
	return biggest


## One lawn-layer chain, packed.
func _lawn_chain(path: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q: Variant in path.get("chain", []):
		out.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
	return out


## The world-local AABB over the fountain part record set.
func _queue_aabb_from_dict_parts(parts: Array[Dictionary]) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for b: Dictionary in parts:
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		lo = lo.min(p - s * 0.5)
		hi = hi.max(p + s * 0.5)
	return AABB(lo - Vector3.ONE, (hi - lo) + Vector3.ONE * 2.0)


## --- T-186 the campanile hero ----------------------------------------------
## The #1 emotional object in Ames at hero fidelity, swapping the T-175
## placeholder slot 1:1: same id (`CAMPANILE_HERO_ID`), same chunk slot, same
## collision class (layer-1 `world` static shapes on the chunk's own body).
## The silhouette is MODELING-SPECS §1.1's photo read — buff/tan brick (F-01:
## NOT red; the dossier's red was corrected by the photos), a slender 4.9 m
## shaft, the three open-arcade head tiers (the 50-bell carillon read — real
## through-openings: only the piers, mullions and crowns collide up there), a
## white clock per face at ~2/3 height and the dark slate cap whose truncated
## pyramid ends in the LANDABLE deck at exactly 33.5 m (the T-175 anchor-cap
## rule carries: the crumb stays pinned at the cap top + ANCHOR_CRUMB_LIFT).
## Like every corner dress: pure pack-derived geometry, zero RNG of any
## stream — a rebuild reproduces every transform — and the part record is
## retained for the gate (headless runs cannot read MultiMesh instances back).

## (T-186) The pinned palette — MODELING-SPECS §1.1's photo-corrected hex
## estimates, one band per hero family. The palette gate re-derives these
## hexes from the survey doc itself (never from these constants) and holds
## the live colors against them.
const CAMPANILE_BRICK := Color(0.788, 0.647, 0.416) ## #C9A56A sunlit buff brick.
const CAMPANILE_BRICK_SHADE := Color(0.541, 0.427, 0.247) ## #8A6D3F mid/shaded brick (the receding upper stages).
const CAMPANILE_SLOT := Color(0.431, 0.333, 0.200) ## #6E5533 recessed slots / deep shadow.
const CAMPANILE_SLATE := Color(0.247, 0.267, 0.302) ## #3F444D the pyramidal cap.
const CAMPANILE_CLOCK := Color(0.945, 0.933, 0.906) ## #F1EEE7 the clock dials.
const CAMPANILE_TRIM := Color(0.776, 0.753, 0.698) ## #C6C0B2 limestone trim.
const CAMPANILE_HAND := Color(0.18, 0.18, 0.18) ## The dial hands — the black-numerals read.

## The band -> color table (the record and the render share this one mapping).
const CAMPANILE_BANDS: Dictionary = {
	"brick": CAMPANILE_BRICK,
	"brick_shade": CAMPANILE_BRICK_SHADE,
	"slot": CAMPANILE_SLOT,
	"slate": CAMPANILE_SLATE,
	"clock": CAMPANILE_CLOCK,
	"trim": CAMPANILE_TRIM,
	"hand": CAMPANILE_HAND,
}

## The tier-stack heights (m) — the T-175 slot spans kept EXACTLY (plinth
## 0..2.0, shaft ..26.4, head ..30.9, cap ..33.5 — the bake's 33.5-exact
## anchor stack) with the head band subdivided into the three open-arcade
## tiers and the cap mass re-read as the truncated pyramid + landable deck
## the photos show. Each tier's floor is the tier below's crown (or the shaft
## top), so a perch-through pigeon can stand INSIDE every stage; the deck top
## is the pad.
const CAMPANILE_TIER1_TOP := 28.4
const CAMPANILE_TIER2_TOP := 29.5
const CAMPANILE_TIER3_TOP := 30.9
const CAMPANILE_CORONA_TOP := 31.12
const CAMPANILE_DECK_BOTTOM := 33.3
const CAMPANILE_DECK_TOP := 33.5 ## The survey's settled total — the pad.
const CAMPANILE_DIAL_Y := 21.5 ## The clock stage, just under 2/3 of the 33.5 m height.


func _campanile_band_color(band: String) -> Color:
	return CAMPANILE_BANDS.get(band, CAMPANILE_BRICK)


## Builds the hero into its chunk: render (box MultiMesh + the cap frustum
## mesh + the four clock dials), collision (the hero's own shapes on the
## chunk's placeholder body — the SAME slot and class the T-175 boxes rode,
## passed in from `_build_chunk_colliders`), ground-record tops (the
## superseded placeholders file nothing anymore), and the retained part
## record the gates walk. No-op for every chunk that does not carry the
## campanile slot.
func _build_campanile_hero(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var c := Vector2.ZERO
	var found := false
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) != CAMPANILE_HERO_ID or str(ph.get("part", "")) != "shaft":
			continue
		c = Vector2(float(ph["p"][0]), float(ph["p"][2]))
		found = true
		break
	if not found:
		return ## Not this chunk's slot (or the bake lost the shaft — the dims gate fails loudly).
	var boxes := _campanile_hero_boxes(c)
	var root := Node3D.new()
	root.name = "HeroCampanile"
	chunk_root.add_child(root)
	## Render: every box through the vertex-color unit box, chunk-local like
	## every placeholder family member.
	var mm := _new_multimesh(boxes.size())
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(s), p - center))
		mm.set_instance_color(i, _campanile_band_color(str(b["band"])))
	mm.custom_aabb = _campanile_hero_aabb(boxes, center)
	var mm_node := MultiMeshInstance3D.new()
	mm_node.name = "Boxes"
	mm_node.multimesh = mm
	root.add_child(mm_node)
	## The cap's truncated pyramid: one double-sided vertex-color mesh.
	var roof := MeshInstance3D.new()
	roof.name = "CapRoof"
	roof.mesh = _make_campanile_cap_mesh()
	var roof_center := Vector3(c.x, (CAMPANILE_CORONA_TOP + CAMPANILE_DECK_BOTTOM) * 0.5, c.y)
	roof.position = roof_center - center
	root.add_child(roof)
	## The four clock dials (round — the white dot every lawn photo carries).
	var dial_mesh := _make_campanile_dial_mesh()
	for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var dial := MeshInstance3D.new()
		dial.name = "Clock%s" % dir
		dial.mesh = dial_mesh
		dial.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)),
				Vector3(c.x, CAMPANILE_DIAL_Y, c.y) + dir * 2.5 - center)
		root.add_child(dial)
	## Collision: the hero's own shapes ride the chunk's placeholder body —
	## same slot, same layer-1 `world` class (the T-175 boxes were removed
	## from this body's feed in `_build_chunk_colliders`).
	var body := chunk_body
	if body == null:
		body = StaticBody3D.new()
		body.name = "Placeholders"
		body.collision_layer = 1 ## world
		body.collision_mask = 0
		chunk_root.add_child(body)
	for b: Dictionary in boxes:
		if not b["collide"]:
			continue
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s
		shape.shape = box
		shape.position = p - center
		body.add_child(shape)
	## The cap mass: one convex solid from the corona up to the deck rim —
	## the pyramidal roof is solid at flight speeds.
	var cap_shape := CollisionShape3D.new()
	var cap_convex := ConvexPolygonShape3D.new()
	cap_convex.points = PackedVector3Array([
		Vector3(-2.5, -1.09, -2.45), Vector3(2.5, -1.09, -2.45),
		Vector3(2.5, -1.09, 2.45), Vector3(-2.5, -1.09, 2.45),
		Vector3(-1.2, 1.09, -1.2), Vector3(1.2, 1.09, -1.2),
		Vector3(1.2, 1.09, 1.2), Vector3(-1.2, 1.09, 1.2),
	])
	cap_shape.shape = cap_convex
	cap_shape.position = roof_center - center
	body.add_child(cap_shape)
	## Ground record: the hero files its own true tops where the superseded
	## placeholders used to (the shaft top, the three tier crowns, the corona
	## and the landable deck answer the walkability query now).
	var tiles: Dictionary = {}
	var bytes := 0
	for b: Dictionary in boxes:
		if not b["ground"]:
			continue
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		bytes += _file_ground_box(tiles, [p.x, p.y, p.z], [s.x, s.y, s.z])
	for key: Vector2i in tiles:
		var record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = record.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		record["ground"] = ground
		_chunks[key] = record
	_buffer_bytes += bytes
	## Retain the part record (world-local bands, positions, sizes, colors)
	## for the gates — headless runs cannot read the instances back.
	for b: Dictionary in boxes:
		campanile_hero_parts.append({
			"band": str(b["band"]),
			"p": b["p"],
			"s": b["s"],
			"color": _campanile_band_color(str(b["band"])),
		})


## The hero's box schedule in WORLD-LOCAL coordinates (pack-local — the world
## node IS the pack frame), one entry per box: `{band, p, s, collide, ground}`.
## `collide` boxes join the chunk's layer-1 body; `ground` boxes file their
## top into the walkability record. Every height rides the pinned tier-stack
## constants; every span rides the survey (plinth 6.8 × 6.7, shaft 4.9 — the
## OSM 6.8 × 6.7 bbox is the plinth, the shaft stays ~5 m).
func _campanile_hero_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	## The four faces as [outward, horizontal] pairs (+z is south here).
	var faces := [
		[Vector3.RIGHT, Vector3.BACK], ## East.
		[Vector3.LEFT, Vector3.BACK], ## West.
		[Vector3.BACK, Vector3.RIGHT], ## South.
		[Vector3.FORWARD, Vector3.RIGHT], ## North.
	]
	## --- plinth: the battered base, limestone-trimmed entrance arch ---------
	_add_campanile_box(out, "brick", Vector3(c.x, 1.0, c.y), Vector3(6.8, 2.0, 6.7), true, true)
	_add_campanile_box(out, "trim", Vector3(c.x, 0.125, c.y), Vector3(6.9, 0.25, 6.8), false, false)
	## The entrance arch on the WEST face (−X, the lawn side): dark opening,
	## limestone lintel + flanking buttresses.
	_add_campanile_box(out, "slot", Vector3(c.x - 3.34, 0.95, c.y), Vector3(0.12, 1.9, 1.5), false, false)
	_add_campanile_box(out, "trim", Vector3(c.x - 3.33, 1.98, c.y), Vector3(0.14, 0.25, 1.9), false, false)
	_add_campanile_box(out, "trim", Vector3(c.x - 3.25, 1.0, c.y - 1.15), Vector3(0.3, 2.0, 0.45), false, false)
	_add_campanile_box(out, "trim", Vector3(c.x - 3.25, 1.0, c.y + 1.15), Vector3(0.3, 2.0, 0.45), false, false)
	## --- shaft: the slender buff needle, slim lancet slots stacked down it --
	_add_campanile_box(out, "brick", Vector3(c.x, 14.2, c.y), Vector3(4.9, 24.4, 4.9), true, true)
	for f: Array in faces:
		var n: Vector3 = f[0]
		var h: Vector3 = f[1]
		var thin := Vector3(0.06, 1.9, 0.35) if absf(n.x) > 0.5 else Vector3(0.35, 1.9, 0.06)
		for off: float in [-0.55, 0.55]: ## The upper lancet pair (under the belfry).
			_add_campanile_box(out, "slot",
					Vector3(c.x, 23.35, c.y) + n * 2.47 + h * off, thin, false, false)
		_add_campanile_box(out, "slot", ## The mid-shaft single.
				Vector3(c.x, 16.95, c.y) + n * 2.47, thin, false, false)
	## The clock stringcourse under the belfry.
	_add_campanile_box(out, "trim", Vector3(c.x, 26.2, c.y), Vector3(5.3, 0.3, 5.2), false, false)
	## --- head: the three open-arcade tiers (the 50-bell carillon read) -----
	## Tier 1 (26.4..28.4): two tall lancet openings per face — corner piers
	## + a center mullion per face, dark core depth, walkable crown.
	var t1_open_mid := (26.4 + CAMPANILE_TIER1_TOP - 0.35) * 0.5 ## 27.225
	for k: int in 4:
		var sx := -1.0 if k % 2 == 0 else 1.0
		var sz := -1.0 if k < 2 else 1.0
		_add_campanile_box(out, "brick",
				Vector3(c.x + sx * 2.075, 27.4, c.y + sz * 2.075),
				Vector3(0.75, 2.0, 0.75), true, false)
	var t1_mull_thin := Vector3(0.45, 1.65, 0.4)
	var t1_mull_flat := Vector3(0.4, 1.65, 0.45)
	for f: Array in faces:
		var n1: Vector3 = f[0]
		_add_campanile_box(out, "brick", Vector3(c.x, t1_open_mid, c.y) + n1 * 2.225,
				t1_mull_thin if absf(n1.x) > 0.5 else t1_mull_flat, true, false)
	_add_campanile_box(out, "brick", Vector3(c.x, CAMPANILE_TIER1_TOP - 0.175, c.y),
			Vector3(5.0, 0.35, 4.9), true, true)
	_add_campanile_box(out, "slot", Vector3(c.x, t1_open_mid, c.y),
			Vector3(3.1, 1.65, 3.05), false, false)
	## Tier 2 (28.4..29.5): the receding middle stage, two smaller openings
	## per face — its masonry wears the shaded band (the photos' receding read).
	var t2_open_mid := (CAMPANILE_TIER1_TOP + CAMPANILE_TIER2_TOP - 0.3) * 0.5 ## 28.85
	for k: int in 4:
		var sx2 := -1.0 if k % 2 == 0 else 1.0
		var sz2 := -1.0 if k < 2 else 1.0
		_add_campanile_box(out, "brick_shade",
				Vector3(c.x + sx2 * 2.05, 28.95, c.y + sz2 * 2.05),
				Vector3(0.6, 1.1, 0.6), true, false)
	var t2_mull_thin := Vector3(0.4, 0.8, 0.35)
	var t2_mull_flat := Vector3(0.35, 0.8, 0.4)
	for f: Array in faces:
		var n2: Vector3 = f[0]
		_add_campanile_box(out, "brick_shade", Vector3(c.x, t2_open_mid, c.y) + n2 * 2.125,
				t2_mull_thin if absf(n2.x) > 0.5 else t2_mull_flat, true, false)
	_add_campanile_box(out, "brick_shade", Vector3(c.x, CAMPANILE_TIER2_TOP - 0.15, c.y),
			Vector3(4.7, 0.3, 4.65), true, true)
	_add_campanile_box(out, "slot", Vector3(c.x, t2_open_mid, c.y),
			Vector3(2.7, 0.8, 2.65), false, false)
	## Tier 3 (29.5..30.9): the crown colonnade — one wide opening per face.
	var t3_open_mid := (CAMPANILE_TIER2_TOP + CAMPANILE_TIER3_TOP - 0.35) * 0.5 ## 30.025
	for k: int in 4:
		var sx3 := -1.0 if k % 2 == 0 else 1.0
		var sz3 := -1.0 if k < 2 else 1.0
		_add_campanile_box(out, "brick_shade",
				Vector3(c.x + sx3 * 1.975, 30.2, c.y + sz3 * 1.975),
				Vector3(0.55, 1.4, 0.55), true, false)
	_add_campanile_box(out, "brick_shade", Vector3(c.x, CAMPANILE_TIER3_TOP - 0.175, c.y),
			Vector3(4.8, 0.35, 4.4), true, true)
	_add_campanile_box(out, "slot", Vector3(c.x, t3_open_mid, c.y),
			Vector3(2.3, 1.05, 2.25), false, false)
	## --- cap: the corona table, the crocketed corner pinnacles, the
	## truncated-pyramid roof, the LANDABLE deck ------------------------------
	_add_campanile_box(out, "slate",
			Vector3(c.x, (CAMPANILE_TIER3_TOP + CAMPANILE_CORONA_TOP) * 0.5, c.y),
			Vector3(5.2, 0.22, 5.1), true, true)
	for k: int in 4:
		var px := -2.15 if k % 2 == 0 else 2.15
		var pz := -2.15 if k < 2 else 2.15
		_add_campanile_box(out, "brick",
				Vector3(c.x + px, (CAMPANILE_CORONA_TOP + 32.9) * 0.5, c.y + pz),
				Vector3(0.45, 32.9 - CAMPANILE_CORONA_TOP, 0.45), false, false)
		_add_campanile_box(out, "slate",
				Vector3(c.x + px, (32.9 + 33.25) * 0.5, c.y + pz),
				Vector3(0.22, 0.35, 0.22), false, false)
	_add_campanile_box(out, "slate",
			Vector3(c.x, (CAMPANILE_DECK_BOTTOM + CAMPANILE_DECK_TOP) * 0.5, c.y),
			Vector3(2.5, CAMPANILE_DECK_TOP - CAMPANILE_DECK_BOTTOM, 2.45), true, true)
	## The clock hands (render-only, riding the dial faces).
	for f: Array in faces:
		var n3: Vector3 = f[0]
		var h3: Vector3 = f[1]
		var hand := Vector3(0.06, 0.08, 0.85) if absf(n3.x) > 0.5 else Vector3(0.85, 0.08, 0.06)
		_add_campanile_box(out, "hand",
				Vector3(c.x, CAMPANILE_DIAL_Y, c.y) + n3 * 2.58 + h3 * 0.28, hand, false, false)
	return out


## One box into the schedule (typed push keeps the Array[Dictionary] contract).
func _add_campanile_box(out: Array[Dictionary], band: String, p: Vector3, s: Vector3,
		collide: bool, ground: bool) -> void:
	out.append({"band": band, "p": p, "s": s, "collide": collide, "ground": ground})


## The schedule's render AABB (chunk-local), padded for the roof frustum.
func _campanile_hero_aabb(boxes: Array[Dictionary], center: Vector3) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for b: Dictionary in boxes:
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		lo = lo.min(p - s * 0.5)
		hi = hi.max(p + s * 0.5)
	return AABB(lo - center - Vector3.ONE * 2.0, (hi - lo) + Vector3.ONE * 4.0)


## The cap's truncated pyramid as one double-sided vertex-color ArrayMesh
## (slate), matching the cap collider's convex: base ±2.5/±2.45, deck rim
## ±1.2, shape-local around the frustum center (the mesh instance rides
## `roof_center - center` — heights span ±1.09 around it).
func _make_campanile_cap_mesh() -> ArrayMesh:
	var y_lo := -1.09 ## The corona-top plane, shape-local.
	var y_hi := 1.09 ## The deck-rim plane, shape-local.
	var b := [ ## The four base corners, clockwise seen from above.
		Vector3(-2.5, y_lo, -2.45), Vector3(2.5, y_lo, -2.45),
		Vector3(2.5, y_lo, 2.45), Vector3(-2.5, y_lo, 2.45),
	]
	var t := [ ## The four deck-rim corners, matching order.
		Vector3(-1.2, y_hi, -1.2), Vector3(1.2, y_hi, -1.2),
		Vector3(1.2, y_hi, 1.2), Vector3(-1.2, y_hi, 1.2),
	]
	var quads := [ ## Each: [a, b, c, d, normal], wound counter-clockwise outside.
		[b[1], b[0], t[0], t[1], Vector3(0.0, 0.0, -1.0)], ## North.
		[b[2], b[1], t[1], t[2], Vector3(1.0, 0.0, 0.0)], ## East.
		[b[3], b[2], t[2], t[3], Vector3(0.0, 0.0, 1.0)], ## South.
		[b[0], b[3], t[3], t[0], Vector3(-1.0, 0.0, 0.0)], ## West.
		[t[0], t[3], t[2], t[1], Vector3.UP], ## The deck rim face.
	]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for q: Array in quads:
		var n: Vector3 = q[4]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			idx.append(verts.size())
			verts.append(q[corner])
			normals.append(n)
			colors.append(CAMPANILE_SLATE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := _make_vertex_color_material()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh


## One white clock dial (the round white dot per face) — a short cylinder
## with its own material (the vertex-color box path cannot round a box).
func _make_campanile_dial_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 0.85
	mesh.height = 0.16
	mesh.radial_segments = 20
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CAMPANILE_CLOCK
	mat.roughness = 0.9
	mesh.material = mat
	return mesh


## --- T-188 the campus row west heroes ---------------------------------------
## The west classical row at hero fidelity, swapping their T-175 slots 1:1 —
## the T-186 campanile law generalized from one hero to four:
##
## - **Beardshear Hall** (`way/33725619`, a HERO placeholder slot): the pale
##   limestone block keeps the bake slot's envelope EXACTLY (41.1 × 14 × 66,
##   the dome stack at its slot offset +12 x and tops 18 / 20), dressed with
##   the columned east portico (the lawn frontage — the E-W lawn axis starts
##   at this face), the heavy cornice and THE GREEN DOME (F-03 — the only
##   green dome in town, the oxidized-copper estimate trio from
##   MODELING-SPECS §1.4). Its slot's block/dome/dome_cap placeholder parts
##   render, collide and ground-file NOTHING anymore; the hero files its own
##   tops, and the dome-top crumb lands byte-identically where the bake's
##   dome_cap-derived spot always sat (20.0 m at the dome center).
## - **Morrill Hall** (`way/158023244`, an authored massing slot): dark red
##   brick under the patterned slate hip (red banding at the eave), the
##   round-arched windows read as dark openings, and the round corner turret
##   with its conical slate roof at the lawn-facing (SE) corner — the corner
##   itself is unpinned by the survey (photos only), chosen for the read.
## - **Farm House** (`way/158023219`, authored massing slot): the tiny
##   1860s farmhouse on its knoll — 2-story brick massing (census 314 m²
##   footprint, the 2-level ladder), white trim, front gable, ridge
##   chimneys, the west-front porch. The ONLY ref is the archival B&W photo
##   (`campus/15`): brick/trim colors carry from LANDMARKS C9's text, the
##   roof wears §1.10's weathered-shingle row (the nearest pinned survey
##   family — the B&W cannot pin a roof hue), flagged honestly.
## - **Marston Hall** (`way/183216666`, authored massing slot — the ticket's
##   "facade hint if cheap"): the quad's east row partner keeps its slot
##   envelope (31.4 × 12 × 64.2) and gains the pale classical east facade —
##   cornice, central pavilion, pilasters, arched entry, steps.
##
## The slot swap keys run in the SAME families the T-186 swap does: the
## Beardshear placeholder parts are skipped by id in the placeholder render,
## collision, ground-record and roof-spot passes; Morrill / Farm House /
## Marston Hall join `_hero_ids` at build time (`CAMPUS_ROW_RUNTIME_HERO_IDS`),
## so the existing hero-massing skips apply to their superseded bbox boxes
## unchanged. Each hero hangs its own shapes on its chunk's layer-1
## `Placeholders` body (the same slot and collision class), files its own
## true ground tops, hosts its own roof crumb at its true top, and retains
## its part record for the gates (headless runs cannot read the instances
## back — the T-185 law). Like every corner dress: pure bake-derived
## geometry, zero RNG of any stream — a rebuild reproduces every transform.

const BEARDSHEAR_HERO_ID := "way/33725619"
const MORRILL_HERO_ID := "way/158023244"
const FARMHOUSE_HERO_ID := "way/158023219"
const MARSTON_HALL_HERO_ID := "way/183216666"

## (T-188) The massing-slot supersessions (see the section doc — Beardshear's
## id already rides the bake manifest's `heroes` list, so only the three
## authored-massing swaps need the runtime merge).
const CAMPUS_ROW_RUNTIME_HERO_IDS: Array[String] = [
	MORRILL_HERO_ID, FARMHOUSE_HERO_ID, MARSTON_HALL_HERO_ID,
]

## (T-188) The pinned palette — MODELING-SPECS §1.4's campus-buildings rows,
## verbatim. The palette gate re-derives these hexes from the survey doc's
## own table (never from these constants) and holds the record colors
## against them; the window band carries no survey hex (the openings read as
## dark in every ref photo) and is held by a darkness law instead, the
## campanile `hand` band's precedent.
const ROW_LIMESTONE := Color(0.784, 0.757, 0.682) ## #C8C1AE limestone, sunlit.
const ROW_LIMESTONE_SHADE := Color(0.635, 0.608, 0.545) ## #A29B8B limestone, shade (base courses, cornices, trims).
const ROW_DOME_MID := Color(0.369, 0.561, 0.408) ## #5E8F68 oxidized copper, mid (F-03 — the dome's own body).
const ROW_DOME_LIGHT := Color(0.561, 0.725, 0.561) ## #8FB98F oxidized copper, light (the drum).
const ROW_DOME_DARK := Color(0.290, 0.439, 0.333) ## #4A7055 oxidized copper, dark (the drum base ring).
const ROW_MORRILL_BRICK := Color(0.659, 0.314, 0.227) ## #A8503A Morrill brick, sunlit.
const ROW_MORRILL_SHADE := Color(0.486, 0.227, 0.169) ## #7C3A2B Morrill brick, shade (the attic frieze).
const ROW_MORRILL_SLATE := Color(0.247, 0.267, 0.298) ## #3F444C Morrill patterned slate.
const ROW_MORRILL_BANDING := Color(0.549, 0.290, 0.235) ## #8C4A3C the slate roof's red banding.
const ROW_FARM_BRICK := Color(0.604, 0.290, 0.204) ## #9A4A34 Farm House brick (LANDMARKS C9 text — B&W-only ref).
const ROW_FARM_TRIM := Color(0.929, 0.918, 0.886) ## #EDEAE2 Farm House white trim (C9 text).
const ROW_FARM_ROOF := Color(0.306, 0.306, 0.322) ## #4E4E52 weathered shingle (§1.10 row — the B&W cannot pin a roof hue).
const ROW_KNOLL := Color(0.373, 0.498, 0.259) ## #5F7F42 the quad lawn green — the knoll's dress.
const ROW_WINDOW := Color(0.16, 0.14, 0.125) ## The dark openings — held by luminance ≤ 0.25, not a hex.

## The band -> color table (the record and the render share this one mapping).
const CAMPUS_ROW_BANDS: Dictionary = {
	"limestone": ROW_LIMESTONE,
	"limestone_shade": ROW_LIMESTONE_SHADE,
	"dome_light": ROW_DOME_LIGHT,
	"dome_mid": ROW_DOME_MID,
	"dome_dark": ROW_DOME_DARK,
	"morrill_brick": ROW_MORRILL_BRICK,
	"morrill_shade": ROW_MORRILL_SHADE,
	"morrill_slate": ROW_MORRILL_SLATE,
	"morrill_banding": ROW_MORRILL_BANDING,
	"farm_brick": ROW_FARM_BRICK,
	"farm_trim": ROW_FARM_TRIM,
	"farm_roof": ROW_FARM_ROOF,
	"knoll": ROW_KNOLL,
	"window": ROW_WINDOW,
}

## (T-188) The pinned heights (m) — the slot-exact law where the bake settled
## one (Beardshear's stack: block 14, dome drum top 18, dome top 20), the
## census ladder where it did not (Morrill 3 levels ≈ 11 walls + 4-hip read —
## the bake's 30.0 `height_m` was an OSM default the census §3 records as the
## bogus class and the baker's own hero law overrides; Farm House 2 levels
## ≈ 8 walls on its knoll; Marston Hall keeps the pack's tagged 12.0).
const BEARDSHEAR_DOME_OFFSET_X := 12.0 ## The slot's own dome offset (the bake's `dome` part).
const BEARDSHEAR_DOME_TOP := 20.0 ## The slot's settled dome top (the crumb height, byte-continuous).
const MORRILL_WALL_TOP := 9.6
const MORRILL_ATTIC_TOP := 10.6
const MORRILL_RIDGE := 15.0
const MORRILL_TURRET_DRUM_TOP := 13.0
const MORRILL_TURRET_CONE_TOP := 16.8
const FARMHOUSE_KNOLL_TOP := 1.4
const FARMHOUSE_RIDGE := 12.9
const MARSTON_HALL_TOP := 12.0 ## The pack's own tagged height (the slot stays exact).


func _row_band_color(band: String) -> Color:
	return CAMPUS_ROW_BANDS.get(band, ROW_LIMESTONE)


## (T-188) TRUE when a baked placeholder entry belongs to a hero that
## supersedes its slot at runtime — the campanile (T-186) and Beardshear
## (T-188, this ticket). The placeholder-family passes (render, collision,
## ground record, roof spots) skip these ids so a hero never renders twice.
func _row_superseded_placeholder(id: String) -> bool:
	return id == CAMPANILE_HERO_ID or id == BEARDSHEAR_HERO_ID


## Builds the row heroes found in this chunk (Beardshear + Morrill + Marston
## Hall live in chunk (0, -2); Farm House in chunk (1, -2)). No-op elsewhere.
func _build_campus_row_heroes(chunk_root: Node3D, chunk: Dictionary,
		center: Vector3, chunk_body: StaticBody3D) -> void:
	var beardshear := Vector2.ZERO
	var morrill := Vector2.ZERO
	var farm := Vector2.ZERO
	var marston := Vector2.ZERO
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) == BEARDSHEAR_HERO_ID \
				and str(ph.get("part", "")) == "block":
			beardshear = Vector2(float(ph["p"][0]), float(ph["p"][2]))
	for m: Dictionary in chunk.get("massing", []):
		var mid := str(m.get("id", ""))
		if mid == MORRILL_HERO_ID:
			morrill = Vector2(float(m["p"][0]), float(m["p"][2]))
		elif mid == FARMHOUSE_HERO_ID:
			farm = Vector2(float(m["p"][0]), float(m["p"][2]))
		elif mid == MARSTON_HALL_HERO_ID:
			marston = Vector2(float(m["p"][0]), float(m["p"][2]))
	if beardshear != Vector2.ZERO:
		var bx := beardshear.x + BEARDSHEAR_DOME_OFFSET_X
		_row_commit(chunk_root, center, "Beardshear", BEARDSHEAR_HERO_ID,
				_beardshear_hero_boxes(beardshear),
				Vector3(bx, BEARDSHEAR_DOME_TOP, beardshear.y), chunk_body,
				_beardshear_hero_extras(beardshear))
	if morrill != Vector2.ZERO:
		_row_commit(chunk_root, center, "Morrill", MORRILL_HERO_ID,
				_morrill_hero_boxes(morrill),
				Vector3(morrill.x, MORRILL_RIDGE, morrill.y), chunk_body,
				_morrill_hero_extras(morrill),
				[{"p": Vector3(morrill.x, 13.05, morrill.y),
					"s": Vector3(2.0, 3.9, 28.0)}] as Array[Dictionary])
	if farm != Vector2.ZERO:
		_row_commit(chunk_root, center, "FarmHouse", FARMHOUSE_HERO_ID,
				_farmhouse_hero_boxes(farm),
				Vector3(farm.x, FARMHOUSE_RIDGE, farm.y - 3.75), chunk_body,
				_farmhouse_hero_extras(farm),
				[{"p": Vector3(farm.x, 11.15, farm.y - 3.75),
					"s": Vector3(19.6, 3.5, 0.9)}] as Array[Dictionary])
	if marston != Vector2.ZERO:
		_row_commit(chunk_root, center, "MarstonHall", MARSTON_HALL_HERO_ID,
				_marston_hero_boxes(marston),
				Vector3(marston.x, MARSTON_HALL_TOP, marston.y), chunk_body,
				[] as Array[Dictionary])


## One hero's commit — the T-186 pipeline shared by the four: render (the box
## MultiMesh + every named mesh extra), collision (the hero's own shapes ride
## the chunk's placeholder body — same slot, same layer-1 `world` class),
## ground-record tops, the roof-crumb host (`_hero_roof_tops`, consumed by
## `_append_roof_spots`), and the retained part record. Each extra is
## `{name, mesh, pos, convex, band, size}`: the mesh mounts at `pos`
## (chunk-local); a non-empty `convex` becomes one CollisionShape3D at the
## same spot; `band`/`size` file the record.
func _row_commit(chunk_root: Node3D, center: Vector3, hero_name: String,
		hero_id: String, boxes: Array[Dictionary], crumb: Vector3,
		chunk_body: StaticBody3D, extras: Array[Dictionary],
		record_only: Array[Dictionary] = []) -> void:
	var root := Node3D.new()
	root.name = "HeroRow%s" % hero_name
	chunk_root.add_child(root)
	var mm := _new_multimesh(boxes.size())
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(s), p - center))
		mm.set_instance_color(i, _row_band_color(str(b["band"])))
	mm.custom_aabb = _campanile_hero_aabb(boxes, center)
	var mm_node := MultiMeshInstance3D.new()
	mm_node.name = "Boxes"
	mm_node.multimesh = mm
	root.add_child(mm_node)
	for e: Dictionary in extras:
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = str(e["name"])
		mesh_node.mesh = e["mesh"]
		mesh_node.position = (e["pos"] as Vector3) - center
		root.add_child(mesh_node)
	## Collision: the chunk's placeholder body (created when the chunk had no
	## other entries — the campanile chunk's case, kept for the row).
	var body := chunk_body
	if body == null:
		body = StaticBody3D.new()
		body.name = "Placeholders"
		body.collision_layer = 1 ## world
		body.collision_mask = 0
		chunk_root.add_child(body)
	for b2: Dictionary in boxes:
		if not b2["collide"]:
			continue
		var bp: Vector3 = b2["p"]
		var bs: Vector3 = b2["s"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bs
		shape.shape = box
		shape.position = bp - center
		body.add_child(shape)
	for e2: Dictionary in extras:
		var pts: PackedVector3Array = e2["convex"]
		if pts.is_empty():
			continue
		var extra_shape := CollisionShape3D.new()
		var convex := ConvexPolygonShape3D.new()
		convex.points = pts
		extra_shape.shape = convex
		extra_shape.position = (e2["pos"] as Vector3) - center
		body.add_child(extra_shape)
	## Ground record: the hero files its own true tops where the superseded
	## slot used to (the walkability query answers the hero now). The
	## `record_only` entries file WITHOUT rendering or colliding — the two
	## roofs' ridge masses (a big ground box under a sloped loft mesh would
	## poke through the slope; a hidden ridge strip files the ridge-top
	## answer cleanly).
	var tiles: Dictionary = {}
	var bytes := 0
	for b3: Dictionary in boxes:
		if not b3["ground"]:
			continue
		var gp: Vector3 = b3["p"]
		var gs: Vector3 = b3["s"]
		bytes += _file_ground_box(tiles, [gp.x, gp.y, gp.z], [gs.x, gs.y, gs.z])
	for r: Dictionary in record_only:
		var rp: Vector3 = r["p"]
		var rs: Vector3 = r["s"]
		bytes += _file_ground_box(tiles, [rp.x, rp.y, rp.z], [rs.x, rs.y, rs.z])
	for key: Vector2i in tiles:
		var record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = record.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		record["ground"] = ground
		_chunks[key] = record
	_buffer_bytes += bytes
	## The roof-crumb host: one ROOF spot at the hero's true top (the T-176
	## convention — the superseded bake entries stopped filing in
	## `_collect_roof_spots`).
	_hero_roof_tops[hero_id] = crumb
	## Retain the part record (world-local bands, positions, sizes, colors).
	for b4: Dictionary in boxes:
		campus_row_hero_parts.append({
			"hero": hero_name, "band": str(b4["band"]), "p": b4["p"],
			"s": b4["s"], "color": _row_band_color(str(b4["band"])),
			"collide": b4["collide"],
		})
	for e3: Dictionary in extras:
		campus_row_hero_parts.append({
			"hero": hero_name, "band": str(e3["band"]), "p": e3["pos"],
			"s": e3["size"], "color": _row_band_color(str(e3["band"])),
			"collide": false,
		})


## One box into a row-hero schedule (typed push keeps the Array[Dictionary]
## contract — the campanile's own helper, row-suffixed).
func _add_row_box(out: Array[Dictionary], band: String, p: Vector3, s: Vector3,
		collide: bool, ground: bool) -> void:
	out.append({"band": band, "p": p, "s": s, "collide": collide, "ground": ground})


## --- Beardshear Hall ---------------------------------------------------------
## The slot envelope EXACT (block 41.1 × 14 × 66 at the bake part's center,
## dome drum 9 × 4 × 9 at +12 x topping 18, dome topping 20), dressed: the
## east portico (columns + architrave + steps on the lawn frontage), the
## heavy cornice, the drum's copper banding. The portico pavilion protrudes
## 2.2 m past the east face; its face plane is `ex + 2.2`.
func _beardshear_hero_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ex := c.x + 20.55 ## The east face — the lawn frontage.
	var dx := c.x + BEARDSHEAR_DOME_OFFSET_X
	_add_row_box(out, "limestone", Vector3(c.x, 7.0, c.y),
			Vector3(41.1, 14.0, 66.0), true, true)
	_add_row_box(out, "limestone_shade", Vector3(c.x, 0.4, c.y),
			Vector3(41.1, 0.8, 66.0), false, false)
	_add_row_box(out, "limestone_shade", Vector3(c.x, 13.5, c.y),
			Vector3(41.5, 1.0, 66.4), true, false) ## The heavy cornice ring.
	## The portico pavilion + its own cornice.
	_add_row_box(out, "limestone", Vector3(ex + 1.1, 7.0, c.y),
			Vector3(2.2, 14.0, 12.0), true, true)
	_add_row_box(out, "limestone_shade", Vector3(ex + 1.2, 13.5, c.y),
			Vector3(2.6, 1.0, 12.8), false, false)
	## Four portico columns carrying the architrave slab.
	for off: float in [-4.6, -1.7, 1.7, 4.6]:
		_add_row_box(out, "limestone", Vector3(ex + 2.8, 4.5, c.y + off),
				Vector3(1.0, 9.0, 1.0), true, false)
	_add_row_box(out, "limestone_shade", Vector3(ex + 2.8, 9.6, c.y),
			Vector3(1.6, 1.2, 12.0), true, false) ## The architrave roof slab.
	_add_row_box(out, "limestone_shade", Vector3(ex + 2.75, 10.9, c.y),
			Vector3(1.8, 1.4, 12.2), false, false) ## The entablature band.
	## The entrance steps, plate to the portico floor.
	_add_row_box(out, "limestone_shade", Vector3(ex + 3.6, 0.175, c.y),
			Vector3(5.2, 0.35, 15.0), true, true)
	_add_row_box(out, "limestone_shade", Vector3(ex + 3.0, 0.525, c.y),
			Vector3(3.6, 0.35, 13.2), true, true)
	## The dark door + the tall windows, proud of the pavilion face (a face-
	## flush dark box would z-fight; proud reads as the opening).
	_add_row_box(out, "window", Vector3(ex + 2.26, 2.4, c.y),
			Vector3(0.12, 3.4, 2.2), false, false)
	for woff: float in [-3.4, 3.4]:
		for wy: float in [3.4, 7.0]:
			_add_row_box(out, "window", Vector3(ex + 2.26, wy, c.y + woff),
					Vector3(0.12, 2.4, 1.4), false, false)
	## The dome stack at the slot's own offset: drum (slot-exact 9 × 4 × 9,
	## top 18 — its square top corners read as the plinth under the round
	## cap), the dark copper base ring, and the cap's ground box (sized to
	## stay fully under the tapered cap mesh; the mesh + convex ride the
	## extras and the box files the 20.0 walkability top).
	_add_row_box(out, "dome_light", Vector3(dx, 16.0, c.y),
			Vector3(9.0, 4.0, 9.0), true, true)
	_add_row_box(out, "dome_dark", Vector3(dx, 14.25, c.y),
			Vector3(9.3, 0.5, 9.3), false, false)
	_add_row_box(out, "dome_mid", Vector3(dx, 19.0, c.y),
			Vector3(3.0, 2.0, 3.0), false, true)
	return out


## Beardshear's mesh extras: the oxidized-copper dome cap — one tapered
## CylinderMesh (the round read the box path cannot give), 18→20 so the top
## stays the slot's settled 20.0. The convex is the 8-segment frustum under
## it (the walkable dome mass).
func _beardshear_hero_extras(c: Vector2) -> Array[Dictionary]:
	var dx := c.x + BEARDSHEAR_DOME_OFFSET_X
	var pos := Vector3(dx, 19.0, c.y)
	var out: Array[Dictionary] = [{
		"name": "DomeCap", "mesh": _row_taper_mesh(2.2, 4.5, 2.0, ROW_DOME_MID),
		"pos": pos, "convex": _row_cylinder_convex(4.5, 2.2, 2.0, 8),
		"band": "dome_mid", "size": Vector3(9.0, 2.0, 9.0),
	}]
	return out


## --- Morrill Hall ------------------------------------------------------------
## Dark red brick walls (0→9.6, the census 3-level read), the shaded attic
## frieze, the red-banded eave, the patterned slate hip (loft mesh 11.1→15.0
## with its ridge line along the long z axis) and the round corner turret at
## the lawn-facing corner — a full-height brick drum (13.0) carrying the
## limestone band and the conical slate roof to 16.8. Tall windows and the
## entry read as dark openings with pale surrounds on the east (lawn) face.
func _morrill_hero_boxes(m: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hx := 13.85
	var hz := 20.15
	var tx := m.x + hx - 1.2 ## The turret center (SE corner, inset 1.2).
	var tz := m.y + hz - 1.2
	_add_row_box(out, "limestone_shade", Vector3(m.x, 0.6, m.y),
			Vector3(27.7, 1.2, 40.3), false, false) ## The limestone base course.
	_add_row_box(out, "morrill_brick", Vector3(m.x, 4.8, m.y),
			Vector3(27.7, 9.6, 40.3), true, true)
	_add_row_box(out, "morrill_shade", Vector3(m.x, 10.1, m.y),
			Vector3(27.7, 1.0, 40.3), true, true) ## The attic frieze.
	_add_row_box(out, "morrill_banding", Vector3(m.x, 10.85, m.y),
			Vector3(28.3, 0.5, 40.9), false, false) ## The red eave banding.
	## (The hip roof's ridge-top ground answer files RECORD-ONLY — see the
	## dispatcher: a big ground box under the sloped loft mesh would poke
	## through the slope.)
	## The banding dormer hint on the south slope (the winter photo's banded
	## gable read).
	_add_row_box(out, "morrill_banding", Vector3(m.x, 12.0, m.y + 18.8),
			Vector3(6.0, 2.2, 1.4), false, false)
	## The entry + tall windows on the east (lawn) face — surround proud of
	## the wall, door proud of the surround (face-coincident boxes z-fight).
	_add_row_box(out, "limestone_shade", Vector3(m.x + hx + 0.12, 2.1, m.y),
			Vector3(0.16, 4.2, 2.8), false, false)
	_add_row_box(out, "window", Vector3(m.x + hx + 0.15, 1.9, m.y),
			Vector3(0.1, 3.0, 2.0), false, false)
	for woff: float in [-10.0, 10.0]:
		for wy: float in [3.4, 6.4]:
			_add_row_box(out, "window", Vector3(m.x + hx + 0.06, wy, m.y + woff),
					Vector3(0.1, 2.2, 1.4), false, false)
	_add_row_box(out, "window", Vector3(m.x + hx + 0.06, 6.4, m.y),
			Vector3(0.1, 2.2, 1.4), false, false)
	## The turret drum's ground box (sized to stay inside the round convex;
	## the drum cylinder + cone ride the extras) — files the 13.0 top.
	_add_row_box(out, "morrill_brick", Vector3(tx, 6.5, tz),
			Vector3(3.6, 13.0, 3.6), false, true)
	return out


func _morrill_hero_extras(m: Vector2) -> Array[Dictionary]:
	var hx := 13.85
	var hz := 20.15
	var tx := m.x + hx - 1.2
	var tz := m.y + hz - 1.2
	var out: Array[Dictionary] = [{
		"name": "HipRoof",
		"mesh": _row_loft_mesh(Vector2(28.3, 40.9), Vector2(2.0, 28.0), 3.9,
				ROW_MORRILL_SLATE, ROW_MORRILL_SLATE),
		"pos": Vector3(m.x, 13.05, m.y),
		"convex": _row_frustum_convex(Vector2(28.3, 40.9), Vector2(2.0, 28.0), 3.9),
		"band": "morrill_slate", "size": Vector3(28.3, 3.9, 40.9),
	}, {
		"name": "TurretDrum", "mesh": _row_taper_mesh(2.6, 2.6, 13.0, ROW_MORRILL_BRICK),
		"pos": Vector3(tx, 6.5, tz),
		"convex": _row_cylinder_convex(2.6, 2.6, 13.0, 8),
		"band": "morrill_brick", "size": Vector3(5.2, 13.0, 5.2),
	}, {
		"name": "TurretBand", "mesh": _row_taper_mesh(2.8, 2.8, 0.4, ROW_LIMESTONE_SHADE),
		"pos": Vector3(tx, 13.2, tz), "convex": PackedVector3Array(),
		"band": "limestone_shade", "size": Vector3(5.6, 0.4, 5.6),
	}, {
		"name": "TurretCone", "mesh": _row_taper_mesh(0.15, 3.2, 3.4, ROW_MORRILL_SLATE),
		"pos": Vector3(tx, 15.1, tz),
		"convex": _row_cylinder_convex(3.2, 0.3, 3.4, 8),
		"band": "morrill_slate", "size": Vector3(6.4, 3.4, 6.4),
	}]
	return out


## --- Farm House --------------------------------------------------------------
## The tiny 1860s farmhouse on its knoll (the ticket's honest-flag hero: the
## only ref is the archival B&W, `campus/15` — colors carry from LANDMARKS
## C9's text; the roof hue borrows §1.10's weathered-shingle row). The main
## 2-story gable block (walls 8.0 = the 2-level census ladder) + the lower
## rear wing complete the slot's 18.8 × 21.5 envelope; the white-trimmed
## porch faces WEST (the campus read); two brick chimneys ride the ridge.
func _farmhouse_hero_boxes(f: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var zx := f.y - 3.75 ## The main block's center z (the north portion).
	_add_row_box(out, "knoll", Vector3(f.x, 0.7, f.y),
			Vector3(26.0, 1.4, 29.0), true, true) ## The knoll.
	_add_row_box(out, "farm_brick", Vector3(f.x, 5.4, zx),
			Vector3(18.8, 8.0, 14.0), true, true) ## The gable block.
	_add_row_box(out, "farm_brick", Vector3(f.x + 2.0, 4.15, f.y + 7.0),
			Vector3(13.0, 5.5, 7.5), true, true) ## The rear wing.
	## (The gable roof's ridge-top ground answer files RECORD-ONLY — see the
	## dispatcher: a big ground box under the sloped loft mesh would poke
	## through the slope.)
	## The ridge chimneys (the B&W photo's pair).
	for coff: float in [-3.2, 3.2]:
		_add_row_box(out, "farm_brick", Vector3(f.x + coff, 13.6, zx),
				Vector3(0.9, 1.4, 0.9), true, false)
	## The porch (deck + roof walkable; posts visual), facing west.
	_add_row_box(out, "farm_trim", Vector3(f.x - 11.2, 1.55, zx),
			Vector3(3.6, 0.3, 11.0), true, true)
	_add_row_box(out, "farm_trim", Vector3(f.x - 11.3, 4.175, zx),
			Vector3(4.0, 0.35, 11.4), true, true)
	for poff: float in [-4.5, -1.5, 1.5, 4.5]:
		_add_row_box(out, "farm_trim", Vector3(f.x - 12.9, 2.7, zx + poff),
				Vector3(0.2, 2.6, 0.2), false, false)
	## The door, its trim surround, the white-linteled windows and the attic
	## gable window — all on the west front, every face proud of the plane
	## behind it (face-coincident boxes z-fight).
	_add_row_box(out, "farm_trim", Vector3(f.x - 9.52, 2.8, zx),
			Vector3(0.1, 2.9, 1.7), false, false)
	_add_row_box(out, "window", Vector3(f.x - 9.56, 2.7, zx),
			Vector3(0.14, 2.6, 1.3), false, false)
	for woff: float in [-3.6, 3.6]:
		for wy: float in [3.6, 7.0]:
			_add_row_box(out, "window", Vector3(f.x - 9.49, wy, zx + woff),
					Vector3(0.12, 1.6, 1.2), false, false)
			_add_row_box(out, "farm_trim", Vector3(f.x - 9.5, wy + 1.0, zx + woff),
					Vector3(0.14, 0.28, 1.5), false, false)
	_add_row_box(out, "window", Vector3(f.x - 9.86, 10.7, zx),
			Vector3(0.12, 0.9, 0.9), false, false)
	return out


func _farmhouse_hero_extras(f: Vector2) -> Array[Dictionary]:
	var zx := f.y - 3.75
	var out: Array[Dictionary] = [{
		"name": "GableRoof",
		"mesh": _row_loft_mesh(Vector2(19.6, 15.2), Vector2(19.6, 0.9), 3.5,
				ROW_FARM_ROOF, ROW_FARM_BRICK),
		"pos": Vector3(f.x, 11.15, zx),
		"convex": _row_frustum_convex(Vector2(19.6, 15.2), Vector2(19.6, 0.9), 3.5),
		"band": "farm_roof", "size": Vector3(19.6, 3.5, 15.2),
	}]
	return out


## --- Marston Hall (the facade hint) ------------------------------------------
## The slot envelope EXACT (31.4 × 12 × 64.2, the pack's tagged 12.0 kept),
## dressed with the pale classical east facade: cornice ring, the central
## pavilion with its four pilasters, the arched entry in its surround, and
## the entrance steps onto the marston_spoke walk.
func _marston_hero_boxes(s: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ex := s.x + 15.7 ## The east face — the lawn frontage.
	_add_row_box(out, "limestone", Vector3(s.x, 6.0, s.y),
			Vector3(31.4, 12.0, 64.2), true, true)
	_add_row_box(out, "limestone_shade", Vector3(s.x, 0.4, s.y),
			Vector3(31.4, 0.8, 64.2), false, false)
	_add_row_box(out, "limestone_shade", Vector3(s.x, 11.55, s.y),
			Vector3(31.8, 0.9, 64.6), true, false) ## The cornice ring.
	_add_row_box(out, "limestone", Vector3(ex + 1.0, 6.0, s.y),
			Vector3(2.0, 12.0, 14.0), true, true) ## The central pavilion.
	_add_row_box(out, "limestone_shade", Vector3(ex + 1.1, 11.55, s.y),
			Vector3(2.4, 0.9, 14.6), false, false)
	for poff: float in [-5.2, -2.4, 2.4, 5.2]:
		_add_row_box(out, "limestone_shade", Vector3(ex + 2.05, 5.0, s.y + poff),
				Vector3(0.35, 10.0, 0.9), false, false) ## The pilasters.
	_add_row_box(out, "limestone_shade", Vector3(ex + 2.15, 2.9, s.y),
			Vector3(0.2, 5.8, 4.2), false, false) ## The entry surround.
	_add_row_box(out, "window", Vector3(ex + 2.22, 2.5, s.y),
			Vector3(0.12, 5.0, 3.2), false, false) ## The arched entry.
	_add_row_box(out, "limestone_shade", Vector3(ex + 3.6, 0.175, s.y),
			Vector3(5.2, 0.35, 12.0), true, true)
	_add_row_box(out, "limestone_shade", Vector3(ex + 3.0, 0.525, s.y),
			Vector3(3.6, 0.35, 10.4), true, true)
	return out


## One tapered/straight cylinder mesh with its own albedo material — the
## dial-material path (albedo colors render sRGB-correct; the mesh-carried
## vertex-color path would wash the hex — the T-187 round-1 finding).
func _row_taper_mesh(top_radius: float, bottom_radius: float, height: float,
		color: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	return mesh


## One eave→ridge loft as a double-sided material ArrayMesh: the base
## rectangle (at the eave plane, shape-local y −h/2) lerped to the top
## rectangle (the ridge plane, +h/2). An axis whose extent does NOT shrink
## makes vertical end walls — the gable read (the Farm House ends wear the
## brick, the Morrill hip shrinks on both axes so every face is slate). Two
## surfaces: 0 = slopes + ridge strip (the roof color), 1 = vertical ends
## (empty when the roof is a full hip). Surface materials, not vertex
## colors — the same color-space law as the tapers.
func _row_loft_mesh(base_size: Vector2, top_size: Vector2, height: float,
		slope_color: Color, end_color: Color) -> ArrayMesh:
	var hh := height * 0.5
	var b := [
		Vector3(-base_size.x * 0.5, -hh, -base_size.y * 0.5),
		Vector3(base_size.x * 0.5, -hh, -base_size.y * 0.5),
		Vector3(base_size.x * 0.5, -hh, base_size.y * 0.5),
		Vector3(-base_size.x * 0.5, -hh, base_size.y * 0.5),
	]
	var t := [
		Vector3(-top_size.x * 0.5, hh, -top_size.y * 0.5),
		Vector3(top_size.x * 0.5, hh, -top_size.y * 0.5),
		Vector3(top_size.x * 0.5, hh, top_size.y * 0.5),
		Vector3(-top_size.x * 0.5, hh, top_size.y * 0.5),
	]
	var end_x := absf(base_size.x - top_size.x) < 0.01 ## E/W walls vertical.
	var end_z := absf(base_size.y - top_size.y) < 0.01 ## N/S walls vertical.
	## Each: [a, b, c, d, normal, is_end], wound outside-out like the
	## campanile cap's quads; cull disabled so winding never hides a face.
	var quads := [
		[b[1], b[0], t[0], t[1], Vector3(0.0, 0.0, -1.0), end_z],
		[b[2], b[1], t[1], t[2], Vector3(1.0, 0.0, 0.0), end_x],
		[b[3], b[2], t[2], t[3], Vector3(0.0, 0.0, 1.0), end_z],
		[b[0], b[3], t[3], t[0], Vector3(-1.0, 0.0, 0.0), end_x],
		[t[0], t[3], t[2], t[1], Vector3.UP, false],
	]
	var slope_verts := PackedVector3Array()
	var slope_normals := PackedVector3Array()
	var slope_idx := PackedInt32Array()
	var end_verts := PackedVector3Array()
	var end_normals := PackedVector3Array()
	var end_idx := PackedInt32Array()
	for q: Array in quads:
		var is_end: bool = q[5]
		var verts := end_verts if is_end else slope_verts
		var normals := end_normals if is_end else slope_normals
		var idx := end_idx if is_end else slope_idx
		var n: Vector3 = q[4]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			idx.append(verts.size())
			verts.append(q[corner])
			normals.append(n)
	var mesh := ArrayMesh.new()
	var arrays_slope := []
	arrays_slope.resize(Mesh.ARRAY_MAX)
	arrays_slope[Mesh.ARRAY_VERTEX] = slope_verts
	arrays_slope[Mesh.ARRAY_NORMAL] = slope_normals
	arrays_slope[Mesh.ARRAY_INDEX] = slope_idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_slope)
	mesh.surface_set_material(0, _row_flat_material(slope_color))
	if not end_verts.is_empty():
		var arrays_end := []
		arrays_end.resize(Mesh.ARRAY_MAX)
		arrays_end[Mesh.ARRAY_VERTEX] = end_verts
		arrays_end[Mesh.ARRAY_NORMAL] = end_normals
		arrays_end[Mesh.ARRAY_INDEX] = end_idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_end)
		mesh.surface_set_material(1, _row_flat_material(end_color))
	return mesh


func _row_flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED ## The lofts read from inside the gable too.
	return mat


## One square frustum's 8 convex points, shape-local (±h/2) — the loft
## roofs' and the dome cap's solid mass.
func _row_frustum_convex(base_size: Vector2, top_size: Vector2,
		height: float) -> PackedVector3Array:
	var hh := height * 0.5
	return PackedVector3Array([
		Vector3(-base_size.x * 0.5, -hh, -base_size.y * 0.5),
		Vector3(base_size.x * 0.5, -hh, -base_size.y * 0.5),
		Vector3(base_size.x * 0.5, -hh, base_size.y * 0.5),
		Vector3(-base_size.x * 0.5, -hh, base_size.y * 0.5),
		Vector3(-top_size.x * 0.5, hh, -top_size.y * 0.5),
		Vector3(top_size.x * 0.5, hh, -top_size.y * 0.5),
		Vector3(top_size.x * 0.5, hh, top_size.y * 0.5),
		Vector3(-top_size.x * 0.5, hh, top_size.y * 0.5),
	])


## One tapered cylinder's convex ring points, shape-local (±h/2) — the dome
## cap, the turret drum and the cone (8 segments keeps the shape light while
## reading round to a ray).
func _row_cylinder_convex(radius_bottom: float, radius_top: float, height: float,
		segments: int) -> PackedVector3Array:
	var hh := height * 0.5
	var pts := PackedVector3Array()
	for k in segments:
		var a := TAU * float(k) / float(segments)
		pts.append(Vector3(cos(a) * radius_bottom, -hh, sin(a) * radius_bottom))
		pts.append(Vector3(cos(a) * radius_top, hh, sin(a) * radius_top))
	return pts
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

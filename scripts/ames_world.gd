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
## (T-189) The MU + Parks hero part record, retained on the same law: every
## box and mesh-bounding extra the two builds emitted —
## `{hero, band, p, s, color, collide}` in world-local (pack) coordinates,
## `hero` one of `memorial_union` / `parks_library`. The tower crown, the
## zodiac disc and its ring file their band and bounding `s` at their mesh
## centers so the dims and palette arms walk one record; the LIVE material
## arms re-prove the meshes themselves.
var mu_parks_hero_parts: Array[Dictionary] = []
## (T-190) The Marston Water Tower hero's part record, retained on the same
## law: every rotated trestle box and mesh-bounding extra the build emitted —
## `{hero, band, p, s, color, collide, mesh}` in world-local (pack)
## coordinates, `p`/`s` the part's axis-aligned bounding box (the splayed legs
## and the lattice turns file their boxes' world AABBs so the dims arm walks
## one record); the tank cylinder, the cornice ring, the cone and the
## medallion file their band and bounding `s` at their mesh centers so the
## dims and palette arms walk one record; the LIVE material arms re-prove the
## meshes themselves.
var marston_hero_parts: Array[Dictionary] = []
## (T-191) The Jack Trice Stadium hero's part record, retained on the same
## headless-visibility law: every box the build emitted —
## `{hero, band, p, s, color, collide, mesh}` in world-local (pack)
## coordinates. The bowl ring bands carry their per-band palette (the
## cardinal seat field, the gold section accents, the concrete north wall)
## so the dims arm can union the ring by band prefix while the palette arm
## walks the exact hexes.
var stadium_hero_parts: Array[Dictionary] = []
## (T-191) The Hilton Coliseum hero's part record, same shape — the drum
## segments (concrete + streak panels), the arc roof slab, the portico
## canopy/columns and the seal medallion (`mesh` marks the named extras).
var hilton_hero_parts: Array[Dictionary] = []
## (T-191) The tailgate-lot dress records: the paved flats' ear-clip tri
## count over the pack's Iowa State Center lot polygons and the white
## stall-marking transforms (world-local), retained on the headless law.
var lot_flat_tris: int = 0
var lot_marking_xfs: Array[Transform3D] = []
## (T-192) The Durham Bandshell hero's part record, the T-191 law carried
## downtown: every box the build emitted —
## `{hero, band, p, s, color, collide, mesh}` in world-local (pack)
## coordinates, the arch rings' chords filing their boxes' world AABBs (the
## rotated-chord law) so the dims arm unions the arch by band.
var bandshell_hero_parts: Array[Dictionary] = []
## (T-192) The civic pair's part record, same shape — the City Hall block
## (`relation/2560369`) and the Municipal Building (`way/237834146`) hero
## boxes with their stone cornice bands and cartouche-entry hints.
var civic_hero_parts: Array[Dictionary] = []
## (T-192) The Main Street fabric's part record, same shape — the retail
## row's cornice hints, the maroon street furniture (lamp posts, arms,
## shades), the blue banner slabs and the neon blade sign seeds.
var fabric_parts: Array[Dictionary] = []
## (T-193) The civic water tanks' part record, the T-190 law carried to the
## city's pair: every box and named mesh the build emitted —
## `{hero, band, p, s, color, collide, mesh}` in world-local (pack)
## coordinates, `hero` one of `civic_tank_north` / `civic_tank_east`. The
## diamond rides the rotated-box path (its record entry files the box's
## world AABB, the T-192 arch-chord law); the round families file their
## bounding sizes.
var civic_tank_hero_parts: Array[Dictionary] = []
## (T-195) The SE grain-elevator cluster's part record, the T-193 law carried
## to the agricultural skyline: every box and named mesh the build emitted —
## `{band, p, s, color, collide, mesh}` in world-local (pack) coordinates.
## The silo bank, the headhouse and the annex bins ride the round named-mesh
## families (their record entries file the bounding sizes); the headhouse cap,
## the silo cap rings are mesh entries too; the leg tower rides the box path.
var elevator_hero_parts: Array[Dictionary] = []

## (T-204) The Reiman Gardens conservatory hero's retained part record — the
## same law as every runtime hero above: render/collision/ground all read
## from the box schedule, the gates walk the record (headless runs cannot
## read MultiMesh instances back). Named extras (the Hughes glasshouse
## volume) append their own records with `mesh: true`.
var gardens_hero_parts: Array[Dictionary] = []

## (T-204) The butterfly accent props — the world-staged records ({node,
## home, phase}), count pinned ≤ 12 (dressing, not a system).
var butterflies: Array[Dictionary] = []

## (T-198) The Tier-1 venue signs — one record per placed sign (id, venue text,
## form, the pack-frame mount transform, the live SignText node; the Superdog
## cart's record carries its cart_parts count). The staged entry (The Cafe)
## builds nothing and rides only in `AmesVenueSigns.SIGNS`. World-local (= the
## pack frame), retained for the gate like the T-180/T-181 queues.
var venue_signs: Array[Dictionary] = []

## (T-199) The tiers 2–3 venue signs — one record per placed sign, the same
## shape as the T-198 array, under their own `VenueSignsTiers` root (the
## out-of-core venues ride the apron as free-standing forms). World-local
## (= the pack frame), retained for the gate.
var venue_signs_t23: Array[Dictionary] = []

## (T-199) The mourned ghost plaques — one record per memorial plaque under
## the `GhostPlaques` root: the §6 closed venues whose rooms the committed
## bake pins, at ground-floor memorial mounts.
var ghost_plaques: Array[Dictionary] = []

## (T-200) The street-name blades — one record per MUTCD green blade under the
## `StreetBlades` root: one per SPINE street name at each T-180 pinned corner
## that touches the spine set (the module derives every mount off the traffic
## graph, mast-arm stacked at signal corners, post-mounted on the approach's
## right at the all-way corners). World-local (= the pack frame), retained for
## the gate like the venue-sign arrays.
var street_blades: Array[Dictionary] = []

## (T-201) The campus + civic name plaques — one record per nominative
## building-name plaque under the `CampusPlaques` root: the pinned building
## list's names in plain type (name + survey year only, no marks — the legal
## line), hung on the R3 heroes' own faces (the Marston tower as the one
## free-standing base marker). The staged Reiman Gardens spec (out of core,
## the T-204 dependency) builds nothing and rides only in
## `AmesCampusPlaques.PLAQUES`. World-local (= the pack frame), retained for
## the gate like the other sign arrays.
var campus_plaques: Array[Dictionary] = []

## (T-192) The frontage-row slots collected while the chunks parse (the
## authored downtown massing in the Main/5th frontage bands), consumed by
## the step-3 fabric build — the cornice hints ride the bake's own slot
## dims, so the walk happens where the JSON is in hand.
var _fabric_row_slots: Array[Dictionary] = []

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
	mu_parks_hero_parts = [] ## (T-189) The MU + Parks hero record rebuilds with it.
	marston_hero_parts = [] ## (T-190) The Marston tower record rebuilds with it.
	stadium_hero_parts = [] ## (T-191) The stadium-complex record rebuilds with the world.
	hilton_hero_parts = [] ## (T-191) The Hilton drum record rebuilds with it.
	lot_flat_tris = 0 ## (T-191) The tailgate-lot dress records rebuild with it.
	lot_marking_xfs = []
	bandshell_hero_parts = [] ## (T-192) The downtown records rebuild with the world.
	civic_hero_parts = []
	civic_tank_hero_parts = [] ## (T-193) The civic tank record rebuilds with the world.
	depot_hero_parts = [] ## (T-194) The rail-corridor records rebuild with the world.
	elevator_hero_parts = [] ## (T-195) The elevator-cluster record rebuilds with the world.
	gardens_hero_parts = [] ## (T-204) The gardens-conservatory record rebuilds with the world.
	butterflies = [] ## (T-204) The butterfly accent records rebuild with the world.
	crossbuck_pins = []
	wigwag_parts = []
	_crossbuck_post_xfs = []
	_crossbuck_arm_xfs = []
	_fence_post_xfs = []
	_fence_wire_xfs = []
	rail_route = PackedVector3Array()
	train = null
	fabric_parts = []
	_fabric_row_slots = []
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
	## (T-192) The downtown civic pair swaps AUTHORED massing slots (the City
	## Hall block + the Municipal Building) the same way — their ids join the
	## hero set at runtime so every massing-family skip (render, occluder,
	## collision, ground record, roof spots) applies unchanged. The bandshell
	## is NOT here: its superseded PLACEHOLDER parts run through
	## `_row_superseded_placeholder` (it carries no massing bbox — a park POI,
	## not a building), and joining it would let `_collect_roof_spots` file
	## the retired pier tops it must not.
	for hero_id: String in DOWNTOWN_RUNTIME_HERO_IDS:
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
	_build_reiman_butterflies() ## (T-204) The gardens' butterfly accents over the entrance beds.
	_build_campus_lawn() ## (T-187) The lawn slab, the crossing axes' ribbons, the fountain.
	_build_tailgate_lots() ## (T-191) The Iowa State Center lot flats + stall-marking hint.
	_build_downtown_fabric() ## (T-192) The Main Street cornices + the maroon furniture + the blade seeds.
	_build_rail_corridor() ## (T-194) The depot rides its chunk; this is the corridor dress: crossbucks, fence, the coal drag.
	_build_venue_signs() ## (T-198) The Tier-1 venue names on their street walls.
	_build_venue_signs_tiers() ## (T-199) Tiers 2–3 + the mourned ghost plaques.
	_build_street_blades() ## (T-200) The spine street-name blades at the pinned corners.
	_build_campus_plaques() ## (T-201) The campus + civic name plaques on the heroes.
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
		"mu_parks_parts": mu_parks_hero_parts.size(), ## (T-189) The MU + Parks pair is live.
		"marston_parts": marston_hero_parts.size(), ## (T-190) The water-tower hero is live.
		"stadium_parts": stadium_hero_parts.size(), ## (T-191) The bowl hero is live.
		"hilton_parts": hilton_hero_parts.size(), ## (T-191) The drum hero is live.
		"lot_flat_tris": lot_flat_tris, ## (T-191) The tailgate-lot flats are live.
		"lot_markings": lot_marking_xfs.size(), ## (T-191) The stall-marking hint is live.
		"bandshell_parts": bandshell_hero_parts.size(), ## (T-192) The bandshell hero is live.
		"civic_parts": civic_hero_parts.size(), ## (T-192) The civic pair is live.
		"fabric_parts": fabric_parts.size(), ## (T-192) The Main Street fabric is live.
		"campus_ribbons": campus_ribbon_xfs.size(), ## (T-187) The lawn dress is live.
		"campus_slab_tris": campus_slab_tris,
		"campus_plaza_tris": campus_plaza_tris,
		"fountain_parts": fountain_parts.size(),
		"depot_parts": depot_hero_parts.size(), ## (T-194) The depot hero is live.
		"elevator_parts": elevator_hero_parts.size(), ## (T-195) The SE cluster hero is live.
		"gardens_parts": gardens_hero_parts.size(), ## (T-204) The gardens hero is live.
		"butterflies": butterflies.size(), ## (T-204) The accent props are live.
		"venue_signs": venue_signs.size(), ## (T-198) The Tier-1 signs are live.
		"superdog_cart_parts": _venue_cart_parts(),
		"venue_signs_t23": venue_signs_t23.size(), ## (T-199) The tiers 2–3 signs are live.
		"ghost_plaques": ghost_plaques.size(), ## (T-199) The mourned plaques are live.
		"street_blades": street_blades.size(), ## (T-200) The street-name blades are live.
		"campus_plaques": campus_plaques.size(), ## (T-201) The name plaques are live.
		"cq_truck_parts": _cq_truck_parts(),
		"crossbuck_crossings": crossbuck_pins.size(),
		"crossbuck_posts": _crossbuck_post_xfs.size(),
		"fence_posts": _fence_post_xfs.size(),
		"fence_wires": _fence_wire_xfs.size(),
		"train_route_m": snappedf(_rail_route_length(rail_route), 0.01),
		"train_boxes": train.consist_boxes() if train != null else 0,
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
				or hero_id == BEARDSHEAR_HERO_ID \
				or hero_id == MU_HERO_ID or hero_id == PARKS_HERO_ID \
				or hero_id == MARSTON_TOWER_HERO_ID \
				or hero_id == JACK_TRICE_HERO_ID or hero_id == HILTON_HERO_ID \
				or hero_id == DEPOT_HERO_ID:
			continue ## (T-186/T-188/T-189/T-190/T-191/T-194) the campanile's cap
			## crumb is pinned; the other heroes file their own true-top spots
			## in their builds (Marston's byte-identical to the bake-derived
			## cap pin; the stadium's re-pins the ring-top read at the
			## press-tower roof, Hilton's byte-identical at the drum roof top;
			## the depot's the ridge top).
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
	_build_mu_parks_heroes(chunk_root, chunk, center, chunk_body) ## (T-189) the MU + Parks pair rides theirs.
	_build_marston_hero(chunk_root, chunk, center, chunk_body) ## (T-190) the water-tower hero rides its own chunk.
	_build_stadium_hero(chunk_root, chunk, center, chunk_body) ## (T-191) the bowl hero rides its carrier chunk.
	_build_hilton_hero(chunk_root, chunk, center, chunk_body) ## (T-191) the drum hero rides its carrier chunk.
	_build_downtown_heroes(chunk_root, chunk, center, chunk_body) ## (T-192) the bandshell + civic pair ride their carrier chunks.
	_build_civic_tank_heroes(chunk_root, chunk, center, chunk_body) ## (T-193) the city tanks ride theirs.
	_build_depot_hero(chunk_root, chunk, center, chunk_body) ## (T-194) the depot rides its carrier chunk.
	_build_elevator_hero(chunk_root, chunk, center, chunk_body) ## (T-195) the SE cluster rides its carrier chunk.
	_build_reiman_hero(chunk_root, chunk, center, chunk_body) ## (T-204) the gardens conservatory rides its carrier chunk.
	_collect_fabric_row_slots(chunk) ## (T-192) the frontage-row walk, while the doc is in hand.


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
		if pid == MU_HERO_ID or pid == PARKS_HERO_ID:
			## (T-189) The MU + Parks heroes supersede their slots' placeholder
			## parts the same 1:1 way (MU block/tower/tower_cap; Parks
			## block/addition) — their builds file the shapes; no capture.
			continue
		if pid == MARSTON_TOWER_HERO_ID:
			## (T-190) The Marston hero supersedes its slot's six placeholder
			## parts the same 1:1 way (four legs + tank + cap) — its build
			## files the shapes (the splayed legs as rotated boxes, the round
			## families as convex cylinders); no capture.
			continue
		if pid == JACK_TRICE_HERO_ID or pid == HILTON_HERO_ID:
			## (T-191) The stadium + Hilton heroes supersede their slots'
			## placeholder parts the same 1:1 way (the bowl's ring/berm/pitch,
			## the drum's ring/roof) — their builds file the shapes (the ring
			## segments on the bake's own chord schedule, the hillside/press/
			## Sukup/statue/portico boxes, the roofs as convex solids); no
			## capture.
			continue
		if pid == BANDSHELL_SLOT_ID:
			## (T-192) The bandshell hero supersedes its slot's seven shell
			## piers + stage deck the same 1:1 way — its build files the
			## shapes (the stage deck, the brick piers, the arch chords on
			## their rotated radial bases); no capture.
			continue
		if pid == CITY_TANK_NORTH_HERO_ID or pid == CITY_TANK_EAST_HERO_ID:
			## (T-193) The civic tank heroes supersede their slots'
			## stem/bulb/cap placeholder parts the same 1:1 way — their builds
			## file the shapes (the stem, the mushroom shoulder, the bulb drum
			## and the roof dome as convex cylinders); no capture.
			continue
		if pid == DEPOT_HERO_ID:
			## (T-194) The depot hero supersedes its slot's wall/roof/canopy
			## placeholder parts the same 1:1 way — its build files the shapes
			## (the wall + canopy slab boxes, the chimney, the hip frustum);
			## no capture.
			continue
		if pid == ELEVATOR_CLUSTER_HERO_ID:
			## (T-195) The elevator-cluster hero supersedes its slot's seven
			## placeholder parts (4 silos + headhouse + 2 bins) the same 1:1
			## way — its build files the shapes (the round families as convex
			## cylinders, the headhouse box, the bin cones); no capture.
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


## --- T-189 the MU + Parks heroes -------------------------------------------
## The corner block at Lincoln Way & Morrill Rd/Lynn (F-06's corrected corner)
## and the library block closing the lawn's east read. Both ids ALREADY ride
## the bake manifest's `heroes` list (the T-175 hero set), so their bbox
## massing is skipped by every massing family; the heroes supersede the
## slots' PLACEHOLDER parts at runtime (MU block/tower/tower_cap in chunk
## (1,−1); Parks block/addition in chunk (0,−3)) through
## `_row_superseded_placeholder`, the T-186/T-188 law.

const MU_HERO_ID := "way/183224150"
const PARKS_HERO_ID := "way/33725897"

## (T-189) The pinned palette — MODELING-SPECS §1.4's rows, verbatim, shared
## with the T-188 consts where the row is the same (the limestone pair); the
## additions' curtain-wall glass is the table's own "MU/parks 1950s–80s
## addition glass" row, the white spandrel panels the survey's pinned white
## (the §1.4 Marston-tank row — the table's only white estimate); the MU's
## dark slate hip borrows the table's slate row (shared with Morrill — the
## survey pins one town slate). The zodiac bronze carries NO survey hex —
## TRADITIONS §9.5 pins the WORD ("raised bronze"), so the band is held by
## the bronze-ordering law (r > g > b, dark against the limestone), the
## campanile `hand` / row `window` precedent.
const MU_SLATE := Color(0.247, 0.267, 0.298) ## #3F444C the §1.4 slate row (shared with Morrill).
const ADDITION_GLASS := Color(0.243, 0.29, 0.314) ## #3E4A50 the 1950s–80s addition glass row.
const ADDITION_PANEL := Color(0.929, 0.929, 0.918) ## #EDEDEA the survey's pinned white (the spandrel panels).
const ZODIAC_BRONZE := Color(0.43, 0.35, 0.2) ## #6E5933 — no survey hex; bronze-ordering law (r>g>b), luminance ≤ 0.45.

## The band -> color table (the record and the render share this one mapping;
## the limestone pair reuses the T-188 consts — one §1.4 table).
const MU_PARKS_BANDS: Dictionary = {
	"limestone": ROW_LIMESTONE,
	"limestone_shade": ROW_LIMESTONE_SHADE,
	"mu_slate": MU_SLATE,
	"addition_glass": ADDITION_GLASS,
	"addition_panel": ADDITION_PANEL,
	"zodiac_bronze": ZODIAC_BRONZE,
	"window": ROW_WINDOW,
}

## (T-189) The pinned heights (m). MU: the slot's OWN block top stays 20.0
## (the bake block part's settled stack — byte continuity); the photo-18
## dress adds the arcade apron (13.0), the dark slate hip (eave 20.0 → ridge
## 24.0) and the squat square corner tower. THE TOWER IS THE TICKET'S
## ESTIMATE: survey VERIFICATION "Memorial Union tower height — UNKNOWABLE…
## if a number is needed for tooling, use ≈35–45 m, UNVERIFIED"; this build
## pins 36.0 (just inside that band, the photo-19 squat read) — the estimate
## and its source uncertainty are recorded in the ticket; the ~148 ft
## circulating figure stays UNBAKED (LANDMARKS C5's caveat). Parks: the 1925
## core tops the composition at 24.0 (the slot's own block read — 5 census
## floors), the 1961/1983 additions band at 20.0 (the photo-22 blocky read).
const MU_BLOCK_TOP := 20.0
const MU_APRON_TOP := 13.0
const MU_HIP_RIDGE := 24.0
const MU_TOWER_SHAFT_TOP := 34.2
const MU_TOWER_TOP := 36.0
const PARKS_CORE_TOP := 24.0
const PARKS_ADDITION_TOP := 20.0
## The 1925 core's footprint (LANDMARKS C4's original block, 53.6 × 39.6 m —
## [x, z] here: the long axis runs N–S along the lawn's east edge).
const PARKS_CORE_SIZE := Vector2(39.6, 53.6)
## The MU corner tower's slot position — the bake's own tower part, i.e. the
## block's southwest corner: 5.0 in from the west edge (the Morrill Rd/Lynn
## corridor), 5.0 in from the south edge (Lincoln Way). F-06's corrected
## corner, kept from the bake (the ledger item).
const MU_TOWER_SLOT_INSET := 5.0
## The zodiac decal: the Gold Star Hall threshold read — one bay east of the
## tower bay on the SOUTH (Lincoln Way) face, just outside the wall line (a
## survey-anchored approximation: the tradition pins the HALL, the sources
## pin no door survey; recorded in the ticket). Visual-only — no collision,
## no ground record (students walk AROUND it; the walkability query answers
## the plate through the decal).
const ZODIAC_X_FROM_TOWER := 8.0
const ZODIAC_SOUTH_OUTSET := 2.2


func _row_band_color(band: String) -> Color:
	return CAMPUS_ROW_BANDS.get(band, ROW_LIMESTONE)


## (T-188) TRUE when a baked placeholder entry belongs to a hero that
## supersedes its slot at runtime — the campanile (T-186), Beardshear (T-188),
## the MU + Parks pair (T-189; both ids already ride the bake manifest's
## `heroes` list, so only their PLACEHOLDER parts need the runtime skip) and
## the Marston Water Tower (T-190; its id rides the same bake list, and the
## four legs + tank + cap parts are the slot the hero re-shapes). The stadium
## complex (T-191: the bowl's ring/berm/pitch parts across chunks (4,3)/(4,4)
## and the drum's ring/roof parts across (4,0)/(5,0) are the slots the two
## heroes re-shape). The Durham Bandshell (T-192: the park POI's seven shell
## piers + stage deck in chunk (13,−2) are the slot the hero re-shapes at its
## true structure position ~35 m north). The civic water tanks (T-193: the
## two municipal bulbs' stem/bulb/cap placeholder stacks — chunk (10,−5)
## north and (13,2) east — are the slots the bulb-on-stem heroes re-shape).
## The depot (T-194: the 1906 C&NW depot's wall/roof/canopy stack — chunk
## (10,−1) — is the slot the depot hero re-shapes; its id already rides the
## bake's `heroes` list, so the massing term handles its bbox). The SE
## grain-elevator cluster (T-195: the silo bank + headhouse + bins placeholder
## stack — chunk (13,−1) — is the slot the styled cluster hero re-shapes).
## The placeholder-family passes (render, collision, ground record, roof
## spots) skip these ids so a hero never renders twice.
func _row_superseded_placeholder(id: String) -> bool:
	return id == CAMPANILE_HERO_ID or id == BEARDSHEAR_HERO_ID \
			or id == MU_HERO_ID or id == PARKS_HERO_ID \
			or id == MARSTON_TOWER_HERO_ID \
			or id == JACK_TRICE_HERO_ID or id == HILTON_HERO_ID \
			or id == BANDSHELL_SLOT_ID \
			or id == CITY_TANK_NORTH_HERO_ID or id == CITY_TANK_EAST_HERO_ID \
			or id == DEPOT_HERO_ID \
			or id == ELEVATOR_CLUSTER_HERO_ID


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
				_beardshear_hero_extras(beardshear),
				campus_row_hero_parts, CAMPUS_ROW_BANDS)
	if morrill != Vector2.ZERO:
		_row_commit(chunk_root, center, "Morrill", MORRILL_HERO_ID,
				_morrill_hero_boxes(morrill),
				Vector3(morrill.x, MORRILL_RIDGE, morrill.y), chunk_body,
				_morrill_hero_extras(morrill),
				campus_row_hero_parts, CAMPUS_ROW_BANDS,
				[{"p": Vector3(morrill.x, 13.05, morrill.y),
					"s": Vector3(2.0, 3.9, 28.0)}] as Array[Dictionary])
	if farm != Vector2.ZERO:
		_row_commit(chunk_root, center, "FarmHouse", FARMHOUSE_HERO_ID,
				_farmhouse_hero_boxes(farm),
				Vector3(farm.x, FARMHOUSE_RIDGE, farm.y - 3.75), chunk_body,
				_farmhouse_hero_extras(farm),
				campus_row_hero_parts, CAMPUS_ROW_BANDS,
				[{"p": Vector3(farm.x, 11.15, farm.y - 3.75),
					"s": Vector3(19.6, 3.5, 0.9)}] as Array[Dictionary])
	if marston != Vector2.ZERO:
		_row_commit(chunk_root, center, "MarstonHall", MARSTON_HALL_HERO_ID,
				_marston_hero_boxes(marston),
				Vector3(marston.x, MARSTON_HALL_TOP, marston.y), chunk_body,
				[] as Array[Dictionary],
				campus_row_hero_parts, CAMPUS_ROW_BANDS)


## One hero's commit — the T-186 pipeline shared by the six (the T-188 four
## + the T-189 MU/Parks pair): render (the box MultiMesh + every named mesh
## extra), collision (the hero's own shapes ride the chunk's placeholder
## body — same slot, same layer-1 `world` class), ground-record tops, the
## roof-crumb host (`_hero_roof_tops`, consumed by `_append_roof_spots`), and
## the retained part record. Each extra is `{name, mesh, pos, convex, band,
## size}`: the mesh mounts at `pos` (chunk-local); a non-empty `convex`
## becomes one CollisionShape3D at the same spot; `band`/`size` file the
## record. `record` + `bands` name the retained array and the band->color
## table the hero wears (the T-188 record/`CAMPUS_ROW_BANDS` for the row, the
## T-189 record/`MU_PARKS_BANDS` for the pair).
func _row_commit(chunk_root: Node3D, center: Vector3, hero_name: String,
		hero_id: String, boxes: Array[Dictionary], crumb: Vector3,
		chunk_body: StaticBody3D, extras: Array[Dictionary],
		record: Array[Dictionary], bands: Dictionary,
		record_only: Array[Dictionary] = []) -> void:
	var hero_key: String = hero_name.to_lower().replace("farmhouse", "farm_house") \
			.replace("marstonhall", "marston_hall") \
			.replace("memorialunion", "memorial_union") \
			.replace("parkslibrary", "parks_library") ## The record's lowercase key.
	var band_color := func(band: String) -> Color:
		return bands.get(band, ROW_LIMESTONE)
	var root := Node3D.new()
	root.name = "HeroRow%s" % hero_name
	chunk_root.add_child(root)
	var mm := _new_multimesh(boxes.size())
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var p: Vector3 = b["p"]
		var s: Vector3 = b["s"]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(s), p - center))
		mm.set_instance_color(i, band_color.call(str(b["band"])))
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
		var tile_record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = tile_record.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		tile_record["ground"] = ground
		_chunks[key] = tile_record
	_buffer_bytes += bytes
	## The roof-crumb host: one ROOF spot at the hero's true top (the T-176
	## convention — the superseded bake entries stopped filing in
	## `_collect_roof_spots`).
	_hero_roof_tops[hero_id] = crumb
	## Retain the part record (world-local bands, positions, sizes, colors);
	## `mesh` marks the named mesh extras so the gate can count the box
	## schedule against the render MM separately.
	for b4: Dictionary in boxes:
		record.append({
			"hero": hero_key, "band": str(b4["band"]), "p": b4["p"],
			"s": b4["s"], "color": band_color.call(str(b4["band"])),
			"collide": b4["collide"], "mesh": false,
		})
	for e3: Dictionary in extras:
		record.append({
			"hero": hero_key, "band": str(e3["band"]), "p": e3["pos"],
			"s": e3["size"], "color": band_color.call(str(e3["band"])),
			"collide": false, "mesh": true,
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
	## extras and the box files the 20.0 walkability top — every height
	## derives from BEARDSHEAR_DOME_TOP so the settled pin is one constant).
	_add_row_box(out, "dome_light", Vector3(dx, 16.0, c.y),
			Vector3(9.0, 4.0, 9.0), true, true)
	_add_row_box(out, "dome_dark", Vector3(dx, 14.25, c.y),
			Vector3(9.3, 0.5, 9.3), false, false)
	_add_row_box(out, "dome_mid", Vector3(dx, BEARDSHEAR_DOME_TOP - 1.0, c.y),
			Vector3(3.0, 2.0, 3.0), false, true)
	return out


## Beardshear's mesh extras: the oxidized-copper dome cap — one tapered
## CylinderMesh (the round read the box path cannot give), 18→20 so the top
## stays the slot's settled 20.0 (BEARDSHEAR_DOME_TOP). The convex is the
## 8-segment frustum under it (the walkable dome mass).
func _beardshear_hero_extras(c: Vector2) -> Array[Dictionary]:
	var dx := c.x + BEARDSHEAR_DOME_OFFSET_X
	var pos := Vector3(dx, BEARDSHEAR_DOME_TOP - 1.0, c.y)
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


## --- Memorial Union + Parks Library (T-189) ----------------------------------
## The corner block at Lincoln Way & Morrill Rd/Lynn (F-06's CORRECTED corner
## — the bake's own tower part sits at the block's southwest corner, 5.0 m in
## from each edge, exactly the Lincoln Way + Morrill/Lynn read) and the
## library block closing the lawn's east read. Both supersede their slots'
## placeholder parts 1:1 through `_row_commit` (the T-188 pipeline, now
## parameterized over the record + band table).
##
## MU (F-02: PALE GRAY LIMESTONE, NOT dark brick; photo 18's north-lawn read):
## the slot-exact 20.0 block carries the collision class; the north face
## wears the long arcade apron (13.0) with the round-arch rhythm, the central
## arched entry pavilion, the stone balustrade and the two corner pavilions;
## the dark slate hip (the §1.4 slate row) rides the extras from the 20.0
## eave to the 24.0 ridge; the squat square corner TOWER rises at the bake's
## own slot to MU_TOWER_TOP — the ticket's ESTIMATE (survey band ≈35–45 m
## UNVERIFIED; see the ticket for the uncertainty note). The zodiac (F-13:
## the Gold Star Hall floor bronze, students never step on it) is a
## visual-only disc + ring at the south entry threshold read — no collision,
## no ground record (the walkability query answers the plate through it).
##
## Parks (the massing read; facade detail CAPPED at what the refs support —
## the 1925 street facade has NO usable photo, the CREDITS.md gap carried
## forward): the 1925 Bedford-limestone core (39.6 × 53.6, the LANDMARKS C4
## block, topping the composition at 24.0) at the lawn (east) frontage, the
## 1961 north wing and the 1983 west + south-leg additions (the photo-22
## blocky read, tiled to the slot's exact 95.5 × 122.9 envelope) in the
## §1.4 shade row (the pale-concrete masses), with the dark curtain-wall
## glass + white spandrel ribbon reads and the big west portal frame (piers
## + lintel — the opening between them stays fly-through clear).
func _build_mu_parks_heroes(chunk_root: Node3D, chunk: Dictionary,
		center: Vector3, chunk_body: StaticBody3D) -> void:
	var mu := Vector2.ZERO
	var mu_tower := Vector2.ZERO
	var parks := Vector2.ZERO
	var parks_box := Vector2.ZERO
	for ph: Dictionary in chunk.get("placeholders", []):
		var pid := str(ph.get("id", ""))
		if pid != MU_HERO_ID and pid != PARKS_HERO_ID:
			continue
		var part := str(ph.get("part", ""))
		if pid == MU_HERO_ID and part == "block":
			mu = Vector2(float(ph["p"][0]), float(ph["p"][2]))
		elif pid == MU_HERO_ID and part == "tower":
			mu_tower = Vector2(float(ph["p"][0]), float(ph["p"][2]))
		elif pid == PARKS_HERO_ID and part == "block":
			parks = Vector2(float(ph["p"][0]), float(ph["p"][2]))
			parks_box = Vector2(float(ph["s"][0]), float(ph["s"][2]))
	if mu != Vector2.ZERO and mu_tower != Vector2.ZERO:
		_row_commit(chunk_root, center, "MemorialUnion", MU_HERO_ID,
				_mu_hero_boxes(mu, mu_tower),
				Vector3(mu_tower.x, MU_TOWER_TOP, mu_tower.y), chunk_body,
				_mu_hero_extras(mu, mu_tower),
				mu_parks_hero_parts, MU_PARKS_BANDS,
				[{"p": Vector3(mu.x, (MU_BLOCK_TOP + MU_HIP_RIDGE) * 0.5, mu.y),
					"s": Vector3(30.0, MU_HIP_RIDGE - MU_BLOCK_TOP, 30.0)}]
					as Array[Dictionary])
	if parks != Vector2.ZERO:
		var core_x := parks.x + parks_box.x * 0.5 - PARKS_CORE_SIZE.x * 0.5
		_row_commit(chunk_root, center, "ParksLibrary", PARKS_HERO_ID,
				_parks_hero_boxes(parks),
				Vector3(core_x, PARKS_CORE_TOP, parks.y), chunk_body,
				[] as Array[Dictionary],
				mu_parks_hero_parts, MU_PARKS_BANDS)


## The MU box schedule in world-local coordinates (pack frame). The body keeps
## the bake block part's slot dims EXACT (the 109.8 × 20.0 × 109.9 envelope at
## the block center — the 1:1 collision class); every dress rides the faces.
func _mu_hero_boxes(c: Vector2, t: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nz := c.y - 54.95 ## North face — the lawn/Union Dr read (photo 18).
	## --- the slot-exact body + its courses -----------------------------------
	_add_row_box(out, "limestone", Vector3(c.x, MU_BLOCK_TOP * 0.5, c.y),
			Vector3(109.8, MU_BLOCK_TOP, 109.9), true, true)
	_add_row_box(out, "limestone_shade", Vector3(c.x, 0.5, c.y),
			Vector3(109.8, 1.0, 109.9), false, false) ## The base course.
	_add_row_box(out, "limestone_shade", Vector3(c.x, MU_BLOCK_TOP - 0.4, c.y),
			Vector3(110.4, 0.8, 110.5), true, false) ## The cornice ring.
	## --- the north arcade apron (photo 18's long lower wing) ------------------
	var az := nz - 3.0 ## The apron center z (6.0 deep, fully proud).
	var af := nz - 6.0 ## The apron front face plane.
	_add_row_box(out, "limestone", Vector3(c.x, MU_APRON_TOP * 0.5, az),
			Vector3(100.0, MU_APRON_TOP, 6.0), true, true)
	_add_row_box(out, "limestone_shade", Vector3(c.x, MU_APRON_TOP + 0.45, af + 0.5),
			Vector3(100.0, 0.9, 0.4), false, false) ## The balustrade rail.
	for sgn: int in [-1, 1]: ## The corner pavilions (the balustrade's ends).
		_add_row_box(out, "limestone",
				Vector3(c.x + float(sgn) * 48.0, 7.4, az),
				Vector3(4.0, 14.8, 6.4), true, true)
	## The central arched entry pavilion (photo 18's center read) — proud of
	## the APRON front face (proud = northward, more negative z).
	var pz := af - 1.2 ## The pavilion center z (2.4 deep past the apron face).
	var pf := af - 2.4 ## The pavilion front face plane.
	_add_row_box(out, "limestone", Vector3(c.x, MU_APRON_TOP * 0.5, pz),
			Vector3(14.0, MU_APRON_TOP, 2.4), true, true)
	_add_row_box(out, "limestone_shade", Vector3(c.x, MU_APRON_TOP - 0.3, pz),
			Vector3(14.6, 0.8, 3.0), false, false) ## The pavilion cornice.
	_add_row_box(out, "limestone_shade", Vector3(c.x, 3.4, pf - 0.1),
			Vector3(4.8, 6.8, 0.28), false, false) ## The entry surround.
	_add_row_box(out, "window", Vector3(c.x, 3.2, pf - 0.14),
			Vector3(3.8, 6.0, 0.36), false, false) ## The arched entry opening.
	_add_row_box(out, "limestone_shade", Vector3(c.x, 6.9, pf - 0.14),
			Vector3(5.4, 0.8, 0.28), false, false) ## The arch head band.
	## The round-arch rhythm: five bays each side of the pavilion, every
	## opening proud of its plane (the face-coincident z-fight law).
	for off: float in [-42.5, -34.5, -26.5, -18.5, -10.5, 10.5, 18.5, 26.5, 34.5, 42.5]:
		_add_row_box(out, "window", Vector3(c.x + off, 2.8, af - 0.06),
				Vector3(1.9, 4.0, 0.16), false, false)
		_add_row_box(out, "limestone_shade", Vector3(c.x + off, 5.15, af - 0.07),
				Vector3(2.5, 0.7, 0.2), false, false)
	## The tall block's upper window row, over the apron roofline.
	for off2: float in [-42.5, -34.5, -26.5, -18.5, -10.5, 10.5, 18.5, 26.5, 34.5, 42.5]:
		_add_row_box(out, "window", Vector3(c.x + off2, 16.0, nz - 0.04),
				Vector3(1.6, 2.6, 0.12), false, false)
	## The ridge chimneys (photo 18's roofline stacks; collide, ground rides
	## the hip's record-only ridge strip — the Farm House chimney law).
	for coff: float in [-18.0, 18.0]:
		_add_row_box(out, "limestone_shade", Vector3(c.x + coff, 23.6, c.y),
				Vector3(1.6, 3.2, 1.6), true, false)
	## --- the corner tower at the bake's own slot (the CORRECT corner) --------
	_add_row_box(out, "limestone", Vector3(t.x, MU_TOWER_SHAFT_TOP * 0.5, t.y),
			Vector3(10.0, MU_TOWER_SHAFT_TOP, 10.0), true, true) ## 0..34.2.
	_add_row_box(out, "limestone_shade", Vector3(t.x, MU_TOWER_SHAFT_TOP + 0.3, t.y),
			Vector3(10.8, 0.6, 10.8), false, false) ## The stringcourse.
	_add_row_box(out, "limestone", Vector3(t.x, MU_TOWER_TOP - 0.6, t.y),
			Vector3(9.0, 1.2, 9.0), true, true) ## The crown 34.8..36.0.
	## The tower's tall arched pair, high on the street faces (photo 19), plus
	## the corner entry at its base — south (Lincoln Way) + west (Morrill Rd).
	for toff: float in [-1.7, 1.7]:
		_add_row_box(out, "window",
				Vector3(t.x + toff, 28.0, t.y + 5.0 - 0.04),
				Vector3(1.9, 4.6, 0.12), false, false)
		_add_row_box(out, "window",
				Vector3(t.x - 5.0 + 0.04, 28.0, t.y + toff),
				Vector3(0.12, 4.6, 1.9), false, false)
	_add_row_box(out, "limestone_shade", Vector3(t.x, 2.2, t.y + 5.0 - 0.1),
			Vector3(3.0, 4.8, 0.24), false, false) ## The entry surround.
	_add_row_box(out, "window", Vector3(t.x, 2.1, t.y + 5.0 - 0.04),
			Vector3(2.4, 4.2, 0.12), false, false) ## The corner entry opening.
	return out


## The MU mesh extras: the dark slate hip (the §1.4 slate row — eave 20.0 →
## ridge 24.0, a full hip shrinking both axes) and the ZODIAC — the Gold Star
## Hall threshold read as two flat bronze cylinders (ring + proud disc) on the
## approach just south of the wall line, one bay east of the tower bay.
## Visual-only: empty convex, no ground record — students walk AROUND it.
func _mu_hero_extras(c: Vector2, t: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{
		"name": "SlateHip",
		"mesh": _row_loft_mesh(Vector2(110.6, 110.7), Vector2(30.0, 30.0), 4.0,
				MU_SLATE, MU_SLATE),
		"pos": Vector3(c.x, (MU_BLOCK_TOP + MU_HIP_RIDGE) * 0.5, c.y),
		"convex": _row_frustum_convex(Vector2(110.6, 110.7), Vector2(30.0, 30.0), 4.0),
		"band": "mu_slate", "size": Vector3(110.6, MU_HIP_RIDGE - MU_BLOCK_TOP, 110.7),
	}]
	var zx := t.x + ZODIAC_X_FROM_TOWER
	var zz := c.y + 54.95 + ZODIAC_SOUTH_OUTSET
	out.append({
		"name": "ZodiacRing", "mesh": _row_taper_mesh(3.1, 3.1, 0.03, ZODIAC_BRONZE),
		"pos": Vector3(zx, 0.03, zz), "convex": PackedVector3Array(),
		"band": "zodiac_bronze", "size": Vector3(6.2, 0.03, 6.2),
	})
	out.append({
		"name": "ZodiacDisc", "mesh": _row_taper_mesh(2.6, 2.6, 0.05, ZODIAC_BRONZE),
		"pos": Vector3(zx, 0.04, zz), "convex": PackedVector3Array(),
		"band": "zodiac_bronze", "size": Vector3(5.2, 0.05, 5.2),
	})
	return out


## The Parks box schedule (world-local). The slot's exact 95.5 × 122.9
## envelope tiles into the massing read: the 1925 limestone core (39.6 × 53.6,
## LANDMARKS C4's block) at the east (lawn) frontage topping 24.0, the 1961
## north wing, and the 1983 west band + south leg — the three additions at
## 20.0. All offsets derive from the slot center + box so a re-bake that
## moves the slot moves the hero.
func _parks_hero_boxes(p: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ex := p.x + 47.75 ## The slot's east face — the lawn frontage.
	var wx := p.x - 47.75 ## The slot's west face.
	var nz := p.y - 61.45 ## The slot's north face.
	var sz := p.y + 61.45 ## The slot's south face.
	var core_x := ex - PARKS_CORE_SIZE.x * 0.5
	var core_nz := p.y - PARKS_CORE_SIZE.y * 0.5
	var core_sz := p.y + PARKS_CORE_SIZE.y * 0.5
	## --- the 1925 core --------------------------------------------------------
	_add_row_box(out, "limestone", Vector3(core_x, PARKS_CORE_TOP * 0.5, p.y),
			Vector3(PARKS_CORE_SIZE.x, PARKS_CORE_TOP, PARKS_CORE_SIZE.y),
			true, true)
	_add_row_box(out, "limestone_shade", Vector3(core_x, PARKS_CORE_TOP - 0.35, p.y),
			Vector3(PARKS_CORE_SIZE.x + 0.6, 0.7, PARKS_CORE_SIZE.y + 0.6),
			false, false) ## The cornice.
	## The lawn-facing entry + two window rows — facade detail CAPPED here
	## (the 1925 street facade's documented gap; the east read is the
	## composition, not ornament).
	_add_row_box(out, "limestone_shade", Vector3(ex + 0.1, 3.0, p.y),
			Vector3(0.28, 6.0, 3.4), false, false) ## The entry surround.
	_add_row_box(out, "window", Vector3(ex + 0.14, 2.9, p.y),
			Vector3(0.36, 5.2, 2.6), false, false) ## The entry opening.
	for woff: float in [-23.0, -15.5, -8.0, 8.0, 15.5, 23.0]:
		for wy: float in [6.5, 12.5]:
			_add_row_box(out, "window", Vector3(ex + 0.04, wy, p.y + woff),
					Vector3(0.12, 3.0, 1.7), false, false)
	## --- the 1961 north wing ---------------------------------------------------
	var wing_cz := (nz + core_nz) * 0.5
	var wing_d := core_nz - nz
	_add_row_box(out, "limestone_shade",
			Vector3(p.x, PARKS_ADDITION_TOP * 0.5, wing_cz),
			Vector3(95.5, PARKS_ADDITION_TOP, wing_d), true, true)
	_add_row_box(out, "limestone_shade",
			Vector3(p.x, PARKS_ADDITION_TOP - 0.3, wing_cz),
			Vector3(95.9, 0.6, wing_d + 0.4), false, false) ## Its cornice.
	_add_row_box(out, "addition_glass", Vector3(p.x, 6.6, nz - 0.04),
			Vector3(91.0, 2.6, 0.14), false, false) ## The curtain wall.
	_add_row_box(out, "addition_panel", Vector3(p.x, 4.6, nz - 0.03),
			Vector3(91.0, 1.2, 0.12), false, false) ## The spandrel strip.
	_add_row_box(out, "addition_glass", Vector3(p.x, 13.4, nz - 0.04),
			Vector3(91.0, 2.6, 0.14), false, false)
	_add_row_box(out, "addition_panel", Vector3(p.x, 10.4, nz - 0.03),
			Vector3(91.0, 1.2, 0.12), false, false)
	## --- the 1983 west band + south leg ----------------------------------------
	var band_w := core_x - PARKS_CORE_SIZE.x * 0.5 - wx
	var band_cz := (core_nz + sz) * 0.5
	var band_d := sz - core_nz
	_add_row_box(out, "limestone_shade",
			Vector3(wx + band_w * 0.5, PARKS_ADDITION_TOP * 0.5, band_cz),
			Vector3(band_w, PARKS_ADDITION_TOP, band_d), true, true)
	_add_row_box(out, "limestone_shade",
			Vector3(wx + band_w * 0.5, PARKS_ADDITION_TOP - 0.3, band_cz),
			Vector3(band_w + 0.4, 0.6, band_d + 0.4), false, false)
	var leg_cz := (core_sz + sz) * 0.5
	var leg_d := sz - core_sz
	var leg_cx := core_x
	_add_row_box(out, "limestone_shade",
			Vector3(leg_cx, PARKS_ADDITION_TOP * 0.5, leg_cz),
			Vector3(PARKS_CORE_SIZE.x, PARKS_ADDITION_TOP, leg_d), true, true)
	_add_row_box(out, "limestone_shade",
			Vector3(leg_cx, PARKS_ADDITION_TOP - 0.3, leg_cz),
			Vector3(PARKS_CORE_SIZE.x + 0.4, 0.6, leg_d + 0.4), false, false)
	## The west face's curtain-wall ribbons + spandrels (the photo-22 skin).
	for gy: float in [6.6, 13.4]:
		_add_row_box(out, "addition_glass", Vector3(wx - 0.04, gy, band_cz),
				Vector3(0.14, 2.6, band_d - 4.0), false, false)
	for py: float in [4.6, 10.4, 17.2]:
		_add_row_box(out, "addition_panel", Vector3(wx - 0.03, py, band_cz),
				Vector3(0.12, 1.2, band_d - 4.0), false, false)
	_add_row_box(out, "addition_glass", Vector3(leg_cx, 6.6, sz + 0.04),
			Vector3(PARKS_CORE_SIZE.x - 4.0, 2.6, 0.14), false, false)
	_add_row_box(out, "addition_panel", Vector3(leg_cx, 4.6, sz + 0.03),
			Vector3(PARKS_CORE_SIZE.x - 4.0, 1.2, 0.12), false, false)
	## The big west portal frame (photo 22's gate): two proud piers + the
	## lintel — the 14 m opening between them stays fly-through clear.
	for poff: float in [-9.0, 9.0]:
		_add_row_box(out, "limestone_shade",
				Vector3(wx - 1.2, 9.0, band_cz + poff),
				Vector3(2.4, 18.0, 4.0), true, false)
	_add_row_box(out, "limestone_shade", Vector3(wx - 1.2, 16.0, band_cz),
			Vector3(2.4, 4.0, 18.0), true, false) ## The portal lintel.
	return out


## --- T-190 the Marston Water Tower hero -------------------------------------
## The tallest object on campus (taller than the campanile) and the flight
## beacon of the whole ring, swapping the T-175 placeholder slot 1:1 — the
## T-186 campanile law on its own chunk. `way/861201396` already rides the
## bake manifest's `heroes` list, so its bbox massing is skipped by every
## massing family; the hero supersedes the slot's SIX placeholder parts (four
## legs + tank + cap — chunk (−1,−2)'s whole gray placeholder family IS the
## tower) through `_row_superseded_placeholder`, the T-186/T-188/T-189 law.
##
## The silhouette is MODELING-SPECS §1's photo read (F-03's sibling
## correction: WHITE painted steel, NOT the dossier's dark tank —
## `campus/09,10,11,12`): the survey's 7.3 m × 12.2 m riveted cylinder carried
## as a real round drum, the balcony walkway ring at the tank's base plane,
## the bowl bottom hanging under it, the wide top cornice lip and the conical
## cap closing at the settled 51.2, and the ISU-seal medallion on the tank's
## EAST (campus-facing — photos 10/12 read it from Marston Hall and the lawn)
## face — the GEOMETRY HINT the ticket scopes: the seal SHAPE renders as the
## photo's medallion silhouette (a dark ring + proud disc); any text glyph
## defers to R4's legal pass. The trestle read (photo 11's full-height
## proportions): six splayed legs flaring from ≈2× the tank diameter at the
## foot to just inside the balcony ring at the top (the photo's ~70% trestle
## fraction), dark lattice ring braces at three levels, X bracing in the two
## lower bays, the fat riser pipe dead center and the foot pads under the
## legs. Like every corner dress: pure pack-derived geometry, zero RNG of any
## stream — a rebuild reproduces every transform byte-identically — and the
## part record is retained for the gates (headless runs cannot read
## MultiMesh instances back).

const MARSTON_TOWER_HERO_ID := "way/861201396"

## (T-190) The pinned palette — MODELING-SPECS §1.4's rows, verbatim: the
## tank's painted-steel pair (white #EDEDEA / shade #D8D8D4) and the lattice
## legs row #C9C9C4. The brace and medallion bands carry NO survey hex (the
## photos' dark lattice channels and the seal's dark silhouette) — each is
## held by a darkness law, the campanile `hand` / row `window` precedent.
const MARSTON_TANK_WHITE := Color(0.929, 0.929, 0.918) ## #EDEDEA the tank's painted steel, sunlit.
const MARSTON_TANK_SHADE := Color(0.847, 0.847, 0.831) ## #D8D8D4 the tank's shade (the bowl's curved read).
const MARSTON_LEG_STEEL := Color(0.788, 0.788, 0.769) ## #C9C9C4 the lattice legs row.
const MARSTON_BRACE := Color(0.35, 0.35, 0.33) ## No survey hex — the dark-lattice law (luminance ≤ 0.45).
const MARSTON_MEDALLION := Color(0.38, 0.38, 0.36) ## No survey hex — the dark-seal law (luminance ≤ 0.45).

## The band -> color table (the record and the render share this one mapping).
const MARSTON_BANDS: Dictionary = {
	"tank": MARSTON_TANK_WHITE,
	"tank_shade": MARSTON_TANK_SHADE,
	"legs": MARSTON_LEG_STEEL,
	"brace": MARSTON_BRACE,
	"medallion": MARSTON_MEDALLION,
}

## (T-190) The pinned heights (m) — the T-175 slot stack kept EXACTLY where
## the survey settled it (legs 0..36, tank 36..48.2 = the LANDMARKS C2
## 12.2 m × 7.3 m cylinder, cap closing at 51.2): the hero re-reads the same
## span as the photo's shapes instead of gray boxes.
const MARSTON_LEG_TOP := 36.0
const MARSTON_TANK_BOTTOM := 36.0 ## The slot stack's own — the legs' top IS the tank's bottom.
const MARSTON_TANK_TOP := 48.2 ## 36.0 + the survey's 12.2 m tank.
const MARSTON_TOTAL := 51.2 ## The survey's settled total — the beacon height.
const MARSTON_TANK_RADIUS := 3.65 ## The survey's 7.3 m diameter.
const MARSTON_LEG_BASE_R := 6.725 ## The OSM bbox's 14.0 m base spread (± half leg).
const MARSTON_LEG_TOP_R := 2.95 ## Just inside the balcony ring (the photo's flare).
const MARSTON_LEG_HALF := 0.275 ## The 0.55 m leg angle section, half.
const MARSTON_BALCONY_R := 3.95
const MARSTON_BALCONY_TOP := 36.05 ## The walkway slab over the tank's base plane.
const MARSTON_BOWL_BOTTOM := 33.2 ## The bowl's hang under the balcony (photo 11).
const MARSTON_CORNICE_R := 3.95 ## The wide top lip, flush at the tank top.
const MARSTON_CAP_BASE_R := 3.55 ## Inside the cornice lip (photo 11).
const MARSTON_MEDALLION_Y := 42.8 ## The seal's height (the photo's upper-mid tank read).
const MARSTON_MEDALLION_R := 1.5 ## The seal ring (the ~3 m medallion silhouette).
const MARSTON_MEDALLION_DISC_R := 1.15 ## The proud inner disc.
## The trestle dressing: the ring-brace levels (m); the X bracing rides the
## two lower bay levels (0..9, 9..18 — the photos' braced half).
const MARSTON_BRACE_LEVELS: Array[float] = [9.0, 18.0, 27.0]


func _marston_band_color(band: String) -> Color:
	return MARSTON_BANDS.get(band, MARSTON_TANK_WHITE)


## Builds the hero into its chunk (chunk (−1,−2) is the only carrier). Render:
## the lattice trestle + dressing as one rotated-box MultiMesh (the legs lean,
## the ring chords and X braces turn — real bases on the box path) and the
## round families as named cylinder meshes (the Beardshear dome's taper path,
## the medallion turned to face east); collision: the hero's own shapes ride
## the chunk's placeholder body — same slot, same layer-1 `world` class (the
## T-175 boxes were removed from this body's feed in `_build_chunk_colliders`);
## ground record: the walkable tops the superseded placeholders used to file
## (the balcony ring + the tank top — the cone tip stays a point, nobody
## stands on it); the roof crumb at the cone tip (byte-identical to the
## bake-derived cap-top pin); the retained part record the gates walk. No-op
## for every chunk that does not carry the tower slot.
func _build_marston_hero(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var c := Vector2.ZERO
	var found := false
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) != MARSTON_TOWER_HERO_ID \
				or str(ph.get("part", "")) != "tank":
			continue
		c = Vector2(float(ph["p"][0]), float(ph["p"][2]))
		found = true
		break
	if not found:
		return ## Not this chunk's slot (or the bake lost the tank — the dims gate fails loudly).
	var boxes := _marston_tower_boxes(c)
	var root := Node3D.new()
	root.name = "HeroMarstonTower"
	chunk_root.add_child(root)
	## Render: every trestle box through the vertex-color unit box at its own
	## rotated basis (scale applied in the box's local frame), chunk-local like
	## every placeholder family member; the world AABB per box feeds both the
	## MM's custom AABB and the record.
	var mm := _new_multimesh(boxes.size())
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var basis: Basis = b["basis"]
		var bp: Vector3 = b["p"]
		var bs: Vector3 = b["s"]
		mm.set_instance_transform(i, Transform3D(basis * Basis.from_scale(bs),
				bp - center))
		mm.set_instance_color(i, _marston_band_color(str(b["band"])))
		var ab: Array = _marston_box_aabb(basis, bp, bs)
		lo = (ab[0] as Vector3).min(lo)
		hi = (ab[1] as Vector3).max(hi)
	mm.custom_aabb = AABB(lo - center - Vector3.ONE * 2.0, (hi - lo) + Vector3.ONE * 4.0)
	var mm_node := MultiMeshInstance3D.new()
	mm_node.name = "Boxes"
	mm_node.multimesh = mm
	root.add_child(mm_node)
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
	for b2: Dictionary in boxes:
		if not b2["collide"]:
			continue
		var basis2: Basis = b2["basis"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b2["s"]
		shape.shape = box
		shape.transform = Transform3D(basis2, (b2["p"] as Vector3) - center)
		body.add_child(shape)
	## The round families (the extras): each is `{name, mesh, pos, rot,
	## convex, band, size}` — the mesh mounts at `pos` (chunk-local) with the
	## optional rotation basis; a non-empty `convex` becomes one
	## CollisionShape3D at the same spot; `band`/`size` file the record.
	for e: Dictionary in _marston_tower_extras(c):
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = str(e["name"])
		mesh_node.mesh = e["mesh"]
		var rot: Basis = e["rot"]
		mesh_node.transform = Transform3D(rot, (e["pos"] as Vector3) - center)
		root.add_child(mesh_node)
		var pts: PackedVector3Array = e["convex"]
		if not pts.is_empty():
			var extra_shape := CollisionShape3D.new()
			var convex := ConvexPolygonShape3D.new()
			convex.points = pts
			extra_shape.shape = convex
			extra_shape.transform = Transform3D(rot, (e["pos"] as Vector3) - center)
			body.add_child(extra_shape)
	## Ground record: the hero files its own true tops where the superseded
	## placeholders used to — the balcony ring (the trestle's walkable crown)
	## and the tank top (the survey answer kept; the cone tip files nothing).
	var tiles: Dictionary = {}
	var bytes := 0
	bytes += _file_ground_box(tiles, [c.x, MARSTON_BALCONY_TOP - 0.25, c.y],
			[MARSTON_BALCONY_R * 2.0, 0.5, MARSTON_BALCONY_R * 2.0])
	bytes += _file_ground_box(tiles, [c.x, (MARSTON_TANK_BOTTOM + MARSTON_TANK_TOP) * 0.5, c.y],
			[MARSTON_TANK_RADIUS * 2.0, MARSTON_TANK_TOP - MARSTON_TANK_BOTTOM,
			MARSTON_TANK_RADIUS * 2.0])
	for key: Vector2i in tiles:
		var record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = record.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		record["ground"] = ground
		_chunks[key] = record
	_buffer_bytes += bytes
	## The roof-crumb host: one ROOF spot at the hero's true top — the cone
	## tip, byte-identical to the bake-derived cap-part pin this swap retires.
	_hero_roof_tops[MARSTON_TOWER_HERO_ID] = Vector3(c.x, MARSTON_TOTAL, c.y)
	## Retain the part record (world-local AABBs, bands, colors) for the gates;
	## `mesh` marks the named mesh extras so the gate can count the trestle
	## schedule against the render MM separately.
	for b3: Dictionary in boxes:
		var ab2: Array = _marston_box_aabb(b3["basis"], b3["p"], b3["s"])
		marston_hero_parts.append({
			"hero": "marston_tower", "band": str(b3["band"]),
			"p": ((ab2[0] as Vector3) + (ab2[1] as Vector3)) * 0.5,
			"s": (ab2[1] as Vector3) - (ab2[0] as Vector3),
			"color": _marston_band_color(str(b3["band"])),
			"collide": b3["collide"], "mesh": false,
		})
	for e2: Dictionary in _marston_tower_extras(c):
		marston_hero_parts.append({
			"hero": "marston_tower", "band": str(e2["band"]), "p": e2["pos"],
			"s": e2["size"], "color": _marston_band_color(str(e2["band"])),
			"collide": false, "mesh": true,
		})


## The trestle's box schedule in WORLD-LOCAL coordinates (pack-local — the
## world node IS the pack frame), one entry per rotated box:
## `{band, basis, p, s, collide}` — `basis` the UNSCALED rotation, `s` the box
## size applied in that rotated local frame, `p` the box center. Every height
## rides the pinned constants; every span derives from the bake slot center.
func _marston_tower_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var o := Vector3(c.x, 0.0, c.y) ## The slot center.
	var rise := MARSTON_LEG_BASE_R - MARSTON_LEG_TOP_R
	var leg_len: float = sqrt(MARSTON_LEG_TOP * MARSTON_LEG_TOP + rise * rise)
	## --- the six splayed legs (the hexagonal trestle; photo 11's flare) ----
	for k in 6:
		var a := TAU * float(k) / 6.0
		var radial := Vector3(cos(a), 0.0, sin(a))
		var base := o + radial * MARSTON_LEG_BASE_R
		var top := o + radial * MARSTON_LEG_TOP_R + Vector3.UP * MARSTON_LEG_TOP
		var mid := (base + top) * 0.5
		var dir := (top - base).normalized()
		var x_axis := Vector3(-dir.z, 0.0, dir.x).normalized() ## The horizontal tangent.
		var z_axis := x_axis.cross(dir).normalized()
		var basis := Basis(x_axis, dir, z_axis)
		var leg_s := Vector3(MARSTON_LEG_HALF * 2.0, leg_len, MARSTON_LEG_HALF * 2.0)
		out.append({"band": "legs", "basis": basis, "p": mid, "s": leg_s,
				"collide": true})
		## The foot pad under each leg (photo 12's base pads) — centered so
		## its outer face aligns with the leg's own: the 0.9 m footing reads
		## proud of the 0.55 m leg without widening the base spread.
		var pad_r := MARSTON_LEG_BASE_R - (0.45 - MARSTON_LEG_HALF)
		out.append({"band": "legs",
				"basis": Basis(),
				"p": o + radial * pad_r + Vector3.UP * 0.25,
				"s": Vector3(0.9, 0.5, 0.9), "collide": true})
	## --- the lattice: ring braces at the three levels ------------------------
	for level: float in MARSTON_BRACE_LEVELS:
		var ry: float = lerpf(MARSTON_LEG_BASE_R, MARSTON_LEG_TOP_R,
				level / MARSTON_LEG_TOP)
		for k2 in 6:
			var a0 := TAU * float(k2) / 6.0
			var a1 := TAU * float(k2 + 1) / 6.0
			var v0 := o + Vector3(cos(a0) * ry, level, sin(a0) * ry)
			var v1 := o + Vector3(cos(a1) * ry, level, sin(a1) * ry)
			var chord := v1 - v0
			var x_axis2 := chord.normalized()
			var basis2 := Basis(x_axis2, Vector3.UP, x_axis2.cross(Vector3.UP))
			out.append({"band": "brace", "basis": basis2,
					"p": (v0 + v1) * 0.5,
					"s": Vector3(chord.length(), 0.28, 0.18), "collide": false})
	## --- the X bracing in the two lower bays (the photos' braced half) -------
	for k3 in 6:
		for lvl: int in 2:
			var y_lo := float(lvl) * 9.0
			var y_hi := y_lo + 9.0
			var a_lo := TAU * float(k3) / 6.0
			var a_hi := TAU * float(k3 + 1) / 6.0
			var r_lo: float = lerpf(MARSTON_LEG_BASE_R, MARSTON_LEG_TOP_R, y_lo / MARSTON_LEG_TOP)
			var r_hi: float = lerpf(MARSTON_LEG_BASE_R, MARSTON_LEG_TOP_R, y_hi / MARSTON_LEG_TOP)
			var p_lo := o + Vector3(cos(a_lo) * r_lo, y_lo, sin(a_lo) * r_lo)
			var p_hi := o + Vector3(cos(a_hi) * r_hi, y_hi, sin(a_hi) * r_hi)
			for swapped: bool in [false, true]: ## The X: both diagonals.
				var from := p_lo if not swapped else p_hi
				var to := p_hi if not swapped else p_lo
				var span := to - from
				var z_axis3 := span.normalized()
				var x_axis3 := z_axis3.cross(Vector3.UP).normalized()
				var y_axis3 := z_axis3.cross(x_axis3).normalized()
				var basis3 := Basis(x_axis3, y_axis3, z_axis3)
				out.append({"band": "brace", "basis": basis3,
						"p": (from + to) * 0.5,
						"s": Vector3(0.18, 0.18, span.length()), "collide": false})
	return out


## One rotated box's world AABB, the size through the UNSCALED basis — the
## MM custom AABB's and the record's feed (the lean and the lattice turns
## file their boxes' true extents).
func _marston_box_aabb(basis: Basis, origin: Vector3, size: Vector3) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for sx: float in [-0.5, 0.5]:
		for sy: float in [-0.5, 0.5]:
			for sz: float in [-0.5, 0.5]:
				var corner := origin + basis * Vector3(
						sx * size.x, sy * size.y, sz * size.z)
				lo = lo.min(corner)
				hi = hi.max(corner)
	return [lo, hi]


## The round families' mesh extras (world-local): the riser pipe dead center,
## the bowl hang, the balcony walkway ring, the tank drum, the top cornice
## lip, the conical cap, and the ISU-seal medallion turned to face EAST (the
## campus-facing read — photos 10/12). Visual-only medallion (empty convex —
## the tank's own convex is the wall it relieves).
func _marston_tower_extras(c: Vector2) -> Array[Dictionary]:
	var face := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(-90.0)) ## Y axis -> east.
	var out: Array[Dictionary] = [
		{
			"name": "RiserPipe", "mesh": _row_taper_mesh(0.35, 0.35, MARSTON_LEG_TOP,
					MARSTON_LEG_STEEL),
			"pos": Vector3(c.x, MARSTON_LEG_TOP * 0.5, c.y), "rot": Basis(),
			"convex": _row_cylinder_convex(0.35, 0.35, MARSTON_LEG_TOP, 6),
			"band": "legs", "size": Vector3(0.7, MARSTON_LEG_TOP, 0.7),
		},
		{
			"name": "TankBowl", "mesh": _row_taper_mesh(MARSTON_TANK_RADIUS, 1.5,
					MARSTON_TANK_BOTTOM - MARSTON_BOWL_BOTTOM, MARSTON_TANK_SHADE),
			"pos": Vector3(c.x, (MARSTON_BOWL_BOTTOM + MARSTON_TANK_BOTTOM) * 0.5, c.y),
			"rot": Basis(),
			"convex": _row_cylinder_convex(1.5, MARSTON_TANK_RADIUS,
					MARSTON_TANK_BOTTOM - MARSTON_BOWL_BOTTOM, 8),
			"band": "tank_shade",
			"size": Vector3(MARSTON_TANK_RADIUS * 2.0,
					MARSTON_TANK_BOTTOM - MARSTON_BOWL_BOTTOM,
					MARSTON_TANK_RADIUS * 2.0),
		},
		{
			"name": "BalconyDisc", "mesh": _row_taper_mesh(MARSTON_BALCONY_R,
					MARSTON_BALCONY_R, 0.5, MARSTON_LEG_STEEL),
			"pos": Vector3(c.x, MARSTON_BALCONY_TOP - 0.25, c.y), "rot": Basis(),
			"convex": _row_cylinder_convex(MARSTON_BALCONY_R, MARSTON_BALCONY_R, 0.5, 10),
			"band": "legs", "size": Vector3(MARSTON_BALCONY_R * 2.0, 0.5, MARSTON_BALCONY_R * 2.0),
		},
		{
			"name": "TankCylinder", "mesh": _row_taper_mesh(MARSTON_TANK_RADIUS,
					MARSTON_TANK_RADIUS, MARSTON_TANK_TOP - MARSTON_TANK_BOTTOM,
					MARSTON_TANK_WHITE),
			"pos": Vector3(c.x, (MARSTON_TANK_BOTTOM + MARSTON_TANK_TOP) * 0.5, c.y),
			"rot": Basis(),
			"convex": _row_cylinder_convex(MARSTON_TANK_RADIUS, MARSTON_TANK_RADIUS,
					MARSTON_TANK_TOP - MARSTON_TANK_BOTTOM, 10),
			"band": "tank",
			"size": Vector3(MARSTON_TANK_RADIUS * 2.0,
					MARSTON_TANK_TOP - MARSTON_TANK_BOTTOM, MARSTON_TANK_RADIUS * 2.0),
		},
		{
			"name": "CorniceRing", "mesh": _row_taper_mesh(MARSTON_CORNICE_R,
					MARSTON_CORNICE_R, 0.5, MARSTON_TANK_WHITE),
			"pos": Vector3(c.x, MARSTON_TANK_TOP - 0.25, c.y), "rot": Basis(),
			"convex": _row_cylinder_convex(MARSTON_CORNICE_R, MARSTON_CORNICE_R, 0.5, 10),
			"band": "tank", "size": Vector3(MARSTON_CORNICE_R * 2.0, 0.5, MARSTON_CORNICE_R * 2.0),
		},
		{
			"name": "CapCone", "mesh": _row_taper_mesh(0.22, MARSTON_CAP_BASE_R,
					MARSTON_TOTAL - MARSTON_TANK_TOP, MARSTON_TANK_WHITE),
			"pos": Vector3(c.x, (MARSTON_TANK_TOP + MARSTON_TOTAL) * 0.5, c.y), "rot": Basis(),
			"convex": _row_cylinder_convex(MARSTON_CAP_BASE_R, 0.22,
					MARSTON_TOTAL - MARSTON_TANK_TOP, 8),
			"band": "tank",
			"size": Vector3(MARSTON_CAP_BASE_R * 2.0, MARSTON_TOTAL - MARSTON_TANK_TOP,
					MARSTON_CAP_BASE_R * 2.0),
		},
		{
			"name": "MedallionRing", "mesh": _row_taper_mesh(MARSTON_MEDALLION_R,
					MARSTON_MEDALLION_R, 0.06, MARSTON_MEDALLION),
			"pos": Vector3(c.x + MARSTON_TANK_RADIUS + 0.05, MARSTON_MEDALLION_Y, c.y),
			"rot": face, "convex": PackedVector3Array(),
			"band": "medallion", "size": Vector3(0.06, MARSTON_MEDALLION_R * 2.0,
					MARSTON_MEDALLION_R * 2.0),
		},
		{
			"name": "MedallionDisc", "mesh": _row_taper_mesh(MARSTON_MEDALLION_DISC_R,
					MARSTON_MEDALLION_DISC_R, 0.08, MARSTON_MEDALLION),
			"pos": Vector3(c.x + MARSTON_TANK_RADIUS + 0.10, MARSTON_MEDALLION_Y, c.y),
			"rot": face, "convex": PackedVector3Array(),
			"band": "medallion", "size": Vector3(0.08, MARSTON_MEDALLION_DISC_R * 2.0,
					MARSTON_MEDALLION_DISC_R * 2.0),
		},
	]
	return out


## --- T-191 the Jack Trice Stadium complex hero ------------------------------
## The town's biggest silhouette set, one complex — the #1 and #2
## from-the-air reads (the bowl + the drum) — swapping the T-175 placeholder
## slots 1:1 on the T-186 law. `way/613735866` (the bowl) and
## `way/180651868` (the drum) already ride the bake manifest's `heroes`
## list, so their bbox massing is skipped by every massing family; the
## heroes supersede the slots' placeholder parts through
## `_row_superseded_placeholder` (the bowl's 22+14 ring segments + 2 berms +
## pitch across chunks (4,3)/(4,4); the drum's 12 segments + roof across
## (4,0)/(5,0)).
##
## The silhouette is MODELING-SPECS §1.3's photo read (`images/stadium/20`
## the west gate facade with the flanking berms · `21` the glass gable ·
## `22` the drum): a concrete bowl 183 × 208 m long axis N–S (V-09 — the
## field runs NORTH–SOUTH, standard; the "Wikipedia east–west" line was a
## misquote — verification ledger V-09), double-decked sideline grandstands
## whose seats read brick-red from OUTSIDE with the gold section accents,
## the 3-level press/suite tower on the WEST sideline (1997), the glass
## Sukup endzone-club hint closing the SOUTH end over the bowl (2015; the
## authored south mass `way/613735869` keeps the exterior read), the north
## videoboard (11 × 24.2 m, added 2011 — V-11) over the Jacobson mass, and
## the NORTH grass hillside wedge (V-11: GA berms in the NE/NW corners)
## crested past the bowl's north rim. The naming timeline is ground truth
## and rides these comments (TRADITIONS §3 / F-15): students fought for the
## name from 1973–74, the FIELD named 1984 (informal use from the 1975
## opening as Cyclone Stadium / Jack Trice Field), the STATUE dedicated
## 1988 on Central Campus and MOVED here when the STADIUM was renamed
## Jack Trice Stadium in 1997, the street Jack Trice Way in 2023 — the
## only D-I FBS stadium named for a Black man; the CYCLONES facade letters
## defer to R4's legal pass (text), and the statue is a simplified
## dignified read: presence, the forward crouch of the "Fight low, with
## your eyes open" letter, no face, no caricature. The statue POSITION is
## a survey-anchored approximation recorded right here (the V-30 law: no
## sourced statue coordinate exists in the survey): the northeast plaza
## between the hillside wedge and the east lots, overlooking the bowl.
## Hilton: the low 12-sided board-formed concrete drum 138 × 105 m with
## the stain-streak panels, the shallow arc roof overhang and the east
## entry portico hint (canopy + columns + the ISU-seal medallion
## silhouette — the T-190 medallion law; the cast HILTON COLISEUM letters
## defer to R4's legal pass). Tailgate lots: the pack's own Iowa State
## Center lot polygons (census §3 — 19 mapped, 8.9 ha, the tailgate box
## filter `ames_parking.gd` carries) painted as paved flats with a white
## stall-marking hint — the populated dressing is T-208's. Like every
## corner dress: pure pack-derived geometry, zero RNG of any stream — a
## rebuild reproduces every transform byte-identically — and the part
## records are retained for the gates (headless runs cannot read
## MultiMesh instances back).

const JACK_TRICE_HERO_ID := "way/613735866"
const HILTON_HERO_ID := "way/180651868"

## (T-191) The pinned palette — MODELING-SPECS §1.3's rows, verbatim.
const STADIUM_SEAT_CARDINAL := Color(0.651, 0.098, 0.18) ## #A6192E the seat field (dominant).
const STADIUM_SEAT_GOLD := Color(0.788, 0.663, 0.306) ## #C9A94E the section accents.
const STADIUM_CONCRETE := Color(0.612, 0.612, 0.58) ## #9C9C94 the weathered bowl concrete.
const STADIUM_PRESS_GLASS := Color(0.431, 0.482, 0.51) ## #6E7B82 the press tower glass/steel.
const STADIUM_SUKUP_GLASS := Color(0.788, 0.776, 0.561) ## #C9C68F the pale yellow-green club glass.
const STADIUM_FIELD_GRASS := Color(0.306, 0.478, 0.227) ## #4E7A3A the field grass (and the berms).
const STADIUM_FIELD_MARK := Color(0.91, 0.91, 0.886) ## #E8E8E2 the white markings.
const LOT_ASPHALT := Color(0.337, 0.345, 0.361) ## #56585C the tailgate asphalt.
const LOT_MARKING := Color(0.91, 0.91, 0.886) ## the white stall lines (the §1.3 markings row).
const HILTON_CONCRETE := Color(0.651, 0.62, 0.561) ## #A69E8F the board-formed concrete.
const HILTON_STREAK := Color(0.549, 0.522, 0.478) ## #8C857A the stain streaks.

## The bands that carry NO survey hex, held by darkness laws (the campanile
## `hand` precedent): the videoboard slab (L1 black + emissive), the statue
## bronze + stone (the dignity read — dark, quiet, no caricature), and the
## Hilton seal (the medallion silhouette).
const STADIUM_VIDEOBOARD := Color(0.12, 0.12, 0.13) ## Dark law: luminance ≤ 0.25.
const STATUE_BRONZE := Color(0.29, 0.22, 0.15) ## Dark law: luminance ≤ 0.35.
const STATUE_STONE := Color(0.34, 0.34, 0.33) ## Dark law: luminance ≤ 0.35.
const HILTON_SEAL := Color(0.38, 0.36, 0.33) ## Medallion law: luminance ≤ 0.45.

## (T-191) The pinned bowl geometry — the T-175 slot numbers kept EXACTLY:
## the ring's outer face at the survey's 91.5 × 104.0 half-extents (the
## 183 × 208 m envelope, V-09), built on the bake's own chord schedule (36
## segments, 20 m band, inward shift width/2 — the `_ring_parts` geometry
## the placeholder baked, now decked). Double-decked sidelines (LANDMARKS
## C6): the upper deck cantilevers 7 m over the lower deck at the same
## outer face, the end zones ride one deck, and the north end drops to the
## low wall the grass hillside crests over.
const STADIUM_RING_RX := 91.5
const STADIUM_RING_RZ := 104.0
const STADIUM_RING_SEGMENTS := 36
const STADIUM_RING_WIDTH := 20.0
const STADIUM_SIDE_LOWER_TOP := 10.5
const STADIUM_SIDE_UPPER_TOP := 19.5
const STADIUM_SIDE_UPPER_WIDTH := 13.0
const STADIUM_END_TOP := 16.0
const STADIUM_NORTH_WALL_TOP := 6.0
## The west press/suite tower (1997, 3 levels — LANDMARKS C6): concrete
## base + two glass levels + the roof slab, its west face ON the ring's
## outer face, rising above the sideline decks.
const STADIUM_PRESS_X := -79.0 ## The base center x offset (25 m deep, −91.5..−66.5).
const STADIUM_PRESS_HALF_Z := 30.0
const STADIUM_PRESS_TOP := 29.0
## The Sukup Endzone Club hint (2015 south enclosure): the pale glass band
## closing the south end over the deck, inner face flush.
const STADIUM_SUKUP_TOP := 22.0
## The north videoboard (V-11: 11 × 24.2 m, added 2011), mounted over the
## Jacobson mass at the north end, face to the field (south).
const STADIUM_VIDEOBOARD_SIZE := Vector3(24.2, 11.0, 1.2)
const STADIUM_VIDEOBOARD_CENTER := Vector3(0.0, 23.5, -105.0)
## The north grass hillside (V-11: GA berms in the NE/NW corners): two
## grass steps per side, crested past the bowl's north rim (the berm
## union's north edge sits beyond the ring's — the T-175 reach law). The
## x bands clear the authored Jacobson mass (x 1166.7..1210.7 pack-local).
const STADIUM_BERM_STEP1 := Vector3(36.0, 6.0, 24.0) ## Center y 3.0, z offset −108.
const STADIUM_BERM_STEP2 := Vector3(24.0, 4.5, 15.0) ## Center y 8.25, z offset −104.5.
const STADIUM_BERM_X := 52.0
## The pitch (V-09: "MidAmerican Field" 53 m E–W × 113 m N–S — the N–S
## orientation IS the AC assertion), kept at the slot's own 0.6 deck.
const STADIUM_PITCH_SIZE := Vector3(53.0, 0.6, 113.0)
## The Jack Trice statue at the northeast plaza (the survey-anchored
## approximation recorded in the section header): plaza offset from the
## bowl center. The figure is the simplified dignified read — the crouch
## of the October 5, 1923 letter, head up, eyes toward the play (south,
## the bowl side).
const STADIUM_STATUE_OFFSET := Vector2(58.0, -140.0)

## (T-191) The pinned Hilton geometry — the T-175 slot numbers kept
## EXACTLY: the 12-sided drum's outer face at the survey's 69 × 52.5
## half-extents (138 × 105 m, §1.3), the drum wall to 20.0, the arc roof
## closing at the slot's own 23.0 with the §1.3 overhang (3 m past the
## face) replacing the old inset roof box, and the east entry portico
## hint (the POI faces University Boulevard, east — `facing_deg` 75.1).
const HILTON_RING_RX := 69.0
const HILTON_RING_RZ := 52.5
const HILTON_RING_SEGMENTS := 12
const HILTON_RING_WIDTH := 12.0
const HILTON_RING_TOP := 20.0
const HILTON_ROOF_RX := 72.0
const HILTON_ROOF_RZ := 55.5
const HILTON_ROOF_Y := 21.5 ## The slab's center (20.0..23.0).
const HILTON_ROOF_TOP := 23.0
## The portico hint: canopy slab + two outer columns projecting east, the
## seal medallion silhouette on the drum wall above it (the photo-22 read:
## seal + letters between canopy and roof; the letters defer to R4).
const HILTON_PORTICO_CANOPY := Vector3(13.0, 1.0, 26.0) ## Center (+72.0, 8.7, 0).
const HILTON_PORTICO_COL := Vector3(0.9, 8.2, 0.9) ## Centers (+77.5, 4.1, ±11.5).
const HILTON_SEAL_POS := Vector3(69.1, 13.0, 0.0)
const HILTON_SEAL_R := 1.6

## The band -> color table (the records and the render share this one
## mapping; the deck bands split the ring palette).
const STADIUM_BANDS: Dictionary = {
	"bowl_cardinal": STADIUM_SEAT_CARDINAL,
	"bowl_gold": STADIUM_SEAT_GOLD,
	"bowl_concrete": STADIUM_CONCRETE,
	"berm": STADIUM_FIELD_GRASS,
	"pitch": STADIUM_FIELD_GRASS,
	"field_mark": STADIUM_FIELD_MARK,
	"press_concrete": STADIUM_CONCRETE,
	"press_glass": STADIUM_PRESS_GLASS,
	"sukup": STADIUM_SUKUP_GLASS,
	"videoboard": STADIUM_VIDEOBOARD,
	"statue_plaza": STADIUM_CONCRETE,
	"statue_stone": STATUE_STONE,
	"statue_bronze": STATUE_BRONZE,
}
const HILTON_BANDS: Dictionary = {
	"drum": HILTON_CONCRETE,
	"drum_streak": HILTON_STREAK,
	"hilton_roof": HILTON_CONCRETE,
	"hilton_portico": HILTON_CONCRETE,
	"hilton_seal": HILTON_SEAL,
}


func _stadium_band_color(band: String) -> Color:
	return STADIUM_BANDS.get(band, STADIUM_CONCRETE)


func _hilton_band_color(band: String) -> Color:
	return HILTON_BANDS.get(band, HILTON_CONCRETE)


## One hero box schedule entry's render+collision+record mount, shared by
## the two complex heroes (the T-190 tower's own build keeps its shape —
## this is the same law with the record name parameterized): render every
## box through the chunk's vertex-color unit box at its own (optional
## rotated) basis, append colliding boxes to the chunk's placeholder body,
## file `ground`-flagged boxes into the walkable-top record, retain every
## box in `record`. `extra_bands` (T-192) extends the band->color lookup
## for later heroes (the band names stay unique across ALL the tables).
## Returns the MultiMeshInstance3D (or null for an empty schedule).
func _mount_complex_hero_boxes(root: Node3D, body: StaticBody3D, center: Vector3,
		boxes: Array[Dictionary], record: Array[Dictionary], hero_name: String,
		mm_name: String, extra_bands: Dictionary = {}) -> MultiMeshInstance3D:
	if boxes.is_empty():
		return null
	var mm := _new_multimesh(boxes.size())
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var tiles: Dictionary = {}
	var bytes := 0
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var basis: Basis = b.get("basis", Basis())
		var bp: Vector3 = b["p"]
		var bs: Vector3 = b["s"]
		var band := str(b["band"])
		## The band names are unique across the tables (one lookup).
		var color: Color = STADIUM_BANDS.get(band, HILTON_BANDS.get(band,
				extra_bands.get(band, Color(0.5, 0.5, 0.5))))
		mm.set_instance_transform(i, Transform3D(basis * Basis.from_scale(bs),
				bp - center))
		mm.set_instance_color(i, color)
		var ab: Array = _complex_box_aabb(basis, bp, bs)
		lo = (ab[0] as Vector3).min(lo)
		hi = (ab[1] as Vector3).max(hi)
		if bool(b.get("collide", true)):
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = bs
			shape.shape = box
			shape.transform = Transform3D(basis, bp - center)
			body.add_child(shape)
		if bool(b.get("ground", false)):
			## The walkable top files from the box's world AABB (the same
			## corners the record holds) — identical numbers for the
			## axis-aligned schedules, the honest footprint for the rotated
			## ones (the T-192 arch chords; the T-191 schedule is identity
			## and files byte-unchanged).
			var gc := ((ab[0] as Vector3) + (ab[1] as Vector3)) * 0.5
			var gs := (ab[1] as Vector3) - (ab[0] as Vector3)
			bytes += _file_ground_box(tiles, [gc.x, gc.y, gc.z],
					[gs.x, gs.y, gs.z])
		record.append({
			"hero": hero_name, "band": band,
			"p": ((ab[0] as Vector3) + (ab[1] as Vector3)) * 0.5,
			"s": (ab[1] as Vector3) - (ab[0] as Vector3),
			"color": color, "collide": bool(b.get("collide", true)),
			"mesh": false,
		})
	mm.custom_aabb = AABB(lo - center - Vector3.ONE * 2.0,
			(hi - lo) + Vector3.ONE * 4.0)
	var mm_node := MultiMeshInstance3D.new()
	mm_node.name = mm_name
	mm_node.multimesh = mm
	root.add_child(mm_node)
	for key: Vector2i in tiles:
		var rec: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = rec.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		rec["ground"] = ground
		_chunks[key] = rec
	_buffer_bytes += bytes
	return mm_node


## One rotated/axis-aligned box's world AABB (the `_marston_box_aabb` law,
## shared by the complex heroes).
func _complex_box_aabb(basis: Basis, origin: Vector3, size: Vector3) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for sx: float in [-0.5, 0.5]:
		for sy: float in [-0.5, 0.5]:
			for sz: float in [-0.5, 0.5]:
				var corner := origin + basis * Vector3(
						sx * size.x, sy * size.y, sz * size.z)
				lo = lo.min(corner)
				hi = hi.max(corner)
	return [lo, hi]


## Builds the stadium hero into its carrier chunk — chunk (4,3) is the only
## carrier (the bowl center + the pitch part live there; the north rim's
## segments in chunk (4,4) retire through `_row_superseded_placeholder`).
## Render: the decked ring + hillside + press tower + Sukup hint + statues
## as one rotated-box MultiMesh; collision: the hero's own shapes ride the
## chunk's placeholder body — same slot, same layer-1 `world` class (the
## T-175 boxes were removed from this body's feed in
## `_build_chunk_colliders`); ground record: the walkable tops (the pitch,
## the berm steps, the decks, the tower roof, the statue pedestal); the
## roof crumb at the press-tower roof (the ring-top read this swap
## retires re-pins at the tower — recorded in the ticket); the retained
## part record the gates walk. No-op for every chunk that does not carry
## the pitch slot.
func _build_stadium_hero(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var c := Vector2.ZERO
	var found := false
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) != JACK_TRICE_HERO_ID \
				or str(ph.get("part", "")) != "pitch":
			continue
		c = Vector2(float(ph["p"][0]), float(ph["p"][2]))
		found = true
		break
	if not found:
		return ## Not this chunk's slot (or the bake lost the pitch — the gate fails loudly).
	var boxes := _stadium_boxes(c)
	var root := Node3D.new()
	root.name = "HeroJackTrice"
	chunk_root.add_child(root)
	var body := chunk_body
	if body == null:
		body = StaticBody3D.new()
		body.name = "Placeholders"
		body.collision_layer = 1 ## world
		body.collision_mask = 0
		chunk_root.add_child(body)
	_mount_complex_hero_boxes(root, body, center, boxes, stadium_hero_parts,
			"jack_trice", "Boxes")
	## The roof crumb: one ROOF spot at the press-tower roof (the hero's
	## true top — the superseded ring-top pin re-anchors here).
	_hero_roof_tops[JACK_TRICE_HERO_ID] = Vector3(
			c.x + STADIUM_PRESS_X, STADIUM_PRESS_TOP, c.y)


## The stadium hero's box schedule in WORLD-LOCAL coordinates (pack-local —
## the world node IS the pack frame), one entry per box:
## `{band, basis, p, s, collide, ground}` — `basis` the UNSCALED rotation
## (identity except the statue figure's lean), `s` the box size applied in
## that rotated local frame, `p` the box center. Every height rides the
## pinned constants; every span derives from the bake slot center.
func _stadium_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var o := Vector3(c.x, 0.0, c.y) ## The slot center.
	## --- the decked bowl ring (the bake's own chord schedule) ---------------
	for k in STADIUM_RING_SEGMENTS:
		var a0 := TAU * float(k) / float(STADIUM_RING_SEGMENTS)
		var a1 := TAU * float(k + 1) / float(STADIUM_RING_SEGMENTS)
		var am := (a0 + a1) * 0.5
		var ca := cos(am)
		var sa := sin(am)
		var sideline := absf(ca) >= 0.7071
		var north := sa < -0.7071
		var p0 := Vector2(c.x + STADIUM_RING_RX * cos(a0),
				c.y + STADIUM_RING_RZ * sin(a0))
		var p1 := Vector2(c.x + STADIUM_RING_RX * cos(a1),
				c.y + STADIUM_RING_RZ * sin(a1))
		var mid := (p0 + p1) * 0.5
		var from_center := mid - c
		var radial := from_center / maxf(from_center.length(), 0.001)
		## The lower deck / end zones / north wall: the placeholder band.
		var width := STADIUM_RING_WIDTH
		var height := STADIUM_END_TOP
		var band := "bowl_cardinal"
		if sideline:
			height = STADIUM_SIDE_LOWER_TOP
		elif north:
			height = STADIUM_NORTH_WALL_TOP
			band = "bowl_concrete"
		var inward := radial * (width * 0.5)
		out.append({"band": band, "basis": Basis(),
				"p": Vector3(mid.x - inward.x, height * 0.5, mid.y - inward.y),
				"s": Vector3(absf(p1.x - p0.x) + width, height,
				absf(p1.y - p0.y) + width),
				"collide": true, "ground": true})
		## The upper deck over the sideline segments only: narrower box at
		## the same outer face (the cantilever read), sections striped.
		if sideline:
			var uw := STADIUM_SIDE_UPPER_WIDTH
			var u_height := STADIUM_SIDE_UPPER_TOP - STADIUM_SIDE_LOWER_TOP
			var u_inward := radial * (uw * 0.5)
			out.append({"band": "bowl_gold" if k % 2 == 1 else "bowl_cardinal",
					"basis": Basis(),
					"p": Vector3(mid.x - u_inward.x,
					STADIUM_SIDE_LOWER_TOP + u_height * 0.5, mid.y - u_inward.y),
					"s": Vector3(absf(p1.x - p0.x) + uw, u_height,
					absf(p1.y - p0.y) + uw),
					"collide": true, "ground": true})
	## --- the north grass hillside (the berm read, NE/NW corners) ------------
	for side: float in [-1.0, 1.0]:
		out.append({"band": "berm", "basis": Basis(),
				"p": o + Vector3(side * STADIUM_BERM_X, 3.0, -108.0),
				"s": STADIUM_BERM_STEP1, "collide": true, "ground": true})
		out.append({"band": "berm", "basis": Basis(),
				"p": o + Vector3(side * STADIUM_BERM_X, 8.25, -104.5),
				"s": STADIUM_BERM_STEP2, "collide": true, "ground": true})
	## --- the pitch (V-09: 53 E–W × 113 N–S at the slot's own deck) ----------
	out.append({"band": "pitch", "basis": Basis(),
			"p": o + Vector3(0.0, 0.3, 0.0), "s": STADIUM_PITCH_SIZE,
			"collide": true, "ground": true})
	## The white markings hint (visual only): the touchline rectangle + the
	## mid line, 30 mm proud of the pitch deck.
	var my := 0.63
	for side2: float in [-1.0, 1.0]:
		out.append({"band": "field_mark", "basis": Basis(),
				"p": o + Vector3(side2 * 26.2, my, 0.0),
				"s": Vector3(0.3, 0.05, 112.0), "collide": false})
		out.append({"band": "field_mark", "basis": Basis(),
				"p": o + Vector3(0.0, my, side2 * 55.7),
				"s": Vector3(52.4, 0.05, 0.3), "collide": false})
	out.append({"band": "field_mark", "basis": Basis(),
			"p": o + Vector3(0.0, my, 0.0),
			"s": Vector3(52.4, 0.05, 0.3), "collide": false})
	## --- the west press/suite tower (3 levels, west face ON the ring) -------
	var px := STADIUM_PRESS_X
	out.append({"band": "press_concrete", "basis": Basis(),
			"p": o + Vector3(px, 6.0, 0.0),
			"s": Vector3(25.0, 12.0, STADIUM_PRESS_HALF_Z * 2.0),
			"collide": true})
	out.append({"band": "press_glass", "basis": Basis(),
			"p": o + Vector3(px, 17.0, 0.0),
			"s": Vector3(25.0, 10.0, STADIUM_PRESS_HALF_Z * 2.0),
			"collide": true})
	out.append({"band": "press_glass", "basis": Basis(),
			"p": o + Vector3(px, 25.0, 0.0),
			"s": Vector3(19.0, 6.0, 40.0), "collide": true})
	out.append({"band": "press_concrete", "basis": Basis(),
			"p": o + Vector3(px, 28.5, 0.0),
			"s": Vector3(21.0, 1.0, 44.0), "collide": true, "ground": true})
	## --- the Sukup Endzone Club hint (south end, inner face flush) ----------
	out.append({"band": "sukup", "basis": Basis(),
			"p": o + Vector3(0.0, 19.0, 86.0),
			"s": Vector3(68.0, STADIUM_SUKUP_TOP - STADIUM_END_TOP, 4.0),
			"collide": true, "ground": true})
	## --- the north videoboard (V-11, over the Jacobson mass) ----------------
	out.append({"band": "videoboard", "basis": Basis(),
			"p": o + STADIUM_VIDEOBOARD_CENTER, "s": STADIUM_VIDEOBOARD_SIZE,
			"collide": true, "ground": true})
	## --- the Jack Trice statue (the northeast plaza; dignity note in the
	## section header — presence and the crouch, no face, no caricature) ----
	var sp := o + Vector3(STADIUM_STATUE_OFFSET.x, 0.0, STADIUM_STATUE_OFFSET.y)
	out.append({"band": "statue_plaza", "basis": Basis(),
			"p": sp + Vector3(0.0, 0.06, 0.0),
			"s": Vector3(8.0, 0.12, 8.0), "collide": true, "ground": true})
	out.append({"band": "statue_stone", "basis": Basis(),
			"p": sp + Vector3(0.0, 0.72, 0.0),
			"s": Vector3(2.4, 1.2, 2.4), "collide": true, "ground": true})
	## The figure: legs mass, the forward-leaning torso (the crouch, +z the
	## bowl side), the head eyes-open toward the play, the arm reaching low
	## — the October 5, 1923 letter's posture, abstracted.
	out.append({"band": "statue_bronze", "basis": Basis(),
			"p": sp + Vector3(0.0, 1.67, 0.15),
			"s": Vector3(1.5, 0.7, 1.0), "collide": true})
	var lean := Basis(Vector3.RIGHT, deg_to_rad(35.0))
	out.append({"band": "statue_bronze", "basis": lean,
			"p": sp + Vector3(0.0, 2.0, -0.2),
			"s": Vector3(0.75, 1.15, 0.55), "collide": true})
	out.append({"band": "statue_bronze", "basis": Basis(),
			"p": sp + Vector3(0.0, 2.6, 0.15),
			"s": Vector3(0.3, 0.34, 0.34), "collide": true})
	var arm := Basis(Vector3.RIGHT, deg_to_rad(65.0))
	out.append({"band": "statue_bronze", "basis": arm,
			"p": sp + Vector3(0.0, 1.55, 0.5),
			"s": Vector3(0.16, 0.85, 0.16), "collide": true})
	return out


## Builds the Hilton hero into its carrier chunk — chunk (4,0) is the only
## carrier (the drum center + the roof part live there; the east segments
## in chunk (5,0) retire through `_row_superseded_placeholder`). Same law
## as the stadium build; the roof crumb stays byte-identical at the drum
## roof top (the slot's own answer). No-op for every chunk that does not
## carry the roof slot.
func _build_hilton_hero(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var h := Vector2.ZERO
	var found := false
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) != HILTON_HERO_ID \
				or str(ph.get("part", "")) != "roof":
			continue
		h = Vector2(float(ph["p"][0]), float(ph["p"][2]))
		found = true
		break
	if not found:
		return ## Not this chunk's slot.
	var boxes := _hilton_boxes(h)
	var root := Node3D.new()
	root.name = "HeroHilton"
	chunk_root.add_child(root)
	var body := chunk_body
	if body == null:
		body = StaticBody3D.new()
		body.name = "Placeholders"
		body.collision_layer = 1 ## world
		body.collision_mask = 0
		chunk_root.add_child(body)
	_mount_complex_hero_boxes(root, body, center, boxes, hilton_hero_parts,
			"hilton", "Boxes")
	## The arc roof slab + the seal medallion: the named mesh extras (the
	## T-190 extras law — an elliptical slab cannot ride the box path).
	var roof := MeshInstance3D.new()
	roof.name = "RoofSlab"
	roof.mesh = _elliptic_slab_mesh(HILTON_ROOF_RX, HILTON_ROOF_RZ, 3.0,
			HILTON_CONCRETE)
	roof.transform = Transform3D(Basis(),
			Vector3(h.x, HILTON_ROOF_Y, h.y) - center)
	root.add_child(roof)
	var face := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(-90.0)) ## Y axis -> east.
	var seal := MeshInstance3D.new()
	seal.name = "SealDisc"
	seal.mesh = _row_taper_mesh(HILTON_SEAL_R, HILTON_SEAL_R, 0.08, HILTON_SEAL)
	seal.transform = Transform3D(face,
			Vector3(h.x + HILTON_SEAL_POS.x, HILTON_SEAL_POS.y,
			h.y + HILTON_SEAL_POS.z) - center)
	root.add_child(seal)
	## The roof's collision: one elliptic-prism convex at the slab's spot.
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for k in HILTON_RING_SEGMENTS:
		var a := TAU * float(k) / float(HILTON_RING_SEGMENTS)
		pts.append(Vector3(cos(a) * HILTON_ROOF_RX, -1.5, sin(a) * HILTON_ROOF_RZ))
		pts.append(Vector3(cos(a) * HILTON_ROOF_RX, 1.5, sin(a) * HILTON_ROOF_RZ))
	convex.points = pts
	shape.shape = convex
	shape.transform = Transform3D(Basis(),
			Vector3(h.x, HILTON_ROOF_Y, h.y) - center)
	body.add_child(shape)
	## The roof's ground record: the walkable top filed at the T-175 slot's
	## OWN roof-box footprint (118 × 90 — the walk answers this swap
	## inherits, kept byte-identical; the overhang ring is collision, not a
	## walkable filing, so the drum plan's interior answers stay as the
	## placeholder left them).
	var tiles: Dictionary = {}
	var bytes := _file_ground_box(tiles, [h.x, HILTON_ROOF_Y, h.y],
			[HILTON_RING_RX * 2.0 - 20.0, 3.0, HILTON_RING_RZ * 2.0 - 15.0])
	for key: Vector2i in tiles:
		var rec: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = rec.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		rec["ground"] = ground
		_chunks[key] = rec
	_buffer_bytes += bytes
	## The retained record's mesh entries (the gates walk the families).
	hilton_hero_parts.append({
		"hero": "hilton", "band": "hilton_roof",
		"p": Vector3(h.x, HILTON_ROOF_Y, h.y),
		"s": Vector3(HILTON_ROOF_RX * 2.0, 3.0, HILTON_ROOF_RZ * 2.0),
		"color": HILTON_CONCRETE, "collide": true, "mesh": true,
	})
	hilton_hero_parts.append({
		"hero": "hilton", "band": "hilton_seal",
		"p": Vector3(h.x + HILTON_SEAL_POS.x, HILTON_SEAL_POS.y,
				h.y + HILTON_SEAL_POS.z),
		"s": Vector3(0.08, HILTON_SEAL_R * 2.0, HILTON_SEAL_R * 2.0),
		"color": HILTON_SEAL, "collide": false, "mesh": true,
	})
	## The roof crumb: byte-identical to the bake-derived roof pin this
	## swap retires.
	_hero_roof_tops[HILTON_HERO_ID] = Vector3(h.x, HILTON_ROOF_TOP, h.y)


## The Hilton hero's box schedule (world-local; the drum on the bake's own
## 12-segment chord schedule with the streak panels every third segment,
## the east entry portico hint — canopy + two outer columns).
func _hilton_boxes(h: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in HILTON_RING_SEGMENTS:
		var a0 := TAU * float(k) / float(HILTON_RING_SEGMENTS)
		var a1 := TAU * float(k + 1) / float(HILTON_RING_SEGMENTS)
		var p0 := Vector2(h.x + HILTON_RING_RX * cos(a0),
				h.y + HILTON_RING_RZ * sin(a0))
		var p1 := Vector2(h.x + HILTON_RING_RX * cos(a1),
				h.y + HILTON_RING_RZ * sin(a1))
		var mid := (p0 + p1) * 0.5
		var from_center := mid - h
		var inward := from_center / maxf(from_center.length(), 0.001) \
				* (HILTON_RING_WIDTH * 0.5)
		out.append({
			"band": "drum_streak" if k % 3 == 1 else "drum",
			"basis": Basis(),
			"p": Vector3(mid.x - inward.x, HILTON_RING_TOP * 0.5,
					mid.y - inward.y),
			"s": Vector3(absf(p1.x - p0.x) + HILTON_RING_WIDTH, HILTON_RING_TOP,
					absf(p1.y - p0.y) + HILTON_RING_WIDTH),
			"collide": true, "ground": true,
		})
	## The portico: canopy slab + two outer columns, projecting east.
	out.append({"band": "hilton_portico", "basis": Basis(),
			"p": Vector3(h.x + 72.0, 8.7, h.y),
			"s": HILTON_PORTICO_CANOPY, "collide": true, "ground": true})
	for side: float in [-1.0, 1.0]:
		out.append({"band": "hilton_portico", "basis": Basis(),
				"p": Vector3(h.x + 77.5, HILTON_PORTICO_COL.y * 0.5,
				h.y + side * 11.5),
				"s": HILTON_PORTICO_COL, "collide": true})
	return out


## One elliptical slab (12-gon prism) as a double-sided-shaded ArrayMesh —
## the Hilton arc-roof read the box path cannot carry. SurfaceTool norms,
## own albedo material (the dial-material path's sRGB law).
func _elliptic_slab_mesh(rx: float, rz: float, thickness: float,
		color: Color) -> ArrayMesh:
	var hh := thickness * 0.5
	var top := PackedVector3Array()
	for k in HILTON_RING_SEGMENTS:
		var a := TAU * float(k) / float(HILTON_RING_SEGMENTS)
		top.append(Vector3(cos(a) * rx, hh, sin(a) * rz))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := HILTON_RING_SEGMENTS
	for k in n:
		var k1 := (k + 1) % n
		## Top face fan.
		st.set_normal(Vector3.UP)
		st.set_color(color)
		st.add_vertex(Vector3.ZERO + Vector3(0.0, hh, 0.0))
		st.add_vertex(top[k])
		st.add_vertex(top[k1])
		## Bottom face fan.
		st.set_normal(Vector3.DOWN)
		st.add_vertex(Vector3(0.0, -hh, 0.0))
		st.add_vertex(top[k1] + Vector3(0.0, -thickness, 0.0))
		st.add_vertex(top[k] + Vector3(0.0, -thickness, 0.0))
		## Side wall.
		var side := Vector3(top[k].x, 0.0, top[k].z).normalized()
		st.set_normal(side)
		st.add_vertex(top[k])
		st.add_vertex(top[k] + Vector3(0.0, -thickness, 0.0))
		st.add_vertex(top[k1] + Vector3(0.0, -thickness, 0.0))
		st.add_vertex(top[k])
		st.add_vertex(top[k1] + Vector3(0.0, -thickness, 0.0))
		st.add_vertex(top[k1])
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	return mesh


## --- T-191 the tailgate lot massing -----------------------------------------
## The surrounding Iowa State Center lots as paved flats with a white
## stall-marking hint (§1.3's LOD row: "L0 ground splats + prop scatter" —
## the populated dressing is T-208's). The data path is the parking
## census's own lot list (`AmesParking.lots`, the census §3 tailgate box
## filter that file carries) — one data source, paint and dressing can
## never disagree. The flats ride the T-187 mesh path (ear-clip over the
## baker's own ring-split, mesh-carried vertex colors converted
## sRGB→linear at the build); the markings ride a box MultiMesh at the
## 30 mm-proud step the ribbon read proved depth-safe. Both families live
## OUTSIDE the bake-derived render metric (the T-187 corner-dress law),
## records retained for the gate. Zero RNG of any stream — a rebuild
## reproduces every transform byte-identically.
const LOT_FLAT_Y := 0.03 ## The paved flat, above the 0.014 ground-cell tops.
const LOT_MARK_Y := 0.06 ## The stall lines, 30 mm proud of the flat.
const LOT_ROW_PITCH := 6.0 ## The stall-row module (depth + aisle).
const LOT_STALL_PITCH := 2.75 ## The stall width along the row.
const LOT_STALL_DEPTH := 5.0 ## The painted line length across the row.


func _build_tailgate_lots() -> void:
	if parking == null:
		return ## The parking system never built — the dress stays empty.
	var root := Node3D.new()
	root.name = "StadiumLots"
	add_child(root)
	var lots: Array[PackedVector2Array] = []
	var union := Rect2()
	for lot: AmesParking.Lot in parking.lots:
		if not lot.in_tailgate or lot.polygon.size() < 3:
			continue
		lots.append(lot.polygon)
		union = union.merge(lot.aabb)
	if lots.is_empty():
		return ## The census lost the lot sea — the gate fails loudly.
	_build_lot_flats(root, lots)
	_build_lot_markings(root, lots, union)


## The paved flats: every tailgate lot polygon ear-clipped (the baker's own
## triangulator, fed through its own ring-split first — the T-187 law) into
## ONE vertex-colored ArrayMesh at the pinned flat level.
func _build_lot_flats(root: Node3D, lots: Array[PackedVector2Array]) -> void:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var tris := 0
	for poly: PackedVector2Array in lots:
		for ring: PackedVector2Array in AmesBaker._split_rings(poly):
			for t: Vector3i in AmesBaker._triangulate(ring):
				tris += 1
				for idx: int in [t.x, t.y, t.z]:
					verts.append(Vector3(poly[idx].x, LOT_FLAT_Y, poly[idx].y))
					## Mesh-carried vertex colors ride the shader as LINEAR
					## values (the T-187 color-space law).
					colors.append(_srgb_to_linear(LOT_ASPHALT))
	if tris == 0:
		return
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
	node.name = "LotFlats"
	node.mesh = mesh
	root.add_child(node)
	lot_flat_tris = tris


## The stall-marking hint: rows every `LOT_ROW_PITCH` across the lot's
## SHORT axis, stall lines every `LOT_STALL_PITCH` along the LONG axis,
## each line emitted only when both ends and its center sit inside the lot
## polygon. Box MultiMesh, white, records retained.
func _build_lot_markings(root: Node3D, lots: Array[PackedVector2Array],
		union: Rect2) -> void:
	var xfs: Array[Transform3D] = []
	for poly: PackedVector2Array in lots:
		var min_x := INF
		var min_z := INF
		var max_x := -INF
		var max_z := -INF
		for p: Vector2 in poly:
			min_x = minf(min_x, p.x)
			min_z = minf(min_z, p.y)
			max_x = maxf(max_x, p.x)
			max_z = maxf(max_z, p.y)
		var long_x := (max_x - min_x) >= (max_z - min_z)
		var a_lo := min_x if long_x else min_z
		var a_hi := max_x if long_x else max_z
		var b_lo := min_z if long_x else min_x
		var b_hi := max_z if long_x else max_x
		var row := b_lo + LOT_STALL_DEPTH * 0.5
		while row <= b_hi:
			var stall := a_lo + LOT_STALL_PITCH * 0.5
			while stall <= a_hi:
				## The line: across the row (the stall depth), centered on
				## the stall pitch; emitted only fully inside the polygon.
				var pa := Vector2(stall, row - LOT_STALL_DEPTH * 0.5)
				var pb := Vector2(stall, row + LOT_STALL_DEPTH * 0.5)
				var pc := Vector2(stall, row)
				var size := Vector3(0.12, 0.04, LOT_STALL_DEPTH)
				var pos := Vector3(stall, LOT_MARK_Y, row)
				if not long_x:
					pa = Vector2(row - LOT_STALL_DEPTH * 0.5, stall)
					pb = Vector2(row + LOT_STALL_DEPTH * 0.5, stall)
					pc = Vector2(row, stall)
					size = Vector3(LOT_STALL_DEPTH, 0.04, 0.12)
					pos = Vector3(row, LOT_MARK_Y, stall)
				if Geometry2D.is_point_in_polygon(pa, poly) \
						and Geometry2D.is_point_in_polygon(pb, poly) \
						and Geometry2D.is_point_in_polygon(pc, poly):
					xfs.append(Transform3D(Basis.from_scale(size), pos))
				stall += LOT_STALL_PITCH
			row += LOT_ROW_PITCH
	lot_marking_xfs = xfs
	if xfs.is_empty():
		return
	var mm := _new_multimesh(xfs.size())
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, LOT_MARKING)
	var mm_lo := Vector3(union.position.x, 0.0, union.position.y) - Vector3.ONE * 4.0
	var mm_size := Vector3(union.size.x, 0.0, union.size.y) + Vector3.ONE * 8.0
	mm.custom_aabb = AABB(mm_lo, mm_size)
	var node := MultiMeshInstance3D.new()
	node.name = "LotMarkings"
	node.multimesh = mm
	root.add_child(node)


## --- T-192 the downtown heroes + the Main Street fabric ---------------------
## Downtown's identity set, on the T-186/T-188/T-191 swap law:
##
## - **Durham Bandshell** (LANDMARKS T2 — built 1934, refurbished 2005;
##   §1.7's L3 "a small, high-value organic shell"): the weathered-copper
##   ribbed arch over the pale mint/cream concentric shells on the red-brick
##   pier pair, standing in Bandshell Park. The park sits ~30 m OUTSIDE the
##   v1 core bbox (census §5) — the hero models the STRUCTURE at its true
##   position: the OSM way `269752151` footprint (25.4 × 14.6 m, center
##   (3360.9, −377.7)), ~35 m north of the T-175 placeholder slot whose seven
##   shell piers + stage deck sit at the PARK POI's centroid (3353.52,
##   −412.08). The slot parts retire through `_row_superseded_placeholder`;
##   the shell keeps the footprint's own orientation — the wide NORTH block
##   is the open face and pier line (the audience lawn runs north off the
##   structure's 5th-St end; 5th Street is the park's SOUTH edge, the lawn
##   stretches away from it), the narrow south neck the dome's taper + rear
##   annex — so the scallop reads from Main Street and from the air as the
##   survey's instant-read demands (LANDMARKS §5 item 13); T-203 extends the
##   bbox east and makes the inclusion official. Proportions are the photo
##   read (`downtown/05` front: ~4 nested shells under the copper band;
##   `downtown/06` side: brick piers with the art-deco grille windows, dome
##   depth ≈ half the span), flagged as photo-grounded approximations — the
##   survey pins no bandshell dims.
## - **City Hall** (`relation/2560369`, 515 Clark — LANDMARKS T3) and the
##   **Municipal Building** (`way/237834146`, photo `downtown/02`): the civic
##   brick set. Each swaps its AUTHORED massing slot 1:1 (the T-188 runtime
##   `_hero_ids` law), keeps the slot envelope EXACT, and wears the photo-02
##   stone vocabulary at hint level: the cornice band, the cartouche entry
##   surround with the carved panel, the door, the steps. City Hall fronts
##   Clark Ave (its east face — Clark runs at x ≈ 2750, east of the block);
##   the Municipal Building fronts Kellogg (its west face — Kellogg at
##   x ≈ 3013, west of the block). The bake slot colors are the §1.7 brick
##   range's own two ends (#A8663F / #8A4A36) and stay.
## - **The Main Street fabric**: the two frontage rows (Main + 5th, §1.7's
##   L2 row) get cornice hints riding their own bake slots (0.8/1.2 m bands
##   alternating by a fixed parity — the parapet-variety hint); the maroon
##   street furniture (#5C2E35 lamp posts with gooseneck arms + shades and
##   banner brackets) and the blue AMES banner slab (#2E4E9E, text is R4)
##   run the Main sidewalks at a fixed pitch, skipping the cross streets;
##   the Whiskey River-style neon blade sign (no text — R4's legal pass)
##   seeds the bar-sign typology on the row's named bar venues.
##   NO door-number logic anywhere — the survey's QA-corrected rule (Main
##   numbering increases WESTWARD, V-06/F-07) is honored by not reading
##   numbers; the blade mounts derive from the pack's own venue names.
##
## Like every corner dress: pure pack/bake-derived geometry, zero RNG of any
## stream — a rebuild reproduces every transform byte-identically — and the
## part records are retained for the gates (headless runs cannot read
## MultiMesh instances back).

const BANDSHELL_SLOT_ID := "downtown_bandshell"
const CITY_HALL_HERO_ID := "relation/2560369"
const MUNICIPAL_HERO_ID := "way/237834146"

## (T-192) The civic massing-slot supersessions (the T-188 runtime-merge law;
## the bandshell is deliberately NOT here — see `generate_step_ground`).
const DOWNTOWN_RUNTIME_HERO_IDS: Array[String] = [
	CITY_HALL_HERO_ID, MUNICIPAL_HERO_ID,
]

## (T-192) The pinned palette — §1.7's downtown rows, verbatim.
const BSHELL_ARCH := Color(0.29, 0.353, 0.341) ## #4A5A57 the weathered copper arch.
const BSHELL_MINT := Color(0.863, 0.91, 0.863) ## #DCE8DC the pale mint shells.
const BSHELL_CREAM := Color(0.929, 0.914, 0.847) ## #EDE9D8 the cream shells.
const BSHELL_BRICK := Color(0.612, 0.29, 0.204) ## #9C4A34 the brick piers + stage base.
const CIVIC_CORNICESTONE := Color(0.839, 0.808, 0.733) ## #D6CDBB the cornice stone (civic + fabric).
const CIVIC_BRICK_LIGHT := Color(0.659, 0.4, 0.247) ## #A8663F City Hall — its OWN bake slot color (the range's light end).
const CIVIC_BRICK_DARK := Color(0.541, 0.29, 0.212) ## #8A4A36 the Municipal Building — its OWN bake slot color (the range's dark end).
const FURNITURE_MAROON := Color(0.361, 0.18, 0.208) ## #5C2E35 the street furniture.
const BANNER_BLUE := Color(0.18, 0.306, 0.62) ## #2E4E9E the AMES banner.

## The bands with NO survey hex, held by laws (the campanile `hand`
## precedent): the piers' dark ironwork grilles, the civic doors, the blade
## board (all dark law ≤ 0.25) and the neon tube (photo-07 read — red-orange;
## no survey hex exists, pinned exact here and asserted as the scenario's
## own literal).
const BSHELL_GRILLE := Color(0.14, 0.15, 0.16) ## Dark law: luminance ≤ 0.25.
const CIVIC_DOOR := Color(0.16, 0.14, 0.13) ## Dark law: luminance ≤ 0.25.
const BLADE_BOARD := Color(0.13, 0.12, 0.13) ## Dark law: luminance ≤ 0.25.
const BLADE_NEON := Color(0.91, 0.32, 0.14) ## The neon tube read (photo 07).

## (T-192) The band -> color table (the records and the render share this
## one mapping).
const DOWNTOWN_BANDS: Dictionary = {
	"arch": BSHELL_ARCH,
	"shell_mint": BSHELL_MINT,
	"shell_cream": BSHELL_CREAM,
	"pier_brick": BSHELL_BRICK,
	"backstage": BSHELL_BRICK,
	"stage_floor": BSHELL_CREAM,
	"grille": BSHELL_GRILLE,
	"civic_brick": CIVIC_BRICK_LIGHT,
	"civic_brick_dark": CIVIC_BRICK_DARK,
	"cornice_stone": CIVIC_CORNICESTONE,
	"cartouche_stone": CIVIC_CORNICESTONE,
	"civic_door": CIVIC_DOOR,
	"cornice": CIVIC_CORNICESTONE,
	"lamp": FURNITURE_MAROON,
	"lamp_arm": FURNITURE_MAROON,
	"lamp_shade": FURNITURE_MAROON,
	"banner_arm": FURNITURE_MAROON,
	"banner": BANNER_BLUE,
	"blade": BLADE_BOARD,
	"blade_neon": BLADE_NEON,
}

## (T-192) The pinned bandshell geometry: the OSM footprint is the truth
## (25.4 × 14.6 m at the pinned center; +z offsets run SOUTH toward the
## stage neck), the heights are the photo read. The arch rings stand on the
## stage deck top (the slot's own 1.2, kept byte-continuous); the front
## plane sits in the wide north block, the rear rings step south so the
## dome profile slopes down toward the annex.
const BSHELL_CENTER := Vector2(3360.9, -377.7)
const BSHELL_STAGE_TOP := 1.2 ## The slot's own stage deck top.
const BSHELL_PIER_TOP := 7.2
const BSHELL_APEX := 11.6 ## The outer arch crown (base 1.2 + r 9.2 + t/2 1.2).
## One arch ring: r the arch radius, t the radial band thickness, z the
## ring's south-offset from the center, d the ring's z depth, n the chord
## count, band the palette row, ground whether the chords file walkable
## tops — the FRONT scallop only (the rear profile rings would otherwise
## file their tops over the stage deck's own walk answer behind the face).
const BSHELL_RINGS: Array = [
	{"r": 9.2, "t": 2.4, "z": -5.2, "d": 3.0, "n": 10, "band": "arch", "ground": true},
	{"r": 6.6, "t": 2.3, "z": -5.2, "d": 2.9, "n": 10, "band": "shell_mint", "ground": true},
	{"r": 4.3, "t": 2.1, "z": -5.2, "d": 2.8, "n": 10, "band": "shell_cream", "ground": true},
	{"r": 2.3, "t": 1.8, "z": -5.2, "d": 2.7, "n": 8, "band": "shell_mint", "ground": true},
	{"r": 7.4, "t": 2.2, "z": -1.8, "d": 2.6, "n": 10, "band": "arch", "ground": false},
	{"r": 5.0, "t": 2.0, "z": 1.4, "d": 2.4, "n": 8, "band": "arch", "ground": false},
]

## (T-192) The Main Street fabric pins: the frontage-row walk bands (x span
## Clark → Duff; the Main and 5th centroid bands — the §1.7 L2 rows), the
## furniture pitch and the blade typology.
const FABRIC_ROW_X := Vector2(2752.0, 3292.0)
const FABRIC_MAIN_Z := Vector2(-286.0, -236.0)
const FABRIC_FIFTH_Z := Vector2(-372.0, -322.0)
const FABRIC_CORNICETAIL := 0.6 ## The cornice band's proud margin per side.
const FABRIC_LAMP_PITCH := 32.0 ## The lamp run's along-street pitch.
const FABRIC_LAMP_INSET := 24.0 ## The run's inset from the span ends.
const FABRIC_LAMP_CLEAR := 16.0 ## The crossing-clearance radius.
const FABRIC_LAMP_OFFSET := 6.9 ## Main half-width 5.5 + the 1.4 sidewalk margin.
## The bar-sign tokens (the T-176 café-token law): matched lowercase against
## the pack building names in the frontage window.
const FABRIC_BAR_TOKENS: Array[String] = ["whiskey river", "mary jane"]


## Builds the three downtown heroes found in this chunk — the bandshell
## (chunk (13,−2), the placeholder-slot carrier) and the civic pair (the
## authored massing slots in chunks (10,−2) / (11,−2)). Same law as the
## T-191 builds: render (one rotated-box MultiMesh per hero via the shared
## mount), collision (the hero's own shapes ride the chunk's placeholder
## body — same slot, same layer-1 `world` class), ground-record tops, the
## roof-crumb host, the retained part record. No-op for every other chunk.
func _build_downtown_heroes(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var shell_found := false
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) == BANDSHELL_SLOT_ID:
			shell_found = true
			break
	var hall_slot: Dictionary = {}
	var municipal_slot: Dictionary = {}
	for m: Dictionary in chunk.get("massing", []):
		var mid := str(m.get("id", ""))
		if mid == CITY_HALL_HERO_ID:
			hall_slot = m
		elif mid == MUNICIPAL_HERO_ID:
			municipal_slot = m
	if shell_found:
		var root := Node3D.new()
		root.name = "HeroBandshell"
		chunk_root.add_child(root)
		var body := chunk_body
		if body == null:
			body = StaticBody3D.new()
			body.name = "Placeholders"
			body.collision_layer = 1 ## world
			body.collision_mask = 0
			chunk_root.add_child(body)
		_mount_complex_hero_boxes(root, body, center, _bandshell_boxes(BSHELL_CENTER),
				bandshell_hero_parts, "bandshell", "Boxes", DOWNTOWN_BANDS)
		## The arch crown: the game-native perch this swap files (the §1.7
		## GAME-NATIVE line — the superseded pier-top reads retire).
		_hero_roof_tops[BANDSHELL_SLOT_ID] = Vector3(
				BSHELL_CENTER.x, BSHELL_APEX, BSHELL_CENTER.y - 5.2)
	if not hall_slot.is_empty():
		_row_commit(chunk_root, center, "CityHall", CITY_HALL_HERO_ID,
				_cityhall_boxes(Vector2(float(hall_slot["p"][0]),
						float(hall_slot["p"][2]))),
				Vector3(float(hall_slot["p"][0]),
						float(hall_slot["p"][1]) + float(hall_slot["s"][1]) * 0.5,
						float(hall_slot["p"][2])), chunk_body,
				[] as Array[Dictionary], civic_hero_parts, DOWNTOWN_BANDS)
	if not municipal_slot.is_empty():
		_row_commit(chunk_root, center, "Municipal", MUNICIPAL_HERO_ID,
				_municipal_boxes(Vector2(float(municipal_slot["p"][0]),
						float(municipal_slot["p"][2]))),
				Vector3(float(municipal_slot["p"][0]),
						float(municipal_slot["p"][1]) + float(municipal_slot["s"][1]) * 0.5,
						float(municipal_slot["p"][2])), chunk_body,
				[] as Array[Dictionary], civic_hero_parts, DOWNTOWN_BANDS)


## The bandshell hero's box schedule in WORLD-LOCAL coordinates (pack-local —
## the world node IS the pack frame; +z offsets run SOUTH toward the stage
## neck). The stage deck + floor, the pier pair with their caps and grille
## windows, the four nested front arch rings, the two rear profile rings and
## the low rear annex — the OSM footprint's 25.4 × 14.6 filled by the photo
## proportions. The arch chords ride rotated radial bases (the T-191
## statue-lean law); every chord ground-files so the arch crown walks.
func _bandshell_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base := BSHELL_STAGE_TOP
	## --- the stage: the wide north block + into the neck ---------------------
	out.append({"band": "pier_brick", "basis": Basis(),
			"p": Vector3(c.x, 0.6, c.y - 2.3),
			"s": Vector3(25.4, 1.2, 9.2), "collide": true, "ground": true})
	out.append({"band": "stage_floor", "basis": Basis(),
			"p": Vector3(c.x, 1.26, c.y - 2.3),
			"s": Vector3(23.0, 0.12, 8.0), "collide": false, "ground": false})
	## --- the pier pair (the front corners) + caps + grille windows -----------
	for side: float in [-1.0, 1.0]:
		out.append({"band": "pier_brick", "basis": Basis(),
				"p": Vector3(c.x + side * 10.6, base + 3.0, c.y - 5.2),
				"s": Vector3(2.8, 6.0, 3.6), "collide": true, "ground": true})
		out.append({"band": "cornice_stone", "basis": Basis(),
				"p": Vector3(c.x + side * 10.6, BSHELL_PIER_TOP + 0.15, c.y - 5.2),
				"s": Vector3(3.2, 0.3, 4.0), "collide": false, "ground": false})
		out.append({"band": "grille", "basis": Basis(),
				"p": Vector3(c.x + side * 10.6, 4.6, c.y - 7.06),
				"s": Vector3(1.7, 2.5, 0.16), "collide": false, "ground": false})
	## --- the arch rings (front to back; the nested scallop + the profile) ----
	for ring: Dictionary in BSHELL_RINGS:
		var r := float(ring["r"])
		var t := float(ring["t"])
		var n := int(ring["n"])
		var ring_ground := bool(ring["ground"])
		for k in n:
			var a0 := PI * float(k) / float(n)
			var a1 := PI * float(k + 1) / float(n)
			var am := (a0 + a1) * 0.5
			var chord := 2.0 * r * sin(PI / (2.0 * float(n))) + 0.4
			var sx := sin(am)
			var cx := cos(am)
			## The T-191 statue-lean law: the basis is the PURE rotation
			## (tangent × radial × depth, unit columns), the size rides `s`
			## in that rotated frame — the mount scales, collides and files
			## from `s`, never from the basis.
			out.append({
				"band": str(ring["band"]),
				"basis": Basis(Vector3(sx, cx, 0.0), Vector3(-cx, sx, 0.0),
						Vector3(0.0, 0.0, 1.0)),
				"p": Vector3(c.x - r * cx, base + r * sx, c.y + float(ring["z"])),
				"s": Vector3(chord, t, float(ring["d"])),
				"collide": true, "ground": ring_ground,
			})
	## --- the rear annex (the south neck's low mass) ---------------------------
	out.append({"band": "backstage", "basis": Basis(),
			"p": Vector3(c.x, 1.5, c.y + 5.0),
			"s": Vector3(11.3, 3.0, 5.4), "collide": true, "ground": true})
	return out


## The City Hall hero's box schedule: the slot envelope EXACT (82.3 × 14 ×
## 78.5 at the bake slot's center and color), the cornice band, and the
## photo-02 entry hint on the EAST face (Clark Ave frontage): the stone
## surround, the carved cartouche panel above, the dark door, the steps.
func _cityhall_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ex := c.x + 41.15 ## The east face.
	_add_row_box(out, "civic_brick", Vector3(c.x, 7.0, c.y),
			Vector3(82.3, 14.0, 78.5), true, true)
	_add_row_box(out, "cornice_stone", Vector3(c.x, 13.55, c.y),
			Vector3(83.5, 0.9, 79.7), true, false)
	_add_row_box(out, "cartouche_stone", Vector3(ex + 0.25, 2.9, c.y),
			Vector3(0.5, 5.8, 9.0), false, false) ## The entry surround.
	_add_row_box(out, "cartouche_stone", Vector3(ex + 0.17, 6.6, c.y),
			Vector3(0.34, 2.0, 4.4), false, false) ## The carved panel.
	_add_row_box(out, "civic_door", Vector3(ex + 0.15, 1.5, c.y),
			Vector3(0.3, 3.0, 2.4), false, false)
	_add_row_box(out, "cartouche_stone", Vector3(ex + 1.45, 0.22, c.y),
			Vector3(4.2, 0.44, 7.0), true, false) ## The steps.
	return out


## The Municipal Building hero's box schedule: the slot envelope EXACT (26.7
## × 11 × 25.3 at the bake slot's center and color), the cornice band, and
## the photo-02 cartouche entry on the WEST face (Kellogg frontage) — the
## photo building itself: surround, the carved panel high under the cornice,
## door, steps.
func _municipal_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wx := c.x - 13.35 ## The west face.
	_add_row_box(out, "civic_brick_dark", Vector3(c.x, 5.5, c.y),
			Vector3(26.7, 11.0, 25.3), true, true)
	_add_row_box(out, "cornice_stone", Vector3(c.x, 10.6, c.y),
			Vector3(27.7, 0.8, 26.3), true, false)
	_add_row_box(out, "cartouche_stone", Vector3(wx - 0.25, 3.0, c.y),
			Vector3(0.5, 6.0, 6.5), false, false) ## The entry surround.
	_add_row_box(out, "cartouche_stone", Vector3(wx - 0.2, 7.0, c.y),
			Vector3(0.4, 1.8, 3.4), false, false) ## The carved panel.
	_add_row_box(out, "civic_door", Vector3(wx - 0.15, 1.4, c.y),
			Vector3(0.3, 2.8, 2.2), false, false)
	_add_row_box(out, "cartouche_stone", Vector3(wx - 1.25, 0.3, c.y),
			Vector3(3.4, 0.6, 5.0), true, false) ## The steps.
	return out


## (T-192) The frontage-row walk, run while each chunk's JSON is in hand:
## every authored downtown massing slot whose center sits in the Main or 5th
## frontage bands (the §1.7 L2 rows, Clark → Duff) joins the fabric's slot
## list — the cornice hints ride these slots' own dims in step 3.
func _collect_fabric_row_slots(chunk: Dictionary) -> void:
	for m: Dictionary in chunk.get("massing", []):
		if not bool(m.get("a", false)) or _is_hero_massing(m):
			continue
		if str(m.get("d", "")) != "downtown":
			continue
		var x := float(m["p"][0])
		var z := float(m["p"][2])
		if x < FABRIC_ROW_X.x or x > FABRIC_ROW_X.y:
			continue
		if (z >= FABRIC_MAIN_Z.x and z <= FABRIC_MAIN_Z.y) \
				or (z >= FABRIC_FIFTH_Z.x and z <= FABRIC_FIFTH_Z.y):
			_fabric_row_slots.append({
				"id": str(m.get("id", "")),
				"p": Vector3(x, float(m["p"][1]), z),
				"s": Vector3(float(m["s"][0]), float(m["s"][1]), float(m["s"][2])),
			})


## The Main Street fabric (step 3): the frontage cornice hints, the maroon
## street-furniture run along Main's sidewalks (poles, gooseneck arms,
## shades, banner brackets, the blue banner slabs) and the neon blade sign
## seeds on the row's named bar venues. Families under `DowntownFabric/`
## (one MultiMesh per band family + one layer-1 StaticBody carrying the
## pole colliders), the part record retained. Zero RNG of any stream.
func _build_downtown_fabric() -> void:
	var root := Node3D.new()
	root.name = "DowntownFabric"
	add_child(root)
	## --- the cornice hints on the pinned frontage rows -----------------------
	var cornices: Array[Transform3D] = []
	for i in _fabric_row_slots.size():
		var slot: Dictionary = _fabric_row_slots[i]
		var p: Vector3 = slot["p"]
		var s: Vector3 = slot["s"]
		var h := 0.8 if i % 2 == 0 else 1.2
		var top := p.y + s.y * 0.5
		cornices.append(Transform3D(
				Basis.from_scale(Vector3(s.x + FABRIC_CORNICETAIL, h,
						s.z + FABRIC_CORNICETAIL)),
				Vector3(p.x, top - h * 0.5, p.z)))
		fabric_parts.append({
			"hero": "fabric", "band": "cornice",
			"p": Vector3(p.x, top - h * 0.5, p.z),
			"s": Vector3(s.x + FABRIC_CORNICETAIL, h, s.z + FABRIC_CORNICETAIL),
			"color": CIVIC_CORNICESTONE, "collide": true, "mesh": false,
		})
	## --- the maroon furniture run along Main ---------------------------------
	var main_pts := _fabric_main_points()
	var cross_xs := _fabric_cross_xs(main_pts)
	var poles: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	var shades: Array[Transform3D] = []
	var brackets: Array[Transform3D] = []
	var banners: Array[Transform3D] = []
	var run_len := 0.0
	for i in main_pts.size() - 1:
		run_len += main_pts[i].distance_to(main_pts[i + 1])
	var s_pos := FABRIC_LAMP_INSET
	while s_pos <= run_len - FABRIC_LAMP_INSET:
		var lamp_at := _fabric_point_at(main_pts, s_pos)
		var skip := false
		for cx: float in cross_xs:
			if absf(lamp_at.x - cx) < FABRIC_LAMP_CLEAR:
				skip = true
				break
		if not skip:
			var side := 1.0 if fmod(s_pos / FABRIC_LAMP_PITCH, 2.0) < 1.0 else -1.0
			var lamp_z := lamp_at.y + side * FABRIC_LAMP_OFFSET
			var to_street := -side ## The arm/shade aim at the centerline.
			poles.append(Transform3D(
					Basis.from_scale(Vector3(0.22, 5.0, 0.22)),
					Vector3(lamp_at.x, 2.5, lamp_z)))
			arms.append(Transform3D(
					Basis.from_scale(Vector3(0.14, 0.14, 1.5)),
					Vector3(lamp_at.x, 4.9, lamp_z + to_street * 0.75)))
			shades.append(Transform3D(
					Basis.from_scale(Vector3(0.55, 0.28, 0.55)),
					Vector3(lamp_at.x, 4.75, lamp_z + to_street * 1.5)))
			for by: float in [3.8, 3.0]:
				brackets.append(Transform3D(
						Basis.from_scale(Vector3(0.9, 0.08, 0.08)),
						Vector3(lamp_at.x, by, lamp_z)))
			banners.append(Transform3D(
					Basis.from_scale(Vector3(0.95, 1.5, 0.06)),
					Vector3(lamp_at.x, 3.4, lamp_z)))
			fabric_parts.append({
				"hero": "fabric", "band": "lamp",
				"p": Vector3(lamp_at.x, 2.5, lamp_z),
				"s": Vector3(0.22, 5.0, 0.22),
				"color": FURNITURE_MAROON, "collide": true, "mesh": false,
			})
			fabric_parts.append({
				"hero": "fabric", "band": "lamp_arm",
				"p": Vector3(lamp_at.x, 4.9, lamp_z + to_street * 0.75),
				"s": Vector3(0.14, 0.14, 1.5),
				"color": FURNITURE_MAROON, "collide": false, "mesh": false,
			})
			fabric_parts.append({
				"hero": "fabric", "band": "lamp_shade",
				"p": Vector3(lamp_at.x, 4.75, lamp_z + to_street * 1.5),
				"s": Vector3(0.55, 0.28, 0.55),
				"color": FURNITURE_MAROON, "collide": false, "mesh": false,
			})
			for by2: float in [3.8, 3.0]:
				fabric_parts.append({
					"hero": "fabric", "band": "banner_arm",
					"p": Vector3(lamp_at.x, by2, lamp_z),
					"s": Vector3(0.9, 0.08, 0.08),
					"color": FURNITURE_MAROON, "collide": false, "mesh": false,
				})
			fabric_parts.append({
				"hero": "fabric", "band": "banner",
				"p": Vector3(lamp_at.x, 3.4, lamp_z),
				"s": Vector3(0.95, 1.5, 0.06),
				"color": BANNER_BLUE, "collide": false, "mesh": false,
			})
		s_pos += FABRIC_LAMP_PITCH
	## --- the neon blade sign seeds (the bar venues of the row) ---------------
	var blades: Array[Transform3D] = []
	var neons: Array[Transform3D] = []
	for b: Dictionary in AmesDataPack.buildings():
		var nm := str(b.get("name", "")).to_lower()
		var hit := false
		for tok: String in FABRIC_BAR_TOKENS:
			if nm.contains(tok):
				hit = true
				break
		if not hit:
			continue
		var bc: Array = b["centroid"]
		var bb: Array = b["bbox_m"]
		var bx := float(bc[0])
		var bz := float(bc[1])
		if bx < FABRIC_ROW_X.x or bx > FABRIC_ROW_X.y \
				or bz < -300.0 or bz > -220.0:
			continue
		var mz := _fabric_main_z_at(main_pts, bx)
		if mz == INF:
			continue
		## The blade hangs on the Main-facing facade, projecting over the
		## sidewalk so it reads along the street (the photo-07 read). North
		## of Main (bz < mz) the SOUTH face fronts the street and the blade
		## projects south (+z); south of Main it mirrors.
		var proj := 1.0 if bz < mz else -1.0
		var half := float(bb[1]) * 0.5
		var facade_z := bz + half if bz < mz else bz - half
		var blade_z := facade_z + proj * 0.75
		blades.append(Transform3D(
				Basis.from_scale(Vector3(0.3, 3.6, 1.15)),
				Vector3(bx, 5.6, blade_z)))
		for nx: float in [-0.19, 0.19]:
			neons.append(Transform3D(
					Basis.from_scale(Vector3(0.06, 3.0, 0.75)),
					Vector3(bx + nx, 5.5, blade_z)))
		fabric_parts.append({
			"hero": "fabric", "band": "blade",
			"p": Vector3(bx, 5.6, blade_z),
			"s": Vector3(0.3, 3.6, 1.15),
			"color": BLADE_BOARD, "collide": false, "mesh": false,
		})
		for nx2: float in [-0.19, 0.19]:
			fabric_parts.append({
				"hero": "fabric", "band": "blade_neon",
				"p": Vector3(bx + nx2, 5.5, blade_z),
				"s": Vector3(0.06, 3.0, 0.75),
				"color": BLADE_NEON, "collide": false, "mesh": false,
			})
	## --- the blade tops walk (the game-native perch line) --------------------
	var tiles: Dictionary = {}
	var bytes := 0
	for part: Dictionary in fabric_parts:
		if str(part["band"]) != "blade":
			continue
		var gp: Vector3 = part["p"]
		var gs: Vector3 = part["s"]
		bytes += _file_ground_box(tiles, [gp.x, gp.y, gp.z], [gs.x, gs.y, gs.z])
	for key: Vector2i in tiles:
		var rec: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = rec.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		rec["ground"] = ground
		_chunks[key] = rec
	_buffer_bytes += bytes
	## --- the families ---------------------------------------------------------
	var body := StaticBody3D.new()
	body.name = "Furniture"
	body.collision_layer = 1 ## world
	body.collision_mask = 0
	root.add_child(body)
	for part2: Dictionary in fabric_parts:
		if not bool(part2["collide"]):
			continue
		var fp: Vector3 = part2["p"]
		var fs: Vector3 = part2["s"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = fs
		shape.shape = box
		shape.position = fp
		body.add_child(shape)
	_spawn_corner_family(root, "Cornices", cornices, CIVIC_CORNICESTONE)
	_spawn_corner_family(root, "LampPoles", poles, FURNITURE_MAROON)
	_spawn_corner_family(root, "LampArms", arms, FURNITURE_MAROON)
	_spawn_corner_family(root, "LampShades", shades, FURNITURE_MAROON)
	_spawn_corner_family(root, "BannerBrackets", brackets, FURNITURE_MAROON)
	_spawn_corner_family(root, "Banners", banners, BANNER_BLUE)
	_spawn_corner_family(root, "BladeBoards", blades, BLADE_BOARD)
	_spawn_corner_family(root, "BladeNeons", neons, BLADE_NEON)


## The Main Street downtown polyline (pack-derived): every Main Street point
## inside the fabric x span, sorted west → east, deduplicated.
func _fabric_main_points() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for street: Dictionary in AmesDataPack.streets():
		if str(street.get("name", "")) != "Main Street":
			continue
		for q: Variant in street.get("points", []):
			var v := Vector2(float((q as Array)[0]), float((q as Array)[1]))
			if v.x >= FABRIC_ROW_X.x and v.x <= FABRIC_ROW_X.y:
				pts.append(v)
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	for p: Vector2 in pts:
		if out.is_empty() or out.back().distance_to(p) > 0.5:
			out.append(p)
	return out


## The downtown crossing x positions (pack-derived): every non-Main street
## point inside the fabric window near Main's z band — the walk skips lamp
## positions within `FABRIC_LAMP_CLEAR` of any of these.
func _fabric_cross_xs(main_pts: Array[Vector2]) -> Array[float]:
	var main_z := 0.0
	if not main_pts.is_empty():
		for p: Vector2 in main_pts:
			main_z += p.y
		main_z /= float(main_pts.size())
	var xs: Array[float] = []
	for street: Dictionary in AmesDataPack.streets():
		if str(street.get("name", "")) == "Main Street":
			continue
		for q: Variant in street.get("points", []):
			var v := Vector2(float((q as Array)[0]), float((q as Array)[1]))
			if v.x >= FABRIC_ROW_X.x - 5.0 and v.x <= FABRIC_ROW_X.y + 5.0 \
					and absf(v.y - main_z) < 25.0:
				xs.append(v.x)
	xs.sort()
	return xs


## The polyline position at arc length `s` (west → east).
func _fabric_point_at(pts: Array[Vector2], s: float) -> Vector2:
	var acc := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= s:
			var t := (s - acc) / maxf(seg, 0.001)
			return pts[i].lerp(pts[i + 1], t)
		acc += seg
	return pts.back() if not pts.is_empty() else Vector2.ZERO


## Main's centerline z at the given x (nearest polyline point's z; INF when
## the walk is empty).
func _fabric_main_z_at(pts: Array[Vector2], x: float) -> float:
	var best := INF
	var best_d := INF
	for p: Vector2 in pts:
		var d := absf(p.x - x)
		if d < best_d:
			best_d = d
			best = p.y
	return best


## --- T-193 the civic water tanks (the AMES diamond in the sky) ---------------
## The town's sky-level signature — the city's municipal bulb-on-stem pair
## (LANDMARKS T8: BRET the north-skyline tank + one of the "two others" on
## the east side), swapping the T-175 placeholder slots 1:1 on the T-186 law.
## The bake ids `city_water_tank_north`/`city_water_tank_east` are the baker's
## own T8 stand-ins (LANDMARKS T8's "survey-anchored approximations"), NOT
## manifest `heroes` — placeholder-only slots like the bandshell's — so the
## skip rides `_row_superseded_placeholder` alone; the two heroes supersede
## the slots' stem/bulb/cap placeholder stacks (chunk (10,−5) north, (13,2)
## east) through the T-190 Marston flow.
##
## The silhouette is `images/misc/02` (the dusk full tank) read at massing
## level: the concrete pedestal stem, the mushroom shoulder flaring out to
## the bulb's diameter, the tall white bulb drum carrying the green/blue
## banding — the photo's stripe pairs at both edges of the white field, blue
## outermost — the shallow roof dome with its perimeter railing ring, and the
## AMES diamond logo AS PAINTED GEOMETRY (the ticket's scope: the diamond
## SHAPE + the banding land now; the letterforms and the welcome script are
## R4 text — a dark diamond reads unmistakably Ames from 200 m without a
## single glyph). The diamond faces the town (the north tank's logo looks
## south down its own skyline, the east tank's looks west — the game-native
## read; the photos show one face each). The stack keeps the slot's own
## spans EXACTLY (the T-190 law): stem part 0..16, bulb part 16..28, cap
## part 28..30, bulb Ø20 = the slot's 20 m box — the hero re-reads the same
## spans as the photo's shapes instead of gray boxes, with the stem widened
## to the photo-02 ratio (bulb dia ≈ 3× stem dia; the slot's 3 m placeholder
## box is the skinny T-175 guess).
##
## NOT landable (the ticket's own line): the superseded slot's placeholder
## pass used to file walkable tops at 16/28/30 — the swap retires them and
## the hero files NO ground record and NO roof crumb; the bulb crown stays
## honest to the photos (dome + railing, no flat perch), solid collision
## only. Palette: NO survey hex exists (photo 01 is a blue duotone print —
## every pixel sits near hue 215°; photo 02 is dusk-cast) and the IMAGE_INDEX
## cluster note pins "green/blue" only, so the colored bands are held by HUE
## laws (the T-190 dark-law precedent): the diamond + green banding read
## green (hue 90..170°), the blue banding reads blue (hue 200..250°), the
## white field reads white (luminance ≥ 0.85, near-neutral), the railing
## dark. Like every hero: pure pack-derived geometry, zero RNG of any
## stream — a rebuild reproduces every transform byte-identically — and the
## part record is retained for the gates (headless runs cannot read
## MultiMesh instances back).

const CITY_TANK_NORTH_HERO_ID := "city_water_tank_north"
const CITY_TANK_EAST_HERO_ID := "city_water_tank_east"

## (T-193) The pinned palette. No survey hex (see the section header) — the
## constants carry this ticket's own pinned literals, the scenario re-pins
## the same values and holds the hue/luminance laws that make them
## green/blue rather than arbitrary.
const TANK_DIAMOND_GREEN := Color(0.075, 0.302, 0.231) ## #134D3B the diamond's dark green (hue ≈ 161°).
const TANK_BAND_GREEN := Color(0.118, 0.376, 0.263) ## #1E6043 the green stripes (hue ≈ 153°).
const TANK_BAND_BLUE := Color(0.157, 0.271, 0.447) ## #284572 the blue stripes (hue ≈ 216°).
const TANK_BULB_WHITE := Color(0.937, 0.933, 0.91) ## #EFEEE8 the bulb's painted field (the town's white-tank convention, warmed a step off Marston's #EDEDEA).
const TANK_BULB_SHADE := Color(0.847, 0.843, 0.816) ## #D8D7D0 the shoulder's shade (the curved read).
const TANK_STEM_CONCRETE := Color(0.655, 0.647, 0.635) ## #A7A5A2 the pedestal's concrete gray.
const TANK_RAILING := Color(0.32, 0.33, 0.32) ## Dark law: luminance ≤ 0.45 (the photo's dark railing band).

## The band -> color table (the record and the render share this one mapping).
const TANK_BANDS: Dictionary = {
	"stem": TANK_STEM_CONCRETE,
	"skirt": TANK_BULB_SHADE,
	"drum": TANK_BULB_WHITE,
	"band_green": TANK_BAND_GREEN,
	"band_blue": TANK_BAND_BLUE,
	"dome": TANK_BULB_WHITE,
	"railing": TANK_RAILING,
	"diamond": TANK_DIAMOND_GREEN,
}

## (T-193) The pinned dims (m) — the slot stack kept EXACTLY where the bake
## settled it (stem 0..16, bulb 16..28, cap 28..30; the bulb Ø20 = the slot
## bulb's 20 m box), the shapes re-read from photo 02.
const TANK_TOTAL := 30.0 ## The slot cap part's top — the stack's own total.
const TANK_STEM_TOP := 16.0 ## The slot stem part's top = the bulb part's bottom.
const TANK_BULB_TOP := 28.0 ## The slot bulb part's top = the cap part's bottom.
const TANK_BULB_RADIUS := 10.0 ## The slot bulb's 20 m box → the round drum.
const TANK_STEM_RADIUS := 3.3 ## Photo-02's ratio: bulb dia ≈ 3× stem dia (20 ≈ 3 × 6.6).
const TANK_SKIRT_TOP := 17.2 ## The mushroom shoulder closes 1.2 m above the stem top.
const TANK_BAND_RADIUS := 10.09 ## The stripes ride proud of the drum wall.
const TANK_BAND_H := 0.6 ## Each stripe's height.
const TANK_DIAMOND_T := 0.07 ## The diamond's proud thickness.
const TANK_DIAMOND_DIAG := 10.0 ## The on-point square's diagonals (photo-02's ≈ half the bulb dia).
const TANK_DIAMOND_STANDOFF := 0.12 ## The diamond's center radius beyond the wall (face ≈ 10.16).
const TANK_DIAMOND_Y := 22.6 ## The white field's mid (18.4..26.8 between the stripe pairs).
const TANK_RAILING_POSTS := 16 ## The dome rim's post count (photo-02's railing line).
## The stripe centers derived from the skirt line and the bulb top: bottom
## pair 17.2..18.4 (blue inner at the skirt seam, green above), top pair
## 26.8..28.0 (green below, blue at the roof edge) — photo-02's mirrored
## pairs, blue outermost at both extremities.
const TANK_BAND_BLUE_LO_Y := 17.5 ## Bottom blue stripe center (17.2..17.8).
const TANK_BAND_GREEN_LO_Y := 18.1 ## Bottom green stripe center (17.8..18.4).
const TANK_BAND_GREEN_HI_Y := 27.1 ## Top green stripe center (26.8..27.4).
const TANK_BAND_BLUE_HI_Y := 27.7 ## Top blue stripe center (27.4..28.0).


func _civic_tank_band_color(band: String) -> Color:
	return TANK_BANDS.get(band, TANK_BULB_WHITE)


## Builds the heroes found in this chunk — chunk (10,−5) carries the north
## tank's slot, chunk (13,2) the east tank's. No-op elsewhere.
func _build_civic_tank_heroes(chunk_root: Node3D, chunk: Dictionary,
		center: Vector3, chunk_body: StaticBody3D) -> void:
	for spec: Dictionary in [
		{"id": CITY_TANK_NORTH_HERO_ID, "hero": "civic_tank_north", "facing": "south"},
		{"id": CITY_TANK_EAST_HERO_ID, "hero": "civic_tank_east", "facing": "west"},
	]:
		var c := Vector2.ZERO
		var found := false
		for ph: Dictionary in chunk.get("placeholders", []):
			if str(ph.get("id", "")) == str(spec["id"]) \
					and str(ph.get("part", "")) == "bulb":
				c = Vector2(float(ph["p"][0]), float(ph["p"][2]))
				found = true
				break
		if not found:
			continue ## Not this chunk's slot.
		_build_one_civic_tank(chunk_root, center, chunk_body, spec, c)


## One tank's mount (the T-190 flow): render — the diamond as one rotated
## box in a chunk-local MultiMesh (the on-point square reads at any distance
## the drum does; real basis on the box path) and the round families as
## named cylinder meshes; collision — the hero's own convexes ride the
## chunk's placeholder body, same slot, same layer-1 `world` class (the
## stem, shoulder, drum and dome are solid; the proud stripes, railing and
## diamond stay visual-only, the drum's convex is the wall behind them);
## ground record — NOTHING (the not-landable law: the retired slot's 16/28/30
## walk answers stay retired); roof crumb — none (the slot never filed one —
## the tanks are not manifest heroes); the retained part record for the
## gates.
func _build_one_civic_tank(chunk_root: Node3D, center: Vector3,
		chunk_body: StaticBody3D, spec: Dictionary, c: Vector2) -> void:
	var boxes := _civic_tank_diamond_boxes(c, str(spec["facing"]))
	var extras := _civic_tank_extras(c)
	var root := Node3D.new()
	root.name = "HeroCivicTank%s" % str(spec["hero"]).replace("civic_tank_", "").capitalize()
	chunk_root.add_child(root)
	var mm := _new_multimesh(boxes.size())
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var basis: Basis = b["basis"]
		var bp: Vector3 = b["p"]
		var bs: Vector3 = b["s"]
		mm.set_instance_transform(i, Transform3D(basis * Basis.from_scale(bs),
				bp - center))
		mm.set_instance_color(i, _civic_tank_band_color(str(b["band"])))
		var ab: Array = _complex_box_aabb(basis, bp, bs)
		lo = (ab[0] as Vector3).min(lo)
		hi = (ab[1] as Vector3).max(hi)
	mm.custom_aabb = AABB(lo - center - Vector3.ONE * 2.0, (hi - lo) + Vector3.ONE * 4.0)
	var mm_node := MultiMeshInstance3D.new()
	mm_node.name = "Boxes"
	mm_node.multimesh = mm
	root.add_child(mm_node)
	## Collision: the chunk's placeholder body (created when the chunk had no
	## other entries — kept for the tank chunks' case).
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
		var basis2: Basis = b2["basis"]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b2["s"]
		shape.shape = box
		shape.transform = Transform3D(basis2, (b2["p"] as Vector3) - center)
		body.add_child(shape)
	for e: Dictionary in extras:
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = str(e["name"])
		mesh_node.mesh = e["mesh"]
		mesh_node.position = (e["pos"] as Vector3) - center
		root.add_child(mesh_node)
		var pts: PackedVector3Array = e["convex"]
		if not pts.is_empty():
			var extra_shape := CollisionShape3D.new()
			var convex := ConvexPolygonShape3D.new()
			convex.points = pts
			extra_shape.shape = convex
			extra_shape.position = (e["pos"] as Vector3) - center
			body.add_child(extra_shape)
	## Retain the part record (world-local bands, positions, sizes, colors);
	## `mesh` marks the named round families so the gate can count the
	## diamond box against the render MM separately.
	for b3: Dictionary in boxes:
		var ab2: Array = _complex_box_aabb(b3["basis"], b3["p"], b3["s"])
		civic_tank_hero_parts.append({
			"hero": str(spec["hero"]), "band": str(b3["band"]),
			"p": ((ab2[0] as Vector3) + (ab2[1] as Vector3)) * 0.5,
			"s": (ab2[1] as Vector3) - (ab2[0] as Vector3),
			"color": _civic_tank_band_color(str(b3["band"])),
			"collide": b3["collide"], "mesh": false,
		})
	for e2: Dictionary in extras:
		civic_tank_hero_parts.append({
			"hero": str(spec["hero"]), "band": str(e2["band"]), "p": e2["pos"],
			"s": e2["size"], "color": _civic_tank_band_color(str(e2["band"])),
			"collide": not (e2["convex"] as PackedVector3Array).is_empty(),
			"mesh": true,
		})


## The box schedule in WORLD-LOCAL coordinates (pack-local — the world node
## IS the pack frame): the on-point diamond square plus the roof railing's
## perimeter posts. The diamond: `basis` the UNSCALED rotation (the T-191
## statue-lean law — the mount scales, collides and files from `s`, never
## from the basis), `s` the box size in that rotated frame (side = diag/√2
## in the logo plane, the thin proud thickness on the face normal), `p` the
## box center on the tank's town-facing wall. The north tank's logo faces
## SOUTH (+z — the town lies south of it), the east tank's faces WEST (−x);
## the in-plane 45° turn reads the square as the diamond at every distance.
## The railing: sixteen dark posts standing on the dome's rim (r 9.5,
## y 28.3..29.1) — POSTS, not a ring cylinder: a solid ring's top disc reads
## as a fat dark roof from the air (the round-1 shot review), while the
## photo's railing is a thin post line over a white dome. At skyline
## distances the posts merge into the band the photo carries.
func _civic_tank_diamond_boxes(c: Vector2, facing: String) -> Array[Dictionary]:
	var side := TANK_DIAMOND_DIAG / sqrt(2.0)
	var basis := Basis()
	var pos := Vector3.ZERO
	if facing == "south":
		basis = Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(45.0))
		pos = Vector3(c.x, TANK_DIAMOND_Y, c.y + TANK_BULB_RADIUS + TANK_DIAMOND_STANDOFF)
	else: ## "west"
		basis = Basis(Vector3(0.0, 1.0, 0.0), deg_to_rad(-90.0)) \
				* Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(45.0))
		pos = Vector3(c.x - TANK_BULB_RADIUS - TANK_DIAMOND_STANDOFF, TANK_DIAMOND_Y, c.y)
	var out: Array[Dictionary] = []
	out.append({
		"band": "diamond", "basis": basis,
		"p": pos,
		"s": Vector3(side, side, TANK_DIAMOND_T),
		"collide": false,
	})
	for k in TANK_RAILING_POSTS:
		var a := TAU * float(k) / float(TANK_RAILING_POSTS)
		out.append({
			"band": "railing", "basis": Basis(),
			"p": Vector3(c.x + cos(a) * 9.5, 28.7, c.y + sin(a) * 9.5),
			"s": Vector3(0.18, 0.8, 0.18), "collide": false,
		})
	return out


## The round families' mesh extras (world-local): the concrete stem, the
## mushroom shoulder, the white bulb drum, the four banding stripes and the
## roof dome — the railing rides the box schedule as perimeter posts (the
## round-1 shot review: a solid ring's top disc reads as a fat dark roof
## from the air). Solid convexes on stem/shoulder/drum/dome; the proud
## stripes stay visual-only.
func _civic_tank_extras(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{
			"name": "Stem", "mesh": _row_taper_mesh(TANK_STEM_RADIUS,
					TANK_STEM_RADIUS, TANK_STEM_TOP, TANK_STEM_CONCRETE),
			"pos": Vector3(c.x, TANK_STEM_TOP * 0.5, c.y), "rot": Basis(),
			"convex": _row_cylinder_convex(TANK_STEM_RADIUS, TANK_STEM_RADIUS,
					TANK_STEM_TOP, 8),
			"band": "stem",
			"size": Vector3(TANK_STEM_RADIUS * 2.0, TANK_STEM_TOP, TANK_STEM_RADIUS * 2.0),
		},
		{
			"name": "SkirtCone", "mesh": _row_taper_mesh(TANK_BULB_RADIUS,
					TANK_STEM_RADIUS, TANK_SKIRT_TOP - TANK_STEM_TOP,
					TANK_BULB_SHADE),
			"pos": Vector3(c.x, (TANK_STEM_TOP + TANK_SKIRT_TOP) * 0.5, c.y),
			"rot": Basis(),
			"convex": _row_cylinder_convex(TANK_STEM_RADIUS, TANK_BULB_RADIUS,
					TANK_SKIRT_TOP - TANK_STEM_TOP, 8),
			"band": "skirt",
			"size": Vector3(TANK_BULB_RADIUS * 2.0, TANK_SKIRT_TOP - TANK_STEM_TOP,
					TANK_BULB_RADIUS * 2.0),
		},
		{
			"name": "BulbDrum", "mesh": _row_taper_mesh(TANK_BULB_RADIUS,
					TANK_BULB_RADIUS, TANK_BULB_TOP - TANK_SKIRT_TOP,
					TANK_BULB_WHITE),
			"pos": Vector3(c.x, (TANK_SKIRT_TOP + TANK_BULB_TOP) * 0.5, c.y),
			"rot": Basis(),
			"convex": _row_cylinder_convex(TANK_BULB_RADIUS, TANK_BULB_RADIUS,
					TANK_BULB_TOP - TANK_SKIRT_TOP, 10),
			"band": "drum",
			"size": Vector3(TANK_BULB_RADIUS * 2.0, TANK_BULB_TOP - TANK_SKIRT_TOP,
					TANK_BULB_RADIUS * 2.0),
		},
		{
			"name": "BandBlueBottom", "mesh": _row_taper_mesh(TANK_BAND_RADIUS,
					TANK_BAND_RADIUS, TANK_BAND_H, TANK_BAND_BLUE),
			"pos": Vector3(c.x, TANK_BAND_BLUE_LO_Y, c.y), "rot": Basis(),
			"convex": PackedVector3Array(),
			"band": "band_blue",
			"size": Vector3(TANK_BAND_RADIUS * 2.0, TANK_BAND_H, TANK_BAND_RADIUS * 2.0),
		},
		{
			"name": "BandGreenBottom", "mesh": _row_taper_mesh(TANK_BAND_RADIUS,
					TANK_BAND_RADIUS, TANK_BAND_H, TANK_BAND_GREEN),
			"pos": Vector3(c.x, TANK_BAND_GREEN_LO_Y, c.y), "rot": Basis(),
			"convex": PackedVector3Array(),
			"band": "band_green",
			"size": Vector3(TANK_BAND_RADIUS * 2.0, TANK_BAND_H, TANK_BAND_RADIUS * 2.0),
		},
		{
			"name": "BandGreenTop", "mesh": _row_taper_mesh(TANK_BAND_RADIUS,
					TANK_BAND_RADIUS, TANK_BAND_H, TANK_BAND_GREEN),
			"pos": Vector3(c.x, TANK_BAND_GREEN_HI_Y, c.y), "rot": Basis(),
			"convex": PackedVector3Array(),
			"band": "band_green",
			"size": Vector3(TANK_BAND_RADIUS * 2.0, TANK_BAND_H, TANK_BAND_RADIUS * 2.0),
		},
		{
			"name": "BandBlueTop", "mesh": _row_taper_mesh(TANK_BAND_RADIUS,
					TANK_BAND_RADIUS, TANK_BAND_H, TANK_BAND_BLUE),
			"pos": Vector3(c.x, TANK_BAND_BLUE_HI_Y, c.y), "rot": Basis(),
			"convex": PackedVector3Array(),
			"band": "band_blue",
			"size": Vector3(TANK_BAND_RADIUS * 2.0, TANK_BAND_H, TANK_BAND_RADIUS * 2.0),
		},
		{
			"name": "RoofDome", "mesh": _row_taper_mesh(1.6, 9.3,
					TANK_TOTAL - TANK_BULB_TOP, TANK_BULB_WHITE),
			"pos": Vector3(c.x, (TANK_BULB_TOP + TANK_TOTAL) * 0.5, c.y),
			"rot": Basis(),
			"convex": _row_cylinder_convex(9.3, 1.6, TANK_TOTAL - TANK_BULB_TOP, 8),
			"band": "dome",
			"size": Vector3(18.6, TANK_TOTAL - TANK_BULB_TOP, 18.6),
		},
	]
	return out


## --- T-194 the rail corridor -------------------------------------------------
## The town's motion landmark (LANDMARKS §5 item 12), honest to the verified
## facts: the 1906 C&NW depot hero (photo `rail/08` — brick + red-tile hip +
## arched dormers + green-bracket platform canopy, NO Amtrak signage — the
## ground truth: Ames has no passenger stop, the nearest is Osceola), the
## crossbucks at the pack's 9 at-grade crossings (T-134 sign discipline,
## visual-only dressing), ONE museum wigwag at the busiest crossing (Duff —
## the ticket's optional flavor, photo `rail/09`), the right-of-way fence
## line (photo `rail/06`'s cross-section read) and THE DAILY COAL DRAG — a
## yellow SD70ACe-led consist (photo `rail/07`) running the chained south
## track on a loop-timer schedule. The train is DRESSING THAT MOVES: zero
## physics (collision_layer 0, no body — the T-185 swan scope guard), no
## event system, no traffic gating (the fence — the blocking-EVENT fork is
## deliberately out per the ticket). Ballast + tie stripes already exist in
## the bake (T-174); this section adds only what the bake does not carry.
## Zero RNG of any stream — a rebuild reproduces every transform
## byte-identically (the T-180 dress law).

const DEPOT_HERO_ID := "way/260524827" ## The 1906 depot (today's "Main Street Station") — a bake manifest hero: the massing bbox is already skipped, the placeholder stack joins the superseded set below.

## (T-194) The depot's pinned palette — §1.8's rail-corridor rows, verbatim
## where the table pins one; the trim and cap carry no survey hex (photo-08
## reads) pinned here and asserted as the scenario's own literals.
const DEPOT_BRICK := Color(0.604, 0.251, 0.188) ## #9A4030 the depot brick row.
const DEPOT_TILE := Color(0.690, 0.290, 0.204) ## #B04A34 the red tile roof row.
const DEPOT_BRACKET_GREEN := Color(0.243, 0.478, 0.353) ## #3E7A5A the canopy brackets row.
const DEPOT_TRIM := Color(0.898, 0.875, 0.808) ## #E5DFCE the photo-08 cream trim read.
const DEPOT_STEEL := Color(0.45, 0.45, 0.46) ## The bake's own canopy-steel carryover (HERO_STEEL).
const DEPOT_CAP := Color(0.30, 0.28, 0.27) ## Dark law: luminance ≤ 0.45 (the chimney cap).

## The band -> color table (the record and the render share this one mapping).
const DEPOT_BANDS: Dictionary = {
	"brick": DEPOT_BRICK,
	"tile": DEPOT_TILE,
	"trim": DEPOT_TRIM,
	"green": DEPOT_BRACKET_GREEN,
	"steel": DEPOT_STEEL,
	"cap": DEPOT_CAP,
}

## (T-194) The depot's pinned dressing dims (m) — photo-08 reads on the slot's
## own envelope (the T-190 keep-the-stack law: the wall/roof/canopy spans stay
## the slot's; the shapes re-read from the photo). The canopy moves to the
## TRACK FACE: the bake's north-face canopy contradicts the pack's own
## geometry (the Clinton main runs SOUTH of the depot footprint here — z
## −159..−163 vs the wall's −175..−195), so the platform canopy rides the
## south face, 11.95 m south of the wall center (the wall half-depth 9.95 +
## the 4.0 m canopy half-depth — over the platform, 10 m clear of the track).
const DEPOT_DORMER_OFFSET_X := 10.5 ## The dormer pair's spacing off the wall center (photo-08's flanking pair).
const DEPOT_DORMER_Z := 4.6 ## The dormers' center depth onto the south slope (front face proud of the slope).
const DEPOT_CHIMNEY_X := 14.0 ## The chimney's east offset (photo-08's center-east stack).
const DEPOT_CHIMNEY_Z := -1.5 ## The chimney rides the ridge's north side.
const DEPOT_CANOPY_POSTS := 9 ## The bracket-post run along the 85.4 m canopy.
const DEPOT_CANOPY_OUTSET := 1.24 ## The post row's inset from the canopy's outer edge.


func _depot_band_color(band: String) -> Color:
	return DEPOT_BANDS.get(band, DEPOT_BRICK)


## Builds the depot hero found in this chunk — chunk (10,−1) carries the slot.
## No-op elsewhere. The 1:1 swap (the T-190 law): the slot's wall/roof/canopy
## placeholder stack is superseded (render, collision, ground record, roof
## crumb); the hero re-reads the SAME spans as the photo's shapes. Render —
## the box schedule in a chunk-local MultiMesh plus the hip-roof loft and the
## two dormer arches as named meshes (the T-188 mesh-extra path, extended with
## a per-extra rot basis); collision — the wall, the canopy slab, the chimney
## and the hip frustum ride the chunk's placeholder body, same layer-1 `world`
## class (the dressing props stay visual-only); ground record — the wall top
## 7.0, the canopy top 4.0 at its CORRECTED south-face position and a hidden
## ridge strip filing the ridge-top 9.5 walk answer (the Farm House law: the
## sloped loft files no AABB lie); roof crumb — the ridge top; the retained
## part record for the gates.
func _build_depot_hero(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var wall := {}
	var roof := {}
	var canopy := {}
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) != DEPOT_HERO_ID:
			continue
		match str(ph.get("part", "")):
			"wall":
				wall = ph
			"roof":
				roof = ph
			"canopy":
				canopy = ph
	if wall.is_empty() or roof.is_empty() or canopy.is_empty():
		return ## Not this chunk's slot.
	var wx := float(wall["p"][0])
	var wz := float(wall["p"][2])
	var roof_base := Vector2(float(roof["s"][0]), float(roof["s"][2]))
	var canopy_s := Vector3(float(canopy["s"][0]), float(canopy["s"][1]),
			float(canopy["s"][2]))
	var boxes := _depot_boxes(wx, wz, wall["s"], roof_base, canopy_s)
	var extras := _depot_extras(wx, wz, roof_base)
	var root := Node3D.new()
	root.name = "HeroDepot"
	chunk_root.add_child(root)
	var mm := _new_multimesh(boxes.size())
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var basis: Basis = b["basis"]
		var bp: Vector3 = b["p"]
		var bs: Vector3 = b["s"]
		mm.set_instance_transform(i, Transform3D(basis * Basis.from_scale(bs),
				bp - center))
		mm.set_instance_color(i, _depot_band_color(str(b["band"])))
		var ab: Array = _complex_box_aabb(basis, bp, bs)
		lo = (ab[0] as Vector3).min(lo)
		hi = (ab[1] as Vector3).max(hi)
	mm.custom_aabb = AABB(lo - center - Vector3.ONE * 2.0, (hi - lo) + Vector3.ONE * 4.0)
	var mm_node := MultiMeshInstance3D.new()
	mm_node.name = "Boxes"
	mm_node.multimesh = mm
	root.add_child(mm_node)
	## Collision: the chunk's placeholder body (the chunk carries authored
	## massing, so the body always exists here — the null fallback kept for
	## the swap's contract).
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
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b2["s"]
		shape.shape = box
		shape.transform = Transform3D(b2["basis"] as Basis,
				(b2["p"] as Vector3) - center)
		body.add_child(shape)
	for e: Dictionary in extras:
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = str(e["name"])
		mesh_node.mesh = e["mesh"]
		mesh_node.position = (e["pos"] as Vector3) - center
		mesh_node.transform = Transform3D(e["rot"] as Basis,
				(e["pos"] as Vector3) - center)
		root.add_child(mesh_node)
		var pts: PackedVector3Array = e["convex"]
		if not pts.is_empty():
			var extra_shape := CollisionShape3D.new()
			var convex := ConvexPolygonShape3D.new()
			convex.points = pts
			extra_shape.shape = convex
			extra_shape.position = (e["pos"] as Vector3) - center
			body.add_child(extra_shape)
	## Ground record: the hero files its own true tops where the superseded
	## slot used to (the walk seam answers the hero now); the ridge strip is
	## record-only — the loft slopes file no AABB lie over the walk query.
	var tiles: Dictionary = {}
	var bytes := 0
	for b3: Dictionary in boxes:
		if not b3["ground"]:
			continue
		var gp: Vector3 = b3["p"]
		var gs: Vector3 = b3["s"]
		bytes += _file_ground_box(tiles, [gp.x, gp.y, gp.z], [gs.x, gs.y, gs.z])
	bytes += _file_ground_box(tiles, [wx, DEPOT_RIDGE_WALK_Y - 0.2, wz],
			[roof_base.x - roof_base.y, 0.4, 0.9])
	for key: Vector2i in tiles:
		var tile_record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = tile_record.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		tile_record["ground"] = ground
		_chunks[key] = tile_record
	_buffer_bytes += bytes
	## The roof-crumb host: the ridge top (the superseded bake crumb retired
	## with the slot; this one files through the same `_hero_roof_tops` map).
	_hero_roof_tops[DEPOT_HERO_ID] = Vector3(wx, DEPOT_RIDGE_WALK_Y, wz)
	## Retain the part record (world-local bands, positions, sizes, colors);
	## `mesh` marks the named families so the gate walks one record.
	for b4: Dictionary in boxes:
		var ab2: Array = _complex_box_aabb(b4["basis"], b4["p"], b4["s"])
		depot_hero_parts.append({
			"band": str(b4["band"]),
			"p": ((ab2[0] as Vector3) + (ab2[1] as Vector3)) * 0.5,
			"s": (ab2[1] as Vector3) - (ab2[0] as Vector3),
			"color": _depot_band_color(str(b4["band"])),
			"collide": b4["collide"], "mesh": false,
		})
	for e2: Dictionary in extras:
		depot_hero_parts.append({
			"band": str(e2["band"]), "p": e2["pos"], "s": e2["size"],
			"color": _depot_band_color(str(e2["band"])),
			"collide": not (e2["convex"] as PackedVector3Array).is_empty(),
			"mesh": true,
		})


## The ridge-top walk answer the ridge strip files (the loft's own top).
const DEPOT_RIDGE_WALK_Y := 9.5 ## The slot roof part's top — the stack's own total.


## The depot's box schedule in WORLD-LOCAL coordinates (pack-local — the world
## node IS the pack frame). The wall and the canopy slab keep the slot's own
## spans EXACTLY; the canopy center moves to the corrected south (track) face.
## `basis` the UNSCALED rotation (the T-191 statue-lean law), `s` the size in
## that rotated frame.
func _depot_boxes(wx: float, wz: float, wall_s: Array, roof_base: Vector2,
		canopy_s: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var canopy_z := wz + float(wall_s[2]) * 0.5 + canopy_s.z * 0.5
	## The body + the platform canopy slab (the slot's own spans).
	out.append({"band": "brick", "basis": Basis(),
			"p": Vector3(wx, float(wall_s[1]) * 0.5, wz),
			"s": Vector3(float(wall_s[0]), float(wall_s[1]), float(wall_s[2])),
			"collide": true, "ground": true})
	out.append({"band": "tile", "basis": Basis(),
			"p": Vector3(wx, canopy_s.y * 0.5 + 3.2, canopy_z), "s": canopy_s,
			"collide": true, "ground": true})
	## The bracket-post run + the green diagonal braces (photo-08's canopy
	## read) + the green fascia line on the outer edge.
	var run_a := canopy_s.x * 0.5 - 2.6
	for k in DEPOT_CANOPY_POSTS:
		var px := wx - run_a + (2.0 * run_a) * float(k) / float(DEPOT_CANOPY_POSTS - 1)
		var post_z := canopy_z + canopy_s.z * 0.5 - DEPOT_CANOPY_OUTSET
		out.append({"band": "steel", "basis": Basis(),
				"p": Vector3(px, 1.6, post_z), "s": Vector3(0.18, 3.2, 0.18),
				"collide": false, "ground": false})
		var brace := Basis(Vector3.RIGHT, deg_to_rad(-66.0))
		out.append({"band": "green", "basis": brace,
				"p": Vector3(px, 3.9, post_z - 1.57), "s": Vector3(0.22, 3.44, 0.22),
				"collide": false, "ground": false})
	out.append({"band": "green", "basis": Basis(),
			"p": Vector3(wx, 3.45, canopy_z + canopy_s.z * 0.5 + 0.075),
			"s": Vector3(canopy_s.x, 0.5, 0.15), "collide": false, "ground": false})
	## The arched dormer pair on the south (track-facing) slope: brick slabs
	## through the slope + the cream arch caps (mesh extras below).
	for side: float in [-1.0, 1.0]:
		out.append({"band": "brick", "basis": Basis(),
				"p": Vector3(wx + side * DEPOT_DORMER_OFFSET_X, 7.7,
						wz + DEPOT_DORMER_Z),
				"s": Vector3(3.6, 1.4, 1.5), "collide": false, "ground": false})
	## The brick chimney (north of the ridge, photo-08's center-east stack).
	out.append({"band": "brick", "basis": Basis(),
			"p": Vector3(wx + DEPOT_CHIMNEY_X, 10.1, wz + DEPOT_CHIMNEY_Z),
			"s": Vector3(1.6, 4.2, 1.6), "collide": true, "ground": false})
	out.append({"band": "cap", "basis": Basis(),
			"p": Vector3(wx + DEPOT_CHIMNEY_X, 12.4, wz + DEPOT_CHIMNEY_Z),
			"s": Vector3(2.0, 0.4, 2.0), "collide": false, "ground": false})
	return out


## The depot's mesh extras (world-local): the hip roof as one eave→ridge loft
## (the Farm House/Morrill path — both axes shrink, so every face is tile) on
## its solid frustum convex, and the two cream dormer arch caps (axis turned
## horizontal so the round profile faces the tracks).
func _depot_extras(wx: float, wz: float, roof_base: Vector2) -> Array[Dictionary]:
	var ridge_len := roof_base.x - roof_base.y
	var out: Array[Dictionary] = [
		{
			"name": "HipRoof", "mesh": _row_loft_mesh(roof_base,
					Vector2(ridge_len, 0.9), 2.5, DEPOT_TILE, DEPOT_TILE),
			"pos": Vector3(wx, 8.25, wz), "rot": Basis(),
			"convex": _row_frustum_convex(roof_base, Vector2(ridge_len, 0.9), 2.5),
			"band": "tile",
			"size": Vector3(roof_base.x, 2.5, roof_base.y),
		},
	]
	for side: float in [-1.0, 1.0]:
		out.append({
			"name": "DormerArch%s" % ("East" if side > 0.0 else "West"),
			"mesh": _row_taper_mesh(1.8, 1.8, 1.5, DEPOT_TRIM),
			"pos": Vector3(wx + side * DEPOT_DORMER_OFFSET_X, 8.4,
					wz + DEPOT_DORMER_Z),
			"rot": Basis(Vector3.RIGHT, deg_to_rad(90.0)),
			"convex": PackedVector3Array(),
			"band": "trim",
			"size": Vector3(3.6, 1.5, 3.6),
		})
	return out


## --- T-195 the SE grain-elevator cluster -------------------------------------
## The agricultural skyline (LANDMARKS T7, MODELING-SPECS §1.8 item 4): the
## styled hero that swaps the T-175 placeholder massing 1:1 on the T-190 law.
##
## HONESTY NOTE (the ticket's, carried verbatim — it governs any future R4
## signage decision): no photo of the actual Ames SE elevator cluster exists
## under CC — styled from Iowa-generic refs (`images/rail/10,11,12`: Hull's
## pale concrete silo bank + headhouse slab, Jefferson's box-annex read,
## Batavia's rail-side steel bins + leg tower) at ASSUMED heights — the V-30
## 30–40 m UNVERIFIED placeholder range the bake's own slot spans (silos 34,
## headhouse 38, bins 12) already sits inside. NO operator name, logo or
## brand mark is painted anywhere on it — nothing real is known to letter
## the cluster; R4 text defers to the legal pass like every facade.
##
## The slot (committed bake, chunk (13,−1), the baker's ELEVATOR_CLUSTER_POS
## survey-anchored approximation — V-30: no sourced position exists): four
## 7 × 34 × 7 silo boxes in an E–W bank, the 10 × 38 × 10 headhouse 8 m
## north of it, two 5 × 12 × 5 bins 8 m south. The hero keeps every span
## EXACTLY (the keep-the-stack law) and re-reads the SHAPES from the refs:
## the silos round to Ø7 cylinders under darker cap rims, the headhouse
## stays the box under a proud dark roof slab, the bins round to Ø5
## galvanized cylinders under cone roofs, and the Batavia typology's LEG
## TOWER joins as a visual-only dark lattice (4 posts + 5 collars + the
## crown distributor arm) against the headhouse's east wall — hero-only
## geometry, the composition member the ticket names beyond the T-175
## massing. Collision solid on the big three families (convex cylinders +
## the box, layer-1 `world` on the chunk body); ground record: the slot's
## own seven walk answers re-filed byte-identically (the walk-parity law —
## the swap changes the dress, never the seam); roof crumb: none (the slot
## never filed one — the specced silo-cap perch is a future owner ticket).

const ELEVATOR_CLUSTER_HERO_ID := "grain_elevators"

## (T-195) The pinned palette — §1.8's "Grain silos (style ref) #D9D2C4 pale"
## row verbatim for the concrete; the rest this ticket's own literals (the
## refs are photos, not hex tables — the scenario re-pins the same values
## and holds the warm/cool/dark laws that make them read).
const ELEVATOR_CONCRETE := Color(0.851, 0.824, 0.769) ## #D9D2C4 the silo bank + headhouse pale.
const ELEVATOR_CONCRETE_CAP := Color(0.784, 0.753, 0.682) ## #C8C0AE the cap rims' darker warm step.
const ELEVATOR_ROOF := Color(0.30, 0.29, 0.28) ## The headhouse roof slab — dark law: luminance ≤ 0.45.
const ELEVATOR_STEEL := Color(0.776, 0.796, 0.824) ## #C6CBD2 the bins' galvanized (cool: blue ≥ red).
const ELEVATOR_STEEL_ROOF := Color(0.651, 0.675, 0.714) ## #A6ACB6 the cones' darker galvanized.
const ELEVATOR_LEG := Color(0.34, 0.35, 0.36) ## The leg lattice — dark law: luminance ≤ 0.45.

## The band -> color table (the record and the render share this one
## mapping); closed at six — NO sign band (the honesty note's no-branding law).
const ELEVATOR_BANDS: Dictionary = {
	"concrete": ELEVATOR_CONCRETE,
	"concrete_cap": ELEVATOR_CONCRETE_CAP,
	"roof": ELEVATOR_ROOF,
	"steel": ELEVATOR_STEEL,
	"steel_roof": ELEVATOR_STEEL_ROOF,
	"leg": ELEVATOR_LEG,
}

## (T-195) The pinned dressing dims (m) — the slot's own spans are kept
## exactly; these shape the dressing INSIDE them.
const ELEVATOR_HEADHOUSE_CAP_H := 0.8 ## The proud roof slab's height.
const ELEVATOR_HEADHOUSE_CAP_PROUD := 0.15 ## Its overhang per side.
const ELEVATOR_SILO_CAP_H := 0.7 ## The cap rim ring's height at each silo top.
const ELEVATOR_SILO_CAP_PROUD := 0.06 ## The rim's proud radius past the wall.
const ELEVATOR_BIN_ROOF_H := 1.6 ## Each bin's cone roof (the wall takes the rest of the slot span).
const ELEVATOR_BIN_ROOF_TOP_R := 0.25 ## The cone's top eyelet radius.
const ELEVATOR_LEG_HALF := 0.8 ## The lattice square's half-width about the leg center.
const ELEVATOR_LEG_STANDOFF := 1.4 ## The leg center's standoff east of the headhouse east wall.
const ELEVATOR_LEG_TOP_DROP := 1.0 ## The leg tops this under the headhouse top — ABOVE the bank line, so the rail/12 mast reads in the skyline from the town side (occluded behind the silos if it stopped at their top).
const ELEVATOR_LEG_COLLARS := 5 ## The collar ring count (the braced read at distance), evenly spread over the lower leg.
const ELEVATOR_LEG_ARM_DROP := 0.6 ## The distributor arm hangs this under the leg top.
const ELEVATOR_LEG_ARM_LEN := 8.0 ## The arm's length, running alongside the headhouse wall.


func _elevator_band_color(band: String) -> Color:
	return ELEVATOR_BANDS.get(band, ELEVATOR_CONCRETE)


## Builds the elevator hero found in this chunk — chunk (13,−1) carries the
## slot. No-op elsewhere. The 1:1 swap (the T-190 law): the slot's seven
## placeholder parts are superseded (render, collision, ground record — the
## slot filed no roof crumb and files none now). Render — the headhouse box +
## roof slab + the leg tower in a chunk-local MultiMesh, the round families
## (4 silo cylinders + cap rims, 2 bin cylinders + cone roofs) as named
## meshes; collision — the silos/bins/cones as convex cylinders + the
## headhouse box on the chunk's placeholder body, same layer-1 `world` class
## (the cap rims, roof slab and leg lattice stay visual-only dressing);
## ground record — the slot's own seven boxes re-filed byte-identically (the
## walk-parity law); the retained part record for the gates.
func _build_elevator_hero(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var silos: Array[Dictionary] = []
	var bins: Array[Dictionary] = []
	var headhouse := {}
	for ph: Dictionary in chunk.get("placeholders", []):
		if str(ph.get("id", "")) != ELEVATOR_CLUSTER_HERO_ID:
			continue
		var part := {
			"p": Vector3(float(ph["p"][0]), float(ph["p"][1]), float(ph["p"][2])),
			"s": Vector3(float(ph["s"][0]), float(ph["s"][1]), float(ph["s"][2])),
		}
		match str(ph.get("part", "")):
			"silo":
				silos.append(part)
			"bin":
				bins.append(part)
			"headhouse":
				headhouse = part
	if silos.size() != 4 or bins.size() != 2 or headhouse.is_empty():
		return ## Not this chunk's slot (or the bake lost a part — the gate fails loudly).
	silos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["p"] as Vector3).x < (b["p"] as Vector3).x)
	bins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["p"] as Vector3).x < (b["p"] as Vector3).x)
	var hp: Vector3 = headhouse["p"]
	var hs: Vector3 = headhouse["s"]
	var boxes := _elevator_boxes(hp, hs)
	var extras := _elevator_extras(silos, bins)
	var root := Node3D.new()
	root.name = "HeroElevatorCluster"
	chunk_root.add_child(root)
	var mm := _new_multimesh(boxes.size())
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in boxes.size():
		var b: Dictionary = boxes[i]
		var basis: Basis = b["basis"]
		var bp: Vector3 = b["p"]
		var bs: Vector3 = b["s"]
		mm.set_instance_transform(i, Transform3D(basis * Basis.from_scale(bs),
				bp - center))
		mm.set_instance_color(i, _elevator_band_color(str(b["band"])))
		var ab: Array = _complex_box_aabb(basis, bp, bs)
		lo = (ab[0] as Vector3).min(lo)
		hi = (ab[1] as Vector3).max(hi)
	mm.custom_aabb = AABB(lo - center - Vector3.ONE * 2.0, (hi - lo) + Vector3.ONE * 4.0)
	var mm_node := MultiMeshInstance3D.new()
	mm_node.name = "Boxes"
	mm_node.multimesh = mm
	root.add_child(mm_node)
	## Collision: the chunk's placeholder body (the chunk carries authored
	## entries, so the body exists — the null fallback kept for the swap's
	## contract).
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
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b2["s"]
		shape.shape = box
		shape.transform = Transform3D(b2["basis"] as Basis,
				(b2["p"] as Vector3) - center)
		body.add_child(shape)
	for e: Dictionary in extras:
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = str(e["name"])
		mesh_node.mesh = e["mesh"]
		mesh_node.position = (e["pos"] as Vector3) - center
		root.add_child(mesh_node)
		var pts: PackedVector3Array = e["convex"]
		if not pts.is_empty():
			var extra_shape := CollisionShape3D.new()
			var convex := ConvexPolygonShape3D.new()
			convex.points = pts
			extra_shape.shape = convex
			extra_shape.position = (e["pos"] as Vector3) - center
			body.add_child(extra_shape)
	## Ground record: the slot's own seven boxes re-filed byte-identically —
	## the walk answers the T-175 massing gave (silos 34, headhouse 38, bins
	## 12) survive the swap exactly (the walk-parity law; the flag path would
	## double-file the headhouse, so the parity walk is explicit).
	var tiles: Dictionary = {}
	var bytes := 0
	for ph2: Dictionary in chunk.get("placeholders", []):
		if str(ph2.get("id", "")) != ELEVATOR_CLUSTER_HERO_ID:
			continue
		bytes += _file_ground_box(tiles, ph2["p"], ph2["s"])
	for key: Vector2i in tiles:
		var tile_record: Dictionary = _chunks.get(key, {})
		var ground: PackedFloat32Array = tile_record.get("ground", PackedFloat32Array())
		ground.append_array(PackedFloat32Array(tiles[key]))
		tile_record["ground"] = ground
		_chunks[key] = tile_record
	_buffer_bytes += bytes
	## Retain the part record (world-local bands, positions, sizes, colors);
	## `mesh` marks the named round families so the gate walks one record.
	for b3: Dictionary in boxes:
		var ab2: Array = _complex_box_aabb(b3["basis"], b3["p"], b3["s"])
		elevator_hero_parts.append({
			"band": str(b3["band"]),
			"p": ((ab2[0] as Vector3) + (ab2[1] as Vector3)) * 0.5,
			"s": (ab2[1] as Vector3) - (ab2[0] as Vector3),
			"color": _elevator_band_color(str(b3["band"])),
			"collide": b3["collide"], "mesh": false,
		})
	for e2: Dictionary in extras:
		elevator_hero_parts.append({
			"band": str(e2["band"]), "p": e2["pos"], "s": e2["size"],
			"color": _elevator_band_color(str(e2["band"])),
			"collide": not (e2["convex"] as PackedVector3Array).is_empty(),
			"mesh": true,
		})


## The box schedule in WORLD-LOCAL coordinates (pack-local — the world node
## IS the pack frame): the headhouse body keeps the slot's own box EXACTLY
## under its proud dark roof slab; the leg tower rises to a meter under the
## headhouse top — ABOVE the bank line, so the rail/12 mast reads in the
## skyline from the town side — and its posts, collars and crown arm are
## visual-only dressing (the thin-member law — the fence/crossbuck
## precedent). `basis` the UNSCALED rotation (the T-191 statue-lean law), `s`
## the size in that rotated frame.
func _elevator_boxes(hp: Vector3, hs: Vector3) -> Array[Dictionary]:
	var leg_top := hs.y - ELEVATOR_LEG_TOP_DROP
	var out: Array[Dictionary] = []
	out.append({"band": "concrete", "basis": Basis(), "p": hp, "s": hs,
			"collide": true, "ground": false})
	out.append({"band": "roof", "basis": Basis(),
			"p": Vector3(hp.x, hp.y + hs.y * 0.5 - ELEVATOR_HEADHOUSE_CAP_H * 0.5, hp.z),
			"s": Vector3(hs.x + ELEVATOR_HEADHOUSE_CAP_PROUD * 2.0,
					ELEVATOR_HEADHOUSE_CAP_H, hs.z + ELEVATOR_HEADHOUSE_CAP_PROUD * 2.0),
			"collide": false, "ground": false})
	var leg_x := hp.x + hs.x * 0.5 + ELEVATOR_LEG_STANDOFF
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			out.append({"band": "leg", "basis": Basis(),
					"p": Vector3(leg_x + sx * ELEVATOR_LEG_HALF, leg_top * 0.5,
							hp.z + sz * ELEVATOR_LEG_HALF),
					"s": Vector3(0.16, leg_top, 0.16),
					"collide": false, "ground": false})
	for k in ELEVATOR_LEG_COLLARS:
		out.append({"band": "leg", "basis": Basis(),
				"p": Vector3(leg_x, leg_top * float(k + 1)
						/ float(ELEVATOR_LEG_COLLARS + 1), hp.z),
				"s": Vector3(ELEVATOR_LEG_HALF * 2.0 + 0.3, 0.14,
						ELEVATOR_LEG_HALF * 2.0 + 0.3),
				"collide": false, "ground": false})
	out.append({"band": "leg", "basis": Basis(),
			"p": Vector3(leg_x, leg_top - ELEVATOR_LEG_ARM_DROP, hp.z),
			"s": Vector3(0.22, 0.3, ELEVATOR_LEG_ARM_LEN),
			"collide": false, "ground": false})
	return out


## The round families' mesh extras (world-local): the four Ø7 concrete silo
## cylinders + their proud cap rims, the two Ø5 galvanized bin cylinders +
## their cone roofs — the slot's own spans kept (silo 0..34, bin wall
## 0..10.4 + cone 10.4..12). Solid convexes on the walls and cones; the
## proud cap rims stay visual-only.
func _elevator_extras(silos: Array[Dictionary],
		bins: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in silos.size():
		var sp: Vector3 = silos[i]["p"]
		var ss: Vector3 = silos[i]["s"]
		var r := ss.x * 0.5
		out.append({
			"name": "Silo%d" % (i + 1),
			"mesh": _row_taper_mesh(r, r, ss.y, ELEVATOR_CONCRETE),
			"pos": sp, "rot": Basis(),
			"convex": _row_cylinder_convex(r, r, ss.y, 8),
			"band": "concrete",
			"size": Vector3(ss.x, ss.y, ss.z),
		})
		out.append({
			"name": "SiloCap%d" % (i + 1),
			"mesh": _row_taper_mesh(r + ELEVATOR_SILO_CAP_PROUD,
					r + ELEVATOR_SILO_CAP_PROUD, ELEVATOR_SILO_CAP_H,
					ELEVATOR_CONCRETE_CAP),
			"pos": Vector3(sp.x, sp.y + ss.y * 0.5 - ELEVATOR_SILO_CAP_H * 0.5, sp.z),
			"rot": Basis(), "convex": PackedVector3Array(),
			"band": "concrete_cap",
			"size": Vector3((r + ELEVATOR_SILO_CAP_PROUD) * 2.0,
					ELEVATOR_SILO_CAP_H, (r + ELEVATOR_SILO_CAP_PROUD) * 2.0),
		})
	for i in bins.size():
		var bp: Vector3 = bins[i]["p"]
		var bs: Vector3 = bins[i]["s"]
		var br := bs.x * 0.5
		var wall_h := bs.y - ELEVATOR_BIN_ROOF_H
		out.append({
			"name": "Bin%d" % (i + 1),
			"mesh": _row_taper_mesh(br, br, wall_h, ELEVATOR_STEEL),
			"pos": Vector3(bp.x, wall_h * 0.5, bp.z), "rot": Basis(),
			"convex": _row_cylinder_convex(br, br, wall_h, 8),
			"band": "steel",
			"size": Vector3(bs.x, wall_h, bs.z),
		})
		out.append({
			"name": "BinRoof%d" % (i + 1),
			"mesh": _row_taper_mesh(ELEVATOR_BIN_ROOF_TOP_R, br,
					ELEVATOR_BIN_ROOF_H, ELEVATOR_STEEL_ROOF),
			"pos": Vector3(bp.x, wall_h + ELEVATOR_BIN_ROOF_H * 0.5, bp.z),
			"rot": Basis(),
			"convex": _row_cylinder_convex(br, ELEVATOR_BIN_ROOF_TOP_R,
					ELEVATOR_BIN_ROOF_H, 8),
			"band": "steel_roof",
			"size": Vector3(bs.x, ELEVATOR_BIN_ROOF_H, bs.z),
		})
	return out


## --- T-204 Reiman Gardens: the town's south gate ----------------------------
##
## The wing roof is the silhouette (MODELING-SPECS §1.9: the conservatory is
## the L3 south-gate set piece), and QA item 1's blocks-build split is made
## STRUCTURAL here: the 59 × 88 m mass is the WHOLE "Reiman Gardens
## Conservatory" building (OSM way 180765068, h 10, ≈2,994 m² shoelace) and
## the named Hughes Conservatory glasshouse inside it is 465 m² (5,000 sq ft,
## LANDMARKS C10) — built as a DISTINCT volume in the hero's scene tree
## (`HughesGlasshouse`, 31.0 × 15.0 m of glass), never folded into the
## envelope (following the split would have built the set piece ~11×
## oversized as "Hughes").
##
## Hero-lite = the silhouette + palette + the two set pieces: the blue-glass
## envelope with the wing-form roof massing (photo 11's read — a raised
## spine with two stepped side wings each way of it, the butterfly profile),
## and the butterfly-wing ENTRANCE CANOPY over the east arrival walk (photo
## 11; LANDMARKS C10's caveat: no sourced dimension exists — MODEL-TO-LOOK,
## the spans recorded right here and marked UNVERIFIED, the V-30 law).
## Everything else at the gardens — the Christina Reiman Butterfly Wing
## building, the Mahlstede Center, Hunziker House, the maintenance ranges —
## rides the bake's own authored massing slots (the v3 pack's south strip),
## and the gardens' 73,202 m² lawn is the bake's own park flat. The vet-med
## campus and the south blocks are context mass the strip brought in.
##
## The butterfly ACCENT PROPS (photo 13's read — `butterfly.gd`) hover the
## entrance beds: count tiny, ambient only (dressing, not a system).
##
## Like every hero: pure pack/bake-derived geometry, zero RNG of any stream,
## the part records retained for the gates.

const REIMAN_HERO_ID := "way/180765068"

## The pinned conservatory geometry — the SLOT's own numbers (the bake's
## authored bbox for way/180765068: 58.7 E–W × 87.8 N–S at centroid
## (955.0, 1233.08), h 10). The hero builds at the slot's own center the
## City Hall way; the envelope dims are the QA-split whole-building truth.
const REIMAN_W := 58.7 ## E–W (m).
const REIMAN_D := 87.8 ## N–S (m).
const REIMAN_H := 10.0 ## The OSM height tag (1 level).

## The wing roof massing (photo 11, model-to-look — UNVERIFIED rise): the
## walls carry the roof at 10.0; a central spine rises to REIMAN_RIDGE over
## the N–S long axis, each side stepping down in two faceted bands (the
## butterfly profile read), the eaves returning to just over the wall top.
const REIMAN_RIDGE := 14.0 ## The spine crown (m) — a 4.0 m rise over the 58.7 m width.
const REIMAN_EAVE := 10.3 ## The outer band's crown at the eave return.
const REIMAN_INNER_RUN := 12.0 ## The steep inner band's horizontal run from the spine.
const REIMAN_ROOF_T := 0.35 ## The glass band thickness (m).
const REIMAN_SPINE_CAP_W := 1.6 ## The spine cap's width/depth (m).
const REIMAN_SPINE_CAP_T := 0.3 ## The spine cap's thickness (m).

## The Hughes glasshouse split (QA item 1, STRUCTURAL): LANDMARKS C10's
## 465 m² (5,000 sq ft) named glasshouse inside the whole building — a
## distinct volume in the hero's scene tree, 31.0 × 15.0 m of footprint
## (31.0 × 15.0 = 465.0 m² exactly) standing the full REIMAN_H interior at
## the envelope's south display range. The split is the ticket's structural
## fix: the volume exists SEPARATELY or the QA's ~11× oversize read returns.
const REIMAN_GLASSHOUSE := Vector2(31.0, 15.0) ## Footprint (m) — 465 m².
const REIMAN_GLASSHOUSE_Z := 6.9 ## The volume's center, SOUTH of the slot center (m).

## The butterfly-wing entrance canopy (photo 11; LANDMARKS C10's caveat —
## NO SOURCED DIMENSION EXISTS: model-to-look, the estimate recorded here
## and UNVERIFIED, the V-30 law). Two swept wing shells meet at a spine
## over the east arrival walk, on two posts. Estimate: span 14.2 m E–W ×
## 10.0 m N–S, eaves 4.2, spine 6.8.
const REIMAN_CANOPY_X := 993.0 ## The walk center, east of the east face (984.35).
const REIMAN_CANOPY_Z := 1233.08 ## On the envelope center line (the main bay).
const REIMAN_CANOPY_SHELL := Vector2(7.5, 10.0) ## Slope length × N–S depth (m).
const REIMAN_CANOPY_RIDGE := 6.8 ## The spine crown (m).
const REIMAN_CANOPY_EAVE := 4.2 ## The wing tips (m).
const REIMAN_CANOPY_EAVE_CLEAR := 3.6 ## The post-top underside the tips read to.
const REIMAN_CANOPY_SHELL_T := 0.25 ## The shell thickness (m).

## The butterfly accents (photo 13's read): eight hover the trial-landscape
## beds east of the conservatory — the ticket's count law (≤ 12, ambient
## only), staged as a fixed ring (zero RNG; the phases spread by fraction).
const BUTTERFLY_COUNT := 8
const BUTTERFLY_RING_CENTER := Vector2(1028.0, 1310.0) ## The entrance beds.
const BUTTERFLY_RING_R := 21.0 ## m — over the beds, clear of the walkways.
const BUTTERFLY_HOVER_Y := 1.5 ## The hover mid height (m).
const BUTTERFLY_SCENE: PackedScene = preload("res://scenes/butterfly.tscn")

## The pinned palette — §1.9's Reiman rows, verbatim.
const REIMAN_GLASS := Color(0.498, 0.659, 0.788) ## #7FA8C9 the blue glass.
const REIMAN_GLASSHOUSE_GLASS := Color(0.573, 0.722, 0.835) ## The Hughes range — one step lighter so the split reads.
const REIMAN_FRAME := Color(0.22, 0.23, 0.25) ## The mullion/spine dark steel.
const REIMAN_WALL := Color(0.62, 0.61, 0.57) ## The service ranges' warm pale metal.

## (T-204) The band -> color table (the records and the render share this
## one mapping; names unique against the stadium/hilton tables the complex
## mount consults first).
const GARDENS_BANDS: Dictionary = {
	"glass_wall": REIMAN_GLASS,
	"roof_glass": REIMAN_GLASS,
	"spine_frame": REIMAN_FRAME,
	"canopy_glass": REIMAN_GLASS,
	"canopy_frame": REIMAN_FRAME,
}


## Builds the Reiman Gardens conservatory hero into its carrier chunk — the
## chunk whose massing carries `way/180765068` (the slot's own center and
## carrier; the hero supersedes the slot 1:1 through the bake's
## HERO_BUILDING_IDS law). Render: one rotated-box MultiMesh via the complex
## mount; collision: the hero's own shapes ride the chunk's placeholder body
## (same layer-1 `world` class); ground: the envelope top + the spine ridge
## file walkable; the roof crumb at the spine crown; the retained part
## record the gates walk; and the NAMED Hughes glasshouse volume — the QA
## split made structural — hangs under the hero root as its own mesh node.
## No-op for every other chunk.
func _build_reiman_hero(chunk_root: Node3D, chunk: Dictionary, center: Vector3,
		chunk_body: StaticBody3D) -> void:
	var c := Vector2.ZERO
	var found := false
	for m: Dictionary in chunk.get("massing", []):
		if str(m.get("id", "")) != REIMAN_HERO_ID:
			continue
		c = Vector2(float(m["p"][0]), float(m["p"][2]))
		found = true
		break
	if not found:
		return ## Not this chunk's slot (or the bake lost the way — the gate fails loudly).
	var boxes := _reiman_boxes(c)
	var root := Node3D.new()
	root.name = "HeroReimanGardens"
	chunk_root.add_child(root)
	var body := chunk_body
	if body == null:
		body = StaticBody3D.new()
		body.name = "Placeholders"
		body.collision_layer = 1 ## world
		body.collision_mask = 0
		chunk_root.add_child(body)
	_mount_complex_hero_boxes(root, body, center, boxes, gardens_hero_parts,
			"reiman_gardens", "Boxes", GARDENS_BANDS)
	## The Hughes glasshouse volume (the QA split, STRUCTURAL): one named
	## mesh node — the 465 m² footprint stands distinct in the scene tree —
	## plus its own part record (`mesh: true`) so the record walk sees the
	## split. It stands INSIDE the envelope (contained; the gate asserts
	## both) and carries no collision of its own — the envelope's walls
	## already own the mass.
	var glasshouse := MeshInstance3D.new()
	var gh_mesh := BoxMesh.new()
	gh_mesh.size = Vector3(REIMAN_GLASSHOUSE.x, REIMAN_H, REIMAN_GLASSHOUSE.y)
	var gh_mat := StandardMaterial3D.new()
	gh_mat.albedo_color = REIMAN_GLASSHOUSE_GLASS
	gh_mat.roughness = 0.25
	gh_mesh.material = gh_mat
	glasshouse.name = "HughesGlasshouse"
	glasshouse.mesh = gh_mesh
	glasshouse.position = Vector3(c.x, REIMAN_H * 0.5, c.y + REIMAN_GLASSHOUSE_Z) \
			- center
	root.add_child(glasshouse)
	gardens_hero_parts.append({
		"hero": "reiman_gardens", "band": "glasshouse",
		"p": Vector3(c.x, REIMAN_H * 0.5, c.y + REIMAN_GLASSHOUSE_Z),
		"s": Vector3(REIMAN_GLASSHOUSE.x, REIMAN_H, REIMAN_GLASSHOUSE.y),
		"color": REIMAN_GLASSHOUSE_GLASS, "collide": false, "mesh": true,
	})
	## The roof crumb: one ROOF spot at the spine crown's TOP (the hero's
	## true walkable top — the superseded bbox-top pin re-anchors here; the
	## ridge strip files the same 14.3 answer in the ground record).
	_hero_roof_tops[REIMAN_HERO_ID] = Vector3(
			c.x, REIMAN_RIDGE + REIMAN_SPINE_CAP_T, c.y)


## The conservatory hero's box schedule in WORLD-LOCAL coordinates (pack
## local — the world node IS the pack frame), one entry per box:
## `{band, basis, p, s, collide, ground}` — `basis` the UNSCALED rotation
## (the pitched roof bands and the swept canopy shells), `s` the box size in
## that rotated frame, `p` the box center. The envelope is the QA-split
## WHOLE building; the roof is the wing-form massing; the canopy rides the
## east arrival walk.
func _reiman_boxes(c: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	## --- the envelope: the whole 59 × 88 building, blue glass ---------------
	_add_row_box(out, "glass_wall", Vector3(c.x, REIMAN_H * 0.5, c.y),
			Vector3(REIMAN_W, REIMAN_H, REIMAN_D), true, true)
	## The dark base mullion band (the glazed wall's frame read, grounding) —
	## INSET one hair so the envelope face stays the hero's outermost plane
	## (the T-189 apron law: a proud band would own the face the plaque
	## mounts on and float the wall-exists leg).
	_add_row_box(out, "spine_frame", Vector3(c.x, 0.6, c.y),
			Vector3(REIMAN_W - 0.1, 1.2, REIMAN_D - 0.1), false, false)
	## --- the wing roof (photo 11): spine cap + two stepped bands per side ---
	## The steep inner band runs REIMAN_INNER_RUN from the spine, dropping
	## from the ridge to the inner step; the shallow outer band carries the
	## step out to the eave return. Each band is one pitched box (rotation
	## about the N–S long axis), its slope length the hypotenuse of its run.
	var inner_drop := REIMAN_RIDGE - (REIMAN_EAVE + 1.9) ## Ridge → the inner step top.
	var inner_len := sqrt(REIMAN_INNER_RUN * REIMAN_INNER_RUN + inner_drop * inner_drop)
	var inner_pitch := atan2(inner_drop, REIMAN_INNER_RUN)
	var outer_run := REIMAN_W * 0.5 - REIMAN_INNER_RUN ## Out to the eave line.
	var outer_drop := (REIMAN_EAVE + 1.9) - REIMAN_EAVE
	var outer_len := sqrt(outer_run * outer_run + outer_drop * outer_drop)
	var outer_pitch := atan2(outer_drop, outer_run)
	for side: float in [-1.0, 1.0]:
		## Inner band: from the spine (x c) down to the inner step.
		var mid_x := c.x + side * REIMAN_INNER_RUN * 0.5
		var mid_y := REIMAN_RIDGE - inner_drop * 0.5 - REIMAN_ROOF_T * 0.25
		out.append({
			"band": "roof_glass",
			"basis": Basis(Vector3(cos(inner_pitch), -side * sin(inner_pitch), 0.0),
					Vector3(side * sin(inner_pitch), cos(inner_pitch), 0.0),
					Vector3(0.0, 0.0, 1.0)),
			"p": Vector3(mid_x, mid_y, c.y),
			"s": Vector3(inner_len, REIMAN_ROOF_T, REIMAN_D + 0.8),
			"collide": false, "ground": false,
		})
		## Outer band: from the inner step out to the eave return.
		var o_mid_x := c.x + side * (REIMAN_INNER_RUN + outer_run * 0.5)
		var o_mid_y := (REIMAN_EAVE + 1.9) - outer_drop * 0.5 - REIMAN_ROOF_T * 0.25
		out.append({
			"band": "roof_glass",
			"basis": Basis(Vector3(cos(outer_pitch), -side * sin(outer_pitch), 0.0),
					Vector3(side * sin(outer_pitch), cos(outer_pitch), 0.0),
					Vector3(0.0, 0.0, 1.0)),
			"p": Vector3(o_mid_x, o_mid_y, c.y),
			"s": Vector3(outer_len, REIMAN_ROOF_T, REIMAN_D + 0.8),
			"collide": false, "ground": false,
		})
	## The spine cap: the ridge's frame crown — the walkable ridge strip.
	_add_row_box(out, "spine_frame",
			Vector3(c.x, REIMAN_RIDGE + REIMAN_SPINE_CAP_T * 0.5, c.y),
			Vector3(REIMAN_SPINE_CAP_W, REIMAN_SPINE_CAP_T, REIMAN_D + 0.8),
			false, true)
	## --- the entrance canopy (photo 11, model-to-look): two swept wing
	## shells meeting at a spine over the east arrival walk, on two posts ---
	var shell_pitch := atan2(REIMAN_CANOPY_RIDGE - REIMAN_CANOPY_EAVE,
			REIMAN_CANOPY_SHELL.x)
	for side2: float in [-1.0, 1.0]:
		out.append({
			"band": "canopy_glass",
			"basis": Basis(Vector3(cos(shell_pitch), -side2 * sin(shell_pitch), 0.0),
					Vector3(side2 * sin(shell_pitch), cos(shell_pitch), 0.0),
					Vector3(0.0, 0.0, 1.0)),
			"p": Vector3(REIMAN_CANOPY_X + side2 * REIMAN_CANOPY_SHELL.x * 0.5 * cos(shell_pitch),
					(REIMAN_CANOPY_RIDGE + REIMAN_CANOPY_EAVE) * 0.5,
					REIMAN_CANOPY_Z),
			"s": Vector3(REIMAN_CANOPY_SHELL.x, REIMAN_CANOPY_SHELL_T,
					REIMAN_CANOPY_SHELL.y),
			"collide": true, "ground": false,
		})
	_add_row_box(out, "canopy_frame",
			Vector3(REIMAN_CANOPY_X, REIMAN_CANOPY_RIDGE + 0.1, REIMAN_CANOPY_Z),
			Vector3(0.5, 0.25, REIMAN_CANOPY_SHELL.y + 0.4), false, false)
	for side3: float in [-1.0, 1.0]:
		_add_row_box(out, "canopy_frame",
				Vector3(REIMAN_CANOPY_X + side3 * REIMAN_CANOPY_SHELL.x * cos(shell_pitch),
						REIMAN_CANOPY_EAVE_CLEAR * 0.5, REIMAN_CANOPY_Z),
				Vector3(0.45, REIMAN_CANOPY_EAVE_CLEAR, 0.45), true, false)
	return out


## The butterfly accents (the finish slice): eight ambient props over the
## entrance beds east of the conservatory — a fixed ring, phases spread by
## fraction (zero RNG), parented under `ReimanButterflies/`. The scope guard
## lives in `butterfly.gd`: no colliders, no bread, no citizen machinery.
func _build_reiman_butterflies() -> void:
	var root := Node3D.new()
	root.name = "ReimanButterflies"
	add_child(root)
	butterflies = []
	for k: int in BUTTERFLY_COUNT:
		var a := TAU * float(k) / float(BUTTERFLY_COUNT)
		var home := Vector3(
				BUTTERFLY_RING_CENTER.x + BUTTERFLY_RING_R * cos(a),
				BUTTERFLY_HOVER_Y,
				BUTTERFLY_RING_CENTER.y + BUTTERFLY_RING_R * sin(a))
		var bfly: Butterfly = BUTTERFLY_SCENE.instantiate()
		bfly.name = "Butterfly%d" % (k + 1)
		bfly.home = home
		bfly.phase = float(k) / float(BUTTERFLY_COUNT)
		bfly.flap_phase = fposmod(float(k) * 0.137, 1.0) ## Desynced, still deterministic.
		root.add_child(bfly)
		butterflies.append({
			"node": bfly, "home": home, "phase": bfly.phase,
		})


## (T-194) The rail corridor dressing: the chained track route, the crossbucks
## at the 9 at-grade crossings, the right-of-way fence line and the daily coal
## drag. Everything derives from the committed pack (`rail()` crossings +
## centerlines, `streets()` for the road axes); the fence and the crossbucks
## keep the T-180 transform-queue retention for the gate.
const RAIL_Y := 0.16 ## The rail-head height the consist rides (the bake's tie stripe tops 0.13).
const CROSSBUCK_POST_H := 3.0 ## The post's height (m) — the T-134 sign-assembly read.
const CROSSBUCK_ARM_LEN := 1.9 ## Each X arm's length.
const CROSSBUCK_EDGE_GAP := 2.5 ## The assembly's setback past the road half-width.
const FENCE_LEFT_OFFSET := 5.0 ## The north-side fence line, off the route (clears the ballast edge by 2.5).
const FENCE_RIGHT_OFFSET := 9.5 ## The south-side line — the double-track midline sits ~2.1 right of this chain; both fences hold 7.25 off it.
const FENCE_POST_PITCH := 18.0 ## The post run's along-route pitch.
const FENCE_POST_H := 1.3 ## The post's height (m).
const FENCE_WIRE_HEIGHTS: Array[float] = [0.55, 1.05] ## The two strand lines.
const FENCE_GAP_RADIUS := 18.0 ## No fence element within this of an at-grade crossing (the ballast's own road-gap law).
const WIGWAG_ROAD := "Duff Avenue" ## The museum piece stands at the busiest crossing (the census's note).

## The fence's weathered read (no survey hex — photo-06's dark right-of-way
## line) pinned here, asserted as the scenario's literals.
const FENCE_POST_COLOR := Color(0.23, 0.21, 0.19)
const FENCE_WIRE_COLOR := Color(0.45, 0.44, 0.42)
const WIGWAG_DARK := Color(0.16, 0.16, 0.17)
const WIGWAG_WHITE := Color(0.90, 0.89, 0.86)
const WIGWAG_RED := Color(0.75, 0.10, 0.08)

## The world-local chain of the south track (the greedy nearest-endpoint walk
## over the pack's 26 main-line ways — the daily drag's route and the fence's
## spine), retained for the gate.
var rail_route: PackedVector3Array = PackedVector3Array()
var train: AmesTrain = null
var crossbuck_pins: Array[Dictionary] = []
var wigwag_parts: Array[Dictionary] = []
var depot_hero_parts: Array[Dictionary] = []
var _crossbuck_post_xfs: Array[Transform3D] = []
var _crossbuck_arm_xfs: Array[Transform3D] = []
var _fence_post_xfs: Array[Transform3D] = []
var _fence_wire_xfs: Array[Transform3D] = []
const TRAIN_SCENE: PackedScene = preload("res://scenes/ames_train.tscn")


## Builds the whole corridor dress (the finish slice, after the fabric): the
## route chain, the crossbuck assemblies at the pack's 9 at-grade crossings,
## the fence lines and the train — one `RailCorridor` root under the world.
func _build_rail_corridor() -> void:
	rail_route = _rail_chain_route()
	if rail_route.size() < 2:
		push_error("AmesWorld: rail route chain failed — corridor builds empty")
		return
	var root := Node3D.new()
	root.name = "RailCorridor"
	add_child(root)
	_build_crossbucks(root)
	_build_fence(root)
	train = TRAIN_SCENE.instantiate() as AmesTrain
	train.name = "CoalDrag"
	train.setup(rail_route)
	root.add_child(train)


## The route: ONE track of the double-track main, chained west → east. Walk:
## start at the westmost way endpoint, then repeatedly consume the unused way
## whose start or end coincides with the chain's end (2.0 m tolerance — the
## ways split at shared nodes; the parallel track sits ≥ 3.4 m away and can
## never cross-link), appending it in its traversal direction. Deterministic,
## zero RNG. Returns the CORE route (y = RAIL_TOP); the train extends it
## off-map itself.
func _rail_chain_route() -> PackedVector3Array:
	var lines: Array = AmesDataPack.rail().get("centerlines", [])
	if lines.is_empty():
		return PackedVector3Array()
	var used: Array[bool] = []
	for _l: Array in lines:
		used.append(false)
	var start_i := 0
	var start_first := true
	var best_x := INF
	for i in lines.size():
		var line: Array = lines[i]
		if float((line[0] as Array)[0]) < best_x:
			best_x = float((line[0] as Array)[0])
			start_i = i
			start_first = true
		if float((line[line.size() - 1] as Array)[0]) < best_x:
			best_x = float((line[line.size() - 1] as Array)[0])
			start_i = i
			start_first = false
	used[start_i] = true
	var route := PackedVector3Array()
	var first: Array = lines[start_i]
	if start_first:
		for p: Array in first:
			route.append(Vector3(float(p[0]), RAIL_Y, float(p[1])))
	else:
		for k in range(first.size() - 1, -1, -1):
			var p2: Array = first[k]
			route.append(Vector3(float(p2[0]), RAIL_Y, float(p2[1])))
	while true:
		var end_p := route[route.size() - 1]
		var nxt := -1
		var nxt_rev := false
		var best_d := 2.0
		for i in lines.size():
			if used[i]:
				continue
			var line2: Array = lines[i]
			var a: Array = line2[0]
			var b: Array = line2[line2.size() - 1]
			var d0 := Vector2(float(a[0]), float(a[1])).distance_to(
					Vector2(end_p.x, end_p.z))
			var d1 := Vector2(float(b[0]), float(b[1])).distance_to(
					Vector2(end_p.x, end_p.z))
			if d0 < best_d:
				best_d = d0
				nxt = i
				nxt_rev = false
			if d1 < best_d:
				best_d = d1
				nxt = i
				nxt_rev = true
		if nxt < 0:
			break
		used[nxt] = true
		var seg: Array = lines[nxt]
		if not nxt_rev:
			for k in range(1, seg.size()):
				var p3: Array = seg[k]
				route.append(Vector3(float(p3[0]), RAIL_Y, float(p3[1])))
		else:
			for k in range(seg.size() - 2, -1, -1):
				var p4: Array = seg[k]
				route.append(Vector3(float(p4[0]), RAIL_Y, float(p4[1])))
	return route


## The road axis at an at-grade crossing: the nearest polyline segment of the
## matching street (exact name when the crossing names one, else — the unnamed
## yard lead — the nearest street segment of ANY class, since the pack's
## streets[] graph carries no service-class ways for it) — the segment's unit
## direction is the road axis, its `width_m` the road width. Deterministic.
func _road_axis_at(pos: Vector2, road_name: String, road_class: String) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for street: Dictionary in AmesDataPack.streets():
		if not road_name.is_empty() and str(street.get("name", "")) != road_name:
			continue
		var pts: Array = street.get("points", [])
		for i in range(pts.size() - 1):
			var a := Vector2(float((pts[i] as Array)[0]), float((pts[i] as Array)[1]))
			var b := Vector2(float((pts[i + 1] as Array)[0]),
					float((pts[i + 1] as Array)[1]))
			var seg := b - a
			var l2 := seg.length_squared()
			var t := 0.0
			if l2 > 1e-12:
				t = clampf((pos - a).dot(seg) / l2, 0.0, 1.0)
			var p := a + seg * t
			var d := p.distance_to(pos)
			if d < best_d:
				best_d = d
				best = {
					"axis": seg.normalized() if l2 > 1e-12 else Vector2.RIGHT,
					"width": float(street.get("width_m", 8.0)),
					"point": p,
				}
	return best


## The crossbuck assemblies: two per at-grade crossing (one per road approach,
## set back past the asphalt edge), each a dark post + the white X (two arms
## rotated ±45° in the plane facing along the road — the T-134 sign
## discipline: face-flush thin boxes, visual-only dressing).
func _build_crossbucks(root: Node3D) -> void:
	var posts: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	for crossing: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(crossing.get("grade", "")) != "at_grade":
			continue
		var pos := Vector2(float((crossing["pos"] as Array)[0]),
				float((crossing["pos"] as Array)[1]))
		var road := _road_axis_at(pos, str(crossing.get("road_name", "")),
				str(crossing.get("road_class", "")))
		if road.is_empty():
			continue
		var axis: Vector3 = Vector3((road["axis"] as Vector2).x, 0.0,
				(road["axis"] as Vector2).y)
		var side := axis.cross(Vector3.UP).normalized() ## In-plane perpendicular.
		var setback: float = float(road["width"]) * 0.5 + CROSSBUCK_EDGE_GAP
		for dir_sign: float in [-1.0, 1.0]:
			var sp := pos + (road["axis"] as Vector2) * dir_sign * setback
			var sp3 := Vector3(sp.x, 0.0, sp.y)
			posts.append(Transform3D(
					Basis(axis * 0.14, Vector3.UP * CROSSBUCK_POST_H, side * 0.14),
					sp3 + Vector3(0.0, CROSSBUCK_POST_H * 0.5, 0.0)))
			for arm_sign: float in [-1.0, 1.0]:
				var arm_dir := (Vector3.UP + side * arm_sign).normalized()
				arms.append(Transform3D(
						Basis(axis * 0.10, arm_dir * CROSSBUCK_ARM_LEN,
								axis.cross(arm_dir).normalized() * 0.30),
						sp3 + Vector3(0.0, CROSSBUCK_POST_H, 0.0)))
		crossbuck_pins.append({
			"pos": pos, "road": str(crossing.get("road_name", "")),
			"rail": str(crossing.get("rail", "")), "width": float(road["width"]),
			"assemblies": 2,
		})
	_crossbuck_post_xfs = posts
	_crossbuck_arm_xfs = arms
	_spawn_corner_family(root, "CrossbuckPosts", posts, COLOR_SIGN_POST)
	_spawn_corner_family(root, "CrossbuckArms", arms, COLOR_SIGN_WHITE)
	_build_wigwag(root)


## The museum wigwag at ONE crossing (the ticket's optional flavor, photo
## `rail/09`): pole + top motor case + the over-road arm + the round target
## disc (mesh extra, face toward the road approach). Static — the swing is a
## museum piece, not live hardware.
func _build_wigwag(root: Node3D) -> void:
	for crossing: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(crossing.get("grade", "")) != "at_grade" \
				or str(crossing.get("road_name", "")) != WIGWAG_ROAD:
			continue
		var pos := Vector2(float((crossing["pos"] as Array)[0]),
				float((crossing["pos"] as Array)[1]))
		var road := _road_axis_at(pos, WIGWAG_ROAD,
				str(crossing.get("road_class", "")))
		if road.is_empty():
			continue
		var axis: Vector3 = Vector3((road["axis"] as Vector2).x, 0.0,
				(road["axis"] as Vector2).y)
		var u2: Vector2 = road["axis"]
		var base := pos + u2 * (float(road["width"]) * 0.5 + 6.0)
		var base3 := Vector3(base.x, 0.0, base.y)
		var parts: Array[Dictionary] = [
			{"band": "wigwag_dark", "p": base3 + Vector3(0.0, 2.2, 0.0),
					"s": Vector3(0.16, 4.4, 0.16), "color": WIGWAG_DARK},
			{"band": "wigwag_dark", "p": base3 + Vector3(0.0, 4.25, 0.0),
					"s": Vector3(0.5, 0.35, 0.4), "color": WIGWAG_DARK},
			{"band": "wigwag_dark", "p": base3 - axis * 0.45 + Vector3(0.0, 4.0, 0.0),
					"s": Vector3(0.9, 0.08, 0.08), "color": WIGWAG_DARK},
			{"band": "wigwag_white", "p": base3 + Vector3(0.0, 3.6, 0.0),
					"s": Vector3(1.6, 0.4, 0.08), "color": WIGWAG_WHITE},
		]
		var disc_pos := base3 - axis * 0.9 + Vector3(0.0, 3.55, 0.0)
		var x_col := axis.cross(Vector3.UP).normalized()
		var disc_basis := Basis(x_col, axis, x_col.cross(axis).normalized())
		wigwag_parts = parts
		var wg_dark: Array[Transform3D] = []
		var wg_white: Array[Transform3D] = []
		for part2: Dictionary in parts:
			var xf2 := Transform3D(Basis.from_scale(part2["s"] as Vector3),
					part2["p"] as Vector3)
			if str(part2["band"]) == "wigwag_white":
				wg_white.append(xf2)
			else:
				wg_dark.append(xf2)
		_spawn_corner_family(root, "WigwagDark", wg_dark, WIGWAG_DARK)
		_spawn_corner_family(root, "WigwagWhite", wg_white, WIGWAG_WHITE)
		var disc := MeshInstance3D.new()
		disc.name = "WigwagDisc"
		disc.mesh = _row_taper_mesh(0.275, 0.275, 0.1, WIGWAG_RED)
		disc.transform = Transform3D(disc_basis, disc_pos)
		root.add_child(disc)
		wigwag_parts.append({
			"band": "wigwag_red", "p": disc_pos,
			"s": Vector3(0.55, 0.1, 0.55), "color": WIGWAG_RED, "mesh": true,
		})
		for p_rec: Dictionary in wigwag_parts:
			if p_rec.has("mesh"):
				continue
			p_rec["mesh"] = false
		return ## One wigwag only.


## One route polyline's total length (m) — the gate's route-metric feed.
func _rail_route_length(route: PackedVector3Array) -> float:
	var total := 0.0
	for i in route.size() - 1:
		total += (route[i + 1] as Vector3).distance_to(route[i])
	return total


## The right-of-way fence lines (photo `rail/06`'s cross-section): a post run
## at the pinned pitch on BOTH sides of the route (the offsets clear both
## ballast strips of the double track) with two strand lines between
## consecutive posts, gapped at the at-grade crossings. Visual-only dressing.
func _build_fence(root: Node3D) -> void:
	var posts: Array[Transform3D] = []
	var wires: Array[Transform3D] = []
	var route := rail_route
	var total := 0.0
	var seg_lens: PackedFloat32Array = PackedFloat32Array()
	for i in route.size() - 1:
		var seg := (route[i + 1] as Vector3).distance_to(route[i])
		seg_lens.append(seg)
		total += seg
	var crossings: Array[Vector2] = []
	for crossing: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(crossing.get("grade", "")) != "at_grade":
			continue
		crossings.append(Vector2(float((crossing["pos"] as Array)[0]),
				float((crossing["pos"] as Array)[1])))
	var n_posts := int(total / FENCE_POST_PITCH)
	var prev: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var prev_ok: Array[bool] = [false, false]
	for k in n_posts + 1:
		var s := float(k) * FENCE_POST_PITCH
		if s > total:
			break
		## Walk to arc s.
		var acc := 0.0
		var pt := route[0]
		var tan := Vector3.RIGHT
		for i in route.size() - 1:
			if acc + seg_lens[i] >= s:
				var t := (s - acc) / maxf(seg_lens[i], 0.001)
				pt = (route[i] as Vector3).lerp(route[i + 1], t)
				tan = ((route[i + 1] as Vector3) - (route[i] as Vector3)).normalized()
				break
			acc += seg_lens[i]
		var left := Vector3(tan.z, 0.0, -tan.x) ## North side of west→east travel.
		for side_i in 2:
			var offset := FENCE_LEFT_OFFSET if side_i == 0 else FENCE_RIGHT_OFFSET
			var side_sign := 1.0 if side_i == 0 else -1.0
			var fp_flat := pt + left * (offset * side_sign) ## Left line north of the route, right line south (the second track's side).
			var fp := Vector3(fp_flat.x, 0.0, fp_flat.z) ## The fence stands on the plate — the route's own y is the rail head.
			var fp2 := Vector2(fp.x, fp.z)
			var ok := true
			for c: Vector2 in crossings:
				if fp2.distance_to(c) < FENCE_GAP_RADIUS:
					ok = false
					break
			if ok:
				posts.append(Transform3D(
						Basis(tan * 0.10, Vector3.UP * FENCE_POST_H,
								Vector3(left.z, 0.0, -left.x) * 0.10),
						fp + Vector3(0.0, FENCE_POST_H * 0.5, 0.0)))
			if ok and prev_ok[side_i]:
				var span := fp - prev[side_i]
				var mid := (fp + prev[side_i]) * 0.5
				var dir := span.normalized()
				var perp := Vector3(-dir.z, 0.0, dir.x)
				for h: float in FENCE_WIRE_HEIGHTS:
					wires.append(Transform3D(
							Basis(dir * span.length(), Vector3.UP * 0.05,
									perp * 0.05),
							mid + Vector3(0.0, h, 0.0)))
			prev[side_i] = fp
			prev_ok[side_i] = ok
	_fence_post_xfs = posts
	_fence_wire_xfs = wires
	_spawn_corner_family(root, "FencePosts", posts, FENCE_POST_COLOR)
	_spawn_corner_family(root, "FenceWires", wires, FENCE_WIRE_COLOR)


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


## --- T-198 the Tier-1 venue signs ------------------------------------------
## The fourteen VENUES §1 names a student says first, mounted at their verified
## positions/facings through `AmesVenueSigns` (the mount table + the Superdog
## cart prop live there; this is only the world wiring). The signs are the R4
## text capability's first real content: visual-only (no colliders), pack-frame
## coordinates, zero RNG — a rebuild reproduces every mount byte-identically.
## The staged The Cafe entry (north Ames, outside the v1 bake core) places when
## T-205 extends the bake — recorded in the module table and the ticket, not
## worked around.
func _build_venue_signs() -> void:
	var root := Node3D.new()
	root.name = "VenueSigns"
	add_child(root)
	venue_signs = AmesVenueSigns.build(root)


## --- T-199 the tiers 2–3 signs + the ghost plaques --------------------------
## The next names a student gives (VENUES §2/§3) and the mourned CLOSED
## venues of §6, mounted through the same `AmesVenueSigns` tables as the
## Tier-1 build. Separate roots so the T-198 subtree (and its gate pins)
## stay byte-identical: `VenueSignsTiers` carries the 27 signed tier-2/3
## venues, `GhostPlaques` the 11 memorial plaques — visual-only, pack-frame,
## zero RNG.
func _build_venue_signs_tiers() -> void:
	var root := Node3D.new()
	root.name = "VenueSignsTiers"
	add_child(root)
	venue_signs_t23 = AmesVenueSigns.build_tiers(root)
	var plaque_root := Node3D.new()
	plaque_root.name = "GhostPlaques"
	add_child(plaque_root)
	ghost_plaques = AmesVenueSigns.build_plaques(plaque_root)


## --- T-200 the spine street-name blades -------------------------------------
## The MUTCD green blades at the pinned corners (the wayfinding channel after
## the venue names), mounted through `AmesStreetBlades` off the traffic graph's
## own T-180 classification — one blade per spine street name at every pinned
## corner the spine set touches, mast-arm stacked at signal corners, post-
## mounted on the approach's right at the all-way stops. Visual-only (the
## T-197 scope), pack-frame coordinates, zero RNG — a rebuild reproduces every
## mount byte-identically. Runs AFTER the intersection furniture so the blades
## hang on/stand beside the T-180 dress that shares their derivation.
func _build_street_blades() -> void:
	if traffic_graph == null:
		return
	var root := Node3D.new()
	root.name = "StreetBlades"
	add_child(root)
	street_blades = AmesStreetBlades.build(traffic_graph, root)


## --- T-201 the campus + civic name plaques ----------------------------------
## The pinned building list's nominative names in plain type (name + the
## survey's year, nothing else — no wordmark, no Cy, no athletics marks, no
## railroad brands), hung one gap off the R3 heroes' own pinned faces through
## `AmesCampusPlaques` (the mount table lives there; this is only the world
## wiring). The Marston tower rides the free-standing base-marker form; the
## staged Reiman Gardens spec (out of core, the T-204 dependency) places when
## that bake extension lands. Visual-only (the T-197 scope), pack-frame
## coordinates, zero RNG — a rebuild reproduces every mount byte-identically.
## Runs AFTER the heroes (built in the chunk walk) so the gate's re-derivation
## against the hero part records sees the finished geometry.
func _build_campus_plaques() -> void:
	var root := Node3D.new()
	root.name = "CampusPlaques"
	add_child(root)
	campus_plaques = AmesCampusPlaques.build(root)


## The Superdog cart's part count for the report (0 before the signs build).
func _venue_cart_parts() -> int:
	for rec: Dictionary in venue_signs:
		if rec.has("cart_parts"):
			return int(rec["cart_parts"])
	return 0


## The Carlos Quesadilla truck's part count for the report (T-199).
func _cq_truck_parts() -> int:
	for rec: Dictionary in venue_signs_t23:
		if rec.has("truck_parts"):
			return int(rec["truck_parts"])
	return 0


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

class_name City
extends Node3D
## The world-root base class — the gameplay seam (T-173). After the R1
## cutover (T-177, owner fork 2026-11-09 — master plan §11.2) the one world
## is the resident Ames bake: `AmesWorld extends City` and implements the
## build (`generate` + the three stepped-boot slices) over the committed
## chunk data. THIS class carries only the world-agnostic surface every
## consumer reads — the spawn corridor, the bread/elder/cafe spot arrays,
## the `regenerated` signal, the `world`-layer collision helpers (`_group`/
## `_add_collider`), and the shared layout constants the citizen systems
## and the route grid are defined against (crumb lifts, table offsets,
## crosswalk bands, stop-line outset).
##
## The Windrow procedural city (T-004-T-136) was RETIRED at the cutover: its
## generate path — the seeded RNG layout, the MultiMesh builders, the visual
## palettes and the M1 guarantee report — is deleted, no debug toggle (the
## owner fork; git history keeps the old city, and `city.tscn` survives only
## as the staged node `main.tscn` swaps away). The base `generate()`/
## `generate_step_*` below are loud stubs: only an `AmesWorld` (or an R2+
## world) may build. The grid math the citizen systems still reference —
## `sidewalk_loop`, `traffic_loop`, `parking_spots`, the T-134 route grid —
## stays: it is the seam those systems re-point onto real Ames data in R2,
## and on the Ames world the citizens' empty spot arrays keep every consumer
## inert (the spawners early-return; nothing on Ames reaches this math yet).


## Tabletop crumb layout (T-112): one TABLE bread spot per awninged building,
## riding its own cafe table. The spot's y is CAFE_CRUMB_TABLE_LIFT above the
## table spot origin — the merged collider's walkable top face at +0.72
## (CafeSpawner.TABLE_SHAPE_SIZE/OFFSET) plus the 0.06 crumb lift, the exact
## roof/anchor spot convention (ANCHOR_CRUMB_LIFT) — and its XZ sits
## CAFE_CRUMB_SIT_INSET along the table's local +X, toward the first sitter
## (CafeSpawner.SITTER_SEATS puts one at ±0.72 on every table): the
## diner's-edge plate, 0.47 m from that sitter and 0.20 m inside the 0.9 m
## top's edge. Pure layout numbers; the placement draws no RNG of any stream
## and appends no `_fp` entry, so the layout fingerprint stays byte-identical.
const CAFE_CRUMB_TABLE_LIFT := 0.78 ## Spot y above the table spot origin: collider top 0.72 + crumb lift 0.06.
const CAFE_CRUMB_SIT_INSET := 0.25 ## Spot XZ offset along the table's local +X, toward the first sitter.

const ANCHOR_CRUMB_LIFT := 0.06 ## Crumb height above the cap's top face (the T-032 roof-crumb pattern).

## Intersection crosswalk layout (T-069, bars re-oriented longitudinal by
## T-102): one zebra band per intersection approach, its center CROSSWALK_OUTSET
## out from the road-center node along the approach axis, on the road
## centerline. Real zebra geometry (UK Highway Code: longitudinal stripes): the
## bars run ALONG the road and repeat ACROSS it — the band is a
## CROSSWALK_BAND_DEPTH-deep run of road, tiled edge-to-edge by
## CROSSWALK_BAR_WIDTH-wide bars at CROSSWALK_BAR_PITCH on centers,
## road_width / CROSSWALK_BAR_PITCH bars per band (10 at the defaults, 0.25 m
## of asphalt left clear at each road edge). With the defaults the band
## footprint spans 5.0–7.4 m out — its 5.0 m inner edge clears the corner-cut
## area turning cars sweep through (traffic_lane_offset 3.5 m) by 1.5 m — and an
## approach whose band would leave the asphalt (node ± 7.4 m past ±city_span *
## 0.5) is skipped, dropping the 32 outward approaches of the outer ring: 224
## bands, 2,240 bars. Pure layout numbers; the placement draws no RNG and
## appends no `_fp` entry.
const CROSSWALK_OUTSET := 6.2 ## Band center out from the node (m).
const CROSSWALK_BAND_DEPTH := 2.4 ## Band depth along the road (m).

## How far a crosswalk band reaches from its node: center plus half depth
## (7.4 m at the defaults) — the T-069 approach-existence rule's reach, shared
## by the T-134 stop-control furniture so paint and cars agree on which
## approaches exist.
const CROSSWALK_REACH := 6.2 + 2.4 * 0.5

## Route grid (T-134): the intersection nodes are the (blocks_per_side + 1)
## road centers per axis; `ROUTE_DIRS` is the cyclic compass (index +1 = a
## RIGHT turn: +x → +z → −x → −z), so `route_relative_turn` and every
## right-hand lane/yaw derivation share one definition. Turn codes double as
## Car blinker sides (−1 left / 0 straight / +1 right).
const ROUTE_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]
const ROUTE_DIR_VECS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0),
	Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0),
]
const ROUTE_TURN_LEFT := -1
const ROUTE_TURN_STRAIGHT := 0
const ROUTE_TURN_RIGHT := 1

## Intersection stop-control layout (T-134): per EXISTING approach (the same
## T-069 reach rule as the crosswalk bands) one white stop line across the
## incoming lane, one stop-sign assembly on the approach's right side, and per
## node one speed-limit sign on the first existing approach. All pure layout
## math on the grid constants: zero RNG of any stream, zero `_fp` entries (the
## T-069/T-031 precedent — the layout fingerprint stays byte-identical) and
## zero colliders (visual-only, the T-017 decision). Pinned by
## `intersection_furniture_oriented`.
const STOP_LINE_OUTSET := 8.8 ## Stop-line bar center out from the node (m) — 1.2 m beyond the crosswalk band's 7.4 m edge plus half the bar width (MUTCD ≥ 4 ft before the crosswalk).

@export_group("Layout")
## Fixed M1 seed — same city every run so runs and scores stay comparable.
@export var seed_value: int = 20260928
@export var blocks_per_side: int = 7 ## City is blocks_per_side squared blocks.
@export var block_size: float = 22.0 ## Full block footprint including the sidewalk ring (m).
@export var road_width: float = 10.0 ## Street width between blocks (m).
@export var ground_extra: float = 250.0 ## Grass apron beyond the city edge on each side (m).
## (T-129) Hold the boot build for Main's stepped boot: when true (main.tscn
## only), `_ready` does NOT generate — main.gd drives the same build as ordered
## slices the engine can render between (`generate_step_ground` →
## `generate_step_blocks` → `generate_step_finish`), or synchronously in
## Main._ready on the instanced-Main rig path. Standalone city rigs (city.tscn,
## every harness rig) keep the default false and self-generate exactly as
## always.
@export var hold_generate: bool = false

## (T-004, kept for the citizen seam) Top of the raised block slab — the
## height the sidewalk-loop and route math ride; on the Ames world the
## plate is flat and this stays the documented default the route grid
## answers against until R2 re-points it.
## Top of the raised block slab — sidewalk and courtyards (m). Steps stay below
## r·(1−cos45°) ≈ 0.09 m for the 0.3 m pigeon collider: taller curbs are walls,
## shorter ones roll under the sphere so the waddle climbs them.
@export var block_slab_height: float = 0.12
@export var road_slab_height: float = 0.05 ## Top of the asphalt slab (m).

@export_group("Spawn")
## Height above the road surface the pigeon drops in from. Keep small: the
## spawn drop is straight down, so anything tall turns into a skid.
@export var spawn_drop_height: float = 0.6

## Driving-lane center beyond the block edge (m) — the route grid's lane
## convention (`lane_center_off`).
@export var traffic_lane_offset: float = 3.5
## Parking-lane center beyond the block edge (m) — `parking_spots`' curb
## convention.
@export var parking_offset: float = 1.05

## Where the pigeon starts: plaza center plus the spawn drop (global coords).
var spawn_point: Vector3
## Hash of the whole generated layout; equal fingerprints mean an identical city.
var fingerprint: int = 0
## One entry per building: `center` (global footprint center), `size` (XZ
## footprint), `top` (global roof height), plus the T-013 palette members
## Summary of the last generation — the sim harness asserts the guarantees on it.
var last_report: Dictionary = {}

## How many real rebuilds this City has performed — the boot build makes it 1
## (T-033). The same-seed fast path never increments it: the standing build is
## kept, and the sim harness asserts on that (`restart_same_seed_skips_rebuild`).
var build_count: int = 0

## Emitted at the end of every generate() — the bread service (T-005) re-seeds
## its pickups so they always sit on the current layout.
signal regenerated

## Surface points (city-local) where a bread crumb can sit (T-005): bench
## seats, the sidewalk ring of every block, plaza and park slabs. Purely
## derived from the layout — no RNG of its own — so it is deterministic per
## seed and never shifts the building RNG sequence.
var bread_spots: Array[Vector3] = []

## What surface class each `bread_spots` entry is (T-112), index-aligned —
## appended in lockstep with every `bread_spots` append and cleared beside it:
## GROUND for the sidewalk ring and bench seats, ROOF for the roof corners and
## district-anchor caps, TABLE for the cafe tabletops. The spawner (T-112)
## weights the live spread per class — tables most, roofs rare — and the
## harness scenarios read the kinds instead of re-deriving surfaces from
## heights. Zero RNG of its own and zero `_fp` entries (the `bread_spots`
## precedent), so the layout fingerprint stays byte-identical.
enum BreadKind { GROUND, TABLE, ROOF }
var bread_spot_kinds: Array[int] = []

## (T-176) Indices into `bread_spots` the BreadSpawner seeds FIRST on every
## populate — guaranteed-at-boot crumbs near the spawn, so "first bread
## reachable" is a fact about the live spread, not just the spot supply
## (AmesWorld files its spawn's nearest ground spots here; at 40 crumbs
## across 11,000+ Ames spots the seeded shuffle alone would land the nearest
## one hundreds of metres out). Empty on the Windrow generator — every
## populate behaves byte-as-today there — and re-seeded by every populate,
## so the guarantee renews across restarts; eaten boot crumbs respawn
## wherever the class quotas put them, exactly like any other crumb.
var boot_bread_spots: Array[int] = []

## (T-178) The resident world's traffic graph — the route system the car
## fleet drives on the real Ames streets (welded junctions, right-hand lane
## polylines, speed classes, rail-crossing facts). Null on the base class:
## the Windrow grid route seam above stays the fallback for bare rigs, and
## the CarSpawner branches on this being set (the Ames population/recycle/
## dev-spawn paths). Built by the world's build (AmesWorld's finish slice),
## pure data, no RNG.
var traffic_graph: AmesTrafficGraph = null

## The pedestrian zones (T-181) — the pinned activity streets the citizens
## populate (the Welch strip, downtown Main, Central Campus, the LaVerne
## shore, the MU corner), each with sidewalk polylines, a population cap and
## bench/sit targets. Built by the world's finish slice right after the
## traffic graph (the zone crossing legs derive from its pinned bands), pure
## data, no RNG of any stream. Null until a world builds it; the citizen
## spawners fall back to their retired block-grid machinery when unset.
var ped_zones: AmesPedZones = null

## The parking system (T-182) — the census curb marking the car fleet's
## parked placement re-targets to, plus the dressed big-lot stall grids the
## world renders as dressing rows (the tailgate stock reads full-ish; the
## splat/favor fleet itself stays the T-147 contract). Built by the world's
## finish slice after the pedestrian zones, pure data, no RNG of any stream.
var parking: AmesParking = null

## Seated spots (city-local) for the park elders (T-020): one transform per
## plaza-ring bench — position on the seat line, yaw = the bench's own. Purely
## derived from the layout — no RNG of its own — so it is deterministic per
## seed and never shifts the layout RNG sequence.
var elder_spots: Array[Transform3D] = []

## The migration district of each `elder_spots` entry (T-137), appended in
## lockstep: -1 for the 8 plaza seats, `district_of` for the 4 park seats.
## Pure layout data - zero RNG, zero `_fp` entries.
var elder_seat_districts: Array[int] = []

## Seated spots (city-local) for the sidewalk cafes (T-031): one transform per
## awninged building — table center on the sidewalk in front of the shop door,
## yaw facing the street. Appended after the block loop from the public
## `buildings[]` data by pure math, zero RNG of any stream, so the layout
## fingerprints and the pinned awning count stay byte-identical.
var cafe_spots: Array[Transform3D] = []


## Center (city-local) of every generated block — the tourist service (T-007)
## picks its sidewalk walking loops from these.
var block_centers: Array[Vector3] = []

## Center-to-center distance between neighboring blocks (m).
var block_pitch: float:
	get: return block_size + road_width

## Full city span across, outer ring roads included (m).
var city_span: float:
	get: return blocks_per_side * block_pitch + road_width


## The off-world guard's home center Main wires at boot — the world origin
## here. A method so worlds override it: the Ames map's center is its bake
## bounds center, not the pack origin (T-173 round-1 review — the origin sits
## on the map's WEST edge, which put half the skeleton outside the guard).
func home_center() -> Vector3:
	return global_position


## The off-world guard's home radius Main wires at boot (m) — the apron edge
## past which the nudge bends the course home. A method (not the property
## arithmetic) so worlds override it: the Ames map's radius comes from the
## bake's own bounds, not the Windrow grid math (T-173). The value here is
## exactly the expression Main used to inline.
func home_radius() -> float:
	return city_span * 0.5 + ground_extra

var _static_root: Node3D ## (T-093) The `Static/` root the `_group` bodies hang under.


func _ready() -> void:
	if hold_generate: ## (T-129) main.tscn's stepped boot drives the build itself.
		return
	generate()


## Rebuilds the whole world. (T-177) The base class CANNOT build: the Windrow
## generator was retired at the cutover — only an `AmesWorld` (or a future
## world root) overrides this and the three stepped-boot slices. A bare City
## reaching this fails loudly, never silently builds nothing.
##
## Same-seed fast path (T-033, the AmesWorld override): when a build already
## stands (`fingerprint != 0`) and `new_seed` equals its seed, the rebuild is
## skipped entirely — `regenerated` still emits, because that is what a
## restart actually needs: the spawners re-seed fresh nodes off it.
func generate(new_seed: int = seed_value, force_rebuild: bool = false) -> void:
	push_error("City.generate: the Windrow generator was retired at the T-177 cutover — build through AmesWorld")

## (T-129) Stepped boot, slice 1 of 3 — "ground/slabs". (T-177) Loud stub on
## the base class — only the world override builds; see `generate`. The
## same-seed fast path check stays (the override's contract keeps the shape).
func generate_step_ground(new_seed: int = seed_value, force_rebuild: bool = false) -> bool:
	if fingerprint != 0 and new_seed == seed_value and not force_rebuild:
		regenerated.emit()
		return false
	push_error("City.generate_step_ground: the Windrow generator was retired at the T-177 cutover — build through AmesWorld")
	return true

## (T-129) Stepped boot, slice 2 of 3 — "buildings". (T-177) Loud stub on the
## base class — only the world override builds; see `generate`.
func generate_step_blocks() -> void:
	push_error("City.generate_step_blocks: the Windrow generator was retired at the T-177 cutover — build through AmesWorld")

## (T-129) Stepped boot, slice 3 of 3 — "visuals". (T-177) Loud stub on the
## base class — only the world override builds; see `generate`.
func generate_step_finish() -> void:
	push_error("City.generate_step_finish: the Windrow generator was retired at the T-177 cutover — build through AmesWorld")

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_static_root = null

## --- citizen-seam layout math ---------------------------------------------


## Waypoint loop (city-local) for one block's tourists (T-007): a rectangle on
## the sidewalk's outer curb line. The radius matters: the loop's legs must be
## clear of everything that shares the block. (T-177) The Windrow block ring
## this derives from is retired; the method stays as the seam TouristSpawner
## reads — empty until R2 fills real pedestrian zones over the Ames data.
func sidewalk_loop(center: Vector3) -> PackedVector3Array:
	var ring := block_size * 0.5 - 0.1
	var y := block_slab_height
	return PackedVector3Array([
		center + Vector3(ring, y, ring),
		center + Vector3(-ring, y, ring),
		center + Vector3(-ring, y, -ring),
		center + Vector3(ring, y, -ring),
	])

## Corner waypoints (city-local) for one block's traffic loop (T-008): the
## ring road around the block, right-hand traffic. The traversal order turns
## right at every corner, so of the four loops meeting at an intersection each
## cuts a disjoint corner (offsets ±traffic_lane_offset sit 3 m apart against
## a 1.9 m car width) — cross traffic can never meet, it can only queue.
## (T-177) Kept as the citizen seam, inert until R2 re-points traffic onto
## the real Ames street graph.
func traffic_loop(center: Vector3) -> PackedVector3Array:
	var o := block_size * 0.5 + traffic_lane_offset
	var y := road_slab_height
	return PackedVector3Array([
		center + Vector3(o, y, o),
		center + Vector3(-o, y, o),
		center + Vector3(-o, y, -o),
		center + Vector3(o, y, -o),
	])

## Eight curb parking spots (city-local) for one block (T-008): two per edge,
## well clear of the intersection corners, each yaw-aligned with the adjacent
## driving lane so parked cars face with the traffic. Purely derived from the
## layout — no RNG — so it is deterministic per seed. (T-177) Kept as the
## citizen seam, inert until R2 re-points parking onto the real curbs.
func parking_spots(center: Vector3) -> Array[Dictionary]:
	var edge := block_size * 0.5
	var p := edge + parking_offset
	var y := road_slab_height
	var spots: Array[Dictionary] = []
	for a: float in [edge * 0.5, -edge * 0.5]:
		spots.append({ ## South edge — its lane flows -x.
			"pos": center + Vector3(a, y, p), "yaw": PI * 0.5,
		})
		spots.append({ ## North edge — its lane flows +x.
			"pos": center + Vector3(a, y, -p), "yaw": -PI * 0.5,
		})
		spots.append({ ## East edge — its lane flows +z.
			"pos": center + Vector3(p, y, a), "yaw": PI,
		})
		spots.append({ ## West edge — its lane flows -z.
			"pos": center + Vector3(-p, y, a), "yaw": 0.0,
		})
	return spots

## --- route grid (T-134) -----------------------------------------------------


## The road-center coordinate per axis (city-local): the `blocks_per_side + 1`
## street centerlines both `_build_roads` and `_build_crossings` walk.
func road_node_coords() -> Array[float]:
	var half := city_span * 0.5
	var centers: Array[float] = []
	for i in blocks_per_side + 1:
		centers.append(-half + road_width * 0.5 + i * block_pitch)
	return centers


## One intersection node's position (city-local), at paint height.
func road_node_pos(node: Vector2i) -> Vector3:
	var centers := road_node_coords()
	return Vector3(centers[node.x], road_slab_height, centers[node.y])


## True when the node index stays on the (blocks_per_side + 1)² grid.
func on_grid(node: Vector2i) -> bool:
	return node.x >= 0 and node.x <= blocks_per_side \
			and node.y >= 0 and node.y <= blocks_per_side


## True when a route may step from `node` toward `dir` — on-grid only, so at
## rim nodes the outward turn is simply not offered.
func route_step_ok(node: Vector2i, dir: int) -> bool:
	return on_grid(node + ROUTE_DIRS[dir])


## True when the node's `dir` approach exists as PAINT (the T-069 reach rule:
## its crosswalk band, and so every stop-control prop, stays on the asphalt).
## At the defaults this coincides exactly with `route_step_ok` — every approach
## a car can arrive on carries furniture.
func approach_exists(node: Vector2i, dir: int) -> bool:
	var centers := road_node_coords()
	var along: float = centers[node.x] if ROUTE_DIRS[dir].x != 0 else centers[node.y]
	return absf(along + signf(ROUTE_DIRS[dir].x + ROUTE_DIRS[dir].y) * CROSSWALK_REACH) \
			<= city_span * 0.5


## The driving-lane center's offset off the road centerline toward the travel
## direction's right (m): the lane sits `traffic_lane_offset` beyond the block
## edge — the `traffic_loop`/`parking_spots` right-hand convention — which is
## `road_width * 0.5 − traffic_lane_offset` (1.5 m at the defaults) off the
## centerline. Route legs reuse it verbatim, so the lane geometry (and the
## parked-row clearance) is byte-identical to the ring loops'.
func lane_center_off() -> float:
	return road_width * 0.5 - traffic_lane_offset


## The unit right-of-travel vector for approach `dir` (right = forward × up:
## facing +x your right is +z, facing −z your right is +x).
func right_of_dir(dir: int) -> Vector3:
	var a := ROUTE_DIR_VECS[dir]
	return Vector3(-a.z, 0.0, a.x)


## A point on `node`'s `dir` approach lane, `out` metres before the node
## (city-local, paint height): `out` back along the approach axis plus the
## lane-center offset to the travel direction's right.
func route_lane_point(node: Vector2i, dir: int, out: float) -> Vector3:
	var a := ROUTE_DIR_VECS[dir]
	return road_node_pos(node) - a * out + right_of_dir(dir) * lane_center_off()


## −1 left / 0 straight / +1 right — the turn `dir_out` makes against `dir_in`
## on the cyclic compass (the code doubles as the Car blinker side).
func route_relative_turn(dir_in: int, dir_out: int) -> int:
	if dir_out == (dir_in + 1) % 4:
		return ROUTE_TURN_RIGHT
	if dir_out == (dir_in + 3) % 4:
		return ROUTE_TURN_LEFT
	return ROUTE_TURN_STRAIGHT


## The turn waypoint where `dir_in`'s approach lane line meets `dir_out`'s exit
## lane line at `node` (city-local): the closed form falls out of the two
## perpendicular lane lines — n + off·(r_in − a_in) for a right turn,
## n + off·(r_in + a_in) for a left — the same disjoint-corner recipe the ring
## loops cut, now inside the intersection box.
func route_corner(node: Vector2i, dir_in: int, dir_out: int) -> Vector3:
	var a := ROUTE_DIR_VECS[dir_in]
	var r := right_of_dir(dir_in)
	var sign := 1.0 if route_relative_turn(dir_in, dir_out) == ROUTE_TURN_LEFT else -1.0
	return road_node_pos(node) + (r + a * sign) * lane_center_off()


## A seeded random walk over the node grid (T-134): never doubling back (no
## U-turns — the offered moves are straight/right/left only) and never stepping
## off the grid (at rim nodes the outward turn is not offered; a weight whose
## move is unavailable is simply not rolled). Turn weights come from the car's
## Routes exports via `weights` — straight 0.60 / right 0.25 / left 0.15 at the
## defaults, lefts rare per real behavior. One `rng.randi_range` for the initial
## heading (uniform over the on-grid neighbors, or `initial_dir` fixed — the
## extension path passes the car's live heading so a dealt route never
## U-turns) and one `rng.randf()` per step, off the CALLER's stream (the
## spawner's `_rng`) — zero new streams.
func route_from(start: Vector2i, steps: int, rng: RandomNumberGenerator,
		weights: Dictionary = {}, initial_dir: int = -1) -> Array[Vector2i]:
	var straight: float = weights.get("straight", 0.60)
	var right: float = weights.get("right", 0.25)
	var left: float = weights.get("left", 0.15)
	var nodes: Array[Vector2i] = [start]
	var dir := initial_dir
	if dir < 0:
		var options: Array[int] = []
		for d in 4:
			if route_step_ok(start, d):
				options.append(d)
		dir = options[rng.randi_range(0, options.size() - 1)]
	elif not route_step_ok(start, dir):
		## A pinned heading can point off-grid — an extension dealt at a rim
		## node whose car arrived heading outward. Degrade to the weighted
		## walk: the offered-move roll below never steps off the grid.
		dir = -1
		var options: Array[int] = []
		for d in 4:
			if route_step_ok(start, d):
				options.append(d)
		dir = options[rng.randi_range(0, options.size() - 1)]
	for _s in steps:
		nodes.append(nodes[nodes.size() - 1] + ROUTE_DIRS[dir])
		var here := nodes[nodes.size() - 1]
		var moves: Array[int] = []
		var totals: Array[float] = []
		var total := 0.0
		for move_dir: int in [dir, (dir + 1) % 4, (dir + 3) % 4]:
			var weight: float = straight if move_dir == dir \
					else (right if move_dir == (dir + 1) % 4 else left)
			if weight > 0.0 and route_step_ok(here, move_dir):
				total += weight
				moves.append(move_dir)
				totals.append(total)
		var roll := rng.randf() * total
		for i in moves.size():
			if roll <= totals[i]:
				dir = moves[i]
				break
	return nodes


## The padded crosswalk-band rectangles of `node`'s existing approaches
## (city-local XZ `Rect2`s): each band spans CROSSWALK_OUTSET ± half depth
## along its approach axis, padded 0.5 m, and the full road width across,
## padded 0.5 m. The four-way-stop crosswalk yield point-tests bodies against
## these — no raycasts (T-134).
func crosswalk_band_rects(node: Vector2i) -> Array[Rect2]:
	var centers := road_node_coords()
	var pos := Vector2(centers[node.x], centers[node.y])
	var rects: Array[Rect2] = []
	for dir in 4:
		if not approach_exists(node, dir):
			continue
		var u := ROUTE_DIRS[dir]
		var near := CROSSWALK_OUTSET - CROSSWALK_BAND_DEPTH * 0.5 - 0.5
		var far := CROSSWALK_OUTSET + CROSSWALK_BAND_DEPTH * 0.5 + 0.5
		var lo := minf(near, far)
		var hi := maxf(near, far)
		var along_lo: float = pos.x + u.x * lo if u.x != 0 else pos.x - 5.5
		var along_hi: float = pos.x + u.x * hi if u.x != 0 else pos.x + 5.5
		var cross_lo: float = pos.y + u.y * lo if u.y != 0 else pos.y - 5.5
		var cross_hi: float = pos.y + u.y * hi if u.y != 0 else pos.y + 5.5
		rects.append(Rect2(
				Vector2(minf(along_lo, along_hi), minf(cross_lo, cross_hi)),
				Vector2(absf(along_hi - along_lo), absf(cross_hi - cross_lo))))
	return rects

## --- collision -------------------------------------------------------------


## One StaticBody3D per group name (T-093): every collider the world builds is
## a positioned CollisionShape3D child of its group's single body instead of a
## single-shape body of its own — same layer (1 `world`), same mask (0). The
## AmesWorld build hangs its ground plate on it.
func _group(group: String) -> StaticBody3D:
	if not _static_root.has_node(group):
		var body := StaticBody3D.new()
		body.name = group
		body.collision_layer = 1 ## world
		body.collision_mask = 0
		_static_root.add_child(body)
	return _static_root.get_node(group) as StaticBody3D


## One box collider in `group`'s body: a CollisionShape3D carrying the box at
## `pos`, yaw-rotated (`yaw` — bench colliders pass one). Returns the shape.
func _add_collider(group: String, size: Vector3, pos: Vector3, yaw: float = 0.0) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	shape.rotation.y = yaw
	_group(group).add_child(shape)
	return shape

class_name City
extends Node3D
## Procedural city blockout (T-004): builds a street grid of raised blocks with
## sidewalks, building volumes with flat landable roofs, and street props
## (benches, lamp posts, trash bins) at scene load. Every solid element is a
## plain layer-1 (`world`) static body; the visuals are a handful of MultiMeshes
## so the whole city stays well inside the frame budget.
##
## Determinism: the layout is a pure function of `seed_value` — the same seed
## always regenerates the identical city (see `fingerprint`), and every seed
## keeps the M1 guarantees checked by `report()`: a clear spawn plaza, street
## widths fit for flight, roof heights under the cruise floor, and enough
## bread-capable surfaces (benches, sidewalks, roofs, parks) for T-005.

## Per-district facade palettes (T-013): the city reads as neighborhoods from
## the air. The locked low-poly palette colors, regrouped into four district
## families — a building picks its color from its district's palette only, so
## each quadrant wears a coherent range while the whole city stays in style.
## Index with `district_of()`.
const DISTRICT_PALETTES: Array = [
	[Color(0.78, 0.48, 0.38), Color(0.72, 0.4, 0.32), Color(0.84, 0.56, 0.44)], ## Warm brick.
	[Color(0.88, 0.82, 0.68), Color(0.82, 0.73, 0.55), Color(0.9, 0.86, 0.76)], ## Sandy cream.
	[Color(0.52, 0.6, 0.7), Color(0.44, 0.53, 0.64), Color(0.6, 0.67, 0.76)], ## Cool blue-gray.
	[Color(0.55, 0.64, 0.48), Color(0.47, 0.58, 0.43), Color(0.62, 0.69, 0.54)], ## Sage green.
]
const COLOR_ASPHALT := Color(0.29, 0.29, 0.31)
const COLOR_GRASS := Color(0.36, 0.5, 0.30)
const COLOR_SIDEWALK := Color(0.56, 0.55, 0.53)
const COLOR_PLAZA := Color(0.60, 0.57, 0.51)
const COLOR_PARK := Color(0.42, 0.55, 0.34)
const COLOR_ROOF := Color(0.33, 0.33, 0.36)
const COLOR_LANE_MARK := Color(0.85, 0.82, 0.60)
const COLOR_BENCH_WOOD := Color(0.55, 0.38, 0.24)
const COLOR_METAL := Color(0.25, 0.26, 0.28)
const COLOR_BIN := Color(0.16, 0.30, 0.20)
const COLOR_TANK := Color(0.45, 0.53, 0.58) ## Dull plastic rooftop water tanks (T-032).
const COLOR_STONE := Color(0.44, 0.42, 0.38) ## Gray limestone plaza landmark plinth (T-029) — clearly darker than the pale plaza slab.
const COLOR_BRONZE := Color(0.34, 0.26, 0.17) ## Dark oxidized bronze plaza landmark figure (T-029).
const COLOR_LAMP_GLOW := Color(1.0, 0.9, 0.6)
const COLOR_DOOR := Color(0.18, 0.14, 0.12)
const COLOR_SIGNBOARD := Color(0.92, 0.87, 0.74) ## Blank cream signboard plaque over every door (T-090) — clearly lighter than every shopfront band and the dark door slab.
const COLOR_CROSSWALK := Color(0.78, 0.78, 0.75) ## Worn-white zebra paint (T-069) — clearly not the yellow lane mark.
## City-edge rim greens (T-088 commit 1, executing T-047): the hedge band and
## tree crowns must read against the grass apron they sit on — both hold ≥ 0.15
## Euclidean RGB from COLOR_GRASS (0.188 / 0.195 at these values), a floor the
## `city_apron_rim_present` scenario asserts and prints informationally.
const COLOR_RIM_HEDGE := Color(0.24, 0.38, 0.22)
const COLOR_RIM_CROWN := Color(0.22, 0.42, 0.19) ## The hedge green family, a touch deeper.
## Ground-floor shopfront palette (T-017): cafés, bakeries, bookshops and delis,
## so the street level reads as shop rows instead of blank office walls. Kept
## well apart from all four district families (the harness asserts the means
## stay > 0.1 apart in RGB).
const SHOPFRONT_PALETTE: Array[Color] = [
	Color(0.62, 0.28, 0.22), ## Café red-brown.
	Color(0.85, 0.72, 0.45), ## Bakery cream.
	Color(0.34, 0.48, 0.36), ## Bookshop green.
	Color(0.26, 0.42, 0.48), ## Deli teal.
]
## Shopfront door faces: 0=+x 1=-x 2=+z 3=-z — the same order `_add_shopfront`
## indexes its normals with. The T-031 cafe placement reads it too.
const FACE_NORMALS: Array[Vector3] = [
	Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD,
]
## Sidewalk cafe table layout (T-031): the table sits `CAFE_STANDOFF` out from
## the shop-band face plane and `CAFE_SIDE_OFFSET` along the face from the
## (centered) door — corner-ward, the side the `lot_offset` sign picks. Pure
## layout numbers; the placement draws no RNG.
const CAFE_FACE_OUTSET := 0.12 ## The shop band's outset (the `_add_shopfront` band_outset).
const CAFE_STANDOFF := 1.9 ## Table center out from the face plane (m).
const CAFE_SIDE_OFFSET := 2.2 ## Table center along the face from the door center (m).

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
const CROSSWALK_BAR_PITCH := 1.0 ## Bar spacing across the road (m).
const CROSSWALK_BAR_WIDTH := 0.5 ## Bar width across the road (m).

## Rooftop clutter layout (T-032): per building, 1-3 props sit at ±0.25·footprint
## per axis in the three non-(+,+) corner quadrants and one roof crumb at
## ±0.28·footprint in the remaining (+,+) quadrant — both mirrored through the
## lot_offset signs, so the geometry is corner-relative per lot. Since T-051 the
## footprint itself varies per lot and per axis in [0.78, 1.0]·(lot − lot_gap),
## so at the 5.54 m minimum (7.1 × 0.78) prop centers sit √2·0.25·5.54 ≈ 1.96 m
## from the footprint center — the `city_roof_landable` drop point at the exact
## center stays ≥ 0.96 m clear of the worst prop (the 1.4 m water tank's 0.99 m
## half-diagonal) — and the tank keeps 2.77 − 1.385 − 0.7 ≈ 0.685 m inside every
## roof edge. Pure layout numbers: the placement draws no RNG of any stream.
const ROOF_PROP_INSET := 0.25 ## Prop center offset from the footprint center, × footprint.
const ROOF_BREAD_INSET := 0.28 ## Roof crumb offset from the footprint center, × footprint.
const ROOF_PROP_KINDS: Array[String] = ["ac_box", "water_tank", "roof_vent"]
const ROOF_PROP_SIZES: Dictionary = {
	"ac_box": Vector3(1.2, 0.8, 1.2), ## Metal AC unit.
	"water_tank": Vector3(1.4, 2.0, 1.4), ## Dull plastic tank.
	"roof_vent": Vector3(0.5, 0.9, 0.5), ## Metal vent housing.
}

## City-edge rim layout (T-088 commit 1): one hedge band per side on the grass
## apron just outside the outer road edge, plus two trees flanking every street
## exit (`blocks_per_side + 1` road centers per side). RIM_TREE_CLEARANCE is
## measured from the road edge, so tree centers sit `road_width * 0.5 + 1.5` m
## along the side axis from their road center. Pure layout numbers; the
## placement draws no RNG of any stream and appends no `_fp` entry.
const RIM_HEDGE_SETBACK := 0.5 ## Hedge center line out from the outer road edge (m).
const RIM_HEDGE_HEIGHT := 1.2 ## Hedge band height (m).
const RIM_HEDGE_DEPTH := 0.8 ## Hedge band thickness (m).
const RIM_TREE_CLEARANCE := 1.5 ## Tree center clear of the road edge (m).
const RIM_TRUNK_SIZE := Vector3(0.35, 2.2, 0.35) ## Rising from the apron (y 0).
const RIM_CROWN_SIZE := Vector3(2.6, 2.2, 2.6) ## Centered 3.3 m up — sits on the 2.2 m trunk.
const RIM_CROWN_CENTER_Y := 3.3 ## Crown box center height (m).

## Park tree layout (T-030): four trees per park block at the fixed (±5, ±5)
## offsets from the block center — the same trunk/crown recipe as the rim
## trees (T-088), so the whole city wears one tree: bench-wood trunks under
## the hedge-family crown green, which holds 0.28 Euclidean RGB from COLOR_PARK
## (the lawn) so crowns read against their own grass. Fully inside the block
## (5.0 + 1.3 = 6.3 m < the 11.0 m half footprint) and ≥ 1.5 m clear of
## everything `_build_block_props` shares the block with — worst approach is a
## max-jitter bin at (8, 8), 4.24 m center-to-center from the (5, 5) tree,
## vs the crown's 1.84 m horizontal half-diagonal plus a ~0.9 m worst prop
## half-extent. Pure layout numbers; the placement draws no RNG of any stream
## and appends no `_fp` entry (the T-020 `elder_spots` precedent), so the
## layout fingerprint stays byte-identical to pre-T-030 builds; visual-only
## (the T-017 decision), pinned by the `city_park_trees_present` scenario.
const PARK_TREE_OFFSET := 5.0 ## Tree center out from the block center, per axis (m).
const PARK_TRUNK_SIZE := Vector3(0.35, 2.2, 0.35) ## Rising from the slab.
const PARK_CROWN_SIZE := Vector3(2.6, 2.2, 2.6) ## Centered 3.3 m up — sits on the 2.2 m trunk.
const PARK_CROWN_CENTER_Y := 3.3 ## Crown box center height above the slab top (m).

## District anchor layout (T-091): one tall clock post per district quadrant, at
## the pinned blocks' alley-cross centers — the one spot on EVERY block the
## layout math keeps clear (lot centers sit ±4.25 m out per axis, footprints are
## ≤ 7.1 m wide, so every building's inner face stays 0.70–1.48 m off the block
## center per axis; block props sit ≥ 8 m out, the ground bread ring ≥ 6.5 m per
## axis and the tourist loop on the 10.9 m curb line). The gate sits OUTSIDE the
## plaza/park/building branch, so the post stands in parks too — the (±5, ±5)
## park trees leave 5.0 − 1.84 crown half-diagonal − 0.99 plinth half-diagonal
## ≈ 2.2 m per axis clear. The ANCHOR_BLOCKS pins assume the M1 `blocks_per_side`
## 7. Four tiers of MultiMesh boxes rise from the slab top — plinth, shaft,
## head, cap — the cap's top face (slab + 17.3 m) the landable pad, under
## `max_roof_height` and the 23 m autoplay cruise floor. Zero RNG of any stream
## (no draw touches `_rng`/`_shop_rng`) and exactly one `_fp` entry per anchor,
## so every seeded sequence and every pinned count stays byte-identical and the
## fingerprint tracks the anchors' positions. The anchors deliberately do NOT
## feed `_max_roof` — the `city_district_anchors_present` scenario re-pins
## `report.max_roof_height` to the building roofs so the rule is guarded. The
## head wears the district's first `DISTRICT_PALETTES` color so the quadrant
## reads from the air.
const ANCHOR_BLOCKS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(5, 1), Vector2i(1, 5), Vector2i(5, 5),
]
const ANCHOR_PLINTH_SIZE := Vector3(1.4, 1.0, 1.4) ## Alley-cross footing, rising from the slab.
const ANCHOR_SHAFT_SIZE := Vector3(0.7, 13.6, 0.7) ## The post — slab+1.0 up to slab+14.6.
const ANCHOR_HEAD_SIZE := Vector3(1.8, 2.2, 1.8) ## The clock/bell housing — district-tinted.
const ANCHOR_CAP_SIZE := Vector3(2.0, 0.5, 2.0) ## The landable pad.
const ANCHOR_CRUMB_LIFT := 0.06 ## Crumb height above the cap's top face (the T-032 roof-crumb pattern).

## Distant skyline layout (T-088 commit 2): a ring of flat-shaded background
## towers on the grass apron — the horizon reads as a larger city under haze
## instead of a void edge. Placement is a deterministic hash chain (one
## `_skyline_roll` per attribute, each with its own salt): ZERO draws from
## `_rng`/`_shop_rng` (both sequences stay byte-identical), ZERO `_fp` entries
## and ZERO `_add_collider` calls (visual-only, the T-017 decision — colliders
## live only under `Static`).
const SKYLINE_COUNT := 64 ## Total background towers (the harness gates [40, 80]).
const SKYLINE_TALL_TARGET := 6 ## Landmark towers the class roll aims at (the harness gates [2, 8]).
const SKYLINE_SALT_RADIUS := 101
const SKYLINE_SALT_ANGLE := 211
const SKYLINE_SALT_CLASS := 307
const SKYLINE_SALT_HEIGHT := 401
const SKYLINE_SALT_WIDTH := 503
const SKYLINE_SALT_SHADE := 601

## Plaza landmark layout (T-029): a bronze pigeon on a limestone plinth at the
## exact center of the spawn plaza — the square's heart, the one fixed volume
## to steer home by. Built from fixed offsets at the plaza center like every
## city visual: ZERO draws from `_rng`/`_shop_rng` and exactly one `_fp` entry
## (`["landmark", center.x, center.z]`), so the RNG streams stay byte-identical
## and the fingerprint tracks the anchor's position. The plinth is landable
## through ONE layer-1 `Props` collider (the bench pattern) whose top face is
## the cap top at `block_slab_height + LANDMARK_PLINTH_TOP`; the figure above
## stays visual-only (the T-017 awning decision) — flight passes through it
## rather than snagging at perch-climb altitude. Total top
## `block_slab_height + LANDMARK_FIGURE_TOP` ≈ 5.07 m: under the ticket's 5.5 m
## bar, deep inside the 12 m spawn-clear guarantee and far below both
## `max_roof_height` and the 23 m cruise floor.
const LANDMARK_PLINTH_BASE := Vector3(2.4, 0.9, 2.4) ## Plinth base box, rising from the slab.
const LANDMARK_PLINTH_CAP := Vector3(1.8, 1.1, 1.8) ## Plinth cap box on the base — its top is the landing surface.
const LANDMARK_PLINTH_TOP := 2.0 ## Cap top above the slab top (m) — base 0.9 + cap 1.1.
const LANDMARK_FIGURE_TOP := 4.95 ## Figure's highest point above the slab top (m) — a ~3 m pigeon on the cap.

@export_group("Layout")
## Fixed M1 seed — same city every run so runs and scores stay comparable.
@export var seed_value: int = 20260928
@export var blocks_per_side: int = 7 ## City is blocks_per_side squared blocks.
@export var block_size: float = 22.0 ## Full block footprint including the sidewalk ring (m).
@export var road_width: float = 10.0 ## Street width between blocks (m).
@export var ground_extra: float = 250.0 ## Grass apron beyond the city edge on each side (m).

@export_group("Guarantees")
## report() flags a city whose streets are narrower than this as unflyable.
@export var min_flyable_street: float = 8.0
## report() flags roofs taller than this; the autoplay pilot cruises just above it.
@export var max_roof_height: float = 20.0
## Minimum count of landable/eatable surfaces report() must guarantee.
@export var min_bread_surfaces: int = 150
## No building footprint may come this close to the plaza center (m).
@export var spawn_clear_radius: float = 12.0

@export_group("Surfaces")
@export var sidewalk_width: float = 2.5 ## Raised sidewalk ring inside each block edge (m).
## Top of the raised block slab — sidewalk and courtyards (m). Steps stay below
## r·(1−cos45°) ≈ 0.09 m for the 0.3 m pigeon collider: taller curbs are walls,
## shorter ones roll under the sphere so the waddle climbs them.
@export var block_slab_height: float = 0.12
@export var road_slab_height: float = 0.05 ## Top of the asphalt slab (m).
@export var roof_slab_height: float = 0.25 ## Thickness of the roof cap on every building (m).

@export_group("Buildings")
@export var floor_height: float = 3.0 ## Roof heights are whole floors of this height.
@export var building_floors_min: int = 2
@export var building_floors_max: int = 6
@export var lot_gap: float = 1.4 ## Alley between buildings inside one block (m).
@export var park_chance: float = 0.12 ## Chance a non-plaza block comes up as an open park.

@export_group("Spawn")
## Height above the road surface the pigeon drops in from. Keep small: the
## spawn drop is straight down, so anything tall turns into a skid.
@export var spawn_drop_height: float = 0.6

@export_group("Props")
@export var bench_chance: float = 0.75 ## Chance each block edge gets a bench.
@export var bin_chance: float = 0.6 ## Chance each block gets a trash bin.

@export_group("Shopfronts")
@export var awning_chance: float = 0.6 ## Share of buildings whose shop door gets an awning (T-017).

@export_group("Traffic")
## Driving-lane center beyond the block edge (m) — ring-road corners sit at
## this offset. With the 1.9 m car width this keeps ~0.55 m to the parked
## cars and a ~1.1 m center gap to the oncoming lane.
@export var traffic_lane_offset: float = 3.5
## Parking-lane center beyond the block edge (m) — parked cars sit a hand's
## width off the curb, outside the driving lane.
@export var parking_offset: float = 1.05

## Where the pigeon starts: plaza center plus the spawn drop (global coords).
var spawn_point: Vector3
## Hash of the whole generated layout; equal fingerprints mean an identical city.
var fingerprint: int = 0
## One entry per building: `center` (global footprint center), `size` (XZ
## footprint), `top` (global roof height), plus the T-013 palette members
## (`district`, `color`) and the T-017 shopfront members (`lot_offset`,
## `shop_color`, `door_face`, `has_awning`). Tests and later tickets read this.
var buildings: Array[Dictionary] = []
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

## Seated spots (city-local) for the park elders (T-020): one transform per
## plaza-ring bench — position on the seat line, yaw = the bench's own. Purely
## derived from the layout — no RNG of its own — so it is deterministic per
## seed and never shifts the layout RNG sequence.
var elder_spots: Array[Transform3D] = []

## Seated spots (city-local) for the sidewalk cafes (T-031): one transform per
## awninged building — table center on the sidewalk in front of the shop door,
## yaw facing the street. Appended after the block loop from the public
## `buildings[]` data by pure math, zero RNG of any stream, so the layout
## fingerprints and the pinned awning count stay byte-identical.
var cafe_spots: Array[Transform3D] = []

## Rooftop clutter (T-032): one entry per roof prop, appended in
## `_add_building()` — `center` (global prop center), `size` (prop box),
## `top` (global y of the prop's top face) and `kind` (`ac_box`,
## `water_tank` or `roof_vent`). Pure layout math from the building's own
## record (floors, footprint, lot_offset): zero RNG of any stream and no `_fp`
## entry, so the layout fingerprint stays byte-identical to pre-T-032 builds;
## the props are pinned by the `city_roofs_inhabited` scenario, like
## `cafe_spots`.
var roof_props: Array[Dictionary] = []

## District anchors (T-091): one record per pinned anchor post, appended by
## `_build_district_anchor` — `center` (global), `district`, `top` (the anchor's
## total height above the slab top: the pure tier-constant sum, 17.3 m at the
## defaults) and `cap_top` (global y of the cap's top face — the landing
## surface). Pure layout math at fixed block centers: zero RNG of any stream
## and exactly one `_fp` entry per anchor, so the layout fingerprint tracks the
## anchors while every seeded stream stays byte-identical. The anchors are NOT
## folded into `_max_roof` (see the `ANCHOR_BLOCKS` const note); the
## `city_district_anchors_present` scenario pins that rule.
var anchors: Array[Dictionary] = []

## City-edge rim (T-088 commit 1): one transform per hedge band — origin at the
## band's box center on the boundary line, basis scale = its oriented
## (city_span, 1.2, 0.8) size — and, in `rim_tree_spots`, one per rim tree.
## Appended by `_build_rim()` as pure functions of the grid constants, the
## `elder_spots`/`cafe_spots`/`roof_props` precedent: zero RNG of any stream,
## zero `_fp` entries and zero colliders, so the layout fingerprint stays
## byte-identical to pre-T-088 builds; pinned by the `city_apron_rim_present`
## scenario.
var rim_hedge_spots: Array[Transform3D] = []

## The rim trees of the same pass (see `rim_hedge_spots`): origin at the trunk
## base on the apron (y 0) — the trunk mesh rises 2.2 m from it and the crown
## is centered 3.3 m up.
var rim_tree_spots: Array[Transform3D] = []

## Center (city-local) of every generated block — the tourist service (T-007)
## picks its sidewalk walking loops from these.
var block_centers: Array[Vector3] = []

## Center-to-center distance between neighboring blocks (m).
var block_pitch: float:
	get: return block_size + road_width

## Full city span across, outer ring roads included (m).
var city_span: float:
	get: return blocks_per_side * block_pitch + road_width

var _rng := RandomNumberGenerator.new()
## Dedicated stream for the T-017 shopfront decoration: seeding it separately
## keeps the layout stream (floors, colors, lots, parks, props) byte-identical
## to the pre-shopfront city — only the decoration and the fingerprint entries
## it appends are new.
var _shop_rng := RandomNumberGenerator.new()
var _meshes: Dictionary = {} ## MultiMesh key -> shared unit BoxMesh for that key.
var _visuals: Dictionary = {} ## MultiMesh key -> {xfs: Array, colors: Array}.
var _static_root: Node3D
var _visual_root: Node3D
var _counts: Dictionary = {}
var _fp: Array = []
var _max_roof: float = 0.0
var _plaza_clear: bool = true
var _plaza_center := Vector3.ZERO


func _ready() -> void:
	generate()


## Rebuilds the whole city for `new_seed`. Deterministic: the same seed always
## produces the same fingerprint. Safe to call again at any time (restart flow,
## sim harness determinism checks).
##
## Same-seed fast path (T-033): when a build already stands (`fingerprint != 0`)
## and `new_seed` equals its seed, the rebuild is skipped entirely — the layout
## is a pure function of the seed, so the standing build IS the rebuild output
## (`city_same_seed_deterministic` proves it byte-identical). `regenerated`
## still emits, because that is what a restart actually needs: the spawners
## re-seed fresh nodes off it. `force_rebuild = true` opts out — the sim
## harness's determinism scenarios use it so "a real rebuild reproduces X"
## keeps proving a real rebuild.
func generate(new_seed: int = seed_value, force_rebuild: bool = false) -> void:
	if fingerprint != 0 and new_seed == seed_value and not force_rebuild:
		regenerated.emit()
		return
	seed_value = new_seed
	build_count += 1
	_clear()
	_rng.seed = seed_value
	_shop_rng.seed = seed_value
	_meshes = {}
	_visuals = {}
	_counts = {"buildings": 0, "parks": 0, "benches": 0, "lamps": 0, "bins": 0}
	_fp = []
	_max_roof = 0.0
	_plaza_clear = true
	buildings = []
	bread_spots = []
	elder_spots = []
	cafe_spots = []
	roof_props = []
	anchors = []
	rim_hedge_spots = []
	rim_tree_spots = []
	block_centers = []
	_static_root = Node3D.new()
	_static_root.name = "Static"
	add_child(_static_root)
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	var plaza_i := int(roundf((blocks_per_side - 1) * 0.5))
	_plaza_center = _block_center(plaza_i, plaza_i)
	_make_meshes()
	_build_ground()
	_build_skyline() ## T-088 commit 2 — the distant background towers, visual-only.
	_build_roads()
	_build_rim() ## T-088 commit 1 — the city-edge rim, visual-only.
	_build_crossings() ## T-069 — intersection paint, visual-only.
	for bx in blocks_per_side:
		for bz in blocks_per_side:
			_build_block(bx, bz, bx == plaza_i and bz == plaza_i)
	_build_cafe_spots() ## T-031 — after the block loop, from the buildings[] records.
	_spawn_visuals()
	## Spawn on the road centerline next to the plaza, facing along the street:
	## roads are the one corridor guaranteed clear of buildings at every
	## height, so the opening climb is always safe.
	spawn_point = to_global(_plaza_center
			+ Vector3(block_size * 0.5 + road_width * 0.5, spawn_drop_height, 0.0))
	fingerprint = _fp.hash()
	last_report = _make_report()
	regenerated.emit()


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_static_root = null
	_visual_root = null


## --- layout math ---------------------------------------------------------


func _block_center(ix: int, iz: int) -> Vector3:
	var half := (blocks_per_side - 1) * 0.5
	return Vector3((ix - half) * block_pitch, 0.0, (iz - half) * block_pitch)


## Which district a block belongs to: the city's four quadrants (the middle
## column/row folds into the east/south side). A pure function of the block
## coordinates, so the district map is deterministic per seed.
func district_of(bx: int, bz: int) -> int:
	var half := (blocks_per_side - 1) * 0.5
	return (0 if bx <= half else 1) + (0 if bz <= half else 2)


## Stable per-lot, per-axis footprint scale (T-051): a pure hash fold of
## (block x/z, quadrant, axis, seed) mapped to [0.78, 1.0], so building
## footprints vary — some squat-wide, some slim, occasional near-full-lot slabs
## — without the roofscape reading as a waffle grid of equal squares. ZERO
## draws from `_rng`/`_shop_rng` (the hash chain `_skyline_roll` precedent):
## every seeded roll keeps its exact place in its stream, so the floor tally,
## the palette draws and the pinned 104-of-146 awning count stay byte-identical.
## The scale never exceeds 1.0, so a footprint never grows past
## `lot - lot_gap` — alleys only widen and every layout guarantee (clear
## plaza, flyable streets, capped roofs, bread surfaces) holds by
## construction. Deterministic and machine-recomputable: the sim harness
## owns its copy of this fold (`city_footprints_vary`).
func _lot_footprint_scale(bx: int, bz: int, qx: int, qz: int, axis: int) -> float:
	var h := hash(Vector4i(bx, bz, qx * 2 + qz, axis + 1))
	h = hash(h ^ seed_value)
	return 0.78 + 0.22 * float(h % 1001) / 1000.0


## --- construction --------------------------------------------------------


## Waypoint loop (city-local) for one block's tourists (T-007): a rectangle on
## the sidewalk's outer curb line. The radius matters: the loop's legs must be
## clear of everything that shares the block. Buildings reach 7.8 m from the
## block center, benches sit 9.5–10.0 m out along the edges, lamps and bins
## crowd the diagonals up to ~10.3 m — so the only band where the sides AND
## the corners stay clear is the curb line just inside the slab edge (11.0 m):
## sides keep ~0.6–0.9 m off every prop, corners ~0.9 m off the worst-case
## (max-jitter) corner bin. Anything tighter (e.g. a diamond through the edge
## midpoints) chords straight through the building footprints.
func sidewalk_loop(center: Vector3) -> PackedVector3Array:
	var ring := block_size * 0.5 - 0.1
	var y := block_slab_height
	return PackedVector3Array([
		center + Vector3(ring, y, ring),
		center + Vector3(-ring, y, ring),
		center + Vector3(-ring, y, -ring),
		center + Vector3(ring, y, -ring),
	])


## Four sidewalk spots per block for bread crumbs (T-005), placed at the
## diagonal corners of the sidewalk ring: off the bench line (benches slide
## ±4 m along each edge plus their seat length) and clear of the corner lamps
## and bins, so a crumb never spawns inside a prop.
func _bread_ring_spots(center: Vector3) -> void:
	var ring := block_size * 0.5 - sidewalk_width * 0.5
	var mid := block_size * 0.5 - 4.5
	var y := block_slab_height + 0.06
	for sx: float in [ring, -ring]:
		for sz: float in [mid, -mid]:
			bread_spots.append(center + Vector3(sx, y, sz))
			bread_spots.append(center + Vector3(sz, y, sx))


## Corner waypoints (city-local) for one block's traffic loop (T-008): the
## ring road around the block, right-hand traffic. The traversal order turns
## right at every corner, so of the four loops meeting at an intersection each
## cuts a disjoint corner (offsets ±traffic_lane_offset sit 3 m apart against
## a 1.9 m car width) — cross traffic can never meet, it can only queue.
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
## layout — no RNG — so it is deterministic per seed.
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


## One shared unit BoxMesh per visual key; instances scale it via their transform.
func _make_meshes() -> void:
	_meshes = {
		"road": _unit_box(_flat_material(COLOR_ASPHALT)),
		"dash": _unit_box(_flat_material(COLOR_LANE_MARK)),
		"crosswalk": _unit_box(_flat_material(COLOR_CROSSWALK)),
		"slab": _unit_box(_vertex_color_material()),
		"roof": _unit_box(_flat_material(COLOR_ROOF)),
		"bench_seat": _unit_box(_flat_material(COLOR_BENCH_WOOD)),
		"bench_leg": _unit_box(_flat_material(COLOR_METAL)),
		"lamp_post": _unit_box(_flat_material(COLOR_METAL)),
		"lamp_head": _unit_box(_glow_material(COLOR_LAMP_GLOW)),
		"bin": _unit_box(_flat_material(COLOR_BIN)),
		"shopfront": _unit_box(_vertex_color_material()),
		"awning": _unit_box(_vertex_color_material()),
		"door": _unit_box(_flat_material(COLOR_DOOR)),
		"sign": _unit_box(_flat_material(COLOR_SIGNBOARD)),
		"ac_box": _unit_box(_flat_material(COLOR_METAL)),
		"water_tank": _unit_box(_flat_material(COLOR_TANK)),
		"roof_vent": _unit_box(_flat_material(COLOR_METAL)),
		"rim_hedge": _unit_box(_flat_material(COLOR_RIM_HEDGE)),
		"rim_trunk": _unit_box(_flat_material(COLOR_BENCH_WOOD)),
		"rim_crown": _unit_box(_flat_material(COLOR_RIM_CROWN)),
		"tree_trunk": _unit_box(_flat_material(COLOR_BENCH_WOOD)),
		"tree_crown": _unit_box(_flat_material(COLOR_RIM_CROWN)),
		"skyline": _unit_box(_vertex_color_material()),
		"skyline_tall": _unit_box(_vertex_color_material()),
		"plinth": _unit_box(_flat_material(COLOR_STONE)),
		"figure": _unit_box(_flat_material(COLOR_BRONZE)),
		"anchor_plinth": _unit_box(_flat_material(COLOR_STONE)),
		"anchor_shaft": _unit_box(_flat_material(COLOR_METAL)),
		"anchor_head": _unit_box(_vertex_color_material()),
		"anchor_cap": _unit_box(_flat_material(COLOR_STONE)),
	}
	## Facades (T-049): one key per floor count a building can have — each its
	## own material drawing exactly that many window rows, so a BoxMesh face
	## maps one row per real floor instead of one fixed sticker at five scales.
	for f: int in range(building_floors_min, building_floors_max + 1):
		_meshes["facade%d" % f] = _unit_box(_facade_material(f))


func _build_ground() -> void:
	var size := city_span + ground_extra * 2.0
	_add_collider("Ground", Vector3(size, 1.0, size), Vector3(0.0, -0.5, 0.0))
	## T-093 ground-mesh trap: the grass visual used to ride the old
	## single-shape ground body — body at (0, -0.5, 0), mesh local (0, -0.5, 0),
	## world (0, -1.0, 0), half a metre below the collision surface at y 0.
	## The merged Ground body sits at the group origin, so parenting the mesh
	## explicitly under it (decision: stays with its collider) at city-local
	## (0.0, -1.0, 0.0) keeps it exactly where it has always been; the old
	## LOCAL offset here would raise the grass slab 0.5 m into the roads,
	## sidewalks and the plaza — invisible to every headless scenario.
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, 1.0, size)
	mesh.material = _flat_material(COLOR_GRASS)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, -1.0, 0.0)
	_group("Ground").add_child(mesh_instance)
	_fp.append(["ground", size])


## One normalized [0, 1] roll of the skyline's deterministic hash chain (T-088
## commit 2): folds `hash(Vector3i(i, seed_value, salt))` — a pure function of
## the tower index, the seed and the attribute's salt. No RNG stream is
## touched, so `_rng`/`_shop_rng` sequences and the layout fingerprint stay
## byte-identical to pre-T-088 builds.
func _skyline_roll(i: int, salt: int) -> float:
	return float(hash(Vector3i(i, seed_value, salt)) & 0x7fffffff) / 2147483647.0


## Distant skyline (T-088 commit 2, executing T-050): a ring of slim background
## towers on the apron, every origin at ground radius
## [city_span * 0.5 + ground_extra * 0.3, city_span * 0.5 + ground_extra - 20.0]
## (192-347 m at defaults — beyond the blocks, ON the apron box; the planning
## sketch's 1.3-2.2x span overran the apron edge, so the top of the range is
## clamped). Heights 15-60 m with the `skyline_tall` landmarks at 40-60, XZ
## footprints 6-18 m, muted DISTRICT_PALETTES members darkened() 0.30-0.45 —
## the tower's angle quadrant picks its district family, so the ring reads as
## the city's wider surroundings. Box origins sit at height/2: the apron top
## is y 0, the towers rise from the grass. Zero RNG draws from any stream,
## zero `_fp` entries, zero colliders (visual-only, the T-017 decision);
## pinned by the `city_horizon_skyline` scenario.
func _build_skyline() -> void:
	var half := city_span * 0.5
	var inner := half + ground_extra * 0.3
	var outer := half + ground_extra - 20.0
	for i in SKYLINE_COUNT:
		var radius := inner + _skyline_roll(i, SKYLINE_SALT_RADIUS) * (outer - inner)
		var angle := _skyline_roll(i, SKYLINE_SALT_ANGLE) * TAU
		var tall := _skyline_roll(i, SKYLINE_SALT_CLASS) \
				< float(SKYLINE_TALL_TARGET) / float(SKYLINE_COUNT)
		var height: float = 40.0 + _skyline_roll(i, SKYLINE_SALT_HEIGHT) * 20.0
		if not tall:
			height = 15.0 + _skyline_roll(i, SKYLINE_SALT_HEIGHT) * 30.0
		var width := 6.0 + _skyline_roll(i, SKYLINE_SALT_WIDTH) * 12.0
		var pos := Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius)
		var palette: Array = DISTRICT_PALETTES[int(angle / (PI * 0.5)) % 4]
		var shade: Color = (palette[i % palette.size()] as Color).darkened(
				0.3 + _skyline_roll(i, SKYLINE_SALT_SHADE) * 0.15)
		_add_mm("skyline_tall" if tall else "skyline",
				_box_xf(pos, Vector3(width, height, width)), shade)


## Streets: two slab families (5 mm apart at crossings to avoid z-fighting),
## plus dashed lane marks that skip the intersections.
func _build_roads() -> void:
	var half := city_span * 0.5
	var centers: Array[float] = []
	for i in blocks_per_side + 1:
		centers.append(-half + road_width * 0.5 + i * block_pitch)
	for c: float in centers:
		var v_size := Vector3(road_width, road_slab_height, city_span)
		_add_mm("road", _box_xf(Vector3(c, road_slab_height * 0.5, 0.0), v_size))
		_add_collider("Roads", v_size, Vector3(c, road_slab_height * 0.5, 0.0))
		var h_size := Vector3(city_span, road_slab_height, road_width)
		_add_mm("road", _box_xf(Vector3(0.0, road_slab_height * 0.5 - 0.005, c), h_size))
		## Colliders stay flush with the vertical slabs: the 5 mm visual offset
		## (z-fighting) must not become a physical lip at every crossing — the
		## box-shaped car collider (T-008) can't climb even a 5 mm seam.
		_add_collider("Roads", h_size, Vector3(0.0, road_slab_height * 0.5, c))
		var z := -half + 3.0
		while z < half - 3.0:
			if not _near_road(z, centers):
				_add_mm("dash", _box_xf(
						Vector3(c, road_slab_height + 0.005, z), Vector3(0.15, 0.01, 1.8)))
				_add_mm("dash", _box_xf(
						Vector3(z, road_slab_height - 0.005 + 0.005, c), Vector3(1.8, 0.01, 0.15)))
			z += 4.0
	_fp.append(["roads", city_span, road_width])


func _near_road(z: float, centers: Array[float]) -> bool:
	for c: float in centers:
		if absf(z - c) < road_width * 0.5 + 1.5:
			return true
	return false


## Zebra crosswalks (T-069, longitudinal bars per T-102): one bar-tiled band
## per unblocked intersection approach, painted like the lane dashes — queued
## MultiMesh instances, no new nodes per bar, and ZERO colliders (the T-017
## visual-only decision), so cars and pigeon never sense the paint. Zero RNG
## draws and zero `_fp.append` calls (the T-031 precedent): the fingerprint and
## every RNG stream stay byte-identical to pre-T-069 builds. The dash gate
## (`_near_road`) already skips everything within `road_width * 0.5 + 1.5` =
## 6.5 m of a node, so the bands never overlap a center dash — the nearest dash
## sits 10.0 m out and its 1.8 m length stops 9.1 m out, 1.7 m clear of the
## band's 7.4 m outer edge.
func _build_crossings() -> void:
	var half := city_span * 0.5
	var centers: Array[float] = []
	for i in blocks_per_side + 1:
		centers.append(-half + road_width * 0.5 + i * block_pitch)
	## How far the band reaches from the node: band center plus half depth
	## (6.2 + 2.4 * 0.5 = 7.4 m at the defaults).
	var reach := CROSSWALK_OUTSET + CROSSWALK_BAND_DEPTH * 0.5
	for cx: float in centers:
		for cz: float in centers:
			## Approaches along x — bands on the horizontal road (its centerline
			## is z = cz), heights from the horizontal-dash recipe. Skips the
			## rim's outward +x / -x approaches: the road ends at ±half and the
			## stripes would paint grass.
			if cx + reach <= half:
				_add_crosswalk_band(Vector3(cx, 0.0, cz), true, 1.0)
			if cx - reach >= -half:
				_add_crosswalk_band(Vector3(cx, 0.0, cz), true, -1.0)
			## Approaches along z — bands on the vertical road (centerline
			## x = cx), heights from the vertical-dash recipe.
			if cz + reach <= half:
				_add_crosswalk_band(Vector3(cx, 0.0, cz), false, 1.0)
			if cz - reach >= -half:
				_add_crosswalk_band(Vector3(cx, 0.0, cz), false, -1.0)


## Queues one band's bars for one intersection approach (T-069, T-102).
## `along_x` picks the road family the band paints (true = the horizontal road
## the ±x approaches cross), `side` the approach direction. The band is one
## CROSSWALK_BAND_DEPTH-deep run of road centered CROSSWALK_OUTSET out from the
## node on the road centerline; its bars run WITH the road and repeat ACROSS it
## at CROSSWALK_BAR_PITCH on centers, each CROSSWALK_BAR_WIDTH across x 0.01
## thick, 5 mm proud of its slab family.
func _add_crosswalk_band(node: Vector3, along_x: bool, side: float) -> void:
	var bars := int(road_width / CROSSWALK_BAR_PITCH)
	var out := side * CROSSWALK_OUTSET
	for j in bars:
		var across := (float(j) - (float(bars) - 1.0) * 0.5) * CROSSWALK_BAR_PITCH
		var size := Vector3(CROSSWALK_BAND_DEPTH, 0.01, CROSSWALK_BAR_WIDTH) if along_x \
				else Vector3(CROSSWALK_BAR_WIDTH, 0.01, CROSSWALK_BAND_DEPTH)
		var y := road_slab_height if along_x else road_slab_height + 0.005
		var pos := node + (Vector3(out, y, across) if along_x else Vector3(across, y, out))
		_add_mm("crosswalk", _box_xf(pos, size))


## City-edge rim (T-088 commit 1, executing T-047): a low hedge band on the
## grass apron just outside the outer road edge — the boundary's at-a-glance
## "in town / at the rim / gone" read at cruise — plus two trees flanking every
## street exit, marking where a street still leads home. Pure layout math on
## the grid constants, the `elder_spots`/`cafe_spots`/crosswalk precedent:
## ZERO RNG draws (every stream stays byte-identical), ZERO `_fp` entries (the
## fingerprint stays byte-identical to pre-T-088 builds) and ZERO
## `_add_collider` calls (visual-only, the T-017 decision). Small corner gaps
## where the four hedge sides meet are accepted.
func _build_rim() -> void:
	var edge := city_span * 0.5
	var hedge_line := edge + RIM_HEDGE_SETBACK
	var tree_offset := road_width * 0.5 + RIM_TREE_CLEARANCE
	for side: int in 4: ## 0=+x 1=-x 2=+z 3=-z — the FACE_NORMALS order.
		var normal: Vector3 = FACE_NORMALS[side]
		var along := Vector3(-normal.z, 0.0, normal.x) ## The side axis.
		var hedge_xf := _box_xf(
				normal * hedge_line + Vector3.UP * (RIM_HEDGE_HEIGHT * 0.5),
				along.abs() * city_span + Vector3.UP * RIM_HEDGE_HEIGHT
						+ normal.abs() * RIM_HEDGE_DEPTH)
		_add_mm("rim_hedge", hedge_xf)
		rim_hedge_spots.append(hedge_xf)
		for i in blocks_per_side + 1:
			var road_center := -edge + road_width * 0.5 + i * block_pitch
			for s: float in [1.0, -1.0]:
				var pos := normal * hedge_line + along * (road_center + s * tree_offset)
				rim_tree_spots.append(Transform3D(Basis.IDENTITY, pos))
				_add_mm("rim_trunk", _box_xf(
						pos + Vector3.UP * (RIM_TRUNK_SIZE.y * 0.5), RIM_TRUNK_SIZE))
				_add_mm("rim_crown", _box_xf(
						pos + Vector3.UP * RIM_CROWN_CENTER_Y, RIM_CROWN_SIZE))


func _build_block(bx: int, bz: int, is_plaza: bool) -> void:
	var center := _block_center(bx, bz)
	var is_park: bool = (not is_plaza) and _rng.randf() < park_chance
	var slab_color := COLOR_PLAZA if is_plaza else (COLOR_PARK if is_park else COLOR_SIDEWALK)
	var slab_size := Vector3(block_size, block_slab_height, block_size)
	_add_mm("slab", _box_xf(center + Vector3(0.0, block_slab_height * 0.5, 0.0), slab_size), slab_color)
	_add_collider("Blocks", slab_size, center + Vector3(0.0, block_slab_height * 0.5, 0.0))
	_fp.append(["slab", center.x, center.z, is_plaza, is_park])
	_bread_ring_spots(center)
	block_centers.append(center)
	if is_plaza:
		_build_plaza(center)
	elif is_park:
		_counts.parks += 1
		_build_park_trees(center)
	else:
		_build_block_buildings(center, district_of(bx, bz), bx, bz)
	## District anchor (T-091) — OUTSIDE the plaza/park/building branch, so the
	## post stands in parks too (the pinned blocks' alley cross is clear there
	## by the same layout math; see the ANCHOR_BLOCKS const note).
	if ANCHOR_BLOCKS.has(Vector2i(bx, bz)):
		_build_district_anchor(center, district_of(bx, bz))
	_build_block_props(center, is_plaza)


## Park trees (T-030): four per park block at the fixed (±PARK_TREE_OFFSET,
## ±PARK_TREE_OFFSET) offsets — the vacant-lot fix, a grove read from the air.
## Trunks rise from the slab, crowns sit on them (crown bottom at trunk top),
## all visual-only so the pigeon brushes through at park-cruise altitude (the
## T-017 awning decision). Zero RNG and zero `_fp` entries: the park branch's
## only draw remains the park roll in `_build_block`, and every tree position
## is a pure function of the block center — the layout fingerprint stays
## byte-identical to pre-T-030 builds. Pinned by `city_park_trees_present`.
func _build_park_trees(center: Vector3) -> void:
	for sx: float in [PARK_TREE_OFFSET, -PARK_TREE_OFFSET]:
		for sz: float in [PARK_TREE_OFFSET, -PARK_TREE_OFFSET]:
			var base := center + Vector3(sx, block_slab_height, sz)
			_add_mm("tree_trunk", _box_xf(
					base + Vector3.UP * (PARK_TRUNK_SIZE.y * 0.5), PARK_TRUNK_SIZE))
			_add_mm("tree_crown", _box_xf(
					base + Vector3.UP * PARK_CROWN_CENTER_Y, PARK_CROWN_SIZE))


## One district anchor (T-091): the four-tier clock post at `center` (a block
## center), its head tinted `district`'s first palette color so the quadrant
## reads. Tiers stack from the slab top; every tier carries its own layer-1
## `Props` box (the T-093 shape-per-group pattern — the cap's top face is the
## landing surface). Appends the cap crumb to `bread_spots` (the T-032
## roof-crumb pattern) and the record to `anchors`, and leaves the one `["anchor",
## center.x, center.z, district]` `_fp` entry — zero RNG of any stream.
func _build_district_anchor(center: Vector3, district: int) -> void:
	var palette: Array = DISTRICT_PALETTES[district]
	var head_color: Color = palette[0]
	var y := block_slab_height
	var pos := center + Vector3(0.0, y + ANCHOR_PLINTH_SIZE.y * 0.5, 0.0)
	_add_mm("anchor_plinth", _box_xf(pos, ANCHOR_PLINTH_SIZE))
	_add_collider("Props", ANCHOR_PLINTH_SIZE, pos)
	y += ANCHOR_PLINTH_SIZE.y
	pos = center + Vector3(0.0, y + ANCHOR_SHAFT_SIZE.y * 0.5, 0.0)
	_add_mm("anchor_shaft", _box_xf(pos, ANCHOR_SHAFT_SIZE))
	_add_collider("Props", ANCHOR_SHAFT_SIZE, pos)
	y += ANCHOR_SHAFT_SIZE.y
	pos = center + Vector3(0.0, y + ANCHOR_HEAD_SIZE.y * 0.5, 0.0)
	_add_mm("anchor_head", _box_xf(pos, ANCHOR_HEAD_SIZE), head_color)
	_add_collider("Props", ANCHOR_HEAD_SIZE, pos)
	y += ANCHOR_HEAD_SIZE.y
	pos = center + Vector3(0.0, y + ANCHOR_CAP_SIZE.y * 0.5, 0.0)
	_add_mm("anchor_cap", _box_xf(pos, ANCHOR_CAP_SIZE))
	_add_collider("Props", ANCHOR_CAP_SIZE, pos)
	y += ANCHOR_CAP_SIZE.y
	bread_spots.append(center + Vector3(0.0, y + ANCHOR_CRUMB_LIFT, 0.0))
	anchors.append({
		"center": to_global(center),
		"district": district,
		"top": y - block_slab_height, ## Total height above the slab top.
		"cap_top": to_global(Vector3(0.0, y, 0.0)).y, ## Global cap-top face y.
	})
	_fp.append(["anchor", center.x, center.z, district])


## Subdivides a block interior into 2x2 lots and fills 2–4 of them with
## buildings whose heights snap to whole floors. The block's district picks
## the palette the buildings wear. Each building's footprint varies per lot
## AND per axis through the stable `_lot_footprint_scale` hash (T-051) — a
## pure function of the block coordinates, the lot's quadrant and the seed,
## so the roofscape reads as individual volumes instead of a waffle grid of
## equal 7.1 m squares. No RNG draw: the floors/palette roll sequences are
## untouched.
func _build_block_buildings(center: Vector3, district: int, bx: int, bz: int) -> void:
	var interior := block_size - sidewalk_width * 2.0
	var lot := interior * 0.5
	var footprint_max := lot - lot_gap
	var lots: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	var roll := _rng.randf()
	if roll < 0.45:
		pass ## Quad — all four lots filled.
	elif roll < 0.70:
		lots.remove_at(_rng.randi_range(0, lots.size() - 1)) ## Trio — one courtyard.
	else:
		var keep_low := _rng.randi_range(0, 1) == 0
		var kept: Array[Vector2] = []
		for q in lots:
			if (q.x < 0.0) == keep_low:
				kept.append(q)
		lots = kept ## Duo — one alley through the block.
	for q in lots:
		var lot_offset := Vector2(q.x * lot * 0.5, q.y * lot * 0.5)
		var footprint := Vector2(
				footprint_max * _lot_footprint_scale(bx, bz, int(q.x), int(q.y), 0),
				footprint_max * _lot_footprint_scale(bx, bz, int(q.x), int(q.y), 1))
		_add_building(center + Vector3(lot_offset.x, 0.0, lot_offset.y), footprint, district,
				lot_offset)


func _add_building(base_center: Vector3, footprint: Vector2, district: int,
		lot_offset: Vector2) -> void:
	var floors := _rng.randi_range(building_floors_min, building_floors_max)
	var wall_h := floors * floor_height
	var total_h := wall_h + roof_slab_height
	var palette: Array = DISTRICT_PALETTES[district]
	var color: Color = palette[_rng.randi_range(0, palette.size() - 1)]
	_add_mm("facade%d" % floors, _box_xf(
			base_center + Vector3(0.0, block_slab_height + wall_h * 0.5, 0.0),
			Vector3(footprint.x, wall_h, footprint.y)), color)
	_add_mm("roof", _box_xf(
			base_center + Vector3(0.0, block_slab_height + wall_h + roof_slab_height * 0.5, 0.0),
			Vector3(footprint.x, roof_slab_height, footprint.y)))
	var shop := _add_shopfront(base_center, footprint, lot_offset)
	_add_collider("Buildings",
			Vector3(footprint.x, total_h, footprint.y),
			base_center + Vector3(0.0, block_slab_height + total_h * 0.5, 0.0))
	## Rooftop clutter (T-032): 1-3 deterministic props in the three non-(+,+)
	## corner quadrants plus one roof-corner crumb spot in the remaining (+,+)
	## quadrant — every position a pure function of this building's own layout
	## data (floors, footprint, lot_offset). Zero RNG of any stream and no `_fp`
	## entry, so the layout fingerprint stays byte-identical to pre-T-032
	## builds. Each prop carries a small layer-1 collider (the bench pattern)
	## and is landable cover; the (+,+) quadrant never hosts a prop (count ≤ 3)
	## and nothing ever touches the footprint center — the
	## `city_roof_landable` drop point.
	var roof_top := block_slab_height + wall_h + roof_slab_height
	var kind: String = ROOF_PROP_KINDS[buildings.size() % ROOF_PROP_KINDS.size()]
	var prop_count := 1 + ((floors - building_floors_min) % 3)
	var prop_quadrants: Array[Vector2] = [
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0)]
	for i in prop_count:
		var quadrant := prop_quadrants[i]
		var prop_size: Vector3 = ROOF_PROP_SIZES[kind]
		var prop_pos := base_center + Vector3(
				quadrant.x * signf(lot_offset.x) * footprint.x * ROOF_PROP_INSET,
				roof_top + prop_size.y * 0.5,
				quadrant.y * signf(lot_offset.y) * footprint.y * ROOF_PROP_INSET)
		_add_mm(kind, _box_xf(prop_pos, prop_size))
		_add_collider("Props", prop_size, prop_pos)
		roof_props.append({
			"center": to_global(prop_pos),
			"size": prop_size,
			"top": to_global(Vector3(0.0, roof_top + prop_size.y, 0.0)).y,
			"kind": kind,
		})
	bread_spots.append(base_center + Vector3(
			signf(lot_offset.x) * footprint.x * ROOF_BREAD_INSET,
			roof_top + 0.06,
			signf(lot_offset.y) * footprint.y * ROOF_BREAD_INSET))
	buildings.append({
		"center": to_global(Vector3(base_center.x, 0.0, base_center.z)),
		"size": footprint,
		"top": to_global(Vector3(0.0, block_slab_height + total_h, 0.0)).y,
		"district": district, ## Which district palette the facade wore (T-013).
		"color": color, ## The facade color itself — tests assert palette membership (T-013).
		"lot_offset": lot_offset, ## City-local offset from the block center (T-017 street-face rule).
		"shop_color": shop.color, ## Ground-floor band color — tests assert palette membership (T-017).
		"door_face": shop.door_face, ## 0=+x 1=-x 2=+z 3=-z — must be one of the lot's street faces (T-017).
		"has_awning": shop.has_awning, ## Whether the door got its awning (T-017).
	})
	_max_roof = maxf(_max_roof, total_h)
	_counts.buildings += 1
	_fp.append(["b", base_center.x, base_center.z, footprint.x, footprint.y, wall_h,
			color.r, color.g, color.b])
	_fp.append(["shop", base_center.x, base_center.z, shop.color.r, shop.color.g, shop.color.b,
			shop.door_face, 1 if shop.has_awning else 0])
	## Spawn-plaza guarantee: no footprint may intrude into the clear radius.
	var closest := Vector2(
			clampf(_plaza_center.x, base_center.x - footprint.x * 0.5,
					base_center.x + footprint.x * 0.5),
			clampf(_plaza_center.z, base_center.z - footprint.y * 0.5,
					base_center.z + footprint.y * 0.5))
	if Vector2(_plaza_center.x, _plaza_center.z).distance_to(closest) < spawn_clear_radius:
		_plaza_clear = false


## Ground-floor shopfront (T-017): a colored band around the whole ground floor,
## plus a door — and often an awning over it — on ONE street-facing face. All
## rolls come from the dedicated `_shop_rng`, so the layout stream is untouched.
## Face indices: 0=+x, 1=-x, 2=+z, 3=-z. The street faces of a lot are the two
## whose outward normal points away from the block center; the other two look
## into the `lot_gap` alley, where facing awnings at the same height would
## interpenetrate. The awning is deliberately visual-only (no collider — see
## the ticket's Decisions).
func _add_shopfront(base_center: Vector3, footprint: Vector2, lot_offset: Vector2) -> Dictionary:
	var shop_color: Color = SHOPFRONT_PALETTE[
			_shop_rng.randi_range(0, SHOPFRONT_PALETTE.size() - 1)]
	var band_h := 2.4
	var band_outset := 0.12
	_add_mm("shopfront", _box_xf(
			base_center + Vector3(0.0, block_slab_height + band_h * 0.5, 0.0),
			Vector3(footprint.x + band_outset, band_h, footprint.y + band_outset)), shop_color)
	var street_faces: Array[int] = []
	if lot_offset.x > 0.0:
		street_faces.append(0) ## +x
	elif lot_offset.x < 0.0:
		street_faces.append(1) ## -x
	if lot_offset.y > 0.0:
		street_faces.append(2) ## +z
	elif lot_offset.y < 0.0:
		street_faces.append(3) ## -z
	var door_face: int = street_faces[_shop_rng.randi_range(0, street_faces.size() - 1)]
	var face_normal: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD][door_face]
	## T-051: the footprint extent ALONG the face normal decides the face plane;
	## the awning's along-face span uses the OTHER axis.
	var face_out := footprint.x if absf(face_normal.x) > 0.5 else footprint.y
	var door_size := Vector3(0.95, 2.05, 0.1) if absf(face_normal.x) > 0.5 \
			else Vector3(0.1, 2.05, 0.95)
	_add_mm("door", _box_xf(
			base_center + face_normal * (face_out * 0.5 + band_outset + 0.01)
					+ Vector3(0.0, block_slab_height + 1.025, 0.0),
			door_size))
	## Signboard plaque (T-090): one blank cream plaque per building, centered
	## above the door on the shop band — spanning slab+2.30 to slab+2.80, so it
	## clears the door top (slab+2.05) below and the awning underside
	## (slab+2.855) above when one is present. Orientation follows the AWNING's
	## convention — the thin 0.08 m depth on the face-normal axis, the 2.2 m
	## width along the wall — so the plaque hangs flush; NOT the door's
	## inverted swap (T-103). Visual-only like the awning, and pure layout:
	## zero RNG draws of any stream, zero `_fp` entries, so every pinned count
	## and the layout fingerprint stay byte-identical.
	var sign_size := Vector3(0.08, 0.5, 2.2) if absf(face_normal.x) > 0.5 \
			else Vector3(2.2, 0.5, 0.08)
	_add_mm("sign", _box_xf(
			base_center + face_normal * (face_out * 0.5 + band_outset + 0.05)
					+ Vector3(0.0, block_slab_height + 2.55, 0.0),
			sign_size))
	var has_awning := _shop_rng.randf() < awning_chance
	if has_awning:
		var awn_depth := 1.3
		var awn_along := footprint.y if absf(face_normal.x) > 0.5 else footprint.x
		var awn_size := Vector3(awn_depth, 0.09, awn_along * 0.55) if absf(face_normal.x) > 0.5 \
				else Vector3(awn_along * 0.55, 0.09, awn_depth)
		_add_mm("awning", _box_xf(
				base_center + face_normal * (face_out * 0.5 + awn_depth * 0.5)
						+ Vector3(0.0, block_slab_height + 2.9, 0.0),
				awn_size), shop_color.darkened(0.15))
	return {"color": shop_color, "door_face": door_face, "has_awning": has_awning}


## Sidewalk cafe tables (T-031): one spot per awninged building, appended after
## the block loop from the public `buildings[]` records. Pure math — ZERO new
## RNG (no `_shop_rng` draws, no layout-stream draws, no `_fp` entry), so the
## pinned awning count and the layout fingerprint stay byte-identical; the
## spots are pinned by the `city_cafe_tables_present` scenario directly, like
## `elder_spots`.
func _build_cafe_spots() -> void:
	for info in buildings:
		if info.has_awning:
			cafe_spots.append(cafe_spot_for(info))


## The transform for one building's cafe table (T-031) — a pure function of its
## `buildings[]` record (`door_face`, `size`, `lot_offset`), recomputable by
## tests: 1.9 m out from the shop-band face plane along the door-face normal,
## ±2.2 m along the face from the centered door — the side the lot_offset sign
## picks (toward the lot's own outer corner), y at slab level, yaw facing the
## street. The center lands 9.82 m out along the normal, 6.45 m along the face:
## on the sidewalk band with the tourist loop's ~0.63 m walker clearance to the
## 10.9 m curb line, ~1.28 m edge-to-edge clear of the door, and structurally
## ≥ 1.0 m off the block's bread spots at every seed (bench jitter ±4 m can
## never reach the corner-ward line).
func cafe_spot_for(info: Dictionary) -> Transform3D:
	var normal: Vector3 = FACE_NORMALS[int(info.door_face)]
	var lot: Vector2 = info.lot_offset
	var size: Vector2 = info.size
	var face_axis_x := absf(normal.x) > 0.5
	var along := Vector3(0.0, 0.0, signf(lot.y)) if face_axis_x \
			else Vector3(signf(lot.x), 0.0, 0.0)
	var pos: Vector3 = to_local(info.center) \
			+ normal * ((size.x if face_axis_x else size.y) * 0.5
					+ CAFE_FACE_OUTSET + CAFE_STANDOFF) \
			+ along * CAFE_SIDE_OFFSET
	pos.y = block_slab_height
	return Transform3D(Basis(Vector3.UP, atan2(-normal.x, -normal.z)), pos)


## The spawn plaza: an open paved block — benches around a landmarked middle,
## lamps on the corners, bins on the diagonals just outside the bench ring.
## The center carries the T-029 landmark (the bronze pigeon on its plinth);
## everything else stays on the 8 m ring and beyond.
func _build_plaza(center: Vector3) -> void:
	for i in 8:
		var ang := TAU * i / 8.0
		var pos := center + Vector3(sin(ang) * 8.0, 0.0, cos(ang) * 8.0)
		_add_bench(pos, ang + PI * 0.5)
		## Elder seat (T-020): the same bench, recorded as a pure-layout spot —
		## position on the seat top (slab + 0.60, the `_add_bench` math), yaw =
		## the bench's own. No RNG: appending here never touches the layout
		## stream, so the fingerprints stay byte-identical.
		elder_spots.append(Transform3D(
				Basis(Vector3.UP, ang + PI * 0.5),
				Vector3(pos.x, block_slab_height + 0.60, pos.z)))
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		_add_lamp(center + Vector3(corner.x * 9.8, 0.0, corner.y * 9.8))
		## (T-104) The bins keep the diagonal azimuths but sit radially OUTSIDE
		## the 8 m bench ring: (7.0, 7.0) puts the bin center at r ≈ 9.9 m,
		## 0.611 m clear of the bench colliders' outer end (8.9 m) — the probed
		## minimum is ~6.6 per axis, (6.5, 6.5) still clips. On the slab
		## (per-axis reach 7.389 ≪ 11.0), 3.96 m from the lamps, 5.0 m from the
		## sim harness's PLAZA_DROP_OFFSET landing point.
		_add_bin(center + Vector3(corner.x * 7.0, 0.0, corner.y * 7.0))
	_add_landmark(center) ## T-029 — after the ring, at the center.


## The plaza landmark (T-029): a stylized bronze pigeon on a limestone plinth,
## standing at the exact plaza center. Plinth = base box plus cap box, the cap
## top at `block_slab_height + LANDMARK_PLINTH_TOP` (2.12 m global) — the one
## landing surface, carried by a single layer-1 `Props` box collider (the bench
## pattern). Figure = legs, body, tail fan, neck, head and beak as boxes (the
## T-011 hand-built-primitives recipe), facing +x, highest point at
## `block_slab_height + LANDMARK_FIGURE_TOP` (≈ 5.07 m global) — visual-only,
## the T-017 awning decision. Pure layout: fixed offsets, zero RNG of any
## stream, one `_fp` entry so the fingerprint pins the anchor's position.
func _add_landmark(center: Vector3) -> void:
	var slab := block_slab_height
	_add_mm("plinth", _box_xf(center + Vector3(0.0,
			slab + LANDMARK_PLINTH_BASE.y * 0.5, 0.0), LANDMARK_PLINTH_BASE))
	_add_mm("plinth", _box_xf(center + Vector3(0.0,
			slab + LANDMARK_PLINTH_BASE.y + LANDMARK_PLINTH_CAP.y * 0.5, 0.0),
			LANDMARK_PLINTH_CAP))
	_add_collider("Props",
			Vector3(LANDMARK_PLINTH_BASE.x, LANDMARK_PLINTH_TOP, LANDMARK_PLINTH_BASE.z),
			center + Vector3(0.0, slab + LANDMARK_PLINTH_TOP * 0.5, 0.0))
	_add_mm("figure", _box_xf(center + Vector3(-0.55, slab + 2.35, 0.0),
			Vector3(0.28, 0.7, 0.28))) ## Legs (paired).
	_add_mm("figure", _box_xf(center + Vector3(0.55, slab + 2.35, 0.0),
			Vector3(0.28, 0.7, 0.28)))
	_add_mm("figure", _box_xf(center + Vector3(0.0, slab + 3.3, 0.0),
			Vector3(1.8, 1.2, 1.0))) ## Body — chest to tail along +x.
	_add_mm("figure", _box_xf(center + Vector3(-0.98, slab + 3.4, 0.0),
			Vector3(0.16, 1.1, 0.8))) ## Tail fan, rising behind the body.
	_add_mm("figure", _box_xf(center + Vector3(0.6, slab + 4.1, 0.0),
			Vector3(0.4, 0.6, 0.4))) ## Neck.
	_add_mm("figure", _box_xf(center + Vector3(0.7, slab + 4.6, 0.0),
			Vector3(0.7, 0.7, 0.7))) ## Head.
	_add_mm("figure", _box_xf(center + Vector3(1.24, slab + 4.6, 0.0),
			Vector3(0.38, 0.16, 0.16))) ## Beak.
	_fp.append(["landmark", center.x, center.z])


## Benches along the edges, lamps on the corners, the occasional bin.
func _build_block_props(center: Vector3, is_plaza: bool) -> void:
	if is_plaza:
		return ## The plaza places its own ring.
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		_add_lamp(center + Vector3(corner.x * 9.8, 0.0, corner.y * 9.8))
	var edges: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	for n: Vector3 in edges:
		if _rng.randf() < bench_chance:
			var perp := Vector3(-n.z, 0.0, n.x)
			var offset := _rng.randf_range(-4.0, 4.0)
			var pos := center + n * 9.75 + perp * offset
			_add_bench(pos, atan2(-perp.z, perp.x))
	if _rng.randf() < bin_chance:
		var corner: Vector2 = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)][
				_rng.randi_range(0, 3)]
		_add_bin(center + Vector3(
				corner.x * 9.0 + _rng.randf_range(-1.0, 1.0), 0.0,
				corner.y * 9.0 + _rng.randf_range(-1.0, 1.0)))


## --- props (visual via MultiMesh, collision via a small static body) ------


func _add_bench(pos: Vector3, yaw: float) -> void:
	var base := Vector3(pos.x, block_slab_height, pos.z)
	var xf := Transform3D(Basis(Vector3.UP, yaw), base)
	bread_spots.append(base + Vector3(0.0, 0.60, 0.0)) ## Seat top — crumb sits on the bench (T-005).
	_add_mm("bench_seat", xf * _box_xf(Vector3(0.0, 0.5, 0.0), Vector3(1.8, 0.08, 0.5)))
	_add_mm("bench_leg", xf * _box_xf(Vector3(-0.75, 0.25, 0.0), Vector3(0.1, 0.5, 0.44)))
	_add_mm("bench_leg", xf * _box_xf(Vector3(0.75, 0.25, 0.0), Vector3(0.1, 0.5, 0.44)))
	_add_collider("Props", Vector3(1.8, 0.55, 0.5), base + Vector3(0.0, 0.275, 0.0), yaw)
	_counts.benches += 1
	_fp.append(["bench", base.x, base.z, yaw])


func _add_lamp(pos: Vector3) -> void:
	var base := Vector3(pos.x, block_slab_height, pos.z)
	var xf := Transform3D(Basis.IDENTITY, base)
	_add_mm("lamp_post", xf * _box_xf(Vector3(0.0, 2.2, 0.0), Vector3(0.12, 4.4, 0.12)))
	_add_mm("lamp_head", xf * _box_xf(Vector3(0.0, 4.45, 0.0), Vector3(0.55, 0.2, 0.3)))
	_add_cylinder("Props", 0.14, 4.6, base + Vector3(0.0, 2.3, 0.0))
	_counts.lamps += 1
	_fp.append(["lamp", base.x, base.z])


func _add_bin(pos: Vector3) -> void:
	var base := Vector3(pos.x, block_slab_height, pos.z)
	_add_mm("bin", _box_xf(base + Vector3(0.0, 0.4, 0.0), Vector3(0.5, 0.8, 0.5)))
	_add_collider("Props", Vector3(0.55, 0.8, 0.55), base + Vector3(0.0, 0.4, 0.0))
	_counts.bins += 1
	_fp.append(["bin", base.x, base.z])


## --- visuals --------------------------------------------------------------


## Queues one instance for the MultiMesh registered under `key`.
func _add_mm(key: String, xf: Transform3D, color: Color = Color.WHITE) -> void:
	if not _visuals.has(key):
		_visuals[key] = {"xfs": [], "colors": []}
	_visuals[key].xfs.append(xf)
	_visuals[key].colors.append(color)


## Turns the queued instances into one MultiMeshInstance3D per key.
func _spawn_visuals() -> void:
	for key: String in _visuals:
		var data: Dictionary = _visuals[key]
		var xfs: Array = data.xfs
		var colors: Array = data.colors
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[key]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = key.to_pascal_case()
		node.multimesh = mm
		_visual_root.add_child(node)


## --- materials & meshes ---------------------------------------------------


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat


## Block slabs take their color per MultiMesh instance.
func _vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	return mat


## Facades: a tiny procedural window grid, tinted per building via instance
## color. One material per floor count (T-049): exactly `floors` window rows,
## with the row pitch derived from the count so every row sits fully inside the
## 64 px texture with even spacing at any count in
## `building_floors_min..building_floors_max` — the old fixed 15 px pitch would
## push a 5th row past y 64. The count rides the material as `window_rows`
## metadata, the machine-readable test channel (no GPU readback).
func _facade_material(floors: int) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.95, 0.95))
	var pitch := (64.0 - 8.0) / float(floors)
	var window_h := int(pitch) - 5
	for row in floors:
		for col in 3:
			img.fill_rect(Rect2i(5 + col * 20, 4 + int(float(row) * pitch), 13, window_h),
					Color(0.25, 0.30, 0.38))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.set_meta("window_rows", floors)
	return mat


func _glow_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	return mat


func _unit_box(material: StandardMaterial3D) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	return mesh


## Transform for one unit-box instance: scaled to `size`, offset by `offset`.
func _box_xf(offset: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), offset)


## --- collision ------------------------------------------------------------


## One StaticBody3D per group name (T-093): every collider the city builds is
## a positioned CollisionShape3D child of its group's single body instead of a
## single-shape body of its own — same layer (1 `world`), same mask (0), same
## spot under `Static/`. Five bodies replace ~840; shapes carry the transforms.
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


## One cylinder collider in `group`'s body — the `_add_collider` pattern with a
## CylinderShape3D. Returns the shape.
func _add_cylinder(group: String, radius: float, height: float, pos: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position = pos
	_group(group).add_child(shape)
	return shape


## --- reporting -------------------------------------------------------------


func _make_report() -> Dictionary:
	return {
		"seed": seed_value,
		"span": city_span,
		"street_width": road_width,
		"max_roof_height": _max_roof,
		"plaza_clear": _plaza_clear,
		"bread_surfaces": _counts.benches + blocks_per_side * blocks_per_side
				+ _counts.buildings + _counts.parks,
		"blocks": blocks_per_side * blocks_per_side,
		"buildings": _counts.buildings,
		"parks": _counts.parks,
		"benches": _counts.benches,
		"lamps": _counts.lamps,
		"bins": _counts.bins,
	}

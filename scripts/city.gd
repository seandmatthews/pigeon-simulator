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
const COLOR_ASPHALT := Color(0.24, 0.24, 0.26)
const COLOR_GRASS := Color(0.36, 0.5, 0.30)
const COLOR_SIDEWALK := Color(0.62, 0.61, 0.58)
const COLOR_PLAZA := Color(0.70, 0.66, 0.58)
const COLOR_PARK := Color(0.42, 0.55, 0.34)
const COLOR_ROOF := Color(0.33, 0.33, 0.36)
const COLOR_LANE_MARK := Color(0.85, 0.82, 0.60)
const COLOR_BENCH_WOOD := Color(0.55, 0.38, 0.24)
const COLOR_METAL := Color(0.25, 0.26, 0.28)
const COLOR_BIN := Color(0.16, 0.30, 0.20)
const COLOR_LAMP_GLOW := Color(1.0, 0.9, 0.6)

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
## footprint), `top` (global roof height). Tests and later tickets read this.
var buildings: Array[Dictionary] = []
## Summary of the last generation — the sim harness asserts the guarantees on it.
var last_report: Dictionary = {}

## Emitted at the end of every generate() — the bread service (T-005) re-seeds
## its pickups so they always sit on the current layout.
signal regenerated

## Surface points (city-local) where a bread crumb can sit (T-005): bench
## seats, the sidewalk ring of every block, plaza and park slabs. Purely
## derived from the layout — no RNG of its own — so it is deterministic per
## seed and never shifts the building RNG sequence.
var bread_spots: Array[Vector3] = []

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
func generate(new_seed: int = seed_value) -> void:
	seed_value = new_seed
	_clear()
	_rng.seed = seed_value
	_meshes = {}
	_visuals = {}
	_counts = {"buildings": 0, "parks": 0, "benches": 0, "lamps": 0, "bins": 0}
	_fp = []
	_max_roof = 0.0
	_plaza_clear = true
	buildings = []
	bread_spots = []
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
	_build_roads()
	for bx in blocks_per_side:
		for bz in blocks_per_side:
			_build_block(bx, bz, bx == plaza_i and bz == plaza_i)
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
		"slab": _unit_box(_vertex_color_material()),
		"facade": _unit_box(_facade_material()),
		"roof": _unit_box(_flat_material(COLOR_ROOF)),
		"bench_seat": _unit_box(_flat_material(COLOR_BENCH_WOOD)),
		"bench_leg": _unit_box(_flat_material(COLOR_METAL)),
		"lamp_post": _unit_box(_flat_material(COLOR_METAL)),
		"lamp_head": _unit_box(_glow_material(COLOR_LAMP_GLOW)),
		"bin": _unit_box(_flat_material(COLOR_BIN)),
	}


func _build_ground() -> void:
	var size := city_span + ground_extra * 2.0
	var body := _add_collider("Ground", Vector3(size, 1.0, size), Vector3(0.0, -0.5, 0.0))
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, 1.0, size)
	mesh.material = _flat_material(COLOR_GRASS)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(mesh_instance)
	_fp.append(["ground", size])


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
	else:
		_build_block_buildings(center, district_of(bx, bz))
	_build_block_props(center, is_plaza)


## Subdivides a block interior into 2x2 lots and fills 2–4 of them with
## buildings whose heights snap to whole floors. The block's district picks
## the palette the buildings wear.
func _build_block_buildings(center: Vector3, district: int) -> void:
	var interior := block_size - sidewalk_width * 2.0
	var lot := interior * 0.5
	var footprint := lot - lot_gap
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
		_add_building(center + Vector3(q.x * lot * 0.5, 0.0, q.y * lot * 0.5), footprint, district)


func _add_building(base_center: Vector3, footprint: float, district: int) -> void:
	var floors := _rng.randi_range(building_floors_min, building_floors_max)
	var wall_h := floors * floor_height
	var total_h := wall_h + roof_slab_height
	var palette: Array = DISTRICT_PALETTES[district]
	var color: Color = palette[_rng.randi_range(0, palette.size() - 1)]
	_add_mm("facade", _box_xf(
			base_center + Vector3(0.0, block_slab_height + wall_h * 0.5, 0.0),
			Vector3(footprint, wall_h, footprint)), color)
	_add_mm("roof", _box_xf(
			base_center + Vector3(0.0, block_slab_height + wall_h + roof_slab_height * 0.5, 0.0),
			Vector3(footprint, roof_slab_height, footprint)))
	_add_collider("Buildings",
			Vector3(footprint, total_h, footprint),
			base_center + Vector3(0.0, block_slab_height + total_h * 0.5, 0.0))
	buildings.append({
		"center": to_global(Vector3(base_center.x, 0.0, base_center.z)),
		"size": Vector2(footprint, footprint),
		"top": to_global(Vector3(0.0, block_slab_height + total_h, 0.0)).y,
		"district": district, ## Which district palette the facade wore (T-013).
		"color": color, ## The facade color itself — tests assert palette membership (T-013).
	})
	_max_roof = maxf(_max_roof, total_h)
	_counts.buildings += 1
	_fp.append(["b", base_center.x, base_center.z, footprint, wall_h, color.r, color.g, color.b])
	## Spawn-plaza guarantee: no footprint may intrude into the clear radius.
	var half := footprint * 0.5
	var closest := Vector2(
			clampf(_plaza_center.x, base_center.x - half, base_center.x + half),
			clampf(_plaza_center.z, base_center.z - half, base_center.z + half))
	if Vector2(_plaza_center.x, _plaza_center.z).distance_to(closest) < spawn_clear_radius:
		_plaza_clear = false


## The spawn plaza: an open paved block — benches around a clear middle,
## lamps on the corners, bins on the diagonals. The center stays empty.
func _build_plaza(center: Vector3) -> void:
	for i in 8:
		var ang := TAU * i / 8.0
		var pos := center + Vector3(sin(ang) * 8.0, 0.0, cos(ang) * 8.0)
		_add_bench(pos, ang + PI * 0.5)
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		_add_lamp(center + Vector3(corner.x * 9.8, 0.0, corner.y * 9.8))
		_add_bin(center + Vector3(corner.x * 5.5, 0.0, corner.y * 5.5))


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


## Facades: a tiny procedural window grid, tinted per building via instance color.
func _facade_material() -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.95, 0.95))
	for row in 4:
		for col in 3:
			img.fill_rect(Rect2i(5 + col * 20, 4 + row * 15, 13, 10), Color(0.25, 0.30, 0.38))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
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


func _group(group: String) -> Node3D:
	if not _static_root.has_node(group):
		var node := Node3D.new()
		node.name = group
		_static_root.add_child(node)
	return _static_root.get_node(group) as Node3D


func _add_collider(group: String, size: Vector3, pos: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 ## world
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	body.rotation.y = yaw
	_group(group).add_child(body)
	return body


func _add_cylinder(group: String, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 ## world
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	body.position = pos
	_group(group).add_child(body)
	return body


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

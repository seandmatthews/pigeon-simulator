class_name AmesParking
extends RefCounted
## The Ames parking system (T-182) — cars that sit still, at the places Ames
## actually parks them. A pure function of the committed pack + the traffic
## graph (zero RNG of any stream), built once per world build in the finish
## slice (after the graph; BEFORE the spawners populate — the CarSpawner's
## parked placement reads the curb marking):
##
## 1. **The lot stock** is the pack's `parking` layer — the census §3
##    amenity=parking census verbatim (480 areas / 73.6 ha; 19 tailgate-zone
##    lots / 8.9 ha; the `kind` field carries the OSM `parking` subtype).
## 2. **The curb marking** answers "where does the census show curb spots":
##    a run is a CURB run when its baker district is downtown or Campustown
##    (census §2's two commercial districts — downtown's parallel/angled
##    rows, Campustown's messy parallel) OR a mapped curb bay (`street_side`
##    / `lane` parking areas — 31 in the pack) sits within
##    `CURB_BAY_PROBE` of its centerline. The CarSpawner's parked placement
##    walks curb runs FIRST (the re-target; unmarked runs stay eligible —
##    the fleet-count contract never starves).
## 3. **The lot dressing** fills the dressed lots at dressing density: rows
##    of parked-car silhouettes (the world renders them as two boxes off
##    these transforms), stalls clipped to the lot polygon at the pinned
##    module, every LOT_GAP_EVERY-th stall skipped — the "full-ish
##    year-round" read with the honest gaps real lots carry. Dressed set =
##    the Iowa State Center tailgate zone + the Campustown census window +
##    the census §3 "biggest single lots" cut (≥ LOT_BIG_AREA). Guards: a
##    stall inside a building footprint, on street asphalt, inside Lake
##    LaVerne or on the rail ballast drops. Dressing bodies are SCENERY —
##    the splat/favor stock stays the T-147 fleet exactly as tuned (the
##    anti-farm math does not re-derive here; IDEAS.md B-6 stays parked):
##    the fleet's parked placement stages REAL cars into the dressing's gap
##    slots near the pigeon (`park_spots_near`), so a lot visit pays like a
##    curb visit, and the fleet count never moves.

## --- the parking law (placement data, pinned by `ames_parking_census`) ------

## The OSM `parking` subtypes that mark curb runs (the mapped bay stock).
const CURB_BAY_KINDS: Array[String] = ["street_side", "lane"]
## A curb bay marks a run whose centerline passes within `half_width + probe`
## of the bay's bbox center (m). Measured: downtown Main's bays sit 5.5–6.7 m
## off an 11–13 m street's centerline; the widest honest catch (Union Drive's
## 15.2 m outlier) still clears at 8.
const CURB_BAY_PROBE := 8.0
## The baker districts whose streets carry curb parking by census §2 (the
## ticket's own record: "downtown angled/parallel, Campustown messy
## parallel"). Every run in these districts is a curb run.
const CURB_DISTRICTS: Array[String] = ["downtown", "campustown"]

## Stall pitch along a row (m on centers) and the row module across (m):
## one 5.5 m stall depth plus the 7.0 m drive aisle it loads from. Full lot
## density ≈ 2.6 × 12.5 = 32.5 m²/stall (~308 stalls/ha — the ITE full-lot
## read); the gap skip below dresses it "full-ish", not sealed.
const LOT_STALL_PITCH := 2.6
const LOT_STALL_DEPTH := 5.5
const LOT_AISLE := 7.0
## Every Nth stall (deterministic, by global dressing counter) is SKIPPED —
## the real lots' empty stalls: the full-ish read plus the gaps the REAL
## parked fleet may take (the CarSpawner stages splat/favor targets into
## them when the pigeon stands near the lot — the economy does not thin
## where the parking visibly is).
const LOT_GAP_EVERY := 7
## A dressed lot offers its gap stalls to the parked fleet when the pigeon
## stands within this distance (flat, m) of them — the lot-staging reach
## (the pigeon ON the lot reads its own parking; a drive-by at 200 m does
## not yank the fleet off the curbs).
const LOT_PARK_RADIUS := 90.0
## The census §3 "biggest single lots" cut (ha → m²): lots this big dress
## wherever they stand in the core (the 2.31 ha campus permit lot, the 1.62
## ha Molecular Biology lot, the 1.54 ha SE Rec lot, the two 1.5 ha rows).
const LOT_BIG_AREA := 15000.0
## A stall whose ground query answers taller than this is inside a building
## footprint — dropped (the T-176/T-181 ground-guard law).
const GROUND_COVER_MAX := 0.5
## A stall within this distance (m) of a run's centerline rides the street's
## asphalt — dropped (dressing cars never park on the road; the curb bays
## belong to the real fleet).
const STREET_CLEAR := 0.5
## A stall within this distance (m) of a rail centerline rides the ballast —
## dropped (the T-194 corridor stays clear until it dresses itself).
const RAIL_CLEAR := 6.0
## The dressing car silhouette (m): the Car collider's own 1.9 × 1.45 × 4.4
## body plus a cabin box over it — the two-box parked-car read at dressing
## distance. Y offsets ride the body collider's center (0.725) and roof.
const DRESS_BODY_SIZE := Vector3(1.9, 1.45, 4.4)
const DRESS_BODY_CY := 0.725
const DRESS_CABIN_SIZE := Vector3(1.7, 0.55, 2.0)
const DRESS_CABIN_CY := 1.725

## The tailgate zone (census §3, verbatim): lat < 42.0225, lon
## −93.6445…−93.6260 — the Iowa State Center lot sea around Jack Trice /
## Hilton, "the game's tailgate stock". WGS84; converted through the pack
## transform. The south edge is the core bbox (lots are centroid-in-core).
const TAILGATE_LON_W := -93.6445
const TAILGATE_LON_E := -93.6260
const TAILGATE_LAT_N := 42.0225


## One dressed lot: its pack identity, the clipped stall grid (kept stalls
## only, pack-local placement transforms), and the raw grid size before the
## guards (the dressing-density read).
class Lot:
	extends RefCounted
	var id: String = ""
	var kind: String = ""
	var area_m2: int = 0
	var district: String = "" ## The baker district at the lot center.
	var in_tailgate: bool = false
	var polygon := PackedVector2Array() ## Pack-local metres.
	var center := Vector2.ZERO ## The census bbox center, pack-local.
	var aabb := Rect2() ## The polygon's bbox — the park-spot prefilter.
	var stalls: Array[Transform3D] = [] ## Kept stalls (dressing bodies), pack-local.
	## The GUARD-CLEAN gap slots the dressing skipped (LOT_GAP_EVERY): the
	## stalls a real parked fleet car may take (a splat/favor target exactly
	## like a curb car — T-182's economy coupling) without fusing into a
	## dressing body.
	var gaps: Array[Transform3D] = []
	var stalls_raw: int = 0 ## The polygon-clipped grid before the guards.


var lots: Array[Lot] = []
var _world: AmesWorld
var _graph: AmesTrafficGraph
## The census-curb marking: run id → true (run_is_curb reads it).
var _curb_runs: Dictionary = {}
## Rail centerline segments (pack-local), built once for the ballast guard.
var _rail_segs: PackedVector2Array = PackedVector2Array()
var _lake := PackedVector2Array() ## Lake LaVerne, pack-local (the water guard).
var _dressed_total: int = 0
var _dressed_by_district: Dictionary = {}
var _dressed_tailgate: int = 0


func _init(world: AmesWorld, graph: AmesTrafficGraph) -> void:
	_world = world
	_graph = graph
	if graph == null or graph.run_count() == 0:
		push_error("AmesParking: no traffic graph — curb marking builds empty")
	if world == null:
		push_error("AmesParking: no world — dressing builds empty")
		return
	_build_lake()
	_build_rail_segs()
	_mark_curb_runs()
	_dress_lots()


## The dressed-lot count.
func lot_count() -> int:
	return lots.size()


## Total kept dressing stalls across the dressed lots.
func dressed_car_count() -> int:
	return _dressed_total


## The per-district kept-stall table (baker district → count).
func dressed_by_district() -> Dictionary:
	return _dressed_by_district.duplicate()


## The tailgate-zone lots' kept stalls (the tailgate stock's dressed size).
func dressed_tailgate() -> int:
	return _dressed_tailgate


## True when `run_id` is a census-curb run (the parked placement's
## preferred set).
func run_is_curb(run_id: int) -> bool:
	return _curb_runs.has(run_id)


## The marked curb-run count.
func curb_run_count() -> int:
	return _curb_runs.size()


## The parkable lot stalls (the dressing's gap slots) within `radius` of a
## pack-local XZ anchor, nearest-first across the lots — the CarSpawner's
## lot-staging candidates ({pos, yaw, lot} — pos carries the stall's ground
## y). Deterministic: distance then lot id order. A stall already in use is
## the spawner's `_spot_taken` business, not this read's.
func park_spots_near(lxz: Vector2, radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lot: Lot in lots:
		if not lot.aabb.grow(radius).has_point(lxz):
			continue
		for xf: Transform3D in lot.gaps:
			var d := Vector2(xf.origin.x - lxz.x, xf.origin.z - lxz.y).length()
			if d > radius:
				continue
			out.append({
				"pos": Vector3(xf.origin.x, xf.origin.y, xf.origin.z),
				"yaw": xf.basis.get_euler().y,
				"lot": lot.id,
				"block": Vector3(lot.center.x, 0.0, lot.center.y),
				"dist": d,
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["dist"]) != float(b["dist"]):
			return float(a["dist"]) < float(b["dist"])
		return str(a["lot"]) < str(b["lot"]))
	return out


## --- T-208 the tailgate-dress guards -----------------------------------------


## (T-208) The per-lot street-guard candidate list — the T-182 stall guard's
## own short list (the runs whose grown AABBs overlap the lot's bbox) —
## exposed for the world's tailgate prop walk. The props run the SAME guard
## chain stalls do, so a prop and a car never disagree about where the
## asphalt starts. Built once per lot, not per prop.
func street_guard_candidates(dress: Lot) -> Array:
	return _street_candidates(dress)


## (T-208) One tailgate prop candidate's guard chain — the T-182 stall
## guards verbatim (lake water, building ground, rail ballast, street
## asphalt) minus the stall-specific kept/gap decision. `candidates` is the
## lot's `street_guard_candidates` list.
func prop_guard_ok(x: float, z: float, candidates: Array) -> bool:
	if _in_polygon(x, z, _lake):
		return false ## Never in the lake.
	var ground := _world.ground_height(
			_world.to_global(Vector3(x, 0.0, z)))
	if ground > GROUND_COVER_MAX:
		return false ## Inside a building footprint.
	if _near_rail(x, z):
		return false ## The rail corridor stays clear.
	if _near_street(x, z, candidates):
		return false ## Off the asphalt; the lots dress, the streets drive.
	return true


## --- the curb marking -------------------------------------------------------


## Marks the census-curb runs: every downtown/Campustown run by district,
## plus every run a mapped curb bay (`street_side` / `lane`) rides within
## `half_width + CURB_BAY_PROBE` of its centerline. Deterministic over the
## pack's parking order.
func _mark_curb_runs() -> void:
	if _graph == null:
		return
	var graph := _graph
	for r in graph.run_count():
		if CURB_DISTRICTS.has(graph.run_district(r)):
			_curb_runs[r] = true
	var bays: Array[Vector2] = []
	for lot: Dictionary in AmesDataPack.parking():
		if not CURB_BAY_KINDS.has(str(lot.get("kind", ""))):
			continue
		var poly: Array = lot.get("polygon", [])
		if poly.size() < 3:
			continue
		bays.append(_bbox_center(poly))
	for bay: Vector2 in bays:
		for r in graph.run_count():
			if _curb_runs.has(r):
				continue
			var pts := graph.run_points(r)
			## AABB prefilter: the run's box grown by its own half-width plus
			## the probe must hold the bay center.
			var reach := graph.run_half_width(r) + CURB_BAY_PROBE
			var aabb: Rect2 = _run_aabb(graph, r).grow(reach)
			if not aabb.has_point(bay):
				continue
			if _poly_dist2(bay, pts) <= reach * reach:
				_curb_runs[r] = true


## --- the lot dressing -------------------------------------------------------


## Dresses the parked-car rows: the tailgate zone + Campustown window + the
## census big-lot cut, stalls on the pinned module clipped to each polygon,
## the gap skip applied, each survivor ground/street/rail/water-guarded.
## Window tests run in WGS84 (the census's own frames); districts and guards
## run in pack-local metres.
func _dress_lots() -> void:
	var cw: Array = AmesTrafficGraph.CAMPUSTOWN_WINDOW ## W/S/E/N lon-lat.
	for lot: Dictionary in AmesDataPack.parking():
		var poly: Array = lot.get("polygon", [])
		if poly.size() < 3:
			continue
		var area := float(lot.get("area_m2", 0))
		var wgs: Array = lot.get("wgs84", [])
		if wgs.size() < 2:
			continue
		var lon := float(wgs[0])
		var lat := float(wgs[1])
		var in_tailgate := lat < TAILGATE_LAT_N \
				and lon > TAILGATE_LON_W and lon < TAILGATE_LON_E
		var in_cw := lon >= float(cw[0]) and lon <= float(cw[2]) \
				and lat >= float(cw[1]) and lat <= float(cw[3])
		if not (in_tailgate or in_cw or area >= LOT_BIG_AREA):
			continue
		var center: Array = lot.get("center", [0.0, 0.0])
		var dress := Lot.new()
		dress.id = str(lot.get("id", ""))
		dress.kind = str(lot.get("kind", ""))
		dress.area_m2 = int(area)
		dress.in_tailgate = in_tailgate
		dress.center = Vector2(float(center[0]), float(center[1]))
		for q: Variant in poly:
			dress.polygon.append(Vector2(float((q as Array)[0]),
					float((q as Array)[1])))
		var min_x := INF
		var min_z := INF
		var max_x := -INF
		var max_z := -INF
		for p: Vector2 in dress.polygon:
			min_x = minf(min_x, p.x)
			min_z = minf(min_z, p.y)
			max_x = maxf(max_x, p.x)
			max_z = maxf(max_z, p.y)
		dress.aabb = Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
		dress.district = _world.district_at(_world.to_global(Vector3(
				float(center[0]), 0.0, float(center[1]))))
		_stalls_for(dress)
		lots.append(dress)
		_dressed_total += dress.stalls.size()
		_dressed_by_district[dress.district] = int(
				_dressed_by_district.get(dress.district, 0)) \
				+ dress.stalls.size()
		if in_tailgate:
			_dressed_tailgate += dress.stalls.size()
	lots.sort_custom(func(a: Lot, b: Lot) -> bool:
		if a.area_m2 != b.area_m2:
			return a.area_m2 > b.area_m2
		return a.id < b.id)


## One lot's stall grid: rows across the bbox's SHORT axis (one stall depth
## + aisle per module — the double-loaded row read, facings alternating per
## row), stalls along the LONG axis at the pinned pitch, each candidate
## clipped to the polygon (the raw count), guard-checked (building ground,
## street asphalt, rail ballast, lake) and gap-skipped (kept → the dressing
## rows, gaps → the real fleet's parkable slots).
func _stalls_for(dress: Lot) -> void:
	var poly := dress.polygon
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
	var row_start := min_z if long_x else min_x
	var row_end := max_z if long_x else max_x
	var along_start := min_x if long_x else min_z
	var along_end := max_x if long_x else max_z
	var module := LOT_STALL_DEPTH + LOT_AISLE
	var candidates := _street_candidates(dress)
	var counter := 0
	var row := 0
	var row_pos := row_start
	while row_pos + LOT_STALL_DEPTH * 0.5 <= row_end:
		var row_center := row_pos + LOT_STALL_DEPTH * 0.5
		## Even rows face the aisle on their + side, odd rows the − side.
		var facing := Vector2(0.0, 1.0 if row % 2 == 0 else -1.0)
		if not long_x:
			facing = Vector2(1.0 if row % 2 == 0 else -1.0, 0.0)
		var u := along_start + LOT_STALL_PITCH * 0.5
		while u <= along_end:
			var x := u if long_x else row_center
			var z := row_center if long_x else u
			if _in_polygon(x, z, poly):
				counter += 1 ## The in-polygon candidate count IS the raw read.
				var spot := _guarded_stall(x, z, facing, counter, candidates)
				if not spot.is_empty():
					if bool(spot["kept"]):
						dress.stalls.append(spot["xf"])
					else:
						dress.gaps.append(spot["xf"])
			u += LOT_STALL_PITCH
		row += 1
		row_pos += module
	dress.stalls_raw = counter


## One stall's guard chain ({kept: bool, xf} — the transform pack-local, yaw
## facing the row's aisle; kept stalls dress the lot, gaps stay parkable) —
## empty when any guard drops it.
func _guarded_stall(x: float, z: float, facing: Vector2, counter: int,
		candidates: Array) -> Dictionary:
	if _in_polygon(x, z, _lake):
		return {} ## Never in the lake.
	var ground := _world.ground_height(
			_world.to_global(Vector3(x, 0.0, z)))
	if ground > GROUND_COVER_MAX:
		return {} ## Inside a building footprint.
	if _near_rail(x, z):
		return {} ## The rail corridor stays clear.
	if _near_street(x, z, candidates):
		return {} ## Off the asphalt; curbs belong to the real fleet.
	var yaw := atan2(-facing.x, -facing.y)
	return {
		"kept": counter % LOT_GAP_EVERY != 0,
		"xf": Transform3D(Basis(Vector3.UP, yaw), Vector3(x, ground, z)),
	}


## True when (x, z) sits within RAIL_CLEAR of a pack rail centerline.
func _near_rail(x: float, z: float) -> bool:
	for i in range(0, _rail_segs.size(), 2):
		if _seg_dist2(x, z, _rail_segs[i], _rail_segs[i + 1]) <= RAIL_CLEAR * RAIL_CLEAR:
			return true
	return false


## True when (x, z) sits within a run's half-width + STREET_CLEAR of that
## run's centerline — on the asphalt. Only the lot's candidate runs (whose
## grown AABBs overlap the lot's bbox) are tested.
func _near_street(x: float, z: float, candidates: Array) -> bool:
	var p := Vector2(x, z)
	for cand: Variant in candidates:
		var reach := float((cand as Array)[0])
		var pts: PackedVector2Array = (cand as Array)[1]
		if _poly_dist2(p, pts) <= reach * reach:
			return true
	return false


## The asphalt-guard candidate runs for one lot: every run whose
## (half-width + STREET_CLEAR)-grown centerline AABB overlaps the lot's
## bbox, as [reach, points] pairs — the per-stall test's short list.
func _street_candidates(dress: Lot) -> Array:
	var out: Array = []
	var graph := _graph
	if graph == null:
		return out
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for p: Vector2 in dress.polygon:
		min_x = minf(min_x, p.x)
		min_z = minf(min_z, p.y)
		max_x = maxf(max_x, p.x)
		max_z = maxf(max_z, p.y)
	var bbox := Rect2(min_x, min_z, max_x - min_x, max_z - min_z)
	for r in graph.run_count():
		var reach := graph.run_half_width(r) + STREET_CLEAR
		var aabb := _run_aabb(graph, r).grow(reach)
		if not aabb.intersects(bbox):
			continue
		out.append([reach, graph.run_points(r)])
	return out


## --- shared geometry helpers ------------------------------------------------


func _build_lake() -> void:
	for water: Dictionary in AmesDataPack.water():
		if str(water.get("name", "")) != "Lake LaVerne":
			continue
		for q: Variant in water.get("polygon", []):
			_lake.append(Vector2(float((q as Array)[0]),
					float((q as Array)[1])))


func _build_rail_segs() -> void:
	for line: Variant in AmesDataPack.rail().get("centerlines", []):
		var pts: Array = line
		for i in pts.size() - 1:
			_rail_segs.append(Vector2(float((pts[i] as Array)[0]),
					float((pts[i] as Array)[1])))
			_rail_segs.append(Vector2(float((pts[i + 1] as Array)[0]),
					float((pts[i + 1] as Array)[1])))


## A run's centerline AABB (pack-local) — the per-point prefilter.
func _run_aabb(graph: AmesTrafficGraph, run_id: int) -> Rect2:
	var pts := graph.run_points(run_id)
	var aabb := Rect2(pts[0], Vector2.ZERO)
	for i in range(1, pts.size()):
		aabb = aabb.expand(pts[i])
	return aabb


static func _bbox_center(poly: Array) -> Vector2:
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for q: Variant in poly:
		min_x = minf(min_x, float((q as Array)[0]))
		min_z = minf(min_z, float((q as Array)[1]))
		max_x = maxf(max_x, float((q as Array)[0]))
		max_z = maxf(max_z, float((q as Array)[1]))
	return Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)


## Squared distance from p to the closest segment of polyline pts.
func _poly_dist2(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, _seg_dist2(p.x, p.y, pts[i], pts[i + 1]))
	return best


func _seg_dist2(x: float, z: float, a: Vector2, b: Vector2) -> float:
	var dx := b.x - a.x
	var dz := b.y - a.y
	var l2 := dx * dx + dz * dz
	var t := 0.0
	if l2 > 1e-12:
		t = clampf(((x - a.x) * dx + (z - a.y) * dz) / l2, 0.0, 1.0)
	var px := a.x + t * dx
	var pz := a.y + t * dz
	return (x - px) * (x - px) + (z - pz) * (z - pz)


## Even-odd point-in-polygon (pack-local metres).
func _in_polygon(x: float, z: float, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var xi := poly[i].x
		var zi := poly[i].y
		var xj := poly[j].x
		var zj := poly[j].y
		if (zi > z) != (zj > z) \
				and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
			inside = not inside
		j = i
	return inside

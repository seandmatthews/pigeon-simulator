class_name AmesTrafficGraph
extends RefCounted
## The Ames street traffic graph (T-178) — the car fleet's route system over
## the REAL map, replacing the retired Windrow block-loop math (`City.route_from`
## and its grid seam stay for the base-class contract; nothing on the resident
## world reaches them anymore).
##
## Built once per world build from the committed pack (`AmesDataPack.streets()`
## + `rail()`) as a pure function of that data — zero RNG of any stream, zero
## per-frame work. Geometry, in pack-local metres (the world node's local
## frame):
##
## 1. **Weld**: every street polyline vertex snaps onto a shared node table
##    (1 cm keys — the pack's ways share byte-equal coordinates at junctions).
## 2. **Classify**: a shared point is a JUNCTION when the street arms meeting
##    there cluster into ≥ 3 directions, or a CORNER when two clusters meet at
##    an angle (an L in the ways); two nearly-opposite clusters are a
##    collinear CONTINUATION (a street chain's split point — merged, no node,
##    no stop). This reproduces the census's way-split discipline: 369
##    junction/corner nodes over the 436 pack ways.
## 3. **Runs**: each way splits at its nodes into undirected RUNS between
##    adjacent nodes — 777 of them, 91.9 km, per-class km matching the
##    census table (§4: primary 10.0, secondary 16.3, tertiary 13.1,
##    residential 48.7, unclassified 4.0) within rounding.
## 4. **Lanes**: every run carries TWO directed lane polylines (a→b and b→a),
##    the centerline offset to the travel direction's RIGHT by the run's lane
##    offset (`lane_off` — the `City.traffic_lane_offset` 3.5 m convention
##    applied to the real widths, clamped 1.6 m off centerline and off edge),
##    mitred at interior bends. Right-hand traffic is structural: a car only
##    ever drives a directed lane forward, so a wrong-way move is not a state
##    it can reach.
## 5. **Speed classes** (feel constants, recorded in the ticket, NOT silently
##    tuned): `CRUISE_BY_CLASS` — primary (Lincoln Way) 9.0 m/s, secondary
##    6.5, tertiary 5.5, residential/unclassified 4.5 — carried per run and
##    handed to cars through their stop entries' `cruise` field.
## 6. **Density model** (the same constants block): `SPAWN_WEIGHT_BY_CLASS` ×
##    `SPAWN_WEIGHT_BY_DISTRICT` (the baker's district rule at the run
##    midpoint — arterials and downtown/Campustown dense, residential sparse).
## 7. **Rail crossings as route facts**: the 9 at-grade vehicular crossings of
##    the pack's rail block (`at_grade` — the 6 grade-separated ones are
##    bridges, no track contact) flag their nearest graph nodes
##    (`node_is_rail`); cars cross them freely — no train events, no gates
##    (T-194 dresses the corridor later).
##
## The stop protocol, blinkers and patience machinery are unchanged: the
## spawner builds stop entries from `stop_line_local` / `corner_local` /
## `turn_of` exactly as the grid seam did from its closed forms, and
## `TrafficControl` orders movements by approach AXIS (the grid compass was
## its special case). The crosswalk-band rects stay grid-only paint: the
## graph's entries carry empty bands until R2 fills real crosswalks.

## --- feel constants (recorded in T-178; changing one is a ticket event) ----

## Lane cruise speed by street class (m/s, before the per-car pace factor).
## Lincoln Way (primary) is the fast arterial; downtown/secondary mid;
## residential calm.
const CRUISE_BY_CLASS: Dictionary = {
	"primary": 9.0,
	"secondary": 6.5,
	"tertiary": 5.5,
	"residential": 4.5,
	"unclassified": 4.5,
}

## Spawn-band density weight by street class — arterials carry the fleet.
const SPAWN_WEIGHT_BY_CLASS: Dictionary = {
	"primary": 3.0,
	"secondary": 2.5,
	"tertiary": 2.0,
	"residential": 0.7,
	"unclassified": 0.7,
}

## Spawn-band density weight multiplier by baker district at the run midpoint
## — downtown/Campustown business traffic, campus bustle, calm residential.
const SPAWN_WEIGHT_BY_DISTRICT: Dictionary = {
	"downtown": 2.5,
	"campustown": 2.0,
	"campus": 1.4,
	"lincolnway": 1.5,
	"residential": 1.0,
}

## Route-deal weight boost for a candidate edge continuing the SAME named
## street as the incoming edge — real drivers ride their street through the
## junction instead of zig-zagging onto whatever crosses. A feel constant.
const STREET_CONTINUITY_BOOST := 5.0

## Lane offset law: `width_m * 0.5 - City.traffic_lane_offset`, clamped to
## stay at least LANE_OFF_MIN off the centerline and the asphalt edge.
const LANE_OFF_MIN := 1.6
## Parked-curb lane center off the road centerline: `width_m * 0.5 - 1.05`
## (the `City.parking_offset` 1.05 m edge convention).
const PARK_EDGE_OFFSET := 1.05
## Curb parking spot pitch along a run (m) and the minimum spot spacing check
## radius the spawner's `_spot_taken` applies (a car length plus margin).
const CURB_SPOT_PITCH := 7.0
## (T-178 round 2) Curb spots keep this far (arc m) from either run end — the
## junction corner-swing zone the grid parking stayed clear of. See
## `run_curb_spots`.
const CURB_CORNER_CLEAR := 14.0
## A graph node flags `rail` when an at-grade crossing center sits within
## this radius (m) — the crossing geometry's own road half-width.
const RAIL_NODE_RADIUS := 14.0
## Junction arm-cluster tolerance (deg) — street arms at one welded point.
const ARM_CLUSTER_TOL_DEG := 15.0
## Two arm clusters closer than this (deg, line-space) are a collinear
## continuation, not a corner.
const CONTINUATION_TOL_DEG := 15.0
## Weld key quantization (1/cm keys — the pack shares byte-equal junction
## coordinates; a finer grid cannot split them, a coarser one could merge
## distinct close nodes).
const WELD_QUANT := 100.0
## Miter limit for lane offsets at interior bends: the offset never exceeds
## this multiple of the base lane offset (near-reversal spikes clamp).
const MITER_LIMIT := 3.0

## One undirected street run between two graph nodes.
class Run:
	extends RefCounted
	var node_a: int = -1
	var node_b: int = -1
	var cls: String = ""
	var sname: String = ""
	var width_m: float = 11.0
	var points := PackedVector2Array() ## Centerline, a→b (pack-local metres).
	var lane_fwd := PackedVector2Array() ## Right-hand lane, a→b.
	var lane_bwd := PackedVector2Array() ## Right-hand lane, b→a.
	var length: float = 0.0
	var mid := Vector2.ZERO
	var cruise: float = 4.5
	var lane_off: float = 1.6
	var weight: float = 1.0
	var district: String = "residential"
	var aabb := Rect2()
	var rail: bool = false ## Crosses an at-grade rail track (the T-178 fact).
	var reverse_edge: int = -1 ## The b→a directed edge id, -1 when none.
	var curb_spots: Array = [] ## [{pos: Vector2, yaw: float}] built lazily, local.

## Node kinds: SPLICE = a continuation/dead-end weld (traffic flows through,
## no stop, no turn waypoint), CORNER = a 2-cluster angled shared point (a
## turn waypoint, no stop), JUNCTION = ≥ 3 street arms (the four-way stops).
enum { KIND_SPLICE, KIND_CORNER, KIND_JUNCTION }

var _nodes: Array[Vector3] = [] ## Welded node positions (pack-local; y = 0).
var _node_rail: Array[bool] = []
var _node_kind: Array[int] = []
var _runs: Array[Run] = []
var _out_edges: Array[PackedInt32Array] = [] ## Per node: directed edge ids.
var _edge_to: PackedInt32Array = [] ## Directed edge id → its END node.
var _edge_run: PackedInt32Array = [] ## Directed edge id → its run index.
var _edge_fwd: PackedByteArray = [] ## Directed edge id → 1 when a→b.
var _context: Dictionary = {} ## The baker district-rule context, built once.
## Weld key (1 cm) → node id — EVERY welded vertex resolves here, so street
## chains splice across their continuation points (a run's ends are always
## welded keys).
var _weld_nodes: Dictionary = {}


## The welded junction count.
func node_count() -> int:
	return _nodes.size()


## The undirected run count (directed edges = 2× this).
func run_count() -> int:
	return _runs.size()


## The directed lane edge count.
func edge_count() -> int:
	return _edge_to.size()


## A junction's pack-local position.
func node_pos(node: int) -> Vector3:
	return _nodes[node]


## True when the node carries the four-way-stop protocol (a junction of ≥ 3
## street arms). Continuation splices, corners and dead ends do not stop.
func node_stops(node: int) -> bool:
	return _node_kind[node] == KIND_JUNCTION


## The junction's arm extent (m): the widest street half-width among the runs
## touching `node`. Every run that touches a node files one of its directed
## edges under that node's out-edges (a run ending here as node_b still
## leaves via its b→a edge), so the out-edge scan covers all arms. The
## four-way-stop box's half-extent the force-commit's occupancy check derives
## from (T-179 — the T-166 box radius was the Windrow ±5 m grid box's
## half-diagonal; a real junction is as wide as its widest street).
func node_extent(node: int) -> float:
	var extent := 0.0
	if node < 0 or node >= _out_edges.size():
		return extent
	for e in _out_edges[node]:
		extent = maxf(extent, edge_half_width(e))
	return extent


## The node's kind (KIND_SPLICE / KIND_CORNER / KIND_JUNCTION) — the routes
## scenario reads it; a turn waypoint can only ever sit at a ≥ KIND_CORNER
## node (a splice's only non-reverse exit is its straight continuation).
func node_kind(node: int) -> int:
	return _node_kind[node]


## True when the junction carries an at-grade rail-crossing fact (T-178 §3).
func node_is_rail(node: int) -> bool:
	return _node_rail[node]


## The node ids flagged with rail crossings — one or more per at-grade
## crossing of the pack's nine.
func rail_nodes() -> Array[int]:
	var out: Array[int] = []
	for i in _node_rail.size():
		if _node_rail[i]:
			out.append(i)
	return out


## Total centerline km across all runs (the census §4 drivable stock).
func total_km() -> float:
	var km := 0.0
	for run in _runs:
		km += run.length
	return km / 1000.0


## Centerline km per street class — the census table's shape.
func km_by_class() -> Dictionary:
	var out: Dictionary = {}
	for run in _runs:
		out[run.cls] = float(out.get(run.cls, 0.0)) + run.length / 1000.0
	return out


## A run's centerline midpoint (pack-local XZ) — the follow-gap grouping key
## and parked-block anchor the spawner reads.
func run_mid(run_id: int) -> Vector2:
	return _runs[run_id].mid


## A run's centerline polyline (pack-local) — the route-integrity reads.
func run_points(run_id: int) -> PackedVector2Array:
	return _runs[run_id].points


## A run's street half-width (m).
func run_half_width(run_id: int) -> float:
	return _runs[run_id].width_m * 0.5


## A run's street class / name / district.
func run_class(run_id: int) -> String:
	return _runs[run_id].cls


func run_name(run_id: int) -> String:
	return _runs[run_id].sname


func run_district(run_id: int) -> String:
	return _runs[run_id].district


## --- directed edge surface -------------------------------------------------


## A directed edge's END node.
func edge_to(edge: int) -> int:
	return _edge_to[edge]


## A directed edge's START node (where the car enters the lane).
func edge_from(edge: int) -> int:
	var run := _runs[_edge_run[edge]]
	return run.node_a if _edge_fwd[edge] == 1 else run.node_b


## The directed edge driving the same asphalt the other way (-1 when none).
func edge_reverse(edge: int) -> int:
	return _runs[_edge_run[edge]].reverse_edge if _edge_fwd[edge] == 1 \
			else _edge_run[edge] * 2


## A directed edge's run index.
func edge_run_id(edge: int) -> int:
	return _edge_run[edge]


## A directed edge's overall travel axis (flat, unit, pack-local).
func edge_axis(edge: int) -> Vector3:
	var run := _runs[_edge_run[edge]]
	var pts := run.points
	var a := pts[0]
	var b := pts[pts.size() - 1]
	if _edge_fwd[edge] == 0:
		a = pts[pts.size() - 1]
		b = pts[0]
	var d := Vector3(b.x - a.x, 0.0, b.y - a.y)
	return d.normalized() if d.length() > 0.0001 else Vector3(1.0, 0.0, 0.0)


## A directed edge's lane polyline (pack-local, right-hand offset applied).
func edge_points(edge: int) -> PackedVector2Array:
	var run := _runs[_edge_run[edge]]
	return run.lane_fwd if _edge_fwd[edge] == 1 else run.lane_bwd


## A directed edge's lane center offset off the centerline (m).
func edge_lane_off(edge: int) -> float:
	return _runs[_edge_run[edge]].lane_off


## A directed edge's street half-width (m) — the asphalt test's bound.
func edge_half_width(edge: int) -> float:
	return _runs[_edge_run[edge]].width_m * 0.5


## A directed edge's lane cruise speed (m/s, before pace).
func edge_cruise(edge: int) -> float:
	return _runs[_edge_run[edge]].cruise


## A directed edge's class weight × district weight — the spawn-band draw's
## density law.
func edge_weight(edge: int) -> float:
	return _runs[_edge_run[edge]].weight


## A directed edge's street name.
func edge_name(edge: int) -> String:
	return _runs[_edge_run[edge]].sname


## A directed edge's class.
func edge_class(edge: int) -> String:
	return _runs[_edge_run[edge]].cls


## A directed edge's district (the baker rule at the run midpoint).
func edge_district(edge: int) -> String:
	return _runs[_edge_run[edge]].district


## A directed edge's centerline length (m).
func edge_length(edge: int) -> float:
	return _runs[_edge_run[edge]].length


## The out-edges of one node (directed ids leaving it).
func out_edges(node: int) -> PackedInt32Array:
	return _out_edges[node]


## The turn a directed exit makes against a directed approach at their shared
## node: −1 left / 0 straight / +1 right (the `City.ROUTE_TURN_*` codes, which
## double as the Car blinker sides). Generalized from the grid compass: the
## exit's dot against the approach's right-of-travel decides the side, straight
## when the axes stay within ~30°. Exact on the axis-aligned grid.
func turn_of(in_edge: int, out_edge: int) -> int:
	var a := edge_axis(in_edge)
	var b := edge_axis(out_edge)
	if a.dot(b) > 0.866:
		return City.ROUTE_TURN_STRAIGHT
	var right := Vector3(-a.z, 0.0, a.x)
	return City.ROUTE_TURN_RIGHT if right.dot(b) > 0.0 else City.ROUTE_TURN_LEFT


## The turn waypoint where the incoming lane line meets the outgoing lane line
## at their shared node (pack-local): the grid `City.route_corner` closed form,
## generalized to arbitrary angles with the 2×2 line intersection. Straight
## continuations have no corner — the caller uses `through_local`.
func corner_local(node: int, in_edge: int, out_edge: int) -> Vector3:
	var n := Vector2(_nodes[node].x, _nodes[node].z)
	var a := edge_axis(in_edge)
	var b := edge_axis(out_edge)
	var off_in := edge_lane_off(in_edge)
	var off_out := edge_lane_off(out_edge)
	var r_in := Vector2(-a.z, a.x) * off_in
	var r_out := Vector2(-b.z, b.x) * off_out
	var p := n + r_in ## A point on the incoming lane line.
	var q := n + r_out ## A point on the outgoing lane line.
	var det := a.z * b.x - a.x * b.z
	if absf(det) < 0.05:
		return Vector3(p.x, 0.0, p.y) ## Nearly parallel — no resolvable corner.
	var rel := q - p
	var t := (b.x * rel.y - b.z * rel.x) / det
	return Vector3(p.x + a.x * t, 0.0, p.y + a.z * t)


## The lane's through point at a node for the incoming edge (pack-local) —
## where a straight continuation crosses the node box.
func through_local(node: int, in_edge: int) -> Vector3:
	var n := Vector2(_nodes[node].x, _nodes[node].z)
	var a := edge_axis(in_edge)
	var off := edge_lane_off(in_edge)
	var p := n + Vector2(-a.z, a.x) * off
	return Vector3(p.x, 0.0, p.y)


## The four-way-stop line center for one approach (pack-local): the node
## pulled back along the approach axis, offset to the lane. `stop_outset` is
## the caller's `City.STOP_LINE_OUTSET`.
func stop_line_local(node: int, in_edge: int, stop_outset: float) -> Vector3:
	var n := Vector2(_nodes[node].x, _nodes[node].z)
	var a := edge_axis(in_edge)
	var off := edge_lane_off(in_edge)
	var p := n - Vector2(a.x, a.z) * stop_outset + Vector2(-a.z, a.x) * off
	return Vector3(p.x, 0.0, p.y)


## --- route dealing ---------------------------------------------------------


## A seeded random walk over the directed lanes (the grid `City.route_from`'s
## replacement): never doubling back (the reverse of the incoming edge is not
## offered — except at a dead end, where the U-turn is the only move), turn
## weights from the caller's dictionary (straight/right/left), a
## `STREET_CONTINUITY_BOOST` for candidates continuing the incoming edge's
## street name. One `rng.randi_range`-free draw per step: a single
## `rng.randf()` off the CALLER's stream — zero new streams. Returns DIRECTED
## EDGE ids.
func deal_route(start_node: int, in_edge: int, steps: int,
		rng: RandomNumberGenerator, weights: Dictionary) -> PackedInt32Array:
	var straight: float = weights.get("straight", 0.60)
	var right: float = weights.get("right", 0.25)
	var left: float = weights.get("left", 0.15)
	var route := PackedInt32Array()
	var cur := start_node
	var incoming := in_edge
	for _s in steps:
		var pool := _out_edges[cur]
		var cands := PackedInt32Array()
		var totals := PackedFloat64Array()
		var total := 0.0
		## (T-178 round 2) Candidates into DEAD-END stubs are skipped while
		## any other candidate exists: a car driven into a stub must
		## 3-point-turn across the lane on its next extension — a transient
		## wrong-way/off-lane posture the route-integrity pins would honestly
		## flag. (The deal still takes a dead end when it is the only exit —
		## the fallback below — so no car is ever stranded.)
		var alternatives := false
		for e: int in pool:
			if (incoming < 0 or e != edge_reverse(incoming)) \
					and _out_edges[_edge_to[e]].size() > 1:
				alternatives = true
				break
		for e: int in pool:
			if incoming >= 0 and e == edge_reverse(incoming):
				continue ## No U-turn.
			if alternatives and _out_edges[_edge_to[e]].size() <= 1:
				continue ## Never enter a dead-end stub while anywhere else to go.
			var w := 1.0
			if incoming >= 0:
				var t := turn_of(incoming, e)
				w = straight if t == City.ROUTE_TURN_STRAIGHT \
						else (right if t == City.ROUTE_TURN_RIGHT else left)
				if w <= 0.0:
					continue
				var name_in := edge_name(incoming)
				if not name_in.is_empty() and edge_name(e) == name_in:
					w *= STREET_CONTINUITY_BOOST
			total += w
			cands.append(e)
			totals.append(total)
		if cands.is_empty():
			## Dead end: the U-turn (or any exit) stands — never strand a car.
			for e: int in pool:
				total += 1.0
				cands.append(e)
				totals.append(total)
			if cands.is_empty():
				break ## Isolated node: the walk ends here.
		var roll := rng.randf() * total
		var pick: int = cands[cands.size() - 1]
		for i in cands.size():
			if roll <= totals[i]:
				pick = cands[i]
				break
		route.append(pick)
		cur = _edge_to[pick]
		incoming = pick
	return route


## --- queries ---------------------------------------------------------------


## The nearest directed LANE polyline to a pack-local XZ point: returns
## {edge: int, dist: float, point: Vector2, axis: Vector3} — the on-graph
## read the route-integrity scenarios sample against. Empty Dictionary when
## the graph has no edges.
func nearest_edge(x: float, z: float) -> Dictionary:
	var best := {}
	var best_d2 := INF
	for edge in _edge_to.size():
		var pts := edge_points(edge)
		for i in pts.size() - 1:
			var d2 := _seg_dist2(x, z, pts[i], pts[i + 1])
			if d2 < best_d2:
				best_d2 = d2
				var a := pts[i]
				var b := pts[i + 1]
				var d := Vector2(b.x - a.x, b.y - a.y).normalized()
				best = {
					"edge": edge,
					"dist": sqrt(d2),
					"point": a + (b - a) * _last_t,
					"axis": Vector3(d.x, 0.0, d.y),
				}
	return best


var _last_t := 0.0 ## The last `_seg_dist2` projection — read with its result.


## The nearest CENTERLINE run to a pack-local XZ point (the placement/recycle
## anchor read, run-level): {run: int, dist: float} — empty when none.
func nearest_run(x: float, z: float) -> Dictionary:
	var best := {}
	var best_d2 := INF
	for r in _runs.size():
		var pts := _runs[r].points
		for i in pts.size() - 1:
			var d2 := _seg_dist2(x, z, pts[i], pts[i + 1])
			if d2 < best_d2:
				best_d2 = d2
				best = {"run": r, "dist": sqrt(d2)}
	return best


## The directed edges whose centerline passes within [min_d, max_d] (flat, m)
## of a pack-local XZ anchor — the spawn band over real streets. Ascending id
## order (a stable, deterministic base order; the spawner draws weighted).
func edges_in_band(x: float, z: float, min_d: float, max_d: float) -> PackedInt32Array:
	var edges := PackedInt32Array()
	for r in _runs.size():
		var pts := _runs[r].points
		var best_d2 := INF
		for i in pts.size() - 1:
			best_d2 = minf(best_d2, _seg_dist2(x, z, pts[i], pts[i + 1]))
		var d := sqrt(best_d2)
		if d >= min_d and d <= max_d:
			edges.append(r * 2)
			edges.append(r * 2 + 1)
	return edges


## The `count` runs nearest a pack-local XZ anchor, band ignored — the
## far-from-traffic fallback ({run, dist} dictionaries, nearest first).
func nearest_runs(x: float, z: float, count: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for r in _runs.size():
		var pts := _runs[r].points
		var best_d2 := INF
		for i in pts.size() - 1:
			best_d2 = minf(best_d2, _seg_dist2(x, z, pts[i], pts[i + 1]))
		found.append({"run": r, "dist": sqrt(best_d2), "i": found.size()})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["dist"] != b["dist"]:
			return a["dist"] < b["dist"]
		return a["i"] < b["i"])
	found.resize(mini(count, found.size()))
	return found


## One run's curb parking spots (pack-local, lazily built): points every
## `CURB_SPOT_PITCH` along the centerline, one per side, offset to
## `width*0.5 - PARK_EDGE_OFFSET` off the centerline, yaw along the side's
## travel direction (right-hand: parked cars face with the adjacent lane).
## Both sides share the walk; the spot list order is deterministic.
## (T-178 round 2) Spots within `CURB_CORNER_CLEAR` of either run end are
## SKIPPED — the grid parking's own "well clear of the intersection
## corners" rule: a parked car beside the corner-swing zone sits inside the
## turning arcs of the solid fleet, and a car rounding the corner wedges
## against it (the deterministic (507, −238) Wallace Road wedge: a traffic
## car pinned nose-first against a curb-spotted car 3.9 m away, creeping at
## 0.06 m/s until the stuck escape fired). The clearance covers the stop
## box (8.8 m) plus the swinging body (4.4 m) plus margin.
func run_curb_spots(run_id: int) -> Array:
	var run := _runs[run_id]
	if not run.curb_spots.is_empty():
		return run.curb_spots
	var pts := run.points
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var carry := 0.0
	var walked := 0.0
	var i := 0
	while i < pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := b - a
		var seg_len := seg.length()
		if seg_len < 0.001:
			i += 1
			continue
		var dir := seg / seg_len
		var right := Vector2(-dir.y, dir.x)
		var along := -carry
		while along <= seg_len:
			if along >= 0.0:
				var arc := walked + along
				if arc >= CURB_CORNER_CLEAR and arc <= total - CURB_CORNER_CLEAR:
					var p := a + dir * along
					var off := run.width_m * 0.5 - PARK_EDGE_OFFSET
					run.curb_spots.append({ ## Right side — travels a→b.
						"pos": p + right * off, "yaw": atan2(-dir.x, -dir.y),
					})
					run.curb_spots.append({ ## Left side — travels b→a.
						"pos": p - right * off, "yaw": atan2(dir.x, dir.y),
					})
			along += CURB_SPOT_PITCH
		carry = along - seg_len
		walked += seg_len
		i += 1
	return run.curb_spots


## --- construction ----------------------------------------------------------


## Builds the graph from the committed pack (pure data, no RNG).
func _init() -> void:
	var streets := AmesDataPack.streets()
	if streets.is_empty():
		push_error("AmesTrafficGraph: the pack has no streets — graph builds empty")
		return
	_context = AmesBaker._build_context()
	_weld_and_classify(streets)
	_extract_runs(streets)
	_flag_rail()


## The weld key of a pack-local vertex.
static func _weld_key(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x * WELD_QUANT), roundi(z * WELD_QUANT))


## Pass 1+2: weld every polyline vertex into the node table (ALL of them —
## street chains must splice across their split points), then classify each
## shared point: ≥ 3 arm clusters = a junction (stops); 2 clusters at an
## angle = a corner (a turn waypoint, no stop); 2 nearly-opposite clusters or
## one = a collinear continuation (a pure splice — no stop, no corner).
func _weld_and_classify(streets: Array[Dictionary]) -> void:
	var arm_users: Dictionary = {} ## Vector2i -> Array of [way, idx].
	for wi in streets.size():
		var pts: Array = streets[wi].get("points", [])
		for pi in pts.size():
			var key := _weld_key(float(pts[pi][0]), float(pts[pi][1]))
			if not _weld_nodes.has(key):
				_weld_nodes[key] = _weld_nodes.size()
				_nodes.append(Vector3(float(pts[pi][0]), 0.0, float(pts[pi][1])))
				_node_rail.append(false)
				_node_kind.append(KIND_SPLICE)
				_out_edges.append(PackedInt32Array())
			if not arm_users.has(key):
				arm_users[key] = []
			arm_users[key].append([wi, pi])
	## Arm clustering per shared point (≥ 2 distinct ways).
	for key: Vector2i in arm_users:
		var users: Array = arm_users[key]
		var ways: Dictionary = {}
		for u in users:
			ways[u[0]] = true
		if ways.size() < 2:
			continue ## Single-way vertex: interior shape point or dead end.
		var node: int = int(_weld_nodes[key])
		var arms := PackedFloat64Array()
		for u in users:
			var wi: int = u[0]
			var pi: int = u[1]
			var pts: Array = streets[wi].get("points", [])
			if pi > 0:
				arms.append(_arm_angle(key, pts[pi - 1]))
			if pi < pts.size() - 1:
				arms.append(_arm_angle(key, pts[pi + 1]))
		var clusters := _cluster_arms(arms)
		if clusters.size() >= 3:
			_node_kind[node] = KIND_JUNCTION ## A T/X junction (census ≥ 3 arms).
		elif clusters.size() == 2:
			## Line-space separation: ~0° = collinear continuation (a pure
			## splice), anything wider = a corner worth a turn waypoint.
			var sep := absf(_angle_line_diff(clusters[0], clusters[1]))
			if sep >= CONTINUATION_TOL_DEG:
				_node_kind[node] = KIND_CORNER


## The arm angle (deg) from a welded point toward one neighbor vertex.
static func _arm_angle(key: Vector2i, p: Array) -> float:
	var dx := float(p[0]) - float(key.x) / WELD_QUANT
	var dz := float(p[1]) - float(key.y) / WELD_QUANT
	return rad_to_deg(atan2(dz, dx))


## Greedy RAY clustering (order-independent enough for compass-spread street
## arms): each arm joins the first cluster whose mean sits within tolerance
## — RAYS, not lines: 0° and 180° are DIFFERENT arms (a way's two directions
## through the point), so a 4-way junction clusters into four, not two. The
## circular mean per cluster handles the 0/360 wrap.
static func _cluster_arms(arms: PackedFloat64Array) -> Array[float]:
	var members: Array = [] ## Array of PackedFloat64Array.
	for a in arms:
		var placed := false
		for i in members.size():
			var cluster: PackedFloat64Array = members[i]
			if _angle_ray_diff(_circular_mean(cluster), a) < ARM_CLUSTER_TOL_DEG:
				cluster.append(a)
				placed = true
				break
		if not placed:
			members.append(PackedFloat64Array([a]))
	var means: Array[float] = []
	for cluster: PackedFloat64Array in members:
		means.append(_circular_mean(cluster))
	return means


## The circular mean of a ray cluster (deg).
static func _circular_mean(angles: PackedFloat64Array) -> float:
	var sx := 0.0
	var sy := 0.0
	for a in angles:
		sx += cos(deg_to_rad(a))
		sy += sin(deg_to_rad(a))
	return rad_to_deg(atan2(sy, sx))


## The separation of two angles as RAYS (mod 360°), in degrees 0..180.
static func _angle_ray_diff(a_deg: float, b_deg: float) -> float:
	var d := fmod(absf(a_deg - b_deg), 360.0)
	return minf(d, 360.0 - d)


## The separation of two angles as LINES (mod 180°), in degrees 0..90 — the
## continuation test's read (two arm clusters nearly parallel AS LINES are a
## street's split point, whatever their ray senses).
static func _angle_line_diff(a_deg: float, b_deg: float) -> float:
	var d := _angle_ray_diff(a_deg, b_deg)
	return minf(d, 180.0 - d)


## Pass 3: split every way at its nodes into runs between adjacent welded
## points (way endpoints always bound a run — dead ends included). Every run
## gets its two directed lane edges.
func _extract_runs(streets: Array[Dictionary]) -> void:
	for wi in streets.size():
		var s: Dictionary = streets[wi]
		var pts: Array = s.get("points", [])
		if pts.size() < 2:
			continue
		var run_pts := PackedVector2Array()
		run_pts.append(Vector2(float(pts[0][0]), float(pts[0][1])))
		for pi in range(1, pts.size()):
			var p := Vector2(float(pts[pi][0]), float(pts[pi][1]))
			run_pts.append(p)
			## A run boundary: the way's end, or a welded junction/corner the
			## way passes through (interior single-way shape points and pure
			## continuation splices stay INSIDE the run).
			var boundary := pi == pts.size() - 1
			if not boundary:
				var key := _weld_key(p.x, p.y)
				if _weld_nodes.has(key) \
						and _node_kind[int(_weld_nodes[key])] >= KIND_CORNER:
					boundary = true
			if boundary:
				if run_pts.size() >= 2:
					_add_run(run_pts, str(s.get("class", "residential")),
							str(s.get("name", "")), float(s.get("width_m", 11.0)))
				run_pts = PackedVector2Array([p])
	## Directed edges: run r drives as r*2+0 (a→b) and r*2+1 (b→a); each is
	## filed under the node it LEAVES (the dealer walks out-edges).
	for r in _runs.size():
		_runs[r].reverse_edge = r * 2 + 1
		for dir in 2:
			var e := r * 2 + dir
			_edge_run.append(r)
			_edge_fwd.append(1 if dir == 0 else 0)
			var end_node := _runs[r].node_b if dir == 0 else _runs[r].node_a
			var start_node := _runs[r].node_a if dir == 0 else _runs[r].node_b
			_edge_to.append(end_node)
			_out_edges[start_node].append(e)


func _add_run(pts: PackedVector2Array, cls: String, sname: String,
		width_m: float) -> void:
	var run := Run.new()
	run.cls = cls
	run.sname = sname
	run.width_m = width_m
	run.points = pts
	run.node_a = int(_weld_nodes[_weld_key(pts[0].x, pts[0].y)])
	run.node_b = int(_weld_nodes[_weld_key(pts[pts.size() - 1].x, pts[pts.size() - 1].y)])
	## The AABB seeds from the first point — Godot's default Rect2 sits at the
	## origin, and a default-seeded expand would drag every midpoint toward
	## (0, 0) (the wrong-district bug this fixed).
	run.aabb = Rect2(pts[0], Vector2.ZERO)
	for i in pts.size() - 1:
		run.length += pts[i].distance_to(pts[i + 1])
		run.aabb = run.aabb.expand(pts[i + 1])
	run.mid = run.aabb.get_center()
	run.lane_off = clampf(width_m * 0.5 - 3.5, LANE_OFF_MIN, width_m * 0.5 - LANE_OFF_MIN)
	run.cruise = float(CRUISE_BY_CLASS.get(cls, 4.5))
	run.district = AmesBaker._district_of(run.mid.x, run.mid.y, _context)
	run.weight = float(SPAWN_WEIGHT_BY_CLASS.get(cls, 0.7)) \
			* float(SPAWN_WEIGHT_BY_DISTRICT.get(run.district, 1.0))
	run.lane_fwd = _offset_polyline(pts, run.lane_off)
	var rev := pts.duplicate()
	rev.reverse()
	run.lane_bwd = _offset_polyline(rev, run.lane_off)
	_runs.append(run)


## The right-hand lane polyline of a centerline: every vertex offset to the
## travel direction's right (2D right of (dx,dz) is (-dz,dx)), mitred at
## interior bends (the offset vector grows by 1/cos(θ/2), clamped against
## near-reversal spikes), endpoints riding their own segment's normal.
static func _offset_polyline(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var r_prev := Vector2.ZERO
		if i > 0:
			var d := pts[i] - pts[i - 1]
			if d.length() > 0.0001:
				r_prev = Vector2(-d.y, d.x) / d.length()
		var r_next := Vector2.ZERO
		if i < n - 1:
			var d := pts[i + 1] - pts[i]
			if d.length() > 0.0001:
				r_next = Vector2(-d.y, d.x) / d.length()
		var offset := Vector2.ZERO
		if r_prev == Vector2.ZERO:
			offset = r_next * off
		elif r_next == Vector2.ZERO:
			offset = r_prev * off
		else:
			var m := r_prev + r_next
			if m.length() > 0.01:
				var mn := m / m.length()
				var scale := off / maxf(mn.dot(r_prev), 0.35)
				offset = mn * minf(scale, off * MITER_LIMIT)
			else:
				offset = r_prev * off ## Near-reversal: keep the incoming side.
		out[i] = pts[i] + offset
	return out


## Pass 4: the 9 at-grade vehicular rail crossings as route facts — each
## crossing's position flags the graph node it rides (within
## `RAIL_NODE_RADIUS` of a welded node) AND the run it lies on (its nearest
## centerline within the asphalt); cars cross freely — no train events, no
## gates (T-194 dresses the corridor later).
func _flag_rail() -> void:
	for crossing: Dictionary in AmesDataPack.rail().get("crossings", []):
		if str(crossing.get("grade", "")) != "at_grade":
			continue ## Grade-separated: the road bridges the track — no fact.
		var pos: Array = crossing.get("pos", [])
		if pos.size() < 2:
			continue
		var px := float(pos[0])
		var pz := float(pos[1])
		## Node flag: the nearest node within radius (a crossing may weld onto
		## a junction or sit between two of them).
		var best := -1
		var best_d := RAIL_NODE_RADIUS
		for i in _nodes.size():
			var d := Vector2(_nodes[i].x - px, _nodes[i].z - pz).length()
			if d <= best_d:
				best_d = d
				best = i
		if best >= 0:
			_node_rail[best] = true
		## Run flag: the nearest centerline within its road's half-width.
		var run_hit := nearest_run(px, pz)
		if not run_hit.is_empty() and float(run_hit["dist"]) \
				<= _runs[int(run_hit["run"])].width_m * 0.5 + 2.0:
			_runs[int(run_hit["run"])].rail = true


## True when the run crosses an at-grade rail track (the T-178 route fact).
func run_is_rail(run_id: int) -> bool:
	return _runs[run_id].rail


## Squared distance from (x, z) to segment ab, with the projection kept in
## `_last_t` (0..1) for callers that need the point.
func _seg_dist2(x: float, z: float, a: Vector2, b: Vector2) -> float:
	var dx := b.x - a.x
	var dz := b.y - a.y
	var l2 := dx * dx + dz * dz
	var t := 0.0
	if l2 > 1e-12:
		t = clampf(((x - a.x) * dx + (z - a.y) * dz) / l2, 0.0, 1.0)
	_last_t = t
	var px := a.x + t * dx
	var pz := a.y + t * dz
	return (x - px) * (x - px) + (z - pz) * (z - pz)

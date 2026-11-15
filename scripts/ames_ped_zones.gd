class_name AmesPedZones
extends RefCounted
## The Ames pedestrian zones (T-181) — where the people actually are. The
## census maps 191.75 km of footway (BUILD-CENSUS.md §5); covering it is
## neither possible nor wanted — the zones are the pinned activity streets:
## the Welch Ave strip (Lincoln Way → the 300 block), downtown Main Street,
## the Central Campus lawn-edge path, the Lake LaVerne shore path and the MU
## corner. Each zone derives its sidewalk polyline set from the committed
## pack as a PURE FUNCTION (the traffic graph's own welded runs, offset to
## the walk edge outside the asphalt; the park/shore polygons at their pinned
## insets), carries a pinned population cap and bench/sit targets at
## ground-guarded positions, and the walking law is the T-165 measured gait,
## unchanged. The crossing fence: a zone route leg is marked a ROAD CROSSING
## only where it passes through a pinned anchor's crosswalk band (the T-180
## geometry) — the MU corner's Lincoln Way crossing is the one such leg; every
## other zone path stays clear of the asphalt entirely, so "nobody walks on
## roads except at crossings" holds structurally, not by sampling luck.
##
## Zone presence is a DENSITY function (the tone fence): the caps are
## steady-state, no schedules, no time-of-day gating — nobody has an
## appointment. Time-of-day scaling stays an owner-picked R6 option.
##
## Bench honesty note: the survey carries NO mapped bench nodes (verified —
## zero `amenity=bench` in census/tagged-nodes-core.json this session), so
## "real bench positions" means ground-guarded positions derived from the
## zone's own real geometry at pinned fractions of its paths, built at the
## retired Windrow bench's exact dimensions (seat slab top 0.54 — the
## T-163 law's wood top — over the T-141 spot line 0.60). T-183 re-homes the
## favor benches onto this set; this ticket is placement + walking only.
## (T-187 campus amendment) the Central Campus zone's benches moved OFF the
## abstract ring fractions onto the committed lawn layer's real geography —
## the walk chains' junction (the two crossing sight axes' meeting point),
## the fountain plaza (facing the pool down its walk) and the campanile
## stub (facing the tower) — all derived from `AmesDataPack.campus_lawn()`,
## never invented. T-183's favor elders seat THESE benches.

## --- the zone law (placement data law, pinned by `ames_ped_zones`) ----------

## Sidewalk center offset beyond a street's half-width (m) — the walk edge.
const WALK_EDGE := 1.6
## The Central Campus lawn-edge path's inset inside the park polygon (m,
## toward the centroid) — the real periphery walk; 15 m clears every road
## the polygon touches (probe 2026-11-13: insets 15/20/25 conflict-free).
const CAMPUS_INSET := 15.0
## The LaVerne shore path's offset off the lake polygon (m) — the T-176
## bread ring's own SHORE_OFFSET, so path and crumb ring share one edge law.
const SHORE_OFFSET := 6.0
## Waypoint densification cadence (m) — walkers turn at waypoints.
const DENSIFY_STEP := 8.0
## The bench sit line over the ground (m) — the retired `elder_spots`
## contract ("root sits 0.60 above the slab"): the T-163 seat-contact law
## reads the DEF-hips bone relative to THIS line on the T-141 composite.
const BENCH_SEAT_LINE := 0.60
## Bench side offset off its path (m, away from the walk line) — walkers pass
## beside the furniture, never through it (bench half-depth 0.25 + capsule
## 0.28 stays clear).
const BENCH_SIDE_OFFSET := 1.3
## A ground-guarded point whose ground query answers taller than this is
## inside a building footprint — nudged off its spot (the T-176
## GROUND_COVER_MAX law).
const GROUND_COVER_MAX := 0.5
## The ground-guard ladder steps (m) a blocked point walks before the vertex
## is dropped.
const GUARD_LADDER: Array[float] = [1.0, 2.0, 3.5, 5.0, 7.0]

## The pinned zone table. Caps: Welch carries the densest crowd (the Reddit
## lane's whole point — "everyone just knew to gather on Welch"); downtown
## the visitor premise's second cluster; the MU corner the campus-side
## frontage walk; the locals (elder class) hold Central Campus + LaVerne.
## (T-183) The favor economy's elder benches sit ON these zones — the
## ElderSpawner's FAVOR_ZONE_IDS law (campus + downtown + shore) seats one
## favor elder per bench, the T-114 loop live; the caps themselves are
## untouched placement law.
const ZONE_CAPS: Dictionary = {
	"welch_strip": 12,
	"downtown_main": 8,
	"mu_corner": 4,
	"central_campus": 6,
	"laverne_shore": 4,
}
## Who populates each zone: visitors (the Tourist scene) on Welch + downtown
## + the MU frontage, locals (the Elder scene) on campus + the shore.
const ZONE_CLASS: Dictionary = {
	"welch_strip": "tourist",
	"downtown_main": "tourist",
	"mu_corner": "tourist",
	"central_campus": "elder",
	"laverne_shore": "elder",
}
## Bench/sit targets per zone (occupancy is the population's to give: the
## elder zones seat their locals; since T-183 the FAVOR_ZONE_IDS zones'
## benches seat favor elders — the T-114 economy re-homed onto this set —
## while the other zones' benches stand as furniture).
const ZONE_BENCHES: Dictionary = {
	"welch_strip": 2,
	"downtown_main": 2,
	"mu_corner": 1,
	"central_campus": 3,
	"laverne_shore": 2,
}

## The bench furniture palette (the CafeSpawner's shared furniture colors —
## one wood, one metal, the retired bench's two keys).
const BENCH_WOOD := Color(0.55, 0.38, 0.24)
const BENCH_METAL := Color(0.25, 0.26, 0.28)


## One zone: its sidewalk polyline set (pack-local XZ), its population cap,
## class and bench/sit targets.
class Zone:
	extends RefCounted
	var id: String = ""
	var klass: String = "" ## "tourist" | "elder" (the ZONE_CLASS law).
	var cap: int = 0
	## Sidewalk polylines, pack-local XZ. Open polylines BOUNCE (the walk
	## reverses at the ends); closed ones (first point repeated last) LOOP.
	var paths: Array[PackedVector2Array] = []
	var closed: Array[bool] = []
	## Per path: the unit (pack-local XZ) toward the road the path lines —
	## the benches face this way and sit the other way (walkers pass behind).
	var road_dirs: Array[Vector2] = []
	## Per path: the leg ARRIVING at vertex i crosses road asphalt (inside a
	## pinned crosswalk band). Empty = no crossing legs.
	var crosses: Array = []
	## Bench/sit targets at the seat line (origin ground + BENCH_SEAT_LINE,
	## yaw = the bench's own facing), pack-local.
	var benches: Array[Transform3D] = []

	func _init(zone_id: String = "", zone_class: String = "", zone_cap: int = 0) -> void:
		id = zone_id
		klass = zone_class
		cap = zone_cap


var zones: Array[Zone] = []

var _world: AmesWorld
var _graph: AmesTrafficGraph


func _init(world: AmesWorld, graph: AmesTrafficGraph) -> void:
	_world = world
	_graph = graph
	if graph == null or graph.run_count() == 0:
		push_error("AmesPedZones: no traffic graph — zones build empty")
		return
	_build_welch_strip()
	_build_downtown_main()
	_build_mu_corner()
	_build_central_campus()
	_build_laverne_shore()


## The zone with the given id (null when none) — tests and the spawners read.
func zone(id: String) -> Zone:
	for z: Zone in zones:
		if z.id == id:
			return z
	return null


## --- the street zones ------------------------------------------------------


## The Welch Ave strip (Lincoln Way → the 300 block): the strip's four block
## faces — both sidewalks, split at the Chamberlain junction pad (the
## Campustown cross street the strip crosses; the fence sends its crossers
## over the pinned crosswalk, and the divided-section pad data puts even the
## band-line corners inside asphalt — so the zone strolls each block face
## instead and crosses nothing). Open (bounce) paths, zero crossing legs.
func _build_welch_strip() -> void:
	var zone := Zone.new("welch_strip", ZONE_CLASS["welch_strip"], ZONE_CAPS["welch_strip"])
	var half := _chain_half_width("Welch Avenue")
	for side: Vector2 in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]:
		var walk := _side_walk("Welch Avenue", Vector2(-30.0, 30.0),
				Vector2(0.0, 460.0), side, Vector2(0.0, 1.0))
		var core := _densify(_trim_chain(walk, 10.0, 388.0), false)
		var off := half + WALK_EDGE if side.x < 0.0 else -(half + WALK_EDGE)
		var path := _guard_sidewalk(_sidewalk_offset(core, off), core)
		_append_path(zone, path, false,
				Vector2(1.0, 0.0) if side.x < 0.0 else Vector2(-1.0, 0.0))
	_split_at_pads(zone)
	_benches_for_open_zone(zone, [0.2, 0.55, 0.8, 0.95])
	zones.append(zone)


## Downtown Main Street: both sidewalks of the welded Main chain across the
## census downtown window, open (bounce) paths, zero crossing legs.
func _build_downtown_main() -> void:
	var zone := Zone.new("downtown_main", ZONE_CLASS["downtown_main"], ZONE_CAPS["downtown_main"])
	var half := _chain_half_width("Main Street")
	var south_core := _densify(_trim_chain(
			_side_walk("Main Street", Vector2(2440.0, 3300.0), Vector2(-280.0, -240.0),
					Vector2(0.0, 1.0), Vector2(1.0, 0.0)), 18.0, 810.0), false)
	var north_core := _densify(_trim_chain(
			_side_walk("Main Street", Vector2(2440.0, 3300.0), Vector2(-280.0, -240.0),
					Vector2(0.0, -1.0), Vector2(1.0, 0.0)), 18.0, 810.0), false)
	var right := _guard_sidewalk(_sidewalk_offset(south_core, half + WALK_EDGE), south_core)
	var left := _guard_sidewalk(_sidewalk_offset(north_core, -(half + WALK_EDGE)), north_core)
	## The walks run east (x+): the right side is south, left is north.
	_append_path(zone, right, false, Vector2(0.0, -1.0))
	_append_path(zone, left, false, Vector2(0.0, 1.0))
	_split_at_pads(zone)
	_benches_for_open_zone(zone, [0.4, 0.6])
	zones.append(zone)


## The MU corner: Lincoln Way's north (campus-side) walk from the Welch corner
## to the Morrill corner, open (bounce), PLUS the one real crossing leg —
## south across Lincoln Way through the L/W × Welch signal corner's east
## crosswalk band (the students' southbound crossing into Campustown,
## VENUES.md §0). The leg is marked cross: the walkers hold the curb until
## the fleet clears, cross only the band, and the cars' T-180 band yield
## watches them (the tourist fleet rides `traffic.watched`).
func _build_mu_corner() -> void:
	var zone := Zone.new("mu_corner", ZONE_CLASS["mu_corner"], ZONE_CAPS["mu_corner"])
	var half := _chain_half_width("Lincoln Way")
	var core := _densify(_trim_chain(
			_side_walk("Lincoln Way", Vector2(0.0, 320.0), Vector2(-20.0, 20.0),
					Vector2(0.0, -1.0), Vector2(1.0, 0.0)), 12.0, 298.0), false)
	var north := _guard_sidewalk(_sidewalk_offset(core, -(half + WALK_EDGE)), core)
	## The crossing leg: the walk's west end steps south across the road
	## through the east crosswalk band, to the far curb + walk edge. The leg
	## is the path's FIRST leg (leg-indexed flags — the bounce path walks it
	## both ways and the tourist's curb gate reads either end).
	var band := _crossing_band(north[0], Vector2(0.0, 1.0)) ## Cross southward.
	if band.is_empty():
		push_error("AmesPedZones: no crosswalk band at the MU corner — crossing leg dropped")
		_append_path(zone, north, false, Vector2(0.0, 1.0))
	else:
		var axis: Vector2 = band["axis"]
		var across := Vector2(-axis.y, axis.x)
		var far: Vector2 = band["center"] \
				+ across * (float(band["half_across"]) + WALK_EDGE)
		## Far curb on the side AWAY from the walk's own side: pick the sign
		## of `across` that points south of the road centerline node.
		var node: Vector2 = band["node"]
		if (far - node).y < 0.0:
			far = band["center"] \
					- across * (float(band["half_across"]) + WALK_EDGE)
		var path := PackedVector2Array()
		path.append(_guard_point(far, (north[0] - far).normalized()))
		for p: Vector2 in north:
			path.append(p)
		var crosses: Array[bool] = []
		for i in path.size() - 1:
			crosses.append(i == 0) ## Leg 0 (far curb -> the walk) is the crossing.
		zone.paths.append(path)
		zone.closed.append(false)
		zone.road_dirs.append(Vector2(0.0, 1.0)) ## The road is south of the walk.
		zone.crosses.append(crosses)
	_benches_for_open_zone(zone, [0.5])
	zones.append(zone)


## --- the green-zone paths --------------------------------------------------


## The Central Campus lawn-edge path: one closed loop 15 m inside the park
## polygon (the real periphery walk — road-free by probe), densified and
## ground-guarded inward. (T-187) the zone's benches stand at the lawn
## layer's real sit targets — the axes' junction, the fountain plaza and the
## campanile stub — NOT the pre-T-187 ring fractions: the lawn's own sit
## law, `_campus_bench_targets`, derives them from the committed data.
func _build_central_campus() -> void:
	var zone := Zone.new("central_campus", ZONE_CLASS["central_campus"], ZONE_CAPS["central_campus"])
	var poly := _park_polygon("Central Campus")
	if poly.size() < 3:
		push_error("AmesPedZones: no Central Campus polygon — zone builds empty")
		return
	var ring := _inset_ring(poly, CAMPUS_INSET)
	ring = _densify(ring, true)
	ring = _guard_ring(ring, _centroid(poly), true)
	_append_path(zone, ring, true, Vector2.ZERO)
	_benches_at_targets(zone, _campus_bench_targets())
	zones.append(zone)


## (T-187) The campus sit targets, derived from the committed lawn layer —
## one facing + ground-guarded position per target, exactly three (the
## ZONE_BENCHES law): the two crossing sight axes' junction (facing north up
## the spine toward the library read), the fountain plaza (facing the pool
## down its walk) and the campanile stub (facing the tower). Every position
## is a pure function of `AmesDataPack.campus_lawn()` + the pack POIs.
func _campus_bench_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lawn: Dictionary = AmesDataPack.campus_lawn()
	if lawn.is_empty():
		return out ## The gate fails loudly on the missing targets.
	var chains: Array[PackedVector2Array] = []
	for path: Dictionary in lawn.get("paths", []):
		var pts := PackedVector2Array()
		for q: Variant in path.get("chain", []):
			pts.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
		if pts.size() >= 2:
			chains.append(pts)
	var by_id := {}
	for path2: Dictionary in lawn.get("paths", []):
		by_id[str(path2.get("id", ""))] = path2
	## 1. The axes junction: the E-W axis' vertex nearest the spine chain;
	##    the bench faces the spine's own run direction (north — the library
	##    read) and stands clear of the E-W ribbon (its own data half-width
	##    plus the bench side offset — the path law applied to a wide path).
	var ew_path: Dictionary = by_id.get("axis_ew_beardshear", {})
	var ew := _lawn_chain_pts(ew_path)
	var ns := _lawn_chain_pts(by_id.get("axis_ns_spine", {}))
	if ew.size() >= 2 and ns.size() >= 2:
		var junction := Vector2.ZERO
		var best_d := INF
		for p: Vector2 in ew:
			var d := _point_chain_dist(p, ns)
			if d < best_d:
				best_d = d
				junction = p
		var spine_dir := (ns[ns.size() - 1] - ns[0]).normalized()
		var clear := float(ew_path.get("width_m", 3.0)) * 0.5 + BENCH_SIDE_OFFSET
		var pos := junction - spine_dir * clear
		out.append({"pos": _guard_point(pos, -spine_dir), "facing": spine_dir})
	## 2. The fountain plaza: the plaza ring's centroid; the bench sits on
	##    the side away from the pool and faces it (the pool ring's centroid).
	var fountain: Dictionary = lawn.get("fountain", {})
	var plaza := _lawn_ring_pts(fountain, "plaza_ring")
	var pool := _lawn_ring_pts(fountain, "ring")
	if plaza.size() >= 3 and pool.size() >= 3:
		var plaza_c := _centroid(plaza)
		var pool_c := _centroid(pool)
		var facing2 := (pool_c - plaza_c).normalized()
		var pos2 := plaza_c - facing2 * BENCH_SIDE_OFFSET
		out.append({"pos": _guard_point(pos2, -facing2), "facing": facing2})
	## 3. The campanile stub: its midpoint, offset perpendicular away from
	##    the tower POI, facing the tower.
	var stub_path: Dictionary = by_id.get("campanile_stub", {})
	var stub := _lawn_chain_pts(stub_path)
	var cam_poi := Vector2.ZERO
	var found := false
	for p: Dictionary in AmesDataPack.pois():
		if str(p.get("id", "")) == "campanile":
			cam_poi = Vector2(float(p["position"][0]), float(p["position"][1]))
			found = true
			break
	if stub.size() == 2 and found:
		var mid := (stub[0] + stub[1]) * 0.5
		var seg := stub[1] - stub[0]
		var perp := Vector2(seg.y, -seg.x).normalized()
		if (mid - cam_poi).dot(perp) < 0.0:
			perp = -perp ## The offset side is the one away from the tower.
		var stub_clear := float(stub_path.get("width_m", 3.0)) * 0.5 \
				+ BENCH_SIDE_OFFSET
		var pos3 := mid + perp * stub_clear
		var facing3 := (cam_poi - mid).normalized()
		out.append({"pos": _guard_point(pos3, perp), "facing": facing3})
	return out


## Benches for the pinned campus targets: one per surviving target, facing
## its derived direction, ground-guarded (dropped when the ladder ends).
func _benches_at_targets(zone: Zone, targets: Array[Dictionary]) -> void:
	for target: Dictionary in targets:
		var facing: Vector2 = target["facing"]
		var pos: Vector2 = target["pos"]
		if pos.x == INF or not _ground_ok(pos):
			continue
		zone.benches.append(Transform3D(Basis(Vector3.UP, _yaw_of(facing)),
				Vector3(pos.x, BENCH_SEAT_LINE, pos.y)))


## One lawn-layer chain packed ({} -> empty).
func _lawn_chain_pts(path: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q: Variant in path.get("chain", []):
		out.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
	return out


## One lawn-layer fountain ring packed and RING-SPLIT (the baker's dedupe
## law — the OSM closure duplicate must not skew a centroid) ({} -> empty).
func _lawn_ring_pts(fountain: Dictionary, field: String) -> PackedVector2Array:
	var raw := PackedVector2Array()
	for q: Variant in fountain.get(field, []):
		raw.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
	var biggest := PackedVector2Array()
	for ring: PackedVector2Array in AmesBaker._split_rings(raw):
		if ring.size() > biggest.size():
			biggest = ring
	return biggest


## The distance from `p` to the nearest point ON a polyline's segments.
func _point_chain_dist(p: Vector2, chain_pts: PackedVector2Array) -> float:
	var best := INF
	for i in chain_pts.size() - 1:
		var a := chain_pts[i]
		var b := chain_pts[i + 1]
		var d := b - a
		var l2 := d.length_squared()
		var t := 0.0
		if l2 > 1e-12:
			t = clampf((p - a).dot(d) / l2, 0.0, 1.0)
		best = minf(best, p.distance_to(a + d * t))
	return best


## The Lake LaVerne shore path: one closed loop SHORE_OFFSET off the water
## polygon (the T-176 shore-ring edge law, road-free by probe), densified and
## ground-guarded outward, benches facing the water.
func _build_laverne_shore() -> void:
	var zone := Zone.new("laverne_shore", ZONE_CLASS["laverne_shore"], ZONE_CAPS["laverne_shore"])
	var poly := _lake_polygon()
	if poly.size() < 3:
		push_error("AmesPedZones: no Lake LaVerne polygon — zone builds empty")
		return
	var ring := _outset_ring(poly, SHORE_OFFSET)
	ring = _densify(ring, true)
	ring = _guard_ring(ring, _centroid(poly), false)
	_append_path(zone, ring, true, Vector2.ZERO)
	_benches_for_ring_zone(zone, [0.3, 0.7], _centroid(poly))
	zones.append(zone)


## --- derivation helpers ----------------------------------------------------


## The per-side street walk (T-181): the welded pieces of every graph run
## named `sname` inside the (x-window, z-window) box, walked from every
## piece endpoint (greedy, no piece reuse) with the fork rule "farthest
## along `side_dir`" — a divided section (Welch's Campustown dual
## carriageway, Lincoln Way's pair) forks at its merge nodes and each side's
## walk takes ITS carriageway, so a sidewalk never runs the median. Picks
## the walk whose midpoint sits farthest along `side_dir` (the side IS the
## walk must not lose a window-cut parallel carriageway on point count, so
## ties break to the midpoint farthest along `side_dir`, then to the most
## vertices. The result is oriented along `forward` (the zone's own walk
## direction) so the offset sides keep their sign law.
func _side_walk(sname: String, x_win: Vector2, z_win: Vector2,
		side_dir: Vector2, forward: Vector2) -> PackedVector2Array:
	var pieces: Array[PackedVector2Array] = []
	for r in _graph.run_count():
		if _graph.run_name(r) != sname:
			continue
		var pts := _graph.run_points(r)
		var mid := _graph.run_mid(r)
		if mid.x < x_win.x or mid.x > x_win.y 				or mid.y < z_win.x or mid.y > z_win.y:
			continue
		var dup := false
		for taken: PackedVector2Array in pieces:
			if _is_reverse_duplicate(pts, taken):
				dup = true
				break
		if dup:
			continue ## The pack double-lists the way — one copy serves.
		pieces.append(pts)
	## Weld-key adjacency: endpoint -> piece indices, plus each piece's
	## vertex-average (the fork rule's deviation read — endpoint midpoints
	## are identical for a fork-merge pair, the vertex average is not).
	var adj: Dictionary = {}
	var piece_mids: Array[Vector2] = []
	for pi in pieces.size():
		var acc := Vector2.ZERO
		for p: Vector2 in pieces[pi]:
			acc += p
		piece_mids.append(acc / maxf(float(pieces[pi].size()), 1.0))
		for end_i in 2:
			var k := _weld_key(pieces[pi][0 if end_i == 0 else pieces[pi].size() - 1])
			if not adj.has(k):
				adj[k] = []
			(adj[k] as Array).append(pi)
	var best := PackedVector2Array()
	var best_score := Vector3(-1, -INF, -1) ## (pieces, side dot, vertices)
	for start_pi in pieces.size():
		for start_end in 2:
			var walked := _walk_pieces(pieces, adj, piece_mids, start_pi, start_end,
					side_dir)
			var walk: PackedVector2Array = walked["walk"]
			if walk.size() < 2:
				continue
			var mid_acc := Vector2.ZERO
			for p: Vector2 in walk:
				mid_acc += p
			var walk_mid := mid_acc / float(walk.size())
			var side_dot := walk_mid.dot(side_dir)
			var score := Vector3(int(walked["coverage"]), side_dot, walk.size())
			if score.x > best_score.x 					or (score.x == best_score.x and score.y > best_score.y + 0.001) 					or (score.x == best_score.x and absf(score.y - best_score.y) <= 0.001
							and score.z > best_score.z):
				best = walk
				best_score = score
	if (best[best.size() - 1] - best[0]).dot(forward) < 0.0:
		best.reverse()
	return best


## One greedy walk from a piece endpoint: forward through unused pieces, at
## forks taking the candidate whose far midpoint deviates farthest along
## `side_dir`, never reusing a piece.
func _walk_pieces(pieces: Array[PackedVector2Array], adj: Dictionary,
		piece_mids: Array[Vector2], start_pi: int, start_end: int,
		side_dir: Vector2) -> Dictionary:
	var used: Dictionary = {start_pi: true}
	var pts: PackedVector2Array = pieces[start_pi]
	var walk := PackedVector2Array(pts)
	if start_end == 1:
		walk.reverse()
	var cur := walk[walk.size() - 1]
	while true:
		var cur_key := _weld_key(cur)
		var cands: Array = adj.get(cur_key, [])
		var pick := -1
		var pick_dev := -INF
		var pick_rev := false
		for cand: int in cands:
			if used.has(cand):
				continue
			var pp: PackedVector2Array = pieces[cand]
			var a := pp[0]
			var b := pp[pp.size() - 1]
			var rev := _close(cur, b)
			var far := a if rev else b
			if _close(cur, a) == false and not rev:
				continue
			var dev := (piece_mids[cand] - cur).dot(side_dir)
			if dev > pick_dev:
				pick_dev = dev
				pick = cand
				pick_rev = rev
		if pick < 0:
			break
		used[pick] = true
		var seg: PackedVector2Array = pieces[pick].duplicate()
		if pick_rev:
			seg.reverse()
		walk.append_array(seg.slice(1))
		cur = walk[walk.size() - 1]
	return {"walk": walk, "coverage": used.size()}


## The 1 cm weld key of a chain vertex (the graph's own quantization).
static func _weld_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))


## The widest street half-width over the graph runs named `name`.
func _chain_half_width(sname: String) -> float:
	var half := 5.0
	for r in _graph.run_count():
		if _graph.run_name(r) == sname:
			half = maxf(half, _graph.run_half_width(r))
	return half


static func _close(a: Vector2, b: Vector2) -> bool:
	return a.distance_squared_to(b) < 0.0001


## True when `pts` is a byte-reverse of `taken` (same vertex count, every
## vertex welding onto its reversed twin) — the pack's double-listed ways.
## A DIVIDED section's two carriageways share endpoints but not interiors;
## they are two pieces, never duplicates.
static func _is_reverse_duplicate(pts: PackedVector2Array,
		taken: PackedVector2Array) -> bool:
	if pts.size() != taken.size():
		return false
	for i in pts.size():
		if _weld_key(pts[i]) != _weld_key(taken[taken.size() - 1 - i]):
			return false
	return true


## Trims a point chain to the arc-length window [s0, s1] (the chain's own
## walk from its first point), cutting boundary points on the end segments.
func _trim_chain(pts: PackedVector2Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var walked := 0.0
	var started := false
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var lo := walked
		var hi := walked + seg
		walked = hi
		if hi < s0 or lo > s1:
			continue
		var t0 := clampf((s0 - lo) / maxf(seg, 0.0001), 0.0, 1.0)
		var t1 := clampf((s1 - lo) / maxf(seg, 0.0001), 0.0, 1.0)
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		if not started:
			out.append(p0)
			started = true
		elif out[out.size() - 1].distance_squared_to(p0) > 0.0001:
			out.append(p0)
		if t1 > t0:
			out.append(p1)
	return out


## The sidewalk offset of a centerline: per SEGMENT, the line pushed `off`
## sideways (sign-symmetric — no mitre math), with TWO points at every turn
## (each segment's own end/start) so the walk wraps the corner instead of
## cutting its mitre joint across the junction asphalt — a corner pair sits
## at the band's along-center where the sidewalk meets a pinned cross street,
## which is exactly the legal crossing line. The graph's `_offset_polyline`
## stays the LANES' tool (its mitre clamp assumes a positive offset and its
## joints cut corners).
static func _sidewalk_offset(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		if d.length() < 0.0001:
			continue
		var r := Vector2(-d.y, d.x) / d.length()
		var pa := a + r * off
		var pb := b + r * off
		if out.is_empty() or out[out.size() - 1].distance_squared_to(pa) > 0.0001:
			out.append(pa)
		out.append(pb)
	return out


## The pad law (T-181): a zone path never crosses a junction pad outside a
## pinned crosswalk band — a vertex whose road contact is NEITHER off-road
## NOR band-legal sits in a pad the path has no business walking; the path
## SPLITS there (the contact cluster plus one vertex of padding each side is
## dropped, the survivors become their own block-face strolls). The one
## legal crossing a zone carries is the one it builds explicitly through a
## band (the MU corner's Lincoln Way leg).
func _split_at_pads(zone: Zone) -> void:
	for pi in zone.paths.size():
		var path := zone.paths[pi]
		var segments: Array[PackedVector2Array] = []
		var current := PackedVector2Array()
		var i := 0
		while i < path.size():
			if _contact_kind(path[i]) == 2:
				## Drop the cluster plus one padding vertex each side.
				if current.size() > 0:
					current.remove_at(current.size() - 1)
				if current.size() >= 2:
					segments.append(current)
				current = PackedVector2Array()
				i += 1
				while i < path.size() and _contact_kind(path[i]) == 2:
					i += 1
				continue
			current.append(path[i])
			i += 1
		if current.size() >= 2:
			segments.append(current)
		if segments.size() > 1 or (segments.size() == 1 \
				and segments[0].size() != path.size()):
			zone.paths[pi] = segments[0]
			var legs: Array[bool] = []
			for k in segments[0].size() - 1:
				legs.append(false)
			zone.crosses[pi] = legs
			for si in range(1, segments.size()):
				zone.paths.append(segments[si])
				zone.closed.append(false)
				zone.road_dirs.append(zone.road_dirs[pi])
				var more: Array[bool] = []
				for k in segments[si].size() - 1:
					more.append(false)
				zone.crosses.append(more)


## The road-contact kind of a pack-local point: 0 off-road, 1 inside a pinned
## crosswalk band, 2 mid-block contact (the pad law's trigger).
func _contact_kind(p: Vector2) -> int:
	var hit := _graph.nearest_run(p.x, p.y)
	if hit.is_empty():
		return 0
	if float(hit["dist"]) >= _graph.run_half_width(int(hit["run"])) + 0.5:
		return 0
	return 1 if _in_any_band(p) else 2


## True when the point sits inside ANY pinned anchor's crosswalk band (the
## same derivation the gate recomputes — the bands are the graph's law).
func _in_any_band(p: Vector2) -> bool:
	for a in _graph.intersection_count():
		if _graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		for member in _graph.intersection_members(a):
			for edge in _graph.node_in_edges(member):
				var geo := _graph.approach_geometry(member, edge)
				if not bool(geo["fits"]):
					continue
				var band: Dictionary = geo["band"]
				var rel := p - (band["center"] as Vector2)
				var axis: Vector2 = band["axis"]
				if absf(rel.dot(axis)) <= float(band["half_along"]) \
						and absf(rel.dot(Vector2(-axis.y, axis.x))) \
								<= float(band["half_across"]):
					return true
	return false


## One sidewalk polyline, ground-guarded: a point inside a building footprint
## walks the guard ladder OUTWARD (along its own offset from the core
## centerline point) before the vertex is dropped.
func _guard_sidewalk(pts: PackedVector2Array, core: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var p := pts[i]
		var away := Vector2.RIGHT
		if i < core.size():
			var d := p - core[i]
			if d.length_squared() > 0.0001:
				away = d.normalized()
		out.append(_guard_point(p, away))
	return out


## Ground-guard one point: ladder steps along `away` while the world answers
## a rooftop; the ladder's end drops the point (INF sentinel — the caller
## splices).
func _guard_point(p: Vector2, away: Vector2) -> Vector2:
	if _ground_ok(p):
		return p
	for step: float in GUARD_LADDER:
		var q := p + away * step
		if _ground_ok(q):
			return q
	return Vector2(INF, INF)


func _ground_ok(p: Vector2) -> bool:
	return _world.ground_height(_world.to_global(Vector3(p.x, 0.0, p.y))) \
			<= GROUND_COVER_MAX


## Appends one derived path (dropping guard-dropped vertices), closing loops.
## `toward_road` records the path's road direction for the bench law.
func _append_path(zone: Zone, pts: PackedVector2Array, closed: bool,
		toward_road: Vector2) -> void:
	var path := PackedVector2Array()
	for p: Vector2 in pts:
		if p.x == INF:
			continue
		path.append(p)
	if path.size() < 2:
		return
	if closed:
		if path[0].distance_squared_to(path[path.size() - 1]) > 0.0001:
			path.append(path[0])
	zone.paths.append(path)
	zone.closed.append(closed)
	zone.road_dirs.append(toward_road)
	var legs: Array[bool] = []
	for i in path.size() - 1:
		legs.append(false)
	zone.crosses.append(legs)


## Benches for an open (sidewalk) zone: one per fraction, alternating paths,
## each facing its path's road (the ZONE law) and sitting the other way —
## walkers pass behind the furniture.
func _benches_for_open_zone(zone: Zone, fractions: Array) -> void:
	var want := int(ZONE_BENCHES.get(zone.id, 0))
	var fracs: Array = fractions.duplicate()
	fracs.resize(mini(want, fracs.size()))
	for i in fracs.size():
		var path_i := i % zone.paths.size()
		var path := zone.paths[path_i]
		var frac: float = fracs[i]
		var at := _point_at(path, frac)
		if at.x == INF:
			continue
		var facing := zone.road_dirs[path_i] if path_i < zone.road_dirs.size() \
				else Vector2(0.0, 1.0)
		var pos := _guard_point(at - facing * BENCH_SIDE_OFFSET,
				-facing)
		if pos.x == INF or not _ground_ok(pos):
			continue
		zone.benches.append(Transform3D(Basis(Vector3.UP, _yaw_of(facing)),
				Vector3(pos.x, BENCH_SEAT_LINE, pos.y)))


## Benches for a ring zone: at the fractions, facing the ring's target (the
## lawn centroid / the water) and sitting toward it — walkers pass behind.
func _benches_for_ring_zone(zone: Zone, fractions: Array, target: Vector2) -> void:
	var want := int(ZONE_BENCHES.get(zone.id, 0))
	var fracs: Array = fractions.duplicate()
	fracs.resize(mini(want, fracs.size()))
	var path := zone.paths[0]
	for frac: Variant in fracs:
		var at := _point_at(path, frac)
		if at.x == INF:
			continue
		var facing := (target - at).normalized()
		var pos := _guard_point(at + facing * BENCH_SIDE_OFFSET, facing)
		if pos.x == INF or not _ground_ok(pos):
			continue
		zone.benches.append(Transform3D(Basis(Vector3.UP, _yaw_of(facing)),
				Vector3(pos.x, BENCH_SEAT_LINE, pos.y)))


static func _yaw_of(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


## The point at arc fraction `frac` of a polyline (INF sentinel off-range).
func _point_at(path: PackedVector2Array, frac: float) -> Vector2:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	if total <= 0.0:
		return Vector2(INF, INF)
	var want := clampf(frac, 0.0, 1.0) * total
	var walked := 0.0
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if walked + seg >= want:
			var t := (want - walked) / maxf(seg, 0.0001)
			return path[i].lerp(path[i + 1], t)
		walked += seg
	return path[path.size() - 1]


## Inserts points every DENSIFY_STEP along a polyline; loops stay closed.
func _densify(path: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := path.size()
	var limit := n if closed else n - 1
	for i in limit:
		var a := path[i]
		var b := path[(i + 1) % n]
		var seg := a.distance_to(b)
		out.append(a)
		if seg <= DENSIFY_STEP:
			continue
		var steps := int(floorf(seg / DENSIFY_STEP))
		for k in range(1, steps + 1):
			out.append(a.lerp(b, float(k) * DENSIFY_STEP / seg))
	return out


## One polygon's inset ring (edge midpoints pulled `inset` toward the
## centroid) — the campus lawn-edge path shape.
func _inset_ring(poly: PackedVector2Array, inset: float) -> PackedVector2Array:
	var c := _centroid(poly)
	var ring := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var mid := (a + b) * 0.5
		var dir := (c - mid).normalized()
		ring.append(mid + dir * inset)
	return ring


## One polygon's outset ring (edge midpoints pushed `out` away from the
## centroid) — the shore path shape (the T-176 shore-ring law).
func _outset_ring(poly: PackedVector2Array, out: float) -> PackedVector2Array:
	var c := _centroid(poly)
	var ring := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var mid := (a + b) * 0.5
		var dir := (mid - c).normalized()
		ring.append(mid + dir * out)
	return ring


## Ground-guards a ring: blocked points walk the ladder toward `inward`
## direction for inset rings, away for outset ones.
func _guard_ring(ring: PackedVector2Array, center: Vector2, inset: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in ring:
		var away := (p - center).normalized()
		if inset:
			away = -away
		out.append(_guard_point(p, away))
	return out


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p: Vector2 in poly:
		c += p
	return c / maxf(float(poly.size()), 1.0)


## The crosswalk band a crossing from `from` should use: among the pinned
## anchors near `from`, the approach band whose ALONG line the crossing start
## sits nearest (the crossing walks the band's perpendicular — a band whose
## axis runs along the walk is the wrong road's band), preferring the band
## farthest along `prefer` — a divided road forks one band per carriageway,
## and the crossing must span the WHOLE road, so its far curb derives from
## the far carriageway's band (the near bands' spans still cover the leg —
## the gate checks containment against every pinned band). Returns
## {center, axis, half_along, half_across, node}.
func _crossing_band(from: Vector2, prefer: Vector2) -> Dictionary:
	var best := {}
	var best_score := Vector2(40.0, -INF) ## (anchor distance, prefer dot)
	for a in _graph.intersection_count():
		if _graph.intersection_pin(a) == AmesTrafficGraph.PIN_NONE:
			continue
		for member in _graph.intersection_members(a):
			var node_pos := _graph.node_pos(member)
			var flat_node := Vector2(node_pos.x, node_pos.z)
			var anchor_d := flat_node.distance_to(from)
			for edge in _graph.node_in_edges(member):
				var geo := _graph.approach_geometry(member, edge)
				if not bool(geo["fits"]):
					continue
				var band: Dictionary = geo["band"]
				var center := (band["center"] as Vector2)
				var axis := (band["axis"] as Vector2)
				## The walk starts on the band's perpendicular through ~center:
				## its offset ALONG the band axis must stay near the band.
				var along := absf((from - center).dot(axis))
				if along > float(band["half_along"]) + 8.0:
					continue
				## Nearest anchor wins outright; inside one anchor the farthest
				## band along `prefer` serves the whole-road crossing.
				if anchor_d > best_score.x + 20.0:
					continue
				var score := Vector2(anchor_d + along, center.dot(prefer))
				if score.x < best_score.x - 20.0 \
						or (score.x <= best_score.x + 20.0
								and score.y > best_score.y):
					best_score = score
					best = {
						"center": center,
						"axis": axis,
						"half_along": band["half_along"],
						"half_across": band["half_across"],
						"node": flat_node,
					}
	return best


func _park_polygon(park_name: String) -> PackedVector2Array:
	for park: Dictionary in AmesDataPack.parks():
		if str(park.get("name", "")) == park_name:
			var ring := PackedVector2Array()
			for q: Variant in park.get("polygon", []):
				ring.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
			return ring
	return PackedVector2Array()


func _lake_polygon() -> PackedVector2Array:
	for water: Dictionary in AmesDataPack.water():
		if str(water.get("name", "")) == "Lake LaVerne":
			var ring := PackedVector2Array()
			for q: Variant in water.get("polygon", []):
				ring.append(Vector2(float((q as Array)[0]), float((q as Array)[1])))
			return ring
	return PackedVector2Array()

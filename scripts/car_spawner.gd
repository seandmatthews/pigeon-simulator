class_name CarSpawner
extends BandSpawner
## The car service (T-008): keeps `target_moving` traffic cars driving ROUTES
## through the city's road grid (T-134 — a seeded random walk of intersection
## nodes dealt by `City.route_from` off this spawner's own `_rng` stream, so a
## car's block assignment changes as it DRIVES) and `target_parked` cars
## sitting in the curb spaces (`City.parking_spots`) around the player. At
## every intersection the four-way-stop protocol applies through the shared
## `TrafficControl` ledger each traffic car carries (`Car.traffic`; the
## `stop_protocol_enabled` hatch is the test escape back to bare pathing).
## When a route runs out the spawner deals a fresh one FROM the car's end node
## — continuous driving, no teleport; teleporting stays the recycle scan's job.
## The band/recycle machinery — the shared recycle exports, the recycle-scan
## timer and the band helpers — lives in the BandSpawner base (T-054). Since
## T-089 recycled traffic prefers blocks holding fewer than
## `ring_traffic_soft_cap` cars and rejoins at a probed follow-gap-clear point
## on the fresh route's first leg, so a standing player stops watching the
## band clot into one parked wall. Since T-128 BOTH placement paths (the
## populate loop and the recycle rejoin) pass the sightline gate: a candidate
## point within `spawn_sightline_max` of the player AND inside the chase
## camera's horizontal cone is rejected, so cars only ever enter view by
## driving — `sightline_gate_enabled` is the test escape hatch back to the old
## staging. Seeded from the city's seed and re-seeded on city regeneration,
## like the tourist (T-007) and bread (T-005) services. Every car splat relays
## as `car_splatted` — Main wires it into the Game autoload's score table
## (T-009).

## Relayed from each car's `splatted` — Main wires it into the Game autoload's
## score table (T-009).
signal car_splatted(car: Car)

@export_group("Population")
@export var car_scene: PackedScene = preload("res://scenes/car.tscn")
@export var target_moving: int = 14 ## Traffic cars kept driving routes (T-128: 20 → 14 — fewer visible spawn events).
@export var target_parked: int = 12 ## Cars kept parked at curbs (T-128: 16 → 12 — the owner's "less frequently").

@export_group("Classes")
@export var visitor_share: float = 0.40 ## Share of cars seeded in full visitor team paint with the flag up (T-113); civilians take the remainder.
@export var superfan_share: float = 0.05 ## Share of cars seeded as cardinal SUPERFAN vehicles (T-113).

@export_group("Sightline")
## (T-128) The off-screen placement gate: when ON, both placement paths (the
## populate loop and the recycle rejoin) reject candidate points inside the
## player's sightline — within `spawn_sightline_max` AND inside the chase
## camera's horizontal `spawn_avoid_cone_deg` half-angle cone — so cars only
## ever enter view by driving. OFF stages spawns the old way: the escape hatch
## for scenarios (and the least-bad fill) whose subject is not placement.
@export var sightline_gate_enabled: bool = true
@export var spawn_sightline_max: float = 80.0 ## Cone-test radius (flat, m) around the player — points at or beyond it always pass.
@export var spawn_avoid_cone_deg: float = 55.0 ## Avoided cone half-angle (deg) around the chase camera's live flat view direction.

## (T-134) The four-way-stop protocol hatch: when ON every traffic car gets
## the shared `TrafficControl` ledger and stops at every intersection; OFF
## hands the cars a null `traffic` — the whole protocol skips (the red-before
## probe and the bare-pathing escape hatch).
@export_group("Stops")
@export var stop_protocol_enabled: bool = true

@export_group("Recycle")
@export var recycle_probe_count: int = 5 ## Evenly spaced route-leg fractions probed for a follow-gap-clear traffic rejoin point before the random draw (T-089).
@export var ring_traffic_soft_cap: int = 3 ## Recycled traffic skips blocks already holding this many traffic cars while any band block is lighter (T-089).

@export_group("Wiring")
@export var bread_spawner_path: NodePath ## (T-114) The bread service tailgate crumbs drop through — Main wires the path.
@export var tourist_spawner_path: NodePath ## (T-134) The tourist fleet the crosswalk yield senses — Main wires the path.

## Car honks this run — the autoplay DONE line reports it. Splat-relay ONLY:
## patience honks ride `Car.honk_count` and never touch this counter (T-134).
var honk_count: int = 0

## (T-114) The bread service the tailgate crumbs drop through — resolved from
## `bread_spawner_path` in _ready; the sim harness assigns directly. Null
## (bare rigs) means the fleet grows coolers but no crumbs.
var bread_spawner: BreadSpawner

## (T-134) The shared four-way-stop ledger every traffic car carries, built
## here in _ready when `stop_protocol_enabled` is on. The crosswalk yield's
## watched bodies (the pigeon plus the tourist fleet) refresh on every
## populate.
var traffic_ctrl: TrafficControl = null

## (T-134) The tourist service the crosswalk yield senses through
## `traffic_ctrl.watched` — resolved from `tourist_spawner_path`; the harness
## assigns directly. Null means only the pigeon is watched.
var tourist_spawner: TouristSpawner

var _cars: Array[Car] = []

## (T-128) The chase camera rig the sightline cone reads — resolved once off
## the player's typed children (the rig is a direct `top_level` child in
## player.tscn, so its basis is world-frame); null falls the view direction
## back to the player's own facing.
var _camera_rig: Node3D

## The class quotas of the populate loop in flight (T-113): the class COUNTS
## are the share knobs' exact integer rounding at every seed, and the seeded
## draws in `_assign_class` pick WHICH car wears which uniform — same seed,
## same multiset. Opened per loop (traffic, parked) by `_begin_class_quota`.
var _class_slots_left: int = 0
var _visitors_left: int = 0
var _superfans_left: int = 0

## The city's block centers in global coords — handed to each dealt car so it
## can refresh its block assignment by driving (T-134).
var _block_centers_cache := PackedVector3Array()


func _ready() -> void:
	# (T-114) Resolve the tailgate bread service BEFORE super()'s populate —
	# the parked-visitor cars it seeds anchor their crumbs during _populate.
	if bread_spawner == null and not bread_spawner_path.is_empty():
		bread_spawner = get_node(bread_spawner_path) as BreadSpawner
	# (T-134) The tourist service and the shared stop ledger, likewise before
	# the populate hands cars out.
	if tourist_spawner == null and not tourist_spawner_path.is_empty():
		tourist_spawner = get_node(tourist_spawner_path) as TouristSpawner
	if stop_protocol_enabled:
		traffic_ctrl = TrafficControl.new()
	super()


func _init() -> void:
	# Beyond this flat distance (m) a car recycles to the player's area. Must
	# clear the WORST legitimate route leg distance — a car seeded at
	# spawn_max_dist drives legs ~32 m toward or away — or traffic gets yanked
	# mid-route and dropped on top of other cars. (A GDScript subclass cannot
	# redeclare the inherited export, so the tourist-default 80.0 becomes an
	# `_init` override — T-054.)
	recycle_radius = 100.0


## Living cars — tests and the autoplay pilot read these.
func living_cars() -> Array[Car]:
	_cars = _cars.filter(func(car: Car) -> bool: return is_instance_valid(car))
	return _cars.duplicate()


## Wipes and re-seeds the whole fleet (first boot, city regeneration).
func _populate() -> void:
	for car in _cars:
		if is_instance_valid(car):
			car.release_tailgate() ## (T-114) The anchored bread dies with its car — erased, not orphaned.
			car.queue_free()
	_cars.clear()
	if city == null or player == null:
		return
	_rng.seed = city.seed_value
	var anchor := _anchor_flat()
	if city.block_centers.is_empty():
		return
	_block_centers_cache = PackedVector3Array()
	for center in city.block_centers:
		_block_centers_cache.append(city.to_global(center))
	_refresh_watched()
	var made_moving := 0
	_begin_class_quota(target_moving)
	while made_moving < target_moving:
		var block := _pick_block(anchor)
		_spawn_traffic(block, made_moving)
		made_moving += 1
	var made_parked := 0
	var attempts := 0
	_begin_class_quota(target_parked)
	while made_parked < target_parked and attempts < target_parked * 8:
		attempts += 1
		if _try_place_parked(anchor, made_parked, sightline_gate_enabled):
			made_parked += 1
	## (T-128) The least-bad fill: a band whose every curb spot sits inside the
	## avoided cone must not starve the fleet COUNT contract — stage whatever
	## is missing the old way, gate off.
	while made_parked < target_parked and attempts < target_parked * 16:
		attempts += 1
		if _try_place_parked(anchor, made_parked, false):
			made_parked += 1
	## (T-114) The deferred tailgate dressing pass: one idle frame after the
	## populate. BreadSpawner's own populate may run later in the SAME
	## `regenerated` emission and queue-free every crumb it re-seeds around;
	## cars whose anchored crumb died in that wipe re-anchor here, and the
	## alive-check keeps this pass from ever double-dropping over `park_at`'s
	## own drops.
	_dress_tailgates.call_deferred()


## (T-134) The crosswalk yield's senses: the pigeon plus the whole living
## tourist fleet. Re-read on every populate — a re-seeded fleet is new nodes.
func _refresh_watched() -> void:
	if traffic_ctrl == null:
		return
	traffic_ctrl.watched.clear()
	if player != null:
		traffic_ctrl.watched.append(player)
	if tourist_spawner != null:
		for tourist in tourist_spawner.living_tourists():
			if is_instance_valid(tourist):
				traffic_ctrl.watched.append(tourist)


## Puts a car that drifted beyond the recycle radius back into the spawn band
## — the same node teleports onto a fresh dealt route (the recycle acceptance
## contract, as for tourists T-007). Since T-089 the block draw prefers light
## blocks and traffic rejoins at a probed follow-gap-clear point on the fresh
## route's first leg, so recycled cars stop stuffing full blocks into braking
## queues. Since T-128 every rejoin point also passes the sightline gate (a
## gated draw walks its own first leg, then the band — light blocks first; the
## free drawn point stands as the documented least-bad fallback), so recycled
## cars drive into view instead of popping. (T-147) The far list partitions:
## a car carrying `splatted_once` is despawn-eligible — it churns out of the
## fleet through `_replace_car` instead of teleporting back to a curb to be
## farmed again — while every never-splatted far car takes the teleport arms
## below byte-identical.
func _recycle_far() -> void:
	var anchor := _anchor_flat()
	var far: Array[Car] = []
	for car in _cars:
		if is_instance_valid(car) and _flat_dist(car.global_position, anchor) > recycle_radius:
			far.append(car)
	if far.is_empty():
		return
	var blocks := _blocks_in_band(anchor)
	if blocks.is_empty():
		return
	## (T-147) The duplicate iterates safely while `_replace_car` lands its
	## `_cars` swaps mid-loop; a spent car whose replacement has no
	## gate-passing placement this scan stays put — the next 0.5 s scan retries.
	var pending: Array[Car] = far.duplicate()
	for car in pending:
		if car.splatted_once:
			_replace_car(car)
			continue
		var block: Vector3 = _pick_recycle_block(blocks)
		if car.mode == Car.Mode.PARKED:
			if not _recycle_parked_to(car, block, blocks):
				continue
		else:
			var placement := _route_rejoin(block, car, false)
			if not _sightline_ok(placement.pos):
				var scan := _offscreen_route_rejoin(blocks, car)
				if not scan.is_empty():
					block = scan.block
					placement = scan.placement
			## else: least-bad — the drawn rejoin stands (in view, documented).
			car.start_route(placement.pos, placement.points, placement.entries,
					city.to_global(block), _block_centers_cache, placement.end)


## (T-147) Swaps one despawn-eligible far car for a FRESH splat-fresh node —
## the churn that keeps the favor economy renewable: the spent car is already
## beyond `recycle_radius` (out of reach) and a fresh like-for-like car takes
## its fleet slot, entering off-screen. The replacement's identity is
## like-for-like, zero RNG: `citizen_class`, `body_color` (civilians keep
## their palette paint, visitors keep their black↔gold paint direction —
## `Car._ready` re-reads the stored color, no new roll) and `pace` carry over,
## `_assign_tailgate` re-hands the cooler + bread service by class — every
## mid-run count stays stable (the 14 + 12 fleet, the class multiset, the
## roundi(target_parked × visitor_share) parked-visitor tailgate crumbs)
## without touching the populate-scoped `_begin_class_quota` machinery.
## Placement is strict-gate, NO least-bad fallback — an in-view stage for a
## REPLACEMENT is a pop: parked entries use the strict finders only
## (`_offscreen_spot` on the drawn block, else `_offscreen_band_spot`) and
## traffic entries re-check the gate after `_route_rejoin` before falling to
## the `_offscreen_route_rejoin` band scan. Place-then-free, never starve:
## only a RESOLVED placement adds the fresh node, stages it, lands the
## `_cars` swap and tears the spent car down (`release_tailgate()` first —
## the `_populate` free-loop precedent, so a parked visitor's crumb never
## orphans — then `queue_free()`; its stop-ledger state releases in its own
## `_exit_tree`). With no gate-passing placement this scan the staged node
## (if any) frees, the spent car stays (the fleet count never dipped), and
## the next 0.5 s scan retries. True when the swap landed.
func _replace_car(spent: Car) -> bool:
	var blocks := _blocks_in_band(_anchor_flat())
	if blocks.is_empty():
		return false
	var fresh: Car = car_scene.instantiate()
	fresh.citizen_class = spent.citizen_class
	fresh.body_color = spent.body_color
	fresh.pace = spent.pace
	_assign_tailgate(fresh)
	fresh.traffic = traffic_ctrl ## (T-134) Null when the protocol hatch is off.
	var block: Vector3 = _pick_recycle_block(blocks)
	var placed := false
	if spent.mode == Car.Mode.PARKED:
		var spot: Dictionary = _offscreen_spot(city.parking_spots(block))
		if spot.is_empty():
			var band := _offscreen_band_spot(blocks)
			if not band.is_empty():
				block = band["block"]
				spot = band["spot"]
		if not spot.is_empty():
			add_child(fresh) ## Before park_at — the crumb drop needs the tree.
			fresh.park_at(city.to_global(spot.pos), spot.yaw, city.to_global(block))
			placed = true
	else:
		var placement := _route_rejoin(block, fresh, true)
		if not _sightline_ok(placement.pos):
			var scan := _offscreen_route_rejoin(blocks, fresh)
			if not scan.is_empty():
				block = scan.block
				placement = scan.placement
			else:
				placement = {} ## No gate-passing rejoin anywhere — keep the spent car.
		if not placement.is_empty():
			add_child(fresh)
			fresh.start_route(placement.pos, placement.points, placement.entries,
					city.to_global(block), _block_centers_cache, placement.end)
			placed = true
	if not placed:
		fresh.free()
		return false
	## The fresh node stands — wire the relays and land the swap.
	fresh.route_exhausted.connect(_on_route_exhausted)
	fresh.splatted.connect(_on_car_splatted)
	_cars.erase(spent)
	_cars.append(fresh)
	spent.release_tailgate()
	spent.queue_free()
	return true


## `_pick_block`'s fallback pool for a far-from-every-block anchor: the whole
## fleet's worth of nearest centers, band ignored (tourists seed 6 groups'
## worth; the fleet needs the larger draw).
func _fallback_blocks(anchor: Vector2) -> Array[Vector3]:
	return _nearest_blocks(anchor, maxi(target_moving, target_parked))


func _spawn_traffic(block_local: Vector3, index: int) -> void:
	var car: Car = car_scene.instantiate()
	_assign_class(car)
	if car.citizen_class == CitizenClass.Kind.CIVILIAN:
		car.body_color = Car.BODY_PALETTE[index % Car.BODY_PALETTE.size()]
	_assign_tailgate(car) ## (T-114) The cooler rides traffic AND parked visitors.
	car.pace = _rng.randf_range(0.9, 1.15)
	car.traffic = traffic_ctrl ## (T-134) Null when the protocol hatch is off — bare pathing.
	add_child(car)
	# A deterministic seeded route off the block's corner node, staged at a
	# deterministic spread point on its first leg: two cars sharing one leg
	# never start overlapped. Since T-128 the point passes the sightline gate
	# first — a gated spread fraction walks the leg's probe fractions (the
	# least-bad fallback below keeps the spread fraction when none pass).
	var nodes := _deal_nodes(car, _node_beside_block(block_local), -1)
	## The placement walk honours the follow-gap clearance against the block's
	## live cars too — two cars dealt onto the same corner node must never
	## land on the same probe fraction. When a whole dealt route stays inside
	## the sightline window (a short route hugging the player's cone), up to
	## three fresh deals get the same walk before the least-bad fallback
	## stands — the fleet COUNT contract never starves.
	var placement := _route_placement(nodes, city.to_global(block_local), car,
			sightline_gate_enabled, fmod(index * 0.37, 1.0))
	var deals := 1
	while deals < 4 and sightline_gate_enabled \
			and not _sightline_ok(placement.pos):
		nodes = _deal_nodes(car, _node_beside_block(block_local), -1)
		placement = _route_placement(nodes, city.to_global(block_local), car,
				true, fmod(index * 0.37, 1.0))
		deals += 1
	var built := _build_route(placement.nodes)
	car.start_route(placement.pos, built.points, built.entries,
			city.to_global(block_local), _block_centers_cache, built.end)
	car.route_exhausted.connect(_on_route_exhausted)
	car.splatted.connect(_on_car_splatted)
	_cars.append(car)


func _spawn_parked(block_local: Vector3, pos: Vector3, yaw: float, index: int) -> void:
	var car: Car = car_scene.instantiate()
	_assign_class(car)
	if car.citizen_class == CitizenClass.Kind.CIVILIAN:
		car.body_color = Car.BODY_PALETTE[index % Car.BODY_PALETTE.size()]
	_assign_tailgate(car) ## (T-114) Cooler + bread service; park_at anchors the crumb.
	add_child(car)
	car.park_at(pos, yaw, city.to_global(block_local))
	car.splatted.connect(_on_car_splatted)
	_cars.append(car)


## (T-114) Hands a freshly built car its tailgate state before _ready: visitor
## cars haul the cooler (parked AND traffic) and — when a bread service is
## wired — anchor their stealable crumb while parked. Civilians and superfans
## haul nothing.
func _assign_tailgate(car: Car) -> void:
	car.has_cooler = car.citizen_class == CitizenClass.Kind.VISITOR
	car.bread_spawner = bread_spawner


## (T-114) The deferred tailgate dressing pass: re-anchors every parked
## visitor car whose crumb died since its park_at (the BreadSpawner populate
## wiping-and-reseeding in the same `regenerated` emission is the one case).
## Cars whose crumb is still valid are skipped, so this pass and `park_at`
## can never double-drop.
func _dress_tailgates() -> void:
	for car in _cars:
		if is_instance_valid(car) and car.mode == Car.Mode.PARKED \
				and car.citizen_class == CitizenClass.Kind.VISITOR \
				and not car.tailgate_crumb_alive():
			car._redress_crumb()


## The seeded citizen-class draw (T-113): the class counts are the share
## knobs' exact integer rounding (opened by `_begin_class_quota`), and one
## roll off the spawner's own `_rng` stream per spawn picks WHICH car wears
## which uniform — a sequential draw without replacement, so the tallies land
## exactly on the quotas while the assignment stays seeded (same seed, same
## multiset). A second roll picks the visitor's paint direction (gold body →
## black banner, black body → gold banner, drawn in `Car._ready`). Civilians
## keep the palette round-robin draw. Class is fixed at populate and never
## re-rolled on recycle: the same car keeps its paint when teleported.
func _assign_class(car: Car) -> void:
	var roll: float = _rng.randf() * float(_class_slots_left)
	if roll < float(_superfans_left):
		car.citizen_class = CitizenClass.Kind.SUPERFAN
		car.body_color = CitizenClass.SUPERFAN_CARDINAL
		_superfans_left -= 1
	elif roll < float(_superfans_left + _visitors_left):
		car.citizen_class = CitizenClass.Kind.VISITOR
		car.body_color = CitizenClass.VISITOR_BLACK \
				if _rng.randf() < 0.5 else CitizenClass.TEAM_GOLD
		_visitors_left -= 1
	else:
		car.citizen_class = CitizenClass.Kind.CIVILIAN
	_class_slots_left -= 1


## Opens one populate loop's class quotas (T-113): `slots` draws will land
## exactly roundi(slots · share) superfans and visitors, civilians the
## remainder.
func _begin_class_quota(slots: int) -> void:
	_class_slots_left = slots
	_superfans_left = roundi(float(slots) * superfan_share)
	_visitors_left = clampi(roundi(float(slots) * visitor_share), 0,
			slots - _superfans_left)


func _on_car_splatted(car: Car) -> void:
	honk_count += 1
	car_splatted.emit(car)


## --- placement helpers -----------------------------------------------------


## Flat (XZ) distance between two world positions.
func _flat_dist_pos(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## --- route dealing (T-134) -------------------------------------------------


## The grid node at a block's minimum corner — a dealt route's start. Blocks
## sit between nodes: block index (i, j) has corner node (i, j) on the grid.
func _node_beside_block(block_local: Vector3) -> Vector2i:
	var half := float(city.blocks_per_side - 1) * 0.5
	return Vector2i(roundi(block_local.x / city.block_pitch + half),
			roundi(block_local.z / city.block_pitch + half))


## One seeded route draw off this spawner's own `_rng` stream: the leg count
## from the car's Routes exports, the turn weights from the same group, the
## initial heading random (`initial_dir` < 0) or pinned (extensions — the car's
## live heading, so a dealt route never U-turns). Two-ish draws per deal.
func _deal_nodes(car: Car, start: Vector2i, initial_dir: int) -> Array[Vector2i]:
	var legs := _rng.randi_range(car.route_legs_min, car.route_legs_max)
	var weights := {
		"straight": car.straight_weight,
		"right": car.right_weight,
		"left": car.left_weight,
	}
	return city.route_from(start, legs, _rng, weights, initial_dir)


## The grid-direction index of a node step.
func _dir_index(step: Vector2i) -> int:
	for d in 4:
		if City.ROUTE_DIRS[d] == step:
			return d
	return 0


## One stop entry for the car's `stops` walk — the node, its approach axis,
## the turn made there, the stop-line center (where the NOSE halts), the car
## center point that puts the nose on the line, the turn waypoint, and the
## node's padded crosswalk bands — all in GLOBAL coords (the car never sees
## the City). `exit_dir` is the leg leaving the node (its own `dir` when the
## route ends here).
func _stop_entry(node: Vector2i, dir: int, turn: int, exit_dir: int) -> Dictionary:
	var a := City.ROUTE_DIR_VECS[dir]
	var line_local := city.route_lane_point(node, dir, City.STOP_LINE_OUTSET)
	var corner_local := city.route_corner(node, dir, exit_dir) if turn != 0 \
			else city.road_node_pos(node)
	var bands: Array[Rect2] = []
	for rect in city.crosswalk_band_rects(node):
		var origin := city.to_global(Vector3(rect.position.x, 0.0, rect.position.y))
		bands.append(Rect2(Vector2(origin.x, origin.z), rect.size))
	return {
		"node": node,
		"pos": city.to_global(city.road_node_pos(node)),
		"dir": dir,
		"turn": turn,
		"line": city.to_global(line_local),
		"corner": city.to_global(corner_local),
		"bands": bands,
		"registered": false,
		"committed": false,
		"center": city.to_global(line_local) - a * Car.HALF_LENGTH,
	}


## Builds a dealt route's driving data from its node list: the open waypoint
## path (`points` — turn corners plus the final leg's exit point, a mid-leg
## lead point when the route never turns), the same list WITHOUT the lead for
## extensions (`tail`), the stop `entries` (provisionally straight at the end
## node — the extension deals the real turn), the leg `dirs` and the `end`
## node. The spawner owns the City reference; the car receives globals.
func _build_route(nodes: Array[Vector2i]) -> Dictionary:
	var dirs: Array[int] = []
	for i in range(1, nodes.size()):
		dirs.append(_dir_index(nodes[i] - nodes[i - 1]))
	var entries: Array[Dictionary] = []
	for i in range(1, nodes.size()):
		var turn := 0
		var exit_dir := dirs[i - 1] ## The route ends here: the exit is straight on.
		if i < dirs.size():
			turn = city.route_relative_turn(dirs[i - 1], dirs[i])
			exit_dir = dirs[i]
		entries.append(_stop_entry(nodes[i], dirs[i - 1], turn, exit_dir))
	var points := PackedVector3Array()
	var tail := PackedVector3Array()
	for i in range(1, nodes.size()):
		if entries[i - 1].turn != 0:
			points.append(entries[i - 1].corner)
			tail.append(entries[i - 1].corner)
	var exit_point := city.to_global(city.route_lane_point(nodes[nodes.size() - 1],
			dirs[dirs.size() - 1], -14.0))
	points.append(exit_point)
	tail.append(exit_point)
	if points.size() < 2:
		## An all-straight route has no corners: one mid-leg lead point keeps
		## the path steerable (>= 2 waypoints). It never rides `tail` — an
		## extension appends from the end node onward only.
		points.insert(0, city.to_global(
				city.route_lane_point(nodes[0], dirs[0], -16.0)))
	return {
		"points": points,
		"tail": tail,
		"entries": entries,
		"dirs": dirs,
		"end": nodes[nodes.size() - 1],
	}


## The direction the car's route currently ends on — the last stop entry's
## approach axis (an extension pins the next deal's initial heading to it).
func _last_leg_dir(car: Car) -> int:
	return car.stops[car.stops.size() - 1].dir


## The route-exhaustion handler: deal a fresh route FROM the car's end node
## (its live heading pinned as the initial direction — never a U-turn) and
## append it through `Car.extend_route`. Continuous driving, no teleport.
func _on_route_exhausted(car: Car) -> void:
	if city == null or not is_instance_valid(car) or car.stops.is_empty():
		return
	var last_dir := _last_leg_dir(car)
	var nodes := _deal_nodes(car, car.route_end_node, last_dir)
	var built := _build_route(nodes)
	var turn_at_end := 0
	if not built.dirs.is_empty():
		turn_at_end = city.route_relative_turn(last_dir, built.dirs[0])
	car.extend_route(built.tail, built.entries, turn_at_end, built.end)


## A point at fraction (0..1) along a segment — the route-leg analogue of the
## old loop fractions (T-089's probed rejoin shape, on legs).
func _segment_point(a: Vector3, b: Vector3, fraction: float) -> Vector3:
	return a.lerp(b, clampf(fraction, 0.0, 1.0))


## A placement point on a dealt route: walks the route's legs in order (leg 1
## first), probing `recycle_probe_count` evenly spaced fractions of each leg's
## mid-lane segment — the first fraction that passes the sightline gate (with
## `gate`) AND the follow-gap clearance (when `clear_block` is a real block
## center) wins, and the route is REBASED to that leg: the dropped lead nodes
## leave behind exactly the entries and waypoints the car starts past, so a
## car staged mid-route is clean. When every probe fails, leg 1's `spread`
## fraction stands — the documented least-bad fallback that keeps the fleet
## COUNT contract from ever starving. Deterministic, RNG-free (the spread
## fraction carries the caller's draw).
func _route_placement(nodes: Array[Vector2i], clear_block: Vector3, mover: Car,
		gate: bool, spread: float) -> Dictionary:
	var dirs: Array[int] = []
	for i in range(1, nodes.size()):
		dirs.append(_dir_index(nodes[i] - nodes[i - 1]))
	var probes := maxi(recycle_probe_count, 1)
	var anchor := _anchor_flat()
	for k in dirs.size():
		var d := dirs[k]
		var seg_a := city.to_global(city.route_lane_point(nodes[k], d, 11.0))
		var seg_b := city.to_global(city.route_lane_point(nodes[k + 1], d, 11.0))
		for p in 2 * probes: ## Denser than the recycle knob: two per probe step.
			var fraction := float(p) / float(2 * probes)
			if k == 0 and p == 0:
				fraction = spread ## The caller's deterministic spread first.
			var candidate := _segment_point(seg_a, seg_b, fraction)
			## A placement beyond the recycle radius of the player would be
			## re-recycled on the next scan — never stage one there.
			if player != null and _flat_dist(candidate, anchor) > recycle_radius:
				continue
			if (not gate or _sightline_ok(candidate)) \
					and (clear_block == Vector3.INF
							or _probe_clear(candidate, clear_block, mover)):
				var subset: Array[Vector2i] = []
				for i in range(k, nodes.size()):
					subset.append(nodes[i])
				return {"pos": candidate, "nodes": subset}
	var d0: int = dirs[0]
	var fallback := _segment_point(
			city.to_global(city.route_lane_point(nodes[0], d0, 11.0)),
			city.to_global(city.route_lane_point(nodes[1], d0, 11.0)), spread)
	return {"pos": fallback, "nodes": nodes.duplicate()}


## A fresh dealt route's rejoin for one traffic car: one seeded deal off the
## block's node plus a gate/clear placement walk over the route's legs (see
## `_route_placement`). The fallback roll (one `_rng` draw) fires only when
## every probed fraction on every leg fails — the T-089 documented least-bad
## fallback.
func _route_rejoin(block_local: Vector3, mover: Car, gate: bool) -> Dictionary:
	var start := _node_beside_block(block_local)
	var nodes := _deal_nodes(mover, start, -1)
	var placement := _route_placement(nodes, city.to_global(block_local), mover,
			gate, _rng.randf())
	var built := _build_route(placement.nodes)
	return {"pos": placement.pos, "points": built.points,
			"entries": built.entries, "end": built.end}


## A recycled traffic car's gate-passing rejoin: scans the band — light blocks
## first (T-089's preference, T-128's scan), natural order inside each group —
## for the first block whose leg walk lands an off-screen placement. Returns
## {"block": city-local center, "placement": rejoin} — empty when no band
## block offers one (the caller keeps the drawn placement — the documented
## least-bad fallback).
func _offscreen_route_rejoin(blocks: Array[Vector3], mover: Car) -> Dictionary:
	for block in _band_blocks_light_first(blocks):
		var placement := _route_rejoin(block, mover, true)
		if _sightline_ok(placement.pos):
			return {"block": block, "placement": placement}
	return {}


## The block a recycled car draws onto (T-089): rings already holding
## `ring_traffic_soft_cap` traffic cars are skipped while any band ring is
## lighter — uniform draws kept stuffing the same full rings until the whole
## band read as one parked wall. Still one `_rng` draw per recycled car from
## the spawner's own stream; when every band ring is at cap, the draw spans
## all band blocks exactly as before.
func _pick_recycle_block(blocks: Array[Vector3]) -> Vector3:
	var pool := blocks
	var light := _light_ring_blocks(blocks)
	if not light.is_empty():
		pool = light
	return pool[_rng.randi_range(0, pool.size() - 1)]


## The band blocks whose rings hold fewer than `ring_traffic_soft_cap` traffic
## cars (T-089) — `_pick_recycle_block`'s preferred pool and the T-128 gate
## scan's preferred order, extracted so the two can never drift apart.
func _light_ring_blocks(blocks: Array[Vector3]) -> Array[Vector3]:
	var traffic_per_ring := {}
	for car in _cars:
		if is_instance_valid(car) and car.mode == Car.Mode.TRAFFIC:
			traffic_per_ring[car.block_center] = int(traffic_per_ring.get(car.block_center, 0)) + 1
	var light: Array[Vector3] = []
	for block in blocks:
		if int(traffic_per_ring.get(city.to_global(block), 0)) < ring_traffic_soft_cap:
			light.append(block)
	return light


## Band blocks ordered light-rings-first (T-089's preference, T-128's scan):
## the light pool in natural order, then the rest. When every ring is at cap
## (or none is), the natural order stands — the scan's deterministic, RNG-free
## walk order.
func _band_blocks_light_first(blocks: Array[Vector3]) -> Array[Vector3]:
	var light := _light_ring_blocks(blocks)
	if light.is_empty() or light.size() == blocks.size():
		return blocks
	var order: Array[Vector3] = []
	order.append_array(light)
	for block in blocks:
		if not light.has(block):
			order.append(block)
	return order


## True when `probe` sits at least `mover.follow_gap` away (flat, center to
## center) from every traffic car assigned to the `block_global` block — the
## car being placed excepted: its old body teleports away with the rejoin.
func _probe_clear(probe: Vector3, block_global: Vector3, mover: Car) -> bool:
	for car in _cars:
		if not is_instance_valid(car) or car == mover:
			continue
		if car.mode != Car.Mode.TRAFFIC or car.block_center != block_global:
			continue
		if _flat_dist_pos(probe, car.global_position) < mover.follow_gap:
			return false
	return true


## True when a living parked car already sits within a car length of `pos` —
## two cars never share one curb space.
func _spot_taken(pos: Vector3) -> bool:
	for car in _cars:
		if is_instance_valid(car) and car.mode == Car.Mode.PARKED \
				and car.global_position.distance_to(pos) < 4.5:
			return true
	return false


## --- the sightline gate (T-128) --------------------------------------------


## The gate's flat view direction: the chase camera's LIVE basis (the damped
## rig yaw) projected on the XZ plane — pitch and roll never bend a horizontal
## cone. The player's own facing stands in when no camera rides the rig.
func _view_dir_flat() -> Vector2:
	if _camera_rig == null and player != null:
		for child in player.get_children():
			if child is ChaseCamera:
				_camera_rig = child
				break
	var fwd := Vector3.ZERO
	if _camera_rig != null:
		fwd = -_camera_rig.global_transform.basis.z
	elif player != null:
		fwd = -player.global_transform.basis.z
	var flat := Vector2(fwd.x, fwd.z)
	if flat.length() > 0.1:
		return flat.normalized()
	return Vector2(0.0, -1.0) ## The spawn corridor's facing — a finite last resort.


## The ONE sightline acceptance both placement paths call: true when `pos` may
## take a car — the gate is off (the `sightline_gate_enabled` escape hatch),
## the point sits at/beyond `spawn_sightline_max` of the player, or it lies
## outside the chase camera's horizontal cone (`spawn_avoid_cone_deg`
## half-angle). Cheap flat dot products, no raycasts.
func _sightline_ok(pos: Vector3) -> bool:
	if not sightline_gate_enabled or player == null:
		return true
	var offset := Vector2(pos.x - player.global_position.x,
			pos.z - player.global_position.z)
	if offset.length() >= spawn_sightline_max:
		return true
	if offset.length() < 0.001:
		return false ## At the player's feet is the worst pop there is.
	return offset.normalized().dot(_view_dir_flat()) <= cos(deg_to_rad(spawn_avoid_cone_deg))


## One parked-placement attempt of the populate loop: the seeded two-draw
## (band block, curb spot), with the drawn spot's taken-skip exactly as
## pre-T-128 and — gate ON — a gated drawn spot walking its own block's spots
## for a free, gate-passing one. False when nothing placeable came out of the
## draw (the caller's attempt is spent; the loop retries). `gate` false stages
## the old way — the escape hatch, and the least-bad fill's mode.
func _try_place_parked(anchor: Vector2, index: int, gate: bool) -> bool:
	var block := _pick_block(anchor)
	var spots := city.parking_spots(block)
	var spot: Dictionary = spots[_rng.randi_range(0, spots.size() - 1)]
	var global_spot: Vector3 = city.to_global(spot.pos)
	if _spot_taken(global_spot):
		return false
	if gate and not _sightline_ok(global_spot):
		var offscreen := _offscreen_spot(spots)
		if offscreen.is_empty():
			return false
		spot = offscreen
		global_spot = city.to_global(spot.pos)
	_spawn_parked(block, global_spot, spot.yaw, index)
	return true


## A recycled parked car's re-park: the seeded block draw + spot draw (one
## `_rng` pair, T-054/T-089 shape) when the drawn spot is free and passes the
## gate; a gated drawn spot walks its own block first, then the band scan.
## False only when the drawn spot was taken and nothing gate-passing exists
## anywhere in the band — the caller's `continue` retries next scan, the
## taken-spot precedent.
func _recycle_parked_to(car: Car, block: Vector3, blocks: Array[Vector3]) -> bool:
	var spots := city.parking_spots(block)
	var spot: Dictionary = spots[_rng.randi_range(0, spots.size() - 1)]
	var global_spot: Vector3 = city.to_global(spot.pos)
	if _spot_taken(global_spot):
		return false
	if not _sightline_ok(global_spot):
		var walked := _offscreen_spot(spots)
		if not walked.is_empty():
			spot = walked
		else:
			var band := _offscreen_band_spot(blocks)
			if not band.is_empty():
				block = band["block"]
				spot = band["spot"]
		## else: least-bad — the free drawn spot stands (in view, documented).
		global_spot = city.to_global(spot.pos)
	car.park_at(global_spot, spot.yaw, city.to_global(block))
	return true


## The first curb spot on one block that is free AND passes the sightline
## gate — the walk a gated drawn spot falls back to. Empty when every spot on
## the block is taken or still inside the window. Deterministic, RNG-free.
func _offscreen_spot(spots: Array[Dictionary]) -> Dictionary:
	for spot in spots:
		var global_spot: Vector3 = city.to_global(spot.pos)
		if not _spot_taken(global_spot) and _sightline_ok(global_spot):
			return spot
	return {}


## The band-wide parked fallback: the first free, gate-passing curb spot
## across the whole band, blocks in `_band_blocks_light_first` order, spots in
## spot order. Returns {"block": city-local center, "spot": spot} — empty when
## no band block offers one. Deterministic, RNG-free.
func _offscreen_band_spot(blocks: Array[Vector3]) -> Dictionary:
	for block in _band_blocks_light_first(blocks):
		var found := _offscreen_spot(city.parking_spots(block))
		if not found.is_empty():
			return {"block": block, "spot": found}
	return {}


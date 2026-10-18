class_name CarSpawner
extends BandSpawner
## The car service (T-008): keeps `target_moving` traffic cars looping the
## city's ring roads (`City.traffic_loop` over `City.block_centers`) and
## `target_parked` cars sitting in the curb spaces (`City.parking_spots`)
## around the player. The band/recycle machinery — the shared recycle exports,
## the recycle-scan timer and the band helpers — lives in the BandSpawner base
## (T-054); this script keeps only the car specifics. Since T-089 recycled
## traffic prefers rings holding fewer than `ring_traffic_soft_cap` cars and
## rejoins at a probed follow-gap-clear point, so a standing player stops
## watching the band clot into one parked wall. Since T-128 BOTH placement
## paths (the populate loop and the recycle rejoin) pass the sightline gate:
## a candidate point within `spawn_sightline_max` of the player AND inside the
## chase camera's horizontal cone is rejected, so cars only ever enter view by
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
@export var target_moving: int = 14 ## Traffic cars kept looping block rings (T-128: 20 → 14 — fewer visible spawn events).
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

@export_group("Recycle")
@export var recycle_probe_count: int = 5 ## Evenly spaced loop fractions probed for a follow-gap-clear traffic rejoin point before the random draw (T-089).
@export var ring_traffic_soft_cap: int = 3 ## Recycled traffic skips rings already holding this many traffic cars while any band ring is lighter (T-089).

@export_group("Wiring")
@export var bread_spawner_path: NodePath ## (T-114) The bread service tailgate crumbs drop through — Main wires the path.

## Car honks this run — the autoplay DONE line reports it.
var honk_count: int = 0

## (T-114) The bread service the tailgate crumbs drop through — resolved from
## `bread_spawner_path` in _ready; the sim harness assigns directly. Null
## (bare rigs) means the fleet grows coolers but no crumbs.
var bread_spawner: BreadSpawner

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


func _ready() -> void:
	# (T-114) Resolve the tailgate bread service BEFORE super()'s populate —
	# the parked-visitor cars it seeds anchor their crumbs during _populate.
	if bread_spawner == null and not bread_spawner_path.is_empty():
		bread_spawner = get_node(bread_spawner_path) as BreadSpawner
	super()


func _init() -> void:
	# Beyond this flat distance (m) a car recycles to the player's area. Must
	# clear the WORST legitimate loop distance — a car seeded at spawn_max_dist
	# rounds ring corners ~20 m past its block center — or traffic gets yanked
	# mid-lap and dropped on top of other cars. (A GDScript subclass cannot
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


## Puts a car that drifted beyond the recycle radius back into the spawn band
## — the same node teleports onto a fresh block ring (the recycle acceptance
## contract, as for tourists T-007). Since T-089 the block draw prefers light
## rings and traffic rejoins at a probed clear point, so recycled cars stop
## stuffing full rings into braking queues. Since T-128 every rejoin point
## also passes the sightline gate (a gated draw walks its own ring, then the
## band — light rings first; the free drawn point stands as the documented
## least-bad fallback), so recycled cars drive into view instead of popping.
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
	for car in far:
		var block: Vector3 = _pick_recycle_block(blocks)
		if car.mode == Car.Mode.PARKED:
			if not _recycle_parked_to(car, block, blocks):
				continue
		else:
			var loop := _loop_for(block)
			var block_global := city.to_global(block)
			var rejoin := _clear_rejoin_point(loop, block_global, car)
			if not _sightline_ok(rejoin):
				var scan := _offscreen_rejoin(blocks, car)
				if scan.size() == 2:
					block = scan[0] ## City-local center of the scanned block.
					loop = _loop_for(block)
					block_global = city.to_global(block)
					rejoin = scan[1]
			car.recycle_to(rejoin, loop, block_global)


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
	var loop := _loop_for(block_local)
	add_child(car)
	# A deterministic spread point per car: two cars sharing one block ring
	# never start overlapped. Since T-128 the point passes the sightline gate
	# first — a gated spread fraction walks the ring's probe fractions (the
	# least-bad fallback below keeps the spread fraction when none pass).
	car.recycle_to(_offscreen_point_on_loop(loop, fmod(index * 0.37, 1.0)), loop,
			city.to_global(block_local))
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


## The block's ring-road loop in global coords.
func _loop_for(block_local: Vector3) -> PackedVector3Array:
	var loop := PackedVector3Array()
	for point in city.traffic_loop(block_local):
		loop.append(city.to_global(point))
	return loop


## A random point along the loop — the T-089 fallback when every probed
## rejoin point is blocked; the worst case stays exactly the old behavior.
func _point_on_loop(loop: PackedVector3Array) -> Vector3:
	return _point_at_fraction(loop, _rng.randf())


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


## A rejoin point on `loop` with follow-gap clearance (T-089): walks
## `recycle_probe_count` evenly spaced loop fractions and returns the first
## whose flat distance to every traffic car already looping this ring is at
## least the mover's `follow_gap` — an insertion inside the gap would turn
## both cars into a braking queue. When every probe is blocked, falls back to
## the random `_point_on_loop` draw.
func _clear_rejoin_point(loop: PackedVector3Array, block_global: Vector3, mover: Car) -> Vector3:
	var probes := maxi(recycle_probe_count, 1)
	for i in probes:
		var probe := _point_at_fraction(loop, float(i) / float(probes))
		if _probe_clear(probe, block_global, mover):
			return probe
	return _point_on_loop(loop)


## True when `probe` sits at least `mover.follow_gap` away (flat, center to
## center) from every traffic car looping the `block_global` ring — the car
## being placed excepted: its old body teleports away with the rejoin.
func _probe_clear(probe: Vector3, block_global: Vector3, mover: Car) -> bool:
	for car in _cars:
		if not is_instance_valid(car) or car == mover:
			continue
		if car.mode != Car.Mode.TRAFFIC or car.block_center != block_global:
			continue
		if _flat_dist_pos(probe, car.global_position) < mover.follow_gap:
			return false
	return true


## The point a fraction (0..1) of the loop perimeter along — deterministic
## spread positions for seeded traffic.
func _point_at_fraction(loop: PackedVector3Array, fraction: float) -> Vector3:
	if loop.size() < 2:
		return loop[0] if loop.size() == 1 else Vector3.ZERO
	var segs: Array[float] = []
	var total := 0.0
	for i in loop.size():
		var seg := loop[i].distance_to(loop[(i + 1) % loop.size()])
		segs.append(seg)
		total += seg
	var want := clampf(fraction, 0.0, 1.0) * total
	for i in loop.size():
		if want <= segs[i]:
			return loop[i].lerp(loop[(i + 1) % loop.size()], want / maxf(segs[i], 0.001))
		want -= segs[i]
	return loop[0]


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


## A seeded traffic car's loop point: the deterministic spread fraction when it
## passes the gate — byte-identical to the pre-T-128 placement whenever nothing
## is gated — else the nearest of the ring's evenly spaced probe fractions that
## passes, else the spread fraction unchanged (the documented least-bad
## fallback that keeps the fleet COUNT contract from ever starving).
func _offscreen_point_on_loop(loop: PackedVector3Array, fraction: float) -> Vector3:
	var spread := _point_at_fraction(loop, fraction)
	if _sightline_ok(spread):
		return spread
	var probes := maxi(recycle_probe_count, 1)
	for i in probes:
		var candidate := _point_at_fraction(loop,
				fmod(fraction + float(i + 1) / float(probes), 1.0))
		if _sightline_ok(candidate):
			return candidate
	return spread


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


## A recycled traffic car's gate-passing rejoin: scans the band — light rings
## first (T-089's preference), natural order inside each group — for the first
## probe point that is BOTH follow-gap-clear and outside the sightline window.
## Returns [city-local block center, global rejoin point]; empty when no band
## block offers one (the caller keeps the drawn placement — the documented
## least-bad fallback). Deterministic, RNG-free.
func _offscreen_rejoin(blocks: Array[Vector3], mover: Car) -> PackedVector3Array:
	for block in _band_blocks_light_first(blocks):
		var block_global := city.to_global(block)
		var loop := _loop_for(block)
		var probes := maxi(recycle_probe_count, 1)
		for i in probes:
			var probe := _point_at_fraction(loop, float(i) / float(probes))
			if _sightline_ok(probe) and _probe_clear(probe, block_global, mover):
				return PackedVector3Array([block, probe])
	return PackedVector3Array()

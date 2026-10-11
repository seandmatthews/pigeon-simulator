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
## watching the band clot into one parked wall. Seeded from the city's seed
## and re-seeded on city regeneration, like the tourist (T-007) and bread
## (T-005) services. Every car splat relays as `car_splatted` — Main wires it
## into the Game autoload's score table (T-009).

## Relayed from each car's `splatted` — Main wires it into the Game autoload's
## score table (T-009).
signal car_splatted(car: Car)

@export_group("Population")
@export var car_scene: PackedScene = preload("res://scenes/car.tscn")
@export var target_moving: int = 20 ## Traffic cars kept looping block rings.
@export var target_parked: int = 16 ## Cars kept parked at curbs.

@export_group("Classes")
@export var visitor_share: float = 0.40 ## Share of cars seeded in full visitor team paint with the flag up (T-113); civilians take the remainder.
@export var superfan_share: float = 0.05 ## Share of cars seeded as cardinal SUPERFAN vehicles (T-113).

@export_group("Recycle")
@export var recycle_probe_count: int = 5 ## Evenly spaced loop fractions probed for a follow-gap-clear traffic rejoin point before the random draw (T-089).
@export var ring_traffic_soft_cap: int = 3 ## Recycled traffic skips rings already holding this many traffic cars while any band ring is lighter (T-089).

## Car honks this run — the autoplay DONE line reports it.
var honk_count: int = 0

var _cars: Array[Car] = []

## The class quotas of the populate loop in flight (T-113): the class COUNTS
## are the share knobs' exact integer rounding at every seed, and the seeded
## draws in `_assign_class` pick WHICH car wears which uniform — same seed,
## same multiset. Opened per loop (traffic, parked) by `_begin_class_quota`.
var _class_slots_left: int = 0
var _visitors_left: int = 0
var _superfans_left: int = 0


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
		var block := _pick_block(anchor)
		var spots := city.parking_spots(block)
		var spot: Dictionary = spots[_rng.randi_range(0, spots.size() - 1)]
		var global_spot: Vector3 = city.to_global(spot.pos)
		if _spot_taken(global_spot):
			continue
		_spawn_parked(block, global_spot, spot.yaw, made_parked)
		made_parked += 1


## Puts a car that drifted beyond the recycle radius back into the spawn band
## — the same node teleports onto a fresh block ring (the recycle acceptance
## contract, as for tourists T-007). Since T-089 the block draw prefers light
## rings and traffic rejoins at a probed clear point, so recycled cars stop
## stuffing full rings into braking queues.
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
			var spots := city.parking_spots(block)
			var spot: Dictionary = spots[_rng.randi_range(0, spots.size() - 1)]
			var global_spot: Vector3 = city.to_global(spot.pos)
			if _spot_taken(global_spot):
				continue
			car.park_at(global_spot, spot.yaw, city.to_global(block))
		else:
			var loop := _loop_for(block)
			var block_global := city.to_global(block)
			car.recycle_to(_clear_rejoin_point(loop, block_global, car), loop, block_global)


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
	car.pace = _rng.randf_range(0.9, 1.15)
	var loop := _loop_for(block_local)
	add_child(car)
	# A deterministic spread point per car: two cars sharing one block ring
	# never start overlapped.
	car.recycle_to(_point_at_fraction(loop, fmod(index * 0.37, 1.0)), loop,
			city.to_global(block_local))
	car.splatted.connect(_on_car_splatted)
	_cars.append(car)


func _spawn_parked(block_local: Vector3, pos: Vector3, yaw: float, index: int) -> void:
	var car: Car = car_scene.instantiate()
	_assign_class(car)
	if car.citizen_class == CitizenClass.Kind.CIVILIAN:
		car.body_color = Car.BODY_PALETTE[index % Car.BODY_PALETTE.size()]
	add_child(car)
	car.park_at(pos, yaw, city.to_global(block_local))
	car.splatted.connect(_on_car_splatted)
	_cars.append(car)


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
	var traffic_per_ring := {}
	for car in _cars:
		if is_instance_valid(car) and car.mode == Car.Mode.TRAFFIC:
			traffic_per_ring[car.block_center] = int(traffic_per_ring.get(car.block_center, 0)) + 1
	var light: Array[Vector3] = []
	for block in blocks:
		if int(traffic_per_ring.get(city.to_global(block), 0)) < ring_traffic_soft_cap:
			light.append(block)
	var pool := blocks
	if not light.is_empty():
		pool = light
	return pool[_rng.randi_range(0, pool.size() - 1)]


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

class_name TouristSpawner
extends BandSpawner
## The tourist service (T-007): keeps `target_count` tourists (ticket band
## 15–20) alive around the player, seeded in loose groups onto the city's
## sidewalk loops (`City.sidewalk_loop` over `City.block_centers`). The
## band/recycle machinery — the spawn-band exports, the recycle-scan timer and
## the band helpers — lives in the BandSpawner base (T-054); this script keeps
## only the tourist specifics. The scan teleports tourists that drifted beyond
## `recycle_radius` onto fresh loops in the spawn band around the player —
## the same nodes, no allocation. The initial spread is seeded from the city's
## seed and re-seeds on city regeneration, like the bread service (T-005).

## Relayed from each tourist's `splatted` — Main wires it into the Game
## autoload's score table (T-009).
signal tourist_splatted(tourist: Tourist)

@export_group("Population")
@export var tourist_scene: PackedScene = preload("res://scenes/tourist.tscn")
@export var target_count: int = 18 ## Tourists kept alive (ticket band: 15–20).
@export var group_size_max: int = 3 ## Loose groups: 2..group_size_max tourists share one block loop.

@export_group("Classes")
@export var visitor_share: float = 0.35 ## Share of tourists seeded as black-and-gold VISITORS (T-113); civilians take the remainder.
@export var superfan_share: float = 0.06 ## Share of tourists seeded as cardinal-and-gold HOMETOWN SUPERFANS (T-113).
@export var finger_share: float = 0.5 ## Share of VISITORS carrying the foam finger; superfans always carry it (T-113).

## Tourist splats this run — the autoplay DONE line reports it.
var splat_count: int = 0

var _tourists: Array[Tourist] = []

## The class quotas of the populate in flight (T-113): the class COUNTS are
## the share knobs' exact integer rounding at every seed, and the seeded draws
## in `_assign_class` pick WHO wears which uniform — same seed, same multiset.
var _class_slots_left: int = 0
var _visitors_left: int = 0
var _superfans_left: int = 0


## Living tourists — tests and the autoplay pilot read these.
func living_tourists() -> Array[Tourist]:
	_tourists = _tourists.filter(func(tourist: Tourist) -> bool: return is_instance_valid(tourist))
	return _tourists.duplicate()


## Wipes and re-seeds the whole population (first boot, city regeneration).
## (T-181) On the Ames world (`city.ped_zones` set by the build) the
## population IS the zone crowd: the visitor zones' caps (the Welch strip the
## densest) seeded along their sidewalk polylines in loose seeded groups —
## the class quota law unchanged, the share draws rolling the same seeded
## stream. The block-loop seeding below is the retired Windrow seam.
func _populate() -> void:
	for tourist in _tourists:
		if is_instance_valid(tourist):
			tourist.queue_free()
	_tourists.clear()
	if city == null or player == null:
		return
	_rng.seed = city.seed_value
	if city.ped_zones != null:
		_populate_zones()
		return
	_begin_class_quota(target_count)
	var anchor := _anchor_flat()
	if city.block_centers.is_empty():
		return
	var index := 0
	while _tourists.size() < target_count:
		var block := _pick_block(anchor)
		var group := mini(target_count - _tourists.size(), _rng.randi_range(2, group_size_max))
		for _g in group:
			_spawn_on_block(block, index)
			index += 1


## The zone seeding (T-181): every visitor zone's cap exactly, walkers
## spread along the zone's sidewalk polylines (round-robin across the paths,
## seeded stagger), open paths bounce. The class quotas open over the zone
## total so the T-113 share law lands exactly at the zone crowd's size.
func _populate_zones() -> void:
	var total := 0
	for zone: AmesPedZones.Zone in city.ped_zones.zones:
		if zone.klass == "tourist":
			total += zone.cap
	if total <= 0:
		return
	_begin_class_quota(total)
	var index := 0
	for zone: AmesPedZones.Zone in city.ped_zones.zones:
		if zone.klass != "tourist":
			continue
		for i in zone.cap:
			_spawn_zone_tourist(zone, i, index)
			index += 1


## One zone tourist (T-181): path = the zone's sidewalk polyline (global,
## densified waypoints), bounce on open paths, crossing flags carried, start
## fraction staggered on the seeded stream, class drawn off the same stream.
func _spawn_zone_tourist(zone: AmesPedZones.Zone, i: int, index: int) -> void:
	var path_i := i % zone.paths.size()
	var pts := zone.paths[path_i]
	var path := PackedVector3Array()
	for p: Vector2 in pts:
		path.append(city.to_global(Vector3(p.x, 0.0, p.y)))
	var closed := zone.closed[path_i] if path_i < zone.closed.size() else false
	var cross_flags: Array[bool] = []
	var crosses: Array = zone.crosses[path_i] if path_i < zone.crosses.size() else []
	for flag: Variant in crosses:
		cross_flags.append(bool(flag))
	var tourist: Tourist = tourist_scene.instantiate()
	_assign_class(tourist)
	if tourist.citizen_class == CitizenClass.Kind.CIVILIAN:
		tourist.shirt_color = Tourist.SHIRT_PALETTE[index % Tourist.SHIRT_PALETTE.size()]
	tourist.pace = _rng.randf_range(0.85, 1.2)
	tourist.path = path
	tourist.path_cross = cross_flags
	tourist.path_bounce = not closed
	tourist.zone_id = zone.id
	var mid := _zone_mid(zone)
	tourist.block_center = city.to_global(Vector3(mid.x, 0.0, mid.y))
	add_child(tourist)
	## Seeded stagger: walker i of the zone's cap spreads around the path.
	var frac := fposmod(float(i) / float(maxi(zone.cap, 1)) + _rng.randf() * 0.5
			/ float(maxi(zone.cap, 1)), 1.0)
	tourist.global_position = _point_on_path(path, frac)
	tourist._retarget_nearest_waypoint()
	tourist.splatted.connect(_on_tourist_splatted)
	_tourists.append(tourist)


## A point at arc fraction `frac` of a global polyline.
func _point_on_path(path: PackedVector3Array, frac: float) -> Vector3:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var want := clampf(frac, 0.0, 1.0) * total
	var walked := 0.0
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if walked + seg >= want and seg > 0.0001:
			return path[i].lerp(path[i + 1], (want - walked) / seg)
		walked += seg
	return path[path.size() - 1]


## The zone's centroid (global) — the `block_center` grouping key stand-in.
func _zone_mid(zone: AmesPedZones.Zone) -> Vector2:
	var acc := Vector2.ZERO
	var n := 0
	for path: PackedVector2Array in zone.paths:
		for p: Vector2 in path:
			acc += p
			n += 1
	return acc / maxf(float(n), 1.0)


## Puts a tourist that drifted beyond the recycle radius back into the spawn
## band around the player — the same node teleports (the recycle acceptance
## criterion: reuse, no respawn churn). Outside the city there is nowhere
## sensible to put anyone: tourists hold position until the player returns.
func _recycle_far() -> void:
	var anchor := _anchor_flat()
	var far: Array[Tourist] = []
	for tourist in _tourists:
		if is_instance_valid(tourist) and _flat_dist(tourist.global_position, anchor) > recycle_radius:
			far.append(tourist)
	if far.is_empty():
		return
	if _blocks_in_band(anchor).is_empty():
		return
	for tourist in far:
		var block := _pick_block(anchor)
		var loop := _loop_for(block)
		tourist.recycle_to(_point_on_loop(loop), loop, city.to_global(block))


func _spawn_on_block(block_local: Vector3, index: int) -> void:
	var tourist: Tourist = tourist_scene.instantiate()
	_assign_class(tourist)
	if tourist.citizen_class == CitizenClass.Kind.CIVILIAN:
		tourist.shirt_color = Tourist.SHIRT_PALETTE[index % Tourist.SHIRT_PALETTE.size()]
	tourist.pace = _rng.randf_range(0.85, 1.2)
	var loop := _loop_for(block_local)
	if _rng.randf() < 0.35:
		loop.reverse() ## Some walkers take the loop the other way — loose groups.
	tourist.path = loop
	tourist.block_center = city.to_global(block_local)
	add_child(tourist)
	tourist.global_position = _point_on_loop(loop)
	tourist._retarget_nearest_waypoint()
	tourist.splatted.connect(_on_tourist_splatted)
	_tourists.append(tourist)


## The seeded citizen-class draw (T-113): the class counts are the share
## knobs' exact integer rounding (opened by `_begin_class_quota`), and one roll
## off the spawner's own `_rng` stream per spawn picks WHO wears which uniform
## — a sequential draw without replacement, so the tallies land exactly on the
## quotas while the assignment stays seeded (same seed, same multiset). A
## second roll picks the visitor's pairing direction (black torso + gold arms
## or the inverse), a third the foam finger. Civilians keep the palette
## round-robin draw. Class is fixed at populate and never re-rolled on
## recycle: the same person keeps their uniform when teleported.
func _assign_class(tourist: Tourist) -> void:
	var roll: float = _rng.randf() * float(_class_slots_left)
	if roll < float(_superfans_left):
		tourist.citizen_class = CitizenClass.Kind.SUPERFAN
		tourist.shirt_color = CitizenClass.SUPERFAN_CARDINAL
		tourist.carries_finger = true
		_superfans_left -= 1
	elif roll < float(_superfans_left + _visitors_left):
		tourist.citizen_class = CitizenClass.Kind.VISITOR
		tourist.shirt_color = CitizenClass.VISITOR_BLACK \
				if _rng.randf() < 0.5 else CitizenClass.TEAM_GOLD
		tourist.carries_finger = _rng.randf() < finger_share
		_visitors_left -= 1
	else:
		tourist.citizen_class = CitizenClass.Kind.CIVILIAN
	_class_slots_left -= 1


## Opens one populate's class quotas (T-113): `slots` draws will land exactly
## roundi(slots · share) superfans and visitors, civilians the remainder.
func _begin_class_quota(slots: int) -> void:
	_class_slots_left = slots
	_superfans_left = roundi(float(slots) * superfan_share)
	_visitors_left = clampi(roundi(float(slots) * visitor_share), 0,
			slots - _superfans_left)


func _on_tourist_splatted(tourist: Tourist) -> void:
	splat_count += 1
	tourist_splatted.emit(tourist)


## --- placement helpers -----------------------------------------------------


## The block's sidewalk loop in global coords.
func _loop_for(block_local: Vector3) -> PackedVector3Array:
	var loop := PackedVector3Array()
	for point in city.sidewalk_loop(block_local):
		loop.append(city.to_global(point))
	return loop


## A random point along the loop — groups spawn staggered, not stacked.
func _point_on_loop(loop: PackedVector3Array) -> Vector3:
	var seg := _rng.randi_range(0, loop.size() - 1)
	return loop[seg].lerp(loop[(seg + 1) % loop.size()], _rng.randf())

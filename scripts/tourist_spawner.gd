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
func _populate() -> void:
	for tourist in _tourists:
		if is_instance_valid(tourist):
			tourist.queue_free()
	_tourists.clear()
	if city == null or player == null:
		return
	_rng.seed = city.seed_value
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

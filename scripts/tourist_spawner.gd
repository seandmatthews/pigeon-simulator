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

## Tourist splats this run — the autoplay DONE line reports it.
var splat_count: int = 0

var _tourists: Array[Tourist] = []


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

class_name TouristSpawner
extends Node3D
## The tourist service (T-007): keeps `target_count` tourists (ticket band
## 15–20) alive around the player, seeded in loose groups onto the city's
## sidewalk loops (`City.sidewalk_loop` over `City.block_centers`). A recycle
## scan every `recycle_interval` teleports tourists that drifted beyond
## `recycle_radius` onto fresh loops in the spawn band around the player —
## the same nodes, no allocation, and never inside `spawn_min_dist`, so
## nothing pops into view. The initial spread is seeded from the city's seed
## and re-seeds on city regeneration, like the bread service (T-005).

## Relayed from each tourist's `splatted` — Main wires it to the score stub
## (T-009 brings the real table and combos).
signal tourist_splatted(tourist: Tourist)

@export_group("Population")
@export var tourist_scene: PackedScene = preload("res://scenes/tourist.tscn")
@export var target_count: int = 18 ## Tourists kept alive (ticket band: 15–20).
@export var group_size_max: int = 3 ## Loose groups: 2..group_size_max tourists share one block loop.

@export_group("Recycle")
@export var recycle_radius: float = 80.0 ## Flat distance (m) beyond which a tourist recycles to the player's area.
@export var recycle_interval: float = 0.5 ## Seconds between recycle scans.
@export var spawn_min_dist: float = 30.0 ## Recycled loops stay at least this far away (flat, m) — pop-in guard.
@export var spawn_max_dist: float = 70.0 ## ...and at most this far, so density stays where the player is.

@export var city_path: NodePath
@export var player_path: NodePath

## The city to walk and the pigeon to orbit — Main wires the paths; the sim
## harness assigns both directly.
var city: City
var player: Player

## Tourist splats this run — the autoplay DONE line reports it.
var splat_count: int = 0

var _tourists: Array[Tourist] = []
var _rng := RandomNumberGenerator.new()
var _scan_timer: float = 0.0


func _ready() -> void:
	if city == null and not city_path.is_empty():
		city = get_node(city_path) as City
	if player == null and not player_path.is_empty():
		player = get_node(player_path) as Player
	if city == null or player == null:
		push_warning("TouristSpawner needs a City and a Player — no tourists will spawn.")
		return
	city.regenerated.connect(_populate)
	_populate()


func _physics_process(delta: float) -> void:
	if city == null or player == null:
		return
	_scan_timer += delta
	if _scan_timer >= recycle_interval:
		_scan_timer = 0.0
		_recycle_far()


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
	var blocks := _blocks_in_band(anchor)
	if blocks.is_empty():
		blocks = _nearest_blocks(anchor, 6)
	var index := 0
	while _tourists.size() < target_count and not blocks.is_empty():
		var block: Vector3 = blocks[_rng.randi_range(0, blocks.size() - 1)]
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
	var blocks := _blocks_in_band(anchor)
	if blocks.is_empty():
		return
	for tourist in far:
		var block: Vector3 = blocks[_rng.randi_range(0, blocks.size() - 1)]
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


func _anchor_flat() -> Vector2:
	return Vector2(player.global_position.x, player.global_position.z)


func _flat_dist(pos: Vector3, anchor: Vector2) -> float:
	return Vector2(pos.x - anchor.x, pos.z - anchor.y).length()


## City-local block centers whose global position lies inside the spawn band
## (flat, m) around the anchor.
func _blocks_in_band(anchor: Vector2) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for center in city.block_centers:
		var d := _center_dist(center, anchor)
		if d >= spawn_min_dist and d <= spawn_max_dist:
			found.append(center)
	return found


## Fallback for anchors far from every block: the `count` nearest block
## centers, band ignored.
func _nearest_blocks(anchor: Vector2, count: int) -> Array[Vector3]:
	var sorted_centers := city.block_centers.duplicate()
	sorted_centers.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return _center_dist(a, anchor) < _center_dist(b, anchor))
	sorted_centers.resize(mini(count, sorted_centers.size()))
	return sorted_centers


func _center_dist(center: Vector3, anchor: Vector2) -> float:
	var g := city.to_global(center)
	return Vector2(g.x - anchor.x, g.z - anchor.y).length()


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

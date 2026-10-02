class_name BandSpawner
extends Node3D
## The shared band/recycle machinery behind the city's population services
## (T-054, extracting the byte-identical copies TouristSpawner and CarSpawner
## each carried since T-007/T-008). A band spawner orbits a population around
## the player: seeds spread over the city-local block centers whose global
## position lies inside the spawn band (`spawn_min_dist`..`spawn_max_dist`,
## flat, m — never inside `spawn_min_dist`, so nothing pops into view), and a
## scan every `recycle_interval` teleports whatever drifted beyond
## `recycle_radius` back into the band around the player — the same nodes, no
## allocation. Seeding re-runs on city regeneration. Subclasses own what
## genuinely differs: the population itself, `_populate`, `_recycle_far`, the
## loop flavor (`sidewalk_loop` vs `traffic_loop`) and the typed living
## filters (GDScript has no generics, so the `Array[Tourist]`/`Array[Car]`
## filters cannot lift to the base).

@export_group("Recycle")
@export var recycle_radius: float = 80.0 ## Flat distance (m) beyond which a body recycles to the player's area.
@export var recycle_interval: float = 0.5 ## Seconds between recycle scans.
@export var spawn_min_dist: float = 30.0 ## Recycled bodies stay at least this far away (flat, m) — pop-in guard.
@export var spawn_max_dist: float = 70.0 ## ...and at most this far, so density stays where the player is.

@export var city_path: NodePath
@export var player_path: NodePath

## The city to walk and the pigeon to orbit — Main wires the paths; the sim
## harness assigns both directly.
var city: City
var player: Player

var _rng := RandomNumberGenerator.new()
var _scan_timer: float = 0.0


func _ready() -> void:
	if city == null and not city_path.is_empty():
		city = get_node(city_path) as City
	if player == null and not player_path.is_empty():
		player = get_node(player_path) as Player
	if city == null or player == null:
		push_warning("BandSpawner needs a City and a Player — nothing will spawn.")
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


## The scan's action — subclasses override: teleport the population that
## drifted beyond `recycle_radius` back into the spawn band. The base stub is
## a no-op (a band spawner without a population has nothing to recycle).
func _recycle_far() -> void:
	pass


## Wipes and re-seeds the whole population (first boot, city regeneration) —
## subclasses override. The base stub is a no-op.
func _populate() -> void:
	pass


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


## One plain spawn-band draw (T-054): a uniformly random city-local block
## center from the band around `anchor` — the draw both populate paths and the
## tourist recycle make (the car recycle's `_pick_recycle_block` stays
## CarSpawner-specific: its T-089 light-ring filter is not this plain draw).
## When the band is empty the draw falls back over `_fallback_blocks`, so a
## far-from-every-block anchor still seeds density.
func _pick_block(anchor: Vector2) -> Vector3:
	var blocks := _blocks_in_band(anchor)
	if blocks.is_empty():
		blocks = _fallback_blocks(anchor)
	return blocks[_rng.randi_range(0, blocks.size() - 1)]


## `_pick_block`'s fallback pool when the spawn band is empty — the nearest
## centers, band ignored. Subclasses tune the count to their fleet shape.
func _fallback_blocks(anchor: Vector2) -> Array[Vector3]:
	return _nearest_blocks(anchor, 6)

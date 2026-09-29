class_name CarSpawner
extends Node3D
## The car service (T-008): keeps `target_moving` traffic cars looping the
## city's ring roads (`City.traffic_loop` over `City.block_centers`) and
## `target_parked` cars sitting in the curb spaces (`City.parking_spots`)
## around the player. A recycle scan every `recycle_interval` teleports cars
## that drifted beyond `recycle_radius` onto fresh blocks/spots in the spawn
## band — the same nodes, no allocation, and never inside `spawn_min_dist`,
## so nothing pops into view. Seeded from the city's seed and re-seeded on
## city regeneration, like the tourist (T-007) and bread (T-005) services.
## Every car splat relays as `car_splatted` — Main wires it into the Game
## autoload's score table (T-009).

## Relayed from each car's `splatted` — Main wires it into the Game autoload's
## score table (T-009).
signal car_splatted(car: Car)

@export_group("Population")
@export var car_scene: PackedScene = preload("res://scenes/car.tscn")
@export var target_moving: int = 20 ## Traffic cars kept looping block rings.
@export var target_parked: int = 16 ## Cars kept parked at curbs.

@export_group("Recycle")
## Beyond this flat distance (m) a car recycles to the player's area. Must
## clear the WORST legitimate loop distance — a car seeded at spawn_max_dist
## rounds ring corners ~20 m past its block center — or traffic gets yanked
## mid-lap and dropped on top of other cars.
@export var recycle_radius: float = 100.0
@export var recycle_interval: float = 0.5 ## Seconds between recycle scans.
@export var spawn_min_dist: float = 30.0 ## Recycled cars stay at least this far away (flat, m) — pop-in guard.
@export var spawn_max_dist: float = 70.0 ## ...and at most this far, so density stays where the player is.

@export var city_path: NodePath
@export var player_path: NodePath

## The city to dress and the pigeon to orbit — Main wires the paths; the sim
## harness assigns both directly.
var city: City
var player: Player

## Car honks this run — the autoplay DONE line reports it.
var honk_count: int = 0

var _cars: Array[Car] = []
var _rng := RandomNumberGenerator.new()
var _scan_timer: float = 0.0


func _ready() -> void:
	if city == null and not city_path.is_empty():
		city = get_node(city_path) as City
	if player == null and not player_path.is_empty():
		player = get_node(player_path) as Player
	if city == null or player == null:
		push_warning("CarSpawner needs a City and a Player — no cars will spawn.")
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
	var blocks := _blocks_in_band(_anchor_flat())
	if blocks.is_empty():
		blocks = _nearest_blocks(_anchor_flat(), maxi(target_moving, target_parked))
	if blocks.is_empty():
		return
	var made_moving := 0
	while made_moving < target_moving:
		var block: Vector3 = blocks[_rng.randi_range(0, blocks.size() - 1)]
		_spawn_traffic(block, made_moving)
		made_moving += 1
	var made_parked := 0
	var attempts := 0
	while made_parked < target_parked and attempts < target_parked * 8:
		attempts += 1
		var block: Vector3 = blocks[_rng.randi_range(0, blocks.size() - 1)]
		var spots := city.parking_spots(block)
		var spot: Dictionary = spots[_rng.randi_range(0, spots.size() - 1)]
		var global_spot: Vector3 = city.to_global(spot.pos)
		if _spot_taken(global_spot):
			continue
		_spawn_parked(block, global_spot, spot.yaw, made_parked)
		made_parked += 1


## Puts a traffic car that drifted beyond the recycle radius back into the
## spawn band — the same node teleports onto a fresh block ring (the recycle
## acceptance contract, as for tourists T-007).
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
		var block: Vector3 = blocks[_rng.randi_range(0, blocks.size() - 1)]
		if car.mode == Car.Mode.PARKED:
			var spots := city.parking_spots(block)
			var spot: Dictionary = spots[_rng.randi_range(0, spots.size() - 1)]
			var global_spot: Vector3 = city.to_global(spot.pos)
			if _spot_taken(global_spot):
				continue
			car.park_at(global_spot, spot.yaw, city.to_global(block))
		else:
			var loop := _loop_for(block)
			car.recycle_to(_point_on_loop(loop), loop, city.to_global(block))


func _spawn_traffic(block_local: Vector3, index: int) -> void:
	var car: Car = car_scene.instantiate()
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
	car.body_color = Car.BODY_PALETTE[index % Car.BODY_PALETTE.size()]
	add_child(car)
	car.park_at(pos, yaw, city.to_global(block_local))
	car.splatted.connect(_on_car_splatted)
	_cars.append(car)


func _on_car_splatted(car: Car) -> void:
	honk_count += 1
	car_splatted.emit(car)


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


## The block's ring-road loop in global coords.
func _loop_for(block_local: Vector3) -> PackedVector3Array:
	var loop := PackedVector3Array()
	for point in city.traffic_loop(block_local):
		loop.append(city.to_global(point))
	return loop


## A random point along the loop — recycled cars rejoin anywhere.
func _point_on_loop(loop: PackedVector3Array) -> Vector3:
	return _point_at_fraction(loop, _rng.randf())


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

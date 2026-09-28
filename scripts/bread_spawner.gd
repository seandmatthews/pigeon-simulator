class_name BreadSpawner
extends Node3D
## The bread service (T-005): keeps `target_count` crumbs alive on the city's
## bread-capable surfaces (`City.bread_spots`) and tops up every
## `respawn_interval` seconds, so eaten crumbs come back somewhere else and the
## city never starves you unfairly. The initial spread is seeded from the
## city's seed — the same city always opens with the same crumbs — and every
## city regeneration (restart flow, sim harness) re-seeds the spread.

## Relayed from each crumb's eaten signal — Main wires this into Hunger.eat.
signal crumb_eaten(amount: float)

@export var city_path: NodePath
@export var crumb_scene: PackedScene = preload("res://scenes/bread_crumb.tscn")
@export var target_count: int = 40 ## Crumbs kept alive across the whole city.
@export var respawn_interval: float = 5.0 ## Seconds between top-up ticks that replace eaten crumbs.

## The city to seed crumbs onto — Main wires `city_path`; tests assign directly.
var city: City

## How many crumbs have been eaten on this run — the autoplay pilot reports it.
var eaten_count: int = 0

var _crumbs: Array[BreadCrumb] = []
var _occupied: Dictionary = {} ## City.bread_spots index -> the crumb sitting on it.
var _rng := RandomNumberGenerator.new()
var _respawn_timer: float = 0.0


func _ready() -> void:
	if city == null and not city_path.is_empty():
		city = get_node(city_path) as City
	if city == null:
		push_warning("BreadSpawner has no City — no crumbs will spawn.")
		return
	city.regenerated.connect(_populate)
	_populate()


func _physics_process(delta: float) -> void:
	if city == null:
		return
	_respawn_timer += delta
	if _respawn_timer >= respawn_interval:
		_respawn_timer = 0.0
		_top_up()


## Living crumbs — the autoplay pilot homes in on the nearest of these.
func living_crumbs() -> Array[BreadCrumb]:
	_crumbs = _crumbs.filter(func(crumb: BreadCrumb) -> bool: return is_instance_valid(crumb))
	return _crumbs.duplicate()


## Wipes and re-seeds the whole spread (first boot, city regeneration).
func _populate() -> void:
	for crumb in _crumbs:
		if is_instance_valid(crumb):
			crumb.queue_free()
	_crumbs.clear()
	_occupied.clear()
	if city == null:
		return
	_rng.seed = city.seed_value
	var indices: Array[int] = []
	for i in city.bread_spots.size():
		indices.append(i)
	_shuffle(indices)
	for i in mini(target_count, indices.size()):
		_spawn_at(indices[i])


## Replaces eaten crumbs — every `respawn_interval`, back up to target_count.
func _top_up() -> void:
	if city == null:
		return
	var free: Array[int] = []
	for i in city.bread_spots.size():
		if not _occupied.has(i):
			free.append(i)
	while _crumbs.size() < target_count and not free.is_empty():
		var pick := _rng.randi_range(0, free.size() - 1)
		_spawn_at(free[pick])
		free.remove_at(pick)


func _spawn_at(spot_index: int) -> void:
	var crumb: BreadCrumb = crumb_scene.instantiate()
	crumb.spot_index = spot_index
	crumb.position = city.to_global(city.bread_spots[spot_index])
	crumb.eaten.connect(_on_crumb_eaten.bind(crumb))
	add_child(crumb)
	_crumbs.append(crumb)
	_occupied[spot_index] = crumb


func _on_crumb_eaten(amount: float, crumb: BreadCrumb) -> void:
	_crumbs.erase(crumb)
	_occupied.erase(crumb.spot_index)
	eaten_count += 1
	crumb_eaten.emit(amount)


## Fisher–Yates, seeded — deterministic initial spread per city seed.
func _shuffle(values: Array[int]) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := values[i]
		values[i] = values[j]
		values[j] = swap

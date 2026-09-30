class_name CafeSpawner
extends Node3D
## The sidewalk-cafe service (T-031): seats one cafe table — with its 1-2
## static sitters — on every `City.cafe_spots` entry (one spot per awninged
## building, a pure-layout array), so placement draws zero city RNG and the
## layout fingerprints never move. Re-populates on `City.regenerated` like
## every other service; deterministic per seed, no RNG of its own — the spot
## list is the spot list at every seed.

@export_group("Population")
@export var table_scene: PackedScene = preload("res://scenes/cafe_table.tscn")

@export_group("Wiring")
@export var city_path: NodePath

## The city to seat — Main wires the path; the sim harness assigns directly.
var city: City

var _tables: Array[CafeTable] = []


func _ready() -> void:
	if city == null and not city_path.is_empty():
		city = get_node(city_path) as City
	if city == null:
		push_warning("CafeSpawner needs a City — no cafe tables will spawn.")
		return
	city.regenerated.connect(_populate)
	_populate()


## Seated tables — tests and the autoplay pilot read these.
func living_tables() -> Array[CafeTable]:
	_tables = _tables.filter(func(table: CafeTable) -> bool: return is_instance_valid(table))
	return _tables.duplicate()


## Wipes and re-seats the whole population (first boot, city regeneration):
## one table per spot, in spot order, so the spot index drives the pure
## sitter-count and shirt rules inside the table scene.
func _populate() -> void:
	for table in _tables:
		if is_instance_valid(table):
			table.queue_free()
	_tables.clear()
	if city == null:
		return
	for spot_i in city.cafe_spots.size():
		var table: CafeTable = table_scene.instantiate()
		table.spot_index = spot_i
		add_child(table)
		table.global_transform = city.global_transform * city.cafe_spots[spot_i]
		_tables.append(table)

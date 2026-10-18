class_name ElderSpawner
extends Node3D
## The park-elder service (T-020): keeps `elder_count` static elders seated on
## the spawn plaza's benches — spots 0, 2, 4, 6 of the 8-bench ring, taken
## straight from `City.elder_spots` (a pure-layout array, so placement draws
## zero city RNG and the layout fingerprints never move). Re-populates on
## `City.regenerated` like every other service; deterministic per seed, no RNG
## of its own — the ring is the ring at every seed.

## Relayed from each elder's `shared` — the CaptureRecorder logs the
## `elder_bread_shared` event from here.
signal bread_shared(elder: Elder, crumbs: int)

@export_group("Population")
@export var elder_scene: PackedScene = preload("res://scenes/elder.tscn")
@export var elder_count: int = 4 ## Elders seated per run (every 2nd bench of the 8-bench ring).

@export_group("Wiring")
@export var city_path: NodePath
@export var player_path: NodePath
@export var bread_spawner_path: NodePath
## (T-129) Staged boot — see BandSpawner.staged_boot: main.tscn's boot calls
## `populate()` explicitly; bare rigs keep the default false and self-populate.
@export var staged_boot: bool = false

## The city to sit in, the pigeon to host and the bread service to toss with —
## Main wires the paths; the sim harness assigns directly.
var city: City
var player: Player
var bread_spawner: BreadSpawner

## Shares this run — the autoplay DONE line reports it.
var share_count: int = 0

var _elders: Array[Elder] = []


func _ready() -> void:
	if city == null and not city_path.is_empty():
		city = get_node(city_path) as City
	if player == null and not player_path.is_empty():
		player = get_node(player_path) as Player
	if bread_spawner == null and not bread_spawner_path.is_empty():
		bread_spawner = get_node(bread_spawner_path) as BreadSpawner
	if city == null:
		push_warning("ElderSpawner needs a City — no elders will spawn.")
		return
	if staged_boot: ## (T-129) main.gd's boot stages the first populate itself.
		return
	city.regenerated.connect(_populate)
	_populate()


## (T-129) The boot's explicit staging entry — the BandSpawner.populate() twin:
## idempotent `regenerated` wiring plus the re-seat, safe to call any time.
func populate() -> void:
	if not city.regenerated.is_connected(_populate):
		city.regenerated.connect(_populate)
	_populate()


## Seated elders — tests and the autoplay pilot read these.
func living_elders() -> Array[Elder]:
	_elders = _elders.filter(func(elder: Elder) -> bool: return is_instance_valid(elder))
	return _elders.duplicate()


## Wipes and re-seats the whole population (first boot, city regeneration).
## Seats one elder on every SECOND bench of the plaza ring (spots 0, 2, 4, …),
## so the four elders spread around the circle deterministically at every seed.
func _populate() -> void:
	for elder in _elders:
		if is_instance_valid(elder):
			elder.queue_free()
	_elders.clear()
	if city == null:
		return
	var seated := 0
	for spot_i in city.elder_spots.size():
		if seated >= elder_count:
			break
		if spot_i % 2 != 0:
			continue ## Every second bench of the 8-bench ring.
		var elder: Elder = elder_scene.instantiate()
		elder.cardigan_color = Elder.CARDIGAN_PALETTE[seated % Elder.CARDIGAN_PALETTE.size()]
		elder.bread_spawner = bread_spawner
		add_child(elder)
		elder.global_transform = city.global_transform * city.elder_spots[spot_i]
		elder.shared.connect(_on_elder_shared)
		_elders.append(elder)
		seated += 1


func _on_elder_shared(elder: Elder, crumbs: int) -> void:
	share_count += 1
	bread_shared.emit(elder, crumbs)

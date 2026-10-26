class_name ElderSpawner
extends Node3D
## The park-elder service (T-020): keeps `elder_count` static elders seated on
## the spawn plaza's benches — spots 0, 2, 4, 6 of the 8-bench ring, taken
## straight from `City.elder_spots` (a pure-layout array, so placement draws
## zero city RNG and the layout fingerprints never move). Re-populates on
## `City.regenerated` like every other service; deterministic per seed, no RNG
## of its own — the ring is the ring at every seed.
##
## Since T-137 (the grandpa shuffle) the spawner also runs the migration: on
## each `bread_shared` it reserves the sharing elder's next bench BEFORE the
## elder stands — the pool is every seat minus its own minus occupied minus
## reserved, restricted to seats whose district differs from the elder's
## current one (plaza seats carry the sentinel district −1, so every park
## differs from the plaza; `City.elder_seat_districts` is pure layout). The
## pick is a deterministic hash of (run seed, the elder's cumulative share
## count) over the pool — no RNG stream, replayable — and a completed
## migration relays `elder_relocated(elder, from_seat, to_seat)` (the T-095
## pilot-event precedent; the CaptureRecorder logs it).

## Relayed from each elder's `shared` — the CaptureRecorder logs the
## `elder_bread_shared` event from here.
signal bread_shared(elder: Elder, crumbs: int)

## (T-137) Relayed when a migration completes — the elder is SEATED on its
## new bench. The CaptureRecorder logs the `elder_relocated` event from here.
signal elder_relocated(elder: Elder, from_seat: int, to_seat: int)

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

## (T-137) Completed migrations this run — the autoplay DONE line reports it.
var relocation_count: int = 0

var _elders: Array[Elder] = []
## (T-137) Seat indices (into `City.elder_spots`) currently reserved for a
## walking elder's arrival — never occupied mid-walk, never re-picked.
var _reserved: Array[int] = []


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


## Wipes and re-seats the whole population (first boot, city regeneration,
## restart). Seats one elder on every SECOND bench of the plaza ring
## (spots 0, 2, 4, …), so the four elders spread around the circle
## deterministically at every seed — the boot path T-137 leaves UNCHANGED
## (the four park seats at spots 8-11 are migration destinations only).
func _populate() -> void:
	for elder in _elders:
		if is_instance_valid(elder):
			elder.queue_free()
	_elders.clear()
	_reserved.clear()
	relocation_count = 0
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
		elder.city = city
		add_child(elder)
		elder.global_transform = city.global_transform * city.elder_spots[spot_i]
		elder.current_seat = spot_i
		elder.departed_seat = spot_i
		elder.shared.connect(_on_elder_shared)
		elder.arrived.connect(_on_elder_arrived)
		_elders.append(elder)
		seated += 1


func _on_elder_shared(elder: Elder, crumbs: int) -> void:
	share_count += 1
	_reserve_destination(elder)
	bread_shared.emit(elder, crumbs)


func _on_elder_arrived(elder: Elder) -> void:
	_reserved.erase(elder.current_seat)
	relocation_count += 1
	elder_relocated.emit(elder, elder.departed_seat, elder.current_seat)


## (T-137, owner fork 4) The deterministic pick: pool = all seats minus the
## elder's own minus occupied (any LIVING elder's `current_seat`, which after
## `begin_migration` is the reserved destination itself) minus the other
## reserved seats, restricted to seats whose district differs from the
## elder's current one (plaza = sentinel −1, so every park differs). The
## pick hashes (run seed, the elder's cumulative share count) — no RNG
## stream anywhere, replayable from the seed alone. The pool is never empty
## (the four parks cover all four districts), but the guard keeps a
## seat-less rig elder (current_seat −1) from ever walking.
func _reserve_destination(elder: Elder) -> void:
	if city == null or elder.current_seat < 0:
		return
	var occupied := {}
	for other in living_elders():
		if other != elder:
			occupied[other.current_seat] = true
	for seat in _reserved:
		occupied[seat] = true
	var own_district: int = city.elder_seat_districts[elder.current_seat]
	var pool: Array[int] = []
	for i in city.elder_spots.size():
		if i == elder.current_seat or occupied.has(i):
			continue
		if city.elder_seat_districts[i] == own_district:
			continue
		pool.append(i)
	if pool.is_empty():
		return ## Unreachable with the shipped city (guard, not a rule).
	var roll := _migration_roll(city.seed_value, elder.share_count)
	_reserved.append(pool[roll % pool.size()])
	elder.begin_migration(_reserved[_reserved.size() - 1])


## The migration hash (T-137): a pure function of (run seed, share count) —
## the same shape the city's `_skyline_roll` uses for its own no-stream
## rolls. Tests recompute it (the scenario owns this exact fold).
func _migration_roll(seed_value: int, share_number: int) -> int:
	var h := hash(Vector2i(seed_value, share_number))
	h = hash(h ^ seed_value)
	return h & 0x7fffffff

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

## (T-183) The zones whose benches joined the favor economy — the elder
## benches at their pinned geography (the ticket's AC 1): the Central Campus
## lawn, downtown Main Street and the Lake LaVerne shore. Every bench of
## these zones seats a favor elder (the T-114 trust/share loop live — spend
## targets where the elders sit); the other zones' benches stay furniture and
## the zone walkers stay favor-dark. On the elder-klass zones the cap law
## seats benches-first exactly as T-181 shipped it; on a tourist-klass favor
## zone (downtown — the visitors' second cluster keeps its full cap) the
## bench elders are ADDITIVE population beside the crowd.
const FAVOR_ZONE_IDS: Array[String] = ["central_campus", "downtown_main", "laverne_shore"]

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
## restart). (T-181) On the Ames world (`city.ped_zones` set, no seat ring)
## the locals populate the zones; (T-183) the benches of `FAVOR_ZONE_IDS`
## carry the favor economy — each seats one favor elder (the T-141 sit
## composite via `Elder.zone_seat`, `zone_bench` set, the `shared` relay
## wired so the T-114 loop books and the `bread_spawner` assigned so the
## share tosses), the elder-klass zones fill the rest of their cap walking
## the zone's closed paths at deterministic start fractions, and a
## tourist-klass favor zone (downtown) gains its bench elders ADDITIVELY
## beside its full T-181 visitor cap. No RNG of any stream — the zone law is
## a pure function. On a seat ring (the retired Windrow seam) the plaza law
## below stands unchanged.
func _populate() -> void:
	for elder in _elders:
		if is_instance_valid(elder):
			elder.queue_free()
	_elders.clear()
	_reserved.clear()
	relocation_count = 0
	if city == null:
		return
	if city.ped_zones != null and city.elder_spots.is_empty():
		_populate_zones()
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


## The zone locals (T-181, re-homed T-183): per zone, the FAVOR benches
## first — one favor elder per bench of every `FAVOR_ZONE_IDS` zone (the
## T-114 loop live: `zone_bench` set, the `shared` relay wired, the
## `bread_spawner` assigned; a tourist-klass favor zone's bench elders ride
## ADDITIVELY beside its full visitor cap) — then the elder-klass zones fill
## the remainder of their cap walking the closed path with even start
## fractions. Zero RNG — deterministic per build.
func _populate_zones() -> void:
	var index := 0
	for zone: AmesPedZones.Zone in city.ped_zones.zones:
		var favor: bool = zone.id in FAVOR_ZONE_IDS
		var sitters := 0
		if favor:
			sitters = zone.benches.size()
		elif zone.klass == "elder":
			sitters = mini(zone.benches.size(), zone.cap)
		for bench_i in sitters:
			var elder: Elder = elder_scene.instantiate()
			elder.cardigan_color = Elder.CARDIGAN_PALETTE[index % Elder.CARDIGAN_PALETTE.size()]
			elder.city = city
			elder.zone_id = zone.id
			add_child(elder)
			_elders.append(elder)
			if favor:
				## (T-183) The favor bench: the T-114 loop runs on this seat —
				## trust/share live, the share's toss wired, the relay feeding
				## the spawner's bookkeeping (the migration pool refuses a
				## ring-seatless elder, so `shared` never moves a zone elder).
				elder.zone_bench = bench_i
				elder.bread_spawner = bread_spawner
				elder.shared.connect(_on_elder_shared)
			## Seat at the zone's sit target: the T-141 composite via the
			## seat-line transform (the retired plaza ring's exact law).
			elder.zone_seat(city.global_transform * zone.benches[bench_i])
			index += 1
		## (T-183) Walkers are the ELDER zones' cap remainder — a tourist-klass
		## favor zone's cap belongs to its visitor crowd, so its bench elders
		## stand alone (no walkers drawn off the tourist cap).
		var walkers := (zone.cap - sitters) if zone.klass == "elder" else 0
		if walkers <= 0 or zone.paths.is_empty():
			continue
		var path := zone.paths[0]
		var route := PackedVector3Array()
		for p: Vector2 in path:
			route.append(city.to_global(Vector3(p.x, 0.0, p.y)))
		var cross_flags: Array[bool] = []
		## (T-181 round 2) The elder's `_route_cross` is WAYPOINT-indexed —
		## `_route_cross[i]` marks the leg ARRIVING at waypoint i (the
		## migration route's own convention, size == route.size()). The zone
		## data's flags are LEG-indexed (leg i joins waypoints i and i+1,
		## size route.size()−1), so leg i maps onto waypoint i+1 and waypoint
		## 0 has no arriving leg. Feeding the leg array unconverted left the
		## last waypoint's read out of bounds — the tick errored, the wrap
		## never ran and every zone walker froze at its route's end (the rv2
		## review's live evidence).
		cross_flags.append(false)
		var crosses: Array = zone.crosses[0] if zone.crosses.size() > 0 else []
		for flag: Variant in crosses:
			cross_flags.append(bool(flag))
		for w in walkers:
			var elder: Elder = elder_scene.instantiate()
			elder.cardigan_color = Elder.CARDIGAN_PALETTE[index % Elder.CARDIGAN_PALETTE.size()]
			elder.city = city
			elder.zone_id = zone.id
			add_child(elder)
			var frac := float(w) / float(walkers)
			elder.global_position = _point_on_path(route, frac)
			_elders.append(elder)
			elder.zone_walk(route, cross_flags)
			index += 1


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

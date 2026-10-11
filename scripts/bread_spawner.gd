class_name BreadSpawner
extends Node3D
## The bread service (T-005): keeps `target_count` crumbs alive on the city's
## bread-capable surfaces (`City.bread_spots`) and tops up every
## `respawn_interval` seconds, so eaten crumbs come back somewhere else and the
## city never starves you unfairly. The initial spread is seeded from the
## city's seed — the same city always opens with the same crumbs — and every
## city regeneration (restart flow, sim harness) re-seeds the spread.
##
## Since T-112 the spread is weighted per surface class (`City.bread_spot_kinds`):
## the live spread tracks the city's own logic — food under the awnings where
## the people are. `table_share` of the budget lands on cafe tabletops, the
## fixed `roof_share` keeps roofs and anchor caps "rare spice, not a common
## sight" (a ceiling, never a floor), and the ground class takes the remainder.
## Quotas fill in the fixed order TABLE, GROUND, ROOF (the same seeded RNG and
## Fisher–Yates shuffle as ever, now per class), and a class whose free spots
## run out spills its deficit to the next class down — overflow is a safety
## net, never a live path at the shipped values (the table supply is the
## awning count, ≥ 66 at every probed seed vs the 36-table quota).
## T-020's hand-placed elder loaves stay outside the class math: they occupy
## no spot, join `_crumbs` as today, and merely shrink the spawned budget they
## always shrank.

## Relayed from each crumb's eaten signal — Main wires this into Hunger.eat.
signal crumb_eaten(amount: float)

## (T-114) Relayed when an OWNED crumb is eaten — the favor its theft books.
## Fires only for non-zero `favor_delta` crumbs (café TABLE crumbs, tailgate
## crumbs); gutter and roof spice emit nothing. Main wires this into
## Game.add_favor — emit-and-listen, so bare harness rigs without Main stay
## favor-silent.
signal crumb_favor(delta: int)

## The class fill/spill order (T-112): tables first, then the ground, roofs
## last. `City.BreadKind` values — TABLE 1, GROUND 0, ROOF 2.
const FILL_ORDER: Array[int] = [City.BreadKind.TABLE, City.BreadKind.GROUND, City.BreadKind.ROOF]
## The terminal class of FILL_ORDER — the roof class absorbs no spill: "rare"
## is a ceiling, not a floor.
const TERMINAL_CLASS := City.BreadKind.ROOF

@export var city_path: NodePath
@export var crumb_scene: PackedScene = preload("res://scenes/bread_crumb.tscn")
@export var target_count: int = 40 ## Crumbs kept alive across the whole city.
@export var respawn_interval: float = 5.0 ## Seconds between top-up ticks that replace eaten crumbs.
## Share of the spawned budget that lands on cafe tabletops (T-112) — the
## owner's "like 90%": bread lives where people eat.
@export var table_share: float = 0.90
## Share of the spawned budget that lands on roofs and anchor caps (T-112) —
## the owner's "rare spice": a ceiling of ~1 crumb at the shipped target. The
## ground class takes the remainder (7.5% at the defaults).
@export var roof_share: float = 0.025

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


## The living crumb nearest `pos` by squared distance, `null` when none is
## alive — the HUD bread pointer's target (T-037), called every rendered frame
## (Main._update_bread_pointer). (T-055) Iterates `_crumbs` in place with an
## `is_instance_valid` skip instead of routing through `living_crumbs()`'s
## filter+duplicate — allocation-free, while pruning of `_crumbs` stays
## `living_crumbs()`'s job.
func nearest_crumb(pos: Vector3) -> BreadCrumb:
	var nearest: BreadCrumb = null
	var best := INF
	for crumb in _crumbs:
		if not is_instance_valid(crumb):
			continue
		var d := pos.distance_squared_to(crumb.global_position)
		if d < best:
			best = d
			nearest = crumb
	return nearest


## Wipes and re-seeds the whole spread (first boot, city regeneration): the
## seeded Fisher–Yates shuffle applied PER CLASS in the fixed TABLE, GROUND,
## ROOF order, each quota taken off its shuffled class list — a class whose
## free spots run out spills its deficit to the next class down, ROOF caps at
## its quota.
## (T-114) One carve-out: hand-placed crumbs carrying a favor delta (the
## visitor cars' tailgate crumbs) survive the wipe — they are owned by living
## parked cars, whose own populate re-anchored them earlier in the same
## `regenerated` emission (the CarSpawner is wired ahead of this spawner in
## main.tscn), so they must live on and keep holding the spawned budget at
## `target_count − hand_placed`. Unowned hand-placed bread (T-020 elder
## loaves) still dies with the run, exactly as always.
func _populate() -> void:
	var survivors: Array[BreadCrumb] = []
	for crumb in _crumbs:
		if not is_instance_valid(crumb) or crumb.is_queued_for_deletion():
			continue
		if crumb.spot_index < 0 and crumb.favor_delta != 0:
			survivors.append(crumb) ## Car-anchored steal bread — see above.
		else:
			crumb.queue_free()
	_crumbs = survivors
	_occupied.clear()
	if city == null:
		return
	_rng.seed = city.seed_value
	var quotas := _quotas()
	var spill := 0
	for order_i in FILL_ORDER.size():
		var class_i: int = FILL_ORDER[order_i]
		var picks := _class_indices(class_i)
		_shuffle(picks)
		spill = _fill_class(class_i, quotas[order_i], 0, spill, picks, false)


## Replaces eaten crumbs — every `respawn_interval`, back to the class quotas:
## per class in the fixed order, deficit = quota − live crumbs of that class,
## filled by uniform `_rng` draws among the class's FREE spots. A class whose
## free spots run out spills its deficit to the next class down; ROOF is
## terminal and caps at its quota — spill never raises roof-class live crumbs
## above it, and a deficit past ROOF is dropped.
func _top_up() -> void:
	if city == null:
		return
	var quotas := _quotas()
	var live := _live_per_class()
	var spill := 0
	for order_i in FILL_ORDER.size():
		var class_i: int = FILL_ORDER[order_i]
		var picks := _free_class_indices(class_i)
		spill = _fill_class(class_i, quotas[order_i], live[class_i], spill, picks, true)


## The per-class spawned quotas over the CURRENT budget: `target_count` minus
## the live hand-placed crumbs (T-020 elder loaves stay outside the class
## math; T-114 tailgate crumbs join them). `table_share` and `roof_share`
## round to integers; the ground class takes the exact remainder, so the
## quotas always sum to the budget. At the shipped target 40 with no elders
## and no visitor cars: 36 tables / 3 ground / 1 roof; in the real main scene
## the 6 tailgate crumbs hold the budget at 34 → 31 / 2 / 1. Crumbs already
## queued for deletion (a car released its crumb this frame) are dead for
## accounting — never counted.
func _quotas() -> Array[int]:
	var hand_placed := 0
	for crumb in _crumbs:
		if is_instance_valid(crumb) and not crumb.is_queued_for_deletion() \
				and crumb.spot_index < 0:
			hand_placed += 1
	var budget := maxi(target_count - hand_placed, 0)
	var table := roundi(table_share * budget)
	var roof := roundi(roof_share * budget)
	return [table, budget - table - roof, roof] ## FILL_ORDER: TABLE, GROUND, ROOF.


## Spawns up to `want` crumbs on the free indices in `picks` and returns the
## unfilled remainder: the spill the next class down absorbs. `draw_random`
## picks HOW a spot is taken: false pops the head of the pre-shuffled list
## (`_populate` — the shuffle already made the choice), true draws uniformly
## through `_rng` (`_top_up`). The terminal ROOF class absorbs no spill (its
## `want` is its own quota's deficit only), so anything past it is dropped.
func _fill_class(class_i: int, quota: int, live: int, spill: int, picks: Array[int],
		draw_random: bool) -> int:
	var want := maxi(quota - live, 0)
	if class_i != TERMINAL_CLASS:
		want += maxi(spill, 0)
	while want > 0 and not picks.is_empty():
		var pick := _rng.randi_range(0, picks.size() - 1) if draw_random else 0
		_spawn_at(picks[pick])
		picks.remove_at(pick)
		want -= 1
	return want


## The indices of every spot of one kind — ascending order, so the seeded
## shuffle that follows is the only randomness.
func _class_indices(kind: int) -> Array[int]:
	var picks: Array[int] = []
	for i in city.bread_spots.size():
		if city.bread_spot_kinds[i] == kind:
			picks.append(i)
	return picks


## The FREE indices of one kind — the `_top_up` draw pool.
func _free_class_indices(kind: int) -> Array[int]:
	var picks: Array[int] = []
	for i in city.bread_spots.size():
		if city.bread_spot_kinds[i] == kind and not _occupied.has(i):
			picks.append(i)
	return picks


## Live crumbs per kind — hand-placed crumbs (`spot_index` < 0), stale
## indices (a city array shrunk under live crumbs) and crumbs already queued
## for deletion (released by a car this frame) belong to no class.
func _live_per_class() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for crumb in _crumbs:
		if not is_instance_valid(crumb) or crumb.is_queued_for_deletion() \
				or crumb.spot_index < 0 \
				or crumb.spot_index >= city.bread_spot_kinds.size():
			continue
		counts[city.bread_spot_kinds[crumb.spot_index]] += 1
	return counts


## Hand-placed crumb (T-020): spawns one ordinary crumb at `global_pos` — the
## park elders toss their shared bread through this. `spot_index` stays -1
## (the hand-placed case `BreadCrumb` already supports): the crumb occupies no
## bread spot, but it joins `_crumbs` like any other, so it is
## respawn-accounted and its eaten signal flows through the same wiring.
## (T-114) Gains the optional `favor_delta` stamp and returns the crumb, so a
## hand-placer can keep its own reference: elder loaves call it bare (they are
## paid for at share time, favor_delta 0) and the visitor cars' tailgate drops
## pass `Game.favor_steal_visitor`, keeping the returned crumb to re-anchor or
## free when the car moves on.
func drop_crumb(global_pos: Vector3, favor_delta: int = 0) -> BreadCrumb:
	var crumb: BreadCrumb = crumb_scene.instantiate()
	crumb.spot_index = -1
	crumb.favor_delta = favor_delta
	crumb.eaten.connect(_on_crumb_eaten.bind(crumb))
	add_child(crumb)
	crumb.global_position = global_pos
	_crumbs.append(crumb)
	return crumb


## (T-114) Forgets a hand-placed crumb its owner is about to free (a car
## releasing its tailgate bread): erases it from `_crumbs` WITHOUT the eaten
## bookkeeping — the crumb is gone, not eaten, so `living_crumbs()` never
## walks a freed node and the hand-placed count stays honest for `_quotas`.
func forget_crumb(crumb: BreadCrumb) -> void:
	_crumbs.erase(crumb)


func _spawn_at(spot_index: int) -> void:
	var crumb: BreadCrumb = crumb_scene.instantiate()
	crumb.spot_index = spot_index
	## (T-114) The ownership stamp: café TABLE crumbs are the civilians' bread
	## — stealing one books `Game.favor_steal_table`; GROUND and ROOF crumbs
	## are gutter and roof spice, nobody's (favor_delta stays 0).
	crumb.favor_delta = Game.favor_steal_table \
			if city.bread_spot_kinds[spot_index] == City.BreadKind.TABLE else 0
	crumb.eaten.connect(_on_crumb_eaten.bind(crumb))
	add_child(crumb)
	## Global, set after parenting (the drop_crumb pattern): to_global is a
	## world value, and assigning it to the local `position` only ever worked
	## because Main sat at the origin — any offset instance (sim harness)
	## double-offset every seeded crumb.
	crumb.global_position = city.to_global(city.bread_spots[spot_index])
	_crumbs.append(crumb)
	_occupied[spot_index] = crumb


func _on_crumb_eaten(amount: float, crumb: BreadCrumb) -> void:
	_crumbs.erase(crumb)
	_occupied.erase(crumb.spot_index)
	eaten_count += 1
	crumb_eaten.emit(amount)
	if crumb.favor_delta != 0: ## (T-114) Owned bread books its theft; bare bread stays silent.
		crumb_favor.emit(crumb.favor_delta)


## Fisher–Yates, seeded — deterministic initial spread per city seed.
func _shuffle(values: Array[int]) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := values[i]
		values[i] = values[j]
		values[j] = swap

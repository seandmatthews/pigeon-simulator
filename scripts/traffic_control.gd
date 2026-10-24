class_name TrafficControl
extends RefCounted
## Per-intersection right-of-way bookkeeping for the American four-way stops
## (T-134) — a RefCounted service with no node and no autoload, injected into
## traffic cars as `Car.traffic` by the spawner (the `bread_spawner` service
## precedent). Keyed by node × approach; at most four waiting entries and a
## handful of committed movements per node, only for nodes a car is actually
## near, and touched only on arrival/commit/release events — never polled
## per-frame fleet-wide — so with 14 traffic cars over 64 nodes the live set
## stays trivially cheap.
##
## The priority ladder (the research note's all-way-stop protocol, deliberately
## "more or less" — a fair-enough judge, not a strict FIFO court):
##   1. A waiting car may go only when no committed movement at the node is
##      incompatible with its own (approach, turn) pair. Rights are compatible
##      with everything and opposing straights pass right-side to right-side.
##   2. One that stopped earlier by more than `simultaneous_window` goes first.
##   3. Inside the near-simultaneous set: yield to the right — a conflicting
##      set member sitting on my right goes first.
##   4. Still tied: straight beats left and right beats left for conflicting
##      pairs.
## The crosswalk yield (ladder rule 5) is NOT bookkept here — the car senses
## the padded band rectangles itself and simply stays at its line while they
## are occupied, so pedestrians never enter this ledger at all.
##
## Liveness: the ladder cannot cycle (right-yielding is asymmetric — if you
## are on my right I am on your left), and the one geometric cycle real all-way
## stops can produce (three mutual near-simultaneous arrivals each yielding
## right) is broken by the car-side patience clock: after `Car.patience_seconds`
## a denied car honks once and force-commits through. Nothing stays stuck.

## Near-simultaneous arrivals within this window (s) resolve by yielding to the
## right instead of arrival order.
var simultaneous_window: float = 0.75

## Bodies the crosswalk yield senses (the player plus the tourist fleet) —
## maintained by the owning spawner; the cars point-test their node's padded
## band rectangles against these positions.
var watched: Array[Node3D] = []

## Waiting arrivals per node key (Vector2i) — registered at the stop line,
## released on commit/patience-break/teardown.
var _waiting: Dictionary = {}
## Committed movements per node key — a car drives its box only after its
## movement is here, and frees the slot on exit.
var _committed: Dictionary = {}


## One registered movement at one node: who, from which approach, making which
## turn, and the (game-time) stop instant the ladder orders by. The car is held
## by instance id so a freed car can never dangle.
class Movement:
	var car_id: int
	var node: Vector2i
	var approach: int ## Travel direction index at arrival (the ROUTE_DIRS compass).
	var turn: int ## −1 left / 0 straight / +1 right — doubles as the blinker side.
	var arrival: float ## Game-time the full stop happened (Engine.get_physics_frames clock).


## Game time on the fixed physics clock — deterministic under the harness's
## `--fixed-fps 60` (wall-clock timers are not: their spacing wobbles against
## the ladder's arrival-order comparisons). Shared by every car and control.
static func now() -> float:
	return float(Engine.get_physics_frames()) / 60.0


## A car at its stop line: registers (node, approach, turn, arrival time) and
## holds until `request_go` says otherwise. Idempotent per car.
func register_arrival(car: Car, node: Vector2i, approach: int, turn: int) -> void:
	if find_waiting(car) != null:
		return
	var movement := Movement.new()
	movement.car_id = car.get_instance_id()
	movement.node = node
	movement.approach = approach
	movement.turn = turn
	movement.arrival = now()
	if not _waiting.has(node):
		_waiting[node] = []
	_waiting[node].append(movement)


## The ladder, evaluated for `car`'s waiting entry. True when the car may
## commit its movement and drive the box.
func request_go(car: Car) -> bool:
	var movement := find_waiting(car)
	if movement == null:
		return true ## Never registered — nothing to resolve, the car is free.
	## 1. No committed movement may be incompatible with ours.
	for committed: Movement in _committed.get(movement.node, []):
		if movements_conflict(movement.approach, movement.turn,
				committed.approach, committed.turn):
			return false
	## 2. A clearly earlier stopper at the node goes first — but only over
	## CONFLICTING movements (round 1 review): an earlier waiter making a
	## movement compatible with ours (an opposing straight, a same-turn
	## opposite) must never order us, or one waiter that cannot proceed
	## would seal every compatible later arrival out of the node forever.
	for other: Movement in _waiting[movement.node]:
		if other.car_id == movement.car_id:
			continue
		if movement.arrival - other.arrival <= simultaneous_window:
			continue
		if movements_conflict(movement.approach, movement.turn,
				other.approach, other.turn):
			return false
	## 3+4. Near-simultaneous set: yield to the right; still tied, straight
	## and right beat our left — for CONFLICTING pairs only.
	for other: Movement in _waiting[movement.node]:
		if other.car_id == movement.car_id:
			continue
		if absf(movement.arrival - other.arrival) > simultaneous_window:
			continue
		if not movements_conflict(movement.approach, movement.turn,
				other.approach, other.turn):
			continue
		## On my right = waiting on the branch my right turn would face:
		## their approach direction is (mine + 3) % 4.
		if other.approach == (movement.approach + 3) % 4:
			return false
		if movement.turn == City.ROUTE_TURN_LEFT:
			return false
	return true


## A granted go: the waiting entry becomes a committed movement — other cars'
## ladders now resolve against it until `release`.
func commit(car: Car) -> void:
	var movement := find_waiting(car)
	if movement == null:
		return
	_waiting[movement.node].erase(movement)
	if not _committed.has(movement.node):
		_committed[movement.node] = []
	_committed[movement.node].append(movement)


## The patience break (T-134 §3): a denied car that has waited out its patience
## clock honks once and commits THROUGH — the liveness guarantee that no
## ladder cycle (three mutual right-yields) can deadlock the city. Whatever it
## displaced re-resolves against the new committed movement like any other.
func force_commit(car: Car, node: Vector2i, approach: int, turn: int) -> void:
	release(car) ## Drop any stale committed slot first.
	var movement := find_waiting(car)
	if movement == null:
		movement = Movement.new()
		movement.car_id = car.get_instance_id()
		movement.node = node
		movement.approach = approach
		movement.turn = turn
		movement.arrival = now()
		if not _waiting.has(node):
			_waiting[node] = []
		_waiting[node].append(movement)
	commit(car)


## The car left the box: its committed movement frees the node.
func release(car: Car) -> void:
	var car_id := car.get_instance_id()
	for key: Vector2i in _committed:
		for movement: Movement in _committed[key]:
			if movement.car_id == car_id:
				_committed[key].erase(movement)
	for key: Vector2i in _waiting:
		for movement: Movement in _waiting[key]:
			if movement.car_id == car_id:
				_waiting[key].erase(movement)


## The car's waiting entry, or null.
func find_waiting(car: Car) -> Movement:
	var car_id := car.get_instance_id()
	for key: Vector2i in _waiting:
		for movement: Movement in _waiting[key]:
			if movement.car_id == car_id:
				return movement
	return null


## The car's committed entry, or null (harness observability).
func find_committed(car: Car) -> Movement:
	var car_id := car.get_instance_id()
	for key: Vector2i in _committed:
		for movement: Movement in _committed[key]:
			if movement.car_id == car_id:
				return movement
	return null


## Waiting arrivals at `node` — the staged scenarios read the queue.
func waiting_at(node: Vector2i) -> Array:
	return _waiting.get(node, [])


## Committed movements at `node`.
func committed_at(node: Vector2i) -> Array:
	return _committed.get(node, [])


## The compatibility table (T-134 §2), landed form: a movement coexists only
## with a SAME-approach queue mate and with an OPPOSING movement of the SAME
## turn — opposing straights pass right-side to right-side (3.0 m at the
## lanes), opposing rights cut the two disjoint corners (3.0 m at the corner
## waypoints), opposing lefts sweep past left-side to left-side (4.2 m). The
## ticket's draft table also called rights compatible with everything — the
## fleet scenario measured that promise broken twice (a perpendicular
## straight-vs-left merge at 0.73 m, then a perpendicular right-vs-right
## sharing one exit lane at 1.05 m, bodies overlapped both times) — so every
## PERPENDICULAR pair and every opposing mixed-turn pair conflicts. The
## no-overlap floor (pairwise gaps > 2.0 m) requires it. Deviations recorded
## in T-134.
static func movements_conflict(approach_a: int, turn_a: int,
		approach_b: int, turn_b: int) -> bool:
	var k := (approach_b - approach_a + 4) % 4
	if k == 0:
		return false ## A same-approach queue is the follow gap's job.
	return not (k == 2 and turn_a == turn_b)

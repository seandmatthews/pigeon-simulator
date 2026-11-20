class_name Car
extends CharacterBody3D
## One low-poly city car (T-008): a layer-4 `vehicle` on the road grid. Since
## T-134 traffic cars drive ROUTES through the road grid — a seeded walk of
## intersection nodes dealt leg by leg by the spawner, each leg's lane center
## `traffic_lane_offset` right of the road centerline for the travel direction
## (right-hand traffic, the old `traffic_loop` yaw conventions) — instead of
## patrolling one block's ring. At every intersection node on the route the car
## obeys the American four-way-stop protocol (T-134): it brakes to a FULL stop
## at the approach's stop line, registers with the shared `TrafficControl`
## ledger (`traffic`, spawner-injected; null skips the whole protocol — the
## bare-rig escape hatch), and proceeds only when the ladder grants the go —
## first-stopped-first beyond a near-simultaneous window, simultaneous arrivals
## yield to the right, straight and right beat left, conflicting committed
## movements hold the line. A body in the node's padded crosswalk bands holds
## the car too, pedestrian-priority. Nothing stays stuck: every hold runs the
## patience clock (T-134 §3) — at `patience_seconds` (physical blockers and
## wedges) or `protocol_patience_seconds` (ladder/crosswalk denials) the car
## honks once through the etiquette gate (T-166: only near the player, under
## the fleet cadence cap) and either commits through a protocol denial whose
## node box is actually clear, or steers one careful lateral pass around
## what holds it — a pigeon/tourist body (a CAR blocker never arms a pass:
## cars are solid to each other and a crossing arc would wedge, T-178
## round 2; the blocked car waits for the ladder and the queue to drain) —
## never blind: the pass arms only across a verified shoulder (the oncoming
## gate and the parked gate), with the aim clamped inside the asphalt. Amber corner
## blinkers arm `blinker_lead` before the route's next turn and flash at
## `blinker_hz` — the splat-planning tell (T-134 §5). Either mode takes a poop
## splat through the duck-typed `on_splatted` convention (T-006): the car
## honks — a bright body flash plus the horn (T-012) — and fires `splatted`,
## the cheap-points score event (30 base via the Game autoload's table, DESIGN
## pillar 3) that the spawner relays. Getting splatted never derails the drive,
## and never drops the stop state.

## Fired when the car adopts the waypoint before the route's last one — the
## spawner deals a fresh route FROM the car's end node and appends it (no
## teleport, no stop).
signal route_exhausted(car: Car)

## Fired on every splat this car takes — the spawner relays it into the Game
## autoload's score table (T-009).
signal splatted(car: Car)

## (T-178 round 2) Fired when the car has broken against CAR blockers too
## many times in a row — the solid-fleet world's wedged-car tell: a pass
## arc (or any physical contact the front zone cannot see) can pin a car
## with no logic escape, and the owning spawner answers by re-staging the
## car onto a clear lane point (the reviewer-proven recycle escape,
## automated).
signal stuck(car: Car)

## (T-183 round 1) Fired once when the car's origin drops below the ground
## plate's bottom — the off-world net the player's T-042 guard has and the
## fleet lacked: the plate is a 1.0 m box with nothing beneath it, so a car
## staged inside a massing footprint (the churn-replacement defect the T-183
## review session and the round-1 review both measured live) is depenetrated
## DOWNWARD through the plate and free-falls below the world — unreachable,
## and for PARKED cars frozen mid-fall (the physics tick early-returns before
## gravity ever runs). The spawner answers with the like-for-like swap, so
## the fleet count and the favor farm's restock stay intact.
signal fell_out(car: Car)

## PARKED sits at the curb · TRAFFIC drives its route.
enum Mode { PARKED, TRAFFIC }

## Civilian body paints only — the visitors' team hues are RESERVED (T-121):
## TEAM_GOLD gold and VISITOR_BLACK near-black both read as the jackpot target
## from the air, so this palette may never carry either hue. The sim pins the
## law (`civilian_palette_reserved`); the spawner's round-robin draw adapts to
## the palette length on its own.
const BODY_PALETTE: Array[Color] = [
	Color(0.85, 0.25, 0.22), Color(0.24, 0.45, 0.78), Color(0.92, 0.92, 0.90),
	Color(0.35, 0.62, 0.38), Color(0.72, 0.74, 0.78),
]
const HONK_TINT := Color(1.0, 0.85, 0.2)
## Every living Car — the careful pass's proximity read (round 1 review: two
## simultaneous passes converged mid-arc at 1.11 m). A car holds no fleet
## list, so a self-maintaining static registry is the one honest source.
static var _fleet: Array[Car] = []
## (T-166) Game-time (`TrafficControl.now`) of the last PATIENCE honk sounded
## anywhere in the fleet — the etiquette cadence cap's clock. Static like
## `_fleet`: the cadence is a world-wide street mood, not a per-car one. Near
## honks set it; far honks (gated out) and splat honks (never gated) do not.
static var _last_fleet_patience_honk: float = -INF
## Half the scene collider's 4.4 m length — the nose offset used for stop-line
## geometry (the nose stops AT the line; the body stays behind it).
const HALF_LENGTH := 2.2
## Braking-profile margin (m): the stop cap lands the nose this short of the
## line, so an overshooting integrator step can never carry it across.
const STOP_MARGIN := 0.3
@export_group("Traffic")
@export var cruise_speed: float = 6.0 ## Lane speed (m/s), before the per-car pace factor.
@export var corner_speed: float = 3.5 ## Speed cap while closing on a corner or still swinging onto the new leg (m/s) — and the careful-pass pace.
@export var corner_slow_range: float = 7.0 ## Distance (m) to the current corner inside which the corner cap applies.
@export var follow_gap: float = 5.6 ## Stop following at this center-to-center distance to the blocker (m).
@export var follow_gain: float = 1.8 ## How fast the allowed speed grows with the gap to the blocker (1/s).
@export var accel: float = 4.0 ## How fast traffic eases up to cruise speed (m/s²).
@export var brake_decel: float = 12.0 ## How hard traffic brakes behind a blocker (m/s²).
@export var turn_rate: float = 5.0 ## 1/s yaw easing toward the current corner.
@export var waypoint_reach: float = 4.5 ## Distance (m) at which the next corner is adopted — wide, in-quadrant turns.
@export var rejoin_dist: float = 5.0 ## Distance (m) down the new leg of the on-lane rejoin point steered through after each corner.

@export_group("Routes")
@export var route_legs_min: int = 3 ## Shortest dealt route (legs between intersection nodes).
@export var route_legs_max: int = 6 ## Longest dealt route.
@export var straight_weight: float = 0.60 ## Route turn roll: straight.
@export var right_weight: float = 0.25 ## Route turn roll: right (lefts rarer, per real driving).
@export var left_weight: float = 0.15 ## Route turn roll: left.
@export var blinker_lead: float = 12.0 ## Distance (m) to the route's next turn inside which the blinker arms — ≈ 2 s at cruise.
@export var blinker_hz: float = 2.0 ## Blinker flash rate (Hz) — inside the legal 60-120 pulses/min band.

@export_group("Stops")
@export var full_stop_speed: float = 0.3 ## Horizontal speed (m/s) at/below which a stopped car counts as fully stopped at its line.

@export_group("Patience")
@export var patience_seconds: float = 6.0 ## Seconds a hold lasts before the honk-and-pass break — physical blockers and wedges.
@export var protocol_patience_seconds: float = 12.0 ## (T-166) Seconds a PROTOCOL denial (a registered ladder denial or a crosswalk hold) lasts before the break — longer, because waiting in line is polite; the pigeon-in-the-crosswalk honk comes after ~12 s, not ~6.
@export var pass_clearance: float = 2.3 ## Lateral pass offset around a blocker (m): blocker half-width 0.95 + own half-width 0.95 + margin.
@export var pass_clearance_body: float = 1.7 ## (T-166) Lateral pass offset around a pigeon/tourist BODY blocker (m): body half ~0.35 + own half-width 0.95 + margin — narrower than the car-class clearance, the swing stays small.

@export_group("Honk")
@export var honk_flash_seconds: float = 0.8 ## Seconds the honk flash stays lit before fading.
@export var honk_near_m: float = 30.0 ## (T-166) Patience honks play only within this flat distance (m) of the player — beyond it the horn is static, not feedback, and the break runs silent.

@export_group("Pass")
@export var pass_lookahead: float = 25.0 ## (T-166) Corridor length (m) ahead of the pass origin the shoulder gates scan — ≈ 4 s at cruise 6 m/s.
@export var box_clear_radius: float = 7.0 ## (T-166) The force-commit's node-box occupancy radius (m) ≈ the box half-diagonal (±5 m both axes): any other fleet car this close holds the break's force-commit arm. (T-179) A FLOOR now — the Ames entries' junction stamp (the widest arm's half-width × √2, `_entry_box_radius`) raises it over the real junction extent.

## (T-166) The fleet-wide patience-honk cadence floor (s), on the fixed physics
## clock (`TrafficControl.now` — deterministic under `--fixed-fps 60`): a
## patience honk may sound only this long after the previous fleet-wide one.
## Near honks set the clock; far honks (already silent) do not.
const HONK_MIN_FLEET_INTERVAL := 3.0
## (T-166, re-derived per leg by T-179) The pass aim's ABSOLUTE lane-local
## lateral bounds (m) — the asphalt clamp — and the corridor gates' band are
## DERIVED from the leg's real lane geometry now (the Ames stop entries'
## `lane_off` / `half_width` stamps, T-179): for a street of half-width W
## whose lane line rides L off the centerline, the asphalt spans lane-local
## [−(W + L), +(W − L)], so the corridor gates read exactly that band and
## the aim clamp shrinks it by `PASS_EDGE_MARGIN` (own half-width 0.95 plus
## the 0.4 m margin the `pass_clearance` arithmetic already carries) on each
## side. The retired Windrow grid street (W 5.0, L 1.5) reproduces the landed
## T-166 constants exactly — corridor [−6.5, +3.5], clamp [−5.15, +2.15] —
## through the same derivation off the seam constants below (the fixed
## constant pairs are gone: a per-leg bound cannot be a constant). On the
## resident graph the bounds grow with the street: Lincoln Way's 20 m asphalt
## reads a [−16.5, +3.5] corridor (the oncoming lane center at lane-local
## −13.0 is INSIDE it — the gate checks the real opposing lane, which the
## fixed Windrow band stopped 6.5 m short of), a residential street reads
## [−7.5, +3.5]. No pass aim can leave the asphalt from the clamp alone,
## whatever the origin's own lane-local offset.
## (T-179) The clamp's margin inside the asphalt (m): the car's own
## half-width 0.95 plus the 0.4 m aim margin. The clamp bound is the
## corridor bound pulled in by this on each side.
const PASS_EDGE_MARGIN := 1.35
## (T-179) The Windrow-seam fallback lane geometry (m) — the retired grid
## street's constants (`city.gd road_width` 10.0, `traffic_lane_offset`
## 3.5 → lane line 1.5 off the centerline), from which the T-166 constant
## pairs were derived. Entries without the `lane_off`/`half_width` stamps
## (the grid seam) read these.
const SEAM_LANE_OFF := 1.5
const SEAM_HALF_WIDTH := 5.0

## Route lane waypoints (global coords) — the current route's corner points and
## leg leads, dealt and extended by the spawner. Empty (or PARKED mode) means
## stand still.
var path: PackedVector3Array = PackedVector3Array()
## The route's stop entries, one per intersection node still ahead on the
## route, in path order: {node: int (the route system's node id — a grid
## encoding on the Windrow seam, an AmesTrafficGraph node on Ames),
## pos: Vector3 (node, global), dir: int (grid compass index), axis: Vector3
## (flat unit approach axis — present on both systems since T-178, the
## protocol's direction read), turn: int (−1/0/+1), line: Vector3 (stop
## line center, global), corner: Vector3 (turn waypoint, global),
## bands: Array[Rect2] (the node's padded crosswalk bands, global — empty on
## the Ames graph until real crosswalks land), cruise: float (the leg's speed
## class cruise, Ames only), edge: int (the arriving directed edge, Ames
## only), registered: bool, committed: bool}. The car resolves them front to
## back.
var stops: Array[Dictionary] = []
var waypoint_index: int = 0
var mode: Mode = Mode.TRAFFIC
## Global center of the block the car is currently driving beside — refreshed
## from the route's leg geometry at every waypoint adoption (a route car's
## block assignment CHANGES AS IT DRIVES; the recycle scan groups cars by it).
var block_center: Vector3 = Vector3.ZERO
## Block-assignment changes taken while driving — the routes evidence the
## `traffic_routes_multi_block` scenario counts.
var block_changes: int = 0
## The node this route ends on — the extension deals the next route from
## here. Spawner-owned bookkeeping the car carries: a grid-route id on the
## Windrow seam, a `AmesTrafficGraph` node id on the resident Ames world
## (T-178).
var route_end_node: int = 0
## The four-way-stop ledger — assigned by the spawner before _ready (the
## `bread_spawner` service precedent). Null skips the protocol entirely: the
## car just follows its path (every bare-rig scenario and the harness escape
## hatch keep today's behavior).
var traffic: TrafficControl = null
## (T-166) The pigeon — assigned by the spawner before _ready (the same
## injection pattern as `traffic`/`bread_spawner`) and by the harness staging
## helper. The patience-honk gate reads it: honks play only within
## `honk_near_m` of the player, because beyond that the horn is static the
## player can attribute to nothing. Null (bare rigs without a spawner) keeps
## the old always-honk behavior — the gate needs a player to gate against.
var player: Player = null
## The city's block centers (global) — handed over at deal time so the car can
## refresh `block_center` without holding a City reference.
var _block_centers := PackedVector3Array()
var body_color: Color = BODY_PALETTE[0] ## The calm body albedo for every class — the spawner assigns it before _ready (the class draw for VISITOR/SUPERFAN, the palette round-robin for CIVILIAN).
var citizen_class: CitizenClass.Kind = CitizenClass.Kind.CIVILIAN ## The worn uniform (T-113) — assigned by the spawner before _ready, never re-rolled on recycle.
## (T-114) The tailgate pair, spawner-assigned before _ready (the
## `elder.bread_spawner` pattern): `has_cooler` shows the scene's hidden
## cooler meshes on every visitor car — parked AND traffic, they are
## transporting their tailgate — and `bread_spawner` is the service the
## tailgate CRUMB drops through while this car is parked. Null (bare rigs
## without a spawner) means no crumb, ever.
var has_cooler: bool = false
var bread_spawner: BreadSpawner = null
## This parked car's anchored tailgate crumb — freed and re-dropped by
## `_redress_crumb`, released when the car leaves the parking spot (or the
## tree). The crumb lives under the bread spawner, not under the car, so the
## reference is what ties it to this car.
var _tailgate_crumb: BreadCrumb = null
## (T-114) Where the tailgate crumb lands in car-local space: 0.45 m off the
## body's right side (body half-width 0.95), 0.75 m back toward the tailgate,
## at gutter height plus the 0.06 crumb lift — within the grounded eat reach
## of a pigeon waddling the road edge. Derived from the car's own transform
## at drop time: zero RNG on any stream.
const TAILGATE_CRUMB_OFFSET := Vector3(1.4, 0.06, 0.75)
var pace: float = 1.0 ## Per-car speed factor (0.9–1.15) so traffic spreads out.
## Honks taken so far — evidence for tests and the autoplay DONE line. The
## spawner's `honk_count` stays splat-relay-only: patience honks ride HERE
## and never reach the DONE line (T-134 Gate 2 contract).
var honk_count: int = 0
## (T-147) The once-per-target favor book: true after this car's FIRST splat
## of the run. Two readers — Main's `_on_car_splatted` gates ONLY the
## `Game.splat_favor` call on it (a repeat splat still honks, still scores and
## still chains, but books zero favor — including the negatives: a second hit
## on a civilian adds 0, not another −2), and CarSpawner's `_recycle_far`
## reads it as despawn eligibility (a spent car beyond the recycle radius
## churns out of the fleet through `_replace_car` instead of teleporting back
## to a curb to be farmed again). Set by `on_splatted` AFTER its
## `splatted.emit` — the order is load-bearing: Godot signals are synchronous,
## so the relay chain (spawner → Main) runs DURING the emit and reads the flag
## false exactly on the first splat; that read IS the whole gate (pinned by
## the `splat_favor_once_per_target` Gate 1b scenario).
var splatted_once: bool = false
## The armed blinker side: −1 left / 0 none / +1 right — readable by the
## harness and the pilot (the splat-planning tell).
var blinker: int = 0
## (T-168) The dev verb's forced blinker: 0 = none (the route-driven state
## machine owns the tell), −1/+1 = that side held solid-lit, overriding the
## arming logic and the flash law while set. Written only through
## `set_blinker_forced` (the `car_blinker` pilot verb's entry); released by
## the same call with 0 — the machine resumes exactly where the override
## paused it (a mid-hold clock keeps its remaining seconds).
var blinker_forced: int = 0
## (T-168) The dev traffic freeze: when true, every car's `_physics_process`
## returns at the top — route progress, the patience/honk clocks and the
## blinker state machine all hold, and transforms stay put for staging — and
## CarSpawner's recycle cadence is gated on the same flag. Static like
## `_fleet` because the freeze is a world-wide staging state, not a per-car
## one; set only by the `freeze_traffic` pilot verb (and the suite's restore).
static var traffic_frozen: bool = false

## (T-183 round 1) The off-world net's line: any car origin below this is out
## of the world. The plate's bottom sits at y −1.0 (the bake's stacked flats
## end at its y-0 top face) and nothing legitimate lives beneath it — a car
## that slips below the plate settles into a drive-under-the-world
## equilibrium ≈ −2.8 (the route steer pulls up toward the y-0 waypoints, the
## glue vy pulls down), so the net line must sit ABOVE that equilibrium: 0.5 m
## under the plate's bottom face. The player's own T-042 guard uses −5.0
## below "any floor"; the fleet's floor is THE plate.
const OFF_WORLD_Y := -1.5

## (T-183 round 1) The `fell_out` latch — the signal fires once per car; the
## spawner's like-for-like swap is the only handler and must never double-book.
var _fell_out_emitted: bool = false

## (T-162) Corner seeds for `_seat_blinkers`, car-local, in the BlinkFL/FR/RL/
## RR order — hovering above the hood/deck top at each corner station (front is
## −z), so the closest paint triangle is the surface the lens seats on. Tuning
## latitude per the ticket; the probe measured the derived seats at
## (±0.63, 0.72, −1.89) front / (±0.63, 0.74, +1.94) rear.
const BLINKER_SEEDS: Array[Vector3] = [
	Vector3(-0.63, 0.8, -1.9), Vector3(0.63, 0.8, -1.9),
	Vector3(-0.63, 0.8, 1.95), Vector3(0.63, 0.8, 1.95),
]
## (T-162) How deep the lens sinks into the panel (m) — the half-buried read,
## the `cafe_spawner.gd _hair_offset` sunk-past-the-surface precedent.
const BLINKER_SINK := 0.015

var _honk_tween: Tween
## On-lane rejoin point just past the corner being rounded — steering through
## it instead of straight at the far corner keeps the car ON its lane; a bare
## far-corner aim lets the corner-exit offset persist until the body scrubs a
## curb or noses into a parking car.
var _via_point := Vector3.ZERO
var _has_via := false
## Index of the next unresolved stop entry (into `stops`).
var _stop_index: int = 0
## Patience clock (s) accumulated under the current hold.
var _patience: float = 0.0
## While true the car is steering one careful lateral pass around a blocker.
var _passing := false
## Where the pass started — its travel measures the pass's progress.
var _pass_origin := Vector3.ZERO
## The pass's world-fixed aim point, armed once at the break — steering at a
## live-heading-relative point turns the pass into a circle that never clears
## the blocker.
var _pass_aim := Vector3.ZERO
## The instance id of the body this pass is clearing — the proximity brake
## must never brake for it (passing means closing to pass_clearance of it).
var _pass_target := 0
## The pass shoulder: +1 left of travel / −1 right, flipped BEFORE every arm
## (`_break_hold`) — so a fresh car's first break aims RIGHT (init +1 → −1
## against the car-local "forward is −z, right is +x" convention), its second
## left — and a pass that wedged (or a denied shoulder) tries the other side
## next break (T-166 §2 keeps the flip and adds the fallthrough).
var _pass_side := 1
## Pass progress watch: the best travel so far and how long since it grew.
var _pass_best := 0.0
var _pass_stall := 0.0
## The wedge watchdog: last frame's flat position and how long the car has
## commanded real speed without actually moving (a curb/slab grind the zone
## can never see — blocker INF, target cruise, zero displacement).
var _prev_pos := Vector3.ZERO
var _stalled := 0.0
## (T-178 round 2) The no-progress break counter — the wedged-car tell in
## the solid-fleet world: a pass arc can wedge a car against ANOTHER CAR
## (side contact the front zone misses) or against a BUILDING corner
## collider (invisible to the zone's mask entirely), and the crawl that
## follows defeats the pass's stall watchdog by advancing `traveled`
## millimetres at a time. Every patience break with no genuine travel
## behind it counts; `STUCK_BREAKS` in a row fires `stuck` and the owning
## spawner re-stages the car (the reviewer-proven recycle escape). Any
## accumulated travel over 1 m resets it.
var _no_progress_breaks := 0
var _progress_accum := 0.0
const STUCK_BREAKS := 3
## Post-turn blinker hold: the side just driven and the seconds left on it.
var _blinker_side: int = 0
var _blinker_hold: float = 0.0
## Flash clock (s) — the square wave runs off it at `blinker_hz`.
var _flash_clock: float = 0.0

## Decision batching (the per-tick scan throttle): the expensive scans — the
## front-zone overlap query (`_blocker_distance`), the crosswalk band sweep
## and the block-center refresh — run once every SCAN_INTERVAL-th physics
## tick (10 Hz decisions, visually identical at town scale) and cache their
## results below; the cheap motion integration (steering, the exact-brake
## stop-line profile, the ladder poll, the blinker machine) keeps its full
## 60 Hz rate off the cached values. `_scan_phase` is staggered by instance
## id in `_ready`, so the 26-car fleet's scan ticks spread across the interval
## instead of spiking one shared tick. Safety-relevant O(1) reads (the brake
## profile's along-line distance, the wedge watchdog) never join the batch.
const SCAN_INTERVAL := 6
var _scan_phase := 0
## Forward distance to the nearest front-zone body (m, INF when clear) —
## `_blocker_distance()` sampled at the scan tick.
var _cached_blocker_dist := INF
## The active stop entry's crosswalk occupancy at the scan tick — the
## pedestrian-priority read (`_crosswalk_blocked` against `_current_entry()`).
var _cached_crosswalk_blocked := false
## The pass's no-overlap fleet gap (m, INF when not passing) —
## `_nearest_car_gap(_pass_target)` sampled at the scan tick.
var _cached_pass_gap := INF

@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _flag_pole: MeshInstance3D = $Visual/FlagPole
@onready var _flag_banner: MeshInstance3D = $Visual/FlagBanner
@onready var _cooler: Node3D = $Visual/Cooler
@onready var _front_zone: Area3D = $FrontZone
@onready var _blink_fl: MeshInstance3D = $Visual/BlinkFL
@onready var _blink_fr: MeshInstance3D = $Visual/BlinkFR
@onready var _blink_rl: MeshInstance3D = $Visual/BlinkRL
@onready var _blink_rr: MeshInstance3D = $Visual/BlinkRR


func _ready() -> void:
	# Per-car body material: the palette tint and later the honk flash, without
	# touching the shared scene material. (T-113) For the special classes it
	# carries the full-body team paint and raises the flag meshes from the
	# scene (hidden by default); civilians keep the palette draw, flags down.
	var mat: StandardMaterial3D = _body_mesh.mesh.surface_get_material(0).duplicate()
	mat.albedo_color = body_color
	_body_mesh.material_override = mat
	_seat_blinkers() ## (T-162) The lenses sit on the paint body — derived from the mesh.
	match citizen_class:
		CitizenClass.Kind.VISITOR:
			_show_flag(CitizenClass.VISITOR_BLACK \
					if body_color.is_equal_approx(CitizenClass.TEAM_GOLD) \
					else CitizenClass.TEAM_GOLD)
		CitizenClass.Kind.SUPERFAN:
			_show_flag(CitizenClass.TEAM_GOLD)
		_:
			pass ## CIVILIAN — exactly the pre-T-113 look: no flag.
	if has_cooler:
		_cooler.visible = true ## (T-114) The visitor's tailgate rides along — visual only.
	_scan_phase = get_instance_id() % SCAN_INTERVAL ## Decision-batch stagger.
	_fleet.append(self)


## Flat distance to the nearest OTHER living car (m), INF when alone — the
## pass's no-overlap read. `except_id` skips the body being passed: closing
## to ~2.3 m of its own blocker is the pass's whole geometry, and braking
## for it would pin the pass mid-arc forever (round 1 soak: 13/14 cars froze
## that way).
func _nearest_car_gap(except_id: int = 0) -> float:
	var best := INF
	for other in _fleet:
		if other == null or other == self or not is_instance_valid(other):
			continue
		if other.get_instance_id() == except_id:
			continue
		var d := Vector2(other.global_position.x - global_position.x,
				other.global_position.z - global_position.z).length()
		best = minf(best, d)
	return best


## Raises the tailgate flag (T-113) and paints the banner in the pairing
## partner color — the scene's visual-only meshes, no new physics shapes.
func _show_flag(banner_color: Color) -> void:
	var banner_mat: StandardMaterial3D = _flag_banner.mesh.surface_get_material(0) \
			.duplicate() as StandardMaterial3D
	banner_mat.albedo_color = banner_color
	_flag_banner.material_override = banner_mat
	_flag_pole.visible = true
	_flag_banner.visible = true


func _physics_process(delta: float) -> void:
	if traffic_frozen:
		return ## (T-168) The dev freeze: route progress, honk clocks and the
			## blinker state machine all hold; transforms stay put for staging.
	## (T-183 round 1) The off-world net, BEFORE the parked early-return — a
	## fallen PARKED car freezes mid-fall otherwise (no gravity ever runs for
	## it), so the lost-car tell must ride the tick every mode reads.
	if not _fell_out_emitted and global_position.y < OFF_WORLD_Y:
		_fell_out_emitted = true
		fell_out.emit(self)
		return
	if mode == Mode.PARKED:
		return ## Parked cars just sit at the curb.
	_drive(delta)
	_update_blinker(delta)


## Lane-follow with stop-if-blocked: the allowed speed shrinks with the gap to
## whatever player·npc·vehicle occupies the front zone, so traffic brakes
## smoothly, queues at ~1 m bumper gaps and CREEPS forward as the gap opens —
## a binary stop/go would pin cars at zero under the intermittent blocks of a
## shuffling queue. On top of that sits the four-way-stop protocol (T-134):
## approaching an unresolved stop entry caps speed on an exact-brake profile
## to the line; a registered (or crosswalk-blocked) car holds at its line
## until the ledger grants the go; a committed car rolls the box and releases
## past it. Every hold feeds the patience clock.
func _drive(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	## The decision-batched scans (see SCAN_INTERVAL): block refresh, front-zone
	## overlap distance, crosswalk occupancy, pass fleet gap — cached for the
	## next SCAN_INTERVAL − 1 ticks of cheap motion integration.
	_scan_phase += 1
	if _scan_phase >= SCAN_INTERVAL:
		_scan_phase = 0
		_refresh_block()
		_cached_blocker_dist = _blocker_distance()
		_cached_crosswalk_blocked = _crosswalk_blocked(_current_entry())
		_cached_pass_gap = _nearest_car_gap(_pass_target) if _passing else INF
	## The wedge watchdog measures LAST frame's displacement (cheap, honest).
	var moved := Vector2(global_position.x - _prev_pos.x,
			global_position.z - _prev_pos.z).length()
	_prev_pos = global_position
	## (T-178 round 2) Genuine travel resets the no-progress break counter —
	## a creeping wedge advances `traveled` millimetres at a time and would
	## otherwise sit under the stall watchdogs forever.
	_progress_accum += moved
	if _progress_accum > 1.0:
		_progress_accum = 0.0
		_no_progress_breaks = 0
	var entry := _current_entry()
	## The previous frame's motion may have carried us past the active node —
	## release before anything else reads the entry.
	entry = _advance_past_entry(entry)
	## (T-178 round 2) A nose beyond the line's registration window can never
	## resolve its entry: the brake cap reads 0 past the line
	## (`maxf(0, along − STOP_MARGIN)`) and the [−3, +1] m window excludes
	## registration, so the car would hold forever, invisible to the ladder —
	## the round-2 review's corridor lock (cars staged or rebased inside the
	## stop-line window). The placement now refuses such candidates; this
	## self-heal releases any entry a car still finds itself past, exactly
	## like the past-the-node release above: the ledger entry releases, the
	## stop index advances, the car moves on.
	if not entry.is_empty() and traffic != null \
			and _entry_along(entry) < -3.0:
		_finish_entry(entry)
		entry = _current_entry()
	## (T-178) The leg's cruise: the current stop entry's `cruise` (the speed
	## class of the street being driven — Lincoln Way faster, residential
	## calm), falling back to the car's own `cruise_speed` on the Windrow seam.
	var cruise := _leg_cruise()
	## The careful pass overrides the zone cap outright: the pass IS the exit
	## from a zone the ordinary cap can never open (a stopped car has no
	## lateral velocity, so the blocker stays parked in its front zone at
	## exactly the follow gap forever). It steers a near-field offset waypoint
	## at `corner_speed` instead.
	var target_speed := corner_speed if _passing \
			else minf(cruise * pace, _gap_speed(cruise))
	var held := false
	## The pass overrides the protocol outright, not just the zone cap: a car
	## breaking a hold must never be re-pinned by the very entry it is
	## breaking — a registered-denied hold or an at-the-line brake cap would
	## otherwise pin the pass at 0 m/s and the car would honk forever.
	if entry != null and traffic != null and not _passing:
		var cap_result := _protocol_speed(entry, hspeed, target_speed)
		target_speed = cap_result.x
		held = cap_result.y
	## The patience clock (T-134 §3): any hold — a denied go, a FrontZone
	## blocker, a pigeon in the lane, or a WEDGE (commanded speed, zero
	## displacement — the curb grind) — feeds it; at `patience_seconds` the car
	## honks once (etiquette-gated) and breaks the hold (commit through a
	## clear box, or one gated careful pass).
	if target_speed > 1.0 and moved < 0.03:
		_stalled += delta
	else:
		_stalled = 0.0
	if held or target_speed < cruise * pace * 0.5 or _stalled > 1.0:
		## (T-180) A red-light hold alone never feeds the clock: the signal
		## guarantees progress, and a break would run the red. Every OTHER
		## hold (the ladder on green, a crosswalk body, a physical blocker, a
		## wedge) accumulates exactly as before — a red that also holds for a
		## pigeon in the band keeps the pedestrian-priority hold's patience
		## frozen until the green, then it runs its own clock.
		var red_hold := held and entry != null and not entry.is_empty() \
				and entry.has("signal_group") \
				and traffic.signal_red_for_group(int(entry["signal_group"]))
		if not red_hold:
			_patience += delta
		## (T-166) One accumulated clock; the threshold reads the CURRENT hold
		## class each frame — `held` (a registered ladder denial or a crosswalk
		## hold, from `_protocol_speed`) expires at `protocol_patience_seconds`,
		## physical blockers and wedges at `patience_seconds`. A hold that
		## becomes a protocol denial mid-window simply expires later; monotone,
		## no second float.
		var threshold := protocol_patience_seconds if held else patience_seconds
		if _patience >= threshold and not _passing:
			_stalled = 0.0
			_break_hold(entry)
	if path.size() >= 2:
		var to_target := path[waypoint_index] - global_position
		to_target.y = 0.0
		if to_target.length() < waypoint_reach:
			# Arm the on-lane rejoin point down the new leg, then switch to the
			# next corner. On the open route path index 0 extends its own leg
			# backwards instead of wrapping to the route's far end.
			var prev := path[waypoint_index - 1] if waypoint_index > 0 \
					else path[0] - (path[1] - path[0])
			var leg := path[waypoint_index] - prev
			leg.y = 0.0
			_via_point = path[waypoint_index] + leg.normalized() * rejoin_dist
			_has_via = true
			_on_waypoint_adopted()
			waypoint_index += 1
			if waypoint_index >= path.size():
				waypoint_index = path.size() - 1 ## No extension came — hold at the route's end.
			to_target = path[waypoint_index] - global_position
			to_target.y = 0.0
		var aiming := to_target
		if _has_via:
			var to_via := _via_point - global_position
			to_via.y = 0.0
			if to_via.length() < waypoint_reach * 0.5:
				_has_via = false
			else:
				aiming = to_via
		if _passing:
			# The careful pass: steer at the world-fixed aim point armed at the
			# break (RELATIVE here — `aiming` is a direction vector) — a
			# live-heading-relative point would turn the pass into a circle
			# that never clears the blocker. A pass never trades its blocker
			# for a neighbour: inside the no-overlap margin of any OTHER car
			# it halts mid-arc (the stall escape then re-arms the clock and
			# the next break tries the other shoulder).
			aiming = _pass_aim - global_position
			aiming.y = 0.0
			if _cached_pass_gap < 2.6:
				target_speed = 0.0
		_face(aiming / maxf(aiming.length(), 0.001), delta)
		# Corners are taken wide and slow: the cap applies while closing on the
		# corner (or rejoin point) AND until the swing has levelled onto the
		# new leg (yaw still off-target), so the arc never overshoots into the
		# quadrant where a neighbouring car makes its own turn.
		if aiming.length() < corner_slow_range \
				or absf(angle_difference(rotation.y, atan2(-aiming.x, -aiming.z))) > 0.45:
			target_speed = minf(target_speed, corner_speed)
		if waypoint_index >= path.size() - 1 \
				and (path[waypoint_index] - global_position).length() < waypoint_reach:
			target_speed = 0.0 ## Route ran dry with no extension: stand at the end.
	var rate := brake_decel if hspeed > target_speed else accel
	hspeed = move_toward(hspeed, target_speed, rate * delta)
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	velocity.x = fwd.x * hspeed
	velocity.z = fwd.z * hspeed
	velocity.y = -2.0 ## Stay glued to the asphalt.
	move_and_slide()
	_update_pass(delta)
	_apply_blinker_meshes()


## The active stop entry, or null when the route's entries are all resolved.
func _current_entry() -> Dictionary:
	return stops[_stop_index] if _stop_index < stops.size() else {}


## The active stop entry's approach axis: the entry's stored `axis` (flat,
## unit, global — the Ames graph entries carry the real street direction,
## T-178) with the grid compass as the Windrow-seam fallback.
func _entry_axis(entry: Dictionary) -> Vector3:
	if entry.has("axis"):
		return entry["axis"]
	return City.ROUTE_DIR_VECS[int(entry.get("dir", 0))]


## Releases and steps past the active entry once the body is clearly through
## its node (center 1 m past along the approach axis) — the committed
## movement frees the box exactly here.
func _advance_past_entry(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return entry
	var a := _entry_axis(entry)
	var past := Vector3(global_position - entry.pos).dot(a)
	if past > 1.0:
		_finish_entry(entry)
		return _current_entry()
	return entry


## The signed nose-to-line distance for one entry (m, > 0 while the nose is
## before the line) — the brake profile's and the registration window's read,
## shared with the past-line self-heal in `_drive`.
func _entry_along(entry: Dictionary) -> float:
	var a := _entry_axis(entry)
	var nose := global_position + _flat_forward() * HALF_LENGTH
	var to_line := Vector3(entry.line - nose)
	to_line.y = 0.0
	return to_line.dot(a)


## The protocol's speed cap for one frame against `entry` (null-safe).
## Returns (capped target speed, held-now) as a Vector2 pair.
func _protocol_speed(entry: Dictionary, hspeed: float, target_speed: float) -> Vector2:
	if entry.is_empty() or traffic == null:
		return Vector2(target_speed, false)
	var a := _entry_axis(entry)
	var along := _entry_along(entry) ## > 0 while the nose is before the line.
	if not entry.committed:
		if entry.registered:
			## (T-180) Signal control: at a signalized corner the phase gate
			## fronts the ladder — a red parks the car at its line (held).
			## The hold deliberately does not feed the patience clock (the
			## `_drive` accumulation reads `signal_red_hold` below): the light
			## guarantees progress, and the force-commit break would run it.
			if entry.has("signal_group") \
					and traffic.signal_red_for_group(int(entry["signal_group"])):
				return Vector2(0.0, true)
			## Stopped at the line: hold until the ladder (and the crosswalk)
			## both say go, then commit and roll.
			if _cached_crosswalk_blocked:
				return Vector2(0.0, true)
			if traffic.request_go(self):
				traffic.commit(self)
				entry.committed = true
				return Vector2(target_speed, false)
			return Vector2(0.0, true)
		## Approaching: an exact-brake profile to the line — speed squared
		## capped by twice the deceleration times the remaining distance — so
		## the nose halts just short and can never cross the bar, even with a
		## full-brake integrator step. The crosswalk gate does NOT bind here:
		## the bands sit between the line and the box, so an occupied band is
		## irrelevant until the car is at its line (where the registered hold
		## below keeps it) — a mid-approach stop would strand cars tens of
		## metres from their lines. Registration is ALONG-AXIS and forgiving
		## of overshoot (round  1 review): a car stopped at its line region
		## — up to 1 m short or up to 3 m into the box, ANY lateral offset —
		## registers; the old full 3D distance-to-line-center test left a car
		## stopped mid-swing/mid-pass 1.1+ m laterally off the line center
		## unregistered forever, pinned by the zero cap, honking every
		## patience cycle.
		var cap := sqrt(2.0 * brake_decel * maxf(0.0, along - STOP_MARGIN))
		if hspeed <= full_stop_speed and along <= 1.0 and along >= -3.0:
			entry.registered = true
			traffic.register_arrival(self, entry.node, _entry_axis(entry), entry.turn)
		return Vector2(minf(target_speed, cap), cap <= 0.0)
	## Committed and rolling the box: a late-entering body re-holds the car
	## before its nose crosses the bar; past the bar the box is ours.
	if along > 0.0 and _cached_crosswalk_blocked:
		return Vector2(0.0, true)
	return Vector2(target_speed, false)


## True while any watched body (player or tourist) stands in the node's padded
## crosswalk bands — the pedestrian-priority hold. A cheap rect-overlap point
## test; no raycasts. (T-180) The Ames entries carry ORIENTED band records
## `{center: Vector2, axis: Vector2, half_along, half_across}` (global XZ —
## real streets run at arbitrary angles, which an axis-aligned Rect2 cannot
## span); the Windrow seam's axis-aligned Rect2s duck-type alongside.
func _crosswalk_blocked(entry: Dictionary) -> bool:
	if traffic == null or entry.is_empty():
		return false
	for body: Node3D in traffic.watched:
		if body == null or not is_instance_valid(body):
			continue
		var p := body.global_position
		var flat := Vector2(p.x, p.z)
		for band: Variant in entry.bands:
			if band is Rect2:
				if (band as Rect2).has_point(flat):
					return true
			elif band is Dictionary:
				var b := band as Dictionary
				var rel := flat - (b["center"] as Vector2)
				var axis := (b["axis"] as Vector2)
				if absf(rel.dot(axis)) <= float(b["half_along"]) \
						and absf(rel.dot(Vector2(-axis.y, axis.x))) \
								<= float(b["half_across"]):
					return true
	return false


## The patience break (T-134 §3, rebuilt by T-166): honk ONCE where the honk
## is feedback, then make progress. Three rules keep the break calm:
##   1. EVERY blocker class may be passed, but never blind: the pass arms only
##      across a VERIFIED shoulder (rule 3's gates). This INCLUDES driving
##      cars — the ticket's §1 had retired queue passes outright, but the
##      landed census met the §1 fallback's own trigger and the pre-agreed
##      escape (option 1, the oncoming-gated car pass) was invoked and is
##      recorded in the ticket: the no-car-pass tree froze 8 of 14 traffic
##      cars > 30 s (pre-fix worst continuous stop 21.2 s) in MUTUAL
##      HEAD-TO-HEAD FACE-OFFS — wrong-side cars (pass-overshoot U-turns)
##      nose-to-nose with oncoming traffic, each the other's only blocker,
##      a stand-off no ladder, box check or parked rule can dissolve. The
##      gates made the car pass what §1 wanted all along: not a blind swerve
##      into oncoming, but a verified-clear overtake. (T-178 round 2
##      supersedes the car pass entirely on the resident world: cars are
##      SOLID to each other now, a crossing arc wedges instead of ghosting,
##      and the directed-lane graph cannot produce the face-offs — one-way
##      lanes, no U-turns in deals, forward-snapped recycles — so a car
##      blocker waits for the ladder and the queue to drain. T-179
##      re-derives the etiquette for real lanes.)
##   2. A protocol denial with nothing physical ahead force-commits through
##      (the liveness guarantee that no ladder cycle can deadlock the city) —
##      but ONLY when the node box is actually clear (`_box_clear`, geometric:
##      it catches committed movements mid-box AND waiting cars that overshot
##      in, which a ledger-only check would miss). When the box is occupied
##      the break does nothing but the gated honk and re-arms — the occupant
##      is mid-movement and clears in seconds, and liveness chains through
##      the occupant's own breaks. The three-mutual-right-yield cycle (all
##      waiting, box empty) still force-commits, at protocol patience,
##      exactly as `TrafficControl`'s liveness note documents.
##   3. A pigeon/tourist body or a wedge grind gets one careful lateral pass
##      at corner speed — but only across a VERIFIED shoulder: the oncoming
##      gate denies the left while an opposing car sits in the corridor, the
##      parked gate denies the right while a parked car occupies the band,
##      the alternated shoulder is tried first and a denied one falls to the
##      other, and the aim is clamped so the pass center can never leave the
##      asphalt. A car blocker (parked or driving) arms NO pass since the
##      round-2 gate above — the car waits. Both shoulders denied arms no
##      pass this cycle — the gated honk, the clock re-arms, the next cycle
##      re-checks.
func _break_hold(entry: Dictionary) -> void:
	_play_patience_honk()
	_patience = 0.0
	_pass_side = -_pass_side ## The next pass tries the other shoulder.
	if entry != null and traffic != null and entry.has("registered") \
			and entry.registered and not entry.committed \
			and _blocker_distance() == INF:
		if not _box_clear(entry.pos, _entry_box_radius(entry)):
			## Occupied box: the break does nothing but the gated honk and
			## re-arms (T-166 §4) — the occupant is mid-movement and clears
			## in seconds, and liveness chains through the occupant's own
			## breaks. Falling through to a wedge pass here would drive the
			## registered car THROUGH the box it must respect. (T-179) The
			## radius reads the entry's junction stamp — a real junction is
			## as wide as its widest street, not the Windrow ±5 m grid box.
			return
		traffic.force_commit(self, entry.node, _entry_axis(entry), entry.turn)
		entry.committed = true
		return
	var blocker := _nearest_blocker()
	## (T-178 round 2) A CAR blocker — parked or driving — never arms a pass:
	## cars are SOLID to each other now (car.tscn mask 9, the round-1
	## fused-pile fix), and a pass whose arc crosses its blocker's body can
	## no longer ghost through — it wedges at contact, re-arms, wedges again,
	## and the standing tangle locks the corridor (the round-2 review's
	## total gridlock: 14 moving at t=12 s, 0 from t=154 s, the only escape
	## the player-anchored recycle). On the directed-lane graph a blocked car
	## simply WAITS: the head of the queue rolls when its junction box
	## clears, and the ladder + follow-gap logic drain the line behind it —
	## the Windrow head-to-head standoffs the pass existed for cannot arise
	## (one-way lanes, no U-turns in deals, forward-snapped recycles). The
	## passes that remain are the GHOST-safe ones: pigeon/tourist bodies
	## (the car's mask never included the player/npc layers) and the
	## no-body curb-grind wedge (blocker null), where contact is physically
	## impossible. (T-179) The GATE ITSELF lands here — the round-2 record
	## described it, but the code below still armed a pass for every blocker
	## class (only the clearance differed), and the calm-port staged probes
	## measured a mover swinging around its parked blocker on the resident
	## graph. The stuck escape above stays the car-blocker liveness path.
	_no_progress_breaks += 1
	if _no_progress_breaks >= STUCK_BREAKS:
		_no_progress_breaks = 0
		_progress_accum = 0.0
		stuck.emit(self)
	if blocker is Car:
		return
	_pass_origin = global_position
	var axis := _leg_axis()
	var first_clear := _shoulder_clear(_pass_side, axis)
	var second_clear := _shoulder_clear(-_pass_side, axis)
	if not first_clear and not second_clear:
		return ## Both shoulders denied: no pass this cycle — re-check next one.
	_passing = true
	_pass_target = blocker.get_instance_id() if blocker != null else 0
	## Pigeon/tourist bodies get the narrower `pass_clearance_body`; car-class
	## blockers (parked or driving) and wedge grinds (no zone body at all)
	## keep the car-class `pass_clearance`.
	var clearance := pass_clearance_body \
			if (blocker != null and not blocker is Car) else pass_clearance
	var fwd := _flat_forward()
	var left := Vector3(fwd.z, 0.0, -fwd.x) * float(
			_pass_side if first_clear else -_pass_side)
	var aim := global_position + fwd * 6.0 + left * clearance
	## Asphalt clamp (T-166 §2, bounds re-derived per leg by T-179): the aim's
	## lane-local lateral offset may never leave the leg's asphalt minus the
	## PASS_EDGE_MARGIN — the corridor bounds pulled in by own half-width 0.95
	## and the 0.4 m aim margin — corrected along the leg's right axis, so
	## even a yawed origin (whose `fwd * 6.0` term leaks lateral offset)
	## cannot swing the aim off the asphalt. The Windrow seam reproduces the
	## landed [−5.15, +2.15] constants exactly.
	var corridor := _pass_corridor()
	var clamp_left := corridor.x + PASS_EDGE_MARGIN
	var clamp_right := corridor.y - PASS_EDGE_MARGIN
	var lat := _lane_local(aim, axis)
	if lat > clamp_right:
		aim += _lane_right(axis) * (clamp_right - lat)
	elif lat < clamp_left:
		aim += _lane_right(axis) * (clamp_left - lat)
	_pass_aim = aim


## (T-166 §3) The patience honk's etiquette gate. The horn plays only where it
## is feedback: within `honk_near_m` of the player — a null player (bare-rig
## default) keeps the old always-honk behavior, the gate needs a player to
## gate against — and only when the fleet's last patience honk is
## `HONK_MIN_FLEET_INTERVAL` old (`TrafficControl.now`, the fixed physics
## clock). Near honks set the fleet clock; far honks are already silent and
## do not; a capped-out near honk is DUCKED (the next cycle tries again),
## like a real street. `honk_count` counts played honks only. Splat honks
## (`on_splatted`) are never gated — hitting a car is always feedback.
func _play_patience_honk() -> void:
	if player != null:
		var offset := Vector2(player.global_position.x - global_position.x,
				player.global_position.z - global_position.z)
		if offset.length() > honk_near_m:
			return
	var t := TrafficControl.now()
	if t - _last_fleet_patience_honk < HONK_MIN_FLEET_INTERVAL:
		return
	_last_fleet_patience_honk = t
	honk()


## (T-166 §2) The car's current leg axis: the flat unit travel direction of
## the leg being driven — the active stop entry's approach axis (route legs
## are grid-axis-aligned), falling back to the bearing of the current
## waypoint, then the car's own flat forward (a route-end wedge stand). Every
## lane-local gate read computes against this axis and the lane line through
## the pass origin.
func _leg_axis() -> Vector3:
	var entry := _current_entry()
	if not entry.is_empty():
		return _entry_axis(entry)
	if waypoint_index < path.size():
		var to := path[waypoint_index] - global_position
		to.y = 0.0
		if to.length() > 0.1:
			return to.normalized()
	return _flat_forward()


## (T-166 §2) The flat right-of-travel unit vector for a leg `axis`.
func _lane_right(axis: Vector3) -> Vector3:
	return Vector3(-axis.z, 0.0, axis.x)


## (T-179) The current leg's lane offset (m off the centerline) — the
## `_leg_cruise` precedent: the active stop entry's `lane_off` stamp (the
## spawner reads it off the arriving directed edge's run), falling back past
## the last entry to ITS stamp, and to the Windrow-seam constant when no
## entry carries one.
func _leg_lane_off() -> float:
	if _stop_index < stops.size():
		if stops[_stop_index].has("lane_off"):
			return float(stops[_stop_index]["lane_off"])
	elif not stops.is_empty() and stops[stops.size() - 1].has("lane_off"):
		return float(stops[stops.size() - 1]["lane_off"])
	return SEAM_LANE_OFF


## (T-179) The current leg's street half-width (m) — the same stamp read as
## `_leg_lane_off`, Windrow-seam fallback included.
func _leg_half_width() -> float:
	if _stop_index < stops.size():
		if stops[_stop_index].has("half_width"):
			return float(stops[_stop_index]["half_width"])
	elif not stops.is_empty() and stops[stops.size() - 1].has("half_width"):
		return float(stops[stops.size() - 1]["half_width"])
	return SEAM_HALF_WIDTH


## (T-179) The pass corridor's lane-local lateral bounds for the CURRENT leg
## (m) — Vector2(left, right): the leg's actual asphalt edges seen from the
## lane line, [−(W + L), +(W − L)] for street half-width W and lane offset L.
## The Windrow seam reads (−6.5, +3.5) — the landed T-166 constants; Lincoln
## Way's 20 m asphalt reads (−16.5, +3.5), so the oncoming gate checks the
## REAL opposing lane (lane-local −2·L ≈ −13.0) instead of stopping 6.5 m
## short of it.
func _pass_corridor() -> Vector2:
	return Vector2(-(_leg_half_width() + _leg_lane_off()),
			_leg_half_width() - _leg_lane_off())


## (T-179) The force-commit's node-box occupancy radius for one entry (m):
## the entry's junction stamp — the widest arm's half-width × √2, the box's
## half-diagonal over the REAL junction extent — held above the
## `box_clear_radius` export floor (the Windrow ±5 m grid box's 7.0).
func _entry_box_radius(entry: Dictionary) -> float:
	return maxf(box_clear_radius, float(entry.get("box_radius", 0.0)))


## (T-166 §2) A point's signed lateral offset (m) off the car's current lane
## line — the line through the pass origin parallel to the leg axis, right
## positive. Legs are grid-axis-aligned, so the offset is one flat projection.
func _lane_local(p: Vector3, axis: Vector3) -> float:
	var rel := p - _pass_origin
	rel.y = 0.0
	return rel.dot(_lane_right(axis))


## (T-166 §2, corridor bounds re-derived per leg by T-179) The shoulder gate
## for one pass side against the lane line through `_pass_origin`. The side
## pairs with the aim it clears (the `_break_hold` multiplier): side +1 is a
## LEFTWARD aim across the LEFT shoulder — the oncoming gate denies while any
## fleet car with an opposing heading (flat forward dot < −0.5) sits ahead of
## the origin within `pass_lookahead` at lane-local lateral < −0.5 (at/over
## the centerline) — a verified-clear oncoming lane is exactly when a real
## overtake crosses, and the corridor band is the leg's REAL asphalt
## ([−(W + L), +(W − L)]): on Lincoln Way the opposing lane rides lane-local
## −13.0, well past the retired Windrow band's −6.5 edge. Side −1 is a
## RIGHTWARD aim across the RIGHT shoulder — the parked gate denies while any
## PARKED-mode fleet car sits ahead within `pass_lookahead` at lane-local
## lateral > +1.0 (the parked band — the graph's curb spots sit +2.45 off the
## lane line on every unclamped width). The in-pass 2.6 m proximity brake
## stays as the floor's last line either way.
func _shoulder_clear(side: int, axis: Vector3) -> bool:
	var right := _lane_right(axis)
	var corridor := _pass_corridor()
	for other in _fleet:
		if other == null or other == self or not is_instance_valid(other):
			continue
		var rel := other.global_position - _pass_origin
		rel.y = 0.0
		var along := rel.dot(axis)
		if along <= 0.0 or along > pass_lookahead:
			continue
		var lat := rel.dot(right)
		if side > 0:
			## LEFT shoulder — the oncoming gate: an opposing car on THIS
			## road's left half (at/over the centerline, out to the far
			## asphalt edge) inside the corridor denies the pass.
			if lat >= corridor.x and lat < -0.5 \
					and other._flat_forward().dot(axis) < -0.5:
				return false
		elif other.mode == Mode.PARKED and lat > 1.0 and lat <= corridor.y:
			## RIGHT shoulder — the parked gate: a parked car in THIS road's
			## band (the row occupies lane-local +1.0..+corridor.y) inside
			## the corridor denies the pass.
			return false
	return true


## (T-166 §4) The force-commit's node-box occupancy check: true when no OTHER
## fleet car sits within `radius` (flat) of `center`. Geometric on purpose —
## it catches committed movements mid-box AND waiting cars that overshot into
## the box (along-axis registration allows up to 3 m in), which a ledger-only
## check would miss.
func _box_clear(center: Vector3, radius: float) -> bool:
	for other in _fleet:
		if other == null or other == self or not is_instance_valid(other):
			continue
		var d := Vector2(other.global_position.x - center.x,
				other.global_position.z - center.z).length()
		if d <= radius:
			return false
	return true


## Ends the pass when the blocker is BEHIND us and we have genuinely moved —
## the ticket's own completion condition — on the 20 m failsafe, or when the
## pass itself has stalled (wedged) for 2 s, which re-arms the clock so the
## next break tries the other shoulder. Nothing stays stuck.
func _update_pass(_delta: float) -> void:
	if not _passing:
		return
	var traveled := Vector2(global_position.x - _pass_origin.x,
			global_position.z - _pass_origin.z).length()
	if traveled > _pass_best + 0.1:
		_pass_best = traveled
		_pass_stall = 0.0
	else:
		_pass_stall += _delta
	var blocker_d := _cached_blocker_dist ## Scan-batched read.
	var behind := blocker_d == INF or blocker_d < 0.5
	if (traveled > 6.0 and behind) or traveled > 20.0 or _pass_stall > 2.0:
		_passing = false
		_pass_stall = 0.0
		_patience = 0.0


## Waypoint-adoption bookkeeping (T-134): ask the spawner for a fresh route
## when the car adopts the waypoint before the path's last one — the deal
## appends from the end node synchronously, so the index never wraps. (The
## block assignment refreshes every frame in `_drive`.)
func _on_waypoint_adopted() -> void:
	if path.size() >= 2 and waypoint_index == path.size() - 2:
		route_exhausted.emit(self)


## Nearest block center to the car (flat, with a 2 m switch margin so the
## mid-road equidistant line can't flip-flop the assignment) — a route car's
## block assignment rides the block it currently drives beside, refreshed
## EVERY physics frame, so it changes BY DRIVING.
func _refresh_block() -> void:
	if _block_centers.is_empty():
		return
	var best_d := INF
	var best := block_center
	for center in _block_centers:
		var d := Vector2(center.x - global_position.x,
				center.z - global_position.z).length_squared()
		if d < best_d:
			best_d = d
			best = center
	if Vector2(best.x - block_center.x, best.z - block_center.z).length() > 2.0:
		block_center = best
		block_changes += 1


## Blinker state machine (T-134 §5): arm the route's next turn's side inside
## `blinker_lead` of its stop line (12 m out ≈ 2 s at cruise — the approach,
## full stop and grant land inside that window), hold the just-driven side
## ~0.5 s after the turn completes, and never arm for straight continuations.
## (T-168) A forced blinker (`set_blinker_forced`) owns the tell while set:
## the arming logic and the post-turn hold clock both pause — the hold keeps
## its remaining seconds for when the override is released — and `blinker`
## reads the forced side every frame.
func _update_blinker(delta: float) -> void:
	_flash_clock += delta
	if blinker_forced != 0:
		blinker = blinker_forced
		return
	if _blinker_hold > 0.0:
		_blinker_hold -= delta
		blinker = _blinker_side
		return
	blinker = 0
	for i in range(_stop_index, stops.size()):
		if stops[i].turn == City.ROUTE_TURN_STRAIGHT:
			continue
		var d := Vector2(stops[i].line.x - global_position.x,
				stops[i].line.z - global_position.z).length()
		if d < blinker_lead:
			blinker = stops[i].turn
		break ## Only the NEXT entry can arm the tell.


## The four amber corner meshes: the armed side's pair flashes at
## `blinker_hz`; everything stays dark at rest. (T-168) A forced blinker
## holds its pair solid-lit instead — staging wants a steady tell, not the
## flash law.
func _apply_blinker_meshes() -> void:
	if blinker_forced != 0:
		_set_blinker_lamps(blinker_forced, true)
		return
	var lit := blinker != 0 and fmod(_flash_clock * blinker_hz, 1.0) < 0.5
	_set_blinker_lamps(blinker, lit)


## One lamp pass: `side`'s pair takes `lit`, the other pair goes dark.
func _set_blinker_lamps(side: int, lit: bool) -> void:
	var left := lit and side < 0
	var right := lit and side > 0
	_blink_fl.visible = left
	_blink_rl.visible = left
	_blink_fr.visible = right
	_blink_rr.visible = right


## (T-168) The `car_blinker` dev verb's entry (CaptureRecorder dispatches it;
## never bypassed): forces the tell to `side` (−1 left / +1 right) held
## solid-lit, or hands control back with 0 — the one-shot lamp write here
## stages parked and frozen cars too (their loops never touch the lamps),
## while a driving car's per-frame `_apply_blinker_meshes` carries the state
## from here on. On release the machine resumes exactly where the override
## paused it: a driving car re-arms off its route within a frame, a parked
## car stays dark.
func set_blinker_forced(side: int) -> void:
	blinker_forced = clampi(side, -1, 1)
	blinker = blinker_forced
	_apply_blinker_meshes()


## (T-162) Seats the four blinker lenses ON the paint body: per corner, the
## closest point on the paint TRIANGLES to a fixed corner seed (point-on-
## triangles, not nearest-vertex — the mesh samples flat quads only at their
## corners, so a vertex-based seat can land between quads), that triangle's
## geometric normal flipped to face the seed (the visible side — the source
## winding is inconsistent: the rear-quarter panel measures raw −x), and the
## node re-positioned so the lens straddles the panel: center = hit point +
## N × (half lens height − `BLINKER_SINK`), box axis-aligned, long axis along
## z. The `cafe_spawner.gd _hair_offset` precedent — a future re-bake of
## `car_paint.res` can never strand the lamps off the body again. Runs once
## per car at `_ready`, zero per-frame cost; the scene's static transforms are
## the measured-surface fallback kept when no triangle exists near a seed.
func _seat_blinkers() -> void:
	var lens := _blink_fl.mesh as BoxMesh
	if lens == null:
		push_warning("Car: BlinkFL mesh is not a BoxMesh — blinker seat derivation skipped")
		return
	var arrays := _body_mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nodes: Array[MeshInstance3D] = [_blink_fl, _blink_fr, _blink_rl, _blink_rr]
	var half_height := lens.size.y * 0.5
	for i in nodes.size():
		var seed_point := BLINKER_SEEDS[i]
		var hit := Vector3.ZERO
		var normal := Vector3.UP
		var best := INF
		for t in range(0, indices.size(), 3):
			var a := verts[indices[t]]
			var b := verts[indices[t + 1]]
			var c := verts[indices[t + 2]]
			var p := _closest_point_on_triangle(seed_point, a, b, c)
			var d := p.distance_squared_to(seed_point)
			if d < best:
				best = d
				hit = p
				normal = (b - a).cross(c - a).normalized()
		if best == INF:
			push_warning("Car: no paint triangle near blinker seed %s — scene transform kept" % seed_point)
			continue
		if normal.dot(seed_point - hit) < 0.0:
			normal = -normal
		nodes[i].position = hit + normal * (half_height - BLINKER_SINK)


## Closest point on the triangle abc to p (Ericson, Real-Time Collision
## Detection §5.1.5) — the seat derivation's surface read.
func _closest_point_on_triangle(p: Vector3, a: Vector3, b: Vector3,
		c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v := d1 / (d1 - d3)
		return a + ab * v
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w := d2 / (d2 - d6)
		return a + ac * w
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w2 := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return b + (c - b) * w2
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)


## The car's flat forward unit vector.
func _flat_forward() -> Vector3:
	var fwd := -transform.basis.z
	fwd.y = 0.0
	return fwd.normalized()


## The CURRENT leg's cruise speed (m/s, before pace): the active stop entry's
## `cruise` — the speed class of the street this leg rides (T-178) — falling
## back past the last entry to its leg's cruise, and to the car's own
## `cruise_speed` when no entry carries one (the Windrow seam, byte-identical).
func _leg_cruise() -> float:
	if _stop_index < stops.size():
		if stops[_stop_index].has("cruise"):
			return float(stops[_stop_index]["cruise"])
	elif not stops.is_empty() and stops[stops.size() - 1].has("cruise"):
		return float(stops[stops.size() - 1]["cruise"])
	return cruise_speed


## Speed cap from the nearest body in the front zone: zero at the follow gap,
## rising with `follow_gain` per metre until cruise. No blocker → cruise.
## Reads the scan-batched `_cached_blocker_dist` (the physics overlap query
## behind `_blocker_distance` is the fleet's hottest per-tick scan).
func _gap_speed(cruise: float) -> float:
	var d := _cached_blocker_dist
	if d == INF:
		return cruise * pace
	return clampf((d - follow_gap) * follow_gain, 0.0, cruise * pace)


## Forward distance to the nearest player·npc·vehicle in the front zone (m),
## INF when the zone is clear. The zone is a box ahead of the bumper, so
## anything it reports is in front or beside us.
func _blocker_distance() -> float:
	var best := INF
	var fwd := _flat_forward()
	for body in _front_zone.get_overlapping_bodies():
		if body == self:
			continue
		var to_body := body.global_position - global_position
		to_body.y = 0.0
		best = minf(best, to_body.dot(fwd))
	return best


## The instance id of the nearest front-zone body (0 when clear) — the pass
## stores it so the proximity brake never halts for the body being passed.
func _nearest_blocker_id() -> int:
	var blocker := _nearest_blocker()
	return blocker.get_instance_id() if blocker != null else 0


## The nearest front-zone body (null when clear).
func _nearest_blocker() -> Object:
	var best := INF
	var best_body: Object = null
	var fwd := _flat_forward()
	for body in _front_zone.get_overlapping_bodies():
		if body == self:
			continue
		var to_body := body.global_position - global_position
		to_body.y = 0.0
		var d := to_body.dot(fwd)
		if d < best:
			best = d
			best_body = body
	return best_body


func _face(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_rate * delta))


## Poop hit (T-006 duck-typed convention): honk and fire the score event.
## Cars don't flee — per pillar 2 they honk, and the drive goes on (the sim
## harness proves it). The stop state rides through untouched. (T-147) Every
## splat also spends the target: `splatted_once` flips AFTER the emit —
## deliberate, see the field's docstring.
func on_splatted(_impact_velocity: Vector3) -> void:
	honk()
	splatted.emit(self)
	## (T-147) AFTER the emit, deliberately — Godot signals are synchronous, so
	## Main's favor gate runs during the line above and reads false exactly on
	## the first splat. Setting this before the emit would silently kill
	## first-splat favor (the `splat_favor_once_per_target` scenario pins it).
	splatted_once = true


## The horn: a bright flash on the body plus the honk itself (T-012 wires the
## audio) — a comedic bike-horn blast from the car's position. Counts on this
## car's OWN `honk_count` only.
func honk() -> void:
	honk_count += 1
	Sfx.play_at("honk", global_position)
	var mat := _body_mesh.material_override as StandardMaterial3D
	if mat == null:
		return
	if _honk_tween != null and _honk_tween.is_valid():
		_honk_tween.kill()
	mat.emission_enabled = true
	mat.emission = HONK_TINT
	mat.emission_energy_multiplier = 1.6
	_honk_tween = create_tween()
	_honk_tween.tween_property(mat, "emission_energy_multiplier", 0.0, honk_flash_seconds)
	_honk_tween.tween_callback(func() -> void: mat.emission_enabled = false)


## Teleport-staged onto a fresh route (spawner, T-134): the same node, a new
## route's open waypoint path plus its stop entries, no allocation. The car is
## placed ON the route's first leg, so waypoint 0 is ahead; yaw snaps onto it.
## Everything the previous life armed dies here: via point, stop state,
## blinker, patience, pass.
func start_route(pos: Vector3, new_path: PackedVector3Array,
		new_stops: Array[Dictionary], new_block: Vector3,
		block_centers: PackedVector3Array, new_end: int) -> void:
	mode = Mode.TRAFFIC
	_release_crumb()
	global_position = pos
	path = new_path
	stops = new_stops
	_stop_index = 0
	block_center = new_block
	block_changes = 0
	_block_centers = block_centers
	route_end_node = new_end
	_has_via = false
	waypoint_index = 0
	blinker = 0
	blinker_forced = 0 ## (T-168 round 1) A re-staged car loses the dev override —
		## an orphaned tell would ride recycles for the whole process and pollute
		## the T-134/T-162 blinker observations. The next driving frame re-applies
		## the (now route-driven) lamps.
	_blinker_side = 0
	_blinker_hold = 0.0
	_passing = false
	_patience = 0.0
	_pass_side = 1
	_pass_best = 0.0
	_pass_stall = 0.0
	_no_progress_breaks = 0
	_progress_accum = 0.0
	_stalled = 0.0
	_prev_pos = pos
	## Decision-batch caches die with the old life too: a re-staged car must
	## not carry the previous street position's blocker distance or crosswalk
	## read into its first ticks on the new route (the next scan refreshes).
	_cached_blocker_dist = INF
	_cached_crosswalk_blocked = false
	_cached_pass_gap = INF
	velocity = Vector3.ZERO
	if traffic != null:
		traffic.release(self)
	_snap_to_waypoint()


## The extension deal (spawner): append the next route's waypoints and stop
## entries onto the live drive, update the OLD end node's provisional straight
## entry with the real turn from the dealt route's first leg (so the blinker
## can arm for the imminent turn), and carry the new end node. No teleport, no
## stop — the car rolls from one route into the next. (T-178) The patch now
## targets the entry the comment always named — the OLD end node's provisional,
## still unresolved at extension time (the car adopts one waypoint before the
## end); the previous new-end match landed on the fresh deal's own last entry,
## which is provisional in its own right and carried the wrong turn until its
## own extension.
func extend_route(path_tail: PackedVector3Array, new_stops: Array[Dictionary],
		turn_at_end: int, new_end: int) -> void:
	path.append_array(path_tail)
	stops.append_array(new_stops)
	var old_end := route_end_node
	route_end_node = new_end
	for i in range(_stop_index, stops.size()):
		if stops[i].node == old_end:
			stops[i].turn = turn_at_end
			break


## Teleport-recycle into a curb space (spawner, T-008): parked cars sit where
## they are put, aligned with the adjacent lane's flow.
## (T-114) Parking anchors the tailgate bread: parked visitor cars re-anchor
## (or drop fresh) through `_redress_crumb` — recycles land the steal surface
## at the new curb, spawner populate drops the first ones.
func park_at(pos: Vector3, yaw: float, new_block: Vector3) -> void:
	mode = Mode.PARKED
	global_position = pos
	rotation = Vector3(0.0, yaw, 0.0)
	velocity = Vector3.ZERO
	path = PackedVector3Array()
	stops = []
	_stop_index = 0
	block_center = new_block
	blinker = 0
	blinker_forced = 0 ## (T-168 round 1) Same de-override as start_route.
	_apply_blinker_meshes() ## Parked cars never tick the lamp pass — go dark now.
	if traffic != null:
		traffic.release(self)
	_redress_crumb()


## (T-114) Anchors this car's tailgate crumb: free the stale one if it still
## exists, then drop a fresh one at the gutter through the bread spawner —
## stamped `Game.favor_steal_visitor`, so eating it books the steal. No-op
## unless the spawner handed over a bread service, this car wears the visitor
## uniform and it is actually parked. Idempotent end to end: the spawner's
## deferred dressing pass only calls it when `tailgate_crumb_alive()` is
## false, so the two paths can never double-drop.
func _redress_crumb() -> void:
	if bread_spawner == null or citizen_class != CitizenClass.Kind.VISITOR \
			or mode != Mode.PARKED:
		return
	_release_crumb()
	_tailgate_crumb = bread_spawner.drop_crumb(to_global(TAILGATE_CRUMB_OFFSET),
			Game.favor_steal_visitor)


## True while the anchored tailgate crumb is a live, un-queued node — a
## queue-freed crumb (released by us, or wiped by the bread spawner's
## populate) does not count as anchored.
func tailgate_crumb_alive() -> bool:
	return _tailgate_crumb != null and is_instance_valid(_tailgate_crumb) \
			and not _tailgate_crumb.is_queued_for_deletion()


## (T-114) Public release for the spawner: frees the anchored tailgate crumb
## and erases it from the bread service's books BEFORE the car itself is
## freed — a queue-freed crumb must never linger in `BreadSpawner._crumbs`.
func release_tailgate() -> void:
	_release_crumb()


## (T-114) Frees the anchored tailgate crumb, if any — the car drove off, or
## is being torn down and must not orphan its bread. The erase through
## `forget_crumb` keeps the spawner's list free of freed nodes.
func _release_crumb() -> void:
	if _tailgate_crumb != null and is_instance_valid(_tailgate_crumb):
		if bread_spawner != null and is_instance_valid(bread_spawner):
			bread_spawner.forget_crumb(_tailgate_crumb)
		_tailgate_crumb.queue_free()
	_tailgate_crumb = null


## (T-114) The crumb lives under the bread spawner, not under this car — any
## teardown releases it so it never outlives its owner. The stop ledger dies
## with the car too: a freed car's waiting/committed entries must never leak.
func _exit_tree() -> void:
	_fleet.erase(self)
	_release_crumb()
	if traffic != null:
		traffic.release(self)


## Adopts the staged route: targets the first waypoint and snaps the yaw onto
## it — a staged or recycled car always begins heading FORWARD along its lane.
func _snap_to_waypoint() -> void:
	if path.size() < 1:
		return
	if path.size() > 1:
		waypoint_index = 0
	var to := path[waypoint_index] - global_position
	to.y = 0.0
	if to.length() > 0.1:
		rotation.y = atan2(-to.x, -to.z)


## Frees one resolved entry's ledger state (committed or patience-passed).
func _finish_entry(entry: Dictionary) -> void:
	if traffic != null:
		traffic.release(self)
	if entry.turn != City.ROUTE_TURN_STRAIGHT:
		_blinker_side = entry.turn
		_blinker_hold = 0.5
	_stop_index += 1

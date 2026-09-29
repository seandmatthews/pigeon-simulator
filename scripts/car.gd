class_name Car
extends CharacterBody3D
## One low-poly city car (T-008): a layer-4 `vehicle` on the road grid. Traffic
## cars loop their home block on the ring-road lane (`City.traffic_loop`) with
## right-hand, right-turn-only corners — the four loops meeting at any
## intersection each cut a disjoint corner, so cross traffic can never meet —
## and brake whenever the front zone (`FrontZone`, masking player · npc ·
## vehicle) is occupied, so cars queue instead of overlapping. Parked cars sit
## at the curb (`City.parking_spots`) and never move. Either mode takes a poop
## splat through the duck-typed `on_splatted` convention (T-006): the car
## honks — a bright body flash until T-012 wires the horn — and fires
## `splatted`, the cheap-points score event (30 base per DESIGN pillar 3) that
## the spawner relays. Getting splatted never derails the drive.

## Fired on every splat this car takes — the spawner relays it (Main's score
## stub adds `points_value` today, T-009's real table later).
signal splatted(car: Car)

## PARKED sits at the curb · TRAFFIC loops its block ring.
enum Mode { PARKED, TRAFFIC }

const BODY_PALETTE: Array[Color] = [
	Color(0.85, 0.25, 0.22), Color(0.24, 0.45, 0.78), Color(0.93, 0.78, 0.25),
	Color(0.92, 0.92, 0.90), Color(0.22, 0.24, 0.26), Color(0.35, 0.62, 0.38),
	Color(0.72, 0.74, 0.78),
]
const HONK_TINT := Color(1.0, 0.85, 0.2)

@export_group("Traffic")
@export var cruise_speed: float = 6.0 ## Lane speed (m/s), before the per-car pace factor.
@export var corner_speed: float = 3.5 ## Speed cap while closing on a corner or still swinging onto the new leg (m/s).
@export var corner_slow_range: float = 7.0 ## Distance (m) to the current corner inside which the corner cap applies.
@export var follow_gap: float = 5.6 ## Stop following at this center-to-center distance to the blocker (m).
@export var follow_gain: float = 1.8 ## How fast the allowed speed grows with the gap to the blocker (1/s).
@export var accel: float = 4.0 ## How fast traffic eases up to cruise speed (m/s²).
@export var brake_decel: float = 12.0 ## How hard traffic brakes behind a blocker (m/s²).
@export var turn_rate: float = 5.0 ## 1/s yaw easing toward the current corner.
@export var waypoint_reach: float = 4.5 ## Distance (m) at which the next corner is adopted — wide, in-quadrant turns.
@export var rejoin_dist: float = 5.0 ## Distance (m) down the new leg of the on-lane rejoin point steered through after each corner.

@export_group("Honk")
@export var points_value: int = 30 ## Base score per splat — cars are the deliberately cheap target (DESIGN pillar 3).
@export var honk_flash_seconds: float = 0.8 ## Seconds the honk flash stays lit before fading.

## Ring-road corner loop (global coords) this car patrols — assigned by the
## spawner. Empty (or PARKED mode) means stand still.
var path: PackedVector3Array = PackedVector3Array()
var waypoint_index: int = 0
var mode: Mode = Mode.TRAFFIC
## Global center of the block whose ring this car serves — the recycle scan
## groups cars by it.
var block_center: Vector3 = Vector3.ZERO
var body_color: Color = BODY_PALETTE[0] ## Assigned by the spawner before _ready.
var pace: float = 1.0 ## Per-car speed factor (0.9–1.15) so traffic spreads out.
## Honks taken so far — evidence for tests and the autoplay DONE line.
var honk_count: int = 0

var _honk_tween: Tween
## On-lane rejoin point just past the corner being rounded — steering through
## it instead of straight at the far corner keeps the car ON its lane; a bare
## far-corner aim lets the corner-exit offset persist until the body scrubs a
## curb or noses into a parking car.
var _via_point := Vector3.ZERO
var _has_via := false

@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _front_zone: Area3D = $FrontZone


func _ready() -> void:
	# Per-car body material: the palette tint and later the honk flash, without
	# touching the shared scene material.
	var mat: StandardMaterial3D = _body_mesh.mesh.surface_get_material(0).duplicate()
	mat.albedo_color = body_color
	_body_mesh.material_override = mat


func _physics_process(delta: float) -> void:
	if mode == Mode.PARKED:
		return ## Parked cars just sit at the curb.
	_drive(delta)


## Lane-follow with stop-if-blocked: the allowed speed shrinks with the gap to
## whatever player·npc·vehicle occupies the front zone, so traffic brakes
## smoothly, queues at ~1 m bumper gaps and CREEPS forward as the gap opens —
## a binary stop/go would pin cars at zero under the intermittent blocks of a
## shuffling queue. The zone only reaches into this car's own lane (a 2 m box
## against a 3 m lane gap), so the disjoint corner cuts of cross traffic never
## brake us.
func _drive(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var target_speed := minf(cruise_speed * pace, _gap_speed())
	if path.size() >= 2:
		var to_target := path[waypoint_index] - global_position
		to_target.y = 0.0
		if to_target.length() < waypoint_reach:
			# Arm the on-lane rejoin point down the new leg, then switch to the
			# next corner.
			var prev := path[(waypoint_index + path.size() - 1) % path.size()]
			var leg := path[waypoint_index] - prev
			leg.y = 0.0
			_via_point = path[waypoint_index] + leg.normalized() * rejoin_dist
			_has_via = true
			waypoint_index = (waypoint_index + 1) % path.size()
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
		_face(aiming / maxf(aiming.length(), 0.001), delta)
		# Corners are taken wide and slow: the cap applies while closing on the
		# corner (or rejoin point) AND until the swing has levelled onto the
		# new leg (yaw still off-target), so the arc never overshoots into the
		# quadrant where a neighbouring loop makes its own turn.
		if aiming.length() < corner_slow_range \
				or absf(angle_difference(rotation.y, atan2(-aiming.x, -aiming.z))) > 0.45:
			target_speed = minf(target_speed, corner_speed)
	var rate := brake_decel if hspeed > target_speed else accel
	hspeed = move_toward(hspeed, target_speed, rate * delta)
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	velocity.x = fwd.x * hspeed
	velocity.z = fwd.z * hspeed
	velocity.y = -2.0 ## Stay glued to the asphalt.
	move_and_slide()


## Speed cap from the nearest body in the front zone: zero at the follow gap,
## rising with `follow_gain` per metre until cruise. No blocker → cruise.
func _gap_speed() -> float:
	var d := _blocker_distance()
	if d == INF:
		return cruise_speed * pace
	return clampf((d - follow_gap) * follow_gain, 0.0, cruise_speed * pace)


## Forward distance to the nearest player·npc·vehicle in the front zone (m),
## INF when the zone is clear. The zone is a box ahead of the bumper, so
## anything it reports is in front or beside us.
func _blocker_distance() -> float:
	var best := INF
	var fwd := -transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for body in _front_zone.get_overlapping_bodies():
		if body == self:
			continue
		var to_body := body.global_position - global_position
		to_body.y = 0.0
		best = minf(best, to_body.dot(fwd))
	return best


func _face(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_rate * delta))


## Poop hit (T-006 duck-typed convention): honk and fire the score event.
## Cars don't flee — per pillar 2 they honk, and the drive goes on (the sim
## harness proves it).
func on_splatted(_impact_velocity: Vector3) -> void:
	honk()
	splatted.emit(self)


## The horn: for now a bright flash on the body — the audio arrives with T-012.
func honk() -> void:
	honk_count += 1
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


## Teleport-recycle onto a new ring loop (spawner, T-008) — the same node, a
## new block, no allocation. Yaw snaps onto the loop so the car never arcs
## across the block while turning around.
func recycle_to(pos: Vector3, new_path: PackedVector3Array, new_block: Vector3) -> void:
	mode = Mode.TRAFFIC
	global_position = pos
	path = new_path
	block_center = new_block
	_retarget_loop()
	velocity = Vector3.ZERO


## Teleport-recycle into a curb space (spawner, T-008): parked cars sit where
## they are put, aligned with the adjacent lane's flow.
func park_at(pos: Vector3, yaw: float, new_block: Vector3) -> void:
	mode = Mode.PARKED
	global_position = pos
	rotation = Vector3(0.0, yaw, 0.0)
	velocity = Vector3.ZERO
	path = PackedVector3Array()
	block_center = new_block


## Adopts the loop leg the car sits on and targets its far corner. Spawning or
## recycling mid-leg must always yield a FORWARD heading: a nearest-corner
## rule would flip the car around whenever it lands just past a corner, and a
## reversed car drives straight into oncoming traffic.
func _retarget_loop() -> void:
	if path.size() < 2:
		return
	var best_d := INF
	var best_leg := 0
	for i in path.size():
		var a := path[i]
		var seg := path[(i + 1) % path.size()] - a
		seg.y = 0.0
		var t := clampf((global_position - a).dot(seg) / maxf(seg.length_squared(), 0.0001),
				0.0, 1.0)
		var d := global_position.distance_squared_to(a + seg * t)
		if d < best_d:
			best_d = d
			best_leg = i
	waypoint_index = (best_leg + 1) % path.size()
	_snap_to_waypoint()


func _snap_to_waypoint() -> void:
	if path.size() < 2:
		return
	var to := path[waypoint_index] - global_position
	to.y = 0.0
	if to.length() > 0.1:
		rotation.y = atan2(-to.x, -to.z)

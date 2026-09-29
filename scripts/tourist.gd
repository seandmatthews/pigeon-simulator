class_name Tourist
extends CharacterBody3D
## One low-poly tourist (T-007): a layer-3 `npc` pedestrian that strolls a
## sidewalk loop (from `City.sidewalk_loop`) in loose groups. The reactions are
## the charm — a poop splat arriving through the duck-typed `on_splatted`
## convention (T-006) triggers a panic: sprint away from where the dropping
## came from, arms up, shirt flushing red, fist shake at the end; a close
## high-speed flyby of the pigeon through the buzz zone earns a flinch duck
## without full panic. Every splat emits `splatted` — the score event the
## spawner relays (T-009 scoring listens later). All tunables are @export.

## Fired on every splat this tourist takes — the spawner relays it into the
## Game autoload's score table (T-009).
signal splatted(tourist: Tourist)

## WALK strolls the loop · PANIC sprints away from a splat · FLINCH ducks a
## buzz while strolling on.
enum Mood { WALK, PANIC, FLINCH }

const SHIRT_PALETTE: Array[Color] = [
	Color(0.86, 0.30, 0.28), Color(0.95, 0.68, 0.20), Color(0.30, 0.55, 0.83),
	Color(0.42, 0.72, 0.40), Color(0.85, 0.45, 0.70), Color(0.92, 0.90, 0.86),
	Color(0.55, 0.35, 0.65), Color(0.20, 0.68, 0.66),
]
const SKIN := Color(0.87, 0.68, 0.55)
const PANIC_TINT := Color(0.92, 0.22, 0.18)

@export_group("Walk")
@export var walk_speed: float = 1.3 ## Stroll speed along the loop (m/s), before the per-tourist pace factor.
@export var walk_turn_rate: float = 7.0 ## 1/s yaw easing toward the current leg.
@export var waypoint_reach: float = 0.7 ## Distance (m) at which the next waypoint is adopted.
@export var bob_rate: float = 9.0 ## Walk bob cycles per second.
@export var bob_height: float = 0.045 ## Walk bob amplitude (m).

@export_group("Panic")
@export var panic_speed: float = 4.2 ## Sprint speed straight away from the splat (m/s).
@export var panic_seconds: float = 2.6 ## How long the panic sprint lasts before the stroll resumes.
@export var panic_bob_scale: float = 2.2 ## Bob-rate multiplier while panicking (frantic steps).
@export var arm_raise_rate: float = 8.0 ## 1/s the arms sweep up when panic starts.
@export var panic_shout_at: float = 0.8 ## Panic seconds left at which the indignant shout plays — together with the fist shake (T-012).

@export_group("Buzz")
@export var buzz_speed: float = 12.0 ## Player speed (m/s) that turns a near miss into a flinch.
@export var buzz_cooldown: float = 2.0 ## Seconds between flinches — one buzz, one duck.
@export var flinch_seconds: float = 0.5 ## Length of the flinch duck.
@export var flinch_squash: float = 0.72 ## Visual Y scale at the bottom of the duck.

## Sidewalk loop (global coords) this tourist patrols — assigned by the
## spawner. Empty means stand still (the sim harness freezes targets with it).
var path: PackedVector3Array = PackedVector3Array()
var waypoint_index: int = 0
var mood: Mood = Mood.WALK
## Global center of the block whose loop this tourist walks — tests and the
## recycle scan group "loose groups" by it.
var block_center: Vector3 = Vector3.ZERO
var shirt_color: Color = SHIRT_PALETTE[0] ## Assigned by the spawner before _ready.
var pace: float = 1.0 ## Per-tourist speed factor (0.85–1.2) so groups walk loosely.
## Flinches taken so far — evidence for tests and the autoplay DONE line.
var buzz_count: int = 0

var _panic_left: float = 0.0
var _panic_dir := Vector3.RIGHT
var _shouted: bool = true ## True except mid-panic — the shout fires once per panic (T-012).
var _flinch_left: float = 0.0
var _buzz_cd: float = 0.0
var _arm_raise: float = 0.0 ## 0 = arms down, 1 = arms up; doubles as the panic tint intensity.
var _phase: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _arm_l: MeshInstance3D = $Visual/ArmL
@onready var _arm_r: MeshInstance3D = $Visual/ArmR
@onready var _buzz_zone: Area3D = $BuzzZone


func _ready() -> void:
	# Per-tourist shirt material: the palette tint and later the panic flush,
	# without touching the shared scene material.
	var mat: StandardMaterial3D = _body_mesh.mesh.surface_get_material(0).duplicate()
	mat.albedo_color = shirt_color
	_body_mesh.material_override = mat
	_arm_l.material_override = mat
	_arm_r.material_override = mat


func _physics_process(delta: float) -> void:
	_buzz_cd = maxf(_buzz_cd - delta, 0.0)
	if _buzz_cd <= 0.0 and mood != Mood.PANIC:
		_check_buzz()
	match mood:
		Mood.PANIC:
			_panic(delta)
		_:
			_walk(delta)
	if mood == Mood.FLINCH:
		_flinch_left -= delta
		if _flinch_left <= 0.0:
			mood = Mood.WALK
	_animate(delta)


## Poop hit (T-006 duck-typed convention): panic away from where the dropping
## came from — the horizontal mirror of its impact velocity — and raise the
## score event for whoever listens. A straight drop has no horizontal mirror,
## so any direction is "away".
func on_splatted(impact_velocity: Vector3) -> void:
	var away := Vector3(-impact_velocity.x, 0.0, -impact_velocity.z)
	if away.length() < 0.5:
		away = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	_panic_dir = away.normalized()
	mood = Mood.PANIC
	_panic_left = panic_seconds
	_shouted = false ## The indignant shout waits for the fist shake (T-012).
	splatted.emit(self)
	Sfx.play_at("yelp", global_position) ## The hit itself earns a yelp (T-012).


## Teleport-recycle onto a new loop (spawner, T-007): the same node, a new
## place — no allocation, and with the spawner's minimum spawn distance no
## pop-in either.
func recycle_to(pos: Vector3, new_path: PackedVector3Array, new_block: Vector3) -> void:
	global_position = pos
	path = new_path
	block_center = new_block
	mood = Mood.WALK
	velocity = Vector3.ZERO
	_panic_left = 0.0
	_flinch_left = 0.0
	_shouted = true
	_retarget_nearest_waypoint()


## Adopts the nearest path point as the current target — after a recycle or a
## panic sprint that left the tourist somewhere mid-loop.
func _retarget_nearest_waypoint() -> void:
	var best := 0
	var best_d := INF
	for i in path.size():
		var d := global_position.distance_squared_to(path[i])
		if d < best_d:
			best_d = d
			best = i
	waypoint_index = best


func _walk(delta: float) -> void:
	if path.size() >= 2:
		var to_target := path[waypoint_index] - global_position
		to_target.y = 0.0
		if to_target.length() < waypoint_reach:
			waypoint_index = (waypoint_index + 1) % path.size()
		else:
			var dir := to_target / to_target.length()
			velocity.x = dir.x * walk_speed * pace
			velocity.z = dir.z * walk_speed * pace
			_face(dir, delta, walk_turn_rate)
	else:
		velocity.x = 0.0 ## No loop (spawner tests freeze targets this way): stand still.
		velocity.z = 0.0
	velocity.y = -2.0 ## Stay glued to the slab.
	move_and_slide()


func _panic(delta: float) -> void:
	_panic_left -= delta
	velocity.x = _panic_dir.x * panic_speed
	velocity.z = _panic_dir.z * panic_speed
	_face(_panic_dir, delta, walk_turn_rate * 1.5)
	velocity.y = -2.0
	move_and_slide()
	if not _shouted and _panic_left <= panic_shout_at:
		_shouted = true
		Sfx.play_at("panic", global_position) ## Shaking the fist, shouting about it (T-012).
	if _panic_left <= 0.0:
		mood = Mood.WALK
		_retarget_nearest_waypoint()


## The pigeon crossing the buzz zone faster than buzz_speed — a near miss, not
## a landing — earns a flinch duck. Panicking tourists are too busy to flinch.
func _check_buzz() -> void:
	for body in _buzz_zone.get_overlapping_bodies():
		if body is Player and body.velocity.length() >= buzz_speed:
			buzz_count += 1
			_buzz_cd = buzz_cooldown
			mood = Mood.FLINCH
			_flinch_left = flinch_seconds
			return


func _face(dir: Vector3, delta: float, rate: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rate * delta))


## Cosmetic layer: the walk bob, the panic lean + arms up + fist shake, the
## flinch duck and the panic flush on the shirt (presentation pass comes later).
func _animate(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var panicking := mood == Mood.PANIC
	if hspeed > 0.2:
		_phase += bob_rate * (panic_bob_scale if panicking else 1.0) * delta
		_visual.position.y = bob_height * sin(_phase)
	else:
		_visual.position.y = move_toward(_visual.position.y, 0.0, bob_height * delta)
	_arm_raise = move_toward(_arm_raise, 1.0 if panicking else 0.0, arm_raise_rate * delta)
	_arm_l.rotation.x = -_arm_raise * 2.4
	_arm_r.rotation.x = -_arm_raise * 2.4
	if panicking and _panic_left < 0.8:
		_arm_r.rotation.x += sin(_phase * 3.0) * 0.6 ## The fist shake.
	_visual.rotation.x = _arm_raise * 0.3 ## Lean into the sprint.
	var duck := flinch_squash if mood == Mood.FLINCH else 1.0
	_visual.scale.y = lerpf(_visual.scale.y, duck, 1.0 - exp(-18.0 * delta))
	var mat := _body_mesh.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = PANIC_TINT if panicking else shirt_color

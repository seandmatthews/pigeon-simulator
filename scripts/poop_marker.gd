class_name PoopMarker
extends Node3D
## The predicted-impact ring for drops (T-046): a flat, unshaded emissive torus
## pinned to the surface an airborne dropping (Poop) is going to hit — the
## bombsight that turns "track a speck" (T-086's ball) into "aim the glide".
## Visual only: no physics nodes of its own, so there is no layer/mask to get
## wrong (the pigeon_visual precedent) and the falling ball can never collide
## with it. track() snapshots the drop ONCE — position, velocity, gravity,
## lifetime — then the marker marches the analytic parabola under the drop's
## own fall_gravity in fixed steps on its first physics frame, casting one
## segment ray per step against the world (layer 1 only — floors, roofs and
## walls all end the march) and seating the ring on the first hit along its
## normal. Each physics frame it polls the drop: when the drop is gone — splat
## or max_lifetime expiry, indistinguishable to a marker and both end-of-job —
## it fades out and frees itself.

@export_group("Ring")
@export var surface_lift: float = 0.03 ## Offset along the hit normal so the ring clears z-fighting (m) — the splat_lift trick, a hair prouder than the decal.
@export var fade_seconds: float = 0.3 ## Seconds the fade-out takes once the drop is gone (splat or expiry).
@export var pulse_amplitude: float = 0.1 ## Ring scale swing while the drop is airborne (±fraction — the gentle pulse).
@export var pulse_hz: float = 2.0 ## Pulse cycles per second while the drop is airborne.

@export_group("Prediction")
@export var march_step: float = 0.05 ## Fixed dt (s) of the analytic parabola march — one segment ray per step.
@export var world_mask: int = 1 ## Collision layers the march ray may hit: the world. Never bodies (player, targets, the drop itself).

## The drop under prediction; dead (freed) drops end the marker's job.
var _drop: Poop
## The track() snapshot — the ring predicts from release conditions, not from
## chasing the ball, so it stays pinned while ball and target move.
var _p0: Vector3 = Vector3.ZERO
var _v0: Vector3 = Vector3.ZERO
var _gravity: float = 12.0
var _max_lifetime: float = 12.0
var _marched := false ## The march is one-shot: first physics frame after track().
var _fading := false ## Set once, when the drop is found gone; the tween owns the rest.
var _pulse_age: float = 0.0 ## Physics-time phase of the pulse — fixed-fps deterministic.

@onready var _ring: MeshInstance3D = %Ring


func _ready() -> void:
	add_to_group("poop_markers") ## Main.restart_run() clears rings still pinned (the poops-group precedent).
	## Per-instance material: every ring fades its own alpha independently
	## (the poop.gd decal pattern).
	var mat := _ring.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	_ring.material_override = mat
	_ring.visible = false ## Hidden until the march finds a surface to pin to.


## Snapshot the drop's release conditions ONCE — call after the marker is in
## the tree. The march itself waits for the marker's first physics frame, the
## one place space queries are legal, so track() from Main's pooped handler
## (mid physics step) and from a test coroutine are the same code path.
func track(drop: Poop) -> void:
	_drop = drop
	_p0 = drop.global_position
	_v0 = drop.linear_velocity
	_gravity = drop.fall_gravity
	_max_lifetime = drop.max_lifetime


func _physics_process(delta: float) -> void:
	if _fading:
		return
	if not is_instance_valid(_drop):
		_start_fade() ## Splat or expiry — the ring's job is done either way.
		return
	if not _marched:
		_march()
	_pulse_age += delta
	var s := 1.0 + pulse_amplitude * sin(_pulse_age * TAU * pulse_hz)
	_ring.scale = Vector3(s, s, s)


## The march: exact parabola points at t and t + march_step (no Euler
## accumulation — every segment endpoint lies ON the analytic arc), one world
## ray per segment, first hit seats the ring. No hit within the drop's
## lifetime (a lob past the city edge) leaves the ring hidden — the honest
## "no predicted ground" answer.
func _march() -> void:
	_marched = true
	var step := maxf(march_step, 0.005) ## A non-positive step would never advance.
	var t := 0.0
	var space := get_world_3d().direct_space_state
	while t < _max_lifetime:
		var t_next := minf(t + step, _max_lifetime)
		var query := PhysicsRayQueryParameters3D.create(
				_point_at(t), _point_at(t_next), world_mask)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			global_transform = Transform3D(_basis_from_normal(normal),
					hit["position"] + normal * surface_lift)
			_ring.visible = true
			return
		t = t_next


## The analytic parabola point at t: p0 + v0·t + ½g·t² straight down.
## Deliberately undamped — the machine leg pins the ring against an independent
## undamped recompute; the live body's default linear_damp lands the real splat
## slightly short of the ring (a Gate 3 eye note, not a code path).
func _point_at(t: float) -> Vector3:
	return _p0 + _v0 * t + Vector3.DOWN * (0.5 * _gravity * t * t)


## Fade the ring out over fade_seconds and free the marker — started exactly
## once, when the drop is found gone; the tween owns everything after.
func _start_fade() -> void:
	_fading = true
	var mat := _ring.material_override as StandardMaterial3D
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, fade_seconds)
	tween.tween_callback(queue_free)


## Deterministic orthonormal basis with +Y along the surface normal — the
## ring's orientation on any wall, roof or floor (the poop.gd decal helper).
func _basis_from_normal(normal: Vector3) -> Basis:
	var helper := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := helper.cross(normal).normalized()
	var z := x.cross(normal).normalized()
	return Basis(x, normal, z)

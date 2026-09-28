class_name Poop
extends RigidBody3D
## One air-dropped dropping (T-006): a layer-6 `projectile` rigid body that
## inherits the pigeon's full velocity on release — a lob, not a raycast — and
## falls under gravity. First contact resolves the hit: the splatted signal
## fires for any listener (T-007/T-008 targets, T-009 scoring), the hit body
## gets a duck-typed `on_splatted(impact_velocity)` call when it implements
## one, and the ball swaps for a splat decal that sticks to the hit face
## (reparented onto the hit body, so later moving targets carry their splats)
## and fades out over fade_seconds. Drops that never hit anything (e.g. past
## the city edge) free themselves after max_lifetime.

## Fired once, on first contact, before the fade starts: `target` is the body
## that was hit, `impact_velocity` the pre-contact velocity of the dropping.
signal splatted(target: Node, impact_velocity: Vector3)

@export_group("Flight")
@export var fall_gravity: float = 12.0 ## Downward accel (m/s²) — matches the flight model's gravity.
@export var max_lifetime: float = 12.0 ## Seconds airborne before a drop that hit nothing frees itself.

@export_group("Splat")
@export var fade_seconds: float = 4.0 ## Seconds the splat stays on the surface before it fades away.
@export var splat_lift: float = 0.02 ## Offset along the hit normal so the decal clears z-fighting (m).

## The decal mesh — reparented onto the hit body when the splat sticks. Public
## so the sim harness can assert where it landed and how it fades.
@onready var splat_mesh: MeshInstance3D = $SplatMesh

var _spent: bool = false
var _age: float = 0.0
var _last_velocity: Vector3 = Vector3.ZERO ## Velocity entering the current physics step.
var _has_contact: bool = false
var _hit_point: Vector3
var _hit_normal: Vector3

@onready var _ball_mesh: MeshInstance3D = $BallMesh
@onready var _shape: CollisionShape3D = $BallShape


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	gravity_scale = fall_gravity / float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	# Per-instance material: every splat fades its own alpha independently.
	var mat: StandardMaterial3D = splat_mesh.mesh.surface_get_material(0).duplicate()
	splat_mesh.material_override = mat
	splat_mesh.visible = false


func _physics_process(delta: float) -> void:
	_age += delta
	_last_velocity = linear_velocity ## Pre-integration snapshot — the honest impact velocity.
	if _age >= max_lifetime:
		queue_free()


## Contacts are captured during the physics step (world-space point and
## normal); the body_entered flush afterwards resolves the hit with them.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _spent or _has_contact or state.get_contact_count() == 0:
		return
	_hit_point = state.get_contact_collider_position(0)
	_hit_normal = state.get_contact_local_normal(0)
	_has_contact = true


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	_spent = true
	splatted.emit(body, _last_velocity)
	if body.has_method("on_splatted"):
		body.on_splatted(_last_velocity)
	_stick_splat(body)


## Freezes the ball, swaps it for the decal stuck to the hit face, hands the
## fade to the decal's own tween and frees the rigid body — the splat then
## lives on the hit body alone until it has faded away.
func _stick_splat(target: Node) -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	_shape.set_deferred("disabled", true)
	_ball_mesh.visible = false
	var normal := _hit_normal.normalized() if _has_contact and _hit_normal.length() > 0.5 else Vector3.UP
	var point := _hit_point if _has_contact else global_position
	splat_mesh.global_transform = Transform3D(_basis_from_normal(normal), point + normal * splat_lift)
	splat_mesh.visible = true
	if target is Node3D:
		splat_mesh.reparent(target)
	var mat := splat_mesh.material_override as StandardMaterial3D
	var tween := splat_mesh.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, fade_seconds)
	tween.tween_callback(splat_mesh.queue_free)
	queue_free()


## Deterministic orthonormal basis with +Y along the surface normal — the
## decal's orientation on any wall, roof or floor.
func _basis_from_normal(normal: Vector3) -> Basis:
	var helper := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := helper.cross(normal).normalized()
	var z := x.cross(normal).normalized()
	return Basis(x, normal, z)

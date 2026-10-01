class_name Elder
extends StaticBody3D
## One seated park elder (T-020): a static layer-3 `npc` grandparent on a
## plaza bench, built from the same hand-placed low-poly primitives as the
## tourist (T-007). A PresenceZone around the bench watches for the pigeon
## (layer 2): a GROUNDED pigeon inside it (the bread crumb's land-and-peck
## rule, T-005) fills `_trust` at 1.0/s; with nobody present it decays — a
## fly-through banks nothing, a brief walk-away doesn't wipe progress. At
## `trust_needed` the elder shares: `crumbs_per_share` ordinary T-005 crumbs
## tossed to the pavement in front of them through
## `BreadSpawner.drop_crumb()`, then a long `share_cooldown` — a friend, not
## an infinite buffet. One cosmetic beat: the near arm raises while sharing.
## Elders don't walk and don't react to splats or buzzes (that is still the
## tourists' job).

## Fired on every share — the spawner relays it as `bread_shared` (the
## CaptureRecorder's `elder_bread_shared` event listens there).
signal shared(elder: Elder, crumbs: int)

## Muted cardigan colors — the spawner assigns one per elder by index, so
## four elders around the ring read as four different grandparents with no
## RNG anywhere.
const CARDIGAN_PALETTE: Array[Color] = [
	Color(0.42, 0.55, 0.52), ## Faded teal.
	Color(0.62, 0.48, 0.38), ## Warm tan.
	Color(0.70, 0.35, 0.26), ## Warm rust (T-048) — the old dusty lilac sat 0.12 from the sidewalk gray and plaza elders washed out at range.
	Color(0.48, 0.52, 0.42), ## Sage.
]
const SKIN := Color(0.87, 0.68, 0.55) ## Same skin family as the tourists (T-007).
const HAIR := Color(0.78, 0.78, 0.75) ## Gray/white hair — the elder giveaway.
const SEAT_HEIGHT := 0.60 ## Bench seat top above the slab — the `_add_bench` math.
const CRUMB_LIFT := 0.06 ## Tossed crumbs rest at the same height as bread-spot ring crumbs.

@export_group("Trust")
@export var proximity_radius: float = 3.0 ## PresenceZone radius (m) around the bench.
@export var trust_fill_rate: float = 1.0 ## Trust per second while a GROUNDED pigeon is present.
@export var trust_decay: float = 2.0 ## Trust per second while nobody is present.
@export var trust_needed: float = 4.0 ## Seconds of company before the elder shares.

@export_group("Sharing")
@export var crumbs_per_share: int = 2 ## Ordinary T-005 crumbs tossed per share.
@export var toss_distance: float = 1.2 ## Forward distance (m) from the elder the crumbs land at.
@export var toss_spread: float = 0.4 ## Sideways spread (m) — crumbs alternate left/right of the facing line.
@export var share_cooldown: float = 25.0 ## Seconds the elder ignores the pigeon after sharing.

@export_group("Beat")
@export var arm_raise_seconds: float = 0.5 ## How long the near arm stays up after a share.
@export var arm_raise_rate: float = 8.0 ## 1/s the arm sweeps up and back down.

## Cardigan tint — the spawner assigns it before _ready (index-based, no RNG).
var cardigan_color: Color = CARDIGAN_PALETTE[0]
## The bread service the tossed crumbs come from — the spawner assigns it.
var bread_spawner: BreadSpawner

## Shares so far this run — the spawner relays and the autoplay DONE line reports it.
var share_count: int = 0

var _trust: float = 0.0
var _cooldown_left: float = 0.0
var _arm_left: float = 0.0
var _arm_raise: float = 0.0 ## 0 = arm down, 1 = arm up.

@onready var _zone: Area3D = $PresenceZone
@onready var _zone_shape: CollisionShape3D = $PresenceZone/Shape
@onready var _torso: MeshInstance3D = $Visual/Torso
@onready var _cane: MeshInstance3D = $Visual/Cane
@onready var _arm_near: MeshInstance3D = $Visual/ArmNear
@onready var _arm_far: MeshInstance3D = $Visual/ArmFar


func _ready() -> void:
	(_zone_shape.shape as SphereShape3D).radius = proximity_radius
	## The hunched pose and the leaning cane — rotations live in script so the
	## scene file stays free of hand-computed basis matrices.
	_torso.rotation.x = 0.18
	_cane.rotation.z = -0.08
	## Per-elder cardigan material: the palette tint, without touching the
	## shared scene material (the tourist's pattern).
	var mat: StandardMaterial3D = _torso.mesh.surface_get_material(0).duplicate()
	mat.albedo_color = cardigan_color
	_torso.material_override = mat
	_arm_near.material_override = mat
	_arm_far.material_override = mat


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _pigeon_present():
		_trust = minf(_trust + trust_fill_rate * delta, trust_needed)
		if _trust >= trust_needed and _cooldown_left <= 0.0:
			_share()
	else:
		_trust = maxf(_trust - trust_decay * delta, 0.0)
	_animate(delta)


## A GROUNDED pigeon inside the PresenceZone — the same land-and-peck rule
## the bread crumbs use (T-005): a fly-through is not company.
func _pigeon_present() -> bool:
	for body in _zone.get_overlapping_bodies():
		if body is Player and body.is_grounded:
			return true
	return false


## Trust paid off: toss `crumbs_per_share` ordinary crumbs to the pavement in
## front of the elder's facing (alternating sideways, so two crumbs read as a
## small scatter, not a stack), then go quiet for `share_cooldown`.
func _share() -> void:
	_cooldown_left = share_cooldown
	_trust = 0.0
	_arm_left = arm_raise_seconds
	share_count += 1
	if bread_spawner == null:
		push_warning("Elder has no BreadSpawner — the shared bread is lost.")
		shared.emit(self, 0)
		return
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var ground_y := global_position.y - SEAT_HEIGHT + CRUMB_LIFT
	for i in crumbs_per_share:
		var side := toss_spread if i % 2 == 0 else -toss_spread
		var pos := global_position + forward * toss_distance + right * side
		pos.y = ground_y
		bread_spawner.drop_crumb(pos)
	shared.emit(self, crumbs_per_share)


## Cosmetic layer: the near arm sweeps up for the share beat, then settles.
func _animate(delta: float) -> void:
	if _arm_left > 0.0:
		_arm_left -= delta
	_arm_raise = move_toward(_arm_raise, 1.0 if _arm_left > 0.0 else 0.0,
			arm_raise_rate * delta)
	_arm_near.rotation.x = -_arm_raise * 2.2

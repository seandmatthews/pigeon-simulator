class_name Butterfly
extends Node3D
## One ambient butterfly of the Reiman Gardens entrance beds (T-204) — the
## wing-exhibit read of `images/nature/13` (the survey's own accent-prop
## reference, pass-2 note). DRESSING, NOT A SYSTEM: a tiny count (8, the
## ticket's ≤ 12 cap) hovers the garden beds the way the swans circle the
## lake — nothing reads it, nothing spawns from it, nothing scores it.
##
## The rig is this script's own primitive build at accent scale (~10 cm of
## wing): an amber-forewing pair on two live pivots (the flap), a dark
## body/caber between them. It is deliberately NOT the T-138 people rig and
## carries nothing the T-165 gait law touches — no imported clips, no
## AnimationPlayer, no citizen machinery.
##
## The scope guard is structural, the swan's law verbatim: the butterfly owns
## NO physics body and NO area — collision_layer stays 0, the pigeon flies
## through it, a dropping falls past it. Not perchable, not splat-able, not
## bread-able; it yields to everything.

## --- presentation (the nature/13 macro read: amber forewing, dark body) -----

const COLOR_WING := Color(0.851, 0.541, 0.169) ## #D98A2B monarch amber.
const COLOR_WING_EDGE := Color(0.30, 0.16, 0.08) ## The dark veins/edge band.
const COLOR_BODY := Color(0.16, 0.12, 0.10) ## Dark body + antennae.

## Accent scale (m): the wingspan read of the photo — a painted lady at arm's
## length, not a system-scale animal.
const WING_SIZE := Vector2(0.16, 0.11)
const BODY_SIZE := Vector3(0.028, 0.028, 0.14)

## --- motion (the ambient read; all time-based, zero RNG of any stream) ------

## The hover wander: a slow drift circle around the home position.
const WANDER_RATE := 0.35 ## Circuits per second — a lazy garden drift.
const WANDER_RADIUS := 0.9 ## m around the home point.
## The hover bob riding the wander: gentle vertical breathing.
const BOB_RATE := 1.1
const BOB_AMP := 0.12
## The flap: wing-pivot z-rock rate and amplitude — a fast shiver, slower at
## the rest fraction of each stroke (the sine's own shape gives that free).
const FLAP_RATE := 11.0
const FLAP_AMP := 1.05 ## rad — near-vertical stroke tips.

## Start offset around the wander circle and the clocks, as fractions [0, 1).
@export var phase: float = 0.0
## The flap/idle clock offset — the eight never shiver in sync.
@export var flap_phase: float = 0.0

## The home position (world-local XZ, y = hover mid). The parent is the
## world root, the pack frame. Set by the world BEFORE the node enters the
## tree; the wander circles it.
var home: Vector3 = Vector3.ZERO

## The live wing pivots (the gate samples nothing on them — the count and
## the no-collision law are the whole contract — but the flap drives them).
var wing_l: Node3D
var wing_r: Node3D

var _clock: float = 0.0


func _ready() -> void:
	_build_visual()
	var a := TAU * fposmod(phase, 1.0)
	position = home + Vector3(cos(a) * WANDER_RADIUS, 0.0, sin(a) * WANDER_RADIUS)
	_clock = TAU * fposmod(flap_phase, 1.0) / TAU


func _process(delta: float) -> void:
	_clock += delta
	## The drift circle around the home bed.
	var a := TAU * fposmod(phase, 1.0) + TAU * WANDER_RATE * _clock
	position = home + Vector3(
			cos(a) * WANDER_RADIUS,
			sin(_clock * TAU * BOB_RATE) * BOB_AMP,
			sin(a) * WANDER_RADIUS)
	## Face along the drift.
	rotation.y = atan2(-cos(a), -sin(a))
	## The flap: mirrored z-rock on the two pivots.
	var flap := sin(_clock * TAU * FLAP_RATE) * FLAP_AMP
	wing_l.rotation = Vector3(0.0, 0.0, flap)
	wing_r.rotation = Vector3(0.0, 0.0, -flap)


## --- the primitive rig (the nature/13 accent read) -------------------------


func _build_visual() -> void:
	var wing := StandardMaterial3D.new()
	wing.albedo_color = COLOR_WING
	wing.roughness = 0.8
	var edge := StandardMaterial3D.new()
	edge.albedo_color = COLOR_WING_EDGE
	edge.roughness = 0.8
	var body := StandardMaterial3D.new()
	body.albedo_color = COLOR_BODY
	body.roughness = 0.8
	_body_part(body, BODY_SIZE, Vector3.ZERO) ## Caber.
	_body_part(body, Vector3(0.02, 0.02, 0.03), Vector3(0.0, 0.012, -0.085)) ## Head.
	wing_l = _wing_pivot(wing, edge, 1.0)
	wing_r = _wing_pivot(wing, edge, -1.0)


## One body part: a scaled box at `pos` (the caber and the head bead).
func _body_part(mat: StandardMaterial3D, size: Vector3, pos: Vector3) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	part.mesh = mesh
	part.position = pos
	add_child(part)


## One wing: a pivot at the body's flank (`side` ±1) carrying a forewing quad
## (the amber face) and a narrow edge band behind it, both double-sided.
func _wing_pivot(wing_mat: StandardMaterial3D, edge_mat: StandardMaterial3D,
		side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.014 * side, 0.0, -0.02)
	add_child(pivot)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = WING_SIZE
	quad.orientation = PlaneMesh.FACE_Z ## The card faces ±Z; the flap rocks it.
	quad.material = wing_mat
	face.mesh = quad
	face.position = Vector3(0.0, 0.0, 0.055 * side)
	face.rotation = Vector3(0.0, 0.0, -0.12 * side) ## The resting backward sweep.
	pivot.add_child(face)
	var tip := MeshInstance3D.new()
	var band := QuadMesh.new()
	band.size = Vector2(WING_SIZE.x, WING_SIZE.y * 0.22)
	band.orientation = PlaneMesh.FACE_Z
	band.material = edge_mat
	tip.mesh = band
	tip.position = Vector3(0.0, 0.0, 0.055 * side + 0.004 * side)
	tip.rotation = Vector3(0.0, 0.0, -0.12 * side)
	pivot.add_child(tip)
	return pivot

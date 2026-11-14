class_name Swan
extends Node3D
## One ambient mute swan of Lake LaVerne (T-185) — Lancelot and Elaine, the
## town's beloveds restored (TRADITIONS §2; owner fork 2026-11-09, master plan
## §11.3: AMBIENT ONLY). The bird swims a closed circuit the world hands it
## (`AmesWorld.swan_circuit`, derived from the lake it must never leave — the
## probe-pinned 27 m round in the wide south basin), bobs on its own wake as
## it paddles, and rustles a slow wing-tuck idle on a per-bird offset clock.
##
## The rig is this script's own primitive build (the §1.2 mute-swan read at
## 1:1 scale: white #F4F2EC body over an S-neck with the black basal knob and
## the orange bill, wings folded flat on two live pivots). It is deliberately
## NOT the T-138 people rig and carries nothing the T-165 gait law touches —
## no imported clips, no AnimationPlayer, no citizen machinery.
##
## The scope guard is structural: the swan owns NO physics body and NO area —
## collision_layer stays 0, the pigeon flies through it, a dropping falls past
## it. Not perchable, not splat-able, not bread-able; it yields to everything.

## The water flat's baked top (the baker's y-stack law — the swan floats ON it).
const WATER_TOP := 0.02

## --- presentation (MODELING-SPECS §1.2 palette) -----------------------------

const COLOR_PLUMAGE := Color(0.957, 0.949, 0.925) ## #F4F2EC swan white.
const COLOR_BILL := Color(0.90, 0.55, 0.15) ## Mute-swan orange bill.
const COLOR_KNOB := Color(0.09, 0.09, 0.09) ## The black basal knob + mask.

## --- motion (the ambient read; all time-based, zero RNG of any stream) ------

## Paddle pace (m/s) — a mute swan's unhurried cruise.
@export var speed: float = 0.8
## Start position around the circuit, as an arc fraction [0, 1).
@export var phase: float = 0.0
## The idle clock offset (s) — the two birds do not rustle in sync.
@export var tuck_phase: float = 0.0

## The closed loop this bird swims (world-local XZ at the water top; the
## parent is the world root, the pack frame). Set by the world BEFORE the
## node enters the tree.
var circuit: PackedVector3Array = PackedVector3Array()

## Wake bob: cycles per second and amplitude (m) — a gentle paddle rock.
const BOB_RATE := 0.9
const BOB_AMP := 0.025
## Hull roll wobble (rad) riding the same wake, out of phase with the bob.
const ROLL_RATE := 0.6
const ROLL_AMP := 0.03

## The wing-tuck idle: once every TUCK_PERIOD seconds the folded wings ease
## tighter against the body (pivot chord squeeze + a small lift) and settle
## back. The wave is a smooth bump over the first TUCK_HOLD fraction.
const TUCK_PERIOD := 9.0
const TUCK_HOLD := 0.55 ## Fraction of the period the rustle occupies.
const TUCK_SQUEEZE := 0.82 ## Wing pivot Z scale at the tuck's deepest.
const TUCK_LIFT := 0.14 ## Wing pivot lift (rad) at the tuck's deepest.

## The live wing pivots (the gate samples their bases across time to prove
## the idle moves the fold) — built in `_build_visual`.
var wing_l: Node3D
var wing_r: Node3D

## Internal clock and arc-table state.
var _clock: float = 0.0
var _arc: float = 0.0
var _total: float = 0.0
var _cum: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_build_visual()
	_build_arc_table()
	_arc = fposmod(phase, 1.0) * _total
	if circuit.size() >= 2:
		var p := _point_at(_arc)
		position = Vector3(p.x, WATER_TOP, p.z)


func _physics_process(delta: float) -> void:
	_clock += delta
	if _total <= 0.0:
		return
	## Advance along the circuit at the paddle pace, then place the hull.
	_arc = fposmod(_arc + speed * delta, _total)
	var p := _point_at(_arc)
	var dir := _dir_at(_arc)
	var bob := sin(_clock * TAU * BOB_RATE) * BOB_AMP
	position = Vector3(p.x, WATER_TOP + bob, p.z)
	## The tourist's own heading law (−Z forward), plus the wake roll.
	rotation = Vector3(
		0.0, atan2(-dir.x, -dir.y), sin(_clock * TAU * ROLL_RATE) * ROLL_AMP)
	_drive_wing_tuck()


## The wing-tuck idle wave: 0 at rest → 1 at the deepest fold → back, once
## per period, offset by this bird's `tuck_phase`. Smoothstep in and out so
## the rustle never snaps.
func _tuck_wave() -> float:
	var t := fposmod(_clock / TUCK_PERIOD + tuck_phase, 1.0)
	if t > TUCK_HOLD:
		return 0.0
	var half := TUCK_HOLD * 0.5
	if t < half:
		return smoothstep(0.0, half, t)
	return 1.0 - smoothstep(half, TUCK_HOLD, t)


func _drive_wing_tuck() -> void:
	var w := _tuck_wave()
	var lift := TUCK_LIFT * w
	wing_l.rotation = Vector3(0.0, 0.0, lift)
	wing_r.rotation = Vector3(0.0, 0.0, -lift)
	var squeeze := 1.0 - (1.0 - TUCK_SQUEEZE) * w
	wing_l.scale = Vector3(1.0, 1.0, squeeze)
	wing_r.scale = Vector3(1.0, 1.0, squeeze)


## --- the primitive rig (the §1.2 mute-swan read) ---------------------------


func _build_visual() -> void:
	var plumage := StandardMaterial3D.new()
	plumage.albedo_color = COLOR_PLUMAGE
	plumage.roughness = 0.9
	var bill := StandardMaterial3D.new()
	bill.albedo_color = COLOR_BILL
	bill.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = COLOR_KNOB
	dark.roughness = 0.8
	_body_part(plumage, Vector3(0.52, 0.44, 1.2), Vector3(0.0, 0.22, 0.0)) ## Hull.
	_body_part(plumage, Vector3(0.18, 0.10, 0.3), Vector3(0.0, 0.30, 0.62)) ## Tail.
	_body_part(bill, Vector3(0.045, 0.05, 0.16), Vector3(0.0, 0.86, -0.30)) ## Bill.
	_body_part(dark, Vector3(0.07, 0.07, 0.07), Vector3(0.0, 0.895, -0.345)) ## Knob.
	## The S-neck: five shrinking beads from the hull's front up to the head.
	var neck := [Vector3(0.0, 0.34, -0.50), Vector3(0.0, 0.50, -0.56),
			Vector3(0.0, 0.64, -0.56), Vector3(0.0, 0.75, -0.51),
			Vector3(0.0, 0.83, -0.44)]
	var neck_r := [0.075, 0.07, 0.065, 0.06, 0.055]
	for i: int in neck.size():
		var r: float = neck_r[i]
		_body_part(plumage, Vector3(r * 2.0, r * 2.0, r * 2.0), neck[i])
	_body_part(plumage, Vector3(0.14, 0.14, 0.15), Vector3(0.0, 0.88, -0.38)) ## Head.
	## The folded wings: two live pivots off the hull's flanks, each carrying
	## one flattened plumage shell lying along the body (the tucked read).
	wing_l = _wing_pivot(plumage, 1.0)
	wing_r = _wing_pivot(plumage, -1.0)


## One hull part: a scaled sphere shell at `pos` (the S-neck and head are the
## same primitive at bead sizes).
func _body_part(mat: StandardMaterial3D, size: Vector3, pos: Vector3) -> void:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = mat
	part.mesh = mesh
	part.scale = size
	part.position = pos
	add_child(part)


## One folded wing: a pivot on the hull's flank (`side` ±1) carrying a
## flattened shell that lies along the body, tipped slightly outward.
func _wing_pivot(mat: StandardMaterial3D, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.26 * side, 0.36, 0.05)
	add_child(pivot)
	var shell := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = mat
	shell.mesh = mesh
	shell.scale = Vector3(0.11, 0.14, 0.62)
	shell.position = Vector3(0.05 * side, 0.02, -0.05)
	shell.rotation = Vector3(0.0, 0.0, -0.06 * side) ## Tips the fold outward.
	pivot.add_child(shell)
	return pivot


## --- the arc table (uniform-speed travel along the closed loop) ------------


func _build_arc_table() -> void:
	_cum = PackedFloat32Array()
	_total = 0.0
	var n := circuit.size()
	_cum.resize(n + 1)
	_cum[0] = 0.0
	for i: int in n:
		var a := circuit[i]
		var b := circuit[(i + 1) % n]
		_total += Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		_cum[i + 1] = _total


## The circuit point at arc distance `s` (wraps at the loop's total length).
func _point_at(s: float) -> Vector3:
	var n := circuit.size()
	if n < 2:
		return circuit[0] if n > 0 else Vector3.ZERO
	var target := clampf(s, 0.0, _total)
	var lo := 0
	var hi := n ## _cum has n+1 entries; the last equals _total.
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _cum[mid + 1] < target:
			lo = mid + 1
		else:
			hi = mid
	lo = mini(lo, n - 1)
	var seg_start := circuit[lo]
	var seg_end := circuit[(lo + 1) % n]
	var seg := _cum[lo + 1] - _cum[lo]
	var t := 0.0 if seg <= 0.0 else (target - _cum[lo]) / seg
	return Vector3(
		lerpf(seg_start.x, seg_end.x, t), WATER_TOP, lerpf(seg_start.z, seg_end.z, t))


## The unit travel direction at arc distance `s` (the segment's tangent).
func _dir_at(s: float) -> Vector2:
	var n := circuit.size()
	if n < 2:
		return Vector2(0.0, -1.0)
	var target := clampf(s, 0.0, _total)
	var lo := 0
	var hi := n
	while lo < hi:
		var mid := (lo + hi) >> 1
		if _cum[mid + 1] < target:
			lo = mid + 1
		else:
			hi = mid
	lo = mini(lo, n - 1)
	var seg_start := circuit[lo]
	var seg_end := circuit[(lo + 1) % n]
	var d := Vector2(seg_end.x - seg_start.x, seg_end.z - seg_start.z)
	return d.normalized() if d.length_squared() > 1e-12 else Vector2(0.0, -1.0)

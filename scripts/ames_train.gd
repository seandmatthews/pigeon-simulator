class_name AmesTrain
extends Node3D
## The daily coal drag (T-194) — the town's motion landmark: a yellow
## SD70ACe-led UP consist (photo `rail/07`'s EB drag — weathered yellow #
## D9A02C body, dark roof/frame, the blue-white winged shield as painted
## geometry, a chain of brown-gray coal hoppers) running the chained south
## track of the Clinton Subdivision on a LOOP-TIMER schedule. A timer, not a
## simulation: the world hands the route (the greedy west→east chain of the
## pack's 26 main-line ways, this script extends it off-map both ends so the
## consist enters and exits fully), the schedule is two pinned constants
## (period + speed — the daily-traffic compression; the line's tagged
## 70-mph class), and the consist advances its arc every physics tick.
##
## The scope guard is structural (the ticket's fence — "the train is dressing
## that moves"): the rig owns NO physics body and NO area — collision_layer
## stays 0, cars cross regardless, the pigeon flies through it; no event
## system, no traffic gating, no signals into the traffic graph. The part
## schedule and the extended route are retained for the gate (headless runs
## cannot read MultiMesh instances back).
##
## The rig is this script's own primitive build (massing level — the T-175
## placeholder vocabulary at motion scale): one unit-box MultiMesh, per-box
## vertex colors, every box re-anchored onto the route arc each tick (the
## consist bends through the line's curves). Zero RNG of any stream.

## --- the loop schedule (the ticket's pinned constants) ----------------------

## The daily-traffic compression: one drag every 6 wall-minutes (the refs'
## "daily traffic = manifests and coal drags" read — a handful a day, so a
## typical run sees one to three passes; recorded in the ticket).
const RUN_PERIOD_S := 360.0
## The line's tagged 70-mph class (MODELING-SPECS §1.8): 70 mph = 31.29 m/s.
const RUN_SPEED_MPS := 31.3
## The first pass starts this long after the build (a short session still
## catches a drag).
const RUN_START_DELAY_S := 25.0
## The off-map run-out past each end of the core route (m): the whole
## consist clears the chain before the run ends, and enters from fully
## outside the core window.
const EXIT_CLEAR := 60.0

## --- the consist (photo 07's massing read; real-unit dims) ------------------

const LOCO_LEN := 22.4 ## SD70ACe length (m).
const LOCO_WIDTH := 3.15
const LOCO_HEIGHT := 4.9 ## Above rail head.
const HOPPER_LEN := 15.9 ## The Bethgon coal porter's length.
const HOPPER_WIDTH := 3.4
const HOPPER_COUNT := 12 ## A readable drag, not the real 100+ (the game read).
const COUPLER_GAP := 1.2 ## Between consecutive cars.
const HOPPER_PITCH := HOPPER_LEN + COUPLER_GAP

## Palette (§1.8's rail-corridor rows + the photo reads pinned here).
const LOCO_YELLOW := Color(0.851, 0.627, 0.173) ## #D9A02C the weathered yellow row.
const LOCO_DARK := Color(0.27, 0.25, 0.23) ## The roof/frame/underbody read.
const LOCO_GLASS := Color(0.09, 0.10, 0.12) ## The cab glass band.
const SHIELD_WHITE := Color(0.910, 0.902, 0.878) ## #E8E6E0 the shield field row.
const SHIELD_BLUE := Color(0.110, 0.247, 0.580) ## #1C3F94 the winged-shield blue row.
const HOPPER_GRAY := Color(0.420, 0.396, 0.361) ## #6B655C the coal hoppers row.
const COAL_DARK := Color(0.17, 0.16, 0.15) ## The loaded heap read.

## The retained schedule the gate walks: every consist box —
## `{band, off, y, z, s, color}` in the consist's local frame (+x = forward
## toward the nose, y above rail head, z across).
var part_schedule: Array[Dictionary] = []
## The extended route this consist rides (core chain + the off-map run-outs),
## retained for the gate's motion arm.
var extended_route: PackedVector3Array = PackedVector3Array()
## The loop clock (s). Advanced by `_physics_process`; the gate drives it
## directly to stage the consist (the no-gating probe parks it mid-crossing).
var clock: float = 0.0

var _mm: MultiMesh
var _seg_lens: PackedFloat32Array = PackedFloat32Array()
var _total := 0.0


## The full consist span behind the loco center (m): front half-loco + the
## hopper chain's tail.
func consist_length() -> float:
	return LOCO_LEN * 0.5 + float(HOPPER_COUNT) * HOPPER_PITCH


## The consist's box count (the render MM's instance count).
func consist_boxes() -> int:
	return part_schedule.size()


## The whole run's length (the extended route).
func route_length() -> float:
	return _total


## The traversable span (m): the run starts with the tail at arc 0 and ends
## when the nose tip reaches the far end.
func traverse_span() -> float:
	return _total - consist_length()


## The traverse time at the pinned speed (s).
func traverse_time() -> float:
	return traverse_span() / RUN_SPEED_MPS


## The pure schedule: the state at clock t — `{visible, nose_arc}` (the loco
## center's arc along the extended route). Hidden before the first pass and
## through the gap between passes; the run occupies the traverse window of
## each period.
func state_at(t: float) -> Dictionary:
	var tt := t - RUN_START_DELAY_S
	if tt < 0.0:
		return {"visible": false, "nose_arc": consist_length() - LOCO_LEN * 0.5}
	var c := fposmod(tt, RUN_PERIOD_S)
	if c > traverse_time():
		return {"visible": false, "nose_arc": consist_length() - LOCO_LEN * 0.5}
	return {"visible": true, "nose_arc": consist_length() - LOCO_LEN * 0.5 \
			+ c * RUN_SPEED_MPS}


## Builds the consist + the route bookkeeping. `core_route` is the world's
## chained track (y = the rail head); this extends it off-map both ends
## (straight along the end segments) so the consist enters and exits whole.
func setup(core_route: PackedVector3Array) -> void:
	extended_route = _extend_route(core_route)
	_seg_lens.clear()
	_total = 0.0
	for i in extended_route.size() - 1:
		var seg := (extended_route[i + 1] as Vector3).distance_to(extended_route[i])
		_seg_lens.append(seg)
		_total += seg
	_build_schedule()
	_build_rig()


func _physics_process(delta: float) -> void:
	clock += delta
	_apply()


## Re-anchors every consist box onto the route at the current clock.
func _apply() -> void:
	if _mm == null or extended_route.size() < 2:
		return
	_apply_state(state_at(clock))


## One schedule state onto the rig: visibility + every box's route anchor.
func _apply_state(st: Dictionary) -> void:
	visible = bool(st["visible"])
	if not visible:
		return
	var nose: float = st["nose_arc"]
	for i in part_schedule.size():
		var part: Dictionary = part_schedule[i]
		var arc: float = nose - float(part["off"])
		var pt := _point_at(arc)
		var yaw := atan2(-pt["dir"].z, pt["dir"].x) ## +x-local = forward.
		var basis := Basis(Vector3.UP, yaw)
		var off := basis * Vector3(0.0, float(part["y"]), float(part["z"]))
		_mm.set_instance_transform(i, Transform3D(
				basis * Basis.from_scale(part["s"] as Vector3),
				(pt["p"] as Vector3) + off))


## The live readout seam (the T-169 call verb's ordinary one-hop method —
## a getter, nothing more): the schedule state at the CURRENT clock, so a
## staging session can read where the drag is without touching the write
## family. The clock itself stays advanced only by `_physics_process`.
func live_state() -> Dictionary:
	return state_at(clock)


## The route position and unit direction at arc s (clamped into the span).
func _point_at(s: float) -> Dictionary:
	var acc := 0.0
	for i in _seg_lens.size():
		var seg: float = _seg_lens[i]
		if acc + seg >= s or i == _seg_lens.size() - 1:
			var t := clampf((s - acc) / maxf(seg, 0.001), 0.0, 1.0)
			var a := extended_route[i]
			var b := extended_route[i + 1]
			return {"p": a.lerp(b, t), "dir": (b - a).normalized()}
		acc += seg
	var last := extended_route[extended_route.size() - 1]
	return {"p": last, "dir": (last - extended_route[extended_route.size() - 2]) \
			.normalized()}


## Straight run-outs past both ends of the core chain (the end segments'
## directions), long enough for the whole consist to clear the chain.
func _extend_route(core_route: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var head_dir := (core_route[1] - core_route[0]).normalized()
	var tail_dir := (core_route[core_route.size() - 1]
			- core_route[core_route.size() - 2]).normalized()
	var run_out := consist_length() + EXIT_CLEAR
	out.append(core_route[0] - head_dir * run_out)
	for p: Vector3 in core_route:
		out.append(p)
	out.append(core_route[core_route.size() - 1] + tail_dir * run_out)
	return out


## The consist schedule (the retained record): every box's band, its `off`
## BEHIND the loco center along the route (negative = ahead of it, toward the
## nose), the cross-body `z` for the proud flank faces, and the size.
func _build_schedule() -> void:
	part_schedule.clear()
	var hw := LOCO_WIDTH * 0.5
	part_schedule.append({"band": "loco_frame", "off": 0.0,
			"y": 1.05, "z": 0.0, "s": Vector3(LOCO_LEN, 1.3, LOCO_WIDTH - 0.1),
			"color": LOCO_DARK})
	part_schedule.append({"band": "loco_body", "off": 0.0,
			"y": 3.2, "z": 0.0,
			"s": Vector3(LOCO_LEN, 2.9, LOCO_WIDTH), "color": LOCO_YELLOW})
	part_schedule.append({"band": "loco_roof", "off": 0.0,
			"y": LOCO_HEIGHT - 0.125, "z": 0.0,
			"s": Vector3(LOCO_LEN, 0.25, LOCO_WIDTH), "color": LOCO_DARK})
	part_schedule.append({"band": "loco_glass", "off": -7.7,
			"y": 3.85, "z": 0.0,
			"s": Vector3(2.8, 0.85, LOCO_WIDTH + 0.04), "color": LOCO_GLASS})
	for side: float in [-1.0, 1.0]:
		part_schedule.append({"band": "shield_white", "off": 2.0,
				"y": 3.4, "z": side * (hw + 0.04),
				"s": Vector3(2.6, 1.7, 0.08), "color": SHIELD_WHITE})
		part_schedule.append({"band": "shield_blue", "off": 2.0,
				"y": 3.4, "z": side * (hw + 0.05),
				"s": Vector3(2.0, 1.3, 0.10), "color": SHIELD_BLUE})
	for k in HOPPER_COUNT:
		var center_off := LOCO_LEN * 0.5 + COUPLER_GAP + HOPPER_LEN * 0.5 \
				+ HOPPER_PITCH * float(k)
		part_schedule.append({"band": "hopper", "off": center_off,
				"y": 2.15, "z": 0.0,
				"s": Vector3(HOPPER_LEN, 3.3, HOPPER_WIDTH), "color": HOPPER_GRAY})
		part_schedule.append({"band": "coal", "off": center_off,
				"y": 3.9, "z": 0.0,
				"s": Vector3(HOPPER_LEN - 1.3, 0.45, HOPPER_WIDTH - 0.4),
				"color": COAL_DARK})


## The render rig: one unit-box MultiMesh (vertex colors), sized once for the
## whole extended route.
func _build_rig() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mesh.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = mesh
	_mm.instance_count = part_schedule.size()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p: Vector3 in extended_route:
		lo = lo.min(p - Vector3(0.0, 0.0, 0.0))
		hi = hi.max(p)
	## The route is 1-D; pad for the consist's width/height envelope.
	lo -= Vector3(3.0, 1.0, 3.0)
	hi += Vector3(3.0, 6.0, 3.0)
	_mm.custom_aabb = AABB(lo, hi - lo)
	for i in part_schedule.size():
		var part: Dictionary = part_schedule[i]
		_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY,
				Vector3(0.0, -1000.0, 0.0))) ## Parked below until the first run.
		_mm.set_instance_color(i, part["color"] as Color)
	var node := MultiMeshInstance3D.new()
	node.name = "Consist"
	node.multimesh = _mm
	add_child(node)
	## The scope guard is structural: NO physics body anywhere in this rig —
	## collision objects would gate a crossing car; the train is dressing.

extends SceneTree
## (T-141 diagnostic) Measures the imported people rig's actual seated
## geometry headless: for every whitelisted sit clip, the hip / foot / head
## bone heights above the rig root (the skeleton updated, not rest), plus the
## live elder SEATED composite (SEAT_SINK + hunch + hair mount applied the
## way _animate does) so the bench-math constants can be checked against
## reality. Run:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/probe_sit_geometry.gd
## (T-163) Adds the seat-contact law's three lines on BOTH surfaces —
##   (a) thigh-vs-seat-top: the sitting line's min-y over the seat plan's
##       z-band (feet/shin bins excluded) vs the seat top;
##   (b) knee-vs-front-edge: the live clip's shin bone origins vs the
##       front-edge plane;
##   (c) shin-vs-front-face: where the lower-leg line crosses the seat
##       slab's y-band vs that plane (inside the footprint = through the
##       face) — plus the sole line and the glute overhang. Mesh lines come
##       from the shipped SitBake bake (adult, root space — the exact pose
##       the café instances render and the elder's hold shares); constants
##       are read from the scripts' CURRENT values, so the same instrument
##       records the red-before and the green-after.

const RIG_SCENE := "res://scenes/people_rig.tscn"
const ELDER_SCENE := "res://scenes/elder.tscn"
const CLIPS: Array[String] = [
	"Rig|Sitting_Enter", "Rig|Sitting_Idle", "Rig|Sitting_Exit",
]

var _frame := 0
var _rig: Node3D
var _elder: Node3D


func _initialize() -> void:
	_rig = (load(RIG_SCENE) as PackedScene).instantiate()
	root.add_child(_rig)
	_elder = (load(ELDER_SCENE) as PackedScene).instantiate()
	_elder.position = Vector3(50.0, 0.0, 50.0)
	root.add_child(_elder)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 20:
		_measure_clip_geometry()
	elif _frame == 40:
		_measure_elder_seated()
	elif _frame == 41:
		_measure_contact_lines()
	elif _frame == 42:
		_measure_sit_bake()
		return true
	return false


func _skeleton(rig: Node3D) -> Skeleton3D:
	return rig.find_child("Skeleton3D", true, false) as Skeleton3D


func _bone_y(rig: Node3D, bone_name: String) -> float:
	var skeleton := _skeleton(rig)
	var idx := skeleton.find_bone(bone_name)
	if idx < 0:
		return NAN
	## World Y of the bone (get_bone_global_pose is skeleton-node-local; the
	## node itself may carry scale/offset from the import).
	return (skeleton.global_transform * skeleton.get_bone_global_pose(idx)).origin.y


func _bone_line(rig: Node3D) -> String:
	return "DEF-hips=%.4f  Lfoot=%.4f  Rfoot=%.4f  head=%.4f" % [
		_bone_y(rig, "DEF-hips"), _bone_y(rig, "DEF-foot.L"),
		_bone_y(rig, "DEF-foot.R"), _bone_y(rig, "DEF-head")]


func _measure_clip_geometry() -> void:
	var anim: AnimationPlayer = _rig.find_child("AnimationPlayer", true, false)
	print("=== clip geometry (rig root at identity, bone Y above rig root) ===")
	for clip in CLIPS:
		if not anim.has_animation(clip):
			print(clip, " MISSING")
			continue
		var a: Animation = anim.get_animation(clip)
		anim.play(clip, 0.0)
		anim.seek(a.length, true)
		print("%s end (len %.3f s): %s" % [clip, a.length, _bone_line(_rig)])
	anim.play("Rig|Idle", 0.0)
	anim.seek(0.0, true)
	_skeleton(_rig).force_update_all_bones()
	print("Rig|Idle frame 0:           %s" % _bone_line(_rig))
	## Sit_Idle mid-hold too, in case frame 0 is a blend-in artifact.
	var sit: Animation = anim.get_animation("Rig|Sitting_Idle")
	anim.seek(sit.length * 0.5, true)
	_skeleton(_rig).force_update_all_bones()
	print("Rig|Idle mid (0.83 s):      %s" % _bone_line(_rig))


## (T-142) The café crowd's baked seated meshes: AABBs in rig-root space so
## the spawner's placement constants come from measurement, not guesses.
func _measure_sit_bake() -> void:
	print("=== SitBake harvest (adult, rig-root space) ===")
	var rig: Node3D = (load(RIG_SCENE) as PackedScene).instantiate()
	var bake := rig.find_child("SitBake", true, false) as Node3D
	if bake == null:
		print("SitBake MISSING — the import bake did not run")
		return
	var skeleton := _skeleton(rig)
	for mi: MeshInstance3D in bake.get_children():
		var ab: AABB = mi.mesh.get_aabb()
		print("%s: aabb pos=%s size=%s  surfaces=%d  clip=%s" % [mi.name, ab.position,
				ab.size, mi.mesh.get_surface_count(), mi.mesh.get_meta("pose_clip", "")])
	rig.free()


func _measure_elder_seated() -> void:
	print("=== live elder, SEATED composite (elder root y=0 = bench seat top) ===")
	## Drive the SEATED cosmetic layer exactly as elder._animate does for the
	## state, without depending on headless physics ticking.
	var visual: Node3D = _elder.get_node("Visual")
	var sink: float = _elder.get("SEAT_SINK")
	var hunch: float = _elder.get("HUNCH_SEATED")
	visual.position.y = sink
	visual.rotation.x = hunch
	var sit: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)
	sit.play("Rig|Sitting_Idle", 0.0)
	sit.seek(0.5, true) ## A settled mid-hold frame.
	print("applied: sink=%.4f hunch=%.4f  visual.y=%.4f visual.rot.x=%.4f" % [
		sink, hunch, visual.position.y, visual.rotation.x])
	print("elder root global y=%.4f   bones: %s" % [
		_elder.global_position.y, _bone_line(visual)])
	var head_slot: Node3D = visual.find_child("HeadTop", true, false)
	var hair: Node3D = visual.find_child("Hair", true, false)
	if head_slot != null:
		print("HeadTop slot global y=%.4f" % head_slot.global_position.y)
	if hair != null:
		print("Hair global y=%.4f  (rig-root global y=%.4f)" % [
			hair.global_position.y, visual.global_position.y])
	var head_rigid := visual.find_child("HeadRigid", true, false) as MeshInstance3D
	if head_rigid != null and head_rigid.mesh != null:
		var ab: AABB = head_rigid.mesh.get_aabb()
		print("HeadRigid mesh AABB pos=%s size=%s end=%s (bind-frame metres)" % [
			ab.position, ab.size, ab.end])
	## The hunch's own hip drop, measured at the candidate values: the sink
	## must be derived WITH the hunch contribution, not on top of it.
	var hips0 := _bone_y(visual, "DEF-hips")
	visual.rotation.x = 0.0
	var hips_no_hunch := _bone_y(visual, "DEF-hips")
	visual.rotation.x = 0.06
	var hips_hunch06 := _bone_y(visual, "DEF-hips")
	visual.rotation.x = hunch
	print("hips bone y: hunch0=%.4f  hunch0.06=%.4f  hunch0.18=%.4f  (drop 0→0.06 = %.4f)" % [
		hips_no_hunch, hips_hunch06, hips0, hips_no_hunch - hips_hunch06])
	var hips_y := _bone_y(visual, "DEF-hips")
	var feet_y := minf(_bone_y(visual, "DEF-foot.L"), _bone_y(visual, "DEF-foot.R"))
	print("COMPOSITE: hips %.4f above the elder root (= seat top), feet %.4f above it" % [
		hips_y, feet_y])


## (T-163) The seat-contact law's three lines on BOTH surfaces, under the
## scripts' CURRENT constants (red-before and green-after run one instrument).
## Root space is pose space: the café pin translates the stool to root
## z = +SIT_SLIDE (the slide runs along the sitter's local z — the figure's
## facing), and the bench composite applies the exact elder node math —
## hunch Basis(RIGHT, HUNCH_SEATED), then the rig root lifted to slab
## + (SEAT_SINK + 0.60) and slid SEAT_SLIDE along the facing.
func _measure_contact_lines() -> void:
	print("=== seat-contact lines (T-163; current script constants) ===")
	var cconst: Dictionary = load("res://scripts/cafe_spawner.gd").get_script_constant_map()
	var econst: Dictionary = load("res://scripts/elder.gd").get_script_constant_map()
	var hips_y: float = cconst.get("SIT_HIPS_Y", 0.5179)
	var stool_top: float = cconst.get("SITTER_SEAT_TOP", 0.45)
	var root_y: float = cconst.get("SIT_ROOT_Y", stool_top - hips_y)
	var sit_slide: float = cconst.get("SIT_SLIDE", 0.0)
	var sink: float = econst.get("SEAT_SINK", -0.465)
	var hunch: float = econst.get("HUNCH_SEATED", 0.04)
	var seat_slide: float = econst.get("SEAT_SLIDE", 0.0)
	print("cafe: SIT_ROOT_Y=%+.4f SIT_SLIDE=%+.3f -> hips bone at stool%+.4f" % [
		root_y, sit_slide, root_y + hips_y - stool_top])
	print("bench: SEAT_SINK=%+.4f HUNCH_SEATED=%.3f SEAT_SLIDE=%+.4f -> rig root at slab%+.4f" % [
		sink, hunch, seat_slide, sink + 0.60])
	var rig2: Node3D = (load(RIG_SCENE) as PackedScene).instantiate()
	var bake := rig2.find_child("SitBake", true, false) as Node3D
	if bake == null:
		print("SitBake MISSING — re-import the pack glb (T-142)")
		rig2.free()
		return
	var all := PackedVector3Array()
	for mi: MeshInstance3D in bake.get_children():
		if mi.name.begins_with("SitHead"):
			continue ## y >= 1.05 — above every seat band, keep the scan lean.
		for v in mi.mesh.get_faces():
			all.append(v)
	rig2.free()
	print("bake faces scanned: %d (SitBody + SitLegs, adult)" % [all.size() / 3])
	_cafe_contact_lines(all, root_y, sit_slide)
	_bench_contact_lines(all, sink, hunch, seat_slide)
	_knee_contact_line(sit_slide)


## The three lines vs the stool (top 0.45, slab 0.39..0.45, plan ±0.18).
## In root space the stool's front edge sits at root z = SIT_SLIDE − 0.18.
func _cafe_contact_lines(all: PackedVector3Array, root_y: float, sit_slide: float) -> void:
	const PLAN := 0.18
	const TOP := 0.45
	const SLAB_LO := 0.39
	const SLAB_HI := 0.45
	var edge_front: float = sit_slide - PLAN
	var edge_rear: float = sit_slide + PLAN
	var thigh := INF
	var thigh_at := Vector3.ZERO
	var shin_z_max := -INF
	var shin_z_min := INF
	var sole := INF
	var glute_z := -INF
	var bins := {}
	for v in all:
		var wy: float = v.y + root_y ## world (sitter-frame) height.
		if v.z >= 0.0 and absf(v.x) <= PLAN and v.z >= edge_front and v.z <= edge_rear:
			if v.y < thigh:
				thigh = v.y
				thigh_at = v
			var b := int(floor(v.z / 0.05))
			bins[b] = minf(bins.get(b, INF), v.y)
		if v.z < -0.02 and wy >= SLAB_LO and wy <= SLAB_HI:
			shin_z_max = maxf(shin_z_max, v.z)
			shin_z_min = minf(shin_z_min, v.z)
		sole = minf(sole, wy)
		if v.z >= 0.0 and v.y >= 0.42 and v.y <= 0.47:
			glute_z = maxf(glute_z, v.z)
	var thigh_wy: float = thigh + root_y
	var thigh_ok := thigh_wy >= TOP - 0.01 and thigh_wy <= TOP + 0.05
	print("[cafe] (a) thigh line world=%.4f (root y %.4f at z %+.3f) vs top %.2f: %s — want [%.2f, %.2f]" % [
		thigh_wy, thigh, thigh_at.z, TOP, _verdict(thigh_ok), TOP - 0.01, TOP + 0.05])
	var slide_need: float = shin_z_max + PLAN + 0.01
	var shin_ok := shin_z_max <= edge_front + 0.01
	print("[cafe] (c) shin slab-band crossing root z %+.3f..%+.3f vs front edge %+.3f: %s — all crossing z <= %+.3f (SIT_SLIDE >= %.3f clears)" % [
		shin_z_min, shin_z_max, edge_front, _verdict(shin_ok), edge_front + 0.01, slide_need])
	print("[cafe] soles world=%+.4f: %s — want >= -0.01 (visible sole; the foot BONE rides %+.4f)" % [
		sole, _verdict(sole >= -0.01), 0.0873 + root_y])
	print("[cafe] glute band max root z %+.3f vs rear edge %+.3f (info; overhang %+.3f)" % [
		glute_z, edge_rear, glute_z - edge_rear])
	## Field note (T-163): vertices sunk deeper than the accepted 0.02 settle,
	## pose-z split — everything behind the knee divider (z >= 0) is the sit
	## clip's FOLDED far leg (its calf rides mid-slab at any rigid dial;
	## measured, recorded in the ticket, outside the law's three lines).
	var deep_f := 0
	var deep_b := 0
	var deep_f_z := INF
	var deep_b_z := -INF
	for v in all:
		if v.y + root_y >= SLAB_LO and v.y + root_y <= SLAB_HI - 0.02 \
				and absf(v.x) <= PLAN and v.z >= edge_front and v.z <= edge_rear:
			if v.z < 0.0:
				deep_f += 1
				deep_f_z = minf(deep_f_z, v.z)
			else:
				deep_b += 1
				deep_b_z = maxf(deep_b_z, v.z)
	print("[cafe] slab census (deeper than 0.02 settle): forward-leg %d (min z %+.3f), folded-leg %d (max z %+.3f)" % [
		deep_f, deep_f_z, deep_b, deep_b_z])
	var bin_keys := bins.keys()
	bin_keys.sort()
	var bin_s := ""
	for b: int in bin_keys:
		bin_s += "z%+.2f:%.3f  " % [b * 0.05, bins[b]]
	print("[cafe] plan-band underside per 0.05 z-bin (root y): %s" % bin_s)


## The three lines vs the bench (wood top 0.54, slab 0.46..0.54, edges ±0.25)
## in slab space, under the exact elder composite.
func _bench_contact_lines(all: PackedVector3Array, sink: float, hunch: float,
		seat_slide: float) -> void:
	const WOOD_TOP := 0.54
	const SLAB_LO := 0.46
	const SLAB_HI := 0.54
	const EDGE := 0.25
	const PLANE := 0.60
	const HALF_W := 0.9
	var rot := Basis(Vector3.RIGHT, hunch)
	var lift: float = sink + PLANE ## The rig root above the slab.
	var thigh := INF
	var thigh_at := Vector3.ZERO
	var shin_z_max := -INF
	var shin_z_min := INF
	var feet_lo := INF
	var glute_z := -INF
	for v in all:
		var p: Vector3 = rot * v + Vector3(0.0, lift, seat_slide)
		if v.z >= 0.0 and absf(p.x) <= HALF_W and absf(p.z) <= EDGE:
			if p.y < thigh:
				thigh = p.y
				thigh_at = v
		if v.z < -0.02 and p.y >= SLAB_LO and p.y <= SLAB_HI:
			shin_z_max = maxf(shin_z_max, p.z)
			shin_z_min = minf(shin_z_min, p.z)
		feet_lo = minf(feet_lo, p.y)
		if v.z >= 0.0 and v.y >= 0.42 and v.y <= 0.47:
			glute_z = maxf(glute_z, p.z)
	var thigh_ok := thigh >= WOOD_TOP - 0.01 and thigh <= PLANE + 0.05
	print("[bench] (a) thigh line slab=%.4f (root y %.4f at z %+.3f) vs wood top %.2f: %s — want [%.2f, %.2f]" % [
		thigh, thigh_at.y, thigh_at.z, WOOD_TOP, _verdict(thigh_ok),
		WOOD_TOP - 0.01, PLANE + 0.05])
	var base_z: float = shin_z_max - seat_slide ## The composite's z at slide 0.
	var shin_ok := shin_z_max <= -EDGE + 0.01
	print("[bench] (c) shin slab-band crossing slab z %+.3f..%+.3f vs front edge -%.2f: %s — all crossing z <= %+.3f (SEAT_SLIDE <= %+.3f clears)" % [
		shin_z_min, shin_z_max, EDGE, _verdict(shin_ok), -EDGE + 0.01, -EDGE + 0.01 - base_z])
	print("[bench] glute band max slab z %+.3f vs rear edge +%.2f: %s — want <= +%.2f (the glute ON the seat)" % [
		glute_z, EDGE, _verdict(glute_z <= EDGE + 0.01), EDGE + 0.01])
	print("[bench] lowest vertex slab y=%+.4f (the documented foot dangle, info)" % feet_lo)
	## Field note (T-163): same folded-leg census in slab space (the composite
	## applied) — the folded calf's slab crossing rides mid-seat at any slide.
	var deep_f := 0
	var deep_b := 0
	var deep_f_z := INF
	var deep_b_z := -INF
	for v in all:
		var p: Vector3 = rot * v + Vector3(0.0, lift, seat_slide)
		if p.y >= SLAB_LO and p.y <= SLAB_HI - 0.02 and absf(p.x) <= HALF_W \
				and absf(p.z) <= EDGE:
			if v.z < 0.0:
				deep_f += 1
				deep_f_z = minf(deep_f_z, p.z)
			else:
				deep_b += 1
				deep_b_z = maxf(deep_b_z, p.z)
	print("[bench] slab census (deeper than 0.02 settle): forward-leg %d (min z %+.3f), folded-leg %d (max z %+.3f)" % [
		deep_f, deep_f_z, deep_b, deep_b_z])


## (b) knee-vs-front-edge: the live clip's shin bone origins in root space
## (the rig is still posed at the Sitting_Idle mid-hold from the clip section).
func _knee_contact_line(sit_slide: float) -> void:
	var skel := _skeleton(_rig)
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		var low := n.to_lower()
		if not (low.contains("shin") or low.contains("calf") or low.contains("knee")
				or low.contains("foot") or low.contains("thigh")):
			continue
		var p: Vector3 = (skel.global_transform * skel.get_bone_global_pose(i)).origin
		print("[knee] %s origin root z %+.4f y %.4f x %+.4f — vs stool front edge %+.3f (slide-independent: knee INSIDE the plan at any height) and bench front edge -0.25" % [
			n, p.z, p.y, p.x, sit_slide - 0.18])


func _verdict(ok: bool) -> String:
	return "PASS" if ok else "FAIL"


## (T-145 debugging) The head-prop mount chain, world transforms in the
## seated composite: bone vs slot vs mesh corners vs the hair, so the
## render's floating read can be reconciled with the numbers.
func _measure_mount_chain() -> void:
	print("=== mount chain (seated composite) ===")
	var visual: Node3D = _elder.get_node("Visual")
	var sink: float = _elder.get("SEAT_SINK")
	visual.position.y = sink
	visual.rotation.x = _elder.get("HUNCH_SEATED")
	var sit: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)
	sit.play("Rig|Sitting_Idle", 0.0)
	sit.seek(0.5, true)
	var skeleton := _skeleton(visual)
	var wait := 3
	while wait > 0:
		await process_frame
		wait -= 1
	var head_rigid := visual.find_child("HeadRigid", true, false) as MeshInstance3D
	var head_slot := visual.find_child("HeadTop", true, false) as Node3D
	var hair := visual.find_child("Hair", true, false) as Node3D
	var head_idx := skeleton.find_bone("DEF-head")
	var bone_w := skeleton.global_transform * skeleton.get_bone_global_pose(head_idx)
	print("head BONE world origin=%s" % bone_w)
	print("HeadMount world origin=%s" % (visual.find_child("HeadMount", true, false)
			as Node3D).global_position)
	print("HeadRigid world origin=%s  scale=%s" % [head_rigid.global_position,
			head_rigid.global_transform.basis.get_scale()])
	var ab := head_rigid.mesh.get_aabb()
	print("mesh AABB pos=%s end=%s" % [ab.position, ab.end])
	for corner_name in ["top-center", "top-front", "top-back"]:
		var local := Vector3.ZERO
		if corner_name == "top-center":
			local = Vector3(ab.get_center().x, ab.end.y, ab.get_center().z)
		elif corner_name == "top-front":
			local = Vector3(ab.get_center().x, ab.end.y, ab.position.z)
		else:
			local = Vector3(ab.get_center().x, ab.end.y, ab.end.z)
		print("mesh %s world=%s" % [corner_name, head_rigid.global_transform * local])
	print("slot local=%s world=%s" % [head_slot.position, head_slot.global_position])
	print("hair world=%s  (local %s under %s)" % [hair.global_position,
			hair.position, hair.get_parent().name])
	quit()

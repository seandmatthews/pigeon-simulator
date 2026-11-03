extends SceneTree
## (T-141 diagnostic) Measures the imported people rig's actual seated
## geometry headless: for every whitelisted sit clip, the hip / foot / head
## bone heights above the rig root (the skeleton updated, not rest), plus the
## live elder SEATED composite (SEAT_SINK + hunch + hair mount applied the
## way _animate does) so the bench-math constants can be checked against
## reality. Run:
##   ~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##     --script tools/probe_sit_geometry.gd

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

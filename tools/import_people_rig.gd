@tool
extends EditorScenePostImport
## T-138 import script for the Quaternius pack (`base_character.glb`): turns
## the imported scene into the ONE shared rigged people source.
##
## NOTE: the `@tool` annotation is LOAD-BEARING — without it the editor never
## instantiates the script at import time (silently, headless included) and
## the pack ships unpruned and unsplit.
##
## The T-124 bake era imported this pack MESH-ONLY (`animation/import=false`)
## and derived static per-part pose bakes through `tools/bake_people_cars.gd`.
## T-138 retires that for humans: the rig goes LIVE, and this script — run by
## the importer itself, so nothing derived ever lands in `assets/` — prepares
## the runtime scene:
##
## 1. CLIP WHITELIST (the ban audit): the Universal Animation Library ships
##    45 clips; only six are kept — `Rig|Idle`, `Rig|Walk`, `Rig|Sprint`,
##    `Rig|Sitting_Idle`, `Rig|Sitting_Enter` (stand→sit, the ARRIVING
##    settle), `Rig|Sitting_Exit` (sit→stand, the RISING blend). Everything
##    outside the whitelist (which includes every T-124-banned clip) is
##    REMOVED here, so it exists nowhere
##    in the packed game — the T-124 "referenced nowhere" audit stays.
## 2. PART SPLIT (the T-113 color laws, now riding skinned meshes): the
##    mannequin's surfaces are partitioned per-vertex by dominant bone into
##    Body / Legs / ArmL, each a SKINNED MeshInstance3D over the same 53-joint
##    Skeleton3D with its own flat StandardMaterial3D (the per-class
##    `material_override` duplication source). ArmR has no skinned variant —
##    both citizens' right arms are the rigid ones below; the elder's far arm
##    rides the skinned ArmL.
## 3. RIGID MOUNT PARTS: HeadRigid / ArmLRigid / ArmRRigid — the head and the
##    script-driven arms (the tourist's panic raise, the elder's T-078 trust
##    arm) are rigid meshes authored in their main bone's BIND frame (scaled
##    to meters), each living under a BoneAttachment3D → 0.01-scale Frame so
##    they follow the live bone exactly. HeadRigid carries the HeadTop mount
##    slot (the tourist's cap, the elder's hair); ArmRRigid carries the HandR
##    slot (the tourist's foam finger).
## 4. METADATA: source pack/file/license (CC0) on the root and every part, the
##    clip whitelist, and the probe-measured envelope/stride constants the
##    sim scenario pins.
##
## Runtime half: `scripts/people_rig.gd` (+ `scenes/people_rig.tscn`), which
## instances THIS scene. Node names below are the contract — keep them in sync
## with people_rig.gd (this tools script deliberately never loads gameplay
## scripts, the T-124 bake precedent).

## The only clips that reach the packed game (recorded from the glb
## inventory, 2026-10-26: 45 shipped; the T-124-banned families stay out).
const CLIP_WHITELIST: Array[String] = [
	"Rig|Idle", "Rig|Walk", "Rig|Sprint",
	"Rig|Sitting_Idle", "Rig|Sitting_Enter", "Rig|Sitting_Exit",
]

const SOURCE_PACK := "quaternius-universal-base-characters"
const SOURCE_FILE := "res://assets/third-party/quaternius/base_character.glb"
const LICENSE := "CC0"

## Bone-name groups (Quaternius Rigify-style DEF- names — the T-124 bake's
## exact partition rules, arms split by the .L/.R suffix).
const HEAD_BONES: Array[String] = ["DEF-head", "DEF-neck"]
const BODY_BONES: Array[String] = ["DEF-hips", "DEF-spine.001", "DEF-spine.002",
		"DEF-spine.003", "DEF-shoulder.L", "DEF-shoulder.R"]
const LEGS_BONES: Array[String] = ["DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-toe.L",
		"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R", "DEF-toe.R"]

## Probe-measured envelope/locomotion constants (T-138 probes, 2026-10-26):
## standing Idle figure at import scale 1.0. The runtime Model node scales by
## the adult factor so the head top lands ≈ 1.75 m over feet at 0.
const MEASURED_HEAD_TOP := 1.7698
const MEASURED_FEET_Y := -0.0130
const WALK_STRIDE := 1.3239 ## Foot fore-aft range 0.6619 ×2 — distance per walk cycle.
const WALK_SECONDS := 1.3333 ## Rig|Walk length — natural pace 0.993 m/s.
const SPRINT_STRIDE := 2.1333
const SPRINT_SECONDS := 0.6667 ## Rig|Sprint natural pace 3.2 m/s (the panic clip).

## Per-part flat materials (the T-124 bake's palette; every tintable part
## carries a StandardMaterial3D for the per-class override duplication).
const MAT_SHIRT := Color(0.86, 0.30, 0.28) ## Tourist.SHIRT_PALETTE[0] literal.
const MAT_SKIN := Color(0.87, 0.68, 0.55) ## The shared skin family (T-007).
const MAT_DENIM := Color(0.25, 0.28, 0.33) ## Neutral denim — no team hue (T-121).

## The rigid parts' main bones — the frames their meshes are authored in.
const RIGID_MAIN_BONES := {
	"head": "DEF-head",
	"arm_l": "DEF-upper_arm.L",
	"arm_r": "DEF-upper_arm.R",
}

var _src_skin: Skin ## The mannequin's original Skin, captured before teardown.


func _post_import(scene: Node) -> Object:
	var skel := _find_skeleton(scene)
	var ap := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var mannequin := _find_skinned(scene)
	if skel == null or ap == null or mannequin == null:
		push_error("people rig import: skeleton/animation/mannequin missing")
		return scene
	_src_skin = mannequin.skin
	var accum := _accum_xform(scene, skel)
	var bind_global := _bind_globals(skel, mannequin)

	_partition_and_emit(skel, mannequin, accum, bind_global)
	_prune_clips(ap)
	_stamp_meta(scene)
	mannequin.get_parent().remove_child(mannequin)
	mannequin.free()
	scene.name = "PeopleRig"
	return scene


## --- discovery ---------------------------------------------------------------


func _find_skeleton(scene: Node) -> Skeleton3D:
	for n: Node in scene.find_children("*", "Skeleton3D", true, false):
		return n as Skeleton3D
	return null


func _find_skinned(scene: Node) -> MeshInstance3D:
	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.skin != null and mi.skin.get_bind_count() > 0:
			return mi
	return null


## The scene-root→skeleton transform accumulated by hand — global_transform
## is meaningless during import (the scene is not in a tree yet).
func _accum_xform(root: Node, node: Node) -> Transform3D:
	var chain: Array[Node] = []
	var cur: Node = node
	while cur != null and cur != root:
		chain.push_front(cur)
		cur = cur.get_parent()
	var xf := Transform3D.IDENTITY
	if cur == root:
		xf = (root as Node3D).transform
	for n: Node in chain:
		xf = xf * (n as Node3D).transform
	return xf


## Per-bone bind poses of the mannequin's skin (bind = inverse bind).
func _bind_globals(skel: Skeleton3D, mannequin: MeshInstance3D) -> Dictionary:
	var binds := {}
	var skin := mannequin.skin
	for bind_i in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind_i)
		if bone < 0 and skin.get_bind_name(bind_i) != "":
			bone = skel.find_bone(skin.get_bind_name(bind_i))
		if bone >= 0:
			binds[bone] = skin.get_bind_pose(bind_i)
	return binds


## --- part split ---------------------------------------------------------------


## The T-124 bake's dominant-bone partition, arms split by suffix.
func _part_of(bone_name: String) -> String:
	if bone_name in HEAD_BONES:
		return "head"
	if bone_name in BODY_BONES:
		return "body"
	if bone_name in LEGS_BONES:
		return "legs"
	if bone_name.ends_with(".L"):
		return "arm_l"
	if bone_name.ends_with(".R"):
		return "arm_r"
	return "body"


## Partitions both surfaces per-vertex by dominant bone and emits the game
## nodes. Skinned parts (Body/Legs/ArmL) keep the full bind skin and go under
## the Skeleton3D. Rigid parts (head/arms) are re-authored in their main
## bone's BIND frame (scaled to meters) under BoneAttachment3D mounts.
func _partition_and_emit(skel: Skeleton3D, mannequin: MeshInstance3D,
		accum: Transform3D, bind_global: Dictionary) -> void:
	var scale := absf(accum.basis.get_scale().x) ## The import's ×100.
	var per_part := {} ## part -> Array (per source surface) of build Dictionaries.
	for s in mannequin.mesh.get_surface_count():
		var arrays := mannequin.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var dom: Array[String] = []
		dom.resize(verts.size())
		for v in verts.size():
			var best_w := -1.0
			var best_b := 0
			for k in 4:
				var w := weights[v * 4 + k]
				if w > best_w:
					best_w = w
					best_b = bones[v * 4 + k]
			dom[v] = _part_of(skel.get_bone_name(best_b))
		## Triangle → part by 2-of-3 majority (the bake's rule).
		for t in range(0, indices.size(), 3):
			var a := indices[t]
			var b := indices[t + 1]
			var c := indices[t + 2]
			var part: String = dom[a]
			if dom[b] == dom[c] and dom[b] != dom[a]:
				part = dom[b]
			if not per_part.has(part):
				per_part[part] = []
			var build: Dictionary = _surface_build(per_part, part, s, arrays)
			var remap: Dictionary = build["remap"]
			var new_indices: PackedInt32Array = build["indices"]
			for idx: int in [a, b, c]:
				if not remap.has(idx):
					remap[idx] = (build["verts"] as PackedVector3Array).size()
					_append_vertex(build, arrays, idx)
			new_indices.append(remap[a])
			new_indices.append(remap[b])
			new_indices.append(remap[c])
			build["indices"] = new_indices

	## Skinned, always-visible parts.
	_emit_skinned(skel, per_part, "body", "Body", MAT_SHIRT)
	_emit_skinned(skel, per_part, "legs", "Legs", MAT_DENIM)
	_emit_skinned(skel, per_part, "arm_l", "ArmL", MAT_SKIN)
	## Rigid mount parts: head always shown (the Cap/Hair mount); arms hidden
	## — the tourist shows them, the elder leaves them off (far arm = ArmL).
	_emit_rigid(skel, per_part, accum, bind_global, scale,
			"head", "HeadRigid", "HeadMount", true)
	_emit_rigid(skel, per_part, accum, bind_global, scale,
			"arm_l", "ArmLRigid", "ArmLMount", false)
	_emit_rigid(skel, per_part, accum, bind_global, scale,
			"arm_r", "ArmRRigid", "ArmRMount", false)


func _surface_build(per_part: Dictionary, part: String, surface: int,
		arrays: Array) -> Dictionary:
	var list: Array = per_part[part]
	while list.size() <= surface:
		list.append({
			"verts": PackedVector3Array(), "normals": PackedVector3Array(),
			"uv": PackedVector2Array(),
			"bones": PackedInt32Array(), "weights": PackedFloat32Array(),
			"indices": PackedInt32Array(), "remap": {},
		})
	return list[surface]


## Appends one vertex to a part build (read-modify-write: packed arrays in
## Dictionaries copy on assignment). EVERY part's vertices copy the arrays
## verbatim — the mannequin's bind skin assumes that space, and the skinned
## parts (body/legs/arm_l) ride it directly. The rigid parts' bake into their
## main bone's bind frame happens at EMISSION time (`_emit_rigid`), never
## here: `arm_l` feeds BOTH the skinned ArmL and the rigid ArmLRigid, and a
## bake at partition time corrupted the skinned arm with meter-space
## vertices — it rendered ×100 as ~85 m slabs (T-139).
func _append_vertex(build: Dictionary, arrays: Array, idx: int) -> void:
	var verts: PackedVector3Array = build["verts"]
	verts.append(arrays[Mesh.ARRAY_VERTEX][idx])
	build["verts"] = verts
	var normals: PackedVector3Array = build["normals"]
	normals.append(arrays[Mesh.ARRAY_NORMAL][idx])
	build["normals"] = normals
	var uv_src: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if uv_src != null:
		var uv: PackedVector2Array = build["uv"]
		uv.append(uv_src[idx])
		build["uv"] = uv
	var bones: PackedInt32Array = build["bones"]
	var weights: PackedFloat32Array = build["weights"]
	for k in 4:
		bones.append(arrays[Mesh.ARRAY_BONES][idx * 4 + k])
		weights.append(arrays[Mesh.ARRAY_WEIGHTS][idx * 4 + k])
	build["bones"] = bones
	build["weights"] = weights


func _build_mesh(build: Dictionary, with_skin: bool) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = build["verts"]
	arrays[Mesh.ARRAY_NORMAL] = build["normals"]
	var uv: PackedVector2Array = build["uv"]
	if uv.size() == (build["verts"] as PackedVector3Array).size():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if with_skin:
		arrays[Mesh.ARRAY_BONES] = build["bones"]
		arrays[Mesh.ARRAY_WEIGHTS] = build["weights"]
	arrays[Mesh.ARRAY_INDEX] = build["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _flat_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


## Emits one skinned part: surface 0 = the body panels, surface 1 = the
## Quaternius doll joints — both under the part's single flat material.
func _emit_skinned(skel: Skeleton3D, per_part: Dictionary, key: String,
		node_name: String, color: Color) -> void:
	var list: Array = per_part[key]
	var mesh := _build_mesh(list[0], true)
	for s in range(1, list.size()):
		var extra := _build_mesh(list[s], true)
		var a: Array = extra.surface_get_arrays(0)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = a[Mesh.ARRAY_VERTEX]
		arrays[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
		arrays[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
		arrays[Mesh.ARRAY_BONES] = a[Mesh.ARRAY_BONES]
		arrays[Mesh.ARRAY_WEIGHTS] = a[Mesh.ARRAY_WEIGHTS]
		arrays[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := _flat_mat(color)
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, mat)
	mesh.set_meta("source_pack", SOURCE_PACK)
	mesh.set_meta("source_file", SOURCE_FILE)
	mesh.set_meta("license", LICENSE)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.skin = _src_skin.duplicate() ## Full 53-bind skin; parts use bone indices.
	mi.skeleton = NodePath("..")
	skel.add_child(mi)
	mi.owner = skel.owner


## Emits one rigid mount part: the head/arm meshes are baked at the BIND pose
## in their main bone's frame (meters), hung under
## BoneAttachment3D → Frame (1/×100 scale) so they ride the live bone.
func _emit_rigid(skel: Skeleton3D, per_part: Dictionary, accum: Transform3D,
		bind_global: Dictionary, scale: float, key: String, mesh_name: String,
		mount_name: String, visible: bool) -> void:
	var list: Array = per_part[key]
	## Merge all surfaces into one (verts/normals/indices — flat color, no
	## UVs/skin needed on rigid parts), baking each verbatim partition vertex
	## into the main bone's BIND frame (meters — the frame the mount's
	## 0.01-scale Frame expects): at bind every vertex renders at its
	## authored spot, so the frame transform is exactly the main bone's bind
	## pose (`P_bind(main)` from the skin), scaled to meters. The bake lives
	## HERE, not at partition time: `arm_l` also feeds the skinned ArmL,
	## whose bind skin assumes mannequin space (the T-139 ×100 lesson).
	var main_bone: String = RIGID_MAIN_BONES[key]
	var main_bp: Transform3D = bind_global[skel.find_bone(main_bone)]
	var n_xf: Basis = main_bp.basis.inverse().transposed()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for build: Dictionary in list:
		var base := verts.size()
		var bverts: PackedVector3Array = build["verts"]
		for i in bverts.size():
			verts.append(main_bp * bverts[i] * scale)
		var bnormals: PackedVector3Array = build["normals"]
		for j in bnormals.size():
			normals.append((n_xf * bnormals[j]).normalized())
		for idx: int in build["indices"]:
			indices.append(base + idx)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := _flat_mat(MAT_SKIN)
	mesh.surface_set_material(0, mat)
	mesh.set_meta("source_pack", SOURCE_PACK)
	mesh.set_meta("source_file", SOURCE_FILE)
	mesh.set_meta("license", LICENSE)

	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.visible = visible
	var attach := BoneAttachment3D.new()
	attach.name = mount_name
	attach.bone_name = main_bone
	skel.add_child(attach)
	attach.owner = skel.owner
	var frame := Node3D.new()
	frame.name = "Frame"
	frame.scale = Vector3.ONE / scale ## Meters frame under the ×100 skeleton.
	attach.add_child(frame)
	frame.owner = skel.owner
	frame.add_child(mi)
	mi.owner = skel.owner

	if key == "arm_r":
		var hand_idx := skel.find_bone("DEF-hand.R")
		var hand_local: Vector3 = (bind_global[skel.find_bone(main_bone)]
				* bind_global[hand_idx].inverse()).origin * scale
		var slot := Node3D.new()
		slot.name = "HandR"
		slot.position = hand_local
		mesh.set_meta("hand_local", hand_local)
		## Under the MESH node (not the Frame): the slot must ride the
		## script-driven raise with the arm.
		mi.add_child(slot)
		slot.owner = skel.owner
	if key == "head":
		var top := AABB(verts[0], Vector3.ZERO)
		for v: Vector3 in verts:
			top = top.expand(v)
		var top_center := Vector3(0.0, top.end.y, 0.0)
		var slot := Node3D.new()
		slot.name = "HeadTop"
		slot.position = top_center
		mesh.set_meta("head_top_local", top_center)
		mi.add_child(slot)
		slot.owner = skel.owner


## --- clips + metadata ---------------------------------------------------------


## The ban audit, enforced where it counts: everything outside the whitelist
## is removed from the library BEFORE the scene is saved — the banned clips
## exist nowhere in the packed game.
func _prune_clips(ap: AnimationPlayer) -> void:
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for clip_name in lib.get_animation_list():
			if not (clip_name in CLIP_WHITELIST):
				lib.remove_animation(clip_name)


func _stamp_meta(scene: Node) -> void:
	scene.set_meta("source_pack", SOURCE_PACK)
	scene.set_meta("source_file", SOURCE_FILE)
	scene.set_meta("license", LICENSE)
	scene.set_meta("clip_whitelist", CLIP_WHITELIST)
	scene.set_meta("measured_head_top", MEASURED_HEAD_TOP)
	scene.set_meta("measured_feet_y", MEASURED_FEET_Y)
	scene.set_meta("walk_stride", WALK_STRIDE)
	scene.set_meta("walk_seconds", WALK_SECONDS)
	scene.set_meta("sprint_stride", SPRINT_STRIDE)
	scene.set_meta("sprint_seconds", SPRINT_SECONDS)

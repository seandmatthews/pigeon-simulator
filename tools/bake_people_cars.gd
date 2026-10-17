extends SceneTree
## T-124 one-shot bake: derives the game's pedestrian + car VISUAL meshes from
## the imported CC0 packs and writes them under assets/generated/models/.
##
##   human  -> assets/third-party/quaternius/base_character.glb
##             (Quaternius Universal Base Character, CC0) — skinned at the
##             given Universal Animation Library clip frames, then split into
##             per-part meshes (head/torso/arm L/R/legs) by dominant bone.
##   car    -> assets/third-party/kenney/carkit/sedan.glb
##             (Kenney Car Kit, CC0) — body triangles split by colormap
##             color role into paint/glass/trim/lights meshes; the paint mesh
##             is the per-class tint surface (T-113/T-121 overrides).
##
## RUN MODE: `godot --headless --path . --script res://tools/bake_people_cars.gd`
## IMPORTANT: the base_character.glb import must have animation/import=true
## WHILE THIS RUNS (the pose comes from the clips). The committed import has
## animation/import=false — flip it, run `--import`, run this bake, flip it
## back, run `--import` again. No runtime animation resource ships (the death
## clips are banned, T-124).
## Output is committed: the game scenes reference these .res meshes, never
## the packs directly, so the physics-vs-visual contract stays hand-reviewed.

const PEOPLE_DIR := "res://assets/generated/models/people/"
const CARS_DIR := "res://assets/generated/models/cars/"

## Standing figure envelope: head top lands here (the scene's head line 1.27
## keeps ~0.05 of cap headroom), feet on y 0 — the tourist capsule
## (r 0.25 / h 1.1, centered 0.55) still bounds the body.
const HEAD_TOP := 1.22

## Car body box (the physics contract): 1.9 x 1.45 x 4.4. The Kenney sedan
## (1.5 wide x 1.15 tall body x 2.55 long in node space) stretches to fill
## length, keeps height, and squeezes width to the box; wheels scale uniformly.
const CAR_BOX := Vector3(1.9, 1.45, 4.4)

const SOURCE_PACK_HUMAN := "quaternius-universal-base-characters"
const SOURCE_FILE_HUMAN := "res://assets/third-party/quaternius/base_character.glb"
const SOURCE_PACK_CAR := "kenney-car-kit"
const SOURCE_FILE_CAR := "res://assets/third-party/kenney/carkit/sedan.glb"
const LICENSE_HUMAN := "CC0"
const LICENSE_CAR := "CC0"

const PART_NAMES: Array[String] = ["head", "torso", "arm_l", "arm_r", "legs"]

## Bone-name groups (Quaternius Rigify-style DEF- names). Arms also catch the
## finger/thumb bones via the suffix rule in _dominant_part().
const HEAD_BONES: Array[String] = ["DEF-head", "DEF-neck"]
const TORSO_BONES: Array[String] = ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003"]
const LEGS_BONES: Array[String] = ["DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-toe.L",
		"DEF-thigh.R", "DEF-shin.R", "DEF-foot.R", "DEF-toe.R"]

func _process(_delta: float) -> bool:
	## The bake needs a live SceneTree (skeleton global transforms), so it
	## runs on the first process frame, not in setup.
	var failed := false
	if _bake_human() != OK:
		failed = true
	if _bake_car() != OK:
		failed = true
	print("BAKE DONE failed=", failed)
	return true ## Quit after this frame.


## ---------------------------------------------------------------------------
## Human bake
## ---------------------------------------------------------------------------

func _dominant_part(bone_name: String) -> String:
	if bone_name in HEAD_BONES:
		return "head"
	if bone_name in TORSO_BONES:
		return "torso"
	if bone_name in LEGS_BONES:
		return "legs"
	if bone_name.ends_with(".L"):
		return "arm_l"
	if bone_name.ends_with(".R"):
		return "arm_r"
	return "torso"

func _bake_human() -> int:
	var scene := load(SOURCE_FILE_HUMAN) as PackedScene
	if scene == null:
		push_error("BAKE human: cannot load " + SOURCE_FILE_HUMAN)
		return ERR_CANT_OPEN
	var inst := scene.instantiate()
	root.add_child(inst)
	var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skel == null or ap == null:
		push_error("BAKE human: skeleton/animation player missing")
		return ERR_UNAVAILABLE

	## Pose + skin one clip frame into world-space part arrays. The walk
	## figure poses at Rig|Idle frame 0 (arms down, neutral stance — the
	## runtime comedy animation stays the script's own, T-011 lineage); the
	## elder poses at Rig|Sitting_Idle frame 0 (the sit clip, T-124).
	var poses := {
		"walk": {"clip": "Rig|Idle", "time": 0.0, "out": "walk_"},
		"sit": {"clip": "Rig|Sitting_Idle", "time": 0.0, "out": "sit_"},
	}
	var results := {}
	for key: String in poses:
		var spec: Dictionary = poses[key]
		var clip: String = spec["clip"]
		if not ap.has_animation(clip):
			push_error("BAKE human: clip missing: " + clip)
			return ERR_DOES_NOT_EXIST
		ap.play(clip)
		ap.seek(spec["time"], true)
		## advance() with delta 0 does not reliably flush the first blend —
		## march one clip frame (the import baked 30 fps) and verify the arms
		## actually left the bind pose before skinning.
		ap.advance(1.0 / 30.0)
		var ua := skel.find_bone("DEF-upper_arm.L")
		if ua >= 0 and skel.get_bone_global_pose(ua).is_equal_approx(
				skel.get_bone_global_rest(ua)):
			ap.advance(1.0 / 30.0)
		results[key] = {"parts": _skin_parts(skel), "skel_xf": skel.global_transform,
				"skel": skel}

	## Uniform scale from the WALK figure: head top -> HEAD_TOP, feet -> y 0.
	var walk_bounds := _union_aabb(results["walk"]["parts"])
	if walk_bounds.size.y <= 0.1:
		push_error("BAKE human: degenerate walk bounds " + str(walk_bounds))
		return ERR_DOES_NOT_EXIST
	var stand_scale := HEAD_TOP / walk_bounds.size.y
	var walk_shift := -walk_bounds.position.y * stand_scale
	print("BAKE human: walk bounds ", walk_bounds, " scale=", stand_scale)
	var sit_bounds := _union_aabb(results["sit"]["parts"])
	print("BAKE human: sit bounds ", sit_bounds)

	## The seated figure shares the standing scale; it shifts so the pelvis
	## settles INTO the bench seat (the elder root sits ON the seat plane,
	## so hips land ~0.06 above it and the feet dangle toward the pavement).
	var sit_hips: Vector3 = _bone_world(results["sit"]["skel"], "DEF-hips",
			stand_scale, 0.0)
	var sit_shift: float = -sit_hips.y + 0.06
	print("BAKE human: sit hips pre-shift=", sit_hips, " shift=", sit_shift)

	for key in ["walk", "sit"]:
		var figure_skel: Skeleton3D = results[key]["skel"]
		var shift: float = walk_shift if key == "walk" else sit_shift
		var prefix: String = poses[key]["out"]
		var nodes := _node_map(key, results[key]["parts"], figure_skel, stand_scale, shift)
		for part in PART_NAMES:
			var data: Dictionary = results[key]["parts"][part]
			if data["indices"].is_empty():
				push_error("BAKE human: empty part " + key + "/" + part)
				return ERR_DOES_NOT_EXIST
			var node_pos: Vector3 = nodes[part + "_node"]
			var mesh := _build_mesh(data["verts"], data["normals"], data["indices"],
					stand_scale, shift, node_pos, _part_material(part))
			mesh.set_meta("source_pack", SOURCE_PACK_HUMAN)
			mesh.set_meta("source_file", SOURCE_FILE_HUMAN)
			mesh.set_meta("pose_clip", poses[key]["clip"])
			mesh.set_meta("license", LICENSE_HUMAN)
			var err := ResourceSaver.save(mesh, PEOPLE_DIR + prefix + part + ".res")
			if err != OK:
				push_error("BAKE human: save failed " + prefix + part)
				return err
		_print_placement(key, nodes)
	inst.queue_free()
	return OK

## The joint origin of `bone_name` in final game space (scaled + shifted).
func _bone_world(skel: Skeleton3D, bone_name: String, scale: float,
		shift: float) -> Vector3:
	var idx := skel.find_bone(bone_name)
	if idx < 0:
		push_error("BAKE human: missing bone " + bone_name)
		return Vector3.ZERO
	return (skel.global_transform * skel.get_bone_global_pose(idx)).origin 			* scale + Vector3(0.0, shift, 0.0)

## Part node placements for one figure: where the scene nodes must sit for
## the node-local meshes to land. Torso/head nodes take their AABB centers
## (x forced to 0 — the tourist yaws about its root); the arm nodes take the
## shoulder JOINT origins (the panic raise pivots there); legs sit at the root.
func _node_map(key: String, parts: Dictionary, skel: Skeleton3D,
		scale: float, shift: float) -> Dictionary:
	var map := {}
	for part in ["head", "torso", "legs"]:
		if part == "legs":
			map[part + "_node"] = Vector3.ZERO ## Root-local: feet on the ground.
			continue
		var box := _union_aabb_dict(parts, part)
		var center := box.get_center() * scale + Vector3(0.0, shift, 0.0)
		center.x = 0.0
		map[part + "_node"] = center
	map["arm_l_node"] = _bone_world(skel, "DEF-upper_arm.L", scale, shift)
	map["arm_r_node"] = _bone_world(skel, "DEF-upper_arm.R", scale, shift)
	map["hand_l"] = _bone_world(skel, "DEF-hand.L", scale, shift)
	map["head_top"] = _union_aabb_dict(parts, "head").end.y * scale + shift
	map["key"] = key
	return map

func _print_placement(key: String, nodes: Dictionary) -> void:
	print("BAKE placement ", key, ":")
	for part in PART_NAMES:
		print("    %s%s node -> (%.3f, %.3f, %.3f)" % [nodes["key"], part,
				nodes[part + "_node"].x, nodes[part + "_node"].y, nodes[part + "_node"].z])
	print("    %s hand_l -> (%.3f, %.3f, %.3f)" % [nodes["key"],
			nodes["hand_l"].x, nodes["hand_l"].y, nodes["hand_l"].z])
	print("    %s head_top -> %.3f" % [nodes["key"], nodes["head_top"]])

## Skins the posed skeleton's mesh surfaces into per-part world-space data.
## The delta uses the SKIN's bind poses (the mesh is bound in a T-pose while
## the skeleton rest has arms down — the rest pose is NOT the bind pose).
func _skin_parts(skel: Skeleton3D) -> Dictionary:
	var parts := {}
	for part in PART_NAMES:
		parts[part] = {"verts": PackedVector3Array(), "normals": PackedVector3Array(),
				"indices": PackedInt32Array()}
	for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", true, false):
		var posed: Array[Transform3D] = []
		var inv_bind: Array[Transform3D] = [] ## Per MESH JOINT index.
		var skin := mi.skin
		if skin == null or skin.get_bind_count() == 0:
			push_error("BAKE human: mesh without skin binds")
			continue
		for bind_i in skin.get_bind_count():
			var bone := skin.get_bind_bone(bind_i)
			if bone < 0 and skin.get_bind_name(bind_i) != "":
				bone = skel.find_bone(skin.get_bind_name(bind_i))
			if bone < 0:
				push_error("BAKE human: skin bind without bone")
				return parts
			posed.append(skel.get_bone_global_pose(bone))
			inv_bind.append(skin.get_bind_pose(bind_i))
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if verts == null or bones == null or weights == null:
				push_error("BAKE human: surface without skin data")
				continue
			## Pre-skin every vertex into skeleton space (rigid per dominant
			## joint — Quaternius weights are near-rigid).
			var skel_verts := PackedVector3Array()
			skel_verts.resize(verts.size())
			var skel_normals := PackedVector3Array()
			skel_normals.resize(normals.size())
			var dominant: Array[String] = []
			dominant.resize(verts.size())
			for v in verts.size():
				var pos := Vector3.ZERO
				var best_w := -1.0
				var best_bone := 0
				for k in 4:
					var w := weights[v * 4 + k]
					if w <= 0.0:
						continue
					var j := bones[v * 4 + k]
					pos += (posed[j] * inv_bind[j]) * verts[v] * w
					if w > best_w:
						best_w = w
						best_bone = j
				var delta := posed[best_bone] * inv_bind[best_bone]
				skel_verts[v] = skel.global_transform * pos
				skel_normals[v] = skel.global_transform.basis * (delta.basis * normals[v])
				dominant[v] = _dominant_part(skel.get_bone_name(best_bone))
			for t in range(0, indices.size(), 3):
				var a := indices[t]
				var b := indices[t + 1]
				var c := indices[t + 2]
				var part: String = dominant[a]
				if dominant[b] == dominant[c] and dominant[b] != dominant[a]:
					part = dominant[b] ## 2-of-3 majority beats the odd vertex.
				var base: int = parts[part]["verts"].size()
				for idx: int in [a, b, c]:
					parts[part]["verts"].append(skel_verts[idx])
					parts[part]["normals"].append(skel_normals[idx])
				parts[part]["indices"].append(base)
				parts[part]["indices"].append(base + 1)
				parts[part]["indices"].append(base + 2)
	return parts

func _union_aabb_dict(parts: Dictionary, part: String) -> AABB:
	var verts: PackedVector3Array = parts[part]["verts"]
	if verts.is_empty():
		return AABB()
	var box := AABB(verts[0], Vector3.ZERO)
	for v: Vector3 in verts:
		box = box.expand(v)
	return box

func _union_aabb(parts: Dictionary) -> AABB:
	var total := AABB()
	var first := true
	for part in parts:
		var verts: PackedVector3Array = parts[part]["verts"]
		if verts.is_empty():
			continue
		var box := AABB(verts[0], Vector3.ZERO)
		for v: Vector3 in verts:
			box = box.expand(v)
		if first:
			total = box
			first = false
		else:
			total = total.merge(box)
	return total

func _build_mesh(verts: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, scale: float, shift: float,
		node_pos: Vector3, mat: StandardMaterial3D) -> ArrayMesh:
	var out_verts := PackedVector3Array()
	out_verts.resize(verts.size())
	var out_normals := PackedVector3Array()
	out_normals.resize(normals.size())
	for i in verts.size():
		## verts/normals are ALREADY in world space (_skin_parts applied the
		## skeleton transform); only the game scale/shift/node-local applies.
		out_verts[i] = (verts[i] * scale + Vector3(0.0, shift, 0.0)) - node_pos
		out_normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_verts
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh

func _part_material(part: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	match part:
		"head":
			mat.albedo_color = Color(0.87, 0.68, 0.55) ## The shared skin family (T-007).
		"torso":
			## Tourist.SHIRT_PALETTE[0] — replaced per tourist at _ready; kept a
			## literal so this tools script never depends on gameplay scripts.
			mat.albedo_color = Color(0.86, 0.30, 0.28)
		"legs":
			mat.albedo_color = Color(0.25, 0.28, 0.33) ## Neutral denim — no team hue (T-121).
		_:
			mat.albedo_color = Color(0.87, 0.68, 0.55) ## Arms: always overridden per class.
	return mat

## ---------------------------------------------------------------------------
## Car bake
## ---------------------------------------------------------------------------

func _bake_car() -> int:
	var scene := load(SOURCE_FILE_CAR) as PackedScene
	if scene == null:
		push_error("BAKE car: cannot load " + SOURCE_FILE_CAR)
		return ERR_CANT_OPEN
	var inst := scene.instantiate()
	root.add_child(inst)
	var img := (load("res://assets/third-party/kenney/carkit/Textures/colormap.png")
			as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()

	## Node-space -> car-root space with the box fit: length to 4.4 (the
	## Kenney front +Z becomes the game's forward -Z), width to 1.9, height
	## kept. Wheels scale uniformly and re-seat at their scaled centers.
	var s := Vector3(CAR_BOX.x / 1.5, 1.0, CAR_BOX.z / 2.55)
	var rot := Basis(Vector3.UP, PI)
	var car_xf := func(node_pos: Vector3, v: Vector3) -> Vector3:
		return rot * ((node_pos + v) * Vector3(s.x, 1.0, s.z))

	var roles := {}
	for role in ["paint", "glass", "trim", "lights"]:
		roles[role] = {"verts": PackedVector3Array(), "normals": PackedVector3Array(),
				"indices": PackedInt32Array()}
	var body := inst.find_child("body", true, false) as MeshInstance3D
	if body == null:
		push_error("BAKE car: body mesh missing")
		return ERR_DOES_NOT_EXIST
	var arrays := body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if uvs == null:
		push_error("BAKE car: body without UVs")
		return ERR_DOES_NOT_EXIST
	var paint_votes := {}
	for t in range(0, indices.size(), 3):
		var i0 := indices[t]
		var i1 := indices[t + 1]
		var i2 := indices[t + 2]
		var uv_mid := (uvs[i0] + uvs[i1] + uvs[i2]) / 3.0
		var role := _color_role(_sample(img, uv_mid))
		roles[role]["verts"].append(car_xf.call(body.position, verts[i0]))
		roles[role]["verts"].append(car_xf.call(body.position, verts[i1]))
		roles[role]["verts"].append(car_xf.call(body.position, verts[i2]))
		for idx: int in [i0, i1, i2]:
			roles[role]["normals"].append((rot * normals[idx]).normalized())
		var base: int = roles[role]["verts"].size() - 3
		roles[role]["indices"].append(base)
		roles[role]["indices"].append(base + 1)
		roles[role]["indices"].append(base + 2)
		if role == "paint":
			var col := _sample(img, uv_mid)
			paint_votes[col] = paint_votes.get(col, 0) + 1
	print("BAKE car paint chip votes: ", paint_votes)

	var mats := {
		"paint": _flat_mat(Color(0.85, 0.25, 0.22), 0.5, 0.35), ## Replaced per car at _ready.
		"glass": _flat_mat(Color(0.16, 0.19, 0.24), 0.15, 0.2),
		"trim": _flat_mat(Color(0.12, 0.12, 0.13), 0.9, 0.0),
		"lights": _flat_mat(Color(0.98, 0.95, 0.85), 0.4, 0.0),
	}
	for role in roles:
		if roles[role]["indices"].is_empty():
			push_error("BAKE car: empty role " + str(role))
			return ERR_DOES_NOT_EXIST
		var mesh := ArrayMesh.new()
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = roles[role]["verts"]
		a[Mesh.ARRAY_NORMAL] = roles[role]["normals"]
		a[Mesh.ARRAY_INDEX] = roles[role]["indices"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mesh.surface_set_material(0, mats[role])
		mesh.set_meta("source_pack", SOURCE_PACK_CAR)
		mesh.set_meta("source_file", SOURCE_FILE_CAR)
		mesh.set_meta("license", LICENSE_CAR)
		var err := ResourceSaver.save(mesh, CARS_DIR + "car_" + str(role) + ".res")
		if err != OK:
			push_error("BAKE car: save failed " + str(role))
			return err
	## Wheels: one mesh, uniform scale, authored around the origin (the four
	## scene nodes carry the translations). The colormap material keeps the
	## kit's tire/hub read.
	var wheel := inst.find_child("wheel-front-right", true, false) as MeshInstance3D
	if wheel == null:
		push_error("BAKE car: wheel mesh missing")
		return ERR_DOES_NOT_EXIST
	var w_arrays := wheel.mesh.surface_get_arrays(0)
	var w_verts: PackedVector3Array = w_arrays[Mesh.ARRAY_VERTEX]
	var w_uv: PackedVector2Array = w_arrays[Mesh.ARRAY_TEX_UV]
	var ws := CAR_BOX.x / 1.5 ## Uniform: a round tire stays round.
	var w_mesh := ArrayMesh.new()
	var wa := []
	wa.resize(Mesh.ARRAY_MAX)
	var wv := PackedVector3Array()
	wv.resize(w_verts.size())
	for i in w_verts.size():
		wv[i] = w_verts[i] * ws
	wa[Mesh.ARRAY_VERTEX] = wv
	wa[Mesh.ARRAY_NORMAL] = w_arrays[Mesh.ARRAY_NORMAL]
	wa[Mesh.ARRAY_TEX_UV] = w_uv
	wa[Mesh.ARRAY_INDEX] = w_arrays[Mesh.ARRAY_INDEX]
	w_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wa)
	var w_mat := StandardMaterial3D.new()
	w_mat.roughness = 0.9
	w_mat.albedo_texture = load("res://assets/third-party/kenney/carkit/Textures/colormap.png")
	w_mesh.surface_set_material(0, w_mat)
	w_mesh.set_meta("source_pack", SOURCE_PACK_CAR)
	w_mesh.set_meta("source_file", SOURCE_FILE_CAR)
	w_mesh.set_meta("license", LICENSE_CAR)
	var werr := ResourceSaver.save(w_mesh, CARS_DIR + "car_wheel.res")
	if werr != OK:
		push_error("BAKE car: wheel save failed")
		return werr
	## Wheel node placements (scaled + yaw-flipped node translations, seated
	## at the uniform wheel radius).
	var wheel_radius := 0.3 * ws
	for wheel_name in ["wheel-front-right", "wheel-front-left", "wheel-back-right", "wheel-back-left"]:
		var node := inst.find_child(wheel_name, true, false) as Node3D
		var p := rot * Vector3(node.position.x * s.x, wheel_radius, node.position.z * s.z)
		print("BAKE car wheel %s -> (%.3f, %.3f, %.3f)" % [wheel_name, p.x, p.y, p.z])
	## Body landmarks for the flag/cooler placement.
	print("BAKE car body aabb: ", _aabb_of(roles["paint"]["verts"]))
	inst.queue_free()
	return OK

func _aabb_of(verts: PackedVector3Array) -> AABB:
	var box := AABB(verts[0], Vector3.ZERO)
	for v: Vector3 in verts:
		box = box.expand(v)
	return box

func _flat_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _sample(img: Image, uv: Vector2) -> Color:
	var x := clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y)

## Color role from a colormap sample (the kit's palette chips): dark trim,
## bluish glass, bright neutral whites (lights), everything else paint.
func _color_role(c: Color) -> String:
	var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	if lum < 0.35:
		return "trim"
	if c.b > c.r + 0.04 and lum < 0.75:
		return "glass"
	if lum >= 0.75 and absf(c.r - c.b) < 0.12 and absf(c.r - c.g) < 0.12:
		return "lights"
	return "paint"

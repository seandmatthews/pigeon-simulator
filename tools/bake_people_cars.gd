extends SceneTree
## T-124 one-shot bake, CARS HALF ONLY since T-138: derives the game's car
## VISUAL meshes from the imported CC0 Kenney pack and writes them under
## assets/generated/models/cars/.
##
##   car    -> assets/third-party/kenney/carkit/sedan.glb
##             (Kenney Car Kit, CC0) — body triangles split by colormap
##             color role into paint/glass/trim/lights meshes; the paint mesh
##             is the per-class tint surface (T-113/T-121 overrides).
##
## The PEOPLE half of this tool is RETIRED (T-138): humans are no longer
## baked — every citizen rides the live rigged Quaternius skeleton through
## `scenes/people_rig.tscn`, prepared at import by `tools/import_people_rig.gd`
## (the per-part `sit_*`/`walk_*` pose bakes and the `animation/import=false`
## handling are gone). Cars stay baked — they are not humans.
##
## RUN MODE: `godot --headless --path . --script res://tools/bake_people_cars.gd`
## Output is committed: the car scene references these .res meshes, never the
## pack directly, so the physics-vs-visual contract stays hand-reviewed.

const CARS_DIR := "res://assets/generated/models/cars/"

## Car body box (the physics contract): 1.9 x 1.45 x 4.4. The Kenney sedan
## (1.5 wide x 1.15 tall body x 2.55 long in node space) stretches to fill
## length, keeps height, and squeezes width to the box; wheels scale uniformly.
const CAR_BOX := Vector3(1.9, 1.45, 4.4)

const SOURCE_PACK_CAR := "kenney-car-kit"
const SOURCE_FILE_CAR := "res://assets/third-party/kenney/carkit/sedan.glb"
const LICENSE_CAR := "CC0"

func _process(_delta: float) -> bool:
	## The bake needs a live SceneTree, so it runs on the first process
	## frame, not in setup.
	var failed := _bake_car() != OK
	print("BAKE DONE failed=", failed)
	return true ## Quit after this frame.


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

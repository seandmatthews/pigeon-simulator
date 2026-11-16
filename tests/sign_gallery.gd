extends Node3D
## The T-197 sign gallery (Gate 3 evidence rig): the four SignText typologies
## on a flat test placement, with a camera that steps through five fixed
## poses — the street-level triptych, then each typology at its own readable
## distance — every POSE_SECONDS, so a pilot session's periodic `shot`s catch
## each pose. Pure evidence staging: nothing here ships into the game world.

## Seconds each camera pose holds before stepping to the next.
const POSE_SECONDS := 3.5

## The five poses: [camera position, look-at target] — target chosen so each
## typology reads at roughly its pinned readable_distance from the mount.
const POSES: Array = [
	[Vector3(0.0, 3.0, 9.0), Vector3(0.0, 2.6, 0.0)], ## Triptych: box + blade + pole.
	[Vector3(4.6, 3.4, 3.6), Vector3(4.6, 3.5, 0.2)], ## Box close (mid budget ~60 m -> sidewalk read).
	[Vector3(0.4, 2.2, 2.2), Vector3(0.0, 2.0, 0.0)], ## Blade at eye level.
	[Vector3(2.4, 4.0, 8.0), Vector3(-4.4, 4.4, 0.0)], ## Pole cabinet from the drive-by side.
	[Vector3(-8.6, 2.7, 2.4), Vector3(-9.2, 2.6, 0.1)], ## Plaque at its close sidewalk read.
]

var _camera: Camera3D
var _clock: float = 0.0


func _ready() -> void:
	## Flat light ground — the placement slab.
	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(40.0, 0.2, 24.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.36, 0.38, 0.36)
	ground_mesh.material = ground_mat
	ground.mesh = ground_mesh
	ground.position = Vector3(-2.0, -0.1, 0.0)
	add_child(ground)
	## Sun.
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	add_child(sun)
	## The four typologies at their test mounts: the box on a wall stub, the
	## blade on a facade face, the pole standing on the slab, the plaque on
	## its own stub — each _ready-builds its own body from the component.
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(7.0, 5.0, 0.3)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.42, 0.38, 0.34)
	wall_mesh.material = wall_mat
	wall.mesh = wall_mesh
	wall.position = Vector3(0.0, 2.5, -0.45)
	add_child(wall)
	var box: SignText = (load("res://scenes/sign_box.tscn") as PackedScene).instantiate()
	box.position = Vector3(4.6, 3.5, -0.2)
	add_child(box)
	var blade: SignText = (load("res://scenes/sign_blade.tscn") as PackedScene).instantiate()
	blade.position = Vector3(0.0, 2.0, -0.2)
	add_child(blade)
	var pole: SignText = (load("res://scenes/sign_pole.tscn") as PackedScene).instantiate()
	pole.position = Vector3(-4.4, 0.0, 0.0)
	add_child(pole)
	var plaque_sign := SignText.new()
	plaque_sign.typology = SignText.Typology.PLAQUE
	plaque_sign.position = Vector3(-9.2, 2.6, -0.1)
	add_child(plaque_sign)
	_camera = Camera3D.new()
	_camera.fov = 65.0
	add_child(_camera)
	_apply_pose(0)


func _process(delta: float) -> void:
	_clock += delta
	_apply_pose(int(_clock / POSE_SECONDS) % POSES.size())


func _apply_pose(index: int) -> void:
	var pose: Array = POSES[index]
	_camera.position = pose[0]
	_camera.look_at(pose[1])

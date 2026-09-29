class_name OneShotBurst
extends GPUParticles3D
## One-shot juice burst (T-013): spawns already-emitting, fires its whole
## payload in one frame (the scenes are one_shot + fully explosive) and frees
## itself once its lifetime plus a burnout margin has elapsed. The cleanup is
## a plain `_process` countdown rather than GPUParticles3D.finished so it also
## runs in headless runs, where the particle simulation has no GPU clock to
## fire the finished signal. All three juice looks (splat burst, feather poof,
## dust puff) share this script; the scenes carry the meshes and materials.

## Extra seconds past `lifetime` before the node frees itself.
@export var burnout_margin: float = 0.25

var _age: float = 0.0


func _ready() -> void:
	add_to_group("juice_effects") ## Tests and the autoplay DONE line count these.
	emitting = true


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime + burnout_margin:
		queue_free()


## Deterministic orthonormal basis with +Y along `dir` — the same trick the
## splat decal uses, so a burst leaves along the surface it hit.
static func basis_from_dir(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var helper := Vector3.RIGHT if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.BACK
	var x := helper.cross(y).normalized()
	var z := y.cross(x).normalized()
	return Basis(x, y, z)

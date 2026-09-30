class_name CafeSitter
extends StaticBody3D
## One seated cafe sitter (T-031): a static layer-3 `npc` person on a stool at
## a sidewalk cafe table — the T-020 elder body pattern (`StaticBody3D`,
## layer 3 `npc`, mask 0, so the grounded pigeon can waddle up and perch beside
## them) dressed tourist-style instead: shirt and arms in
## `Tourist.SHIRT_PALETTE` colors, the tourists' skin, seated at stool height
## with thighs forward under the table. Sitters are street dressing: they
## don't walk, don't panic, don't share bread — the loop-walkers (T-007) and
## the elders (T-020) own the behaviors. Zero RNG: the table assigns the shirt
## by its spot index before `_ready`.

## Shirt tint — the table assigns it before _ready (index-based, no RNG).
var shirt_color: Color = Tourist.SHIRT_PALETTE[0]

@onready var _torso: MeshInstance3D = $Visual/Torso
@onready var _arm_l: MeshInstance3D = $Visual/ArmL
@onready var _arm_r: MeshInstance3D = $Visual/ArmR


func _ready() -> void:
	## Per-sitter shirt material: the palette tint, without touching the shared
	## scene material (the tourist's and elder's pattern). Skin and hair stay
	## the scene materials — every sitter shares them.
	var mat: StandardMaterial3D = _torso.mesh.surface_get_material(0).duplicate()
	mat.albedo_color = shirt_color
	_torso.material_override = mat
	_arm_l.material_override = mat
	_arm_r.material_override = mat

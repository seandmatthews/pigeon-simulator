class_name PeopleRig
extends Node3D
## The ONE shared rigged people visual (T-138): every human in the city — all
## four tourist classes and the elders — wears this scene, an instance of the
## Quaternius Universal Base Character (`assets/third-party/quaternius/base_character.glb`)
## whose import (`tools/import_people_rig.gd`) keeps the live 53-joint
## skeleton, prunes the animation library to the six whitelisted clips (the
## T-124-banned clips are pruned at import and exist nowhere in the packed
## game) and splits the mannequin into Body/Legs/ArmL skinned parts (the
## T-113 per-class `material_override` surfaces) plus rigid HeadRigid /
## ArmLRigid / ArmRRigid parts hanging off BoneAttachment3D mounts.
##
## Scripts keep driving behavior; this class only drives the CLIPS and the
## script-owned arm poses on top of them:
## - `play_locomotion()` / `play_clip()` — clip choice + play rate. Walk and
##   sprint rates are derived from the clips' own stride (the probe-measured
##   ground per cycle), so feet track the move speed without skating.
## - `set_arm_pose()` — eases an arm between the clip's swing (raise 0) and a
##   world-aimed raised pose (raise 1: the panic raise, the foam-finger
##   baseline, the elder's T-078 trust arm), cancelling the bone swing so a
##   raised arm points up steady. `shake` swings a raised arm about the body's
##   right axis (the tourist fist shake).
## - `show_rigid_arms()` — the tourist raises BOTH rigid arms (the far skinned
##   ArmL hides); the elder raises only the near rigid right arm and leaves
##   the far arm on the skinned ArmL riding the clips.
## - `mount_prop()` — parents scene props (the tourist's mitt and cap, the
##   elder's hair) onto the head/hand bone slots. `adopt()` takes a static
##   prop (the elder's cane) into the bob/lean container.
##
## The Model child scales the pack's native 1.78 m figure to the adult
## envelope: head top ≈ 1.75 m over feet at 0 (the furniture probe: 2.05 m
## shop doors, 0.60 m bench seats, 0.78 m café tabletops, the 2.0 m plaza
## plinth). The physics capsule grows with the visual — it is the splat
## surface (tourist/elder CapsuleShape3D r 0.28 / h 1.75 at y 0.875).

## The imported clip whitelist — mirrored from `tools/import_people_rig.gd`
## (this script never loads tools scripts; the T-124 bake precedent).
const CLIP_IDLE := "Rig|Idle"
const CLIP_WALK := "Rig|Walk"
const CLIP_SPRINT := "Rig|Sprint"
const CLIP_SITTING_IDLE := "Rig|Sitting_Idle"
const CLIP_SITTING_ENTER := "Rig|Sitting_Enter" ## Stand → sit (ARRIVING).
const CLIP_SITTING_EXIT := "Rig|Sitting_Exit" ## Sit → stand (RISING).
## The packed-game clip whitelist — mirrored from `tools/import_people_rig.gd`
## (the import prunes to exactly this; pinned by the people_on_one_rig scenario).
const CLIPS_WHITELIST: Array[String] = [
	CLIP_IDLE, CLIP_WALK, CLIP_SPRINT,
	CLIP_SITTING_IDLE, CLIP_SITTING_ENTER, CLIP_SITTING_EXIT,
]
const LOOPED_CLIPS: Array[String] = [
	CLIP_IDLE, CLIP_WALK, CLIP_SPRINT, CLIP_SITTING_IDLE,
]

## Probe-measured clip strides/lengths (T-138 probes, 2026-10-26): the ground
## distance one loop covers at the clip's natural pace. The rate law:
## `speed × seconds / stride` keeps the feet planted relative to the move.
const WALK_STRIDE := 1.3239
const WALK_SECONDS := 1.3333
const SPRINT_STRIDE := 2.1333
const SPRINT_SECONDS := 0.6667
const SITTING_ENTER_SECONDS := 1.2917
const SITTING_EXIT_SECONDS := 1.0

## The crossfade between clips (the pigeon visual's _STATE_BLEND convention).
const CLIP_BLEND := 0.18

## Arm sides for `set_arm_pose`.
const ARM_L := 0
const ARM_R := 1

enum Mount { HEAD, HAND_R }

## The adult envelope (probe-measured, 2026-10-26): the pack's native figure
## stands 1.7828 m (head top 1.7698 / feet −0.0130, skeleton origin −0.0136),
## so this scale + drop pins head top 1.7507 m over feet at 0. Kept in sync
## with scenes/people_rig.tscn's Model transform.
const ADULT_HEAD_TOP := 1.7507
const ADULT_SCALE := 0.982
const ADULT_DROP := -0.0006
## Head bone origin → head top, unscaled (probe-measured: 1.7698 − 1.5126).
const HEAD_BONE_TO_TOP := 0.2572

## The raised-arm aim: the arm mesh's long axis is its bind-frame +Y
## (shoulder → hand, probe-measured), so the raise tips that axis up with a
## slight forward lean (−11° about the body's right axis; forward is −Z) — a
## raised arm reads as presented, not bolted vertical.
const RAISE_TILT := -0.1974

## Head prop placement: the mount slot's world-space correction runs once the
## Idle pose has landed (frame 1); props then sit at this lift above the
## corrected head-top line (m, adult scale).
const HEAD_PROP_LIFT := 0.04

@export_group("Slots")
@export var head_prop_lift: float = HEAD_PROP_LIFT ## Head props' lift above the corrected head top.

## True once the frame-1 mount correction has run (head slot + prop yaw).
var _mounts_settled: bool = false
var _head_props: Array[Node3D] = []
var _current_clip: String = ""

@onready var model: Node3D = $Model
@onready var _skeleton: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var body_mesh: MeshInstance3D = _find_part("Body")
@onready var legs_mesh: MeshInstance3D = _find_part("Legs")
@onready var arm_skinned_l: MeshInstance3D = _find_part("ArmL")
@onready var head_rigid: MeshInstance3D = _find_part("HeadRigid")
@onready var arm_l_rigid: MeshInstance3D = _find_part("ArmLRigid")
@onready var arm_r_rigid: MeshInstance3D = _find_part("ArmRRigid")
@onready var head_slot: Node3D = _find_part("HeadTop")
@onready var hand_r_slot: Node3D = _find_part("HandR")


func _ready() -> void:
	if anim != null:
		for clip_name: String in LOOPED_CLIPS:
			if anim.has_animation(clip_name):
				anim.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		play_clip(CLIP_IDLE, 1.0, 0.0)


func _process(_delta: float) -> void:
	if _mounts_settled:
		return
	## Frame 1: the Idle pose has landed — pin the head slot to the real
	## adult head top (the bind-space slot is close but not world-exact) and
	## align mounted head props to the body yaw (the bone frame is neither
	## world-aligned nor meter-scaled).
	_mounts_settled = true
	if head_slot != null:
		var frame := head_slot.get_parent() as Node3D
		var bone_world := frame.global_transform * Vector3.ZERO
		var slot_world := head_slot.global_transform.origin
		var want := Vector3(bone_world.x,
				bone_world.y + HEAD_BONE_TO_TOP * ADULT_SCALE + head_prop_lift,
				bone_world.z)
		head_slot.position += frame.global_transform.basis.inverse() \
				* (want - slot_world)
		for prop: Node3D in _head_props:
			_align_prop_yaw(prop, frame)


## Aligns a head prop's basis to the body yaw (a one-time compensation — the
## prop then rides the rigid head; the head bone's idle sway is invisible).
func _align_prop_yaw(prop: Node3D, frame: Node3D) -> void:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var yaw := Basis(Vector3.UP, atan2(-fwd.x, -fwd.z))
	prop.basis = Basis(frame.global_transform.basis.orthonormalized() \
			.get_rotation_quaternion().inverse()) * yaw


## Finds an imported part/mount by name anywhere under the instance.
func _find_part(node_name: String) -> Node3D:
	return find_child(node_name, true, false) as Node3D


## --- clips --------------------------------------------------------------------


## The play rate that walks `speed` m/s without skating: ground per cycle
## (stride) over the clip's length, times the speed.
static func walk_rate(speed: float) -> float:
	return speed * WALK_SECONDS / WALK_STRIDE


## Same law for the sprint (the panic clip).
static func sprint_rate(speed: float) -> float:
	return speed * SPRINT_SECONDS / SPRINT_STRIDE


## Picks the locomotion clip from the horizontal speed: Sprint while
## panicking, Walk while strolling, Idle standing — each rate-matched.
func play_locomotion(speed: float, sprinting: bool) -> void:
	if speed > 0.2:
		if sprinting:
			play_clip(CLIP_SPRINT, sprint_rate(speed))
		else:
			play_clip(CLIP_WALK, walk_rate(speed))
	else:
		play_clip(CLIP_IDLE, 1.0)


## Crossfades to `clip` at `rate` (no-op when already current — the rate
## still updates, so rate-matching survives the dedupe).
func play_clip(clip: String, rate: float = 1.0, blend: float = CLIP_BLEND) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	anim.speed_scale = rate
	if clip == _current_clip:
		return
	_current_clip = clip
	anim.play(clip, blend)


## --- arms ---------------------------------------------------------------------


## The citizen layout: the near RIGHT arm is rigid and visible for BOTH
## citizens — the tourist's panic raise / foam finger and the elder's T-078
## trust arm drive the same node. The tourist additionally shows the rigid
## left (and hides the skinned ArmL — no doubled geometry); the elder keeps
## the skinned ArmL riding the clips (the far arm) and the rigid left hidden.
func show_rigid_arms(shown: bool) -> void:
	if arm_skinned_l != null:
		arm_skinned_l.visible = not shown
	if arm_l_rigid != null:
		arm_l_rigid.visible = shown
	if arm_r_rigid != null:
		arm_r_rigid.visible = true


## Eases `arm` between the clip's own swing (raise 0 → the node rides the
## BoneAttachment3D untouched) and the world-aimed raise (raise 1: the long
## axis tips up along RAISE_DIRECTION, the bone swing cancelled so a raised
## arm — foam finger, panic flail, trust meter — points up steady). `shake`
## swings a raised arm about the body's right axis (the fist shake).
func set_arm_pose(arm: int, raise: float, shake: float = 0.0) -> void:
	var node := arm_l_rigid if arm == ARM_L else arm_r_rigid
	if node == null:
		return
	if raise <= 0.0 and is_zero_approx(shake):
		node.transform = Transform3D.IDENTITY
		return
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var yaw := Basis(Vector3.UP, atan2(-fwd.x, -fwd.z))
	var world := yaw * Basis(Vector3.RIGHT, shake + RAISE_TILT)
	## The arm node lives in its Frame's space (the 0.01-scale meters frame
	## under the mount) — invert THAT, not the raw mount chain.
	var frame := node.get_parent() as Node3D
	var local := frame.global_transform.basis.inverse() * world
	if raise >= 1.0:
		node.basis = local
	else:
		node.basis = Basis(Quaternion.IDENTITY.slerp(
				local.orthonormalized().get_rotation_quaternion(),
				clampf(raise, 0.0, 1.0)))


## --- props --------------------------------------------------------------------


## Parents a scene prop onto a bone mount slot (the tourist's mitt on HandR,
## the cap and the elder's hair on the head).
func mount_prop(prop: Node3D, mount: Mount) -> void:
	var slot := head_slot if mount == Mount.HEAD else hand_r_slot
	if slot == null:
		return
	var old := prop.get_parent()
	if old != null:
		old.remove_child(prop)
	slot.add_child(prop)
	prop.position = Vector3.ZERO
	if mount == Mount.HEAD:
		_head_props.append(prop)
		if _mounts_settled:
			_align_prop_yaw(prop, slot.get_parent() as Node3D)
	## (The mitt needs no extra rotation: its +Y matches the arm mesh's long
	## axis, so a raised foam finger reads straight up.)


## Takes a static prop (the elder's cane) into the bob/lean container so it
## rides the figure's cosmetics.
func adopt(prop: Node3D) -> void:
	var old := prop.get_parent()
	if old != null:
		old.remove_child(prop)
	add_child(prop)

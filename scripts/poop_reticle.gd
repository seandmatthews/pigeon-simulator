class_name PoopReticle
extends Node3D
## The one persistent poop target (T-105), replacing T-046's per-drop ring: a
## single reticle owned by the run — ring + center dot + four cardinal ticks in
## the EOTech grammar — that shows where a poop release would land. Two modes,
## ONE shape (a real reticle never changes shape, only brightness): LIVE while
## airborne with no drop in flight continuously re-marches a hypothetical
## release from the player's exact release point and velocity (~30 Hz, coarse
## step); FROZEN (lock_to, driven by Main on the pooped signal) pins the
## released drop's predicted impact until that drop splats or expires, then
## resumes LIVE — a press mid-flight re-snaps to the newest drop by
## construction. The reticle never frees mid-run — persistence is the point —
## so restart_run() needs no special case: it frees the locked drop and the
## validity poll flips the reticle home on its own. Visual only: no physics
## nodes of its own (the PoopMarker precedent), so the falling ball can never
## collide with it. The march is T-046's analytic one FIXED for aiming (the
## aiming contract): every predicted point uses the damped closed form under
## the drop's own exports — the live body carries the project
## default_linear_damp, so the deliberately undamped T-046 ring plotted every
## lob ~1.3–1.5 m long; as an aiming device the prediction must match reality.
## Driven entirely in _physics_process (fixed 60 Hz ticks — deterministic under
## --fixed-fps, frozen under pause like every physics-driven thing).

enum Mode { LIVE, FROZEN }

@export_group("Reticle")
@export var surface_lift: float = 0.03 ## Offset along the hit normal so the reticle clears z-fighting (m) — the marker's landed value.
@export var dim_alpha: float = 0.25 ## Albedo alpha while the poop cooldown runs — the same 0.25 as Main.POOP_READY_DIM_ALPHA (the T-077 dim convention, duplicated so the reticle stays decoupled from Main).
@export var poop_scene: PackedScene = preload("res://scenes/poop.tscn") ## Instantiated-not-added once in _ready, read (g/lifetime), freed — the real exports, never mirrored constants.
@export var player_path: NodePath ## The pigeon to predict for — Main wires it in main.tscn; empty in bare rigs, where live mode idles and frozen mode still works.

@export_group("Prediction")
@export var frozen_march_step: float = 0.05 ## Fixed dt (s) of the one-shot locked march — T-046's landed step.
@export var live_march_step: float = 0.1 ## Fixed dt (s) of the live hypothetical march — coarser; live re-marches every live_refresh_hz, so its cumulative ray volume far exceeds the frozen one-shot.
@export var live_refresh_hz: float = 30.0 ## Live re-march rate (Hz) — every Nth physics tick of the fixed 60 Hz step; whole ticks only, so 24 would resolve to 20.
@export var world_mask: int = 1 ## Collision layers the march ray may hit: the world. Never bodies (player, targets, the drop itself).

## The driver state: frozen holds a pin from lock_to()'s snapshot; live marches
## the hypothetical release.
var _mode: Mode = Mode.LIVE
var _locked: Poop ## The frozen-mode drop; freed (splat or max_lifetime expiry) ends the freeze.
var _p0: Vector3 = Vector3.ZERO ## The point the march predicts from — the drop's release (frozen) or the hypothetical release point (live).
var _v0: Vector3 = Vector3.ZERO
var _gravity: float = 12.0 ## The drop's fall_gravity — read fresh at lock_to, template value for live.
var _damp: float = 0.1 ## The effective linear damp the live body actually carries — the project default; Poop sets none.
var _max_lifetime: float = 12.0 ## March horizon — the drop's max_lifetime, read fresh at lock_to / template in _ready.
var _marched := true ## The frozen march is one-shot: first physics frame after lock_to() (space queries are illegal mid-step).
var _pinned := false ## The last march found a surface; a lob off the world unpins and hides the reticle.
var _ticks_since_refresh: int = 0 ## Live-mode cadence counter, physics ticks.
var _refresh_ticks: int = 6 ## Ticks per live re-march — physics_ticks_per_second / live_refresh_hz, resolved in _ready.
var _mat: StandardMaterial3D ## The one duplicated material all six meshes share — the dim write is this single alpha.
var _player: Player ## The prediction subject (player_path); null in bare rigs.

@onready var _ring: MeshInstance3D = %Ring
@onready var _dot: MeshInstance3D = %Dot
@onready var _ticks: Array[MeshInstance3D] = [%TickN, %TickS, %TickE, %TickW]


## True while the reticle holds the released drop's pin (frozen mode) — the
## machine-observable mode for the sim harness.
var is_frozen: bool:
	get: return _mode == Mode.FROZEN


func _ready() -> void:
	add_to_group("poop_reticles") ## The harness counts persistence through it; Main never frees by it.
	_player = get_node_or_null(player_path) as Player
	## g/lifetime from the real drop exports — instantiate-not-added, read, free.
	var probe: Poop = poop_scene.instantiate()
	_gravity = probe.fall_gravity
	_max_lifetime = probe.max_lifetime
	probe.free()
	## The drop's effective linear damp: Poop sets none, so the live body carries
	## the project default (stock 0.1) — the aiming contract's `d`.
	_damp = float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	_refresh_ticks = maxi(1, roundi(float(Engine.physics_ticks_per_second) / live_refresh_hz))
	## One duplicated material shared by all children, so the dim write is one
	## property (the poop.gd decal pattern).
	_mat = _ring.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	_ring.material_override = _mat
	_dot.material_override = _mat
	for tick in _ticks:
		tick.material_override = _mat
	visible = false ## Hidden until a march finds a surface to sit on (and whenever grounded).


## Freeze onto `drop` — called by Main's pooped handler (mid physics step, the
## T-046 track() shape): snapshot the release conditions ONCE; the march itself
## waits for the next physics frame, the one place space queries are legal. A
## press mid-flight re-snaps to the newest drop by construction — the handler
## fires per press and overwrites the snapshot.
func lock_to(drop: Poop) -> void:
	_locked = drop
	_p0 = drop.global_position
	_v0 = drop.linear_velocity
	_gravity = drop.fall_gravity
	_max_lifetime = drop.max_lifetime
	_mode = Mode.FROZEN
	_marched = false


func _physics_process(_delta: float) -> void:
	## Frozen expiry: the locked drop freed itself — splat or max_lifetime
	## expiry, indistinguishable and both end-of-job (the T-046 honest read).
	## The reticle itself NEVER frees; it resumes live on the spot.
	if _mode == Mode.FROZEN and not is_instance_valid(_locked):
		_locked = null
		_mode = Mode.LIVE
		_ticks_since_refresh = _refresh_ticks ## Refresh live immediately.
	if _mode == Mode.LIVE and _player != null:
		_ticks_since_refresh += 1
		if _ticks_since_refresh >= _refresh_ticks:
			_ticks_since_refresh = 0
			## The exact point _try_poop would spawn at, and the velocity it
			## would inherit — the hypothetical release.
			var p := _player.global_position \
					- _player.global_transform.basis.y * _player.poop_drop_offset
			var v := _player.velocity
			if p != _p0 or v != _v0: ## Changed-value guard: a still pigeon re-marches nothing.
				_p0 = p
				_v0 = v
				_march(live_march_step)
	elif _mode == Mode.FROZEN and not _marched:
		_marched = true
		_march(frozen_march_step) ## One-shot: the pin then holds absolutely — no chase, no re-march.
	_update_visuals()


## The march (the T-046 shape): exact arc points at t and t + step (no Euler
## accumulation — every segment endpoint lies ON the analytic arc), one world
## ray per step, first hit seats the reticle on the surface along its normal.
## No hit within the lifetime (a lob past the city edge) unpins — the honest
## "no predicted ground" answer.
func _march(step: float) -> void:
	var s := maxf(step, 0.005) ## A non-positive step would never advance.
	var t := 0.0
	var space := get_world_3d().direct_space_state
	while t < _max_lifetime:
		var t_next := minf(t + s, _max_lifetime)
		var query := PhysicsRayQueryParameters3D.create(
				_point_at(t), _point_at(t_next), world_mask)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var normal: Vector3 = hit["normal"]
			global_transform = Transform3D(_basis_from_normal(normal),
					hit["position"] + normal * surface_lift)
			_pinned = true
			return
		t = t_next
	_pinned = false


## The analytic point at t under the aiming contract — the damped closed form
## `p(t) = p0 + (v0 − G/d)·(1 − e^(−d·t))/d + (G/d)·t` with G = (0, −g, 0) and
## d the effective linear damp the live body actually carries. This is the
## T-105 fix over T-046's deliberately undamped parabola, whose ring landed
## ~1.3–1.5 m long of the real splat at lob range. Guard d ≈ 0 back to the
## pure parabola (the T-046 form).
func _point_at(t: float) -> Vector3:
	if _damp > 0.0001:
		var k := (1.0 - exp(-_damp * t)) / _damp
		var g_over_d := Vector3.DOWN * (_gravity / _damp)
		return _p0 + (_v0 - g_over_d) * k + g_over_d * t
	return _p0 + _v0 * t + Vector3.DOWN * (0.5 * _gravity * t * t)


## Visibility & brightness (both writes changed-value-guarded — idle frames
## touch nothing): grounded hides the reticle entirely (pooping is air-only);
## airborne shows it whenever a pin exists, dimmed to `dim_alpha` while the
## poop cooldown runs (the T-077 dim convention — real sights dim, never
## vanish) and full when rested. No restart-specific code: restart_run() frees
## the locked drop, reset_flight returns the player to AIR with a zeroed
## cooldown, and the next tick here drives the right state.
func _update_visuals() -> void:
	var grounded: bool = _player != null and _player.is_grounded
	var want_visible := _pinned and not grounded
	if visible != want_visible:
		visible = want_visible
	var want_alpha := dim_alpha if (_player != null and not _player.poop_ready) else 1.0
	if not is_equal_approx(_mat.albedo_color.a, want_alpha):
		_mat.albedo_color.a = want_alpha


## Deterministic orthonormal basis with +Y along the surface normal — the
## reticle's orientation on any wall, roof or floor (the poop.gd decal helper).
func _basis_from_normal(normal: Vector3) -> Basis:
	var helper := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := helper.cross(normal).normalized()
	var z := x.cross(normal).normalized()
	return Basis(x, normal, z)

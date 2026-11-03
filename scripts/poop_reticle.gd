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
## Since T-158 the live pin also carries a TARGET TELL: at each live re-march
## that seats a pin, one sphere query on the citizen body layers asks what
## stands under it, and a citizen-classed body tints the ring the favor color
## that body would pay — the same gold/red vocabulary the post-hit readout
## speaks — with the class word on a small billboard above the pin. FROZEN
## never queries and forces neutral: the drop is committed, and coloring a
## committed pin would claim a guarantee about a target the ball may miss.
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

@export_group("Target tell") ## (T-158) What the pin stands on, in the post-hit readout's own vocabulary.
@export var tell_body_mask: int = 12 ## Citizen body layers the tell sphere may hit: npc + vehicle (3 | 4). The march itself stays world-only per world_mask — the tell queries bodies, the march never does.
@export var tell_query_radius: float = 1.0 ## Tell sphere radius (m) at the pin point — it must reach past the surface: the pin lands on the GROUND (the march ray can't hit bodies), so a parked car's hull sits beside the pin, not under it. Feel value — Gate 3.
@export var tell_gain_color: Color = Color(1.0, 0.85, 0.3) ## Ring tint over a VISITOR — the exact MainGame.FAVOR_GAIN_COLOR, duplicated so the reticle stays decoupled from Main (the dim_alpha precedent).
@export var tell_loss_color: Color = Color(1.0, 0.32, 0.25) ## Ring tint over a CIVILIAN or SUPERFAN — the exact MainGame.FAVOR_LOSS_COLOR, duplicated so the reticle stays decoupled from Main.

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
var _mat: StandardMaterial3D ## The duplicated material the dot + ticks share — the dim write is this single alpha (T-158 split the ring onto its own material so the tell tint can't recolor them).
var _ring_mat: StandardMaterial3D ## (T-158) The Ring's own duplicated material — the dim writes alpha here too (the harness alpha read goes through this override), the tell tints rgb.
var _ring_neutral := Color(0.94, 0.9, 0.78) ## The scene albedo rgb — read off the Ring's own material in _ready, never a duplicated literal.
var _tell_class: int = -1 ## (T-158) The CitizenClass.Kind the tell last named under the pin, or −1 neutral — the changed-value guard for both tint writes.
var _tell_shape: SphereShape3D ## (T-158) The tell query's sphere — built once in _ready at tell_query_radius.
var _player: Player ## The prediction subject (player_path); null in bare rigs.

@onready var _ring: MeshInstance3D = %Ring
@onready var _dot: MeshInstance3D = %Dot
@onready var _ticks: Array[MeshInstance3D] = [%TickN, %TickS, %TickE, %TickW]
@onready var _class_word: Label3D = %ClassWord


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
	## Two duplicated materials (the T-158 split): the Ring gets its own so the
	## tell tint recolors the ring alone, dot + ticks share the other — the dim
	## write drives BOTH alphas. The tell's neutral rgb is the scene value, read
	## off the ring's own material, never a duplicated literal.
	var ring_mesh_mat := _ring.mesh.surface_get_material(0) as StandardMaterial3D
	_ring_neutral = Color(ring_mesh_mat.albedo_color.r,
			ring_mesh_mat.albedo_color.g, ring_mesh_mat.albedo_color.b)
	_ring_mat = ring_mesh_mat.duplicate() as StandardMaterial3D
	_ring.material_override = _ring_mat
	_mat = _dot.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	_dot.material_override = _mat
	for tick in _ticks:
		tick.material_override = _mat
	_tell_shape = SphereShape3D.new()
	_tell_shape.radius = tell_query_radius
	visible = false ## Hidden until a march finds a surface to sit on (and whenever grounded).


## Freeze onto `drop` — called by Main's pooped handler (mid physics step, the
## T-046 track() shape): snapshot the release conditions ONCE; the march itself
## waits for the next physics frame, the one place space queries are legal. A
## press mid-flight re-snaps to the newest drop by construction — the handler
## fires per press and overwrites the snapshot. (T-158) The tell forces
## neutral here and never queries while frozen — the drop is committed, and
## coloring a committed pin would claim a guarantee about a target the ball
## may miss. Pure state+material writes: no space query on this mid-step path.
func lock_to(drop: Poop) -> void:
	_locked = drop
	_p0 = drop.global_position
	_v0 = drop.linear_velocity
	_gravity = drop.fall_gravity
	_max_lifetime = drop.max_lifetime
	_mode = Mode.FROZEN
	_marched = false
	_set_tell(-1)


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
			if _mode == Mode.LIVE: ## (T-158) The tell rides LIVE re-marches only — a seated live pin asks what stands under it; FROZEN never queries.
				_query_tell()
			return
		t = t_next
	_pinned = false
	if _mode == Mode.LIVE: ## (T-158) No predicted ground, no target claim — neutral until the next seated pin.
		_set_tell(-1)


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
	if not is_equal_approx(_ring_mat.albedo_color.a, want_alpha):
		_ring_mat.albedo_color.a = want_alpha ## (T-158) The ring's own material carries the dim too — the harness alpha read goes through this override.


## (T-158) The tell query: one sphere at the seated pin, citizen body layers
## only (tell_body_mask — the march itself stays world-only). The FIRST
## collider that answers the duck-typed `citizen_class` names the pin —
## tourists and cars carry it (scripts/tourist.gd, scripts/car.gd), elders and
## the pigeon claim nothing — so a body under the pin with no class reads
## neutral. The query claims the first citizen-classed collider, not
## best-of-crowd disambiguation, and refreshes only per re-march.
func _query_tell() -> void:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _tell_shape
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = tell_body_mask
	var hits := space.intersect_shape(params, 8)
	var kind := -1
	for hit in hits:
		var collider: Object = hit["collider"]
		if collider == null:
			continue
		var value: Variant = collider.get("citizen_class")
		if value != null:
			kind = int(value)
			break
	_set_tell(kind)


## (T-158) Apply the tell: tint the ring's albedo rgb — ALPHA STAYS OWNED BY
## THE DIM LOGIC, the tell tints rgb only — and show the class word above the
## pin in the same color while a tell is active. Both writes changed-value
## guarded (the T-055 rule): idle tells touch nothing.
func _set_tell(kind: int) -> void:
	if kind == _tell_class:
		return
	_tell_class = kind
	var tint := _ring_neutral
	var word := ""
	if kind == CitizenClass.Kind.VISITOR:
		tint = tell_gain_color
		word = CitizenClass.label(CitizenClass.Kind.VISITOR)
	elif kind == CitizenClass.Kind.CIVILIAN or kind == CitizenClass.Kind.SUPERFAN:
		tint = tell_loss_color
		word = CitizenClass.label(kind as CitizenClass.Kind)
	var rgb_changed := not is_equal_approx(_ring_mat.albedo_color.r, tint.r) \
			or not is_equal_approx(_ring_mat.albedo_color.g, tint.g) \
			or not is_equal_approx(_ring_mat.albedo_color.b, tint.b)
	if rgb_changed:
		_ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, _ring_mat.albedo_color.a)
	if word == "":
		if _class_word.visible:
			_class_word.visible = false
	else:
		if _class_word.text != word:
			_class_word.text = word
		var word_tint := Color(tint.r, tint.g, tint.b, 1.0)
		if not _class_word.modulate.is_equal_approx(word_tint):
			_class_word.modulate = word_tint
		if not _class_word.visible:
			_class_word.visible = true


## Deterministic orthonormal basis with +Y along the surface normal — the
## reticle's orientation on any wall, roof or floor (the poop.gd decal helper).
func _basis_from_normal(normal: Vector3) -> Basis:
	var helper := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := helper.cross(normal).normalized()
	var z := x.cross(normal).normalized()
	return Basis(x, normal, z)

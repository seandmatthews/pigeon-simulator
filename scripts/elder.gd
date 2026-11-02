class_name Elder
extends CharacterBody3D
## One seated park elder (T-020): a layer-3 `npc` grandparent on a plaza
## bench, built from the same hand-placed low-poly primitives as the tourist
## (T-007). A PresenceZone around the bench watches for the pigeon (layer 2):
## a GROUNDED pigeon inside it (the bread crumb's land-and-peck rule, T-005)
## fills `_trust` at 1.0/s; with nobody present it decays — a fly-through
## banks nothing, a brief walk-away doesn't wipe progress. At `trust_needed`
## the elder shares: `crumbs_per_share` ordinary T-005 crumbs tossed to the
## pavement in front of them through `BreadSpawner.drop_crumb()`, then a long
## `share_cooldown` — a friend, not an infinite buffet. The near arm is the
## trust meter (T-078): it eases up with the banked trust while the pigeon
## hangs out, stays down through the share cooldown even though trust has
## already refilled, and sweeps up for the share beat.
## Since T-137 (the grandpa shuffle) the elder is a CharacterBody3D (the
## tourist's body config) that MIGRATES after every share: the spawner
## reserves a different-district bench (a deterministic hash of the run seed
## and the elder's cumulative share count — no RNG stream), the elder stands
## (RISING), shuffles there on the sidewalk rings and the pinned crosswalk
## bands (WALKING, pausing at every curb while a car is within
## `curb_car_radius` AND closing — cars never yield, CURB_WAIT) and settles
## onto the reserved bench (ARRIVING). Trust accrues only while SEATED —
## mid-walk the bank is frozen (no accrual, no decay). Elders still don't
## react to splats or buzzes (that is the tourists' job).
## Since T-138 the visual is the ONE shared rigged people scene (`Visual`, a
## PeopleRig — the same model as the tourists): the shuffle walks the live
## `Rig|Walk` clip rate-matched to the 0.8 m/s pace, RISING/ARRIVING play the
## library's stand-up/sit-down transition clips, SEATED holds `Rig|Sitting_Idle`
## with the figure sunk so the sit pose's hips rest on the 0.60 m bench seat.
## The near trust arm is the rig's rigid right arm on its BoneAttachment3D —
## `_arm_raise` drives it exactly as it drove the static part (T-078); the
## far arm rides the skinned clips. The bob and the bench-hunch comedy layer
## stay.

## Fired on every share — the spawner relays it as `bread_shared` (the
## CaptureRecorder's `elder_bread_shared` event listens there).
signal shared(elder: Elder, crumbs: int)

## Fired when a migration completes (T-137): the elder is SEATED on its new
## bench — the spawner re-books the seat registry and relays `elder_relocated`
## from here (the T-095 pilot-event precedent).
signal arrived(elder: Elder)

## The shuffle states (T-137): SEATED banks trust and shares; RISING stands
## off the bench; WALKING follows the route legs; CURB_WAIT holds at a curb
## while any car is within `curb_car_radius` and closing; ARRIVING settles
## onto the reserved bench.
enum State { SEATED, RISING, WALKING, CURB_WAIT, ARRIVING }

## Muted cardigan colors — the spawner assigns one per elder by index, so
## four elders around the ring read as four different grandparents with no
## RNG anywhere.
const CARDIGAN_PALETTE: Array[Color] = [
	Color(0.42, 0.55, 0.52), ## Faded teal.
	Color(0.62, 0.48, 0.38), ## Warm tan.
	Color(0.70, 0.35, 0.26), ## Warm rust (T-048) — the old dusty lilac sat 0.12 from the sidewalk gray and plaza elders washed out at range.
	Color(0.48, 0.52, 0.42), ## Sage.
]
const SKIN := Color(0.87, 0.68, 0.55) ## Same skin family as the tourists (T-007).
const HAIR := Color(0.78, 0.78, 0.75) ## Gray/white hair — the elder giveaway.
const SEAT_HEIGHT := 0.60 ## Bench seat top above the slab — the `_add_bench` math.
const CRUMB_LIFT := 0.06 ## Tossed crumbs rest at the same height as bread-spot ring crumbs.
const HUNCH_SEATED := 0.04 ## (T-141) A whisper of the grandpa slump — the T-020 primitive-era 0.18 folded the whole rigged figure forward off the real sit clip (its root pitch also sank the hips 0.067; the sink below is derived WITH this pitch).
const HUNCH_WALKING := 0.06 ## Nearly upright mid-shuffle — "upright, bobbing" (T-137).
## (T-141) The seated sink: the pack's sit clip holds its DEF-hips BONE
## 0.5179 m above the rig root (probe-measured, adult scale 0.982), and the
## seat-contact point is the glute underside ~0.105 below that bone on the
## 1.75 m adult figure — NOT the bone itself (the T-138 −0.511 derivation
## treated the bone as the contact, a child-scale habit from the retired
## 1.22 m bake, and buried the pelvis ~0.16 into the slab). Sinking
## −0.399 with the 0.04 hunch (its root pitch drops the hips a measured
## 0.0136) lands the hips bone at seat + 0.105: glute kisses the 0.60 m
## seat plane. Feet follow to ~0.29 above the pavement — the pack's sit
## pose is built for a ~0.45 m chair; the dangle is the accepted read.
const SEAT_SINK := -0.399

@export_group("Trust")
@export var proximity_radius: float = 3.0 ## PresenceZone radius (m) around the bench.
@export var trust_fill_rate: float = 1.0 ## Trust per second while a GROUNDED pigeon is present.
@export var trust_decay: float = 2.0 ## Trust per second while nobody is present.
@export var trust_needed: float = 4.0 ## Seconds of company before the elder shares.

@export_group("Sharing")
@export var crumbs_per_share: int = 2 ## Ordinary T-005 crumbs tossed per share.
@export var toss_distance: float = 1.2 ## Forward distance (m) from the elder the crumbs land at.
@export var toss_spread: float = 0.4 ## Sideways spread (m) — crumbs alternate left/right of the facing line.
@export var share_cooldown: float = 25.0 ## Seconds the elder ignores the pigeon after sharing.

@export_group("Beat")
@export var arm_raise_seconds: float = 0.5 ## How long the near arm stays up after a share.
@export var arm_raise_rate: float = 8.0 ## 1/s the arm sweeps up and back down.

@export_group("Shuffle") ## (T-137) The grandpa shuffle — slower than every tourist.
@export var walk_speed: float = 0.8 ## Shuffle pace along the route legs (m/s) — the tourists stroll at 1.3.
@export var walk_turn_rate: float = 4.0 ## 1/s yaw easing toward the current leg — slower hips than the tourist's 7.0.
@export var waypoint_reach: float = 0.6 ## Distance (m) at which the next route waypoint is adopted.
@export var rise_seconds: float = 0.6 ## Standing up off the bench (and sitting back down) takes this long.
@export var stand_off: float = 0.9 ## Forward distance (m) from the bench the elder stands on.
@export var bob_rate: float = 5.0 ## Shuffle bob cycles per second at full pace.
@export var bob_height: float = 0.035 ## Shuffle bob amplitude (m), scaled by the pace fraction.
@export var hunch_rate: float = 2.0 ## 1/s the torso eases between the bench hunch and the walking stance.
@export var curb_car_radius: float = 15.0 ## CURB_WAIT radius (m): no car inside it may be closing before a crossing.
@export var stall_skip_seconds: float = 0.5 ## (T-137) Ground the shuffle may fail to make before it skips to the next route waypoint (a prop on the lane must never strand him).

## Cardigan tint — the spawner assigns it before _ready (index-based, no RNG).
var cardigan_color: Color = CARDIGAN_PALETTE[0]
## The bread service the tossed crumbs come from — the spawner assigns it.
var bread_spawner: BreadSpawner
## (T-137) The city the routes read — the spawner assigns it before _ready.
var city: City
## (T-137) The seat this elder occupies — an index into `City.elder_spots`.
## −1 = seatless (a bare rig elder never migrates).
var current_seat: int = -1
## (T-137) The seat this elder departed from on its current migration — the
## `elder_relocated` event's `from` half.
var departed_seat: int = -1

## Shares so far this run — the spawner relays and the autoplay DONE line reports it.
var share_count: int = 0

var _trust: float = 0.0
var _cooldown_left: float = 0.0
var _arm_left: float = 0.0
var _arm_target: float = 0.0 ## Where the arm eases toward this frame — the share beat, the cooldown or the banked trust (T-078).
var _arm_raise: float = 0.0 ## 0 = arm down, 1 = arm up.
var _state: State = State.SEATED
var _dest_seat: int = -1
var _route := PackedVector3Array() ## Global waypoints; `_route_cross[i]` marks the leg ARRIVING at i a road crossing.
var _route_cross: Array[bool] = []
var _wp: int = 0
var _cross_committed: bool = false
var _rise_left: float = 0.0
var _rise_from := Vector3.ZERO
var _rise_to := Vector3.ZERO
var _arrive_left: float = 0.0
var _arrive_from := Vector3.ZERO
var _seat_target := Vector3.ZERO
var _seat_yaw: float = 0.0
var _phase: float = 0.0
var _sink: float = 0.0 ## (T-138) The eased seated sink (SEAT_SINK when seated).
var _stall_left: float = 0.5
var _stall_pos := Vector3.ZERO

@onready var _zone: Area3D = $PresenceZone
@onready var _zone_shape: CollisionShape3D = $PresenceZone/Shape
@onready var _visual: PeopleRig = $Visual
@onready var _torso: MeshInstance3D = _visual.body_mesh
@onready var _cane: MeshInstance3D = $Cane
@onready var _arm_near: MeshInstance3D = _visual.arm_r_rigid
@onready var _arm_far: MeshInstance3D = _visual.arm_skinned_l


func _ready() -> void:
	(_zone_shape.shape as SphereShape3D).radius = proximity_radius
	## (T-138) The elder layout: the near trust arm is the rig's rigid right
	## arm (the T-078 meter), the far arm rides the skinned clips, the hair
	## mounts on the head bone and the cane is adopted into the bob/lean
	## container. The bench hunch is a figure pitch on the rig root.
	_visual.show_rigid_arms(false)
	_visual.mount_prop($Hair, PeopleRig.Mount.HEAD)
	_visual.adopt(_cane)
	_cane.rotation.z = -0.08
	_visual.rotation.x = HUNCH_SEATED
	## Per-elder cardigan material: the palette tint, without touching the
	## shared scene material (the tourist's pattern).
	var mat: StandardMaterial3D = _torso.mesh.surface_get_material(0).duplicate()
	mat.albedo_color = cardigan_color
	_torso.material_override = mat
	_arm_near.material_override = mat
	_arm_far.material_override = mat


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	var present := _pigeon_present()
	if _state == State.SEATED:
		## (T-137) Trust accrues ONLY while seated — the walk pauses accrual
		## and decay alike (the existing bank/decay rules cover walk-aways).
		if present:
			_trust = minf(_trust + trust_fill_rate * delta, trust_needed)
			## (T-114) The favor gate, layered ON TOP of the proven trust path —
			## trust rates, `trust_needed`, the cooldown and the T-078 arm are
			## untouched. The elders won't hand over bread you can't pay for: a
			## broke pigeon pins trust at `trust_needed` with no share coming (the
			## favor meter is what explains the hold).
			if _trust >= trust_needed and _cooldown_left <= 0.0 \
					and Game.favor >= Game.elder_loaf_cost * crumbs_per_share:
				_share()
		else:
			_trust = maxf(_trust - trust_decay * delta, 0.0)
	## The arm IS the trust meter (T-078): the post-share beat keeps the
	## target at 1.0; after it the cooldown pins the arm down ("not now")
	## even though trust refills to `trust_needed` during it, company raises
	## it with the banked trust, and absence lowers it again.
	if _arm_left > 0.0:
		_arm_target = 1.0
	elif _cooldown_left > 0.0 or not present:
		_arm_target = 0.0
	else:
		_arm_target = _trust / trust_needed
	match _state:
		State.RISING:
			_rising_tick(delta)
		State.WALKING:
			_walking_tick(delta)
		State.CURB_WAIT:
			_curb_tick(delta)
		State.ARRIVING:
			_arriving_tick(delta)
		_:
			pass ## SEATED — the trust block above is the whole tick.
	_animate(delta)


## A GROUNDED pigeon inside the PresenceZone — the same land-and-peck rule
## the bread crumbs use (T-005): a fly-through is not company.
func _pigeon_present() -> bool:
	for body in _zone.get_overlapping_bodies():
		if body is Player and body.is_grounded:
			return true
	return false


## Trust paid off: toss `crumbs_per_share` ordinary crumbs to the pavement in
## front of the elder's facing (alternating sideways, so two crumbs read as a
## small scatter, not a stack), then go quiet for `share_cooldown`.
## (T-114) The share IS the purchase: the exact `elder_loaf_cost ×
## crumbs_per_share` favor is charged here, once, AFTER the spawner guard — a
## spawner-less elder never charges for bread it cannot toss — so every loaf
## bought is favor not banked.
## (T-137) The spawner's `bread_shared` relay reserves the destination bench
## and calls `begin_migration` — the elder stands right after the toss.
func _share() -> void:
	_cooldown_left = share_cooldown
	_trust = 0.0
	_arm_left = arm_raise_seconds
	share_count += 1
	if bread_spawner == null:
		push_warning("Elder has no BreadSpawner — the shared bread is lost.")
		shared.emit(self, 0)
		return
	Game.add_favor(-Game.elder_loaf_cost * crumbs_per_share) ## (T-114) The spend.
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var ground_y := global_position.y - SEAT_HEIGHT + CRUMB_LIFT
	for i in crumbs_per_share:
		var side := toss_spread if i % 2 == 0 else -toss_spread
		var pos := global_position + forward * toss_distance + right * side
		pos.y = ground_y
		bread_spawner.drop_crumb(pos)
	shared.emit(self, crumbs_per_share)


## --- the grandpa shuffle (T-137) ------------------------------------------


## The spawner's migration entry: `dest_seat` (an index into
## `City.elder_spots`) is already reserved. Stands up off the current bench
## and builds the route (sidewalk rings + crosswalk bands) to the new one.
## No RNG anywhere — the route is a pure function of the two seats and the
## city layout.
func begin_migration(dest_seat: int) -> void:
	if _state != State.SEATED or current_seat < 0 or city == null:
		return
	if dest_seat < 0 or dest_seat >= city.elder_spots.size():
		return ## Defensive: an out-of-range seat (never with the shipped city).
	departed_seat = current_seat
	current_seat = dest_seat
	_dest_seat = dest_seat
	_build_route()
	if _route.size() < 2:
		_departed_reset() ## Defensive: no route — stay seated where he was.
		return
	_rise_from = global_position
	_rise_to = city.to_global(_stand_point_local(city.elder_spots[departed_seat]))
	_rise_left = rise_seconds
	_wp = 0
	_cross_committed = false
	velocity = Vector3.ZERO
	_state = State.RISING


## Builds the shuffle route as GLOBAL waypoints: origin bench stand point →
## origin block's sidewalk ring (`City.sidewalk_loop`'s square) → per-block
## steps, X first then Z — each step ONE road crossing at the pinned T-069
## crosswalk band of the shared corner node (a diagonal plaza↔park hop is two
## perpendicular crossings at ONE intersection: the second step reuses the
## first's road when the other axis is already aligned) → destination ring →
## the reserved bench's stand point. `_route_cross[i]` marks the leg ARRIVING
## at waypoint `i` as a road crossing — the CURB_WAIT gate.
func _build_route() -> void:
	_route = PackedVector3Array()
	_route_cross = []
	var r := city.block_size * 0.5 - 0.1 ## The `sidewalk_loop` radius.
	var from_spot := city.elder_spots[departed_seat]
	var to_spot := city.elder_spots[_dest_seat]
	var from_block := _block_coords_of(from_spot)
	var to_block := _block_coords_of(to_spot)
	var cur := from_block
	var cur_local := _ring_project(_block_center(cur),
			_stand_point_local(from_spot))
	_route.append(city.to_global(cur_local))
	_route_cross.append(false)
	## X steps first, then Z — the deterministic order (the diagonal hop's two
	## crossings land on ONE node because the Z step reuses the X step's road).
	var prev_road := 0.0
	var has_prev := false
	while cur.x != to_block.x:
		var dirx := signi(to_block.x - cur.x)
		var road_x := _axis_coord(cur.x) + float(dirx) * city.block_pitch * 0.5
		var other := signi(to_block.y - cur.y)
		var road_z: float = _axis_coord(cur.y) + float(other) * city.block_pitch * 0.5 \
				if other != 0 \
				else (prev_road if has_prev else _axis_coord(cur.y) + city.block_pitch * 0.5)
		var band_z := road_z + float(signi(_axis_coord(cur.y) - road_z)) * City.CROSSWALK_OUTSET
		var wait := Vector3(_axis_coord(cur.x) + float(dirx) * r, city.block_slab_height, band_z)
		_append_ring_path(_block_center(cur), cur_local, wait)
		_route.append(city.to_global(wait))
		_route_cross.append(false)
		## The far curb: the NEXT block's ring edge (`block_pitch - r` out), so
		## the crossing spans the full road and lands on the destination ring.
		var exit := Vector3(
				_axis_coord(cur.x) + float(dirx) * (city.block_pitch - r),
				city.block_slab_height, band_z)
		_route.append(city.to_global(exit))
		_route_cross.append(true)
		cur_local = exit
		cur.x += dirx
		prev_road = road_x
		has_prev = true
	while cur.y != to_block.y:
		var dirz := signi(to_block.y - cur.y)
		var road_z2 := _axis_coord(cur.y) + float(dirz) * city.block_pitch * 0.5
		var other_x := signi(to_block.x - cur.x)
		var road_x2: float = _axis_coord(cur.x) + float(other_x) * city.block_pitch * 0.5 \
				if other_x != 0 \
				else (prev_road if has_prev else _axis_coord(cur.x) + city.block_pitch * 0.5)
		var band_x := road_x2 + float(signi(_axis_coord(cur.x) - road_x2)) * City.CROSSWALK_OUTSET
		var wait2 := Vector3(band_x, city.block_slab_height,
				_axis_coord(cur.y) + float(dirz) * r)
		_append_ring_path(_block_center(cur), cur_local, wait2)
		_route.append(city.to_global(wait2))
		_route_cross.append(false)
		var exit2 := Vector3(band_x, city.block_slab_height,
				_axis_coord(cur.y) + float(dirz) * (city.block_pitch - r))
		_route.append(city.to_global(exit2))
		_route_cross.append(true)
		cur_local = exit2
		cur.y += dirz
		prev_road = road_z2
		has_prev = true
	var to_center := _block_center(to_block)
	var dest_local := _stand_point_local(to_spot)
	## The interior approach runs up the bench's OWN forward lane from the
	## opposite ring point, through the block center: the one lane the pinned
	## bench itself never blocks (the stand point sits in front of the seat,
	## and the lane stops there). An RNG edge bench whose jitter lands on the
	## lane is the one residual squeeze - the progress watchdog covers it.
	var dest_fwd := -to_spot.basis.z
	dest_fwd.y = 0.0
	dest_fwd = dest_fwd.normalized()
	var opp := _ring_project(to_center, to_center - dest_fwd * city.block_size)
	_append_ring_path(to_center, cur_local, opp)
	_route.append(city.to_global(opp))
	_route_cross.append(false)
	_route.append(city.to_global(dest_local))
	_route_cross.append(false)


func _departed_reset() -> void:
	departed_seat = current_seat ## No-op walk: the seats never swapped hands.


## Appends the ring walk (corner waypoints along the sidewalk square) between
## two points already on the same block's ring — the shorter way round,
## forward on ties.
func _append_ring_path(center: Vector3, from_pt: Vector3, to_pt: Vector3) -> void:
	var r := city.block_size * 0.5 - 0.1
	var pf := _ring_perim(Vector2(from_pt.x - center.x, from_pt.z - center.z), r)
	var pt := _ring_perim(Vector2(to_pt.x - center.x, to_pt.z - center.z), r)
	var fwd := fposmod(pt - pf, 8.0 * r)
	var backward := 8.0 * r - fwd
	var step := 1.0 if fwd <= backward else -1.0
	var dist: float = fwd if step > 0.0 else backward
	## Collect the corners on the chosen arc, then emit them in TRAVEL order:
	## ascending along for the forward lap, descending for the backward one
	## (appending in perimeter order sent a backward lap around the wrong way).
	var stops: Array = []
	for k in 4:
		var cp := 2.0 * r * float(k) ## The corner perimeter coordinates.
		var along: float = fposmod(cp - pf, 8.0 * r) if step > 0.0 else fposmod(pf - cp, 8.0 * r)
		if along > 0.001 and along < dist - 0.001:
			stops.append([along, cp])
	stops.sort_custom(func(a, b): return a[0] < b[0])
	if step < 0.0:
		stops.reverse()
	for stop: Array in stops:
		var c := _ring_pos(stop[1], r)
		_route.append(city.to_global(Vector3(
				center.x + c.x, city.block_slab_height, center.z + c.y)))
		_route_cross.append(false)


## The perimeter coordinate of a point ON the ring square (city-local offset
## from the block center): corner k sits at p = 2k·r, edges run between —
## edge 0 (z = +r, toward −x), edge 1 (x = −r, toward −z), edge 2 (z = −r,
## toward +x), edge 3 (x = +r, toward +z). Every caller passes a constructed
## point, so the exact corner hits are exact.
func _ring_perim(off: Vector2, r: float) -> float:
	if absf(off.y - r) < 0.001 and absf(off.x - r) < 0.001:
		return 0.0 ## (r, r).
	if absf(off.y - r) < 0.001 and absf(off.x + r) < 0.001:
		return 2.0 * r ## (−r, r).
	if absf(off.y + r) < 0.001 and absf(off.x + r) < 0.001:
		return 4.0 * r ## (−r, −r).
	if absf(off.y + r) < 0.001 and absf(off.x - r) < 0.001:
		return 6.0 * r ## (r, −r).
	if off.y > r - 0.001:
		return fposmod(r - off.x, 8.0 * r) ## +z edge (toward −x).
	if off.x < -r + 0.001:
		return fposmod(2.0 * r + (r - off.y), 8.0 * r) ## −x edge (toward −z).
	if off.y < -r + 0.001:
		return fposmod(4.0 * r + (off.x + r), 8.0 * r) ## −z edge (toward +x).
	return fposmod(6.0 * r + (off.y + r), 8.0 * r) ## +x edge (toward +z).


## The inverse of `_ring_perim`: the point at perimeter coordinate `p`.
func _ring_pos(p: float, r: float) -> Vector2:
	var e := clampi(int(floorf(p / (2.0 * r))), 0, 3)
	var t := p - 2.0 * r * float(e)
	match e:
		0: return Vector2(r - t, r)
		1: return Vector2(-r, r - t)
		2: return Vector2(-r + t, -r)
		_: return Vector2(r, -r + t)


## The point on the block's ring square nearest `pos` (city-local) — the ray
## from the center scaled out to the ring radius.
func _ring_project(center: Vector3, pos: Vector3) -> Vector3:
	var off := Vector2(pos.x - center.x, pos.z - center.z)
	var m := maxf(absf(off.x), absf(off.y))
	if m < 0.001:
		off = Vector2(0.0, 1.0)
		m = 1.0
	var scaled := off * ((city.block_size * 0.5 - 0.1) / m)
	return Vector3(center.x + scaled.x, city.block_slab_height, center.z + scaled.y)


## The city-local block coordinates of an elder seat (its transform origin is
## the bench, within a bench offset of the block center).
func _block_coords_of(spot: Transform3D) -> Vector2i:
	var half := float(city.blocks_per_side - 1) * 0.5
	return Vector2i(roundi(spot.origin.x / city.block_pitch + half),
			roundi(spot.origin.z / city.block_pitch + half))


## The city-local center of the block at grid coordinates `b`.
func _block_center(b: Vector2i) -> Vector3:
	return city.block_centers[b.x * city.blocks_per_side + b.y]


## The city-local road-center coordinate of block row/column `i`.
func _axis_coord(i: int) -> float:
	return (float(i) - float(city.blocks_per_side - 1) * 0.5) * city.block_pitch


## The city-local stand point of a bench: `stand_off` in front of the seat
## (the elder's facing is −basis.z), at slab height.
func _stand_point_local(spot: Transform3D) -> Vector3:
	var fwd := -spot.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p := spot.origin + fwd * stand_off
	p.y = city.block_slab_height
	return p


## RISING: lerp off the bench onto the stand point, easing the yaw toward
## the first route leg.
func _rising_tick(delta: float) -> void:
	_rise_left -= delta
	var t := 1.0 - maxf(_rise_left, 0.0) / rise_seconds
	global_position = _rise_from.lerp(_rise_to, t)
	if not _route.is_empty():
		var to := _route[0] - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			_face(to.normalized(), delta, walk_turn_rate)
	if _rise_left <= 0.0:
		_state = State.WALKING


## WALKING: follow the route legs at `walk_speed`; before each crossing leg
## the CURB_WAIT gate holds until the road is clear.
func _walking_tick(delta: float) -> void:
	if _wp >= _route.size():
		_begin_arrival()
		return
	if _route_cross[_wp] and not _cross_committed:
		if _road_blocked():
			_state = State.CURB_WAIT
			return
		_cross_committed = true
	var to := _route[_wp] - global_position
	to.y = 0.0
	if to.length() < waypoint_reach:
		_wp += 1
		_cross_committed = false
		_stall_left = stall_skip_seconds
		_stall_pos = global_position
		if _wp >= _route.size():
			_begin_arrival()
		return
	## Progress watchdog: an RNG edge bench can sit anywhere along the lane -
	## when the shuffle stops making ground for `stall_skip_seconds`, it skips
	## to the next waypoint (direction changes, sliding resumes; the ARRIVING
	## lerp covers the last gap onto the seat). No RNG - pure frame math.
	if _stall_pos.distance_to(global_position) < 0.02:
		_stall_left -= delta
		if _stall_left <= 0.0:
			_stall_left = stall_skip_seconds
			_stall_pos = global_position
			_wp += 1
			_cross_committed = false
			if _wp >= _route.size():
				_begin_arrival()
			return
	else:
		_stall_left = stall_skip_seconds
		_stall_pos = global_position
	var dir := to / to.length()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	velocity.y = -2.0 ## Stay glued to the slab or the road.
	_face(dir, delta, walk_turn_rate)
	move_and_slide()


## CURB_WAIT (owner fork 2): hold the curb — the crossing commit stays armed
## and resumes the moment the road clears.
func _curb_tick(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = -2.0
	move_and_slide()
	if not _road_blocked():
		_state = State.WALKING


## ARRIVING: settle from the stand point onto the reserved bench, easing the
## yaw to the bench's own, then byte-exact seat placement and SEATED.
func _arriving_tick(delta: float) -> void:
	_arrive_left -= delta
	var t := 1.0 - maxf(_arrive_left, 0.0) / rise_seconds
	global_position = _arrive_from.lerp(_seat_target, t)
	rotation.y = lerp_angle(rotation.y, _seat_yaw, 1.0 - exp(-walk_turn_rate * delta))
	if _arrive_left <= 0.0:
		global_transform = city.global_transform * city.elder_spots[_dest_seat]
		_state = State.SEATED
		arrived.emit(self)


## Arms the settle: the seat's global transform (position and yaw) becomes
## the lerp target.
func _begin_arrival() -> void:
	var xf := city.global_transform * city.elder_spots[_dest_seat]
	_arrive_from = global_position
	_arrive_left = rise_seconds
	_seat_target = xf.origin
	_seat_yaw = xf.basis.get_euler().y
	velocity = Vector3.ZERO
	_state = State.ARRIVING


## CURB_WAIT's rule (T-137, owner fork 2): the crossing waits while ANY car
## is within `curb_car_radius` AND closing — its velocity carries toward the
## elder. Parked cars (velocity ≈ 0) never block, and cars NEVER yield —
## rare clip-throughs are the accepted trade. The scan reads the static
## `Car._fleet` registry, so no spawner wiring is needed.
func _road_blocked() -> bool:
	for car: Car in Car._fleet:
		if car == null or not is_instance_valid(car):
			continue
		var flat := Vector2(car.global_position.x - global_position.x,
				car.global_position.z - global_position.z)
		if flat.length() >= curb_car_radius:
			continue
		if Vector2(car.velocity.x, car.velocity.z).dot(-flat) > 0.0:
			return true ## Within the radius and closing.
	return false


## Yaw easing toward the current leg's direction (the tourist's `_face`).
func _face(dir: Vector3, delta: float, rate: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rate * delta))


## Cosmetic layer (T-138): the near arm eases toward `_arm_target` at
## `arm_raise_rate` — the share beat first, then the trust meter (T-078) —
## driven through the rig's raised-arm aim exactly as it drove the static
## part; plus (T-137) the shamble: a bob sine scaled by the pace fraction
## while walking, and the torso easing upright off the bench hunch mid-route.
## The clip layer follows the state machine: Sitting_Idle seated, the
## stand-up/sit-down transitions on RISING/ARRIVING (paced to
## `rise_seconds`), the rate-matched Walk shuffle, Idle at the curb.
func _animate(delta: float) -> void:
	if _arm_left > 0.0:
		_arm_left -= delta
	_arm_raise = move_toward(_arm_raise, _arm_target, arm_raise_rate * delta)
	_visual.set_arm_pose(PeopleRig.ARM_R, _arm_raise)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if _state == State.WALKING and hspeed > 0.05:
		_phase += bob_rate * delta
		_visual.position.y = _sink + bob_height * minf(hspeed / walk_speed, 1.5) * sin(_phase)
	else:
		## (T-141) The bob's leftover closes at least as fast as the sink
		## itself eases — at the bare bob rate the 0.399 m sink took ~11 s to
		## reach the visual, so the elder hovered above the seat long after
		## ARRIVING landed him.
		_visual.position.y = _sink + move_toward(_visual.position.y - _sink, 0.0,
				maxf(bob_height, absf(SEAT_SINK) * hunch_rate) * delta)
	var want_hunch: float = HUNCH_SEATED \
			if (_state == State.SEATED or _state == State.ARRIVING) else HUNCH_WALKING
	_visual.rotation.x = move_toward(_visual.rotation.x, want_hunch, hunch_rate * delta)
	var want_sink: float = SEAT_SINK \
			if (_state == State.SEATED or _state == State.ARRIVING) else 0.0
	_sink = move_toward(_sink, want_sink, hunch_rate * absf(SEAT_SINK) * delta)
	_sync_clip()


## (T-138) The state machine's clip layer — the states are untouched; each
## just picks its clip: the seated hold, the paced stand-up/sit-down
## transitions, the rate-matched shuffle and the curb-side idle.
func _sync_clip() -> void:
	match _state:
		State.SEATED:
			_visual.play_clip(PeopleRig.CLIP_SITTING_IDLE, 1.0)
		State.RISING:
			_visual.play_clip(PeopleRig.CLIP_SITTING_EXIT,
					PeopleRig.SITTING_EXIT_SECONDS / rise_seconds)
		State.WALKING:
			_visual.play_clip(PeopleRig.CLIP_WALK, PeopleRig.walk_rate(walk_speed))
		State.CURB_WAIT:
			_visual.play_clip(PeopleRig.CLIP_IDLE, 1.0)
		State.ARRIVING:
			_visual.play_clip(PeopleRig.CLIP_SITTING_ENTER,
					PeopleRig.SITTING_ENTER_SECONDS / rise_seconds)

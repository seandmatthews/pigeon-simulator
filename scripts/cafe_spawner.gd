class_name CafeSpawner
extends Node3D
## The sidewalk-cafe service (T-031, batched T-094): seats every
## `City.cafe_spots` entry (one spot per awninged building, a pure-layout
## array) without instancing a node graph per table — the furniture is built
## as a batch, the city-props way. One MultiMeshInstance3D per visual key
## under a `CafeVisuals` child replaces ~1600 mesh instances; two merged
## `StaticBody3D` — `Tables` on layer 1 `world`, `Sitters` on collision-layer
## value 4 (the retired scenes' value; mask 0 both) — replace 260
## single-shape bodies, one positioned `CollisionShape3D` per piece (the
## T-093 one-body-per-group pattern). Re-populates on `City.regenerated`;
## deterministic per seed, zero RNG of any stream — the spot list is the spot
## list at every seed, and the even/odd sitter count and the shirt palette
## offsets are pure functions of the spot index.

## Seat offsets (local, m): one sitter per side of the tabletop, facing it.
const SITTER_SEATS: Array[Vector3] = [Vector3(0.72, 0.0, 0.0), Vector3(-0.72, 0.0, 0.0)]
## Facing yaw per seat — each sitter turns inward toward the table.
const SITTER_YAWS: Array[float] = [PI * 0.5, -PI * 0.5]

## (T-142) The crowd wears the ONE people model: the import bakes the pack's
## `Rig|Sitting_Idle` pose into static meshes (SitBake/SitBody|SitLegs|SitHead
## inside the shared rig scene, hidden) and this spawner harvests them for
## its MultiMesh batch — the T-094 perf law keeps live rigs out of the café,
## and sitters never move, so the pose bakes once at import instead.
## Probe-measured seated constants (adult, rig-root space — the same
## measurement family as the elder's SEAT_SINK, tools/probe_sit_geometry.gd):
## the pose's DEF-hips BONE rides 0.5179 above the rig root, and the stool
## top is the sitter_seat box's top face (center 0.42 + half 0.03). The
## instance sinks so the hips rest on the stool; the pose's feet (0.0873
## above the clip floor) land ~0.02 above the pavement.
const PEOPLE_RIG_SCENE := "res://scenes/people_rig.tscn"
const SIT_HIPS_Y := 0.5179
const SITTER_SEAT_TOP := 0.45
const SIT_ROOT_Y := SITTER_SEAT_TOP - SIT_HIPS_Y

## Collider boxes — exactly the retired scenes' shapes: the table's
## 0.9 × 0.72 × 0.9 bench collider at (0, 0.36, 0) on the spot, each sitter's
## 0.44 × 0.78 × 0.34 body at (0, 0.42, 0) on its seat transform.
const TABLE_SHAPE_SIZE := Vector3(0.9, 0.72, 0.9)
const TABLE_SHAPE_OFFSET := Vector3(0.0, 0.36, 0.0)
const SITTER_SHAPE_SIZE := Vector3(0.44, 0.78, 0.34)
const SITTER_SHAPE_OFFSET := Vector3(0.0, 0.42, 0.0)

## The keys whose instances carry per-sitter shirt colors (the tourist
## palette); every other key wears its fixed scene color on a flat material.
const SHIRT_KEYS: Array[String] = ["sit_body"]

## (T-142) The baked sit meshes, harvested once per populate from the rig
## scene ("sit_body"/"sit_legs"/"sit_head" → Mesh). The `sit_hair` key keeps
## the retired box (the pack mannequin is bald); its offset derives from the
## baked head's own AABB at populate time.
var _sit_meshes: Dictionary = {}

## The retired scenes' fixed material colors (T-031) — wood, metal, hair —
## reused verbatim on the flat materials. (T-142) The sitters' skin and
## trousers colors live in the import's baked-mesh materials now.
const WOOD := Color(0.55, 0.38, 0.24)
const METAL := Color(0.25, 0.26, 0.28)
const HAIR := Color(0.3, 0.21, 0.15)

@export_group("Wiring")
@export var city_path: NodePath
## (T-129) Staged boot — see BandSpawner.staged_boot: main.tscn's boot calls
## `populate()` explicitly; bare rigs keep the default false and self-populate.
@export var staged_boot: bool = false

## The city to seat — Main wires the path; the sim harness assigns directly.
var city: City

## The merged table body (layer 1 `world`, mask 0) — tests read the layers
## and the positioned shapes.
var tables_body: StaticBody3D

## The merged sitter body (collision-layer value 4, mask 0) — tests read the
## layers and the positioned shapes.
var sitters_body: StaticBody3D

## The batched visuals root — the per-key MultiMeshInstance3D hang under it.
var visuals_root: Node3D

## One record per seated sitter, in build order: which spot seats it, which
## seat of that spot, and its MultiMesh instance ordinal (every sit key uses
## the ordinal directly — one instance per sitter since T-142). Tests read
## these.
var sitters: Array[Dictionary] = []

## The visual queues the last populate fed into the MultiMeshes: per key, the
## `xfs` and per-instance `colors` exactly as passed to `set_instance_transform`
## / `set_instance_color`. Tests read these — this engine build's headless
## RenderingServer reads instance data back as identity/black, so the queue is
## the only per-instance channel it can answer (the city-props precedent).
var _mm_queues: Dictionary = {}


func _ready() -> void:
	if city == null and not city_path.is_empty():
		city = get_node(city_path) as City
	if city == null:
		push_warning("CafeSpawner needs a City — no cafe furniture will spawn.")
		return
	if staged_boot: ## (T-129) main.gd's boot stages the first populate itself.
		return
	city.regenerated.connect(_populate)
	_populate()


## (T-129) The boot's explicit staging entry — the BandSpawner.populate() twin:
## idempotent `regenerated` wiring plus the re-seat, safe to call any time.
func populate() -> void:
	if not city.regenerated.is_connected(_populate):
		city.regenerated.connect(_populate)
	_populate()


## Sitters seated at one spot — the pure even/odd rule (even → 2, odd → 1),
## lifted from the retired cafe_table.gd unchanged.
func sitter_count(spot_index: int) -> int:
	return 2 if spot_index % 2 == 0 else 1


## The shirt tint for one sitter — the tourist palette indexed by spot + seat,
## the retired cafe_table.gd's exact rule (index-based, no RNG).
func shirt_color(spot_index: int, seat: int) -> Color:
	return Tourist.SHIRT_PALETTE[(spot_index + seat) % Tourist.SHIRT_PALETTE.size()]


## One batched visual by its key ("sit_body", "sit_legs", "sit_hair", …) —
## tests read the sit/furniture MultiMeshes off these.
func visual(key: String) -> MultiMeshInstance3D:
	return visuals_root.get_node(key.to_pascal_case()) as MultiMeshInstance3D


## The per-instance color queued for one MultiMesh instance — the exact value
## fed into `set_instance_color` (headless instance readback is black on this
## engine build, so tests use this channel).
func instance_color(key: String, i: int) -> Color:
	return (_mm_queues[key].colors as Array)[i] as Color


## Wipes and re-builds the whole batch (first boot, city regeneration):
## furniture per spot, in spot order, so the spot index drives the pure
## sitter-count and shirt rules.
func _populate() -> void:
	_clear_batch()
	if city == null:
		return
	_sit_meshes = _harvest_sit_meshes()
	visuals_root = Node3D.new()
	visuals_root.name = "CafeVisuals"
	add_child(visuals_root)
	tables_body = _make_body("Tables", 1) ## layer 1 `world`
	sitters_body = _make_body("Sitters", 4) ## the retired scenes' layer value 4
	var to_local: Transform3D = global_transform.affine_inverse() * city.global_transform
	var queues: Dictionary = {}
	var sitter_i := 0
	for spot_i in city.cafe_spots.size():
		var spot: Transform3D = to_local * city.cafe_spots[spot_i]
		_queue_mm(queues, "table_top", spot.translated_local(Vector3(0.0, 0.69, 0.0)))
		_queue_mm(queues, "table_post", spot.translated_local(Vector3(0.0, 0.36, 0.0)))
		_add_shape(tables_body, TABLE_SHAPE_SIZE, spot.translated_local(TABLE_SHAPE_OFFSET))
		for seat in sitter_count(spot_i):
			var sitter_xf: Transform3D = spot * Transform3D(
					Basis(Vector3.UP, SITTER_YAWS[seat]), SITTER_SEATS[seat])
			_queue_mm(queues, "sitter_seat", sitter_xf.translated_local(Vector3(0.0, 0.42, 0.0)))
			_queue_mm(queues, "sitter_post", sitter_xf.translated_local(Vector3(0.0, 0.21, 0.0)))
			## (T-142) The sitter: the baked seated figure, hips on the stool.
			var sit_root: Transform3D = sitter_xf.translated_local(Vector3(0.0, SIT_ROOT_Y, 0.0))
			_queue_mm(queues, "sit_body", sit_root, shirt_color(spot_i, seat))
			_queue_mm(queues, "sit_legs", sit_root)
			_queue_mm(queues, "sit_head", sit_root)
			_queue_mm(queues, "sit_hair", sit_root.translated_local(_hair_offset()))
			_add_shape(sitters_body, SITTER_SHAPE_SIZE,
					sitter_xf.translated_local(SITTER_SHAPE_OFFSET))
			sitters.append({"spot": spot_i, "seat": seat, "instance": sitter_i})
			sitter_i += 1
	_mm_queues = queues
	_spawn_visuals(queues)


## (T-142) Harvests the import's baked seated meshes from the ONE people
## scene. Missing bake (the glb not re-imported) leaves the crowd collider-
## correct but invisible — the `cafe_sitters_on_the_rig` scenario fails loud.
func _harvest_sit_meshes() -> Dictionary:
	var out := {}
	var rig: Node3D = (load(PEOPLE_RIG_SCENE) as PackedScene).instantiate()
	var bake := rig.find_child("SitBake", true, false) as Node3D
	if bake == null:
		push_warning("CafeSpawner: no SitBake in the people rig — re-import the pack glb (T-142)")
	else:
		for mi: MeshInstance3D in bake.get_children():
			out["sit_" + mi.name.to_lower().trim_prefix("sit")] = mi.mesh
	rig.free()
	return out


## (T-142) The hair box's offset over the sitter root, derived from the
## baked head's own AABB: centered on the head, sunk 3 cm past the scalp
## line so the flat bottom reads as hair, not a hovering slab.
func _hair_offset() -> Vector3:
	var head_mesh: Mesh = _sit_meshes.get("sit_head")
	if head_mesh == null:
		return Vector3(0.0, SIT_ROOT_Y + 1.4, 0.0) ## Bake missing — keep the box out of the ground.
	var ab := head_mesh.get_aabb()
	return Vector3(ab.get_center().x, ab.end.y + 0.02 - 0.05, ab.get_center().z)


## Frees the previous batch (if any): detached immediately so the rebuild can
## reuse the node names, deleted deferred so physics never mid-flushes.
func _clear_batch() -> void:
	for node: Node in [visuals_root, tables_body, sitters_body]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	visuals_root = null
	tables_body = null
	sitters_body = null
	sitters.clear()
	_mm_queues = {}


## One merged StaticBody3D under the spawner: `layer` set, mask 0 — the T-093
## one-body-per-group pattern with the cafe's own layer values.
func _make_body(body_name: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body


## One box collider in `body`: a CollisionShape3D carrying the box at `xf`
## (spot/seat yaw + translation). Shapes are appended in build order, so a
## shape's index is its table/sitter ordinal.
func _add_shape(body: StaticBody3D, size: Vector3, xf: Transform3D) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xf
	body.add_child(shape)


## Queues one instance for the MultiMesh registered under `key` — the city
## props' `_add_mm` shape, kept local so the cafe never writes the city's
## visual queues.
func _queue_mm(queues: Dictionary, key: String, xf: Transform3D, color: Color = Color.WHITE) -> void:
	if not queues.has(key):
		queues[key] = {"xfs": [], "colors": []}
	(queues[key].xfs as Array).append(xf)
	(queues[key].colors as Array).append(color)


## Turns the queued instances into one MultiMeshInstance3D per key — the
## city's `_spawn_visuals`, tinted: shirt-tinted keys get `use_colors` and a
## vertex-color material, every other key wears its fixed scene color.
func _spawn_visuals(queues: Dictionary) -> void:
	for key: String in queues:
		var data: Dictionary = queues[key]
		var xfs: Array = data.xfs
		var colors: Array = data.colors
		var use_colors: bool = SHIRT_KEYS.has(key)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = use_colors
		mm.mesh = _visual_mesh(key)
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			if use_colors:
				mm.set_instance_color(i, colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = key.to_pascal_case()
		node.multimesh = mm
		visuals_root.add_child(node)


## The batch's meshes — the baked people meshes for the sit keys (T-142,
## materials stamped at import), the retired furniture primitives otherwise:
## shirt-tinted keys take a vertex-color albedo, the rest a flat scene color.
func _visual_mesh(key: String) -> Mesh:
	if _sit_meshes.has(key):
		return _sit_meshes[key]
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	match key:
		"table_top":
			var box := BoxMesh.new()
			box.size = Vector3(0.9, 0.06, 0.9)
			mesh = box
			mat.albedo_color = WOOD
			mat.roughness = 0.95
		"table_post":
			var box := BoxMesh.new()
			box.size = Vector3(0.09, 0.66, 0.09)
			mesh = box
			mat.albedo_color = METAL
			mat.roughness = 0.9
		"sitter_seat":
			var box := BoxMesh.new()
			box.size = Vector3(0.36, 0.06, 0.36)
			mesh = box
			mat.albedo_color = WOOD
			mat.roughness = 0.95
		"sitter_post":
			var box := BoxMesh.new()
			box.size = Vector3(0.07, 0.42, 0.07)
			mesh = box
			mat.albedo_color = METAL
			mat.roughness = 0.9
		"sit_hair":
			var box := BoxMesh.new()
			box.size = Vector3(0.28, 0.1, 0.3)
			mesh = box
			mat.albedo_color = HAIR
			mat.roughness = 1.0
	mesh.material = mat
	return mesh

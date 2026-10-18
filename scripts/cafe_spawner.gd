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

## Collider boxes — exactly the retired scenes' shapes: the table's
## 0.9 × 0.72 × 0.9 bench collider at (0, 0.36, 0) on the spot, each sitter's
## 0.44 × 0.78 × 0.34 body at (0, 0.42, 0) on its seat transform.
const TABLE_SHAPE_SIZE := Vector3(0.9, 0.72, 0.9)
const TABLE_SHAPE_OFFSET := Vector3(0.0, 0.36, 0.0)
const SITTER_SHAPE_SIZE := Vector3(0.44, 0.78, 0.34)
const SITTER_SHAPE_OFFSET := Vector3(0.0, 0.42, 0.0)

## The keys whose instances carry per-sitter shirt colors (the tourist
## palette); every other key wears its fixed scene color on a flat material.
const SHIRT_KEYS: Array[String] = ["sitter_torso", "sitter_arm"]

## The retired scenes' fixed material colors (T-031) — wood, metal, skin,
## hair, trousers — reused verbatim on the flat materials.
const WOOD := Color(0.55, 0.38, 0.24)
const METAL := Color(0.25, 0.26, 0.28)
const SKIN := Color(0.87, 0.68, 0.55)
const HAIR := Color(0.3, 0.21, 0.15)
const TROUSERS := Color(0.42, 0.38, 0.36)

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
## seat of that spot, and its MultiMesh instance ordinal (torso uses the
## ordinal directly; arms and thighs use 2 × ordinal for the left piece and
## 2 × ordinal + 1 for the right). Tests read these.
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


## One batched visual by its key ("sitter_torso", "sitter_arm", …) — tests
## read the torso/arm MultiMeshes off these.
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
			_queue_mm(queues, "sitter_torso", sitter_xf.translated_local(Vector3(0.0, 0.75, 0.0)),
					shirt_color(spot_i, seat))
			_queue_mm(queues, "sitter_head", sitter_xf.translated_local(Vector3(0.0, 1.14, 0.0)))
			_queue_mm(queues, "sitter_hair", sitter_xf.translated_local(Vector3(0.0, 1.24, 0.015)))
			_queue_mm(queues, "sitter_arm", sitter_xf.translated_local(Vector3(0.27, 0.7, 0.0)),
					shirt_color(spot_i, seat))
			_queue_mm(queues, "sitter_arm", sitter_xf.translated_local(Vector3(-0.27, 0.7, 0.0)),
					shirt_color(spot_i, seat))
			_queue_mm(queues, "sitter_thigh", sitter_xf.translated_local(Vector3(0.11, 0.5, -0.24)))
			_queue_mm(queues, "sitter_thigh", sitter_xf.translated_local(Vector3(-0.11, 0.5, -0.24)))
			_add_shape(sitters_body, SITTER_SHAPE_SIZE,
					sitter_xf.translated_local(SITTER_SHAPE_OFFSET))
			sitters.append({"spot": spot_i, "seat": seat, "instance": sitter_i})
			sitter_i += 1
	_mm_queues = queues
	_spawn_visuals(queues)


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


## The batch's meshes — exactly the retired scenes' primitives and materials:
## shirt-tinted keys take a vertex-color albedo, the rest a flat scene color.
func _visual_mesh(key: String) -> Mesh:
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
		"sitter_torso":
			var box := BoxMesh.new()
			box.size = Vector3(0.44, 0.56, 0.28)
			mesh = box
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.9
		"sitter_head":
			var sphere := SphereMesh.new()
			sphere.radius = 0.15
			sphere.height = 0.3
			mesh = sphere
			mat.albedo_color = SKIN
			mat.roughness = 0.9
		"sitter_hair":
			var box := BoxMesh.new()
			box.size = Vector3(0.32, 0.11, 0.32)
			mesh = box
			mat.albedo_color = HAIR
			mat.roughness = 1.0
		"sitter_arm":
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.32, 0.08)
			mesh = box
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.9
		"sitter_thigh":
			var box := BoxMesh.new()
			box.size = Vector3(0.16, 0.11, 0.38)
			mesh = box
			mat.albedo_color = TROUSERS
			mat.roughness = 1.0
	mesh.material = mat
	return mesh

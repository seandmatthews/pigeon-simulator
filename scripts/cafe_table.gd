class_name CafeTable
extends StaticBody3D
## One sidewalk cafe table (T-031): a small layer-1 `world` table — top on a
## center post, the bench collider pattern — seating 1-2 static cafe sitters
## under an awninged shopfront. The spawner assigns `spot_index` (which
## `City.cafe_spots` entry this table seats) before the table enters the tree;
## everything else is a pure rule with zero RNG anywhere: even spot index →
## 2 sitters, odd → 1, and the shirt palette offsets follow the spot index.

const SITTER_SCENE: PackedScene = preload("res://scenes/cafe_sitter.tscn")
## Seat offsets (local, m): one sitter per side of the tabletop, facing it.
const SITTER_SEATS: Array[Vector3] = [Vector3(0.72, 0.0, 0.0), Vector3(-0.72, 0.0, 0.0)]
## Facing yaw per seat — each sitter turns inward toward the table.
const SITTER_YAWS: Array[float] = [PI * 0.5, -PI * 0.5]

## Which `City.cafe_spots` entry this table seats — sets the sitter count and
## the shirt palette offsets. Assigned by the spawner before _ready.
var spot_index: int = 0

## The sitters seated here — tests read these.
var sitters: Array[CafeSitter] = []


func _ready() -> void:
	var count := 2 if spot_index % 2 == 0 else 1
	for i in count:
		var sitter: CafeSitter = SITTER_SCENE.instantiate()
		sitter.shirt_color = Tourist.SHIRT_PALETTE[
				(spot_index + i) % Tourist.SHIRT_PALETTE.size()]
		add_child(sitter)
		sitter.position = SITTER_SEATS[i]
		sitter.rotation.y = SITTER_YAWS[i]
		sitters.append(sitter)

class_name BreadCrumb
extends Area3D
## One bread-crumb pickup (T-005), a layer-5 `pickup` area that watches for the
## pigeon (layer 2). Eating is land-and-peck only: the crumb feeds when a
## GROUNDED pigeon is inside its eat radius — flying over, or skidding through
## after a hard touchdown, never feeds. On feeding it emits eaten(amount) and
## frees itself; the spawner re-seeds a fresh crumb elsewhere.

## Fired once, right before freeing: `amount` is the hunger restored. Main
## relays the spawner's crumb_eaten into Hunger.eat.
signal eaten(amount: float)

@export var restore: float = 30.0 ## Hunger restored on eating (Hunger bar units).
@export var spin_rate: float = 1.6 ## Cosmetic spin (rad/s) so crumbs read as pickups from the air.

## Index into City.bread_spots this crumb occupies — the spawner frees the
## spot for respawn when the crumb is eaten. -1 for hand-placed crumbs.
var spot_index: int = -1

## (T-114) The favor this crumb's theft is worth, stamped at spawn: café
## TABLE crumbs cost the locals' favor, tailgate crumbs pay the visitors',
## everything else is nobody's. 0 = the crumb carries no ownership — the
## spawner only emits `crumb_favor` when this is non-zero.
var favor_delta: int = 0

var _consumed: bool = false
var _time: float = 0.0

@onready var _mesh: MeshInstance3D = $Mesh


func _physics_process(delta: float) -> void:
	_time += delta
	_mesh.rotation.y = spin_rate * _time
	_mesh.position.y = 0.04 + 0.03 * sin(_time * 2.6)
	if _consumed:
		return
	for body in get_overlapping_bodies():
		if body is Player and body.is_grounded:
			_consumed = true
			eaten.emit(restore)
			queue_free()
			return

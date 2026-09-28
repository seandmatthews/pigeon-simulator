extends StaticBody3D
## Test double for T-006 (sim harness only): a plain layer-1 body that records
## poop hits through the duck-typed `on_splatted(impact_velocity)` convention —
## proof that any body on the projectile layers can receive the hit event
## without knowing anything about the pigeon that dropped it.

var hits: Array[Vector3] = []


func on_splatted(impact_velocity: Vector3) -> void:
	hits.append(impact_velocity)

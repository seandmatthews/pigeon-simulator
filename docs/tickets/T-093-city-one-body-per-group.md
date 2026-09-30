# T-093 — Merge the city's 840 single-shape static bodies into one body per group

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 2 · **Risk (1-5):** 2
- **Depends on:** — (the T-004/T-032 city is landed; this is the collider pattern T-094 reuses)

## What

Every collider the city builds is its own single-shape `StaticBody3D`:
`City._add_collider` (`scripts/city.gd:818-830`) and `_add_cylinder`
(`scripts/city.gd:833-845`) allocate a fresh body per call —
`collision_layer = 1` (`world`), `collision_mask = 0` — parented under a plain
`Node3D` group (`_group`, `scripts/city.gd:810-815`). Across the five groups
the city actually uses (Ground `city.gd:403`, Roads `city.gd:424,430`, Blocks
`city.gd:455`, Buildings `city.gd:508`, Props `city.gd:533,700,710,718`) that
is ~840 bodies, each existing only to hold one shape.

Change only the collision section of `scripts/city.gd` — nothing about the
layout math, the RNG streams or the fingerprint:

- `_group(group)` lazily creates **one `StaticBody3D` per group name** (Ground,
  Roads, Blocks, Buildings, Props) instead of a `Node3D` — layer 1, mask 0, at
  the group node's old spot under `Static/`.
- `_add_collider` / `_add_cylinder` add a positioned `CollisionShape3D` child
  of that one body — the shape carries the position **and the yaw rotation**
  the body used to carry (bench colliders pass a yaw, `city.gd:700`) — and
  return it. Boxes stay boxes, cylinders stay cylinders; same sizes, same
  world transforms, same layer/mask. Five bodies replace ~840.

**The ground-mesh trap (must handle explicitly):** `_build_ground`
(`scripts/city.gd:401-411`) hosts the grass mesh on `_add_collider`'s return
value. Today the mesh sits at body-local (0, −0.5, 0) under a body at
(0, −0.5, 0) — a world position of (0, −1.0, 0), i.e. the grass visual is
sunk **half a metre below the collision surface**. Under a merged body at the
group origin the mesh must move to city-local (0.0, −1.0, 0.0) to stay exactly
where it is; keeping the old local offset would poke the grass slab 0.5 m up
through roads, sidewalks and the plaza — and no headless scenario can see it.
Stop using `_add_collider`'s return value in `_build_ground`; parent the grass
mesh explicitly (child of the Ground body at (0, −1.0, 0.0), or under
`_static_root` — one decision, documented in the code).

What this does **not** claim: no CPU-step win. The planning probe (throwaway
SceneTree script, deleted after; numbers planner-supplied — re-measure on
landing) moved boot total_nodes 4815 → 3975 and StaticBody3D 1104 → 269
(City subtree 1705 → 865 nodes, 840 → 5 bodies; the density scenario's own
counter 6548 → 4868), while the density median stayed at 264.2 vs a 258.9 ms
baseline — noise. The honest win is scene weight and boot build surface.
~30 lines of change plus the audit re-point.

## Why

No direct player-visible defect — this is scene hygiene with a multiplier:
~840 pointless nodes inflate the one-off boot build (the `city.generate` spike
T-033 left standing), every scene iteration, and every harness audit walk —
and the per-body pattern is what makes the cafe furniture problem (T-094) 260
bodies instead of 2. Contact behavior is provably identical: nothing in the
repo reads which body a contact came from — no `get_collider` consumer exists
(grep over `scripts/`, `tests/`, `scenes/`: zero hits). The splat decal and
droplet burst do reparent onto the hit body (`scripts/poop.gd:110,91`), but
`reparent()` preserves the global transform, a static parent never moves, and
the only parent-identity assert targets the harness's own `_ground`
(`tests/sim_test.gd:1036`; the harness builds that ground with its own
`_add_box`, `tests/sim_test.gd:61`, not through City). The existing suite —
`roof_landing`, `bench_landing`, `hard_landing_skids`, `trim_glide_lands_clean`,
every `city_*` scenario and `density_cpu_budget` — collides against exactly
these shapes, so the merge is machine-provable.

## Acceptance criteria

- [ ] Gate 1b `city_roofs_inhabited` stays green with its collider audit
      re-pointed: `Static/Props` holds exactly **one** `StaticBody3D` (layer 1,
      mask 0) whose `CollisionShape3D` children above y 5.0 number exactly
      `roof_props.size()` (re-points `tests/sim_test.gd:1736-1744`, which
      today counts one body per prop)
- [ ] Exactly five `StaticBody3D` under `Static/` after `generate()` — one per
      group (Ground/Roads/Blocks/Buildings/Props), each layer 1 mask 0, every
      collider now a shape child (assertable in the re-pointed audit)
- [ ] Gate 1b full suite green — the collision scenarios are the machine proof
      the merge is collision-identical: `roof_landing`, `bench_landing`,
      `hard_landing_skids`, `trim_glide_lands_clean`, the `city_*` set and
      `density_cpu_budget` explicitly re-run
- [ ] [screenshot] The grass apron sits exactly where it did: no 0.5 m lip of
      grass above the road/sidewalk/plaza surfaces at the apron seam or the
      spawn plaza (the `_build_ground` reparent trap — a before/after shot at
      the city edge; the headless gates cannot see this one)
- [ ] Before/after node counts recorded in this ticket from the landed tree:
      the density scenario's own `nodes` print
      (`tests/sim_test.gd:3284-3289`) plus a boot node count

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines) + Gate 1b full suite
(recording the before/after node counts above) + Gate 2 (autoplay unchanged;
the DONE fps line is informational) + Gate 3: the [screenshot] grass-seam
line. `VERIFICATION.md`: update the `city_roofs_inhabited` row's "one layer-1
`world` collider each" wording to "one layer-1 shape each under the Props
group body" in the same change-set.

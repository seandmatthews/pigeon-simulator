# T-094 — Cafe furniture is 47% of the boot scene — batch it like the city props

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** T-093 (the one-body-per-group collider pattern) · builds on the landed T-031 furniture

## What

The cafe furniture is the biggest single chunk of the boot scene: 104 tables
and 156 static sitters — one table per awninged building, even spots seat 2,
odd 1 (`scripts/cafe_table.gd:25`) — cost ≈2289 of 4815 boot nodes (47%):
104×4 + 156×12 = 2288 nodes recounted from the scene files (table =
root+Shape+Top+Post; sitter = root+Shape+Visual+9 meshes) plus the spawner —
as **1612 individual MeshInstance3D** (104×2 + 156×9) and **260 single-shape
static bodies** (104 layer-1 `world` tables, `cafe_table.tscn:24-26`; 156
layer-4 `npc` sitters, `cafe_sitter.tscn:61-64`). The city's own props already
solve this exact problem: one MultiMeshInstance3D per visual key with
per-instance colors (`scripts/city.gd:799-823` `_add_mm`/`_spawn_visuals`,
`use_colors` + a `vertex_color_use_as_albedo` material, `city.gd:837-841`).

Batch the furniture in `scripts/cafe_spawner.gd` on populate, in the T-093
merged-body mold:

- **Visuals:** stop instantiating `cafe_table.tscn`/`cafe_sitter.tscn` per
  spot. Build one MultiMeshInstance3D per visual key under a `CafeVisuals`
  child of the spawner — `table_top`, `table_post`, `sitter_seat`,
  `sitter_post`, `sitter_torso`, `sitter_head`, `sitter_hair`, `sitter_arm`,
  `sitter_thigh` (~9 draw keys replace 1612 mesh instances). The shirt-tinted
  keys (torso + both arms) carry per-instance colors: `use_colors = true`, a
  vertex-color material, per-sitter
  `Tourist.SHIRT_PALETTE[(spot_index + i) % SHIRT_PALETTE.size()]` — the exact
  rule `cafe_table.gd:28-29` applies today. Every other key wears its fixed
  scene color on a flat material (top/post wood+metal, stool seat/post,
  skin head, hair, trousers thighs — `cafe_sitter.tscn:32-59`).
- **Collision:** two merged `StaticBody3D` children — `Tables` (layer 1,
  mask 0; 104 positioned `CollisionShape3D` of BoxShape3D 0.9×0.72×0.9 at the
  spot transform + local (0, 0.36, 0), spot yaw) and `Sitters` (layer 4 `npc`,
  mask 0; 156 BoxShape3D 0.44×0.78×0.34 at the seat offset (±0.72, 0, 0) with
  the sitter yaw, + (0, 0.42, 0)) — one shape per piece, exactly T-093's
  `_add_collider` pattern (shape sizes/offsets per `cafe_table.tscn:5-6,29-31`
  and `cafe_sitter.tscn:5-6,66-68`, seats per `cafe_table.gd:12-14`).
- **The pure rules stay pure:** the even/odd sitter count and the shirt
  palette offset lift from `cafe_table.gd` into `CafeSpawner` as pure
  functions of `spot_index` — zero RNG of any stream. `regenerated`
  re-population wipes and rebuilds the batch where it frees tables today
  (`cafe_spawner.gd:41-53`).
- **Retire** `scenes/cafe_table.tscn`, `scenes/cafe_sitter.tscn`,
  `scripts/cafe_table.gd`, `scripts/cafe_sitter.gd` — the per-sitter material
  duplicate (`cafe_sitter.gd:25-29`, the tourist/elder pattern) goes with
  them, replaced by instance colors. Nothing else references the scenes (the
  `SITTER_SCENE` preload lives in `cafe_table.gd` itself; `tests/autoplay.gd`
  has no cafe reads).

What this does **not** claim: no today-bottleneck. The planning Gate 2
autoplay printed fps = 132 with all furniture live (planner-supplied). The
honest claim: scene weight ≈ **−2016 boot nodes** (2289 → ~273) and render
headroom (1612 mesh instances → ~9 draw keys). The arithmetic, kept honest:
the collision design above KEEPS 260 `CollisionShape3D` nodes (104 + 156 —
shapes are nodes, and today's shape nodes are inside the 2289 baseline at
`cafe_table.tscn:29-31` / `cafe_sitter.tscn:66-68`), so after = 1 spawner +
1 `CafeVisuals` + 9 MultiMeshInstance3D + 2 merged `StaticBody3D` + 260
shapes ≈ 273 nodes — not −2270, and not "~12 nodes" (that count drops the
shapes; T-093 counts its identical pattern honestly as bodies-removed-only).
Any fps delta lands as a Gate 3 human note, not a
gate.

## Why

Static street dressing should not cost half the scene. At 1612 separate mesh
instances the furniture is paid per frame in draw/scene work everywhere in the
city, and 260 single-shape bodies drag every scene iteration — while the
headless CPU budget (`density_cpu_budget`) cannot see the render side at all,
which is exactly why it stays green today. The behavior is fully pinned by
Gate 1b `city_cafe_tables_present` (spot layout recomputable from the building
records and byte-identical across same-seed regeneration, the index rule,
street clearances, the perch-and-snag physics legs), so the batch is
machine-provable — but the work must be honest that this is a **rewrite** of
the scenario's rig section, not an extension: three read paths disappear
(`table.sitters` at `tests/sim_test.gd:1640`, `sitter.collision_layer` at
`:1644`, the shirt `material_override` at `:1647`), while the perch-and-snag
physics legs (`tests/sim_test.gd:1652-1670`) survive on the merged bodies.

## Acceptance criteria

- [ ] Gate 1b `city_cafe_tables_present` stays green with its rig section
      rewritten against the batch (`tests/sim_test.gd:1630-1650`): sitter
      count per spot via a new spawner exposure (transforms or counts per
      spot — replaces `table.sitters`), the two merged bodies' layers
      asserted (`Tables` = 1, `Sitters` = 4, both mask 0 — replaces
      `sitter.collision_layer`), and the shirt palette per sitter read off the
      torso/arm MultiMesh instance colors (replaces the `material_override`
      albedo). The spot-layout, clearance and determinism legs pass untouched.
- [ ] The perch-and-snag physics legs re-run unchanged: a grounded pigeon
      perches beside table 0 and the solid tabletop stops the waddle dead
      (`tests/sim_test.gd:1652-1670` — the two merged bodies collide the
      CharacterBody3D exactly as the 260 individual ones did)
- [ ] Gate 1b `density_cpu_budget` stays green (the furniture contributes
      ~273 nodes — 260 of them `CollisionShape3D` — and 2 bodies, instead of
      today's 2289 nodes / 260 bodies)
- [ ] Gate 1b `city_same_seed_deterministic` and
      `restart_same_seed_skips_rebuild` stay green — the batch rebuilds
      identically on every `regenerated` (zero RNG anywhere in the lift)
- [ ] [screenshot] Street level: tables and seated sitters under an awning
      read as before — shirt palette visibly varied per sitter, no color
      bleed between shirt/skin/hair parts, no z-fighting (the human read is a
      Gate 3 note)
- [ ] Boot node count and the MultiMesh key list recorded before/after in
      this ticket from the landed tree (the density print
      `tests/sim_test.gd:3782-3787` plus a boot probe)
- [ ] No dangling references to the retired scenes/scripts — Gate 1 import and
      boot exit 0 with zero ERROR lines

## Verification

Gate 1 + Gate 1b (rewrite `city_cafe_tables_present`'s rig section as above —
a real rewrite of ~`tests/sim_test.gd:1630-1650`, physics legs kept as-is —
plus a full suite re-run, with `density_cpu_budget` and both determinism
scenarios explicitly re-run) + Gate 2 re-run for the render side (autoplay
DONE fps line, informational — compare against the pre-change fps on the same
machine) + Gate 3: the [screenshot] cafe-read line. `VERIFICATION.md`: note in
the `city_cafe_tables_present` row that the 156 sitters are now batch
MultiMesh instances with instance colors, in the same change-set.

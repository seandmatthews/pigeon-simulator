# T-094 — Cafe furniture is ~58% of boot nodes — batch it like the city props

- **Milestone:** Sweep backlog · **Status:** done · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** T-093 (landed, e183c90 — the one-body-per-group collider pattern and its
  bodies-removed-only counting convention) · builds on the landed T-031 furniture

## What

The cafe furniture is the biggest single chunk of the boot scene: 104 tables and
156 static sitters — one table per awninged building, even spots seat 2, odd 1
(`scripts/cafe_table.gd:25`) — measured today at **2289 of 3969 boot nodes
(≈58%)**: a throwaway 120-frame `main.tscn` probe (2026-10-02, the T-093
convention) walked the cafe subtree and printed `nodes 2289 … tables 104
sitters 156`; T-093's landed table recorded boot 3992 the day before
(`docs/tickets/T-093-city-one-body-per-group.md:117`) — ≈57% on that basis.
The old "47% of the boot scene" headline died with T-093's landing (its landed
table: boot 4832 → 3992, density counter 6581 → 4901, `:115-117`); on today's
density-scenario node counter the share is ≈47% (2289 of 4904 — `SIM DATA
density_cpu_budget … nodes 4904`, identical across two full-suite runs
2026-10-02), so this ticket now names its denominator everywhere. The 2289
recomputes exactly from the scene files: 104×4 (table = root+Shape+Top+Post)
+ 156×12 (sitter = root+Shape+Visual+9 meshes) + 1 spawner — as **1612
individual MeshInstance3D** (probe: 104×2 + 156×9) and **260 single-shape
static bodies** (probe: 260 — 104 layer-1 `world` tables, `cafe_table.tscn:24-26`;
156 layer-value-4 sitters, `cafe_sitter.tscn:61-64` — see the label wrinkle
below). The city's own props already solve this exact problem: one
MultiMeshInstance3D per visual key with per-instance colors
(`scripts/city.gd:1025` `_add_mm`, `:1033-1049` `_spawn_visuals` with
`use_colors = true` at `:1040`, and the `vertex_color_use_as_albedo` material
at `city.gd:1063-1066`).

Batch the furniture in `scripts/cafe_spawner.gd` on populate, in the T-093
merged-body mold (`scenes/main.tscn:12,91` wires the spawner; the batch hangs
under it):

- **Visuals:** stop instantiating `cafe_table.tscn`/`cafe_sitter.tscn` per
  spot. Build one MultiMeshInstance3D per visual key under a `CafeVisuals`
  child of the spawner — `table_top`, `table_post`, `sitter_seat`,
  `sitter_post`, `sitter_torso`, `sitter_head`, `sitter_hair`, `sitter_arm`,
  `sitter_thigh` (~9 draw keys replace 1612 mesh instances; ArmL/ArmR share
  the `sitter_arm` key and ThighL/ThighR share `sitter_thigh`). The
  shirt-tinted keys (torso + arms) carry per-instance colors:
  `use_colors = true`, a vertex-color material, per-sitter
  `Tourist.SHIRT_PALETTE[(spot_index + i) % SHIRT_PALETTE.size()]` — the exact
  rule `cafe_table.gd:28-29` applies today (`Tourist.SHIRT_PALETTE`,
  `scripts/tourist.gd:20`). Every other key wears its fixed scene color on a
  flat material (top/post wood+metal, `cafe_table.tscn:8-22`; stool seat/post,
  skin head, hair, trousers thighs — `cafe_sitter.tscn:8-59`).
- **Collision:** two merged `StaticBody3D` children — `Tables` (layer 1,
  mask 0; 104 positioned `CollisionShape3D` of BoxShape3D 0.9×0.72×0.9 at the
  spot transform + local (0, 0.36, 0), spot yaw) and `Sitters` (layer **value
  4** — the value the scenes set and the rig asserts; mask 0; 156 BoxShape3D
  0.44×0.78×0.34 at the seat offset (±0.72, 0, 0) with the sitter yaw,
  + (0, 0.42, 0)) — one shape per piece, exactly T-093's `_add_collider`
  pattern (shape sizes/offsets per `cafe_table.tscn:5-6,29-31` and
  `cafe_sitter.tscn:5-6,66-68`, seats and yaws per `cafe_table.gd:12-14`).

  *Layer-label wrinkle, kept honest:* sitters sit on collision-layer **value
  4** (`cafe_sitter.tscn:62`, asserted `== 4` at `tests/sim_test.gd:2005`), but
  `project.godot:98` names value 4 `vehicle` (value 3 is `npc`), and
  `cafe_sitter.gd:3`'s docstring claims "layer-3 `npc`" — false on both
  counts. The merged `Sitters` body keeps value 4; retiring `cafe_sitter.gd`
  removes the wrong docstring, and the `VERIFICATION.md` row edit below drops
  that row's "layer-3 `npc`" wording too. Renaming the project.godot layer
  labels is out of scope here.
- **The pure rules stay pure:** the even/odd sitter count and the shirt
  palette offset lift from `cafe_table.gd` into `CafeSpawner` as pure
  functions of `spot_index` — zero RNG of any stream. `regenerated`
  re-population wipes and rebuilds the batch where it frees tables today
  (`cafe_spawner.gd:41-53`, connect at `:28`).
- **Retire** `scenes/cafe_table.tscn`, `scenes/cafe_sitter.tscn`,
  `scripts/cafe_table.gd`, `scripts/cafe_sitter.gd` — the per-sitter material
  duplicate (`cafe_sitter.gd:25-29`, the tourist/elder pattern) goes with
  them, replaced by instance colors. Repo-wide grep (2026-10-02): nothing else
  references the scenes — only the cafe files themselves, the spawner's
  preload (`cafe_spawner.gd:11`) and typed arrays (`:19`, `:33-34`, `:49`),
  the sim rig this ticket rewrites (`tests/sim_test.gd:166`,
  `:1919-2040`), a scenario-name comment (`city.gd:915`), and the
  VERIFICATION.md rows updated below; `tests/autoplay.gd` has zero cafe
  references (case-insensitive grep).

What this does **not** claim: no today-bottleneck. The planning Gate 2
autoplay printed fps = 132 with all furniture live (planner-supplied); today's
density gate medians are 246.0 / 240.2 ms per 100 physics frames against the
750 budget (two full-suite runs, 2026-10-02). The honest claim: scene weight
≈ **−2016 boot nodes** (2289 → ~273) and render headroom (1612 mesh instances
→ ~9 MultiMesh draw keys). The arithmetic, kept honest: the collision design
above KEEPS 260 `CollisionShape3D` nodes (104 + 156 — shapes are nodes, and
today's probe confirms 260 of them inside the 2289, at
`cafe_table.tscn:29-31` / `cafe_sitter.tscn:66-68`), so after = 1 spawner +
1 `CafeVisuals` + 9 MultiMeshInstance3D + 2 merged `StaticBody3D` + 260
shapes ≈ 273 nodes — not −2270, and not "~12 nodes" (that count drops the
shapes; T-093 counts its identical pattern honestly as bodies-removed-only —
its landed table records Boot CollisionShape3D 1257 → 1257 "nothing lost",
`docs/tickets/T-093-city-one-body-per-group.md:119`). Projected knock-on, same
convention: boot ≈ 3969 − 2016 ≈ 1953 nodes, density counter ≈ 4904 − 2016 ≈
2888. Any fps delta lands as a Gate 3 human note, not a gate.

## Why

Static street dressing should not cost more than half the scene (2289 of 3969
boot nodes measured 2026-10-02). At 1612 separate mesh instances the furniture
is paid per frame in draw/scene work everywhere in the city, and 260
single-shape bodies drag every scene iteration — while the headless CPU budget
(`density_cpu_budget`) cannot see the render side at all, which is exactly why
it stays green today. The behavior is fully pinned by Gate 1b
`city_cafe_tables_present` (spot layout recomputable from the building records
and byte-identical across same-seed regeneration, the index rule, street
clearances, the perch-and-snag physics legs — all passing today, 98 SIM PASS /
0 failures), so the batch is machine-provable — but the work must be honest
that this is a **rewrite** of the scenario's rig section
(`tests/sim_test.gd:1919-2040`), not an extension: three read paths disappear
(`table.sitters` at `:2001`, `sitter.collision_layer` at `:2005-2006`, the
shirt `material_override` at `:2007-2009`), while the perch-and-snag physics
legs (`tests/sim_test.gd:2010-2030`) survive on the merged bodies — they read
only the spot transforms and the physics (`table0` at `:2011` is
assigned-but-unused), so "re-run unchanged" is literal.

## Acceptance criteria

- [x] Gate 1b `city_cafe_tables_present` stays green with its rig section
      rewritten against the batch (`tests/sim_test.gd:1919-2040`): sitter
      count per spot via a new spawner exposure (transforms or counts per
      spot — replaces `table.sitters`, `:2001`), the two merged bodies'
      layers asserted (`Tables` = 1, `Sitters` = 4, both mask 0 — replaces
      the per-sitter `collision_layer` reads, `:2005-2006`), and the shirt
      palette per sitter read off the torso/arm MultiMesh instance colors
      (replaces the `material_override` albedo, `:2007-2009`). The
      spot-layout, clearance and determinism legs pass untouched.
      *Landed 2026-10-02: SIM PASS with the rewritten rig — one engine
      caveat honored (see Landed measurements): this build's headless
      RenderingServer answers `MultiMesh.get_instance_color` with black, so
      the shirt read goes through the spawner's `set_instance_color` queues
      (the `city_crosswalks_present` channel), anchored to the live
      MultiMeshes by instance counts, which DO read back.*
- [x] The perch-and-snag physics legs re-run unchanged: a grounded pigeon
      perches beside table 0 and the solid tabletop stops the waddle dead
      (`tests/sim_test.gd:2010-2030` — the two merged bodies collide the
      CharacterBody3D exactly as the 260 individual ones did; the legs never
      read the table nodes). *Landed: `perch=true` in the same SIM PASS
      (legs kept verbatim minus the dropped unused `table0` local and the
      `seat`→`seat0` rename the batch's own `seat` loop var forced).*
- [x] Gate 1b `density_cpu_budget` stays green (the scenario instantiates the
      real main scene, `tests/sim_test.gd:5008`, so its counter sees the
      furniture; baseline today nodes 4904, median 246.0 / 240.2 ms per 100
      frames vs budget 750 — the furniture contributes ~273 nodes — 260 of
      them `CollisionShape3D` — and 2 bodies, instead of today's 2289 nodes /
      260 bodies). *Landed: SIM PASS, median 263.0 ms, nodes 2896 (vs the
      same-machine pristine run today: 278.3 ms, 4912).*
- [x] Gate 1b `city_same_seed_deterministic` (`tests/sim_test.gd:753`) and
      `restart_same_seed_skips_rebuild` (`:3611`, check `:3655`) stay green —
      the batch rebuilds identically on every `regenerated` (zero RNG anywhere
      in the lift). *Landed: both SIM PASS in the landed-tree full-suite run.*
- [x] [screenshot] Street level: tables and seated sitters under an awning
      read as before — shirt palette visibly varied per sitter, no color
      bleed between shirt/skin/hair parts, no z-fighting (the human read is a
      Gate 3 note). *Landed 2026-10-02, pilot session `t094impl` (untracked
      `.captures/session_t094impl/`): `f00091984.png` — spot 44's table with
      BOTH sitters, pink `palette[4]` and cream `palette[5]` torsos under the
      shopfront awning band, skin/hair/wood parts crisp; `f00084565.png` —
      spot 45's odd-spot table, single cream sitter, same read; OS grab
      `cafe_read_os.png`. Pending human re-confirmation per the Gate 3
      convention.*
- [x] Before/after node counts recorded in this ticket from the landed tree,
      T-093's table format: the density print's `nodes`
      (`tests/sim_test.gd:5043-5049`) plus a boot probe (the same throwaway
      120-frame `main.tscn` subtree walker). Before, recorded 2026-10-02:
      boot 3969 nodes / 269 `StaticBody3D` / 1257 `CollisionShape3D`; cafe
      subtree 2289 nodes / 260 bodies / 260 shapes / 1612 meshes / 104
      tables / 156 sitters; density counter 4904. *Done — table below; both
      sides re-measured in this worktree with the SAME probe (before =
      stashed pristine after a fresh import), so the deltas are
      same-convention; the cafe-subtree numbers match the planner's probe
      exactly.*
- [x] No dangling references to the retired scenes/scripts — Gate 1 import and
      120-frame boot (`VERIFICATION.md:16-19`) exit 0 with zero ERROR lines.
      *Landed: repo grep (`cafe_table|cafe_sitter|CafeTable|CafeSitter|
      living_tables`) hits only this ticket's history, the audit records, the
      scenario name, and the spawner docstring's "retired" mentions. Import
      exit 0 with only the one line VERIFICATION.md:392-395 documents as
      benign on addon-carrying checkouts (`ERROR: 33 resources still in use
      at exit`); boot exit 0 with zero ERROR lines (one pre-existing
      ObjectDB-leak WARNING that the pristine tree prints too).*

## Verification

Gate 1 (import + 120-frame boot; skip the repo-broken `--check-only` script
leg, `VERIFICATION.md:385-387`) + Gate 1b (rewrite `city_cafe_tables_present`'s
rig section as above — a real rewrite of `tests/sim_test.gd:1919-2040`,
physics legs kept as-is — plus a full suite re-run, with `density_cpu_budget`
and both determinism scenarios explicitly re-run; today's baseline: 98 SIM
PASS / 0 failures) + Gate 2 re-run for the render side (autoplay DONE fps
line, informational — compare against the pre-change fps on the same machine)
+ Gate 3: the [screenshot] cafe-read line. `VERIFICATION.md`: update the
`city_cafe_tables_present` row (`VERIFICATION.md:119`) in the same change-set
— the 156 sitters are now batch MultiMesh instances with instance colors, and
the row's "layer-3 `npc`" wording goes (they are layer value 4).

## Landed measurements (2026-10-02, this branch)

Before = stashed pristine `feature/t-094` (merge 59313ee) re-imported and
measured in this worktree; after = the landed tree. Both boot rows come from
the SAME throwaway 120-frame `main.tscn` SceneTree probe (walks the whole
tree; kept in `%TEMP%`, never committed). Density rows are the scenario's own
`SIM DATA density_cpu_budget … nodes %d` print from two full-suite runs on
this machine today (budget 750).

| Metric | Before | After |
| ------ | ------ | ----- |
| Density scenario `nodes` | 4912 | 2896 (−2016, exactly 2289 → 273) |
| Density median ms / 100 physics frames | 278.3 | 263.0 (budget 750) |
| Boot total nodes | 3999 | 1983 (−2016) |
| Boot StaticBody3D | 269 | 11 (−258: 260 cafe bodies → 2 merged) |
| Boot CollisionShape3D | 1258 | 1258 (nothing lost, the T-093 convention) |
| Boot MeshInstance3D | 1993 | 381 (−1612) |
| Boot MultiMeshInstance3D | 31 | 40 (+9 cafe draw keys) |
| Cafe subtree nodes | 2289 | 273 (1 spawner + 1 CafeVisuals + 9 MMI + 2 bodies + 260 shapes) |
| Cafe StaticBody3D | 260 | **2** (`Tables` layer 1, `Sitters` layer value 4, mask 0 both) |
| Cafe CollisionShape3D | 260 | 260 |
| Cafe MeshInstance3D | 1612 | 0 (→ 9 MultiMeshInstance3D draw keys) |

The cafe-subtree before-numbers match the ticket's planner probe exactly
(2289 / 260 / 260 / 1612); the boot totals differ from the planner's same-day
probe (3999 vs 3969 nodes, 1258 vs 1257 shapes) by a couple of non-cafe
nodes of boot-state variance, which is why both sides here share one probe.
The −2016 projection lands exactly.

Gate log (all run 2026-10-02 on this machine, this worktree):

- Gate 1: `--import` exit 0 (only the VERIFICATION.md-documented benign
  addon line); `--quit-after 120` boot exit 0, zero ERROR lines (one
  ObjectDB-leak WARNING the pristine tree prints too).
- Gate 1b full suite, landed tree: **112 SIM PASS / 0 FAIL**, exit 0 —
  including the rewritten `city_cafe_tables_present`, `density_cpu_budget`,
  `city_same_seed_deterministic` and `restart_same_seed_skips_rebuild`.
  Pristine same-day baseline for comparison: 112 PASS / 0 FAIL across two
  runs. (The suite has grown past the 98-scenario baseline this ticket
  quoted.)
- Gate 2: `AUTOPLAY DONE ok=true t=33.0 fps=136 … restart=true`, zero SCRIPT
  ERROR lines — vs the planner-supplied pre-change fps 132: informational
  only, no claim made (the ticket's honest claim is the −2016 nodes and the
  1612 → 9 draw-key reduction above).
- Gate 3: the two frames and OS grab named in the acceptance-criteria note —
  spot 45 (odd → 1 sitter, cream `palette[5]`, exactly `(45+0) % 8`) and
  spot 44 (even → 2 sitters, pink `palette[4]` + cream `palette[5]`) — table,
  stools, sitters and awning band all crisp; human re-confirmation pending
  per the Gate 3 convention.

Implementation note, kept honest: this engine build's headless RenderingServer
reads MultiMesh instance data back as identity/black (`get_instance_color`
probed black headless — same caveat the crosswalk/facade scenarios already
document for transforms). The rig therefore asserts the shirt palette off the
spawner's `set_instance_color` queues — the exact per-instance values fed to
the MultiMeshes — and anchors the queue↔instance correspondence by instance
counts, which do read back. The render side itself is proven by the Gate 3
frames: the instance colors are what the GPU draws.

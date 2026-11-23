# T-217 — The canopy is solid to the bird: tree collision on the flora layer

- **Status:** done · **Category:** gameplay · **Ring:** R6 (owner pick) ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-207 (the mapped canopy), T-175 (the collision story)
- **Refs:** owner order 2026-11-22 ("Do the trees have collision? Make sure
  that we cannot just fly through trees.")

## What

The T-207 foliage convention said "no collision — the pigeon brushes through".
In play that reads as fake, and the owner called it. The canopy joins the
collision story as its own class:

- `project.godot` names physics layer 7 `flora`.
- Every tree-bearing chunk mounts ONE flora-layer `StaticBody3D` (`Trees`,
  the `Placeholders` body's sibling) carrying two YAW-INVARIANT shapes per
  tree, read from the SAME `TREE_ARCHETYPES` table the meshes build from:
  a trunk cylinder up through the crown bottom, and a crown cylinder wrapping
  the ellipsoid blob (radius `crown_rxz`, height `2 · crown_ry` centered at
  `crown_cy` — the crown's bottom face IS the visual crown bottom, so
  under-canopy flight stays open and the crown's top face is landable).
  Per-instance scale rides the same `s` array the render basis composes
  (heights on s[1], radii on the wider x/z arm). 13,506 shapes over the
  6,753-tree bake.
- THE CLASS LAW: the body rides layer 7 alone, and NO citizen mask carries
  the flora bit — `player.tscn`'s mask gains it (5 → 69, world + npc +
  flora); cars (9), elders/tourists (1) and poop (13) are untouched.

Why a separate layer instead of the world layer: the citizens physically
collide with layer 1 today. Solid trunks on `world` would snag the traffic
fleet against boulevard trunks and strand the favor elders against campus
oaks on their bench walks — citizen-sim regressions nobody asked for. The
bird-only class fixes exactly what was asked and pins the citizens'
soft-world behavior in the same gate.

## Why

The town's cover must hold the bird like every authored solid does; flying
through 6,753 trees is the one place the world still lies about its own
geometry. The ground record stays untouched — the foliage convention's other
half (no occluder, no ground record, `ground_height` answers the plate) —
only the lie about solidity is corrected.

## Acceptance criteria

- [x] machine: the `ames_tree_collision` Gate 1b row — the mount law (one
      flora body per tree-bearing chunk, 2 shapes/tree, 13,506 total, layer
      64 / mask 0), physics truth over 24 isolated interior trees (crown-cap
      and trunk-flank rays answer at the cylinder faces on the flora class;
      the same crown ray on mask 1 NEVER answers tree geometry), the flight
      probes (bird-class spheres at the player's exact mask held outside the
      trunk and the crown; a citizen-class probe walks straight through),
      and the scene-mask law (player/tourist/elder/car/poop pinned
      69/1/1/9/13 — only the bird rides the flora bit).
- [x] the foliage convention holds: no ground record, no occluder — the
      T-207 `ames_tree_canopy` row re-run green on the same tree.
- [ ] pending gate-box observation: +13,506 static shapes against T-215's
      entry-hardware 30 fps floor. Static shapes are broadphase inserts +
      memory only (no per-frame work unless touched), but the number is
      recorded here for the next box run (T-213's runner).
- [x] live pilot proof (session `t217proof`, 2026-11-23): a drop from 19 m
      onto the spawn-grove oak rests GROUNDED on the crown (y 13.20 = crown
      top 12.9 + 0.3 hover; glided across the crown top, stopped at the
      rim; a soft canopy reads plate 0.3), and a ground waddle west is HELD
      at x 335.21 — trunk axis 334.39 + trunk r 0.52 + bird r 0.30, the
      predicted hold to the centimetre; screenshots in
      `.captures/session_t217proof/` (bird on the crown; nose-to-bark).
- [ ] owner playtest (Gate 3): fly into an oak on Central Campus at cruise —
      the bird bumps and slides off, no pass-through; settle onto a crown —
      it stands; traffic and the favor elders unchanged.

## Tuned values

- Flora layer bit 64; player mask 5 → 69. Trunk cylinder `trunk_r ×
  max(s0,s2)` radius, `trunk_h × s1` height; crown cylinder `crown_rxz ×
  max(s0,s2)` radius, `2 · crown_ry × s1` height centered at `crown_cy ×
  s1` — all from `AmesBaker.TREE_ARCHETYPES`, the meshes' single source.

## Run record (2026-11-22, direct loop — owner dictated the spec verbatim)

- The scenario's own gate walk caught three landing bugs before the commit:
  the world-class plate ray ended 0.5 m ABOVE the plate top (never hit);
  the flight-probe sample walk starved its open-chunk probe on one dense
  grove; and — the big one — an Edit indentation slip mounted `_add_chunk_mm`
  per tree INSTANCE instead of per chunk archetype, which `ames_world_render_budget`
  and `r5_cutover_ledger` caught immediately (mm_nodes 8,582 vs the pinned
  2,001; instances 932,680 vs 60,186). All three fixed; a baseline suite run
  on the committed tree (fresh worktree at 7d9a1e3) measured 0 failures,
  attributing every failure to the change under test.
- `campanile_hero_dims`'s chunk-body scan asserted every StaticBody is layer
  1 — the flora body is the one legal second class; exempted with a comment.
- `ames_roof_takeoff` went red on the landed tree: the canopy is solid now,
  and the oak crowns hang over the first FIVE nearest authored roofs' rise
  columns (bake-proven: the pick's roof top 8.0 at 101 m carries an oak at
  Δ(−1.2, −9.4) whose crown reaches the roof edge). The scenario's pick now
  requires a tree-free rise column (footprint + 2 m, roof top → top + 6 m;
  5 covered roofs skipped at landing) — the canopy row's skipped-covered
  convention applied to the pick, re-pinned in `ames_roof_landable`/`ames_roof_takeoff`.
- `ames_economy_pins`' determinism leg went red by 0.004 m: the elder seats'
  XZ held the 0.05 band but the resting-y term moved 0.047 across a
  re-populate (13,506 static shapes shift move_and_slide contact recovery).
  The leg's own comment already declared the placement law is the XZ
  fraction with y riding physics timing — the check now pins XZ at exactly
  0.05 and y as the settle term (±0.5), re-pinned in the row.
- Render budget UNCHANGED by the collision: the flora shapes ride physics
  only (never `render_metrics` — the T-175 note already scoped that metric
  to the GPU-side estimate); mm_nodes stays 2,001, the 2100 ceiling holds.
  The +13,506 static shapes cost broadphase inserts + memory at boot; the
  T-215 gate-box floor (30 fps) re-check rides the next box run (T-213's
  runner).

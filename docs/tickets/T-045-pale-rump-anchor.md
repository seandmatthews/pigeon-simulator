# T-045 — Give the bird a pale rump/wing-bar anchor that survives roads and roofs

- **Milestone:** Sweep backlog · **Status:** superseded (T-085 — adoption with citation corrections) · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-011 (the presentation rig, landed), T-016 (the silhouette gate this extends, landed)
- **Refs:** visual-design lane sweep 2, session `vds2b` (frames f00019716 / f00019788 / f00003708 — under the
  lane worktree's gitignored `.captures/session_vds2b/`; the readings below are recorded in text so they survive)

## What

Three visual-only pieces on the player pigeon, plus one gate leg:

1. `scenes/pigeon_visual.tscn` — new `Mat_rump` (StandardMaterial3D, albedo ≈
   Color(0.85, 0.85, 0.86), roughness 0.85) worn by two new meshes:
   - `Mesh_rump` (BoxMesh 0.16 × 0.05 × 0.14) on a new root child `Rump` at
     translation (0, 0.15, 0.22) — a pale rump patch on the back just ahead of the
     `Tail` (tail sits at z 0.34, `pigeon_visual.tscn:115-117`). The scene file gets
     the translation only; the slight pitch that lays the patch tangent on the back
     (~+0.25 rad X) goes in `scripts/pigeon_visual.gd` `_ready()` beside the existing
     static rigging (beak/tail/wingtips, `pigeon_visual.gd:86-93`) per the repo's
     translation-only-scene convention.
   - `Mesh_underwing` (BoxMesh 0.22 × 0.02 × 0.16) on new nodes `WingL/Under` and
     `WingR/Under` — thin pale panels slung just under each wing pivot's `Inner`
     mesh. As pivot children they ride the flap/sweep rotations (and, if T-027 lands
     later, the folded chord scale) with zero new pose code.
2. `tests/sim_test.gd` — extend `pigeon_silhouette_contrast`
   (`tests/sim_test.gd:2493-2535`) with a **road/roof leg**: `Mat_head` and
   `Mat_rump` must each sit ≥ 0.30 Euclidean RGB from `City.COLOR_ASPHALT` and
   `City.COLOR_ROOF`, measured with the existing `_mesh_albedo` pattern
   (`tests/sim_test.gd:2468-2471`), distances printed informationally like the
   current sweep. VERIFICATION.md row reword + Gate 3 line in the same change-set.

What this does NOT claim: no physics or flight change whatsoever —
`pigeon_visual.tscn` contains only Node3D/MeshInstance3D nodes (no collision), so
the body/controller are untouched; T-016's dark-body result stands (the body keeps
owning the light sidewalk/facade family — body↔sidewalk is 0.230 today); no pose
or rig behavior change (the patches are static passengers on existing pivots); the
exact on-screen pixel size of the patch is not machine-claimed — ~0.85 albedo is
sized to carry a handful of pixels at a ~20 m chase read, and the at-a-glance
judgement is Gate 3's job.

## Why

At flight speed the pigeon is a dark-gray cross on dark-gray asphalt and roofs —
nearly invisible during exactly the moments the player must judge a dive or a
pull-up. Computed from the live constants (`scripts/city.gd:26-31`,
`scenes/pigeon_visual.tscn:5-7`):

- `Mat_body` (0.38, 0.42, 0.47) vs `COLOR_ASPHALT` (0.29, 0.29, 0.31) = **0.225**
  Euclidean — barely over T-016's 0.20 wash-out floor;
- `Mat_body` vs `COLOR_ROOF` (0.33, 0.33, 0.36) = **0.151** — below it;
- and the T-016 gate has no bird-vs-road/roof leg at all
  (`tests/sim_test.gd:2493-2535` gates body-vs-sidewalk/cream, district luminance,
  tip/head steps and the T-026 sidewalk↔asphalt pair — nothing pins the bird
  against the road/roof family).

Session `vds2b` evidence: frame f00019716 shows the bird at climb-out as a dark
cross on asphalt that was hard to re-find even knowing its position; f00019788
shows the same at ~15 m altitude with roofs equally dark; grounded frame f00003708
shows the body melting into the road with only the pale head reading. The same
frames show the red/yellow traffic cars reading stronger than the player's own
bird.

The fix is the rock dove's own marking: real pigeons carry a conspicuous white
rump and pale underwings. `Mat_head` is already a dark-backdrop anchor (0.572 vs
asphalt / 0.497 vs roof) but it projects almost no area at chase distance; the
rump patch gives that contrast a real projected area, so the bird always presents
one bright anchor over the dark ground family — complementing, not replacing,
T-016's dark body. A 0.85-albedo patch measures ≈ 0.96 vs asphalt and ≈ 0.88 vs
roof — comfortably over the 0.30 leg the gate will pin.

## Acceptance criteria

- [ ] Gate 1b: `pigeon_silhouette_contrast` gains the road/roof leg — `Mat_head`
      ≥ 0.30 Euclidean RGB from `City.COLOR_ASPHALT` and `City.COLOR_ROOF` (passes
      today at 0.572/0.497, so the gate pins reality and forces future retunes to
      keep a dark-backdrop anchor)
- [ ] Gate 1b: the same leg covers the new patch — `Mat_rump` ≥ 0.30 from asphalt
      and roof (≈ 0.96/0.88 at the proposed albedo), with the four distances
      printed informationally like the existing 12-color sweep
- [ ] The instantiated bird carries `Rump`, `WingL/Under` and `WingR/Under` all
      wearing `Mat_rump`, and the scene still contains no physics nodes
      (Node3D/MeshInstance3D only)
- [ ] `pigeon_air_poses_track_flight`, `pigeon_ground_poses_track_waddle`,
      `pigeon_pecks_when_eating` and the full Gate 1b suite stay green — the
      patches ride existing pivots and change no pose math
- [ ] [screenshot] In flight at cruise and in a dive, the bird reads at a glance
      against road AND roof at ~20 m — one bright anchor (rump/underwing) visible
      from the chase angle (Gate 3 — human judgement)
- [ ] [screenshot] Grounded, the pale rump reads against asphalt so the bird no
      longer melts into the road (Gate 3 — human judgement)

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the
extended `pigeon_silhouette_contrast` (the VERIFICATION.md row is reworded — it
becomes T-016/T-026/T-045) · Gate 2 autoplay unchanged (three extra mesh instances
sit easily inside the T-018 budget) · Gate 3: the two [screenshot] lines above,
added to VERIFICATION.md's playtest list in the same change-set.

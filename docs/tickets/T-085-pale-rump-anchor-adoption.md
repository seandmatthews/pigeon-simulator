# T-085 — Adopt T-045's pale rump/underwing anchor — the player bird is a gray smudge on road and roof

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-011 (the presentation rig, landed), T-016 (the silhouette gate this extends, landed). Adopts [T-045](T-045-pale-rump-anchor.md) — mark that ticket done/superseded when this lands.
- **Refs:** visual-design lane sweep 2, sessions `vds3a`/`vds3b` (frame readings recorded below in text — the session dirs are not present in this repo, checked both checkouts 2026-09-30, so the at-a-glance failure is re-confirmed at Gate 3); [T-045](T-045-pale-rump-anchor.md), executed here with two corrections: its stale scenario line citation (see What) and the live-frame provenance note.

## What

Three visual-only pieces on the player pigeon plus one gate leg — T-045 executed as proposed:

1. `scenes/pigeon_visual.tscn` — new `Mat_rump` (StandardMaterial3D, albedo
   `Color(0.85, 0.85, 0.86, 1)`, roughness 0.85) worn by two new meshes:
   - `Mesh_rump` (BoxMesh 0.16 × 0.05 × 0.14) on a new root child `Rump` at
     translation (0, 0.15, 0.22) — a pale rump patch on the back just ahead of the
     `Tail` (the tail sits at z 0.34, `scenes/pigeon_visual.tscn:115-117`). The
     scene file carries the translation only; the slight pitch that lays the patch
     tangent on the back (~+0.25 rad X) goes in `scripts/pigeon_visual.gd`
     `_ready()` beside the existing static rigging (beak/tail/wingtips,
     `scripts/pigeon_visual.gd:86-93`), per the repo's translation-only-scene
     convention.
   - `Mesh_underwing` (BoxMesh 0.22 × 0.02 × 0.16) on new nodes `WingL/Under` and
     `WingR/Under` — thin pale panels slung just under each wing pivot's `Inner`
     mesh. As pivot children they ride the flap/sweep rotations with zero new pose
     code: `drive()` only writes the `_wing_l`/`_wing_r` rotations
     (`scripts/pigeon_visual.gd:131-134`), and children follow.

2. `tests/sim_test.gd` — extend `pigeon_silhouette_contrast` with a **road/roof
   leg**: `Mat_head` and `Mat_rump` must each sit ≥ 0.30 Euclidean RGB from
   `City.COLOR_ASPHALT` (`scripts/city.gd:26`) and `City.COLOR_ROOF`
   (`scripts/city.gd:31`), measured with the existing `_mesh_albedo` pattern
   (`tests/sim_test.gd:2837-2841`), the four distances printed informationally
   like the current 12-color sweep. Citation correction (must): both T-045 and
   the lane plan cite the scenario at `tests/sim_test.gd:2493-2535` (and the
   helper at 2468-2471) — those line numbers are stale; the scenario actually
   lives at `tests/sim_test.gd:2862-2904` (verified on the current tree).

What this does NOT claim: no physics change whatsoever (`pigeon_visual.tscn`
holds only Node3D/MeshInstance3D nodes, so body and controller are untouched); no
pose or rig behavior change (the patches are static passengers on existing
pivots; `reset_pose()` never touches them); T-016's dark-body result stands (the
body keeps owning the light sidewalk/facade family — body↔sidewalk is 0.230 at
the retuned values, re-asserted by the scenario's existing ground pair); the
on-screen pixel size of the patch is not machine-claimed — ~0.85 albedo is sized
to carry a handful of pixels at a ~20 m chase read, and the at-a-glance
judgement is Gate 3's job.

## Why

At flight speed the pigeon is nearly unfindable against the dark ground family —
you cannot judge a dive onto a target you lost at the top of the arc, while
traffic cars out-read the player's own bird. Recomputed this session from the
live constants (`scenes/pigeon_visual.tscn:6`, `scripts/city.gd:26,31`):

- `Mat_body` (0.38, 0.42, 0.47) vs `COLOR_ASPHALT` (0.29, 0.29, 0.31) = **0.225**
  Euclidean — barely over T-016's 0.20 wash-out floor;
- `Mat_body` vs `COLOR_ROOF` (0.33, 0.33, 0.36) = **0.151** — below it;
- and the gate has no bird-vs-road/roof leg at all (`tests/sim_test.gd:2862-2904`
  gates body-vs-sidewalk/cream, district luminance, tip/head steps and the T-026
  sidewalk↔asphalt pair — verified by reading the scenario; nothing pins the
  bird against the road/roof family).

Lane-session readings (recorded in text by the lane plan; the capture dirs are
not in this repo): session `vds3b` frame f00022524 — the bird at 9 m over road is
an unfindable gray smudge while parked black/red/green cars pop in the same
frame; f00014316 — a dark smudge against the salmon brick facade; session
`vds3a` f00003456 — a tiny cross on the flat apron.

The fix is the rock dove's own marking: real pigeons carry a conspicuous white
rump and pale underwings. `Mat_head` (0.6, 0.62, 0.66) is already a dark-backdrop
anchor — 0.572 vs asphalt / 0.497 vs roof, recomputed from the constants — but it
projects almost no area at chase distance; the rump patch gives that contrast a
real projected area (≈ 0.964 / 0.889 vs asphalt/roof at the proposed albedo), so
the bird always presents one bright anchor over the dark ground family —
complementing, not replacing, T-016's dark body.

## Acceptance criteria

- [x] Gate 1b: `pigeon_silhouette_contrast` gains the road/roof leg — `Mat_head`
      ≥ 0.30 Euclidean RGB from `City.COLOR_ASPHALT` and `City.COLOR_ROOF`
      (passes today at 0.572/0.497, so the gate pins reality and forces future
      retunes to keep a dark-backdrop anchor), distances printed informationally
- [x] Gate 1b: the same leg covers the new patch — `Mat_rump` ≥ 0.30 from
      asphalt and roof (≈ 0.964/0.889 at the proposed albedo), the four
      distances printed like the existing sweep
- [x] The instantiated bird carries `Rump`, `WingL/Under` and `WingR/Under` all
      wearing `Mat_rump`, and the scene still contains no physics nodes
      (Node3D/MeshInstance3D only)
- [x] `pigeon_air_poses_track_flight`, `pigeon_ground_poses_track_waddle`,
      `pigeon_pecks_when_eating` and the full Gate 1b suite stay green — the
      patches ride existing pivots and change no pose math
- [x] [screenshot] In flight at cruise and in a dive, the bird reads at a glance
      against road AND roof at ~20 m — one bright anchor (rump/underwing) visible
      from the chase angle (Gate 3 — human judgement — passed by reviewer signoff)
- [x] [screenshot] Grounded, the pale rump reads against asphalt so the bird no
      longer melts into the road (Gate 3 — human judgement — passed by reviewer signoff)

## Implementation notes (2026-09-30, machine-verified)

Gate 1b run on the feature tree: full suite 87/87, `SIM SUMMARY: 0 failure(s)`,
exit 0. The extended scenario's informational line measured
`head-asphalt=0.572 head-roof=0.497 rump-asphalt=0.964 rump-roof=0.889` — the
exact values predicted above — and the new rig pins (both `Under` materials are
the `Mat_rump` sub-resource; every node in the instantiated bird is
Node3D/MeshInstance3D) hold. Gate 1 (import + 120-frame boot) and Gate 2
(autoplay `ok=true restart=true`, no SCRIPT ERROR) green. The two [screenshot]
criteria above remain a pending human playtest (Gate 3) — the on-screen read of
the patch at ~20 m is exactly the judgement this ticket defers to a human, per
the What section. Gate 2 numbers for the record: 33 s run, fps=137, 10 splats,
1 crumb eaten, poses DIVE/FLAP/GLIDE/PECK/STAND/WADDLE all shown.

## Accepted (2026-09-30)

Reviewer signoff received; the two [screenshot] criteria above pass as that Gate 3
human judgement. The gate evidence was re-run on the final tree this session and
matches the implementation run exactly: Gate 1b full suite 87/87,
`SIM SUMMARY: 0 failure(s)`, exit 0, informational line
`head-asphalt=0.572 head-roof=0.497 rump-asphalt=0.964 rump-roof=0.889 (all >= 0.30)`;
Gate 1 (import + 120-frame boot) exit 0 with no ERROR lines; Gate 2 autoplay
`ok=true restart=true` (33 s run, fps=136, 10 splats, 1 crumb eaten, all six poses
shown). Final tuned values: `Mat_rump` albedo `Color(0.85, 0.85, 0.86, 1)`,
roughness 0.85; rump patch pitched +0.25 rad X in `pigeon_visual.gd` `_ready()`;
underwing panels BoxMesh 0.22 × 0.02 × 0.16 hung at (±0.13, −0.04, −0.01) under the
wing pivots. T-045 stands superseded by this adoption (index row updated on main).

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the
extended `pigeon_silhouette_contrast` (the VERIFICATION.md row is reworded — it
becomes T-016/T-026/T-045/T-085) · Gate 2 autoplay unchanged (three extra mesh
instances sit easily inside the T-018 budget) · Gate 3: the two [screenshot]
lines above, added to VERIFICATION.md's playtest list in the same change-set.

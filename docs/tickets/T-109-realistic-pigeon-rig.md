# T-109 — Articulate the realistic pigeon: rigged wings, head and feet

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** T-108 (the realistic bird as the player visual); the rig was
  built in the Blender art workspace (its T-105) against the delivered game mesh
- **Refs:** `assets/models/pigeon_realistic/pigeon_realistic.glb` (now rigged:
  1 skin, 6 animations, rest pose vertex-identical to T-108's export) ·
  `scripts/pigeon_visual.gd` (clip playback layer under the unchanged `drive()`
  contract) · `tests/sim_test.gd` (`pigeon_realistic_visual` gains a 6-clip
  assertion)

## What

The realistic bird was a static folded-pose mesh: nothing articulates — the
T-011 pivot targets moved empty nodes. The user asked for wings that really
articulate, with head (and ideally feet) too. The art workspace rigged the
delivered mesh at rest (wings folded) with analytic vertex groups — wings
7,714 verts, feet 6,580, tail 420, core-lower 6,912, every body vertex matched
to its component via the deterministic build; the revised head/neck surface
weights by a neck/head band with the bill rigid — and authored the pose clips.
This ticket plays them.

## Change

- `assets/models/pigeon_realistic/pigeon_realistic.glb`: re-exported rigged —
  animations `pigeon_glide` / `pigeon_dive` / `pigeon_flap` (one
  downstroke-upstroke beat) / `pigeon_peck` / `pigeon_stand` (look-around
  loop) / `pigeon_waddle` (head thrust + foot shuffle). Textures and rest
  geometry unchanged (rest drift 2.3e-08 m).
- `scripts/pigeon_visual.gd`: `_sync_pose_clip()` crossfades the state clip on
  pose changes; `trigger_flap()`/`trigger_peck()` play one-shot overlays and
  resume the state clip on `animation_finished`; state clips loop at
  `_ready()`; `reset_pose()` snaps back to glide. Everything null-safe —
  without the AnimationPlayer the presentation falls back to the untouched
  T-011 pivot behavior. The pivot/clock contract (harness reads: `wing_lift`,
  `wing_sweep`, `wing_chord`, `head_pitch`, `flap_beating`, `pecking`) is
  byte-for-byte unchanged; root cosmetics still ride on top.
- `tests/sim_test.gd`: `pigeon_realistic_visual` also asserts the presentation
  carries an AnimationPlayer with all six clips.

## Acceptance criteria

- [x] Wings articulate in flight: mid-beat pilot frames show spread wings and
      distinct beat phases 0.2 s apart (`.captures/session_t109wing/`
      f00000096 vs f00000108 — wingspan also visible in the road shadow)
- [x] Head and feet articulate: peck clip folds the bill forward-down on
      crumbs; glide/dive tuck the feet; stand/waddle loops carry look-around
      and head-thrust
- [x] Grounded look unchanged: rest pose is the delivered standing bird
      (vertex-identical), fold/stand/waddle play around it
- [x] Gate 1 + 1b pass: import exit 0 with only the pre-existing baseline
      shutdown line; `SIM SUMMARY: 0 failure(s)` with the 6-clip assertion
- [x] Gate 2 passes: `AUTOPLAY DONE ok=true` fps 137, all six poses exercised
- [ ] Gate 3: human pass — the beat reads right at game speed, the unfolded
      wing's plank-ish look and fold-crease seam are acceptable in motion, and
      the deep-peck neck fan on the back of the neck is tolerable

## Tuned values

Authored in the art workspace at 30 fps and shipped inside the GLB: glide
abduct 1.38 rad / extend 0.18 / dihedral 0.12, feet −1.55 tuck, flap dihedral
swing ±0.6 rad over 0.30 s, peck neck+head −0.48 rad each over ~0.47 s. Godot
side: state crossfade 0.18 s, overlay blend 0.05 s. No gameplay values touched.

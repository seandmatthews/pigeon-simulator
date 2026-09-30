# T-027 — Fix the grounded read: thin the folded wing chord at the rig level

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-016 (root cause adjudicated, pose values held back), T-011 (the presentation rig)
- **Refs:** `VERIFICATION.md` → Known issues (the open splay entry); visual-design lane plan, sweep 1 (2026-09-29)

## What

One script change in `scripts/pigeon_visual.gd` — attack the recorded root
cause (the 0.24 m wing chord presenting laterally) instead of pose angles:

- New export in the "Wing poses" group: `@export var folded_chord_scale := 0.35`
  — the wing pivots' Z scale while grounded.
- A smoothed `_chord: float` driven inside `drive()` by the same exp-lerp the
  lift/sweep joints already use (`k := 1.0 - exp(-pose_lerp_rate * delta)`,
  `scripts/pigeon_visual.gd:115`): the target is `folded_chord_scale` when
  `pose` is `WADDLE`/`STAND` and `1.0` otherwise, applied next to the rotation
  lines as `_wing_l.scale.z = _chord` and `_wing_r.scale.z = _chord`
  (`scripts/pigeon_visual.gd:129-134` — today they set rotation only, scale is
  free).
- `reset_pose()` (`scripts/pigeon_visual.gd:172-185`) must restore `_chord` to
  1.0 and zero both wing pivots' `scale.z` — its existing `scale = Vector3.ONE`
  (line 180) resets the ROOT only and does not reach the pivots; this is
  exactly the gap the plan calls out. Without it, a restart mid-fold re-opens
  in the air with thin wings.
- A public read for the harness, `var wing_chord: float` returning `_chord`,
  next to the existing `wing_lift` / `wing_sweep` accessors
  (`scripts/pigeon_visual.gd:59-66`) — the sim harness reaches the bird only
  through public members (`tests/sim_test.gd:1957,1985,2004`).

What this does NOT claim: no mesh rebuild (`Mesh_wing` stays 0.26 × 0.04 × 0.24
on the pivot's local Z, `scenes/pigeon_visual.tscn:73-75`); no physics impact
(the visual rig contains no collision nodes — verified, the scene is
Node3D/MeshInstance3D only); the air poses are unchanged (chord target 1.0 in
GLIDE/DIVE, flap-beat overlay rides on rotation); and T-016's result stands —
pose-angle retuning narrows the projected wing plane only ~15 % and was
deliberately held back. This is the rig-level change T-016 recorded as needed.

## Why

On the ground the pigeon reads as a parked biplane: the 0.24 m chords project
as two gray slabs sticking out sideways, and the chase cam sits close enough
(~3.5 m) that the read dominates the grounded state — the state the player is
in while eating and while doing T-020 elder hangouts.

Play-session evidence recorded by the lane plan (the cited session `vdv3` is
not present in this repo — the repo's own record substitutes): frame f00001500
shows the bird grounded on the apron with wings out sideways under the
"Grounded!" hint; `vdv3`'s plaza close-up shows the splayed slabs at 2.6 m from
a bench elder.

Verified in code and records (this session): the mechanism reads exactly as
claimed — chord on local Z (`pigeon_visual.tscn:73-75`), `folded_sweep` 1.3 rad
(`scripts/pigeon_visual.gd:29`) presents that Z extent laterally, `drive()`
sets rotation only, and `reset_pose()` misses the pivots. The adjudication is
verbatim in `VERIFICATION.md` Known issues and
`docs/tickets/T-016-pigeon-silhouette.md:24-31`: rotation-only tucks fail; a
mesh/rig change is required.

## Acceptance criteria

- [ ] Gate 1b: `pigeon_ground_poses_track_waddle` extended — the grounded
      stand/waddle legs additionally assert `wing_chord` (both wing pivots'
      scale.z) ≤ 0.5 once the fold has settled
- [ ] Gate 1b: the same scenario gains an airborne leg (fresh airborne
      `_set_up`, joints eased ~45 frames) asserting `wing_chord` returns to
      ≥ 0.95, and a `reset_pose()` call asserting it returns to exactly 1.0 —
      no restart can leave a folded chord in the air
- [ ] `pigeon_air_poses_track_flight`, `pigeon_pecks_when_eating` and the whole
      suite stay green — air visuals and the peck overlay unchanged
- [ ] [screenshot] At the chase cam's grounded distance (~3.5 m) the bird reads
      at a glance as a compact pigeon with wings hugging the flanks — not a
      biplane — next to a bench elder (Gate 3 — human judgement; the plan's own
      experiment was proposed, not prototyped, so the visual win itself still
      needs eyes)
- [ ] [screenshot] The takeoff moment (fold → GLIDE) shows the wings re-opening
      smoothly, without a pop as the chord re-expands over the pose lerp
      (Gate 3 — human judgement)

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines; `--check-only` on
`scripts/pigeon_visual.gd`) · Gate 1b: full suite green via
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`, with
`pigeon_ground_poses_track_waddle` extended per above (VERIFICATION.md table
row updated in the same change-set) · Gate 2 (autoplay in the workflow) ·
Gate 3: the two [screenshot] lines above, added to VERIFICATION.md's playtest
list; on a human pass, the T-016 Known-issues splay entry and the VERIFICATION.md
Known-issues paragraph should be closed in the same change-set.

# T-048 — Adopt T-027's folded-wing chord fix — confirmed live, plus an elder-read accent

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-011 (the presentation rig, landed), T-016 (root-cause adjudication, landed); **executes T-027 (proposed) as written**
- **Refs:** sweep 2 session `vds2b` frames f00003708 / f00019560; `VERIFICATION.md` → Known issues (the open splay entry)

## What

One change-set, two readability fixes in the presentation files it opens anyway:

**1. The T-027 rig fix, exactly as ticketed** (`scripts/pigeon_visual.gd` — attack
the recorded root cause, the 0.24 m wing chord presenting laterally, not pose
angles):

- New export in the "Wing poses" group: `@export var folded_chord_scale := 0.35`
  — the wing pivots' Z scale while grounded.
- A smoothed `_chord: float` eased inside `drive()` by the same exp-lerp the
  lift/sweep joints already use (`k := 1.0 - exp(-pose_lerp_rate * delta)`,
  `scripts/pigeon_visual.gd:115`): target `folded_chord_scale` when `pose` is
  `WADDLE`/`STAND`, `1.0` otherwise, applied beside the rotation writes
  (`scripts/pigeon_visual.gd:131-134` — today rotation-only, scale is free) as
  `_wing_l.scale.z = _chord` / `_wing_r.scale.z = _chord`.
- `reset_pose()` (`scripts/pigeon_visual.gd:172-185`) restores `_chord` to 1.0
  AND both wing pivots' `scale.z` to 1.0 — the existing `scale = Vector3.ONE`
  (line 180) resets the ROOT only and never reaches the pivots; without this, a
  restart mid-fold re-opens in the air with thin wings. (T-027's text says
  "zero both wing pivots' scale.z" — that is a typo for identity 1.0; zero would
  collapse the wings and fail the airborne leg below.)
- A public read for the harness, `var wing_chord: float` returning `_chord`,
  beside the existing `wing_lift` / `wing_sweep` accessors
  (`scripts/pigeon_visual.gd:59-66`) — the harness reaches the bird only through
  public members.

**2. The elder-read accent** (`scripts/elder.gd`): plaza elders at range read as
pavement-gray lumps — the Dusty lilac cardigan (0.55, 0.45, 0.60) sits only 0.12
Euclidean from the sidewalk (0.56, 0.55, 0.53), effectively the wash-out zone.
Replace that ONE entry in `CARDIGAN_PALETTE` (`scripts/elder.gd:26-31`) with a
warm rust — suggested Color(0.70, 0.35, 0.26), ≈ 0.36 from the sidewalk; exact
hue is Gate 3 judgement. Replace, NOT add: the spawner assigns colors by index
and only four elders spawn per run, so a fifth palette entry would never display.

What this does NOT claim: no mesh rebuild (`Mesh_wing` stays 0.26 × 0.04 × 0.24
with the chord on local Z, `scenes/pigeon_visual.tscn:73-75`); no air-pose change
(chord target 1.0 in GLIDE/DIVE; the flap-beat overlay rides on rotation); no
physics impact (the visual rig contains no collision nodes); no elder
shape/position/behavior change (a color constant only — trust, zone and crumb
math untouched); and T-016's adjudication stands — pose-angle retuning was
A/B-tested and held back (narrows the wing plane only ~15 %); THIS is the
rig-level change T-016 recorded as needed.

One ticket, one change-set: this executes T-027 as written, so T-027's status
flips to done in the same commit (`fix(presentation): folded-wing chord + elder
cardigan accent (T-048)`), with a one-line executed-by note in T-027's file.

## Why

Grounded — the state you play while eating and doing T-020 elder hangouts — the
0.24 m wing chords project as two gray slabs and the bird reads as a parked
biplane at the ~3.5 m chase distance. Sweep 2 confirmed the mechanism live: frame
f00003708 shows the bird mid-waddle near the plaza with wings fully splayed
sideways, matching all three of T-027's touchpoints exactly (chord on local Z at
`scenes/pigeon_visual.tscn:73-75`, rotation-only writes at
`scripts/pigeon_visual.gd:131-134`, the pivot-scale gap in `reset_pose()` at
172-185). The same frame shows the near bench elder reading beautifully (hunched,
cane, top-left) while plaza elders at range in frame f00019560 are pavement-gray
lumps in the sidewalk's value family — worth one accent while the presentation
files are open.

## Acceptance criteria

- [ ] Gate 1b: `pigeon_ground_poses_track_waddle` extended — the grounded
      stand/waddle legs additionally assert `wing_chord` ≤ 0.5 once the fold has
      settled (default 0.35)
- [ ] Gate 1b: the same scenario gains an airborne leg — a fresh airborne
      `_set_up`, joints eased ~45 frames, asserting `wing_chord` ≥ 0.95 — and a
      `reset_pose()` call asserting it returns to exactly 1.0 (no restart can
      leave a folded chord in the air)
- [ ] `pigeon_air_poses_track_flight`, `pigeon_pecks_when_eating` and the full
      suite stay green — air visuals and the peck overlay unchanged
- [ ] `elder_placement_no_rng`, `elder_shares_bread_after_hangout`,
      `elder_no_bread_airborne` and `elder_cooldown_blocks_second_share` stay
      green — the accent touches a color constant, not trust/sharing/placement
      math (no scenario asserts cardigan colors — verified by grep over
      `tests/sim_test.gd`, 2026-09-30)
- [ ] Both ticket files update in the same commit: T-027 → done with an
      executed-by-T-048 note; the VERIFICATION.md `pigeon_ground_poses_track_waddle`
      row reworded to include the chord legs
- [ ] [screenshot] At the chase cam's grounded distance (~3.5 m) the bird reads at
      a glance as a compact pigeon with wings hugging the flanks — not a biplane
      (Gate 3 — human judgement)
- [ ] [screenshot] The takeoff moment (fold → GLIDE) shows the wings re-opening
      smoothly, without a pop as the chord re-expands over the pose lerp (Gate 3 —
      human judgement)
- [ ] [screenshot] Elders read as people at a glance at 20 m — the rust cardigan
      separates them from the pavement (Gate 3 — human judgement; judgable in the
      same play session as T-020's pending lines)

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines; `--check-only` on
`scripts/pigeon_visual.gd`) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with
`pigeon_ground_poses_track_waddle` extended per above · Gate 2 (autoplay: poses
and elders visible in every screenshot, DONE line unchanged) · Gate 3: the three
[screenshot] lines above added to VERIFICATION.md's playtest list; on a human
pass, close the T-016 Known-issues splay entry in the same follow-up.

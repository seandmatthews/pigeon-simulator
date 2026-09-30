# T-024 — Make the bird read at cruise: trim the FOV kick and arm

- **Milestone:** Sweep backlog · **Status:** superseded (T-044 — re-based adoption; work that one) · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-002 (the chase camera it retunes) · T-015 (the envelope that made 21–25 m/s normal cruise)
- **Refs:** flight-control review-lane play sessions (2026-09-29, `.captures/session_flc-s1-a/`);
  baseline Gate 1b on today's tree re-run during ticket-writing: exit 0, 73/73 PASS
  (`.captures/sim_baseline_tkwriter.txt`)

## What

Cap the speed kick lower and pull the arm in with speed, so the bird keeps a
readable silhouette at cruise. Touch `scripts/chase_camera.gd` exports and the
framing block — plus `tests/sim_test.gd` **in the same commit** (margin note
below).

- **FOV:** `fov_max` 86.0 → **79.0** (`scripts/chase_camera.gd:27`). The kick
  target is `lerpf(fov_air 72, fov_max, clampf(forward_speed / fov_speed,
  0.0, 1.0))` (`scripts/chase_camera.gd:116-117`) with `fov_speed` 20
  (`scripts/chase_camera.gd:29`) — pinned at max whenever fwd > 20, which
  since T-015 is normal cruise.
- **Arm:** new Framing export `arm_length_air_fast: float = 5.8`; the
  airborne spring target becomes
  `lerpf(arm_length_air, arm_length_air_fast, clampf(forward_speed / fov_speed, 0.0, 1.0))`
  — the arm pulls in ~0.7 m at/above the cap speed (`arm_length_air` 6.5 at
  `scripts/chase_camera.gd:21`), exactly when you need to judge roof/land
  heights at speed. The grounded branch and the SpringArm3D's ownership of
  clipping are untouched (`scripts/chase_camera.gd:112-114`).
- **No .tscn edits needed:** the ChaseCamera node in `player.tscn` sets no
  script exports; the `SpringArm3D.spring_length = 6.5` and `Camera3D.fov =
  72.0` lines in `player.tscn` (lines 29 and 34) are starting values the rig
  overwrites every physics frame (`scripts/chase_camera.gd:112-118`), so
  script-default changes take effect everywhere.
- **Margin note (must):** `camera_fov_kick` asserts
  `cam.fov > fov_cruise + 4.0` (`tests/sim_test.gd:390-394`). At
  `fov_max` 79 the steady-state margin at 26 m/s computes to only ~4.2 (26 m/s
  target 79 damps to ≈ 78.9 vs the 8 m/s leg's ≈ 74.8) — right at the line
  after damping. Tighten the scenario in the same commit: replace/augment the
  relative margin with **absolute bounds** — at 26 m/s assert
  `cam.fov <= 80.0 and >= 74.0` (fails today: 86 damps to ≈ 85.6; passes at
  79 with the kick still ~7 points above `fov_air`). Read the live values
  through the existing `fov` / `arm_length` getters
  (`scripts/chase_camera.gd:52-59`).

What this does **not** claim: it does not make the bird bigger while grounded
or slow, does not touch follow/yaw/pitch/shake (T-002/T-013), and does **not**
claim machine-verified readability — the px-size benefit stays a Gate 3
screenshot pair.

## Why

At cruise the pigeon shrinks to ~34 px tall (~2.3% of frame width): frame
`.captures/session_flc-s1-a/f00033540.png` at 21 m/s vs `f00033036.png`
grounded (~70 px). (Reviewer's eyeball on the same frames said ~45 vs ~90 px —
same direction, roughly half size; the exact pixel counts are an
approximation.) Cause: flaps pace cruise to 21–25 m/s while `fov_speed` is 20,
so the kick sits fully on for the entire flight
(`scripts/chase_camera.gd:116-117`), and the 6.5 m arm
(`scripts/chase_camera.gd:21`) keeps the camera far exactly when landing
judgement matters.

## Acceptance criteria

- [ ] The FOV kick survives but stops pinning at cruise: at 26 m/s the FOV is
      ≤ 80.0 and ≥ 74.0 (Gate 1b: `camera_fov_kick` tightened in the same
      commit — fails on today's tree, passes after)
- [ ] The arm pulls in with speed: the airborne `arm_length` reads measurably
      below 6.5 at cruise (Gate 1b: assert it in the same `camera_fov_kick`
      high-speed leg via the existing getter)
- [ ] Grounded tuck and yaw follow are untouched (Gate 1b:
      `camera_tucks_in_grounded`, `camera_follows_yaw` stay green —
      SpringArm3D still owns clipping)
- [ ] [screenshot] Gate 3 side-by-side cruise frames: the bird keeps a
      readable silhouette for landing judgement vs the old pinned-kick frame

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script
res://scripts/chase_camera.gd`) + Gate 1b full suite green — baseline on
today's tree measured exit 0, 73/73 PASS (same count after: the change
tightens `camera_fov_kick` in place rather than adding a scenario);
`camera_fov_kick` (new bounds + arm read), `camera_follows_yaw`,
`camera_tucks_in_grounded` explicitly re-run; `VERIFICATION.md`'s Gate 1b
`camera_fov_kick` row reworded to the new bounds — + Gate 2 (autoplay) +
Gate 3.

**Pending human playtest (Gate 3):** a cruise frame pair (old vs new) — does
the bird read at 20+ m/s, does ground rush still sell the speed, and does the
slightly shorter arm feel cramped anywhere low.

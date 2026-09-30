# T-044 — Trim the pinned FOV kick and pull the arm in at speed (adopt T-024)

- **Milestone:** Sweep 2 · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-002 (landed — the chase camera it retunes), T-015 (landed — the envelope
  that put flapped cruise at the kick's saturation speed). Adopts
  [T-024](T-024-cruise-readability.md) — mark that ticket done/superseded when this lands.
- **Refs:** [T-024](T-024-cruise-readability.md) · sweep-2 planning sessions flcs2-a/b/c
  (trace stats verified at ticket-writing time; see the evidence caveat — no frame PNGs
  survive from any of these sessions)

## What

Cap the speed kick lower and pull the arm in with speed, so the bird keeps a readable
silhouette at cruise. `scripts/chase_camera.gd` exports + the framing block;
`tests/sim_test.gd` tightened **in the same commit**. No `.tscn` edits (verified below).

- **FOV:** `fov_max` 86.0 → **79.0** (`scripts/chase_camera.gd:27`). The kick target is
  `lerpf(fov_air, fov_max, clampf(forward_speed / fov_speed, 0.0, 1.0))` with `fov_speed`
  20 (`scripts/chase_camera.gd:116-118`, `:29`) — pinned at max whenever fwd ≥ 20.
- **Arm:** new Framing export `arm_length_air_fast: float = 5.8`; the airborne spring
  target becomes
  `lerpf(arm_length_air, arm_length_air_fast, clampf(forward_speed / fov_speed, 0.0, 1.0))`
  (`scripts/chase_camera.gd:112-114`) — the arm pulls in ~0.7 m at/above 20 m/s, exactly
  when roof/landing judgement happens at speed. The grounded branch and the SpringArm3D's
  ownership of clipping are untouched.
- **No `.tscn` edits needed (verified):** the ChaseCamera node in `player.tscn` sets no
  script exports; `spring_length = 6.5` (`scenes/player.tscn:29`) and `fov = 72.0`
  (`scenes/player.tscn:34`) are starting values the rig overwrites every physics frame —
  script-default changes take effect everywhere.
- **Margin note (must, same commit):** `camera_fov_kick` asserts a relative
  `fov > fov_cruise + 4.0` (`tests/sim_test.gd:398`). At `fov_max` 79 the 26 m/s leg
  computes to only ~4.2 of margin (target 79 damps to ≈ 78.9 after 1 s at `fov_rate` 4;
  the 8 m/s leg sits ≈ 74.8) — right at the line, so the relative assert goes blind.
  Replace it with **absolute bounds** on the 26 m/s leg:
  `cam.fov <= 80.0 and cam.fov >= 74.0` (fails today — 86 damps to ≈ 85.7) and
  `cam.arm_length < 6.2` (fails today — damps toward `arm_length_air` 6.5), read through
  the existing getters (`scripts/chase_camera.gd:52-59`).

What this does **not** claim: a bigger bird grounded or slow (grounded tuck untouched); any
follow/yaw/pitch/shake change; machine-verified readability — the on-screen size benefit
stays a Gate 3 screenshot pair, and see the caveat: it must be captured fresh for this
change.

## Why

At cruise the kick sits fully on and the 6.5 m arm keeps the bird small exactly when you
judge roof heights and landing lines. The mechanism is code-verified: `fov_speed` 20 with
flapped cruise ~25 m/s (T-015's landed pump measurement) and dives 28+ means the
saturation branch (`scripts/chase_camera.gd:116-117`) is the normal state of every fast
leg, not an edge case; the turn/bank follow itself reads fine — framing, not follow, is
the issue.

**Evidence caveat (honest):** the pixel measurements behind this ticket are gone —
T-024's frames (`session_flc-s1-a`, ~34 px bird at 21 m/s vs ~70 grounded, reviewer-eyeballed
at ~45 vs ~90) no longer exist in either repo, and the sweep-2 flcs2 sessions kept no frame
PNGs. The traces do bound the exposure: fwd ≥ 20 on only 4.7 % (flcs2-a) / 5.2 % (flcs2-b)
of Main rows, medians 14.46 / 7.39 m/s — so "cruised at 20–28 the whole time" would
overstate it; the pin engages on every fast leg and dive recovery, which is where landing
judgement matters most. The Gate 3 before/after pair is therefore the load-bearing
evidence and must be captured on this change (before-frame from the untouched tree,
after-frame from the landed one, same state).

## Acceptance criteria

- [ ] The FOV kick survives but stops pinning at cruise: at 26 m/s, 74.0 ≤ fov ≤ 80.0
      (Gate 1b: `camera_fov_kick` tightened in the same commit — the absolute bounds fail
      on today's tree, pass after)
- [ ] The arm pulls in with speed: the airborne `arm_length` reads < 6.2 on the same
      26 m/s leg (Gate 1b: same scenario, via the existing getter)
- [ ] Grounded tuck and yaw follow are untouched (Gate 1b: `camera_tucks_in_grounded`,
      `camera_follows_yaw` stay green — SpringArm3D still owns clipping)
- [ ] [screenshot] Gate 3 side-by-side cruise frames captured for this change (untouched
      tree vs landed, same state): the bird keeps a readable silhouette for landing
      judgement at 20+ m/s, ground rush still sells the speed, and the shorter arm never
      feels cramped low

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/chase_camera.gd`)
+ Gate 1b full suite green — record a fresh baseline on the untouched tree first (same
scenario count: the change tightens `camera_fov_kick` in place rather than adding one);
`camera_fov_kick` (new bounds + arm read), `camera_follows_yaw`, `camera_tucks_in_grounded`
explicitly re-run; reword `VERIFICATION.md`'s Gate 1b `camera_fov_kick` row to the new
bounds in the same change-set + Gate 2 (autoplay) + Gate 3.

**Pending human playtest (Gate 3):** the cruise frame pair — does the bird read at 20+
m/s; does the kick still sell speed at 79; is the 5.8 m arm ever cramped near the ground.

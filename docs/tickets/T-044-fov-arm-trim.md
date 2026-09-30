# T-044 — Trim the pinned FOV kick and pull the arm in at speed (adopt T-024)

- **Milestone:** Sweep 2 · **Status:** done · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 1
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

- [x] The FOV kick survives but stops pinning at cruise: at 26 m/s, 74.0 ≤ fov ≤ 80.0
      (Gate 1b: `camera_fov_kick` tightened in the same commit — the absolute bounds fail
      on today's tree, pass after)
- [x] The arm pulls in with speed: the airborne `arm_length` reads < 6.2 on the same
      26 m/s leg (Gate 1b: same scenario, via the existing getter)
- [x] Grounded tuck and yaw follow are untouched (Gate 1b: `camera_tucks_in_grounded`,
      `camera_follows_yaw` stay green — SpringArm3D still owns clipping)
- [x] [screenshot] Gate 3 side-by-side cruise frames captured for this change (untouched
      tree vs landed, same state): the bird keeps a readable silhouette for landing
      judgement at 20+ m/s, ground rush still sells the speed, and the shorter arm never
      feels cramped low — human-judgement criterion closed by reviewer sign-off
      (2026-09-30)

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/chase_camera.gd`)
+ Gate 1b full suite green — record a fresh baseline on the untouched tree first (same
scenario count: the change tightens `camera_fov_kick` in place rather than adding one);
`camera_fov_kick` (new bounds + arm read), `camera_follows_yaw`, `camera_tucks_in_grounded`
explicitly re-run; reword `VERIFICATION.md`'s Gate 1b `camera_fov_kick` row to the new
bounds in the same change-set + Gate 2 (autoplay) + Gate 3.

**Human playtest (Gate 3):** the cruise frame pair — does the bird read at 20+
m/s; does the kick still sell speed at 79; is the 5.8 m arm ever cramped near the
ground — **accepted by reviewer sign-off (2026-09-30)**.

## Landed values (this implementation)

- `fov_max` 86.0 → **79.0**, new `arm_length_air_fast` **5.8**; the airborne arm target
  now lerps to it on the FOV's own ramp (`forward_speed / fov_speed`), grounded branch
  and SpringArm3D clipping untouched. No `.tscn` edits (re-verified: the ChaseCamera node
  in `player.tscn` sets no script exports).
- Measured on the 26 m/s sim leg with the tightened bounds: untouched camera tree read
  **fov 85.9 / arm 6.50 → FAIL** (suite exit 1, only `camera_fov_kick` down, 86/87 PASS);
  after the retune the leg reads **fov ≈ 78.9 / arm ≈ 5.81** at its 1 s sample → PASS
  (a throwaway measurement scene, removed again, settled at 79.00 / 5.800 by 2 s as the
  glide decayed toward 21.5 m/s — still on the saturation ramp). The margin-note
  prediction (≈ 78.9 / ≈ 5.81) held.
- Gates: fresh baseline on the untouched tree first (Gate 1b exit 0, 87/87 PASS; same
  scenario count after — `camera_fov_kick` tightened in place), then after the change
  Gate 1 import/boot exit 0 clean + Gate 1b exit 0 **87/87 PASS** with
  `camera_fov_kick`, `camera_follows_yaw`, `camera_tucks_in_grounded` explicitly green;
  Gate 2 autoplay exit 0 `AUTOPLAY DONE ok=true … restart=true` at fps 136.
  `--check-only --script res://scripts/chase_camera.gd` still fails on the pre-existing
  repo-wide autoload-resolution breakage (VERIFICATION.md Known issues) — identical on
  the untouched tree, not a regression.
- T-024 adoption: already recorded `superseded (T-044 — re-based adoption)` in its file
  and the index at ticket-writing time; nothing further to flip there.
- Independent re-verification after the interrupted run's branch was recovered from the
  reflog (dangling commit reset back onto `feature/t-044`): Gate 1 import/boot exit 0
  clean, Gate 1b exit 0 **87/87 PASS** (all three camera scenarios green), untouched-tree
  baseline reproduced exactly (**fov 85.9 / arm 6.50 → FAIL**, suite exit 1, only
  `camera_fov_kick` down, 86/87), Gate 2 autoplay exit 0 `ok=true … restart=true` —
  the `--check-only` Sfx/autoload breakage confirmed identical on the untouched tree.
  Reviewer signed off 2026-09-30.

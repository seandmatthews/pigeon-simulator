# T-061 — Make a stall fall: grade the velocity-align cut by stall depth

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (complements T-041: its brake-sink band ends at the stall, which must fall, not waft)
- **Refs:** `scripts/player.gd` Handling / Lift & stall groups; sweep-1 flight-control lane suite logs in
  the flight-control worktree `.captures/`: `sim_baseline_flcs1.txt` (0 failures) and
  `sim_experiment{,2,3}_flcs1.txt` (exp3 = 76/77, sole failure `hit_shake_and_score_pulse`)

## What

One graded change in the airborne velocity-align of `_apply_flight_forces`
(`scripts/player.gd:370-373`). Today the magnitude-preserving slerp that bends
velocity toward the nose runs at the full `velocity_align_rate` (3.5,
`scripts/player.gd:49`) whenever |v| > 0.05 — including while `stalled`, when
the nose can sit 90–180° away from straight down and the slerp keeps bending
the tiny fall velocity back toward that nose. That redirect IS the wing
bending the flow; a stalled wing shouldn't steer the fall.

Compute a stall depth from forward speed and scale the align rate with it, in
place, feeding the existing `clampf(velocity_align_rate * delta, 0, 1)`
argument at `scripts/player.gd:372`:

```gdscript
var stall_depth := clampf((stall_speed - forward_speed) / stall_speed, 0.0, 1.0)
var align_rate := velocity_align_rate * lerpf(1.0, stall_align_fraction, stall_depth)
```

New export in the Handling group: `stall_align_fraction: float = 0.15` — the
align-rate fraction left at full stall depth (0.15 is the lane-tested value;
record the final number in this ticket). Depth is 0 at `stall_speed` (full
authority) and 1 at zero — or negative — forward speed (the clamp catches
backward drift). Graded, not binary: transient forward-speed dips on pull-up
crests keep near-full authority because depth scales continuously; the lane's
A/B kept every flight scenario green with exactly this shape. ~4 lines in one
function; `velocity_align_rate`'s default and everything outside the
stall-depth band are unchanged.

What this does **not** claim: stall entry (`stall_speed` 5.0), the stall
gravity multiplier (`stall_gravity_scale` 1.7, `scripts/player.gd:353-355`)
and the automatic nose drop (`stall_nose_drop_rate` 1.1) are untouched — the
fall's energy still comes from the existing 1.7× gravity; the cut only stops
the aligner from steering the fall toward a nose it shouldn't follow. The
flap's recovery bite is untouched (the T-015 taper keeps the full 45° shove at
low speed). No stall HUD/pose signaling. Note one honest consequence: during
early recovery the depth is still high, so the nose-chase that converts the
flap impulse into forward speed is weakened there too — `stall_recovers`
measures exactly that and is a required green (it held in the lane's A/B).

## Why

Stalling out of a climb doesn't read as a stall. Lane session trace (flcs1a,
frames f30802–f30922 — the session frame traces are not committed to either
tree; the scenario below re-measures everything on-tree): ~90 frames hovering
at ±1 m/s with `stalled == true` while `stall_gravity_scale` 1.7 already
applied, y pinned at 36.5, fwd ≈ −2 — a helicopter hang — and the wallow into
the dive only started once the nose crossed the horizon. Holding W into a
climb is punished by a broken-looking waft instead of a legible
drop-and-recover. The mechanism is code-certain: while stalled, gravity pours
in (`scripts/player.gd:353-354`) but the align slerp
(`scripts/player.gd:370-373`) preserves |v| and bends the velocity toward the
nose every frame, canceling the fall until the nose drops past it. The
machine check is blind to it: `stall_drops` launches its stall leg from |v| = 1
with a level attitude (`tests/sim_test.gd:350`), where nose and fall agree, so
the hover never appears there. Lane A/B record for this change's shape:
`.captures/sim_experiment3_flcs1.txt` — 76/77, the sole failure the
flight-agnostic canary `hit_shake_and_score_pulse` (same signature as every
flight perturbation on the lane; the untouched-tree baseline log is 0
failures).

## Acceptance criteria

- [ ] New Gate 1b scenario `stall_falls_develops` in `tests/sim_test.gd`:
      balloon a settled climb — `_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -15))`
      then `_hold("pitch_up", 45)` (helpers at `tests/sim_test.gd:172-183`) —
      then wait for `stalled == true` with a frame budget so a broken model
      can't hang the harness (the `_await_grounded` pattern,
      `tests/sim_test.gd:207-211`), and once stalled assert
      `velocity.y <= -6.0` within 45 further frames. Demonstrated RED on the
      pre-fix tree and GREEN with the change, both inside this change-set;
      the measured frames-to-fall of both runs recorded in this ticket. If
      the scenario does not reproduce RED on the pre-fix tree, stop and
      re-derive the trigger shape before shipping — the ticket's premise is
      that today's tree hovers.
- [ ] `pullup_gains_height`, `dive_gains_speed`, `stall_drops` and
      `stall_recovers` pass with their before/after margins recorded in this
      ticket — all four cross partial stall depth by design (pull-up crests,
      deep-stall legs, recovery), so their green is evidence, not assumption.
- [ ] `hit_shake_and_score_pulse` is green again and the full Gate 1b suite
      exits 0. It flipped in every flight-model experiment run recorded on
      the lane (`.captures/sim_experiment{,2,3}_flcs1.txt`, always
      `combo_shown=false` at `tests/sim_test.gd:2652` while pulse/shake/settle
      passed; baseline 0 failures): diagnose the coupling in this change-set
      and either fix the real cause or harden the scenario's hit sequence
      (`Game.add_tourist_hit` timing, `tests/sim_test.gd:2646-2652`) without
      weakening what it proves. Do not ship this ticket with the suite red.
- [ ] Final `stall_align_fraction` recorded in this ticket together with the
      A/B fall numbers (lane-tested value 0.15; on the lane's fixed-tree
      trace the fall developed in ~0.67 s to vy −10.4 with pitch capped at
      76.8°).
- [ ] (Gate 3, human) Stalling out of a climb reads as a drop-and-recover —
      the nose heaves over and the bird falls within about a second instead
      of hovering, and the recovery flap still bites.

## Verification

Gate 1 (`--import`, `--quit-after 120`, `--check-only --script
res://scripts/player.gd` — all exit 0, no ERROR lines) + Gate 1b (new
`stall_falls_develops` shown red-before/green-after; full suite exit 0 with
`pullup_gains_height`, `dive_gains_speed`, `stall_drops`, `stall_recovers`,
`trim_glide_lands_clean`, `hard_landing_skids` explicitly re-run;
`hit_shake_and_score_pulse` restored to green) + Gate 2 (autoplay
`ok=true restart=true`) + Gate 3 (the new human line above). Add the
`stall_falls_develops` row to the VERIFICATION.md Gate 1b table and the Gate 3
checklist line in the same change-set.

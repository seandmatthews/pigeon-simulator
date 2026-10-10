# T-110 — Reticle live refresh: 10 Hz → 30 Hz

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-105 (the live/frozen reticle, landed)
- **Refs:** owner request (2026-10-10): the live reticle's 10 Hz refresh reads as discrete hops in
  real flight — try 24 or 30 Hz; owner hands-on verdict for 30 Hz: "much better, let's keep that"

## Why

The live mode re-marches its hypothetical release on the FIXED 60 Hz physics clock, quantized to
whole ticks (`_refresh_ticks = physics_ticks_per_second / live_refresh_hz`,
`scripts/poop_reticle.gd:76`). At the T-105 tuning (10 Hz = every 6th tick) the pin visibly hops
during cruise and shallow dives — six positions a second reads as steps, not a sight tracking
intent. 24 Hz is not a real option on this clock (60/24 = 2.5 rounds to 3 ticks = an effective
20 Hz); 30 Hz divides clean (every 2nd tick) and is the smoother of the two owner-proposed values.
The frozen pin is untouched — it was already exact (one-shot march at the 0.05 s step).

## What

- `scripts/poop_reticle.gd` — `live_refresh_hz` 10.0 → 30.0; the docstring and export comments
  updated to the new cadence and the whole-tick constraint. Nothing else: the march itself, the
  step sizes and the frozen mode are all unchanged.
- `tests/sim_test.gd` — new `reticle_live_refresh_30hz` scenario: a bare-rig value lock asserting
  the export is 30.0 and resolves to exactly 2 physics ticks, so a silent revert FAILs Gate 1b.
- `VERIFICATION.md` — the scenario row + the Gate 3 hands-on line.

## Acceptance criteria

- [x] (machine, Gate 1b) `reticle_live_refresh_30hz` — export 30.0, resolved to 2 ticks at the
  fixed 60 Hz; a revert to 10.0 (6 ticks) fails both arms.
- [x] (human, Gate 3) Hands-on flight, 2026-10-10: the live ring reads continuously attached at
  cruise and leads smoothly through a shallow dive; the frozen pin behaves exactly as at 10 Hz.
  Owner: "much better, let's keep that".

## Tuned values

- `live_refresh_hz` **30.0** (was T-105's 10.0) — every 2nd physics tick of the fixed 60 Hz step.
- Cost note: worst-case live march volume rises ~3× to ~3,600 rays/s (12 s lifetime horizon ÷
  0.1 s live step × 30 Hz, only while airborne AND the release point or velocity changed) — still
  trivial against the T-018 perf budget.

# T-184 — Ames R2 · CUTOVER: the town lives, the suite re-pins

- **Status:** proposed · **Ring:** R2 The Life ·
  **Value (1-5):** 5 · **Risk (1-5):** 5
- **Depends on:** T-178..T-183 (all R2 tickets green)
- **Refs:** `docs/AMES-MASTERPLAN.md` §3, §10 · the T-177 cutover
  pattern (this is its R2 repeat)

## What

R2's cutover — same discipline as T-177, new layer:

1. **Flip defaults**: traffic/pedestrians/parking/economy live on Ames
   geometry for every boot (they may already be default-on per-ticket;
   anything flag-gated flips here — the ring decides per ticket which
   pieces can land default, the cutover owns the rest).
2. **The re-pin**: all R2-dependent suite expectations re-derived
   (traffic density/route pins, calm scenario, pedestrian zones,
   parking census, economy pins) — recorded in-ticket as R2's pinned
   ledger; un-pin-able items block and get reported.
3. **Gate 3, the ring's bar** (two-part owner pass): (a) watch calm
   traffic hold a REAL Lincoln Way intersection; (b) walk Welch at eye
   level among the crowd and sit-target benches. Both sign-offs close
   the ring.

## Why

Concentrating default-changing risk into one revertable reviewed unit
per ring is the campaign's core discipline; R2's lives here.

## Acceptance criteria

- [ ] Default boot: living Ames (traffic + people + parking + economy)
- [ ] Full Gate 1b: 0 failures on the R2 pin ledger (counts recorded,
      deltas justified)
- [ ] Gate 2 autoplay green (world-scoped Ames autoplay if needed)
- [ ] VERIFICATION.md + AGENTS.md updated in the same change-set
- [ ] **Gate 3 (human)**: owner's two-part pass — calm at a real
      intersection; Welch eye-level crowd — sign-offs recorded

## Verification (proposed)

Full gates on the new default.

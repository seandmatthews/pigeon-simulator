# T-177 — Ames R1 · CUTOVER: Ames becomes the world, the suite re-pins

- **Status:** proposed · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 5
- **Depends on:** T-174, T-175, T-176 (all R1 tickets landed and green)
- **Refs:** `docs/AMES-MASTERPLAN.md` §3 (cutover pattern), §10 ·
  `sim_test.gd` (the ~140-check suite whose pins this ticket re-derives) ·
  `VERIFICATION.md` (every world-dependent gate) · `AGENTS.md` (the
  verification contract this re-pins)

## What

The one ticket per ring allowed to change the default game:

1. **Flip the default**: `world=ames`. The menu→flight loop now boots
   Ames for every player, every gate.
2. **Retire the Windrow generate path**: delete `city.gd`'s live
   generate (master plan §11 fork 2 default = delete; owner veto window
   closes at this ticket's review). The Windrow visuals survive only in
   git history. `district_of`/anchor logic that gameplay still consumes
   is re-pointed to the data pack — NOT deleted until nothing reads it.
3. **The re-pin**: every world-dependent suite expectation re-derived
   against Ames — counts, positions, palettes, fingerprints, the plaza/
   park/anchor scenarios, spawn-corridor math — recorded in this
   ticket's body as the new pinned ledger. This is budgeted, deliberate
   work (the known tax); anything that cannot re-pin honestly blocks
   and gets reported, never fudged.
4. **Gate 3, the ring's bar**: owner flies Lincoln Way State Ave →
   Duff at 60 m and recognizes Ames from the air; eats bread; lands on
   the campanile cap. His sign-off closes the ring.

## Why

Small merges keep gates green; a world swap cannot. Cutover tickets
concentrate ALL default-changing risk into one reviewed, revertable
unit per ring — the auto-revert machinery already exists (the pipeline
merges with gate re-runs).

## Acceptance criteria

- [ ] Default boot = Ames (menu → flight over the skeleton, survival
      loop live)
- [ ] Full Gate 1b: 0 failures with the NEW pins (count recorded vs the
      old ~140 — deltas justified one-by-one in-ticket)
- [ ] Gate 2 autoplay green on Ames
- [ ] Windrow generate path removed or flag-locked per the fork decision
      (recorded); zero dead-code references left in scripts
- [ ] VERIFICATION.md re-pinned rows + AGENTS.md world notes updated in
      the same change-set
- [ ] **Gate 3 (human)**: owner Lincoln Way flyover + bread + campanile
      landing — his sign-off recorded, the ring's exit demo

## Verification (proposed)

Full gates, all four, on the new default. This ticket is expected to be
the ring's long pole; its review rounds are where feel regressions get
caught (any feel change found here is a defect, not a tuning pass —
feel constants were frozen in T-176).

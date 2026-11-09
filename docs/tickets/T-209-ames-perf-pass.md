# T-209 — Ames R5 · performance pass: budgets audited, the web fork decided

- **Status:** proposed · **Category:** code-optimization · **Ring**: R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-206, T-207, T-208 (the last visual weight)
- **Refs:** master plan §2 (lighting policy), §12 (melt-factors) ·
  T-173's frame budget (the gate this audits) · T-018 (the original
  perf-budget pass — this is its Ames successor) · T-129 (the web
  boot history — context for the fork)

## What

The audit before the ring closes:

1. **Frame audit**: worst-case sweeps — low hover over Campustown at
      dusk, cruise over the stadium complex on game-day dressing,
      downtown at ground level — recorded against T-173's budget;
      regressions fixed here (LOD band tuning, variant weights), not
      deferred.
2. **Memory audit**: chunk payload + hero scene cost vs the budget;
      occluder effectiveness spot-check.
3. **Load audit**: boot→menu→flight timeline on Ames (the T-129
      pattern — nothing synchronous, but measure it anyway).
4. **The web fork** (owner decision, prepared here with measured
      numbers): re-diet and redeploy the web build (what would have to
      go) vs desktop-only for the campaign (current default). The
      ticket records the measurements; the owner picks; `deploy:false`
      stays until the fork resolves AND the box is alive.

## Why

Five rings of accumulation need one honest measurement moment, and the
web question deserves numbers, not vibes.

## Acceptance criteria

- [ ] Audit ledger recorded in-ticket: frame ms per sweep, memory,
      boot timeline — each vs its budget
- [ ] Any budget miss fixed in-ticket (LOD/band tuning) or escalated
      as a follow-up with numbers
- [ ] The web-fork one-pager with measurements presented to the owner;
      his pick recorded
- [ ] *(Gate 1b)* full suite green (perf gates re-pinned if tuning
      changed values)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b (re-pinned as needed) · Gate 2 · Gate 3: the owner
plays a session on the audited build and feels no regression — his
bar, since feel outranks metrics.

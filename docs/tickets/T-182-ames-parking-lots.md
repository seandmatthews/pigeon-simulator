# T-182 — Ames R2 · parking: curbs and lots from the census

- **Status:** proposed · **Category:** worldbuilding · **Ring:** R2 The Life ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-178 (graph curb geometry)
- **Refs:** `census/BUILD-CENSUS.md` §3 (480 lots / 73.6 ha; the
  tailgate stock) · T-147 (anti-farm rebalance — the line this must
  respect) · T-140 (the parked-car splat exploit history) · T-168
  (`spawn_car` stages parked)

## What

Cars that sit still, at the places Ames parks them:

1. **Curbside parking** along graph edges where the census shows
   curb spots (downtown angled/parallel, Campustown messy parallel) —
   the existing parked-car system re-targeted to real curbs.
2. **Lot parking**: the core's big lots near the stadium/Campustown
   filled at dressing density (rows of parked cars — the tailgate
   stock reads full-ish year-round, events are R5/T-208's business).
3. **Economy coupling**: parked cars stay splat/favor targets under
   the T-147 rules exactly as tuned — the anti-farm math does not
   re-derive here; the B-6 parked-car fountain question stays parked
   (IDEAS.md) unless the owner re-opens it.
4. **`car_blinker` reach**: nearest-car targeting includes parked cars
   (the T-168 contract's "staged or fleet" extends to parked).

## Why

Parked cars are the game's bread-and-butter splat stock; on Ames
geometry they must exist where parking exists or both the look and the
economy thin out.

## Acceptance criteria

- [ ] Curbside + lot populations pinned per district (counts from
      census-derived caps, recorded)
- [ ] *(Gate 1b)* `ames_parking_census`: lot counts match data; parked
      positions on curb geometry within tolerance; total splat-stock
      count within the T-147 balance band
- [ ] T-147 exploit probes re-run on Ames (the reviewer's T-140 script
      pattern) — no new fountain opens
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3 folded into T-184.

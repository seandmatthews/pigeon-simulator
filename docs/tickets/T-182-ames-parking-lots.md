# T-182 — Ames R2 · parking: curbs and lots from the census

- **Status:** doing · **Category:** worldbuilding · **Ring:** R2 The Life ·
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

## Landed record (the pinned populations, 2026-11-13)

**Data layer** (`tools/ames_distill.py`, the census rule verbatim — hard-fail
guards): the pack gains the `parking` layer — 480 areas / 73.6 ha
(amenity=parking, bbox center in core, areas by shoelace, plus the one
in-core tagged node lot), **19 tailgate-zone lots / 8.9 ha** (lat < 42.0225,
lon −93.6445…−93.6260), **31 curb bays** (`parking=street_side` 27 +
`parking=lane` 4). Surfaced through `AmesDataPack.parking()`.

**Curbside** — the census curb marking (`AmesParking`, pure data over pack +
graph): **94 curb runs** — downtown **64** + Campustown **24** (every run of
the two census-§2 commercial districts; the ticket's "downtown angled/
parallel, Campustown messy parallel") + **6 bay-adjacency runs** (Morrill
Road ×2, Pammel Drive ×2, WOI Road, Sheldon Avenue Extension — the mapped
bay stock at the 8.0 m probe). The CarSpawner's parked placement walks
curb-marked runs FIRST (populate + churn replacement; unmarked runs stay
eligible so the fleet never starves; the `spawn_car` dev verb keeps its
nearest-free-curb contract).

**Lots** — the dressing rule (`AmesParking` consts): dressed set = tailgate
zone ∪ the T-180 Campustown window ∪ the census §3 big-lot cut (≥ 1.5 ha) →
**88 dressed lots**; stall grid 2.6 m pitch × 12.5 m row module (5.5 stall +
7.0 aisle), clipped to each polygon, 1-in-7 gap skip, every survivor
ground/street/rail/lake-guarded → **5,873 dressing cars kept of 6,915
in-polygon stalls (fill 0.85), 2,437 in the tailgate zone**; per baker
district {residential 3101, campus 2224, campustown 494, lincolnway 54}.
Rendered as two palette-cycled box MultiMeshes under `Parking/` (no
colliders — scenery; events are R5/T-208's business).

**Economy coupling** — the splat/favor fleet stays byte-identical: **14
moving + 12 parked** (`target_moving + target_parked`), the parked
placements take the dressing's GAP slots first when the pigeon stands
within 90 m of a dressed lot (real splat/favor targets where the parking
visibly is), else the census-ordered curb spots. The anti-farm math did not
re-derive; the B-6 question stays parked (IDEAS.md). The T-147 exploit
probes re-ran green on the new stock (the `splat_favor_once_per_target` /
`spent_car_despawn_replacement` scenarios in the same Gate 1b run + the
probe legs inside `ames_parking_census`).

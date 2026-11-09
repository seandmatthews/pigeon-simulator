# T-200 — Ames R4 · street name blades: wayfinding by reading

- **Status:** proposed · **Category:** visual-design · **Ring:** R4 The Names ·
  **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-197, T-180 (the intersection set)
- **Refs:** `osm/SUMMARY.md` (spine streets; Lincoln Way becomes East
  Lincoln Way exactly at Duff — the seam is a nice detail) · MUTCD
  green-blade convention (the T-134 speed-sign geometry family) ·
  `images/lincolnway/01` (mast arms at the Welch intersection)

## What

Real street names on green blades at the intersections that matter:

- **The spine set** (pinned): Lincoln Way (+ its East rename at Duff),
  Welch, Hayward, Sheldon, Stanton, Main, Duff, Grand, University,
  Mortensen, 16th, Stange, Clark, Burnett, Douglas — blades at
  spine×spine and spine×collector corners from T-180's set.
- MUTCD-correct form: green blade, white text, the T-134 family's
  sign geometry at blade size; mast-arm or post-mount per corner type.
- Correct directional names where OSM has them (East Lincoln Way,
  South Duff) — the data's names, not invented ones.

## Why

An alum navigating by street names is the second recognition channel
after venue signs — and it's nearly free once T-197 exists.

## Acceptance criteria

- [ ] Blades at the pinned corner set; names exact-match the data
      pack's street names (incl. the East Lincoln Way seam)
- [ ] *(Gate 1b)* `street_blades_pins`: corner list + text pins
- [ ] Screenshot: the Lincoln Way × Welch corner with blades (vs photo)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass; owner
eyeball in T-202.

# T-205 — Ames R5 · north: Ada Hayden and the north parks

- **Status:** proposed · **Ring:** R5 The Town ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-203
- **Refs:** `osm/SUMMARY.md` (+1.6 km north option) ·
  `landmarks/LANDMARKS.md` (Ada Hayden twin quarry lakes; trail
  length) · `images/nature/01-04` (4 refs) · T-198 (The Cafe's staged
  sign finally places — 2616 Northridge Pkwy is here)

## What

+~1.6 km north:

- **Ada Hayden Heritage Park**: the twin quarry lakes as water flats
  (the north-Ames big-water read — photos 01/02), gravel trail ring,
  the quarry-banked shore character.
- **Inis Grove + Moore Memorial parks** as green massing + trails.
- **North Ames residential fabric** (the census's north blocks).
- **The Cafe** un-staged: T-198's staged sign places at 2616
  Northridge Pkwy (the noted dependency closes).
- Data pack v4, re-bake, bbox pins.

## Why

The lake is north Ames's identity (and the game's best soaring water
read); The Cafe's placement closes the last open Tier-1 commitment.

## Acceptance criteria

- [ ] Twin lakes at data geometry; trail ring walkable-adjacent;
      parks + fabric per data
- [ ] The Cafe signed at its true position (T-198's staged sign
      placed; its pin moves from staged to live)
- [ ] *(Gate 1b)* `ames_extension_north`: lake geometry pins; bbox
      consts; The Cafe position pin moves
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass.

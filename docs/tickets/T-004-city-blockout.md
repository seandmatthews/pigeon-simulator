# T-004 — City blockout v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** L · **Status:** todo
- **Depends on:** — (can run in parallel with T-001)
- **Refs:** `docs/DESIGN.md` → The city

## What

First version of the procedural city (per the locked decision):

- Generator script builds a street grid: roads, sidewalks, building volumes with
  simple facades, landable flat roofs
- Props: benches, lamp posts, trash bins (café tables arrive with T-005)
- One seed constant for M1; a different seed must still guarantee a spawn plaza,
  sufficient bread-capable surfaces, and flyable street widths
- Static bodies on layer 1 (`world`); generation runs at scene load

## Why

The world is the toybox — flight and the whole scoring loop need somewhere to happen.

## Acceptance criteria

- [ ] Fly end-to-end across the city without falling through anything
- [ ] Roofs and sidewalks are landable and walkable (pairs with T-003)
- [ ] Generation is deterministic for a given seed and regenerates cleanly on restart
- [ ] 60 fps flying over the whole city on the dev machine
- [ ] Street widths and building heights stay within flyable/tunable bounds

## Verification

Gate 1 + Gate 2 + Gate 3, plus a flyover of every generated block and a restart
twice to confirm determinism.

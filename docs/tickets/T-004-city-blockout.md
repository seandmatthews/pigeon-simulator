# T-004 — City blockout v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** L · **Status:** done
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

- [x] Fly end-to-end across the city without falling through anything —
  machine-verified: `city_street_flyover` crosses the full 226 m street corridor
  without a collision, plus the autoplay run
- [x] Roofs and sidewalks are landable and walkable (pairs with T-003) —
  machine-verified: `city_roof_landable`, `city_roof_takeoff`,
  `city_sidewalk_walkable`; the autoplay ground visit lands on the pavement
- [x] Generation is deterministic for a given seed and regenerates cleanly on
  restart — machine-verified: `city_same_seed_deterministic` and
  `city_regenerate_restores_layout` (layout fingerprint identical across
  regenerations); every gate run boots the city fresh
- [x] 60 fps flying over the whole city on the dev machine — measured by the
  autoplay run (Gate 2 `DONE` line): **131 fps average** over 30 s on the dev
  machine (RTX 4080, 1280×720); visuals are ~10 MultiMeshes + ~650 static bodies
- [x] Street widths and building heights stay within flyable/tunable bounds —
  machine-verified: `city_new_seed_guarantees` asserts the `City.report()`
  invariants for a foreign seed too (street ≥ 8 m, roofs ≤ 20 m, plaza clear,
  ≥ 150 bread surfaces)

## Tuned values (final @exports, `scripts/city.gd`)

| Export | Value | Note |
| ------ | ----- | ---- |
| `seed_value` | 20260928 | Fixed M1 seed |
| `blocks_per_side` | 7 | 49 blocks, span 234 m |
| `block_size` / `road_width` | 22 / 10 | 10 m streets, building faces 7.5 m off the road centerline |
| `ground_extra` | 250 | Grass apron to the horizon |
| `sidewalk_width` | 2.5 | Raised ring inside each block edge |
| `block_slab_height` / `road_slab_height` | 0.12 / 0.05 | Curb steps ≤ 0.07 m — below r·(1−cos45°) ≈ 0.09 m so the pigeon's sphere rolls over them; taller curbs are walls (found by `city_sidewalk_walkable`) |
| `roof_slab_height` | 0.25 | Flat roof cap, landable |
| `floor_height`, floors | 3.0, 2–6 | Roofs 6–18.25 m; autoplay cruises at 23–30 m |
| `lot_gap` / `park_chance` | 1.4 / 0.12 | Alleys + open park blocks |
| `spawn_drop_height` | 0.6 | Spawn is on the road centerline by the plaza, facing up the street |
| `min_flyable_street` / `max_roof_height` | 8 / 20 | `report()` guarantee thresholds |
| `min_bread_surfaces` / `spawn_clear_radius` | 150 / 12 | Ditto |
| `bench_chance` / `bin_chance` | 0.75 / 0.6 | Lamps on every block corner |

Default-seed report (actual): 146 buildings, 2 parks, 141 benches, 196 lamps,
32 bins, 338 bread-capable surfaces, max roof 18.25 m, plaza clear.

## Verification

- Gate 1 (import + 120-frame boot): clean, exit 0, no errors.
- Gate 1b: 8 new scenario checks (see VERIFICATION.md) — all green alongside
  the 19 existing ones; nothing weakened.
- Gate 2: `AUTOPLAY DONE ok=true fps=131` — the city-aware pilot cruises above
  the skyline, dives over roofs, lands on the plaza, waddles and takes off.
- Gate 3 (human, still pending): city readability from the air, restart-twice
  determinism by eye, a full manual flyover for the fps criterion, curb
  step-over feel.

## Notes

- The pigeon spawns grounded on the road next to the spawn plaza — roads are
  the one corridor guaranteed building-free at every height, so the opening
  climb is always safe.
- T-005 can spawn bread on benches, sidewalks, plaza and roofs;
  `City.buildings` exposes every roof footprint for spawn rules.

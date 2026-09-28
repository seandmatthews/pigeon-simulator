# T-005 — Bread & hunger

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** done
- **Depends on:** T-003, T-004
- **Refs:** `docs/DESIGN.md` → Hunger

## What

The survival half of the core loop:

- Bread-crumb pickups (layer 5 `pickup`) spawn on sidewalks, benches and café tables
- Hunger drains over time — faster while flapping/boosting, slower while gliding —
  shown on a HUD bar
- Eating: land near crumbs → peck → restore a chunk of hunger (eating is ground-only;
  flying over crumbs does nothing)
- Hunger 0 emits a game-over signal (T-010 turns that into a screen)

## Why

Hunger is the clock. Without it there is no reason to land, and no tension between
greed and survival.

## Acceptance criteria

- [x] Hunger empties in ~3 minutes of lazy flying (tunable `@export`s)
- [x] Drain rate visibly differs between flapping and gliding
- [x] Eating works while grounded; flying over crumbs does nothing
- [x] Game-over signal fires exactly once, at zero
- [x] Crumbs respawn over time so the city never starves you unfairly

## Tuned values

- `Hunger` (`scripts/hunger.gd`): max 100 · glide drain **0.45/s** (full bar ≈
  3 min 42 s of pure glide) · **×2.0** while flap heat is up (0.7 s window after
  each flap) · **×0.6** while grounded. The autoplay pilot's flap-heavy mix
  measured ≈0.57/s → ≈2 min 55 s full-to-zero — squarely in the "~3 min" band.
- `BreadCrumb` (`scripts/bread_crumb.gd`): restore **30** (a third of the bar)
  · eat radius **1.1 m** · feeds only when a GROUNDED pigeon overlaps.
- `BreadSpawner` (`scripts/bread_spawner.gd`): **40** crumbs kept alive ·
  **5 s** respawn top-up · initial spread seeded from the city seed, re-seeded
  on every `City.regenerated`.
- City spots (`scripts/city.gd`): 4 sidewalk-corner spots per block + one per
  bench seat (533 spots at the default seed) — pure layout data, no RNG of its
  own, so the building RNG sequence is untouched (T-004 fingerprints unchanged).

## Verification

Gate 1 + Gate 2 + Gate 3. Machine-verified by four new Gate 1b scenarios
(`hunger_drain_flap_vs_glide`, `hunger_game_over_once`,
`crumb_eaten_grounded_only`, `crumbs_respawn` — 31/31 pass). The autoplay pilot
now aims its ground-visit touchdown at a plaza crumb, pecks it and reports
`hunger=`/`eaten=` on its DONE line (ok=true, eaten=1, no SCRIPT ERROR).

**Pending human playtest:** play until game over once and confirm the drain
timing feels fair and the starved moment reads well (the full game-over screen
arrives with T-010 — until then the HUD hint announces the starvation).

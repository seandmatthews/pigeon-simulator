# T-005 — Bread & hunger

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** todo
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

- [ ] Hunger empties in ~3 minutes of lazy flying (tunable `@export`s)
- [ ] Drain rate visibly differs between flapping and gliding
- [ ] Eating works while grounded; flying over crumbs does nothing
- [ ] Game-over signal fires exactly once, at zero
- [ ] Crumbs respawn over time so the city never starves you unfairly

## Verification

Gate 1 + Gate 2 + Gate 3. Play until game over once: confirm drain timing feels
fair and the signal fires at the right moment.

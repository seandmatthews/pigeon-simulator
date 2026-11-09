# T-176 — Ames R1 · survival rebase: bread, hunger, spawn on the real map

- **Status:** proposed · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-173 (world), T-175 (crumb hosts)
- **Refs:** `VENUES.md` (real café/bread spots: Stomping Grounds 300
  block Welch, downtown cafés) · `MODELING-SPECS.md` §1 game-native
  notes · `T-005` (bread & hunger), `T-032` (roof crumbs) ·
  `sim_test.gd` economy pins (favor ceiling 100, hunger drain — both
  UNCHANGED here)

## What

The survival loop moves to Ames geometry with zero feel changes:

1. **Spawn** over Central Campus near the campanile (owner-decided
   2026-11-09, master plan §11.1) — the postcard spawn: lake+campanile
   on one screen, Lincoln Way strip one dive south.
2. **Bread distribution from data**: ground rings at downtown Main,
   Campustown Welch, the four pinned parks, LaVerne shore; roof crumbs
   on authored buildings + large filler (the T-032 pattern over the
   512-name list); **crumb tables at real cafés** (the sidewalk-café
   system re-targeted to the venue list's café positions).
3. **Hunger**: drain rate and the starvation ceiling UNCHANGED — the
   scale change is served by distribution (bread must exist district-
   wide), never by touching the clock. The T-167 hunger_lock verb
   keeps working as-is.
4. **Favor**: ceiling 100 (T-115) and elder logic untouched here —
   elder bench placement is T-183.

## Why

R1's exit demo is a playable flight, not a diorama: the game must
remain the game — eat, fly, splat-able world — on day one of Ames.
Feel constants are frozen; only placement follows the data.

## Acceptance criteria

- [ ] Spawn over Central Campus; first bread reachable ≤ 60 m
- [ ] *(Gate 1b)* `ames_bread_reach`: nearest-bread ≤ 150 m from ANY
      point in the core (sampled grid); crumb total ≥ the Windrow
      baseline count; café crumb tables present at ≥ 3 real cafés
- [ ] *(Gate 1b)* hunger constants byte-identical to the Windrow pins
      (the drain quartet untouched — diff-proven in the scenario)
- [ ] `AMES_AUTOPLAY`-style env or world-scoped autoplay flies, eats,
      survives one loop on `ames` (Gate 2's pattern, world-scoped)
- [ ] *(Gate 1/2)* clean; `windrow` full suite still green

## Verification (proposed)

Gate 1 · Gate 1b + two new rows · Gate 2 (windrow) + world-scoped Ames
autoplay green · Gate 3 folded into T-177's owner flight.

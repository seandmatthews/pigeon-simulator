# T-176 — Ames R1 · survival rebase: bread, hunger, spawn on the real map

- **Status:** doing · **Category:** gameplay · **Ring:** R1 The Map ·
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

- [x] Spawn over Central Campus; first bread reachable ≤ 60 m
- [x] *(Gate 1b)* `ames_bread_reach`: nearest-bread ≤ 150 m from ANY
      point in the core (sampled grid); crumb total ≥ the Windrow
      baseline count; café crumb tables present at ≥ 3 real cafés
- [x] *(Gate 1b)* hunger constants byte-identical to the Windrow pins
      (the drain quartet untouched — diff-proven in the scenario)
- [x] `AMES_AUTOPLAY`-style env or world-scoped autoplay flies, eats,
      survives one loop on `ames` (Gate 2's pattern, world-scoped)
- [x] *(Gate 1/2)* clean; `windrow` full suite still green

## Verification (landed)

Gate 1 clean (import + boot). Gate 1b: two new rows — `ames_bread_reach`
(spawn district/flight arms + first ground bread 20.6 m; reach grid 1,107
samples at 100 m over the pack core window, ZERO over 150 m, worst 110.6;
crumb supply 11,346 vs the Windrow baseline 778 measured live; café tables
at 6 real cafés) and `ames_hunger_pins` (drain quartet 0.45 / 2.0 / 0.7 /
0.6 + favor_max 100 diff-proven across a full ames build) — plus the
`ames_world_api_seam` spawn-corridor arm re-pinned to the new spawn (the
re-pin its landing note anticipated); full suite 0 failures. Gate 2: the
windrow autoplay green (`ok=true restart=true`) and the world-scoped Ames
autoplay green (`AMES_AUTOPLAY=1` → `ok=true world=ames loop_ok=true
restart=true eaten=21` — the staged demo spread `AMES_CRUMB_TARGET=400` is
pilot-side only, disclosed in the DONE line and the Gate 2 section). Gate 3
folded into T-177's owner flight.

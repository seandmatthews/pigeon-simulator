# T-176 — Ames R1 · survival rebase: bread, hunger, spawn on the real map

- **Status:** done · **Category:** gameplay · **Ring:** R1 The Map ·
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
(spawn district/flight arms + first bread ≤ 60 m; reach grid 1,107
samples at 100 m over the pack core window, ZERO over 150 m, worst 110.6;
crumb supply 11,346 vs the Windrow baseline 778 measured live; café tables
at 6 real cafés) and `ames_hunger_pins` (drain quartet 0.45 / 2.0 / 0.7 /
0.6 + favor_max 100 diff-proven across a full ames build) — plus the
`ames_world_api_seam` spawn-corridor arm re-pinned to the new spawn (the
re-pin its landing note anticipated); full suite 0 failures. Gate 2: the
windrow autoplay green (`ok=true restart=true`) and the world-scoped Ames
autoplay green at the shipped target. Gate 3 folded into T-177's owner
flight.

**Round 1 (review fixes, 2026-11-09):**
- **Live crumb growth, bounded.** The un-capped spawner re-added the
  30-crumb TABLE shortfall to GROUND on every top-up on Ames (measured
  red-before: populate 40 → 70 → 100 → … exactly 40 + 30·n — the review's
  own 1,480-at-4-min trace reproduced). `BreadSpawner._fill_class` now caps
  every fill by the FLEET deficit (`_fleet_deficit`), so the live total
  converges to the budget and can never pass it on either world; the cap is
  a no-op wherever classes reach their quotas, so Windrow's seeded spread is
  byte-identical. New Gate 1b row `ames_bread_spawner` holds the bound at
  the shipped target (boot ≤ target, 8 top-ups and a timed window at 40,
  eat-3-and-refill lands back at exactly 40).
- **AC 1 true in play, not just in supply.** The ≤ 60 m bar had been
  measured against the nearest SPOT (20.6 m) while the nearest LIVE crumb
  sat ~295 m out at boot (the review's rv1/rv2). The world now files its 8
  nearest ground spots as `City.boot_bread_spots` — seeded FIRST by every
  populate (Windrow's list is empty and byte-green) — so real bread sits
  20.6 m from the spawn at boot and after every restart; `ames_bread_reach`
  now measures the LIVE spread (a real spawner seeding the world), with the
  spot measure demoted to context.
- **Autoplay at the shipped target.** The `AMES_CRUMB_TARGET=400` staging
  (which multiplied the growth bug and inflated `eaten=21`) is retired; the
  Ames autoplay runs the shipped 40 and its `eaten ≥ 1` gate is honest —
  the boot ring puts the first crumb 20.6 m out.

**Round-1 gate run (this fix-set):** Gate 1 import + boot exit 0; Gate 1b
full suite `SIM SUMMARY: 0 failure(s)` (191 passes — `ames_bread_reach`
"first LIVE bread 20.6 m (bar 60); live crumbs 40 (target 40)",
`ames_bread_spawner` "boot 40 (target 40), nearest 20.6 m; 8 top-ups → 40;
timed window → 40; ate 3 → 37; 3 top-ups → 40"); Gate 2 windrow
`ok=true restart=true eaten=1`; Gate 2 ames at target 40
`ok=true world=ames crumb_target=40 loop_ok=true restart=true eaten=7`.

## Tuned values (final, all pinned by Gate 1b where machine-checkable)

Placement constants (`scripts/ames_world.gd` unless noted) — the hunger
quartet and every favor/economy knob are deliberately NOT here (frozen,
`ames_hunger_pins`):

- **Spawn**: campanile POI + `SPAWN_CAMPANILE_OFFSET_X` 40 m east at
  ground + 0.6 drop → world-local (380.17, 0.6, −294.43), district
  "campus", massing-clear (landed nearest LIVE crumb 20.6 m).
- **Boot ring** (round 1): `BOOT_BREAD_COUNT` 8 — the GROUND spots nearest
  the spawn, filed as `City.boot_bread_spots`, seeded FIRST by every
  populate (empty on Windrow, byte-green).
- **Street rings**: named anchors Main/Welch `ANCHOR_RING_STEP` 30 m,
  `ANCHOR_RING_OFFSET` 4 m; other named streets `STREET_RING_STEP` 150 m;
  creeks `CREEK_RING_STEP` 100 m / `CREEK_RING_OFFSET` 3 m.
- **Parks**: the census §5 named-stock top four (`PINNED_PARKS`:
  Brookside, ISU Arboretum, Stuart Smith, Central Campus) at
  `PARK_GRID_STEP` 100 m, polygon-clipped; LaVerne shore
  `SHORE_OFFSET` 6 m.
- **Field lattice**: `FIELD_LATTICE_STEP` 200 m cells over the pack core
  window, one cell past each edge (worst sample-to-spot 110.6 m vs the
  150 m bar).
- **Roof crumbs**: authored `a` slots + filler ≥ `FILLER_ROOF_MIN_DIM`
  12 m; `SPOT_LIFT` 0.06; ground guard `GROUND_COVER_MAX` 0.5.
- **Café tables**: 6 real cafés (name tokens cafe/café/coffee, in-bounds
  ±`CAFE_BOUNDS_SLACK` 60 m), outset ladder
  `CAFE_VENUE_OUTSET_STEPS` 7/9/11/13/16/20 m.
- **Supply landed**: 11,346 spots (8,682 ground / 6 table / 2,658 roof)
  vs the Windrow baseline 778; steady fleet at the shipped spawner knobs
  (target 40, table_share 0.90, roof_share 0.025, respawn 5 s —
  untouched) is 6 tables + 34 ground, fleet-deficit-capped.

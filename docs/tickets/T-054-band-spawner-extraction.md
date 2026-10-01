# T-054 — Extract BandSpawner and close the unverified car-recycle contract

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** — (T-007 and T-008, whose spawners it refactors, are landed) · implements **T-034**
- **Refs:** sweep 2 planning lane · re-based during the 2026-09-30 backlog audit — **T-089 landed after this ticket was written and changed the car recycle path** (see What), so re-locate by symbol, not line number: older text has already drifted (T-034 cites the tourist recycle scenario at `sim_test.gd:1418-1451`; it is at `sim_test.gd:2170` today)

## What

TouristSpawner and CarSpawner each carry a verbatim copy of the band/recycle
machinery — the five helpers `_anchor_flat/_flat_dist/_blocks_in_band/_nearest_blocks/_center_dist`
and the `_physics_process` recycle-scan timer are byte-identical between the two
scripts (symbol-level compare, re-verified during the 2026-09-30 audit; the
sweep-2 sed-range check no longer aligns because the car side gained
T-089's `_on_car_splatted`/`_flat_dist_pos`/`_pick_recycle_block` since).

The recycle exports are duplicated equal too — `recycle_interval` 0.5,
`spawn_min_dist` 30, `spawn_max_dist` 70 (`tourist_spawner.gd:23-25`,
`car_spawner.gd:32-34`) — while `recycle_radius` differs: 80 for tourists
(`tourist_spawner.gd:22`) vs 100 for cars (`car_spawner.gd:31`, load-bearing
comment `:27-30`: it
must clear the worst legitimate loop distance — a car seeded at `spawn_max_dist`
rounds ring corners ~20 m past its block center — or traffic gets yanked mid-lap and
dropped on top of other cars).

New `scripts/band_spawner.gd` — `class_name BandSpawner extends Node3D` — owning:

- the city/player wiring: `city_path`/`player_path` exports, the `_ready`
  resolution, the needs-City-and-Player warning,
  `city.regenerated.connect(_populate)`;
- the shared recycle exports with the equal defaults, `recycle_radius` defaulting to
  the tourist's 80.0;
- `_rng`, `_scan_timer`, `_physics_process` (the scan timer, dispatching to a
  `_recycle_far()` stub the subclasses override);
- the five band helpers verbatim, plus a small `_pick_block(anchor) -> Vector3` for
  the plain `blocks[_rng.randi_range(0, blocks.size() - 1)]` draw that both
  `_populate`s (`tourist_spawner.gd:85`, `car_spawner.gd:97` and `:104`) and the
  tourist `_recycle_far` (`tourist_spawner.gd:108`) make. The CAR `_recycle_far`
  has made a different draw since T-089: `_pick_recycle_block`
  (`car_spawner.gd:131`), which filters to blocks under `ring_traffic_soft_cap`
  (`car_spawner.gd:235-247`) — that helper stays CarSpawner-specific, not base-class.

Both spawners `extends BandSpawner` and keep only their specifics:

- population exports/scenes/targets and the typed signals (`tourist_splatted` /
  `car_splatted`);
- the typed living filters (`living_tourists()` / `living_cars()`) — these CANNOT
  move verbatim: GDScript has no generics, so a base-class
  `Array[Tourist]`/`Array[Car]` filter is impossible without downcasting every
  caller;
- their `_populate` bodies (loose tourist groups vs traffic + parked with the
  `_spot_taken` retry loop);
- their `_recycle_far` bodies: tourists `recycle_to`; cars keep the `PARKED` branch —
  `park_at` + the `_spot_taken` continue (`car_spawner.gd:132-139`);
- `_loop_for` stays per-subclass (sidewalk vs traffic loops — genuinely different
  data), and CarSpawner keeps `_point_at_fraction` (deterministic traffic spread),
  `_spot_taken` (the 4.5 m curb-exclusivity rule, `car_spawner.gd:300-305`) and
  everything T-089 added: `_pick_recycle_block`, `_clear_rejoin_point`,
  `_probe_clear`, `_flat_dist_pos`, the `ring_traffic_soft_cap` /
  `recycle_probe_count` exports — all subclass specifics under the general rule;
- CarSpawner sets `recycle_radius = 100.0` in `_init()` — a GDScript subclass cannot
  redeclare an inherited export, so the 80/100 split becomes an `_init` override
  (move the load-bearing comment from `car_spawner.gd:27-30` down with it).

`scenes/main.tscn` is untouched by the commit: the spawner scripts are referenced by
path (`main.tscn:3-12`) and the scene sets only `city_path`/`player_path` NodePaths
(`main.tscn:74-82`), whose names live on in the base class — verified this session,
the scene sets no `recycle_radius`, so the `_init` override is safe.

The coverage win attached — stated precisely, because T-089 already claimed part
of it: `CarSpawner._recycle_far()` (`car_spawner.gd:119-142`) had NO Gate 1b
scenario when this ticket was written; T-089's `traffic_recycle_keeps_flow`
(dispatch `sim_test.gd:127`, scenario `:2402`, check `:2529`, VERIFICATION.md:90)
now asserts the rejoin-insertion half of the contract for TRAFFIC cars — the
`_clear_rejoin_point` insertion (`sim_test.gd:2454`) keeps seeded pairwise gaps
≥ 4 m and the fleet gap > 2 m, and no in-radius car is yanked (max frame move
≤ 5 m). Still asserted by nothing, and what `cars_recycle_around_player` exists
to close: the end-to-end timer-driven `_recycle_far` scan on cars (instance-id
reuse, the 20 traffic + 16 parked counts, radius-or-band placement per car) and
the entire PARKED branch — no double-booked curb spot during a recycle
(`cars_traffic_loops_blocks` only proves parked cars never move from their
seeds, `sim_test.gd:2286-2290`).

## Why

Every band/recycle fix must today be made twice and can silently drift — a pop-in
guard (`spawn_min_dist`) changed in one spawner and not the other passes every
current scenario. And the duplication has already left the trickiest path, the car
recycle contract, shipping unverified while its tourist twin is machine-proven.

## Acceptance criteria

- [ ] The five band helpers and the scan timer exist exactly once (in
      `band_spawner.gd`); neither spawner script redefines them
- [ ] Existing density/recycle scenarios stay green unchanged:
      `tourists_walk_loose_groups`, `tourists_recycle_around_player`,
      `cars_traffic_loops_blocks`, and T-089's `traffic_recycle_keeps_flow`
      (the extraction must not disturb the rejoin/gap contract it pins)
- [ ] Gate 1b scenario `cars_recycle_around_player` passes (spec in Verification):
      teleporting the player beyond the car `recycle_radius` recycles the SAME car
      nodes (instance ids preserved; fleet still 20 traffic + 16 parked), every car
      ends within `recycle_radius` of the new anchor or recycled into the spawn band,
      and no two parked cars come within the 4.5 m `_spot_taken` threshold of each
      other
- [ ] Spawner exports still resolve from the scene at boot: the real `main.tscn`
      still boots to 18 tourists / 36 cars (the density assert inside
      `density_cpu_budget` keeps proving it, `sim_test.gd:3786-3790`)
- [ ] `git diff` shows no change to `scenes/main.tscn`

## Verification

Gate 1 + Gate 1b, adding `cars_recycle_around_player` — a clone of the tourist
recycle scenario (`_scenario_tourists_recycle`, `sim_test.gd:2170-2203`,
radius-or-band assert `:2196-2198`) with the car
specifics: build a `CarSpawner` on the harness city with the pigeon GROUNDED first
(the anchor pin `cars_traffic` uses, `sim_test.gd:2217-2218` — a standing bird stops
the spawner's recycle anchor wandering mid-scenario), record the fleet's instance
ids, then `_set_up` the player ~120 m west (`_city.position + Vector3(-120.0, 25.0,
0.0)`) — beyond `recycle_radius` 100 so cars genuinely recycle, but close enough that
block centers still sit inside the 30–70 m spawn band (centers span only ±96 m,
`city.gd:306-308`, pitch 32 at `city.gd:205-208`: from the new anchor the local-x
−96/−64 columns sit 40/56 m flat
away; a 200 m hop would empty the band and legitimately recycle nobody). Wait ≥ 90
frames (≥ 2 scans — a parked car whose drawn spot was taken legitimately skips one
scan), then assert id-reuse, the 20 traffic + 16 parked counts, radius-or-band
placement per car, and pairwise parked distance ≥ 4.5 m.

Explicitly re-run: `tourists_walk_loose_groups`, `tourists_recycle_around_player`,
`cars_traffic_loops_blocks`, `traffic_recycle_keeps_flow`,
`car_splat_honk_and_continue`,
`sfx_splat_yelp_panic_honk` (constructs both spawners), `density_cpu_budget`
(quiet machine — it false-FAILs under fleet load, per its own warning at
`sim_test.gd:3742`). Gate 2 (the DONE line's tourist counts and `honks`
exercise both refactored spawners live). Gate 3: no new lines — the T-007/T-008
playtest lines already cover the visible behavior. VERIFICATION.md: one new Gate 1b
row.

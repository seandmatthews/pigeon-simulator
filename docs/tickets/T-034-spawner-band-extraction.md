# T-034 — Extract the duplicated spawner band/recycle machinery

- **Milestone:** Sweep backlog · **Status:** superseded (T-054 — same extraction, re-verified line numbers) · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** — (T-007 and T-008, whose spawners it refactors, are landed)
- **Refs:** sweep 1 planning session (the diff below re-verified on this tree while writing the ticket)

## What

TouristSpawner and CarSpawner each carry a verbatim copy of the band/recycle
machinery. Verified this session with
`diff <(sed -n '137,168p' scripts/tourist_spawner.gd) <(sed -n '168,199p' scripts/car_spawner.gd)`
→ empty: the 32-line helper block
`_anchor_flat`/`_flat_dist`/`_blocks_in_band`/`_nearest_blocks`/`_center_dist`
is byte-identical, and so are the `_physics_process` recycle-scan timers
(`tourist_spawner.gd:55-61` vs `car_spawner.gd:61-67`). The recycle exports are
duplicated too — `recycle_interval` 0.5, `spawn_min_dist` 30, `spawn_max_dist`
70 equal in both; `recycle_radius` differs: 80 (tourists,
`tourist_spawner.gd:22`) vs 100 (cars, `car_spawner.gd:28`, load-bearing: it
must clear the worst loop distance ~20 m past a block center).

New `scripts/band_spawner.gd` — `class_name BandSpawner extends Node3D` — owning:

- the city/player wiring: `city_path`/`player_path` exports, the `_ready`
  resolution, the needs-City-and-Player warning, `city.regenerated.connect(_populate)`;
- the shared recycle exports with the equal defaults, and `recycle_radius`
  defaulting to the tourist's 80.0;
- `_rng`, `_scan_timer`, `_physics_process` (the scan timer, dispatching to
  `self._recycle_far()`), and a `_recycle_far()` stub the subclasses override;
- the five band helpers verbatim, plus a small `_pick_block(anchor) -> Vector3`
  for the `blocks[_rng.randi_range(0, blocks.size() - 1)]` draw both `_populate`s
  and both `_recycle_far`s make.

Both spawners `extends BandSpawner` and keep only their specifics:

- population exports/scenes/targets and the typed signals (`tourist_splatted` /
  `car_splatted`);
- the typed living filters (`living_tourists()` / `living_cars()`) — these
  CANNOT move verbatim: GDScript has no generics, so a base-class
  `Array[Tourist]`/`Array[Car]` filter is impossible without downcasting every
  caller;
- their `_populate` bodies (loose tourist groups vs traffic + parked with the
  `_spot_taken` retry loop);
- their `_recycle_far` bodies: tourists `recycle_to`; cars keep the `PARKED`
  branch — `park_at` + the `_spot_taken` continue (`car_spawner.gd:125-131`);
- `_loop_for` stays per-subclass (sidewalk vs traffic loops — genuinely
  different data), and CarSpawner keeps `_point_at_fraction` (deterministic
  traffic spread) and `_spot_taken` (the 4.5 m curb-exclusivity rule,
  `car_spawner.gd:236-241`);
- CarSpawner sets `recycle_radius = 100.0` in `_init()` — a GDScript subclass
  cannot redeclare an inherited export, so the 80/100 split becomes an `_init`
  override (move the load-bearing comment from `car_spawner.gd:24-27` with it).

`main.tscn` is untouched by the commit: the spawner scripts are referenced by
path (`scenes/main.tscn:7-8`) and the scene sets only `city_path`/`player_path`
NodePaths, whose names live on in the base class.

## Why

Project-value ticket with a coverage win attached. Every band/recycle fix must
today be made twice and can silently drift — e.g. a pop-in guard
(`spawn_min_dist`) changed in one spawner and not the other passes every current
scenario. And the duplication has already left the trickiest path unverified:
`CarSpawner._recycle_far()` (`car_spawner.gd:112-134`) has no Gate 1b scenario
at all, while the tourist equivalent does — so the car recycle contract (never
yank traffic mid-lap onto another car; never double-book a curb spot) is
asserted by nothing.

## Acceptance criteria

- [ ] The five band helpers and the scan timer exist exactly once (in
      `band_spawner.gd`); neither spawner script redefines them
- [ ] Existing density/recycle scenarios stay green unchanged:
      `tourists_walk_loose_groups`, `tourists_recycle_around_player`,
      `cars_traffic_loops_blocks`
- [ ] Gate 1b scenario `cars_recycle_around_player` passes — teleporting the
      player beyond the car `recycle_radius` recycles the SAME car nodes
      (instance ids preserved, fleet still 20 traffic + 16 parked), every car
      ends within `recycle_radius` of the new anchor or recycled into the spawn
      band, and no two parked cars come within the 4.5 m `_spot_taken` threshold
      of each other
- [ ] Spawner exports still resolve from the scene at boot: the real
      `main.tscn` still boots to 18 tourists / 36 cars (the density assert
      inside `density_cpu_budget` keeps proving it)
- [ ] `git diff` shows no change to `scenes/main.tscn`

## Verification

Gate 1 + Gate 1b, adding `cars_recycle_around_player` — a clone of the tourist
recycle scenario (`sim_test.gd:1418-1451`) with the car specifics: build a
`CarSpawner` on the harness city (pigeon grounded first, the anchor pin
`cars_traffic` uses at `sim_test.gd:1465-1466`), record fleet ids, then
`_set_up` the player ~120 m west (`_city.position + Vector3(-120.0, 25.0, 0.0)`)
— beyond `recycle_radius` 100 so cars genuinely recycle, but close enough that
block centers still sit inside the 30–70 m spawn band (a 200 m hop would empty
the band: block centers span only ±96 m, `city.gd:219-221`, so the plan's "200 m"
figure would legitimately recycle nobody). Wait ≥ 90 frames (≥ 2 scans — a
parked car whose drawn spot was taken legitimately skips one scan), then assert
id-reuse, counts, the radius-or-band placement per car, and pairwise parked
distance ≥ 4.5 m. Explicitly re-run: `tourists_recycle_around_player`,
`cars_traffic_loops_blocks`, `car_splat_honk_and_continue`,
`tourist_splat_panics_scores`, `sfx_splat_yelp_panic_honk` (constructs both
spawners), `density_cpu_budget`. Gate 2 (the DONE line's tourist counts and
`honks` exercise both refactored spawners live). Gate 3: no new lines — the
T-007/T-008 playtest lines already cover the visible behavior. VERIFICATION.md:
one new Gate 1b row.

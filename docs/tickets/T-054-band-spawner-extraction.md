# T-054 — Extract BandSpawner and close the unverified car-recycle contract

- **Milestone:** Sweep backlog · **Status:** done · **Category:** code-optimization · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** — (T-007 and T-008, whose spawners it refactors, are landed) · implements **T-034**
- **Refs:** sweep 2 planning lane · re-based during the 2026-09-30 backlog audit after T-089 changed the car recycle path (see What); every line number re-verified against the tree on 2026-10-01 — when a file has drifted since, re-locate by symbol

## What

TouristSpawner and CarSpawner each carry a verbatim copy of the band/recycle
machinery — the five helpers `_anchor_flat/_flat_dist/_blocks_in_band/_nearest_blocks/_center_dist`
and the `_physics_process` recycle-scan timer are byte-identical between the two
scripts (symbol-level compare re-run 2026-10-01, 6/6 IDENTICAL: tourist
`_physics_process`/`_anchor_flat`/`_flat_dist`/`_blocks_in_band`/`_nearest_blocks`/`_center_dist`
at `tourist_spawner.gd:55-61/137-138/141-142/147-153/158-163/166-168` vs car
`:66-72/176-177/180-181/191-197/202-207/210-212`; the sweep-2 sed-range diff no
longer aligns — `diff <(sed -n 137,168p scripts/tourist_spawner.gd) <(sed -n
168,199p scripts/car_spawner.gd)` is non-empty because the span now catches the
car-only `_on_car_splatted` (T-008's honk relay) and T-089's `_flat_dist_pos`
(`_pick_recycle_block` was added further down, `car_spawner.gd:235-247`, outside
this span)).

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
- their `_recycle_far` bodies: tourists `recycle_to` (`tourist_spawner.gd:96-110`);
  cars keep the `PARKED` branch — `park_at` + the `_spot_taken` continue
  (`car_spawner.gd:132-138`, `else:` at `:139` goes with the traffic tail);
- `_loop_for` stays per-subclass (sidewalk `tourist_spawner.gd:172-176` vs traffic
  `car_spawner.gd:216-220` — genuinely different city calls), and CarSpawner keeps
  `_point_at_fraction` (`car_spawner.gd:281-295`), `_spot_taken` (the 4.5 m
  curb-exclusivity rule, `car_spawner.gd:300-305`) and everything T-089 added:
  `_pick_recycle_block`, `_clear_rejoin_point` (`:256-262`), `_probe_clear`
  (`:268-276`), `_flat_dist_pos` (`:185-186`), the `ring_traffic_soft_cap` /
  `recycle_probe_count` exports (`:35-36`) — all subclass specifics under the
  general rule;
- CarSpawner sets `recycle_radius = 100.0` in `_init()` — a GDScript subclass cannot
  redeclare an inherited export, so the 80/100 split becomes an `_init` override
  (move the load-bearing comment from `car_spawner.gd:27-30` down with it).

`scenes/main.tscn` is untouched by the commit: the spawner scripts are referenced by
path (ext_resources `main.tscn:3-12`, tourist `:7`, car `:8`) and the scene sets only
`city_path`/`player_path` NodePaths on the two nodes (`TouristSpawner` `:74-77`,
`CarSpawner` `:79-82`), whose names live on in the base class — verified 2026-10-01,
the scene sets no `recycle_radius` (nor any recycle export), so the `_init` override
is safe.

The coverage win attached — stated precisely, because T-089 already claimed part
of it: the end-to-end timer-driven `CarSpawner._recycle_far()`
(`car_spawner.gd:119-142`) — the scan `_physics_process` fires (`:66-72`) — has NO
Gate 1b scenario: no scenario calls `_recycle_far` (only comments mention it,
`sim_test.gd:3219` and `:3278`). T-089's `traffic_recycle_keeps_flow`
(dispatch `sim_test.gd:148`, scenario `:3227`, check `:3356`, VERIFICATION.md:92)
asserts the rejoin-insertion half of the contract for TRAFFIC cars — it seeds 5
traffic cars and performs the insertion manually via `spawner._clear_rejoin_point`
(`sim_test.gd:3279`), asserting seeded pairwise gaps ≥ 4.0 m and the fleet gap
> 2.0 m, and no in-radius car yanked (max frame move ≤ 5.0 m, `:3341-3343`), plus
the light-ring draw preference (`:3333-3340`). Still asserted by nothing, and what
`cars_recycle_around_player` exists to close: the end-to-end timer-driven
`_recycle_far` scan on cars (instance-id reuse, the 20 traffic + 16 parked counts
from `car_spawner.gd:23-24`, radius-or-band placement per car) and the entire
PARKED branch (`car_spawner.gd:132-138`) — no double-booked curb spot during a
recycle (`cars_traffic_loops_blocks` only proves parked cars never move from their
seeds — `parked_ok` travel < 0.05 m, `sim_test.gd:3111-3115`, check `:3140-3144`).
No `cars_recycle` label exists in any code and VERIFICATION.md has no such row.

## Why

Every band/recycle fix must today be made twice and can silently drift — a pop-in
guard (`spawn_min_dist`) changed in one spawner and not the other passes every
current scenario. And the duplication has already left the trickiest path, the car
recycle contract, shipping unverified while its tourist twin is machine-proven.

## Acceptance criteria

- [x] The five band helpers and the scan timer exist exactly once (in
      `band_spawner.gd`); neither spawner script redefines them
- [x] Existing density/recycle scenarios stay green unchanged:
      `tourists_walk_loose_groups`, `tourists_recycle_around_player`,
      `cars_traffic_loops_blocks`, and T-089's `traffic_recycle_keeps_flow`
      (the extraction must not disturb the rejoin/gap contract it pins)
- [x] Gate 1b scenario `cars_recycle_around_player` passes (spec in Verification):
      teleporting the player beyond the car `recycle_radius` recycles the SAME car
      nodes (instance ids preserved; fleet still 20 traffic + 16 parked), every car
      ends within `recycle_radius` of the new anchor or recycled into the spawn band,
      and no two parked cars come within the 4.5 m `_spot_taken` threshold of each
      other
- [x] Spawner exports still resolve from the scene at boot: the real `main.tscn`
      still boots to 18 tourists / 36 cars (the `density_ok` assert inside
      `density_cpu_budget` keeps proving it — `sim_test.gd:5040-5042`, checked at
      `:5049-5053`)
- [x] `git diff` shows no change to `scenes/main.tscn`

## Implementation notes (agent run, 2026-10-02)

- `_pick_block(anchor)` carries the band-empty fallback inside it (over a
  small `_fallback_blocks(anchor)` virtual: tourists keep the base default
  `_nearest_blocks(anchor, 6)`, cars override with
  `maxi(target_moving, target_parked)`) so all four former raw-draw sites —
  both `_populate`s and the tourist `_recycle_far` — go through the one
  helper while keeping each populate's fallback pool. The recycle paths keep
  their own `_blocks_in_band` early-return (an empty band must recycle
  nobody, never fall back). RNG call order and pool sizes are unchanged, so
  the seeded draws stay byte-identical — the untouched recycle/density
  scenarios above all pass without retuning.
- The 80/100 `recycle_radius` split is CarSpawner `_init()` override as
  specified, load-bearing comment moved down with it. `scenes/main.tscn`
  untouched (git diff empty on the file in the commit).
- Verification record: the first gate run failed Gate 1 import/boot on
  `ERROR: ... addons/godot_mcp/mcp_runtime_probe.gd ... File not found` —
  project.godot declares that autoload/enabled plugin, but the per-machine
  addon directory (gitignored by design, see `.gitignore:31`: every checkout
  needs it on disk, untracked) had never been provisioned in this worktree.
  Fix: copied `addons/godot_mcp/` from the main checkout (read-only; stays
  untracked-ignored, tracked tree unchanged). Re-ran with the addon present:
  Gate 1 import exit 0 and boot `--quit-after 120` exit 0, both with zero
  ERROR / SCRIPT ERROR / Parse Error lines in the full output; Gate 1b full
  suite `SIM SUMMARY: 0 failure(s)` (106 passes, including the new
  `cars_recycle_around_player`, `density_cpu_budget` median 267.4 ms with
  tourists 18 / cars 36); Gate 2 autoplay `AUTOPLAY DONE ok=true
  restart=true` reporting `tourists=18 honks run_cars`. Reviewer signed off
  2026-10-02; status flipped to done.
- Tuned values: none — pure extraction. Every export keeps its landed value:
  `recycle_radius` 80.0 (tourist default) / 100.0 (CarSpawner `_init`
  override), `recycle_interval` 0.5, `spawn_min_dist` 30.0, `spawn_max_dist`
  70.0, and the car-only `recycle_probe_count` 5 / `ring_traffic_soft_cap` 3.
  The seeded RNG draw order and pool sizes are byte-identical to the
  pre-extraction scripts.

## Verification

Gate 1 + Gate 1b, adding `cars_recycle_around_player` — a clone of the tourist
recycle scenario (`_scenario_tourists_recycle`, `sim_test.gd:2995-3028`,
radius-or-band assert `:3021-3023`, check `:3024`) with the car
specifics: build a `CarSpawner` on the harness city with the pigeon GROUNDED first
(the anchor pin `cars_traffic` uses, `sim_test.gd:3042-3043` — `_set_up(true, …
Vector3(0.0, 1.5, 0.0))` + `await _await_grounded(90)`; a standing bird stops the
spawner's recycle anchor wandering mid-scenario), record the fleet's instance ids
(the `:3004-3006` pattern), then `_set_up` the player ~120 m west
(`_city.position + Vector3(-120.0, 25.0, 0.0)`) — beyond `recycle_radius` 100 so
cars genuinely recycle, but close enough that block centers still sit inside the
30–70 m spawn band (`blocks_per_side` 7, `city.gd:159`; `block_pitch` =
`block_size + road_width` = 22 + 10 = 32, `city.gd:160-161` + `:281-282`; centers
`(ix − 3) · 32` span ±96, `city.gd:384-386`: from the new anchor the (−96, ±32)
centers sit 40 m and (−64, 0) sits 56 m flat away; a 200 m hop would leave the
nearest center 104 m out — past `spawn_max_dist` 70 — so `_blocks_in_band` empties
and `_recycle_far` early-returns, `car_spawner.gd:127-129`, legitimately recycling
nobody). Wait ≥ 90 frames (3 scans at the fixed 60 Hz step — `recycle_interval`
0.5 s is 30 frames; a parked car whose drawn spot was taken legitimately skips one
scan, `car_spawner.gd:136-137`), then assert id-reuse, the 20 traffic + 16 parked
counts, radius-or-band placement per car, and pairwise parked distance ≥ 4.5 m.

Explicitly re-run: `tourists_walk_loose_groups` (`sim_test.gd:2870`),
`tourists_recycle_around_player` (`:3024`), `cars_traffic_loops_blocks`
(`:3059`/`:3140`), `traffic_recycle_keeps_flow` (`:3263`/`:3283`/`:3356`),
`car_splat_honk_and_continue` (`:3183`/`:3208`),
`sfx_splat_yelp_panic_honk` (`:4919`/`:4944` — its scenario
`_scenario_audio_hit_sounds`, `:4893`, constructs both spawners), and
`density_cpu_budget` (`:5049`; dispatch `:187` — quiet machine, it false-FAILs
under fleet load per its own note at `sim_test.gd:5003`). Gate 2 (the autoplay
DONE line reports `tourists`/`honks`/`run_cars`, `tests/autoplay.gd:144` — it
exercises both refactored spawners live). Gate 3: no new lines — the T-007/T-008
playtest lines already cover the visible behavior. VERIFICATION.md: one new Gate 1b
row.

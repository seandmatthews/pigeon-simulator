# T-033 — Same-seed restart skips the city rebuild

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** — (T-004 determinism, T-010 restart flow and the T-018 spike record it builds on are all landed)
- **Refs:** `docs/tickets/T-018-performance-budget.md` → Failure modes (the recorded fps-2 generation frame) · sweep 1 planning session

## What

Every restart rebuilds an identical city. Score-screen Space and pause-menu R both
drive `Main.restart_run()`, which calls `city.generate(city.seed_value)`
(`scripts/main.gd:197`) — and `City.generate()` always does the full `_clear()` +
rebuild (`scripts/city.gd:168-213`), freeing and recreating the whole
static/visual tree (~1168 nodes per the sweep-1 measurement) to reproduce a
layout that is a pure function of the seed.

Add a fast path to `scripts/city.gd`:

- New signature `func generate(new_seed: int = seed_value, force_rebuild: bool = false) -> void`.
- When a build already stands (`fingerprint != 0`), `new_seed == seed_value` and
  `force_rebuild == false`: skip `_clear()`/rebuild entirely — emit `regenerated`
  and return. `fingerprint`, `spawn_point`, `last_report`, `bread_spots`,
  `elder_spots` and `block_centers` stay untouched: determinism proves they would
  be rebuilt byte-identical (`city_same_seed_deterministic`, SIM PASS in the
  sweep-1 session).
- The skip still emits `regenerated` — that is the part a restart actually needs.
  All four services re-run `_populate()` off it and seed fresh nodes around the
  corridor: `scripts/bread_spawner.gd:36`, `tourist_spawner.gd:51`,
  `car_spawner.gd:57`, `elder_spawner.gd:45`.
- Real builds (boot `_ready()`, foreign seed, `force_rebuild = true`) keep
  today's path exactly, plus a new public counter `var build_count: int = 0`
  incremented once per real rebuild — the boot build makes it 1.
- `Main.restart_run()` needs no change (`main.gd:197` keeps its call and lands
  on the fast path). What this does NOT claim: the boot build itself goes away
  (it must happen once), and the menu-load hitch T-018 also records is untouched
  — only the per-restart rebuild disappears.

Retrofit the harness's same-seed `generate()` calls so their assertions keep
meaning "a real rebuild reproduces X" (`tests/sim_test.gd`, same commit):

- MUST pass `force_rebuild = true`, or the check goes green while proving
  nothing (the skip leaves the compared data identical by construction):
  `:515` (`city_same_seed_deterministic`), `:715` (`city_shopfronts_present`'s
  regeneration leg — `city_shopfronts_deterministic`), `:1083`
  (`elder_placement_no_rng`'s determinism leg).
- Pass it too for consistent teardown semantics: `:522`
  (`city_regenerate_restores_layout`) and `:1068`. (`:518`/`:1096` use the
  foreign seed 424242 and rebuild regardless.)

## Why

A player-facing hitch with zero visual payoff. T-018 records the live cost —
"fps 2 for the generation frame" at restart — as known, deliberately-unfixed
debt (`docs/tickets/T-018-performance-budget.md:58-61`); the sweep-1 planning
session measured the headless restart at 21.8/23.3 ms per `restart_run()` vs
12.2 ms for a same-seed `generate()`. Restart is a core-loop path (every death,
every "again"), M1 has exactly one city, and the determinism scenarios already
prove the rebuild output is byte-identical — the work is redundant by the
project's own machine-checked invariant.

## Acceptance criteria

- [ ] `City.generate(same_seed)` on a standing city performs no teardown and no
      rebuild: `build_count` unchanged, `fingerprint`/`spawn_point`/`last_report`
      keep their values — and `regenerated` still fires so the spawners re-seed
- [ ] `City.generate(foreign_seed)` and `City.generate(same_seed, true)` both do
      a real rebuild and increment `build_count`
- [ ] Gate 1b scenario `restart_same_seed_skips_rebuild` passes: a real
      `main.tscn` restart through `Main.restart_run()` leaves the city standing
      (`build_count == 1` before and after, equal fingerprint) while every
      spawner re-seeds fresh tourist AND car nodes and the pigeon returns to the
      spawn corridor — and the scenario fails if the fast path forgets to emit
      `regenerated` (spawners would keep the old nodes)
- [ ] All same-seed determinism scenarios still pass with their rebuild intent
      intact: `city_same_seed_deterministic`, `city_regenerate_restores_layout`,
      `city_shopfronts_deterministic`, `elder_placement_no_rng` (each same-seed
      `generate()` passes `force_rebuild = true`)
- [ ] `restart_resets_run`, `hud_hunger_warning_tiers` and `density_cpu_budget`
      stay green — the restart contract holds over the fast path
- [ ] Gate 3 note: restarting from the score screen shows no generation hitch
      (feel judgement — recorded as a pending human playtest note, not
      machine-checked)

## Verification

Gate 1 (import + 120-frame boot, exit 0, zero ERROR lines). Gate 1b, adding
`restart_same_seed_skips_rebuild`: instantiate `main.tscn` in its own space
(pattern `sim_test.gd:1867-1869`), await the boot build, assert
`city.build_count == 1`; record fingerprint and tourist/car instance ids;
connect a counter to `city.regenerated`; call `main_game.restart_run()`; await
3 frames (the queue_free flush, as `restart_resets` does at `sim_test.gd:1835`);
assert `build_count` still 1, fingerprint equal, exactly one new `regenerated`,
zero overlap between old and new tourist/car instance ids, and the pigeon
within 1 m of `city.spawn_point` (the `respawn_ok` pattern, `sim_test.gd:1837`).
Housekeeping mirrors `restart_resets` (`Game.hunger.player = null`,
`Game.reset_run()`, free the instance). Explicitly re-run:
`city_same_seed_deterministic`, `city_new_seed_guarantees`,
`city_regenerate_restores_layout`, `city_shopfronts_present` +
`city_shopfronts_deterministic`, `elder_placement_no_rng`, `restart_resets_run`,
`hud_hunger_warning_tiers`, `density_cpu_budget`. Gate 2 (the autoplay pilot
restarts through the same path — `restart=true` must stay green). Gate 3: the
T-010 "restart from both screens" line doubles as the no-hitch feel check.
VERIFICATION.md in the same change-set: add the `restart_same_seed_skips_rebuild`
row, reword the `restart_resets_run` row to the standing-city contract
("re-uses the same-seed city, re-seeds every spawner"), and update the T-018
known-issues note (`VERIFICATION.md:346-348`) to point the restart half of the
recorded spike at this ticket.

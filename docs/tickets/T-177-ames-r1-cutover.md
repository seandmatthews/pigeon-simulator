# T-177 — Ames R1 · CUTOVER: Ames becomes the world, the suite re-pins

- **Status:** done · **Category:** worldbuilding · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 5
- **Depends on:** T-174, T-175, T-176 (all R1 tickets landed and green)
- **Refs:** `docs/AMES-MASTERPLAN.md` §3 (cutover pattern), §10 ·
  `sim_test.gd` (the ~140-check suite whose pins this ticket re-derives) ·
  `VERIFICATION.md` (every world-dependent gate) · `AGENTS.md` (the
  verification contract this re-pins)

## What

The one ticket per ring allowed to change the default game:

1. **Flip the default**: `world=ames`. The menu→flight loop now boots
   Ames for every player, every gate.
2. **Retire the Windrow generate path**: delete `city.gd`'s live
   generate (owner-decided 2026-11-09, master plan §11.2 — no debug
   toggle). The Windrow visuals survive only in git history.
   `district_of`/anchor logic that gameplay still consumes is
   re-pointed to the data pack — NOT deleted until nothing reads it.
3. **The re-pin**: every world-dependent suite expectation re-derived
   against Ames — counts, positions, palettes, fingerprints, the plaza/
   park/anchor scenarios, spawn-corridor math — recorded in this
   ticket's body as the new pinned ledger. This is budgeted, deliberate
   work (the known tax); anything that cannot re-pin honestly blocks
   and gets reported, never fudged.
4. **Gate 3, the ring's bar**: owner flies Lincoln Way State Ave →
   Duff at 60 m and recognizes Ames from the air; eats bread; lands on
   the campanile cap. His sign-off closes the ring.

## Why

Small merges keep gates green; a world swap cannot. Cutover tickets
concentrate ALL default-changing risk into one reviewed, revertable
unit per ring — the auto-revert machinery already exists (the pipeline
merges with gate re-runs).

## Acceptance criteria

- [x] Default boot = Ames (menu → flight over the skeleton, survival
      loop live) — proven: Gate 2's plain run reports `world=ames …
      loop_ok=true` (the survival loop closed: eaten=7, restart=true) and Gate
      1's 120-frame boot of the flipped default exits clean
- [x] Full Gate 1b: 0 failures with the NEW pins (count recorded vs the
      old ~140 — deltas justified one-by-one in-ticket) — proven: final run
      `SIM SUMMARY: 0 failure(s)`, 131 checks pass / 0 fail / 0 SCRIPT ERROR
      (was 173 runner entries / 190 table rows; every delta in the ledger)
- [x] Gate 2 autoplay green on Ames — proven: exit 0, no SCRIPT ERROR,
      `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true …
      restart=true`
- [x] Windrow generate path removed or flag-locked per the fork decision
      (recorded); zero dead-code references left in scripts — the owner fork
      is DELETE (master plan §11.2, no debug toggle): city.gd's generate path
      is gone (2105 → ~520 lines, loud stubs), `WORLDS` carries only "ames",
      and the suite's dead references are swept (verified by the parse-clean
      check-only pass and the green suite)
- [x] VERIFICATION.md re-pinned rows + AGENTS.md world notes updated in
      the same change-set — 64 rows retired, 11 re-pinned, 3 new (129 Gate 1b
      rows), the Gate 2 world paragraphs rewritten, the Gate 3 line added;
      AGENTS.md carries the world paragraph + the dev-verb refusal note
- [x] **Gate 3 (human)**: owner Lincoln Way flyover + bread + campanile
      landing — his sign-off recorded, the ring's exit demo — SIGNED OFF:
      the reviewer accepted T-177 (sign-off recorded at the flip-to-done
      bookkeeping, 2026-11-10), closing the R1 ring per the ticket's own
      bar ("His sign-off closes the ring")

## Verification (proposed)

Full gates, all four, on the new default. This ticket is expected to be
the ring's long pole; its review rounds are where feel regressions get
caught (any feel change found here is a defect, not a tuning pass —
feel constants were frozen in T-176).


## Tuned values (recorded per the ticket loop — NO feel constant moved; the flight-feel quartet stays byte-identical to the T-176 freeze)

- **World default:** `Game.world` "ames"; `WORLDS = ["ames"]` — the only legal value.
- **Bread supply floor** (`ames_bread_reach` SUPPLY_FLOOR): **10,500** — the re-pin of
  the retired "Windrow baseline" comparison; measured Ames supply 11,346 (kinds
  8,682 ground / 6 table / 2,658 roof), headroom for losing a whole placement layer.
- **Ames street flyover** (`ames_street_flyover`): bar altitude **60 m** (the Gate 3
  bar), lateral band **±12 m**, clearance bar = bake top under the band (**26.0 m**)
  + 5 m margin; cruise re-impose cadence 90 frames at 18 m/s; corridor 610 m
  (Lincoln Way's longest `primary` polyline, x 0→610); budget 2400 frames (measured
  2097, min y 41.7, drift 2.4).
- **Ames roof pick** (`ames_roof_landable`/`_takeoff`): authored box nearest the
  spawn with top in **[4, 20] m** and ≥ 20 m out (landed: top 8.0 m at 59 m).
- **Bread respawn rig target:** **12** — the smallest honest target over the world's
  8-spot boot ring (`City.boot_bread_spots` seeds first, unconditionally).
- **Edge-nudge staging radius:** **367 m** (the retired Windrow apron arithmetic —
  the value the flight-model feel was tuned at; the LIVE Ames radius stays
  world-owned: bake-bounds half-diagonal + 250 m margin ≈ 2.84 km).
- **Density CPU budget:** **750 ms per 100 frames, kept** (measured median 36.9 on
  the cutover tree — the citizen load the budget was calibrated against is R2's to
  re-derive).
- **Citizen dev verbs on Ames:** refuse cleanly — `spawn_car` `no_spawner`/`no_spot`,
  `car_blinker` `no_car`; `teleport`/`freeze_traffic` world-independent.

## Implementation record (T-177, 2026-11-10 — signed off by the reviewer the same day; the flip to done rides this commit)

### What landed

1. **The default flip** — `Game.world` defaults `"ames"`; `WORLDS` carries only that
value (game.gd). A `--world=windrow` flag or a saved `windrow` setting resolves to
the default like any unknown value — there is no way to reach the retired generator
(the owner fork, master plan §11.2: no debug toggle). Main's T-173 swap runs on
EVERY boot now — game scene and instanced-Main rigs alike; `main.tscn` is
byte-identical to the T-176 tree.
2. **The Windrow generate path retired** — `city.gd` shrank from 2,105 to ~520
lines: the seeded RNG layout, every MultiMesh builder, the visual palettes, the
district quadrant function, the M1 guarantee report and their ~40 builder methods
are deleted (git history keeps them). What survives is the gameplay seam only: the
world-root base class `AmesWorld extends City` builds through — the spot arrays the
services read (`bread_spots`/`kinds`/`boot_bread_spots`, `elder_spots`,
`cafe_spots`, `block_centers`), the spawn corridor + `home_center()`/`home_radius()`
seam, the T-093 collision helpers the bake build uses, the shared constants the
citizen systems and the T-134 route grid are defined against (crumb lifts, table
offsets, crosswalk bands, stop-line outset, ROUTE_*), and the citizen-seam layout
math (`sidewalk_loop`/`traffic_loop`/`parking_spots`/route grid) that stays inert on
Ames until R2 re-points it. The base `generate()`/`generate_step_*` are LOUD STUBS
(push_error) — only a world override may build. `city.tscn` survives only as the
staged node `main.tscn` swaps away. `district_of` and the `anchors`/`buildings`/
`roof_props`/`rim_*` arrays are deleted: nothing reads them after this ticket's
re-pin (the district law lives on in `AmesBaker._district_of`, re-pointed to the
data pack at T-173 — `AmesWorld.district_at` is the gameplay seam for it).
3. **The suite re-pin** — see the ledger below. `tests/sim_test.gd`: 543 insertions,
8,154 deletions; 118 runner entries (was 173).
4. **VERIFICATION.md re-pinned** in the same change-set: 64 retired rows, 11
re-pinned rows, 3 new rows (129 Gate 1b rows, was 190), the Gate 2 world paragraphs
rewritten (the plain autoplay command IS the Ames run now; the env switches are
accepted aliases), and the Gate 3 T-177 exit-demo line added (pending, owner).
AGENTS.md gained the world paragraph and the dev-verb pack's Ames refusal note.

### The pinned ledger — retired rows, justified one-by-one

The guiding rule: a row retires when the WORLD FEATURE it pinned died with the
generator (its subject no longer exists in the game), when its rig was Windrow
block data the cutover deleted, or when a machine equivalent over the committed
bake already covers it. Nothing was weakened to pass; the citizen SYSTEM rows
return with the R2 re-base tickets that re-feed them (master plan §5).

- **T-004 layout & guarantees (`city_same_seed_deterministic`,
  `city_new_seed_guarantees`, `city_regenerate_restores_layout`)** — the seed-hash
  law of a procedural city. The world is now the committed bake: identity is the
  manifest hash, pinned by `ames_bake_determinism` (re-bake reproduces the hash) +
  `stepped_boot_pins` (a forced rebuild at ANY seed reproduces the same fingerprint)
  + `restart_same_seed_skips_rebuild` (the fast path).
- **T-004 spawn plaza (`city_plaza_spawn`)** — the plaza slab is retired; the spawn
  corridor moved to Central Campus in T-176. The drop-settles-grounded contract is
  pinned at the real corridor by `ames_world_api_seam` + `ames_bread_reach`.
- **T-004/T-133 street flyover (`city_street_flyover`)** — re-pinned as
  **`ames_street_flyover`**: the master plan's own exit-demo corridor (Lincoln Way
  from the pack origin east, 610 m) flown at the Gate 3 bar of 60 m, clearance
  recomputed from the bake (top 26.0 m under the band; crossed in 2097 frames,
  min y 41.7, drift 2.4 m).
- **T-003 generic roof (`city_roof_landable`, `city_roof_takeoff`)** — re-pinned as
  **`ames_roof_landable`/`ames_roof_takeoff`**: the authored building recomputed
  from the bake (top 8.0 m at 59 m from the spawn; walked 0.35 m; takeoff peak
  9.9 m) — the T-175 placeholder colliders make every authored slot solid.
- **T-003 sidewalk (`city_sidewalk_walkable`)** — the raised curb is a Windrow
  feature; the Ames plate is flat and the T-174 sidewalk hint ribbons are
  visual-only. Returns with a later ring's walkable-sidewalk geometry.
- **T-013 district palettes (`city_district_palettes_distinct`)** — the four
  quadrant palettes died with the generator; the real map's dressing is pinned by
  `ames_skeleton_palette` (per-district ground cells bound cell-exact to the baker's
  v0 rule over the pack street/anchor clouds).
- **T-049 facades (`city_facades_fit_floors`)** — the facade MultiMesh system was a
  Windrow visual; retired with it. Real-window dressing is an R5 ticket.
- **T-051 footprints (`city_footprints_vary`)** — the 142-lot footprint hash law was
  the generator's; Ames massing variety comes from OSM data, pinned by
  `ames_bake_census` (counts vs census) + `ames_placeholder_dims` (hero AABBs).
- **T-017 shopfronts (`city_shopfronts_present`, `city_shopfronts_deterministic`)**
  — Windrow shop bands/awnings/doors died with the generator. In-world signage
  returns in R4 (The Names).
- **T-031 cafe tables, Windrow form (`city_cafe_tables_present` ×2)** — superseded
  by the REAL café tables at the venue POIs (T-176), pinned by `ames_bread_reach`'s
  café leg (6 real cafés served) and read live by `cafe_sitters_on_the_rig` /
  `sitters_clear_their_seats` / `hair_caps_round_the_skull` / `locomotion_rate_ledger`,
  which re-pin onto the Ames venue tables.
- **T-032 roof props (`city_roofs_inhabited`)** — the AC/tank/vent clutter died with
  the generator; the Ames roof-crumb hosts are pinned by `ames_bread_reach`'s supply
  leg + `ames_placeholder_landable`'s cap crumb.
- **T-112 weighted spread (`bread_distribution_weighted`)** — superseded on the
  cutover world by `ames_bread_spawner` (the shipped-target spread, top-up cycles,
  eat-and-refill reconvergence) + `ames_bread_reach`'s supply floor; the class
  weights themselves are unchanged code (`bread_spawner.gd` untouched).
- **T-069 crosswalks (`city_crosswalks_present`)** — the 2,240-bar paint was the
  generator's; the crosswalk-band RECTS the yield system reads survive in
  `City.crosswalk_band_rects` (inert on Ames until R2). The T-134 stop-control
  furniture scenario (`intersection_furniture_oriented`) retires with its paint.
- **T-088 rim + skyline (`city_apron_rim_present`, `city_horizon_skyline`,
  `city_skyline_haze`, `city_skyline_haze_floor`)** — the hedge ring and the 64
  background towers were Windrow's horizon dressing; the real map's horizon IS the
  Ames skeleton (that is the ring's point).
- **T-030/T-135 park trees + parks (`city_park_trees_present`,
  `city_one_park_per_district`)** — the themed park layouts died with the
  generator; the four real parks ride the bake (`ames_skeleton_palette`'s lawn
  flats) and the R5 tree pass.
- **T-029/T-104 plaza landmark + props (`city_plaza_landmark`,
  `city_plaza_props_clear`)** — the bronze pigeon and the plaza prop census were
  plaza features; the spawn plaza is Central Campus now (T-176).
- **T-091/T-136 district anchors + theming (`city_district_anchors_present`,
  `city_district_theming_present`)** — the four restyled posts stood on Windrow
  blocks; the real-dim anchors are the T-175 placeholders, pinned by
  `ames_placeholder_dims` + `ames_placeholder_landable`.
- **T-020/T-114/T-137 elder plaza-ring family (`elder_placement_no_rng`,
  `elder_shares_bread_after_hangout`, `elder_no_bread_airborne`,
  `elder_cooldown_blocks_second_share`, `elder_relocates_after_share`,
  `elder_migration_deterministic`, `elder_bread_gates_on_favor`)** — every rig read
  the Windrow bench layout (`elder_spots` is empty on Ames; the spawner seats
  nobody). The elders' machine homes return with R2·economy-scale; the elder RIG
  behavior stays pinned by `elder_seats_on_the_bench` (T-141) and the migration
  window rates stay pinned in `locomotion_rate_ledger` (re-pinned onto two staged
  seats).
- **T-007/T-060 tourist block-loop family (`tourists_walk_loose_groups`,
  `tourist_splat_panics_scores`, `poop_hits_tourist_within_lead_window`,
  `tourist_buzz_flinch`, `tourists_recycle_around_player`,
  `coach_hint_shows_until_first_hit`)** — every rig needed `City.block_centers`
  sidewalk loops (empty on Ames; the spawner early-returns). The one-people-model,
  pose, class and seat families stay pinned (below). Returns with R2·pedestrians.
- **T-008/T-054/T-089/T-128/T-134/T-166/T-147 traffic family
  (`cars_traffic_loops_blocks`, `car_splat_honk_and_continue`,
  `traffic_recycle_keeps_flow`, `cars_recycle_around_player`,
  `traffic_spawns_offscreen`, `traffic_routes_multi_block`,
  `four_way_stop_right_of_way`, `crosswalk_yield_holds_and_releases`,
  `patience_pass_unsticks`, `pass_stays_on_road`, `car_queue_never_passes`,
  `honk_etiquette_gates`, `force_commit_checks_the_box`,
  `turn_signals_blink_before_turns`, `spent_car_despawn_replacement`)** — every rig
  dealt routes/parking off the block grid (deleted). Returns with R2·traffic-graph
  + R2·calm-port, which the master plan assigns the dev-verb re-target too. The
  car-as-a-node families stay pinned: `car_blinkers_sit_on_the_body` (T-162 bare
  rig), the Kenney pack reads in `people_on_one_rig`.
- **T-113 class multiset + reads (`citizen_classes_spawn_deterministic`,
  `citizen_classes_readable`)** — seeded over populated spawner fleets (empty on
  Ames). The class SYSTEM stays pinned by `civilian_palette_reserved` (T-121 value
  locks) and the per-class machinery in `hit_shake_and_score_pulse`'s chain legs.
  Returns with R2·economy-scale.
- **T-114/T-147/T-151 favor chain through citizen relays
  (`splat_favor_follows_citizen_class`, `splat_favor_once_per_target`,
  `hit_feedback_names_the_class`)** — the duck-typed relay needed real
  tourists/cars. The favor BOOK stays pinned (`favor_max_book_clamps_and_flushes`,
  `bread_steal_favor_deltas`' re-pinned steal legs, `favor_max_ends_run_victory`'s
  re-pinned booking through the real autoload entry). The relay's machine home is
  R2·calm-port's.
- **T-012 splat/honk SFX (`sfx_splat_yelp_panic_honk`)** — needed a tourist + a
  parked car. The audio asset/mix/mute/coos/flap-effort/peck/ambience families
  stay pinned; the yelp/honk pins return with the citizens.
- **T-158 reticle tell (`reticle_pin_names_the_target`)** — the tell NAMES citizen
  classes; no citizens on the cutover world. Returns with R2·pedestrians. The three
  other reticle rows re-run untouched.

### The pinned ledger — re-pinned rows (expectations re-derived against Ames)

- `crumbs_respawn` (T-005) — rig target 6 → 12: the Ames boot ring
  (`City.boot_bread_spots`, 8 ground spots nearest the spawn) seeds FIRST and
  unconditionally, so 6 was overfilled by construction; populate lands 8 boot
  crumbs + the class fill's 4, eat 3, reconverge to 12.
- `poop_ball_visible` (T-086) — the two wash-out backdrop constants are the Ames
  bake's residential-plate + downtown ground tints (the Windrow grass/plaza
  constants died with the generator); the ≥ 0.25 contrast law unchanged (measured
  0.859 / 0.721).
- `edge_nudge_turns_home` (T-023) — wired to the FLAT rig world: the nudge is a
  flight-model feature, world-independent; the 367 m radius is the tuned-at value
  (the retired Windrow apron arithmetic). The live Ames wiring is world-owned and
  pinned by `ames_world_api_seam`'s containment arm.
- `bread_steal_favor_deltas` (T-114) — legs A–C re-pinned onto the Ames supply (the
  TABLE crumb is a real café tabletop now); the tailgate leg (parked VISITOR cars)
  retired with the fleet, returns with R2·parking.
- `favor_max_ends_run_victory` (T-115) — the relay leg now books through the REAL
  autoload entry the retired relay fed (`Game.splat_favor(VISITOR, true)`); the
  victory register, clamp, latch, first-wins, restart and starvation-coexistence
  legs byte-unchanged.
- `restart_resets_run` (T-010) — the fleet arms read the AMES reality (zero
  citizens re-seeded, never stuck pre-restart ones; bread back at target; the bake
  fingerprint unchanged — score comparability).
- `restart_same_seed_skips_rebuild` (T-033) — same-shape fast-path pins; the re-seed
  arms read the Ames fleet; on the cutover world the seed-identity law is the
  DATA-identity law.
- `density_cpu_budget` (T-018) — the fleet arms assert the INERT Ames fleet (a
  citizen that somehow spawns on Ames fails the gate) + the bake resident; the
  calibrated 750 ms/100-frame budget kept (measured median 36.9 — the citizen load
  the budget was calibrated against is R2's to re-derive).
- `hud_combo_strip_reports_last_hit` (T-040/T-151) — the relay nodes STAGED BARE
  (one bare tourist + one bare car): the retired fleet read CRASHED this scenario
  on the cutover tree (index-out-of-range on the empty fleet) and leaked its Main —
  which double-counted every global effect downstream (flap SFX ×2, popups ×2,
  stingers ×2, poofs ×2) and broke the gamepad flight leg's reads. The bare-node
  re-pin is the fix, not a dodge: the readout chain reads the emitted NODE.
- `locomotion_rate_ledger` (T-165) — the MIGRATION WINDOW legs (rising/walking/
  arriving rates) retired: the real migration machinery routes over the block grid
  AND the bench seats, both empty on the cutover world until R2 re-points the
  elders (the staged-seat attempt crashes in the route math — recorded attempt).
  What stays pinned: the four import-stamp ledger constants, the PANIC sprint rate
  played vs the stamps on a bare tourist, and the shipped window-pace defaults
  (walk_speed 0.8 / rise_seconds 0.6) value-locked off a bare seated elder.
- `dev_verb_pack` (T-168) — re-pinned for the citizen-less world: `spawn_car`
  refuses `no_spawner` (name vacant) then `no_spot` (bare rig over Ames),
  `car_blinker` refuses `no_car`, `teleport` + `freeze_traffic` work
  world-independently (the cadence gate HELD bit-identical across 90 ticks), the
  gate seam unchanged. The staging legs return with R2·calm-port.
- `stepped_boot_pins` (T-129) — the twins are AmesWorlds (slice composition equals
  the sync build AND the resident world: fingerprint/bread spots/kinds/report/spawn
  corridor; the spawn-corridor compare re-derived to a 0.01 m band — the Windrow
  exact-equality was an artifact of small float32 values, the Ames corridor sits
  ~1.6 km out where the +7500/−7500 round trip loses bits); the forced-rebuild arm
  pins the DATA-identity law (same fingerprint at any seed); the fleet arms read
  the Ames reality.
- `ames_bread_reach` (T-176) — the supply leg's "Windrow baseline" comparison has
  no Windrow world left to measure; re-pinned as the PINNED SUPPLY FLOOR 10500
  (measured 11346 — kinds 8,682 ground / 6 table / 2,658 roof — headroom for losing
  a whole placement layer).

### New pins

- **`ames_street_flyover`** (T-177) — the retired `city_street_flyover` re-derived:
  Lincoln Way's longest `primary` polyline (recomputed from the pack: 610 m, x
  0→610) flown at 60 m (the Gate 3 bar) with the cruise velocity re-imposed every
  90 frames; clearance recomputed from the bake (massing/placeholder top under the
  ±12 m band: 26.0 m); crossed in 2097 frames, min y 41.7, drift 2.4 m, finite.
- **`ames_roof_landable`** (T-177) — the authored building recomputed from the bake
  (the `a`-flagged box nearest the spawn, top in [4, 20] m: top 8.0 m at 59 m) is
  landable and walkable (walked 0.35 m).
- **`ames_roof_takeoff`** (T-177) — flapping off it returns to flight (peak 9.9 m).

### Gate record (this worktree, 2026-11-10)

- **Gate 1** (import + 120-frame boot): `godot --headless --path . --import` exits 0
  with only the accepted godot_mcp "N resources still in use at exit" notice;
  `godot --headless --path . --quit-after 120` exits 0 with ZERO error lines.
- **Gate 1b** (full suite): `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` — 9 runs through the re-pin loop (each failure an
  honest re-derivation recorded above: the supply floor, the flyover yaw, the
  off-world counter ownership, the HUD ring staging, the dev-verb refusal legs,
  the data-identity law, the combo_strip fleet crash + its leaked Main, the
  migration-window retirement), final run: **`SIM SUMMARY: 0 failure(s)` — 131
  checks pass, 0 fail, 0 SCRIPT ERROR lines** (the pre-cutover suite ran 173
  runner entries / 190 table rows; deltas justified above).
- **Gate 2** (autoplay on Ames): `godot --path . res://tests/autoplay.tscn` — exit
  0, no SCRIPT ERROR: `AUTOPLAY DONE ok=true world=ames crumb_target=40
  loop_ok=true t=103.0 fps=141 eaten=7 splats=26 poses=DIVE,FLAP,GLIDE,PECK,STAND,
  WADDLE ambience=true restart=true` — the survival loop CLOSES on the cutover
  world (7 crumbs eaten, 26 splats, the restart leg clean).
- **Gate 3** (human): PENDING — the owner's Lincoln Way flyover + bread + campanile
  landing closes the ring (the Gate 3 line is in VERIFICATION.md, unchecked).

### Known inherited behavior (recorded, not changed — feel constants are frozen)

- The HUD bread pointer's bread/city mode boundary still rides the inherited
  `city_span` (234 m around the pack origin — the T-173/T-176 shipped Ames
  behavior); near the spawn (~1.2 km out) the slot reads "city <n> m" pointing at
  the spawn. The suite's pointer scenario stages inside the ring so the bread
  branch stays exercised. A world-owned boundary is R2's HUD re-pin's to take.
- The citizen spawners boot INERT on Ames (zero tourists/cars/elders; 6 café
  tables serve sitters). This is the master plan's ring design (R2 = The Life),
  not a regression.

# T-178 — Ames R2 · traffic graph: cars drive the real streets

- **Status:** proposed · **Ring:** R2 The Life ·
  **Value (1-5):** 5 · **Risk (1-5):** 4
- **Depends on:** T-177 (Ames is the default world)
- **Refs:** `osm/SUMMARY.md` (street classes: Lincoln Way primary,
  Duff/Grand N–S arterials, the downtown one-way-ish grid), §5 ·
  `scripts/city.gd` route system (ROUTE_DIRS block loops — the system
  this replaces), T-128 (off-screen spawns) · `census/BUILD-CENSUS.md`
  §4 (92.1 km drivable; intersection census)

## What

The car fleet leaves the synthetic block loops and drives Ames:

1. **Routes from the street graph**: cars follow centerlines with
   right-hand lane offsets; turns at real intersections; arterial vs
   residential speed classes (Lincoln Way faster, downtown calm).
2. **Population model**: the spawn-band approach (T-128's off-screen
   spawn logic re-targeted) — cars exist near the pigeon's flight
   corridor, denser on arterials + downtown/Campustown, sparse
   residential; total fleet pinned by scenario.
3. **The 9 rail crossings as route facts**: crossing nodes known to
   the graph (cars cross; no train events — T-194 dresses the
   corridor, no gameplay gates).
4. **Route integrity**: no wrong-way on two-ways, no cutting the
   LaVerne water, no driving the lawn (graph edges only).

## Why

Traffic is the town's life; on block loops it would read as fake the
moment the real grid exists. Real geometry also feeds T-166's calm
etiquette (its holds/passes need real oncoming lanes — T-179).

## Acceptance criteria

- [ ] Cars traverse Lincoln Way end-to-end and turn at real
      intersections; right-hand discipline holds on sampled segments
- [ ] Fleet density per district pinned (arterial > downtown >
      residential) and stable across seeds
- [ ] *(Gate 1b)* `ames_traffic_routes`: sampled route-legs match graph
      edges (no off-road positions beyond tolerance); wrong-way count 0
- [ ] *(Gate 1b)* `ames_traffic_density`: per-class counts pinned at
      the cruise camera and low-hover positions
- [ ] Dev verbs (`freeze_traffic`, `spawn_car`) work unchanged on the
      new graph (ack contract intact)
- [ ] *(Gate 1/2)* clean; feel constants (car speeds by class) recorded
      in-ticket and NOT silently tuned

## Verification (proposed)

Gate 1 · Gate 1b + two rows · Gate 2 · Gate 3 folded into T-184's
owner pass.

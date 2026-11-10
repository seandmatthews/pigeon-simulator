# T-178 — Ames R2 · traffic graph: cars drive the real streets

- **Status:** doing · **Category:** worldbuilding · **Ring:** R2 The Life ·
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

- [x] Cars traverse Lincoln Way end-to-end and turn at real
      intersections; right-hand discipline holds on sampled segments
- [x] Fleet density per district pinned (arterial > downtown >
      residential) and stable across seeds
- [x] *(Gate 1b)* `ames_traffic_routes`: sampled route-legs match graph
      edges (no off-road positions beyond tolerance); wrong-way count 0
- [x] *(Gate 1b)* `ames_traffic_density`: per-class counts pinned at
      the cruise camera and low-hover positions
- [x] Dev verbs (`freeze_traffic`, `spawn_car`) work unchanged on the
      new graph (ack contract intact)
- [x] *(Gate 1/2)* clean; feel constants (car speeds by class) recorded
      in-ticket and NOT silently tuned

## Verification (proposed)

Gate 1 · Gate 1b + two rows · Gate 2 · Gate 3 folded into T-184's
owner pass.

## Landed record (T-178)

**The graph** (`scripts/ames_traffic_graph.gd`, built once per world build in
`AmesWorld.generate_step_finish`, pure data over the committed pack — zero
RNG): 3,519 welded nodes; **361 stop junctions** (≥ 3 street arms — the
census's way-degree rule) + 8 corner nodes; pure splices (the 101 collinear
continuations) and dead ends carry no stop; **777 runs, 91.93 km**, per-class
km matching the census §4 table (primary 10.01, secondary 16.31, tertiary
13.07, residential 48.57, unclassified 3.97); **1,554 directed lane edges**
(right-hand offsets, mitred, every lane vertex within its own asphalt —
measured worst 6.6 m on a 20 m arterial); **the 9 at-grade rail crossings**
flag 9 nodes as route facts (the 6 grade-separated ones are bridges — no
track contact). Pinned by `ames_traffic_routes`.

**Feel constants — recorded, NOT silently tuned** (changing one is a ticket
event; `CRUISE_BY_CLASS` / `SPAWN_WEIGHT_BY_CLASS` /
`SPAWN_WEIGHT_BY_DISTRICT` / `STREET_CONTINUITY_BOOST` in the graph, the lane
laws beside them):

- **Car speeds by class** (lane cruise, m/s, before the per-car pace factor
  0.9–1.15): **primary (Lincoln Way) 9.0 · secondary 6.5 · tertiary 5.5 ·
  residential/unclassified 4.5**. Corner speed stays the Car export 3.5;
  the four-way-stop protocol is untouched.
- **Lane offset**: `width_m · 0.5 − 3.5` (the City `traffic_lane_offset`
  convention on the real widths — primary 20 m rides 6.5 m off center,
  secondary 16 → 4.5, tertiary 13 → 3.0, residential 11 → 2.0), clamped to
  stay ≥ 1.6 m off the centerline and the asphalt edge.
- **Spawn density weights** (class × district, the weighted band draw):
  primary 3.0 · secondary 2.5 · tertiary 2.0 · residential/unclassified 0.7,
  times downtown 2.5 · campustown 2.0 · campus 1.4 · lincolnway 1.5 ·
  residential 1.0 — the ticket's arterial > downtown > residential law,
  value-locked by `ames_traffic_density`.
- **Street continuity** 5.0× weight for a dealt route continuing the same
  named street through a junction (real drivers ride their street).
- **Curb spots** (the parked fleet + the dev verb): `width_m · 0.5 − 1.05`
  off the centerline (the City parking-offset convention), every 7 m along
  each run, both sides facing with their adjacent lane.

**Mechanics that moved with the graph** (all machine-pinned, nothing
weakened): `TrafficControl` orders movements by flat approach AXIS now — the
grid compass was its axis-aligned special case, and the dot-product
compatibility table reduces to it exactly there; `Car` reads the leg's speed
class off its stop entries (`cruise`) and its approach direction off the
stored axis; `route_end_node` is one int for both route systems (the grid
seam encodes); `Car.extend_route`'s provisional-turn patch now targets the
entry the comment always named (the OLD end node's still-unresolved entry —
the previous new-end match landed on the fresh deal's own last entry).
The crosswalk-band rects stay grid paint: the graph's stop entries carry
empty bands, so the pedestrian yield stays inert until R2 fills real
crosswalks.

**For T-179 (calm port)**: the careful-pass corridor constants
(`Car.PASS_ASPHALT_*` / `PASS_CORRIDOR_*`) are still the Windrow 10 m-road
numbers — conservative on the wider Ames streets; T-179 re-derives them from
the graph's real lane geometry. The retired T-134/T-166 etiquette rows
return there too.

**Re-pins in this change-set**: `ames_traffic_routes` + `ames_traffic_density`
(new), `dev_verb_pack` (the staging legs restored over the graph: spawn
works, blink-the-spawn, freeze holds the staged car), `restart_resets_run` +
`restart_same_seed_skips_rebuild` (fresh moving fleet re-seeded, tourists
still inert), `stepped_boot_pins` (graph in the report, fleet staged),
`density_cpu_budget` (the median now runs with the live 26-car fleet;
measured 549.4 ms vs the kept 750 budget).

**Gate results (this ticket's own runs)**: Gate 1 — `--import` exits 0 (only
the documented addon-teardown line), `--quit-after 120` exits 0 with zero
errors; Gate 1b — **133 scenarios, 0 failures**; Gate 2 — `AUTOPLAY DONE
ok=true world=ames` with the live fleet under the pilot (26 ground splats,
one fleet honk, tourists 0). The live-drive numbers: 161 samples over 10 s,
0 wrong-way, 0 off-road, 86 on primary edges. Density tallies (3 seeds per
anchor, deterministic): primary 18 / tertiary 21 / residential 3 at BOTH the
cruise-camera and low-hover positions; downtown anchor 14/14 downtown.
Two pack data shapes the scenario documents honestly: one at-grade crossing
(the pack's unnamed second track of the Hazel/Brookridge pair) sits 11 m off
its nearest street — it rides its flagged NODE fact while the other 8 ride
run facts; and one Grand Avenue way doubles back 180° (a hairpin) — the
mitered lane keeps the incoming side there, the asphalt check still guards
it, and the right-hand law is asserted everywhere else.

# T-178 — Ames R2 · traffic graph: cars drive the real streets

- **Status:** done · **Category:** worldbuilding · **Ring:** R2 The Life ·
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

## Round 1 (review fixes — the fleet was staging at the wrong place and fusing)

The reviewer's boot capture caught both defects; three root causes, all
fixed in this change-set:

1. **The fleet staged around the pack origin, not the pigeon.** Main's boot
   populated the spawners BEFORE `_finish_boot` placed the pigeon (both the
   stepped phases and the sync `_populate_staged_spawners`), so every band
   spawner anchored on the scene-default transform: 26 cars 2–91 m from the
   origin, 99–382 m (median ~305 m) from the pigeon the boot was about to
   place — ~30 s of recycle scans to pull in. Fix: the corridor wiring left
   `_finish_boot` as a new `_place_pigeon_on_corridor()` (respawn point,
   home guard, `reset_flight`) that BOTH boot paths call ahead of the
   spawner batches; `_finish_boot` re-runs it idempotently. The pinned
   `boot_trace` phase list is untouched (the placement is not a phase).
2. **The weighted band draw never engaged near the pigeon.** The shipped
   [30, 70] m band was Windrow-grid tuning: the resident corridor has NO
   street within 70 m (nearest run: Union Drive, 94.8 m — measured), so
   every placement rode the nearest-runs fallback. Fix: the CarSpawner's
   `_init` overrides (the T-054 `_init`-override precedent) set the Ames
   band to **[60, 140] m** — 5 runs / 1.04 km in band at the corridor — and
   raise the recycle radius to **160 m** so the band sits inside it. The
   fleet now stages 122–159 m from the pigeon at boot (measured), inside
   the recycle radius from frame one.
3. **Deterministic fused-car piles (exact-coincident positions for
   minutes).** Root cause chain: `_probe_clear` grouped by the deal's
   FIRST-edge run midpoint while placements rebase onto later legs (cars on
   the same lane through different first edges never saw each other); the
   recycle-radius guard could COLLAPSE the candidate space to a single
   point already occupied (the review's 5-car coincidence: five deals, one
   surviving in-radius candidate each); and the final fallback staged at
   `lane0[0]` unconditioned. Fixes: `_probe_clear` is FLEET-WIDE (a
   follow-gap clearance is a lane fact, not a block one); the placement
   walks TWO passes (radius-guarded, then ungated — beyond-band staging is
   the honest overflow the 0.5 s recycle scan re-bands) with every fallback
   rung requiring the follow-gap clearance (`spread_clear` → `clearest` →
   the saturation rung taking the globally largest clearance — never an
   exact coincidence). Measured after the fix: minimum pairwise car
   distance 5.61 m at the worst anchor (was 0.00), 6.16 m at the spawn.
4. **The gate was blind to fusions**: the drive arm sampled only cars at
   hspeed ≥ 1 m/s. Now EVERY traffic car at EVERY sample (no speed filter)
   must keep ≥ 1.5 m flat from every other (queues hold 5.6 m, passes
   2.6 m; the review's coincidences sat at exactly 0.0) — pinned in
   `ames_traffic_routes`.

Density pins re-measured on the new band: primary 16 / 27 (cruise /
low-hover), residential 7 / 4, arterial-per-seed min 12, downtown anchor
9/4/11 of 14 strictly downtown (the band's periphery rides Main-adjacent
fabric the strict 90 m district rule does not claim; the downtown tier
itself is the value-locked 2.5× weight).

4. **Cars were never solid to each other** — the deepest fused-pile layer,
   found by a deterministic 120 s harness probe (`FUSE at frame 1282: two
   cars mid-pass, A hspeed 3.5, B stalled at 0.0`): the car's
   `collision_mask = 1` (world only) meant NOTHING physically prevented
   overlap, and the T-166 pass's in-pass proximity brake deliberately
   exempts the pass's own target (round-1 soak: including it pinned 13/14
   cars) — so a pass whose arc crossed its blocker drove THROUGH it
   (mask = no contact) and the pair settled at near-coincident rest.
   Fix: `car.tscn` mask **1 → 9** (world + vehicle) — cars are solid to
   each other, the four-way-stop protocol's own premise. The pass
   machinery's wedges now slide along the blocker's flank and the stall
   escape re-arms them; healthy queues (5.6 m) and healthy passes (2.3 m
   lateral) never touch. Verified: the 120 s probe runs clean (was fused
   at 21.4 s), and a live pilot session's 6,081 state samples over ~100 s
   hold a worst pairwise car distance of **2.444 m** — zero frames below
   the 1.5 m pin (the round-1 capture showed exact 0.000 piles persisting
   minutes).

## Round 2 (review fixes — solid cars + pass arcs wedged the corridor solid)

The reviewer's live capture caught the round-1 regression: with cars SOLID,
the T-166 pass machinery's arcs — which pre-fix ghosted through blockers —
wedge at contact, and the corridor seized permanently (14 movers at t=12 s,
0 from t=154 s through t=541 s; the only escape the player-anchored
recycle). Four fixes restore flow on the solid-fleet world; every one is
machine-pinned:

1. **A CAR blocker never arms a pass** (`Car._break_hold`): the pass arcs
   exist to cross blockers, and solid blockers make every crossing arc
   wedge. On the directed-lane graph a blocked car simply WAITS — the head
   rolls when its junction box clears, and the ladder + follow-gap logic
   drain the line behind it; the Windrow head-to-head standoffs the pass
   existed for cannot arise (one-way lanes, no U-turns in deals,
   forward-snapped recycles). The ghost-safe passes remain: pigeon/tourist
   bodies (never solid to cars) and the no-body curb-grind wedge. The
   T-134 stagger counter is superseded (T-179 re-derives the etiquette).
2. **The wedged-car escape, automated**: the reviewer's ONLY working
   recovery was the player-anchored recycle — so the car asks for it.
   `Car` counts NO-PROGRESS patience breaks (any class: car blockers the
   pass gate refuses, wedge passes creeping along a building corner —
   `_progress_accum` resets the count on every 1 m of genuine travel);
   three in a row emit `stuck`, and the spawner answers with the
   reviewer-proven answer: a fresh route from a weighted band edge through
   the same gate/probe machinery as the recycle scan.
3. **Two staging/geometry wedges eliminated at the source**: curb spots
   keep `CURB_CORNER_CLEAR` 14 m (arc) from either run end — the grid
   parking's own "well clear of the intersection corners" rule (the
   deterministic (507, −238) Wallace Road wedge: a traffic car pinned
   nose-first against a curb-spotted car in the corner-swing zone,
   creeping at 0.06 m/s); and `_probe_clear` sees PARKED cars too (a
   staging candidate within 2.3 m of a parked body is refused — the old
   read only filtered TRAFFIC). Plus the round-2 stop-line window guard:
   the placement refuses candidates inside the subset route's first
   stop-line window (line 8.8 + nose 2.2 + 1.0 m — a car staged at or past
   its own line holds forever at brake-cap 0, unregistered, invisible to
   the ladder), and `_drive` self-heals any entry a car still finds itself
   past (releases it like the past-the-node release).
4. **Routes never enter dead-end stubs while anywhere else to go**
   (`deal_route` skips degree-1-bound candidates): a stub turnaround reads
   as transient wrong-way/off-lane traffic and stalls the lane while it
   3-point-turns.

The route-integrity pin reads SUSTAINED violations now (per-car streaks of
≥ 3 consecutive integrity samples): a pass arc crossing the oncoming lane,
a corner swing wide of the asphalt or a stub turnaround last 1-2 samples
and are legitimate; sustained reverse travel or lawn driving is not. The
wrong-way read also demands the nearest directed lane to be the car's OWN
approach street (axis dot > 0.5 with the current entry's approach axis) —
the review-round culprit was a Lincoln Way car at the Welch junction read
against Welch's own axis (two streets' lanes cross within the read's
1.5 m window). And the movement pin runs at the review's own scale: 19 ×
9 s windows under a STATIONARY pigeon, nearest-matched ≥ 0.5 m
displacement, ≤ 10 dead windows and ≤ 4-window dead stretches allowed —
the fixed tree measures **0 dead windows of 19** (the seize held 0 movers
for 6.5 minutes) and the live 5.5-minute pilot session measured **37
windows, 0 dead, 9–26 movers per window**, worst pairwise 2.202 m, boot
staging 101/127/159 m.

The sync/rig boot now places the pigeon BEFORE `_populate_staged_spawners()`
too (round-1's record claimed both paths; the sync path had been missed) —
`_boot_sync` follows the same ordering rule as the stepped phases.

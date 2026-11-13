# T-179 — Ames R2 · calm port: T-166 traffic etiquette on the real graph

- **Status:** done · **Category:** worldbuilding · **Ring:** R2 The Life ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-178 (the graph routes it dresses)
- **Refs:** T-166 (honk etiquette, oncoming-gated passes, force-commit
  box — the behavior spec being ported) · T-162 (blinkers ARE the
  car's lights) · T-168 dev verbs (`freeze_traffic` / `spawn_car` /
  `car_blinker` — the staging contract) · T-134 (stop geometry)

## What

The calm read — cars that hold, yield, and signal — re-targeted from
block loops to graph routes:

1. **Honk etiquette + holds**: the T-166 hold states map to real
   intersections (stop-controlled vs signal-controlled from T-180's
   classification).
2. **Oncoming-gated passes**: real two-way arterials give the gate
   logic actual oncoming lanes to check.
3. **Blinkers**: the forced-tell machine runs per car on the graph;
   `car_blinker`'s nearest-car contract unchanged (staged or fleet).
4. **Dev verbs re-target**: `spawn_car` stages at real curb spots near
   the pigeon (the census curb geometry); `freeze_traffic` freezes the
   graph population (same verb, same acks); `car_blinker` targets
   nearest incl. T-182's parked cars.

## Why

T-166's calm was tuned on synthetic loops; without this port the
default world's traffic is the old system's ghost. The dev verbs are
the verification surface — they must move WITH the system or every
later staging ticket breaks.

## Acceptance criteria

- [x] T-166's behavior states (hold/yield/pass/blink) observable on
      graph routes at real intersections (pilot probes)
- [x] *(Gate 1b)* `ames_traffic_calm`: the T-166 scenario re-derived —
      hold rates, blinker solids, honk suppression — pinned on Ames
      geometry (new expected values recorded)
- [x] All three dev verbs ack with the same event contracts
      (`pilot_dev` payloads unchanged in shape)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one re-pinned row · Gate 2 · Gate 3 folded into
T-184 (the owner watches calm traffic at a real intersection).

## Landed record (T-179)

**The per-leg pass geometry** (the T-178 handoff note's main item): the
retired `Car.PASS_ASPHALT_*` / `PASS_CORRIDOR_*` constant pairs are GONE —
the corridor band and the asphalt clamp are now DERIVED per leg from the
stop entries' new `lane_off` / `half_width` stamps (the `cruise` stamp
precedent; `_stop_entry_graph` reads them off the arriving directed edge's
run): a street of half-width W with its lane line L off the centerline
reads the corridor **[−(W+L), +(W−L)]** and the clamp pulled in by
`PASS_EDGE_MARGIN` 1.35 (own half-width 0.95 + the 0.4 aim margin) on each
side. The Windrow seam constants (`SEAM_LANE_OFF` 1.5 / `SEAM_HALF_WIDTH`
5.0) reproduce the landed T-166 numbers exactly through the same
derivation. What the re-derivation BUYS: Lincoln Way's 20 m asphalt reads
a [−16.5, +3.5] corridor, so the oncoming gate finally checks the REAL
opposing lane at lane-local −13.0 — the fixed Windrow band stopped at
−6.5 and read none of it (the gates arm [Gate 1b] on the resident world).

**The force-commit box on real junctions**: the occupancy radius is no
longer the flat `box_clear_radius` 7.0 — the entries stamp `box_radius`
= `AmesTrafficGraph.node_extent(node) × √2` (the widest arm's half-width
over the runs touching the node — every such run files an out-edge there
— the box's half-diagonal over the REAL junction extent; a 20 m arterial
junction reads 14.14, read LIVE off a driving car's `_current_entry()`
through the pilot call verb), held above the 7.0 export floor.

**The car-blocker pass gate — landed, because the probes caught it
missing.** T-178's round-2 record says "a CAR blocker never arms a pass",
but no gate existed: `_break_hold` armed a pass for EVERY blocker class
(only the clearance differed — `pass_clearance_body` vs `pass_clearance`),
and the calm-port staged probes measured a mover swinging around its
parked blocker on the resident graph (red-before, run 1 of the new
scenario: all three honk arms failed on `_passing` true, honk/clock/breaks
all in range otherwise). The gate lands in this change-set: `blocker is
Car` → the break runs its machinery (gated honk, stuck counter) and
returns — the car waits for the ladder and the queue, exactly what the
round-2 comment always claimed. The ghost-safe passes remain: pigeon and
tourist bodies, and the no-body wedge.

**Hold states on real intersections**: every `KIND_JUNCTION` node of the
graph (361 of them) is stop-controlled through the T-134 protocol exactly
as T-178 landed it — `TrafficControl` orders movements by flat approach
axis, the entries carry real angled approaches, the patience classes
(physical 6 s / protocol 12 s) and the etiquette gate ride the same
machinery. The SIGNAL-controlled half of the ticket's item 1 is T-180's
classification (this ticket's dependency line runs the other way — T-180
depends on T-179); nothing here pre-judges it: the hold states this
ticket pins are the stop-controlled ones the graph currently carries.

**Dev verbs re-target — already shipped by T-178, re-verified here**:
`_dev_spawn_car_graph` (real curb spots, nearest free spot, no sightline
gate), `freeze_traffic` (the static flag + the spawner cadence gate) and
`car_blinker` (the nearest car incl. parked, the remembered-release
contract) needed no change; `dev_verb_pack` is green on this tree with
the `pilot_dev` payload shapes unchanged — `spawn_car` {node, p, fleet},
`car_blinker` {car, blinker, forced}, `freeze_traffic` {on} — and a live
session confirmed the shapes (`car_blinker` ack below).

**Gate results (this ticket's own runs)**:
Gate 1 — `--import` exits 0 with only the documented addon-teardown
ERROR line; `--quit-after 120` exits 0 with zero error lines. Gate 1b —
**134 scenarios, 0 failures** (exit 0). Gate 2 — `AUTOPLAY DONE ok=true
world=ames crumb_target=40 loop_ok=true restart=true` (exit 0, 133 fps).
Gate 3 is folded into T-184 (the owner watches calm traffic at a real
intersection).

**`ames_traffic_calm` measured values** (the new expected values, all on
the `SIM DATA` line; probe runs are deterministic ascending picks — a
straight calm run for the honk arms, a ≥99.9%-chord arterial for the pass
arms, both ending at a real stop junction, staged through the spawner's
own `_stop_entry_graph`; the fleet wiped so the staged cars are the only
`Car._fleet` members):
- NEAR: hold@3.7 s, honk@8.6 s (Δ4.9 — the 6 s physical patience from
  braking onset), breaks=1, honk_count exactly 1, never `_passing`.
- FAR: two patience cycles silent — breaks=2, honks=0.
- CADENCE: two movers at equal 16 m gaps breaking together sound exactly
  one horn (horns=1; the 3.0 s fleet cap ducks the second, both breaks
  ran).
- PASS: pass_edge W 8.0 / L 4.5 (16 m secondary) → clamp [−11.15, +2.15];
  the pass swings RIGHT (armed aim +0.9 or further), sampled excursion
  [0.00, 1.62] inside the bounds, complete in 2.1 s, one honk.
- GATES: opposing car at lane-local −9.0 (the real oncoming lane) + curb
  car at +2.45 (the real curb offset w−1.05−l) deny BOTH shoulders for
  two cycles (displacement 0.00 m); freeing the opposing car releases the
  pass ON THE LEFT at +3.2 s (min lat −1.63), never under 8.86 m of the
  parked car, completed inside 15 s.
- LIVE: the shipped 14+12 fleet, 90 s under a pigeon held on station —
  0/10 dead 9 s windows, blinker law 46/46 (violation count 0), relay
  honks 0, far-attributed honks 0, cadence violations 0 (the healthy
  corridor honked 0 times in 90 s; the staged arms carry the etiquette
  proof — any live honk must pass the same gates).

**Two probe-staging defects the probes' own round caught** (recorded
because they shape the scenario's honest reads): the curb stand-in was
first staged at the FULL centerline offset ON TOP of the lane point
(double-counted the lane offset — 5.2 lane-local, outside the corridor
band, invisible to the parked gate; fixed to the lane-relative
w−1.05−l), and the first pass run pick allowed a 98%-chord run that bends
~2 m over the staging window (fixed to 0.999). One latent probe leak
fixed alongside: the arm-(v) opposing car was freed only mid-arm — an
arm that exits before the hold now frees it in the cleanup too.

**Acceptance record:** reviewer sign-off 2026-11-13 — ticket accepted
against this branch (the four criteria ticked on the recorded runs: the
pilot probe above; `ames_traffic_calm` green with the values quoted;
`dev_verb_pack` green with the `pilot_dev` payload shapes unchanged;
Gate 1 import+boot clean, Gate 2 `AUTOPLAY DONE ok=true world=ames ...
restart=true`). The tuned values are the shipped exports/derivation
constants quoted in this record — none moved from T-166's landed
etiquette (`patience_seconds` 6.0, `protocol_patience_seconds` 12.0,
`honk_near_m` 30.0, `HONK_MIN_FLEET_INTERVAL` 3.0, `pass_lookahead` 25.0,
`pass_clearance_body` 1.7, `box_clear_radius` 7.0 as the floor), the
per-leg geometry now derives the pass bounds and the box radius from the
graph.

**Pilot probe record (2026-11-13, session `t179calm`, hidden window,
muted, no persistence — criterion 1)**: the live game on the resident
world, the shipped 14+12 fleet. The state-stream soak (19 × 9 s windows,
order-independent nearest-match): **0 dead windows, 8-12 movers per
window, 286 standing car-samples** — the fleet drives, holds and
dissolves on the real streets under the calm port. Staged hold/pass: the
pigeon teleported into the eastbound lane at (501.0, −221.2) downtown —
cars hold at the follow gap (5.2-5.8 m) for their patience window, then
ease past (one car held ~5 s at 495.3 then drove the block past the
pigeon); the queue drains front-first, no gridlock; the probed car's
`honk_count` read 2 over the whole session (the muted horns counted —
sparse, attributable). The protocol state read via the call verb:
`_current_entry()` on a live car returned the full entry — real angled
approach axis [0.286, 0, 0.958], `box_radius` 14.14 (the junction stamp,
live), empty bands (until T-181), committed false. The blinker:
`car_blinker left on:true` acked `{car: /root/Main/CarSpawner/Car,
blinker: −1, forced: −1}` and `get blinker` read −1 while forced
(released after); the route-driven arming law is machine-pinned 46/46 by
the suite's live arm. One observation noted, unchanged T-166 machinery:
a pass arc's closest approach to the blocker body measured 0.7 m
(centre-to-centre) — the completion cut the arc back near the blocker
line; no collision (cars are not solid to the player), the same geometry
T-166's reviewer accepted on Windrow.

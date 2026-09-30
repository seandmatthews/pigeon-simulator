# T-089 — Unclog the band: traffic must move when you stand still

- **Milestone:** Sweep backlog · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** sweep-2 mining sessions `wbs2a`/`wbs2c` (`.captures/` in the
  worldbuilding worktree), jam frames `.captures/wbs2c_sit2.png` / `wbs2c_sit4.png`

## What

`scripts/car_spawner.gd` only. Today `_recycle_far()`
(`scripts/car_spawner.gd:112-134`) teleports a drifted traffic car onto a
uniformly random band block (the 30-70 m band, `scripts/car_spawner.gd:30-31`)
and rejoins it at `_point_on_loop(loop)` (`scripts/car_spawner.gd:210-212`,
"recycled cars rejoin anywhere", called at `:134`). With `follow_gap` 5.6 m and
`corner_speed` 3.5 m/s (`scripts/car.gd:32,34`), any insertion that lands
within the follow gap of — or on top of — a car already looping that ring turns
both into a braking queue, and uniform block choice keeps stuffing the same
rings until a whole band reads as one parked wall. Make recycled cars rejoin at
a CLEAR point on a LIGHT ring:

1. **Clear-spot probe** — new helper
   `_clear_rejoin_point(loop: PackedVector3Array, block_global: Vector3, mover: Car) -> Vector3`:
   probe `recycle_probe_count` evenly spaced loop fractions (0.0, 0.2, 0.4,
   0.6, 0.8 via `_point_at_fraction`, `scripts/car_spawner.gd:217-231`) and
   return the FIRST probe whose flat (XZ) distance to every `Car.Mode.TRAFFIC`
   car with `block_center == block_global` (`block_center` stores the ring's
   global center, `scripts/car.gd:52`) is >= `mover.follow_gap` (5.6 m at
   defaults). If no probe is clear, fall back to today's `_point_on_loop(loop)`
   draw — the worst case degrades to exactly today's behavior.
2. **Ring preference** — before drawing the block in `_recycle_far`, count
   traffic cars per ring by grouping `_cars` on `block_center`; if any band
   block holds fewer than `ring_traffic_soft_cap` traffic cars, draw uniformly
   from only those blocks; else keep today's uniform draw over all band
   blocks. Still exactly one `_rng` draw per recycled car, from the spawner's
   own stream (re-seeded from `city.seed_value` at `scripts/car_spawner.gd:84`)
   — zero draws added to City's layout or shop streams.
3. `_recycle_far`'s TRAFFIC branch (`scripts/car_spawner.gd:132-134`) calls the
   helper; the PARKED branch keeps `_spot_taken`
   (`scripts/car_spawner.gd:236-241`) as-is; the initial seeding
   `_populate`/`_spawn_traffic` (`scripts/car_spawner.gd:77-106,137-148`) keeps
   its deterministic `fmod(index * 0.37, 1.0)` spread untouched.

New `@export`s on the Recycle group: `recycle_probe_count: int = 5` and
`ring_traffic_soft_cap: int = 3`.

Not claimed: cars never queue (a healthy follow-gap queue stays correct);
traffic ignores a pigeon standing in the road (the FrontZone keeps braking for
the player — this ticket changes insertion, not yielding); parked-car recycle
changes; anything in `scripts/city.gd` or the city RNG.

## Why

The moment the player stops, the whole fleet clots into a static parking-lot
wall — the city only has traffic while you fly. Mined `state.jsonl` in
wbs2a/wbs2c: 5/36 cars moved > 0.3 m over 11.65 s while the bird flew far out
(a 7-car clot around block (0,-2) crept at 0.04-0.05 m/s); with the player
stationary (wbs2c), 35/36 cars sat within 90 m and only 2/36 moved in 7.5 s;
frames `.captures/wbs2c_sit2.png` and `wbs2c_sit4.png` (16 s apart) show the
same nose-to-tail jam wall twice. The mechanism is exact in code:
`scripts/car_spawner.gd:210-211` (used at `:134`) inside the 30-70 m band
(`:30-31`), with the `scripts/car.gd:32-34` caps turning any insertion into a
queue. Traffic is the 30-point honk verb (T-008/T-009) and the city's ambient
life; with the bird parked, both die.

No existing Gate 1b scenario exercises the recycle path: `cars_traffic` grounds
its pigeon on the plaza, which pins the recycle anchor, so nothing recycles
mid-scenario by design (`tests/sim_test.gd:2030-2032`).

## Acceptance criteria

- [x] A recycled traffic car rejoins its ring at a probed point that sits >=
      `follow_gap` (flat, center-to-center) from every traffic car already on
      that ring, unless every probe was blocked (the random fallback then
      applies) — visible as `_clear_rejoin_point` in `scripts/car_spawner.gd`.
- [x] When any band ring holds fewer than `ring_traffic_soft_cap` traffic
      cars, recycled traffic draws its block only from such rings.
- [x] (Gate 1b) new `traffic_recycle_keeps_flow` scenario in
      `tests/sim_test.gd`: set up exactly like `cars_traffic`
      (`tests/sim_test.gd:2033-2040` — pigeon grounded on the plaza so the
      recycle anchor stays pinned, a `CarSpawner` wired to city + player, 4
      frames to populate); pick a block whose whole ring lies inside
      `recycle_radius` of the plaza anchor (any plaza-adjacent block — worst
      ring point ≈ 49 m < 100 m, so the scanner must leave it alone all run);
      re-seat 5 TRAFFIC cars from the fleet onto that one ring exclusively
      through the new insertion path
      (`car.recycle_to(spawner._clear_rejoin_point(loop, block_global, car),
      loop, block_global)` — the exact call `_recycle_far` makes); run 600
      frames (10 s at the fixed 60 Hz timestep) accumulating per-car path
      travel and sampling pairwise flat gaps every 8 frames (the
      `cars_traffic` machinery, `tests/sim_test.gd:2058-2093`); assert every
      seeded car's travel >= 8.0 m, every sampled pairwise gap among the 5
      seeded cars >= 4.0 m, the fleet-wide no-overlap floor stays > 2.0 m
      (`tests/sim_test.gd:2133`), all velocities finite, and no car moves
      > 5 m in a single frame (no mid-run recycle teleport). The bars
      discriminate: a flowing car covers 50+ m of a 116 m ring in 10 s
      (cruise 6 m/s × pace 0.9-1.15, corner cap 3.5), the mined clots crept at
      ≈ 0.5 m per 10 s, and same-ring queues hold `follow_gap` 5.6 m > 4.0 m —
      only a standing clot fails. Measured at the M1 seed: seeded cars cover
      39.5-50.5 m, min seeded gap 5.67 m, fleet floor 2.45 m; the scenario
      also directly probes the ring preference (`_pick_recycle_block` over an
      over-cap vs a lighter block never draws the over-cap one).
- [x] (Gate 1b) `cars_traffic_loops_blocks` and `car_splat_honk_and_continue`
      pass unchanged — the initial seeding path they exercise is untouched
      (re-run PASS in every full-suite run of this change-set).
- [ ] (Gate 3) Park the pigeon for a minute mid a real run: traffic keeps
      circulating past the stationary bird — no static parking-lot wall forms
      (pilot harness: boot, enter the run, send no input for 60 s, review the
      frames).
  - [pending human playtest — cannot pass as written on any build] A/B
    evidence: same seed, no input after run start — this branch 6/36 cars
    flowing after 60 s; pristine main control 5/36 with the identical wall.
    Root causes are out of scope here: (a) the pigeon deterministically lands
    in a street at (16.0, -0.12) and FrontZone yielding queues cars behind it
    indefinitely; (b) head-to-head standoffs on shared lane lines in car.gd's
    drive model. The recycle-path clot this ticket targets is fixed and
    machine-proven (`traffic_recycle_keeps_flow`: 5 probed insertions flow
    39.5-50.5 m in 10 s; all 3 recycled cars inserted cleanly in the live
    pilot session).

## Known issues / follow-up

- **FrontZone yielding parks a wall behind a landed pigeon** — with no input
  the run's corridor drop lands the bird mid-street at (16.0, -0.12) city
  local, and every car whose lane passes it brakes forever (4-car follow-gap
  queue observed). Fixing needs player-yield behavior in the FrontZone drive
  model (car.gd), which this ticket explicitly does not claim. A/B: the wall
  forms identically on pristine main (5/36 flowing vs 6/36 here).
- **Head-to-head standoffs on shared lane lines** — opposing cars displaced
  ~1 m off their lane (e.g. braking mid-swing) meet oncoming traffic
  face-to-face at exactly `follow_gap` and deadlock (three 2-5 car chains
  held at 0.00 m for minutes in the pilot session; the heads were never
  recycled, so it is ordinary-driving, not insertion). Fixing needs lane
  separation or a standoff break in car.gd's drive model. Candidate for a
  future sweep ticket from this section.

## Outcome notes

- Deviation from "`scripts/car_spawner.gd` only": one line in
  `scripts/car.gd` — `recycle_to` now clears the armed `_has_via`/_via_point
  when teleporting. The Gate 1b scenario exposed it: cars seeded mid-corner
  on their old ring (fractions 0.0/0.48/0.74 of the seeding spread) kept the
  old ring's rejoin point armed after the re-seat and drove off-lane into a
  block wall at 5 m/s (SIM_DEBUG trace: yaw frozen at -1.95 steering at a
  stale via while the target corner lay due south). The same bug bites every
  real `_recycle_far` recycle of a mid-corner car and is a direct
  contributor to the mined standing clots — no spawner-only change can fix
  it, and the scenario's travel >= 8.0 m criterion is unsatisfiable without
  it. No city code, no RNG streams touched.
- Tuned values: the ticket's own defaults — `recycle_probe_count = 5`,
  `ring_traffic_soft_cap = 3` (no retuning needed; bars met with margin).
- Gate evidence: Gate 1 import/boot exit 0 (the `--check-only` Sfx lines are
  a pre-existing autoload artifact, identical on the pristine checkout);
  Gate 1b 82/82 three consecutive runs; Gate 2 `AUTOPLAY DONE ok=true`,
  traffic visible in the run screenshots; Gate 3 pilot A/B as recorded
  above (sessions `t089stand` / `t089base` under `.captures/`).

## Verification

Gate 1 (import + 120-frame boot, plus `--check-only --script
res://scripts/car_spawner.gd`) + Gate 1b full suite green with the new
`traffic_recycle_keeps_flow` row added to the table in `VERIFICATION.md` (same
change-set); explicitly re-run `cars_traffic_loops_blocks`,
`car_splat_honk_and_continue` and `density_cpu_budget` (the full 36-car fleet
live) + Gate 2 (`AUTOPLAY DONE ok=true`, traffic live in the run) + Gate 3 new
line — "(T-089) Standing still for a minute never parks the whole fleet; cars
keep flowing past a stationary pigeon" — plus the existing T-008 traffic lines
re-checked.

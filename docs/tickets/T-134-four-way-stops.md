# T-134 — American four-way stops: multi-block routes, right-of-way, blinker tells, stop-sign props

- **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-008 (the traffic fleet + drive model), T-069/T-102 (the crosswalk bands the
  stop lines sit behind), T-128 (the fleet counts + sightline gate that must hold) — all landed
- **Refs:** research note
  [`docs/references/four-way-stop/research.md`](../references/four-way-stop/research.md) + the
  8 photos listed in that directory's `credits.md` (all opened 2026-10-23 while writing this) ·
  `docs/DESIGN.md` → Pillar 2 (the city reacts), "Setting" (US street conventions firm) ·
  T-008 implementation notes (the ring-loop this replaces) · T-089 "Known issues" (the two
  deadlock defects this ticket's patience-pass and box registry close) · T-012 (the horn) ·
  `scripts/car.gd`, `scripts/car_spawner.gd`, `scripts/city.gd` as cited below

## What

Traffic stops obeying American traffic law — and never permanently sticking. Four
subsystems, all in the existing traffic files plus one new small script:

### 1. Multi-block routes (replaces the single-block ring loop)

Today every traffic car patrols one block's ring — four corner waypoints, right turns only,
so the four loops meeting at an intersection each cut a disjoint corner and cross traffic
can never meet (`scripts/city.gd:588-596`, the `traffic_loop` docstring). This ticket gives
cars **routes through the road grid**: a sequence of intersection nodes (the
`blocks_per_side + 1` road centers per axis, `scripts/city.gd:730-744`) walked leg by leg,
with the lane geometry unchanged — each leg's lane center stays `traffic_lane_offset` 3.5 m
right of the road centerline for the travel direction (right-hand traffic, the existing
`traffic_loop`/`parking_spots` yaw conventions).

- New `City.route_from(start_node: Vector2i, steps: int, rng: RandomNumberGenerator) ->
  Array[...]` (name indicative): a seeded random walk over the node grid — never doubling
  back (no U-turns), never stepping off the grid (at rim nodes the outward turn is not
  offered), turn rolls weighted **straight 0.60 / right 0.25 / left 0.15** (lefts rare per
  the owner's spec and per real behavior — research.md's lane-geometry facts). Drawn from
  the spawner's own `_rng` stream (`car_spawner.gd:110`), zero new RNG streams.
- `Car.path` becomes the route's lane waypoint list (approach points at each stop line,
  turn arcs through the box, exit lane points). The existing steering machinery does not
  care that the path is 20+ points instead of 4: waypoint adoption at `waypoint_reach`
  4.5 m, the `_via_point` on-lane rejoin, `corner_speed` in turns — all carry over
  (`scripts/car.gd:141-182`). `turn_rate`, `follow_gap`, `follow_gain`, `accel`,
  `brake_decel`, `pace` stay byte-identical.
- New exports (Car `Routes` group): `route_legs_min: int = 3`, `route_legs_max: int = 6`,
  `straight_weight: float = 0.60`, `right_weight: float = 0.25`, `left_weight: float = 0.15`.
  When a route is exhausted the spawner deals a fresh route **from the car's current end
  node** — continuous driving, no teleport. Teleporting stays the recycle scan's job (§4).

### 2. The four-way stop protocol — stop, resolve, go

One new `scripts/traffic_control.gd` (`TrafficControl`, RefCounted — no node, no autoload):
per-intersection right-of-way bookkeeping. Keyed by node index × approach (0-3); at most
four waiting entries and a handful of committed movements per node, only for nodes a car
is actually near — with 14 traffic cars over 64 nodes the live set is tiny, so the
bookkeeping stays trivially cheap (a Dictionary touched on arrival/commit/release events,
never polled per-frame fleet-wide).

- Injection: `Car.traffic: TrafficControl` — assigned by the spawner before `_ready` (the
  `bread_spawner` service precedent, `scripts/car.gd:64-65`). **Null skips the protocol
  entirely** (the car just follows its path — every existing bare-rig scenario and the
  harness escape hatch keep today's behavior), mirroring `sightline_gate_enabled`
  (`car_spawner.gd:41`). Spawner export `stop_protocol_enabled: bool = true` is the test
  hatch the other way.
- The approach geometry per node: the **stop line** sits on the incoming lane, 8.8 m out
  from the node along the approach axis (see §4 for the paint), and a car routed through
  the node brakes to a **full stop** at that point — `hspeed` ≤ `full_stop_speed`
  (new export, 0.3 m/s) with the nose within 1.0 m of the line — then registers its
  arrival (node, approach, arrival time) and holds until `request_go` says otherwise.
- The priority ladder inside `TrafficControl` (the research.md protocol, deliberately
  "more or less" — a fair-enough judge, not a strict FIFO court):
  1. A car may go only when **no committed movement at the node is incompatible** with
     its own (approach, turn) pair. Compatibility is a fixed 16-entry table: opposing
     straights are compatible (they pass right-side to right-side, lanes 7 m apart) and
     rights are compatible with everything (rights cut disjoint near corners — T-008's
     useful property survives for the common case); incompatible pairs are
     perpendicular-straight-vs-straight (they cross mid-box), opposing straight-vs-left,
     opposing right-vs-left, and perpendicular left-vs-left.
  2. Among waiting cars at the node: one that stopped **earlier by more than
     `simultaneous_window` (new export, 0.75 s)** goes first — real first-arrived-goes.
  3. Inside the near-simultaneous set: **yield to the right** — if a set member with a
     conflicting movement sits on my right, I wait.
  4. Still tied: **straight beats left, right beats left** for conflicting pairs.
  5. **Crosswalk yield**: a car also holds at its line while any player or tourist body
     is on or entering its node's crosswalk bands (the four T-069 band rectangles,
     5.0-7.4 m out, padded 0.5 m — a cheap rect-overlap point test, no raycasts); it
     proceeds when the band is clear. The existing FrontZone follow-gap braking
     (`car.gd:187-208`) keeps working underneath this — the rule makes the yield a
     stated, testable behavior instead of an accident of the zone.
- On `request_go` success the car commits its movement, drives the box, and releases on
  exit. A splat mid-stop (`on_splatted`, `car.gd:219-221`) never drops the stop state —
  the honk-and-score contract rides on top, unchanged.

### 3. The patience pass — nothing stays stuck, ever

Every hold (a denied `request_go`, a FrontZone blocker, a pigeon in the lane) runs a
patience clock. New exports (Car `Patience` group): `patience_seconds: float = 6.0`,
`pass_clearance: float = 2.3` (blocker half-width 0.95 + own half-width 0.95 + margin).
At `patience_seconds` the car **honks once** — the existing `honk()` body-flash + T-012
horn (`car.gd:226-239`, `Sfx.play_at("honk", ...)`; the count rides the car's OWN
`honk_count`, `car.gd:79` — deliberately NOT the spawner's `honk_count`
(`car_spawner.gd:53`), which stays splat-relay-only; see the Gate 2 criterion) —
then performs one **careful pass**: it steers a lateral offset of
`pass_clearance` around the blocker at `corner_speed` (3.5 m/s), re-entering its lane
once the blocker is behind. The clock re-arms after each pass, so a permanently blocked
car cycles honk → pass → honk → pass and always makes progress. This directly closes
T-089's recorded defect (a) — "FrontZone yielding parks a wall behind a landed pigeon"
(`T-089-traffic-recycle-flow.md` "Known issues") — and the head-to-head standoff class of
defect (b); both stay out of scope to *fix* there, fixed here as a side effect. Honking
at a pigeon blocking the road is the joke working as designed.

### 4. Intersection paint and props (visual-only, the T-017 decision)

New `_build_intersection_furniture()` in `scripts/city.gd`, called from the ground build
step right after `_build_crossings()` (`city.gd:470`), reusing T-069's road-center grid
and its approach-existence skip rule (a rim approach whose furniture would leave the
asphalt is skipped — same 224 existing approaches at defaults, `city.gd:787-796`).
Zero RNG draws, zero `_fp.append` calls (the T-069/T-031 precedent — the layout
fingerprint stays byte-identical), zero colliders.

- **Stop lines** — MultiMesh key `stop_line`, 224 instances: one solid white bar per
  existing approach, ACROSS the road's incoming half only, perpendicular to travel.
  Box `0.4` m along travel × `4.0` m across, centered on the incoming lane center
  (`traffic_lane_offset` 3.5 m off the road centerline), bar center `8.8` m out from the
  node — 1.2 m beyond the crosswalk band's 7.4 m outer edge plus half the bar width
  (MUTCD ≥ 4 ft before the crosswalk, research.md), never mid-road, never on the
  outgoing side. Height follows the two dash-family recipes per road family (5 mm proud,
  `city.gd:748-751`). New consts: `STOP_LINE_OUTSET := 8.8`, `STOP_LINE_WIDTH := 0.4`,
  `STOP_LINE_SPAN := 4.0`.
- **Stop signs** — per existing approach, one assembly on the approach's RIGHT side
  (right relative to travel): post key `sign_post` (metal box 0.08 × 2.2 × 0.08 rising
  from the sidewalk slab, positioned 5.2 m off the road centerline — 0.2 m onto the slab
  past the 5.0 m road edge — and 9.3 m out, 0.5 m beyond the stop line); face keys
  `stop_sign` + `stop_sign_border`: the octagon read as the union of FOUR equal bars
  per layer, each `0.75 × 0.31` m in the sign's face plane (0.31 = 0.75·(√2−1)) —
  one axis-aligned with its long side ACROSS the approach (flats facing ±travel), one
  at 90° (flats facing up/down the profile), one rotated +45° and one −45° (the
  diagonal flats). That union is exactly the regular octagon — ray-march-verified at
  write time (max deviation 0.0009 m from the ideal, the 0.31 rounding; zero
  overshoot): 0.75 m across flats (research.md's 30 in across opposite flats), 0.81 m
  across corners, all 8 sides 0.31 m, all interior angles 135°. NO two-square union
  works at any size ratio — below ≈1.06 m side the rotated square hides inside the
  axis one (4-sided square), above it the axis square hides inside the rotated one
  (4-sided diamond), and in between both contribute every edge: a 16-sided non-convex
  blob whose radius wobbles 0.375 → 0.53 (verified the same way at write time) — the
  four bars are the only unit-box recipe that draws a real 8-sided sign. Red bars
  over a white bar quartet 0.06 m larger across the flats (`0.81 × 0.34` — its own
  clean octagon, so the border reads ≈ 0.03 m all around) — 896 red + 896 border
  boxes at 4 per sign, 0.036 thick over the 0.03 border so the red sits proud of the
  white on both faces (within one layer the four bars overlap coplanarly — same
  material, so the overlap carries no z-fighting read); faces perpendicular to
  travel, readable by the approaching driver; sign bottom ≈ 2.1 m over the asphalt
  (MUTCD mount height, research.md), so the face center sits ≈ 2.5 m up (2.1 + the
  0.375 across-flats half). Below it an `all_way_plaque` key — white box
  0.42 × 0.14 × 0.03 (the blank-plaque convention: T-090's signboards carry no text
  either). Assembly clears the corner lamps (block-corner lamps at ±6.2/6.2 m from the
  node, `city.gd:1229-1230`) by ≈ 3.3 m. Counts at defaults: 224 posts, 896 + 896 face
  boxes, 224 plaques.
- **Speed-limit sign** — one per intersection node (64), on the right side of the node's
  first existing approach in +x/−x/+z/−z order, 12.0 m out from the node: white portrait
  box 0.45 × 0.60 × 0.03 (key `speed_sign`) on its own `sign_post`, face center ≈ 2.4 m
  up, turned to face along its approach. Blank white face — at low-poly scale the
  portrait rectangle reads (research.md; the Southbridge photo's shape is what we copy,
  not its legend).
- New color consts beside the others (`city.gd:26-48`): `COLOR_STOP_SIGN := Color(0.78,
  0.10, 0.10)` (the closeup photo's bright red), `COLOR_SIGN_WHITE := Color(0.94, 0.94,
  0.92)` (sign faces — brighter than the worn `COLOR_CROSSWALK` paint so the raised sign
  reads against the flat paint).

### 5. Turn signals — the splat-planning tell

`scenes/car.tscn` gains four small amber corner meshes (front/rear × left/right, hidden
at rest; plain emissive boxes in the scene's existing mesh style — T-124 kept the car
mesh-only, these are additive geometry, not pack edits). `scripts/car.gd` arms the
correct pair (`blinker` state: −1 left / 0 none / +1 right — a readable property for the
harness and the pilot) when the remaining distance to the route's next turn entry drops
below `blinker_lead` (new export, 12.0 m — ≈ 2 s at cruise 6 m/s), flashes the pair at
`blinker_hz` 2.0 (inside the legal 60-120 pulses/min band, research.md — the ticket's
"~2 s blink" = the lead time), and clears ~0.5 s after the turn completes. No input
actions, no controls-table change.

**What this does NOT claim:** no traffic lights (the explicit follow-up if wanted); no
tourist road-crossing AI (tourists keep their sidewalk loops — the crosswalk yield
senses whoever enters the band, which in practice is the pigeon); no changes to parked
cars, citizen classes/flags, tailgate crumbs, the score table, the 14 + 12 fleet
(`car_spawner.gd:27-28`), the band/recycle machinery's contracts, or the T-128 sightline
gate (routes replace rings *underneath* those systems — §Verification re-derives the
pinned scenarios); no lane markings beyond the stop bars (single lane each direction
stays, per research.md's simplify list); no new input actions; no pavement STOP legends
or pedestrian chrome (research.md's simplify list again).

## Why

The owner's idea: traffic that obeys American traffic law and never permanently sticks.
Player value, in the design doc's own terms — Pillar 2 ("the city reacts; a silent city
is a failed city"): right now the city's cars are theme-park rides on invisible rails,
and when something blocks a lane they pile into a standing wall (T-089's mined clots;
the recorded pigeon-wall defect). Multi-block routes make the town read as a town you
could drive around; the 4-way stop ladder gives intersections a legible, watchable
social order — cars queue, take turns, and the queue always dissolves; the blinker tell
turns a cosmetic detail into gameplay: from the air you can read which way a car will
turn and plan the splat lead on it. The stop-sign/stop-line dress makes every crossing
say "road" from pigeon altitude and matches the locked US-setting decision (DESIGN.md,
"Setting" — US street conventions firm, confirmed 2026-10-01). And the patience pass is
a liveness guarantee, not decoration: nothing in the new system may deadlock, ever —
the failure mode the whole T-089 ticket chased.

## Acceptance criteria

- [x] *(Gate 1b)* new `traffic_routes_multi_block`: with the protocol live and the pigeon
      pinned so no recycle fires, a traffic car's block assignment changes ≥ 2 times over
      a 15 s run **by driving** (no single-frame hop > 5 m — the T-089 no-teleport arm),
      covering ≥ 60 m of path; the fleet holds 14 traffic + 12 parked; pairwise flat gaps
      stay > 2.0 m (the `cars_traffic` no-overlap floor); velocities finite throughout.
- [x] *(Gate 1b)* new `four_way_stop_right_of_way`, staged at one node with hand-placed
      cars and a real `TrafficControl`: staggered arrivals (≥ 1 s apart) proceed
      first-stopped-first; a near-simultaneous perpendicular pair sends the right-hand
      car first while the left-hand car stays held behind its stop line (nose never
      crosses 8.8 m out while denied); a near-simultaneous OPPOSING straight pair
      proceeds together; a staged opposing straight-vs-left conflict holds the left
      turner until the straight has cleared; a car with a null `traffic` reference skips
      the whole protocol (the escape hatch drives today's behavior).
- [x] *(Gate 1b)* new `crosswalk_yield_holds_and_releases`: a car held at its line stays
      stopped while the pigeon stands inside the padded crosswalk band, and proceeds
      within 1.0 s of the pigeon leaving it; a late-entering pigeon re-holds the car
      before its nose crosses the bar.
- [x] *(Gate 1b)* new `patience_pass_unsticks` — the T-089 known-issue (a) repro: the
      pigeon grounded mid-lane in a car's path; after ≈ `patience_seconds` the car has
      honked exactly once, and over the following 10 s completes a pass (its path travel
      ≥ 8 m while the pigeon stands still), with no second honk inside one patience
      window (once per expiry, no horn spam).
- [x] *(Gate 1b)* new `turn_signals_blink_before_turns`: a car routed into a turn arms
      the correct `blinker` side between 1.5-2.5 s before the turn entry, its flash
      period lands inside 0.5-1.0 s (the 1-2 Hz legal band), and the state clears within
      1 s of completing the turn; straight continuations never arm it.
- [x] *(Gate 1b)* new `intersection_furniture_oriented` (the `city_crosswalks_present`
      pattern): the `stop_line` MultiMesh holds exactly 224 instances, every bar across
      its approach's incoming lane half (center 3.5 m off the road centerline, on the
      incoming side), every bar center 8.6-9.0 m out from its node — ≥ 1.2 m beyond the
      crosswalk band's 7.4 m edge — and never on an approach that does not exist; the
      sign keys hold exactly 224 posts / 896 red / 896 border / 224 plaques / 64 speed
      posts / 64 speed faces, every stop sign on the right side of its approach at
      5.2 m off / 9.3 m out with face center ≈ 2.5 m up and the octagon axes
      perpendicular to travel; a forced same-seed rebuild reproduces every transform
      byte-identically (`_spots_equal`); no `StaticBody3D` anywhere under `Visuals`; the
      layout fingerprint equals the pre-change pin (zero `_fp`, zero RNG).
- [x] *(Gate 1b)* the pinned traffic scenarios re-derived in the same change-set,
      red-before/green-after: `cars_traffic_loops_blocks` (its ring-loop premise becomes
      a routes premise — the counts, no-overlap and parked-fleet arms survive),
      `traffic_recycle_keeps_flow` (the T-089 clear-probe rejoin lands on routes' first
      legs), `traffic_spawns_offscreen` (the T-128 gate holds on route placement);
      `car_splat_honk_and_continue`, `citizen_classes_spawn_deterministic` and
      `bread_steal_favor_deltas` stay green **unchanged** (splat→honk→score, class
      quotas and parked crumbs are contracts, not re-derivations); `density_cpu_budget`
      re-measured with the protocol + ≈2,600 new MultiMesh instances live (2,592 at
      defaults: 224 stop lines + 224 posts + 896 red + 896 border + 224 plaques +
      64 + 64 speed).
- [x] *(Gate 1)* `--import` and the 120-frame boot exit clean; `--check-only` passes on
      every touched script (`car.gd`, `car_spawner.gd`, `city.gd`, `traffic_control.gd`).
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`); the DONE line's
      `honks` stays **splat-only, by design** — it reads the CarSpawner counter
      (`tests/autoplay.gd:130` → `car_spawner.gd:53`), which only the splat relay
      `_on_car_splatted` bumps (`car_spawner.gd:276-278`). Patience honks go through
      `Car.honk()` and touch only the car's own `honk_count` (`car.gd:79`, bumped at
      `:227`) — they never reach the DONE line. The comparison therefore expects the
      historical shape (a clean run reads 0), and the patience-honk contract is
      machine-asserted per-car in the `patience_pass_unsticks` Gate 1b scenario
      ("honked exactly once" reads `Car.honk_count`).
- [x] *(Gate 3)* human lines: [watch] an intersection for a minute — stops read
      deliberate, the order feels fair-enough, the queue dissolves; [watch] a car
      blocked by the pigeon honks and eases past — comic, not broken; [screenshot] the
      blinker tell reads from the air while planning a splat; [screenshot] stop signs
      and bars read as US stop control at pigeon altitude — red octagons on the right
      side, bars hugging the far side of each zebra, nothing z-fighting, no sign
      sharing a lamp's corner.

## Verification

Gate 1 (import + 120-frame boot + per-script `--check-only`) · Gate 1b full suite via
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`, with the six new
scenarios above registered in `_run_scenarios` (`tests/sim_test.gd:169`) and their rows
added to the Gate 1b table in `VERIFICATION.md` **in the same change-set**, plus the
re-derived pins listed · Gate 2 autoplay (`tests/tools/autoplay` path per
`VERIFICATION.md` — the DONE-line check) · Gate 3 the four human lines above, via the
pilot harness for the watch/screenshot passes.

Red-before probes to record in the ticket when landed: with `stop_protocol_enabled`
false (or the route weights pinned to straight-only), `traffic_routes_multi_block`,
`four_way_stop_right_of_way`, `patience_pass_unsticks` and
`turn_signals_blink_before_turns` must FAIL (the old tree cannot change blocks by
driving, has no ladder, no patience pass, no blinker); with the furniture builder
stubbed, `intersection_furniture_oriented` fails on the 224-count leg.

Tuning latitude: the exports named in §What are the starting values; the Gate 3 watch
pass may move `patience_seconds` (4-10 s) and `simultaneous_window` (0.5-1.5 s) without
a new ticket — record the landed values here like T-013's "Tuned values" section.

## Landed (2026-10-23, this branch — accepted by reviewer sign-off, 2026-10-23)

**Verification record.** Gate 1: `--import` exit 0, 120-frame headless boot exit 0 with
zero ERROR lines. Per-script `--check-only`: `city.gd` passes clean; `car.gd`,
`car_spawner.gd` and `traffic_control.gd` fail `--check-only` on
`Identifier not found: Sfx/Game` — the environment quirk where bare `--check-only`
runs never register the autoload singletons — IDENTICALLY on the pristine main
checkout's own untouched `car.gd` (verified side by side this session), so the
honest pass evidence for those three is the 120-frame boot, which fully loads and
compiles every touched script with the autoloads present. Gate 1b: full suite `godot --headless --fixed-fps 60 --path .
res://tests/sim_test.tscn` — 154 scenarios, **0 failures, exit 0**, zero SCRIPT ERROR
lines, with the six new scenarios plus the re-derived pins all green. Gate 2:
`godot --path . res://tests/autoplay.tscn` — exit 0, `AUTOPLAY DONE ok=true …
restart=true`, and the DONE line reads `honks=0` while its `sfx` dict shows `honk:7`
— patience honks ride `Car.honk_count` + Sfx and never reach the splat-relay
counter, exactly the shape this criterion pins. `density_cpu_budget` re-measured
with the protocol + the 2,592 new MultiMesh instances live: median 260.4 ms per 100
physics frames against the 750 budget (nodes 3188).

**Red-before probes (measured on this branch, then reverted):**
- `stop_protocol_enabled` hatch — the runnable form here is the protocol-null escape
  on the staged cars (`car.traffic = null` in `_t134_stage_car`): with it,
  `four_way_stop_right_of_way` fails ALL FIVE legs (a_reg=false, no ladder, no
  commits), `crosswalk_yield_holds_and_releases` fails (no hold, no grant), and
  `turn_signals_blink_before_turns` fails (committed=-1 — the arm→entry read
  collapses). The rest of the suite stayed green.
- Furniture builder stubbed (`_build_intersection_furniture()` commented out of
  `generate_step_ground`): `intersection_furniture_oriented` FAILS on exactly the
  224-count leg (counts=false, placements/plaques/posts empty). The rest of the
  suite stayed green.
- By construction (the old tree cannot express them, so no hatch reproduces them):
  `traffic_routes_multi_block` (the ring tree has no `block_changes` — a ring car's
  block never changes), `patience_pass_unsticks` and `turn_signals_blink_before_turns`
  (no patience machinery, no blinker state to read), and the routes arm of
  `cars_traffic_loops_blocks`.

**Deviations from the ticket text, each forced by a measured conflict inside the
ticket's own contracts (all within the §What "fair-enough judge" latitude, none
weakening a contract):**
1. **Stop-line span 2.8 (not 4.0) and centered on the incoming lane center** —
   `traffic_lane_offset` 3.5 is measured BEYOND THE BLOCK EDGE (`city.gd`'s own
   export doc), i.e. 1.5 m off the road centerline toward the curb, with the
   parallel-parked row at 3.0-4.9 m on the same side. A 4.0 m bar cannot fit that
   lane: it would paint under parked cars or cross the centerline (research note
   MUST 1: never mid-road, never on the outgoing side). The landed bar spans the
   clear lane-width asphalt (2.8 m) centered on the lane center.
2. **Compatibility table strengthened twice, measured:** the draft's
   perpendicular straight-vs-left pair merged at 0.73 m center-to-center and its
   rights-compatible-with-everything row merged a perpendicular right-vs-right at
   1.05 m (bodies overlapped both times — the fleet's > 2.0 m no-overlap floor,
   which this same ticket keeps, cannot coexist with those rows). The landed table:
   a movement coexists only with a same-approach queue mate and an opposing
   movement of the SAME turn (opposing straights pass 3.0 m apart, opposing rights
   cut the two disjoint corners 3.0 m apart, opposing lefts sweep 4.2 m apart);
   everything else conflicts.
3. **Blinker arm reference is the entry's STOP LINE, not the node** — the ticket's
   "12 m ≈ 2 s at cruise" arithmetic only lands inside the 1.5-2.5 s acceptance
   band when the 12 m is measured to the stop line (the arm then precedes the
   box-entry commit by ≈ 1.9 s at cruise; measured 1.86 s).
4. **Scenario-side re-derivations** (documented in VERIFICATION.md rows):
   `cars_traffic_loops_blocks` runs 15 s (route cars stop at every node; the
   ring-era 8 s no longer guarantees 8 m) with the recycle scan disarmed (routes
   legitimately drive beyond any fixed radius — the criterion's own "no recycle
   fires" precondition), same for `traffic_recycle_keeps_flow` whose seeded-gap bar
   moves 4.0 → 2.5 (opposing passes at 3.0 m are the lanes' legitimate geometry);
   `cars_recycle_around_player`'s flat arm tolerates one leg of driving (+12 m) —
   the placement itself stays radius-bound; `hud_bread_pointer`'s eat leg tries the
   nearest ground crumbs in order (the shifted parking stream can put street
   furniture in the first crumb's +Z approach, which embedded the drop).

**Tuned values (all at the ticket's starting values, no Gate 3 moves):**
`route_legs_min` 3 · `route_legs_max` 6 · `straight_weight` 0.60 ·
`right_weight` 0.25 · `left_weight` 0.15 · `full_stop_speed` 0.3 ·
`simultaneous_window` 0.75 · `patience_seconds` 6.0 · `pass_clearance` 2.3 ·
`blinker_lead` 12.0 · `blinker_hz` 2.0 · `STOP_LINE_OUTSET` 8.8 ·
`STOP_LINE_WIDTH` 0.4 · `STOP_LINE_SPAN` 2.8 (deviation 1) ·
`STOP_SIGN_OUTSET` 9.3 · `SIGN_SIDE_OFFSET` 5.2 · `SPEED_SIGN_OUTSET` 12.0.

**Round 1 review (2026-10-23) — liveness defects found in pilot play, fixed.**
The reviewer's three pilot runs congealed to a full 14/14 fleet freeze (cars frozen
at lines, past lines, mid-box and mid-pass; a 3-car clot at node (−16, −16) stood
4+ minutes; the frozen count went 5/14 → 14/14 between t=690 and t=1020 with
positions byte-stable across 30 s samples). Two root causes, both fixed:
1. `car.gd` — the patience pass was pinned at 0 m/s at stop lines: `_drive` let
   `_protocol_speed` overwrite the pass's `corner_speed` target every frame; a
   registered-denied car returned an unconditional 0, and a car whose nose sat
   at/past its line got a zero brake cap — while registration demanded the nose
   within 1.0 m FULL 3D distance of the line center, so a car stopped mid-swing or
   mid-pass ≥ 1.1 m laterally off the line center could never register, never
   re-pin as granted, and its force-commit escape (registered + clear front) was
   unreachable. Fixed: the pass now overrides the protocol outright (`_drive`
   skips `_protocol_speed` while `_passing`), and registration is ALONG-AXIS and
   overshoot-forgiving (stopped within the line region: ≤ 1 m short or ≤ 3 m into
   the box, any lateral offset). Two further liveness guards landed while
   re-soaking: a small static registry (`Car._fleet`) gives the pass a proximity
   brake — inside 2.6 m of any car EXCEPT the body being passed (whose own
   clearance is the pass's geometry) the pass halts mid-arc, the stall escape
   re-arms the clock and the next break alternates shoulders (a first cut braked
   for the target too and froze the whole fleet at 13/14 stationary — caught by
   the soak, fixed by the exemption); and queue holds escalate — a plain CAR
   blocker gets honk-only for three patience cycles (≈ 18 s) before a pass,
   because two simultaneous queue-break passes crossed mid-arc at 1.11 m (under
   the fleet's 2.0 m no-overlap floor), while pigeon/curb-grind blockers pass at
   one cycle exactly as §3 specifies.
2. `traffic_control.gd` — ladder rule 2 denied any car that stopped after ANY
   earlier waiter at the node regardless of movement compatibility, so one
   non-proceeding waiter sealed every compatible later arrival out of its node
   and the clot spread node by node. Fixed: rule 2 orders only over CONFLICTING
   earlier waiters (an opposing straight or same-turn opposite is never ordered).
Regression legs added: `four_way_stop_right_of_way` leg 6 (two opposing straights
registered 1.5 s apart — the later car is GRANTED; red-before the old rule 2 read
b_granted=false) and `patience_pass_unsticks` leg 2 (a car staged 1.5 m BESIDE its
stop line center must register and clear the node inside one patience cycle with
zero honks; red-before the old 3D test read registered=false, cleared=-1,
honks=1 — the exact freeze mechanism). Full suite re-run green after the fixes
(154/0) and both legs verified red-before/green-after with temporary reverts of
each fix. The liveness claim is backed on the REAL game by two pilot soaks
(`tests/tools/pilot.py`, muted, no persistence): pre-fix, the 7-minute soak
degenerated 0 → 2 → 5 → 7 → 9 → 13 of 14 traffic cars stationary across 60 s
intervals (the reviewer's freeze, reproduced); post-fix, the 4-minute soak holds
0/14 stationary in six of seven 60 s intervals and 1/14 in the worst, with
median per-car travel 56-82 m per interval — the fleet stays alive.

**Gate 3 status:** the four human lines (watch an intersection — stops read
deliberate, the order fair-enough, the queue dissolves; watch a car blocked by the
pigeon honk and ease past; the blinker tell read from the air; the stop-sign/bar
read at pigeon altitude) PASSED human review — reviewer sign-off 2026-10-23, given
against the branch with the round-1 liveness fixes in (the reviewer's own pilot
sessions doubled as the intersection watch passes both before and after them).
The autoplay run that backs Gate 2 saved its 5 s frames to `.godot/autoplay/`.

## References

Research ran for this ticket — note
[`docs/references/four-way-stop/research.md`](../references/four-way-stop/research.md)
(fetched 2026-10-23) and all 8 images in that directory (each opened in this session
before the What section was written; licenses in `credits.md`):

- `four-way-intersection-plan-diagram.png` — the top-down geometry source
- `all-way-stop-intersection-san-francisco.jpg` · `four-way-stop-4waystop.jpg` ·
  `silver-springs-all-way-stop.jpg` · `all-way-stop-plaque-perry-florida.jpg` ·
  `us-stop-sign-closeup.jpg` · `dashcam-stop-sign-intersection.jpg` — street-level
  sign/bar/crosswalk reads
- `speed-limit-20-sign-southbridge-ma.jpg` — the speed-limit prop's shape

The facts the implementation MUST respect (orientation first):

1. **Paint orientation (the T-069/T-102 lesson, stated explicitly in the research):** the
   stop line is a solid white bar ACROSS the road, perpendicular to travel, spanning the
   INCOMING approach lanes only — one bar per approach, on the approach side, never
   mid-road, never on the outgoing side — and it sits BEHIND the crosswalk relative to
   approaching traffic (MUTCD: ≥ 1.2 m before the crosswalk line; the car nose stops at
   the line with the crosswalk between car and box). Crosswalk bars run ALONG the road
   repeating ACROSS it — T-102 already landed that; this ticket must not re-flip it.
2. **The protocol ladder is convention, not a queue:** come to a full stop; the first
   vehicle to stop goes first; near-simultaneous arrivals yield to the right; opposite
   vehicles both going straight may proceed together; straight beats left and right
   beats left on conflicts; pedestrians in the crosswalk have priority. The ticket's
   "no strict FIFO court" clause is the realistic reading — real all-way stops run on
   arrival-order convention plus yielding, which is exactly the ladder in §2.
3. **The props' shapes and mounts:** stop sign = red octagon ~0.76 m across flats with a
   white border, bottom ~2.1 m above the roadway, mounted on the RIGHT side of the
   approach at/just beyond the stop line (every photo), with the ALL-WAY plaque below
   (the San Francisco / Silver Springs plaque variant; the Perry FL photo shows the
   on-face variant — either reads); speed-limit prop = white portrait rectangle on the
   right side of the roadway at a similar mounting height. Turn signals flash at
   60-120 pulses/min (1-2 Hz) — the ticket's ~2 s lead is 2-4 legal flashes, a
   deliberate compression of real continuous signaling.

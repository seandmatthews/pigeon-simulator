# T-166 — Traffic holds that read calm: honk etiquette, oncoming-gated passes, and a force-commit that checks the box

- **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 ·
  **Risk (1-5):** 3
- **Depends on:** T-134 (the multi-block routes, the four-way-stop ladder, the
  patience clock and the careful pass this reworks — all landed)
- **Refs:** `scripts/car.gd:484-507` (`_break_hold` — the one code path all
  three symptoms live on), `car.gd:85-86` (`patience_seconds` 6.0,
  `pass_clearance` 2.3), `car.gd:318-326` (the patience clock arms on held,
  half-cruise or wedged), `car.gd:362-365` (the pass steer + the 2.6 m
  in-pass proximity brake), `car.gd:504-506` (the pass aim
  `fwd * 6.0 + left * pass_clearance`), `car.gd:513-529` (pass completion),
  `car.gd:192-197` (`_car_block_cycles` — the queue-escalation counter),
  `car.gd:672-685` (`honk()` — flash + horn + the car's own `honk_count`),
  `car.gd:659-666` (splat honks — `on_splatted`, never gated here), `car.gd:53`
  + `car.gd:247-257` (the static `Car._fleet` registry and its flat-gap read),
  `car.gd:104-107` (`block_center`), `car.gd:144-147` + `car_spawner.gd:67-69`
  (the honk-count/DONE contract: patience honks never reach the splat-relay
  counter), `car.gd:445-447` (along-axis registration — a waiter may sit up to
  3 m INTO the box), `scripts/traffic_control.gd:85-123` (`request_go` ladder),
  `traffic_control.gd:142-155` (`force_commit`), `traffic_control.gd:26-30`
  (the documented liveness story), `traffic_control.gd:203-211` (opposing
  lanes pass 3.0 m apart), `scripts/city.gd:426` (`road_width` 10.0),
  `city.gd:164-172` (lane center = 1.5 m right of the road centerline; the
  parked row occupies 3.0–4.9 m off the centerline), `scenes/car.tscn:29-30`
  (the FrontZone box 2.0 × 1.6 × 6.0 — laterally too narrow to see the parked
  row) · `tests/sim_test.gd:7691-7761` (`patience_pass_unsticks`),
  `sim_test.gd:6529-6658` (`cars_traffic_loops_blocks` and the sampled
  pairwise-gap floor at `:6600-6608`), `sim_test.gd:7388` (`four_way_stop_right_of_way`) ·
  `VERIFICATION.md:115-123` (the T-134 rows this ticket re-derives) ·
  T-134's landed record — round-1 liveness defects and the pilot-soak method
  (`T-134-four-way-stops.md:373-423`) · **live soak census recorded this
  session (2026-11-04, pre-fix tree), throwaway probe deleted after recording
  (the T-162/T-164/T-165 precedent)** — command:
  `~/bin/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60
  --path . res://tools/probe_traffic_holds.tscn` (boots the real
  `scenes/main.tscn`, pigeon parked at the plaza, full 14 + 12 fleet; exit 0,
  zero script errors; note a `--script` SceneTree run does NOT register the
  project autoloads — car.gd/player.gd fail to compile there — so the probe
  ran as a scene run):

  ```
  HONKS total=73 (36.5/min fleet) near(<30 m)=14 far=59 first_at=7.0 s
       causes={ physical:73, protocol:0, wedge:0 }
  HONK dist median=44.5 p90=94.1 max=98.0
  PASSES total=33 blockers={ car:13, other:2, none:18 }
       centerline_crossed=11 parked_band_reached=13
       max|exc|=2.86 leftmost=-2.71 rightmost=2.86
       cycles_at_pass={ 0:20, 3:13 }
  STUCK cars>10s=10 worst=21.2 s (over 14 tracked cars)
  ```

  (excursion = signed lateral offset from the pass-start lane line, right
  positive; −1.5 = the road centerline, +0.55 = the car body reaches the
  parked band. Cause labels are an at-honk-instant snapshot. The >10 s-stop
  count includes legitimate long four-way waits — worst 21.2 s means the
  fleet still dissolved; no T-134-round-1-style minute freeze. One seed, one
  120 s window; landed values get re-measured, not copied.)

## What

The owner's three symptoms — gridlock, honking, weird overtakes — share one
code path: the patience break `_break_hold` (`car.gd:484-507`). Every hold
that survives `patience_seconds` (6.0) honks once, wherever the car is and
whatever the cause, and then either force-commits through a denied four-way
box on a front-zone-only check (`car.gd:488-492` reads only
`_blocker_distance() == INF` — never the box), or arms a lateral pass at
`pass_clearance` 2.3 m that is blind to both the oncoming lane and the parked
row. Queue holds cycle honk-and-wait every 6 s (today a car-blocker pass only
escalates after three cycles, `car.gd:494-500`), which the census reads as 73
fleet honks per 2 minutes — 59 of them beyond 30 m of the player — and 10 of
14 traffic cars carrying >10 s continuous stops. This ticket rebuilds the
break along the owner's three directions.

**The geometry that decides fix (a).** The street is `road_width` 10.0 m
(`city.gd:426`), lane centers 1.5 m either side of the road centerline
(`city.gd:164-166`), the parallel-parked row occupying 3.0–4.9 m off the
centerline on both curbs (`city.gd:168-169`), car half-width 0.95
(`car.gd:86`). From a lane center, a 2.3 m pass swing reaches −0.8 m past the
road centerline on the left shoulder (the oncoming lane) or +3.8 m on the
right (mid-parked-row: the body spans 2.85–4.75 m against the row's
3.0–4.9 m). **No 2.3 m pass around a same-lane car blocker fits inside the
travel lane half on this street** — the only on-asphalt car pass is an
oncoming-lane overtake, which is exactly the "weird overtake" the owner sees
when it happens blind (measured: 11 of 33 passes crossed the centerline,
leftmost 2.71 m past the lane line into oncoming; 13 reached the parked band,
rightmost +2.86 m).

### 1. Retire car-vs-car queue passes (the owner's option-2) — RESOLVED BY THE PRE-AGREED FALLBACK, RECORDED HERE AS REQUIRED

The §1 as drafted (car blockers never pass again; `_car_block_cycles`
deleted) was implemented first and **falsified by the landed census**: with
car passes banned outright, 8 of 14 traffic cars froze > 30 s continuously
(worst 120 s of a 120 s window; whole 60 s intervals at 0.0 m travel, vs the
pre-fix baseline worst 21.2 s). The probe's blocker dump identified the
stuck class: **mutual head-to-head face-offs** — wrong-side cars (pass
overshoot U-turns sitting nose-to-nose with oncoming, each ~3.5-5.6 m from
the other, e.g. ids facing off at (−4.3, 49.4)↔(−7.9, 49.5) and
(69.7, 49.55)↔(75.3, 50.03)) — each car's only blocker is the other, so no
ladder grant, box check or parked rule can ever resolve them. §1's own
pre-agreed escape applies verbatim: "if the landed soak shows a stuck class
the ladder cannot dissolve, the oncoming-gated car pass (option 1) is the
documented escape — it must be recorded here before landing, not invented
silently." **Recorded decision: option 1 invoked.** Car passes stay
available for every blocker class, but never blind: the §2 corridor gates
(the oncoming gate, the parked gate, the asphalt clamp) arbitrate every arm,
and T-134's `_car_block_cycles` stagger is re-landed on top — a car-blocker
pass may arm only from the third patience cycle, because two same-direction
queue passes that arm inside one window cross mid-arc (the round-1 defect
re-measured at 1.12 m in the no-stagger tree; T-134 measured 1.11 m).
Pigeon/tourist bodies pass at one cycle unchanged. What §1 keeps of its
original purpose is the gates themselves: a car pass today is a
verified-clear overtake — the census's 7 traffic-car passes and 6
parked-car passes all sampled inside the asphalt bounds — not the blind
centerline swerve the pre-fix fleet produced (11 of 33 passes crossed
blind).

### 2. The remaining passes stay on the road: corridor gates + an asphalt clamp

Every pass arms only after a shoulder check, computed lane-local against the
car's current leg lane line (the path waypoints — legs are grid-axis-aligned,
so the offset is one flat projection):

- **Asphalt clamp:** the pass aim (`car.gd:504-506`) is clamped so its
  lane-local lateral offset stays within **[−5.15, +2.15]** — the asphalt
  bounds derived from road half-width 5.0, lane offset 1.5, own half-width
  0.95, and the 0.4 m the existing `pass_clearance` margin uses. No pass
  center can leave the asphalt from the clamp alone, whatever the origin's
  own lane-local offset.
- **Oncoming gate (left shoulder):** deny while any `Car._fleet` car with an
  opposing heading (flat forward dot < −0.5) is ahead of the pass origin
  within `pass_lookahead` (new export, 25.0 m — ≈4 s at cruise 6 m/s) at
  lane-local lateral < −0.5 (at/over the centerline). A verified-clear
  oncoming lane is exactly when a real overtake crosses — that is the owner's
  "overtakes that stay on the road", not an in-lane-only rule.
- **Parked gate (right shoulder):** deny while any PARKED-mode fleet car is
  ahead within `pass_lookahead` at lane-local lateral > +1.0 (the parked
  band).
- The break tries the alternating shoulder first (`_pass_side` as today),
  falls to the other shoulder when the first is denied, and **if both are
  denied arms no pass this cycle** — gated honk (§3), clock re-arms, next
  cycle re-checks. Note the flip happens BEFORE arming (`car.gd:487`,
  init `car.gd:189`): a fresh car's first break aims RIGHT (`_pass_side`
  1 → −1 against the car-local "forward is −z, right is +x" convention,
  `scenes/car.tscn:110`), its second break left. The in-pass 2.6 m proximity
  brake (`car.gd:364-365`) stays as the floor's last line.
- **Narrower body clearance:** pigeon/tourist blockers use
  `pass_clearance_body` (new export, 1.7 m ≈ body half ~0.35 + own 0.95 +
  margin), shrinking the swing from 2.3 m; wedge passes (no blocker) keep
  `pass_clearance`.

### 3. Honk etiquette

- **Patience honks play only where they are feedback:** `_break_hold` honks
  through a new gate — the car is within `honk_near_m` (new export, 30.0 m
  flat) of the player, or the player reference is null (bare-rig default:
  the gate needs a player to gate against; every existing staged scenario
  keeps today's behavior). A gated-out break still runs its pass/force-commit
  machinery — only the horn and flash are skipped, and `honk_count` counts
  played honks only (the counter stays honest). **Splat honks are never
  gated** (`on_splatted`, `car.gd:659-666`) — hitting a car is always
  feedback. The player reference arrives the `traffic`/`bread_spawner` way:
  new `Car.player: Player = null`, assigned by the spawner before `_ready`
  (`car_spawner.gd:333`, `:278` sites) and by the harness staging helper.
- **Fleet-wide cadence cap:** a patience honk may sound only if
  `TrafficControl.now() − last fleet patience-honk ≥ HONK_MIN_FLEET_INTERVAL`
  (new const, 3.0 s — the fixed physics clock, deterministic under
  `--fixed-fps 60`). Near honks set the clock; far honks (already silent)
  do not. A capped-out near honk is ducked, like a real street.
- **Longer patience for protocol denials:** the clock reads
  `protocol_patience_seconds` (new export, 12.0 s) while the current hold is
  a protocol denial — the `held` flag from `_protocol_speed`
  (`car.gd:310-313`), which covers registered ladder denials and crosswalk
  holds — and `patience_seconds` (6.0, unchanged) for physical blockers and
  wedges. One accumulated clock, the threshold reads the current hold class
  each frame (a hold that becomes a protocol denial mid-window simply
  expires later; monotone, no second float). The pigeon-in-the-crosswalk honk
  still comes — after ~12 s instead of ~6 s; that shift is a Gate 3 judge
  line.

### 4. Gentler force-commit — only when the box is actually clear

`_break_hold`'s force-commit arm (`car.gd:488-492`) gains a box check beside
the existing front-zone-clear precondition: a new Car helper
`_box_clear(center: Vector3, radius: float) -> bool` scanning `Car._fleet`
(skip self) for any other car within `box_clear_radius` (new export, 7.0 m ≈
the node box's half-diagonal: ±5 m both axes) of the node center. The radius
test is geometric on purpose — it catches committed movements mid-box AND
waiting cars that overshot into the box (registration allows up to 3 m in,
`car.gd:445-447`), which a ledger-only check would miss. When the box is
occupied the break does nothing but the gated honk and re-arms — the occupant
is mid-movement and clears in seconds, and liveness chains through the
occupant's own breaks (its wedge watchdog and shoulder-alternating passes).
The three-mutual-right-yield cycle — all waiting, box empty — still
force-commits at protocol patience, exactly as `traffic_control.gd:26-30`
documents.

**New exports (all Car):** `protocol_patience_seconds: float = 12.0` ·
`honk_near_m: float = 30.0` · `pass_lookahead: float = 25.0` ·
`pass_clearance_body: float = 1.7` · `box_clear_radius: float = 7.0` ·
new const `HONK_MIN_FLEET_INTERVAL := 3.0` · new injected ref
`Car.player: Player = null`. Existing `patience_seconds`, `pass_clearance`,
`follow_*`, `full_stop_speed` unchanged.

**No reference photos:** no research phase ran for this ticket — driving-hold
behavior is game-invented tuning with no very clear real-world counterpart to
consult, so reference photos do not apply; every number above is read from
the tree (cited above) or measured by the headless census recorded in Refs,
and this ticket opened no image.

**What this does NOT claim:** no ladder changes — `request_go`'s four rules
and the `movements_conflict` table (`traffic_control.gd:85-123`, `:213-218`)
are untouched, only the car-side break is; no crosswalk-band, blinker, route,
spawn/recycle or sightline-gate changes; no parked-car or tailgate-crumb
changes; no changes to splat honks, scoring, favor or the honk-count/DONE
contract (`patience honks stay off the autoplay DONE line`,
`car_spawner.gd:67-69`); no traffic lights; no new input actions (no
controls-table change); no new scenes, meshes or paint; it does NOT claim
passes never cross the centerline — a clear-corridor overtake crosses on
purpose; and it does not re-tune lane speeds, follow gaps or the fleet size.

## Why

The owner picked the three symptoms together because they are one read:
**traffic under stress looks broken, not alive.** Pillar 2 says "the city
reacts; a silent city is a failed city" — but what the city currently says
under stress is a horn somewhere over the horizon every 1.6 seconds (73 per
2 minutes in the census, median 44.5 m away, p90 94 m: pure noise the player
can attribute to nothing) and cars swerving across the centerline into
oncoming traffic or shoving into the parked row to get past a queue that the
ladder was already dissolving. The honk is the city's best joke when it is
feedback — T-134's "honking at a pigeon blocking the road is the joke working
as designed" — and worthless when it is static. Etiquette keeps the joke and
kills the static: honks become sparse, local, attributable. Retiring
car-vs-car passes makes queues honest (traffic waits, then flows when the
ladder or the leader resolves — what a street is supposed to do), and the
corridor gates turn the pass from a defect generator into a real overtake you
can watch from the air. The gentler force-commit closes the last place the
four-way protocol can be seen violating itself: driving through a box another
car is already using. All three keep T-134's hard guarantees — pairwise gaps
> 2.0 m and nothing stays stuck — as the non-negotiable floor.

## Acceptance criteria

- [x] *(Gate 1b)* new `pass_stays_on_road`, staged at the T-134 node with a
      real `TrafficControl` and the background fleet wiped for determinism
      (zero the spawner targets, call the spawner's `_populate()` — the
      staged cars are then the only `Car._fleet` members): (i) a pigeon-held
      car with the oncoming corridor verified empty commits a pass whose
      every sampled frame stays inside the asphalt bounds — lane-local
      lateral within [−5.15 − 0.3, +2.15 + 0.3] — with pairwise gaps > 2.0 m
      throughout and completion inside 15 s (travel ≥ 8 m, blocker behind);
      (ii) with an opposing car staged mid-corridor (ahead 15 m, lane-local
      −3.0, opposing heading) AND a parked car staged in the right band
      (ahead ~12 m, lane-local +2.0), BOTH shoulders are denied — the fresh
      car's first break aims right (flip-before-arming, `car.gd:487` +
      `car.gd:189`, the `car.tscn:110` +x-right convention) and is denied by
      the parked gate, the left by the oncoming gate — so no pass commits for
      two patience cycles (the car stays held behind the pigeon, never
      `_passing`), and freeing the opposing car releases the pass inside the
      next cycle ON THE LEFT SHOULDER — the right is still parked-denied, so
      the leg also proves the fallthrough: the pass's lateral excursion goes
      leftward (min lane-local < 0) and stays inside the arm-(i) asphalt
      bounds; (iii) with a parked car staged in the right band and NO
      opposing car (the oncoming corridor clear), the car's natural first
      break aims right (no pinning needed — flip-before-arming,
      `car.gd:487`), the right shoulder is denied, and the pass falls through
      to the left, completing within the arm-(i) asphalt bounds and never
      closing under 2.0 m of the staged parked car
- [x] *(Gate 1b)* new `car_queue_never_passes`: a leader held by a pigeon and
      a follower at follow-gap behind it — over ≥ 3 follower patience cycles
      (≈ 20 s) the follower never enters `_passing` and the pairwise gap
      stays > 2.0 m; once the leader completes its (gated) pass the follower
      gains ≥ 5 m of travel within the next 6 s (the queue dissolves from the
      front; nothing wedges behind the retired pass)
- [x] *(Gate 1b)* new `honk_etiquette_gates`: (i) FAR — a staged car blocked
      by a pigeon with the player parked beyond `honk_near_m` holds honk_count
      at 0 across two patience cycles while its break machinery still runs
      (progress continues); (ii) NEAR — the same staging with the player 10 m
      away honks exactly once at the first expiry (the T-134 joke honk);
      (iii) CADENCE — two near-player cars breaking within
      `HONK_MIN_FLEET_INTERVAL` sound exactly one horn between them (the
      second's honk_count stays 0, its break still runs)
- [x] *(Gate 1b)* new `force_commit_checks_the_box`: (i) a registered-denied
      car with a conflicting committed movement staged in its node does NOT
      force-commit at `patience_seconds` (`find_committed` stays null; nose
      distance pin holds) and force-commits only after the staged movement is
      released; (ii) a registered-denied car with an empty box does nothing
      at 6 s and force-commits only past `protocol_patience_seconds`
      (measured 11-13 s); (iii) the three-mutual-right-yield cycle (all
      waiting, box empty) dissolves within `protocol_patience_seconds` + 10 s
      with zero overlaps
- [x] *(Gate 1b)* re-derived pins in the same change-set:
      `patience_pass_unsticks` keeps its leg-1/leg-2 expectations (near-player
      honk allowed at 5-9 s; one pass; zero honks on the off-line leg) with
      the staging gaining the corridor-clear precondition the gate now
      demands; `cars_traffic_loops_blocks` green with all arms (its sampled
      floor doubles as the pass-geometry proof on a live fleet);
      `four_way_stop_right_of_way`, `crosswalk_yield_holds_and_releases`,
      `traffic_recycle_keeps_flow`, `traffic_spawns_offscreen` and
      `car_splat_honk_and_continue` expected green UNCHANGED (ladder, holds,
      recycle, splat honks untouched); `density_cpu_budget` re-measured
- [x] *(Gate 1)* `--import` and the 120-frame boot exit clean, zero ERROR
      lines; per-script `--check-only` on touched scripts (the T-134 caveat
      stands: bare `--check-only` never registers the autoloads — the boot is
      the honest pass for those)
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`); the
      DONE line's `honks` stays splat-only (patience honks never reach the
      relay counter)
- [x] *(Gate 1b, recorded when landed)* the same 120 s headless census re-run
      on the landed tree — **recorded 2026-11-06, throwaway probe recreated,
      run, deleted** (numbers below, not copied):

      ```
      HONKS total=9 (4.5/min fleet) near(<30 m)=9 far=0 first_at=6.6 s
           causes={ physical:9, protocol:0, wedge:0 }
      HONK dist median=15.7 p90=24.5 max=24.5
      PASSES total=40 blockers={ car_parked:6, car_traffic:7, other:0, none:27 }
           centerline_crossed=9 parked_band_reached=15
           max|exc|=2.96 leftmost=-2.96 rightmost=2.60
      STUCK cars>10s=3 cars>30s=0 worst=20.0 s (over 14 tracked traffic cars)
      ```

      far (>30 m) patience honks = 0 ✓; the fleet total 9 = a small fraction
      of 73 ✓; every pass stays inside the asphalt bounds (max excursion
      2.96 m off the pass-start lane line against the −6.5/+3.5 road edges;
      rightmost 2.60 ≈ the gutter line on one sampled frame of a turn-arc
      pass) with crossings only on gated corridors (9 recorded) ✓;
      **car-blocker passes = 6 parked + 7 traffic, NOT 0 — this is the §1
      fallback the criterion itself points at** ("any new stuck class
      triggers the §1 fallback decision, recorded here"): the no-car-pass
      tree met the trigger (8 of 14 cars frozen > 30 s in mutual head-to-head
      face-offs, whole 60 s intervals at 0.0 m travel, worst 120 s), the
      decision is recorded in §1 above, and the landed passes are the
      gated/staggered form that decision names; no car continuously
      stationary > 30 s ✓ (worst 20.0 s against the pre-fix 21.2 s baseline —
      no regression)
- [x] *(pilot soak, recorded when landed — see the record below; ticked on
      reviewer sign-off 2026-11-07 with the fifth-interval caveat standing)*
      the T-134 round-1 liveness metric re-proven on the real game: a
      ≥ 4-minute pilot soak at defaults holds 0-1/14 traffic cars stationary
      across 60 s intervals with median per-car travel in the T-134 band
      (56-82 m/interval)

      **Soak record (2026-11-06, session `t166-soak-impl`, 5.5 min in Main,
      defaults — hidden window, muted, no persistence; `state.jsonl`
      positions at 60 s boundaries, first 14 spawner children = traffic):**
      intervals 0-60/60-120/120-180/180-240 s read **0/14 stationary** with
      median per-car travel 79.4 / 69.6 / 82.6 / 79.9 m (in/beside the T-134
      band 56-82); the 240-300 s interval reads **2/14 stationary, median
      40.8** — ABOVE the bar. The two cars are NOT a patience-break artifact:
      they drove independently to the same point in the east apron
      ((85.1, 13.2) and (86.0, 13.4) — the route-exit lead point past a rim
      node, ~3 m beyond the city's road edge), arrived ~30 s apart, and STAND
      there 0.87-1.0 m apart for the rest of the soak — a route-end stand
      (`path` ran dry, target 0), which involves NO break machinery, NO
      patience clock and NO pass: the code paths this ticket touched are not
      in that loop, and T-134's own landed soak recorded the same straggler
      family (1/14 in its worst interval, "post-fix ... 1/14 in the worst").
      The landed headless census on the same tree independently shows the
      fleet dissolving (worst continuous stop 20.0 s vs the 21.2 s baseline;
      three cars > 10 s, zero > 30 s). Verdict recorded: the reviewer signed
      off on the ticket with this record (2026-11-07) — the tick stands on
      the clean four-minute reading plus the census corroboration; the
      rim-exit stand is flagged for a follow-up ticket (T-134's dealing,
      not this ticket's), and the fifth-interval reading is recorded here
      for what it is.
- [x] *(Gate 3)* human feel lines, via the pilot harness: [watch] a queue near
      the pigeon waits calm — honks sparse and attributable to the car you can
      see; [watch] a pigeon-held car honks and either eases past staying over
      the asphalt or visibly waits out oncoming before going — never swerves
      into traffic; [watch] a four-way node under a protocol denial holds
      patient, not frozen — the queue dissolves, and the ~12 s crosswalk honk
      still reads comic not laggy; [screenshot] a mid-arc pass from the air
      reads as a car easing around an obstacle, not a lane change into
      oncoming — **PASSED human review: reviewer sign-off 2026-11-07, ticket
      accepted against the branch** (the T-134 Gate 3 precedent: the
      reviewer's own drive-around sessions are the feel instrument named by
      this ticket's Route line)

## Verification

Gate 1 (import + 120-frame boot + per-script `--check-only`, with the T-134
autoload caveat) · Gate 1b full suite via
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`, with the
four new scenarios registered in `_run_scenarios` and their rows added to the
Gate 1b table in `VERIFICATION.md` in the same change-set, plus the re-derived
pins listed · Gate 2 autoplay (the DONE-line honks check) · Gate 3 the four
human lines above plus the pilot soak.

**Red-before probes to record when landed:** `car_queue_never_passes` reds on
the old tree (census: 13 car-blocker passes, all at cycle 3);
`pass_stays_on_road`'s arm (ii) reds — the old tree has no gates at all, so
the staged car arms a pass on its first break straight through the staged
oncoming car and parked car; `honk_etiquette_gates`' far arm reds
(census: 59 of 73 honks beyond 30 m); `force_commit_checks_the_box`'s
occupied-box arm reds (`car.gd:488-492` reads only the front zone — the
box is never consulted).

**Red-before record (landed 2026-11-06):** the old tree was NOT re-run for a
fresh red suite this session — the recorded pre-fix census above (measured
2026-11-04) stands as the red-before evidence for `car_queue_never_passes`
(13 car-blocker passes, all at cycle 3), `honk_etiquette_gates`' far arm
(59 of 73 honks beyond 30 m) and `force_commit_checks_the_box`'s occupied-box
arm (the break read only the front zone). Two clean red observations DID land
during this session's iteration and are recorded in the VERIFICATION rows:
with the gates absent the staged `pass_stays_on_road` car armed its pass
straight through the staged denials (the arm-ii release pass ran RIGHT at
+1.58 lane-local past a staged parked car at +2.0, min fleet gap 2.07), and
the `force_commit` occupied-box arm's held car left its stop line mid-hold
(the un-gated break's escape path).

**Landed values (all at the ticket's proposed defaults, T-013/T-134 style):**
`protocol_patience_seconds` 12.0 · `honk_near_m` 30.0 ·
`HONK_MIN_FLEET_INTERVAL` 3.0 · `pass_lookahead` 25.0 ·
`pass_clearance_body` 1.7 · `box_clear_radius` 7.0 · `patience_seconds` 6.0
and `pass_clearance` 2.3 unchanged. Two implementation constants derived from
the street geometry landed beside them: the asphalt clamp bounds
`PASS_ASPHALT_LEFT` −5.15 / `PASS_ASPHALT_RIGHT` +2.15 (lane-local, see the
derivation in car.gd) and the corridor band `PASS_CORRIDOR_LEFT` −6.5 /
`PASS_CORRIDOR_RIGHT` +3.5 — the gate band that keeps the corridor reads ON
this road (the unbounded projection denied passes through walls: the census
caught a wedge held 47 s by an opposing car 68 m away on a parallel street
and a parked car 10 m off-road, both through the raw projection; bounded,
the census worst continuous stop fell to 20.0 s).

**Route:** pipeline (feel) — the owner-directed route; the Gate 3 drive-around
feel pass is the accept instrument.

**Acceptance record:** reviewer sign-off 2026-11-07 — ticket accepted against
this branch with the soak/census records above standing as written.

**Tuning latitude:** Gate 3 may move `protocol_patience_seconds` (8-16 s),
`honk_near_m` (20-40), `HONK_MIN_FLEET_INTERVAL` (2-5 s), `pass_lookahead`
(15-35), `pass_clearance_body` (1.5-1.9) and `box_clear_radius` (6-8) without
a new ticket — record the landed values here, T-013/T-134 style.

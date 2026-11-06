# T-168 — Dev tool 2: the starter verb pack — spawn a car, blink its lights, teleport the pigeon, freeze traffic

- **Status:** done · **Category:** tooling · **Value (1-5):** 4 ·
  **Risk (1-5):** 2
- **Depends on:** T-167 (lands `CaptureRecorder._execute_dev` and the
  debug-build gate — this ticket only adds members to that dispatcher)
- **Refs:** `tests/capture_recorder.gd` (`_pilot_step()` dispatch chain +
  the T-167 `_execute_dev` seam and `pilot_dev`/`pilot_dev_unknown`
  events) · `scripts/car_spawner.gd:33` (`car_scene` preload), 
  `car_spawner.gd:87` (`_cars: Array[Car]` — the managed living fleet),
  `car_spawner.gd:34-35` (`target_moving` 14 / `target_parked` 12 — the
  spawner already owns fleet size), `car_spawner.gd:108+` (`_ready`-driven
  spawn cadence) · `scripts/car.gd:163` (`var blinker: int` — −1 left /
  0 none / +1 right, the readable tell), `car.gd:214-217`
  (`$Visual/BlinkFL..RR` — the four T-162 amber lamps), `car.gd:78-79`
  (`blinker_lead` / `blinker_hz` — the existing flash law) · 
  `scripts/player.gd:178-186` (`reset_flight(pos, yaw_deg)` — zeroes
  velocity and touchdown state: the existing teleport primitive) · 
  `scripts/main.gd:582` (the splat-target API precedent for "readable from
  the harness" world queries)

## What

The owner's examples, verbatim: "Spawn a car, make it flash its lights,
watch it visually." This ticket adds the starter pack of named dev verbs —
explicit, self-documenting members of the T-167 `{"dev":...}` family,
each backed by an API that already ships:

1. **`{"dev":"spawn_car"}`** — instantiate one car near the player THROUGH
   the spawner's own spawn path (reusing `car_scene` and registering in
   `_cars`) so the new car joins the managed fleet — cleanup, crosswalk
   yield, class quotas — instead of becoming an orphan the spawner never
   sees. (Exact internal entry point is the implementer's read of
   `car_spawner.gd`; recorded in this ticket at done-time.)
2. **`{"dev":"car_blinker","side":"left"|"right","on":true|false}`** —
   targets the NEAREST car and forces `Car.blinker` (−1/0/+1) with the
   lamp meshes held lit or released. The T-162 blinkers ARE the car's
   lights — headlight meshes don't exist in the model, so "flash its
   lights" is this. A forced blinker overrides the route-driven arming
   logic while `on` (the `_blinker_side`/`_blinker_hold` state machine,
   `car.gd:203-206`), and `on:false` hands control back.
3. **`{"dev":"teleport","x":…,"y":…,"z":…,"yaw_deg":0.0}`** — calls
   `Player.reset_flight(target, yaw_deg)`: the existing API that zeroes
   velocity, touchdown velocity and flap state, so a teleport lands in a
   hover-friendly glide rather than carrying the old velocity into a wall.
4. **`{"dev":"freeze_traffic","on":true|false}`** — cars HOLD: a `frozen`
   check at the top of `Car`'s `_physics_process` stops route progress,
   honk clocks and the blinker state machine, and the spawner's cadence is
   gated while frozen (no new spawns into a staged scene). Frozen cars keep
   their transforms — staging stays stable for screenshots. `on:false`
   resumes exactly where everything stopped (no re-pathing, no teleports).
5. Every verb acks `pilot_dev {verb, ...}` with enough payload to be
   machine-checkable (e.g. `spawn_car` acks the spawned node's path,
   `teleport` acks the resolved target); unknown verbs keep logging
   `pilot_dev_unknown` per the T-167 contract.
6. **Gate 1b scenario `dev_verb_pack`** (registered in the
   `sim_test.gd:242` block; the T-167 `dev_hunger_lock` scenario stays as
   landed), driven through `_execute_dev` with explicit dicts, `allowed`
   default (headless sim is a debug build): (a) `spawn_car` adds exactly
   one node to the tree AND to the spawner's managed list; (b) `teleport`
   moves the player to the target with `velocity == Vector3.ZERO`;
   (c) `freeze_traffic` produces a zero position-delta across N ticks and
   `on:false` resumes movement; (d) `car_blinker` sets the readable
   `blinker` var and the correct side's lamp visibility, and releases
   cleanly on `on:false`; (e) `allowed=false` refuses every pack verb.
7. **Docs in the same change-set:** VERIFICATION.md Gate 1b row; AGENTS.md
   pilot verb list gains the pack. Final verb names/payloads are recorded
   in this ticket's Tuned-values section at done-time (the T-134 pattern).

**No reference photos:** dev tooling; no research phase, no image opened.

**Not claimed:** no despawn/delete verb (the spawner's recycling owns fleet
size; a kill verb invites orphan state — reconsider when a ticket actually
needs it); no traffic-AI behavior changes (freeze is a hold, not new
driving); no tourist/elder/bread verbs (the T-169 call verb covers one-offs
once it lands, and the pack grows only when a ticket needs a named member);
no in-game console UI (pilot channel only — owner decision 2026-11-04);
no spawn-location customization beyond "near the player" (the call verb can
reach finer placement once it lands).

## Why

This is 90% of day-to-day ticket testing: stage a scene (freeze traffic),
put a subject in it (spawn a car), pose the camera and the pigeon
(teleport), exercise a behavior (blinkers — directly useful for re-verifying
T-162/T-134 blinker tickets), and look at it. Today each of those needs a
fresh sim_test scenario or a code edit; with the pack they are JSONL lines
any agent (or the owner, via `pilot.py send`) can fire mid-session at any
pause state. The verbs deliberately route through the real gameplay APIs —
spawn through the spawner, teleport through `reset_flight`, blink through
the car's own state — so a dev session exercises the same code paths a
player session would, which is what makes the observations trustworthy.

## Acceptance criteria

- [x] All four verbs live on the `_execute_dev` dispatcher, each acking a
      machine-checkable `pilot_dev` event; unknown verbs log
      `pilot_dev_unknown`
- [x] `spawn_car` registers the new car in the spawner's managed fleet
      (cleanup/yield/quotas see it) — no orphan nodes
- [x] `car_blinker` overrides the route-driven blinker state machine while
      on, and hands control back on `on:false` (post-turn holds, T-134 §5,
      behave normally after release)
- [x] `teleport` goes through `Player.reset_flight` (velocity zeroed — the
      suite pins this, not a raw position write)
- [x] `freeze_traffic` holds ALL car motion and the spawn cadence, and
      resumes without re-pathing or state resets
- [x] *(Gate 1b)* new `dev_verb_pack` scenario registered in the
      `_run_scenarios` block with the five legs above; full suite 0
      failures: `godot --headless --fixed-fps 60 --path .
      res://tests/sim_test.tscn`
- [x] *(Gate 1)* `godot --headless --path . --import` and the 120-frame
      boot exit clean, zero ERROR lines
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`)
- [x] VERIFICATION.md Gate 1b row + AGENTS.md pilot verb list updated in
      the same change-set; final verb payloads recorded below at done-time
- [x] *(Gate 3, screenshots)* one pilot session proving the owner's flow
      end-to-end — freeze traffic, spawn a car near the pigeon, force its
      left blinker, teleport the pigeon overhead, capture — with the
      captures recorded here and an eyes-on verdict that the staged scene
      reads correctly (this IS the "watch it visually" acceptance)

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with
`dev_verb_pack` registered and its VERIFICATION.md row · Gate 2 autoplay ·
Gate 3 the staged-scene screenshot pass above (the one human-judgement
line: whether a frozen, blinked, player-placed car reads right on screen).

**Tuned values** (final verb names, payloads and the spawner's internal
spawn entry point used — all four on the `_execute_dev` dispatcher,
`tests/capture_recorder.gd`):

- `{"dev":"spawn_car"}` — no payload. Ack: `pilot_dev {verb, node, p,
  fleet}` — `node` is the spawned node's path, `p` its global position,
  `fleet` the post-spawn `living_cars()` size. Refusals:
  `pilot_dev_refused {reason:"no_spawner"|"no_spot"}`. Spawner entry
  point: **`CarSpawner.dev_spawn_car()`** (scripts/car_spawner.gd) — it
  walks the NEAREST block centers with the spawn band ignored (round 1
  review: the band pool landed the dev car 22.5 m out and the blink step
  then forced a fleet car — measured 8.78 m on the suite plaza, 6.8 m
  live, after the fix) and each block's curb spots nearest-first, and
  spawns through the populate path's own `_spawn_parked` (now returning
  the `Car`), under a fresh 1-slot class quota, so the car joins `_cars`
  with the tailgate wiring and splat relay — never an orphan. The
  sightline gate is deliberately not consulted (a dev spawn is meant to
  be seen).
- `{"dev":"car_blinker","side":"left"|"right","on":true|false}` — targets
  the NEAREST living car to the pigeon at the moment it fires (flat,
  walked over Car's static `_fleet`, so staged cars qualify) — to dress
  the spawned car, hop onto the spawn ack's `p` first (the flow below).
  Ack: `pilot_dev {verb, side, on, car, blinker, forced}`. Refusals:
  `bad_side`, `no_player`, `no_car`, and — round 1 review — `no_forced`
  (an `on:false` with no car forced). Entry:
  `Car.set_blinker_forced(side)` — `blinker_forced` −1/+1 holds that
  side's pair solid-lit (no flash), the route-driven machine and the
  post-turn hold clock pause while set; 0 hands control back and the
  machine resumes (a driving car re-arms off its route within a frame).
  (Round 1 review) The release targets the car THIS SESSION FORCED —
  the recorder remembers it at force time (`_dev_forced_car`), falling
  back to the nearest car still carrying a forced tell — not whatever
  is nearest at release time. A forced tell also dies with the car's
  re-staging: `start_route` and `park_at` clear `blinker_forced` (and
  re-apply dark lamps when parking), so a dev override can never ride a
  recycle and pollute the T-134/T-162 blinker observations.
- `{"dev":"teleport","x":…,"y":…,"z":…,"yaw_deg":0.0}` — world-frame
  target, `yaw_deg` optional. Routed through `Player.reset_flight`
  (velocity, touchdown velocity and flap state zeroed), converted
  through the player's parent so harness rigs resolve correctly. Ack:
  `pilot_dev {verb, p, yaw_deg}` with the resolved global position.
  Refusal: `no_player`.
- `{"dev":"freeze_traffic","on":true|false}` — default true. Sets the
  static `Car.traffic_frozen`: every car's `_physics_process` returns at
  the flag and `CarSpawner._physics_process` gates the recycle cadence
  (the scan timer holds, so resume keeps the old rhythm). Ack:
  `pilot_dev {verb, on}`. Restore note: the flag is static — a crash
  mid-freeze leaves it set only for that process; a fresh session
  boots false.

## Gate 3 record

### Round 1 (2026-11-06, session `t168gate3`) — superseded by review

Flow run as freeze → spawn → blink → teleport overhead → captures. The
verdict recorded then ("the staged scene reads correctly") was TRUE of
the staged frames but the FLOW was defective, per the round-1 review:
`spawn_car` landed @1218 22.5 m from the pigeon (the spawn-band search)
while a fleet car sat 18.6 m away, so `car_blinker` forced the STRANGER
`@863`, never the spawned car — reproduced 3/3 runs (reviewer's rv1/rv2
included). Also: `on:false` released whatever car was nearest at release
time, orphaning the forced car solid-lit through recycles. Both defects
fixed this round (see Tuned values); captures of the flawed flow remain
at `.captures/session_t168gate3/`.

### Round 2 (2026-11-06, session `t168gate3r2`) — the recorded pass

The owner's flow, corrected per the review (freeze → spawn → hop onto
the spawn ack's `p` → blink → pose overhead → captures), through the real
pilot channel. Acks (events.jsonl): `freeze_traffic on` at 28.1 s;
`spawn_car` fleet 26→27, node `/root/Main/CarSpawner/@CharacterBody3D@1218`
at (12.05, 0.05, −5.5) — 6.8 m from the pigeon; `teleport` onto that exact
`p` (+1.6 m hover); **`car_blinker left on` acked `car: @1218` — the
spawn ack's node, the review's cross-pin, TRUE**; six further `teleport`
acks each resolving exactly the commanded target. Capture PNGs
(`.captures/session_t168gate3r2/`): `t168_r2_overhead.png`,
`t168_r2_stage.png`, `t168_r2_closeup.png`, `t168_r2_flank.png`,
`t168_r2_flank2.png`.

**Eyes-on verdict: the staged scene reads correctly.** The spawned blue
visitor car sits frozen at its curb mid-frame with its LEFT amber corner
lamps visibly lit — front-left in `t168_r2_closeup.png`, rear-left
clear in the broadside `t168_r2_flank2.png` — the right flank dark; the
fleet (black car across the crosswalk) holds bit-identical positions
across 195 s (state.jsonl multiset compare, first post-spawn sample vs
final: 27 cars, identical); the pigeon lands exactly where each teleport
put it (the reset_flight hover glides down and grounds — expected,
velocity zeroed). The solid-lit read on screen is corroborated by the
suite's 60/60-frame lamp pin and the new release/flow pins (suite bite
line: spawn dist 8.78 m, released=true nearest=true wrong_nearest=true,
spawned forced=true released=true flow=true).

Gate runs on the round-2 tree: Gate 1 `--import` exit 0 (only the
documented godot_mcp teardown ERROR line) and `--quit-after 120` exit 0
with zero ERROR lines; Gate 1b full suite `SIM SUMMARY: 0 failure(s)`
(173 pass); Gate 2 `AUTOPLAY DONE ok=true t=33.0 … restart=true`.

Gate runs on the committed tree: Gate 1 `--import` exit 0 (only the
documented godot_mcp teardown ERROR line) and `--quit-after 120` exit 0
with zero ERROR lines; Gate 1b full suite `SIM SUMMARY: 0 failure(s)`
(173 pass, `dev_verb_pack` bite line: spawn fleet 5→6 tree 5→6,
teleport Δpos 0.0000 vel_zero=true, blinker held 60/60 released
machine_ok, frozen Δpos=0.000000 timer_held far_held, resumed Δpos=131.52
far_returned, refused=4/4 acks=true); Gate 2 `AUTOPLAY DONE ok=true
t=33.0 … restart=true`.

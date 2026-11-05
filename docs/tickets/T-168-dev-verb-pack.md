# T-168 — Dev tool 2: the starter verb pack — spawn a car, blink its lights, teleport the pigeon, freeze traffic

- **Status:** proposed · **Category:** tooling · **Value (1-5):** 4 ·
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

- [ ] All four verbs live on the `_execute_dev` dispatcher, each acking a
      machine-checkable `pilot_dev` event; unknown verbs log
      `pilot_dev_unknown`
- [ ] `spawn_car` registers the new car in the spawner's managed fleet
      (cleanup/yield/quotas see it) — no orphan nodes
- [ ] `car_blinker` overrides the route-driven blinker state machine while
      on, and hands control back on `on:false` (post-turn holds, T-134 §5,
      behave normally after release)
- [ ] `teleport` goes through `Player.reset_flight` (velocity zeroed — the
      suite pins this, not a raw position write)
- [ ] `freeze_traffic` holds ALL car motion and the spawn cadence, and
      resumes without re-pathing or state resets
- [ ] *(Gate 1b)* new `dev_verb_pack` scenario registered in the
      `_run_scenarios` block with the five legs above; full suite 0
      failures: `godot --headless --fixed-fps 60 --path .
      res://tests/sim_test.tscn`
- [ ] *(Gate 1)* `godot --headless --path . --import` and the 120-frame
      boot exit clean, zero ERROR lines
- [ ] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`)
- [ ] VERIFICATION.md Gate 1b row + AGENTS.md pilot verb list updated in
      the same change-set; final verb payloads recorded below at done-time
- [ ] *(Gate 3, screenshots)* one pilot session proving the owner's flow
      end-to-end — freeze traffic, spawn a car near the pigeon, force its
      left blinker, teleport the pigeon overhead, capture — with the
      captures recorded here and an eyes-on verdict that the staged scene
      reads correctly (this IS the "watch it visually" acceptance)

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with
`dev_verb_pack` registered and its VERIFICATION.md row · Gate 2 autoplay ·
Gate 3 the staged-scene screenshot pass above (the one human-judgement
line: whether a frozen, blinked, player-placed car reads right on screen).

**Tuned values:** *(recorded at done-time — final verb names, payloads and
the spawner's internal spawn entry point used)*

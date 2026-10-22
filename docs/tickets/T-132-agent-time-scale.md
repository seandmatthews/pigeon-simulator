# T-132 — Slow-mo for agent play: a pilot `--time-scale` flag that slows the world, not the frames

- **Milestone:** Agent play tooling (owner ask 2026-10-22) · **Status:** done (Gate 3 pending — the precision-splat dogfood leg) · **Category:** tooling · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** — (pilot harness T-014, landed; game boot-mute opt-in T-101, landed — its flag pattern is the template)
- **Refs:** owner question 2026-10-22 ("can we slow the internal game clock so you
  can look and then issue inputs?"); `scripts/game.gd:95-100` (the
  `PIGEON_SOUND=1`-or-`--sound`-user-arg pattern to mirror);
  `tests/capture_recorder.gd:57-61` (user-arg parsing convention after `--`);
  AGENTS.md pilot section (CLI docs that must grow the flag).

## What

Agent play is bottlenecked by decision latency, not by frames. A look-think-act
cycle takes seconds of wall-clock time, and at 1× the pigeon falls, drifts, and
overshoots a lot between cycles — precision maneuvers (lining up a poop dive on
a tourist, staging screenshots for a ticket, A/B-ing a feel change) are mostly
recovery from what happened while the agent was thinking.

The fix is to slow the **simulation**, not the render: `Engine.time_scale`
scales `delta` for every `_process`, `_physics_process`, Timer, and Tween, so
the whole world runs in slow motion while frames keep painting at full rate.
At 0.1×, two seconds of agent wall-clock is 0.2 s of game time — enough slack
to actually line up a dive. Two properties make this cheap and safe here:

1. **The tree is never paused**, so the known capture-while-paused wedge
   (game-over screen, 2026-10-12 MCP defect log) is sidestepped — pilot's
   in-process frame PNGs and `shot` keep working exactly as today.
2. **The simulation per game-second is unchanged** — physics ticks advance a
   proportionally smaller step, determinism and the flight model are intact,
   and every gate runs at the default 1.0, so no Gate 1b bar is re-derived.

**The change:** a pilot opt-in flag, plumbed like T-101's sound opt-in —

- `pilot.py start --time-scale 0.1` forwards `--time-scale=0.1` as a user arg
  after `--` (next to `--pilot-session=<id>`), default 1.0 (absent = untouched).
- The Game autoload reads it (user arg **or** `PIGEON_TIME_SCALE` env, same
  env-or-arg pairing as sound) in `_ready` — before any scene loads — clamps it
  to **[0.01, 1.0]** (slow-mo only; >1.0 would silently break gates that
  assume realtime) and sets `Engine.time_scale`. The parse routes through a
  small seam function so the harness can pin both branches without relaunching,
  per the `Game.web_override` pattern.
- AGENTS.md's pilot block documents the flag; pilot.py's usage text too.

Non-goals: no step mode (advance-N-ticks-then-hold), no menu/UI exposure, no
faster-than-realtime, and normal launches (game icon, exports, all gates) are
byte-unaffected — the default is absent-flag = 1.0.

## Acceptance criteria

- [x] `pilot.py start --time-scale 0.1` boots the game with
      `Engine.time_scale == 0.1`; default `start` (no flag) and every existing
      launch path boot at `1.0`.
- [x] The parse seam clamps out-of-range and garbage input to 1.0's branch:
      `2.5` → `1.0`, `abc` → `1.0`, `0` → `1.0` (a frozen world is a hung
      session, not a feature).
- [x] *(Gate 1b)* New scenario `pilot_time_scale_flag` pins the seam both ways
      via injection (no-flag default 1.0; `--time-scale=0.1` applied AND
      landed on the engine through the applier; clamp legs) **and** a rate leg
      proving the world actually slows: the same 60 physics frames accumulate
      1.0 game-second at scale 1.0 and 0.1000 at scale 0.1 (binary probe
      2026-10-22: the ~60/s wall tick rate never changes, every delta scales —
      true under the suite's `--fixed-fps` and in real time alike).
      VERIFICATION.md table row added.
- [x] Frames keep flowing in slowed sessions — with a discovered nuance the
      dogfood surfaced: the in-process PNG stream's timer is a scaled Timer,
      so its cadence follows the GAME clock (a "0.5 s" stream delivers a PNG
      every 0.5 game-seconds = every 5 wall-s at 0.1×; session t132slow: 470
      PNGs spanning 141k game-frames, exactly the game-time cadence). Sampling
      density per game-second is unchanged and the OS `shot` grab is
      instant at any moment — agent vision survives, the wall cadence claim
      did not and is corrected in AGENTS.md.
- [x] AGENTS.md pilot section + pilot.py usage text document the flag.

**Tuned values:** default 1.0; accepted range [0.01, 1.0]; working presets for
agents: 0.1 (dive lining) and 0.02 (near-turn-based staging).

## Verification

- Gate 1: `--import` and `--quit-after 120` both exit 0 with zero ERROR lines
  (re-run on the final tree after the applier split; the accepted godot_mcp
  teardown ERROR didn't even appear this pass; `game.gd` still fails bare
  `--check-only` on the autoload-resolution gap — proven pre-existing, the
  120-frame boot is the compile proof).
- Gate 1b: full suite **145 PASS / 0 FAIL**, exit 0 (144 + this scenario).
  `pilot_time_scale_flag` reads `scaled=0.1000s normal=1.0000s` on the rate
  legs. Red-before probe: with the applier hard-set to 1.0 (the exact wiring-
  revert shape) the suite exits 1 with
  `SIM FAIL pilot_time_scale_flag: ... applied=false` naming the leg — the
  parse table alone can NOT catch a wiring revert, which is why the
  parse/apply split exists.
- Gate 2: `AUTOPLAY DONE ok=true` (fps 137, poses all six, splats 8, ambience
  true), no SCRIPT ERROR — re-run on the final tree, flagless boot untouched.
- Gate 3 (agent dogfood, 2026-10-22, five pilot sessions ≈ 2.5 wall-hours at
  0.1×): **the flag earns its keep; the splat itself stays open.**
  - Mechanism proven in-session: hunger drains 0.280 per 10 wall-s = exactly
    0.278/game-s × 0.1 (the 0.1× signature; ~60 wall-min of play per run);
    per-frame state JSONL keeps streaming; poops release and resolve; the
    agent ran hundreds of measure-decide-act cycles at 2-3 s decision
    latency — geometry that at 1× would shift 3-30 m between decision and
    action moves 0.3-3 m at 0.1×.
  - The precision shot got CLOSE but did not land: ground-aligned ambush
    reached 0.000 rad heading error and sub-2.5 m line offset via measured
    waddle steps; the intercept driver reached `dist_R` 5.7 m of a 0.55 m
    window across 9 attempts. Every failure is the agent's own hand-rolled
    pilot (ledger: uninitialized heading guard, turn-command queue bombing —
    600 frames = 1 game-SECOND at 0.1×, they back up for minutes — sign
    flips at the ±π knife edge, takeoff guards too narrow, hover authority,
    a waddle probe that read displacement instead of velocity), never the
    game or the flag. For scale: the autoplay script lands 8 splats in 33
    game-seconds at 1× with its well-crafted single-release formula.
  - Discoveries folded back into the tooling/docs: the PNG stream timer scales
    with the world (above); the hunger clock is a real budget (~60 wall-min
    per run at 0.1× — two sessions starved mid-maneuver); pilot command
    `frames` are wall ticks, so at 0.1× a `{"frames":600}` hold is 10 wall-s.
- **OPEN leg (rides a future agent/owner session):** land the tourist splat
  at 0.1× decision latency. The mechanism, state stream, and aiming math are
  all proven; the gap is pilot craft, and the next session starts from this
  ledger instead of rediscovering it.

**Route note:** default-off debug tooling — no shipped feel, no physics change
at defaults, no re-derived bars — so per the T-116 precedent this is
direct-loop eligible despite touching the sim clock, **provided** the gates
prove the default path is byte-unaffected (that's the first AC). If
implementation ends up touching flight code to make slow-mo behave, stop and
re-route through the pipeline.

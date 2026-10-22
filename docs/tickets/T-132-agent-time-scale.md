# T-132 — Slow-mo for agent play: a pilot `--time-scale` flag that slows the world, not the frames

- **Milestone:** Agent play tooling (owner ask 2026-10-22) · **Status:** proposed · **Category:** tooling · **Value (1-5):** 3 · **Risk (1-5):** 1
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

- [ ] `pilot.py start --time-scale 0.1` boots the game with
      `Engine.time_scale == 0.1`; default `start` (no flag) and every existing
      launch path boot at `1.0`.
- [ ] The parse seam clamps out-of-range and garbage input to 1.0's branch:
      `2.5` → `1.0`, `abc` → `1.0`, `0` → `1.0` (a frozen world is a hung
      session, not a feature).
- [ ] *(Gate 1b)* New scenario `pilot_time_scale_flag` pins the seam both ways
      via injection (no-flag default 1.0; `--time-scale=0.1` applied; clamp
      legs) **and** a rate leg proving the world actually slows: with
      `Engine.time_scale = 0.1`, game time accumulated over ~1 wall-second of
      frames is ≈0.1 (Timer/delta accumulation probe, tolerance stated in the
      scenario). VERIFICATION.md table row added.
- [ ] Frames keep flowing in slowed sessions: a pilot session at 0.1× produces
      fresh frame PNGs at the usual 0.2 s wall cadence (the frame stream is
      wall-clock scheduled; this is a spot-check during Gate 2, not a new gate).
- [ ] AGENTS.md pilot section + pilot.py usage text document the flag.

**Tuned values:** default 1.0; accepted range [0.01, 1.0]; working presets for
agents: 0.1 (dive lining) and 0.02 (near-turn-based staging).

## Verification

- Gate 1: `--import` and `--quit-after 120` exit 0 (accepted godot_mcp
  teardown ERROR line only; `game.gd` already fails bare `--check-only` on the
  autoload-resolution gap — proven pre-existing, the 120-frame boot is the
  compile proof).
- Gate 1b: `pilot_time_scale_flag` green, full suite PASS, red-before probe =
  temporarily bypassing the seam (hard-set 1.0) must FAIL the applied leg.
- Gate 2: autoplay green at default (no flag), no SCRIPT ERROR.
- Gate 3: owner-free by design — the human-judgement leg is an agent dogfood
  pass recorded in the ticket: one pilot session at 0.1× lines up and lands a
  poop on a moving tourist that fails at 1× decision latency. If that pass
  can't tell the difference, the flag isn't earning its keep and should say so.

**Route note:** default-off debug tooling — no shipped feel, no physics change
at defaults, no re-derived bars — so per the T-116 precedent this is
direct-loop eligible despite touching the sim clock, **provided** the gates
prove the default path is byte-unaffected (that's the first AC). If
implementation ends up touching flight code to make slow-mo behave, stop and
re-route through the pipeline.

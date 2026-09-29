# T-018 — Performance budget pass

- **Milestone:** M2 · **Priority:** P1 · **Size:** M · **Status:** done
- **Depends on:** T-004, T-007, T-008 (the density it budgets)
- **Refs:** `docs/DESIGN.md` → Milestone 2 list ("performance budget pass")

> **ID note:** the workflow assigned T-018 to the code-optimization lane while
> the backlog index's highest ID was T-014; T-015–T-017 are deliberately left
> unclaimed for other in-flight work rather than renumbering an assigned
> ticket.

## What

Guard the full-density CPU frame cost with a machine check, and give agent
play sessions a machine-readable perf stream:

- Gate 1b scenario `density_cpu_budget`: the real `main.tscn` — city, 18
  tourists, 36 cars, bread, pigeon — parked in its own space, pigeon on a
  synthetic level cruise above the plaza, three 100-frame wall-time windows
  under `--fixed-fps 60`, median asserted against a calibrated absolute
  budget.
- `PIGEON_PERF=1` pilot stream: engine monitors (fps, script process/physics
  time, draw calls, primitives, render objects, nodes, physics-active) every
  30 frames in the session's `state.jsonl`.
- Pilot channel hardening the perf work depends on: stale command files are
  swept at session start, consumed commands are deleted before executing (a
  quit can no longer poison the next session), and the recorder null-guards
  the scene-change window.

## Why

Nothing machine-guards the frame budget: the T-004 60 fps criterion lives only
in Gate 2's autoplay DONE line (average fps) and a pending Gate 3 human line.
M2 adds NPCs, districts and effects on top of the M1 city; a gross CPU
regression should trip a gate, not a vibes check.

## Acceptance criteria

- [x] `density_cpu_budget` runs green in Gate 1b and fails when the budget
      constant is cut below the measured cost
- [x] Budget number is calibrated headless on the dev machine and recorded
      below (not predicted from windowed pilot data)
- [x] `PIGEON_PERF=1` sessions carry the monitor stream; default sessions are
      unchanged
- [x] A session whose predecessor died without consuming its commands boots
      and plays instead of quitting at t≈1 s

## Failure modes (stated, not hidden)

- The gate is **absolute wall-time**, so it is machine-relative: a busy
  machine can false-FAIL it (re-run idle) — it can never false-PASS a load
  spike. The budget carries ~3x headroom over the calibrated cost, so only
  gross regressions (think: NPC fleet doubled, a per-tick allocation storm)
  trip it; percent-level drift passes by design.
- Headless renders nothing: the gate sees **only the CPU half** of the frame
  (scripts, physics, scene). Draw-call/primitive regressions stay with Gate
  2's DONE-line average fps and Gate 3's human pass.
- The `city.generate` synchronous rebuild spike (measured at fps 2 for the
  generation frame, fps 17 for ~2 s of menu load on the dev machine —
  `city.gd:141-184`) is **recorded here, not gated and not fixed**: it is a
  one-off hitch at boot/restart, out of this ticket's scope.

## Calibration (normative)

Calibrated headless on the dev machine (RTX 4080, worktree at main + this
ticket), Gate 1b `--fixed-fps 60`, median of three 100-frame windows,
full-density real main scene at offset (-3500, 0, 3500):

| Quantity | Measured |
| -------- | -------- |
| Median 100-frame window | **247.5 ms** and **245.1 ms** across two full-suite runs (≈2.5 ms per physics frame) |
| Per-window spread (worst run) | 233.7 / 247.5 / 264.2 ms (±7% around the median) |
| Budget constant (~3x, rounded) | **750 ms** |
| Nodes (harness scene total) | 3149 |
| Physics-active bodies | 40 (20 traffic + 18 tourists + 1 player + 1; parked cars sleep — car.gd early-returns before move_and_slide) |

Pilot-session context (windowed profiler stream, not the gate's basis):
physics script ~2.9-3.7 ms/s, city-in-view draw calls 123-234, 60.0 ticks/s
held in every state.

## Landed (T-018)

- `tests/sim_test.gd` — `_scenario_density_cpu_budget()` (runs last): instant
  `main.tscn` at a fresh offset clear of the test world and the harness city,
  cruise position from `city.to_local(city.spawn_point)` (reset_flight is
  local — the `main.gd:60` pattern), velocity re-imposed at every window
  start so no window mixes cruise/stall/grounded states, density asserted
  (18 tourists + 36 cars alive) so the gate cannot silently pass on a
  half-seeded city; housekeeping mirrors `restart_resets` (detach the
  autoload's hunger player, reset the run, free, null the ref).
- `tests/capture_recorder.gd` — `PIGEON_PERF=1` monitor stream; null-guards
  in `_find_player`/`_spawner` for the `change_scene_to_file` window;
  commands are consumed-and-deleted before execution so a quit never
  survives to kill the next session on the same id (observed live: a stale
  `{"quit":true}` booted-and-killed a fresh instance in ~1 s).
- `tests/tools/pilot.py` — `start` sweeps stale `pilot_cmd_*.jsonl` from the
  session dir before spawning.
- `VERIFICATION.md` — Gate 1b row `density_cpu_budget` + known-issues note
  splitting CPU gating (this ticket) from rendered fps (Gate 2 DONE line +
  Gate 3 human pass).

## Verification

Gate 1 + Gate 1b (both green on the dev machine: import/boot exit 0 with zero
error lines; `SIM SUMMARY: 0 failure(s)` with `density_cpu_budget` median
245.1 ms vs the 750 budget). The harness fixes were verified live in a pilot
session: a planted stale `{"quit":true}` was swept by `start` and the session
booted and played; the boot log contains zero `get_node_or_null` errors
(previously ~24 per boot); `PIGEON_PERF=1` emitted perf blocks exactly every
30 frames with sane values (Main: fps 144, 237 draw calls, 1940 nodes, 39
physics-active). No input actions change, so no controls-table updates.
Rendered fps stays a Gate 2/Gate 3 judgement — nothing here replaces the
human pass over the T-004 "holds ~60 fps" line.

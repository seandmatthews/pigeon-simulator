# T-140 — Frame-step agent play: pilot pause/step/resume + deferred presses

- **Milestone:** Agent play tooling (owner ask 2026-10-27) · **Status:** done · **Category:** tooling · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-014 (the pilot harness), T-132 (the slow-mo sibling — this
  supersedes its recorded "no step mode" non-goal, owner-directed)
- **Refs:** owner steer mid-session ("the game is still too fast for you — how
  do we slow it down to frame by frame inputs, advancing to the next frame only
  when you're ready?"); `tests/capture_recorder.gd` `_pilot_step` (the command
  channel — PROCESS_MODE_ALWAYS, so it flows through pause); AGENTS.md pilot
  section; the 2026-10-27 beat-the-game run (sessions `slowwin1`/`slowwin4`,
  evidence in `.captures/`).

## What

T-132's `--time-scale` slowed the world for real-time play, and an owner-supervised
session at 0.1× proved it still wasn't slow enough to aim in. The owner asked for
frame-by-frame control, and the pilot channel already had everything needed to
carry it: the recorder node processes through a paused tree, so three new commands
make agent play **turn-based** —

- `{"pause": true}` freezes the whole tree; `{"step": N}` unpauses for ~N world
  ticks and re-freezes; `{"resume": true}` leaves pause. `step` is refused while
  unpaused (`pilot_step_ignored`), and `{"quit": true}` works from pause.
- **Deferred presses:** input queued while frozen is parked, not dropped — it
  presses on the first tick that actually runs. A press made while frozen would
  otherwise expire unheard (`is_action_just_pressed` is one tick wide and a
  paused player never ticks to see it). Queue-then-step — input and step lines
  in the SAME command file — is the protocol; the file's lines run in one pass,
  so the ordering is guaranteed.
- **The unpause pad:** the tree hands PAUSABLE nodes their first live tick ~2-3
  recorder ticks after the unpause flip (measured live: step at t, first player
  motion at t+44 ms). The step window carries a +4-tick pad so a raw window
  cannot close before the world moved at all; the pad is dead time, not world
  time. This was found empirically — a 2-tick window produced zero player ticks.

With pausing doing the waiting, sessions no longer need `--time-scale`: one tick
is one real frame and the agent chooses exactly how much world to advance between
observations. `shot` (OS grab) and `state` read the frozen world freely — and the
T-105 reticle, frozen mid-pause, shows its exact predicted impact, which became
the aiming tool.

**Helpers generalized into `tests/tools/`** (from the gitignored session scratch):
`pilot_nav.py` (`state` — last-COMPLETE-line read, the newest line can be
mid-write; `goto X Z --face YAW` — exact waddle navigation, no obstacle
avoidance) and `pilot_splat.py` (the parked-visitor-car grind worked example).
Both smoke-proven live post-generalization (2/2 splats from a cold spawn).

**Live proof — the run that won the game** (2026-10-27, ~27 wall-min): favor 100
→ the T-115 victory screen ("THE TOWN IS YOURS!", score 510, new high score, 17
cars splatted, 0 tourists), via 17 re-splats of ONE parked visitor car plus 1
tailgate crumb (+1) and 1 accidental table crumb (−1). Parked visitor cars are
re-splattable +6 fountains (cars never flee, splats never dedup) — the owner
noted it may be TOO easy (same route his friend found on a phone); recorded as
an open question on IDEAS.md B-6, not a defect.

**Default-off:** with no command file the recorder behaves byte-identically to
before (paused stays false, the counter stays 0) — every gate runs the old path.

## Acceptance criteria

- [x] *(Gate 1b)* New scenario `pilot_frame_step` drives a real CaptureRecorder
      in session mode plus a pausable inline-script probe (counts live ticks,
      latches flap visibility) through four legs: step-refused-while-unpaused,
      pause freezes the probe dead, `{"step":30}` advances 26-35 live ticks and
      re-freezes, and a same-file flap hold latches `saw_flap` (the deferral
      contract). Tree + env restored however the leg ends. **PASS, suite 0
      failures** (Gate 1b full run, 2026-10-27).
- [x] Gate 1 green: `--import` exits 0 (only the documented godot_mcp teardown
      line), `--quit-after 120` boots clean.
- [x] Deferred presses land on the first live tick — the queue-then-step
      protocol works against a real run (the entire victory run used it).
- [x] VERIFICATION.md carries the agent-play frame-step notes: the commands,
      the paid-for gotchas, the helpers, the 2026-10-27 win recipe, and the
      verify-a-new-feature loop.
- [x] Helpers committed in `tests/tools/` and live-proven after generalization.

## Gotchas recorded (the ones that cost debugging time)

- The unpause lag (raw window → zero player ticks) and its +4 pad.
- The one-tick `is_action_just_pressed` window → defer, don't drop.
- One command file = one pass: lines execute the same tick; sequence via
  separate sends or accept concurrency.
- `events.jsonl`/`state.jsonl` `t_ms` is ENGINE time — never compare against
  wall-clock (a grind script "went blind" this way; count by file line offset).
- Godot yaw: `forward = (-sin yaw, -cos yaw)` — 0 north, ±π south, +π/2 west,
  −π/2 east. Everything else is a sign error waiting to happen.

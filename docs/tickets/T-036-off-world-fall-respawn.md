# T-036 — Guard the off-world fall with a return to the spawn corridor

- **Milestone:** Sweep backlog · **Status:** done (adopted by T-042) · **Category:** code-optimization · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** — (T-001/T-003 flight and T-010's hunger-only fail state are landed)

> **Adopted and landed by [T-042](T-042-off-world-void-respawn.md)** — same guard design
> (this ticket's plan, including the main.gd wiring it adds to the file list), with
> T-042's scenario-sketch correction: the harness scenario starts below the guard at
> y −10 and polls ≤ 120 frames, because the sketched y −2 start never crosses the −5
> line. The landed scenario is named `off_world_fall_respawns`.
- **Refs:** `.captures/session_optperf1/state.jsonl:6990`, `.captures/session_optperf2/state.jsonl:17503` (worktree captures, verified verbatim this session) · sweep 1 planning session

## What

Fly ~370 m in any direction and the pigeon leaves the ground box
(`city.gd:329-331`: the ground spans ±(city_span/2 + ground_extra) =
±(117 + 250) = ±367 m) and falls under the world forever — HUD alive, no
visible floor, no respawn, no run end until starvation minutes later. Nothing
handles it: a grep for bound/edge/apron/void/kill across `player.gd`,
`main.gd` and `city.gd` finds no off-world handling, while the pigeon's own
droppings have a `max_lifetime` self-free for exactly this failure mode
(`scripts/poop.gd:19`).

In `scripts/player.gd`, one guarded branch at the top of `_physics_process`:

- New tunable `@export var off_world_y: float = -5.0` — the guard line,
  unreachable over real terrain: the lowest walkable surface is the ground
  slab top at y = 0 (`city.gd:329-338`).
- New plain var `respawn_point: Vector3 = Vector3.ZERO` — LOCAL coordinates,
  matching `reset_flight`'s convention (it sets `position`, and `main.gd:79`
  already wraps the global spawn point in `city.to_local(...)` for that
  reason).
- When `global_position.y < off_world_y`: `reset_flight(respawn_point)` — the
  existing hard reset (zeroes velocity/timers, AIR state, 2-frame air grace,
  `player.gd:111-125`), after which the pigeon drops the short spawn drop onto
  the corridor and lands normally. Quietly — no sound, no popup; the
  "you flew off and came home" beat is the return itself.
- A public counter `off_world_resets: int` incremented per guard fire (test
  evidence, and proof the reset cannot oscillate: the corridor sits ~360 m
  inside the world, so a second fire would mean the respawn point itself is
  off-world — a bug the counter makes loud).
- `scripts/main.gd` is in the change-set too — the plan's file list omits it,
  but Player has no City reference and cannot compute the corridor itself: in
  `_ready()`, next to the initial `reset_flight` (`main.gd:79`), wire
  `player.respawn_point = city.to_local(city.spawn_point)`. `restart_run()`
  re-calls `reset_flight` with the same value, and the respawn point never goes
  stale in M1 (restart always keeps the same seed).
- Hunger is untouched by design: the clock lives in the autoload and drains on
  its own physics ticks (`hunger.gd:68-80`), independent of position —
  DESIGN's hunger-only fail state survives the reset.

**Design call flagged (decide before landing):** the alternative is treating
off-world as death — end the run, or fade-and-return with a hunger penalty.
M1 ships the free return-home because it keeps the fail state single-caused
(starvation) and stays invisible to players who never leave; revisit if the
return reads as a teleport glitch in Gate 3.

## Why

A run-ruining soft state with hard evidence from the sweep sessions:
`optperf1` shows the pigeon under the slab underside at
`p=[-0.17, -8.93, -671.98]` — ~300 m past the apron edge — (`.captures/session_optperf1/state.jsonl:6990`);
`optperf2` shows it at `p=[16.0, -162.24, -524.44]`, `vel=[0.0, -23.26, -18.95]`,
falling at ~23 m/s out of a 30 m/s dive (`.captures/session_optperf2/state.jsonl:17503`).
A crude autopilot hit the state in 2 of 3 sessions; a player streaking past the
skyline gets minutes of falling with a living HUD and nothing on screen,
escapable only by starving or restarting.

## Acceptance criteria

- [x] Gate 1b scenario `off_world_fall_returns_home` passes *(landed as
      `off_world_fall_respawns` per T-042's corrected sketch)*: a player teleported
      below `off_world_y` (and beyond any floor) is grounded on the respawn
      corridor within ~2 s, the reset fired exactly once (counter == 1, no
      oscillation across the following ~2 s), and hunger kept draining through
      the reset
- [x] No false trigger in ordinary play: every existing flight/landing/density
      scenario stays green (all harness setups start at y ≥ 0.35 and every
      in-scenario fall lands on a floor — the −5 line is never approached)
- [x] The fail state is unchanged: starvation still ends the run exactly once
      (`hunger_game_over_once` green); the reset neither refills nor pauses the
      clock
- [x] No input actions change (no controls-table updates); the only new knobs
      are `off_world_y` and `respawn_point`
- [ ] [screenshot] Gate 3: flying hard past the apron returns you to the spawn
      corridor within a couple of seconds, and it reads as intentional ("came
      home"), not a teleport glitch — **pending human playtest** (tracked on
      T-042, which carries the landed change-set)

## Verification

Gate 1 + Gate 1b, adding `off_world_fall_returns_home` to `tests/sim_test.gd`:
set `_player.respawn_point` to a known point over the flat test ground (the
standalone harness player has no city — `sim_test.gd:49` — so the scenario sets
it directly, mirroring what Main does), attach a fresh local hunger clock
(`Hunger.new()` + `hunger.player = _player`, the `sim_test.gd:734-736` pattern),
record hunger and `off_world_resets`, then
`_set_up(true, Vector3(0.0, -10.0, -400.0), Vector3.ZERO)` — below the guard
AND past where any floor exists, so without the guard the pigeon falls forever.
Poll ≤ 120 frames for `is_grounded` near the respawn point; assert the counter
== 1, hunger loss > 0.2 over the window (the existing glide-leg threshold,
`sim_test.gd:753`), and position stability for ~2 more seconds. Housekeeping:
free the local hunger node. Explicitly re-run: `takeoff_3_flaps`,
`stall_drops`, `stall_recovers`, `hard_landing_skids`, `landing_slides_to_stop`,
`dive_gains_speed`, `pullup_gains_height`, `city_street_flyover`,
`city_roof_takeoff`, `restart_resets_run`, `density_cpu_budget`. Gate 2 (the
autopilot's two known off-world failure modes now self-heal; `ok=true` must
hold). Gate 3: the [screenshot] line above plus confirming the hunger clock
never paused across a return. VERIFICATION.md in the same change-set: new Gate
1b row + new Gate 3 playtest line.

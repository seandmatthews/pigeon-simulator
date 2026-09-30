# T-042 — Guard the off-world void: respawn at the spawn corridor (adopt T-036)

- **Milestone:** Sweep 2 · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** — (T-001/T-003 flight and T-010's hunger-only fail state are landed). Adopts
  [T-036](T-036-off-world-fall-respawn.md) — mark that ticket done/superseded when this lands;
  T-023's banked home-nudge stays the softer follow-up, not the first fix.
- **Refs:** sweep-2 planning sessions, `.captures/session_flcs2-a/` (state.jsonl line 14589 and
  void_shot.png verified verbatim at ticket-writing time; the captures live in the
  flight-control-s2 worktree) · [T-036](T-036-off-world-fall-respawn.md)

## What

Fly ~370 m in any direction and the pigeon leaves the ground box — the ground slab spans
±(city_span/2 + ground_extra) = ±(117 + 250) = ±367 m (`scripts/city.gd:67` `ground_extra`,
`scripts/city.gd:165` `city_span`, `scripts/city.gd:368-369` `_build_ground`) — then glides
over an empty plane and sinks under the world until starvation. Nothing handles it: no
bound/edge/void/kill logic exists anywhere in `player.gd`, `main.gd` or `city.gd`.

Adopt T-036's minimal guard. Two files, one commit:

`scripts/player.gd`:

- `@export var off_world_y: float = -5.0` — the guard line. Unreachable over real terrain:
  the lowest walkable surface is the ground slab top at y = 0.
- `var respawn_point: Vector3 = Vector3.ZERO` — plain var, **LOCAL** coordinates, matching
  `reset_flight`'s `position` convention (`scripts/player.gd:112-125`).
- `var off_world_resets: int = 0` — public counter: test evidence, and proof the reset
  cannot oscillate (the corridor sits ~360 m inside the box; a second fire would mean the
  respawn point itself is off-world — the counter makes that loud).
- One guarded branch at the **top of `_physics_process`** (`scripts/player.gd:129`), before
  the state machine: when `global_position.y < off_world_y`, increment the counter and call
  the existing `reset_flight(respawn_point)` — velocity/timers zeroed, AIR state, 2-frame
  air grace (`scripts/player.gd:112-125`) — after which the pigeon drops the short spawn
  drop onto the corridor and lands normally. Quietly: no sound, no popup; the return is
  the beat.

`scripts/main.gd` — in the change-set because Player has no City reference and cannot
compute the corridor: in `_ready()`, next to the initial reset (`scripts/main.gd:84`), wire
`player.respawn_point = city.to_local(city.spawn_point)`. `restart_run()` re-calls
`reset_flight` with the same value (`scripts/main.gd:247`), and the respawn point never
goes stale in M1 (restart always keeps the same seed).

Hunger is untouched by design: the clock drains on its own physics ticks, independent of
position (`scripts/hunger.gd:68-80`) — the hunger-only fail state survives the reset. No
input actions change (no controls-table updates).

**Scenario sketch correction (must):** the planning sketch
`_set_up(true, Vector3(0, -2, 0), Vector3(0, 0, -15))` + 30 frames is broken as written —
from y −2 the sink builds slowly and reaches only ≈ y −2.4 by frame 30, so the guard at −5
never fires and `off_world_resets == 1` can never pass. Start **below** the guard (y −10,
per T-036's own sketch) and poll up to 120 frames.

What this does **not** claim: no HUD/popup beat (the quiet return is the design; revisit
only if Gate 3 reads it as a teleport glitch), no edge nudge (T-023 remains a separate
follow-up), and the M1 respawn point is static by construction.

## Why

A run-ruining soft state, hit in all three sweep-2 planning sessions with zero deliberate
effort. Verified: flcs2-a `state.jsonl` line 14589 is exactly
`p=[16.0, -80.62, -2080.91], vel=[0.0, -1.04, -14.46]` (fwd 14.46, not stalled) — ~2.1 km
out, 80 m under an empty plane, HUD alive, no floor, no fail state; the run ended minutes
later on the STARVED! screen with the HUD still reading "city 2429 m"
(`.captures/session_flcs2-a/void_shot.png`; `game_over` at t_ms 268130 in `events.jsonl`).
flcs2-b ended the same way (`game_over` at t_ms 250277); flcs2-c's final glide was still
outbound. The 36:1 glide makes crossing ±367 effortless — a player streaking past the
skyline gets minutes of falling and a dead run, escapable only by starving or restarting.

## Acceptance criteria

- [ ] Gate 1b scenario `off_world_fall_respawns` passes: the player placed below
      `off_world_y` and beyond any floor is grounded on the respawn point within ~2 s;
      `off_world_resets == 1`; velocity finite throughout; no second fire across a further
      ~2 s
- [ ] Hunger keeps draining through the reset: loss > 0.2 across the scenario window (the
      existing glide-leg threshold, `tests/sim_test.gd:797`) — the reset neither refills
      nor pauses the clock (`hunger_game_over_once` stays green)
- [ ] No false trigger in ordinary play: every existing flight/landing/density scenario
      stays green (all harness `_set_up` positions are y ≥ 0.4 and every in-scenario fall
      lands on a floor — the −5 line is never approached)
- [ ] No input actions change (no README/VERIFICATION controls-table updates); the only
      new knobs are `off_world_y` and `respawn_point`
- [ ] [screenshot] Gate 3: flying hard past the apron returns you to the spawn corridor
      within a couple of seconds, and it reads as intentional ("came home"), not a
      teleport glitch

## Verification

Gate 1 + Gate 1b, adding `off_world_fall_respawns` to `tests/sim_test.gd` (record a fresh
baseline on the untouched tree first): set `_player.respawn_point` to a known point over
the flat test ground (the harness player has no city wired — `tests/sim_test.gd:50` — so
the scenario sets it directly, mirroring what Main does); attach a fresh local hunger
clock (`Hunger.new()` + `hunger.player = _player` + `add_child`, the
`_scenario_hunger_drain` pattern at `tests/sim_test.gd:777-780`; `free()` it after, as
that scenario's housekeeping does); then
`_set_up(true, Vector3(0.0, -10.0, -400.0), Vector3.ZERO)` — below the guard AND past
where any floor exists (the harness ground spans z ±100, `tests/sim_test.gd:61`), so
without the guard the pigeon falls forever. Poll ≤ 120 frames for `is_grounded` within
~2 m of the respawn point; assert the counter == 1, `velocity.is_finite()`, hunger
loss > 0.2 over the window; then ~120 more frames of position stability with the counter
still 1. Add the VERIFICATION.md Gate 1b row and a Gate 3 playtest line in the same
change-set. Explicitly re-run: `takeoff_3_flaps`, `stall_drops`, `stall_recovers`,
`hard_landing_skids`, `landing_slides_to_stop`, `dive_gains_speed`, `pullup_gains_height`,
`city_street_flyover`, `city_roof_takeoff`, `city_plaza_spawn`, `restart_resets_run`,
`restart_same_seed_skips_rebuild`, `hunger_drain_flap_vs_glide`, `hunger_game_over_once`,
`density_cpu_budget`. Gate 2: the autoplay pilot's off-world failure modes now self-heal —
`ok=true` must hold. Gate 3: the [screenshot] line above, plus confirming the hunger clock
never paused across a return.

**Design call flagged (decide before landing):** the alternative is treating off-world as
death — end the run, or fade-and-return with a hunger penalty. M1 ships the free
return-home (it keeps the fail state single-caused and stays invisible to players who
never leave); revisit if Gate 3 reads the return as a teleport glitch.

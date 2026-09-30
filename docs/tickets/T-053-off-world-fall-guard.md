# T-053 — Land the off-world fall guard: falling past the apron returns you home

- **Milestone:** Sweep backlog · **Status:** done · **Category:** code-optimization · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** — (T-001/T-003 flight and T-010's hunger-only fail state are landed) · implements **T-036** as specified — land it under this ID and flip T-036 to done in the same commit; do not implement twice
- **Refs:** sweep 2 planning lane (code-optimization) · all line numbers verified on commit b76ec96, this tree

## What

A guarded branch at the very top of `Player._physics_process` (`scripts/player.gd:129`).
Today nothing handles leaving the world: `_physics_process` (player.gd:129-145) runs
timers, the state machine and `_air_physics` with no bound of any kind, so past the
ground box's edge the pigeon simply falls forever.

- New export `@export var off_world_y: float = -5.0` — the guard line. Unreachable
  over real terrain: the lowest walkable surface is the ground slab top at y = 0, and
  the ground box spans ±(city_span/2 + ground_extra) = ±(117 + 250) = ±367 m
  (`_build_ground`, `city.gd:368-370`; span getter `city.gd:165-166` — 7 blocks × 32 m
  pitch + 10 m road = 234 m).
- New plain var `respawn_point: Vector3 = Vector3.ZERO` — LOCAL coordinates, matching
  `reset_flight`'s convention (it assigns `position`, `player.gd:112-126`).
- When `global_position.y < off_world_y`: increment a public
  `var off_world_resets: int = 0` and call the existing hard reset
  `reset_flight(respawn_point)`, then return for that frame — `reset_flight` already
  establishes the full state (zeroed velocity/timers, AIR, 2-frame air grace), so the
  rest of the frame would only re-run the flight model on a freshly teleported body.
  Quietly — no sound, no popup; the "you flew off and came home" beat is the return
  itself.
- `off_world_resets` is the test evidence and the oscillation alarm: the respawn
  corridor sits ~360 m inside the world, so a second fire would mean the respawn
  point itself is off-world — a bug the counter makes loud.
- `scripts/main.gd` is in the change-set: Player has no City reference and cannot
  compute the corridor itself. In `_ready()`, next to the initial `reset_flight`
  (`main.gd:84`), wire `player.respawn_point = city.to_local(city.spawn_point)`.
  `restart_run()` (`main.gd:236-248`) re-calls `reset_flight` with the same corridor
  and M1's restart always keeps the same seed, so the respawn point never goes stale.
- Hunger is untouched by design: the autoload's clock drains `rate * delta` per
  physics tick regardless of position (`scripts/hunger.gd:68-80`), so DESIGN's
  hunger-only fail state survives the reset.

What this does NOT do: no death/penalty variant (T-036's design call, resolved — M1
ships the free return-home so the fail state stays single-caused), no input changes,
no scene changes, no new HUD element.

## Why

A run-ruining soft state: fly ~370 m past the city (the apron edge, above) and the
pigeon leaves the ground box and falls under the world with the HUD alive — no floor,
no respawn, no run end until starvation minutes later. The sweep-2 planning lane
reported reproducing it in 2 of 2 unattended pilot sessions (a fall trace passing
−20 m at z ≈ −1185 while hunger drained, then `game_over` minutes later at y ≈ −160
with the scene still Main and the HUD reading "city 3128 m") — those capture sessions
are no longer in the tree, so the trace values are not re-verifiable here. What IS
verified by direct read this session is the mechanism: no bound/edge/respawn handling
anywhere in `player.gd:129-145` or `main.gd`, a finite ground box (`city.gd:368-370`)
beyond which gravity never ends, and that the only self-rescue in the codebase is the
pigeon's own droppings — `Poop.max_lifetime` frees a drop that hit nothing
(`scripts/poop.gd:19`), for exactly this failure mode. A player streaking past the
skyline gets minutes of falling with nothing on screen, escapable only by starving or
restarting.

## Acceptance criteria

- [x] Gate 1b scenario `off_world_fall_returns_home` passes (spec in Verification):
      a pigeon teleported below `off_world_y` AND past every floor is grounded on the
      respawn point within ≤ 120 physics frames, the guard fired exactly once
      (`off_world_resets == 1`, no second fire across the following ~2 s of
      stability), and hunger kept draining through the reset (loss > 0.2 over the
      window)
- [x] No false trigger in ordinary play: every existing flight/landing/density
      scenario stays green — all harness setups start at y ≥ 0.35 and every
      in-scenario fall lands on a floor, so the −5 line is never approached
- [x] The fail state is unchanged: `hunger_game_over_once` stays green; the reset
      neither refills nor pauses the hunger clock
- [x] No input actions change (no controls-table updates needed); the only new knobs
      are `off_world_y` and `respawn_point`
- [ ] [screenshot] Gate 3: flying hard past the apron returns you to the spawn
      corridor within a couple of seconds, and it reads as intentional ("came
      home"), not a teleport glitch — **pending human playtest** (machine gates all
      green; the line is in VERIFICATION.md's Gate 3 checklist with its
      hunger-never-paused companion, and the drain-through half is machine-covered
      by this ticket's criterion 1)

## Verification

Gate 1 (import + 120-frame boot, both exit 0, zero ERROR lines). Gate 1b, adding
`off_world_fall_returns_home` to `tests/sim_test.gd`:

- The harness player is a loose node instantiated over the flat test world
  (`sim_test.gd:50`, ground box at `sim_test.gd:61`), not wired to any city — the
  scenario sets `_player.respawn_point` directly to a known point over the flat
  ground (e.g. `Vector3(0.0, 0.35, 0.0)`), mirroring what Main does.
- Attach a fresh local hunger clock (`Hunger.new()` + `hunger.player = _player`, the
  `sim_test.gd:778-780` pattern); record hunger and `off_world_resets`.
- `_set_up(true, Vector3(0.0, -10.0, -400.0), Vector3.ZERO)` — below the −5 guard AND
  past every floor (the flat world ends at ±100 m, the harness city sits at
  (2000, 0, 2000)), so without the guard the pigeon falls forever.
- Poll ≤ 120 frames for `is_grounded` near the respawn point (the `_await_grounded`
  pattern, `sim_test.gd:207`); assert `off_world_resets == 1`, hunger loss > 0.2 over
  the window (the existing glide-leg threshold, `sim_test.gd:796-797`), then position
  stability for ~2 more seconds. Housekeeping: free the local hunger node (the
  `hunger.free()` pattern, `sim_test.gd:800`).

Explicitly re-run: `takeoff_3_flaps`, `stall_drops`, `stall_recovers`,
`hard_landing_skids`, `landing_slides_to_stop`, `dive_gains_speed`,
`pullup_gains_height`, `city_street_flyover`, `city_roof_takeoff`,
`restart_resets_run`, `hunger_game_over_once`, `density_cpu_budget`. Gate 2 (the
autopilot's known off-world failure modes now self-heal; `ok=true` must hold). Gate 3:
the [screenshot] line above plus confirming the hunger clock never paused across a
return. VERIFICATION.md in the same change-set: new Gate 1b row + new Gate 3 playtest
line.

Implementer note: run the gates on a quiet machine — `density_cpu_budget` is
machine-relative and false-FAILs under fleet load (the planning lane measured
1662.9 ms median vs the 750 budget with ~10 fleet Godot processes sharing the box;
the scenario itself warns about this at `sim_test.gd:2874-2876`).

## Landed

This ticket says to implement [T-036](T-036-off-world-fall-respawn.md) "do not implement
twice" — and that work is already in the tree, landed under two IDs: commit `0a08d8e`
(T-036's guard plus this ticket's named `off_world_fall_returns_home` scenario, its
Gate 1b row and both Gate 3 lines) and commit `c2cf7f4` (T-042's adoption, which added
its own `off_world_fall_respawns` scenario). T-036 is flipped done ("done (adopted by
T-042)"). This change-set therefore lands only the ticket bookkeeping and re-verifies
the criteria under this ID — no second implementation.

Landed shape, as adopted: `@export var off_world_y: float = -5.0` (`scripts/player.gd:55`),
`respawn_point` in local coordinates (`scripts/player.gd:60`), `off_world_resets`
(`scripts/player.gd:64`), the guarded branch at the top of `Player._physics_process`
(`scripts/player.gd:157-159`) incrementing the counter then calling
`reset_flight(respawn_point)`; `Main._ready()` wires
`player.respawn_point = city.to_local(city.spawn_point)` (`scripts/main.gd:93`). One
deviation from this ticket's sketch, deliberate in the adopted landing: the guard does
not `return` for that frame — T-042's spec lets the frame continue so the pigeon "drops
the short spawn drop onto the corridor and lands normally", which differs only by one
frame of air physics on the freshly teleported body (identical state either way —
`reset_flight` zeroes velocity/timers, sets AIR and the 2-frame air grace). Both guard
scenarios assert the exactly-one fire and the 2 s stability this ticket requires, so the
criteria hold under either shape.

Gates re-run this session on the final tree (quiet machine, `Godot_v4.7.2-stable_win64_console.exe`):

- Gate 1: `--headless --path . --import` exit 0 (its one output line is the documented
  benign "ERROR: 33 resources still in use at exit" addon-shutdown bookkeeping, same as
  T-042's landing) and `--headless --path . --quit-after 120` exit 0 with zero ERROR lines.
- Gate 1b: `--headless --fixed-fps 60 --path . res://tests/sim_test.tscn` exit 0 —
  81 SIM PASS, `SIM SUMMARY: 0 failure(s)`, including `off_world_fall_returns_home`,
  `off_world_fall_respawns`, `hunger_game_over_once` and every scenario in this ticket's
  explicit re-run list; `density_cpu_budget` median 262.0 ms vs the 750 budget.
- Gate 2: `--path . res://tests/autoplay.tscn` exit 0 — `AUTOPLAY DONE ok=true …
  restart=true` (t=33.0, fps=134, splats=13, ambience=true), no SCRIPT ERROR lines.

Verification coverage: the Gate 1b row (`off_world_fall_returns_home`,
`VERIFICATION.md:121`) and the two Gate 3 playtest lines (`VERIFICATION.md:293-294`)
landed in the same change-sets that shipped the feature and are tagged T-036 — not
duplicated under this ID.

Gate 3 pending (human): the [screenshot] criterion above — the return reading as "came
home", not a teleport glitch, and the hunger bar visibly ticking through a return.

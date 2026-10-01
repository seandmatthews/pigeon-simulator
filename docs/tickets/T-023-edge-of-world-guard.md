# T-023 — Edge-of-world guard: nudge the pigeon home past the apron

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** T-004 (city span / ground_extra geometry) · T-001 (the steer term it extends) · builds on the landed T-036/T-042/T-053 off-world teleport guard (this ticket is the prevention layer *ahead* of it, as T-042 itself positions it)
- **Refs:** re-based to the guarded tree during the 2026-09-30 backlog audit (original written 2026-09-29, pre-guard; flight-control review-lane sessions from that sweep, `.captures/session_flc-s1-b/`, are pre-guard history) · untouched-tree baseline `.captures/sim_baseline_tkwriter.txt` (73/73 on the sweep-1 tree; the suite is 87 scenarios today — see Verification)

## What

Beyond a soft radius past the city, blend a gentle banked yaw toward home so
straight-line escape into the void becomes impossible — never a hard grab.
The hard stop already exists: T-036/T-042 landed a teleport guard
(`off_world_y` −5 → `reset_flight(respawn_point)`, `scripts/player.gd:59` and
`:161-163`, wired at `scripts/main.gd:88-95`, machine-verified by
`off_world_fall_respawns` / `off_world_fall_returns_home`,
`tests/sim_test.gd:583-617` and `:161`). But the guard is silent while it
matters: the player gets no feedback during the long outbound fall, then the
world hard-cuts. This ticket adds the readable layer *before* the fall:
a nudge that makes straight-line escape impossible and a hint that says why.

Touches `scripts/player.gd` + `scripts/main.gd` (+ `tests/sim_test.gd`). **No
.tscn edits:** the hint reuses the existing unique-named `%HintLabel`
(`scenes/main.tscn:119-120`, resolved at `scripts/main.gd:41`).

`scripts/player.gd` — the flight model has **zero reference to the city
today** (the T-042 guard imports are Main-wired for the same reason), so the
nudge needs new wiring exports:

- `home_center: Vector3 = Vector3.ZERO` and `home_radius: float = 0.0` —
  **0.0 disables the nudge entirely**, so every scene and scenario that
  doesn't wire it (including all existing guard scenarios) is unaffected by
  construction.
- `home_nudge_rate: float = <tuned>` (1/s) plus a ramp width (suggest ~100 m):
  in `_steer` (`scripts/player.gd:367-379`), beyond `home_radius` add a
  yaw/bank term toward `home_center`, scaled by
  `clampf((flat_distance - home_radius) / ramp, 0.0, 1.0)` and riding the
  existing bank/yaw path, capped well under `max_bank_deg` — the player's own
  turn input must still be able to overpower it.

Interaction with the landed guard, stated explicitly: the nudge acts
horizontally while airborne past the radius; the guard fires only on
`global_position.y < off_world_y`. A player who fights the nudge all the way
out can still trigger the teleport — that is the intended layering
(prevention first, failsafe second). `reset_flight` touches position/velocity/
attitude only, so the nudge exports survive a guard reset and keep working if
the pigeon flies out again. The guard's respawn corridor sits inside the
nudge radius, so a teleported pigeon is immediately back in normal territory.

`scripts/main.gd` — wire it (the refs already exist at `scripts/main.gd:51-52`):

- In `_ready()`: `player.home_center = city.global_position` (the span is
  symmetric about the City origin) and `player.home_radius = city.city_span *
  0.5 + city.ground_extra` — **367 m** at defaults (117 + 250): the ground
  collider is exactly `city_span + ground_extra * 2` wide
  (`scripts/city.gd:421`, `ground_extra` 250 at `scripts/city.gd:103`, span
  getter at `scripts/city.gd:211-212`; span = 7 × (22 + 10) + 10 = **234 m**,
  so the radius sits ~250 m beyond the city edge). One wiring in `_ready()`
  is enough: `restart_run()` regenerates the same-seed city in place
  (`scripts/main.gd:280`, generate at `:290`), so the geometry never moves —
  the same argument the T-042 respawn wiring already makes.
- HUD hint: const `HINT_EDGE := "Nothing out there — turn back"`. In
  `_process()`, while airborne and past `home_radius`, show it on
  `%HintLabel`; on coming back inside (or on grounding — which includes the
  guard's teleport, whose drop lands at the corridor) restore the normal
  air/ground hint. Coordinate with the existing hint swap
  `_on_grounding_changed` (`scripts/main.gd:309-310`, consts at
  `scripts/main.gd:12-13`) via a small `_edge_hinting` flag so the two
  writers don't fight.

**Harness:** the sim city sits at (2000, 0, 2000) (`tests/sim_test.gd:66-67`);
only the new scenario wires `home_center`/`home_radius` manually — every other
scenario runs with the nudge disabled, which is what keeps in-city handling
green by construction (the 367 m radius sits ~250 m beyond the 234 m span).

What this does **not** claim: not a wall, not a teleport (the teleport is
T-042's, already landed), not damage, not a failsafe against every void (it
assumes a roughly circular world centered on `home_center`); it only makes
straight-line escape impossible so the player always has ground to return to.

## Why

On the sweep-1 tree (2026-09-29) flying ~400 m outward left the ground slab
entirely and the pigeon fell into a bottomless void with zero feedback —
session b ended still "airborne" in the void at p=(−1642, −57, −655). That
evidence produced T-036/T-042/T-053, which shipped the teleport failsafe on
2026-09-30. What remains is the experience problem: between the apron edge
and `off_world_y` (−5) the player gets no feedback at all, and the guard's
rescue is a blank-frame hard cut (T-087 covers the return beat; this ticket
covers the outbound read). A soft banked turn home with a hint makes the
world legible before the failsafe is ever needed — and the failsafe stays
for anyone who fights it.

Nothing in game code homes today apart from the T-042 guard's vertical
teleport: `_steer` has no homing term, and the only horizontal homing in the
repo is the autoplay pilot's (`tests/autoplay.gd:28`, `HOME_RADIUS = 40.0` —
note `VERIFICATION.md:150`'s "beyond 60 m" prose is stale against that
constant; refresh it while touching the file).

## Acceptance criteria

- [ ] Reset ~300 m past the apron edge (home + (half_span + 300, 30, 0)),
      flying straight out, hands off for 3 s (180 frames): the heading rotates
      ≥ 30° back toward home and y never drops below 0 — today's tree holds
      course (`_steer` has no homing term) and the landed teleport guard never
      fires inside the window (from y = 30 the fall stays far above −5), so
      the heading assertion fails before (Gate 1b: `edge_nudge_turns_home`)
- [ ] In-city handling is untouched: `banked_left_turn` (at the origin,
      `tests/sim_test.gd:346`) and `city_street_flyover` (inside the span,
      `tests/sim_test.gd:672-692`) stay green — the nudge is disabled by
      default and its radius sits ~250 m beyond the whole city
- [ ] The landed guard layering holds: `off_world_fall_respawns`
      (`tests/sim_test.gd:583-617`) and `off_world_fall_returns_home`
      (`tests/sim_test.gd:161`) stay green unchanged — the guard must not
      depend on the nudge, and the nudge must not disable the guard
- [ ] The guard never hard-grabs: with the nudge active, a held player turn
      can still hold course against it (Gate 3 playtest line)
- [ ] [screenshot] The HUD shows the turn-back hint past the apron and the
      normal air/ground hint again once back inside — no hint-writer fight
      across a landing/takeoff cycle at the boundary

## Verification

Gate 1 (import + 120-frame boot — the `--check-only --script` leg is broken
repo-wide and stays dropped per `VERIFICATION.md:343-348`) + Gate 1b full
suite green — the suite is 87 scenarios on today's tree (0 failures, measured
during the 2026-09-30 audit); the new scenario makes it 88;
`edge_nudge_turns_home` wiring: `_player.home_center = _city.position`,
`_player.home_radius = _city.city_span * 0.5 + _city.ground_extra`, then
`_set_up(true, home + Vector3(half + 300, 30, 0), Vector3(17, 0, 0), -90.0)`
(nose +X, away from home); read the heading from `-transform.basis.z` the way
the flight scenarios do (`tests/sim_test.gd:400`); `city_street_flyover`,
`banked_left_turn`, `off_world_fall_respawns` and `off_world_fall_returns_home`
explicitly re-run; `VERIFICATION.md`'s Gate 1b table gains the
`edge_nudge_turns_home` row (and the stale "beyond 60 m" Gate 2 prose at
`VERIFICATION.md:150` is refreshed) — + Gate 2 (the pilot already arcs home
well inside the radius; unaffected) + Gate 3.

**Pending human playtest (Gate 3):** the hint text reads and disappears
correctly at the boundary; the nudge feels like a pigeon wanting to go home —
present, never a control grab — and an outward turn can still win against it.

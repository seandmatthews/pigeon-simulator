# T-023 — Edge-of-world guard: nudge the pigeon home past the apron

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** T-004 (city span / ground_extra geometry) · T-001 (the steer term it extends)
- **Refs:** flight-control review-lane play sessions (2026-09-29, `.captures/session_flc-s1-b/`);
  baseline Gate 1b on today's tree re-run during ticket-writing: exit 0, 73/73 PASS
  (`.captures/sim_baseline_tkwriter.txt`)

## What

Beyond a soft radius past the city, blend a gentle banked yaw toward home so
straight-line escape into the void becomes impossible — never a hard grab.
Touches `scripts/player.gd` + `scripts/main.gd` (+ `tests/sim_test.gd`). **No
.tscn edits:** the hint reuses the existing unique-named `%HintLabel`
(`scenes/main.tscn:88`, resolved at `scripts/main.gd:38`).

`scripts/player.gd` — the flight model has **zero reference to the city
today**, so the guard needs new wiring exports:

- `home_center: Vector3 = Vector3.ZERO` and `home_radius: float = 0.0` —
  **0.0 disables the guard entirely**, so every scene and scenario that
  doesn't wire it is unaffected by construction.
- `home_nudge_rate: float = <tuned>` (1/s) plus a ramp width (suggest ~100 m):
  in `_steer` (`scripts/player.gd:320-332`), beyond `home_radius` add a
  yaw/bank term toward `home_center`, scaled by
  `clampf((flat_distance - home_radius) / ramp, 0.0, 1.0)` and riding the
  existing bank/yaw path, capped well under `max_bank_deg` — the player's own
  turn input must still be able to overpower it.

`scripts/main.gd` — wire it (the refs already exist at `scripts/main.gd:42-43`):

- In `_ready()`: `player.home_center = city.global_position` (the span is
  symmetric about the City origin) and `player.home_radius = city.city_span *
  0.5 + city.ground_extra` — ≈ **327 m** at defaults: the ground collider is
  exactly `city_span + ground_extra * 2` wide (`scripts/city.gd:330-331`,
  `ground_extra` 250 at `scripts/city.gd:55`, span getter at
  `scripts/city.gd:141`). One wiring in `_ready()` is enough:
  `restart_run()` regenerates the same-seed city in place
  (`scripts/main.gd:197`), so the geometry never moves.
- HUD hint: const `HINT_EDGE := "Nothing out there — turn back"`. In
  `_process()`, while airborne and past `home_radius`, show it on
  `%HintLabel`; on coming back inside (or on grounding) restore the normal
  air/ground hint. Coordinate with the existing hint swap
  `_on_grounding_changed` (`scripts/main.gd:216-217`, consts at
  `scripts/main.gd:11-12`) via a small `_edge_hinting` flag so the two
  writers don't fight.

**Harness:** the sim city sits at (2000, 0, 2000) (`tests/sim_test.gd:63-64`);
only the new scenario wires `home_center`/`home_radius` manually — every other
scenario runs with the guard disabled, which is what keeps in-city handling
green by construction (327 m ≫ the 154 m span).

What this does **not** claim: not a wall, not a teleport, not damage, not a
failsafe against every void (it assumes a roughly circular world centered on
`home_center`); it only makes straight-line escape impossible so the player
always has ground to return to.

## Why

Flying ~400 m outward leaves the ground slab entirely and the pigeon falls
into a bottomless void with zero feedback: session b ended at
p=(-1642.31, -56.73, -654.82), fwd 16.68, grounded=false — still "airborne"
in the void when the run froze (final live row t=352426) — and
`.captures/session_flc-s1-b/shot_climb.png` shows empty green to the horizon
at 38 m. Nothing in game code homes today (verified by reading `player.gd`,
`main.gd`, `city.gd`); the only homing behavior in the repo is the autoplay
pilot's (`tests/autoplay.gd:28`, `HOME_RADIUS = 40.0` — note
`VERIFICATION.md:136`'s "beyond 60 m" prose is stale against that constant;
refresh it while touching the file).

## Acceptance criteria

- [ ] Reset ~300 m past the apron edge (home + (half_span + 300, 30, 0)),
      flying straight out, hands off for 3 s (180 frames): the heading rotates
      ≥ 30° back toward home and y never drops below 0 — today's tree flies
      straight into the void (`_steer` has no homing term) so this fails
      before (Gate 1b: `edge_nudge_turns_home`)
- [ ] In-city handling is untouched: `banked_left_turn` (at the origin) and
      `city_street_flyover` (inside the span, `tests/sim_test.gd:542-562`)
      stay green — the guard is disabled by default and its radius sits ~170 m
      beyond the whole city
- [ ] The guard never hard-grabs: with the nudge active, a held player turn
      can still hold course against it (Gate 3 playtest line)
- [ ] [screenshot] The HUD shows the turn-back hint past the apron and the
      normal air/ground hint again once back inside — no hint-writer fight
      across a landing/takeoff cycle at the boundary

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script
res://scripts/player.gd`) + Gate 1b full suite green — baseline on today's
tree measured exit 0, 73/73 PASS; the new scenario makes it 74;
`edge_nudge_turns_home` wiring: `_player.home_center = _city.position`,
`_player.home_radius = _city.city_span * 0.5 + _city.ground_extra`, then
`_set_up(true, home + Vector3(half + 300, 30, 0), Vector3(17, 0, 0), -90.0)`
(nose +X, away from home); read the heading from `-transform.basis.z` the way
`camera_follows_yaw` does (`tests/sim_test.gd:383-387`); `city_street_flyover`
and `banked_left_turn` explicitly re-run; `VERIFICATION.md`'s Gate 1b table
gains the `edge_nudge_turns_home` row (and the stale "beyond 60 m" Gate 2
prose is refreshed) — + Gate 2 (the pilot already arcs home well inside the
radius; unaffected) + Gate 3.

**Pending human playtest (Gate 3):** the hint text reads and disappears
correctly at the boundary; the nudge feels like a pigeon wanting to go home —
present, never a control grab — and an outward turn can still win against it.

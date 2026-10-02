# T-023 — Edge-of-world guard: nudge the pigeon home past the apron

- **Milestone:** Sweep backlog · **Status:** done · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** T-004 (city span / ground_extra geometry) · T-001 (the steer term it extends) · builds on the landed T-036/T-042/T-053 off-world teleport guard and its landed presentation (T-087's return beat, T-095's pilot visibility) — this ticket is the prevention layer *ahead* of the guard, as T-042 itself positions it
- **Refs:** re-based onto the guarded tree during the 2026-09-30 backlog audit (original written
  2026-09-29, pre-guard; commit 77e08e5), then re-checked 2026-10-01 against the tree with
  T-087/T-095 landed — flight-control review-lane sessions from sweep 1
  (`.captures/session_flc-s1-b/`) are pre-guard history · untouched-tree baseline
  `.captures/sim_baseline_tkwriter.txt` (73 SIM PASS lines — the sweep-1 record, historical;
  today's suite is 110 scenarios — see Verification)

## What

Past the apron the pigeon has no floor, no fail state but starvation — and no
feedback: nothing bends the course, and the only stop is the landed teleport
guard (`off_world_y` −5 → `off_world_reset(from)` emitted →
`reset_flight(respawn_point)`, `scripts/player.gd:74` and `:176-179`). That
guard is no longer a silent hard cut — since T-087 Main presents the return
(feather poof at `from`, deferred chase-camera snap, warm fade, "home again"
note; connect `scripts/main.gd:105`, handler `:337-346`) and since T-095 the
fire is machine-counted and pilot-visible (`off_world_fall_returns_home`,
`VERIFICATION.md:136`; the pilot events line, `VERIFICATION.md:645-650`). But
everything *before* the fall is still illegible: the flight model has no
homing term, and nothing names the edge. (The bread pointer's "city N m" home
mode beyond half the span, `scripts/main.gd:219-223`, is wayfinding only —
nothing acts on it.) This ticket adds the readable layer before the fall: a
nudge that makes straight-line escape impossible and a hint that says why.

Touches `scripts/player.gd` + `scripts/main.gd` (+ `tests/sim_test.gd`). **No
.tscn edits:** the hint reuses the existing unique-named `%HintLabel`
(`scenes/main.tscn:119-120`, resolved at `scripts/main.gd:53`).

`scripts/player.gd` — the flight model has **zero reference to the city
today** (the T-042 guard's respawn point is Main-wired for the same reason),
so the nudge needs new wiring exports:

- `home_center: Vector3 = Vector3.ZERO` and `home_radius: float = 0.0` —
  **0.0 disables the nudge entirely**, so every scene and scenario that
  doesn't wire it (including all existing guard scenarios and the bare
  harness player) is unaffected by construction.
- `home_nudge_rate: float = <tuned>` (1/s) plus a ramp width (suggest ~100 m):
  in `_steer` (`scripts/player.gd:391-417`), while airborne and beyond
  `home_radius` from `home_center` (flat horizontal distance, global space),
  add a yaw/bank term toward `home_center`, scaled by
  `clampf((flat_distance - home_radius) / ramp, 0.0, 1.0)` and riding the
  existing bank/yaw path, capped well under `max_bank_deg` (40,
  `scripts/player.gd:59`) — the player's own turn input must still be able to
  overpower it.

Interaction with the landed guard, stated explicitly: the nudge acts
horizontally while airborne past the radius; the guard fires only on
`global_position.y < off_world_y` (`scripts/player.gd:176`). A player who
fights the nudge all the way out can still trigger the teleport — that is the
intended layering (prevention first, failsafe second). `reset_flight`
(`scripts/player.gd:150-164`) touches position/rotation/velocity/_roll/timers/
state only, so the nudge exports survive a guard reset and keep working if the
pigeon flies out again. The respawn corridor sits well inside the nudge radius
(the guard's own comment, `scripts/player.gd:80-83`), so a teleported pigeon
is immediately back in normal territory.

Composition with the landed return beat: the reset moment belongs to T-087 —
this ticket adds nothing at the guard's fire and must not touch its quiet
contract (no sound, no popup; `scripts/player.gd:168-175`). After a teleport
the pigeon is back inside the radius, so the edge-hint condition below
self-clears on the next `_process` frame and grounding then hands the label
back to `_on_grounding_changed`. T-088's distant skyline towers
(`scripts/city.gd:140`, `:354`, `:557`) already soften the void's *look*; they
do nothing for the turn-back decision.

`scripts/main.gd` — wire it:

- In `_ready()`: `player.home_center = city.global_position` (the span is
  symmetric about the City origin) and `player.home_radius = city.city_span *
  0.5 + city.ground_extra` — **367 m** at defaults (117 + 250): the ground
  collider is exactly `city_span + ground_extra * 2` wide
  (`scripts/city.gd:528-529`, `ground_extra` 250 at `scripts/city.gd:162`,
  span getter at `scripts/city.gd:285-286`; span = 7 × (22 + 10) + 10 = **234
  m** — constants `scripts/city.gd:159-161`, pitch getter `:281-282` — so the
  radius sits ~250 m beyond the city edge). One wiring in `_ready()` is
  enough: `restart_run()` regenerates the same-seed city in place
  (`scripts/main.gd:411`, generate at `:430`), so the geometry never moves —
  the same argument the T-042 respawn wiring already makes
  (`scripts/main.gd:120-131`).
- HUD hint: const `HINT_EDGE := "Nothing out there — turn back"` beside the
  existing hint consts (`scripts/main.gd:12-13`). In `_process()`, while
  `home_radius > 0.0` and airborne and past `home_radius`, show it on
  `%HintLabel`; on coming back inside (or on grounding — which includes the
  guard's teleport, whose drop lands at the corridor) restore the normal
  air/ground hint. Coordinate with the existing hint writer
  `_on_grounding_changed` (`scripts/main.gd:455-456` — still the only other
  one) via a small `_edge_hinting` flag so the two writers don't fight. The
  T-087 beat's elements (`%ReturnFade` `scripts/main.gd:75`, `%HomeNote`
  `:71`) are separate UI — the edge hint must leave them alone.

**Harness:** the sim city sits at (2000, 0, 2000) (`tests/sim_test.gd:84`);
only the new scenario wires `home_center`/`home_radius` manually — every other
scenario runs with the nudge disabled, which is what keeps in-city handling
green by construction (the 367 m radius sits ~250 m beyond the 234 m span).

What this does **not** claim: not a wall, not a teleport (the teleport is
T-042's, landed), not damage, not a failsafe against every void (it assumes a
roughly circular world centered on `home_center`); it only makes straight-line
escape impossible so the player always has ground to return to. The return
*presentation* is T-087's, landed — this ticket is the outbound read only.

## Why

On the sweep-1 tree (2026-09-29) flying ~400 m outward left the ground slab
entirely and the pigeon fell into a bottomless void with zero feedback —
session b ended still "airborne" in the void at p=(−1642, −57, −655). That
evidence produced T-036/T-042/T-053, which shipped the teleport failsafe
(2026-09-30), and T-087/T-095, which made its fire a presented, counted,
pilot-visible beat. What remains is the outbound problem: between the 367 m
apron edge and the −5 guard line the player gets no feedback at all — the
bread pointer points "city N m" but nothing bends the course, straight-line
escape stays free, and the guard only answers after the fall has already
happened. A soft banked turn home with a hint makes the world legible before
the failsafe is ever needed — and the failsafe stays for anyone who fights it.

Nothing in game code homes today: `_steer` has no homing term and
`scripts/player.gd` carries no City/home reference (re-read 2026-10-01) — the
only horizontal homing in the repo is the autoplay pilot's
(`tests/autoplay.gd:28`, `HOME_RADIUS = 40.0`). Note `VERIFICATION.md:160`'s
"beyond 60 m" Gate 2 prose is stale against that constant; refresh it while
touching the file. T-042 defers here by name
(`docs/tickets/T-042-off-world-void-respawn.md:6` and `:54-55`); T-058
(proposed) is a different HUD element — the bread-pointer chevron convention.

## Acceptance criteria

- [x] Reset 300 m past the city edge — `home + Vector3(half_span + 300, 30, 0)`
      = 417 m from home center, i.e. 50 m past the 367 m apron edge, mid-ramp —
      flying straight out (nose +X), hands off for 3 s (180 frames): the
      heading rotates ≥ 30° back toward home and y never drops below 0.
      Today's tree fails this: `_steer` has no homing term, and the guard
      cannot fire inside the window (from y = 30 at glide speed the flight
      model's softened gravity — `min_gravity_fraction` 0.2,
      `scripts/player.gd:51` — sinks roughly 10 m over 3 s, far above −5), so
      the heading assertion is what bites (Gate 1b: `edge_nudge_turns_home`)
- [x] In-city handling is untouched: `banked_left_turn` (the flat world at the
      origin, `tests/sim_test.gd:405`) and `city_street_flyover` (inside the
      span, `tests/sim_test.gd:782-803`) stay green — the nudge is disabled by
      default and its radius sits ~250 m beyond the whole city
- [x] The landed guard layering holds: `off_world_fall_respawns`
      (`tests/sim_test.gd:693-721`, registered `:120`),
      `off_world_fall_returns_home` (`:5074-5115`, registered `:188`) and
      `off_world_return_beat` (`:5142`, registered `:189` — it runs a real
      main scene, so it *will* inherit the `_ready()` nudge wiring) stay green
      unchanged — the guard must not depend on the nudge, and the nudge must
      not disable the guard or disturb the return beat
- [x] The guard never hard-grabs: with the nudge active, a held player turn
      can still hold course against it (Gate 3 playtest line; reviewer
      sign-off 2026-10-02)
- [x] [screenshot] The HUD shows the turn-back hint past the apron and the
      normal air/ground hint again once back inside — no hint-writer fight
      across a landing/takeoff cycle at the boundary (reviewer sign-off
      2026-10-02)

## Verification

Gate 1 (import + 120-frame boot — the `--check-only --script` leg is broken
repo-wide and stays dropped per `VERIFICATION.md:385-389`) + Gate 1b full
suite green — the suite is 110 scenarios on today's tree
(`grep -c '_check("' tests/sim_test.gd` → 110, 2026-10-01); the new scenario
makes it 111. `edge_nudge_turns_home` wiring:
`_player.home_center = _city.global_position`,
`_player.home_radius = _city.city_span * 0.5 + _city.ground_extra`, then
`_set_up(true, home + Vector3(half + 300, 30, 0), Vector3(17, 0, 0), -90.0)`
(nose +X, away from home — `_set_up` at `tests/sim_test.gd:212`); read the
heading from `-transform.basis.z` the way the turn scenarios do
(`tests/sim_test.gd:403`); `city_street_flyover`, `banked_left_turn`,
`off_world_fall_respawns`, `off_world_fall_returns_home` and
`off_world_return_beat` explicitly re-run; `VERIFICATION.md`'s Gate 1b table
(from `:28`) gains the `edge_nudge_turns_home` row (and the stale "beyond
60 m" Gate 2 prose at `VERIFICATION.md:160` is refreshed) — + Gate 2 (the
pilot already arcs home well inside the radius via its own `HOME_RADIUS`;
unaffected) + Gate 3.

**Pending human playtest (Gate 3):** the hint text reads and disappears
correctly at the boundary; the nudge feels like a pigeon wanting to go home —
present, never a control grab — and an outward turn can still win against it;
the outbound hint and T-087's return beat read as one coherent off-world
language rather than two disconnected messages.

## Landed (2026-10-02, implementation record)

**Tuned values:** `home_nudge_rate` 0.35 (the nudge's share of the bank
envelope → a ≤ 14° home bank at full ramp blend, against the player's own 40° —
a full opposite hold still commands 26°) · `home_nudge_ramp` 100 m (the
ticket's suggestion) · the nudge is a target-bank addition inside `_steer`
riding the existing bank→yaw path (`_home_nudge_bank()`), with the flat
bearing-to-home clamped at ±90° so a dead-away heading — the sine's zero, and
exactly the scenario's start — commands the full share instead of stalling.
Main wiring exactly as specified: `home_center = city.global_position`,
`home_radius = city.city_span * 0.5 + city.ground_extra` (367 m at defaults).
Hint: `HINT_EDGE := "Nothing out there — turn back"`, owned via the
`_edge_hinting` flag; `_on_grounding_changed` yields only its hint write (the
combo-note logic below it stays live); `restart_run()` clears the flag.

**Gate evidence (all run on this change-set):**
- Gate 1: `--import` exit 0 and the 120-frame `--quit-after` boot exit 0 (only
  the documented pre-existing benign exit lines: the addon-shutdown "33
  resources still in use" on import and a 1-instance ObjectDB leak warning
  verified identical on the stashed untouched tree). The
  `--check-only --script` leg stays dropped per the known issue.
- Gate 1b: full suite `SIM SUMMARY: 0 failure(s)`, exit 0 — 106 distinct
  `SIM PASS` lines on today's tree (the "110 scenarios" figure above was
  stale against the tree this landed on: HEAD carried 117 `_check(` sites /
  90 registered scenario functions; this change-set carries 118 / 91, the +1
  being `edge_nudge_turns_home`). `edge_nudge_turns_home` measured: turned
  **54.2°** (bar ≥ 30), end bearing 127.7°, min y 26.53 m, resets 0 — and the
  red-before probe (same scenario, nudge wiring disabled = the old tree's
  behavior) failed exactly the heading arm: turned 0.0°, bearing 180.0°.
  `banked_left_turn`, `city_street_flyover`, `off_world_fall_respawns`,
  `off_world_fall_returns_home` and `off_world_return_beat` all re-ran green
  inside the same suite run.
- Gate 2: `AUTOPLAY DONE ok=true … restart=true` at 137 fps, no SCRIPT ERROR —
  the pilot's own `HOME_RADIUS` 40 homing stays far inside the 367 m apron
  radius, so a pilot run never engages the nudge.
- Gate 3: accepted by **reviewer sign-off (2026-10-02)** — the nudge reads as
  a pigeon wanting to go home (present, never a control grab, a held outward
  turn still wins), the hint reads and clears correctly across the boundary
  with no hint-writer fight, and the outbound "turn back" hint and T-087's
  "came home" beat read as one coherent off-world language.

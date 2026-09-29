# T-007 — Tourists v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** done
- **Depends on:** T-004, T-006
- **Refs:** `docs/DESIGN.md` → Tourists & cars

## What

The high-value targets:

- Low-poly pedestrian NPCs walking sidewalk paths in loose groups
- Reactions: **splatted** → panic (run away, yell, shake fist); **buzzed** (close
  high-speed near-miss) → flinch
- Simple waypoint/curve walking, capsule physics, layer 3 `npc`
- Respawn/recycle to keep 15–20 tourists alive around the player

## Why

Tourists are the skill target: small, moving, worth the most points. Their panic is
also most of the city's "reacts to you" charm.

## Acceptance criteria

- [x] 15–20 tourists walking believably around the spawn plaza and main streets
      (18 kept alive by the spawner; rectangle loops on each block's outer curb
      line, the one band clear of buildings, benches, lamps and bins alike —
      machine-checked in Gate 1b; "believably" is the pending human line)
- [x] A splat produces panic (animation + movement change) and the score event
      (real lobbed poop → duck-typed `on_splatted` → panic sprint away from the
      impact's horizontal mirror, arms up, red flush, fist shake; `splatted`
      relayed through the spawner into Main's score stub, machine-checked)
- [x] A close high-speed flyby produces a flinch without full panic
      (≥12 m/s pigeon inside the 2.6 m buzz zone → 0.5 s duck; slow passes do
      nothing; 2 s per-tourist cooldown; machine-checked both ways)
- [x] No frame drops at full density; tourists recycle without popping in view
      (autoplay DONE line: 131 fps avg at 18 tourists; recycle teleports the
      SAME nodes onto fresh loops 30–70 m from the player — never closer, and
      outside the city they hold position; the "not in view" read is the
      pending human line)

## Tuned values

- `Tourist` (`scripts/tourist.gd`): walk 1.3 m/s × per-tourist pace 0.85–1.2 ·
  waypoint reach 0.7 m · panic 4.2 m/s for 2.6 s, flee dir = −(impact
  velocity).horizontal (straight drops flee anywhere) · buzz threshold 12 m/s,
  cooldown 2.0 s, flinch 0.5 s to 0.72 squash · capsule r 0.25 h 1.1, feet-origin ·
  8-shirt palette + skin head · collision layer 3 `npc`, mask 1 `world`.
- `TouristSpawner` (`scripts/tourist_spawner.gd`): `target_count` **18** (band 15–20) ·
  `group_size_max` **3** (loose groups, 35% walk the loop reversed, staggered
  spawn points) · `recycle_radius` **80 m** flat · `recycle_interval` **0.5 s** ·
  spawn band **30–70 m** from the player · seeded from the city seed, re-seeds on
  `City.regenerated`.
- `City.sidewalk_loop` (`scripts/city.gd`): rectangle at **block half − 0.1 m**
  (10.9 m at the default block) on the outer curb line — sides clear buildings
  (≤7.8 m), benches (9.5–10.0 m), corner lamps/bins (≤10.3 m); + `block_centers`
  registry for the spawner.

## Verification

Gate 1 + Gate 2 + Gate 3. Machine-verified by four new Gate 1b scenarios
(`tourists_walk_loose_groups`, `tourist_splat_panics_scores`,
`tourist_buzz_flinch`, `tourists_recycle_around_player` — 41/41 pass, exit 0),
including a real lobbed poop hitting a frozen tourist, the duck-typed panic
with a sideways-impact flee-direction check, slow-vs-fast flyby contrast, and a
move-the-player recycle that asserts node reuse and the spawn-band contract.
Gate 2: the autoplay city runs at full tourist density — DONE line reported
`tourists=18 panics=0 splats=10 eaten=1`, ok=true, no SCRIPT ERROR, ~131 fps;
the pilot now pulls the poop trigger early when a strolling tourist lines up
under the predicted impact point (chance shots; panics counted in the DONE
line). No new input actions, so the controls tables are unchanged except the
README's F-row description.

**Pending human playtest:** the Gate 3 T-007 lines — walk believability, panic
readability (arms/fist/flush in motion), a manual skill run (splat 3, buzz 3,
watch one full panic cycle to recycle), and pop-in visibility.

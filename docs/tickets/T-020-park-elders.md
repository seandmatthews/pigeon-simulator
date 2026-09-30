# T-020 — Park elders share bread

- **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-004 (plaza benches), T-005 (bread system), T-007 (NPC conventions)
- **Refs:** `docs/DESIGN.md` → Pillar 2 ("the city reacts"), Hunger section

## What

Friendly old people sit on the spawn-plaza benches. Land in front of one, hang
out on the ground nearby, and after a few seconds they toss you bread. The
bread **is** the T-005 crumb — no second food system.

- `scripts/elder.gd` + `scenes/elder.tscn` — a static, sitting NPC built from
  the same hand-placed low-poly primitives as `scripts/tourist.gd` (box body,
  sphere head, cardigan-colored torso, gray/white hair box, cane). Sits on the
  bench seat (base y = `City.block_slab_height`, seat top +0.60 — same math as
  `_add_bench`, `scripts/city.gd:538-547`). `StaticBody3D` on layer 3 `npc`,
  mask 0, so the pigeon can perch next to them but not through them. One
  cosmetic beat: the near arm raises for ~0.5 s when bread is shared.
- `scripts/elder_spawner.gd` — mirrors the spawner shape of
  `scripts/tourist_spawner.gd` (wired into `scenes/main.tscn` next to the
  other spawners, `city`/`player` assigned by Main; re-populates on
  `City.regenerated`). Places `elder_count` = 4 elders on **plaza benches only**
  (indices 0, 2, 4, 6 of the 8-bench ring `_build_plaza` lays out at
  `scripts/city.gd:504-511` — deterministic, spread around the ring, every seed
  has them). Placement consumes **zero** city RNG: `city.gd` records a new
  pure-layout array `elder_spots: Array[Transform3D]` (bench position + yaw,
  appended in `_build_plaza` exactly the way `bread_spots` is appended in
  `_add_bench`), so the T-004/T-017 RNG fingerprints and bench counts are
  untouched.
- Proximity → trust → share, all tunables `@export` on `elder.gd`:
  - A `PresenceZone` Area3D (radius `proximity_radius` = 3.0 m, mask layer 2)
    fills `_trust` at 1.0/s **only while the pigeon is GROUNDED inside it**
    (same grounded-only rule as `BreadCrumb`, `scripts/bread_crumb.gd:32-37`).
  - With nobody in the zone, trust decays at `trust_decay` = 2.0/s — a brief
    walk-away doesn't wipe progress, but a fly-through banks nothing.
  - At `_trust >= trust_needed` (4.0 s) the elder shares: calls the new
    `BreadSpawner.drop_crumb(global_pos)` (`scripts/bread_spawner.gd` — spawns
    the existing `scenes/bread_crumb.tscn` with `spot_index = -1`, the
    hand-placed case `scripts/bread_crumb.gd:17-18` already supports, feeding
    the spawner's existing `_on_crumb_eaten` → `crumb_eaten` → Hunger wiring).
    `crumbs_per_share` = 2, tossed to ground points ±0.4 m sideways at
    `toss_distance` = 1.2 m in front of the elder's facing.
  - After sharing, the elder is on `share_cooldown` = 25.0 s and trust resets
    to 0 — a friend, not an infinite buffet.
- `tests/capture_recorder.gd` — two additions in the established patterns:
  `_ensure_connections` gains `_connect_once(elder_spawner, "bread_shared", …)`
  → `_log_event("elder_bread_shared", {"p": …, "crumbs": n})` (same shape as
  the `tourist_splatted` wiring, `tests/capture_recorder.gd:362-365`), and
  `_snapshot()` gains an `elders` position list like `tourists` (line 268).
  `ElderSpawner` relays the moment as its own `bread_shared(elder, count)`
  signal.

**Not claimed:** elders don't walk or react to splats/buzzes (that's still the
tourists' job); no points for hanging out — eating is hunger-only per the
DESIGN.md scoring table; no park-block variants and no elders anywhere but the
plaza ring this slice; no voice/sfx. One focused commit.

## Why

The owner: old people in a park give you food if you land in front of them and
hang out with them for a bit — "if you exist in close proximity to one of the
old people in the park, they should eventually distribute bread."

Player value: the plaza is where every run starts and returns to, and today
its benches hold only static crumbs. An elder turns it into a warm, safe food
stop that rewards the land-and-be-present half of the loop (the half the poop
score punishes), and it makes the city react kindly as well as angrily —
pillar 2 cuts both ways. Panicking tourists vs. generous grandparents is also
the tone contrast the game wants.

## Acceptance criteria

- [x] Four elders sit on plaza benches every run, spread around the ring, and
      zero city-RNG draws were added — T-004/T-017 fingerprints, bench/lamp/bin
      counts and bread-spot layout are byte-identical (Gate 1b asserts).
- [x] A GROUNDED pigeon inside `proximity_radius` of an elder fills trust; at
      `trust_needed` the elder distributes `crumbs_per_share` crumbs that are
      ordinary T-005 crumbs (restore 30 hunger via the existing Hunger wiring,
      eatable grounded-only, respawn-accounted by `BreadSpawner`).
- [x] Flying through the zone, or landing outside the radius, never fills
      trust; trust decays when nobody is present.
- [x] A sharing elder then ignores the pigeon for `share_cooldown` — the
      second hangout within the cooldown shares nothing.
- [x] *(Gate 1b only)* `elder_shares_bread_after_hangout`: a grounded test
      player parked in an elder's PresenceZone for `trust_needed` seconds
      produces ≥ 2 live crumbs within `toss_distance` of the elder and exactly
      one `bread_shared` relay; `elder_no_bread_airborne`: a FLYING player held
      in the same zone for the same duration produces zero crumbs and zero
      relays; `elder_cooldown_blocks_second_share`: re-hanging out inside the
      cooldown produces nothing, after it produces again.
- [x] *(CaptureRecorder)* When an elder shares bread in ANY run (autoplay or
      pilot), `events.jsonl` gets an `elder_bread_shared` line —
      `{"ev":"elder_bread_shared","t_ms":…,"p":[x,y,z],"crumbs":2}` — and the
      state snapshot carries an `elders` list, so agent play sessions can see
      both the people and the moment.
- [x] Four static elders cost nothing measurable: Gate 1 still passes and the
      T-018 CPU frame budget gate stays green with the elders live.

## Decisions & tuned values

- `city.gd` records **all 8** plaza benches in `elder_spots` (appended in
  `_build_plaza`, mirroring `bread_spots` in `_add_bench`); the spawner seats
  elders on every second bench (indices 0, 2, 4, 6) — spread around the ring
  at every seed.
- Player scene change: `player.tscn` `collision_mask` 1 → 5 (world + npc) —
  the ticket's "perch next to them but not through them" only works if the
  pigeon's mask includes the `npc` layer the elders sit on. Side effect: the
  pigeon also collides with tourists now (they never masked the player, so
  they still walk through the bird).
- Tuned values (all `@export` on `elder.gd`, defaults used by the gates):
  `proximity_radius` 3.0 · `trust_fill_rate` 1.0/s · `trust_decay` 2.0/s ·
  `trust_needed` 4.0 s · `crumbs_per_share` 2 · `toss_distance` 1.2 m ·
  `toss_spread` 0.4 m · `share_cooldown` 25.0 s · `arm_raise_seconds` 0.5.
- Cross-version fingerprint proof (run during this ticket): `city.generate`
  fingerprint for seed 20260928 = 2492360539 and for 424242 = 2662825400,
  identical with HEAD's `city.gd` and with the T-020 version.
- Pilot session evidence (`.captures/session_t020impl/`): seven shares across
  three different elders — every share logged while the pigeon was grounded
  ≤ 2.6 m from the sharing elder and > 9.6 m from every other; per-elder
  consecutive shares spaced 25.0 s; tossed crumbs eaten grounded with
  `crumb_eaten` 30.0 each (hunger 70.7 → 99.7).

## Verification

Gate 1 + Gate 1b (new scenarios `elder_placement_no_rng`, `elder_shares_bread_after_hangout`,
`elder_no_bread_airborne`, `elder_cooldown_blocks_second_share` added to
`tests/sim_test.gd` following the spawner-under-test pattern of
`_scenario_tourists_walk`, `tests/sim_test.gd:1026-1082` — the elders' plaza
placement is asserted against a real generated `City` so the fingerprint
guarantee is exercised) + Gate 2 (autoplay DONE line reports the elder share)
+ Gate 3.

**Pending human playtest (Gate 3):** does the elder read as an old person at a
glance (hunch, hair, cane) in screenshots from flight height and ground level;
does ~4 s of hanging out feel like "a bit" and not an age; does the tossed
bread land where the pigeon can reach it without phasing through the bench.

## How to verify by playing (pilot session)

```bash
python tests/tools/pilot.py start --session <id>
python tests/tools/pilot.py wait  --session <id> --scene Menu
python tests/tools/pilot.py send  --session <id> '{"key":"Space","frames":2}'
python tests/tools/pilot.py wait  --session <id> --scene Main
```

The spawn drop puts you at the plaza edge — an elder is on a bench ~8 m from
the plaza center. Then:

1. `state --session <id>` → read the new `elders` list; pick the nearest
   bench position and note the player `p` delta.
2. Take off and glide to land in front of that bench: send
   `{"action":"flap","frames":7}`, steer with `pitch_up`/`turn_left`…, then
   idle until `state.jsonl` shows `"grounded": true` within ~3 m of the elder.
3. Send nothing for ~5 s (hang out). Watch `events --session <id> --tail 20`:
   expect one `elder_bread_shared` line with the elder's position, then, once
   you peck the tossed crumbs (walk into them grounded), the familiar
   `crumb_eaten` lines — and `hunger` in `state.jsonl` rising by 30 per crumb.
4. Immediately repeat steps 2–3 at the same bench: within the 25 s cooldown
   there must be **no** second `elder_bread_shared` — that's the cooldown
   criterion seen live.
5. `shot --session <id>` before the share (elder on bench) and after (crumbs
   on the pavement in front of them) for the human-judgement look check.
6. `python tests/tools/pilot.py stop --session <id>` when done.

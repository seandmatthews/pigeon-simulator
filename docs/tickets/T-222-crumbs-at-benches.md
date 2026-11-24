# T-222 — Breadcrumbs at benches: lunch benches with seated eaters

- **Status:** proposed · **Category:** gameplay · **Ring:** R6 (owner pick) ·
  **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** the bread pointer's Ames fix — **unticketed as of writing.**
  `main.gd _update_bread_pointer` still tests the retired Windrow ring
  (`city_span · 0.5` = 117 m around the pack origin), so on nearly the whole map —
  spawn included — the HUD reads "city N m" aimed at the spawn point instead of
  pointing at the nearest crumb. Bench crumbs nobody is pointed at fix nothing; that
  is a small fix and it goes first.
- **Refs:** owner 2026-11-23 — "think about crumb placement. We can always spawn in
  more benches with students eating at them" → 2026-11-24 "another feature for
  aligning breadcrumbs with benches" · the 2026-11-23 difficulty research (numbers
  below; evidence probe `tools/probe_survival.gd`)

## What

Benches with people eating at them, and the breadcrumbs to match — a steady, learnable
food source near where the player actually is.

- **Lunch benches.** New benches, one or two seated eaters each, in the open near
  spawn and along the walked routes. Students on the Central Campus lawn; the shirt
  palette says "local", never visitor black-and-gold.
- **Crumbs at the bench's feet.** Each bench keeps `crumbs_per_bench` crumbs on the
  ground in front of it; an eaten one comes back after `refill_seconds` while a sitter
  is there. They are hand-placed (`BreadSpawner.drop_crumb`, `spot_index` −1) and free
  to eat.
- **Batched and cheap.** Benches and sitters as one MultiMesh per part, the way
  `CafeSpawner` builds its tables and sitters from the baked sitting pose (the T-163
  seat-contact constants). No per-frame cost beyond the refill timers.

### Where they live

A new list on the world (e.g. `city.lunch_benches`), **separate from
`AmesPedZones.Zone.benches`**. The elder seating law puts one favor elder on EVERY
bench of a favor zone (`ElderSpawner._populate_zones`), and several scenarios pin
`zone.benches.size()`. A lunch bench seats a student, not an elder, and must not move
a zone pin.

### Placement law

- **Open ground.** No tree crown over the bench or over a 6 m approach. Today's
  nearest sharing bench is ~94 % under canopy and invisible from 33 m — the measured
  failure this ticket must not repeat.
- **Off the walk line** by `BENCH_SIDE_OFFSET`, ground-guarded
  (`GROUND_COVER_MAX`), clear of roads and of the T-217 tree colliders.
- **First cluster within ~150 m of spawn**, on the Central Campus crossing axes
  (T-187), where the spawn view is an empty lawn today.

## Why (measured 2026-11-23)

- At boot the player has 8 free crumbs within 21–96 m. After those, the nearest crumb
  is 378 m, then 507 m (the first real café table), then past 1 km. Replacements land
  anywhere among 22,703 ground spots across a 4.9 × 8.5 km map: the nearest crumb is
  ~460 m away in the median and over 850 m one time in ten. A crumb buys 67 s of
  flight, so the run turns into a commute between single crumbs.
- Half of this feature already exists in pieces: benches (`AmesPedZones`), a seated-
  eater batch (`CafeSpawner`), and a bread spot in front of a bench
  (`AmesWorld._add_favor_bench_spots`) — but those are filed as café tables, so each
  costs 1 favor to eat.

## Open decisions (the owner picks at pickup — defaults in brackets)

- **How many, where.** *[Default: 10 — 4 within 150 m of spawn on the crossing axes,
  6 along the routes toward the MU corner and the lake.]*
- **Crumbs per bench, refill time.** *[Default: 2 crumbs, back 25 s after eaten.]*
- **Price.** *[Default: free.]* Alternative: 1 favor each, like the café tables.
- **Who sits.** *[Default: static sitters in the civilian shirt palette, from the café
  batch.] Live rigs cost per frame, and the entry-hardware margin is 1 fps (31
  against the 30 floor).
- **Do bench crumbs displace the far random crumbs.** *[Default: yes.] They are
  hand-placed, so `BreadSpawner._budget()` already shrinks the random spot budget one
  for one and the fleet never exceeds `target_count` (40) — fewer useless crumbs 2 km
  away, by construction.

## Acceptance criteria (proposed)

- [ ] The lunch benches exist at boot at pinned positions, and every one has a sitter
      seated ON the bench (the sitter's seat line against the bench top, inside the
      T-146 family)
- [ ] Each bench keeps `crumbs_per_bench` free crumbs within 2.5 m of its front at
      boot; an eaten one is back after `refill_seconds` (±1 s)
- [ ] The crumbs are hand-placed and free: `spot_index == −1`, `favor_delta == 0`,
      and eating one books no favor
- [ ] The fleet stays in budget — random spot crumbs drop one for one with bench
      crumbs, the total never exceeds `target_count`, and the `ames_bread_spawner` row
      is re-pinned to the new split
- [ ] Canopy-clear: no tree in the committed bake has a crown over any bench or its
      6 m approach (checked against the bake's `trees`, not estimated)
- [ ] No zone bench count moves and the elder count stays 12
- [ ] Batched: one MultiMesh per part, and the headless CPU cost stays under the
      density budget (`density_cpu_budget`)
- [ ] Measured, with the starter crumbs eaten: the nearest-crumb median from spawn
      falls from ~460 m to under 150 m (the `probe_survival` probe, re-run)
- [ ] Full Gate 1b green
- [ ] Gate 3 (owner): from spawn a lunch bench with someone eating is visible; land,
      eat, see the crumb come back

## Verification (proposed)

Gate 1b — `lunch_benches_placed` (positions, sitters, canopy-clear against the bake),
`lunch_bench_crumbs_refill` (free, hand-placed, timer, budget), plus the re-pins
(`ames_bread_spawner`, `ames_bread_reach`). Gate 2 unchanged in shape — its eat loop
should get easier, not harder. Gate 3 the line above.

## Risks

- **The perf margin is 1 fps** (31 against the 30 floor on the gate box). Everything
  batches; nothing ticks per frame except the refills of eaten crumbs.
- **Seat contact needs eyes.** T-141's lesson: contact targets get verified against
  owner screenshots, not bone arithmetic.
- **Blocked on the pointer fix** above until it lands.

## Related, decided but not in this ticket

Owner, 2026-11-24: put one bread-sharing elder on a bench in plain sight at spawn for
now — the near-term half of elder findability (T-221 is the long-term half). It has no
ticket yet.

# T-032 — Give roofs a reason to exist: rooftop clutter and roof bread spots

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-004 (buildings/roofs), T-005 (bread system)
- **Refs:** `docs/tickets/T-004-city-blockout.md` → Notes ("T-005 can spawn
  bread on benches, sidewalks, plaza and roofs — `City.buildings` exposes
  every roof footprint") · `docs/DESIGN.md` → The city (landable flat roofs)

## What

Per building, 1-3 deterministic rooftop props plus one roof-corner bread
spot — all pure layout math, zero RNG, `scripts/city.gd` only:

- `_make_meshes()`: three new mesh keys — `"ac_box"` (1.2 × 0.8 × 1.2,
  `COLOR_METAL`), `"water_tank"` (1.4 × 2.0 × 1.4, dull plastic — new
  `COLOR_TANK` or reuse `COLOR_BIN`), `"roof_vent"` (0.5 × 0.9 × 0.5,
  `COLOR_METAL`).
- New public array `roof_props: Array[Dictionary]` (mirroring `buildings[]`):
  `{center (global), size, top, kind}` appended in `_add_building()`
  (`scripts/city.gd:422-461` — today: facade box + roof slab + shopfront,
  and nothing else ever touches a roof). Placement is a pure function of
  existing layout data, so it is deterministic per seed with zero new RNG
  draws:
  - count = `1 + ((floors - building_floors_min) % 3)` → 1-3 props per
    building;
  - kind = indexed rotation through [ac, tank, vent] by building order;
  - position = fixed corner-quadrant offsets `±footprint * 0.25` (signs
    mirrored by `lot_offset`), filling quadrants in the fixed order
    (−,−), (+,−), (−,+); base on the roof top
    (`block_slab_height + wall_h + roof_slab_height`).
  **Never the footprint center** — see the hazard below.
- Each prop gets a small layer-1 collider (`_add_collider("Props", …)`, the
  bench pattern, `scripts/city.gd:559`) so props are landable cover.
- Roof bread: one spot per building appended to `bread_spots` at the
  remaining (+,+) quadrant (`±footprint * 0.28` — never a prop there, since
  count ≤ 3 fills at most the other three quadrants), y = roof top + 0.06
  (the `_bread_ring_spots` convention, `scripts/city.gd:262`) → 146 new
  spots, city total 533 → 679 (533 = 8 sidewalk spots × 49 blocks + 141
  bench seats at the M1 seed — zero roof spots today).
- `scripts/bread_spawner.gd` needs NO change: `_populate()` blind-shuffles
  every `city.bread_spots` index (`scripts/bread_spawner.gd:64-70`), so
  roof spots join the pool automatically (~9 of the 40 live crumbs start on
  roofs on average) and the eat path is the existing one.
- Fingerprint: no new `_fp` entries — props are pinned via `roof_props` by
  the new scenario, and `bread_spots` was never fingerprinted (`_fp`
  appends are ground/roads/slab/b/shop/bench/lamp/bin only). The hash stays
  byte-identical to pre-T-032 builds.

**Hazard, designed around:** `_scenario_city_roof`
(`tests/sim_test.gd:567-597`) drops the pigeon at the building footprint's
exact CENTER (line 580), asserts grounding within 0.2 m of roof-top (line
583), waddles from there and flaps off (lines 586-596). Any prop or crumb at
the center breaks `city_roof_landable`/`city_roof_takeoff` — so props and
the spot live at the corner quadrants only: prop centers at
`√2 · 0.25 · footprint` ≈ 2.51 m from the center, the spot at ≈ 2.81 m,
vs the current minimum-clear footprint of 7.1 m (constant for every
building).

Not claimed: no roof-exclusive gameplay (special crumb values, rooftop
tourists); no parapets or sloped roofs; no prop kinds beyond the three;
`BreadSpawner.target_count` stays 40.

## Why

All 146 roofs — the surfaces this flight game is built around — are
identical bare gray slabs: a building is facade box + flat roof slab +
shopfront and nothing else (`scripts/city.gd:429-435`), so landing on one
never pays and the roofscape reads as a table-top grid. Zero roof bread
spots exist: `bread_spots = 533` = 8 sidewalk spots × 49 blocks + 141 bench
seats, exactly (author capture `.captures/parks_out.txt`, matching the
arithmetic). Roof bread was promised in T-004's own Notes and never
shipped. Caveat recorded honestly: the lane never got a deliberate rooftop
close-up (pilot steering limits) — the "reads bare" half rests on the code
plus aerial frames (`wb3b f00024852`, the `wb1-air` climb frames), not a
rooftop screenshot; this ticket's Gate 3 screenshot closes that gap.

## Acceptance criteria

- [ ] Every building carries 1-3 rooftop props fully inside its roof (≥ 1.0 m
      from every roof edge), prop centers ≥ 2.5 m from the footprint center;
      props have layer-1 colliders and are landable.
- [ ] Every building's roof carries exactly one bread spot at roof-top
      height (+0.06) in the (+,+) quadrant that never hosts a prop; city-wide
      `bread_spots` grows by exactly the building count (533 → 679 at the
      M1 seed).
- [ ] A roof crumb is an ordinary crumb: a grounded pigeon waddling into it
      eats it through the existing `crumb_eaten` path (+30 via Hunger), with
      NO `BreadSpawner` code change.
- [ ] Zero RNG draws and no new `_fp` entries: the fingerprint hash is
      byte-identical to pre-T-032, and
      `city_same_seed_deterministic` / `city_regenerate_restores_layout`
      pass unchanged.
- [ ] *(Gate 1b)* `city_roofs_inhabited`: on a real generated City — every
      building has ≥ 1 prop whose footprint is inside the roof and whose
      center is ≥ 2.5 m from the footprint center (the `city_roof_landable`
      drop point, `tests/sim_test.gd:580`); ≥ 20 roof bread spots city-wide
      (one per building asserted); a crumb instantiated at a low roof's spot
      position is eaten by a dropped-then-waddling pigeon through
      `crumb_eaten` (`crumb_eaten_grounded_only` template,
      `tests/sim_test.gd:783-804`); a drop onto the low roof's first prop
      settles grounded on its top (bench-landing template);
      `_city.generate(default_seed)` reproduces `roof_props` and the roof
      spots byte-identically.
- [ ] *(Gate 1b)* `city_roof_landable`, `city_roof_takeoff`, `roof_landing`,
      `roof_takeoff`, `crumb_eaten_grounded_only` and `crumbs_respawn` stay
      green unchanged.
- [ ] [screenshot] From the air, roofs read as inhabited — props break the
      gray planes — and a rooftop crumb is spottable from a cruise glide.

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b full suite (73 → 74 with
`city_roofs_inhabited`; explicit re-runs: `city_roof_landable`,
`city_roof_takeoff`, `roof_landing`, `roof_takeoff`,
`crumb_eaten_grounded_only`, `crumbs_respawn`,
`city_same_seed_deterministic`, `city_regenerate_restores_layout`) + Gate 2
(autoplay: roof props visible in the cruise screenshots; the ground visit is
plaza-bound and unaffected) + Gate 3.

**Pending human playtest (Gate 3):** new lines — "roofs read as inhabited
from cruise height, not as uniform gray planes" [screenshot]; "landing on a
roof near a crumb and waddling to it works like the pavement version; props
read as useful cover, not obstacles".

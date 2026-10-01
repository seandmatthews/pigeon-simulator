# T-051 — Vary building footprints to break the uniform block grid

- **Milestone:** Sweep backlog · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (builds on landed T-004 grid, T-017 shopfronts, T-031 cafe
  tables — all three own math this ticket must make axis-aware)
- **Refs:** worldbuilding-s2 planning session (uniform-roof evidence: `wbs2-c`
  f00001752 — every roof the same gray square, only heights step; street frame
  `wbs2-b` f00085446 — equal-width facades per block) · T-017 (the
  separate-stream precedent: decoration without touching the layout stream)

## What

All 146 buildings share the exact same 7.1 × 7.1 m footprint: the constant chain
`interior = block_size - sidewalk_width*2` = 17 → `lot = interior*0.5` = 8.5 →
`footprint = lot - lot_gap` = 7.1 (`scripts/city.gd:438-441`), passed unchanged
for every lot (`scripts/city.gd:455-458`). From the air the roofscape is a
literal grid of equal squares differing only in height — the "waffle grid"
failure mode.

Vary it, per lot and per axis, by a **stable hash** — a pure function of
existing layout data, ZERO draws from `_rng`/`_shop_rng` (their sequences — and
therefore the pinned 104-of-146 awning count, tests/sim_test.gd:704, and the
cafe pin at tests/sim_test.gd:1339 — stay byte-identical):

- New pure helper in `scripts/city.gd`, e.g.
  `_lot_footprint_scale(bx, bz, qx, qz, axis) -> float`: folds
  `(bx, bz, quadrant, axis, seed_value)` through `hash()` (e.g. a `Vector4i`
  fold, then one fold with `seed_value`) and maps to **[0.78, 1.0]**. Properties
  that must hold (they are what the harness asserts, not the exact fold):
  deterministic, machine-recomputable, uniform-ish across the range, no RNG
  stream touched. Reference shape:
  `var h := hash(Vector4i(bx, bz, qx * 2 + qz, axis + 1)); h = hash(h ^ seed_value); return 0.78 + 0.22 * float(h % 1001) / 1000.0`
- `_build_block_buildings` (city.gd:438-458): compute `footprint := Vector2(
  (lot - lot_gap) * scale_x, (lot - lot_gap) * scale_z)` per lot and pass it on.
- `_add_building` (city.gd:461): signature `footprint: float` →
  `footprint: Vector2`; every internal use becomes axis-aware —
  facade/roof/collider extents (city.gd:468-477), record `"size"` (480, already
  a Vector2), the `_fp` `"b"` entry (491) carries BOTH axes, and the
  spawn-clear clamp (495-500) takes per-axis halves. The fingerprint VALUE
  changes once (accepted precedent, T-017/T-029); every fingerprint assert in
  the suite is self-to-self (tests/sim_test.gd:557, 566, 1135, 1392, 2036), so
  nothing pinned breaks.
- `_add_shopfront` (city.gd:511-545): band outset per axis (516-518); the door
  plane distance and awning position along the face normal use the footprint
  component ALONG THE NORMAL (`normal.x != 0 → size.x`, else `size.y`,
  530-535); the awning's along-face extent uses the OTHER axis (538-543).
- Downstream `size.x` readers made axis-aware — unfixed, ±z-face cafe tables
  would sit up to ~0.78 m off their shop band at the smallest footprint
  (7.1 × 0.78 = 5.54; (7.1 − 5.54)/2):
  - `cafe_spot_for` (scripts/city.gd:570-581, reads `size.x` at 573): face
    distance picks `size.x` for ±x faces, `size.y` for ±z faces;
  - the harness mirrors `_expected_cafe_spot` (tests/sim_test.gd:1302-1313,
    reads `size.x` at 1310) and the door-line check (reads `size.x` at 1387) —
    same fix so the recompute assertions stay honest.

What this does NOT claim: no block/road/lot layout change (blocks, sidewalks,
tourist loops, bread rings stay put — only building extents inside lots vary);
`lot_gap` ≥ 1.4 preserved by construction (scale ≤ 1.0 keeps each footprint ≤
lot − lot_gap, so alleys only widen); no height change (floors stay on the
existing `_rng` roll); doors stay on street faces; the "buildings reach 7.8 m
from the block center" comment (city.gd:277-278) stays true as an upper bound —
reach only shrinks.

## Why

The dominant read of this game is from the air, and the air read is a waffle
grid: every roof the same gray square, blocks differing only in how many equal
squares they hold and how tall they step (`wbs2-c` f00001752), street facades
equal-width per block (`wbs2-b` f00085446). Buildings that read as individual
volumes — some squat-wide, some slim, occasional near-full-lot slabs — are the
cheapest big win left for the city's "real place" feel, and they cost zero
gameplay: the layout guarantees (clear plaza, flyable streets, capped roofs,
bread surfaces) all hold at scale ≤ 1.0.

## Acceptance criteria

- [x] Gate 1b: new scenario `city_footprints_vary` in `tests/sim_test.gd`
      passes (`SIM PASS city_footprints_vary`):
  - [x] ≥ 3 distinct footprint sizes city-wide (distinct `Vector2`s across
        `buildings[]` records) — measured 146 distinct of 146 buildings;
  - [x] every footprint fully inside its lot with the gap kept: per axis,
        `size ≤ (block_size - sidewalk_width * 2) * 0.5 - lot_gap` (7.1 m at
        defaults) and `size > 0` (the scenario's `bounds_ok` leg);
  - [x] every record's size recomputable from the hash: the scenario owns its
        copy of `_lot_footprint_scale` (the `_expected_cafe_spot`
        harness-owns-its-copy pattern — `tests/sim_test.gd`
        `_expected_footprint_scale`) re-derived from
        `bx/bz/quadrant/axis + city.seed_value`, matching each record within
        0.01.
- [x] Gate 1b: `city_cafe_tables_present` stays green with BOTH face
      orientations on the face plane — i.e. after the axis-aware fixes, every
      table's recompute distance < 0.01 m including ±z-door buildings (the
      pre-fix failure mode).
- [x] Gate 1b: the determinism trio stays green unchanged (self-to-self
      fingerprints — the reworked `"b"` entry regenerates identically), and
      `city_shopfronts_present` / `city_shopfronts_deterministic` stay green
      (band/door/awning math reworked, coverage + determinism must hold).
- [x] Explicit re-runs green: `city_plaza_spawn`, `city_street_flyover`,
      `city_roof_landable`, `city_roof_takeoff`, `city_sidewalk_walkable`,
      `city_cafe_tables_present`, `city_new_seed_guarantees`,
      `city_shopfronts_present`, `restart_resets_run` and the full suite
      (95 PASS / 0 FAIL, exit 0).
- [x] [screenshot] Gate 3: the roofline reads as varied building volumes, not a
      waffle grid — compare against the `wbs2-c` f00001752 baseline; the
      street-level read keeps shop rows continuous (no building so slim its
      shop band looks broken). (Agent grabs — `.captures/t051_cruise_roofscape_after.png`,
      `.captures/t051_blockrow_after.png`, `.captures/t051_streetlevel_after.png`;
      reviewer sign-off 2026-10-01.)

## Landed (agent, 2026-10-01)

- Tuned values: scale range [0.78, 1.0] via the reference fold exactly as
  specified (`hash(Vector4i(bx, bz, qx*2+qz, axis+1))`, one fold with
  `seed_value`, `0.78 + 0.22·(h % 1001)/1000`); observed city-wide spread
  0.781–0.998 over 146 buildings × 2 axes, all 146 footprints distinct.
- Zero RNG-stream drift proven: the `_rng`-derived facade floor tally is
  byte-identical pre/post (`[2:34 6:33 5:23 3:32 4:24]`), roofs/spot counts
  identical (146/259/146/679), and both `_shop_rng` pins hold (awnings 104 of
  146; cafe tables 104).
- The fingerprint VALUE moved once, as mandated: seed 20260928
  2492360539 → **4188136223**, seed 424242 2662825400 → **547420287**
  (probe: headless `City.generate`, same-session default→foreign→default
  reproduced). The ticket's "nothing pinned breaks" note predates the
  cross-version pins that T-049/T-088/T-030 later added to
  `city_facades_fit_floors`, `city_apron_rim_present`,
  `city_horizon_skyline` and `city_park_trees_present` — those four pins were
  re-derived per the accepted T-017/T-029 precedent, with the old values
  recorded in the comments.
- `city_roofs_inhabited`'s derived numeric bars were re-based for the smaller
  footprints (they were computed from the old constant 7.1 m): center
  clearance 2.5 → 1.9 m (√2·0.25·5.54 ≈ 1.96 m at the 0.78-scaled minimum,
  still ≥ 0.96 m clear of the worst prop's half-diagonal) and edge margin
  1.0 → 0.6 m (0.25·5.54 − 0.7 ≈ 0.685 m) — and the scenario now pins the
  corner-relative inset EXACTLY per axis (±0.25·size), stronger than the old
  ≥ bar. The harness's `_props_of` and the roof-spot/crumb legs read the
  footprint per axis. `city_roof_landable` itself needed no change (drops at
  the record center).
- Harness mirrors made axis-aware as specified: `_expected_cafe_spot` and the
  door-line check pick the footprint component along the face normal;
  `cafe_spot_for` likewise.
- Gate 3 evidence: pilot sessions (`t051g3c`/`t051g3e`) grabbed the three
  `.captures/t051_*.png` frames; the waffle-grid comparison baseline
  (`wbs2-c` f00001752) frames are no longer on disk — the comparison uses the
  planning session's documented read (every roof the same gray square). The
  roofline read (varied volumes, continuous shop rows) was accepted by
  reviewer sign-off (2026-10-01) — ticket done.

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/city.gd`,
exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with
`city_footprints_vary` added and every scenario in the re-run list above
re-run explicitly (the touched sites are exactly: footprint chain, `_add_building`,
`_add_shopfront`, `cafe_spot_for`, two harness mirrors — the re-run list covers
each) · Gate 2 (autoplay unchanged — spawn corridor, roofs and streets behave
identically; the pilot's roof landings pick from the same low-roof pool) ·
Gate 3: the [screenshot] line above, added to VERIFICATION.md's Gate 1b table
and playtest list in the same change-set.

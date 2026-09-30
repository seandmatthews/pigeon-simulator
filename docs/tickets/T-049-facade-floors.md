# T-049 — Fit facade windows to each building's real floor count

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** worldbuilding-s2 planning session (live A/B: `wbs2-c` f00001752 shows
  floor-matched rows with the prototype in; baseline street frame `wbs2-b`
  f00085446 shows four huge rows on a low podium) · T-013 (district palettes —
  landed, must not shift)

## What

Every building today wears one shared window sticker: `_make_meshes()` registers a
single `"facade"` key (`scripts/city.gd:354`) whose `_facade_material()` draws a
FIXED 4-row × 3-column window grid on a 64×64 image (`scripts/city.gd:706-717`),
and `_add_building()` queues that one key for every building
(`scripts/city.gd:468-470`) while wall heights range over 2-6 floors
(`building_floors_min`/`building_floors_max`, `scripts/city.gd:90-91`, at
`floor_height` 3.0). A Godot BoxMesh maps its texture once per face, so a 6-floor
tower stretches those 4 rows into ~4.5 m windows and a 2-floor podium squeezes
them into 6 m — shops read as 4-story blocks, and from the air the roofscape is
one texture at five zoom levels.

Change, `scripts/city.gd` only (~20 lines):

- `_make_meshes()` (city.gd:350-365): replace the `"facade"` entry with one key
  per floor count — `"facade%d" % f` for `f` in
  `building_floors_min..building_floors_max` (five keys, `facade2`..`facade6` at
  defaults) — each its own material.
- `_facade_material()` → `_facade_material(floors: int)` (city.gd:706-717): draw
  exactly `floors` window rows. **The row pitch must be derived from `floors`**:
  the current fixed 15 px pitch (rows at y = 4 + row·15, 10 px tall) overflows
  the 64 px texture at 5+ rows (a 5th row would start at y 64). Keep the
  3-column layout (x = 5 + col·20, 13 px wide) and compute the pitch from
  `floors` (e.g. `pitch := (64 - 8) / floors`, window height `pitch - 5`) so
  every row sits fully inside the texture with even spacing.
- `_add_building()` (city.gd:468-470): queue `_add_mm("facade%d" % floors, …)`.
  The instance keeps its per-building district color — the `color` argument and
  the T-013 palette membership asserts are untouched.
- So the row count is machine-readable from the scene tree (no GPU readback),
  the material carries it as metadata: `mat.set_meta("window_rows", floors)` in
  `_facade_material` — one line, the test channel for Gate 1b.

What this does NOT claim: no new RNG draws (the floor count already exists from
the `_rng` roll at city.gd:463 — the key derivation only reads it); no
fingerprint impact (the `_fp` stream records layout data only — city.gd:378,
491-493, 636, 646, 654 — never materials or mesh keys, so the fingerprint is
byte-identical); no new colliders; no footprint/height change (that is T-051);
no texture resolution change (stays 64×64).

## Why

The city reads as boxes wearing the same sticker at different zooms. Street
level, planning-session frame `wbs2-b` f00085446 shows four huge window rows on
a low podium — a 2-story shop reading as a 4-story block; with the prototype
diff in, orbit frame `wbs2-c` f00001752 shows window rows matching the real
floor count (1 row on the 2-story podium) where the baseline shows the stretched
sticker. Cruise crosses the whole city in ~9 s, so the air read is the dominant
read — and today it is a fixed 4-row grid at five different scales.

The texture change cannot trip the visual gates: `city_district_palettes_distinct`
(`tests/sim_test.gd:664-694`) and `pigeon_silhouette_contrast`
(`tests/sim_test.gd:2493-2535`) read only the `DISTRICT_PALETTES` and
ground-color constants plus the pigeon's own mesh albedos — never facade
textures.

## Acceptance criteria

- [ ] Gate 1b: new scenario `city_facades_fit_floors` in `tests/sim_test.gd`
      (layout asserts on the standing City, the `_scenario_city_district_palettes`
      shape at tests/sim_test.gd:664 — no flight needed) passes:
  - [ ] one `MultiMeshInstance3D` per floor count present in `buildings[]` exists
        under `_city.get_node("Visuals")`, named `"facade%d" % f` in
        `to_pascal_case()` form — `Facade2`..`Facade6` (verified on this repo's
        Godot 4.7.2: `"facade2".to_pascal_case()` == `"Facade2"`; names set at
        scripts/city.gd:683) — and no `Facade*` node for a floor count no
        building has;
  - [ ] each class's `multimesh.instance_count` equals the number of
        `buildings[]` records with that floor count, floors derived from the
        record: `roundi((info.top - block_slab_height - roof_slab_height) /
        floor_height)` (record `top` set at city.gd:481; all three exports are
        public);
  - [ ] every facade instance transform equals its building's expected facade
        transform in the right floor class: origin
        `_city.to_local(info.center) + Vector3(0, block_slab_height +
        floors * floor_height * 0.5, 0)`, basis scale
        `(info.size.x, floors * floor_height, info.size.y)` — compare origin
        within 0.01 m and scale within 0.01; write the expectation with BOTH
        size axes (equal today, so T-051's per-axis footprints slot in without
        touching this scenario);
  - [ ] each class's material reports `get_meta("window_rows") == floors` and
        the meta values differ across the classes present.
- [ ] Gate 1b: a forced same-seed rebuild (`generate(seed_value, true)`)
      reproduces the facade instance sets byte-identically (`_spots_equal`
      pattern, tests/sim_test.gd:1093), and the city fingerprint equals the
      pre-change baseline — record the baseline on the untouched tree first;
      byte-identical fingerprints are a claim of this ticket.
- [ ] `city_street_flyover`, `city_district_palettes_distinct`,
      `city_shopfronts_present`, `pigeon_silhouette_contrast` and the full suite
      stay green.
- [ ] [screenshot] Gate 3: at eye level the window rows read as floors — 2 rows
      on the 2-story podium, 5-6 on towers — and from cruise height the
      roofscape reads as buildings of differing heights, not one sticker at
      different zooms.

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/city.gd`,
exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with
`city_facades_fit_floors` added, and `city_street_flyover`,
`city_district_palettes_distinct`, `city_shopfronts_present` and
`pigeon_silhouette_contrast` re-run explicitly · Gate 2 (autoplay unchanged —
visuals only) · Gate 3: the [screenshot] line above, added to VERIFICATION.md's
Gate 1b table and playtest list in the same change-set.

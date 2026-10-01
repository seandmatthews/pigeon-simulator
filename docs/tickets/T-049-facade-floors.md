# T-049 — Fit facade windows to each building's real floor count

- **Milestone:** Sweep backlog · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 1
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

- [x] Gate 1b: new scenario `city_facades_fit_floors` in `tests/sim_test.gd`
      (layout asserts on the standing City, the `_scenario_city_district_palettes`
      shape at tests/sim_test.gd:664 — no flight needed) passes:
  - [x] one `MultiMeshInstance3D` per floor count present in `buildings[]` exists
        under `_city.get_node("Visuals")`, named `"facade%d" % f` in
        `to_pascal_case()` form — `Facade2`..`Facade6` (verified on this repo's
        Godot 4.7.2: `"facade2".to_pascal_case()` == `"Facade2"`; names set at
        scripts/city.gd:683) — and no `Facade*` node for a floor count no
        building has;
  - [x] each class's `multimesh.instance_count` equals the number of
        `buildings[]` records with that floor count, floors derived from the
        record: `roundi((info.top - block_slab_height - roof_slab_height) /
        floor_height)` (record `top` set at city.gd:481; all three exports are
        public);
  - [x] every facade instance transform equals its building's expected facade
        transform in the right floor class: origin
        `_city.to_local(info.center) + Vector3(0, block_slab_height +
        floors * floor_height * 0.5, 0)`, basis scale
        `(info.size.x, floors * floor_height, info.size.y)` — compare origin
        within 0.01 m and scale within 0.01; write the expectation with BOTH
        size axes (equal today, so T-051's per-axis footprints slot in without
        touching this scenario);
  - [x] each class's material reports `get_meta("window_rows") == floors` and
        the meta values differ across the classes present.
- [x] Gate 1b: a forced same-seed rebuild (`generate(seed_value, true)`)
      reproduces the facade instance sets byte-identically (`_spots_equal`
      pattern, tests/sim_test.gd:1093), and the city fingerprint equals the
      pre-change baseline — record the baseline on the untouched tree first;
      byte-identical fingerprints are a claim of this ticket.
- [x] `city_street_flyover`, `city_district_palettes_distinct`,
      `city_shopfronts_present`, `pigeon_silhouette_contrast` and the full suite
      stay green.
- [x] [screenshot] Gate 3: at eye level the window rows read as floors — 2 rows
      on the 2-story podium, 5-6 on towers — and from cruise height the
      roofscape reads as buildings of differing heights, not one sticker at
      different zooms. (Agent grabs `.captures/t049_eyelevel_after.png`,
      `.captures/t049_cruise_roofscape_after.png`,
      `.captures/t049_streetflight_after.png`; reviewer sign-off 2026-10-01.)

## Implementation notes (agent, 2026-10-01)

- Pre-change fingerprint baseline, recorded on the untouched tree BEFORE the
  diff with a throwaway headless `City.generate` probe (deleted afterwards):
  seed 20260928 → **2492360539**, seed 424242 → **2662825400** — the same
  cross-version pins `city_park_trees_present` already asserts. Post-change,
  `city_facades_fit_floors` pins both again: byte-identical, as claimed.
- Engine quirk the scenario works around: on this repo's Godot 4.7.2 headless,
  `MultiMesh.get_instance_transform()` reads back identity (data is set and
  rendered correctly; only the readback is dead). Per-instance transforms are
  therefore read from the `_visuals["facade%d" % f].xfs` queues — the exact
  arrays fed into `set_instance_transform`, the same channel the park-trees
  and crosswalks scenarios use. `multimesh.instance_count` still comes from
  the node. Verified empirically with the probe before writing the assert.
- Landed tally at the M1 seed: facade2 ×34, facade3 ×32, facade4 ×24,
  facade5 ×23, facade6 ×33 = 146 buildings, all five classes present.
- Gates run on this change-set: Gate 1 import/boot/check-only clean; Gate 1b
  full suite 94/94 (exit 0); the four named scenarios re-run green in the same
  log; Gate 2 autoplay `AUTOPLAY DONE ok=true … restart=true`, exit 0. The
  `N resources still in use at exit` lines in those logs are the documented
  addon-shutdown noise (present identically on the untouched tree — checked
  via a stashed baseline suite run, 93/93 there).
- Gate 3 human read: ACCEPTED by reviewer sign-off (2026-10-01) over the
  agent-side grabs on the changed tree:
  `.captures/t049_eyelevel_after.png` (spawn-corridor street view: the 2-story
  podium reads shop band + one window row, its taller neighbor its own stack),
  `.captures/t049_cruise_roofscape_after.png` (autoplay cruise frame
  shot-011s: rows vary per building — 1 on podiums, 3+ on mid-rises — instead
  of one sticker at five scales) and `.captures/t049_streetflight_after.png`
  (autoplay low street flight, shot-016s).

## Landed values

- Row layout: 3 columns unchanged (x = 5 + col·20, 13 px wide); rows drawn at
  y = 4 + row·pitch with `pitch := (64 − 8) / floors` and window height
  `int(pitch) − 5` (floors 2 → pitch 28 / 23 px windows; floors 6 → pitch
  9.33 / 4 px) — every row inside the 64 px texture at any
  `building_floors_min..building_floors_max`.
- Material metadata: `window_rows` = the floor count, one StandardMaterial3D
  per count, 64×64 RGB8 unchanged.
- Fingerprint pins: seed 20260928 → 2492360539, seed 424242 → 2662825400
  (byte-identical to pre-T-049 builds).
- M1-seed class tally: facade2 ×34, facade3 ×32, facade4 ×24, facade5 ×23,
  facade6 ×33 = 146 buildings.

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/city.gd`,
exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with
`city_facades_fit_floors` added, and `city_street_flyover`,
`city_district_palettes_distinct`, `city_shopfronts_present` and
`pigeon_silhouette_contrast` re-run explicitly · Gate 2 (autoplay unchanged —
visuals only) · Gate 3: the [screenshot] line above, added to VERIFICATION.md's
Gate 1b table and playtest list in the same change-set.

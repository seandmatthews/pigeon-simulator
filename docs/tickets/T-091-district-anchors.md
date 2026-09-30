# T-091 — One tall anchor per district — a destination you can steer by

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** — (complements proposed T-029, the plaza statue — this is the
  per-district slice its "Not claimed" line at
  `docs/tickets/T-029-plaza-landmark.md:49-51` reserves)
- **Refs:** T-032 recipe (landed) · aerial frames `.captures/wbs2a_air4-6.png`,
  `.captures/wbs2a_over_city.png`, plaza frame `.captures/wbs2b_plaza3.png`
  (`.captures/` in the worldbuilding worktree)

## What

`scripts/city.gd` only: exactly one deterministic landmark per district
quadrant — a tall clock post built from the existing MultiMesh box recipe at a
fixed block center, with a landable cap and a roof crumb on top.

1. **Placement** — new `_build_district_anchor(center: Vector3, district: int)`
   called from `_build_block` (`scripts/city.gd:449-465`) for exactly four
   pinned blocks, gated on a const `ANCHOR_BLOCKS: Array[Vector2i] =
   [Vector2i(1,1), Vector2i(5,1), Vector2i(1,5), Vector2i(5,5)]` (pins assume
   the M1 `blocks_per_side` 7): `(1,1)` → district 0 (NW, warm brick), `(5,1)`
   → 1 (NE, sandy cream), `(1,5)` → 2 (SW, cool blue-gray), `(5,5)` → 3 (SE,
   sage green) under `district_of` (`scripts/city.gd:296-299`). All four sit
   ≈ 90.5 m from the plaza center — far outside `spawn_clear_radius` (12 m,
   `scripts/city.gd:96`) and the autoplay ground-visit orbit.
2. **Why a post at the block center** — the build point is the alley cross,
   the one spot on EVERY block guaranteed clear by constant layout math:
   interior 17 m, lot 8.5, footprint 7.1 (`scripts/city.gd:472-475`) put every
   building's inner edge exactly 0.7 m from the block center on both axes,
   while block props (lamps ±9.8, bins ±9.0±1, benches 9.75,
   `scripts/city.gd:664-687`) and bread-ring spots (≥ 6.5 m out,
   `scripts/city.gd:328-335`) stay ≥ 6.5 m away. Only a footprint ≤ 1.4 m
   (`lot_gap`) fits there — a ~1.4 m post fits; a 3.5 m water tower would have
   to replace a building lot and cascade every RNG-derived pin (104 awnings,
   146 buildings, 679 spots). A park roll (`park_chance` 0.12,
   `scripts/city.gd:111`) changes nothing — the post stands in the open too —
   so no `is_park` override, no fallback rule, and zero RNG-stream impact.
3. **The build** — fixed offsets, four tiers, MultiMesh boxes: plinth
   1.4 × 1.0 × 1.4 (slab → slab+1.0), shaft 0.7 × 13.6 × 0.7 (slab+1.0 →
   slab+14.6), head 1.8 × 2.2 × 1.8 (slab+14.6 → slab+16.8, tinted the
   district's first `DISTRICT_PALETTES` color, `scripts/city.gd:20-25`, so the
   quadrant reads), cap 2.0 × 0.5 × 2.0 (slab+16.8 → slab+17.3) — the landable
   pad. Total top 17.3 m ≤ the tallest building (18.25 m = 6 × 3.0 + 0.25),
   `max_roof_height` (20, `scripts/city.gd:92`) and the 23 m autoplay cruise
   floor (VERIFICATION.md → Gate 2). Colliders: one layer-1 box per tier via
   `_add_collider("Props", …)` (the bench/T-032 pattern,
   `scripts/city.gd:818-830`) — 16 bodies city-wide; the cap's top face at
   slab+17.3 is the landing surface.
4. **Bookkeeping, all zero-RNG** — new public `anchors: Array[Dictionary]`
   reset in `generate()` beside the other layout arrays
   (`scripts/city.gd:245-250`) with records `{center` (global), `district`,
   `top`, `cap_top`}`; append ONE `bread_spots` entry — the roof crumb at
   cap_top + 0.06 above the cap center (the T-032 roof-crumb pattern,
   `scripts/city.gd:540-543`); append ONE `_fp` entry
   `["anchor", center.x, center.z, district]`. Do NOT fold the anchor into
   `_max_roof` — `report.max_roof_height` stays "building roofs" (asserted at
   `tests/sim_test.gd:599`).

**Known pin breaks, amended in the same change-set (mandatory):**
`city_roofs_inhabited` counts roof spots as every `bread_spots` entry with
y > 1.0 (`tests/sim_test.gd:1646-1651`), so the 4 anchor crumbs enter its
snapshot and break TWO assertions: the `spots_ok` size equality
(`tests/sim_test.gd:1699-1700`) and the city-wide `total_ok` pin
(`tests/sim_test.gd:1702-1704`). Amend both to add `_city.anchors.size()`
(683 = 679 + 4 at the M1 seed) and refresh the scenario comment plus the
`city_roofs_inhabited` row in `VERIFICATION.md` in the same commit. The
per-building `found == 1` audit is safe without changes: the anchor crumb sits
4.25 m per axis from the nearest building center, outside the 3.55 m
half-footprint filter (`tests/sim_test.gd:1726`). The one `_fp` entry changes
the fingerprint VALUE vs pre-T-091 builds — every determinism scenario
compares within-build only (the property T-029 documents for its own appended
entries), so they hold.

Not claimed: interaction, bonus points, signage, a second anchor per district,
or the plaza center (T-029's statue, which explicitly does not claim this
either).

## Why

Nothing in the world is a destination: live HUD in wbs2a read "city 194 m →
268 m → 253 m" across one circuit — cruise crosses the whole city in ~9 s —
the four districts are palette swaps only (`DISTRICT_PALETTES`,
`scripts/city.gd:20-25`, mapped by `district_of` `:296-299`), and the aerial
frames `.captures/wbs2a_air4-6.png` show a uniform roofscape with the city a
thin island in bare apron; `wbs2a_over_city.png` shows nothing breaks the
horizon. The one intended landmark — the plaza — is an empty slab ringed by
benches and elders (`.captures/wbs2b_plaza3.png`), and T-029's statue tops out
at 5.5 m: local, not a district silhouette. One tall element per quadrant
gives "fly to the tower" a run verb and each district a steer-by silhouette;
the T-032 landable-prop + roof-crumb recipe (`scripts/city.gd:511-543`) is the
pattern this extends.

## Acceptance criteria

- [ ] Exactly one anchor stands per district quadrant at the pinned blocks
      `(1,1)/(5,1)/(1,5)/(5,5)`, total top 17.3 m, footprint inside the 1.4 m
      alley cross — touching no building, prop, bread-ring spot or tourist
      loop at any seed (the 0.7 m building standoff is constant layout math).
- [ ] The cap is landable: a drop onto the cap settles grounded at
      cap-top + 0.3 (the `city_roofs_inhabited` prop-landing leg,
      `tests/sim_test.gd:1799-1803`), and the anchor crumb is an ordinary
      crumb a grounded pigeon on the cap can eat.
- [ ] (Gate 1b) new `city_district_anchors_present` scenario in
      `tests/sim_test.gd`: on a real generated City — `anchors` holds exactly
      4 records, one per district, at the pinned blocks; every `top` ≤
      `max_roof_height`; a harness-side re-derivation reproduces each anchor's
      center/top from the block grid; the cap crumb sits in `bread_spots` at
      cap_top + 0.06; `last_report.plaza_clear` still true; and
      `generate(default_seed, true)` reproduces `anchors` and `bread_spots`
      byte-identically (the `_props_reproduced`/`_vec_spots_equal` pattern,
      `tests/sim_test.gd:1657-1676`).
- [ ] (Gate 1b) `city_roofs_inhabited` passes with its amended pins: roof-spot
      snapshot == buildings + anchors and city-wide total ==
      blocks² × 8 + benches + buildings + anchors (683 at the M1 seed).
- [ ] (Gate 1b) every fingerprint-derived scenario passes unchanged —
      `city_same_seed_deterministic`, `city_regenerate_restores_layout`,
      `elder_placement_no_rng`, `city_cafe_tables_present` (all compare
      within-build).
- [ ] (Gate 1b) `city_street_flyover` and `city_roof_landable` pass unchanged
      (the anchors stand ~90 m off the spawn corridor; the flyover leg runs
      along a street).
- [ ] [screenshot] From cruise height each quadrant shows one tall silhouette
      that reads as a destination against the roofscape; from the block below,
      the post reads as a clock/bell tower, not a bare pole.

## Verification

Gate 1 (import + 120-frame boot, plus `--check-only --script
res://scripts/city.gd`) + Gate 1b full suite green with
`city_district_anchors_present` added to the `VERIFICATION.md` table and the
`city_roofs_inhabited` row's bread-spot numbers refreshed (same change-set);
explicitly re-run `city_roofs_inhabited`, `city_same_seed_deterministic`,
`city_regenerate_restores_layout`, `elder_placement_no_rng`,
`city_cafe_tables_present`, `city_street_flyover`, `city_roof_landable`,
`city_plaza_spawn`, `city_new_seed_guarantees` + Gate 2 (the pilot's 23 m
floor clears the 17.3 m anchors; require `AUTOPLAY DONE ok=true`) + Gate 3 new
line — "(T-091) Each district has a tall anchor you can steer by — visible
from cruise height, landable, with a crumb on top [screenshot]" — plus the
existing T-004 city-readability lines re-checked.

# T-091 — One tall anchor per district — a destination you can steer by

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** — (complements proposed T-029, the plaza statue — this is the
  per-district slice its "Not claimed" line at
  `docs/tickets/T-029-plaza-landmark.md:86-92` reserves; T-029 there calls the
  two tickets "Complementary, not duplicates" and T-088's skyline "no in-city
  steering value")
- **Refs:** T-032 recipe (landed, `scripts/city.gd:802-834`) · aerial frames
  `.captures/wbs2a_air4-6.png`, `.captures/wbs2a_over_city.png`, plaza frame
  `.captures/wbs2b_plaza3.png` (recorded readings only — absent from this
  checkout; the worldbuilding worktree is gone) · line refs and counts
  re-based against the 2026-10-02 tree in the backlog-audit rewrite; counts
  re-derived the same day with a headless `City.generate(20260928, true)`
  probe (buildings=146, bread_spots=679, benches=141, roof_props=259,
  parks=2, blocks=49, report.max_roof_height=18.25, max buildings[].top=18.37,
  min footprint axis=5.5442, max observed=7.089, plaza_clear=true, span=234,
  fingerprint=4188136223)

## What

`scripts/city.gd` only: exactly one deterministic landmark per district
quadrant — a tall clock post built from the existing MultiMesh box recipe at a
fixed block center, with a landable cap and a roof crumb on top. Everything is
zero-RNG (the T-030/T-031/T-088 pure-layout precedents): no draw touches
`_rng` or `_shop_rng`.

1. **Placement** — new `_build_district_anchor(center: Vector3, district: int)`
   called from `_build_block` (`scripts/city.gd:713-730`) for exactly four
   pinned blocks, gated on a const `ANCHOR_BLOCKS: Array[Vector2i] =
   [Vector2i(1,1), Vector2i(5,1), Vector2i(1,5), Vector2i(5,5)]` (pins assume
   the M1 `blocks_per_side` 7, `scripts/city.gd:159`): `(1,1)` → district 0
   (NW, warm brick), `(5,1)` → 1 (NE, sandy cream), `(1,5)` → 2 (SW, cool
   blue-gray), `(5,5)` → 3 (SE, sage green) under `district_of`
   (`scripts/city.gd:392-394`). Probe-confirmed: global centers (±64, ±64),
   90.51 m from the plaza center and exactly 80 m from the spawn-corridor drop
   at (16, 0.6, 0) (`scripts/city.gd:366-367`) — far outside
   `spawn_clear_radius` (12 m, `scripts/city.gd:172`), the autoplay
   ground-visit orbit and the Gate 2 cruise path. None of the four is a park
   at the M1 seed (parks land at blocks (0,0) and (3,1)), but the gate sits
   OUTSIDE the plaza/park/building branch so the post stands in parks too —
   T-030's trees at (±5, ±5) (`scripts/city.gd:135-138,741-748`) leave
   5.0 − 1.84 crown half-diagonal − 0.99 plinth half-diagonal ≈ 2.2 m per
   axis — so no `is_park` override, no fallback rule.
2. **Why a post at the block center** — the build point is the alley cross,
   the one spot on EVERY block guaranteed clear by layout math: interior 17 m,
   lot 8.5, `footprint_max` 7.1 (`scripts/city.gd:760-762`) put every
   building's inner face 0.70–1.48 m from the block center per axis (since
   T-051, `_lot_footprint_scale` `scripts/city.gd:409-412` shrinks footprints
   symmetrically about the ±4.25 lot centers — the variance only WIDENS the
   alley: probe range 5.5442–7.089 per axis → standoff 0.705–1.478 m), while
   block props (lamps ±9.8, bins ±9.0±1, benches 9.75±4 along the edges,
   `scripts/city.gd:972-985`), the ground bread ring (±9.75/±6.5 per axis,
   `scripts/city.gd:442-449` — 11.7 m out in every combination) and the
   tourist sidewalk loop (10.9 m, `scripts/city.gd:427-435`) all stay
   ≥ 9.75 m from the center — probe: the nearest `bread_spots` entry of ANY
   kind is a roof crumb ~8.3 m out, at roof height. Only a footprint ≤
   `lot_gap` (1.4 m, `scripts/city.gd:187`) fits there — the 1.4 m plinth
   fits (≥ 5.5 mm of daylight per face at the M1 seed; worst case at the
   fold's theoretical 1.0 scale is flush — contact, never overlap — and the
   new scenario re-derives the standoff per seed from `buildings[]` so a bad
   seed fails loudly); a 3.5 m water tower would have to replace a building
   lot and cascade every RNG-derived pin (104 awnings, 146 buildings, 679
   spots). One accepted overlap: a visual-only awning on a center-facing door
   (`scripts/city.gd:898-907`, no collider) can lap the shaft at ~slab+2.9 —
   the T-017 brush-through convention; the head and cap read above it.
3. **The build** — fixed offsets, four tiers, MultiMesh boxes (new visual keys
   in `_make_meshes`, `scripts/city.gd:494-524`), heights relative to the slab
   top: plinth 1.4 × 1.0 × 1.4 (slab → slab+1.0), shaft 0.7 × 13.6 × 0.7
   (slab+1.0 → slab+14.6), head 1.8 × 2.2 × 1.8 (slab+14.6 → slab+16.8,
   tinted the district's first `DISTRICT_PALETTES` color,
   `scripts/city.gd:20-25`, so the quadrant reads), cap 2.0 × 0.5 × 2.0
   (slab+16.8 → slab+17.3) — the landable pad. Total top slab+17.3 = 17.42 m
   global: under the tallest building's roof (18.25 city-local = 6 × 3.0 +
   0.25; 18.37 global — the records' `top` carries `block_slab_height`,
   `scripts/city.gd:838`), under `max_roof_height` (20,
   `scripts/city.gd:168`) and under the 23 m autoplay cruise floor
   (`tests/autoplay.gd:25`). Colliders: one layer-1 box per tier via
   `_add_collider("Props", …)` (`scripts/city.gd:1134-1142`) — since T-093
   that is 16 CollisionShape3D shapes under the ONE shared Props group body
   (`_group`, `scripts/city.gd:1122-1129`; five bodies Ground/Roads/Blocks/
   Buildings/Props), not 16 bodies; the cap's top face at slab+17.3 is the
   landing surface. Three tiers per anchor (shaft, head, cap — centers
   slab+7.8/+15.7/+17.05) sit above the y 5.0 window the roofs scenario
   counts; the plinth (center slab+0.5) sits below it.
4. **Bookkeeping, all zero-RNG** — new public `anchors: Array[Dictionary]`
   reset in `generate()` beside the other layout arrays
   (`scripts/city.gd:332-343`) with records
   `{center (global), district, top, cap_top}`; append ONE `bread_spots`
   entry — the roof crumb at
   cap_top + 0.06 above the cap center (the T-032 roof-crumb pattern,
   `scripts/city.gd:831-834`; global y 17.48 at the M1 slab); append ONE
   `_fp` entry `["anchor", center.x, center.z, district]` per anchor. Do NOT
   fold the anchor into `_max_roof` (`scripts/city.gd:846`). Honest note:
   NOTHING in the harness pins `report.max_roof_height` to building roofs
   today — the only related assert is the ≤-bound in `_report_holds`
   (`tests/sim_test.gd:739`, `report.max_roof_height <= _city.max_roof_height`),
   which a folded 17.42 m anchor would still pass — so the new
   `city_district_anchors_present` scenario adds that pin itself (see
   criteria, comparing like-for-like: the report carries city-local total_h
   while `buildings[].top` is global): nothing guards this rule by convention
   alone.

**Known pin breaks, amended in the same change-set (mandatory):**
`city_roofs_inhabited` counts roof spots as every `bread_spots` entry with
y > 1.0 (`tests/sim_test.gd:2076-2081`), so the 4 anchor crumbs (y 17.48)
enter its snapshot and break THREE assertions: the `spots_ok` size equality
(`tests/sim_test.gd:2133-2134`, 146 → 150), the city-wide `total_ok` pin
(`tests/sim_test.gd:2136-2138`, 679 → 683 = 49·8 + 141 + 146 + 4) and — the
T-093 ledger — the Props-body `high_shapes == roof_props.size()` pin
(`tests/sim_test.gd:2205-2212`: every roof prop sits above y 5.0 — probe min
prop center y 6.77 — and each anchor adds its shaft/head/cap shapes there,
259 → 271). Amend all three with `_city.anchors.size()` terms (3 high shapes
per anchor) and refresh the scenario comment plus the `city_roofs_inhabited`
row in `VERIFICATION.md` (:120, "533 → 679"; also the T-032 note at :525-530)
in the same commit. The per-building `found == 1` audit and the leg-1
roof-spot search (`tests/sim_test.gd:2163-2177,2232-2236`) are safe WITHOUT
changes: the anchor crumb fails both filters — the y test needs a building
top of 17.42 (tops are 6.37…18.37 in whole-floor steps; probe: no such top)
and the XZ test needs |flat| ≤ 3.55 vs the crumb's 4.25 m per axis from every
lot center. The four `_fp` entries DO move the cross-version fingerprint
pins: four scenarios hard-assert exact values — `city_facades_fit_floors`
(`tests/sim_test.gd:919-921`, asserted at :1010), `city_apron_rim_present`
(:2546/:2548, asserted :2553-2555), `city_horizon_skyline` (:2634/:2637,
asserted :2641-2643) and `city_park_trees_present` (:2794/:2796, asserted
:2802-2805) — so re-derive BOTH pin values (seeds 20260928 → 4188136223 and
424242 → 547420287 today, probe-confirmed) with a headless `City.generate`
probe — the T-051 precedent each site's own comment names — and update the
four sites plus every `VERIFICATION.md` row quoting the values (:115, :121,
:122, :123, :124) in the same change-set. The within-build determinism
scenarios (`city_same_seed_deterministic` :753, `city_regenerate_restores_layout`
:762-766, `elder_placement_no_rng` :1713, `city_cafe_tables_present` :2031,
`city_footprints_vary` :1100) compare captured-to-current only and need no
edit.

Not claimed: interaction, bonus points, signage, a second anchor per district,
or the plaza center (T-029's statue, which explicitly does not claim this
either — `docs/tickets/T-029-plaza-landmark.md:86-92`).

## Why

Nothing inside the city is a destination. The M1 roofscape is flat by design —
6 floors max (`scripts/city.gd:185-186`) — and the four districts are palette
swaps only (`DISTRICT_PALETTES`, `scripts/city.gd:20-25`, mapped by
`district_of` `:392-394`); live HUD in the (gone) worldbuilding session read
"city 194 m → 268 m → 253 m" across one circuit — cruise crosses the whole
234 m span in ~9 s. What HAS landed since that reading must be acknowledged:
T-088's distant skyline ring (`scripts/city.gd:569-587`, consts :147-154,
pinned by `city_horizon_skyline`, `tests/sim_test.gd:2641`) raised 64
visual-only towers 192–347 m out on the grass apron — a backdrop that ends
the void, with zero colliders and no in-city steer-by value (T-029 records
the same reading, `docs/tickets/T-029-plaza-landmark.md:86-92`), and T-088's
near rim (`scripts/city.gd:114-120,689-710`) marks the city's edge, not a
district. T-030's park trees (`scripts/city.gd:741-748`, 2.2 m crowns) green
the parks; T-029's proposed statue tops out at 5.5 m — local color, not a
district silhouette; the plaza center itself stays empty
(`scripts/city.gd:949`). One 17.3 m element per quadrant gives "fly to the
tower" a run verb and each district a steer-by silhouette; the T-032
landable-prop + roof-crumb recipe (`scripts/city.gd:802-834`) is the pattern
this extends.

## Acceptance criteria

- [ ] Exactly one anchor stands per district quadrant at the pinned blocks
      `(1,1)/(5,1)/(1,5)/(5,5)`, total top 17.3 m above the slab (17.42 m
      global), the 1.4 m plinth clear of every building face — the per-axis
      standoff re-derived per seed from `buildings[]` (≥ 5.5 mm at the M1
      seed, flush-but-never-overlapping at the theoretical worst) — and
      touching no prop, bread-ring spot or tourist loop at any seed, standing
      in parks too with no `is_park` override.
- [ ] The cap is landable: a drop onto the cap settles grounded at
      cap-top + 0.3 (the prop-landing template, `tests/sim_test.gd:2263-2272`
      — add the leg to the new scenario), and the anchor crumb is an ordinary
      crumb a grounded pigeon on the cap can eat (+30 through Hunger).
- [ ] (Gate 1b) new `city_district_anchors_present` scenario in
      `tests/sim_test.gd`: on a real generated City — `anchors` holds exactly
      4 records, one per district, at the pinned blocks; every `top` ≤
      `max_roof_height`; `report.max_roof_height` equals
      `max(buildings[].top) − block_slab_height` (18.25 at the M1 seed — the
      new pin guarding the do-not-fold rule, comparing CITY-LOCAL total_h
      against the global tops minus the 0.12 slab; today only the ≤-bound at
      `tests/sim_test.gd:739` exists); a harness-side re-derivation
      reproduces each anchor's center/top from the block grid and the tier
      constants, and each pinned block's building standoff from its
      `buildings[]` records; the cap crumb sits in `bread_spots` at
      cap_top + 0.06; `last_report.plaza_clear` still true; each anchor
      contributes exactly 3 CollisionShape3D shapes above y 5.0 under the
      Props body; and `generate(default_seed, true)` reproduces `anchors` and
      `bread_spots` byte-identically (the `_props_reproduced`/
      `_vec_spots_equal` pattern, `tests/sim_test.gd:2087-2096,2100-2106`).
- [ ] (Gate 1b) `city_roofs_inhabited` passes with its amended pins: roof-spot
      snapshot == buildings + anchors, city-wide total == blocks² × 8 +
      benches + buildings + anchors (683 at the M1 seed), and Props-body
      shapes above y 5.0 == roof_props + 3 × anchors (271).
- [ ] (Gate 1b) the four cross-version fingerprint-pin scenarios pass with
      both values re-derived for the four new `_fp` entries —
      `city_facades_fit_floors`, `city_apron_rim_present`,
      `city_horizon_skyline`, `city_park_trees_present` — with every
      `VERIFICATION.md` row quoting the values refreshed in the same
      change-set.
- [ ] (Gate 1b) every within-build determinism scenario passes unchanged —
      `city_same_seed_deterministic`, `city_regenerate_restores_layout`,
      `elder_placement_no_rng`, `city_cafe_tables_present`,
      `city_footprints_vary`.
- [ ] (Gate 1b) `city_street_flyover`, `city_roof_landable` and
      `city_plaza_spawn` pass unchanged (the anchors stand ~90 m off the
      plaza and ~80 m off the spawn corridor; the flyover leg runs the
      x = 16 m street, ≥ 48 m from any anchor).
- [ ] [screenshot] From cruise height each quadrant shows one tall silhouette
      that reads as a destination against the roofscape (the T-088 backdrop
      ring stays clearly background); from the block below, the post reads as
      a clock/bell tower, not a bare pole.

## Verification

Gate 1 (import + 120-frame boot, plus `--check-only --script
res://scripts/city.gd` — re-run 2026-10-02, exit 0; do NOT add the
known-broken player.gd check-only leg, `VERIFICATION.md:385-387`) + Gate 1b
full suite green with `city_district_anchors_present` added to the
`VERIFICATION.md` table (110 `_check` sites today → 111) and the
`city_roofs_inhabited` row's bread-spot numbers refreshed (same change-set);
explicitly re-run `city_roofs_inhabited`, `city_same_seed_deterministic`,
`city_regenerate_restores_layout`, `elder_placement_no_rng`,
`city_cafe_tables_present`, `city_street_flyover`, `city_roof_landable`,
`city_plaza_spawn`, `city_new_seed_guarantees` + Gate 2 (the pilot's 23 m
floor clears the 17.42 m anchors; require `AUTOPLAY DONE ok=true`) + Gate 3
new line — "(T-091) Each district has a tall anchor you can steer by —
visible from cruise height, landable, with a crumb on top [screenshot]" —
plus the existing T-004 city-readability lines re-checked
(`VERIFICATION.md:256-260`).

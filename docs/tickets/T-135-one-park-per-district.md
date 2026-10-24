# T-135 — One park per district: pin the park roll to four mirrored blocks

- **Milestone:** City identity (owner direction 2026-10-23) · **Status:** done ·
  **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (T-136 district theming builds ON this — its themed parks
  need a park in every quadrant to dress)
- **Refs:** the roll `scripts/city.gd:1199` and its export `park_chance`
  `scripts/city.gd:319` · the park branch `_build_block`
  (`scripts/city.gd:1197-1219`) · `_build_park_trees` `scripts/city.gd:1230`
  (T-030 recipe, unchanged) · `district_of` `scripts/city.gd:583` ·
  `ANCHOR_BLOCKS` `scripts/city.gd:236` · the plaza elder seat
  `scripts/city.gd:1520` + `scripts/elder_spawner.gd:71-91` · T-091's pin
  re-derivation precedent (`docs/tickets/T-091-district-anchors.md`).

## What

`scripts/city.gd` only. Parks stop being a per-block 12% RNG roll and become
exactly four PINNED blocks — one per district quadrant, mid-quadrant on each
plaza↔anchor diagonal. Park count and position stop drifting with the seed;
green space becomes part of the map's identity.

1. **The pick** — new const `PARK_BLOCKS: Array[Vector2i] = [Vector2i(2, 2),
   Vector2i(4, 2), Vector2i(2, 4), Vector2i(4, 4)]` beside `ANCHOR_BLOCKS`
   (`scripts/city.gd:236`). `district_of` (`scripts/city.gd:583`) maps
   `(2,2)`→0 NW warm brick, `(4,2)`→1 NE sandy cream, `(2,4)`→2 SW cool
   blue-gray, `(4,4)`→3 SE sage green — one park per quadrant, each the
   midpoint of its diagonal between the spawn plaza (3,3) and that district's
   T-091 anchor ((1,1)/(5,1)/(1,5)/(5,5)). Block centers land at (±32, ±32)
   (block pitch 32): 45.25 m from the plaza center — outside the 16 m
   `city_plaza_props_clear` census and the plaza's own ring — and ≥ 35.8 m
   from the spawn-corridor drop (16, 0.6, 0) against `spawn_clear_radius` 12 m
   and the autoplay's plaza-bound ground visit. Each park sits one block
   diagonal from its anchor (45.25 m center-to-center). None of the four is
   the plaza or an `ANCHOR_BLOCKS` block — the new scenario asserts the
   disjointness so a future const edit fails loudly.
2. **The replacement** — delete the `park_chance` export
   (`scripts/city.gd:319`) and replace the roll at `scripts/city.gd:1199`
   with `var is_park: bool = (not is_plaza) and PARK_BLOCKS.has(Vector2i(bx,
   bz))`. This REMOVES one `_rng.randf()` draw per block: every downstream
   layout draw (floors, colors, lot scales, awnings, roof props, benches,
   bins) shifts at every seed — the whole city re-derives. That is the
   accepted cost (the honest code beats burning the draw to preserve a
   fingerprint); every pin break below is amended in the same change-set. The
   `_fp` slab entry (`scripts/city.gd:1204`) keeps its shape — the four
   pinned blocks' `is_park` flips false→true and the seed-parks' flip
   true→false — so the cross-version fingerprint moves once, for the last
   time this feature needs.
3. **What does NOT change** — the park recipe itself: `COLOR_PARK` slab
   (`scripts/city.gd:30`), four T-030 trees at ±`PARK_TREE_OFFSET`
   (`scripts/city.gd:1230`, now 16 total), the ground bread ring
   (`_bread_ring_spots`, every block), and the block props
   (`_build_block_props` runs for parks too, `scripts/city.gd:1219` — lamps,
   RNG benches and bins stay; park benches remain seats and crumb hosts).
   Park blocks keep their sidewalk tourist loop and curb parking like every
   block. **Elders are untouched**: they seat on the PLAZA's 8-bench ring
   (`scripts/city.gd:1520`, `scripts/elder_spawner.gd` spots 0/2/4/6) — the
   "park elders" name is historical — so the favor economy, trust and
   bread-share machinery re-derive NOTHING. No anchor block becomes a park,
   so T-091's plinth-daylight re-derivation stays well-formed against
   `buildings[]`.
4. **Report** — `report.parks` becomes 4 at every seed
   (`scripts/city.gd:1777`); at the M1 seed it was 2, at 424242 it was 3.

**Known pin breaks, amended in the same change-set (mandatory):**

- The layout fingerprint moves (stream shift). Re-derive BOTH cross-version
  pins with a headless `City.generate` probe (the T-051 precedent each site's
  comment names) and update every pin site: the `pin_default`/`pin_foreign`
  literals and history comments at `tests/sim_test.gd:1517`, `:3828`,
  `:3947`, `:4036`, `:4195`, `:6680`, T-134's crosswalks pin site (grep
  `4045370482` / `533171164` — catches any stragglers), and every
  `VERIFICATION.md` row quoting the values (the T-134, facades, crosswalks,
  apron-rim, skyline, park-trees, plaza-props and anchors rows).
- `city_park_trees_present` (`tests/sim_test.gd:4069`): the count pin 8 → 16
  (4 × parks 4); the foreign-seed leg "2 parks → 3 at seed 424242" becomes
  "exactly 4 parks at every seed". The scenario's independent park-block
  recompute (slabs wearing `COLOR_PARK`) already adapts.
- `city_roofs_inhabited` (`tests/sim_test.gd:3261`): two more park blocks
  replace building blocks, so the building count, `spots_ok`, the city-wide
  total ledger (blocks² × 8 + benches + buildings + cafe_spots + anchors;
  787 at the M1 seed pre-change) and the Props-body high-shape ledger
  (`roof_props.size() + 3 × anchors.size()`) all re-derive. The formulas
  stand; the literals refresh.
- `city_district_anchors_present` (`tests/sim_test.gd:4595`): the measured
  plinth-daylight and nearest-bread-spot values re-derive from the shifted
  layout (the anchors' own blocks are not parks; the derivation stays
  buildings-based).
- Bread-budget scenario pins downstream of the awning→cafe pool (the
  `splat_favor_follows_citizen_class` "35 → 32 TABLE / 2 GROUND / 1 ROOF, 40
  living crumbs" integers): the TABLE quota re-derives from the new
  cafe_spots count. Grep the spawner-budget literals, refresh them from the
  probe.
- Within-build determinism scenarios (`city_same_seed_deterministic`,
  `city_regenerate_restores_layout`, `elder_placement_no_rng`,
  `city_cafe_tables_present`, `city_footprints_vary`,
  `citizen_classes_spawn_deterministic`) compare captured-to-current only —
  no edit, but the full suite re-runs green.
- Gate 2 autoplay re-runs unchanged: the ground visit is plaza-bound, the 23 m
  cruise floor clears everything, parks add no height.

Not claimed: themed park dressing (T-136), any new park props or mechanics,
sub-block path meshes, park enclosures/fences, renaming the elders, changing
elder placement or count, touching `bench_chance`/`bin_chance`.

## Why

Parks are currently seed-lottery: `park_chance` 0.12 per non-plaza block
yields 2 parks at the M1 seed and 3 at 424242 — a district can be all
buildings or half green depending on the seed, and no quadrant is guaranteed
its open block. The city's four quadrants are otherwise palette swaps plus a
tall anchor each; one pinned park per quadrant gives every district a
guaranteed open block at a mirrored, symmetric position — the map reads
balanced from cruise height (plaza center, four green mid-quadrants, four
anchor posts) instead of seeded-random. Owner direction 2026-10-23 ("one park
per district"), with T-136's themed parks depending on the guarantee. The
pin-re-derivation storm is the standard price (`T-051` → `T-091` → `T-104`
each paid it) and the mechanics stay free: no favor, hunger, scoring or
traffic surface changes — elders seat on the plaza regardless of parks.

## Acceptance criteria

- [x] Exactly four park blocks, one per district quadrant at `PARK_BLOCKS`
      ((2,2)/(4,2)/(2,4)/(4,4) — one per `district_of`, each mid-quadrant on
      its plaza↔anchor diagonal), `report.parks` == 4 at BOTH pinned seeds;
      `park_chance` and its export are gone; park selection draws zero RNG.
      *Probe (`City.generate`, both seeds): parks=4, blocks (2,2)/(4,2)/(2,4)/(4,4)
      → districts 0/1/2/3, trees 16; `city_one_park_per_district` + the re-run
      `city_park_trees_present` green.*
- [x] The const-level disjointness holds: no `PARK_BLOCKS` block is the plaza
      or an `ANCHOR_BLOCKS` block (asserted in-scenario so a future edit
      fails loudly); park centers stay ≥ 30 m from the spawn-corridor drop.
      *Scenario legs: disjoint=true, midpoint=true, districts 4/4;
      corridor=true — measured min 35.78 m (probe) against the 30 m bar.*
- [x] The park recipe is unchanged: each park keeps its `COLOR_PARK` slab,
      exactly four T-030 trees at the (±5, ±5) offsets (16 city-wide), its
      ground bread ring, and block props (lamps always; benches/bins by the
      existing chances — park benches remain crumb-eligible seats).
      *Scenario legs: slabs 4/4 at the centers, 16 trunks+crowns placed,
      bread_ring=true (8 GROUND spots per park, exact-offset matched),
      lamps 196 = 4 × blocks² incl. each park's four corners; benches/bins
      code untouched (`_build_block_props` unchanged).*
- [x] (Gate 1b) new `city_one_park_per_district` scenario in
      `tests/sim_test.gd`: on a real generated City — the four park slabs
      recomputed independently from the slab queue (exactly the slabs wearing
      `COLOR_PARK`) sit at the `PARK_BLOCKS` centers, one per `district_of`;
      `PARK_BLOCKS` is exactly 4 entries, disjoint from the plaza and
      `ANCHOR_BLOCKS`, covering all four districts; `report.parks` == 4; the
      tree queues hold 16 instances over the park centers; a forced same-seed
      rebuild reproduces the slab/tree/bread arrays byte-identically; the
      foreign seed (424242) raises the same four parks (report 4, same
      blocks); and the cross-version fingerprint equals the re-derived pins.
      *Added after `city_park_trees_present`, same audit chain; row added to
      the VERIFICATION.md table.*
- [x] (Gate 1b) every pin break above is amended in the same change-set:
      both fingerprint literals re-derived by probe and every quoting site
      refreshed; `city_park_trees_present` at 16 / 4-parks-at-every-seed;
      `city_roofs_inhabited` literals re-derived; anchor-scenario measured
      values refreshed; bread-budget integers re-derived; the FULL suite
      green (0 failures).
      *New pins 20260928 → 2003179558 / 424242 → 3801669696 (probe), updated
      at `tests/sim_test.gd` facades / apron-rim / skyline / park-trees /
      intersection-furniture sites + every quoting VERIFICATION.md row
      (T-134, facades, crosswalks, apron-rim, skyline, park-trees,
      plaza-props, anchors). M1 literals re-derived: 137 buildings, 97/137
      awnings, 97 cafe spots → 146 sitters (odd-count formula fixed — the
      old `n + n/2` form only held for even counts), benches 152,
      bread 782 = 544 GROUND (392 ring + 152 bench) + 97 TABLE + 141 ROOF
      (137 + 4 anchors), roof props 245, anchors daylight 0.0242/0.0148 m,
      worst bread 8.27 m, park-tree bread 4.87 m. The spawner quota
      integers (36/3/1, 32/2/1, spill 29) are share-based and did NOT move —
      probe-verified. Full suite: 155 scenarios, 0 failures.*
- [x] (Gate 2) `AUTOPLAY DONE ok=true` unchanged.
      *`AUTOPLAY DONE ok=true t=33.0 fps=131 … restart=true`, exit 0, no
      SCRIPT ERROR.*
- [x] [screenshot] From cruise height the map reads balanced: one green park
      block per quadrant between the plaza and each anchor post; from the
      ground, a park block reads as today's parks (trees, benches, crumbs).
      *Agent grabs captured (`.captures/t135_parks/`: top-down map,
      oblique cruise, two ground-level park reads — the real generated city,
      the main.gd sun recipe, live crumbs); accepted by reviewer sign-off
      2026-10-24 (the pending-judgement note in the Gate 3 line is closed).*

## Verification

Gate 1 (import + 120-frame boot, plus `--check-only --script
res://scripts/city.gd`) + Gate 1b full suite green with
`city_one_park_per_district` added to the `VERIFICATION.md` table and the
pin-quoting rows refreshed (same change-set); explicitly re-run
`city_park_trees_present`, `city_roofs_inhabited`,
`city_district_anchors_present`, `city_same_seed_deterministic`,
`city_regenerate_restores_layout`, `elder_placement_no_rng`,
`city_cafe_tables_present`, `city_footprints_vary`, `city_plaza_props_clear`,
`city_new_seed_guarantees`, `splat_favor_follows_citizen_class`,
`citizen_classes_spawn_deterministic`, `city_street_flyover`,
`city_roof_landable`, `city_plaza_spawn` + Gate 2 + Gate 3 new line —
"(T-135) One green park per district, mid-quadrant between the plaza and
each anchor — the map reads balanced from cruise height [screenshot]" — plus
the T-004 city-readability lines re-checked.

## Implementation record

*(pipeline route per the T-117 rule; the layout re-derivation and pin
refreshes are the risk surface)* — **landed 2026-10-24.** `scripts/city.gd`:
new `PARK_BLOCKS` const beside `ANCHOR_BLOCKS` (with the geometry note), the
`park_chance` export deleted, the `_build_block` roll replaced by the
membership test (the `_fp` slab entry keeps its shape — the four pinned
blocks flip false→true, the seed-parks true→false), and the T-030 park-tree
const note updated (the park branch now draws NOTHING). Headless
`City.generate` probe (the T-051/T-091 precedent) re-derived both
cross-version pins — **20260928 → 2003179558, 424242 → 3801669696**
(pre-T-135: 4045370482 / 533171164) — and every M1-seed literal the shift
moved: buildings 146 → **137**, awnings **97**/137 (shopfronts + doors +
facade classes), cafe spots 104 → **97** (sitters 156 → **146** — the
even/odd total formula generalized to `n + (n+1)/2`, the old `n + n/2`
floor form silently wrong at odd counts, found by the probe), benches
141 → **152**, bread spots 787 → **782** (GROUND **544** = 392 ring + 152
bench, TABLE **97**, ROOF **141** = 137 + 4 anchors), roof props 259 →
**245**, park trees 8 → **16**, anchor plinth daylight 0.024 → **0.0242** m
(M1) / 0.0016 → **0.0148** m (foreign), anchor worst bread **8.27** m,
park-tree worst bread 4.98 → **4.87** m. The BreadSpawner quota integers
(36/3/1, boot 35 → 32/2/1, shrink spill 29) are share-based, not
count-based — probe-verified unchanged. New `city_one_park_per_district`
scenario (the park-trees audit chain) machine-checks the const law
(disjoint/midpoint/districts/30 m corridor), the slab-tree-bread-lamp
recipe, same-seed byte-identical rebuilds, the foreign seed and both pins.
Gates: 1 (import clean except the documented godot_mcp exit line; 120-frame
boot clean; `--check-only --script res://scripts/city.gd` exit 0), 1b full
suite **155 scenarios, 0 failures**, 2 (`AUTOPLAY DONE ok=true …
restart=true`, fps 131), 3 new line added pending the owner's balanced-map
judgement (agent grabs in `.captures/t135_parks/`).

# T-136 — District theming: four dressed quadrants, one signature silhouette each

- **Milestone:** City identity (owner direction 2026-10-23) · **Status:** proposed
  (forge deliverables landed 2026-10-24 — research note + 8 reference photos in
  `docs/references/district-theming/`, photo-grounded values recorded below;
  owner sign-off of the three open picks is the gate before implementation) ·
  **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-135 (one park per district, done — the themed parks dress
  its four pinned `PARK_BLOCKS`; the guarantee is what makes per-theme park
  dressing legible)
- **Refs:** `DISTRICT_PALETTES` `scripts/city.gd:20-25` (four quadrant facade
  palettes — UNTOUCHED here) · `district_of` `scripts/city.gd:600` ·
  `PARK_BLOCKS` `scripts/city.gd:253` + the park branch
  `scripts/city.gd:1216-1221` (the `slab_color` pick at `:1221`) ·
  `_build_park_trees` `scripts/city.gd:1251-1258` (`PARK_TREE_OFFSET` `:212`,
  visual-only, zero RNG/`_fp` per its const note) · `ANCHOR_BLOCKS`
  `scripts/city.gd:236` + the tier consts `:257-261` + `_build_district_anchor`
  `scripts/city.gd:1268-1296` + the anchor visual keys `:732-735` · block props
  `_build_block_props` `scripts/city.gd:1593-1610` (`bench_chance`/`bin_chance`
  exports `:344-345`; bench/bin rolls feed GROUND bread crumbs
  `:1619-1620` and `_fp` entries `:1626`/`:1644`) · the signboard plaque
  (`"sign"` key `:719`, placed `:1462-1465`) and the awning (`"awning"`
  vertex-color key `:717`, color `shop_color.darkened(0.15)` at `:1475`,
  `has_awning` roll `:1466`) · the `_fp` ledger — building/shop colors are
  fingerprinted (`:1397-1400`), slab entries carry only booleans (`:1225`) ·
  research note `docs/references/district-theming/research.md` + the 8 photos
  named in §References · the visitor gold/black pairing precedent
  (`docs/references/tailgate-fans/research.md`) · T-091's pin-storm precedent
  (`docs/tickets/T-091-district-anchors.md`) and T-135's (its implementation
  record) · DESIGN.md "Setting — a real US city (Ames … lightly fictionalized)"
  (`docs/DESIGN.md:149-159`) — campus / main-street / tailgate-lot are promised
  there, residential is the owner's fourth (2026-10-23)

## What

Each of the four quadrants stops being a palette swap and reads as a PLACE —
dressing with the existing recipes plus one signature silhouette per district.
All presentation; zero mechanics, zero economy, zero new verbs. `scripts/city.gd`
only.

**The quadrant↔theme mapping (Fork 1 — owner confirms at sign-off):**

| District (`district_of`) | Blocks | Palette today | Theme | Signature (Fork D-A restyle) |
| ---- | ---- | ---- | ---- | ---- |
| 0 NW | parks (2,2) · anchor (1,1) | warm brick | **Main street** — downtown row: shopfronts, awnings, signboards, the marquee | Movie-marquee cap on the anchor post |
| 1 NE | parks (4,2) · anchor (5,1) | sandy cream | **Tailgate lot** — pregame party edge: open lots, party dressing at the lot side | Water tower (riser + tank + band) |
| 2 SW | parks (2,4) · anchor (1,5) | cool blue-gray | **Campus** — the college side: quads, dense trees, collegiate stone | Campanile (shaft + belfry + spire) |
| 3 SE | parks (4,4) · anchor (5,5) | sage green | **Residential** — quiet neighborhood edge: porch-ish rhythm, greenery | Grain silo (widened shaft + hoops + dome) |

The research checked every pairing against the photos and found no
photo-grounded argument forcing any permutation — the table is a taste pick,
owner-owned (research.md §"Quadrant ↔ theme mapping").

**The four levers, keyed on `district_of`, with photo-grounded values:**

1. **Themed park slabs** — new const `PARK_SLAB_TINTS: Array[Color]` (one per
   district), applied at the `slab_color` pick (`scripts/city.gd:1221`) when
   `is_park`; the plaza keeps `COLOR_PLAZA`, non-park blocks keep
   `COLOR_SIDEWALK`. Proposed values (sampled by eye off the named photo, all
   within ≈0.06 RGB of base `COLOR_PARK` 0.42/0.55/0.34 so the city stays
   coherent; tuned at implementation): d0 **(0.46, 0.52, 0.30)** formal warm
   square; d1 **(0.48, 0.50, 0.28)** dry sandy-green edge (the tailgate-fans
   lot photos); d2 **(0.36, 0.58, 0.32)** lush cool quad lawn
   (`isu-campanile-full.jpg`); d3 **(0.44, 0.56, 0.33)** sage lawn
   (`random-lake-tower-aerial.jpg`). Zero RNG, zero `_fp` (slab entries carry
   only booleans, `scripts/city.gd:1225`).
2. **Signboard + awning tints** — the signboard plaque (`"sign"` key,
   `scripts/city.gd:719`) moves to the vertex-color material pattern (the
   `anchor_head` precedent, `:734`) and takes a per-district tint
   `SIGNBOARD_TINTS`: d0 keep cream `COLOR_SIGNBOARD` (Geneva), d1
   **(0.90, 0.78, 0.50)** banner gold (the visitor pairing — the black stays
   the door/band; `docs/references/tailgate-fans/research.md`), d2
   **(0.88, 0.85, 0.74)** limestone cream, d3 **(0.88, 0.90, 0.82)** muted
   white-sage (`random-lake-tower-aerial.jpg` painted houses). The awning
   (`:1475`) lerps its shop-derived color toward `AWN_TINTS[district]`: d0
   0.65 toward **(0.16, 0.35, 0.27)** Geneva dark green (the strongest read —
   green awnings on warm brick IS the photo's main street), d1 0.35 toward
   **(0.62, 0.48, 0.18)** banner gold, d2 0.35 toward **(0.30, 0.40, 0.50)**
   collegiate slate, d3 0.35 toward **(0.60, 0.64, 0.55)** porch sage. Both
   are post-roll pure math: the `has_awning` roll (`:1466`) and
   `awning_chance` stay untouched, shop colors never change, so neither lever
   touches a stream or `_fp`.
3. **Prop-mix weights** — `bench_chance` (0.75) / `bin_chance` (0.6)
   (`scripts/city.gd:344-345`) become per-district const tables
   `BENCH_CHANCE_BY_DISTRICT` / `BIN_CHANCE_BY_DISTRICT` (the exports are
   deleted, the T-135 `park_chance` precedent), same single draw site per edge
   and per block (`scripts/city.gd:1600,1605`): d0 **bench 0.90 / bin 0.70**
   (street furniture high — the Naas canyon's walked edges), d1 **0.50 / 0.90**
   (open lot, party litter), d2 **0.90 / 0.40** (quad seating, few bins —
   `isu-campanile-full.jpg` shows a lawn with no bins), d3 **0.50 / 0.70**
   (quiet porch rhythm, curb bins). **Honest cost:** bench/bin hit counts
   change the number of follow-up `_rng` draws (bench offsets, bin
   position/jitter — `:1602,1606-1610`), so the whole downstream stream
   shifts — this is the FULL T-135-scale re-derivation storm, not a small one:
   every M1 literal (buildings, awnings, cafe spots/sitters, benches, bread
   totals, roof props) and both cross-version fingerprint pins re-derive by
   probe in the same change-set (see criteria). The plaza is excluded
   (`:1594` returns early) — elders seat on the plaza's own ring
   (`_build_plaza` `scripts/city.gd:1532`, `elder_spots.append` `:1541`,
   `scripts/elder_spawner.gd` spots 0/2/4/6) and
   re-derive NOTHING.
4. **Themed park trees** — `_build_park_trees` (`scripts/city.gd:1251-1258`)
   takes the district and plants a fixed per-district layout
   `PARK_TREE_LAYOUTS` (still zero RNG, zero `_fp` — every offset a constant):
   d0 **2** at (±5, 0) — a formal axial pair (the Naas/Geneva canyon is
   essentially treeless; the square keeps a ceremonial pair); d1 **3** at
   (−5, 0), (0, 5), (−5, 5) — the plaza-facing half (−x/+z in block space; the
   anchor-facing half stays bare, the tailgate-fans lots are treeless asphalt);
   d2 **8** at the four corners (±5, ±5) plus edge midpoints (±7.5, 0),
   (0, ±7.5) — clusters framing an open middle (`isu-campanile-full.jpg`);
   d3 **6** at the four corners plus (±6.5, 0) with
   `PARK_CROWN_SCALE_BY_DISTRICT[district]` = **0.8** (small-crown canopy,
   whole block buried — `random-lake-tower-aerial.jpg`), others 1.0. City-wide
   park trees 16 → **19**. Trees stay visual-only (no colliders, the T-030
   convention) — the ±7.5 crowns overhang the sidewalk ≤ 0.84 m, brush-through.

**The signature silhouettes — FORK D-A (recommended): restyle the four T-091
anchor posts.** The posts already give each quadrant a steer-by silhouette at
a pinned block with a landable cap, a crumb and re-derived pins. The restyle
branches `_build_district_anchor` per district and keeps the tier STACK exact:
plinth 1.4 × 1.0 × 1.4 / shaft 0.7 × 13.6 × 0.7 / head 1.8 × 2.2 × 1.8 / cap
2.0 × 0.5 × 2.0, top 17.3 above the slab (17.42 global), crumb at cap_top +
0.06, the `anchors` record and the `["anchor", …]` `_fp` entry unchanged
(`scripts/city.gd:257-261,1288-1296`) — so the landing, crumb, top/cap_top
and plinth-daylight legs of `city_district_anchors_present` hold as-is.
Detail boxes queue on ONE new `"anchor_detail"` vertex-color key and carry NO
collider, so the SHAPE COUNTS hold (4 colliders per anchor, 3 above the y 5.0
window; the ledger roof_props + 3 × anchors holds as a count) — but the
scenario does not count shapes geometrically: it matches each Props box by
SIZE against the harness's own hardcoded tier copy
(`tests/sim_test.gd:4879-4884`, `anchor_shaft` Vector3(0.7, 13.6, 0.7)) and
asserts `per_anchor == 4` (`:5022`) and `high_shapes == 3 × anchors`
(`:5023`), and its visual leg matches the MultiMesh queues at the tier scales
the same way (`:4985-4987`) — so the d3 widened shaft breaks the size-match
legs and their `VERIFICATION.md` row ("the four tier MultiMesh queues … at
the tier scales", VERIFICATION.md:176), and the re-tinted heads break the
head-color leg (`:4988-4994`, "every head wearing one of the four districts'
first palette colors"). All three re-derive in the same change-set (Known pin
breaks). 21 extra visual instances total: 4 + 2 + 12 + 3. Per district:

- **d0 marquee (emblem):** shaft tinted Geneva blade green **(0.16, 0.35,
  0.27)**; head = the marquee box, tinted cream `COLOR_SIGNBOARD` (the letter
  board); cap = the landing pad, dark green. Four bulb boxes (0.12 × 2.2 ×
  0.12, warm **(1.0, 0.85, 0.50)**) at the head's corners — the bulb border
  that runs the box perimeter in `geneva-marquee.jpg`. Static tint, no
  emission tech, no lettering.
- **d1 water tower (good fit):** shaft = the riser, keeps 0.7 wide
  `COLOR_METAL`; head = the tank, keeps 1.8 wide (≈2.6× the shaft — the
  Random Lake single-column spheroid, the type this restyle mirrors, measures
  ≈ 3× its column's width in the photo; the Allen Hazen neoclassical ring
  runs the OTHER way — its tank overhangs the ring only slightly, ≈ 1.3× the
  ring span — see References), tinted cream **(0.88, 0.86, 0.80)**; cap =
  tank roof, cream. One
  name-band box (1.84 × 0.4 × 1.84) at head mid-height, gold **(0.72, 0.55,
  0.15)** — the horizontal band that carries the town's name in the photos
  (renders NO letters). One antenna box (0.08 × 0.9 × 0.08) rises from the cap
  at (0.55, 0, 0.55) — the photos put antennas at the tank top's CENTER, moved
  off-center here because the cap center hosts the crumb/landing spot.
- **d2 campanile (best fit):** shaft + head tinted cool limestone **(0.60,
  0.65, 0.72)** — the ISU tan re-tinted into the district's cool family per
  the research's tint note; the SHAPE carries the identity. Four dark inset
  boxes (1.2 × 1.4 × 0.1, **(0.20, 0.22, 0.26)**) centered on each head face —
  the open arched belfry, pierced on ALL FOUR faces. Four clock boxes (0.5 ×
  0.5 × 0.06, white **(0.92, 0.92, 0.90)**) at the head's lower band, one per
  face — the photos show a clock on EVERY face, never one side only. Cap =
  the spire mass, dark slate **(0.22, 0.24, 0.28)**, plus four pinnacle boxes
  (0.14 × 0.5 × 0.14, slate) at the cap's corners — the pad center stays
  clear for landings and the crumb. No bells rendered (inside the belfry,
  invisible at this scale — the dark insets carry the read).
- **d3 silo (weakest fit, honestly stylized):** the shaft widens **0.7 → 1.4**
  (mesh AND its one Props collider — the collider SHAPE COUNT is unchanged,
  but the widened SIZE breaks the scenario's tier-size match and the
  `VERIFICATION.md` row's "at the tier scales" pin — amended, see Known pin
  breaks) to read as a
  cylinder at ≈ 11:1; the research is explicit this is a stylized silhouette,
  NOT a real-silo proportion (real silos run 3–27 m diameter). Clearance is
  the plinth's own: the 1.4 m footprint equals `ANCHOR_PLINTH_SIZE`'s, so the
  per-seed plinth-daylight derivation (worst 24.2 mm at the M1 seed, 14.8 mm
  at 424242, re-derived by the scenario from `buildings[]`) covers the shaft
  at every height by the same arithmetic. Shaft tinted light concrete gray
  **(0.68, 0.67, 0.64)** (the Dane County concrete-stave silo — owner may
  flip to the blue Harvestore type, a rider pick); head = the upper drum, the
  same concrete gray; three hoop bands (1.44 ×
  0.12 × 1.44, **(0.55, 0.54, 0.52)**) at slab+4/+8/+12 — the stave-and-hoop
  read at box scale; cap = the dome, gray. Under D-A ONE silo stands — real
  farmsteads cluster 2–4 beside a barn, never freestanding mid-block, and the
  alley-cross footprint fits exactly one 1.4 m structure; the cluster/barn
  read is forgone (D-B territory).

Under D-A every signature is an emblem at 17.3 m — the real landmarks run 34 m
(ISU campanile, Allen Hazen tower) to 40 m (standard water tower). **FORK D-B:
separate new structures** buys true scale — a 34–40 m tower on the lot corner,
a fat 6 m silo — at the cost of new placement/clearance math and a second pin
storm (T-091's own record). The research adds: campanile and water tower
re-skin cleanly onto the tier stack, the silo is the one that suffers, and if
the owner wants ONE true-scale landmark, a D-B water tower at the tailgate
alone is the highest-value exception (the district whose real structure is the
town's name-bearer). Recommend D-A; owner picks.

**Tone rules:** invented Ames-flavored names only; no real schools, logos,
mascots or trademarks anywhere — colors and behavior carry the joke (DESIGN.md
naming rule). NO per-district sub-goals, score bonuses or quest machinery —
B-4e's "per-district sub-goals" stays out per the scope guardrail; this ticket
is identity, not objectives.

**Name candidates (Fork 3 — owner picks; collision checks were plain web
searches 2026-10-24, NOT a trademark-registry search):**

- School (campus): **Windrow State** / **Prairie Fork A&M** / **Vesper Plains
  State** — searched, no real institutions by these names.
- City: **Marigold Bend** / **Corntassel** / **Nettlebrook** — no towns;
  subdivision/neighborhood names only, no marks attached.
- Main street: **Bricklight Row** / **Marquee Mile** (searched clean) /
  **Gaslight Mile** (unsearched).
- Tailgate lot: **Tailgate Terrace** (searched clean) / **The Blacktop** /
  **The Gold Lot** (unsearched; "Gold Lot" is generic stadium-lot vernacular).
- Campus: **Campanile Green** / **Bell Walk** / **The Quad** (unsearched; all
  generic descriptive).
- Residential: **Windrow Heights** / **Porch Row** / **Dome Corner**
  (unsearched). *Silo Bend was considered and DROPPED — taken (a Tampa event
  venue, Nashville's "Bexley Silo Bend", streets in NC/GA).*
- Cohesion: "Windrow" seeds city + school + residential for free.

The names are RECORDS in this change-set (ticket, DESIGN.md, the owner's
worldbook) — they render nowhere: there is no text tech in the city recipes
and signage text stays out (below). If the owner later wants the name band or
signboards to render letters, that is its own ticket.

**Known pin breaks, amended in the same change-set (mandatory):** the
bench/bin stream shift re-rolls the city. Re-derive BOTH cross-version
fingerprint literals with a headless `City.generate` probe (the T-051/T-091/
T-135 precedent each site's comment names) and update every pin site and every
`VERIFICATION.md` row quoting them (the T-135 record's list verbatim). Re-derive
every M1 literal the storm moves — buildings, awnings, cafe spots/sitters,
benches, bread totals (GROUND bench crumbs), roof props — and the
bread-budget spawner integers (T-135 found them share-based; probe-verify, do
not assume). Scenario-level: `city_park_trees_present` (count pin 16 → 19 +
per-district legs; the park-tree bread-distance literal re-derives),
`city_one_park_per_district` (its "tree queues hold 16" leg and its
independent slab recompute — "exactly the slabs wearing COLOR_PARK" — re-derive
to the per-district tint table), `city_roofs_inhabited` (bench-crumb totals),
`city_district_anchors_present` — the storm re-derives its measured
plinth-daylight/nearest-bread literals from the shifted layout, AND the D-A
restyle itself changes three of its legs, amended in the same change-set: its
hardcoded tier copy (`tests/sim_test.gd:4879-4884`) learns the per-district
shaft — (0.7, 13.6, 0.7) for d0/d1/d2, (1.4, 13.6, 1.4) for d3 — so
`per_anchor == 4` (`:5022`) and `high_shapes == 3 × anchors` (`:5023`)
re-verify for ALL anchors (the counts themselves do not move: still 4
colliders per anchor, 3 above y 5.0); its head-color leg (`:4988-4994`, "all
four districts' first palette colors present") re-derives to the restyle's
per-district head-tint table (d0 `COLOR_SIGNBOARD` cream, d1 tank cream
(0.88, 0.86, 0.80), d2 cool limestone (0.60, 0.65, 0.72), d3 concrete gray
(0.68, 0.67, 0.64) — all four distinct); its visual-queue size-match
(`:4985-4987`) re-derives with the d3 shaft scale; and the `VERIFICATION.md`
row (VERIFICATION.md:176) is refreshed in the same change-set (two shaft
scales, the restyled head tints; the row's plinth-daylight derivation at
`:4930-4931` is height-blind and already covers the 1.4 m shaft — the same
0.7 m half-extent as the plinth). `city_district_palettes_distinct` (T-013) is expected
green unchanged — `DISTRICT_PALETTES` and `SHOPFRONT_PALETTE` are untouched —
but re-runs to prove the new tint surfaces don't disturb its material-mean
asserts. Within-build determinism scenarios compare captured-to-current and
need no edit.

**Not claimed:** new score/favor surfaces; per-district NPC behavior or spawn
rules; interiors; zone boundaries/fences on the ground; signage TEXT; traffic
changes (T-134 owns streets); NEW PROP TYPES — the research's planter/cooler/
banner-pole/fence/hedge/driveway prop rows are future dressing, not here (the
prop-mix lever tunes only the existing bench/bin/tree recipes);
`DISTRICT_PALETTES`/`SHOPFRONT_PALETTE` changes (facade identity stays T-013's);
`awning_chance` changes; light-emission or text-rendering tech; the plaza's
look; elder/favor/hunger/scoring mechanics.

## Why

The owner picked the direction 2026-10-23: "give each district more of a
theme." Today the quadrants differ by a facade tint (`DISTRICT_PALETTES`) and
the anchor head's color — invisible at cruise; even after T-135 the map reads
as one uniform city with four identical green squares. DESIGN already promises
campus / main-street / tailgate flavor (the Ames setting, DESIGN.md:149-174);
the owner added residential as the fourth. The four levers are the depth that
reads from the air: canopy deltas are the cheapest cruise-height read (the
research: main street ≈ treeless, campus = framed lawn, residential = buried
in trees), the signature silhouettes give each quadrant a steer-by landmark
(the T-091 posts proved silhouettes steer by), and the tints/prop weights make
the block level read as a place. The forge-with-photos route applied because
every theme and signature has a clear real-world counterpart (the owner photo
rule); all eight photos were opened and the values above written against them.

## Acceptance criteria

*Forge legs (checked before implementation):*

- [ ] The reference set is in place: `docs/references/district-theming/`
      holds `research.md`, the 8 credited photos (`credits.md`, all Wikimedia,
      free licenses) and this ticket's §References checked against them.
- [ ] The owner has signed off on the three open picks — the quadrant↔theme
      mapping (or an amended table), D-A vs D-B (D-A recommended; the hybrid
      "D-A + one D-B tailgate tower" is a legal pick), and the four names —
      and the picks are recorded in this file before implementation starts.

*Implementation legs (pipeline route — `scripts/city.gd` pin surfaces are the
risk surface):*

- [ ] Each themed park wears its district: slab tint per `PARK_SLAB_TINTS`,
      tree layout per `PARK_TREE_LAYOUTS` (2/3/8/6, city total 19, zero RNG),
      d3 crowns at 0.8 scale; the rest of the T-135 park recipe (benches,
      crumbs, lamps, tourist loop, curb parking) unchanged.
- [ ] Each anchor reads as its theme: the per-district restyles above with the
      tier stack exact (top 17.3 / cap_top 17.42 global, crumb +0.06, records
      and `_fp` entry unchanged), detail boxes visual-only (zero new
      colliders — the Props shape count stays 4 per anchor, 3 above y 5.0),
      and the d3 shaft's 1.4 m footprint clear of every building face by the
      plinth's own per-seed derivation; `city_district_anchors_present`'s
      tier-copy, head-tint and visual-queue legs re-derive to the restyle law
      (Known pin breaks) and its VERIFICATION.md row is refreshed in the same
      change-set.
- [ ] The prop-mix tables hold (`BENCH_CHANCE_BY_DISTRICT` /
      `BIN_CHANCE_BY_DISTRICT`, exports deleted) and the stream shift they
      cause is paid honestly: both fingerprint literals re-derived by probe,
      every M1 literal and quoting `VERIFICATION.md` row refreshed in the same
      change-set (the T-135 storm list, executed).
- [ ] (Gate 1b) new `city_district_theming_present` scenario in
      `tests/sim_test.gd` — the only machine-checkable home for the theming
      law: on a real generated City it recomputes INDEPENDENTLY (a) each
      park's district from `district_of` and its slab tint/tree layout from
      the const tables over the `PARK_BLOCKS` centers (equality, including d3's
      0.8 crowns and 19 total trees), (b) each anchor's restyle — per-district
      tier tints/widths, the detail-instance counts (4/2/12/3), zero colliders
      beyond the four tiers (3 shapes above y 5.0 per anchor), tops/crumb
      records intact, (c) the d3 shaft's building standoff re-derived per seed
      from `buildings[]` (the plinth derivation, extended to the shaft's
      height band), (d) same-seed `generate(default_seed, true)` reproduces
      the themed-park and anchor arrays byte-identically (the
      `_props_reproduced`/`_vec_spots_equal` pattern), and (e) at BOTH pinned
      seeds the cross-version fingerprint equals the re-derived literals.
- [ ] (Gate 1b) every pin break named in What is amended in the same
      change-set and the FULL suite is green (0 failures).
- [ ] Mechanics untouched: elders/favor/hunger/scoring/traffic re-derive
      nothing — the elder seat ring is plaza-side, benches remain crumb hosts
      wherever they land, and the bread-budget spawner integers are
      probe-verified (re-derived if the awning pool moved).
- [ ] Tone check passes: invented names only in any new string/comment, no
      real-world marks, no sub-goals or objectives anywhere in the diff, no
      rendered text.
- [ ] [screenshot] From cruise height the four quadrants are distinguishable
      by silhouette and dressing alone — canopy deltas read (treeless formal
      square / bare-edged green / framed quad / buried block), each signature
      steers by, and the T-088 backdrop ring stays background; at block level
      each district reads as its theme (tints, signboards/awnings, prop
      rhythm). The map still reads balanced (T-135's line re-checked).

## Verification

Forge legs first — no implementation commit before the owner's sign-off lands
in this file. Then Gate 1 (import + 120-frame boot + `--check-only --script
res://scripts/city.gd`) + Gate 1b FULL suite green with
`city_district_theming_present` added to the `VERIFICATION.md` table and every
pin-quoting row refreshed (same change-set); explicitly re-run the T-135
record's list — `city_one_park_per_district`, `city_park_trees_present`,
`city_roofs_inhabited`, `city_district_anchors_present`,
`city_same_seed_deterministic`, `city_regenerate_restores_layout`,
`elder_placement_no_rng`, `city_cafe_tables_present`, `city_footprints_vary`,
`city_plaza_props_clear`, `city_new_seed_guarantees`,
`splat_favor_follows_citizen_class`, `citizen_classes_spawn_deterministic`,
`city_street_flyover`, `city_roof_landable`, `city_plaza_spawn` — plus
`city_district_palettes_distinct` (expected unchanged, must be proven) and the
T-090 signboard scenario (its plaque surface changed). Gate 2 (`AUTOPLAY DONE
ok=true` — nothing grows; the 23 m cruise floor clears the unchanged 17.42 m
tops). Gate 3 new lines, per district — "(T-136) District N reads as its theme
from cruise height and at street level [screenshot]" — plus "(T-136) the map
still reads balanced: four dressed parks, four signatures, T-088 ring
background [screenshot]" and the T-004 city-readability lines re-checked.

## References

Research: `docs/references/district-theming/research.md` (fetched Wikipedia
dimensions for campanile/water tower/silo/marquee + all photo readings; the
dressing tables and D-A mapping above are grounded there. Review round 1
correction: research.md's "Des Moines tank ≈ 2.5–3× its column ring" photo
reading is WRONG — the photo measures ≈ 1.3× — so every width-ratio claim in
this ticket is grounded in the Random Lake photo alone). Photos — the facts
the implementation MUST respect, orientation first:

- `docs/references/district-theming/main-street-naas-aerial.jpg` — (1)
  buildings wall BOTH sides of the street in one continuous canyon, rear
  alleys splitting the rows: main-street identity is FURNITURE and tint, not
  new street geometry; (2) cars park nose-to-curb and the canyon is virtually
  treeless → d0 gets the lowest tree count (2, formal pair); (3) the rows are
  consistent 2–3 story volumes — no tower interrupts the canyon.
- `docs/references/district-theming/geneva-marquee.jpg` — (1) the marquee box
  projects over the sidewalk AT THE ENTRANCE, letter board facing along the
  street, bulb strip around the box's outer perimeter (the D-A emblem
  approximates the perimeter with corner bulbs); (2) warm brick + cream trim +
  dark-green awnings + cream letter board is the district's whole palette
  story — the exact d0 tint set; (3) the vertical blade rises one extra story
  from the marquee's street-facing edge.
- `docs/references/district-theming/julesburg-theater.jpg` — the bare
  blade-sign variant (a green blade reading ACROSS the facade, no letter
  board, no canopy): the recorded fallback if the owner wants a plainer d0
  emblem. Not the default.
- `docs/references/district-theming/allen-hazen-water-tower.jpg` — (1)
  everything sits ON TOP: column ring + central riser + entablature + drum
  tank with top railing — the tier stack maps 1:1; (2) the neoclassical ring
  runs WIDE relative to its tank — the drum overhangs the ring only slightly
  (tank ≈ 1.3× the ring span, review-measured off the photo 2026-10-24; NOT
  the ≈ 2.5–3× this ticket first carried from research.md — no reading of
  "support width" yields that; the multi-x ratio belongs to the single-column
  type) — so this photo grounds the ON-TOP stacking, never a width ratio; (3)
  antennas rise from the tank top — moved off-center in-game for the
  crumb, noted in What.
- `docs/references/district-theming/random-lake-tower-aerial.jpg` — (1) the
  name band runs HORIZONTALLY around the tank, readable from the air (the
  gold band's placement); (2) the spheroid tank measures ≈ 3× the single
  column's width ("golf ball on a tee" — the type the d1 restyle mirrors; the
  1.8 m head on the 0.7 m shaft ≈ 2.6× sits just under it); (3) the
  surrounding residential town is buried in mature
  tree canopy — this is BOTH the d3 canopy target and the proof the aerial
  read matters.
- `docs/references/district-theming/isu-campanile-full.jpg` — (1) the tower
  stands centered in a big open mown lawn, tree clusters framing the edges,
  middle open → d2's 8-tree frame; (2) the plain shaft runs ≈ 75–80% of the
  height (the post's shaft tier is 13.6 of 17.3 ≈ 79%); (3) a clock face sits
  just below the belfry on the visible face.
- `docs/references/district-theming/isu-campanile-angle.jpg` — (1) a clock on
  EACH flat face (two visible here) — never one side only; (2) the belfry is
  an OPEN arched tier with the bells visible through the arches (the dark
  inset boxes); (3) a pyramidal slate spire caps it with corner pinnacles at
  the belfry tier (the slate cap + corner pinnacles).
- `docs/references/district-theming/dane-county-silos.jpg` — (1) silos CLUSTER
  (three here — one gray concrete-stave, two blue Harvestore-style) directly
  beside the barns, never freestanding mid-block: under D-A one emblem stands
  alone and the cluster/barn read is honestly forgone; (2) silos top out ≈
  1.5–2× the barn roof; (3) the stave type shows vertical seams + horizontal
  hoops — the hoop bands carry the read at box scale.

## Implementation record

*(pending — fires on the owner's sign-off of the three picks; implementation
routes through the pipeline after that, `scripts/city.gd` pin surfaces first)*

# T-069 — Paint the intersections — crosswalks so streets read as streets

- **Milestone:** Sweep backlog · **Status:** done · **Category:** worldbuilding ·
  **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** — (builds on the landed T-004 blockout and T-008 traffic offsets; no open
  dependency)
- **Refs:** `scripts/city.gd:383-413` (roads + dash gate) · T-017 (the visual-only
  MultiMesh decision: decoration gets no colliders) · T-031 (the zero-RNG / zero-`_fp`
  layout precedent, `scripts/city.gd:550-554`)

## What

Zebra crosswalks at every intersection, painted the same way the lane dashes are: queued
MultiMesh instances, no new nodes per stripe, no physics.

1. **`scripts/city.gd`** — new `_build_crossings()`, called from `generate()` immediately
   after `_build_roads()` (`scripts/city.gd:231`). It reuses the road-center grid math
   (`scripts/city.gd:384-387`): `blocks_per_side + 1` centers per axis → 64 intersection
   nodes with default exports.
   - Per node, per approach (+x / −x / +z / −z): one zebra band on the road centerline,
     centered `road_width * 0.5 + 1.2` = 6.2 m out from the node along the approach axis.
   - A band is 5 stripes; each stripe is a box `0.4` m along the road × `road_width`
     across × `0.01` thick, stripe centers spaced `0.5` m on centers — distances
     5.2 / 5.7 / 6.2 / 6.7 / 7.2 m from the node, so the band footprint spans 5.0–7.4 m
     out. The 5.0 m inner edge clears the corner-cut area turning cars sweep through
     (`traffic_lane_offset` 3.5 m, `scripts/city.gd:107-111`) by 1.5 m.
   - **Skip an approach whose band would leave the asphalt:** node coordinate ± 7.4 m
     outside `±city_span * 0.5`. With defaults this drops the 32 outward approaches of
     the outer ring (node centers ±112; band outer edge 119.4 > span half 117 — the road
     ends at ±117 and the stripes would paint grass). Result: 224 bands = 36 interior
     nodes × 4 + 24 rim nodes × 3 + 4 corner nodes × 2, × 5 stripes = **1,120 instances**.
   - Height follows the two dash families exactly: stripes on vertical roads (band
     running along z) at y = `road_slab_height + 0.005` — the vertical-dash recipe
     (`scripts/city.gd:401-402`); stripes on horizontal roads at y =
     `road_slab_height - 0.005 + 0.005` — the horizontal-dash recipe
     (`scripts/city.gd:403-404`). Each sits flush on the slab family it paints, 5 mm proud.
   - New layout consts beside the cafe ones (`scripts/city.gd:53-59` pattern):
     `CROSSWALK_OUTSET := 6.2`, `CROSSWALK_STRIPE_PITCH := 0.5`,
     `CROSSWALK_STRIPE_DEPTH := 0.4`, `CROSSWALK_STRIPE_COUNT := 5`.
   - One new MultiMesh key `"crosswalk"` in `_make_meshes()`
     (`scripts/city.gd:350-365`): `_unit_box(_flat_material(COLOR_CROSSWALK))`, with
     `const COLOR_CROSSWALK := Color(0.78, 0.78, 0.75)` (worn white, clearly not the
     yellow `COLOR_LANE_MARK`, `scripts/city.gd:32`) beside the other colors
     (`scripts/city.gd:26-37`). Instances queued via `_add_mm("crosswalk", _box_xf(...))`;
     `_spawn_visuals()` (`scripts/city.gd:669-685`) turns the key into one
     `MultiMeshInstance3D` named `Crosswalk` under `Visuals`.
   - **Zero `_add_collider` calls** (T-017 visual-only decision), **zero RNG draws**,
     **zero `_fp.append`** (T-031 precedent) — the fingerprint and every RNG stream stay
     byte-identical.
2. **`tests/sim_test.gd`** — new `city_crosswalks_present` scenario (see Verification).
3. **`VERIFICATION.md`** — Gate 1b table row for the scenario.

Two corrections to the reviewed plan, both verified by replicating the
`scripts/city.gd:383-413` arithmetic with default exports:

- The plan sketched 64 × 4 bands = 1,280 stripes, but its own criterion "every stripe
  center inside its approach road's asphalt rect" forbids the 32 rim outward approaches.
  The asphalt-bounded rule above is the spec: **1,120**.
- The plan review flagged a coplanar overlap with a center dash "at 6.0 m" needing a
  `_near_road` extension. No fix is needed: the dash gate already skips everything
  within `road_width * 0.5 + 1.5` = 6.5 m of any center (`scripts/city.gd:409-413`), so
  the dash position 6.0 m from a node is never drawn; the nearest dash actually placed
  sits 10.0 m out and its 1.8 m length stops 9.1 m out — 1.7 m clear of the band.
  `_near_road` is untouched by this ticket.

What this does NOT claim: no gameplay or physics change (no colliders, no spawns, no
scoring, cars and pigeon never sense the paint); no change to the existing dashes; no
mid-block crossings or pedestrian logic — intersection paint only; the exact tone of the
paint is Gate 3 judgement.

## Why

All 64 crossings are blank 10 × 10 m asphalt — at pigeon eye level the city reads as
gray canyons to nowhere, and the only road markings anywhere are the sparse center
dashes, which stop 6.5 m short of every intersection *by design*
(`_near_road`, `scripts/city.gd:400,409-413`): nothing inside the crossing box ever says
"road", and low flight down a street gets no visual rhythm from the crossings it passes.
Machine-side the gap is airtight — no marking key is ever placed within 6.5 m of an
intersection node (verified this run by replicating the dash loop). The sweep lane's
low pass down the x=16 street and an aerial pass reported the same blankness at eye
level and from above; those session frames were not retained on disk, so they are not
re-captured here — Gate 3 re-judges the look on fresh screenshots.

## Acceptance criteria

- [x] The `Crosswalk` MultiMesh has exactly 1,120 instances with default exports — 224
      bands × 5 stripes (36 interior nodes × 4 approaches, 24 rim nodes × 3, 4 corner
      nodes × 2; every approach whose band would leave the asphalt skipped)
- [x] Every stripe is axis-aligned with extents {0.4, road_width} in the ground plane ×
      0.01 thick; stripes on vertical roads sit at y = `road_slab_height + 0.005`, on
      horizontal roads at y = `road_slab_height` (the two dash-family recipes)
- [x] Every stripe center lies ≥ 5.0 m from every intersection node in XZ (turning
      traffic's 3.5 m corner-cut swing area, `scripts/city.gd:107-111`, stays clear by
      1.5 m) and inside its approach road's asphalt rect (|along-road coordinate| ≤
      `city_span * 0.5`, cross-road on the centerline)
- [x] Each unblocked node approach carries exactly 5 stripes centered at
      5.2 / 5.7 / 6.2 / 6.7 / 7.2 m along the approach axis, on that road's centerline
- [x] A forced same-seed rebuild reproduces all 1,120 transforms byte-identically
      (`_spots_equal`, `tests/sim_test.gd:1093` — the `elder_placement_no_rng` pattern,
      `tests/sim_test.gd:1109-1131`)
- [x] No `StaticBody3D` exists anywhere under the city's `Visuals` root — the paint is
      visual-only (T-017 decision)
- [x] Gate 1b suite green unchanged, explicitly `city_street_flyover`,
      `cars_traffic_loops_blocks`, `city_sidewalk_walkable` and
      `city_same_seed_deterministic` (zero `_fp` entries keep the fingerprint stable)
- [x] `density_cpu_budget` re-run green with the extra MultiMesh (1,120 instances, one
      extra draw key)
- [x] [screenshot] An eye-level pass down a street shows a zebra band ahead at each
      crossing, reading as worn road paint, not glowing geometry
- [x] [screenshot] An aerial pass shows the crossing grid banding the intersections;
      no z-fighting shimmer between stripes and slabs at any of the 64 nodes

## Tuned values (as landed)

- `CROSSWALK_OUTSET := 6.2` · `CROSSWALK_STRIPE_PITCH := 0.5` ·
  `CROSSWALK_STRIPE_DEPTH := 0.4` · `CROSSWALK_STRIPE_COUNT := 5` — band footprint
  5.0–7.4 m out from each node, stripe centers 5.2 / 5.7 / 6.2 / 6.7 / 7.2 m.
- `COLOR_CROSSWALK := Color(0.78, 0.78, 0.75)` — worn white, distinct from the yellow
  lane mark; reads as road paint, not glowing geometry (Gate 3 pass, screenshots at
  `.captures/t069_eye_level_crossing*.png`).
- Counts at the default seed: 224 bands (36 interior nodes × 4 + 24 rim × 3 + 4 corner
  × 2) → 1,120 stripes; `Visuals/Crosswalk` instance_count == 1120 (machine-checked).
- Layout fingerprint unchanged at 2492360539 (byte-identical to pre-T-069); Gate 1b
  `density_cpu_budget` median 268.0 ms per 100 physics frames (budget 750).

## Implementation note (T-069, agent pass 2026-09-30)

- One deliberate deviation from the Verification plan: `MultiMesh.get_instance_transform`
  reads back IDENTITY for every key in headless runs (the dummy RenderingServer never
  uploads the instance buffer — verified with a throwaway probe against the pre-existing
  `Dash` key too, which also read all-identity). `city_crosswalks_present` therefore
  asserts `instance_count == 1120` off the `Visuals/Crosswalk` node itself (readable,
  headless-proven) and walks the transforms from the queue that feeds that exact
  MultiMesh (`_visuals["crosswalk"].xfs`, copied verbatim by `_spawn_visuals`, same
  build, same order). The queue must stay in sync with the node or the count assert
  fails.
- Gates run on this branch: Gate 1 import + 120-frame boot clean; Gate 1b full suite
  `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` → 0 failures,
  `SIM DATA city_crosswalks: stripes=1120 bands=224 fingerprint=2492360539` (fingerprint
  unchanged from the pre-change print in the same log's roofs scenario), Gate 1b
  `density_cpu_budget` median 268.0 ms ≤ 750; Gate 2 autoplay `AUTOPLAY DONE ok=true`
  (fps 134, restart=true).
- Fresh screenshots captured for the Gate 3 human pass (the ticket's earlier session
  frames were not retained, so these are new): eye-level low pass down the x=16 street
  with bands ahead at the crossings — `.captures/t069_eye_level_crossing.png`,
  `.captures/t069_eye_level_crossing2.png` (pilot session `t069gate3`); aerial cruise
  over the grid with the crossings banding at every intersection —
  `.captures/t069_aerial_grid.png`, `.captures/t069_aerial_grid2.png` (Gate 2 autoplay
  frames). Gate 3 human pass signed off 2026-09-30: paint reads as worn road paint at
  eye level, the grid reads at altitude, no shimmer — both [screenshot] criteria ticked.

## Verification

- **Gate 1** — headless smoke, both exit 0, zero ERROR lines.
- **Gate 1b** — full suite via
  `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
  (`VERIFICATION.md:31`), including new scenario `city_crosswalks_present`, registered
  in `_run_scenarios`:
  - find `_city.get_node("Visuals/Crosswalk")`;
  - assert `multimesh.instance_count == 1120`;
  - walk every `get_instance_transform(i)` for the geometry / y / ≥5.0 m / asphalt-rect
    criteria above (y within 0.001 of the family value);
  - snapshot all 1,120 transforms into an `Array[Transform3D]`, `_city.generate(default_seed, true)`,
    snapshot again, `_spots_equal` (`tests/sim_test.gd:1093`);
  - assert `find_children("*", "StaticBody3D", true, false)` under `Visuals` is empty.
  - Re-run green, unchanged: `city_street_flyover` (`tests/sim_test.gd:586`),
    `cars_traffic_loops_blocks` (`tests/sim_test.gd:1763`), `city_sidewalk_walkable`
    (`tests/sim_test.gd:654`), `city_same_seed_deterministic` (`tests/sim_test.gd:557`);
    re-measure `density_cpu_budget` (`tests/sim_test.gd:2877`).
- **Gate 2** — autoplay smoke as usual (`VERIFICATION.md:119`); no behavior change expected.
- **Gate 3** — two lines, both [screenshot]: eye-level — a crossing ahead reads as paint
  in the street canyon and doesn't glare; aerial — the crossing grid reads at altitude
  and no stripe shimmers against the slabs.

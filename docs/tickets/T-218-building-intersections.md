# T-218 — Buildings intersect when they shouldn't: 1,239 interpenetrating massing pairs, one duplicate entry

- **Status:** proposed · **Category:** worldbuilding (data + render,
  diagnosis-first — the fix scale is an owner pick) · **Value (1-5):** 4 ·
  **Risk (1-5):** 3
- **Depends on:** nothing (evidence landed 2026-11-22)
- **Refs:** T-172 (the bake's massing pass), T-175 (placeholders), T-206
  (dressing families), T-205 (venue fixups) · the probe:
  `python -I tests/tools/building_intersect_probe.py` (stdlib; reads the
  bake chunks + the pack; the truth pass re-derives REAL footprints from
  `docs/references/ames-survey/osm/ames_merged.json` with the pack's own
  projection, `ames_data_pack.gd` constants) · eyes-on repro: teleport
  (-88.85, 70, -60) for the Friley slab, (500, 24, -766) facing south for
  the Kildee×Meats wall crossing

## What

The bake renders every building as ONE axis-aligned box — the footprint's
AABB at its centroid (`ames_baker.gd` massing pass). A full-stock sweep
(10,773 visible masses, 106 placeholder parts, 7,223 dressing boxes, 9,163
gable prisms over all 553 chunks; spatial hash, 3D AABB pairs) plus a
truth pass against the survey's real OSM polygons says:

1. **1,239 pairs of DISTINCT buildings' boxes interpenetrate** (789 with a
   ≥1 m mutual bite in both ground axes). The residential fabric alone:
   965 procedural×procedural pairs (687 serious; bites to 17.5 m — the
   119×138 m apartment slab `way/964842191` swallows a 17×23 m house
   whole), and **1,170 of 9,184 residential buildings (12.7%) sit in at
   least one interpenetration**. Campus worst (authored×authored, m³ of
   mutual volume): Friley×Helser 114,750 — Helser's ENTIRE box sits inside
   Friley's 192×207 m envelope; Vet Med×Lloyd 59,799; Meats×Kildee 55,405;
   TASF×Spedding 47,615; State Gym×Eaton 40,787; Collegiate Presbyterian
   ×itself 39,396; UDCC×Friley 13,517; King×College of Design 12,937;
   Bergstrom×Stark 12,876; Therkildsen×Howe 12,724; LeBaron×HNS 12,164;
   LeBaron×MacKay 11,068. The L-shaped giants (Friley, Vet Med) render as
   solid slabs covering the courtyards reality keeps open.
2. **The truth pass acquits the data**: 1,237 of the 1,239 pairs have
   CLEAN real footprints — the intersections are the AABB render
   approximation (rotated and L-shaped footprints → fat envelopes), not
   bad geometry. The two real overlaps:
   - **Collegiate Presbyterian Church is double-entered** —
     `relation/3377215` and `way/251728632` share the IDENTICAL ring,
     centroid AND bbox (the relation's sole outer member IS that way). The
     same real building renders TWICE as exactly coplanar boxes: a
     whole-footprint z-fighting surface (~1,950 m²), double collision,
     double occluder, and two different id-hashed colors flickering. The
     pack's only duplicate group (exact centroid+bbox scan, n=1).
   - **Ames Lock & Security × Melissa Stenstrom Fine Jewelry** — two
     downtown storefront footprints genuinely overlap ~46 m² (row-fabric
     surveying noise).
3. **Downstream dressing pokes ride the same envelopes**: 551
   dress×foreign-massing hits (237 ≥1 m bites) — cornice/parapet OUTSET
   bands and rooftop screens extending already-overlapping boxes into
   neighbors; almost all at §1 pair sites. The one independent class:
   **~113 pairs of porch decks/canopies poking into neighbors where the
   PARENT boxes are clean** (the porch extends past the footprint into a
   close neighbor's lot).
4. **Placeholder overlaps split by intent**: all 51 massing×hero-part hits
   are Jack Trice's own support buildings (Sukup Endzone, Press Box,
   concessions, Jacobson) punching the bowl/berm silhouettes — REAL-WORLD
   NESTING (the endzone building stands in the bowl), intended-with-a-note,
   NOT defects. The defects: **Café Beaudelaire × Mr. Burrito** — two
   adjacent Campustown storefronts both get the constant `VENUE_FIXUP_SIZE`
   box and the boxes overlap 5.2×9.9 m (both collide); and 16 fixups
   (Stomping Grounds, The Cafe, Blue Owl, Welch Ave Station …) poked by
   their host buildings' porch/cornice dressing.

The survey docs acknowledge none of this (QA/census/SUMMARY never mention
building overlap) — it is undocumented bake behavior, not a recorded
acceptance.

## Why

The R5 cutover's product is the town's shape honesty — "the whole town at
every boot" — and today 12.7% of the homes and the campus's biggest
residences visibly lie about their geometry: slabs where reality has open
courts (Friley's envelope covers ~4 ha), swallowed neighbors, walls
crossing walls with different id-hashed colors, and one whole church
flickering in a z-fight with itself. The data leg is a straight bug; the
render leg deserves an owner decision on the box house style.

## Fix options (the owner picks the scale)

- **A. Data leg** (cheap, unambiguous): dedupe the church (keep one entry,
  the named authored slot); decide the 46 m² storefront pair (nudge or
  accept as row-fabric noise).
- **B. Render leg** — three costs:
  1. *Min-area rotated rectangle per footprint*: massing gains a yaw;
     MultiMesh transforms, dressing, occluders, collision and the ground
     record all compose the same basis. Kills the rotated-row bulk but NOT
     the L-shaped giants (Friley stays fat).
  2. *Footprint-fit prisms*: bake the actual polygons (ear-clip offline,
     the lawn/water-tri house style), render per-chunk merged meshes — the
     honest shape, the biggest change (draw budget re-derivation;
     collision/occluder/ground re-plumb).
  3. *Accept + document* the box style (QA note) and hand-fit only the
     top campus offenders.
- **C. Dressing leg**: clamp porch reach to neighbor distance; the
  cornice/parapet outsets fold into whatever B lands.
- **D. Fixup leg**: shrink/nudge venue fixups when two sit closer than the
  box (Beaudelaire/Mr. Burrito) or when a host's porch band crosses.

## Acceptance criteria

- [ ] Data leg: no duplicate-entry buildings in the pack (an
      `ames_data_integrity`-style row: no two entries share a ring /
      centroid+bbox); the church renders once.
- [ ] Gate 1b `ames_massing_intersections` row — the probe as a scenario
      pinning the residual budget of whatever fix lands (footprint-fit →
      0 non-design pairs; min-area rect → its pinned small count; accept →
      pinned at today's 1,239 with the by-design stadium nesting and
      same-hero parts excluded).
- [ ] The chosen render leg re-pins `ames_world_render_budget` (draw
      ceiling 2100) and the ground record's consumers, or explicitly
      leaves them untouched with the check re-run green.
- [ ] *(Gate 3, eyes-on)* fly the Richardson court complex (Friley/Helser)
      and the Campustown Lincoln Way strip: no swallowed-neighbor
      silhouettes, no z-fighting church, storefronts read as separate.

## Verification (proposed)

Gate 1b (the new intersection row + the re-pins) · the box gate rides the
next T-213 run if B.2 changes the draw story · Gate 3 as the flight above.

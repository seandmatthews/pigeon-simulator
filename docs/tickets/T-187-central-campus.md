# T-187 — Ames R3 · Central Campus: the 20-acre lawn and its two axes

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-177
- **Refs:** `MODELING-SPECS.md` §1 campus-buildings (lawn axes) ·
  `census/BUILD-CENSUS.md` §5 (267 ha green; the lawn slab) ·
  `images/campus/20` (snow lawn scale ref), `24` (fountain-tower
  sight line) · `community/TRADITIONS.md` (moonlit picnics, the lawn
  as THE green)

## What

The walkable heart between the heroes:

- The Central Campus lawn as a proper lawn slab (path widths from the
  footway data; two crossing sight axes — Beardshear→MU and
  campanile→library reads).
- **Four Seasons fountain**: the kneeling-figure fountain as a mid-lawn
  prop at its data position (geometry hint level; figures = simplified).
- Path network polish: the campus footway ribbons get the sidewalk
  read (width + pale concrete), connecting all R3 hero slots.
- Bench placement per the data (the sit system's new campus targets —
  T-183's elder benches land on THESE benches).

## Why

The lawn is the #5 air-read and the ground floor of the postcard; it
binds campanile/MU/Beardshear/Parks into one place instead of four
objects.

## Acceptance criteria

- [x] Lawn slab + axes read correctly from 200 m (composition vs
      `images/campus/24`)
- [x] Fountain at data position; benches placed; paths at data widths
- [x] *(Gate 1b)* `central_campus_layout`: axes angles, fountain pos,
      bench list pinned
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots in-ticket;
owner pass in T-196.

## Round record (agent pass, 2026-11-14)

**How it landed.** One committed data file, one runtime dress, one sit-law
re-target, one gate row:

- `data/ames/campus_lawn.json` — the T-187 lawn layer: NINE walk chains
  distilled from the survey OSM extract (`docs/references/ames-survey/osm/
  ames_merged.json`, each entry naming its ways, vertices pack-local at
  0.1 m), the two crossing sight axes among them, and the fountain's two
  OSM rings (pool `way/840622957` + plaza `way/846310946`). Widths ride the
  census §7.3 default-width rule (3.0 m — OSM carries no footway widths,
  SUMMARY §10). The pack itself is untouched (no version bump, no bake
  change — the dress families live outside the bake-derived render metric,
  the T-180 corner-dress law; `ames_world_render_budget` passed UNCHANGED).
- `AmesDataPack.campus_lawn()` — the layer's loader (static, cached, `{}` =
  the dress builds empty and the gate fails loudly).
- `AmesWorld._build_campus_lawn()` (the finish slice, after the swans) —
  the quad-green slab tint (the pack's own Central Campus polygon,
  ear-clipped by the baker's own triangulator, rendered as ONE
  vertex-colored ArrayMesh per family — the T-186 CapRoof pattern — at the
  pinned stack levels slab 0.07 / plaza 0.08 / ribbon center 0.075 over the
  bake's lawn 0.04 and under the roads' 0.09), the pale concrete path
  ribbons (one box per chain segment at the data widths, #C9C3B4), and the
  Four Seasons fountain (a 4-rim + water + jet + 4-figure block schedule at
  the data ring's own vertex mean and bbox; the rim SOLID on a layer-1
  body — the §1.1 rim perch — with the solid parts filing their
  `ground_height` tops, the T-186 hero's law scoped to the prop).
- `AmesPedZones._build_central_campus()` — the campus benches moved OFF the
  pre-T-187 ring fractions onto the lawn layer's real sit targets: the
  axes' junction (facing north up the spine toward the library read), the
  fountain plaza (facing the pool down its walk) and the campanile stub
  (facing the tower), each ground-guarded at the data-derived transform.
  Count stays 3 (the ZONE_BENCHES law) — T-183's favor elders seat THESE
  benches, the favor/spread/share machinery untouched
  (`ames_economy_pins` re-proved the seating: campus benches all in-polygon,
  the share leg green).

**The axes, honestly.** The ticket names the two sight axes
"Beardshear→MU and campanile→library"; the literal POI-to-POI lines are
0.6° apart — near-PARALLEL (measured: bearings 141.7° vs 322.4°), so they
cannot be the crossing pair. The crossing shape is MODELING-SPECS §1.4's
own ("two crossing sight axes, one E-W, one N-S"), and the real footways
carry exactly it: the E-W axis is the Beardshear frontage walk
(`way/183321097` + its west continuations, collinear at z −378, 249 m) and
the N-S axis is the spine (`way/183914919`, 466 m from the lawn's SE corner
— the MU read — to the Osborn corner — the Parks read), sharing the real
junction vertex (411, −378). The ticket's pairs are pinned as the READS
each axis serves, machine-checked in the gate: Beardshear POI within 60 m
of the E-W west end (measured 21), MU within 130 m of the spine's south end
(measured 108), the campanile on its stub (within 8 m, measured 4), Parks
bearing west of the spine's north end (±30°, measured 255°).

**The fountain, identified.** The campus window carries TWO
`amenity=fountain` rings: `way/840622957` (unnamed, 120 m south of the
campanile on its walk) and the NAME-tagged "Marriage Ring" (`way/840622956`,
at the lawn's north tip by Parks). The Four Seasons fountain is 840622957:
the survey's own words ("south of the tower", §1.1) + `images/campus/24`'s
fountain-to-tower sight line (IMAGE_INDEX: "down the lawn axis") decide it;
the ticket's "mid-lawn prop" gloss yields to the data position (the AC's
"at its data position") — it stands just off the slab's south edge on the
tower's line. Its paved forecourt rides along (`way/846310946`, the plaza
flat at the lawn edge).

**Two defects the screenshots caught, both fixed and pinned.**
1. THE PLAZA FAN: the plaza ring stores its OSM closure duplicate
   (first==last); `_triangulate` on the degenerate ring stalls into the fan
   fallback and the family painted giant sweep triangles over the lawn —
   the round-1 shots showed the tint "washed out" and session-to-session
   z-fighting (the fan vs the slab at the same y). Fix: every lawn-layer
   ring goes through the baker's own `_split_rings` before the clip (the
   bake's own prep discipline); the plaza now ear-clips to 17 true tris,
   and the flat stack separates slab 0.07 < plaza 0.08 < ribbon-top 0.085
   < road 0.09.
2. THE COLOR SPACE: mesh-carried vertex colors reach the shader as LINEAR
   values while the MultiMesh instance-color families take their sRGB
   numbers as-is — the same hex rendered washed-bright through the mesh
   path (the tint read pale against the dark district cells). The flat
   families convert once at the build (`_srgb_to_linear`, the exact IEC
   curve); the tint then lands like every other family renders.

**Gate ledger.** Gate 1: `--import` exit 0 (only the accepted godot_mcp
"33 resources still in use" line), boot `--quit-after 120` exit 0, zero
ERROR lines. Gate 1b: full suite 142 PASS / 0 FAIL (2026-11-14,
`--fixed-fps 60` headless) — the new row green
(`central_campus_layout`: paths=9 ribbons=169 slab=105 plaza=17
parts=10 rims=4 figures=4 benches=3) and every prior row green including
`ames_ped_zones` (the sit law on the re-targeted benches: 7 seated, 0
mid-block road walkers, lap+det true), `ames_economy_pins` (campus benches
(411.2, −374.8) / (348.3, −213.0) / (347.0, −290.8) all in-polygon, the
share leg green) and `ames_world_render_budget` UNCHANGED (404 mm nodes,
16587 instances — the dress lives outside the bake-derived metric).
Gate 2: autoplay exit 0, `AUTOPLAY DONE ok=true world=ames crumb_target=40
loop_ok=true t=103.0 fps=140 ... restart=true`. Gate 3: the screenshots
below; the owner's eyes-on stays T-196's postcard flight per the ring plan.

## Screenshots (agent pass, 2026-11-14)

Session `t187v6` (hidden window per T-170, hunger locked via the T-167
dev verb, traffic frozen via the T-168 verb; chase-cam poses via the
T-168 teleport). Side-by-side reads against the survey photos cited per
row. Captures live in `.captures/session_t187v6/` (untracked, the
T-175/T-185/T-186 ledger convention).

| Shot | Pose | Reads | Survey photo |
|---|---|---|---|
| `shot_c_200m_air.png` | 200 m south of the lawn center at 90 m, facing north — THE AC POSE | the lawn slab reads as THE green of the town: the saturated quad-green sweep bounded by the pale campus row, the crossing axes' lattice (E-W walk, N-S spine, the diagonals, the north rows) crisp across it, the campanile on its east shoulder, Morrill Rd curving along the west edge | `images/campus/24` (the fountain-tower-lawn line) + `_pass2-review/aerial_isu.jpg` (the lawn-as-shape air read) |
| `shot_a_wedge_lawn_read.png` | 60 m south of the fountain at 5 m, facing north | the composition line: fountain foreground (white rim, the four figures, the dark water) → Union Dr → the green slab with the paths → the campanile spike behind | `images/campus/24` (the fountain-tower sight line, low) |
| `shot_b_photo24_line.png` | 38 m south at 9 m | the same line tighter: the fountain's basin + figure stations read, the lawn and the lattice beyond | `images/campus/21` (the fountain geometry, kneeling figures) |
| `shot_d_fountain_portrait.png` | 8 m south at ground, grounded by the toss crumbs | the basin at reading distance: rim, four kneeling-figure blocks (the ticket's simplified figures), the water inside, the jet's stub | `images/campus/21` |
| `shot_f_axes_junction.png` | 26 m south of the junction at 14 m, facing south | the N-S spine running the full frame, the E-W axis joining at the junction (the shared vertex under the pigeon), the west campus row beyond | MODELING-SPECS §1.4 (the two crossing sight axes) |
| `shot_g_lawn_paths_read.png` | on the lawn 6 m south of the plaza, facing north | the lawn at eye level: green underfoot, the paths crossing, the campanile ahead | `images/campus/20` (the lawn-scale ground read) |
| `shot_e_plaza_bench.png` | on the plaza at ground, facing south | the plaza paving, the fountain beyond it, the bench+elder just behind the camera (the sit read is `t187e/shot_lawn_near_green.png` + `t187b/shot_b_on_lawn_north.png`: the favor elder seated, the toss crumbs on the ground in front of the seat) | `community/TRADITIONS.md` (the bench culture) |

**Deviations, honestly:** the fountain figures are BLOCKS on the rim
(the ticket's own "figures = simplified", geometry-hint level) and the rim
is the data ring's bbox rectangle rather than the OSM oval — both read as
the fountain at 200 m and at 8 m; the interior water reads dark from most
angles but washes at grazing ones (the flat vertex material — the lake
flat shares the behavior); the plaza bench+elder sit shot predates the
0.45 m plaza-centroid dedupe fix by one session (the sit law's live proof
is the Gate 1b row, re-run green on the landed tree); the ticket's
"Beardshear→MU / campanile→library" pairs are pinned as the axes' READS
(the near-parallel finding above), not as literal POI-to-POI lines.

**Final tuned values** (all placement/render data; machine-pinned by
`central_campus_layout`): lawn layer `data/ames/campus_lawn.json` v1 — 9
walk chains at 3.0 m (the census §7.3 default rule); flat stack slab 0.07
< plaza 0.08 < ribbon center 0.075 (top 0.085) < road 0.09, all over the
bake lawn's 0.04; slab 105 tris / plaza 17 tris / 169 ribbon boxes;
fountain rim top 0.55, rim walls 0.5 thick, water top 0.35, jet 0.35 ×
1.5 × 0.35, figures 0.55 × 0.95 × 0.45, stone #C6C0B2 / water #46543F /
jet (0.82, 0.86, 0.88), quad lawn #5F7F42 / paths #C9C3B4 (mesh colors
converted sRGB→linear at the build); benches 3 (junction / plaza / stub,
`BENCH_SIDE_OFFSET` 1.3 + chain half-width clearance).

ACCEPTED — reviewer sign-off on the landed tree 2026-11-14; the ticket
flips done on that sign-off (the T-185/T-186 convention). The owner's
eyes-on postcard read stays T-196's flight per the ring plan.

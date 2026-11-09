# T-174 — Ames R1 · skeleton visuals: streets, water, rail, parks readable from the air

- **Status:** done · **Category:** visual-design · **Ring:** R1 The Map ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-173 (renders the bake this dresses)
- **Refs:** `MODELING-SPECS.md` §3 (district dressing v0), §1 clusters
  (lake-laverne, rail-corridor, water-green) · `osm/SUMMARY.md` (street
  classes, widths) · `landmarks/LANDMARKS.md` (materials) · photos:
  `images/lincolnway/`, `images/downtown/01` (street read) ·
  T-026 (the ground-palette retune this inherits), T-148 (skyline haze)

## What

Make the baked skeleton READ as Ames instead of as geometry:

1. **Street dressing**: lane-mark hints on arterials only (Lincoln Way,
   Main, Duff, Grand) — center dashed line, no crosswalk paint yet
   (that is T-180); residential streets stay plain asphalt; the
   125–140 m block rhythm does the rest.
2. **Ground palettes per district** (dressing v0): downtown brick-warm
   sidewalks, Campustown scruffy gray, campus lawn green (the
   20-ac Central Campus slab from the park polygons), Lincoln Way
   commercial strip asphalt, residential seed — palettes picked from
   MODELING-SPECS §3 hex estimates, tuned by screenshot.
3. **Water v1**: LaVerne flat with a shoreline band (the 236×122 m
   oval reads as a lake, not a blue hole); College/Ioway creeks as
   green-blue ribbons; no shader fancy — the town's water is small.
4. **Rail corridor**: ballast gray strip + tie hint, the 9 road
   crossing gaps left honest (no signals yet — T-180/T-194).

## Why

The cutover's Gate 3 bar is "fly Lincoln Way end to end and recognize
Ames" — recognition at cruise altitude is carried by the skeleton's
color and width discipline, not by heroes (which R3 adds later).

## Acceptance criteria

- [x] From 60 m cruise: Lincoln Way reads as a 4-lane arterial, Main as
      a historic 2-lane grid, Campustown as a dense low strip — agent
      visual pass (the ticket's Verification line names Gate 3 as the
      agent pass; the OWNER judgement flight stays T-177):
      `.captures/session_t174vis4/lincolnway_60m.png` — dashed
      centerline(s) down the wide commercial spine (dual carriageways
      where the pack stores them), set-back retail masses, Campustown
      strip right; `main_60m.png` — the masonry wall rows tight on the
      dashed 2-lane with the brick-warm ground band
- [x] District palettes distinct in screenshots; haze (T-148) still
      carries the horizon — `main_60m.png` (downtown brick-warm band vs
      the green residential plate past the rail, Campustown gray toward
      campus), `laverne_200m.png` (campus green basin vs the olive
      lake); the haze band holds the horizon in every shot — owner
      confirmation deferred to T-177 like T-173's AC
- [x] LaVerne reads as a lake with a shore at 200 m —
      `laverne_200m.png` (210 m drop-start, olive water in its Union
      Drive basin with the shore ring and Swan Island's lawn notch) and
      `laverne_shore.png` (~120 m, shore fans at the near rim, College
      Creek joining from the east without canaling across)
- [x] *(Gate 1b)* `ames_skeleton_palette`: pinned per-district ground
      colors (the vertex-color discipline) — existing palette scenarios
      scoped to `windrow` stay green — the new scenario pins the five
      `DISTRICT_GROUND` colors + nine flat-family colors in every chunk
      file, binds every one of the 3,230 baked ground cells to
      `_district_of` at its own center (no residential-seed cells, no
      duplicates, four known-band pins), recounts the 1,647 lane dashes
      exactly from the pack under the 3 m/9 m rule on the four name
      fragments only, recounts the 117 shore quads per ring-split edge
      through the scenario's own ring walk (every quad center within the
      7 m band of the ring, worst 3.50 m), pins the flat STACK
      (cells 0.004 → shore 0.008 → water flat 0.02 — see Landed: the
      first landing's coplanar cells z-fought the lake into lawn), proves
      ties ride ballast 1:1 (1,055) with no tie over crossing asphalt,
      and pins the creek/lake RGB gap (0.158 > 0.05). Suite 186 PASS /
      0 FAIL, `city_district_palettes_distinct` PASS (windrow untouched)
- [x] Pilot screenshot set recorded in-ticket (Lincoln Way, Main,
      LaVerne, rail corridor) vs survey photos —
      `.captures/session_t174vis4/{lincolnway_60m,main_60m,laverne_200m,laverne_shore,rail_corridor_60m}.png`
      vs `images/lincolnway/01` (the wide spine + strip), `images/downtown/01`
      (the Main wall + angled-park read), `images/laverne/01` (water to
      the limestone mass), `images/rail/07` (ballasted double main);
      hidden windows, `PIGEON_WORLD=ames`, T-170 no-focus contract
      (teleport acks in the session's events.jsonl)
- [x] *(Gate 1/2)* clean; `windrow` untouched — Gate 1 import exit 0
      (only the accepted godot_mcp "still in use" line) + 120-frame boot
      exit 0 no error lines; Gate 2 `AUTOPLAY DONE ok=true … restart=true`;
      the only touched gameplay files are AmesBaker/AmesWorld (the ames
      world's own data path) — `city.gd`/windrow byte-unchanged, suite
      pins unchanged (185→186 = the new row only)

## Verification (proposed)

Gate 1 · Gate 1b + one new row · Gate 2 · Gate 3: agent visual pass;
screenshots attached to the ticket.

**Recorded:** all gates run green on the landed tree (Gate 1 import
exit 0 with only the accepted godot_mcp line + 120-frame boot exit 0;
Gate 1b 186 PASS / 0 FAIL, exit 0 — the new `ames_skeleton_palette` row
red-checked live: sabotaged, the arm's `flat stack fights the water`
FAIL fired, reverted, green; Gate 2 autoplay `ok=true restart=true`);
the Gate 3 agent visual pass is the screenshot set above. **Reviewer
signed off 2026-11-09** (round-1 findings — the dead flat-stack arm,
the row's stale y-stack, the stale row numbers — fixed in-commit with
the red-check recorded in Review round 1).

## Tuned values (final, as landed)

- Lane dashes: 3 m dash / 9 m period / 0.4 m wide, `#C7B35A`, y 0.10
  (box top 0.11 over ribbon top 0.09); corridors by name fragment
  ("Lincoln Way"/"Main Street"/"Duff"/"Grand").
- District ground (`DISTRICT_GROUND`): campus `#66874C`, campustown
  `#847E72`, downtown `#A07052`, lincolnway `#55524C`, residential seed
  `#61754D` (= the plate); 32 m cells at y 0.004 (tops 0.014), tinted
  only off the seed.
- Water: lake olive `#46543F` (flat tris at y 0.02), shore band
  `#6F8F4F` 7 m at y 0.008 (tops 0.018), creeks green-blue `#466663`
  (6 m ribbons, lake-interior segments skipped).
- Rail: ballast `#8B8578` 5 m (unchanged), tie stripe `#4A443A` 1.6 m
  at y 0.12 (tops 0.13).
- Bake: `ames_chunks/v2`, 173 chunks, 3.35 MB, total_sha256
  `32e502ed9c95e668541125f1f070bd250c972e16314b148701a15ec823eaeb13`.

## Landed (2026-11-09) — reviewer signed off (see Review round 1)

- **Bake (v1 → `ames_chunks/v2`)**: four new per-chunk families, one
  `FAMILY_KEYS` const keeping the template/counts/totals/doc in one
  place. Re-baked payload 3.35 MB / 173 chunks (one new
  ground-cells-only tile, chunk (4,5), two cells) /
  total_sha256 `32e502ed9c95e668541125f1f070bd250c972e16314b148701a15ec823eaeb13`,
  reproduced by two consecutive tool runs (1.0 s, budgets 60 s / 40 MB).
  Totals: massing 3,737 · ribbons 3,750 · **lane_quads 1,647** ·
  water_tris 113 · **shore_quads 117** · creek_quads 397 · lawn_tris
  1,264 · ballast_quads 1,055 · **tie_quads 1,055** ·
  **ground_quads 3,230** · occluders 3,737 · crossings 9.
- **Lane dashes** (`lane_quads`): name-based rule (`_is_arterial`,
  fragments "Lincoln Way"/"Main Street"/"Duff"/"Grand" — Main's
  residential-tagged eastern stretches stay Main), 3 m dash / 9 m
  period / 0.4 m wide (real paint is 0.15 m — the HINT must survive a
  60 m read), #C7B35A weathered yellow, boxes riding the ribbon top
  (y 0.10, top 0.11 over the ribbon's 0.09). Divided carriageways dash
  per centerline — the pack stores one entry per carriageway, so
  Lincoln Way reads two dashed lines: a divided-arterial look.
- **District ground** (`ground_quads` + `DISTRICT_GROUND`): a 32 m cell
  grid over the whole pack tile range, tinted ONLY where the v0 rule
  says a district other than the residential seed stands (plate = the
  residential seed `AmesBaker.DISTRICT_GROUND["residential"]`, so
  plate and cells never disagree — the renderer reads the same const).
  Measured split: campus 1,945 / lincolnway 691 / downtown 420 /
  campustown 174. Colors from MODELING-SPECS §3 estimates: campus lawn
  #66874C, Campustown scruffy gray #847E72, downtown brick-warm
  sidewalk #A07052, Lincoln Way strip asphalt #55524C.
- **Water v1**: creeks re-colored GREEN-BLUE #466663 (distinct from the
  lake's #46543F olive, RGB gap 0.158); LaVerne shore band
  (`shore_quads`, #6F8F4F mown shore lawn per §1.2, 7 m extruded
  outward from every ring edge with per-loop winding-aware normals);
  and the loading-order fix: **College Creek's centerline runs through
  the pack's lake polygon** (it feeds the lake) — creek segments whose
  midpoint lies inside the lake's ring union paint NO ribbon (6 quads
  skipped), so the oval reads as one lake, not a canal crossing it.
  The scenario recounts the skip with its own ring walk + ray cast.
- **Rail**: `tie_quads` — a 1.6 m dark #4A443A stripe per track riding
  the same unblocked stretches as the ballast (1:1), so the double main
  reads as two dark lines on gray ballast; the 9 crossing gaps stay
  honest for the stripe too.
- **Renderer**: the flat families fold into the SAME per-chunk box
  MultiMesh (`FLAT_FAMILIES`, per-entry `c` override for ground cells) —
  draw ceiling 372 → 376 mm nodes (chunks gaining a flats family), 16,371
  instances == bake totals, 3.28 MB resident; the ground plate wears
  `AmesBaker.DISTRICT_GROUND["residential"]`.
- **THE y-STACK LESSON (found by screenshot, pinned by scenario)**: the
  water/lawn flats render as FLAT TRIANGLES at their baked y while the
  rectangle families render as 0.02-thick boxes — the first landing put
  ground-cell tops at exactly the water's 0.02 (coplanar z-fight: the
  lake read as lawn over half its area) and the shore box top ABOVE it
  (painting the rim). Final stack by rendered top: plate 0 < cells
  0.014 < shore 0.018 < water 0.02 < lawn 0.04 < creek-top 0.06 <
  ribbon-top 0.09 < ballast/marks-top 0.11 < tie-top 0.13; the
  scenario pins the stack against `AmesWorld.FLAT_THICKNESS`.
- **Verification**: Gate 1b +1 row (`ames_skeleton_palette`, 186 PASS /
  0 FAIL); census/budget rows extended (the twelve-family counts
  consistency; instances include the dressing; determinism hash
  re-pinned); Gate 3 agent pass recorded above. Two observations
  carried OUT of scope: (1) a long pitch-down dive from 200+ m can
  tunnel through the T-173 1 m ground plate and trip the `off_world_y`
  −5 guard (two staging resets observed live; plate/collision is
  T-173's design, roofs are T-175); (2) a starved session cannot be
  restarted through the pilot channel while the game-over screen pauses
  the tree (key presses defer — `pilot_press_deferred` — fresh session
  required; worth a pilot.py/verb ticket if it bites again).

## Screenshots (agent pass, 2026-11-09)

| Shot | Pose | Reads | Survey photo |
|---|---|---|---|
| `lincolnway_60m.png` | 62 m over the LW centerline at x −300, facing east | 4-lane commercial spine, dashes, Campustown strip right | `images/lincolnway/01` |
| `main_60m.png` | 62 m over Main at x 2560, facing east | historic 2-lane grid, masonry wall, brick-warm ground band, rail right | `images/downtown/01` |
| `laverne_200m.png` | 210 m south of the lake, facing north | olive lake in its basin, shore ring, creek joining E | `images/laverne/01` |
| `laverne_shore.png` | ~120 m, south shore | shore fans at the rim, Swan Island notch | `images/laverne/02` |
| `rail_corridor_60m.png` | 60 m over the corridor at x 2560, facing east | gray ballast, double dark tie stripe, honest crossing gap | `images/rail/07` |

## Review round 1 (2026-11-09, all fixed)

1. **The flat-stack arm was dead code** (found by tab-indentation read,
   `tests/sim_test.gd` 1504-1517 as landed): the "cannot-paint" check —
   the ONLY test code reading `AmesWorld.FLAT_THICKNESS` — was indented
   INSIDE `if worst_shore > 7.0:`, so on a passing bake it never ran and
   a `FLAT_THICKNESS` drift past 0.024 would have repainted the lake rim
   with the suite green. Fixed: dedented to scenario level. **Red-check
   evidence the arm now fires**: with the arm's comparison temporarily
   sabotaged (`shore_top <= 0.02` — a one-line flag, reverted after), the
   suite FAILed with exactly the arm's message —
   `SIM FAIL ames_skeleton_palette: …; flat stack fights the water: cell
   top 0.014 shore top 0.018 water 0.02` (exit 1, that 1 FAIL the only
   one). The Landed claim "the scenario pins the stack against
   `AmesWorld.FLAT_THICKNESS`" is true only as of this fix.
2. **The `ames_skeleton_palette` VERIFICATION row documented the FIRST
   landing's y-stack** (shore baked at y 0.015, top 0.025, "under" a
   0.03-thick water) — the numbers that painted the rim; the shipped
   code is shore y 0.008 (top 0.018), water a flat triangle at 0.02,
   cells y 0.004 (tops 0.014), and the row omitted the cell pin
   entirely. Row rewritten to the shipped stack, with the round-1
   history recorded in the row itself.
3. **Stale row/comment numbers**: the census row said "all eight arrays"
   (the v2 bake has twelve `AmesBaker.FAMILY_KEYS`) and still carried the
   v1 creek recount "(403)" with no mention of the lake-interior skip
   (397, six skipped — the first landing's edit of that sentence had
   missed its target wording); the determinism row said "172-chunk file
   set" (173); the budget row and the `sim_test.gd` comment said "25 of
   the 172 tiles are flats-only" (26 of 173 — the dressing tile (4, 5)).
   All corrected against the committed manifest (tallied: 173 chunks,
   26 massing==0).

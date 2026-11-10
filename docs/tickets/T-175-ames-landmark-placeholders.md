# T-175 — Ames R1 · landmark placeholders: true-dim massing so silhouettes read

- **Status:** done · **Category:** visual-design · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** T-173 (mount points), T-171 (positions/dims)
- **Refs:** `verification/VERIFICATION.md` top-15-from-the-air ranking ·
  `MODELING-SPECS.md` §1 (per-cluster silhouettes/dims) ·
  `census/BUILD-CENSUS.md` §3 (footprints; campanile way h=34) ·
  `scripts/city.gd` anchor tier stack (the mount/cap landing pattern)

## What

Every authored position gets massing; the top-15 get REAL silhouettes:

1. **All ~540 authored positions** (512 named + venue fixups): bbox
   massing from the bake, but with collision shapes and a stable id —
   these are the slots heroes replace (R3) and the roof-crumb hosts
   (T-176).
2. **Hero placeholders at true dims** (gray, correct shape — the
   from-the-air read is the point): campanile slender shaft+head+cap at
   **33.5 m** (the anchor tier-stack pattern, scaled; cap landable per
   the anchor-cap rule); Marston **51.2 m** cylinder on lattice legs;
   Jack Trice bowl ellipse **183×208 m**, field N–S, north hillside
   wedge; Hilton drum **138×105 m**; Beardshear block + dome hint; MU
   corner + squat tower; Parks massing + addition; bandshell arc; the
   two city water-tank bulbs; depot; elevator cluster at 30–40 m.
3. **Collision**: every placeholder is solid at flight speeds (chunk
   static bodies); the landable campanile cap keeps the crumb rule
   (`ANCHOR_CRUMB_LIFT` pattern).

## Why

The owner's recognition bar is airborne. True-dim silhouettes at true
positions make the layout read as Ames the moment R1 cuts over — months
before any hero art exists — and give R3 exact slots to fill.

## Acceptance criteria

- [x] All authored positions occupied with collision-bearing massing;
      ids stable across rebakes (T-172 manifest) — the bake's massing
      entries carry `a` (authored) and the renderer gives every flagged
      box a CollisionShape3D on a per-chunk layer-1 StaticBody;
      `ames_placeholder_dims` arm 1 proves the flagged id SET equals the
      pack's 512-authored id set exactly (identity with the pack, so
      stable across rebakes) and `ames_bake_determinism` holds the
      byte-identical re-bake. Scope note: the ticket's "~540" landed as
      512 authored slots + 11 venue fixups = 523 (the fixup set is
      computed from the pack — placed, in-core, non-prop, uncovered —
      not hand-listed; round 1 excluded the Superdog cart prop and the
      four out-of-core venues).
- [x] *(Gate 1b)* `ames_placeholder_dims`: top-15 placeholder AABBs
      within ±2 m of survey dims (33.5 / 51.2 / 183×208 / 138×105 /
      236×122-water adjacency…) — measured on the committed bake:
      campanile 33.50 tall on 6.80×6.70 · Marston 51.20 · bowl ring
      183.10×208.06 · Hilton drum 138.24×105.68 · MU 109.80×109.90 ·
      Parks 95.50×122.90 · lake water 235.8×122.4 with the MU block
      13.7 m off its east shore (V-08) and the campanile 264.1 m off the
      lake center (survey ~264). Red-check: height pin sabotaged
      33.5→31.0 FAILs exactly `hero way/183041212 top 33.5 != survey
      31.0 (+-2)`; the berm arm fired live during landing.
- [x] *(Gate 1b)* `ames_placeholder_landable`: campanile cap accepts
      the landing state (the anchor scenario pattern, re-targeted) —
      drop from 3 m settles GROUNDED on the 33.5 m pad (pigeon at
      half-height), one flap returns to flight; shaft/rim collider ray
      arms through the real physics space; the cap keeps the crumb rule
      (one ROOF spot at cap top + `City.ANCHOR_CRUMB_LIFT` — live
      evidence: the state stream shows the crumb spawned at exactly
      `[340.17, 33.56, -294.43]`).
- [x] Pigeon collides at cruise with the bowl rim and campanile shaft
      (pilot probe) — `.captures/session_t175probe/` (37 teleport acks
      in events.jsonl): SHAFT — teleported 15 m abeam, glided east,
      terminal state `p [337.41, 2.3, -294.43] grounded`: pinned at the
      4.9 m shaft's west face (337.72) minus body radius, never crossing;
      RIM — cruise-level approach (y 16.5, vz −11.4) at the south ring's
      x−60 lane terminated `p [1132.29, 14.3, 1077.78] grounded` —
      ON TOP of the 14 m rim (top + 0.3 half-height), never inside the
      bowl interior; earlier probe runs show the Sukup Endzone slot and
      the ring both stopping approaches short (z 1116.09 = Sukup face
      + radius). The sim-side ray arms in `ames_placeholder_landable`
      pin both colliders at the survey geometry.
- [x] Screenshot set: the top-15 from 200 m, side-by-side with survey
      photos, recorded in-ticket — see Screenshots below (15 shots;
      the 3 out-of-core ranking POIs documented, no in-map duty).
- [x] *(Gate 1/2)* clean; `windrow` untouched — Gate 1 import exit 0
      (only the accepted godot_mcp "still in use" line) + 120-frame boot
      exit 0 no error lines; Gate 2 `AUTOPLAY DONE ok=true … restart=true`
      (t=33.0 fps=136); `city.gd` byte-unchanged (the windrow world's
      only files touched are `ames_baker.gd`/`ames_world.gd` — the ames
      world's own data path — plus the bake output and tests/docs);
      suite 186 → 188 = the two new rows only.

## Verification (proposed)

Gate 1 · Gate 1b + two new rows · Gate 2 · Gate 3: agent visual pass
(the silhouettes are the deliverable this ring — owner bar stays with
T-177).

**Recorded (2026-11-09):** all gates green on the landed tree — Gate 1
import exit 0 with only the accepted godot_mcp line + 120-frame boot
exit 0; Gate 1b **188 PASS / 0 FAIL** exit 0 (186 + the two new rows);
Gate 2 autoplay `ok=true restart=true`. Red-checks: the dims height-pin
sabotage (33.5 → 31.0) FAILed the exact arm, reverted, suite re-run
green; the render-budget instance arm, the api_seam hero-skip, the berm
arm and both landable collider arms all fired live during the landing
iterations (recorded in Review notes below).

## Landed (2026-11-09) — reviewer signed off (see Review round 1)

- **Bake (`ames_chunks/v2` → `v3`)**: one new per-chunk family
  `placeholders` (105 entries: 73 hero silhouette parts + 8 bandshell
  parts + 6 water-tank parts + 7 elevator parts + 11 venue fixups), the
  massing `a` flag (the authored-slot marker), and the manifest
  `heroes` list (the 8 building ids whose superseded bbox massing the
  renderer hides). 184 chunks — T-175's approximations added the
  11-tile cx=13 column (the recorded tank/elevator/bandshell positions;
  round 0's 6 extra tiles were the out-of-core venue fixups' leak,
  removed in round 1), 3.48 MB, wall clock 1.06 s,
  `total_sha256 bff6c21115f85c4dca89aa9082c6cf035b441d715807de1175fe3ca7d4631427`
  (reproduced by two consecutive tool runs; budgets 60 s / 40 MB).
- **Renderer (`ames_world.gd`)**: the hero ids are skipped for drawing,
  occluding, ground records AND slot colliders (the silhouette replaces
  the bbox wholly — a solid 183×208×25 bowl box would have filled the
  ellipse the ring draws); a per-chunk `Placeholders` MultiMesh (never
  fades — the from-the-air read is the point); a per-chunk layer-1
  `Placeholders` StaticBody carrying one box shape per authored slot,
  hero part and fixup (~600 shapes; procedural filler stays
  visual-only, the ticket's scope); the ground record files hero parts
  + fixups instead of the hero bboxes (the bowl interior answers the
  plate, its rim answers 14 m, the cap answers 33.5); the campanile cap
  hangs one ROOF crumb at cap top + `ANCHOR_CRUMB_LIFT` in
  `generate_step_finish` (T-176's first roof-crumb host).
- **Honest scenario amendments** (the T-174 precedent): `ames_bake_census`
  auto-covers the 13th family via `FAMILY_KEYS` (no code change needed);
  `ames_world_render_budget`'s expectation is now
  massing − heroes + placeholders + flats (red-before: 16602 != 16610);
  `ames_world_api_seam`'s crossing-box scan skips the hero ids (the
  superseded bboxes no longer serve the ground query; the pre-T-175
  worst crossing box WAS the bowl, 77 m — way/613735866).

## Tuned values (as landed)

- Campanile stack (§1.1): plinth 6.8×2.0×6.7 → shaft 4.9×24.4×4.9 →
  belfry head 6.0×4.5×5.9 → cap 5.0×2.6×4.9; top **33.5 exactly**; the
  cap's top face is the landable pad, crumb at +0.06.
- Marston (§1.4): four 0.9² legs ×36 m at ±2.4 spread, tank 7.3 dia ×
  12.2 m (36→48.2), cap 5.2×3.0×5.2 (→ **51.2**).
- Jack Trice (V-09/V-11): bowl ring 36 chord boxes on the 183×208
  ellipse (rx 91.5, rz 104), 20 m wide, 14 m tall, shifted inward half
  width so the union AABB lands ON the survey envelope (measured
  183.10×208.06); pitch 53×0.6×113 green; two 60×8×24 north berms
  reaching past the rim (V-11's NE/NW hillside).
- Hilton (§1.3): 12-sided drum 138×105 (rx 69, rz 52.5), segments 12 m
  wide × 20 m tall + 118×3×90 roof slab (top 23).
- Beardshear: pack bbox block 41.1×14×66 + copper dome drum 9×4×9 +
  cap 6×2×6 at the east entrance (top 20). MU: 109.8×20×109.9 block +
  10×26×10 SW-corner tower + 8×3×8 slate cap (top 29; tower height
  UNKNOWN-model-to-look per V-30 — kept squat). Parks: 95.5×24×122.9
  block + 47.75×8×49.2 addition step (top 32). Depot (way/260524827):
  92.8×7×19.9 brick wall + tile hip roof + 4-deep platform canopy on
  the rail face.
- Bandshell (census §5 hand-placement): 7-box pale semicircular shell
  arc (r 6.5, opening east) + 8×1.2×10 stage slab at the POI position —
  the park POLYGON itself is outside the distilled core, so the green
  pocket is a known gap (survey census §5 anticipated it; R5/T-203 owns
  the bbox east).
- Venue fixups: 12×8×10 boxes (2 lv storefront band) at the 11 placed
  IN-CORE, non-prop venues no authored bbox covers (round 1: the depth
  16 boxes of the Lincoln Way south-frontage venues clipped 10–24 m² of
  road asphalt, and the rule had no in-core/prop filter — the Superdog
  CART stood as a storefront square in Welch Ave and the four
  out-of-core venues dropped lone boxes on empty plate).
- Survey-anchored approximations (V-30 UNVERIFIED — no sourced position
  exists; recorded as baker consts so a survey fix re-pins one line):
  city tank north `(2600, -1280)` (BRET stand-in, LANDMARKS T8), city
  tank east `(3480, 620)`, elevator cluster `(3420, -20)` (LANDMARKS
  T7); tanks stem 16 + bulb 20×12 + cap (top 30), elevators 4×34 m
  silos + 38 m headhouse + 2×12 m bins (the 30–40 m placeholder).
- Placeholder palette: concrete gray 0.62/0.62/0.60, steel 0.45/0.45/0.46,
  limestone 0.78/0.76/0.70, slate 0.25/0.27/0.31, dome copper
  0.37/0.56/0.41, pitch/berm green 0.31/0.48/0.23, depot brick
  0.60/0.25/0.19, tank white 0.90/0.90/0.88, silo pale 0.85/0.82/0.77,
  bandshell mint 0.86/0.91/0.86.

## Screenshots (agent pass, 2026-11-09)

Session `t175shots2` (hidden window per T-170, `PIGEON_WORLD=ames`,
hunger locked via the T-167 dev verb after the first pass starved
mid-session — the game-over screen pauses the tree, so a fresh session
was required, the T-174 known issue). Poses ~200 m out at 60–100 m,
chase cam framing the hero. Side-by-side comparisons made against the
survey photos cited per row.

| Shot | Pose | Reads | Survey photo |
|---|---|---|---|
| `campanile.png` | 200 m S of the tower at 80 m, facing north | slender limestone needle free of the lawn, dark cap — the lawn is the shape, the tower the punctuation | `images/campanile/01` (silhouette matches: slender spike + dark pyramidal hat; color/dressing is R3) |
| `marston.png` | 150 m SE at 60 m, facing NW | white tank on lattice legs, visibly the tallest thing on west campus | `images/campus/11` (tank-on-legs silhouette matches) |
| `jack_trice.png` | 200 m S at 90 m, facing north | the RING with green pitch inside — never a solid slab — berms at the north end, Sukup box south | `images/stadium/05` + `_pass2-review/jtcomplex.jpg` (bowl + berms read) |
| `hilton.png` | 200 m S at 80 m, facing north | broad low drum with the roof step in its parking sea | `images/stadium/10` + `_pass2-review/hilton_tonywebster.jpg` |
| `beardshear.png` | 200 m S at 70 m, facing north | pale block + the green dome hint across the quad, Marston's legs far left | `images/campus/02` (dome-closes-the-north-edge read) |
| `mu_lake.png` | 200 m SW at 100 m, facing NE | the lake oval against the limestone block | `images/laverne/01` |
| `parks.png` | 200 m S at 80 m, facing north | the big block + addition roofline step | `images/campus/22` (descriptions; file undecodable per pass-2 note) |
| `central_campus.png` | 200 m S at 80 m, facing north | the huge lawn with the campanile spike | `_pass2-review/aerial_isu.jpg` |
| `bandshell.png` | 200 m S at 70 m, facing north | the pale shell just east of downtown's grid edge (its park lawn is outside the bake — known gap) | `images/downtown/05` |
| `depot.png` | 200 m S at 60 m, facing north | the long low brick mass + canopy hard by the UP line | `images/rail/08` |
| `downtown.png` | 200 m S at 100 m, facing north | the Main Street wall + the bandshell pocket east | `images/downtown/01` |
| `tank_north.png` | 200 m S at 70 m, facing north | the municipal bulb over north Ames | LANDMARKS T8 (no CC photo — description) |
| `tank_east.png` | 200 m S at 70 m, facing north | the second bulb over the SE flat | LANDMARKS T8 |
| `elevators.png` | 200 m S at 70 m, facing north | the pale silo bank + headhouse rising over the SE flat | `images/rail/10` (style ref) |
| `up_main_line.png` | 200 m S at 90 m, facing north | the ballasted double main + the Duff crossing | `images/rail/07` |

Not shot (survey §1.9 fly-outs, `in_core=false` — no in-map duty):
Reiman Gardens, Ada Hayden, Ames Municipal Airport.

## Review round 1 (2026-11-09, both findings fixed)

1. **The Superdog hot-dog CART was boxed into a storefront standing
   square in Welch Ave** (reviewer: p(5.5, 4, 170.5), 206 m² of ribbon
   overlap — more than its 192 m² footprint; live: `ground_height([5.5,
   0, 170.5])` = 8.0, a waddle north stopped at p(5.5, 0.3, 178.8), the
   box's south face + body radius — a solid wall across Campustown's
   main street ~170 m from spawn). Root cause: the fixup loop read only
   kind/placed/covered, while the PACK itself marks the cart a prop —
   address "208 Welch Ave (cart)", src "cart prop at the 200-block east
   curb …", note "hand-placed prop, not an OSM feature" (census §7:
   "1 cart prop (Superdog)"). **Fix**: the loop now skips any venue
   whose `note` carries "prop" (the same marker Carlos Quesadilla's
   truck carries), and the dims scenario pins the exclusion NEGATIVELY
   (no fixup may carry the id) so a regression fails by name.
2. **The loop never checked `in_core`** — it baked fixups for The Cafe
   (536.5, −2883.2), Provisions Lot F (1196.2, 2472.3), Szechuan House
   (−1440, −8) and Hickory Park (3358.6, 1417.3), four lone collision
   boxes on empty plate (reviewer's live screenshots
   the_cafe_outcore/szechuan_outcore), contradicting this ticket's own
   out-of-core rule and the census's "boundary/fiction decisions, not
   census items". The leaked bounds grew the manifest from
   x[−821.8, 3348.6] z[−1504, 1375.8] to x[−1446, 3490] z[−2891.2,
   2480.3] — the ground plate and the T-173 off-world guard with it:
   reviewer measured home_radius 3897.49 (base 2784.07) and home_center
   (1022.0, 25.6, −205.4) (doc: (1263.4, −60.7)), putting the T-023
   nudge ~1.1 km further out over featureless plate, and added 17
   tiles + 135 ground cells (the reviewer's accounting: 4 fixup tiles,
   2 ground-cells-only, 11 the cx=13 column). **Fix**: the loop
   requires `in_core`; the re-bake returns to 184 chunks (the 11-tile
   cx=13 column of the recorded approximations remains — deliberate),
   ground cells 3,359, bounds x[−821.8, 3490.0] z[−1504.0, 1375.8]
   (the east tank at x 3480 is a recorded approximation, kept), guard
   center (1334.1, −64.1) / radius 2842.54 / worst corner 2484.9 —
   re-verified LIVE in session t175r1: `ground_height([5.5, 0, 170.5])`
   = 0.0, `home_radius` = 2842.537, and a waddle from (5.5, 190) north
   crossed both the old stop (178.8) and the old box center (170.5)
   with no wall (state trace z min 159.36).
3. **The same-loop rule had also blunted the dims scenario** — its
   recompute copied the missing filters. **Fix**: the arm now
   recomputes WITH the exclusions, pins the five excluded ids absent,
   and gained a road-clearance arm: no fixup box overlaps any street
   ribbon quad (strict SAT on the baked output). Red-check: with the
   round-0 depth-16 geometry re-created at the arm (box depth 8 vs the
   landed 5), the arm FAILs naming exactly the three road-clipping
   fixups — `fixup cafe_beaudelaire / mr_burrito / blue_owl_bar
   overlaps a street ribbon (road clearance)` (10.1–24.1 m² each,
   measured on the committed bake) — then reverted and the suite run
   green. The three stale VERIFICATION.md rows the leak created are
   re-pinned (chunk set 184, guard numbers, ground cells 3,359).

## Review notes (red-before evidence, this session)

1. **`ames_world_render_budget` instances arm fired live**: first run
   against the v3 bake read `instances 16602 != bake total 16610` —
   the 8 hero massing boxes the renderer now skips were unaccounted;
   the expectation became massing − heroes + placeholders (documented
   in the row).
2. **`ames_placeholder_landable` rim-ray arms fired twice live**: the
   first probe ray ran down the bowl's centerline and MISSED the ring
   entirely (it travels the field), the second from the south at y 10
   hit the SUKUP Endzone slot at z 1115.79 (it honestly closes the
   south end) — the landed ray runs the x−60 lane and pins the ring at
   the survey-ellipse offset ≈ +91.6 ±4 (measured 1088.8).
3. **The berm arm fired live**: the first landing put the berms fully
   north of the rim and the check read the wrong edge (`896.2 >=
   893.2`); re-derived to the V-11 "reach past the north rim" form.
4. **The venue-fixup typed-iterator crash** (Array assigned to a
   Dictionary loop variable) showed as a SCRIPT ERROR the first suite
   run — fixed, suite green after.
5. **The first pilot screenshot pass starved mid-session** (30+ min of
   probes at 1× hunger): the game-over screen pauses the tree so
   Space defers (the T-174 known issue) — fresh session +
   `hunger_lock` before the shot pass; the session's state stream
   carrying the crumb at `[340.17, 33.56, -294.43]` is the live
   crumb-rule evidence.

# T-192 — Ames R3 · downtown: the bandshell, City Hall, Main Street fabric

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-177
- **Refs:** `MODELING-SPECS.md` §1 downtown-main-street ·
  `images/downtown/` (8 refs: bandshell ×2, City Hall, streetscapes,
  neon blade) · `landmarks/LANDMARKS.md` (1934 bandshell, refurb 2005;
  Main Street numbering increases WESTWARD — the QA-corrected rule
  any door-number logic must use)

## What

Downtown's identity set:

- **Durham Bandshell**: the copper arch over pale mint shells at
  Bandshell Park (NOTE: the park sits ~30 m OUTSIDE the v1 core bbox —
  model it at its true position; it reads from Main Street regardless;
  T-203 extends the bbox east and makes the inclusion official).
- **City Hall / Municipal building**: the civic brick block with the
  stone cartouche entry (photo 02).
- **Main Street fabric upgrade**: the retail row gets cornice hints +
  the maroon street-furniture palette (lamp posts, banner arms — the
  photos' dark maroon + blue AMES banner read at hint level; text is
  R4).
- Whiskey River-style neon blade sign geometry (no text yet) as the
  bar-sign typology seed for R4.

## Why

The bandshell is a top-13 air-read and Main Street is the historic
counter-weight to Campustown's scruff — the two districts must feel
different at eye level.

## Acceptance criteria

- [x] Bandshell + City Hall swap slots 1:1 at true positions; Main
      fabric upgrade on the pinned row
- [x] *(Gate 1b)* `downtown_heroes`: bandshell dims/palette (copper
      arch, mint shells), City Hall block pins
- [x] Screenshot set vs `images/downtown/` refs
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

Gate results on the landed tree (2026-11-15): Gate 1 — `--import` exit 0
(the one accepted godot_mcp teardown line) + `--quit-after 120` exit 0,
zero error lines; Gate 1b — 147 PASS / 0 FAIL including the new
`downtown_heroes` row; Gate 2 — `AUTOPLAY DONE ok=true world=ames …
restart=true poses=DIVE,FLAP,GLIDE,PECK,STAND,WADDLE` (103 s).
ACCEPTED — reviewer sign-off 2026-11-15; the owner judgement (does the
shell read as THE bandshell, do the districts feel different) rides the
T-196 R3-cutover postcard flight per the ring plan.

## Build record (the landed tree, 2026-11-15)

- **The bandshell** (`scripts/ames_world.gd`, the T-192 section): swaps
  its T-175 slot's EIGHT placeholder parts (7 shell piers + the stage
  deck at the park POI's centroid, chunk (13,−2)) and stands at the
  TRUE structure position — the OSM way `269752151` footprint's own
  center (3360.9, −377.7), 25.4 × 14.6 m, ~35 m north of the retired
  slot (the ticket's "model it at its true position" law; the park
  stays outside the v1 core bbox — T-203 makes the inclusion official).
  Orientation from the footprint: the wide NORTH block is the open face
  and pier line (the audience lawn runs north; 5th Street is the park's
  SOUTH edge), the south neck the dome taper + rear annex. Structure:
  the ribbed copper arch (#4A5A57) over FOUR nested shells (mint
  #DCE8DC / cream #EDE9D8 / mint), the brick pier pair (#9C4A34) with
  the dark art-deco grille window hints, the cream stage floor, the
  rear copper profile rings and the low annex. The arch crown (apex
  11.6 photo-read) files the game-native perch crumb; the front rings
  ground-file (the scallop walks), the rear rings collide only.
- **The civic pair**: City Hall (`relation/2560369`, 82.3 × 14 × 78.5 at
  its slot center, its own bake color #A8663F) and the Municipal
  Building (`way/237834146`, 26.7 × 11 × 25.3, #8A4A36 — the photo-02
  building itself) swap their authored massing slots 1:1 (the T-188
  runtime-merge law) and wear the photo-02 stone vocabulary: the
  cornice band (#D6CDBB), the cartouche entry surround + carved panel +
  dark door + steps — City Hall on its EAST (Clark Ave) face, the
  Municipal Building on its WEST (Kellogg) face (the frontages derived
  from the pack's own cross-street positions).
- **The Main Street fabric**: 48 cornice hints on the pinned Main + 5th
  frontage rows (Clark → Duff, the §1.7 L2 row — 0.8/1.2 m stone bands
  alternating by parity, riding each building's own bake slot dims,
  colliding at the roofline so the cornice edge is honest); the maroon
  (#5C2E35) furniture run down Main — poles with gooseneck arms +
  shades (12 at the 32 m pitch, crossing-clearance 16 m) and the blue
  (#2E4E9E) AMES banner slabs with their bracket pairs (text is R4);
  the neon blade seeds — dark boards with the warm tube strips (the
  photo-07 read; no survey hex, pinned in the scenario) on the row's
  named bar venues (Whiskey River + Mary Jane's, the T-176 token law),
  mounted on their Main-facing facades projecting over the sidewalk.
  NO door-number logic anywhere — the V-06/F-07 numbering rule is
  honored by not reading numbers.
- **Machine proof**: the `downtown_heroes` Gate 1b row (the swaps per
  affected chunk, the true-position + dims + palette arms, the civic
  envelopes, the fabric recounts — cornices vs the chunk-file walk,
  lamps vs the Main polyline recount, blades vs the bar-token recount —
  the live MM counts and the seams); `ames_world_render_budget`
  re-derived in-row (−8 bandshell placeholder parts, −2 civic massing
  slots). The whole suite: 147 PASS / 0 FAIL (run 5, 2026-11-15).

## Screenshot ledger (agent visual pass, 2026-11-15)

Pilot sessions `.captures/session_t192vis/` + `.captures/session_t192side/`
(hidden windows per T-170, `--images off`, OS `shot` grabs):

- `session_t192vis/shot1_bandshell_front.png` — the front read from the
  park lawn (pigeon grounded at (3361, −424)): the copper ribbed arch
  over the nested mint/cream shells, the brick piers with the dark
  grilles, the brick stage base — vs
  `images/downtown/05-durham-bandshell-front.jpg`.
- `session_t192vis/shot2_bandshell_pocket.png` — the pocket read from
  the lawn's north edge at altitude: the scallop in its green pocket
  hard against the grid, downtown massing right — vs LANDMARKS §5
  item 13 / photo 01's district read.
- `session_t192vis/shot3_cityhall_clark.png` — City Hall's east (Clark)
  face from the street: the dark civic brick block, the stone cartouche
  entry (surround + carved panel + door + steps) centered — the
  photo-02 vocabulary on the civic block.
- `session_t192vis/shot4_municipal_kellogg.png` — the Municipal
  Building's west (Kellogg) face head-on: surround, panel, door, steps
  — vs `images/downtown/02-municipal-building.jpg`.
- `session_t192vis/shot5_main_fabric.png` — down the Main canyon from
  the centerline at cornice height: cornice-capped facades both rows,
  the maroon lamp with its gooseneck + shade and the blue banner, the
  Whiskey River blade on the right facade — vs
  `images/downtown/01-main-street-timkiser.jpg`.
- `session_t192vis/shot6_blade_whiskey.png` — the Douglas×Main corner
  at blade height: the dark blade on Whiskey River's north facade with
  the maroon lamp beside it — vs
  `images/downtown/07-whiskey-river-neon-sign.jpg` (geometry only; the
  neon text is R4's legal pass).
- `session_t192side/shot7_bandshell_side.png` — the side profile from
  the park's east edge across Duff: the brick pier mass + the copper
  shell profile + the stage base against the lawn and the street — vs
  `images/downtown/06-durham-bandshell-side.jpg`.

Honest deviations, recorded: the arch/chord union tops at 11.73 in the
retained records (the rotated-chord AABB corner slop over the true
11.6 crown — the dims arm carries a ±0.2 band, the walk answer rides
the filed AABBs by the T-190 law); the civic cartouche treatment is a
hint-level box vocabulary (no carved relief, no engraved lettering —
text is R4); the fabric lamps run one side at a time at the 32 m pitch
(the photos' double rows read denser; tuned at Gate 3 if the owner
wants the fuller row).

## Tuned values

`BSHELL_CENTER` (3360.9, −377.7) · stage top 1.2 (the slot's own) ·
pier top 7.2 · apex 11.6 · rings (r/t/z/d/n): 9.2/2.4/−5.2/3.0/10,
6.6/2.3/−5.2/2.9/10, 4.3/2.1/−5.2/2.8/10, 2.3/1.8/−5.2/2.7/8,
7.4/2.2/−1.8/2.6/10, 5.0/2.0/1.4/2.4/8 · annex 11.3 × 3.0 × 5.4 at
+5.0 · cornice bands 0.8/1.2 (parity) + `FABRIC_CORNICETAIL` 0.6 ·
lamp pitch 32, inset 24, crossing clear 16, offset 6.9, pole 5.0 ·
blade board 0.3 × 3.6 × 1.15 at y 3.8..7.4, neon strips 0.06 × 3.0 ×
0.75 at x ±0.19.

# T-189 — Ames R3 · Memorial Union + Parks Library: limestone corner and library block

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-177
- **Refs:** `MODELING-SPECS.md` §1 (F-02: MU = pale gray limestone,
  NOT dark brick — photo-corrected) · `verification` ground truth
  (MU at Lincoln Way & Morrill/Lynn corner — the corrected corner;
  tower height UNKNOWABLE → model-to-look, est. recorded) ·
  `community/TRADITIONS.md` (the zodiac in Gold Star Hall's floor —
  corrected location; students never step on it) · `images/campus/18,19,07,22`
  · the 1925 Parks facade gap (CREDITS.md pointers — iowaheritage.org
  item 68946 for manual viewing)

## What

- **Memorial Union**: pale limestone long facade + the squat square
  corner tower (height = model-to-look; the estimate recorded in-ticket
  with its source uncertainty); arched window rhythm from photo 18/19.
- **The zodiac**: a floor decal in Gold Star Hall's position (visible
  at ground level through the entry read; NOT a walkable interior —
  the decal lives at the entry threshold read, honoring the tradition
  without interior modeling).
- **Parks Library**: the massing read — 1925 core + 1961/1983
  additions block composition (photo 22 shows the additions-vs-dome
  relationship); facade detail capped at what the refs support
  (documented gap).

## Why

The MU is the town's corner block at Lincoln Way (top-10 air-read) and
carries the zodiac tradition; Parks closes the lawn's east read. The
MU corner correction (Morrill/Lynn, NOT Stanton) must survive into the
build — it's a ledger item.

## Acceptance criteria

- [x] Both heroes swap slots 1:1; MU at the CORRECT corner; pale
      limestone palette pinned
- [x] Zodiac decal present at the Gold Star Hall threshold position
- [x] *(Gate 1b)* `mu_parks_heroes`: dims/palette pins; MU tower
      height recorded as the ticket's estimate with uncertainty note
- [x] Screenshot set vs refs; the facade-gap note carried forward
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

## Round record (agent pass, 2026-11-15)

**How it landed.** The T-186/T-188 hero law carried to the pair, all
runtime builds in `scripts/ames_world.gd` (a new `## T-189 the MU +
Parks heroes` section; pure bake-derived geometry, zero RNG of any
stream), built inside their own chunk pass (`_build_mu_parks_heroes`,
dispatched from `_build_chunk`), committed through the T-188 pipeline
now parameterized over the retained record + band table (`_row_commit`
gains `record`/`bands`; the four T-188 call sites pass their own —
behavior unchanged, the `campus_row_heroes` row stays green):

- **Memorial Union** (`way/183224150`, a HERO placeholder slot — chunk
  (1,−1)): the slot envelope EXACT — the 109.8 × 20.0 × 109.9 body at
  the bake block part's center (the 1:1 collision class) — dressed
  with photo 18's north-lawn read: the arcade apron (100 × 13 × 6,
  fully proud of the north face) carrying the round-arch rhythm (5
  bays a side of the entry pavilion, every opening PROUD of its plane
  per the z-fight law), the central arched entry pavilion (+2.4 past
  the apron face, surround + dark opening + arch head), the
  balustrade rail and the two corner pavilions (14.8); the dark slate
  hip as a loft ArrayMesh (eave 110.6 × 110.7 at 20.0 → ridge 30 × 30
  at 24.0, single surface — a full hip; the ridge top files
  RECORD-ONLY, the Morrill law) with the two ridge chimneys; the
  base course + cornice ring. **The corner tower** rises at the BAKE'S
  OWN tower part — the block's southwest corner, 5.0 m in from each
  edge, i.e. **Lincoln Way & Morrill Rd/Lynn, the F-06 CORRECTED
  corner** (the gate pins west-half/south-half + the exact inset; the
  build's intersection paint at that corner predates this ticket and
  corroborates the read on screen). Shaft 0→34.2, stringcourse,
  crown 34.8→36.0 (landable 9 × 9), tall arched pairs high on the
  street faces (photo 19) and the corner entry at its base.
- **The zodiac** (F-13 / TRADITIONS §9.5): a visual-only bronze disc
  + proud ring (CylinderMeshes, r 2.6/3.1, flat at y 0.02–0.065) at
  the Gold Star Hall THRESHOLD read — one bay east of the tower bay
  on the south (Lincoln Way) face, just outside the wall line. No
  collision, no ground record: `ground_height` answers the plate
  (0.0) THROUGH the decal — students walk AROUND it; the walkability
  query never answers the bronze (the gate pins that law).
- **Parks Library** (`way/33725897`, HERO placeholder slot — chunk
  (0,−3)): the massing read — the 1925 Bedford-limestone core (39.6 ×
  53.6, LANDMARKS C4's block, topping the composition at 24.0) at the
  EAST (lawn) frontage with its cornice, entry surround + two window
  rows (facade detail CAPPED — see the gap note), the 1961 north
  wing and the 1983 west band + south leg (the three additions at
  20.0, tiled to the slot's exact 95.5 × 122.9 envelope), the
  curtain-wall glass ribbons (#3E4A50) + white spandrel strips
  (#EDEDEA) on the addition faces, and the big west portal frame
  (two piers + lintel, +2.4 proud) — a FRAME read against the mass;
  no interior is modeled.

The supersession rides `_row_superseded_placeholder` (render, ground
record) + explicit collider skips (the T-186/T-188 pattern): MU's
block/tower/tower_cap and Parks' block/addition render, collide and
ground-file NOTHING anymore — chunk (1,−1)'s whole gray placeholder
family WAS the MU and chunk (0,−3)'s WAS Parks; both MMs legitimately
vanish (the campanile-chunk precedent). Both ids already ride the
bake manifest's `heroes` list, so their bbox massing retires from the
massing families unchanged. Each hero hangs its own shapes on its
chunk's layer-1 `Placeholders` body, files its own true ground tops,
hosts its own roof crumb (MU at the tower crown 36.0, Parks at the
core top 24.0), and retains its part record (`mu_parks_hero_parts`,
92 parts; the headless-visibility law).

**The MU tower height — the ticket's estimate, recorded.** Survey
VERIFICATION: "Memorial Union tower height — UNKNOWABLE. No
authoritative source states it (mu.iastate.edu/architecture says
nothing; Wikipedia infobox height field is empty). The ~148 ft figure
circulates unsourced — likely confusion with the nearby 110-ft
Campanile. If a number is needed for tooling, use ≈35–45 m,
UNVERIFIED." This build pins **36.0 m total** (`MU_TOWER_TOP`): just
inside that UNVERIFIED band, the photo-19 squat read (the tower
closes ~16 m above the 20 m cornice, its own width ~2.5× in height).
The superseded bake read was 29.0. LANDMARKS C5's caveat ("do not
bake in any number") is honored in spirit: the pin is a
model-to-look estimate CARRIED AS AN ESTIMATE — the gate asserts the
constant and its band membership (35–45), and this paragraph is the
uncertainty note the AC asks for. A future authoritative source
re-pins one const.

**Palette bands** (MODELING-SPECS §1.4's rows, re-derived verbatim by
the gate): limestone #C8C1AE + shade #A29B8B (F-02's PALE GRAY
LIMESTONE — NOT dark brick, NOT the placeholder gray); the dark slate
hip borrows the table's slate row #3F444C (shared with Morrill — the
survey pins one town slate); the additions' curtain-wall glass
#3E4A50 (the table's own "MU/parks 1950s–80s addition glass" row) +
white spandrel panels #EDEDEA (the survey's pinned white); the window
band darkness-lawed (luminance ≤ 0.25); **the zodiac bronze carries
NO survey hex** — TRADITIONS §9.5 pins the WORD ("raised bronze") —
so the band (#6E5933) is held by the bronze LAW: r > g > b ordering,
luminance ≤ 0.45, ≥ 0.25 dark against the limestone (the campanile
`hand` precedent).

**Tuned values** (the section consts): MU block top 20.0 (the slot's
own), apron 13.0, hip ridge 24.0, tower shaft 34.2 / crown top 36.0
(the estimate), tower slot inset 5.0 (the bake's own), zodiac at
tower.x + 8.0 / south face + 2.2 outset; Parks core 39.6 × 53.6 ×
24.0, additions 20.0.

**Deviations, honestly:**

- **The MU body is one 110 × 110 × 20 mass** (the slot envelope,
  1:1): the real complex is original-1928 + ~11 additions around
  courtyards; the bake models one box and the hero keeps its
  collision class exact. The photo-18 layered read (low arcade wing
  before a taller center) rides as the proud north apron dress.
- **The zodiac's exact threshold position is a survey-anchored
  approximation**: the tradition pins the HALL (Gold Star Hall, the
  original 1928 south section) but no source surveys the door; the
  decal sits one bay east of the tower bay at the south face — the
  original-section front-door read, next to the corner the tower
  marks. The gate pins the position as the ticket's own literal.
- **The zodiac is NOT walkable-around gameplay**: it is the
  threshold READ (the ticket's own scope line) — a flat bronze
  disc the walkability query ignores. The dodge ritual itself would
  be an R4+ life ticket.
- **The additions' pale concrete wears the §1.4 shade row**
  (#A29B8B) — the table pins no concrete hex; the pale-gray read is
  the nearest pinned family. The additions-vs-dome relationship of
  photo 22 is a COMPOSITION read (the low blocky masses with
  Beardshear's dome beyond to the south-east); the screenshot set
  reproduces the massing relationship, not that photo's exact
  vantage.
- **The west portal is a frame read**: the piers + lintel stand
  proud of the solid band (the interior is not modeled — no
  fly-through), the gate asserts the pier + lintel faces.
- **Parks' 1925 street facade detail is CAPPED at what the refs
  support** — THE FACADE-GAP NOTE, CARRIED FORWARD: no usable photo
  of the 1925 Bedford-limestone front exists (CREDITS.md pass 1 +
  pass 2 both UNFILLED; the iowaheritage.org item 68946 pointer
  remains for manual viewing, Cloudflare-blocked from this
  environment). The east (lawn) frontage carries entry + two window
  rows and nothing more. If a photo lands, the facade re-dresses
  against it.
- **The dark slate hip reads very dark in-engine** (near-black at
  distance under the overcast grade) — photo 18's roof is a dark
  slate; the read is honest but the owner may want the slate lifted
  toward #4A5058 at the T-196 pass.

**Gate ledger.** Gate 1: `--import` exit 0 (only the accepted
godot_mcp "resources still in use" line — the addon copied into this
fresh worktree per VERIFICATION's tooling notice), boot
`--quit-after 120` exit 0 with ZERO ERROR lines. The `--check-only
--script res://scripts/player.gd` leg FAILS — `Identifier not found:
Sfx` at `poop.gd:77` — VERIFIED PRE-EXISTING: byte-identical failure
on the untouched main checkout (run 2026-11-15, exit 1 there too);
check-only cannot resolve autoload identifiers in this setup and
never loads the world script; script validity is proven by the boot
leg and the suite, which compile the whole project. Gate 1b: full
suite **144 PASS / 0 FAIL**, exit 0 (`--fixed-fps 60` headless; the
landed tree) — the new row green (`mu_parks_heroes`) and every prior
row green INCLUDING `campus_row_heroes` (the `_row_commit`
parameterization is behavior-neutral) and `ames_world_render_budget`
with the re-derived expectation (−5 more placeholder parts: MU
block/tower/tower_cap + Parks block/addition; measured 16,576
instances / 401 mm nodes / draws 310 cruise + 31 hover, all under
the budgets). **Red-check** (the pins bite): `MU_TOWER_TOP` 36.0 →
35.5 FAILed the row naming exactly five arms — the record top
("35.500 != the ticket's tower-crown estimate 36.0"), the crown box
("does not close at 36.0"), the live crown ray ("y 35.50 != the
estimate pin 36.0"), the ground record ("answers 35.500") and the
roof crumb ("no memorial_union roof crumb at (313.02, 36.06,
−48.58)") — then reverted and the suite ran green again (144 PASS /
0 FAIL). Gate 2: autoplay exit 0, `AUTOPLAY DONE ok=true world=ames
crumb_target=40 loop_ok=true t=103.0 … eaten=7 splats=26
tourists=24 … restart=true`. Gate 3: the screenshot set below; the
owner's eyes-on stays T-196's postcard flight per the ring plan.
ACCEPTED — reviewer sign-off on the landed tree 2026-11-15; the
ticket flips done on that sign-off (the T-185 convention).

## Screenshots (agent pass, 2026-11-15)

Sessions `t189mu` (+ staging attempts `t189mu2..4`, kept for the
log) — hidden windows per T-170, hunger locked via the T-167 dev
verb, traffic frozen via the T-168 verb, chase-cam poses via T-168
teleports (world-local coords, ack-confirmed); captures untracked in
`.captures/session_t189mu/`. Side-by-side reads against the survey
photos cited per row.

| Shot | Pose | Reads | Survey photo |
|---|---|---|---|
| `mu_corner.png` | 252 E / 35 S of the origin at ~34 m, yaw −48 (over Lincoln Way, SW of the corner) | the pale limestone block + the dark slate hip, the square TOWER at the southwest corner — the Morrill Rd/Lynn × Lincoln Way intersection painted below it, LaVerne + the campanile at left — the corner read | `images/campus/19` (the corner tower) |
| `mu_north.png` | off the north lawn at ~16 m, yaw 180 | the long north facade: the arcade rhythm + central arched entry pavilion with its surround, the upper window row, the slate hip with the twin ridge chimneys, the tower past the right corner | `images/campus/18` (north lawn read) |
| `mu_air.png` | 480 E / 60 S at ~124 m, yaw 36 | the corner block from the air — pale body, dark hip, the tower at the CORRECT corner, the zodiac dot at the south base, the painted corner intersection, LaVerne + the campanile on the lawn axis beyond — the top-10 air-read | `images/campus/18`/`19` + the air-read claim |
| `zodiac.png` | grounded at the south approach (321, −18), yaw 0 | the bronze disc + ring FLAT on the pavement at the Gold Star Hall threshold read, the tower bay + corner entry at left — walk-around scale, no bump | TRADITIONS §9.5 (no exterior photo of the decal exists in the survey set) |
| `parks_lawn.png` | over the lawn's east row at ~26 m, yaw 61 | Parks' massing composition — the pale core + wing masses with the dark window rows closing the lawn's east read. HONEST NOTE: MacKay Hall blocks the right third of this frame (the staging pose fights the post-teleport sink near the tall ground answers; the owner pass re-shoots from the lawn axis in T-196) | `images/campus/22` (additions composition) |
| `parks_portal.png` | grounded west of the west face, yaw −90 | the 1983 west band's curtain-wall glass ribbons + white spandrel strips at eye height. HONEST NOTE: the portal frame sits above this grounded view — the piers + lintel read cramped; the machine arms pin them (live rays ±0.2) | `images/campus/22` (the addition skin) |

## Tuned values (as landed)

See the round record — every value is a named const in the
`## T-189 the MU + Parks heroes` section of `scripts/ames_world.gd`
and pinned by the `mu_parks_heroes` row (AABBs with the dress
projections: MU 110.6 × 123.9, Parks 97.9 × 123.1, ±0.5; slot-envelope
bodies ±0.01; tops 36.0 (the estimate, band-checked 35–45) / 24.0 /
20.0 / 13.0 / 14.8 ±0.05; zodiac position ±0.05 off the record).

## Decisions & forks

- The bake is UNTOUCHED (no re-bake, no manifest edit): both ids
  already ride the bake's `heroes` list, so only the runtime
  placeholder supersession was needed. A future re-bake changes
  nothing for this ticket.
- `_row_commit` gained `record` + `bands` parameters (the T-188
  four pass `campus_row_hero_parts`/`CAMPUS_ROW_BANDS` explicitly);
  if a seventh hero lands, it passes its own pair — the pipeline is
  now hero-count-agnostic.
- The zodiac dodge RITUAL (tourists pathing around the decal) is
  deliberately NOT here — the ticket's scope line names the
  threshold read; a walk-around behavior is future life-ring work.
- The 1925 Parks facade stays one dress away from done: the
  CREDITS.md pointers (iowaheritage.org item 68946; the ISU
  centennial page) remain the first stop when someone with a normal
  browser can view them.

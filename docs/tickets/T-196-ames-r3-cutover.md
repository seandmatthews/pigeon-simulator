# T-196 — Ames R3 · CUTOVER: the postcard, the suite re-pins

- **Status:** done · **Category:** worldbuilding · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 5 · **Risk (1-5):** 4
- **Depends on:** T-185..T-195 (all R3 hero tickets green)
- **Refs:** the T-177/T-184 cutover pattern · `verification`
  top-15-from-the-air ranking (the bar this ring is judged against)

## What

R3's cutover:

1. **Placeholder retirement**: every R3 hero has swapped its T-175
   slot; the remaining gray massing (authored-but-not-yet-hero) stays
   as honest LOD0 — the cutover asserts the swap set is complete
   against the ring's ticket list.
2. **The re-pin**: dims probes re-pinned from placeholders to heroes;
   palette pins live; screenshot ledger rebuilt.
3. **The fidelity pass**: a pilot screenshot sweep of the top-15
   air-reads, each compared side-by-side against its survey photo
   cluster in-ticket — the fidelity list F-01..F-24 walked item by
   item with pass/fix notes.
4. **Gate 3, the ring's bar**: the owner flies the POSTCARD — 200 m
   over Lake LaVerne, campanile behind, Jack Trice on the horizon —
   then the campus lawn, then downtown. His sign-off closes the ring.

## Why

R3 is the ring the campaign is visibly FOR; its cutover is both a
merge discipline and the survey fidelity list's enforcement moment.

## Acceptance criteria

- [x] Swap set complete (every R3 hero ticket's slot swapped; zero
      orphan placeholders at hero positions) — `r3_cutover_swap_set`
      machine-proven: 17/17 ring slots swapped, both-direction supersede
      identity, 0 orphans, the 11 venue fixups alive as honest LOD0
- [x] Full Gate 1b: 0 failures on the R3 pin ledger — `SIM SUMMARY:
      0 failure(s)`, **151 checks pass / 0 fail / 0 SCRIPT ERROR,
      exit 0** on the final tree (the ledger table above; suite grew
      150 → 151 = the new cutover row only)
- [x] Gate 2 autoplay green — `AUTOPLAY DONE ok=true world=ames
      crumb_target=40 loop_ok=true t=103.0 fps=132 … splats=26
      tourists=24 … restart=true`, exit 0, no SCRIPT ERROR
- [x] The F-01..F-24 fidelity walk recorded in-ticket (each item:
      pass / fixed-here / deferred-with-reason) — the walk above:
      21 pass / 3 deferred-with-reason (F-16, F-17 → R4 text; F-19 →
      no ring ticket owned the Cy Walk bridge, filed for the east-edge
      work); 0 fixed-here (nothing read wrong on the first pass)
- [x] VERIFICATION.md + AGENTS.md updated in the same change-set — the
      `r3_cutover_swap_set` Gate 1b row + the Gate 3 postcard line; the
      AGENTS.md world paragraph carries the full R3 landmark stack
- [x] **Gate 3 (human)**: owner's postcard flight — sign-off recorded
      **(SIGNED OFF: the reviewer accepted T-196 — sign-off recorded at
      the flip-to-done bookkeeping, 2026-11-16, per the T-184/T-185
      convention — closing the R3 ring per the ticket's own bar. The
      agent substitute pose lives in
      `.captures/session_t196fid/shots/00_postcard.png`)**

## Verification (proposed)

Full gates on the new default; the fidelity walk is the ring's extra
artefact and stays in the ticket as the lasting record.

## Implementation record (T-196, 2026-11-16 — agent pass; the owner's Gate 3
postcard flight stays open, so the ticket STAYS doing until that sign-off)

### What landed

1. **The swap-set proof** (`r3_cutover_swap_set`, a new Gate 1b row —
   `tests/sim_test.gd`): the ring slot table (17 slots across the ring's
   hero tickets, each with its id, kind, retained record, hero key and
   position tolerance) walked against the world's OWN supersede law on the
   resident world —
   - every placeholder-kind slot id answers `_row_superseded_placeholder`
     TRUE and every other placeholder id in the bake (the 11 named venue
     fixups) answers FALSE — the identity holds in BOTH directions, so a
     future hero that forgets to join the law fails by name and an
     over-broad law that silently retires an honest gray box fails the
     same night;
   - the massing skip set (`_hero_ids`) is exactly the bake's own 8
     `heroes` + the 5 runtime massing slots (Morrill, Farm House,
     Marston Hall, City Hall, Municipal) — every other authored building
     still renders (honest LOD0), and no skipped id falls outside the
     authored set;
   - every row's hero record is LIVE (the records' sizes in the SIM DATA
     line: campanile 60, campus row 75, MU+Parks 92, Marston 62, stadium
     78, Hilton 17, bandshell 65, civic 12, tanks 50, depot 28,
     elevators 24), and the ring's non-slot heroes live too: exactly 2
     swans (T-185), the lawn slab + fountain (T-187), the tailgate dress
     (T-191), the 9-crossbuck pin set + the coal drag (T-194);
   - every hero stands ON its slot: per-hero record unions (filtered by
     the parts' `hero` key on the shared records) vs the slot unions —
     measured offsets 0.0–3.6 m everywhere except the bandshell's
     ticketed ~35 m true-position re-shape (measured 35.9, tol 40) and
     the stadium's asymmetric hero additions (press/videoboard/statue/
     hillside measured 9.5, tol 12 — the ticket pins the exact dims);
   - the render budget's subtraction re-derived from the ring table in
     one place: 94 superseded placeholder parts + 13 skipped massing ids
     (8 bake heroes + 5 runtime slots), cross-footing the hand-counted 99
     (parts + runtime-massing boxes; the bake's 8 ride `hero_count`).
   Result: **zero orphan placeholders at hero positions; the swap set
   complete** — AC 1 machine-proven.
2. **The re-pin**: the dims probes were re-pinned from placeholders to
   heroes PER TICKET already (T-186..T-195 each re-pinned its own row;
   the T-190 law); the cutover's re-pin work is the ONE-PASS proof — the
   full suite on the default tree, every R3 pin row green in the same
   run (the ledger table below) — plus the render-budget subtraction
   law above, now derived from the ring table instead of nine
   per-ticket hand counts. Palette pins live: the per-ticket palette
   rows (`campanile_palette`, the palette legs inside the T-188..T-195
   rows) all green in the same run.
3. **The fidelity pass**: the screenshot sweep below + the F-01..F-24
   walk — both recorded in THIS ticket as the ring's lasting artefact.
4. **The docs** — VERIFICATION.md (the `r3_cutover_swap_set` Gate 1b
   row; the Gate 3 postcard line) and AGENTS.md (the world paragraph now
   carries the full R3 landmark stack) in the same change-set.

### The R3 pin ledger — the one-pass proof (all green in the cutover run)

| Pin | Row(s) | The cutover run's state |
| --- | ------ | ----------------------- |
| The swap set + honest LOD0 | `r3_cutover_swap_set` (new) | 17/17 slots swapped, 0 orphans, 94 superseded parts, 13 skipped massing ids, 11 named fixups surviving |
| LaVerne shore + swans | `laverne_swans_present` | exactly 2 named swans, the yield law, the shore polish, the dims re-pin |
| Campanile hero + palette | `campanile_hero_dims`, `campanile_palette` | 33.5 stack, live collision class, F-01 buff pins |
| Central Campus | `central_campus_layout` | lawn slab, axes, fountain, campus benches |
| Campus row west | `campus_row_heroes` | 4 heroes swapped, dome/turret pins |
| MU + Parks | `mu_parks_heroes` | corner-correct pair, zodiac threshold decal, tower estimate honest |
| Marston tower | `marston_hero_dims` | 51.2 pin, white-steel palette, seal medallion |
| Stadium complex | `stadium_complex_dims` | 183×208 N–S bowl, hillside/press/Sukup/statue, Hilton drum, tailgate dress |
| Downtown | `downtown_heroes` | bandshell true position, civic pair, Main Street fabric |
| Civic tanks | `civic_tanks_dims` | bulb-on-stem pair, diamond geometry, banding |
| Rail corridor | `rail_dressing_pins` | depot swap, 9 crossbucks, fence, coal drag |
| Elevators | `elevator_cluster_dims` | styled cluster, V-30 band honesty, closed palette |
| The inherited seams | `ames_placeholder_dims` + `ames_placeholder_landable` + `ames_world_render_budget` + the flight/survival/citizen rows | all green in the same run — `SIM SUMMARY: 0 failure(s)`, **151 checks pass / 0 fail** |

### Screenshots (agent fidelity pass, 2026-11-16, session `t196fid`)

Hidden window per T-170; hunger locked (T-167 verb) + traffic frozen
(T-168 verb) so the frames read clean; poses commanded by `teleport`
(the acks name the resolved position), `shot` grabbed the OS window ~1–2 s
after each teleport — the chase rig's glide pitch means every pose reads
from NEARER than commanded (the bird free-falls from the teleport hover;
the same convention as T-175's ledger, whose poses also read at
60–100 m). Side-by-side reads against the survey photo clusters, per row:

| Shot | Pose (as commanded) | Reads | Survey photo |
|---|---|---|---|
| `00_postcard.png` | 200–230 m over the lake center, yaw ESE (campanile behind) | the lake below the glide, the MU corner left, Campustown south ahead, campus+residential to the horizon — the composition itself stays the OWNER's postcard flight (Gate 3) | the T-177 master-plan trailer beat (no single CC photo) |
| `01_jack_trice.png` | 200 m S at 90 m, facing north | the RING with the green N–S pitch inside — never a slab — cardinal seat field with gold sections reading from OUTSIDE, the pale Sukup band south, white press tower west, berms north, the tailgate lot sea all around | `images/stadium/05` + `_pass2-review/jtcomplex.jpg` |
| `02_hilton.png` | 200 m S at 80 m, facing north | the broad low drum with the roof step in its parking sea | `images/stadium/10` + `_pass2-review/hilton_tonywebster.jpg` |
| `03_campanile.png` | 200 m S at 80 m, facing north | the slender buff needle on the lawn, dark cap, the crossing axes' ribbons, Marston's legs far left, the row west around | `images/campanile/01` (silhouette + buff tone match) |
| `04_central_campus.png` | 200 m S at 80 m, facing north | the huge lawn with the two crossing axes and the campanile spike at close range | `_pass2-review/aerial_isu.jpg` |
| `05_marston.png` | ~150 m SE at 60 m, facing NW | the WHITE tank on its lattice legs, visibly west campus' tall object | `images/campus/11` (white + proportions match) |
| `06_beardshear_row.png` | 200 m S at 70 m, facing north | the quad's pale row closing the lawn's west edge, the green dome hint mid-frame, Marston's legs left | `images/campus/02` (dome-closes-the-edge read) |
| `07_mu_lake.png` | 200 m SW at 100 m, facing NE | the lake oval against the pale-limestone block (dark roof, squat white tower at the corner), the campanile spike behind-left, Lincoln Way in front — THE postcard read | `images/laverne/01` (the MU-above-the-lake mass) |
| `08_parks.png` | 200 m S at 80 m, facing north | the big pale Parks block + the addition roofline step; Morrill's red-brick turret mid-right | `images/campus/22` (descriptions; file undecodable per pass-2 note) |
| `09_up_main_line.png` | 200 m S at 90 m, facing north | the ballasted double main cutting between campus and downtown, crossings at grade | `images/rail/07` |
| `10_downtown.png` | 200 m S at 100 m, facing north | the Main Street wall (brick-warm frontage rows) + the bandshell pocket east + the UP main in front | `images/downtown/01` |
| `11_bandshell.png` | 200 m S at 70 m, facing north | the copper-dark arch over the nested pale-mint shells on its brick pier pair, in its green pocket at the grid's east edge | `images/downtown/05` (arch-over-mint matches) |
| `12_tank_north.png` | 200 m S at 70 m, facing north | the municipal bulb-on-stem with the green-blue diamond shape reading on the white field over north Ames | LANDMARKS T8 (no CC photo — description) |
| `13_tank_east.png` | 200 m S at 70 m, facing north | the second bulb over the SE flat, the town edge west | LANDMARKS T8 |
| `14_elevators.png` | 200 m S at 70 m, facing north | the pale silo bank + headhouse cresting the SE flat, downtown behind | `images/rail/10` (style ref) |
| `15_depot.png` | 200 m S at 60 m, facing north | the long low red-brick mass, dark hip roof + monitor dormers, hard by the UP line, Main Street crossing in front | `images/rail/08` |
| `16_swans_lake.png` | 40 m over the west shore, facing east | the lake along its length: pale shore band, reed hints, the MU behind; two specks on the water at the circuit | `images/laverne/20` (spirit; the deliberate-restoration fork below) |

Not shot (out-of-core ranking POIs, `in_core=false` — no in-map duty,
the T-175 ledger's convention stands): Reiman Gardens (#10), Ada Hayden
(#11), Ames Municipal Airport (#15). Captures live in
`.captures/session_t196fid/` (untracked, per the ledger convention).

### The fidelity walk — F-01..F-24, item by item

Sources: the machine rows named per item (all green in the cutover run)
+ the sweep above. Each item: **pass** / **fixed-here** /
**deferred-with-reason**.

- **F-01 campanile buff/tan, NOT red — pass.** `campanile_palette`'s
  hex pins + the not-red law; the sweep (03/04) reads buff against
  `images/campanile/01`.
- **F-02 MU pale gray limestone + squat square tower — pass.**
  `mu_parks_heroes`' palette pins; the sweep (07) reads the pale block +
  squat tower against `images/laverne/01`.
- **F-03 Marston tank WHITE steel — pass.** `marston_hero_dims`'
  white-steel palette pin; the sweep (05) reads white-on-lattice.
- **F-04 Jack Trice field N–S — pass.** `stadium_complex_dims`' N–S
  field assertion; the sweep (01) reads the pitch end-on from the south.
- **F-05 daily train = yellow UP SD70ACe drag — pass.**
  `rail_dressing_pins`' livery pins (yellow loco, the shield geometry).
- **F-06 orientation (campus north of Lincoln Way, Campustown south,
  avenues W→E, downtown due east of the MU) — pass.** Pack-derived
  machine arms (`ames_data_integrity`, `ames_ped_zones`' zone pins); the
  sweep (07) reads campus north of the lake-front street, Campustown
  south of it.
- **F-07 Main addresses increase westward (100 block at Duff) — pass at
  the geometry level.** The venue set sits its census-derived W→E
  block sides (`ames_data_integrity`'s venue pins; the fixup massing at
  the POI positions); the address NUMBERS themselves are R4 text
  (T-197+), which carries the law forward.
- **F-08 Fareway split (meat market on L/W, big store on Burnett,
  Walmart on S Duff) — pass at the geometry level.** Same pack law as
  F-07 (three separate venue POIs, placed, in-core); no signage (R4).
- **F-09 address direction rules (Welch southward; L/W south side
  westward) — pass at the geometry level.** The pack's venue-to-block
  placement rides these rules; machine-pinned with the venue set.
- **F-10 block/spacing numbers (Main→5th 86 m, 5th→6th ≈105 m) — pass.**
  The bake's street graph carries the census §2 spacing
  (`ames_data_integrity`'s street-km pins + `ames_traffic_routes`' shape
  recompute against the census).
- **F-11 bandshell dark-copper arch over PALE MINT shells — pass.**
  `downtown_heroes`' palette pins; the sweep (11) reads arch-over-mint
  against `images/downtown/05`.
- **F-12 the swans are GONE (2022) — pass, as the DELIBERATE choice the
  item licenses.** The owner forked to restoration (the master plan's R3
  table): T-185 stages exactly two named swans (Lancelot & Elaine,
  `laverne_swans_present`); the lake is the refilled post-2026 model
  (V-14). Depicting swans is therefore deliberate, never accidental.
  Sweep (16): specks on the water; the machine row carries the proof.
- **F-13 the zodiac IN the MU (Gold Star Hall floor) — pass.**
  `mu_parks_heroes` carries the zodiac decal at the Gold Star Hall
  threshold (T-189's corrected location; the interior itself is not
  built — the decal rides the hero at the hall's threshold).
- **F-14 VEISHEA dead and mourned — pass (by absence).** Nothing in the
  world stages VEISHEA running; no banner, no prop; any mourning note is
  R4 copy's to carry respectfully.
- **F-15 Jack Trice naming dates + dignity — pass.** T-191's statue is
  the dignified bronze figure (presence + crouch, no face, no
  caricature; the naming timeline lives in the world script's comments);
  the sweep (01) shows the bowl without gag content; facade text defers
  to R4's legal pass.
- **F-16 spell it "Oktoberfest" for Ames — deferred-with-reason.** No
  signage text exists in the world yet (geometry-only per the ring plan;
  R4's text capability T-197+ owns every letterform) — the spelling law
  is hereby RECORDED for R4 to inherit; nothing today can render it
  wrong.
- **F-17 campaniling folklore (midnight + under the tower; jelly
  beans/lemon drops; the paddling legend stays rumor-only) —
  deferred-with-reason.** Same R4-text path as F-16; the folklore laws
  recorded here for R4's copy.
- **F-18 "Cyclone" = the town's visual grammar (cardinal & gold) —
  pass.** T-191's cardinal seat field + gold sections (the sweep 01
  reads the spangle from the air); the remaining banner/awning grammar
  is R4's.
- **F-19 the Cy Walk bridge over University Blvd is OPEN —
  deferred-with-reason.** No R3 ticket owned it (the ring's ticket list
  T-185..T-195 names no bridge ticket) and nothing stages it today —
  an honest gap this walk surfaces: University Blvd is in-core east of
  the stadium. Filed for the east-edge work (R5's bbox-east T-203) or a
  dedicated follow-up ticket; NOT silently claimed as standing.
- **F-20 no Amtrak; the depot is 1906 C&NW scenery — pass.**
  `rail_dressing_pins`: the depot hero is the canopy'd scenery mass; the
  line is the double-track freight through-line with the coal drag; no
  station/platform furniture exists to fake a node.
- **F-21 UNKNOWN dims not invented — pass.** The V-30 honesty pins are
  LIVE: T-195's 30–40 m band assertion (never exact), T-189's MU tower
  estimate kept explicitly UNVERIFIED, T-193's tanks at their recorded
  survey-anchored approximations, T-191's generic tailgate lot names.
- **F-22 no South Skunk River in-core — pass.** The pack's water set is
  creeks + Lake LaVerne only (`ames_data_integrity`'s counts); Ada
  Hayden stays north-outside (the fly-out contract arm).
- **F-23 Ioway naming everywhere — pass.** The baker's creek quads ride
  the College/Ioway centerlines (`scripts/ames_baker.gd:36`); a tree
  grep carries zero "Squaw Creek" strings.
- **F-24 venue churn (signage as eras; buildings as constants) — pass,
  by the ring's own design.** No business name is baked anywhere
  (geometry-only world; T-192's blade seeds are blank geometry — the
  neon text is R4's legal pass, which inherits the re-verify-before-bake
  rule this item states).

Walk tally: **21 pass** (one by the licensed deliberate choice, two by
geometry-level proof with the text law carried to R4), **3
deferred-with-reason** (F-16, F-17 — R4 text; F-19 — no ring ticket
owned the bridge, filed for the east-edge work). Nothing the sweep saw
needed a fix: every hero read its survey cluster's silhouette, palette
and position on the first pass — no fixed-here items, no regressions.

### Gate record (this worktree, 2026-11-16, the final tree)

- **Gate 1** (import + 120-frame boot): `godot --headless --path .
  --import` exits 0 with only the accepted godot_mcp "33 resources
  still in use at exit" notice; `godot --headless --path . --quit-after
  120` exits 0 with ZERO error lines.
- **Gate 1b** (full suite): `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` — `SIM SUMMARY: 0 failure(s)`, **151
  checks pass / 0 fail / 0 SCRIPT ERROR lines, exit 0**. The T-195 tree
  measured 150; the delta is the one new `r3_cutover_swap_set` row.
  Iteration record: the first red run's honest failures were the
  scenario's own measurement laws, not the world — the shared hero
  records needed per-hero filtering (their `hero` keys), and the
  budget cross-foot initially conflated the parts count (94) with the
  id count (13); both re-derived (the T-186 law's per-ticket honesty
  kept — nothing weakened, everything tightened).
- **Gate 2** (autoplay on the default): `godot --path .
  res://tests/autoplay.tscn` — exit 0, no SCRIPT ERROR:
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
  t=103.0 fps=132 player=(386.9, 0.3, -296.6) speed=2.64 hunger=99
  eaten=7 splats=26 tourists=24 panics=0 honks=0 shares=0
  relocations=0 score=0 high=780 restart=true` — the survival loop
  closes and the living town (24 zone tourists, the parked stock, the
  fleet) is in the DONE line, under the heroes' silhouettes.
- **Gate 3** (human): PENDING — the owner's postcard flight (AC 6, the
  ring's bar; VERIFICATION.md's Gate 3 line carries it unchecked).

## Tuned values (recorded per the ticket loop — NO feel constant moved;
the flight quartet, the fleet/crowd caps and the M2 economy table stay
byte-identical to the per-ticket freezes; the cutover moved no gameplay
value at all — its numbers are the swap-set proof's own pins)

- **The ring slot table** (`r3_cutover_swap_set`, tests/sim_test.gd):
  17 slots — T-186 campanile way/183041212 · T-188 beardshear
  way/33725619 + morrill way/158023244 + farm_house way/158023219 +
  marston_hall way/183216666 · T-189 MU way/183224150 + parks
  way/33725897 · T-190 marston way/861201396 · T-191 jack trice
  way/613735866 + hilton way/180651868 · T-192 bandshell
  downtown_bandshell + city hall relation/2560369 + municipal
  way/237834146 · T-193 city_water_tank_north/east · T-194 depot
  way/260524827 · T-195 grain_elevators.
- **Position tolerances** (measured on the resident world): 5.0 m
  standard; the bandshell row 40.0 m for T-192's ticketed ~35 m
  true-position re-shape (measured 35.9); the stadium row 12.0 m for
  the hero's asymmetric additions (press/videoboard/statue/hillside;
  measured 9.5). All other measured offsets 0.0–3.6 m.
- **The supersede counts** (re-derived from the ring table, cross-foot
  ames_world_render_budget's hand-counted 99): 94 superseded placeholder
  parts + 13 skipped massing ids (8 bake `heroes` + 5 runtime slots) —
  94 parts + 5 runtime-massing boxes ride the 99, the bake's 8 ride
  `hero_count`; the 11 venue fixups stay honest LOD0, named.
- **Suite size:** 151 checks (the T-195 tree measured 150; the delta is
  the one new cutover row).
- **The fidelity walk tally:** 21 pass / 3 deferred-with-reason
  (F-16 + F-17 → R4's text path, the laws recorded in-ticket for R4 to
  inherit; F-19 — the Cy Walk bridge had no ring ticket, filed for the
  east-edge work T-203 or a follow-up). 0 fixed-here.

## ACCEPTED — reviewer sign-off on the landed tree 2026-11-16; the
## ticket flips done on that sign-off, closing the R3 ring

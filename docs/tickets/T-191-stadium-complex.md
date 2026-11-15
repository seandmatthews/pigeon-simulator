# T-191 — Ames R3 · Jack Trice Stadium complex: the bowl, the hillside, the drum

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-177
- **Refs:** `MODELING-SPECS.md` §1 stadium+tailgates · `verification`
  ground truth (field N–S — the Wikipedia misquote corrected; 61,500;
  bowl 183×208 m; Hilton 138×105 m ≈ 790 m NE center-to-center) ·
  `landmarks/LANDMARKS.md` (naming timeline: students' name 1975 /
  field 1984 / stadium 1997 / statue 1988→moved 1997 — handle with
  dignity, fidelity note) · `images/stadium/` (9 refs) ·
  `community/TRADITIONS.md` §3 (Jack Trice's story — the moral
  touchstone)

## What

The town's biggest silhouette set, one complex:

- **Jack Trice Stadium**: the open bowl at true dims with the NORTH
  grass hillside wedge (the berm read), west press box, Sukup hint
  massing; the CYCLONES facade letters deferred to R4 (text); the
  Jack Trice STATUE as a simplified figure at the plaza (dignity note:
  presence and posture from refs, no caricature).
- **Hilton Coliseum**: the round concrete drum at 138×105 m ~790 m NE,
  entry portico hint.
- **Tailgate lot massing**: the surrounding lots as paved flats with
  lot markings hint (populated dressing is T-208).
- Field: N–S orientation, 53×113 m pitch inside the bowl.

## Why

The #1 and #2 from-the-air reads (bowl + drum). The naming timeline
matters: everything here carries the ground-truth dates in comments/
docs so no text asset later contradicts them.

## Acceptance criteria

- [x] Bowl + hillside + drum swap slots 1:1; N–S field; dims ±2 m
- [x] Statue present at the plaza position, simplified-dignified
- [x] *(Gate 1b)* `stadium_complex_dims` (re-pins T-175 rows; field
      orientation assertion N–S)
- [x] Screenshot set vs `images/stadium/` refs (west facade w/ berms,
      north CYCLONES facade pre-text, drum closeup)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

## Landing record (agent pass 2026-11-15; ACCEPTED — reviewer sign-off 2026-11-15; the owner's look pass rides the T-196 R3-cutover postcard flight per the ring plan)

### Built

- **The bowl hero** (`_build_stadium_hero`, carrier chunk (4,3) — the
  north-rim segments in (4,4) retire through the supersede list): the
  T-175 ring schedule kept EXACTLY (36 chord segments, outer face
  91.5 × 104.0 → **183.1 × 208.1 measured**, V-09 ±2 ✓) now DECKED —
  double-decked sidelines (lower 0–10.5, upper 10.5–19.5 cantilevered
  flush at the outer face, sections striped cardinal/gold), single-deck
  end zones (0–16), the low north wall (0–6) the hillside crests over;
  seats read brick-red from OUTSIDE (`#A6192E`, gold `#C9A94E`,
  concrete `#9C9C94` — §1.3 verbatim).
- **The north grass hillside** (V-11): two grass steps per side at the
  NE/NW corners (step 1 tops 6.0, crest 10.5, x bands ±34..±70),
  reaching past the bowl's north rim (the T-175 reach law kept) — the
  x bands reshaped from T-175's ±12..±72 to clear the authored Jacobson
  mass (x 1166.7..1210.7) the placeholder berms used to clip.
- **The west press/suite tower** (1997, 3 levels): concrete base
  0–12 + glass 12–22 + glass penthouse 22–28 + roof slab, west face ON
  the ring face, top **29.0** (`#6E7B82` glass / `#9C9C94` concrete).
- **The Sukup Endzone Club hint** (2015 south enclosure): pale glass
  band `#C9C68F` over the south deck (16–22, inner face flush); the
  authored south mass `way/613735869` keeps the exterior read.
- **The north videoboard** (V-11: 11 × 24.2 m, added 2011): dark slab
  (luminance 0.12 ≤ 0.25 law) at 18–29 over the Jacobson mass, face to
  the field.
- **The pitch** (V-09): the slot's own 53 × 113 × 0.6 deck, LONG AXIS
  N–S — the AC's orientation assertion, machine-pinned — plus the
  white-markings hint (`#E8E8E2`: touchlines + mid line).
- **The Jack Trice statue**: plaza slab + stone pedestal (top 1.32) +
  the simplified bronze figure (~2.9 total — legs mass, the forward
  crouch, head eyes-open toward the play, the reaching arm), dark
  bronze law (≤ 0.35), at the recorded NE-plaza offset (+58, −140)
  facing the bowl. **The naming timeline rides the world comments**
  (`scripts/ames_world.gd` §T-191 header): campaign 1973–74 / field
  named 1984 (informal from the 1975 opening) / statue dedicated 1988
  on Central Campus, MOVED here when the stadium was renamed 1997 /
  street Jack Trice Way 2023 (TRADITIONS §3, F-15) — no text asset
  exists yet to contradict them; the CYCLONES/HILTON letters and any
  facade text defer to R4's legal pass.
- **The Hilton drum hero** (`_build_hilton_hero`, carrier chunk (4,0);
  the east segments in (5,0) retire): the T-175 12-sided schedule kept
  EXACTLY (outer face 69 × 52.5 → **138.2 × 105.7 measured**, §1.3 ±2
  ✓), wall to 20.0 with stain-streak panels every third segment
  (`#A69E8F` / `#8C857A`), the arc roof closing at the slot's own
  **23.0** with the §1.3 3 m overhang (elliptic slab 144 × 111,
  collision convex + named mesh), the east entry portico hint (canopy
  13 × 26 at 8.2–9.2 + two columns) and the ISU-seal medallion
  silhouette (r 1.6 dark disc, ≤ 0.45 law) on the wall above the
  canopy, facing EAST (the University Blvd approach read — the T-190
  medallion law; the cast HILTON COLISEUM letters defer to R4).
- **The tailgate lot massing** (`_build_tailgate_lots`, the
  `StadiumLots` dress outside the bake-derived render metric — the
  T-187 law): the pack's own Iowa State Center lot polygons (census §3
  tailgate box; 18 polygon lots — the census's 19th is the
  vertex-less node entry) paved as flats (`#56585C`, 346 ear-clip
  tris at y 0.03) with the white stall-marking hint (y 0.06, rows
  every 6.0 m, stalls every 2.75 m, 5.0 m lines, polygon-clipped —
  **4715 markings**, every one inside the tailgate union); the
  populated dressing stays T-208's.

### Gate ledger (all run 2026-11-15, this worktree)

- **Gate 1** ✓ — `--import` exits 0 with only the accepted godot_mcp
  "resources still in use" line; `--quit-after 120` boots clean.
- **Gate 1b** ✓ — full suite `SIM SUMMARY: 0 failure(s)`, including
  the new `stadium_complex_dims` row (the swap walks, the T-175
  bowl/drum rows re-pinned on the heroes' records, the N–S field
  assertion, the palette + darkness laws, the live ray/ground seams,
  the roof crumbs, the tailgate recount) and `ames_world_render_budget`
  re-derived (−52 retired slot parts). Landing-round finds, all fixed:
  a `Vector2+Vector3` parse error (lot-flats AABB), a recount typo
  (`b_hi` read `max_z2` on both ternary branches — five lots recounted
  0), and two seam queries re-aimed (the berm step-1 point out from
  under the crest box; the drum-wall point outside the roof's walkable
  filing).
- **Gate 2** ✓ — `AUTOPLAY DONE ok=true world=ames … restart=true`
  (headless; the capture "Parameter t is null" line is the known
  dummy-renderer artifact, not a gate line).
- **Gate 3** — the agent screenshot set below; the OWNER judgement
  (does the bowl read as THE bowl from the air, does the drum read as
  the round drum, does the statue read with dignity) stays the T-196
  R3-cutover postcard flight per the ring plan.

### Screenshot ledger (pilot session `t191stadium`, hidden window per
T-170; refs under `docs/references/ames-survey/images/stadium/`)

- `.captures/session_t191stadium/stadium_complex_overview.png` — the
  whole complex from the west at 40 m: the decked cardinal bowl with
  the gold stripes, the west press tower, the north berms, the Sukup
  glass band, the videoboard slab, the low Iowa State Center masses
  and the lot sea with its parked fleet east — vs `12-isu-center-
  parking-dusk-pano.jpg`'s ring-in-a-sea-of-lots read (the pano's
  night-floodlit grade is not reproducible in-engine; matched for
  silhouette).
- `.captures/session_t191stadium/stadium_west_gate_berms.png` —
  ground-level at the NW corner: the two-step grass hillside, the
  cardinal wall and the press tower's pale mass — vs
  `20-jack-trice-west-facade-gate4-2006.jpg`'s slopes-flanking-the-
  gate read (ref 20's gate pylons read as our press tower mass; the
  berm slopes flank, not gate-specific pylons — the honest
  simplification).
- `.captures/session_t191stadium/stadium_west_facade_berms.png` — the
  west face from the lot at deck height: the striped upper deck, the
  cardinal field, the Sukup band beyond.
- `.captures/session_t191stadium/stadium_north_facade_pretext.png` —
  over the Jacobson mass from the NE plaza: the STATUE on its plaza,
  the NE berm wedge, the ring + Sukup band and the videoboard slab,
  the lot fleet beyond — the ref `21-jack-trice-north-facade-
  cyclones-2018.jpg` PRE-TEXT state (the CYCLONES glass-gable letters
  defer to R4's text pass per the ticket's What block; the survey's
  §1.3 materials row puts the Sukup glass at the SOUTH end, kept).
- `.captures/session_t191stadium/stadium_statue_closeup.png` — the
  statue from the south across its plaza: plinth + the dark bronze
  crouched figure against the sky — presence and posture, no face, no
  caricature (the dignity note; OWNER confirms the read in T-196).
- `.captures/session_t191stadium/hilton_drum_closeup.png` — the drum's
  east facade from the lot: the board-formed panels, the seal
  medallion silhouette and the portico canopy line — vs
  `22-hilton-coliseum-drum-facade-2018.jpg` (the cast HILTON
  COLISEUM letters defer to R4; the seal is the geometry hint).

### Honest deviations

1. **The statue position is a survey-anchored approximation** (the
   V-30 law): no sourced statue coordinate exists in the survey —
   pinned at the NE-plaza offset (+58, −140) from the bowl center,
   facing the bowl, recorded in `ames_world.gd` so a sourced fix
   re-pins one constant.
2. **The berm x-bands moved** (±34..±70 vs T-175's ±12..±72): the
   placeholder berms clipped the authored Jacobson mass; the reach-
   past-the-north-rim law and the NE/NW corner read are kept and
   machine-pinned.
3. **The Hilton roof's walkable filing keeps the T-175 slot's own
   118 × 90 footprint** (byte-continuity of the walk answers); the
   visual/collision roof overhangs to 144 × 111 per §1.3 — the
   overhang ring is collision, not a walkable filing.
4. **Ref 21's north CYCLONES letters do not exist yet** — text is
   R4's legal pass (the ticket's own What block); the shot records
   the pre-text state honestly.
5. **The stadium's roof crumb moved by design**: the superseded
   placeholder pinned a ROOF spot at a ring-segment top (14 m); the
   hero re-pins it at the press-tower roof (29 m) — recorded in the
   Gate 1b row; Hilton's crumb is byte-identical at 23 m.
6. **The dusk lighting lifts the asphalt**: the lot flats carry the
   pinned `#56585C` (machine-asserted through the mesh path's linear
   conversion, the T-187 law) but the session's low sun reads them
   pale-gray — the palette arm is the ground truth, not the JPEG.

### Tuned values (the constants live in `scripts/ames_world.gd` §T-191)

Bowl decks 10.5/19.5 (upper width 13 flush), end zones 16.0, north
wall 6.0; press tower top 29.0 (base 25 × 60, penthouse 19 × 40);
Sukup band 16–22 (68 × 4); videoboard 24.2 × 11.0 × 1.2 at 18–29
(z −105); berms ±52 (36 × 6 × 24 at y 3, 24 × 4.5 × 15 at y 8.25);
pitch 53 × 113 × 0.6, markings y 0.63; statue (+58, −140): plaza
8 × 0.12 × 8, pedestal 2.4 × 1.2 × 2.4 (top 1.32), figure to ~2.9;
Hilton ring top 20.0, roof 20–23 overhanging to 144 × 111, canopy
13 × 1 × 26 at 8.2–9.2, columns 0.9 × 8.2 × 0.9 at (+77.5, ±11.5),
seal r 1.6 at y 13.0 facing east; lots flat y 0.03, markings y 0.06,
row pitch 6.0, stall pitch 2.75, line depth 5.0 (4715 kept, 346 flat
tris).

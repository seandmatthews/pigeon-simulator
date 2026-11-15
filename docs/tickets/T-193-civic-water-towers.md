# T-193 — Ames R3 · civic water towers: the AMES diamond in the sky

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-177
- **Refs:** `images/misc/01,02` (diamond logo closeup; dusk full tank
  with "We're Glad You're Here" script) · `MODELING-SPECS.md` §1 misc
  (bulb-on-stem municipal form) · Marston T-190 (the campus tower —
  DIFFERENT object; these are the city tanks)

## What

The town's sky-level signature, at its real positions:

- One or two bulb-on-stem city tanks (positions from the data pack)
  with the green/blue **AMES diamond logo as painted geometry**
  (the diamond shape + banding; the letterforms and the welcome
  script are R4 text — the SHAPE lands now so the silhouette is
  already unmistakably Ames).
- Swaps placeholder slots; collision solid; not landable (the bulb
  crown stays honest to the photos).

## Why

The photos' review called the tanks "the town's sky-level signature" —
the cheapest instant-recognition prop in the whole campaign.

## Acceptance criteria

- [x] Tank(s) at data positions, bulb-on-stem form vs photo 02
- [x] Diamond logo shape reads from 200 m (palette pinned: green/blue)
- [x] *(Gate 1b)* `civic_tanks_dims` + palette row
- [x] Screenshot vs `images/misc/02` (dusk)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

Gate results on the landed tree (2026-11-15): Gate 1 — `--import` exit 0
(the one accepted godot_mcp teardown line) + `--quit-after 120` exit 0,
zero error lines; Gate 1b — 148 PASS / 0 FAIL including the new
`civic_tanks_dims` row (run 6, the final tree); Gate 2 — `AUTOPLAY DONE
ok=true world=ames … restart=true poses=DIVE,FLAP,GLIDE,PECK,STAND,WADDLE`.
ACCEPTED — reviewer sign-off 2026-11-15; the owner judgement (does the
diamond read as THE diamond, does the tank read as the town's sky-level
signature) rides the T-196 R3-cutover postcard flight per the ring plan.

## Build record (the landed tree, 2026-11-15)

- **The pair** (`scripts/ames_world.gd`, the T-193 section): swaps the
  two T-175 municipal-bulb placeholder stacks 1:1 on the T-190 law —
  `city_water_tank_north` (stem/bulb/cap, chunk (10,−5)) at the bake's
  own (2600, −1280), the BRET stand-in anchoring north Ames
  (LANDMARKS T8), and `city_water_tank_east` (chunk (13,2)) at (3480,
  620), one of T8's "two others" on the east side. Placeholder-only
  slots (the baker's own T8 stand-ins, NOT manifest `heroes`) — the
  skip rides `_row_superseded_placeholder` for render/ground record and
  `_build_chunk_colliders`' own skip chain for collision (the round-1
  catch: that chain is separate, and until the tank ids joined it the
  retired gray boxes still answered the seam rays).
- **The form** (`images/misc/02` on the slot stack's own spans — the
  T-190 keep-the-stack law): concrete pedestal stem Ø6.6 on 0..16 (the
  photo's ≈3× bulb ratio; the slot's 3 m box was the skinny T-175
  guess), the mushroom shoulder flaring Ø6.6→Ø20 over 16..17.2, the
  white bulb drum Ø20 spanning 17.2..28.0 (the slot bulb's own 20 m
  box, round), the four banding stripes 0.6 m tall at 17.5/18.1/27.1/
  27.7 — photo-02's mirrored pairs, blue inner at the skirt seam and
  blue at the roof edge, green framing the white field — the roof dome
  closing at 30.0 with SIXTEEN dark railing POSTS on its rim (r 9.5;
  the round-1 shot review: a solid ring cylinder's top disc painted a
  fat dark roof from the air, while the photo's railing is a thin post
  line over a white dome), and the AMES diamond as painted geometry —
  a Ø10 on-point square (side 7.071, 7 cm proud) on the town-facing
  wall: the north tank's logo looks SOUTH, the east tank's WEST (the
  game-native read; the photos show one face each). The letterforms and
  the welcome script stay R4 text — the SHAPE is this ticket's scope.
  Collision solid (stem/shoulder/drum/dome convex cylinders ride the
  chunks' placeholder bodies, layer-1 `world`); NOT landable: the swap
  retires the slot's 16/28/30 walk answers and files NO ground record
  and NO roof crumb — the bulb crown stays honest to the photos (dome +
  posts, no flat perch).
- **The palette**: no survey hex exists (photo 01 is a blue duotone
  print — every pixel near hue 215°; photo 02 is dusk-cast; the
  IMAGE_INDEX cluster note pins "green/blue" only), so the pair is held
  by hue/luminance laws (the T-190 dark-law precedent) over this
  ticket's own pinned literals: diamond #134D3B (hue ≈ 161°), green
  stripes #1E6043, blue stripes #284572 (hue ≈ 216°), bulb field
  #EFEEE8 (the town's white-tank convention, warmed a step off
  Marston's #EDEDEA), shoulder shade #D8D7D0, stem #A7A5A2, posts dark
  (luminance ≤ 0.45).
- **Machine proof**: the `civic_tanks_dims` Gate 1b row (the bake slot
  walk, the per-tank dims + stripes + posts + the diamond's world AABB
  10.0 × 10.0 × 0.07 on the face normal, the literal + hue-law palette
  arms, the live mesh albedos, the live seams — the drum wall at Ø20,
  the town-facing wall behind the visual-only diamond (the medallion
  convention: the proud face is proven by the record + the single
  17-instance Boxes MM, not by a ray), the stem Ø6.6, the dome slope,
  the plate answering at both centers) and the render budget's
  bake-derived expectation re-derived in-row (−6 placeholder parts —
  the T-186 law). The whole suite: 148 PASS / 0 FAIL (run 6, the final
  tree).

## Screenshot ledger (agent visual pass, 2026-11-15)

Pilot session `.captures/session_t193vis2/` (hidden window per T-170,
`--images off` trimmed, OS `shot` grabs; hunger locked via the T-167
verb, dusk via the T-169 call verb driving `/root/Main/Sun` low):

- `shot1_north_tank_south_115m.png` — the form read from 115 m south
  (pigeon at 60 m): the white bulb on its concrete stem over the north
  Ames grid, the green diamond on the south face, the banding pairs at
  both edges, the white roof with the dark post fringe — vs
  `images/misc/02`'s bulb-on-stem form (daylight grade).
- `shot2_north_tank_200m.png` — the AC's 200 m read from the south: the
  diamond still reading above the north roofline — the zoom-in shows
  the full lockup (diamond + stripe pairs + roof + stem).
- `shot3_east_tank_west_150m.png` — the east tank at its data position
  on the open east side, the diamond facing WEST (town-facing).
- `shot4_north_tank_dusk_70m.png` — the dusk grade at 70 m: sun driven
  low WSW, long shadows — the dark diamond against the dimming white
  bulb, the banding pairs, the stem — vs `images/misc/02`.
- `shot5_north_tank_dusk_close.png` — the close dusk read: the photo
  01/02 lockup filling the frame — diamond, both stripe pairs, the
  post fringe on the roof, the concrete stem below. No letterforms, no
  script — R4's scope.

Honest deviations, recorded: the engine carries no dusk sky gradient —
matched for silhouette + light direction, not the sky grade (the
T-186 precedent); the diamond reads lighter under full daylight sun
than the pinned dark literal (the albedo is pinned exact in the gate;
the dusk shots read closest to the photos); the posts read as a
speckled fringe from steeply above at close range — they merge into
the band at skyline distances; the drum's collision convex is a
10-gon (the walls read round at game distances; the seam arms carry
the apothem/vertex reads); the total height 30.0 is the T-175 bake
pin (survey-anchored approximation, heights UNVERIFIED per V-30),
kept per the T-190 keep-the-stack law.

## Tuned values

`TANK_TOTAL` 30.0 (the slot's own) · stem Ø6.6 on 0..16 · shoulder
16..17.2 (Ø6.6→Ø20) · drum Ø20 on 17.2..28.0 · stripes 0.6 m at
17.5/18.1/27.1/27.7, Ø20.18 · dome 28..30 (Ø18.6→Ø3.2) · 16 posts at
r 9.5, y 28.3..29.1 (0.18 × 0.8) · diamond diag 10.0 (side 7.071,
t 0.07) at y 22.6, standoff 0.12 · palette #134D3B / #1E6043 /
#284572 / #EFEEE8 / #D8D7D0 / #A7A5A2, posts ≤ 0.45 luminance.

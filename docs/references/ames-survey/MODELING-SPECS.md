# Ames Survey — Modeling Specifications (per-cluster)

Date-stamped: **2026-11-08**. Role: the modeling-specs lane of the Ames survey. This
document translates the whole survey (geography, landmarks, venues, community,
verification, census, reference photos) into per-cluster 3D-modeling specifications —
the document the city-builder agents work from.

**Authority order for any disputed detail:**

1. **The reference photos** (`images/<cluster>/…`) — where a photo and a text lane
   disagree, the PHOTO wins and the text source is flagged as corrected (§2 collects
   every such flag).
2. `verification/VERIFICATION.md` — ground truth for disputed numbers/orientations
   (cited as `V-nn`).
3. `census/BUILD-CENSUS.md` — the generator parameter sheet (cited as `census §n`).
4. `landmarks/LANDMARKS.md`, `venues/VENUES.md`, `community/TRADITIONS.md`,
   `osm/SUMMARY.md` — as corrected by the verification ledger.

**Conventions used in every cluster spec:**

- **PALETTE** hex values are estimates eyeballed from the cited photos (unmanaged
  sRGB, varying exposure/grade) — treat as anchors ±10 %, not calibration.
- **LOD tiers:** `L0` = silhouette box + roof form (procedural filler);
  `L1` = textured box + distinctive roof/openings; `L2` = authored mass + facade
  rhythm (windows, doors, sign bands); `L3` = full geometry (signature set pieces).
  Budget context: the census's authored/procedural split — **512 named buildings
  carry 55.3 % of footprint; 3,175 anonymous boxes (median 127 m²) carry 42.6 %**
  (census §6). Everything marked L0/L1 is procedural territory; L2+ is authored.
- **Image citations** are file paths relative to `docs/references/ames-survey/`.
- **UNKNOWN-model-to-look** = no sourced dimension exists (VERIFICATION §4);
  model to visual match, keep the number out of tooling.
- **Game-native notes** are brief design *implications* (perches, breadcrumbs,
  splat surfaces, NPC placement); the design itself comes later.

**Pass-2 image-lane note (concurrent edits, observed during this read):** the
gap-fill lane was writing while this document was produced. On disk, two indexed
`nature/` files carry *different content than their IMAGE_INDEX.md rows*
(`nature/05-brookside-park-footbridge.jpg` currently holds the stone RR-bridge
abutment described as row 06; `nature/13-reiman-entrance-sign.jpg` currently holds
the butterfly macro described as row 11), and `campus/02-beardshear-green-dome-autumn.jpg`
holds a winter portico close-up rather than the indexed autumn dome view. Two files
failed to decode on read: `nature/10-reiman-conservatory-wing-roof.jpg` and
`_pass2-review/parks_jaretac.jpg` (their content is taken from IMAGE_INDEX.md /
CREDITS.md text only). The `_pass2-review/` staging folder holds 10 unindexed extras;
the ones used here are cited as `_pass2-review/<file>` (pass-2, unindexed).

---

## 1. Per-cluster specs

### 1.1 Cluster: campanile

**SILHOUETTE.** A slender brick needle, 33.5 m tall on a ~5 m square shaft, rising
free of the big lawn's tree line; in the classic view the cap just clears the
surrounding pines and the tower reads as a thin spike with a dark pyramidal hat
(`images/campanile/01-portrait-from-lawn.jpg`, `campanile/09-autumn-portrait.jpg`).
From the air it is the exclamation point on the huge lawn — the lawn is the shape,
the tower is the punctuation (`_pass2-review/aerial_isu.jpg`). Instant-read test:
the ONLY slender freestanding tower inside the town grid.

**PALETTE** (from `campanile/02-spring-closeup.jpg`, `campanile/03-from-central-lawn.jpg`):

| Part | Hex est. |
|---|---|
| Brick, sunlit | `#C9A56A` |
| Brick, mid/shaded | `#8A6D3F` |
| Recessed slots / deep shadow | `#6E5533` |
| Pyramidal cap (dark slate) | `#3F444D` |
| Clock dial (white) | `#F1EEE7`, black numerals |
| Base trim / limestone accents | `#C6C0B2` |
| Lawn ground plane | `#5F7F42` |

The brick is **BUFF/TAN — NOT red** (photos; fidelity F-01). The 03 photo is the
neutral-grade reference for the buff tone; 07 is the golden-hour grade.

**MATERIALS & FEATURES.** Brick masonry throughout (50,000+ bricks per LANDMARKS C1);
Gothic-revival detailing:

1. Open belfry — **two tall lancet openings per face** (recessed, read as dark slots
   from distance; `campanile/05-looking-up-wormseye.jpg`).
2. Dark pyramidal cap with **crocketed corner pinnacles** at the belfry corners
   (`campanile/02-spring-closeup.jpg`).
3. **One white clock face per side at roughly 2/3 height**, slim lancet slot windows
   stacked down the shaft below it.
4. Buttressed entrance arch at the base with limestone trim; snow barely holds on the
   cap edges (`campanile/04-winter-snow-view.jpg`).

**DIMENSIONS.** Height **33.5 m** (110 ft; OSM height tag 34 m on way 183041212
agrees — census §3). Shaft square **4.9 × 4.9 m** (LANDMARKS C1); OSM footprint bbox
6.8 × 6.7 m includes the base plinth — model the plinth, keep the shaft ~5 m.
Centroid (−93.64604, 42.02543), 264 m from Lake LaVerne's center, on the east half of
the Central Campus lawn (census §3, V-12). 50 bells (largest ≈ 2.6 t). No
UNKNOWN-model-to-look items in this cluster.

**LOD.** `L3` full geometry — signature set piece #1. Shaft + belfry openings + clock
faces + cap + crockets as low-poly silhouette furniture; brick as a tiled texture with
normal-mapped coursing, not mesh relief.

**GAME-NATIVE.** The cap top is a landable perch with a 360° skyline read; the belfry
arches are perch-throughs. Breadcrumbs: quarter-hour Westminster chimes as the town's
soundtrack and a "walk under the tower once" rite (TRADITIONS §1); midnight
campaniling pairs + Homecoming-Friday fireworks over the quad; 11:50 a.m. weekday
carillon recitals. NPC placement: graduate-photo clusters on the lawn in May, event
tent footprints (the white event tent in `campanile/02` is a recurring real prop).
The Four Seasons fountain south of the tower (`campus/21-four-seasons-fountain.jpg`)
belongs to this cluster as a prop: splat-water feature, coin-toss counter-curse
bait (TRADITIONS §6), rim perch. CyRide buses passing on Morrill Rd wear
cardinal/gold/white livery (`campanile/06-fountain-and-cyride-bus.jpg`).

---

### 1.2 Cluster: lake-laverne

**SILHOUETTE.** A compact oval pond (236 × 122 m) jammed hard against the Memorial
Union's west face, with Union Drive skirting the shore and the Campanile spike just
northeast — from the air the MU mass + dark oval + tower read as ONE postcard shape
(`images/laverne/01-lake-to-mu-autumn.jpg`, `laverne/02-mu-south-facade-spring.jpg`).
Instant-read test: the only water adjacent to a big limestone block.

**PALETTE** (from `laverne/02-mu-south-facade-spring.jpg`, `laverne/01-lake-to-mu-autumn.jpg`):

| Part | Hex est. |
|---|---|
| Lake water (overcast) | `#46543F` olive-brown |
| Lake water (sky reflection) | `#7C8A93` |
| Shore lawn (mown) | `#6F8F4F` |
| Shore boulders | `#8B8B85` |
| MU limestone, sunlit | `#C4BEB0` |
| MU limestone, shade | `#9E9889` |
| MU tower cap (dark pyramidal) | `#4A4A48` |
| MU low-wing copper roof | `#7FA184` |
| Swans (if modeled) | `#F4F2EC` |

**MATERIALS & FEATURES.** Shoreline = mown lawn straight to the water, a few boulders,
NO beach; swan-plaque markers on the shore (OSM maps them as nodes — SUMMARY §7).
The MU south face is the postcard composition: pale limestone Georgian mass, arched
Great Hall windows, low arcade wing with copper-green roof, and the **squat square
corner tower with dark pyramidal cap + chimney stack** (`laverne/02`;
`campus/19-memorial-union-corner-tower.jpg` for the tower's arched crown and the
mid-century dark-frame glass addition skin). Winter reads: partial ice sheet with
white edges (`laverne/04-mu-winter-frozen-lake.jpg`).

**DIMENSIONS.** Open water **2.8 acres (≈11,300 m²)**, footprint **236 × 122 m**,
center (−93.64792, 42.02354) — game figure per V-12 (the 1.11 ha OSM ring is the same
lake, 2.5 % polygon simplification). Depth: model the **refilled** post-dredge lake,
~5 ft average, max **3.7 m** (V-14 — the lake was drained mid-2026 for the dredge).
MU: 110 × 110 m footprint, 6 levels (V-01, census §3). **MU tower height:
UNKNOWN — model to look**; tooling placeholder "≈35–45 m, UNVERIFIED" only
(VERIFICATION §4 — do NOT bake the circulating ~148 ft). MU corner is **Lincoln Way &
Morrill Rd/Lynn — one block EAST of Stanton** (V-08 corrects LANDMARKS C5/§5).

**LOD.** Lake = authored water shape (`L1` + shore dressing). MU = `L2` authored mass
with facade rhythm; the corner tower gets `L3` treatment (it is the silhouette's crown).
Mid-century glass addition = `L1` dark-curtain texture.

**GAME-NATIVE.** The MU tower top is a marquee perch; the lake surface is a splat
surface with ripples; the shore path is the three-silent-laps folklore loop
(TRADITIONS §2) — breadcrumb it with a discreet marker, not a sign. Swans: as of the
survey date the lake is SWANLESS (Lancelot died June 2022, Elaine retired Nov 2022 —
V-13). If the game stages "now," an empty lake + a restoration note lands truer; if
the swans are restored as a deliberate choice, model two female mute swans and tell
the 1935 story at the plaque (F-12). NPCs: ClubFest crowds at the MU in September,
the Lincoln Way/Union Drive underpass (cluster C13) disgorging pedestrians from
Campustown, parking friction along Union Drive (`laverne/05-union-drive-winter.jpg`).

---

### 1.3 Cluster: stadium + tailgates

**SILHOUETTE.** The biggest object in town: a concrete bowl 183 × 208 m inside a
234 × 303 m fenced site, long axis N–S, with the **grass hillside at the north end**
(NE/NW corners) as the tell, the 3-level press tower on the **west** sideline, and
the glass Sukup club closing the south end; ringed by the Iowa State Center parking
sea with the **Hilton Coliseum drum** (138 × 105 m) ~790 m center-to-center to the
northeast (~640 m edge-to-edge; OSM probe) *(QA fix 2026-11-08: "300 m northeast"
→ ~790 m center-to-center per QA-REPORT item 5)*
(`images/stadium/05-interior-bowl-press-tower.jpg`, `_pass2-review/jtcomplex.jpg`,
`stadium/12-isu-center-parking-dusk-pano.jpg`, `_pass2-review/hilton_tonywebster.jpg`).
Instant-read test: nothing else in town is a bowl; #1 on the from-the-air ranking
(LANDMARKS §5 items 1–2).

**PALETTE** (from `stadium/05`, `stadium/01-interior-night-videoboard.jpg`,
`_pass2-review/jtcomplex.jpg`, `_pass2-review/hilton_tonywebster.jpg`):

| Part | Hex est. |
|---|---|
| Seat field (cardinal, dominant) | `#A6192E` |
| Seat sections (gold accents) | `#C9A94E` |
| Bowl concrete, weathered | `#9C9C94` |
| Press tower glass/steel | `#6E7B82` |
| Sukup club glass (pale yellow-green) | `#C9C68F` |
| Field grass | `#4E7A3A`, white markings `#E8E8E2` |
| Tailgate asphalt | `#56585C` + white stall lines |
| Hilton concrete (board-formed, stained) | `#A69E8F` / streaks `#8C857A` |
| Gameday crowd (distant bowl fill) | cardinal `#A6192E` + gold `#C9A94E` spangle |

**MATERIALS & FEATURES.**

1. Concrete bowl, **double-decked sidelines**; seats read brick-red from OUTSIDE
   (`_pass2-review/jtcomplex.jpg` — the deck's underside is open concrete).
2. **3-level press/suite tower on the WEST sideline** (glass over concrete base).
3. Sukup Endzone club at the south: modern **glass gable facade over the 1975 bowl**,
   flagpole court (`stadium/02-sukup-endzone-club-exterior.jpg`, `jtcomplex.jpg`).
4. **North videoboard, 36 × 79.5 ft (11 × 24.2 m)**, added 2011 (V-11); "JACK TRICE
   STADIUM" west-facade lettering + big "IOWA STATE UNIVERSITY" south lettering
   (`stadium/03-facade-signage-flooded-lots.jpg`, `stadium/09-south-endzone-exterior-wide.jpg`).
5. **Hilton Coliseum:** low 12-sided board-formed concrete drum, shallow arc roof
   overhang, few windows, big entry portico with cast "HILTON COLISEUM" letters +
   ISU seal (`hilton_tonywebster.jpg`, `stadium/10-hilton-entry-portico-signage.jpg`).
6. Tailgate prop stock: RVs with awnings/TVs, canopies, coolers, cornhole
   (`stadium/14-tailgate-lot-rv.jpg`).

**DIMENSIONS.** Capacity **61,500** (V-10; OSM's 55,000 tag is stale 2007–12).
Bowl **183 × 208 m** (long axis N–S), fenced site **234 × 303 m**, pitch
"MidAmerican Field" **53 m E–W × 113 m N–S** (V-09 — the field runs
**NORTH–SOUTH**, standard; fidelity F-04). Press tower west; grass hillside NE/NW;
videoboard north (V-09/V-11). Stadium center (−93.6358, 42.0139); 1.53 km from the
Campanile (census §3). Hilton 138 × 105 m, 12,334 m², capacity 14,267 (census §3,
LANDMARKS C7). Scheman Building 6,123 m²; Lied Recreation Center 15,468 m² (156×126 m);
Bergstrom Indoor Training Facility 92 × 135 m (census §1/§3). Tailgate stock:
**19 Iowa State Center lots, 8.9 ha** mapped (census §3) plus the Lied Rec/grass-field
overflow. **East Gateway pedestrian bridge ("Cy Walk") over University Blvd has been
OPEN since ~2024** (V-17 — LANDMARKS's 2026 "building" line is stale). Address on
South 4th Street: use neither house number (V-28) — place the bowl west of University
Blvd with Jack Trice Way on its north side.

**LOD.** Bowl = `L2` authored mass (stand rakes as textured wedges, seat color by
band); press tower + Sukup facade = `L3`; Hilton drum = `L2` (polygonal drum + arc
roof + portico geometry, concrete texture); videoboard = `L1` black slab + emissive
texture; tailgate lots = `L0` ground splats + prop scatter; Lied Rec/Bergstrom =
`L1` big boxes (Bergstrom's barrel-arch roof from the census bbox is enough).

**GAME-NATIVE.** The gameday loop is the cluster's engine: lots fill from dawn,
Spirit Walk on the north side by the Jacobson Building, the ISUCF'V'MB on the Alumni
Center steps, the crowd streaming across Cy Walk (TRADITIONS §5). Perches: press-tower
roof, light masts, flag court; the over-the-bowl kickoff view is the one seat nobody
sells. Splat surfaces: tailgate-lot car roofs (the game's bread and butter), patio
rails, the sea of windshields. NPC placement: 5–6-hours-early tailgaters in fall
weekends; visitors adopted into tents ("bring a case of beer and a story"). The
**Jack Trice statue** stands at the stadium — model with dignity, never a gag
(TRADITIONS §9.1, F-03). Carlos Quesadilla truck parked inside on gamedays
(VENUES §3.12).

---

### 1.4 Cluster: campus-buildings (Central Campus + west/north campus)

**SILHOUETTE.** One huge **~8.3 ha lawn** with two crossing sight axes (MU–MacKay
E–W, Beardshear–Curtiss N–S), tree-dotted, rimmed by the classical pale row; the
**green dome** of Beardshear closes the north edge (only dome on the quad), Parks
Library is the big block north of the Campanile, **Marston Water Tower** is the lone
51.2 m steel lollipop west, Morrill Hall the red-brick turret east, Farm House the
tiny 1860s farmhouse on its knoll
(`images/campus/02-beardshear-green-dome-autumn.jpg` [on-disk content: the winter
portico close-up], `campus/22-parks-library-addition-dome.jpg`
[faint dome in reflection], `campus/11-marston-tower-full.jpg`,
`campus/13-morrill-hall-winter.jpg`, `_pass2-review/aerial_isu.jpg`).
Instant-read test: the biggest single open green in town with a spike and a dome
(LANDMARKS §5 items 3–9).

**PALETTE** (from `campus/01`/`02` [portico file], `campus/11`, `campus/13`,
`campus/18`, `campus/22`):

| Part | Hex est. |
|---|---|
| Beardshear/Parks limestone, sunlit | `#C8C1AE` |
| Limestone, shade | `#A29B8B` |
| Beardshear dome (oxidized copper) | `#5E8F68` mid, `#8FB98F` light, `#4A7055` dark |
| Marston tank (painted steel) | `#EDEDEA` white / `#D8D8D4` |
| Marston lattice legs | `#C9C9C4` |
| Morrill brick | `#A8503A` sunlit / `#7C3A2B` shade |
| Morrill slate roof (patterned + red banding) | `#3F444C` + `#8C4A3C` |
| Farm House brick | `#9A4A34`, white trim `#EDEAE2` |
| Quad lawn | `#5F7F42`; paths `#C9C3B4` |
| MU/parks 1950s–80s addition glass | `#3E4A50` dark frames + white panels |

**MATERIALS & FEATURES.**

1. **Beardshear Hall** — neoclassical pale limestone, Corinthian portico, carved
   "IOWA STATE UNIVERSITY" pediment, heavy cornice (`campus/02`, `campus/01`);
   **oxidized-copper green dome** over the east entrance is the silhouette icon
   (IMAGE_INDEX cluster note; dome hex estimated from the note + faint reflection in
   `campus/22` — no dedicated CC dome photo exists; pull a dome shot from the
   CREDITS view-online list if the estimate is challenged). Night: facade uplighting
   (`campus/05-beardshear-night-floodlit.jpg`).
2. **Marston Water Tower** — riveted steel cylinder tank with **conical cap, ISU seal
   medallion** on the tank wall, white/pale-gray paint, flared lattice trestle legs
   with ring bracing (`campus/11-marston-tower-full.jpg`,
   `campus/09-marston-tower-legs-closeup.jpg`).
3. **Parks Library** — 1925 Bedford-limestone block (NO CC photo of the 1925 facade —
   IMAGE_INDEX gap) + 1960s–80s additions: blocky pale-concrete pavilions with big
   portal frame and dark curtain-wall glass with white spandrels
   (`campus/22`, `_pass2-review/parks_dirk2010.jpg`, `_pass2-review/parks_cburnett.jpg`).
   Interior easter egg: Grant Wood murals rotunda (`campus/07`).
4. **Morrill Hall** — Romanesque red brick, **round corner turret with conical slate
   roof**, patterned slate hip roof with red banding, limestone base course, tall
   round-arched windows (`campus/13`).
5. **Farm House** — 2-story red brick farmhouse, white trim, front porch, on a knoll
   (`campus/15-farm-house-historic-bw.jpg` is archival B&W only; colors red brick +
   white trim per LANDMARKS C9).
6. **Memorial Union north face** — long pale limestone facade closing the MU–MacKay
   axis: arcade of round-arched windows, dark slate hip roof, stone balustrade with
   corner pavilions, central arched entry (`campus/18`).
7. Context props: Four Seasons fountain (kneeling figures), the 150th-style
   cardinal banners on portico columns (`campus/01`), mature oaks/elms over the whole
   lawn.

**DIMENSIONS.** Central Campus lawn **~8.3 ha** (V-25). Beardshear 9,689 m² GSF,
1906–08 (LANDMARKS C3); footprint 2,151 m² (census §3). Marston tower **51.2 m**,
tank 12.2 m tall × 7.3 m dia, 162,000 gal, 1897 (LANDMARKS C2); footprint 151 m²
(census §3). Parks Library 30,238 m² GSF, 5 floors, original block 53.6 × 39.6 m,
1925, named 1984 (LANDMARKS C4); footprint 95 × 123 m (census §3). Morrill 763 m²,
1891 (census §3, LANDMARKS C8). Farm House 314 m², 1860–61, NHL 1966 (census §3,
LANDMARKS C9). MU north face spans the 110 × 110 m mass (§1.2). The 30-biggest
campus footprints with levels are tabulated in census §3 — use it as the massing
sheet for the other 140 named campus buildings (`L1`/`L2`).

**LOD.** Beardshear `L3` (portico + dome + cornice); Marston tower `L3` (lattice is
the silhouette); Parks `L2` (1925 block + addition skins); Morrill `L3` (turret);
Farm House `L2` (small but precious); MU north face `L2`. Everything else on the
quad: `L1` textured boxes with the census's bbox/levels, dressed pale-limestone or
brick by district rule (§3). The 20-ac lawn itself is the cheapest highest-value
mesh in the whole build.

**GAME-NATIVE.** Perches: Marston tank top (the town's highest open perch inside the
grid), Beardshear dome, turret roof, the balustrades. Breadcrumbs: Barks@Parks therapy
dogs INDOORS — Parks Library Upper Rotunda, 2nd floor — in finals week (TRADITIONS
§6; QA fix 2026-11-08: "on the library lawn" → indoors per QA-REPORT item 9),
WinterFest tree-lighting
across from Beardshear (TRADITIONS §7), graduation-photo drift in May, the
Beardshear–Curtiss axis as the streak-run corridor (tasteful Easter egg only,
TRADITIONS §6). Splat surfaces: lawn, fountain rim, parked staff cars in the East
Parking Deck (5,430 m², census §1). NPCs: crossing flows on the two axes between
classes; CyRide stop "Campanile" 87 m SW of the tower (census §3).

---

### 1.5 Cluster: campustown-venues (Welch Ave strip)

**SILHOUETTE.** A narrow 2-lane bar strip of 2–3-story cinderblock/brick storefronts
running SOUTH from Lincoln Way, closed at its head by the freestanding brick
**clock tower** at the Welch/Lincoln Way corner; 4–10-story student apartment blocks
loom behind and beside (`images/campustown/01-welch-ave-clock-tower-snow.jpg`,
`campustown/03-campustown-side-street-snow.jpg`). Instant-read test: the densest
small-parcel strip in town; Legacy Tower (10 levels, 60 × 38 m) is the one high-rise
(census §3 appendix). NOTE: this strip is SOUTH of Lincoln Way; campus is north
(V-01 — the fly-through runs southbound out of campus).

**PALETTE** (from `campustown/01`, `campustown/02`):

| Part | Hex est. |
|---|---|
| Clock-tower brick shaft | `#9C4E36` |
| Clock-tower cream diamond (zigzag glazed brick) | `#E9E2CE` |
| Clock-tower cap/spire | `#3A3F46` |
| Strip brick facades | `#96513A` … `#7C4230` |
| Cinderblock/stucco facades | `#B9B1A2` … `#C9C0AE` |
| Kum & Go canopy red / stripe | `#C8102E` / `#2E7D46` + `#E8C33C` |
| Vintage lampposts (black, hanging globes) | `#1E1E20` |
| Snow ground (winter grade reference) | `#E8E9E6` |

**MATERIALS & FEATURES.**

1. **The Campustown clock tower** — slender freestanding brick shaft (OSM way
   853592605, ~4 m² footprint at (−93.65015, 42.02134), census §3 appendix), cream
   zigzag glazed-brick diamonds, **four clock faces near the top**, dark pyramidal
   cap (`campustown/01`, `campustown/02`).
2. Storefront fabric: ground-floor box signs (illuminated), wide flat glazing,
   upper-floor apartment windows; the 100 block west row stacks Mickey's (109) →
   Ichiban (117) → **Cy's Roost + Lost and Found (121, a skinny 32 × 12 m two-story
   slot — one building, two nightlife signs)**; east row Macubana (116) → vacant
   120 (ex-Es Tas) → Paddy's over Sips (124/126, one facade two doors, basement
   stairwell glow) → Fire Station 2 (132) (VENUES §1.2–1.4, §4).
3. **Fire Station 2** — civic brick station wedged into the strip (`campustown/04`);
   slated to relocate to State Ave (VENUES §0) — model the Welch building, note the
   era.
4. **Kum & Go** at 203 Welch (west side; V-21 corrects "opposite"), red canopy +
   green/yellow stripe, beer-run store (`campustown/02`).
5. **Legacy Tower** 119 Stanton — 10 levels; **Clouds café on the 7th floor** (V-16
   corrects the "12th floor" memory); rooftop glass band (`campus`… VENUES §3.2).
6. Welch Ave is/was under full reconstruction (2025–26, "building face to building
   face") — model the COMPLETED streetscape with the vintage-style lampposts seen in
   `campustown/01` (VENUES §0).

**DIMENSIONS.** Campustown polygon 748 × 269 m (census §2). Block gaps W→E:
State→Hyland 295 m (the back-of-strip fabric block), Hyland→Sheldon 112,
Sheldon→Hayward 204, Hayward→Welch 134, Welch→Stanton 136 (census §2). Welch
setbacks: p50 16.6 m from centerline but **min 0.2 m — allow ~2 buildings built hard
to the sidewalk** (Cy's Roost); Lincoln Way south frontage deeper at p50 20.7 m with
parking rows (census §2). Strip buildings p50 294 m²; 58 named authored buildings in
the strip (census §6). Address rules: Welch numbers increase SOUTH, odd west / even
east (V-22). Venues: 26 in-core Tier-1/2 anchors with exact OSM coords in census §2;
Superdog is a cart prop at the 200-block east curb across from Kum & Go (census §6);
the Welch Ave Station building (207 Welch) carries NO venue name in OSM — attach it
by hand (census §6); The Stan Tap (216 Stanton, 3 lv) sits on an anonymous footprint
— add to the authored set (census §6).

**LOD.** Clock tower `L3`; Cy's Roost / Paddy's-Sips / Welch Ave Station / Mickey's /
BNC `L2` (facade rhythm + sign bands + the night-glow tells); Kum & Go `L2` (canopy);
Legacy Tower + 23 Twenty + The Foundry + Union on Lincoln Way (6 lv, 4,799 m²) `L2`
mass with `L1` skin; everything else `L1`.

**GAME-NATIVE.** This is the night district: perches on the clock tower cap, parapets
and blade signs; splat surfaces on patio rails, the 2 a.m. queue sidewalks (Superdog,
Mr. Burrito, Jeff's), and parked cars. Breadcrumbs: 801 Day floods the
Lincoln Way/Welch intersection (the emotional center — model it generously wide,
VENUES §4); the "DOG TOWN" ghost-sign nod at Dogtown University 217 Welch (Campustown's
original nickname, circa 1922 — VENUES §3.7). NPC night-flow: 8–10 pm West Street and
Mickey's patios; 10–12 Cy's/Mickey's/Paddy's; 12–2 Sips/AJ's/Outlaws; 2 am Superdog
(VENUES §4). The Lincoln Way & Welch corner is where the 2014 VEISHEA riot toppled a
stoplight — memory, not a prop (TRADITIONS §4, F-14).

---

### 1.6 Cluster: lincolnway-corridor

**SILHOUETTE.** A dead-straight due-E–W four-lane urban state highway (primary, 20 m
default width — census §7.3) with mast-arm signals, set-back one-story retail behind
pole/pylon signs, motels and car lots; the MU frontage owns the north side at the
Campustown stretch (`images/lincolnway/01-lincolnway-welch-intersection-snow.jpg`,
`lincolnway/02-s-duff-commercial-strip-flood.jpg`). Instant-read test: the WIDE
asphalt spine — contrast with downtown Main's tight historic wall (§3). **The corridor
is thin in references: only 4 winter/street-corner photos; supplement from the
CREDITS view-online list (the 2023 katherineofchicago Flickr set is the best
street-level ref but all-rights-reserved — view, don't ship).**

**PALETTE** (from `lincolnway/01`, `lincolnway/02`):

| Part | Hex est. |
|---|---|
| Asphalt (4-lane) | `#5A5C5E` |
| Mast-arm signals / poles | `#2A2C2E` |
| Storefront fascia (e.g. Copyworks blue) | `#2E5EA8` |
| Strip brick / stucco boxes | `#9C6A48` / `#C4B49A` |
| Pole signs (Advance red, CarX yellow) | `#D22730` / `#E8B92E` |
| Church spire (Memorial Lutheran silhouette beyond Welch) | `#8C8578` |

**MATERIALS & FEATURES.**

1. Mast-arm signal gantries at the major crossings (State, Sheldon, Hayward, Welch,
   Stanton — the 8 signalized Campustown nodes, census §4).
2. Set-back one-story retail with **freestanding pole/pylon signs** and parking
   aprons between sidewalk and door (`lincolnway/02`).
3. The Campustown gate cluster west of Welch on the south side: Dunkin' (2650), U.S.
   Bank (2546), Mr. Burrito (2508), Café Beaudelaire (2504) — then east: 23 Twenty
   (2320, 7 lv), The Foundry (2300), Memorial Lutheran (2228), St Thomas Aquinas
   (2210) (order per V-20; addresses increase WESTWARD on the south side — F-09).
4. Far west: Fareway **Meat Market** #189 at 3720 (NOT the full store — F-08) and
   Hy-Vee big box at 3800 (V-15; footprint 0.784 ha, OSM way 186660819). *(QA fix
   2026-11-08: census §1's "Hy-Vee (S Duff)" 0.699 ha is the OTHER Ames store —
   Hy-Vee "Lincoln Center", 640 Lincoln Way near Grand (way 98658304); no Hy-Vee is
   on S Duff — per QA-REPORT item 2.)*
5. S Duff south of Lincoln Way: the commercial-strip typology at full width — pole
   signs, set-back boxes, wooden utility poles with wire (photo), chain food row
   (Texas Roadhouse, Red Lobster, Arby's, Taco Bell — census appendix), ALDI, and the
   Walmart Supercenter at 534 S Duff (F-08).

**DIMENSIONS.** Lincoln Way: due E–W at lat 42.0227–42.0229 (V-03 — NOT diagonal);
name changes to "East Lincoln Way" exactly at Duff (SUMMARY §4). Primary width
default 20 m (census §7.3). Block rhythm 110–140 m with real wide gaps at
University Blvd (295 m) and Beach (503 m — the campus/greenway edges, SUMMARY §5).
South-side L/W addresses increase westward (V-20). Welch→Stanton 136 m, Welch
centerline lon −93.65015 (census §7.2).

**LOD.** The corridor is `L1` at heart: textured boxes + pole-sign sprites + mast-arm
props. Authored exceptions: Café Beaudelaire corner (the lit corner at the head of
the strip), Memorial Lutheran + St Thomas (church forms on the campus gate), 23
Twenty/The Foundry towers (`L2`), Hy-Vee/Fareway Meat Market big boxes (`L1` with
correct sign-band colors — model the sign, rename the wordmark per LANDMARKS tiers).

**GAME-NATIVE.** Perches: mast-arm crossarms, pole-sign tops (classic pigeon real
estate), motel-canopy edges. Splat surfaces: the giant parking aprons and windshields.
Breadcrumbs: the Lincoln Way/Union Drive pedestrian underpass (2021, the only road
tunnel on campus — LANDMARKS C13) as a swallow-perch fly-through; traffic light
cycles at Welch as the crosswalk machine's showcase. NPCs: bus-stop clusters, the
8 a.m. coffee queue at Dunkin', the 2 am spill from Café B/Mr. Burrito.

---

### 1.7 Cluster: downtown-main-street

**SILHOUETTE.** A continuous 1880s–1920s commercial wall of 2–3-story masonry blocks
with flat roofs, parapets and cornices, on 125–140 m blocks with a hard ~12 m setback
line; the pale scallop of the 1934 **Durham Bandshell** in its green pocket just
east of the grid; the double-track rail line squeezing along the district's south
edge (44 m from Main×Duff — SUMMARY §8)
(`images/downtown/01-main-street-timkiser.jpg`, `downtown/05-durham-bandshell-front.jpg`,
`downtown/06-durham-bandshell-side.jpg`). Instant-read test: LANDMARKS §5 item 13 —
the 2-3-story Main Street strip with the white shell in its green pocket.

**PALETTE** (from `downtown/01`, `downtown/05`, `downtown/08`):

| Part | Hex est. |
|---|---|
| Brick blocks (range) | `#8A4A36` … `#A8663F` |
| Painted concrete / cream facades | `#C9C0AE` |
| Cornice stone | `#D6CDBB` |
| Street furniture (lamp posts, banner arms) | `#5C2E35` maroon |
| "AMES" banner | `#2E4E9E` blue + white/yellow text |
| Sidewalk red-brick band | `#A05A44` |
| Bandshell outer arch (weathered copper) | `#4A5A57` |
| Bandshell inner shells | `#DCE8DC` pale mint / `#EDE9D8` cream |
| Bandshell brick piers | `#9C4A34` |

**MATERIALS & FEATURES.**

1. Continuous storefront wall: brick + painted concrete, varied cornices, 1950s–2000s
   storefront infill, blade signs and window posters; angled + parallel parking
   (`downtown/01`, `downtown/08`).
2. **Maroon street furniture** with blue "AMES many windows one community" banners —
   the town's downtown signature (`downtown/01`).
3. **Durham Bandshell** — ribbed arch shell: OUTER arch is dark weathered copper
   patina, INNER concentric shells pale mint/cream, brick side piers with
   metal-grille windows (`downtown/05`, `downtown/06`). (Refines the IMAGE_INDEX
   "white/pale-green scallop shell" note — see F-11.)
4. Civic set pieces: Ames City Hall (5,148 m², rel 2560369 — census appendix), the
   Masonic Temple/Octagon corner block (`downtown/03`), Municipal Building stone
   cartouche (`downtown/02`).
5. Bar-sign grammar: vertical neon blade + window posters (`downtown/07`,
   `downtown/09`).
6. The restored Orpheum Theater is the district's marquee cinema (LANDMARKS T1) —
   marquee geometry, no CC photo; model to look from the street rows.

**DIMENSIONS.** District polygon 995 × 411 m; 158 buildings (113 named); footprint
p50 246 m², p90 836 m²; setback to Main centerline **12.4 m p50 (11.7–12.6 p25–75) —
build the wall flat** (census §2). Block gaps W→E: 115, 63, 214, 122, 139, 133, 138 m;
Main→5th 86 m, **5th→6th ≈105 m (census corrects SUMMARY §5's 205 m — F-10)**
(census §2/§7.1). **Main Street addresses increase WESTWARD; the 100 block is the
EAST end at Duff** (V-06 — F-07). True W→E venue order: Aunt Maude's (547) →
Cornbred BBQ depot (526) → Torrent (504 Burnett) → Cafe Diem (229) → London
Underground (212) → Whiskey River (134) → Great Plains (129) → Sam's Place (125) →
Grove Cafe (124) → Sportsman (123) → Mary Jane's (119) → Morning Bell (111)
(VERIFICATION §5). So **Great Plains is at the EAST end near Duff** (VENUES §1.14's
"near Clark/west end" is corrected), and **the Cornbred depot stands at Main's WEST
end near Clark/Pearle** (VENUES §2.6's "east end" is corrected) — one imagery check
on the 500 block is still an open item (VERIFICATION §6.4). Bandshell Park (2.5 ac)
centers ~30 m EAST of the core edge — widen the box ~50 m or hand-place it
(census §5).

**LOD.** The two Main/5th frontage rows: `L2` (parapet variety + sign band), with
named venues getting facade-correct treatment; second-row buildings `L1`; Bandshell
`L3` (a small, high-value organic shell); City Hall `L2`. The remaining downtown
blocks are the densest procedural payoff in the build (29–38 buildings per block,
census §2).

**GAME-NATIVE.** Perches: cornices, blade-sign tops, the bandshell arch crown.
Splat surfaces: farmers-market canopies on Saturday mornings (the market closes Main —
VENUES §5.2), patio rails, parked cars along both curbs. Breadcrumbs: free Municipal
Band concerts every Thursday June–July at the bandshell (LANDMARKS T2), Snow Magic in
Tom Evans Plaza in December (TRADITIONS §7), Oktoberfest on the 200 block (spell it
with the T — F-16). NPC day-rhythm: Grove Cafe at 6 am, deli lunch counters,
Whiskey River/Torrent evenings, London Underground last call.

---

### 1.8 Cluster: rail-corridor

**SILHOUETTE.** The double-tracked UP Clinton Subdivision (ex-C&NW Overland Route)
running ENE at 93.7° through the campus–downtown gap, ballasted, welded rail on
concrete ties, cantilever/mast signals; a **yellow SD70ACe coal drag** rolling through
is the daily animation that makes the town read as a railroad town
(`images/rail/07-up-coal-drag-2019.jpg`, `rail/03-up-freight-nevada-ia.jpg`,
`rail/06-bigboy-side-2019.jpg` for right-of-way cross-section). Instant-read test:
LANDMARKS §5 item 12 — the double-track spine with a train on it.

**PALETTE** (from `rail/07`, `rail/08-ames-depot.jpg`, `rail/10-grain-elevator-hull-ia.jpg`):

| Part | Hex est. |
|---|---|
| UP locomotive yellow (weathered) | `#F2B01E` / `#D9A02C` |
| Winged shield | `#1C3F94` blue + `#E8E6E0` white |
| Coal hoppers | `#6B655C` brown-gray |
| Ballast | `#8A8578` |
| Depot brick | `#9A4030` |
| Depot tile roof | `#B04A34` |
| Depot canopy brackets (green) | `#3E7A5A` |
| Grain silos (style ref) | `#D9D2C4` pale |

**MATERIALS & FEATURES.**

1. Main line: 2 tracks through town, 70 mph tagged (90-mph-class geometry — SUMMARY
   §8); entering the core's west edge at lat ≈42.034, bending through downtown at
   lat 42.0241→42.0247 (census §5).
2. **The Ames depot** — 1906-era C&NW depot, red brick + red tile hip roofs, arched
   half-round dormer windows, brick chimney, long platform canopy with GREEN painted
   brackets (`rail/08`). (Note: OSM carries NO Amtrak station node — SUMMARY §8 —
   and Ames has no Amtrak service in reality either: Iowa's Amtrak stops are all on
   the southern-BNSF California Zephyr line; the nearest to Ames is Osceola. The
   depot is unhosted scenery — treat the depot as scenery + the train stop as
   fiction-adjacent, per F-20. *(QA fix 2026-11-08: strikes this doc's "the real
   depot serves Amtrak" claim per QA-REPORT item 6; the IMAGE_INDEX rail-note half
   is deferred to item 7.)*
3. Crossing hardware: modern mast/cantilever signals at the 4 downtown vehicular
   crossings (Grand-spur, Clark, Kellogg, Duff — all at-grade) + Hazel/Brookridge;
   15 vehicular crossings in core, 9 at-grade (census §5). The WRRS wigwag
   (`rail/09`) is a museum piece — cosmetic prop only.
4. **Grain elevators (SE cluster)** — pale concrete silo bank + headhouse + attached
   steel bins (`rail/10`–`12` are Iowa-generic STYLE references; the Ames SE cluster
   has NO CC photos). Heights UNKNOWN/UNVERIFIED: 30–40 m placeholder, eyeball
   against aerials (V-30, VERIFICATION §6.1).
5. Yard: short industrial lead east of downtown; the big yard is OUTSIDE the core
   (~2.3 km ENE — SUMMARY §8). NO hump (LANDMARKS T6).

**DIMENSIONS.** Clinton Sub main line 8.47 km in core across 26 ways; Jewell Sub
1.25 km leaving NW (census §5). Downtown crossings at: Grand −93.62026 (spur),
Clark −93.61691, Kellogg −93.61374, Duff −93.61042 (census §5). Main Street is only
244 m north of Lincoln Way — the rail line runs between them (SUMMARY §4).

**LOD.** Track/roadbed `L1` spline work; locomotives + hoppers `L2` (the yellow
shield units must be right — they are the daily train, F-05); depot `L3` (small,
distinctive); grain elevators `L2` silo cylinders + headhouse (silhouette matters,
texture simple); crossing signals `L2` props with animated gates at the 9 at-grade
vehicular crossings — the train-blocking set (census §5).

**GAME-NATIVE.** The train is the town's metronome: block traffic at Grand/Clark/
Kellogg/Duff, gameday extra chains in fall. Perches: signal masts, depot canopy
ridge, silo caps (the SE skyline). Breadcrumbs: the 44 m rail-to-Main×Duff squeeze;
the depot platform as an NPC idle spot; "the reason Ames exists" flavor at the depot
sign (founded Dec 1864 by the C&NW — LANDMARKS T6). Splat surfaces: hopper roofs in
motion (a pigeon classic), stationary coal drags held for the downtown crossings.

---

### 1.9 Cluster: water-green (creeks, parks, Reiman gate)

**SILHOUETTE.** Ioway Creek's meander monster wrapping Brookside Park's dark oak
forest (the biggest dark tree mass inside the grid), College Creek crossing campus
W→E, and — at the town's south gate — Reiman Gardens' low glass conservatory with the
butterfly-wing blue-glass roof (`images/nature/05-brookside-park-footbridge.jpg`
[on-disk content: the stone RR-bridge abutment over the creek],
`nature/10-reiman-conservatory-wing-roof.jpg` [indexed description only — file
undecodable], `_pass2-review/aerial_isu.jpg`). Ada Hayden is OUTSIDE the core
(north) — skybox/fly-out target, not a build cluster (SUMMARY §3).

**PALETTE** (from `nature/05` on-disk, `nature/04-adahayden-prairie-trail.jpg`,
IMAGE_INDEX notes):

| Part | Hex est. |
|---|---|
| Ioway Creek water | `#4A4638` dark silt |
| Brookside forest canopy (late fall) | `#4E4A38` → summer `#3E5A32` |
| Park mown cores | `#7A9450` |
| Red-steel footbridge | `#8C3A2E` |
| Stone bridge abutment | `#6E675C` mossy |
| Prairie/gravel trail | `#B9A984` |
| Reiman conservatory glass (blue) | `#7FA8C9` |
| Reiman limestone sign monolith | `#C4BCA8` |

**MATERIALS & FEATURES.**

1. **Brookside Park** — dense dark oak/hackberry gallery forest along Ioway Creek,
   open mowed cores, shelters, the rust-red steel footbridge + masonry RR abutment
   (IMAGE_INDEX nature notes; on-disk `nature/05` shows the abutment detail:
   coursed stone, weep stains, dark creek water).
2. **College Creek** — the campus creek: 10.2 km mapped in core, crossing campus at
   lat ≈42.024–42.025; banks as lawn + tree rows (census §5).
3. **Reiman Gardens** — 17 ac official (V-23; OSM way 414 × 475 m); the 59 × 88 m
   blue-glass butterfly-wing-roofed OSM way (180765068, ≈2,994 m² shoelace) is the
   WHOLE "Reiman Gardens Conservatory" building (≈34,251 GSF per ISU Facilities),
   and the named **Hughes Conservatory glasshouse inside it is 465 m² (5,000 sq
   ft)**; limestone entrance
   sign monolith, seasonal giant color blocks; **entrance canopy spans UNKNOWN —
   model the sculptural wing-form canopy to look** (V-30, VERIFICATION §4). Just
   south of the core box — the SUMMARY §3 "+1.0 km south" extension exists precisely
   for this. *(QA fix 2026-11-08: "Hughes Conservatory = 59 × 88 m" split per
   QA-REPORT item 1 — following it would build the south-gate L3 set piece ~11×
   oversized; V-23's "Conservatory 59 × 88 m confirmed" is attributed to the whole
   building.)*
4. Named-park stock for dressing: Brookside 83 ac city figure (V-24 — the 96 ac OSM
   polygon includes the creek corridor; use the polygon for SHAPE, the city figure
   for any label), ISU Arboretum 11.6 ha, Stuart Smith 9.9 ha, Central Campus 8.5 ha
   (§1.4), plus 20 named in-core parks (census §5 table). Bandshell Park sits just
   outside the E edge (§1.7).

**DIMENSIONS.** Green total 267.1 ha = 25.2 % of the core; 1,860 green polygons;
5,637 individual tree nodes as scatter seeds (census §5). Ioway Creek 33.1 km of
bank/centerline in core; College Creek 10.2 km; NO South Skunk River in-core (it runs
1.4 km east — census §5, SUMMARY §7 — do not build a river inside the box).

**LOD.** Creeks `L1` spline water + bank dressing; Brookside canopy `L0` polygon
forests with scatter trees (only the footbridge/abutment get `L2`); Reiman
conservatory `L3` (the wing roof is the south-gate silhouette), gardens `L0`
color-block dressing; shelters/props `L1`.

**GAME-NATIVE.** The pigeon's actual habitat: perch stock on the footbridge rails,
shelter roofs, fence lines; splat surfaces on picnic tables and the spray-pool lip.
Breadcrumbs: the Saturday farmers market and creek-trail dog walkers (NPC herds);
the 2025 streambank-stabilization works as optional dressing. Reiman: Winter
Wonderscape's 200,000+ lights as a December event skin (TRADITIONS §7); butterfly
accents (`nature/13` on-disk macro as the prop reference — pass-2 note).

---

### 1.10 Cluster: residential-filler (the 3,175 anonymous boxes)

**SILHOUETTE.** Low-density grids of 1–2-story gable/hip-roofed houses on ~125–140 m
blocks, heavy mature tree canopy, school and church anchors; Campustown's side
streets densify to 2–4-story apartment slabs; north campus fills with 3-level
Frederiksen Court blocks
(`images/misc/03-roosevelt-school.jpg`, `campustown/03-campustown-side-street-snow.jpg`,
`_pass2-review/aerial_isu.jpg`). Instant-read test (from the air): the canopy IS the
district — roofs peek through a continuous green mat.

**PALETTE** (from `misc/03`, `campustown/03`):

| Part | Hex est. |
|---|---|
| Siding (tan/cream/gray range) | `#D8CDB4` / `#EDEAE2` / `#B7B7AD` |
| Brick accents/foundations | `#96513A` |
| Asphalt shingle roofs | `#4E4E52` (weathered) … `#3A3A3E` |
| School brick (Roosevelt typology) | `#A05238` + limestone trim `#CCC5B4` |
| Mature canopy (summer) | `#55703F` dominant |
| Side-street apartment slabs | `#8C8478` brown-gray, `#AFA9A0` |

**MATERIALS & FEATURES.** Procedural filler must be DISTRICT-DRESSED (full rules in
§3): roof pitch and material by district, setbacks by street class, the 125–140 m
block rhythm, tree-canopy density by neighborhood age. Named anchors inside the
filler (authored, from the census appendix "everywhere else" list of 155): CyRide
bus barn (7,105 m²), McFarland Clinic block (6 lv hospital), Fitch Family Aquatic
Center, Ames First United Methodist + First Christian + Ames UCC churches, the Greek
house row (26 named chapter houses, 300–1,000 m² each, south of Lincoln Way),
Frederiksen Court apartment blocks, 800 Lincoln Way, the Roosevelt-typology schools.

**DIMENSIONS.** Procedural stock: p50 footprint **127 m²**, p90 595 m²; levels
histogram — 1 lv 187 / 2 lv 158 / 3 lv 154 of 586 tagged (85 % are 1–3 lv); default
heights **1 lv ≈ 4 m, 2 lv ≈ 8 m, 3 lv ≈ 11 m, 4 lv ≈ 14 m**; towers 8–11 lv
(27–40 m) reserved for the named tall stock (census §1, §7.4–7.5). Setbacks:
residential streets 11 m default width (census §7.3); downtown/Campustown/Lincoln
Way rules per §1.5–1.7. Grid axis-aligned to true north with the named exceptions
(Sheldon 356°, Stange 12°, University Blvd curved, UP line 93.7° — SUMMARY §5).

**LOD.** `L0` everything: silhouette box + roof form + chimney prop; only lot-level
variation (shed, porch hint, driveway) breaks the repetition. The filler's budget is
DENSITY, not detail — 3,175 boxes must generate fast.

**GAME-NATIVE.** Perches: ridge lines, TV antennas, power drops, the canopy itself
(the game's most common perch surface — seed it generously). Splat surfaces: parked
sedans, mailboxes, birdbaths (rival-bird bait). Breadcrumbs: the white-squirrel
sighting blessing (TRADITIONS §6 — a rare albino-squirrel NPC in these canopies is
the lore payoff), school playgrounds at recess, church parking on Sunday mornings.
NPCs: dog walkers, lawn care, school runs.

---

## 2. The fidelity list (must-NOT-get-wrong)

The details the community will notice. Cited. Where a photo corrects a sibling lane,
the sibling is named as corrected (per the survey's photo-wins rule).

**Colors & materials**

- **F-01. Campanile brick is BUFF/TAN, not red.** Every photo
  (`campanile/02`, `campanile/03`) shows warm sandstone-tone buff brick with darker
  slots. LANDMARKS C1/§5's "slender red-brick needle" is corrected by the photos.
  The only red-brick needle habits should be unlearned — Morrill Hall (§1.4) is the
  campus's red-brick turret.
- **F-02. Memorial Union is PALE GRAY LIMESTONE with a squat square tower — NOT
  dark brick.** `laverne/02`, `campus/18`, `campus/19` contradict LANDMARKS C5's
  "huge dark-brick Georgian block" (the dossier's own guess, flagged in
  IMAGE_INDEX cluster notes). Model pale limestone.
- **F-03. Marston Water Tower's tank is WHITE/pale-gray painted steel — not a
  "dark tank"/"dark pin-cushion."** `campus/11-marston-tower-full.jpg` and
  `campus/09` show white paint with the ISU seal medallion; LANDMARKS C2's "dark"
  wording is corrected by the photos. The lattice-leg silhouette is the darker read.
- **F-04. Jack Trice field runs NORTH–SOUTH** (standard), press/institutional side
  WEST, grass hillside NE/NW, videoboard NORTH (V-09/V-11). Wikipedia never claimed
  E–W — that citation was a misquote. Capacity **61,500** (V-10).
- **F-05. The daily train is a yellow UP SD70ACe/ES44AC-led drag** with the
  blue-white winged shield (`rail/07`); double-track, concrete ties, welded rail
  (IMAGE_INDEX rail notes). Paint the loco right; it crosses town all day.

**Locations & orientation**

- **F-06. Campus is NORTH of Lincoln Way; Campustown (Welch bars) is SOUTH;**
  students cross southbound. Campustown avenues W→E: Sheldon, Hayward, Welch,
  Stanton (V-01/V-02). The MU corner is Lincoln Way & Morrill Rd/Lynn, one block
  EAST of Stanton (V-08). Downtown is 2.93 km due EAST of the MU (V-04) — not NE.
- **F-07. Main Street addresses increase WESTWARD; the 100 block is the EAST end at
  Duff.** Great Plains (129) sits near Duff/Douglas (east end); the Cornbred depot
  (526) and Aunt Maude's (547) sit at the WEST end near Clark/Pearle (V-06;
  VENUES §1.14/§2.6 corrected). Use VERIFICATION §5's W→E venue sequence.
- **F-08. Fareway:** full store at **619 Burnett Ave** (+ 3619 Stange Rd);
  **3720 Lincoln Way is a Fareway Meat Market**; **534 S Duff is the Walmart
  Supercenter** (V-15 — both LANDMARKS T4 and VENUES §5.1 corrected). Model the
  meat market on L/W as the small 2016 box; put the big-box grocery on Burnett.
- **F-09. Address direction rules:** Welch increases SOUTH (odd W/even E — V-22);
  Lincoln Way south side increases WESTWARD (V-20). Get these right and every
  venue lands on the correct block side.

**Names, dates & language**

- **F-10. Block/spacing number:** downtown Main→5th ≈ 86 m, 5th→6th ≈ 105 m
  (census §2 — SUMMARY §5's "205 m" does not reproduce). Duff Ave downtown lon is
  −93.6104 (V-05).
- **F-11. The bandshell's outer arch is dark weathered-copper patina over PALE MINT
  inner shells** (`downtown/05`, `downtown/06`) — refine IMAGE_INDEX's
  "white/pale-green scallop shell."
- **F-12. The swans are GONE (2022 fact).** Lancelot died June 20, 2022; Elaine
  retired Nov 2022 to a pond near Woodward; no replacement as of the survey
  (V-13, TRADITIONS §2). The game MAY restore them as a deliberate choice, but must
  not depict 2022–24 reality as having swans by accident. If staged "now": empty
  lake + restoration note (the lake was drained mid-2026; model the refilled lake,
  max 3.7 m — V-14).
- **F-13. The zodiac is IN the Memorial Union — floor of Gold Star Hall — NOT a
  sidewalk between Curtiss and Beardshear.** People walk AROUND it; the
  Curtiss–Beardshear pairing is the streak run, a different ritual (TRADITIONS §9.5
  correcting REDDIT-RESONANCE §3). If the MU interior is built, the bronze zodiac is
  a floor decal students dodge.
- **F-14. VEISHEA is dead and mourned** (ended Aug 7, 2014). Never stage it as
  running; memory/absence is the respectful pose (TRADITIONS §9.3). CyTown is NOT
  its successor in community sentiment (TRADITIONS §4).
- **F-15. Jack Trice naming dates:** students fought for the name from 1973; field
  formally named 1984 (informal use from the 1975 opening); statue dedicated 1988 on
  Central Campus (between Beardshear and Carver) and MOVED to the stadium in 1997
  when the stadium was renamed; 2023 centennial renamed the street Jack Trice Way
  (TRADITIONS §3 correcting LANDMARKS C6's "field = Jack Trice Field from 1975").
  Only D-I FBS stadium named for a Black man — model the statue and letter with
  dignity, never a gag (TRADITIONS §9.1).
- **F-16. Spell it "Oktoberfest" for Ames (Main Street, 200 block).**
  "Oktemberfest" with the T is Marshalltown's, 45 minutes east (TRADITIONS §7).
  801 Day is named for the 8:01 a.m. Greek recruitment-rule lifting — NOT an area
  code or highway (TRADITIONS §7).
- **F-17. Campaniling:** midnight + under the Campanile = a true Iowa Stater; the
  documented folklore is jelly beans/lemon drops; the paddling legend is
  undocumented chatter — in-world rumor only, never ISU's rule (TRADITIONS §9.2).
- **F-18. "Cyclone" is 1895 weather-history pride; cardinal & gold and Cy (1954)
  are the town's visual grammar** — every banner, awning and seat field (TRADITIONS
  §9.6). VEISHEA's cherry pies are a 1919-origin fundraiser worth a ghost prop.

**States of the world**

- **F-19. The East Gateway pedestrian bridge ("Cy Walk") over University Blvd is
  OPEN (since ~2024)** — build it as standing infrastructure, not construction
  (V-17). The Welch Ave reconstruction (2025–26) and Fire Station 2's move to State
  Ave: model the completed Welch streetscape (VENUES §0).
- **F-20. No Amtrak node exists in OSM and the yard is NOT a hump yard** — the depot
  is 1906 C&NW scenery, the line is a double-track freight through-line with a short
  local lead (SUMMARY §8, LANDMARKS T6). The famous "Big Boy through Ames" shots
  (`rail/04`–`06`) are a 2019 excursion — one-off special, not the daily consist.
- **F-21. UNKNOWN-model-to-look items — do not invent numbers:** MU tower height
  (placeholder ≈35–45 m UNVERIFIED; never ~148 ft), Reiman canopy spans, grain-
  elevator heights (30–40 m placeholder), tailgate lot names (use generic lots)
  (VERIFICATION §4/§6).
- **F-22. No South Skunk River in-core** (1.4 km east of the box) and Ada Hayden is
  north-outside: build creeks and Lake LaVerne, not a river town (census §5).
- **F-23. South Skunk/Ioway naming:** Ioway Creek is confirmed renamed (zero
  "Squaw Creek" waterways — SUMMARY §7); use Ioway everywhere.
- **F-24. Venue churn:** business names rot fast (Es Tas evicted Dec 2024 → The Stan
  Tap; Little Taipei closed Oct 2024; Macubana closing as of Sept 2026; Mary Jane's
  replaced the Angry Irishmen in 2026). Model BUILDINGS as constants, signage as
  eras; re-verify any venue name before baking it in (VENUES §6/§7).

---

## 3. District dressing rules (the procedural filler's per-district look)

Constants for the generator (census §7 parameter sheet is the numeric source; the
photos set the texture):

1. **Block rhythm:** 125–140 m centerline-to-centerline on both downtown Main and
   Lincoln Way; downtown cross-street gaps W→E 115/63/214/122/139/133/138 m;
   Campustown L/W south side State→Hyland 295 / Hyland→Sheldon 112 / Sheldon→Hayward
   204 / Hayward→Welch 134 / Welch→Stanton 136 (census §2, §7.1–7.2). Grid
   axis-aligned to true north; visible exceptions only where named (SUMMARY §5).
2. **Downtown rows (Main/5th/6th):** continuous 1880s–1920s masonry wall — flat
   roofs, parapets, cornice band; 2–3 stories (p50 footprint 246 m²); setback a hard
   12.4 m from the Main centerline (≈6 m from the curb), no parking lagoons;
   materials: dark-to-mid brick `#8A4A36`–`#A8663F` + painted-concrete cream; maroon
   furniture + blue AMES banners; angled parking on Main (`downtown/01`). Second-row
   (5th/6th) may loosen one setback class.
3. **Campustown strip:** 2–3-story cinderblock/brick storefronts, p50 294 m², mixed
   setbacks (p50 16.6 m, allow 2 buildings at 0.2 m — the Cy's Roost condition);
   4–10-level student towers behind (Legacy/23 Twenty/Foundry/Union on L/W style);
   deeper L/W frontage (p50 20.7 m) with parking rows in front of the 2010s infill;
   vintage black lampposts with hanging globes; illuminated box signs
   (`campustown/01`, `campustown/03`).
4. **Lincoln Way corridor (outside Campustown):** four-lane primary (20 m), mast-arm
   signals, set-back ONE-story retail behind pole/pylon signs, parking aprons, motels,
   car lots; wooden utility poles + wire on the S Duff stretch (`lincolnway/01`,
   `lincolnway/02`). This is a STRIP, not a wall — the anti-downtown.
5. **S Duff south of Lincoln Way:** widest asphalt, big-pole signs, chain boxes and
   grocery anchors (Walmart 534, ALDI — no Hy-Vee on S Duff; Ames's two Hy-Vees are
   3800 Lincoln Way and 640 Lincoln Way), auto row; far-south
   transition to the airport-side fields. *(QA fix 2026-11-08 per QA-REPORT item 2.)*
6. **Residential grids:** 1–2-story gable/hip houses, p50 127 m², 11 m streets;
   materials by era/neighborhood: tan/cream/gray siding + brick accents, asphalt
   shingle roofs `#4E4E52`; mature canopy denser west and north (the aerial shows
   canopy dominant over roofs); schools = Roosevelt typology (2-story brick, window
   bands, `misc/03`); churches as steeple anchors on corner lots. Greek row south of
   Lincoln Way: bigger 2–3-story brick houses on generous lots (census appendix
   300–1,000 m²).
7. **Campus-in-green rule (applies everywhere near ISU):** buildings nestle in
   tree canopy — the aerial (`_pass2-review/aerial_isu.jpg`) shows roofs poking
   through a continuous mat; never bare-ground campus. Buff/tan + pale limestone
   palette for the classical rows, dark-red brick for Morrill/Farm House-era,
   1950s–80s glass-and-concrete for the additions; rooflines: flat + mechanical
   screens, occasional copper-green or slate accent.
8. **Parking stock:** 480 lots, 73.6 ha (7 % of core) — sprinkle honestly; the
   Iowa State Center's 19 tailgate lots (8.9 ha) are the biggest dressed fields
   (census §3).
9. **Trees:** 5,637 mapped nodes are scatter SEEDS, not an inventory; polygon woods
   (Brookside 38.9 ha OSM, Pammel 16.1 ha) carry the mass (census §5).
10. **Heights cap:** procedural towers are FORBIDDEN — the skyline belongs to
    Marston (51.2 m), the Campanile (33.5 m), Legacy Tower/University Towers/
    Wilson-Wallace (10–11 lv, 27–40 m), the ISU Power Plant stack (suspect 100 m tag
    — treat as the stack, not the mass) and the SE grain elevators (census §1).

---

## 4. Build-order recommendation (recognition per effort)

Driven by the from-the-air ranking (LANDMARKS §5, confirmed by VERIFICATION §5's
orientation fixes) crossed with mesh cost. "Air recognition" = what a pigeon-cruise
altitude actually reads.

| Order | Cluster | Why now |
|---|---|---|
| **1** | **stadium+tailgates** | Top-2 air-reads in one cluster (bowl + Hilton drum, LANDMARKS §5 #1–2), cheap geometry (concrete bowl + polygonal drum + lot splats), and it anchors the whole sports campus. |
| **2** | **lake-laverne** | #3 air-read; the cheapest high-value shape in the build (one authored water oval + one L2 limestone mass + tower crown). Fixes MU-at-Morrill-corner early so the campus grid starts true. |
| **3** | **campanile + Central Campus lawn** | #4 + #5 — the lawn is the biggest single open shape in town (get its rectangle right and campus reads instantly, LANDMARKS C12); the tower is a small L3 mesh with outsized silhouette value. |
| **4** | **campus-buildings** | Fills the quad: Beardshear dome (#7), Marston tower (#6), MU mass (#8), Parks block (#9). The census §3 top-30 dims table is the massing sheet; L1 boxes for the tail. |
| **5** | **rail-corridor** | #12 air-read and the town's motion landmark: spline track + one train asset (yellow SD70ACe + hopper chain, `rail/07`) reused across the 9 at-grade downtown crossings; depot L3 is small. |

Then: **6** campustown-venues (ground-level recognition — the "alum finds Welch Ave
Station" test; clock tower L3 + sign bands), **7** downtown-main-street (#13; the
procedural wall + bandshell L3), **8** lincolnway-corridor (the wide-spine contrast;
mostly L1 + props), **9** water-green (creeks + Brookside canopy + Reiman gate if the
box extends south), **10** residential-filler (pure procedural; lands last because
its look depends on the district rules hardened by clusters 1–9).

Rationale for campus-before-strips: the authored budget should be spent campus-first
(152 named buildings, 38.3 ha — 57 % of the authored footprint, census §6; QA fix
2026-11-08: "a third" was of the TOTAL building footprint, 120.7 ha — per QA-REPORT
item 9), then
the two district rows, then the named scatter.

---

## 5. Provenance

**Inputs (read-only):** `verification/VERIFICATION.md` (V-nn), `census/BUILD-CENSUS.md`
(+ `census/authored-buildings.csv`), `images/IMAGE_INDEX.md` + per-cluster
`CREDITS.md`, `landmarks/LANDMARKS.md`, `venues/VENUES.md`,
`community/TRADITIONS.md`, `osm/SUMMARY.md`, and the photo files cited per cluster
above (83 indexed images + 10 pass-2 `_pass2-review/` extras; 2 files undecodable —
noted in the header).

**Corrections made here under the photo-wins rule:** F-01 (campanile buff, corrects
LANDMARKS C1/§5), F-02 (MU pale limestone, corrects LANDMARKS C5), F-03 (Marston
white tank, corrects LANDMARKS C2), F-11 (bandshell arch patina, refines IMAGE_INDEX),
plus the header note on pass-2 filename re-cuts in `nature/` and `campus/`.
Text-vs-text corrections are carried from VERIFICATION.md only (V-01…V-30) and
flagged at point of use — this file edits no sibling.

**Companion docs:** dimension ground truth and dispute verdicts live in
`verification/VERIFICATION.md`; generator constants in `census/BUILD-CENSUS.md` §7;
traditions and game hooks in `community/TRADITIONS.md`; venue operations and
addresses in `venues/VENUES.md`.

*Modeling-specs lane, 2026-11-08.*

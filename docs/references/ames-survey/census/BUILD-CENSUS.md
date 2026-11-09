# Ames Survey — Build Census (what is actually inside the game-core box)

Date-stamped: **2026-11-08**. Role: the build-census lane of the Ames survey. This file
measures what is physically inside the proposed game-core bbox — buildings, blocks,
streets, intersections, green, water, rail — so the master plan can split **authored
landmarks** from **procedural filler**.

**Input:** the sibling OSM extract `../osm/raw/ames_merged.json` (309,870 nodes /
37,531 ways / 251 relations, pulled 2026-11-08; nodes carry no tags, so tagged-node
queries re-scan the 42 raw tiles via a cache). **Script:** `scripts/ames_census.py`
in this directory, run `python -I ames_census.py <mode>`; every number below names
its mode. Machine outputs of each run are kept as `scripts/_out_<mode>.txt`.
**Cross-reads:** `../osm/SUMMARY.md` (core bbox, street facts), `../venues/VENUES.md`
(Tier 1–2 list), `../verification/VERIFICATION.md` (ground truth — orientation,
address rules, settled dimensions; used throughout).

**Definitions (all modes):**

- **Core bbox** = `W −93.6590, S 42.0120, E −93.6100, N 42.0355` (the game-core box
  from SUMMARY §3; 4,053 m E–W × 2,610 m N–S ≈ 10.58 km²).
- A **building is "in core"** when its footprint **bbox centroid** falls inside the
  box (primary definition). "Touches core" (≥1 node inside) is also reported —
  see the reconciliation note in §1.
- **Area** = planar shoelace on `m_per_deg_lat = 111,074`, `m_per_deg_lon(lat) =
  111,320·cos(lat)` (≈82,650 m/° at Ames) — consistent within <0.3 % with the
  sibling SUMMARY's 82,700 figure.
- **Road length in core** sums only segments whose **midpoint** is inside the box.
- **Intersection degree** = number of distinct road ways meeting at a node (OSM
  splits ways at junctions; downtown/Campustown OSM data is well-split).

---

## 1. Building census for the core bbox

*Source: `ames_census.py buildings` (+ `cache` for tagged nodes).*

**Headline:** **3,737 buildings** inside the core — **3,724** building ways +
**13** building relations. (Reconciliation: 3,754 building ways have ≥1 node in the
core; the sibling SUMMARY's "3,733 buildings" sits between the centroid (3,737 incl.
relations) and any-node (3,754) definitions — the three numbers agree within 0.5 %.)

| Metric | Value |
|---|---|
| Buildings (centroid-in-core) | **3,737** |
| …with a `name` tag | **512 (13.7 %)** |
| …with `building:levels` | **586 (15.7 %)** |
| …with `height` (m) | 175 (4.7 %) |
| …with either | 593 (15.9 %) |
| Total footprint area | **1.207 km² = 120.7 ha = 11.4 % of the core** |
| Footprint m²: p10 / p50 / p90 / max | 53 / 127 / 595 / 21,413 |
| Open (unclosed) building ways | 0 |

**`building:levels` histogram (586 tagged buildings)** — this decides the generator's
default heights: 85 % of tagged buildings are 1–3 levels; only 25 buildings (0.7 %
of all) reach 6+.

| levels | count | | levels | count |
|---|---|---|---|---|
| 1 | 187 | | 6 | 9 |
| 2 | 158 | | 7 | 5 |
| 3 | 154 | | 8 | 4 |
| 3.5 | 1 | | 9 | 2 |
| 4 | 44 | | 10 | 3 |
| 5 | 17 | | 11 | 2 |

Tagged `height` stats: min 3.5 m, p50 20 m, p90 40 m, max 100 m (the max is the ISU
Power Plant's way tag `height=100`, levels=10 — almost certainly the stack, not the
building mass; treat as suspect). Tallest stock (levels ≥ 6, 25 buildings) is led by:
Wilson & Wallace Residence Halls (11 lv, h=40), Legacy Tower (10, 40), University
Towers (10, 27), ISU Power Plant (10, 100?), Buchanan Hall (9, 27), Cyclone Plaza
(9, 40), Geoffroy Hall (8, 30), Willow/Larch/Maple Halls (8, 37.5), 23 Twenty Lincoln
(7, 26), Campus Flats (7), Ross Hall (7, 70 — includes its tower), Science II (7, 70).

**Top 25 largest footprints in the core** (name, centroid, area):

| ha | name | center | OSM |
|---|---|---|---|
| 2.141 | Jack Trice Stadium | −93.63573, 42.01380 | way/613735866 |
| 1.547 | Lied Recreation Center | −93.63721, 42.02659 | way/33726001 |
| 1.233 | Hilton Coliseum | −93.63477, 42.02100 | way/180651868 |
| 1.121 | (unnamed) hospital — McF. clinic block | −93.61202, 42.03271 | rel/11700175 |
| 0.940 | Bergstrom Indoor Training Facility | −93.63812, 42.01543 | way/1052515109 |
| 0.906 | Friley Residence Hall | −93.65122, 42.02394 | way/158023222 |
| 0.891 | Memorial Union | −93.64576, 42.02367 | way/183224150 |
| 0.859 | Forker Building | −93.64028, 42.02673 | way/162993229 |
| 0.787 | State Gymnasium | −93.65326, 42.02463 | way/183224403 |
| 0.757 | ISU Power Plant | −93.63949, 42.02779 | way/183191045 |
| 0.729 | Parks Library | −93.64883, 42.02813 | way/33725897 |
| 0.711 | CyRide (bus barn) | −93.63520, 42.02792 | way/183344075 |
| 0.699 | Hy-Vee (640 Lincoln Way) | −93.61962, 42.02002 | way/98658304 |
| 0.684 | (unnamed) commercial, N Downtown | −93.61813, 42.02166 | way/98658325 |
| 0.660 | General Services Building | −93.64075, 42.02807 | way/183191043 |
| 0.653 | Howe Hall | −93.65307, 42.02683 | way/183218202 |
| 0.648 | Kildee Hall | −93.64379, 42.02957 | way/183200718 |
| 0.640 | Agronomy Hall | −93.64264, 42.02834 | way/183187995 |
| 0.622 | Food Sciences Building | −93.64268, 42.02685 | rel/2507887 |
| 0.612 | Scheman Building | −93.63672, 42.02150 | way/180649660 |
| 0.605 | (unnamed) parking garage | −93.61234, 42.03175 | way/312090985 |
| 0.562 | Beyer Hall | −93.65294, 42.02588 | way/158023212 |
| 0.559 | Gilman Hall | −93.64858, 42.02943 | way/183214584 |
| 0.543 | East Parking Deck (campus) | −93.64274, 42.02546 | way/183319697 |
| 0.515 | Ames City Hall | −93.61775, 42.02636 | rel/2560369 |

*20 of the 25 are ISU campus buildings — the campus owns the big-footprint stock.*

*(QA fix 2026-11-08 per QA-REPORT item 2 / B-04: way 98658304 is Hy-Vee "Lincoln
Center" at **640 Lincoln Way** near Grand (its addr tags) — the old "(S Duff)" label
was wrong; no Hy-Vee is on S Duff. Ames's other full Hy-Vee is **3800 Lincoln Way**
(way 186660819, 0.784 ha).)*

---

## 2. The two authored districts

*Source: `ames_census.py districts` (polygon membership = ray-cast inside the
`landuse=commercial` polygons; block cells = measured street centerlines).*

### Downtown (Main Street blocks)

Landuse polygon `Downtown` (way **918949337**): **995 × 411 m**, center
(−93.61652, 42.02605). **158 buildings** with centroid inside (113 named, 71 %);
total footprint **7.27 ha**; p50 footprint 246 m², p90 836 m².

Measured cross-street centerlines (mean lon of the street's nodes in the downtown
band) and **per-block building counts along the Main Street band** (lat
42.02388…42.02628 — wide enough to include both Main and 5th frontage rows; 5th St
is NORTH of Main here, see below):

| block (W→E) | gap | buildings | p50 m² |
|---|---|---|---|
| Northwestern Ave → Grand Ave | 115 m | 7 | 529 |
| Grand Ave → Pearle Ave | 63 m | 1 | 432 |
| Pearle Ave → Clark Ave | 214 m | 19 | 219 |
| Clark Ave → Burnett Ave | 122 m | 12 | 544 |
| Burnett Ave → Kellogg Ave | 139 m | 29 | 398 |
| Kellogg Ave → Douglas Ave | 133 m | 33 | 207 |
| Douglas Ave → Duff Ave | 138 m | 38 | 181 |

N–S spacing (measured centerline-to-centerline): **Main→5th ≈ 86 m** (matches
SUMMARY's "tight ≈ 80 m"); **5th→6th ≈ 105 m**. ⚠ SUMMARY §5 says "5th → 6th ≈ 205 m"
— that does not reproduce from the extract (5th sits at lat ≈ 42.0258–42.0259, 6th at
≈ 42.0268–42.0270 across the whole downtown band); use ≈105 m.

**Setback character:** distance from each building's outline to the Main Street
centerline (92 buildings within 60 m): **min 9.5 m, p25 11.7, p50 12.4, p75 12.6,
max 48.5**. Downtown storefronts sit a hard ~12 m off the centerline (≈6 m from the
curb) — a continuous 1880s–1920s commercial wall with no parking lagoons.

### Campustown (south of Lincoln Way, Sheldon→Stanton)

Landuse polygon `Campustown` (way **918491523**): **748 × 269 m**, center
(−93.65101, 42.02150). **71 buildings** inside (38 named); footprint **4.14 ha**;
p50 294 m², p90 1,361 m².

Measured centerlines and **per-block counts along the Lincoln Way south frontage**
(lat 42.02117…42.02257). Note: Howard and Campus Avenues exist in OSM only NORTH of
Lincoln Way, so the south-side strip really is: State → Hyland (one long block),
Hyland → Sheldon, Sheldon → Hayward, Hayward → Welch, Welch → Stanton:

| block (W→E) | gap | buildings | p50 m² |
|---|---|---|---|
| State Ave → South Hyland Ave | 295 m | 67 | 93 |
| South Hyland Ave → Sheldon Ave | 112 m | 7 | 323 |
| Sheldon Ave → Hayward Ave | 204 m | 7 | 321 |
| Hayward Ave → Welch Ave | 134 m | 28 | 224 |
| Welch Ave → Stanton Ave | 136 m | 18 | 301 |

The State→Hyland "block" carries 67 buildings at p50 only 93 m² — that is the
back-of-strip fabric (parking, small commercial sheds) behind the Lincoln Way
storefronts; the Welch and Hayward frontage rows are the dense bar blocks.

**Setback character:** to the **Welch Ave centerline** (39 buildings within 50 m):
min 0.2 m (!), p25 10.8, **p50 16.6**, p75 23.6, max 43.2 — the bar strip is built
hard to the sidewalk in places (Cy's Roost), looser toward Hunt. To the **Lincoln Way
centerline, south side** (54 buildings within 60 m): min 9.7, p25 11.3, **p50 20.7**,
p75 38.3, max 49.3 — the L/W frontage is deeper-set than downtown Main (parking rows
in front of the 2010s infill).

### Venue anchor cross-check (VENUES.md Tier 1–2)

*Source: `ames_census.py venues` (name-normalized match on building ways, POI ways
and cached tagged nodes; addr match on `addr:housenumber` + `addr:street`).*
Address rules per VERIFICATION §3/§5 (odd=W/even=E on Welch; addresses increase
southward on Welch, westward on L/W south side and on Main).

**Result: 26 of 31 Tier-1/2 venues have an in-core OSM anchor; 3 are anchored but
outside the core box (Hickory Park S, The Cafe N, Provisions S); 1 has no anchor; 1
is a cart.** *(QA fix 2026-11-08: "2 are anchored but outside" → 3 per QA-REPORT
item 9 / B-09 — the old sentence dropped Provisions; §7.7's list of 3 is right.)*
No Tier-1 position was
contradicted (consistent with VERIFICATION §3's 10/10 spot-check).

Tier 1 (14):

| venue | VENUES address | OSM anchor | in core |
|---|---|---|---|
| Welch Ave Station | 207 Welch | ⚠ addr node 2531586094 (−93.65058, 42.02107) — node is named "Pizza Pit" (same building); **the venue name is not in OSM** | yes |
| Paddy's Irish Pub | 124 Welch | node 1941751171 amenity=bar (−93.64992, 42.02173) + addr node | yes |
| Cy's Roost | 121 Welch | **exact**: way 241365820, amenity=bar, 2 lv, (−93.65046, 42.02195) | yes |
| Sips | 126 Welch (Paddy's basement) | node 8530394477 (−93.64974, 42.02173) | yes |
| Mickey's Irish Pub | 109 Welch | node 2531586091 amenity=pub (−93.65033, 42.02236) + addr | yes |
| AJ's Ultra Lounge | 2401 Chamberlain | **exact**: way 246079558, 3 lv, (−93.64878, 42.02156) | yes |
| Outlaws | 2522 Chamberlain | **exact**: way 272522425, 2 lv, (−93.65124, 42.02123) | yes |
| Café Beaudelaire | 2504 Lincoln Way | node 2400994656 amenity=cafe (−93.65043, 42.02260) + addr | yes |
| Jeff's Pizza Shop | 2402 Lincoln Way | node 2447728161 amenity=restaurant (−93.64872, 42.02260) + addr | yes |
| Mr. Burrito | 2508 Lincoln Way | addr node 2531586092 (−93.65051, 42.02260) | yes |
| Superdog | 208 Welch (cart) | **none — it's a cart**: model as a prop anchored at the BNC curb | n/a |
| Hickory Park | 1404 S Duff | **exact**: way 196541966 (−93.60954, 42.01002) — **220 m SOUTH of the core edge** | no (S) |
| The Cafe | 2616 Northridge Pkwy | node 1292348200 (−93.64366, 42.04874) — **~1.5 km north of the core edge** | no (N) |
| Great Plains Sauce & Dough | 129 Main | **exact**: way 237834149 (−93.61182, 42.02537) | yes |

Tier 2 (17):

| venue | address | OSM anchor | in core |
|---|---|---|---|
| Mother's Pub & Coffee | 2900 West St | **exact**: way 251728629 (−93.65726, 42.02518) | yes |
| Thumbs | 2816 West St | **exact**: way 251728624, 1 lv (−93.65652, 42.02515) | yes |
| West Street Deli | 2810 West St | **exact**: way 251728626 (−93.65624, 42.02517) | yes |
| BNC Field House | 206 Welch | **exact**: way 241365816 (−93.64966, 42.02120) | yes |
| Blue Owl Bar | 223 Welch | node 2445161035 "The Blue Owl Bar" (−93.65036, 42.02040) | yes |
| Cornbred Barbecue | 526 Main (depot) | node 8395552560 (−93.61828, 42.02446) + addr | yes |
| Whiskey River | 134 Main | **exact**: way 269752175 (−93.61184, 42.02495) | yes |
| London Underground | 212 Main | **exact**: way 269752154 (−93.61247, 42.02492) | yes |
| Time Out | 120 Kellogg | **exact**: way 236565187 (−93.61325, 42.02380) | yes |
| The Mucky Duck Pub | 3100 S Duff | **NO OSM ANCHOR anywhere in the extract** (and 3100 S Duff is far south of the core anyway) | no |
| Torrent Brewing | 504 Burnett | **exact**: way 931902030 (−93.61509, 42.02639) | yes |
| Aunt Maude's | 547 Main | node 5064244865 (−93.61907, 42.02522) + addr | yes |
| The Grove Cafe | 124 Main | **exact**: way 269752153 (−93.61154, 42.02497) | yes |
| Provisions Lot F | 2400 N Loop Dr | **exact**: way 846310912 (−93.63569, 42.00052) — outside (S research park) | no (S) |
| The Stan Tap | 216 Stanton | addr way 273536249, 3 lv residential (**unnamed** — the ex-Es Tas building) | yes |
| Sam's Place | 125 Main | **exact**: way 237834143 (−93.61170, 42.02539) | yes |
| Lost and Found Lounge | 121 Welch (upper) | shares Cy's Roost way 241365820 | yes |

**Tier-1 venues with NO OSM anchor: only Superdog** (by design — a cart; hand-place
the prop at the 200-block east curb, across from Kum & Go way 231767147). Two Tier-1
anchors need a boundary decision: **Hickory Park** (0.9 ha site, 220 m south of the
S edge) and **The Cafe** (1.5 km north) — either extend the box or ship them as
fiction-adjacent fill. Also flag: the **Welch Ave Station building carries no venue
name in OSM** — attach the name to the 207-Welch building by hand.

---

## 3. Campus inventory

*Source: `ames_census.py campus` + polygon follow-up in `scripts/_out_campus.txt`.
Campus membership = building tag in {university, dormitory, stadium} OR centroid
inside ISU relation 3501275's outer rings (the relation's 12 rings are spotty — they
miss the MU and the Union Drive residence halls — hence the tag-based OR).*

**Campus buildings in core: 193, of which named: 152** (footprint total 38.3 ha).
Named mix: 19 dormitories, ~48 `building=university` academic, 6 stadium-tagged
(Jack Trice bowl + endzone + 4 concessions/press boxes).

**30 biggest named campus buildings** (footprint, bbox, levels):

| name | m² | bbox m | center | lv | OSM |
|---|---|---|---|---|---|
| Jack Trice Stadium | 21,413 | 183×208 | −93.63573, 42.01380 | — | way/613735866 |
| Lied Recreation Center | 15,468 | 156×126 | −93.63721, 42.02659 | 3 | way/33726001 |
| Hilton Coliseum | 12,334 | 138×105 | −93.63477, 42.02100 | 5 | way/180651868 |
| Bergstrom Indoor Training Facility | 9,401 | 92×135 | −93.63812, 42.01543 | — | way/1052515109 |
| Friley Residence Hall | 9,060 | 192×207 | −93.65122, 42.02394 | 5 | way/158023222 |
| Memorial Union | 8,913 | 110×110 | −93.64576, 42.02367 | 6 | way/183224150 |
| Forker Building | 8,591 | 133×86 | −93.64028, 42.02673 | 3 | way/162993229 |
| State Gymnasium | 7,866 | 143×122 | −93.65326, 42.02463 | 3 | way/183224403 |
| ISU Power Plant | 7,567 | 107×99 | −93.63949, 42.02779 | 10 | way/183191045 |
| Parks Library | 7,290 | 95×123 | −93.64883, 42.02813 | 5 | way/33725897 |
| General Services Building | 6,604 | 86×105 | −93.64075, 42.02807 | 2 | way/183191043 |
| Howe Hall | 6,526 | 170×67 | −93.65307, 42.02683 | 3 | way/183218202 |
| Kildee Hall | 6,480 | 94×113 | −93.64379, 42.02957 | 4 | way/183200718 |
| Agronomy Hall | 6,399 | 144×86 | −93.64264, 42.02834 | 4 | way/183187995 |
| Food Sciences Building | 6,221 | 124×79 | −93.64268, 42.02685 | 3 | rel/2507887 |
| Beyer Hall | 5,620 | 94×75 | −93.65294, 42.02588 | 3 | way/158023212 |
| Gilman Hall | 5,590 | 85×88 | −93.64858, 42.02943 | 4 | way/183214584 |
| Molecular Biology Building | 4,870 | 77×83 | −93.64968, 42.03110 | 5 | way/183207520 |
| Lagomarcino Hall | 4,660 | 75×121 | −93.64539, 42.02981 | 3 | rel/2507889 |
| Town Engineering Building | 4,596 | 80×88 | −93.65274, 42.02955 | 5 | way/158023277 |
| Stephens Auditorium | 4,582 | 74×96 | −93.63801, 42.02021 | 5 (h=35) | way/180654356 |
| Gerdin Business Building | 4,469 | 82×82 | −93.64429, 42.02531 | 3 | way/158023223 |
| Physics Hall | 4,450 | 56×86 | −93.64735, 42.02943 | 2 | way/183214402 |
| Armory | 4,439 | 63×72 | −93.65094, 42.02964 | 2 | way/162986350 |
| Black Engineering | 4,295 | 103×75 | −93.65106, 42.02601 | 4 | way/183217314 |
| Coover Hall | 4,129 | 90×63 | −93.65100, 42.02841 | 4 | rel/14386885 |
| Bergstrom Football Complex | 3,980 | 52×125 | −93.63727, 42.01545 | 2 | way/1052515108 |
| Seed Science Building | 3,794 | 75×54 | −93.64219, 42.02932 | 3 | rel/14386886 |
| Student Innovation Center | 3,793 | 63×64 | −93.65132, 42.02723 | 5 | way/499168444 |
| Ames Lab – Metals Development | 3,698 | 73×58 | −93.64860, 42.03099 | 2 | way/183207516 |

(Also named and campus-tagged, below the top-30 cut: Beardshear Hall 2,151 m²,
Curtiss Hall 2,174 m², MacKay Hall 2,726 m², Morrill Hall 763 m², Farm House Museum
314 m², Marston Water Tower 151 m², Campanile 45 m² — the whole VERIFICATION §5
central-campus set is anchored.)

**Campanile — exact coordinates:** building way **183041212** `name=Campanile`,
`building=university`, `man_made=tower`, `tower:type=bell_tower`,
`tower:construction=brick`, `height=34`, bbox center **(−93.64604, 42.02543)**,
footprint **6.8 × 6.7 m** (45 m²), 1 tagged level. (Height tag 34 m agrees with the
settled 33.5 m / 110 ft from LANDMARKS C1.) The CyRide stop node named "Campanile"
(node 8699270338, highway=bus_stop) sits 87 m SW at (−93.64613, 42.02465) — not the
tower. Note for landmarks: OSM also has unrelated "Reiman Campanile" (way 840743159)
and "Penkhus Campanile Garden" (way 479976955) at Reiman Gardens, 1.6 km south —
don't confuse them.

**Jack Trice + Hilton footprints** (re-measured; agrees with VERIFICATION §5):

- Jack Trice Stadium bowl: way 613735866, bbox **183 × 208 m** (long axis N–S),
  shoelace **21,413 m²** — the largest building footprint in the core.
  Fenced relation 11545732: bbox **234 × 303 m**. Inner pitch "MidAmerican Field"
  way 101135481: **53 m E–W × 113 m N–S** (V-09 settled N–S). Sukup Endzone way
  613735869 (2,089 m²) closes the south; press tower west (way 183039624).
- Hilton Coliseum: way 180651868, bbox **138 × 105 m**, area **12,334 m²**, 5 lv.

**Parking-lot census** (`amenity=parking` areas, centroid in core): **480 areas,
73.6 ha total** — 7.0 % of the core box is parking lot. Biggest single lots: 2.31 ha
(campus permit lot, −93.63749, 42.02416), 1.62 ha (Molecular Biology lot), 1.54 ha
(SE Rec Complex), 1.51 ha (north campus), 1.50 ha ( Wallace-Wilson area), 1.50 ha
(Jacobson build-up lot). **Iowa State Center tailgate zone** (lat < 42.0225, lon
−93.6445…−93.6260): **19 lots, 8.9 ha** mapped as amenity=parking — the game's
tailgate stock; note gameday overflow parking also uses the Lied Rec / grass fields
(not tagged as parking in OSM).

---

## 4. Street & intersection stock

*Source: `ames_census.py streets` (segments with midpoint in core; signals/crossings
from the tagged-node cache).*

**Road length inside the core by `highway` class:**

| class | km | | class | km |
|---|---|---|---|---|
| footway | 191.75 | | pedestrian | 10.65 |
| service | 123.19 | | **primary** | **10.01** |
| **residential** | **48.66** | | unclassified | 4.05 |
| cycleway | 28.07 | | proposed | 1.07 |
| **secondary** | **16.31** | | steps | 1.05 |
| path | 13.68 | | platform | 0.79 |
| **tertiary** | **13.07** | | track | 0.26 |

**Drivable total (motorway…residential + living_street): 92.1 km, 91.9 km of it
named.** The walkable network (footway + pedestrian + steps ≈ 203 km) is more than
twice the drivable network — that is the pigeon-perch infrastructure. OSM carries no
lane/width detail for Ames (SUMMARY §10 caveat): generator widths must be defaults.

**Intersections by way-degree** (nodes where ≥3 road ways meet; OSM splits ways at
junctions so degree ≈ arm count):

| window | intersections | 3-way | 4-way | 5-way |
|---|---|---|---|---|
| Downtown (Clark…Duff, Main…6th, 0.46×0.50 km) | **20** | 14 | 6 | 0 |
| Campustown (State…Stanton, LW…Hunt) | **13** | 6 | 6 | 1 |
| whole core | 143 | 93 | 45 | 5 |

Downtown's grid is 3-way-dominated (Pearle/Walnut/Gilchrist/Sherman T into the
spines); Campustown's Lincoln Way strip is evenly split 3/4-way with one 5-way
(the Lincoln Way × Welch/Chamberlain cluster).

**Signalized crossings** (`highway=traffic_signals` nodes): **78 in core** — only
6 in the downtown window and 8 in the Campustown window (the L/W × State/Sheldon/
Hayward/Welch/Stanton set); the rest are campus/Duff/Grand corridors.
**Pedestrian crossing nodes** (`highway=crossing`): **1,801**, of which 126 are
signal-controlled — the crosswalk machine's stock.

---

## 5. Green & water

*Source: `ames_census.py green` (+ named-park follow-up in `scripts/_out_green.txt`).*

**Green areas** (`leisure=park|garden`, `natural=wood|scrub`,
`landuse=recreation_ground|forest|grass|meadow|village_green`, centroid in core):
**1,860 polygons, 267.1 ha total = 25.2 % of the core**. The 20 **named**
park/garden ways in core:

| ha | park | center | OSM |
|---|---|---|---|
| 38.931 | Brookside Park (Ioway Creek forest; city figure 83 ac incl. creek corridor, V-24) | −93.63115, 42.03049 | way/44806238 |
| 11.619 | ISU Arboretum | −93.65668, 42.01913 | way/183766534 |
| 9.897 | Stuart Smith Park | −93.63121, 42.01956 | way/1091918442 |
| 8.548 | Central Campus (the quad lawn; V-25 ~8.3 ha) | −93.64619, 42.02648 | way/486943973 |
| 4.828 | Ioway Creek Park | −93.62332, 42.01622 | way/1085452407 |
| 1.391 | O'Neil Park | −93.62449, 42.01986 | way/1107155947 |
| 1.226 | Richardson Court Park | −93.64042, 42.02401 | way/486944924 |
| 0.738 | Community Gardens | −93.62468, 42.01659 | way/917669106 |
| 0.565 | Schainker Plaza (downtown) | −93.61650, 42.02638 | way/1091346806 |
| 0.544 | Roosevelt Park | −93.62287, 42.03074 | way/1018566234 |
| 0.417 | Anderson Sculpture Garden | −93.64834, 42.02690 | way/845202104 |
| 0.243 | Duff Park | −93.61113, 42.03547 | way/183898439 |
| 0.205 | Old Town Park | −93.61180, 42.03003 | way/256860737 |
| 0.132 | Emma McCarthy Lee Park (access) | −93.65852, 42.02844 | way/927852534 |
| 0.102 | Greek Triangle | −93.64318, 42.02035 | way/845848098 |
| 0.084 | Ames Veterans Memorial | −93.61990, 42.02601 | way/1106240549 |
| 0.083 | Tom Evans Plaza / Park (two ways, one plaza) | −93.61536, 42.02480 | way/1532311777 |
| 0.020 | Campustown Court | −93.64995, 42.02133 | way/919933059 |
| 0.013 | Seating Area (Campustown) | −93.65642, 42.02000 | way/1047737417 |

Biggest **unnamed** green: Pammel Woods 16.1 ha (−93.65202, 42.03243), an 11.4-ha
wood at (−93.63223, 42.03223) plus a chain of Ioway Creek corridor woods and grass
swales. **⚠ Bandshell Park** (LANDMARKS T2, the downtown landmark with the 1934
shell): way 1104127122 centers at **−93.60960, 42.02649 — ~30 m EAST of the core's
east edge** (it fronts East 5th St across Duff). Decide: widen the E edge by ~50 m
or hand-place it at the boundary.

**Tree cover:** **5,637 individual `natural=tree` nodes** in core (densely mapped on
campus and downtown; the generator can treat them as a scatter-seed sample, not an
exhaustive inventory — Brookside/Pammel woods are polygon-level, not node-level).

**Water in core:**

| feature | in-core extent |
|---|---|
| Lake LaVerne | rel 3329428: bbox **236 × 122 m**, center (−93.64802, 42.02357), area **11,039 m²** (V-12: game uses 2.8 ac / ≈11,300 m²) |
| College Creek | **10.2 km** of mapped creek lines in core, bbox 3,310 × 1,151 m (lon −93.671…−93.631, lat 42.015…42.026; crosses campus W→E at lat ≈42.024–42.025) |
| Ioway Creek | **33.1 km** of bank/centerline lines in core, bbox 4,915 × 3,238 m — the meander monster through Brookside, downtown's west side and the SE complex |
| Worrell Creek | 1.55 km (SE corner, lat 42.010–42.016) |
| Clear Creek | 3.56 km (NW corner, lat 42.029–42.037) |
| **South Skunk River** | **0 m — entirely outside the core.** The river runs N–S at lon ≈−93.594 (SUMMARY §7), ~1.4 km east of the E edge; it does not clip the NE corner at this bbox. The "river town" river is not buildable inside the box. |

(Lengths sum segments with midpoint in core; bboxes include segment endpoints, so
they can overshoot the edge by up to one segment length.)

### Rail corridor

*Source: `ames_census.py rail` (all `railway=*` ways; crossings = planar segment
intersections with all road classes; dedup 20 m within the same road).*

**Track in core:** UP **Clinton Subdivision** (main line) **8.47 km across 26 ways**
— it enters the core's west edge at lat ≈42.034 (13th St), bends SE through
downtown at **lat 42.0241 (Clark) → 42.0245 (Grand) → 42.0247 (Duff)**, then runs ENE
toward the yard. Plus: Jewell Subdivision 1.25 km (the NW branch, leaves at 13th
St), 1.00 km of spurs, 0.12 km abandoned. The yard itself (1,464 × 235 m, SUMMARY
§8) is east of the core.

**Road × rail crossings inside the core: 37 total — 15 vehicular, 22 foot/bike.**
Vehicular ones (the game's car-traffic crossings):

| crossing | coords | grade | notes |
|---|---|---|---|
| 13th St × Clinton Sub (×2 tracks) | −93.65415/−93.65392, 42.03497 | **separated** | the NW gate of the main line |
| 13th St × Jewell Sub | −93.62708, 42.03456 | at-grade | |
| Stange Rd × Clinton Sub | −93.64471, 42.03224 | **separated** | |
| Haber Rd × Clinton Sub | −93.63866, 42.03027 | **separated** | |
| 6th St × Clinton Sub | −93.63218, 42.02814 | **separated** | |
| 6th St × Jewell Sub | −93.62445, 42.02675 | **separated** | |
| 9th St × Jewell Sub | −93.62487, 42.03018 | at-grade | |
| North Hazel Ave × Clinton Sub | −93.62671, 42.02640 | **at-grade** | |
| Brookridge Ave × Clinton Sub | −93.62662, 42.02637 | **at-grade** | |
| **Grand Ave × spur** | −93.62026, 42.02445 | **at-grade** | downtown; Grand crosses a yard lead |
| **Clark Ave × Clinton Sub** | −93.61691, 42.02414 | **at-grade** | downtown |
| **Kellogg Ave × Clinton Sub** | −93.61374, 42.02420 | **at-grade** | downtown |
| **Duff Ave × Clinton Sub** | −93.61042, 42.02471 | **at-grade** | downtown, the busiest |
| unnamed service × abandoned | −93.62532, 42.02560 | at-grade | cosmetic |

The other 22 crossings are footway/cycleway/path (7 of them grade-separated) — the
campus-area rail trail network hops the line repeatedly.

**The downtown surprise:** only **four streets cross the main line vehicularly in
downtown (Grand, Clark, Kellogg, Duff)** — Burnett, Douglas, Pearle and Northwestern
Avenues are mapped only NORTH of Main and do not cross the rail at all; Sherman stops
just short of it. The rail corridor between Main and Lincoln Way is crossed exactly
where the game's trains should block traffic: 4 downtown streets + Hazel/Brookridge.

---

## 6. The filler verdict

*Source: `ames_census.py buildings` (authored split) + `authored-buildings.csv`
(every one of the 3,737 buildings classified).*

**Of the 3,737 in-core buildings:**

| class | count | % count | footprint | % area |
|---|---|---|---|---|
| **authored** — named (`name` tag) | **512** | 13.7 % | 66.7 ha | **55.3 %** |
| semi-authored — unnamed but use-tagged | 50 | 1.3 % | 2.5 ha | 2.1 % |
| **procedural** — fully anonymous | **3,175** | **85.0 %** | 51.4 ha | 42.6 % |

Read that right: **a sixth of the buildings carry 55 % of the footprint.** The
procedural synthesizer owns 3,175 anonymous boxes (p50 127 m² — houses, garages,
small commercial) but must NOT touch the 512 named ones (the whole ISU campus, both
downtown rows, the stadium, the churches, every venue building).

The 50 semi-authored buildings decompose as: 29 bus shelters (<15 m² — procedural
props, really), 7 parking structures/canopies, 3 monopine/cell towers, 2 bleachers,
2 storage tanks, 2 healthcare clinics, 2 fuel canopies, 1 fire station, 1 storage
rental, 1 toilet block. Net: **≈21 need function-aware authoring, 29 are props.**

The authored list in full is `authored-buildings.csv` (column `class=authored-named`,
with centroid, area, bbox, levels, height, POI tag, ISU-polygon membership) and is
reproduced zone-by-zone in the appendix table below. Zone counts: **ISU campus 152,
Campustown strip 58, downtown grid 147, everywhere else 155.**

Additions beyond `name` tags that still need hand-authoring:

- **The Stan Tap's building** (way 273536249, 216 Stanton, 3 lv, unnamed) — a
  Tier-2 venue on an anonymous footprint; add a name to the authored set.
- **The Welch Ave Station building** (207 Welch) — anchored only by an addr node
  (named "Pizza Pit"); the venue name must be attached by hand.
- **The Superdog cart** — a prop, placed at the Welch 200-block east curb.
- Two named venues sit **outside** the core (Hickory Park, The Cafe) and one Tier-2
  (Mucky Duck) has no anchor at all — boundary/fiction decisions, not census items.

**Bottom line for the master plan:** author ≈540 buildings (512 named + the venue
fixups), procedurally synthesize ≈3,200, and spend the authored budget first on the
campus 152 (38.3 ha — 57 % of the authored footprint), then the two district rows,
then the named scatter. *(QA fix 2026-11-08: "a third of the authored footprint" →
57 % per QA-REPORT item 9 / B-07 — 38.3 ha is 57 % of the 66.7 ha authored total, a
third of the 120.7 ha TOTAL building footprint.)*

---

## 7. Generator parameter sheet

The 15 numbers the city generator needs as constants (each traceable to a § above):

1. **Downtown block rhythm along Main** (W→E gaps): 115, 63, 214, 122, 139, 133,
   138 m — cross-street centerlines at Northwestern −93.62161, Grand −93.62022,
   Pearle −93.61946, Clark −93.61687, Burnett −93.61539, Kellogg −93.61371,
   Douglas −93.61211, Duff −93.61043; Main lat 42.02508, 5th 42.0259, 6th 42.0269
   (Main→5th 86 m, 5th→6th 105 m). (§2)
2. **Campustown blocks along Lincoln Way** (S side): State→Hyland 295 m,
   Hyland→Sheldon 112, Sheldon→Hayward 204, Hayward→Welch 134, Welch→Stanton 136;
   centerlines: State −93.65913, Hyland −93.65557, Sheldon −93.65422,
   Hayward −93.65175, Welch −93.65013, Stanton −93.64849; Lincoln Way lat 42.02277;
   Chamberlain 42.02147, Hunt 42.02022. (§2)
3. **Street widths by class** (generator defaults — OSM has no widths; SUMMARY §10):
   primary 20 m (Lincoln Way, S Duff, Grand), secondary 16 m (Duff, 13th, 6th,
   University Blvd), tertiary 13 m (Main, Sheldon, Mortensen), residential 11 m,
   service 7 m. (§4)
4. **Default level heights**: 1 lv ≈ 4 m, 2 lv ≈ 8 m, 3 lv ≈ 11 m, 4 lv ≈ 14 m —
   defaults from the histogram where 1–3 lv = 85 % of tagged stock; towers 8–11 lv
   (h≈27–40 m); Marston tower 51.2 m and Campanile 33.5 m as set pieces. (§1,
   VERIFICATION §5)
5. **Building footprint sampler**: p50 127 m², p90 595 m², mean ≈323 m² for
   procedural fill; district rows tighter (downtown p50 246, Campustown p50 294
   with strip buildings 200–300 m²). (§1, §2)
6. **Setbacks**: downtown Main frontage **12.4 m from centerline** (p25–p75
   11.7–12.6 — build the wall flat); Welch Ave 16.6 m (min 0.2 — allow 2 buildings
   at the sidewalk); Lincoln Way south side 20.7 m. (§2)
7. **Venue anchor list**: **26 in-core anchors** (11 Tier-1 + 15 Tier-2, exact
   coordinates in §2) + 3 out-of-core (Hickory Park S, The Cafe N, Provisions S) +
   1 cart prop (Superdog). (§2)
8. **Campus authored set**: 152 named campus buildings, 38.3 ha; top-30 dims in §3;
   anchor trio Campanile (−93.64604, 42.02543) / MU (−93.64576, 42.02367) /
   Parks Library (−93.64883, 42.02813). (§3)
9. **Park list**: 20 named in-core parks (§5 table) + Pammel Woods 16.1 ha + the
   Ioway Creek corridor woods; total green 267.1 ha (25.2 % of core). Bandshell
   Park just outside the E edge — decide boundary. (§5)
10. **Water**: Lake LaVerne 236×122 m / 11,300 m² game figure; College Creek
    10.2 km in-core crossing campus; Ioway Creek 33.1 km of meander; **no South
    Skunk in-core** (1.4 km east). (§5)
11. **Rail**: Clinton Sub main line 8.47 km in core, downtown lat band
    42.0241→42.0247 (slopes ENE at ~93.7°); **15 vehicular crossings (9 at-grade:
    Grand, Clark, Kellogg, Duff, Hazel, Brookridge, 9th, 13th×Jewell, 1 service) +
    22 foot/bike crossings** — the train-blocking set. (§5)
12. **Intersections**: downtown window 20 (14× 3-way, 6× 4-way); Campustown 13
    (6/6/1); core-wide 143. Crosswalk/stop-sign machine stocks these. (§4)
13. **Signals**: 78 traffic_signal nodes in core (6 downtown, 8 Campustown);
    1,801 pedestrian crossing nodes, 126 signalized. (§4)
14. **Parking**: 480 lots, 73.6 ha (7 % of core); tailgate stock = 19 Iowa State
    Center lots, 8.9 ha. (§3)
15. **Trees**: 5,637 mapped tree nodes as scatter seeds; wooded polygons
    (Brookside 38.9 ha, Pammel 16.1 ha) carry the rest. (§5)

---

## Provenance / file manifest

| file | what it is |
|---|---|
| `census/BUILD-CENSUS.md` | this file |
| `census/authored-buildings.csv` | all 3,737 in-core buildings: id, name, authored/semi/procedural class, area, bbox dims, centroid, levels, height, POI tag, ISU-polygon flag |
| `census/scripts/ames_census.py` | the census script (modes: cache, buildings, districts, venues, campus, streets, green, rail) |
| `census/scripts/tagged_nodes.json` | cache of 17,895 tagged nodes re-scanned from the 42 raw tiles (merged dataset drops node tags) |
| `census/scripts/_out_<mode>.txt` | raw machine outputs of each mode run (buildings, districts, venues, campus, streets, green, rail) |
| inputs (read-only) | `../osm/raw/ames_merged.json`, `../osm/raw/tile_r*.json`, `../osm/SUMMARY.md`, `../venues/VENUES.md`, `../landmarks/LANDMARKS.md`, `../verification/VERIFICATION.md` |

Claim → mode map: §1 `buildings`; §2 `districts` + `venues`; §3 `campus`; §4
`streets`; §5 `green` + `rail`; §6 `buildings` + the CSV; every sibling fact used
(Lincoln Way lat, address rules, settled dims, V-06/V-09/V-12/V-24/V-25) comes from
`../verification/VERIFICATION.md`.

*Build-census lane, 2026-11-08.*

---

## Appendix — the authored list (all 512 named in-core buildings)


### ISU campus (building=university/dormitory/stadium or inside ISU relation) — 152 named buildings

| name | center (lon, lat) | m2 | levels | building tag | OSM |
|---|---|---|---|---|---|
| Jack Trice Stadium | -93.635733, 42.013802 | 21413 | - | stadium | way/613735866 |
| Lied Recreation Center | -93.637213, 42.026593 | 15468 | 3 | university | way/33726001 |
| Hilton Coliseum | -93.634771, 42.021002 | 12334 | 5 | stadium | way/180651868 |
| Bergstrom Indoor Training Facility | -93.638118, 42.015435 | 9401 | - | university | way/1052515109 |
| Friley Residence Hall | -93.651224, 42.023939 | 9060 | 5 | dormitory | way/158023222 |
| Memorial Union | -93.645762, 42.023667 | 8913 | 6 | university | way/183224150 |
| Forker Building | -93.640277, 42.026734 | 8591 | 3 | university | way/162993229 |
| State Gymnasium | -93.653256, 42.02463 | 7866 | 3 | university | way/183224403 |
| Iowa State University Power Plant | -93.639487, 42.027794 | 7567 | 10 | university | way/183191045 |
| Parks Library | -93.648828, 42.028126 | 7290 | 5 | university | way/33725897 |
| General Services Building | -93.640747, 42.028073 | 6604 | 2 | university | way/183191043 |
| Howe Hall | -93.653074, 42.026834 | 6526 | 3 | university | way/183218202 |
| Kildee Hall | -93.643793, 42.029573 | 6480 | 4 | university | way/183200718 |
| Agronomy Hall | -93.642638, 42.028337 | 6399 | 4 | university | way/183187995 |
| Food Sciences Building | -93.64268, 42.026854 | 6221 | 3 | university | relation/2507887 |
| Beyer Hall | -93.652939, 42.025884 | 5620 | 3 | university | way/158023212 |
| Gilman Hall | -93.648576, 42.029432 | 5590 | 4 | university | way/183214584 |
| Molecular Biology Building | -93.649678, 42.031099 | 4870 | 5 | university | way/183207520 |
| Lagomarcino Hall | -93.64539, 42.029811 | 4660 | 3 | university | relation/2507889 |
| Town Engineering Building | -93.652736, 42.029546 | 4596 | 5 | university | way/158023277 |
| Stephens Auditorium | -93.638012, 42.020215 | 4582 | 5 | university | way/180654356 |
| Gerdin Business Building | -93.644286, 42.025312 | 4469 | 3 | university | way/158023223 |
| Physics Hall | -93.647355, 42.029427 | 4450 | 2 | university | way/183214402 |
| Armory | -93.650935, 42.029639 | 4439 | 2 | university | way/162986350 |
| Black Engineering | -93.651057, 42.026011 | 4295 | 4 | university | way/183217314 |
| Coover Hall | -93.650999, 42.028414 | 4129 | 4 | university | relation/14386885 |
| Bergstrom Football Complex | -93.637272, 42.015449 | 3980 | 2 | university | way/1052515108 |
| Seed Science Building | -93.642191, 42.02932 | 3794 | 3 | university | relation/14386886 |
| Student Innovation Center | -93.651317, 42.027232 | 3793 | 5 | university | way/499168444 |
| Ames Lab - Metals Development Building | -93.6486, 42.030993 | 3698 | 2 | yes | way/183207516 |
| Communications Building | -93.650842, 42.031012 | 3423 | 2 | university | way/183206734 |
| Environmental Health & Safety Services Building | -93.648037, 42.034451 | 3406 | 2 | university | way/183201816 |
| Meats Laboratory | -93.643891, 42.030041 | 3173 | 2 | university | way/183200700 |
| Maple-Willow-Larch Commons | -93.638208, 42.02375 | 3133 | 3 | university | way/162990259 |
| Hoover Hall | -93.651067, 42.026667 | 3084 | 3 | university | way/158023224 |
| Stark Performance Center | -93.636874, 42.01556 | 3028 | 5 | university | way/840743112 |
| Union Drive Community Center | -93.651497, 42.024968 | 3028 | 3 | university | way/158023282 |
| Helser Residence Hall | -93.651822, 42.024092 | 3018 | 4 | dormitory | way/183323404 |
| Bessey Hall | -93.644629, 42.028484 | 2949 | 5 | university | way/183187336 |
| Oak-Elm Residence Hall | -93.640312, 42.025067 | 2912 | 4 | dormitory | way/183318478 |
| Wallace-Wilson Commons | -93.650463, 42.014041 | 2867 | 2 | university | way/183332705 |
| College of Design | -93.65315, 42.028557 | 2829 | 5 | university | relation/11697605 |
| Printing and Publications Building | -93.64725, 42.032604 | 2828 | 1 | university | way/183205859 |
| Knapp-Storms Dining Complex | -93.650495, 42.01525 | 2822 | 2 | university | way/183332704 |
| Simon Estes Music Hall | -93.648203, 42.024633 | 2770 | 3 | university | way/183317249 |
| Hach Hall | -93.649738, 42.030157 | 2738 | 4 | university | way/183213421 |
| MacKay Hall | -93.646504, 42.028576 | 2726 | 3 | university | way/158023238 |
| Ames Lab - Spedding Hall | -93.648623, 42.03008 | 2698 | 3 | yes | way/183763233 |
| Horticulture Hall | -93.644807, 42.027839 | 2684 | 2 | university | way/183870431 |
| Carver Hall | -93.648326, 42.025263 | 2664 | 5 | university | way/33725618 |
| Linden Residence Hall | -93.640311, 42.023145 | 2605 | 5 | dormitory | way/183319184 |
| Agronomy Greenhouse | -93.640038, 42.029864 | 2599 | 1 | university | way/183189176 |
| Sweeney Hall | -93.651024, 42.027861 | 2528 | 4 | university | way/158023274 |
| Durham Center | -93.649802, 42.027546 | 2496 | 4 | university | way/158023217 |
| Science Hall | -93.646314, 42.029325 | 2298 | 5 | university | relation/2507891 |
| Geoffroy Hall | -93.642696, 42.022222 | 2268 | 8 | dormitory | way/377558130 |
| Warren Madden Building | -93.645519, 42.034589 | 2248 | 2 | university | way/183201818 |
| Martin Residence Hall | -93.652865, 42.023871 | 2211 | 4 | dormitory | relation/2507890 |
| Jacobson Athletic Building | -93.635776, 42.014983 | 2203 | 3 | university | way/42501390 |
| Curtiss Hall | -93.644739, 42.026176 | 2174 | 3 | university | way/122268115 |
| Beardshear Hall | -93.64843, 42.026189 | 2151 | 4 | university | way/33725619 |
| Sukup Hall | -93.653229, 42.027648 | 2148 | 5 | university | way/226914404 |
| Eaton Residence Hall | -93.652756, 42.024441 | 2097 | 4 | dormitory | way/231767123 |
| Sukup Endzone | -93.635721, 42.012877 | 2089 | - | stadium | way/613735869 |
| National Laboratory for Agriculture and the Environment | -93.642095, 42.030166 | 2019 | 3 | university | way/183200004 |
| Advanced Teaching and Research Building | -93.645385, 42.030837 | 2014 | 7 | university | way/499161009 |
| Extension 4-H Building | -93.645732, 42.035241 | 1946 | 2 | university | way/183202173 |
| Pearson Hall | -93.649878, 42.025941 | 1849 | 3 | university | way/183216667 |
| Buchanan Residence Hall | -93.64368, 42.022216 | 1775 | 9 | dormitory | way/183324232 |
| Science Hall II | -93.646325, 42.030085 | 1739 | 7 | university | way/183221039 |
| Thielen Student Health Center | -93.653902, 42.025762 | 1711 | 3 | university | way/42501405 |
| Troxel Hall | -93.644057, 42.027787 | 1702 | 1 | university | way/219124288 |
| Palmer Building | -93.645603, 42.028388 | 1695 | 3 | university | way/158023252 |
| Hamilton Hall | -93.642009, 42.027592 | 1689 | 2 | university | way/183187396 |
| Therkildsen Industrial Engineering Building | -93.65368, 42.026553 | 1689 | 4 | university | way/1353295731 |
| Ames Lab - Warehouse | -93.649385, 42.03327 | 1645 | 1 | university | way/183205329 |
| Roy J. Carver Co-Lab | -93.650825, 42.032338 | 1627 | 2 | university | way/183206735 |
| Iowa State University Alumni Center | -93.638602, 42.018116 | 1511 | 3 | university | way/162993592 |
| Library Storage Facility | -93.646712, 42.033379 | 1480 | 1 | university | way/183201636 |
| Marston Hall | -93.649886, 42.026807 | 1475 | 4 | university | way/183216666 |
| Horse Barn | -93.643717, 42.030874 | 1409 | 2 | university | way/183198848 |
| National Swine Research and Information Center | -93.642756, 42.030147 | 1381 | 4 | university | way/183200003 |
| Zaffarano Physics Addition | -93.647314, 42.029932 | 1369 | 6 | university | way/183214247 |
| Hixson-Lied Student Success Center | -93.639748, 42.024021 | 1348 | 3 | university | way/183318868 |
| Southeast Concessions | -93.634545, 42.01342 | 1330 | 1 | stadium | way/180650428 |
| King Pavilion | -93.653446, 42.028808 | 1318 | 2 | university | way/183218411 |
| LeBaron Hall | -93.647212, 42.028142 | 1317 | 3 | university | way/1569210622 |
| Human Nutritional Sciences Building | -93.647427, 42.028141 | 1316 | 3 | university | way/183219250 |
| Elings Hall | -93.65265, 42.027395 | 1302 | 5 | university | way/305573354 |
| Ross Hall | -93.644182, 42.026626 | 1262 | 7 | university | way/158023259 |
| Southwest Concessions | -93.636939, 42.013403 | 1258 | 1 | stadium | way/180763713 |
| Bessey Hall Addition | -93.64414, 42.028481 | 1257 | - | university | way/840622960 |
| Biorenewables Research Laboratory | -93.652646, 42.027719 | 1239 | 5 | university | way/158023213 |
| Welch Residence Hall | -93.642129, 42.023535 | 1223 | 4 | dormitory | way/183734212 |
| LeBaron Hall | -93.647371, 42.028552 | 1213 | 2 | university | way/158023234 |
| Fredrickson Court Community Center | -93.642872, 42.033927 | 1207 | 1 | university | way/183192306 |
| Forestry Greenhouse | -93.641054, 42.029962 | 1202 | 1 | university | way/183189042 |
| Plant Pathology Greenhouse | -93.641052, 42.029647 | 1183 | 1 | university | way/183189044 |
| Snedecor Hall | -93.64971, 42.028508 | 1129 | 3 | university | way/158023268 |
| Atanasoff Hall | -93.649729, 42.028166 | 1120 | 3 | university | way/158023211 |
| Maple Residence Hall | -93.63871, 42.023648 | 1110 | 8 | dormitory | way/162989420 |
| Willow Residence Hall | -93.637707, 42.023928 | 1100 | 8 | dormitory | way/162989415 |
| Larch Residence Hall | -93.638039, 42.023269 | 1037 | 8 | dormitory | way/162989419 |
| Roberts Residence Hall | -93.642478, 42.023922 | 1030 | 4 | dormitory | way/183734204 |
| Student Services | -93.650088, 42.025249 | 979 | 4 | university | way/183216668 |
| Northeast Concessions | -93.634527, 42.014505 | 975 | 1 | stadium | way/180650616 |
| Northwest Concessions | -93.636993, 42.014479 | 959 | 1 | stadium | way/180763711 |
| Firemanship Training | -93.639009, 42.031357 | 941 | - | university | way/183199045 |
| Fisher Theater | -93.638036, 42.021547 | 928 | 3 | university | way/180654035 |
| United States Department of Agriculture Greenhouse | -93.641118, 42.029288 | 901 | 1 | university | way/183189168 |
| Birch Residence Hall | -93.641637, 42.023583 | 875 | 4 | dormitory | way/183734220 |
| Heady Hall | -93.643171, 42.026346 | 859 | 6 | university | way/183186372 |
| East Hall | -93.643376, 42.026066 | 831 | 4 | university | way/183186375 |
| Frederiksen Court 52 | -93.638645, 42.034239 | 822 | 3 | apartments | way/183193754 |
| Wilson Residence Hall | -93.651038, 42.013871 | 819 | 11 | dormitory | way/183333365 |
| Wallace Residence Hall | -93.649898, 42.014249 | 819 | 11 | dormitory | way/183333371 |
| Ames Lab - Mechanical Maintenance | -93.648632, 42.033026 | 813 | 1 | university | way/183205330 |
| North Chilled Water Plant | -93.646375, 42.032234 | 802 | 1 | university | way/183201563 |
| Iowa Farm Bureau Pavilion | -93.643298, 42.029204 | 782 | 1 | university | way/183200917 |
| Freeman Residence Hall | -93.641683, 42.024769 | 773 | 4 | dormitory | way/183732080 |
| Morrill Hall | -93.648072, 42.027233 | 763 | 3 | university | way/158023244 |
| Lyon Residence Hall | -93.642382, 42.024468 | 760 | 4 | dormitory | way/183732085 |
| Ames Lab - Maintenance Shops | -93.648265, 42.032811 | 744 | 1 | university | way/183205337 |
| Jischke Honors Building | -93.644588, 42.027142 | 710 | 2 | university | way/158023231 |
| Catt Hall | -93.645667, 42.027896 | 668 | 4 | university | way/158023214 |
| Enrollment Services Center | -93.649138, 42.025079 | 664 | 3 | university | way/162993480 |
| Hub | -93.648492, 42.027266 | 648 | 1 | university | way/183785559 |
| Office and Lab Building | -93.647915, 42.029409 | 641 | 3 | university | way/162982460 |
| Locker Rooms | -93.646093, 42.013056 | 595 | - | yes | way/242895555 |
| Press Box | -93.636886, 42.013989 | 584 | - | stadium | way/183039624 |
| Reiman Maintenance Building | -93.638219, 42.012591 | 556 | 1 | university | way/180764674 |
| Transportation Services | -93.639045, 42.030711 | 556 | - | university | way/183199044 |
| Advanced Machinery Systems Laboratory | -93.647004, 42.03095 | 541 | 1 | university | way/183206444 |
| Ames Lab - Paint and AC | -93.647756, 42.032703 | 507 | 1 | university | way/183205595 |
| Laboratory Of Mechanics | -93.650579, 42.02561 | 477 | 3.5 | university | way/33725868 |
| Ruminant Nutrition Laboratory | -93.642754, 42.030875 | 472 | 2 | university | way/183199395 |
| SE Recreation Complex Service Building | -93.631676, 42.013314 | 466 | 1 | university | way/845871555 |
| Barton Residence Hall | -93.641634, 42.024216 | 454 | 4 | dormitory | way/183319404 |
| Ames Lab - Construction Storage | -93.647737, 42.032972 | 441 | 1 | university | way/183205594 |
| Landscape Architecture Building | -93.64297, 42.02753 | 419 | 2 | university | way/183187337 |
| Concessions | -93.646419, 42.013015 | 418 | - | yes | way/242895553 |
| Crop Genome Informatics Laboratory | -93.642019, 42.029751 | 411 | 1 | university | way/183200221 |
| Sukup Atrium | -93.652806, 42.027582 | 409 | 1 | university | way/305573355 |
| Kocimski Auditorium | -93.653114, 42.028282 | 355 | 2 | university | way/930836768 |
| Farm House Museum | -93.64396, 42.027165 | 314 | 3 | university | way/158023219 |
| Maintenance Building | -93.647113, 42.012148 | 222 | - | yes | way/242895554 |
| Sloss House | -93.644915, 42.025677 | 157 | - | university | way/183041219 |
| Marston Water Tower | -93.650765, 42.026993 | 151 | - | yes | way/861201396 |
| Paintball Storage | -93.655051, 42.0175 | 102 | - | university | way/854983919 |
| Soccer Pressbox | -93.645844, 42.013189 | 71 | - | yes | way/242895556 |
| Softball Pressbox | -93.646726, 42.012787 | 71 | - | yes | way/854983921 |
| Campanile | -93.646037, 42.025431 | 45 | 1 | university | way/183041212 |

### Campustown strip (State..Stanton Aves, south of Lincoln Way) — 58 named buildings

| name | center (lon, lat) | m2 | levels | building tag | OSM |
|---|---|---|---|---|---|
| Union on Lincoln Way | -93.654933, 42.022293 | 4799 | 6 | apartments | way/852963437 |
| Ames Intermodal Facility | -93.652314, 42.021095 | 3654 | 4 | yes | way/183767367 |
| The Edge | -93.647184, 42.021949 | 3436 | 1 | apartments | way/486943472 |
| Collegiate United Methodist Church | -93.652614, 42.022327 | 2780 | - | yes | relation/3324395 |
| Kingland Building | -93.649542, 42.022497 | 2545 | 3 | commercial | way/377558129 |
| 23 Twenty Lincoln | -93.647545, 42.022348 | 2535 | 7 | apartments | way/377558125 |
| The Crawford | -93.648926, 42.018419 | 2307 | 3 | apartments | way/855616112 |
| Legacy Tower | -93.649, 42.021945 | 2161 | 10 | apartments | way/236800162 |
| The Stritz | -93.64975, 42.018292 | 1596 | 3 | apartments | way/830930329 |
| The Foundry | -93.646841, 42.022499 | 1486 | 1 | apartments | way/377558124 |
| Chamberlain Lofts | -93.651319, 42.0217 | 1474 | 6 | apartments | way/241365810 |
| St. John's by the Campus Episcopal Church of Ames | -93.648172, 42.022374 | 1466 | - | yes | way/247519152 |
| Welch Crown Center | -93.650569, 42.02068 | 1361 | 4 | residential | way/259249457 |
| CenturyLink | -93.65869, 42.022436 | 1324 | - | commercial;service | way/244329932 |
| Lighthouse Campus Fellowship | -93.653891, 42.022195 | 1320 | 1 | yes | way/246079553 |
| University Towers | -93.646755, 42.022008 | 1225 | 10 | apartments | way/247526947 |
| Cyclone Plaza | -93.648124, 42.02123 | 1189 | 9 | apartments | way/246557466 |
| Campus Flats | -93.651277, 42.022042 | 1166 | 7 | apartments | way/805223843 |
| Brickstone Place | -93.648843, 42.020946 | 1028 | 6 | apartments | way/244329939 |
| Stanton Heights | -93.648149, 42.020338 | 1018 | 6 | apartments | way/246252176 |
| The Annex of Collegiate United Methodist Church and Wesley Foundation | -93.653894, 42.021538 | 999 | - | yes | way/246079544 |
| Spruce Pointe | -93.646862, 42.019366 | 882 | 4 | apartments | way/247526936 |
| Delta Gamma | -93.646856, 42.019875 | 707 | 3 | yes | way/247526941 |
| Clock Tower Place | -93.649048, 42.021241 | 668 | 4 | apartments | way/1101564268 |
| Kappa Kappa Gamma | -93.646058, 42.021947 | 666 | 3 | yes | way/1212918380 |
| Alpha Chi Omega | -93.646821, 42.020449 | 622 | 3 | yes | way/247526960 |
| Cardinal Terrace | -93.646824, 42.021186 | 581 | 3 | apartments | way/247526943 |
| Ames Fire Department Station 2 | -93.649661, 42.021611 | 547 | 1 | yes | way/231767150 |
| Cranford Building | -93.648854, 42.022577 | 501 | 4 | commercial | way/236800163 |
| Adelante | -93.649708, 42.019755 | 474 | 2 | yes | way/272522416 |
| Pi Kappa Phi | -93.650465, 42.018854 | 458 | 3 | residential | way/244329945 |
| Chamberlynn Professional Building | -93.646722, 42.021397 | 441 | 2 | commercial | way/247526958 |
| Campus View | -93.651435, 42.021026 | 437 | 3 | apartments | way/272522424 |
| BNC Field House | -93.649664, 42.021196 | 422 | 1 | yes | way/241365816 |
| Kappa Alpha Theta | -93.646105, 42.019429 | 420 | 3 | yes | way/247519137 |
| Alpha Sigma Phi | -93.646789, 42.020741 | 419 | 3 | yes | way/247526930 |
| Theta Xi | -93.65053, 42.019764 | 375 | 3 | yes | way/830930328 |
| The Resort | -93.648771, 42.021699 | 369 | 3 | residential | way/246079551 |
| Alpha Kappa Lambda | -93.653628, 42.019335 | 364 | 3 | yes | way/830930330 |
| U.S. Bank | -93.651501, 42.022536 | 362 | 2 | yes | way/246079545 |
| Planned Parenthood - Ames Health Center | -93.651492, 42.021154 | 359 | 1 | yes | way/272522421 |
| Delta Sigma Phi | -93.646764, 42.020253 | 339 | 3 | yes | way/247526954 |
| Public House | -93.651069, 42.021238 | 332 | 5 | apartments | way/334936864 |
| Dunkin' | -93.653873, 42.022542 | 321 | - | yes | way/231767127 |
| Macubana | -93.649882, 42.022073 | 301 | 2 | yes | way/241365821 |
| AJ's Ultralounge | -93.648777, 42.021562 | 301 | 3 | yes | way/246079558 |
| Iowa House | -93.652105, 42.018808 | 301 | 3 | yes | way/919933057 |
| Outlaws | -93.651236, 42.021234 | 290 | 2 | yes | way/272522425 |
| Cy's Roost | -93.650463, 42.02195 | 289 | 2 | yes | way/241365820 |
| Kum & Go | -93.650558, 42.021245 | 263 | - | yes | way/231767147 |
| Crystal Clean Windows | -93.651096, 42.021028 | 246 | - | yes | way/272522423 |
| Little Taipei | -93.650769, 42.021184 | 242 | - | yes | way/241365808 |
| Portobello Road | -93.649847, 42.021868 | 159 | 3 | yes | way/231767129 |
| Ichiban Japanese Restaurant | -93.650362, 42.022055 | 126 | 1 | yes | way/231767126 |
| AJ's Liquor | -93.650875, 42.021626 | 124 | 1 | yes | way/241365811 |
| Kum & Go | -93.650292, 42.021274 | 115 | - | roof | way/231767132 |
| Times Square Corner | -93.648761, 42.021198 | 70 | 3;2 | residential | relation/14669595 |
| Campustown Clock Tower | -93.650151, 42.021343 | 4 | - | yes | way/853592605 |

### Downtown grid (Northwestern..Duff, Main..6th) — 147 named buildings

| name | center (lon, lat) | m2 | levels | building tag | OSM |
|---|---|---|---|---|---|
| Ames City Hall | -93.617751, 42.026361 | 5148 | - | yes | relation/2560369 |
| Ames Public Library | -93.612593, 42.02642 | 4235 | 2 | yes | way/774663109 |
| Fareway | -93.615861, 42.027422 | 2302 | 1 | yes | way/102723486 |
| Ames First United Methodist Church | -93.613269, 42.02656 | 2175 | - | yes | way/853984836 |
| Wheatsfield Cooperative | -93.62173, 42.025235 | 2051 | - | yes | way/265728169 |
| CenturyLink | -93.617603, 42.025453 | 1865 | - | yes | way/853984663 |
| Ames Post Office | -93.61423, 42.026573 | 1800 | 2 | yes | way/310111056 |
| HPC | -93.611664, 42.023671 | 1654 | 1 | yes | way/236565197 |
| The Sheldon-Munn | -93.614118, 42.025345 | 1484 | 4 | apartments | way/241720035 |
| First National Bank of Ames | -93.615845, 42.026162 | 1408 | - | yes | way/262264540 |
| Historic Tribune Building | -93.61474, 42.026264 | 1385 | 2 | commercial | way/262264538 |
| Greater Iowa Credit Union | -93.62077, 42.023395 | 1341 | - | yes | way/102239926 |
| Main Street Station | -93.618071, 42.024445 | 1303 | 1 | commercial | way/260524827 |
| First Christian Church | -93.617412, 42.027161 | 1101 | - | yes | way/853984696 |
| Ames United Church of Christ | -93.613331, 42.027199 | 1003 | - | yes | way/718052513 |
| US Federal Highway Administration | -93.61085, 42.027245 | 940 | 1 | yes | way/853984820 |
| Friedrich Iowa Realty | -93.610825, 42.026702 | 836 | 1 | yes | way/519341373 |
| Sweet Carolines | -93.614692, 42.024795 | 827 | - | yes | way/254335401 |
| Wells Fargo | -93.616264, 42.024818 | 822 | - | yes | way/241720048 |
| Hokel Machine Supply | -93.610079, 42.02445 | 809 | - | yes | way/312090995 |
| U.S. Bank | -93.615695, 42.025346 | 806 | 1 | yes | way/241720047 |
| Zions Agricultural Finance | -93.61722, 42.025637 | 795 | 1 | yes | way/853984664 |
| House of Refuge Church | -93.620877, 42.024868 | 721 | - | church | way/265728171 |
| Ames Probation Parole Administration Building | -93.612441, 42.023672 | 710 | 1 | yes | way/236565195 |
| Heuss Printing Inc | -93.622359, 42.024318 | 665 | - | yes | way/238454547 |
| Time Out | -93.613251, 42.023804 | 657 | 1 | yes | way/236565187 |
| Masonic Temple Building | -93.612401, 42.025726 | 648 | 3 | office | way/237834152 |
| La Casa Maya | -93.619421, 42.023783 | 608 | - | yes | way/98658302 |
| New Point Law Firm, plc | -93.613433, 42.0275 | 600 | 1 | yes | way/853984850 |
| Municipal Building | -93.613432, 42.02566 | 589 | 3 | yes | way/237834146 |
| Pyle Office Park | -93.620505, 42.026266 | 586 | 2 | office | way/519341370 |
| Town Center | -93.614926, 42.024822 | 584 | 3 | commercial | way/254335400 |
| EZPAWN | -93.613966, 42.023166 | 557 | - | yes | way/236410790 |
| Adams Funeral Home | -93.611668, 42.026265 | 557 | 2 | yes | way/853984833 |
| Pyle's Town Centre | -93.62181, 42.026559 | 549 | 2 | apartments | way/774664015 |
| Dog·Eared Books | -93.612409, 42.025374 | 545 | 2 | retail | way/237834137 |
| Culver's | -93.618788, 42.023783 | 535 | - | yes | way/98658327 |
| Pyle Office Park | -93.620696, 42.026014 | 529 | 2 | office | way/519341371 |
| 600 Fifth | -93.618563, 42.025599 | 516 | 3 | office | way/519341366 |
| Ames Elks Lodge | -93.611729, 42.026764 | 515 | 1 | yes | way/519341372 |
| BMO | -93.618069, 42.025254 | 512 | - | yes | way/853984672 |
| Holy Transfiguration Orthodox Church | -93.614183, 42.027723 | 500 | - | yes | way/853984853 |
| Torrent Brewing Company | -93.61509, 42.026394 | 496 | 1 | yes | way/931902030 |
| Body of Christ Church | -93.611243, 42.025709 | 485 | 2 | yes | way/237834133 |
| Laura's Cabinet Gallery | -93.614373, 42.023952 | 482 | - | yes | way/236410786 |
| Great Harvest Bakery and Café | -93.615087, 42.026231 | 460 | 1 | yes | way/853984690 |
| Premier Credit Union | -93.619825, 42.026642 | 454 | - | yes | way/260308165 |
| Wild Water Car Wash & Pet Wash | -93.616419, 42.023816 | 453 | - | yes | way/236410784 |
| Montgomery Ward Building | -93.614962, 42.025337 | 452 | 2 | commercial | way/241720034 |
| Sportsman Lounge | -93.611527, 42.025373 | 450 | - | yes | way/237834144 |
| American Legion Hall | -93.613233, 42.025353 | 442 | - | yes | way/237834140 |
| Knapp-Tedesco Insurance | -93.619659, 42.025335 | 432 | - | yes | way/265728172 |
| English Bulldog Cigar Lounge | -93.614017, 42.025603 | 421 | - | yes | way/241720042 |
| Mercer Advisors Wealth Management | -93.614381, 42.026073 | 421 | 2 | yes | way/853984682 |
| Everts Flowers Home Gifts | -93.615134, 42.025336 | 418 | 1 | retail | way/241720030 |
| Midas | -93.611234, 42.023164 | 409 | 1 | yes | way/236780158 |
| Precision Auto Clinic | -93.621123, 42.024381 | 400 | 1 | yes | way/238454556 |
| Payer, Hunziker, Rhodes & Peters, LLP | -93.618635, 42.025307 | 400 | - | yes | way/853984674 |
| 10Fold Architecture + Engineering | -93.61401, 42.025739 | 398 | 1 | yes | way/241720033 |
| Ames Tile Showroom | -93.611261, 42.025397 | 384 | 1 | retail | way/237834142 |
| Greater Iowa Credit Union | -93.621424, 42.023651 | 373 | 1 | yes | way/102239928 |
| Winning Solutions | -93.621877, 42.023885 | 369 | - | yes | way/102239924 |
| Sam's Place | -93.611704, 42.025385 | 368 | 2 | commercial | way/237834143 |
| Ames History Museum | -93.611886, 42.02574 | 361 | 2 | yes | way/237834127 |
| Alliance Ames Brazilian JiuJitsu | -93.613359, 42.023211 | 360 | 1 | yes | way/236780163 |
| All Star Auto Glass | -93.621699, 42.023193 | 358 | 1 | yes | way/102239931 |
| Weber Accounting Services | -93.614416, 42.02713 | 321 | - | yes | way/853984698 |
| Goldfinch Apartments | -93.613124, 42.027759 | 321 | 4 | apartments | way/853984852 |
| Pioneer Cleaning & Restoration | -93.610736, 42.025795 | 299 | 1 | yes | way/853984842 |
| Members 1st Community Credit Union | -93.616581, 42.025275 | 297 | - | yes | way/241720026 |
| Ames Pantorium | -93.611737, 42.025601 | 292 | 2 | commercial | way/237834148 |
| Ames National Corporation | -93.61483, 42.027086 | 291 | - | yes | way/718052516 |
| Serenity Pet Spa | -93.61338, 42.023313 | 286 | 1 | yes | way/236780162 |
| Skunk River Cycles | -93.614235, 42.024825 | 275 | - | yes | way/254335405 |
| The Knittery Nook & Fibre Co. | -93.612927, 42.025367 | 269 | - | yes | way/237834147 |
| Dangerous Curves | -93.61107, 42.026142 | 264 | 2 | yes | way/310110557 |
| Triplett Insurance | -93.615006, 42.02607 | 257 | 1 | yes | way/853984691 |
| Whiskey River | -93.611838, 42.024948 | 257 | - | yes | way/269752175 |
| Morning Bell Coffee Roasters | -93.611092, 42.025399 | 256 | - | yes | way/237834136 |
| Abelardo's Mexican Food | -93.618419, 42.023231 | 253 | 1 | yes | way/236094050 |
| Pyfferoen Pediatric Dentistry | -93.613942, 42.026102 | 251 | - | yes | way/262264537 |
| Starbucks | -93.61736, 42.023196 | 247 | 1 | yes | way/236094026 |
| The Pumpkin Patch | -93.613954, 42.024839 | 246 | - | yes | way/254335407 |
| Heroic Ink Tattoo & Piercing | -93.612631, 42.025373 | 241 | - | yes | way/237834145 |
| Triplett Companies | -93.615165, 42.026067 | 232 | 1 | yes | way/1105577307 |
| Kitchen, Bath & Home | -93.612251, 42.025376 | 232 | - | retail | way/237834132 |
| Avec Design+Build | -93.611913, 42.025374 | 231 | 2 | office | way/237834141 |
| Emerhoff's Footwear | -93.612823, 42.025361 | 222 | 2 | retail | way/237834139 |
| Moorman Clothiers | -93.612891, 42.024887 | 222 | - | yes | way/269752179 |
| Skei Coal & Salt | -93.619103, 42.024015 | 219 | - | shed | way/98658312 |
| Melissa Stenstrom Fine Jewelry | -93.617282, 42.025302 | 219 | 2 | yes | way/853984669 |
| Touchless Laser Car Wash II | -93.615623, 42.023848 | 217 | - | yes | way/236410785 |
| Back Alley House Plants | -93.617117, 42.025305 | 213 | 2 | yes | way/853984668 |
| Ames Christian Supply | -93.612727, 42.025362 | 212 | 2 | retail | way/237834125 |
| The Loft - Ames | -93.613555, 42.02535 | 211 | 2 | retail | way/237834135 |
| Mary Jane's Ames | -93.611381, 42.025384 | 208 | - | yes | way/237834131 |
| Cafe Diem | -93.613376, 42.025352 | 207 | - | yes | way/237834126 |
| Family Martial Arts Center | -93.613464, 42.025351 | 203 | - | yes | way/237834128 |
| Papa Murphy's | -93.611648, 42.023077 | 196 | 1 | yes | way/236780159 |
| Iowa Subway Development | -93.610698, 42.026122 | 196 | 2 | office | way/853984845 |
| Cooks' Emporium | -93.614444, 42.025342 | 193 | 2 | retail | way/241720041 |
| Huss Law Office | -93.618911, 42.025509 | 191 | - | yes | way/519341367 |
| Ames Silversmithing | -93.612785, 42.024925 | 189 | - | yes | way/269752173 |
| Valor & Violet Salon | -93.614332, 42.024881 | 187 | - | yes | way/254335404 |
| Medicap Pharmacy | -93.610822, 42.023245 | 184 | - | yes | way/236780157 |
| The Great Plains Sauce & Dough Company | -93.611821, 42.025368 | 183 | - | yes | way/237834149 |
| Vision Bank | -93.61094, 42.025338 | 181 | - | yes | way/237834121 |
| Ames Smoke Shop | -93.613215, 42.023112 | 180 | 1 | yes | way/236780164 |
| In Spyrit Metaphysical | -93.613445, 42.023455 | 177 | 1 | yes | way/236565191 |
| Eastman Auto Care | -93.614212, 42.027156 | 177 | - | yes | way/853984699 |
| Dutch Oven Bakery | -93.611117, 42.024388 | 174 | 1 | yes | way/236780154 |
| Worldly Goods | -93.613097, 42.025351 | 174 | 2 | retail | way/237834123 |
| Hoyng Insurance Group | -93.615043, 42.027104 | 172 | 1 | yes | way/718052515 |
| SJB Hair Studio | -93.616157, 42.025702 | 171 | 1 | yes | way/241720045 |
| Ames Spine & Sport | -93.612552, 42.024913 | 170 | - | yes | way/269752174 |
| State Farm | -93.610675, 42.025458 | 169 | - | yes | way/237834151 |
| 5th Street Dental Office | -93.619124, 42.025616 | 166 | - | yes | way/519341368 |
| Sciota Trading | -93.618909, 42.025292 | 163 | 2 | yes | way/519341365 |
| Scooter's Coffee | -93.610047, 42.023157 | 162 | - | yes | way/982317724 |
| Hastings, Gartin & Boettger | -93.610696, 42.025694 | 160 | 1 | yes | way/853984844 |
| Chester's Coins & Gifts | -93.613021, 42.025351 | 157 | 2 | retail | way/237834134 |
| Corsanti Building | -93.611213, 42.026127 | 156 | 2 | apartments | way/310110558 |
| Heroic Hair | -93.61255, 42.025373 | 147 | - | yes | way/237834124 |
| The Hobby Shop | -93.612069, 42.02494 | 144 | - | yes | way/269752171 |
| Little Woods: Herbs and Teas | -93.611976, 42.024945 | 142 | - | yes | way/269752155 |
| Chic Beauty Salon | -93.612156, 42.024934 | 141 | - | yes | way/269752172 |
| London Underground | -93.612469, 42.024917 | 138 | - | yes | way/269752154 |
| Treats on a Leash | -93.612637, 42.024917 | 135 | - | yes | way/269752180 |
| The Frame Shop | -93.612395, 42.02492 | 133 | - | yes | way/269752159 |
| Acorn Antiques and Consignments | -93.614624, 42.025272 | 132 | 2 | retail | way/241720036 |
| AXA Advisors | -93.615174, 42.027563 | 131 | 2 | yes | way/1105577336 |
| Herrick Dental | -93.619271, 42.025608 | 128 | - | yes | way/853984679 |
| PhotoSynthesis | -93.614527, 42.025272 | 121 | 2 | retail | way/241720032 |
| Triad Chiropractic | -93.611702, 42.024959 | 120 | - | yes | way/269752169 |
| The Grove Cafe | -93.611538, 42.024969 | 112 | - | yes | way/269752153 |
| Gilger Designs | -93.613355, 42.024933 | 112 | - | yes | way/269752167 |
| Edward Jones | -93.612328, 42.024921 | 111 | - | yes | way/269752166 |
| Fringe Salon | -93.611128, 42.024994 | 93 | - | yes | way/269752163 |
| H&R Block | -93.61162, 42.024964 | 87 | - | yes | way/269752156 |
| Dave Fitz Electric | -93.610184, 42.023763 | 84 | 1 | yes | way/312090992 |
| Gannon Real Estate & Consulting | -93.611453, 42.024974 | 84 | - | yes | way/269752158 |
| Nations Financial Group | -93.613591, 42.027612 | 72 | - | yes | way/1242088604 |
| Satellite Communications | -93.611163, 42.025329 | 59 | - | yes | way/237834122 |
| Ann's Insurance | -93.61127, 42.024986 | 58 | - | yes | way/269752157 |
| A Stitch On Time | -93.611329, 42.024982 | 58 | - | yes | way/269752168 |
| Cyclone Barber | -93.611044, 42.025 | 48 | - | yes | way/269752161 |
| Ames Lock & Security | -93.617336, 42.025265 | 43 | - | yes | way/1246453468 |

### Everywhere else in the core (residential grids, S Duff, rail-corridor shops) — 155 named buildings

| name | center (lon, lat) | m2 | levels | building tag | OSM |
|---|---|---|---|---|---|
| CyRide | -93.635203, 42.027919 | 7105 | 2 | transportation | way/183344075 |
| Hy-Vee | -93.619617, 42.020023 | 6992 | - | yes | way/98658304 |
| Scheman Building | -93.636716, 42.021495 | 6123 | 2 | yes | way/180649660 |
| East Parking Deck | -93.642743, 42.025459 | 5430 | - | yes | way/183319697 |
| Materials Lab | -93.622141, 42.020515 | 4811 | - | yes | way/236094027 |
| McFarland Clinic | -93.612071, 42.033668 | 3940 | 6 | hospital | way/255604119 |
| Fitch Family Aquatic Center | -93.622818, 42.023277 | 3829 | - | yes | way/1557704182 |
| Warehouse | -93.623322, 42.020174 | 3341 | - | yes | way/103156222 |
| Repair Shop | -93.62112, 42.020197 | 2596 | - | yes | way/103156218 |
| Hub at Oak and Grand | -93.62211, 42.022047 | 2544 | - | yes | way/236094029 |
| 800 Lincoln Way | -93.62242, 42.02233 | 2444 | 3 | yes | way/103156214 |
| CenturyLink | -93.612516, 42.019755 | 2187 | - | yes | way/782468691 |
| St Thomas Aquinas Church & Catholic Student Center | -93.64497, 42.022243 | 2011 | 2 | yes | way/246252178 |
| Collegiate Presbyterian Church | -93.654772, 42.024887 | 1951 | - | yes | way/251728632 |
| Collegiate Presbyterian Church | -93.654772, 42.024887 | 1951 | - | yes | relation/3377215 |
| Sign Shop | -93.622169, 42.018983 | 1792 | - | yes | way/236094051 |
| Southpoint Centre | -93.611325, 42.01539 | 1754 | 1 | retail | way/774663111 |
| ALDI | -93.612219, 42.016906 | 1678 | - | yes | way/845880897 |
| Maplewood Apartments | -93.6256, 42.01874 | 1649 | 3 | apartments | way/310110055 |
| Medical Arts Building | -93.611058, 42.031657 | 1598 | - | hospital | way/255605672 |
| Story County Human Services | -93.613037, 42.021843 | 1531 | - | yes | way/236410781 |
| The Roosevelt | -93.623664, 42.030635 | 1506 | - | residential | way/260496177 |
| South Wing | -93.622103, 42.021479 | 1431 | - | yes | way/236094028 |
| Memorial Lutheran Church | -93.645922, 42.022334 | 1394 | - | yes | way/247519155 |
| Arnold Motor Supply | -93.616552, 42.022094 | 1288 | - | yes | way/236410782 |
| Dollar Tree | -93.610938, 42.021125 | 1275 | - | yes | way/260524828 |
| Frederiksen Court 82 | -93.641061, 42.031787 | 1272 | 3 | apartments | way/231380176 |
| Frederiksen Court 24 | -93.643556, 42.032744 | 1266 | 3 | apartments | way/231380160 |
| Frederiksen Court 35 | -93.642203, 42.035346 | 1266 | 3 | apartments | way/231380167 |
| Frederiksen Court 36 | -93.641162, 42.035345 | 1266 | 3 | apartments | way/231380170 |
| Frederiksen Court 81 | -93.640744, 42.032414 | 1266 | 3 | apartments | way/231380173 |
| Frederiksen Court 83 | -93.639673, 42.031846 | 1266 | 3 | apartments | way/231380180 |
| Ames Lab - Wilhelm Hall | -93.647333, 42.030229 | 1226 | 3 | yes | way/183214248 |
| Ames Lab - Technical and Administrative Services Facility (TASF) | -93.64843, 42.029996 | 1188 | 3 | yes | way/183763232 |
| Ortho2 | -93.612162, 42.012625 | 1146 | 1 | yes | way/237817477 |
| Boys & Girls Club | -93.61287, 42.01708 | 1090 | 1 | yes | way/774665656 |
| The Phoenix | -93.613256, 42.019325 | 1083 | 3 | apartments | way/905641420 |
| Days Inn by Wyndham Ames | -93.610797, 42.02059 | 1067 | 2 | yes | way/98658309 |
| Optimae LifeServices | -93.626334, 42.02255 | 1055 | - | yes | way/917962142 |
| Bike World | -93.611762, 42.019837 | 1051 | - | yes | way/196546800 |
| Frederiksen Court 33 | -93.640645, 42.034618 | 1000 | 3 | apartments | way/183195765 |
| Frederiksen Court 43 | -93.641955, 42.032775 | 1000 | 3 | apartments | way/183195767 |
| Frederiksen Court 62 | -93.64048, 42.033269 | 1000 | 3 | apartments | way/183195768 |
| Frederiksen Court 73 | -93.638597, 42.032991 | 1000 | 3 | apartments | way/183195593 |
| Frederiksen Court 34 | -93.641327, 42.034364 | 998 | 3 | apartments | way/183194927 |
| Frederiksen Court 63 | -93.640781, 42.032792 | 998 | 3 | apartments | way/183195498 |
| Frederiksen Court 41 | -93.642494, 42.032769 | 998 | 3 | apartments | way/183195507 |
| Frederiksen Court 74 | -93.639279, 42.03272 | 998 | 3 | apartments | way/183195491 |
| Frederiksen Court 42 | -93.642237, 42.033264 | 997 | 3 | apartments | way/183194938 |
| Frederiksen Court 32 | -93.641333, 42.034843 | 997 | 3 | apartments | way/183195478 |
| Frederiksen Court 61 | -93.641115, 42.033269 | 997 | 3 | apartments | way/183195763 |
| Frederiksen Court 31 | -93.642012, 42.034598 | 997 | 3 | apartments | way/183195764 |
| Frederiksen Court 72 | -93.639186, 42.033223 | 997 | 3 | apartments | way/183195575 |
| Frederiksen Court 71 | -93.639783, 42.033097 | 997 | 3 | apartments | way/183195582 |
| University Lutheran Center | -93.643277, 42.021134 | 971 | - | yes | way/241726009 |
| Delta Tau Delta | -93.642804, 42.021017 | 970 | - | yes | way/292313666 |
| Farm House | -93.644818, 42.019777 | 953 | 3 | yes | way/246252166 |
| First Baptist Church of Ames | -93.645901, 42.02073 | 941 | - | yes | way/247519149 |
| Unitarian Universalist Fellowship of Ames | -93.656152, 42.03158 | 922 | - | yes | way/1098315342 |
| Buildings & Grounds Shop | -93.623232, 42.01905 | 885 | - | yes | way/236094043 |
| Mike's Body & Frame | -93.623997, 42.024821 | 861 | 1 | yes | way/238454553 |
| Repair Shop Annex | -93.624877, 42.017832 | 837 | - | yes | way/236094033 |
| Alfred's Carpet & Decorating | -93.611823, 42.022622 | 830 | 1 | yes | way/236410775 |
| Frederiksen Court 12 | -93.643975, 42.034668 | 821 | 3 | apartments | way/183193991 |
| Frederiksen Court 22 | -93.643954, 42.033605 | 821 | 3 | apartments | way/183194108 |
| Frederiksen Court 51 | -93.639285, 42.034529 | 821 | 3 | apartments | way/183193746 |
| Frederiksen Court 53 | -93.638751, 42.033803 | 821 | 3 | apartments | way/183193751 |
| Frederiksen Court 23 | -93.643317, 42.033233 | 819 | 3 | apartments | way/183193990 |
| Frederiksen Court 11 | -93.644251, 42.034275 | 819 | 3 | apartments | way/183194115 |
| Frederiksen Court 13 | -93.6437, 42.034275 | 819 | 3 | apartments | way/183194160 |
| Frederiksen Court 21 | -93.64423, 42.033183 | 819 | 3 | apartments | way/183194161 |
| Building 6 | -93.621037, 42.020954 | 809 | - | yes | way/103156217 |
| District 1 Office | -93.624549, 42.018866 | 802 | - | yes | way/236094052 |
| CelebrationsWarehouse | -93.61402, 42.019885 | 799 | 1 | warehouse | way/1104795180 |
| Delta Chi | -93.644884, 42.021324 | 763 | 2 | yes | way/246252168 |
| Howe's Welding & Metal Fabrication | -93.610992, 42.014813 | 762 | - | yes | way/918074884 |
| Building 5 | -93.621041, 42.021482 | 761 | - | office | way/103156220 |
| Tau Kappa Epsilon | -93.643869, 42.02061 | 746 | - | yes | way/241726008 |
| Building 4 | -93.621051, 42.022013 | 737 | - | yes | way/103156216 |
| Beta Theta Pi | -93.640945, 42.022299 | 731 | 2 | yes | way/238398080 |
| AutoZone | -93.611151, 42.016723 | 728 | - | yes | way/338476422 |
| Auction Building | -93.622258, 42.018443 | 723 | - | yes | way/236094039 |
| YSS Family Counseling and Clinic | -93.61158, 42.020469 | 703 | - | yes | way/782468965 |
| Texas Roadhouse | -93.611085, 42.016252 | 696 | - | yes | way/338476423 |
| Triangle Fraternity | -93.641707, 42.022383 | 689 | - | yes | way/292313667 |
| Alpha Gamma Rho | -93.642347, 42.021153 | 643 | - | yes | way/241725994 |
| Alpha Delta Pi | -93.64162, 42.019849 | 617 | - | yes | way/241725992 |
| Chi Omega | -93.641215, 42.020416 | 613 | - | yes | way/241725997 |
| Perkins | -93.610978, 42.019148 | 603 | - | yes | way/196546807 |
| phClean - Ames | -93.614954, 42.02233 | 581 | 1 | yes | way/964840705 |
| Celebrations Party & Rental Store | -93.613603, 42.019871 | 577 | - | yes | way/782468950 |
| Hy-Vee Gas | -93.619095, 42.0226 | 574 | - | roof | way/236094031 |
| Darul Arqum Islamic Centre | -93.658526, 42.03386 | 563 | - | yes | way/652095881 |
| TS Bank | -93.61571, 42.022622 | 559 | - | yes | way/236410772 |
| Grandon Funeral & Cremation | -93.616033, 42.022577 | 555 | - | yes | way/236410771 |
| Knoll | -93.643598, 42.02362 | 554 | 3 | house | way/183324739 |
| Sigma Phi Epsilon | -93.640348, 42.020518 | 547 | - | yes | way/241726006 |
| Village Inn | -93.618129, 42.022631 | 545 | - | yes | way/103156221 |
| Sigma Kappa | -93.64114, 42.02001 | 542 | - | yes | way/241726005 |
| Pi Beta Phi | -93.643863, 42.021256 | 521 | - | yes | way/241726004 |
| Ames Church of the Nazarene | -93.613927, 42.02141 | 519 | - | yes | way/1104795179 |
| Panera Bread | -93.611109, 42.019824 | 510 | - | yes | way/196546803 |
| Delta Delta Delta | -93.643914, 42.019835 | 504 | - | yes | way/241725998 |
| Sigma Alpha Epsilon | -93.645737, 42.021287 | 504 | - | yes | way/247519146 |
| Phi Delta Theta | -93.641125, 42.021654 | 502 | - | yes | way/238398081 |
| Kappa Sigma | -93.644987, 42.020492 | 495 | 3 | yes | way/246252167 |
| Alpha Tau Omega | -93.641322, 42.022364 | 475 | - | yes | way/238398079 |
| Theta Chi | -93.644889, 42.020799 | 451 | 3 | yes | way/246252170 |
| Alpha Omicron Pi | -93.640034, 42.020171 | 450 | - | yes | way/241725995 |
| Gamma Phi Beta | -93.642111, 42.019775 | 448 | - | yes | way/241726001 |
| Express Pawn | -93.615052, 42.022588 | 447 | - | yes | way/236410773 |
| Delta Zeta | -93.642401, 42.020163 | 437 | - | yes | way/241726000 |
| Bernard Firm | -93.613255, 42.019885 | 437 | - | yes | way/782468914 |
| Alpha Phi | -93.644763, 42.020238 | 434 | 3 | yes | relation/14680048 |
| Phi Gamma Delta (FIJI) | -93.644874, 42.019404 | 432 | 3 | yes | way/246252169 |
| Pi Kappa Alpha | -93.640318, 42.022384 | 427 | - | yes | way/238398083 |
| McDonald's | -93.611025, 42.021857 | 424 | - | yes | way/236410780 |
| CarX | -93.610979, 42.017969 | 423 | - | yes | way/196546801 |
| Red Lobster | -93.610923, 42.013081 | 417 | - | yes | way/196541292 |
| Finesse Self Storage | -93.614458, 42.019816 | 409 | - | yes | way/1104795188 |
| Alpha Gamma Delta | -93.641647, 42.020525 | 394 | - | yes | way/241725993 |
| Phi Kappa Psi | -93.645848, 42.019904 | 393 | 3 | yes | way/247519143 |
| Kappa Delta | -93.641204, 42.020967 | 375 | - | yes | way/241726003 |
| Wandling Engineering | -93.6234, 42.024231 | 369 | 1 | yes | way/238454551 |
| Sigma Pi | -93.643933, 42.02092 | 357 | - | yes | way/241726007 |
| Motor Pool | -93.620941, 42.019732 | 354 | - | yes | way/103156212 |
| Delta Upsilon | -93.644868, 42.02203 | 349 | 3 | yes | way/246252165 |
| Casey's General Store | -93.616635, 42.022687 | 348 | - | roof | way/236094032 |
| Mass Mutual Financial Group | -93.616612, 42.02182 | 340 | 1 | yes | way/964840703 |
| ACACIA | -93.641599, 42.021593 | 338 | - | yes | way/238398078 |
| Beta Sigma Psi | -93.642073, 42.020316 | 327 | - | yes | way/241725996 |
| Casey's General Store | -93.616653, 42.022422 | 320 | - | yes | way/236094025 |
| Theta Delta Chi | -93.6449, 42.021059 | 313 | 3 | yes | way/246252171 |
| Track Storage | -93.646893, 42.014171 | 297 | - | yes | way/242895558 |
| Ames Eye Clinic | -93.612586, 42.031397 | 285 | - | yes | way/260923823 |
| Lebeda Matress Factory | -93.610627, 42.020388 | 278 | - | yes | way/98658320 |
| Celaya TexMex | -93.610687, 42.020952 | 278 | 1 | yes | way/300409284 |
| Arby's | -93.610921, 42.018599 | 266 | - | commercial | way/196546798 |
| The Parlor | -93.615918, 42.022122 | 264 | 1 | yes | way/236410783 |
| Phi Kappa Theta | -93.639883, 42.022377 | 264 | - | yes | way/238398082 |
| Taco Bell | -93.610988, 42.018138 | 244 | - | yes | way/196546809 |
| DQ Grill & Chill | -93.61434, 42.022622 | 235 | 1 | yes | way/236094047 |
| Mother's Pub | -93.65726, 42.02518 | 212 | - | yes | way/251728629 |
| Campus Garage | -93.655241, 42.023038 | 211 | - | yes | way/317113439 |
| T-Mobile | -93.610799, 42.01577 | 194 | - | yes | way/782468336 |
| West Street Deli | -93.656245, 42.025174 | 164 | 1 | yes | way/251728626 |
| Hickory Shelter | -93.630633, 42.030045 | 163 | - | roof | way/55875377 |
| Martin House | -93.612988, 42.022699 | 154 | 2 | house | way/1014233739 |
| 1+1 Restaurant & Tea | -93.656421, 42.025152 | 138 | 2 | yes | way/251728622 |
| Maple Shelter | -93.629485, 42.028862 | 120 | - | roof | way/260180372 |
| Thumbs | -93.656521, 42.025152 | 109 | 1 | yes | way/251728624 |
| The Pier | -93.655408, 42.025552 | 105 | 2 | house | way/251810709 |
| Aisles Online | -93.620068, 42.020807 | 104 | 1 | service | way/1105093113 |
| Linden Shelter | -93.629456, 42.0302 | 99 | - | roof | way/260180376 |
| Troy's Barber Shop | -93.655802, 42.025496 | 66 | 1 | yes | way/251728627 |

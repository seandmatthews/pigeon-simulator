# Ames Survey — Verification & Reconciliation (corrections ledger)

Date-stamped: **2026-11-08**.
Role: settle the disputes and UNVERIFIED flags across the four sibling lanes so the
master plan can treat **this document** as ground truth where siblings disagree.

**Method / authority order:**

1. **Local OSM dataset** — `../osm/raw/ames_merged.json` (309,870 nodes / 37,531 ways /
   251 relations, pulled 2026-11-08). Parsed independently of the siblings with
   `scripts/verify_osm.py` + `scripts/probe2.py` (both in this directory). Way/relation
   IDs and coordinates below are quoted from that file so every claim is re-runnable.
2. **Web corroboration** — cited per item (campus maps, Ames Historical Society, DNR,
   Wikipedia articles fetched in full, team/facility pages, local news).
3. Sibling text is quoted only to identify what is being corrected. Nothing in the
   sibling files was edited; verdicts live here.

Confidence levels: **settled** (machine-checkable or two independent sources),
**high**, **medium**, **open**.

---

## 1. THE ORIENTATION DISPUTE — settled

**Verdict (plain map fact):** Lincoln Way runs due east–west at lat 42.0227–42.0229
through the survey area. **Central ISU campus — including the Memorial Union, the
Campanile and Parks Library — lies NORTH of Lincoln Way. Campustown (the Welch Avenue
bar strip) lies SOUTH of Lincoln Way.** Students cross Lincoln Way *southbound* out of
campus into Campustown. The true west→east order of the Campustown avenues is
**Sheldon, Hayward, Welch, Stanton**.

The venues lane (`../venues/VENUES.md` §0) is **right on all three points**. The
landmarks lane (`../landmarks/LANDMARKS.md` §1) is **wrong** and must be flipped. The
OSM lane's §5 block-gap numbers are correct but its **"west→east" label is reversed**.

### OSM evidence (ames_merged.json)

| Query | Result |
|---|---|
| Lincoln Way ways (`name=Lincoln Way`, ~40 ways) | Dead E–W: node lats in the Campustown window (lon −93.662…−93.628) span 42.02267–42.02288, mean **42.02278** (n=139). Bbox heights of individual ways are 0–13 m over hundreds of metres — no diagonal. |
| Memorial Union (way **183224150**, `addr=2229 Lincoln Way`, `building=university`, `building:levels=6`, `wikipedia=en:Memorial Union (Iowa State University)`) | lat **42.02317–42.02416**, lon −93.64643…−93.64510 (≈110×110 m) — **entirely north** of Lincoln Way's 42.0227–42.0229 line. |
| Central-campus buildings | All **north** of Lincoln Way: Campanile (−93.64604, **42.02542**), Parks Library (−93.64874, **42.02811**), Beardshear Hall (−93.64843, **42.02620**), Curtiss Hall (−93.64474, **42.02617**), MacKay Hall (−93.64644, **42.02862**), Marston Water Tower (−93.65076, **42.02699**), Morrill Hall (−93.64804, **42.02720**), Farm House Museum (−93.64394, **42.02716**). |
| Campustown commercial polygon (way **918491523**, `name=Campustown`, `landuse=commercial`) | lat **42.02029–42.02271** — entirely **south** of Lincoln Way; 748×269 m, bbox center (−93.65100, 42.02150). Matches the OSM lane's dims exactly. |
| Welch Avenue ways | Run from Lincoln Way (42.02275) **south** to 42.01186 — ~1.2 km, south side only. Hayward likewise south. |
| Welch-avenue venues | Cy's Roost (−93.65040, 42.02195), BNC Field House (−93.64972, 42.02122), Stomping Grounds building (−93.65062, 42.02008), Legacy Tower (−93.64916, 42.02194) — all south of Lincoln Way, lat 42.0200–42.0221. |
| Named streets crossing Lincoln Way (mean lon of nodes within the corridor band) | West→east: Franklin −93.6648, Wilmoth −93.6616, Manning −93.6599, **State −93.65914, Howard −93.65845, Campus −93.65704, Hyland −93.65558, Sheldon −93.65424, Hayward −93.65173, Welch −93.65015, Stanton −93.64850, Morrill Rd/Lynn −93.64645, Ash −93.64440, Union Dr −93.64278, Gray −93.64202, Beach −93.63949, University Blvd −93.63333**, Riverside −93.6298, Russell −93.6284, Hazel −93.6268, Maple −93.6253, Oak −93.6238, Elm −93.6221, Grand −93.6202, Gilchrist −93.6175, Walnut/Clark −93.6169, Washington −93.6154, Kellogg −93.6137, Sherman −93.6121, … Duff −93.6104. |

### Web corroboration

- [Ames Historical Society, *Walking Tour of Campustown* (PDF)](https://ameshistory.org/sites/default/files/Campustown%20Tour%202021_final_print.pdf): "The two block stretch of Welch **south of Lincoln Way** is lined with bars and eateries…"
- [Iowa State Daily letter on Campustown redevelopment](https://www.iowastatedaily.com): the redevelopment zone is "**south of Lincoln Way, from Stanton to Hayward Avenue**."
- Wikipedia's [Memorial Union (Iowa State University)](https://en.wikipedia.org/wiki/Memorial_Union_(Iowa_State_University)) article (fetched in full): gives the address 2229 Lincoln Way and says the building "complements the designs of the major buildings surrounding the University's Central Campus area" (Beardshear, Curtiss, MacKay — all north of Lincoln Way). No side statement, so the OSM geometry is the decisive source.

### Corrections to siblings

- `../landmarks/LANDMARKS.md` §1 — **flip**: "Campustown (Welch Ave bars/shops) sits just north of it" is wrong (Campustown is south); "Lincoln Way forms the campus's northeast edge" is wrong (Lincoln Way passes along the **south** side of central campus at the Campustown stretch, separating it from Campustown and the sports campus); "Lincoln Way (old Lincoln Highway, diagonal-ish NE–SW through town)" is wrong (bearing 269.3°, dead E–W); "the commercial grid is roughly 1.5 km northeast of the Memorial Union" is wrong (Main×Duff is **2.93 km due east** of the MU — Main×Duff lon −93.61043 vs MU −93.64584).
- `../landmarks/LANDMARKS.md` §1 University-Blvd reading: University Blvd crosses Lincoln Way at **−93.63333, east of Campustown** — it is the west edge of the *sports complex* (stadium center −93.6358 is west of the boulevard) but the east approach to central campus. The landmarks lane's "University Blvd on the west/southwest edge and Lincoln Way on the north" is a misreading.
- `../osm/SUMMARY.md` §5 — the crossing list labelled "west→east from Duff" actually runs **east→west** (it starts at Duff and walks west). The true west→east order is the reverse: State, Howard, Campus, Hyland, Sheldon, Hayward, Welch, Stanton, Morrill/Lynn, Ash, Union Dr, Gray, Beach, University Blvd, Riverside, Russell, Hazel, Maple, Oak, Elm, Grand, Gilchrist, Walnut/Clark, Washington, Kellogg, Sherman, … Duff. The measured gap numbers themselves check out (e.g. Stanton→Welch 136 m, Welch→Hayward 130 m, Hayward→Sheldon 208 m).
- `../venues/VENUES.md` §0 — **confirmed as written** (including claim 3: Welch addresses increase going south, odd west / even east — verified below in the spot-check).

Confidence: **settled** (OSM geometry + Ames Historical Society + ISD all agree).

---

## 2. Corrections ledger

| ID | Item | Siblings' claims | Verdict | Evidence | Confidence |
|---|---|---|---|---|---|
| V-01 | Campus vs Campustown sides of Lincoln Way | LANDMARKS §1: Campustown north of Lincoln Way; VENUES §0: south | **VENUES right; LANDMARKS flipped** | OSM way 183224150 (MU) + all central-campus buildings north of LW; Campustown polygon + venues south; Ames Hist. Soc. tour quote | settled |
| V-02 | Campustown avenues W→E | SUMMARY §5 list labelled W→E; VENUES: actually E→W, true order Sheldon, Hayward, Welch, Stanton | **VENUES right** | Mean lons: Sheldon −93.65424 < Hayward −93.65173 < Welch −93.65015 < Stanton −93.64850 | settled |
| V-03 | Lincoln Way alignment | LANDMARKS §1: "diagonal-ish NE–SW" | **Wrong — dead E–W (269.3°)** | LW node lats constant ±0.0001° over 11 km | settled |
| V-04 | Downtown–MU distance | LANDMARKS §1: "roughly 1.5 km northeast" | **Wrong — 2.93 km due east** | Main×Duff −93.61043 vs MU −93.64584 | settled |
| V-05 | SUMMARY §4 "Duff Avenue … at lon ≈ −93.6154" | — | **Typo: Duff downtown is at −93.6104** (−93.6154 is the Burnett/Washington line). TL;DR distances reconcile with the fix: Main×Duff→Campanile **2,945 m** (claimed 2,940), →Lincoln×Welch **3,285 m** (claimed 3,290), →MU 2,929 m | Duff-node mean lon at Main lat = −93.61042; downtown gap chain Clark→Duff = 538 m matches the §5 gaps | settled |
| V-06 | Main Street numbering direction | VENUES §1.14 Great Plains "near Clark (100 block, west end)"; §3.16 Morning Bell "downtown west end"; §2.12 Aunt Maude's "Main's east end"; §2.6 Cornbred "downtown's east end"; §5.2 sequence labelled "west→east" | **Numbers increase WESTWARD; the 100 block is the EAST end (at Duff).** Great Plains (129, −93.61183) is near **Duff/Douglas** (its "near Duff" phrase is right, "near Clark/west end" wrong); Morning Bell (111) is the east end; Aunt Maude's (547) and Cornbred (526) are at the **west** end (~Clark by interpolation); §5.2's sequence as written runs **east→west** — reverse it | OSM: 111 Main −93.61110, 119 −93.61139, 123 −93.61155, 125 −93.61172, 129 −93.61183, 134 −93.61183, 212 −93.61246, 229 −93.61338 (monotonic westward) | settled |
| V-07 | Campanile vs Parks Library N/S | LANDMARKS C1: Campanile "S of Parks Library, N of MU"; LANDMARKS C4: Parks "S of Campanile" | **Internal contradiction; C1 right, C4 wrong.** Parks Library (42.02811) is NORTH of the Campanile (42.02542), which is north of the MU (42.02317–42.02416) | OSM building centroids | settled |
| V-08 | Memorial Union corner | LANDMARKS C5 + §5: "corner Lincoln Way & Stanton Ave" | **Off by one block: the MU is at the Lincoln Way & Morrill Rd/Lynn Ave corner, one block east of Stanton** (Stanton −93.64850, Lynn/Morrill −93.64645, MU spans −93.64643…−93.64510). Lake LaVerne's east shore touches the Morrill Rd corridor and the MU's west edge | OSM MU way + crossing scan; Wikipedia gives no cross street | settled (geometry), medium (naming) |
| V-09 | Jack Trice field orientation | LANDMARKS C6: "Wikipedia states the field runs east–west, unusual for D-I — single source" | **The field runs NORTH–SOUTH (standard), and Wikipedia contains no orientation claim at all — the citation is a misquote** | OSM pitch way 101135481 "MidAmerican Field pitch": bbox **53 m E–W × 113 m N–S** (long axis N–S); stadium bowl way 613735866 183×208 m, longer N–S; CycloneFanatic: "The playing field runs North and South"; GamedayGuides: "The field runs north–south… the west side is the institutional side — the three-level press box" | settled |
| V-10 | Jack Trice capacity gap | LANDMARKS: 61,500; OSM tag: 55,000 | **Official = 61,500 (since 2015). OSM's 55000 is a stale tag matching the 2007–2012 era.** History: 42,500 (1975) → 48,000 (1976–94) → 43,000 (1995–2001) → 45,814 (2002–05) → 46,721 (2006) → **55,000 (2007–12)** → 56,800 (2013) → 54,800 (2014) → **61,500 (2015 south-end-zone enclosure)**; record attendance 61,500 (Sept 5, 2015) | Wikipedia (fetched: full capacity table) + cyclones.com | settled |
| V-11 | Jack Trice hillside / videoboard | LANDMARKS: north end zone grass hillside; videoboard 36×79.5 ft since 2011 | **Confirmed**: GA grass-berm seating in the NE and NW corners (north end zone); videoboard over the Jacobson Building, 36 ft × 79.5 ft, added 2011. Press tower on the **west** sideline | Ticket/seat sources (koobit); Wikipedia (fetched); GamedayGuides | settled |
| V-12 | Lake LaVerne area | DNR 2.80 ac (11,330 m²) vs OSM 1.11 ha (11,050 m²) | **Same lake; 2.5 % polygon-simplification gap. Game number: 2.8 acres (≈11,300 m²) of open water.** OSM ring recomputed: relation 3329428 → chained outer ring, **11,053 m² = 2.73 ac**, bbox 236×122 m, center (−93.64792, 42.02354) — matches SUMMARY §7 exactly | DNR Fish Iowa LAV85: Surface Area 2.80 ac | settled |
| V-13 | Swans Lancelot & Elaine | LANDMARKS: "Elaine retired Nov 2022"; community: "one swan died ~2022, other removed" | **Both partially right — merge:** Lancelot **died** June 2022 (found June 20, 2022, natural causes; pair on the lake since 2003); Elaine **retired** Nov 2022 (moved to a pond near Woodward). No replacement pair as of the Aug–Sep 2025 thread — restoration first | [Inside Iowa State, Nov 17 2022](https://www.inside.iastate.edu/article/2022/11/17/elaine); [Ames Tribune, Nov 18 2022](https://www.amestrib.com/story/news/2022/11/18/iowa-state-university-lake-laverne-swan-to-retire-new-pair-arriving-soon-isu/69658215007); Inside Iowa State June 23 2022 (Lancelot) | settled |
| V-14 | Lake LaVerne dredging state | LANDMARKS: $5.1M, 2024–28, depth 1.7→3.7 m (5.5→12 ft) | **Add dated fact: the lake was DRAINED mid-2026** for the dredge (game should model the refilled lake); news says refill targets ~5 ft average, **up to 13 ft** deep — 12 vs 13 ft discrepancy noted, use the project page value (3.7 m) until ISU publishes the as-built | DNR temporary-fishing-regulation notice + local coverage (search) | high |
| V-15 | Fareway addresses | LANDMARKS T4: "store #792 at 534 S Duff Ave"; VENUES §5.1/§7: "Fareway (3720 L/W + 534 S Duff)" | **534 S Duff is the Walmart Supercenter (OSM way 186655755, addr=534 South Duff Avenue) — both lanes wrong.** The full grocery is **Fareway, 619 Burnett Ave** (OSM way 102723486, shop=supermarket). **3720 Lincoln Way is Fareway Meat Market #189** (5,363 sq ft building, built 2016) — real, but a meat market, not "the local grocery institution". Ames full stores: 619 Burnett + 3619 Stange Rd. Store number "#792" unconfirmed — drop it | [fareway.com/meatmarkets/189](https://www.fareway.com/meatmarkets/189); store locator; OSM | settled |
| V-16 | Clouds café floor | Community: "12th level of Legacy Tower"; VENUES: 7th floor per cloudsames.com | **7th floor — VENUES right.** Legacy Tower is 10 levels in OSM (way at 119 Stanton, 60×38 m — VENUES's footprint confirmed), so a 12th-floor café is impossible | [cloudsames.com/location-hours](https://www.cloudsames.com/location-hours); [Ames Tribune, Jan 16 2020](https://www.amestrib.com/story/business/2020/01/16/campustown-cafe-offers-unique-experience/1883707007) (~100 ft up, opened Oct 2019) | settled |
| V-17 | Stadium pedestrian bridge | LANDMARKS C13: "In 2026 ISU was also building a pedestrian bridge over University Blvd"; community: Oct 2024 "The Bridge on East side of the stadium, it's new" | **The East Gateway Pedestrian Bridge ("Cy Walk") over University Blvd opened ~2024** (span installed June 2022, ~$10M; Iowa Stater Fall 2024 describes it in use). LANDMARKS's 2026 "building" line is stale — the community quote is the current state | [Substance Architecture project page](https://substancearchitecture.com/projects/athletics/iowa-state-university-east-gateway-pedestrian-bridge); [Iowa Stater, Fall 2024](https://iowastater.iastate.edu/fall-2024/article/cy-walk); [Wells construction](https://wells.build/projects/isu-jack-trice-east-gateway-bridge) | settled |
| V-18 | People's Bar & Grill closure date | Community: "not pinned"; VENUES: May 31, 2007 | **~2007 stands as the best available** (no primary article found). Added context: People's occupied the old People's Drugstore building on Lincoln Way (basement bar "Lumpy's"); the site later became the Campustown CVS; Charlie Yoke's succeeded People's in the same room — all consistent with VENUES's account | [CycloneFanatic In Memoriam thread](https://cyclonefanatic.com/forum/threads/in-memoriam-ames-business-restaurants.237059/page-44); [CVS-to-open thread (2014)](https://cyclonefanatic.com/forum/threads/cvs-pharmacy-to-open-in-campustown.190509) | medium |
| V-19 | The Cafe's location | VENUES §1.13: "2616 Northridge Pkwy (ISU Research Park, **south of campus** — NOT North Loop Dr)" | **Address right; "south of campus" wrong.** Northridge Parkway is in **north** Ames (OSM ways span lat 42.045–42.056, the Northridge Heights/Village area). Sister restaurant Provisions Lot F (2400 N Loop Dr, OSM way 846310912 at −93.63565, 42.00053) IS in the south research park — they are ~4.5 km apart | OSM Northridge Parkway extents; [DMR/ISD listings](https://www.desmoinesregister.com) ("north Ames") | settled |
| V-20 | East-of-Welch Lincoln Way order | VENUES §4/§5.1: "The Foundry (2300) … then 23 Twenty Lincoln (2320)" | **Swapped.** South-side L/W addresses increase **westward** (3605 Szechuan −93.66734 < 3720 Fareway −93.66857 < 3800 Hy-Vee −93.66990; 2650 Dunkin' −93.65389 < 2546 US Bank −93.65148). Correct W→E: … Dunkin' (2650), U.S. Bank (2546), Mr. Burrito (2508), Café Beaudelaire (2504), **[Welch]**, 23 Twenty (2320, −93.64756), The Foundry (2300, −93.64692), Memorial Lutheran (2228, −93.64595), St Thomas Aquinas (2210, −93.64495). Jeff's (2402) sits between Welch and 23 Twenty — VENUES's "just east of Welch" is right | OSM addr-tagged buildings, monotonic chain | high |
| V-21 | Kum & Go vs Welch Ave Station | VENUES §1.1: "Kum & Go's … store at #203 **opposite**" the 207 building | **Both on the WEST side of the 200 block** (OSM: Kum & Go way 231767147 at −93.65054, 42.02125, W of Welch centerline −93.65012). The opposite (east) row is Campustown Court 204 / BNC 206 / Superdog 208. VENUES §4's own fly-through already had it right; §1.1's "opposite" is the error | OSM addr tags | settled |
| V-22 | Welch Ave address parity | VENUES §0 claim 3: addresses increase south; odd W / even E | **Confirmed** by OSM anchors: 116 Macubana E (−93.64986), 117 Ichiban W (−93.65038), 121 Cy's Roost W (−93.65040), 132 Fire Stn 2 E (−93.64970), 203 Kum & Go W (−93.65054), 204 Campustown Court E (−93.64997), 206 BNC E (−93.64972), 217 Welch Crown Center W (−93.65059), 303 commercial W (−93.65062) | OSM addr tags | settled |
| V-23 | Reiman Gardens area | LANDMARKS: 17 ac (6.9 ha); OSM way: 7.3 ha (18.1 ac) | **Use official 17 ac (6.9 ha)**; the OSM `leisure=garden` way is slightly generous (boundary/parking). Footprint 414×475 m and Conservatory 59×88 m confirmed | OSM way 180765023; reimangardens.com | settled |
| V-24 | Brookside Park area | LANDMARKS: 83 ac (33.6 ha, city figure); OSM way: 38.9 ha (96.2 ac) | **Use the city figure 83 ac for "the park"; use the OSM polygon for the shape** — the OSM way 44806238 likely includes the Ioway Creek corridor/greenway beyond the city park boundary | OSM shoelace area | high |
| V-25 | Central Campus lawn | LANDMARKS: ~20 ac (8.1 ha); OSM "Central Campus" leisure=park: 8.5 ha (21.1 ac) | Consistent — game uses **~8.3 ha** | OSM way 486943973 | settled |
| V-26 | Airport position | LANDMARKS T5: "~2 mi SE of downtown" | **Essentially due S, slightly W (SSW): 3.84 km S, 0.53 km W of Main×Duff; 3.9 km total.** Distance ~right; compass direction loose | OSM airport center (−93.62188, 41.99047) | settled (minor) |
| V-27 | US-30 "Dakota/Elwood" interchange | LANDMARKS T9 lists "Dakota/Elwood" | **"Elwood" is almost certainly the old name of University Boulevard** (renamed ~2000s). Effective interchange list for the game: Dayton, Grand, Dakota, University Blvd, Duff/S Duff + I-35 | Naming history (search); OSM University Blvd geometry | medium |
| V-28 | Jack Trice address | Wikipedia: 1798 South 4th Street; OSM relation: 1732 South 4th Street | Minor conflict between sources; the game should place the stadium **west of University Blvd**, Jack Trice Way along its north side, and not lean on either house number | Wikipedia (fetched); OSM relation 11545732 | high (minor) |
| V-29 | VENUES §7 operating-status flags (Thumbs; Lost and Found Lounge; Stomping Grounds/Bar La Tosca; Public House 2520; El Maguey conflict; Welch reconstruction completion; Labyrinth suite; Cafe Diem summer closure) | Flagged UNVERIFIED by VENUES | **Carried forward unchanged** — my checks neither confirmed nor overturned them. Note: OSM 2520 Chamberlain IS tagged "Public House" (apartment building, 5 levels) — the venue-name evidence remains web-only. El Maguey stays "do not bake in" (Stacker 2025 vs Yelp CLOSED) | OSM way 334936864; sibling web sources | open |
| V-30 | LANDMARKS UNVERIFIED list (MU tower height; Reiman canopy spans; grain-elevator heights; tailgate lot names) | Flagged by LANDMARKS | See §4 — MU tower and canopy: **unknowable from sources, model to look**; grain elevators: **unknowable + unmapped in OSM**; tailgate lot names: still open | Searches + OSM scan (zero `grain_elevator`/`storage_tank`/`silo` elements; zero height tags on industrial ways) | see §4 |

---

## 3. Venue position spot-check — 10 Tier-1 venues

"Exact" = address-tagged building found in `ames_merged.json` with matching name.
"Parity" = no addr tag in the extract (an OSM completeness gap, not an error);
side verified from the established numbering rules (V-22: odd=W/even=E on Welch;
V-20: addresses increase westward on Lincoln Way's south side).

| # | Venue | VENUES claim | OSM evidence | Web | Verdict |
|---|---|---|---|---|---|
| 1 | Welch Ave Station | 207 Welch, W side of 200 block, between Chamberlain & Hunt | No addr tag; parity anchors 203 W / 217 W / 204 E / 206 E bracket it | welchave.com/location; discoverames.com listing | **CONSISTENT** (parity) |
| 2 | Paddy's Irish Pub | 124–126 Welch, E side of 100 block | No addr tag; parity anchors 116 E / 132 E | Dec 2025 liquor license "126 Welch" | **CONSISTENT** (parity) |
| 3 | Cy's Roost | 121 Welch, W side of 100 block | **Exact**: way 241365820, (−93.65040, 42.02195), W of Welch −93.65012, amenity=bar, 2 levels | Jan 14 2025 license renewal | **CONFIRMED exact** |
| 4 | Sips | 126 Welch, basement of Paddy's building | Same building as #2 (one facade, two doors) | THE SCENE LLC DBA "Sips and Paddy's", Dec 2025 | **CONSISTENT** |
| 5 | Mickey's Irish Pub | 109 Welch, W side of 100 block, at the Lincoln Way end | No addr tag; parity odd=W; first block off Lincoln Way | Dec 9 2025 council minutes | **CONSISTENT** (parity) |
| 6 | AJ's Ultra Lounge | 2401 Chamberlain, east of Welch, entrance on Chamberlain | **Exact**: way 246079558 "AJ's Ultralounge", amenity=bar, 3 levels, (−93.64880, 42.02156) — east of Welch | 2025 council agenda | **CONFIRMED exact** |
| 7 | Outlaws | 2522 Chamberlain, west of Welch | **Exact**: way 272522425 "Outlaws", amenity=bar, 2 levels, (−93.65125, 42.02121) — west of Welch | venue listings | **CONFIRMED exact** |
| 8 | Café Beaudelaire | 2504 Lincoln Way, S side, W of Welch corner | No addr tag; anchored by 2546 US Bank (−93.65148) and 2650 Dunkin' (−93.65389) S-side; sits just west of Welch | cafebeaudelaire.com | **CONSISTENT** (interpolated ±50 m, as VENUES itself flagged) |
| 9 | Jeff's Pizza Shop | 2402 Lincoln Way, S side, just east of Welch | No addr tag; numbering places it between Welch and 23 Twenty (−93.64756) | jeffspizzashop.com | **CONSISTENT** (interpolated) |
| 10 | Mr. Burrito | 2508 Lincoln Way, two doors W of Café B | No addr tag; numbering direction (higher = further west, V-20) confirms "two doors west" | mrburritoia.com | **CONSISTENT** (interpolated) |

Bonus exacts: **Hickory Park** 1404 S Duff — way 196541966 at (−93.60955, 42.00998); **BNC Field House** 206 Welch E — way 241365816; **Kum & Go** 203 Welch W — way 231767147; **Little Taipei** 2514 Chamberlain W — way 241365808 (closed venue, room confirmed); **Fire Station 2** 132 Welch E — way 231767150 "Ames Fire Department Station 2"; **Time Out** 120 Kellogg — way 236565187; **Torrent Brewing** 504 Burnett — way 931902030; **Legacy Tower** 119 Stanton — way 236800162, 10 levels, 60×38 m.

**Result: 10/10 no mismatches.** All block-side and cross-street claims in VENUES's
Tier-1 list check out against OSM + web (with the V-21 wording fix). The OSM extract
simply lacks addr tags for ~6 strip venues — worth a mapping pass, not a correction.

---

## 4. Flagged dimensions — dispositions

| Item | Disposition | Number to use |
|---|---|---|
| **Memorial Union tower height** | **Unknowable.** No authoritative source states it (mu.iastate.edu/architecture says nothing; Wikipedia infobox height field is empty; nothing in ISU Facilities pages surfaced). The ~148 ft figure circulates unsourced — likely confusion with the nearby 110-ft Campanile. OSM tags the building `building:levels=6` and a bogus default `height=9`. | Do **not** bake in any number. Model the tower to look (a slender rooftop/entrance tower on a ~110×110 m, 6-level Georgian block); if a number is needed for tooling, use "≈35–45 m, UNVERIFIED". |
| **Reiman Gardens entrance-canopy spans** | **Unknowable.** No sourced dimension found (official site describes the butterfly-wing canopy but gives no span). OSM has the garden (way 180765023), conservatory (59×88 m, h=10), Butterfly Wing (way 479976960) — no canopy geometry. | Model as a large sculptural wing-form canopy over the entry drive, scale to look; keep UNVERIFIED. |
| **Grain-elevator heights (SE cluster)** | **Unknowable + unmapped.** OSM contains zero grain-elevator POIs, storage tanks or silos in the survey area, and no web source gives Ames-specific silo heights. | Keep LANDMARKS's placeholder (typical Iowa concrete silos ≈30–40 m / 100–130 ft) marked UNVERIFIED; eyeball the S Duff/SE-16th cluster against aerials when modeling. |
| **Jack Trice field orientation** | **Settled: north–south** (V-09). Wikipedia never claimed east–west. | Field long axis N–S; press/institutional side **west**; grass hillside NE/NW corners; videoboard at the north end. |
| **Jack Trice capacity 55,000 vs 61,500** | **Settled** (V-10): OSM tag is the 2007–2012 value. | **61,500** official (since 2015). Footprint: fenced relation bbox 234×303 m; stadium bowl way 183×208 m. |
| **Lake LaVerne 2.80 ac vs 1.11 ha** | **Settled** (V-12): same lake, 2.5 % polygon-simplification gap. | **2.8 acres (≈11,300 m²)** open water, footprint 236×122 m, center (−93.64792, 42.02354). Definition: open-water surface at normal pool. |

---

## 5. Master plan ground truth

Use these as the final numbers/orientations where siblings disagreed.

**Orientation (the big one)**

- Lincoln Way: due E–W, lat 42.0227–42.0229. **Downtown Ames AND central ISU campus
  are north of it; Campustown and the sports campus are south of it.**
- Campustown avenues west→east: **Sheldon, Hayward, Welch, Stanton**
  (−93.6542, −93.6517, −93.6501, −93.6485); State Ave is the west gateway (−93.6591),
  University Blvd the east gate (−93.6333), with Morrill Rd/Lynn (−93.6465) and Ash
  (−93.6444) between Stanton and University Blvd. Union Drive meets Lincoln Way at
  −93.6428 (the 2021 underpass site).
- Memorial Union: north side of Lincoln Way at the **Morrill Rd/Lynn** corner (one
  block east of Stanton), 110×110 m, 6 levels; Lake LaVerne's east shore touches the
  Morrill corridor just west of it.
- Welch Avenue runs south from Lincoln Way ~1.2 km (lat 42.0228→42.0119). Addresses
  increase southward; odd west / even east.
- Lincoln Way south-side addresses increase **westward** (3800 Hy-Vee → 3720 Fareway
  Meat Market → 3605 Szechuan House → 2650 Dunkin' → 2546 U.S. Bank → 2508 Mr.
  Burrito → 2504 Café B → [Welch] → 2320 23 Twenty → 2300 The Foundry → 2228 Memorial
  Lutheran → 2210 St Thomas).
- Downtown Main Street addresses increase **westward**; the 100 block is the east end
  at Duff. Correct west→east venue sequence: Aunt Maude's (547) → Cornbred BBQ depot
  (526) → Torrent (504 Burnett) → Cafe Diem (229 N) → London Underground (212 S) →
  Whiskey River (134 S) → Great Plains (129 N) → Sam's Place (125 N) → Grove Cafe
  (124 S) → Sportsman (123 N) → Mary Jane's (119 N) → Morning Bell (111 N).
  Downtown cross streets west→east: Northwestern (−93.6210), Grand (−93.6202), Pearle
  (−93.6195), Clark (−93.6169), Burnett (−93.6154), Kellogg (−93.6137), Douglas
  (−93.6121), Duff (−93.6104). (Burnett continues south of Lincoln Way under the name
  Washington.)
- Grid: E–W streets 269–271°, N–S streets 359–180° — build axis-aligned to true north
  (visible exceptions per SUMMARY §5 stand: Sheldon 356°, Stange 12°, University Blvd
  curved, UP line 93.7°).

**Key coordinates / distances** (all reconcile with the OSM extract)

- Campanile (−93.64604, 42.02543); MU centroid (−93.64584, 42.02373); Lake LaVerne
  center (−93.64792, 42.02354); Campustown polygon center (−93.6510, 42.0215);
  Jack Trice Stadium center (−93.6358, 42.0139); Welch×Lincoln Way (−93.65015, 42.0228).
- Main×Duff → Campanile **2.94 km**; Main×Duff → Lincoln Way×Welch **3.29 km**;
  Main×Duff → MU **2.93 km due east**; Campanile → Lake LaVerne **~264 m**; Campanile →
  stadium **1.53 km**. (SUMMARY TL;DR distances stand; only §4's Duff lon was off.)

**Settled dimensions**

- Campanile 33.5 m (110 ft), 50 bells — unchanged.
- Marston Water Tower 51.2 m (168 ft) — unchanged.
- Jack Trice Stadium: capacity **61,500**; field **north–south**; bowl 183×208 m;
  fenced footprint 234×303 m; press tower **west** side; grass hillside NE/NW corners;
  videoboard north 36×79.5 ft; East Gateway pedestrian bridge over University Blvd
  **open since ~2024**; address on South 4th Street (1732 vs 1798 — use neither).
- Lake LaVerne: **2.8 acres (≈11,300 m²)** open water, 236×122 m; swans absent since
  2022 (Lancelot died June 2022, Elaine retired Nov 2022); lake drained mid-2026 for
  dredging — model the refilled lake, ~5 ft average / max 3.7 m (12 ft, project figure).
- Memorial Union tower height: **unknown — model to look** (do not use ~148 ft).
- Reiman Gardens: **17 acres (6.9 ha)** official; conservatory 59×88 m; canopy spans
  **unknown — model to look**.
- Fareway: full store at **619 Burnett Ave** (+ 3619 Stange Rd); **3720 Lincoln Way is
  a Fareway Meat Market (#189)**; **534 S Duff is Walmart**.
- Clouds café: **7th floor** of Legacy Tower (10 levels, 119 Stanton, west side).
- The Cafe: **2616 Northridge Pkwy, north Ames**; Provisions Lot F: 2400 N Loop Dr,
  south research park.
- Central Campus lawn ~8.3 ha (8.1–8.5 ha figures agree); Brookside Park **83 ac city
  figure** (OSM polygon 96 ac includes creek corridor); Reiman 17 ac official.
- Hilton Coliseum 14,267; Campustown polygon 748×269 m; downtown blocks 125–137 m —
  all unchanged (no sibling disputes).

---

## 6. Remaining OPEN items (priority order)

1. **Grain-elevator heights** (SE cluster) — skyline-relevant; settle by measuring
   against aerial imagery / a commissioning doc for the S Duff–SE 16th elevators.
   Until then: 30–40 m placeholder, UNVERIFIED.
2. **Memorial Union tower height** — unknowable from sources; model to look. If a
   doc-ever surfaces (ISU Facilities drawing set), re-pin it. Do not use ~148 ft.
3. **Reiman Gardens entrance-canopy spans** — unknowable; model to look.
4. **Aunt Maude's (547 Main) and Cornbred/depot (526 Main) exact cross-streets** —
   number-interpolation puts the 500 block near Clark/Pearle; not addr-tagged in OSM.
   One imagery check settles both.
5. **OSM addr quirk: two buildings tagged 2320 Lincoln Way** (23 Twenty Lincoln and
   University Towers). Numbering monotonicity says 23 Twenty is the true 2320;
   University Towers needs its real number (likely 2300-block east of The Foundry).
6. **Fire Station 1 at 1300 Burnett (1980)** — plausible, unconfirmed by OSM (Station 2
   and 3 are tagged; 1 is not). One city-page check.
7. **Lake LaVerne post-dredge depth** — 12 ft (ISU project page) vs 13 ft (2026 news);
   re-check when the project completes. (Lake is drained as of this writing.)
8. **VENUES operating-status flags** (Thumbs, Lost and Found Lounge, Stomping
   Grounds/Bar La Tosca, Public House, El Maguey conflict, Welch reconstruction
   completion, Labyrinth suite, Cafe Diem summer closure) — re-verify each before
   baking a name into a build; businesses churn fast.
9. **Tailgate lot names** around the stadium/Iowa State Center — still unnamed by any
   source; the game can use generic lots.
10. **Brookside Park boundary definition** (city park 83 ac vs OSM polygon 96 ac incl.
    creek corridor) — pick per game need; not a factual error.
11. **"Elwood" interchange naming** — confirm Elwood Dr = old University Blvd from a
    city rename record (cosmetic; the interchanges themselves are clear).

---

## 7. File manifest

| File | What it is |
|---|---|
| `verification/VERIFICATION.md` | This corrections ledger (the deliverable). |
| `verification/scripts/verify_osm.py` | Full-dataset analysis: Lincoln Way geometry, LW crossing order, MU/campus buildings, Campustown polygon, avenue extents, addr-tag venue scan, stadium/pitch bboxes, Lake LaVerne ring area, park areas, height/grain scan. |
| `verification/scripts/probe2.py` | Follow-up probes: downtown Main cross-street order, Main Street extents, named-venue POI scan, stadium relation tags, distance recomputes. |

Inputs read (not modified): `../landmarks/LANDMARKS.md`, `../osm/SUMMARY.md`,
`../community/REDDIT-RESONANCE.md`, `../venues/VENUES.md`, `../osm/raw/ames_merged.json`.

Primary web sources used: [Ames Historical Society Campustown tour](https://ameshistory.org/sites/default/files/Campustown%20Tour%202021_final_print.pdf) ·
[Wikipedia: Jack Trice Stadium](https://en.wikipedia.org/wiki/Jack_Trice_Stadium) ·
[Wikipedia: Memorial Union (ISU)](https://en.wikipedia.org/wiki/Memorial_Union_(Iowa_State_University)) ·
[DNR Fish Iowa LakeDetails LAV85](https://programs.iowadnr.gov/lakemanagement/fishiowa/LakeDetails/LAV85) ·
[Inside Iowa State: Elaine retires](https://www.inside.iastate.edu/article/2022/11/17/elaine) ·
[Ames Tribune: swan retirement](https://www.amestrib.com/story/news/2022/11/18/iowa-state-university-lake-laverne-swan-to-retire-new-pair-arriving-soon-isu/69658215007) ·
[Fareway Meat Market #189](https://www.fareway.com/meatmarkets/189) ·
[cloudsames.com/location-hours](https://www.cloudsames.com/location-hours) ·
[Ames Tribune: Clouds](https://www.amestrib.com/story/business/2020/01/16/campustown-cafe-offers-unique-experience/1883707007) ·
[Substance Architecture: East Gateway Bridge](https://substancearchitecture.com/projects/athletics/iowa-state-university-east-gateway-pedestrian-bridge) ·
[Iowa Stater Fall 2024: Cy Walk](https://iowastater.iastate.edu/fall-2024/article/cy-walk) ·
[Wells: East Gateway Bridge](https://wells.build/projects/isu-jack-trice-east-gateway-bridge) ·
[CycloneFanatic: In Memoriam (People's)](https://cyclonefanatic.com/forum/threads/in-memoriam-ames-business-restaurants.237059/page-44) ·
[CycloneFanatic: CVS replaces People's](https://cyclonefanatic.com/forum/threads/cvs-pharmacy-to-open-in-campustown.190509).

*Verification lane, 2026-11-08.*

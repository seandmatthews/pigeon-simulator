# Ames, Iowa — OpenStreetMap survey for the city rebuild

**Date of data pull & analysis: 2026-11-08.** All numbers below were computed from a
fresh OpenStreetMap extract of Ames and should be re-checked against OSM if a long
time has passed (Ames gets actively mapped; CyRide and campus data were touched as
recently as 2023–2024 per `check_date` tags).

This file is written for a game developer: meters, compass bearings, WGS84 lat/lon.
No GIS jargon. Every claim names the extract/script that produced it (see
[Provenance](#provenance--file-manifest) at the bottom).

---

## 1. Where the data came from

- **Plan A (Overpass API) failed from this network.** `overpass-api.de` resets the
  TLS handshake; `overpass.kumi.systems` returns 504 after ~77 s; `overpass.osm.jp`,
  `overpass.private.coffee` time out; `maps.mail.ru` 504s; `overpass.osm.ch` answers
  but serves a Switzerland-only extract (empty results for Ames — verified).
- **Plan B (used): the main OSM API** (`api.openstreetmap.org/api/0.6/map.json`).
  The survey bbox was swept as a 6×7 grid of 42 tiles (0.025° lon × 0.012° lat
  each), merged into one dataset. The OSM API returns *complete* ways (with every
  referenced node), so street geometry is not truncated at tile seams.
- Survey bbox: **lat 42.00…42.08, lon −93.69…−93.56** (W−S−E−N = −93.69, 42.00,
  −93.56, 42.08). Merged contents: **309,870 nodes, 37,531 ways, 251 relations**.
- Ames city verification: OSM `place=city` node **Ames** at **(−93.61704, 42.02676)**.
  The urban grid sits well inside the survey bbox (city fabric spans roughly lat
  42.005…42.055 in the bbox; Ada Hayden park at 42.068 and the Squaw Valley
  neighborhood at 42.071…42.078 are the northernmost mapped bits). Complete ways do
  spill past the bbox edges (e.g. Lincoln Highway continues east to −93.36; the
  Ames Municipal Airport at (−93.62188, 41.99047) lies just *south* of the bbox but
  was captured anyway because its ways are complete).
  *(source: ames_merged.json; scripts/extra.py "extents"; poi mode "PLACE nodes")*

**Conversion factors at Ames (42.02° N)** — use these to eyeball anything yourself:
1° latitude ≈ **111,074 m**; 1° longitude ≈ **82,700 m**. So 0.001° lon ≈ 83 m,
0.001° lat ≈ 111 m.

---

## 2. TL;DR — headline numbers for the game

| What | Value |
|---|---|
| Proposed **game-core bbox** | lon −93.6590…−93.6100, lat 42.0120…42.0355 → **≈ 4,050 m (E–W) × 2,610 m (N–S)**, ~10.6 km² |
| Street grid | essentially cardinal: E–W streets bearing 269–271°, N–S streets 359–180° (≤1° off true N/S) |
| Downtown block (centerline to centerline) | **125–140 m** along Main Street (and along Lincoln Way) |
| Downtown ↔ campus (Main St×Duff → Campanile) | **2.94 km due east** |
| Downtown ↔ Campustown (Main×Duff → Lincoln Way×Welch) | 3.29 km |
| Campanile ↔ Jack Trice Stadium | 1.53 km |
| ISU campus (university polygon) | 3,561 × 5,160 m incl. outlying parcels; built core ≈ 2,800 × 2,700 m |
| Lake LaVerne | **236 × 122 m, 1.11 ha (2.7 acres)** |
| Jack Trice Stadium | 234 × 303 m footprint (55,000 capacity tag — stale 2007–12 value; official 61,500 since 2015, ledger V-10) *(QA fix 2026-11-08 per QA-REPORT item 8 / A-29)* |
| UP rail yard | tagged yard tracks span 1,464 × 235 m ENE of downtown; full multi-track corridor ≈ 2.9 km; **no Amtrak/passenger rail in OSM** |
| Named streets in survey bbox | 727 names, 485.6 km of mapped road (full list: `streets.csv`) |

---

## 3. Proposed GAME-CORE bounding box

This is the box the game should build at true scale. It unions every "must" feature
from the design brief (campus + Campustown + Lincoln Way corridor + downtown +
Lake LaVerne + the stadium) with a small margin, and rounds to 4 decimals:

```
W edge  lon −93.6590   (State Avenue corridor)
E edge  lon −93.6100   (South Duff Avenue corridor)
S edge  lat  42.0120   (just south of Jack Trice Stadium's south rim)
N edge  lat  42.0355   (Frederiksen Court / north downtown residential grid)

corners (WGS84):
  SW (−93.6590, 42.0120)   SE (−93.6100, 42.0120)
  NW (−93.6590, 42.0355)   NE (−93.6100, 42.0355)
center  (−93.6345, 42.02375)
size    4,053 m E–W × 2,610 m N–S  (≈ 10.6 km²)
```

What's inside (verified against the extracts): the whole Lincoln Way corridor from
State Ave to Duff Ave, Campustown (Lincoln/Welch/Hayward/Sheldon commercial
polygon), downtown (Main Street, 5th, 6th, Duff, the "Downtown" landuse polygon,
City Hall), Lake LaVerne, central campus + south campus + the towers, Jack Trice
Stadium, University Blvd's northern half, the Cyclone Sports Complex, and 3,733
building footprints with 99.6 km of named street. *(source: scripts/analyze.py
`core`/`streets`; scripts/extra3.py)*

Deliberately just outside (cheap optional extensions):
- **South to lat 42.0030** (+1.0 km): Reiman Gardens, ISU Vet Med campus, Gateway
  Park. Reiman Gardens alone is a 414 × 475 m garden at (−93.63832, 42.01057).
- **North to lat 42.0500** (+1.6 km): Moore Memorial Park, Inis Grove Park, the
  Somerset village.
- Farther out (probably never worth building): Ada Hayden Heritage Park
  (1,500 × 1,798 m, lake 860 × 1,125 m) at 42.068; Ames Municipal Airport at
  41.990; the UP yard's eastern tail past −93.56.

---

## 4. Street inventory — spine streets

All named streets (727 names) are in **`streets.csv`** with orientation, class,
length, way count and bbox per name. Highlights (lengths are mapped way length,
which double-counts dual carriageways and junction flares slightly):

| OSM name | Orientation (bearing) | Class | Length | Notes |
|---|---|---|---|---|
| **Lincoln Way** | E–W (269.3°) | primary | 11,124 m | THE E–W main drag, lat 42.0229. Name changes to **"East Lincoln Way"** exactly at Duff Ave (the eastern continuation, 4,024 m, secondary). Extent as "Lincoln Way": 6,732 m from lon −93.6918 to Duff. |
| **Main Street** | E–W (269.1°) | residential+tertiary | 824 m | downtown spine, lat 42.0251, runs Northwestern Ave → Duff Ave. Only **244 m north of Lincoln Way** (the UP line runs between them). |
| **Duff Avenue** | N–S (359.1°) | secondary | 3,705 m | downtown N–S spine at lon ≈ −93.6104; downtown's east edge. *(QA fix 2026-11-08: −93.6154 → −93.6104 per QA-REPORT item 8 / A-25 — ledger V-05 typo fix; −93.6154 was the Burnett/Washington line.)* |
| **South Duff Avenue** | N–S | primary | 4,372 m | continues south of Lincoln Way, shifted east to lon ≈ −93.6101. |
| **Grand Avenue** | N–S (180.0°) | primary | 8,466 m | west-downtown N–S spine at lon ≈ −93.6216; "South Grand Avenue" (2,676 m) continues south. |
| **University Boulevard** | diagonal/curved (net 314°) | secondary | 8,110 m | crosses Lincoln Way at lon −93.6334; N–S extent 3.6 km, bends E–W south of campus. |
| **Mortensen Road** | E–W (270.9°) | tertiary | 4,173 m | SW-of-campus E–W street at lat 42.013. |
| **South 16th Street** | E–W | secondary | 2,309 m | south Ames E–W at lat 42.0100 ("Southeast 16th Street", 2,866 m, continues east at 42.0083). |
| **Stange Road** | N–S with NNE drift (11.7°) | secondary+residential | 5,966 m | west/north Ames, lat 42.028…42.073. **Does not reach Lincoln Way** (south end is around Mortensen/Ontario). |
| **Welch Avenue** | N–S (179.5°) | residential | 1,251 m | Campustown street #1, lon −93.6498. |
| **Burnett Avenue** | N–S (359.5°) | residential | 2,296 m | ⚠ exists but it's a **downtown** street (lon −93.6159, north of Main). The same line at Lincoln Way is named **Washington Avenue**. Burnett does not cross Lincoln Way. |
| **Hayward Avenue** | N–S (179.6°) | residential | 1,220 m | Campustown, lon −93.6517. |
| **Sheldon Avenue** | N–S (356.1°, kinks) | tertiary+residential | 1,052 m | Campustown, lon −93.6549. |

All five "verify which exist" Campustown candidates exist in OSM: Welch, Hayward,
Sheldon are the Campustown N–S runs; **Burnett is downtown, not Campustown** — that
part of the brief should be corrected. *(source: ames_merged.json via
scripts/analyze.py `streets`, bearings via scripts/extra.py; Lincoln Way crossings
via `spine "Lincoln Way"`)*

### Top 20 named streets by length (of 727)

| Name | Orient | Class | Length |
|---|---|---|---|
| 190th Street (rural N edge) | E–W | secondary | 17,314 m |
| Lincoln Way | E–W | primary | 11,124 m |
| 200th Street (rural S) | E–W | residential | 8,890 m |
| 570th Avenue (rural E) | N–S | residential+tertiary | 8,156 m |
| Grand Avenue | N–S | primary | 8,466 m |
| University Boulevard | diag | secondary | 8,110 m |
| North Dakota Avenue | N–S | residential+secondary | 7,076 m |
| George Washington Carver Avenue | N–S | tertiary+secondary | 6,996 m |
| Stange Road | N–S | secondary | 5,966 m |
| West 190th Street | E–W | residential | 5,620 m |
| North Dayton Avenue | N–S | secondary | 5,487 m |
| East 13th Street | E–W | secondary | 5,123 m |
| Airport Road | E–W | secondary | 4,952 m |
| Bloomington Road | E–W | tertiary | 4,944 m |
| 13th Street | E–W | secondary | 4,843 m |
| South Duff Avenue | N–S | primary | 4,372 m |
| Mortensen Road | E–W | tertiary | 4,173 m |
| East Lincoln Way | E–W | secondary | 4,024 m |
| Duff Avenue | N–S | secondary | 3,705 m |
| South Dakota Avenue | N–S | secondary | 3,675 m |

(The "190th/200th/570th" names are Story County rural grid roads crossing the
survey bbox corners — ignore for the city build.)

---

## 5. Street grid & block sizes

**Downtown (Main Street corridor, lat 42.0251).** Cross streets west→east:
Northwestern/Grand, Pearle, Clark, Burnett, Kellogg, Douglas, Duff. Centerline-to-
centerline gaps along Main Street: **125–137 m** (Clark→Burnett 125, Burnett→Kellogg
136, Kellogg→Douglas 137, Douglas→Duff 137). Main Street → 5th Street spacing is
**≈ 86 m**; 5th → 6th ≈ **105 m**. *(QA fix 2026-11-08: "≈80 m / ≈205 m" → 86/105 per
QA-REPORT item 8 / A-27 — census §2 re-measurement, adopted by specs F-10; the old
pair does not reproduce from the extract.)* So: **typical downtown block ≈ 130 m**, with one
skinny block between Main and 5th.

**Lincoln Way corridor (lat 42.0229).** Cross streets east→west from Duff: *(QA fix
2026-11-08: "west→east" label reversed per QA-REPORT item 8 / A-26 — ledger §1: the
list starts at Duff and walks west; the gap numbers stand.)*
Sherman (141 m), Kellogg (130), Washington (141), Walnut/Clark (124), Gilchrist
(101), Grand (169), Elm (152), Oak (129), Maple (119), Hazel (128), Russell (128),
Riverside (106), University Blvd (295), Beach (503), Gray (209), Union Drive (62),
Ash (135), Morrill/Lynn (165), Stanton (173), Welch (136), Hayward (130), Sheldon
(208), Hyland (111), Campus (120), Howard (117), State (57+117). Same ≈ **110–140 m
block rhythm** as downtown; the wide gaps (Beach 503, University 295) are real —
those are the campus/greenway edges.

**Campustown block structure** (Lincoln Way frontage): Stanton→Welch 136 m,
Welch→Hayward 130 m, Hayward→Sheldon 208 m (Sheldon is offset north at its south
end), Sheldon→Hyland 111 m, Hyland→Campus 120 m. The named "Campustown" commercial
polygon measures **748 × 269 m (11 ha)**, centered (−93.65101, 42.02150), wrapping
Lincoln Way between ~Hyland Ave and ~Morrill Rd/Lynn. *(QA fix 2026-11-08: "between
State Ave and Sheldon" corrected per QA-REPORT item 8 / B-10 — OSM probe: polygon
bbox lon −93.65554…−93.64649; State Ave lies ~296 m west of the polygon edge and
Sheldon sits inside it.)* Welch/Hayward each run ~1.2 km N–S
(from Lincoln Way's south side up past the commercial strip); Sheldon ~1.0 km.
*(source: scripts/analyze.py `spine "Lincoln Way"` / `spine "Main Street"`; poi mode landuse list)*

**Grid rotation:** downtown N–S streets bear 359.0–359.5° (≈1° west of true north);
E–W streets 269–271°. Campustown N–S streets bear 179.3–179.6°. Grand Avenue is
exactly 180.0°. For the game: **build the grid axis-aligned to true north**; the
sub-degree real-world tilt is imperceptible at game scale. Exceptions that ARE
visible: Sheldon Ave (356°), Stange Rd (12°), University Blvd (curves, net 314°),
and the UP rail line (93.7° through town, cutting diagonally across the N–S grid
just south of Main Street).

---

## 6. Campus & Campustown geometry

- **ISU campus** = OSM relation 3501275, `amenity=university`, bbox
  **lon −93.6690…−93.6259, lat 42.0011…42.0475 → 3,561 × 5,160 m**. The polygon
  includes outlying ISU parcels (north to the Somerset-area villages, south past
  Vet Med). The **built core** (buildings inside the 42.012…42.036 ×
  −93.660…−93.620 window) measures ≈ **2,825 × 2,663 m** — use that for the campus
  in-game; the full polygon is for reference.
- **Vet Med campus** is a separate `amenity=university` polygon: 997 × 869 m at
  (−93.63332, 42.00755), i.e. ~1.5 km SE of the stadium.
- Campus center for distance math: the **Campanile**, a 7 × 7 m footprint at
  **(−93.64604, 42.02543)** (OSM way named "Campanile", building=university).
  Lake LaVerne is 264 m from it; Jack Trice Stadium 1.53 km.
- **Campustown**: see §5 — 748 × 269 m commercial polygon along Lincoln Way,
  spanning ~Hyland Ave to ~Morrill Rd/Lynn (not State→Sheldon — see §5's QA fix
  2026-11-08 per QA-REPORT item 8 / B-10).
- Campus flavor from the data: 4,186 buildings sit inside the campus polygon bbox
  (incl. non-ISU ones in that rectangle); central campus green
  ("Central Campus" leisure=park 287 × 424 m), Lied Recreation Field, the
  Bergan Track (173 × 99 m), Cyclone Sports Complex (218 × 387 m), Recreation
  Trail footway network (7,365 footway ways city-wide — perfect pigeon perch
  density). CyRide (the city's bus system) is mapped with hundreds of stop nodes
  incl. the Iowa State Center station at (−93.63366, 42.01889).
  *(source: poi mode; highway class counts; station node scan)*

---

## 7. Water

| Feature | OSM facts |
|---|---|
| **South Skunk River** | one long `waterway=river` way + riverbank relation; mapped extent lat 41.93…42.105. **Runs due N–S at lon ≈ −93.594 through the whole city** (verified at lat 42.005, 42.015, 42.025, 42.035 — within ±30 m of −93.595), i.e. ~1.6 km east of Duff Ave, then bends NW north of town (at 42.045 it's at −93.605, at 42.055 at −93.615). |
| **Ioway Creek** | ✔ **confirmed renamed** — every waterway is tagged "Ioway Creek"; **zero** waterways named "Squaw Creek". Legacy "squaw" survives only in non-water tags: TIGER import tags, an apartment address "Squaw Creek Drive", a "Squaw Valley" residential landuse (42.071…42.078), and a rural "Squaw Road" at 42.077. Path: meanders north through the **campus–downtown gap at lon ≈ −93.629** (lat 42.025), hooks east/south-east around lat 42.012…42.017 toward the Skunk; mapped bank network 12.4 × 16.4 km, ~100 km of bank lines. |
| **College Creek** | the campus creek: 27 ways, ~5.0 × 1.2 km, crosses all of campus W→E (at lat 42.025 it runs lon −93.6505…−93.6310) and joins Ioway Creek just NE of the Greek houses. |
| **Lake LaVerne** | multipolygon of two chained outer ways (0.0 m gap — verified): **236 × 122 m bbox, area 11,050 m² = 1.11 ha = 2.73 acres**, center (−93.64802, 42.02357). The famous swan plaques are mapped as nodes next to it. |
| **Ada Hayden Lake** | 860 × 1,125 m, 52.1 ha, at 42.0674 (north Ames). |
| Others | Worrell Creek, Clear Creek, Onion Creek (S/SE), Arnold Lake 253 × 261 m, Johnson Pond 127 × 119 m, Lake Helen 52 × 40 m. |

*(source: ames_merged.json via scripts/analyze.py `water`; ring assembly in
scripts/extra2.py; river latitudes probed ad hoc)*

---

## 8. Rail

- **Main line = "UP Clinton Subdivision"**, `usage=main`, `operator=Union Pacific
  Railroad`, `old_railway_operator=C&NW` (the ex-Chicago & North Western Overland
  Route), gauge 1435, maxspeed 70 mph, PTC-tagged. 38.4 km of main-line track
  mapped across the corridor. Through town it bears **93.7°** (E–W with a slight
  southward tilt), passing **44 m from the Main St × Duff Ave intersection** — i.e.
  it squeezes between Main Street and Lincoln Way right along downtown's south
  edge, then angles ENE toward the yard.
- **⚠ No Amtrak / passenger rail exists in OSM for Ames.** There are no
  `railway=station`/`halt` nodes, no passenger tags on any line — only CyRide bus
  stations. The brief's "Amtrak line through town" is not supported by the data;
  the through line is UP freight (Amtrak's nearest service to Ames runs on a
  different corridor entirely). If the game wants a passenger stop, it would be
  fiction (or the historic depot treated as scenery).
- **The yard (confirmed, ENE of downtown):** 14 ways tagged `railway=rail` +
  `service=yard`, total 7,141 m of yard track, combined bbox
  **1,464 m E–W × 235 m N–S centered (−93.56138, 42.02948)**, i.e. ~2.3 km ENE of
  downtown. The wider multi-track corridor (yard + spurs + sidings, ≥500 track-m
  per 250 m cell) spans **≈ 2.9 km along the line from lon −93.589 to −93.554 at
  lat 42.026…42.031**, and continues east past the survey bbox edge. OSM carries no
  "hump" tag, so the hump itself can't be confirmed from this extract — but the
  track density (up to ~2.5 track-km in a single 250 m cell) is unmistakably a
  classification yard. The main line bridges (layer=1) cross the yard at
  −93.559…−93.560.
- **Second line:** UP "Jewell Subdivision" (`usage=branch`, 9.0 km mapped) plus an
  unnamed parallel rail pair ~3.7 km long (bbox 3.7 × 0.5 km centered
  −93.6765, 42.0372) leaving the corridor NW of downtown — the branch toward
  Gilbert/Jewell. 7.1 km of `railway=abandoned` also mapped.
- *(source: scripts/analyze.py `rail`; scripts/extra.py density grid; scripts/extra3.py yard bbox; station scan in extra3.py)*

---

## 9. Landmarks & POIs (WGS84 centers, footprint bboxes)

| Landmark | Center (lon, lat) | Footprint (m) | OSM tags of note |
|---|---|---|---|
| Jack Trice Stadium | (−93.63576, 42.01401) | 234 × 303 | leisure=stadium, capacity=55000, sport=american_football; inner pitch "MidAmerican Field" 53 × 113 m; building way 183 × 208 m |
| Hilton Coliseum | (−93.63477, 42.02100) | 138 × 105 | building=stadium, sport=basketball |
| Campanile | (−93.64604, 42.02543) | 7 × 7 | building=university (way "Campanile") |
| Lake LaVerne | (−93.64802, 42.02357) | 236 × 122 | natural=water multipolygon, 1.11 ha |
| Reiman Gardens | (−93.63832, 42.01057) | 414 × 475 | leisure=garden (7.3 ha way) + Conservatory building 59 × 88 m (≈2,994 m², way 180765068 — the WHOLE "Reiman Gardens Conservatory"; the named Hughes glasshouse inside it is 465 m² / 5,000 sq ft). *(QA fix 2026-11-08 per QA-REPORT item 1 / B-03 — do not model "Hughes" as the 59×88 box.)* |
| Campustown | (−93.65101, 42.02150) | 748 × 269 | landuse=commercial |
| Downtown | (−93.61652, 42.02605) | 995 × 411 | landuse=commercial |
| Ames City Hall | (−93.61775, 42.02636) | 82 × 78 | amenity=townhall |
| Brookside Park | (−93.63115, 42.03049) | 733 × 898 | leisure=park (38.9 ha way) |
| Moore Memorial Park | (−93.65406, 42.04526) | 853 × 781 | leisure=park relation |
| Inis Grove Park | (−93.61250, 42.04764) | 274 × 417 | leisure=park (10.3 ha) |
| Ada Hayden Heritage Park | (−93.63095, 42.06808) | 1,500 × 1,798 | leisure=park relation; lake 860 × 1,125 m |
| Iowa State Center (bus hub) | (−93.63366, 42.01889) | — | amenity=bus_station, CyRide |
| Ames Municipal Airport | (−93.62188, 41.99047) | 1,090 × 2,341 | way (aeroway), just S of survey bbox |
| Iowa DOT district office | (−93.62267, 42.02002) | 416 × 636 | landuse=commercial |

Other useful mapped POIs: Cyclone Sports Complex (218 × 387 m), Southeast
Recreation Complex (336 × 597 m), Ames Municipal Power Plant (riverside, at
−93.6088, 42.0254), Bandshell Park, the Ames "Downtown Gateway" commercial strip
(786 × 186 m at −93.61524, 42.02380). 54 named parks total in the bbox.
*(source: poi mode of scripts/analyze.py)*

---

## 10. Caveats for the rebuild

- Street *lengths* are summed way lengths — a dual carriageway or slip lanes count
  twice; extents (bbox) are the safer "how long is this street" number.
- OSM has **no lane/width detail** for most Ames streets (defaults only); road
  widths in-game must come from defaults (≈ 10–12 m two-lane residential, wider
  for Lincoln Way/Duff/S Grand primaries) or aerial guesswork.
- The rail yard's east tail and the airport sit at/beyond the survey bbox edges —
  the data there is complete but thin (the API returns complete ways, but only
  those touching the bbox).
- Relation "area" figures computed on multipolygon relations (campus, riverbanks,
  Moore/Ada Hayden parks) are approximations from unordered outer rings — the bbox
  dimensions are reliable, treat the hectares as ±20 %.
- `streets.csv` groups by exact OSM name; directional variants are separate rows by
  design ("Duff Avenue" vs "South Duff Avenue", "Grand Avenue" vs "South Grand
  Avenue", "Lincoln Way" vs "East Lincoln Way").

---

## Provenance / file manifest

| File | What it is |
|---|---|
| `raw/tile_r00c00.json` … `raw/tile_r06c05.json` | 42 raw OSM API tile extracts (bbox W−93.69 S42.00 E−93.56 N42.08, grid 0.025°×0.012°), fetched 2026-11-08 from `api.openstreetmap.org/api/0.6/map.json` |
| `raw/ames_merged.json` | merged dataset (309,870 nodes / 37,531 ways / 251 relations) — the single source behind every claim above |
| `raw/_tilelist.txt` | the tile grid used by the sweep |
| `scripts/roads.ql`, `water.ql`, `rail.ql`, `pois.ql` | Overpass queries per the original plan (kept for re-use when Overpass is reachable again; **not** the source of today's data) |
| `scripts/make_tiles.py`, `fetch_tiles.sh` | tile sweep generator/fetcher (OSM API) |
| `scripts/build_dataset.py` | tile merger |
| `scripts/analyze.py` | analysis: streets/water/rail/poi/spine crossings/distances/core bbox |
| `scripts/extra.py`, `extra2.py`, `extra3.py` | follow-ups: yard density grid, Lake LaVerne ring, bearings, yard bbox, station scan, river latitudes |
| `streets.csv` | full street inventory: 727 named streets (name, orientation, classes, length_m, ways, bbox, center) |

Claim → source map (all against `raw/ames_merged.json`):
- §2/§3 core bbox, building/street totals → `analyze.py core` + `streets`, `extra3.py`
- §4 spine table/bearings → `analyze.py streets` + `extra.py` bearings
- §5 blocks/crossings → `analyze.py spine "Main Street"` / `spine "Lincoln Way"`
- §6 campus → ISU relation 3501275, Vet Med way, Campanile way (poi mode); building counts via `extra.py`
- §7 water → `analyze.py water`, ring assembly `extra2.py`, river latitude probes
- §8 rail → `analyze.py rail`, density grid `extra.py`, yard bbox + station scan `extra3.py`
- §9 landmarks → `analyze.py poi` (relation/way ids printed there: stadium relation, Lake LaVerne relation 3329428, etc.)

*Survey by the research agent, 2026-11-08.*

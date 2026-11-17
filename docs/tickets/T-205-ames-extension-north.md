# T-205 — Ames R5 · north: Ada Hayden and the north parks

- **Status:** done · **Category:** worldbuilding · **Ring:** R5 The Town ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-203
- **Refs:** `osm/SUMMARY.md` (+1.6 km north option) ·
  `landmarks/LANDMARKS.md` (Ada Hayden twin quarry lakes; trail
  length) · `images/nature/01-04` (4 refs) · T-198 (The Cafe's staged
  sign finally places — 2616 Northridge Pkwy is here)

## What

+~1.6 km north:

- **Ada Hayden Heritage Park**: the twin quarry lakes as water flats
  (the north-Ames big-water read — photos 01/02), gravel trail ring,
  the quarry-banked shore character.
- **Inis Grove + Moore Memorial parks** as green massing + trails.
- **North Ames residential fabric** (the census's north blocks).
- **The Cafe** un-staged: T-198's staged sign places at 2616
  Northridge Pkwy (the noted dependency closes).
- Data pack v4, re-bake, bbox pins.

## Why

The lake is north Ames's identity (and the game's best soaring water
read); The Cafe's placement closes the last open Tier-1 commitment.

## Acceptance criteria

- [x] Twin lakes at data geometry; trail ring walkable-adjacent;
      parks + fabric per data
- [x] The Cafe signed at its true position (T-198's staged sign
      placed; its pin moves from staged to live)
- [x] *(Gate 1b)* `ames_extension_north`: lake geometry pins; bbox
      consts; The Cafe position pin moves
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass.

## Run record (T-205, 2026-11-17)

**The flip.** Status → doing in this file and the index row before any
code moved (the flip rides the feat commit's content).

**THE NORTH EDGE — the ticket's What corrected by its own data,
recorded up front.** The What header says "+~1.6 km north" (SUMMARY §3's
option lands N 42.0500 and covers Moore Memorial, Inis Grove, The Cafe
and the Somerset fabric). But the What's FIRST bullet and the acceptance
criteria put ADA HAYDEN HERITAGE PARK in the build — twin quarry lakes at
data geometry, the trail ring walkable-adjacent — and the committed
survey data places that park at lat 42.05999..42.07618 (relation
12032468, 1500 × 1798 m; SUMMARY §3 itself lists it under "farther out,
probably never worth building"). A box at 42.0500 stops ~2 km short of
the lake the ticket names as north Ames's identity and the ACs demand at
data geometry. Landing the acceptance criteria verbatim therefore grows
the box past the park: **N 42.0355 → 42.0780, +4,720.6 m** through the
pack's own transform — covering the whole park way, its Ada Hayden Road
(bbox north 42.07794), Grand Avenue's north end, the Moore Memorial /
Inis Grove / Calhoun parks, The Cafe (2616 Northridge Pkwy, lat 42.04874)
and the north residential blocks. W/S/E and the origin are the
census/T-203/T-204 lines, untouched. The override is recorded in the
pack's version history, `meta.bbox_north_note` (asserted by the gate to
name Ada Hayden), and this record.

**The extension, mechanical.** `tools/ames_distill.py`: CORE N edge →
42.0780; the census §6 rule gains its THIRD strip (buildings north of
the stamped `core_bbox_north_v3` 42.0355, disjoint from the east/south
guards, the east guard still winning the NE corner); parks join NAMED
leisure=park RELATIONS north of the v3 edge, one entry per closed outer
ring (Ada Hayden 12032468, Moore Memorial 14721919's TWO DISJOINT rings,
Calhoun 12463402; Emma McCarthy Lee — already in-core but
relation-mapped — stays a recorded data grain of the pre-v4 rule);
`build_water` gains the named-lake rule (NAMED natural=water closed ways
≥ 1 ha in core → lake entries with the survey's shore character in
`bank`: Ada Hayden Lake = "quarry", Arnold Lake sits east of the core
edge and stays out; **LaVerne keeps water()[0]** — the swans read the
first lake, so the named lakes sort after it); `build_trails` joins the
north parks' mapped trail runs (footway/path/cycleway/pedestrian whose
midpoints sit inside the Ada Hayden / Inis Grove / Moore Memorial rings,
holes excluded, runs stitched like streets). Byte-identity held: two
consecutive `python -I tools/ames_distill.py` runs → the same pack
SHA-256 (a78fadaf…).

**The strip numbers** (v3 → v4, the distill's own counts): buildings
4,960 → 10,783 (north strip 5,622 = 65 named / 27 semi / 5,530
procedural; the east bucket's NE-corner growth +201 → 711 = 58/3/650);
named 616 → 682; trees 6,106 → 6,753 (+647); street entries 560 → 1,035,
named drivable km 123.40 → 261.27 (the graph doubles; extra3 rule 134.7
→ 275.9 — the north grid's named ways, the node-filter rule rejoining
its own gaps); parking 571 → 639 lots / 94.43 → 113.97 ha (bays 31 and
the tailgate zone 33 / 11.9 ha untouched — its lat/lon window is
southern); parks 57 → 89; **lakes 1 → 2**; **trails 0 → 69 runs /
9.36 km** (Ada Hayden 5.31, Moore 2.43, Inis Grove 1.62; the longest
single run 1.76 km — the survey's "outside loop 1.9 km" through the
park-ring clip); rail at-grade crossings **9 → 14** (the north strip's
five: West 190th Street, Bloomington Road, 24th, 20th, 16th — the UP
line exits town at grade; the crossbuck set grew with them). The
ada_hayden landmark POI and the_cafe venue POI both flip in_core; The
Cafe's facing re-derives onto Northridge Parkway (359.9°).

**The park-lake hole, as data.** The Ada Hayden tract ring CONTAINS its
lake, and the bake's flats stack lawn (y 0.04) ABOVE water (y 0.02) —
an unmarked polygon would paint mown lawn over the whole 52.1-ha lake.
Two slit-based hole cuts (a keyhole splice with epsilon-separated seam
vertices) fought the ear clip and were replaced by the honest form: the
entry keeps the full tract ring in `polygon` and lists the lake in
`holes`; `area_m2` is the LAWN side (tract − lake, asserted positive =
1,278,476 m²); the baker's parks path ear-clips the simple ring, then
BSP-splits each lawn triangle against the hole ring's own boundary
edges (both sides kept, area-conserving) and drops the in-lake
remainder. The lawn flat ends at the water's edge: recount
6,056,339.2 m² vs baked 6,056,341.0; **zero lawn triangles' centroids
inside the lake rings** (the gate walks the bake). The twin-lobed read
is pinned off the data ring: at the bbox-center x the polygon is WET
south and north of the DRY waist point (1793.4, −5046.8) — the two
former quarry pits and their isthmus.

**The Cafe un-staged.** T-198's staged spec PLACES: the venue's own
building (way/114039922, the unnamed 32.7 × 18.5 m massing — the census
§6 north strip keeps it procedural, the authored set stays closed)
landed with the bake, and the sign mounts its NORTH wall at wall_u
536.49, mount_y 5.4 (the tier-1 plaque band on the 11 m massing),
Northridge Parkway fronting the wall at ~1.4 m (the tight-lot frontage
band [1, 30], the facing floor relaxed to 0.75 for the street's ENE
drift at the frontage — measured dot 0.81). The tier-1 staged set is
EMPTY (the T-198 + r4-ledger scenarios fail on any re-staged spec); the
T-175 venue fixup joined at the POI (in-core, authored-uncovered) and
is asserted fully SWALLOWED by the massing box — the buried-box law the
eleven named fixups carry.

**The quarry shore + the trail paint.** The lake's `bank: "quarry"`
rides the shore family as per-entry color overrides (#A8A194 pale
gravel — the IMAGE_INDEX nature note's "flat quarry-banked shoreline";
the hex is a survey estimate, recorded in the baker) at LAWN level
(top 0.05, over the park ground the hole leaves, 264 overrides = one
per non-degenerate ring edge). The trail ring paints through the bake's
NEW `trail_quads` family (schema ames_chunks/v4): #B9A984 —
MODELING-SPECS §2's "Prairie/gravel trail" hex from
nature/04-adahayden-prairie-trail.jpg — 3 m paved (cycleway) / 2 m
crushed rock (footway/path), tops 0.07 (over the creek tops, under the
road ribbons), 788 quads = one per non-degenerate pack run segment
(recount-exact).

**Re-bake.** `tools/bake_ames_chunks.gd` headless ×2: 552 tiles (the
new north cz rows), 10,783 massing / 10,348 ribbons / 3,018 lane dashes
/ 375 water tris (262 Ada Hayden + 113 LaVerne) / 381 shore quads /
788 trail quads / 4,647 lawn tris / 106 placeholders / 14 crossings,
payload 8.26 MB (budget 40) / ~4 s (budget 60 s), determinism held —
`total_sha256 260c34c66b7d3aed74e8ddd6e42e9a793a669979c6c7be502d46fd074efe134b`
twice.

**The ring table (v3 → v4):** buildings 4,960 → 10,783 · named 616 →
682 · authored 616 → 682 · trees 6,106 → 6,753 · street entries 560 →
1,035 · street km 123.40 → 261.27 · extra3 134.7 → 275.9 · parking 571
→ 639 lots / 94.43 → 113.97 ha · parks 57 → 89 · lakes 1 → 2 · trails
0 → 69 / 9.36 km · traffic graph 1,018 runs / 123.4 km / 472 stops →
2,044 / 261.26 / 1,003 · arterial corners 54 → 83, signals 27 → 34,
all-way 58 → 80 · blades 99 → 130 (50 mast + 80 post) over the north
spine corners · plaques 12 unchanged · text ledger 162 → 194 texts
(venues 14 + tiers 27 + ghosts 11 + blades 130 + plaques 12), the
staged set EMPTY · at-grade crossings 9 → 14 · tailgate 33/11.9 and
bays 31 unchanged · venue tiers 14/17/17 and landmarks 15 unchanged.

**The gates, exact commands and outputs:**

- Gate 1: `Godot_v4.7.2-stable_win64_console.exe --headless --path .
  --import` → exit 0, only the accepted godot_mcp "resources still in
  use" line; `--headless --path . --quit-after 120` → exit 0, zero
  ERROR/SCRIPT ERROR lines.
- Gate 1b: `--headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` → **SIM SUMMARY: 0 failure(s), exit 0**
  (160 scenarios incl. the new `ames_extension_north` PASS printing
  `growth 4720.6 m north; lake 860x1125 m area 521167 m2; trails
  69/9.36 km (AH 5.30); ring crossings 7/8; cafe true in_core`; the
  moved pins re-pinned with their v3 → v4 history recorded in this file
  and VERIFICATION.md; no assertion weakened).
- Gate 2: `--path . res://tests/autoplay.tscn` → **AUTOPLAY DONE
  ok=true world=ames crumb_target=40 loop_ok=true t=103.0 fps=139
  eaten=4 splats=34 tourists=24 panics=0 score=0 high=780 restart=true**,
  exit 0. The one `Basis must be normalized` engine line prints from the
  pigeon pose rig's Basis→Quaternion cast — PRE-EXISTING (T-204's record
  carries the same line class off a control run on the T-203 merge base;
  neither run gates on it).
- Gate 3: the screenshot pass (pilot session `t205north`, OS grabs in
  `.captures/session_t205north/`): the SE aerial at 150 m shows the
  TWIN-LOBED lake — two pale-shored basins around the dry isthmus, the
  quarry bank bands tracing both shores, the trail ring's pale loops on
  the prairie beyond and the shore-side trail curve at the south read;
  the low south-shore read shows the flat pale quarry bank separating
  water from prairie (the `nature/01` "flat quarry-banked shoreline"
  character); the north-fabric aerial shows the Northridge corridor, the
  residential grid and LIVE fleet traffic in the north; and the close
  wall read at 2616 Northridge Pkwy shows **"The Cafe" lettered on the
  building's own north wall** with the café patio table seated below it
  (`g3_cafe_sign.png` in the session dir). Recorded honestly: the water
  flat's tone is the resident baked world's vertex-color/lighting wash —
  a control run of the T-204 merge base (`git worktree add` at 58bde8f,
  pilot session `t205merge`) shows LaVerne's oval at the SAME pale read,
  so the tone is the pre-existing world look, not a T-205 regression (a
  darker water read is the same future polish T-204 recorded for the
  roofs); the suite-2 `poop_ready_indicator` failure did not recur on
  the clean re-run and is recorded as load-flaky (I re-baked
  concurrently with that suite run — never again: the bakes change the
  chunk files under a live harness).

**The workflow-gate sim failure, found and fixed (2026-11-17).** The
orchestrator's gate run flagged the sim leg on this tree. My own
re-runs exited 0 with `SIM SUMMARY: 0 failure(s)` — but the log carried
ERROR-class lines my exit-code read had missed. Three classes, two
mine:
1. `SCRIPT ERROR: Out of bounds get index '12'` at
   `sim_test.gd:18721` (`bread_steal_favor_deltas`) — NEW with the v4
   box, and mine: the scenario's TABLE-ordinal walk counted TABLE-kind
   spots before the crumb and indexed `cafe_spots` with the count —
   silently assuming every TABLE spot is a café table. The T-183
   favor-bench spots already broke that assumption conceptually (7
   bench spots carry no `cafe_spots` entry), and the v4 box's 14 TABLE
   spots (7 café + 7 bench) finally desynced it past the array's end.
   FIXED at the cause: the walk now matches the crumb's stored spot
   POSITION against the café seeding law (`cafe_spot.origin + basis.x ×
   CAFE_CRUMB_SIT_INSET + CAFE_CRUMB_TABLE_LIFT`, the exact
   `_add_cafe_tables` emission) and takes the crumb's true café
   ordinal — correct for any café/bench mix, no assertion weakened.
2. `ERROR: Parse JSON failed` ×2 from `_read_pilot_events`
   (`sim_test.gd`) — the reader parsed the session events.jsonl's
   trailing empty line; the sibling `_read_pilot_event_list` already
   skipped empties. FIXED with the same guard.
3. The `SitterTorso`/`SitHair` cafe-visuals `Node not found` family —
   PRE-EXISTING: T-194 and T-195's own gate records document the class
   reproducing on unmodified trees; my count is unchanged (6 lines in
   every run, mine and theirs), the fix would touch imported animation
   data outside this ticket, and it stays recorded here as the known
   world-noise residue.

Post-fix verification on the final tree: parse check 0 errors; the
suite re-run → **exit 0, SIM SUMMARY: 0 failure(s)**, the `Out of
bounds` and `Parse JSON failed` classes GONE (0/0), the Sitter family
at its documented 6 lines; Gate 1 re-run → import exit 0 (the accepted
godot_mcp line only) + boot exit 0 with zero error lines.

**Reviewer sign-off:** ACCEPTED 2026-11-17 — the workflow's full gate
re-run passed on the fixed tree (import ok / boot ok / sim ok /
autoplay ok) and this commit flips the Status to `done` (the
sign-off commit, per the house rule).

**Final tuned values** (as shipped): core bbox W−93.6590 S42.0030
E−93.6070 **N42.0780** (+4,720.6 m north past the whole park; pack v4,
schema ames_core/v4, byte-identical re-distill a78fadaf…); Ada Hayden
Lake water flat 860.1 × 1125.1 m, 521,167 m², bank=quarry, the
twin-lobed ring with its dry waist at (1793.4, −5046.8); quarry shore
band 7 m wide at lawn level (top 0.05), #A8A194 (the recorded survey
estimate), 264 per-entry overrides; Ada Hayden park entry 1,278,476 m²
= the 180-ha tract ring minus the hole, `holes` carried as data; trails
69 runs / 9.36 km (Ada Hayden 5.31, Moore 2.43, Inis Grove 1.62), the
bake's trail_quads #B9A984 at tops 0.07, 3 m paved / 2 m rock by class;
The Cafe sign on massing:way/114039922's north wall, wall_u 536.49,
mount_y 5.4, letter 0.16, the tight-lot frontage band [1, 30] with the
0.75 facing floor; north strip 5,622 buildings (65/27/5,530); rings
2,044 / 261.26 km / 1,003 stops; corners 83 arterial + 34 signals +
80 all-way; blades 130 (50/80); text ledger 194; crossings 14.

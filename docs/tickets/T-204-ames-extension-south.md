# T-204 — Ames R5 · south: Reiman Gardens and the butterfly wing

- **Status:** done · **Category:** worldbuilding · **Ring:** R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-203 (the extension pattern proven)
- **Refs:** QA item 1 (the conservatory split — the WHOLE building is
  59×88 m; Hughes Conservatory, the glasshouse, is 465 m² — unsplit,
  the set piece builds ~11× oversized) · `landmarks/LANDMARKS.md`
  (Reiman Gardens; canopy spans = model-to-look) ·
  `images/nature/11` (wing-roof), `13` (butterfly — the accent-prop
  ref) · `community` (the gardens as the town's south arrival)

## What

+~1 km south, to the town's garden gate:

- **Reiman Gardens at hero-lite fidelity**: the conservatory as the
  59×88 m building WITH the wing-form blue-glass roof massing (photo
  11), the butterfly-wing entrance canopy as the model-to-look set
  piece (estimate recorded), Hughes glasshouse split respected — the
  QA's blocks-build item made structural here.
- **Vet Med** and the south blocks as massing context.
- Data pack v3, re-bake, bbox pins; a butterfly ACCENT PROP (the
  wing-exhibit read, photo 13) as ambient fauna near the gardens —
  count tiny (dressing, not a system).
- Sign slot reserved for the T-201 plaque ("Reiman Gardens").

## Why

The south gate is the arrival read for anyone who ever drove in on
US-30; the wing roof is the silhouette. And the QA's biggest
blocks-build find gets its structural fix here.

## Acceptance criteria

- [x] Conservatory at 59×88 m with the glasshouse split structural
      (the 465 m² volume distinct in the scene tree)
- [x] Canopy at the recorded estimate; butterfly props ≤ 12, ambient
      only
- [x] *(Gate 1b)* `reiman_gardens_dims`: building/canopy/glasshouse
      pins (the split asserted)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass.

## Run record (T-204, 2026-11-17)

**The flip.** Status → doing in this file and the index row before any
code moved (the flip predates the feat commit's content — it rides it).

**The extension, mechanical.** `tools/ames_distill.py`: CORE S edge
42.0120 → 42.0030 (+9.0e-3° ≈ 999.7 m through the pack's own transform —
SUMMARY §3's planned "+1.0 km south" window to the decimal; W/E/N and
the origin untouched). The census-CSV guard mirrors T-203's: buildings
south of the stamped `core_bbox_south_v2` 42.0120 AND west of the v1
east edge ride the census §6 rule (disjoint guards — the east guard
fires first, so the box's SE-corner growth joins the EAST strip bucket);
a CSV-less building inside both edges still hard-fails (`missing_csv`
measured 0). Byte-identity held: two consecutive
`python -I tools/ames_distill.py` runs → the same pack SHA-256.

**The strip numbers** (the distill's own counts, v2 → v3): buildings
4134 → 4960 (south strip 713 = 47 named / 9 semi / 657 procedural; east
strip 397 → 510, the +113 SE-corner growth riding the east bucket → 57
named); named 556 → 616; trees 5715 → 6106 (+391); street entries 447 →
560, named drivable km 98.04 → 123.40; extra3 105.7 → 134.7 km
(University Boulevard, Mortensen Parkway, South 16th Street, McCarthy
Road, Beach Avenue + the residential south grid); parking 532 → 571
lots / 83.05 → 94.43 ha; parks 32 → 57 (Reiman Gardens' own 73,202 m²
way + Reiman Plaza landed); **tailgate 19 → 33 lots / 8.9 → 11.9 ha —
the §3 window rule is lat/lon, not the box, and the v2 box saw only its
northern part; the south widening revealed the rest** (the game's
tailgate stock grows with the map). Landmarks/venues unchanged
(15 / 48 in the 14/17/17 law). The `reiman_gardens` POI flipped in_core
(facing re-derived 141.8° → University Boulevard), as did `hickory_park`.

**The hero** (runtime, the T-191/T-192 law — `_build_reiman_hero` rides
its carrier chunk (3, 4) off the massing slot's own center): the
envelope EXACT at the whole-building dims (58.7 × 87.8 × 10.0 — the QA
item 1 split: this is the WHOLE "Reiman Gardens Conservatory", never
"Hughes"); the wing-form roof (photo 11): four glass bands in the 2 × 2
faceted sweep + the frame spine cap crowning 14.3 m; the **Hughes
glasshouse split made STRUCTURAL** — a NAMED `HughesGlasshouse` mesh
node (31.0 × 15.0 = 465 m² footprint, LANDMARKS C10's 5,000 sq ft)
standing full-height INSIDE the envelope with its own part record
(`mesh: true`), the gate asserting both the area (±0.5 m²) and the
containment; the butterfly-wing entrance canopy at the RECORDED
ESTIMATE (two swept shells meeting at a spine over the east arrival
walk + two posts: span 14.63 m, top 7.03, shell eaves 4.2 — LANDMARKS
C10 pins NO sourced dimension; the estimate lives in the world consts
and is typed AGAIN in the scenario as the second recording; V-30
UNVERIFIED honored); 8 ambient butterflies (`scenes/butterfly.tscn` +
`scripts/butterfly.gd`, the photo-13 accent read — monarch amber over a
dark body, wander/bob/flap, zero physics: dressing, not a system, the
ticket's ≤ 12 law held at 8); the conservatory way joins
`HERO_BUILDING_IDS` (the supersede 1:1, the T-203 bandshell pattern —
`_hero_parts` has no case for it, so the hero join re-poured
byte-identical chunks and the v3 bake hash survived). The T-201 plaque
un-staged onto the hero's east glass face (plane 984.35, station
1233.08, "Reiman Gardens — 1995", letter 0.20 on the widened 2.8 slab).

**The pylon correction.** Hickory Park's venue pylon had staged on the
apron ("the building lands with the R5 east extension (T-203)" — one
ring early). The bbox south landed `way/196541966` as an authored slot,
so the pylon re-pinned OFF the POI (it would stand inside the
building's own mass now) onto the building's north face at the lot's NE
station (wall_u 3382.0 — Meadow Lane's bend keeps the face-north aim
inside the facing cone), fronting Meadow Lane Court at the measured
24.9 m (the pack's S Duff naming ends at its intersection; the survey
address 1404 S Duff stays in the note).

**Re-bake.** `tools/bake_ames_chunks.gd` headless ×2: 184 → 251 tiles
(the new cz rows), 4960 massing / 5006 ribbons / 2182 lawn tris, payload
4.36 MB (budget 40) / ~1.5 s (budget 60 s), determinism held —
`total_sha256 0fbc445616ae11fc0e31c7eb51efc508752a0a33316533060092dad1d
bec7099` twice, byte-identical across the HERO_BUILDING_IDS join.

**The ring table (v2 → v3):** buildings 4134 → 4960 · named 556 → 616 ·
authored 556 → 616 · trees 5715 → 6106 · street entries 447 → 560 ·
street km 98.04 → 123.40 · extra3 105.7 → 134.7 · parking 532 → 571 lots
/ 83.05 → 94.43 ha · tailgate 19/8.9 → 33/11.9 · parks 32 → 57 · traffic
graph 824 runs / 98.0 km / 383 stops → 1018 / 123.4 / 472 · arterial
corners 47 → 54, signals 25 → 27, all-way 53 → 58 · blades 89 (37+52)
→ 99 (42+57) over 74 → 79 corners · plaques 11 + 1 staged → 12 placed ·
text ledger 151 → 162 · skipped massing ids 14 → 15 · curb runs 92
(62+24) and mapped bays 31 UNCHANGED.

**The gates, exact commands and outputs:**

- Gate 1: `Godot_v4.7.2-stable_win64_console.exe --headless --path .
  --import` → exit 0, only the accepted godot_mcp "resources still in
  use" line; `--headless --path . --quit-after 120` → exit 0, zero
  ERROR/SCRIPT ERROR lines. POST-GATE REPAIR (2026-11-17): the
  workflow's first gate run failed its import leg with the
  `mcp_runtime_probe.gd ... File not found` / `Failed to create an
  autoload` error class — VERIFICATION.md "Known issues" documents this
  exactly: a checkout without the untracked, gitignored
  `addons/godot_mcp/` directory cannot pass an ERROR-line-clean import
  (the MCPRuntimeProbe autoload is configured in project.godot:23).
  Reproduced on a pristine checkout of this branch's tip
  (`git worktree add /tmp/t204-gateprobe 51d37ec` → import printed the
  three autoload ERROR lines, exit 0), fixed by the documented restore
  (copy the addon from the canonical checkout, writable) — the restored
  checkout's import prints only the accepted "33 resources still in
  use" line — and re-proven on THIS worktree from a deleted `.godot`
  (cold cache): import exit 0 (accepted line only) and boot exit 0 with
  zero error lines. No tracked file caused or needed a change; the
  tracked tree ends clean and the addon stays untracked per policy.
- Gate 1b: `--headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
  → **SIM SUMMARY: 0 failure(s), exit 0** (160 scenarios, incl. the new
  `reiman_gardens_dims` PASS printing `parts=13 envelope=58.7x87.8
  ridge=14.1 glasshouse=(31.0, 10.0, 15.0) butterflies=8`). The re-pin
  path took three measured iterations (runs 1–3 recorded the moved
  families; every changed number carries its v1/v2 history; no
  assertion weakened).
- Gate 2: `--path . res://tests/autoplay.tscn` → **AUTOPLAY DONE
  ok=true world=ames crumb_target=40 loop_ok=true t=103.0 eaten=4
  splats=34 tourists=24 panics=0 score=0**, exit 0. Two `Basis must be
  normalized` engine lines print from the pigeon pose rig's
  Basis→Quaternion cast — PRE-EXISTING (a control run of the same
  autoplay on the T-203 merge base 398caf4 shows the same line class;
  neither run gates on it).
- Gate 3 (the screenshot pass, pilot session `t204south`, OS grabs in
  `.captures/`): the south-gate read is live — the SE aerial shows the
  blue-glass envelope with the wing-roof sweep and the spine line over
  the tan Mahlstede Center mass, Hunziker House beside it and LIVE
  University Boulevard traffic (the south fleet stages and drives);
  the east-face read shows the canopy shells over the arrival walk
  between the conservatory and the Butterfly Wing building [ROUND-2
  CORRECTION: this line recorded what the staged screenshot showed, not
  what a player at the walk sees — the v1 station was buried in the
  Butterfly Wing's bake box (see the round-2 record below); the station
  moved and the read re-shot in session `rv2b`]; the wide
  west aerial shows the gardens lawn, the Reiman parking stock dressed
  and the grounds' green inside the core. Recorded honestly: the roof
  planes wash toward white in full sun (the palette pin holds in the
  records and the gate; a darker glass read is future polish, the same
  vertex-color-lighting wash every baked massing shows); the butterfly
  accents are sub-foot-scale dressing — the machine gate pins their 8
  positions/collision law, the eye catches a speck at range; the pilot
  teleport's `yaw_deg` is the raw rotation (90 = west), learned on two
  occluded shots, then the reads landed.

**Reviewer round 2 (2026-11-17) — the canopy/plaque station defect,
fixed:** the reviewer played the site (pilot session `rv2`, east-walk
teleports at t=187s/241s/289s) and found the entrance-canopy set piece
BURIED inside the Christina Reiman Butterfly Wing authored slot's box:
the bake mass `way/479976960` (chunk_3_4: p=[988.41,5.0,1223.26]
s=[23.8,10.0,20.6] → x 976.51..1000.31, z 1212.96..1233.56, y 0..10 —
re-measured from the committed chunk this round, numbers matching the
reviewer's) contains the v1 canopy station entirely: REIMAN_CANOPY_Z
1233.08 put the spine cap, BOTH posts and the north 5.48 m of the
shells' 10 m depth inside that mass — in play only the south ~4.5 m of
the shells read, as a pale-blue shelf clipped into the gray building,
and the "two posts" were invisible; the plaque mount (984.41, 2.6,
1233.08) sat inside the Wing box volume too, reading only from
south-of-the-Wing approaches. The same staging mistake class this
ticket already fixed elsewhere (the Hickory pylon). The round-2
observation also notes the Wing slot box interpenetrating the hero
envelope (7.84 m in x × 20.6 m in z, both 10 m tall) — that overlap is
the pre-existing bbox-grain artifact of two adjacent OSM footprints'
axis-aligned boxes (the same grain every massing pair in the build
carries; the real buildings do not touch), recorded here as data grain,
not staged set piece — the ticket's scope (the What list) owns the
staged set piece, and that is what moved.

**The fix (the reviewer's own suggested station class):** the canopy
re-stationed mid-gap on the OPEN arrival walk south of the Wing box —
REIMAN_CANOPY_Z 1233.08 → 1241.5 (REIMAN_CANOPY_X 993.0 kept): shells z
1236.50..1246.50 clear the Wing's south face (1233.56) by 2.94 m and
the Mahlstede box's north face (1250.07) by 3.57 m; the west post edge
(x 985.69) clears the envelope face (x 984.35) by 1.34 m. The plaque
re-stationed to the same open-walk bay: wall_u 1233.08 → 1241.5
(mount 984.41, 2.6, 1241.5) — it now faces the walk over open air, the
mount the canopy shares. The gate grew the clearance law: the scenario
walks the Wing + Mahlstede bake boxes independently from the chunk
files and pins the shells' z span inside the gap [1233.56, 1250.07]
with NO canopy part and NO plaque slab intersecting either mass — the
burial regression fails the suite by name.

**Round-2 gates:** `--headless --fixed-fps 60 --path .
res://tests/sim_test.tscn` → SIM SUMMARY: 0 failure(s), exit 0 (the
`reiman_gardens_dims` PASS carrying the new clearance legs); Gate 1
import/boot re-run green; Gate 3 re-shot (pilot session `rv2b` — the
canopy now reads as the free-standing wing shells over the open walk
with both posts visible, and the plaque faces the walk; the honest
residual: the gray Wing box still abuts the blue east face at the
data-grain overlap recorded above).

**Final tuned values** (as shipped, round 2): conservatory envelope
58.7 × 87.8 × 10.0 m at the slot center (955.0, 1233.08) — the QA-split
whole building; Hughes glasshouse 31.0 × 15.0 m = 465 m², full-height
inside, center z-offset +6.9; wing roof ridge 14.0 + spine cap → crown
14.3, eave return 10.3, inner run 12.0, band t 0.35; canopy station
(993.0, 1241.5), shells 7.5 slope × 10.0 depth, ridge 6.8 / eaves 4.2 /
post-top 3.6, shell t 0.25, span 14.63 / top 7.03 as recorded; plaque
station (984.41, 2.6, 1241.5), letter 0.20 on the 2.8 × 0.6 × 0.1 slab;
clearances — Wing 2.94 m, Mahlstede 3.57 m, envelope 1.34 m; butterflies
8 (≤ 12), ring center (1028, 1310) r 21, hover y 1.5.

**Reviewer sign-off:** ACCEPTED 2026-11-17 — the reviewer signed the
round-2 record off and this commit flips the Status to `done` (the
sign-off commit, per the house rule).

# T-203 — Ames R5 · bbox east: Bandshell Park and the S Duff corridor come inside

- **Status:** done · **Category:** worldbuilding · **Ring:** R5 The Town ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-202 (R4 cut over; extension machinery stable)
- **Refs:** `census/BUILD-CENSUS.md` (Bandshell Park ~30 m outside the
  east edge — the census miss) · `osm/SUMMARY.md` (core bbox; optional
  extensions) · master plan §8 · T-171 (the distill pipeline this
  re-runs — data pack v2)

## What

The smallest map growth, fixing the census's one embarrassing miss:

- Extend the core bbox ~200–300 m east; re-run the distill (data pack
  v2 with a version bump), re-bake; Bandshell Park + its block land
  inside the playable core (the T-192 bandshell already sits at its
  true position — this makes the GROUND around it playable).
- The S Duff commercial corridor gets its context blocks (Hickory
  Park's surroundings stop being void).
- Suite bbox pins updated (the honest, mechanical re-pin; no hero
  work).

## Why

A landmark you can see but not perch at is a tease; this closes the
gap the census itself flagged.

## Acceptance criteria

- [x] Data pack v2 (version-bumped); Bandshell Park block playable
      (ground, collision, bread reach per the T-176 gate band)
- [x] *(Gate 1b)* `ames_bbox_east`: new bbox consts; Bandshell inside;
      census counts re-pinned (+delta recorded)
- [x] Re-bake determinism holds (T-172's manifest discipline)
- [x] *(Gate 1/2)* clean

*(every box above is ticked on the recorded run evidence below; the
reviewer SIGNED OFF 2026-11-17 — status flipped done in this file and
in the index row.)*

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: agent screenshot pass.

## Run record (2026-11-17, worktree t-203)

**The world flip.** `CORE` E edge −93.6100 → −93.6070 in
`tools/ames_distill.py` (+248.1 m east through the pack's own
transform — the ticket's 200–300 m band; W/S/N and the origin are the
census lines, untouched). Pack `version` 1 → 2, schema
`ames_core/v2`, meta stamps `core_bbox_east_v1` = −93.61 + the
`buildings_east_strip*` delta keys. Distill byte-identity: two
consecutive runs → the same SHA-256
(`f7ecf868…2852208f`). Bandshell Park's way (named, 12,710 m²,
129.4 × 102.2 m, bbox east −93.60882) lands ~150 m inside the new
edge; the strip carries 397 buildings (44 named / 3 semi-tagged / 350
procedural), 78 tree nodes, 52 parking lots (9.45 ha), 6.11 km of
named street, and the east-downtown grid (Carroll/Crawford/Des Moines/
East/High/Stafford/Sumner avenues + the East 2nd–13th fabric + the
Ames Municipal Power Plant).

**The strip classification is mechanical, not curated.** The census
CSV covers the v1 core only; `build_buildings` classifies every
CSV-less building by the census's own §6 rule (names → authored-named,
unnamed+POI-tag → semi-tagged, else procedural) under a per-building
guard: a CSV-less building MUST sit east of `core_bbox_east_v1`, so
the rule can never silently eat census-window drift. The authored set
stays closed — no hand curation.

**One hero consequence, the only non-mechanical code change:** the
Durham Bandshell's own OSM way `way/269752151` ("Durham Bandshell",
25.4 × 14.6 m) came inside as an authored slot standing under the
T-192 hero. It joined `AmesBaker.HERO_BUILDING_IDS` (the manifest
`heroes` law hides its bbox box; `_hero_parts` has no case for it —
the hero's parts are the POI-built arc), so the supersede stays 1:1.
The R3 swap-set ring re-pins 13 → 14 (9 bake heroes + 5 runtime
slots).

**Re-bake.** `tools/bake_ames_chunks.gd`: same 184-tile set (the
strip's content grew inside the existing cx=13 column — 20 chunk
files changed), 4,134 massing / 3,945 ribbons / 407 creek quads /
1,288 lawn tris / 3,359 ground quads / 105 placeholders / 9 crossings,
payload 3.66 MB (budget 40), wall clock 1.1 s (budget 60 s).
Determinism: two consecutive bakes → the same manifest bytes and
`total_sha256 dd7a8a332b60a6f9d725dcf2fce035692eef2c1a5b50b6cc5ebebcb
2ccf5e726` (the new pin, recorded in VERIFICATION.md's
`ames_bake_determinism` row with the full hash history).

**The tuned values (the ring table — every moved family, v1 → v2):**

| family | v1 census pin | strip delta | v2 pin (asserted) |
|---|---|---|---|
| buildings | 3,737 | +397 | 4,134 |
| named/authored | 512 | +44 | 556 |
| trees | 5,637 | +78 | 5,715 |
| parking lots | 480 | +52 | 532 |
| parking ha | 73.6 | +9.45 | 83.05 |
| street km (graph rule) | 91.93 | +6.11 | 98.04 |
| extra3 km | 99.6 | +6.1 | 105.7 |
| parks | 31 | +1 (Bandshell) | 32 |
| rail crossings | 9 at-grade | 0 | 9 |
| venues / tiers / landmarks | 48 / 14-17-17 / 15 | 0 | 48 / 14-17-17 / 15 |

Traffic/intersection/blade re-pins (the graph facts over the grown
pack): 777 → 824 runs, 91.9 → 98.0 km, 361 → 383 stop junctions,
per-class km primary 10.0 / secondary 16.8 / tertiary 13.1 /
residential 54.2 / unclassified 4.0; arterial corners 43 → 47 (East
Lincoln Way × Des Moines / East Avenue / Sumner / High — the avenue
set only exists in the pack since the strip landed), signals 25
(unchanged), all-way 53; blades 85 → 89 (37 mast / 52 post — four
all-way East-Lincoln-Way post blades; the unreached spine ledger
holds: Mortensen / South 16th / Southeast 16th / Stange still place
nothing); the r4 text ring 147 → 151 texts (13/27/11/89/11); curb
runs 94 → 92 (downtown 64 → 62 — East 3rd Street's run joined the
downtown district while two Duff-seam band runs re-districted to
lincolnway with the East Lincoln Way continuation welding through;
every downtown street still marked); parking dressing 88 → 95 lots /
5,873 → 7,076 kept stalls (tailgate stock 2,437 untouched); the
parking staging leg now derives the biggest lot from the stock (the
crown moved east to the strip's 2.78 ha `way/196544343`; v1's 2.31 ha
`way/183319618` is #2); rail coal-drag route 4,272.6 → 4,502.7 m
(east end (3297.47, −217.26) → (3522.0, −266.8); west end untouched);
corner furniture counts 9,812 → 10,244 paint bars, 200 → 215 stop
lines/posts/plaques, 800 → 860 red/border bars; the guard circle
center (1334.1, −64.1) → (1381.9, −64.1), radius 2842.5 → 2882.3.

**Gates, run in this session:**

- Gate 1 — `--headless --path . --import` exit 0 (the one
  documented godot_mcp "resources still in use" line), boot
  `--quit-after 120` exit 0, no error lines.
- Gate 1b — `--headless --fixed-fps 60 --path . res://tests/
  sim_test.tscn`: **159/159 PASS, exit 0** (the suite grew 158 → 159
  with the new `ames_bbox_east` row). The red-before sweep caught
  exactly the mechanical re-pin set (9 scenarios), each re-pinned on
  the measured values above — no assertion weakened.
- Gate 2 — `--path . res://tests/autoplay.tscn`: `AUTOPLAY DONE
  ok=true world=ames … eaten=4 splats=35 tourists=24 … restart=true`,
  exit 0.
- Gate 3 — agent screenshot pass (the ticket's own acceptance test):
  pilot session `t203east` — Space into the run, hunger locked,
  teleport over the park (`3353, 42, −412`) settled GROUNDED on the
  park block (the plate answers), then a flap-hold pose over the
  bandshell: the T-192 hero's copper arch over the mint shells
  standing on its playable lawn, the east-downtown fabric and live
  traffic (cars on East 5th and the S Duff frontage) rendered around
  it — the ground the tease stood on is now perchable. Session
  channel `.captures/session_t203east/` (review with
  `tests/review/summarize.py`), stopped graceful.

## Verification

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: agent screenshot pass —
all four run green above. The human fly-to-your-bar pass stays
available to the owner; the machine-checkable band (ground, collision
cover, bread reach 48.2/48.0 m vs the 150 m T-176 bar) is pinned by
`ames_bbox_east`.

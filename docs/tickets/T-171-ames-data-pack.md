# T-171 — Ames R1 · data pack: the committed city database

- **Status:** done · **Category:** code-optimization · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** the ring-0 survey (landed on `ames/campaign`: aa73840, e486d72)
- **Refs:** `docs/AMES-MASTERPLAN.md` §2 (architecture), §4 ·
  `docs/references/ames-survey/INDEX.md` (entry point) ·
  `osm/ames_merged.json` (source dataset) ·
  `census/BUILD-CENSUS.md` (§7 parameter sheet, `authored-buildings.csv`) ·
  `osm/SUMMARY.md` (bbox, spine streets) · `venues/VENUES.md` (48 venues) ·
  `verification/VERIFICATION.md` (ground truth)

## What

Distill the survey's OSM dataset into `data/ames/ames_core.json` — the
committed, versioned database every later Ames ticket consumes — plus a
typed GDScript loader.

1. **`tools/ames_distill.py`** (offline, `python -I`, reads the committed
   `osm/ames_merged.json` + `census/authored-buildings.csv` + venue list):
   emits the pack with sections — `meta` (core bbox lon/lat, origin,
   attribution string `Map data © OpenStreetMap contributors`, source
   date, distill-commit), `streets[]` (name, class, centerline polyline
   in local meters), `buildings[]` (id, centroid, bbox, levels, name?,
   class authored|procedural), `pois[]` (the 48 venues + the survey's
   landmark list, each with position + facing + tier), `water[]`
   (Lake LaVerne polygon; College/Ioway centerlines + widths),
   `rail` (centerline + the 9 at-grade crossings with road names),
   `parks[]`, `trees[]`.
2. **Coordinate convention** (master plan §2): local meters, origin at
   Lincoln Way × Welch, +X east, −Z north; equirectangular scale at
   lat 42.02. The transform lives in ONE helper so re-centering is a
   pack-version bump, never a refactor.
3. **`scripts/ames_data_pack.gd`** — static loader: parse, typed access
   (`buildings()`, `pois_of(tier)`, `nearest_street(pos)`…), and the
   WGS84→local helper. No autoload (the city code consumes it; no
   global until a ticket needs one).
4. **ODbL one-pager** at `docs/references/ames-survey/ODBL-NOTE.md`:
   attribution obligation, where the string surfaces (credits screen is
   T-197; README until then), and the share-alike read for embedded
   derived tables.

**No reference photos:** the survey already carries them; this ticket is
data plumbing over committed files.

## Why

Every Ames ring needs the same numbers in the same frame; without one
pack, each ticket re-parses 21 MB of OSM and re-derives the projection.
The pack is also the integrity floor: its counts and sentinel positions
become the suite's new pinned truth (the census, made load-bearing).

## Acceptance criteria

- [x] `tools/ames_distill.py` committed; re-running it against the
      committed inputs reproduces `ames_core.json` byte-identically
      *(verified: two `python -I tools/ames_distill.py` runs, md5
      077211db330750840c5464c4c5e59ab5 both; canonical command takes no
      arguments. Discovery recorded: the survey's `osm/ames_merged.json`
      had never actually been committed — it sat in the gitignored
      `osm/raw/` — so this change-set commits it at the ticket's named
      path, plus `census/tagged-nodes-core.json`, a verbatim committed
      snapshot of the census lane's tagged-node cache (merged-OSM nodes
      carry no tags; without it the 5,637 trees and the venue node
      anchors are not reproducible from committed inputs).)*
- [x] Pack counts match the census exactly: 3,737 buildings (512
      named), 5,637 trees, 9 rail crossings, 48 open venues, 99.6 km
      in-core street centerline
      *(all counts machine-verified; both street figures hold, each under
      its own committed rule. The 99.6 km reproduces exactly:
      `python -I docs/references/ames-survey/osm/scripts/extra3.py
      docs/references/ames-survey/osm/ames_merged.json
      docs/references/ames-survey/osm/raw` prints "named-road length
      inside proposed core window: 99.6 km" — the extra3.py §5 rule
      (every way with a `highway` tag and a name, NODES filtered to the
      core bbox, haversine over consecutive survivors; cycleway 6.2 +
      service 2.9 + pedestrian 0.7 km included), the rule the distiller
      implements with a hard guard and the pack carries as
      `meta.street_km.named_highway_in_core_extra3_km` (99.6) plus its
      per-class table `named_km_by_class_extra3`. The streets[] graph
      itself pins the census §4 midpoint rule instead — 91.93 km
      named-drivable (92.09 with unnamed) — because streets[] entries
      are per-way runs with class/width semantics for the city code,
      not a survey statistic over a node-filter that rejoins gaps
      across dropped nodes; both numbers ride in meta.street_km.)*
- [x] Sentinel transforms hold: campanile (−93.64604, 42.02543) and
      the MU (2229 Lincoln Way, NORTH of it) land within ±3 m of their
      expected local positions; Lincoln Way reads E–W at lat 42.0228
      *(ames_data_integrity, Gate 1b: campanile (340.17, −294.43) vs
      closed-form expected (339.90, −294.35) — 0.28 m; MU (362.92,
      −98.53) vs (362.89, −98.52) — 0.04 m, north at z ≤ −90; Lincoln
      Way bearing 0.43° off E–W, mean lat 42.02282)*
- [x] `ames_data_pack.gd` parses the committed pack with typed
      accessors; no autoload added
- [x] `ODBL-NOTE.md` written; attribution string constant exported by
      the loader
- [x] *(Gate 1b)* new `ames_data_integrity` scenario (counts + sentinels
      above); full suite stays 0 failures (Windrow world untouched)
      *(181 PASS / 0 FAIL in one headless run)*
- [x] *(Gate 1)* `--import` + 120-frame boot clean; *(Gate 2)* autoplay
      green (both world-agnostic — nothing renders yet)
      *(Gate 2: `AUTOPLAY DONE ok=true restart=true`)*

## Verification (proposed)

Gate 1 · Gate 1b full suite + `ames_data_integrity` row · Gate 2 ·
no Gate 3 (no visual change). VERIFICATION.md extended in the same
change-set per the ticket loop.

## Decisions & forks

Origin choice Lincoln × Welch is the master plan's §2 convention —
changeable here only, once, before T-172 bakes it into chunk space.

## Tuned values (recorded at landing)

- **Pack:** `data/ames/ames_core.json`, `version` 1, schema
  `ames_core/v1`; 1.61 MB; LF-pinned in `.gitattributes` so checkout
  stays byte-identical to `python -I tools/ames_distill.py` (no args —
  the canonical re-run).
- **Coordinate convention (the ONE transform, `to_local` in the
  distiller / `wgs84_to_local` in the loader, constants pinned in both
  and locked by `ames_data_integrity`):** origin Lincoln Way × Welch
  (−93.65015, 42.02278, from the survey verification §1 crossing scan);
  +X east, −Z north, Y up; equirectangular scale at lat 42.02;
  M_PER_DEG_LAT 111074.0, M_PER_DEG_LON 82700.8758
  (111320·cos 42.02°). Facing = compass degrees (0 = north/−Z,
  90 = east/+X); Godot yaw = −deg_to_rad(facing_deg).
- **Counts (the census, made load-bearing):** 3,737 buildings (512
  named = 512 authored; 3,225 procedural incl. the census's 50
  semi-tagged), 5,637 trees, 48 venues (14/17/17), 15 landmarks,
  63 POIs (56 placed, 6 unplaced: mucky_duck_pub, labyrinth_coffee,
  restaurant_888, el_azteca, perfect_games, whatcha_smokin — the survey
  records no positions; addresses kept), 9 at-grade vehicular rail
  crossings (13th, 9th, North Hazel, Brookridge, unnamed service, Duff,
  Grand, Kellogg, Clark) of 15 vehicular total, 31 parks, 3 water
  features, 436 street entries.
- **Street km, both committed rules:** streets[] graph = census §4
  midpoint rule, named drivable **91.93 km** (92.09 km with unnamed);
  SUMMARY §3 statistic = extra3.py §5 rule **99.6 km** (named highway
  ways, nodes filtered to the core bbox, haversine; per-class table in
  `meta.street_km.named_km_by_class_extra3`).
- **Street width defaults (census §7.3):** primary 20, secondary 16,
  tertiary 13, residential 11, unclassified 11, living_street 9,
  service 7, trunk 20, motorway 24 m (`width_source` field names the
  census default). Creek width 6.0 m, `default` (OSM carries no widths).
- **Rail:** UP Clinton Sub main line 8.47 km in core.
- **Venue anchor provenance:** every anchor names its committed doc
  (census §2 table, census appendix way/relation, tagged-nodes-core
  node, or a computed rule — Superdog's curb rule, Szechuan House's
  doc-interpolation); no invented coordinates anywhere.

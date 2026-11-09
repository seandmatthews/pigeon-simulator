# T-171 — Ames R1 · data pack: the committed city database

- **Status:** proposed · **Ring:** R1 The Map ·
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

- [ ] `tools/ames_distill.py` committed; re-running it against the
      committed inputs reproduces `ames_core.json` byte-identically
- [ ] Pack counts match the census exactly: 3,737 buildings (512
      named), 5,637 trees, 9 rail crossings, 48 open venues, 99.6 km
      in-core street centerline
- [ ] Sentinel transforms hold: campanile (−93.64604, 42.02543) and
      the MU (2229 Lincoln Way, NORTH of it) land within ±3 m of their
      expected local positions; Lincoln Way reads E–W at lat 42.0228
- [ ] `ames_data_pack.gd` parses the committed pack with typed
      accessors; no autoload added
- [ ] `ODBL-NOTE.md` written; attribution string constant exported by
      the loader
- [ ] *(Gate 1b)* new `ames_data_integrity` scenario (counts + sentinels
      above); full suite stays 0 failures (Windrow world untouched)
- [ ] *(Gate 1)* `--import` + 120-frame boot clean; *(Gate 2)* autoplay
      green (both world-agnostic — nothing renders yet)

## Verification (proposed)

Gate 1 · Gate 1b full suite + `ames_data_integrity` row · Gate 2 ·
no Gate 3 (no visual change). VERIFICATION.md extended in the same
change-set per the ticket loop.

## Decisions & forks

Origin choice Lincoln × Welch is the master plan's §2 convention —
changeable here only, once, before T-172 bakes it into chunk space.

# ODbL note — what shipping Ames data obligates us to (T-171)

One page, kept next to the survey it governs. Written for the R1 data pack;
nothing here is legal advice — it is the project's working read of the
OpenStreetMap license terms, recorded so every later Ames ticket inherits the
same line instead of re-deriving it.

## The obligation, in one line

The Ames world data — and every distilled table cut from it
(`data/ames/ames_core.json` above all) — derives from OpenStreetMap and
carries the attribution obligation:

> **"Map data © OpenStreetMap contributors"** — visible, in the game, for the
> OSM-derived layers, distributed under ODbL's terms (see below).

## Where the string surfaces

- **Today:** `README.md` (credits section) — landed with T-171, per the
  ticket's decision that attribution may not wait for a credits screen.
- **The constant:** `scripts/ames_data_pack.gd` exports it as
  `AmesDataPack.ATTRIBUTION` and the pack itself carries the same string in
  `meta.attribution` — one source of wording, pinned equal by the
  `ames_data_integrity` sim scenario (Gate 1b). Code and copy that need the
  string read the constant; nothing retypes it.
- **T-197 (R4·text-capability):** the in-game credits screen renders it.
  From that ticket on, the screen is the surfacing point and the README line
  is documentation. Until then the README is the surfacing point.

## Why we owe it

The ring-0 survey's dataset (`osm/ames_merged.json`, pulled 2026-11-08 from
`api.openstreetmap.org`, 309,870 nodes / 37,531 ways / 251 relations) is OSM
data. The master plan's §0 licensing note makes this a standing obligation of
the Ames campaign, independent of any pack: "attribution itself is mandatory
either way."

## Share-alike: the project's read for embedded derived tables

ODbL (the Open Database License, v1.0) governs the OSM database and
**Derivative Databases**; **Produced Works** (games, renders, exports that
USE the data but don't redistribute a database) owe attribution only. The
question T-171 was asked to read is where `ames_core.json` falls:

- `ames_core.json` is a **transform of the OSM database** (projection,
  selection, classification — streets, footprints, POIs, water, rail, trees).
  Re-distributing it with the game therefore reads as distributing a
  **Derivative Database**, and ODbL §4.2's Forbidding/Share-Alike clause
  applies: the derived table must be licensed **ODbL itself**, attributed,
  and open in the same sense — which the repo already satisfies in spirit
  (committed, public, source-attributed) and now satisfies in letter:
  the pack's `meta.license` names ODbL and points here.
- The **baker's chunk resources** (T-172+) are Produced Works built FROM the
  pack: attribution carries forward (the credits screen names OSM), but the
  share-alike clause does not force the chunks to be re-licensed as data —
  they are rendered geometry, not a redistributable database.
- Hand-authored additions (the 6 unplaced venues' future coordinates from
  non-OSM research, model dims, names we add ourselves) are **independent
  content** — ODbL does not touch them; they ride the repo's own terms.

The practical consequence, accepted: **if the game ships, `ames_core.json`
ships under ODbL with the attribution string visible in-game.** No ticket may
strip the string from the pack or the loader constant without re-opening this
read with the owner.

## What this note does NOT cover

- The survey's 90 credited **photographs** — CC-licensed per-cluster, already
  handled in `images/CREDITS.md`; the credits screen (T-197) surfaces those
  too.
- **Registered marks** (ISU wordmark/logo, Cy, athletics marks) — excluded
  from the game per the master plan's mandate; a trademark matter, not
  copyright, and not ODbL's.

*T-171, 2026-11-09.*

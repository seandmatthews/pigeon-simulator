# Ames Survey — Master Index

**Date:** 2026-11-08 · **Purpose:** everything needed to rebuild the game's city
as real Ames, Iowa (home of Iowa State University) at true scale, per the
owner's sign-off: approximate street layout + all major landmarks, to scale,
every student-loved venue findable by a pigeon, real names wherever legally
comfortable (university registered marks excepted). **Status: COMPLETE and
QA'd — awaiting owner sign-off to commit.**

## How this was built

Ten chained research lanes (2 concurrent, starter-plan budget), then an
adversarial QA lane, then a fix-application pass (52 edits, probe-rechecked)
plus orchestrator reconciliation of the image tree. Every lane wrote only
inside `docs/references/ames-survey/`; the ledger in `verification/` is the
authority when any two documents disagree.

## Reading order for the master-plan writer

1. **`verification/VERIFICATION.md`** — the 30-item corrections ledger +
   ground-truth section. **This wins every dispute.**
2. **`census/BUILD-CENSUS.md`** — what is inside the core bbox; §7 is the
   15-constant generator parameter sheet; `authored-buildings.csv` classifies
   all 3,737 buildings.
3. **`MODELING-SPECS.md`** — per-cluster build specs (silhouette/palette/
   materials/dims/LOD/game-native), the 24-item fidelity list (F-01…F-24),
   district dressing rules, build-order ranking.
4. Then the reference layers as needed: `osm/SUMMARY.md` (geometry),
   `landmarks/LANDMARKS.md` (dims + dates), `venues/VENUES.md` (the dated
   venue inventory), `community/REDDIT-RESONANCE.md` +
   `community/TRADITIONS.md` (what places MEAN), `images/IMAGE_INDEX.md`
   (90 credited photos), `QA-REPORT.md` + `FIXES-APPLIED.md` (what was
   corrected and why).

## Ground-truth quick sheet

| Fact | Value |
|---|---|
| Game-core bbox | ≈ 4,050 × 2,610 m (10.6 km²) — lon −93.6590…−93.6100, lat 42.0120…42.0355 |
| Orientation (F-06) | Campus NORTH of Lincoln Way; Campustown SOUTH; avenues W→E Sheldon, Hayward, Welch, Stanton |
| Buildings in core | 3,737 → **512 authored-by-name (55.3 % of footprint) / 3,175 procedural** (median 127 m²) |
| Campanile | 33.5 m, 50 bells, 1897, **buff/tan brick** (not red) |
| Memorial Union | Pale gray limestone, squat square tower, at Lincoln Way & Morrill/Lynn; height of tower = model-to-look |
| Jack Trice | 61,500 seats, field runs **N–S**, footprints 183×208 m (bowl) |
| Lake LaVerne | 2.8 acres (≈ 11,300 m²), 236 × 122 m; swans gone since 2022 (Lancelot † Jun 2022, Elaine retired Nov 2022) |
| Marston Water Tower | 51.2 m, white painted steel with ISU seal |
| Rail | UP Clinton Subdivision double-track through-line; **9 at-grade crossings core-wide** (4 vehicular downtown); daily train = yellow SD70ACe coal drags; NO Amtrak (nearest stop Osceola) |
| Venues | 48 open (Tier 1: 14) + 17 closed/mourned; Welch sequence verified block-by-block |
| Streets | 727 named (99.6 km in core); downtown blocks ≈ 125–140 m, cardinal within 1° |
| The river | South Skunk River is OUTSIDE the core (1.4 km east) — in-core water = Ioway Creek, College Creek, Lake LaVerne |
| Signature civic look | Water tanks with green/blue diamond "AMES" + "We're Glad You're Here" |

## Top ritual fidelity (from TRADITIONS.md)

Campaniling: *"a student officially becomes an Iowa Stater when kissed under
the campanile at the stroke of midnight"* — jelly beans/lemon drops are the
documented penalty (paddling legend: rumor-only). The zodiac students refuse
to step on is in the **MU floor (Gold Star Hall)**. Jack Trice naming:
students' name 1975 / field 1984 / stadium 1997 / statue 1988→moved 1997.
Ames runs **Oktoberfest** (not "Oktemberfest" — that is Marshalltown's).

## Open items (none block the master plan)

- **No CC photo exists** (pointers recorded in CREDITS.md): summer Lincoln
  Way, Welch Ave Station signage, Parks Library 1925 facade, the SE grain
  elevator cluster. Residential street = house portraits only.
- **Unknowable from public data (model-to-look):** MU tower height, Reiman
  entrance-canopy spans, grain-elevator heights (30–40 m placeholder).
- **Carried flags:** 8 venue operating-status UNVERIFIED, tailgate-lot names,
  two 500-block cross-streets, Brookside boundary definition, the 105 vs
  114 m 5th→6th block method-drift note (QA probe), Brookside 05/06 Flickr
  URL swap caveat (nature/CREDITS.md).

## Commit split (QA item 10 — owner decision pending)

- **Commit:** all `*.md`, `streets.csv`, `authored-buildings.csv`, all
  scripts (`osm/scripts/`, `census/scripts/`, `verification/scripts/`,
  `_qa/probe_qa.py`, `community/_fetch.py`), `osm/ames_merged.json`
  (21 MB), and the 90 credited photos in `images/` (~148 MB).
- **Leave local (proposed `.gitignore` additions):**
  `docs/references/ames-survey/osm/raw/` (84 MB tiles),
  `census/scripts/tagged_nodes.json` (cache), `community/_cache/` (3.2 MB
  thread JSONs), `community/_cache2/` (never created).
- Survey totals: 258 MB / 270 files; zero files outside the survey tree.

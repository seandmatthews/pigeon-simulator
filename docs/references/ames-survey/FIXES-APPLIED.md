# Ames Survey — QA Fixes Applied (log)

Date-stamped: **2026-11-08**. Role: fix-application lane. Applied QA-REPORT.md
top-10 items **1, 2, 3, 4, 5, 6, 8, 9** to the sibling docs; item 7 (image
reconciliation) untouched — the pass-2 image lane still owns `images/` — and
item 10 (commit split) untouched — owner decision at sign-off.

Method: minimal surgical edits, each carrying a one-line
`*(QA fix 2026-11-08: … per QA-REPORT item N)*` note at the corrected spot.
Ground truth = `verification/VERIFICATION.md`; where a QA fix and the ledger
could disagree, the ledger was checked first (see "Conflicts" — none found).
Post-edit re-verification: `_qa/probe_qa.py` re-run read-only
(`python -I probe_qa.py ../osm/raw/ames_merged.json ../census/scripts/tagged_nodes.json`).

**Total: 52 edit operations across 6 files.** All probe-checkable fixes agree
with the OSM extract; zero reverts; zero ledger conflicts.

---

## Item 1 — Hughes Conservatory split from the 59 × 88 m building (B-03) — APPLIED

- `MODELING-SPECS.md` §1.9 item 3: "Hughes Conservatory 59 × 88 m with the
  blue-glass butterfly-wing roof" rewritten — the 59 × 88 m way (180765068,
  ≈2,994 m² shoelace) is the WHOLE "Reiman Gardens Conservatory" building
  (≈34,251 GSF per ISU Facilities); the named **Hughes glasshouse inside it is
  465 m² (5,000 sq ft)**; oversized-build warning added.
- `osm/SUMMARY.md` §9 Reiman Gardens row: Conservatory entry annotated with the
  same split ("do not model 'Hughes' as the 59×88 box").
- **Deferred (out of edit scope):** the QA item 1 note to V-23 itself —
  `verification/VERIFICATION.md` is not in this lane's editable set. V-23's
  "Conservatory 59 × 88 m confirmed" stands as a whole-building number; the
  reattribution is recorded in the two files above. Owner may add the note to
  the ledger at sign-off.
- Probe re-check: **AGREES** — probe 2: way 180765068 `name='Reiman Gardens
  Conservatory'`, bbox 59 × 88 m, area 2,994 m² (the way's own name is the
  whole building, not "Hughes").

## Item 2 — Hy-Vee two-store data (B-04) — APPLIED

- `census/BUILD-CENSUS.md` §1 top-25 row: "Hy-Vee (S Duff)" → "Hy-Vee (640
  Lincoln Way)"; note added after the table (no Hy-Vee on S Duff; the other
  store is 3800 Lincoln Way, way 186660819, 0.784 ha).
- `MODELING-SPECS.md` §1.6 item 4: "census §1 Hy-Vee footprint 0.699 ha" on the
  3800 store → footprint 0.784 ha (way 186660819), with the 640 Lincoln Way /
  0.699 ha attribution note.
- `MODELING-SPECS.md` §3 rule 5: S Duff grocery anchors "(Walmart 534, Hy-Vee
  0.699 ha, ALDI)" → "(Walmart 534, ALDI — no Hy-Vee on S Duff; Ames's two
  Hy-Vees are 3800 Lincoln Way and 640 Lincoln Way)".
- Probe re-check: **AGREES** — probe 1: way 186660819 addr 3800 Lincoln Way,
  area 7,842 m² (0.784 ha); way 98658304 addr **640 Lincoln Way**, area
  6,993 m² (0.699 ha). Consistent with the ledger's own §5 chain ("3800 Hy-Vee
  → 3720 Fareway Meat Market").

## Item 3 — LANDMARKS corrections A-01…A-12 — APPLIED

All in `landmarks/LANDMARKS.md` (16 edits):

| Finding | Where | Edit |
|---|---|---|
| A-01 | §1 orientation bullets | Campustown **south** of Lincoln Way; Lincoln Way along the **south** side of central campus (campus north of it); University Blvd = EAST gate of Campustown, not a west/southwest campus edge (V-01) |
| A-03 | §1 | commercial grid 2.93 km **due east** of the MU (was "1.5 km northeast") (V-04) |
| A-02 | §1 | Lincoln Way dead E–W at 269.3° (was "diagonal-ish NE–SW") (V-03) |
| A-04 | C4 table + §5 item 9 | Parks **N** of Campanile (was "S of") (V-07) |
| A-05 | C5 table + C5 body + §5 item 8 | MU at Lincoln Way & **Morrill Rd/Lynn**, one block east of Stanton (V-08) |
| A-11 | C5 table + §5 item 8 | MU pale gray-limestone (was "dark-brick") (photos, F-02) |
| A-06 | C6 body + §6 UNVERIFIED tail | field NORTH–SOUTH settled (V-09); "Wikipedia states east–west" misquote replaced; stale unverified-list entry removed |
| A-07 | T4 table + T4 body | full store **619 Burnett**; 3720 L/W = Meat Market #189; 534 S Duff = Walmart; "#792" dropped (V-15) |
| A-08 | C13 body | Cy Walk bridge **open since ~2024** (was "In 2026 ISU was also building") (V-17) |
| A-09 | C2 table + C2 body | Marston tank white/pale-gray (was "dark tank"/"dark pin-cushion") (photos, F-03) |
| A-10 | C1 table | Campanile buff/tan brick (was "red-brick") (photos, F-01) |
| A-12 | C11 table | lake swanless since 2022, drained mid-2026 (was present-tense swans) (V-13/V-14) |

- Probe re-check: probe_qa.py has no direct probe for these (they are
  ledger-settled orientation/color/name facts, V-01…V-17) — verified against
  the ledger verdicts, which all agree with the applied values.

## Item 4 — VENUES corrections A-14…A-22 — APPLIED

All in `venues/VENUES.md` (12 edits): Kum & Go #203 on the SAME west side (A-14,
V-21); The Cafe in NORTH Ames, ~4.5 km from Provisions' south research park (A-15,
V-19); Great Plains at the EAST end near Duff/Douglas (A-16, V-06); Cornbred depot
at the WEST end near Clark/Pearle — both its Location line and pigeon cue (A-17,
V-06); Aunt Maude's at Main's WEST end (A-18, V-06); Morning Bell at the EAST end
at Duff (A-19, V-06); §5.2 heading relabelled east→west (A-20, V-06); §4 east-of-Welch
L/W note re-ordered to 23 Twenty (2320) then The Foundry (2300) (A-21, V-20); §5.1
same order fix (A-21, V-20); §5.1 Fareway → Meat Market #189 with full store 619
Burnett (A-22, V-15); §7 near-corridor note same Fareway fix (A-22, V-15).

- Probe re-check: no direct probe (ledger-settled V-06/V-15/V-19/V-20/V-21) —
  verified against the ledger, which agrees.

## Item 5 — Hilton Coliseum distance (B-01) — APPLIED

- `MODELING-SPECS.md` §1.3 silhouette: "300 m northeast" → "~790 m
  center-to-center to the northeast (~640 m edge-to-edge; OSM probe)".
- Probe re-check: **AGREES** — probe 3: Hilton centroid (−93.63464, 42.02096)
  vs bowl centroid (−93.63580, 42.01387) = **793 m** center-to-center, ~96 m E /
  ~787 m N (NE direction confirmed), 644 m lat-wise edge gap.

## Item 6 — depot-Amtrak claims (B-05) — APPLIED (half) / DEFERRED (half)

- `MODELING-SPECS.md` §1.8 item 2 note: "but the real depot serves Amtrak"
  struck — Ames has no Amtrak service (Iowa's stops are on the southern-BNSF
  California Zephyr line; nearest is Osceola); depot = unhosted scenery per F-20.
- **Deferred to item 7:** the IMAGE_INDEX rail-row-08 half of the claim —
  `images/IMAGE_INDEX.md` is inside `images/`, which this lane must not touch
  while the pass-2 image lane is running.
- Probe re-check: not probe-able (web-sourced finding); QA §2 claim 1 verdict
  applied as written. SUMMARY §8 needed no change (QA confirms it was right).

## Item 8 — SUMMARY §4/§5 stale numbers — APPLIED

All in `osm/SUMMARY.md` (7 edits):

| Finding | Where | Edit |
|---|---|---|
| A-25 | §4 Duff Avenue row | lon ≈ −93.6154 → **−93.6104** (V-05) |
| A-26 | §5 Lincoln Way corridor | label "west→east from Duff" → "east→west from Duff"; gap numbers stand (ledger §1) |
| A-27 | §5 downtown spacing | Main→5th ≈ 80 m → **86 m**; 5th→6th ≈ 205 m → **105 m** (census §2, specs F-10) |
| B-10 | §5 Campustown polygon | "between State Ave and Sheldon" → "between ~Hyland Ave and ~Morrill Rd/Lynn" with probe bbox note |
| B-10 | §6 Campustown line | same extent claim corrected (repeat of §5's sentence, same file — logged as an extra instance) |
| A-29 | §2 TL;DR stadium row | 55,000 tag flagged stale (2007–12); official 61,500 since 2015 (V-10) |
| (item 1) | §9 Reiman row | Conservatory split note (see item 1) |

- Probe re-check: **AGREES** — probe 6: Duff downtown-band mean lon −93.61043;
  probe 5: polygon bbox lon −93.65554…−93.64649, State Ave corridor mean −93.65913
  (~297 m west of the edge, outside), Sheldon −93.65423 inside, Morrill −93.64650
  at the east edge — "~Hyland → ~Morrill Rd/Lynn" confirmed.
- Supplementary check (not part of probe_qa.py): Main→5th reproduces at
  **86 m** exactly (mean/median of downtown-band node lats). 5th→6th measures
  **≈114–115 m** by node-mean/median vs the census's ≈105 m — a ~10 m sub-block
  method variance of the same class QA-REPORT B-11 waves through. **Not
  reverted** (the endorsed value is census §2's, adopted by specs F-10 — all
  three docs now agree; probe_qa.py has no check for this pair). Flagged below
  under "Observations for the owner".

## Item 9 — Small corrections sweep — APPLIED (8 fixes) / SKIPPED (3, out of scope)

Applied:

| Finding | File | Edit |
|---|---|---|
| B-02 | `venues/VENUES.md` §3.9 | Szechuan House "~3.5 km west of Welch" → "~1.4 km west of Welch". Probe 4: **AGREES** — 1,436 m from the Welch/Lincoln Way corner |
| A-23 | `community/REDDIT-RESONANCE.md` | §1 row 28 zodiac → **MU Gold Star Hall floor** (not a Curtiss–Beardshear sidewalk; that pairing is the streak run, TRADITIONS §9.5); §3 "zodiac walk between Curtiss and Beardshear" corrected; §2 quote-14's editorial bracket gloss corrected (third instance of the same error, same file — logged) |
| A-24 | `community/REDDIT-RESONANCE.md` | §1 B-list + §4 Clouds entries annotated: "12th floor" is the commenter's error — café is on the **7th floor** (cloudsames.com, V-16); verbatim quotes left untouched |
| B-09 | `census/BUILD-CENSUS.md` §2 | "2 are anchored but outside the core box" → **3** (Hickory Park S, The Cafe N, Provisions S) — now sums to 31 and matches §7.7 |
| B-07 | `MODELING-SPECS.md` §4 | "a third of the authored footprint" → **57 % of the authored footprint** (38.3 ha of 66.7 ha; the "third" was of the 120.7 ha total) |
| B-07 | `census/BUILD-CENSUS.md` §6 "Bottom line" | same sentence the specs quote carries the same error — fixed identically (extra instance, same finding, in-scope file) |
| B-08 | `MODELING-SPECS.md` §1.4 GAME-NATIVE | Barks@Parks → **indoors, Parks Library Upper Rotunda, 2nd floor** (was "on the library lawn") |

Skipped (with reason):

| Finding | Target | Reason |
|---|---|---|
| B-06 | `images/IMAGE_INDEX.md` "MU sits on its south side" | under `images/` — deferred to item 7 (image lane) |
| A-30 | `images/misc/CREDITS.md` Fareway address | under `images/` — deferred to item 7 (image lane) |
| B-14 | `community/TRADITIONS.md` `_cache2` manifest phantom | TRADITIONS.md is not in this lane's editable file set — needs an owner/one-line fix ("Left EMPTY" → directory does not exist) |

## Deferred — item 7 (untouched, per scope)

`images/` entirely: nature/05↔06 and campus/02 re-cuts, nature/10 corrupt file,
`_pass2-review/` staging cleanup, B-06 IMAGE_INDEX note, A-30 misc/CREDITS
Fareway line, and the "10 unindexed extras" count. The MODELING-SPECS §1.8
IMAGE_INDEX half of the Amtrak strike is likewise deferred (see item 6).

## Skipped — item 10 (owner decision at sign-off)

Commit split and `.gitignore` additions (QA §4) — not applied.

## Conflicts between QA fixes and the verification ledger

**None.** Checked before each edit: V-01/V-03/V-04/V-05/V-06/V-07/V-08/V-09/
V-10/V-13/V-14/V-15/V-16/V-17/V-19/V-20/V-21 all agree with the applied values;
the ledger's §5 chain already treats 3800 Lincoln Way as Hy-Vee (consistent with
item 2); ledger V-23's "Conservatory 59 × 88 m confirmed" is compatible with
item 1's name reattribution (the number was the whole building's — note deferred
since the ledger file is out of edit scope).

## Observations for the owner (no action taken)

1. **5th→6th spacing:** census §2's ≈105 m measures ≈114–115 m by plain
   downtown-band node-mean/median (Main→5th reproduces at exactly 86 m).
   Sub-block method drift; if the master plan hardens F-10 for the generator,
   re-measure with the census's own methodology before pinning.
2. **Ledger V-23 note deferred** (see item 1) — one line to add at sign-off.
3. **TRADITIONS `_cache2` manifest line** (B-14) — one-line fix outside this
   lane's file set (see item 9 skips).

## File manifest (all files touched)

| File | Edits |
|---|---|
| `docs/references/ames-survey/MODELING-SPECS.md` | 7 |
| `docs/references/ames-survey/landmarks/LANDMARKS.md` | 16 |
| `docs/references/ames-survey/venues/VENUES.md` | 13 |
| `docs/references/ames-survey/osm/SUMMARY.md` | 7 |
| `docs/references/ames-survey/community/REDDIT-RESONANCE.md` | 5 |
| `docs/references/ames-survey/census/BUILD-CENSUS.md` | 4 |
| **Total** | **52** |

Inputs read, not modified: `QA-REPORT.md`, `verification/VERIFICATION.md`,
`_qa/probe_qa.py`, `osm/raw/ames_merged.json` (probe, read-only),
`census/scripts/tagged_nodes.json` (probe, read-only). Nothing under `images/`
was read or modified.

*Fix-application lane, 2026-11-08.*

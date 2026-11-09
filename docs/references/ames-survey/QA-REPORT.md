# Ames Survey — QA / Red-Team Report

Date-stamped: **2026-11-08**. Role: final adversarial quality review of the eight
survey lanes, run BEFORE the index is compiled and the master plan is written.
Research-only: nothing outside `docs/references/ames-survey/QA-REPORT.md` and
`_qa/` was created or edited.

**Severity tags:** `blocks-build` (would put something wrong into the world even if
every lane is followed via the declared authority chain) · `misleads` (wrong or
unapplied correction that can mislead a reader but is recoverable via the ledger) ·
`cosmetic` (drift, arithmetic, prose).

---

## 1. Cross-document consistency sweep

**Method:** every deliverable read end-to-end; every number/direction/name/date
cross-checked against `verification/VERIFICATION.md` (ground truth), the OSM extract
reprobed where cheap (see §2), and the photo record. The ledger's settled verdicts
are treated as final; findings are split into (A) sibling text still contradicting
settled verdicts with no in-file correction note, and (B) NEW contradictions the
ledger did not catch.

### 1A. Settled-by-ledger contradictions still live in sibling files (unapplied corrections)

No sibling file was edited by the ledger by design — but none of them carries a
"corrections applied" pointer either, so each reads as false on its own. Severity
is `misleads` throughout unless the modeling specs (the builder-facing doc) also
copied the error, in which case it escalates.

| ID | Where | What it still says | Per ledger / evidence | Severity |
|---|---|---|---|---|
| A-01 | `landmarks/LANDMARKS.md` §1 | Campustown "sits just **north**" of Lincoln Way; "Lincoln Way forms the campus's **northeast edge**"; "University Blvd on the **west/southwest** edge and Lincoln Way on the north" | V-01: campus NORTH of Lincoln Way, Campustown SOUTH; University Blvd is the EAST gate of Campustown | misleads |
| A-02 | `landmarks/LANDMARKS.md` §1 | Lincoln Way "diagonal-ish NE–SW through town" | V-03: dead E–W (bearing 269.3°) | misleads |
| A-03 | `landmarks/LANDMARKS.md` §1 | Commercial grid "roughly 1.5 km **northeast** of the Memorial Union" | V-04: 2.93 km **due east** | misleads |
| A-04 | `landmarks/LANDMARKS.md` C4 table + §5 item 9 | Parks Library "S of Campanile" / "south of the Campanile" | V-07: Parks (42.02811) is NORTH of the Campanile (42.02542) | misleads |
| A-05 | `landmarks/LANDMARKS.md` C5 table/body + §5 item 8 | MU at "corner Lincoln Way & Stanton Ave"; "corner block at Lincoln Way & Stanton" | V-08: Lincoln Way & **Morrill Rd/Lynn**, one block east of Stanton | misleads |
| A-06 | `landmarks/LANDMARKS.md` C6 body + §6 UNVERIFIED tail | "Wikipedia states the field runs east–west, unusual for D-I — single source; verify against imagery"; unverified list still carries "field east–west orientation" | V-09: field runs NORTH–SOUTH; the citation is a misquote; settled — the whole caveat is stale | misleads |
| A-07 | `landmarks/LANDMARKS.md` T4 | Fareway "store #792 at **534 S Duff Ave**" | V-15: 534 S Duff is the **Walmart Supercenter**; full store = **619 Burnett**; 3720 L/W = Meat Market #189; drop "#792". (MODELING-SPECS F-08 already corrects this, so it cannot leak — misleads at document level only) | misleads |
| A-08 | `landmarks/LANDMARKS.md` C13 | "In 2026 ISU was also **building** a pedestrian bridge over University Blvd" | V-17: East Gateway bridge ("Cy Walk") **open since ~2024** | misleads |
| A-09 | `landmarks/LANDMARKS.md` C2 body + §5 item 6 | Marston "riveted **dark** tank"/"dark pin-cushion" | F-03 (photos): tank is **white/pale-gray** painted steel | misleads |
| A-10 | `landmarks/LANDMARKS.md` C1 table + §5 item 4 | "slender **red-brick** needle" | F-01 (photos + IMAGE_INDEX): buff/tan brick | misleads |
| A-11 | `landmarks/LANDMARKS.md` C5 body + §5 item 8 | MU "huge **dark-brick** Georgian block" | F-02 (photos): pale gray limestone | misleads |
| A-12 | `landmarks/LANDMARKS.md` C11 table | "the oval pond beside the MU **with two white specks (the swans) on it**" — present tense | V-13: swanless since 2022 (Lancelot died Jun 2022, Elaine retired Nov 2022); lake drained mid-2026 | misleads |
| A-13 | `landmarks/LANDMARKS.md` T5 + §5 item 15 | Airport "~2 mi **SE** of downtown" | V-26: essentially due S, slightly W (SSW), 3.9 km | cosmetic |
| A-14 | `venues/VENUES.md` §1.1 pigeon cue | "Kum & Go's … store at #203 **opposite**" the 207 building | V-21: both on the WEST side of the 200 block (§4's own fly-through has it right) | misleads |
| A-15 | `venues/VENUES.md` §1.13 | The Cafe "ISU Research Park, **south of campus**" | V-19: 2616 Northridge Pkwy is **north** Ames (~4.5 km from Provisions' south-research-park site). The census's own venue table puts the node 1.5 km NORTH of the core — cross-lane inconsistency | misleads |
| A-16 | `venues/VENUES.md` §1.14 | Great Plains "near Clark (100 block, **west end**)" | V-06: 129 Main is the **EAST** end near Duff/Douglas | misleads |
| A-17 | `venues/VENUES.md` §2.6 | Cornbred depot "at downtown's **east** end" | V-06: 526 Main is the **WEST** end (near Clark/Pearle) | misleads |
| A-18 | `venues/VENUES.md` §2.12 | Aunt Maude's at "Main's **east** end" | V-06: 547 Main is the **WEST** end | misleads |
| A-19 | `venues/VENUES.md` §3.16 | Morning Bell "downtown **west** end" | V-06: 111 Main is the **EAST** end at Duff | misleads |
| A-20 | `venues/VENUES.md` §5.2 | Venue sequence labelled "west → east" | V-06: as written it runs **east→west**; reverse the label | misleads |
| A-21 | `venues/VENUES.md` §4 note + §5.1 | "…then east: **The Foundry (2300)** … then **23 Twenty Lincoln (2320)**" | V-20: swapped — correct W→E is 23 Twenty (2320) then The Foundry (2300). MODELING-SPECS §1.6 already implements the fix | misleads |
| A-22 | `venues/VENUES.md` §5.1 + §7 note | "Fareway (3720 L/W + **534 S Duff**)" | V-15: 534 S Duff is Walmart; full store 619 Burnett | misleads |
| A-23 | `community/REDDIT-RESONANCE.md` #28 + §3 | "The zodiac (**Curtiss–Beardshear sidewalk**)"; "the zodiac walk between Curtiss and Beardshear" | TRADITIONS §9.5 / F-13: the zodiac is the **MU Gold Star Hall floor**; the Curtiss–Beardshear pairing is the streak run | misleads |
| A-24 | `community/REDDIT-RESONANCE.md` §1 B-list + §4 | "Clouds coffee on the **12th floor** of Legacy Tower" | V-16: **7th floor** (VENUES §3.2 flags the floor number as the commenter's error, but the REDDIT doc itself carries no note) | cosmetic |
| A-25 | `osm/SUMMARY.md` §4 table | "Duff Avenue … downtown N–S spine at lon ≈ **−93.6154**" | V-05: typo for **−93.6104** (re-probed: downtown-band mean −93.61043) | misleads |
| A-26 | `osm/SUMMARY.md` §5 | Lincoln Way corridor crossings labelled "west→east from Duff" | Ledger §1: the list actually runs **east→west**; the gap numbers are right | misleads |
| A-27 | `osm/SUMMARY.md` §5 | "Main → 5th ≈ **80 m**; 5th → 6th ≈ **205 m**" | census §2 re-measurement: **86 m** / **105 m** (census explicitly flags; specs F-10 adopt census; SUMMARY still carries the old numbers) | misleads |
| A-28 | `landmarks/LANDMARKS.md` C6 body | "field = Jack Trice Field **from 1975**" | TRADITIONS §3/§9: 1975 informal use, 1984 formal field naming, 1997 stadium rename | cosmetic |
| A-29 | `osm/SUMMARY.md` §2 TL;DR | "Jack Trice Stadium | … (55,000 capacity tag)" — no staleness note | V-10: tag is the stale 2007–12 value; official 61,500 | cosmetic |
| A-30 | `images/misc/CREDITS.md` note | "the Ames store (**534 S Duff**) has no CC photo" | V-15: the full Ames store is 619 Burnett; 534 S Duff is Walmart | cosmetic |

### 1B. NEW contradictions the ledger did NOT catch

| ID | Where | What | Evidence (fresh) | Severity |
|---|---|---|---|---|
| B-01 | `MODELING-SPECS.md` §1.3 silhouette | "the **Hilton Coliseum drum** (138 × 105 m) **300 m northeast**" (of the stadium) | OSM re-probe (`_qa/probe_qa.py`): Hilton centroid (−93.63464, 42.02096) vs bowl centroid (−93.63580, 42.01387) = **793 m center-to-center** (~640 m edge-to-edge). Off by 2.6×. Geometry itself comes from census coords, so only the prose is wrong — but the build-order doc is the builder's mental model | misleads |
| B-02 | `venues/VENUES.md` §3.9 | Szechuan House "~**3.5 km** west of Welch" | OSM: Szechuan way centroid −93.66734 (the ledger's own V-20 anchor) = **1.44 km** west of the Welch/Lincoln Way corner. Off by 2.5× | cosmetic |
| B-03 | `MODELING-SPECS.md` §1.9 vs `landmarks/LANDMARKS.md` C10 (and `osm/SUMMARY.md` §9, ledger V-23) | Specs: "**Hughes Conservatory 59 × 88 m** with the blue-glass butterfly-wing roof". LANDMARKS C10 (official reimangardens.com): Hughes Conservatory = **5,000 sq ft (465 m²)**. OSM way 180765068 "Reiman Gardens Conservatory": 59×88 m bbox, 2,994 m² shoelace, 1 level, h=10 | Web: Hughes glasshouse = 5,000 sq ft; **ISU Facilities lists the whole "Reiman Gardens Conservatory" building at 34,251 GSF (≈3,181 m²)** — matching the OSM 59×88 m way almost exactly. So 59×88 m is the WHOLE conservatory building (incl. service ranges); 465 m² is the named Hughes glasshouse inside it. V-23's "Conservatory 59×88 m confirmed" is half-right and misattributes the source. The L3 south-gate set piece would be built ~11× oversized if "Hughes = 59×88" is followed | **blocks-build** |
| B-04 | `census/BUILD-CENSUS.md` §1 top-25 + §3 rule references, inherited by `MODELING-SPECS.md` §1.6 item 4 + §3 rule 5 | Census labels way 98658304 "**Hy-Vee (S Duff)**" (0.699 ha); specs cite "census §1 Hy-Vee footprint **0.699 ha**" for the **3800 Lincoln Way** store and put a "Hy-Vee 0.699 ha" among the **S Duff** grocery anchors | OSM: **two** Hy-Vee supermarkets — way 186660819 addr **3800 Lincoln Way** (0.784 ha, 113×78 m) and way 98658304 addr **640 Lincoln Way** (0.699 ha, 105×91 m). Web (hy-vee.com store pages): Ames #1 at 3800 Lincoln Way (west), Ames #2 "Lincoln Center" at **640 Lincoln Way** near Grand Ave. No Hy-Vee is on S Duff; the two footprints are swapped and the "(S Duff)" label is wrong | **blocks-build** |
| B-05 | `images/IMAGE_INDEX.md` rail row 08 note + `MODELING-SPECS.md` §1.8 note | "the 1906-era C&NW depot **serving Amtrak today**" / "the real depot **serves Amtrak**" | Web (Iowa DOT / Amtrak station lists): Iowa's six Amtrak stops are all on the southern-BNSF California Zephyr line (Burlington, Fort Madison, Mount Pleasant, Osceola, Ottumwa, Creston). **Ames has no Amtrak service**; nearest stop Osceola (~45 min). SUMMARY §8 was right (and understated: it's not just an OSM gap, it's reality). Note the internal tension: specs F-20 says "treat the train stop as fiction-adjacent" while §1.8 asserts real service | misleads |
| B-06 | `images/IMAGE_INDEX.md` lincolnway cluster note | "the university edge (**MU sits on its south side** at 2229 Lincoln Way)" | V-01: the MU is on the **north** side of Lincoln Way (all of central campus is north; Campustown is south). The MU's *south facade* faces Lincoln Way, but the building is on the north side | misleads |
| B-07 | `MODELING-SPECS.md` §4 rationale (twice, §4 + §1.4 LOD rationale) | campus 152 buildings / 38.3 ha called "**a third of the authored footprint**" | census §6: authored named total 66.7 ha → campus is **57 %** of authored; 38.3 ha is a third of the **total** building footprint (120.7 ha). Wrong referent | cosmetic |
| B-08 | `MODELING-SPECS.md` §1.4 GAME-NATIVE | "Barks@Parks therapy dogs **on the library lawn**" | TRADITIONS §6: Barks@Parks is **inside, Upper Rotunda, 2nd floor of Parks Library** (noon–3, prep week) | cosmetic |
| B-09 | `census/BUILD-CENSUS.md` §2 prose vs §7.7 | §2: "26 of 31 … **2** are anchored but outside the core; 1 has no anchor; 1 is a cart" (sums to 30 of 31) | §7.7 correctly lists **3** out-of-core (Hickory S, The Cafe N, **Provisions S**) + 1 no-anchor + 1 cart = 31. The §2 sentence dropped Provisions | cosmetic |
| B-10 | `osm/SUMMARY.md` §5 | Campustown polygon "wrapping Lincoln Way **between State Ave and Sheldon**" | OSM re-probe: polygon way 918491523 bbox lon −93.65554…−93.64649 — from ~**Hyland** to ~**Morrill Rd/Lynn**; State Ave (−93.65913) is 296 m west of the polygon edge; Sheldon is *inside* it. (Its own 748×269 m dims + 11 ha center are correct; census §2's "Sheldon→Stanton" heading is also imprecise the same way) | cosmetic |
| B-11 | `osm/SUMMARY.md` §4 vs census/ledger | Welch centerline "lon −93.6498" vs census/ledger −93.65013/−93.65015 (probe mean −93.64999); Sheldon "−93.6549" vs −93.65422; Hayward→Welch gap "130 m" (SUMMARY §5) vs "134 m" (census §2); Sheldon→Hayward "208" vs "204" | Measurement-method drift at sub-block scale; census values adopted downstream by the specs | cosmetic |
| B-12 | ledger §5 vs `venues/VENUES.md` §3.9 | Ledger's "Lincoln Way **south-side** addresses increase westward" chain cites "3605 Szechuan (−93.66734)" — but Szechuan House is on the **north** side (OSM centroid lat 42.02327 > LW's 42.0228; VENUES §3.9 says "north side"). The numbering-direction rule still holds via the other (genuinely south-side) anchors | cosmetic |
| B-13 | ledger §5/V-12 vs census §5/SUMMARY §7 | Lake LaVerne center "−93.64792, 42.02354" (ledger recomputation) vs "−93.64802, 42.02357" (census/SUMMARY) — ~9 m drift between the ledger's ring recomputation and the sibling number. Specs use the ledger value | cosmetic |
| B-14 | `community/TRADITIONS.md` manifest | "`community/_cache2/` Left EMPTY" — the directory does not exist on disk at all | cosmetic |
| B-15 | `landmarks/LANDMARKS.md` C1 vs `osm/SUMMARY.md` §6 vs census §3 | Campanile base "4.9×4.9 m" vs "7 × 7 m footprint" vs census 6.8×6.7 m | Reconciled in MODELING-SPECS §1.1 (shaft vs plinth-inclusive bbox) but the three docs never say so | cosmetic |
| B-16 | census §1 vs `landmarks/LANDMARKS.md` C8 | Morrill Hall census footprint 763 m² vs LANDMARKS "27,172 sq ft (2,524 m²)" | Not a contradiction (footprint vs GSF over 3 levels) but the pair is never reconciled the way Beardshear is | cosmetic |

**Swept and clean (no findings):** address-parity rules (V-20/V-22 chains), all
census §7 generator constants vs the specs' §3 rules, venue anchor tables vs
appendix coordinates, distances in ledger §5 vs specs §1 (Campanile↔LaVerne 264 m,
Campanile↔stadium 1.53 km, Main×Duff chains), Welch-address venue sides, the
TRADITIONS↔REDDIT quote chain, VEISHEA/801/Oktemberfest trap set, rail-crossing
lists, water extents, park areas vs V-23/V-24/V-25, and the pass-2 header notes in
MODELING-SPECS (confirmed accurate on disk — see §3).

---

## 2. Sample verification against reality (8 load-bearing claims, none ledger-settled)

| # | Claim (doc) | Re-check | Result | Confidence |
|---|---|---|---|---|
| 1 | "the 1906-era C&NW depot **serving Amtrak today**" (`images/IMAGE_INDEX.md` rail notes; also `MODELING-SPECS.md` §1.8 "the real depot serves Amtrak") | Web search: Iowa DOT passenger-rail page + Amtrak station lists | **FALSE.** Ames is not an Amtrak stop. Iowa's California Zephyr stops (Burlington, Fort Madison, Mount Pleasant, Osceola, Ottumwa, Creston) are all on the southern BNSF line; nearest to Ames is Osceola (~45 min). The depot is unhosted scenery — which is what SUMMARY §8 and specs F-20 assumed | High |
| 2 | "**Hughes Conservatory 59 × 88 m**" (`MODELING-SPECS.md` §1.9; `osm/SUMMARY.md` §9; ledger V-23 "confirmed") vs "Hughes Conservatory — 5,000 sq ft (465 m²)" (`landmarks/LANDMARKS.md` C10) | Web (reimangardens.com / ISU Facilities building 154) + OSM probe of way 180765068 | **BOTH real, different objects.** Hughes glasshouse = 5,000 sq ft (465 m²); the whole ISU "Reiman Gardens Conservatory" building = 34,251 GSF (≈3,181 m²), matching the OSM 59×88 m / 2,994 m² way. Specs conflate the two names; V-23's source attribution is wrong. Fix before modeling the south-gate set piece | High |
| 3 | Census "Hy-Vee **(S Duff)**" way 98658304 / specs' "Hy-Vee footprint **0.699 ha**" attached to the 3800 Lincoln Way store and to the S Duff strip (`census/BUILD-CENSUS.md` §1, `MODELING-SPECS.md` §1.6 + §3.5) | OSM probe (both ways' addr tags) + hy-vee.com store locator | **MIXED UP.** Two full-service Ames stores: #1 at **3800 Lincoln Way** (way 186660819, 0.784 ha) and #2 "Lincoln Center" at **640 Lincoln Way** near Grand (way 98658304, 0.699 ha — the census's mislabeled one). No Hy-Vee on S Duff | High |
| 4 | Hilton Coliseum "**300 m northeast**" of Jack Trice Stadium (`MODELING-SPECS.md` §1.3) | OSM probe: centroids of ways 180651868 and 613735866 | **FALSE — 793 m center-to-center** (~640 m edge-to-edge). Wrong by 2.6×; geometry unaffected (coords come from census) | High |
| 5 | Szechuan House "~**3.5 km** west of Welch" (`venues/VENUES.md` §3.9) | OSM probe: named way centroid −93.66734 vs Welch corridor mean lon −93.64999 | **FALSE — 1.44 km** west of the Welch/Lincoln Way corner. Wrong by 2.5× | High |
| 6 | Campustown commercial polygon "wrapping Lincoln Way **between State Ave and Sheldon**" (`osm/SUMMARY.md` §5) | OSM probe: way 918491523 bbox lon −93.65554…−93.64649; corridor means for State/Hyland/Sheldon/Stanton/Morrill | **FALSE — the polygon spans ~Hyland → ~Morrill Rd/Lynn** (748×269 m, 11.0 ha, center as published). State Ave lies 296 m west of the polygon; Sheldon and Stanton are inside it. Dims are right, the prose extent is wrong (census §2's "Sheldon→Stanton" heading is similarly loose) | High (local data) |
| 7 | Ames Municipal Airport: RWY 1/19 **1,738×30 m (5,701×100 ft)** asphalt, RWY 13/31 1,064×23 m, elev 291.3 m, **no control tower** (`landmarks/LANDMARKS.md` T5) | Web (AirNav KAMW + pilot guides) | **CONFIRMED in full** — 5,701×100 ft asphalt, non-towered, ~956 ft MSL. LANDMARKS T5 is accurate as written | High |
| 8 | Stomping Grounds / Bar La Tosca (303 Welch) — `venues/VENUES.md` §7 UNVERIFIED ("Netlify placeholder site"), carried forward open by V-29 | Web search (DiscoverAmes directory, Yelp updated late 2026, Oct 2026 press) | **ACTIVE** — DiscoverAmes lists "Bar La Tosca / Stomping Grounds Café, 303 Welch" as a current listing; Yelp entry updated late 2026; Oct 2026 article. One VENUES/V-29 flag resolves positively. (The other seven V-29 flags remain open.) | Medium-high |

Also re-probed from the local extract while in there: Duff Ave downtown lon =
−93.61043 (confirms V-05 vs SUMMARY §4's −93.6154); Welch corridor mean lon
−93.64999; Campustown polygon area 10.98 ha (matches the published 11 ha).
Probe script: `_qa/probe_qa.py` (reads `osm/raw/ames_merged.json` +
`census/scripts/tagged_nodes.json` read-only).

---

## 3. Image integrity audit

**Tree:** `images/IMAGE_INDEX.md` + 10 cluster dirs holding **83 indexed JPGs**
(campanile 10, laverne 6, stadium 9, campus 17, campustown 4, lincolnway 4,
downtown 8, rail 10, nature 9, misc 6 — exactly the index's counts, **no index row
whose file is missing**), each cluster with a `CREDITS.md`, plus the unindexed
`_pass2-review/` staging folder.

**Byte-level scan (all 151 JPGs, SOI/EOI + size):**

| File | Finding | Severity |
|---|---|---|
| `nature/10-reiman-conservatory-wing-roof.jpg` | **INDEXED and UNDECODABLE** — Read tool fails ("Unable to decode image data") despite passing byte checks. MODELING-SPECS's suspicion confirmed. The index row (blue-glass wing roof) is effectively sourced from text only | misleads (repair or replace before master plan) |
| `_pass2-review/ft_44248909705_b2.jpg` | **CORRUPT junk** — 462 bytes, no JPEG SOI (a failed download saved as .jpg). Unindexed pass-2 extra | cosmetic (delete) |
| `stadium/01-interior-night-videoboard.jpg` | Missing JPEG EOI trailer (truncated tail) — but **decodes completely** and matches its index row; benign | cosmetic (note only) |
| `_pass2-review/parks_jaretac.jpg` | MODELING-SPECS header says undecodable — **STALE: it now decodes** and shows the Parks Library addition (glass + white panels + sculpture, snow) as expected. The specs' pass-2 note is half right (nature/10) and half outdated (this file) | cosmetic |

**CREDITS audit:** all 10 `CREDITS.md` files carry a source URL, site,
photographer and license for **every one of the 83 rows** — no missing URLs. View-
online (all-rights-reserved) pointers are correctly kept OUT of the downloads.
Gap notes are honest and match the index.

**Credits/integrity gaps in `_pass2-review/`:** the staging folder holds ~**72
JPGs** (24 top-level + 47 in `pxl/` + a contact sheet), 2 HTML scrapes
(`dvids_page.html`, `flickr_welch.html`) and `pxl/dl_list.txt` — versus
MODELING-SPECS's claim of "10 unindexed extras". None of them has any CREDITS
entry, yet the specs cite at least 8 of them by path (`aerial_isu.jpg`,
`jtcomplex.jpg`, `hilton_tonywebster.jpg`, `parks_dirk2010.jpg`,
`parks_cburnett.jpg`, `parks_jaretac.jpg`, plus natguard/dvids-adjacent). Filenames
hint at sources (tonywebster/dirk/cburnett are known CC authors) but that is not a
credits record. If any pass-2 file ships, it ships uncredited.

**Cluster-assignment spot checks (7 files Read):**

| File | Index row says | On disk | Verdict |
|---|---|---|---|
| `campanile/02-spring-closeup.jpg` | 3/4 close-up, clock faces, belfry arches, event tent | Matches — buff/tan brick, dark slate cap, crockets, 2 white dials, white event tent | OK (also independently confirms F-01) |
| `laverne/03-swans-on-frozen-lake.jpg` | Two swans on partially frozen lake, snow | Matches | OK |
| `downtown/05-durham-bandshell-front.jpg` | Copper shell + pale arcs head-on | Matches — dark weathered-copper outer arch, pale mint inner shells (confirms F-11) | OK |
| `rail/08-ames-depot.jpg` | Brick, red tile roof, arched dormers, green canopy brackets | Matches | OK |
| `misc/01-ames-water-tower-logo.jpg` | Diamond "AMES" logo close-up | Matches | OK |
| `nature/05-brookside-park-footbridge.jpg` | "Rust-red **steel footbridge** over Ioway Creek" | **MISMATCH — file holds the row-06 subject**: the stone RR-bridge abutment carrying a steel rail bridge. MODELING-SPECS's pass-2 note confirmed on disk | WRONG CONTENT (re-cut row 05/06 or fix the index) |
| `campus/02-beardshear-green-dome-autumn.jpg` | "Beardshear full frontal, **green dome**, autumn — THE dome shot" | **MISMATCH — winter portico close-up** (columns + pediment + snow); no dome visible. MODELING-SPECS's pass-2 note confirmed; the dome reference is effectively missing from the corpus (specs already work around it via the campus/22 reflection) | WRONG CONTENT (re-cut or fix the index; this was the cluster's only dome shot) |

**Verdict:** the indexed corpus is healthy except for one dead file (nature/10)
and two filename↔content swaps (nature/05↔06, campus/02) that the pass-2 lane
declared but never reconciled on disk; the `_pass2-review/` staging area is in a
half-landed state (~72 unindexed/uncredited files, 1 corrupt, 2 HTML scrapes) and
its size is misdescribed in MODELING-SPECS.

---

## 4. Repo hygiene audit

**Git state (2026-11-08):** the entire survey tree is a single untracked entry
(`?? docs/references/ames-survey/`); nothing in the survey has ever been committed
(`git ls-files` count 0). Repo-wide `git status --porcelain` shows **exactly one
entry** — the survey tree — i.e. the lanes kept their promise:

- **Zero survey files exist outside `docs/references/ames-survey/`.** No modified
  or untracked files anywhere else in the repo. The only file on disk modified
  today outside the tree is `.zcode/workflow-drafts/Ames-master-plan-forge.dwf.ts`
  — ZCode tooling under the already-ignored `.zcode/`, not a survey deliverable.
  (`.captures/` and `.godot/` are likewise ignored.)

**Sizes (du -sh):**

| Part | Size | Regenerable? | Recommendation |
|---|---|---|---|
| `osm/raw/` | **105 MB** (42 tiles ~84 MB + `ames_merged.json` 21.8 MB + `_tilelist.txt`) | Tiles: yes (`fetch_tiles.sh` + `build_dataset.py`); merged: yes (refetch + merge) | **Leave tiles local** (gitignore). **Commit `ames_merged.json`** — every lane cites its way/relation IDs; 21.8 MB JSON is the cheapest way to keep the corpus re-runnable. (If repo weight rules, ignore it too and document the refetch recipe.) Commit `_tilelist.txt` |
| `osm/streets.csv` + `osm/scripts/` (7 scripts + 4 .ql) | 70 KB | — | Commit (provenance) |
| `images/` | **176 MB** — 83 indexed photos ≈ 127 MB (campus 43, stadium 25, campanile 20, downtown 13, laverne 8.6, nature 8.9, lincolnway 3.7, rail 3.7, campustown 0.8, misc 1.7) + `_pass2-review/` 49 MB | Photos: no (they are the evidence base); pass-2: partially | **Commit the 83 indexed photos + 10 CREDITS.md + IMAGE_INDEX.md.** Consider Git LFS for `images/*.jpg` (127 MB of JPGs in plain git is heavy but workable). **Leave `_pass2-review/` local** until pass-2 lands, then commit only the indexed/credited keepers |
| `census/` | 2.2 MB (`BUILD-CENSUS.md`, `authored-buildings.csv` 286 KB, scripts, `tagged_nodes.json` 1.7 MB, `_out_*.txt` 95 KB) | `tagged_nodes.json` yes (`ames_census.py cache`); `_out_*` no (machine outputs backing the doc) | Commit doc + CSV + script + `_out_*.txt`; **gitignore `tagged_nodes.json`** |
| `community/` | 3.3 MB (2 docs + `_fetch.py` + `_cache/` 90 files) | `_cache/` re-fetchable via `_fetch.py` (Arctic Shift) | Commit the docs + `_fetch.py`. `_cache/` is a judgement call — the verbatim quotes + thread IDs are already in the docs, so **leave local** to keep the repo lean; commit instead if the owner wants the raw evidence frozen |
| `landmarks/` `venues/` `verification/` | 36 K / 52 K / 64 K | — | Commit (docs + verification scripts) |

**Proposed `.gitignore` additions (exact):**

```gitignore
# Ames survey — regenerable bulk stays local (see docs/references/ames-survey/QA-REPORT.md §4)
docs/references/ames-survey/osm/raw/tile_r*.json
docs/references/ames-survey/census/scripts/tagged_nodes.json
docs/references/ames-survey/images/_pass2-review/
docs/references/ames-survey/community/_cache/
```

(If the owner prefers minimum weight over re-runnability, also ignore
`docs/references/ames-survey/osm/raw/ames_merged.json` and record the 2-command
refetch in the survey README.) Net commit weight with the split above:
≈ 152 MB (127 MB images + 21.8 MB merged JSON + ~3 MB docs/CSV/scripts).

---

## 5. Completeness scorecard

| Lane | Covers | Visibly lacks | Fill effort |
|---|---|---|---|
| **osm** (`osm/SUMMARY.md`, streets.csv, raw, scripts) | Survey bbox, 727-street inventory, block rhythm, campus geometry, water/rail/POI, the core-bbox proposal everything else builds on | Five §4/§5 items superseded by the census/ledger (Duff lon, W→E labels, 5th→6th, Campustown-polygon prose extent, lon drift) with no errata sheet | **small** |
| **landmarks** (`landmarks/LANDMARKS.md`) | 13 campus + 13 city landmark entries with sourced dims, history/culture, the top-15 air-recognition ranking the build order leans on | ~12 unapplied ledger/photo corrections (orientation block, colors, MU/Parks/Campanile relations, Fareway, bridge, swans) + stale UNVERIFIED tail; no pointer to the ledger | **small** |
| **venues** (`venues/VENUES.md`) | 48 open venues tiered with dated status evidence, 17 closed, the Welch fly-through, night-flow overlay — the strongest sourcing discipline in the survey | 8 unapplied ledger corrections (§1.1, §1.13, four Main-numbering items, Foundry/23-Twenty, Fareway); Szechuan distance; second Hy-Vee missing | **small** |
| **community** (`community/REDDIT-RESONANCE.md` + `community/TRADITIONS.md`) | 45-thread resonance ranking + verbatim gold; traditions split verified-vs-folklore with real source work; the §9 fidelity note and the zodiac/naming corrections | Zodiac error and Clouds floor error persist in the REDDIT doc unflagged; `_cache2` manifest phantom | **small** |
| **verification** (`verification/VERIFICATION.md`) | 30 settled verdicts, 10/10 venue spot-check, dispositions for every UNVERIFIED, an honest open list — genuinely the ground truth it claims to be | Its own V-23 endorses the half-right Conservatory number; Amtrak, Hilton distance, Hy-Vee count, Szechuan distance unexamined; ledger chain quietly mixes a north-side anchor | **small** |
| **census** (`census/BUILD-CENSUS.md` + authored-buildings.csv + scripts) | Machine-derived census of everything in the core box (3,737 buildings, districts, venues cross-check, streets/signals, green/water, rail, parameter sheet, full 512-authored CSV) | "(S Duff)" Hy-Ve mislabel; §2 prose "2 outside" vs §7 "3 out-of-core"; otherwise the tightest lane | **small** |
| **images** (`images/` + IMAGE_INDEX.md + 10 CREDITS.md) | 83 CC-licensed photos, fully credited, indexed with modeling notes and honest gap lists | Pass-2 half-landed: 2 content swaps unreconciled, 1 indexed corrupt file, ~72 unindexed/uncredited staging files (1 corrupt, 2 HTML scrapes), count misdescribed in specs | **medium** |
| **modeling-specs** (`MODELING-SPECS.md`) | The synthesis: 10 cluster specs with palettes/LODs/game-native hooks, fidelity list F-01–F-24, district rules, build order — the right document, correctly deferring to photos and the ledger | Inherits 5 errors not caught upstream (Hilton 300 m, Hy-Vee swap, Hughes=59×88, "third of authored footprint", depot-Amtrak) + stale pass-2 header note | **small** |

### Overall verdict

**YES — with the gaps listed above.** The survey is sufficient to write the master
plan: the geography (core bbox, block rhythm, address rules, settled dimensions),
the venue skeleton, the census constants and the fidelity list are consistent,
sourced, and mutually reconciled to an unusual degree; every disagreement that
matters has a settled verdict. The blocking items are narrow and mechanical —
two wrong numbers the authority chain itself endorses (B-03 Hughes Conservatory
scale, B-04 Hy-Vee store swap), the unapplied-correction banners in four sibling
docs, and the half-landed image pass-2. None of them touches the core bbox, the
block grid, or any settled dimension. Fix the top-10 list and compile the index.

---

## 6. Top 10 fixes before master plan

1. **Split "Hughes Conservatory" from the 59×88 m building** in `MODELING-SPECS.md` §1.9 (and note it in SUMMARY §9 / V-23): Hughes glasshouse = **465 m² (5,000 sq ft)**; the 59×88 m OSM way (≈3,181 m² GSF) is the whole Reiman Gardens Conservatory building. Otherwise the south-gate L3 set piece gets built ~11× oversized. *(blocks-build)*
2. **Fix the Hy-Vee story**: two stores — 3800 Lincoln Way (0.784 ha, west) and 640 Lincoln Way "Lincoln Center" (0.699 ha, near Grand); no Hy-Ve on S Duff. Correct census §1's "(S Duff)" label and MODELING-SPECS §1.6 item 4 + §3 rule 5. *(blocks-build)*
3. **Apply the LANDMARKS correction banner/edits** (A-01…A-12): orientation block, Lincoln Way E–W, downtown-2.93-km-east, Parks north of Campanile, MU at Morrill/Lynn, field N–S (drop the stale misquote + unverified tail), buff Campanile, pale-limestone MU, white Marston tank, swanless lake, Fareway addresses, Cy Walk open. *(misleads)*
4. **Apply the VENUES corrections** (A-14…A-22): Kum & Go same-side, The Cafe north Ames, the four Main-numbering flips + §5.2 label, Foundry/23-Twenty order, Fareway addresses. *(misleads)*
5. **Fix MODELING-SPECS §1.3 "Hilton 300 m northeast" → ~790 m center-to-center** (~640 m edge gap) per OSM. *(misleads)*
6. **Strike the depot-Amtrak claims** in IMAGE_INDEX rail notes and MODELING-SPECS §1.8 — Ames has no Amtrak service (nearest stop Osceola); depot = scenery per F-20, which is what SUMMARY §8 assumed. *(misleads)*
7. **Finish the image pass-2**: re-cut `nature/05`↔`06` and `campus/02` (or amend the index rows) so the index describes what is on disk; repair/replace corrupt indexed `nature/10-reiman-conservatory-wing-roof.jpg`; delete corrupt `_pass2-review/ft_44248909705_b2.jpg`; index + credit every `_pass2-review/` keeper cited by the specs; correct the "10 unindexed extras" count (~72 on disk). *(misleads / medium effort)*
8. **Patch SUMMARY §4/§5 stale numbers**: Duff lon −93.6104 (V-05), "west→east" labels (ledger §1), Main→5th 86 m / 5th→6th 105 m (census §2), Campustown polygon extent prose ~Hyland→Morrill (probe §2.6), 55,000-tag staleness note. *(misleads/cosmetic)*
9. **Small corrections sweep**: VENUES §3.9 Szechuan ~1.4 km (not 3.5); REDDIT zodiac location + Clouds floor notes (A-23/A-24); IMAGE_INDEX "MU sits on its south side" (B-06); census §2 "2 outside" → 3 (B-09); specs "a third of the authored footprint" → over half (B-07); Barks@Parks indoors (B-08); misc/CREDITS Fareway address (A-30); TRADITIONS `_cache2` manifest line (B-14). *(cosmetic)*
10. **Set the commit split + add the four `.gitignore` lines from §4** (tiles, tagged-node cache, `_pass2-review/`, `_cache/`), commit the eight lane docs + streets.csv + authored-buildings.csv + ames_merged.json + scripts + the 83 credited photos (LFS if preferred). *(hygiene)*

---

## File manifest

| File | What it is |
|---|---|
| `docs/references/ames-survey/QA-REPORT.md` | This report — the QA lane's deliverable. |
| `docs/references/ames-survey/_qa/probe_qa.py` | Read-only OSM probe used for §2 claims 3/4/5/6 + spot re-checks (Hy-Vee ways, Conservatory bbox, Hilton↔stadium distance, Szechuan distance, Campustown polygon extent, Duff lon). Run: `python -I probe_qa.py ../osm/raw/ames_merged.json ../census/scripts/tagged_nodes.json`. |

Inputs read, not modified: all eight lane deliverables, the 10 CREDITS.md files,
IMAGE_INDEX.md, `osm/raw/ames_merged.json`, `census/scripts/tagged_nodes.json`,
and 9 image files (2 decode-failure probes + 5 random spot-checks + 2 swap probes).

*QA/red-team lane, 2026-11-08.*

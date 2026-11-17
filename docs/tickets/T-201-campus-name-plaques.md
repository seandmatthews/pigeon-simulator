# T-201 — Ames R4 · campus name plaques: nominative names, no marks

- **Status:** done · **Category:** visual-design · **Ring:** R4 The Names ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-197
- **Refs:** master plan §0 (the legal line: names OK, registered marks
  excluded) · `landmarks/LANDMARKS.md` legal-tier notes · R3 hero
  tickets (the buildings these plaques name)

## What

Nominative building-name plaques on the campus heroes and civic
buildings: Campanile, Beardshear Hall, Morrill Hall, Farm House,
Memorial Union, Parks Library, Marston Water Tower, Jack Trice
Stadium, Hilton Coliseum, Ames City Hall, the depot (no railroad
brand marks — "Ames Depot"), Reiman Gardens (T-204 dependency note).

The legal discipline, pinned: **names in plain type only** — no
university wordmark, no Cy, no athletics marks, no logo shields; a
plaque reads "Beardshear Hall", full stop. Building dates may appear
(e.g. "1897") as historical fact.

## Why

Campus buildings are the town's address system for alums; names are
nominative fair use territory while marks are not — this ticket draws
that line in code and review, once, explicitly.

## Acceptance criteria

- [x] Plaques on the pinned building list; text = name (+ year) only;
      zero mark-like graphics (review-checked against the excluded
      list)
- [x] *(Gate 1b)* `campus_plaques_pins`: plaque list + text pins
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass; owner
eyeball in T-202.

## Run record (2026-11-16, implementer)

**Reviewer sign-off 2026-11-16** — ticket accepted against this branch on
the recorded evidence below: the AC ticked on the recorded runs (the
11-plaque table with the plain-type law machine-read; the
`campus_plaques_pins` Gate 1b row green in the 157 PASS / 0 FAIL suite;
Gate 1 clean; Gate 2 `ok=true … restart=true`; the 12-shot pilot ledger)
and the review-check against the excluded list accepted on the delivered
screenshot set (every face plain type, zero mark-like graphics). The
tuned values stand as recorded. Ticket flipped to done on that sign-off;
the owner eyeball pass (the names at flight distances) folds into T-202
per the Verification line.

- **The mount table** (`scripts/ames_campus_plaques.gd`, 12 entries, 11
  placed + Reiman staged): every mount derives from the LIVE hero part
  records (`AmesWorld`'s `*_hero_parts` arrays — the geometry the player
  flies past, not the superseded bake slots), probed 2026-11-16 with
  `tools/probe_campus_plaques.gd`; each entry pins face/plane/wall_u/
  mount_y/letter with the derivation cited per entry. The years are the
  survey's own (LANDMARKS C1..C10 + T3; the depot 1906 per MODELING-SPECS
  §1.8 — the RAILROAD BRAND stays off the text: "Ames Depot — 1906");
  City Hall carries the NAME ONLY because the survey pins no completion
  year (the ticket's "dates may appear" law leaves it off rather than
  inventing one). Reiman Gardens stages ready with the T-204 note (the
  pack marks it `in_core: false`, 1 km south of the bake core), the
  The-Cafe rule.
- **The mount facts worth knowing:** the campanile's entrance arch owns
  the WEST face (T-186's schedule), so its plaque takes the plinth's
  plain south face · Beardshear's between-column gaps are 1.9 m (under
  the 2.2 slab), so its plaque hangs ABOVE the entry door on the portico
  face — the carved-name position — clear of the columns and the door
  slab · Farm House's real porch owns its west face (porch posts + door
  trim crowd it), so the plaque takes the main block's south wall in the
  strip the south wing leaves open · MU's plaque rides the entry apron's
  OWN proud face (−43.56, 0.02 past the main block) — the clip law's
  round-1 correction, see below · Parks rides the east entry bay's
  outermost slab face · the Marston tower is a TRESTLE + tank with no
  wall, so its plaque is the real ISU-marker form (a base marker on a
  post east of the tower, facing Marston Court) · Jack Trice's plaque
  mounts on the OUTERMOST west face (the bowl band boxes reach 0.05 west
  of the press tower base) · Hilton hangs under the east portico's seal
  medallion · City Hall sits north of the T-192 cartouche on the Clark
  face · the depot's plaque hangs UNDER the platform canopy on the TRACK
  face (T-194's correction: the Clinton main is south), mid-span between
  the canopy posts, while Cornbred's live venue sign keeps the Main face
  (T-199) — the historical name takes the rails side.
- **The legal line, machine-read** (`campus_plaques_pins`): the
  excluded-mark scan over every text ("Iowa State" / "ISU" / "Cyclone" /
  "Cy" / "MidAmerican" / "C&NW" / "North Western" / "Union Pacific" /
  "Amtrak" — none may appear), the plain-typography law on the live
  nodes (exactly ONE body slab mesh + ONE unshaded type face per plaque —
  a logo shield cannot exist here — zero emission, the typology cream/
  ink, zero outline), the year-suffix law (name + at most one
  " — year", matching the survey's pinned year per building), the budget
  law (readable = letter × 140: 0.16–0.22 caps → 22.4–30.8 m), the
  face-fit law, and the mounts re-derived against the hero records: the
  wall-exists leg, the CLIP leg (no hero box penetrates the slab's own
  volume — the Beardshear column law), the span/top/ground legs, the
  marker's clear-of-the-tower leg + its gray post.
- **Gate 1** — `--import` exit 0 with only the documented benign addon
  line ("33 resources still in use at exit"); `--quit-after 120` exit 0,
  ZERO ERROR lines (the lone ObjectDB leak WARNING is the notice's
  acceptable class).
- **Gate 1b** — full suite `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn`: exit 0, **157 PASS / 0 FAIL** (the new
  `campus_plaques_pins` row green; every existing row untouched). Two
  intermediate failures recorded honestly, both during this ticket's own
  derivation: the clip leg's E/W half-extent swap was inverted (my own
  scenario bug — every wall mount false-failed), and the MU mount's
  plane sat at the main block instead of the apron's proud face — the
  clip law caught the 8 mm penetration the design note had missed. The
  gate works; the landed table is clean.
- **Gate 2** — `godot --path . res://tests/autoplay.tscn`: exit 0,
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
  t=103.0 fps=141 … splats=26 tourists=24 … eaten=7 … restart=true`,
  zero SCRIPT ERROR lines — the full Ames window closes its loop with
  the eleven plaques in the world.
- **Gate 3** — the screenshot set (pilot sessions, hidden windows per
  T-170): `.captures/session_t201plq/shots/` — `01_campanile_s.png`
  ("Campanile — 1897" on the plinth toward the MU approach),
  `02_beardshear_e.png` ("Beardshear Hall — 1906" above the portico
  entry), `03_morrill_w.png` ("Morrill Hall — 1891" facing the quad),
  `04_farmhouse_s.png` ("Farm House — 1860–61" beside the south wing),
  `05_mu_s.png` (the MU entry bay; re-shot angled past a street object
  in `../session_t201plq2/shots/05_mu_s.png`), `06_parks_e.png`
  ("Parks Library — 1925" on the Morrill Rd entry bay),
  `07_marston_marker.png` (the base marker under the trestle, "Marston
  Water Tower — 1897"), `08_jack_trice_w.png` ("Jack Trice Stadium —
  1975" on the University Blvd press-tower face), `09_hilton_e.png`
  ("Hilton Coliseum — 1971" under the east portico seal),
  `10_city_hall_e.png` (re-shot from the correct east stand in
  `../session_t201plq2/shots/10_city_hall_e.png` — "Ames City Hall"
  beside the Clark cartouche; the first take stood on the wrong side of
  the wall, recorded for honesty), `11_depot_s.png` ("Ames Depot —
  1906" under the track-face canopy), `12_lawn_context.png` (the lawn
  glide with the campanile plaque reading mid-frame). Every placed text
  reads letter-for-letter in its shot; every face is plain type — the
  review-check against the excluded list on the LOOK is the owner
  eyeball in T-202 per the Verification line.

## Tuned values (as landed)

`AmesCampusPlaques` (12 entries, 11 placed + Reiman staged; the T-090
cream slab `2.2 × 0.5 × 0.08` at the PLAQUE typology defaults, unlit,
budget 140): WALL_GAP 0.01 · campanile S −291.08 / u 340.17 / y 1.1 /
letter 0.22 · beardshear E 164.96 / u −378.61 / y 5.4 / letter 0.16 ·
morrill W 158.03 / u −494.61 / y 2.2 / letter 0.22 · farm_house S
−483.76 / u 504.9 / y 2.9 / letter 0.16 · mu S −43.56 (the apron's own
proud face) / u 313.02 / y 2.4 / letter 0.22 / band (2.8, 0.6, 0.1) ·
parks E 157.4 / u −593.85 / y 2.6 / letter 0.22 / band (2.8, 0.6, 0.1) ·
marston_tower marker at (−42.5, 1.6, −467.96) facing east / letter 0.16 /
band (2.4, 0.5, 0.08) · jack_trice W 1100.74 / u 997.23 / y 3.0 /
letter 0.20 / band (2.8, 0.6, 0.1) · hilton E 1340.97 / u 197.47 / y 3.0 /
letter 0.22 / band (2.8, 0.6, 0.1) · city_hall E 2720.58 / u −405.0 /
y 2.2 / letter 0.22 · depot S −175.04 / u 2647.89 / y 2.2 / letter 0.22 /
band (2.4, 0.5, 0.08). Readable distances: letter 0.16 → 22.4 m, 0.20 →
28.0 m, 0.22 → 30.8 m (the plaque budget's own law). Marker consts:
MARKER_Y 1.6, MARKER_POST_H 1.35, MARKER_POST_THICK 0.12, MARKER_POST_
COLOR Color(0.25, 0.25, 0.28). World wiring: the `CampusPlaques` root,
report key `campus_plaques` 11.

# T-188 — Ames R3 · campus row west: Beardshear's dome, Morrill, Farm House

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-177
- **Refs:** `MODELING-SPECS.md` §1 campus-buildings (F-03: Beardshear
  oxidized-copper GREEN dome — the only green dome in town) ·
  `images/campus/01,02→renamed-portico-winter,05,13,15` ·
  `landmarks/LANDMARKS.md` (Morrill red brick + corner turret cupola;
  Farm House = oldest building, red brick/white trim from text —
  archival B&W photo only)

## What

The west classical row at hero fidelity, as one ticket:

- **Beardshear Hall**: pale stone body, columned portico, the green
  dome (the dome is THE color note on the skyline — F-03).
- **Morrill Hall**: dark red brick, round-arched windows, the conical
  corner turret.
- **Farm House**: 2-story brick farmhouse massing (colors from
  LANDMARKS text — the only ref is archival B&W; flagged honestly).
- Marston Hall facade hint if cheap (the quad's east row partner).

## Why

The green dome is a top-10 air-read and the row anchors the lawn's
west edge; grouping the three small heroes keeps ticket ceremony down
while each stays slot-swapped and probe-pinned.

## Acceptance criteria

- [x] Three heroes swap their T-175 slots 1:1; Beardshear dome color
      pinned to the photo estimate band
- [x] *(Gate 1b)* `campus_row_heroes`: per-hero AABB dims/palette pins
      (re-pinning T-175 rows for these slots)
- [x] Screenshot set vs `images/campus/` refs (portico, Morrill
      winter, Farm House — honest note where the ref is B&W)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

## Round record (agent pass, 2026-11-15)

**How it landed.** The T-186 campanile hero law generalized from one
hero to four, all runtime builds in `scripts/ames_world.gd` (a new
`## T-188 the campus row west heroes` section; pure bake-derived
geometry, zero RNG of any stream — a rebuild reproduces every
transform), built inside their own chunk pass
(`_build_campus_row_heroes`, dispatched from `_build_chunk`):

- **Beardshear Hall** (`way/33725619`, a HERO placeholder slot): the
  slot envelope EXACT — body 41.1 × 14 × 66 at the bake block part's
  center, dome drum 9 × 4 × 9 at the slot's own +12 x (top 18), dome
  top 20.0 (the bake's settled stack) — dressed with the east portico
  (4 columns at the lawn frontage + architrave slab + entablature band
  + entrance steps plate→0.7), the heavy cornice ring (41.5 × 1.0 ×
  66.4 at 13.0–14.0), the copper base ring and the dome cap (a tapered
  CylinderMesh, 18→20, with its 8-segment frustum convex). The slot's
  block/dome/dome_cap placeholder parts render, collide and ground-file
  NOTHING anymore (the placeholder-family passes skip
  `_row_superseded_placeholder` ids: campanile + Beardshear); the
  dome-top crumb lands byte-identically where the bake's dome_cap-
  derived spot always sat (20.0 at (154.21, −378.61) + `SPOT_LIFT` —
  the row pins that continuity).
- **Morrill Hall** (`way/158023244`, an authored massing slot): walls
  27.7 × 9.6 × 40.3 (the census 3-level read; see Deviations), shaded
  attic frieze to 10.6, red-banded eave (28.3 × 0.5 × 40.9), the
  patterned slate hip as a loft ArrayMesh (eave 28.3 × 40.9 at 11.1 →
  ridge 2.0 × 28.0 at 15.0, single surface — a full hip), the banding
  dormer hint on the south slope, dark round-arched window reads +
  pale entry surround on the east (lawn) face, and the round corner
  TURRET at the lawn-facing corner: a full-height brick drum
  (CylinderMesh r 2.6 to 13.0, 8-segment convex), limestone band, and
  the conical slate roof (13.4→16.8, cone convex).
- **Farm House** (`way/158023219`, authored massing slot): the knoll
  (26 × 1.4 × 29, quad-lawn green), the 2-story gable block
  18.8 × 8 × 14 (the 2-level ladder) + the rear wing 13 × 5.5 × 7.5 —
  together spanning exactly the slot's 18.8 × 21.5 envelope — the
  gable roof as a two-surface loft (shingle slopes + BRICK vertical
  ends), two ridge chimneys (to 14.3), the white-trimmed west porch
  (deck + roof walkable, 4 posts), white-linteled windows and the
  attic gable window.
- **Marston Hall** (`way/183216666`, the ticket's "facade hint if
  cheap"): the slot envelope kept EXACT (31.4 × 12 × 64.2, the pack's
  tagged 12.0) with the pale classical east facade — cornice ring,
  central pavilion (+2.0 projection), four pilasters, the arched
  entry in its surround, entrance steps onto the marston_spoke walk.

The three massing-slot ids join `_hero_ids` at build time
(`CAMPUS_ROW_RUNTIME_HERO_IDS`), so every existing hero-massing skip
(render, occluder, collision, ground record, roof spots) applies to
their superseded bbox boxes unchanged; each hero hangs its own shapes
on its chunk's layer-1 `Placeholders` body, files its own true ground
tops (the two roofs' ridge tops via record-only entries — a big ground
box under a sloped loft mesh would poke through the slope), hosts its
own roof crumb at its true top, and retains its part record
(`campus_row_hero_parts`, the headless-visibility law; `mesh`-marked
extras so the gate can count the box schedule against the render MM).

**Palette bands** (MODELING-SPECS §1.4's campus-buildings rows,
re-derived verbatim by the gate): limestone #C8C1AE + shade #A29B8B;
the dome trio #5E8F68 mid / #8FB98F light / #4A7055 dark (F-03 — the
gate's green-dominance law: g > r and g > b for all three, no
brick/stone band is); Morrill brick #A8503A + shade #7C3A2B + slate
#3F444C + banding #8C4A3C; Farm House brick #9A4A34 + white trim
#EDEAE2; the knoll #5F7F42 (the quad-lawn row); the window band
darkness-lawed (luminance ≤ 0.25 — the survey pins no window hex; the
campanile `hand` precedent).

**Tuned values** (the section consts): Beardshear dome offset +12 /
top 20.0 (the slot's own); Morrill wall top 9.6 / attic 10.6 / ridge
15.0 / turret drum 13.0 / cone 16.8 (turret at the SE corner inset
1.2, r 2.6); Farm House knoll 1.4 / ridge 12.9 / chimneys 14.3;
Marston top 12.0.

**Deviations, honestly:**

- **Morrill + Farm House heights**: the bake slots stand 30.0 m tall
  — an OSM `height` default the census §3 records in the bogus class
  (the baker's own hero law: settled heights are literals, not the
  tags). The heroes take the census ladder instead (Morrill 3 levels ≈
  11 → 9.6 walls + hip to 15.0, cone 16.8; Farm House 2 levels ≈ 8
  above the 1.4 knoll) — the swap RETIRES the 30 m silhouettes and the
  row pins the ladder bars.
- **Morrill's turret corner** is unpinned by the survey ("round corner
  turret", photos only) — placed at the lawn-facing SE corner, inset
  1.2, r 2.6, where a pigeon circling the lawn sees it.
- **Farm House colors**: the only ref is the archival B&W
  (`campus/15`) — brick #9A4A34 + trim #EDEAE2 carry from LANDMARKS
  C9's text; the roof hue borrows §1.10's weathered-shingle row
  (#4E4E52, the nearest pinned survey family); the facade faces west
  (the campus read) and the turret-corner-style choices are documented,
  not sourced.
- **Beardshear's carved pediment** is OMITTED (the LOD row pins
  portico + dome + cornice; the tall entablature band carries the
  classical read) and the dome's lantern/finial is omitted so the
  settled slot total stays EXACTLY 20.0 (the T-186 finial precedent).
- **Beardshear's dome cap is a straight taper** (CylinderMesh), not a
  hemisphere — the box-path budget read; the convex is the 8-segment
  frustum under it.
- **`images/campus/05` (night floodlit)** is matched for silhouette
  only — the engine cannot do the night-floodlit grade; not shot.

**Gate ledger.** Gate 1: `--import` exit 0 (only the accepted
godot_mcp "resources still in use" line), boot `--quit-after 120`
exit 0 with ZERO ERROR lines. Gate 1b: full suite **143 PASS / 0
FAIL**, exit 0 (`--fixed-fps 60` headless; the landed tree) — the new
row green (`campus_row_heroes`) and every prior row green INCLUDING
T-175's bake-side rows (the bake itself is untouched) and
`ames_world_render_budget` with the re-derived expectation (−3
Beardshear placeholder parts, −3 authored massing slots, the hero MM
families outside the bake-derived metric — the T-186 law, walked from
the chunk files not hardcoded). Gate 2: autoplay exit 0, `AUTOPLAY
DONE ok=true world=ames crumb_target=40 loop_ok=true t=103.0 …
restart=true`. Gate 3: the screenshot set below; the owner's eyes-on
stays T-196's postcard flight per the ring plan.
ACCEPTED — reviewer sign-off on the landed tree 2026-11-15; the ticket
flips done on that sign-off (the T-185 convention).

**Red-check** (the pins bite): `BEARDSHEAR_DOME_TOP` 20.0 → 19.5
FAILed the row naming exactly four arms — "Beardshear top 19.500 !=
the slot's settled 20.0", the live dome-top ray ("dome top y 19.50 !=
the settled 20.0 (±0.1)"), the ground record ("answers 19.500") and
the roof-crumb continuity ("no beardshear roof crumb at (154.21,
20.06, −378.61)") — then reverted and the suite ran green again
(143 PASS / 0 FAIL). (First sabotage attempt moved only the crumb: the
dome stack's ground box and mesh were hardcoded at y 19.0 —
parameterized onto the constant first, then the sabotage re-run, so
the whole dome stack moves with the pin.)

## Screenshots (agent pass, 2026-11-15)

Session `t188row` (hidden window per T-170, hunger locked via the
T-167 dev verb, traffic frozen via the T-168 verb, chase-cam poses via
T-168 teleports; captures untracked in `.captures/session_t188row/`).
Side-by-side reads against the survey photos cited per row.

| Shot | Pose | Reads | Survey photo |
|---|---|---|---|
| `beardshear_portico.png` | 55 m E of the east face at ~30 m, facing west | the pale limestone facade + the 4-column portico + steps + the GREEN DOME over the roofline; Morrill's brick + round turret at right; Marston Tower beyond — the row anchors the lawn's west end | `images/campus/01`/`02` (portico columns + the dome read) |
| `beardshear_200m.png` | the T-175 ledger's lawn pose re-shot (200 m E at 70 m, facing west) | the dome closing the view across the quad, the crossing axes' paths leading to the portico | `images/campus/02` (dome-closes-the-view; the "renamed-portico-winter" file) |
| `beardshear_dome_150m.png` | 150 m E at 60 m, facing west | the dome stack at the slot's own +12 x offset, top pinned 20.0 | `images/campus/05` — silhouette matched; the NIGHT-FLOODLIT grade is not reproducible in-engine (honest note) |
| `morrill_70m.png` | 70 m S at ~24 m, facing north | red brick walls, the banded dormer hint on the south slope, the dark slate hip, the round corner turret with its conical roof + limestone band | `images/campus/13` (the winter read: brick mass + round turret + patterned hip) |
| `farmhouse.png` | ~57 m W at ground, facing east | the tiny farmhouse ON its knoll: white-trimmed porch, front gable + attic window, ridge chimney, the rear wing — completely out of scale with everything around it | `images/campus/15` — ARCHIVAL B&W ONLY: colors from LANDMARKS C9's text (red brick + white trim), roof hue borrowed from §1.10 (the ticket's honest flag) |
| `marston_hall.png` | 60 m E at ground, facing west | the pale facade hint: cornice, central pavilion + pilasters, arched entry + steps; the Marston Water Tower's legs above the roofline | `images/campus/16` (facade + tower-behind read) |

## Tuned values (as landed)

See the round record — every value is a named const in the
`## T-188 the campus row west heroes` section of `scripts/ames_world.gd`
and pinned by the `campus_row_heroes` row (AABBs with the dress
projections: Beardshear 47.5 × 66.4, Morrill 30.0 × 42.6, Farm House
26.3 × 29.0, Marston 37.8 × 64.6, all ±0.5; slot-envelope bodies ±0.01;
tops 20.0 / 16.8 / 14.3 / 12.0 ±0.05).

## Decisions & forks

- The bake is UNTOUCHED (no re-bake, no manifest edit): Beardshear's
  slot was already a bake hero; Morrill / Farm House / Marston Hall
  join the hero set at runtime. A future re-bake that wants the massing
  retirement physical can move the three ids into the bake's `heroes`
  list — the runtime merge is a no-op then.
- The 30 m bogus heights retire to the census ladder in the HEROES
  only; the bake's massing stays as committed (a data-ring fix, not a
  visual-design one — if the census re-pins Morrill/Farm House heights
  the heroes re-pin one const each).

# T-186 — Ames R3 · the campanile: the 33.5 m buff-tan brick spike

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-177 (placeholder slot)
- **Refs:** `MODELING-SPECS.md` §1 campanile cluster (silhouette,
  palette hex) · `landmarks/LANDMARKS.md` C1 (33.5 m, 50 bells, 1897;
  **buff/tan brick — photo-corrected, NOT red**) · `images/campanile/`
  (10 refs incl. dusk/20 storm shot) · `community/TRADITIONS.md` §1
  (campaniling — the rite this tower carries)

## What

The #1 emotional object in Ames, at hero fidelity:

- Buff/tan brick shaft with the three open-arcade head tiers (the
  50-bell carillon read), the tier-stack proportions from the photos
  (the city.gd anchor stack pattern at hero scale); slender 1:9-ish
  read from the lawn views.
- **Landable cap** — the midnight-kiss spot is a perch (the anchor-cap
  landing rule carries; crumb on cap per the T-032 pattern).
- **Chimes**: the quarter-hour Westminster Quarters as a soft audible
  layer is DELEGATED — an optional follow-up (audio design owner-gate),
  not this ticket.
- Swaps the T-175 slot; dims probe ±2 m; palette probe vs the photo
  hex estimates.

## Why

Fidelity item F-01 — the most recognizable silhouette in town, and the
survey's most load-bearing color correction (the dossier had it red;
the photos said buff/tan).

## Acceptance criteria

- [x] Hero swaps the placeholder 1:1 (same id, slot, collision class);
      cap landable; dims within ±2 m of 33.5 m total —
      `campanile_hero_dims` arms A–D (schedule at the bake slot center,
      live layer-1 rays, open-arcade miss/hit pairs, the gray-family
      accounting, the pinned crumb); T-175's `ames_placeholder_dims` +
      `ames_placeholder_landable` rows pass UNCHANGED on the hero's own
      colliders (the cap drop lands on the hero deck)
- [x] *(Gate 1b)* `campanile_hero_dims` (re-pins T-175's row) +
      `campanile_palette` (buff/tan band vs pinned hex estimates) —
      full suite 141 PASS / 0 FAIL on the landed tree
      (2026-11-14, `--fixed-fps 60` headless)
- [x] Screenshot set: lawn portrait, worm's-eye, dusk vs
      `images/campanile/` refs — session `t186keep`, ledger below
- [x] *(Gate 1/2)* clean — `--import` exit 0 (only the accepted
      godot_mcp "resources still in use" line), `--quit-after 120` boot
      exit 0 with zero ERROR lines, autoplay `AUTOPLAY DONE ok=true
      world=ames ... restart=true` exit 0

## Verification (proposed)

Gate 1 · Gate 1b + two rows · Gate 2 · Gate 3: screenshots in-ticket;
owner sees it in T-196's postcard flight.

## Decisions & forks

Carillon audio = separate optional ticket, owner-gated (sound design
is owner territory per the mute-by-default norm).

## Round record (agent pass, 2026-11-14)

**How it landed.** A runtime hero family in `scripts/ames_world.gd`
(`_build_campanile_hero`, the corner-dress discipline: pure
pack-derived geometry, zero RNG, a rebuild reproduces every transform),
built inside its own chunk pass. The swap keys on the bake id
`way/183041212`: the four T-175 placeholder parts render, collide and
ground-file NOTHING anymore; the hero files its own true tops. Its
collider shapes ride the chunk's OWN layer-1 `Placeholders` StaticBody —
same slot, same collision class, the T-175 probes pass on them
unchanged. The part record (`campanile_hero_parts`) is retained for the
gates (headless runs cannot read MultiMesh instances back — the T-185
law).

**The stack** (the T-175 anchor spans kept EXACTLY — plinth 0→2.0,
shaft →26.4, head →30.9, cap →33.5):

- Plinth 6.8 × 6.7 × 2.0 buff brick on a limestone base course, the
  west-arch entrance (dark opening + limestone lintel + flanking
  buttresses — the lawn side).
- Shaft 4.9 × 24.4 × 4.9 sunlit buff #C9A56A, slim lancet slots
  #6E5533 stacked down it (upper pair + mid single per face), the
  clock stringcourse under the belfry.
- THREE open-arcade tiers (the ticket's 50-bell carillon read):
  26.4→28.4 two tall lancets per face (piers + mullions + walkable
  crown), 28.4→29.5 the receding shaded stage, 29.5→30.9 the crown
  colonnade — REAL through-openings: only piers/mullions/crowns
  collide, each stage's floor is the tier below's crown, so a pigeon
  can fly into a lancet and perch inside (MODELING-SPECS GAME-NATIVE
  "the belfry arches are perch-throughs").
- Four white clock dials (CylinderMesh, #F1EEE7) + black hand bars at
  ~2/3 height (y 21.5).
- Corona table + crocketed corner pinnacles (buff, slate tips) + the
  dark slate #3F444D truncated-pyramid cap ending in the LANDABLE deck
  at exactly 33.5 m.

**Palette bands** (MODELING-SPECS §1.1 hexes, pinned by
`campanile_palette` at ±0.02/channel): brick #C9A56A, brick_shade
#8A6D3F (the receding upper stages), slot #6E5533, slate #3F444D,
clock #F1EEE7, trim #C6C0B2, hand (black-numerals, luminance ≤ 0.25).

**Tuned values** (the `CAMPANILE_*` consts): tier tops 28.4 / 29.5 /
30.9, corona 31.12, deck 33.3→33.5 (the pad), dial y 21.5, deck
2.5 × 0.2 × 2.45, frustum base ±2.5/±2.45 → deck rim ±1.2 over 2.18 m,
pinnacles 31.12→32.9 + tips →33.25 (everything stays at or below the
33.5 pad — the tower total is the pad, per the settled figure).

**Deviations, honestly:** the real apex finial is OMITTED (the settled
33.5 total IS the landable deck top — a finial above it would break
the pad; a ≤0.4 m detail at this scale); the lancet openings are
tall rectangles, not pointed Gothic arcs (L3 low-poly boxes — the
ticket's "open-arcade read" rides the proportions and the dark depth);
the worm's-eye arm of the screenshot set is the AT-THE-BASE loom (the
pigeon standing on the plinth top, the shaft filling the frame) — the
chase rig cannot hold a straight-up gaze; the dusk arm is the engine's
own low-sun grade (sun driven to (−9°, −110°) through the T-169 call
verb) — the engine sky carries no storm clouds, so `images/campanile/20`
is matched for silhouette and light, not for the sky's storm grade.

**Gate ledger.** Gate 1: `--import` exit 0 (only the accepted
godot_mcp "resources still in use" line), boot `--quit-after 120`
exit 0, zero ERROR lines. Gate 1b: full suite, 141 PASS / 0 FAIL —
the two new rows green (`campanile_hero_dims`, `campanile_palette`)
and every prior row green INCLUDING T-175's `ames_placeholder_dims` +
`ames_placeholder_landable` on the hero's colliders; the
`ames_world_render_budget` expectation re-derived in-row (−4 retired
slot parts, the hero a corner dress outside the bake-derived metric).
Gate 2: autoplay exit 0, `AUTOPLAY DONE ok=true world=ames crumb_target=40
loop_ok=true t=103.0 ... restart=true`. Gate 3: the screenshots below;
the owner's eyes-on stays T-196's postcard flight per the ring plan.
ACCEPTED — reviewer sign-off on the landed tree 2026-11-14; the ticket
flips done on that sign-off (the T-185 convention).

## Screenshots (agent pass, 2026-11-14)

Session `t186keep` (hidden window per T-170, hunger locked via the
T-167 dev verb, traffic frozen via the T-168 verb, dusk via the T-169
call verb on `/root/Main/Sun`). Chase-cam poses; side-by-side reads
against the survey photos cited per row.

| Shot | Pose | Reads | Survey photo |
|---|---|---|---|
| `portrait_200m.png` | 200 m S of the tower at 80 m, facing north (the T-175 ledger's pose, re-shot on the hero) | the slender buff spike free of the lawn, dark cap — the lawn is the shape, the tower the punctuation; the shaft reads BUFF, not the placeholder gray and not red | `images/campanile/01` (silhouette matches: slender needle + dark hat) |
| `portrait_150m.png` | 150 m S at 55 m, facing north | the full stack: buff shaft, the belfry stage's lighter arcade under the dark cap, plinth at the base, the white dial faint on the face | `images/campanile/09` (lawn portrait proportion read; tier-stack vs photo) |
| `wormseye_plinth.png` | at the base: the pigeon ON the plinth top at the south face, the shaft looming | the battered limestone-trimmed base, the sheer buff shaft overhead — the pigeon's-eye loom; the chase rig cannot hold a straight-up gaze, so the belfry's up-look stays the owner's T-196 flight | `images/campanile/05` (spirit: the tower from the pigeon's eyes; the UP angle partially matched) |
| `dusk_150m.png` | the 150 m pose with the sun driven low WSW (−9°, −110°) via the T-169 call verb | the dusk silhouette: cooler sky, long shadows, the dark cap reading against the dimming sky — the engine carries no storm clouds, so 20's storm grade is not reproducible in-engine | `images/campanile/20` (silhouette + light direction matched; the storm sky is the ref's own) |

Captures live in `.captures/session_t186keep/` (untracked, per the
T-175/T-185 ledger convention).

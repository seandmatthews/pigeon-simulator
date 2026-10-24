# T-136 — District theming: four dressed quadrants, one signature silhouette each

- **Milestone:** City identity (owner direction 2026-10-23) · **Status:** proposed
  (forge pending — this file is the forge INPUT; per-theme dressing details,
  invented names and reference-grounded values land via the forge) ·
  **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-135 (one park per district) — the themed parks need a
  guaranteed park in every quadrant to dress
- **Refs:** `DISTRICT_PALETTES` `scripts/city.gd` (four quadrant palettes —
  today the ONLY per-district signal besides T-091's anchor-head tint) ·
  `district_of` `scripts/city.gd:583` · the T-091 anchor builder
  (`_build_district_anchor`, four-tier clock post per quadrant) · DESIGN.md
  "Setting — a real US city (Ames … lightly fictionalized)" — campus /
  main-street / tailgate-lot are already promised there · the forge workflow
  (real-world research + reference images in `docs/references/<slug>/`,
  reviewer checks claims against the images) · the owner photo rule:
  reference photos ONLY for clear real-world counterparts.

## What

Each of the four quadrants stops being a palette swap and reads as a PLACE —
through dressing with the existing recipes plus one signature silhouette per
district. All presentation; zero mechanics, zero economy, zero new verbs.

1. **The four themes** (quadrant mapping is a proposal — owner confirms at
   forge sign-off):

   | District (`district_of`) | Palette today | Theme | Signature silhouette |
   | ------------------------ | ------------- | ----- | -------------------- |
   | 0 NW warm brick | warm brick | **Main street** — downtown row: shopfronts, awnings, signboards, the marquee | Movie-marquee cap on the district's anchor post |
   | 1 NE sandy cream | sandy cream | **Tailgate lot** — pregame party edge: open lots, grills/cooler props, banner colors | Water tower (legs + tank) restyle of the anchor post |
   | 2 SW cool blue-gray | cool blue-gray | **Campus** — the college side: quads, dense trees, collegiate brick | Campanile / bell-tower restyle of the anchor post |
   | 3 SE sage green | sage green | **Residential** — quiet neighborhood edge: smaller-scale reads, porch-ish rhythm, greenery | Grain silo restyle of the anchor post |

2. **Dressing levers — existing recipes only, zero new tech** (all keyed on
   `district_of`, all zero-RNG or stream-stable): per-district slab/ground
   tint trims on top of the base palettes; awning/signboard tint bias per
   district; prop-mix weights (more bins on tailgate edges, more
   benches/trees on campus and residential); tree density per themed park.
   The forge grounds the per-lever values in the reference photos.
3. **Signature silhouettes — FORK D-A (recommended): restyle the four T-091
   anchor posts.** The posts already give each quadrant a steer-by
   silhouette at a pinned block with landable caps, crumbs and re-derived
   pins; re-skinning each per its theme (marquee cap / water tower / 
   campanile / silo) buys identity with NO new placement math and NO new
   pin breaks beyond the anchor scenario's own constants. **FORK D-B:
   separate new structures** — full-size landmark props distinct from the
   posts — buys bigger silhouettes at the cost of new placement/clearance
   math and a second pin storm. Recommend D-A; owner picks at sign-off.
4. **Themed parks (rides on T-135):** campus quad (dense trees), tailgate
   green (open, party-edge dressing at the lot side), residential pocket
   park, main-street square (formal). Same mechanics — elders, crumbs,
   benches — just dressed; T-135's guarantee is what makes per-theme park
   dressing legible.
5. **Tone rules:** invented Ames-flavored names only; no real schools,
   logos, mascots or trademarks anywhere — colors and behavior carry the
   joke (the M2 rule). NO per-district sub-goals, score bonuses or quest
   machinery — B-4e's "per-district sub-goals" stays out per the scope
   guardrail; this ticket is identity, not objectives.

**Forge deliverables (next step, before any implementation):**

- `docs/references/district-theming/` — per-theme photo sets with clear
  real-world counterparts: campus quad, downtown main street with marquee,
  tailgate lot, residential street; plus the four signature counterparts
  (marquee, water tower, campanile, grain silo).
- Per-theme dressing-value proposals grounded in the photos (tints, prop
  mixes, tree densities) with the claims the reviewer checks.
- Invented district/place names (2–4 candidates each) for the owner to pick.

**Open forks for the owner:** the quadrant↔theme table above; D-A vs D-B;
names. Nothing else.

Not claimed: new score/favor surfaces, per-district NPC behavior or spawn
rules, interiors, zone boundaries/fences on the ground, signage TEXT (names
render only if the forge proves legible props), traffic changes (T-134 owns
streets).

## Why

The owner picked the direction 2026-10-23: "give each district more of a
theme." Today the quadrants differ by a tint (`DISTRICT_PALETTES`) and the
anchor head's color — invisible at cruise, and the map reads as one
uniform city with four unrelated green patches (pre-T-135). DESIGN already
promises campus / main-street / tailgate flavor (the Ames setting); the
owner added residential as the fourth. Dressing + one signature per
quadratic is the depth that reads from the air — the T-091 posts proved
silhouettes steer by; the forge-with-photos route applies because every
theme and signature has a clear real-world counterpart (the owner photo
rule), unlike fictional HUD affordances.

## Acceptance criteria

*Forge legs (checked before implementation):*

- [ ] `docs/references/district-theming/` holds the per-theme photo sets;
      the reviewer has checked the ticket's claims against the images and
      signed off; the owner has picked the quadrant↔theme mapping, D-A/D-B,
      and the names.
- [ ] The dressing-value table (per-district tints, prop weights, tree
      densities, signature dimensions) is recorded in this ticket,
      photo-grounded, before implementation starts.

*Implementation legs (finalized post-forge; pipeline route — city.gd pin
surfaces are the risk surface):*

- [ ] Each district reads as its theme from cruise height AND at block
      level: palette/dressing shifts present, one signature silhouette per
      quadrant (screenshot legs for all four).
- [ ] Zero RNG-stream discipline: dressing keyed on `district_of` adds no
      draws; any structural change re-derives the cross-version fingerprint
      pins with the headless probe (T-051/T-091/T-135 precedent) in the same
      change-set.
- [ ] (Gate 1b) new scenario pins the per-district dressing (tint/prop
      assertions recomputed independently) and the signature structures at
      their pinned blocks; existing city scenarios green with re-derived
      pins where the constants moved.
- [ ] Mechanics untouched: elders/favor/hunger/scoring/traffic re-derive
      nothing; T-135's four parks keep their recipe (dressed only).
- [ ] Tone check passes: invented names only, no real-world marks, no
      sub-goals or objectives anywhere in the diff.
- [ ] [screenshot] The four quadrants are distinguishable from cruise
      height by silhouette and dressing alone; the T-088 backdrop ring stays
      background; the map still reads balanced (T-135's line re-checked).

## Verification

Forge legs first (no implementation commit before sign-off). Then Gate 1 +
Gate 1b full suite with the new scenario added to `VERIFICATION.md`, the
explicit re-run list copied forward from T-135's record plus every scenario
the dressing touches (slab colors, awnings/signboards, prop counts), Gate 2,
and Gate 3 lines per district — "(T-136) District N reads as its theme from
cruise height and at street level [screenshot]".

## Implementation record

*(pending — forge fires on the owner's go; implementation routes through the
pipeline after the forge lands the photo-grounded values)*

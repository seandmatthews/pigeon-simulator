# T-174 — Ames R1 · skeleton visuals: streets, water, rail, parks readable from the air

- **Status:** proposed · **Category:** visual-design · **Ring:** R1 The Map ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-173 (renders the bake this dresses)
- **Refs:** `MODELING-SPECS.md` §3 (district dressing v0), §1 clusters
  (lake-laverne, rail-corridor, water-green) · `osm/SUMMARY.md` (street
  classes, widths) · `landmarks/LANDMARKS.md` (materials) · photos:
  `images/lincolnway/`, `images/downtown/01` (street read) ·
  T-026 (the ground-palette retune this inherits), T-148 (skyline haze)

## What

Make the baked skeleton READ as Ames instead of as geometry:

1. **Street dressing**: lane-mark hints on arterials only (Lincoln Way,
   Main, Duff, Grand) — center dashed line, no crosswalk paint yet
   (that is T-180); residential streets stay plain asphalt; the
   125–140 m block rhythm does the rest.
2. **Ground palettes per district** (dressing v0): downtown brick-warm
   sidewalks, Campustown scruffy gray, campus lawn green (the
   20-ac Central Campus slab from the park polygons), Lincoln Way
   commercial strip asphalt, residential seed — palettes picked from
   MODELING-SPECS §3 hex estimates, tuned by screenshot.
3. **Water v1**: LaVerne flat with a shoreline band (the 236×122 m
   oval reads as a lake, not a blue hole); College/Ioway creeks as
   green-blue ribbons; no shader fancy — the town's water is small.
4. **Rail corridor**: ballast gray strip + tie hint, the 9 road
   crossing gaps left honest (no signals yet — T-180/T-194).

## Why

The cutover's Gate 3 bar is "fly Lincoln Way end to end and recognize
Ames" — recognition at cruise altitude is carried by the skeleton's
color and width discipline, not by heroes (which R3 adds later).

## Acceptance criteria

- [ ] From 60 m cruise: Lincoln Way reads as a 4-lane arterial, Main as
      a historic 2-lane grid, Campustown as a dense low strip
- [ ] District palettes distinct in screenshots; haze (T-148) still
      carries the horizon
- [ ] LaVerne reads as a lake with a shore at 200 m
- [ ] *(Gate 1b)* `ames_skeleton_palette`: pinned per-district ground
      colors (the vertex-color discipline) — existing palette scenarios
      scoped to `windrow` stay green
- [ ] Pilot screenshot set recorded in-ticket (Lincoln Way, Main,
      LaVerne, rail corridor) vs survey photos
- [ ] *(Gate 1/2)* clean; `windrow` untouched

## Verification (proposed)

Gate 1 · Gate 1b + one new row · Gate 2 · Gate 3: agent visual pass;
screenshots attached to the ticket.

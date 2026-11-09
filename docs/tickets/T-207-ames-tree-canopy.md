# T-207 — Ames R5 · tree canopy: the 5,637 mapped trees become a skyline of leaves

- **Status:** proposed · **Category:** visual-design · **Ring:** R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-172 (the bake carries them)
- **Refs:** census §5 (5,637 natural=tree points; 267 ha green) ·
  `images/nature/20` (the mature-canopy read), `images/campus/20`
  (oaks on the snow lawn) · T-148 (haze — the canopy is the fog's
  dance partner)

## What

The town's cover, as the bake's cheapest big win:

- 2–3 tree archetypes (canopy blob + trunk hint; billboard-free —
  low-poly meshes in the house style), distributed at the mapped
  points via per-chunk MultiMesh (one draw per chunk, same as
  massing).
- Campus lawn oaks, residential canopy, park fills, the LaVerne
  shore ring — the mapped data decides where; the archetypes decide
  what.
- Wind sway = optional vertex-shader hint (cheap, no bones); no
  collision (canopy is soft — the pigeon brushes through, the
  existing foliage convention).

## Why

A treeless Ames reads as a render test. The canopy is also the flight
experience's texture at rooftop altitude — where this game actually
lives.

## Acceptance criteria

- [ ] 5,637 trees at mapped positions (±0 m — the data is the point);
      archetype mix pinned; per-chunk MultiMesh discipline (draw
      budget holds — T-173's gate re-run)
- [ ] *(Gate 1b)* `ames_tree_canopy`: count, archetype mix, chunk draw
      budget re-pin
- [ ] Screenshot set: campus lawn, residential street, LaVerne shore
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass.

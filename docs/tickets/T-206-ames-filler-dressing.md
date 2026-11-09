# T-206 — Ames R5 · filler dressing: anonymous buildings start being Ames

- **Status:** proposed · **Category:** visual-design · **Ring:** R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-177 (filler is live), independent of R3/R4 timing
  (can move earlier if the owner steers)
- **Refs:** `MODELING-SPECS.md` §3 (the 10 district dressing rules —
  this ticket implements them) · `images/nature/20,21` (the house
  portraits: clapboard + porch rhythm) · `images/campustown/03` (the
  scruffy 2-4 story fabric) · census §1 (levels histogram 1:187,
  2:158, 3:154… the height mix)

## What

The 3,175 procedural buildings stop being gray boxes:

- Per-district variation from the specs' rules: roof pitch variants
  (gabled residential, flat commercial), setback discipline from the
  census, porch hints on residential (the two house portraits'
  read), materials by district (brick-warm downtown, scruff
  Campustown, siding residential, lawn-edge campus).
- The variation is BAKED (T-172's arrays gain a small variant set —
  still MultiMesh, still vertex color, still one draw per chunk);
  the determinism manifest discipline holds.
- No collision changes (footprints identical).

## Why

85 % of the buildings carry 43 % of the visual field; the filler is
the difference between "a map of Ames" and "Ames."

## Acceptance criteria

- [ ] District-variant set live in the bake; roof/setback/porch rules
      per the specs; collision untouched
- [ ] *(Gate 1b)* `ames_filler_variants`: variant distribution pins
      per district; bake determinism re-manifested
- [ ] Screenshot set: the same Campustown + residential vantage
      before/after (in-ticket)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass (owner
eyeball folded into T-210).

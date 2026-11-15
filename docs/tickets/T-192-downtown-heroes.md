# T-192 — Ames R3 · downtown: the bandshell, City Hall, Main Street fabric

- **Status:** doing · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-177
- **Refs:** `MODELING-SPECS.md` §1 downtown-main-street ·
  `images/downtown/` (8 refs: bandshell ×2, City Hall, streetscapes,
  neon blade) · `landmarks/LANDMARKS.md` (1934 bandshell, refurb 2005;
  Main Street numbering increases WESTWARD — the QA-corrected rule
  any door-number logic must use)

## What

Downtown's identity set:

- **Durham Bandshell**: the copper arch over pale mint shells at
  Bandshell Park (NOTE: the park sits ~30 m OUTSIDE the v1 core bbox —
  model it at its true position; it reads from Main Street regardless;
  T-203 extends the bbox east and makes the inclusion official).
- **City Hall / Municipal building**: the civic brick block with the
  stone cartouche entry (photo 02).
- **Main Street fabric upgrade**: the retail row gets cornice hints +
  the maroon street-furniture palette (lamp posts, banner arms — the
  photos' dark maroon + blue AMES banner read at hint level; text is
  R4).
- Whiskey River-style neon blade sign geometry (no text yet) as the
  bar-sign typology seed for R4.

## Why

The bandshell is a top-13 air-read and Main Street is the historic
counter-weight to Campustown's scruff — the two districts must feel
different at eye level.

## Acceptance criteria

- [ ] Bandshell + City Hall swap slots 1:1 at true positions; Main
      fabric upgrade on the pinned row
- [ ] *(Gate 1b)* `downtown_heroes`: bandshell dims/palette (copper
      arch, mint shells), City Hall block pins
- [ ] Screenshot set vs `images/downtown/` refs
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

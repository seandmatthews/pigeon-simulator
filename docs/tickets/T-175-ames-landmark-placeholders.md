# T-175 — Ames R1 · landmark placeholders: true-dim massing so silhouettes read

- **Status:** proposed · **Category:** visual-design · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** T-173 (mount points), T-171 (positions/dims)
- **Refs:** `verification/VERIFICATION.md` top-15-from-the-air ranking ·
  `MODELING-SPECS.md` §1 (per-cluster silhouettes/dims) ·
  `census/BUILD-CENSUS.md` §3 (footprints; campanile way h=34) ·
  `scripts/city.gd` anchor tier stack (the mount/cap landing pattern)

## What

Every authored position gets massing; the top-15 get REAL silhouettes:

1. **All ~540 authored positions** (512 named + venue fixups): bbox
   massing from the bake, but with collision shapes and a stable id —
   these are the slots heroes replace (R3) and the roof-crumb hosts
   (T-176).
2. **Hero placeholders at true dims** (gray, correct shape — the
   from-the-air read is the point): campanile slender shaft+head+cap at
   **33.5 m** (the anchor tier-stack pattern, scaled; cap landable per
   the anchor-cap rule); Marston **51.2 m** cylinder on lattice legs;
   Jack Trice bowl ellipse **183×208 m**, field N–S, north hillside
   wedge; Hilton drum **138×105 m**; Beardshear block + dome hint; MU
   corner + squat tower; Parks massing + addition; bandshell arc; the
   two city water-tank bulbs; depot; elevator cluster at 30–40 m.
3. **Collision**: every placeholder is solid at flight speeds (chunk
   static bodies); the landable campanile cap keeps the crumb rule
   (`ANCHOR_CRUMB_LIFT` pattern).

## Why

The owner's recognition bar is airborne. True-dim silhouettes at true
positions make the layout read as Ames the moment R1 cuts over — months
before any hero art exists — and give R3 exact slots to fill.

## Acceptance criteria

- [ ] All authored positions occupied with collision-bearing massing;
      ids stable across rebakes (T-172 manifest)
- [ ] *(Gate 1b)* `ames_placeholder_dims`: top-15 placeholder AABBs
      within ±2 m of survey dims (33.5 / 51.2 / 183×208 / 138×105 /
      236×122-water adjacency…)
- [ ] *(Gate 1b)* `ames_placeholder_landable`: campanile cap accepts
      the landing state (the anchor scenario pattern, re-targeted)
- [ ] Pigeon collides at cruise with the bowl rim and campanile shaft
      (pilot probe)
- [ ] Screenshot set: the top-15 from 200 m, side-by-side with survey
      photos, recorded in-ticket
- [ ] *(Gate 1/2)* clean; `windrow` untouched

## Verification (proposed)

Gate 1 · Gate 1b + two new rows · Gate 2 · Gate 3: agent visual pass
(the silhouettes are the deliverable this ring — owner bar stays with
T-177).

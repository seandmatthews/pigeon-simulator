# T-203 — Ames R5 · bbox east: Bandshell Park and the S Duff corridor come inside

- **Status:** proposed · **Ring:** R5 The Town ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-202 (R4 cut over; extension machinery stable)
- **Refs:** `census/BUILD-CENSUS.md` (Bandshell Park ~30 m outside the
  east edge — the census miss) · `osm/SUMMARY.md` (core bbox; optional
  extensions) · master plan §8 · T-171 (the distill pipeline this
  re-runs — data pack v2)

## What

The smallest map growth, fixing the census's one embarrassing miss:

- Extend the core bbox ~200–300 m east; re-run the distill (data pack
  v2 with a version bump), re-bake; Bandshell Park + its block land
  inside the playable core (the T-192 bandshell already sits at its
  true position — this makes the GROUND around it playable).
- The S Duff commercial corridor gets its context blocks (Hickory
  Park's surroundings stop being void).
- Suite bbox pins updated (the honest, mechanical re-pin; no hero
  work).

## Why

A landmark you can see but not perch at is a tease; this closes the
gap the census itself flagged.

## Acceptance criteria

- [ ] Data pack v2 (version-bumped); Bandshell Park block playable
      (ground, collision, bread reach per the T-176 gate band)
- [ ] *(Gate 1b)* `ames_bbox_east`: new bbox consts; Bandshell inside;
      census counts re-pinned (+delta recorded)
- [ ] Re-bake determinism holds (T-172's manifest discipline)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: agent screenshot pass.

# T-013 — Juice pass v1

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** todo
- **Depends on:** T-006, T-009 (polish can start once those land)
- **Refs:** `docs/DESIGN.md` → Pillars 2 & 3

## What

Make hits and moments pop:

- GPUParticles: splat burst on hit, feather poofs on hard flaps, dust puff on landing
- Tiny camera shake on landing and on your own splat hits (small — this is a cozy game)
- Lighting pass: warmer sun, per-district building color palette
- HUD score pulse on combo escalation

## Why

The difference between "systems work" and "game feels alive". Pure multiplier on
everything else.

## Acceptance criteria

- [ ] Side-by-side with before, the game is noticeably more alive
- [ ] Still 60 fps with all particles active at max density
- [ ] No particle/popup spam overwhelming the screen; shake never nauseates
- [ ] District palettes are distinct without clashing with the locked art style

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: chained combo with all effects firing; confirm
frame rate holds and nothing obscures targets.

# T-007 — Tourists v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** todo
- **Depends on:** T-004, T-006
- **Refs:** `docs/DESIGN.md` → Tourists & cars

## What

The high-value targets:

- Low-poly pedestrian NPCs walking sidewalk paths in loose groups
- Reactions: **splatted** → panic (run away, yell, shake fist); **buzzed** (close
  high-speed near-miss) → flinch
- Simple waypoint/curve walking, capsule physics, layer 3 `npc`
- Respawn/recycle to keep 15–20 tourists alive around the player

## Why

Tourists are the skill target: small, moving, worth the most points. Their panic is
also most of the city's "reacts to you" charm.

## Acceptance criteria

- [ ] 15–20 tourists walking believably around the spawn plaza and main streets
- [ ] A splat produces panic (animation + movement change) and the score event
- [ ] A close high-speed flyby produces a flinch without full panic
- [ ] No frame drops at full density; tourists recycle without popping in view

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: splat at least 3 tourists and buzz 3 more; watch
one full panic cycle from takeoff to respawn.

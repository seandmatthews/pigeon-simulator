# T-011 — Pigeon presentation v1

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** todo
- **Depends on:** T-001, T-003
- **Refs:** `docs/DESIGN.md` → Art style (locked: low-poly, bright & cartoonish)

## What

Retire the gray sphere:

- Low-poly pigeon mesh — CC0 source (Kenney/Quaternius, log in `assets/CREDITS.md`)
  or hand-built from primitives; gray body, darker wingtips, green neck sheen
- Animation/pose states: flap, glide (wings out), dive (wings back), waddle, peck
- Attached to Player and driven from the flight state machine

## Why

You spend the whole game looking at this bird. It must read as a pigeon and as a
character, not a physics capsule.

## Acceptance criteria

- [ ] Readable silhouette at ~20 m against both roofs and road
- [ ] Poses/animations match actual physics state with no desync
- [ ] Waddle on the ground is at least a little bit funny
- [ ] `assets/CREDITS.md` updated if the mesh is third-party

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: fly, glide, dive, land, waddle, peck — confirm a
pose exists for each and nothing clips the camera.

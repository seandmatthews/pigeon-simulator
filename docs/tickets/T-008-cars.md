# T-008 — Cars v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** todo
- **Depends on:** T-004, T-006
- **Refs:** `docs/DESIGN.md` → Tourists & cars · Pillar 3

## What

The easy-money targets:

- Parked cars along curbs (static, easy) and looping traffic on roads
- Traffic: simple lane-follow, stop-if-blocked; nothing fancier in M1
- Hit by poop → honk + score event (30 pts base per DESIGN)
- Layer 4 `vehicle`

## Why

Per pillar 3, cars are the deliberately easy, low-value target — the game's "free
points" valve and contrast to tourist trick shots.

## Acceptance criteria

- [ ] Parked and moving cars both register splats and honk
- [ ] Traffic loops the blocks without overlapping or getting stuck at corners
- [ ] Cars read as visibly bigger/easier targets than tourists (the points contract)
- [ ] Getting splatted doesn't derail traffic logic (the loop continues)

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: splat a parked car and a moving car, follow one
traffic loop for a full circuit.

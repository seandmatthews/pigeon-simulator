# T-003 — Land, walk, take off

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** todo
- **Depends on:** T-001
- **Refs:** `docs/DESIGN.md` → Hunger (eating happens on the ground)

## What

Add an air/ground state machine to the Player:

- **Landing:** touching a surface at shallow angle + low speed → grounded (no damage model in M1)
- **Waddle:** WASD on the ground, slow and comedic; `flap` takes off again
- Anything on layer 1 (`world`) is landable — ground, roofs, benches

## Why

The hunger loop (T-005) needs the pigeon to come down, peck, and leave again. This is
the mechanic that makes the game touch the ground at all.

## Acceptance criteria

- [ ] Land on flat ground, a roof and a bench; walk on each; take off again
- [ ] Hard, fast landings just slide/stop — no crashes, no tunneling through geometry
- [ ] Take-off from a roof works the same as from the ground
- [ ] State is readable (HUD hint or animation pose) so players know they're grounded

## Verification

Gate 1 + Gate 2 + Gate 3, plus explicitly landing on all three surface types above.

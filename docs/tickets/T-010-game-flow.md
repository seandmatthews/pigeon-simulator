# T-010 — Game flow

- **Milestone:** M1 · **Priority:** P0 · **Size:** S · **Status:** todo
- **Depends on:** T-005
- **Refs:** `docs/DESIGN.md` → Fail state (locked: game over on starvation)

## What

Ships-in-a-box around the core loop:

- Title screen: placeholder logo + "press Space to fly"
- Pause on Esc: resume / restart / quit; physics and audio pause correctly
- Game over on starvation: score screen (score, high score, tourist/car breakdown)
  → restart
- Scene flow `menu.tscn` ↔ `main.tscn`; restart regenerates with the same M1 seed
  so scores stay comparable

## Why

Without an ending there's no run, and without a run there's no "one more go".

## Acceptance criteria

- [ ] Full loop works: boot → menu → play → starve → score screen → restart, no leaks/errors
- [ ] Esc pauses and resumes; nothing keeps moving while paused
- [ ] Restart resets score, hunger, city state and spawns
- [ ] Score screen shows score, high score, and a tourists-vs-cars breakdown

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: die on purpose twice in a row; pause mid-flight
during both runs.

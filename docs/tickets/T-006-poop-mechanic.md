# T-006 — Poop mechanic

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** todo
- **Depends on:** T-001
- **Refs:** `docs/DESIGN.md` → Poop

## What

The scoring verb of the whole game:

- **F** drops a poop projectile (layer 6 `projectile`) that inherits the pigeon's
  velocity and falls under gravity — a lob, not a raycast
- Splats stick to whatever they hit (decal) and fade out over a few seconds
- Hit resolution emits an event (`splatted(target, impact_velocity)`) so T-007/T-008
  targets and T-009 scoring can react without coupling
- Short cooldown (~1 s); effectively unlimited ammo in v1

## Why

It's the game's namesake act. Leading a moving tourist is the core skill expression.

## Acceptance criteria

- [ ] Poop arcs with inherited momentum; leading a moving target is possible
- [ ] Splat sticks to buildings, cars and tourists and fades cleanly
- [ ] Mashing F doesn't spawn a stream (cooldown respected)
- [ ] Any body on the right layers can receive the hit event without importing Player
- [ ] Poop exists only in the air — can't hit things above the pigeon

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: hit the ground, a wall, and (if present) a moving
placeholder; confirm splats and events with a debug print or HUD counter.

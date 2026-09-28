# T-006 — Poop mechanic

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** done
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

- [x] Poop arcs with inherited momentum; leading a moving target is possible
- [x] Splat sticks to buildings, cars and tourists and fades cleanly
- [x] Mashing F doesn't spawn a stream (cooldown respected)
- [x] Any body on the right layers can receive the hit event without importing Player
- [x] Poop exists only in the air — can't hit things above the pigeon

## Tuned values

- `Player` (`scripts/player.gd`) Poop group: `poop_cooldown` **1.0 s** ·
  `poop_drop_offset` **0.3 m** below the body · air-only (grounded F is ignored).
- `Poop` (`scripts/poop.gd`): `fall_gravity` **12 m/s²** (matches the flight
  model) · `fade_seconds` **4.0 s** · `splat_lift` **0.02 m** off the surface ·
  `max_lifetime` **12 s** then an unhittable drop frees itself · ball sphere
  r **0.07 m** · splat quad **0.45 m** · collision layer **6 projectile**,
  mask **world + npc + vehicle** (never the pigeon, pickups or other droppings).

## Verification

Gate 1 + Gate 2 + Gate 3. Machine-verified by six new Gate 1b scenarios
(`poop_inherits_and_arcs`, `poop_grounded_no_drop`, `poop_cooldown_blocks_stream`,
`poop_splats_ground_and_fades`, `poop_splats_wall`, `poop_event_reaches_any_body`
— 37/37 pass, exit 0), including a duck-typed hit receiver (`tests/splat_target.gd`)
and a source scan proving `poop.gd` references no player type. Gate 2: the
autoplay pilot now drops a real dropping every 2 s while airborne — its DONE
line reported `splats=10` (plus the still-working `eaten=1`), ok=true, no
SCRIPT ERROR, ~131 fps.

**Pending human playtest:** lob feel and splat readability in motion (the Gate 3
T-006 lines) — leading a real moving target only becomes playable once T-007/T-008
tourists and cars exist.

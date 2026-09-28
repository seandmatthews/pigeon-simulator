# Tickets

One file per ticket. Workflow, statuses and definition-of-done: [`AGENTS.md`](../../AGENTS.md).
Verification gates: [`VERIFICATION.md`](../../VERIFICATION.md). Design rationale: [`DESIGN.md`](../DESIGN.md).

## Milestone 1 — vertical slice

| ID | Ticket | Priority | Size | Depends on | Status |
| -- | ------ | -------- | ---- | ---------- | ------ |
| T-001 | [Flight feel v1](T-001-flight-feel.md) | P0 | L | — | todo |
| T-002 | [Chase camera v1](T-002-chase-camera.md) | P0 | S | T-001 | todo |
| T-003 | [Land, walk, take off](T-003-land-walk-takeoff.md) | P1 | M | T-001 | todo |
| T-004 | [City blockout v1](T-004-city-blockout.md) | P0 | L | — | todo |
| T-005 | [Bread & hunger](T-005-bread-and-hunger.md) | P0 | M | T-003, T-004 | todo |
| T-006 | [Poop mechanic](T-006-poop-mechanic.md) | P0 | M | T-001 | todo |
| T-007 | [Tourists v1](T-007-tourists.md) | P0 | M | T-004, T-006 | todo |
| T-008 | [Cars v1](T-008-cars.md) | P0 | M | T-004, T-006 | todo |
| T-009 | [Scoring & combos](T-009-scoring-and-combos.md) | P0 | M | T-006, T-007, T-008 | todo |
| T-010 | [Game flow](T-010-game-flow.md) | P0 | S | T-005 | todo |
| T-011 | [Pigeon presentation v1](T-011-pigeon-presentation.md) | P1 | M | T-001, T-003 | todo |
| T-012 | [Audio v1](T-012-audio.md) | P1 | M | T-005, T-006, T-007, T-008 | todo |
| T-013 | [Juice pass v1](T-013-juice-pass.md) | P1 | M | T-006, T-009 | todo |

## Milestone 2 — after the slice (not yet ticketed)

Districts & palette variety · hawk hazard · seagull bread rivals · statue/landmark
bonus targets · objectives & missions · gamepad support · settings (sensitivity,
invert-Y, volume) · performance budget pass · Windows export builds.

## Suggested build order

T-001 (feel) and T-004 (world) are independent — run them in parallel. T-002 follows
T-001. T-003 unlocks the ground loop that T-005 needs. T-006 unlocks the target
tickets T-007/T-008, which unlock T-009. T-010 ties the loop together. T-011, T-012
and T-013 are polish that can land any time after their dependencies.

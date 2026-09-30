# Tickets

One file per ticket. Workflow, statuses and definition-of-done: [`AGENTS.md`](../../AGENTS.md).
Verification gates: [`VERIFICATION.md`](../../VERIFICATION.md). Design rationale: [`DESIGN.md`](../DESIGN.md).

## Milestone 1 — vertical slice

| ID | Ticket | Priority | Size | Depends on | Status |
| -- | ------ | -------- | ---- | ---------- | ------ |
| T-001 | [Flight feel v1](T-001-flight-feel.md) | P0 | L | — | done |
| T-002 | [Chase camera v1](T-002-chase-camera.md) | P0 | S | T-001 | done |
| T-003 | [Land, walk, take off](T-003-land-walk-takeoff.md) | P1 | M | T-001 | done |
| T-004 | [City blockout v1](T-004-city-blockout.md) | P0 | L | — | done |
| T-005 | [Bread & hunger](T-005-bread-and-hunger.md) | P0 | M | T-003, T-004 | done |
| T-006 | [Poop mechanic](T-006-poop-mechanic.md) | P0 | M | T-001 | done |
| T-007 | [Tourists v1](T-007-tourists.md) | P0 | M | T-004, T-006 | done |
| T-008 | [Cars v1](T-008-cars.md) | P0 | M | T-004, T-006 | done |
| T-009 | [Scoring & combos](T-009-scoring-and-combos.md) | P0 | M | T-006, T-007, T-008 | done |
| T-010 | [Game flow](T-010-game-flow.md) | P0 | S | T-005 | done |
| T-011 | [Pigeon presentation v1](T-011-pigeon-presentation.md) | P1 | M | T-001, T-003 | done |
| T-012 | [Audio v1](T-012-audio.md) | P1 | M | T-005, T-006, T-007, T-008 | done |
| T-013 | [Juice pass v1](T-013-juice-pass.md) | P1 | M | T-006, T-009 | done |
| T-014 | [Multi-instance pilot harness](T-014-pilot-multi-instance.md) | P1 | M | — | done |
| T-015 | [Flap envelope](T-015-flap-envelope.md) | P1 | S | T-001 | done |
| T-016 | [Pigeon silhouette & readable backdrops](T-016-pigeon-silhouette.md) | P1 | S | T-011, T-013 | done |
| T-017 | [Shopfront ground floors](T-017-shopfronts.md) | P1 | S | T-004, T-013 | done |
| T-018 | [Performance budget pass](T-018-performance-budget.md) | P1 | M | T-004, T-007, T-008 | done |
| T-019 | [HUD legibility & hunger warning](T-019-hud-legibility.md) | P0 | S | T-005, T-010 | done |
| T-020 | [Park elders share bread](T-020-park-elders.md) | P1 | S | T-004, T-005, T-007 | done |

## Sweep backlog (agent sweeps)

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-021 | [Stick the landing: settle shallow touchdowns on contact](T-021-stick-the-landing.md) | flight-control | 4 | 2 | done |
| T-022 | [Give pitch-up a real flare near the ground instead of a balloon](T-022-pitch-flare.md) | flight-control | 4 | 3 | proposed |
| T-023 | [Edge-of-world guard: nudge the pigeon home past the apron](T-023-edge-of-world-guard.md) | flight-control | 3 | 3 | proposed |
| T-024 | [Make the bird read at cruise: trim the FOV kick and arm](T-024-cruise-readability.md) | flight-control | 3 | 1 | proposed |
| T-025 | [Make the falling dropping trackable: bigger ball, soft emission](T-025-poop-ball-visibility.md) | visual-design | 3 | 1 | proposed |
| T-026 | [Re-value the ground planes: stop the sidewalk/plaza blowout, lift the road](T-026-ground-palette-retune.md) | visual-design | 4 | 2 | proposed |
| T-027 | [Fix the grounded read: thin the folded wing chord at the rig level](T-027-folded-wing-chord.md) | visual-design | 3 | 2 | proposed |
| T-029 | [Plaza landmark: statue on a plinth at the square's center](T-029-plaza-landmark.md) | worldbuilding | 3 | 2 | proposed |
| T-030 | [Tree the parks (prototyped live: 4 MultiMesh trees per park block)](T-030-park-trees.md) | worldbuilding | 3 | 1 | proposed |
| T-031 | [Cafe life under the awnings: tables with seated tourists on shop fronts](T-031-cafe-tables.md) | worldbuilding | 4 | 2 | proposed |
| T-032 | [Give roofs a reason to exist: rooftop clutter and roof bread spots](T-032-roof-clutter.md) | worldbuilding | 4 | 2 | proposed |
| T-033 | [Same-seed restart skips the city rebuild](T-033-same-seed-restart-skip.md) | code-optimization | 4 | 2 | done |
| T-034 | [Extract the duplicated spawner band/recycle machinery](T-034-spawner-band-extraction.md) | code-optimization | 3 | 3 | proposed |
| T-035 | [Stop the per-frame redundant presentation writes](T-035-redundant-presentation-writes.md) | code-optimization | 2 | 1 | proposed |
| T-036 | [Guard the off-world fall with a return to the spawn corridor](T-036-off-world-fall-respawn.md) | code-optimization | 4 | 2 | proposed |
| T-037 | [HUD bread pointer & off-city "city that way"](T-037-hud-bread-pointer.md) | ui-ux | 4 | 2 | proposed |
| T-038 | [Show the style bonus in the score popup](T-038-style-tag-in-popup.md) | ui-ux | 3 | 1 | proposed |
| T-039 | [Teach the controls on the title screen](T-039-title-controls.md) | ui-ux | 3 | 1 | proposed |
| T-040 | [HUD combo strip & hit marker: make every scored hit readable](T-040-combo-strip-hit-marker.md) | ui-ux | 4 | 2 | proposed |

## Milestone 2 — after the slice (not yet ticketed)

Districts & palette variety · hawk hazard · seagull bread rivals · statue/landmark
bonus targets · objectives & missions · gamepad support · settings (sensitivity,
invert-Y, volume) · performance budget pass · Windows export builds.

## Suggested build order

T-001 (feel) and T-004 (world) are independent — run them in parallel. T-002 follows
T-001. T-003 unlocks the ground loop that T-005 needs. T-006 unlocks the target
tickets T-007/T-008, which unlock T-009. T-010 ties the loop together. T-011, T-012
and T-013 are polish that can land any time after their dependencies.

# Tickets

One file per ticket. Workflow, statuses and definition-of-done: [`AGENTS.md`](../../AGENTS.md).
Verification gates: [`VERIFICATION.md`](../../VERIFICATION.md). Design rationale: [`DESIGN.md`](../DESIGN.md).

## Current phase

**Sweep polish, waves W1–W8** — readability, flight feel and performance over
the M1 slice. Schedule, phase goals and exit criteria:
[`docs/ROADMAP.md`](../ROADMAP.md). M2 (the town-vs-visitors goal layer) is
proposed but **not yet ticketed** — see [`DESIGN.md`](../DESIGN.md) →
Milestone 2; don't pull M2 work into sweep waves.

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
| T-022 | [Give pitch-up a real flare near the ground instead of a balloon](T-022-pitch-flare.md) | flight-control | 4 | 3 | done |
| T-023 | [Edge-of-world guard: nudge the pigeon home past the apron](T-023-edge-of-world-guard.md) | flight-control | 3 | 3 | proposed |
| T-024 | [Make the bird read at cruise: trim the FOV kick and arm](T-024-cruise-readability.md) | flight-control | 3 | 1 | superseded (T-044) |
| T-025 | [Make the falling dropping trackable: bigger ball, soft emission](T-025-poop-ball-visibility.md) | visual-design | 3 | 1 | superseded (adopted by T-086) |
| T-026 | [Re-value the ground planes: stop the sidewalk/plaza blowout, lift the road](T-026-ground-palette-retune.md) | visual-design | 4 | 2 | done |
| T-027 | [Fix the grounded read: thin the folded wing chord at the rig level](T-027-folded-wing-chord.md) | visual-design | 3 | 2 | done (T-048) |
| T-029 | [Plaza landmark: statue on a plinth at the square's center](T-029-plaza-landmark.md) | worldbuilding | 3 | 2 | done |
| T-030 | [Tree the parks (prototyped live: 4 MultiMesh trees per park block)](T-030-park-trees.md) | worldbuilding | 3 | 1 | done |
| T-031 | [Cafe life under the awnings: tables with seated tourists on shop fronts](T-031-cafe-tables.md) | worldbuilding | 4 | 2 | done |
| T-032 | [Give roofs a reason to exist: rooftop clutter and roof bread spots](T-032-roof-clutter.md) | worldbuilding | 4 | 2 | done |
| T-033 | [Same-seed restart skips the city rebuild](T-033-same-seed-restart-skip.md) | code-optimization | 4 | 2 | done |
| T-034 | [Extract the duplicated spawner band/recycle machinery](T-034-spawner-band-extraction.md) | code-optimization | 3 | 3 | superseded (T-054) |
| T-035 | [Stop the per-frame redundant presentation writes](T-035-redundant-presentation-writes.md) | code-optimization | 2 | 1 | superseded (T-055) |
| T-036 | [Guard the off-world fall with a return to the spawn corridor](T-036-off-world-fall-respawn.md) | code-optimization | 4 | 2 | done (adopted by T-042) |
| T-037 | [HUD bread pointer & off-city "city that way"](T-037-hud-bread-pointer.md) | ui-ux | 4 | 2 | done |
| T-038 | [Show the style bonus in the score popup](T-038-style-tag-in-popup.md) | ui-ux | 3 | 1 | done |
| T-039 | [Teach the controls on the title screen](T-039-title-controls.md) | ui-ux | 3 | 1 | proposed |
| T-040 | [HUD combo strip & hit marker: make every scored hit readable](T-040-combo-strip-hit-marker.md) | ui-ux | 4 | 2 | done |
| T-041 | [Land the pitch-up flare: brake-sink instead of balloon (adopt T-022)](T-041-flare-brake-sink.md) | flight-control | 4 | 3 | superseded (T-084) |
| T-042 | [Guard the off-world void: respawn at the spawn corridor (adopt T-036)](T-042-off-world-void-respawn.md) | flight-control | 4 | 2 | done |
| T-043 | [Cap the sustained-flap throttle so dives own the top end](T-043-sustained-flap-cap.md) | flight-control | 3 | 3 | done |
| T-044 | [Trim the pinned FOV kick and pull the arm in at speed (adopt T-024)](T-044-fov-arm-trim.md) | flight-control | 3 | 1 | done |
| T-045 | [Give the bird a pale rump/wing-bar anchor that survives roads and roofs](T-045-pale-rump-anchor.md) | visual-design | 3 | 1 | superseded (T-085) |
| T-046 | [Add a predicted-impact ring for drops — the bombsight behind T-086's bigger ball](T-046-poop-impact-ring.md) | visual-design | 4 | 2 | done |
| T-047 | [Build a readable rim at the city edge — trees/hedge ring instead of the infinite flat apron](T-047-city-edge-rim.md) | visual-design | 3 | 2 | superseded (T-088) |
| T-048 | [Adopt T-027's folded-wing chord fix — confirmed live, plus an elder-read accent](T-048-folded-wing-chord-adoption.md) | visual-design | 3 | 2 | done |
| T-049 | [Fit facade windows to each building's real floor count](T-049-facade-floors.md) | worldbuilding | 3 | 1 | done |
| T-050 | [Put a skyline on the horizon so the world doesn't end at a cliff](T-050-horizon-skyline.md) | worldbuilding | 3 | 1 | superseded (T-088) |
| T-051 | [Vary building footprints to break the uniform block grid](T-051-varied-footprints.md) | worldbuilding | 4 | 3 | done |
| T-053 | [Land the off-world fall guard: falling past the apron returns you home](T-053-off-world-fall-guard.md) | code-optimization | 4 | 2 | done |
| T-054 | [Extract BandSpawner and close the unverified car-recycle contract](T-054-band-spawner-extraction.md) | code-optimization | 3 | 3 | proposed |
| T-055 | [Stop the per-frame redundant presentation writes and the HUD pointer's per-frame array churn](T-055-redundant-writes-pointer-churn.md) | code-optimization | 2 | 1 | done |
| T-057 | [Derive the bread-pointer chevron from screen space; pin Gate 1b to independent ground truth](T-057-screen-space-bread-chevron.md) | ui-ux | 4 | 3 | done |
| T-058 | [Make the off-city void readable: teach the chevron convention and cue the edge](T-058-off-city-turn-around.md) | ui-ux | 3 | 1 | proposed |
| T-059 | [Retune the world score popup: legible at hit distances, de-cluster chained hits](T-059-score-popup-retune.md) | ui-ux | 3 | 1 | done |
| T-060 | [Make the splat humanly possible and coach the lead](T-060-poop-hitbox-coach.md) | ui-ux | 4 | 2 | proposed |
| T-061 | [Make a stall fall: grade the velocity-align cut by stall depth](T-061-stall-fall-develops.md) | flight-control | 4 | 3 | superseded (T-081) |
| T-062 | [Fade pitch authority near vertical — no more stuck 68–101° ballooning attitudes](T-062-pitch-authority-falloff.md) | flight-control | 4 | 3 | superseded (T-083) |
| T-069 | [Paint the intersections — crosswalks so streets read as streets](T-069-crosswalk-intersection-paint.md) | worldbuilding | 3 | 1 | done |
| T-073 | [Take the high-score save off the scoring hot path (save once per run, flush at game over)](T-073-highscore-save-off-hot-path.md) | code-optimization | 2 | 2 | proposed |
| T-074 | [Fix the broken failure diagnostics in two Gate 1b scenarios (string-precedence bug)](T-074-gate1b-fail-diagnostics.md) | code-optimization | 3 | 1 | done |
| T-075 | [Calm the hunger→HUD write storm: emit only on real change, stop rewriting the bar at tick rate (T-055's missed 4th site)](T-075-hunger-hud-write-storm.md) | code-optimization | 2 | 2 | done |
| T-077 | [Give F a readiness cue: three silent failure modes, one glyph](T-077-poop-ready-cue.md) | ui-ux | 4 | 1 | done |
| T-078 | [Make the elder's arm the trust meter — make the hangout learnable](T-078-elder-arm-trust-meter.md) | ui-ux | 3 | 1 | done |
| T-079 | [Acknowledge the combo a landing kills — the loss moment is invisible](T-079-combo-landing-note.md) | ui-ux | 3 | 2 | done |
| T-080 | [Give the hunger bar a dark track/border — the white bar vanishes on bright ground](T-080-hunger-bar-track.md) | ui-ux | 3 | 1 | done |
| T-081 | [Make sub-glide flight fall: key the align cut on lift, not stall depth](T-081-lift-keyed-align-cut.md) | flight-control | 4 | 4 | done |
| T-082 | [Give released pitch inputs a hands-off trim toward the velocity vector](T-082-released-pitch-trim.md) | flight-control | 4 | 3 | done |
| T-083 | [Adopt T-062: bound pitch attitude with authority falloff near vertical](T-083-pitch-attitude-bound.md) | flight-control | 4 | 3 | done |
| T-084 | [Adopt T-041: pitch-up near the ground becomes a brake-sink, not a balloon](T-084-flare-brake-sink.md) | flight-control | 4 | 3 | superseded (T-022 landed the flare; audit 2026-09-30: stale) |
| T-085 | [Adopt T-045's pale rump/underwing anchor — the player bird is a gray smudge on road and roof](T-085-pale-rump-anchor-adoption.md) | visual-design | 3 | 1 | done |
| T-086 | [Adopt T-025's bigger emissive drop ball — A/B-proven live, minus a latent parse bug in the ticket](T-086-poop-ball-visibility-adoption.md) | visual-design | 4 | 1 | done |
| T-087 | [Give the off-world return a visible "came home" beat — today it is a blank frame and a hard cut](T-087-off-world-return-beat.md) | visual-design | 3 | 2 | done |
| T-088 | [Make the city edge legible: T-047's near rim plus T-050's far skyline as one pass](T-088-city-edge-rim-skyline.md) | visual-design | 4 | 2 | done |
| T-089 | [Unclog the band: traffic must move when you stand still](T-089-traffic-recycle-flow.md) | worldbuilding | 4 | 2 | done |
| T-090 | [Signboards over the shop doors](T-090-shop-signboards.md) | worldbuilding | 3 | 1 | done |
| T-091 | [One tall anchor per district — a destination you can steer by](T-091-district-anchors.md) | worldbuilding | 4 | 2 | proposed |
| T-093 | [Merge the city's 840 single-shape static bodies into one body per group](T-093-city-one-body-per-group.md) | code-optimization | 2 | 2 | done |
| T-094 | [Cafe furniture is ~58% of boot nodes — batch it like the city props](T-094-cafe-furniture-batched.md) | code-optimization | 3 | 3 | proposed |
| T-095 | [Make the off-world return and the buzz flinch visible to pilot sessions](T-095-pilot-off-world-buzz-events.md) | code-optimization | 3 | 1 | done |
| T-097 | [Stop the title screen's Esc key from hard-quitting the app](T-097-title-esc-no-quit.md) | ui-ux | 3 | 1 | done |
| T-098 | [Give the bread pointer an up/down cue — roof crumbs currently point into walls](T-098-bread-pointer-climb-cue.md) | ui-ux | 4 | 1 | done |
| T-099 | [Put the controls inside the pause menu — the one screen a stuck player opens](T-099-pause-menu-controls.md) | ui-ux | 3 | 1 | done |
| T-100 | [Whisper 'home again' when the off-world guard snaps the pigeon back](T-100-off-world-home-note.md) | ui-ux | 3 | 1 | superseded (T-087) |
| T-101 | [Boot muted: start silent unless a sound-design session opts in](T-101-boot-muted.md) | ui-ux | 3 | 1 | done |
| T-102 | [Zebra stripes run with the traffic: flip T-069's crossing stripes 90°](T-102-crosswalk-stripe-orientation.md) | visual-design | 3 | 1 | done |
| T-103 | [Stand the shop doors up: fix the inverted axis swap that renders them as fins](T-103-shop-door-orientation.md) | worldbuilding | 2 | 1 | proposed |

**Backlog quality audit (2026-09-30):** all 38 proposed tickets were audited —
22 solid, 15 need fixes, 1 stale (T-084). All 16 flagged tickets have since
been re-reviewed and fixed in their files (see the addendum at the end of
[backlog-audit-2026-09-30.md](backlog-audit-2026-09-30.md) for the per-ticket
fixes and commits). Tickets still go stale fast — re-verify a ticket's
current-state section right before building it.

## Milestone 2 — the town's pigeon (proposed, not yet ticketed)

Direction proposed 2026-10-01 — detail and the four open forks in
[`DESIGN.md`](../DESIGN.md) → Milestone 2. Short version: the town gets memory
and sides — befriend the locals (park elders first), drive off the rowdy
visiting fans, game-day arc, real-US-city setting (Ames or Des Moines — US
street conventions firm, city choice open), no quest machinery. The old M2
sketch folds in where it serves that spine (hawk hazard, seagull rivals at the
tailgates, districts as campus/main-street/tailgate palettes, landmark bonus
targets, gamepad, settings, export builds); objectives & missions stay out.
No M2 tickets until the forks are decided.

## Suggested build order

T-001 (feel) and T-004 (world) are independent — run them in parallel. T-002 follows
T-001. T-003 unlocks the ground loop that T-005 needs. T-006 unlocks the target
tickets T-007/T-008, which unlock T-009. T-010 ties the loop together. T-011, T-012
and T-013 are polish that can land any time after their dependencies.

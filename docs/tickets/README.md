# Tickets

One file per ticket. Workflow, statuses and definition-of-done: [`AGENTS.md`](../../AGENTS.md).
Verification gates: [`VERIFICATION.md`](../../VERIFICATION.md). Design rationale: [`DESIGN.md`](../DESIGN.md).

## Current phase

**M3 waves 1–2 — owner-directed batches from the brainstorm**
([`../IDEAS.md`](../IDEAS.md)) — wave 1 (T-121..T-126) landed 2026-10-17/18;
wave 2 (T-127..T-129) landed 2026-10-18/19; T-130 (bigger Fly button, real
poop distance) followed 2026-10-20. T-120 (readable touch buttons) stays
open from the mobile phase. Phase goals and
exit criteria: [`../ROADMAP.md`](../ROADMAP.md).

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
| T-023 | [Edge-of-world guard: nudge the pigeon home past the apron](T-023-edge-of-world-guard.md) | flight-control | 3 | 3 | done |
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
| T-039 | [Teach the controls on the title screen](T-039-title-controls.md) | ui-ux | 3 | 1 | done |
| T-040 | [HUD combo strip & hit marker: make every scored hit readable](T-040-combo-strip-hit-marker.md) | ui-ux | 4 | 2 | done |
| T-041 | [Land the pitch-up flare: brake-sink instead of balloon (adopt T-022)](T-041-flare-brake-sink.md) | flight-control | 4 | 3 | superseded (T-084) |
| T-042 | [Guard the off-world void: respawn at the spawn corridor (adopt T-036)](T-042-off-world-void-respawn.md) | flight-control | 4 | 2 | done |
| T-043 | [Cap the sustained-flap throttle so dives own the top end](T-043-sustained-flap-cap.md) | flight-control | 3 | 3 | done |
| T-044 | [Trim the pinned FOV kick and pull the arm in at speed (adopt T-024)](T-044-fov-arm-trim.md) | flight-control | 3 | 1 | done |
| T-045 | [Give the bird a pale rump/wing-bar anchor that survives roads and roofs](T-045-pale-rump-anchor.md) | visual-design | 3 | 1 | superseded (T-085) |
| T-046 | [Add a predicted-impact ring for drops — the bombsight behind T-086's bigger ball](T-046-poop-impact-ring.md) — superseded by T-105 (the persistent live/frozen reticle; its undamped-march bias fixed there) | visual-design | 4 | 2 | superseded (T-105) |
| T-047 | [Build a readable rim at the city edge — trees/hedge ring instead of the infinite flat apron](T-047-city-edge-rim.md) | visual-design | 3 | 2 | superseded (T-088) |
| T-048 | [Adopt T-027's folded-wing chord fix — confirmed live, plus an elder-read accent](T-048-folded-wing-chord-adoption.md) | visual-design | 3 | 2 | done |
| T-049 | [Fit facade windows to each building's real floor count](T-049-facade-floors.md) | worldbuilding | 3 | 1 | done |
| T-050 | [Put a skyline on the horizon so the world doesn't end at a cliff](T-050-horizon-skyline.md) | worldbuilding | 3 | 1 | superseded (T-088) |
| T-051 | [Vary building footprints to break the uniform block grid](T-051-varied-footprints.md) | worldbuilding | 4 | 3 | done |
| T-053 | [Land the off-world fall guard: falling past the apron returns you home](T-053-off-world-fall-guard.md) | code-optimization | 4 | 2 | done |
| T-054 | [Extract BandSpawner and close the unverified car-recycle contract](T-054-band-spawner-extraction.md) | code-optimization | 3 | 3 | done |
| T-055 | [Stop the per-frame redundant presentation writes and the HUD pointer's per-frame array churn](T-055-redundant-writes-pointer-churn.md) | code-optimization | 2 | 1 | done |
| T-057 | [Derive the bread-pointer chevron from screen space; pin Gate 1b to independent ground truth](T-057-screen-space-bread-chevron.md) | ui-ux | 4 | 3 | done |
| T-058 | [Make the off-city void readable: teach the chevron convention and cue the edge](T-058-off-city-turn-around.md) | ui-ux | 3 | 1 | done |
| T-059 | [Retune the world score popup: legible at hit distances, de-cluster chained hits](T-059-score-popup-retune.md) | ui-ux | 3 | 1 | done |
| T-060 | [Make the splat humanly possible and coach the lead](T-060-poop-hitbox-coach.md) | ui-ux | 4 | 2 | done |
| T-061 | [Make a stall fall: grade the velocity-align cut by stall depth](T-061-stall-fall-develops.md) | flight-control | 4 | 3 | superseded (T-081) |
| T-062 | [Fade pitch authority near vertical — no more stuck 68–101° ballooning attitudes](T-062-pitch-authority-falloff.md) | flight-control | 4 | 3 | superseded (T-083) |
| T-069 | [Paint the intersections — crosswalks so streets read as streets](T-069-crosswalk-intersection-paint.md) | worldbuilding | 3 | 1 | done |
| T-073 | [Take the high-score save off the scoring hot path (save once per run, flush at game over)](T-073-highscore-save-off-hot-path.md) | code-optimization | 2 | 2 | done |
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
| T-091 | [One tall anchor per district — a destination you can steer by](T-091-district-anchors.md) | worldbuilding | 4 | 2 | done |
| T-093 | [Merge the city's 840 single-shape static bodies into one body per group](T-093-city-one-body-per-group.md) | code-optimization | 2 | 2 | done |
| T-094 | [Cafe furniture is ~58% of boot nodes — batch it like the city props](T-094-cafe-furniture-batched.md) | code-optimization | 3 | 3 | done |
| T-095 | [Make the off-world return and the buzz flinch visible to pilot sessions](T-095-pilot-off-world-buzz-events.md) | code-optimization | 3 | 1 | done |
| T-097 | [Stop the title screen's Esc key from hard-quitting the app](T-097-title-esc-no-quit.md) | ui-ux | 3 | 1 | done |
| T-098 | [Give the bread pointer an up/down cue — roof crumbs currently point into walls](T-098-bread-pointer-climb-cue.md) | ui-ux | 4 | 1 | done |
| T-099 | [Put the controls inside the pause menu — the one screen a stuck player opens](T-099-pause-menu-controls.md) | ui-ux | 3 | 1 | done |
| T-100 | [Whisper 'home again' when the off-world guard snaps the pigeon back](T-100-off-world-home-note.md) | ui-ux | 3 | 1 | superseded (T-087) |
| T-101 | [Boot muted: start silent unless a sound-design session opts in](T-101-boot-muted.md) | ui-ux | 3 | 1 | done |
| T-102 | [Zebra stripes run with the traffic: flip T-069's crossing stripes 90°](T-102-crosswalk-stripe-orientation.md) | visual-design | 3 | 1 | done |
| T-103 | [Stand the shop doors up: fix the inverted axis swap that renders them as fins](T-103-shop-door-orientation.md) | worldbuilding | 2 | 1 | done |
| T-104 | [Move the spawn plaza's bins outside the bench ring: today they bury into the diagonal benches](T-104-plaza-bins-outside-bench-ring.md) | worldbuilding | 3 | 2 | done |
| T-105 | [One persistent poop target: the live/frozen reticle that replaces the per-drop ring](T-105-poop-target-reticle.md) | visual-design | 4 | 2 | done |
| T-106 | [Kill the post-loop roll cant: drive the bank controller and leveler from measured roll](T-106-loop-roll-cant.md) | flight-control | 4 | 3 | done |
| T-107 | [Adopt the B6 Merged sculpt as the interim player pigeon](T-107-b6-merged-pigeon.md) | visual-design | 4 | 2 | done |
| T-108 | [Adopt the realistic Blender pigeon as the player bird](T-108-realistic-pigeon-player.md) | visual-design | 5 | 2 | done |
| T-109 | [Articulate the realistic pigeon: rigged wings, head and feet](T-109-realistic-pigeon-rig.md) | visual-design | 5 | 2 | done |
| T-110 | [Reticle live refresh: 10 Hz → 30 Hz](T-110-reticle-live-refresh-30hz.md) | visual-design | 3 | 1 | done |
| T-111 | [The bread globe: a pigeon-frame 3D bread finder replaces the 2D chevron pointer](T-111-bread-globe.md) | ui-ux | 4 | 3 | done |
| T-112 | [Bread belongs at the tables: reweight the crumb spread to ~90% café tabletops, roofs rare](T-112-bread-at-the-tables.md) | worldbuilding | 4 | 2 | done |
| T-113 | [The invasion has a uniform: citizens split into black-and-gold VISITORS, CIVILIAN locals and a rare cardinal-and-gold HOMETOWN SUPERFAN](T-113-citizen-classes.md) | worldbuilding | 4 | 3 | done |
| T-114 | [The favor economy: visitor splats earn the elders' favor, local blood and stolen crumbs spend it, and elder bread is bought with it](T-114-favor-economy.md) | worldbuilding | 4 | 3 | done |
| T-115 | [Sufficiently hostile: the favor-max victory ending](T-115-favor-max-victory.md) | worldbuilding | 5 | 2 | done |
| T-116 | [The meter names the prize: the favor row shows the ceiling and the HUD states the win](T-116-favor-meter-names-the-prize.md) | ui-ux | 4 | 1 | done |
| T-117 | [20% more WASD: the owner responsiveness pass](T-117-wasd-20-percent.md) | flight-control | 4 | 2 | done |
| T-134 | [American four-way stops: multi-block routes, right-of-way, blinker tells and stop-sign props](T-134-four-way-stops.md) | worldbuilding | 4 | 3 | done |
| T-147 | [Favor pays once per target; spent cars churn out of the fleet at the recycle radius](T-147-favor-once-per-target.md) | worldbuilding | 4 | 3 | done |
| T-148 | [Haze the skyline ring: apron monoliths dissolve into the horizon](T-148-skyline-haze.md) | visual-design | 4 | 1 | done |
| T-149 | [Visitor cars get a roof-level tell: the class reads from the dive](T-149-visitor-roof-topper.md) | visual-design | 4 | 2 | proposed |
| T-150 | [Soften the bead juice: dust billows, splat splash flattens](T-150-soften-bead-juice.md) | visual-design | 3 | 1 | proposed |
| T-151 | [Name the class on every hit readout](T-151-hit-feedback-names-the-class.md) | ui-ux | 4 | 2 | done |
| T-152 | [Teach the color code where the favor rule already lives](T-152-teach-the-color-code.md) | ui-ux | 3 | 1 | proposed |
| T-153 | [Attribute the favor delta to its cause](T-153-favor-note-names-the-cause.md) | ui-ux | 3 | 2 | proposed |
| T-154 | [Retire the amber civilian shirt — the last gold hue-twin](T-154-retire-amber-civilian-shirt.md) | ui-ux | 3 | 2 | proposed |
| T-155 | [Floor the skyline-ring haze: inner monoliths must read as backdrop](T-155-skyline-haze-floor.md) | visual-design | 4 | 1 | done |
| T-156 | [Fog the far field into the sky-horizon color](T-156-far-field-fog.md) | visual-design | 3 | 2 | proposed |
| T-157 | [Give the splat burst a value that survives white paint](T-157-splat-contrast-on-white-paint.md) | visual-design | 3 | 1 | proposed |
| T-158 | [Give the poop reticle a target tell: name what the pin is on before the drop](T-158-reticle-target-tell.md) | ui-ux | 4 | 2 | done |
| T-159 | [The starved game-over screen should carry the favor goal it ignored all run](T-159-starved-screen-favor-line.md) | ui-ux | 3 | 2 | proposed |
| T-160 | [Mark a spent target on repeat hits: "favor paid" on the readout](T-160-favor-paid-suffix.md) | ui-ux | 3 | 2 | proposed |
| T-161 | [Separate the bread crumb from the yellow lane paint — the first verb misreads](T-161-crumb-vs-lane-paint.md) | ui-ux | 3 | 1 | proposed |

**Backlog quality audit (2026-09-30):** all 38 proposed tickets were audited —
22 solid, 15 need fixes, 1 stale (T-084). All 16 flagged tickets have since
been re-reviewed and fixed in their files (see the addendum at the end of
[backlog-audit-2026-09-30.md](backlog-audit-2026-09-30.md) for the per-ticket
fixes and commits). Tickets still go stale fast — re-verify a ticket's
current-state section right before building it.

## Milestone 2 — the town's pigeon (3-ticket sequence approved by the owner 2026-10-11)

Direction proposed 2026-10-01 — detail and the four open forks in
[`DESIGN.md`](../DESIGN.md) → Milestone 2. Short version: the town gets memory
and sides — befriend the locals (park elders first), drive off the rowdy
visiting fans, game-day arc, real-US-city setting (Ames — fixed by the split;
US street conventions firm), no quest machinery. The old M2
sketch folds in where it serves that spine (hawk hazard, seagull rivals at the
tailgates, districts as campus/main-street/tailgate palettes, landmark bonus
targets, gamepad, settings, export builds); objectives & missions stay out.
The approved sequence: **T-113** citizen classes (first ticket, above, done) →
**T-114** the favor economy (above, ticket 2, done) → **T-115** the favor-max
victory ending (above, ticket 3, done) — named in T-113 and
forged in order after each lands.

## Mobile — play it on her iPhone (owner-directed 2026-10-14)

The owner wants the game playable on his girlfriend's iPhone. Direction decided
2026-10-14: a single-threaded web build she opens in Safari, hosted on the
owner's own server (re-targeted 2026-10-15 to the basement Linux box at
`games.matthews.mx/pigeon-simulator/` under nginx; the original Cloudflare
Pages call was shelved) — native iOS is ruled out (Godot's iOS export needs
macOS/Xcode plus an Apple developer account). Platform first as the go/no-go
de-risk, touch controls second. Both tickets are done; the hosted-URL and
iPhone Gate 3 passes are the owner's. See the ticket files for the traps list.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-118 | [A web build Safari can run: Compatibility web override, single-threaded export, Cloudflare Pages](T-118-web-safari-build.md) | platform | 3 | 3 | done |
| T-119 | [Thumbs on the city: a virtual joystick and touch buttons for the phone](T-119-touch-controls.md) | ui-ux | 4 | 2 | done |
| T-120 | [Readable thumbs: the touch buttons need an at-a-glance treatment](T-120-readable-touch-buttons.md) | ui-ux | 2 | 1 | proposed |

## M3 wave 1 — the owner's improvement batch (2026-10-17)

Six confirmed, no-further-input ideas folded out of the 2026-10-15/17
brainstorm ([`../IDEAS.md`](../IDEAS.md) — every remaining item there stays
pitched behind its open decision-log forks). Suggested order: T-121 → T-124
(the swap implements T-121's rules on the new models); T-122, T-123, T-125
and T-126 are independent.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-121 | [Unmistakable targets: reserve black-and-gold for the visitors, grow the flag](T-121-unmistakable-targets.md) | visual-design | 4 | 1 | done (Gate 3 pending) |
| T-122 | [Settings v1: invert pitch + volume on the pause menu](T-122-settings-v1.md) | ui-ux | 3 | 2 | done (Gate 3 pending) |
| T-123 | [Sound pass: coos, splat variety, and endings that aren't silent](T-123-sound-pass.md) | audio | 4 | 1 | done (Gate 3 pending) |
| T-124 | [People and cars: swap in Quaternius pedestrians and Kenney cars](T-124-people-and-cars.md) | visual-design | 5 | 3 | done 2026-10-17 |
| T-125 | [Ditch the Godot boot splash](T-125-boot-splash.md) | visual-design | 2 | 1 | done (Gate 3 pending) |
| T-126 | [Hide Quit on the web (a browser tab can't close itself)](T-126-web-quit.md) | platform | 2 | 1 | done (Gate 3 pending) |

## M3 wave 2 — owner picks from the ideas doc (2026-10-18)

Fork-free pitches pulled from [`../IDEAS.md`](../IDEAS.md) plus one
owner-directed platform ticket, run serially through the pipeline (shared
sim_test/VERIFICATION surfaces). Everything else in the ideas doc stays
pitched behind its decision-log forks.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-127 | [Xbox controller: sticks and pads drive the existing actions](T-127-xbox-controller.md) | ui-ux | 4 | 2 | done (Gate 3 pending) |
| T-128 | [Traffic spawns off-screen and drives in](T-128-traffic-spawns-offscreen.md) | worldbuilding | 3 | 2 | done (Gate 3 pending) |
| T-129 | [Web boot paints instead of stalling: sliced city boot + a loading screen that waits for warm](T-129-web-boot-paints.md) | platform | 4 | 3 | done (Gate 3 pending) |

## Mobile follow-up — owner feedback (2026-10-19)

Second hands-on pass on the hosted phone build, verbatim: "the fly button is
too small, and the poop button is too close to it." Size/spacing moves are
deliberately out of T-120's legibility scope, so this is its own
owner-directed ticket; runs through the pipeline per T-119's route note.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-130 | [Thumbs first: a bigger Fly button and real distance from Poop](T-130-bigger-fly-button.md) | ui-ux | 2 | 1 | done |

## Web boot follow-up — double loading screen (2026-10-20)

A friend's hosted-web report: "2 identical loading screens happening in close
proximity." Code-read confirmed — T-129's Fly press paints the title's
"warming up the city" note AND fades the shell's identical loader (same navy,
same words) in over it one frame later. Presentation-only; direct loop per
the T-116 precedent.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-131 | [One warming screen: the web handoff lets the shell's loader do the talking](T-131-web-double-loading.md) | platform | 2 | 1 | done (Gate 3 pending) |

## Agent play tooling — owner ask (2026-10-22)

Agent decision latency vs. realtime game speed is the bottleneck on precision
agent play (lining up dives, staging screenshots). Fix: a pilot opt-in
`--time-scale` flag — slow the simulation via `Engine.time_scale`, never the
render, default 1.0 so every launch path and gate is untouched. Default-off
debug tooling; direct-loop eligible per the T-116 precedent.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-132 | [Slow-mo for agent play: a pilot `--time-scale` flag that slows the world, not the frames](T-132-agent-time-scale.md) | tooling | 3 | 1 | done (Gate 3 pending) |

## Agent play tooling — frame step (owner ask 2026-10-27)

Mid-playtest the owner steered: even at T-132's 0.1× the game is too fast to
aim in — make it frame by frame, advancing only when the agent is ready. The
pilot channel gained pause/step/resume commands plus deferred presses (input
queued while frozen fires on the first running tick), making agent play
turn-based. Proven the same day by an agent run that WON the game (favor 100,
17 car splats, the T-115 victory screen). The economy observation that the
parked-visitor-car fountain may be too easy is an open IDEAS.md B-6 question,
not a defect.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-140 | [Frame-step agent play: pilot pause/step/resume + deferred presses](T-140-pilot-frame-step.md) | tooling | 4 | 1 | done |

## Feel — slower bird, bigger city (owner pick 2026-10-22)

[B-20](../IDEAS.md) forked three ways (cap-only / quartet / full ×0.8); the
owner picked **tine (b)**: scale the coupled speed quartet down together and
leave the turn rates alone — the only tine that buys easier aiming AND tighter
circles at once. Route: pipeline per the T-117 rule (this un-turns the T-117
dial, so its bars re-derive).

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-133 | [Slower bird, bigger city: the speed quartet ×0.8, turn rates untouched](T-133-slower-bird.md) | flight-control | 3 | 2 | done |

## City identity — parks & districts (owner direction 2026-10-23)

Owner pick: one park per district, then give each district a real theme —
campus / main-street / tailgate / residential (the fourth theme
owner-picked), dressing plus one signature silhouette per quadrant, themed
parks included. Two serial tickets: T-135 pins the parks first; T-136 themes
on top and forge-routes first (reference photos — every theme and signature
has a clear real-world counterpart). The quadrant↔theme mapping and the
signature-prop fork are T-136 owner picks at forge sign-off. Follow-up
(2026-10-24, forks picked same day): after a share the elder relocates to a
different district's bench, walking there — T-137, waits behind both.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-135 | [One park per district: pin the park roll to four mirrored blocks](T-135-one-park-per-district.md) | worldbuilding | 4 | 3 | done |
| T-136 | [District theming: four dressed quadrants, one signature silhouette each](T-136-district-theming.md) | worldbuilding | 4 | 3 | done |
| T-137 | [The grandpa shuffle: elders relocate after a share, walking there themselves](T-137-elder-migration.md) | worldbuilding | 3 | 2 | done |

## People rig — owner ask (2026-10-26)

Post-T-137 the elders' baked pose-swap figures read as a different people
model next to the tourists, and the owner dictated the fix: all humans on
one model, all rigged reasonably, walking at least sort of realistically,
sized appropriately against the furniture. Discovery in the ticket: NO human
is rigged at runtime today — T-124 shipped everyone as static pose bakes
(`animation/import=false`); the pack's live 53-joint rig and animation
library have been thrown away at import ever since. T-138 turns the rig on
for every human, retires the bake tool's people half, grows everyone to
adult scale against the furniture (capsule and the splat-read pins grow with
it), and keeps the T-078 trust-arm and T-137 migration contracts passing
UNTOUCHED as the tripwire. Pipeline per the T-124 precedent.

| ID | Ticket | Category | Value | Risk | Status |
| -- | ------ | -------- | ----- | ---- | ------ |
| T-138 | [One people rig: every human on the live Quaternius skeleton — real walks, sits, adult scale](T-138-one-people-rig.md) | visual-design | 4 | 3 | done |
| T-139 | [Fix the elder's giant far arm: the import split baked the skinned arm's vertices ×100](T-139-arm-mesh-space-fix.md) | visual-design | 5 | 2 | done |
| T-141 | [Fix the seated elder: hips buried in the bench, hunch fold, floating hair](T-141-elder-seated-pose.md) | visual-design | 4 | 2 | done |
| T-142 | [The café sitters wear the one people model: seated-pose bakes replace the box crowd](T-142-cafe-sitters-new-model.md) | visual-design | 4 | 2 | done |
| T-143 | [The stop signs read red: give the red face real relief over the border](T-143-stop-sign-red-face.md) | visual-design | 4 | 1 | done |
| T-144 | [The elders keep their hands down: retire the T-078 trust arm](T-144-retire-the-elder-trust-arm.md) | gameplay | 3 | 2 | done |
| T-145 | [Head props hug the skull: the elder's hair (and the tourist cap) still read as floating planks](T-145-head-props-hug-the-skull.md) | visual-design | 3 | 1 | done |
| T-146 | [The elder sits IN the bench: thighs rest on the seat, no more clipping](T-146-elder-sits-in-the-bench.md) | visual-design | 4 | 1 | done |

## Suggested build order

*(Historical — the M1 sequencing note below predates the sweep and M2; every
ticket through T-116 is done or superseded. Phase status lives in
[`../ROADMAP.md`](../ROADMAP.md).)*

T-001 (feel) and T-004 (world) are independent — run them in parallel. T-002 follows
T-001. T-003 unlocks the ground loop that T-005 needs. T-006 unlocks the target
tickets T-007/T-008, which unlock T-009. T-010 ties the loop together. T-011, T-012
and T-013 are polish that can land any time after their dependencies.

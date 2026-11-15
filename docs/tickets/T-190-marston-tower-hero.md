# T-190 — Ames R3 · Marston Water Tower: the 51.2 m white beacon

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-177
- **Refs:** `landmarks/LANDMARKS.md` (51.2 m; "first elevated steel
  water tank west of the Mississippi" — verified) · `MODELING-SPECS.md`
  §1 (white painted steel + ISU seal medallion — photo-corrected from
  the dossier's "dark tank") · `images/campus/09,10,11,12` (legs,
  seal, full, on-lawn scale)

## What

The tallest object on campus (taller than the campanile) and the
flight beacon of the whole ring:

- White painted-steel tank on the four lattice legs, conical cap, the
  ISU-seal medallion on the tank face (geometry hint of the seal —
  the wordmark question does NOT arise: the seal shape renders as the
  photo's medallion silhouette; any text glyph defers to R4's legal
  pass).
- Swaps the T-175 slot; the beacon role in navigation stays (tallest
  visible point NE of the stadium axis).

## Why

Fidelity item F-03's sibling correction (white, not dark) and the
single best wayfinding landmark for players learning the map.

## Acceptance criteria

- [x] Hero swaps slot 1:1; 51.2 m ±2 m; legs/tank/cap proportions vs
      photo 11 (full-height)
- [x] *(Gate 1b)* `marston_hero_dims` + palette pin (white steel band)
- [x] Screenshot set vs the four refs
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

## Round record (agent pass, 2026-11-15)

**How it landed.** The T-186 hero law carried to the lollipop, all runtime
builds in `scripts/ames_world.gd` (a new `## T-190 the Marston Water Tower
hero` section; pure bake-derived geometry, zero RNG of any stream — a rebuild
reproduces every transform byte-identically). `way/861201396` already rides
the bake manifest's `heroes` list, so the bake is UNTOUCHED (no re-bake, no
manifest edit — the T-189 convention) and the hero supersedes the slot's six
placeholder parts (four legs + tank + cap — chunk (−1,−2)'s whole gray
placeholder family WAS the tower) through `_row_superseded_placeholder`, the
T-186/T-188/T-189 law: the placeholder render MM, the slot colliders, the
ground record and the roof spots all skip the id; chunk (−1,−2)'s gray
placeholder MM legitimately vanishes (the campanile-chunk precedent) and the
superseded authored bbox massing retires from the massing families unchanged.

The build (`_build_marston_hero`, dispatched from `_build_chunk` in its own
chunk pass) hangs its own shapes on chunk (−1,−2)'s layer-1 `Placeholders`
body (the 1:1 collision class — the T-186 law), files its own true ground
tops, hosts its own roof crumb at the cone tip (byte-identical to the
bake-derived cap-part pin this swap retires), and retains its part record
(`marston_hero_parts`, 62 parts; the headless-visibility law). The trestle
rides a rotated-box MultiMesh — the schedule carries an UNSCALED basis + size
per box, so the render, the collision shapes and the record's world AABBs
(one helper, `_marston_box_aabb`) all derive one geometry:

- **The six splayed legs** (photo 11's flare): hexagonal trestle, base offset
  6.725 (the OSM bbox's own 14.0 m base spread, ± half leg), top offset 2.95
  (just inside the balcony ring), 0.55 m angle sections leaning 5.9° —
  `MARSTON_LEG_TOP` 36.0 = the slot stack's own span, **70.3% of the total**
  (photo 11's trestle fraction). Each leg collides (one rotated box shape) and
  carries a 0.9 m foot pad whose outer face aligns with the leg's own (the
  footing reads proud of the leg without widening the base spread).
- **The lattice** (photo-correct "flared lattice legs with ring bracing",
  MODELING-SPECS §1): dark ring-brace chords at 9 / 18 / 27 m (the level
  radii lerped down the flare) and X bracing in the two lower bays
  (0..9, 9..18) — 18 chords + 24 diagonals, visual-only (thin lattice; the
  legs are the collision structure, the T-186 open-arcade law).
- **The riser pipe** dead center (0.7 m dia × 36, photo 12's fat gray
  column), colliding.
- **The round families** (named cylinder meshes, the Beardshear dome's taper
  path): the bowl hang (33.2→36.0, the photo-11 under-balcony bulge, the
  §1.4 tank-shade row #D8D8D4), the balcony walkway ring (r 3.95,
  35.55→36.05 — the legs close INTO it, photo 11), the tank drum EXACTLY the
  survey's 7.3 × 12.2 cylinder (36→48.2, LANDMARKS C2 — the slot stack's own
  span, kept), the top cornice lip (r 3.95, flush at 48.2), and the conical
  cap (base r 3.55 inside the lip, truncated at r 0.22) closing at **51.2 —
  the survey's settled total, pinned exact** (the AC ±2 band).
- **The ISU-seal medallion** on the tank's EAST (campus-facing) face at
  y 42.8: a dark ring (r 1.5) + proud disc (r 1.15) turned onto the +X axis —
  the ticket's GEOMETRY HINT: the seal SHAPE renders as the photo's medallion
  silhouette; no text glyph (the wordmark question does not arise — R4's
  legal pass owns any text).
- **Ground record**: the balcony ring answers 36.05 (the trestle's walkable
  crown), the tank top answers 48.2 (the survey answer kept), the plate
  answers 0.0 between the legs (the trestle is open) — and the superseded
  cap square's 51.2 walkable answer is RETIRED (the cone tip files nothing;
  nobody stands on a point).

**The palette** (MODELING-SPECS §1.4's rows, re-derived verbatim by the
gate): the white steel pinned — tank #EDEDEA (F-03's correction: WHITE
painted steel, NOT the dossier's dark tank/pin-cushion), tank shade #D8D8D4
(the bowl's curved read), lattice legs #C9C9C4; the brace + medallion bands
carry NO survey hex (the photos' dark lattice channels and the seal's dark
silhouette) and are held by darkness laws (luminance ≤ 0.45; the medallion
also ≥ 0.25 dark against the white tank — the campanile `hand` / row
`window` precedent).

**Deviations, honestly:**

- **The leg count**: the photos resolve 5–6 legs through the lattice (the
  closeups interleave legs, braces and the riser); the hero pins SIX in a
  regular hexagon — the count the full-height photo-11 silhouette supports.
  No authoritative source states the trestle's leg count in the survey set.
- **The base spread's z**: the hexagon's z span measures 12.4 vs the OSM
  polygon's 14.0 × 13.9 bbox — the polygon's z reads the footing apron trace,
  the six-leg hexagon is the structure; the x (14.0, the bbox's long axis)
  pins exactly. The gate pins the record AABB 14.0 × 12.4 ±0.5 as this
  build's own literal.
- **The medallion's cardinal**: the survey pins no face for the seal; photos
  10/12 read it from Marston Hall and the lawn — the EAST (campus-facing)
  face, where players approaching from the quad see it.
- **The balcony/cornice radii are photo-derived estimates** (r 3.95): the
  survey pins only the tank's 7.3 dia and the 51.2 total; the walkway and
  lip widths read off photos 11/12.
- **The on-lawn vantage**: the bake's own 119 × 36 m massing
  (`way/158023224`, an authored OSM building) stands SE of the tower and
  blocks photo 12's open-lawn vantage from the ground; the on-lawn scale
  read rides the grounded under-trestle shot (foot pads + legs looming over
  the pigeon) instead, and the owner pass re-shoots from the west lawn in
  T-196.
- **The walkability change above** (51.2 → 48.2 at the tank footprint) is a
  deliberate behavior change carried by the row, not a regression: the
  placeholder's 5.2² cap square answering 51.2 was the gray box's fiction
  (the cone tip is a point).

**Gate ledger.** Gate 1: `--import` exit 0 (only the accepted godot_mcp
"resources still in use" line — `--verbose` entries all
`res://addons/godot_mcp/...`; the addon copied into this fresh worktree per
VERIFICATION's tooling notice), boot `--quit-after 120` exit 0 with ZERO
error lines. The `--check-only --script res://scripts/ames_world.gd` leg
FAILS — `Identifier not found: Sfx/Game` — VERIFIED PRE-EXISTING:
byte-identical failure on the untouched main checkout (run 2026-11-15);
check-only cannot resolve autoload identifiers in this setup (the T-189
record's same note); script validity is proven by the boot leg and the
suite, which compile the whole project. Gate 1b: full suite **145 PASS /
0 FAIL**, exit 0 (`--fixed-fps 60` headless; the landed tree) — the new row
green (`marston_hero_dims`) and every prior row green including
`campus_row_heroes`, `mu_parks_heroes` and `ames_world_render_budget` with
the re-derived expectation (−6 more placeholder parts; measured 16,570
instances = 16,576 − 6 / 400 mm nodes / draws 310 cruise + 31 hover, all
under the budgets — the hero MM family lives OUTSIDE the bake-derived
metric, the corner-dress law). **Red-checks** (the pins bite):
`MARSTON_TOTAL` 51.2 → 50.7 FAILed the row naming exactly the right arms —
the top ("50.70 != the survey's settled 51.2"), the cone-family matcher, the
tip plane ray ("50.70 != the survey 51.2") and the roof crumb ("no roof
crumb at the cone tip (−50.83, 51.26, −467.96)") — then reverted and the
suite ran green again (145/0). Two landing iterations fired live before the
green run: the rotated-basis double-scale (the record AABB read
146.6 × 127.1, top 669.57 — the AABB helper re-applied the size to an
already-scaled basis; the schedule now carries the unscaled basis) and the
foot-pad overhang (the record AABB 14.5 × 12.7 vs the 14.0 pin — the pads
re-centered onto the legs' outer face). Gate 2: autoplay exit 0,
`AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true t=103.0
… eaten=7 splats=26 tourists=24 … restart=true`. Gate 3: the screenshot set
below; the owner's eyes-on stays T-196's postcard flight per the ring plan.
Status stays `doing` — the flip to done waits for the reviewer's sign-off
(the T-185 convention). ACCEPTED — reviewer sign-off on the landed tree
2026-11-15; the ticket flips done on that sign-off (the T-185 convention).

## Screenshots (agent pass, 2026-11-15)

Session `t190mw` — hidden window per T-170, hunger locked via the T-167 dev
verb, traffic frozen via the T-168 verb, poses via T-168 teleports
(pack-local coords, ack-confirmed; the post-teleport sink fought the staging
exactly as T-189 recorded — the airborne shots were taken off the frame
stream within ~0.5 s of the confirmed-airborne poll, the grounded shots
after the settle). Captures untracked in `.captures/session_t190mw/`.
Side-by-side reads against the survey photos cited per row.

| Shot | Pose | Reads | Survey photo |
|---|---|---|---|
| `marston_full.png` | 106 m SW-W of the tower at 55 m, yaw −110 (perched on a west-campus roof) | the full-height silhouette: the WHITE tank (cornice lip + conical cap above) on the dark splayed lattice, taller than everything around it — the photo-11 read | `images/campus/11` (full-height) |
| `marston_legs.png` | 44 m SE of the tower at 30 m, yaw 62 | the legs closeup: the flared six-leg trestle, the dark ring braces, the X bracing, the riser — Marston Hall behind | `images/campus/09` (legs closeup) |
| `marston_medallion.png` | 113 m E of the tower at 46 m, yaw 86 | the tank drum on the trestle with the DARK SEAL MEDALLION on the east face, the cornice lip + cone above — the photo-09/10 tank read | `images/campus/09,10` (seal, over-hall) |
| `marston_lawn.png` | GROUNDED under the trestle (the sink settled at the base), lawn-level camera | the on-lawn SCALE read: the foot pads + splayed legs looming over the pigeon, the lattice shadows on the grass — photo 12's scale from inside the trestle (the SE massing blocks photo 12's exact vantage; the owner pass re-shoots from the west lawn in T-196) | `images/campus/12` (on-lawn scale) |
| `marston_air.png` | 391 m E over the campanile lawn at 85 m, yaw 66 | the BEACON read: the white drum standing over west campus past the lawn's west row — the tallest point on the skyline, the wayfinding landmark | `images/campus/10` (over-campus context) + LANDMARKS §5 item 6 |
| `marston_west.png` | staging attempt, kept for the log (the west-lawn vantage spawned against a massing; superseded by the under-trestle read) | — | — |

## Tuned values (as landed)

See the round record — every value is a named const in the
`## T-190 the Marston Water Tower hero` section of `scripts/ames_world.gd`
and pinned by the `marston_hero_dims` row: total 51.2 exact (the AC ±2
band); tank 7.3 dia × 12.2 (36.0→48.2, the slot stack's own); legs top
36.0, base offset 6.725, top offset 2.95, sections 0.55; balcony r 3.95 top
36.05; bowl bottom 33.2; cornice r 3.95 flush 48.2; cone base r 3.55 tip r
0.22 closing 51.2; medallion ring r 1.5 / disc r 1.15 at y 42.8, east face
+3.70/+3.75 proud; brace levels 9/18/27; record AABB 14.0 × 12.4 (±0.5);
palette #EDEDEA / #D8D8D4 / #C9C9C4 pinned, brace + medallion darkness-lawed.

## Decisions & forks

- The bake is UNTOUCHED (no re-bake, no manifest edit): the id already rides
  the bake's `heroes` list, so only the runtime placeholder supersession was
  needed. A future re-bake changes nothing for this ticket.
- The rotated-box schedule (`band, basis, p, s, collide` with an UNSCALED
  basis) is the first box schedule in the world script that leans: the
  campanile/row/MU-Parks schedules are axis-aligned. A future hero needing
  lean (the R4 stadium's light towers?) reuses `_marston_box_aabb` +
  `_build_marston_hero`'s render/collision/record split.
- The seal's TEXT (the wordmark around the medallion's ring) defers to R4's
  legal pass per the ticket's own scope line — the geometry hint carries the
  silhouette only.
- The beacon navigation ROLE (T-175's ranking stays) is untouched: the crumb
  at the tip is byte-identical to the bake-derived pin, so no nav or crumb
  consumer sees a change.

# T-194 — Ames R3 · rail corridor: the depot, the crossings, the daily coal drag

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-177 (corridor flats exist), T-180 (crossing set)
- **Refs:** `MODELING-SPECS.md` §1 rail-corridor · `census` §5 (9
  at-grade crossings; 4 vehicular downtown: Grand, Clark, Kellogg,
  Duff) · `images/rail/` (10 refs: depot, coal drag, wigwag, elevator
  styles) · ground truth: NO Amtrak — nearest stop Osceola (depot is a
  preserved C&NW building, no passenger signage) · daily train =
  yellow SD70ACe coal drags (Big Boy = 2019 special, do NOT model as
  daily)

## What

The motion landmark, honest to the verified facts:

- **The train**: a SD70ACe-led coal drag (yellow/gray livery) as a
  loop-timer landmark — it runs the main line on a simple schedule
  (frequency from the refs' "daily traffic" read; a timer, not a
  simulation). The game's 9 crossings are route facts; the train does
  NOT gate traffic (no event system — the fence; cars just cross, the
  train is dressing that moves).
- **The depot**: the brick + red-tile hip-roof building at its real
  spot — NO Amtrak signage (corrected fact), blank-preserved-depot
  read.
- **Crossing hardware**: crossbucks at the 9 (the T-134-style sign
  discipline; the wigwag is a museum piece — optional flavor at ONE
  crossing if cheap).
- Corridor texture polish: ballast, tie hint, fence line (photo 06's
  right-of-way cross-section).

## Why

The main line is the town's spine between campus and downtown and the
census's designated "motion landmark" — one train asset, reused across
all 9 crossings, makes the whole map feel alive for one asset's cost.

## Acceptance criteria

- [x] Train: correct livery, loop schedule pinned (frequency + speed
      recorded), no traffic gating (cars cross regardless — probe)
- [x] Depot at true position, no Amtrak marks; crossbucks at all 9
- [x] *(Gate 1b)* `rail_dressing_pins`: depot pos, crossing set = 9,
      train schedule constants
- [x] Screenshot set vs `images/rail/` refs
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

Gate results on the landed tree (2026-11-16): Gate 1 — `--import`
exit 0 (only the accepted godot_mcp "33 resources still in use at
exit" line) + `--quit-after 120` exit 0, zero error lines; Gate 1b —
**149 PASS / 0 FAIL** including the new `rail_dressing_pins` row (the
`ames_world_render_budget` bake-derived expectation re-derived in-row:
−3 depot placeholder parts — the T-186 law); the pre-existing
`SitterTorso` cafe-visuals ERROR lines reproduce on the unmodified
main checkout (baseline run 148 PASS + the same lines — not this
ticket's regression); Gate 2 — `AUTOPLAY DONE ok=true world=ames …
restart=true poses=DIVE,FLAP,GLIDE,PECK,STAND,WADDLE` at fps=139.
ACCEPTED — reviewer sign-off 2026-11-16, status done in the ticket +
the index row; the owner judgement (does the drag read as THE coal
drag, does the depot read as the preserved depot) rides the T-196
R3-cutover postcard flight per the ring plan.

## Build record (the landed tree, 2026-11-16)

- **The depot** (`scripts/ames_world.gd`, the T-194 section +
  `_build_depot_hero`): swaps the T-175 placeholder stack (wall/roof/
  canopy — chunk (10,−1)) 1:1 on the T-190 law for bake hero
  `way/260524827` (the 1906 C&NW depot, today's "Main Street
  Station"). The wall + canopy keep the slot's own spans exactly
  (92.8 × 7.0 × 19.9 wall top 7.0; canopy slab 85.376 × 0.8 × 4.0,
  top 4.0); the hip roof re-reads the slot's own envelope (88.16 ×
  16.915 base, ridge top 9.5) as one eave→ridge loft (the Farm House
  path, both axes shrink — every face tile); the canopy moves to the
  CORRECTED TRACK FACE (z −173.04, 11.95 m south of the wall center):
  the pack's own geometry puts the Clinton main south of the footprint
  there (route z −159..−163 vs the wall's −175..−195), so the platform
  faces the rails — the bake's north-face canopy slot is retired and
  that ground answers the plate again. Photo-08 dressing: the two
  arched dormers on the track-facing slope (brick slabs + cream arch
  cylinders, apex ~10.2), the brick chimney + cap north of the ridge
  (+14 east), the canopy's 9 steel posts + 9 green diagonal braces
  (#3E7A5A) + the green fascia line. Collision: wall + canopy slab +
  chimney + the hip frustum (layer-1 `world`, riding the chunk body);
  walk seam: the ridge files 9.5 through a record-only strip (the
  sloped loft files no AABB lie), wall 7.0, canopy 4.0; the roof crumb
  rides the ridge. **NO Amtrak marks**: the band set is closed at six
  dressing bands (brick #9A4030 / tile #B04A34 / trim #E5DFCE / green
  #3E7A5A / steel / cap dark) — no sign band exists for the preserved
  depot's blank read (the gate asserts the closure).
- **The coal drag** (`scripts/ames_train.gd` + `scenes/ames_train.tscn`,
  staged by `_build_rail_corridor`): ONE AmesTrain under the world's
  `RailCorridor/` root. The route = the greedy nearest-endpoint chain
  over the pack's 26 Clinton-main ways — ONE track, 13 ways consumed
  end-to-end, west (−724.6, −1404.4) → east (3297.5, −217.3),
  **4272.6 m**, extended off-map both ends (run-out = consist length +
  60 m) so the consist enters and exits whole (**4825.4 m** total).
  The consist: SD70ACe loco (22.4 × 3.15 × 4.9 — dark frame/roof,
  weathered-yellow #D9A02C body, dark cab-glass band, the winged
  shield as painted geometry per flank — white #E8E6E0 underlay +
  blue #1C3F94 field) + 12 Bethgon-style hoppers (15.9 × 3.4, #6B655C,
  dark coal loads) = **32 boxes** in one unit-box MultiMesh, every box
  re-anchored onto its own route arc each physics tick (the consist
  bends through the curves). **The loop schedule** (the pinned
  constants): period **360.0 s** (the refs' daily-traffic compression —
  a drag every 6 wall-minutes; a typical run sees one to three passes),
  speed **31.3 m/s** (the line's tagged 70-mph class), first pass at
  **25.0 s** after the build; the traverse ≈ 147.3 s, the between-pass
  gap hides the node. **The scope guard is structural**: no physics
  body anywhere in the rig (collision objects would gate a crossing
  car), no event system, no signals into the traffic graph — the train
  is dressing that moves and can gate nothing; `live_state()` is the
  one readout seam (the T-169 call verb's ordinary one-hop getter) the
  staging session and the gate use.
- **The crossbucks** (`_build_crossbucks`): two assemblies per
  at-grade crossing (**9 pins / 18 posts / 36 arms**), each set back
  the matched street's half-width + 2.5 m along the re-derived road
  axis (the unnamed yard lead falls back to the nearest street segment
  of any class — the pack's street graph carries no service ways for
  it); the T-134 discipline: dark post 3.0 m + the white X (two arms
  at ±45° in the plane facing along the road), visual-only.
- **The wigwag** (`_build_wigwag`): the ticket's optional flavor at
  ONE crossing — the museum piece at Duff (the busiest, census §5):
  pole + motor case + over-road arm + white plate + the red target
  disc (mesh), static (the swing is museum hardware, not live).
- **The fence line** (`_build_fence`, photo 06's right-of-way
  cross-section): posts at the **18 m** pitch on BOTH sides of the
  route (left 5.0 / right 9.5 off the chained track — the double-track
  midline sits ~2.1 right of it; both fences hold ~7.25 off it and
  clear both ballast strips), two strand lines at 0.55/1.05 between
  consecutive posts, **gapped at the 9 at-grade crossings** (nothing
  within 18 m — the ballast's own road-gap law; posts 458, wires 896,
  spans 17.499..18.494 m — the lines swing wider than the route over
  the downtown bend). Visual-only; ballast + tie stripes already ride
  the bake (T-174).
- **Machine proof**: the `rail_dressing_pins` Gate 1b row (see
  VERIFICATION.md) — the data layer (the 9-crossing set, the depot
  slot walk, the route re-proven vertex-by-vertex against the pack's
  ways), the drag (32-box schedule, the livery literals + hue laws,
  the schedule pins through the pure state machine + the live clock
  advance, the no-body scope guard), the depot (the swap, the dims,
  the walk seam, the no-Amtrak band closure, the live loft/arch
  albedos, the collision seams), the crossbuck siting + 45° X arms,
  the fence pitch/gap law, the render-budget −3 re-pin, and the
  **no-traffic-gating probe**: the consist held straddling a drag
  crossing while a REAL staged mover drives its graph lane through it
  (min distance < 12 m, the signed side flips). The suite:
  **149 PASS / 0 FAIL**.

## Screenshot ledger (agent visual pass, 2026-11-16)

Pilot sessions `.captures/session_t194vis/` + `.captures/session_t194west/`
(hidden windows per T-170, OS `shot` grabs, hunger locked via the
T-167 verb; the drag timed through its own loop schedule via the
`live_state` readout seam):

- `shot1_depot_tracks.png` — the depot from across the tracks, the
  photo-08 composition: the long brick body, the red hip roof with
  both dormer arch bumps reading, the platform canopy's green fascia +
  post line on the track face, the ballast + fence in the foreground.
- `shot4_depot_air.png` — the depot from the SE air (the from-the-air
  recognition read): the roof envelope, the dormer pair, the chimney,
  the Clark Ave crossing + its crossbucks right of the depot.
- `shot3f_crossbuck_closeup.png` — a crossbuck assembly filling the
  frame at Kellogg (the photo-09 composition minus the wigwag — the
  wigwag stands at Duff): the white X on its post at the road edge,
  the crossing ahead.
- `shot5_row_crosssection.png` — the right-of-way cross-section down
  the line (photo 06's read): the double ballast strips + tie stripes,
  both fence lines flanking, the green either side.
- `duff_1.png` — the coal drag's hopper chain crossing Duff under the
  crossbuck (the photo-07 moment; the consist reads its massing +
  dark-gray hoppers at this sun angle).
- `pass_duff_13.png` — the yellow SD70ACe nose approaching down the
  double-track main toward Duff (the photo-03/07 head-on corridor
  read; the weathered yellow reads at distance).

Honest deviations, recorded: the engine's midday sun grades every
livery flat/grayer than the photos (the machine gate pins the exact
albedos; the shot set records composition + massing, not the photo
grade — the T-186/T-193 precedent); the drag shots catch the consist
head-on/quarter through the crossing rather than photo-07's full side
profile (the schedule-window capture from a hidden pilot session; the
side-profile read rides the T-196 owner flight); the depot's window
trim is massing-level (R4-adjacent detail, skipped at L3).

## Tuned values

Depot: slot spans kept (wall 7.0 / hip top 9.5 on 88.16 × 16.915 /
canopy top 4.0) · canopy z −173.04 (the corrected track face) ·
dormers ±10.5 ×, arch r 1.8 apex ~10.2 · chimney +14.0/−1.5, top 12.6 ·
9 posts + 9 braces + green fascia · palette #9A4030 / #B04A34 /
#E5DFCE / #3E7A5A / steel 0.45 gray / cap dark. Drag: period 360.0 s ·
speed 31.3 m/s · first pass 25.0 s · consist 22.4 m loco + 12 ×
(15.9 + 1.2) hoppers = 227.6 m span · route 4272.6 m core, 4825.4 m
extended · palette #D9A02C / #E8E6E0 / #1C3F94 / #6B655C, dark frame
roof, coal dark. Crossbucks: setback half-width + 2.5 m, post 3.0 m,
arms 1.9 m at ±45°. Fence: pitch 18.0 m, offsets 5.0/9.5, strands
0.55/1.05, gap 18.0 m.

## Decisions & forks

A train-blocking EVENT (cars hold, bells ring) is deliberately out —
it's a gameplay system and needs its own owner-picked ticket.
Additionally forked here: the wigwag's swing is frozen static (the
museum-piece read; a live swing is dressing-fork material, argued
against the same line); the depot's canopy moved to the track face
(the bake slot's north-face guess contradicted the pack's own track
geometry — the T-189 "correct position" precedent, recorded above).

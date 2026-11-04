# T-163 — One seat-contact law: thighs, knees and shins clear every seat — the café stools and the elder bench

- **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 ·
  **Risk (1-5):** 2
- **Depends on:** T-146 (the thighs-are-the-contact-mass law — hips bone at
  seat + 0.04 — that this ticket re-applies to the stool pin) · T-142 (the
  baked sit meshes the café crowd renders, and the import pipeline a
  last-resort pose variant would extend)
- **Refs:** owner idea + screenshots (2026-11-03: a café sitter sunk into the
  stool; a bench elder's shins through the bench front face and the glute
  perched at the seat edge) · `scripts/cafe_spawner.gd:16-43,161-176,300-305`
  · `scripts/city.gd:1890-1901` (the bench recipe), `city.gd:1792,1811-1813`
  (the spot planes) · `scripts/elder.gd:60-76,540-548,595-613` ·
  `tests/sim_test.gd:8842-8938` (the two sit scenarios) ·
  `tools/probe_sit_geometry.gd` (the probe this extends) · render evidence
  opened this session: `.captures/t146_sit/after_contact_zoom.png` (the bench
  state the owner re-flags) and `.captures/t142_cafe/cafe_sitters_closeup.png`
  + `cafefix2_midshot.png` (the stool crowd) · a throwaway contact probe run
  this session in the `probe_sit_geometry` family (numbers below; deleted
  after recording, the T-162 precedent)

## What

Two crowds sit on two seat shapes, and both seatings clip. T-146 re-derived
the elder's bench sink and left the café spawner on the pre-T-146 derivation;
this ticket makes ONE law of it: the seated figure's THIGHS rest on the seat
top, its KNEES sit at the seat's front edge, and its SHINS clear the seat's
front face — on both surfaces.

**The current pins (code, read this session).**

- Café: `cafe_spawner.gd:33-35` pins `SIT_ROOT_Y = SITTER_SEAT_TOP -
  SIT_HIPS_Y` = 0.45 − 0.5179 = **−0.0679** — the hips bone exactly AT the
  stool top, the pre-T-146 family T-146 superseded (the bone belongs at
  seat + 0.04, `elder.gd:64-76`). The stool is the `sitter_seat` BoxMesh
  0.36 × 0.06 × 0.36 at +0.42 (`cafe_spawner.gd:300-305`): top face 0.45,
  slab 0.39–0.45, plan ±0.18; the spot plane is the pavement
  (`city.gd:1792`). The feet comment (`cafe_spawner.gd:30-31`, "feet … land
  ~0.02 above the pavement") reads the FOOT BONE (0.0873 above the clip
  floor), not the visible sole.
- Bench: the seat wood is a 1.8 × 0.08 × 0.5 box at +0.5 → wood top **0.54**,
  slab 0.46–0.54; the collider tops at 0.55; the elder spot / bread-spot
  plane is slab + **0.60** (`city.gd:1893-1898`, `1811-1813`, `1457-1459`).
  The elder root lands byte-exact on the spot (`elder.gd:546`); the rig
  rides `SEAT_SINK` −0.465 and `HUNCH_SEATED` 0.04 (`elder.gd:76,62`), so
  the rig root sits 0.135 above the slab. There is NO fore-aft dial — the
  seated figure sits at the spot origin, the bench slab's center.

**Measured this session** (throwaway probe: the T-142 `SitBake` mesh faces
binned per 0.05 m of z, plus the live-clip bones, rig at identity, adult
0.982; the bench numbers with the exact engine composite — hunch
`Basis(RIGHT, 0.04)` then +0.135 — applied):

- The pose (root space): DEF-hips +0.5179 at z +0.3255; thigh bones +0.5330
  at z +0.2749; shin bones ≈ +0.505 at z ≈ −0.11; foot bones +0.0873 at
  z −0.1248. The legs mesh: soles −0.013, toes to z −0.362, and a flat
  SITTING LINE (butt + thigh underside) at +0.434..+0.454 across
  z 0.00..0.35 — **0.06–0.08 below the hips bone**. The pose's z-span is
  **0.712 m**.
- Café (pin −0.0679): the sitting line over the stool plan is 0.366..0.377 —
  **0.073..0.084 below the 0.45 top**: the whole 6 cm stool slab lies inside
  the thigh volume (the owner reads ~4 cm of sink at the silhouette; the
  deepest line is deeper). The glute band (z +0.27..+0.35) hangs mostly PAST
  the stool's outer edge (+0.18). The soles sit **0.081 under the pavement**
  (the +0.019 the comment quotes is the bone).
- Café (at the mandated +0.04 pin, root −0.0279): the sitting line lands
  0.406..0.417 — still 0.033..0.044 below the top; soles −0.041; bone feet
  +0.059. A full-contact pin ≈ bone seat + 0.078 (root +0.010) puts the
  sitting line ON 0.45, the soles at −0.003, the bone feet at +0.097.
- Bench (current composite): the sitting line over the wood is
  **0.561..0.608** — straddling the 0.60 plane, 0.021..0.068 ABOVE the wood
  top (the T-146 accepted contact read ✓ — the plane/wood split hides the
  pose's sitting-line offset; the stool has no such split, which is why the
  same pose slices the stool). The SHINS descend at z ≈ −0.07..−0.15 —
  **0.10..0.18 behind the front-edge plane (−0.25)** — so they cross the
  slab band 0.46..0.54 INSIDE the seat footprint: through the wood, the
  owner's "shins through the bench front face". The soles hang at
  +0.126..+0.142 (the bone at 0.222 is T-146's documented dangle). The
  glute band extends **0.02..0.10 past the seat edge** — the owner's
  "glute perched at the seat edge".

**No reference photos:** no research phase ran — the subject is
repo-internal seating geometry (a game-invented affordance with no very
clear real-world counterpart), so reference photos do not apply; the
criteria are concrete from the repo's own constants and the probe lines
below.

**Fix — probe first, then the dials, in this order:**

1. **Probe-first.** Extend `tools/probe_sit_geometry.gd` with a
   contact-lines section that measures, on BOTH surfaces, the three lines
   the law names: (a) **thigh-vs-seat-top** — the sitting line's min-y over
   the seat plan's z-band (feet/shin bins excluded) vs the seat top (stool
   0.45; bench wood 0.54); (b) **knee-vs-front-edge** — the shin bone
   origin's z vs the front-edge plane (stool ±0.18; bench ±0.25); (c)
   **shin-vs-front-face** — where the lower-leg line crosses the slab's
   y-band (stool 0.39..0.45; bench 0.46..0.54) vs that plane: inside the
   footprint = through the face. The landed values are recorded in this
   ticket and locked by the Gate 1b scenario.
2. **Café re-pin.** `SIT_ROOT_Y := SITTER_SEAT_TOP + 0.04 - SIT_HIPS_Y`
   (bone at stool + 0.04 — the T-146 family floor). The probe's thigh line
   adjudicates the landed value: this session's numbers predict +0.04 still
   buries the line 0.033–0.044 into the slab, so the pin dials up within
   the contact read (predicted full contact ≈ bone seat + 0.078) — never
   above bone seat + 0.08 (the T-146 hips family). Re-derive the feet
   comment for the landed pin in BOTH terms: the bone (0.0873 + root) AND
   the visible sole (−0.013 + root). If the shin line still intersects the
   stool slab after the re-pin — the geometry says it will; the stool plan
   (±0.18) contains the shin line at z −0.07..−0.15 at ANY height — add
   `SIT_SLIDE` (predicted 0.10–0.15 m): the sit_root instances slide along
   the figure's facing (`sitter_xf.translated_local(0, SIT_ROOT_Y,
   -SIT_SLIDE)`), the inert SITTER_SHAPE collider slides with them, the
   stool/table transforms stay. Slid, the knees land at the table edge
   under the 0.66–0.72 tabletop slab (air — the collider is invisible), the
   shins exit past the stool edge, the soles reach the pavement.
3. **Bench dials, in order.** (a) `SEAT_SLIDE` first (predicted
   0.15–0.22 m): a rig-visual fore-aft offset applied while
   SEATED/ARRIVING — `_visual.position.z`, eased to/from 0 exactly like the
   sink in `_animate` (`elder.gd:595-613`) — the ROOT stays byte-exact on
   the spot (the state machine, PresenceZone, crumb toss origin and the
   T-137 scenarios all keep their geometry). The direction: the ask's
   screenshot reads the mass perched too far forward → slide back; this
   session's bake measurement has the figure overhanging BOTH edges
   (z-span 0.712 vs the 0.50 seat depth) with the shins 0.10–0.18 behind
   the front-edge plane on the knee side — the clearing motion runs toward
   the figure's facing (the knees), i.e. back FROM the edge the mass
   overhangs. **The probe's three lines pick the sign and the magnitude;
   the owner's Gate 3 screenshot judges the read.** (b) Sink trim ONLY if
   the post-slide read unseats the thighs: trim `SEAT_SINK` within the
   T-146 hips band (bone seat + 0.00..0.08); the numbers predict no trim
   (the sitting line keeps its accepted 0.02–0.07-above-the-wood contact
   read — z-only slide).
4. **Last resort only:** if slide + trim cannot clear the shins (the probe
   says so), bake a bench-variant sit pose with forward-angled shins — as
   an imported clip variant (amending T-142's no-new-clip whitelist law IN
   THE SAME CHANGE-SET) or a runtime shin-chain pose patch on the live rig,
   implementer's choice; the elder plays live clips, so a café-style static
   bake alone cannot serve it.

**What this does NOT claim:** no furniture changes — the stool/bench
dimensions, the Props colliders and the 0.60 bread spots stay as-is,
including the bench's pre-existing 0.06 plane-vs-wood split (T-005-era city
geometry, a separate matter); the T-142 bake meshes are untouched unless
the last resort fires; the elder state machine (states, routes, trust,
share, migration) is untouched — the slide is rig-visual; `HUNCH_SEATED`
0.04 stays; no layout RNG, fingerprint or count changes; no input actions;
no new scenes; the tourists are not claimed.

## Why

The owner flagged both seats with screenshots on 2026-11-03: café sitters
sunk into their stools, and the bench elder's shins vanishing into the
bench with his weight perched on the seat edge. Sitters and elders are the
city's main close-range humans — the player walks and lands right next to
them, and a slab slicing through a thigh or a calf reads as broken
rigging, not as a person (Pillar 2: the city reacts, it does not wear its
rigging). T-146 already established the right derivation — the contact
mass is the THIGHS, the bone belongs at seat + 0.04 — and proved the
verify-with-screenshots loop; this ticket finishes the job by making that
one law hold on every seat shape, with the probe lines as the reusable
measurement for any future seat (a new bench depth, a taller stool) so the
next seat type is a measurement, not a fresh guess.

## Acceptance criteria

- [ ] *(Gate 1b)* new `sitters_clear_their_seats` (the
      `cafe_sitters_on_the_rig` mesh-probe family, `sim_test.gd:8890`):
      - café legs — from the spawner's `_mm_queues` sit transforms plus the
        harvested `sit_legs`/`sit_body` meshes, against the stool constants
        (top 0.45, slab 0.39..0.45, plan ±0.18): the thigh line within
        [top − 0.01, top + 0.05]; the shin line's slab-band crossing past
        the front-edge plane (ε 0.01); the soles ≥ −0.01;
      - bench legs — the SitBake mesh under the exact composite constants
        (plane 0.60, `SEAT_SINK`, `HUNCH_SEATED`, `SEAT_SLIDE`) against the
        bench constants (wood top 0.54, slab 0.46..0.54, edges ±0.25): the
        thigh line ≥ wood top − 0.01 and ≤ plane + 0.05; the shin line's
        slab-band crossing past −0.25 (ε 0.01); the deepest sitting-line
        vertex within the seat plan (≤ rear edge + 0.01 — the glute ON the
        seat);
      - value locks: the landed `SIT_ROOT_Y`, `SIT_SLIDE`, `SEAT_SLIDE`
        (and `SEAT_SINK` if trimmed).
- [ ] *(Gate 1b)* `elder_seats_on_the_bench` stays green with its lock set
      amended in the same change-set (the `SEAT_SLIDE` rig-z lock added;
      the hips band 0.00..0.08 re-verified — the slide is z-only);
      `cafe_sitters_on_the_rig` stays green UNCHANGED (its AABB bands are
      mesh-level and pin-insensitive by construction); the T-137 migration
      scenarios byte-green (the root placement is untouched); FULL suite
      0 failures (`godot --headless --fixed-fps 60 --path .`
      `res://tests/sim_test.tscn`).
- [ ] *(Gate 1)* `--import` and the 120-frame boot exit clean, zero ERROR
      lines.
- [ ] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`).
- [ ] *(Gate 3, screenshots)* pilot-harness captures into
      `.captures/t163_seats/`, eyes-on: (a) a café sitter reads seated ON
      the stool — thighs on the top, shins at/past the stool edge under the
      table, feet at the pavement; (b) a bench elder (plaza AND a park
      bench) reads seated IN the bench — shins descending in front of the
      front face, knees at the seat edge, glute on the seat; (c) the T-146
      contact read survives the slide (thighs/pelvis vs the bench seat, the
      accepted 2026-11-02 read not regressed).

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with the new
`sitters_clear_their_seats` registered in `_run_scenarios` (`sim_test.gd:244`
neighbors) and its row added to the Gate 1b table in `VERIFICATION.md`, the
`elder_seats_on_the_bench` row amended for the slide lock, and the
`cafe_sitters_on_the_rig` row re-worded for the landed pin — all in the same
change-set · Gate 2 autoplay · Gate 3 the three screenshot lines above.

**Red-before probe to record when landed:** with the current constants the
new scenario fails its café thigh leg (the sitting line 0.073–0.084 below
the stool top), its bench shin leg (the crossing 0.10–0.18 inside the
footprint) and its café sole leg (−0.081) — all three measured this session
against the shipped meshes and constants, so the red state is already
demonstrated, not predicted.

**Tuning latitude:** the landed `SIT_ROOT_Y` within [bone seat + 0.04, bone
seat + 0.08]; the slide magnitudes ±0.05 m and their sign, set by the probe
lines; the sink trim within the T-146 hips band, only on the Gate 3 read.
Everything else above is fixed. Record the landed values here (the T-134
"Tuned values" pattern).

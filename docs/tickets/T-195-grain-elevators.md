# T-195 — Ames R3 · grain elevators: the SE silo cluster

- **Status:** done · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-177
- **Refs:** `MODELING-SPECS.md` §1 rail-corridor (elevators) ·
  ground truth: heights UNKNOWABLE from public data → 30–40 m
  placeholder-truth styling, flagged · `images/rail/10,11,12` (Iowa
  style refs — NO photo of Ames's own cluster exists; CREDITS gap
  note) · census §3 (SE cluster, along the line)

## What

The agricultural skyline, styled honestly:

- The SE elevator cluster (concrete silo bank + headhouse + attached
  steel bins + leg tower) at 30–40 m heights — the documented
  placeholder-truth range; the styled read comes from the three Iowa
  reference photos (Hull / Jefferson / Batavia typologies).
- Swaps the T-175 massing; collision solid; a legit landmark for
  orientation SE of downtown.
- The in-ticket honesty note: "no photo of the actual Ames cluster
  exists under CC — styled from Iowa-generic refs at assumed heights"
  travels into the ticket body and any future R4 signage decision.

> **HONESTY NOTE (carries forward — into the world script's section
> header and any future R4 signage decision):** no photo of the actual
> Ames SE elevator cluster exists under CC — styled from Iowa-generic
> refs (Hull / Jefferson / Batavia, `images/rail/10,11,12`) at assumed
> 30–40 m heights (V-30 UNVERIFIED). NO operator name, logo or brand
> signage may be painted on it (nothing real is known to letter it;
> R4 text defers to the legal pass like every facade).

## Why

Iowa's skyline IS grain elevators; leaving Ames without them fails the
state read even if the specifics are unverifiable.

## Acceptance criteria

- [x] Cluster at data position; 30–40 m band; silo bank + headhouse +
    bins composition vs style refs
- [x] *(Gate 1b)* `elevator_cluster_dims` (band assertion, not exact
    dims — the honesty is the pin)
- [x] Screenshot vs `images/rail/12` (the closest typology ref)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

Gate results on the landed tree (2026-11-16): Gate 1 — `--import`
exit 0 (only the accepted godot_mcp "33 resources still in use at
exit" line) + `--quit-after 120` exit 0, zero error lines; Gate 1b —
**150 PASS / 0 FAIL** including the new `elevator_cluster_dims` row
(the `ames_world_render_budget` bake-derived expectation re-derived
in-row: −7 elevator placeholder parts — the T-186 law); the
pre-existing `SitHair`/`SitterTorso` cafe-visuals ERROR lines and the
pilot-harness `Parse JSON failed` lines reproduce on the unmodified
main checkout baseline (T-194's gate note — not this ticket's
regression); Gate 2 — `AUTOPLAY DONE ok=true world=ames …
restart=true poses=DIVE,FLAP,GLIDE,PECK,STAND,WADDLE` at fps=140.
The owner judgement (does the cluster read as THE grain elevator,
does it anchor the SE orientation read) rides the T-196 R3-cutover
postcard flight per the ring plan.
ACCEPTED — reviewer sign-off 2026-11-16, status done in the ticket +
the index row.

## Build record (the landed tree, 2026-11-16)

- **The SE cluster hero** (`scripts/ames_world.gd`, the T-195 section +
  `_build_elevator_hero`): swaps the T-175 placeholder massing (4 silo
  boxes 7 × 34 × 7 + the 10 × 38 × 10 headhouse + two 5 × 12 × 5 bins,
  chunk (13,−1)) 1:1 on the T-190 law — every slot span kept EXACTLY,
  the shapes re-read from the three Iowa-generic refs
  (`images/rail/10,11,12`): the silos round to Ø7 concrete cylinders
  under proud darker cap rims (rings at 33.3..34.0, the Hull photo's
  flat-top read), the headhouse keeps its box under a proud dark roof
  slab (10.3 × 0.8 × 10.3, top stays the slot's 38), the bins round to
  Ø5 galvanized cylinders (0..10.4) under cone roofs (10.4..12.0, the
  Batavia read), and the Batavia typology's LEG TOWER joins as
  hero-only geometry: a 4-post dark lattice (0.16 m square posts on a
  1.6 m lattice square at the 1.4 m standoff off the headhouse's east
  wall) rising to a meter under the headhouse top — ABOVE the bank
  line, so the mast reads in the skyline from the town side — with 5
  collars spread evenly over the lower leg and the crown distributor
  arm (0.22 × 0.3 × 8.0) at leg-top − 0.6 running alongside the wall.
  **The honesty note travels verbatim into the world script's section
  header** (and any future R4 signage decision): no photo of the
  actual Ames SE cluster exists under CC — styled from Iowa-generic
  refs at ASSUMED heights (the V-30 30–40 m UNVERIFIED range the
  slot's own spans already sit inside) — and NO operator name, logo or
  brand mark is painted anywhere: the palette band set is CLOSED at six
  dressing bands with no sign band (the gate asserts the closure).
- **Collision solid** (the ticket's AC): the big three families ride
  the chunk's placeholder body, same layer-1 `world` class — the 4
  silos and 2 bin walls as 8-gon convex cylinders, the 2 bin cones as
  tapered convexes, the headhouse as its box; the cap rims, roof slab
  and leg lattice stay visual-only dressing (the thin-member law — the
  T-194 fence/crossbuck precedent). Ground record: the slot's own
  seven walk answers re-filed byte-identically (the walk-parity law —
  the swap changes the dress, never the seam: silos answer 34,
  headhouse 38, bins 12). Roof crumb: none (the slot never carried
  one; the specced silo-cap perch is a future owner ticket — forked
  below).
- **Machine proof**: the `elevator_cluster_dims` Gate 1b row (see
  VERIFICATION.md) — the slot walk (7 parts, the bank's touching+2 m
  gap read, headhouse 8 m north / bins 8 m south of the bank line, the
  V-30 band on the slot's own spans), the swap arm (the gray stack
  retired to exactly its non-superseded remainder; Boxes = 12: the
  headhouse + roof slab + 10 leg members), the BAND assertion as the
  honesty pin (union top INSIDE 30..40 — deliberately never == the
  slot's dims), the keep-the-stack law per family, the composition
  (4/4/1/1/2/2 + the 4/5/1 leg schedule + the mast-visibility law:
  leg top > the bank line), the closed six-band palette at its
  literals + the warm/cool/dark laws + the cap-darker-than-walls
  luminance proof, the live seam rays (the Ø7 silo on the east vertex
  plane, the headhouse slot wall, the Ø5 bin, the 10.756 bin-cone
  frustum read, the leg lattice ray-clear), the walk-parity ground
  pins (34/38/12/12) and the no-crumb arm. The suite: **150 PASS /
  0 FAIL**.

## Screenshot ledger (agent visual pass, 2026-11-16)

Pilot session `.captures/session_t195vis2/` (hidden window per T-170,
OS `shot` grabs, hunger locked via the T-167 verb; teleports via the
T-168 staging verb; every shot on the landed tree):

- `shot1_side_south.png` — the south composition from 150 m (the
  rail/12 read): the pale silo bank with its darker cap rims, the two
  cone-roofed galvanized bins in front, the headhouse's tall slab +
  dark roof closing the north side behind the bank.
- `shot3_close_oblique.png` — the 80 m oblique: the full composition
  with the leg mast reading ABOVE the bank line between the headhouse
  gap (the raised-leg law's proof shot).
- `shot4_leg_close.png` — due east at 95 m: the leg tower's dark
  collars reading as the braced lattice line against the pale
  headhouse east wall (how a real leg reads), the bin cone at frame
  left, the bank's shadow to the ground.
- `shot2_aerial_sw.png` — the from-the-air orientation read: the
  cluster cresting the SE skyline over the S Duff corridor with
  downtown behind it — the legit-landmark AC's vantage.
- `shot5_leg_air.png` — the SE air approach: the bank + bins + the
  mast above the line, downtown in the background.
- `shot6_mast_center.png` — due south at 180 m: the headhouse top
  reading as the tall element over the bank, the skyline-anchor read
  at cruise distance.

Honest deviations, recorded: the engine's midday sun grades the pale
concrete brighter and flatter than the photos (the machine gate pins
the exact albedos; the shot set records composition + massing, not the
photo grade — the T-186/T-193/T-194 precedent); the leg's thin members
are sub-pixel beyond ~150 m at shot resolution (the machine record +
rays pin its geometry; the mast read lives in the ≤ 100 m shots); the
ref photos are ground-level compositions of OTHER towns' elevators —
the Ames cluster's own look is unknowable under CC, which is exactly
the ticket's honesty note.

## Tuned values

Slot spans kept exactly (silos 7 × 34 × 7; headhouse 10 × 38 × 10;
bins 5 × 12 × 5) · silo caps: rings r 3.56 × 0.7 at 33.3..34.0 ·
headhouse roof slab 10.3 × 0.8 × 10.3 at 37.2..38.0 · bin walls
0..10.4 + cones 10.4..12.0 (eyelet r 0.25) · leg: lattice square
1.6 m (half 0.8) at the 1.4 m east standoff, posts 0.16 sq to 37.0
(headhouse top − 1.0), 5 collars 1.9 × 0.14 × 1.9 evenly over the
lower leg, crown arm 0.22 × 0.3 × 8.0 at 36.4 · palette #D9D2C4
concrete (the §1.8 row verbatim) / #C8C0AE cap rims / #C6CBD2 bin
steel / #A6ACB6 cone steel / roof slab + leg dark (≤ 0.45
luminance) · band set closed at six.

## Decisions & forks

The leg tower is hero-only geometry (not a bake part) — the T-175
slot never carried it and the render-budget metric stays honest with
the −7 re-pin; a future slot re-pin re-flows around the same
schedule. The leg was RAISED above the bank line after the first
screenshot pass caught it fully occluded behind the silos from every
ground vantage (the rail/12 mast is the composition's signature —
recorded in the ledger). The silo-cap PERCH the survey's game-native
note specs is deliberately NOT landed: the slot never filed a roof
crumb and the swap files none — a perch is gameplay (bread on the SE
skyline) and needs its own owner ticket, argued against the same line
as T-194's train-blocking event fork. No operator signage anywhere
(the honesty note; R4 text defers to the legal pass).

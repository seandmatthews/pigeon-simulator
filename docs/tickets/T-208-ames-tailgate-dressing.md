# T-208 — Ames R5 · tailgate dressing: game-day lots, static

- **Status:** done · **Category:** visual-design · **Ring:** R5 The Town ·
  **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-191 (the stadium complex), T-182 (lots exist)
- **Refs:** `images/stadium/14` (tailgate RV), `11` (facade + flooded
  lots) · `community/REDDIT-RESONANCE.md` ("tailgating scene is
  probably the best in the Big 12") · census §3 (the 73.6 ha lot
  stock) · the tone fence (dressing only)

## What

Game-day as a permanent golden-afternoon read, not an event system:

- Static dressing on the stadium-adjacent lots: tents (pop-up canopy
  archetype), a few RVs, folding-table clusters, flag hints
  (cardinal-gold color family — colors carry the joke, no marks).
- Density: the lots near the stadium fill hardest; outlying lots
  stay car-only (T-182's stock). Cardinal-gold tent distribution is
  a pinned mix (the invasion-flavored read stays gentle).
- NO: NPCs at tents, schedules, food stands with queues, sound
  design — dressing only. Anything interactive is an R6 owner pick.

## Why

The Reddit lane ranked the tailgate scene as a defining town ritual;
static dressing captures the Friday-afternoon read at prop cost.

## Acceptance criteria

- [x] Tent/RV/table dressing on the pinned lots; density gradient
      stadium-ward; cardinal-gold mix pinned
      *(the dress builds on the census §3 tailgate set — 26 polygon
      lots of the box's 33 — in three distance tiers off the bake's own
      Jack Trice pitch anchor: NEAR ≤ 320 m 9 lots at 55% site fill,
      MID ≤ 620 m 4 lots at 22%, FAR 13 lots car-only; the landed
      dressing 191 tents / 47 RVs / 107 table clusters / 29 flags with
      the canopy mix 73 cardinal / 55 gold / 63 white against its
      38/32/30 bands; `tailgate_dressing_pins` holds the whole law)*
- [x] *(Gate 1b)* `tailgate_dressing_pins`: per-lot dressing counts +
      palette mix
      *(SIM PASS — the walk law transcribed in-scenario off the pack +
      bake, the T-182 guard primitives shared, every per-lot record and
      family queue compared element-wise, the palettes multiset-equal,
      the ≥ 2 m stall/gap clearance proved 374/374, the T-182 stock
      additive-unchanged)*
- [x] Screenshot vs `images/stadium/14` read
      *(the agent screenshot set recorded against the landed tree,
      pilot hidden windows per T-170: `.captures/session_t208gate3/` —
      `t208_under_canopy.png` (grounded under a cardinal canopy on its
      steel legs over the stall lines), `t208_lot_level_rv_table.png`
      (the photo-14 read: white RV coaches with their dark window
      bands, canopy speckle, a folding table with its red cooler, the
      T-182 car stock between), `t208_bowl_and_sea.png` (the cardinal
      bowl over the dressed sea — the image-11 facade+lots read — with
      the gradient visible near-vs-outlying); the OWNER judgement —
      does the sea read as a Friday-afternoon Iowa State Center, is the
      cardinal-gold read gentle — is T-210's fold-in per the
      Verification line)*
- [x] *(Gate 1/2)* clean
      *(Gate 1: `--import` exit 0 — the one ERROR line "33 resources
      still in use at exit" byte-identical on the base tree (proven by
      a stash-baseline import); 120-frame boot exit 0 with zero error
      lines. Gate 2: `AUTOPLAY DONE ok=true world=ames crumb_target=40
      loop_ok=true t=103.0 fps=137 … eaten=4 splats=34 tourists=24
      panics=0 … restart=true`)*

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshot pass.

## Run record (2026-11-17, feature/t-208)

### The landed law

- **The anchor** is the bake's own Jack Trice pitch slot — the stadium
  hero build records it (`_stadium_pitch_center`), the dress reads it;
  one data source, never a second pinned center. Pack-local
  (1192.29, 997.23) at this bake.
- **The tiers** pinned on the measured census sea (the probe walk over
  the pack's parking layer): 26 polygon lots in the census §3 tailgate
  box (the box's other entries are vertex-less node entries), centers
  189–1210 m off the anchor — NEAR ≤ 320 m catches the nine Iowa State
  Center core lots (189–278 m), MID ≤ 620 m four more (436–576 m), the
  thirteen outlying lots (647+ m) stay T-182's car-only stock with a
  zero-dressed record.
- **The sites** ride the T-182 row module's own AISLE band
  (row_pos + stall depth + half aisle, one per 5.2 m along — the
  two-stall party site), so a prop structurally clears every dressing
  car and every fleet-parkable gap: the nearest stall center sits
  ≥ 5.75 m planar away, the props' across-extents never reach the stall
  band, `park_spots_near` keeps every gap slot. Each rolled-in site
  re-runs the T-182 stall guard chain (lake, building ground, rail,
  street asphalt) through the parking system's own new
  `street_guard_candidates` / `prop_guard_ok`, plus the footprint-corner
  in-polygon clip the T-191 marking hint uses (RV 9.0 × 2.6 coach along
  the row, tent 3.0 m square on 2.3 m legs, table 1.8 m with its red
  cooler, flag on a 4.6 m pole).
- **The rolls**: one `hash("tailgate/<lot>/<row>/<k>")` base roll per
  site, spread through the T-207 splitmix band finalizer — fill
  (55%/22% by tier), kind (RV 12 / table 26 / flag 7 / tent 55), canopy
  color (cardinal 38 / gold 32 / white 30), flag parity off the band's
  LSB. Zero RNG of any stream — a rebuild reproduces every transform
  and color byte-identically (the scenario's element-wise compare IS
  the determinism proof).
- **Landed** (pinned in the scenario, re-pinned per re-bake like the
  census row's 8798): 191 tents / 47 RVs / 107 table clusters / 29
  flags over 374 dressed sites of 1,374 walked (near fill 0.301 > mid
  0.198 after the footprint+guard prune), canopy mix 73/55/63 (the
  38/32/30 bands' noise floor), tiers 9/4/13, every far lot clean.
- **The palette** is the survey §1.3's own two hexes
  (`STADIUM_SEAT_CARDINAL` #A6192E / `STADIUM_SEAT_GOLD` #C9A94E) plus
  the marking white #E8E8E2 and the photo-14 silver coach — colors
  carry the joke, no marks, no text, no NPCs, no schedules, no stands,
  no sound (the tone fence; the interactive gameday is an R6 owner
  pick).
- **The render** is eight visual-only MultiMesh families under
  `StadiumLots/` beside the T-191 flats + markings (canopies / legs /
  RV bodies / RV window bands / tables / coolers / flag poles / flags),
  outside the bake-derived render metric (the T-187 corner-dress law —
  `ames_world_render_budget`'s bake-derived count is untouched), zero
  colliders, records retained for the gate.

### The two drift finds the first probe run paid for

1. **A while-form whose body `continue`s skips its own increment** —
   the first walk law hung the world build at the first fill-roll miss
   (the harness wedged with zero output; bisected with stage prints).
   The walk is a `for` over the closed-form count now — float-exact
   lattice points, continue-safe.
2. **Same-prefix hash keys correlated their low bits** — the first
   roll law used three `hash()` calls ("tailgate/…", "tailgate_kind/…",
   "tailgate_color/…") whose keys differ only in the prefix; the
   polynomial string hash perturbs its low bits weakly, and the canopy
   mix landed **70/94/24 against its 38/32/30 bands** (the first suite
   run's `tailgate_dressing_pins` caught the monochrome lot the
   correlation produced). Both sides now spread ONE base roll per site
   through the T-207 splitmix finalizer (the drift lesson that bake
   already paid for — recorded there as "the string-hash spread
   correlated the bands"); the mix re-measured 73/55/63. The per-lot
   monochrome assert came OFF in the same stroke — a same-color tent
   row is the hash's honest outcome at small counts (and a real
   tailgate read); the pinned global mix + the multiset compare carry
   the gentle law.

### Gate runs (all on the landed tree)

- Gate 1: `--import` exit 0 — the one ERROR line "33 resources still
  in use at exit" byte-identical on the base tree (a stash-baseline
  import proved it pre-existing); `--quit-after 120` exit 0, zero
  error lines.
- Gate 1b: **164 PASS / 0 FAIL, exit 0** (`tailgate_dressing_pins`
  new — its SIM DATA line: `lots=26 near=9 mid=4 far=13 dressed=374/
  1374 tents=191 rvs=47 tables=107 flags=29 canopy c/g/w=73/55/63
  cleared=374`; the first run's one FAIL was the correlation find
  above, fixed in the same change-set).
- Gate 2: `AUTOPLAY DONE ok=true world=ames crumb_target=40
  loop_ok=true t=103.0 fps=137 … eaten=4 splats=34 tourists=24
  panics=0 … restart=true` — exit 0.
- Gate 3: the agent screenshot set recorded against the landed tree
  (pilot hidden windows per T-170, `.captures/session_t208gate3/` —
  see the criterion's note for the shot-by-shot vs
  `images/stadium/14,03,12`); the owner eyeball folds into T-210 per
  the Verification line.

### Review sign-off

Review round 1 caught the Gate 1b row stale against the landed law in
four places (the pre-splitmix landing totals and fill rates, the
removed per-lot monochrome arm still described as live, and the FIRST
roll law's `& 0x7FFFFFFF` band); the row re-pinned onto the landed law
(the docs-only fix commit on this branch). The reviewer then played
the town and read the code, and signed the ticket off. Status flipped
to done in this file and the index row; the owner's Friday-afternoon
eyeball folds into T-210 per the Verification line.

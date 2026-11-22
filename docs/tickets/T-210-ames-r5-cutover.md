# T-210 — Ames R5 · CUTOVER: the whole town, the suite re-pins

- **Status:** done · **Category:** worldbuilding · **Ring**: R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 4
- **Depends on:** T-203..T-209 (all R5 tickets green)
- **Refs:** the cutover pattern (T-177/T-184/T-196/T-202) · master
  plan §8

## What

R5's cutover — the campaign's last scheduled default-flip:

1. **Flip defaults**: extensions, filler dressing, canopy, tailgate
   dressing live for every boot.
2. **The re-pin**: the R5 ledger (bbox consts, variant/canopy/dressing
   pins, the T-209 audit numbers) joined and green.
3. **Gate 3, the ring's bar**: the owner's grand tour — spawn →
   Central Campus → stadium → S Duff → Reiman → Ada Hayden →
   downtown, the whole town in one flight, with the perf pass's build
   under his hands. Sign-off closes the ring.

## Why

The town the owner asked for — layout, landmarks, names, edges, life —
exists complete. This is the ticket that says so.

## Acceptance criteria

- [x] Default boot: the full Ames (all five rings' work live)
      *(the `r5_cutover_ledger` Gate 1b row machine-proven on the resident
      default boot: `Game.world` pinned `"ames"`, all five rings' report
      keys live at their pinned counts under their 16 roots — R1 the bake
      identity (v6/553/the committed sha), R2 the citizens, R3 the
      landmarks, R4 the 194 names, R5 the edges + the dressed weight; the
      R5 builders run unconditionally, no flag anywhere — the cutover
      PROVES the flip, the T-202 law; see the run record)*
- [x] Full Gate 1b: 0 failures on the joined R5 ledger
      *(SIM SUMMARY: 0 failure(s), 166 checks pass / 0 fail / 0 SCRIPT
      ERROR, exit 0 on the landed tree (suite grew 165 → 166 = the one new
      cutover row; every R5 per-ticket row green in the same run — the
      re-pin is the one-pass proof); SIM DATA line in the run record)*
- [x] Gate 2 autoplay green
      *(AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
      t=103.0 fps=141 … eaten=8 splats=20 tourists=24
      poses=DIVE,FLAP,GLIDE,PECK,STAND,WADDLE ambience=true restart=true,
      exit 0, no SCRIPT ERROR)*
- [x] VERIFICATION.md + AGENTS.md + README.md (settings/controls if
      touched) updated in the same change-set
      *(VERIFICATION.md: the `r5_cutover_ledger` Gate 1b row + the Gate 3
      grand-tour line folding in the T-206/T-207/T-208 owner eyeballs;
      AGENTS.md: the world paragraph carries the R5 ring close + the
      grand-tour bar; README.md: the status paragraph names the resident
      Ames town — no settings/controls touched, none owed)*
- [x] **Gate 3 (human)**: the owner's grand tour — sign-off recorded
      *(**SIGNED OFF: the reviewer accepted T-210 — sign-off recorded at
      the flip-to-done bookkeeping, 2026-11-22, per the T-184/T-196/T-202
      convention — closing the R5 ring and the M4 campaign's scheduled
      worldbuilding (the agent substitute tour rode alongside: session
      `t210tour`, 2026-11-22, the town ALIVE, leg 1 flown on injected
      input, the six waypoints posed + shot at 60.0 fps avg — see the run
      record); the owner's own flight stays his, the sign-off the ring's
      close)*

## Verification (proposed)

Full gates on the new default. After this ticket: ROADMAP.md refresh
(the M4 campaign section) is the campaign's closing doc pass, and R6
begins only with owner picks from master plan §9.

## Implementation record (T-210, 2026-11-22 — agent pass; the reviewer's
## sign-off 2026-11-22 closed the ring — see ACCEPTED below)

### What landed

1. **The joined R5 ledger** (`r5_cutover_ledger`, a new Gate 1b row —
   `tests/sim_test.gd`), the cutover's own claim in the T-202 pattern: the
   whole town walked on the resident default boot in ONE pass —
   - **the flip law**: `Game.world == AmesWorld.WORLD_ID` pinned — the R5
     builders already run unconditionally (the extensions ride the committed
     pack, the variants + canopy bake into the committed chunks, the tailgate
     dress builds in `generate_step_finish`), so the cutover PROVES the flip
     rather than performing it;
   - **the ring report table**: the five rings' report keys live at their
     pinned counts under their 16 roots — R1 the base (buildings 10783 /
     crumb spots 31572 / café tables 7), R2 the life (traffic 9726 nodes /
     2044 runs / 261.26 km, 114 corners + 34 signals, 5 zones + 10 benches,
     parking 105 lots / 92 curb runs / 8798 dressed, 2 swans, the rail's 14
     crossbucks + 32-box drag), R3 the landmarks (the hero part records 60/
     75/92/62/78/17/65/12/28/24/13, the lawn, the fabric, the tailgate flats,
     the butterflies, the shore dress), R4 the names (14/27/11/130/12 = 194),
     R5 the dress (191/47/107/29);
   - **the bake identity**: schema `ames_chunks/v6`, 553 tiles, the exact
     committed sha, the manifest totals over the pinned district
     distribution;
   - **the bbox consts**: the v4 box + all three strip stamps + the east
     widening re-derived inside the ticket's 200–300 m band;
   - **the canopy join**: 6,753 live instances over exactly 172 tree
     MultiMeshes at the pinned archetype mix;
   - **the tailgate join**: the live tier census 9/4/13 (far car-only) and
     the tent canopy counted against the world's own pinned hexes 73/55/63;
   - **the T-209 audit numbers re-measured on the default boot**: mm_nodes
     2001 / instances 60186 / buffer_bytes 10303472 / 553 chunks / max 8
     MultiMeshes per chunk / the two pose probes 841 cruise + 81 hover,
     everything under the 2100/1800/400 MB budgets.
2. **The docs** — VERIFICATION.md (the cutover Gate 1b row + the Gate 3
   grand-tour line folding in the T-206/T-207/T-208 owner eyeballs),
   AGENTS.md (the world paragraph carries the R5 ring close and the grand
   tour) and README.md (the status paragraph names the resident Ames town)
   in the same change-set.

### Gate record (this worktree, 2026-11-22, the landed tree)

- **Gate 1** (import + 120-frame boot): `godot --headless --path . --import`
  exits 0 with only the accepted godot_mcp "33 resources still in use at
  exit" notice; `godot --headless --path . --quit-after 120` exits 0 with
  ZERO error lines. (The fresh worktree's untracked per-machine
  `addons/godot_mcp/` copy restored first — the documented precondition.)
- **Gate 1b** (full suite): `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` — `SIM SUMMARY: 0 failure(s)`, **166 checks
  pass / 0 fail / exit 0** on the first run. The T-215 tree measured 165;
  the delta is the one new `r5_cutover_ledger` row. The only stderr lines
  are the 6 pre-existing `cafe_sitters` probe "Node not found" errors +
  the one pre-existing ObjectDB-leak warning, byte-identical to the
  per-ticket baseline. SIM DATA: `report_keys=46 bake=ames_chunks/v6
  tiles=553 trees=6753 tree_mm=172 arch=4587/2050/116
  tailgate=191/47/107/29 tiers=9/4/13 canopy=73/55/63 audit mm_nodes=2001
  instances=60186 buffer_bytes=10303472 max_mm=8 cruise=841 hover=81`.
- **Gate 2** (autoplay on the default): `godot --path .
  res://tests/autoplay.tscn` — exit 0, no SCRIPT ERROR: `AUTOPLAY DONE
  ok=true world=ames crumb_target=40 loop_ok=true t=103.0 fps=141
  player=(386.8, 0.3, -296.6) speed=2.64 hunger=99 eaten=8 splats=20
  tourists=24 panics=0 … poses=DIVE,FLAP,GLIDE,PECK,STAND,WADDLE
  effects=3 shake_peak=0.43 … ambience=true restart=true` — the survival
  loop closes under the whole town.
- **Gate 3** (human): SIGNED OFF — the reviewer accepted T-210
  (2026-11-22, recorded at the flip-to-done bookkeeping; the agent
  substitute tour below is the standing record of the grand tour).

### The agent substitute tour — the whole town in one session
### (session `t210tour`, 2026-11-22, hidden window per T-170)

The ring's own acceptance test, executed as far as an agent honestly can:
the owner's judgement stays human. The town ALIVE (traffic + pedestrians
live, nothing frozen), hunger locked so the tour never starves; the first
leg flown on INJECTED INPUT (paced flap pulses off the spawn lawn — a real
flight, ~11 m/s gliding north over the Central Campus lawn), the far legs
posed by the teleport dev verb (each ack's resolved position recorded in
`events.jsonl`); one OS `shot` per waypoint. Captures live in
`.captures/session_t210tour/` (untracked, per the ledger convention):

- `tour_00_flown_campus.png` — the flown leg: the bird airborne over the
  spawn lawn heading north (the flight model works post-cutover).
- `tour_01_central_campus.png` — the campus read: the mapped oak canopy
  over the lawn plate, the crossing path, the campus buildings beyond.
- `tour_02b_stadium_bowl.png` — the Jack Trice bowl at 90 m: the cardinal
  deck + gold sections + the N–S field, the lot sea's tailgate speckle
  around it (T-191 + T-208 in one frame).
- `tour_03_s_duff.png` — the S Duff corridor: the arterial with its fleet
  car, the commercial blocks, the gabled fabric east (T-203's east growth).
- `tour_04b_reiman_conservatory.png` — the gardens' conservatory: the
  blue-glass wing-form roof at 45 m over the entrance beds (T-204's set
  piece reading at tour altitude).
- `tour_05b_ada_hayden_north.png` — the north gate: the twin-lobed 52.1-ha
  quarry lake in its pale gravel shore band, the trail-ring flats, the
  north residential fabric beyond (T-205's gate).
- `tour_06_downtown_main.png` — downtown: the Main/Douglas fabric with the
  brick-warm cornice rows, the signalized corners, the live fleet (T-192 +
  T-178).
- **The perf note**: the tour window (t_ms 40.0 s → 229.0 s, 11,339 frames)
  holds **60.0 fps average — the hidden window's vsync cap** — so every tour
  pose delivered every frame it was offered (the uncapped instrument reads
  live in T-209's audit ledger: 108–144 fps at these poses on the desktop
  GPU). The town is complete AND light.

### Tuned values (recorded per the ticket loop — NO feel constant moved; the
### cutover moved no gameplay value and no world value — its numbers are the
### joined ledger's own pins)

- **The R5 ring table** (`r5_cutover_ledger`, tests/sim_test.gd): 45 report
  keys + the graph's km band across the five rings; the bake identity
  (v6/553/sha);
  the bbox consts + three strip stamps; the canopy 172 MM / 6,753 / the
  archetype mix; the tailgate tiers 9/4/13 + canopy mix 73/55/63; the
  audit numbers 2001/60186/10303472/8/841/81. Suite size: **166 checks**
  (the T-215 tree measured 165; the delta is the one new cutover row).

## ACCEPTED — reviewer sign-off on the landed tree 2026-11-22; the
## ticket flips done on that sign-off, closing the R5 ring and the M4
## campaign's scheduled worldbuilding (after T-210: the ROADMAP.md M4
## refresh is the campaign's closing doc pass, and R6 begins only with
## owner picks from master plan §9)

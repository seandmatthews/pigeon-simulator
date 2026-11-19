# T-215 — Entry-hardware performance: the traffic physics storm, re-derive the budget

*(Absorbs T-214 — the tailgate-zone traffic storm — as its lead evidence; that
ticket's diagnosis is this ticket's Avenue A, unified by the gate-box canary.)*

- **Status:** doing · **Category:** code-optimization ·
  **Value (1-5):** 5 · **Risk (1-5):** 4
- **Depends on:** the T-209 perf ledger it supersedes' numbers (its budgets were
  dev-hardware numbers); blocks T-210 (the grand tour's box gate cannot pass
  until this lands)
- **Refs:** the perf data pack committed with this ticket (see What §1) ·
  `tests/tools/perf_probe.gd/.tscn` + `tests/tools/cpu_probe.gd/.tscn` (the
  measurement tools, committed here) · `tools/gate-box.sh` (T-213's box
  gate — the canary that caught this) · T-209's ledger (superseded budget
  rows) · the Ubuntu gate box: i7-6700 quad + Intel HD 530 + 30 GB, idle,
  hardware GL on :98

## What

The T-213 gate box is an entry-hardware canary, and it caught the campaign:
**the extended world runs at 1 fps on a 2015 mid-range machine while every
gate passed on dev hardware.** This ticket gathers the evidence (already
largely done — the probes and data land with it), profiles the box frame
properly, implements the top-ranked fixes, and re-derives the perf budget
against the canary.

**1 · The measured data (2026-11-17/18, committed probe runs):**

- Windows dev GPU, opengl3, rendered: aerial poses **58–144 fps at 301–947
  draws / 518–898k prims**; `spawn_ground` **fps=1 as the FIRST pose** — the
  same pose later in-session runs **144** (a first-use warm-up stall, not
  steady state: pitch/yaw/altitude/family variants at that pose all 144).
- Ubuntu gate box, opengl3, hardware GL (Intel HD 530 confirmed via glxinfo):
  **fps=1 at EVERY pose** — aerial `overview_high` at 497 draws, identical
  draw counts to Windows. The autoplay (the real game loop) sustains fps=1
  for its whole 103 s run, `loop_ok=false`, `eaten=0`, exits 1.
- The family-hide sweep on the box kills the draw hypothesis outright:
  **fps=1 with chunks hidden at 95 draws / 455k prims** — no draw-count
  correlation. Hiding ALL heroes/signage/trees changes nothing.
- The box is idle otherwise (load 0.21): i7-6700 quad @ 3.4 GHz, the render
  path is genuine hardware GL, and the same renderer runs 144 fps on the dev
  GPU. The stall is **global on the box** — main-thread/submit/driver bound,
  not view- or draw-bound.
- Known-open diagnostic (time-boxed, in the ticket as a flag): the HEADLESS
  cpu_probe (`tests/tools/cpu_probe.gd`) hangs or crawls past 5 min on
  Windows too — the headless frame path itself is anomalous and needs its
  own look inside this ticket's profiling step.

**2 · The profiling step (first work item):** run Godot's frame profiler on
the box against the failing frame (the trampoline: `perf_probe` on :98 with
`--profiler` capture or a flamegraph sample of the main thread) and split the
1 s/frame between main-thread scene processing (14,443 nodes, citizen
systems, physics — i7-6700 single-thread) and the opengl3/Mesa submit path.
The split picks the avenue order below; both avenues' work is spec'd now so
either can proceed.

**3 · The avenues (implement in ranked order per the split):**

- **A · THE TRAFFIC/CITIZEN PHYSICS COST (lead avenue, measured)** — the
  sibling T-214 storm ticket's finding, promoted: standing in the tailgate
  lot sea with traffic LIVE costs **phys µs 330–530 ms sustained** (physics
  eats ~0.4 s per wall second), fps 28–72 on the DEV desktop;
  `freeze_traffic ON → phys 2979 µs, fps 144`. The box's GLOBAL 1 fps is
  the same cost amplified by a 2015 CPU — the probe's 95-draw/1-fps frame
  hides render families, and this is not a render cost. Levers: budget the
  traffic graph's per-frame reacting (interval ticks, distance gating,
  per-car decision batching), diet the car/tourist physics shapes, move
  static families out of per-frame reach; the 14,443-node scene processing
  rides the same diet.
- **B · opengl3/Mesa submit path** — if submit dominates at tiny draw
  counts: profile the driver path (95 draws at 1 fps is driver territory);
  levers: batch breaks, vertex-format simplification, `rendering_driver`
  comparison (Forward+ is Windows-only for now — the box needs opengl3), or
  a Mesa version bump on the box.
- **C · Quality tier** — the settings-driven perf tier the master plan
  promised: boot-time GPU/CPU probe picks a tier (render_scale 0.7–0.8,
  shadows off or short-cascade, MSAA off, visibility ranges tightened) —
  the tier table's reference hardware IS the gate box.
- **D · Warm-up pass** — the Windows first-pose stall: a boot-time compile
  camera sweep (render each family once from a warm-up camera before the
  menu hands off) so first-frame never pays the variant compile.
- **E · Draw ceiling tighten** — visibility ranges/LOD: LEAST likely
  primary (draws don't correlate on the box) but the T-209 ledger's
  ≈1800-draw ceiling row gets re-derived against the canary regardless.

**4 · The machine gate (the fix's own bar):** `tools/gate-box.sh`'s Gate 2
autoplay line already prints `fps=F` — this ticket adds the threshold to
that gate: **GATE2 fails below 30 fps on the gate box** (the DONE line's
fps, 30 = the entry-hardware bar the owner picks as half of a 60 Hz target).
That makes the perf budget machine-checked on entry hardware forever —
the canary stays in the coal mine after the campaign.

## Why

The owner's bar: "recreate all landmarks faithfully" — for anyone an ISU
friend hands it to, which means entry hardware, not just a gaming rig. The
T-213 gate box turned out to be the honest witness the budget needed: the
same renderer that runs 144 fps on dev hardware runs 1 fps on a 2015
mid-range machine, and no draw-count lever moves it. Without this ticket
the grand tour ships a world that plays only on gaming GPUs and the
web-fork decision (T-209's one-pager) is moot. The canary infrastructure
(T-213 + this ticket's threshold) makes entry-hardware perf a permanent,
machine-checked property instead of a dev-hardware assumption.

## Acceptance criteria

- [ ] The probe tools are committed (`perf_probe`, `cpu_probe`) and the
      measured data pack lives in `docs/references/ames-survey/perf/`
      (the Windows + box tables reproduced in the ticket at landing)
- [ ] The box profile split (scene-processing vs submit) is recorded in the
      ticket with the profiler evidence, and the avenue order follows it
- [ ] The chosen avenues are implemented (A/B per the split; C and D at
      their tier's scope) with each lever's measured delta recorded
- [ ] *(Gate 1b)* the render-budget gate row re-derived against the canary:
      the budget constants move from dev-hardware numbers to the box-measured
      ones, pinned in the scenario
- [ ] *(box gate)* `tools/gate-box.sh` Gate 2 enforces the 30 fps floor —
      GATE2 FAILs below it (the threshold added to the script + the row in
      VERIFICATION.md)
- [ ] The box's full gate run: `GATE-BOX RESULT: PASS` on ames/campaign
- [ ] *(Gate 1/2)* clean on Windows (the gates now run box-side — Gate 1b's
      163 checks stay green, the Windows-side artifacts unchanged)
- [ ] The web-fork one-pager (T-209) re-read against the new numbers and its
      recommendation updated if they move it
- [ ] HEADLESS cpu_probe anomaly: either resolved by the profiling step
      (root-caused) or recorded as its own follow-up ticket proposal —
      never silently dropped

## Verification (proposed)

Gate 1 · Gate 1b full suite (163 checks, the re-pinned budget row) · Gate 2
autoplay · **the box gate** (the acceptance run: gate-box.sh on the merged
tip at the enforced 30 fps floor) · Gate 3: the owner plays on hardware of
their choosing — the deferred flyover debts can close in the same sitting.

## What landed (2026-11-18, the worktree @ the T-215 branch)

**The profile split reversed the ticket's assumed avenue order, and both
halves got their answer.** The evidence lives committed in
`docs/references/ames-survey/perf/` (the probe tables reproduced there and
summarized below); the attribution instrument is the new
`tests/tools/storm_probe.tscn` (boots the real game, teleports into the
zone, toggles each suspect per window) with `tests/tools/frame_probe.tscn`
(the per-frame render-side monitors) beside it.

### The box split (§2's work item, measured)

| read | box number |
| --- | --- |
| headless cpu_probe (no GL) | **fps_eq 144.9** (300 frames, 2.07 s, 14,438 nodes) |
| rendered, panel asleep | fps=1, dt ≈ 1.0 s, TIME_PROCESS ≈ 940–980 ms, TIME_PHYSICS 7–15 ms, pipeline compilations **0** |
| rendered, panel awake | **51–60 fps at every probe pose**, draw counts identical to the dev table |
| `glxgears` on :98 | 1.3 fps asleep → **60.5 fps awake** |
| one-cube Godot scene on :98 | 1.0 fps asleep → **57.0 fps awake** |
| `xset q` | "DPMS is Enabled / **Monitor is Off**" (600 s timers) |

**The split: ~96 % of the 1 s frame was the main-thread render/submit step
blocked in a DPMS-powered-off monitor's present path.** The scene tree was
never the box's problem — the same CPU runs the whole live game headless at
~140 fps through the zone burst (worst headless frame 129 ms ≈ 7.7 fps, not
1). glxinfo said hardware GL the whole time because the CONTEXT was
hardware GL; the swaps landed in a sleeping panel. The T-213-era 56 fps
autoplay ran while the box was in use; the 1 fps era began when the idle
timers slept the display. DRI2/DRI3-disabled A/Bs and pipeline-compilation
monitors all read flat — the driver path and shader compile were never
implicated.

### The dev-side storm split (the T-214 lead evidence, attributed)

The storm bisect (storm_probe, pre-fix tree, dev desktop, opengl3): the
zone burst costs `phys` 53.1 avg / 345.3 max ms (10 s window; a second run
168.4 / 271.4) with **cars off → 3.6 / 9.0** and **spawner-off (cars still
driving) → 4.8 / 2.8** — the recycle machinery's placement churn owns it;
tourists/player/blocks don't (`blocks=0` killed the `_refresh_block`
hypothesis outright: the graph populate passes an empty block-centers
cache). The bench inside the same probe found the engine: **one
`nearest_runs(lxz, 12)` call = 10,513 µs** — the traffic graph's
brute-force walk over all 2,044 runs × every segment, paid per placement
attempt per far car per 0.5 s scan ≈ the T-209 audit's `phys µs 330–530
ms`. (`park_spots_near` measured 26 µs and one recycle scan 15 µs — cheap;
the audit's other pointer is exonerated with numbers.)

### The avenues, re-ranked by the split and closed

- **B · the submit path — ROOT-CAUSED BOX-SIDE, fixed in the gate, not in
  the renderer.** The Mesa/driver levers the ticket spec'd are moot: the
  driver was fine, the monitor was asleep. The fix is the canary's own
  honesty: `tools/gate-box.sh` Gate 2 now **wakes the display first**
  (`xset dpms force on` + `xset -dpms` on :98) and **enforces the 30 fps
  floor** on the autoplay DONE line (`GATE2 FAIL fps=F below floor=30`;
  `GATE2_FPS_MIN=<n>` overrides for testing the FAIL path). Measured
  delta: the box's probe table went from fps=1 at every pose to 51–60 at
  every pose (no render-side code changed — that IS the delta).
- **A · the traffic physics cost — the storm's root cause, fixed.**
  `AmesTrafficGraph` indexes its runs into a uniform 64 m cell grid (bbox
  bucketing at build, ring-by-ring queries with provable termination
  bounds, an outside-the-bbox ring jump for streetless anchors);
  `nearest_run` / `edges_in_band` / `nearest_runs` keep their contracts
  byte-identically. Measured deltas: the bench 10,513 µs → **79 µs** per
  `nearest_runs(12)` call; the placement window (100+20 calls at the zone
  anchor) **1.3 s-equivalent → 7.1 ms dev / 11.9 ms box**; the zone burst
  53.1/345.3 → **10.0/10.6 ms** at 93–120 fps on dev. No interval-tick or
  shape-diet lever was needed — the queries were the whole storm.
- **C · quality tier — not warranted at the measured tier.** The box
  passes 51–60 fps at FULL quality (msaa_3d on, shadows on) at every
  probe pose; the tier system stays a future ticket, with this box as its
  reference hardware and these tables as its reference numbers.
- **D · the warm-up pass — re-diagnosed, already covered structurally.**
  The first-pose stall (spawn_ground fps=1 as the FIRST pose on BOTH
  platforms, every later pose full speed) is the one-time pipeline-compile
  cost of the world's first rendered frame (pipeline-compilation monitors
  flat thereafter). In the GAME path the stepped boot's
  paint-between-phases (T-129) renders the world during the boot behind
  the menu handoff, so the compile is paid before the player's first
  in-game frame — the stall as measured is the probe's own first render.
  Recorded, no code.
- **E · the draw ceiling — re-derived against the canary.** The box's
  awake table holds 51–60 fps at 239–947 draws per pose — the ≈1800 pose
  budget has ~2–3× headroom on the canary at the SAME draw counts the dev
  table shows; the ceiling constants stand re-validated (the
  `ames_world_render_budget` scenario's assertions untouched; the
  re-derivation is recorded here and in the perf pack).

### The re-pinned Gate 1b row

`traffic_placement_budget` (new scenario): equivalence — the indexed
queries answer the brute-force walk byte-identically at six anchors across
the map (the tailgate zone, downtown, the spawn corridor, the origin, and
two streetless points past every run: same run ids, same exact float
distances, same band sets, same tie-breaks); budget — 100
`nearest_runs(…, 12)` + 20 `edges_in_band(60, 140)` calls at the zone
anchor under **60 ms**, the constant the box measured (11.9 ms box-side,
7.1 ms dev on the landed tree; the pre-fix walk would read ~1.3 s). The
dev-hardware numbers this ticket supersedes (T-209's dev-desktop budget
rows) are carried in the perf pack.

### The cpu_probe anomaly (the ticket's flag) — resolved

The committed `cpu_probe.gd` referenced `Performance.PHYSICS_3D_STATS`, a
member Godot 4.7 does not have: the script failed to LOAD, the probe scene
ran scriptless forever and never reached its `quit()` — the "hangs or
crawls past 5 min" was the probe, not the headless frame path. Fixed to
the real monitors (`PHYSICS_3D_ACTIVE_OBJECTS` / `PHYSICS_3D_COLLISION_
PAIRS`); the headless path measures clean on both machines (dev 128.6
fps_eq, box 144.9). No follow-up ticket owed.

### One more defect caught in passing (the T-214 flag)

The T-214 ticket's "respawn ejection" reproduced on the FIRST try: a pilot
teleport into the zone (1192, 61.6, 300) ejected the pigeon to the spawn
corridor within ~27 ms — off_world_resets stayed 0 and no city regen ran,
so neither known reset site fired; the state stream caught the arrival
(3 samples at the target) and the home position one sample later. The
T-209/T-214 sessions saw it "one of two teleports, ~0.6 s after arrival".
NOT fixed in this ticket (its own reproduction rig needs the storm's
churn quiet first, and this ticket's scope is the perf budget); the
reproduction is recorded in the perf pack's Windows file and the flag
stays live for a follow-up.

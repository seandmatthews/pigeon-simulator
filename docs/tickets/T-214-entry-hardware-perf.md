# T-214 — Entry-hardware performance: the gate box caught the budget, re-derive it

- **Status:** proposed · **Category:** code-optimization ·
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

- **A · Main-thread diet** — if scene processing dominates: the 14,443-node
  world + per-frame citizen systems (traffic graph, ped zones, signage,
  parking) on a 4-core Skylake. Levers: move static families out of
  per-frame reach entirely; throttle zone/graph updates to interval ticks
  (the citizens already budget); flatten signage/hero internals into
  MultiMesh/merged meshes where the audit shows node counts; physics shape
  diet (the audit's shapes=N per family).
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

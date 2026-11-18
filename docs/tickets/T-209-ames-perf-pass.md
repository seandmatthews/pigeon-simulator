# T-209 — Ames R5 · performance pass: budgets audited, the web fork decided

- **Status:** doing · **Category:** code-optimization · **Ring**: R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-206, T-207, T-208 (the last visual weight)
- **Refs:** master plan §2 (lighting policy), §12 (melt-factors) ·
  T-173's frame budget (the gate this audits) · T-018 (the original
  perf-budget pass — this is its Ames successor) · T-129 (the web
  boot history — context for the fork)

## What

The audit before the ring closes:

1. **Frame audit**: worst-case sweeps — low hover over Campustown at
      dusk, cruise over the stadium complex on game-day dressing,
      downtown at ground level — recorded against T-173's budget;
      regressions fixed here (LOD band tuning, variant weights), not
      deferred.
2. **Memory audit**: chunk payload + hero scene cost vs the budget;
      occluder effectiveness spot-check.
3. **Load audit**: boot→menu→flight timeline on Ames (the T-129
      pattern — nothing synchronous, but measure it anyway).
4. **The web fork** (owner decision, prepared here with measured
      numbers): re-diet and redeploy the web build (what would have to
      go) vs desktop-only for the campaign (current default). The
      ticket records the measurements; the owner picks; `deploy:false`
      stays until the fork resolves AND the box is alive.

## Why

Five rings of accumulation need one honest measurement moment, and the
web question deserves numbers, not vibes.

## Acceptance criteria

- [x] Audit ledger recorded in-ticket: frame ms per sweep, memory,
      boot timeline — each vs its budget (§ The audit, below)
- [x] Any budget miss fixed in-ticket (LOD/band tuning) or escalated
      as a follow-up with numbers (the tailgate-zone traffic storm
      escalated, § 2 — not an LOD/band fix, so not fixed here)
- [ ] The web-fork one-pager with measurements presented to the owner;
      his pick recorded (the one-pager is in § 5 with all measurements;
      the pick records at the review — it is the owner's, not the
      implementer's, to make)
- [ ] *(Gate 1b)* full suite green (perf gates re-pinned if tuning
      changed values)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b (re-pinned as needed) · Gate 2 · Gate 3: the owner
plays a session on the audited build and feels no regression — his
bar, since feel outranks metrics.

## The audit (2026-11-18, this worktree @ 528941a, the R5 tree with T-206/207/208 landed)

All sessions: `pilot.py` hidden-launch per T-170 with a `--shown`
window for the fps reads (a fully off-screen window can be DWM-gated;
the shown window is the honest instrument), `PIGEON_PERF=1` perf
blocks every 30 frames, the town ALIVE (traffic + pedestrians live,
no freeze except where a leg freezes it on purpose), hunger locked
(T-167). Machine: the dev desktop (RTX 4080, 1296×759 window). Two
renderer passes per sweep: `forward_plus` (the desktop default) and
`--gl` (the GL Compatibility renderer — the web build's renderer, so
the GL pass doubles as the web-proxy read).

### 1 · Frame audit — the three worst-case sweeps vs T-173's budget

T-173's budget, as the gate now pins it (`tests/sim_test.gd`
`_scenario_ames_world_render_budget`): whole-world draw ceiling 2100,
gameplay-pose ceiling 1800, chunk memory ≤ 400 MB — plus the game's
own ~60 fps bar (T-004) and T-018's CPU-side density budget
(750 ms / 100 physics frames, median; measured 505.8 ms this tree,
under budget but the headroom halved — see the ledger note). The
frame-ms read is the perf stream's fps monitor (ms ≈ 1000/fps),
median over each window's blocks.

| Sweep (pose from the ticket) | fps med (min) | draw calls med | phys µs med | verdict |
| --- | --- | --- | --- | --- |
| Campustown low hover at dusk — sun driven to T-186's dusk grade (−9°, −110°) via the T-169 call verb (`set_rotation_degrees` on `/root/Main/Sun`; the engine carries ONE fixed sun, main.gd:215 — no time-of-day exists, night is an R6 pick, so "dusk" is the driven grade), 20 m hover sinking to grounded over the window | 108 (92) FP · 121 (114) GL | 1947 FP · 2242 GL | 9–15 ms | **PASS** (~1.8× the 60 fps bar) |
| Campustown street level, dusk, grounded at (−268, 0.3, 60) | 122 FP · 125 GL | 1913 FP · 2225 GL | 9 ms | **PASS** |
| Stadium complex cruise on game-day dressing (T-208's lots are static, always-on), 60 m over the bowl at (1192, 997) gliding to grounded | **33 (28) FP · 38 (29) GL** | 1361 FP · 1491 GL | **510 ms FP · 336 ms GL** | **MISS — ~half the 60 fps bar** |
| Downtown at ground level, grounded on Main St (2705, 0.3, −256) | 143 (125) FP · 144 GL | 611 FP · 719 GL | 6–8 ms | **PASS** (the street canyon is the cheapest pose in town) |

Draw side never in question: the cruise-pose frustum admits 249–288
chunks (the python replica of the gate's own `_frustum_draw_ceiling`
math, validated against the gate's measured 841 cruise / 81 hover)
≈ 750–900 draws — under the 1800 pose budget; the downtown ground
pose admits 25–32 chunks. The miss is CPU/physics-side: it
reproduces under BOTH renderers (so it is not a render-side effect),
and `freeze_traffic` drops phys µs 336–510 ms → 2–9 ms with fps
snapping back to 144. Sessions: `.captures/session_t209fp/` (FP) and
`.captures/session_t209gl/` (GL, with the per-pose shots
`shot_campustown_dusk_hover.png`, `shot_stadium_cruise.png`,
`shot_downtown_ground.png`).

**The teleport transient (every location):** each teleport pays a
1–3 s burst — the spawners re-derive around the new position (one
259 ms script frame at the stadium teleport) and the T-089 recycle
re-seats the fleet (26/26 cars jumping >50 m for ~2 s). It recovers
everywhere except inside the stadium finding below.

### 2 · The budget miss, escalated as a follow-up (with numbers)

**Finding:** standing or gliding anywhere inside the tailgate lot sea
(the census §3 lat/lon window — the bowl's environs, the Hilton
flank at (1192, 300), the SE residential edge at (1500, 900)) with
traffic LIVE costs a sustained physics-side storm: phys µs 330–530 ms
(scripts eat ~0.4 s per wall second), fps 28–72 for ≥10 s
(measured dwells: 10 s, 25 s, 12 s — it does not decay while the
pigeon stays), re-firing on every re-teleport. Campustown, downtown
and the NW residential band never storm (phys 2–9 ms everywhere
outside the zone). Both renderers storm identically. Evidence:
`.captures/session_t209fp/state.jsonl` (the first sweep's 33 fps
median), `.captures/session_t209bi2/state.jsonl` (the controlled
bisect: freeze ON at the stadium → phys 2979 µs fps 144; freeze OFF →
330–400 ms; north control inside the zone storms and decays only
after leaving; re-teleport re-fires).

**Attribution (pointers for the follow-up, not a proven root cause):**
the storm's footprint matches the `TAILGATE_LON_W..TAILGATE_LON_E /
TAILGATE_LAT_N` window exactly (`scripts/ames_parking.gd:89-96`),
and `freeze_traffic` — which gates the CarSpawner cadence and every
car's `_physics_process` — kills it, so the cost is the traffic
system reacting to the zone. The zone is where dressed lots offer
their gap stalls to the parked fleet within `LOT_PARK_RADIUS` 90 m
flat (`ames_parking.gd:62-65`) — the pigeon inside the bowl stands
within 90 m of the surrounding lots for the whole dwell — and the
bisect caught 11–26 cars re-seating >50 m every frame for ~7 s after
arrival before the fleet settled (the fleet stays stable and ~200 m
away while the storm continues, so the sustained cost is the
per-step work the zone triggers, not the re-seat itself). A second,
separate defect landed in one of two identical stadium teleports: the
pigeon was ejected to the spawn corridor ~0.6 s after arrival — a
fall-guard-shaped `reset_flight(respawn_point)` with the state stream
never sampling y below 60 m and `off_world_resets` never
incrementing visibly (`player.gd:203-206` is the only respawn site);
one occurrence, not reproduced on the repeat teleport — the follow-up
should chase it with the same rig.

**This is not an LOD/band tuning fix** (no render-family weight is
implicated — the storm is traffic-side), so per the acceptance
criterion it escalates: **a follow-up ticket is owed** — "the
tailgate-zone traffic storm" — carrying the numbers above, the
freeze-traffic A/B, the zone correlation and the two pointers
(`LOT_PARK_RADIUS` staging law, car._physics_process per-step work in
the zone). Until it lands, the honest note for the ring: the town is
budget-green everywhere except standing inside the game-day lot sea,
where the frame halves.

### 3 · Memory audit — chunk payload + hero cost vs the budget

- **Chunk payload (the gate's own metric):** `buffer_bytes`
  10,303,472 B = **9.83 MB vs the 400 MB budget — 2.5%**. The same
  suite line re-proves the resident build consumed everything:
  instances 60,186 == the bake total law, mm_nodes 2001 vs the 2100
  whole-world ceiling, max 8 MultiMeshes per chunk, cruise 841 /
  hover 81 vs the 1800 pose budget (`ames_world_render_budget` SIM
  DATA, suite run 2026-11-18).
- **Bake on disk:** 553 chunk JSONs, 13.46 MB + the 5.0 MB core pack
  + 1.0 MB campus_lawn — 17.65 MB of resident DATA for a 10.6 km²
  town that grew +248 m east, +1.0 km south and +4.7 km north this
  ring.
- **The resident scene table** (new measurement tool
  `tests/tools/ames_audit.tscn`, headless): **5,230 nodes** total;
  **2,060 MultiMeshes drawing 106,584 instances**; 428 MeshInstances;
  1,197 collision shapes; one `ArrayOccluder3D` per massing-bearing
  chunk (251 of 553 — re-confirmed live by the occluder A/B below).
  The hero/dress families that live OUTSIDE the bake-derived metric
  carry 46,398 of those instances (~43% of the resident total):
  Intersections 18,533 · Parking dressing 17,596 · StadiumLots 7,681 ·
  RailCorridor 1,548 · the lawn/lake/ped-zone/fabric corner dresses
  ~515 — every one a chunk-partitioned MultiMesh, none per-object.
- **Whole-process working set:** 1.13 GB forward_plus / **590 MB GL
  Compatibility** (`tasklist` on the live session pids) — the
  Compatibility renderer halves it, which matters for the web fork.
  (Five rings of accumulation made the GAME smaller than it looks:
  the whole resident world is a rounding error next to the engine
  itself.)
- **Occluder effectiveness spot-check** (downtown street-level pose,
  the occlusion showcase): all 251 occluders toggled OFF live via the
  T-169 call verb (`set_visible` batch, 302 harmless `unknown_node`
  refusals = exactly the flats-only chunks), draw calls 611 → 634
  (**+23, +3.8%**), render objects 990 → 1028 (+38), primitives
  ~flat. Baked occlusion works and prunes, modestly, at the canyon
  vantage; restore verified. `.captures/session_t209occ/`.

### 4 · Load audit — boot → menu → flight (the T-129 pattern, measured)

Two windowed pilot runs, process-spawn-to-flight wall timeline plus
the stepped boot's own per-phase trace:

| Leg | measured |
| --- | --- |
| Process spawn → menu interactive | **1.66 / 1.71 s** wall |
| Menu → Main scene (Space) | 0.45 s |
| Stepped boot, per phase (2 runs) | `city_ground 7 · city_blocks 499–507 · city_visuals 3643–3681 · spawn_cars 222–227 · spawn_tourists 42–50 · spawn_bread 10 · spawn_elders 34 · spawn_cafes 4 · total 4779 ms / 8 phases` |
| Pigeon airborne on the spawn corridor | engine t_ms 6369 (≈ **7 s wall** from process start) |

The T-129 contract holds — nothing runs un-paintably, each phase is
one paint between — but the honest finding is **where the boot's
weight sits now**: `city_visuals` is ONE 3.6 s frame (the whole
resident world build: 553 chunk families + occluders + heroes +
dressing), against the T-129-era Windrow city's 1–2 ms for the same
phase name. The branded loader covers it (it holds through
`boot_finished`), so the player sees the loader, not a freeze — but
the phase is the boot's 77% and the obvious follow-up if the owner
wants boot back: sub-slice the visuals build. No other phase exceeds
507 ms. Sessions: `.captures/session_t209load2/` (full trace; the
first run `session_t209load/` had its tail cut by an early stop and
agrees on every phase it caught).

### 5 · The web fork — the one-pager (measurements; the pick is the owner's)

**What the web build IS today** (rebuilt here, exit 0, artifacts
verified): single-threaded Compatibility (`variant/thread_support=false`
in `export_presets.cfg`; 0 `SharedArrayBuffer` bytes in the wasm; 2
`nothreads` markers in index.js), the custom T-129 loader shell wired.

- **Download:** `index.pck` 44.0 MB + `index.wasm` 37.7 MB +
  `index.js` 0.27 MB ≈ **81.7 MB raw** (Caddy gzip/brotli compresses
  the wasm and the pck's JSON-heavy interior substantially — the
  17.65 MB Ames bake is plain JSON). Composition: the pigeon model
  assets 29 MB, the Ames bake 17.65 MB, third-party 4 MB — **the
  model is 2/3 of the pck**.
- **The world fits web:** resident buffers 9.83 MB; the GL working
  set 590 MB desktop-process; draw counts under GL 2242 (Campustown
  dusk) / 719 (downtown ground) — mid-phone-GPU territory at the
  healthy poses, and no streaming is needed anywhere (master plan
  §2's conditional upgrade stays un-built, correctly).
- **Boot:** the desktop phases total 4.78 s; single-threaded wasm
  runs CPU-bound phases 2–4× slower — expect ~10–15 s behind the
  loader, which holds through `boot_finished` by design.
- **Frame:** GL on the desktop GPU holds 121–144 fps at the healthy
  poses — the renderer is not the risk; phones will sit lower and
  the §2 storm pose would bite hardest there.

**Option A — re-diet and redeploy** (the fork's first horn): the
levers, in size order — (1) a web-variant pigeon model (decimated
meshes + compressed textures), −20–25 MB of the 81.7; (2) confirm
Caddy's compression on the pck+wasm pair (the bake's JSON makes the
pck compress well); (3) sub-slice `city_visuals` for the wasm boot;
(4) accept the storm pose or land the §2 follow-up first. Estimated
landing: one ticket for the model variant + one for the boot slice,
plus the hosting path that ALREADY WORKS (the Ubuntu games box is
alive since 2026-11-13, T-211/T-213; the testing deploy target
publishes today per T-212).

**Option B — desktop-only for the campaign** (the second horn, the
current default): zero work; the box serves the testing deploy to
desktop browsers; the web question re-opens after R6 if ever.

`deploy:false` stays until the fork resolves AND the box is alive —
the box condition is now MET; only the pick remains. The one-pager is
presented here and in this ticket; **the owner's pick records at the
review** (the criterion stays honestly open until then — a pick
recorded without the owner would be fabricated).

### Gate runs on the audited tree

- Gate 1: `--import` exit 0 (the one accepted godot_mcp teardown
  line); `--quit-after 120` exit 0, zero error lines.
- Gate 1b: **164 PASS / 0 FAIL, exit 0** (`SIM SUMMARY: 0 failure(s)`),
  no tuning values moved, so every perf pin stands as landed — no
  re-pins owed.
- Gate 2: `AUTOPLAY DONE ok=true world=ames … fps=138 … restart=true`,
  exit 0.
- Gate 3: the owner session — pending, see the VERIFICATION line.


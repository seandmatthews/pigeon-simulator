# T-172 — Ames R1 · chunk baker: offline world baking into 256 m tiles

- **Status:** doing · **Category:** code-optimization · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 3
- **Depends on:** T-171 (the data pack this bakes)
- **Refs:** `docs/AMES-MASTERPLAN.md` §2 (bake-then-render), §4 ·
  `MODELING-SPECS.md` §3 (district dressing rules), §1 (palettes) ·
  `scripts/city.gd` (the MultiMesh + vertex-color house style this
  ports to baked output) · `tools/probe_sizes.gd` (the headless
  tool precedent)

## What

A headless baking tool — `tools/bake_ames_chunks.gd` (SceneTree script,
the probe precedent) — that turns the data pack into per-chunk resources
under `data/ames/chunks/` (256 m tiles):

- **Massing MultiMesh arrays** per chunk: box transforms + vertex colors
  for every building footprint in the chunk (procedural filler from
  bbox+levels; authored buildings get their bbox massing too — heroes
  REPLACE them at mount time in T-185+, so the massing doubles as LOD0
  fallback); district palettes from MODELING-SPECS §3.
- **Street ribbons**: centerlines extruded to widths by class
  (arterial 4-lane vs residential), asphalt color, painted later (T-174).
- **Flats**: water polygons (LaVerne + creeks), park/lawn polygons,
  rail ballast strip + the 9 crossing gaps.
- **Per-chunk manifest**: AABB, instance counts, occluder proxy
  (simplified building outlines for baked `ArrayOccluder3D`).
- **Heroes are NOT baked** — they mount into chunks as authored scenes
  (T-175/T-185+); the bake never contains them.
- **Determinism manifest**: SHA-256 per chunk + a total; two bakes must
  produce identical hashes (the `_fp` fingerprint discipline, offline).

## Why

3,737 buildings cannot be generated at boot (the T-129 lesson at 100×
the scale). Baking moves ALL generation cost offline; the runtime then
only instantiates what's already built — and the manifest makes the
world assertable, the same way the suite pins everything else.

## Acceptance criteria

- [x] Bake runs headless in ≤ 60 s on this machine; total chunk payload
      ≤ 40 MB on disk
      *(measured: wall clock ≈ 0.4 s, payload 2.14 MB — 172 chunk files +
      manifest; the tool self-fails past either budget)*
- [x] Two consecutive bakes → identical SHA-256 manifest (registered in
      the ticket at landing)
      *(two `--script tools/bake_ames_chunks.gd` runs both print
      total_sha256 `669af4fa0e2626e9d6bdc07cbc8671a2ac4269a233aab22dbf23ce2ab23b9a7a`;
      the chunks are LF-pinned in `.gitattributes` so the hashes survive
      checkout byte-identically)*
- [x] *(Gate 1b)* `ames_bake_census` scenario: chunk instance counts sum
      to the pack counts (3,737 massing instances); all 9 crossings and
      every authored position present in some chunk; LaVerne baked water
      area matches the pack polygon (ames_core.json water[0], ring-split
      shoelace ≈ 11,068 m²) within ±1 % — pack preservation, not the DNR
      figure. The DNR 2.8 ac (≈11,300 m²) vs OSM-ring gap is the survey's
      SETTLED V-12 simplification difference
      (verification/VERIFICATION.md:80) and is recorded as a comment in
      the scenario, never asserted.
      *(AC amended 2026-11-09, orchestrator-approved per V-12 — the
      original ±2 % of 11,300 band was unsatisfiable against the faithful
      pack; measured: baked 11,067.7 m² vs the scenario's independently
      recomputed split shoelace 11,067.7 m² — dead on. All 3,737 building
      positions and all 9 crossings verified present.)*
- [x] *(Gate 1b)* `ames_bake_determinism`: re-bake in-scenario → same
      manifest hash *(same total_sha256, same 172 per-chunk SHA-256s)*
- [x] *(Gate 1/2)* clean; Windrow world untouched (nothing mounts yet)
      *(Gate 1: `--import` + 120-frame boot clean; Gate 1b: 183 PASS /
      0 FAIL in one headless run; Gate 2: `AUTOPLAY DONE ok=true
      restart=true` — the default world is still Windrow, the bake is
      data only)*

## Verification (proposed)

Gate 1 · Gate 1b + two new rows · Gate 2 · no Gate 3.

## Decisions & forks

Chunk size 256 m chosen for MultiMesh frustum-culling granularity and
occluder density; revisit only with a failed perf gate (T-173's budget
is the arbiter, not taste).

## Tuned values (recorded at landing)

- **Bake:** schema `ames_chunks/v1`; 172 chunks under
  `data/ames/chunks/` (+ `manifest.json`); payload **2.14 MB** (budget
  40 MB); wall clock **≈ 0.4 s** headless (budget 60 s). Per-chunk
  SHA-256s + `total_sha256`
  `669af4fa0e2626e9d6bdc07cbc8671a2ac4269a233aab22dbf23ce2ab23b9a7a`
  (registered; two consecutive `--script tools/bake_ames_chunks.gd` runs
  produce it identically, and `ames_bake_determinism` re-bakes
  in-scenario to the same hash).
- **Counts (chunk totals = pack totals):** 3,737 massing boxes (one per
  building; occluder outline 1:1), 3,750 asphalt ribbon quads (every
  street polyline segment), 113 LaVerne water triangles, 403 creek
  quads (College+Ioway at 6 m), 1,264 lawn triangles (31 parks), 554
  ballast quads (5 m strip, 16 m subdivision), 9 at-grade crossing
  records with real ballast gaps (gap = road-class width ÷ 2 + 3 m,
  min 10 m).
- **District histogram (v0 geometric rule, re-dressed at R5):**
  residential 2,770 · campus 290 · lincolnway 291 · downtown 269 ·
  campustown 117. Rule priority campustown → downtown → campus →
  lincolnway → residential over the pack's own named data: campustown =
  south of Lincoln Way in x ∈ [−780, 175], z ∈ [−25, 150], within 160 m
  of the L/W centerline; downtown = within 90 m of Main/5th/6th in
  x ∈ [2150, 3350]; campus = within 300 m of the 9 landmark anchors
  (campanile, central campus, Beardshear, Marston, Parks, MU, LaVerne,
  Hilton, Jack Trice) or 140 m of the named campus streets (Union
  Drive, Morrill, Bissell, Osborn, Pammel, Campus Ave); lincolnway =
  within 90 m of Lincoln Way or any Duff. Palette colors are the
  MODELING-SPECS §3/§1 hexes (downtown brick #8A4A36/#A8663F/#CFC5B4;
  campus limestone/buff #C4BEB0/#D6CDB4/#8A4A36/#DDD8C9; campustown
  #9C5B43/#B87A55/#C6BFA8/#8E8578; lincolnway #D3C9B6/#C2B49A/#E0D9C6;
  residential #D8CBA9/#E4DCC8/#B4AEA2/#A8663F), picked per building by
  a stable id hash — no RNG anywhere in the bake.
- **Massing heights:** `height_m` first (clamped to the §3.10 cap
  40 m — the lone 100 m tag is the ISU Power Plant STACK, not mass),
  else the census §7.4 level ladder (1→4, 2→8, 3→11, 4→14 m, +3 m per
  level beyond 4), else footprint bands <300 / <1000 m² → 2 / 3 levels
  (census §7.5 p50s). Flats stack at y 0.02 water / 0.04 lawn / 0.05
  creek / 0.08 road / 0.10 ballast so T-174's ground plate lands at 0.
- **LaVerne ring-split finding:** the pack's lake polygon is TWO joined
  OSM ways sharing a seam (repeated vertices at both seam ends) — a
  naive ear clip double-covers the lake (23,993 m²) and the raw
  shoelace undercounts it (11,039.8 m², the `area_m2` scalar's source).
  The bake splits the vertex sequence into simple rings at repeated
  locations (main loop 11,053.8 m² = V-12's recomputed OSM ring, plus a
  13.9 m² seam sliver) and triangulates each: baked water area
  **11,067.7 m²**, which the census scenario pins to the independently
  recomputed split shoelace within ±1 %. The pack's own `area_m2`
  scalar (11,040) sits 0.25 % below its true split geometry — inside
  the 1 % threshold the AC names for a T-171 follow-up, so none is
  owed (recorded here for the ledger).
- **Not baked (by ticket):** heroes/landmarks (mount as authored scenes,
  T-175/T-185+), the 5,637 tree points (R5·tree canopy), collision
  (T-173's gameplay seam answers ground queries over chunk data), paint
  (T-174).

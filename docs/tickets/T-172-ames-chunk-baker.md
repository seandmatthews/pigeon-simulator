# T-172 — Ames R1 · chunk baker: offline world baking into 256 m tiles

- **Status:** proposed · **Category:** code-optimization · **Ring:** R1 The Map ·
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

- [ ] Bake runs headless in ≤ 60 s on this machine; total chunk payload
      ≤ 40 MB on disk
- [ ] Two consecutive bakes → identical SHA-256 manifest (registered in
      the ticket at landing)
- [ ] *(Gate 1b)* `ames_bake_census` scenario: chunk instance counts sum
      to the pack counts (3,737 massing instances); all 9 crossings and
      every authored position present in some chunk; LaVerne polygon
      area within 2 % of 11,300 m²
- [ ] *(Gate 1b)* `ames_bake_determinism`: re-bake in-scenario → same
      manifest hash
- [ ] *(Gate 1/2)* clean; Windrow world untouched (nothing mounts yet)

## Verification (proposed)

Gate 1 · Gate 1b + two new rows · Gate 2 · no Gate 3.

## Decisions & forks

Chunk size 256 m chosen for MultiMesh frustum-culling granularity and
occluder density; revisit only with a failed perf gate (T-173's budget
is the arbiter, not taste).

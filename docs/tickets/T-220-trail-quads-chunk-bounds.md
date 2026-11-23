# T-220 — Trails vanish with their chunk's houses: trail_quads join the chunk bounds

- **Status:** done · **Category:** visual-design · **Ring:** R6 (owner pick) ·
  **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-172 (the chunk bake + its bounds), T-205 (the `trail_quads`
  family)
- **Refs:** the 2026-11-23 adversarial review (found in the code, then measured
  on the committed bake — twice, by two readers) · owner 2026-11-23: "If you
  think it's correct, then do that"

## What

`AmesBaker._chunk_aabb` grows a chunk's bounds over its massing, placeholders,
dressing, seven flat-quad families, the water/lawn triangles, roofs and trees —
but not `trail_quads`, the T-205 family. The runtime folds every flat family of
a chunk into ONE MultiMesh and culls it by exactly those bounds
(`_add_chunk_mm` → `mm.custom_aabb`), so a trail that runs past its chunk's
houses disappears whenever the houses leave the frustum.

- Add `trail_quads` to the bounds and re-bake (`tools/bake_ames_chunks.gd`).
- Add the invariant the omission broke as a Gate 1b scenario,
  `ames_chunk_bounds_cover_flats`: every flat quad and every water/lawn triangle
  of every committed chunk lies inside that chunk's recorded bounds. It reads the
  geometry straight off the documents (never `_chunk_aabb`), so a family added
  to the renderer but not to the bounds fails here.

## Why

In the committed bake, 10 of the 37 trail-bearing chunks carry 131 trail quads
outside their bounds, overhanging by up to 202.9 m — `chunk_5_-23`'s bounds are
a strip of six houses while its trails run ~200 m north of it. The north parks'
trail ring is T-205's headline; from the air it reads as trails that pop in and
out with the rooftops.

## Acceptance criteria

- [x] After the re-bake, no trail quad sits outside its chunk's recorded bounds
      (the review's probe re-run: 10 chunks → 0)
- [x] The re-bake changes ONLY bounds, and only where the fix explains them: 17
      chunk documents and the manifest — 10 chunks grow in x/z to take in their
      trails, 7 building-free chunks rise 1–2 cm in `max.y` because their trails
      (at 0.06 m) are their tallest geometry; `aabb` is the only key that moves
      in any document, and every other chunk is byte-identical
- [x] Gate 1b: `ames_chunk_bounds_cover_flats` green on the re-baked tree, and
      red against the pre-fix bake (run record below)
- [x] The bake stays deterministic: `ames_bake_determinism` green against the
      re-baked tree
- [x] The bake identity pin re-pinned to the new `total_sha256` (the literal in
      `tests/sim_test.gd` + the VERIFICATION.md line)
- [x] Full Gate 1b green
- [ ] [screenshot] Gate 3: fly Ada Hayden's trail ring low, look along a trail
      with its chunk's houses behind you — the trail stays drawn *(owner)*

## Measured

| | Before | After |
| --- | --- | --- |
| Chunks with trail quads outside their bounds | 10 of 37 trail-bearing | 0 |
| Trail quads outside their bounds | 131 (max overhang 202.9 m) | 0 |
| Bake `total_sha256` | `8f932959…040175` | `663cdea2…34d1f5` |
| Chunk documents changed | — | 17 (+ the manifest) |
| Tiles / schema / payload | 553 / `ames_chunks/v6` / 12.84 MB | unchanged |

The largest bounds moves: `chunk_5_-23` max.z −5849.170 → −5646.289 (203 m),
`chunk_-1_-10` max.x −72.370 → −6.366 (66 m), `chunk_4_-22` max.z
−5556.310 → −5398.427 (158 m), `chunk_3_-21` max.x 845.910 → 991.717 (146 m).

## Verification

Gate 1 + Gate 1b with the new scenario and the re-pinned bake identity. Gate 2
unchanged (no gameplay code moves). Gate 3: the screenshot line above.

## Run record (2026-11-23, direct loop — the owner approved the fix as described)

- **Red before the fix** (new scenario, old bake): `SIM FAIL
  ames_chunk_bounds_cover_flats: prims=26267 chunks_with_prims_outside=10 …` —
  the same 10 chunks and the same per-chunk counts (35, 16, 32, 2, 34, 4, 4, 1,
  1, 1 = 131) an independent python probe measured; **169 PASS / 1 FAIL**.
- **Re-bake:** `tools/bake_ames_chunks.gd` rc 0 in 5.7 s (budget 60 s),
  553 chunks, 12.84 MB. A second run reproduced `total_sha256
  663cdea24241a04edfa393457608e8364ff91d212816216a0b6709ba1f34d1f5` with zero
  bytes changed.
- **What the re-bake moved:** 18 files — 17 chunk documents + `manifest.json`;
  in every chunk document the `aabb` key is the only difference (key-by-key
  comparison against `HEAD`).
- **Gate 1:** `--import` rc 0, the 120-frame boot rc 0, no `ERROR:` /
  `SCRIPT ERROR:` line past the benign exit-cleanup filter.
- **Gate 1b:** **170 PASS / 0 FAIL**, exit 0 — `ames_chunk_bounds_cover_flats`
  (prims=26267, 0 chunks outside), `ames_bake_determinism` against the re-baked
  tree, and no other pin moved.
- **Gate 2:** not re-run — no gameplay code moves.

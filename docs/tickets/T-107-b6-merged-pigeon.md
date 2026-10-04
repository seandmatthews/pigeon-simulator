# T-107 — Adopt the B6 Merged sculpt as the interim player pigeon

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** none (`assets/pigeon_variants/b6_merged.glb` exists from the 2026-10-02 Blender variant exploration)
- **Refs:** `scenes/pigeon_visual.tscn` (primitive build replaced) · `scripts/pigeon_visual.gd` (`_ready` rig made null-safe) · `tests/sim_test.gd` (`pigeon_silhouette_contrast` → `pigeon_b6_sculpt_visual`) · review rig `scenes/pigeon_variants/variants_review.tscn` (untracked, upstream of the pick)

## What

The player pigeon is still the T-011 hand-built primitive bird. The 2026-10-02
Blender variant exploration produced seven candidates and the user picked
**B6 Merged** ("b6_merged should be our new pigeon for now"). This ticket
instances that sculpt as the pigeon presentation while keeping the whole
`PigeonVisual` `drive()` contract the player and the sim harness depend on.

## Why "interim"

The sculpt is a static folded-pose mesh: the wing/head pivots keep their pose
math (the harness reads stay truthful) but nothing visual articulates — no
flap beats, waddle head-bob or beak peck on the model itself. The ROOT
cosmetics still play (grounded squat, waddle bob + sway, peck body lean). A
rigged replacement is future work.

## Change

- `scenes/pigeon_visual.tscn`: primitive meshes → one instanced
  `b6_merged.glb` ("Model"), plus empty `HeadPivot`/`WingL`/`WingR` pivots so
  `drive()` keeps its node contract. The sculpt's native forward is −Z — the
  same convention as the old cone beak — so no reorientation is needed.
- `scripts/pigeon_visual.gd`: `_ready()`'s primitive-rig cosmetics become
  null-safe (each applies only when its node exists); docstring updated.
- `tests/sim_test.gd`: `pigeon_silhouette_contrast` (gated flat primitive
  albedos against district palettes — meaningless on a textured mesh) is
  replaced by `pigeon_b6_sculpt_visual`: asserts the presentation carries a
  child scene sourced from `b6_merged.glb` with meshes, and that `drive()`
  still tracks glide/fold sweeps.

## Acceptance criteria

- [x] The player's pigeon renders the B6 Merged sculpt, beak-forward and pigeon-scaled in the streets (pilot grab `.captures/session_b6adopt/window.png`; headless probe: model spans 0.74 × 0.57 × 0.80 m, ground line y −0.29 — same class and grounding as the T-011 build)
- [x] Gate 1 + 1b + 2 pass with the swap in (import exit 0; `SIM SUMMARY: 0 failure(s)`; `AUTOPLAY DONE ok=true` fps 137, poses DIVE/FLAP/GLIDE/PECK/STAND/WADDLE)
- [x] Pose contract preserved: air/ground/peck scenarios stay green (they read the retained pivots + script properties, untouched)
- [ ] Gate 3: human pass — the sculpt reads as a pigeon against road/roof/sidewalk palettes; texture contrast, scale, orientation (pending human eyes). Note: the sculpt's albedos are linear-space PALER than the old build (body sRGB ≈ 0.65 vs 0.38) — that is the B-series' intended pale game-asset look, but the wash-out risk against the pale sidewalk is exactly what this line asks a human to judge.

## Tuned values

None — the sculpt ships as-authored (no scale/rotation/material overrides; the
file's own factors are correct, metallic 0 / roughness 0.85 on the body).

## Verification

Gate 1b `pigeon_b6_sculpt_visual` (automated presence + pose tracking); the
look itself is a Gate 3 line (textured model, human judgement).

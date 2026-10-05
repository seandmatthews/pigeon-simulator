# T-108 — Adopt the realistic Blender pigeon as the player bird

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** the T-104 realistic pigeon asset (built in the Blender art
  workspace and delivered as the `blender-pigeon-checkpoint-v1` checkpoint;
  that ticket's Godot import + gameplay checks were the standalone dry run)
- **Refs:** `scenes/pigeon_visual.tscn` (b6 instance → realistic instance with
  a measured fit transform) · `scripts/pigeon_visual.gd` (docstring) ·
  `tests/sim_test.gd` (`pigeon_b6_sculpt_visual` → `pigeon_realistic_visual`)

## What

The player pigeon is still the T-107 interim B6 Merged sculpt. T-104 delivered
the user-commissioned realistic blue-bar rock pigeon — one GLB, two PBR
surfaces, 64,697 triangles, 2048 px embedded albedo/normal/roughness, meter
scale, ground origin, static folded-wing pose. This ticket makes that bird the
visible player pigeon while keeping the whole `PigeonVisual` `drive()` contract
the player and the sim harness depend on.

## Fit math (measured, not eyeballed)

Headless AABB probe of both imported sculpts (probe script deleted after use):

| Sculpt | Size (X × Y × Z, m) | Ground line y |
| ------ | ------------------- | ------------- |
| b6_merged | 0.74 × 0.57 × 0.804 | −0.29 |
| pigeon_realistic | 0.094 × 0.230 × 0.309 | +0.0009 (origin at the feet) |

The asset ships at real-world pigeon scale; the city, collision sphere
(r = 0.3) and camera arm were tuned on the b6 class. **Scale 2.6** matches the
realistic bird's 0.309 m length to b6's 0.804 m (height lands at 0.60 m vs
0.57 — same class; width stays narrow because the realistic pose folds the
wings). **Position.y −0.292** drops the feet onto b6's exact ground line, so
grounded contact, the waddle bob and the peck lean read exactly where they did
before. No rotation: both sculpts face −Z natively.

## Change

- `assets/models/pigeon_realistic/` — `pigeon_realistic.glb` (textures
  embedded), its `.import` sidecar and `asset_stats.json`, copied from the
  checkpoint at the asset's authored in-game path.
- `scenes/pigeon_visual.tscn`: the "Model" instance swaps b6 → realistic with
  the fit transform above; `HeadPivot`/`WingL`/`WingR` pivots retained.
- `scripts/pigeon_visual.gd`: docstring updated (T-107 → T-108); no code
  changes — the static-mesh limitation (no visible wing beats, no mesh peck)
  carries over unchanged.
- `tests/sim_test.gd`: `pigeon_b6_sculpt_visual` → `pigeon_realistic_visual`
  (asserts a child scene sourced from `pigeon_realistic.glb` with meshes, and
  the same glide/fold sweep tracking).

## Acceptance criteria

- [x] The player's pigeon renders the realistic asset at the b6 size class and
      ground line (measured AABB fit above)
- [x] Gate 1 passes: import exit 0 with no new ERROR lines (the one
      "33 resources still in use at exit" shutdown line reproduces identically
      on HEAD — pre-existing baseline, per the T-104 notes); boot exit 0 with
      only the known ObjectDB warning
- [x] Gate 1b passes: `SIM SUMMARY: 0 failure(s)` with `pigeon_realistic_visual`
      green (117 scenarios)
- [x] Pose contract preserved: air/ground/peck scenarios stay green (they read
      the retained pivots + script properties, untouched)
- [x] Gate 2 passes: `AUTOPLAY DONE ok=true` fps 136, poses DIVE/FLAP/GLIDE/PECK/STAND/WADDLE — the DONE line byte-identical to HEAD's (deterministic autoplay unaffected by the swap)
- [x] Agent eyes-on pre-check (pilot session `t108look`): grounded on the plaza street with feet on the ground line and the beak pointing away from the chase camera; airborne glide centered over the street with the poop reticle live
- [ ] Gate 3: human pass — the realistic bird reads as a pigeon airborne and grounded (beak-forward orientation, texture contrast against road/roof/sidewalk), and the T-104 realism review (scalp smoothness, neck feather regularity) remains pending from the art side.

## Tuned values

Model instance scale 2.6, position.y −0.292 (measured fit — see "Fit math").
Everything else ships as authored; materials are the GLB's own PBR factors.

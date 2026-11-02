# T-142 — The café sitters wear the one people model: seated-pose bakes replace the box crowd

- **Milestone:** People-model audit follow-up (owner ask 2026-11-02, same
  playtest as T-141: "check all benches and tables and so on by the
  street/outside of shops — make sure that all things that are supposed to
  look like humans use the new human model") · **Status:** done 2026-11-02 ·
  **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-138 (the one people rig, landed), T-141 (the seated
  geometry this bake poses, landed), T-094 (the café batch whose perf
  contract this must keep, landed)
- **Refs:** `scripts/cafe_spawner.gd` (the batch + collider contracts),
  `tools/import_people_rig.gd` (the import pipeline that gains the bake),
  the retired T-124 people bake (`git show e2dff98:tools/bake_people_cars.gd`
  — the frame-flush trick and the skinning math precedent), the audit table
  in the T-141 ticket.

## What

The audit (owner ask above) found exactly one human-shaped thing still on
the old box model: the ~150 café sitters outside the awninged buildings
(`CafeSpawner` builds them from `BoxMesh` torso/head/hair/arms/thighs —
the retired `cafe_table.gd`'s T-031 primitives, batched per T-094).
Everything else is already on the new model or is not a human: plaza +
park elders (T-138/T-141), strolling tourists (T-138), street benches (no
humans sit on them), cars (baked vehicle meshes, no rendered people —
T-138's explicit "cars are not humans"), the plaza statue (a stylized
landmark, explicitly not claimed by T-138).

**The swap:** the import pipeline (`tools/import_people_rig.gd`) gains a
seated-pose bake — it samples `Rig|Sitting_Idle` (frame 0, the old bake's
advance-1/30 flush), skins the Body + ArmL + ArmR partitions through the
posed skeleton into ONE static shirt-tintable mesh, and the Legs and Head
partitions into two static fixed-color meshes, all in the rig-root space at
the adult 0.982 scale, metadata-stamped (source pack/license/pose clip)
and emitted as HIDDEN `SitBake/*` nodes inside the imported scene. Nothing
lands in `assets/` (the T-138 law); no new clip is imported (the whitelist
audit survives); the live rig is untouched.

`CafeSpawner` harvests the three meshes from `people_rig.tscn` (the ONE
people source) at populate time and feeds its existing MultiMesh batch:
`sit_body` (1 instance per sitter, per-instance shirt colors — the same
tourist-palette law), `sit_legs` / `sit_head` / `sit_hair` (1 each, fixed
denim/skin/brown). The retired box keys (`sitter_torso`, `sitter_arm`,
`sitter_head`, `sitter_hair`, `sitter_thigh`) die. Instance count per
sitter drops 7 → 4. The merged `Tables`/`Sitters` bodies, the colliders,
the seat/yaw transforms and every gameplay contract (T-112 tabletop
crumbs, T-114 steal, the layer values) stay byte-identical.

**Why a bake and not live rigs:** T-094 batched the café precisely because
~260 live node graphs were too heavy; sitters are static scenery that never
plays a clip. T-138's "the bake era ends for people" retired the RUNTIME
bake pipeline (static figures standing in for moving people) — a one-time
import-time pose bake of the SAME model for a never-moving, batched crowd
is the only architecture that satisfies both the one-model law and the
batch perf law. The bake lives in the import (nothing derived ever lands
in `assets/`, the T-138 precedent).

## Known pin breaks, amended in the same change-set

- `city_cafe_tables_present` reads the `sitter_torso`/`sitter_arm` keys
  (counts 1×/2× per sitter + per-instance shirt colors) → rewritten to the
  new keys (`sit_body`/`sit_legs`/`sit_head`/`sit_hair`, 1× each, shirt
  colors on `sit_body` by the unchanged spot+seat law). The collider,
  layer, clearance, perch and waddle-stop legs pass untouched.
- VERIFICATION.md's `city_cafe_tables_present` row names the torso/arm
  keys → reworded.
- New Gate 1b scenario `cafe_sitters_on_the_rig`: the sit keys' meshes
  carry the stamped metadata (source pack, CC0, `pose_clip ==
  Rig|Sitting_Idle`), one instance per sitter on every key, `sit_body`
  tinted by the exact shirt law, the old keys absent (swap tripwire), and
  the baked seated figure measures human (AABB ≈ the probe's seated
  envelope — catches scale drift against the rig's 0.982 adult factor).

## Not claimed

- Sitter variety (every sitter is the same figure in a different shirt —
  true of the box crowd too).
- Live clip playback at the café (they never stand up; the T-137 shuffle
  is elders-only).
- Cars, the plaza statue, street benches (no humans), the elders (T-141).

## Acceptance criteria

- [x] The import emits hidden `SitBake/SitBody|SitLegs|SitHead` static
      meshes posed at `Rig|Sitting_Idle`, adult-scaled, metadata-stamped;
      the glb re-imports clean and the FULL existing suite stays green (the
      live rig untouched).
- [x] `CafeSpawner` renders the crowd from the baked meshes (new keys,
      shirt law on `sit_body`, colliders byte-identical); the retired box
      keys are gone.
- [x] (Gate 1b) `cafe_sitters_on_the_rig` green + the amended
      `city_cafe_tables_present` green + FULL suite 0 failures.
- [x] (Gate 3, screenshot) A café table reads as people (new model) seated
      at it, shirts varied — captured in `.captures/t142_cafe/`
      (`cafe_sitters_closeup.png`: lilac + teal sitters facing their table,
      hair boxes on the heads; `cafefix2_midshot.png`: the same crowd from
      the road). The owner feel-pass stays the pending human judgement.
- [x] VERIFICATION.md rows amended/added in the same change-set.

## Implementation record (2026-11-02)

**The bake.** `tools/import_people_rig.gd` grew `_bake_seated` +
`_posed_globals`: the sit pose's bone globals are computed BY HAND (local
poses default to the bone rest, the `Rig|Sitting_Idle` track values
overwrite them via the typed interpolators, globals chain parent→child
through `get_bone_parent`), then each partition build's vertices skin
through `posed(b) × bind⁻¹(b)`, pass out through the root chain
(`accum`, the ×100 import scale) and the 0.982 adult factor. Three meshes
(SitBody = body + both arms, shirt-tintable; SitLegs = denim; SitHead =
skin) hang as HIDDEN children named to avoid the live parts' `_find_part`
namespace. The probe-measured result sits exactly on the clip geometry the
elders use: feet −0.013 / hips ~0.52 / head 1.05–1.40 in root space.

**Two import-context lessons (the reason the bake took four rounds):**

1. **Nothing animation-related runs at import.** The scene is not in a
   tree: `AnimationPlayer.advance()` no-ops and `Skeleton3D`'s pose caches
   never flush (`set_bone_pose_*` + `force_update_all_bone_transforms`
   left `get_bone_global_pose` at rest — measured, not assumed). The
   retired T-124 bake only worked because it ran in a live SceneTree.
   Hence the hand-computed pose chain — pure math, tree-free.
2. **`Animation.track_interpolate` does not exist in Godot 4.7** — the
   typed `position_/rotation_/scale_track_interpolate` are the API (and
   `Basis(quat, scale)` isn't a constructor — `Basis(quat) *
   Basis.from_scale(scale)` is).

**The spawner.** `_populate` harvests the three meshes from
`people_rig.tscn` (the ONE people source) and queues `sit_body` (tinted,
per-instance colors — the MultiMesh channel the box crowd used) /
`sit_legs` / `sit_head` / `sit_hair`, one instance per sitter (7 box
instances → 4). The instance sinks `SIT_ROOT_Y = 0.45 − 0.5179` so the
pose's hips rest on the 0.45 m stool (feet land ~0.02 above the pavement);
the hair box keeps its brown but derives its offset from the baked head's
own AABB, sunk past the scalp line. Colliders, layers, seat/yaw transforms
and every gameplay contract are byte-identical.

**Gates.** Full suite green: `SIM PASS elder_seats_on_the_bench` + `SIM
PASS cafe_sitters_on_the_rig` + `SIM PASS city_cafe_tables_present` + `SIM
SUMMARY: 0 failure(s)` (log `/tmp/sim_t142.log`, 2026-11-02).

**Human playtest (pending):** owner to confirm the café crowd reads right
in play — in particular the shared single seated pose (every sitter is the
same figure in a different shirt, true of the box crowd too) and the
hair-box read at distance.

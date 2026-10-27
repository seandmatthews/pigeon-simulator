# T-139 — Fix the elder's giant far arm: the import split baked the skinned arm's vertices ×100

- **Milestone:** People rig follow-up (owner playtest 2026-10-27: "enormous
  blobs clipping through the world") · **Status:** done 2026-10-27 ·
  **Category:** visual-design · **Value (1-5):** 5 · **Risk (1-5):** 2
- **Depends on:** T-138 (the live people rig this fixes, landed)
- **Refs:** `tools/import_people_rig.gd` (the split), `scripts/people_rig.gd`
  (the runtime half, unchanged), the raw pack glb (ground truth: ONE
  Mannequin mesh, both primitives in one ~1/100 space, ×100 on the node).

## What

Every elder renders an ~85 m arm slab centered on themselves — the
"enormous blobs" the owner saw from altitude (four plaza elders = four
colored blobs) and at street level (walls swallowing intersections).
Tourists hide the skinned left arm (rigid arms are correct), so only
elders show the corruption.

Root cause (probe-measured 2026-10-27): in the import split,
`_append_vertex` took the rigid bake branch for any part in
`RIGID_MAIN_BONES` — which includes `arm_l` — so the SHARED partition build
for `arm_l` was baked into the main bone's meter frame, and
`_emit_skinned("arm_l", "ArmL")` then consumed those meter-space vertices
as a SKINNED mesh wearing the full bind skin, which assumes mannequin space
(~1/100). Net: the skinned arm renders ×100 (world AABB 85.8 m vs the
correct ≈0.86 m). Body/Legs (verbatim branch) were never affected.

Fix: partition vertices stay verbatim for every part; the bake into the
main bone's bind frame moves into `_emit_rigid` (its only consumer), with
identical math. The glb re-imports; nothing else changes — the rigid parts'
output is byte-identical, the skinned arm joins Body/Legs' (correct) path.

## Acceptance criteria

- [x] Census: no citizen part's world AABB exceeds 3 m (the bug measured
      85.8 m; correct parts are ≤ 0.86 m). Post-fix census over the full
      live Main scene: exactly ONE instance above 8 m — the 734 m ground
      plane (intended); all 18 pre-fix tourist ArmL monsters gone.
- [x] New Gate 1b scenario `citizen_parts_world_scale` pins that cap
      (red-before the fix was trivially red at 85.8 m — the scenario walks
      the same live rig AABBs the census measured, capped at 3.0 m).
- [x] Full Gate 1b suite green — 0 failures, `people_on_one_rig` untouched
      and passing.
- [x] Eyes-on (pilot session `t139-elder-1027`, 2026-10-27): the plaza —
      the blob ground zero — shows the seated elder with both arms at human
      scale against the 0.60 m bench, hair prop mounted, every tourist
      pedestrian correctly sized; the streets that swallowed intersections
      under 85 m slabs are clean from every angle flown.
- [x] No gameplay/literals change: the rigid bake math moved verbatim
      (ArmLRigid/ArmRRigid/HeadRigid AABBs byte-identical after re-import);
      the HandR slot, adult envelope and stride constants untouched.

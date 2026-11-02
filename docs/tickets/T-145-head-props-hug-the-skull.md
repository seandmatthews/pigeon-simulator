# T-145 — Head props hug the skull: the elder's hair (and the tourist cap) still read as floating planks

- **Milestone:** Owner verification ask 2026-11-02 ("can you confirm that
  the elders' hair is fixed?") — the zoom said NO · **Status:** done
  2026-11-02 · **Category:** visual-design · **Value (1-5):** 3 ·
  **Risk (1-5):** 1
- **Depends on:** T-138 (the rig mount this re-derives), T-141 (whose hair
  resize this completes — the size shrank, the read did not fix)
- **Refs:** `scripts/people_rig.gd` (`_process` mount correction,
  `HEAD_PROP_LIFT`), `scenes/elder.tscn` (Hair), `scenes/tourist.tscn`
  (Cap), the zoom evidence `.captures/t144_hair/head_zoom_7m.png`.

## What

The T-141 verification pass zoomed an elder's head at ~7 m and the hair is
still wrong: a white plank balanced on the crown's back, sky visible under
its rear overhang, displaced backward off the skull. Two compounding
causes, both mount-level:

1. **The mount pins above the BONE, not the MESH.** The frame-1 correction
   targets `bone_world.y + HEAD_BONE_TO_TOP + lift` with `want.x/z` at the
   bone's XZ — but the head mesh's visual center rides ~0.07 m forward of
   the head bone (the face). Every head prop therefore mounts ~0.07 m
   behind the skull's center: the backward float.
2. **The props are plank-proportioned.** The elder hair (0.30 × 0.10 ×
   0.32 after T-141) and especially the tourist cap (still the T-113-era
   **0.46 × 0.16 × 0.46**) center on the crown line and overhang the
   skull's curve — the head is 0.275 × 0.34 × 0.258.

**Fix.** The mount correction now pins the HeadTop slot to the HeadRigid
mesh's own BIND-FRAME AABB top-center — HeadTop hangs under HeadRigid, so
the prop tracks the exact mesh in every pose (idle, sit pitch, walk bob),
and the prop centers on the skull instead of the bone. The props get cap
proportions: elder hair **0.28 × 0.08 × 0.26** (bottom kisses the crown:
lift 0.04 − half 0.04 = 0; depth flush with the head's 0.258), tourist cap
**0.30 × 0.10 × 0.30** (bottom 0.01 sunk into the crown). `HEAD_BONE_TO_TOP`
stays (the adult-envelope pin and the T-141 scenario metric read it).

## Known pin breaks, amended in the same change-set

- `elder_seats_on_the_bench`'s hair-lift band re-verified against the
  mesh-pinned slot (expected to hold: the mesh top in the seated pose sits
  within the existing −0.05/+0.10 band).
- `citizen_classes_readable` pins the cap VISIBLE, not its size — expected
  green untouched.

## Not claimed

- Hair shape/color variety (a flat gray cap is the art style; variety is
  IDEAS material).
- The café sitters' hair boxes (a separate AABB-derived mount that already
  seats them correctly — verified in T-142's café shots).

## Acceptance criteria

- [ ] (Gate 3, screenshot) The zoomed elder head reads hair-ON-skull — no
      sky gap, no backward float — before/after in `.captures/t144_hair/`;
      a superfan's cap reads as a gold cap, not a gold slab.
- [ ] (Gate 1b) FULL suite green including `elder_seats_on_the_bench` and
      `citizen_classes_readable` untouched.

## Implementation record (2026-11-02)

**The mount.** The frame-1 correction now sets the HeadTop slot DIRECTLY to
the HeadRigid mesh's bind-frame AABB top-center
(`(center.x, end.y + lift, center.z)`) — HeadTop hangs under HeadRigid,
whose mesh is authored in the same bind frame, so the prop tracks the
exact mesh in every pose. Measured mesh AABB: pos (−0.138, −0.080,
−0.148), end (0.138, 0.260, 0.110) — the slot rides end.y + lift.

**The float's second cause — the yaw leveling itself.** With the mesh pin
landed the zoom STILL floated, and the reconciliation landed on
`_align_prop_yaw`: it replaced the prop's whole basis with a LEVEL
body-yaw box, stripping the head bone's ~25° sit-pitch — a level box on a
nodded skull leaves sky under its back edge. The props now take the bone
frame IDENTITY (pitch rides along, the head nods, the hair stays glued);
the dead `_align_prop_yaw` is deleted (the late-mount path takes identity
too). **The owner confirmed the hair on this build** ("The hair looks
like it's attached to the head").

**The props.** Elder hair 0.30 × 0.10 × 0.28; tourist cap 0.46 × 0.16 ×
0.46 → **0.30 × 0.10 × 0.30** (the T-113-era slab proportions). Shared
`HEAD_PROP_LIFT` −0.05: the slot sinks 0.05 below the mesh top, so a
box wider than the dome wraps the skull's upper quarter as a band — the
crown pokes just past the box's top plane (the grandpa bald-crown read).
`HEAD_BONE_TO_TOP` stays for the envelope pin.

**Gates.** Full suite green mid-flight (`citizen_classes_readable` with
the resized cap, `elder_seats_on_the_bench` with the new lift, `SIM
SUMMARY: 0 failure(s)`); the final suite re-runs with the T-146 sink
(see that ticket — the two land back-to-back).

**Human playtest:** the hair leg is CLOSED by the owner's own
confirmation on this build.

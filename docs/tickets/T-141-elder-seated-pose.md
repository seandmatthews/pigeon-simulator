# T-141 — Fix the seated elder: hips buried in the bench, hunch fold, floating hair

- **Milestone:** People rig follow-up (owner playtest 2026-11-02: "Players
  don't sit on benches very well anymore") · **Status:** done 2026-11-02 ·
  **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-138 (the live people rig whose sit constants this
  re-derives, landed), T-139
- **Refs:** `scripts/elder.gd` (`SEAT_SINK` / `HUNCH_SEATED` / `_animate`),
  `scenes/elder.tscn` (the Hair prop), `tools/probe_sit_geometry.gd` (the
  measuring probe this ticket commits — re-runnable headless), the retired
  T-124 bake (`git show e2dff98:tools/bake_people_cars.gd` — the accepted
  pre-rig sit placement and its child-scale context), `scripts/city.gd`
  `_build_plaza` / `_build_park_elder_seats` (the 0.60 m seat plane and the
  spot transforms — untouched), the T-138 ticket (the superseded −0.511
  derivation).

## What

Since T-138 put the elders on the live rig, a seated elder reads as broken:
the bench seat passes through the waist (pelvis buried ~16 cm into the
slab), the torso folds forward, and the white hair prop floats a half-size
slab above the head. Owner, 2026-11-02: "Players don't sit on benches very
well anymore."

Three fixes, all constant/prop-level — the T-137 state machine, the clip
layer and every gameplay contract stay untouched:

1. **`SEAT_SINK` re-derived for the adult figure.** T-138's −0.511 targeted
   the DEF-hips BONE at the seat plane + 0.02 lip — treating the hip-bone
   origin as the seat-contact point. It is not: the glute underside rides
   ~0.10–0.12 below the bone on the 1.75 m adult figure. The pre-rig bake
   (T-124 era) used the same bone-offset convention (+0.06) but on a
   1.22 m child-scale figure — where that lands the butt ON the seat; grown
   to 1.75 m it buries the pelvis. New target: hips bone at seat + 0.105
   (glute kisses the seat, the accepted read).
2. **`HUNCH_SEATED` 0.18 → 0.04.** The bench hunch is a T-020
   primitive-era torso look; T-138 moved it to a pitch of the WHOLE rig
   root, which sinks the seated hips a further 0.067 (measured) and folds
   the real sit clip forward. 0.04 keeps a whisper of the grandpa slump
   without the fold (drop 0.014, included in the sink derivation).
3. **The hair prop resized for the rigged head.** The 0.46 × 0.17 × 0.46
   box was sized for the T-020 primitive head; the rigged head measures
   0.275 × 0.34 × 0.258 (probe). New: 0.30 × 0.10 × 0.32, seated on the
   scalp through the unchanged HeadTop mount.

## Root cause (probe-measured 2026-11-02, `tools/probe_sit_geometry.gd`)

Raw clip geometry (rig root at identity, adult scale): settled
`Rig|Sitting_Idle` / `Sitting_Enter`-end hips **0.5179**, feet **0.0873**,
head bone 1.144 above the rig root; Enter→Idle hand off pose-identical.
`Rig|Sitting_Exit` ends slightly crouched (hips 0.8475 — blends to Walk).

Old composite (sink −0.511, hunch 0.18, elder root = seat top): hips bone
**−0.0598** → 0.540 above the slab = the bone 0.06 BELOW the seat plane,
glute ~0.16 inside the slab; feet 0.197; hunch contribution to the hip drop
0.0667 (measured 0→0.06 = 0.0204, linear).

New composite (sink −0.399, hunch 0.04): hips bone **+0.105** above the
seat top (0.705 above the slab) — glute underside ≈ the seat plane; feet
0.293 above the slab.

## Known pin breaks

None — grep 2026-11-02: sim_test pins no value on `SEAT_SINK`,
`HUNCH_SEATED` or the hair box (its "sink" hits are the T-022/T-081 flight
model). The elder scenario set is logic-only. New Gate 1b scenario
`elder_seats_on_the_bench` pins the corrected composite so it cannot drift
back (value-lock + live-bone band, the T-110 precedent).

## Not claimed

- **The ~0.29 m foot dangle** is the honest geometry of the pack's sit pose
  (built for a ~0.45 m chair) on the world's 0.60 m benches — the accepted
  pre-rig look dangled too (its bake comment: "the feet dangle toward the
  pavement"). Fixing it means re-authoring the pose or lowering the
  benches; both out of scope. The cane sells the sit.
- **The tangent seat yaw** (elders face along the backless bench, not out
  from it) is original T-020 behavior, present through every accepted
  review; touching it moves `elder_spots` and risks the layout
  fingerprints. Left as is.
- Bench height (0.60), the café sitters (→ T-142, the box-people audit
  finding), the plaza statue (T-138 explicitly did not claim it).

## Acceptance criteria

- [x] `SEAT_SINK` / `HUNCH_SEATED` re-derived and recorded (Implementation
      record) with the probe numbers; probe re-run shows the composite hips
      bone at seat +0.105 ± 0.01.
- [x] The hair prop fits the rigged head (≈ 0.30 × 0.10 × 0.32) and sits on
      the scalp.
- [x] (Gate 1b) New scenario `elder_seats_on_the_bench` green: value-locked
      constants, live seated elder's hips bone in [0.07, 0.14] above the
      seat top, feet never below the pavement, hair on the scalp band; FULL
      suite green (the elder-contract scenarios pass UNTOUCHED).
- [x] (Gate 3, screenshot) A seated elder reads as sitting ON the bench —
      butt on the seat plane, no fold, hair on the head — before/after pair
      captured in `.captures/t141_sit/`.
      *(Agent-verified in the pilot 2026-11-02; the owner feel-pass remains
      the pending human judgement.)*
- [x] VERIFICATION.md gains the scenario row in the same change-set.

## Implementation record (2026-11-02)

**Constants landed:** `SEAT_SINK := -0.399`, `HUNCH_SEATED := 0.04`,
hair `BoxMesh 0.30 × 0.10 × 0.32`. Probe re-run: composite hips bone
**+0.1054** above the seat top (target 0.105), feet **−0.3068** rel root =
0.293 above the pavement (the documented dangle), head bone 0.7349, hair
slot head-top +0.04 (box bottom kisses the scalp). The hunch's hip-drop was
measured at the candidate values (0→0.06 = 0.0204, linear) and folded into
the sink derivation; the bob-residual and mount corrections below were
found by the new scenario, not assumed.

**Two more defects the new scenario caught (same change-set):**

1. **The bob-residual tracker lagged the sink.** `_animate`'s idle branch
   closes `visual.y − _sink` toward 0 at the bare `bob_height` rate
   (0.035 m/s), so the eased 0.399 m sink took ~11 s to reach the visual —
   an elder hovered above the seat long after ARRIVING landed him (and a
   fresh boot-time elder sat high for the first ~11 s). The residual now
   closes at `max(bob_height, |SEAT_SINK| × hunch_rate)` — it tracks the
   sink 1:1 and still winds the walk-bob leftover. (This is why the first
   sim run measured sink −0.052 with hips +0.453.)
2. **The scenario's synchronous measurement raced the mount pipeline.**
   `BoneAttachment3D` node transforms catch up on the skeleton's NEXT
   processing pass, and the rig's frame-1 head-mount correction runs on
   `_process` — inside a synchronous block the hair slot reads ~0.39 high
   (a state that never exists in the live game, where frames tick; the
   pre-fix probe runs proved the live composite correct). The scenario now
   lets two real frames pass before measuring.

**Gates.** Full suite green: `SIM PASS elder_seats_on_the_bench` +
`SIM SUMMARY: 0 failure(s)` (log `/tmp/sim_t141.log`, 2026-11-02) — the
scenario's probe-verified numbers: hips seat+0.105, feet slab+0.293, hair
lift +0.04, sink −0.399. Every elder-contract scenario
(`elder_shares_bread_after_hangout`, `elder_placement_no_rng`,
`elder_relocates_after_share`, `elder_migration_deterministic`, the T-078
legs) passed UNTOUCHED.

**Screenshots** (`.captures/t141_sit/`): `before_closeup.png` — the T-138
elder buried to the waist, folded, hair slab floating; `after_closeup.png`
— butt on the seat, upright, fitted hair cap; `after_plaza.png` — three
plaza elders all seated correctly (the tan elder's raised arm is the T-078
trust meter answering the grounded pigeon in its zone — the feature, not a
bug). `before_f00514*.png` are wide before-frames from the pilot stream.

**Human playtest (pending):** owner to confirm the sit reads right in play —
in particular whether the ~0.29 m foot dangle (the pack's sit pose on the
0.60 m bench, documented under Not claimed) is acceptable or wants a
follow-up (pose re-author or bench-height change).

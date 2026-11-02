# T-144 — The elders keep their hands down: retire the T-078 trust arm

- **Milestone:** Owner playtest 2026-11-02 (after T-141/T-142/T-143: "The
  elders raising their hands is silly. Can we just get rid of that?" —
  clarified in the same breath: "I want to keep the elders. I just don't
  want them raising their arms") · **Status:** done 2026-11-02 ·
  **Category:** gameplay · **Value (1-5):** 3 ·
  **Risk (1-5):** 2
- **Depends on:** T-078 (the trust arm this retires), T-114 (the favor
  gate layered on the trust path — untouched), T-137/T-138 (the state
  machine and rig the arm rode — untouched)
- **Refs:** `scripts/elder.gd` (the meter), `scripts/people_rig.gd`
  (`set_arm_pose` — stays, the tourists' panic raise uses it),
  `tests/sim_test.gd` (`elder_shares_bread_after_hangout`'s meter legs,
  `people_on_one_rig`'s geometric raise leg).

## What

The elders' near arm is the T-078 trust meter: it eases up with banked
trust while the pigeon hangs out, pins down through the share cooldown,
and sweeps up for the share beat. The owner reads it as silly — removed
entirely. The elders' hands ride the clips like every other citizen's:
the near rigid right arm keeps its cardigan sleeve and follows its bone
(identity on the BoneAttachment), the far arm keeps riding the skinned
ArmL. No elder arm ever lifts again.

**Unchanged, deliberately:** the trust path itself (accrual while a
grounded pigeon is present, decay when alone, the `trust_needed` share,
the cooldown), the T-114 favor gate on top of it, the T-137 shuffle, the
T-138 clips/sink/hunch, the tourists' panic raise and foam finger (their
`set_arm_pose` driver stays). The trust read the arm gave is simply gone —
the share (crumbs at your feet) and the HUD favor meter are the feedback.

## Known pin breaks, amended in the same change-set

- `elder_shares_bread_after_hangout`: the T-078 meter legs
  (`arm_meters_trust` rising read, `arm_down_while_away`,
  the post-share `_arm_raise` pin) leave; the trust-accrue/decay, share,
  spend, cooldown and T-137 migration-launch legs stay and now carry the
  scenario.
- `people_on_one_rig`: the geometric raise leg (staging `_arm_left`,
  requiring `_arm_raise` ≥ 0.95 with the hand lifted > 0.4 m) inverts into
  the removal tripwire — with FULL trust staged, the near hand stays on
  the sit clip (lift < 0.2 m), so a reinstated meter fails by
  construction.
- VERIFICATION.md's two rows reworded.

## Acceptance criteria

- [x] `elder.gd` carries no arm-meter code (no `_arm_*` members, no beat
      exports, no `set_arm_pose` call); the near arm wears the cardigan
      and rides the clip.
- [x] (Gate 1b) the amended `elder_shares_bread_after_hangout` and
      `people_on_one_rig` green; FULL suite 0 failures — every trust /
      share / favor / migration scenario passes.
- [x] (Gate 3, screenshot) A hanging-out elder reads hands-down natural —
      in `.captures/t144_hands/` (`plaza_arms_down.png`: the plaza ring
      with all three elders hands-down; `hangout_arms_down.png`: the near
      bench elder with the pigeon approaching — the exact framing where
      the T-078 meter used to lift).
      *(Owner feel-pass pending as the human judgement.)*
- [x] VERIFICATION.md rows reworded in the same change-set.

## Implementation record (2026-11-02)

**The removal.** `elder.gd` lost the whole meter: the `Beat` export group
(`arm_raise_seconds` / `arm_raise_rate`), the `_arm_left` / `_arm_target`
/ `_arm_raise` members, the `_physics_process` target block (share beat →
cooldown pin → trust fraction), the `_share` beat staging and the
`_animate` drive (`set_arm_pose(ARM_R, …)` — the call is the tourists'
now). The near rigid right arm keeps its cardigan `material_override`
and rides its BoneAttachment with an identity transform — the clip swing
moves it; the far arm keeps riding the skinned ArmL. `people_rig.gd`'s
`set_arm_pose` stays (the tourists' panic raise / foam finger). The
trust path — accrual, decay, `trust_needed`, the cooldown, the T-114
favor gate — is untouched and now invisible bookkeeping.

**The pins.** `elder_shares_bread_after_hangout` carries the scenario
without the meter legs (bank → decay → share → exact spend → cooldown +
T-137 migration launch). `people_on_one_rig`'s raise leg inverted into
the structural retirement tripwire: after stepping the elder's own
`_animate`, the near rigid arm's basis reads IDENTITY — a reinstated
meter's world-aimed `set_arm_pose` write would tilt it away and fail by
construction.

**Gates.** Full suite green: all nine elder scenarios (`elder_shares_
bread_after_hangout`, `elder_bread_gates_on_favor`,
`elder_placement_no_rng`, `elder_no_bread_airborne`,
`elder_cooldown_blocks_second_share`, `elder_relocates_after_share`,
`elder_migration_deterministic`, `elder_seats_on_the_bench`) +
`people_on_one_rig` + `SIM SUMMARY: 0 failure(s)` (log
`/tmp/sim_t144.log`, 2026-11-02). Pilot: the plaza ring's three elders
all read hands-down at rest and with the pigeon approaching
(`.captures/t144_hands/`).

**Human playtest (pending):** owner confirms the hands-down elders read
right in play — and whether the lost "elder is warming to you" signal
wants a replacement read someday (IDEAS material, not this ticket).

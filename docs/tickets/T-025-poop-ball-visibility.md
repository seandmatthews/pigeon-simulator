# T-025 — Make the falling dropping trackable: bigger ball, soft emission

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-006 (poop mechanic, landed)
- **Refs:** `docs/DESIGN.md` → scoring loop (leading targets is core play); visual-design lane plan, sweep 1 (2026-09-29)

## What

Two property edits inside `scenes/poop.tscn`, nothing else:

1. **BallMesh** (`scenes/poop.tscn:8-11`): `radius` 0.07 → **0.12** and `height`
   0.14 → **0.24** (height stays 2×radius). The drop's visible diameter grows
   0.14 m → 0.24 m — at chase-cam distance that is the difference between a
   sub-pixel speck and a readable dot.
2. **Mat_ball** (`scenes/poop.tscn:5-6`, albedo (0.94, 0.9, 0.78)): add
   `emission_enabled = true`, `emission = Color(0.85, 0.78, 0.55)`,
   `emission_energy_multiplier = 0.55` — a soft warm self-glow that keeps the
   drop's read inside building shade, where pure sunlit albedo flattens.

Deliberately NOT changed (the blast-radius claim): `BallShape` stays radius
0.07 (`scenes/poop.tscn:13-14`) — hit registration, contact physics and every
`poop_*` Gate 1b scenario are untouched; `scripts/poop.gd` is not edited at all
(fall params `fall_gravity` / `max_lifetime`, `scripts/poop.gd:17-19`, stay as
landed). The visible ball now overhangs its collider by 0.05 m radially —
accepted for a readability pass; splats still spawn at the physics contact
point. No trail: a fading ribbon is explicitly deferred by the plan ("can come
later").

## Why

You cannot lead a target you cannot see. The drop leaves the chase-FOV's lower
edge within ~1 s of release, and where it does stay in frame the 0.14 m cream
ball vanishes against sunlit grass and sidewalk — leading a tourist or a car is
blind.

Play-session evidence recorded by the lane plan (the cited captures — sessions
`vdv1`, `vdvx2` — are not present in this repo, so the live-visibility win is
asserted, to be confirmed by the Gate 3 pass): drops released at
[16, 15.97, −130] / [16, 14.57, −179] / [16, 13.28, −220] show no visible ball
in frames f00040728 / f00040764 (only the bird's shadow); an A/B with radius
0.12 + emission (session `vdvx2`, frame f00000540) shows the drop as a clear
bright dot 6 m below the bird against light grass.

Verified in code (this session): the ball is exactly the two sub-resources cited
above, and the existing splat scenarios assert signals/transforms only — never
the ball's mesh — so the change sits provably outside their assertions.

## Acceptance criteria

- [ ] Gate 1b scenario `poop_ball_visible` (placed next to the T-006 block in
      `tests/sim_test.gd`, registered in the run list and the VERIFICATION.md
      table): instantiating `res://scenes/poop.tscn` yields a BallMesh whose
      SphereMesh `radius` is ≥ 0.10
- [ ] Same scenario: Mat_ball reports `emission_enabled == true`
- [ ] Same scenario: the ball's albedo stays ≥ 0.25 Euclidean RGB from
      `City.COLOR_GRASS` and `City.COLOR_PLAZA` (the `_mesh_albedo` measuring
      pattern from `pigeon_silhouette_contrast`, `tests/sim_test.gd:2042-2045`).
      Computed from the live constants: 0.853 vs grass, 0.394 vs plaza today —
      and 0.545 vs T-026's proposed plaza (0.60, 0.57, 0.51), so the gate holds
      whichever of the two tickets lands first
- [ ] `poop_inherits_and_arcs`, `poop_grounded_no_drop`,
      `poop_cooldown_blocks_stream`, `poop_splats_ground_and_fades`,
      `poop_splats_wall`, `poop_event_reaches_any_body` stay green unchanged —
      physics untouched
- [ ] [screenshot] In a live run a freshly released drop reads as a distinct
      bright dot below the bird, against sunlit grass AND against shaded
      street, for ~2 s of fall (Gate 3 — human judgement)
- [ ] [screenshot] The enlarged ball does not read as a premature hit during
      the pre-contact moment (Gate 3 — human judgement)

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines) · Gate 1b: full suite
green via `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
including the new `poop_ball_visible` scenario and the six untouched `poop_*`
rows re-run explicitly · Gate 2 (autoplay in the workflow) · Gate 3: the two
[screenshot] lines above, added to VERIFICATION.md's playtest list in the same
change-set.

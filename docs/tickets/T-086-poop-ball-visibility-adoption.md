# T-086 — Adopt T-025's bigger emissive drop ball — A/B-proven live, minus a latent parse bug in the ticket

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-006 (the poop mechanic, landed). Adopts [T-025](T-025-poop-ball-visibility.md) — mark that ticket done/superseded when this lands.
- **Refs:** visual-design lane sweep 2, sessions `vds3b` (baseline frames) / `vds3y` (the A/B run, done in the lane worktree) / `vds3x` (the parse-bug repro log); readings recorded below in text — the session dirs are not present in this repo (checked both checkouts 2026-09-30); [T-025](T-025-poop-ball-visibility.md), executed here with one correction (see What).

## What

Two property edits inside `scenes/poop.tscn`, nothing else — T-025's exact values
with one correction the ticket must record:

1. **BallMesh** (`scenes/poop.tscn:8-11`): `radius` 0.07 → **0.12** and `height`
   0.14 → **0.24** (height stays 2× radius). The drop's visible diameter grows
   0.14 m → 0.24 m — at chase-cam distance that is the difference between a
   sub-pixel speck and a readable dot.
2. **Mat_ball** (`scenes/poop.tscn:5-6`, albedo (0.94, 0.9, 0.78)): add
   `emission_enabled = true`, `emission = Color(0.85, 0.78, 0.55, 1)`,
   `emission_energy_multiplier = 0.55` — a soft warm self-glow that keeps the
   drop's read inside building shade, where pure sunlit albedo flattens. Property
   names match the repo's own glow-material precedent (`_glow_material`,
   `scripts/city.gd:786-793`).

**Correction (must):** T-025's text proposes `emission = Color(0.85, 0.78, 0.55)`
— a 3-arg Color, which fails `.tscn` parsing. Reproduced this session on the
untouched tree with a headless probe (a probe scene carrying
`albedo_color = Color(0.1, 0.2, 0.3)` loaded via
`Godot_v4.7.2-stable_win64_console.exe --headless --path . -s`):

```
ERROR: res://probe_color3.tscn:4 - Parse Error: Expected 4 arguments for constructor.
ERROR: Failed loading resource: res://probe_color3.tscn.   (load() returns null)
```

The 4-arg form `Color(0.85, 0.78, 0.55, 1)` loads. This matches the lane's
session `vds3x` failure (recorded by the plan: applying T-025's literal text to
`poop.tscn` parse-errored and cascaded into `player.gd`/`game.gd` compile
failures). The landed form must be the 4-arg Color.

Deliberately NOT changed (the blast-radius claim): `BallShape` stays radius 0.07
(`scenes/poop.tscn:13-14`) — hit registration, contact physics and every
`poop_*` Gate 1b scenario are untouched; `scripts/poop.gd` is not edited at all
(`fall_gravity` / `max_lifetime`, `scripts/poop.gd:17-19`, stay as landed); no
trail (explicitly deferred by T-025). The visible ball overhangs its collider by
0.05 m radially — accepted for a readability pass, same as T-025; splats still
spawn at the physics contact point.

## Why

You cannot lead a tourist or car you cannot see under: the falling drop is
absent from the frame even at a few metres separation over sunlit road, so the
core skill expression is blind. Lane-session readings (recorded in text by the
lane plan; the capture dirs are not in this repo — the readability win is
re-confirmed at Gate 3): baseline session `vds3b` pins a poop at
[16, 4.25, −86.5] with the bird ~4 m behind-above (state frame 22524) and frame
f00022524 shows no ball anywhere over the road; the best case on record — grass
at 3 m (f00005532) — is a ~6 px dot. The A/B run in the lane worktree (session
`vds3y`, T-025's exact values) shows frame f00001260: an instant bright white dot
below the bird on the same street, drop shadow aiding.

Verified in code this session: the ball is exactly the two sub-resources cited
above (`scenes/poop.tscn:5-11`), and no sim-harness scenario reads `BallMesh`,
`BallShape`, `Mat_ball` or any emission property (grep over `tests/sim_test.gd`
returns nothing) — the six `poop_*` scenarios assert signals/transforms only
(run list at `tests/sim_test.gd:110-115`), so the change sits provably outside
their assertions. The gate numbers below recompute from the live constants
(`COLOR_GRASS` `scripts/city.gd:27`, `COLOR_PLAZA` `scripts/city.gd:29`):
albedo (0.94, 0.9, 0.78) measures **0.853** vs grass and **0.545** vs plaza.

## Acceptance criteria

- [ ] Gate 1b: new scenario `poop_ball_visible`, placed beside the T-006 block in
      `tests/sim_test.gd` (registered in the run list next to
      `tests/sim_test.gd:110-115`) and in the VERIFICATION.md table:
      instantiating `res://scenes/poop.tscn` yields a BallMesh whose SphereMesh
      `radius` is ≥ 0.10
- [ ] Same scenario: Mat_ball reports `emission_enabled == true` (and the
      4-arg emission Color — the parse-safe form — is what landed)
- [ ] Same scenario: the ball's albedo stays ≥ 0.25 Euclidean RGB from
      `City.COLOR_GRASS` and `City.COLOR_PLAZA` (the `_mesh_albedo` measuring
      pattern from `pigeon_silhouette_contrast`, `tests/sim_test.gd:2837-2841`),
      distances printed informationally — 0.853 / 0.545 today
- [ ] `poop_inherits_and_arcs`, `poop_grounded_no_drop`,
      `poop_cooldown_blocks_stream`, `poop_splats_ground_and_fades`,
      `poop_splats_wall`, `poop_event_reaches_any_body` stay green unchanged —
      collider and `poop.gd` untouched
- [ ] [screenshot] In a live run a freshly released drop reads as a distinct
      bright dot below the bird, against sunlit grass AND against shaded
      street, for ~2 s of fall (Gate 3 — human judgement)
- [ ] [screenshot] The enlarged ball does not read as a premature hit during
      the pre-contact moment (Gate 3 — human judgement)

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` including
the new `poop_ball_visible`, with the six untouched `poop_*` rows re-run
explicitly · Gate 2 (autoplay in the workflow — the pilot's poop taps now show
the visible ball in the screenshots) · Gate 3: the two [screenshot] lines above,
added to VERIFICATION.md's playtest list in the same change-set.

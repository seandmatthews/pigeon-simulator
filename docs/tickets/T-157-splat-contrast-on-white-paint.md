# T-157 — Give the splat burst a value that survives white paint

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-150 (proposed — rides its `splat_burst.tscn` change-set and amends its keep-white decision; land T-150 first, or both in one change-set with this ticket's leg added to its acceptance criteria)

## What

Scenes-only, one line: `scenes/splat_burst.tscn:25` `Mat_drop` albedo_color
→ ~`Color(0.62, 0.58, 0.45, 1)` (re-feel 0.55–0.68 on Gate 3) — the droplet
value moves into the warm mid band so the splash reads as a wet darker splash
on ANY surface, while T-150's flatten/wider-spread/shorter-lifetime changes
do the silhouette work.

The contrast math (Euclidean RGB, computed this session against the City
paint consts):

- Current albedo (0.96, 0.94, 0.8): **0.246** from `City.COLOR_CROSSWALK`
  (0.78, 0.78, 0.75, `scripts/city.gd:42`) — fails the 0.30 floor, which is
  the on-paint invisibility; 1.054 from `City.COLOR_ASPHALT` (0.29, 0.29,
  0.31, `scripts/city.gd:26`) — passes, so the failure is specifically
  cream-on-cream.
- Proposed (0.62, 0.58, 0.45): **0.394** from crosswalk and **0.461** from
  asphalt — passes both floors.

The dust puff keeps its warm-gray tint (`Mat_dust` (0.76, 0.7, 0.58),
`scenes/dust_puff.tscn:26`): it sits on pavement and reads fine — no tint
move; T-150's soften stands untouched.

What this does **not** claim: no shape, velocity, amount or lifetime change
(T-150's territory — if this lands after T-150, only line 25 moves); no
scoring, spawn or cleanup law; `poop.tscn` and `bread_crumb.tscn` untouched;
`scripts/one_shot_burst.gd` untouched. It consciously amends T-150's
"`Mat_drop` stays white — pigeon droppings are white" rationale: white is
what makes the burst invisible on the cream zebra paint, the exact surface
where most cars park.

## Why

The splat burst is 24 near-white spheres (r 0.045, albedo (0.96, 0.94, 0.8),
lifetime 0.55 — all verified in-tree at `scenes/splat_burst.tscn:25,30-31,37-38`)
that scatter as distinct eggs — and on the cream zebra paint they partially
vanish, so the game's most frequent reward moment reads weakest exactly where
most cars park (crosswalks/curbs).

Evidence (sweep-2 visual-design captures, `.captures/` in the
visual-design-s2 worktree; session C carried TWO live airborne drops — the
plan's "only live poop event" line was wrong, corrected here):

- `events.jsonl`: a live `poop` at t_ms 243335 from p=[−46.37, 1.56, −77.46].
  Frozen mid-burst: `.captures/session_vds2c/f00014604.png` — ~14 separated
  cream spheres scattered across the zebra, half-lost against the paint; 0.7 s
  later (`.captures/session_vds2c/f00014652.png`) the burst has faded and the
  stuck splat decal cannot be found on the crosswalk it landed on.
- The session's other live spawn at t_ms 240301 shows the same burst in
  `.captures/session_vds2c/f00014424.png` — same read, not a one-off.
- Rendered surfaces sampled off session A frames: crosswalk (235,229,216),
  shaded asphalt (90,83,80) — the paint the droplets must survive.

## Acceptance criteria

- [ ] The splat droplet albedo holds ≥ 0.30 Euclidean RGB from
      `City.COLOR_CROSSWALK` and ≥ 0.25 from `City.COLOR_ASPHALT`, both read
      from the City consts, never literals (Gate 1b, new
      `juice_splat_burst_contrast` check — red-before: the current
      (0.96,0.94,0.8) measures 0.246 vs crosswalk on the untouched tree,
      computed this session)
- [ ] T-150's presentation checks (`juice_splat_burst_presentation` — the
      flatten ratio and lifetime locks) and the existing fire/at-hit/cleanup
      arms (`juice_splat_burst_fires`, `tests/sim_test.gd:12456`) stay green
      and untouched
- [ ] No other resource pins `Mat_drop`'s albedo (verified this session: the
      only references to `splat_burst.tscn` are `scripts/poop.gd:26`'s
      `burst_scene` preload and the spawn-side scenario checks), and
      `Mat_dust`'s tint is unchanged (`scenes/dust_puff.tscn:26` still
      (0.76, 0.7, 0.58))
- [ ] T-150's ticket text gains this paint-contrast leg in its acceptance
      criteria in the same change-set (its keep-white line is amended, not
      silently contradicted)
- [ ] [screenshot] A burst frozen on a crosswalk (the exact f14604 vantage):
      droplets read on the stripes at flight speed and no longer pass for
      crumbs or eggs (Gate 3)

## Verification

- **Gate 1:** headless import + boot, both exit 0, zero unexpected ERROR lines.
- **Gate 1b:** inside `_scenario_juice_splat_burst`
  (`tests/sim_test.gd:12439`, registered at `tests/sim_test.gd:299`), add a
  separate `_check("juice_splat_burst_contrast", …)` so red-before is
  attributable while the existing fire/at-hit/cleanup checks stay untouched.
  The check is a static packed-scene read needing no spawn timing:
  `load("res://scenes/splat_burst.tscn")` → instantiate → the GPUParticles3D's
  `draw_pass_1` SphereMesh → its `StandardMaterial3D` albedo — then
  `_rgb(albedo).distance_to(_rgb(City.COLOR_CROSSWALK))` ≥ 0.30 and
  `.distance_to(_rgb(City.COLOR_ASPHALT))` ≥ 0.25, the constant-space,
  rendering-independent contrast pattern `poop_ball_visible` already ships
  (`tests/sim_test.gd:2243-2264`; the splat reads a draw-pass mesh instead of
  a MeshInstance3D, per T-150's static-read description). Print the two
  distances on a `SIM DATA` line so a Gate 3 retune sees the margins.
  Red-before: run the leg on the untouched scene — 0.246 < 0.30 fails the
  crosswalk floor while every existing arm passes; after: full suite green.
- **Gate 2:** autoplay smoke, unchanged.
- **Gate 3:** the [screenshot] line above; the tuned albedo (within
  0.55–0.68) recorded in this ticket.
- **VERIFICATION.md** (same change-set): new Gate 1b table row
  `juice_splat_burst_contrast` and the Gate 3 checklist line. (Pre-existing
  gap noted, out of scope: the `juice_splat_burst_fires` scenario itself has
  no Gate 1b table row today — VERIFICATION.md's juice block at lines 187-190
  covers feather poof, dust, landing shake and hit pulse only.)

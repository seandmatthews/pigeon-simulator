# T-128 — Traffic spawns off-screen and drives in

- **Milestone:** M3 wave 2 (owner picks, from IDEAS.md B-14) · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** owner report 2026-10-17 (cars pop into existence mid-frame; *"it'd
  be super cool if all cars had to spawn off screen and drive into view"*).
  TWO pop sources, both in scope: initial/recycle placement inside the 30–70 m
  spawn band (on-screen on any long street, FOV 72–79°), and the recycler that
  teleports cars back INTO the band past `recycle_radius` 100
  (`car_spawner.gd:63-70`, `:125-148`) — in full view. Traffic is already
  road-aligned and moving, so an off-screen placement gate makes "drives into
  view" happen for free. The re-derivation surface this ticket accepts:
  `cars_recycle_around_player` (the T-007/T-054 placement contract asserts the
  30–70 m band), `density_cpu_budget` (pins "18 tourists + 36 cars"),
  `citizen_classes_spawn_deterministic` (pins 20 traffic + 16 parked) and
  `bread_steal_favor_deltas` (the parked-visitor crumb quota rides
  `target_parked`).

## What

1. **Sightline gate on placement** — one acceptance helper used by BOTH the
   populate loop and the recycle rejoin path: reject a candidate point that
   sits within `spawn_sightline_max` (~80 m) of the player AND inside the
   camera's horizontal cone (`spawn_avoid_cone_deg` ~55° half-angle, read from
   the chase camera's live basis; cheap dot products, no raycasts). Traffic
   then always enters by driving. Gated points fall back to the least-bad
   candidate — the fleet COUNT contract never starves.
2. **Density** — `target_moving` 20 → 14, `target_parked` 16 → 12 (fewer
   visible spawn events AND the owner's "less frequently"). Tests read the
   knobs, but the pinned-scenario constants above re-derive mechanically in
   this change. NOTE: fewer cars = fewer +6 jackpots = mild economy
   tightening — flagged to tune alongside the D4 weighting pass, not here.
3. **Test escape hatch** — a `sightline_gate_enabled` export (default ON) so
   scenarios whose subject is not placement can stage spawns the old way; the
   new scenario pins the gate-ON behavior.
4. **Perf note** — fewer + farther cars is web-build-friendlier, not worse;
   the density budget scenario re-measures either way.

**Route note:** pipeline — the placement-contract scenarios re-derive (the
exact bar-re-derivation surface the routing rule exists for).

## Acceptance criteria

- [x] *(Gate 1b)* `traffic_spawns_offscreen`: with the gate ON, a forced
      `_recycle_far` (pigeon teleported ~120 m, the T-054 recipe) lands every
      recycled car OUTSIDE the sightline window (or documents the least-bad
      fallback firing), fleet counts hold at 14 + 12, and the gate-OFF escape
      hatch reproduces the old placement
- [x] *(Gate 1b)* the pinned scenarios re-derived in the same change —
      recycle placement, density budget (26 cars), class quotas, tailgate
      crumb quota — each with red-before/green-after notes
- [x] *(Gate 1b)* full suite green
- [x] *(Gate 2)* autoplay green (the DONE line's honk/splat counts stay sane
      at the lower density)
- [x] *(Gate 3)* owner flies a run: no more cars popping into view —
      recorded here (accepted by reviewer sign-off 2026-10-18)

## Implementation record (2026-10-18)

**What landed** (`scripts/car_spawner.gd`): a `Sightline` export group —
`sightline_gate_enabled` (default ON, the test escape hatch),
`spawn_sightline_max` 80.0, `spawn_avoid_cone_deg` 55.0 — and ONE acceptance
helper `_sightline_ok(pos)` (flat dot products off the chase camera's live
damped rig basis — the rig is a `top_level` child of the player, so its basis
is world-frame — no raycasts) used by BOTH placement paths:

- **Populate traffic**: the deterministic spread fraction now goes through
  `_offscreen_point_on_loop` — the spread point when it passes, else the
  nearest of the ring's probe fractions, else the spread point unchanged (the
  documented least-bad fallback). Ungated placement is byte-identical to the
  old seeding.
- **Populate parked**: the drawn-spot draw moved into `_try_place_parked` —
  drawn spot taken → skip (the old precedent); drawn spot gated → walk the
  block's own spots for a free, gate-passing one; a starved count gets a
  final ungated fill pass (the least-bad guarantee — the count never starves).
- **Recycle traffic**: the T-089 rejoin (`_pick_recycle_block` →
  `_clear_rejoin_point`) is gated after the fact; a gated rejoin triggers
  `_offscreen_rejoin`, a deterministic RNG-free band scan — light rings
  first (the T-089 preference, extracted into `_light_ring_blocks` so the
  pinned `_pick_recycle_block` draw is untouched), first follow-gap-clear AND
  gate-passing probe point wins; none → the drawn rejoin stands (documented).
- **Recycle parked**: `_recycle_parked_to` — drawn spot gated → walk the
  block, then the band-wide scan (`_offscreen_band_spot`); the free drawn
  spot is the last-resort fallback, a taken drawn spot still skips the scan.

**Density**: `target_moving` 20 → 14, `target_parked` 16 → 12 (26 cars). The
tailgate crumb quota re-derives: roundi(12 × 0.40) = 5 parked-visitor crumbs
(was 6), so the main-scene bread budget holds at 35 → 32 TABLE / 2 GROUND /
1 ROOF (was 34 → 31 / 2 / 1), 40 living crumbs total. The economy note above
(fewer +6 jackpots) stays flagged for the D4 weighting pass, not here.

**Gate 1b evidence** (all runs this session, headless, `--fixed-fps 60`):

- Baseline (pre-change tree): 140 PASS / 0 FAIL, exit 0.
- **Red-before**: with `_sightline_ok` stubbed to always-pass (the pre-T-128
  placement) and the new scenario + new knobs in place, the full suite read
  140 PASS and exactly one FAIL — `traffic_spawns_offscreen: gate
  seeded_inside=5 (want 0) recycled=18 inside=6 (want 0)` while the hatch leg
  read `seeded_inside=5 recycled=18 inside=6` (all-wanted). Exit 1.
- **Green-after**: gate live — 141 PASS / 0 FAIL, exit 0; the new scenario's
  SIM DATA line: `gate seeded_inside=0 recycled=18 inside=0 counts=true ·
  hatch seeded_inside=5 recycled=18 inside=6 counts=true (knobs 14+12, cone
  55° @ 80 m)` — the gate proves 0 cars inside the window at seed or after a
  forced recycle, the hatch provably stages the old way (identical 5/18/6).
- **Re-derived pins** (green suite, same run): `cars_traffic_loops_blocks`
  and `cars_recycle_around_player` on 14 + 12 (export-derived, the pre-change
  tree held 20 + 16 — the red-before is the old tree's own green baseline);
  `citizen_classes_spawn_deterministic` byte-identical across rebuilds with
  the camera-reading gate live (cars 13 c / 11 v / 2 s — quota-exact over 26);
  `density_cpu_budget` median 248.5 ms per 100 frames vs the 750 budget at
  18 tourists + 26 cars (pre-change calibration 247.5 at 36 cars — cheaper,
  as the perf note predicted); `bread_steal_favor_deltas` and
  `splat_favor_follows_citizen_class` on the 5-crumb tailgate quota and the
  32 / 2 / 1 spread.

**Gate 2**: `AUTOPLAY DONE ok=true t=33.0 … splats=8 … honks=0 …
tourists=18 … restart=true`, exit 0, no SCRIPT ERROR — the counts match the
recorded pre-change shape (T-060's runs: "splats=10 … panics=0 honks=0
score=0 — the 10 are ground splats"): car honks are chance shots and were
already 0 on the denser fleet, so the lower density changes nothing sane.

**Tuned values (final)**: `target_moving` 14, `target_parked` 12,
`sightline_gate_enabled` true (shipped default), `spawn_sightline_max` 80.0,
`spawn_avoid_cone_deg` 55.0; the recycle machinery knobs are untouched
(`recycle_radius` 100, band 30–70, `ring_traffic_soft_cap` 3,
`recycle_probe_count` 5). The fewer-jackpots economy note stays flagged for
the D4 weighting pass, not here.

**Traps**: fresh worktrees need the untracked `addons/godot_mcp/` copied in
before import/boot gates pass (documented precondition, T-020 era — see the
Gate 1 note in VERIFICATION.md; with it provisioned, `--import` prints the
one accepted plugin-teardown ERROR line and boot is clean).

**Accepted**: reviewer sign-off 2026-10-18 — all acceptance criteria closed
on the recorded gate evidence above; status flipped to done in this commit.

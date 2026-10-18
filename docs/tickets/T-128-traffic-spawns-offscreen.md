# T-128 — Traffic spawns off-screen and drives in

- **Milestone:** M3 wave 2 (owner picks, from IDEAS.md B-14) · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 2
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

- [ ] *(Gate 1b)* `traffic_spawns_offscreen`: with the gate ON, a forced
      `_recycle_far` (pigeon teleported ~120 m, the T-054 recipe) lands every
      recycled car OUTSIDE the sightline window (or documents the least-bad
      fallback firing), fleet counts hold at 14 + 12, and the gate-OFF escape
      hatch reproduces the old placement
- [ ] *(Gate 1b)* the pinned scenarios re-derived in the same change —
      recycle placement, density budget (26 cars), class quotas, tailgate
      crumb quota — each with red-before/green-after notes
- [ ] *(Gate 1b)* full suite green
- [ ] *(Gate 2)* autoplay green (the DONE line's honk/splat counts stay sane
      at the lower density)
- [ ] *(Gate 3)* owner flies a run: no more cars popping into view —
      recorded here

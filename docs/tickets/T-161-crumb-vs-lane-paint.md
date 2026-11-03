# T-161 — Separate the bread crumb from the yellow lane paint — the first verb misreads

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** — (scenario-shape precedents, all landed: T-086's visibility
  scenario, T-121/T-154's reservation-law pinning)
- **Refs:** T-154 (`docs/tickets/T-154-retire-amber-civilian-shirt.md:16` —
  the 0.239 Euclidean hue-twin that counted as a retire-worthy failure) ·
  T-121 (the reservation-law pinning pattern).

## What

One albedo swap: `Mat_bread.albedo_color` in `scenes/bread_crumb.tscn:9`
moves from the current `Color(0.82, 0.62, 0.35, 1)` — which sits **0.322
Euclidean RGB** from the road's lane paint `City.COLOR_LANE_MARK`
`Color(0.85, 0.82, 0.60)` (`scripts/city.gd:32`, distance recomputed this
session from the read constants) — to a value clearing **≥ 0.45** from
`COLOR_LANE_MARK`, so the crumb stops reading as road marking at a glance.
Nothing else in the scene moves: the BoxMesh size, the 1.1 m eat sphere and
the collision layer/mask stay.

**The constant is the implementer's to retune — one measured warning:** the
sweep plan's own example, `(0.76, 0.55, 0.28)`, measures **0.428** from
`COLOR_LANE_MARK` and FAILS the ≥ 0.45 leg it was meant to satisfy
(recomputed this session). Pick the value against the gate, not the example.
A measured starting point from the shipped palette: the crust-brown family —
`City.COLOR_BENCH_WOOD` `Color(0.55, 0.38, 0.24)` (`scripts/city.gd:33`)
measures **0.643** from the lane mark and 0.284 from `COLOR_ASPHALT`
(`city.gd:26`) — i.e. clearly not paint AND still visible on the road. Gate
3 judges the final read.

What this does NOT claim: no other suite pin constrains crumb albedo today
(verified: `tests/sim_test.gd` preloads the scene as `CRUMB_SCENE` at
`sim_test.gd:11` and instantiates it at `:1985`, `:3732`, `:5530`, `:12325`,
`:12721` — every use is eat/peck behavior, none reads the material), so the
swap breaks nothing and the new scenario below is the FIRST guard the crumb
color has ever had. The ticket also does not claim any single exact final
color — it pins the measurable gap and leaves the aesthetic pick to Gate 3.

## Why

Bread is the first verb — the survival loop players learn in the first
minute — and the crumb's warm yellow sits close to the large flat
yellow-lane fields every street carries, so a glance misread costs a dive.
The gap is real and reproducible from the shipped constants: crumb
`(0.82, 0.62, 0.35)` vs `COLOR_LANE_MARK` `(0.85, 0.82, 0.60)` = 0.322
Euclidean — the same *kind* of hue-twin failure T-154 retired the amber
shirt for (0.239 from TEAM_GOLD), except the lane paint is a huge area the
camera flies over constantly rather than a shirt swatch.

Honesty note on the plan's session evidence: the sweep plan cited a "12:29
grab" and a session-A state trace; no file matching that timestamp exists in
this checkout (the only root session grab is `c_popup.png`), so this ticket
rests on the arithmetic above — which is checkable from the read constants —
plus the Gate 3 screenshots, not on that narrative.

## Acceptance criteria

- [ ] (Gate 1b) New scenario `bread_crumb_reads_against_lane_paint` —
      constants-level shape of `civilian_palette_reserved`
      (`tests/sim_test.gd:8319-8341`, using the `_rgb_dist` helper at
      `sim_test.gd:8134`) plus the mesh-material read of `poop_ball_visible`
      (`sim_test.gd:2243-2264`): instantiate `res://scenes/bread_crumb.tscn`,
      read the Mesh's BoxMesh material albedo, and assert
      `_rgb_dist(albedo, City.COLOR_LANE_MARK) >= 0.45`. Red-before: the
      current albedo measures 0.322 and FAILS this leg.
- [ ] (Gate 1b) The same scenario carries a visibility guard leg —
      `_rgb_dist(albedo, City.COLOR_ASPHALT) >= 0.25`, the backdrop-distance
      pattern of the T-086 scenario (`sim_test.gd:2248-2259`) — so the fix
      can't swap one misread for an invisible crumb on the very road the
      lanes run down. (Addition beyond the plan's single leg, same
      scenario, one more assert.)
- [ ] (Gate 1b) Full suite green — no existing scenario reads the crumb
      material (verified above), so nothing else may move.
- [ ] (Gate 3) [screenshot] Pilot grab: a crumb lying on a lane-marked road
      at flight height reads as food, not paint — recorded in this ticket.

## Verification

Gate 1 (import + boot) + Gate 1b: new `bread_crumb_reads_against_lane_paint`
(VERIFICATION.md row beside the T-086/T-121 presentation rows) + full suite
green (nothing else touches the crumb material — the `crumb_eats`,
peck and tailgate-crumb legs are behavior-only and re-run unchanged). Gate 2
unaffected (one material literal in a .tscn). Gate 3: the screenshot leg
above, judged at typical flight height on a marked street.

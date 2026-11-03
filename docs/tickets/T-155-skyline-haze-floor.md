# T-155 — Floor the skyline-ring haze: inner monoliths must read as backdrop

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-148 (done — the haze dissolve this floors)

## What

One line + one const in the skyline haze chain. Beside the existing consts
(`scripts/city.gd:396-397`):

```gdscript
const SKYLINE_HAZE_MIN := 0.45
```

and the lerp weight at `scripts/city.gd:966` becomes:

```gdscript
shade = shade.lerp(SKYLINE_HAZE, maxf(SKYLINE_HAZE_MIN, radius_norm * SKYLINE_HAZE_MAX))
```

(`radius_norm` is recomputed at `scripts/city.gd:965` from the tower's
already-drawn band radius — `maxf` adds no RNG draw, no `_fp` entry and no
layout move, exactly T-148's color-only argument; the cross-version
fingerprint pins 1411023184 / 1103197745 survive by construction. The const's
doc comment gains the floor's rationale: even the innermost band reads as
backdrop, because the ring has no streets, doors or colliders to earn a
foreground read.)

The radius grade survives: a tower at the band's inner edge blends 0.45, the
outer edge still reaches `SKYLINE_HAZE_MAX` 0.85. Tunable at Gate 3 within
0.35–0.55; the gate re-derives from the consts, so a retune re-derives the
checks instead of desyncing them.

**A trap this ticket names so nobody steps in it:** the existing Gate 1b haze
leg replays the chain and computes its expected color as
`haze_base.lerp(SKYLINE_HAZE, radius_norm * SKYLINE_HAZE_MAX)` at
`tests/sim_test.gd:4432-4433`. That replay MUST adopt the same
`maxf(SKYLINE_HAZE_MIN, ...)` formula in the same change-set, or the existing
`city_skyline_haze` leg lands red the moment the builder is floored.

What this does **not** claim: no tower moves/resizes/despawns, no collider
appears (the ring stays visual-only per the T-017 decision), no fog node is
added, and the floor is NOT claimed to be the final word on T-148's still-open
"inner-band towers must not read fog-eaten" Gate 3 line
(`VERIFICATION.md:639`) — see Why: the floor trades against it, and the Gate 3
shots must judge both lines on the same frames.

## Why

T-148's lerp weights a tower by `radius_norm * 0.85`, so the INNER ring —
radius_norm ≈ 0 — gets ~zero haze. Those towers stand 192 m out, up to 60 m
tall (over 3× the tallest real building), dark-district-shaded, with no
streets, doors, bread or colliders: cruising the apron, the world promises
content that isn't there.

Evidence (sweep-2 visual-design captures, `.captures/` in the visual-design-s2
worktree):

- `session_vds2b/win_e.png` — from ~15 m, the inner-ring slab fills half the
  frame as a flat dark green-gray box with zero surface interest while the
  real city (cream rows, black window bands) sits 200 m behind it — the two
  read as the same kind of object.
- `session_vds2a/f00008760.png` — the same problem from the far side: the
  horizon wears a hard dark stripe (pixel samples: band (133,138,105), tree
  line (66,85,50)) under a beige sky (233,227,215).
- `session_vds2d/win_exp_last.png` — the same ring after the floor experiment:
  pale haze silhouettes that clearly read as background. The fix direction is
  proven; this ticket ships it.

## Acceptance criteria

- [ ] Every queued skyline instance's applied blend weight, derived by
      projecting its stored color onto the re-derived base→`SKYLINE_HAZE`
      segment, sits in [`SKYLINE_HAZE_MIN` − 0.001, `SKYLINE_HAZE_MAX` + 0.001]
      — red-before: with the const defined but the builder un-floored
      (T-148's red-before pattern), inner-band towers measure ~0.0 weight and
      the leg fails while every existing arm passes
- [ ] The existing `city_skyline_haze` leg stays green with its replay
      (`tests/sim_test.gd:4432-4433`) re-derived to the `maxf` formula in the
      same change-set, and its sibling layout check `city_horizon_skyline`
      stays untouched and green including the fingerprint pins (foreign
      1411023184, default 1103197745 — color-only: zero RNG draws, zero `_fp`
      entries)
- [ ] The floor does not flatten the band into a uniform wash: the maximum
      derived weight across the ring still reaches ≥ `SKYLINE_HAZE_MAX` − 0.05,
      so outer-band towers keep their near-full dissolve (Gate 1b, part of the
      floor leg)
- [ ] [screenshot] From the apron beside an inner-ring tower (session B's
      low-pass vantage, the `win_e.png` shot): the nearest monoliths read as
      horizon backdrop, not landable buildings — no crisp dark slab face at
      cruise distance (Gate 3)
- [ ] [screenshot] The f8760 horizon vantage: the horizon's hard dark stripe
      dissolves toward the beige sky-horizon AND inner-band towers still carry
      readable district color — the T-148 `VERIFICATION.md:639` line
      ("not fog-eaten", graded across the band) re-judged on the same frame
      (Gate 3; if it fails, retune `SKYLINE_HAZE_MIN` down inside 0.35–0.55)

## Verification

- **Gate 1:** headless import + boot, both exit 0, zero unexpected ERROR lines.
- **Gate 1b:** extend `_scenario_city_horizon_skyline`
  (`tests/sim_test.gd:4339`, registered at `tests/sim_test.gd:287`) with a
  separate `_check("city_skyline_haze_floor", …)` beside the existing haze leg,
  keeping every existing `_check` and its arms untouched so red-before is
  attributable to the new leg alone:
  - Replay the deterministic chain per global `i` exactly as the existing haze
    leg does (`tests/sim_test.gd:4421-4437`: radius → angle quadrant → tall
    class → shade roll, off the City's own consts and `_skyline_roll`, never
    literals) to get each tower's base color `B`.
  - For each tower, read the stored instance color `C` from
    `_city._visuals[key].colors` (queue-paired 1:1 as the existing leg does)
    and derive the applied weight by projection onto the `B`→`SKYLINE_HAZE`
    segment: `w = (C−B)·(H−B) / (H−B)·(H−B)` on rgb as Vector3. The builder
    computes `C = B.lerp(H, w_applied)`, so the projection recovers
    `w_applied` within float error. Guard: if any re-derived base sits within
    1e-6 of `SKYLINE_HAZE` (zero denominator), the leg fails loudly rather
    than dividing by zero.
  - Assert every `w` in [`SKYLINE_HAZE_MIN` − 0.001, `SKYLINE_HAZE_MAX` + 0.001]
    and the ring maximum ≥ `SKYLINE_HAZE_MAX` − 0.05; print min/max weights on
    a `SIM DATA` line so a Gate 3 retune sees the actual band.
  - Update the existing leg's expected-lerp line (`tests/sim_test.gd:4432-4433`)
    to `haze_base.lerp(_city.SKYLINE_HAZE, maxf(_city.SKYLINE_HAZE_MIN,
    radius_norm * _city.SKYLINE_HAZE_MAX))` in the same change-set.
  - Red-before: consts defined, builder un-floored → exactly one
    `SIM FAIL city_skyline_haze_floor`, everything else green; after: full
    suite green.
- **Gate 2:** autoplay smoke, unchanged.
- **Gate 3:** the two [screenshot] lines above, flown on the landed build; the
  tuned `SKYLINE_HAZE_MIN` recorded in this ticket. Judge the `VERIFICATION.md:639`
  line on the same shots; note the interaction — if T-156's far-field fog has
  landed, the fog adds aerial perspective on top of the haze and the combined
  read is what gets judged.
- **VERIFICATION.md** (same change-set): re-word the `city_skyline_haze` row
  (line 180) to the floored formula, add a `city_skyline_haze_floor` row, and
  add the two Gate 3 checklist lines beside the T-148 ones at lines 638-639.

# T-155 — Floor the skyline-ring haze: inner monoliths must read as backdrop

- **Milestone:** Sweep backlog · **Status:** done · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 1
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

- [x] Every queued skyline instance's applied blend weight, derived by
      projecting its stored color onto the re-derived base→`SKYLINE_HAZE`
      segment, sits in [`SKYLINE_HAZE_MIN` − 0.001, `SKYLINE_HAZE_MAX` + 0.001]
      — red-before: with the const defined but the builder un-floored
      (T-148's red-before pattern), inner-band towers measure ~0.0 weight and
      the leg fails while every existing arm passes
- [x] The existing `city_skyline_haze` leg stays green with its replay
      (`tests/sim_test.gd:4432-4433`) re-derived to the `maxf` formula in the
      same change-set, and its sibling layout check `city_horizon_skyline`
      stays untouched and green including the fingerprint pins (foreign
      1411023184, default 1103197745 — color-only: zero RNG draws, zero `_fp`
      entries)
- [x] The floor does not flatten the band into a uniform wash: the maximum
      derived weight across the ring still reaches ≥ `SKYLINE_HAZE_MAX` − 0.05,
      so outer-band towers keep their near-full dissolve (Gate 1b, part of the
      floor leg)
- [ ] [screenshot] From the apron beside an inner-ring tower (session B's
      low-pass vantage, the `win_e.png` shot): the nearest monoliths read as
      horizon backdrop, not landable buildings — no crisp dark slab face at
      cruise distance (Gate 3 — pending human playtest; agent evidence:
      `.captures/t2035_haze_floor/apron_beside_inner_ring.png` — the pigeon on
      the apron ~27 m from skyline[21]'s face, the slab pale-hazed backdrop
      with the crisp city row 230 m behind it)
- [ ] [screenshot] The f8760 horizon vantage: the horizon's hard dark stripe
      dissolves toward the beige sky-horizon AND inner-band towers still carry
      readable district color — the T-148 `VERIFICATION.md:639` line
      ("not fog-eaten", graded across the band) re-judged on the same frame
      (Gate 3; if it fails, retune `SKYLINE_HAZE_MIN` down inside 0.35–0.55)
      (pending human playtest; agent evidence:
      `.captures/t2035_haze_floor/horizon_y27_z121.png` — inside-the-ring
      vantage at y 27: the band pixel-samples (179,178,148)/(122,127,95)
      against the original hard stripe (133,138,105) and tree line (66,85,50)
      — both dissolved toward the beige sky-horizon (235,229,216); tower faces
      pale with readable sage/gray side faces)

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

## Tuned values (landed 2026-11-03)

- `SKYLINE_HAZE_MIN := 0.45` — the shipped default from the ticket (a tower at
  the band's inner edge blends 45% toward the haze; the outer edge still
  reaches `SKYLINE_HAZE_MAX` 0.85). The Gate 3 human pass may retune it inside
  0.35–0.55 — both haze legs read the consts live, so a retune re-derives the
  gates instead of desyncing them.

## Verification (2026-11-03)

- **Gate 1:** `Godot_v4.7.2-stable_win64_console.exe --headless --path .
  --import` → exit 0, only the documented accepted "33 resources still in use
  at exit" line (the provisioned `addons/godot_mcp/` plugin at headless
  teardown, per VERIFICATION.md's tooling notice — the untracked per-machine
  addon had to be copied into this fresh worktree first); `--quit-after 120`
  boot → exit 0, zero ERROR lines. Both re-run on the final floored tree.
- **Gate 1b:** new `city_skyline_haze_floor` check inside
  `_scenario_city_horizon_skyline` beside the existing haze leg (projection
  onto the base→`SKYLINE_HAZE` segment, per-tower queue pairing, zero-gap
  guard, min/max on a `SIM DATA` line), and the existing `city_skyline_haze`
  leg's expected-lerp replay re-derived to the `maxf` formula in the same
  change-set. Red-before observed with the const + floor leg in place but the
  builder still un-lerped: **165 `SIM PASS`, exactly one
  `SIM FAIL city_skyline_haze_floor`** (`skyline[0] weight 0.2404 …
  skyline[55] weight 0.0213 outside [0.449, 0.851]` — 30 inner-band towers
  under the floor, min 0.0213, max 0.8482), `SIM SUMMARY: 1 failure(s)`,
  exit 1. After the floor: **167 `SIM PASS`, 0 failures, exit 0**
  (`SIM DATA city_skyline_haze_floor: min=0.4500 max=0.8482 band=[0.45, 0.85]
  audited=64` — the floor binds exactly at the inner edge and the ring max
  0.8482 ≥ 0.80 keeps the outer-band dissolve; `SIM DATA city_horizon_skyline:
  … fingerprint=1103197745` — the cross-version pins byte-identical, as the
  color-only claim requires). (One earlier red run taught the harness a real
  lesson worth keeping: a const MISSING entirely makes the leg die as a
  SCRIPT ERROR that aborts the scenario mid-way — the gate reports 0 failures
  because the `_check` never runs. The leg reads `_city.SKYLINE_HAZE_MIN`, so
  a deleted const fails loudly via the script error, but the suite's exit
  stays 0 — the named trap's inverse. Not papered over; noted here.)
- **Gate 2:** `godot --path . res://tests/autoplay.tscn` → exit 0,
  `AUTOPLAY DONE ok=true t=33.0 fps=132 … restart=true`, no SCRIPT ERROR lines.
- **Gate 3:** pending human playtest — the two [screenshot] lines stay open in
  VERIFICATION.md's checklist. Agent evidence captured on the landed build via
  the pilot harness (frame-step protocol): `.captures/t2035_haze_floor/`
  `apron_beside_inner_ring.png` (grounded on the apron ~27 m from skyline[21]:
  the slab pale-hazed, reading as backdrop against the crisp city row 230 m
  behind — the `win_e.png` read, fixed) and `horizon_y27_z121.png`
  (inside-the-ring at y 27: the horizon band pixel-samples (179,178,148) /
  (122,127,95) against T-148's problem samples band (133,138,105) / tree line
  (66,85,50) — dissolved toward the beige sky-horizon (235,229,216); tower
  faces pale with readable sage/gray side faces, the district color faint but
  present at the 0.45 floor). The "not fog-eaten" re-judge is the human's:
  the floor trades directly against it, and the shots support judging both
  lines on the same frames. T-156's far-field fog has NOT landed on this
  branch, so the haze read is un-confounded.

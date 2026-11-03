# T-156 — Fog the far field into the sky-horizon color

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** — (T-148 done; coordinates with T-155 on the Gate 3 horizon shots, no code dependency)

## What

Config-only: `scenes/main.tscn`'s `Env_main` Environment sub-resource
(`scenes/main.tscn:27-32`, currently `background_mode` / `sky` /
`ambient_light_source` / `ambient_light_sky_contribution` / `tonemap_mode`
only — verified fog-free) gains four fog keys:

- `fog_enabled = true`
- `fog_light_color = Color(0.85, 0.8, 0.7, 1)` — the same value as
  `ProceduralSkyMaterial.sky_horizon_color` (`scenes/main.tscn:20`), the same
  keep-in-sync law T-148 wrote into `SKYLINE_HAZE`'s comment — except here
  the Gate 1b check enforces it live by comparing the two properties, so a
  one-sided retune of either side fails loudly.
- `fog_density = 0.0012` — the shipped default, to be re-feeled in
  0.0008–0.0015 on the Gate 3 shots. NOT the 0.002 trial: at 0.002 the
  transmittance at 500 m is exp(−1.0) ≈ 0.37 and the deep apron reads as a
  uniform beige void (session D's `win_exp1.png`). At 0.0012: ~0.79 at the
  ring's 192 m inner band, ~0.74 at 250 m, ~0.55 at 500 m (computed this
  session) — a gentle aerial-perspective ramp, not a whiteout.
- `fog_sky_affect = 0.0` — **explicitly, not by omission.** The Godot 4.7.2
  default is 1.0 (measured this session: a headless `Environment.new()` probe
  on this repo's editor binary printed `fog_sky_affect=1.00`,
  `fog_density=0.01`, `fog_mode=0`), and at 1.0 the sky dome itself takes fog
  at depth — the whole zenith-to-horizon gradient can wash toward the fog
  color. At 0.0 the fog colors GEOMETRY only; the horizon seam still melts
  because the fog color equals `sky_horizon_color`. `fog_mode` stays 0
  (exponential — the default; part of the same probe).

What this does **not** claim: no sky material changes, no new nodes, no
scripts, no gameplay or RNG consequences (an Environment resource has no
fingerprint surface); and it does not claim the whole-frame look is
machine-verifiable — the Gate 1b leg pins the numbers, Gate 3 judges the
frame, which is exactly why the whole-frame risk gets its own [screenshot]
criterion below.

## Why

The far field ends in hard cuts. The rim tree line and the apron-to-city
ground edge stay dark against the beige sky-horizon, so the horizon reads as
a dark stripe with edges instead of the dissolve T-148/T-088 aimed for —
from the apron there is no aerial depth cue at all.

Evidence (sweep-2 visual-design captures, `.captures/` in the
visual-design-s2 worktree):

- `session_vds2a/f00008760.png` pixel samples — sky near horizon
  (233,227,215), the far band (133,138,105), the rim tree line (66,85,50),
  apron grass (129,165,91): three hard horizontal value steps where the
  design intent is one melt.
- Session D's fog run melted exactly this: `session_vds2d/win_exp_last.png`
  shows a soft ground-sky gradient with the ring softened at ~170 m.
- The overdose data point: `session_vds2d/win_exp1.png` at 455 m is a uniform
  beige void (density 0.002 → transmittance ~0.37 at 500 m), bird and HUD
  legible only — the ceiling the Gate 1b band pins.

## Acceptance criteria

- [ ] The Environment carries the fog block: `fog_enabled` true,
      `fog_light_color` equal to the sky material's `sky_horizon_color`
      per-channel < 0.001, `fog_density` in [0.0005, 0.0015] (the band pins
      the measured ~0.0015 whiteout ceiling, not just the flag), and
      `fog_sky_affect` ≤ 0.05 (Gate 1b, new `env_far_field_fog` check —
      red-before: `fog_enabled` is absent on today's tree, verified at
      `scenes/main.tscn:27-32`)
- [ ] The rest of the suite stays green with no scenario's arms moved — a
      config-only change to one Environment resource (Gate 1b, full suite)
- [ ] [screenshot] The f8760 horizon vantage: rim tree line and apron-to-city
      ground edge melt into the sky-horizon color — no hard horizontal value
      steps left (Gate 3)
- [ ] [screenshot] The same horizon frame must show the UPPER sky keeping its
      zenith-to-horizon gradient — no beige wash up the dome (the
      `fog_sky_affect = 0.0` judgement; a whole-frame read no machine check
      can make) (Gate 3)
- [ ] [screenshot] A 250 m city view: far streets still legible, no whiteout,
      deep apron keeps readable ground color (Gate 3)

## Verification

- **Gate 1:** headless import + boot, both exit 0, zero unexpected ERROR lines.
- **Gate 1b:** new `_scenario_env_far_field_fog` with its own
  `_check("env_far_field_fog", …)`, registered in the city block of the
  scenario list (e.g. beside `_scenario_city_district_theming`,
  `tests/sim_test.gd:293`). The check is a static instantiate-read of the
  main scene — `MAIN_SCENE` is already preloaded at `tests/sim_test.gd:14`;
  `instantiate()` → the `WorldEnvironment` node (`scenes/main.tscn:67-68`) →
  its `environment` — the in-tree instantiate-and-read pattern (settings
  scenarios e.g. `tests/sim_test.gd:8969` instantiate `MAIN_SCENE`;
  `poop_ball_visible` at `tests/sim_test.gd:2243-2264` reads meshes and
  materials the same way), needing no gameplay timing. NOTE: the plan's
  "T-150 static-read pattern" citation is forward-looking — T-150 is still
  proposed and not in the tree, so this ticket stands on the in-tree pattern
  above. Compare `fog_light_color` to
  `(env.sky.sky_material as ProceduralSkyMaterial).sky_horizon_color`
  per-channel < 0.001, never to a literal, so the keep-in-sync law is
  enforced rather than assumed. Free the instance after the read. Red-before:
  run the leg on the untouched tree — `fog_enabled` false → fail while every
  existing arm passes; after: full suite green.
- **Gate 2:** autoplay smoke, unchanged.
- **Gate 3:** the three [screenshot] lines above (the f8760 horizon frame
  serves both horizon criteria); the tuned `fog_density` (within
  0.0008–0.0015) and `fog_sky_affect` recorded in this ticket. Judge the
  combined horizon read with T-155's haze floor if both have landed.
- **VERIFICATION.md** (same change-set): new Gate 1b table row
  `env_far_field_fog` and the Gate 3 checklist lines.

# T-148 — Haze the skyline ring: apron monoliths dissolve into the horizon

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-088 (done — the rim + skyline pass this retunes)

## What

One post-roll, pure-math pass in `City._build_skyline` (`scripts/city.gd:930-948`): after the existing district-shade computation, blend each tower's instance color toward the sky-horizon haze by its normalized radius across the existing band. Two new consts beside the skyline salts (`scripts/city.gd:381-388`):

- `SKYLINE_HAZE := Color(0.85, 0.8, 0.7)` — `main.tscn`'s `sky_horizon_color` (`scenes/main.tscn:20`); the comment points there so the two stay in sync.
- `SKYLINE_HAZE_MAX := 0.85` — the blend weight a tower at the OUTER edge of the band receives (inner towers get ~0; tunable at the Gate 3 pass).

In `_build_skyline`, before the `_add_mm` call (`scripts/city.gd:947-948`):

```gdscript
var radius_norm := clampf((radius - inner) / (outer - inner), 0.0, 1.0)
shade = shade.lerp(SKYLINE_HAZE, radius_norm * SKYLINE_HAZE_MAX)
```

`radius` is already the `_skyline_roll(i, SKYLINE_SALT_RADIUS)`-drawn band position (`scripts/city.gd:935`), so `radius_norm` re-reads the same number — it is not a new draw.

What this does **not** claim: no fog node is added (the Environment at `scenes/main.tscn:27-32` stays as-is), no tower moves/resizes/despawns, no collider appears (the ring stays visual-only per the T-017 decision, `scripts/city.gd:927-929`). The safety claim the whole ticket rides on: **no RNG draw and no `_fp` entry is touched** — `_build_skyline` draws nothing from any stream and appends no `_fp` entries (`scripts/city.gd:909-929`; `fingerprint = _fp.hash()` at `scripts/city.gd:713`), so the cross-version fingerprint pins (foreign seed `1411023184`, default seed `1103197745`, `tests/sim_test.gd:4385-4388`) stay byte-identical. The change is color-only.

## Why

The T-088 skyline towers stand on the open grass apron at 192–347 m (`scripts/city.gd:920-924`, band `[span*0.5 + ground_extra*0.3, span*0.5 + ground_extra - 20]`), up to 60 m tall — over 3× the tallest real building (floors cap 6 × `floor_height` 3.0 + 0.25 roof slab = 18.25 m, `scripts/city.gd:428,444-446`) — colored `darkened(0.30-0.45)` district palette members (`scripts/city.gd:944-946`) with no fog in the Environment to fade them. At flight speed they read as REAL, landable city buildings — and they read DARKER than the city behind them, an inverted depth cue. Every tower is also far beyond the rim hedge (setback 0.5 m, `scripts/city.gd:217`), so they stand alone on empty grass with nothing to context them.

Evidence (sweep-1 visual-design captures, `.captures/` in the visual-design-s1 worktree):

- `session_vd1/f00023556.png` — the pigeon on a direct collision course with a lone blue-gray slab rising from empty grass, its hard black shadow dominating the frame.
- vd2's west-side shot — the same slabs read as part of the block row; vd2's roof shot — the pale sage towers on the opposite side already blend acceptably. The read varies wildly by district family (the quadrant pick at `scripts/city.gd:944`); a uniform radius-driven haze normalizes every family at once.

## Acceptance criteria

- [ ] Every queued skyline instance's color is the district shade lerped toward `SKYLINE_HAZE` by `radius_norm * SKYLINE_HAZE_MAX`: inner-band towers keep (nearly) their grounded district color, outer-band towers sit at up to `SKYLINE_HAZE_MAX` blend weight toward the haze (Gate 1b, new `city_skyline_haze` leg — red-before: the current tree stores the un-lerped shade)
- [ ] The ring's layout is untouched: the existing `city_horizon_skyline` count/placement/size/visual-only arms stay green, and the fingerprint pins hold (foreign `1411023184`, default `1103197745`, same-seed rebuild byte-identical)
- [ ] [screenshot] From cruise height at the rim, the outer ring reads as horizon haze — no hard-edged slab silhouettes casting ground shadows at the skyline (Gate 3)
- [ ] [screenshot] Inner-band towers still read as a distant city, not fog-eaten: the dissolve is graded across the band, not a uniform wash (Gate 3)

## Verification

- **Gate 1:** headless import + boot, both exit 0, zero unexpected ERROR lines.
- **Gate 1b:** extend `_scenario_city_horizon_skyline` (`tests/sim_test.gd:4330`) with a separate `_check("city_skyline_haze", …)` beside the existing one — keep the existing `_check` and its arms untouched so red-before is attributable to the new leg alone:
  - Replay the deterministic chain for `i` in `City.SKYLINE_COUNT`: the tall roll (`SKYLINE_SALT_CLASS`), the quadrant palette pick (`int(angle / (PI * 0.5)) % 4`, indexed with the GLOBAL `i`, per `scripts/city.gd:944`), and the shade roll (`SKYLINE_SALT_SHADE`). Append each expected color — `base.darkened(0.3 + roll * 0.15).lerp(SKYLINE_HAZE, t)` — to the expected list of the queue the tall roll selects (`skyline` / `skyline_tall`; each key's `_visuals` array is an `i`-ordered subsequence of the global chain).
  - Compare element-wise (per-channel distance < 0.001) against `_city._visuals[key].colors`: `_add_mm` stores per-instance colors (`scripts/city.gd:1899-1903`) and `_spawn_visuals` pushes them through `set_instance_color` (`scripts/city.gd:1914-1919`).
  - Read `SKYLINE_HAZE`, `SKYLINE_HAZE_MAX` and the salts from the `City` script consts, never literals, so Gate 3 tuning cannot desync the gate.
  - Full suite green after; red-before observed by running the leg on the untouched tree (the leg fails while every existing arm passes).
- **Gate 2:** autoplay smoke, unchanged.
- **Gate 3:** the two [screenshot] lines above, flown at the rim on the landed build; the tuned `SKYLINE_HAZE_MAX` recorded in this ticket.

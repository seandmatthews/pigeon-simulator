# T-013 — Juice pass v1

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** done
- **Depends on:** T-006, T-009 (polish can start once those land)
- **Refs:** `docs/DESIGN.md` → Pillars 2 & 3

## What

Make hits and moments pop:

- GPUParticles: splat burst on hit, feather poofs on hard flaps, dust puff on landing
- Tiny camera shake on landing and on your own splat hits (small — this is a cozy game)
- Lighting pass: warmer sun, per-district building color palette
- HUD score pulse on combo escalation

## Why

The difference between "systems work" and "game feels alive". Pure multiplier on
everything else.

## Acceptance criteria

- [x] Side-by-side with before, the game is noticeably more alive
- [ ] Still 60 fps with all particles active at max density
- [ ] No particle/popup spam overwhelming the screen; shake never nauseates
- [ ] District palettes are distinct without clashing with the locked art style

*(Criteria 1 and 4 are look judgements: the autoplay screenshots show the warm
sun, the four distinct district palettes around the plaza and the juice
firing (`effects=3`, `shake_peak=0.43` in the DONE line), and the average
autoplay fps was 130 — well past 60 — but "more alive", "not nauseating" and
"no clash" need human eyes. Pending Gate 3 playtest — see below.)*

## Landed (T-013)

- `scripts/one_shot_burst.gd` + `scenes/splat_burst.tscn` / `feather_poof.tscn`
  / `dust_puff.tscn` — one shared one-shot GPUParticles3D script (spawns
  emitting, frees itself after lifetime + burnout margin on a plain `_process`
  countdown so cleanup also works headless); the three scenes carry the looks.
  All join the `juice_effects` group — the autoplay DONE line reports the peak
  number alive at once.
- `scripts/poop.gd` — every splat fires a droplet burst at the hit point along
  the contact normal, parented to the hit body so moving targets carry it.
- `scripts/player.gd` — fully-rested flaps poof feathers (throttled by
  `feather_min_interval` so pacing never featherscreens); touchdowns kick dust
  and shake the camera, scaled by the recorded first-contact impact velocity
  (a straight drop settles a frame late with its speed already eaten by the
  slide — the juice reads the hit that actually happened).
- `scripts/chase_camera.gd` — trauma-based shake: `add_shake()` clamps into
  0..1, decay is linear, applied strength is trauma², the lens rides a
  fixed-seed noise pattern (h/v image offset + roll — the rig transform stays
  exact for the T-002 checks).
- `scripts/city.gd` — `FACADE_PALETTE` regrouped into four district palettes
  (warm brick / sandy cream / cool blue-gray / sage green); `district_of()`
  maps blocks to quadrants; buildings record `district` + `color` for tests.
- `scenes/main.tscn` — warm sun (`light_color` 1, 0.92, 0.78, energy 1.3) and
  warmer sky/ground horizon haze.
- `scripts/main.gd` — scored hits add a small camera shake; combo escalations
  pulse the HUD score line (scale arcs up with a TRANS_BACK overshoot and
  settles back, gold flash fades) and show the ×N.
- Verification: six Gate 1b scenarios (`city_district_palettes_distinct`,
  `juice_splat_burst_fires`, `juice_feather_poofs_on_hard_flap`,
  `juice_dust_puff_on_landing`, `juice_landing_shake_decays`,
  `hit_shake_and_score_pulse`); the autoplay DONE line now reports `effects`
  and `shake_peak`.

## Tuned values (final)

- `player.feather_flap_fraction` = 0.85 (rested fraction a flap needs to poof)
- `player.feather_min_interval` = 0.9 s — paced 0.35 s flapping poofs at most
  every other beat-and-a-half, never a screen of feathers
- `player.dust_impact_min` = 1.5 m/s — just under the flight model's natural
  glide-touchdown sink (~1.8 m/s measured in the harness), so every real
  landing puffs while curbside hops stay quiet
- `player.land_shake` = 0.45 trauma at a max-speed touchdown, scaled by
  impact/max_land_speed (floor 0.15) — a gentle landing is a ~0.3 tick
- `chase_camera.shake_max_offset` = 0.18 m · `shake_max_roll` = 0.03 rad ·
  `shake_decay` = 1.4/s (a hit's tick lasts ~0.2 s) · `shake_rate` = 24 ·
  fixed noise seed 20260928
- `main.hit_shake` = 0.3 trauma per scored splat
- `main.pulse_base_scale` = 1.14 (×2 escalation) · +0.05 per extra step, capped
  · `pulse_seconds` = 0.3 (40% up with overshoot, 60% settle)
- Particles: splat 24 drops, 0.55 s · feathers 8, 0.9 s · dust 14, 0.5 s —
  all one-shot, explosive, alpha-faded ramps
- Districts: `district_of()` quadrant mapping; palettes 3 colors each, means
  pairwise ≥ 0.22 apart in RGB (harness asserts > 0.1)

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: chained combo with all effects firing; confirm
frame rate holds and nothing obscures targets.

**Pending human playtest (Gate 3):** the four T-013 playtest lines — effects
read at flight speed without clutter; the shake stays a tick and never
nauseates with nothing obscuring targets; the warm sun and district palettes
read distinct-but-harmonious from the air; the HUD pulse reads clearly and
settles without jitter.

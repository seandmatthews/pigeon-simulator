# T-080 — Give the hunger bar a dark track/border — the white bar vanishes on bright ground

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** — (completes T-019's landed legibility work; feeds its pending human pass)
- **Refs:** VERIFICATION.md Known issues, the two pending T-019 human lines
  (`VERIFICATION.md:273-274`) · sweep 1 grabs cited below

## What

The hunger bar's healthy state is a borderless white fill on default styleboxes —
`scenes/main.tscn:83-91` declares NO theme overrides at all — so over white pavement and the
bright sky the at-a-glance fail-state element is effectively invisible until there is
already an emergency.

`scenes/main.tscn` only: add two `StyleBoxFlat` sub-resources and set them as the bar's
theme overrides:

- `theme_override_styles/background` — dark translucent track: `bg_color`
  `Color(0, 0, 0, 0.35)`, border 1 px on all four sides in the established dark-outline
  family `Color(0, 0, 0, 0.85)` (the label recipe at `main.tscn:78`), corner radius 3 (the
  default ProgressBar look);
- `theme_override_styles/fill` — `bg_color` pure WHITE with the same 1 px dark border and
  corner radius 3.

The white fill is the invariant that keeps T-019 intact: tier colors arrive via
`hunger_bar.modulate` (`scripts/main.gd:100,188`), which multiplies the whole node — a white
fill renders exactly the T-019 tier colors as today. The border is modulate-proof by
construction: its RGB channels are 0 and 0 × anything = 0, so it stays black in every tier
and mid-pulse.

Bump the scene header's `load_steps` by 2 (two new sub-resources; the file is hand-edited).
`show_percentage`, the node geometry, the tier constants and all
`_process`/`_on_hunger_changed` code stay untouched.

What this does NOT claim: no retune of the tier colors, thresholds or pulse; no HUD layout
change; nothing outside `scenes/main.tscn` and the extended scenario.

## Why

Session evidence (both images viewed this run): `uiuxs3a/window.png` — Hunger 70%, grounded
over the plaza — shows the white fill as a barely-visible sliver against the pavement/sky
backdrop (the plan's original "93%" was a misread; the grab shows 70%). Contrast
`uiuxs3b/f00010452.png` — Hunger 36%, amber tier 1 — where the fill reads instantly against
the same sky (companion frame `f00011520.png`, 28%). Players only discover the bar once it
turns amber — i.e. once it can no longer help them learn to look at it.
`VERIFICATION.md:273-274` still carries the pending T-019 human pass for exactly this
at-a-glance readability; this ticket is the scene-side half of that fix.

## Acceptance criteria

- [x] At tier 0 the bar reads as a bounded element — dark track + dark border — findable at
      a glance over white pavement at the spawn corridor and over the bright sky at
      altitude [screenshot]
- [x] Tier colors and pulses are unchanged: the fill renders white at tier 0 through the
      tier modulate, and the amber/red/flash tiers behave identically to today
- [x] `_scenario_hud_hunger_tiers` (`tests/sim_test.gd:2290`) extended with a
      resolved-stylebox assertion (below) passes, including all of its existing
      tier/pulse/restart assertions untouched
- [x] Full Gate 1b suite green
- [x] [screenshot] pass: the bar is findable at a glance at tier 0 over pavement, sky and
      road (side-by-side with before)

## Evidence (agent-played, pilot harness sessions `t080ui` / `t080after`)

Grabs under `.captures/t080_shots/` (session dirs swept, copies kept):

- `before_plaza.png` (99%, grounded at spawn corridor over road/pavement) vs
  `after_pavement.png` (99%, same spot): before, the full bar is a barely-there white
  sliver lost against the pale buildings; after, the white fill + dark track + dark
  border reads instantly. `after_road.png` (59%, grounded on the road) — tier 0, road
  backdrop, bar clearly bounded.
- `before_sky.png` (89%, airborne ~27 m) vs `after_sky.png` (85%, same flight profile):
  before, the fill is a dim grey pill on the pale sky; after, dark track and border make
  the bar findable at a glance.
- Tier colors unchanged: `after_amber.png` (34%, tier 1) shows the same amber fill as
  T-019 landed, now with the border staying black through the modulate;
  `after_red_pulse.png` (14.6%, tier 2) shows the red pulse fill over the dark track.
  The tier-3 flash was not visually captured (the idle run starved through it before the
  grab — `after_flash.png` is the starve screen); tier-3 behavior is machine-verified by
  the untouched pulse assertions in `hud_hunger_warning_tiers` (Gate 1b PASS, tier-3
  faster-than-tier-2 zero-crossing check) plus the white-fill modulate invariant.

## Verification record (this change-set)

- Gate 1: `--headless --import` exit 0 (only the documented benign
  "33 resources still in use" line); `--headless --quit-after 120` exit 0, no errors.
- Gate 1b: `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` — exit 0,
  84 `SIM PASS` lines, 0 `SIM FAIL`, including `hud_hunger_warning_tiers` with the new
  `styleboxes=True` term.
- Gate 2: `godot --path . res://tests/autoplay.tscn` — exit 0,
  `AUTOPLAY DONE ok=true … restart=true`, no SCRIPT ERROR.
- Gate 3: the two [screenshot] lines above (agent-played). The two pending T-019 human
  lines in VERIFICATION.md stay unticked — the human pass over feel/comfort is still
  open; this ticket only lands the scene-side legibility half.

## Verification

Gate 1 + Gate 1b — extend `_scenario_hud_hunger_tiers` with a config-class check exactly
parallel to its outline check (`tests/sim_test.gd:2303-2307`): resolve
`bar.get_theme_stylebox("background")` and `bar.get_theme_stylebox("fill")` as
`StyleBoxFlat`; assert both non-null, `border_color` ≈ `Color(0, 0, 0, 0.85)`, border
widths ≥ 1 on all four sides, and the fill's `bg_color` ≈ `Color.WHITE` (the tier-modulate
invariant). The scenario's tier/pulse assertions read `bar.modulate`, which this change
does not touch. Gate 2 runs normally. Gate 3: the two [screenshot] lines above; update the
pending T-019 human line (`VERIFICATION.md:273-274`) in the same change-set once played.

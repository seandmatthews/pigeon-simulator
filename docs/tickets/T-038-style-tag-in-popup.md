# T-038 — Show the style bonus in the score popup

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-009 (scoring & style) — done
- **Refs:** UI/UX lane playtest, sweep 1 (2026-09-29); `docs/DESIGN.md` → Scoring (T-009)

## What

Tag styled payouts so every popup on screen decomposes into base × combo +
style:

- `ScorePopup.format_text(points, multiplier, style := false)` — a third,
  defaulted parameter appending the tag: `"+150 ×2 STYLE"` (multiplier > 1) /
  `"+150 STYLE"` (multiplier == 1). Unstyled output is byte-identical to
  today's `"+%d ×%d"` / `"+%d"` (`scripts/score_popup.gd:22-25`).
- `ScorePopup.setup(points, multiplier, pos, style := false)` — same defaulted
  parameter, stored alongside the existing payload (`score_popup.gd:29-33`).
  Both existing callers keep compiling unchanged: `scripts/main.gd:259` and
  `tests/sim_test.gd:2622`, so the existing `"+100 ×2"` assertion
  (`tests/sim_test.gd:2624`) stays true.
- `Main._on_hit_scored` (`scripts/main.gd:257-260`) stops discarding the flag:
  `popup.setup(points, multiplier, pos, style)`.
- Styled popups tint their label the HUD pulse gold `Color(1.0, 0.85, 0.3)`
  (the color `_pulse_score` flashes, `scripts/main.gd:124`) so the tag reads as
  the same "special payout" language; the fade still owns the exit
  (`score_popup.gd:43` already tweens `modulate:a` — tint the RGB, leave the
  alpha tween alone).

Deliberately NOT in this ticket: a second Label3D tag in
`scenes/score_popup.tscn` (the idea listed it as optional; the single-label
tag keeps the blast radius at one script + one call site — revisit only if the
[screenshot] pass says the inline tag doesn't read); any scoring-math change
(`_register_hit`, `scripts/game.gd:151-163`, is untouched); any change to when
style applies (`_is_style_hit`, `scripts/game.gd:168-171`); popup lifetime,
rise or float.

## Why

A fast/low dive hit pays `roundi(base × multiplier × 1.5)`
(`scripts/game.gd:156`) but the popup renders only `"+%d ×%d"`
(`scripts/score_popup.gd:22-25`): a styled tourist hit at ×1 reads as a bare
"+150" with no label — the player cannot learn the skill expression DESIGN's
scoring table promises (`docs/DESIGN.md:68`, "+50% style bonus"). VERIFICATION's
own Gate 3 line expects the bonus "visible as a bigger popup number"
(`VERIFICATION.md:272`) — a bare 150 is not learnable feedback. The UI/UX lane
session never captured a live popup (~5 min of observed play, 0 scored hits;
autoplay DONE: splats=10, panics=0, score=0), so the code path is the
evidence: the `hit_scored` signal carries the style flag
(`scripts/game.gd:14`) and `main.gd:257` drops it on the floor
(underscore parameter).

## Acceptance criteria

- [ ] `ScorePopup.format_text(150, 2, true) == "+150 ×2 STYLE"` and
      `format_text(150, 1, true) == "+150 STYLE"`; every unstyled form is
      byte-identical to today's output (Gate 1b)
- [ ] Through the real Main: a fresh fast/low release (`Game.on_poop_released`
      at ≥ 14 m/s from ≤ 6 m height — `scripts/game.gd:26-27`) followed by
      `Game.add_tourist_hit` spawns a popup whose label contains the STYLE tag
      (150 paid at ×1) — Gate 1b only (needs the real signal path)
- [ ] A slow release (below `style_min_speed`) spawns a popup without the tag
      (100 paid at ×1) — Gate 1b only
- [ ] `score_popup_floats_and_fades` passes without editing its existing
      assertions (the defaulted parameter preserves `setup(100, 2, pos)`
      behavior exactly)
- [ ] Styled popups read as gold/special at a glance in a real hit — [screenshot]

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b — extend `_scenario_score_popup`
with the static format variants (cheap, no instancing), and add the two
real-Main style assertions inside `_scenario_juice_hit_shake_pulse`
(`tests/sim_test.gd:3474-3505`), a real-Main scenario where popups are
group-findable (`score_popups` group, `score_popup.gd:36`). **That scenario
today calls only `Game.add_tourist_hit` (`:3488`, `:3491`) — it never records
a poop release** (every `Game.on_poop_released` call in the harness lives in
the T-009 scoring scenario, `tests/sim_test.gd:2556-2585`, which has no
Main), so with no release `_release_age` sits at its stale 999 and the style
gate can never fire. The style checks therefore ADD the release themselves:
after the existing two hits, fire a fresh
`Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -18.0))`
(fast AND low — the scoring scenario's exact pattern), then a third
`add_tourist_hit` at ×3 pays 450 and labels "STYLE"; restore a slow release
(`on_poop_released` at −5 m/s) for a fourth hit that pays plain. The existing
assertions stay untouched. Full suite green. Gate 2: the autoplay asserts
nothing about popup text — unaffected. Gate 3: the T-009 line
(`VERIFICATION.md:272`) re-read as "styled hits are labelled, not just
bigger".

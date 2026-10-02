# T-038 — Show the style bonus in the score popup

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
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
  Both existing callers keep compiling unchanged: `scripts/main.gd:385` and
  `tests/sim_test.gd:3447`, so the existing `"+100 ×2"` assertion
  (`tests/sim_test.gd:3449`) stays true.
- `Main._on_hit_scored` (`scripts/main.gd:383-391`) stops discarding the flag:
  `popup.setup(points, multiplier, pos, style)`. One line — the same handler's
  T-040 HUD combo-strip write (`main.gd:388-391`) composes unchanged beside
  it, and the handler's own docstring already reserves the slot ("The STYLE
  suffix is T-038's, once that lands", `main.gd:381-382`).
- Styled popups tint their label the HUD pulse gold `Color(1.0, 0.85, 0.3)`
  (the color `_pulse_score` flashes, `scripts/main.gd:191`) so the tag reads as
  the same "special payout" language; the fade still owns the exit
  (`score_popup.gd:43` already tweens `modulate:a` — tint the RGB, leave the
  alpha tween alone).

Deliberately NOT in this ticket: a second Label3D tag in
`scenes/score_popup.tscn` (the idea listed it as optional; the single-label
tag keeps the blast radius at one script + one call site — revisit only if the
[screenshot] pass says the inline tag doesn't read); any scoring-math change
(`_register_hit`, `scripts/game.gd:151-163`, is untouched); any change to when
style applies (`_is_style_hit`, `scripts/game.gd:168-171`); popup lifetime,
rise or float (T-059's retune, still `proposed` — it explicitly excludes the
style tag, `T-059-score-popup-retune.md:39`).

## Why

A fast/low dive hit pays `roundi(base × multiplier × 1.5)`
(`scripts/game.gd:156`, `style_bonus_fraction` 0.5 at `game.gd:25`) but the
popup renders only `"+%d ×%d"`
(`scripts/score_popup.gd:22-25`): a styled tourist hit at ×1 reads as a bare
"+150" with no label — the player cannot learn the skill expression DESIGN's
scoring table promises (`docs/DESIGN.md:85`, "| Hit during a fast/low dive |
+50% style bonus |"). VERIFICATION's own Gate 3 line expects the bonus
"visible as a bigger popup number" (`VERIFICATION.md:285`) — a bare 150 is not
learnable feedback. The UI/UX lane session never captured a live popup (~5 min
of observed play, 0 scored hits; autoplay DONE: splats=10, panics=0, score=0),
so the code path is the evidence: the `hit_scored` signal carries the style
flag (`scripts/game.gd:14`) and `main.gd:383` drops it on the floor (the
`_style` underscore parameter). Nothing else claims this surface: T-040 landed
the HUD strip (a different component), T-079 the landing note, and T-059's
popup retune still disclaims the tag.

## Acceptance criteria

- [x] `ScorePopup.format_text(150, 2, true) == "+150 ×2 STYLE"` and
      `format_text(150, 1, true) == "+150 STYLE"`; every unstyled form is
      byte-identical to today's output (Gate 1b)
- [x] Through the real Main: a fresh fast/low release (`Game.on_poop_released`
      at ≥ 14 m/s from ≤ 6 m height — `scripts/game.gd:26-27`) followed by
      `Game.add_tourist_hit` spawns a popup whose label contains the STYLE tag
      (in the harness recipe the styled hit is the chain's first after a
      reset: 150 paid at ×1 → `"+150 STYLE"` — the Why's bare-150 case,
      labelled) — Gate 1b only (needs the real signal path)
- [x] A slow release (below `style_min_speed`) spawns a popup without the tag
      (the recipe's next hit — the chain now stands at 1, so ×2 plain: 200
      paid → `"+200 ×2"`) — Gate 1b only
- [x] `score_popup_floats_and_fades` passes without editing its existing
      assertions (the defaulted parameter preserves `setup(100, 2, pos)`
      behavior exactly — `tests/sim_test.gd:3447`, `:3449`)
- [x] Styled popups read as gold/special at a glance in a real hit — [screenshot]
      (reviewer sign-off 2026-10-02)

## Landed values (2026-10-02)

- Tag format: `"+%d STYLE"` at ×1, `"+%d ×%d STYLE"` chained —
  `format_text(points, multiplier, style = false)`, `scripts/score_popup.gd:32-36`;
  every unstyled form stays byte-identical to the T-009 output.
- Styled tint: `STYLE_COLOR := Color(1.0, 0.85, 0.3)` (`score_popup.gd:14`) —
  the HUD pulse gold `_pulse_score` flashes — applied to the label's RGB only
  (`score_popup.gd:51-53`); the fade tween keeps owning `modulate:a`.
- Nothing else retuned: popup lifetime 1.2 s / rise 1.8 m as T-009 landed, and
  the style gate is untouched (`style_bonus_fraction` 0.5, `style_min_speed`
  14.0, `style_max_height` 6.0, `style_release_window` 3.0 — `game.gd:25-28`).
- Machine evidence: Gate 1b `score_popup_style_tag_format` +
  `score_popup_style_tag_live` green inside the full suite (100 SIM PASS /
  0 failures, exit 0); Gate 1 and Gate 2 green. The reviewer sign-off
  (2026-10-02) covers the [screenshot] pass.

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b — extend `_scenario_score_popup`
with the static format variants (cheap, no instancing; their own `_check`, so
the existing `score_popup_floats_and_fades` assertions stay byte-identical),
and add the two real-Main style assertions inside
`_scenario_juice_hit_shake_pulse` (`tests/sim_test.gd:4735-4766`), a real-Main
scenario where popups are group-findable (`score_popups` group,
`score_popup.gd:36`). **That scenario today calls only `Game.add_tourist_hit`
(`:4749`, `:4751`) — it never records a poop release** (every
`Game.on_poop_released` call in the harness lives in the T-009 scoring
scenario, `tests/sim_test.gd:3375-3421`, which has no Main), so with no
release `_release_age` sits at its stale 999 (`game.gd:74`) and the style gate
can never fire. The style checks therefore ADD the release themselves — and
slot in AFTER the scenario's existing reads so nothing there moves: T-040's
landed combo assertion (`var combo_shown := label.text.contains("×2 combo")`,
`sim_test.gd:4755`, folded into the `hit_shake_and_score_pulse` `_check` at
`:4764`) must survive untouched. Insert after the settled read (`:4757-4759`)
and before the teardown (`main_game.free()`, `:4761`) — but do NOT assume the
existing two hits' chain is still live there: Main spawns its Player 6 m up in
`State.AIR` (`scenes/main.tscn` Player transform `(0, 6, 8)`;
`scripts/player.gd:117`), so mid-scenario it lands and Main's wiring
(`scripts/main.gd:103`) ends the chain — the landing fires just after the
frame-~10 `combo_shown` read (a headless probe replicating the scenario's
exact frame sequence observed it at frames 10-12 across runs) and the
insertion point reads `combo_mult=0 score=300` (the full Gate 1b suite still
passes — the existing reads are unaffected). Stage the chain state explicitly
instead of trusting the landing's frame: first
`Game.on_grounding_changed(true)` (the landing reset, idempotent — the scoring
scenario's own idiom, `:3385`), then a fresh
`Game.on_poop_released(Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -18.0))`
(fast AND low — the scoring scenario's exact vector, `:3388`) and an
`add_tourist_hit`: the chain's first hit, ×1 styled, pays
`roundi(100 × 1 × 1.5)` = 150 and its popup reads `"+150 STYLE"` — the exact
bare-150 case the Why section describes, now labelled. Then restore a slow
release (`Vector3(0.0, 3.0, 0.0), Vector3(0.0, 0.0, -5.0)`, the `:3394`
vector) for the styled block's second hit: the chain now stands at 1, so it
is ×2 plain and pays 200 — `"+200 ×2"`, no STYLE (the ×3-styled-450
arithmetic stays where it is already asserted, the scoring scenario's
`p6 == 450` at `:3390-3391`). Await a few frames for the popups' `_ready` to
apply the text, read them back through the `score_popups` group BEFORE
`main_game.free()` frees them — by then the two earlier popups have freed
(1.2 s lifetime vs ~1.6 s elapsed), so exactly one popup contains STYLE and
it is `"+150 STYLE"`, while the `"+200 ×2"` beside it carries no tag — and
give the style results their own `_check` so the existing check line is not
edited. The existing assertions stay untouched. The VERIFICATION Gate 1b
table gains rows for the new check ids in the same change-set. Full suite
green. Gate 2: the autoplay asserts nothing about popup text (no popup
reference in `tests/autoplay.gd`) — unaffected. Gate 3: the T-009 line
(`VERIFICATION.md:285`) re-read as "styled hits are labelled, not just
bigger" — the [screenshot] pass above.

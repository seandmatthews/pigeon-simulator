# T-160 — Mark a spent target on repeat hits: "favor paid" on the readout

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-147 (favor once per target, done) · T-151 (class-named readouts, done)
- **Refs:** T-140 (`docs/tickets/T-140-pilot-frame-step.md:48-54` — the
  beat-the-game run re-splatted ONE parked visitor car 17 times for favor) ·
  T-147's gate (`scripts/main.gd:693-699`, `719-725`).

## What

Since T-147 a repeat splat pays full score but books zero favor — and the
readout quietly loses its gold. "Visitor car +30" in the rest tint with no
favor note is one missing tint away from looking like a broken bonus. Name
the spent state at the moment the gold disappears: append a dim suffix to
the readout when the T-147 gate skipped the favor call.

Changes:

1. `scripts/main.gd` — stash a `_last_hit_books_favor: bool` beside
   `_last_hit_favor_delta` (`main.gd:174`), set in BOTH splat handlers —
   `_on_tourist_splatted` (`main.gd:693-699`) and `_on_car_splatted`
   (`main.gd:719-725`) — true exactly when the T-147 `splatted_once` gate
   books the favor, false on repeats. It joins the T-151 stash reset in
   `restart_run()` (`main.gd:903-906`), so a post-restart synthetic hit
   claims no suffix (the existing restart leg in
   `hit_feedback_names_the_class`, `tests/sim_test.gd:9789-9797`, guards
   exactly this).
2. `scripts/main.gd` `_on_hit_scored` (`main.gd:750-768`) — compose
   `suffix := " · favor paid"` when `_last_hit_books_favor` is false AND
   `_last_hit_kind` is non-empty (the same real-splat convention the class
   prefix follows — synthetic `Game.add_*_hit` entries claim nothing). The
   suffix rides the REST tint: `_last_hit_favor_delta` is 0 on a repeat, so
   the existing tint path (`main.gd:753-759`) already stays at rest — the
   suffix re-golds nothing. Strip form appends after the multiplier:
   `"Visitor car +30 · favor paid"` (chained: `"... ×N · favor paid"`).
3. `scripts/score_popup.gd` — `format_text` gains a trailing
   `suffix: String = ""` appended LAST (after the STYLE tag), and `setup`
   gains `suffix: String = ""` after `tint` (`score_popup.gd:47-52`,
   `:60-67`). The empty defaults keep every pinned legacy form
   byte-identical: the static format pins at `tests/sim_test.gd:10281-10284`
   (`"+150"`, `"+150 ×2"`, `"+150 STYLE"`, `"+150 ×2 STYLE"`) call
   `format_text` without a suffix and stay green untouched
   (`score_popup_style_tag_format`, `VERIFICATION.md:145`).

The label renders one modulate, so "dim suffix" means the suffix shares the
readout's rest tint on a repeat — which is the whole point: the spent state
is named IN the tint the player is already looking at, not re-golded.

What this does NOT claim: no change to scoring, to the T-147 gate, or to
favor booking; no favor-meter note on repeats (delta 0 arms none —
`main.gd:820-823` unchanged); the suffix is informational only.

## Why

Farming a parked jackpot car is a real, recorded strategy — the T-140
beat-the-game run re-splatted one parked visitor car 17 times
(`docs/tickets/T-140-pilot-frame-step.md:48-54`) — and every repeat readout
silently drops its gold with no stated reason. Play history this sweep: score
climbing to 60 while favor stood at 4/100, with the bare white strip as the
only feedback (captured in the session's `b_splat_grind.png`; that grab
lives in the eval worktree's capture dir and is not in this checkout —
cited as session evidence per the sweep plan). The code path: both handlers
stash `_last_hit_favor_delta = 0` when `splatted_once`
(`main.gd:693-699`, `719-725`), `_on_hit_scored` renders the bare class form
at rest tint (`main.gd:750-768`), and delta 0 arms no favor note
(`main.gd:820-823`) — three moving parts, zero of which say "already paid".

## Acceptance criteria

- [ ] (Gate 1b) `hit_feedback_names_the_class` gains a re-splat leg using the
      T-147 double-splat recipe verbatim — `visitor_car.on_splatted(...)`
      twice on one parked visitor car (the recipe as it runs in
      `splat_favor_once_per_target`, `tests/sim_test.gd:9513-9516`): hit 2's
      popup `%Text` AND the combo strip read WITH the `" · favor paid"`
      suffix at the rest tint, while every first-hit leg stays gold with NO
      suffix.
- [ ] (Gate 1b) `score_popup_style_tag_format` re-runs green untouched — the
      four pinned legacy forms stay byte-identical under the empty-suffix
      default (`tests/sim_test.gd:10281-10284`).
- [ ] (Gate 1b) The restart leg stays green: after `restart_run()` a
      post-restart synthetic hit claims no class word and no suffix —
      `_last_hit_books_favor` joined the stash reset
      (`tests/sim_test.gd:9789-9797` leg unchanged).
- [ ] (Gate 3) [screenshot] A live repeat splat on a parked visitor car
      showing the dim " · favor paid" strip while the favor meter holds
      still, recorded in this ticket.

## Verification

Gate 1 (import + boot) + Gate 1b: the extended
`hit_feedback_names_the_class` (re-splat leg documented in its
`VERIFICATION.md:137` row, reworded in the same commit) + full suite green
with `score_popup_style_tag_format`, `hud_combo_strip_reports_last_hit`
(`VERIFICATION.md:154` — first-hit forms carry no suffix, must stay
byte-identical) and `splat_favor_once_per_target` explicitly re-run. Gate 2
unaffected (presentation text only). Gate 3: the screenshot leg above.

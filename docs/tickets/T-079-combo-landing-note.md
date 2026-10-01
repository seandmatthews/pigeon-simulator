# T-079 — Acknowledge the combo a landing kills — the loss moment is invisible

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** — (no code dependency; the player value lands once T-060 makes hits reachable)
- **Refs:** `docs/DESIGN.md` → scoring (streaks without landing multiply) · T-040 (hit strip —
  shows what you hit; this shows what landing cost) · T-060 (makes hits reachable)

## What

When a ×2+ combo is live and the pigeon lands, show a transient HUD note — "landing ended
the ×2 combo" — for 2.5 s of game time. Today the loss is silent.

1. **`scripts/main.gd`** — in `_on_grounding_changed` (`scripts/main.gd:265-266`):
   - **Load-bearing order.** Main connects its own handler BEFORE `Game.on_grounding_changed`
     (`scripts/main.gd:62-63`), so inside Main's handler `Game.combo_multiplier()`
     (`scripts/game.gd:82-85`) still returns the PRE-reset streak; Game's `_end_combo`
     (`scripts/game.gd:110-113`) only runs afterward. Read the multiplier there and put a
     comment on the invariant at the read site — a future connect reorder silently breaks
     the note (this ordering dependency is why Risk is 2).
   - If `Game.combo_multiplier() >= 2`: set `%ComboNote.text = "landing ended the ×%d combo"`,
     make it visible, and start a game-time expiry — `const COMBO_NOTE_SECONDS := 2.5` beside
     the hint consts (`scripts/main.gd:12-15`), counted down in `_process` (the
     `_pulse_phase` game-time pattern, `scripts/main.gd:57,96-100`); hide when it elapses.
     Guard the writes with changed-value checks (the T-035/T-055 concern).
   - `restart_run()` clears it explicitly — text "" and the countdown zeroed, next to the
     popup/poop sweeps (`scripts/main.gd:242-245`). `Game.reset_run()` zeroes the streak but
     would not clear a mid-display note.
2. **`scenes/main.tscn`** — new `ComboNote` Label: `unique_name_in_owner = true`, hidden by
   default, stacked under the bread pointer (the pointer's row ends at offset_bottom 112,
   `main.tscn:105-111`; suggest 16..500 × 112..132), wearing the pointer's exact T-019
   recipe (`font_outline_color Color(0, 0, 0, 0.85)`, `outline_size` 4, `font_size` 14,
   white 0.75 — `main.tscn:112-115`).

What this does NOT claim: no scoring change (`scripts/game.gd` untouched); no duplication of
T-040's strip/marker (that shows what you hit; this shows what landing cost); no new
mechanic — purely the teaching note.

## Why

DESIGN sells "streaks without landing multiply", but landing — which the hunger loop forces
constantly — silently erases the ×N multiplier (`scripts/game.gd:110-113` → `_end_combo`, no
event, no presentation). The only display is the "×N combo" suffix on the stats line
(`scripts/main.gd:89-95`) that simply vanishes. No session has ever watched a combo die: all
three sweep-1 sessions show `streak: 0` in every one of their 57,410 combined state.jsonl
samples (re-counted this run), matching T-060's autoplay evidence (`panics=0 score=0`). That
is exactly why the loss moment must teach the rule at the instant it bites, once T-060 makes
hits reachable.

## Acceptance criteria

- [x] Landing while a ×2+ combo is live shows "landing ended the ×2 combo" for 2.5 s of game
      time, then clears without disturbing the rest of the HUD
- [x] Landing with no live combo shows nothing
- [x] `restart_run()` mid-display clears the note immediately
- [x] Gate 1b scenario `combo_note_on_landing` passes (below), driving the REAL
      `grounding_changed` signal rather than calling the private handler
- [x] Full Gate 1b suite green, explicitly `scoring_values` and both HUD scenarios

## Verification

Gate 1 + Gate 1b — new scenario `combo_note_on_landing` through a real Main (the
`_scenario_hud_hunger_tiers` own-space pattern, `tests/sim_test.gd:2290-2296`;
`Game.save_path = SIM_SAVE_PATH`; reuse that scenario's free /
`Game.hunger.player = null` / `Game.reset_run()` cleanup, `tests/sim_test.gd:2364-2366`):

- two `Game.add_tourist_hit(...)` calls (the synthetic-hit pattern,
  `tests/sim_test.gd:1858`) → streak 2;
- emit the REAL signal — `main_game.player.grounding_changed.emit(true)` — NOT a direct
  `_on_grounding_changed` call, so both connections fire in connect order and the
  load-bearing invariant above stays covered → `%ComboNote.text` contains "×2";
- advance ≥ 190 physics frames (> 2.5 s at the fixed 60 Hz) → empty and hidden;
- emit again with streak 0 → stays empty;
- rebuild a streak, emit, then `main_game.restart_run()` mid-display → empty.

Register it in `_run_scenarios` (`tests/sim_test.gd:84`+). Gate 2 runs normally. Gate 3
line: with a live combo (needs T-060-era hit rates, or a debug affordance), the note reads
at a glance and doesn't crowd the pointer row — if it can't be played yet, record it as a
pending human note in the ticket.

## Implementation notes (this change-set)

- **Tuned values (final):** note lifetime `COMBO_NOTE_SECONDS := 2.5` s of game time
  (`scripts/main.gd`, beside the hint consts); note text "landing ended the ×%d combo"
  from the live pre-reset multiplier; rect 16..500 × 140..160 (one 20 px row under the
  T-040 strip's 116..136, same 4 px rhythm as pointer→strip); the pointer's exact T-019
  recipe — `font_outline_color Color(0, 0, 0, 0.85)`, `outline_size` 4, `font_size` 14,
  `font_color Color(1, 1, 1, 0.75)`; expiry and restart clear wipe text + visibility +
  countdown together.
- **Placement deviation from the suggested rect.** The suggested 16..500 × 112..132 was
  written before T-040's `ComboStrip` occupied that exact row (116..136, `main.tscn`) — the
  two would overlap, and both are transient notes that are routinely visible together
  (hit → land within 2.5 s). The `ComboNote` sits one row *under* the strip instead:
  16..500 × 140..160, same 4 px rhythm as pointer→strip, same span, the pointer's exact
  T-019 recipe (outline black 0.85, outline_size 4, font_size 14, white 0.75). The scenario
  pins `note.offset_top >= combo_strip.offset_bottom` so the stacking stays honest.
- **Gate evidence (run in this change-set):** Gate 1 `--import` exit 0 and 120-frame boot
  exit 0 (no ERROR/SCRIPT ERROR/Parse Error; the ObjectDB-leak WARNING and the `--import`
  "33 resources still in use" line pre-exist on the pristine tree — verified by stash
  round-trip); Gate 1b full suite 97 PASS / 0 FAIL, exit 0, no SCRIPT ERROR, explicitly
  `combo_note_on_landing`, `score_combo_style_values`, `hud_hunger_warning_tiers`,
  `hud_combo_strip_reports_last_hit` (and `hud_bread_pointer_tracks_nearest_crumb`);
  Gate 2 autoplay `AUTOPLAY DONE ok=true … restart=true`, exit 0.
- **PENDING HUMAN PLAYTEST NOTE (Gate 3):** with a live combo the note must read at a
  glance and not crowd the strip/pointer rows — not playable at current hit rates (no
  session has ever built a streak; needs T-060-era hit rates or a debug affordance). The
  pending line lives in VERIFICATION.md's Gate 3 checklist, T-079 entry.

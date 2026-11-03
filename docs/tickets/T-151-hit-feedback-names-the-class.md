# T-151 — Name the class on every hit readout

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** T-113/T-114 (class + favor tables, landed) · T-121's owner misread —
  *"Sometimes a car is just yellow and its wheels are black but it's not a
  black/yellow target car"* (`docs/tickets/T-121-unmistakable-targets.md:5-6`) —
  the same read failure one step earlier in the chain · T-154 (retires the
  last pedestrian hue-twin; independent of this ticket).

## What

Carry the citizen class through the hit feedback chain — world popup, HUD
combo strip, game-over breakdown — using the class Main **already has in
hand** at splat time. No signal change: `hit_scored` keeps its exact 4-arg
payload (`scripts/game.gd:18`), because three harness listeners use 4-arg
lambdas (`tests/sim_test.gd:9427`, `tests/sim_test.gd:9810`,
`tests/capture_recorder.gd:489`) and the deliberately class-free synthetic
entries (`Game.add_tourist_hit`, `scripts/game.gd:268-270`) must keep
rendering without a class claim.

Design — the `_last_hit_kind` stash generalized (its own comment at
`scripts/main.gd:166` says hit_scored carries points but not the kind, so
Main stashes the word):

1. `scripts/citizen_class.gd` — new static `label(kind: Kind) -> String`
   returning `"Civilian"` / `"Visitor"` / `"Superfan"`.
2. `scripts/main.gd` — beside `_last_hit_kind` (`main.gd:166`), Main keeps
   `_last_hit_class` (CitizenClass.Kind) and `_last_hit_favor_delta: int`,
   set in `_on_tourist_splatted` (`main.gd:660-665` — `tourist.citizen_class`
   is read there already) and `_on_car_splatted` (`main.gd:677-682`);
   `_last_hit_favor_delta` captures the return of `Game.splat_favor(...)`
   (`game.gd:301-311` returns it today — the handlers drop it), `0` when the
   T-147 `splatted_once` gate skips the favor call. All three reset in
   `restart_run()`'s HUD reset block (`main.gd:797-809`). Declared behavior
   change: `_last_hit_kind` is NOT reset there today, so a post-restart
   synthetic hit inherits a stale word — this ticket fixes that.
3. `_on_hit_scored` (`main.gd:700-708`) composes a class prefix: tourists
   `"Visitor "`/`"Civilian "`/`"Superfan "`, cars `"Visitor car "`/`"Civilian
   car "`/`"Superfan car "` (prefix carries its own trailing space), empty
   stash → bare legacy form (synthetic hits read `"+100"`, claiming no
   class). The strip shows the same wording — `"Visitor +100 ×2"` replaces
   `"Tourist +100 ×2"`. The favor tint rides the same hit: strip and popup
   tint gold (`MainGame.FAVOR_GAIN_COLOR`, `main.gd:37`) on a stashed delta
   > 0, red (`FAVOR_LOSS_COLOR`, `main.gd:38`) on < 0, existing colors at 0;
   the strip restores its T-019 white when it clears. A styled popup keeps
   its STYLE gold (`score_popup.gd:61-63` wins over the favor tint).
4. `scripts/score_popup.gd` — `setup()` and static `format_text()`
   (`score_popup.gd:42-50`) gain `prefix: String = ""` (prepended verbatim)
   and `setup` gains `tint: Color = Color(1, 1, 1, 1)`; empty/no-op defaults
   keep every existing form byte-identical (`"+150"`, `"+150 ×2"`,
   `"+150 STYLE"`, `"+150 ×2 STYLE"`). Says nothing beyond the word — no
   claim about which class paid what.
5. `scripts/game_over_screen.gd` `_open` (`game_over_screen.gd:64-80`) gains
   `class_split: String = ""`, appended before the Favor total (victory
   form) / at the end (starved form); empty split keeps both forms
   byte-identical. Main composes the split from its own per-class splat
   tally (Dictionary keyed on Kind, incremented in both splat handlers —
   every splat counts, matching `tourist_hits`/`car_hits`), e.g.
   `" (visitor 1 · civilian 2)"`; empty when the tally is empty. The only
   callers are `main.gd:756` and `main.gd:772`.

**Declared same-commit re-pins** (the guards that own the touched strings —
one commit, re-pins included):

- `tests/sim_test.gd:11846-11847` + `11861` (`combo_strip_reports_last_hit`
  exact texts `"Tourist +100"` / `"Tourist +200 ×2"` / `"Car +30"`) —
  re-pinned to derive the expected word from each emitted node's own
  `citizen_class` (seed-robust), never from literals.
- `tests/sim_test.gd:10213-10214` (victory exact breakdown) — re-pinned to
  carry the visitor split. The starved zero-run exact pin at `10259` stays
  byte-identical (empty tally → empty split) and must stay green.
- `tests/sim_test.gd:9992-9995` (format_text pins) and `10003`/`10034-10036`
  (popup bare texts) stay green under the empty-prefix default — declared
  verification points, not edits.
- `VERIFICATION.md` rows updated: `hud_combo_strip_reports_last_hit` (row
  ~153), `score_popup_style_tag_live` (row ~145 — its `"+150 STYLE"` leg
  reads a real crowd and must derive the word),
  `favor_max_ends_run_victory` (row ~135), `game_over_shows_score_screen`
  (row ~148 — contains-legs survive), plus the new row below.

## Why

After a splat the player cannot tell WHICH class they hit. A visitor jackpot
(+6 favor), a civilian friendly-fire (−1/−2) and a superfan disaster (−8)
read identically as `"+30"` / `"Tourist +100"` / `"Car +60 ×2"` — the only
class signal is a bare favor delta that decodes only if you memorized a
table the game never shows. The uiux2 frozen frames make the cost concrete:
a visitor car reads `Car +30` beside a gold `Favor: 6 / 100 (+6)` while a
civilian car reads `Car +60 ×2` beside a red `Favor: 4 / 100 (-2)` —
identical `+N` shapes, and the friendly-fire hit paid MORE score than the
jackpot. T-121's refs record the owner misidentifying gold-adjacent cars
pre-fix — the same read failure one step earlier in the chain — and the
T-121 Gate 3 aerial check is still pending owner eyes.

## Acceptance criteria

- [ ] (Gate 1b) On the all-visitor rig through the real Main chain, the
      spawned popup's `%Text` reads `"Visitor +100"` (gold tint) and
      `%ComboStrip` reads `"Visitor +100"` — on today's tree they read bare
      `"+100"` / `"Tourist +100"` (red-before, real).
- [ ] (Gate 1b) All-civilian tourist → `"Civilian +100"` red-tinted (−1);
      parked civilian car → `"Civilian car +30"` red-tinted (−2); parked
      visitor car → `"Visitor car +30"` gold-tinted (+6); superfan →
      `"Superfan +100"` red-tinted (−8); the strip wording matches the
      popup's in every leg.
- [ ] (Gate 1b) A synthetic `Game.add_tourist_hit` on a fresh Main renders
      the bare `"+100"` — no class word (the class-free entry claims
      nothing; `score_popup_chain_stagger` stays green untouched).
- [ ] (Gate 1b) `format_text`/`setup` with the empty prefix produce
      byte-identical legacy forms — `score_popup_style_tag_format` green
      untouched.
- [ ] (Gate 1b) The starved zero-splat breakdown stays exactly
      `"Tourists splatted: 0    Cars splatted: 0"`; a run with real splats
      appends the per-class split; the victory register carries it before
      the Favor total.
- [ ] The strip clears to empty AND the rest tint after
      `combo_strip_seconds`; `restart_run()` resets the stash (no stale
      class across runs).

## Verification

Gate 1 (import + boot) + Gate 1b: new scenario
`hit_feedback_names_the_class` on the `splat_favor_follows_citizen_class`
instanced-Main pattern (`tests/sim_test.gd:9260`): own-space Main, share-knob
rigs (`visitor_share` / `superfan_share` + `_populate()`), duck-typed
`on_splatted` entries, popup read through the `score_popups` group inside the
1.2 s lifetime (the `10027-10036` recipe), tint asserted against
`MainGame.FAVOR_GAIN_COLOR`/`FAVOR_LOSS_COLOR`; the class-split leg starves
the run via the `drain_per_second` compression (`10129` recipe) and reads the
breakdown. Full suite green with the declared re-pins. Gate 2 unaffected —
presentation-only, no scoring change. Gate 3: [screenshot] a visitor-car
jackpot popup + strip read gold `"Visitor car +30"` at typical flight
distance; [screenshot] a civilian friendly-fire reads red; [screenshot] the
game-over screen shows the class split — owner eyes, recorded here.

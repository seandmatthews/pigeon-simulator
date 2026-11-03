# T-159 — The starved game-over screen should carry the favor goal it ignored all run

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-010 (the score screen, done) · T-115 (the two registers, done) · T-151 (the split, done)
- **Refs:** `docs/DESIGN.md` Milestone 2 — favor-max-or-starve is the locked
  run shape (T-115) · T-151 (the per-class split riding the breakdown).

## What

Append a Favor line to the game-over breakdown in BOTH registers, so the
run's stated goal appears on the one screen where a run is judged:

- **Starved form** becomes
  `Tourists splatted: N    Cars splatted: N (split)    Favor: n / max`
  — the balance over the ceiling, the same form the HUD favor meter composes
  (`scripts/main.gd:829-830`, `"Favor: %d / %d"` interpolated from
  `Game.favor_max` so a T-115 retune re-labels the screen along with the
  meter).
- **Victory register keeps its landed form byte-identical**
  (`...    Favor: <favor>` — always the clamped max on a real win). The
  asymmetry is deliberate: the victory form is pinned byte-exact by the
  suite (`tests/sim_test.gd:10503-10504`) and this ticket must not move it.

Changes:

1. `scripts/game_over_screen.gd` — `open()` gains a trailing
   `favor: int = 0` param and forwards it into `_open`'s EXISTING `favor`
   parameter (today `open()` hard-passes 0, `game_over_screen.gd:54`; `_open`
   already takes `favor` for the victory branch, `game_over_screen.gd:70`).
   The starved branch (`game_over_screen.gd:83-85`) appends
   `"    Favor: %d / %d" % [favor, Game.favor_max]` — one autoload read for
   the ceiling, mirroring `main.gd:830`, so the screen owns the format and
   Main stays a pure passthrough. The victory branch (`:80-82`) is untouched.
   The `_open` both-registers-rewrite contract (`game_over_screen.gd:67-68`)
   already covers the new line: both branches compose the whole breakdown, so
   neither register can leak its Favor form into the other across restarts.
2. `scripts/main.gd` `_on_game_over` (`main.gd:852-859`) — the one `open()`
   call site in the tree (verified: `game_over_screen.open` /
   `open_victory` appear only at `main.gd:857` and `main.gd:874`; the harness
   drives the screen only through real starvation/victory paths) — passes
   `Game.favor`.

What this does NOT claim: no change to scoring, favor booking, or either
ending's trigger; the split keeps riding where T-151 put it (before the
Favor total, matching the victory ordering); the victory register's title,
dim, note and breakdown stay byte-identical.

## Why

The run's stated goal is the elders' favor, but the STARVED! register shows
only score, high score and the tourist/car counts — a player who starved at
favor 96/100 sees neither the balance nor how close the town was. Session B
(pilot capture, this sweep): the starved screen at Score 0 shows
"Tourists splatted: 0    Cars splatted: 0" and no favor at all, while the
same run's HUD had shown "Favor: 6 / 100 (+6)" (captured in the session's
`b_gameover.png`; that grab lives in the eval worktree's capture dir and is
not in this checkout — cited as session evidence per the sweep plan). The
code agrees: the victory branch interpolates Favor and the starved branch
does not (`game_over_screen.gd:81-85`), and `_on_game_over` passes no favor
(`main.gd:857-859`).

## Blast radius — the declared same-commit re-pins

Two exact starved-form pins and two VERIFICATION rows break BY DESIGN and
must re-pin in the same commit (the sweep plan named the first; the other
two were found re-verifying the plan):

1. `tests/sim_test.gd:10551` — `favor_max_ends_run_victory`'s starved
   coexistence leg pins the exact zero-run form
   `"Tourists splatted: 0    Cars splatted: 0"` (the leg stages
   `Game.favor = 2` at `sim_test.gd:10538`). NOTE: the sweep plan cited
   "~10259, per T-151's notes" — the pin has MOVED; it sits at 10551 on
   the current tree (verified this session). Re-pin to
   `"Tourists splatted: 0    Cars splatted: 0    Favor: 2 / 100"`.
2. `tests/sim_test.gd:9780-9783` — `hit_feedback_names_the_class`'s
   `split_ok` leg pins the exact starved split form
   `"Tourists splatted: %d    Cars splatted: %d (visitor 2 · civilian 2 ·
   superfan 1)"`. Re-pin to compose the same
   `"    Favor: %d / %d" % [Game.favor, Game.favor_max]` suffix.
3. `VERIFICATION.md:135` (`favor_max_ends_run_victory`) — its starved
   coexistence prose says "the legacy form stands byte-identical"; reworded
   for the Favor line. `VERIFICATION.md:137`
   (`hit_feedback_names_the_class`) — documents the exact starved split
   form; reworded. `VERIFICATION.md:149` (`game_over_shows_score_screen`;
   the plan said ~148 — verified at 149) — mentions the new Favor line.

The victory exact pin (`tests/sim_test.gd:10503-10504`) must stay green
UNTOUCHED — if it needs editing, the victory form changed, which is out of
scope.

## Acceptance criteria

- [ ] (Gate 1b) New scenario `game_over_shows_favor_in_starved_register` on
      the instanced-Main rig (the T-115 pattern, `sim_test.gd:10462-10564`):
      stage `Game.favor = 37`, starve mid-run via the
      `drain_per_second = 60` compression (`sim_test.gd:10539-10546`) →
      the breakdown ends `"    Favor: 37 / 100"`.
- [ ] (Gate 1b) A fresh starved run at favor 0 shows the same line ending
      `"    Favor: 0 / 100"` — neither register leaks (the
      both-registers-rewrite contract pinned in the same scenario).
- [ ] (Gate 1b) The victory register's exact breakdown form stays
      byte-identical: the `sim_test.gd:10503-10504` pin passes UNCHANGED.
- [ ] (Gate 1b) Both declared re-pins (`sim_test.gd:10551`,
      `sim_test.gd:9780-9783`) re-pinned and green in the same commit, full
      suite green.
- [ ] (Gate 3) [screenshot] Starved screen showing the Favor line under the
      splat counts, recorded in this ticket beside the session-B grab.

## Verification

Gate 1 (import + boot) + Gate 1b: new `game_over_shows_favor_in_starved_register`
(VERIFICATION.md row beside `game_over_shows_score_screen`, ~149) + full
suite green with `favor_max_ends_run_victory`, `hit_feedback_names_the_class`
and `score_popup_style_tag_format` explicitly re-run (the last guards that
the popup side of T-151's chain is untouched). Gate 2 unaffected
(UI text only). Gate 3: the screenshot leg above.

# T-073 — Take the high-score save off the scoring hot path (save once per run, flush at game over)

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** code-optimization · **Value (1-5):** 2 · **Risk (1-5):** 2
- **Depends on:** — (T-009 scoring/high score, T-005 hunger and T-010 game-over flow, whose surfaces it touches, are landed)
- **Refs:** sweep 1 planning lane (code quality & performance) · line numbers on commit f77da93, this tree

## What

`scripts/game.gd` only — no new exports, no input actions, no scene changes.
Today every record-beating hit performs a synchronous `ConfigFile.save` on the
hit frame: `_register_hit()` calls `_save_high_score()` unconditionally once
`score > high_score` (`game.gd:145-148`), and `_save_high_score()` is a
synchronous `cfg.save(save_path)` (`game.gd:166-171`). The change turns that
per-hit write into a first-beat write plus a dirty-flag flush:

1. **First beat stays on the hot frame** — the crash-safety intent documented
   at `game.gd:46-47` ("written to save_path as soon as a run beats it, so a
   crash or an Alt-F4 still keeps the record") is preserved for the moment the
   OLD record first falls. Add `var _saved_this_run: bool = false`; on a beat,
   write immediately only when `not _saved_this_run`, then set it. Every
   further beat in the same run only sets `var _high_score_dirty: bool = true`.
   `reset_run()` (`game.gd:119-126`) clears both alongside `record_beaten` (it
   deliberately keeps `high_score`).
2. **`_flush_high_score()`** — if `_high_score_dirty`: `_save_high_score()`;
   then clear the flag.
3. **Game-over flush** — in `_ready()` (`game.gd:65-69`), connect
   `hunger.game_over.connect(_flush_high_score)`. Game owns its Hunger
   instance (`game.gd:66-68`), so every game over — Main's fail state
   (`main.gd:72`) and headless harnesses alike — flushes; Main needs no
   change.
4. **Quit/teardown flush** — `_notification()` handles
   `NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_PREDELETE` with
   `_flush_high_score()` (the dirty guard makes both no-ops when clean; the
   predelete arm covers teardown paths that never deliver the window
   notification).
5. **Test hook** — `var _save_count: int = 0`, incremented inside
   `_save_high_score()` past the `_persistence_enabled` guard, so it counts
   real disk writes and Gate 1b can assert on it.
6. **Docstrings** — `game.gd:5-6` and `game.gd:46-47` are updated to the
   honest contract: the record is written the moment a run FIRST beats it
   (that write keeps a crash safe); further beats flush at game over or quit —
   so a crash mid-chain now keeps the record as of the first beat, not the
   last.

What this does NOT claim: a measured frame-time win as a gate; any change to
the save format, the load path (`game.gd:130-135`), `PIGEON_NO_PERSIST`
semantics (`game.gd:34-36`), the HUD or the game-over screen.

## Why

The hitch lands at the exact moment of the payoff, repeated for every hit in a
chain: once a run is past the record, every scored splat pays a synchronous
disk write on its frame — a 12-hit chain is 12 sync writes on 12 hit frames,
the worst place for a spike in a flight game. The planning lane measured
headless this session: 100 saves = 165.47 ms (1.655 ms/save), so a 12-hit
chain is ~3.3 ms of sync I/O spread across the chain's frames — 2–10% of a
16.6 ms frame per hit, spiky on busy disks (lane benchmark, not re-run for
this ticket — the mechanism is a code fact at `game.gd:145-148` regardless).
The save already runs inside input-driven physics frames, and the combo
escalations players chase are exactly the multi-beat case that pays it over
and over.

## Acceptance criteria

- [ ] New Gate 1b scenario `highscore_save_throttled` (slotted after
      `_scenario_high_score_persists`, `sim_test.gd:122`): redirect
      `Game.save_path` to `SIM_SAVE_PATH` (pattern at `sim_test.gd:48`,
      `sim_test.gd:1905`), remove the file, `reset_run()`, plant
      `Game.high_score = 100`, snapshot `Game._save_count`, fire 20
      `add_tourist_hit` calls → assert exactly ONE new save and the file reads
      the FIRST-beat score (200, not the final 2000); then emit
      `Game.hunger.game_over` (no listeners live in the T-009 block — Main
      instances only come later, `sim_test.gd:124-129`, and emitting sets
      nothing on Hunger itself, the latch is the clock's own, `hunger.gd:78-80`)
      → assert the file reads the final score (2000) and the total
      `_save_count` delta is exactly 2
- [ ] Crash-safety intent preserved at the first beat:
      `score_high_score_persists` stays green unchanged (it starts from
      `high_score = 0`, fires one hit and asserts the file exists immediately,
      `sim_test.gd:1904-1916`)
- [ ] Scoring math and the game-over flow unchanged:
      `score_combo_style_values`, `score_popup_floats_and_fades`,
      `pause_freezes_world`, `game_over_shows_score_screen`,
      `restart_resets_run` and `restart_same_seed_skips_rebuild` all stay
      green without edits
- [ ] Docstrings state the real contract, including the mid-chain-crash
      nuance (a crash keeps the record as of the first beat)
- [ ] No new @export tunables, no input actions, no scene changes;
      `PIGEON_NO_PERSIST=1` still produces zero writes (and `_save_count`
      stays flat)
- [ ] VERIFICATION.md Gate 1b table: new `highscore_save_throttled` row

## Verification

Gate 1 (import + boot, exit 0, zero ERROR lines) + Gate 1b (full suite
headless — `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`;
baseline on this tree measured 77 PASS / `SIM SUMMARY: 0 failure(s)`, the new
scenario makes it 78; explicitly re-run `score_high_score_persists`,
`score_combo_style_values`, `pause_freezes_world`,
`game_over_shows_score_screen`, `restart_resets_run`,
`restart_same_seed_skips_rebuild`) + Gate 2 + Gate 3.

**Pending human playtest (Gate 3):** one manual persistence pass — beat the
record in a real run, chain two or more further hits, Alt-F4, relaunch: the
record comes back as the first-beat value (the accepted nuance above), and a
normal game-over run still persists the final score.

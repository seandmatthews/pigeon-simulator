# T-073 — Take the high-score save off the scoring hot path (save once per run, flush at game over)

- **Milestone:** Sweep backlog · **Status:** done · **Category:** code-optimization · **Value (1-5):** 2 · **Risk (1-5):** 2
- **Depends on:** — (T-009 scoring/high score, T-005 hunger and T-010 game-over flow, whose surfaces it touches, are landed)
- **Refs:** sweep 1 planning lane (code quality & performance) · line numbers pinned to commit
  f77da93 when written; re-cited at HEAD ad02528 during the 2026-10-01 backlog audit
  re-check (T-101's boot-muted block grew `game.gd`, T-075 grew `hunger.gd`, and the
  harness scenarios migrated downward since). Criterion 1's first-beat values were
  corrected to 300/21,000 at 75e110e (2026-09-30) — the arithmetic below is that
  correction, re-verified against today's tree.

## What

`scripts/game.gd` only — no new exports, no input actions, no scene changes.
Today every record-beating hit performs a synchronous `ConfigFile.save` on the
hit frame: `_register_hit()` calls `_save_high_score()` unconditionally once
`score > high_score` (`game.gd:158-161`), and `_save_high_score()` is a
synchronous `cfg.save(save_path)` (`game.gd:179-184`, save at `:184`). The
change turns that per-hit write into a first-beat write plus a dirty-flag flush:

1. **First beat stays on the hot frame** — the crash-safety intent documented
   at `game.gd:58-59` ("written to save_path as soon as a run beats it, so a
   crash or an Alt-F4 still keeps the record") is preserved for the moment the
   OLD record first falls. Add `var _saved_this_run: bool = false`; on a beat,
   write immediately only when `not _saved_this_run`, then set it. Every
   further beat in the same run only sets `var _high_score_dirty: bool = true`.
   `reset_run()` (`game.gd:132-139`) clears both alongside `record_beaten` (it
   deliberately keeps `high_score`).
2. **`_flush_high_score()`** — if `_high_score_dirty`: `_save_high_score()`;
   then clear the flag.
3. **Game-over flush** — in `_ready()` (`game.gd:77-82`), connect
   `hunger.game_over.connect(_flush_high_score)`. Game owns its Hunger
   instance (`game.gd:79-81`), so every game over — Main's fail state
   (`main.gd:113` connects it, handler at `main.gd:398`) and headless
   harnesses alike — flushes; Main needs no change.
4. **Quit/teardown flush** — `_notification()` handles
   `NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_PREDELETE` with
   `_flush_high_score()` (the dirty guard makes both no-ops when clean; the
   predelete arm covers teardown paths that never deliver the window
   notification, such as Main's `get_tree().quit()` at `main.gd:444`).
5. **Test hook** — `var _save_count: int = 0`, incremented inside
   `_save_high_score()` past the `_persistence_enabled` guard, so it counts
   real disk writes and Gate 1b can assert on it.
6. **Docstrings** — `game.gd:58-59` (and the class header) are updated to the
   honest contract: the record is written the moment a run FIRST beats it
   (that write keeps a crash safe); further beats flush at game over or quit —
   so a crash mid-chain now keeps the record as of the first beat, not the
   last.

What this does NOT claim: a measured frame-time win as a gate; any change to
the save format, the load path (`game.gd:143-148`), `PIGEON_NO_PERSIST`
semantics (`game.gd:35-36`), the HUD or the game-over screen.

## Why

The hitch lands at the exact moment of the payoff, repeated for every hit in a
chain: once a run is past the record, every scored splat pays a synchronous
disk write on its frame — a 12-hit chain is 12 sync writes on 12 hit frames,
the worst place for a spike in a flight game. The planning lane measured
headless this session: 100 saves = 165.47 ms (1.655 ms/save), so a 12-hit
chain is ~3.3 ms of sync I/O spread across the chain's frames — 2–10% of a
16.6 ms frame per hit, spiky on busy disks (lane benchmark, not re-run for
this ticket — the mechanism is a code fact at `game.gd:158-161` regardless).
The save already runs inside input-driven physics frames, and the combo
escalations players chase are exactly the multi-beat case that pays it over
and over.

## Acceptance criteria

- [x] New Gate 1b scenario `highscore_save_throttled` (slotted directly after
      `_scenario_high_score_persists` — call slot `sim_test.gd:150`, before
      the T-019-window block that starts at `:157`): redirect
      `Game.save_path` to `SIM_SAVE_PATH` (whole-run pattern in `_ready`,
      `sim_test.gd:67`; per-scenario pattern in `_scenario_high_score_persists`,
      `sim_test.gd:3427-3439`), remove the file, `reset_run()`, plant
      `Game.high_score = 100`, snapshot `Game._save_count`, fire 20
      `add_tourist_hit` calls → assert exactly ONE new save and the file reads
      the FIRST-beat score (**300**, not the final 21,000); then emit
      `Game.hunger.game_over` — no listeners live in the scoring block: the
      only Main instanced earlier in the call order belongs to
      `_scenario_poop_ready_indicator_tracks_cooldown` (func
      `sim_test.gd:1531`, called at `:141`) and is freed before the block
      (`sim_test.gd:1621`, its hunger player detached at `:1622`; Main's own
      listener, `main.gd:113`, dies with the freed node), and the harness's
      only other `game_over` relay (`sim_test.gd:1226`) hangs off a local
      `Hunger.new()` freed at `:1243` — while emitting sets nothing on Hunger
      itself: the one-shot latch is the drain tick's, not the emit's
      (`hunger.gd:86-88`; `game_over_emitted` `:52-53`, cleared by `reset()`
      `:98-101`)
      → assert the file reads the final score (**21,000**) and the total
      `_save_count` delta is exactly 2.
      **Why 300/21,000 and not 200/2,000:** bare back-to-back
      `add_tourist_hit` calls escalate the combo — points are 100×1, 100×2, …,
      100×20 cumulative (`_register_hit`, `game.gd:151-163`: streak `:152`,
      points `:156`, score `:157`; `combo_multiplier()` `:95-98`;
      `combo_max` defaults to 0 = uncapped, `game.gd:22`), and no landing
      reset is staged. Bare calls never touch `on_poop_released`, so
      `_release_age` stays 999.0 (init `game.gd:74`, `reset_run()` `:138`) —
      past `style_release_window` 3.0 (`:28`), so `_is_style_hit()`
      (`:168-171`) pays plain and no style bonus contaminates the series.
      Hit 1 scores 100, not > the planted 100, so no beat and no save; hit 2
      makes score 300 > 100 — the FIRST beat, file = 300; hits 3–20 accumulate
      score to 100·(1+2+…+20) = 21,000, which the flush writes. The repo's own
      harness proves the escalation on consecutive bare hits
      (`_scenario_scoring_values`, `sim_test.gd:3375-3421`: p1 = 100 at
      `:3381`, p3 = 300 at `:3383`, and the final check holds score and high
      both 2,890 at `:3418`). The save-count arithmetic (one beat save, delta
      exactly 2 after the flush) is the same under either convention
- [x] Crash-safety intent preserved at the first beat:
      `score_high_score_persists` stays green unchanged (it plants
      `high_score = 0` at `sim_test.gd:3431`, fires ONE hit at `:3432` — which
      IS the first beat — and asserts the file exists immediately at `:3433`,
      then loads it back `:3436-3437`)
- [x] Scoring math and the game-over flow unchanged:
      `score_combo_style_values` (`sim_test.gd:3416`),
      `score_high_score_persists` (`:3438`),
      `score_popup_floats_and_fades` (`:3456`), `pause_freezes_world`
      (`:3485`), `game_over_shows_score_screen` (`:3556`),
      `restart_resets_run` (`:3593`) and `restart_same_seed_skips_rebuild`
      (`:3655`) all stay green without edits
- [x] Docstrings state the real contract, including the mid-chain-crash
      nuance (a crash keeps the record as of the first beat)
- [x] No new @export tunables, no input actions, no scene changes;
      `PIGEON_NO_PERSIST=1` still produces zero writes (and `_save_count`
      stays flat). Checked in its own targeted headless run, NOT inside the
      standard suite — the flag is read once at autoload load
      (`game.gd:36`), so a suite process that booted without it cannot assert
      this leg after the fact
- [x] VERIFICATION.md Gate 1b table: new `highscore_save_throttled` row

## Verification

Gate 1 (import + boot, exit 0, zero ERROR lines) + Gate 1b (full suite
headless — `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`;
the suite carries 110 `_check(` call sites on today's tree (`grep -c '_check("'
tests/sim_test.gd`, 2026-10-01) — a grep count, not a fresh pass count: the
suite was not re-run while re-citing this ticket, so the implementer's run must
end `SIM SUMMARY: 0 failure(s)`; the new scenario's check makes 111. Explicitly
re-run `score_high_score_persists`, `score_combo_style_values`,
`score_popup_floats_and_fades`, `pause_freezes_world`,
`game_over_shows_score_screen`, `restart_resets_run`,
`restart_same_seed_skips_rebuild`) + Gate 2 + Gate 3 (including the
`PIGEON_NO_PERSIST=1` leg's own targeted headless run, above).

**Pending human playtest (Gate 3):** one manual persistence pass — beat the
record in a real run, chain two or more further hits, Alt-F4, relaunch: the
record comes back as the first-beat value (the accepted nuance above), and a
normal game-over run still persists the final score.

## Implementation notes (2026-10-02, implementer run)

- Result (recorded values): a chain against a planted record of 100 pays
  exactly one hot-frame write at the FIRST beat (file = 300 after hit 2 of 20)
  and exactly one flush write at game over (file = 21,000) — `_save_count`
  delta exactly 2 across the whole chain. No @export values changed.
- Gate 1: import and 120-frame boot both exit 0 with zero project error lines
  (import's exit prints only the known-benign `addons/godot_mcp` tooling line
  documented in VERIFICATION.md's "Known issues"; the boot run is fully clean).
- Gate 1b: `SIM SUMMARY: 0 failure(s)`, exit 0, 110 `SIM PASS` lines vs 109 on
  the pristine base — exactly the one new scenario. All seven named regression
  scenarios re-ran green. (`grep -c '_check("'` is now 122 on this tree, not
  the ticket's pinned 110/111 — scenarios merged since ad02528; the gate is
  the summary line, which is 0.)
- `PIGEON_NO_PERSIST=1` targeted leg: a throwaway headless probe scene (run
  then deleted, not committed) reported `saves=0 file_exists=false` exit 0;
  the same probe WITHOUT the env var reported `saves=2 file_exists=true` —
  the assertion is not vacuous.
- Gate 2: `AUTOPLAY DONE ok=true … restart=true`, fps 137, no SCRIPT ERROR.

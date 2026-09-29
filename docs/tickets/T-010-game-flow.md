# T-010 — Game flow

- **Milestone:** M1 · **Priority:** P0 · **Size:** S · **Status:** done
- **Depends on:** T-005
- **Refs:** `docs/DESIGN.md` → Fail state (locked: game over on starvation)

## What

Ships-in-a-box around the core loop:

- Title screen: placeholder logo + "press Space to fly"
- Pause on Esc: resume / restart / quit; physics and audio pause correctly
- Game over on starvation: score screen (score, high score, tourist/car breakdown)
  → restart
- Scene flow `menu.tscn` ↔ `main.tscn`; restart regenerates with the same M1 seed
  so scores stay comparable

## Why

Without an ending there's no run, and without a run there's no "one more go".

## Acceptance criteria

- [x] Full loop works: boot → menu → play → starve → score screen → restart, no leaks/errors
- [x] Esc pauses and resumes; nothing keeps moving while paused
- [x] Restart resets score, hunger, city state and spawns
- [x] Score screen shows score, high score, and a tourists-vs-cars breakdown

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: die on purpose twice in a row; pause mid-flight
during both runs. *(Machine-verified via Gate 1b `pause_freezes_world`,
`game_over_shows_score_screen`, `restart_resets_run` and the autoplay restart
phase — `restart=true` in the DONE line; the die-twice/pause-mid-flight human
pass is recorded as pending in VERIFICATION.md → Known issues.)*

## Landed (implementation notes)

- **Title screen:** `scenes/menu.tscn` + `scripts/menu.gd` — placeholder logo,
  persisted high score line, "press Space to fly". Space (the `flap` action) or
  the Fly button starts the run; Esc/Q quits from the menu. `run/main_scene` now
  boots the menu; scene flow is `change_scene_to_file` both ways.
- **Pause:** `scripts/pause_menu.gd` (`PauseMenu`, CanvasLayer in
  `PROCESS_MODE_ALWAYS`) — Esc toggles `get_tree().paused`; resume / restart /
  menu / quit by key (Esc · R · M · Q) and by mouse button. Every pausable node
  stops: physics, the hunger clock, spawners, tweens, popups. (No audio exists
  yet — T-012 players will pause under the same tree pause.) `locked` refuses
  Esc once the run is over.
- **Game over:** `scripts/game_over_screen.gd` — opened by `Main._on_game_over`
  with score, high score, tourist/car breakdown and the fresh-record flag
  (`Game.tourist_hits` / `car_hits` / `record_beaten`, reset by
  `Game.reset_run()`); freezes the run; Space/R restarts, M returns to the menu.
- **Restart:** `Main.restart_run()` — deliberately in-place, not a scene reload:
  `Game.reset_run()` + `city.generate(city.seed_value)` (same M1 seed → identical
  fingerprint; bread/tourist/car spawners re-seed off `regenerated`) + pigeon
  reset onto the spawn corridor + `score_popups` / `poops` groups cleared. The
  identical path runs in the game, the sim harness and the autoplay pilot.
  `reset_flight` is fed `city.to_local(city.spawn_point)` so the scene spawns
  correctly wherever it is instanced.
- **New input actions:** `restart` (R), `to_menu` (M), `quit` (Q) — controls
  tables in README.md and VERIFICATION.md updated in the same change-set.
- **Verification:** three Gate 1b scenarios (`pause_freezes_world`,
  `game_over_shows_score_screen`, `restart_resets_run`) drive the real
  PauseMenu script and the real main.tscn (instanced far from the test world);
  the autoplay pilot (Gate 2) now starves on purpose at 30 s, verifies the score
  screen's labels, restarts and only then prints DONE (`restart` joins `ok`).

## Tuned values

No new gameplay tunables — this ticket is flow, not feel. The only numbers:
test-time starvation compression (`drain_per_second = 60.0` inside the sim
scenario; the live clock keeps T-005's 0.45/s default) and the autoplay restart
windows (`RESTART_TIMEOUT = 6.0` s for the screen to appear, `RESTART_PLAY_SECONDS
= 3.0` of post-restart cruise before DONE).

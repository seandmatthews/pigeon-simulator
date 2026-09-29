# T-014 — Multi-instance pilot harness

- **Milestone:** M1 tooling · **Priority:** P1 · **Size:** M · **Status:** done
- **Depends on:** — (builds on the CaptureRecorder autoload's pilot channel)
- **Refs:** AGENTS.md → "Agent play: pilot harness"; cozy-arcade slot/port work
  (concurrent editors) for the problem shape

## What

Let a fleet of agents play the game **at the same time**. Until now the pilot
channel was a single shared `.captures/` directory: two concurrent instances
would eat each other's `pilot_cmd_*` commands and collide on `run_*` folders.

- Session mode in `tests/capture_recorder.gd`: a game launched with
  `--pilot-session=<id>` (user arg after `--`, or `PIGEON_PILOT_SESSION` env)
  owns `.captures/session_<id>/` exclusively — state/events JSONL, frame PNGs
  and its own command channel. The window is re-titled `Pigeon pilot <id>`
  (the engine stamps its own title after autoload `_ready`, so the recorder
  re-stamps for the first ~10 s) so `window-shot.ps1` can grab one instance
  among many. A duplicate live claim is warned about and overwritten.
- `tests/tools/pilot.py` — stateless driver CLI: `start / send / state /
  events / wait / shot / stop / list / clean`. Refuses to start onto a live
  owner (pid + image-name check, so Windows pid reuse can't fake ownership),
  cascades window positions, warms `.godot/` imports before a fleet launch,
  and stops gracefully (`{"quit":true}`) with a `taskkill /T` fallback.
- `tests/tools/window-shot.ps1` — OS-level window capture by title pattern
  (adapted from cozy-arcade; bypasses any capture channel entirely).
- `scripts/game.gd` — high-score persistence is skipped when
  `PIGEON_NO_PERSIST=1` (pilot default), so N concurrent agents never fight
  over or wipe the real `user://highscore.cfg`.
- Legacy flag-file mode is unchanged (plus a `_p<pid>` run-dir suffix so two
  same-second launches can't share a folder, and no image timer when headless
  — the dummy renderer's null texture used to spam `Parameter "t" is null`).

## Why

The next milestone work is a multi-agent push: several tickets in parallel,
each agent playing the game while it tunes. The godot-mcp editor path is
single-bridge and wedges after game events; the standalone pilot path is
file-based and scales with disk, not ports.

## Acceptance criteria

- [x] Two sessions launched concurrently reach the menu, start runs with
      Space and stream state/frames into separate `session_*` dirs
- [x] A flap command sent to one session never appears in the other's event
      stream (input isolation)
- [x] `start` refuses a session id owned by a live instance
- [x] `stop` quits both sessions gracefully; `clean` removes dead dirs
- [x] OS-level `shot` captures the right one of two windows by session id
- [x] Gates 1/1b stay green with the session code in place (0 boot errors,
      63/63 SIM PASS, exit 0)

## Defaults worth knowing

- Sessions boot `res://scenes/menu.tscn`, muted (`--sound` to unmute),
  persistence off (`--persist` to allow), images every 0.2 s (`--images
  off|N`) — ~10–20 MB/s of PNGs per session, so `clean` when reviewed.
- `shot`'s default output lands inside the session dir; `clean` deletes
  session dirs, so pass `--out` for shots you want to keep.
- No ports anywhere — concurrency is bounded by CPU/GPU only (~130 fps each
  at T-013 density on the dev box, so 3–5 concurrent sessions are safe).

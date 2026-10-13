# AGENTS.md

Guidance for AI agents (and humans) working in this repo. Read this before making
changes, and follow [`VERIFICATION.md`](VERIFICATION.md) before calling any change done.

## What this project is

**Pigeon Simulator** — a third-person 3D flight game in Godot. You are a pigeon in a
city: eat bread to survive, and earn points by pooping on tourists and their cars.
Design rationale lives in [`docs/DESIGN.md`](docs/DESIGN.md); work is tracked in
[`docs/tickets/`](docs/tickets/README.md).

## Stack & tooling

- **Engine:** Godot 4.7, standard build (no .NET). Language is GDScript 2.0 — no C#, no GDExtension.
- **Editor binary:** `~/bin/Godot_v4.7.2-stable_win64.exe` (the `_console.exe` variant is
  better for terminal/headless runs). Not on PATH by default.
- **Version control:** git. Never commit `.godot/`. Do commit the `*.import` and `*.uid`
  files Godot generates next to assets and scripts.
- **Addons/plugins:** don't add any without agreeing with the user first.

## Layout

```
project.godot   engine config: input actions, physics layer names, main scene
scenes/         .tscn files, snake_case, one gameplay entity per scene
scripts/        .gd files, snake_case
tests/          headless sim harness (VERIFICATION.md Gate 1b)
assets/         art / audio / fonts; third-party credits in assets/CREDITS.md
docs/           DESIGN.md and tickets/
```

## Conventions

### GDScript
- **Tabs** for indentation. snake_case for files, functions and variables; PascalCase
  for node names inside scenes.
- Static typing wherever the language allows (`var speed: float`, `-> void`, typed signals).
- Use `##` docstrings on scripts and non-obvious functions.
- Node access: `@onready var label := %StatsLabel` with "unique name in owner" set on the
  target node. Avoid `get_node("A/B/C")` chains into other nodes' subtrees.
- Prefer composition (child nodes + signals) over deep inheritance.
- Game-wide state (score, hunger, settings) belongs in autoload singletons under
  `scripts/` — add one only when a ticket calls for it; don't stash globals on `Main`.

### Input
- All input actions are declared in `project.godot` under `[input]` and referenced by
  name only (`Input.is_action_pressed("flap")`). Never use raw keycodes in scripts.
- Current actions: `flap` (Space), `poop` (F), `pitch_up`/`pitch_down` (W/S),
  `turn_left`/`turn_right` (A/D), `boost` (Shift), `pause` (Esc).
- Adding or changing an action requires updating the controls tables in `README.md`
  and `VERIFICATION.md` in the same change.

### Physics
- Use the named collision layers from `project.godot` and set **layer and mask**
  deliberately on every physics body:
  1 `world` · 2 `player` · 3 `npc` · 4 `vehicle` · 5 `pickup` · 6 `projectile`

### Scenes
- New entity → new scene + its script (`scenes/tourist.tscn` + `scripts/tourist.gd`).
- Keep `.tscn` files hand-editable: translation-only transforms are fine in the file;
  do rotations in `_ready()`/scripts (the Sun in `main.gd` shows the pattern) so
  scene files stay free of hand-computed basis matrices.

## Agent play: godot-mcp (eyes-on verification)

An MCP server lets agents launch the game, inject input, and capture screenshots.
Wiring lives in `.zcode/config.json` (`godot` → `http://127.0.0.1:9090/mcp`), the
editor-side pieces in `addons/godot_mcp/` (editor plugin + the `MCPRuntimeProbe`
autoload — the probe no-ops outside debug sessions, leave both in place).

- **Shared server first.** The server is shared with the cozy-carnival suite and
  lives in that sibling checkout — this repo deliberately names no foreign path
  (the suite was renamed once already). If port 9090 isn't answering, start it
  before opening the editor:
  `cmd //c .zcode/tools/serve-godot-mcp.cmd` (run it in the background; it
  resolves the suite — `GODOT_MCP_REPO` env var or sibling probe — and keeps the
  suite's identity-checked shared server. If the suite's packaged launcher dies
  silently, as it does as of 2026-10-12, the wrapper falls back to a direct
  `python -m` start that the suite's port checker still classifies as OURS).
  Idempotent. Editor bridge: `ws://127.0.0.1:9080`.
- **One editor per bridge.** Open this project's editor
  (`~/bin/Godot_v4.7.2-stable_win64.exe --path . --editor`) and preflight with
  `godot_get_server_info` before any runtime tool — if `bridge_connected` is false,
  the tool is talking to nobody (or another project).
- **A fresh MCP session has only core+inspection.** Enable what the session needs
  once: `godot_enable_toolset` with category `runtime`, `input`, `testing` (and
  `editor` for editor screenshots).
- **Play loop:** `godot_runtime_play_scene` (e.g. `res://scenes/menu.tscn`) →
  `godot_runtime_capture_game_screenshot` → input → screenshot → … →
  `godot_runtime_stop_scene`.
- **Input must be press+release pairs.** A lone `pressed=true` may never complete
  (the focused button waits for release). Use `godot_input_play_sequence` with a
  down event and an up event ~120 ms apart; confirm delivery via
  `godot_input_get_stats` (`injected` count). This is how the title screen's Space
  shortcut was proven to start a run.
- **Gameplay input is action events, not raw keys.** The movement bindings use
  *physical* keycodes, which synthesized `{"type":"key"}` events don't carry —
  a raw W press moves nothing. Use `{"type":"action","action":"pitch_up"}`-style
  events for in-game driving; raw keys only reach menus (Space works either way).
- **Known defects (2026-09-17, from the cozy-carnival suite):** screenshots can wedge
  after game events — capture first, and restart the play session if one times out;
  `monitor_property` sampling pauses the SceneTree and drops injected input — arm it
  while idle and never interleave with input. Bridge acting up: run
  `../cozy-carnival/tools/port-doctor.cmd`; ports are identity-checked, a SQUAT is a
  foreign process, not our server.
- **More defects (2026-10-12 session, 3 runs / 120 injected events):** any capture
  wedges while the SceneTree is *paused* — the game-over screen pauses the tree
  (`game_over_screen.gd`), so death screenshots time out every time. Grab the
  window at the OS level instead:
  `powershell -File ../cozy-carnival/tools/window-shot.ps1 "Pigeon Simulator (DEBUG)" out.png`.
  After the menu→main scene swap, `godot_runtime_get_game_scene_tree` and
  `is_playing`'s scene field can serve stale data (they kept reporting
  `menu.tscn` mid-run) — trust screenshots over them.

Without the bridge (headless CI), `tests/` Gate 1b still works — the MCP path is
for the eyes-on human-judgement gate (feel, look, sound).

## Agent play: pilot harness (standalone, multi-instance)

For gameplay verification — and always when more than one agent needs to play at
the same time — use the standalone pilot harness instead of the editor bridge
(editor play sessions freeze during real gameplay, and the bridge is one-editor-
only). Sessions are isolated by id, need no ports, and scale with CPU/GPU only:

```bash
python tests/tools/pilot.py start --session <your-unique-id>   # boots menu.tscn
python tests/tools/pilot.py wait  --session <id> --scene Menu  # Menu → Main after Space
python tests/tools/pilot.py send  --session <id> '{"key":"Space","frames":2}'
python tests/tools/pilot.py send  --session <id> '{"action":"flap","frames":7}'
python tests/tools/pilot.py state --session <id>               # last world-state JSONL line
python tests/tools/pilot.py events --session <id> --tail 20    # what happened
python tests/tools/pilot.py shot  --session <id>               # OS grab of that window
python tests/tools/pilot.py stop  --session <id>               # graceful quit
python tests/tools/pilot.py list / clean                       # fleet overview / sweep dead dirs
```

- **One session id per agent, unique while you live.** Your channel is
  `.captures/session_<id>/` (state/events JSONL + frame PNGs + the command
  queue); nobody else's commands can reach your instance. `start` refuses an id
  owned by a live process — pick a fresh one rather than reusing.
- **Session defaults are safe for fleets:** muted audio, high-score persistence
  OFF (`--sound` / `--persist` to opt in), frame PNGs every 0.2 s (`--images
  off|N`; they run 10–20 MB/s per session, so `clean` once reviewed). The title
  screen to run transition is `{"key":"Space"}` — real key events reach menus,
  action commands (`flap`, `poop`, …) only reach gameplay.
- **Command files are consumed-and-deleted** by the game oldest-first; queue
  several in one file by passing multiple JSON lines. `state`'s `scene` field
  drives `wait` (`Menu`, `Main`).
- **`shot` vs frame PNGs:** `shot` grabs the OS window by its
  `Pigeon pilot <id>` title (works even with `--images off`); the frame stream
  is the in-process viewport. Review with `tests/review/summarize.py
  .captures/session_<id>` and `contact_sheet.py` — both take the session dir.
- Launch only through `pilot.py` (it warms `.godot/` imports before a fleet and
  owns the liveness checks); `stop` when done so the desktop doesn't fill with
  pigeons.

## Ticket workflow

- Backlog: `docs/tickets/` — index in `docs/tickets/README.md`, one file per ticket,
  IDs like `T-004`.
- Statuses: `todo` → `doing` → `done` (or `blocked`, with a note in the file). Update
  the status in both the ticket file and the index table.
- One ticket per change-set; reference the ID in commit messages,
  e.g. `feat(flight): stall behavior (T-001)`.
- A ticket is **done** when: all acceptance criteria are checked off, the
  [`VERIFICATION.md`](VERIFICATION.md) gates pass, and the ticket's status/checkboxes
  are updated in the same commit.

### The ticket loop

Work one ticket at a time, in the build order from the backlog index:

1. Flip the ticket to `doing` in its file and the index table.
2. Implement it (conventions above).
3. **Extend `VERIFICATION.md` in the same change-set.** Every feature, input or
   mechanic that lands gets a matching verification entry: an automated scenario in
   the sim harness (`tests/`, Gate 1b) where one is possible, otherwise a Gate 3
   playtest line. Never ship a feature without a way to re-verify it later.
4. Run the gates from `VERIFICATION.md` and fix until green. Machine-verified
   acceptance criteria get checked off; anything needing human judgement (feel,
   look, sound) is recorded in the ticket as a pending human playtest note.
5. Record tuned values in the ticket, flip it to `done`, commit (one commit per
   ticket, ID in the message) — then pick the next ticket.

## Commit style

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`) with the ticket ID in
parentheses. Small, focused commits; never mix a gameplay change with .godot cache junk.

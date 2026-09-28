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

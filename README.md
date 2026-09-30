# Pigeon Simulator 🐦

A third-person pigeon flight sim built with Godot 4. Wander the city, eat bread to
survive, and earn points by pooping on tourists and their cars.

> **Status:** pre-alpha scaffold. A gray placeholder pigeon flies over a procedural
> gray-box city, lands on roofs, sidewalks and the spawn plaza, waddles around,
> runs on a hunger clock fed by breadcrumbs — land and walk into a crumb to eat —
> and lobs poop splats over the city with **F** while flying, past the tourists
> strolling the sidewalks (a direct hit triggers a panic) and the cars parked at
> the curbs and looping the blocks (a direct hit earns a honk). Every splat
> scores: tourists 100, cars 30, consecutive hits without landing multiply
> (×1 → ×2 → ×3…), fast low dive hits pay +50%, and the high score persists
> between runs. The game boots to a title screen (Space to fly), pauses on Esc,
> and starvation ends the run on a score screen — restart regenerates the same
> city so scores stay comparable.
> The roadmap lives in [`docs/tickets/`](docs/tickets/README.md).

## Run it

1. Get Godot 4.7 (the exact binary used for this project: `~/bin/Godot_v4.7.2-stable_win64.exe`).
2. Open this folder as a project in Godot, or run `godot --path .` from a terminal.
3. Press **F5**.

**Sound:** the game boots muted (T-101). To hear it, opt in explicitly — run
`godot --path . -- --sound` (note the `--`), set `PIGEON_SOUND=1`, or launch the pilot
harness with `--sound`. In the editor, put `--sound` in Debug → Customize Run Instances →
Main Run Args.

## Controls

| Input | Action |
| ----- | ------ |
| W / S | pitch up / down · waddle fwd / back while grounded |
| A / D | turn left / right · turn while waddling |
| Space | flap · takes off when grounded · starts a run from the title screen · fly again on the score screen |
| F | poop — lobs a splat dropping while airborne · a direct hit panics a tourist · honks a car (30 pts) |
| Shift | boost *(not implemented yet)* |
| Esc | pause — everything freezes; Esc again resumes |
| R | restart the run — from the pause menu or the score screen |
| M | back to the title screen — from the pause menu or the score screen |
| Q | quit the game — from the pause menu or the title screen |

## Docs

- [`AGENTS.md`](AGENTS.md) — conventions for working in this repo (read this first)
- [`VERIFICATION.md`](VERIFICATION.md) — the test gates every change must pass
- [`docs/DESIGN.md`](docs/DESIGN.md) — the game design
- [`docs/tickets/`](docs/tickets/README.md) — backlog and ticket workflow

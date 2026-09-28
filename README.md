# Pigeon Simulator 🐦

A third-person pigeon flight sim built with Godot 4. Wander the city, eat bread to
survive, and earn points by pooping on tourists and their cars.

> **Status:** pre-alpha scaffold. A gray placeholder pigeon flies over a procedural
> gray-box city, lands on roofs, sidewalks and the spawn plaza, waddles around, and
> runs on a hunger clock fed by breadcrumbs — land and walk into a crumb to eat.
> The roadmap lives in [`docs/tickets/`](docs/tickets/README.md).

## Run it

1. Get Godot 4.7 (the exact binary used for this project: `~/bin/Godot_v4.7.2-stable_win64.exe`).
2. Open this folder as a project in Godot, or run `godot --path .` from a terminal.
3. Press **F5**.

## Controls

| Input | Action |
| ----- | ------ |
| W / S | pitch up / down · waddle fwd / back while grounded |
| A / D | turn left / right · turn while waddling |
| Space | flap · takes off when grounded |
| F | poop *(not implemented yet)* |
| Shift | boost *(not implemented yet)* |
| Esc | pause *(not implemented yet)* |

## Docs

- [`AGENTS.md`](AGENTS.md) — conventions for working in this repo (read this first)
- [`VERIFICATION.md`](VERIFICATION.md) — the test gates every change must pass
- [`docs/DESIGN.md`](docs/DESIGN.md) — the game design
- [`docs/tickets/`](docs/tickets/README.md) — backlog and ticket workflow

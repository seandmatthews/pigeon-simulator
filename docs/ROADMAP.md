# Pigeon Simulator — Roadmap

Phase-level plan: what phase the project is in, what that phase is for, and what
comes after. This is the repo-visible source of truth for the schedule and phase
goals. Refreshed 2026-10-13 — the previous version (git history, 8f6f4d8) was
frozen at the 2026-10-01 "mayhem-first" steer and still showed M2 as proposed;
everything since then shipped.

## Phase overview

| Phase | Goal | Exit criteria | Status |
| ----- | ---- | -------------- | ------ |
| M1 — vertical slice | One stretch of city where the whole loop works and feels good | T-001..T-020 done, gates green | done 2026-09-29 |
| Sweep — readability, feel, perf (waves W1–W8) | Make the slice legible and pleasant: the bird readable against the city, every scored moment visible, flight well-behaved at its edges, boot scene affordable | Every W1–W8 ticket merged or flagged; backlog re-audited | done 2026-10-01 — chain complete, every wave ticket landed (record below) |
| M2 — the town's pigeon | Goal layer: the invasion gets a uniform and the sandbox gets a win — citizen classes, the favor economy, the favor-max victory, and the HUD that names the prize | All four forks decided (2026-10-11); the forged sequence landed with gates green | done 2026-10-11/12 — T-113 96d09fe, T-114 6b51dc4, T-115 112f8e9, T-116 bfe31fb |
| M3 — next | open | open | open — no direction chosen yet |

## Where we are (2026-10-13)

The tracker is empty: T-001..T-116 are all done or superseded. Open
human-judgement lines: T-115's and T-116's Gate 3 passes only
([VERIFICATION.md](../VERIFICATION.md) → Gate 3; the rest of the ledger was
bulk-closed by the owner 2026-10-13).

Parked candidates from the M2 sketch, none committed to: the hawk hazard,
seagull rivals at the tailgates, districts (campus / main-street / tailgate
palettes), landmark bonus targets, gamepad support, settings, export builds.
New work starts as a tone-checked pitch before anything is forged (AGENTS.md —
the idea-talk convention); scope stays a silly game about a bird pooping on
people.

## The sweep's wave schedule (historical record)

How the sweep actually ran, 2026-09-30 → 2026-10-02. Grouping rules (kept for
any future multi-ticket wave): at most one `city.gd` ticket and one `player.gd`
ticket per wave; T-087 and T-095 never share a wave (both emit at the off-world
guard branch); T-048 lands before T-078 (both touch elder machinery); T-088
lands as two commits (rim + skyline, per its mandate); max 3 concurrent runs —
the CPU-budget Gate 1b scenario false-fails under heavier fleet load.
Per-ticket merge commits live in the ticket files.

| Wave | Tickets | Status |
| ---- | ------- | ------ |
| W1 | T-074, T-097, T-069 | done (merged 7509620 / 26fcbf5 / fbab8ff) |
| W2 | T-044, T-085 | done (merged c1fe4bd / 50f8487) |
| W3 | T-088, T-040, T-043 | done (merged 193c0af / e3fb3e5 / 8ed9a89) |
| W4 | T-102, T-083, T-055 | done |
| W5 | T-030, T-057, T-048 | done |
| W6 | T-049, T-075, T-095 | done |
| W7 | T-051, T-078, T-099 | done |
| W8 | T-093, T-079, T-087 | done (T-079's merge conflict hand-resolved as 3fdb102) |
| W9 | T-081, T-039 | both done outside the original wave window (T-039 04af1f9; T-081 — see its ticket) |

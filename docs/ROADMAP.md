# Pigeon Simulator — Roadmap

Phase-level plan: what phase the project is in, what that phase is for, and what
comes after. This is the repo-visible source of truth for the schedule and phase
goals; the orchestrator's live execution state (in-flight run ids, per-wave
status flips) stays outside the repo and defers to this file's schedule.

Added 2026-10-01, closing the main gap from that date's docs review: the wave
schedule had been living only in a gitignored file, so a fresh clone could not
answer "what are we building right now, and in what order."

## Phase overview

| Phase | Goal | Exit criteria | Status (2026-10-01) |
| ----- | ---- | -------------- | ------------------- |
| M1 — vertical slice | One stretch of city where the whole loop works and feels good | T-001..T-020 done, gates green | done 2026-09-29 |
| Sweep — readability, feel, perf (waves W1–W8) | Make the slice legible and pleasant: the bird readable against the city, every scored moment visible, flight well-behaved at its edges, boot scene affordable | Every W1–W8 ticket merged or flagged; backlog re-audited against the new tree | in progress — W4 of W8 |
| W9 overflow | T-081 (gated on a T-082 rewrite) and T-039 | — | not authorized — plan stops after W8 |
| M2 — the town's pigeon | Goal layer: befriend the locals, drive off the rowdy visitors (DESIGN.md → Milestone 2) | Open forks decided; M2 tickets forged and run | proposed 2026-10-01, deferred by user steer — mayhem-first for now |

## Wave schedule (sweep phase)

| Wave | Tickets | Status |
| ---- | ------- | ------ |
| W1 | T-074, T-097, T-069 | done (merged 7509620 / 26fcbf5 / fbab8ff) |
| W2 | T-044, T-085 | done (merged c1fe4bd / 50f8487) |
| W3 | T-088, T-040, T-043 | done (merged 193c0af / e3fb3e5 / 8ed9a89) |
| W4 | T-102, T-083, T-055 | in flight |
| W5 | T-030, T-057, T-048 | pending W4 |
| W6 | T-049, T-075, T-095 | pending W5 |
| W7 | T-051, T-078, T-099 | pending W6 |
| W8 | T-093, T-079, T-087 | pending W7 |
| W9 | T-081, T-039 | not authorized |

Grouping rules (why these lanes): at most one `city.gd` ticket and one
`player.gd` ticket per wave; T-087 and T-095 never share a wave (both emit at
the off-world guard branch); T-048 lands before T-078 (both touch elder
machinery); T-088 lands as two commits (rim + skyline, per its mandate). Max
3 concurrent runs — the CPU-budget Gate 1b scenario false-fails under heavier
fleet load.

## M2 — the town's pigeon (proposed)

The next milestone gives the sandbox a purpose: the locals know you, the
visitors don't. Befriend the park elders; ruin the visiting fans' Saturday.
Full direction and the four open forks: [`DESIGN.md`](DESIGN.md) →
"Milestone 2". No M2 tickets exist yet — do not pull M2 work into sweep waves.

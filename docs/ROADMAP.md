# Pigeon Simulator — Roadmap

Phase-level plan: what phase the project is in, what that phase is for, and what
comes after. This is the repo-visible source of truth for the schedule and phase
goals. Refreshed 2026-10-23 — the previous version (git history, 2fa404b)
still showed the 2026-10-20 state; T-131–T-133 have shipped and T-134 has been
proposed since.

## Phase overview

| Phase | Goal | Exit criteria | Status |
| ----- | ---- | -------------- | ------ |
| M1 — vertical slice | One stretch of city where the whole loop works and feels good | T-001..T-020 done, gates green | done 2026-09-29 |
| Sweep — readability, feel, perf (waves W1–W8) | Make the slice legible and pleasant: the bird readable against the city, every scored moment visible, flight well-behaved at its edges, boot scene affordable | Every W1–W8 ticket merged or flagged; backlog re-audited | done 2026-10-01 — chain complete, every wave ticket landed (record below) |
| M2 — the town's pigeon | Goal layer: the invasion gets a uniform and the sandbox gets a win — citizen classes, the favor economy, the favor-max victory, and the HUD that names the prize | All four forks decided (2026-10-11); the forged sequence landed with gates green | done 2026-10-11/12 — T-113 96d09fe, T-114 6b51dc4, T-115 112f8e9, T-116 bfe31fb |
| M3 — improvement waves | Owner-directed batches from the 2026-10-15/17 brainstorm ([IDEAS.md](IDEAS.md)): wave 1 = target-car readability, settings v1, the sound pass, the human/car model swap, the boot splash, the web quit gate (T-121..T-126); wave 2 = the Xbox controller, the off-screen traffic spawn gate, and the web boot that paints (T-127..T-129); follow-ups = the bigger Fly button + real poop distance (T-130), the single web warming screen (T-131), the pilot slow-mo flag (T-132), the slower-bird feel pass (T-133) | every wave's tickets done with gates green, owner Gate 3 passes recorded | waves 1–2 done 2026-10-18/19 · T-130/T-131 done 2026-10-20 · T-132/T-133 done 2026-10-22 (hosted build current with T-133, 2cf865c) · T-134 (four-way stops) proposed 2026-10-23 · owner Gate 3 passes pending per ticket |

## Where we are (2026-10-23)

M3 waves 1 and 2 are done: T-121..T-126 (target-car readability, settings v1,
the sound pass, the human/car model swap, the boot-splash swap, the web quit
gate) landed 2026-10-17/18, and T-127..T-129 (the Xbox controller, the
off-screen traffic spawn gate, the web boot that paints) landed 2026-10-18/19.
The follow-ups since: T-130 (bigger Fly button + real poop distance) and
T-131 (one warming screen on the web handoff) on 2026-10-20; T-132 (pilot
`--time-scale` slow-mo) and T-133 (slower bird — the speed quartet ×0.8) on
2026-10-22. The hosted build at games.matthews.mx is current with T-133.
Still open: T-120 (readable touch buttons) and T-134 (American four-way
stops, proposed 2026-10-23 out of the traffic-laws forge — cars get
multi-block routes, right-of-way, blinker tells and stop signs), owner Gate 3
playtest passes for the landed tickets, and the
GitHub Actions deploy button's repo secrets (deploys stay manual until those
land).

Everything else from the brainstorm stays pitched in
[IDEAS.md](IDEAS.md) behind its open decision-log forks: updrafts (B-5),
perch (B-9), the difficulty/points rebalance (B-6/B-7), quests-lite (B-15),
the pigeon-look pass (B-1), buildings/props
swap (B-2 phase 2), the hawk hazard and seagull rivals (still on DESIGN's
out-of-scope list — re-opening is an explicit owner call), districts,
landmark targets, and export builds. New work starts as a tone-checked pitch
before anything is forged (AGENTS.md — the idea-talk convention); scope stays
a silly game about a bird pooping on people.

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

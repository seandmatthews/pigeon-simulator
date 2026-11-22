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
| M3 — improvement waves | Owner-directed batches from the 2026-10-15/17 brainstorm ([IDEAS.md](IDEAS.md)): waves 1–2 (T-121..T-129), follow-ups (T-130..T-133), the traffic-laws batch (T-134..T-137), the people-rig marathon (T-138..T-146), the complaint batch (T-162..T-166), the dev-tool trio (T-167..T-169), hidden pilot windows (T-170) | every wave's tickets done with gates green | done through 2026-11-07 (the 2026-11-05 owner batch landed all nine) · owner Gate 3 passes deferred and recorded |
| M4 — the Ames campaign | The city becomes **real Ames, Iowa** at true scale: the ring campaign over the research survey ([references/ames-survey/INDEX.md](references/ames-survey/INDEX.md), master plan [AMES-MASTERPLAN.md](AMES-MASTERPLAN.md)) — R1 the map (data pack, bake, renderer, cutover), R2 the life (traffic, pedestrians, parking, economy), R3 the landmarks (11 heroes + the fidelity walk), R4 the names (venue signs, ghost plaques, blades, plaques, credits), R5 the town (bbox extensions, filler dressing, canopy, tailgates, perf) — 40+ tickets, every one pipeline-implemented, gate-checked and reviewer-played | all ring tickets merged with the entry-hardware bar machine-checked (the gate box's 30 fps floor) | **done 2026-11-22** — T-171..T-215 + T-213/T-216 merged on `ames/campaign`; the grand tour (T-210) merged 78c12ab · owner victory-lap flights deferred and recorded |
| Open follow-ups | T-216 (cross-platform autoplay determinism — the citizens diverge by platform; proposed by the perf climb), the web-fork decision (T-209's measured one-pager — the hosting is live with a testing door at `/pigeon-simulator/testing`), R6 owner-pick options (master plan §9: day/night bar lighting, traditions easter eggs, VEISHEA remembrance, flight feel, ending relocation) | owner picks | awaiting owner steer |

## Where we are (2026-11-22)

**The M4 Ames campaign is complete.** Since 2026-11-08 the game's city was
rebuilt as real Ames, Iowa — the ring campaign above: the map cut over at the
true-scale core (R1), the town came alive on the real grid (R2), the
landmarks landed at verified dimensions with the fidelity walk against the
survey's reference photos (R3), the town got its names — venue signs, the
mourned venues' ghost plaques, street blades, campus plaques, the credits
screen (R4) — and the edges/extensions, filler dressing, 5,637-tree canopy,
tailgates, and the entry-hardware performance re-derive (R5). The perf fix
was proven on the campaign's own canary: the Ubuntu gate box (a 2015
i7-6700 + HD 530) runs the merged world at 31 fps against the 30 fps floor
the campaign machine-checked into `tools/gate-box.sh`. The whole branch is
on `ames/campaign` (pushed to origin; the hosted testing door serves it at
`/pigeon-simulator/testing`).

Still open: the owner's victory-lap flights (deferred Gate 3 passes for
R1's flyover, R2's favor run, R3's postcard, R4's fly-to-your-bar — closable
by playing the shipped world), T-216 (cross-platform autoplay determinism),
the web-fork call, and R6's owner-pick options.

Everything else from the brainstorm stays pitched in
[IDEAS.md](IDEAS.md) behind its open decision-log forks. New work starts as a
tone-checked pitch before anything is forged (AGENTS.md — the idea-talk
convention); scope stays a silly game about a bird pooping on people.

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

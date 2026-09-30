# T-039 — Teach the controls on the title screen

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** — (T-010 menu flow, done)
- **Refs:** UI/UX lane playtest, sweep 1 (2026-09-29); T-019 (title background finding)

## What

Two data-only Label edits — no script logic, no input changes:

- **`scenes/menu.tscn`** — one new full-width Label under the Footer
  (`scenes/menu.tscn:67-78`; anchors preset 12, e.g. `offset_top -26`,
  `offset_bottom -4`): the controls block
  `"W/S pitch · A/D turn · Space flap · F poop · Esc pause"`, 15 px,
  `Color(1, 1, 1, 0.7)`, no outline — T-019 established the flat dark-navy
  background (`Color(0.16, 0.22, 0.33, 1)`, `menu.tscn:17`) needs no outline
  (T-019 ticket, "Title screen considered and NOT changed"). The keycaps are
  the exact `HINT_AIR` set (`scripts/main.gd:11`) plus Esc pause, which the
  title must teach and the in-flight hints never show. Scene files cannot
  reference script constants, so the copy is duplicated from `main.gd:11` by
  design — the Gate 1b scenario below is the divergence guard (it cross-checks
  every named action against the project InputMap).
- **`scenes/main.tscn`** — the game-over Hint text (`scenes/main.tscn:214-218`)
  reworded from dev jargon into player language:
  `"same city every run — race your best"` (replaces "the city regenerates
  with the same seed — scores stay comparable").

No input action is added or changed, so the README and VERIFICATION control
tables are untouched. Does **not** claim: no `menu.gd` change, no flow change,
no new scenes, nothing beyond the two Label edits.

## Why

The title screen states the goal but zero keys: everything in
`scenes/menu.tscn:19-77` — Title, Subtitle "press Space to fly",
HighScoreLabel, FlyButton, Footer — names no control beyond Space. A new
player's first instruction is the 14 px hint line (`scenes/main.tscn:88-98`)
that appears only once the run has started, mid-air over a road, with
pitch/turn/flap/poop already live (the hint swaps on grounding,
`scripts/main.gd:216-217`). The UI/UX lane's first two sessions flew off the
city twice without steering back. The game-over footer's "regenerates with the
same seed" is dev jargon — visible in the lane's `session_uiuxs1d` window
grab of the score screen.

## Acceptance criteria

- [ ] The title screen shows a controls line naming every action family a
      first run needs — pitch, turn, flap, poop, pause — and each family
      resolves to a real action in the project InputMap (`flap`, `poop`,
      `pitch_up`/`pitch_down`, `turn_left`/`turn_right`, `pause`, all present
      at `project.godot:37-72`) — Gate 1b only
- [ ] The controls line is 15 px white @ 0.7 with no outline, positioned under
      the footer, legible on the dark navy — [screenshot]
- [ ] The game-over footer reads "same city every run — race your best" and
      contains neither "seed" nor "regenerate" (Gate 1b for the text; tone is
      Gate 3) — [screenshot]
- [ ] The diff touches only the two .tscn Label blocks: `project.godot`
      `[input]`, README and VERIFICATION control tables unchanged
- [ ] Title → run flow unchanged: Space still starts a run from the title
      (the existing T-010 Gate 3 line keeps passing)

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b — new scenario
`title_screen_teaches_controls`: instance `scenes/menu.tscn` headless
(`menu.gd`'s `_ready` is headless-safe — it only sets the high-score label
text and grabs button focus, `scripts/menu.gd:12-17`), assert the controls
label exists and is visible, its text names pitch/turn/flap/poop/pause, and
`InputMap.has_action` holds for all seven actions the keycaps map to; free the
instance. Assert the reworded game-over Hint by reading the label through an
instanced `main.tscn` (no existing scenario asserts that label —
`_scenario_game_over_screen` checks only score/high/breakdown labels,
`tests/sim_test.gd:1797-1801`). Registration is unconstrained (the menu
instance touches no Main state and frees itself) — any unpaused point after
the T-019 window works. Full suite green. Gate 2 unaffected: the autoplay
boots `main.tscn` directly and never visits the menu (`VERIFICATION.md:115-118`).
Gate 3: [screenshot] pass over both screens — the controls read at a glance
on the title, and the footer reads as an invitation rather than a commit
message.

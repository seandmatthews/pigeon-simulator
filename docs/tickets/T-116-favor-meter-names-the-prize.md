# T-116 — The meter names the prize: the favor row shows the ceiling and the HUD states the win

- **Milestone:** M2 — the town's pigeon (discoverability patch) · **Status:** done · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** T-114 (the `%FavorLabel` meter and its rest/delta text forms), T-115 (`Game.favor_max`, the victory ending it names) — all done
- **Refs:** owner playtest note (2026-10-12): "The player needs to know how much favor they have and what the win condition is." · tone guardrail — the win read stays "the town is yours" warmth, comedic not triumphalist · `docs/DESIGN.md` → Milestone 2

## What

The goal layer landed (T-113 → T-115) but never announced itself. The owner played the
post-T-115 build and hit the gap: the HUD's favor row shows a bare signed balance —
`Favor: 0` (`scripts/main.gd:552-555`) — with no ceiling, so "how much favor do I have"
has no context and "how much is there to get" has none at all; and the win rule —
**max the elders' favor to take the town** — appears nowhere in the game until the
moment you win (`game_over_screen.gd`'s victory register). The menu footer, the game's
de-facto rules line ("eat bread to survive · splat tourists (100) and cars (30) · don't
starve · Q quit", `scenes/menu.tscn:77`), doesn't mention favor either.

Three touchpoints, all presentation-only — the favor book (`scripts/game.gd`) is untouched:

1. **The meter reads against the ceiling.** Rest text `Favor: <n> / <favor_max>`, delta
   note `Favor: <n> / <favor_max>  (<+d>)` — the same T-114 note machinery, tint and
   2.5 s expiry, with the ceiling interpolated from the export (`Game.favor_max`,
   `scripts/game.gd:42`), never a literal, so a future retune re-labels itself. Debt
   still reads (`Favor: -5 / 100`) — the T-114 no-floor lock is shown, not hidden.
2. **A caption row under the meter states the rule.** New scene-static `FavorGoal`
   label (`scenes/main.tscn`, under the FavorLabel block): "max the elders' favor to
   take the town" — the column's outline treatment (4 px, 14 px, like FavorLabel) at a
   dimmer white @ 0.6 so it reads as a caption on the meter, not a fourth score. Zero
   runtime code: the rule doesn't change mid-run, so the scene owns the text.
3. **The menu footer gains the win clause.** "eat bread to survive · splat tourists
   (100) and cars (30) · max the elders' favor to take the town · don't starve · Q quit"
   — ~124 chars at 15 px in the 1280 px window, comfortably inside it (the ControlsLabel
   line already runs 54 chars at the same size full-width).

**Tree facts (verified this session).** `_show_favor` composes both text forms and
guards the writes (`scripts/main.gd:552-565`); `restart_run()` re-fires it with favor 0
(the T-114 `restart_ok` leg, `tests/sim_test.gd:5903`); the scene block sits at
`scenes/main.tscn:208-218` (offsets 16/192/500/212, outline 4, font 14, white @ 0.75,
scene text "Favor: 0"). `Game.favor_max` is the T-115 export at 100
(`scripts/game.gd:42`); the clamp lives inside `add_favor` (`:174`), so the meter can
read at most the ceiling and never past it. The victory screen's breakdown carries its
own "Favor:" line (`tests/sim_test.gd:6576`) — that is the score screen's total, NOT the
HUD meter, and is untouched by this format change.

## Acceptance criteria

- [x] The HUD meter reads `Favor: <n> / <favor_max>` at rest and
      `Favor: <n> / <favor_max>  (<+d>)` while a delta note is live — ceiling
      interpolated from `Game.favor_max` (no literal in `main.gd`); scene text is
      `Favor: 0 / 100`; tint, expiry and restart-reset behavior are byte-identical to
      T-114's (only the composed strings grow)
- [x] A scene-static `FavorGoal` label exists under the meter with the exact text
      "max the elders' favor to take the town", the column outline treatment (4 px
      outline, 14 px font) at white @ 0.6, `unique_name_in_owner` set, and no code
      writer anywhere (grep-clean: only the scene sets its text)
- [x] The menu footer names the win rule (contains "favor" and "town") while keeping
      the survival, splat-value and quit clauses
- [x] *(Gate 1b)* `favor_meter_names_the_ceiling` — through the REAL main scene
      (the instanced-Main pattern): value-lock `Game.favor_max == 100` (T-115's tuning —
      a silent retune is a red flag, not a re-derive); rest form exact, gain form exact
      after a real `Game.add_favor(6)` ("Favor: 6 / 100  (+6)"), the 2.5 s game-time
      expiry back to rest, `restart_run()` reset to "Favor: 0 / 100"; the goal row
      asserts text + treatment + placement under the meter; debt form
      (`Game.favor = -3` staged → "Favor: -3 / 100") — the T-114 no-floor read shown
- [x] *(Gate 1b)* the T-039 `title_screen_teaches_controls` scenario grows a footer
      leg (it already reads the Footer label): the footer names "favor" and "town" —
      the by-design duplicated rules copy stays divergence-guarded
- [x] The five stale exact-string asserts in `splat_favor_follows_citizen_class`'s HUD
      legs (`tests/sim_test.gd:5812,5889-5903`) move to the new format — the scenario's
      behavioral asserts (tints, expiry, restart) are untouched
- [x] Full Gate 1b suite green in one headless run; VERIFICATION.md gains the new
      scenario row in the same change-set
- [x] Gate 3 eyes-on: a pilot screenshot shows the meter + caption row in the HUD
      column and the footer on the menu — recorded in VERIFICATION.md (agent grab
      2026-10-12, `.captures/session_t116hud/`; the owner feel pass is the ticket's
      one open Gate 3 line)

## Tuned values

- Goal caption text: "max the elders' favor to take the town" (scene-static)
- Caption tint: white @ 0.6 (dimmer than the meter's 0.75 rest fill — caption, not score)
- Footer: the win clause sits between the splat values and "don't starve"

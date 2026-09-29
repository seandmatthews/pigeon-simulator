# T-019 — HUD legibility & hunger warning

- **Milestone:** M1 · **Priority:** P0 · **Size:** S · **Status:** done
- **Depends on:** T-005 (hunger), T-010 (HUD/game flow) — both done
- **Refs:** `docs/DESIGN.md` → Hunger (T-005); expert UI/UX lane playtest
  2026-09-29 (pilot sessions `wt646889d-ui-uxa…d`, evidence cited inline)

## What

Make the HUD readable everywhere and make the survival clock warn before it
kills:

- Dark outlines on the HUD score line and control hint — white text currently
  washes out over the white pavement every run starts on
- A tiered hunger bar: white when healthy, amber under half, red pulsing under
  a quarter, fast-flashing dark red under 10% — the bar is the fail state's
  messenger, and today 3% looks exactly like 95%

## Why

The expert-lane play sessions showed, at the spawn corridor, the 14 px hint
line dissolving over the pale facade/white pavement and the borderless
default-styled bar invisible against the same background (`.captures` OS grabs,
sessions `…uxa`/`…uxd`); a starve run (`…uxc`) drained 17.68 → 3.27 → 0.00
(state.jsonl) with no warning state ever shown before `game_over`. An
invisible clock is an unfair death.

## Acceptance criteria

- [x] Score line and hint carry a resolved dark outline (machine: resolved
      theme getters); human legibility over white pavement / bright sky /
      dark road is the Gate 3 screenshot pass below
- [x] Hunger bar warns in four tiers — white > 50%, amber 25–50%, red
      pulsing 10–25%, fast-flashing dark red < 10% — driven in game time
      (deterministic under `--fixed-fps`)
- [x] Falling back to a lower tier restores that tier's rest color — no
      stranded mid-flash (crumb refills and `restart_run` both pass through
      `_on_hunger_changed`)
- [x] Machine-verified: Gate 1b scenario `hud_hunger_warning_tiers` through
      the real Main scene (64/64 PASS, exit 0, `SIM SUMMARY: 0 failure(s)`)

## Landed (implementation notes)

- `scenes/main.tscn` — theme overrides only: `outline_size` 6 on the 22 px
  StatsLabel, 4 on the 14 px HintLabel (43% of a 14 px glyph would blob);
  `font_outline_color` `Color(0, 0, 0, 0.85)`. Data-only; no new SubResources
  so `load_steps` is unchanged.
- `scripts/main.gd` — `hud_warning_tier` (0–3) computed in
  `_on_hunger_changed` from value/max bands; transitions key on tier CHANGE
  only (the hunger setter emits every drain tick, ~60/s on a live run, so the
  handler must be idempotent per tier). The pulse accumulates a phase from
  `_process(delta)` — game time, NOT `Time.get_ticks_msec`, so the flash
  freezes with the world under pause/game-over (correct: it freezes with the
  run; `restart_run` re-fires full hunger and restores the rest color) and
  stays deterministic headless — and rides `hunger_bar.modulate` only, a
  per-instance property; mutating the shared StyleBoxFlat would leak tier
  colors across the 4+ main.tscn instances the sim harness creates in one
  process.
- `tests/sim_test.gd` — `_scenario_hud_hunger_tiers` registered in
  `_run_scenarios` IMMEDIATELY AFTER `_scenario_restart_resets`: that is the
  only spot with an unpaused tree and no live Main (game_over_screen ends
  paused; restart_resets unpauses, detaches the clock, frees the instance —
  insert earlier and the fresh instance inherits a paused tree and a
  signal-shadowing sibling). Its cleanup tail mirrors
  `_scenario_juice_hit_shake_pulse` (`free()` → `Game.hunger.player = null` →
  `Game.reset_run()`). The pulse assertion samples `modulate` across a
  ~0.5 s window and compares per-channel spread plus zero-crossing counts
  (tier 3 flashes faster than tier 2) — alias-proof against sampling the
  flash at its rest point.
- Title screen considered and NOT changed: `scenes/menu.tscn` sits on a flat
  dark-navy Background ColorRect (`Color(0.16, 0.22, 0.33, 1)`), not a pale
  sky — white/gold text is legible there (lane screenshots), so the outline
  fix does not transfer.
- Gate 2 unaffected: the autoplay starves via `Game.hunger.value = 0.0`
  (tests/autoplay.gd:157), which will now flash the bar but no autoplay
  assertion reads it. No input changes → controls tables untouched.
- Ticket-ID note: T-015…T-018 do not exist on this branch (index ends at
  T-014); parallel lanes may allocate them — renumber at merge if they
  collide.

## Tuned values (final)

- Outline: `outline_size` 6 (StatsLabel 22 px) / 4 (HintLabel 14 px), color
  `Color(0, 0, 0, 0.85)`
- Tier rest colors on `hunger_bar.modulate`: 0 white; 1 amber
  `Color(1, 0.72, 0.35)`; 2 red `Color(1, 0.32, 0.25)`; 3 dark red
  `Color(1, 0.16, 0.14)`; pulse bright end `Color(1, 0.85, 0.8)`
- Bands: tier 1 ≤ 0.5 · tier 2 ≤ 0.25 · tier 3 ≤ 0.10 (fractions of max)
- Pulse rates: 3 Hz (tier 2), 6 Hz (tier 3) — sine on game-time phase

## Verification

Gate 1 + Gate 1b + Gate 2 (run by the workflow) + Gate 3. **Pending human
playtest (Gate 3):** hint/score legibility over white pavement at the spawn
corridor and over the bright sky at altitude; the amber/red tiers read at a
glance without staring at the bar; the pulse is noticeable but never
nauseating; no stranded flash after landing to eat.

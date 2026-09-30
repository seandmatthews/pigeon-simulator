# T-077 — Give F a readiness cue: three silent failure modes, one glyph

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** — (T-019's outline treatment is landed and reused as-is)
- **Refs:** sweep 1 session `uiuxs3b` (`.captures/session_uiuxs3b/events.jsonl`, readings below) ·
  T-025 (ball visibility), T-046 (impact ring), T-060 (hitbox + lead coach) — all separate fixes

## What

The poop action (F) fails silently in three distinct ways — grounded (by design), mid-cooldown
(`poop_cooldown` 1.0 s, `scripts/player.gd:68`), or both — and nothing tells the player which.
`_try_poop` (`scripts/player.gd:321-330`) just returns, and no HUD code reads `_poop_timer`.

Add a small always-present readiness glyph to the HUD:

1. **`scripts/player.gd`** — one additive getter beside `is_grounded` (`scripts/player.gd:91-93`),
   same shape:
   ```gdscript
   ## True while the poop cooldown has elapsed — the F readiness cue (T-077) reads this.
   var poop_ready: bool:
       get: return _poop_timer <= 0.0
   ```
   No behavior change: `_try_poop`, the cooldown write and `poop_cooldown` stay exactly as they are.
2. **`scripts/main.gd`** — `@onready var poop_ready_label: Label = %PoopReady`, driven in
   `_process` (game time — it freezes under pause because pausing writes `get_tree().paused`,
   `scripts/pause_menu.gd:50`, which stops `_process`):
   - grounded → `visible = false`;
   - airborne + `player.poop_ready` → `visible = true`, `modulate.a = 1.0`;
   - airborne + cooling → `visible = true`, `modulate.a = 0.25`.
   Guard both writes with changed-value checks so idle frames don't touch the node (the
   T-035/T-055 redundant-write concern; the tier pulse at `scripts/main.gd:96-100` is the pattern).
   No restart-specific code needed: `restart_run()` → `player.reset_flight(...)` zeroes
   `_poop_timer` (`scripts/player.gd:118`) and returns to AIR, so the next `_process` tick
   lights the glyph on its own.
3. **`scenes/main.tscn`** — new `PoopReady` Label in the HUD stack: `unique_name_in_owner = true`,
   text `F`, `font_size` 16, the T-019 outline treatment (`font_outline_color`
   `Color(0, 0, 0, 0.85)`, `outline_size` 4 — the family at `main.tscn:78`). Suggested slot
   beside the hint line: `offset_left 504 / offset_right 528 / offset_top 68 / offset_bottom 88`
   — clear of the hint label's box (ends x=500, `main.tscn:93-98`) and of the bread pointer's
   chevron (sits at ≈ (22, 102), `main.tscn:117-120`). Fine placement is a Gate 3 judgement.

What this does NOT claim: no audio cue; no change to when pooping works (grounded block,
cooldown); no world feedback — that is T-025's (visible ball), T-046's (predicted-impact ring)
and T-060's (hitbox + lead coach) territory. This ticket is input-state feedback: "can I F
right now".

## Why

The game's core scoring verb feels unresponsive: presses are eaten with zero feedback, so the
player can't tell blocked from wasted from in-flight. Session evidence (`uiuxs3b/events.jsonl`,
re-read this run): five `pilot_press` poop events all stamped t_ms 12437 (lines 9-13) produced
exactly ONE `poop` event (t_ms 12458, line 16) — four presses vanished into the cooldown
unheard; after the `grounded` event at t_ms 248567 (line 38), presses at t_ms 274246 and
274658 (lines 39-40) produced zero poop events. Even the one drop that fired left no
observable trace in any capture.

## Acceptance criteria

- [ ] Airborne with a rested poop the F glyph shows at full opacity; a drop dims it to ~25%
      alpha immediately, and it returns to full after `poop_cooldown` of game time with no
      further press
- [ ] Grounded, the glyph is hidden entirely — no dim ghost
- [ ] Pausing mid-cooldown freezes the glyph's state; after `restart_run()` mid-cooldown it
      is lit again
- [ ] Gate 1b scenario `poop_ready_indicator_tracks_cooldown` passes (below)
- [ ] Full Gate 1b suite green, explicitly `poop_lob`, the grounded/cooldown poop scenarios,
      and both HUD scenarios (`hud_bread_pointer_tracks_nearest_crumb`,
      `hud_hunger_warning_tiers`)
- [ ] [screenshot] The glyph reads at a glance beside the hint line over pavement and sky,
      and the dim state is distinguishable from the lit one

## Verification

Gate 1 + Gate 1b — new scenario `poop_ready_indicator_tracks_cooldown` through a real Main
(the `_scenario_hud_hunger_tiers` own-space pattern, `tests/sim_test.gd:2290-2296`:
instantiate `MAIN_SCENE` (`tests/sim_test.gd:14`), offset it to its own space, set
`Game.save_path = SIM_SAVE_PATH` first, and reuse that scenario's free/detach-clock cleanup):

- airborne fresh run → `%PoopReady` visible with `modulate.a` ≈ 1.0 (keep the instance's
  player airborne the way `_scenario_elder_no_bread_airborne` holds flight,
  `tests/sim_test.gd:1233-1235`);
- drive the REAL poop action — `_tap("poop")` (`tests/sim_test.gd:185-188`) — → dimmed
  (~0.25) immediately;
- advance more than `poop_cooldown` of game time (≥ 70 physics frames at the fixed 60 Hz) →
  lit again;
- land (`_await_grounded`, `tests/sim_test.gd:207-211`) → hidden;
- poop again, then `main_game.restart_run()` mid-cooldown → lit.

Register it beside the other poop scenarios in `_run_scenarios` (`tests/sim_test.gd:84`+).
Gate 2 runs normally. Gate 3: the [screenshot] line above; VERIFICATION.md gains a Gate 1b
row and a Gate 3 line in the same change-set.

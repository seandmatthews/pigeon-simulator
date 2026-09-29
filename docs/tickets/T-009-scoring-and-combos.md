# T-009 — Scoring & combos

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** done
- **Depends on:** T-006, T-007, T-008
- **Refs:** `docs/DESIGN.md` → Scoring

## What

Turning splats into numbers:

- New autoload `scripts/game.gd` owning score, combo state and high score
  (persisted to `user://`) — global state moves off `Main` (update the scaffold)
- Point values per DESIGN: tourist 100, car 30, combo ×2/×3… for consecutive hits
  without landing, +50% style bonus for fast/low dive hits
- Floating "+100 ×2" popups in world space at the splat; HUD score updates
- Combo resets on landing or after a window (~20 s)

## Why

The loop needs a scoreboard to push against. This is the "greed" half of the tension.

## Acceptance criteria

- [x] Numbers match DESIGN defaults and every value is tunable
- [x] Popups appear at the hit position and read clearly at flight speed *(position/format/fade machine-verified; readability at flight speed is a Gate 3 item below)*
- [x] Combo multiplier escalates and resets on landing/window as specified
- [x] High score persists across game restarts
- [x] `Main` no longer holds score/hunger globals — the autoload does

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: build a ×3 combo without landing, confirm style
bonus on a dive hit, restart and confirm the high score survived.

**Machine-verified (Gate 1b, `tests/sim_test.gd`):**

- `score_combo_style_values` — the Game autoload pays DESIGN values (tourist
  100, car 30), the chain escalates ×1 → ×2 → ×3 across target kinds, landing
  resets it, the 20 s window resets it, and the +50% style bonus demands a
  release that is fast (≥14 m/s), low (≤6 m) and fresh (≤3 s old) — each gate
  proven independently.
- `score_high_score_persists` — beating the record writes `user://` at once and
  a fresh Game loads it back (the restart round-trip, minus the process exit).
- `score_popup_floats_and_fades` — the world-space popup shows the ticket's
  "+100 ×2" format at the hit position, floats up, fades and frees itself.
- End to end: the T-007/T-008 splat scenarios now wire the spawner relays into
  the Game autoload exactly like `Main` does, so real lobbed drops score
  through the full chain — tourist 100 then the synthetic second hit at ×2
  (`Game.score == 300`), parked car 30 then the traffic hit at ×2 (90).

**Autoplay (Gate 2):** the DONE line now reports `score` and `high`. The pilot's
poop triggers gained a car-length pursuit window and the visit window raises the
lead-shot ceiling to 18 m (a steady descent keeps the fall-time prediction
honest). Target hits stay chance shots by design, so a given seed can finish at
`score=0` — the deterministic scoring proof is the Gate 1b list above; the
screenshots show the live HUD score line and hint.

## Implementation notes

- `scripts/game.gd` — the `Game` autoload (no `class_name`; registered under
  `[autoload]` in `project.godot`). Owns the score table, combo, style, high
  score **and the Hunger clock** (moved off `Main`/`main.tscn` as the
  `hunger.gd` docstring always planned). `Hunger.attach_player()` exists for
  late wiring (the autoload is in the tree before `Main`). `reset_run()` zeroes
  score/combo and refills hunger but deliberately keeps the high score.
- Style bonus is judged from the poop's **release** conditions (relayed via
  `player.pooped` → `Game.on_poop_released`), not the impact — gravity gives
  every falling drop speed, but only a dive releases it fast AND low; the
  release goes stale after 3 s so a forgotten lob can't style a later hit.
- Chain state: any hit advances the streak (tourist → car chains too); landing
  (`grounding_changed` true) and the 20 s window both reset it. Points are
  `roundi(base × multiplier × (1.5 if style))`.
- High score saves to `user://highscore.cfg` the moment a run beats it (an
  Alt-F4 keeps the record). The sim harness redirects `Game.save_path` for its
  whole run so test scores never touch the real file.
- `scenes/score_popup.tscn` + `scripts/score_popup.gd` — billboarded Label3D,
  `setup()` before `add_child` (the float tween must start from the hit, not
  the origin), rises 1.8 m over 1.2 s while the last 60 % fades it out, then
  frees itself. `Main` instantiates popups; the autoload stays
  presentation-free.
- `Car.points_value` removed — the table lives in the Game autoload's exports
  now (`car_points 30`).
- Autoplay got its hunger from `_game.get_node("Hunger")` before; it reads
  `Game.hunger` now.

## Tuned values (`@export`)

| Where | Value |
| ----- | ----- |
| `Game.tourist_points` / `Game.car_points` | 100 / 30 (DESIGN table) |
| `Game.combo_window` / `Game.combo_max` | 20.0 s / 0 (= uncapped ×1 → ×2 → ×3…) |
| `Game.style_bonus_fraction` | 0.5 (+50 %) |
| `Game.style_min_speed` / `style_max_height` | 14.0 m/s / 6.0 m at release |
| `Game.style_release_window` | 3.0 s |
| `Game.save_path` | `user://highscore.cfg` (sim redirects to `user://sim_highscore.cfg`) |
| `ScorePopup.lifetime` / `rise_height` | 1.2 s / 1.8 m |
| Autoplay `_lead_ceiling` | 14 m cruise · 18 m during the ground-visit window |

## Pending human playtest (Gate 3)

- [ ] Splats pay the DESIGN points — 100 per tourist, 30 per car — and a popup at the hit reads clearly at flight speed
- [ ] Chained hits without landing escalate ×2, ×3… and reset when you land or after ~20 s
- [ ] A fast low dive hit pays the +50% style bonus — visible as a bigger popup number
- [ ] Beating the high score, then quitting and relaunching, shows the record survived

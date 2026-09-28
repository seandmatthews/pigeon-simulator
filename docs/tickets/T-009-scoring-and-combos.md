# T-009 — Scoring & combos

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** todo
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

- [ ] Numbers match DESIGN defaults and every value is tunable
- [ ] Popups appear at the hit position and read clearly at flight speed
- [ ] Combo multiplier escalates and resets on landing/window as specified
- [ ] High score persists across game restarts
- [ ] `Main` no longer holds score/hunger globals — the autoload does

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: build a ×3 combo without landing, confirm style
bonus on a dive hit, restart and confirm the high score survived.

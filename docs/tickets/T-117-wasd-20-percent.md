# T-117 — 20% more WASD: the owner responsiveness pass

- **Milestone:** M2 follow-up (feel tuning) · **Status:** doing · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-001/T-015 (the flight model and its speed envelope), T-083 (pitch authority falloff), T-106 (measured-roll bank control) — all done
- **Refs:** owner playtest note (2026-10-13): "the movement feels insufficiently responsive. I definitely need to be able to dive faster, but I feel like if everything was faster that would be just fine. Let's make WASD do 20% more of whatever they're doing."

## What

Exactly what the owner ordered: every WASD-driven rate and the speed cap their inputs
reach scale by ×1.2 — nothing else in the flight model moves. The bird pitches,
banks and yaws 20% harder, waddles and waddle-turns 20% faster, and the global speed
cap rises 20%, which is where "dive faster" lands: a dive is pitch-down (faster now)
plus the terminal speed the cap allows (36 instead of 30).

**Scaled (all `scripts/player.gd` @export defaults; no scene or harness overrides
exist — verified):**

| Constant | Before | After (×1.2) | Axis |
| --- | --- | --- | --- |
| `pitch_speed` | 2.2 rad/s | 2.64 | W/S in flight |
| `bank_rate` | 3.5 rad/s | 4.2 | A/D roll toward target bank |
| `full_bank_yaw_rate` | 1.5 rad/s | 1.8 | A/D yaw at full bank |
| `max_speed` | 30 m/s | 36 | the cap dives fly into |
| `walk_speed` | 2.2 m/s | 2.64 | grounded W/S waddle |
| `walk_accel` | 10 m/s² | 12 | waddle spin-up |
| `waddle_turn_rate` | 2.6 rad/s | 3.12 | grounded A/D |

**Untouched on purpose** — the owner said WASD, and these are not WASD's doing: the
whole flap family (Space), boost (Shift), the flight model's energy exchange
(`gravity`, `glide_speed`, `drag`, `velocity_align_rate`, the stall family, `trim_rate`,
the flare pair), passive ground physics (`ground_friction`, `walk_decel`,
`ground_level_rate`), and the home nudge (a share of `max_bank_deg`, which didn't move
— a held turn still overpowers it by more than before).

**Known ripples, watched in Gate 1b:** turn-rate and flare bars pin the old authority
(`banked_left_turn`, `flare_sheds_speed_low`), the dive top-end bar in
`flap_speed_envelope` pins the old cap, and loop/stall timings loosen. Bars that pin
the OLD tuned values get re-derived from the new ones in the same change-set; bars
that are safety invariants (bounds, one-shot latches) must pass untouched or the
change is wrong. The favor-max pace arithmetic (T-115's 6–8 min) gets slightly
friendlier — its Gate 3 line is open anyway.

## Acceptance criteria

- [ ] The seven constants above carry exactly the ×1.2 values; no other player.gd
      export changes; `scenes/main.tscn` and the harness carry no overrides of them
- [ ] *(Gate 1b)* full suite green in one headless run — scenario bars re-derived
      where they pinned the old authority/cap, recorded in the table below; every
      scenario green with NO logic edits
- [ ] *(Gate 2)* autoplay re-run green (`AUTOPLAY DONE ok=true restart=true`) with no
      autopilot edits — the scripted run survives the stronger responses
- [ ] *(Gate 3)* owner feel pass: the bird reads as snappier on WASD and dives
      meaningfully faster, nothing twitchy — recorded in VERIFICATION.md

## Tuned values

See the table above — this ticket's whole payload is that ×1.2 column. Gate 1b bar
re-derivations recorded below as they land:

*(filled during the run)*

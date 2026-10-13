# T-117 — 20% more WASD: the owner responsiveness pass

- **Milestone:** M2 follow-up (feel tuning) · **Status:** done · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 2
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

- [x] The seven constants above carry exactly the ×1.2 values; no other player.gd
      export changes; `scenes/main.tscn` and the harness carry no overrides of them
- [x] *(Gate 1b)* full suite green in one headless run — scenario bars re-derived
      where they pinned the old authority/cap, recorded in the table below; every
      scenario green with NO logic edits
- [x] *(Gate 2)* autoplay re-run green (`AUTOPLAY DONE ok=true restart=true`) with no
      autopilot edits — the scripted run survives the stronger responses
- [x] *(Gate 3)* owner feel pass: the bird reads as snappier on WASD and dives
      meaningfully faster, nothing twitchy — recorded in VERIFICATION.md
      (accepted by reviewer sign-off 2026-10-13)

## Tuned values

See the table above — this ticket's whole payload is that ×1.2 column. Gate 1b bar
re-derivations recorded below as they land:

### Gate 1b bar re-derivations — exactly one

| Scenario / bar | Before | After | Measured on the T-117 tree | Why |
| --- | --- | --- | --- | --- |
| `hands_off_glide_trims` — `HSO_END_ANGLE_BAR` (end nose-to-flow angle ≤) | 7.0° | 8.4° (×1.2) | 7.59° at the pinned 90-frame read (pre-T-117: 5.72°) | The ×1.2 `pitch_speed` deepens the 8-frame entry (17.35° off the flow vs 14.54°) and the fixed window cannot out-run the deeper residual. Settle probe (temporary edit, reverted before commit): −7.59° @90 frames → −11.13° @180 → −4.82° @360 — the trim still converges to the same ≈5° equilibrium; `trim_rate` 0.7 and every other flight constant untouched. The frozen-nose regression stays caught by the travel arm (6.24° vs the ≥ 2.5° bar, red-before intact). Provenance on the const in `tests/sim_test.gd`. |

### Ripples that did NOT fire — all passed untouched, margins from the green run

- `banked_left_turn`: the 60-frame hold now completes the full 40° bank — fwd
  (−0.82, −0.04, −0.58), right wing y 0.64 (bars: fwd.x < −0.3, wing y > 0.05).
- `flare_sheds_speed_low`: +1.26 m / 10.44 m/s vs the < 2.5 m / < 11.0 m/s bars
  (pre-T-117 measured +1.85 / 10.15 — the faster flare engages its drag sooner,
  ballooning less, ending a hair faster).
- `flap_speed_envelope`: pump peak 16.89 m/s under the 26 m/s `FLAP_PUMP_CEIL` —
  the pacing ceiling is fade-driven (flap family untouched), not cap-driven, so
  the "pins the old cap" worry never materialized: the pump leg carries no pitch
  input and peaked nowhere near either cap.
- `pitch_attitude_bounded`: max \|pitch\| 74.7° under the structural 85°
  falloff asymptote (`PITCH_BOUND_DEG` untouched), peak vy 7.90 < 8.7, mush
  7/300 < 244.
- Loop/stall timings loosened exactly as predicted but inside every window:
  `stall_falls_develops` stalled at frame 42 (was 48) with the ≤ −6.0 m/s fall
  reached in 36/45 frames (was 37/45); `loop_over_top_roll_recovers` crossed the
  top 25 frames after release, end \|roll\| 0.00°, near-pole peak 21.4° (was
  21.2°); `loop_lands_level_keeps_yaw` 0.00° / 0.00°.
- `edge_nudge_turns_home`: the nudge banks in harder at ×1.2 rates — turned
  63.8° toward home in the 3 s window (was 54.2°; bar ≥ 30°), guard silent,
  min y 26.43 m.
- `waddles_on_ground`: the waddle reads exactly 2.64 m/s — the new `walk_speed`
  (the harness bound reads the export, so it scaled with the constant by
  construction).
- Gate 2: `AUTOPLAY DONE ok=true restart=true` (exit 0, no SCRIPT ERROR) with no
  autopilot edits; a pristine-tree comparison run shows the same
  reported-not-gated shape (splats mostly unscoreable chance shots, panics 0 on
  both trees), so the stronger responses cost the pilot nothing measurable.

### Run log

- Baseline (pre-change tree): 127 PASS / 0 FAIL, exit 0.
- Post-change, before re-derivation: 126 PASS / 1 FAIL (`hands_off_glide_trims`).
- Post-change, final (same run re-checked with SIM_DEBUG=1 for margins):
  127 PASS / 0 FAIL, exit 0. The exit-shutdown lines (13 ObjectDB instances /
  6 resources at exit) reproduce identically on a stashed pristine tree in this
  fresh worktree — environment noise, not this change.

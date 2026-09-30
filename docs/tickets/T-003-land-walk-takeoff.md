# T-003 — Land, walk, take off

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** done
- **Depends on:** T-001
- **Refs:** `docs/DESIGN.md` → Hunger (eating happens on the ground)

## What

Add an air/ground state machine to the Player:

- **Landing:** touching a surface at shallow angle + low speed → grounded (no damage model in M1)
- **Waddle:** WASD on the ground, slow and comedic; `flap` takes off again
- Anything on layer 1 (`world`) is landable — ground, roofs, benches

## Why

The hunger loop (T-005) needs the pigeon to come down, peck, and leave again. This is
the mechanic that makes the game touch the ground at all.

## Acceptance criteria

- [x] Land on flat ground, a roof and a bench; walk on each; take off again
- [x] Hard, fast landings just slide/stop — no crashes, no tunneling through geometry
- [x] Take-off from a roof works the same as from the ground
- [x] State is readable (HUD hint or animation pose) so players know they're grounded

All machine-verified by the Gate 1b scenarios (`waddles_on_ground`, `waddle_turns`,
`flap_takes_off_ground`, `roof_landing`, `roof_takeoff`, `bench_landing`,
`bench_takeoff`, `hard_landing_skids`); the autoplay pilot's ground visit shows the
grounded squat pose and the HUD hint swap in the real game. The *feel* half — whether
the waddle reads as slow and comedic — is pending the human Gate 3 lines.

## Tuned values (v1)

`max_land_speed 16` (T-021, was 12) · `max_land_angle_deg 30` · `skid_settle_speed 2`
(T-021) · `walk_speed 2.2` · `walk_accel 10` · `walk_decel 22` · `waddle_turn_rate 2.6` ·
`ground_level_rate 6` · `grounded_squat 0.82` · `waddle_bob_rate 10` ·
`waddle_bob_height 0.03` · `waddle_sway 0.1`

Model notes from the tuning session:
- A touch settles into the waddle only below `max_land_speed` and `max_land_angle_deg`
  of descent; anything harder stays in AIR and skids (`ground_friction`) until it has
  bled down to waddle pace. Falling out of a stall means a forward skid, because
  velocity chases the nose as the stall drops it — that's why `walk_decel` exists.
  (T-021 amends the settle semantics: the touch is judged ONCE, on the first
  floor-contact frame's pre-move velocity — `max_land_speed` rose 12 → 16 because
  the model's own trim glide touches down at 15.3–17.2 m/s — and a rejected touch's
  skid may only settle again under `skid_settle_speed` 2, i.e. near rest.)
- A grounded flap launches up+forward from a level attitude regardless of body pitch:
  a pigeon that touches down nose-low would otherwise "flap" into a forward lunge
  along the pavement instead of a startled hop into the air.
- W/S reuse the pitch actions and A/D the turn actions while grounded — no new input
  actions; `grounding_changed(grounded)` drives the HUD hint (`%HintLabel` in main.tscn).
- `reset_flight` distrusts `is_on_floor()` for 2 frames (`_air_grace`) — the flag is
  stale after a teleport and once settled the pigeon mid-air on top of it.

## Verification

Gate 1 + Gate 2 + Gate 3, plus explicitly landing on all three surface types above —
the three surfaces are now machine-covered by Gate 1b (ground / roof / bench boxes),
and the autoplay ground visit (staircase descent → touchdown → waddle → take-off)
smoke-covers the whole loop; the Gate 3 playtest lines cover the human feel pass.

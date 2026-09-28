# T-001 — Flight feel v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** L · **Status:** done
- **Depends on:** — (placeholder controller already in `scripts/player.gd`)
- **Refs:** `docs/DESIGN.md` → Flight · Pillar 1

## What

Replace the placeholder controller with the real arcade flight model:

- **Flap** (Space): timed impulse up+forward; pacing beats mashing (mash = weaker average impulse).
- **Glide**: gravity scales down with forward speed (lift); gliding converts height into speed.
- **Dive**: pitching down accelerates hard; pulling up trades that speed back for height.
- **Banking turns**: A/D banks the body and yaw follows the bank — pigeon-like, not tank-like.
- **Stall**: below a minimum airspeed, lift collapses and the pigeon drops until speed returns.

## Why

Pillar 1 — flight is the toy. Everything else in the game sits on top of this feeling great.

## Acceptance criteria

- [x] Take off from the ground with 2–3 flaps and sustain altitude by flapping
- [x] Gravity noticeably softens with forward speed; gliding feels smooth
- [x] Dive then pull-up gains real height (energy exchange is legible)
- [x] Turns bank and feel weighty; no instant tank-yaw
- [x] Stalling (too slow) drops the pigeon; recovery works without inputs feeling eaten
- [x] All tunables are `@export` vars; a tuning session leaves defaults that feel good
- [x] Landing at low speed slides to a stop — no bouncing, no NaNs

All seven are machine-verified by the Gate 1b sim harness (`tests/sim_test.gd`, 8/8
scenarios). The *feel* half of "feels good / feels weighty" still deserves a human
pass over the T-001 lines in `VERIFICATION.md` Gate 3.

## Tuned values (v1)

`flap_impulse 13` · `flap_interval 0.35` · `flap_min_fraction 0.25` · `flap_cooldown 0.12` ·
`gravity 12` · `glide_speed 17` · `min_gravity_fraction 0.2` · `stall_speed 5` ·
`stall_gravity_scale 1.7` · `stall_nose_drop_rate 1.1` · `max_speed 30` · `drag 0.06` ·
`max_bank_deg 40` · `bank_rate 3.5` · `full_bank_yaw_rate 1.5` · `pitch_speed 2.2` ·
`min_control_authority 0.35` · `velocity_align_rate 3.5` · `ground_friction 14`

Model notes from the tuning session:
- Gravity is decomposed along vs. perpendicular to the flight path: the along-path
  part is never softened (dives accelerate, climbs pay), only the path-bending
  "sink" part yields to speed-scaled lift. Softening by speed alone made fast dives
  weightless and the energy exchange illegible.
- Velocity direction chases the nose via magnitude-preserving slerp; a plain lerp
  there silently bleeds speed during maneuvers and kills pull-ups.

## Verification

Gate 1 + Gate 2 + full Gate 3 list in `VERIFICATION.md`. Fly for 3 minutes with no
errors; record the final tuned values in this ticket before closing.

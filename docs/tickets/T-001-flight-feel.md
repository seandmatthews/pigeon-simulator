# T-001 — Flight feel v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** L · **Status:** todo
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

- [ ] Take off from the ground with 2–3 flaps and sustain altitude by flapping
- [ ] Gravity noticeably softens with forward speed; gliding feels smooth
- [ ] Dive then pull-up gains real height (energy exchange is legible)
- [ ] Turns bank and feel weighty; no instant tank-yaw
- [ ] Stalling (too slow) drops the pigeon; recovery works without inputs feeling eaten
- [ ] All tunables are `@export` vars; a tuning session leaves defaults that feel good
- [ ] Landing at low speed slides to a stop — no bouncing, no NaNs

## Verification

Gate 1 + Gate 2 + full Gate 3 list in `VERIFICATION.md`. Fly for 3 minutes with no
errors; record the final tuned values in this ticket before closing.

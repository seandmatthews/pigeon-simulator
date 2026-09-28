# T-012 — Audio v1

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** todo
- **Depends on:** T-005, T-006, T-007, T-008
- **Refs:** `docs/DESIGN.md` → Tone (comedic, family-friendly)

## What

First sound pass:

- SFX: flap whoosh, splat, tourist yelp + panic, car honk, bread peck, wing-beat
  effort while climbing
- City ambience bed (traffic murmur, distant chatter) looping under everything
- Audio buses Master / SFX / Ambience; sane default volumes
- CC0 sources only (freesound, Kenney, Sonniss GDC packs), all logged

## Why

The splat and the yelp carry half the comedy. Silence makes the city feel dead —
pillar 2.

## Acceptance criteria

- [ ] Every listed sound exists and is wired to the right event
- [ ] Mix is sane: nothing clips, ambience never drowns gameplay SFX
- [ ] Ambience loops seamlessly
- [ ] `assets/CREDITS.md` lists every file with source and license

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: trigger every sound once via normal play; listen
for clipping, missing loops, and off-sync flaps.

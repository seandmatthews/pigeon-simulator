# T-012 — Audio v1

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** done
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

- [x] Every listed sound exists and is wired to the right event
- [ ] Mix is sane: nothing clips, ambience never drowns gameplay SFX
- [ ] Ambience loops seamlessly
- [x] `assets/CREDITS.md` lists every file with source and license

*(Criteria 2–3 are listen judgements: the mix is sane **by construction** —
every file peak-normalized to −3 dBFS, beds RMS-normalized with a −6 dBFS peak
cap, Ambience bus 10 dB under SFX plus per-sound trims — and the beds were
**made** seamless (head-tail crossfade loops, loop flag machine-checked), but
"nothing clips" and "no audible seam" need human ears. Pending Gate 3 listen
pass — see below.)*

## Landed (T-012)

- `scripts/sfx.gd` — `Sfx` autoload: the sound palette (stream + per-sound trim
  + pitch jitter), a pool of 6 non-positional + 12 positional voices,
  `play()`/`play_at()`, the looping ambience bed (`start_ambience()` idempotent,
  survives restarts; stops when Main returns to the title screen), and
  `played_counts` — the machine evidence Gate 1b and the autoplay DONE line
  report.
- `default_bus_layout.tres` + `project.godot` — Master / SFX / Ambience buses.
- Wiring: flap whoosh + climb effort on every real flap impulse
  (`player.gd _flap`), bread peck in `player.peck()`, splat at first poop
  contact (`poop.gd`), yelp at a tourist splat + indignant panic shout when the
  fist shake starts (`tourist.gd`), horn in `car.gd honk()`, ambience
  start/stop in `main.gd`.
- Assets (all CC0, edited derivatives, logged in `assets/CREDITS.md`):
  flap whoosh + effort (artisticdude swishes), splat (EZduzziteh squish),
  yelp (Ferk girly scream), panic shout (pauliuw), horn (AntumDeluge bicycle
  horn), traffic murmur (IgnasD), distant chatter (StarNinjas), bread peck
  (Kenney impact).
- Verification: five Gate 1b scenarios (`audio_buses_and_assets`,
  `sfx_flap_effort_fires`, `sfx_peck_plays_on_eat`, `sfx_splat_yelp_panic_honk`,
  `ambience_loops_under_game`); the autoplay DONE line now reports
  `sfx=<name:count…>` + `ambience` and gates on the bed looping plus ≥1 whoosh.

## Tuned values (final)

- Buses: Master 0 dB · SFX −2.0 dB · Ambience −10.0 dB
- Per-sound trims (dB, on the SFX bus): flap −6 · effort −8 · splat −2 ·
  yelp −3 · panic −4 · honk −3 · peck −4; pitch jitter ±0.06 (honk) to ±0.2
  (peck)
- Ambience players: traffic murmur 0 dB, distant chatter −8 dB (the chatter
  bed is peakier); files RMS-normalized to −30 dBFS, peak-capped −6 dBFS;
  seamless loops of 59.6 s (3 s crossfade) and 27.4 s (2.5 s crossfade)
- `player.effort_climb_speed` = 2.0 m/s — the climb the pigeon must *already*
  be on (pre-impulse vy) for the effort beat; the impulse itself would flatter
  every flap
- `tourist.panic_shout_at` = 0.8 s of panic left — the shout lands together
  with the fist shake
- 3D positional roll-off: `Sfx.pos_unit_size` = 10 m (≈ half volume at 10 m)

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: trigger every sound once via normal play; listen
for clipping, missing loops, and off-sync flaps.

**Pending human playtest (Gate 3):** the four T-012 playtest lines — every
sound triggered in a real run; nothing clips at splat+yelp+honk pile-ups; no
audible seam on either ambience loop over minutes; flap whoosh in sync with the
wing beat and the effort strain only on hard climbs. The honk is deliberately a
comedic bike-horn blast — believability is a listen judgement.

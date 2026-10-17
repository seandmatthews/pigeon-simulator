# T-123 — Sound pass: coos, splat variety, and endings that aren't silent

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-8) · **Status:** proposed · **Category:** audio · **Value (1-5):** 4 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** `scripts/sfx.gd` pool architecture (6 non-positional + 12
  positional players, pitch jitter, `unit_size = 10`); existing palette:
  flap, effort, splat, yelp, panic, honk, peck + traffic/chatter ambience
  loops; the win (favor max) and starvation endings are currently silent;
  there is no music at all; boot-muted policy unchanged. DESIGN's music
  question is explicitly NOT this ticket.

## What

Three additions, all through the existing `sfx.gd` pools and buses — no new
buses, no music:

1. **Pigeon coos** — grounded idle, waddle, and a smug post-splat coo.
2. **Variants** — 2–3 alternates each for splat, yelp, and honk, cycled
   randomly so repeated hits stop reading as one sample. Keep the
   pitch-jitter convention.
3. **Endings** — a win stinger on `favor_maxed` and a lose sting on
   starvation, each firing exactly once per run.

Source CC0 audio; verify the license per file and record every import in
`assets/CREDITS.md`. The mute-by-default boot policy and the
`--audio-driver Dummy` autoplay path are untouched.

**Route note:** presentation-only → direct-loop eligible.

## Acceptance criteria

- [ ] *(Gate 1b)* extend the sfx-count scenarios: a splat (any variant)
      plays on first contact; the win and lose stingers fire exactly once per
      ending — logical counts under `--audio-driver Dummy`
- [ ] *(Gate 1b)* variant randomization does not perturb determinism
      (seeded, or confined to presentation)
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 3)* owner listen pass (`--sound`): coos charm, repeated splats
      stop grating, the endings land — recorded here

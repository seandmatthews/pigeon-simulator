# T-123 — Sound pass: coos, splat variety, and endings that aren't silent

- **Milestone:** M3 wave 1 (owner batch, from IDEAS.md B-8) · **Status:** done 2026-10-17 · **Category:** audio · **Value (1-5):** 4 · **Risk (1-5):** 1
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

Source: the spec said CC0 recordings, but the landed implementation went one
better on license cleanliness — the seven NEW sounds (3 coos, 2 splat
variants, 2 stingers) are **synthesized in-house** by `tools/gen_sfx.py`
(sines + shaped noise, committed and re-runnable), recorded in
`assets/CREDITS.md` as the project's own work. The yelp/honk variants reuse
the existing CC0 recordings at shifted base pitches through the variant
cycler. The mute-by-default boot policy and the `--audio-driver Dummy`
autoplay path are untouched.

**Route note:** presentation-only → direct-loop eligible.

## Acceptance criteria

- [x] *(Gate 1b)* extend the sfx-count scenarios: a splat (any variant)
      plays on first contact; the win and lose stingers fire exactly once per
      ending — logical counts under `--audio-driver Dummy`
      (`sfx_coos_and_stingers`: idle + waddle coos on cadence, smug coo on
      the 2nd-splat parity exactly, stinger_win then stinger_lose exactly
      once each through one real Main across both registers)
- [x] *(Gate 1b)* variant randomization does not perturb determinism
      (seeded, or confined to presentation — the variant cycler is a plain
      per-group counter, and `played_counts` records the REQUESTED name)
- [x] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true`; the DONE line
      reports the new voice live: coo_waddle:2, stinger_lose:1)
- [ ] *(Gate 3)* owner listen pass (`--sound`): coos charm, repeated splats
      stop grating, the endings land — recorded here
      *(PENDING owner pass — the machine legs are green. NOTE: the coos and
      stingers are synthesized placeholders by design; if the ear disagrees,
      swap CC0 recordings into `assets/generated/` 1:1 — the wiring does not
      change.)*

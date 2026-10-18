# T-129 — Web boot paints instead of stalling: sliced city boot + a loading screen that waits for warm

- **Milestone:** M3 wave 2 (owner-directed, web performance) · **Status:** proposed · **Category:** platform · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-128 (touches the same spawner boot path — runs after it merges)
- **Refs:** owner report 2026-10-18, desktop Edge AND Firefox behave the same
  (kills the browser-warm-up theory — this is our code): the Fly button
  darkens instantly, then ~2 s of dead air, then the world appears with the
  camera crawling into position and input unreliable for ~10 s. Grounded
  mechanism: `main.gd:642` runs `city.generate()` synchronously in Main's
  setup and every spawner populates in `_ready` (`band_spawner.gd:44`) — all
  BEFORE the first frame of the new scene can paint; the ~2 s dead air is that
  burst, and the ~10 s slideshow tail is first-draw pipeline/shader
  compilation (Compatibility/WebGL compiles each material variant on first
  use, spread across the city's first visible seconds) compounded by physics
  catch-up (a stalled frame owes up to `max_physics_steps_per_frame` ticks).
  The "camera slowly shifts" tell: the chase camera's exponential follow runs
  per-frame, so at single-digit fps it takes visible seconds to converge.
  Single-threaded web build per T-118; boot splash navy per T-125.

## What

Three legs, one goal — the busy work happens where the player is already
entertained:

1. **Paint between boot phases (the real win).** Main's boot becomes a
   stepped sequence the engine can render between: after the Fly press the
   menu hands off with immediate feedback ("warming up the city" beat in the
   title's own navy), then the world comes up in slices — ground/slabs →
   buildings → visuals → spawners in batches (cars first, then tourists,
   bread, elders) → first flight frame. Every phase prints an ms-per-phase
   trace line (desktop AND web builds), recorded in this ticket — the
   numbers decide which further knobs are worth turning. The sim harness
   keeps a synchronous path: an export flag (default ON in game, OFF for
   instanced-Main rigs) so every existing scenario boots byte-as-today; a
   new Gate 1b scenario pins the stepped path itself (steps callable in
   order, trace emits, flag default).
2. **The cheat, done properly: the loading screen waits for warm.** A custom
   web export shell keeps the branded loader visible (navy, pigeon mark, a
   rotating tone-safe tip line — "the black-and-gold pay favor" · "bread,
   quick") until Godot signals readiness via `JavaScriptBridge` AFTER the
   first warm frames — then it fades out over the live game. The slideshow
   happens behind the loader instead of in the player's face. The loader
   re-check rides the owner's next hosted deploy (T-126 pattern).
3. **Web-only warm-up diet (gated on the trace numbers).** Feature-tagged
   web overrides as experiments, each kept only if its trace delta proves
   it: smaller (or off) directional shadow, MSAA off, and a web override of
   `max_physics_steps_per_frame` to stop catch-up compounding a stall into
   a slideshow. No desktop setting moves.

**Route note:** pipeline — boot timing + spawner staging are bar-derivation
territory, and T-128 will have just re-derived the same scenarios.

## Acceptance criteria

- [ ] *(Gate 1b)* a scenario pins the stepped boot: the phase sequence is
      explicit and ordered, the trace emits per-phase ms, the sync flag
      defaults keep every existing scenario green untouched
- [ ] *(Gate 1b)* full suite green (sync boot path for rigs)
- [ ] *(Gate 2)* autoplay green
- [ ] *(Gate 2)* web export builds; the loader holds until the readiness
      signal and the ms-per-phase trace is readable in the browser console —
      numbers recorded here
- [ ] *(Gate 3)* owner on the hosted build: the Fly press answers instantly,
      the loader covers the warm-up, and the world fades in already playable —
      recorded here

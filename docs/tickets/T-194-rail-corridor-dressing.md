# T-194 — Ames R3 · rail corridor: the depot, the crossings, the daily coal drag

- **Status:** proposed · **Category:** visual-design · **Ring:** R3 The Landmarks ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-177 (corridor flats exist), T-180 (crossing set)
- **Refs:** `MODELING-SPECS.md` §1 rail-corridor · `census` §5 (9
  at-grade crossings; 4 vehicular downtown: Grand, Clark, Kellogg,
  Duff) · `images/rail/` (10 refs: depot, coal drag, wigwag, elevator
  styles) · ground truth: NO Amtrak — nearest stop Osceola (depot is a
  preserved C&NW building, no passenger signage) · daily train =
  yellow SD70ACe coal drags (Big Boy = 2019 special, do NOT model as
  daily)

## What

The motion landmark, honest to the verified facts:

- **The train**: a SD70ACe-led coal drag (yellow/gray livery) as a
  loop-timer landmark — it runs the main line on a simple schedule
  (frequency from the refs' "daily traffic" read; a timer, not a
  simulation). The game's 9 crossings are route facts; the train does
  NOT gate traffic (no event system — the fence; cars just cross, the
  train is dressing that moves).
- **The depot**: the brick + red-tile hip-roof building at its real
  spot — NO Amtrak signage (corrected fact), blank-preserved-depot
  read.
- **Crossing hardware**: crossbucks at the 9 (the T-134-style sign
  discipline; the wigwag is a museum piece — optional flavor at ONE
  crossing if cheap).
- Corridor texture polish: ballast, tie hint, fence line (photo 06's
  right-of-way cross-section).

## Why

The main line is the town's spine between campus and downtown and the
census's designated "motion landmark" — one train asset, reused across
all 9 crossings, makes the whole map feel alive for one asset's cost.

## Acceptance criteria

- [ ] Train: correct livery, loop schedule pinned (frequency + speed
      recorded), no traffic gating (cars cross regardless — probe)
- [ ] Depot at true position, no Amtrak marks; crossbucks at all 9
- [ ] *(Gate 1b)* `rail_dressing_pins`: depot pos, crossing set = 9,
      train schedule constants
- [ ] Screenshot set vs `images/rail/` refs
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3: screenshots; owner pass
in T-196.

## Decisions & forks

A train-blocking EVENT (cars hold, bells ring) is deliberately out —
it's a gameplay system and needs its own owner-picked ticket.

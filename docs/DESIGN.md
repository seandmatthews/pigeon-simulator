# Pigeon Simulator — Game Design

Last updated: 2026-09-28 (pre-alpha)

## Pitch

You are a pigeon in a sunny low-poly city. Eat bread to survive; earn points by
pooping on tourists and their cars. Fly well, eat regularly, be a menace.

## Decisions (locked 2026-09-28)

| Topic | Decision |
| ----- | -------- |
| Art style | Low-poly, bright & cartoonish (CC0 packs where possible) |
| Structure | Endless score attack: one living city, run ends on starvation |
| Fail state | Hunger at zero → game over → score screen → restart |
| City | Procedural street grid, landmark features sprinkled by seed |
| Platform | Windows desktop, keyboard + mouse first (gamepad later) |
| Tone | Comedic, family-friendly |

## Core loop

FLY the city → SPOT bread or a target → DIVE to poop / LAND to eat → SCORE &
SURVIVE → repeat.

Hunger is the clock that forces you down to the pavement; points are the greed that
pulls you into risky flying. The moment-to-moment tension is choosing the next risky
dive versus playing it safe for crumbs.

## Pillars

1. **Flight is the toy.** Soaring between rooftops must feel great even with nothing
   else in the world. Flight feel gets its own ticket (T-001) and its own tuning pass.
2. **The city reacts.** Tourists panic and flee, cars honk, pigeons scatter. A silent
   city is a failed city.
3. **Cheap points vs. good points.** Cars are big, easy targets worth little; a splat
   on a moving tourist is skill and pays well; streaks without landing multiply.

## Mechanics

### Flight (T-001)
Arcade, not simulation. Flap for timed impulses that are up-and-forward when slow
and mostly lift near cruise (T-015) — pacing beats mashing, and sustained flapping
converges around 20 m/s (the T-043 fade cuts each flap's impulse as speed builds),
so speed beyond that comes from diving. Forward speed generates lift
that softens gravity; diving trades height for speed; pulling up trades it back.
Turns bank the body. Too slow → stall. All tunables are
exported on the player script for live tweaking.

### Hunger (T-005)
- Drains over time — faster while flapping/boosting, slower while gliding.
- Bread (crumbs on pavements, benches, café tables) restores a chunk. Eating happens
  on the ground (peck) — this is what forces the land/fly rhythm.
- Hunger zero → game over (handled by T-010): score screen, restart.

### Poop (T-006)
- **F** drops a dropping with inherited velocity + gravity: a lob, not a raycast.
  Leading a moving tourist is the skill expression.
- Splats stick to surfaces and fade; hit resolution emits an event for scoring.
- Short cooldown; effectively unlimited ammo in v1.

### Scoring (T-009 — defaults tunable)

| Action | Points |
| ------ | ------ |
| Splat a tourist | 100 |
| Splat a car | 30 |
| Consecutive hits without landing | ×1 → ×2 → ×3 … (combo resets on landing) |
| Hit during a fast/low dive | +50% style bonus |
| Eating bread | hunger only, no points |

### The city (T-004)
Procedural street grid: sidewalks, roads with crossing traffic, buildings with
landable flat roofs, benches, lamp posts, trash. Landmarks sprinkled by seed (statue
square, café tables). Bread and tourists spawn from district rules. Same seed each
run in M1 so scores are comparable.

### Tourists & cars (T-007, T-008)
Tourists walk sidewalks in loose groups; splatted (or buzzed at speed) they panic —
run away, yell, shake a fist. Cars come parked along curbs (easy targets) and looping
traffic on roads; getting hit earns a honk. Cars are deliberately the easier, lower-
value target per pillar 3.

## Milestone 1 — vertical slice

Gray-box city (4+ blocks), pigeon with genuinely good flight feel, bread/hunger with
game over, poop with splats, reacting tourists and cars, scoring with combos, and the
title/pause/game-over flow. Placeholder art is acceptable; sound optional but nice.

## Out of scope for M1

Gamepad, settings menu, save system beyond high score, multiple districts, hazards
(hawks, hoses), seagull rivals, objectives/missions, export builds.

## Open questions

- Should eating ever happen mid-air (swoop through a bread trail)?
- Does the pigeon get heavier/slower after big meals? (Comedic physics opportunity.)
- Boost: keep Shift, or double-tap flap instead?
- Music: looping cheerful track versus ambient city only?

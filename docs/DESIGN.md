# Pigeon Simulator — Game Design

Last updated: 2026-10-01 (post-M1; sweep phase in flight, M2 direction proposed)

## Pitch

You are a pigeon in a sunny low-poly city. Eat bread to survive; earn points by
pooping on tourists and their cars. Fly well, eat regularly, be a menace.

## Where we are (2026-10-01)

M1 — the vertical slice described below — landed 2026-09-29 (T-001..T-020, all
gates green). Since then the project is in a polish sweep (readability, flight
feel, performance) run as agent waves; the schedule and phase goals live in
[`ROADMAP.md`](ROADMAP.md). The next milestone — a town-vs-visitors goal layer —
is proposed but not yet locked; see "Milestone 2" below.

## Decisions (locked 2026-09-28)

| Topic | Decision |
| ----- | -------- |
| Art style | Low-poly, bright & cartoonish (CC0 packs where possible) |
| Structure | Endless score attack: one living city, run ends on starvation |
| Fail state | Hunger at zero → game over → score screen → restart |
| City | Procedural street grid, landmark features sprinkled by seed |
| Platform | Windows desktop, keyboard + mouse first (gamepad later) |
| Tone | Comedic, family-friendly |

Added since the lock:

| Topic | Decision |
| ----- | -------- |
| Audio | Boots muted; sound opts in per session (T-101) |
| Run structure | "Endless score attack" above is re-opened for M2 — game-day arc proposal, see Milestone 2 |

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

## Milestone 2 — the town's pigeon (proposed 2026-10-01 — not locked, not ticketed)

Direction from the 2026-10-01 design session. The open forks at the end are the
user's to settle before anything is ticketed; leans are recorded, not decided.

**Pitch extension:** the town is yours. The locals know you and feed you; the
visiting fans don't, and get what's coming. Be a good bird to your town.

### The goal layer

One readable town axis — how the locals feel about you versus how infested the
town is with visitors — plus the game-day calendar. No quest log, no mission
arrows, no NPC schedules: you're a pigeon, not an errand runner. The arc (quiet
Friday → tailgate morning → kickoff flood → postgame exodus) is the campaign;
escalation comes from the calendar, not from objectives.

### Locals vs visitors

- **Locals** (cardinal and gold): elders, dog walkers, café sitters, joggers.
  Hitting one costs you — exactly how is an open fork below.
- **Visiting fans** (black and gold, foam fingers, coolers, chants): the prime
  targets, on foot and especially in their cars. The existing easy/low-value
  car split becomes "visitor cars are the jackpot, local cars are friendly
  fire."
- Target discrimination at flight speed is the new skill leg: it deepens
  pillar 3 (cheap vs good points becomes safe vs risky vs wrong) and gives the
  elders a reason to exist.

### Elders

Extends landed T-020 (elders share bread) toward T-078's trust meter: earned
trust unlocks better bread spots and gossip — a pointed wing at where the
rowdiest fans are gathering. Depth is an open fork (anonymous class, one named
bench regular, or several named characters).

### Setting — Ames, Iowa, lightly fictionalized

Real town, real rivalry spirit, invented teams. No real school names, logos, or
mascots anywhere — colors and behavior carry the joke (anyone from Iowa reads
"black and gold flooding a college town" instantly). Tone stays locked on
comedic, family-friendly: the visitors are a goofy nuisance, not a hated enemy.

**Scope guardrail (user, 2026-10-01):** if a proposal starts needing dialogue
trees, NPC schedules, or quest machinery — stop, it's gone too crazy. It's a
silly game about a bird pooping on people.

### Proposed pillar

4. **It's your town.** The city remembers: locals warm to a good pigeon, and a
   defended town shows it. (Joins the locked three above only when M2 locks.)

### Carryover from the old M2 sketch

Folds in where it serves the spine: hawk hazard, seagull bread rivals
(competing at the tailgates), districts as campus / main-street / tailgate-lot
palettes, landmark bonus targets, gamepad, settings, export builds.
Objectives & missions stay out — the calendar is the campaign.

### Open forks (user to decide)

1. **Run shape:** game-day arc as the run (lean — it gives the comedy a stage
   and an ending beat, and re-opens the locked "endless" decision) vs endless
   runs with town mood in the background vs mood persisting across runs.
2. **Elder depth:** one class trust meter plus one named bench regular (lean)
   vs anonymous class only vs several named characters with arcs.
3. **Naming:** real Ames with fictional teams (lean) vs fully fictional
   college town vs real teams too.
4. **Friendly fire:** mood hit, repairable by gifting bread to the splatted
   local (lean) vs soft score penalty only vs sharp per-run trust reset.

## Out of scope for M1

Gamepad, settings menu, save system beyond high score, multiple districts, hazards
(hawks, hoses), seagull rivals, objectives/missions, export builds.

## Open questions

- Should eating ever happen mid-air (swoop through a bread trail)?
- Does the pigeon get heavier/slower after big meals? (Comedic physics opportunity.)
- Boost: keep Shift, or double-tap flap instead?
- Music: looping cheerful track versus ambient city only?

The four M2 forks (run shape, elder depth, naming, friendly fire) live in the
Milestone 2 section above — settle those before any M2 ticket is forged.

# Ideas — improvement brainstorm (living doc)

Born 2026-10-15 from an owner+agent brainstorm. This doc is the feed for future
tickets: pitches get tree-grounded and refined here first, the owner picks a
direction per fork (decision log at the bottom), then an item graduates to
`docs/tickets/` (next free number: **T-121**) through the usual loop — forge
sign-off when real-world references are needed, then pipeline or direct per the
routing notes on each item.

Every "grounded today" line was verified against the tree on 2026-10-15
(post-T-119). The tone guardrail applies to everything below
([DESIGN.md](DESIGN.md) — "if a proposal starts needing dialogue trees, NPC
schedules, or quest machinery — stop, it's gone too crazy").

## Economy snapshot (the numbers every gameplay idea must respect)

| Dial | Value | Where |
| ---- | ----- | ----- |
| Score | pedestrian 100 · car 30, class-blind | `scripts/game.gd:28` |
| Favor | visitor +3 · visitor car +6 · civilian −1/−2 · superfan −8 · table steal −1 · tailgate crumb +1 | `scripts/game.gd:41-50` |
| Win | favor 100 = town taken, run ends | `scripts/game.gd:41`, `scripts/main.gd:596` |
| Bread | 2 favor/crumb, crumb restores 30 hunger, 40 crumbs city-wide, 90% on tables | `scripts/game.gd:49`, `scripts/bread_spawner.gd:43` |
| Hunger | 0.45/s drain, flap ×2, grounded ×0.6 | `scripts/hunger.gd:25-31` |
| Combo | 20 s window, uncapped, style bonus +50% | `scripts/game.gd:31-39` |
| Classes | civilian / visitor / superfan, color-coded uniforms, fixed at spawn | `scripts/citizen_class.gd`, `scripts/tourist_spawner.gd:114` |

Two M2 decisions that ideas below would consciously re-open (owner's call —
fine, but making it explicit):

- **Cars are the favor jackpot** (+6 vs +3 on foot) — decided in T-114 ("cars
  carry favor"). B-6 flips the emphasis back to pedestrians.
- **Visitors never retaliate** — they're "a goofy nuisance, not a hated enemy"
  (DESIGN tone rules). The hawk/seagull candidates (B-13) sit on DESIGN's
  out-of-scope list that ROADMAP parks as M3 candidates — re-opening needs an
  explicit owner yes.

---

## A. Look & feel

### B-1 · Better-looking pigeon (owner item 1) — refined, needs pick D1

**Pitch:** the bird reads great in stills but motion and materials can carry it
much further.

**Grounded today:** the player bird is the rigged photoreal glb (T-108 static,
T-109 rigged — 6 clips under the unchanged `drive()` contract, scale 2.6 held).
The b1–b6 variant exploration was deleted 2026-10-12 (b6 recoverable from git
history only); the costume lane was stopped by the owner (untracked T-106
draft — out of bounds without say-so).

**Options:**
- **(a) Motion + material polish on the current bird** *(recommended)* —
  blend/transition polish between the existing 6 clips, idle variety (preen,
  pigeon head-bob while waddling), neck iridescence/sheen pass, wingtip/tail
  fan driven on the existing rig during flap and flare.
- **(b) Hold and re-judge** — after B-2 swaps the world's assets, re-judge
  whether the photoreal bird still sits well in a more styled city, THEN pick.
- **(c) Restyle toward the world** — rebuild the bird low-poly/stylized to
  match an asset-swapped city. Most expensive; throws away fought-for work.

**Size & routing:** (a) S–M, direct-loop (presentation-only); (c) L, forge +
pipeline. **Fork D1:** a / b / c.

### B-2 · Swap in free assets (owner item 2) — refined, needs pick D6

**Pitch:** replace capsule citizens and box cars with free low-poly models;
buildings/props follow.

**Grounded today:** research already done 2026-10-13 — Kenney City Kits +
Car Kit, Quaternius Animated Men/Women + Universal Animation Library (has sit
AND walk clips — elders could finally stand), KayKit City Builder Bits,
Poly Pizza singles; one primary per category, procedural roads stay. Citizens
are color-coded capsules today (uniform color carries the class joke); physics
shapes are a capsule r=0.25×h1.1 (pedestrian) and a 1.9×1.45×4.4 box (car).

**Constraints (the real work):**
- Class readability is color-based — any new model takes a per-class
  tint/material so the civilians-vs-visitors-vs-superfans read stays instant.
- Keep the physics shapes exactly as-is (visual mesh ≠ collision shape) so
  splat difficulty doesn't silently move.
- Web budget: the wasm build is single-threaded Compatibility — stay low-poly,
  small textures; re-verify the web build after each phase.
- License per pack verified at import; every import updates
  `assets/CREDITS.md`.
- Universal Animation Library has death clips — we don't use them; splatted
  people flail, wipe off, and grump. Slapstick only.

**Options:** **(a) pedestrians + cars first**, buildings/props later
*(recommended — biggest visible win, unlocks B-7 elder-stroll animations)*;
**(b) big-bang swap** (all categories one epic ticket — high risk to the web
budget and to splat parity); **(c) buildings/props first** (the world reads
"city" before people read "people"). **Fork D6.**

**Size & routing:** M per phase, direct-loop per phase (presentation-only),
each phase ending with web-build + splat-parity verification.

---

## B. Flight & feel

### B-3 · Slightly improved controls (owner item 3) — needs the owner's "what feels off" (D2)

**Pitch:** the flight model is heavily tuned (T-081/082/083/106/117); "better"
needs a specific complaint. Grounded gaps that could be the target:

- **No boost exists** — `player.gd` has none; DESIGN.md still carries the open
  question "Boost: keep Shift, or double-tap flap instead?". B-5's updrafts are
  a third answer: skip boost, add air sources (no new button, mobile-friendly).
- **No perch/grab** — landing is floor-contact only (`player.gd`); grabbing a
  ledge/sign/statue is its own idea (B-9).
- **No aim aid** — poop inherits full velocity, no spread, pure skill
  (`player.gd:126`); assist options live in B-6.
- **Camera niceties** — look-behind hold, tighter ground/air pivot blend
  (camera is already SpringArm + trauma shake + FOV kick).

**Size & routing:** any *feel* change goes through the pipeline even when tiny
(T-117 rule — bar re-derivations are the risk surface). **Fork D2:** owner
names what feels off (turn/bank, landing, aim, speed range, camera, other).

### B-5 · Updrafts / soaring (owner item 5) — refined

**Pitch:** thermal columns — vent steam, chimney smoke, rooftop AC, the
sun-baked plaza — that lift you when you glide into them. Soaring is the
missing pigeon fantasy, and it's the elegant answer to the dead boost question:
depth without a new button.

**Grounded today:** zero wind/thermal code anywhere; altitude currently costs
flaps and flaps cost double hunger — sustained climb is the most expensive
thing the bird does. Current flight: flap 13 m/s impulse, max speed 36, stall
5.0, glide-trim rate, flare band.

**Design sketch:** `UpdraftZone` Area3D columns with a visible particle cue +
soft whoosh; inside, capped upward acceleration (numbers tuned in-sim); slight
centering drift so riding feels skilled but forgiving. Passive to use —
joystick-friendly for the iPhone build.

**Forks:** cue style; density/placement; whether updrafts also push poop
(default: they shouldn't — keeps splat physics honest and predictable).

**Size & routing:** M, **pipeline** (re-derives feel bars; new Gate 1b
scenarios: climb rate inside a zone, negligible effect outside, hunger math
unchanged).

### B-9 · Perch & verticality (agent addition)

**Pitch:** slow down near a ledge, sign, bench-back, or statue and grab it;
launch off with Space. Completes the pigeon fantasy loop: soar → perch →
splat from a standstill → glide away.

**Grounded today:** landing/perch is floor-contact only; waddle exists, no
grab state.

**Size & routing:** M, **pipeline** (new player states + collision masks).
Synergy: B-4 landmarks (statue perching), B-5 (arrive via updraft).

---

## C. Gameplay & economy

### B-4 · More to do in the city (owner item 4) — needs pick D7

**Pitch:** more ways to earn score/favor that stay ambient — score events, not
quests. DESIGN's unimplemented intent "escalation comes from the calendar" is
related (see B-7e).

**Options (mix-and-match):**
- **(a) Landmark bonus targets** — 2–3 town landmarks (Ames-flavored, invented
  names per tone rules; real-world reference photos fit the owner's photo rule
  since statues/water towers have clear counterparts). One-time big
  score/favor + a perched-photo moment.
- **(b) The birdbath/fountain** — a plaza fountain: drink/bathe for a small
  hunger top-up on a cooldown. A calm spot that's also a vantage.
- **(c) Windshield-artist combo** — re-splat the same car within the combo
  window for escalating bonus. Builds directly on the existing 20 s combo.
- **(d) Crumb variety reskins** — fries/pretzel/donut variants of existing
  bread crumbs. Pure presentation, zero balance risk.
- **(e) Districts** — campus/main-street/tailgate palettes with per-district
  sub-goals. L-sized; flirts with the scope guardrail — only with a very small
  definition of "sub-goal".

**Size & routing:** S–M each for a–d (forge for a — reference images;
direct-loop for b/c/d), L for e. **Fork D7:** which of a–e.

### B-6 · Easier + more important pedestrian splats (owner item 6, and the weighting half of 7) — needs picks D3+D4

**Pitch:** hitting the right pedestrian should be easier to DO and worth MORE
than it is today — currently the car is the jackpot.

**Grounded today:** poop inherits the pigeon's full velocity, no spread; hits
are physics contact (sphere r=0.3 vs capsule r=0.25); panicked pedestrians
sprint 4.2 m/s for 2.6 s, pulling themselves out of the drop zone; reticle
refreshes at 30 Hz (T-110). Favor: visitor +3 on foot, +6 via car (deliberate
M2 decision — flipping it is a conscious re-decision, which is fine).

**"Easier" options:**
- **(a) Predicted-impact shadow** — a small ellipse on the ground where the
  poop will land. Velocity is deterministic, so this is honest aim help and a
  big win on a touchscreen.
- **(b) Lead tick** — reticle nudges toward a moving target's velocity.
- **(c) Bigger contact sphere** — e.g. 0.3 → 0.38, invisible forgiveness.
- **(d) Panic tuning** — 4.2 → 3.6 m/s or 2.6 → 2.0 s.

**"More important" options:**
- **(i) Flip the weights** — visitor foot becomes the prime target (e.g. +5
  foot / +4 car; numbers tuned in-sim).
- **(ii) Pedestrian streak multiplier** — keep the car jackpot, but chained
  visitor splats climb harder.
- **(iii) Score-side bump only** — leave favor alone, pedestrian score
  100 → 150.

Any weighting change is one economy pass gated by `sim_test` (favor_max 100 is
value-locked there; the deltas re-derive). HUD changes coordinate with T-120
(touch button readability) so nothing regresses on mobile.

**Size & routing:** S–M, **pipeline**. **Forks D3** (a/b/c/d, multi) and
**D4** (i/ii/iii or leave-as-is).

### B-7 · Difficulty pass (owner item 7) — needs pick D5

**Pitch:** deepen the pressure without adding punishment. Grounded options:

- **(a) Elder stroll** — after a share (plus a beat), an elder stands and
  waddles to another bench; presence zone and trust travel with them. Kills
  bench-camping. Today elders are `StaticBody3D` — they never move, ever
  (`elder.gd:2`) — so this is a real body-type change, and it lands best with
  B-2's walk/sit clips (works capsule-first without them). Sim gate:
  relocation + zone-follow scenario.
- **(c) Sharper traps** — superfan share 0.06/0.05 → 0.08–0.10, or superfans
  linger near tailgates. Pure dial turns.
- **(d) Favor mercy floor** — the cozy option: floor favor at e.g. −20. Debt
  is currently unlimited (`game.gd` `add_favor` has no floor), which is a
  death spiral for a casual phone player after a superfan misread.
- **(e) The calendar** — DESIGN's stated-but-unimplemented escalation: an
  in-game day counter that nudges exactly one dial (visitor density or hunger
  drain). Kept to "a number on the HUD + one dial" or it goes too crazy.
- **(f) Hunger/respawn tightening** — drain 0.45 → 0.5, table respawn 5 → 6 s.
  Cheapest knobs in the game.

**Cozy rule for all of these:** add richness, not punishment — no new fail
states; the win stays reachable one-handed on a phone.

**Size & routing:** S–M per knob, **pipeline** — bundled with B-6's picks into
ONE economy/feel pass so bars re-derive once. **Fork D5:** a/c/d/e/f (multi).

---

## D. Meta & platform

### B-8 · Sound & music pass (agent addition)

**Grounded today:** 7 sfx + 2 ambience loops on SFX/Ambience buses; boots
muted by policy; **no music at all**; no in-game mute toggle; win (favor max)
and starvation endings are currently silent.

**Options:** pigeon coos (idle/waddle/post-splat smug coo); 2–3 alternate
splat/yelp/honk variants to kill repetition; win/lose stingers; a light sunny
music loop; in-game volume/mute (overlaps B-10).

**Size & routing:** S–M, direct-loop. Free audio packs exist (same
research/sources pass as B-2); `CREDITS.md` per import.

### B-10 · Settings + gamepad (ROADMAP parked candidate)

Volume sliders (the buses already exist), camera sensitivity/distance, invert
Y, persisted to config. Gamepad via the input map — which per AGENTS means the
controls tables in README + VERIFICATION update in the same change. Mostly
direct-loop; S–M.

### B-11 · Post-victory moment (agent addition)

**Grounded today:** reaching favor 100 just ends the run (`main.gd:596`).
Options: a short town-celebration beat before results; "keep flying" endless
continuation after the win; or leave as-is. Small, direct-loop, no economy
change. Pairs naturally with B-7e if the calendar ever lands.

### B-12 · First-run nudges (agent addition, deliberately tiny)

Two one-shot contextual hints, dismiss-forever: first hunger dip → "bread,
quick"; first visitor in view → "the black-and-gold pay favor". T-116 fixed
the favor caption's discoverability; this covers the two remaining face-plant
moments. NOT a tutorial system — if it wants a third hint, it goes too crazy.
Direct-loop, S.

### B-13 · Parked — needs an explicit owner re-open (D8)

Hawk hazard and seagull rivals are on DESIGN.md's out-of-scope list (hazards,
rivals) while ROADMAP parks them as M3 candidates — that tension resolves only
by owner decision. Worth knowing if revisited: **the hawk pairs beautifully
with B-5** (sky risk makes thermals meaningful — dive into a plume, hawk loses
you), and a seagull that steals table crumbs gives the chase a silly,
non-mean motivation. Districts (B-4e) and export builds (blocked on the hosted
deploy owner steps) also live here. Silence = stays parked.

---

## Suggested sequencing (dependency-aware, no dates)

1. **Quick wins, direct-loop, any order:** B-8 (sound), B-1a (bird polish),
   B-12 (if wanted).
2. **B-2 phase 1 — pedestrians + cars** (biggest visual win; unlocks
   elder-stroll animation; verify web build + splat parity after).
3. **One combined economy/feel pass (pipeline): B-6 + chosen B-7 knobs** —
   single batch so the sim bars re-derive once.
4. **B-5 updrafts (pipeline)** — then re-judge B-13's hawk with the new sky.
5. **B-4 landmarks** (forge: Ames-flavored reference images) + **B-9 perch**.
6. **Anytime:** B-2 phase 2 (buildings/props), B-10, B-11.

Mobile note: T-120 (readable touch buttons) should land before any HUD-adding
item above — B-6a/b especially.

## Decision log

| # | Fork | Owner pick |
| - | ---- | ---------- |
| D1 | B-1 direction: a polish now / b hold + re-judge / c restyle | — |
| D2 | B-3 scope: what feels off (turn/bank, landing, aim, speed, camera, other) | — |
| D3 | B-6 easier: a impact shadow / b lead tick / c bigger sphere / d panic tune (multi) | — |
| D4 | B-6 weighting: i flip / ii streak / iii score-only / leave as-is | — |
| D5 | B-7 knobs: a elder stroll / c traps / d mercy floor / e calendar / f hunger (multi) | — |
| D6 | B-2 order: a peds+cars first / b big-bang / c buildings first | — |
| D7 | B-4 activities: a landmarks / b birdbath / c windshield combo / d crumb reskins / e districts (multi) | — |
| D8 | B-13: re-open hawk? seagull? | — |

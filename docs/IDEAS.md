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
schedules, or quest machinery — stop, it's gone too crazy"), with one
owner-softened line: quests are no longer blanket-ruled-out (2026-10-16) —
see B-15 for the shape that keeps the machinery ban intact.

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

### B-16 · Make target cars unmistakable (owner report, 2026-10-16)

**Pitch:** "Sometimes a car is just yellow and its wheels are black but it's
not a black/yellow target car." Civilian cars impersonate visitors, and the
real markers are too small to save it.

**Grounded today (the collision, confirmed):** the civilian `BODY_PALETTE`
(`car.gd:23-27`) contains a gold `Color(0.93, 0.78, 0.25)` and a near-black
`Color(0.22, 0.24, 0.26)` — hue-twins of the visitor's `TEAM_GOLD`
(1.0, 0.80, 0.0) and `VISITOR_BLACK` (0.08, 0.08, 0.08). All cars share one
near-black tire material (`car.tscn` `Mat_tire`), so "black wheels"
discriminates nothing. A visitor's actual tells are the raised flag + banner
(`car.gd:115-121`) and the trunk cooler — the cooler sits at bumper height and
vanishes in traffic; the flag is a small box on a pole. From ahead, behind, or
at distance, a gold civilian with black tires IS a false positive. T-113 chose
the class colors from a readability table — the defect is the civilian
palette colliding with them, not the class colors.

**Fix (a) — reserve the combo** *(do regardless)*: drop the gold and
near-black entries from the civilian palette (7 → 5 colors). Pure data, no
class-quota logic touched. The same reservation rule gets written into B-2
phase 1: pedestrian civilian uniforms must not collide with black-and-gold
either.

**Fix (b) — upgrade the true tell** *(pick one)*:
- **(b1) Bigger flag** — taller pole, larger banner so it reads at distance
  and from front/rear. *(Recommended now — S.)*
- **(b2) Roof topper** — a taxi-style roof sign readable from all horizontal
  angles. Natural moment for this is the B-2 car swap (the model gets rebuilt
  anyway). S–M.
- **(b3) Outline/ring shader** on visitor vehicles. M; risks over-triggering
  visual noise.
- **(b4) HUD icons over targets** — M; wait for T-120, and diegetic beats HUD
  per the design pillars ("the city reacts").

**Size & routing:** (a) S, direct-loop — presentation data change; if sim
paint assertions pin the old palette values, updating the pinned values is
mechanical, not a bar re-derivation. Re-check the read from the air after
B-2's car swap. **Fork D11:** which (b).

---

## B. Flight & feel

### B-3 · Controls pass (owner items, concretized 2026-10-16) — D2 partially answered

**Owner asks:** invert pitch up/down; "some amount of mouse control"; at
minimum Mouse1 fires poop so a turn doesn't cost a WASD finger.

- **Mouse1 → poop** — add an `InputEventMouseButton` (button 1) onto the
  existing `poop` action (`project.godot` binds physical F only today). S,
  direct-loop; per AGENTS the README + VERIFICATION controls tables update in
  the same change.
- **Invert pitch** — a persisted `invert_pitch` setting flipping the sign of
  `Input.get_axis("pitch_down", "pitch_up")` (three call sites in `player.gd`
  :302/:459/:564 — flip once in a helper, not per-site). The touch joystick
  feeds the same actions (T-119), so one flip covers mobile too. There is no
  settings UI yet — ship it as B-10's first entry (a `user://settings.cfg` +
  a bare checkbox row) rather than a hidden flag. S.
- **Mouse scope — fork D9:** (a) Mouse1 = poop, nothing else — the stated
  minimum; (b) mouse moves the aim point and poop fires toward it (design
  together with B-6a's predicted-impact shadow if both land — the shadow
  becomes the cursor); (c) mouse steers flight (pitch/yaw follow). (c) is the
  big one: desktop-only flavor, meaningless on touch, and it fights the tuned
  keyboard model (T-117) — only if the owner really wants it, pipeline.

Still open from the original pitch (unchanged): no boost (DESIGN open
question — B-5's updrafts are the elegant answer), no perch/grab (B-9),
camera niceties (look-behind hold, ground/air pivot blend).

**Size & routing:** the two concrete asks are S, direct-loop (input map + sign
flip; no bars move). Any *feel* change beyond them goes through the pipeline
(T-117 rule).

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
  big win on a touchscreen. If D9b (mouse aim) also lands, design them
  together — the shadow is the cursor.
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

### B-14 · Traffic spawns off-screen and drives in (owner idea, 2026-10-16)

**Pitch:** no more cars popping into existence mid-frame: new traffic appears
only off-screen and drives into view, and visible spawn events get rarer
overall.

**Grounded today:** cars spawn on block ring loops and curb spots inside a
30–70 m band around the player (`recycle_radius` 100, `car_spawner.gd:63-70`)
— on a long street sightline (FOV 72–79°) that is on screen. There are TWO pop
sources: initial/recycle placement, and the recycler that teleports cars back
INTO the band once they drift past 100 m (`car_spawner.gd:125-148`) — which
can happen in full view. Traffic is already road-aligned and moving, so an
off-screen placement gate makes "drives into view" happen for free.

**Knobs:**
- Sightline gate on placement (populate AND recycle rejoin): reject points
  inside the camera frustum or within a max-sightline distance.
- Density: `target_moving` 20 → ~14, `target_parked` 16 → ~12. Tests read the
  knob (`sim_test.gd` compares against `spawner.target_moving`), so a default
  change is test-safe; fewer cars = fewer +6 jackpots = mild tightening —
  tune alongside D4 so the two knobs don't fight.
- The BandSpawner recycle-scan cadence is a third dial: slower scans = rarer
  teleports.
- Perf: fewer + farther cars is web-build-friendlier, not worse.

**Watch:** `sim_test.gd` pins population counts in several scenarios
(:5029, :5359, :5391) and the T-007/T-054 recycle acceptance contract
asserts where recycled cars land — a placement gate re-derives those
scenarios even though counts don't move. Give tests an injectable
"spawn anywhere" escape hatch rather than weakening the gate.

**Size & routing:** S–M, **pipeline** (placement-contract scenarios
re-derive).

### B-15 · Quests, pigeon-style (owner softened the guardrail, 2026-10-16)

**Owner steer:** "not sure I 100% want to rule out quests." Recorded here as a
revision of the blanket machinery ban; DESIGN.md's out-of-scope line changes
only when a concrete pitch is signed.

**The tone-check, made concrete:** what made quests scary is the MACHINERY —
dialogue trees, a quest-log UI, NPC schedules, multi-step chains, quest-giver
states. A pigeon-safe version keeps one shape — **ambient bounties**: a
one-liner challenge that appears on its own (no giver, no dialogue), tracked
in ONE HUD line, expiring on its own, paying through the existing score/favor
economy, never chaining. Sketches (invented, silly):

- "Three black-and-gold, one windshield" — splat 3 visitors inside one combo
  window.
- "The bench wants quiet" — buzz the superfans off a plaza bench.
- "Lunch rush" — steal 2 table crumbs before the combo breaks.

**Why this is friendlier than it sounds:** the 20 s combo window already IS an
implicit bounty generator — bounties would mostly NAME what the systems
already do, which is a discoverability win (the T-116 gap) more than new
machinery.

**Open (D10):** want the shape? Which sketches / owner's own? On a yes →
forge-input sign-off on the verbatim bounty list, then pipeline if favor pays
are involved (economy deltas), direct if score-only.

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

### B-10 · Settings menu (ROADMAP parked candidate)

Volume sliders (the buses already exist), camera sensitivity/distance,
`invert_pitch` (B-3's ride-along), persisted to `user://settings.cfg`. The
game has no settings UI today — this is the sliver B-3's invert depends on.
Mostly direct-loop; S–M. Gamepad support split out into B-17.

### B-17 · Xbox controller support (owner ask, 2026-10-17)

**Pitch:** Godot treats Xbox pads as the generic joypad standard, and every
gameplay action already exists by name — this ticket adds joypad events to the
existing `project.godot` actions and makes menus pad-navigable. Bonus
synergy: it's the same joypad system on the web build, so a paired controller
could outrank the touch joystick on the girlfriend's iPhone in Safari (iOS
16.4+ exposes the Gamepad API — worth verifying early).

**Mapping (proposal — veto in chat):**

| Input | Action |
| ----- | ------ |
| Left stick | pitch (Y) + turn (X) — 1:1 with WASD, analog |
| A | flap — and menu confirm / title-screen start |
| RT | poop (X as alternate) |
| Start / Menu | pause (B = back) |
| rumble (optional) | splat + landing thud |

**Grounded notes:**
- The actions are read two ways: buttons (`flap`, `poop`) and
  `Input.get_axis` (pitch, turn — `player.gd:302/459/564`). A stick feeds
  ANALOG strength where the keyboard always gives ±1.0 — half deflection
  trims pitch/turn rates in live play. Sim bars stay untouched (the harness
  injects actions at full strength), but the feel pass is real.
- Deadzones: the actions sit at Godot's default 0.5 — too heavy for sticks;
  drop to ~0.25 per action.
- Menus need Control focus + dpad/stick navigation: pad-start on the title
  screen, pause-menu traversal.
- Per AGENTS: the controls tables in README + VERIFICATION update in the same
  change, plus a new Gate 3 line — "owner plays a run on a controller" (and
  an iPhone-Safari line if the web path matters).
- No boost exists (B-3), and the camera is auto-chase, so the right stick
  stays free.

**Size & routing:** M, **pipeline** (input-path feel; the owner controller
pass is the mandatory Gate 3).

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

1. **Quick wins, direct-loop, any order:** B-3's Mouse1 poop binding, B-16's
   palette fix (a) + flag bump (b1), B-8 (sound), B-1a (bird polish), B-12
   (if wanted). B-3's invert pitch rides in with B-10's first settings entry.
2. **B-2 phase 1 — pedestrians + cars** (biggest visual win; unlocks
   elder-stroll animation; verify web build + splat parity after).
3. **One combined economy/feel pass (pipeline): B-6 + chosen B-7 knobs** —
   single batch so the sim bars re-derive once.
4. **B-5 updrafts (pipeline)** — then re-judge B-13's hawk with the new sky.
5. **B-4 landmarks** (forge: Ames-flavored reference images) + **B-9 perch**.
6. **Anytime:** B-14 traffic spawn gate (pipeline), B-17 controller support
   (pipeline), B-2 phase 2 (buildings/props), B-10, B-11, B-15 (after D10).

Mobile note: T-120 (readable touch buttons) should land before any HUD-adding
item above — B-6a/b especially.

## Decision log

| # | Fork | Owner pick |
| - | ---- | ---------- |
| D1 | B-1 direction: a polish now / b hold + re-judge / c restyle | — |
| D2 | B-3 scope: **partially answered 2026-10-16** — invert pitch + Mouse1 poop are IN; remaining scope is the mouse (D9) | invert + Mouse1 in |
| D9 | B-3 mouse scope: a poop-only / b mouse aim / c mouse steering | — |
| D10 | B-15 quests: want the ambient-bounty shape? which sketches? | ban softened 2026-10-16; shape undecided |
| D11 | B-16 true-tell upgrade: b1 bigger flag / b2 roof topper / b3 outline / b4 HUD icons / none | recommendation: b1 now, b2 at the B-2 swap |
| D3 | B-6 easier: a impact shadow / b lead tick / c bigger sphere / d panic tune (multi) | — |
| D4 | B-6 weighting: i flip / ii streak / iii score-only / leave as-is | — |
| D5 | B-7 knobs: a elder stroll / c traps / d mercy floor / e calendar / f hunger (multi) | — |
| D6 | B-2 order: a peds+cars first / b big-bang / c buildings first | — |
| D7 | B-4 activities: a landmarks / b birdbath / c windshield combo / d crumb reskins / e districts (multi) | — |
| D8 | B-13: re-open hawk? seagull? | — |

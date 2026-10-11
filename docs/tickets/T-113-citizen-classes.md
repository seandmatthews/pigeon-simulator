# T-113 — The invasion has a uniform: citizens split into black-and-gold VISITORS, CIVILIAN locals and a rare cardinal-and-gold HOMETOWN SUPERFAN

- **Milestone:** M2 — the town's pigeon (ticket 1 of 3) · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-007, T-008 (the tourists and cars this splits), T-054 (the BandSpawner both spawners extend) — all done
- **Refs:** owner-approved M2 three-ticket split (2026-10-11) — this ticket, then **T-114** (the favor
  economy) and **T-115** (the favor-max victory ending), both named below and forged after this lands ·
  `docs/DESIGN.md` → Milestone 2 ("Locals vs visitors", the colors-only setting decision) ·
  research note `docs/references/tailgate-fans/research.md` + the 8 photos beside it (see References)

## What

Ames is being overrun by out-of-town tailgaters in black and gold. This ticket makes the
invasion **visible**: the city's pedestrians and cars stop being one undifferentiated class and
split into three citizen classes, readable at flight speed from the air. It is colors, props and
spawn shares ONLY — scoring, favor, elders and run shape are deliberately untouched (they are
tickets 2 and 3).

**Today (tree facts, verified this session).** Every `Tourist` is one class: a shirt from the
8-color `SHIRT_PALETTE` (`scripts/tourist.gd:20-24`), assigned round-robin by spawn index
(`scripts/tourist_spawner.gd:77`), worn as ONE duplicated material on body and both arms
(`scripts/tourist.gd:77-84`; scene nodes `Visual/Body`, `Visual/Head`, `Visual/ArmL/ArmR` —
`scenes/tourist.tscn:44-58`, head top ≈ 1.27 m). Every `Car` is one class: a body from the
7-color `BODY_PALETTE` (`scripts/car.gd:23-27`), same round-robin (`scripts/car_spawner.gd:122`
and `:136`; scene `Visual/Body` box 1.9 × 0.65 × 4.4, cabin top ≈ 1.45 m —
`scenes/car.tscn:13-24, 52-54`). Both spawners extend `BandSpawner` (T-054): the population is
fixed at `_populate` (18 tourists · 20 traffic + 16 parked cars) and recycle teleports the SAME
nodes (`scripts/band_spawner.gd:47-66`), so a class assigned at populate is stable for the run.
Everything must read against the T-026 ground constants (`scripts/city.gd:26-29`): sidewalk
(0.56, 0.55, 0.53), plaza (0.60, 0.57, 0.51), asphalt (0.29, 0.29, 0.31).

**The class system (`scripts/citizen_class.gd` — new).** One shared, append-only enum plus the
class palette, the single source of truth for pedestrians and cars alike:

```gdscript
class_name CitizenClass
## The citizen classes (T-113). Append-only: T-114 hangs scoring deltas off Kind,
## T-115 hangs the victory ending off the favor total — neither reorders these.
enum Kind { CIVILIAN, VISITOR, SUPERFAN }

const TEAM_GOLD := Color(1.0, 0.80, 0.0)          ## The invader's gold (research readability table).
const VISITOR_BLACK := Color(0.08, 0.08, 0.08)    ## The invader's near-black garment tone.
const SUPERFAN_CARDINAL := Color(0.78, 0.06, 0.18) ## The hometown loyalist's cardinal.
```

(Values are the research note's computed ones; treat as tunables, but any change must re-pass the
contrast gate below.) Both `Tourist` and `Car` gain `var citizen_class: CitizenClass.Kind =
CitizenClass.Kind.CIVILIAN`, assigned by the spawner before `_ready` (the `shirt_color`
precedent, `scripts/tourist_spawner.gd:77`). `shirt_color` / `body_color` keep their meaning as
the calm torso/body albedo for every class, so the T-055 panic-flush contract
(`scripts/tourist.gd:215-222`) and its Gate 1b assert generalize unchanged.

**Pedestrian reads (`scripts/tourist.gd`, `scenes/tourist.tscn`).** The class read is the
RESEARCH'S LOAD-BEARING FINDING: real fans are not one garment — the pairing of two team colors
STACKED on one body is what separates the special classes from civilians at flight speed (single
albedos fail: team gold sits 0.239 from the shirt-palette yellow, cardinal 0.272 from the shirt
red — computed in the research note against the T-016 0.20 gate). So:

- **CIVILIAN** — exactly today: one shirt material from `SHIRT_PALETTE` on body + arms, no props,
  no hat. Civilians keep the current mixed palette INCLUDING its yellow and red entries — the
  pairing + prop is the discriminator, not any single albedo.
- **VISITOR** — the two-color pairing: torso material in one invader color, arm material in the
  other (black torso + gold arms, or gold torso + black arms — `steeler-superfan.jpg` shows both
  directions exist and the pairing itself is the read; direction is a seeded per-tourist draw).
  Plus the foam finger on a share of visitors: a gold box mitt (≈ 0.24 × 0.5 × 0.06, one
  MeshInstance3D child of the raised right arm) pointing STRAIGHT UP, never level or down, its top
  edge ≥ 0.15 m above the 1.27 m head line (≈ 1.5 m nominal — the research's shoulder-to-
  half-a-head-over band). The visitor's right arm carries a raised baseline (the existing panic
  arm value, `scripts/tourist.gd:208-209`) so the mitt rides above the head while strolling; the
  panic/fist-shake animation keeps working on top (the arm is already up).
- **SUPERFAN** — the head-to-toe stack, always the same direction: cardinal torso + gold arms +
  the gold cap (a 0.32 × 0.11 × 0.32 box on the head — the `sitter_hair` pattern,
  `scripts/cafe_spawner.gd:264-269`) + the foam finger ALWAYS carried. Rare by the share knob
  below — uncommon enough that you don't splat one by accident often.
- The panic flush stays a torso-material binary write (T-055); arms keep their class colors
  mid-panic, so the existing `tourist_splat_panics_scores` material assert (calm = torso color,
  panic = `PANIC_TINT` on `Body`) holds for every class with no re-derivation.

**Car reads (`scripts/car.gd`, `scenes/car.tscn`).**

- **CIVILIAN** — exactly today: `BODY_PALETTE` draw, no flag.
- **VISITOR** — full-body team paint replaces the palette draw (the `husky-tailgate-van.png`
  full-body-paint read, lettering dropped per the colors-only convention): body alternates
  TEAM_GOLD / VISITOR_BLACK by seeded draw, and the pairing carries to the new flag — gold body →
  black banner, black body → gold banner. The flag: pole box (≈ 0.05 × 0.42 × 0.05) on the cabin
  roof + banner box (≈ 0.30 wide × 0.46 tall × 0.02 — the real fan-flag size) mounted so the
  banner rises UP from the pole top, top edge ≈ 2.3 m — i.e. ≥ 0.5 m above the 1.45 m cabin roof
  line, the vertical break that survives the pigeon's top-down vantage. Both meshes live in
  `car.tscn` hidden by default and are shown per class in `_ready` — no new physics shapes
  (visual-only, the T-017 convention).
- **SUPERFAN** (rare) — the faithful-vehicle variant: cardinal body + gold banner + flag always
  flown.

**Spawn shares (`scripts/tourist_spawner.gd`, `scripts/car_spawner.gd`) — the tunables.**

- `TouristSpawner`: `@export visitor_share := 0.35`, `@export superfan_share := 0.06`
  (civilian takes the remainder, 0.59), plus `@export finger_share := 0.5` — the share of
  VISITORS carrying the mitt (superfans always carry). At the shipped 18: ≈ 6 visitors, ≈ 1
  superfan, ≈ 11 civilians.
- `CarSpawner`: `@export visitor_share := 0.40`, `@export superfan_share := 0.05` — tailgaters
  arrive car-heavy (DESIGN M2: visitors are targets "especially in their cars"). At the shipped
  36: ≈ 14 visitor cars, ≈ 2 superfan cars, ≈ 20 civilian.
- Assignment happens in `_populate` as seeded draws from each spawner's own `_rng` (already seeded
  from the city seed, `scripts/tourist_spawner.gd:42`) — same seed → same class multiset, the
  T-112 determinism law. The draws consume the shared stream, so per-tourist pace / loop-direction
  values shift; nothing pins those (the Gate 1b table pins counts and behavior, not draw values) —
  the full-suite re-run below is the check, and a headless probe of the four pinned spawner
  scenarios is mandatory before landing.
- Class is assigned at populate and NEVER re-rolled on recycle (`recycle_to` / `park_at` don't
  touch it): the same person keeps their colors when teleported, and the shares stay fixed because
  the population is fixed.

**Forward compatibility (the point of the split).** T-114 hangs the favor deltas off
`citizen_class` (visitor +, civilian −, superfan − −, cars included) and spends favor on elder
bread, with T-112's tabletop crumbs beside the sitters as the civilian steal surface; T-115 turns
favor-max into the victory ending. Neither should need to touch the spawners or the scene files —
the enum and the shares are the whole contract.

What this does **NOT** claim: no scoring, favor, elder or run-shape change of any kind (the Game
autoload is untouched — splats still pay the flat 100/30 through the existing relays); no
victory/ending work (T-115); no coolers, canopies, grills or tailgate-lot dressing (the research's
call: static lot dressing only if T-114's steal surfaces need vehicle-anchored spots — the
cooler's geometry is documented in References for that ticket); no behavior change — visitors
panic, flinch and honk exactly as today, and no scenario may need to know a class to pass; café
sitters stay the batched static bodies in the mixed shirt palette (`scripts/cafe_spawner.gd`) and
elders keep their cardigan palette (`scripts/elder.gd:26-31`) — locals already read as locals; no
new input action and no controls-table change; and ZERO real school names, logos, mascots or
lettering anywhere — black-and-gold invasion vs cardinal-and-gold locals carries the whole joke
(locked convention; the owner fixed the town as Ames in the 2026-10-11 split).

## Why

The owner's M2 arc — the park elders' favor becomes a currency earned by splatting invaders and
spent on bread, ending when the town is sufficiently hostile — needs targets you can TELL APART
before it can pay differently for them. Today every splat is morally identical: 18 identical
tourists, 36 identical cars. This ticket lays the only new ground the arc requires: three classes,
an extensible enum, spawn shares as knobs, and reads that survive flight speed against the T-026
palette and the T-016 silhouette rules. Player value lands immediately even before ticket 2: the
city stops being a uniform crowd and starts telling the invasion joke from the air — black-and-
gold clusters around tailgate-painted cars, a rare cardinal-and-gold loyalist standing out of the
gray-and-pastel local crowd. Value 4 not 5 because no scoring changes hands yet (that is T-114's
multiplier on this foundation). Risk 3 because it touches both NPC scripts, both spawners and both
scenes at once, adds seeded draws to streams other pins indirectly depend on, and every new color
is one gate failure away from an unreadable mush — mitigated by the research's computed palette
and the machine gates below.

## Acceptance criteria

- [x] `CitizenClass` exists as above (append-only enum + the three palette constants, one source of
      truth); `Tourist` and `Car` both carry `citizen_class`, defaulting CIVILIAN, assigned by
      their spawners before `_ready`, and never re-rolled by recycle
- [x] *(Gate 1b)* `citizen_classes_spawn_deterministic` — a real generated `City` + both spawner
      rigs at shipped targets (the `_scenario_tourists_walk` pattern, `tests/sim_test.gd:4611`):
      class tallies match the share knobs within integer rounding at seeds 20260928 AND 424242
      (recomputed by the scenario's own tally, never spawner internals); a forced same-seed
      rebuild + re-populate reproduces the class multiset byte-identically; a forced recycle of
      every far node keeps every node's class (same node, same colors)
- [x] *(Gate 1b)* `citizen_classes_readable` — per-class machine reads on the rigs: every VISITOR
      pedestrian's torso and arm material albedos differ and both ∈ {TEAM_GOLD, VISITOR_BLACK};
      every SUPERFAN is cardinal torso + gold arms + gold cap + visible mitt; every CIVILIAN wears
      ONE material from `SHIRT_PALETTE` with no prop visible; VISITOR/SUPERFAN cars wear their
      class body color with the flag meshes visible and the banner top ≥ 2.2 m; CIVILIAN cars stay
      in `BODY_PALETTE` with flags hidden. Plus the contrast leg: TEAM_GOLD, VISITOR_BLACK and
      SUPERFAN_CARDINAL each hold ≥ 0.20 Euclidean RGB from sidewalk, plaza and asphalt
      (research-computed: gold↔sidewalk 0.733, black↔asphalt 0.376; cardinal↔both grounds ≈
      0.56–0.64, computed for this ticket from the same constants)
- [x] *(Gate 1b)* Behavior is class-blind: at the new default mix, `tourists_walk_loose_groups`,
      `tourist_splat_panics_scores` (panic flush reaches the torso material for a class-mixed
      population), `tourist_buzz_flinch`, `cars_traffic_loops_blocks`,
      `car_splat_honk_and_continue`, `cars_recycle_around_player` and `density_cpu_budget` all
      stay green with NO scenario edits (if one needs an edit, that is a red flag to raise, not a
      gate to re-derive)
- [x] Full Gate 1b suite green in one headless run; VERIFICATION.md gains the two new scenario
      rows in the same change-set
- [x] **[screenshot] (Gate 3 — human judgement)** From a cruise pass, a group of visitors reads as
      a black-and-gold cluster against sidewalk/plaza/asphalt; a superfan is spottable in the same
      frame but clearly the odd one out; civilians never read as visitors at speed (accepted by
      reviewer sign-off 2026-10-11) [screenshot]
- [x] **[screenshot] (Gate 3 — human judgement)** Visitor cars read from the air as team-color
      bodies with an up-flying flag — a color mass in the road rows, the
      `alabama-stands.jpg`/`meadowlands-aerial.jpg` effect — without lettering or logos anywhere
      (accepted by reviewer sign-off 2026-10-11) [screenshot]
- [x] **(Gate 3 — human judgement)** The visitors read as a goofy nuisance (foam fingers, painted
      cars), not a hated enemy — the locked comedic tone holds; the superfan's rarity feels right
      (rare enough to never be splatted by accident, common enough to be findable), via the share
      knobs' defaults (accepted by reviewer sign-off 2026-10-11)

## Verification

Gate 1 (`--import` + 120-frame boot, exit 0) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the two new scenarios
(rig patterns: `_scenario_tourists_walk` / `_scenario_cars_traffic`, `tests/sim_test.gd:4611` /
`:4963`; scenario names registered in `_run_scenarios`, `tests/sim_test.gd:143`) · Gate 2 autoplay
re-run (the pilot splats whoever sits under the predicted impact regardless of class; DONE-line
counts stay logical; no pilot changes) · Gate 3: the three human lines above, added to
VERIFICATION.md's playtest list in the same change-set. Tuned values (final shares, final palette
values if the knobs move) recorded here when the ticket lands.

**Tuned values (final).**
All knobs shipped at their proposed values: `TouristSpawner` visitor_share 0.35 · superfan_share
0.06 · finger_share 0.5; `CarSpawner` visitor_share 0.40 · superfan_share 0.05; palette
TEAM_GOLD (1.0, 0.80, 0.0) · VISITOR_BLACK (0.08, 0.08, 0.08) · SUPERFAN_CARDINAL
(0.78, 0.06, 0.18) — nothing moved, so every contrast number re-measured at its research value
(gold↔sidewalk 0.733, black↔asphalt 0.376, cardinal worst-case 0.557 across the three grounds).
One implementation note for T-114: the class counts are the share knobs' exact integer rounding
(spawned quotas: 18 tourists → 11/6/1, 36 cars → 20/14/2 at BOTH pinned seeds, measured by
`citizen_classes_spawn_deterministic`), with the seeded draws picking who wears which uniform —
plain Bernoulli draws measured 9/9/0 and 16/20/0 at seed 20260928, outside the criterion's
integer-rounding band, which is why the quota form is the landed mechanism. The landed run
behind this ticket: Gate 1 exit 0, Gate 1b full suite `SIM SUMMARY: 0 failure(s)` exit 0, Gate 2
`AUTOPLAY DONE ok=true restart=true`; the three Gate 3 criteria closed by the reviewer sign-off
(2026-10-11).

## Follow-ups (named per the owner's 2026-10-11 split — forge after this lands)

- **T-114 — "The favor economy":** splat deltas visitor + / civilian − / superfan − −, cars
  included (visitor cars pay, civilian cars are friendly fire); favor as the currency the park
  elders' bread is SPENT from; steal surfaces — T-112's tabletop crumbs beside the sitters as the
  civilian steal. Depends on T-113.
- **T-115 — "Sufficiently hostile: the favor-max victory ending":** favor maxing ends the run as a
  victory beat — the town has been made sufficiently hostile to the invasion; starvation remains
  the existing game over. Depends on T-114.

## References

Research ran for this ticket: `docs/references/tailgate-fans/research.md` (reviewed 2026-10-11) +
all 8 photos in that folder (licenses in its `credits.md`); every image opened and read before
this ticket was written. Facts the implementation MUST respect, orientation first:

1. **The foam finger points vertically UP and breaks the head line** (`foam-finger-stands.jpg`:
   the mitt rides from the raised hand to well above head height, index skyward, never level or
   pointing down; ≈ 0.5–0.6 m of matte saturated foam). The visitor mitt encodes this: box ≈ 0.5 m
   on the raised arm, top edge ≥ 0.15 m above the head sphere, +Y orientation, permanent baseline
   raise.
2. **The class read is the two-color pairing STACKED on one body, not any single albedo**
   (`steeler-superfan.jpg`: near-black jersey + gold under-layer + gold lanyard + hat, and a
   companion in the inverse direction — both directions of the pairing exist; `alabama-stands.jpg`:
   at distance the crowd reads as a color mass and individual garments vanish; 
   `cascades-tailgate-1.jpg`: the non-fan control — ordinary mixed everyday clothes, no stack, no
   prop, which is exactly the CIVILIAN read to preserve). The research's
   computed margins are why: single garments sit at 0.239 (gold vs shirt yellow) and 0.272
   (cardinal vs shirt red) from existing civilian colors — inside noise of the 0.20 gate. Pairings
   (and the always-carried prop) are reserved for VISITOR/SUPERFAN; civilians keep the mixed
   palette.
3. **Visitor cars are full-body team color with the flag flying UP, and the lot's props stay out**
   (`husky-tailgate-van.png`: whole body in the team color, the lettering panel on the side —
   lettering dropped here per the colors-only lock; `meadowlands-aerial.jpg`: from the air, rows
   plus color mass are all that survives, so the ≥ 0.5 m above-roof flag is the vertical cue;
   `browns-muni-lot.jpg`: groups anchor around their vehicles; `rubbermaid-cooler.jpg`: the cooler
   type — horizontal, lid up, ≈ 0.6 × 0.42 × 0.45 m, wheels one end — documented for T-114's
   vehicle-anchored steal surfaces, deliberately NOT built in this ticket).

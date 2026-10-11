# T-114 — The favor economy: visitor splats earn the elders' favor, local blood and stolen crumbs spend it, and elder bread is bought with it

- **Milestone:** M2 — the town's pigeon (ticket 2 of 3) · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-113 (the citizen classes this pays out on), T-020 (the elder share path the gate rides), T-112 (the tabletop crumbs that become the civilian steal surface), T-009 (the Game autoload score table the meter sits beside) — all done
- **Refs:** owner-locked decisions (2026-10-11): per-class favor deltas with cars included · favor is SPENT on elder bread, not threshold-gated · stealing civilians' bread costs a little, stealing visitors' earns a little · the per-elder trust system and the T-078 arm stay UNTOUCHED, favor layered on top · `docs/DESIGN.md` → Milestone 2 · T-113's Follow-ups section (this ticket named) · **T-115** (the favor-max victory ending) is the named successor and reads the total this ticket exposes

## What

T-113 made the invasion visible; this ticket makes it matter. The park elders back your
cause: their **favor** becomes a per-run currency, earned by splatting black-and-gold
visitors, spent on the bread they share, and nicked by every local you hit or rob. It is a
meter, a delta table and a spend path — no quest machinery, no NPC schedules, no behavior
change of any kind; the visitors stay a goofy nuisance.

**References do not apply here:** favor is a game-invented affordance with no real-world
counterpart to photograph (like T-111's globe), so every criterion below is derived from
repo constants and landed machinery instead.

**Today (tree facts, verified this session).** Every resolved splat flows one path:
`Tourist.on_splatted`/`Car.on_splatted` emit `splatted` (`scripts/tourist.gd:144-153`,
`scripts/car.gd:193-195`), the spawners relay (`car_splatted` / `tourist_splatted`), and
`Main._on_tourist_splatted`/`_on_car_splatted` call `Game.add_tourist_hit` /
`Game.add_car_hit` (`scripts/main.gd:464-467`, `:473-476` → `scripts/game.gd:121-129`) —
both handlers receive the typed node, and since T-113 it carries `citizen_class`
(`scripts/tourist.gd:63`, `scripts/car.gd:53`). Score pays the flat 100/30 table
(`scripts/game.gd:17-19`) through `_register_hit`. Elders share free: trust fills at 1.0/s
with a grounded pigeon present, and `_trust >= trust_needed and _cooldown_left <= 0.0`
fires `_share()` — two ordinary crumbs tossed via `BreadSpawner.drop_crumb`
(`scripts/elder.gd:95`, `:124-145`, `crumbs_per_share` 2 at `:44`). Crumbs carry no
ownership: `BreadCrumb` has `restore` and `spot_index` only (`scripts/bread_crumb.gd:13`,
`:18`), and eating flows `eaten` → `BreadSpawner.crumb_eaten` → `Main` wires
`Game.hunger.eat` (`scripts/main.gd:138`). The city's crumb kinds are GROUND / TABLE / ROOF
(`City.BreadKind`, `scripts/city.gd:308`; TABLE = one tabletop spot per awninged building
beside its sitter, `scripts/city.gd:1090` + the T-112 spot law). Parked cars are classed by
quota: `_begin_class_quota(target_parked)` lands exactly `roundi(16 · visitor_share)` = 6
VISITOR and 1 SUPERFAN parked cars at the shipped knobs, every seed
(`scripts/car_spawner.gd:83`, `:186-193`).

**The favor book (`scripts/game.gd` — beside the score table).** One int, one signal, one
delta table, all `@export` tunables:

```gdscript
signal favor_changed(favor: int, delta: int)

@export_group("Favor (T-114)")
@export var favor_visitor_splat: int = 3      ## Splatting a VISITOR pedestrian.
@export var favor_visitor_car_splat: int = 6  ## The jackpot — a visitor vehicle.
@export var favor_civilian_splat: int = -1    ## Friendly fire on a local pedestrian.
@export var favor_civilian_car_splat: int = -2 ## Friendly fire on a local car.
@export var favor_superfan_splat: int = -8    ## The rare loyalist — costs a lot, pedestrian or car.
@export var favor_steal_table: int = -1       ## Stealing a café tabletop crumb (civilians' bread).
@export var favor_steal_visitor: int = 1      ## Stealing a tailgate crumb (visitors' bread).
@export var elder_loaf_cost: int = 2          ## Favor per crumb the elders share (a 2-crumb share spends 4).

var favor: int = 0
```

Plus three methods: `add_favor(delta)` (adds, emits `favor_changed(favor, delta)` —
negatives allowed, **no floor and no cap**: a floor would make civilian splats free once
you are broke, and the ceiling is T-115's to define); `splat_favor(kind: CitizenClass.Kind,
vehicle: bool)` (resolves the table above — SUPERFAN pays the same on foot or on wheels);
and `reset_run()` gains `favor = 0` (`scripts/game.gd:152-161` — favor is per-run state,
zeroed with the score). The autoload stays presentation-free (its own contract,
`scripts/game.gd:8-10`): it only books and emits; Main renders.

**The splat hook (`scripts/main.gd`).** One line in each existing handler, beside the score
call: `_on_tourist_splatted` adds `Game.splat_favor(tourist.citizen_class, false)`
(`scripts/main.gd:464-467`), `_on_car_splatted` adds `Game.splat_favor(car.citizen_class,
true)` (`:473-476`). Deliberately a separate call, NOT a changed `add_*_hit` signature —
the harness stages synthetic `Game.add_tourist_hit` calls (the T-060 coach leg,
VERIFICATION.md `coach_hint_shows_until_first_hit`) and those must stay favor-silent.

**The elder gate (`scripts/elder.gd` — the layer, not a rework).** The share condition at
`scripts/elder.gd:95` gains one clause:

```gdscript
if _trust >= trust_needed and _cooldown_left <= 0.0 \
		and Game.favor >= Game.elder_loaf_cost * crumbs_per_share:
	_share()
```

and `_share()` charges `Game.add_favor(-Game.elder_loaf_cost * crumbs_per_share)` once,
placed after the `bread_spawner == null` guard (`scripts/elder.gd:129-132`) so a spawner-less
elder never charges for bread it cannot toss. **The spend happens at the share, not the
eat** — the share IS the purchase (the elders won't hand over bread you can't pay for), and
it is what makes eating elder bread actively delay T-115's victory: every loaf bought is
favor not banked. Trust rates, `trust_needed`, the cooldown, `crumbs_per_share`, the toss
and the **T-078 arm logic stay byte-identical** (the owner lock). One honest consequence,
accepted and named: while broke, a present pigeon still pins trust at `trust_needed`, so
the arm rides full-up with no bread coming — the favor meter is what explains the hold.
Gate 3 judges that read; if it fails, the pre-agreed smallest follow-up is routing the
broke state through the arm's existing cooldown clause ("not now") in its own ticket — NOT
here.

**Bread ownership (`scripts/bread_crumb.gd`, `scripts/bread_spawner.gd`).** `BreadCrumb`
gains `var favor_delta: int = 0`. `BreadSpawner._spawn_at` stamps it from the spot kind
(`scripts/bread_spawner.gd:223-234`): TABLE spots get `Game.favor_steal_table`, GROUND and
ROOF stay 0 (gutter and roof spice are nobody's). `drop_crumb` gains an optional
`favor_delta: int = 0` parameter (`scripts/bread_spawner.gd:214-220`) — elder loaves keep
calling it bare (they are paid for at share time), tailgate drops pass
`Game.favor_steal_visitor`. `_on_crumb_eaten` emits a new `crumb_favor(delta)` when the
delta is non-zero (`:237-241`); `Main` wires `bread_spawner.crumb_favor.connect(Game.add_favor)`
beside the existing eat wiring (`scripts/main.gd:138`) — emit-and-listen, so bare harness
rigs without Main stay inert. The 90/7.5/2.5 class quotas are untouched.

**The visitor steal surface — T-113's deferred tailgate dressing, minimum viable
(`scripts/car_spawner.gd`, `scenes/car.tscn`, `scripts/car.gd`).** Without it the
earn-half of the steal rule is dead content. Every PARKED VISITOR car anchors one
tailgate crumb:

- **The cooler** (`car.tscn`, hidden by default, shown in `Car._ready` when flagged — the
  T-113 flag-mesh pattern, `scripts/car.gd:93-99`): a white body box 0.42 × 0.45 × 0.60
  (`BODY_PALETTE`'s white) + a gold lid strip 0.42 × 0.06 × 0.60 (`CitizenClass.TEAM_GOLD`)
  — T-113's documented cooler geometry (horizontal, lid up, ≈ 0.6 × 0.42 × 0.45 m), axes
  mapped so the long side runs with the car and the child needs translation only. Visual
  only, no collision shapes (the T-017 convention). `Car` gains `has_cooler: bool` +
  `bread_spawner: BreadSpawner` (spawner-assigned, the `elder.bread_spawner` pattern,
  `scripts/elder_spawner.gd:73`); the cooler rides parked AND traffic visitor cars (they
  are transporting their tailgate).
- **The crumb**: parked visitor cars only. One idempotent `Car._redress_crumb()`: free the
  stale crumb if still valid, `drop_crumb(to_global(Vector3(1.4, 0.06, 0.75)),
  Game.favor_steal_visitor)` — 0.45 m off the body's right side at gutter height + the
  0.06 lift, within the grounded eat reach of a pigeon waddling the road edge. Called from
  `park_at` (`scripts/car_spawner.gd:120`, `:156`) so recycles re-anchor the bread, and
  from a deferred `_dress_tailgates()` pass after `_populate` — deferred because
  `BreadSpawner._populate` queue-frees every crumb it knows (`scripts/bread_spawner.gd:107-111`)
  in the same `regenerated` emission, and the pass skips cars whose crumb is still valid, so
  the two paths can never double-drop. `recycle_to` frees the crumb (the car drove off).
  Zero RNG: placement derives from the car's own transform, no draw of any stream, and
  City generation is untouched — no new `bread_spots`, no `_fp` entries, the layout
  fingerprints hold.
- **Count is deterministic**: exactly 6 parked visitors at the shipped quotas
  (`scripts/car_spawner.gd:186-193`) → exactly 6 tailgate crumbs while all 16 parked cars
  place. They are hand-placed (`spot_index` −1), so they shrink the real main scene's
  spawned budget exactly as elder loaves always have: 40 − 6 = 34 → **31 TABLE / 2 GROUND /
  1 ROOF live spread in Main only**. The bare bread rigs (no cars) keep the pinned 36/3/1 —
  `bread_distribution_weighted` is untouched. Eaten tailgate crumbs are not topped up by
  `_top_up` (hand-placed, like elder loaves); they come back when the car next re-parks.

**The HUD readout (`scripts/main.gd`, `scenes/main.tscn`) — game-invented, repo-grounded.**
A `%FavorLabel` in the left column directly under `%ComboNote` (offsets 16/192/500/212 —
no existing offset moves), the column's standard treatment (14 px, outline 4, black-0.85,
white fill — the T-019 convention). Rest text `Favor: <n>` (signed — debt is shown, not
hidden). Every `favor_changed` updates it guarded (the T-055 write-only-on-change rule) and
runs a 2.5 s game-time delta note `Favor: <n>  (<+delta>)` — the combo-note machinery
(`scripts/main.gd:217-221`), frozen by pause like the strip; the note tints the HUD-pulse
gold `Color(1.0, 0.85, 0.3)` for gains (`scripts/main.gd:233`) and the tier-2 red
`Color(1.0, 0.32, 0.25)` for losses (`scripts/main.gd:42`). `restart_run()` resets the
label and kills the note (the `combo_strip` pattern, `scripts/main.gd:537`). No world-space
popup for favor deltas — the score popup's job is score.

What this does **NOT** claim: no score change — the 100/30 flat table, combos and style
bonus are untouched (favor is a separate axis; T-113's class-blind scoring stands); no
behavior change of any kind — visitors panic, civilians walk, cars honk exactly as today,
and nothing reacts to stolen bread (T-112's scope guard holds); no per-elder trust change —
fill/decay rates, `trust_needed`, `share_cooldown`, `crumbs_per_share` and the T-078 arm
are byte-identical outside the one share-condition clause; no T-115 work — no favor cap, no
threshold, no ending, no game-over-screen change; no City generation change — zero new
spots, zero `_fp` entries, zero RNG draws on any stream (the seeded class draws and both
pinned seed multisets are untouched); no new input action and no controls-table change; and
zero real branding — the black-and-gold / cardinal-and-gold convention carries on (the
cooler's gold lid is `CitizenClass.TEAM_GOLD`).

## Why

The owner's locked M2 spine: the elders' favor is a currency earned by splatting invaders
and spent on the bread they share, and T-115 ends a run when the town is sufficiently
hostile. T-113 built the targets; until this lands, splatting a visitor and splatting a
grandchild pay identically — the classes are costume, not consequence. The locked decisions
shape the slice: deltas per class with cars included (visitor cars become the jackpot the
M2 pitch promised, and pillar 3's "cheap vs good points" deepens into safe vs risky vs
wrong); favor SPENT on elder bread rather than a threshold gate, so every loaf you buy is
progress given back and eating actively delays the eventual victory; stealing from
civilians costs a little while robbing visitors earns a little, which turns the already-
shipped tabletop crumbs into a moral choice and gives the parked visitor cars a second
use; and the per-elder trust system untouched, so favor layers one gate onto a proven path
instead of reworking it. Player value lands immediately: the HUD meter makes the town's
memory legible at flight speed, every splat gets a second consequence, and bread stops
being free — the hunger clock now pulls against the favor ledger. Value 4 not 5 because
the payoff (the victory ending) is T-115's; Risk 3 because the change crosses the autoload,
both splat handlers, three spawners, two scenes and the harness's pinned elder scenarios at
once, and the elder gate touches scenarios that pin share counts — mitigated by
delta-via-export asserts, the deferred dressing order, and the machine legs below.

## Acceptance criteria

- [ ] The favor book exists as specified: `Game.favor` int + `favor_changed` + the eight
      `@export` deltas at their defaults, `add_favor`/`splat_favor` as above, `reset_run()`
      zeroes favor, and the autoload books without rendering (no node/HUD reference in
      `game.gd`)
- [ ] Splat deltas pay through the real chain: a real visitor/civilian/superfan tourist and
      a real parked visitor/civilian car, splatted through Main's handlers, move
      `Game.favor` by exactly their exports (asserted against the exports, never literals),
      and a synthetic `Game.add_tourist_hit` (the coach scenario's call) pays NO favor
- [ ] *(Gate 1b)* `splat_favor_follows_citizen_class` — through the REAL main scene (the
      instanced-Main pattern), with `TouristSpawner`/`CarSpawner` share knobs forced to
      single-class rigs (the `citizen_classes_readable` pattern): `Game.reset_run()` first,
      then each relay driven at a real living node — favor reads exactly
      +`favor_visitor_splat`, −`favor_civilian_splat`, −`favor_superfan_splat`,
      +`favor_visitor_car_splat`, −`favor_civilian_car_splat` in turn, cumulative sum
      exact, and a landing between legs proves splat favor never touches the combo
- [ ] *(Gate 1b)* `elder_bread_gates_on_favor` — the elder rig (`_add_elder_rig`,
      `tests/sim_test.gd:2516`): with `Game.favor = 0`, a parked pigeon hangs the full
      `trust_needed` + 5 s margin — trust pins at `trust_needed`, NO share, NO crumbs, NO
      charge; then `Game.add_favor(elder_loaf_cost * crumbs_per_share)` fires the share
      within 3 physics frames (trust is still pinned — the gate was the only blocker), and
      favor reads exactly `elder_loaf_cost * crumbs_per_share` lower afterwards
- [ ] *(Gate 1b)* `bread_steal_favor_deltas` — bare rigs over a real City: eating a live
      TABLE crumb grounded (the tabletop feed path) emits `crumb_favor` with
      `Game.favor_steal_table` and Main-style wiring moves favor by exactly that; a
      `drop_crumb(pos, Game.favor_steal_visitor)` crumb eaten the same way pays
      +`favor_steal_visitor`; a GROUND crumb pays 0 and emits nothing; and on a real
      City + `CarSpawner` rig, the scenario's own tally of living parked VISITOR cars
      (6 at the shipped knobs) equals the tailgate crumb count, each within 1.0 m of its
      car and ≥ 0.45 m off the body, no RNG-stream disturbance (the seeded class multisets
      still byte-identical — the `citizen_classes_spawn_deterministic` asserts re-run green)
- [ ] The three elder scenarios pass with favor staged at setup (`Game.favor` set
      explicitly — they inherit whatever the previous scenario left otherwise), with the
      share scenario additionally asserting the exact spend; every other pinned scenario
      stays green UNTOUCHED, including `bread_distribution_weighted` (36/3/1 — bare rigs
      have no cars) and `crumbs_respawn`
- [ ] *(Gate 1b)* Full suite green in one headless run; VERIFICATION.md gains the three new
      scenario rows in the same change-set, and the elder row's wording notes the favor
      staging; the expected re-derivations (if `hud_bread_pointer_tracks_nearest_crumb`'s
      ring-guarded arms trip on a stray tailgate crumb, extend the T-112 ring-guard
      precedent and record it) are made in this change-set, not waved through
- [ ] The HUD readout: `%FavorLabel` under `%ComboNote` with the column treatment, guarded
      updates, the signed 2.5 s delta note (gold gains / red losses, game-time, pause-
      frozen), `restart_run()` reset — machine-checked through the real main scene by
      driving `Game.add_favor` and reading the label + expiry
- [ ] **[screenshot] (Gate 3 — human judgement)** The readout teaches at flight speed: a
      visitor-car splat jumps the balance with the gold +6 note, a civilian splat shows the
      red −2, a tabletop steal shows −1 — cause and effect readable without a tutorial
- [ ] **(Gate 3 — human judgement)** A broke elder hangout reads as "they're holding out"
      (arm up, no bread, meter at zero) rather than as a bug; if it reads as a bug, the
      pre-named fallback (broke routes through the arm's cooldown clause) is forged as its
      own follow-up ticket, not absorbed here
- [ ] **[screenshot] (Gate 3 — human judgement)** The tailgate steal reads as a cheeky
      heist — a gold-lidded cooler beside a painted visitor car with a crumb at the gutter,
      not buried into a curb, a car, or a café table — and the economy's feel holds: an
      aggressive anti-visitor run trends the meter upward while eating still matters

## Verification

Gate 1 (`--import` + 120-frame boot, exit 0) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the three new
scenarios (rig patterns: the instanced-Main scene for the splat legs, `_add_elder_rig`
`tests/sim_test.gd:2516` for the gate, the `bread_distribution_weighted` /
`crumbs_respawn` spawner-under-test rigs for the steal legs; registered in
`_run_scenarios`, `tests/sim_test.gd:143`) · Gate 2 autoplay re-run — DONE criteria
unchanged; `shares` (reported, never gated, `tests/autoplay.gd:131`) may now honestly read
0 while the pilot is broke, and the eaten count may include tailgate crumbs · Gate 3: the
three human lines above, added to VERIFICATION.md's playtest list in the same change-set.
Tuned values (final deltas, any retunes) recorded here when the ticket lands.

## Follow-ups (named per the owner's 2026-10-11 split)

- **T-115 — "Sufficiently hostile: the favor-max victory ending":** reads the `Game.favor`
  total this ticket exposes, ends the run as a victory beat when the town has been made
  sufficiently hostile; starvation remains the existing game over. Depends on T-114. If the
  Gate 3 broke-elder read fails, its pre-named arm fallback is forged alongside.

# T-112 — Bread belongs at the tables: reweight the crumb spread to ~90% café tabletops, roofs rare

- **Milestone:** Sweep backlog · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-005 (the bread system), T-031 (cafe tables + `City.cafe_spots`),
  T-032 (roof bread spots — the class this demotes) — all done
- **Refs:** owner request (2026-10-10): bread belongs where humans could reasonably be
  eating — above all the sidewalk cafe tables with their two seated tourists, "like
  90%" of the time; rooftop bread is weird and should be "rare spice, not a common
  sight" · `docs/DESIGN.md:68` already promises crumbs "on pavements, benches, café
  tables" — the café-tables half never landed · **scope guard: placement ONLY — no
  new tourist reactions to a pigeon stealing table bread**

## What

**Today (measured for this ticket, headless probe over real `City.generate` runs).**
`BreadSpawner._populate` seeds `_rng` from the city seed, Fisher–Yates-shuffles ALL
`City.bread_spots` indices and spawns on the first `target_count` = 40
(`scripts/bread_spawner.gd:84-89`); `_top_up` replaces eaten crumbs at a uniformly
random free index (`scripts/bread_spawner.gd:96-103`). The pool at the M1 seed is
**683 spots = 392 sidewalk-ring + 141 bench seats + 146 roof + 4 district-anchor cap
crumbs** (per-seed arithmetic re-verified: total == 8·blocks² + benches + buildings +
anchors, and the y>1.0 population == buildings + anchors, at 15 seeds). A uniform
spread puts the roof class (150 spots, 22.0%) at **~8.8 of the 40 live crumbs** —
matching T-032's recorded "9 of the 40 seeded crumbs start on roofs". That permanent
rooftop loaf is what the owner wants gone. Meanwhile the café tabletops — 104 set
dining surfaces with 156 seated eaters — hold **zero** spots: `City.cafe_spots` feeds
only `CafeSpawner` (`scripts/cafe_spawner.gd:122-147`); `bread_spots` has no table
entries at all.

**City side (`scripts/city.gd`) — add the table spots + per-spot kind metadata.**

- New `enum BreadKind { GROUND, TABLE, ROOF }` and a parallel array
  `var bread_spot_kinds: Array[int]`, appended in lockstep with every `bread_spots`
  append — ring + bench seats → GROUND (`scripts/city.gd:509-510`, `:1168`), roof +
  anchor cap → ROOF (`scripts/city.gd:941-944`, `:851`), table tops → TABLE (below);
  cleared beside `bread_spots` in `generate()` (`scripts/city.gd:397`). Zero new RNG
  and zero `_fp` entries — `bread_spots` was never fingerprinted (the T-032 note), so
  the layout fingerprint stays byte-identical and every pinned RNG stream is
  untouched.
- One TABLE spot per awninged building, appended in `_build_cafe_spots`
  (`scripts/city.gd:1046-1049` — the pure-math pass) next to each `cafe_spot`
  append. With `spot := cafe_spot_for(info)`:
  - **y** = `block_slab_height + 0.78` (0.90 city-local): the tabletop's walkable
    face is the merged collider's top at spot + 0.72 (`TABLE_SHAPE_SIZE`
    0.9 × 0.72 × 0.9 at offset (0, 0.36, 0), `scripts/cafe_spawner.gd:24-25`; the
    visual top face coincides — the 0.06 m-thick mesh centered at +0.69,
    `scripts/cafe_spawner.gd:124`) **plus the 0.06 crumb lift — the exact roof/anchor
    spot convention** (`scripts/city.gd:941-944`, `ANCHOR_CRUMB_LIFT`). Never at
    spot-origin ground level.
  - **XZ** = `spot.basis.x * 0.25` — toward the first sitter's side (local +X, where
    `SITTER_SEATS` puts a sitter at ±0.72 on every table, `scripts/cafe_spawner.gd:17`,
    `sitter_count` ≥ 1 always): the crumb sits 0.47 m from that sitter, inside the
    0.9 m top with a 0.20 m margin to the edge (the crumb mesh is
    0.16 × 0.1 × 0.12, `scenes/bread_crumb.tscn`). Fixed sign, zero RNG.

**Spawner side (`scripts/bread_spawner.gd`) — class quotas, same determinism law.**

- Two `@export` shares: `table_share := 0.90`, `roof_share := 0.025`; GROUND takes
  the remainder (0.075 at defaults). Integer quotas each fill, over a budget:
  `budget = target_count − live hand-placed crumbs` (T-020 elder loaves stay OUTSIDE
  the class math — `drop_crumb`, `scripts/bread_spawner.gd:111-117`, untouched),
  `table_quota = roundi(table_share · budget)`, `roof_quota = roundi(roof_share ·
  budget)`, `ground_quota = budget − table_quota − roof_quota` (total stays exact).
  At the shipped target 40 with no elders: **36 tables / 3 ground / 1 roof** — the
  owner's "like 90%" pinned, and roofs cut from ~22% to 2.5% of the live spread.
- `_populate`: same seeded `_rng` (`seed = city.seed_value`), same Fisher–Yates
  `_shuffle` (`scripts/bread_spawner.gd:142-148`) — now applied PER CLASS, in the
  fixed order TABLE, GROUND, ROOF, taking each quota off the shuffled class list.
  The docstring's pinned contract — the same city always opens with the same crumbs —
  holds unchanged in kind.
- `_top_up`: per class in the same order, deficit = quota − live crumbs of that
  class; fill each deficit by drawing uniformly (`_rng.randi_range`) among that
  class's FREE spots. **Overflow rule:** a class whose free spots run out spills its
  deficit to the NEXT class down the order (TABLE → GROUND → ROOF); ROOF is terminal
  and caps at its quota — spill never raises roof-class live crumbs above quota
  ("rare" is a ceiling, not a floor), and a deficit past ROOF is dropped.
- **Overflow is a safety net, not a live path, at the shipped target:** the table
  supply is the awning count (`awning_chance` 0.6, `scripts/city.gd:249`), probed at
  **104 (M1) / 90 / 90 / 83 / 77 / 82 / 71 / 91 / 69 / 76 / 69 / 66 / 75 / 88 / 77**
  across seeds 20260928, 424242, 1, 2, 3, 7, 11, 99, 12345, 777, 20260929, 31337,
  555, 8080, 424243 — minimum 66 ≥ 36. The rule's behavior is pinned machine-side by
  a synthetic-shrink leg (below), not by any natural seed.

**Reachability (why a tabletop spot is a lawful bread spot).** The tabletop is a
solid layer-1 box (0.9 × 0.72 × 0.9) under the player's world mask: a pigeon touching
down settles grounded on the 0.84 m face exactly as on the proven bench
(`bench_landing`) and anchor-cap (2.0 × 0.5) pads. The crumb at face + 0.06 feeds the
standing bird through the ordinary overlap path (eat sphere r = 1.1,
`scenes/bread_crumb.tscn`; the roof crumb's identical 0.24 m stand-off is
machine-proven in `city_roofs_inhabited`). Takeoff passes through the awning above
(underside ≈ 2.98 m) — visual-only by the T-017 decision, accepted.

**Harness blast radius (re-derive IN THIS CHANGE-SET, the T-091 re-pin pattern):**

- `city_roofs_inhabited` pins the city-wide `bread_spots` total exactly
  (`tests/sim_test.gd:3056-3059`): add the `+ _city.cafe_spots.size()` term —
  683 → **787** at M1 (787 = 392 + 141 + 146 + 4 + 104).
- `city_cafe_tables_present`'s `bread_ok` leg (`tests/sim_test.gd:2842-2847`)
  checks every cafe spot against every `bread_spots` entry within
  `block_size * 0.5` = 11.0 m XZ of the spot's nearest block center — no kind
  or height filter — and demands ≥ 1.0 m. T-112 puts each table's own crumb
  spot 0.25 m XZ from its own cafe spot, and the table spots' radial from the
  block center straddles the filter (out-axis 9.04–9.82 m = lot 4.25 +
  footprint·0.5 + 2.02 against the 0.78–1.0 footprint scale, along-face
  6.20–6.70 m with the crumb inset — measured radial 10.96–11.88 m at M1), so
  the leg as written goes RED, not green: a headless probe over real
  `City.generate` runs (run for this ticket) trips **3 of the 104 cafe spots
  at M1 and 4 of 90 at seed 424242** — each trip is the table's OWN crumb at
  0.25 m inside the window (cross-table hits, table j's crumb vs cafe spot
  i ≠ j: 0 at both seeds). The leg's pool read is AMENDED to skip kind-TABLE
  entries — the clearance it guards is cafe furniture vs pavement bread, and
  a table's own crumb riding 0.25 m from its own spot is the feature, not a
  failure. The skip restores the leg's exact pre-T-112 semantics (same pool,
  same spots): probe-verified min 2.704 m at M1 — T-031's recorded 2.70 — and
  2.626 m at 424242, 0 trips. For the record, the new TABLE spots' own
  clearance to the pre-existing pool inside the window: 2.455 m (M1) /
  2.377 m (424242) — the ≥ 1.0 m bar also holds for the crumbs themselves.
- `city_park_trees_present`'s "tree ≥ 2.0 m XZ from every `bread_spots` entry" leg
  (`tests/sim_test.gd:3691`, comment `:3589`) and `city_district_anchors_present`'s
  "nothing but the anchor's own crumb within 5 m XZ" leg
  (`tests/sim_test.gd:4187-4194`) now also iterate table spots — measured green
  (same probe): worst park-tree-to-TABLE-spot distance 17.39 m at M1 / 20.78 m at
  424242 (bar 2.0 m; park blocks grow no buildings, so no table is ever near a
  tree), worst anchor-to-TABLE-spot 11.04 m / 10.96 m (bar 5.0 m; anchors stand at
  block centers, own-block tables at ~9.8–11.9 m out) — re-run them, don't trust
  the numbers.
- The pointer scenarios' street-spot scans skip `y > 0.3`
  (`tests/sim_test.gd:5795`, `:5943`) — table spots at 0.90 are excluded by design,
  those arms don't move.
- `crumbs_respawn` (target 6, `tests/sim_test.gd:1789-1809`): quotas round to
  5 tables / 1 ground / 0 roofs; its count-only asserts stay green. The roof quota
  rounding to 0 below budget 20 is accepted — pure proportion, no special cases; the
  shipped target is 40.
- Gate 2 autoplay: `_plaza_crumb` only considers crumbs within 13 m flat of the city
  origin (`tests/autoplay.gd:422-435`) — the plaza block has no buildings, hence no
  tables, and the nearest possible table crumb is ≥ ~21 m flat out; the landing-aim
  fallback (plaza center) already exists. The grounded waddle homing (22 m,
  `tests/autoplay.gd:31, 476-480`) can now aim at a tabletop crumb across a road,
  but the waddle phase is time-boxed (`WADDLE_UNTIL` 28.6, `tests/autoplay.gd:22`) —
  the T-032 precedent (roof crumbs never dragged the plaza-bound visit). Re-run
  required; criteria unchanged.

What this does **NOT** claim: no sitter/tourist reaction to table bread being eaten
(sitters stay the static T-031/T-094 batched bodies — the scope guard); no crumb
`restore`, `target_count` or `respawn_interval` change; no new spot sources beyond
the three classes and no fourth class; no mid-air eating; no visual change to tables
or crumbs; T-020's elders untouched — their hand-placed pavement loaves keep
`spot_index = -1`, join `_crumbs` as today, and merely shrink the spawned budget they
always shrank.

## Why

The owner: bread should be where humans could reasonably be eating — above all the
sidewalk café tables with their seated tourists — and rooftop bread is weird, "rare
spice, not a common sight." Today the spawner is blind to surfaces: a uniform shuffle
over the pool keeps ~9 of 40 live crumbs on roofs and anchor caps at all times, so
the city's most visible food sits precisely where no human could ever have left it,
while 104 occupied dining tables hold none. That breaks the world's own logic every
time a player reads the map — and the fix is the cheapest kind: the tables, sitters
and eat path all exist and are machine-pinned; only the weighting is wrong. Player
value: the core loop's geography starts reading — food lives under awnings where the
people are (hunger pulls you to street level, the T-005 rhythm, now with a
destination), and each city keeps exactly one rooftop crumb as spice for the
roof-crawler who checks. Risk 2 because everything is deterministic pure layout +
selection math riding proven patterns (T-031 spot recompute, T-032 crumb convention);
the only delicate part is re-deriving the one pinned harness total.

## Acceptance criteria

- [x] Table-top bread spots exist and are exact: one per awninged building (== 
      `cafe_spots.size()`, 104 at M1), each at `cafe_spot.origin + spot.basis.x *
      0.25 + Vector3(0, 0.78, 0)`, recomputable < 0.01 from the building record, XZ
      inside the 0.9 m top (|local offset| ≤ 0.45 per axis), y =
      `block_slab_height + 0.78`
- [x] `bread_spot_kinds` stays index-aligned with `bread_spots` at every seed and
      the class tally is exact at M1: GROUND 533 (392 ring + 141 bench), ROOF 150
      (146 + 4 anchors), TABLE 104 — total 787; zero new RNG draws and the layout
      fingerprint byte-identical to pre-T-112
- [x] *(Gate 1b)* `bread_distribution_weighted` — on a real generated City + a
      `BreadSpawner` rig (target 40): after `_populate`, live crumbs per class are
      exactly **36 TABLE / 3 GROUND / 1 ROOF** at seeds 20260928 AND 424242; every
      crumb's `global_position` matches its spot's `to_global` (< 0.01); the
      distribution is recomputed through the scenario's own kind array read, never
      through spawner internals
- [x] *(Gate 1b)* Determinism: same seed, force-rebuild + re-populate → identical
      crumb position multiset (byte-identical compare, the `_spots_equal` pattern);
      the city fingerprint pin holds
- [x] *(Gate 1b)* Top-ups follow the same law: emit `eaten` on 10 TABLE crumbs (the
      `crumbs_respawn` path), wait one `respawn_interval` → TABLE back at 36, GROUND
      3, ROOF still 1 — replacements came from table spots
- [x] *(Gate 1b)* Overflow rule: synthetically shrink the city's TABLE class to 10
      free spots (arrays reassigned on the city object, then re-populate) → TABLE 10,
      GROUND absorbs the spill (3 + 26 = 29), ROOF still 1, total 40; ROOF never
      exceeds its quota in any leg
- [x] *(Gate 1b)* A tabletop crumb is an ordinary reachable crumb: the pigeon drops
      onto a table's top beside the crumb (the bench-landing geometry), settles
      grounded, waddles in, and the crumb feeds +30 through `crumb_eaten`
- [x] Full Gate 1b suite green — including the re-derived `city_roofs_inhabited`
      total (787) and the re-derived `city_cafe_tables_present` `bread_ok` leg (pool
      read skips kind-TABLE entries — the leg then reads today's exact pre-T-112
      pool and spots: probe-verified 0 trips at M1 and 424242, min 2.704 m /
      2.626 m); re-runs of `city_district_anchors_present`,
      `city_park_trees_present`, `crumbs_respawn`, all four elder scenarios and
      `density_cpu_budget`
- [x] VERIFICATION.md in the same change-set: the new `bread_distribution_weighted`
      row added to the Gate 1b table, the `city_roofs_inhabited` row's total pin
      re-derived, the `city_cafe_tables_present` row's clearance wording annotated
      with the kind-TABLE skip, and the two Gate 3 lines below added to the
      playtest list
- [x] **[screenshot] (Gate 3 — human judgement)** From a cruise pass, awninged
      streets visibly hold the city's bread — several tabletop crumbs under awnings
      in one frame — while roofs read bare (0–1 roof crumbs visible across a few
      passes): "bread lives at the tables" reads from the air (accepted by reviewer
      sign-off 2026-10-10) [screenshot]
- [x] **[screenshot] (Gate 3 — human judgement)** Landing on a tabletop and pecking
      the crumb reads right — small pad, sitter beside you, crumb at your feet — and
      takeoff past the awning doesn't snag or read as a collision (accepted by
      reviewer sign-off 2026-10-10) [screenshot]

**Tuned values (final).** `table_share` 0.90 · `roof_share` 0.025 (ground takes the
remainder, 0.075) · `target_count` 40 unchanged → quotas **36 TABLE / 3 GROUND /
1 ROOF** at every seed with no elders (budget 6 rounds to 5/1/0 for the
`crumbs_respawn` rig). Table spot law: `cafe_spot.origin + spot.basis.x * 0.25 +
Vector3(0, 0.78, 0)` — collider top 0.72 + the 0.06 crumb lift, 0.47 m from the
first sitter, 0.20 m inside the 0.9 m top's edge. City pool at M1: 787 = 533
GROUND (392 ring + 141 bench) + 150 ROOF (146 roofs + 4 anchor caps) + 104 TABLE.
The parked-machine evidence above is the landed run: Gate 1 exit 0, Gate 1b
119/119 PASS exit 0, Gate 2 `ok=true restart=true`; the two [screenshot] criteria
closed by the reviewer sign-off (2026-10-10).

**Landed (this change-set, machine side).** Gate 1 exit 0; Gate 1b full suite
119/119 PASS, exit 0 (`roofs_inhabited` re-print: buildings 146, bread_spots 787,
fingerprint 4045370482 — the pre-T-112 pin). Gate 2 autoplay `ok=true restart=true`.
Two harness re-derivations the runs forced, both recorded where they land: (1) the
physical tabletop leg must seat its own `CafeSpawner` — the tabletop collider is
batch-built, and without the rig the probe pigeon fell through the visual table and
ate from the pavement below (caught by the leg's grounded-at-top-height assert);
(2) `hud_bread_pointer_tracks_nearest_crumb`'s T-098 " ▼" arm — with only ~3 GROUND
crumbs alive, its seeded street-crumb pool can hold no crumb inside the bread-mode
ring (the M1 pool's one ring-spot crumb lives ~146.6 m from home, past the city-mode
flip), so the arm ring-guards its probes (like the ▲ arm) and constructs bounded
`drop_crumb` candidates over in-ring street spots, still scan-decided. The feed on
the tabletop fires on the settle frame (the 0.9 m top sits inside the crumb's
1.4 m grounded eat reach) — the leg's mid-bar baseline predates the drop, and the
waddle-in drive is held without its timing pinned.

## Verification

Gate 1 (`--import` + 120-frame boot, exit 0) · Gate 1b full suite in one headless run
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the new
`bread_distribution_weighted` scenario (rig: the `_scenario_bread_respawn`
spawner-under-test pattern over a real generated City; the physical tabletop leg reuses
`city_cafe_tables_present`'s perch/waddle geometry and the `crumb_eaten_grounded_only`
template) · Gate 2 autoplay re-run (crumb positions all move; DONE criteria unchanged;
`_plaza_crumb` cannot see a table crumb — see What) · Gate 3: the two [screenshot]
lines, addable to a standard playtest session.

**Pending human playtest (Gate 3):** the two lines above; plus "hunger runs now pull
me toward awninged streets and that reads as intended, not as starvation" — the
distribution's feel is the owner's judgement, the counts are the machine's.

## References

Research ran for this ticket: `docs/references/sidewalk-cafe-table/research.md`
(reviewed 2026-10-10) + all 7 photos in that folder (licenses in its
`credits.md`); every image opened and read before this ticket was written. Facts the
implementation MUST respect, orientation first:

1. **Food lies flat ON the tabletop, never at ground level** — at the height of a
   seated eater's mid-thigh to waist (`terrasse-cafe-paris-munhoven.jpg`: rims at the
   standing waiter's hip line; `terras-halle-2023.jpg`: top at the seated woman's
   waist). The spot's y is the collider top (spot + 0.72) + 0.06 — the roof-spot
   lift, never the spot-origin pavement.
2. **The crumb belongs at the eater's edge of the top, within arm's reach**
   (`cafe-breakfast-croissant-table.jpg`: the roll/plate sits at the diner's edge of
   a Ø 0.20–0.25 m plate on the top; `where-is-my-seat-topdown.jpg`: 2–4 chairs
   tucked per table). The 0.25 m inset toward the local +X sitter encodes this; a
   center-of-table crumb would read as nothing's plate.
3. **One dining surface per table, out on the sidewalk under the awning** — never
   inside the doorway (`st-gallen-sidewalk-cafe.jpg`: pedestal tops Ø ≈ 0.7 m with
   2–4 chairs and a real pigeon working the pavement beside them;
   `wiki-takes-porto-pausa-cafe.jpg`: the set clustered at the door under the
   awning; `herengracht-sidewalk-cafe.jpg`: diners using the tops). One TABLE spot
   per awninged building matches T-031's one-table-per-front geometry, whose 0.72 m
   top and 1.9 m standoff the research confirms against the real 0.73–0.76 m and
   0.5–2 m conventions; from the air (`where-is-my-seat-topdown.jpg`) tabletops read
   as the scene's dominant light discs — 36 bright tabletop crumbs is what a cruising
   pigeon should see.

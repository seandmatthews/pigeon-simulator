# T-029 — Plaza landmark: statue on a plinth at the square's center

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-004 (plaza + generator guarantees)
- **Refs:** `docs/DESIGN.md:90-91` → "Landmarks sprinkled by seed (statue
  square, café tables)" · `docs/tickets/README.md:127-128` → M2 backlog
  ("landmark bonus targets") · line refs re-based 2026-10-01 (rewrite; the
  T-049/T-051/T-069/T-088/T-089/T-102 landings moved every cited line and
  added cross-build fingerprint pins — hazard 2 below). The 2026-09-30 audit
  fix (four scenarios / five drops) had already landed in this file via
  commit 43829f5 and is kept, not re-applied.

## What

One fixed landmark at the center of the spawn plaza, built exactly like every
other city visual — MultiMesh boxes at pure-layout offsets, zero RNG:

- `scripts/city.gd` `_make_meshes()` (`scripts/city.gd:494`, mesh dict
  `:495-519`): two new mesh keys — `"plinth"` (new `COLOR_STONE`, a gray
  limestone clearly darker than the pale `COLOR_PLAZA` slab — `:29`,
  Color(0.60, 0.57, 0.51)) and `"figure"` (new `COLOR_BRONZE`, a dark
  oxidized bronze). Both constants join the const block `:26-39`
  (`COLOR_TANK` at `:36` is the newest precedent).
- `scripts/city.gd` `_build_plaza()` (`scripts/city.gd:950-964`): after the
  existing bench/lamp/bin ring (untouched), build at `center` (= the
  `_plaza_center` local origin — declared `scripts/city.gd:302`, set in
  `generate()` at `:350-351`) from fixed offsets:
  - plinth: base box 2.4 × 0.9 × 2.4 plus cap box 1.8 × 1.1 × 1.8 → top at
    `block_slab_height + 2.0` = 2.12 m (`block_slab_height` 0.12,
    `scripts/city.gd:179`);
  - figure: a stylized bronze pigeon ~3 m tall on the plinth (body box
    ~1.8 × 1.2 × 1.0, head box ~0.7, beak and tail as small boxes — the
    T-011 hand-built-primitives recipe, static and scaled). Total top ≤ 5.5 m.
- Landability: ONE layer-1 `StaticBody3D` box over the plinth
  (`_add_collider("Props", …)` — the bench pattern at `scripts/city.gd:998`;
  lamp cylinder `:1008`, bin `:1016`) so the plinth is a perch over the
  square. The figure above stays visual-only — the T-017 awning decision:
  flight passes through it rather than snagging at 3-5 m altitude; the plinth
  cap stays the landing surface.
- Fingerprint: append one `_fp` entry `["landmark", center.x, center.z]`.
  Zero RNG draws anywhere — the layout and shop streams produce byte-identical
  buildings, parks, benches, lamps, bins, shopfronts (including the pinned
  104 awnings — `scripts/city.gd:403`, `tests/sim_test.gd:1162`
  `awn_ok := awnings == 104`, `:1928` derives the cafe tables from the same
  count) and bread spots. Within-build fingerprint equality is asserted at
  `tests/sim_test.gd:749`/`:753-755` (`city_same_seed_deterministic`) and
  `:762-766` (`city_regenerate_restores_layout`), plus `:1051`/`:1094`
  (`city_footprints_vary`) and `:1673`ff (`elder_placement_no_rng`).

**Known hazard 1, mitigated in the same change-set (inventory confirmed
2026-09-30, commit 43829f5 — kept verbatim, line refs re-based):** FOUR
harness scenarios ground the pigeon with a straight drop at `_city.position`
— FIVE identical drops, the exact plaza center where the plinth now stands
(`_set_up(true, _city.position + Vector3(0.0, 1.5, 0.0), Vector3.ZERO)`, each
followed by `await _await_grounded(90)`): `tests/sim_test.gd:3042`
(`_scenario_cars_traffic`, `:3041`), `:3157` and `:3197`
(`_scenario_car_splat_honk`, `:3151`), `:3228`
(`_scenario_traffic_recycle_keeps_flow`, `:3227` — the T-089 scenario,
dispatched at `:148`), `:4898` (`_scenario_audio_hit_sounds`, `:4893`).
(`_set_up` is at `tests/sim_test.gd:212`; the test city parks at
(2000, 0, 2000) at `:84`, so bare-rig origin drops never touch the plaza; the
only other `_city.position` drops — `:2819`, `:2996`, `:3007` — are 25 m
airborne starts, unaffected.) Unmitigated, the drop lands on the plinth top
(2.12 m) instead of the slab. Fix in the same commit: shift all five drops
off-center by a fixed plaza offset (e.g. `+ Vector3(4.0, 0.0, 3.0)` — 5.0 m
out, clear of the 2.4 m plinth footprint and the 5.5 m diagonal bins, inside
the 8 m bench ring) and refresh each comment: the anchor's meaning is
"grounded on the plaza", not "at the exact center".

**Known hazard 2, materialized after the audit (2026-10-01 wave) and new to
this ticket:** the appended `_fp` entry changes the fingerprint VALUE, and
the suite now holds FOUR cross-build pins to the old values — appending
breaks all four unless they are re-derived in this change-set:
`tests/sim_test.gd:919-921` + `:1003-1005` (`city_facades_fit_floors`),
`:2546-2548` (`city_apron_rim`), `:2634-2637` (`city_horizon_skyline`),
`:2794-2796` (`city_park_trees`) — all pin default-seed 20260928 →
4188136223 and foreign-seed 424242 → 547420287. The pin contract is
documented at `VERIFICATION.md:115`: the values moved ONCE before, for
T-051's mandated two-axis footprint `_fp` entry, re-derived with a headless
`City.generate` probe — the in-repo precedent (the pins entered with the
2026-10-01 wave; earliest commit by `git log -S 'fingerprint ==
4188136223'` is 25ed0a8, T-051). Mitigation: re-derive BOTH values the same
way and update all four scenario sites plus every `VERIFICATION.md` row
quoting the values (`:115`, `:121`, `:122`, `:124`) in the same change-set.

Not claimed: no seed-sprinkled per-district landmarks (DESIGN's full
"landmarks sprinkled by seed" stays open — this is the fixed plaza-center
slice); no bonus points or interaction; no figure collider. Complementary,
not duplicates: T-088's distant skyline ring (`scripts/city.gd:140-148`,
64 towers) is a visual-only horizon aid on the grass apron — zero colliders,
no in-city steering value — and T-091's district anchors (proposed) exclude
the plaza center by design.

## Why

Every run starts and returns to the plaza, and the plaza is a bare 22 × 22 m
slab (`block_size` 22.0, `scripts/city.gd:160`): `_build_plaza`
(`scripts/city.gd:950-964`) places 8 benches on the 8 m ring (`:951-954` —
the same benches carry the T-020 elder seats, `:955-961`), 4 lamps at the
±9.8 m corners (`:962-963`) and 4 bins on the ±5.5 m diagonals (`:964`) —
"The center stays empty." (`:949`). The wider city still offers nothing to
steer home by in its 49 blocks (`blocks_per_side` 7, `scripts/city.gd:159` —
T-051 varied the footprints, but no volume anchors a return), so aerial
sessions keep losing orientation. `DESIGN.md:90-91` promises the "statue
square" and the M2 backlog names "landmark bonus targets". The generator's
own guarantees make the center safe forever: `spawn_clear_radius` 12.0 m
(`scripts/city.gd:172`) keeps footprints out, roofs cap at 18.25 m (6 floors
× 3.0 + 0.25 — floors drawn at `scripts/city.gd:787`,
`building_floors_max` `:186`, `floor_height` `:184`, `roof_slab_height`
`:181`; 18.37 m counting the slab) against the 23 m pilot cruise floor
(`VERIFICATION.md:143`, Gate 2), so a ≤ 5.5 m statue never blocks cruise or
the opening climb — the spawn drop is on the road corridor next to the plaza
(`scripts/city.gd:366-368`), not over the center.

## Acceptance criteria

- [ ] Exactly one landmark stands at the plaza center every run: footprint
      within 2.5 m of the plaza center, total top ≤ 5.5 m — inside the 12 m
      spawn-clear guarantee and far under both `max_roof_height` (20.0,
      `scripts/city.gd:168`) and the 23 m cruise floor.
- [ ] Zero city-RNG draws added: same-seed regeneration reproduces the
      fingerprint exactly, and every RNG-derived value (buildings, parks,
      benches, lamps, bins, shopfront rolls incl. the pinned 104 awnings,
      bread spots) is unchanged from before the ticket.
- [ ] Both cross-build fingerprint pins re-derived in this change-set
      (headless `City.generate` probe, the T-051 precedent) and updated at
      all four pin sites (`tests/sim_test.gd:919-921` + `:1003-1005`,
      `:2546-2548`, `:2634-2637`, `:2794-2796`) and the `VERIFICATION.md`
      rows quoting the values (`:115`, `:121`, `:122`, `:124`).
- [ ] The plinth is landable: a drop onto it settles grounded at plinth-top
      height and a flap takes off again (bench-landing template).
- [ ] *(Gate 1b)* `city_plaza_landmark`: on a real generated City — exactly
      one landmark; footprint inside `spawn_clear_radius`; top <
      `max_roof_height` and < 23 m; `_city.generate(default_seed)`
      reproduces the landmark transform byte-identically; plus a
      flap-assisted straight pass along x through the plaza center at ~23 m
      altitude crosses the city without touching anything
      (`city_street_flyover` template — scenario `tests/sim_test.gd:782`,
      check `:801`; min y > 20).
- [ ] *(Gate 1b)* The four plaza-anchor scenarios — `cars_traffic`,
      `car_splat_honk`, `traffic_recycle_keeps_flow`, `audio_hit_sounds` —
      pass with their five drops moved off-center; `city_plaza_spawn`
      (road-corridor drop — scenario `tests/sim_test.gd:770`, check `:776`)
      passes unchanged; `city_same_seed_deterministic` and
      `city_regenerate_restores_layout` pass at the NEW pin values.
- [ ] [screenshot] From flight height (~20 m) and from the plaza pavement
      the statue reads as the square's heart — visible against the pale
      slab, not clipping the benches or the T-020 elders on the 8 m ring.

## Verification

Gate 1 (import + 120-frame boot — also the script-parse proof for this
change-set: Gate 1's `--check-only --script res://scripts/player.gd` leg is
broken repo-wide, `VERIFICATION.md:385-386`, so the ticket carries no
check-only leg) + Gate 1b full suite + Gate 2 + Gate 3.

Gate 1b baseline on today's tree: 110 `_check` sites / 98 unique labels
(`grep -c '_check("' tests/sim_test.gd` = 110; `grep -o '_check("[^"]*"' |
sort -u | wc -l` = 98; 86 scenario dispatch calls) → +1 with
`city_plaza_landmark`; re-count at implementation time. Explicitly re-run:
`city_plaza_spawn`, `city_street_flyover`, `city_same_seed_deterministic`,
`city_regenerate_restores_layout`, `city_facades_fit_floors`,
`city_apron_rim_present`, `city_horizon_skyline`, `city_park_trees_present`,
`city_footprints_vary`, `city_shopfronts_present`, `elder_placement_no_rng`,
and the four moved-anchor scenarios incl. `traffic_recycle_keeps_flow`.

Same-commit checklist: (a) the five plaza-center drops moved off-center,
comments refreshed; (b) both fingerprint pins re-derived and written at the
four sim_test sites + the VERIFICATION rows quoting them; (c) the
`city_plaza_landmark` row added to the Gate 1b table in `VERIFICATION.md`
(the AGENTS.md ticket loop: every feature lands with its verification entry).

Gate 2 caution: the autoplay pilot's ground visit steers to the plaza center
when no crumb sits inside the plaza block (`tests/autoplay.gd:486-490` —
"else the plaza center", `land_crumb := _plaza_crumb()` at `:490`, defined
at `:422` with the 13 m plaza-block gate at `:429`), pulls toward the center
below the cruise floor (`tests/autoplay.gd:266`) and banks toward it in
flight (`:317`). With a 2.12 m plinth there, re-run Gate 2 and require
`AUTOPLAY DONE ok=true`; if the descent wedges on the plinth, shift the
fallback landing target off-center in `tests/autoplay.gd` in the same
change-set.

**Pending human playtest (Gate 3):** new line — "the plaza landmark reads
from the air and orients you home from anywhere in the grid"; the existing
T-004/T-020 plaza lines re-checked (elders, benches and the spawn drop
unbothered).

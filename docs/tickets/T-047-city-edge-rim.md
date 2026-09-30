# T-047 — Build a readable rim at the city edge — trees/hedge ring instead of the infinite flat apron

- **Milestone:** Sweep backlog · **Status:** superseded (executed by T-088, commit 1 — work that one) · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-004 (city blockout, landed)
- **Refs:** sweep 2 sessions `vds2a`/`vds2b`/`vds2d` (readings recorded below); T-037's "city N m" HUD line
  (landed — the rim complements it); T-023/T-036 (proposed behavioral guards — out of scope here)

## What

A deterministic, collider-free rim at the city boundary, built in the generation
pass of `scripts/city.gd`:

- New mesh keys in `_make_meshes()` (`scripts/city.gd:350-365`): `"rim_hedge"` (a
  low hedge band, green measurably distinct from `COLOR_GRASS` — suggested
  Color(0.24, 0.38, 0.22), ≥ 0.15 Euclidean from (0.36, 0.5, 0.30); exact value to
  the implementer, Gate 3 judges), `"rim_trunk"` (bark — reuse
  `COLOR_BENCH_WOOD`), `"rim_crown"` (the same rim green family). NOTE: this
  ticket defines its OWN meshes — the "T-030 park-tree tech" is still
  status:proposed with no tree keys in `_make_meshes()`, so there is nothing to
  reuse yet.
- New pure-layout placement, a `_build_rim()` called in `generate()` after
  `_build_roads()` and before `_spawn_visuals()` (`scripts/city.gd:230-236`):
  along each of the four sides, one hedge instance on the grass apron just
  outside the outer road edge (center line ≈ `city_span * 0.5 + 0.5`, size ≈
  (city_span, 1.2, 0.8) — a small corner gap where the sides meet is acceptable);
  and per street exit — the `blocks_per_side + 1` road centers per side
  (`scripts/city.gd:384-387`) — two trees flanking the exit at
  ±(`road_width * 0.5 + 1.5`) along the side axis: trunk 0.35 × 2.2 × 0.35 rising
  from the apron (y 0) and crown 2.6 × 2.2 × 2.6 centered ~3.3 m up. At defaults:
  4 hedges, 64 trunks, 64 crowns.
- ZERO new RNG draws and ZERO new `_fp` entries — the spots are pure functions of
  the grid constants, the `elder_spots`/`cafe_spots` precedent
  (`scripts/city.gd:143-154`). Public reads for the harness:
  `rim_hedge_spots: Array[Transform3D]` and `rim_tree_spots: Array[Transform3D]`
  (city-local, appended during the pass). No `_add_collider` call anywhere —
  visual-only, the T-017 awning decision.
- Gate 1b: new scenario `city_apron_rim_present`; VERIFICATION.md row + Gate 3
  line in the same change-set.

What this does NOT claim: no walkability or flyover change (nothing gains a
collider — `city_street_flyover` and the roof/bench/sidewalk landing scenarios
must pass unchanged); no apron content beyond the rim (the 250 m `ground_extra`
apron itself stays flat, `scripts/city.gd:67` + `_build_ground` 368-378); the
under-world void rendering identically at negative altitude (`vds2d` shotA.png at
−117 m) is NOT addressed — T-036's respawn proposal makes that trip moot instead;
no behavioral guard (T-023's nudge-home owns that).

## Why

The city ends in a hard line to a featureless 250 m green apron, and everything
past it renders identically. Session `vds2a` frame f00007584 (873 m out) is
literally two flat planes and a 55 px bird — that run starved off-city
(`{"ev":"game_over","t_ms":241553}` in its events.jsonl). Session `vds2d`
shotA.png at altitude −117 m composes identically to above-ground flight — no
under-world signal at all. Every flying session in the lane lost its bird past
the edge within minutes (state trajectories: vds2b reached z = +958, vds2d
z = −2125), and the T-037 "city N m" HUD line was the only wayfinding cue in
every off-city frame (verified working at 873 m and 2098 m).

A rim of hedge and trees gives the edge the read it needs at cruise speed — "in
town / at the rim / gone" at a glance, with tree clumps marking exactly where a
street still leads home. It is deliberately decoration only: the fix must not
change one collision shape or one RNG draw.

## Acceptance criteria

- [ ] Gate 1b: `city_apron_rim_present` — on a real generated City:
      `rim_hedge_spots.size() == 4` and `rim_tree_spots.size() ==
      2 * 4 * (blocks_per_side + 1)` (64 at defaults); every hedge sits at the
      boundary radius (|x| or |z| ≈ `city_span * 0.5 + 0.5`), every trunk on the
      apron with its crown ~3.3 m up
- [ ] Gate 1b: same scenario — a forced same-seed rebuild
      (`generate(seed_value, true)`) reproduces both spot lists byte-identically
      (the `_spots_equal` pattern, `tests/sim_test.gd:1093-1108`), and the
      fingerprint hash still equals the recorded pre-change values — cross-version
      proof, T-020-style: seed 20260928 → 2492360539, seed 424242 → 2662825400
      (re-verified on the untouched tree 2026-09-30 with a headless
      `City.generate` probe; re-derive the same way before committing)
- [ ] Gate 1b: the hedge/crown green is ≥ 0.15 Euclidean RGB from
      `City.COLOR_GRASS`, so the rim reads against its own apron (asserted on the
      constants, printed informationally like the silhouette sweep)
- [ ] `city_street_flyover`, `city_roof_landable`/`city_roof_takeoff`,
      `city_sidewalk_walkable`, `city_plaza_spawn`, the determinism trio
      (`city_same_seed_deterministic` / `city_new_seed_guarantees` /
      `city_regenerate_restores_layout`) and the full suite stay green — zero
      colliders, zero RNG draws
- [ ] [screenshot] At cruise the rim reads as the edge of town — a hedge line with
      tree clumps at each street exit — and the apron no longer reads as infinite
      grass (Gate 3 — human judgement)

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the new
scenario, re-running the named city scenarios explicitly · Gate 2 (autoplay
unchanged — the pilot's flyover now crosses a visible rim every run) · Gate 3: the
[screenshot] line above, added to VERIFICATION.md's playtest list in the same
change-set.

# T-088 — Make the city edge legible: T-047's near rim plus T-050's far skyline as one pass

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** — (T-004 city blockout, landed). Executes [T-047](T-047-city-edge-rim.md) and [T-050](T-050-horizon-skyline.md) — both still `proposed`; flip each done/superseded by its own commit below.
- **Refs:** visual-design lane sweep 2, sessions `vds3a`/`vds3c` (frame readings recorded below in text — the session dirs are not present in this repo, checked both checkouts 2026-09-30); fingerprint pins re-verified **today** on the untouched tree with a headless `City.generate` probe (see What, commit 1).

## What

The deterministic, collider-free near rim (T-047) and the distant hash-chain
skyline (T-050), `scripts/city.gd` only. **Landing note (must):** this ticket
lands as **two commits, not one change-set** — AGENTS.md's one-ticket-per-
change-set rule holds per commit: commit 1 lands the rim (executing T-047),
commit 2 lands the skyline (executing T-050), each with its own scenario and
VERIFICATION.md rows; T-088 itself flips done only when both have landed. A
single combined commit is explicitly out.

### Commit 1 — the rim (executes T-047)

- `_make_meshes()` (`scripts/city.gd:380-398`) gains three keys: `rim_hedge`
  (a low hedge band, green measurably distinct from `COLOR_GRASS` — suggested
  Color(0.24, 0.38, 0.22), which measures 0.188 Euclidean from
  (0.36, 0.5, 0.30); exact value to the implementer, Gate 3 judges),
  `rim_trunk` (bark — reuse `COLOR_BENCH_WOOD`), `rim_crown` (the same rim
  green family). This ticket defines its own meshes — T-030's park trees are
  still unlanded, so there is nothing to reuse.
- New `_build_rim()` called in `generate()` after `_build_roads()`
  (`scripts/city.gd:261`) and before the block loop / `_spawn_visuals()`:
  per side, one hedge instance on the grass apron just outside the outer road
  edge — the outer road edge sits at `city_span * 0.5` (= 117 m), so the hedge
  center line is ≈ 117.5 m; size ≈ (city_span, 1.2, 0.8) oriented per side,
  small corner gaps where sides meet acceptable; and per street exit — the
  `blocks_per_side + 1` road centers per side (`scripts/city.gd:418-420`) —
  two trees flanking the exit at ±(`road_width * 0.5 + 1.5`) = ±6.5 m along
  the side axis (1.5 m clear of the road edge): trunk 0.35 × 2.2 × 0.35 rising
  from the apron (y 0), crown 2.6 × 2.2 × 2.6 centered ~3.3 m up. At defaults:
  4 hedges, 64 trunks, 64 crowns.
- Public reads `rim_hedge_spots: Array[Transform3D]` and
  `rim_tree_spots: Array[Transform3D]` (city-local, appended during the pass,
  reset in `generate()`'s reset block alongside `elder_spots`/`cafe_spots`,
  `scripts/city.gd:245-250`). **ZERO new RNG draws, ZERO `_add_collider`
  calls, ZERO new `_fp` entries** — the spots are pure functions of the grid
  constants, the `elder_spots`/`cafe_spots`/`roof_props` precedent; the
  fingerprint stays byte-identical to pre-T-088 builds (the trick is
  documented twice in-tree: `scripts/city.gd:511-519` and `614-619`).
- Gate 1b: new scenario `city_apron_rim_present` (registered beside the city
  scenarios, `tests/sim_test.gd:100-104`).

### Commit 2 — the skyline (executes T-050)

- `_make_meshes()` gains `skyline` and `skyline_tall` — flat
  `StandardMaterial3D`s, no texture; per-instance colors ride the existing
  `_add_mm(key, xf, color)` channel (`scripts/city.gd:727-731`); nodes spawn
  as `Skyline` / `SkylineTall` under the Visuals root via `to_pascal_case()`
  (`scripts/city.gd:749`).
- New `_build_skyline()` called from `generate()` immediately after
  `_build_ground()` (`scripts/city.gd:260`), before the block loop: 40–80 slim
  tall boxes total, of which 2–8 are `skyline_tall` landmark towers, placed by
  a **deterministic hash chain** — per index `i`, folds like
  `hash(Vector3i(i, seed_value, salt))` with a distinct int `salt` per
  attribute (radius, angle, class, height, width). ZERO draws from
  `_rng`/`_shop_rng` (their sequences stay byte-identical), ZERO `_fp` entries.
- Placement constraints (defaults): every tower at ground radius
  `r ∈ [city_span * 0.5 + ground_extra * 0.3, city_span * 0.5 + ground_extra - 20.0]`
  = **192–347 m**. The apron half-width is
  `city_span * 0.5 + ground_extra` = 367 m (`ground_extra` 250 at
  `scripts/city.gd:86` — note: T-042/T-050 cite line 67, which is stale;
  `city_span` 234 at `scripts/city.gd:194-195`), so the planning sketch's
  1.3–2.2× span (304–515 m) overruns the apron edge and the top of the range
  is clamped to 347 m — towers stay ON the apron.
- Sizes: heights 15–60 m (`scale.y`, box origin at height/2 — the apron top is
  y 0), XZ footprint 6–18 m per axis. Colors: muted `DISTRICT_PALETTES`
  members `darkened()` ~0.3–0.45, exact values to the implementer, Gate 3
  judges.
- **No colliders anywhere** — zero `_add_collider` calls (colliders live only
  under `Static`, `scripts/city.gd:252`), the T-017 awning decision.
- Gate 1b: new scenario `city_horizon_skyline` (layout asserts on the standing
  City — the `_scenario_city_district_palettes` access pattern,
  `tests/sim_test.gd:720-731`; no flight required).

What this does NOT claim: no behavioral off-world fix (the pigeon can still fly
past everything — T-023's nudge / T-042's respawn own the trip home); no
walkability or flyover change (nothing gains a collider); no apron content
beyond the rim band and the tower ring (the 250 m apron stays flat,
`_build_ground`, `scripts/city.gd:401-411`); no fog/haze system; the
under-world void's look is untouched.

## Why

Cruise crosses the city boundary in seconds with zero visual cue, and outside
is nothing — two flat green planes and haze — so runs drift off-world and
starve there while the HUD pointer does all the wayfinding. Verified in code:
the apron is one single-color box (`ground_extra` 250 at `scripts/city.gd:86`,
`_build_ground` at `scripts/city.gd:401-411`) and `_make_meshes()`
(`scripts/city.gd:380-398`) holds no rim or skyline keys.

Lane-session readings (recorded in text by the lane plan; the capture dirs are
not in this repo — the at-a-glance reads re-run at Gate 3): session `vds3a` —
the edge crossed at frame 2174 (26.7 m alt) unnoticed; 30 s later f00004404 is
a featureless dark-green plane, horizon to camera, with "city 754 m" the only
information; that run starved out there. Session `vds3c` — f00003732 at 53 m
shows the apron as two flat green planes meeting at a hard diagonal corner
seam; f00005088 at 622 m out shows the whole city as a tiny colorful strip on
a light-green plinth in an endless dark plane. The lane's open-loop flying
drifted off-world in three of four sessions.

The rim gives the edge its at-a-glance read at cruise — "in town / at the rim /
gone" — with tree clumps marking exactly where a street still leads home; the
skyline makes the outside read as a larger city under haze instead of a void
edge. Both are deliberately decoration only: not one collision shape or RNG
draw changes.

## Acceptance criteria

Commit 1 (rim):

- [ ] Gate 1b `city_apron_rim_present`, count legs: `rim_hedge_spots.size() == 4`
      and `rim_tree_spots.size() == 2 * 4 * (blocks_per_side + 1)` (64 at
      defaults)
- [ ] Same scenario, placement legs: every hedge center sits at the boundary
      (|x| or |z| ≈ `city_span * 0.5 + 0.5`); every trunk flanks one of the
      `blocks_per_side + 1` street exits per side at ≈ 6.5 m offset from its
      road center (1.5 m clear of the road edge) on the apron, with its crown
      ~3.3 m up
- [ ] Same scenario: the hedge/crown green is ≥ 0.15 Euclidean RGB from
      `City.COLOR_GRASS` (0.188 at the suggested value), printed informationally
      like the silhouette sweep
- [ ] Same scenario: a forced same-seed rebuild (`generate(seed_value, true)`)
      reproduces both spot lists byte-identically (the `_spots_equal` pattern,
      `tests/sim_test.gd:1257-1263`), and the fingerprint still equals the
      cross-version pins — seed 20260928 → **2492360539**, seed 424242 →
      **2662825400** (recorded by T-047 and re-verified 2026-09-30 on the
      untouched tree with a headless `City.generate` probe in the lane
      worktree: `PROBE_FP seed_20260928=2492360539 / seed_424242=2662825400 /
      default_again=2492360539`; re-derive the same way before committing)
- [ ] `city_street_flyover`, `city_roof_landable`/`city_roof_takeoff`,
      `city_sidewalk_walkable`, `city_plaza_spawn`, the determinism trio and
      the full suite stay green — zero colliders, zero RNG draws
- [ ] [screenshot] At cruise the rim reads as the edge of town — a hedge line
      with tree clumps at each street exit — and the apron no longer reads as
      infinite grass (Gate 3 — human judgement)

Commit 2 (skyline):

- [ ] Gate 1b `city_horizon_skyline`: `Skyline` and `SkylineTall`
      MultiMeshInstance3D nodes exist under `_city.get_node("Visuals")`; total
      instances across both in [40, 80], `skyline_tall` in [2, 8]
- [ ] Same scenario: every instance origin's XZ radius from the city center
      lies in [192, 347] m — beyond the blocks, strictly inside the apron box
      including the tower's own ≤ 9 m half-width; every `scale.y ∈ [15, 60]`
      and XZ extents ≤ 18 m
- [ ] Same scenario: zero `CollisionObject3D` nodes anywhere under the Visuals
      root, and a forced same-seed rebuild reproduces both instance sets
      byte-identically with the fingerprint still equal to the pins above
- [ ] `city_street_flyover`, `city_plaza_spawn`, the determinism trio and the
      full suite stay green; a foreign seed still changes the fingerprint and
      passes `city_new_seed_guarantees` unchanged
- [ ] [screenshot] From the apron (300+ m out) the horizon reads as a distant
      city under haze, not a void edge — the towers must read as background
      (muted, low-contrast), not as landable-looking foreground buildings
      (Gate 3 — human judgement)

Ticket close:

- [ ] Both commits landed in order; T-047 and T-050 flipped done/superseded
      with their own commit references; the backlog index table updated

## Verification

Per commit — Gate 1 (import + 120-frame boot, exit 0, no ERROR lines;
`--check-only --script res://scripts/city.gd`) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with that
commit's new scenario, re-running the named city scenarios explicitly ·
Gate 2 autoplay unchanged (no colliders means no flight surface changed; the
flyover now crosses a visible rim, and its horizon view shows towers) ·
Gate 3: the [screenshot] lines above, added to VERIFICATION.md's playtest list
in the same change-sets.

# T-173 — Ames R1 · world renderer: resident baked world behind a world flag

- **Status:** proposed · **Category:** code-optimization · **Ring:** R1 The Map ·
  **Value (1-5):** 5 · **Risk (1-5):** 4
- **Depends on:** T-172 (the chunks it renders)
- **Refs:** `docs/AMES-MASTERPLAN.md` §2 (resident renderer; streaming is
  the conditional upgrade path only), §12 (melt-factors risk row) ·
  `scripts/main.gd` (the Sun / one-shadow-caster setup kept) ·
  `scripts/city.gd` (the world API surface gameplay expects) ·
  external review 2026-11-09 (precision: worst-case ≈3.3 km from origin,
  inside ±4 km single-precision; melt = draw calls/memory/lighting)

## What

The runtime half of bake-then-render. A new `scripts/ames_world.gd`
world root, selected by a `world` setting (`windrow` | `ames`, default
`windrow` — the suite stays byte-green until T-177 flips it):

- Instantiate all baked chunks once at ready (resident; no streaming) —
  ~160 chunk MultiMeshes, each frustum-cullable via its AABB.
- **Visibility ranges**: massing fades by distance band; heroes mount
  points exposed (`mount_hero(chunk_pos, scene)`) for T-175+.
- **Occlusion**: baked `ArrayOccluder3D` per chunk from the manifest.
- **Lighting**: unchanged one-sun contract; massing is vertex-colored,
  no per-building lights, ever (master plan §2).
- **Gameplay seam**: the same public API `city.gd` exposes today
  (ground queries, block/district lookup) implemented over chunk data —
  gameplay code does not know which world is live.

**Streaming (`R1·streaming-if-needed`) is deliberately NOT here**: if
the perf gate below fails, a follow-up adds load/unload with hysteresis
behind this same interface — built on evidence, never on spec.

## Why

The resident renderer is the simplest thing that can work at 10.6 km²
with low-poly content, and it de-risks the ring: no chunk lifecycle
bugs, no hysteresis tuning, no pop-in. The world flag keeps every
existing gate green until the cutover owns the change.

## Acceptance criteria

- [ ] Default `windrow`: full existing suite green, byte-identical pins
      (the flag is inert until flipped)
- [ ] `ames` boots and is flyable menu→flight over the baked skeleton
- [ ] *(Gate 1b)* `ames_world_render_budget`: at cruise over Campustown
      and low-hover over downtown — instance/draw metrics under budget
      (draws ≤ 800, chunk memory ≤ 400 MB — first values in-ticket,
      tuned on measurement)
- [ ] *(Gate 1b)* `ames_world_api_seam`: the city API surface (ground
      query, district lookup, spawn corridor equivalent) answers
      correctly over chunk data
- [ ] Pilot screenshots (hidden windows, T-170 contract): skeleton
      visible from 60 m and 200 m
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + two new rows · Gate 2 · Gate 3: agent flight pass on
`ames` (recorded screenshots vs survey photos) — the owner flight waits
for T-177.

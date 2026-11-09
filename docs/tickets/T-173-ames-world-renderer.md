# T-173 — Ames R1 · world renderer: resident baked world behind a world flag

- **Status:** done · **Category:** code-optimization · **Ring:** R1 The Map ·
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

- [x] Default `windrow`: full existing suite green, byte-identical pins
      (the flag is inert until flipped) — Gate 1b run: 185 PASS / 0 FAIL
      (2026-11-09), every layout fingerprint pin unchanged (1103197745
      rows green); Gate 2 autoplay `ok=true restart=true`
- [x] `ames` boots and is flyable menu→flight over the baked skeleton —
      pilot (PIGEON_WORLD=ames, hidden window): Space → Main, stepped
      boot `city_ground 2 ms / city_blocks 92 ms / city_visuals 0 ms`,
      pigeon drops and grounds on the plate, flap returns to flight;
      round-1 review's live A/B re-run after the guard fix: heading
      north at 100 m over Main St (2700, 100, −256) the yaw held 0.00
      through the glide to touchdown (pre-fix: 0→1.10 rad of bank-home
      in 4 s, edge hint over downtown), off_world_resets 0
- [x] *(Gate 1b)* `ames_world_render_budget`: at cruise over Campustown
      and low-hover over downtown — instance/draw metrics under budget
      (draws ≤ 800, chunk memory ≤ 400 MB — first values in-ticket,
      tuned on measurement) — measured first values: 372 chunk
      MultiMeshes (worst-case whole-world draw ceiling; 3 max per
      chunk), 10,322 instances == the bake totals, cruise draws 277,
      low-hover draws 22, resident buffers 2.90 MB — 2,896,800 B after the round-1 crossing duplicates (budgets 800 / 400 MB)
- [x] *(Gate 1b)* `ames_world_api_seam`: the city API surface (ground
      query, district lookup, spawn corridor equivalent) answers
      correctly over chunk data — massing-top ground query, plate-clear
      origin, the four district families, the pack-origin spawn
      corridor, and the flyable drop+flap, all recomputed from the
      committed chunks; round-1 arms added: the tile-crossing ground
      probe (largest of the 401 tile-edge-crossing boxes answers its
      top inside the neighbor-tile overhang — red-before 0.0, the
      round-1 call-verb evidence: way/183218202 → 12.0 at center,
      0.0 at (−291.52, −450.35) inside the same footprint) and the
      guard-containment arm (every manifest chunk AABB inside the wired
      circle — red-before: origin-pinned 2335.2 m radius leaked 1,719
      of 3,737 boxes incl. 226 of 269 downtown; fixed center (1263.4,
      −60.7), radius 2782.1, worst corner 2473.9)
- [x] Pilot screenshots (hidden windows, T-170 contract): skeleton
      visible from 60 m and 200 m — `.captures/session_t173ames2/campustown_60m_air.png`
      (60 m) and `.captures/session_t173rv1/campustown_200m.png`
      (200 m, re-recorded after the round-1 review — the originally
      cited 200 m artifact had been captured in the first session,
      whose dir a later `pilot.py clean` removed; the citation now
      points at the re-recorded file, verified on disk): street grid at
      true block rhythm, district palette massing, LaVerne/creek water,
      park lawns, one-sun shadows; `pilot_window_hidden` acked no-focus
- [x] *(Gate 1/2)* clean — Gate 1 import exit 0 (only the accepted
      "still in use" line) + 120-frame boot exit 0, no error lines;
      Gate 2 green above

## Verification (proposed)

Gate 1 · Gate 1b + two new rows · Gate 2 · Gate 3: agent flight pass on
`ames` (recorded screenshots vs survey photos) — the owner flight waits
for T-177.

**Recorded:** all four gates run green at landing and after the round-1
review fixes (Gate 1 import+boot exit 0; Gate 1b 185 PASS / 0 FAIL;
Gate 2 autoplay `ok=true restart=true`; agent flight pass on `ames`
with the hidden-window screenshots above). **Reviewer signed off
2026-11-09** (round-1 findings fixed in-commit, re-verified live: yaw
held 0.00 over Main St; crossing box answers 25.00 in its overhang;
guard containment margin 308.2 m). The OWNER Gate 3 flight — Lincoln
Way end-to-end, recognizing Ames — remains T-177's exit demo per the
ring plan.

## Landed (2026-11-09)

- **World root**: `scripts/ames_world.gd` (`AmesWorld extends City`) +
  `scenes/ames_world.tscn`. Selection: `Game.world` setting
  (`windrow` default) persisted in settings.cfg `game/world`; boot flag
  `--world=<id>` / `PIGEON_WORLD` env beats the file (validated against
  `Game.WORLDS`, anything else means windrow); `Main._ready` swaps the
  world root before any boot phase and re-points the five spawners'
  `city` references (`_swap_to_ames_world`).
- **Resident build**: manifest → per chunk one node family at the tile
  center — `Massing` (vertex-color unit-box MultiMesh, per-instance
  baked colors), `Ribbons` (street/creek/ballast rectangles as thin
  boxes, never fades), `Patches` (lake/park triangles, double-sided,
  only where the bake has tris), one `ArrayOccluder3D` (box side walls,
  both windings, heights index-aligned). Each MultiMesh
  frustum-cullable via `custom_aabb` = the chunk's manifest AABB.
  Chunk SHA-256 verified against the manifest before render — a
  corrupted bake refuses the chunk loudly. Parsed JSON is dropped; the
  resident footprint is geometry + compact ground records (2.90 MB),
  each box indexed into every tile its footprint touches.
- **Visibility**: massing fades 1550→1800 m from the camera
  (`MASSING_RANGE_END` 1800, `MASSING_RANGE_FADE` 250, FADE_SELF);
  ribbons/patches never fade (the ground read stays — T-174 dresses it).
  Retune at Gate 3 re-derives the budget row.
- **Gameplay seam**: `ground_height(pos)` (top massing box over an XZ
  point, else 0 = plate), `district_at(pos)` (the baker's own v0 rule),
  `chunk_of`, `chunk_aabb`, `mount_hero(tile, scene)` (T-175+ mount
  point), spawn corridor over the pack origin (Lincoln Way × Welch —
  T-176 re-pins to Central Campus), and the world-owned guard circle —
  `home_center()` (City: its own origin; AmesWorld: the bake bounds
  center (1263.4, −60.7)) and `home_radius()` (City: the grid math
  Main used to inline, byte-identically; AmesWorld: the bounds'
  half-diagonal + 250 m apron = 2782.1 m, containing every chunk AABB —
  the round-1 fix; new one-line City methods, Main now calls both).
  One flat ground plate
  (physics layer 1 + visual, manifest bounds + 250 m apron) at y 0 —
  the stack height the bake reserved.
- **Deviations/notes**: Godot 4.7's `ArrayOccluder3D` takes
  `vertices`+`indices` (not the old `arrays` — the docs' shape differs
  from the engine, found at first boot); 25 of 172 chunks carry no
  massing (flats-only), so occluders exist per MASSING-bearing chunk
  (asserted against the manifest); harness probes use
  `find_children(..., owned=false)` — runtime-built nodes have no scene
  owner. Streaming deliberately absent (master plan §2).

## Review round 1 (2026-11-09, all fixed)

1. **Off-world guard leaked half the map** (AC2). The guard circle was
   pinned at `city.global_position` — the pack origin, which sits on the
   map's WEST edge — with `home_radius()` = max(span)/2 + 250 = 2335.2 m
   from there. 1,719 of 3,737 massing boxes (46%) sat outside it, incl.
   226 of 269 downtown and 172 of 291 Lincoln Way: the T-023 nudge banked
   the pigeon home over downtown (reviewer's live A/B: heading north at
   100 m over Main St, yaw 0→1.10 rad in 4 s; Campustown control held
   0.00) and the edge hint showed over dense massing. Fix: world-owned
   `home_center()` (City returns `global_position`, AmesWorld the bake
   bounds center (1263.4, −60.7)) and `home_radius()` as the bounds'
   half-DIAGONAL + margin (2782.1 m), so every chunk AABB corner is
   inside (worst 2473.9 m); Main wires both through the methods.
   Gate 1b arm added asserting containment over all 172 manifest AABBs
   (recomputed corners).
2. **`ground_height()` missed cross-tile boxes** (AC4). Boxes were filed
   under their centroid's tile, but 401 of 3,737 boxes cross a 256 m
   tile edge (worst overhang 77 m) — points under an overhang answered
   the plate 0.0 instead of the roof (reviewer's live cases:
   way/183218202 → 12.0 at center, 0.0 at (−291.52, −450.35) inside the
   same 170.5 m footprint; way/180651868 and relation/2507889 same
   shape). Fix: each box is indexed into EVERY tile its footprint
   touches (build-time; ~25 KB of duplicates). Gate 1b arm added: the
   largest-overhang box (recomputed by an independent scan of all chunk
   files) must answer its top at the center AND at a neighbor-tile
   overhang point (red-before 0.0).
3. **AC5 cited a screenshot that did not exist**. The 200 m shot had
   been captured in the first pilot session, whose directory a later
   `pilot.py clean` (sweeping a dead session my own cleanup had killed)
   removed. Re-recorded at `.captures/session_t173rv1/campustown_200m.png`
   (hidden window, `pilot_window_hidden` acked), viewed and verified;
   the citation now points at real files.


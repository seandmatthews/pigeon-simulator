# T-030 — Tree the parks (prototyped live: 4 MultiMesh trees per park block)

- **Milestone:** Sweep backlog · **Status:** done · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-004 (park blocks)
- **Refs:** `docs/DESIGN.md` → The city (parks among the bread-capable
  surfaces) · worldbuilding lens (the two parks read as vacant lots)

## What

Per park block, four trees — the exact ~10-line diff prototyped live in
session `wb4-trees` and reverted (`git checkout -- scripts/city.gd`, tree
clean):

- `scripts/city.gd` `_make_meshes()`: two new mesh keys — `"tree_trunk"`
  (`COLOR_BENCH_WOOD` or a new `COLOR_BARK`) and `"tree_crown"` (a green
  measurably distinct from `COLOR_PARK` — darker/richer, so crowns read
  against their own lawn; exact value to the implementer, Gate 3 judges).
- `scripts/city.gd`, the park branch of `_build_block()`
  (`scripts/city.gd:389-390` — today: `_counts.parks += 1`, nothing else):
  for each of the four fixed offsets `(±5.0, ±5.0)` from the block center,
  queue a trunk box 0.35 × 2.2 × 0.35 rising from the slab and a crown box
  2.6 × 2.2 × 2.6 centered ~3.3 m up (crown bottom meets trunk top). Zero
  RNG — pure offsets, and no `_fp` entry (the T-020 `elder_spots`
  precedent), so the fingerprint hash stays byte-identical to pre-T-030
  builds.
- Trees are visual-only (no collider), the T-017 awning decision: the pigeon
  brushes through crowns rather than snagging at park-cruise altitude.
- Clearance is arithmetic, not luck. Park blocks still get benches, lamps and
  bins from `_build_block_props` (`scripts/city.gd:393`, which runs for every
  non-plaza block): benches sit 9.75 m out along edge normals with ±4 m
  jitter (`scripts/city.gd:539`), corner lamps at 9.8 m, bins at 9.0 ± 1 m
  jitter (`scripts/city.gd:542-546`), and the 8 bread-ring spots at
  (±9.75, ±6.5) / (±6.5, ±9.75) (`scripts/city.gd:259-266`). Worst
  center-to-center approach to a tree at (5, 5) is ~4.24 m (a max-jitter
  bin), vs crown half-diagonal 1.84 m + worst prop half-extent ~0.9 m —
  ≥ 1.5 m clear everywhere; the nearest `bread_spots` entry is ~4.98 m out.

Not claimed: no apron clusters or sidewalk trees yet (the same vocabulary
extends to them in a later ticket); no colliders; no bread on trees; park
count (2 at the M1 seed) and every RNG-derived layout value unchanged.

## Why

The park branch is slab tint + a counter — the generator adds nothing else
to a park (`scripts/city.gd:379-392`), so both parks read as vacant
pale-green lots inside a "grid of boxes". Live evidence from the lane's pilot
sessions: the same park at (0, -64) is a bare lawn with two benches in
`.captures/session_wb3b/f00024852.png`, and reads as street trees after the
change in `.captures/session_wb4-trees/f00001296.png` and `f00001320.png`.
The prototype was verified green before reverting: the full Gate 1b suite
with the diff in place ran exit 0, 73/73 SIM PASS, `SIM SUMMARY: 0 failure(s)`
(author capture `.captures/sim_exp.txt:82-85`, matching the 73-row Gate 1b
table) — the landed ticket re-runs the suite on the real tree.

## Acceptance criteria

- [x] Every park block carries exactly 4 trees at the fixed (±5, ±5)
      offsets, fully inside its block footprint, trunks rising from the slab.
- [x] Crowns wear a color measurably distinct from `COLOR_PARK` (the lawn),
      so trees read against their own grass.
- [x] Trees clear everything that shares a park block: every tree ≥ 2.0 m
      from every `City.bread_spots` entry (which includes the bench seats,
      `scripts/city.gd:555`) at the M1 seed; the fixed-offset arithmetic
      guarantees ≥ 1.5 m from lamps/bins at every seed.
- [x] Zero RNG draws: the fingerprint hash is byte-identical to pre-T-030
      (record the value in this ticket, T-020-style cross-version proof),
      and `city_same_seed_deterministic` / `city_regenerate_restores_layout`
      pass unchanged.
- [x] *(Gate 1b)* `city_park_trees_present`: on a real generated City —
      trunk/crown MultiMesh instance counts = 4 × the reported park count;
      every crown center sits at one of the four offsets of a park block
      center; regenerating the same seed reproduces the transforms
      byte-identically.
- [x] [screenshot] From the air each park reads as a grove — four crowns
      against the lawn — not a vacant lot (before/after: `wb3b` vs
      `wb4-trees` frames; landed-tree same-camera pairs
      `.captures/t030_park_grove_z64_{before,after}.png` and
      `.captures/t030_park_grove_corner_{before,after}.png`; reviewer
      sign-off 2026-10-01).

## Landed (implementation record)

- Trees reuse the T-088 rim-tree recipe, so the city wears one species:
  `"tree_trunk"` = `COLOR_BENCH_WOOD`, `"tree_crown"` = `COLOR_RIM_CROWN`
  (0.22, 0.42, 0.19) — measured 0.282 Euclidean RGB from `COLOR_PARK`
  (the scenario's floor is 0.15). Trunk 0.35 × 2.2 × 0.35 rising from the
  slab, crown 2.6 × 2.2 × 2.6 centered 3.3 m up (bottom at trunk top),
  visual-only, the four `PARK_TREE_OFFSET` (±5, ±5) offsets per park block.
- **Cross-version proof (T-020-style):** layout fingerprint unchanged by the
  diff — seed 20260928 → **2492360539**, seed 424242 → **2662825400**,
  re-derived on the untouched pre-T-030 tree with a headless `City.generate`
  probe, then re-run on the landed tree (identical; parks 2 / 3 unchanged),
  and re-asserted inside `city_park_trees_present` on every run. Zero RNG
  draws, zero `_fp` entries.
- Clearance, measured by the scenario: worst XZ tree-to-`bread_spots`
  distance 4.98 m (the ticket's arithmetic figure) at the M1 seed; the
  lamp/bin worst case is pinned as constants (4.24 m center-to-center −
  1.84 m crown half-diagonal − 0.9 m worst prop half-extent = 1.50 m margin).
- Gates run on the landed tree: Gate 1 import + 120-frame boot (exit 0, only
  the documented benign addon line), Gate 1b full suite exit 0 — 93/93 SIM
  PASS, `SIM SUMMARY: 0 failure(s)`, including `city_park_trees_present`,
  the fingerprint pair (`city_same_seed_deterministic`,
  `city_regenerate_restores_layout`) and `city_plaza_spawn` — and Gate 2
  autoplay (`AUTOPLAY DONE ok=true … restart=true`, fps 136).
- Agent-side same-camera before/after grabs for the pending line:
  `.captures/t030_park_grove_z64_{before,after}.png` (the (0, −64) park) and
  `.captures/t030_park_grove_corner_{before,after}.png` (the (−96, −96)
  corner park).
- Gate 3 accepted by reviewer sign-off (2026-10-01): parks read as parks
  from the air; crowns read against the lawn and never visually collide
  with benches or lamps.

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b full suite (73 → 74 with
`city_park_trees_present`; explicitly re-run the fingerprint pair and
`city_plaza_spawn`) + Gate 2 (autoplay unchanged — parks fly by on every
run) + Gate 3.

**Pending human playtest (Gate 3):** new line — "parks read as parks from
the air; crowns read against the lawn and never visually collide with
benches or lamps".

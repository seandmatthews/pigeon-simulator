# T-103 — Stand the shop doors up: fix the inverted axis swap that renders them as fins

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 2 · **Risk (1-5):** 1
- **Depends on:** — (builds on the landed T-017 shopfronts; surfaced and confirmed during the 2026-09-30 backlog audit, see the addendum in [backlog-audit-2026-09-30.md](backlog-audit-2026-09-30.md); [T-090](T-090-shop-signboards.md) documents the defect and avoids inheriting it)
- **Refs:** `scripts/city.gd:668-669` (the inverted swap) · `scripts/city.gd:676-678` (the awning's CORRECT convention, same function) · `_add_shopfront` at `scripts/city.gd:649-683`

## What

One-line fix in `_add_shopfront()`. The landed door size branches are axis-inverted —
today (`scripts/city.gd:668-669`):

```gdscript
var door_size := Vector3(0.95, 2.05, 0.1) if absf(face_normal.x) > 0.5 \
		else Vector3(0.1, 2.05, 0.95)
```

For an x-facing face the wall runs along z, so the 0.95 m width belongs on z and the
0.1 m thickness on x — the code puts them backwards, and the else branch is inverted
the same way. Swap the two vectors:

```gdscript
var door_size := Vector3(0.1, 2.05, 0.95) if absf(face_normal.x) > 0.5 \
		else Vector3(0.95, 2.05, 0.1)
```

Thin depth on the face-normal axis, width along the wall — exactly the convention the
awning 12 lines below already uses (`scripts/city.gd:676-678`). Everything else is
untouched: the transform site (`scripts/city.gd:670-673`), the door's `+0.01` outset,
the slab+1.025 centering, no RNG change (the size is derived from `face_normal`,
already rolled — zero new draws), and every pinned count (146 doors, 104 awnings,
679 bread spots) is unchanged. The layout fingerprint VALUE may shift if the shop
entry hashes queued door transforms — every determinism scenario compares
within-build only, so they hold (the T-090 precedent for appended/changed visuals).

What this does NOT claim: no per-shop names or lettering; no collider; no change to
the door's nominal-flush float (the band's visible face sits at footprint/2 + 0.06
while the door's back plane sits at footprint/2 + 0.13 — a family-wide convention
the Gate 3 eye judges, not this ticket); no awning or signboard change (T-090 owns
the signs, on the corrected convention independently).

## Why

Every one of the 146 doors has rendered as a thin fin since T-017 landed: 0.1 m
wide, protruding ~0.55 m perpendicular from the band face instead of lying flush on
it. Confirmed by a headless `City.generate(20260928, true)` probe during the
2026-09-30 audit: doors=146, door scale `(0.1, 2.05, 0.95)` on a `door_face = 3`
(±z) building — thin on the wall axis, wide on the normal axis, inverted in both
branches. The shop band is T-017's eye-level feature — the thing that makes street
rows read as shops rather than painted stripes — and its one geometric element reads
as a slab edge-on. The harm is subtle at cruise but large at the street level the
feature exists for, and T-090's signboards will hang directly above mis-shaped
doors. Nothing in the harness caught it because `city_shopfronts_present` checks
only that `door_face` is street-side (`tests/sim_test.gd:822`) — no assertion looks
at door geometry, which is also why the bug survived T-017's green gates.

## Acceptance criteria

- [ ] (Gate 1b) `city_shopfronts_present` (`tests/sim_test.gd:792-855`) extended
      with a geometry leg: every queued door transform
      (`_city._visuals["door"].xfs` — the privates precedent of the crosswalk
      scenario, `tests/sim_test.gd:1909`) decomposes (basis columns — pure
      scale, no rotation, per `_box_xf`) with the ≈ 0.1 m axis on the
      face-normal direction and the 0.95 m axis along the wall, re-derived per
      building from its `door_face` record; door count still 146. This is a NEW
      assert, not a re-pin — nothing asserts door geometry today.
- [ ] (Gate 1b) `city_shopfronts_deterministic` (the twin leg,
      `tests/sim_test.gd:840-855`), `city_same_seed_deterministic` and
      `city_regenerate_restores_layout` stay green — same-seed regeneration
      reproduces the (fixed) door transforms byte-identically.
- [ ] (Gate 1b) the other pinned-count scenarios stay green unchanged:
      `city_cafe_tables_present`, `city_roofs_inhabited`,
      `elder_placement_no_rng`, `city_plaza_spawn`.
- [ ] [screenshot] (Gate 3) From the spawn street at eye level, doors read as
      flush slabs standing in the band face — no fins protruding past the
      shopfront line; reads correctly on both x-facing and z-facing streets.

## Verification

Gate 1 (import + 120-frame boot; `--check-only --script res://scripts/city.gd`
is viable — verified exit 0 during the audit, city.gd references no autoloads) +
Gate 1b full suite headless (87 scenarios on today's tree; the extended
`city_shopfronts_present` keeps the count at 87), explicitly re-run
`city_shopfronts_present`, `city_shopfronts_deterministic`,
`city_same_seed_deterministic`, `city_regenerate_restores_layout`,
`city_cafe_tables_present`, `city_roofs_inhabited` + Gate 2 (`AUTOPLAY DONE
ok=true`) + Gate 3: new VERIFICATION.md playtest line — "(T-103) Shop doors
read as flush slabs in the band face at eye level, on both street orientations
[screenshot]" — and the `city_shopfronts_present` Gate 1b row extended to name
the door-geometry leg, in the same change-set.

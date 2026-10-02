# T-090 — Signboards over the shop doors

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** T-017 shopfronts (landed) · pairs with T-049 (window rows, landed)
  for the full eye-level fix · [T-103](T-103-shop-door-orientation.md)
  (proposed — the inverted door swap this ticket must NOT inherit) · A/B
  frames `.captures/wbs2b_signs0.png` vs `.captures/wbs2a_ground0.png`
  (absent from every checkout searched 2026-10-01 — see Why)

## What

`scripts/city.gd` only — one visual-only signboard plaque above every
building's door, mounted on the shop band, from the existing MultiMesh box
recipe with zero RNG:

1. `_make_meshes()` (`scripts/city.gd:494-524`): register one new key
   `"sign": _unit_box(_flat_material(COLOR_SIGNBOARD))` with a new const
   `COLOR_SIGNBOARD := Color(0.92, 0.87, 0.74)` — a cream clearly lighter than
   every `SHOPFRONT_PALETTE` entry (`scripts/city.gd:50-55`) and the dark
   `COLOR_DOOR` slab (`scripts/city.gd:38`).
2. `_add_shopfront()` (`scripts/city.gd:870-908`): after the door `_add_mm`
   (`:894`), queue exactly one plaque per building from data already in hand —
   `face_normal` (`:888`), `footprint`, `band_outset` 0.12 (`:874`), `band_h`
   2.4 (`:873`):
   - size `(0.08, 0.5, 2.2)` when `absf(face_normal.x) > 0.5`, else
     `(2.2, 0.5, 0.08)` — **the AWNING's convention**
     (`scripts/city.gd:900-903`): the thin 0.08 m depth sits on the
     face-normal axis and the 2.2 m width runs along the wall, so the plaque
     hangs flush. **Do NOT copy the door's axis swap**
     (`scripts/city.gd:892-893`) — it is itself inverted (filed as T-103,
     still proposed): the landed door puts its 0.95 m width on the normal axis
     and its 0.1 m thickness on the wall axis, rendering a 0.1 m-wide fin
     protruding ~0.55 m from the band (re-confirmed 2026-10-01 by a headless
     `City.generate(20260928, true)` probe: `door` scale `(0.1, 2.05, 0.95)`
     on a `door_face=3` building and `(0.95, 2.05, 0.1)` on `door_face=1`).
     Out of scope here — but the harness re-derivations in criteria 4–5 must
     encode the CORRECTED convention or they will happily pass a perpendicular
     plank.
   - position
     `base_center + face_normal * (face_out * 0.5 + band_outset + 0.05)
     + Vector3(0.0, block_slab_height + 2.55, 0)` where
     `face_out := footprint.x if absf(face_normal.x) > 0.5 else footprint.y` —
     the SAME face-distance term the door (`:895`) and awning (`:905`) already
     use, T-051's per-axis convention (`scripts/city.gd:889-891`). NOT the old
     `footprint * 0.5`: since T-051 the two footprint axes differ, and a term
     on the wrong axis plans the plaque up to ~0.15 m off the face plane
     (probe: building 0, `door_face=3`, size `(5.730, 6.032)` — the face plane
     sits at 3.016 m along the normal, not 2.865 m). Centered on the door
     face, spanning slab+2.30 → slab+2.80: above the door top (slab+2.05;
     center slab+1.025, `:894-897`) and 0.055 m below the awning underside
     (awning center slab+2.9, 0.09 thick, `:904-907`), so a present awning
     never interpenetrates it; mounted 0.05 m proud of the band outset like
     the door's `+0.01` (the plaque's back face sits at face_out/2 + 0.13 vs
     the visible band face at face_out/2 + 0.06 — the band box is sized
     `footprint + band_outset`, `:875-877` — a ~0.07 m float; the corrected
     door floats ~0.02 m the same way — the family's nominal-flush convention:
     the Gate 3 screenshot judges the read, not the micrometres).

Zero RNG of any stream (no `_shop_rng` draw, no layout draw), zero `_fp`
(`scripts/city.gd:299`) entries — the T-031/T-032/T-069 precedent
(`_build_cafe_spots` `scripts/city.gd:911-920`, `_build_crossings`
`scripts/city.gd:625-677`), so the layout fingerprint (4188136223 at the M1
seed, re-printed by the 2026-10-01 probe) and every pinned count stay
byte-identical: 146 buildings, the 104-awning draw pin, the 679 bread spots
(all re-derived from today's tree). Visual-only, no collider — the deliberate
T-017 awning decision (`docs/tickets/T-017-shopfronts.md:33`, embodied in
`_add_shopfront`'s collider-free shape), like the crosswalk paint the
`city_crosswalks_present` scenario already asserts collider-free.

Not claimed: lettering or per-shop names (a blank cream plaque is the low-poly
signage read — the [screenshot] criterion judges whether doors read as signed
places); glazing (T-049's window rows); any collision or gameplay; any door
fix (T-103 owns that — the plaque hangs above whatever door geometry stands
when it lands).

## Why

At eye level a shop is a flat colored band plus a door slab — the band is
color-only by construction (`SHOPFRONT_PALETTE`, `scripts/city.gd:50-55`;
`band_h` 2.4 at `scripts/city.gd:873`) — so street rows read as painted
stripes instead of named places. A/B-suggested live during the worldbuilding
pass: an ~8-line prototype (reverted) added exactly this plaque, and session
wbs2b's frame showed pale plaques reading along the spawn street above every
dark door slab. Honest caveats: the cited A/B frames are absent from every
checkout searched today (this repo and both remaining worktrees), and the
prototype copied the door's inverted swap — its "plaques" would have rendered
as perpendicular planks whose long faces mimic flush signs only at oblique
angles — so the A/B is suggestive, not proof. The Gate 3 line below is the
real judge, at eye level, close, on the CORRECTED geometry.

## Acceptance criteria

- [ ] Every building shows exactly one signboard plaque centered above its
      door on the shop band, mounted on the door-face normal, spanning
      slab+2.30 → slab+2.80, its center plane 0.05 m proud of the band outset
      on the `face_out * 0.5` face-distance term — the transform recomputable
      from the building record (`door_face`, `size`, `center`; `size` carries
      the per-axis T-051 footprint).
- [ ] A plaque never interpenetrates its awning when present (plaque top
      slab+2.80 vs awning underside slab+2.855) and never reaches the roofline
      (smallest building: 2 floors → roof top at slab+6.25).
- [ ] Zero RNG draws and zero `_fp` entries added: same-seed regeneration
      reproduces the fingerprint exactly, and the pinned counts are unchanged
      (146 buildings, 104 awnings, 679 bread spots).
- [ ] (Gate 1b) `city_shopfronts_present` (`_scenario_city_shopfronts`,
      `tests/sim_test.gd:1119-1182`) extended: `_city._visuals["sign"].xfs`
      (`scripts/city.gd:295`) holds exactly one transform per building (146 at
      the M1 seed) and each equals a harness-side
      `_expected_sign_plaque(_city, info)` re-derivation from the building
      record — the `_expected_cafe_spot` pattern
      (`tests/sim_test.gd:1889-1902`, which owns its own copy of the layout
      numbers and already phrases the face distance in per-axis `face_out`
      terms; compare origin distance and euler < 0.01, its assert style at
      `:1939-1941`). The re-derivation MUST encode the CORRECTED convention
      (thin 0.08 axis on the face normal) — whatever formula the ticket
      encodes, its own re-derivation passes it, so this requirement is the
      check that keeps a perpendicular plank failing. Reading the private
      `_visuals` queue follows the crosswalk scenario's precedent
      (`tests/sim_test.gd:2319`, `:2401`) because
      `MultiMesh.get_instance_transform` reads back identity headless
      (`tests/sim_test.gd:953`, `:2307-2311`).
- [ ] (Gate 1b) `city_shopfronts_deterministic` (its twin leg,
      `tests/sim_test.gd:1167-1182`) extended: snapshot the sign xfs before
      `generate(default_seed, true)` and require the real rebuild to reproduce
      them exactly (the `_props_reproduced` exact-equality pattern,
      `tests/sim_test.gd:2087-2096`; exact transform compare via
      `_spots_equal`, `tests/sim_test.gd:1655`).
- [ ] [screenshot] From the spawn street at eye level, shop doors read as
      signed places — one plaque over every door — without cluttering or
      z-fighting against the bands, doors or awnings.

## Verification

Gate 1 (import + 120-frame boot, plus `--check-only --script
res://scripts/city.gd` — viable, exit 0 re-run 2026-10-01; city.gd references
no autoload, unlike the player.gd/poop.gd leg VERIFICATION.md:385-390 flags
broken) + Gate 1b full suite green with the two extended scenarios'
`VERIFICATION.md` rows refreshed (`:117-118`, same change-set); explicitly
re-run `city_shopfronts_present`, `city_shopfronts_deterministic`, and the
fingerprint-sensitive set — `city_same_seed_deterministic` (`:66`),
`city_regenerate_restores_layout` (`:68`), `city_footprints_vary` (`:116`,
T-051), `city_cafe_tables_present` (`:119`), `city_roofs_inhabited` (`:120`),
`elder_placement_no_rng` (`:106`) — plus Gate 2 (`AUTOPLAY DONE ok=true`) +
Gate 3 new line — "(T-090) Every shop door reads as a named place at eye
level — signboard plaque over the door, no clutter [screenshot]" — plus the
existing T-017 street-canyon lines re-checked (`VERIFICATION.md:318-327`).

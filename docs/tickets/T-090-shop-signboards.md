# T-090 — Signboards over the shop doors

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** T-017 shopfronts (landed) · pairs with T-049 (window rows) for the
  full eye-level fix · A/B frames `.captures/wbs2b_signs0.png` vs
  `.captures/wbs2a_ground0.png` (`.captures/` in the worldbuilding worktree)

## What

`scripts/city.gd` only — one visual-only signboard plaque above every
building's door, mounted on the shop band, from the existing MultiMesh box
recipe with zero RNG:

1. `_make_meshes()` (`scripts/city.gd:380-398`): register one new key
   `"sign": _unit_box(_flat_material(COLOR_SIGNBOARD))` with a new const
   `COLOR_SIGNBOARD := Color(0.92, 0.87, 0.74)` — a cream clearly lighter than
   every `SHOPFRONT_PALETTE` entry (`scripts/city.gd:43-48`) and the dark
   `COLOR_DOOR` slab.
2. `_add_shopfront()` (`scripts/city.gd:577-611`): after the door `_add_mm`,
   queue exactly one plaque per building from data already in hand —
   `face_normal`, `footprint`, `band_outset` 0.12 (`:581`), `band_h` 2.4
   (`:580`):
   - size `(2.2, 0.5, 0.08)` when `absf(face_normal.x) > 0.5`, else
     `(0.08, 0.5, 2.2)` — the door's axis swap (`scripts/city.gd:596-597`);
   - position
     `base_center + face_normal * (footprint * 0.5 + band_outset + 0.05)
     + Vector3(0.0, block_slab_height + 2.55, 0)` — centered on the door face,
     mounted flush on the band face (0.05 m proud of the band outset, like the
     door's `+0.01`), spanning slab+2.30 → slab+2.80: above the door top
     (slab+2.05, `scripts/city.gd:596-601`) and 0.055 m below the awning
     underside (awning center slab+2.9, 0.09 thick,
     `scripts/city.gd:607-610`), so a present awning never interpenetrates it.

Zero RNG of any stream (no `_shop_rng` draw, no layout draw), zero `_fp`
entries — the T-031/T-032 precedent (`scripts/city.gd:614-623`, `:511-519`), so
the layout fingerprint and every pinned count (146 buildings, the 104-awning
draw pin, the 679 bread spots) stay byte-identical. Visual-only, no collider —
the deliberate T-017 awning decision (`scripts/city.gd:575-576`).

Not claimed: lettering or per-shop names (a blank cream plaque is the low-poly
signage read — the [screenshot] criterion judges whether doors read as signed
places); glazing (T-049's window rows); any collision or gameplay.

## Why

At eye level a shop is a flat colored band plus a door slab — the band is
color-only by construction (`SHOPFRONT_PALETTE`, `scripts/city.gd:43-48`;
`band_h` 2.4 at `:580`) — so street rows read as painted stripes instead of
named places. A/B-proven live: an ~8-line prototype (reverted) added exactly
this plaque, and session wbs2b's `.captures/wbs2b_signs0.png` shows pale
plaques reading along the spawn street above every dark door slab, vs the same
street without them in `.captures/wbs2a_ground0.png`. Honest caveat: the
comparison frame is a different session/pose and the plaques read faintly at
that distance — the Gate 3 line below is the real judge, at eye level, close.

## Acceptance criteria

- [ ] Every building shows exactly one signboard plaque centered above its door
      on the shop band, mounted on the door-face normal, spanning
      slab+2.30 → slab+2.80 with its face 0.05 m proud of the band outset —
      the transform recomputable from the building record
      (`door_face`, `size`, `center`).
- [ ] A plaque never interpenetrates its awning when present (plaque top
      slab+2.80 vs awning underside slab+2.855) and never reaches the roofline.
- [ ] Zero RNG draws and zero `_fp` entries added: same-seed regeneration
      reproduces the fingerprint exactly, and the pinned counts are unchanged
      (146 buildings, 104 awnings, 679 bread spots).
- [ ] (Gate 1b) `city_shopfronts_present` (`tests/sim_test.gd:762-825`)
      extended: `_city._visuals["sign"].xfs` holds exactly one transform per
      building (146 at the M1 seed) and each equals a harness-side
      `_expected_sign_plaque(_city, info)` re-derivation from the building
      record — the `_expected_cafe_spot` pattern
      (`tests/sim_test.gd:1466-1477`, which owns its own copy of the layout
      numbers). Reading the private `_visuals` follows the harness precedent
      of reaching into privates (`tests/sim_test.gd:2130`).
- [ ] (Gate 1b) `city_shopfronts_deterministic` (its twin leg at
      `tests/sim_test.gd:810-825`) extended: snapshot the sign xfs before
      `generate(default_seed, true)` and require the real rebuild to reproduce
      them exactly (the `_props_reproduced` exact-equality pattern,
      `tests/sim_test.gd:1657-1666`).
- [ ] [screenshot] From the spawn street at eye level, shop doors read as
      signed places — one plaque over every door — without cluttering or
      z-fighting against the bands, doors or awnings.

## Verification

Gate 1 (import + 120-frame boot, plus `--check-only --script
res://scripts/city.gd`) + Gate 1b full suite green with the two extended
scenarios' `VERIFICATION.md` rows refreshed (same change-set); explicitly
re-run `city_shopfronts_present`, `city_shopfronts_deterministic`, and the
fingerprint-sensitive set — `city_same_seed_deterministic`,
`city_regenerate_restores_layout`, `city_cafe_tables_present`,
`city_roofs_inhabited`, `elder_placement_no_rng` — plus Gate 2 (`AUTOPLAY DONE
ok=true`) + Gate 3 new line — "(T-090) Every shop door reads as a named place
at eye level — signboard plaque over the door, no clutter [screenshot]" — plus
the existing T-017 street-canyon lines re-checked.

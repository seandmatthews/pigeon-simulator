# T-050 — Put a skyline on the horizon so the world doesn't end at a cliff

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** —
- **Refs:** T-047 (city-edge rim — proposed, visual-design: the NEAR-field hedge/tree
  rim at the block boundary; this ticket dresses the FAR horizon beyond it —
  independent, either order, no shared mesh keys) · T-023 / T-036 / T-042
  (proposed behavioral off-world guards — out of scope here; this ticket is only
  the look of the outside world) · T-017 (the visual-only precedent)

## What

Beyond the ring roads the world is 250 m of flat single-color grass — one flat
box in `_build_ground()` (`scripts/city.gd:368-378`, `ground_extra` 250 at
scripts/city.gd:67) — ending in a hard line against the sky. Cruise crosses the
whole city (city_span 234 m, the getter at scripts/city.gd:165-166) in ~9 s, so
every flight sees the edge, and the outside reads as nothing: the city feels
like a diorama on a table.

A **visual-only distant skyline**, `scripts/city.gd` only:

- Two new mesh keys in `_make_meshes()`: `"skyline"` and `"skyline_tall"` —
  flat `StandardMaterial3D`s, no texture; per-instance colors via the existing
  `_add_mm(key, xf, color)` channel (scripts/city.gd:661-665). The nodes spawn
  as `Skyline` / `SkylineTall` under the Visuals root (`to_pascal_case()`,
  scripts/city.gd:683 — verified on this repo's Godot 4.7.2).
- New `_build_skyline()` called from `generate()` immediately after
  `_build_ground()` (scripts/city.gd:230), before the block loop. 40-80 slim
  tall boxes total, of which 2-8 are `skyline_tall` landmark towers, placed by
  a **deterministic hash chain** — e.g. per index `i`, folds like
  `hash(Vector3i(i, seed_value, salt))` with a distinct int `salt` per attribute
  (radius, angle, class, height, width). ZERO draws from `_rng`/`_shop_rng`
  (their sequences stay byte-identical) and ZERO `_fp` entries.
- Placement constraints (defaults): every tower at ground radius
  `r ∈ [city_span * 0.5 + ground_extra * 0.3, city_span * 0.5 + ground_extra - 20.0]`
  = **192-347 m**, any angle. NOTE: the planning sketch's 1.3-2.2× city span
  (304-515 m) **overruns the apron edge** — the ground box half-width is
  `city_span * 0.5 + ground_extra` = 367 m (T-042 records the same ±367 m math)
  — so the top of the range is clamped to 347 m; towers must stay ON the apron.
- Sizes: heights 15-60 m (`scale.y`, box origin at height/2 — the apron top is
  y 0), XZ footprint 6-18 m per axis. Colors: muted district-palette tones —
  a `DISTRICT_PALETTES` member `darkened()` ~0.3-0.45, exact values to the
  implementer, Gate 3 judges.
- **No colliders anywhere** — zero `_add_collider` calls, the T-017 awning
  decision (scripts/city.gd:509-510). No `_fp` entries — the fingerprint stays
  byte-identical to the pre-change tree.

What this does NOT claim: no behavioral off-world fix (the pigeon can still fly
past the towers — T-023's nudge / T-036+T-042's respawn own the trip home); no
near-field edge read (that is T-047's rim; the two compose — rim at ~117.5 m,
skyline at 192-347 m); no fog or haze system. The planning sketch's "slightly
darker apron band" ships ONLY if Gate 3 reads the towers as pasted-on — then a
darkened-`COLOR_GRASS` ring under the tower ring, same zero-collider / zero-
`_fp` rules, same commit-series.

## Why

The world outside the ring roads is a hard horizon line over nothing, and every
flight sees it. Planning-session frames: `wbs2-a` f00094800 ("city 180 m" HUD
over a featureless apron), f00095328 and f00096000 ("city 356/607 m" — flat dark
plane, hard horizon), `wbs2-b` f00061428 ("city 413 m"). The bird left the city
repeatedly without any input pushing it out — the planning review counted 11
off-city excursions across the three sessions — and T-042 records where that
ends: a verified 2.1 km void glide at fwd 14.5 m/s, 80 m under the plane,
run dying on STARVE. The rescue is T-023/T-036/T-042's; THIS ticket makes the
outside read as a larger city under haze instead of a void edge, which is what
every one of those frames actually shows a player.

## Acceptance criteria

- [ ] Gate 1b: new scenario `city_horizon_skyline` in `tests/sim_test.gd`
      (layout asserts on the standing City — the `_scenario_city_district_palettes`
      access pattern, tests/sim_test.gd:664; no flight required) passes:
  - [ ] `Skyline` and `SkylineTall` MultiMeshInstance3D nodes exist under
        `_city.get_node("Visuals")`; total instances across both in [40, 80],
        `skyline_tall` instances in [2, 8];
  - [ ] every instance origin's XZ radius from the city center lies in
        `[city_span * 0.5 + ground_extra * 0.3, city_span * 0.5 + ground_extra - 20.0]`
        (192-347 m at defaults) — beyond the blocks, strictly inside the apron
        box including the tower's own ≤ 9 m half-width;
  - [ ] every instance's `scale.y ∈ [15, 60]` and XZ extents ≤ 18 m;
  - [ ] zero `StaticBody3D` (or any `CollisionObject3D`) nodes anywhere under
        the Visuals root — colliders live only under `Static`
        (scripts/city.gd:221-226);
  - [ ] a forced same-seed rebuild (`generate(seed_value, true)`) reproduces
        both instance sets byte-identically (`_spots_equal` pattern on the
        collected transform arrays, tests/sim_test.gd:1093).
- [ ] Gate 1b: the city fingerprint equals the pre-change baseline (record it on
      the untouched tree first) — zero `_fp` entries is a claim of this ticket;
      a foreign seed still changes the fingerprint and passes
      `city_new_seed_guarantees` unchanged.
- [ ] `city_street_flyover`, `city_plaza_spawn`, the determinism trio
      (`city_same_seed_deterministic` / `city_new_seed_guarantees` /
      `city_regenerate_restores_layout`) and the full suite stay green.
- [ ] [screenshot] Gate 3: from the apron the horizon reads as a distant city
      under haze, not a void edge — compare directly against the `wbs2-a`
      f00094800 baseline frame; the towers must read as background (muted,
      low-contrast), not as landable-looking foreground buildings.

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/city.gd`,
exit 0, no ERROR lines) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with
`city_horizon_skyline` added, and `city_street_flyover`, `city_plaza_spawn` and
the determinism trio re-run explicitly · Gate 2 (autoplay unchanged — no
colliders means no flight surface changed; the flyover's horizon view now shows
towers) · Gate 3: the [screenshot] line above, added to VERIFICATION.md's Gate
1b table and playtest list in the same change-set.

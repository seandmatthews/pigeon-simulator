# T-150 — Soften the bead juice: dust billows, splat splash flattens

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-013 (done — the one-shot burst rig the scenes ride)

## What

Scenes-only retune of the two most frequent juice effects — **no script logic moves**. `scripts/one_shot_burst.gd` is untouched: it frees at `lifetime + burnout_margin` (`burnout_margin` 0.25, `scripts/one_shot_burst.gd:12,24`), so shorter lifetimes only shrink the self-freeze window inside every existing cleanup wait, and longer dust life is not proposed (dust keeps 0.5 s).

- `scenes/dust_puff.tscn` — fewer, bigger, softer:
  - `Mesh_dust` SphereMesh radius 0.07 → ~0.14 (height 0.28) (`scenes/dust_puff.tscn:29-34`).
  - `Grad_fade` alpha ramp 0.8 → 0.55 → 0 becomes ~0.35 → ~0.2 → 0 (start ≤ 0.45) (`scenes/dust_puff.tscn:5-7`).
  - Add a `scale_curve` (CurveTexture over a Curve) to `PPM_dust` that GROWS over the 0.5 s lifetime (non-decreasing), so the puff billows instead of scattering as distinct balls (there is no `scale_curve` today — `scenes/dust_puff.tscn:12-22`).
  - `amount` 14 → ~10 (fewer, bigger). `Mat_dust` keeps the warm-gray tint, albedo (0.76, 0.7, 0.58) (`scenes/dust_puff.tscn:24-27`).
- `scenes/splat_burst.tscn` — splash, not berries:
  - `Mesh_drop` SphereMesh keeps radius 0.045 but height 0.09 → ~0.036, flattening the droplet to a y-squash ratio ~0.4 (`scenes/splat_burst.tscn:28-33`).
  - Wider velocity spread: `initial_velocity_max` 3.4 → ~5.0 (`scenes/splat_burst.tscn:16`).
  - `lifetime` 0.55 → ~0.4 (≤ 0.45) — a snappier splash (`scenes/splat_burst.tscn:38`).
  - `Mat_drop` stays white, albedo (0.96, 0.94, 0.8) — pigeon droppings are white; the change is silhouette and opacity, not palette. No second mesh/pass and no center blob: one flattened droplet set carries the read.

What this does **not** claim: no scoring, spawn or cleanup law moves; `poop.tscn` and `bread_crumb.tscn` are untouched (their shared value band with the old beads motivates the ticket but the poop ball itself is T-025's territory and stays); the feather poof is untouched (`juice_feather_poofs_on_hard_flap` stays green).

## Why

The landing dust puff is 14 opaque cream spheres (r 0.07, alpha 0.8 → 0.55 → 0, `scenes/dust_puff.tscn:5-7,29-34,38`) that scatter as distinct beige balls around the feet, and the splat burst is 24 cream spheres (r 0.045, albedo (0.96, 0.94, 0.8), `scenes/splat_burst.tscn:24-33,37`) that read as spilled berries — uncomfortably close to "more bread" on a target car's deck (`bread_crumb.tscn:9,14`: albedo (0.82, 0.62, 0.35), BoxMesh 0.16 × 0.1 × 0.12). The whole organic set shares one value band with the poop ball (`poop.tscn`: albedo (0.94, 0.9, 0.78), r 0.12), so dust, splat and poop are indistinguishable at a glance.

Evidence (sweep-1 visual-design captures, `.captures/` in the visual-design-s1 worktree):

- `session_vd2/window.png` — a real ~13 m/s road touchdown frozen mid-burst: ~12 separate beige spheres ringing the bird on open asphalt.
- `session_vd3/f00003420.png` and `f00003372.png` — the same bead read at native resolution behind the waddling bird.
- The splat burst observed live in vd3's frozen post-splat moment (white balls scattered over the hit car's deck), the chain confirmed by `session_vd3/events.jsonl:62-63` — `hit_scored` (points 30) and `car_splatted` at t_ms 64863.

## Acceptance criteria

- [ ] The landing dust reads as a soft cloud: draw-pass SphereMesh radius within 0.12–0.16, gradient alpha start ≤ 0.45, and a `scale_curve` present that is non-decreasing over the lifetime (Gate 1b — red-before: radius 0.07 ∉ band, alpha 0.8 > 0.45, no scale_curve)
- [ ] The splat reads as a flattened splash: draw-pass SphereMesh height/radius ratio < 0.6 and `lifetime` ≤ 0.45 (Gate 1b — red-before: ratio 2.0, lifetime 0.55)
- [ ] Both bursts still fire and self-clean: the existing spawn/at-hit/cleanup arms of `juice_splat_burst_fires` and `juice_dust_puff_on_landing` stay green (the splat node only frees EARLIER at the shorter lifetime — `tests/sim_test.gd:12160` waits past the old 0.55 s + margin)
- [ ] The splat still spawns at the hit point on the surface it hit (the existing `at_hit` arm, `tests/sim_test.gd:12156-12159`, stays green)
- [ ] The feather poof path is untouched (`juice_feather_poofs_on_hard_flap`, `tests/sim_test.gd:12170-12184`, stays green)
- [ ] [screenshot] The dust puff reads as a billowing soft cloud around the feet, not distinct balls (Gate 3)
- [ ] [screenshot] The splat reads as a splash flattened onto the deck, not berries — and no longer mimics a bread crumb on a car roof (Gate 3)

## Verification

- **Gate 1:** headless import + boot, both exit 0, zero unexpected ERROR lines.
- **Gate 1b:** the new locks are static reads of the packed scenes (`load("res://scenes/dust_puff.tscn")` / `splat_burst.tscn`; draw-pass mesh, `process_material` `color_ramp` gradient + `scale_curve`, `lifetime`), so they depend on no spawn timing:
  - Dust locks go in `_scenario_juice_dust_puff` (`tests/sim_test.gd:12191`, registered at `tests/sim_test.gd:300`).
  - Splat locks go in `_scenario_juice_splat_burst` (`tests/sim_test.gd:12145`, registered at `tests/sim_test.gd:298`) — NOT in the combo-strip scenario (it is `_scenario_combo_strip_reports_last_hit`, `tests/sim_test.gd:11806`, and its markers are `hit_marker.tscn`, not the burst). Compute each lock set as its own `_check` (e.g. `juice_dust_puff_presentation`, `juice_splat_burst_presentation`) so red-before is attributable while the existing fire/cleanup checks stay untouched.
  - Full suite green after; red-before observed by running the suite on the untouched scenes (all four value arms fail: 0.07 ∉ 0.12–0.16, alpha 0.8 > 0.45, ratio 2.0 > 0.6, lifetime 0.55 > 0.45).
- **Gate 2:** autoplay smoke, unchanged.
- **Gate 3:** the two [screenshot] lines; final radii/alphas/lifetime recorded in this ticket as the tuned values.

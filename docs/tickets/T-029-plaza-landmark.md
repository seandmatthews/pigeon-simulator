# T-029 — Plaza landmark: statue on a plinth at the square's center

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** worldbuilding · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-004 (plaza + generator guarantees)
- **Refs:** `docs/DESIGN.md:73-74` → "Landmarks sprinkled by seed (statue
  square, café tables)" · `docs/tickets/README.md:33` → M2 backlog
  ("statue/landmark bonus targets")

## What

One fixed landmark at the center of the spawn plaza, built exactly like every
other city visual — MultiMesh boxes at pure-layout offsets, zero RNG:

- `scripts/city.gd` `_make_meshes()`: two new mesh keys — `"plinth"` (new
  `COLOR_STONE`, a gray limestone clearly darker than the pale `COLOR_PLAZA`
  slab) and `"figure"` (new `COLOR_BRONZE`, a dark oxidized bronze).
- `scripts/city.gd` `_build_plaza()` (`scripts/city.gd:511-525`): after the
  existing bench/lamp/bin ring (untouched), build at `center` (= the
  `_plaza_center` local origin) from fixed offsets:
  - plinth: base box 2.4 × 0.9 × 2.4 plus cap box 1.8 × 1.1 × 1.8 → top at
    `block_slab_height + 2.0` = 2.12 m;
  - figure: a stylized bronze pigeon ~3 m tall on the plinth (body box
    ~1.8 × 1.2 × 1.0, head box ~0.7, beak and tail as small boxes — the
    T-011 hand-built-primitives recipe, static and scaled). Total top ≤ 5.5 m.
- Landability: ONE layer-1 `StaticBody3D` box over the plinth
  (`_add_collider("Props", …)`, the bench pattern, `scripts/city.gd:559`) so
  the plinth is a perch over the square. The figure above stays visual-only —
  the T-017 awning decision: flight passes through it rather than snagging at
  3-5 m altitude; the plinth cap stays the landing surface.
- Fingerprint: append one `_fp` entry `["landmark", center.x, center.z]`.
  Zero RNG draws anywhere — the layout and shop streams produce byte-identical
  buildings, parks, benches, lamps, bins, shopfronts (including the pinned
  104 awnings) and bread spots. The fingerprint VALUE changes vs pre-T-029
  builds (as T-017's appended entries did); no cross-build pin exists — the
  suite asserts within-build equality only (`tests/sim_test.gd:516`, `:524`,
  `:1091`).

**Known hazard, mitigated in the same change-set:** three harness scenarios
ground the pigeon with a straight drop at `_city.position` — the exact plaza
center, where the plinth now stands: `tests/sim_test.gd:1465`
(`cars_traffic`), `:1580` and `:1620` (`car_splat_honk`), `:2328`
(`audio_hit_sounds`). Unmitigated, the drop lands on the plinth top (2.12 m)
instead of the slab. Fix in the same commit: shift all four drops off-center
by a fixed plaza offset (e.g. `+ Vector3(4.0, 0.0, 3.0)` — 5.0 m out, clear
of the 2.4 m plinth footprint and the 5.5 m diagonal bins, inside the 8 m
bench ring) and refresh each comment: the anchor's meaning is "grounded on
the plaza", not "at the exact center".

Not claimed: no seed-sprinkled per-district landmarks (DESIGN's full
"landmarks sprinkled by seed" stays open — this is the fixed plaza-center
slice); no bonus points or interaction; no figure collider.

## Why

Every run starts and returns to the plaza, and the plaza is a bare 22 × 22 m
slab: `_build_plaza` places 8 benches on the 8 m ring, 4 lamps at the 9.8 m
corners and 4 bins on the 5.5 m diagonals — "The center stays empty."
(`scripts/city.gd:510`). The wider city has no landmark of any kind in 49
uniform blocks, so aerial sessions kept losing orientation — nothing to
navigate home by. `DESIGN.md:73-74` promises the "statue square" and the M2
backlog names "statue/landmark bonus targets". The generator's own
guarantees make the center safe forever: `spawn_clear_radius` 12 m
(`scripts/city.gd:65`) keeps footprints out, roofs cap at 18.25 m (6 floors ×
3.0 + 0.25) against the 23 m pilot cruise floor (`VERIFICATION.md` → Gate 2),
so a ~5 m statue never blocks cruise or the opening climb — the spawn drop is
on the road corridor next to the plaza (`scripts/city.gd:201-202`), not over
the center.

## Acceptance criteria

- [ ] Exactly one landmark stands at the plaza center every run: footprint
      within 2.5 m of the plaza center, total top ≤ 5.5 m — inside the 12 m
      spawn-clear guarantee and far under both `max_roof_height` (20) and the
      23 m cruise floor.
- [ ] Zero city-RNG draws added: same-seed regeneration reproduces the
      fingerprint exactly, and every RNG-derived value (buildings, parks,
      benches, lamps, bins, shopfront rolls incl. the pinned 104 awnings,
      bread spots) is unchanged from before the ticket.
- [ ] The plinth is landable: a drop onto it settles grounded at plinth-top
      height and a flap takes off again (bench-landing template).
- [ ] *(Gate 1b)* `city_plaza_landmark`: on a real generated City — exactly
      one landmark; footprint inside `spawn_clear_radius`; top <
      `max_roof_height` and < 23 m; `_city.generate(default_seed)`
      reproduces the landmark transform byte-identically; plus a
      flap-assisted straight pass along x through the plaza center at ~23 m
      altitude crosses the city without touching anything
      (`city_street_flyover` template, min y > 20).
- [ ] *(Gate 1b)* The three plaza-anchor scenarios — `cars_traffic`,
      `car_splat_honk`, `audio_hit_sounds` — pass with their four drops
      moved off-center; `city_plaza_spawn` (road-corridor drop) passes
      unchanged.
- [ ] [screenshot] From flight height (~20 m) and from the plaza pavement
      the statue reads as the square's heart — visible against the pale
      slab, not clipping the benches or the T-020 elders on the 8 m ring.

## Verification

Gate 1 (import + 120-frame boot) + Gate 1b full suite (baseline 73/73 → 74
with `city_plaza_landmark`; explicitly re-run `city_plaza_spawn`,
`city_street_flyover`, `city_same_seed_deterministic`,
`city_regenerate_restores_layout`, `elder_placement_no_rng`, and the three
moved-anchor scenarios) + Gate 2 + Gate 3.

Gate 2 caution: the autoplay pilot's ground visit steers to the plaza center
when no crumb sits inside the plaza block (`tests/autoplay.gd:486-490` —
"else the plaza center") and pulls toward the center near roof height
(`tests/autoplay.gd:266`). With a 2.1 m plinth there, re-run Gate 2 and
require `AUTOPLAY DONE ok=true`; if the descent wedges on the plinth, shift
the fallback landing target off-center in `tests/autoplay.gd` in the same
change-set.

**Pending human playtest (Gate 3):** new line — "the plaza landmark reads
from the air and orients you home from anywhere in the grid"; the existing
T-004/T-020 plaza lines re-checked (elders, benches and the spawn drop
unbothered).

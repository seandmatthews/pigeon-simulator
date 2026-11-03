# T-162 — Mount the car blinkers on the body: the four amber lamps float off the stretched sedan's corners

- **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 ·
  **Risk (1-5):** 2
- **Depends on:** T-124 (the Kenney-stretched paint surface the lamps must sit on)
  · T-134 (the flash tell and the four nodes this re-seats — an UNTOUCHED contract)
- **Refs:** owner idea (2026-11-03): "Mount the car blinkers ON the body" ·
  research note
  [`docs/references/car-indicator-lamps/research.md`](../references/car-indicator-lamps/research.md)
  + the 8 photos listed in that directory's `credits.md` (each opened
  2026-11-03 while writing this) · `scenes/car.tscn:109-129` (the four Blink
  nodes), `scenes/car.tscn:50-58` (Mat_blinker / Mesh_blinker),
  `scripts/car.gd:78-79` (`blinker_lead`/`blinker_hz`), `scripts/car.gd:214-217`
  (the `@onready` node paths), `scripts/car.gd:565-591` (`_update_blinker` /
  `_apply_blinker_meshes` — untouched), `scripts/cafe_spawner.gd:200-205`
  (`_hair_offset` — the mesh-derived-mount precedent),
  `tools/bake_people_cars.gd:26,59` (the stretch), `tests/sim_test.gd:7769`
  (`turn_signals_blink_before_turns`), `tests/sim_test.gd:8890`
  (`cafe_sitters_on_the_rig` — the mesh-probe scenario family)

## What

Every car in the fleet wears four floating amber slabs. The corner blinker
nodes `BlinkFL/FR/RL/RR` (`scenes/car.tscn:111-129`, boxes 0.14 × 0.12 × 0.30 m,
`Mesh_blinker` at `car.tscn:56-58`) sit at the car-local stations
(±0.85, 0.82, ∓1.95) — forward is −z, right is +x (`car.tscn:110`) — and none
of that surface exists on the T-124 sedan. Probe-measured this session against
`assets/generated/models/cars/car_paint.res` (438 vertices; a throwaway
`SceneTree` probe in the `tools/probe_sit_geometry.gd` family, deleted after
the numbers were recorded):

- Paint mesh AABB: x ±0.95, y 0.500–1.300, z −1.984–2.157.
- At the lamp stations (|z| 1.7–2.2, per x-side) the body reaches only
  **|x| = 0.697** and tops out at **y = 0.717 (front) / 0.700 (rear)** — the
  hood/deck top is a flat ~0.70 plane (the rear deck's y≈0.70 quad spans
  |z| ≈ 1.81–2.16, sampled at its corner vertices only).
- The lamp boxes (x 0.78–0.92, y 0.76–0.88) therefore hover in air: the nearest
  paint vertex is **0.094 m** from the front boxes and **0.117 m** from the rear
  boxes; within the lamps' own y-band (0.70–0.90) at |z| 1.85–2.05 the panel
  has **no surface at all** — nothing to sit on at that height at those
  stations.

History, stated accurately (git `log -S BlinkFL`): the blinkers were **added**
by T-134 (commit fcaf045, 2026-10-23), AFTER the T-124 Kenney swap (826f269,
2026-10-17) — they never sat on any body. Their offsets were chosen at the old
box-car corner convention (the 1.9 m physics box's flank reaches x ≈ 0.85–0.95)
and never measured against the stretched paint, whose corners taper away
underneath them (the bake squeezes the Kenney sedan ×1.267 wide / ×1.725 long
into the 1.9 × 1.45 × 4.4 box, `tools/bake_people_cars.gd:59`; width fills only
at the mid-body, the front/rear tapers).

**Fix — three parts:**

1. **Lens proportions.** `Mesh_blinker` 0.14 × 0.12 × 0.30 → a lens box
   **0.035 (x, proud) × 0.055 (y, tall) × 0.16 (z, long)** — the research's
   sedan-lens class (0.15–0.18 long × 0.05–0.06 tall × ≤0.04 proud, centimeters
   not decimeters). Long axis along the car (z) like today; the face looks
   outward. `Mat_blinker` (amber, emission 1.4) untouched — no housing, bezel,
   gasket or bulb geometry.
2. **The seat derives from the paint mesh at `_ready()`** — the
   `cafe_spawner.gd _hair_offset` precedent, so a future re-bake of
   `car_paint.res` can never strand the lamps again. New `_seat_blinkers()` in
   `scripts/car.gd`, called once from `_ready()` (after the material line,
   `car.gd:220-227`): per corner, find the closest point on the paint
   TRIANGLES to a fixed corner seed (≈ ±0.72, 0.74, ∓1.90 — a few hundred
   triangle closest-point tests, once per car, zero per-frame cost), take that
   triangle's geometric normal N, and set the node's `position` so the lens
   straddles the panel: center = hit point + N × (half lens height − sink),
   sink ≈ 0.01–0.02 (half-buried read), long axis along z, box axis-aligned.
   Point-on-triangles, not nearest-vertex: the paint mesh samples flat quads
   only at their corners, so a vertex-based seat can land between quads. The
   four `@onready` node paths (`car.gd:214-217`) and the scene nodes stay
   exactly where they are — only the node `position`s change at runtime. The
   scene's static transforms are re-seated to the measured surface
   (≈ ±0.63, 0.725, −1.90 front / +1.95 rear) as the fallback if the probe
   finds no triangle near a seed (push_warning once, `_hair_offset`'s guard
   shape); the mesh is a committed ext_resource and cannot be missing.
3. **The T-134 flash logic is byte-identical.** `_update_blinker`
   (`car.gd:565-579`), `_apply_blinker_meshes` (`car.gd:584-591`),
   the `blinker` property (`car.gd:163`), `blinker_lead` 12.0 / `blinker_hz`
   2.0 (`car.gd:78-79`), hidden-at-rest (`car.tscn:113`), the splat-planning
   contract (T-134 §5) — all untouched. This ticket moves WHERE the lamps sit,
   never WHEN they show.

The new seat (~0.70 m over the wheel-contact plane) stays inside the research's
legal R48 height band (350–1500 mm) and within 400 mm of the body's outermost
edge; the old y = 0.82 station is simply abandoned — the surface, not the band,
dictates the height.

**What this does NOT claim:** no side repeaters (four corners are enough —
research simplify list); no red rear lamps; no per-class lamp tint; no changes
to the physics box (`Shape_body` 1.9 × 1.45 × 4.4 stays — it already overhangs
the tapered paint, that is T-124's physics-vs-visual contract, not this
ticket's), the wheels, the flag/cooler/class-tint machinery, or the T-149
visitor roof-teller (separate open ticket); no input actions; no new scenes;
no light nodes (emissive mesh only, as today).

## Why

The owner's idea: the blinkers must be mounted ON the body — today four amber
slabs hover 9–12 cm off every sedan in the city, parked and moving, and the
float reads as a bug at any distance where cars are legible. The blinker tell
is load-bearing (T-134 §5): from the air you read which way a car will turn and
plan the splat lead on it, so the lamps must read as a real car's corner lamps,
not as detached noise — and every reference photo shows the same rule the
research states plainly: **a real indicator never hovers off the fender line**;
the lens sits in or on the panel at the corner. Player value: the city stops
wearing its rigging (Pillar 2 — a believable, reacting town), the tell reads
as an intent signal rather than a glitch, and the `_ready()` derivation makes
the mount self-healing against future car re-bakes — the same robustness the
café hair boxes bought in T-142.

## Acceptance criteria

- [ ] *(Gate 1b)* new `car_blinkers_sit_on_the_body` (the
      `cafe_sitters_on_the_rig` mesh-probe family, `sim_test.gd:8890`): a bare
      `CAR_SCENE` instance (the traffic-null escape hatch) — for each of the
      four Blink nodes, build the lamp AABB from its BoxMesh size + node
      transform in Visual space, take the paint-mesh triangles near that
      station (same x-side, |z| within the lamp's z ± margin), and require the
      lamp box to **intersect ≥ 1 paint triangle** (clip the triangle polygon
      against the box's six planes; vertex-inside-box alone cannot see
      flat-quad interiors — the paint mesh is only 438 vertices sampled at
      quad corners). Four legs, one per corner, all true.
- [ ] *(Gate 1b)* same scenario also pins the lens class and the rest state:
      every Blink BoxMesh ≤ 0.20 (z) × ≤ 0.07 (y) × ≤ 0.05 (x) — no 0.3 m
      slabs — and all four nodes report `visible == false` at rest with their
      `Visual/Blink*` paths unchanged.
- [ ] *(Gate 1b)* `turn_signals_blink_before_turns` stays green **UNCHANGED**
      (`sim_test.gd:7769` reads only `car.blinker`, `car._flash_clock`,
      `car.blinker_hz` — placement-insensitive by construction; this is the
      tripwire that the tell's logic survived), and the full Gate 1b suite is
      green (`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`,
      0 failures).
- [ ] *(Gate 1)* `--import` and the 120-frame boot exit clean, zero ERROR
      lines.
- [ ] *(Gate 2)* autoplay green (`AUTOPLAY DONE ok=true restart=true`).
- [ ] *(Gate 3, screenshots)* eyes-on, via the pilot harness into `.captures/`:
      (a) a resting car's corners read as body — no floating slabs anywhere in
      the fleet, parked or moving; (b) a flashing turn reads as small amber
      lenses seated on the fender/deck corners from a quartering side view;
      (c) T-134's own line re-run — the blinker tell still reads from the air
      while planning a splat on a turning car.

## Verification

Gate 1 (`--import` + 120-frame boot) · Gate 1b full suite with the new
`car_blinkers_sit_on_the_body` registered in `_run_scenarios` and its row added
to the Gate 1b table in `VERIFICATION.md` **in the same change-set** · Gate 2
autoplay · Gate 3 the three screenshot lines above.

**Red-before probe to record when landed:** with the old scene transforms
restored (or `_seat_blinkers()` skipped), `car_blinkers_sit_on_the_body` fails
on all four intersection legs — measured this session, the old boxes clear the
nearest paint vertex by 0.094 m (front) / 0.117 m (rear) and no station-band
surface exists at their y — while the rest of the suite stays green.

**Tuning latitude:** sink depth (0–0.03 m), the corner seeds, and the lens
dimensions within the research class (0.14–0.20 long × 0.04–0.07 tall ×
0.02–0.05 proud) may move under Gate 3 without a new ticket — the Gate 1b
assert bounds and the untouched-flash contract are what stay fixed. Record the
landed values here like T-134's "Tuned values".

## References

Research ran for this ticket — note
[`docs/references/car-indicator-lamps/research.md`](../references/car-indicator-lamps/research.md)
(fetched 2026-11-03) and all 8 images in that directory (each opened in this
session before the What section was written; licenses in `credits.md`):

- `aventador-indicator.jpg` — the modern flush-set case: a small horizontal
  lens strip seated IN the fender panel behind the wheel arch, no bezel
- `dodge-charger-rear-indicator.jpg` — rear lens in a thin bezel, mounted in
  the body panel, a couple of decimeters at most
- `ford-cortina-full-car.jpg` · `gordon-keeble-front-corner.jpg` — corner
  indicators hug the car's extreme front corners, integrated at the body edge
- `isetta-front-indicator.jpg` · `nash-600-front-indicator.jpg` — the bezel
  variant: small lens on a base that follows the panel, proud centimeters
- `vw-beetle-fender-indicator.jpg` — the extreme case: the bezel conforms to
  the curved fender top, the amber lens angled forward/outward, touching the
  panel everywhere
- `vw-passat-mirror-repeater.jpg` — the side-repeater variant (NOT copied —
  four corners are enough for the tell)

The facts the implementation MUST respect (orientation first):

1. **The lens touches the body, and its face looks outward from the car** —
   front lamps forward-and-outward, rear lamps rearward-and-outward, seated in
   or on the panel (flush like the Aventador/Charger, or on a conforming base
   like the Beetle/Isetta/Nash). A real indicator never hovers off the fender
   line — that is the entire defect this ticket fixes.
2. **Centimeters, not decimeters:** typical sedan corner lenses run
   ~100–200 mm long × 50–80 mm tall, protruding centimeters; the game lens is
   0.15–0.18 × 0.05–0.06 × ≤0.04 m against today's 0.14 × 0.12 × 0.30 slab.
   Mount height stays legal by construction (the ~0.70 m seat is inside R48's
   350–1500 mm band, within 400 mm of the body edge).
3. **Amber only, four corners, no housings:** one flat emissive amber box per
   corner reads correctly at game scale — no bezel/gasket/bulb geometry, no
   red rear section, no side repeaters. The 2 Hz square-wave flash
   (`blinker_hz`, top of the legal 60–120 pulses/min band) is T-134's and is
   untouched here.

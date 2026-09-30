# T-037 — HUD bread pointer & off-city "city that way"

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-005 (bread) · T-019 (HUD outline style) — both done
- **Refs:** UI/UX lane playtest, sweep 1 (2026-09-29); evidence cited inline

## What

A minimal HUD wayfinding affordance — no minimap:

- **`%BreadPointer`** — a new Label (unique name in owner) in the HUD
  CanvasLayer of `scenes/main.tscn`, left column under the hint block (below
  HintLabel's `offset_bottom` 88, e.g. top 92), styled exactly like the hint
  line: 14 px, `outline_size` 4, `font_outline_color` `Color(0, 0, 0, 0.85)`,
  white @ 0.75 (`scenes/main.tscn:88-98` is the template). Hidden when it has
  nothing to say. If T-040's combo strip lands first, stack beneath it.
- **`nearest_crumb(pos: Vector3) -> BreadCrumb`** on `scripts/bread_spawner.gd`
  — the living crumb closest to `pos` by squared distance over
  `living_crumbs()` (`scripts/bread_spawner.gd:50`), `null` when none.
  Hand-placed elder crumbs (`drop_crumb`, `scripts/bread_spawner.gd:92-98`)
  join `_crumbs` like any other, so they are found too. The query is trivially
  cheap: ≤ 40 crumbs alive (`target_count`, `scripts/bread_spawner.gd:15`) —
  the capture recorder already runs the same nearest-N scan every frame
  (`tests/capture_recorder.gd:338-350`).
- **Update in `Main._process`** (`scripts/main.gd:83-95`, alongside the stats
  line), two modes:
  - **Bread mode** (pigeon inside the city ring): the pointer shows a chevron
    plus the distance in metres to
    `nearest_crumb(player.global_position)`. The chevron is a small rotatable
    element whose `rotation_degrees` carries the bearing from the pigeon's
    heading (`-transform.basis.z` projected flat) to the crumb — 0 =
    screen-up = nose. The text reads `"bread 23 m"`. An arrow glyph is
    acceptable instead of a rotatable element IF the default font renders it
    cleanly; the direction value (rotation or a public token-table index) is
    the assertion surface either way.
  - **City mode** (pigeon beyond the ring — horizontal distance from the city
    centre > `city_span * 0.5`, i.e. 117 m of the 234 m span,
    `scripts/city.gd:137-142`): the same slot points home — chevron bearing
    to `city.spawn_point` (XZ), text `"city 131 m"`.
- No new @export tunables required; a public const token table only if the
  direction-token route is chosen over a rotatable chevron.

This does **not** claim: no minimap, no crumb counter, no pathing; the stats
line, hint and popups are untouched; scoring and hunger are untouched; the
crumb layout stays a pure function of the city seed
(`scripts/bread_spawner.gd:64`).

## Why

Bread is the survival loop's destination, but a crumb is a 0.16 × 0.10 × 0.12 m
pale-wheat box (`scenes/bread_crumb.tscn:14`, albedo 0.82/0.62/0.35 at `:9`)
on near-white pavement (sidewalk 0.62/0.61/0.58, plaza 0.70/0.66/0.58 —
`scripts/city.gd:28-29`). The UI/UX lane's evaluator independently confirmed
the invisibility on a captured frame: at state frame 300 the grounded,
spawn-adjacent pigeon had 4 crumbs within 30 m and none is visible in the
frame image. The city is also small at flight speed: 234 m across
(`scripts/city.gd:141-142`, 7 × 32 + 10) is ~10 s at the lane-measured
19–24 m/s cruise — beyond the ring there is no affordance at all while the
hunger clock keeps draining. The only teacher today is the 14 px hint line
("land by bread to eat", `scripts/main.gd:11`, rendered at
`scenes/main.tscn:88-98`) — it names bread but never says where it is.

## Acceptance criteria

- [x] `BreadSpawner.nearest_crumb(pos)` returns the living crumb nearest `pos`
      (`null` when none), through the real seeded spread — Gate 1b only
      (`query`/`none` arms of `hud_bread_pointer_tracks_nearest_crumb`)
- [x] Inside the ring the pointer names the nearest crumb: its distance text
      matches the true player→crumb distance within 1 m, and flipping the
      pigeon's yaw 180° at the same position flips the pointer to the opposite
      bearing — Gate 1b only (`dist`/`bearing`/`flip` arms)
- [x] Approaching the pointed-at crumb decreases the readout across two known
      positions — Gate 1b only (`approach` arm: 10 m → 3.3 m hover legs)
- [x] Consuming the pointed-at crumb through the real eat path (grounded
      waddle-in; `main.gd:60-61` wiring) re-aims the pointer at the
      next-nearest crumb — Gate 1b only (`reaim` arm)
- [x] Beyond the ring (> `city_span`/2 from the city centre) the same slot
      switches to city mode: text names "city", distance ≈ horizontal distance
      to `city.spawn_point` ± 2 m, direction pointing back — Gate 1b only
      (`city` arm)
- [x] The pointer carries the T-019 outline treatment (14 px, outline 4,
      `Color(0, 0, 0, 0.85)`) and is legible over pavement and sky — [screenshot]
      resolved theme getters machine-checked (`style` arm); autoplay/pilot
      frames show `▲ bread 6 m` over white pavement at the plaza, `↖ bread
      30 m` over bright sky mid-flight, and `▼ city 136 m` on the grass apron
      (137 m out, chevron pointing home) — at-a-glance judgement is the
      pending human pass below
- [x] The nearest-crumb query stays inside the frame budget:
      `density_cpu_budget` keeps passing with the pointer live (median
      251.5 ms per 100 physics frames vs the 750 budget)
- [x] Existing bread/city scenarios pass unchanged (`crumbs_respawn`,
      `restart_resets_run`) — the layout RNG sequence is untouched

## Verification

Gate 1 (import + 120-frame boot, both exit 0, zero ERROR lines) + Gate 1b —
new scenario `hud_bread_pointer_tracks_nearest_crumb` through the real Main
scene, registered in `_run_scenarios` immediately after
`_scenario_restart_resets` and BEFORE `_scenario_hud_hunger_tiers` (the T-019
window: unpaused tree, no live Main instance; same cleanup tail as
`_scenario_hud_hunger_tiers` — `free()` → `Game.hunger.player = null` →
`Game.reset_run()`; `tests/sim_test.gd:1864-1948` shows the pattern).
Scenario shape: instantiate Main in its own space; compute the expected
nearest crumb independently from `living_crumbs()` distances; teleport the
pigeon with `reset_flight(pos, yaw_deg)` (`scripts/player.gd:111`); assert
bearing, distance, the decrease on approach and the 180° flip; eat the crumb
via the grounded waddle-in `_scenario_bread_eating` uses
(`tests/sim_test.gd:783-804`); assert re-aim; teleport beyond the ring; assert
city mode. Full suite stays green, explicitly `hud_hunger_warning_tiers`,
`restart_resets_run`, `crumbs_respawn`, `density_cpu_budget`. Gate 2: the
autoplay asserts nothing about the pointer — unaffected. Gate 3:
[screenshot] pass — the arrow is readable at a glance mid-flight and city
mode reads clearly on the cruise home.

## Landed (implementation notes)

- `scripts/bread_spawner.gd` — `nearest_crumb(pos)` over `living_crumbs()` by
  squared distance, `null` when none (same nearest-N scan the capture
  recorder runs every frame; ≤ 40 crumbs). **Latent bug fixed en route:**
  `_spawn_at` assigned the WORLD value `city.to_global(spot)` to the LOCAL
  `position` — correct only while Main sits at the origin, so any offset
  Main instance (every sim-harness instantiation) double-offset all 40
  seeded crumbs. Now parents first, then `global_position` (the pattern
  `drop_crumb` already used). No RNG draws touched — same picks, same order,
  identical layout fingerprints; at the origin the assigned value is
  bit-identical, so `crumbs_respawn` / `restart_resets_run` pass unchanged.
- `scenes/main.tscn` — `%BreadPointer` Label under the hint block (top 92,
  left 34 so the chevron owns the 16 px column margin), styled exactly like
  HintLabel (14 px, outline 4, `Color(0, 0, 0, 0.85)`, white @ 0.75), hidden
  by default; child `Chevron` Polygon2D (black @ 0.85, uniform 1.5 px inset
  via a `Fill` child in white @ 0.75) rotates instead of a font glyph — no
  dependency on default-font arrow coverage. No new SubResources, so
  `load_steps` is unchanged. T-040's combo strip can stack beneath (top 112).
- `scripts/main.gd` — `_update_bread_pointer()` in `_process` beside the
  stats line: beyond `city_span * 0.5` flat from `city.global_position` the
  slot points home at `city.spawn_point` ("city <m> m", horizontal
  distance); inside, at `nearest_crumb()` ("bread <m> m", 3D distance);
  hidden when no crumb is alive. Chevron `rotation_degrees` =
  `-heading.signed_angle_to(flat_to_target, UP)` in degrees (canvas rotation
  is clockwise-positive, the angle CCW-positive from above); degenerate
  geometry (target dead below/ahead-at-zero) keeps the last bearing. The
  chevron reads the pigeon's NOSE, so it can lag the camera's smoothing
  mid-turn — by design.
- `tests/sim_test.gd` — `_scenario_hud_bread_pointer_tracks_nearest_crumb`
  registered in the T-019 window (after `restart_resets`, before
  `hud_hunger_tiers`), same cleanup tail. The independent expected nearest
  comes from a private `_scan_nearest_crumb` over `living_crumbs()` — never
  through `nearest_crumb()`, which is the code under test. The hover leg
  offsets (0, 8, 6) rather than straight above: a target dead below zeroes
  the flat bearing. The eat leg mirrors `_scenario_bread_eating`'s
  drop-waddle and stops the waddle the frame the crumb frees.
- No input changes → controls tables untouched; no new autoloads/addons.

## Tuned values (final)

- Pointer: top 92 / left 34, 20 px row; font 14, outline 4,
  `Color(0, 0, 0, 0.85)`, text `Color(1, 1, 1, 0.75)`
- Chevron: outer triangle (−5, 3.6) (5, 3.6) (0, −5.4) in `Color(0, 0, 0,
  0.85)`, fill inset 1.5 px in white @ 0.75; sits at label-local (−12, 10)
- Modes: city beyond `city_span * 0.5` (117 m of the 234 m span) flat from
  the city centre; bread distance is 3D, city distance is horizontal
- Cost: one 40-crumb scan per `_process` frame (inside the T-018 budget —
  `density_cpu_budget` median 251.5 ms/100 frames vs 750)

## Verification

Gate 1 (import + boot, both exit 0; the lone "resources still in use at
exit" line reproduces on the untouched base commit — pre-existing), Gate 1b
74/74 PASS exit 0, Gate 2 `AUTOPLAY DONE ok=true … restart=true` (fps 136,
`eaten=1` through the re-parented spawner). **Pending human playtest
(Gate 3):** the arrow readable at a glance mid-flight, city mode reading
clearly on the cruise home, pointer legible over pavement and sky without
crowding the hint.

# T-008 — Cars v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** M · **Status:** done
- **Depends on:** T-004, T-006
- **Refs:** `docs/DESIGN.md` → Tourists & cars · Pillar 3

## What

The easy-money targets:

- Parked cars along curbs (static, easy) and looping traffic on roads
- Traffic: simple lane-follow, stop-if-blocked; nothing fancier in M1
- Hit by poop → honk + score event (30 pts base per DESIGN)
- Layer 4 `vehicle`

## Why

Per pillar 3, cars are the deliberately easy, low-value target — the game's "free
points" valve and contrast to tourist trick shots.

## Acceptance criteria

- [x] Parked and moving cars both register splats and honk
- [x] Traffic loops the blocks without overlapping or getting stuck at corners
- [x] Cars read as visibly bigger/easier targets than tourists (the points contract)
- [x] Getting splatted doesn't derail traffic logic (the loop continues)

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: splat a parked car and a moving car, follow one
traffic loop for a full circuit.

**Machine-verified (Gate 1b, `tests/sim_test.gd`):**

- `cars_traffic_loops_blocks` — 20 traffic cars loop their block rings at lane
  speed for 8 s: every car covers ground (nothing gridlocks), the fleet rounds
  corners (waypoints advance), no two cars ever overlap (sampled pairwise gaps
  stay above 2 m), and the parked fleet sits exactly where it was seeded.
- `car_splat_honk_and_continue` — a parked car takes a real lobbed splat (the
  duck-typed `on_splatted` fires, the car honks, the score event relays through
  the spawner, the car stays parked) and a traffic car hit through the same
  entry keeps driving its loop.

**Autoplay (Gate 2):** the pilot now pulls the poop trigger early for cars too
(wider lead tolerance — the easy target), and the DONE line reports `honks`.
Cars are visible in the screenshots (parked along curbs, looping the ring roads).

## Implementation notes

- `scenes/car.tscn` + `scripts/car.gd` — one scene for both modes (`Mode.PARKED`
  sits at the curb, `Mode.TRAFFIC` loops). Layer 4 `vehicle` (collision_layer 8,
  mask 1: glue to the asphalt only). Collider 1.9 × 1.45 × 4.4 m vs the
  tourist's 0.5 × 1.1 capsule — visibly the bigger target.
- `City.traffic_loop(center)` — ring-road corner waypoints at
  `block_half + traffic_lane_offset` (14.5 m). Right-hand traffic: the
  traversal turns right at every corner, so the four loops meeting at an
  intersection each cut a **disjoint corner** — cross traffic can never meet,
  it can only queue (same-direction shared lanes between neighbouring blocks).
- `City.parking_spots(center)` — 8 curb spaces per block (2 per edge) at
  `block_half + parking_offset` (12.05 m), yaw-aligned with the adjacent lane's
  flow, clear of intersection corners; deterministic, no RNG.
- `CarSpawner` (`scripts/car_spawner.gd`) — mirrors the tourist service: 20
  traffic + 16 parked kept alive around the player, seeded from the city seed,
  recycled onto fresh blocks/spots when the player moves on. Deterministic
  spread fractions so two cars sharing a ring never start overlapped.
- Honk = bright emission flash on the body for now; the audio horn arrives with
  T-012. Score stub in `main.gd` adds the car's `points_value` (30) — T-009
  replaces the stub with the real table.
- The front zone (`FrontZone`, 2 × 1.6 × 6 m box ahead of the bumper, masking
  player·npc·vehicle) drives **proportional** follow control: allowed speed
  grows with the gap (`follow_gap` 5.6 m, `follow_gain` 1.8/s), so cars brake
  smoothly, queue at ~1 m bumper gaps and creep forward as gaps open — a binary
  stop/go dead-locks under the intermittent blocks of a shuffling queue.
- Corners are taken wide and slow (`waypoint_reach` 4.5 m adoption,
  `corner_speed` 3.5 m/s within 7 m and until yaw levels, `turn_rate` 5/s), and
  each adopted corner arms an **on-lane rejoin point** 5 m down the new leg —
  that keeps every turn inside its own intersection quadrant and the car ON its
  lane (a bare far-corner aim drifts off-lane until the body scrubs a curb).
- Spawn/recycle snapping targets the far corner of the **containing leg**
  (`_retarget_loop`) — nearest-corner snapping flips cars around when they land
  just past a corner, and a reversed car drives into oncoming traffic.
- City fix that traffic forced: the road **colliders** are now flush at
  `road_slab_height` — the 5 mm z-fighting offset between crossing slab visuals
  used to exist on the colliders too, and a 5 mm lip is an invisible wall for a
  box-shaped car (round capsules rolled over it, which is why T-003/T-007 never
  hit it).

## Tuned values (`@export`)

| Where | Value |
| ----- | ----- |
| `Car.cruise_speed` | 6.0 m/s (× per-car pace 0.9–1.15) |
| `Car.corner_speed` / `corner_slow_range` | 3.5 m/s / 7.0 m |
| `Car.follow_gap` / `follow_gain` | 5.6 m / 1.8 1/s |
| `Car.accel` / `brake_decel` | 4.0 / 12.0 m/s² |
| `Car.turn_rate` / `waypoint_reach` / `rejoin_dist` | 5.0 1/s / 4.5 m / 5.0 m |
| `Car.points_value` / `honk_flash_seconds` | 30 / 0.8 s |
| `CarSpawner.target_moving` / `target_parked` | 20 / 16 |
| `CarSpawner.recycle_radius` | 100 m (must clear spawn_max_dist 70 + ~21 m ring diagonal) |
| `City.traffic_lane_offset` / `parking_offset` | 3.5 m / 1.05 m beyond the block edge |

## Pending human playtest (Gate 3)

- [ ] Parked cars line the curbs and traffic loops the blocks; cars never overlap or gridlock at corners
- [ ] A splat on a parked car and on a moving car both honk (body flash) and tick the score by 30
- [ ] Cars read as visibly bigger, easier targets than tourists; a moving car is hittable with modest lead
- [ ] Follow one car for a full block circuit — it keeps looping normally after being splatted

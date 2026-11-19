# Windows dev probe runs (T-215, 2026-11-17/18)

Machine: the dev desktop — RTX 4080, 1296×759 window, opengl3 (GL
Compatibility) unless noted. The ticket's committed table first (the
`perf_probe` runs of 2026-11-17/18), then the T-215 storm bisect sessions.

## The rendered pose table (perf_probe, the ticket's §1 data)

| pose | fps | draws | prims |
| --- | --- | --- | --- |
| spawn_ground (FIRST pose) | **1** | — | — |
| spawn_ground (later in session) | 144 | — | — |
| aerial poses | 58–144 | 301–947 | 518k–898k |

The first-pose stall reproduces on every platform (pitch/yaw/altitude
variants at the same pose all run 144) — the one-time pipeline-compile cost
of the world's first rendered frame. In the GAME path the stepped boot's
paint-between-phases already pays that compile behind the menu handoff
(T-129), so the player's first in-game frame is warm; the stall as measured
is the probe's (perf_probe renders the world for the first time at pose 1).
The box's awake table shows the same shape: pose 1 at fps=1, every later
pose 51–60.

## The headless frame path (cpu_probe, FIXED probe)

| machine | fps_eq | wall (300 frames) | nodes |
| --- | --- | --- | --- |
| Windows dev | 128.6 | 2.33 s | 14,436 |
| gate box | 144.9 | 2.07 s | 14,438 |

The headless frame path is NOT anomalous on either machine — the committed
probe's "hang past 5 min" was its own invalid monitor name
(`PHYSICS_3D_STATS`), which failed the script load and left the scene
running scriptless forever without its `quit()`.

## The storm bisect (storm_probe, pre-fix tree)

Windows dev, opengl3, hunger locked, teleported to the SE residential edge
(world 1500, 40, 900 — inside the tailgate census window). `phys_ms` is
`Performance.TIME_PHYSICS_PROCESS` averaged over the window (×1000 s→ms);
`max` is the window's worst frame. Two runs, 10 s / 2 s windows:

| window | avg phys ms | max phys ms | fps |
| --- | --- | --- | --- |
| control_out (spawn corridor) | 6.0 / 3.0 | 12.9 / 7.1 | 140 / 139 |
| zone_base | **53.1 / 168.4** | **345.3 / 271.4** | 105 / 59 |
| zone_cars_all_off | 3.6 / 17.3 | 9.0 / 70.7 | 133 / 107 |
| zone_spawner_off | 4.8 / 2.8 | 9.3 / 2.8 | 123 / 119 |
| zone_tourists_off | 12.5 / 4.4 | 72.7 / 7.5 | 130 / 116 |
| zone_player_off | 7.0 / 6.6 | 10.9 / 7.5 | 124 / 123 |
| zone_blocks_truncated | 7.2 / 5.7 | 14.5 / 7.9 | 123 / 119 |
| zone_freeze_on | 3.1 / 6.3 | 7.8 / 8.5 | 131 / 124 |
| zone_restored | 6.6 / 3.0 | 11.6 / 3.5 | 121 / 123 |

Attribution: the CARS own the storm (all-off restores the control floor);
the SPAWNER's per-scan churn drives it (spawner-off with cars still driving
also restores the floor); tourists and the player do not own it. The
`blocks=0` print killed the `_refresh_block` hypothesis outright — the graph
populate path passes an EMPTY block-centers cache, so the per-frame
nearest-block scan early-returns on Ames.

## The placement bench (storm_probe bench, pre-fix vs post-fix)

| read | pre-fix | post-fix |
| --- | --- | --- |
| `park_spots_near(lxz, 90)` | 26 µs/call | 18 µs/call |
| one recycle scan (`_recycle_far`) | 15 µs | 12 µs |
| `nearest_runs(lxz, 12)` | **10,513 µs/call** | **79 µs/call** |

The 10.5 ms brute-force `nearest_runs` was the storm's engine: 26 far cars
× re-seats per 0.5 s scan ≈ 0.27–0.5 s of script physics time per wall
second, matching the T-209 audit's `phys µs 330–530 ms`.

## The fix's equivalence + budget windows (the Gate 1b scenario's own reads)

`traffic_placement_budget` (100 × `nearest_runs(…, 12)` + 20 ×
`edges_in_band(60, 140)` at the zone anchor, 6 anchors' brute-force
equivalence): **BAD=0 / 7.1 ms window** on dev (the suite's SIM DATA line,
`SIM SUMMARY: 0 failure(s)`; the standalone iteration check read 7.3).
Post-fix storm windows: zone_base 10.0 avg / 10.6 max (was 53.1 / 345.3)
at 93–120 fps.

## The respawn ejection (the T-214 flag, caught again in passing)

Session `t215b` (pilot, hunger locked): a teleport into the zone —
world (1192, 61.6, 300), the Hilton flank — ACKED at the target
(`pilot_dev` `p=[1192.0, 61.6, 300.0]`, three state samples holding it:
t_ms 12144/12157/12160) and read **home at the spawn corridor one sample
later** (t_ms 12171, p=(380, 0.6, −294), then grounded there at 12370).
`off_world_resets` stayed 0 across the whole window and the fleet/city
rows continue unchanged (no regen, no restart) — neither known reset site
fired. The T-209 audit's occurrence read "~0.6 s after arrival"; this one
ejected within ~27 ms. Not reproduced on the second teleport
((1500, 40, 900) — the storm bisect's pose, which held). Flag stays live
for a follow-up ticket; recorded here so the next rig starts from two
data points.

# Gate box probe runs (T-215, 2026-11-18)

Machine: the T-213 canary — `ubuntu-basement-box` (192.168.1.247), i7-6700
quad + Intel HD 530 (SKL GT2) + 30 GB, idle (load ≈ 0.8–1.1), Ubuntu,
kernel 7.0.0-43-generic, Mesa 26.0.8-1ubuntu0.3, Xorg :98
(`pigeon-xorg.service`, modesetting + glamor, AIGLX iris, DRI3/DRI2). The
iGPU drives a physically connected Philips monitor (HDMI-A-2, EDID 2024w13).
All Godot runs: `--rendering-method gl_compatibility --rendering-driver
opengl3 --audio-driver Dummy`, nice'd, on :98 unless marked headless.

## The DPMS experiment (the root cause)

`DISPLAY=:98 xset q` after the box sat idle: **"DPMS is Enabled / Monitor is
Off"** (600 s Standby/Suspend/Off timers). Every GL present on the display
crawled to ~1 Hz with the panel asleep:

| read | panel asleep | panel awake (`xset dpms force on`) |
| --- | --- | --- |
| `glxgears` | 1.3 fps (5–7 frames in 5 s) | **60.5 fps** |
| one-cube Godot scene (`--script` tri rig) | 1.0 fps | **57.0 fps** |
| game probe poses (perf_probe) | 1 fps at every pose | **51–60 fps** |
| DRI2-disabled / DRI3-disabled glxgears | 1.3 fps (both) | — |

DPMS disable/enable made no difference while the panel stayed asleep — the
state of the PANEL, not the DRI path, throttles the present. glxinfo
throughout: "direct rendering: Yes, Accelerated: yes, Mesa Intel HD 530" —
the context was hardware GL all along; the swaps were landing in a
power-saving panel. The T-213-era 56 fps autoplay ran while someone was
using the box; the 1 fps era began when the idle timers slept the display.

## The awake pose table (perf_probe, panel awake)

| pose | fps | draws | prims |
| --- | --- | --- | --- |
| spawn_ground (FIRST pose) | 1 | 549 | 807k |
| campus_hover | 51 | 301 | 831k |
| campustown_strip | 58 | 593 | 771k |
| stadium | 60 | 947 | 886k |
| downtown | 60 | 239 | 518k |
| laverne | 60 | 522 | 759k |
| overview_high | 60 | 496 | 822k |
| bisect_spawn_pitch/yaw/alt | 59–60 | 559–661 | 790k–898k |
| family-hide sweep (all families) | 59–60 | 351–549 | 702k–807k |

Draw counts byte-identical to the dev table (the ticket's §1 note:
"identical draw counts to Windows"). Every pose clears the 30 fps gate bar
at full quality — **the box needs no quality tier (avenue C not
warranted)**. The first-pose stall is the shared pipeline-compile cost
(dev shows it too; the game's stepped boot pays it behind the menu
handoff).

## The frame split (frame_probe + storm_probe on :98, panel asleep)

Per-frame samples at fps=1, ~782–956 draws, **pipeline compilations 0**
(all four PIPELINE_COMPILATIONS_* counters flat — not a shader-compile
loop): dt ≈ 995–1028 ms/frame, TIME_PROCESS ≈ 940–980 ms, TIME_PHYSICS ≈
7–15 ms. The same frame headless (no GL): process 2–4 ms at 135–144 fps.
So ≈96 % of the asleep frame is the main-thread render/submit step blocked
in the sleeping panel's present path — the split that sent the
investigation to the display instead of the scene tree.

## The headless reads (CPU side, no GL)

| probe | read |
| --- | --- |
| cpu_probe (fixed) | fps_eq 144.9, wall 2.07 s / 300 frames, nodes 14,438 |
| storm_probe headless, control_out | phys 18.7 ms avg |
| storm_probe headless, zone_base (pre-fix) | phys 38.2 avg / 129.1 max |
| storm_probe headless, zone_cars_all_off | phys 10.4 avg |
| storm_probe headless, zone_spawner_off | phys 12.6 avg |

The box's CPU runs the whole live game headless at ~140 fps even through
the zone burst — the worst headless frame (129 ms ≈ 7.7 fps) is nowhere
near the 1 fps the rendered path showed with the panel asleep. The box's
scene processing was never the 1 fps driver; the storm's shape
(cars/spawner-owned) matches dev at ~1× scale.

## The gate runs (tools/gate-box.sh at the branch tip 7438ecbd, the NEW script)

| run | result |
| --- | --- |
| full gate, floor=30 | GATE1 PASS · GATE1B PASS checks=165 · GATE2 FAIL rc=1 — `AUTOPLAY DONE ok=true … fps=30 … loop_ok=false eaten=0` (the fps floor arm HELD at 30 ≥ 30; the autoplay's own loop gate failed) |
| full gate, `GATE2_FPS_MIN=999` | GATE1 PASS · GATE1B PASS checks=165 · `GATE2 FAIL fps=31 below floor=999` (the floor's FAIL path, read independently of the autoplay's rc) |
| autoplay, `--disable-vsync` | fps=31, same loop failure — the box's spawn-view render rate is genuinely ~31, not a vsync half-rate lock |
| autoplay, HEADLESS | fps_eq 141, same failure byte-for-byte — not render-coupled |
| autoplay HEADLESS at the branch BASE (483e6de) | same failure byte-for-byte (eaten=0, splats=42, player=(386.9, 0.3, −296.6)) — **the Linux autoplay eat-loop divergence PREDATES T-215** |

The placement window on this box (the `traffic_placement_budget` SIM DATA
line, the box Gate 1b runs): **11.9 ms** for 100 `nearest_runs(…, 12)` +
20 `edges_in_band(60, 140)` calls at the zone anchor (dev: 7.1 ms; the
pre-fix brute force: ~10.5 ms PER call). The 60 ms budget const pins to
this box read.

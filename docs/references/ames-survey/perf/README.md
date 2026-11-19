# The Ames perf data pack (T-215)

The measured evidence behind T-215 — the entry-hardware performance ticket.
Everything here is committed probe output from real hardware, dated
2026-11-17/18. Two machines, three probes, one root cause each:

- **The gate box's "1 fps budget" was a sleeping monitor.** The T-213 canary
  (i7-6700 + Intel HD 530, Ubuntu, hardware GL on Xorg :98) DPMS-powers its
  connected Philips panel off after 600 idle seconds, and while the panel
  sleeps the GL present path crawls to ~1 Hz — `glxgears` included. Woken,
  the same box runs the resident world at **51–60 fps at every probe pose**
  (identical draw counts to the dev table). The ticket's headline numbers
  ("fps=1 at EVERY pose", the 103 s autoplay at `loop_ok=false`) were
  measured into a sleeping panel. `tools/gate-box.sh` now wakes the display
  before Gate 2 and enforces the 30 fps floor, so the canary can never again
  measure the monitor's power state instead of the hardware.
- **The tailgate traffic storm was the traffic graph's placement queries.**
  `AmesTrafficGraph.nearest_runs()` / `edges_in_band()` walked ALL 2,044
  runs' EVERY segment per call — 10.5 ms per call in GDScript — paid per
  placement attempt inside the recycle machinery: 26 far cars re-seating in
  the lot sea re-walked the whole graph per 0.5 s scan and ate 0.3–0.5 s of
  script physics time per wall second. The fix indexes the runs into a
  uniform cell grid (64 m cells, ring-by-ring queries); the same window now
  costs **7.1 ms on dev / 11.9 ms on the box** (the `traffic_placement_budget`
  SIM DATA line, 165 checks green on both machines), with byte-identical
  answers pinned by the same scenario at six anchors.

## Files

- `probe-windows-2026-11-18.md` — the Windows dev table (rendered poses +
  the headless cpu_probe read + the storm bisect on the dev desktop).
- `probe-gatebox-2026-11-18.md` — the gate box table (the asleep/awake
  experiment, the awake pose table, the frame split, the headless reads).

## The probes

| probe | what it measures | run |
| --- | --- | --- |
| `tests/tools/perf_probe.tscn` | rendered cost per pose + per family (draws/prims/fps, hide sweep) | `godot --rendering-driver opengl3 --path . res://tests/tools/perf_probe.tscn` |
| `tests/tools/cpu_probe.tscn` | headless scene-processing fps (no GPU) | `godot --headless --path . res://tests/tools/cpu_probe.tscn` |
| `tests/tools/storm_probe.tscn` | the storm A/B: boots the real game, teleports into the zone, toggles cars/spawner/tourists/blocks/freeze per window, benches the placement reads | `godot --path . res://tests/tools/storm_probe.tscn` |
| `tests/tools/frame_probe.tscn` | per-frame render-side monitors (draws, pipeline compilations, process/physics split) | `godot --path . res://tests/tools/frame_probe.tscn` |

(`cpu_probe` as first committed referenced `Performance.PHYSICS_3D_STATS`, a
member Godot 4.7 does not have — the script failed to load and the scene ran
scriptless forever without reaching its `quit()`: the "HEADLESS cpu_probe
hangs past 5 min" flag in the ticket. Fixed to the real monitors; the headless
frame path itself is NOT anomalous — 128.6 fps_eq dev / 144.9 fps_eq box.)

## The machine gate

`tools/gate-box.sh` Gate 2 enforces **fps ≥ 30** on the autoplay DONE line
(half of the 60 Hz target — the owner's entry-hardware bar) and wakes the
gate display first (`xset dpms force on` + `xset -dpms` on :98).
`GATE2_FPS_MIN=<n>` overrides the floor for testing the FAIL path itself.

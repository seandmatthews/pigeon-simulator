# T-046 — Add a predicted-impact ring for drops — the bombsight behind T-025's bigger ball

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-006 (poop mechanic, landed)
- **Refs:** sweep 2 sessions `vds2b`/`vds2d` (all readings recorded below; the captures live in the lane
  worktree's gitignored `.captures/`); related but independent: T-025 (proposed)

## What

A bombsight: a small flat ring marking where the airborne dropping will land.

- New `scripts/poop_marker.gd` (`class_name PoopMarker extends Node3D`) +
  `scenes/poop_marker.tscn` — visual only, no physics nodes at all (nothing to get
  a layer/mask wrong, the pigeon_visual precedent). A flat ring (TorusMesh, outer
  radius ~0.8 m) in an unshaded emissive warm material (T-025's planned
  (0.85, 0.78, 0.55) family), lifted ~0.03 m along the surface normal to clear
  z-fighting (the `splat_lift` precedent, `scripts/poop.gd:23`), pulsing gently
  (scale ~±10 % at ~2 Hz) while the drop is airborne.
- Prediction: `func track(drop: Poop)` snapshots `drop.global_position` +
  `drop.linear_velocity`, then marches the analytic parabola under
  `drop.fall_gravity` (12 m/s², `scripts/poop.gd:18`) in fixed 0.05 s steps capped
  at `drop.max_lifetime`, casting one segment ray per step against the physics
  world; the first hit places the ring on that surface along its normal. Floors,
  roofs and walls all end the march.
- Spawn wiring in `scripts/main.gd`: `_on_player_pooped(poop)`
  (`scripts/main.gd:193`, already connected to `player.pooped` at line 64)
  instantiates the marker and calls `track(poop)`. The player stays decoupled —
  the marker is spawned by Main, the same decoupling shape the harness already
  asserts for poop.gd (`tests/sim_test.gd:1063`).
- Lifecycle: each physics frame the marker polls `is_instance_valid(drop)`; when
  the drop is gone — splat (`queue_free` in `_stick_splat`, `scripts/poop.gd:115`)
  OR `max_lifetime` expiry (`scripts/poop.gd:56-57`) — it fades out over ≤ 0.3 s
  and frees. One mechanism covers both ends honestly: a marker cannot distinguish
  splat from expiry, and in both cases its job is done. The marker also joins a
  `poop_markers` group, and `Main.restart_run()` — which already frees the
  `poops` group (`scripts/main.gd:244`) — gains the twin loop, so a restart
  mid-fall cannot strand a ring.
- Gate 1b: new scenario `poop_impact_marker_matches_fall`, placed next to the
  T-006 block and registered after `poop_event_target` (`tests/sim_test.gd:114`);
  VERIFICATION.md row + Gate 3 line in the same change-set.
- Docs step: append the A/B evidence below to T-025's Why section (a text edit —
  T-025 stays its own ticket and lands or doesn't independently).

What this does NOT claim: no change to drop physics, `BallMesh` or any T-006 code
path — the six `poop_*` scenarios are untouched; T-025's two `poop.tscn` property
edits (radius 0.12 + emission) are NOT part of this ticket — the evidence below
shows they do not fix visibility alone; prediction is approximate for wall/roof
hits by design (the machine leg pins the flat-ground case at ≤ 0.5 m; the
bombsight tolerance on raised surfaces is a Gate 3 eye judgement).

## Why

You cannot lead a target you cannot see. Across four play attempts the falling
dropping was invisible in EVERY captured frame — with the stock 0.07 m ball
(`scenes/poop.tscn:10-11`) AND with T-025's proposed bigger emissive ball — while
score ticks prove hits do land:

- session `vds2b` frames f00008868/f00008940 (stock ball mid-fall, state
  `poops=[[-51.28, 10.55, -90.12]]`): only bird + shadow in frame;
- session `vds2d` A/B with T-025's exact values applied (frames
  f00001596/f00001644, timed shots drop1-3.png): still no ball;
- frozen proof `stall_drop2.png` (+ zoom crop): state
  `poops=[[16.0, 5.64, -177.79]]` vs bird altitude 14.79 — the enlarged emissive
  ball frozen 9.15 m below the bird, empty grass where it should read — and
  `Score: 30` already ticked on the spawner-recycled car out on the apron: hits
  happen blind;
- `pause_drop.png`: at release the drop sits 0.38 m below the bird
  (`poops=[[16.0, 6.99, -32.08]]` vs alt 7.37) — occluded by the bird's own
  silhouette from the chase angle.

So T-025's own Gate 3 line ("reads as a bright dot for ~2 s of fall") cannot pass
at typical release speeds even with its values — verified by experiment, not
asserted. The genre-standard answer is the bombsight: mark where the drop WILL
land, so leading a tourist or car becomes aiming the glide, not tracking a speck.

## Acceptance criteria

- [ ] Gate 1b: `poop_impact_marker_matches_fall` — from
      `_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -12))` plus one poop tap,
      exactly one node sits in the `poop_markers` group
- [ ] Gate 1b: same scenario — the marker's global position is within 0.5 m of the
      impact point recomputed INDEPENDENTLY in the scenario (the no-self-test
      precedent of `_scan_nearest_crumb`, `tests/sim_test.gd:2122-2133`): p0 = the
      drop's actual spawn position, v0 = its inherited velocity, g = 12 down, flat
      ground y = 0 (analytic t = sqrt(2·19.7/12) ≈ 1.81 s → ≈ (0, 0, −21.75))
- [ ] Gate 1b: same scenario — after the splat fires (~1.8 s of fall) the marker
      is gone: the `poop_markers` group is empty within 0.5 s of the splat
- [ ] `poop_inherits_and_arcs`, `poop_grounded_no_drop`,
      `poop_cooldown_blocks_stream`, `poop_splats_ground_and_fades`,
      `poop_splats_wall`, `poop_event_reaches_any_body` and the full suite stay
      green unchanged — no physics touched
- [ ] A restart during a fall leaves no stranded marker: the `poop_markers` free
      loop in `restart_run()` exists, and `restart_resets_run` /
      `restart_same_seed_skips_rebuild` stay green (no marker is alive in those
      scenarios, so this criterion is code inspection plus the suite — honestly
      not a dedicated machine leg; the drop-validity poll is the primary cleanup)
- [ ] [screenshot] The ring reads against road AND grass at cruise, sits where the
      splat lands, pulses while the drop falls and vanishes on impact (Gate 3 —
      human judgement)

## Verification

Gate 1 (import + 120-frame boot; `--check-only` on `scripts/poop_marker.gd`) ·
Gate 1b full suite `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
including the new scenario, with the six untouched `poop_*` rows re-run explicitly ·
Gate 2 (autoplay: the pilot's existing lead-shot prediction now aims at a visible
ring; no autoplay script change expected, DONE line unchanged) · Gate 3: the
[screenshot] line above added to VERIFICATION.md's playtest list in the same
change-set, plus the T-025 evidence append.

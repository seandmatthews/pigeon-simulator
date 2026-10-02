# T-046 — Add a predicted-impact ring for drops — the bombsight behind T-086's bigger ball

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-006 (poop mechanic, landed) · builds on T-086 (bigger emissive drop ball, landed 2026-09-30 — this ticket is additive to it)
- **Refs:** re-based during the 2026-09-30 backlog audit (T-025 was superseded/adopted by
  T-086 in the meantime) · re-anchored 2026-10-01 against the current tree — every line
  citation re-derived, the spawn-wiring precedent upgraded to T-077's landed real-Main
  scenario, and the Gate 1 `--check-only` leg dropped (a `Poop`-typed script fails
  check-only on the known `Sfx` breakage — see Verification) · sweep-2 sessions
  `vds2b`/`vds2d` (pre-T-086 history; readings recorded below, captures live in the lane
  worktree's gitignored `.captures/` and are absent from this checkout)

## What

A bombsight: a small flat ring marking where the airborne dropping will land.

- New `scripts/poop_marker.gd` (`class_name PoopMarker extends Node3D`) +
  `scenes/poop_marker.tscn` — visual only, no physics nodes at all (nothing to get
  a layer/mask wrong, the pigeon_visual precedent). A flat ring (TorusMesh, outer
  radius ~0.8 m) in an unshaded emissive warm material — the landed T-086 ball's
  emission family `(0.85, 0.78, 0.55)` (`scenes/poop.tscn:7-9`) — lifted ~0.03 m
  along the surface normal to clear z-fighting (the `splat_lift` precedent,
  `scripts/poop.gd:23`), pulsing gently (scale ~±10 % at ~2 Hz) while the drop
  is airborne.
- Prediction: `func track(drop: Poop)` snapshots `drop.global_position` +
  `drop.linear_velocity`, then marches the analytic parabola under
  `drop.fall_gravity` (12 m/s², `scripts/poop.gd:18`) in fixed 0.05 s steps capped
  at `drop.max_lifetime` (12 s, `scripts/poop.gd:19`), casting one segment ray per
  step against the physics world; the first hit places the ring on that surface
  along its normal. Floors, roofs and walls all end the march. (The live drop body
  carries the default `linear_damp` 0.1 — the project default; Poop sets none and
  no project setting overrides it — so the real splat lands slightly short of a
  pure-gravity march, ~1.5 m at this rig's 20 m release (order-of-magnitude
  estimate, not machine-integrated). The machine leg below pins
  marker-vs-independent-recompute, both undamped; ring-vs-actual-splat agreement
  is the Gate 3 eye's, and the implementer may fold damping into the march if it
  improves that agreement.)
- Spawn wiring in `scripts/main.gd`: `_on_player_pooped(poop)`
  (`scripts/main.gd:320`, already connected to `player.pooped` at `:104` — the
  signal itself is `scripts/player.gd:28`) instantiates the marker and calls
  `track(poop)`. Its body today is a single `Game.on_poop_released` call
  (`scripts/main.gd:321`) — a clean insertion point. The player stays decoupled —
  the marker is spawned by Main, the same decoupling shape the harness already
  asserts for poop.gd (`tests/sim_test.gd:1484`).
- Lifecycle: each physics frame the marker polls `is_instance_valid(drop)`; when
  the drop is gone — splat (`queue_free` in `_stick_splat`, `scripts/poop.gd:115`)
  OR `max_lifetime` expiry (`scripts/poop.gd:56-57`) — it fades out over ≤ 0.3 s
  and frees. One mechanism covers both ends honestly: a marker cannot distinguish
  splat from expiry, and in both cases its job is done. The marker joins a
  `poop_markers` group in `_ready` (the `poops`-group precedent,
  `scripts/poop.gd:44`), and `Main.restart_run()` — which already frees the
  `poops` group (`scripts/main.gd:419-420`) — gains the twin loop, so a restart
  mid-fall cannot strand a ring.
- Gate 1b, two rigs — the marker exists only when a Main is alive (its spawn
  site is Main's own `$Player` wiring), so the two legs use different rigs:
  - `poop_impact_marker_matches_fall` on the bare `_player` rig (instantiated
    with no Main alive, `tests/sim_test.gd:69-71`; the bare-rig poop block in the
    run order — `tests/sim_test.gd:134-140` — runs exactly that way):
    `_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -12))` — the exact call shape
    `poop_cooldown_blocks_stream` already uses (`tests/sim_test.gd:1364`;
    `_set_up` signature at `:212`, `_tap` at `:225`) — plus one poop tap, then
    instantiate `poop_marker.tscn` directly and `track()` the drop the tap
    produced. Direct instantiation is what makes the clean flat-ground analytic
    legal (the test world's y = 0 Ground belongs to this rig,
    `tests/sim_test.gd:80`); it deliberately bypasses the Main spawn wiring,
    which the next scenario covers.
  - `poop_impact_marker_spawns_from_main` on the real-Main rig — with a landed
    precedent stronger than the T-010 pattern:
    `_scenario_poop_ready_indicator_tracks_cooldown` (T-077,
    `tests/sim_test.gd:1531`) already instantiates the real `main.tscn` parked
    in its own space (`:1534-1535`) and fires a REAL poop tap through it
    (`:1557`). Park this scenario's Main at its own clear slot the same way —
    juice's `(3500, 0, −3500)` corner is the established example
    (`_scenario_juice_hit_shake_pulse`, `tests/sim_test.gd:4735-4741`) — one poop
    tap on Main's Player → the `poop_markers` group gains exactly one node.
    Free the Main and clock the autoload out before returning (the T-077 cleanup
    shape, `tests/sim_test.gd:1621-1623`).
  VERIFICATION.md rows + Gate 3 line in the same change-set.

What this does NOT claim: no change to drop physics, `BallMesh` or any T-006 code
path — the six original `poop_*` scenarios and T-086's `poop_ball_visible` are
untouched. The bigger emissive ball this idea was prototyped behind already
landed via T-086 (radius 0.12 + emission, `scenes/poop.tscn:12-14`, collider
pinned at 0.07 by `poop_ball_visible`, `tests/sim_test.gd:1515-1517`); the ring
is purely additive to it. Prediction is approximate for wall/roof hits by design
(the machine leg pins the flat-ground case at ≤ 0.5 m vs an independent
recompute; the bombsight tolerance on raised surfaces is a Gate 3 eye judgement).

## Why

You cannot lead a target you cannot see. Pre-T-086 sessions (sweep 2) showed the
falling dropping was invisible in every captured frame — with the then-stock 0.07 m
ball and with T-025's proposed bigger ball — while score ticks proved hits landed
blind (`stall_drop2.png`: the enlarged ball frozen 9.15 m below the bird, empty
grass where it should read; `pause_drop.png`: at release the drop sits 0.38 m below
the bird, occluded by the bird's own silhouette from the chase angle). That
evidence became T-025 → T-086, which landed the bigger emissive ball, and its live
pre-check now reads the drop as a bright dot below the bird.

What a visible ball still does not give is ground-anchored lead: it shows where
the drop IS, not where it WILL land, and the occlusion-at-release problem stands
regardless of ball size. Leading a tourist or car means mentally integrating a
12 m/s² arc against a moving target. The genre-standard answer is the bombsight:
mark the predicted impact, so leading a target becomes aiming the glide, not
tracking a speck — the ring stays pinned to the ground while ball and target move.

## Acceptance criteria

- [ ] Gate 1b: `poop_impact_marker_spawns_from_main` — real-Main rig (parked in
      its own space, the T-077 pattern), one poop tap → exactly one node sits in
      the `poop_markers` group (proves the Main spawn wiring)
- [ ] Gate 1b: `poop_impact_marker_matches_fall` — bare rig, direct
      `poop_marker.tscn` instantiation + `track(drop)` from
      `_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -12))` plus one poop tap:
      the marker's global position is within 0.5 m of the impact point
      recomputed INDEPENDENTLY in the scenario (the no-self-test precedent of
      `_scan_nearest_crumb`, `tests/sim_test.gd:3668-3671`): p0 = the drop's
      actual spawn position, v0 = its inherited velocity, g = 12 down, flat
      ground y = 0 (analytic t = sqrt(2·19.7/12) ≈ 1.81 s → ≈ (0, 0, −21.75);
      both sides undamped — the real splat sits ~1.5 m short of this, which is
      the Gate 3 eye's note, not this assertion)
- [ ] Gate 1b: same scenarios — after the splat fires (~1.8 s of fall) the
      marker is gone: freed within 0.5 s of the splat on the bare rig; on the
      Main rig the `poop_markers` group is likewise empty again after the drop
      splats
- [ ] `poop_inherits_and_arcs`, `poop_grounded_no_drop`,
      `poop_cooldown_blocks_stream`, `poop_splats_ground_and_fades`,
      `poop_splats_wall`, `poop_event_reaches_any_body`, T-086's
      `poop_ball_visible` (collider pin at `tests/sim_test.gd:1515-1517`) and
      the full suite stay green unchanged — no physics touched
- [ ] A restart during a fall leaves no stranded marker: the `poop_markers` free
      loop in `restart_run()` exists beside the `poops` free loop
      (`scripts/main.gd:419-420`), and `restart_resets_run` /
      `restart_same_seed_skips_rebuild` (`tests/sim_test.gd:3593`, `:3655`)
      stay green (no marker is alive in those scenarios, so this criterion is
      code inspection plus the suite — honestly not a dedicated machine leg;
      the drop-validity poll is the primary cleanup)
- [ ] [screenshot] The ring reads against road AND grass at cruise, sits where the
      splat lands, pulses while the drop falls and vanishes on impact (Gate 3 —
      human judgement)

## Verification

Gate 1 (import + 120-frame boot; deliberately NO `--check-only` leg: the marker's
`track(drop: Poop)` signature drags `scripts/poop.gd` into the compile, poop.gd
references the `Sfx` autoload, and check-only mode never starts the project — so
the compile dies on the known repo-wide breakage (`VERIFICATION.md:385-390`) even
though poop_marker.gd itself references no autoload; `--import` plus the
120-frame boot exercise the script) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
(`VERIFICATION.md:31`) including the two new scenarios, with the six untouched
`poop_*` rows and `poop_ball_visible` re-run explicitly · Gate 2 (autoplay: the
pilot's existing lead-shot prediction (`tests/autoplay.gd:326`) now aims at a
visible ring; no autoplay script change expected, DONE line unchanged) · Gate 3:
the [screenshot] line above added to VERIFICATION.md's playtest list in the same
change-set, with the ring-vs-actual-splat note (undamped march vs damped body) as
explicit judgement context.

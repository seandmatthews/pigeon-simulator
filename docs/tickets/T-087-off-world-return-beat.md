# T-087 — Give the off-world return a visible "came home" beat — today it is a blank frame and a hard cut

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** visual-design · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-042 (the off-world guard this presents, landed).
- **Refs:** visual-design lane sweep 2, session `vds3a` (state/frame readings recorded below in text — the session dirs are not present in this repo, checked both checkouts 2026-09-30); [T-042](T-042-off-world-void-respawn.md) — its still-pending Gate 3 line is exactly the read this ticket fixes (`docs/tickets/T-042-off-world-void-respawn.md:83-87`, `VERIFICATION.md:297`).

## What

A presentation-only return beat, three files plus one new Gate 1b scenario. No
physics change — `reset_flight` (`scripts/player.gd:131-145`) and the verified
guard branch keep their shape except for one new line.

**Consolidation (2026-09-30):** absorbs [T-100](T-100-off-world-home-note.md) — land its "home again"
HUD note (the `%HomeNote` label + phase accumulator) in this same change-set, with ONE guard-fire
signal (merge the two proposed signal names into one) and one main.gd handler doing the poof, the
fade, the camera snap and the note.

1. `scripts/player.gd` — a new signal beside the others (`player.gd:14-23`),
   typed like its siblings:
   `signal off_world_reset(from: Vector3)`. Emitted at the top of the guard
   branch (`scripts/player.gd:157-159`), **before** `reset_flight` so `from` is
   the true departure position — insert `off_world_reset.emit(global_position)`
   between the counter increment (`player.gd:158`) and the reset call
   (`player.gd:159`). The counter, the guard line and the reset are untouched.
2. `scripts/chase_camera.gd` — a new `snap_home()`: set the rig's
   `global_position` to the follow target it already chases
   (`_player.global_position + Vector3.UP * _pivot_height`, the exponential
   follow at `scripts/chase_camera.gd:92-94`) and zero the lens shake state
   (`_camera.h_offset` / `_camera.v_offset` / `_camera.rotation.z`). The next
   `_physics_process` then dampens from the corridor instead of lerping ~755 m
   across the world.
3. `scripts/main.gd` — connect `player.off_world_reset` in `_ready()` to a
   handler that:
   - spawns the feather poof at `from`: instantiate `player.feather_scene`
     (`player.gd:89`, the OneShotBurst — self-cleaning via the `juice_effects`
     group, `scripts/one_shot_burst.gd`) and place it at the departure point,
     the same pattern as the flap poof (`scripts/player.gd:242-247`);
   - plays a short **warm HUD fade**: a full-rect ColorRect child of the
     existing `HUD` CanvasLayer (`scenes/main.tscn:70`; the `Dim` rects of
     PauseMenu/GameOverScreen at `main.tscn:142,190` are the precedent),
     `mouse_filter` ignore, peak alpha ~0.6–0.7 in a warm tone, back to 0 in
     ~0.6 s, driven in game time so it freezes with a paused world — new
     `@export_group("Off-world return")` tunables on Main (peak alpha, fade
     seconds, warm color);
   - calls `player.chase_camera.snap_home()`.

   Still no sound, no popup: the guard's quiet contract
   (`scripts/player.gd:149-156`) keeps its audio silence — this ticket adds
   only the visual beat.

4. `tests/sim_test.gd` — new scenario `off_world_return_beat`. The fade/camera
   legs **cannot** ride `off_world_fall_returns_home`: that scenario runs the
   bare harness player with no Main and no HUD (it says so itself,
   `tests/sim_test.gd:3310-3311`). Window pattern: instantiate `MAIN_SCENE`
   (`tests/sim_test.gd:14`) into its own space — the
   `poop_ready_indicator_tracks_cooldown` precedent
   (`tests/sim_test.gd:1133-1138`: `Game.save_path = SIM_SAVE_PATH`,
   `Game.reset_run()`, instantiate, offset (3500, 0, 3500)) — then drive its
   player below `off_world_y` and assert:
   - the signal fires exactly once per reset, with `from` equal to the
     departure position;
   - a `juice_effects` burst exists at `from` on the reset frame;
   - the fade's alpha is > 0 right after the reset and back ≤ 0.01 within ~1 s
     of game time;
   - on the first physics frame after the reset, `chase_camera.global_position`
     is within ~1.5 m of the player's (corridor) position + `UP * 1.4` — the
     snap, not a lerp;
   - the pigeon grounds on the respawn corridor within ~2 s; `off_world_resets`
     == 1 with no second fire across a further ~2 s;
   - hunger keeps draining through the presented return (loss > 0.2 across the
     window — the clock rides `Game.hunger`, attached by `Main._ready()`.
     Housekeeping per the precedent: free the main instance,
     `Game.hunger.player = null`, `Game.reset_run()`).

What this does NOT claim: no flight-model or guard behavior change (a bare
`Player` emitting a signal with zero connections is a no-op — the two existing
off-world scenarios keep passing untouched); no new input action (no
controls-table updates); no edge nudge (T-023 stays a separate follow-up); the
fade's warmth/length is a taste value tuned at Gate 3.

## Why

The off-world guard teleports the pigeon ~755 m instantly with no presentation:
a birdless blank frame while the camera chases home, then you are simply
standing on the plaza — exactly the "teleport glitch" read T-042's acceptance
line forbids, and that line is still pending because today's lens fails it.

Verified in code: the guard fires silently (counter only, no signal —
`scripts/player.gd:157-159`); `reset_flight` sets position directly
(`scripts/player.gd:131-145`); ChaseCamera has no snap API — `_physics_process`
only exponential-follows (`scripts/chase_camera.gd:88-95`), which is what
produces the blank chase frames. Session `vds3a` readings recorded by the lane
plan: pos [16, −2.95, −754.72] at frame 4409 → [16, 0.35, −0.14] at frame 4465
(one physics step, 755 m; events: `pitch_down` t=74569 → `grounded` t=75137);
frame f00004452 (~0.4 s after the snap) shows no bird and no city — the camera
mid-flight over blank apron grass; f00004512 (1.2 s later) grounded on the plaza
street. The capture dirs are not in this repo, so the lens judgement re-runs at
Gate 3 against T-042's pending line.

## Acceptance criteria

- [ ] Gate 1b: new `off_world_return_beat` passes with every leg listed in What
      (signal once with the right `from`; feather burst at `from`; fade in and
      fully out within ~1 s game time; camera within ~1.5 m of the corridor rig
      position on the first frame after the reset; grounded home within ~2 s;
      exactly one guard fire; hunger drains > 0.2 through the window)
- [ ] Gate 1b: `off_world_fall_respawns` and `off_world_fall_returns_home` stay
      green unchanged — the bare-harness windows prove the signal is a no-op
      without Main
- [ ] No physics or flight-model change: the guard branch differs from T-042's
      landed shape only by the emit line; every flight/landing scenario stays
      green (`camera_follows_yaw`, `camera_fov_kick`, `camera_tucks_in_grounded`
      re-run explicitly — snap_home is only ever called from the signal path)
- [ ] No input actions change (no README/VERIFICATION controls-table updates)
- [ ] [screenshot] Flying hard past the apron now reads as "came home" — a warm
      fade covers the cut, feathers mark the departure point, and the lens is
      already home when the fade lifts (Gate 3 — human judgement; retires
      T-042's pending teleport-glitch line)
- [ ] [screenshot] Across a presented return the hunger bar visibly keeps
      ticking down (Gate 3 — the machine half is the scenario's drain leg)

## Verification

Gate 1 (import + 120-frame boot, exit 0, no ERROR lines; `--check-only` on
`player.gd`, `chase_camera.gd` and `main.gd`) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the
new `off_world_return_beat`, re-running `off_world_fall_respawns`,
`off_world_fall_returns_home` and the three camera scenarios explicitly ·
Gate 2 (autoplay unchanged — the pilot's off-world self-heal still ends
`ok=true`, now with the beat visible in the screenshots) · Gate 3: the two
[screenshot] lines above, added to VERIFICATION.md's playtest list in the same
change-set, phrased as retiring T-042's pending line.

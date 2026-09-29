# T-011 — Pigeon presentation v1

- **Milestone:** M1 · **Priority:** P1 · **Size:** M · **Status:** done
- **Depends on:** T-001, T-003
- **Refs:** `docs/DESIGN.md` → Art style (locked: low-poly, bright & cartoonish)

## What

Retire the gray sphere:

- Low-poly pigeon mesh — CC0 source (Kenney/Quaternius, log in `assets/CREDITS.md`)
  or hand-built from primitives; gray body, darker wingtips, green neck sheen
- Animation/pose states: flap, glide (wings out), dive (wings back), waddle, peck
- Attached to Player and driven from the flight state machine

## Why

You spend the whole game looking at this bird. It must read as a pigeon and as a
character, not a physics capsule.

## Acceptance criteria

- [x] Readable silhouette at ~20 m against both roofs and road *(close-up pose
  previews rendered and checked during the change — stand/peck/glide/flap/dive
  all read as a pigeon; the at-distance human pass is recorded as pending in
  VERIFICATION.md → Known issues)*
- [x] Poses/animations match actual physics state with no desync *(machine-verified:
  Gate 1b `pigeon_air_poses_track_flight`, `pigeon_ground_poses_track_waddle` —
  the pose is derived from the flight state machine every physics frame)*
- [x] Waddle on the ground is at least a little bit funny *(squat + body rock +
  pigeon head-thrust bob shipped and visible in the autoplay ground visit; the
  comedy judgement itself is a pending human playtest note)*
- [x] `assets/CREDITS.md` updated if the mesh is third-party *(it is not — the
  mesh is hand-built from Godot primitives, so no credits entry is owed)*

## Verification

Gate 1 + Gate 2 + Gate 3. Manual: fly, glide, dive, land, waddle, peck — confirm a
pose exists for each and nothing clips the camera. *(Machine-verified via Gate 1b
`pigeon_air_poses_track_flight`, `pigeon_ground_poses_track_waddle`,
`pigeon_pecks_when_eating`; the autoplay DONE line reports every pose the run
showed (`poses=DIVE,FLAP,GLIDE,PECK,STAND,WADDLE`). The fly/glide/dive/land/waddle/
peck human pass — silhouette at 20 m, pose readability at flight speed, waddle
comedy, camera clipping — is recorded as pending in VERIFICATION.md → Known issues.)*

## Landed (implementation notes)

- **Mesh:** `scenes/pigeon_visual.tscn` + `scripts/pigeon_visual.gd`
  (`PigeonVisual`, Node3D) — hand-built from low-poly primitives: faceted sphere
  body (8×5 segments), sphere head with beak cone, eyes, green metallic neck
  sheen, dark box tail and two-segment box wings (gray inner + dark tip) on
  shoulder pivots, orange feet. Static rig rotations (beak cone, tail tilt,
  wingtip sweep) are applied in `_ready()` so the scene file stays
  translation-only per repo convention. Collision is untouched (the player's
  0.3 m sphere) — this is presentation only.
- **State machine drive:** `Player._update_pose` feeds `pigeon.drive(grounded,
  moving, diving, delta)` every physics frame; the pose enum (GLIDE / DIVE /
  WADDLE / STAND) is derived from the flight state, so picture and model cannot
  desync. The dive pose gates on `dive_pose_nose` (nose-pitch sine) and
  `dive_pose_min_speed`, both @exports on the player. The old sphere cosmetics
  (grounded squat, waddle bob + sway) moved verbatim into the visual.
- **Flap beat:** every `Player.flapped` signal (wired in `Player._ready`) plays
  one 0.32 s wing beat — a sine lift swing of 0.95 rad over the beat, on top of
  whatever base pose is active.
- **Peck:** `Player.peck()` (defaulted arg so the crumb signal connects
  directly) plays a 0.4 s overlay — head dives 1.9 rad with a forward lunge and
  a slight body lean. Wired in `Main._ready` alongside the hunger feed
  (`bread_spawner.crumb_eaten.connect(player.peck)`), so every swallowed crumb
  head-slams. The waddle adds a comedic head-thrust bob on the same beat as the
  body rock; standing birds idle-bob their heads.
- **Tests:** three Gate 1b scenarios drive the visual through the real player
  state machine; the autoplay pilot records which poses the run showed and
  reports them on the DONE line (`poses=…`).

## Tuned values

All @export, defaults as shipped: wing poses — `glide_lift` 0.14 rad,
`dive_lift` 0.05, `folded_lift` −0.08, `glide_sweep` 0.0, `dive_sweep` 1.0,
`folded_sweep` 1.3, `pose_lerp_rate` 9.0/s; flap beat — `flap_beat_seconds`
0.32 s, `flap_lift_amplitude` 0.95 rad; peck — `peck_seconds` 0.4 s,
`peck_angle` 1.9 rad, `peck_body_pitch` 0.22 rad, `peck_head_lunge` 0.06 m;
waddle/idle — `grounded_squat` 0.82, `waddle_bob_rate` 10.0, `waddle_bob_height`
0.03 m, `waddle_sway` 0.1 rad, `head_thrust` 0.05 m, `idle_head_bob` 0.012 m,
`idle_head_rate` 2.2/s; on the player — `dive_pose_nose` −0.35 (nose sine),
`dive_pose_min_speed` 9.0 m/s.

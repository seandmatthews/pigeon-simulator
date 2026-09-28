# T-002 — Chase camera v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** S · **Status:** done
- **Depends on:** T-001
- **Refs:** `docs/DESIGN.md` → Flight

## What

Turn the rigid child camera into a proper third-person chase camera:

- Smoothed follow (lerp/damped spring) so fast turns don't snap the view
- `SpringArm3D` so ground and buildings can't clip the camera
- FOV widens slightly with speed for sensation of speed
- While landed: closer, lower, lazier angle

## Why

The camera sells flight feel as much as the physics does — a stiff camera makes good
physics feel bad.

## Acceptance criteria

- [x] No camera clipping through ground or buildings when landing or hugging walls
- [x] No visible jitter during fast turns and dives
- [x] FOV kick with speed is noticeable but not nauseating
- [x] Follow lag feels responsive: the pigeon never leaves the frame at max speed

Mechanics verified by Gate 1b (`camera_follows_yaw`, `camera_fov_kick`,
`camera_tucks_in_grounded`); clipping/jitter/nausea are visual judgements that
still want the human playtest lines in `VERIFICATION.md` Gate 3.

## Tuned values (v1)

`position_rate 12` · `yaw_rate_air 4.5` · `yaw_rate_ground 2` · `pitch_rate 3.5` ·
`pitch_follow 0.45` · `roll_follow 0.15` · `base_pitch_deg -18` · `pivot_height_air 1.4` ·
`pivot_height_ground 0.6` · `arm_length_air 6.5` · `arm_length_ground 3.5` ·
`framing_rate 4` · `fov_air 72` · `fov_max 86` · `fov_ground 65` · `fov_speed 20` ·
`fov_rate 4`

## Verification

Gate 1 + Gate 2 + Gate 3 (camera line), plus a 2-minute low-altitude flight weaving
between buildings.

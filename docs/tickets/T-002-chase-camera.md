# T-002 — Chase camera v1

- **Milestone:** M1 · **Priority:** P0 · **Size:** S · **Status:** todo
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

- [ ] No camera clipping through ground or buildings when landing or hugging walls
- [ ] No visible jitter during fast turns and dives
- [ ] FOV kick with speed is noticeable but not nauseating
- [ ] Follow lag feels responsive: the pigeon never leaves the frame at max speed

## Verification

Gate 1 + Gate 2 + Gate 3 (camera line), plus a 2-minute low-altitude flight weaving
between buildings.

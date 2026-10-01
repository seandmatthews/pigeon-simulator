# T-057 — Derive the bread-pointer chevron from screen space; pin Gate 1b to independent ground truth

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (T-037 landed the pointer this rewrites)
- **Refs:** sweep 2 session `uiuxs2a` (all readings recorded below; the captures live in the lane
  worktree's gitignored `.captures/session_uiuxs2a/`) · landed [T-037](T-037-hud-bread-pointer.md)

## What

Rewrite the chevron's aim math in `scripts/main.gd` `_aim_bread_pointer`
(`scripts/main.gd:155-165`) from nose-relative to screen space, and rebuild the
Gate-1b assertions that today cannot see the bug.

`_aim_bread_pointer` keeps its first two lines — visibility and the `"%s %d m"`
text (`scripts/main.gd:156-157`) — and replaces the heading / `signed_angle_to`
block (`scripts/main.gd:158-165`) with:

- `var camera := get_viewport().get_camera_3d()` — bail (keep the last chevron
  rotation) when null.
- Project both ends through the live chase camera:
  `camera.unproject_position(target)` and
  `camera.unproject_position(player.global_position)`; `d := target_s - anchor_s`.
- Off-camera guard: `camera.is_position_behind(target)` keeps the last rotation.
  The chase camera looks forward from behind the pigeon, so anything sterner than
  roughly abeam is behind the lens and its unprojection is mirrored garbage —
  those cases hold the last honest bearing until the target re-enters the forward
  hemisphere (T-058 carries the stern case in text instead).
- Degenerate guard: `d.length_squared() < 1.0` (the target unprojects onto the
  pigeon's anchor) keeps the last rotation — the same contract as today's
  `to_target.length_squared() < 0.0001` bail (`scripts/main.gd:162-163`).
- Otherwise: `bread_pointer_chevron.rotation_degrees = rad_to_deg(atan2(d.y, d.x)) + 90.0`
  — canvas y is down, so +90 makes 0° = screen-up.

This changes what the chevron MEANS: from "bearing from the nose" (the docstring
convention, `scripts/main.gd:41-43` and `125-134`) to "the direction to the
target on screen". A ground-level target dead ahead now reads down-ish, honestly,
because that is where it sits on screen. Rewrite both docstrings in the same
change.

What this does NOT claim: no text/distance/mode change (`_update_bread_pointer`,
`scripts/main.gd:135-149`, untouched); no HUD layout change; no stern-target aim
(behind-camera cases hold the last bearing — T-058's suffix owns the stern read);
no chase-camera change; no new tunables.

## Why

The HUD chevron — the primary wayfinding affordance — repeatedly points the wrong
way in live play, worst exactly at run start, where the game teaches players to
follow it. Session `uiuxs2a`, state frame 3347: pigeon grounded at
[16.0, 0.35, −0.12] yaw 0, crumb at [5.66, 0.72, −5.66] — 11.7 m out, −61.8° from
the nose, HUD text "bread 12 m" correct — yet frames f2400–f17000 (~3 min) render
the chevron ▼ (~180° off). After steering it read ▲ at −2° (f18000) and ◄ at
−89.3° (f24000); a second-run spawn with the crumb +24.5° right showed ◄ (f59856).
A headless probe of the exact shipped expression prints −61.8183° (up-left) for
the first case — the live render contradicts the code's own math, and five live
readings fit no single sign convention. The root cause lives somewhere in the
nose-relative convention itself, which is why this ticket removes the convention
rather than patching a sign.

It survives the suite because the test mirrors the implementation:
`tests/sim_test.gd:2206` computes `want_rot` with the same
`-rad_to_deg(heading.signed_angle_to(...))` as `scripts/main.gd:164-165`, so the
scenario asserts the code against itself — 74/74 green while the render lies.

## Acceptance criteria

- [x] With the camera at any yaw, the chevron's drawn direction has a positive
      dot product with the on-screen direction from the pigeon's projected
      position to the target's projected position (checked for known
      `reset_flight` teleports at two opposing yaws)
- [x] Fresh run, zero steering input: the chevron points toward the crumb's
      actual screen position at spawn — the ▼-at-180°-off class is gone
      [screenshot]
- [x] Behind-camera and degenerate targets keep the last chevron rotation —
      never a NaN, never a mirrored direction
- [x] Distance text, bread/city mode switch, approach countdown, eat-and-re-aim,
      and the T-019 outline treatment all still pass unchanged
- [x] The Gate-1b expectations are computed independently of the implementation
      (viewport unprojection + dot product; never `atan2` over the
      implementation's own delta, never the old `signed_angle_to` formula)

## Implementation note (2026-10-01, this change-set)

The screen-space aim landed as specified and is machine-proven (Gate 1b half-plane
arms green; red-before: reverting only the aim math to the old
`signed_angle_to` block fails the scenario with dot −1.00 at the spawn hover).
But the live-play diagnosis changed: the chevron **mesh** is directionally
ambiguous. It is a near-isosceles apex-up triangle whose 10 px base is its
longest edge — at most rotations (measured at the spawn's 65.9°) the base
swings up into a near-horizontal top edge while a base *corner* hangs
bottom-center, so the glyph **reads as ▼ even though its apex points honestly
at the target** (verified in-engine: rotation_degrees read-back, global
transform basis, and a minimal-scene repro all confirm a faithful render).
This retroactively explains the session `uiuxs2a` readings in **Why** — "five
live readings fit no single sign convention": the convention (old and new) was
never the whole story; the glyph's look was. The aim fix this ticket mandates
is real and landed; the **glyph redesign is NOT** (the ticket claims no HUD
change) and is left as follow-up work for the human pass to scope.

## Final verification values (2026-10-01, landed tree)

No new tunables (per the What). Measured on the committed tree, headless
`Godot_v4.7.2-stable_win64_console.exe`: Gate 1 boot exit 0 (import exit 0 with
the pre-existing "33 resources still in use at exit" line); Gate 1b full suite
**92/92 SIM PASS, exit 0** — the reworked scenario's spawn hover half-plane dot
**1.00** (written rotation 65.94°, screen delta d = (416.4, −185.9) toward the
crumb's projection), flip arm dot **1.00**, city arm dot **1.00**; red-before
(old aim block restored) fails exactly this scenario with dot **−1.00**; Gate 2
autoplay `AUTOPLAY DONE ok=true` with `restart=true`, exit 0. Gate 3 pilot
grabs in `.captures/session_t057final/`: fresh hands-off run reads
"bread 14 m" with the apex at the crumb's projected direction, and the
off-rim airborne shot reads "city 272 m" holding the last honest bearing
behind the lens.

## Verification

Gate 1 (import + boot, exit 0) + Gate 1b (full suite green) with
`hud_bread_pointer_tracks_nearest_crumb` (`tests/sim_test.gd:2164`) reworked, in
the same commit:

- New half-plane helper: the chevron's drawn direction is
  `(sin θ, −cos θ)` from `rotation_degrees` θ (canvas rotation is
  clockwise-positive with y-down), dotted with the normalized
  `unproject_position(target) - unproject_position(pigeon)` — an expectation that
  shares no formula with the implementation.
- The bearing arm (`tests/sim_test.gd:2202-2208`) and the 180° flip arm
  (`tests/sim_test.gd:2210-2213`) are REPLACED by half-plane checks sampled
  immediately after each `reset_flight`. The flip arm cannot survive as an
  angle-vs-angle compare: the damped chase camera (`scripts/chase_camera.gd:96-99`,
  `yaw_rate_air` 4.5/s) has not swung after a 2-frame wait, so the honest chevron
  barely rotates across a 180° reset — the half-plane form is
  camera-yaw-independent and still kills every 180°-off bug. (Geometry note: the
  camera position barely moves on a yaw flip — it follows the pigeon, not the
  heading — so the flipped target stays in the stale camera's forward hemisphere
  and its unprojection stays valid.)
- The city arm (`tests/sim_test.gd:2245-2257`) gets the same half-plane
  treatment, and its teleport yaw changes from 0 to 90 so home sits dead ahead:
  at the old abeam-90° teleport home rides the screen edge, where unprojection is
  unreliable. (`reset_flight` yaw convention, `scripts/player.gd:113-115`: yaw 0
  faces −Z, yaw 90 faces −X; `spawn_point` is city-local (16, 0.6, 0) —
  `scripts/city.gd:240-241` — so from (span/2+40, 30, 0) home is due −X.)
- The `nearest_crumb()`-vs-independent-scan arm and the approach / eat-and-re-aim
  arms keep their distance-only asserts.

Update both VERIFICATION.md descriptions of this scenario in the same change-set
— the table row at `VERIFICATION.md:93` and the landed note at
`VERIFICATION.md:375-376` both say "carries the bearing from the nose and flips
~180° with the yaw", which stops being true. Gate 2 (the autoplay asserts nothing
about the pointer — unaffected; run anyway). Gate 3 [screenshot]: fresh run from
the title screen, hands off — chevron honest at spawn; plus T-037's existing
at-a-glance readability pass re-flown.

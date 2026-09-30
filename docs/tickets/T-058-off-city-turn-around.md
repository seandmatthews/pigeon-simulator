# T-058 — Make the off-city void readable: teach the chevron convention and cue the edge

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-057 (rewrites `_aim_bread_pointer` and the same Gate-1b scenario — land this
  after it; the suffix is a pure text branch written to survive that rewrite)
- **Refs:** sweep 2 session `uiuxs2b` (readings recorded below; captures in the lane worktree's
  gitignored `.captures/session_uiuxs2b/`) · T-023/T-036/T-042 (behavioral off-world
  guards, proposed — the flight-control half, out of scope here) · T-047 (city-edge rim) and
  T-029 (plaza landmark) own the world-side edge art

## What

One plain-language branch in the bread pointer's text: when the target bearing is
stern-facing, say so.

- `scripts/main.gd` `_aim_bread_pointer`: with flat heading and flat to-target
  vectors available there, `stern := heading_flat.dot(to_target_flat) < 0.0`. A
  dot test instead of `|bearing| > 90°`: convention-free, survives T-057's
  screen-space rewrite (which removes the heading→rotation block this would
  otherwise lean on), and exact-abeam gives dot ≈ 0 → NOT stern — exactly the
  strict `> 90°` the plan asks for, with no epsilon needed.
- Text becomes `"%s %d m%s" % [what, roundi(distance), STERN_SUFFIX]` with
  `const STERN_SUFFIX := " — turn around"`. One branch covers both modes: city
  mode past the ring (the evidence case) and bread mode when the nearest living
  crumb is behind you after flying past it.
- `scenes/main.tscn` needs NO change: the BreadPointer label box runs
  offset_left 34 → offset_right 518 — 484 px (`scenes/main.tscn:105-115`) — at
  font_size 14, and "city 414 m — turn around" (~24 chars ≈ 170 px) fits with
  room to spare.
- `tests/sim_test.gd` `_pointer_distance_m` (`tests/sim_test.gd:2138-2142`)
  parses exactly three space-separated parts and returns −1.0 on anything else —
  make it suffix-tolerant (strip everything from `" — "` before parsing) so every
  existing distance arm keeps working.

What this does NOT claim: no world-side edge affordance — the rim/skyline read is
T-047's city-edge rim, the landmark is T-029's statue; coordinate, don't
duplicate. No fall cue: T-042's off-world respawn owns the under-world failure
behaviorally, and a second, presentation-only response to the same fall would be
redundant. No chevron change (T-057's). No pointer layout or font change.

## Why

Past the city ring the screen is a featureless green plane — no skyline behind
you — and the only homeward cue is a pointer line whose ▼-means-behind convention
nothing teaches. Session `uiuxs2b`: "▼ city 414 m" at hunger 69% over an entirely
flat green frame (`f00005556.png`), later "▲ city 1015 m" at 42%; the pigeon fell
through the floor mid-play (sub-floor state lines, y ≈ −30) and starved ~1.9 km
out with "◄ city 2020 m" frozen under the score screen. The city is 234 m across
(`city_span` = 7 blocks × 32 pitch + 10 road, `scripts/city.gd:64-66,165-167`) —
~10 s of cruise at the lane-measured 19–24 m/s — so every normal overshoot ends
here. The Gate-2 autoplay never leaves the city, so no automated gate sees this;
only free flight does, and every ui-ux lane session hit it within minutes.
T-023/T-036/T-042 propose the flight-control guard; the presentation half — the
untaught arrow convention — is unclaimed.

## Acceptance criteria

- [ ] Beyond half the city span with the heading facing away from home, the
      pointer reads "city <n> m — turn around"; with the heading facing home, the
      suffix is absent
- [ ] Exact-abeam geometry (target bearing ≈ 90°, dot ≈ 0) shows NO suffix
- [ ] The suffix also appears in bread mode when the nearest living crumb is
      stern, and the metres still parse within the existing ±1 m tolerance
- [ ] [screenshot] At cruise past the ring, "city 414 m — turn around" reads at a
      glance in one look

## Verification

Gate 1 + Gate 1b: extend the city arm of `hud_bread_pointer_tracks_nearest_crumb`
(`tests/sim_test.gd:2245-2257`, as reworked by T-057) — teleport
`Vector3(city.city_span * 0.5 + 40.0, 30.0, 0.0)` with yaw 270 (`reset_flight`'s
yaw convention, `scripts/player.gd:113-115`: yaw 270 faces +X; home at city-local
(16, 0.6, 0) — `scripts/city.gd:240-241` — is due −X from there, i.e. strictly
stern at 180°, no boundary case) and assert the text ends with " — turn around"
AND `_pointer_distance_m` still returns the horizontal distance within 2 m; then
`reset_flight(..., 90.0)` (home dead ahead) and assert the suffix is gone. The
EXISTING city-arm teleport (yaw 0) is exactly abeam — it must keep showing NO
suffix, so that arm doubles as the abeam criterion.

VERIFICATION.md: the Gate-1b row wording for the pointer scenario extended in the
same change-set, plus a Gate 3 line. Gate 2 (the autoplay never leaves the city —
unaffected; run anyway). Gate 3 [screenshot]: at-a-glance "turn around" read at
cruise past the ring; the edge-visible-from-inside-the-ring playtest line belongs
to T-047, not here.

# T-058 — Make the off-city void readable: teach the chevron convention and cue the edge

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-057 (rewrites `_aim_bread_pointer` and the same Gate-1b scenario — land this
  after it; the suffix is a pure text branch written to survive that rewrite)
- **Refs:** sweep 2 session `uiuxs2b` (readings recorded below; captures in the lane worktree's
  gitignored `.captures/session_uiuxs2b/`) · T-036/T-042 (off-world guard, DONE — the
  flight-control half landed 2026-09-30, out of scope here) · T-088 owns the city-edge
  rim + skyline (T-047 superseded by it) and T-029 the plaza landmark — coordinate,
  don't duplicate · re-based during the 2026-09-30 backlog audit: **T-098 landed the
  climb cue in the pointer's suffix slot since this ticket was written** — see What

## What

One plain-language branch in the bread pointer's text: when the target bearing is
stern-facing, say so.

- `scripts/main.gd` `_aim_bread_pointer` (`scripts/main.gd:174-188`): with flat
  heading and flat to-target
  vectors available there, `stern := heading_flat.dot(to_target_flat) < 0.0`. A
  dot test instead of `|bearing| > 90°`: convention-free, survives T-057's
  screen-space rewrite (which removes the heading→rotation block this would
  otherwise lean on), and exact-abeam gives dot ≈ 0 → NOT stern — exactly the
  strict `> 90°` the plan asks for, with no epsilon needed.
- Text composition — **the suffix slot is no longer empty**: T-098's climb cue
  landed there (`climb_cue` " ▲"/" ▼", `scripts/main.gd:177-184`, text line
  already `"%s %d m%s" % [what, roundi(distance), climb_cue]`). Do NOT replace
  it — extend it: `"%s %d m%s%s" % [what, roundi(distance), climb_cue,
  STERN_SUFFIX]` with `const STERN_SUFFIX := " — turn around"`. The climb cue
  goes FIRST, the stern suffix LAST — in city mode `climb_cue` is always ""
  (city mode never arrows, pinned by `tests/sim_test.gd:3075-3076` and
  VERIFICATION.md's pointer row), so city text reads "city 414 m — turn
  around"; in bread mode a stern high crumb reads "bread 12 m ▲ — turn
  around". The T-098 cue arms (`tests/sim_test.gd:3062` ends_with " ▼",
  `:2954-2956` no-arrow-at-level) keep passing because their crumbs sit in
  front of the pigeon (suffix absent) — re-check that geometry when landing,
  and if any arm turns out stern, strengthen its assert to
  `ends_with(" — turn around")` rather than weakening it. One branch covers
  both modes: city mode past the ring (the evidence case) and bread mode when
  the nearest living crumb is behind you after flying past it.
- `scenes/main.tscn` needs NO change: the BreadPointer label box runs
  offset_left 34 → offset_right 518 — 484 px (`scenes/main.tscn:143-153`) — at
  font_size 14, and "city 414 m — turn around" (~24 chars ≈ 170 px) fits with
  room to spare.
- `tests/sim_test.gd` `_pointer_distance_m` (`tests/sim_test.gd:2862-2870`)
  parses exactly three parts, or four with a trailing ▲/▼ (the T-098
  tolerance), and returns −1.0 on anything else — make it suffix-tolerant
  (strip everything from `" — "` before parsing) so every existing distance
  arm keeps working.

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
(`city_span` = 7 blocks × 32 pitch + 10 road, `scripts/city.gd:100-102,207-212`) —
~10 s of cruise at the lane-measured 19–24 m/s — so every normal overshoot ends
here. The Gate-2 autoplay never leaves the city, so no automated gate sees this;
only free flight does, and every ui-ux lane session hit it within minutes.
T-023/T-036/T-042 propose the flight-control guard; the presentation half — the
untaught arrow convention — is unclaimed.

## Acceptance criteria

- [ ] Beyond half the city span with the heading facing away from home, the
      pointer reads "city <n> m — turn around"; with the heading facing home, the
      suffix is absent
- [ ] Exact-abeam geometry (target bearing ≈ 90°, dot ≈ 0) shows NO suffix —
      proven by a DEDICATED abeam arm this ticket adds (see Verification): the
      pre-existing yaw-0 city arm cannot serve, because T-057 reworks it to
      yaw 90 (home dead ahead), which would leave the abeam case unchecked
- [ ] The suffix also appears in bread mode when the nearest living crumb is
      stern, and the metres still parse within the existing ±1 m tolerance
- [ ] [screenshot] At cruise past the ring, "city 414 m — turn around" reads at a
      glance in one look

## Verification

Gate 1 + Gate 1b: extend the city arm of `hud_bread_pointer_tracks_nearest_crumb`
(`tests/sim_test.gd:3064-3078` today, as reworked by T-057) — teleport
`Vector3(city.city_span * 0.5 + 40.0, 30.0, 0.0)` with yaw 270 (`reset_flight`'s
yaw convention, `scripts/player.gd:135-137`: yaw 270 faces +X; home at city-local
(16, 0.6, 0) — `scripts/city.gd:288-289` — is due −X from there, i.e. strictly
stern at 180°, no boundary case) and assert the text ends with " — turn around"
AND `_pointer_distance_m` still returns the horizontal distance within 2 m; then
`reset_flight(..., 90.0)` (home dead ahead) and assert the suffix is gone. For
the abeam criterion, ADD a dedicated arm in the same scenario: a second
teleport to the same spot with yaw 0 (nose −Z, home ≈ 90° off the nose, dot ≈
0) — text-only asserts (no chevron-rotation assert; T-057's unprojection
objection applies only to the chevron half-plane check, not to a text/distance
arm): NO suffix, distance still parses. Do NOT rely on the scenario's existing
yaw-0 city arm for this — T-057 converts it to yaw 90.

VERIFICATION.md: the Gate-1b row wording for the pointer scenario extended in the
same change-set, plus a Gate 3 line. Gate 2 (the autoplay never leaves the city —
unaffected; run anyway). Gate 3 [screenshot]: at-a-glance "turn around" read at
cruise past the ring; the edge-visible-from-inside-the-ring playtest line belongs
to T-047, not here.

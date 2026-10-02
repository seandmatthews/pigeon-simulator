# T-058 — Make the off-city void readable: teach the chevron convention and cue the edge

- **Milestone:** Sweep backlog · **Status:** done · **Category:** ui-ux · **Value (1-5):** 3 · **Risk (1-5):** 1
- **Depends on:** T-098 and T-057 (both landed — the suffix composes with the climb cue's
  slot and must survive the screen-space chevron rewrite; pure text written before the
  camera guards, it does)
- **Refs:** sweep 2 session `uiuxs2b` (readings recorded below; captures in the lane
  worktree's gitignored `.captures/session_uiuxs2b/`) · T-036→T-042/T-053 (off-world
  guard, DONE — the behavioral half landed, out of scope here; this ticket is its
  presentation half) · T-088 (city-edge rim + skyline, DONE) and T-029 (plaza landmark,
  still proposed) own the world-side edge affordances — coordinate, don't duplicate ·
  re-based during the 2026-09-30 backlog audit and again after T-057/T-098 landed: the
  composition plan below is written against the current
  `_aim_bread_pointer(target, what, distance, with_climb_cue: bool = false)` signature

## What

One plain-language branch in the bread pointer's text: when the target bearing is
stern-facing, say so.

- `scripts/main.gd` `_aim_bread_pointer` (`scripts/main.gd:244-245`, since T-098
  `(target: Vector3, what: String, distance: float, with_climb_cue: bool = false)`):
  compute `stern` from **flat forward vs flat to-target** — the player's nose
  (`-player.global_transform.basis.z`, flattened to XZ, normalized) dotted with the
  flattened `target − player` direction: `stern := forward_flat.dot(to_target_flat) < 0.0`.
  A dot test instead of `|bearing| > 90°` is convention-free (no yaw→cardinal mapping to
  get backwards), and exact-abeam gives dot ≈ 0 → NOT stern — exactly the strict
  `> 90°` the plan asks for, with no epsilon needed. **The suffix must NOT piggyback on
  `with_climb_cue`**: that parameter is bread-only (`scripts/main.gd:228-229` passes
  `true`; the city call at `:222` uses the `false` default) and the suffix has to serve
  BOTH modes. Either derive `stern` in-function from the player's transform as above
  (nothing else changes), or thread it as its own optional parameter through both call
  sites. There is no flat heading lying around in the function anymore — T-057 removed
  the heading→rotation block; the chevron now comes from camera unprojection
  (`scripts/main.gd:255-263`), which is exactly why the suffix is computed from world
  space, not screen space.
- Text composition — the suffix slot is T-098's: `climb_cue` " ▲"/" ▼" is built at
  `scripts/main.gd:247-253` (`POINTER_CLIMB_CUE_M := 3.0` at `scripts/main.gd:38`) and
  the format line is `"%s %d m%s" % [what, roundi(distance), climb_cue]` at
  `scripts/main.gd:254`. Do NOT replace it — extend it: `"%s %d m%s%s" % [what,
  roundi(distance), climb_cue, STERN_SUFFIX]` with `const STERN_SUFFIX := " — turn
  around"`. Climb cue FIRST, stern suffix LAST — city text reads "city 141 m — turn
  around" at the Verification arm's geometry (the session evidence saw "city 414 m" from
  further out), a stern high crumb reads "bread 12 m ▲ — turn around". The T-098 cue
  arms keep passing because their crumbs sit in front of the pigeon (suffix absent):
  cue-up ends_with " ▲" (`tests/sim_test.gd:3974-3975`), cue-down ends_with " ▼"
  (`tests/sim_test.gd:4002-4003`), no arrow at level (`tests/sim_test.gd:3893-3894`,
  comment `:3891-3892`), city mode never arrowed (`tests/sim_test.gd:4022-4023`) — all
  pinned in VERIFICATION.md's pointer row (`VERIFICATION.md:101`). Re-check each
  geometry when landing; if any arm turns out stern, strengthen its assert to
  `ends_with(" — turn around")` rather than weakening it. One branch covers both modes:
  city past the ring (the evidence case) and bread when the nearest living crumb is
  behind you after flying past it. Text-only safety: the pointer text is written at
  `scripts/main.gd:254` BEFORE the behind-lens/degenerate camera guards at
  `:255-257`, so a stern branch never touches T-057's unprojection machinery.
- `scenes/main.tscn` needs NO change: the BreadPointer label box runs offset_left 34.0
  (`scenes/main.tscn:146`) → offset_right 518.0 (`scenes/main.tscn:148`) — 484 px — at
  font_size 14 (`scenes/main.tscn:152`), and "city 141 m — turn around" (~24 chars ≈
  170 px) fits with room to spare.
- `tests/sim_test.gd` `_pointer_distance_m` (`tests/sim_test.gd:3686-3693`, docstring
  `:3682-3685`) accepts exactly three parts, or four with a trailing ▲/▼ (the T-098
  tolerance), and returns −1.0 on anything else — "city 141 m — turn around" splits
  into six parts → −1.0, which would fail every distance assert the suffix rides on.
  Make it suffix-tolerant (strip everything from `" — "` before splitting) and update
  the docstring's shape list, so every existing distance arm keeps working.

What this does NOT claim: no world-side edge affordance — the rim/skyline read landed
with T-088 (T-047 superseded by it), the landmark is T-029's statue; coordinate, don't
duplicate. No fall cue: T-042's off-world respawn (guard at `scripts/player.gd:176-178`,
now emitting the T-087/T-095 `off_world_reset` signal at `scripts/player.gd:178`) owns
the under-world failure behaviorally, and a second, presentation-only response to the
same fall would be redundant. No chevron change (T-057's). No pointer layout or font
change.

## Why

Past the city ring the screen is a featureless green plane — no skyline behind you —
and the only homeward cue is a pointer line whose ▼-means-behind convention nothing
teaches. Session `uiuxs2b`: "▼ city 414 m" at hunger 69% over an entirely flat green
frame (`f00005556.png`), later "▲ city 1015 m" at 42%; the pigeon fell through the
floor mid-play (sub-floor state lines, y ≈ −30) and starved ~1.9 km out with
"◄ city 2020 m" frozen under the score screen. The city is 234 m across (`city_span` =
7 blocks × (22 + 10 pitch) + 10 road: `scripts/city.gd:159-161` exports,
`scripts/city.gd:281-286` the `block_pitch`/`city_span` getters) — ~10 s of cruise at
the lane-measured 19–24 m/s — so every normal overshoot ends here. The Gate-2 autoplay
never leaves the city, so no automated gate sees this; only free flight does, and every
ui-ux lane session hit it within minutes. The flight-control half of the fix is
covered — T-023's nudge-home is still proposed, but the hard guard landed
(T-036 adopted by T-042, with T-053's fall leg): past `off_world_y` = −5.0
(`scripts/player.gd:74`) the pigeon respawns at the corridor. The presentation half —
the untaught stern convention — is still unclaimed: no "turn around"/stern text exists
anywhere in `scripts/main.gd` or the harness (grepped 2026-10-01).

## Acceptance criteria

- [x] Beyond half the city span with the heading facing away from home, the pointer
      reads "city <n> m — turn around"; with the heading facing home, the suffix is
      absent (Gate 1b: a dedicated stern arm plus the existing yaw-90 city arm)
- [x] Exact-abeam geometry (target bearing ≈ 90° off the nose, dot ≈ 0) shows NO
      suffix — proven by a DEDICATED abeam arm this ticket adds (see Verification):
      the scenario's only city arm has faced yaw 90 since T-057
      (`tests/sim_test.gd:4011`, `:4016` — home dead ahead), so the abeam case is
      otherwise unchecked
- [x] The suffix also appears in bread mode when the nearest living crumb is stern,
      and the metres still parse within the existing ±1 m tolerance
- [x] [screenshot] At cruise past the ring, the suffixed "city <n> m — turn around"
      line reads at a glance in one look (the session reading was "city 414 m — turn
      around" at the ring overrun) (reviewer sign-off 2026-10-02; agent grab
      `.captures/t058_city_turn_around.png`, pilot session `t058b`)

## Verification

Gate 1 (`--import` + the 120-frame boot; NO `--check-only` leg — VERIFICATION.md:385-390
records it broken repo-wide; both touched scripts are exercised by the boot and the
suite) + Gate 1b + Gate 2 + Gate 3.

Gate 1b — extend the city arm of `_scenario_hud_bread_pointer_tracks_nearest_crumb`
(scenario at `tests/sim_test.gd:3752`, `_check` at `:4036`, registered at `:157`).
Base spot is the T-057 city hover `Vector3(city.city_span * 0.5 + 40.0, 30.0, 0.0)`
(`tests/sim_test.gd:4011`) = city-local (157, 30, 0); home is `city.spawn_point` =
city-local (16, 0.6, 0) (`scripts/city.gd:366-367` — `_plaza_center` plus half a block
plus half a road at `spawn_drop_height` 0.6, `scripts/city.gd:193` — corroborated by
the comment at `tests/sim_test.gd:4005`), due −X, 141 m out. Yaw convention:
`reset_flight(pos, yaw_deg)` (`scripts/player.gd:150-152`), yaw 0 → nose −Z
(`tests/sim_test.gd:3896-3897`), so from the hover: yaw 90 → nose −X = home dead
ahead, yaw 270 → nose +X = home strictly behind at 180°, yaw 0 → home exactly abeam.

- **Stern arm (net-new):** reuse the existing camera-converge loop
  (`tests/sim_test.gd:4015-4017`), then `reset_flight(city_hover, 270.0)` — home
  strictly stern, dot −1, no boundary case. Assert the text ends with
  " — turn around" AND `_pointer_distance_m` still returns the horizontal distance
  within the arm's existing ±2 m tolerance (this leg is only passable once the parser
  is suffix-tolerant).
- **Ahead arm (exists, strengthen):** the yaw-90 arm (`tests/sim_test.gd:4016`, asserts
  `:4022-4025`) already implies suffix-absence — a stray suffix drives
  `_pointer_distance_m` to −1.0 and fails its ±2 m parse — but make it explicit: add
  `not pointer.text.ends_with(" — turn around")` to `city_ok`.
- **Abeam arm (net-new — the criterion-2 proof):** `reset_flight(city_hover, 0.0)` —
  nose −Z, home due −X → bearing exactly 90° off the nose, dot ≈ 0 → the strict
  `< 0.0` shows NO suffix. Text-only asserts (no chevron-rotation assert — T-057's
  unprojection objection applies only to the chevron half-plane check, and the text is
  composed before those guards anyway): NO suffix, distance still parses within 2 m.
  Do NOT look for an existing yaw-0 city arm to reuse — there is none; T-057 reworked
  the city arm to yaw 90 (rationale comment `tests/sim_test.gd:4004-4010`,
  VERIFICATION.md:101 documents "teleport yaw 90").
- **Bread stern arm (net-new):** mirror the T-098 scan-decided pattern — pre-pick a
  street spot clear of every living crumb (the `tests/sim_test.gd:3926-3945` pattern,
  with a clearance ring wide enough that the placed crumb wins the 3D scan from the
  hover), hover ~10 m above it with the nose facing away, `drop_crumb` a hand-placed
  crumb BEHIND the nose so the independent scan names it, then assert the suffix and
  the ±1 m parse against that scan-named crumb.

VERIFICATION.md: extend the Gate-1b pointer row (`VERIFICATION.md:101`) with the three
new city geometries and the suffix-tolerant parser in the same change-set, and add a
Gate 3 line beside the T-037/T-098 playtest lines (`VERIFICATION.md:310-313`). Gate 2:
the autoplay never leaves the city — unaffected; run anyway. Gate 3 [screenshot]:
at-a-glance "turn around" read at cruise past the ring; the
edge-visible-from-inside-the-ring playtest line belongs to T-088, not here.

## Landed (agent, 2026-10-02 — reviewer sign-off 2026-10-02, DONE)

- **Gates run on the commit tree:** Gate 1 (`--import` exit 0, only the documented
  benign `ERROR: 33 resources still in use at exit` addon line; 120-frame boot exit 0,
  no ERROR lines — no `--check-only` leg per the recorded repo-wide breakage),
  Gate 1b 109/109 `SIM PASS`, Gate 2 `AUTOPLAY DONE ok=true … restart=true` (fps 136).
- **Landed values (verbose Gate 1b run of `hud_bread_pointer_tracks_nearest_crumb`):**
  ahead arm `'city 141 m'` (no suffix, chevron dot 1.00), stern arm
  `'city 141 m — turn around'` (±2 m parse), abeam arm `'city 141 m'` (no suffix),
  bread stern arm `'bread 11 m ▼ — turn around'` (10.9 m true, shows 11 — within the
  ±1 m band, cue first / suffix last); the T-098 arms are unchanged (`'bread 9 m ▲'`,
  `'bread 12 m ▼'`, level `'bread 3 m'`).
- **One deliberate deviation from the arm recipe, measured not assumed:** the
  one-shot `reset_flight(hover, yaw)` + 2-frame wait samples the FALL, not the
  geometry — a temporary probe scene showed the re-pinned stall drift (velocity
  chases the dipping nose, ~0.02 m/s of −Z drift) tips the exact-abeam dot a hair
  negative within ~2 frames, and the first Gate 1b run read the abeam arm as
  `'city 141 m — turn around'` (FAIL). The two new city arms and the bread stern arm
  therefore sample from the scenario's established RE-PINNED pose (pin each frame,
  read the same frame's text, as the converge loops do); the asserts are exactly as
  the ticket prescribes. The approach/level read got the same re-pin so its text
  matches its abeam geometry deterministically; its assert is untouched.
- **Gate 3 [screenshot] agent grab, reviewer sign-off 2026-10-02:**
  `.captures/t058_city_turn_around.png` (pilot session `t058b`) — airborne at
  (16, ~20, ~-157), yaw 0, home due behind (flat dot −1.00), the HUD line reads
  "▼ city 157 m — turn around" in one look over the void past the ring.

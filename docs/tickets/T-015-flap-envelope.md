# T-015 — Flap envelope: pace toward ~25, dives own the top end

- **Milestone:** M1 · **Priority:** P1 · **Size:** S · **Status:** done
- **Depends on:** T-001 (flight feel v1)
- **Refs:** `docs/DESIGN.md` → Flight · Pillar 1 · flight-control review-lane
  play sessions (2026-09-29, `.captures/session_wt646889d-flight-control*/`)

## What

Restore a speed envelope to the flight model. Today the airborne flap is a
fixed 45° up+forward impulse (`flap_impulse 13`) at every airspeed, so three
paced flaps — or nine mashed ones — put the pigeon at ~29 m/s one second after
takeoff. There is no slow flight, `flap_min_fraction` (pacing beats mashing)
never shows in the outcome, and turn radius / landing approach / the FOV kick
all collapse into one speed.

Change the airborne flap into a **direction blend**: the impulse direction
rotates from the 45° up+forward shove (at low speed) toward pure body-up lift
(at `glide_speed`). One new export:

- `flap_push_taper` (m/s): the forward shove is full at
  `glide_speed - flap_push_taper` and fades linearly to zero at `glide_speed`.

Note what this does **not** claim: a pure-lift flap still adds impulse
magnitude, and the magnitude-preserving velocity-align slerp converts it into
forward speed within ~1 s at level attitude — so flaps remain a *partial*
throttle. The honest outcome: **flaps alone can no longer reach `max_speed`;
flap pacing tops out around ~25 m/s instead of ~29; speed beyond that comes
from diving.**

The ground takeoff branch (the startled level hop) and the shared application
line keep their shape; pacing, cooldown, audio and juice hooks are untouched.

## Why

Pillar 1 — flight is the toy, and right now the toy has one speed. Evidence
from the review-lane pilot sessions (state.jsonl traces): level flight at
28.7 m/s 1.2 s after takeoff with no dive input; nine mashed flaps reach
29.3 m/s — indistinguishable from paced; a flap at 20–28 m/s adds +8.5–9.3 m/s
of forward speed (throttle, not lift); with fwd ≥ 20 from 1.5 s in, the FOV
kick (fov_speed 20) is pinned at max nearly the whole flight; a no-input coast
needs ~15 s / ~300 m to bleed into the 12 m/s landing band.

## Acceptance criteria

- [x] Four paced flaps from the ground climb, but the forward speed they pump
      stays well under the cap — flaps alone cannot reach `max_speed`
- [x] At cruise speed a flap adds climb, not forward speed (forward gain of a
      single tap sampled at +1–2 frames stays small; vertical gain is large)
- [x] Mashed flaps are now genuinely weaker than paced ones (weaker lift AND
      no throttle past cruise)
- [x] Dive → pull-up remains the main way past ~25; the energy-exchange
      scenarios keep passing unchanged
- [x] Existing Gate 1b suite stays green, explicitly including
      `city_street_flyover` (the flap-paced cruise scenario most coupled to
      the envelope)

## Landed (T-015)

- `scripts/player.gd` — the airborne flap direction now blends from the old
  45° up+forward shove (full below `glide_speed - flap_push_taper`, so stall
  recovery keeps its exact old bite) toward pure body-up lift, reaching pure
  lift at `glide_speed`. The formula divides by `maxf(flap_push_taper, 0.5)`
  so tuning the export to 0 degrades to the old fixed 45° flap instead of
  producing infinities. The application line stays shared with the ground
  takeoff branch (which only overrides the direction); pacing, cooldown,
  audio and juice hooks untouched.
- `tests/sim_test.gd` — new `flap_speed_envelope` scenario (pump ceiling from
  a measured run, cruise tap sampled at +1/+2 physics frames because the
  nose-chase converts lift into forward speed within a few frames).
- `tests/autoplay.gd` — cruise governor flaps to hold `glide_speed + 3` now
  that flaps can't chase the old 28 m/s cap; stale comments refreshed.
- `VERIFICATION.md` / `docs/DESIGN.md` — Gate 1b row, Gate 2 prose touch-up,
  known-issues note, and design wording that matches the model.

## Tuned values (final)

- `player.flap_push_taper` = 10.0 m/s (the only new export; full 45° shove at
  ≤ 7 m/s forward, zero forward shove at `glide_speed` 17)
- Measured on the landed tree (fixed-fps sim, `SIM_DEBUG=1`): four paced
  ground flaps pump to a 25.04 m/s peak at y=7.67 (old model: 28.7 at three
  flaps, riding the 30 cap at four); the scenario asserts < 26.0
- Cruise tap from a settled 16.6 m/s glide (+1/+2 frames): forward gain
  +0.75 m/s max (16.60 → 17.00 → 17.35; assert < 2.0), vertical gain
  +12.25 m/s (−0.58 → 11.67; assert > 4.0)

## Verification

Gate 1 (import + 120-frame boot, both exit 0, zero ERROR lines) + Gate 1b
(full suite, exit 0 — baseline on the untouched tree measured 63/63; the new
scenario makes it 64; `city_street_flyover`, `stall_drops`, `stall_recovers`,
`takeoff_3_flaps`, `dive_gains_speed`, `pullup_gains_height` explicitly
re-run) + Gate 2 (run by the workflow after the commit) + Gate 3.

**Pending human playtest (Gate 3):** the T-001 feel lines re-flown under the
new envelope — does climbing feel like climbing (not throttling), does the
dive feel like the speed tool, is mashing visibly weaker, do turns at the new
cruise speed read weightier.

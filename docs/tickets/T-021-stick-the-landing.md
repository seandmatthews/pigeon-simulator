# T-021 — Stick the landing: settle shallow touchdowns on contact

- **Milestone:** Sweep backlog · **Status:** done · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 2
- **Depends on:** T-003 (amends its settle/skid semantics) · builds on T-001 + T-015 (the trim envelope that set natural arrivals at 15–17 m/s)
- **Refs:** flight-control review-lane play sessions (2026-09-29, `.captures/session_flc-s1-b/`,
  `.captures/session_flc-s1-d/`); baseline Gate 1b on today's tree re-run during ticket-writing:
  exit 0, 73/73 PASS (`.captures/sim_baseline_tkwriter.txt`)

## What

Make a natural glide touchdown **settle on the contact frame** instead of
ghost-sliding through it in AIR. Two changes, both in `scripts/player.gd`:

1. **Raise the settle bar:** `max_land_speed` 12.0 → **16.0**
   (`scripts/player.gd:53`). Natural trim-speed arrivals measure 15.3–17.2 m/s,
   so the bar has to sit above the model's own glide touchdown speed.
2. **Judge the touch, not the slide:** today `_air_physics` calls
   `_try_settle(pre_vy, pre_speed)` on *every* floor-contact frame
   (`scripts/player.gd:160-164`) — by the second skid frame the floor has
   already eaten the speed the landing was judged on. Split the call:
   - **First floor-contact frame** (airborne at frame start: `not
     was_on_floor`, `is_on_floor()` after `move_and_slide`): settle is judged
     on that frame's **pre-move velocity** — the same touch velocity
     `_touchdown_velocity` already records (`scripts/player.gd:153-154`). A
     shallow (≤ `max_land_angle_deg` 30°) touch at ≤ 16 m/s settles
     immediately.
   - **Subsequent AIR frames on the floor** (the T-003 skid): settle only when
     the current speed has bled under a new export
     `skid_settle_speed: float = 2.0` (group "Landing & waddle"). Anything
     above the bar — faster than 16 m/s or steeper than 30° — keeps the
     existing skid and settles only near rest, so **hard-landing semantics are
     preserved**: no damage model appears, `_land_effects`
     (`scripts/player.gd:186-194`) still reads the first-contact velocity, and
     the waddle/takeoff branches are untouched. (A takeoff hop leaves the floor
     at ~13 m/s ≫ `skid_settle_speed`, and `_try_settle`'s rising-touch guard
     `impact_vy > 1.0` holds, so the split cannot re-ground a takeoff.)

**Harness is in scope — the plan's "touch player.gd only" does not survive
contact with the suite.** In `tests/sim_test.gd`:

- `hard_landing_skids` detects the skid as `is_on_floor() and not is_grounded
  and velocity.length() > _player.max_land_speed` (`tests/sim_test.gd:482-484`).
  That dive's floor speeds sit in (12, 16] — proven by the plan's own naive
  12→16 run (72/73, `hard_landing_skids` failing "fast touch stayed
  AIR=false") — so at a 16 bar the detector goes blind even though the
  behavior is still a correct skid. Retune the detector to the new semantics:
  `velocity.length() > _player.skid_settle_speed` on AIR floor frames. It
  fires on both trees (old floor speeds 15→12, new tree 15→2) and cannot
  false-positive on a clean settle, which spends zero AIR frames on the floor.
  The scenario's other assertions (min y, finiteness, rest < 0.8 m/s grounded)
  keep their shape.
- New scenario **`trim_glide_lands_clean`**: from a settled ~17 m/s shallow
  glide started low (~1.5–2 m, so the touch arrives ≈ 15.3 m/s — starting
  higher bleeds less and can exceed the 16 bar; measure with `SIM_DEBUG=1`),
  assert the pigeon ends GROUNDED having spent **zero** airborne floor-contact
  frames (`is_on_floor() and not is_grounded` never true above
  `skid_settle_speed`). Expressible with the existing `_set_up` /
  `_await_grounded` helpers (`tests/sim_test.gd:167-171, 202-207`). Fails on
  today's tree, passes after.

What this does **not** claim: it does not make steep dives landable (the 30°
angle check still rejects them), does not slow the model down, and does not
change stall, flap or juice behavior.

## Why

Every natural glide touchdown arrives faster than the settle bar, so the
pigeon visibly ghost-slides ~3 m in AIR *past* the touch point — wings still
in glide pose, HUD still saying airborne — and small targets like the bench
(1.8 × 0.5 m, `tests/sim_test.gd:62`) punish you for the model's own trim
speed. Evidence (review-lane sessions): session b trace t=22425→22725 — AIR at
y=0.35, 15.31→12.09 m/s, then GND, i.e. the 3 m slide happened airborne after
contact; natural arrivals measured 15.3–17.2 m/s across two independent
touchdowns vs `max_land_speed` 12 (`scripts/player.gd:53`); the session-d
experiment with bar=16 settled GND on the contact frame at 15.31 m/s
(t=26175).

## Acceptance criteria

- [x] A shallow glide touchdown at trim speed settles into the waddle on the
      contact frame — zero airborne floor-contact frames past the touch
      (Gate 1b: `trim_glide_lands_clean`)
- [x] A steep fast dive still skids — never settles on contact, stays AIR on
      the floor while bleeding, settles only under ~2 m/s, no tunneling, no
      NaNs (Gate 1b: `hard_landing_skids` with the retuned detector)
- [x] A low slow touch still slides to a stop with no bounce and no NaNs
      (Gate 1b: `landing_slides_to_stop` stays green unchanged)
- [x] Landings on the bench, the roof and the plaza still settle grounded and
      walkable (Gate 1b: `bench_landing`, `roof_landing`, `city_plaza_spawn`
      stay green)
- [x] The tuned bar is recorded in T-003's "Tuned values" section, and
      `VERIFICATION.md`'s Gate 1b table gains the `trim_glide_lands_clean` row

## Tuned values

`max_land_speed 16` (was 12) · `skid_settle_speed 2` (new) — both in the
"Landing & waddle" group of `scripts/player.gd`. Measured on this tree: the
scenario's trim glide (settled 17 m/s from 1.8 m) touches down at **15.69 m/s**
and settles grounded on the contact frame; with the bar held at the old 12 the
same touch is rejected and ghost-slides **57 airborne floor frames** (15.69 →
1.90 m/s) before grounding — the exact regression `trim_glide_lands_clean`
guards.

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script
res://scripts/player.gd`) + Gate 1b full suite green — baseline on today's
tree measured exit 0, 73/73 PASS; the new scenario makes it 74;
`hard_landing_skids` (retuned detector), `landing_slides_to_stop`,
`bench_landing`, `bench_takeoff`, `roof_landing`, `city_plaza_spawn`
explicitly re-run — + Gate 2 (autoplay) + Gate 3.

Recorded on the implementation tree (2026-09-29): Gate 1 import + 120-frame
boot exit 0 (`--check-only` prints the pre-existing "Identifier not found:
Sfx/Game" autoload noise, identical with the change stashed — see T-017's
note; the suite run is the authority). Gate 1b: exit 0, **74/74 PASS** (73/73
baseline re-run first); the A/B with the old bar (max_land_speed 12, all else
equal) fails exactly `trim_glide_lands_clean` — the scenario has teeth.
Gate 2 autoplay: exit 0, `AUTOPLAY DONE ok=true … restart=true`, ground visit
landed/waddled/ate under the new semantics. Gate 3: pending human playtest
(the stick-vs-skid feel lines above).

**Pending human playtest (Gate 3):** the stick-vs-skid feel line — does a
trim-speed touchdown on a bench now *stick* (pose + HUD flip on contact)
instead of ghost-sliding, and does a deliberately hot dive still read as a
comedic skid rather than a soft settle.

# T-133 — Slower bird, bigger city: the speed quartet ×0.8, turn rates untouched

- **Milestone:** M3 owner pick ([B-20](../IDEAS.md), 2026-10-20; tine picked 2026-10-22) · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** —
- **Refs:** `docs/IDEAS.md` B-20; T-117 (the ×1.2 WASD feel pass that raised the cap
  30 → 36 — this turns the same dial the other way, with more phone play since as
  the new evidence); `scripts/player.gd` flight exports; T-021 landing bars;
  T-015 flap taper; T-022 flare; T-013 dust.

## What

Fly slower, on purpose. Two wins from one dial: **ease of use** — the ground
doesn't rush past, so aiming a poop and lining up a perch stop both get
forgiving — and **scale** — a slower bird makes the same city feel bigger, a
place to cross rather than a plaza you outrun. Especially friendly to the touch
build (T-119), where fine stick work is hardest.

**Tine (b) of the 2026-10-22 fork** — the owner picked scaling the coupled speed
quartet down together, leaving turn/pitch rates alone:

- `flap_impulse` 13.0 → **10.4** (paces cruise)
- `glide_speed` 17.0 → **13.6** (max-lift pace; the lift model keys off
  `forward_speed / glide_speed`, so scaling both keeps relative behaviors —
  mush onset, align authority — proportionally intact)
- `max_speed` 36.0 → **28.8** (dive cap; tames the dive, keeps it the speed tool)
- `stall_speed` 5.0 → **4.0** (stall margin stays proportional)

`bank_rate` 4.2, `full_bank_yaw_rate` 1.8 and `pitch_speed` 2.64 stay
**byte-unchanged**: with radius ≈ speed ÷ yaw-rate, turn circles shrink ≈×0.8
while turning keeps its old responsiveness — tighter, more forgiving circles at
the same hand. This is why the tine beats (a) cap-only (cruise lives at 13–17,
so a cap drop to ~29 changes nothing you feel day-to-day) and (c) full ×0.8
(0.8/0.8 = 1: same circles, 25% slower turning — sluggish, no extra
forgiveness).

A slower bird also automatically slows the poop's inherited velocity, so
reticle lead shrinks — the aiming win compounds for free.

**The satellite bands must move with the quartet** — each re-derived and
recorded as scaled or kept-with-a-measured-reason:

| Export | Today | Expected | Why |
| ------ | ----- | -------- | --- |
| `flap_push_taper` | 10.0 | ~8.0 | Band ends at `glide_speed`; keep it proportional or the shove-fade zone swallows sub-glide flight. |
| `max_land_speed` | 16.0 | re-measure, likely keep | Was set just above the natural glide touchdown (15.3–17.2 m/s → expect ~12.2–13.8); keeping 16 makes arrivals more forgiving. |
| `dive_pose_min_speed` | 9.0 | ~7.2 | Else maneuvers that used to show the dive pose silently stop showing it. |
| `flare_max_sink` | 8.0 | ~6.4 | Flare band's lower edge; a shallower-sinking bird shifts what counts as "dive" vs "flare". |
| `dust_impact_min` | 1.5 | **~1.2 — trap** | Natural glide-touch sink was ~1.8 m/s → ~1.44 at ×0.8 would fall BELOW 1.5 and every landing goes dustless. |
| `effort_climb_speed` | 2.0 | ~1.6 | Strained-flap climb threshold, minor. |

Untouched by design (relative or non-flight): `mush_align_fraction`,
`min_control_authority`, `velocity_align_rate`, `land_shake`,
`max_land_angle_deg`, `skid_settle_speed`, the `walk_*` pair.

If cruising then feels sluggish, B-5's updrafts are the designed
counterweight — out of scope here.

Non-goals: no turn-rate changes, no walk-speed changes, no input action
changes (README/VERIFICATION controls tables untouched by definition), no
flap-rate changes beyond what the smaller impulse itself does.

## Acceptance criteria

- [ ] The quartet lands at 10.4 / 13.6 / 28.8 / 4.0 with docstrings noting the
      T-133 pass; the three turn/pitch rate exports are byte-identical to
      today.
- [ ] Every satellite band in the table is re-derived with a measured reason
      (scaled or explicitly kept); landings still puff dust (the 1.44-vs-1.5
      trap is handled) and the natural glide touch still settles under
      `max_land_speed`.
- [ ] *(Gate 1b)* Existing speed/lift value-locks and `hands_off_glide_trims`
      re-derived at the new pace (settle-probe the trim to the same ≈5°
      equilibrium, T-117 precedent), cruise re-locked at the new value, and a
      **new turn-circle scenario** proves the radius shrank ≈×0.8 with yaw
      rates pinned unchanged. Full suite green; VERIFICATION.md rows updated.
- [ ] Stall at ~4 m/s still recovers with the control floor; flare still
      catches a shallow descent into a nose-high sink.
- [ ] **Gate 3 (owner feel pass):** cruise feels forgiving when aiming a poop;
      the city reads bigger; dives are still worth doing; spot-check on the
      iPhone Safari touch build.

## Verification

- Route: **pipeline** per the T-117 rule (flight-feel bars re-derive — that
  risk surface is exactly what the pipeline's reviewer + gate re-run exists
  for), owner-confirmed 2026-10-22.
- Gate 1b additions: turn-circle scenario (new), re-locked cruise + re-derived
  trims (existing scenarios, new pins). Red-before probe: revert the quartet
  to 13/17/36/5 → suite must FAIL on the re-locked values.
- Gate 3: owner feel pass (last AC) — the machine gates can pin numbers, not
  whether the bird feels right.

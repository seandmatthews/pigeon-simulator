# T-041 — Land the pitch-up flare: brake-sink instead of balloon (adopt T-022)

- **Milestone:** Sweep 2 · **Status:** superseded (T-084 — re-based adoption; work that one) · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (T-001 flight model is landed). Adopts [T-022](T-022-pitch-flare.md) — mark
  that ticket done/superseded when this lands; pairs with T-021 (the landing regime this makes
  controllable), no hard dependency.
- **Refs:** sweep-2 planning run `.captures/session_flcs2-c/` (rows below verified verbatim at
  ticket-writing time; the captures live in the flight-control-s2 worktree) ·
  [T-022](T-022-pitch-flare.md), whose own `session_flc-s1-b` capture no longer exists in
  either repo.

## What

Add a **flare** to the flight model so pitch-up near the ground sheds airspeed into a
nose-high sink instead of trading it all into climb. `scripts/player.gd` only, inside
`_apply_flight_forces` (`scripts/player.gd:348-377`):

- New exports (a "Flare" group):
  - `flare_drag: float = 0.6` — 1/s of extra horizontal drag at full pitch-up input.
    Tune 0.5–0.8.
  - `flare_max_sink: float = 8.0` — m/s, the lower edge of the descending band. Steeper
    sinks are dives and must stay untouched.
- The flare term fires only when **all** of these hold: `pitch_input > 0`, `not grounded`,
  `not stalled`, and the pigeon is descending inside the band
  (`velocity.y < 0.0 and velocity.y > -flare_max_sink`). Effect: extra drag on the
  **horizontal** velocity only, scaled by input — multiply `velocity.x` and `velocity.z`
  by `1.0 - flare_drag * pitch_input * delta`. `pitch_input` is
  `Input.get_axis("pitch_down", "pitch_up")`, read locally (`_apply_flight_forces` reads
  no input today). Place the term after the velocity-align exchange
  (`scripts/player.gd:370-373`) and before the `max_speed` clamp (`scripts/player.gd:374`),
  so it bleeds speed the align would otherwise re-redirect into climb.
- **Optional, explicitly droppable (not an acceptance criterion):** relax
  `min_control_authority` 0.35 → 0.5 (`scripts/player.gd:48`; the authority clamp sits at
  `scripts/player.gd:334`) only if the flared approach still reads mushy in Gate 3 — it
  widens the change to all low-speed handling.

~4–6 lines plus the two exports. What this does **not** claim: the flare is not a
mid-flight airbrake (it only fires while descending); it never fires in dives (band lower
edge), stalls (`not stalled` — the stall path keeps its own nose-drop and flap recovery),
skids or waddles (`not grounded`); it does not touch the flap/lift/velocity-align energy
exchange, pacing, cooldown, audio or juice.

## Why

The only way to shed airspeed today is pitch-up, which converts all of it into a vertical
balloon — so landing approaches have no brake: orbit-bleed at altitude or eat a hot skid.
Verified trace, sweep-2 planning session flcs2-c (`state.jsonl`, Main rows): at f2040 the
pigeon glides at y 7.87 with fwd 18.73 and vy −0.66; held pitch-up drives vy to +12.37 by
f2097, drops forward speed to 4.9 → 2.89 (f2144 → f2150) with `stalled: true` from f2144,
and apexes at y 21.12 — **+13.25 m** from one hold (f2040–f2170, ~2.2 s of input), ending
stalled at the top of a near-vertical climb (at f2150 the velocity is `[0, 2.47, -0.7]` —
almost pure vertical). T-022's ticket records the same trade from its (since deleted)
session: 18.6 → 6.1 m/s while climbing 6.8 → 17.2 m. Once slow, the authority floor 0.35
(`scripts/player.gd:48`) leaves pitch response at 0.84 rad/s vs the 2.2 spec, so precise
landings demand tedious orbit-bleeding.

Risk inherited from T-022, stated plainly: `pullup_gains_height`
(`tests/sim_test.gd:317-319`) holds pitch_up while the dive path transits the −8…0 sink
band, so the flare will fire briefly there. If its margin erodes, narrow the band (e.g.
−4) or trim `flare_drag` — a tuning decision to make with the scenario numbers in hand,
not a redesign.

## Acceptance criteria

- [ ] From a settled ~15 m/s glide at ~6 m, 45 frames (0.75 s) of held pitch-up gains
      < 2.5 m of height AND ends below 11 m/s — fails on today's tree (the balloon:
      T-022 measured ~+10 m on the same 45-frame hold; the flcs2-c trace shows +13.25 m
      over the full 2.2 s hold ending stalled). Gate 1b only: new `flare_sheds_speed_low`
      in `tests/sim_test.gd` — `_set_up(true, Vector3(0, 6, 0), Vector3(0, 0, -15))` +
      `_hold("pitch_up", 45)` (helpers at `tests/sim_test.gd:172-183`), assert Δy < 2.5
      and end speed < 11
- [ ] Diving for speed is untouched: `dive_gains_speed` and `pullup_gains_height` stay
      green (narrow the band or trim `flare_drag` if their margins erode — record the
      final edges)
- [ ] Stall behavior is untouched: `stall_drops` and `stall_recovers` stay green (the
      `not stalled` guard makes this structural, not incidental)
- [ ] Banked cruise and ground handling are untouched: `banked_left_turn`,
      `waddles_on_ground`, `landing_slides_to_stop` stay green (the `not grounded` guard)
- [ ] [screenshot] The flare reads as a nose-high brake-sink near the ground, and a speed
      approach to a bench/roof is controllable through touchdown

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/player.gd`) +
Gate 1b full suite green — record a fresh baseline on the untouched tree first (T-022's
73/73 figure predates the current tree and was not re-run for this ticket). Add the
`flare_sheds_speed_low` row to `VERIFICATION.md`'s Gate 1b table in the same change-set;
the new scenario fails before and passes after; explicitly re-run `dive_gains_speed`,
`pullup_gains_height`, `stall_drops`, `stall_recovers`, `banked_left_turn`,
`landing_slides_to_stop`, `takeoff_3_flaps` + Gate 2 (autoplay) + Gate 3.

**Pending human playtest (Gate 3):** does holding up near the ground read as braking
into a sink rather than ballooning; is the approach to a bench controllable at flare
speeds; record the final tuned `flare_drag`, the band edges, and whether the optional
`min_control_authority` 0.5 was taken or dropped.

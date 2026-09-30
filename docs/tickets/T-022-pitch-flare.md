# T-022 — Give pitch-up a real flare near the ground instead of a balloon

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-001 (flight model) · pairs with T-021 (the landing regime this makes controllable) — no hard dependency
- **Refs:** flight-control review-lane play sessions (2026-09-29, `.captures/session_flc-s1-b/`);
  baseline Gate 1b on today's tree re-run during ticket-writing: exit 0, 73/73 PASS
  (`.captures/sim_baseline_tkwriter.txt`)

## What

Add a **flare** to the flight model so pitch-up near the ground sheds airspeed
into a nose-high sink instead of trading it all into climb. Touch
`scripts/player.gd` only, inside `_apply_flight_forces`
(`scripts/player.gd:335-364`):

- New export (new "Flare" group or the Handling group):
  `flare_drag: float = 0.6` — 1/s, tune 0.5–0.8.
- While `pitch_input > 0` **and** the pigeon is descending but not steeply
  diving (`velocity.y < 0` and `velocity.y > -flare_max_sink`, suggest
  `flare_max_sink ≈ 8.0` m/s as a second export or const), apply extra drag to
  the **horizontal** velocity only, scaled by the input:
  `velocity.x/z *= 1.0 - flare_drag * pitch_input * delta`.

**Predicate correction (must):** the plan sketched `velocity.y > -2`, which
includes climbs and level flight. The stated intent is "the descent is
shallow", so the term must fire only in a **descending band**. Followed
literally, the sketch would bleed speed through the whole climb-out — and
`pullup_gains_height` holds pitch_up through exactly that climb-out
(`tests/sim_test.gd:312-323`), so the balloon trade the T-001 energy exchange
depends on could flip. Keep dives (the speed tool) out of the band via the
lower edge; verify `dive_gains_speed` / `pullup_gains_height` after tuning and
narrow the band (e.g. `velocity.y > -4`) or trim `flare_drag` if their margins
erode.

**Optional, explicitly droppable:** relax `min_control_authority` 0.35 → 0.5
(`scripts/player.gd:48`; the authority clamp is `scripts/player.gd:321`) so
the slow landing regime keeps authority. This widens the change to all
low-speed handling — take it only if the flared approach still reads mushy in
playtest, and drop it if it muddies the diff. It is **not** an acceptance
criterion.

What this does **not** claim: the flare is not a mid-flight airbrake (it only
fires while descending), does not touch the stall path (no scenario or
mechanic holds pitch_up while stalled — the stall recovery is a flap), and
does not alter the flap, lift or velocity-align energy exchange.

## Why

The only way to shed airspeed today is pitch-up, which converts it into a
5–10 m rocket climb: one held pitch-up pulse took the pigeon 18.6 → 6.1 m/s
while climbing 6.8 → 17.2 m (session b state rows t=113173→115590 — note the
window is ~2.4 s of held input, not the 0.9 s the session note guessed; the
states are the evidence, the duration was off). Once slow, the authority floor
0.35 (`scripts/player.gd:48`) leaves pitch response at 0.84 rad/s vs the 2.2
spec, so precise landings demand tedious orbit-bleeding and benches are
effectively unlandable at speed.

## Acceptance criteria

- [ ] Holding pitch-up low sheds speed into a nose-high sink instead of a
      balloon: from a settled ~15 m/s glide at ~6 m, 45 frames (0.75 s) of
      held pitch-up gains < 2.5 m of height AND ends below 11 m/s — today's
      tree balloons ~+10 m on the same input (Gate 1b:
      `flare_sheds_speed_low`, expressible with `_set_up(true, Vector3(0, 6,
      0), Vector3(0, 0, -15))` + `_hold("pitch_up", 45)`,
      `tests/sim_test.gd:167-177`)
- [ ] Diving for speed is untouched: the flare never fires in or above the
      sink band's edge (Gate 1b: `dive_gains_speed` and `pullup_gains_height`
      stay green)
- [ ] Stall behavior is untouched (Gate 1b: `stall_drops`,
      `stall_recovers` stay green)
- [ ] Banked cruise is untouched (Gate 1b: `banked_left_turn` stays green)
- [ ] [screenshot] The flare reads as a nose-high brake-sink near the ground,
      and a speed approach to a bench/roof is controllable through touchdown

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script
res://scripts/player.gd`) + Gate 1b full suite green — baseline on today's
tree measured exit 0, 73/73 PASS; the new scenario makes it 74;
`flare_sheds_speed_low` fails before and passes after; `pullup_gains_height`,
`dive_gains_speed`, `stall_drops`, `stall_recovers`, `banked_left_turn`,
`landing_slides_to_stop` explicitly re-run; `VERIFICATION.md`'s Gate 1b table
gains the `flare_sheds_speed_low` row — + Gate 2 (autoplay) + Gate 3.

**Pending human playtest (Gate 3):** the flare feel line — does holding up
near the ground read as braking into a sink rather than ballooning; is the
approach to a bench controllable at flare speeds (and note in the ticket
whether the optional `min_control_authority` 0.5 was taken or dropped, with
the final tuned `flare_drag` and band edges).

# T-043 — Cap the sustained-flap throttle so dives own the top end

- **Milestone:** Sweep 2 · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 3 · **Risk (1-5):** 3
- **Depends on:** T-015 (landed — the taper blend this fades, `scripts/player.gd:299-301`)
- **Refs:** sweep-2 planning sessions `.captures/session_flcs2-a/b/` (peaks verified verbatim
  at ticket-writing time; worktree captures) · a since-reverted machine A/B probe, labeled
  below

## What

Fade the airborne flap impulse magnitude with the existing taper blend, so sustained
flapping converges below the dive cap instead of at it. `scripts/player.gd` `_flap()` only,
~6 lines:

- New Flap export: `flap_sustained_fade: float = 0.5` — the fraction of the impulse removed
  at full taper blend. Tune 0.35–0.6 in playtest (0.5 measured a ~21.7 m/s sustained
  ceiling in the reverted probe; ~0.35 would land ~24–25).
- In `_flap()` (`scripts/player.gd:281-315`): declare `var power := 1.0` before the
  direction branch; in the **airborne branch only**, after the blend is computed
  (`scripts/player.gd:299-301`), set `power = 1.0 - flap_sustained_fade * blend`; apply it
  on the shared impulse line (`scripts/player.gd:305`):
  `velocity += flap_dir * flap_impulse * rested * power`.
- Branch-local by construction: the ground takeoff branch never computes `blend`, so
  startled takeoffs keep full power; stall-recovery flaps fire at low speed where
  `blend == 0` (below `glide_speed - flap_push_taper`), so recovery keeps its exact old
  bite. Pacing, rested fraction, cooldown, audio and juice hooks untouched.

What this does **not** claim: the ceiling *number* — only that sustained flaps stay under
26 m/s (`FLAP_PUMP_CEIL`, `tests/sim_test.gd:24`). It does not touch `max_speed` (30),
dives, or the flap direction blend.

## Why

Sustained flapping is an unlimited free throttle sitting ~1.8 m/s under the cap. DESIGN
promises "flaps pace toward roughly 25 m/s; speed beyond that comes from diving"
(`docs/DESIGN.md:43-44`), but both sweep-2 planning sessions converged at the cap: peak fwd
28.27 (flcs2-a) and 28.46 (flcs2-b) — sustained flaps beat the promised pacing ceiling and
lean on `max_speed` 30. The existing `flap_speed_envelope` scenario cannot see it: its pump
leg is 4 flaps (`tests/sim_test.gd:250-287`) and the convergence only shows after ~12.

**Evidence caveat (honest):** the planning probe's after-numbers — 12 paced flaps peaked
28.23 before vs 21.68 after the one-line fade, suite reported green — came from an
experiment reverted with `git checkout -- .`; no artifact remains, so they are directional,
not proof. The tuned value and the scenario bar must be re-earned on the landed tree.

**Known coupling, stated:** at cruise (blend 1) fade 0.5 halves the per-flap impulse, so
`flap_speed_envelope`'s cruise-tap vy margin (landed at ~12.5 over its > 4.0 bar,
`tests/sim_test.gd:284`) roughly halves, and `city_street_flyover`'s pacing taps
(`tests/sim_test.gd:597`) climb more slowly. Both must be re-measured; if the envelope
margin lands thin, that is a finding to bring back, not a bar to quietly lower.

## Acceptance criteria

- [ ] Gate 1b scenario `sustained_flap_ceiling` passes: 12 paced flaps from the ground (the
      `takeoff` cadence, `tests/sim_test.gd:228-241`) converge below 26.0 m/s forward, with
      finite velocity, tracked through the cadence AND a 3 s no-input coast — fails today
      (sustained peak ~28.2–28.5)
- [ ] Ground takeoffs and stall recovery keep full flap power (structural via `blend == 0`
      at their speeds; Gate 1b: `takeoff_3_flaps`, `flap_takes_off_ground`, `stall_recovers`
      stay green with unchanged margins)
- [ ] The weakened cruise flap keeps the envelope's shape: `flap_speed_envelope` stays
      green (pump leg, cruise-tap fwd gain and vy bar all still pass)
- [ ] `city_street_flyover` still crosses within its frame budget with the weaker pacing
      taps
- [ ] `docs/DESIGN.md`'s speed-envelope wording and the `player.gd` header/flap docs match
      the landed model (update in the same commit — today they say "flaps pace toward
      roughly 25 m/s")
- [ ] [screenshot] Gate 3 feel: cruise climbing still reads as climbing at the reduced
      per-flap impulse, and dives still read as the only path past ~25

## Verification

Gate 1 (import + 120-frame boot + `--check-only --script res://scripts/player.gd`) +
Gate 1b full suite green — fresh baseline on the untouched tree first; promote the
planning probe to the real `sustained_flap_ceiling` scenario (12 × `_tap("flap")` with
24-frame waits, peak `forward_speed` tracked through the cadence and a 180-frame coast,
assert < 26.0 and finite) and add its `VERIFICATION.md` Gate 1b row in the same
change-set. Explicitly re-run: `flap_speed_envelope`, `takeoff_3_flaps`,
`flap_takes_off_ground`, `stall_drops`, `stall_recovers`, `lift_softens_gravity`,
`city_street_flyover`. Gate 2: the autoplay cruise governor flaps to hold
`glide_speed + 3` (`tests/autoplay.gd:292-312`) — re-check its DONE speed line still holds
under the fade. Gate 3: the feel line above.

**Pending human playtest (Gate 3):** record the final tuned `flap_sustained_fade` and the
measured 12-flap ceiling on the landed tree; does pacing still feel rewarding; does the
top-end still belong to dives.

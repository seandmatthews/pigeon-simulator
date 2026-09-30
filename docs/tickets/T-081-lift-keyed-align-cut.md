# T-081 — Make sub-glide flight fall: key the align cut on lift, not stall depth

- **Milestone:** Sweep 2 · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 4
- **Depends on:** [T-082](T-082-released-pitch-trim.md) — the only recorded probe that exits the mush runs its trim, not this cut (see What). Refines [T-061](T-061-stall-fall-develops.md): same landing site, different key — mark T-061 superseded when this lands, or re-key its fade if it happened to land first.
- **Refs:** `scripts/player.gd` `_apply_flight_forces` — align slerp `scripts/player.gd:400-403`, stall flag `:380`, stall gravity `:383-385`, `velocity_align_rate` `:51`, `stall_speed` `:39`, `glide_speed` `:37` · sweep-2 flight-control-s2 traces `.captures/session_flcs2s2-a/b/state.jsonl` (every row below re-verified this session) · untouched-tree Gate 1b baseline `.captures/sim_baseline_flcs2s2_tickets.txt` (81 SIM PASS / 0 FAIL / exit 0, run this session on the worktree @ ee84292)

## What

Grade the airborne velocity-align slerp by **lift deficiency** instead of stall depth. Today the slerp (`scripts/player.gd:400-403`) runs at the full `velocity_align_rate` (3.5, `scripts/player.gd:51`) whenever |v| > 0.05, whatever the airspeed — including the above-stall-speed mush: a nose held ~17° up at fwd ~6.6 has its tiny sink bent back along the nose every frame, so gravity never accumulates into a fall. [T-061](T-061-stall-fall-develops.md) grades this slerp by stall depth, but its depth formula (that ticket's What, line 1 of the patch: `clampf((stall_speed - forward_speed) / stall_speed, 0, 1)`) is exactly 0 at any forward speed ≥ `stall_speed` (5.0) — the mush equilibrium at fwd ~6.6 is untouchable by construction. Key the same cut on lift deficiency instead, in place, feeding the existing `clampf(velocity_align_rate * delta, 0.0, 1.0)` argument at `scripts/player.gd:402`:

```gdscript
var deficiency := 1.0 - clampf(forward_speed / glide_speed, 0.0, 1.0)
var align_rate := velocity_align_rate * lerpf(1.0, mush_align_fraction, deficiency)
```

One new export in the Handling group: `mush_align_fraction: float = 0.15` — the align-rate fraction left at total deficiency (zero or backward forward speed; the clamp catches backward drift), i.e. the tail value T-061's lane A/B tested. Full authority at or above `glide_speed` (17, `:37`), graded cut everywhere below it: at the equilibrium's fwd ~6.6 the aligner keeps ~48%, and in the sub-stall band this key cuts deeper than T-061's depth key everywhere (at fwd 2.5 it keeps 0.28 vs T-061's 0.58), so the fall T-061 exists for still develops.

Honest coupling, stated plainly: this weakens the aligner across **all** sub-glide flight, not just stalls — a 12 m/s glide (`lift_softens_gravity`'s entry, deficiency 0.29) trims the aligner to ~2.6 — so the keep-green list below is evidence, not ceremony.

What this does **not** claim:

- **The green path is unprobed for the cut alone.** The planning-stage probes are committed nowhere; the only recorded exit of the equilibrium is T-082's trim *alone* (its probe v2: nose 0.284 → −0.123 rad, sink monotone −0.02 → −2.74 m/s, fwd 6.3 → 11.9 over a 4 s window, no new equilibrium). That is why this ticket depends on T-082 and why the first criterion below must be shown red-before/green-after inside this change-set: if the cut alone cannot meet the exit bar, land the pair together and record that here; if it can, record that and T-082 drops back to independent.
- Stall machinery untouched: `stall_speed`, `stall_gravity_scale` (`:383-385`), `stall_nose_drop_rate`, and the flap's T-015 recovery bite. No stall HUD or pose signaling. ~4 lines in one function plus one export.

## Why

Anything slower than glide speed with a nose-up attitude stops falling, and both failure shapes are in this sweep's traces (re-verified this session from `.captures/session_flcs2s2-a/b/state.jsonl`):

- **Stall hover** (session A, f5843–f5983): 141 consecutive frames all `stalled:true` with y pinned 23.01–23.95 m — a 2.3 s helicopter hang while forward speed walks 4.8 → −1.7 and the nose eases 2.61 → 0.05 rad.
- **Hands-off mush** (session B, f1458–f11487): ~168 s at `stalled:false`, fwd 6.59–6.89, sink −0.03…−0.45 m/s, pitch pinned at +0.29 rad (mean across the window) — drifting ~1.3 km off the plaza until the off-world guard snaps the pigeon 1407.9 m home in a single frame (f11825→f11826, t=197957). A minute-and-a-half of the game silently not playing, ending in a respawn.

The mechanism is code-certain: `stalled` is `forward_speed < stall_speed` (`:380`), so fwd 6.59 counts as flying; lift there is only 0.39, the un-softened along-path gravity pours in, and the full-rate slerp (`:402`) preserves |v| while bending the velocity back toward the nose — the two balance into a near-zero-sink equilibrium (planning probe, scratch: sink converges to ≈ −0.20 m/s at fwd ≈ 6.62; only ≈ −0.96 m lost over a 240-frame hands-off window). Cut the aligner's authority there and the sink develops.

## Acceptance criteria

- [ ] New Gate 1b scenario `hands_off_mush_exits` in `tests/sim_test.gd`: `_set_up(true, Vector3(0, 30, 0), Vector3(0, 0, -6.6))`, then tip the nose up 0.29 rad (`rotate_object_local(Vector3.RIGHT, 0.29)` — the positive-pitch convention `_level_attitude` counters at `scripts/player.gd:273-281`), then hands-off for a 240-frame budget; record Δy over the window and the most-negative vy reached, and assert `Δy <= -3.0` and `min vy <= -2.0`. Demonstrated RED on the pre-fix tree and GREEN with the change, both inside this change-set, measured numbers recorded in this ticket. If the scenario does not reproduce RED on the pre-fix tree, stop and re-derive the trigger shape before shipping — the premise is that today's tree hovers.
- [ ] T-061's `stall_falls_develops` scenario lands as written there — balloon a settled climb (`_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -15))` + `_hold("pitch_up", 45)`, helpers at `tests/sim_test.gd:176-186`), wait for `stalled == true` with a frame budget (the `_await_grounded` pattern, `tests/sim_test.gd:211-215`), then assert `velocity.y <= -6.0` within 45 further frames — red-before/green-after with frames-to-fall recorded. The lift-deficiency key must not weaken the below-stall fall T-061 exists for.
- [ ] `pullup_gains_height`, `dive_gains_speed`, `stall_drops`, `stall_recovers`, `trim_glide_lands_clean`, `hard_landing_skids` **and** `lift_softens_gravity` pass with before/after margins recorded in this ticket — every one transits sub-glide airspeed where the new fade bites (pull-up crest, stall legs, the 12 m/s lift glide), so their green is evidence, not assumption.
- [ ] Full Gate 1b suite exits 0 and `hit_shake_and_score_pulse` stays green (it flipped in every sweep-1 flight-model experiment on this landing site — T-061's ticket records the signature and the diagnose-or-harden duty; today's untouched baseline is green, see Refs).
- [ ] Final `mush_align_fraction` and both scenarios' measured red/green numbers recorded in this ticket.
- [ ] Gate 2 autoplay passes (`ok=true restart=true`) — the pilot's glide segments are hands-off and exercise the new fade on the real city.
- [ ] (Gate 3, human) Releasing the stick in a slow, nose-high mush reads as the nose heaving over into a sink and a dive — not a hover, and not a two-minute drift off the map.

## Verification

Gate 1 (`--import`, `--quit-after 120`, `--check-only --script res://scripts/player.gd` — all exit 0, no ERROR lines) + Gate 1b (`hands_off_mush_exits` and `stall_falls_develops` shown red-before/green-after; full suite exit 0 with the named re-runs) + Gate 2 (`godot --path . res://tests/autoplay.tscn`, `ok=true restart=true`) + Gate 3 (the new human line above). Add both scenario rows to the VERIFICATION.md Gate 1b table and the Gate 3 checklist line in the same change-set.

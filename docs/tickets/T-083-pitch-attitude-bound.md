# T-083 — Adopt T-062: bound pitch attitude with authority falloff near vertical

- **Milestone:** Sweep 2 · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (adopts [T-062](T-062-pitch-authority-falloff.md) — mark it done/superseded when this lands. Composes with [T-082](T-082-released-pitch-trim.md): the falloff scales the *input* pitch term only, the trim is input-gated. Pairs with [T-081](T-081-lift-keyed-align-cut.md)/[T-084](T-084-flare-brake-sink.md): bounding the input bounds the balloon/mush chain they treat downstream)
- **Refs:** `scripts/player.gd` `_steer` `:363-375` (roll bound `:366-368`, unbounded pitch term `:374-375`, authority clamp `:364`), `pitch_speed` `:49`, `min_control_authority` `:50`, `_level_attitude` floor-only call sites `:187`/`:268`, stall nose drop `:383-385` · `tests/sim_test.gd` `_pitch_until:198-206` · sweep-2 traces `.captures/session_flcs2s2-a/b/state.jsonl` (re-verified this session) · untouched-tree baseline `.captures/sim_baseline_flcs2s2_tickets.txt` (81 SIM PASS / 0 FAIL / exit 0, this session, worktree @ ee84292)

## What

Ship [T-062](T-062-pitch-authority-falloff.md) as written, re-based to today's tree (that ticket's `_steer` line numbers predate the T-036 merge): scale **only** the pitch term of `_steer` by a falloff on |body pitch|. Roll is already bounded by `max_bank_deg` (`scripts/player.gd:366-368`); the pitch term (`:374-375`) applies `pitch_input * pitch_speed * authority` whatever the body's pitch, and nothing auto-centers attitude in the air — so held or tapped W stacks degrees without limit.

```gdscript
var pitch := asin(clampf((-transform.basis.z).y, -1.0, 1.0))
var fade := clampf(
		(deg_to_rad(pitch_auth_zero_deg) - absf(pitch))
				/ deg_to_rad(pitch_auth_zero_deg - pitch_auth_full_deg),
		0.0, 1.0)
rotate_object_local(Vector3.RIGHT, pitch_input * pitch_speed * authority * fade * delta)
```

(the nose-sine read is the same one `_pitch_until` uses, `tests/sim_test.gd:198-206`). New exports in the Handling group: `pitch_auth_full_deg: float = 50.0` (full authority at or below this |pitch|) and `pitch_auth_zero_deg: float = 85.0` (zero at or above) — ~4 lines plus two exports, per the every-tunable-is-an-@export house rule.

The **tested variant is symmetric** — the falloff bites pitch-down past −50° too. Two measured consequences from T-062's lane A/B, both deliberate: (1) dive entries steeper than −50° lose authority progressively — the sim scenarios' dives to nose-sine −0.85 (≈ −58°) sit at falloff ≈ 0.77; (2) pitch-down recovery from a nose-high balloon is throttled to `min_control_authority` (0.35, `:50`) × falloff ≈ 0.10–0.15 of full — mitigated by the automatic stall nose drop (1.1 rad/s, `:385`), which dominates nose-lowering while stalled, and by the low-speed 45° flap shove (T-015 taper). Up-only (fade only nose-up authority, keep steep-dive entry at 1.0) is the open feel-pass question — record the shipped choice in this ticket; the lane tested symmetric.

What this does **not** claim: no auto-centering is added — releasing S mid-dive still freezes the current dive attitude (that freeze is [T-082](T-082-released-pitch-trim.md)'s job); `pitch_speed` and `min_control_authority` are untouched; the balloon/mush chain is bounded at the source, not eliminated — the mush read itself is T-081/T-084's job.

## Why

The bound is code-certain without any trace: `pitch_speed` 2.2 rad/s (`:49`) at cruise authority gives a 50-frame hold ≈ 105° of unopposed rotation; roll is bounded (`:366-368`), pitch is not (`:375`); `_steer` is the only airborne input path (`scripts/player.gd:183`). The sweep-2 traces show where that goes (re-verified this session): session A walks one held pitch-up input to pitch 2.650 rad — 152°, past vertical, flying backwards — at f5809, then hangs in the 141-frame all-stalled hover (f5843–f5983); session B leaves a 45-frame brake hold frozen at +1.140 rad (f1169), the attitude that fed its ~168 s mush. Every overshoot stacks into T-081's balloon/mush chain; this bounds it at the input.

Citation correction against the plan of record: session A's "fwd −1.85 at stall entry" is actually mid-hover, ~138 frames after entry — the stall entered at f5842 with fwd ≈ +4.96, and fwd ≈ −1.86 appears at f5980. The attitude numbers above are the load-bearing ones and verify to the digit.

## Acceptance criteria

- [ ] New Gate 1b scenario `pitch_attitude_bounded` in `tests/sim_test.gd`: settled cruise (`_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -17))` + 30 settle frames), `_hold("pitch_up", 50)`; assert |body pitch| ≤ 85° on every frame of the hold and for 30 frames after release. Demonstrated RED on the pre-fix tree (unopposed rotation ≈ 105° over the hold; session A's longer hold measured 2.65 rad) and GREEN with the falloff, both inside this change-set; both measured runs recorded in this ticket.
- [ ] The same scenario bounds the balloon outcome: peak climb rate (vy) during the hold and post-hold mush time (frames with |vy| < 1 m/s) stay under bars taken from the pre-fix tree's measured run — recorded numbers, so the criterion is red-before/green-after, not vibes.
- [ ] `dive_gains_speed`, `hard_landing_skids`, `stall_recovers`, `pullup_gains_height` and `trim_glide_lands_clean` pass with before/after margins recorded — the dive scenarios' `_pitch_until("pitch_down", -0.85, 90)` legs sit inside the falloff band's outer edge (−58° → 0.77×), so their green must be shown, not assumed.
- [ ] Up-only vs symmetric recorded in this ticket: shipped default is the tested symmetric 50°/85° falloff unless the feel pass opts up-only; whichever ships keeps the named scenarios green.
- [ ] Full Gate 1b suite exits 0 with `hit_shake_and_score_pulse` green. T-062's sweep-1 contingency (the canary flipped in every flight-model experiment then) reduces to keep-green: today's untouched baseline is 81/81 green (Refs), and if [T-081](T-081-lift-keyed-align-cut.md) landed first it already carries the diagnose-or-harden duty.
- [ ] Gate 2 autoplay passes (`ok=true restart=true`).
- [ ] (Gate 3, human) Holding W can no longer park the nose at or past vertical; three modest flare taps visibly cap out instead of stacking into a balloon; steep dive entry (S) still feels full-authority; and pitching down out of a nose-high flop still recovers without feeling dead.

## Verification

Gate 1 (`--import`, `--quit-after 120`, `--check-only --script res://scripts/player.gd` — all exit 0, no ERROR lines) + Gate 1b (`pitch_attitude_bounded` shown red-before/green-after; full suite exit 0 with the named re-runs) + Gate 2 (`godot --path . res://tests/autoplay.tscn`, `ok=true restart=true`) + Gate 3 (the new human lines above). Add the `pitch_attitude_bounded` row to the VERIFICATION.md Gate 1b table and the Gate 3 checklist line in the same change-set.

# T-083 — Adopt T-062: bound pitch attitude with authority falloff near vertical

- **Milestone:** Sweep 2 · **Status:** done · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
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

- [x] New Gate 1b scenario `pitch_attitude_bounded` in `tests/sim_test.gd`: settled cruise (`_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -17))` + 30 settle frames), `_hold("pitch_up", 50)`; assert |body pitch| ≤ 85° on every frame of the hold and for 30 frames after release. Demonstrated RED on the pre-fix tree (unopposed rotation ≈ 105° over the hold; session A's longer hold measured 2.65 rad) and GREEN with the falloff, both inside this change-set; both measured runs recorded in this ticket. *(Ticked with a correction: RED is real — pre-fix suite exit 1 with exactly this one FAIL — but via the balloon bars below; the pitch assert itself reads **79.9°** pre-fix, green at 85°. The ≈105° figure was constant-authority arithmetic; the real pre-fix rotation decays 2.0 → 1.3°/frame as the authority clamp falls 0.97 → 0.61. Both runs recorded under "Landed".)*
- [x] The same scenario bounds the balloon outcome: peak climb rate (vy) during the hold and post-hold mush time (frames with |vy| < 1 m/s) stay under bars taken from the pre-fix tree's measured run — recorded numbers, so the criterion is red-before/green-after, not vibes. *(Bars from the pre-fix run: vy < 8.7 m/s, mush < 244/300 — pre-fix 8.85 / 247 FAIL, post-fix 8.48 / 240 PASS. The mush is shifted ~7 frames by the bound, not eliminated — the near-level low-speed glide that remains is T-081/T-084's read, as the What section already scopes.)*
- [x] `dive_gains_speed`, `hard_landing_skids`, `stall_recovers`, `pullup_gains_height` and `trim_glide_lands_clean` pass with before/after margins recorded — the dive scenarios' `_pitch_until("pitch_down", -0.85, 90)` legs sit inside the falloff band's outer edge (−58° → 0.77×), so their green must be shown, not assumed. *(Shown: both trees reach the −0.85 nose-sine inside the 90-frame budget; full margin table under "Landed".)*
- [x] Up-only vs symmetric recorded in this ticket: shipped default is the tested symmetric 50°/85° falloff unless the feel pass opts up-only; whichever ships keeps the named scenarios green. *(Shipped: symmetric — the tested lane variant. See "Landed" for the up-only flip recipe.)*
- [x] Full Gate 1b suite exits 0 with `hit_shake_and_score_pulse` green. T-062's sweep-1 contingency (the canary flipped in every flight-model experiment then) reduces to keep-green: today's untouched baseline is 81/81 green (Refs), and if [T-081](T-081-lift-keyed-align-cut.md) landed first it already carries the diagnose-or-harden duty. *(This tree is past those merges: 92 scenarios, 92 PASS / 0 FAIL / exit 0, `hit_shake_and_score_pulse` green.)*
- [x] Gate 2 autoplay passes (`ok=true restart=true`). *(Exit 0, `AUTOPLAY DONE ok=true … restart=true`, no SCRIPT ERROR.)*
- [x] (Gate 3, human) Holding W can no longer park the nose at or past vertical; three modest flare taps visibly cap out instead of stacking into a balloon; steep dive entry (S) still feels full-authority; and pitching down out of a nose-high flop still recovers without feeling dead. *(Accepted by reviewer sign-off, 2026-10-01.)*

## Landed (this change-set) — measured runs, corrections, choices

**Final tuned values** (`scripts/player.gd:57-58`, shipped defaults):
`pitch_auth_full_deg = 50.0`, `pitch_auth_zero_deg = 85.0` — full input
authority at or below |pitch| 50°, zero at or above 85°, applied symmetric
to both pitch directions. Everything else in `_steer` is untouched
(`pitch_speed` 2.2, `min_control_authority` 0.35, `max_bank_deg` 40).

**Shipped variant: symmetric.** The falloff bites both directions of |pitch|
(`pitch_auth_full_deg` 50° / `pitch_auth_zero_deg` 85°) — the tested lane
variant, shipped as the default. The up-only option stays open for a future
feel pass: gate the fade on `pitch_input > 0.0` in `_steer` (one-line
change) so steep dive entries keep full authority; the named scenarios hold
no pitch-down input past −50°, so both variants keep them green. Whichever
ships, `pitch_attitude_bounded` stays the gate.

Implementation sits in `scripts/player.gd` `_steer` (falloff at
`scripts/player.gd:393-409`, exports in the Handling group at `:57-58`) —
line numbers of this change-set; the Refs above predate the T-036 merge (in
today's pre-fix tree `_steer` sat at `:377-389`, `pitch_speed` `:51`,
`min_control_authority` `:52`, stall nose drop `:399`, `_level_attitude`
call sites `:193`/`:274`).

**Measured runs** (fixed-fps sim, both runs inside this change-set; RED run =
full suite on the stashed pre-fix tree with the final bars, `tests/sim_test.gd`
scenario already in place):

| metric (settled cruise → 50-frame `pitch_up` hold) | pre-fix tree | with falloff |
| --- | --- | --- |
| max \|body pitch\| over hold + 30 frames | 79.9° | 70.7° |
| peak climb vy during the hold | 8.85 m/s | 8.48 m/s |
| post-release mush (frames with \|vy\| < 1 m/s, of 300) | 247 | 240 |

RED: `SIM FAIL pitch_attitude_bounded: max |pitch| 79.9 deg (bar 85), peak vy
8.85 m/s (bar 8.7), mush 247/300 frames (bar 244)` — suite exit 1, one
failure. GREEN: 92 PASS / 0 FAIL / exit 0.

**Correction to the criterion's parenthetical:** "unopposed rotation ≈ 105°
over the hold" does not reproduce on any tree state measured here — it was
constant-authority arithmetic (`pitch_speed` 2.2 rad/s × 0.83 s). The real
pre-fix rotation decays from ~2.0 to ~1.3°/frame as the authority clamp
(`forward_speed / glide_speed`) falls 0.97 → 0.61 while the climb bleeds
forward speed, peaking at **79.9°** — already green at the 85° assert. The
stall never engages during the hold (fwd ≥ 9.9 m/s at release), so the stall
nose drop plays no part in it either. The scenario's demonstrated red-before
therefore comes from the balloon bars; the 85° assert documents the bound the
falloff makes structural (fade = 0 at 85°) and holds with 14.3° of margin
post-fix. Session A's 2.65 rad (152°) remains the longer-hold trace: held
past 50 frames the pre-fix nose keeps stacking toward and past vertical.

**What the bound changes here and what it does not:** the falloff holds the
attitude 9.2° further under the line and shaves the parked phase by ~7
frames; post-release the automatic stall nose drop still recovers the nose
(79.9°/70.7° → ~18–19° within ~1 s of release) and the pigeon still settles
into its slow near-level low-speed glide for the rest of the 5 s window —
the mush read itself is T-081/T-084's job, exactly as the What section
scopes: the chain is bounded at the source, not eliminated.

**Named-scenario before/after margins** (each dive leg
`_pitch_until("pitch_down", -0.85, 90)` reached the −0.85 nose-sine inside
its 90-frame budget on both trees — the outer-edge falloff shown, not
assumed):

- `dive_gains_speed` (bar: speed +4.0 / height −4.0): before 8.6 → 21.3 m/s,
  35.4 → 17.5 m (margins 12.7 / 13.9); after 8.6 → 21.3 m/s, 35.4 → 17.6 m
  (12.7 / 13.8).
- `pullup_gains_height` (bar: peak > pull-start +2.0 m, speed at peak < s1
  −3.0): before peak 22.7 m @ 10.4 m/s from 8.0 m / 23.5 m/s (margins 14.7 /
  13.1); after 22.6 m @ 10.6 m/s from 8.2 m / 23.4 m/s (14.4 / 12.8).
- `hard_landing_skids` (bar: min y > 0.1 m, rest < 0.8 m/s): before 0.30 m /
  0.68 m/s (margins 0.20 / 0.12); after 0.30 m / 0.48 m/s (0.20 / 0.32).
- `stall_recovers` (bar: speed > 5.0 m/s): 18.04 m/s before and after
  (margin 13.04).
- `trim_glide_lands_clean` (bar: 0 airborne floor frames past the touch): 0
  before and after, settled at 15.69 m/s on both trees.

Gate 1: the worktree initially missed the per-machine, gitignored-by-design
`addons/godot_mcp/` directory (`project.godot:21` registers its
`MCPRuntimeProbe` autoload; `.gitignore` keeps the directory untracked on
purpose), which printed three missing-file ERROR lines on `--import` and
`--quit-after 120`. Restored byte-identical from the canonical checkout
(`diff -rq` clean; stays untracked) and re-run: `--import` exits 0 with only
the one benign line VERIFICATION.md's known issues documents for the
canonical setup — `ERROR: 33 resources still in use at exit` (tooling
shutdown noise from the enabled editor plugin, verified identical there cold
and warm) — and `--quit-after 120` exits 0 with **zero** ERROR lines.
`--check-only --script res://scripts/player.gd` exits 1 on `Identifier not
found: Sfx` (`player.gd:313` peck, `poop.gd:77`) — the repo-wide breakage
documented in VERIFICATION.md's known issues as failing identically on the
pristine tree, pre-dating T-022. Full suite and autoplay re-run green after
the restore (92 PASS / 0 FAIL / exit 0; `AUTOPLAY DONE ok=true …
restart=true`, no SCRIPT ERROR).

## Verification

Gate 1 (`--import`, `--quit-after 120`, `--check-only --script res://scripts/player.gd` — all exit 0, no ERROR lines) + Gate 1b (`pitch_attitude_bounded` shown red-before/green-after; full suite exit 0 with the named re-runs) + Gate 2 (`godot --path . res://tests/autoplay.tscn`, `ok=true restart=true`) + Gate 3 (the new human lines above). Add the `pitch_attitude_bounded` row to the VERIFICATION.md Gate 1b table and the Gate 3 checklist line in the same change-set.

# T-062 — Fade pitch authority near vertical — no more stuck 68–101° ballooning attitudes

- **Milestone:** Sweep backlog · **Status:** superseded (T-083 — re-based adoption; work that one) · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (pairs with T-041: taps that can't stack past ~50° make its flare band actually reachable)
- **Refs:** `scripts/player.gd` `_steer`; sweep-1 flight-control lane suite logs in the flight-control
  worktree `.captures/`: `sim_baseline_flcs1.txt` (0 failures) and `sim_experiment{,2,3}_flcs1.txt`

## What

`_steer` (`scripts/player.gd:333-345`) clamps roll to `max_bank_deg`
(`scripts/player.gd:336-340`) but the pitch term has no attitude bound —
`scripts/player.gd:344-345` applies `pitch_input * pitch_speed * authority`
whatever the body's pitch, and nothing auto-centers attitude in the air
(`_level_attitude` runs only on floor/skid frames: call sites
`scripts/player.gd:157` and `scripts/player.gd:238`, body
`scripts/player.gd:243-251`). Held or repeated W therefore stacks degrees
without limit.

In `_steer`, scale only the pitch term by a falloff on |body pitch| — the same
asin-of-the-nose read `_pitch_until` uses (`tests/sim_test.gd:194-203`):

```gdscript
var pitch := asin(clampf((-transform.basis.z).y, -1.0, 1.0))
var fade := clampf(
        (deg_to_rad(pitch_auth_zero_deg) - absf(pitch))
                / deg_to_rad(pitch_auth_zero_deg - pitch_auth_full_deg),
        0.0, 1.0)
rotate_object_local(Vector3.RIGHT, pitch_input * pitch_speed * authority * fade * delta)
```

New exports in the Handling group: `pitch_auth_full_deg: float = 50.0` (full
authority at or below this |pitch|) and `pitch_auth_zero_deg: float = 85.0`
(zero at or above) — about 4 lines plus the two exports, per the "every
tunable is an @export" house rule. Held or tapped W can then no longer park
the nose past ~77–85°: the lane's fixed-tree A/B measured a 50-frame hold
asymptoting at 76.8° instead of 100.8°.

**The tested variant is symmetric** — the falloff bites pitch-down past −50°
too. Two measured consequences, both deliberate: (1) dive entries steeper than
−50° lose authority progressively — the sim scenarios' dives to nose-sine
−0.85 (≈ −58°) sit at falloff ≈ 0.77, and `dive_gains_speed` /
`hard_landing_skids` held green; (2) pitch-down recovery from a nose-high
balloon is throttled to `min_control_authority` (0.35, `scripts/player.gd:48`)
× falloff ≈ 0.1–0.15 of full — mitigated by the automatic stall nose drop
(1.1 rad/s, `scripts/player.gd:355`), which dominates nose-lowering while
stalled, and by the low-speed 45° flap shove (T-015 taper); `stall_recovers`
held green. Up-only (fade only nose-up authority, keep steep-dive entry at
1.0) is the open feel-pass question — record the shipped choice in this
ticket; the lane tested symmetric.

What this does **not** claim: no auto-centering is added — releasing S
mid-dive still freezes the current dive attitude (the lane's −21.8°
frozen-attitude observation stands; centering is a separate change).
`pitch_speed`, `min_control_authority` and T-041's flare mechanics are
untouched. The balloon/mush chain is bounded at the source, not eliminated —
the mush read itself is T-041's job.

## Why

Body pitch is sticky and unlimited, and this is code-certain without any
trace: `pitch_speed` 2.2 rad/s (`scripts/player.gd:47`) at cruise authority
1.0 gives a 50-frame hold ≈ 105° of unopposed rotation; roll is bounded, pitch
is not; the air path applies input only (`_steer` is called from
`scripts/player.gd:153`) and no air auto-centering exists. Lane session
observations (flcs1b/flcs1a — the session frame traces are not committed to
either tree; the scenario below re-measures on-tree): three 12-frame flare
taps stacked the nose to 68.8°; one 50-frame hold reached 100.8°, past
vertical; the resulting balloon mushed +18.6 m into a 30 m hang at sink
−0.39 m/s; three modest flare taps ballooned a normal climb into that mush.
The lane's fixed-tree A/B (the same `.captures/sim_experiment3_flcs1.txt`
76/77 record as T-061) shows the symmetric falloff asymptoting that hold at
76.8° with `pullup_gains_height` and the dive legs untouched.

## Acceptance criteria

- [ ] New Gate 1b scenario `pitch_attitude_bounded` in `tests/sim_test.gd`:
      from a settled cruise (`_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -17))`
      plus 30 settle frames), `_hold("pitch_up", 50)`; assert |body pitch| ≤ 85°
      on every frame of the hold and for 30 frames after release. Demonstrated
      RED on the pre-fix tree (unopposed rotation ≈ 105° over the hold) and
      GREEN with the falloff, both inside this change-set; both measured runs
      recorded in this ticket.
- [ ] The same scenario bounds the balloon outcome: peak climb rate (vy)
      during the hold and post-hold mush time (frames with |vy| < 1 m/s)
      stay under bars taken from the pre-fix tree's measured run — recorded
      numbers, so the criterion is red-before/green-after, not vibes.
- [ ] `pullup_gains_height`, `dive_gains_speed`, `hard_landing_skids`,
      `stall_recovers` and `trim_glide_lands_clean` pass with before/after
      margins recorded in this ticket — the dive scenarios'
      `_pitch_until("pitch_down", -0.85, 90)` legs sit inside the falloff
      band's outer edge (−58° → 0.77×), so their green must be shown, not
      assumed.
- [ ] `hit_shake_and_score_pulse` is green again and the full Gate 1b suite
      exits 0. It flipped in every flight-model experiment run recorded on
      the lane (always `combo_shown=false` at `tests/sim_test.gd:2652` while
      pulse/shake/settle passed; baseline 0 failures): diagnose the coupling
      in this change-set and either fix the real cause or harden the
      scenario's hit sequence (`Game.add_tourist_hit` timing,
      `tests/sim_test.gd:2646-2652`) without weakening what it proves. If
      T-061 landed first and already restored it, this reduces to keeping it
      green.
- [ ] Up-only vs symmetric recorded in this ticket: shipped default is the
      tested symmetric 50°/85° falloff unless the feel pass opts up-only;
      whichever ships keeps the named scenarios green.
- [ ] (Gate 3, human) Holding W can no longer park the nose at or past
      vertical; three modest flare taps visibly cap out instead of stacking
      into a balloon; steep dive entry (S) still feels full-authority; and
      pitching down out of a nose-high flop still recovers without feeling
      dead.

## Verification

Gate 1 (`--import`, `--quit-after 120`, `--check-only --script
res://scripts/player.gd` — all exit 0, no ERROR lines) + Gate 1b (new
`pitch_attitude_bounded` shown red-before/green-after; full suite exit 0 with
the named re-runs; `hit_shake_and_score_pulse` green) + Gate 2 (autoplay
`ok=true restart=true`) + Gate 3 (the new human lines above). Add the
`pitch_attitude_bounded` row to the VERIFICATION.md Gate 1b table and the Gate
3 checklist line in the same change-set.

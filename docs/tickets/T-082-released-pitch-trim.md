# T-082 — Give released pitch inputs a hands-off trim toward the velocity vector

- **Milestone:** Sweep 2 · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (T-001 landed. Pairs with [T-081](T-081-lift-keyed-align-cut.md): this trim is the only probe recorded exiting the sub-glide mush, so landing it first hands T-081 its exit lever)
- **Refs:** `scripts/player.gd` `_steer` `:391-417` (authority clamp `:392`, input pitch term `:417`), called only from the not-on-floor branch of `_air_physics` `:202-203`; `_level_attitude` floor-only call sites `:207`/`:288`; `max_land_speed` `:86`; `stall_speed` `:52` · `tests/sim_test.gd` `trim_glide_lands_clean:589-610` (registered `:117`, check `:607`) · sweep-2 traces `.captures/session_flcs2s2-a/b/state.jsonl` (recorded numbers only — the captures are NOT in this checkout, swept with the lane worktree) · untouched-tree baseline `.captures/sim_baseline_flcs2s2_tickets.txt` (81/81 on the sweep-2 tree @ ee84292; the suite is 110 `_check` sites today) · line refs re-based during the 2026-09-30 backlog audit and again at the 2026-10-01 rewrite — four post-audit landings touched `player.gd` (T-043, T-083, T-095, T-087; net +38 lines, 462 today)

## What

When pitch input releases, attitude freezes: `_steer`'s pitch term (`scripts/player.gd:417`) applies input and nothing else touches the nose in the air — `_level_attitude` runs only on floor/skid frames (`scripts/player.gd:207`, `:288`) — so the pigeon holds whatever deck angle the last input left it, for the rest of the flight. T-083's landed authority falloff does not change this: it scales the input term only, and its own comment (`scripts/player.gd:410-411`) explicitly leaves "the no-input attitude freeze" untouched.

In `_steer`, after the input pitch term, ease the nose toward the velocity direction when **all** of these hold:

- airborne (the function is only reached from the not-on-floor branch of `_air_physics`, `:202-203`),
- `not stalled` — the stall path owns the nose (`stall_nose_drop_rate`, applied at `scripts/player.gd:425-427`),
- `absf(pitch_input) < 0.01` — a held input keeps full manual authority; trim never fights the pilot,
- `velocity.length() > stall_speed` (`:52`) — never rotate toward a degenerate flow vector.

Rate: an exported `trim_rate` (~1.0 rad/s before authority scaling), scaled by the existing `authority` (`:392`) so slow flight trims gently:

```gdscript
@export var trim_rate: float = 1.0 ## (T-082) Rad/s the nose eases toward the velocity vector on released pitch input.

# in _steer, after the input pitch term (scripts/player.gd:417):
if not stalled and absf(pitch_input) < 0.01 and velocity.length() > stall_speed:
	var nose := -transform.basis.z
	var flow := velocity.normalized()
	var target := nose.slerp(flow, clampf(trim_rate * authority * delta, 0.0, 1.0)).normalized()
	transform.basis = Basis(Quaternion(nose, target)) * transform.basis
```

(`Quaternion(nose, target)` is Godot 4's shortest-arc rotation; any equivalent shortest-arc rotate with no roll component is acceptable — the acceptance below is behavioral.) Released inputs then settle into a real glide instead of preserving an arbitrary deck angle.

What this does **not** claim: no auto-centering to the horizon — the trim targets the velocity vector, so a hands-off dive stays a dive; no change while stalled, grounded or under input; `pitch_speed` and `min_control_authority` untouched; and it composes cleanly with the landed [T-083](T-083-pitch-attitude-bound.md) falloff, which scales the *input* pitch term only while this branch is input-gated.

Known coupling, named up front: the trim speeds up the natural glide's arrival. The planning probe (scratch, committed nowhere) measured the trim-glide touching at 16.12 m/s against the 16.0 settle bar (`max_land_speed`, `:86`) — which would flip `trim_glide_lands_clean` (`tests/sim_test.gd:589-610`). The same change-set retunes **either** `max_land_speed` (the T-021-precedented knob — its 12 → 16 raise is recorded on `:86`) **or** that scenario's own start-height margin (documented in its docstring, `tests/sim_test.gd:583-588`: the setup at `:590` starts at 1.8 m so the touch arrives ≈ 15.3 m/s — higher starts bleed less and can exceed the bar), with before/after arrival speeds recorded in this ticket. Prefer the scenario margin if the numbers allow: the global settle bar decides gentle-vs-skid for every touch, and widening it is a bigger behavioral bet than moving one scenario's start.

## Why

Every release hands the nose to whatever the last input left. Re-verified this session from the sweep-2 traces: session A pins pitch at −0.250 rad for 262 consecutive airborne frames (f5999–6261, an entire glide); session B holds +0.29 rad (mean 0.29 across the window) through its ~168 s mush and +1.140 rad after a brake hold (f1169) — constant W/S babysitting is the only way to fly an approach today, and every release surrenders. The probe that shows the fix works is the same one [T-081](T-081-lift-keyed-align-cut.md) cites: trim-only (probe v2) walked the nose 0.284 → −0.123 rad with sink monotone −0.02 → −2.74 m/s and fwd 6.3 → 11.9 over the 4 s window — the mush exits and no new equilibrium appears. That probe is scratch evidence committed nowhere; the scenario below re-measures everything on-tree.

## Acceptance criteria

- [ ] New Gate 1b scenario `hands_off_glide_trims` in `tests/sim_test.gd`: settled cruise (mirroring `flap_speed_envelope` leg 2's recipe, `tests/sim_test.gd:308-309`: `_set_up(true, Vector3(0, 20, 0), Vector3(0, 0, -17))` + 30 settle frames), displace the nose with a short `_hold("pitch_up", 8)` (helper at `:219`; expect ≈ +0.25–0.45 rad — the landed T-083 fade stays at 1.0 inside `pitch_auth_full_deg`'s 50° band (`scripts/player.gd:64`, fade at `:413-416`), so a short hold displaces at the raw `pitch_speed` rate — print the measured start angle), then release all inputs for 90 frames; assert the start angle was genuinely displaced (> 10°) and the signed angle between the nose (`-transform.basis.z`) and the velocity unit vector is < 3° at the end of the window. RED on the pre-fix tree: the velocity aligner (`velocity_align_rate`, `scripts/player.gd:66`; slerp at `:452-458`) bends the VELOCITY toward the frozen nose, so the nose-to-velocity angle does NOT literally hold — it decays toward its lift-softened equilibrium while the induced climb bleeds speed. Modelling that window (settled 17 m/s glide, +0.29 rad displacement, 90 frames) lands the end angle well above the 3° bar, so the scenario is still red-before/green-after — but MEASURE the pre-fix run and record both runs in this ticket, and if the measured pre-fix angle lands under 3°, stop and re-derive before changing code (the T-081 rule): the assertion's margin, not the mechanism, is the contract.
- [ ] `trim_glide_lands_clean` (`tests/sim_test.gd:589-610`) re-derived green with the coupling fix above, before/after arrival speeds recorded in this ticket.
- [ ] `stall_drops` and `stall_recovers` pass unchanged (the `not stalled` guard makes this structural), and `dive_gains_speed`, `hard_landing_skids`, `pullup_gains_height`, `banked_left_turn` pass with before/after margins recorded — all four contain hands-off or released-input frames that now trim toward the flow instead of freezing.
- [ ] Full Gate 1b suite exits 0 (110 `_check` sites on today's tree, audit era: 87 — the 0-failure run the audit recorded measured that 87-scenario tree, so the 0 on today's tree is this change-set's own run to produce).
- [ ] Final `trim_rate` and the landing-coupling decision (which knob moved, to what value) recorded in this ticket.
- [ ] Gate 2 autoplay passes (`ok=true restart=true`).
- [ ] (Gate 3, human) Releasing W/S mid-glide settles the nose onto the flight path within about 1–2 s — a hands-off glide keeps flying toward its aim instead of holding a frozen deck angle — and slow-speed handling does not feel rubber-banded.

## Verification

Gate 1 (`--import` + `--quit-after 120` boot — both exit 0, no ERROR lines; **no
`--check-only` leg**: that mode never starts the project, so the `Sfx` autoload
referenced at `scripts/player.gd:321` (also `poop.gd:77`) never resolves and the
compile fails identically on the pristine tree — measured exit 1, 4 ERROR lines
during the 2026-09-30 audit and re-measured unchanged on 2026-10-01, documented
broken repo-wide at `VERIFICATION.md:385-390`; the import + boot legs exercise
the script) + Gate 1b (`hands_off_glide_trims` shown red-before/green-after;
full suite exit 0 with the named re-runs) + Gate 2 (`godot --path .
res://tests/autoplay.tscn`, `ok=true restart=true`) + Gate 3 (the new human line
above). Add the `hands_off_glide_trims` row to the VERIFICATION.md Gate 1b table
and the Gate 3 checklist line in the same change-set.

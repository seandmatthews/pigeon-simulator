# T-106 — Kill the post-loop roll cant: drive the bank controller and leveler from measured roll

- **Milestone:** Sweep backlog · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-082, T-083 (both landed — the released-pitch trim this ticket makes roll-free by construction, and the pitch-attitude falloff that shapes the loop entry the repro flies through)
- **Refs:** `scripts/player.gd` — bookkept `_roll` decl `:160`, `bank_angle` getter `:139-140`, `reset_flight` clear `:173`, `_steer` bank block `:413-425` (target `:419`, bookkept chase `:420-422`, yaw term `:423-425`), the measured-pitch precedent `:436`, input pitch term `:441`, T-082 trim block `:452-456`, `_level_attitude` `:312-320` (call sites `:226` air/skid floor frames, `:307` waddle), T-023 nudge target feed `:419` + `_home_nudge_bank` `:472-485`, stall nose drop `:494-495`, body-up flap dir `:379-380` · sole `bank_angle` consumer: `scripts/chase_camera.gd:121` · measured-wing precedent: `tests/sim_test.gd:461` (`banked_left_turn` reads `basis.x.y`) · harness helpers: `_set_up` `tests/sim_test.gd:266`, `_hold` `:273`, `_tap` `:279`, `_pitch_until` `:288`, `_await_grounded` `:301` · settled-cruise recipe: `flap_speed_envelope` leg 2, `tests/sim_test.gd:362-363` · boost is a declared-but-unconsumed action: `project.godot:67-71`, no script reads it (grepped this session), documented not implemented at `VERIFICATION.md:250` · suite size today (counted this session): 129 `_check` call sites across 100 `func _scenario` definitions (`grep -c "_check(" tests/sim_test.gd` = 130 incl. the `:251` definition; `grep -c "func _scenario" tests/sim_test.gd` = 100) · no research phase ran (owner-reported flight bug, no real-world analogue); no reference images exist for this ticket

## What

Three defects, one root cause. The flight model keeps its roll in a bookkept float (`_roll`, `scripts/player.gd:160`) that only the bank controller's own writes and `reset_flight` ever touch — while other code paths rotate the body basis without reporting into it:

1. **The T-082 trim leaks roll.** The hands-off trim (`scripts/player.gd:452-456`) rotates the whole basis by `Basis(Quaternion(nose, target))` — Godot's shortest-arc rotation from nose to flow. Its comment claims "no roll component — the trim never fights the bank", and that is only true while the nose sits comfortably below vertical: the rotation axis is `nose × flow`, and once the nose passes vertical the axis tilts toward the body's forward axis, so the "pitch" correction physically ROLLS the bird — and `_roll` never hears about it.
2. **The bank controller trusts the book.** `_steer` commands `move_toward(_roll, target_roll, …)` and applies `new_roll − _roll` around the body's BACK axis (`scripts/player.gd:420-421`). With `_roll` bookkept at 0 while the body truly hangs canted, input toward the cant reads sluggish (the visible change is only the input delta from a wrong zero) and input away from it doubles — roll feels one-way. The pure body-pitch terms (input `:441`, stall drop `:495`) also shift the body's true roll relation at large pitch, widening the book-vs-truth gap every maneuver.
3. **The leveler levels the book, not the bird.** `_level_attitude` (`scripts/player.gd:312-320`) eases the TRACKED variable to 0 (`move_toward(_roll, 0.0, …)`) and applies the delta: once the book says 0 it applies exactly zero correction, so whatever true cant the flight leaked survives the landing — the pigeon stands canted on the pavement.

This mirrors how pitch was already fixed: pitch is MEASURED off the basis every frame (`asin((-basis.z).y)`, `scripts/player.gd:436`) and no pitch bookkeeping exists — T-083's falloff is built on that read. Do the same for roll.

**Fix 1 — measure roll, delete the book.**

```gdscript
## Bank measured off the body basis (the yaw-pitch-roll roll): atan2(right.y, up.y).
## 0 for an upright bird, signed left-positive exactly like the input term —
## turn_left drives target_roll positive and lifts the right wing, the same sign
## `banked_left_turn` already asserts (basis.x.y > 0, tests/sim_test.gd:461).
func _measured_roll() -> float:
	return atan2(transform.basis.x.y, transform.basis.y.y)
```

In `_steer`, replace every `_roll` with the measurement:

```gdscript
var roll := _measured_roll()
var target_roll := clampf(turn_input * max_bank + _home_nudge_bank(), -max_bank, max_bank)
var new_roll := move_toward(roll, target_roll, bank_rate * authority * delta)
rotate_object_local(Vector3.BACK, new_roll - roll)
if absf(new_roll) > 0.01:
	rotate_y((new_roll / max_bank) * full_bank_yaw_rate * authority * delta)
```

and point the `bank_angle` getter (`scripts/player.gd:139-140`) at `_measured_roll()`. The chase camera is its only consumer (`scripts/chase_camera.gd:121`) — intended visible change: the camera now follows the true cant during any transient instead of the book. Delete `_roll` (`:160`) and its `reset_flight` clear (`:173` — that function's `rotation = Vector3(0, yaw, 0)` already rebuilds the true basis clean). Behavioral consequence to WANT: a bird flying with leaked cant is now actively driven back inside the ±`max_bank_deg` envelope at the normal `bank_rate` hands-off, because `target_roll` is 0 with no input — the cant becomes a transient instead of a state. (Hands-off roll-centering itself is pre-existing behavior, not new; measurement only makes it bite on truth.)

Near the measurement's pole: `atan2(right.y, up.y)` degenerates as the nose approaches vertical (both y-components → 0; Godot's `atan2(0, 0)` is 0, not NaN). T-083's falloff asymptotes input flight just under 85°, so the pole is transient in real flight; if the scenario traces show roll jitter while |pitch| > ~80°, gate the correction toward zero across a band shaped like T-083's (`pitch_auth_full_deg`/`pitch_auth_zero_deg` pattern, `scripts/player.gd:75-76`). Decide from the measured traces and record the choice — default is no gating.

**Fix 2 — make the T-082 trim roll-free by construction.** Replace the free shortest-arc quaternion with a decomposition whose axes are world-up (heading) and the body's right axis (nose error) — the only rotations that never apply an untracked roll:

```gdscript
if not stalled and absf(pitch_input) < 0.01 and velocity.length() > stall_speed:
	var nose := -transform.basis.z
	var flow := velocity.normalized()
	var d := nose.dot(flow)
	if absf(d) < 0.999:  # near-parallel needs no rotation; ANTIparallel is the degenerate 180° slerp — refuse to steer it
		var target := nose.slerp(flow, clampf(trim_rate * authority * delta, 0.0, 1.0)).normalized()
		var flat_nose := nose; flat_nose.y = 0.0
		var flat_target := target; flat_target.y = 0.0
		if flat_nose.length_squared() > 0.000001 and flat_target.length_squared() > 0.000001:
			var heading := flat_nose.normalized().signed_angle_to(flat_target.normalized(), Vector3.UP)
			transform.basis = Basis(Vector3.UP, heading) * transform.basis
		var pitch_step := asin(clampf(target.y, -1.0, 1.0)) - asin(clampf(nose.y, -1.0, 1.0))
		rotate_object_local(Vector3.RIGHT, pitch_step)
```

Guards: the existing three (`not stalled`, released input, `velocity.length() > stall_speed`) are untouched in shape and values. `absf(d) < 0.999` is the new antipodal guard: at nose ≈ ±flow both `Quaternion(nose, target)` and `slerp` pick an arbitrary perpendicular axis — near-parallel it is a no-op being skipped exactly, antiparallel it is a 180° flip the trim must never command (a nose dead-opposite its flow is the stall machinery's state anyway, and the speed guard makes reaching it rare). The flat guards skip the heading term when nose or target is within ~0.1° of vertical (normalizing a near-zero flat would NaN). The heading rotation is an explicit world-up pre-multiplication — it leaves every basis column's y-component, hence pitch AND measured roll, exactly unchanged; `rotate_object_local(RIGHT, …)` leaves the right column untouched. The decomposition is not perfectly commutative at large pitch (the body-right pitch step shifts measured roll a little when up is far from vertical), but unlike today that residual is MEASURED — Fix 1's controller closes the loop on it the very next frame. That is the guarantee this ticket sells: no rotation path applies a roll component nobody tracks. Keep `trim_rate` at its landed 0.7 and the `authority` scaling; the existing yaw term's `rotate_y` (`:425`) is NOT touched — its frame and behavior are pinned by `banked_left_turn`.

**Fix 3 — hard-level the basis on ground contact, keeping yaw.** Replace `_level_attitude`'s bookkept easing with a reconstruction to upright at the measured heading:

```gdscript
func _level_attitude(delta: float) -> void:
	var fwd := -transform.basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	if flat.length_squared() > 0.000001:  # a vertical nose cannot stand on a floor; guard the skid anyway
		var yaw := atan2(-flat.x, -flat.z)  # Basis(UP, yaw).z == (sin yaw, 0, cos yaw) == -fwd_flat
		var level := Basis(Vector3.UP, yaw)
		transform.basis = transform.basis.slerp(level, clampf(ground_level_rate * delta, 0.0, 1.0)).orthonormalized()
```

The weight reproduces the old easing scale (`ground_level_rate` 6.0 ≈ 0.1 per 60 Hz frame, matching the old `step` clamp), so the waddle keeps its smooth right-up rather than a snap — but the terminal state is now EXACTLY upright: measured roll and pitch 0, yaw whatever the waddle turn (`:296`) left. Both call sites (`:226` air/skid floor frames, `:307` waddle) get this for free. `Basis.slerp` needs orthonormal inputs — the player basis only ever receives rotations — and the trailing `.orthonormalized()` re-pins the basis against accumulated float drift (an unstated cant source until now). If `Basis.slerp` misbehaves on any Godot 4.7 edge, the equivalent `Quaternion(transform.basis).slerp(Quaternion(level), w)` is acceptable; the acceptance is behavioral.

**The loop repro's input mapping.** The owner's repro says "hold pitch-up + boost until the bird goes over the top". `boost` is declared in the input map (`project.godot:67-71`) but NO script reads it — `VERIFICATION.md:250` documents it not implemented, and adding it is not this ticket. The repo's only thrust source is the paced flap. The repro here is hold `pitch_up` (W) with paced flap taps (Space, spaced ≥ 21 frames so flaps land near fully rested) until the nose sweeps past vertical: the flap's body-up impulse (`scripts/player.gd:379-380`) is what pushes the flow past vertical while the T-083 fade asymptotes the input-pitched nose just under 85°, and the RELEASED trim then slerps the nose after the flow — over the top, through exactly the geometry where its shortest arc rolls the bird. That is the leak's natural history, and it is why the fix attacks both ends: measurement closes the loop on whatever leaks, and the decomposition removes the injector.

**Envelope of the change:** `max_bank_deg` 40, `bank_rate` 3.5, `full_bank_yaw_rate` 1.5, `ground_level_rate` 6.0, `trim_rate` 0.7, T-023's nudge exports, T-083's fade band, the stall machinery and T-081's align grading all keep their landed values — this ticket changes what the controllers LISTEN to, not the envelope. The nudge rides the same `target_roll` clamp unchanged (`:419`).

What this does **not** claim: no new flight behavior — no air auto-level beyond the pre-existing hands-off roll-centering (input 0 → target 0, today and after); no boost implementation; no pitch-model change (T-083's falloff values untouched); T-082's trim CONTRACT is preserved, not retuned — `hands_off_glide_trims`' landed bars (start > 10°, travel ≥ 2.5°, end ≤ 7.0°) must stay green as-is; no camera work beyond `bank_angle`'s source swap; and no claim that the bookkept variable was the only drift source — the `.orthonormalized()` pin in Fix 3 exists precisely because the basis could also drift.

**Watch-list** (from the T-082 precedent — adjacent changes to this machinery flipped neighbors): this change-set re-runs and records before/after margins for `banked_left_turn`, `hands_off_glide_trims`, `pitch_attitude_bounded`, `pullup_gains_height`, `trim_glide_lands_clean`, `hard_landing_skids`, `waddles_on_ground`, `edge_nudge_turns_home`, `stall_drops`, `stall_recovers`. If any flips, either the change-set regressed (fix the code) or the scenario's bar encoded the bookkept behavior (re-derive from measurement, never weaken silently) — and record which in this ticket.

## Why

Owner intent (2026-10-02): "after a loop (hold pitch-up + boost until the bird goes over the top) the pigeon can get stuck canted to one side — roll input only works one way — and the cant persists even on the ground." Pillar 1 is "flight is the toy" (`docs/DESIGN.md` → Pillars): a cant the controls cannot fully reverse poisons every post-loop minute of it, and a pigeon standing skewed on the plaza makes the landing — the beat the whole eat/score rhythm depends on — read as broken. The player value is that a loop becomes a maneuver you fly and recover from, not a trap that keeps charging you for it.

The root cause is bookkeeping-as-truth: `_roll` models the bank but is not the bank (mechanism and line refs in What ¶1-3). The fix class is the one this codebase already chose for pitch — measure the state off the body basis (`scripts/player.gd:436`) and let every controller close its loop on truth — plus one structural change: the single free-quaternion rotator (the T-082 trim) decomposes into axes that cannot inject untracked roll at all. No real-world analogue applies; every criterion below is concrete from this repo alone.

## Acceptance criteria

- [ ] **New Gate 1b scenario `loop_over_top_roll_recovers` in `tests/sim_test.gd`** — the only criterion that can prove the loop repro dead. Recipe: settled cruise start (`_set_up(true, Vector3(0, 25, 0), Vector3(0, 0, -17))` + ~30 settle frames, the `flap_speed_envelope` leg-2 recipe at `tests/sim_test.gd:362-363`); seed the asymmetry a real loop entry has with a short `turn_left` hold (~15 frames), then record `entry_fwd := -_player.transform.basis.z` and hold the loop — `Input.action_press("pitch_up")` held directly (the `_hold` helper cannot overlap the flap cadence) with paced `_tap("flap")` every ≥ 21 frames — until the bird demonstrably goes OVER THE TOP: `(-_player.transform.basis.z).dot(entry_fwd) < 0.0` (the nose has swept past vertical onto the far side; bank-tolerant and unambiguous where the pitch sine is not — sine 0.99 is both 81.9° and 98.1°), with a sanity arm that nose.y exceeded +0.9 somewhere in the hold, inside a ~600-frame budget. **The precondition must be asserted, never skipped**: a repro that cannot reach vertical is a different bug and must FAIL loudly, not pass vacuously. Then release ALL input for ~120 frames and assert |measured roll| (`rad_to_deg(atan2(basis.x.y, basis.y.y))`) ≤ 5° at window end (the closed loop converges hands-off at `bank_rate` 3.5 rad/s; the owner's weaker "inside the bank envelope" bar is implied) and non-increasing across the last 60 frames. RED before / GREEN after on the final assertion text; record both runs' numbers in this ticket. If the measured pre-fix end-roll already sits inside the bar, STOP and re-derive before changing code (the T-082 rule): the assertion's margin, not the mechanism, is the contract.
- [ ] **Ground leg in the same scenario:** let the post-release bird descend and settle (`_await_grounded`, `tests/sim_test.gd:301`), wait 60 grounded frames, assert it STANDS LEVEL — |measured roll| ≤ 2° — and that yaw SURVIVED the leveling: heading change from touchdown to the read ≤ 2° (pins Fix 3's "keeping yaw" contract so a later refactor cannot turn the leveler into a snap-to-north). Record pre-fix numbers; the pre-fix tree is expected to fail the level arm exactly when the scenario entered it canted.
- [ ] `banked_left_turn` re-derived green with before/after margins (its `basis.x.y` read at `tests/sim_test.gd:461` is the same measurement this ticket productionizes).
- [ ] `hands_off_glide_trims` stays green at T-082's landed contract (start > 10°, nose travel ≥ 2.5°, end |signed angle| ≤ 7.0°) with before/after numbers recorded — the trim rewrite must preserve the re-derived trim behavior, not retune it.
- [ ] Watch-list green with before/after margins recorded: `pitch_attitude_bounded`, `pullup_gains_height`, `trim_glide_lands_clean`, `hard_landing_skids`, `waddles_on_ground`, `edge_nudge_turns_home`, `stall_drops`, `stall_recovers`.
- [ ] Full Gate 1b suite exit 0 (129 `_check` call sites on today's tree — the change-set's own run to produce, plus the new scenario's sites).
- [ ] Any knob measurement forces moved (e.g., the near-pole gating band from Fix 1's escape hatch) recorded in this ticket with its sweep table; the default is NO knob moves.
- [ ] (Gate 3, human) Fly a loop — pitch-up held through the top — and confirm roll input pushes the roll BOTH ways with equal authority afterward, no persistent cant remains in straight flight, and the chase camera reads the recovery.
- [ ] (Gate 3, human) Land after aggressive maneuvering and confirm the bird stands square on the pavement — no skew — through the waddle.

## Verification (gates)

Gate 1: `godot --headless --path . --import` then `godot --headless --path . --quit-after 120` — both exit 0, no ERROR / SCRIPT ERROR lines · Gate 1b: `godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` — exit 0; `loop_over_top_roll_recovers` shown red-before/green-after on the final assertion text with both runs recorded in this ticket; the watch-list scenarios with before/after margins · Gate 2: `godot --path . res://tests/autoplay.tscn` — exit 0, `AUTOPLAY DONE ok=true … restart=true`, no SCRIPT ERROR · Gate 3: the two human lines above. In the same change-set: add the `loop_over_top_roll_recovers` row to VERIFICATION.md's Gate 1b scenario table and the two Gate 3 playtest lines. One commit, ticket ID in the message, e.g. `fix(flight-control): kill the post-loop roll cant — measured roll everywhere (T-106)`.

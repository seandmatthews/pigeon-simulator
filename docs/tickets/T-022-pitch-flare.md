# T-022 — Give pitch-up a real flare near the ground instead of a balloon

- **Milestone:** Sweep backlog · **Status:** done · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
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

- [x] Holding pitch-up low sheds speed into a nose-high sink instead of a
      balloon: from a settled ~15 m/s glide at ~6 m, 45 frames (0.75 s) of
      held pitch-up gains < 2.5 m of height AND ends below 11 m/s — today's
      tree balloons ~+10 m on the same input (Gate 1b:
      `flare_sheds_speed_low`, expressible with `_set_up(true, Vector3(0, 6,
      0), Vector3(0, 0, -15))` + `_hold("pitch_up", 45)`,
      `tests/sim_test.gd:167-177`)
- [x] Diving for speed is untouched: the flare never fires in or above the
      sink band's edge (Gate 1b: `dive_gains_speed` and `pullup_gains_height`
      stay green)
- [x] Stall behavior is untouched (Gate 1b: `stall_drops`,
      `stall_recovers` stay green)
- [x] Banked cruise is untouched (Gate 1b: `banked_left_turn` stays green)
- [ ] [screenshot] The flare reads as a nose-high brake-sink near the ground,
      and a speed approach to a bench/roof is controllable through touchdown
      *(pending human playtest — Gate 3 lines added to VERIFICATION.md; see
      the landed note below for what to judge)*

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

## Landed (flight-control-s2, 2026-09-30)

Flare shipped in `_apply_flight_forces` (`scripts/player.gd`), ticket-sketch
faithful: new "Flare" export group (`flare_drag`, `flare_max_sink`); while
pitch input is held and the pigeon is airborne in the descending band
`-flare_max_sink < velocity.y < 0`, the **horizontal** velocity takes
`*= 1.0 - flare_drag * pitch_input * delta`. The predicate correction was
followed as written: climbs and level flight sit above the band (no
mid-flight airbrake), dives below the −8 m/s edge keep the speed tool, and a
`not grounded` gate leaves the skid's own friction alone.

**Tuned values:** `flare_drag` **0.8** (top of the licensed 0.5–0.8 range),
band edges **−8 / 0 m/s**. 0.6 also passed both bars but left thinner margins
(+2.07 m / 10.61 m/s, still climbing +6.6 m/s at release); 0.8 measures
**+1.85 m / 10.15 m/s** with the least residual climb. The optional
`min_control_authority` 0.35 → 0.5 relaxation was **dropped** — the flare's
own bleed yields landable speeds without widening the change to all
low-speed handling.

**Gates run:** Gate 1b — `flare_sheds_speed_low` FAILS before the change
(settled 14.54 m/s, +2.60 m, 11.66 m/s) and PASSES after; full suite 82/82
PASS, exit 0, with `dive_gains_speed`, `pullup_gains_height`, `stall_drops`,
`stall_recovers`, `banked_left_turn`, `landing_slides_to_stop` explicitly
re-run green; a 1.2 over-drive probe also leaves every neighbor green, so 0.8
has real headroom. Gate 1 — the first gate round failed `--import` and the
boot in this worktree because the per-machine `addons/godot_mcp/` directory
(deliberately untracked: `.gitignore` calls it per-machine tooling and
requires every checkout to keep it on disk for the `MCPRuntimeProbe`
autoload) was missing, so Godot could not create the autoload. The directory
was restored on disk from the main checkout (untracked, policy-conformant,
zero tracked changes) after which `--import` and the 120-frame boot exit 0 —
boot with zero ERROR lines; import with only the benign core shutdown line
`ERROR: 33 resources still in use at exit`, which a throwaway clone of this
branch with the addon restored reproduces identically on cold and warm cache
(the enabled editor plugin's GDScripts release after Godot's leak check —
inherent to the canonical setup, recorded in VERIFICATION.md's known
issues). `--check-only --script res://scripts/player.gd` fails **identically
on the pristine tree** (check-only never loads autoloads, so `Sfx` doesn't
resolve) — pre-existing, also in VERIFICATION.md's known issues. Gate 2 —
`AUTOPLAY DONE ok=true`, `restart=true`, no SCRIPT ERROR.

**Note for the Gate 3 tester:** at the 45-frame mark the pigeon may still be
climbing gently (~+6 m/s vy at release) — the flare can only act while
descending (the ticket's own predicate correction), so the read to judge is
"brakes hard and stops ballooning" (baseline +2.60 m over the same window,
+10 m over a longer hold), not "never rises at all".

# T-084 — Adopt T-041: pitch-up near the ground becomes a brake-sink, not a balloon

- **Milestone:** Sweep 2 · **Status:** proposed · **Category:** flight-control · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** — (adopts [T-041](T-041-flare-brake-sink.md) — mark it done/superseded when this lands; its T-022 lineage carries over. Re-based to today's tree: T-041's line numbers predate the T-036 merge)
- **Refs:** `scripts/player.gd` `_apply_flight_forces` `:378-407` — velocity-align exchange `:400-403`, `max_speed` clamp `:404`, stall flag `:380`; T-041 cited `:348-377`/`:374` on the older tree, and its `min_control_authority` cite is now `:50` (clamp `:364`) · sweep-2 brake trace `.captures/session_flcs2s2-b/state.jsonl` (re-verified this session) · T-041's recorded flcs2-c trace (that capture no longer exists in either tree; numbers as recorded in the ticket) · untouched-tree baseline `.captures/sim_baseline_flcs2s2_tickets.txt` (81 SIM PASS / 0 FAIL / exit 0, this session, worktree @ ee84292)

## What

Ship T-041's flare term as written: extra drag on the **horizontal** velocity only while the pilot holds pitch-up during a shallow descent, so approach speed sheds into a nose-high sink instead of converting into climb.

In `_apply_flight_forces` (`scripts/player.gd:378-407`), placed **after** the velocity-align exchange (`:400-403`) and **before** the `max_speed` clamp (`:404`) — the slot matters: it bleeds speed the align would otherwise re-redirect into climb, and the clamp must still cap the result:

```gdscript
@export_group("Flare") ## (T-041/T-084) Pitch-up brake during a shallow descent.
@export var flare_drag: float = 0.6 ## 1/s of extra horizontal drag at full pitch-up input. Tune 0.5–0.8.
@export var flare_max_sink: float = 8.0 ## m/s, the lower edge of the descending band; steeper sinks are dives and stay untouched.

# in _apply_flight_forces, after the align exchange, before the clamp:
var pitch_input := Input.get_axis("pitch_down", "pitch_up") ## read locally — this function reads no input today
if pitch_input > 0.0 and not grounded and not stalled \
		and velocity.y < 0.0 and velocity.y > -flare_max_sink:
	var keep := 1.0 - flare_drag * pitch_input * delta
	velocity.x *= keep
	velocity.z *= keep
```

Fires only when **all** of these hold: `pitch_input > 0`, not grounded, not stalled (the `:380` flag), descending inside the 0…−8 m/s band. ~4–6 lines plus the two exports.

What this does **not** claim: the flare is not a mid-flight airbrake (it only fires while descending in band); it never fires in dives (band lower edge), stalls (`not stalled` — the stall path keeps its own nose-drop and flap recovery), skids or waddles (`not grounded`); it does not touch the flap/lift/velocity-align energy exchange, pacing, cooldown, audio or juice.

**Optional, explicitly droppable (not an acceptance criterion):** relax `min_control_authority` 0.35 → 0.5 (`:50`; the authority clamp sits at `:364`) only if the flared approach still reads mushy in Gate 3 — it widens the change to all low-speed handling. Record the decision either way.

## Why

The only way to shed approach speed today is pitch-up, and it converts **all** of it into climb — landing approaches have no brake, only orbit-bleeding at altitude or hot skids. Verified brake trace, `.captures/session_flcs2s2-b/state.jsonl` (re-verified this session): from a ~27.8 m/s approach at y 13 (f1129: vy −10.95, pitch −0.33), a held pitch-up ballooned the pigeon to apex y 39.56 at f1301 — **+26.2 m** — arriving stalled at the top. T-041's own recorded trace (flcs2-c; the capture has since been deleted, numbers as recorded in that ticket) shows the same shape at approach speeds: one hold from an 18.7 m/s glide bought +13.25 m and ended stalled almost pure vertical. The planning session's roof approach likewise overshot its 46.6 m aim by a wide margin — the longest airborne path I measured in `.captures/session_flcs2s2-c/` is ≈ 121 m (f6344–f6744); the plan-of-record's earlier "~146 m" figure did not reproduce and is retracted here.

Risk inherited from T-041, stated plainly: `pullup_gains_height` (`tests/sim_test.gd:331`) holds pitch_up while the dive path transits the −8…0 sink band, so the flare will fire briefly there. If its margin erodes, narrow the band (e.g. `flare_max_sink` 4) or trim `flare_drag` — a tuning decision to make with the scenario numbers in hand, not a redesign.

## Acceptance criteria

- [ ] New Gate 1b scenario `flare_sheds_speed_low` in `tests/sim_test.gd`: `_set_up(true, Vector3(0, 6, 0), Vector3(0, 0, -15))` + `_hold("pitch_up", 45)` (helpers at `tests/sim_test.gd:176-186`); assert Δy < 2.5 m and end speed < 11 m/s. Fails on today's tree (the balloon above) — demonstrated red-before/green-after inside this change-set, both runs recorded in this ticket.
- [ ] Diving for speed is untouched: `dive_gains_speed` and `pullup_gains_height` stay green (narrow the band or trim `flare_drag` if their margins erode — record the final edges).
- [ ] Stall behavior is untouched: `stall_drops` and `stall_recovers` stay green (the `not stalled` guard makes this structural, not incidental).
- [ ] Banked cruise and ground handling are untouched: `banked_left_turn`, `waddles_on_ground`, `landing_slides_to_stop` stay green (the `not grounded` guard).
- [ ] Final `flare_drag`, the band edges, and the `min_control_authority` decision recorded in this ticket, against the recorded untouched-tree baseline (81/81, exit 0, this session).
- [ ] [screenshot] (Gate 3) The flare reads as a nose-high brake-sink near the ground, and a speed approach to a bench/roof is controllable through touchdown.

## Verification

Gate 1 (`--import`, `--quit-after 120`, `--check-only --script res://scripts/player.gd` — all exit 0, no ERROR lines) + Gate 1b full suite exit 0 with the named re-runs, `flare_sheds_speed_low` shown red-before/green-after + Gate 2 (`godot --path . res://tests/autoplay.tscn`, `ok=true restart=true`) + Gate 3 (the screenshot line above; human lines: does holding up near the ground read as braking into a sink rather than ballooning; is the approach to a bench controllable at flare speeds). Add the `flare_sheds_speed_low` row to the VERIFICATION.md Gate 1b table and the Gate 3 checklist line in the same change-set.

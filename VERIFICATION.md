# VERIFICATION.md

How we prove the game still works. A change is **done** only when the gates below pass
for whatever you touched *and* nothing else regressed.

**Godot binary:** `~/bin/Godot_v4.7.2-stable_win64_console.exe` (use this variant in
terminals — it prints output properly). Commands below say `godot` as shorthand;
substitute the full path if it's not on your PATH.

## Gate 1 — Headless smoke tests (run after every change, takes seconds)

From the repo root:

```bash
# 1. Reimport all resources — must exit 0, no ERROR / SCRIPT ERROR lines
godot --headless --path . --import

# 2. Boot the main scene for 120 frames — must exit on its own, no errors
godot --headless --path . --quit-after 120

# 3. (When touching a single script) syntax check
godot --headless --path . --check-only --script res://scripts/player.gd
```

**Pass =** all commands exit 0 and output contains no `ERROR`, `SCRIPT ERROR` or
`Parse Error` lines. Warnings are acceptable but worth cleaning up.

## Gate 1b — Sim harness (automated behavior checks, run after every change)

```bash
godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
```

Prints one `SIM PASS/FAIL <name>` line per scenario; **pass = exit 0**. Deterministic
(fixed timestep, synthetic input), so a failure is always a real regression, never
flakiness. Set `SIM_DEBUG=1` for trajectory traces. The scenario table grows as
tickets land — every feature that can be machine-checked gets a scenario here:

| Scenario | Proves | Ticket |
| -------- | ------ | ------ |
| takeoff_3_flaps | 3 paced flaps from the ground reach climbing flight | T-001 |
| lift_softens_gravity | level glide at 12 m/s sinks gently (< 6 m in 1.5 s) | T-001 |
| dive_gains_speed | a dive to −60° converts height into speed | T-001 |
| pullup_gains_height | pulling out of a dive climbs above the pull-start altitude while speed bleeds | T-001 |
| banked_left_turn | a held turn banks the body and yaws with the bank | T-001 |
| stall_drops | stalling sinks far harder than gliding and the nose drops | T-001 |
| stall_recovers | a flap restores flying speed out of a stall | T-001 |
| landing_slides_to_stop | a low touchdown slides to a stop — no bounce, no NaNs | T-001 |
| camera_follows_yaw | the rig swings around behind a turning pigeon | T-002 |
| camera_fov_kick | FOV widens measurably with speed | T-002 |
| camera_tucks_in_grounded | arm shortens while grounded | T-002 |

## Gate 2 — Autoplay smoke test (run before marking any gameplay ticket done)

Boots the **real** game (`scenes/main.tscn`) in a window and plays it with a
scripted pilot for 30 s: flap-climb, bank, dive pulse, pull-up, glide, poop taps,
with reflexes to pull up near the ground and steer home when drifting. Saves a
screenshot every 5 s to `.godot/autoplay/`:

```bash
godot --path . res://tests/autoplay.tscn
```

**Pass =** exit 0, output contains `AUTOPLAY DONE ok=true`, and no `SCRIPT ERROR`
lines. A game window appears on the desktop for ~35 s — that is the game being
played; the screenshots are the evidence.

Then confirm in a normal editor run (F5):

- [ ] Boots straight into the playable scene; Debugger → Errors tab is empty
- [ ] No warning spam on boot or during ~30 s of play

## Gate 3 — Manual playtest (run the full list before closing any ticket)

Keep this table in sync with `project.godot` and `README.md`:

| Input | Action |
| ----- | ------ |
| W / S | pitch up / down |
| A / D | turn left / right |
| Space | flap |
| F | poop *(not implemented — T-006)* |
| Shift | boost *(not implemented)* |
| Esc | pause *(not implemented — T-010)* |

Playtest checklist (grows as tickets land):

- [ ] Pigeon falls under gravity, flaps with Space, steers with A/D and W/S
- [ ] (T-001) Paced flaps climb and sustain altitude; mashed flaps are noticeably weaker
- [ ] (T-001) Dive → pull-up visibly trades height for speed and back
- [ ] (T-001) Turns bank and feel weighty; stall drop and recovery read clearly
- [ ] (T-001) Landings at low speed slide to a stop without bouncing
- [ ] (T-002) Camera never clips ground or buildings when landing or hugging walls
- [ ] (T-002) No visible jitter during fast turns and dives; FOV kick noticeable but not nauseating
- [ ] (T-002) The pigeon never leaves the frame at max speed
- [ ] Pigeon lands on the ground and does not fall through the world
- [ ] HUD hunger ticks down over time
- [ ] Camera does not clip through the ground while landing
- [ ] Closing and restarting the game produces no errors

## Known issues

- Flight model v1 is machine-verified (Gate 1b, 8/8) only — a human feel/tuning pass
  over the T-001 playtest lines is still pending.
- Placeholder art everywhere: the pigeon is a gray sphere, the city is a green plane
  (tracked in T-004 and T-011).

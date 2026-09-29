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
| waddles_on_ground | a gentle drop settles grounded and W walks forward at waddle pace | T-003 |
| waddle_turns | A/D turn the pigeon in place while grounded | T-003 |
| flap_takes_off_ground | a grounded flap returns to climbing flight | T-003 |
| roof_landing | a raised roof is landable — the pigeon settles grounded on top | T-003 |
| roof_takeoff | flapping off a roof works like off the pavement | T-003 |
| bench_landing | a thin bench seat is landable and walkable | T-003 |
| bench_takeoff | flapping off a bench returns to flight | T-003 |
| hard_landing_skids | a steep fast dive skids to a stop — no instant ground, no tunneling, no NaNs | T-003 |
| city_same_seed_deterministic | regenerating with the same seed reproduces the identical layout fingerprint | T-004 |
| city_new_seed_guarantees | a different seed still yields a clear spawn plaza, flyable street widths, capped roof heights and enough bread-capable surfaces | T-004 |
| city_regenerate_restores_layout | after regenerating a foreign seed, the default seed rebuilds the original city exactly | T-004 |
| city_plaza_spawn | a drop into the spawn plaza settles grounded on the pavement | T-004 |
| city_street_flyover | a flap-assisted flight crosses the whole city along a street without touching anything | T-004 |
| city_roof_landable | a generated building roof is landable and walkable | T-004 |
| city_roof_takeoff | flapping off a generated roof returns to flight | T-004 |
| city_sidewalk_walkable | the pigeon waddles up a curb from the road onto the sidewalk ring | T-004 |
| hunger_drain_flap_vs_glide | hunger ticks in flight — visibly faster while flapping than gliding, slowest resting grounded | T-005 |
| hunger_game_over_once | hunger empties, clamps at zero and fires game_over exactly once; eating restores a chunk but the latch holds | T-005 |
| crumb_eaten_grounded_only | flying over a crumb never feeds; a grounded pigeon waddling into it eats it and frees it | T-005 |
| crumbs_respawn | eaten crumbs are topped back up to the target count within one respawn interval | T-005 |
| poop_inherits_and_arcs | an airborne drop inherits the pigeon's velocity, keeps the horizontal lead and only ever falls | T-006 |
| poop_grounded_no_drop | F does nothing while grounded — droppings exist only in the air | T-006 |
| poop_cooldown_blocks_stream | mashing F yields one dropping; the next comes only after the cooldown elapses | T-006 |
| poop_splats_ground_and_fades | a floor hit fires splatted(target, impact_velocity), sticks an up-facing splat to the hit body and fades it away | T-006 |
| poop_splats_wall | a wall hit sticks a splat facing along the wall's horizontal normal | T-006 |
| poop_event_reaches_any_body | a plain body on the hit layers receives the hit duck-typed (on_splatted) with no player import anywhere in poop.gd | T-006 |
| tourists_walk_loose_groups | 18 tourists stroll their sidewalk loops at slab level, seeded in loose groups | T-007 |
| tourist_splat_panics_scores | a real lobbed splat panics its tourist (sprint + arms) and fires the splatted score event; a sideways hit makes the panic flee along the impact's horizontal mirror | T-007 |
| tourist_buzz_flinch | a slow pass through the buzz zone earns nothing; a fast one earns a flinch duck, never a panic | T-007 |
| tourists_recycle_around_player | moving the player recycles the same tourist nodes into the spawn band around the new position | T-007 |

## Gate 2 — Autoplay smoke test (run before marking any gameplay ticket done)

Boots the **real** game (`scenes/main.tscn`) in a window and plays it with a
scripted, city-aware pilot for 30 s: cruise above the skyline (every generated
roof stays under 18.3 m, the pilot's floor is 23 m), flap-climb, bank, a short
dive pulse that only starts high enough to stay over the roofs, pull-up, glide,
and airborne poop taps (T-006 — every 2 s in flight the pilot lobs a real
dropping; grounded taps are skipped; since T-007 it pulls the trigger early
whenever a strolling tourist lines up under the predicted impact point).
Below the cruise floor the pilot climbs
hard while circling the spawn plaza — the one spot the generator guarantees is
clear of buildings — and beyond 60 m from the plaza it steers home. From 11 s in
the pilot also makes a ground visit (T-003 + T-004): arc to the plaza, bleed
speed in a wide orbit, spiral down inside the building-free ring, touchdown,
waddle across the pavement, take-off. While landed it waddles toward the
nearest breadcrumb and pecks it up when it reaches one (T-005) — the DONE line
reports the hunger bar, how many crumbs were eaten, how many poop splats
landed, how many tourists are alive and how many took a splat (`panics`,
T-007). Saves a screenshot every 5 s to `.godot/autoplay/`:

```bash
godot --path . res://tests/autoplay.tscn
```

**Pass =** exit 0, output contains `AUTOPLAY DONE ok=true`, and no `SCRIPT ERROR`
lines. The `DONE` line also reports the average rendered fps over the run —
the T-004 60 fps criterion is measured with it. A game window appears on the
desktop for ~35 s — that is the game being played; the screenshots are the evidence.

Then confirm in a normal editor run (F5):

- [ ] Boots straight into the playable scene; Debugger → Errors tab is empty
- [ ] No warning spam on boot or during ~30 s of play

## Gate 3 — Manual playtest (run the full list before closing any ticket)

Keep this table in sync with `project.godot` and `README.md`:

| Input | Action |
| ----- | ------ |
| W / S | pitch up / down · waddle fwd / back while grounded |
| A / D | turn left / right · turn while waddling |
| Space | flap · takes off when grounded |
| F | poop — lobs a splat dropping while airborne (T-006) |
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
- [ ] (T-003) A gentle glide touchdown settles into the waddle and the HUD hint swaps to the grounded controls
- [ ] (T-003) Waddling is slow and comedic; A/D turns in place; Space takes off again
- [ ] (T-003) A steep fast dive into the pavement skids to a stop — no crash, no falling through the world
- [ ] (T-003) Landing and taking off on a roof and a bench works the same as on the pavement
- [ ] (T-004) The city reads as a street grid from the air — roads with lane marks, sidewalks, varied facades, flat roofs, benches/lamps/bins
- [ ] (T-004) Flying end-to-end along streets and between roofs never clips through a building
- [ ] (T-004) Roofs, sidewalks and the spawn plaza are landable and walkable in a normal run
- [ ] (T-004) Restarting the game twice regenerates the identical city
- [ ] (T-004) Flying across the whole city holds ~60 fps on the dev machine
- [ ] (T-005) The hunger bar ticks down while flying — visibly faster while flapping, slower while resting
- [ ] (T-005) Landing near crumbs and waddling into them pecks them up and restores a chunk of the bar
- [ ] (T-005) Flying low over crumbs does nothing — only grounded contact feeds
- [ ] (T-005) Hunger reaching zero shows the starved hint exactly once (full game-over screen arrives with T-010)
- [ ] (T-005) Eaten crumbs come back somewhere else within a few seconds
- [ ] (T-006) Tapping F in flight lobs a dropping that visibly inherits momentum and arcs down
- [ ] (T-006) Droppings splat on streets, walls and roofs, stick to the surface, and fade out after a few seconds
- [ ] (T-006) Mashing F while flying yields about one dropping per second — no stream
- [ ] (T-006) F does nothing while grounded — the dropping only exists in the air
- [ ] (T-007) 15–20 tourists stroll the sidewalks and plaza in loose groups and read as believable walkers
- [ ] (T-007) A direct splat panics its tourist — sprints away, arms up, red flush, fist shake — and Score ticks up
- [ ] (T-007) Manual skill run: splat at least 3 tourists and buzz 3 more; watch one full panic cycle (sprint, fist shake, stroll resumes) through to the tourist eventually recycling
- [ ] (T-007) A close fast flyby makes nearby tourists flinch (a quick duck) without full panic
- [ ] (T-007) At full density the framerate holds; tourists only ever appear/disappear well away from the camera
- [ ] Pigeon lands on the ground and does not fall through the world
- [ ] HUD hunger ticks down over time
- [ ] Camera does not clip through the ground while landing
- [ ] Closing and restarting the game produces no errors

## Known issues

- Flight model v1 is machine-verified (Gate 1b, 8/8) only — a human feel/tuning pass
  over the T-001 playtest lines is still pending.
- Land/waddle/take-off (T-003) is machine-verified (Gate 1b) and exercised by the
  autoplay ground visit; a human feel pass over the T-003 lines is still pending.
- City blockout (T-004) is machine-verified (Gate 1b layout/flyover/landing
  scenarios) and flown by the autoplay pilot; a human pass over the T-004 lines
  (city readability, restart determinism, full-city 60 fps flyover) is still pending.
- Bread & hunger (T-005) is machine-verified (Gate 1b drain/game-over/eating/
  respawn scenarios) and exercised by the autoplay ground visit; a human pass
  over the T-005 lines (playing until game over once, drain-timing fairness) is
  still pending.
- Poop mechanic (T-006) is machine-verified (Gate 1b lob/cooldown/splat/event
  scenarios) and exercised by the autoplay pilot's poop taps; a human pass over
  the T-006 lines (leading a moving target once real ones exist, splat look and
  fade timing) is still pending.
- Tourists (T-007) are machine-verified (Gate 1b walk/splat/buzz/recycle
  scenarios) and live in the autoplay city at full density; a human pass over
  the T-007 lines (walk believability, panic readability, splat-the-3-buzz-the-3
  manual run, pop-in visibility) is still pending.
- Placeholder art everywhere: the pigeon is a gray sphere and buildings are tinted
  boxes with a procedural window texture (pigeon look tracked in T-011).

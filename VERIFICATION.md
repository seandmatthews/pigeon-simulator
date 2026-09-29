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
| flap_speed_envelope | four paced flaps climb without pumping forward speed to the cap, and a flap at cruise buys climb, not throttle (fwd gain < 2 m/s at +1–2 frames, vy gain > 4) | T-015 |
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
| tourist_splat_panics_scores | a real lobbed splat panics its tourist (sprint + arms) and fires the splatted score event, scored end to end through the Game autoload (100, then the chain's ×2 → 300); a sideways hit makes the panic flee along the impact's horizontal mirror | T-007 |
| tourist_buzz_flinch | a slow pass through the buzz zone earns nothing; a fast one earns a flinch duck, never a panic | T-007 |
| tourists_recycle_around_player | moving the player recycles the same tourist nodes into the spawn band around the new position | T-007 |
| cars_traffic_loops_blocks | 20 traffic cars loop their block rings at lane speed — every car covers ground, the fleet rounds corners, no two cars ever overlap — while the parked fleet sits exactly where it was seeded | T-008 |
| car_splat_honk_and_continue | a parked car takes a real lobbed splat (honk + score event relayed, stays parked, 30 scored through the Game autoload; the synthetic traffic hit is the ×2 → 90) and a traffic car hit through the same duck-typed entry keeps driving its loop | T-008 |
| score_combo_style_values | the Game autoload pays DESIGN values (tourist 100 · car 30), the chain escalates ×1 → ×2 → ×3 across target kinds and resets on landing and on the 20 s window, and the +50% style bonus demands a release that is fast, low and fresh | T-009 |
| score_high_score_persists | beating the record writes user:// at once and a fresh Game loads it back | T-009 |
| score_popup_floats_and_fades | the world-space popup shows "+100 ×2" at the hit position, floats up, fades and cleans itself up | T-009 |
| pause_freezes_world | Esc-pausing through the real PauseMenu stops the flying pigeon dead mid-air and the hunger clock with it; resuming hands both back | T-010 |
| game_over_shows_score_screen | starving through the real main scene opens the score screen — score, high score, tourist/car breakdown — freezes the run dead and keeps Esc locked | T-010 |
| restart_resets_run | restart through Main.restart_run() zeroes score/breakdown, refills hunger, clears the game-over latch, regenerates the same-seed city and re-seeds every spawner with fresh nodes | T-010 |
| pigeon_air_poses_track_flight | wings out in a glide, a wing beat on every real flap impulse (and the beat ends), wings swept back in a dive — the pose mirrors the flight state | T-011 |
| pigeon_ground_poses_track_waddle | grounded settles into the folded stand, waddling flips to the waddle pose, stopping settles back to stand | T-011 |
| pigeon_pecks_when_eating | eating a crumb through Main's exact wiring (crumb.eaten → Player.peck) plays the peck — the beak dives down and the overlay ends | T-011 |
| pigeon_silhouette_contrast | the bird's body is ≥ 0.20 Euclidean RGB from the sidewalk and the cream facade family, darker than every district backdrop's mean luminance by ≥ 0.05, with wingtips ≥ 0.15 darker and the head lighter (the 12-color sweep prints informationally) | T-016 |
| city_district_palettes_distinct | every building wears a color from its own district's palette, all four districts appear, the palettes are measurably distinct and the quadrant mapping is pure | T-013 |
| juice_splat_burst_fires | a real lobbed splat spawns a one-shot droplet burst at the hit point on the hit body, and it cleans itself up | T-013 |
| juice_feather_poofs_on_hard_flap | a fully-rested flap poofs feathers; a re-flap inside the throttle window doesn't spam another | T-013 |
| juice_dust_puff_on_landing | a gentle glide touchdown kicks a dust puff at the feet, which cleans itself up | T-013 |
| juice_landing_shake_decays | a touchdown kicks a small camera shake (never full trauma) that moves the lens and decays to dead still | T-013 |
| hit_shake_and_score_pulse | through the real main scene, a combo escalation shakes the chase camera, pulses the HUD score line and shows the ×2 — both settle back; the sun is warm and capped at ≤ 1.15 energy | T-013 |
| audio_buses_and_assets | the Master/SFX/Ambience bus mix exists with the ambience bus quieter than SFX, every ticketed sound loads as a real stream, and both ambience beds are flagged to loop forever | T-012 |
| sfx_flap_effort_fires | a takeoff flap whooshes without the effort beat; a flap mid-climb adds the strained wing-beat; a flap while falling stays quiet | T-012 |
| sfx_peck_plays_on_eat | a grounded pigeon eating a crumb through Main's wiring plays exactly one bread peck | T-012 |
| sfx_splat_yelp_panic_honk | a real lobbed splat plays the splat plus its tourist's yelp, the indignant shout joins the fist shake ~1.8 s later, and a duck-typed car hit blasts the horn | T-012 |
| ambience_loops_under_game | main.tscn starts both ambience beds on the Ambience bus, start_ambience() is idempotent across restarts and the bed survives the scene teardown | T-012 |
| density_cpu_budget | the real main scene at full density (18 tourists + 36 cars asserted) keeps the calibrated headless CPU budget — median wall-time of three 100-frame windows under --fixed-fps 60 | T-018 |

## Gate 2 — Autoplay smoke test (run before marking any gameplay ticket done)

Boots the **real** game (`scenes/main.tscn`) in a window and plays it with a
scripted, city-aware pilot for 30 s: cruise above the skyline (every generated
roof stays under 18.3 m, the pilot's floor is 23 m), a flap-paced climb
(since T-015 the flaps pace near glide speed — the dive pulse owns the top
end), bank, a short
dive pulse that only starts high enough to stay over the roofs, pull-up, glide,
and airborne poop taps (T-006 — every 2 s in flight the pilot lobs a real
dropping; grounded taps are skipped; since T-007 it pulls the trigger early
whenever a strolling tourist lines up under the predicted impact point, and
since T-008 also for cars — same prediction, wider tolerance, because cars are
the deliberately easier target; since T-009 the ground-visit window raises the
lead-shot ceiling to 18 m — the descent is a steady approach, so the
fall-time prediction holds there — and a car-length pursuit trigger joins
them, so target hits stay chance shots with better odds). Cars themselves are
live in the run: 20 traffic
cars loop the ring roads and 16 sit parked at curbs, all visible in the
screenshots.
Below the cruise floor the pilot climbs
hard while circling the spawn plaza — the one spot the generator guarantees is
clear of buildings — and beyond 60 m from the plaza it steers home. From 11 s in
the pilot also makes a ground visit (T-003 + T-004): arc to the plaza, bleed
speed in a wide orbit, spiral down inside the building-free ring, touchdown,
waddle across the pavement, take-off. While landed it waddles toward the
nearest breadcrumb and pecks it up when it reaches one (T-005) — the DONE line
reports the hunger bar, how many crumbs were eaten, how many poop splats
landed, how many tourists are alive and how many took a splat (`panics`,
T-007), how many car honks the run earned (`honks`, T-008), and the score the
run built plus the persisted high score (`score` / `high`, T-009 — every real
splat and honk now pays the DESIGN table through the Game autoload, with
floating "+100 ×2" popups at the hits). Since T-010 the run then ends on
purpose at 30 s: the pilot starves the pigeon, the game-over score screen must
open over a frozen world showing that run's numbers (score, high score,
tourist/car breakdown — verified against the labels), the pilot restarts
through the exact path the screen's Space button drives and checks the fresh
run (unfrozen, score/breakdown zeroed, hunger refilled, pigeon back on the
spawn corridor) — `restart=true` joins `ok`, and a timeout waiting for the
screen fails the gate. Since T-011 the pigeon is the real presented bird (a
low-poly primitive pigeon, not a sphere) — flap beats, glide/dive wing poses,
the waddle and the eat peck are all visible in the screenshots, and the DONE
line reports which poses the run actually showed (`poses`). Since T-012 the
run is audible too: every event the pilot drove fires its sound, the DONE line
reports how many times each one played (`sfx`) plus the looping bed
(`ambience`), and the gate requires the bed looping and at least one flap
whoosh. Since T-013 the juice pass is live in the run — splat bursts, feather
poofs and dust puffs spawn as one-shot bursts and the DONE line reports the
peak number alive at once (`effects`, the no-spam evidence) and the peak
camera-shake trauma (`shake_peak`, the never-nauseating evidence). Saves a
screenshot every 5 s to `.godot/autoplay/`:

```bash
godot --path . res://tests/autoplay.tscn
```

**Pass =** exit 0, output contains `AUTOPLAY DONE ok=true` (which now includes
`restart=true`), and no `SCRIPT ERROR`
lines. The `DONE` line also reports the average rendered fps over the run —
the T-004 60 fps criterion is measured with it. A game window appears on the
desktop for ~40 s — that is the game being played; the screenshots are the
evidence.

Then confirm in a normal editor run (F5):

- [ ] Boots straight into the playable scene; Debugger → Errors tab is empty
- [ ] No warning spam on boot or during ~30 s of play

For interactive agent play sessions — including several running at once — use
the pilot harness (`python tests/tools/pilot.py start|send|state|shot|stop …`,
sessions isolated under `.captures/session_<id>/`); see AGENTS.md →
"Agent play: pilot harness" (T-014).

## Gate 3 — Manual playtest (run the full list before closing any ticket)

Keep this table in sync with `project.godot` and `README.md`:

| Input | Action |
| ----- | ------ |
| W / S | pitch up / down · waddle fwd / back while grounded |
| A / D | turn left / right · turn while waddling |
| Space | flap · takes off when grounded · starts a run from the title screen · fly again on the score screen (T-010) |
| F | poop — lobs a splat dropping while airborne (T-006) · a direct hit panics a tourist (T-007) or honks a car for 30 pts (T-008) |
| Shift | boost *(not implemented)* |
| Esc | pause — everything freezes; Esc again resumes (T-010) |
| R | restart the run — from the pause menu or the score screen (T-010) |
| M | back to the title screen — from the pause menu or the score screen (T-010) |
| Q | quit the game — from the pause menu or the title screen (T-010) |

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
- [ ] (T-005) Hunger reaching zero ends the run — the game-over score screen opens (T-010), exactly once per run
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
- [ ] (T-008) Parked cars line the curbs and traffic loops the blocks; cars never overlap or gridlock at corners
- [ ] (T-008) A splat on a parked car and on a moving car both honk (body flash) and tick the score by 30
- [ ] (T-008) Cars read as visibly bigger, easier targets than tourists; a moving car is hittable with modest lead
- [ ] (T-008) Follow one car for a full block circuit — it keeps looping normally after being splatted
- [ ] (T-009) Splats pay the DESIGN points — 100 per tourist, 30 per car — and a popup at the hit reads clearly at flight speed
- [ ] (T-009) Chained hits without landing escalate ×2, ×3… and reset when you land or after ~20 s
- [ ] (T-009) A fast low dive hit pays the +50% style bonus — visible as a bigger popup number
- [ ] (T-009) Beating the high score, then quitting and relaunching, shows the record survived
- [ ] (T-010) Boot lands on the title screen; Space (or the Fly button) starts a run on the spawn corridor
- [ ] (T-010) Esc mid-flight freezes everything dead — pigeon, hunger, traffic; Esc again resumes exactly where it was
- [ ] (T-010) From the pause menu: R restarts into a fresh same-seed city, M returns to the title, Q quits
- [ ] (T-010) Die on purpose twice in a row — each score screen shows score, high score and the tourist/car split; restart works from both (pause mid-flight during both runs)
- [ ] (T-010) The score screen flags a freshly beaten record and Esc cannot unpause a dead run
- [ ] (T-011) The pigeon reads as a pigeon — gray body, darker wingtips, green neck sheen — silhouetted at ~20 m against both roofs and road
- [ ] (T-011) Poses track the flight live: wings out gliding, swept back diving, beats on flaps, folded on the ground — no desync, no frozen wings
- [ ] (T-011) The waddle (squat, body rock, head-thrust bob) is at least a little bit funny
- [ ] (T-011) Eating a crumb plays the peck, and no pose ever clips the camera
- [ ] (T-012) Trigger every sound in a normal run — flap whoosh, climb effort, splat, tourist yelp, panic shout at the fist shake, car honk, bread peck
- [ ] (T-012) The mix is sane: nothing clips even when a splat, a yelp and a honk land at once, and the ambience bed never drowns gameplay SFX
- [ ] (T-012) The ambience loops seamlessly — no audible seam on the traffic murmur or the distant chatter over a few minutes of play
- [ ] (T-012) The flap whoosh reads in sync with the wing beat, and the effort strain only shows up on hard climbs
- [ ] (T-013) Splats burst droplets, hard flaps poof feathers, landings kick dust — the effects read at flight speed but never pile up into screen clutter
- [ ] (T-013) The camera shake on landings and your own splat hits is a tick, never nauseating — nothing obscures targets
- [ ] (T-013) Side-by-side with before, the city reads warmer and the four districts read as distinct-but-harmonious neighborhoods from the air
- [ ] (T-013) The HUD score pulse fires on combo escalation, reads clearly, and settles without jitter
- [ ] (T-016) The pigeon reads as a pigeon at ~20 m against a sunlit sidewalk and a cream facade, not just against the road
- [ ] (T-016) Side-by-side with before, the city still reads warm and sunny after the sun-energy retune (the T-013 warmth judgement re-based)
- [ ] Pigeon lands on the ground and does not fall through the world
- [ ] HUD hunger ticks down over time
- [ ] Camera does not clip through the ground while landing
- [ ] Closing and restarting the game produces no errors

## Known issues

- Flight model v1 is machine-verified (Gate 1b) and its speed envelope was
  re-tuned by T-015 (flaps pace toward ~25, dives own the top end —
  `flap_speed_envelope` green); a human feel pass over the T-001 playtest
  lines under the new envelope is still pending.
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
- Cars (T-008) are machine-verified (Gate 1b traffic/splat-honk scenarios) and
  live in the autoplay city (the DONE line reports `honks`); since T-012 the
  honk is a body flash plus the horn. A human pass over the T-008 lines (parked
  + moving splat, one full traffic circuit, bigger-target readability, corner
  flow at full density) is still pending.
- Scoring & combos (T-009) are machine-verified (Gate 1b values/combo/style,
  high-score persistence and popup scenarios) and live in the autoplay run (the
  DONE line reports `score`/`high`); a human pass over the T-009 lines (popup
  readability at speed, combo rhythm, style-bonus feel) is still pending.
- Game flow (T-010) is machine-verified (Gate 1b pause-freeze, score-screen and
  restart scenarios) and exercised end to end by the autoplay pilot (the DONE
  line reports `restart`/`run_score`/`run_tourists`/`run_cars`); a human pass
  over the T-010 lines (title → play → starve → score screen → restart loop,
  pause feel, die-twice manual run) is still pending. Restart is deliberately
  in-place (Game.reset_run + same-seed city.generate, spawners re-seed off
  `regenerated`) rather than a scene reload — the identical path runs in the
  game, the sim harness and the autoplay pilot.
- Pigeon presentation (T-011) is machine-verified (Gate 1b pose-tracking and
  peck scenarios) and visible in every autoplay screenshot; the mesh is
  hand-built from primitives (no third-party asset, so no CREDITS entry). A
  human pass over the T-011 lines (silhouette at 20 m, pose readability at
  flight speed, waddle comedy, camera clipping) is still pending.
- Audio (T-012) is machine-verified (Gate 1b bus/assets, flap-effort, peck,
  hit-sounds and ambience scenarios) and audible in the autoplay run (the DONE
  line reports `sfx` counts and `ambience`). Every file is CC0 and logged in
  `assets/CREDITS.md` — the ambience beds were made into seamless loops
  (head-tail crossfade) from field recordings. A human listen pass over the
  T-012 lines (clipping at pile-ups, loop seams, flap/sync feel, honk
  believability — the horn is a comedic bike-horn blast) is still pending.
- Juice pass (T-013) is machine-verified (Gate 1b district-palette, splat-burst,
  feather-poof, dust-puff, landing-shake and hit-shake/score-pulse scenarios)
  and live in the autoplay run (the DONE line reports `effects` and
  `shake_peak`; average fps 130 — the 60 fps criterion holds with all
  particles active). A human pass over the T-013 lines (aliveness side-by-side,
  shake comfort, screen clutter, district palette harmony) is still pending.
- Performance budget (T-018) is machine-verified **headless only**
  (`density_cpu_budget`): a headless run renders nothing, so the gate sees the
  CPU half of the frame (scripts, physics, scene) — draw-call/primitive
  regressions stay with Gate 2's autoplay DONE line (average fps) and Gate 3's
  human pass over the T-004 "~60 fps" line. The budget is absolute
  wall-time calibrated on the dev machine (750 ms per 100 physics frames vs a
  measured 247.5 median, ticket T-018): a busy machine can false-FAIL it
  (re-run idle), and a regression smaller than its ~3x headroom passes by
  design. The `city.generate` synchronous rebuild spike at boot/restart is
  recorded in the ticket, not gated.
- Remaining placeholder art: buildings are tinted
  boxes with a procedural window texture.
- T-016 machine-checked the pigeon's material contrast and capped the sun, but
  the human pass over its two new Gate 3 lines (bird readable on sidewalk and
  facade at ~20 m; city still reads warm after the energy retune) is pending.
  The grounded "folded wings still read as splayed" issue remains open: pose
  retuning alone (−0.35 lift / 1.5 sweep) was A/B-tested in play and narrows
  the wing plane only ~15 % — invisible at a glance; the splay comes from the
  0.24 m wing chord presenting laterally, which needs a mesh/rig change.

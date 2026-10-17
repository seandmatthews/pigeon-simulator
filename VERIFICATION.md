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
| sustained_flap_ceiling | TWELVE paced ground flaps (the takeoff cadence, fully rested) converge below the 26 m/s pump ceiling instead of riding toward `max_speed` — peak forward speed tracked through the whole cadence AND a 3 s no-input coast, velocity finite throughout; measured 20.26 m/s at the landed `flap_sustained_fade` 0.5, and 28.28 m/s (FAIL) without the fade | T-043 |
| lift_softens_gravity | level glide at 12 m/s sinks gently (< 6 m in 1.5 s) | T-001 |
| dive_gains_speed | a dive to −60° converts height into speed | T-001 |
| pullup_gains_height | pulling out of a dive climbs above the pull-start altitude while speed bleeds | T-001 |
| banked_left_turn | a held turn banks the body and yaws with the bank | T-001 |
| stall_drops | stalling sinks far harder than gliding and the nose drops | T-001 |
| stall_recovers | a flap restores flying speed out of a stall | T-001 |
| landing_slides_to_stop | a low touchdown slides to a stop — no bounce, no NaNs | T-001 |
| camera_follows_yaw | the rig swings around behind a turning pigeon | T-002 |
| camera_fov_kick | the FOV kick survives but stops pinning at cruise — at 26 m/s the damped FOV sits inside absolute bounds 74.0–80.0 (fov_air 72 below the floor; the old pinned fov_max 86 measured 85.9 there, failing) and the airborne arm reads pulled in with speed < 6.2 m (the old fixed 6.5 m target measured 6.50, failing; since T-044 it damps toward arm_length_air_fast 5.8 on the FOV ramp) | T-002, T-044 |
| camera_tucks_in_grounded | arm shortens while grounded | T-002 |
| waddles_on_ground | a gentle drop settles grounded and W walks forward at waddle pace | T-003 |
| waddle_turns | A/D turn the pigeon in place while grounded | T-003 |
| flap_takes_off_ground | a grounded flap returns to climbing flight | T-003 |
| roof_landing | a raised roof is landable — the pigeon settles grounded on top | T-003 |
| roof_takeoff | flapping off a roof works like off the pavement | T-003 |
| bench_landing | a thin bench seat is landable and walkable | T-003 |
| bench_takeoff | flapping off a bench returns to flight | T-003 |
| hard_landing_skids | a steep fast dive skids to a stop — no instant ground, no tunneling, no NaNs (T-021 retuned the skid detector to AIR floor frames above `skid_settle_speed`) | T-003 |
| trim_glide_lands_clean | a natural trim-speed glide touchdown settles into the waddle on the contact frame — zero airborne floor-contact frames past the touch (no ghost-slide) | T-021 |
| flare_sheds_speed_low | holding pitch-up in a shallow descent sheds speed into a nose-high brake instead of ballooning — from a settled ~15 m/s glide at ~6 m, 0.75 s of held pitch-up gains < 2.5 m of height and ends below 11 m/s (before the flare: +2.60 m / 11.66 m/s); climbs and level flight above the band and dives below the −8 m/s edge never flare, and the grounded skid keeps its own friction | T-022 |
| pitch_attitude_bounded | a held 50-frame pitch-up from settled cruise keeps \|body pitch\| ≤ 85° on every frame of the hold and for 30 frames after release, and bounds the balloon outcome: peak climb vy < 8.7 m/s during the hold and post-release \|vy\| < 1 m/s mush < 244 of 300 frames — bars taken from the pre-fix tree's measured run (pre-fix measured 79.9° nose parked frozen, 8.85 m/s, 247/300 — FAIL; with the falloff 70.7°, 8.48, 240/300 — PASS. The authority decay from bleeding forward speed already slows the pre-fix rotation, so the red-before comes from the balloon bars, not the 85° line) | T-083 |
| hands_off_glide_trims | a RELEASED pitch input eases the nose toward the velocity vector instead of freezing it — from a settled cruise glide an 8-frame pitch-up hold displaces the nose > 10° off the flow (measured 14.54° pre-T-117, 17.35° at the ×1.2 pitch rate), then 90 frames hands-off show the nose travelling ≥ 2.5° back toward the flow (measured 4.91° at the landed trim_rate 0.7, 6.24° on the T-117 tree; the pre-fix tree freezes it — 0.00°, red-before) with the signed nose-to-flow angle bounded ≤ 8.4° (measured 7.59°; the bar was 7.0° at measured 5.72° pre-T-117 and was re-derived ×1.2 for T-117 — the faster pitch rate deepens the entry and the 90-frame window cannot out-run the deeper residual, while a settle probe showed the trim still converging to the same ≈5° equilibrium by 360 frames, trim_rate untouched; the backlog-audit-flagged "< 3°" draft bar was re-derived from measurement, not weakened — the released glide sits at an angle-of-attack equilibrium the 90-frame window cannot out-run, sweep + equilibrium analysis in the ticket) | T-082 |
| hands_off_mush_exits | a slow nose-high hands-off mush FALLS instead of hovering at the aligner's zero-sink equilibrium — from a 6.6 m/s level glide tipped 0.29 rad nose-up, 240 hands-off frames must lose ≥ 3.0 m and reach a sink ≤ −2.0 m/s (measured landed: −8.71 m, min vy −2.70 m/s; the pre-fix tree only mushes: −3.99 m, min vy −1.76 m/s — FAIL on the sink arm, red-before; both runs in the ticket) | T-081 |
| stall_falls_develops | a ballooned climb that reaches the stall flag develops a real fall, not a hover: within 45 frames of `stalled` the sink must reach ≤ −6.0 m/s (measured landed: stalled at frame 48, vy −6.00 reached in 37 frames; the pre-fix tree hovers in the stall: stalled at frame 38, vy only −2.79 after the full 45 — FAIL, red-before; both runs in the ticket) | T-081 |
| loop_over_top_roll_recovers | the owner's loop repro leaves no persistent roll cant: settled cruise → 15-frame turn_left seed → pitch_up held with a near-fully-rested flap tap every 21 frames until the nose parks at the T-083 asymptote, ending the hold ON a fresh kick; the nose must demonstrably sweep over the top (nose·entry_fwd < 0 within 240 frames of release, sanity nose.y > 0.9 somewhere in the hold — the precondition is asserted, never skipped), then 120 frames of hands-off-steering flight (the repro's own flap cadence continues — re-derivation recorded in the ticket) must end with \|measured roll\| ≤ 5° and non-increasing across its last 60 frames (measured landed: end 0.00°, trend 0.00, crossing 24 frames after release, near-pole \|roll\| peaked 21.2° inside the envelope → no gating band needed; the pre-fix bookkept tree ends at 176.84° fully inverted and still increasing — FAIL, red-before; both runs in the ticket) | T-106 |
| loop_lands_level_keeps_yaw | the ground leg of the same scenario: a fresh low cruise glide seeded with the full-envelope cant the book cannot see (`max_bank_deg`) descends passively and must stand \|measured roll\| ≤ 2° after 60 grounded frames with the heading moved ≤ 2° from touchdown (measured landed: stand 0.00°, yaw drift 0.00° — the measured controller eats the cant in flight and the leveler squares whatever the skid leaves; the pre-fix bookkept leveler stands the bird at exactly the seeded 40.00° — FAIL, red-before; both runs in the ticket) | T-106 |
| off_world_fall_respawns | a pigeon placed below the `off_world_y` guard (−5) and past every floor is grounded on the respawn corridor within ~2 s — the guard fired exactly once (`off_world_resets` == 1, no second fire across a further ~2 s, velocity finite throughout) and the hunger clock kept draining through the reset (loss > 0.2) | T-042 |
| city_same_seed_deterministic | regenerating with the same seed reproduces the identical layout fingerprint | T-004 |
| city_new_seed_guarantees | a different seed still yields a clear spawn plaza, flyable street widths, capped roof heights and enough bread-capable surfaces | T-004 |
| city_regenerate_restores_layout | after regenerating a foreign seed, the default seed rebuilds the original city exactly | T-004 |
| city_plaza_spawn | a drop into the spawn plaza settles grounded on the pavement | T-004 |
| city_street_flyover | a flap-assisted flight crosses the whole city along a street without touching anything | T-004 |
| city_roof_landable | a generated building roof is landable and walkable | T-004 |
| city_roof_takeoff | flapping off a generated roof returns to flight | T-004 |
| city_sidewalk_walkable | the pigeon waddles up a curb from the road onto the sidewalk ring | T-004 |
| hunger_drain_flap_vs_glide | hunger ticks in flight — visibly faster while flapping than gliding, slowest resting grounded | T-005 |
| hunger_game_over_once | hunger empties, clamps at zero and fires game_over exactly once; eating restores a chunk but the latch holds; since T-075 the guarded setter also stays silent at zero — 120 further drained frames with the player still attached count ZERO `changed` emissions (the unguarded tree measured 120, one per tick) | T-005, T-075 |
| crumb_eaten_grounded_only | flying over a crumb never feeds; a grounded pigeon waddling into it eats it and frees it | T-005 |
| crumbs_respawn | eaten crumbs are topped back up to the target count within one respawn interval | T-005 |
| poop_inherits_and_arcs | an airborne drop inherits the pigeon's velocity, keeps the horizontal lead and only ever falls | T-006 |
| poop_grounded_no_drop | F does nothing while grounded — droppings exist only in the air | T-006 |
| poop_cooldown_blocks_stream | mashing F yields one dropping; the next comes only after the cooldown elapses | T-006 |
| poop_splats_ground_and_fades | a floor hit fires splatted(target, impact_velocity), sticks an up-facing splat to the hit body and fades it away | T-006 |
| poop_splats_wall | a wall hit sticks a splat facing along the wall's horizontal normal | T-006 |
| poop_event_reaches_any_body | a plain body on the hit layers receives the hit duck-typed (on_splatted) with no player import anywhere in poop.gd | T-006 |
| poop_ball_visible | the falling drop reads from the chase cam — BallMesh radius ≥ 0.10 (landed 0.12), Mat_ball carries the soft warm emission in the parse-safe 4-arg Color form (a 3-arg Color in a .tscn fails to parse, load() → null), albedo ≥ 0.25 Euclidean RGB from grass and plaza (measured 0.853 / 0.545) and the collider stays pinned at T-060's retuned 0.30 (the landed 0.07 pin amended in place — the pin's purpose survives: the collider still deliberately differs from the 0.12 mesh, the overhang direction flipped) | T-086, T-060 |
| reticle_frozen_pin_matches_damped_fall | the ONE persistent poop reticle (T-105, replacing T-046's per-drop ring) pins where the drop will REALLY land — bare rig, direct `poop_reticle.tscn` instantiation + `lock_to(drop)` of a real tap's drop from the cooldown scenario's exact set-up (0, 20, 0)/(0, 0, −12): the frozen pin sits within 0.5 m of the impact recomputed INDEPENDENTLY in the scenario by the DAMPED closed form from the drop's own p0/v0 (read fresh from the drop, never through the reticle's march — the no-self-test rule), with the damp read straight from the `physics/3d/default_linear_damp` project setting (measured 0.03 m; measured damped-vs-undamped separation 1.03 m at this release, and the red-before probe — march reverted to T-046's undamped parabola — measured the pin 1.16 m off and FAILed this leg, so the damping fix is load-bearing); the pin is stable through the fall (≤ 0.05 m across ≥ 30 frames — frozen means frozen); and after the splat the reticle is back in live mode within 0.5 s, still alive — it never frees mid-run | T-105 |
| reticle_main_lifecycle | the reticle's whole run lifecycle through the REAL main scene (the T-077 instanced-Main pattern, parked in its own corner, the bare test pigeon parked grounded first so the tap can only fire through Main's own player): exactly ONE reticle node (the `poop_reticles` group) serves the WHOLE scenario — live mode at the 10 m hover pins within 1.0 m of the hover state's hypothetical damped impact (the scenario's own independent recompute: its own down-ray for the surface, its own closed form and bisection; measured 0.03 m), alpha 1.0; one REAL tap freezes it and dims it to ≈ 0.25 immediately (the T-077 dim convention); the cooldown expires before the 10 m drop lands, so it relights to 1.0 while still frozen; the splat returns it to live with the node count unchanged (persistence — the anti-assertion to T-046's "group empties again"); grounding hides it entirely; and restart_run() mid-freeze recovers it on its own — visible, live, full alpha, the pigeon airborne (no restart-specific code) | T-105 |
| reticle_live_refresh_30hz | the reticle's LIVE re-march cadence is the T-110 tuned value, locked as a bare-rig value check (direct `poop_reticle.tscn` instantiation, no player — the derivation runs in `_ready`): `live_refresh_hz` 30.0 resolves to exactly 2 physics ticks of the fixed 60 Hz step (whole-tick quantization — 24 would round to an effective 20), so a silent revert of the export (T-105's 10.0 → 6 ticks) FAILs both arms; the live-mode feel itself is the Gate 3 line below | T-110 |
| poop_ready_indicator_tracks_cooldown | through the real main scene, the F glyph beside the hint line shows lit at full alpha while airborne with a rested drop, dims to ~25% the moment a REAL poop fires, stays dim through mid-cooldown, freezes with a paused tree and relights when the cooldown elapses in game time with no further press, hides entirely while grounded, and restart_run() mid-cooldown relights it (T-019 outline treatment asserted) | T-077 |
| coach_hint_shows_until_first_hit | through the real main scene (the T-077 instanced-Main pattern, its own TouristSpawner tightened to ONE tourist before _ready), the hint slot shows the plain air hint while airborne ~60 m from the tourist (out of coach_range), shows the lead line `COACH_POOP` while airborne ~20 m ahead of it, falls back to the air hint after one synthetic `Game.add_tourist_hit` (the coach is keyed on `tourist_hits`, never on a signal — per-run, so reset_run() re-teaches), and shows the ground hint when grounded beside the tourist, still within range — ineligible only by grounding | T-060 |
| tourists_walk_loose_groups | 18 tourists stroll their sidewalk loops at slab level, seeded in loose groups | T-007 |
| tourist_splat_panics_scores | a real lobbed splat panics its tourist (sprint + arms) and fires the splatted score event, scored end to end through the Game autoload (100, then the chain's ×2 → 300); a sideways hit makes the panic flee along the impact's horizontal mirror; since T-055 the scenario also reads the shirt's `material_override` albedo — exactly the tourist's palette `shirt_color` while calm (sampled before the drop) and exactly `Tourist.PANIC_TINT` mid-panic (confirmed inside the existing 120-frame poll) | T-007, T-055 |
| poop_hits_tourist_within_lead_window | a drop aimed at the predicted stroll position — the autoplay formula (live flat position + live flat velocity read at release, × the 0.8165 s a 4 m fall takes at `fall_gravity` 12) — connects on a tourist KEEPING its sidewalk loop (never frozen; the scenario seats it mid-leg so no corner can bend the stroll mid-fall): `splatted` fires, the tourist panics; the same drop aimed 1.5 m lateral of the prediction never touches it — 0.95 m of clean margin outside the 0.30 + 0.25 = 0.55 m contact reach, so a ground splat may fire but no event targets the tourist and the mood never reaches PANIC; and the acceptance bar itself — 0.4 m lateral, inside the reach — connects again | T-060 |
| tourist_buzz_flinch | a slow pass through the buzz zone earns nothing; a fast one earns a flinch duck, never a panic | T-007 |
| tourists_recycle_around_player | moving the player recycles the same tourist nodes into the spawn band around the new position | T-007 |
| cars_traffic_loops_blocks | 20 traffic cars loop their block rings at lane speed — every car covers ground, the fleet rounds corners, no two cars ever overlap — while the parked fleet sits exactly where it was seeded | T-008 |
| car_splat_honk_and_continue | a parked car takes a real lobbed splat (honk + score event relayed, stays parked, 30 scored through the Game autoload; the synthetic traffic hit is the ×2 → 90) and a traffic car hit through the same duck-typed entry keeps driving its loop | T-008 |
| traffic_recycle_keeps_flow | with the pigeon parked on the plaza, 5 traffic cars re-seated onto one plaza-adjacent ring through the exact recycle insertion call (`_clear_rejoin_point`) all keep flowing — every seeded car covers ≥ 8 m of path in 10 s, seeded pairwise gaps stay ≥ 4 m (a healthy follow-gap queue still clears it), the fleet no-overlap floor stays > 2 m, velocities stay finite and no car jumps > 5 m in a frame (the whole ring lies inside the recycle radius, so the scanner must leave it alone); plus the block draw prefers rings under `ring_traffic_soft_cap` (an over-cap ring is never drawn while a lighter candidate exists) | T-089 |
| cars_recycle_around_player | teleporting the pigeon ~120 m west of the seeded fleet — beyond the car `recycle_radius` 100 — lets the timer-driven `_recycle_far` scan (3 scans over 90 fixed frames) recycle the SAME car nodes end to end: instance ids all preserved, fleet still 20 traffic + 16 parked, every car inside the recycle radius of the new anchor or on a spawn-band block (30–70 m), and no two parked cars within the 4.5 m `_spot_taken` curb threshold (the PARKED branch's curb exclusivity survives the recycle — the anchor is pinned by grounding the bird on the plaza first, and the hop stays close enough that band blocks remain: nearest centers 40–68 m away, so the band does not empty and legitimately recycle nobody) | T-054 |
| citizen_classes_spawn_deterministic | the T-113 class multiset is a seeded law on BOTH spawner rigs at the shipped targets (18 tourists · 20 traffic + 16 parked cars) over a real generated City: the class tallies match the share knobs within integer rounding at the M1 seed AND at seed 424242 (recomputed through the scenario's own tally over the living nodes, never spawner internals; civilians take the exact remainder), a forced same-seed rebuild + re-populate reproduces both uniform multisets byte-identically (sorted class\|color\|finger rows per node), and a forced `_recycle_far` with the pigeon 120 m away — beyond both recycle radii — keeps every node's class and colors on the same instance ids (same node, same uniform; ≥ 1 tourist and ≥ 1 car verified to actually teleport) | T-113 |
| citizen_classes_readable | per-class machine reads on all-visitor / all-superfan / all-civilian rigs driven through the share knobs: every VISITOR pedestrian wears torso ≠ arm materials, both exactly ∈ {TEAM_GOLD, VISITOR_BLACK} (the pairing, not any single albedo), finger carriers hold the mitt visible, pointing up (global basis y ≥ 0.95) with its top edge ≥ 1.42 m — 0.15 above the 1.27 m head line, nominal 1.50 — while non-carriers and civilians carry no props; every SUPERFAN is cardinal torso + gold arms + visible gold cap + always-carried mitt; every CIVILIAN wears ONE material from `SHIRT_PALETTE`; VISITOR cars wear gold-or-black body paint with pole + banner visible, banner top ≥ 2.2 m, the banner in the pairing partner color (gold body → black banner, black body → gold banner); SUPERFAN cars cardinal body + gold banner; CIVILIAN cars stay in `BODY_PALETTE` with flags hidden; plus the contrast leg — all three class colors hold ≥ 0.20 Euclidean RGB from sidewalk, plaza and asphalt (measured gold↔sidewalk 0.733, black↔asphalt 0.376, cardinal worst 0.557) | T-113 |
| civilian_palette_reserved | the T-121 reservation law pinned bare: the civilian `BODY_PALETTE` holds exactly 5 entries and every entry keeps ≥ 0.20 Euclidean RGB from BOTH team colors (measured worst 0.61 vs TEAM_GOLD, 0.68 vs VISITOR_BLACK — the citizen_classes_readable contrast bar), so the old hue-twin gold/near-black civilian paints can never sneak back into the jackpot read; the scene carries the grown tell — pole mesh 0.06×0.9×0.06, banner 0.62×0.9×0.03, both flags hidden at rest, banner top 2.75 m (≥ the T-113 2.2 m read line) | T-121 |
| splat_favor_follows_citizen_class | the T-114 favor book pays through the real chain, through the REAL main scene (instanced-Main pattern, held airborne throughout so no elder trust can bank and no crumb can feed): the boot leg pins the main scene's spread at the new law — the 6 parked-visitor tailgate crumbs hand-placed (the exact integer quota of the shipped knobs, export-derived), the spawned budget held at 34 → 31 TABLE / 2 GROUND / 1 ROOF, 40 living crumbs total (the `restart_resets` count intact) — a synthetic `Game.add_tourist_hit` (the coach leg's entry) pays NO favor; then each share knob forced to a single-class rig (`citizen_classes_readable` pattern) + re-populate and the relay driven at a REAL living node — visitor, civilian and superfan tourists, then parked visitor and civilian cars — move `Game.favor` by EXACTLY that class's export every leg (asserted against the exports, never literals) with the cumulative sum exact; a `grounding_changed` landing between legs zeroes the combo while favor stands still — splat favor never touches the combo; the HUD legs drive `Game.add_favor` directly and read the `%FavorLabel` under the landing-note row: rest text `Favor: <n> / <max>` at the column's fill (the T-116 ceiling form), the gold gain note `Favor: <n> / <max>  (+6)`, the 2.5 s game-time expiry back to rest, the red loss note `Favor: <n> / <max>  (-1)`, and the restart_run reset to `Favor: 0 / <max>` | T-114 |
| elder_bread_gates_on_favor | the T-114 elder gate on the `_add_elder_rig` rig with `Game.favor = 0` STAGED at setup: a grounded pigeon hangs the full `trust_needed` + 5 s margin — trust pins at `trust_needed` while NO share fires, no crumbs land, the relay count stays 0, `share_count` stays 0 and favor stays 0 (no charge); then one `Game.add_favor(elder_loaf_cost * crumbs_per_share)` unblocks exactly one share within 3 physics frames — trust still pinned (the gate was the only blocker), the relay carries `crumbs_per_share`, the tossed crumbs appear, and favor reads exactly `elder_loaf_cost * crumbs_per_share` lower afterwards (the spend booked at the share, not the eat) | T-114 |
| bread_steal_favor_deltas | the T-114 steal surfaces, bare rigs over a real City with the Main wiring (`crumb_favor` → `Game.add_favor`) connected on the rig and the relays captured: a live TABLE crumb eaten grounded (the tabletop feed path — drop onto the tabletop, settle, waddle) emits `crumb_favor` with exactly `Game.favor_steal_table` and favor moves by exactly that; a hand-dropped `drop_crumb(pos, Game.favor_steal_visitor)` crumb eaten the same grounded way pays exactly `+favor_steal_visitor`; an ordinary GROUND crumb pays 0 and emits nothing; then on a real City + `CarSpawner` rig at the shipped knobs, the scenario's own tally of living parked VISITOR cars equals the favor-marked crumb count (the exact integer quota of the knobs, export-derived) with a per-car bijection, every crumb sitting at the documented gutter offset in its own car's frame (0.45 m off the 0.95 m half-width body, 0.75 m back, ground + 0.06 lift, body-surface distance inside [0.45, 1.0] m), and a forced `_recycle_far` re-anchor keeps the one-crumb-per-parked-visitor law; zero RNG is structural — the seeded class multisets stay byte-identical via `citizen_classes_spawn_deterministic`, which re-runs green in every full suite pass | T-114 |
| favor_max_ends_run_victory | the T-115 ceiling ends the run as a VICTORY through the REAL main scene (instanced-Main pattern, pigeon held airborne): favor staged 2 under `favor_max`, the parked fleet forced all-VISITOR (the T-114 rig), and ONE real parked visitor car driven through Main's relay — favor reads EXACTLY `favor_max` (the clamp in the real chain), the tree pauses, the score screen opens in the victory register (`THE TOWN IS YOURS!` title, the `victory_dim` gold wash, the victory note visible, the breakdown carrying the run's real splat counts plus the favor total) while `Game.hunger.game_over_emitted` stays false and hunger > 0 (the two endings are independent), and Esc is locked (the `toggle()` refusal); a further splat books nothing past the clamp and fires no second `favor_maxed` (one-shot per run); coexistence legs in one Main: a direct `hunger.game_over` emit with the victory screen up changes NOTHING (first-wins — still victory-mode, still paused), `restart_run()` unpauses/closes/zeroes favor/re-arms (a staged sub-max add fires nothing), then favor staged LOW + `drain_per_second` 60 starvation opens the SAME screen in the `STARVED!` register — title, dark red dim, no victory note, plain breakdown — proving both entries rewrite every mode-dependent property and neither register leaks | T-115 |
| score_combo_style_values | the Game autoload pays DESIGN values (tourist 100 · car 30), the chain escalates ×1 → ×2 → ×3 across target kinds and resets on landing and on the 20 s window, and the +50% style bonus demands a release that is fast, low and fresh | T-009 |
| score_high_score_persists | beating the record writes user:// at once and a fresh Game loads it back | T-009 |
| highscore_save_throttled | only the run's FIRST record-beating hit pays a synchronous disk write (T-073): 20 bare tourist hits against a planted record of 100 perform exactly ONE save and leave the file at the first-beat score (300, not the cumulative 21,000 the chain reached — combo escalation 100×1 … 100×20, no landing/release staged so the style gate can't fire), then emitting the Game-owned `hunger.game_over` flushes exactly one more write and the file reads the final 21,000 (`_save_count` delta exactly 2 across both legs; the file is read back through an independent ConfigFile, never `load_high_score()`) | T-073 |
| favor_max_book_clamps_and_flushes | the T-115 ceiling's book legs, bare autoload in the `highscore_save_throttled` window (directly after it): from `reset_run()` a `add_favor(-50)` reads −50 and emits delta −50 (the T-114 no-floor lock intact); with the T-073 dirty state staged (`_saved_this_run` true, `_high_score_dirty` true, a beaten record) one `add_favor(favor_max + 25)` leaves favor EXACTLY `favor_max` (never over), emits the APPLIED delta (150, not the requested 125 — the clamp's arithmetic), performs exactly ONE disk write and the file reads the final score back through an independent ConfigFile (the victory path's flush — the hunger path's twin, fired from inside `add_favor`'s one-shot latch); a further `add_favor(10)` clamps silently and fires NO second `favor_maxed` (and no further write); and `reset_run()` re-arms — a second climb re-fires exactly once, its flush a no-op while the record is clean | T-115 |
| favor_meter_names_the_ceiling | the goal layer announces itself (T-116), through the REAL main scene (instanced-Main pattern, pigeon held airborne so no ambient crumb feed can move the balance mid-read): `Game.favor_max` is value-locked at 100 (T-115's tuning — a silent retune FAILs the leg by design), the meter's rest form is `Favor: <n> / <max>` interpolated from the export (no literal in `main.gd`), the gold gain note reads `Favor: <n> / <max>  (+6)`, a staged −3 balance re-rendered by a zero add reads `Favor: -3 / <max>` (the T-114 no-floor debt shown, not hidden), and `restart_run()` resets to `Favor: 0 / <max>`; the scene-static `%FavorGoal` caption row sits under the meter (unique-name resolved, offset below the label) with the exact text "max the elders' favor to take the town", the column's 4 px outline at 14 px font and the dimmer white @ 0.6 caption fill — the scene owns the text and no code writes it, so these asserts are the whole contract; the T-039 scenario's footer leg grows the rules-line guard alongside (footer names "favor" and "town") | T-116 |
| score_popup_floats_and_fades | the world-space popup shows "+100 ×2" at the hit position, floats up, fades and cleans itself up; since T-059 it renders 1.5× taller in the world (pixel_size 0.015 at the unchanged font_size 96) and the lone popup still rises exactly rise_height (index 0); since T-059 a chained arm drives a REAL main scene's own hit_scored spawn path with two tourist hits 8 m apart in depth inside one second — exactly two popups stay alive in the group, labelled the bare combo payouts "+100" then "+200 ×2" (reset_run() re-stales `_release_age` to 999 and it only grows, so the style gate cannot fire — no styled "+300 ×2" is reachable by this recipe), carrying rise_totals exactly rise_step apart (1.8 m and 2.7 m at the landed values) | T-009, T-059 |
| score_popup_style_tag_format | the static popup format variants: a styled hit appends the STYLE tag in both multiplier shapes (`"+150 ×2 STYLE"` / `"+150 STYLE"`) while every unstyled form stays byte-identical (`"+150 ×2"` / `"+150"`) | T-038 |
| score_popup_style_tag_live | through the REAL main scene's `hit_scored` path: staging the chain explicitly (grounding reset, then a fresh fast/low release — ≥ 14 m/s from ≤ 6 m) before a tourist hit spawns a popup reading `"+150 STYLE"` — the chain's first hit, ×1, 100 × 1.5, the Why's bare-150 case labelled — tinted the HUD pulse gold `Color(1.0, 0.85, 0.3)`; the slow-release follow-up (chain at 1, ×2 plain, 200 paid) spawns `"+200 ×2"` with no tag and no gold; the two earlier unstyled popups have freed by the read (1.2 s lifetime vs ~1.6 s elapsed), so exactly two popups are alive in the group | T-038 |
| pause_freezes_world | Esc-pausing through the real PauseMenu stops the flying pigeon dead mid-air and the hunger clock with it; resuming hands both back | T-010 |
| title_escape_does_not_quit | a synthetic Esc (`pause`) action fed straight to the real title scene's `_unhandled_input` neither quits the process nor pauses the tree — the menu instance survives; a regression re-adding the quit branch kills the whole Gate 1b run at that line (`flap`/`quit` are never fed — they would change the scene / quit the harness) | T-097 |
| game_over_shows_score_screen | starving through the real main scene opens the score screen — score, high score, tourist/car breakdown — freezes the run dead and keeps Esc locked | T-010 |
| restart_resets_run | restart through Main.restart_run() zeroes score/breakdown, refills hunger, clears the game-over latch, re-uses the same-seed city and re-seeds every spawner with fresh nodes | T-010 |
| restart_same_seed_skips_rebuild | a real main.tscn restart through Main.restart_run() takes the same-seed fast path — build_count stays 1, fingerprint/spawn_point/last_report untouched, exactly one regenerated — while every tourist AND car spawner re-seeds fresh nodes and the pigeon returns to the spawn corridor (fails if `regenerated` stops firing: the old nodes would survive) | T-033 |
| hud_bread_pointer_tracks_nearest_crumb | the HUD bread pointer names the nearest living crumb (distance within 1 m; `nearest_crumb()` matches an independent scan and returns null when none is alive) and, since T-111, aims the BREAD GLOBE — the pigeon-frame drawn instrument that replaced the chevron lineage (T-037's slot, T-057's screen-space rebuild, T-098's climb cue and T-058's stern suffix all retired into one geometric encoding): every arm is `reset_flight` → 2-frame wait → sample (the widget reads NO camera — the T-057 chase-camera convergence loops are gone), and every direction expectation is the scenario's own recompute off the LIVE player basis (`basis.inverse() * delta.normalized()`, dot ≥ 0.999), never through the widget's code. The steering contract: a scan-decided `drop_crumb` 10 m down the nose axis at hover height reads `dir_local` (0, 0, −1) within 0.01 — the machine form of "steer along the segment and you intersect the bread" — with the tip on the fly-to pip within 1 px and `screen_offset` up (y < 0) and axial (\|x\| < 1); the SAME crumb at yaw 180 tracks its own recompute with `dir_local.z` > 0.9 and the segment drawn DOWN; a grounded pigeon under a placed ~10 m overhead crumb draws \|screen_offset\| strictly LONGER than dead-ahead (foreshortening orders ahead < above — the 25° vantage tilt is load-bearing); a hover with a placed crumb 5 m behind-below reads stern (`dir_local.z` > 0, `screen_offset.y` > 0). The text is the minimal remainder — `_pointer_distance_m` parses ONLY strict `<what> <n> m`, so any re-introduced ▲/▼ cue or " — turn around" suffix turns every distance assert to −1.0 and fails (asserted bare on the overhead, stern and city arms). The flash state machine: a just-eaten target's re-aim flashes (`flash_active` true right after the real grounded waddle-in eat), a nearer placed crumb flips it true immediately with the text re-aimed ± 1 m, it settles back to rest within flash_seconds (0.4 s = 24 frames) of game time, steady same-crumb frames never re-flash, city frames never flash, and the first acquisition after restart_run() never flashes; the zero-delta guard keeps the last drawn direction, finite — never a NaN — through a direct `_aim_bread_pointer(pigeon_pos, "bread", 0.0)`. City mode at the yaw-90 edge hover still reads "city <n> m" ± 2 m of the horizontal distance with the globe aimed at city.spawn_point through the same mapping (a stern homing read is now geometric). The readout decreases on approach, eating the pointed-at crumb through the real grounded waddle-in re-aims at the next-nearest, and the label keeps the T-019 outline treatment | T-037, T-111 |
| hud_hunger_warning_tiers | the HUD score/hint outlines resolve through the theme, the hunger bar's four warning tiers map the 50/25/10% bands through the real Main scene, the danger tiers pulse in game time (tier 3 faster than tier 2) and falling back restores the rest color — via refill and restart_run; since T-080 the bar also resolves its own `background`/`fill` StyleBoxFlat overrides (dark translucent track, pure-WHITE fill — the tier-modulate invariant — both with the dark-outline border ≥ 1 px on all four sides); since T-075 a standing-percent boundary arm pins the tier-OR-percent bar-write guard (50.4% → 49.98%: percent 50 throughout while tier 0 → 1 — the bar value still rewrites and the tier repaints) | T-019, T-080, T-075 |
| hud_combo_strip_reports_last_hit | through the real main scene, a `%ComboStrip` label sits under the pointer block with the T-019 outline treatment and starts empty; emitting the spawners' splat relays at real tourists/cars (no physics) shows "Tourist +100", the chained second tourist "Tourist +200 ×2", and after a landing a car splat replaces it with "Car +30"; every hit also spawns a hit_marker.tscn burst ON the hit body (parent + hit point asserted, found via the `juice_effects` group) that cleans itself up; the strip clears itself after `combo_strip_seconds` (2.5 s) of game time and stays cleared, and restart_run() mid-display clears it | T-040 |
| hud_combo_note_on_landing | through the real main scene, a landing while a ×2+ combo is live shows "landing ended the ×2 combo" under the strip row (T-019 outline treatment, hidden and empty at rest) for 2.5 s of game time, then clears itself and stays cleared; the landing is driven through the REAL `grounding_changed` signal — Main's handler is connected BEFORE `Game.on_grounding_changed`, so the note provably reads the PRE-reset streak (a connect reorder fails the shown leg, which is the load-bearing invariant the scenario keeps covered); a landing with no live combo shows nothing, and restart_run() mid-display clears it | T-079 |
| pause_menu_shows_controls | through the real main scene, the pause panel's Box carries the two recap lines as its last two children (below the buttons) — hidden with the panel at rest, shown by the first `toggle()` (tree paused, both labels visible), hidden again with the panel by the second (tree unpaused); each line carries exactly its constant's key families, matched bi-directionally against `MainGame.HINT_AIR` (W/S, A/D, Space, F) and `HINT_GROUND` (W/S, A/D, Space), so a future constant edit that drops or gains a family fails the gate; and both labels carry the T-019 treatment (14 px, outline 4, black-0.85 outline, white-0.75 fill) | T-099 |
| title_screen_teaches_controls | through the REAL menu scene, a visible ControlsLabel sits under the Footer naming every first-run family AND its printed keycap (W/S pitch · A/D turn · Space flap · F poop · Esc pause — a reword dropping either half of a pair fails), every keycap resolves to a real InputMap action — all seven `flap`/`poop`/`pitch_up`/`pitch_down`/`turn_left`/`turn_right`/`pause` (the divergence guard for the by-design duplicated copy; scene files cannot reference `main.gd`'s HINT_AIR) — and the line carries its own treatment, 15 px white @ 0.7 with NO outline (the T-019 flat dark-navy finding: absence of a local override plus zero effective outline); the same run reads the game-over Hint through a REAL main scene as exactly "same city every run — race your best" with neither "seed" nor "regenerate" left in it | T-039 |
| elder_placement_no_rng | the city records one pure-layout spot per plaza-ring bench and the spawner seats 4 elders on every second bench (0, 2, 4, 6 — 90° apart, on the seat line); regenerating the same seed reproduces the fingerprint, the bench/lamp/bin counts and the spot list byte-identically, a foreign seed still gets its ring, and the elders sit exactly on the chosen spots of a real generated City | T-020 |
| elder_shares_bread_after_hangout | a GROUNDED pigeon parked in an elder's PresenceZone fills trust (~2 in ~2 s); a short walk-about decays it without wiping; back for `trust_needed` seconds the elder relays `bread_shared` exactly once and two ordinary T-005 crumbs (restore 30, hand-placed, respawn-accounted, favor_delta 0 — elder loaves are paid at the share, not owned by the eater, T-114) sit on the pavement within reach in front of the bench; since T-114 the scenario stages `Game.favor` explicitly at setup (the rig would inherit whatever the previous scenario left) and the share asserts the exact spend — favor drops by exactly `elder_loaf_cost × crumbs_per_share`; since T-078 the near arm IS the trust meter — part-raised mid-hangout (0.2 < `_arm_raise` < 0.9) and still creeping up across sampled frames, never above 0 the whole time the pigeon is absent (polled through the away window), and after the share, still parked, it eases back under 0.1 while trust has re-pinned at `trust_needed` — the cooldown-overrides-trust proof | T-020, T-078, T-114 |
| elder_no_bread_airborne | a FLYING pigeon held inside the same PresenceZone for longer than `trust_needed` banks nothing — zero crumbs, zero relays, trust never leaves zero (favor staged explicitly at setup since T-114) | T-020, T-114 |
| elder_cooldown_blocks_second_share | a pigeon hanging out CONTINUOUSLY through the whole `share_cooldown` after a share earns nothing until it expires — then exactly one more share (favor staged explicitly at setup since T-114: enough to fund both shares' spends) | T-020, T-114 |
| pigeon_air_poses_track_flight | wings out in a glide, a wing beat on every real flap impulse (and the beat ends), wings swept back in a dive — the pose mirrors the flight state | T-011 |
| pigeon_ground_poses_track_waddle | grounded settles into the folded stand, waddling flips to the waddle pose, stopping settles back to stand; since T-048 the fold also thins the wing chord — the grounded legs assert the pivots' eased Z scale ≤ 0.5 (default 0.35), a fresh airborne set-up re-opens it to ≥ 0.95, and reset_pose() returns it to exactly 1.0 with both wing pivots' scale.z back at 1.0 (the root-only scale reset never reached them) | T-011, T-048 |
| pigeon_pecks_when_eating | eating a crumb through Main's exact wiring (crumb.eaten → Player.peck) plays the peck — the beak dives down and the overlay ends | T-011 |
| pigeon_realistic_visual | the presentation (T-011's drive() contract unchanged) instances the rigged realistic Blender pigeon — a child scene sourced from `assets/models/pigeon_realistic/pigeon_realistic.glb` (instanced at 2.6× with a −0.292 m drop onto the b6 ground line) carrying MeshInstance3D meshes and an AnimationPlayer with all six sculpt clips (glide/dive/flap/peck/stand/waddle) — and still tracks flight poses on the retained pivots: wings unswept airborne (sweep < 0.3), folded grounded (sweep > 0.7). Replaces the T-107 B6 check and the T-108 static-mesh check | T-108, T-109 |
| city_district_palettes_distinct | every building wears a color from its own district's palette, all four districts appear, the palettes are measurably distinct and the quadrant mapping is pure | T-013 |
| city_facades_fit_floors | one `Visuals/Facade<N>` MultiMesh per floor count actually present in `buildings[]` (floors re-derived per record: `roundi((top − block_slab_height − roof_slab_height) / floor_height)`) and none for a count no building has; per-class `instance_count` equals the class tally; every instance transform equals its building's expected facade box (origin `to_local(center) + UP·(block_slab_height + floors·floor_height·0.5)`, scale `(size.x, floors·floor_height, size.y)` — both footprint axes, within 0.01); each class material reports `get_meta("window_rows") == floors`, values distinct across classes; a forced same-seed rebuild reproduces every class's instance set byte-identically; the fingerprint stays at the cross-version baseline pins (seed 20260928 → 4045370482, seed 424242 → 533171164 — the values moved for T-051's mandated two-axis footprint `_fp` entry, again for T-029's plaza-landmark `_fp` entry, again for T-091's four district-anchor `_fp` entries and again for T-104's four plaza-bin `_fp` x/z entries, each re-derived with a headless `City.generate` probe; pre-T-051: 2492360539 / 2662825400; pre-T-029: 4188136223 / 547420287; pre-T-091: 1006789400 / 3359332191; pre-T-104: 650664268 / 4031380170; T-049 itself drew zero RNG, zero `_fp` entries) | T-049 |
| city_footprints_vary | the roofscape reads as individual volumes, not a waffle grid of equal 7.1 m squares: ≥ 3 distinct footprint `Vector2`s across `buildings[]` (measured 146 of 146 at the M1 seed), every footprint positive and fully inside its lot with the `lot_gap` kept on BOTH axes (`size ≤ (block_size − sidewalk_width·2)·0.5 − lot_gap` = 7.1 m at the defaults, so alleys only widen), and every record's size recomputable within 0.01 from the harness-owned copy of the pure fold (the `_expected_cafe_spot` pattern) — `(bx, bz, qx·2+qz, axis+1)` hashed, folded once with `seed_value`, mapped to [0.78, 1.0], with bx/bz re-derived from the record's block center and the quadrant signs from `lot_offset`; the observed scales spread across the mapped band (measured 0.781–0.998), not degenerate; a forced same-seed rebuild reproduces every size exactly with a self-to-self fingerprint; and the hash touches NO RNG stream — the floor tally, the pinned 104-of-146 awning count and the roof/spot byte counts elsewhere are unchanged | T-051 |
| city_shopfronts_present | every building wears a ground-floor shop band with a door on one of its two street-facing faces plus the seeded awning share (104/146 at the M1 seed), the shopfront palette stays measurably distinct from every district palette, since T-090 the `sign` visual queue holds exactly one cream signboard plaque per building (146 at the M1 seed), each transform recomputed from its building record (`door_face`, `size` — the T-051 per-axis footprint) with the flush convention — the thin 0.08 m axis on the face normal (the awning's convention, shared by the door since T-103: a perpendicular plank fails the per-axis scale compare, origin+euler alone would pass either) — origin 0.05 m proud of the band outset on the `face_out * 0.5` face-distance term, y slab+2.55 spanning slab+2.30 → slab+2.80 (above the door top slab+2.05, clear of the awning underside slab+2.855 and the smallest roofline slab+6.25) — and since T-103 the door-geometry leg: the `door` visual queue holds exactly one door per building (146 at the M1 seed, paired 1:1 in order), every queued transform decomposes as a pure scale with no rotation (per `_box_xf`) whose ≈0.1 m thin axis sits ON the door-face normal and whose 0.95 m width runs along the wall, read off the raw basis columns per building from its `door_face` record AND matched against the `_expected_door` re-derivation (origin `to_local(center) + normal·(face_out·0.5 + 0.12 + 0.01)`, y slab+1.025, scale `(0.1, 2.05, 0.95)` on ±x faces / `(0.95, 2.05, 0.1)` on ±z — the landed inverted swap kept origin and euler and only swapped the per-axis scales, so a fin fails both compares) | T-017, T-090, T-103 |
| city_shopfronts_deterministic | regenerating the same seed reproduces every shop color, door face and awning flag exactly — and since T-090 the sign plaque queue and since T-103 the fixed door transform queue byte-identically (`_spots_equal` exact compare across a forced rebuild) | T-017, T-090, T-103 |
| city_cafe_tables_present | every awninged building gets exactly one sidewalk cafe table on a pure-layout spot recomputable from its building record (104 at the M1 seed, non-awninged buildings none), same-seed regeneration reproduces the spot list byte-identically, and a spawner rig seats the furniture exactly on the spots — since T-094 a batch, not per-table nodes: one MultiMeshInstance3D per visual key (the shirt-tinted torso/arm keys carry per-instance colors, read back as the tourist-palette shirt by spot+seat index) plus two merged static bodies (tables layer 1 `world`, sitters collision-layer value 4 — the retired scenes' value — mask 0 both, one positioned shape per piece) with 1-2 sitters per table by the even/odd index rule (104 tables → 156); the spots hold the street clearances (center ≥ 0.5 m inside the 10.9 m loop line, ≥ 1.0 m off the block's PAVEMENT bread spots — since T-112 the pool read skips the kind-TABLE entries, so a table's own tabletop crumb riding 0.25 m from its own spot is the feature, not a failure, and the leg reads today's exact pre-T-112 pool: probe-verified min 2.704 m at the M1 seed / 2.626 m at seed 424242, 0 trips — ≥ 1.2 m edge-to-edge off the door line), and a grounded pigeon can perch beside a table — whose solid top stops the waddle dead | T-031, T-094, T-112 |
| city_cafe_tables_present | every awninged building gets exactly one sidewalk cafe table on a pure-layout spot recomputable from its building record (104 at the M1 seed, non-awninged buildings none), same-seed regeneration reproduces the spot list byte-identically, a spawner rig seats tables-with-sitters exactly on the spots (sitters layer-3 `npc` static bodies, 1-2 per table by the even/odd index rule — 104 tables → 156, tourist-palette shirts by index), the spots hold the street clearances (center ≥ 0.5 m inside the 10.9 m loop line, ≥ 1.0 m off the block's bread spots, ≥ 1.2 m edge-to-edge off the door line), and a grounded pigeon can perch beside a table — whose solid top stops the waddle dead | T-031 |
| city_roofs_inhabited | every building carries 1-3 rooftop props fully on its roof (since T-051 ≥ 0.6 m from every edge — re-derived for the varying footprints: 0.25·5.54 − 0.7 ≈ 0.685 m at the 0.78-scaled minimum — centers at the exact corner-relative ±0.25·footprint inset per axis, ≥ 1.9 m from the footprint center at the smallest footprint so the exact-center `city_roof_landable` drop stays ≥ 0.96 m clear of the worst prop (the tank's 0.99 m half-diagonal); since T-093 one layer-1 shape each under the Props group body — exactly five group bodies under `Static/` (Ground/Roads/Blocks/Buildings/Props), all layer 1 mask 0, every collider a shape child) and exactly one roof crumb spot in the never-propped (+,+) quadrant at roof-top + 0.06, so `bread_spots` grows by exactly the building count (533 → 679 at the M1 seed; since T-091 the four district-anchor cap crumbs ride the same y > 1.0 population, 679 → 683; since T-112 the city-wide total pin carries one more `_city.cafe_spots.size()` term — one TABLE spot per awninged building riding its own cafe table, 683 → 787, with the y > 1.0 roof-spot population untouched because tabletops sit at slab + 0.78 < 1.0 — and the Props-body high-shape ledger — `roof_props.size() + 3 × anchors.size()` — carrying `_city.anchors.size()` terms); a crumb instantiated at a low roof's spot is eaten by a dropped-then-waddling pigeon through the ordinary eaten path (no BreadSpawner change), a drop onto the low roof's first prop settles grounded on its top, and a real same-seed rebuild reproduces `roof_props` and the roof spots byte-identically (zero RNG, zero new `_fp` entries) | T-032, T-093, T-091, T-112 |
| bread_distribution_weighted | the T-112 weighted spread: on a real generated City + a `BreadSpawner` rig at the shipped target 40, `_populate` opens the class quotas exactly — 36 TABLE / 3 GROUND / 1 ROOF at the M1 seed AND at seed 424242 — with every crumb's `global_position` matching its spot's `to_global` (< 0.01) and the distribution recomputed through the scenario's own kind-array read (`City.bread_spot_kinds[crumb.spot_index]`), never spawner internals; city-side `bread_spot_kinds` stays index-aligned with `bread_spots` and the M1 class tally is exact (GROUND 533 = 392 ring + 141 bench, ROOF 150 = 146 + 4 anchors, TABLE 104 = the awninged buildings — 787 total), every TABLE spot exactly at the tabletop law recomputed from the building record (`cafe_spot.origin + basis.x·0.25 + UP·0.78`, XZ inside the 0.9 m top, y = slab + 0.78); a force-rebuild re-populates the identical crumb position multiset (sorted byte-identical compare) with the fingerprint pin holding; 10 eaten TABLE crumbs (the `crumbs_respawn` path) refill TABLE to quota within one `respawn_interval` with GROUND and ROOF untouched; the overflow safety net pinned by a synthetic shrink — the TABLE class cut to 10 free spots (arrays reassigned on the city object, then re-populate) spills its deficit to GROUND (3 + 26 = 29) while ROOF stays capped at its quota (ROOF never exceeds 1 live crumb in any leg — "rare" is a ceiling, not a floor); and a tabletop crumb is an ordinary reachable crumb: the pigeon drops onto the tabletop beside it (the bench-landing geometry), settles grounded at top-face height and feeds +30 through the Main wiring (`crumb_eaten` → Hunger.eat; the 0.9 m top sits inside the crumb's 1.4 m grounded eat reach, so the feed can fire on the settle frame — the waddle-in drive is held, its timing not pinned) | T-112 |
| city_crosswalks_present | the `Visuals/Crosswalk` MultiMesh carries exactly 2,240 bars with default exports (224 bands × 10 — every unblocked intersection approach, the 32 outward approaches of the outer ring skipped because their band would leave the asphalt), every bar is an axis-aligned 2.4 along-road × 0.5 across × 0.01 box at its dash-family height (horizontal roads at `road_slab_height`, vertical at `road_slab_height + 0.005`), every bar center lies ≥ 5.0 m from every intersection node in XZ (the 3.5 m corner-cut swing area stays clear) and stays on its approach road's asphalt (the across-extent inside the road edges, the along-coordinate inside the city), the bar multiset matches an independent recomputation (per unblocked approach one 2.4 m-deep band centered 6.2 m out on the centerline, tiled by 10 bars running WITH the road, repeating ACROSS it at a 1.0 m pitch — the T-102 re-orientation of T-069's transverse piano keys, red-before/green-after: the un-flipped builder fails this scenario's count/geometry/asphalt/placement asserts), a forced same-seed rebuild reproduces all transforms byte-identically with the fingerprint unchanged at the cross-version pin (seed 20260928 → 4045370482 — the value moved for T-051's mandated two-axis footprint `_fp` entry, again for T-029's plaza-landmark `_fp` entry, again for T-091's four district-anchor `_fp` entries and again for T-104's four plaza-bin `_fp` x/z entries, each re-derived with a headless `City.generate` probe; pre-T-051 it was 2492360539, pre-T-029 4188136223, pre-T-091 1006789400, pre-T-104 650664268; T-069/T-102 themselves drew zero RNG, zero `_fp` entries), and no StaticBody3D exists under `Visuals` — the paint is visual-only (T-017) | T-069, T-102 |
| city_apron_rim_present | the city-edge rim is pure layout: exactly 4 hedge bands centered on the boundary line (|x| or |z| = city_span·0.5 + 0.5, oriented (city_span, 1.2, 0.8) size) and 2·4·(blocks_per_side+1) = 64 trees — two flanking each street exit at ±6.5 m along the side axis (multiset-matched against an independent recomputation), trunks 1.1 m up on the apron and crowns 3.3 m up over every tree spot; the hedge/crown green holds ≥ 0.15 Euclidean RGB from COLOR_GRASS (measured 0.188 / 0.195, printed informationally); zero CollisionObject3D under the Visuals root; a forced same-seed rebuild reproduces both spot lists byte-identically with the fingerprint still equal to the cross-version pins (seed 20260928 → 4045370482, seed 424242 → 533171164 — re-derived for T-051's mandated two-axis footprint `_fp` entry, again for T-029's plaza-landmark `_fp` entry, again for T-091's four district-anchor `_fp` entries and again for T-104's four plaza-bin `_fp` x/z entries with a headless `City.generate` probe; pre-T-051: 2492360539 / 2662825400; pre-T-029: 4188136223 / 547420287; pre-T-091: 1006789400 / 3359332191; pre-T-104: 650664268 / 4031380170; zero RNG draws, zero `_fp` entries) | T-088 (commit 1) |
| city_horizon_skyline | the distant skyline is a deterministic hash chain: `Skyline`/`SkylineTall` MultiMesh nodes exist under `Visuals` with 64 total instances ([40, 80] gated) of which 6 are landmark towers ([2, 8] gated); every origin's XZ radius sits in the band recomputed from the default exports, 192–347 m (beyond the blocks, strictly inside the ±367 m apron box including the tower's own ≤ 9 m half-width), box origins at height/2 over the y 0 apron; every scale.y ∈ [15, 60] and XZ extents ∈ [6, 18] m; zero CollisionObject3D under the Visuals root; a forced same-seed rebuild reproduces both instance sets byte-identically; the fingerprint still equals the cross-version pins and a foreign seed changes both the fingerprint and the tall-count split (6 → 3 at seed 424242) — zero draws from any RNG stream, zero `_fp` entries | T-088 (commit 2) |
| city_park_trees_present | every park block carries exactly four trees at the fixed (±5, ±5) offsets — 8 = 4 × the reported park count (2) at the M1 seed off the `TreeTrunk`/`TreeCrown` MultiMesh queues, the park blocks recomputed independently from the slab queue (exactly the slabs wearing COLOR_PARK), every trunk (1.1 m up on the slab) and crown (3.3 m up, bottom at trunk top) over exactly one expected offset and fully inside its block (6.3 m < the 11 m half footprint), the crown green (the rim's COLOR_RIM_CROWN) ≥ 0.15 Euclidean RGB from COLOR_PARK (measured 0.282, printed informationally), every tree ≥ 2.0 m XZ from every `bread_spots` entry (measured worst 4.98 m — bench seats included), the constants-level ≥ 1.5 m lamp/bin arithmetic pinned (4.24 m worst center-to-center − 1.84 m crown half-diagonal − 0.9 m worst prop half-extent = 1.50 m margin), zero CollisionObject3D under the Visuals root, a forced same-seed rebuild reproducing both queues byte-identically, a foreign seed keeping the 4 × parks law (2 parks → 3 at seed 424242), and the fingerprint still equal to the cross-version pins (seed 20260928 → 4045370482, seed 424242 → 533171164 — re-derived for T-051's mandated two-axis footprint `_fp` entry, again for T-029's plaza-landmark `_fp` entry, again for T-091's four district-anchor `_fp` entries and again for T-104's four plaza-bin `_fp` x/z entries with a headless `City.generate` probe; pre-T-051: 2492360539 / 2662825400; pre-T-029: 4188136223 / 547420287; pre-T-091: 1006789400 / 3359332191; pre-T-104: 650664268 / 4031380170; zero RNG draws, zero `_fp` entries) | T-030 |
| city_plaza_landmark | exactly one landmark — a bronze pigeon on a limestone plinth — stands at the plaza center every run: the plinth/figure MultiMesh boxes all sit within 2.5 m of the plaza center, the whole footprint inside the 12 m spawn-clear radius, total top ≈ 5.07 m (≤ the 5.5 m bar, under `max_roof_height` 20 and the 23 m cruise floor), the stone holds ≥ 0.15 Euclidean RGB from the pale plaza slab with both new colors equal to their constants, ONE layer-1 `Props` box caps the plinth at `block_slab_height + 2.0` with nothing solid higher in the center column (the figure is visual-only, the T-017 decision), a forced same-seed rebuild reproduces every landmark transform byte-identically (zero RNG draws of any stream, one `_fp` entry — the cross-build pins moved once more for it, re-derived with a headless `City.generate` probe), a drop onto the cap settles grounded at cap height and a flap takes off again (the bench template), and a flap-assisted straight pass along x THROUGH the plaza center crosses the whole city at min y > 20 m without touching anything (the `city_street_flyover` template) | T-029 |
| city_plaza_props_clear | the spawn plaza's props never interpenetrate: every `CollisionShape3D` under `Static/Props` (one body per group, T-093) whose XZ center lies within 16 m of `_plaza_center` — census-pinned to exactly the plaza's 17 shapes: 8 benches, 4 bins at (±7.0, ±7.0) (r ≈ 9.9 m, radially outside the 8 m bench ring since T-104), 4 corner lamps, 1 plinth — is checked pairwise with no intersecting pair: yawed-box SAT over both boxes' face normals for `BoxShape3D` (the reported gap the max per-axis separation — a lower bound of the true distance, exact for the face-to-corner bin/bench case), circle-vs-OBB (closest point on the box) and circle-circle for the lamps' `CylinderShape3D`, Y-range overlap required, a 0.01 m touch tolerated; red-before/green-after held — the pre-fix tree (bins at ±5.5) fails on exactly the four diagonal bench×bin pairs at 0.64 m penetration, identical at both seeds, all other pairs clear; the intent pins ride along: every bin ≥ 0.3 m clear of every bench collider (measured 0.611 m — inside the research's 0.3–1 m bin-beside-bench band) and every bin on the slab (per-axis |offset| + the 0.389 m half-diagonal ≤ 11.0 m); the audit holds at the default seed AND seed 424242 (the plaza layout is RNG-free) and a forced same-seed rebuild still reproduces the fingerprint (T-104 moved the four bin `_fp` x/z entries — the cross-version pins re-derived with a headless `City.generate` probe: 650664268/4031380170 → 4045370482/533171164) | T-104 |
| city_district_anchors_present | exactly one tall clock post per district quadrant stands at the pinned blocks' alley-cross centers (1,1)/(5,1)/(1,5)/(5,5), one record per district in `anchors[]` ({center, district, top, cap_top}), `top` the harness's own tier-constant sum (1.0 + 13.6 + 2.2 + 0.5 = 17.3 m above the slab; cap_top 17.42 m global) under `max_roof_height`; the do-not-fold rule newly guarded — `report.max_roof_height` equals `max(buildings[].top) − block_slab_height` (18.25 at the M1 seed), the anchors never feed `_max_roof`; the 1.4 m plinth's per-axis daylight re-derived per seed from `buildings[]` (worst 0.024 m at the M1 seed, 0.0016 m at seed 424242 — flush, never overlapping, so a bad seed fails loudly), no bread spot but the anchor's own crumb within 5 m XZ (measured worst ~8.3 m) and the tourist-loop / bread-ring / bench-line / park-crown distances held by constants arithmetic; the cap crumb sits in `bread_spots` at cap_top + 0.06 (17.48 m global) and `last_report.plaza_clear` stays true; the four tier MultiMesh queues hold 4 instances each over the anchor centers at the tier scales with every head wearing one of the four districts' first palette colors and all four present; one layer-1 `Props` box per tier under the shared group body, exactly 3 per anchor above the y 5.0 window (the plinth sits below it); a forced same-seed rebuild reproduces `anchors` and `bread_spots` byte-identically, the foreign seed raises the same four posts, a drop onto a cap settles grounded at cap_top + 0.3 and the anchor crumb is an ordinary crumb (+30 through Hunger) — zero RNG of any stream, one `_fp` entry per anchor (the four cross-version pins re-derived for it) | T-091 |
| juice_feather_poofs_on_hard_flap | a fully-rested flap poofs feathers; a re-flap inside the throttle window doesn't spam another | T-013 |
| juice_dust_puff_on_landing | a gentle glide touchdown kicks a dust puff at the feet, which cleans itself up | T-013 |
| juice_landing_shake_decays | a touchdown kicks a small camera shake (never full trauma) that moves the lens and decays to dead still | T-013 |
| hit_shake_and_score_pulse | through the real main scene, a combo escalation shakes the chase camera, pulses the HUD score line and shows the ×2 — both settle back; the sun is warm and capped at ≤ 1.15 energy | T-013 |
| audio_buses_and_assets | the Master/SFX/Ambience bus mix exists with the ambience bus quieter than SFX, every ticketed sound loads as a real stream, and both ambience beds are flagged to loop forever | T-012 |
| audio_boots_muted | the game boots MUTED (T-101) — the real autoload path muted Master in the harness process itself at boot, and the opt-in contract holds: PIGEON_SOUND=1 opts in, the pilot's PIGEON_MUTE=1 wins over `--sound`, the `--sound` user arg opts in, and no opt-in stays silent | T-101 |
| sfx_flap_effort_fires | a takeoff flap whooshes without the effort beat; a flap mid-climb adds the strained wing-beat; a flap while falling stays quiet | T-012 |
| sfx_peck_plays_on_eat | a grounded pigeon eating a crumb through Main's wiring plays exactly one bread peck | T-012 |
| sfx_splat_yelp_panic_honk | a real lobbed splat plays the splat plus its tourist's yelp, the indignant shout joins the fist shake ~1.8 s later, and a duck-typed car hit blasts the horn | T-012 |
| ambience_loops_under_game | main.tscn starts both ambience beds on the Ambience bus, start_ambience() is idempotent across restarts and the bed survives the scene teardown | T-012 |
| density_cpu_budget | the real main scene at full density (18 tourists + 36 cars asserted) keeps the calibrated headless CPU budget — median wall-time of three 100-frame windows under --fixed-fps 60 | T-018 |
| off_world_fall_returns_home | a fall below the off-world guard line (past any floor) fires the reset exactly once — counted twice since T-095, through the `off_world_resets` counter AND a local counter wired to the new `off_world_reset` signal, each exactly once across the whole window — snaps the pigeon home to the respawn corridor and lands it there within ~2 s, stays parked home with no second fire over the following ~2 s, and the hunger clock keeps draining straight through the reset | T-036, T-095 |
| off_world_return_beat | the PRESENTED return through the real main scene (instanced-Main pattern, own space): the guard fires exactly once — counter AND signal, the signal's `from` equal to the void departure position — and Main answers with the full beat: a `juice_effects` feather poof at `from` on the reset frame, the warm HUD fade up right after the reset and fully gone (≤ 0.01) within ~1 s of game time, the chase camera within ~1.5 m of pigeon + UP × 1.4 on the first frame after the reset (the snap, not a lerp), the "home again — mind the edge" note shown then self-expired, grounded on the respawn corridor within ~2 s, no second fire across a further ~2 s, Game.hunger drained > 0.2 across the window; a second fire re-runs the beat and restart_run() mid-note clears note and fade unpaused | T-087 |
| edge_nudge_turns_home | reset 300 m past the city edge (417 m from the home center, 50 m past the 367 m apron — mid-ramp), nose dead away from home (the bearing sine's zero), hands off for 3 s: the heading rotates ≥ 30° back toward home and y never drops below 0, with the T-042 guard silent through the window (from y 30 the softened gravity sinks ~10 m, far above −5 — the heading assert is what bites; measured landed: turned 54.2°, end bearing 127.7°, min y 26.5 m, resets 0; nudge-disabled probe on the same scenario — the old tree's by-construction behavior: turned 0.0°, bearing 180.0°, FAIL exactly on the heading arm). Only this scenario wires `home_center`/`home_radius` — every other runs with the nudge disabled (radius 0.0) | T-023 |
| touch_layer_desktop_inert | the desktop/headless path is byte-unchanged (T-119): the touch layer is HIDDEN (no touchscreen) and inert — a synthetic contact at the stick spot moves nothing — the safe-area layout is a no-op (zero offsets on the touch SafeArea AND the HUD layer, the T-087 return fade un-expanded, the StatsLabel still at its scene spot with the HungerBar beside it), and the InputMap's non-builtin action set reads EXACTLY the shipped eleven (`flap`/`poop`/`pitch_up`/`pitch_down`/`turn_left`/`turn_right`/`boost`/`pause`/`restart`/`to_menu`/`quit`) — zero new actions, live-read so a smuggled-in action fails the same night it lands. Probed facts the touch block leans on (ticket T-119): the stub headless window is 64×64 and the GUI drops contacts outside it, so the touch scenarios size the window to the desktop default 1280×720 first (restored after — every other scenario keeps today's conditions); on a sized window the real pipeline (`Input.parse_input_event` + `flush_buffered_events`) delivers GUI touches and TouchScreenButton actions but a synthetic screen touch does NOT emulate mouse, so the ordinary Pause button is driven with the synthetic mouse click a tap produces on-device (`emulate_mouse_from_touch` is the project default); and `Input.action_press` strength bypasses the InputMap deadzone (0.2 reads 0.2) — what the stick feeds IS what the player polls | T-119 |
| touch_stick_drives_action_axes | a synthetic screen-drag on the T-119 joystick steers through the SAME action axes the player polls: a 40 %-radius deflection reads clearly non-zero turn with the pitch pair exactly at rest (the deadzone trap — gentle deflections must not read zero), strictly weaker than full deflection, which reads > 0.9; and the pigeon itself flies the held drag — 60 frames of full-left stick bank the body (basis.x.y > 0.2) and yaw > 0.3 rad, 40 frames of full-up stick raise the nose > 0.15, and lifting the finger returns every axis to exactly zero | T-119 |
| touch_stick_rest_reads_exactly_zero | the stick-at-rest contract that keeps the T-082 trim arm alive: never-touched reads exactly 0.0 on all four steering actions; a held full-up drag then finger-up returns every action to EXACTLY 0.0 (strength and both axis compositions); and the end-to-end proof — settled cruise, an 8-frame stick pitch-up (the keyboard scenario's own entry hold), released by lifting the finger — shows the nose easing back toward the flow over 90 hands-off frames at the same `HSO_NOSE_TRAVEL_BAR` `hands_off_glide_trims` pins (a stick that leaked strength would freeze the trim here) | T-119 |
| touch_buttons_fire_real_actions | the Flap and Poop TouchScreenButtons fire the REAL actions: a synthetic screen touch on Flap produces exactly one flapped impulse through the player's own polled `_flap`, and one on Poop drops a real, valid, finite-velocity Poop through the polled `_try_poop` (counted by the harness's `pooped` listener) — no new input path exists to verify | T-119 |
| touch_pause_button_toggles_real_pause | the ordinary Pause button pauses through the REAL PauseMenu of an instanced main scene: the tap's emulated click (driven headless as the synthetic mouse click the tap produces on-device) opens the real overlay — tree frozen, `is_open` — and a tap on the panel's own Resume button unpauses; the full touch pause loop, no keyboard involved | T-119 |
| touch_multitouch_steer_and_flap | overlapping synthetic contacts steer + flap at once: finger 0 holds a full-left stick drag while finger 1 lands on Flap — the turn axis stays live (> 0.9) THROUGH the second contact, a real flap impulse fires in the same window, the pigeon yaws > 0.3 rad under both, and lifting both fingers returns every axis to exactly zero | T-119 |

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
clear of buildings — and beyond `HOME_RADIUS` (40 m, tests/autoplay.gd — the
pilot's own homing constant, refreshed from a stale "60 m" prose by T-023) from
the plaza it steers home; that arc stays hundreds of metres inside T-023's 367 m
apron radius, so the flight-model edge nudge never engages in a pilot run.
From 11 s in
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
camera-shake trauma (`shake_peak`, the never-nauseating evidence). Since T-020
the plaza benches seat four park elders and the DONE line reports how many
bread shares the run earned (`shares` — the pilot's ground visit can land
inside an elder's PresenceZone; the count is reported, not gated, since it
depends on where the visit parks; since T-114 the share also spends the
elders' favor, so a broke pilot honestly reports 0, and the eaten count may
include tailgate crumbs). Saves a
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

- [x] Boots straight into the playable scene; Debugger → Errors tab is empty
- [x] No warning spam on boot or during ~30 s of play

For interactive agent play sessions — including several running at once — use
the pilot harness (`python tests/tools/pilot.py start|send|state|shot|stop …`,
sessions isolated under `.captures/session_<id>/`); see AGENTS.md →
"Agent play: pilot harness" (T-014).

## Web export (T-118 — run when touching export/platform config)

The phone target is a **single-threaded web build** (`docs/tickets/T-118-web-safari-build.md`):
`project.godot` carries the per-platform `rendering_method.web = gl_compatibility`
override (web supports only Compatibility; desktop keeps forward_plus — no
`.desktop` value exists), the `canvas_items`/`expand` stretch (a no-op at the
desktop's default 1280×720, so every Gate 1b HUD read stays valid), and the
committed `export_presets.cfg` Web preset has **Variant → Thread Support OFF** —
the load-bearing switch: single-threaded builds avoid the SharedArrayBuffer
requirement that breaks iOS Safari and need no COOP/COEP hosting headers.

Export templates must be installed once (the editor's
Editor → Manage Export Templates…, or the `.tpz` from godotengine.org unpacked
into `%APPDATA%/Godot/export_templates/4.7.2.stable/`). Then:

```bash
mkdir -p build/web   # the exporter fails with "Target folder does not exist" otherwise
godot --headless --path . --export-release "Web" build/web/index.html
```

**Pass =** exit 0 and `build/web/` contains `index.html`, `index.js`,
`index.wasm` and `index.pck` (`build/` is gitignored — never commit it).
Single-threaded sanity check: `grep -c SharedArrayBuffer build/web/index.wasm`
reads 0 and `index.js` carries the `nothreads` markers — a threaded build
would fail both and break iOS Safari.
Re-run after any change to the `[display]`/`[rendering]` settings, the export
preset, or before an owner hosting pass. Hosting is owner-run: the basement
NixOS box — Caddy `file_server` rooted at `/srv/games`, so the game lives at
`games.matthews.mx/pigeon-simulator/` (decided 2026-10-15; the original
Cloudflare Pages call was shelved). Only build artifacts are published, never
the source repo. Deploy:

```bash
tools/deploy-web.sh              # build → upload → publish → verify
tools/deploy-web.sh --first      # one-time: apply the Caddy vhost (done 2026-10-15)
SKIP_BUILD=1 tools/deploy-web.sh # redeploy the existing build/web
```

Credentials come from the untracked `.env.deploy` at the repo root (SSH
host/user/key, plus the sudo password for the root steps; untracked by git
twice over — a `.gitignore` entry plus a `.git/info/exclude` entry;
`git check-ignore -v .env.deploy` proves it). Preconditions: the
`games.matthews.mx` A record must resolve (same public IP as
`jellyfin.matthews.mx`) or verification fails loudly — `DEPLOY_ALLOW_NO_DNS=1`
stages ahead of DNS; `--first` aborts unless the /etc-vs-source NixOS diff is
exactly the games vhost block. Gotchas recorded on the first run
(2026-10-15): the Caddy NixOS module has **no `root` option on a virtualHost**
— the static root belongs in `extraConfig` as `root * /srv/games`; and a bare
`go=` directive in rsync's `--chmod` applies to directories too (strips the
traverse bit) — the publish leg pins 755/644 explicitly so the `caddy` user
can traverse and read. Desktop-browser and iPhone passes live in the Gate 3
checklist below.

## Gate 3 — Manual playtest (run the full list before closing any ticket)

**Bulk closure (owner call, 2026-10-13):** the owner reviewed the ledger after the
2026-10-12 hands-on run ("playtesting is in a fairly good spot currently") and crossed
off every line EXCEPT T-115's and T-116's, which stay open for a targeted double-check
(the victory ending's feel and the new favor meter + win-rule copy) — including the
unprefixed F5 boot/smoke lines in this section's preamble and tail, all covered by the
same recent sessions. The `[x]` marks from that pass carry no per-line notes by
design — the blanket judgement IS the record; re-open any line a future regression
re-raises.

**The game boots muted since T-101.** A playtest that needs to HEAR the game opts in
explicitly: `godot --path . -- --sound` (the flag after `--`), or `PIGEON_SOUND=1`, or the
pilot harness with `--sound`.

Keep this table in sync with `project.godot` and `README.md`:

| Input | Action |
| ----- | ------ |
| W / S | pitch up / down · waddle fwd / back while grounded |
| A / D | turn left / right · turn while waddling |
| Space | flap · takes off when grounded · starts a run from the title screen · fly again on the score screen (T-010) |
| F | poop — lobs a splat dropping while airborne (T-006) · a direct hit panics a tourist (T-007) or honks a car for 30 pts (T-008) |
| Shift | boost *(not implemented)* |
| Esc | pause — everything freezes; Esc again resumes (T-010) · does nothing on the title screen (T-097) |
| R | restart the run — from the pause menu or the score screen (T-010) |
| M | back to the title screen — from the pause menu or the score screen (T-010) |
| Q | quit the game — from the pause menu or the title screen (T-010) |
| Touch (phone only) | left on-screen stick steers — up/down pitch, left/right turn, the W/S/A/D actions with analog strength · on-screen FLAP / POOP buttons (Space / F) · small Pause button (Esc) · auto-shows on touch devices; desktop preview: launch with `PIGEON_TOUCH=1` (T-119) |

Playtest checklist (grows as tickets land):

- [x] Pigeon falls under gravity, flaps with Space, steers with A/D and W/S
- [x] (T-001) Paced flaps climb and sustain altitude; mashed flaps are noticeably weaker
- [x] (T-001) Dive → pull-up visibly trades height for speed and back
- [x] (T-001) Turns bank and feel weighty; stall drop and recovery read clearly
- [x] (T-001) Landings at low speed slide to a stop without bouncing
- [x] (T-002) Camera never clips ground or buildings when landing or hugging walls
- [x] (T-002) No visible jitter during fast turns and dives; FOV kick noticeable but not nauseating
- [x] (T-002) The pigeon never leaves the frame at max speed
- [x] (T-044) Side-by-side with the old pinned kick (untouched tree vs landed, same cruise state), at 20+ m/s the bird keeps a readable silhouette for landing judgement while the ground rush still sells the speed [screenshot]
- [x] (T-044) The shorter fast arm (5.8 m) never feels cramped when it pulls in low near roofs or the pavement
- [x] (T-003) A gentle glide touchdown settles into the waddle and the HUD hint swaps to the grounded controls
- [x] (T-003) Waddling is slow and comedic; A/D turns in place; Space takes off again
- [x] (T-003) A steep fast dive into the pavement skids to a stop — no crash, no falling through the world
- [x] (T-003) Landing and taking off on a roof and a bench works the same as on the pavement
- [x] (T-021) A trim-speed touchdown on the pavement or a bench sticks on contact — the pose folds and the HUD hint swaps the frame the feet touch, no ghost-slide past the touch point
- [x] (T-021) A deliberately hot, steep dive still reads as a comedic skid to near rest — not a soft mid-slide settle
- [x] (T-022) Holding pitch-up near the ground reads as braking into a nose-high sink, not ballooning into a rocket climb [screenshot]
- [x] (T-022) A speed approach to a bench or roof stays controllable through touchdown with the flare — pitch-up bleeds the approach speed without stranding the pigeon in a climb
- [x] (T-083) Holding W can no longer park the nose at or past vertical; three modest flare taps visibly cap out instead of stacking into a balloon; steep dive entry (S) still feels full-authority; and pitching down out of a nose-high flop still recovers without feeling dead
- [x] (T-082) Releasing W/S mid-glide settles the nose onto the flight path within about 1–2 s — a hands-off glide keeps flying toward its aim instead of holding a frozen deck angle — and slow-speed handling does not feel rubber-banded (reviewer sign-off 2026-10-02)
- [x] (T-081) Releasing the stick in a slow, nose-high mush reads as the nose heaving over into a sink and a dive — not a hover, and not a two-minute drift off the map
- [x] (T-106) Fly a loop — pitch-up held through the top — and confirm roll input pushes the roll BOTH ways with equal authority afterward, no persistent cant remains in straight flight, and the chase camera reads the recovery (accepted by reviewer sign-off 2026-10-02)
- [x] (T-106) Land after aggressive maneuvering and confirm the bird stands square on the pavement — no skew — through the waddle (accepted by reviewer sign-off 2026-10-02)
- [x] (T-004) The city reads as a street grid from the air — roads with lane marks, sidewalks, varied facades, flat roofs, benches/lamps/bins
- [x] (T-004) Flying end-to-end along streets and between roofs never clips through a building
- [x] (T-004) Roofs, sidewalks and the spawn plaza are landable and walkable in a normal run
- [x] (T-004) Restarting the game twice regenerates the identical city
- [x] (T-004) Flying across the whole city holds ~60 fps on the dev machine
- [x] (T-005) The hunger bar ticks down while flying — visibly faster while flapping, slower while resting
- [x] (T-005) Landing near crumbs and waddling into them pecks them up and restores a chunk of the bar
- [x] (T-005) Flying low over crumbs does nothing — only grounded contact feeds
- [x] (T-005) Hunger reaching zero ends the run — the game-over score screen opens (T-010), exactly once per run
- [x] (T-005) Eaten crumbs come back somewhere else within a few seconds
- [x] (T-006) Tapping F in flight lobs a dropping that visibly inherits momentum and arcs down
- [x] (T-006) Droppings splat on streets, walls and roofs, stick to the surface, and fade out after a few seconds
- [x] (T-006) Mashing F while flying yields about one dropping per second — no stream
- [x] (T-006) F does nothing while grounded — the dropping only exists in the air
- [x] (T-077) The F readiness glyph beside the hint line reads at a glance over pavement and sky, and the dim (cooling) state is distinguishable from the lit one [screenshot]
- [x] (T-086) A freshly released drop reads as a distinct bright dot below the bird, against sunlit grass AND against shaded street, for ~2 s of fall [screenshot]
- [x] (T-086) The enlarged ball does not read as a premature hit during the pre-contact moment [screenshot]
- [x] (T-105) At cruise the reticle reads as ring + center dot + four cardinal ticks (not a bare circle) against road AND grass, and the splat lands inside the ring at play distances — the damped agreement is the point; the old "splat short of the ring" note must not reproduce (retires the T-046 line, whose undamped-bias judgement this reticle's march fixes; accepted by reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-105) The live→frozen→live handover reads correctly in real flight: the mark follows the glide's intent before the press, holds the released point while the ball falls, and resumes following after the splat; the cooldown dim (0.25) is distinguishable from the live full state at a glance, and grounded hides the mark entirely (judgeable in the same session as T-040's pending combo-strip lines — dive, press, watch the hold; accepted by reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-110) The live reticle at 30 Hz reads as continuously attached to the glide at cruise and leads smoothly through a shallow dive (no discrete hops), with the frozen pin and cooldown dim behaving exactly as at 10 Hz — hands-on owner run 2026-10-10: "much better, let's keep that"
- [x] (T-007) 15–20 tourists stroll the sidewalks and plaza in loose groups and read as believable walkers
- [x] (T-007) A direct splat panics its tourist — sprints away, arms up, red flush, fist shake — and Score ticks up
- [x] (T-007) Manual skill run: splat at least 3 tourists and buzz 3 more; watch one full panic cycle (sprint, fist shake, stroll resumes) through to the tourist eventually recycling
- [x] (T-007) A close fast flyby makes nearby tourists flinch (a quick duck) without full panic
- [x] (T-007) At full density the framerate holds; tourists only ever appear/disappear well away from the camera
- [x] (T-060) A drop released ~15 m early ahead of a strolling tourist now connects in normal flight — splat, panic and score fire off a modest lead, not a lucky graze (the 0.30 collider; cars get proportionally easier)
- [x] (T-060) Airborne near pedestrians the hint slot teaches the lead ("F poop · release ~15 m early to lead them") and hands the slot back cleanly — plain air hint out of coach_range and after the run's first tourist splat, ground hint when landed [screenshot]
- [x] (T-008) Parked cars line the curbs and traffic loops the blocks; cars never overlap or gridlock at corners
- [x] (T-008) A splat on a parked car and on a moving car both honk (body flash) and tick the score by 30
- [x] (T-008) Cars read as visibly bigger, easier targets than tourists; a moving car is hittable with modest lead
- [x] (T-008) Follow one car for a full block circuit — it keeps looping normally after being splatted
- [x] (T-089) Standing still for a minute never parks the whole fleet; cars keep flowing past a stationary pigeon
- [x] (T-113) From a cruise pass, a group of visitors reads as a black-and-gold cluster against sidewalk/plaza/asphalt; a superfan is spottable in the same frame but clearly the odd one out; civilians never read as visitors at speed [screenshot]
- [x] (T-113) Visitor cars read from the air as team-color bodies with an up-flying flag — a color mass in the road rows, the `alabama-stands.jpg`/`meadowlands-aerial.jpg` effect — with no lettering or logos anywhere [screenshot]
- [x] (T-113) The visitors read as a goofy nuisance (foam fingers, painted cars), not a hated enemy; the superfan's rarity feels right — rare enough to never be splatted by accident, common enough to be findable — via the share knobs' defaults
- [x] (T-114) The favor readout teaches at flight speed: a visitor-car splat jumps the balance with the gold +6 note, a civilian splat shows the red −2, a tabletop steal shows −1 — cause and effect readable without a tutorial [screenshot]
- [x] (T-114) A broke elder hangout reads as "they're holding out" (arm up, no bread, meter at zero) rather than as a bug; if it reads as a bug, the pre-named fallback (broke routes through the arm's cooldown clause) is forged as its own follow-up ticket, not absorbed here
- [x] (T-114) The tailgate steal reads as a cheeky heist — a gold-lidded cooler beside a painted visitor car with a crumb at the gutter, not buried into a curb, a car, or a café table — and the economy's feel holds: an aggressive anti-visitor run trends the meter upward while eating still matters [screenshot]
- [ ] (T-115) The victory beat reads as "the town is yours" warmth — comedic, not triumphalist: the gold wash, the delighted-elders line and the title land as a silly bird's good day, never a conquest banner; the visitors stay a goofy nuisance even in defeat; final copy (title, note) accepted or retuned by reviewer sign-off [screenshot]
- [ ] (T-115) The ending arrives readable in real play: the run ends the moment the meter hits the ceiling (no lag, no double beat), the frozen world sits under the victory screen, Space/R restart into a fresh same-seed run and M returns to the title — and a normal starvation ending in the same session still reads exactly as before, both registers never leaking into each other [screenshot]
- [ ] (T-115) The pace holds: a focused visitor-hunting run reaches the ceiling in roughly the ticket arithmetic's 6–8 minutes (aspirational, not a slog; not accidental inside one hunger bar) — if the drag is wrong, `favor_max` moves and the ticket's arithmetic re-runs; the deltas do not
- [x] (T-105..T-115) hands-on owner run of the post-T-115 build, 2026-10-12: "I played the game; I like the changes" — the batch's general feel/look judgement, recorded once here; the per-ticket screenshot lines above stay open for targeted passes
- [ ] (T-116) The favor meter + win-rule caption read at a glance in the HUD column, and the menu footer names the goal (agent pilot grab 2026-10-12, `.captures/session_t116hud/` — layout and copy verified on menu + run start; owner feel pass pending)
- [x] (T-117) The bird reads as snappier on WASD — pitch, bank/yaw and the waddle respond ×1.2 — and dives meaningfully faster (the cap 30 → 36 m/s is where dive speed lands), while nothing reads twitchy or grabby (owner playtest note 2026-10-13: "make WASD do 20% more of whatever they're doing"; accepted by reviewer sign-off 2026-10-13)
- [x] (T-118) Desktop browser: the hosted URL loads, the title screen renders, a run starts and flies with the keyboard, and the city reads right under the Compatibility renderer — sky, shadows, city edge — with the autoloads silent in the console [screenshot]
      · agent evidence 2026-10-15: deployed build browser-proven locally
      (title renders, Fly starts a run, keyboard flies, city reads right),
      hosted URL serving it (`VERIFY OK: HTTP/1.1 200 OK, HTML body served`
      via `tools/deploy-web.sh`, valid Let's Encrypt cert).
      · **owner hands-on pass 2026-10-15, live on the hosted URL: "It's
      working, I played it."**
- [x] (T-118) **iPhone go/no-go:** over the owner's hosting (the basement box at `games.matthews.mx/pigeon-simulator/`), the page loads in Safari, the title renders, the Fly button starts a run, the world renders at an acceptable framerate for a few minutes with no crash/reload, and the autoloads stay silent — the pass that unlocks T-119 [screenshot]
      · **owner hands-on pass 2026-10-15, mobile over the hosted URL: "It's
      working — I played it… it even figured out when I was on mobile vs PC
      and supplied the correct layout for each."** (the go/no-go risk — does
      the web build run on iOS Safari at all — is answered; the dedicated
      "her" playtest remains invited under the T-119 line below)
- [x] (T-119) **on the iPhone:** she starts a run from the hosted build, flies a loop, eats bread, lands, poops on a tourist, and pauses — with her judgement on stick comfort and button reach recorded here (tuning follow-ups — stick sensitivity, button sizes — go through new tickets, not this one) [screenshot]
      · **owner hands-on pass 2026-10-15, live from the hosted build, mobile
      layout auto-shown: "it figured out when I was on mobile vs PC and
      supplied the correct layout for each" — worked end to end. Judgement
      collected: "the buttons need to be a little easier to read" → ticketed
      as T-120 (per this line's own rule: tuning is a new ticket, not
      smuggled in). The dedicated "her" pass (stick comfort + button reach
      in HER hands) stays invited — the auto-layout detection and the
      playability substance are confirmed either way.**
- [x] (T-009) Splats pay the DESIGN points — 100 per tourist, 30 per car — and a popup at the hit reads clearly at flight speed
- [x] (T-009) Chained hits without landing escalate ×2, ×3… and reset when you land or after ~20 s
- [x] (T-009) A fast low dive hit pays the +50% style bonus — visible as a bigger popup number, and since T-038 labelled: styled hits are labelled, not just bigger ("+N STYLE" in gold)
- [x] (T-038) A styled hit's popup reads as gold/special at a glance in a real hit — the "+N STYLE" tag and the HUD pulse gold tint set it apart from a plain payout (reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-059) At cruise, a "+N ×M" popup at 40–46 m reads on screen — at the landed pixel_size 0.015 (font_size 96) it renders ~1.5× taller than the old 0.01 build (≈ 13 px → ≥ 20 px at 46 m) (reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-059) A chained pair of popups at 30–45 m reads as two numbers at a glance — the rise stagger keeps them separated through the float instead of merging into one line (reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-009) Beating the high score, then quitting and relaunching, shows the record survived
- [x] (T-073) One manual persistence pass: beat the record in a real run, chain two or more further hits, Alt-F4, relaunch — the record comes back as the FIRST-beat value (the accepted mid-chain-crash nuance), and a normal game-over run still persists the final score [screenshot]
- [x] (T-010) Boot lands on the title screen; Space (or the Fly button) starts a run on the spawn corridor
- [x] (T-010) Esc mid-flight freezes everything dead — pigeon, hunger, traffic; Esc again resumes exactly where it was
- [x] (T-010) From the pause menu: R restarts into a fresh same-seed city, M returns to the title, Q quits
- [x] (T-010) Die on purpose twice in a row — each score screen shows score, high score and the tourist/car split; restart works from both (pause mid-flight during both runs)
- [x] (T-010) The score screen flags a freshly beaten record and Esc cannot unpause a dead run
- [x] (T-097) The title screen shows a "Q quit" hint, legible at a glance; Esc at the title does nothing (the app stays up) and Q still quits [screenshot]
- [x] (T-039) The title's controls line reads at a glance under the footer — pitch, turn, flap, poop and pause all named before the first takeoff, legible on the flat dark navy (agent grab `.captures/t039_title_controls.png`; reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-039) The game-over footer reads as an invitation ("same city every run — race your best"), not a commit message (agent grab `.captures/t039_gameover_footer.png`; reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-011) The pigeon reads as a pigeon — gray body, darker wingtips, green neck sheen — silhouetted at ~20 m against both roofs and road
- [x] (T-109) The rigged realistic pigeon articulates in play — the flap beat reads at game speed, the peck reaches the crumb, glide/dive hold their poses with feet tucked; the unfolded wing's plank-ish look and fold-crease seam are acceptable in motion [screenshot]
- [x] (T-108) The realistic pigeon reads as the bird airborne and grounded — beak-forward orientation, b6-class scale and ground line held against the collision sphere, textured contrast holding up against road/roof/sidewalk; the T-104 realism review (scalp smoothness, neck feather regularity) stays pending from the art side [screenshot]
- [x] (T-011) Poses track the flight live: wings out gliding, swept back diving, beats on flaps, folded on the ground — no desync, no frozen wings
- [x] (T-011) The waddle (squat, body rock, head-thrust bob) is at least a little bit funny
- [x] (T-011) Eating a crumb plays the peck, and no pose ever clips the camera
- [x] (T-012) Trigger every sound in a normal run — flap whoosh, climb effort, splat, tourist yelp, panic shout at the fist shake, car honk, bread peck
- [x] (T-012) The mix is sane: nothing clips even when a splat, a yelp and a honk land at once, and the ambience bed never drowns gameplay SFX
- [x] (T-012) The ambience loops seamlessly — no audible seam on the traffic murmur or the distant chatter over a few minutes of play
- [x] (T-012) The flap whoosh reads in sync with the wing beat, and the effort strain only shows up on hard climbs
- [x] (T-013) Splats burst droplets, hard flaps poof feathers, landings kick dust — the effects read at flight speed but never pile up into screen clutter
- [x] (T-013) The camera shake on landings and your own splat hits is a tick, never nauseating — nothing obscures targets
- [x] (T-013) Side-by-side with before, the city reads warmer and the four districts read as distinct-but-harmonious neighborhoods from the air
- [x] (T-013) The HUD score pulse fires on combo escalation, reads clearly, and settles without jitter
- [x] (T-016) The pigeon reads as a pigeon at ~20 m against a sunlit sidewalk and a cream facade, not just against the road
- [x] (T-016) Side-by-side with before, the city still reads warm and sunny after the sun-energy retune (the T-013 warmth judgement re-based)
- [x] (T-019) The score line and control hint read clearly over white pavement at the spawn corridor, over the bright sky at altitude and over the dark road (dark outlines)
- [x] (T-019) The hunger bar warns at a glance — white → amber → red pulse → fast flash — without staring at it, and never sits stranded mid-flash after landing to eat
- [x] (T-080) The hunger bar reads as a bounded element at tier 0 — dark track + dark border — findable at a glance over white pavement at the spawn corridor, over the bright sky at altitude and over the dark road (side-by-side with before)
- [x] (T-037) The bread pointer is readable at a glance mid-flight — since T-111 the bread globe's segment leads the eye toward the crumb it names (steer along it), and the metres count down as you close in
- [x] (T-037) Flying past the city edge flips the same line to "city N m" pointing home, and steering along the segment brings the ring back into view
- [x] (T-037) The pointer line and the globe read over white pavement and bright sky (T-019 outline treatment / the dark puck) without crowding the hint above them
- [x] (T-111) Flying past a crumb at cruise, the segment swings down-short and reads "behind you" at a glance with no text — the T-058 bar, geometric [screenshot]
- [x] (T-111) Grounded before a building with a roof crumb, the segment tilts up and reads "above" at a glance — T-098's motivating case on the new instrument [screenshot]
- [x] (T-111) The gold flash reads as "fresh crumb" — noticeable at 40 px, calm not alarming — and the widget stays legible over white pavement and bright sky with the outline treatment; level dead-ahead flight reads as "tip on the pip" and is teachable in one sentence [screenshot]
- [x] (T-098) Grounded before a building with a rooftop crumb, the pointer reads "bread N m ▲" and the arrow stays readable at a glance under the T-019 outline treatment; airborne above a street crumb it reads " ▼"; within a few metres of the crumb's height and in city mode there is no arrow [screenshot] (retired by T-111: the ▲/▼ climb cue no longer exists to judge — the segment's slope IS the climb read; the motivating case re-armed as the T-111 "above" [screenshot] line above; pending T-111's own reviewer sign-off)
- [x] (T-058) At cruise past the ring, the suffixed "city <n> m — turn around" line reads at a glance in one look — the wording, not a chevron convention, is what says home is behind you over the featureless green (with the T-088 rim in view inside the ring, the suffix must still read cleanly past it) [screenshot] (retired by T-111: the stern suffix no longer exists to judge — the segment's down-swing IS the stern read; the bar re-armed as the T-111 "behind you" [screenshot] line above; pending T-111's own reviewer sign-off)
- [x] (T-099) The open pause panel's Air/Ground control recap reads at a glance beside the button labels over the dimmed world, and the "one controls block per screen" tone holds (agent grab `.captures/t099_pause_controls.png`, unpause confirm `.captures/t099_pause_unpaused.png`; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-040) A scored hit leaves the combo strip ("Tourist +100", "Car +30 ×2"…) readable at a glance mid-flight — at cruise over the skyline, low over the pavement and against the road [screenshot]
- [x] (T-079) Landing out of a live ×2+ combo, the "landing ended the ×N combo" note reads at a glance and doesn't crowd the strip/pointer rows above it — needs T-060-era hit rates (or a debug affordance) to reach a live combo in normal play; pending until then [screenshot]
- [x] (T-040) The hit-marker ring flashes at the splat and draws the eye to which tourist/car panicked [screenshot]
- [x] (T-017) Street canyons read as shop rows at eye level — colored ground-floor bands with doors and awnings, not blank office walls
- [x] (T-090) Every shop door reads as a named place at eye level — signboard plaque over the door, no clutter (agent grabs `.captures/t090_eyelevel_signs.png` — grounded on the spawn street: the pale cream plaque centered over the dark door slab under the awning, clear of band, door and awning, with more plaque-over-door reads along the row — and `.captures/t090_streetflight_signs.png`; reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-103) Shop doors read as flush slabs in the band face at eye level, on both street orientations (agent grabs `.captures/t103_street_xfacing_row.png` + `.captures/t103_street_xfacing_closeup.png` — grounded on the spawn street: dark door slabs standing flush in the band faces under their awnings — and `.captures/t103_street_zfacing_row.png` — z-facing doors flush across the intersection; no fin protrudes past any shopfront line in any grab; reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-049) At eye level the window rows read as floors — 2 rows on the 2-story podium, 5-6 on towers — and from cruise height the roofscape reads as buildings of differing heights, not one sticker at different zooms (agent grabs `.captures/t049_eyelevel_after.png`, `.captures/t049_cruise_roofscape_after.png`, `.captures/t049_streetflight_after.png`; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-051) The roofline reads as varied building volumes — slim, squat-wide and near-full-lot slabs mixed on the same block — not a waffle grid of equal squares, and the street-level read keeps shop rows continuous with no band broken by a slim building (agent grabs against the uniform-roof baseline `wbs2-c` f00001752: `.captures/t051_cruise_roofscape_after.png`, `.captures/t051_blockrow_after.png`, `.captures/t051_streetlevel_after.png`; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-020) Four elders sit on the plaza benches every run, spread around the ring, and read as old people at a glance — hunch, gray hair, cane — from both flight height and ground level
- [x] (T-020) Landing in front of an elder and hanging out ~4 s earns a share: two crumbs toss onto the pavement in front of the bench, land where the pigeon can reach them without phasing through the bench, and eating them restores hunger
- [x] (T-020) The ~4 s hangout feels like "a bit", not an age — and after a share the elder clearly ignores you for a good while (no infinite buffet)
- [x] (T-078) The elder's arm reads as the trust meter at ground level: it sits visibly part-raised while you hang out in front of the bench, keeps easing up as the elder warms to you, and eases back down during the post-share cooldown while you are still there — the "hang out, then wait" rhythm becomes learnable (agent grabs `.captures/t078_arm_midhangout.png` — `arm_raise` 0.579 at trust 2.32/4.0, the elder's near arm clearly raised over the bench — and `.captures/t078_arm_after_leave.png` — `arm_raise` 0.000 after stepping out of the zone; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-017) The shop bands read from the air and give the roofscape a visible street-level edge
- [x] (T-017) Shop colors harmonize with the four district palettes — distinct but not clashing
- [x] (T-017) Low street-level flight does not snag on or distractingly pass through awnings (visual-only by decision — `docs/tickets/T-017-shopfronts.md`)
- [x] (T-026) Side-by-side with before: sunlit sidewalk and plaza show surface tone instead of clipping to white, the asphalt reads as road rather than void, and lane dashes and car colors still pop
- [x] (T-026) The city still reads "warm sun" after the ground retune — the T-013 warmth judgement holds over the new ground values
- [x] (T-033) Restarting from the score screen shows no generation hitch — the fresh run appears instantly on the standing same-seed city
- [x] (T-036) Flying hard past the apron returns you to the spawn corridor within a couple of seconds, and it reads as intentional ("came home"), not a teleport glitch [screenshot]
- [x] (T-036) Across an off-world return the hunger bar never pauses — it keeps ticking down through the snap home
- [x] (T-030) Parks read as parks from the air — a grove of four crowns against the lawn, not a vacant lot — and the crowns never visually collide with benches or lamps (agent grabs: same-camera before/after pairs `.captures/t030_park_grove_z64_{before,after}.png` and `.captures/t030_park_grove_corner_{before,after}.png`; author A/B: `wb3b` vs `wb4-trees` frames; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-031) Awninged fronts read as cafes at eye level — table and seated people under the awning, not a bare door slab [screenshot]
- [x] (T-031) Low street-level flight past cafe tables doesn't snag, and tables don't crowd the tourist path
- [x] (T-042) Flying hard past the apron returns you to the spawn corridor within a couple of seconds, and it reads as intentional ("came home") — not a teleport glitch (retired by T-087's reviewer sign-off 2026-10-01: the pass judged the return WITH the presentation beat live) [screenshot]
- [x] (T-042) The hunger bar keeps ticking down across an off-world return — the clock never paused (retired by T-087's reviewer sign-off 2026-10-01; the machine half is `off_world_return_beat`'s drain leg) [screenshot]
- [x] (T-087) Flying hard past the apron now reads as "came home" — a warm fade covers the cut, feathers mark the departure point, and the lens is already home when the fade lifts (reviewer sign-off 2026-10-01; retires T-042's pending teleport-glitch line, jointly with T-036's) [screenshot]
- [x] (T-087) Across a presented return the hunger bar visibly keeps ticking down (reviewer sign-off 2026-10-01; retires the human half of T-042's drain line — the machine half is `off_world_return_beat`'s drain leg) [screenshot]
- [x] (T-023) Flying out past the apron, the pigeon visibly wants to go home — a gentle banked turn back toward the city, present but never a control grab — and a held outward turn can still win against it (the guard never hard-grabs) (reviewer sign-off 2026-10-02)
- [x] (T-023) The HUD shows the "Nothing out there — turn back" hint past the apron and the normal air/ground hint again once back inside — no hint fight across a landing/takeoff cycle at the boundary (reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-023) The outbound "turn back" hint and T-087's "came home" return beat read as one coherent off-world language, not two disconnected messages (reviewer sign-off 2026-10-02)
- [x] (T-032) From cruise height the roofs read as inhabited — AC boxes, water tanks and vents break the gray roof planes, and a rooftop crumb is spottable from a cruise glide [screenshot]
- [x] (T-032) Landing on a roof near a crumb and waddling to it works like the pavement version; the props read as useful cover, not obstacles
- [x] (T-112) From a cruise pass, awninged streets visibly hold the city's bread — several tabletop crumbs under awnings in one frame — while roofs read bare (0–1 roof crumbs visible across a few passes): "bread lives at the tables" reads from the air (accepted by reviewer sign-off 2026-10-10) [screenshot]
- [x] (T-112) Landing on a tabletop and pecking the crumb reads right — small pad, sitter beside you, crumb at your feet — and takeoff past the awning doesn't snag or read as a collision (accepted by reviewer sign-off 2026-10-10) [screenshot]
- [x] (T-085) In flight at cruise and in a dive, the bird reads at a glance against road AND roof at ~20 m — one bright anchor (rump/underwing) visible from the chase angle [screenshot]
- [x] (T-085) Grounded, the pale rump reads against asphalt so the bird no longer melts into the road [screenshot]
- [x] (T-088) At cruise the rim reads as the edge of town — a hedge line with tree clumps at each street exit — and the apron no longer reads as infinite grass [screenshot]
- [x] (T-088) From the apron (300+ m out) the horizon reads as a distant city under haze, not a void edge — the towers read as background (muted, low-contrast), not as landable-looking foreground buildings [screenshot]
- [x] (T-091) Each district has a tall anchor you can steer by — visible from cruise height, landable, with a crumb on top (reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-093) The grass apron sits exactly where it did after the one-body-per-group merge — no 0.5 m lip of grass poking above the road/sidewalk/plaza surfaces at the apron seam or the spawn plaza (the `_build_ground` reparent trap; before/after shots at the city edge; agent grabs `.captures/t093_seam_{before,after}.png` + `.captures/t093_apron_{before,after}.png`, sessions `t093bfly`/`t093afly` flown with one feedback-driven flap script — rim crossing z −155 within 4 frames, ~1 m apart at the seam — backed by the grass-mesh world-origin probe: (0, −1, 0) on both trees; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-102) Walking down a road toward an intersection, the band ahead reads as a zebra — bars running away with the road, step-over rungs — matching `.captures/xwalk-refs/ref08` (agent grab `.captures/t102_eyelevel_zebra.png`; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-102) From the air each crossing reads as a ladder with rails parallel to traffic (compare `ref11`) (agent grab `.captures/t102_aerial_ladder.png`; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-104) From plaza eye level and from a low orbit of each diagonal, each bin reads as its own object standing on the paving with visible daylight to its bench; benches, elders, lamps and the statue read untouched, and the ring still reads as a ring with walk-in gaps (reviewer sign-off 2026-10-02) [screenshot]
- [x] (T-048) At the chase cam's grounded distance (~3.5 m) the bird reads at a glance as a compact pigeon with wings hugging the flanks — not a biplane (reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-048) The takeoff moment (fold → GLIDE) shows the wings re-opening smoothly, without a pop as the chord re-expands over the pose lerp (reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-048) Elders read as people at a glance at 20 m — the rust cardigan separates them from the pavement (reviewer sign-off 2026-10-01; judgable in the same play session as T-020's pending lines) [screenshot]
- [x] Pigeon lands on the ground and does not fall through the world
- [x] HUD hunger ticks down over time
- [x] Camera does not clip through the ground while landing
- [x] Closing and restarting the game produces no errors

## Known issues

- In any checkout carrying the per-machine `addons/godot_mcp/` directory
  (untracked by policy, required on disk for the `MCPRuntimeProbe` autoload),
  Gate 1's `--import` prints one benign core line — `ERROR: 33 resources
  still in use at exit` — because the enabled editor plugin's GDScripts
  release after Godot's shutdown leak check. Verified identical on cold and
  warm cache in a throwaway clone with the addon restored; it is tooling
  shutdown noise from the canonical setup, not a project resource leak
  (`--quit-after` boot runs are clean with the addon present). A fresh git
  worktree does NOT carry the addon: Gate 1's import/boot then fail with
  `mcp_runtime_probe.gd ... File not found` / `Failed to create an autoload`
  errors while the project code is fine — restore the directory with a
  read-only copy from the canonical checkout first (it is gitignored, so the
  tracked tree stays clean; hit and fixed during T-102). Make the copy
  writable, though: the first import on a fresh worktree rewrites
  `godot_mcp/icon.png.import`, and a read-only copy turns that into a
  `Safe save failed` ERROR line in Gate 1's import (hit and fixed during
  T-030).
- Pitch flare (T-022) is machine-verified (Gate 1b `flare_sheds_speed_low` —
  from a settled ~15 m/s glide at ~6 m, 45 frames of held pitch-up gain
  +1.85 m and end at 10.15 m/s against the 2.5 m / 11 m/s bars, failing both
  before the flare at +2.60 m / 11.66 m/s; `dive_gains_speed`,
  `pullup_gains_height`, `stall_drops`, `stall_recovers`, `banked_left_turn`
  and `landing_slides_to_stop` re-run green, and they survive a 1.2 over-drive
  probe, so the tuned `flare_drag` 0.8 sits well inside the protected zone).
  A human pass over its two Gate 3 lines (nose-high brake-sink read near the
  ground, controllable speed approach to a bench/roof) is still pending.
- Gate 1's `--check-only --script res://scripts/player.gd` syntax check is
  currently broken repo-wide, pre-dating T-022: check-only mode never starts
  the project, so autoload globals (T-012's `Sfx`, referenced by `player.gd`
  and `poop.gd`) never resolve and the compile fails identically on the
  pristine tree. `--import` plus the 120-frame boot still exercise the script;
  the command needs its own fix-or-drop decision, not a per-ticket workaround.
- Stick-the-landing (T-021) is machine-verified (Gate 1b `trim_glide_lands_clean`,
  plus `hard_landing_skids` retuned to the skid bar `skid_settle_speed` — the
  settle bar itself rose 12 → 16 to sit above the model's own trim-glide
  touchdown speed); the human pass over the T-021 lines (trim touchdowns
  *stick*, hot dives still read as comedic skids) is still pending.
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
  recorded in the ticket, not gated; since T-033 the restart half is gone (a
  same-seed restart re-uses the standing city — `restart_same_seed_skips_rebuild`)
  and only the one-off boot build remains.
- HUD legibility & hunger warning (T-019) is machine-verified (Gate 1b
  `hud_hunger_warning_tiers` — resolved outlines, tier bands, in-game-time
  pulse, rest-color restore through refill and restart; since T-080 also the
  bar's own track/fill styleboxes). A human pass over the T-019 lines
  (legibility over pavement/sky/road, tier readability at a glance, pulse
  comfort) is still pending; T-080 landed the scene-side half (dark track +
  bordered white fill) and its at-a-glance line is agent-played via the pilot
  harness (see T-080's ticket for the before/after grabs).
- Bread pointer (T-037, re-armed by T-111) is machine-verified (Gate 1b
  `hud_bread_pointer_tracks_nearest_crumb` — nearest-crumb query vs an
  independent scan, distance/approach, re-aim after eating through the real
  waddle-in, city mode beyond the ring, resolved outlines, and since T-111 the
  bread globe's arms: the pigeon-frame steering contract at dead-ahead/yaw-180,
  overhead and stern geometries against the scenario's own live-basis
  recompute, the strict `<what> <n> m` text, the flash state machine and the
  zero-delta guard) and costs one nearest-N scan per frame inside the T-018
  budget (`density_cpu_budget` runs with the pointer live). Since T-111 the
  slot is the bread globe — a drawn pigeon-frame instrument whose segment
  carries the target's direction relative to the pigeon's own orientation;
  T-057's screen-space chevron and its behind-lens/degenerate holds (the
  widget reads no camera, so those hazards do not exist), the T-098 climb cue
  and the T-058 stern suffix are RETIRED — their jobs are the segment's slope,
  foreshortening and down-swing, and their scenario arms and text machinery
  are deleted. A human pass over the T-037/T-111 lines (readable at a glance
  mid-flight, city mode reads clearly on the cruise home, legible over
  pavement and sky) is still pending.
- Park elders (T-020) are machine-verified (Gate 1b `elder_placement_no_rng`,
  `elder_shares_bread_after_hangout`, `elder_no_bread_airborne`,
  `elder_cooldown_blocks_second_share` — including byte-identical city
  fingerprints across the change) and live in the autoplay city (the DONE line
  reports `shares`); the CaptureRecorder emits `elder_bread_shared` events and
  an `elders` state list for pilot sessions. A human pass over the T-020 lines
  (elder reads as an old person at a glance, ~4 s hangout feels right, tossed
  bread lands reachable) is still pending.
- Poop readiness cue (T-077) is machine-verified (Gate 1b
  `poop_ready_indicator_tracks_cooldown` — lit airborne, dim the frame a real
  poop fires, no early relight, freeze under pause, relight on cooldown expiry,
  hidden while grounded, restart mid-cooldown relights) and the glyph freezes
  with the world because it is driven from `_process` game time like the rest
  of the HUD. A human pass over its Gate 3 line (glyph legibility beside the
  hint line over pavement and sky, dim-vs-lit distinguishable) is still pending.
- Same-seed restart fast path (T-033) is machine-verified (Gate 1b
  `restart_same_seed_skips_rebuild` — the standing city is re-used, every
  spawner re-seeds, and the determinism scenarios prove real rebuilds via
  `force_rebuild = true`); the per-restart rebuild hitch is gone and only the
  one-off boot build remains. A human pass over the T-033 Gate 3 line (no
  generation hitch restarting from the score screen) is still pending.
- Cafe tables (T-031) are machine-verified (Gate 1b `city_cafe_tables_present` —
  pure-layout spots recomputable from the building records, byte-identical
  across same-seed regeneration, spawner rig seating 104 tables with 156
  static sitters, street clearances, pigeon perch-and-snag check) and live in
  the autoplay city; the T-018 CPU budget stays green with the furniture in
  (median ~241 vs 750 ms per 100 physics frames). The layout fingerprint is
  byte-identical to pre-T-031 builds (no new RNG draws anywhere). A human pass
  over the T-031 lines (cafe read at eye level, low-flight snag,
  tourist-path crowding) is still pending.
- Off-world guard (T-042, adopting T-036) is machine-verified (Gate 1b
  `off_world_fall_respawns` — a −10 m start past every floor grounds on the
  respawn corridor within ~2 s with exactly one guard fire, finite velocity
  throughout, and the hunger clock draining straight through the reset; every
  pre-existing flight/landing/density scenario re-run green, so the −5 line is
  never approached in ordinary play) and live in the autoplay run (the pilot's
  off-world excursions now self-heal). Its two human lines were retired by
  T-087's reviewer sign-off 2026-10-01 — the pass judged the return as "came
  home", hunger ticking, WITH the presentation beat live.
- Rooftop clutter (T-032) is machine-verified (Gate 1b `city_roofs_inhabited` —
  1-3 props per building ≥ 1.0 m inside every roof edge and ≥ 2.5 m off the
  footprint center, one layer-1 shape each under the Props group body since
  T-093's merge, exactly one roof crumb per
  building in the never-propped (+,+) quadrant so `bread_spots` grows by
  exactly the building count (533 → 679 at the M1 seed; since T-091 the four
  district-anchor cap crumbs join the same count, 683 — the scenario's three
  amended pins carry `_city.anchors.size()` terms), a roof crumb eaten
  through the ordinary grounded waddle path with no BreadSpawner change, a
  prop-top landing, and a byte-identical same-seed rebuild of `roof_props`
  and the roof spots — the layout fingerprint stays byte-identical to
  pre-T-032 builds: zero RNG draws, zero new `_fp` entries). The autoplay
  cruise screenshots show the props; a human pass over the T-032 lines
  (roofs read as inhabited from cruise height, rooftop crumbs spottable,
  props read as cover rather than obstacles) is still pending.
- Park trees (T-030) are machine-verified (Gate 1b
  `city_park_trees_present` — 4 trees per park block at the fixed (±5, ±5)
  offsets with the park blocks re-derived independently from the slab queue,
  trunk 1.1 m up on the slab and crown 3.3 m up over every offset, crowns
  fully inside the block, crown green 0.282 Euclidean RGB from COLOR_PARK,
  bread-spot clearance worst 4.98 m, the ≥ 1.5 m lamp/bin arithmetic pinned,
  visual-only, a byte-identical same-seed rebuild, and the layout fingerprint
  unchanged at the cross-version pins — zero RNG draws, zero `_fp` entries,
  re-derived on the untouched tree before the diff landed). The park trees
  reuse the T-088 rim-tree recipe (bench-wood trunks, the hedge-family crown
  green COLOR_RIM_CROWN), visual-only per the T-017 decision. The Gate 3
  line (parks read as groves from the air; crowns read against the lawn
  without visually colliding with benches or lamps) was accepted by
  reviewer sign-off (2026-10-01; agent-side same-camera before/after grabs:
  `.captures/t030_park_grove_z64_{before,after}.png` and the corner park
  pair `.captures/t030_park_grove_corner_{before,after}.png`).
- Bread pointer climb cue (T-098) — RETIRED BY T-111 (2026-10-10): the ▲/▼
  cue is deleted from the game; its job — "a roof crumb must not read like a
  blank wall it points into" — is the bread globe segment's slope now, and
  its motivating case re-armed as a T-111 Gate 3 [screenshot] line. Its
  machine legs (the cue arms of `hud_bread_pointer_tracks_nearest_crumb`,
  `_pointer_distance_m`'s 4-part shape and the " — " strip) died with the
  cue: the scenario parses STRICT `<what> <n> m` since T-111, so any
  re-introduced suffix fails every distance assert.
- Traffic recycle flow (T-089) is machine-verified (Gate 1b
  `traffic_recycle_keeps_flow` — 5 probed insertions onto one plaza-adjacent
  ring flow 39.5-50.5 m in 10 s with the pigeon parked, seeded gaps ≥ 5.67 m,
  fleet floor 2.45 m, no mid-run teleports, and the block draw never picks an
  over-cap ring while a lighter one exists) plus a one-line latent-bug fix
  the scenario exposed: `Car.recycle_to` kept the old ring's armed rejoin
  point (`_has_via`) after teleporting, dragging recycled cars off-lane into
  walls. The recycle-path clot is fixed, but the Gate 3 line cannot pass as
  written on ANY build — pilot A/B (same seed, no input, sessions
  `t089stand`/`t089base`): 6/36 cars flowing on this branch vs 5/36 on
  pristine main with the identical wall, driven by out-of-scope mechanisms
  (FrontZone yielding queues behind the pigeon the corridor drop lands
  mid-street; head-to-head standoffs on shared lane lines in car.gd's drive
  model). The line stays unchecked pending a human pass; both residuals are
  recorded as follow-up candidates in the ticket's "Known issues / follow-up"
  section.
- Pitch attitude bound (T-083, adopting T-062) is machine-verified (Gate 1b
  `pitch_attitude_bounded` — a 50-frame held pitch-up from settled cruise
  keeps |body pitch| ≤ 85° on every frame of the hold and for 30 frames
  after, and stays under the pre-fix-measured balloon bars peak vy < 8.7 m/s
  and |vy| < 1 m/s mush < 244/300 frames; measured 79.9° / 8.85 / 247 on the
  pre-fix tree vs 70.7° / 8.48 / 240 with the falloff, red-before via the
  balloon bars — the criterion's ≈105° figure was constant-authority
  arithmetic, corrected in the ticket; the five named flight/landing
  re-runs stayed green with before/after margins recorded). The tested
  symmetric 50°/85° falloff shipped, and the Gate 3 feel lines (no
  parked-vertical nose, capped flare taps, full-authority dive entry, live
  pitch-down recovery) were accepted by reviewer sign-off (2026-10-01).
- Title-screen Esc (T-097) is machine-verified (Gate 1b
  `title_escape_does_not_quit` — a synthetic `pause` action fed to the real
  menu scene neither quits the process nor pauses the tree; a regression
  re-adding the quit branch kills the whole Gate 1b run) and the quit arm
  itself is deliberately not asserted headlessly — a harness cannot survive
  testing its own quit. The agent-side pilot pass (title screenshot with the
  "Q quit" footer hint, Esc at the title leaves the app up, Space still starts
  a run, Q exits) is recorded in the ticket and accepted by reviewer
  sign-off (2026-09-30).
- FOV kick / fast-arm trim (T-044, adopting T-024) is machine-verified (Gate 1b
  `camera_fov_kick` tightened in place to absolute bounds on the 26 m/s leg —
  74.0 ≤ fov ≤ 80.0 plus arm < 6.2 m — which measured fov 85.9 / arm 6.50 on
  the untouched camera tree and FAILED there, then 78.9 / 5.81 inside the
  bounds after the retune; `camera_follows_yaw` and `camera_tucks_in_grounded`
  re-run green, so follow and the grounded tuck are untouched). The human
  pass over its two Gate 3 lines (the cruise silhouette pair vs the untouched
  tree; the 5.8 m fast arm never cramped low) was accepted by reviewer
  sign-off (2026-09-30).
- Remaining placeholder art: upper-floor facades are tinted
  boxes with a procedural window texture (ground floors carry T-017 shopfront
  bands, doors and awnings; the awnings are visual-only, no collider).
- T-016 machine-checked the pigeon's material contrast and capped the sun, but
  the human pass over its two new Gate 3 lines (bird readable on sidewalk and
  facade at ~20 m; city still reads warm after the energy retune) is pending.
  The grounded "folded wings still read as splayed" issue is CLOSED (T-048,
  reviewer sign-off 2026-10-01): the rig-level chord fix T-016 called for
  landed — `folded_chord_scale` 0.35 eases the wing pivots' Z scale down while
  grounded (`pigeon_ground_poses_track_waddle` asserts it, plus the
  re-open/reset legs) — and the three T-048 Gate 3 screenshot lines (grounded
  non-biplane read, pop-free fold → GLIDE re-expansion, elder rust accent)
  passed human review.
- Ground palette retune (T-026) is machine-verified: the Gate 1b
  `pigeon_silhouette_contrast` scenario gained the ground-pair floors
  (sidewalk ↔ asphalt ≥ 0.30, sidewalk ↔ body ≥ 0.20 — measured 0.435 / 0.230
  at the retuned constants), and the T-016 body↔sidewalk floor held with no
  re-basing (0.230 ≥ 0.20). Colors are absent from the layout fingerprint and
  colliders, so every determinism/walkability scenario is untouched. A human
  pass over its two Gate 3 lines (sidewalk/plaza tone instead of blow-out,
  road reads as road, dashes/cars still pop; the warm-sun read holds) is
  still pending.
- Off-world fall guard (T-036) is machine-verified (Gate 1b
  `off_world_fall_returns_home` — below the −5 line past any floor the reset
  fires exactly once, the pigeon grounds on the respawn corridor within ~2 s,
  holds it with no second fire for ~2 more, and hunger keeps draining through
  the reset; the fail state is untouched — `hunger_game_over_once` stays
  green). Agent-driven pilot runs flew ~380–460 m past the apron, dove
  off-world and snapped home grounded on the corridor within seconds, hunger
  still draining through the return (evidence kept at
  `.captures/t036_return_home.png`). A human pass over the T-036 Gate 3 lines
  (the return reads as "came home", not a teleport glitch [screenshot]; the
  hunger bar visibly keeps ticking through a return) is still pending.
- Off-world return & buzz-flinch observability (T-095) is machine-verified:
  `off_world_fall_returns_home` now counts the guard's new `off_world_reset`
  signal beside the counter — exactly one of each across the whole window —
  and the full suite stays green (93 scenarios, 0 failures), so the emit is
  behavior-neutral. The pilot evidence path is live and flown: session
  `t095out4` shows the `off_world_reset` events line with the void position
  (`p=[16.0,-5.22,-756.45]`, 389 m past the apron edge) between the last
  outbound state and the corridor `grounded`, with `off_world_resets` rising
  0 → 1 exactly once in the state stream and hunger draining straight
  through; session `t095buzz` shows the per-tourist `buzz` array flinch
  counts landing on exactly the indices of the loose-group pair the pigeon
  overflew at ~2.7 m and 12–17.6 m/s (evidence in `.captures/session_t095out4/`
  and `.captures/session_t095buzz/`, tables in the ticket). The T-042/T-036
  Gate 3 lines keep their pending human-pass status — this ticket gives them
  the pilot-evidence path they were missing.
- Off-world return beat (T-087, absorbing T-100) is machine-verified (Gate 1b
  `off_world_return_beat` — through the real main scene the guard fires exactly
  once with `from` = the void departure position, a feather poof marks `from`,
  the warm HUD fade covers the cut and is fully out within ~1 s of game time,
  the camera is snapped home on the first frame after the reset, the "home
  again" note shows and self-expires, the pigeon grounds within ~2 s with no
  second fire over ~2 more, and Game.hunger drains > 0.2 through the window;
  the bare-harness guard scenarios stay untouched and green, proving the emit
  alone is a no-op). The T-095 pilot evidence path survives the signal's new
  `from` argument: the recorder's listener accepts it (a 0-arg callable is
  never called by a 1-arg signal in Godot 4.7 — it printed an engine ERROR per
  fire and logged nothing, caught in review round 1), and session `t087rv1b`
  re-flew the excursion past the apron — dive from ~1194 m out, events line
  `{"ev":"off_world_reset","p":[16.0,-5.48,-1194.33],"t_ms":146436}` between
  the last outbound state and the corridor `grounded`, `off_world_resets`
  stepping 0 → 1 exactly once across the stream, zero ERROR lines in the
  session's godot.log. Its two Gate 3 screenshot lines passed human review
  (reviewer sign-off 2026-10-01) — the return reads as "came home" with the
  fade, feathers and pre-snapped lens, and the hunger bar visibly keeps
  ticking — retiring T-042's pending teleport-glitch line.
- District anchors (T-091) are machine-verified (Gate 1b
  `city_district_anchors_present` — four zero-RNG clock posts at the pinned
  quadrant blocks' alley-cross centers, `report.max_roof_height` newly pinned
  to the building roofs only, the plinth's per-seed daylight re-derived from
  `buildings[]` (worst 24 mm at the M1 seed, 1.6 mm at seed 424242 — flush,
  never overlapping), measured bread-spot clearance ≥ 5 m plus constants
  arithmetic for loop/bench/ring/crown lines, the cap crumb in `bread_spots`
  at cap_top + 0.06, byte-identical rebuilds, a foreign-seed leg, a cap-top
  landing at cap_top + 0.3 and the crumb eaten through Hunger;
  `city_roofs_inhabited` re-pinned with `_city.anchors.size()` terms and the
  four cross-version fingerprint pins re-derived for the four new `_fp`
  entries — 1006789400/3359332191 → 650664268/4031380170). The autoplay pilot's
  23 m cruise floor clears the 17.42 m tops by construction. The T-091 Gate 3
  line (each quadrant's silhouette reads as a destination from cruise height
  with the T-088 ring still background; from the block below the post reads as
  a clock/bell tower) passed human review (reviewer sign-off 2026-10-02)
  [screenshot].
- WASD responsiveness pass (T-117) is machine-verified (Gate 1b full suite green
  in one headless run — 127 scenarios, 0 failures — with NO logic edits: the
  seven ×1.2 constants in `player.gd` are the whole payload. Exactly one
  scenario bar re-derived: `hands_off_glide_trims`' end-angle bound 7.0 → 8.4,
  ×1.2 on the bar, with the settle-equilibrium probe recorded on the const and
  in the ticket. The ripples the ticket named passed untouched with margin:
  `flare_sheds_speed_low` +1.26 m / 10.44 m/s against the 2.5 m / 11.0 m/s
  bars, `pitch_attitude_bounded` max |pitch| 74.7° under the 85° falloff
  asymptote (peak vy 7.90 vs the 8.7 bar, mush 7/300), `banked_left_turn` at
  the full 40° bank (fwd.x −0.82 vs the −0.3 bar), `flap_speed_envelope`'s pump
  peak 16.89 m/s under the cap-independent 26 m/s ceiling, and the loop/stall
  windows (stall flagged at frame 42, the ≤ −6.0 m/s fall reached in 36/45
  frames). Gate 2 autoplay `ok=true restart=true` with no autopilot edits; the
  pristine tree's DONE line shows the same reported-not-gated shape (splats
  mostly unscoreable chance shots, panics 0 on both trees), so the stronger
  responses cost the pilot nothing measurable). The owner feel pass line was
  accepted by reviewer sign-off (2026-10-13).

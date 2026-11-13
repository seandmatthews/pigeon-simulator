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

> **Known tooling notice (godot_mcp):** fresh worktrees must copy the untracked
> per-machine `addons/godot_mcp/` addon in before import/boot pass (the
> .gitignore-documented precondition — project.godot references the
> MCPRuntimeProbe autoload; copy it from a checkout that has it, keep it
> untracked). When it is provisioned, `--import` exits 0 but prints one ERROR
> line — "N resources still in use at exit" — whose --verbose entries are all
> the enabled editor plugin's own scripts at headless-import teardown
> (`res://addons/godot_mcp/...`). This line is accepted and is NOT a gate
> failure; it reproduces on the main checkout as well (verified 2026-10-17
> wave-1 runs). Any OTHER ERROR line, or a nonzero exit, still fails the gate.

**Pass =** all commands exit 0 and output contains no `ERROR`, `SCRIPT ERROR` or
`Parse Error` lines. Warnings are acceptable but worth cleaning up.

## Gate 1b — Sim harness (automated behavior checks, run after every change)

```bash
godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
```

Prints one `SIM PASS/FAIL <name>` line per scenario; **pass = exit 0**. Deterministic
(fixed timestep, synthetic input), so a failure is always a real regression, never
flakiness. Set `SIM_DEBUG=1` for trajectory traces. Since the T-177 cutover the
WHOLE suite runs on the resident Ames world — `Game.world` defaults `ames`, every
instanced-Main rig boots the bake through Main's swap, and the retired Windrow rows
are recorded in the T-177 ticket's re-pin ledger (the citizen-system rows return
with the R2 re-base tickets that re-feed them). The scenario table grows as
tickets land — every feature that can be machine-checked gets a scenario here:

| Scenario | Proves | Ticket |
| -------- | ------ | ------ |
| takeoff_3_flaps | 3 paced flaps from the ground reach climbing flight | T-001 |
| flap_speed_envelope | four paced flaps climb without pumping forward speed to the cap, and a flap at cruise buys climb, not throttle (fwd gain < 2 m/s at +1–2 frames, vy gain > 4; T-133 re-locked the shared pump ceiling 26 → 15 at the ×0.8 pace — the new tree measures 13.15, the pre-T-133 tree 18.6 fails it, red-before) | T-015, T-133 |
| sustained_flap_ceiling | TWELVE paced ground flaps (the takeoff cadence, fully rested) converge below the pump ceiling instead of riding toward `max_speed` — peak forward speed tracked through the whole cadence AND a 3 s no-input coast, velocity finite throughout; the ceiling re-locked 26 → 15 for T-133's ×0.8 quartet (measured 13.15 at the landed fade 0.5; the pre-T-133 tree measures 18.57 — FAIL, red-before; the T-043-era tree measured 20.26 at ceiling 26, and 28.28 FAIL without the fade) | T-043, T-133 |
| lift_softens_gravity | level glide at 12 m/s sinks gently (< 6 m in 1.5 s) | T-001 |
| dive_gains_speed | a dive to −60° converts height into speed | T-001 |
| pullup_gains_height | pulling out of a dive climbs above the pull-start altitude while speed bleeds | T-001 |
| banked_left_turn | a held turn banks the body and yaws with the bank | T-001 |
| flight_speed_quartet_locked | (T-133) the slower-bird pass value-locked at the live exports: the quartet at 10.4 / 13.6 / 28.8 / 4.0, every re-derived satellite band from the ticket table (`flap_push_taper` 8.0, `max_land_speed` kept 16.0, `dive_pose_min_speed` 7.2, `flare_max_sink` 6.4, `dust_impact_min` 1.2, `effort_climb_speed` 1.6), and the three turn/pitch rate exports byte-identical to the T-117 tree (`bank_rate` 4.2, `full_bank_yaw_rate` 1.8, `pitch_speed` 2.64) — a silent retune of any of them fails the same night; behaviorally the settled cruise re-locks at the new pace (120-frame settle reads fwd 13.35, band 13.0–14.0; the pre-T-133 tree still converging toward its ~17 trim measures 14.51 — FAIL, the revert probe's re-locked-value failure) | T-133 |
| turn_circle_shrinks | (T-133) the same hand draws a ≈×0.8 smaller circle: from a settled cruise glide, 90 frames of full turn_left measure radius = horizontal path ÷ swept heading inside a ×0.8 band of the pre-T-133 run — pre-T-133 12.35 m (path 22.8, swept 1.84 rad; the revert probe re-measures 12.35 byte-identically and fails the ≤ ×0.87 bound), ×0.8 tree 9.95 m (ratio 0.806), band ×0.72–×0.87 so a no-op and a collapse both fail; the rate exports the ratio leans on are pinned in `flight_speed_quartet_locked`; a swept-heading sanity arm (> 1.0 rad) keeps a broken turn from greening the ratio vacuously | T-133 |
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
| trim_glide_lands_clean | a natural trim-speed glide touchdown settles into the waddle on the contact frame — zero airborne floor-contact frames past the touch (no ghost-slide); T-133 re-locked the start to the ×0.8 trim (touch arrives ≈ 13.2 m/s at sink −1.23 m/s — under the kept 16 m/s settle bar, and the landing dusts at the re-derived 1.2 gate) | T-021, T-133 |
| natural_glide_touch_dust | (T-133) the dust trap, as a landing: a DEVELOPED natural glide — the full trim descent with its settled sink, not the short hop — must arrive under `max_land_speed` and settle, touch with a sink at or above `dust_impact_min` (export-relative, so keeping the old 1.5 over a shallower ×0.8 sink or raising the gate fails right here), and actually puff the dust (stale-puff hygiene `_clear_dust_puffs` keeps the before/after count honest). Measured: arrival 14.62 m/s, sink −1.72 m/s vs gate 1.2, dust true. Finding recorded: the ticket's trap estimate (~1.44 developed sink vs the old 1.5) proved pessimistic — the measured ×0.8 developed sink is 1.72, which clears even 1.5; the short hop (sink 1.23) is the landing class 1.5 would ground dustless, and the gate value itself is pinned in `flight_speed_quartet_locked` | T-133 |
| flare_sheds_speed_low | holding pitch-up in a shallow descent sheds speed into a nose-high brake instead of ballooning — from a settled trim glide at ~6 m, 0.75 s of held pitch-up gains < 2.5 m of height and ends below the re-derived bar (T-133 re-derived ×0.8: settled 13.13 → ended 9.14 m/s, +1.83 m; bars settled > 10.5 / ended < 9.8 — the pre-T-133 tree flares to ~10.4 > 9.8 and a flare-less tree keeps its speed, both red; the old pace measured 14.56 → 10.44, +1.26); climbs and level flight above the band and dives below the −6.4 m/s edge never flare, and the grounded skid keeps its own friction | T-022, T-133 |
| pitch_attitude_bounded | a held 50-frame pitch-up from settled cruise keeps \|body pitch\| ≤ 85° on every frame of the hold and for 30 frames after release (T-133 pace measured 73.9°), and bounds the balloon outcome: peak climb vy < 6.5 m/s during the hold (T-133 pace measured 5.54; the pre-fix tree measured 8.85 — still red) and post-release \|vy\| < 1 m/s mush < 230 of 300 frames (T-133 pace measured 217 — the shallower post-release sink mushes longer than the old pace's 7; the pre-fix tree measured 247 — still red; bars re-derived ×0.8 with both documented red runs kept red) | T-083, T-133 |
| hands_off_glide_trims | a RELEASED pitch input eases the nose toward the velocity vector instead of freezing it — from a settled cruise glide an 8-frame pitch-up hold displaces the nose > 10° off the flow (measured 17.35° at the ×1.2 pitch rate, 18.04° at the T-133 pace — the entry is rate-driven and pace-invariant), then 90 frames hands-off show the nose travelling ≥ 2.5° back toward the flow (measured 6.24° old pace, 7.33° at T-133; the pre-fix tree freezes it — 0.00°, red-before) with the signed nose-to-flow angle bounded (bar re-derived twice: 7.0 → 8.4 for T-117 at measured 7.59 → 10.5 for T-133 at measured 9.70 — the slower cruise bleeds deeper in the window and recovers slower; the T-133 settle probe holds the trim-converges arm: −9.70 @90 → −10.81 @180 → −2.98 @360, equilibrium ≈3° by 360 frames — trim_rate untouched; the T-082 freeze red-before rides the travel arm) | T-082, T-133 |
| hands_off_mush_exits | a slow nose-high hands-off mush FALLS instead of hovering at the aligner's zero-sink equilibrium — from a 5.3 m/s level glide (T-133: ×0.8 of 6.6, the same ~0.39 lift fraction at the new glide_speed) tipped 0.29 rad nose-up, 240 hands-off frames must lose ≥ 3.0 m and reach a sink ≤ −2.0 m/s (bars kept: T-133 pace measured −7.64 m, min vy −2.54; the old pace measured −8.71/−2.70; the pre-fix tree only mushes: −3.99 m, min vy −1.76 m/s — FAIL on the sink arm, red-before) | T-081, T-133 |
| stall_falls_develops | a ballooned climb that reaches the stall flag develops a real fall, not a hover: within 45 frames of `stalled` the sink must reach ≤ −6.0 m/s (measured landed: stalled at frame 48, vy −6.00 reached in 37 frames; the pre-fix tree hovers in the stall: stalled at frame 38, vy only −2.79 after the full 45 — FAIL, red-before; both runs in the ticket) | T-081 |
| loop_over_top_roll_recovers | the owner's loop repro leaves no persistent roll cant: settled cruise → 15-frame turn_left seed → pitch_up held with a near-fully-rested flap tap every 21 frames until the nose parks at the T-083 asymptote, ending the hold ON a fresh kick; the nose must demonstrably sweep over the top (nose·entry_fwd < 0 within 240 frames of release, sanity nose.y > 0.9 somewhere in the hold — the precondition is asserted, never skipped), then 120 frames of hands-off-steering flight (the repro's own flap cadence continues — re-derivation recorded in the ticket) must end with \|measured roll\| ≤ 5° and non-increasing across its last 60 frames (measured landed: end 0.00°, trend 0.00, crossing 24 frames after release, near-pole \|roll\| peaked 21.2° inside the envelope → no gating band needed; the pre-fix bookkept tree ends at 176.84° fully inverted and still increasing — FAIL, red-before; both runs in the ticket) | T-106 |
| loop_lands_level_keeps_yaw | the ground leg of the same scenario: a fresh low cruise glide seeded with the full-envelope cant the book cannot see (`max_bank_deg`) descends passively and must stand \|measured roll\| ≤ 2° after 60 grounded frames with the heading moved ≤ 2° from touchdown (measured landed: stand 0.00°, yaw drift 0.00° — the measured controller eats the cant in flight and the leveler squares whatever the skid leaves; the pre-fix bookkept leveler stands the bird at exactly the seeded 40.00° — FAIL, red-before; both runs in the ticket) | T-106 |
| off_world_fall_respawns | a pigeon placed below the `off_world_y` guard (−5) and past every floor is grounded on the respawn corridor within ~2 s — the guard fired exactly once (`off_world_resets` == 1, no second fire across a further ~2 s, velocity finite throughout) and the hunger clock kept draining through the reset (loss > 0.2) | T-042 |
| hunger_drain_flap_vs_glide | hunger ticks in flight — visibly faster while flapping than gliding, slowest resting grounded | T-005 |
| hunger_game_over_once | hunger empties, clamps at zero and fires game_over exactly once; eating restores a chunk but the latch holds; since T-075 the guarded setter also stays silent at zero — 120 further drained frames with the player still attached count ZERO `changed` emissions (the unguarded tree measured 120, one per tick) | T-005, T-075 |
| crumb_eaten_grounded_only | flying over a crumb never feeds; a grounded pigeon waddling into it eats it and frees it | T-005 |
| crumbs_respawn | (T-177 re-pin) eaten crumbs are topped back up within one respawn interval, on the resident Ames world's spot supply — the rig target is 12 (the smallest honest target: the world's 8-spot boot ring `City.boot_bread_spots` seeds FIRST and unconditionally, so the retired Windrow-target 6 would be overfilled by construction): populate lands exactly 8 boot crumbs + the class fill's 4, 3 are eaten, and the count reconverges to 12 with `eaten_count` == 3 | T-005, T-177 |
| poop_inherits_and_arcs | an airborne drop inherits the pigeon's velocity, keeps the horizontal lead and only ever falls | T-006 |
| poop_grounded_no_drop | F does nothing while grounded — droppings exist only in the air | T-006 |
| poop_cooldown_blocks_stream | mashing F yields one dropping; the next comes only after the cooldown elapses | T-006 |
| poop_splats_ground_and_fades | a floor hit fires splatted(target, impact_velocity), sticks an up-facing splat to the hit body and fades it away | T-006 |
| poop_splats_wall | a wall hit sticks a splat facing along the wall's horizontal normal | T-006 |
| poop_event_reaches_any_body | a plain body on the hit layers receives the hit duck-typed (on_splatted) with no player import anywhere in poop.gd | T-006 |
| poop_ball_visible | the falling drop reads from the chase cam — BallMesh radius ≥ 0.10 (landed 0.12), Mat_ball carries the soft warm emission in the parse-safe 4-arg Color form (a 3-arg Color in a .tscn fails to parse, load() → null), albedo ≥ 0.25 Euclidean RGB from the two wash-out backdrops (the T-177 re-pin: the Ames bake's residential-plate and downtown ground tints, the retired Windrow grass/plaza constants died with the generator) and the collider stays pinned at T-060's retuned 0.30 (the landed 0.07 pin amended in place — the pin's purpose survives: the collider still deliberately differs from the 0.12 mesh, the overhang direction flipped) | T-086, T-060, T-177 |
| reticle_frozen_pin_matches_damped_fall | the ONE persistent poop reticle (T-105, replacing T-046's per-drop ring) pins where the drop will REALLY land — bare rig, direct `poop_reticle.tscn` instantiation + `lock_to(drop)` of a real tap's drop from the cooldown scenario's exact set-up (0, 20, 0)/(0, 0, −12): the frozen pin sits within 0.5 m of the impact recomputed INDEPENDENTLY in the scenario by the DAMPED closed form from the drop's own p0/v0 (read fresh from the drop, never through the reticle's march — the no-self-test rule), with the damp read straight from the `physics/3d/default_linear_damp` project setting (measured 0.03 m; measured damped-vs-undamped separation 1.03 m at this release, and the red-before probe — march reverted to T-046's undamped parabola — measured the pin 1.16 m off and FAILed this leg, so the damping fix is load-bearing); the pin is stable through the fall (≤ 0.05 m across ≥ 30 frames — frozen means frozen); and after the splat the reticle is back in live mode within 0.5 s, still alive — it never frees mid-run | T-105 |
| reticle_main_lifecycle | the reticle's whole run lifecycle through the REAL main scene (the T-077 instanced-Main pattern, parked in its own corner, the bare test pigeon parked grounded first so the tap can only fire through Main's own player): exactly ONE reticle node (the `poop_reticles` group) serves the WHOLE scenario — live mode at the 10 m hover pins within 1.0 m of the hover state's hypothetical damped impact (the scenario's own independent recompute: its own down-ray for the surface, its own closed form and bisection; measured 0.03 m), alpha 1.0; one REAL tap freezes it and dims it to ≈ 0.25 immediately (the T-077 dim convention); the cooldown expires before the 10 m drop lands, so it relights to 1.0 while still frozen; the splat returns it to live with the node count unchanged (persistence — the anti-assertion to T-046's "group empties again"); grounding hides it entirely; and restart_run() mid-freeze recovers it on its own — visible, live, full alpha, the pigeon airborne (no restart-specific code) | T-105 |
| reticle_live_refresh_30hz | the reticle's LIVE re-march cadence is the T-110 tuned value, locked as a bare-rig value check (direct `poop_reticle.tscn` instantiation, no player — the derivation runs in `_ready`): `live_refresh_hz` 30.0 resolves to exactly 2 physics ticks of the fixed 60 Hz step (whole-tick quantization — 24 would round to an effective 20), so a silent revert of the export (T-105's 10.0 → 6 ticks) FAILs both arms; the live-mode feel itself is the Gate 3 line below | T-110 |
| poop_ready_indicator_tracks_cooldown | through the real main scene, the F glyph beside the hint line shows lit at full alpha while airborne with a rested drop, dims to ~25% the moment a REAL poop fires, stays dim through mid-cooldown, freezes with a paused tree and relights when the cooldown elapses in game time with no further press, hides entirely while grounded, and restart_run() mid-cooldown relights it (T-019 outline treatment asserted) | T-077 |
| car_blinkers_sit_on_the_body | (T-162, the `cafe_sitters_on_the_rig` mesh-probe family) the four amber corner lamps sit ON the paint body instead of hovering off the stretched sedan's corners: a bare CAR_SCENE instance (the traffic-null escape hatch) keeps the four Blink nodes at their unchanged `Visual/Blink*` paths, dark at rest (`visible == false`), in the research's sedan-lens class (every Blink BoxMesh ≤ 0.20 z × ≤ 0.07 y × ≤ 0.05 x — landed 0.16 × 0.055 × 0.035, no 0.3 m slabs) — and each lamp box, built from its BoxMesh size + node transform in Visual space, INTERSECTS ≥ 1 paint-mesh triangle at its station (same x-side, \|z\| within the lamp's z ± 0.25 m), the intersection being a Sutherland–Hodgman clip of the triangle polygon against the box's six planes — vertex-inside-box alone cannot see flat-quad interiors (the paint mesh is 438 vertices sampled at quad corners), so a hovering lamp free of vertices can never pass. The seat is re-derived from the paint mesh at `_ready` (`Car._seat_blinkers`, the `cafe_spawner _hair_offset` precedent — seeds (±0.63, 0.80, ∓1.90/±1.95), sink 0.015, measured seats (±0.63, 0.72, −1.89) front / (±0.63, 0.74, +1.94) rear), so a future re-bake cannot strand the lamps. Red-before (recorded in the ticket): the pre-T-162 scene transforms (±0.85, 0.82, ∓1.95) clear the nearest paint vertex by 0.094 m (front) / 0.117 m (rear) and fail all four intersection legs | T-162 |
| civilian_palette_reserved | the T-121 reservation law pinned bare: the civilian `BODY_PALETTE` holds exactly 5 entries and every entry keeps ≥ 0.20 Euclidean RGB from BOTH team colors (measured worst 0.61 vs TEAM_GOLD, 0.68 vs VISITOR_BLACK — the citizen_classes_readable contrast bar), so the old hue-twin gold/near-black civilian paints can never sneak back into the jackpot read; the scene carries the grown tell — pole mesh 0.06×0.9×0.06, banner 0.62×0.9×0.03, both flags hidden at rest, banner top 2.75 m (≥ the T-113 2.2 m read line) | T-121 |
| people_on_one_rig | (T-138, replaces T-124's `people_and_cars_swapped` — the bake era ends for people, cars stay baked) BOTH citizens instance the ONE shared rigged scene (`scenes/people_rig.tscn`, a `PeopleRig`) whose Model is the imported Quaternius pack metadata-stamped source pack + CC0 license; the imported scene carries the live 53-bone Skeleton3D and an AnimationPlayer pruned at import to EXACTLY the six-clip whitelist (`Rig|Idle`/`Walk`/`Sprint`/`Sitting_Idle`/`Sitting_Enter`/`Sitting_Exit` — no clip name contains the banned families, so the T-124 "referenced nowhere" audit survives), skinned Body/Legs/ArmL parts (53-bind skins, StandardMaterial3D surfaces — the per-class override duplication source) plus the rigid HeadRigid/ArmLRigid/ArmRRigid mount parts; the near RIGHT rigid arm is visible for BOTH citizens (the tourist's panic raise / foam finger drives it; since T-144 the elder drives it NEVER) while the tourist alone shows the rigid left and hides the skinned ArmL and the elder keeps the skinned ArmL riding the clips (the far arm); and the elder's hands stay DOWN is pinned STRUCTURALLY (the T-144 retirement tripwire) — after stepping the elder's own `_animate` the near rigid arm's basis reads IDENTITY (it rides its bone with the clip swing), so a reinstated meter's world-aimed `set_arm_pose` write fails by construction; the adult envelope is measured live — a strolling tourist's head bone + probe-pinned bone-to-top lands on 1.7507 m ± 0.02 over feet at 0 (scale 0.982, drop −0.0006, furniture probe: 2.05 m doors, 0.60 m benches, 0.78 m tables, 2.0 m plinth); the walk clip plays rate-matched (`speed_scale` == `walk_rate(walk_speed)` ± 0.02 on the live tourist, and the law itself `speed × 1.3333 / 1.3239` value-locked; the sibling scenario `locomotion_rate_ledger` (T-165) pins the sprint/shuffle/sit-pacing rates and the import-stamp ledger — the walk-rate leg stays only here); the splat capsule grew WITH the visual (tourist AND elder r 0.28 / h 1.75 at y 0.875); the car legs are kept verbatim (Kenney-derived meshes, shared wheel, box 1.9×1.45×4.4 at y 0.725); and the banned clip families are referenced nowhere in the rig's scenes, scripts, the import script or the spawners | T-138, T-144 |
| citizen_parts_world_scale | every part of a live tourist rig stays HUMAN-sized: the six imported parts (Body/Legs/ArmL skinned, HeadRigid/ArmLRigid/ArmRRigid rigid) each measure a world AABB under 3 m — correct parts measure at most 0.86 m (the rigid arms) and the T-139 corruption measured 85.8 m (the import's partition baked the shared `arm_l` build into the rigid path's meter frame, so the skinned ArmL wearing the mannequin-space bind skin rendered ×100 — the elder-only "enormous blobs" the owner playtest caught; tourists hid the mesh) | T-139 |
| locomotion_rate_ledger | (T-165; T-177 re-pin) the played-rate pins the suite never had — every read ± 0.02 `speed_scale` on the LIVE animation player: the four script constants vs the import stamps (walk/sprint stride+seconds), the PANIC sprint rate played vs the stamps on a bare tourist, and the shipped window-pace defaults (walk_speed 0.8, rise_seconds 0.6) value-locked off a bare seated elder. The MIGRATION WINDOW legs (rising/walking/arriving rates) retired with the Windrow bench grid — the real migration machinery routes over the block grid AND the bench seats, both empty on the cutover world until R2 re-points the elders (the staged-seat attempt crashes in the route math, recorded in the ticket); the walk-rate leg stays in `people_on_one_rig` | T-165, T-177 |
| elder_seats_on_the_bench | (T-141, sink re-derived by T-146 from the owner's after-screenshot) the seated elder lands IN the bench: an elder's own `_animate` layer stepped to settle (sink eased, `Rig|Sitting_Idle` playing) rides the DEF-hips BONE ~0.04 above the seat top (band 0.00–0.08 — the sit clip's near-horizontal THIGHS rest ON the 0.60 m seat and the glute settles 0.01–0.02 into the slab; the T-141 glute-line target +0.105 left the thighs ~0.07 high and a gap under the pelvis, and the T-138 child-scale derivation put the bone AT the seat and buried the pelvis ~0.16 into the slab), the feet stay above the pavement (the pack's sit pose dangles them — the accepted read), the hair prop sits on the scalp (center within −0.05/+0.10 of head-top through the mesh-pinned HeadTop mount — T-145; T-164: the hair MESH under that unchanged origin law is the fitted dome — the node origin this band reads never moved), and the constants are value-locked (`SEAT_SINK` −0.465, `HUNCH_SEATED` 0.04 — the T-110 precedent; `tools/probe_sit_geometry.gd` re-derives them from the pack clips). (T-163) the lock set grows the `SEAT_SLIDE` rig-z lock (−0.25 — the seat-contact slide eases onto the same visual while seated, root untouched on the spot) and re-verifies the hips 0.00–0.08 band against it — the slide is z-only | T-141, T-146, T-163 |
| cafe_sitters_on_the_rig | (T-142) the café crowd wears the ONE people model: every sit key (`sit_body`/`sit_legs`/`sit_head`/`sit_hair_cap` — T-164 re-keyed the hair: the fitted dome replaced the retired `sit_hair` box, which the swap tripwire now pins absent) renders one instance per sitter, the baked meshes metadata-stamped (source pack, CC0, `pose_clip == Rig|Sitting_Idle` — the pose the elders hold, so both crowds read as one species), `sit_body` tinted by the unchanged tourist-palette law, the retired box keys absent (swap tripwire), and the baked figure measures human — the seated body/legs AABB bands reject the standing-pose bake (feet −0.013, hips 0.95) that the no-tree import produced twice before the hand-computed pose chain landed. (T-163 re-word: the sit transforms now also carry the seat-contact pin + facing slide — those live on the spawner constants and are locked by `sitters_clear_their_seats`; this row's AABB bands stay mesh-level and pin-insensitive by construction) | T-142, T-163 |
| hair_caps_round_the_skull | (T-164) one fitted dome cap on every head (elder hair, superfan cap, cafe sitter hair — the three retired BoxMesh slabs swapped for `PeopleRig.hair_cap_mesh` domes, the node origins never moving under the T-145 mount law): the SHAPE law on all THREE cap meshes — tri count >= 96 (the retired boxes carry 12) and the y-binned radial taper, the top-20%-band max horizontal radius <= 0.75 x the base-20%-band max (vertex bins over `get_faces()` about the mesh's own xz center; probe: dome 0.47 at 24x12, box 1.00 — the dome tapers, the box's top-face corners keep full radius); the FIT law against each mount's live head AABB (the rigs' HeadRigid bind AABB via the new `PeopleRig.head_aabb()` accessor, the cafe's harvested `sit_head` bake AABB): per-axis plan poke <= 0.01 on the half-extents about the AABB centers, cap base at head end.y − `HAIR_CAP_SINK` ± 0.01 (rim sunk onto the skull, not perched), cap apex >= head end.y − 0.03 (the crown read survives), the rig legs pinning the drop equation the bands lean on (`HAIR_CAP_SINK == −HEAD_PROP_LIFT − HAIR_CAP_BASE_DROP`, 0.08 = 0.05 + 0.03); VALUE LOCKS (the T-110 precedent) `HAIR_CAP_SINK` 0.08 / `HAIR_CAP_HEIGHT` 0.10 / `HAIR_CAP_BASE_DROP` −0.03 / segments 24x12; REALIZATION — each cap mesh is a ONE-surface ArrayMesh with a non-null surface-0 StandardMaterial3D in the retired placeholder's own color (a bare SphereMesh return would land its base circle 0.03 high and fail the rim band by construction — the round-1 alternative kept impossible). The elder/tourist legs read the live `Hair`/`Cap` nodes post-_ready — each node's mesh IS the offset dome (the drop baked into the vertices, no child node, no re-homing), so `mesh.get_aabb()`/`get_faces()` see it directly; the cafe leg reads `visual("sit_hair_cap").multimesh.mesh` plus the harvested `sit_head` bake AABB and every queued cap transform (its sit_root translated by head-center x, head end.y − HAIR_CAP_SINK, head-center z; one instance per sitter; the retired `sit_hair` key pinned absent). Red-before (ticket-recorded, probe-confirmed): the shipped boxes fail SHAPE on every mount (12 tris, taper 1.00) and the elder/tourist boxes fail the FIT plan leg (+0.0124/+0.0112 pokes > 0.01); the cafe box passed FIT and failed only SHAPE — a cap must BE round, not merely sit right | T-164 |
| sitters_clear_their_seats | (T-163, the ONE seat-contact law on both surfaces) café legs — every queued sit_root carries the landed pin + facing slide relative to its own queued stool (origin-exact, both facings, every sitter; the inert SITTER_SHAPE collider's offset from the stool center is exactly the yaw-rotated slide), and the harvested `sit_legs`/`sit_body` bake measured in root space against the stool constants (top 0.45, slab 0.39..0.45, plan ±0.18) lands the thigh sitting line at 0.455 (band [top−0.01, top+0.05] — the thighs ON the stool), the forward shin's slab-band crossing at root z ≤ −0.027 vs the front-edge limit +0.00 (ε 0.01 — past the stool's front face; red-before −0.043 INSIDE, sinking 0.073 into the slab), the visible soles at −0.001 (≥ −0.01; red-before −0.081 under the pavement); bench legs — the SitBake bake read off a settled live elder (its own `_animate` composite: plane 0.60, `SEAT_SINK` −0.465, `HUNCH_SEATED` 0.04, `SEAT_SLIDE` −0.25) against the bench constants (wood top 0.54, slab 0.46..0.54, edges ±0.25): the thigh line 0.569 (≥ wood−0.01, ≤ plane+0.05 — the T-146 contact read kept, the slide is z-only), the forward shin's slab-band crossing at slab z ≤ −0.260 vs the −0.24 limit (red-before −0.010 INSIDE — the owner's "shins through the bench front face"), the deepest sitting-line vertex at +0.092 ≤ rear edge +0.26 (the glute ON the seat; red-before +0.342 past it); value locks: `SIT_HIPS_SEAT_LIFT` 0.08 (the T-146 hips family cap — bone at stool + 0.08), `SIT_ROOT_Y` = seat+0.08−hips, `SIT_SLIDE` 0.17, `SEAT_SLIDE` −0.25, `SEAT_SINK` −0.465 untrimmed; `tools/probe_sit_geometry.gd` measures the same three lines on both surfaces | T-163 |
| bread_steal_favor_deltas | (T-177 re-pin) the steal surfaces, bare rigs over the resident Ames world with the Main wiring (`crumb_favor` → `Game.add_favor`) connected on the rig and the relays captured: a live TABLE crumb — a REAL café tabletop now (the T-176 venue tables) — eaten grounded emits exactly `Game.favor_steal_table`; a hand-dropped `drop_crumb(pos, Game.favor_steal_visitor)` crumb pays exactly `+favor_steal_visitor`; an ordinary GROUND crumb pays 0 and emits nothing. The retired tailgate leg (parked VISITOR cars anchor the crumbs, the bijection + gutter-offset geometry, the recycle re-anchor) died with the Windrow fleet and re-pins beside R2·parking | T-114, T-177 |
| favor_max_ends_run_victory | (T-177 re-pin) the ceiling ends the run as a VICTORY through the REAL main scene (instanced-Main pattern, pigeon held airborne): favor staged 2 under `favor_max`, ONE jackpot booking through the REAL autoload entry Main's relay feeds (`Game.splat_favor(VISITOR, true)` — the retired duck-typed car relay died with the Windrow fleet, its machine home is R2·calm-port's) — favor reads EXACTLY `favor_max`, the tree pauses, the score screen opens in the VICTORY register (title, gold dim, note, the plain breakdown + the Favor total) while hunger stands, and Esc stays locked; a further booking past the clamp moves nothing and fires no second `favor_maxed`; coexistence legs (first-wins, restart re-arms, the SAME Main starving into the STARVED! register) byte-unchanged | T-115, T-177 |
| score_combo_style_values | the Game autoload pays DESIGN values (tourist 100 · car 30), the chain escalates ×1 → ×2 → ×3 across target kinds and resets on landing and on the 20 s window, and the +50% style bonus demands a release that is fast, low and fresh | T-009 |
| score_high_score_persists | beating the record writes user:// at once and a fresh Game loads it back | T-009 |
| highscore_save_throttled | only the run's FIRST record-beating hit pays a synchronous disk write (T-073): 20 bare tourist hits against a planted record of 100 perform exactly ONE save and leave the file at the first-beat score (300, not the cumulative 21,000 the chain reached — combo escalation 100×1 … 100×20, no landing/release staged so the style gate can't fire), then emitting the Game-owned `hunger.game_over` flushes exactly one more write and the file reads the final 21,000 (`_save_count` delta exactly 2 across both legs; the file is read back through an independent ConfigFile, never `load_high_score()`) | T-073 |
| favor_max_book_clamps_and_flushes | the T-115 ceiling's book legs, bare autoload in the `highscore_save_throttled` window (directly after it): from `reset_run()` a `add_favor(-50)` reads −50 and emits delta −50 (the T-114 no-floor lock intact); with the T-073 dirty state staged (`_saved_this_run` true, `_high_score_dirty` true, a beaten record) one `add_favor(favor_max + 25)` leaves favor EXACTLY `favor_max` (never over), emits the APPLIED delta (150, not the requested 125 — the clamp's arithmetic), performs exactly ONE disk write and the file reads the final score back through an independent ConfigFile (the victory path's flush — the hunger path's twin, fired from inside `add_favor`'s one-shot latch); a further `add_favor(10)` clamps silently and fires NO second `favor_maxed` (and no further write); and `reset_run()` re-arms — a second climb re-fires exactly once, its flush a no-op while the record is clean | T-115 |
| favor_meter_names_the_ceiling | the goal layer announces itself (T-116), through the REAL main scene (instanced-Main pattern, pigeon held airborne so no ambient crumb feed can move the balance mid-read): `Game.favor_max` is value-locked at 100 (T-115's tuning — a silent retune FAILs the leg by design), the meter's rest form is `Favor: <n> / <max>` interpolated from the export (no literal in `main.gd`), the gold gain note reads `Favor: <n> / <max>  (+6)`, a staged −3 balance re-rendered by a zero add reads `Favor: -3 / <max>` (the T-114 no-floor debt shown, not hidden), and `restart_run()` resets to `Favor: 0 / <max>`; the scene-static `%FavorGoal` caption row sits under the meter (unique-name resolved, offset below the label) with the exact text "max the elders' favor to take the town", the column's 4 px outline at 14 px font and the dimmer white @ 0.6 caption fill — the scene owns the text and no code writes it, so these asserts are the whole contract; the T-039 scenario's footer leg grows the rules-line guard alongside (footer names "favor" and "town") | T-116 |
| score_popup_floats_and_fades | the world-space popup shows "+100 ×2" at the hit position, floats up, fades and cleans itself up; since T-059 it renders 1.5× taller in the world (pixel_size 0.015 at the unchanged font_size 96) and the lone popup still rises exactly rise_height (index 0); since T-059 a chained arm drives a REAL main scene's own hit_scored spawn path with two tourist hits 8 m apart in depth inside one second — exactly two popups stay alive in the group, labelled the bare combo payouts "+100" then "+200 ×2" (reset_run() re-stales `_release_age` to 999 and it only grows, so the style gate cannot fire — no styled "+300 ×2" is reachable by this recipe), carrying rise_totals exactly rise_step apart (1.8 m and 2.7 m at the landed values) | T-009, T-059 |
| score_popup_style_tag_format | the static popup format variants: a styled hit appends the STYLE tag in both multiplier shapes (`"+150 ×2 STYLE"` / `"+150 STYLE"`) while every unstyled form stays byte-identical (`"+150 ×2"` / `"+150"`) | T-038 |
| score_popup_style_tag_live | through the REAL main scene's `hit_scored` path: staging the chain explicitly (grounding reset, then a fresh fast/low release — ≥ 14 m/s from ≤ 6 m) before a tourist hit spawns a popup reading `"+150 STYLE"` — the chain's first hit, ×1, 100 × 1.5, the Why's bare-150 case labelled — tinted the HUD pulse gold `Color(1.0, 0.85, 0.3)`; the slow-release follow-up (chain at 1, ×2 plain, 200 paid) spawns `"+200 ×2"` with no tag and no gold; the two earlier unstyled popups have freed by the read (1.2 s lifetime vs ~1.6 s elapsed), so exactly two popups are alive in the group. (T-151) These are the SYNTHETIC `Game.add_tourist_hit` entries — Main's class stash stays empty, so the popups claim no class word and the STYLE gold wins over any favor tint; the class-named forms live in `hit_feedback_names_the_class` | T-038, T-151 |
| pause_freezes_world | Esc-pausing through the real PauseMenu stops the flying pigeon dead mid-air and the hunger clock with it; resuming hands both back | T-010 |
| title_escape_does_not_quit | a synthetic Esc (`pause`) action fed straight to the real title scene's `_unhandled_input` neither quits the process nor pauses the tree — the menu instance survives; a regression re-adding the quit branch kills the whole Gate 1b run at that line (`flap`/`quit` are never fed — they would change the scene / quit the harness) | T-097 |
| game_over_shows_score_screen | starving through the real main scene opens the score screen — score, high score, tourist/car breakdown — freezes the run dead and keeps Esc locked. (T-151) Its three hits are the synthetic entries, so Main's tally stays empty and the breakdown keeps its legacy contains-form — the exact per-class split is pinned in `hit_feedback_names_the_class` (starved) and `favor_max_ends_run_victory` (victory) | T-010 |
| restart_resets_run | restart through Main.restart_run() zeroes score/breakdown, refills hunger, clears the game-over latch, keeps the world identity (the Ames bake's fingerprint unchanged — the score comparability law) and re-seeds the services: (T-178 re-pin) the fleet arms read the AMES reality — the tourist fleet stays inert until R2·pedestrians while the traffic graph re-seeds a FRESH moving fleet on the real streets (exactly `target_moving` traffic cars, no reused pre-restart instance id) and the bread service re-seeds to its target, and the pigeon returns to the spawn corridor | T-010, T-177, T-178 |
| restart_same_seed_skips_rebuild | a real main.tscn restart through Main.restart_run() takes the same-seed fast path — build_count stays 1, fingerprint/spawn_point/last_report untouched, exactly one `regenerated` — while every spawner re-seeds off the emission; (T-178 re-pin) the re-seed reads the AMES fleet reality: the traffic graph stages a fresh moving fleet (exactly `target_moving` traffic cars, no reused pre-restart ids), the tourists stay inert until R2·pedestrians, the bread service back at target — on the resident world the seed-identity law is the DATA-identity law (the bake hash), pinned by `stepped_boot_pins`' forced-rebuild arm | T-033, T-177, T-178 |
| hud_bread_pointer_tracks_nearest_crumb | the HUD bread pointer names the nearest living crumb (distance within 1 m; `nearest_crumb()` matches an independent scan and returns null when none is alive) and, since T-111, aims the BREAD GLOBE — the pigeon-frame drawn instrument that replaced the chevron lineage (T-037's slot, T-057's screen-space rebuild, T-098's climb cue and T-058's stern suffix all retired into one geometric encoding): every arm is `reset_flight` → 2-frame wait → sample (the widget reads NO camera — the T-057 chase-camera convergence loops are gone), and every direction expectation is the scenario's own recompute off the LIVE player basis (`basis.inverse() * delta.normalized()`, dot ≥ 0.999), never through the widget's code. The steering contract: a scan-decided `drop_crumb` 10 m down the nose axis at hover height reads `dir_local` (0, 0, −1) within 0.01 — the machine form of "steer along the segment and you intersect the bread" — with the tip on the fly-to pip within 1 px and `screen_offset` up (y < 0) and axial (\|x\| < 1); the SAME crumb at yaw 180 tracks its own recompute with `dir_local.z` > 0.9 and the segment drawn DOWN; a grounded pigeon under a placed ~10 m overhead crumb draws \|screen_offset\| strictly LONGER than dead-ahead (foreshortening orders ahead < above — the 25° vantage tilt is load-bearing); a hover with a placed crumb 5 m behind-below reads stern (`dir_local.z` > 0, `screen_offset.y` > 0). The text is the minimal remainder — `_pointer_distance_m` parses ONLY strict `<what> <n> m`, so any re-introduced ▲/▼ cue or " — turn around" suffix turns every distance assert to −1.0 and fails (asserted bare on the overhead, stern and city arms). The flash state machine: a just-eaten target's re-aim flashes (`flash_active` true right after the real grounded waddle-in eat), a nearer placed crumb flips it true immediately with the text re-aimed ± 1 m, it settles back to rest within flash_seconds (0.4 s = 24 frames) of game time, steady same-crumb frames never re-flash, city frames never flash, and the first acquisition after restart_run() never flashes; (T-134 re-derivation: the eat leg picks the ground crumbs NEAREST the spawn point in order and waddles each until one eats — the route deals shifted the parking stream so the nearest crumb can now be a tailgate crumb whose +Z approach faces street furniture, which would embed the drop — the flash/re-aim contract rides whichever crumb was eaten); the zero-delta guard keeps the last drawn direction, finite — never a NaN — through a direct `_aim_bread_pointer(pigeon_pos, "bread", 0.0)`. City mode at the yaw-90 edge hover still reads "city <n> m" ± 2 m of the horizontal distance with the globe aimed at city.spawn_point through the same mapping (a stern homing read is now geometric). The readout decreases on approach, eating the pointed-at crumb through the real grounded waddle-in re-aims at the next-nearest, and the label keeps the T-019 outline treatment | T-037, T-111 |
| hud_hunger_warning_tiers | the HUD score/hint outlines resolve through the theme, the hunger bar's four warning tiers map the 50/25/10% bands through the real Main scene, the danger tiers pulse in game time (tier 3 faster than tier 2) and falling back restores the rest color — via refill and restart_run; since T-080 the bar also resolves its own `background`/`fill` StyleBoxFlat overrides (dark translucent track, pure-WHITE fill — the tier-modulate invariant — both with the dark-outline border ≥ 1 px on all four sides); since T-075 a standing-percent boundary arm pins the tier-OR-percent bar-write guard (50.4% → 49.98%: percent 50 throughout while tier 0 → 1 — the bar value still rewrites and the tier repaints) | T-019, T-080, T-075 |
| hud_combo_strip_reports_last_hit | through the real main scene, a `%ComboStrip` label sits under the pointer block with the T-019 outline treatment and starts empty; emitting the spawners` splat relays — (T-177 re-pin) the relay nodes STAGED BARE (one bare tourist + one bare car instanced into the rig, the fleet on the resident Ames world being empty until R2; the retired fleet read crashed this scenario on the cutover tree and leaked its Main, double-counting every global effect downstream) — the strip reads \<Class\> +100 / \<Class\> +200 x2 / \<Class\> car +30, every hit markers its body, the strip expires in game time and restart_run() clears it mid-display | T-040, T-151, T-177 |
| hud_combo_note_on_landing | through the real main scene, a landing while a ×2+ combo is live shows "landing ended the ×2 combo" under the strip row (T-019 outline treatment, hidden and empty at rest) for 2.5 s of game time, then clears itself and stays cleared; the landing is driven through the REAL `grounding_changed` signal — Main's handler is connected BEFORE `Game.on_grounding_changed`, so the note provably reads the PRE-reset streak (a connect reorder fails the shown leg, which is the load-bearing invariant the scenario keeps covered); a landing with no live combo shows nothing, and restart_run() mid-display clears it | T-079 |
| pause_menu_shows_controls | through the real main scene, the pause panel's Box carries the two recap lines as its last two children (below the buttons) — hidden with the panel at rest, shown by the first `toggle()` (tree paused, both labels visible), hidden again with the panel by the second (tree unpaused); each line carries exactly its constant's key families, matched bi-directionally against `MainGame.HINT_AIR` (W/S, A/D, Space, F) and `HINT_GROUND` (W/S, A/D, Space), so a future constant edit that drops or gains a family fails the gate; and both labels carry the T-019 treatment (14 px, outline 4, black-0.85 outline, white-0.75 fill) | T-099 |
| title_screen_teaches_controls | through the REAL menu scene, a visible ControlsLabel sits under the Footer naming every first-run family AND its printed keycap (W/S pitch · A/D turn · Space flap · F poop · Esc pause — a reword dropping either half of a pair fails), every keycap resolves to a real InputMap action — all seven `flap`/`poop`/`pitch_up`/`pitch_down`/`turn_left`/`turn_right`/`pause` (the divergence guard for the by-design duplicated copy; scene files cannot reference `main.gd`'s HINT_AIR) — and the line carries its own treatment, 15 px white @ 0.7 with NO outline (the T-019 flat dark-navy finding: absence of a local override plus zero effective outline); the same run reads the game-over Hint through a REAL main scene as exactly "same city every run — race your best" with neither "seed" nor "regenerate" left in it | T-039 |
| pigeon_air_poses_track_flight | wings out in a glide, a wing beat on every real flap impulse (and the beat ends), wings swept back in a dive — the pose mirrors the flight state | T-011 |
| pigeon_ground_poses_track_waddle | grounded settles into the folded stand, waddling flips to the waddle pose, stopping settles back to stand; since T-048 the fold also thins the wing chord — the grounded legs assert the pivots' eased Z scale ≤ 0.5 (default 0.35), a fresh airborne set-up re-opens it to ≥ 0.95, and reset_pose() returns it to exactly 1.0 with both wing pivots' scale.z back at 1.0 (the root-only scale reset never reached them) | T-011, T-048 |
| pigeon_pecks_when_eating | eating a crumb through Main's exact wiring (crumb.eaten → Player.peck) plays the peck — the beak dives down and the overlay ends | T-011 |
| pigeon_realistic_visual | the presentation (T-011's drive() contract unchanged) instances the rigged realistic Blender pigeon — a child scene sourced from `assets/models/pigeon_realistic/pigeon_realistic.glb` (instanced at 2.6× with a −0.292 m drop onto the b6 ground line) carrying MeshInstance3D meshes and an AnimationPlayer with all six sculpt clips (glide/dive/flap/peck/stand/waddle) — and still tracks flight poses on the retained pivots: wings unswept airborne (sweep < 0.3), folded grounded (sweep > 0.7). Replaces the T-107 B6 check and the T-108 static-mesh check | T-108, T-109 |
| juice_feather_poofs_on_hard_flap | a fully-rested flap poofs feathers; a re-flap inside the throttle window doesn't spam another | T-013 |
| juice_dust_puff_on_landing | a gentle glide touchdown kicks a dust puff at the feet, which cleans itself up | T-013 |
| juice_landing_shake_decays | a touchdown kicks a small camera shake (never full trauma) that moves the lens and decays to dead still (T-133 hardened the drop, bars untouched: the old (0, −3, −9) recipe arrived at ≈30.3° — ON the 30° `max_land_angle_deg` settle bar, so cross-scenario float state decided settle-vs-skid and with it a 0.32 vs 0.11 trauma; −12 m/s forward re-derives the arrival to ~24° / trauma ~0.37, unambiguous — and the check window now samples a pinned noise phase, since the shake pattern rides a `_shake_clock` that accumulates across the whole run and a shifted phase landed the window on a near-zero patch, failing `moved` with a healthy shake) | T-013, T-133 |
| hit_shake_and_score_pulse | through the real main scene, a combo escalation shakes the chase camera, pulses the HUD score line and shows the ×2 — both settle back; the sun is warm and capped at ≤ 1.15 energy | T-013 |
| audio_buses_and_assets | the Master/SFX/Ambience bus mix exists with the ambience bus quieter than SFX, every ticketed sound loads as a real stream, and both ambience beds are flagged to loop forever | T-012 |
| audio_boots_muted | the game boots MUTED (T-101) — the real autoload path muted Master in the harness process itself at boot, and the opt-in contract holds: PIGEON_SOUND=1 opts in, the pilot's PIGEON_MUTE=1 wins over `--sound`, the `--sound` user arg opts in, and no opt-in stays silent | T-101 |
| sfx_flap_effort_fires | a takeoff flap whooshes without the effort beat; a flap mid-climb adds the strained wing-beat; a flap while falling stays quiet | T-012 |
| sfx_peck_plays_on_eat | a grounded pigeon eating a crumb through Main's wiring plays exactly one bread peck | T-012 |
| ambience_loops_under_game | main.tscn starts both ambience beds on the Ambience bus, start_ambience() is idempotent across restarts and the bed survives the scene teardown | T-012 |
| settings_persist_and_invert | the T-122 settings, pinned at the Game seam plus an end-to-end flip: with NO settings file `load_settings()` early-outs (boot mute stands, identity controls); `pitch_axis()` reads the raw axis (0 at rest, +1 on held W) and NEGATES with `invert_pitch`; the live pigeon's nose answers the SAME held key in OPPOSITE vertical directions across the toggle (raises when off, lowers when on — the convention-free proof every flight consumer reads the helper); a save round-trips through an independent ConfigFile (invert, volumes, muted) and `load_settings()` restores it onto the live state AND the buses (SFX at linear_to_db(0.5), a stored unmute unmuting Master); every touched bus + the boot mute restored before returning; the grounded waddle keeps its raw axis (forward/back is not pitch) | T-122 |
| sfx_coos_and_stingers | the T-123 voice, driven end to end: a grounded hands-off pigeon coos on the idle cadence (coo_idle ≥ 1 within 10 s, zero waddle coos) and chats on the faster waddle cadence while walking; the smug coo rides tourist-splat parity exactly — a first splat is silent, the second fires coo_smug exactly once; and through ONE real Main both endings sound exactly once each — the real ceiling crossing (favor staged max−1, one add_favor) plays stinger_win with the victory screen open, a restart re-arms, a 60/s drain starves into the starvation register with stinger_lose and no second win — audible despite the same-frame tree pause (the always-on ending voice); the hunger knob and the staged Main restored | T-123 |
| boot_splash_pinned | the T-125 splash swap pinned as project settings: `application/boot_splash/show_image` false (no Godot logo on any launch) and the splash background EXACTLY the title screen's navy — read live off an instantiated menu scene so the two can never drift apart; a revert to engine defaults fails here | T-125 |
| web_quit_gated | the T-126 quit seam, BOTH branches through the real scenes: desktop (override OFF = shipped default) keeps the title footer's Q hint and a visible pause-menu Quit button; web (override ON) strips the footer hint, hides the Quit button, and a fed quit ACTION is IGNORED at the title AND inside an open pause menu — the harness surviving both feeds is the proof (an ungated quit would kill it); the `Game.is_web()` seam (single function, `web_override` force) restored to OS-truth afterwards | T-126 |
| density_cpu_budget | the real main scene at the resident reality — the Ames bake (184 chunks, ~600 placeholder colliders, occluders), the LIVE traffic fleet the T-178 graph stages on the real streets (the fleet arms assert the moving+parked contract, so a half-staged fleet fails the gate; tourists stay inert until R2·pedestrians), bread, pigeon — must keep the headless CPU cost per physics frame under the kept 750 ms-per-100-frames budget (the median now runs with 26 cars driving the graph; measured 549.4 on the T-178 tree) | T-018, T-177, T-178 |
| off_world_fall_returns_home | a fall below the off-world guard line (past any floor) fires the reset exactly once — counted twice since T-095, through the `off_world_resets` counter AND a local counter wired to the new `off_world_reset` signal, each exactly once across the whole window — snaps the pigeon home to the respawn corridor and lands it there within ~2 s, stays parked home with no second fire over the following ~2 s, and the hunger clock keeps draining straight through the reset | T-036, T-095 |
| off_world_return_beat | the PRESENTED return through the real main scene (instanced-Main pattern, own space): the guard fires exactly once — counter AND signal, the signal's `from` equal to the void departure position — and Main answers with the full beat: a `juice_effects` feather poof at `from` on the reset frame, the warm HUD fade up right after the reset and fully gone (≤ 0.01) within ~1 s of game time, the chase camera within ~1.5 m of pigeon + UP × 1.4 on the first frame after the reset (the snap, not a lerp), the "home again — mind the edge" note shown then self-expired, grounded on the respawn corridor within ~2 s, no second fire across a further ~2 s, Game.hunger drained > 0.2 across the window; a second fire re-runs the beat and restart_run() mid-note clears note and fade unpaused | T-087 |
| edge_nudge_turns_home | (T-177 re-pin) the prevention layer ahead of the guard, wired to the FLAT rig world — the nudge is a flight-model feature, world-independent; the 367 m radius is the value the feel was tuned at (the retired Windrow apron arithmetic) and the live Ames wiring is world-owned (`AmesWorld.home_radius`, pinned by `ames_world_api_seam`'s containment arm): reset 417 m from home, 50 m past the radius, mid-ramp, nose dead away — 3 s hands-off rotates the heading ≥ 30° back toward home while y never drops below 0 and the guard never fires | T-023, T-177 |
| touch_layer_desktop_inert | the desktop/headless path is byte-unchanged (T-119): the touch layer is HIDDEN (no touchscreen) and inert — a synthetic contact at the stick spot moves nothing — the safe-area layout is a no-op (zero offsets on the touch SafeArea AND the HUD layer, the T-087 return fade un-expanded, the StatsLabel still at its scene spot with the HungerBar beside it), and the InputMap's non-builtin action set reads EXACTLY the shipped eleven (`flap`/`poop`/`pitch_up`/`pitch_down`/`turn_left`/`turn_right`/`boost`/`pause`/`restart`/`to_menu`/`quit`) — zero new actions, live-read so a smuggled-in action fails the same night it lands. Probed facts the touch block leans on (ticket T-119): the stub headless window is 64×64 and the GUI drops contacts outside it, so the touch scenarios size the window to the desktop default 1280×720 first (restored after — every other scenario keeps today's conditions); on a sized window the real pipeline (`Input.parse_input_event` + `flush_buffered_events`) delivers GUI touches and TouchScreenButton actions but a synthetic screen touch does NOT emulate mouse, so the ordinary Pause button is driven with the synthetic mouse click a tap produces on-device (`emulate_mouse_from_touch` is the project default); and `Input.action_press` strength bypasses the InputMap deadzone (0.2 reads 0.2) — what the stick feeds IS what the player polls | T-119 |
| touch_stick_drives_action_axes | a synthetic screen-drag on the T-119 joystick steers through the SAME action axes the player polls: a 40 %-radius deflection reads clearly non-zero turn with the pitch pair exactly at rest (the deadzone trap — gentle deflections must not read zero), strictly weaker than full deflection, which reads > 0.9; and the pigeon itself flies the held drag — 60 frames of full-left stick bank the body (basis.x.y > 0.2) and yaw > 0.3 rad, 40 frames of full-up stick raise the nose > 0.15, and lifting the finger returns every axis to exactly zero | T-119 |
| touch_stick_rest_reads_exactly_zero | the stick-at-rest contract that keeps the T-082 trim arm alive: never-touched reads exactly 0.0 on all four steering actions; a held full-up drag then finger-up returns every action to EXACTLY 0.0 (strength and both axis compositions); and the end-to-end proof — settled cruise, an 8-frame stick pitch-up (the keyboard scenario's own entry hold), released by lifting the finger — shows the nose easing back toward the flow over 90 hands-off frames at the same `HSO_NOSE_TRAVEL_BAR` `hands_off_glide_trims` pins (a stick that leaked strength would freeze the trim here) | T-119 |
| touch_buttons_fire_real_actions | the Flap and Poop TouchScreenButtons fire the REAL actions: a synthetic screen touch on Flap produces exactly one flapped impulse through the player's own polled `_flap`, and one on Poop drops a real, valid, finite-velocity Poop through the polled `_try_poop` (counted by the harness's `pooped` listener) — no new input path exists to verify | T-119 |
| touch_pause_button_toggles_real_pause | the ordinary Pause button pauses through the REAL PauseMenu of an instanced main scene: the tap's emulated click (driven headless as the synthetic mouse click the tap produces on-device) opens the real overlay — tree frozen, `is_open` — and a tap on the panel's own Resume button unpauses; the full touch pause loop, no keyboard involved | T-119 |
| touch_multitouch_steer_and_flap | overlapping synthetic contacts steer + flap at once: finger 0 holds a full-left stick drag while finger 1 lands on Flap — the turn axis stays live (> 0.9) THROUGH the second contact, a real flap impulse fires in the same window, the pigeon yaws > 0.3 rad under both, and lifting both fingers returns every axis to exactly zero | T-119 |
| touch_button_layout_pins_tuned_values | the T-130 owner-dictated thumb ergonomics pinned the T-019 way, read back from the LIVE touch layer: the Flap shape's radius is exactly 68 canvas px (52 → 68 — the "fly button too small" fix, a full thumb-pad target), Poop's stays exactly 52, `button_gap` is exactly 30 (18 → 30 — the "poop button too close" fix), and the Poop center sits exactly `flap_center + (-(68 + 30 + 52), -30)` — the `_layout()` offset asserted against the pinned literals, not the live constants, so a silent revert of either tuned constant (the .tscn shape radius or the script gap) fails the same night | T-130 |
| gamepad_actions_bound | the T-127 mapping pinned live, event-for-event: stick axes 0/1 on `turn_left/right`/`pitch_up/down` at deadzone 0.25 (button actions keep 0.5), A (b0) on `flap`, RT (axis 5) + X (b2) on `poop`, Start (b6) on `pause` — all joypad events on device −1, `restart`/`to_menu`/`quit`/`boost` carrying NO joypad events (the mapping invents nothing), `ui_accept`/`ui_cancel` carrying A/B beside their re-declared engine-default keys (Enter/KP-Enter/Space, Escape), `ui_up`/`ui_down` keeping the engine-default dpad + left-stick traversal, and the action set still EXACTLY the shipped eleven (the T-119 pin, re-read here); behaviorally, a synthetic `InputEventJoypadMotion` through `Input.parse_input_event` drives the REAL axes — 0.2 reads exactly 0.0 (under the deadzone), a gentle 0.3 deflection reads non-zero (the discriminating probe: reads 0.0 at the old 0.5 default), full deflection > 0.9, A/RT/X/Start read strength 1.0 on `flap`/`poop`/`pause` — and the pigeon itself flies the held stick (40 frames stick-up raise the nose > 0.15, 60 frames stick-left bank > 0.2 and yaw > 0.3 rad), every axis back to exactly 0.0 on release; the REAL PauseMenu opens on pad Start (Resume takes focus), resumes via pad A on the focused button, moves focus on the dpad, and backs out on B; the title stays inert to a synthetic `InputEventAction` and to non-Start joypad buttons (the T-097 gate, joypad edition — a live pad Start would change the harness's own scene, so that leg is Gate 3's) | T-127 |
| stepped_boot_pins | (T-177 re-pin, T-178 fleet arm) the stepped world boot pinned at four seams: the AmesWorld slices callable IN ORDER on twin rigs (`generate_step_ground` → `generate_step_blocks` → `generate_step_finish` compose byte-identically to the sync build AND the harness's resident world — fingerprint, bread spots, kinds, report (the report now carries the traffic-graph fields), the spawn corridor — the retired Windrow seed-hash law's successor is the DATA-identity law: a forced rebuild at ANY seed reproduces the SAME manifest-hash fingerprint), main.tscn's staged-boot defaults (hold_generate + every spawner), the game-path Main boots stepped while the rig-path Main syncs (the phases named, ms ≥ 0, the fleet arms reading the AMES reality — the graph built, a fresh moving+parked car fleet staged on the real streets, bread at target, tourists inert), and the web warm-up diet both branches | T-129, T-177, T-178 |
| web_handoff_single_screen | the T-131 single-warming-screen contract: the Fly-press handoff's branch decision lives behind menu.gd's `_web_loader_covers_handoff()` and pins both ways through the T-126 `Game.web_override` seam on the REAL menu scene — the forced-web branch covers the handoff with the export shell's loader (true; the shell's identical navy/words made the T-129 double paint) and desktop does not (false — its one-frame WarmupNote is the feedback there), while `%WarmupNote` exists and stays hidden AT REST on BOTH branches (a note shown outside the desktop handoff — the double-screen bug's shape — fails); `_start_run` itself is never driven headless, it ends in `change_scene_to_file` and would swap the harness's own scene (the T-097 never-feed-flap rule), so the on-screen single-screen judgement is the hosted-web Gate 3 line below | T-131 |
| pilot_time_scale_flag | the T-132 agent slow-mo contract: the flagless boot this very process ran stands at `Engine.time_scale` 1.0 (normal launches — and every other gate scenario here — run exactly that path), the parse seam's truth table holds through the REAL `Game.pilot_time_scale` autoload function (the `--time-scale=` user arg beats the `PIGEON_TIME_SCALE` env; absent, garbage, NaN, negative, zero, above-ceiling and below-floor values all resolve 1.0, so a mistyped flag can never silently mean something), and the rate contract is measured the way the game lives it — the SAME 60 physics frames accumulated from the harness node's own delta run 1.0 game-second at scale 1.0 and ≈0.1 (tolerance 0.05–0.2) at scale 0.1, per the 2026-10-22 binary probe (tick rate never changes in either pacing, every delta scales), with the restore to 1.0 re-pinned so no later scenario inherits a slow world | T-132 |
| pilot_frame_step | the T-140 frame-step contract, driven through a REAL CaptureRecorder in session mode (scratch `simtest_step` dir) plus a pausable inline-script probe whose `_physics_process` only runs on live ticks: it counts them and latches whether `flap` was ever pressed visible to the game. Four legs: a `{"step":N}` while UNPAUSED is refused (`pilot_step_ignored` logged, tree stays live); `{"pause":true}` freezes the probe dead (tick delta exactly 0 over 10 recorder frames); `{"step":30}` advances 26-35 live ticks (the +4-tick window pad absorbs the measured 2-3-tick unpause lag — a raw-window revert lands ~0 and fails) and re-freezes; and a flap hold queued in the SAME command file as the step latches `saw_flap` true — the deferral that lets queue-then-step work, where a press made while frozen would expire unheard one tick wide. The tree and both env vars are restored however the leg ends | T-140 |
| dev_hunger_lock | the T-167 dev-verb family on the pilot channel, driven through a REAL CaptureRecorder in session mode (scratch `simtest_dev` dir) acting on the Game autoload's own clock with `drain_per_second` hand-raised to 60/s for the run: after 90 unlocked ticks drain ~90 units, `{"dev":"hunger_lock"}` through `_execute_dev` (the family's single seam, called with an explicit dict — no command files needed for the seam legs) freezes the bar BIT-IDENTICAL across 90 more ticks with zero `changed` emissions (the locked `_physics_process` returns before any state write — flap heat included); `{"dev":"hunger_refill"}` restores exactly max while locked; `{"dev":"hunger_unlock"}` resumes the drain (max − value > 20 over 90 ticks). The gate seam: with `allowed=false` (the suite cannot flip `OS.is_debug_build()` — tests pass the seam explicitly, the production `_pilot_step()` call site passes nothing) all three verbs log `pilot_dev_refused` and move no state, an unknown `{"dev":...}` logs `pilot_dev_unknown` and is still consumed by the seam (T-168/T-169 extend the dispatcher, never bypass it), and a non-dev dict returns false (the routing's non-dev dicts unaffected). The LIVE channel: lock+refill queued through real command files land while the tree is PAUSED (the recorder is PROCESS_MODE_ALWAYS — verbs flow when frozen), the lock holds bit-exact through live ticks after resume, and `hunger_unlock` from the channel releases the drain again. The tree, the autoload clock (drain constant, lock, player, value) and the session env are restored however the legs end | T-167 |
| dev_verb_pack | (T-178 re-pin) the starter verb pack on the pilot channel, driven through a REAL CaptureRecorder in session mode (scratch `simtest_pack` dir), re-pinned onto the Ames traffic graph — the staging verbs work UNCHANGED on the new graph, the ack contract intact, through the spawner's own graph paths: with the "CarSpawner" name vacant `spawn_car` refuses `no_spawner`; a staged empty rig's `car_blinker` refuses `no_car`; `teleport` lands the player ON the spawn corridor with velocity exactly zero and the resolved position acked; `spawn_car` then WORKS through the graph's curb path (one car stages PARKED near the pigeon — the measured nearest-curb distance printed — the ack carrying node path, position and post-spawn fleet size, the fleet reading exactly the staged car); `car_blinker` on:true forces the NEAREST car (the staged one — the ack's `car` equals the spawn ack's `node`, `blinker`/`forced` read the side) and on:false releases it; `freeze_traffic` holds the world (the static flag, the ack, the recycle cadence HELD bit-identical across 90 ticks AND the staged car's transform held, resume works); and the gate seam (`allowed=false` consumes every verb but moves no state, unknown verbs log `pilot_dev_unknown`) with every ack/refusal machine-checkable off the events file (T-179 re-verified green on the calm-port tree, the `pilot_dev` payload shapes unchanged — spawn_car {node, p, fleet}, car_blinker {car, blinker, forced}, freeze_traffic {on}) | T-168, T-177, T-178, T-179 |

| dev_call_verb | the T-169 call verb on the pilot channel, driven through a REAL CaptureRecorder in session mode (scratch `simtest_call` dir), every leg fired through `_execute_dev` with an explicit dict passed through the scenario's `_json_round_trip` helper FIRST (the round-1 review's channel reality: Godot's JSON parser delivers every number as a float, so a hand-built GDScript dict proves nothing about the live verb — the legs drive it with the types the channel delivers), `allowed` default (the headless sim is a debug build). Targets: the Game autoload's own hunger clock through the dotted-property path (`Game.hunger` — child nodes and node-holding script properties resolve; no wildcards, no search), the harness pigeon through its absolute /root path, and a tests-only CallProbe (tests/call_probe.gd) whose typed methods pin the coercion surface. (a) the happy path: after 90 ticks of a 60/s forced drain, `{"dev":"call","node":"Game.hunger","method":"eat","args":[10.0]}` raises the bar by EXACTLY 10 (synchronous read — no drain tick interleaves) and the `pilot_call_result` ack carries node/method with the void return serialized as JSON null; (b) THE coercion rule: a [x,y,z] array into the probe's Vector3-typed parameter RUNS the method (tell reads Vector3 — an uncoercing verb would have type-refused pre-call), the same shape into Array-typed and untyped parameters stays an Array (tells read `Array:3:float` / `Array:2` — the array-stays-an-array law), the same shape into the pigeon's `reset_flight` via its /root path lands it on the target with velocity exactly Vector3.ZERO, an undershoot into `probe_defaulted` fills the 2.5 default (required = total − `default_args`, and 1 ≥ 1 — the method list names the defaults), a two-float call returns 3.5 through the serializer, and the CHANNEL-TYPE pins (the round-1 defect): a bare JSON `[1]` into the probe's int-typed parameter and a string into its NodePath-typed parameter both RUN (`int:1` / `node_path:CallProbe` — the parser delivered 1 as a float and the engine converts float→int and String→NodePath, proven live in the review's set_blinker_forced [1] and has_node ["Player"]); (b3) THE CACHE-SPLIT PIN (the round-2 defect — the per-class key shipped with no re-verification path): the SAME `set_scale` name driven on a bare Label (Vector2) then a bare Node3D (Vector3) then the LABEL AGAIN — exactly the order that poisoned the round-1 name-only cache (the review's rv1/rv1b set_scale sessions) — with all three consumed, both result acks present, and the scale READBACKS proving the landings (label Vector2(3,3), Node3D Vector3(2,2,2)): a regression back to the name-only key turns the third call into a type refusal while every other leg stays green; (c) error paths: unknown node, unknown method, OVERshoot arity and UNDERshoot arity each log `pilot_call_error` (unknown_node / unknown_method / arity — the round-1 review caught undershoot logging a FALSE void-success with result:null and hunger unmoved; the method dict's `default_args` makes required computable, so eat [] now refuses pre-call), the pair carries exactly two eat error events, the refusals move no state, and the harness continues through all of them; (d) the denylist: the direct names `free` and `queue_free` aimed at /root/Game refuse (`denied_method`) and the autoload survives the following frames, a call aimed at the recorder's own node path refuses (`recorder_node` — no self-calls into the channel), `_pilot_step` aimed anywhere refuses, AND the review-found dispatch/write escapes all refuse: round 1's `call` and `callv` wraps of queue_free on /root/Game, `set("value", 50.0)` and `set_deferred` and `call_deferred("reset")` on Game.hunger, and `/root` `propagate_call` aimed at `_execute_dev`; round 2's thread-safe/indexed SIBLINGS — `set_indexed`, `set_thread_safe`, `set_deferred_thread_group` (each wrote hunger live: 99.88→50.0→40.0→30.0), `call_thread_safe` and `call_deferred_thread_group` (dispatched reset live, and queue_free'd a spawned car, corrupting the fleet) — and `set_script [null]` aimed at the probe (stripped a car's script live via the typed-Object-accepts-null arm, leaving a bare CharacterBody3D in the fleet), with the probe's script proven INTACT after the refusal (has_method + get_script) — each `denied_method`, hunger unmoved through the following frames under the locked drain clock (a slipped deferred would have landed), Game alive, all TWELVE wrap pairs carrying their denied_method error, and NO `pilot_dev` event anywhere in the session's events (the review's propagate_call acked hunger_refill from inside the recorder); (e) the gate seam: with `allowed=false` the verb is consumed but refuses (`pilot_dev_refused`, verb "call"), moves no state, and exactly one eat result ack exists (a leaked refused call would log a second). The tree, the autoload clock (drain constant, lock, player, value) and the session env are restored however the legs end | T-169 |
| pilot_window_hide_math | (T-170) the hidden-launch geometry, pinned as a PURE value lock on `CaptureRecorder._hide_position` — no OS calls (this headless DisplayServer has no window; the OS-level proof is `pilot.py focuscheck` below): the EXACT return for the three ticket monitor layouts at the 1280×720 client — this machine's side-by-side (0,0)+(2560,0) → (−1360,−800), a negative-left-monitor (−1920,0)+(0,0) → (−3280,−800), a single screen (0,0) → (−1360,−800) — each followed by an independent clearance recompute showing the window rect ≥ 80 px clear of EVERY monitor rect on at least one axis (min screen corner minus window size minus the 80 px margin, so the machine's measured ≤ 8/≤ 31 px frame slop can never drag a monitor edge back into view), a second window size (640×360 → (−720,−440)) proving the size input flows (a hard-coded 1280×720 fails it), and the GUARD leg: a real session-mode recorder under `PIGEON_WINDOW_HIDDEN=1` in this headless run logs `run_start` (session mode started) but NO `pilot_window_hidden` — the `DisplayServer.get_name() != "headless"` guard skips the leg with no event and no error, exactly as legacy flag-file mode is skipped by construction (the leg lives in `_start_session`). The env and the tree are restored however the legs end | T-170 |
| ames_data_integrity | (T-171) the committed Ames city database is load-bearing, read through the REAL `AmesDataPack` loader (static class, no autoload) as the suite's FIRST scenario — pure data, touches no pigeon/city/physics. COUNTS vs the census (the pack IS the census, made load-bearing): 3,737 buildings (512 named; exactly 512 in the `authored` class against `authored-buildings.csv`'s authored-named set, the 50 semi-tagged riding the procedural side the census §6 table assigns them), 5,637 tree nodes, 48 venues in the 14/17/17 tier law, 15 landmarks (the Top-15-from-the-air list), and the rail crossing ledger pinned BY NAME — exactly 9 at-grade vehicular crossings carrying the census §5/§7.11 road set (13th, 9th, North Hazel, Brookridge, the unnamed service, Duff, Grand, Kellogg, Clark), so an extra or misnamed crossing fails the same night; street centerline km under BOTH named rules: (a) the graph rule streets[] pins — census §4 midpoint rule, named drivable classes — within [91.4, 92.4] (measured 91.93, with the scenario re-summing every stored polyline against the meta value within 0.05 km), because streets[] is the street GRAPH the city code consumes (per-way runs with class/width semantics); (b) the ticket's 99.6 km, which REPRODUCES exactly under its own committed rule — extra3.py §5 (every way with a `highway` tag and a name, NODES filtered to the core bbox, haversine over the consecutive survivors — folds cycleway 6.2 / service 2.9 / pedestrian 0.7 km into one sum): `python -I docs/references/ames-survey/osm/scripts/extra3.py docs/references/ames-survey/osm/ames_merged.json docs/references/ames-survey/osm/raw` prints "named-road length inside proposed core window: 99.6 km" (run at landing), the distiller implements the same rule with a hard guard, and the pack carries the figure as `meta.street_km.named_highway_in_core_extra3_km` (pinned [99.1, 100.1], measured 99.6) plus its per-class table `named_km_by_class_extra3` — the round-1 draft was wrong to call 99.6 non-reproducible; what it is NOT is a street SET, so it rides in meta while streets[] keeps the census §4 graph; SENTINEL transforms against independently-coded closed-form expectations (111,320·cos(42.02°) m/°lon, 111,074 m/°lat, origin Lincoln Way × Welch at −93.65015/42.02278 from verification §1): the Campanile (`way/183041212`, census-literal −93.64604/42.02543) and the MU (`way/183224150`, 2229 Lincoln Way, census-literal −93.645762/42.023667) each within ±3 m of expected (measured 0.28 m / 0.04 m — the gap is the doc's 6-decimal rounding, not drift), the MU pinned NORTH of Lincoln Way (z ≤ −90 m band, measured −98.5) with Cy's Roost SOUTH (the F-06 orientation both ways), and the loader's `wgs84_to_local` reproducing the pack's stored centroids within 0.25 m from each sentinel's own stored 6-decimal wgs84 (the storage roundings: 1e-6° ≈ 0.11 m — the transform-twins lock; the first landing's 0.05 m band was wrong twice over: it compared the DOC literal against the pack's PRECISE way centroid, a 6-decimal-rounding gap of 0.27 m the ±3 m leg already owns); LINCOLN WAY reads E–W at lat 42.0228 — all stored polyline nodes within 40 m of the line, net bearing within 5° of E–W (measured 0.43°), mean lat 42.0228 ± 0.0002 (measured 42.02282); ACCESSORS — `nearest_street(origin)` lands ON the Lincoln Way × Welch crossing within 10 m (measured 0.19 m) on a street of that crossing — Welch-named or Lincoln Way — because the intersection's own slip lanes are OSM-named "Welch Road" (the first landing's two-name allowlist failed on real data), the campanile POI carries its landmark rank 4, `facing_to_yaw(90°)` is −π/2 (compass facing → Godot yaw), and `AmesDataPack.ATTRIBUTION` equals the pack meta's attribution string "Map data © OpenStreetMap contributors" (the ODbL obligation, README today / credits screen at T-197). Provenance for the byte-identity claim lives in the distiller (`python -I tools/ames_distill.py` re-run → byte-identical pack, verified at landing and re-runnable from the three committed inputs: `osm/ames_merged.json`, `census/authored-buildings.csv`, `census/tagged-nodes-core.json`) | T-171 |

| ames_bake_census | (T-172) the committed chunk bake is load-bearing, read through the REAL `AmesBaker` output (`res://data/ames/chunks/` — manifest + 184 chunk files, ~3.48 MB (the T-174 dressing added one ground-cells-only tile — chunk (4, 5), two cells; T-175's placeholder approximations added the 11-tile cx=13 column at the recorded tank/elevator/bandshell positions — the round-0 build's 6 extra tiles were the out-of-core venue fixups' leak, removed in round 1)) beside `ames_data_integrity` — pure data, no rig/city/physics. COUNTS (every figure derived IN-scenario, never trusted from the bake): manifest totals == the sum of the chunks' PARSED ARRAY LENGTHS for all THIRTEEN `AmesBaker.FAMILY_KEYS` arrays (the v3 bake's count — v1's eight, the T-174 dressing families: lane/shore/tie/ground, and T-175's placeholders; and each chunk's own `counts` field == its arrays — a miscounted chunk fails by file); `massing` sums to EXACTLY the pack's 3,737 buildings with occluder outlines 1:1; `ribbons` == the pack's non-degenerate street polyline segments recounted from `AmesDataPack.streets()` (3,750); `creek_quads` == the creeks' non-degenerate centerline segments recounted from `water()` with the T-174 lake-interior skip — College Creek FEEDS the lake, so segments whose midpoint lies inside the LaVerne ring union paint no ribbon (the lake flat is that ground's surface; the scenario mirrors the skip through its OWN ring walk + ray cast; measured 397, six skipped); the lawn TRIANGLE AREA sums to the 31 park polygons' ring-split shoelace within ±1 % (measured 1,451,392.0 = 1,451,392.0 — triangulation may re-cut, never lose); EVERY building position (all 3,737 — the 512 authored included) must sit in its own floor-divided 256 m tile's chunk with a massing center within 0.05 m of the pack centroid; the 9 at-grade rail crossings ride the chunk manifests BY NAME (the census §5/§7.11 set) and each carries a REAL gap proven GEOMETRICALLY on the baked output: the crossing's road is every ribbon quad the bake laid within 40 m of the crossing pos (both carriageways of divided roads — the pack carries one street entry per carriageway), the scenario requires ≥ 1 such road quad per crossing (no vacuous pass), and NO ballast quad may overlap any of them (strict SAT on the baked corner data — overlap or shared edge fails; the baker keeps a 0.2 m hairline). Red-before (review round 1, measured by the reviewer and reproduced in-session with clip-area geometry): the first landing's midpoint-radius check was tautological — it measured the baker's own skip rule against itself and never fired while ballast painted OVER crossing asphalt at Kellogg 85.5 m², Clark 63.9, Grand 24.4, North Hazel/Brookridge 1.6 each (177 m² total; Kellogg's ballast stopped 4.4 m short of a ±6.6 m road, Grand covered 2.5 m of a ±10.2 m road, and Clark/Kellogg's second carriageways got no gap at all); the doctored-bake teeth run fails the new arm with `ballast quads over crossing-road asphalt=1`. LaVerne PACK PRESERVATION — the baked `water_tris` sum to the pack polygon's ring-split shoelace within ±1 % (measured 11,067.7 m² = 11,067.7 m²; AC amended 2026-11-09, orchestrator-approved per V-12 — the drafted ±2 % of the DNR 11,300 m² figure was unsatisfiable against the faithful pack: the OSM ring is 2.06 % off it, the survey's own settled 2.5 % simplification gap, so the scenario asserts preservation and the DNR figure lives in a comment, never asserted). The ring-split is load-bearing twice over: the stored lake sequence is TWO joined OSM ways sharing a seam (repeated vertices at both ends), the scenario's splitter closes loops at repeated vertices independently of the baker's (the no-self-test rule), and the two red-before shapes are recorded — a naive ear clip double-covers the lake at 23,993 m² and the raw shoelace undercounts it at 11,039.8 m² | T-172 |
| ames_bake_determinism | (T-172) the bake is a pure function of the pack: in-scenario, `AmesBaker.bake_to_dir` re-bakes the committed data pack into `user://` through the same core `tools/bake_ames_chunks.gd` uses and must reproduce the committed manifest EXACTLY — the same 184-chunk file set (T-174's re-bake added the ground-cells-only tile (4, 5); T-175's placeholder approximations added the 11-tile cx=13 column — the recorded tank/elevator/bandshell positions; the round-1 fix removed the six tiles the out-of-core venue fixups had grown), the same per-chunk SHA-256 for every file, and the same `total_sha256` (`bff6c21115f85c4dca89aa9082c6cf035b441d715807de1175fe3ca7d4631427` — re-pinned at T-175's round-1 fix; the round-0 placeholder hash was `a58f2f2b10b686eabbd1e288ecf2e3cef01bb5d703cbc5fcf9abfaeed48c02c5`, T-174's dressing hash was `32e502ed9c95e668541125f1f070bd250c972e16314b148701a15ec823eaeb13`, v1's was `c61fc319b45714cc1a51353a4521f315fe4bbe20a6a2a9cf2365d1587b75573e`; also reproduced by two consecutive tool runs at each landing). No RNG, no wall clock, snapped floats, sorted JSON keys, sorted write order — a nondeterministic float, iteration or hash anywhere in the bake fails here the night it lands; the scratch dir is swept afterwards | T-172 |
| ames_world_render_budget | (T-173) the resident baked world renders the WHOLE committed bake inside the perf budget, chunk-partitioned: `scripts/ames_world.gd` (`scenes/ames_world.tscn`) builds every chunk as ONE small node family — the massing boxes AND every ground rectangle (street ribbons, creek quads, rail ballast — all rectangles) as vertex-color unit-box MultiMeshes with per-instance baked colors (the city.gd house style), the lake/park triangles as a separate double-sided triangle MultiMesh, each MultiMesh frustum-cullable via `custom_aabb` = the chunk's manifest AABB, plus ONE baked `ArrayOccluder3D` per MASSING-bearing chunk (flats-only tiles asserted against the manifest, not trusted from the build — 26 of the 173 v2 tiles; T-175's placeholder tiles are placeholders-only by the same assertion; each massing box's four side walls, both windings, heights index-aligned from the massing) — resident, no streaming (master plan §2). Measured, not assumed: the built instance count equals the committed bake totals (massing+ribbons+lane+shore+creek+ballast+ties+ground+water+lawn+placeholders — the renderer consumed everything, so the memory metric is honest; T-174's dressing flats fold into the same per-chunk box MultiMesh, so the draw ceiling moves only by chunks gaining a flats family: 372 → 376; T-175's placeholders add their own per-chunk `Placeholders` MultiMesh — never fading — while the 8 hero buildings' superseded bbox boxes are SKIPPED from the massing draws, so the honest expectation is massing − heroes + placeholders), the whole-world draw ceiling (mm_nodes, every chunk visible) and the two ticket-pose ceilings — a probe camera mid-band of the chase rig (fov 75, engine-default far 4000) at cruise over Campustown (60 m over the band, pitched −20°, looking east) and low-hover over downtown (20 m, pitched −10°) — all stay under the FIRST-VALUE budgets draws ≤ 800 / chunk memory ≤ 400 MB (the resident buffer estimate: MultiMesh transforms+colors at 64 B/instance + occluder verts + compact ground records; the parsed JSON is dropped at build, so the footprint stays proportional to the geometry), and the massing distance band is on (visibility_range_end 1800 m, 250 m margin, FADE_SELF — the ribbons/patches never fade: the ground read stays). The pose read is the scenario's OWN frustum test — the engine camera's `get_frustum()` planes (the same math the renderer culls with) against each chunk's manifest AABB via its 8 corners (all-8-over-ANY-one-plane excludes; a camera inside the AABB is visible). First measured values print on the `SIM DATA` line; a budget retune re-derives the gate (the budgets are consts beside the assertion, documented), never weakens it | T-173 |
| ames_world_api_seam | (T-173) the gameplay seam: gameplay code does not know which world is live — `AmesWorld extends City`, so every public API gameplay reads answers with identical signatures over chunk data, and every expected value is recomputed INDEPENDENTLY from the committed bake (the no-self-test rule): the ground query's massing leg re-reads chunk (0, 0) from `data/ames/chunks/` and takes its TALLEST massing box, then `ground_height()` (the new seam query — top of the tallest box covering an XZ point, else 0.0 for the ground plate, from the retained per-chunk compact records; the parsed JSON is dropped) must answer exactly that box's top over the box's footprint center; the plate leg re-scans the four origin tiles' committed massing for ANY box covering the pack origin (Lincoln Way × Welch — a street crossing, so none may) and the origin query answers 0.0; the district lookup (`district_at()` — the baker's own v0 rule via `AmesBaker._district_of`, so a lookup can never disagree with the baked dressing) pins the four families at independently-derived points (Campustown band off Lincoln Way at (−300, 60), downtown band off Main Street z ≈ −256 at (2700, −256), the campanile's campus anchor at (340, −294), past-every-band residential at (1500, 900)); the tile-crossing leg (round-1 review) scans every committed chunk file independently for the box with the largest overhang past its centroid tile and requires `ground_height()` to answer that box's top BOTH at the footprint center AND at a mid-overhang point that lies in the NEIGHBOR tile (the scan skips the T-175 hero ids — their superseded bbox massing no longer serves the ground query, the silhouettes file their own true tops — so the worst crossing box is now the worst non-hero: the pre-T-175 worst was the bowl's 77 m z-overhang, way/613735866) (red-before, live call-verb evidence in the ticket: centroid-only filing answered the plate 0.0 — way/183218202 read 12.0 at center but 0.0 at (−291.52, −450.35) inside the same 170.5 m footprint); the guard-containment leg (round-1 review) recomputes every manifest chunk AABB's corners and requires the WIRED guard circle to hold them all (red-before: the round-1 build pinned the center at the pack origin — the map's west edge — with a 2335.2 m radius, leaking 1,719 of 3,737 boxes incl. 226 of 269 downtown: the T-023 nudge banked the pigeon home over downtown, reviewer's live A/B yaw 0→1.10 rad in 4 s over Main St while the Campustown control held 0.00; fixed world-owned center = bake bounds center (1263.4, −60.7), radius = bounds half-diagonal + margin 2782.1, worst corner 2473.9; re-pinned at T-175's round-1 fix: the placeholder heroes grew the east bound to the recorded tank position — center (1334.1, −64.1), radius 2842.5, worst corner 2485.1, containment margin 357.5; the round-0 build's out-of-core venue fixups had leaked the guard to radius 3897.49 / center (1022.0, 25.6, −205.4), kicking the T-023 nudge ~1.1 km out over featureless plate); the spawn corridor equivalent is the pack origin itself — `spawn_point` sits `spawn_drop_height` above the plate exactly at (0, 0, 0) city-local; and the world is FLYABLE: the real rig pigeon drops into the corridor and settles grounded on the ground plate (physics top y 0, layer 1 `world`, bounds from the manifest + 250 m apron — the plate at y 0 the baker's flat stack reserved), then one grounded flap returns it to flight over the skeleton (the `flap_takes_off_ground` contract). (T-177) the world setting IS ames now — `Game.world` defaults "ames", `WORLDS` carries only that value (a `windrow` flag or saved setting resolves to the default like any unknown value — no debug toggle, the owner fork master plan §11.2), and Main swaps the world root at `_ready` on EVERY boot (game scene and instanced-Main rigs alike), wiring the guard circle through the world-owned `home_center()`/`home_radius()` methods. (T-176 re-pin, anticipated by this row's landing note: the survival spawn moved off the pack origin to Central Campus near the campanile — the corridor arm now pins the campanile POI + `SPAWN_CAMPANILE_OFFSET_X` east at ground-answer + drop, massing-clear there, and the flyable drop re-runs at the new spawn) | T-173 |
| ames_skeleton_palette | (T-174) the baked skeleton's DRESSING is machine-checked over the committed chunks (pure data, no rig — beside `ames_bake_census`): the per-district GROUND palette is PINNED (five districts, exact colors — campus lawn green #66874C / Campustown scruffy gray #847E72 / downtown brick-warm sidewalk #A07052 / Lincoln Way strip asphalt #55524C / the residential seed #61754D that also IS the ground plate's color via `AmesBaker.DISTRICT_GROUND`, so plate and untinted cells are one source of truth) and BOUND CELL-EXACT: every baked `ground_quads` entry (3,359 baked — T-174's 3,230 plus the 129 the T-175 placeholder tiles' ground grid added; cells exist only where the v0 district rule says a district other than the residential seed stands, 32 m grid over the whole pack tile range) must carry the pinned color of `_district_of` AT ITS OWN CELL CENTER, no cell may claim the residential seed, no duplicates, and the four known-band pins (Campustown (−300, 60), downtown (2700, −256), campus (340, −294), Lincoln Way strip (1000, 4)) each find their district's cell underneath; the nine flat-family colors are pinned per chunk in EVERY chunk file (asphalt ribbons, the #C7B35A lane dash, the lake's #46543F olive, the #6F8F4F mown shore, the GREEN-BLUE #466663 creek ribbons (distinct from the lake olive by RGB gap 0.158 > 0.05 — creeks must not read as more lake), mown lawn, #8B8578 ballast, #4A443A tie stripe, the ground fallback) — the vertex-color discipline: dressing rides baked per-instance data, never materials; the arterial lane dashes RECOUNT EXACTLY from the pack's polylines under the same 3 m dash / 9 m period arithmetic on the four NAME-matched corridors only (Lincoln Way / Main Street / Duff / Grand — 1,647 dashes; residential streets stay plain asphalt; every corridor paints ≥ 1); the LaVerne shore band is one quad per non-degenerate ring-split edge (117 — recounted through the scenario's OWN ring walk, shared with `_pack_split_area`), every quad center within the 7 m band width of the lake ring (measured worst 3.50 m), baked at y 0.008 so its rendered TOP (0.008 + FLAT_THICKNESS/2 = 0.018, the band being a 0.02-thick BOX) stays UNDER the water — which is a FLAT TRIANGLE at exactly y 0.02, no thickness; the ground cells sit lower still (baked at y 0.004, tops 0.014) and the scenario pins all three stack heights against `AmesWorld.FLAT_THICKNESS` AT SCENARIO LEVEL (the round-1 landing ran this arm nested inside the shore-hug failure branch — dead code on a passing bake — and its first draft also put cell tops at exactly 0.02, coplanar with the water, which depth-fought the lake into lawn; both fixed, the arm fires every run) — a sharp ring corner can poke the band inside the lake without ever painting it; the rail tie stripe rides the ballast 1:1 (1,055 = 1,055), every tie strictly overlaps a ballast quad (32 m-bucket SAT), and no tie overlaps crossing-road asphalt within 40 m of any of the 9 at-grade crossings — the T-172 honest gaps extend to the dressing | T-174 |
| ames_placeholder_dims | (T-175) the landmark placeholders are load-bearing at their SURVEY dims — pure data over the committed chunks (beside `ames_bake_census`, no rig), every expected value recomputed INDEPENDENTLY from the pack + survey literals (never baker consts): AUTHORED SLOTS — every one of the pack's 512 authored buildings rides a massing entry flagged `a` (the collision-bearing slot the R3 heroes replace, T-176's roof-crumb host) and the flagged id SET equals the pack's authored id set exactly (ids stable across rebakes by identity with the pack); VENUE FIXUPS — the placed venue POIs whose address anchor no authored bbox covers, IN-CORE venues only and never a venue the pack marks a PROP (`note` carries "prop"; the round-0 landing had boxed the Superdog hot-dog CART into a storefront standing square in Welch Ave — 206 m² of road overlap, a solid wall across Campustown's main street 170 m from spawn, and had dropped lone collision boxes at the four out-of-core venues, growing the manifest bounds x[−821.8, 3348.6]z[−1504, 1375.8] to x[−1446, 3490]z[−2891.2, 2480.3], the guard radius to 3897.49 and the ground plate with it — all fixed in round 1) each carry exactly one fixup box within 0.05 m of the POI position (11 at landing: café Beaudelaire, Welch Ave Station, Paddy's, Sips, Mickey's, Aunt Maude's, Mr Burrito, the Stan Tap, Blue Owl, Blue Fish Poke, Stomping Grounds — the census §2 anchors OSM never polygonized), the excluded five (superdog + the_cafe/provisions_lot_f/szechuan_house/hickory_park) are pinned ABSENT, and NO fixup box overlaps any street ribbon quad (strict SAT road-clearance arm on the baked output — the round-0 depth-16 boxes of the Lincoln Way frontage clipped 10–24 m² of asphalt; the depth is 10); HERO DIMS within ±2 m of the survey's settled numbers (verification/VERIFICATION.md §5, literals in the scenario): campanile 33.5 m tall on the 6.8 × 6.7 plinth (measured 33.50/6.80/6.70), Marston 51.2 m (51.20), Jack Trice bowl ring 183 × 208 m (measured 183.10 × 208.06 on the `bowl` role only — the V-11 berms are checked separately to REACH PAST the north rim), Hilton drum 138 × 105 (138.24 × 105.68), MU 110 × 110 (109.80 × 109.90), Parks 95 × 123 (95.50 × 122.90); the depot, bandshell, both municipal bulbs and the SE elevator cluster pinned PRESENT at their recorded positions (tanks/elevators: survey-anchored approximations — V-30 UNVERIFIED heights/dims, asserted present, not dimmed); THE RANKING'S NON-BOX LANDMARKS — Lake LaVerne's water flat 236 × 122 m ±2 (measured 235.8 × 122.4) with the MU block 13.7 m from its east shore (V-08 adjacency ≤ 20 m) and the campanile 264.1 m off the lake center (survey ~264 ±5), Central Campus lawn ≥ 7.6 ha within 300 m of its POI (V-25), ballast under the UP-main-line POI (the Duff crossing), and the three out-of-core POIs (Reiman/Ada Hayden/airport) carrying `in_core=false` — fly-out targets per survey §1.9, no in-map duty. Red-check (recorded): the height pin sabotaged 33.5 → 31.0 FAILs exactly `hero way/183041212 top 33.5 != survey 31.0 (+-2)`; the berm arm fired live during landing (berms stubbed short read `896.2 >= 893.2`) | T-175 |
| ames_placeholder_landable | (T-175) the landable campanile cap — the anchor scenario pattern (`city_roof_landable` / the api_seam flyable leg), re-targeted onto the committed bake: the cap + shaft entries are read INDEPENDENTLY from the chunk files, then (a) layer-1 placeholder colliders are probed through the REAL physics space — a horizontal ray into the shaft's west face at mid-shaft must hit at the 4.9 m shaft's face (±0.3 m) and a ray at x −60 off the bowl axis, run past the south rim under the 14 m ring, must hit the ring at the survey-ellipse offset ≈ +91.6 m ±4 (the offset chosen to clear the Sukup Endzone slot that honestly closes the south end — the first landing's center-line ray hit SUKUP, which is itself a live collider and the recorded red run); (b) the real rig pigeon drops from 3 m over the cap top (33.5 m) and settles GROUNDED on the pad at its 0.3 half-height, then one grounded flap returns it to flight (peak > cap + 0.8); (c) the cap keeps the crumb rule — exactly one ROOF bread spot at the cap top + `City.ANCHOR_CRUMB_LIFT` (±0.005), the city.gd anchor-cap convention, T-176's first roof-crumb host | T-175 |
| ames_bread_reach | (T-176, supply leg re-pinned by T-177) the survival re-base, machine-checked against the committed data with every expected value recomputed INDEPENDENTLY in-scenario (the no-self-test rule): SPAWN — `spawn_point` local XZ is the campanile POI + `SPAWN_CAMPANILE_OFFSET_X` east (master plan §11.1), district "campus", the ground query answers the plate, a REAL drop settles grounded and one flap returns to flight, and the nearest living crumb measures ≤ 60 m flat from the spawn (the boot ring seeds the 8 nearest ground spots FIRST on every populate; landed 20.6); REACH — nearest spot ≤ 150 m flat from ANY sampled point of the pack's core window (100 m grid, spatial hash rebuilt in-scenario from the live `world.bread_spots` — landed worst 110.6, ZERO samples over); SUPPLY — (T-177 re-pin) the crumb total ≥ the PINNED SUPPLY FLOOR 10500 (the retired "Windrow baseline" comparison has no Windrow world left to measure; the floor pins the measured Ames supply — 11346 at the committed bake, kinds 8,682 ground / 6 table / 2,658 roof — with headroom for losing a whole placement layer); CAFÉS — every in-bounds café venue of the VENUES.md coffee list carries a table spot near its POI with a TABLE-class crumb on the tabletop, `world.cafe_spots.size() == served` (landed 6 real cafés served, bar 3) | T-176, T-177 |
| ames_hunger_pins | (T-176) the economy pins, diff-proven across the re-base: the hunger drain quartet (`drain_per_second` 0.45, `flap_drain_multiplier` 2.0, `flap_heat_seconds` 0.7, `grounded_drain_multiplier` 0.6 — the T-005 feel constants the ticket freezes) and `favor_max` 100 (the T-115 ceiling) pinned as deliberately duplicated scenario literals (the `DISTRICT_GROUND` pin pattern), read off a FRESH `Hunger` instance AND the LIVE autoload clock, then re-read after a FULL ames world build+fill (the re-base's placement-only contract proven: the clock is byte-identical before and after the 11,346-spot build, with a non-vacuity arm asserting the world actually built spots) — hunger and favor never move on ames; the drain bars themselves stay the Windrow rows (`hunger_drain_flap_vs_glide`, `hunger_game_over_once`) | T-176 |
| ames_bread_spawner | (T-176 round 1) the Ames spawner under the SHIPPED knobs, held to its bounds — no Gate 1b check ran the spawner against Ames before, and the un-capped tree grew the live count forever there (measured red-before: populate 40, then +30 per top-up — 70 → 100 → 130 → …, exactly 40 + 30·n: the 6 café TABLE spots can never cover the 36-table quota so the shortfall re-spilled into GROUND every respawn_interval, walking the ground class toward all 8,682 spots; the growth also silently inflated the round-0 Ames autoplay's `eaten=21`). The fix caps every class fill by the FLEET deficit (`BreadSpawner._fleet_deficit`, recomputed per class as the pass proceeds), so the live total converges to the budget and can never grow past it on either world — on Windrow the cap is a no-op wherever the classes reach their quotas (awning supply ≥ 66 vs the 36 quota), and the first populate's spread is byte-identical there. The row holds the bound: BOOT — the real spawner seeds the world at target 40, the spread lands at-or-under target, and the boot ring (`City.boot_bread_spots` — the 8 ground spots nearest the spawn, seeded FIRST on every populate; empty on Windrow, byte-green) holds the nearest living crumb ≤ 60 m flat from the spawn (landed 20.6); BOUND — eight direct top-up cycles with nothing eaten stay exactly at target (40 → 40 → …; the red-before tree read 70 at the same probe) and a real-timed window (~10 ticks at a compressed `respawn_interval`) stays at target; RECONVERGE — eating 3 crumbs through the same emit path a grounded pigeon fires, then three top-up cycles, refills to EXACTLY the target, never past | T-176 |
| ames_street_flyover | (T-177) the flyover re-pin — the retired `city_street_flyover` re-derived against the resident Ames world, the master plan's own exit-demo corridor: Lincoln Way from the pack origin east (the longest-x-span `primary` polyline, recomputed INDEPENDENTLY from the pack; landed 610 m), flown at the Gate 3 bar of 60 m with the cruise velocity re-imposed every 90 frames (the density pattern — the flight model bleeds speed), the clearance bar recomputed from the committed bake (the tallest massing/placeholder box overlapping the corridor's ±12 m lateral band; landed 26.0 m — 5 m of margin under the bar): the pigeon must cross from the west end to the east end with min y above the recomputed top + 5, lateral drift under the band, every velocity and position finite | T-004→T-177 |
| ames_roof_landable | (T-177) the roof re-pin — the retired `city_roof_landable` on the resident Ames world: the AUTHORED building recomputed INDEPENDENTLY from the committed bake (the `a`-flagged massing box nearest the spawn corridor with top in [4, 20] m and ≥ 20 m out) is landable — the T-175 placeholder colliders make every authored slot solid — a drop settles grounded at the box top and the pigeon waddles > 0.15 m | T-003, T-175, T-177 |
| ames_roof_takeoff | (T-177) flapping off the authored Ames roof returns to flight — the `city_roof_takeoff` leg byte-for-byte on the re-pinned building (peak > top + 0.6) | T-003, T-177 |
| ames_traffic_routes | (T-178, round-2 re-pin) the traffic graph end to end: the shape recomputed against the census §4 stock (777 runs / 91.9 km, per-class km within 0.15 of the census table — primary 10.0, secondary 16.3, tertiary 13.1, residential 48.7, unclassified 4.0 — 361 stop junctions); LANE DISCIPLINE over every directed lane's polyline (each sampled vertex/midpoint within its own run's half-width + 0.05 m of the centerline and on its OWN travel direction's right — the side signed against the vertex's own centerline segment, the miter-at-a-bend keeps a positive projection there; measured worst offset 6.6 m on a 20 m arterial, worst side violation none); LINCOLN WAY end-to-end — the 52 named runs weld into ONE connected 6.51 km component, the name-following walk from both ends rides ≥ 60% of the named km (measured 4.02 of 6.51 — the asphalt continues past the walk's stops under OSM's other name for the same road, "East Lincoln Way"), and a breadth-first walk over the graph's directed edges reaches the east-most named run from the west-most (the end-to-end traversal fact); the LIVE fleet drives ~170 s under a STATIONARY pigeon at the cruise corridor (the round-2 gridlock exists only around a stationary pigeon and the round-1 probes all ended before the seize onset) — the traffic stays ALIVE (the round-2 movement pin at the review's own metric: 19 × 9 s windows, order-independent nearest-match within 20 m, ≥ 0.5 m displacement per mover; ≤ 10 dead windows of 19 and ≤ 4-window dead stretches allowed — the seize held 0 movers for 6.5 minutes; the fixed tree measures 0 dead windows of 19, and the live 5.5-minute pilot session 0 of 37 with 9–26 movers per window); the integrity reads count SUSTAINED violations (per-car streaks of ≥ 3 consecutive samples — pass arcs, corner swings and stub turnarounds are 1-2-sample legitimate manoeuvres; the wrong-way read demands the nearest directed lane to be the car's OWN approach street, its axis agreeing with the entry's approach axis — junctions cross two streets' lanes within the 1.5 m window; measured 0 sustained wrong-way, 0 off-road, 565 primary-edge samples proving Lincoln Way carries traffic); the round-1 fused-pile pin holds (every traffic car at every sample ≥ 1.5 m flat from every other — measured 2.55 m); the 9 at-grade rail crossings are route facts (one flagged node per crossing, 8 of the 9 on a drivable run the graph marks rail — the unnamed ninth track-pair crossing rides its node flag; cars traverse, nothing gates) | T-178 |
| ames_traffic_density | (T-178, round-1 re-pin) the fleet density per street class at the two pinned pigeon positions — the cruise camera (35 m over the Campustown Lincoln Way strip) and the low-hover (4 m over the same strip 90 m west) — across 3 seeds each through the spawner's own stream: the density LAW value-locked off the live graph (edge weights read exactly primary·downtown 7.50 > secondary·downtown 6.25 > tertiary·downtown 5.00 > residential·residential 0.70, with residential·downtown 1.75 — the ticket's arterial > downtown > residential ordering as the constants the population model draws by); the fleet contract holds at every seed (14 moving + 12 parked); arterial dominance at both positions aggregated (primary-class ≥ 12 — measured 16 cruise / 27 low-hover — while the residential staging stays a bounded minority per anchor, never leading primary — measured 10/16 cruise, 4/27 low-hover; the T-180 re-pin restated the aggregate ≤ 9 bar per-anchor at the same cause) and per seed ≥ 9 of the 14 moving cars on arterial classes (primary+secondary+tertiary; the T-180 re-pin moved the bar 10 → 9 at the measured minimum — cruise [11, 9, 12], low_hover [13, 14, 11]; the T-178 tree measured minimum 12: the arterial stop lines moved out to the adapted setback (lane_off + 7.3 — 17.0 m on Lincoln Way, was the flat 8.8) and the staging window follows its own line (the T-178 round-2 corridor lock at the measured width), so the near-junction arterial candidates that tree wrongly allowed are refused and a few cars rebase onto later legs — arterial classes stay the MAJORITY of every seeded fleet); the downtown Main Street anchor stages its local fleet with ≥ 4 of 14 moving cars on downtown-district streets (position-read through the world's own district rule — measured 9/4/11; the [60, 140] band pulls the anchor's periphery onto Main-adjacent side streets the strict 90 m district rule does not claim, and the downtown TIER itself is the value-locked 2.5× weight the law leg reads). The round-1 band re-pin rides here: the car spawner's Ames band is [60, 140] m (was the Windrow [30, 70], in which the resident corridor holds NO street — nearest run Union Drive at 94.8 m — so the weighted draw never engaged near the pigeon) with the recycle radius raised to 160 m to contain it | T-178 |
| ames_traffic_calm | (T-179) the T-166 calm etiquette re-derived on the resident graph: five staged arms on real runs (the fleet wiped — the staged cars are the only `Car._fleet` members, the T-166 determinism discipline; the probe runs are deterministic ascending picks — a straight calm run for the honk arms, a ≥99.9%-chord arterial for the pass arms, both ending at a real stop junction, staged through the spawner's own `_stop_entry_graph` so the cars carry the production stamps) plus a 90 s live-fleet arm at the cruise corridor, every value measured and printed on the `SIM DATA` line. NEAR — a mover held behind a parked blocker with the pigeon 8-14 m off the road honks exactly once at its first patience expiry (hold@3.7 s, honk@8.6 s — the 6 s physical class from braking onset) with the break machinery counting (breaks=1) and NO pass against a car blocker: the T-178 round-2 gate, which the round-2 record described but the code never had — the pre-gate tree armed passes against the staged parked blockers in all three honk arms (red-before, measured run 1) — landed by this ticket. FAR — the pigeon 55-65 m out runs two patience cycles SILENT (breaks=2, honks=0). CADENCE — two movers at equal 16 m gaps breaking together near the pigeon sound exactly ONE horn (the 3.0 s fleet cap ducks the second; both breaks ran). PASS — the pigeon-held pass on the real arterial (W 8.0, L 4.5) swings RIGHT (armed aim lane-local +0.9 or further) and every sampled frame stays inside the per-leg asphalt bounds [−11.15, +2.15] — the closed form −(W+L−1.35) / +(W−L−1.35) recomputed in-scenario off the run's own geometry (measured excursion [0.00, 1.62]) — completing in 2.1 s with the blocker behind, one honk. GATES — with an opposing car staged in the REAL oncoming lane (lane-local −2L = −9.0, the corridor re-derivation's whole point: the retired Windrow band stopped at −6.5 and read none of it) and a parked car at the REAL curb offset (w−1.05−l = +2.45 lane-local) ahead, BOTH shoulders deny for two patience cycles (displacement 0.00 m, the mover never `_passing`), and freeing the opposing car releases the pass ON THE LEFT within 3.2 s (min lat −1.63, never under 8.86 m of the parked car, completed inside 15 s). LIVE — the shipped 14+12 fleet under a pigeon held on station: 0/10 dead 9 s windows (the liveness floor), the blinker law 46/46 (every sampled car inside `blinker_lead` of a turning entry reads blinker == that entry's turn, recomputed from the entries, the post-turn holds skipped), 0 relay honks (patience honks never reach the DONE line — the T-134 contract on Ames), 0 far-attributed honks and 0 cadence violations (the healthy corridor honked 0 times in 90 s — the staged arms carry the etiquette proof; any live honk must pass the same gates). The dev-verb ack contracts rode through unchanged (`dev_verb_pack` green on this tree). (T-180 re-verified byte-identical on the intersections tree: the 25 signal corners change no arm — the staged probes stop ~19+ m before their lines, unregistered, so the red gate never binds; the live arm read 0/10 dead windows, blinker 40/40, 0 honks on the now signal-controlled streets) | T-179, T-166 |
| ames_intersections_present | (T-180) the corners leave the grid-node list and land on real corners: COUNTS pinned off the graph's merged junction anchors (junction nodes within 20 m weld into one corner — carriageway pairs ~12 m apart, street jogs ~17): downtown exactly 20 (the census §4 window's stock, derived band × cross street sets from census §7.1 inside the census script's own DT bbox), Campustown 11 of the census's 13 (the pack welds no junction at L/W × State and one Hunt-grade T — the recorded delta), arterial stops 43 (Lincoln Way / Duff / Grand crossing anchors in the pack core), signals 25 (arterial × collector: an arterial-grade street — primary/secondary class or the Lincoln Way/Duff/Grand/Main Street names — meets a collector-grade street — tertiary class or the census §4 Campustown signal-set avenues — or two distinct arterials cross), all-way 49; named legs: L/W × Welch and Main × Duff signalized, Main × Pearle all-way. GEOMETRY within tolerance of the ADAPTED T-134 consts at the measured widths (scenario literals, not the live constants): per pinned approach the zebra band center rides lane_off + 4.7 out on the axis with roundi(W/0.5) bars, the stop bar lane_off + 7.3 out / lane_off right (span 2.8, width 0.4), the sign post half_width + 0.2 lateral at stop_outset + 0.5 (face center y 2.5, plaque below), counts exact — 9,812 paint bars, 200 stop lines, 200 posts, 800 red + 800 border bars, 200 plaques, 50 mast boxes, 50 heads, 150 lamps — every paint top at 0.12 (center 0.11 + half the 0.02 thickness), equal to NO baked layer top {0.014…0.13} and a half-pitch-clear read over the arterial dashes; the T-143 relief survives the port (red bar extent 0.086 over border 0.03 — measured delta 0.056 > 0.05); the L/W × Welch signal corner carries NO stop furniture within 20 m (control exclusivity) while Main × Pearle carries band + bar + post; every family's MultiMesh instance_count equals its retained queue (the T-069 headless read pattern); zero StaticBody3D under Intersections (visual-only, T-017); a forced rebuild reproduces every corner transform (`is_equal_approx` across all nine queues). TRAFFIC OBEYS: at the L/W × Welch signal a staged mover's registration lands ~3 s into a red window — 483 red frames held at its line with the patience clock BYTE-FROZEN (patience delta 0.000: a red never force-commits), the commit lands +8.1 s after registration (the green flip) inside 13 s; the crosswalk arm parks the pigeon in the corner's REAL oriented band and a green-registered mover holds 622 frames (10.4 s of green) without committing — pedestrian priority reads the painted bands. The entries' bands are the oriented {center, axis, half_along, half_across} records the paint renders (paint and cars cannot disagree), stamped only at pinned corners | T-180 |


## Gate 2 — Autoplay smoke test (run before marking any gameplay ticket done)

Boots the **real** game (`scenes/main.tscn`) in a window and plays it with a
scripted, world-aware pilot — since the T-177 cutover for the Ames window below
(~103 s): cruise over the real massing in the Ames band (30-38 m — above the
campus roofline, under the Marston silhouette), climb, bank, dive pulse,
pull-up, glide, and airborne poop taps (T-006 — every 2 s in flight the pilot
lobs a real dropping; grounded taps are skipped; the T-008 car targets are
LIVE under the pilot since T-178 — the traffic graph stages the 14-moving +
12-parked fleet on the real streets and the taps are chance shots at it and
the skeleton (ground splats in the double digits, score 0 when none connect,
an occasional fleet honk) — while
the T-007 tourist leads stay inert until R2·pedestrians, the DONE line
honestly reporting `tourists=0 panics=0`).
Beyond `HOME_RADIUS` (40 m, tests/autoplay.gd — the pilot's own homing
constant, refreshed from a stale "60 m" prose by T-023) the pilot steers home
toward the spawn; on Ames the home radius is the world-owned bake-bounds circle
(~2.8 km), so that arc stays deep inside it and the flight-model edge nudge
never engages in a pilot run (the nudge itself is pinned by
`edge_nudge_turns_home`). From 11 s in
the pilot also makes a ground visit (T-003 + T-004): bleed speed in a wide
orbit over the Central Campus lawn, spiral down massing-clear, touchdown,
waddle across the grass, take-off. While landed it waddles toward the
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
the DONE line reports how many
bread shares the run earned (`shares` — on the cutover world the elders are
inert until R2 seats the real benches, so it honestly reports 0; the share
machinery returns with R2·economy-scale, the retired elder rows recorded in
the T-177 ledger). Saves a
screenshot every 5 s to `.godot/autoplay/`:

```bash
godot --path . res://tests/autoplay.tscn
```

**The world (T-176, the ONLY world since the T-177 cutover):** the SAME
pilot plays the resident Ames world on every boot — `Game.world` defaults
"ames" and the Windrow generate path was retired (no debug toggle, master
plan §11.2), so the plain command IS the Ames run. The retired env switches
remain accepted aliases:

```bash
AMES_AUTOPLAY=1 godot --path . res://tests/autoplay.tscn   ## redundant, accepted
PIGEON_WORLD=ames godot --path . res://tests/autoplay.tscn ## redundant, accepted
godot --path . res://tests/autoplay.tscn                   ## the Ames run
```

The Ames window is longer (`AMES_RUN_SECONDS` 100) and the run uses the
SHIPPED BreadSpawner target (40) with nothing staged (round 1 retired the
`AMES_CRUMB_TARGET` 400 staging — it inflated the crumb supply and with it
the gate): the world's boot ring (`City.boot_bread_spots`, the ground spots
nearest the spawn, seeded first on every populate) puts real bread ~20 m out
at boot, so one loop fits the window; the district-wide crumb SUPPLY is
`ames_bread_reach`'s contract and the live-count bound is
`ames_bread_spawner`'s. The Ames flight
leg flies the band over the real massing toward the nearest living
GROUND-class crumb, commits a descent, lands, waddles in and EATS it — the
DONE line adds `world=`, `crumb_target=` and `loop_ok=`, and on ames
`loop_ok` (eaten ≥ 1) joins `ok` — the survival loop must actually CLOSE.
Everything else — the restart leg, the screenshots, the pass rule below — is
the same machinery; the retired Windrow branch died with its world.

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

**Hidden launch (T-170):** every pilot session boots hidden-from-focus by
default — the launcher sends `PIGEON_WINDOW_HIDDEN=1` (plus a SW_SHOWNOACTIVATE
show-state leg that is belt-and-suspenders, not load-bearing), and the recorder
flags the window no-activate (`WS_EX_NOACTIVATE`), moves it fully off-screen
(min screen corner over all monitors, minus window size, minus an 80 px
margin), then re-lights it through the engine's own SW_SHOWNOACTIVATE path
(4.7.2's no-activate style rebuild strips `WS_VISIBLE` from an already-shown
window, and a fully hidden window stops DWM compositing — the OS `shot` would
serve a stale boot-splash frame; the BORDERLESS flag case's
`ShowWindow(SW_SHOWNOACTIVATE)` re-lights it off-screen unactivated — measured
at landing, recorded in the ticket) — the `pilot_window_hidden` event acks the
resolved position. The window keeps its taskbar entry but never appears on
screen and never activates. Frame PNGs, `shot` (PrintWindow needs no focus —
captured fresh off-screen at landing) and channel input all keep working, so
agent batches never pop windows over the owner's desktop. A sub-second blip at
the cascade corner before the hide is unavoidable (the engine shows the window
before autoloads run). `python
tests/tools/pilot.py focuscheck` re-proves the whole contract on Windows end to
end: it boots one hidden and one `--shown` session itself, checks the six
hidden-leg assertions (window found by title; `GetWindowRect` outside every
monitor with ≥ 32 px margin; foreground never the pilot window across 3 samples
≥ 1 s apart; the `pilot_window_hidden` ack present with `no_focus: true`; `shot`
writes a non-empty PNG and the frame-PNG stream grows — the render pipeline
alive off-screen; a flap lands as `pilot_press` — input flows without focus),
the two shown-leg assertions (rect on-screen, no hide ack), and
stops both cleanly — prints measurements and `FOCUSCHECK PASS`/`FAIL`, exit 0/1
(non-Windows: SKIP, exit 0). `--shown` restores the visible cascade window for
human eyes-on sessions (`--shown --pos=X,Y` stages a visible window at a spot;
use the `=` form for negative coordinates).

### Frame-step agent play (T-140 — how the 2026-10-27 beat-the-game run worked)

The pilot channel also drives **frame-step mode**, proven end-to-end the day it
landed by an agent run that won the game (favor 100 → "THE TOWN IS YOURS!", 17
car splats, score 510 — 2026-10-27, sessions `slowwin1`/`slowwin4`). Where
T-132's `--time-scale` slows the world for real-time play, frame-step makes
agent play **turn-based** — the fix for "the game is still too fast for you":

- **`{"pause": true}`** freezes the whole tree; **`{"step": N}`** advances ~N
  physics ticks and re-freezes; **`{"resume": true}`** returns to real time.
  `state`/`shot` (OS grab) read the frozen world freely — screenshots show the
  T-105 reticle painting its **exact** predicted impact while paused, which is
  the aiming tool. Input queued while frozen is **deferred onto the first
  running tick** — the protocol is *queue-then-step* (input and `step` lines in
  the SAME command file press together on the first live tick).
- **Gotchas paid for live:** the tree's PAUSABLE nodes only start ticking ~2-3
  recorder ticks after the unpause flip (the window carries a +4-tick pad — a
  raw window closes before the world moves at all); a press made while frozen
  without deferral expires unheard (`is_action_just_pressed` is one tick wide);
  a command file's lines all execute on the SAME tick (holds overlap — sequence
  across separate sends); `events.jsonl`/`state.jsonl` `t_ms` is ENGINE time —
  never compare it to wall-clock; the newest state line can be mid-write (read
  the last COMPLETE one). Godot's yaw convention: `forward = (-sin yaw, -cos
  yaw)` — yaw 0 = north (−Z), ±π = south.
- **Helpers** (`tests/tools/`): `pilot_nav.py` (`state` — last-complete-line
  read; `goto X Z --face YAW` — verified waddle navigation; NO obstacle
  avoidance, route around cars in legs) and `pilot_splat.py` (the parked-
  visitor-car grind worked example). Session scratch like `w.py`/`grind.py`
  patterns live in `.captures/session_*/` (gitignored).
- **The 2026-10-27 win recipe**, for reproducing or re-verifying the economy:
  read the rules first (`game.gd` favor table, `hunger.gd` drain, `player.gd`
  flight) → boot → pause → scout by cross-referencing `state`'s `cars`/`crumbs`
  lists (a ground crumb ~1.6 m off a parked car = the tailgate offset → a
  VISITOR car) → confirm class colors by screenshot (state carries no class) →
  parked VISITOR cars are re-splattable +6 fountains (cars never flee, no
  per-target dedup — 2026-10-27 owner note: possibly TOO effective, see
  IDEAS.md B-6) → per splat: stand 8.2 m out on the road, full-power hop,
  **release the poop at arc apex** (the drop inherits the pigeon's velocity —
  release timing is the whole aim: ±0.1 s = ±2 m of impact) → alternate
  north/south attack points so each landing is a 4-5 m walk from the next shot
  → book favor from the `car_splatted`/`crumb_eaten` event stream by FILE LINE
  OFFSET (never wall-clock) and confirm the HUD ("Favor: n / 100") by
  screenshot.
- **Verifying a new feature agent-side:** pause → read state + screenshot
  (frozen) → act via deferred input + step windows → read `events.jsonl` for
  the feature's pilot event (the T-095/T-137 precedent: new mechanics get a
  state-stream field or event so this loop can see them) → record the Gate 3
  line. If a feature is only observable mid-frame, step small (1-5 ticks) and
  screenshot each stage.

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

**Custom web shell (T-129):** the preset's `html/custom_html_shell` points at
[`tools/web-shell/index.html`](tools/web-shell/index.html) — the branded
loader (boot-splash navy, the gold pigeon mark, the wordmark and a rotating
tone-safe tip line) that replaces the stock page. The exporter still generates
`index.js`/`index.wasm`/`index.pck` and substitutes the `$GODOT_*` placeholders
in the custom page; the four-artifact pass above is unchanged. The loader
holds through the pck/wasm download AND the engine start AND the first warm-up
frames (the slideshow happens behind it), and the game drives it over
`JavaScriptBridge` (two-sided contract): `window.pigeonReady()` fades it out —
the menu calls it once the title has painted its first warm frames, and
Main calls it again at its stepped boot's `boot_finished`, fading the loader
over the live world — and `window.pigeonLoading()` brings it back on the title
screen's Fly handoff, covering the city warm-up. The ms-per-phase boot trace
(`BOOT phase=<name> ms=<n>` lines, plus the `BOOT web_diet:` line) is readable
in the browser console on desktop AND web builds. Verified live in a real
browser on the release export (2026-10-18): the branded loader renders and
rotates tips, holds past engine start, fades over the title via the menu's
signal (`loader-faded` transition observed), a Fly-started run boots with the
web diet applied (`BOOT web_diet: shadow_atlas=2048 msaa=off
max_physics_steps=3`) and the full per-phase trace printed, and the loader
ends hidden over the live world (screenshot-backed).

Re-run after any change to the `[display]`/`[rendering]` settings, the export
preset, `tools/web-shell/index.html`, or before an owner hosting pass. Hosting
is owner-run: the basement
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
| Q | quit the game — from the pause menu or the title screen (T-010) · desktop only (hidden + gated on the web build, T-126) |
| Touch (phone only) | left on-screen stick steers — up/down pitch, left/right turn, the W/S/A/D actions with analog strength · on-screen FLAP / POOP buttons (Space / F) · small Pause button (Esc) · auto-shows on touch devices; desktop preview: launch with `PIGEON_TOUCH=1` (T-119) |
| Xbox controller | left stick steers — up/down pitch, left/right turn, the W/S/A/D actions with analog strength, the stick actions at deadzone 0.25 (T-127) · **A** flap — starts a run from the title screen, presses the focused menu button, flies again on the score screen · **RT** (or **X**) poop · **Start** pause / resume — opens a run from the title too · **B** backs out of the pause menu (project `ui_cancel` override) · D-pad or left stick moves menu focus (engine-default `ui_up/down/left/right`) (T-127). Restart / M / Q / Shift stay keyboard-side; no rumble in v1 |

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
- [ ] (T-128) Owner flies a run: no more cars popping into view — traffic enters by driving — and the lighter 14 + 12 fleet still reads alive on the streets (pending human playtest; the machine arms live in the `traffic_spawns_offscreen` Gate 1b row)
- [x] (T-147) The spent read at the curb: re-splatting the same car still honks, flashes and pays "+30 ×N" — it reads as a rude response, not a broken meter — and the favor note appears only on the first splat (accepted by reviewer sign-off 2026-11-02 — the reviewer played the branch build via the pilot harness and signed off; the machine arms live in the `splat_favor_once_per_target` Gate 1b row)
- [x] (T-147) The churn read in flight: after splatting a car and flying off beyond the radius, the streets never visibly thin or pop — fresh cars enter by driving/parking off-screen — and a long splat-heavy run still finds splat-fresh targets near where the pigeon is (accepted by reviewer sign-off 2026-11-02 via the ticket's named route — the owner's agent flew the branch build and signed off; the machine arms live in the `spent_car_despawn_replacement` Gate 1b row)
- [ ] (T-151) A visitor-car jackpot reads gold "Visitor car +30" — world popup and HUD strip together, at typical flight distance, unmistakable next to the gold favor note [screenshot]
- [ ] (T-151) A civilian friendly-fire (tourist or car) reads red with the "Civilian"/"Civilian car" word — the hit that COSTS favor no longer reads like the one that pays [screenshot]
- [ ] (T-151) The game-over breakdown carries the per-class split (" (visitor 1 · civilian 2)") in both registers — before the Favor total on a win, at the end on a starve — and a zero-splat run still shows the plain legacy form [screenshot]
- [ ] (T-158) [screenshot] The reticle's target tell at flight height: over a parked visitor car the ring reads gold with the class word above the pin; over a civilian pedestrian it reads red; a frozen pin mid-fall shows neutral (pending human playtest; the machine arms live in the `reticle_pin_names_the_target` Gate 1b row)
- [ ] (T-158) The tell's feel lines: the gold/red ring is readable at lob range WITHOUT stealing attention from the pin itself, and the class word doesn't clutter the aim picture (pending human playtest; the tell radius 1.0 m and word size are the Gate 3 feel values)
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
- [ ] (T-148) From cruise height at the rim, the outer skyline ring reads as horizon haze — no hard-edged slab silhouettes casting ground shadows at the skyline (the machine arm lives in the `city_skyline_haze` Gate 1b row; the tuned `SKYLINE_HAZE_MAX` is recorded in the ticket) [screenshot]
- [ ] (T-148) Inner-band towers still read as a distant city, not fog-eaten: the dissolve is graded across the band, not a uniform wash [screenshot]
- [ ] (T-155) From the apron beside an inner-ring tower (session B's low-pass vantage, the `win_e.png` shot): the nearest monoliths read as horizon backdrop, not landable buildings — no crisp dark slab face at cruise distance (the machine arm lives in the `city_skyline_haze_floor` Gate 1b row; the tuned `SKYLINE_HAZE_MIN` is recorded in the ticket; if T-156's far-field fog has landed, the combined fog+haze read is what gets judged) [screenshot]
- [ ] (T-155) The f8760 horizon vantage: the horizon's hard dark stripe dissolves toward the beige sky-horizon AND inner-band towers still carry readable district color — the T-148 "not fog-eaten" line above re-judged on the same frames (the floor trades against it; judge both lines together and retune `SKYLINE_HAZE_MIN` down inside 0.35–0.55 if inner towers read fog-eaten) [screenshot]
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
- [x] (T-124) From typical flight heights the citizen classes still read at a glance on the new Quaternius figures — visitor black-and-gold stacking, superfan head-to-toe cardinal with the gold cap, civilians in plain palette shirts — and no civilian wears a team hue (T-121's reservation carried onto the new models) (accepted by reviewer sign-off 2026-10-17; the autoplay frames in `.godot/autoplay/` back the read)
- [x] (T-124) The Kenney cars read as city cars in traffic and at curbs; visitor flags/banners re-land prominent on the new bodies, the tailgate cooler sits on the trunk deck, and a splat/honk on the new paint reads correctly (accepted by reviewer sign-off 2026-10-17)
- [x] (T-124) The seated elders read as grandparents on the plaza benches at pigeon eye level and the city still feels pigeon-coherent — real people and cars, same pigeon-town joke (accepted by reviewer sign-off 2026-10-17; the pilot plaza session's seated-elder frames are the reference)
- [x] (T-127) **On the controller:** the owner plays a run ON THE PAD — steering feels right at full and half stick deflection (analog trimming reads as intended), the title starts on A/Start, the pause menu navigates (dpad/stick focus, A confirm, B back), and nothing double-fires (no double flap on A, no double pause on Start/B) (accepted by reviewer sign-off 2026-10-18; the machine side is `gamepad_actions_bound` (Gate 1b), which backs the navigation and no-double-fire arms; the iPhone-Safari pad check still rides the next hosted deploy if the hardware is at hand). No rumble in v1 — follow-up ticket if the owner wants it
- [ ] (T-129) **Owner on the hosted build:** the Fly press answers instantly (the title's "warming up the city" beat), the branded loader covers the city warm-up, and the world fades in already playable — the judge line for the whole T-129 boot (pending; rides the owner's next hosted deploy per the T-126 pattern — the machine arms live in the `stepped_boot_pins` Gate 1b row and the web-export section's browser-verified pass above)
- [ ] (T-131) **Owner on the hosted build:** the Fly press shows exactly ONE "warming up the city" screen — the branded loader alone, no title-note flash before it, no two navy screens back-to-back (the friend's report that opened T-131: the T-129 web handoff painted the title's identical note and then faded the shell's identical loader in over it) — while a desktop run keeps its one-frame note (pending; rides the same hosted deploy as T-129's line above, so one deploy closes both; the machine arms live in the `web_handoff_single_screen` Gate 1b row)
- [x] (T-133) **Owner feel pass on the slower bird:** cruise at ~13.6 m/s feels forgiving when lining up a poop (reticle lead visibly shorter), the same city reads BIGGER — a place to cross, not a plaza you outrun — and dives are still worth doing as the speed tool (28.8 cap keeps the top end); plus a spot-check on the iPhone Safari touch build where fine stick work is hardest (accepted by reviewer sign-off 2026-10-22 on the owner-confirmed pipeline route — the Verification section of the ticket is the record; no separate hands-on session was logged and the sign-off is the owner judgement this route exists to carry; the machine arms live in the `flight_speed_quartet_locked`, `turn_circle_shrinks` and `natural_glide_touch_dust` Gate 1b rows)
- [x] (T-135) One green park per district, mid-quadrant between the plaza and each anchor — the map reads balanced from cruise height; from the ground a park block reads as today's parks (trees, benches, crumbs) [screenshot] (agent grabs 2026-10-24: cruise four-park overview and ground-level park walk frames in `.captures/t135_parks/`; accepted by reviewer sign-off 2026-10-24; the T-004 city-readability lines re-checked on the same grabs)
- [x] (T-136) District 0 NW reads as its theme — main street: the walked shop row with green awnings and cream signboards, the formal two-tree square, the marquee post steering by — from cruise height and at street level [screenshot] (accepted by reviewer sign-off on the landed tree 2026-10-25; the machine arms live in the `city_district_theming_present` Gate 1b row)
- [x] (T-136) District 1 NE reads as its theme — tailgate lot: the bare-edged open park with banner-gold dressing, the water tower (riser, cream tank, gold name band) steering by — from cruise height and at street level [screenshot] (accepted by reviewer sign-off on the landed tree 2026-10-25)
- [x] (T-136) District 2 SW reads as its theme — campus: the framed quad lawn with collegiate slate dressing, the campanile (belfry insets, clocks, slate spire) steering by — from cruise height and at street level [screenshot] (accepted by reviewer sign-off on the landed tree 2026-10-25)
- [x] (T-136) District 3 SE reads as its theme — residential: the buried small-crown block with porch-sage dressing, the grain silo (hoop bands, dome) steering by — from cruise height and at street level [screenshot] (accepted by reviewer sign-off on the landed tree 2026-10-25)
- [x] (T-136) The map still reads balanced: four dressed parks, four signature silhouettes, the T-088 backdrop ring staying background — and the T-004 city-readability lines re-checked on the same session [screenshot] (accepted by reviewer sign-off on the landed tree 2026-10-25; the T-004 lines re-checked)
- [x] (T-137) After a share the elder stands, shuffles the route (waits at a curb), and sits down in a different district [screenshot of a mid-walk elder] (accepted by reviewer sign-off on the landed tree 2026-10-26; agent grabs 2026-10-25 in `.captures/t137_walk/`: `03_03_midwalk_sidewalk.png` / `04_04_midwalk_route.png` — the cardigan'd, white-haired grandpa mid-shuffle with his cane, clearly en route at a corner crosswalk — and `05_05_arrived_park_bench.png` — the same grandpa newly seated on the pinned park bench in the destination district, the crossing he arrived through right behind it; grabbed through the real main scene on a real staged share; the machine arms live in the `elder_relocates_after_share` / `elder_migration_deterministic` Gate 1b rows)
- [x] (T-138) All humans read as one people model, rigged and walking naturally [screenshot] (ACCEPTED by reviewer sign-off 2026-10-27 on the landed tree — the reviewer played the fixed build and judged the framings live; agent grabs 2026-10-26 in `.captures/t138_rig/`: `tourist_walking.png` — a visitor mid-stride across a crosswalk on the live `Rig|Walk`; `elder1_seated_preround1.png` is RED evidence only, showing the seated grandpa as the round-1 one-armed bug shipped him (renamed from `elder1_seated.png` when the fix landed); the fixed near arm and its trust raise are machine-proven geometrically in `people_on_one_rig` — hand lift > 0.4 m through the real `_arm_raise` → `_animate` path, red-before delta −0.002 m recorded in the ticket)
- [x] (T-138) Human next to bench/door/table reads adult-sized [screenshot] (ACCEPTED by reviewer sign-off 2026-10-27; agent grab 2026-10-26 in `.captures/t138_rig/`: `scale_table_bench_door.png` — a pedestrian beside a café table, a bench and shopped doors reading adult against the 0.78 m tabletop and 2.05 m doors; the grown capsule is machine-pinned in `people_on_one_rig`)
- [ ] (T-173) **Agent flight pass on `ames`, owner judgement deferred to T-177:** the resident baked skeleton reads as a real map from the air — streets/water/rail/park flats at true positions over the ground plate, the massing skyline standing, menu→flight flyable on the `world=ames` boot (pending — the agent screenshots are recorded against the landed tree (pilot, hidden windows per T-170, from 60 m and 200 m); the OWNER flight — Lincoln Way end-to-end, recognizing Ames — is T-177's Gate 3 per the ring plan; the machine arms live in the `ames_world_render_budget` / `ames_world_api_seam` Gate 1b rows)
- [ ] (T-174) **Agent flight pass on `ames`, owner judgement deferred to T-177:** the baked skeleton READS as Ames from the air — arterial lane dashes on the four named corridors (residential streets stay plain asphalt), district ground palettes distinct (downtown brick-warm band vs Campustown scruffy gray vs campus/plate greens), LaVerne an olive lake with a mown shore ring and Swan Island lawn inside it, College/Ioway green-blue ribbons (no canal across the lake), the rail corridor's gray ballast with the double dark tie stripe and honest gaps at the crossings, and the T-148 haze still carrying the horizon — machine arms in the `ames_skeleton_palette` Gate 1b row (pending — the agent screenshots are recorded against the landed tree, hidden windows per T-170: `.captures/session_t174vis4/lincolnway_60m.png` (Lincoln Way at 62 m vs `images/lincolnway/01`), `main_60m.png` (Main Street at 62 m vs `images/downtown/01`), `laverne_200m.png` + `laverne_shore.png` (LaVerne from the south vs `images/laverne/01`), `rail_corridor_60m.png` (the double main vs `images/rail/07`); the OWNER flight — Lincoln Way end-to-end, recognizing Ames — stays T-177's Gate 3 per the ring plan)
- [ ] (T-177) **The R1 exit demo — the ring's bar (owner, pending):** menu → Space → spawn over Central Campus (lake + campanile on one screen), fly the Lincoln Way corridor (State Ave → Duff leg) at 60 m and RECOGNIZE Ames from the air, eat bread, land on the campanile cap. His sign-off closes the ring and this ticket — the machine arms live in the `ames_*` Gate 1b rows + `ames_street_flyover`; any feel change found on the flight is a defect, not a tuning pass (feel constants frozen in T-176)
- [ ] (T-175) **Agent visual pass on `ames`, owner judgement deferred to T-177 (the silhouettes are the deliverable this ring):** the top-15 read as true-dim SILHOUETTES from 200 m — the campanile a slender needle with its cap landing pad, Marston the lone tall cylinder on lattice legs, Jack Trice a RING with green inside (never a solid slab), Hilton a broad drum, the MU block with its corner tower, Beardshear's dome hint, Parks' roofline step, the bandshell arc in its pocket, the municipal bulbs and the SE silo skyline — plus the pilot COLLISION probe: cruise flights into the campanile shaft and the bowl rim stop at the walls (machine arms in the `ames_placeholder_dims` / `ames_placeholder_landable` Gate 1b rows; pending — the agent screenshot set + probe recorded against the landed tree below; the OWNER flight stays T-177's Gate 3 per the ring plan)
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

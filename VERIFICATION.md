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
| poop_ball_visible | the falling drop reads from the chase cam — BallMesh radius ≥ 0.10 (landed 0.12), Mat_ball carries the soft warm emission in the parse-safe 4-arg Color form (a 3-arg Color in a .tscn fails to parse, load() → null), albedo ≥ 0.25 Euclidean RGB from grass and plaza (measured 0.853 / 0.545) and the collider stays pinned at its landed 0.07 | T-086 |
| poop_ready_indicator_tracks_cooldown | through the real main scene, the F glyph beside the hint line shows lit at full alpha while airborne with a rested drop, dims to ~25% the moment a REAL poop fires, stays dim through mid-cooldown, freezes with a paused tree and relights when the cooldown elapses in game time with no further press, hides entirely while grounded, and restart_run() mid-cooldown relights it (T-019 outline treatment asserted) | T-077 |
| tourists_walk_loose_groups | 18 tourists stroll their sidewalk loops at slab level, seeded in loose groups | T-007 |
| tourist_splat_panics_scores | a real lobbed splat panics its tourist (sprint + arms) and fires the splatted score event, scored end to end through the Game autoload (100, then the chain's ×2 → 300); a sideways hit makes the panic flee along the impact's horizontal mirror; since T-055 the scenario also reads the shirt's `material_override` albedo — exactly the tourist's palette `shirt_color` while calm (sampled before the drop) and exactly `Tourist.PANIC_TINT` mid-panic (confirmed inside the existing 120-frame poll) | T-007, T-055 |
| tourist_buzz_flinch | a slow pass through the buzz zone earns nothing; a fast one earns a flinch duck, never a panic | T-007 |
| tourists_recycle_around_player | moving the player recycles the same tourist nodes into the spawn band around the new position | T-007 |
| cars_traffic_loops_blocks | 20 traffic cars loop their block rings at lane speed — every car covers ground, the fleet rounds corners, no two cars ever overlap — while the parked fleet sits exactly where it was seeded | T-008 |
| car_splat_honk_and_continue | a parked car takes a real lobbed splat (honk + score event relayed, stays parked, 30 scored through the Game autoload; the synthetic traffic hit is the ×2 → 90) and a traffic car hit through the same duck-typed entry keeps driving its loop | T-008 |
| traffic_recycle_keeps_flow | with the pigeon parked on the plaza, 5 traffic cars re-seated onto one plaza-adjacent ring through the exact recycle insertion call (`_clear_rejoin_point`) all keep flowing — every seeded car covers ≥ 8 m of path in 10 s, seeded pairwise gaps stay ≥ 4 m (a healthy follow-gap queue still clears it), the fleet no-overlap floor stays > 2 m, velocities stay finite and no car jumps > 5 m in a frame (the whole ring lies inside the recycle radius, so the scanner must leave it alone); plus the block draw prefers rings under `ring_traffic_soft_cap` (an over-cap ring is never drawn while a lighter candidate exists) | T-089 |
| score_combo_style_values | the Game autoload pays DESIGN values (tourist 100 · car 30), the chain escalates ×1 → ×2 → ×3 across target kinds and resets on landing and on the 20 s window, and the +50% style bonus demands a release that is fast, low and fresh | T-009 |
| score_high_score_persists | beating the record writes user:// at once and a fresh Game loads it back | T-009 |
| score_popup_floats_and_fades | the world-space popup shows "+100 ×2" at the hit position, floats up, fades and cleans itself up | T-009 |
| pause_freezes_world | Esc-pausing through the real PauseMenu stops the flying pigeon dead mid-air and the hunger clock with it; resuming hands both back | T-010 |
| title_escape_does_not_quit | a synthetic Esc (`pause`) action fed straight to the real title scene's `_unhandled_input` neither quits the process nor pauses the tree — the menu instance survives; a regression re-adding the quit branch kills the whole Gate 1b run at that line (`flap`/`quit` are never fed — they would change the scene / quit the harness) | T-097 |
| game_over_shows_score_screen | starving through the real main scene opens the score screen — score, high score, tourist/car breakdown — freezes the run dead and keeps Esc locked | T-010 |
| restart_resets_run | restart through Main.restart_run() zeroes score/breakdown, refills hunger, clears the game-over latch, re-uses the same-seed city and re-seeds every spawner with fresh nodes | T-010 |
| restart_same_seed_skips_rebuild | a real main.tscn restart through Main.restart_run() takes the same-seed fast path — build_count stays 1, fingerprint/spawn_point/last_report untouched, exactly one regenerated — while every tourist AND car spawner re-seeds fresh nodes and the pigeon returns to the spawn corridor (fails if `regenerated` stops firing: the old nodes would survive) | T-033 |
| hud_bread_pointer_tracks_nearest_crumb | the HUD bread pointer names the nearest living crumb (distance within 1 m; `nearest_crumb()` matches an independent scan and returns null when none is alive), and — since T-057 the chevron carries the target's ON-SCREEN direction — the chevron's drawn direction `(sin θ, −cos θ)` from `rotation_degrees` θ has a positive dot with the normalized `unproject_position(target) − unproject_position(pigeon)` delta through the live camera (an independent half-plane check sharing no formula with the implementation — never `atan2` over the implementation's own delta, never the old `signed_angle_to`), sampled at the `reset_flight` hover at two opposing yaws (the flip arm 2 frames in, while the damped chase camera has barely swung and the crumb still rides the stale camera's forward hemisphere), behind-camera and degenerate targets hold the last chevron rotation unchanged (never a NaN, never a mirrored rewrite — the degenerate arm aims a synthetic point on the camera→pigeon axis 12 m past the pigeon, which unprojects onto the pigeon's own anchor pixel), the readout decreases on approach, eating the pointed-at crumb through the grounded waddle-in re-aims at the next-nearest, beyond half the city span the same slot names "city" with the horizontal distance home (± 2 m) and the same half-plane chevron check (teleport yaw 90: home sits dead ahead instead of riding the screen edge abeam), and the label carries the T-019 outline treatment; since T-098 the readout carries the climb cue, decided against the independent scan — " ▲" with a hand-placed crumb ~10 m over a grounded pigeon, " ▼" from ~10 m above a street crumb, no arrow within the ±3 m band, city mode never arrowed, and `_pointer_distance_m` parses both shapes so every pre-existing numeric assert is untouched | T-037, T-098, T-057 |
| hud_hunger_warning_tiers | the HUD score/hint outlines resolve through the theme, the hunger bar's four warning tiers map the 50/25/10% bands through the real Main scene, the danger tiers pulse in game time (tier 3 faster than tier 2) and falling back restores the rest color — via refill and restart_run; since T-080 the bar also resolves its own `background`/`fill` StyleBoxFlat overrides (dark translucent track, pure-WHITE fill — the tier-modulate invariant — both with the dark-outline border ≥ 1 px on all four sides); since T-075 a standing-percent boundary arm pins the tier-OR-percent bar-write guard (50.4% → 49.98%: percent 50 throughout while tier 0 → 1 — the bar value still rewrites and the tier repaints) | T-019, T-080, T-075 |
| hud_combo_strip_reports_last_hit | through the real main scene, a `%ComboStrip` label sits under the pointer block with the T-019 outline treatment and starts empty; emitting the spawners' splat relays at real tourists/cars (no physics) shows "Tourist +100", the chained second tourist "Tourist +200 ×2", and after a landing a car splat replaces it with "Car +30"; every hit also spawns a hit_marker.tscn burst ON the hit body (parent + hit point asserted, found via the `juice_effects` group) that cleans itself up; the strip clears itself after `combo_strip_seconds` (2.5 s) of game time and stays cleared, and restart_run() mid-display clears it | T-040 |
| pause_menu_shows_controls | through the real main scene, the pause panel's Box carries the two recap lines as its last two children (below the buttons) — hidden with the panel at rest, shown by the first `toggle()` (tree paused, both labels visible), hidden again with the panel by the second (tree unpaused); each line carries exactly its constant's key families, matched bi-directionally against `MainGame.HINT_AIR` (W/S, A/D, Space, F) and `HINT_GROUND` (W/S, A/D, Space), so a future constant edit that drops or gains a family fails the gate; and both labels carry the T-019 treatment (14 px, outline 4, black-0.85 outline, white-0.75 fill) | T-099 |
| elder_placement_no_rng | the city records one pure-layout spot per plaza-ring bench and the spawner seats 4 elders on every second bench (0, 2, 4, 6 — 90° apart, on the seat line); regenerating the same seed reproduces the fingerprint, the bench/lamp/bin counts and the spot list byte-identically, a foreign seed still gets its ring, and the elders sit exactly on the chosen spots of a real generated City | T-020 |
| elder_shares_bread_after_hangout | a GROUNDED pigeon parked in an elder's PresenceZone fills trust (~2 in ~2 s); a short walk-about decays it without wiping; back for `trust_needed` seconds the elder relays `bread_shared` exactly once and two ordinary T-005 crumbs (restore 30, hand-placed, respawn-accounted) sit on the pavement within reach in front of the bench | T-020 |
| elder_no_bread_airborne | a FLYING pigeon held inside the same PresenceZone for longer than `trust_needed` banks nothing — zero crumbs, zero relays, trust never leaves zero | T-020 |
| elder_cooldown_blocks_second_share | a pigeon hanging out CONTINUOUSLY through the whole `share_cooldown` after a share earns nothing until it expires — then exactly one more share | T-020 |
| pigeon_air_poses_track_flight | wings out in a glide, a wing beat on every real flap impulse (and the beat ends), wings swept back in a dive — the pose mirrors the flight state | T-011 |
| pigeon_ground_poses_track_waddle | grounded settles into the folded stand, waddling flips to the waddle pose, stopping settles back to stand; since T-048 the fold also thins the wing chord — the grounded legs assert the pivots' eased Z scale ≤ 0.5 (default 0.35), a fresh airborne set-up re-opens it to ≥ 0.95, and reset_pose() returns it to exactly 1.0 with both wing pivots' scale.z back at 1.0 (the root-only scale reset never reached them) | T-011, T-048 |
| pigeon_pecks_when_eating | eating a crumb through Main's exact wiring (crumb.eaten → Player.peck) plays the peck — the beak dives down and the overlay ends | T-011 |
| pigeon_silhouette_contrast | the bird's body is ≥ 0.20 Euclidean RGB from the sidewalk and the cream facade family, darker than every district backdrop's mean luminance by ≥ 0.05, with wingtips ≥ 0.15 darker and the head lighter (the 12-color sweep prints informationally); since T-026 the ground planes stay distinct — sidewalk ↔ asphalt ≥ 0.30 and sidewalk ↔ body ≥ 0.20 (measured 0.435 / 0.230 at the retuned values); since T-045/T-085 the bird also keeps one bright anchor over the dark road/roof family its gray body melts into — head and pale rump patch each ≥ 0.30 Euclidean RGB from asphalt and roof (measured 0.572 / 0.497 and 0.964 / 0.889), both underwings wearing the exact Mat_rump the Rump wears, and the bird scene still visual-only (Node3D/MeshInstance3D, no physics nodes) | T-016, T-026, T-045, T-085 |
| city_district_palettes_distinct | every building wears a color from its own district's palette, all four districts appear, the palettes are measurably distinct and the quadrant mapping is pure | T-013 |
| city_facades_fit_floors | one `Visuals/Facade<N>` MultiMesh per floor count actually present in `buildings[]` (floors re-derived per record: `roundi((top − block_slab_height − roof_slab_height) / floor_height)`) and none for a count no building has; per-class `instance_count` equals the class tally; every instance transform equals its building's expected facade box (origin `to_local(center) + UP·(block_slab_height + floors·floor_height·0.5)`, scale `(size.x, floors·floor_height, size.y)` — both footprint axes, within 0.01); each class material reports `get_meta("window_rows") == floors`, values distinct across classes; a forced same-seed rebuild reproduces every class's instance set byte-identically; the fingerprint stays at the pre-T-049 baseline pins (seed 20260928 → 2492360539, seed 424242 → 2662825400 — re-derived on the untouched tree with a headless `City.generate` probe before the diff landed; zero RNG draws, zero `_fp` entries) | T-049 |
| city_shopfronts_present | every building wears a ground-floor shop band with a door on one of its two street-facing faces plus the seeded awning share (104/146 at the M1 seed), and the shopfront palette stays measurably distinct from every district palette | T-017 |
| city_shopfronts_deterministic | regenerating the same seed reproduces every shop color, door face and awning flag exactly | T-017 |
| city_cafe_tables_present | every awninged building gets exactly one sidewalk cafe table on a pure-layout spot recomputable from its building record (104 at the M1 seed, non-awninged buildings none), same-seed regeneration reproduces the spot list byte-identically, a spawner rig seats tables-with-sitters exactly on the spots (sitters layer-3 `npc` static bodies, 1-2 per table by the even/odd index rule — 104 tables → 156, tourist-palette shirts by index), the spots hold the street clearances (center ≥ 0.5 m inside the 10.9 m loop line, ≥ 1.0 m off the block's bread spots, ≥ 1.2 m edge-to-edge off the door line), and a grounded pigeon can perch beside a table — whose solid top stops the waddle dead | T-031 |
| city_roofs_inhabited | every building carries 1-3 rooftop props fully on its roof (≥ 1.0 m from every edge, centers ≥ 2.5 m from the footprint center, one layer-1 `world` collider each) and exactly one roof crumb spot in the never-propped (+,+) quadrant at roof-top + 0.06, so `bread_spots` grows by exactly the building count (533 → 679 at the M1 seed); a crumb instantiated at a low roof's spot is eaten by a dropped-then-waddling pigeon through the ordinary eaten path (no BreadSpawner change), a drop onto the low roof's first prop settles grounded on its top, and a real same-seed rebuild reproduces `roof_props` and the roof spots byte-identically (zero RNG, zero new `_fp` entries) | T-032 |
| city_crosswalks_present | the `Visuals/Crosswalk` MultiMesh carries exactly 2,240 bars with default exports (224 bands × 10 — every unblocked intersection approach, the 32 outward approaches of the outer ring skipped because their band would leave the asphalt), every bar is an axis-aligned 2.4 along-road × 0.5 across × 0.01 box at its dash-family height (horizontal roads at `road_slab_height`, vertical at `road_slab_height + 0.005`), every bar center lies ≥ 5.0 m from every intersection node in XZ (the 3.5 m corner-cut swing area stays clear) and stays on its approach road's asphalt (the across-extent inside the road edges, the along-coordinate inside the city), the bar multiset matches an independent recomputation (per unblocked approach one 2.4 m-deep band centered 6.2 m out on the centerline, tiled by 10 bars running WITH the road, repeating ACROSS it at a 1.0 m pitch — the T-102 re-orientation of T-069's transverse piano keys, red-before/green-after: the un-flipped builder fails this scenario's count/geometry/asphalt/placement asserts), a forced same-seed rebuild reproduces all transforms byte-identically with the fingerprint unchanged at the pre-T-102 pin 2492360539 (zero RNG, zero `_fp` entries), and no StaticBody3D exists under `Visuals` — the paint is visual-only (T-017) | T-069, T-102 |
| city_apron_rim_present | the city-edge rim is pure layout: exactly 4 hedge bands centered on the boundary line (|x| or |z| = city_span·0.5 + 0.5, oriented (city_span, 1.2, 0.8) size) and 2·4·(blocks_per_side+1) = 64 trees — two flanking each street exit at ±6.5 m along the side axis (multiset-matched against an independent recomputation), trunks 1.1 m up on the apron and crowns 3.3 m up over every tree spot; the hedge/crown green holds ≥ 0.15 Euclidean RGB from COLOR_GRASS (measured 0.188 / 0.195, printed informationally); zero CollisionObject3D under the Visuals root; a forced same-seed rebuild reproduces both spot lists byte-identically with the fingerprint still equal to the cross-version pins (seed 20260928 → 2492360539, seed 424242 → 2662825400 — re-derived on the untouched tree with a headless `City.generate` probe; zero RNG draws, zero `_fp` entries) | T-088 (commit 1) |
| city_horizon_skyline | the distant skyline is a deterministic hash chain: `Skyline`/`SkylineTall` MultiMesh nodes exist under `Visuals` with 64 total instances ([40, 80] gated) of which 6 are landmark towers ([2, 8] gated); every origin's XZ radius sits in the band recomputed from the default exports, 192–347 m (beyond the blocks, strictly inside the ±367 m apron box including the tower's own ≤ 9 m half-width), box origins at height/2 over the y 0 apron; every scale.y ∈ [15, 60] and XZ extents ∈ [6, 18] m; zero CollisionObject3D under the Visuals root; a forced same-seed rebuild reproduces both instance sets byte-identically; the fingerprint still equals the cross-version pins and a foreign seed changes both the fingerprint and the tall-count split (6 → 3 at seed 424242) — zero draws from any RNG stream, zero `_fp` entries | T-088 (commit 2) |
| city_park_trees_present | every park block carries exactly four trees at the fixed (±5, ±5) offsets — 8 = 4 × the reported park count (2) at the M1 seed off the `TreeTrunk`/`TreeCrown` MultiMesh queues, the park blocks recomputed independently from the slab queue (exactly the slabs wearing COLOR_PARK), every trunk (1.1 m up on the slab) and crown (3.3 m up, bottom at trunk top) over exactly one expected offset and fully inside its block (6.3 m < the 11 m half footprint), the crown green (the rim's COLOR_RIM_CROWN) ≥ 0.15 Euclidean RGB from COLOR_PARK (measured 0.282, printed informationally), every tree ≥ 2.0 m XZ from every `bread_spots` entry (measured worst 4.98 m — bench seats included), the constants-level ≥ 1.5 m lamp/bin arithmetic pinned (4.24 m worst center-to-center − 1.84 m crown half-diagonal − 0.9 m worst prop half-extent = 1.50 m margin), zero CollisionObject3D under the Visuals root, a forced same-seed rebuild reproducing both queues byte-identically, a foreign seed keeping the 4 × parks law (2 parks → 3 at seed 424242), and the fingerprint still equal to the cross-version pins (seed 20260928 → 2492360539, seed 424242 → 2662825400 — re-derived on the untouched tree with a headless `City.generate` probe before the diff landed; zero RNG draws, zero `_fp` entries) | T-030 |
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
camera-shake trauma (`shake_peak`, the never-nauseating evidence). Since T-020
the plaza benches seat four park elders and the DONE line reports how many
bread shares the run earned (`shares` — the pilot's ground visit can land
inside an elder's PresenceZone; the count is reported, not gated, since it
depends on where the visit parks). Saves a
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

Playtest checklist (grows as tickets land):

- [ ] Pigeon falls under gravity, flaps with Space, steers with A/D and W/S
- [ ] (T-001) Paced flaps climb and sustain altitude; mashed flaps are noticeably weaker
- [ ] (T-001) Dive → pull-up visibly trades height for speed and back
- [ ] (T-001) Turns bank and feel weighty; stall drop and recovery read clearly
- [ ] (T-001) Landings at low speed slide to a stop without bouncing
- [ ] (T-002) Camera never clips ground or buildings when landing or hugging walls
- [ ] (T-002) No visible jitter during fast turns and dives; FOV kick noticeable but not nauseating
- [ ] (T-002) The pigeon never leaves the frame at max speed
- [ ] (T-044) Side-by-side with the old pinned kick (untouched tree vs landed, same cruise state), at 20+ m/s the bird keeps a readable silhouette for landing judgement while the ground rush still sells the speed [screenshot]
- [ ] (T-044) The shorter fast arm (5.8 m) never feels cramped when it pulls in low near roofs or the pavement
- [ ] (T-003) A gentle glide touchdown settles into the waddle and the HUD hint swaps to the grounded controls
- [ ] (T-003) Waddling is slow and comedic; A/D turns in place; Space takes off again
- [ ] (T-003) A steep fast dive into the pavement skids to a stop — no crash, no falling through the world
- [ ] (T-003) Landing and taking off on a roof and a bench works the same as on the pavement
- [ ] (T-021) A trim-speed touchdown on the pavement or a bench sticks on contact — the pose folds and the HUD hint swaps the frame the feet touch, no ghost-slide past the touch point
- [ ] (T-021) A deliberately hot, steep dive still reads as a comedic skid to near rest — not a soft mid-slide settle
- [ ] (T-022) Holding pitch-up near the ground reads as braking into a nose-high sink, not ballooning into a rocket climb [screenshot]
- [ ] (T-022) A speed approach to a bench or roof stays controllable through touchdown with the flare — pitch-up bleeds the approach speed without stranding the pigeon in a climb
- [x] (T-083) Holding W can no longer park the nose at or past vertical; three modest flare taps visibly cap out instead of stacking into a balloon; steep dive entry (S) still feels full-authority; and pitching down out of a nose-high flop still recovers without feeling dead
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
- [ ] (T-077) The F readiness glyph beside the hint line reads at a glance over pavement and sky, and the dim (cooling) state is distinguishable from the lit one [screenshot]
- [ ] (T-086) A freshly released drop reads as a distinct bright dot below the bird, against sunlit grass AND against shaded street, for ~2 s of fall [screenshot]
- [ ] (T-086) The enlarged ball does not read as a premature hit during the pre-contact moment [screenshot]
- [ ] (T-007) 15–20 tourists stroll the sidewalks and plaza in loose groups and read as believable walkers
- [ ] (T-007) A direct splat panics its tourist — sprints away, arms up, red flush, fist shake — and Score ticks up
- [ ] (T-007) Manual skill run: splat at least 3 tourists and buzz 3 more; watch one full panic cycle (sprint, fist shake, stroll resumes) through to the tourist eventually recycling
- [ ] (T-007) A close fast flyby makes nearby tourists flinch (a quick duck) without full panic
- [ ] (T-007) At full density the framerate holds; tourists only ever appear/disappear well away from the camera
- [ ] (T-008) Parked cars line the curbs and traffic loops the blocks; cars never overlap or gridlock at corners
- [ ] (T-008) A splat on a parked car and on a moving car both honk (body flash) and tick the score by 30
- [ ] (T-008) Cars read as visibly bigger, easier targets than tourists; a moving car is hittable with modest lead
- [ ] (T-008) Follow one car for a full block circuit — it keeps looping normally after being splatted
- [ ] (T-089) Standing still for a minute never parks the whole fleet; cars keep flowing past a stationary pigeon
- [ ] (T-009) Splats pay the DESIGN points — 100 per tourist, 30 per car — and a popup at the hit reads clearly at flight speed
- [ ] (T-009) Chained hits without landing escalate ×2, ×3… and reset when you land or after ~20 s
- [ ] (T-009) A fast low dive hit pays the +50% style bonus — visible as a bigger popup number
- [ ] (T-009) Beating the high score, then quitting and relaunching, shows the record survived
- [ ] (T-010) Boot lands on the title screen; Space (or the Fly button) starts a run on the spawn corridor
- [ ] (T-010) Esc mid-flight freezes everything dead — pigeon, hunger, traffic; Esc again resumes exactly where it was
- [ ] (T-010) From the pause menu: R restarts into a fresh same-seed city, M returns to the title, Q quits
- [ ] (T-010) Die on purpose twice in a row — each score screen shows score, high score and the tourist/car split; restart works from both (pause mid-flight during both runs)
- [ ] (T-010) The score screen flags a freshly beaten record and Esc cannot unpause a dead run
- [x] (T-097) The title screen shows a "Q quit" hint, legible at a glance; Esc at the title does nothing (the app stays up) and Q still quits [screenshot]
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
- [ ] (T-019) The score line and control hint read clearly over white pavement at the spawn corridor, over the bright sky at altitude and over the dark road (dark outlines)
- [ ] (T-019) The hunger bar warns at a glance — white → amber → red pulse → fast flash — without staring at it, and never sits stranded mid-flash after landing to eat
- [x] (T-080) The hunger bar reads as a bounded element at tier 0 — dark track + dark border — findable at a glance over white pavement at the spawn corridor, over the bright sky at altitude and over the dark road (side-by-side with before)
- [ ] (T-037) The bread pointer is readable at a glance mid-flight — the chevron leads the eye toward the crumb it names, and the metres count down as you close in
- [ ] (T-037) Flying past the city edge flips the same line to "city N m" pointing home, and steering along the chevron brings the ring back into view
- [ ] (T-037) The pointer line and chevron read over white pavement and bright sky (T-019 outline treatment) without crowding the hint above them
- [ ] (T-098) Grounded before a building with a rooftop crumb, the pointer reads "bread N m ▲" and the arrow stays readable at a glance under the T-019 outline treatment; airborne above a street crumb it reads " ▼"; within a few metres of the crumb's height and in city mode there is no arrow [screenshot]
- [x] (T-099) The open pause panel's Air/Ground control recap reads at a glance beside the button labels over the dimmed world, and the "one controls block per screen" tone holds (agent grab `.captures/t099_pause_controls.png`, unpause confirm `.captures/t099_pause_unpaused.png`; reviewer sign-off 2026-10-01) [screenshot]
- [ ] (T-040) A scored hit leaves the combo strip ("Tourist +100", "Car +30 ×2"…) readable at a glance mid-flight — at cruise over the skyline, low over the pavement and against the road [screenshot]
- [ ] (T-040) The hit-marker ring flashes at the splat and draws the eye to which tourist/car panicked [screenshot]
- [ ] (T-017) Street canyons read as shop rows at eye level — colored ground-floor bands with doors and awnings, not blank office walls
- [x] (T-049) At eye level the window rows read as floors — 2 rows on the 2-story podium, 5-6 on towers — and from cruise height the roofscape reads as buildings of differing heights, not one sticker at different zooms (agent grabs `.captures/t049_eyelevel_after.png`, `.captures/t049_cruise_roofscape_after.png`, `.captures/t049_streetflight_after.png`; reviewer sign-off 2026-10-01) [screenshot]
- [ ] (T-020) Four elders sit on the plaza benches every run, spread around the ring, and read as old people at a glance — hunch, gray hair, cane — from both flight height and ground level
- [ ] (T-020) Landing in front of an elder and hanging out ~4 s earns a share: two crumbs toss onto the pavement in front of the bench, land where the pigeon can reach them without phasing through the bench, and eating them restores hunger
- [ ] (T-020) The ~4 s hangout feels like "a bit", not an age — and after a share the elder clearly ignores you for a good while (no infinite buffet)
- [ ] (T-017) The shop bands read from the air and give the roofscape a visible street-level edge
- [ ] (T-017) Shop colors harmonize with the four district palettes — distinct but not clashing
- [ ] (T-017) Low street-level flight does not snag on or distractingly pass through awnings (visual-only by decision — `docs/tickets/T-017-shopfronts.md`)
- [ ] (T-026) Side-by-side with before: sunlit sidewalk and plaza show surface tone instead of clipping to white, the asphalt reads as road rather than void, and lane dashes and car colors still pop
- [ ] (T-026) The city still reads "warm sun" after the ground retune — the T-013 warmth judgement holds over the new ground values
- [ ] (T-033) Restarting from the score screen shows no generation hitch — the fresh run appears instantly on the standing same-seed city
- [ ] (T-036) Flying hard past the apron returns you to the spawn corridor within a couple of seconds, and it reads as intentional ("came home"), not a teleport glitch [screenshot]
- [ ] (T-036) Across an off-world return the hunger bar never pauses — it keeps ticking down through the snap home
- [x] (T-030) Parks read as parks from the air — a grove of four crowns against the lawn, not a vacant lot — and the crowns never visually collide with benches or lamps (agent grabs: same-camera before/after pairs `.captures/t030_park_grove_z64_{before,after}.png` and `.captures/t030_park_grove_corner_{before,after}.png`; author A/B: `wb3b` vs `wb4-trees` frames; reviewer sign-off 2026-10-01) [screenshot]
- [ ] (T-031) Awninged fronts read as cafes at eye level — table and seated people under the awning, not a bare door slab [screenshot]
- [ ] (T-031) Low street-level flight past cafe tables doesn't snag, and tables don't crowd the tourist path
- [ ] (T-042) Flying hard past the apron returns you to the spawn corridor within a couple of seconds, and it reads as intentional ("came home") — not a teleport glitch [screenshot]
- [ ] (T-042) The hunger bar keeps ticking down across an off-world return — the clock never paused (compare the bar just before flying out and just after landing home)
- [ ] (T-032) From cruise height the roofs read as inhabited — AC boxes, water tanks and vents break the gray roof planes, and a rooftop crumb is spottable from a cruise glide [screenshot]
- [ ] (T-032) Landing on a roof near a crumb and waddling to it works like the pavement version; the props read as useful cover, not obstacles
- [ ] (T-085) In flight at cruise and in a dive, the bird reads at a glance against road AND roof at ~20 m — one bright anchor (rump/underwing) visible from the chase angle [screenshot]
- [ ] (T-085) Grounded, the pale rump reads against asphalt so the bird no longer melts into the road [screenshot]
- [ ] (T-088) At cruise the rim reads as the edge of town — a hedge line with tree clumps at each street exit — and the apron no longer reads as infinite grass [screenshot]
- [ ] (T-088) From the apron (300+ m out) the horizon reads as a distant city under haze, not a void edge — the towers read as background (muted, low-contrast), not as landable-looking foreground buildings [screenshot]
- [x] (T-102) Walking down a road toward an intersection, the band ahead reads as a zebra — bars running away with the road, step-over rungs — matching `.captures/xwalk-refs/ref08` (agent grab `.captures/t102_eyelevel_zebra.png`; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-102) From the air each crossing reads as a ladder with rails parallel to traffic (compare `ref11`) (agent grab `.captures/t102_aerial_ladder.png`; reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-048) At the chase cam's grounded distance (~3.5 m) the bird reads at a glance as a compact pigeon with wings hugging the flanks — not a biplane (reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-048) The takeoff moment (fold → GLIDE) shows the wings re-opening smoothly, without a pop as the chord re-expands over the pose lerp (reviewer sign-off 2026-10-01) [screenshot]
- [x] (T-048) Elders read as people at a glance at 20 m — the rust cardigan separates them from the pavement (reviewer sign-off 2026-10-01; judgable in the same play session as T-020's pending lines) [screenshot]
- [ ] Pigeon lands on the ground and does not fall through the world
- [ ] HUD hunger ticks down over time
- [ ] Camera does not clip through the ground while landing
- [ ] Closing and restarting the game produces no errors

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
- Bread pointer (T-037) is machine-verified (Gate 1b
  `hud_bread_pointer_tracks_nearest_crumb` — nearest-crumb query vs an
  independent scan, distance/on-screen-chevron/approach, re-aim after eating
  through the real waddle-in, city mode beyond the ring, resolved outlines)
  and costs one nearest-N scan per frame inside the T-018 budget
  (`density_cpu_budget` runs with the pointer live). Since T-057 the chevron
  aims in SCREEN space — target and pigeon unprojected through the live chase
  camera — so it points where the target actually sits in the frame at any
  camera yaw; targets behind the lens (sterner than roughly abeam) and
  degenerate screen deltas hold the last honest rotation, both machine-checked
  in the same scenario (half-plane expectations computed independently of the
  implementation). A human pass over the T-037 lines (readable at a glance
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
  off-world excursions now self-heal). A human pass over the two T-042 lines
  (the return reads as "came home", not a teleport glitch; the hunger bar never
  pauses across a return) is still pending.
- Rooftop clutter (T-032) is machine-verified (Gate 1b `city_roofs_inhabited` —
  1-3 props per building ≥ 1.0 m inside every roof edge and ≥ 2.5 m off the
  footprint center, one layer-1 collider each, exactly one roof crumb per
  building in the never-propped (+,+) quadrant so `bread_spots` grows by
  exactly the building count (533 → 679 at the M1 seed), a roof crumb eaten
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
- Bread pointer climb cue (T-098) is machine-verified (Gate 1b
  `hud_bread_pointer_tracks_nearest_crumb`'s cue arms — " ▲" with a hand-placed
  crumb ~10 m over a grounded pigeon, " ▼" from ~10 m above a street crumb, no
  arrow within the ±3 m band, city mode never arrowed, `_pointer_distance_m`
  parsing both shapes with every pre-existing pointer assert untouched — all
  decided against the scenario's independent scan, and selection is unchanged).
  A human pass over its Gate 3 line (the ▲ reads at a glance at 14 px before a
  roofline [screenshot]) is still pending.
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

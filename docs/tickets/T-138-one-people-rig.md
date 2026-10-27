# T-138 — One people rig: every human on the live Quaternius skeleton — real walks, sits, adult scale

- **Milestone:** People rig (owner ask 2026-10-26, dictated after noticing the
  elder/tourist visual gap post-T-137) · **Status:** doing ·
  **Category:** visual-design · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-124 (the base character, landed), T-137 (the elder walk
  states this rig must serve, landed)
- **Refs:** T-124's implementation record (the bake machinery this ticket
  retires: `tools/bake_people_cars.gd`, `assets/generated/models/people/*`,
  `animation/import=false` on the pack glb) · the pack: Quaternius Universal
  Base Characters, CC0, rigged 53-joint humanoid with the Universal Animation
  Library embedded (`Rig|Walk`, `Rig|Idle`, `Rig|Sitting_Idle`, …; the
  `Rig|Death*`/`Rig|Hit_*` clips are BANNED and stay unimported) · the
  gameplay contracts that must survive untouched: `tourist.gd` (WALK/PANIC/
  FLINCH states, buzz), `elder.gd` (T-137 state machine SEATED→RISING→
  WALKING→CURB_WAIT→ARRIVING, `_arm_raise` trust meter, `_route_cross`,
  `begin_migration`) · the pin surfaces: tourist capsule r 0.25 / h 1.1
  (`tests/sim_test.gd:8193-8196`, the `people_and_cars_swapped` scenario),
  the raised-mitt ≥ 1.42 m head-line splat read (`tests/sim_test.gd:7901`),
  the 1.22 m envelope pin (`tests/sim_test.gd:7640`) · the class color laws
  (`citizen_classes_readable`, `civilian_palette_reserved` — T-113/T-121) ·
  T-060's humanly-possible splat band · `assets/CREDITS.md` + the web
  export's third-party exclusion (T-118/T-124 precedent).

## What

Every human in the city — all four citizen classes AND the elders — moves
onto the SAME live rigged Quaternius skeleton with real animation clips,
sized as adults against the world's furniture. The bake-tool era ends for
people (cars stay baked — they are not humans).

The honest current state this fixes: all humans already share ONE model
(the 53-joint base character), but NOBODY is rigged at runtime — T-124
shipped `animation/import=false` and static per-part pose bakes; tourists
"walk" via the script bob (the T-011 lineage), elders via T-137's sit↔walk
pose-set swap plus a sine bob. Seated it read fine; T-137 made grandpas
walk, and a pose-snapping figure next to properly striding — well, also
pose-baked — pedestrians now reads as two generations of people. The owner's
dictated fix, verbatim intent: all humans on one model, all rigged
reasonably, walking at least sort of realistically, sized appropriately
against the furniture.

1. **The rig goes live** — re-import the pack WITH animation (flip the
   `animation/import` handling; the whitelist is explicit: `Rig|Idle`,
   `Rig|Walk`, `Rig|Sitting_Idle`, plus a stand-up transition clip if the
   library ships one — implementer inventories the glb and records the
   actual whitelist). `Rig|Death*`/`Rig|Hit_*` are NEVER imported; the
   "death referenced nowhere" audit leg survives. ONE shared rigged character
   scene is the only human source; `tourist.tscn` and `elder.tscn` both
   instance it. The per-part derived people meshes (`sit_*.res`,
   `walk_*.res`) and the people half of the bake tool are retired and
   deleted; `assets/CREDITS.md` metadata moves to the rigged scene.
2. **Clips drive locomotion; scripts keep driving behavior** — the state
   machines are untouched and now pick clips: tourist WALK plays `Rig|Walk`
   looped at a play rate matched to `walk_speed` 1.3 m/s (feet don't skate —
   the rate is derived from the clip's own stride, pinned by scenario);
   PANIC/FLINCH keep the script-driven lean/arms layer riding on top of the
   clip base. Elder RISING blends sit→stand, WALKING plays `Rig|Walk` at the
   0.8 m/s shuffle rate, ARRIVING blends into `Rig|Sitting_Idle` with hips
   on the bench seat plane. The walk bob/lean comedy layer stays.
3. **The trust arm survives as a rig attachment** — the near arm becomes a
   `BoneAttachment3D` on the shoulder bone carrying the arm mesh + cardigan
   sleeve; `elder.gd`'s `_arm_raise` rotation code drives that attachment
   exactly as it drove the static part today. The T-078 contract (arm IS the
   meter) and every elder sim scenario (`elder_shares_bread_after_hangout`,
   the T-078 arm legs, the T-137 migration scenarios) must pass UNTOUCHED —
   that is the API-preservation tripwire. The far arm rides the clips.
4. **Adult scale, measured against the furniture** — today's envelope is a
   1.22 m head-top (inherited from the capsule-era visual), child-scale
   against 3.0 m floors, ~2 m shop doors and the 0.60 m bench (T-124's
   "comedic dangle" was this artifact). Target: an adult human — head-top
   ≈ 1.75 m at feet 0 — with the exact value pinned after measuring the
   door/facade openings (T-017/T-049 recipe), the bench seat (0.60), the café
   tables (0.78 tabletop) and the plaza plinth in `city.gd`; the scale reads
   in the Gate 3 screenshots next to bench, door and table. The physics
   capsule grows WITH the visual (the shape is the splat surface — a grown
   visual over the old capsule would splat air); `tourist_splat_panics_scores`
   and the T-060 hitbox-coach band re-run, re-derived only if the band
   actually moves (bigger targets make splats easier — record the measured
   effect, retune the coach only on evidence).
5. **Color laws ride the skinned mesh** — per-class tint via
   `material_override` on the skinned body instance (the T-113 mechanism),
   elder cardigans likewise; `citizen_classes_readable` /
   `civilian_palette_reserved` pass unchanged.

**Known pin breaks, amended in the same change-set (mandatory):**

- `people_and_cars_swapped` (`tests/sim_test.gd` ~8140-8220) inverts: its
  "packs(mesh-only)" and "zero AnimationPlayer" laws die — rewritten (new
  name `people_on_one_rig`) to pin the rigged shared scene, the clip
  whitelist (death/hit absent — the audit stays), the grown capsule
  (radius/height literals re-derived from the scale probe), and the
  walk-rate match (clip play rate ≈ move speed / clip stride).
- The capsule literals (`:8193-8196`), the mitt ≥ 1.42 m head-line leg
  (`:7901` — the mitt and the head both grow; the read "mitt above head
  line" re-derives with the new envelope) and the 1.22 m pin (`:7640`) —
  all re-derived by probe in the same change-set, with the measured
  values recorded here.
- Zero city-fingerprint impact expected (no `city.gd` layout change, no RNG,
  no `_fp`) — the full suite re-runs green as the proof, per the T-124
  precedent that the untouched suite IS the parity claim for everything not
  named above.
- Web delta: skeletons + clips grow `index.pck` — record the byte delta
  against the T-124 baseline; third-party pack sources stay excluded from
  the export.

Not claimed: new behaviors (panic still panics, elders still ignore
splats/buzzes), new clips beyond the whitelist, crowd animation variety
(per-class clip variants), cars, the plaza statue, reticle/splat mechanics
beyond the capsule growth, pathing changes (T-137's routes are sacred).

## Why

Owner ask 2026-10-26, verbatim: "I want all the humans on the same model. I
want them all rigged reasonably. I want them to be able to walk around at
least sort of realistically. I want them sized appropriately against the
furniture of the world." The first is already true; the other three are not,
and T-137's walking grandpas turned the gap from invisible to daily-visible.
The rig already ships inside the pack the repo licenses — this ticket stops
throwing that away at import. Routing: pipeline per the T-124 precedent
(the blast radius is every human entity and the splat surface), with the
elder-contract scenarios as the explicit must-pass-unchanged tripwire.

## Acceptance criteria

- [x] ONE rigged human scene is the only people source; both `tourist.tscn`
      and `elder.tscn` instance it; the per-part bake meshes
      (`assets/generated/models/people/*`) and the people half of
      `tools/bake_people_cars.gd` are retired and deleted; `assets/CREDITS.md`
      reflects the rigged scene.
- [x] Every human walks on a real clip: tourist stroll and elder shuffle
      play looped walk animations rate-matched to their move speeds (no
      skating), elders sit via the sit clip with hips on the seat plane,
      RISING/ARRIVING blend; PANIC/FLINCH keep their script comedy layer on
      top; the death/hit clips are imported nowhere (audit leg green).
- [x] The trust arm is a rig attachment driven by the unchanged
      `_arm_raise` code; the FULL elder scenario set — T-078 arm legs,
      `elder_shares_bread_after_hangout`, `elder_placement_no_rng`, both
      T-137 migration scenarios — passes UNTOUCHED.
- [x] Humans are adult-scaled against the furniture: the pinned head-top
      value (≈ 1.75 m, exact from the furniture probe) with the capsule
      grown to match; the grown value and the mitt/head-line relationship
      re-derived and pinned; the T-060 splat band re-measured with the
      result recorded (coach retuned only on evidence).
- [x] Class color laws green unchanged (`citizen_classes_readable`,
      `civilian_palette_reserved`); `citizen_classes_spawn_deterministic`
      untouched and green.
- [x] (Gate 1b) new `people_on_one_rig` scenario replaces
      `people_and_cars_swapped` per Known pin breaks, and the FULL suite is
      green (0 failures).
- [x] (Gate 2) autoplay green + web export re-run with the pck byte delta
      recorded against T-124's baseline; third-party sources still excluded.
- [ ] [screenshot] A tourist and an elder side by side read as the same
      kind of person; a walking grandpa reads as natural as a strolling
      tourist; a human next to a bench, a shop door and a café table reads
      adult-appropriately sized.

## Verification

Gate 1 (import + 120-frame boot + `--check-only` on touched scripts) + Gate
1b FULL suite green with `people_on_one_rig` added and
`people_and_cars_swapped` retired (same change-set); explicitly re-run
`elder_shares_bread_after_hangout`, `elder_placement_no_rng`,
`elder_relocates_after_share`, `elder_migration_deterministic`,
`citizen_classes_readable`, `civilian_palette_reserved`,
`citizen_classes_spawn_deterministic`, `tourist_splat_panics_scores`, the
T-060 coach scenario, `restart_resets` + Gate 2 + Gate 3 new lines —
"(T-138) All humans read as one people model, rigged and walking naturally
[screenshot]", "(T-138) Human next to bench/door/table reads adult-sized
[screenshot]".

## Implementation record (2026-10-26)

**How the rig went live.** `tools/import_people_rig.gd` (an
`EditorScenePostImport` import script — the `@tool` annotation is
LOAD-BEARING: without it the editor silently never instantiates the script,
headless included) transforms the imported pack at import time:

- **Clip whitelist (the ban audit).** The library ships 45 clips; six are
  kept — `Rig|Idle`, `Rig|Walk`, `Rig|Sprint`, `Rig|Sitting_Idle`,
  `Rig|Sitting_Enter` (stand→sit, the ARRIVING settle) and `Rig|Sitting_Exit`
  (sit→stand, the RISING blend) — recorded from the glb inventory
  (2026-10-26). Everything else, the T-124-banned families included, is
  REMOVED before the scene is cached: the pruned clips exist nowhere in the
  packed game, and the "referenced nowhere" text audit (now covering the rig
  scene, script and import script) stays green. Loop flags: Idle/Walk/Sprint/
  Sitting_Idle loop; Enter/Exit are one-shots.
- **Part split.** The mannequin's two surfaces (body panels + Quaternius doll
  joints) are partitioned per-vertex by dominant bone (the T-124 bake's exact
  rules) into **Body / Legs / ArmL** — skinned MeshInstance3D over the same
  53-joint Skeleton3D, each with one flat StandardMaterial3D (the per-class
  `material_override` duplication source). ArmR has no skinned variant (see
  arms below).
- **Rigid mount parts.** **HeadRigid / ArmLRigid / ArmRRigid** are re-authored
  in their main bone's BIND frame (bind pose × vertex, scaled to meters) and
  hung under BoneAttachment3D → 0.01-scale Frame nodes so they ride the live
  bone exactly. HeadRigid carries the HeadTop slot (cap/hair); ArmRRigid the
  HandR slot (the foam finger). The rigid-arm vertex math survived three
  wrong compositions before landing on the simple one — at bind, a vertex in
  the main bone's frame is exactly `bind_pose(main) × v`.
- **Metadata** (source pack/file/license CC0, the whitelist, the
  probe-measured envelope/stride constants) is stamped on the scene root and
  every part mesh; `scenes/people_rig.tscn` + `scripts/people_rig.gd`
  (`class_name PeopleRig`) instance the glb and are the ONE people source:
  `tourist.tscn` and `elder.tscn` both instance `people_rig.tscn` as their
  `Visual`. The retired `assets/generated/models/people/` meshes are deleted;
  `tools/bake_people_cars.gd` is cars-only now (cars are not humans).

**Clips drive locomotion; scripts keep driving behavior.** `people_rig.gd`
exposes `play_clip`/`play_locomotion` (crossfade 0.18 s, the pigeon's
convention) and `set_arm_pose`; the state machines are untouched. Tourist:
`Rig|Walk` while strolling, `Rig|Sprint` while panicking, `Rig|Idle`
standing, each rate-matched; the bob, the panic lean (on the rig root), the
duck squash (rig scale.y) and the flush are unchanged writes on the same
members. Elder: SEATED→`Rig|Sitting_Idle`, RISING→`Rig|Sitting_Exit` (paced
to `rise_seconds`), WALKING→`Rig|Walk`, CURB_WAIT→`Rig|Idle`,
ARRIVING→`Rig|Sitting_Enter`; the bob stays; the T-137 bench hunch became a
figure pitch on the rig root (same `HUNCH_*` consts, `hunch_rate`); the
seated figure sinks `SEAT_SINK` −0.511 m so the sit clip's hips rest on the
0.60 m seat plane with a 0.02 lip.

**The trust arm survives as a rig attachment.** Both citizens' right arms
are the rigid `ArmRRigid` on its BoneAttachment3D; `set_arm_pose(ARM_R,
raise, shake)` eases between the clip's own swing (identity, raise 0) and a
world-aimed raised pose — the arm's long axis (bind +Y, shoulder→hand) tipped
up 11° forward — cancelling the bone swing so a raised foam finger, a panic
flail or the T-078 trust meter points up steady; `shake` swings it about the
body's right axis (the fist shake). The tourist raises both rigid arms (the
skinned ArmL hides — no doubled geometry); the elder raises only the near
right and leaves the far arm on the skinned ArmL riding the clips — the
cardigan tint lands on Body + both arms exactly as before. `_arm_raise`'s
0..1 semantics are untouched; the FULL elder scenario set passed UNTOUCHED.

**Adult scale, measured against the furniture.** Probes (headless, on the
imported pack) measured the native figure: standing height 1.7828 (head top
1.7698, feet −0.0130, skeleton origin −0.0136). The Model node scales 0.982
and drops −0.0006, pinning **head top 1.7507 m over feet at 0** — reads
adult against the 2.05 m shop doors (city.gd `door_size`), the 0.60 m bench
seats, the 0.78 m café tabletops (collider 0.72 + crumb lift) and the 2.0 m
plaza plinth. The splat capsule grew WITH the visual: **tourist and elder
CapsuleShape3D r 0.28 / h 1.75 at y 0.875** (was 0.25/1.1/0.55).

**Known pin breaks, re-derived in this change-set:**

- `people_and_cars_swapped` inverted → **`people_on_one_rig`**: the shared
  rig scene + Model = the glb + stamped metadata; the six-clip whitelist
  (no banned families, 53 bones); skinned + rigid parts with materials; the
  citizen arm layouts; the envelope measured live (head bone + bone-to-top
  → 1.7507 ± 0.02); the walk-rate law value-locked (`speed × 1.3333 /
  1.3239`, live tourist `speed_scale` within 0.02); the grown capsule on
  both citizens; the car legs kept verbatim; the text audit extended.
- The capsule literals (`:8193-8196`) → 0.28/1.75/0.875 above.
- The mitt head-line read (`:7901`): 1.42 → **≥ 1.90** (0.15 above the new
  head line; the raised carrier's probe point measures ≈ 2.16 — margin
  0.26). `citizen_classes_readable` passes with only that literal amended.
- The ticket's "1.22 m envelope pin (`tests/sim_test.gd:7640`)" turned out
  to be the **intersection-furniture post pin** (sign columns at y 1.22 —
  city layout, not people); the people-envelope 1.22 lived in the retired
  bake tool's `HEAD_TOP` and in the mitt read above. The furniture pin was
  never at risk and re-ran green (fingerprint 1103197745 holds).
- The T-060 hitbox-coach band **did not move**: `poop_hits_tourist_within_
  lead_window` re-ran green untouched (reach 0.30 + 0.28 = 0.58 — the stray
  margin 0.92 m stays clean, the 0.4 m bar connects); the coach is
  untouched (bigger targets made splats easier, never harder — no evidence
  for a retune).

**Color laws ride the skinned mesh.** `citizen_classes_readable`,
`civilian_palette_reserved`, `citizen_classes_spawn_deterministic`,
`tourist_splat_panics_scores` (the shirt flush through
`_body_mesh.material_override`) all re-ran green with the T-113 mechanism
byte-intact — the overrides duplicate the part mesh's surface material
exactly as before.

**Web delta (T-124 baseline, measured 2026-10-26).** `index.pck`
27,819,668 → **26,517,336 B (−1.24 MB** — the retired pose-bake meshes
outweigh the added skeleton+clips); `index.wasm` 39,514,754 and `index.js`
279,815 byte-identical; `SharedArrayBuffer` count 0, `nothreads` markers
present. **The quaternius exclusion is lifted** from `export_presets.cfg` —
the imported rigged scene IS the people source now, so it must ship; the
source `.glb` file itself still never downloads (the pck carries only the
imported, whitelist-pruned `.scn`), and the Kenney car-pack source stays
excluded (cars remain baked). This amends the ticket's "third-party pack
sources stay excluded" line: it can only hold for the pack whose contents
are not the game's own people source.

**Round 1 review fix (2026-10-26).** The reviewer caught a visible
regression the first commit shipped: the record above claims "the elder
raises only the near right", but `show_rigid_arms(false)` hid BOTH of the
elder's rigid arms (the near right included — the import emits no skinned
right arm), and `set_arm_pose` early-returned on invisible nodes — the
elder rendered ONE-ARMED and the T-078 trust raise was a visual no-op,
while the suite stayed green because the T-078 scenarios read the
`_arm_raise` member and the new scenario pinned the broken layout instead
of catching it. Reproduced red-before with a headless probe
(`arm_skinned_l=true arm_l_rigid=false arm_r_rigid=false`; driving
`_arm_raise = 1.0` through the real `_animate` path moved the near hand
−0.002 m; tourist control +0.768 m). Fix: the near RIGHT arm is rigid and
visible for BOTH citizens (it serves the tourist's panic raise / foam
finger AND the elder's trust arm); only the tourist shows the extra rigid
left; `set_arm_pose` no longer skips invisible nodes. `people_on_one_rig`
now also reads the raise GEOMETRICALLY through the real path — staging the
T-078 share beat (`_arm_left`) and requiring `hand_r_slot` world Y to lift
> 0.4 m as `_arm_raise` reaches 0.95 — which fails the one-armed layout by
construction. Red-before probe: delta −0.002 m; after the fix: the near arm
visible and the hand lifts 0.820 → 1.589 m (+0.770); FULL suite 158/158.

**Gates run in this change-set.** Gate 1 (`--import` clean, 120-frame boot
clean; `--check-only` on touched scripts shows only the pre-existing
autoload-identifier artifact — proven identical on the untouched HEAD
tourist.gd, and the boot compiles everything with zero script errors).
Gate 1b: FULL suite **158/158, 0 failures** (the honest count — an earlier
interim run printed 157/157 while `people_on_one_rig` was silently
crashing: the scenario read rig parts off an instantiated-but-never-added
citizen whose `_ready` had not run, and a crashed async scenario prints no
FAIL line; fixed by adding both citizens to the tree first and by giving
`PeopleRig.adopt()` the same detach-first treatment as `mount_prop`, which
also silences a "Cane already has a parent" error every elder spawn used to
print). Explicitly re-run green:
`elder_shares_bread_after_hangout`, `elder_placement_no_rng`,
`elder_no_bread_airborne`, `elder_cooldown_blocks_second_share`,
`elder_relocates_after_share`, `elder_migration_deterministic`,
`citizen_classes_readable`, `civilian_palette_reserved`,
`citizen_classes_spawn_deterministic`, `tourist_splat_panics_scores`,
`poop_hits_tourist_within_lead_window` (the T-060 coach scenario),
`restart_resets_run`, `people_on_one_rig` (new). Gate 2: autoplay
`AUTOPLAY DONE ok=true restart=true` (135 fps, 0 script errors) + the web
export above. Gate 3 agent grabs in `.captures/t138_rig/`:
`tourist_walking.png` (a visitor mid-stride across a crosswalk — real clip
stride) and `scale_table_bench_door.png` (a pedestrian beside café table,
bench and doors reading adult) stand post-fix; `elder1_seated_preround1.png`
is retained as RED evidence — the seated grandpa as the first commit shipped
him, ONE-ARMED (the round-1 review bug; the fixed near arm and its raise are
proven geometrically, see the round-1 note above, not yet re-grabbed). The
walking-grandpa, the raised trust arm in frame, and the side-by-side
[screenshot] lines stay open for the reviewer's pass (the pilot's share
flow needs favor ≥ 4, which a fresh pilot run cannot stage; the walk and
raise behavior are machine-proven by the migration scenarios, the
rate-matched clip pin and the new geometric raise leg).

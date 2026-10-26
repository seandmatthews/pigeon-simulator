# T-138 — One people rig: every human on the live Quaternius skeleton — real walks, sits, adult scale

- **Milestone:** People rig (owner ask 2026-10-26, dictated after noticing the
  elder/tourist visual gap post-T-137) · **Status:** proposed ·
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

- [ ] ONE rigged human scene is the only people source; both `tourist.tscn`
      and `elder.tscn` instance it; the per-part bake meshes
      (`assets/generated/models/people/*`) and the people half of
      `tools/bake_people_cars.gd` are retired and deleted; `assets/CREDITS.md`
      reflects the rigged scene.
- [ ] Every human walks on a real clip: tourist stroll and elder shuffle
      play looped walk animations rate-matched to their move speeds (no
      skating), elders sit via the sit clip with hips on the seat plane,
      RISING/ARRIVING blend; PANIC/FLINCH keep their script comedy layer on
      top; the death/hit clips are imported nowhere (audit leg green).
- [ ] The trust arm is a rig attachment driven by the unchanged
      `_arm_raise` code; the FULL elder scenario set — T-078 arm legs,
      `elder_shares_bread_after_hangout`, `elder_placement_no_rng`, both
      T-137 migration scenarios — passes UNTOUCHED.
- [ ] Humans are adult-scaled against the furniture: the pinned head-top
      value (≈ 1.75 m, exact from the furniture probe) with the capsule
      grown to match; the grown value and the mitt/head-line relationship
      re-derived and pinned; the T-060 splat band re-measured with the
      result recorded (coach retuned only on evidence).
- [ ] Class color laws green unchanged (`citizen_classes_readable`,
      `civilian_palette_reserved`); `citizen_classes_spawn_deterministic`
      untouched and green.
- [ ] (Gate 1b) new `people_on_one_rig` scenario replaces
      `people_and_cars_swapped` per Known pin breaks, and the FULL suite is
      green (0 failures).
- [ ] (Gate 2) autoplay green + web export re-run with the pck byte delta
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

## Implementation record

*(pending — pipeline route; the elder contract scenarios are the
must-pass-unchanged tripwire)*

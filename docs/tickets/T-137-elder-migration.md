# T-137 — The grandpa shuffle: elders relocate after a share, walking there themselves

- **Milestone:** City identity follow-up (owner pitch 2026-10-24, forks picked
  same day) · **Status:** proposed · **Category:** worldbuilding ·
  **Value (1-5):** 3 · **Risk (1-5):** 2
- **Depends on:** T-135 (park seats must exist to migrate between) — build
  order T-135 → T-136 → T-137 per the owner
- **Refs:** `scripts/elder.gd` (StaticBody3D today — its own header: "Elders
  don't walk"; procedural arm, no skeleton) · `scripts/elder_spawner.gd`
  (seats spots 0/2/4/6 of `city.elder_spots`, the plaza ring) · the Tourist
  pattern (`scripts/tourist.gd`: CharacterBody3D layer 3, waypoint walking
  with reach/turn easing, WALK/PANIC/FLINCH) · `City.sidewalk_loop()` +
  `block_centers` (per-block loops) · T-069/T-102 crosswalks (every unblocked
  intersection approach) · the T-095 pilot-events precedent · T-114 (elder
  bread = favor-spend surface).

## What

After an elder's bread share, that elder stands up, shuffles out of the
plaza/park, crosses streets at crosswalks, and takes a bench in a different
district — a fully visible, fully ambient walk. The plaza stays the boot
home; migration is earned one share at a time.

1. **Seats (city leg, T-135's parks gain their bench):** ONE pinned, zero-RNG
   bench per park at a fixed offset from the block center — (0, 0, +3),
   facing the center — via the ordinary `_add_bench` (seat top slab + 0.60,
   one GROUND bread spot each, `_counts.benches` +4). Placement arithmetic
   matches the pinned T-030 prop margins: 4.24 m from the nearest (±5, ±5)
   park tree center − 1.84 m crown half-diagonal − 0.9 m bench half-extent
   ≈ 1.50 m margin; ≥ 6.7 m from every lamp/bin/bread-ring position. Zero
   RNG draws, zero `_fp` entries. The four bench seats append to
   `elder_spots` (indices 8–11) — the boot path is UNCHANGED: the spawner
   still seats elders at spots 0/2/4/6, all plaza.
2. **The pick (owner fork 4 — prefer a different district):** on each
   `bread_shared`, the elder reserves a destination before standing: pool =
   all 12 seats minus its own minus occupied minus reserved, restricted to
   seats whose district differs from its current one — the plaza seat
   carries a sentinel district (−1) so EVERY park differs from the plaza
   (the plaza is the center, not district 0's block); park seats use
   `district_of`. The pool is never empty (the four parks cover all four
   districts). The pick is a deterministic hash of (run seed, elder's
   cumulative share count) over the pool — no RNG stream, replayable.
3. **The walk:** Elder re-roots StaticBody3D → CharacterBody3D (layer 3
   `npc`, the Tourist body config). States: SEATED → RISING → WALKING (→
   CURB_WAIT) → ARRIVING → SEATED. Route legs, all on existing geometry:
   leave the seat → origin block's sidewalk ring (`City.sidewalk_loop`) →
   crosswalk crossings (the diagonal plaza↔park hop is two perpendicular
   crossings at one intersection, deterministic order) → destination ring →
   the pinned bench. Walk speed export ≈ 0.8 m/s (grandpa beats the
   tourists' 1.3). The shamble is procedural in the box recipe — yaw easing
   along the current leg plus a bob sine scaled by speed; no skeleton, no
   AnimationPlayer, the arm machinery untouched. **CURB_WAIT (owner fork 2):
   before each crossing the elder pauses until no car is within 15 m and
   closing; cars NEVER yield** — rare clip-throughs accepted; car-yield at
   crosswalks is a possible future ticket, explicitly not this one. Timing
   is deterministic-by-simulation (same seed → same cars → same waits).
4. **Behavior edges:** trust accrues only while SEATED (walking pauses
   accrual, no decay — the existing bank/decay rules already cover
   walk-aways); trust PERSISTS through the walk (same grandpa). Elders still
   ignore splats and buzzes. The PresenceZone rides along but banks nothing
   mid-walk. `restart_run()` resets everything (4 elders re-seated on the
   plaza ring) — migration is per-run ambient, no persistence. A pigeon
   squatting on the destination bench gets slid off (CharacterBody vs
   CharacterBody) — accepted.
5. **Bookkeeping:** `elder_count` stays 4; `living_elders()` unchanged;
   occupied/reserved exclusion in the pick pool means two elders never share
   a bench (share order is itself deterministic, so the chain resolves).
6. **Pilot visibility:** an `elder_relocated` event (elder, from seat,
   to seat) relayed to the CaptureRecorder — the T-095 precedent, so pilot
   sessions can watch and agents can assert on it.

**Known pin breaks, amended in the same change-set (mandatory):**

- The four park benches add 4 `bread_spots` → the `city_roofs_inhabited`
  city-wide total ledger literal refreshes (+4; the formula itself stands —
  `_counts.benches` absorbs them; bench crumbs sit at slab + 0.60 < 1.0, so
  the y > 1.0 roof-spot population and `spots_ok` are untouched).
- `city_park_trees_present`: the "every tree ≥ 2.0 m XZ from every
  bread_spots entry" leg re-measures (the pinned bench crumb is 4.24 m from
  the nearest tree — still green); the row's measured values refresh.
- `city_plaza_props_clear` is unaffected (park benches sit ~45 m outside its
  16 m census). No fingerprint move anywhere: zero RNG draws, zero `_fp`
  entries.
- The boot-path elder scenarios (`elder_shares_bread_after_hangout`,
  `elder_placement_no_rng`, the T-078 arm legs) must pass UNCHANGED — boot
  byte-identical is the regression tripwire.

Not claimed: car yielding at crosswalks (future ticket if clip-throughs
offend — owner fork 2), elders spreading across the city at boot, elder
reactions to splats/buzzes, elders on the bread globe or any tracker, migration
persistence across runs, changing `elder_count`, tourist/citizen migration,
walking routes that ignore crosswalks.

## Why

Owner pitch 2026-10-24, verbatim intent: "when an elder gives you bread, for
them to disappear from a park/plaza and show up at a different one. Ideally
they'd walk the whole way there." Forks picked same day: migrate after EVERY
share; cars never yield (future ticket if needed); build order
T-135 → T-136 → T-137; prefer a different district. The favor loop gains an
ambient chase beat — feed a grandpa, watch him amble off, find him again —
while the plaza keeps its at-a-glance boot readability and the T-114 economy
unchanged (same vendors, same costs, same trust rules; only their benches
drift). Tone check passes: fully ambient, no tracker, no objective, nobody
harmed — the charm IS the slow walk. The Tourist pattern plus the
procedural-arm elder rig make this an M, not an L: no new animation tech, no
new pathing tech, no pin storm (T-135 already paid the layout one).

## Acceptance criteria

- [ ] One pinned bench per T-135 park (fixed (0, 0, +3) offset, facing
      center, the ordinary `_add_bench` recipe: seat bread spot, `_counts`
      bookkeeping, zero RNG, zero `_fp`); its seat recorded in
      `elder_spots`; the boot population unchanged (4 elders, plaza ring
      spots 0/2/4/6).
- [ ] After EVERY share the elder relocates: it stands, walks the route on
      sidewalk rings and crosswalks, and arrives SEATED at a bench whose
      district differs from its origin (plaza counts as district-less); two
      elders never share or double-reserve a bench; `elder_count` stays 4.
- [ ] The pick is a deterministic hash of (run seed, share count) over the
      then-free different-district pool — no RNG stream draws anywhere in
      the migration path.
- [ ] CURB_WAIT holds before every crossing: the elder does not enter a
      road while a car is within 15 m and closing; cars' behavior is
      untouched (no yield code lands).
- [ ] Trust persists through the walk (sampled mid-walk), accrual is paused
      while not seated, and no decay wipe occurs; the elder ignores splats
      and buzzes as today.
- [ ] (Gate 1b) new `elder_relocates_after_share` scenario on a real Main
      rig: staged trust → real share → the destination matches the
      scenario's own hash-chain recomputation (different district, free
      seat); the state machine walks SEATED → WALKING (CURB_WAIT observed
      when a car approaches) → SEATED at the picked park bench within a
      bounded window; `elder_relocated` fires exactly once with the right
      seats; `elder_count` stays 4; a pigeon parked mid-route does not
      corrupt the walk.
- [ ] (Gate 1b) new `elder_migration_deterministic` scenario: two same-seed
      runs produce identical destination sequences (the hash chain), while
      the boot-path elder scenarios (`elder_shares_bread_after_hangout`,
      `elder_placement_no_rng`, T-078 legs) pass unchanged.
- [ ] (Gate 1b) `city_roofs_inhabited` (total ledger +4) and
      `city_park_trees_present` (re-measured tree-to-crumb distances) green
      with refreshed literals; FULL suite green, 0 failures.
- [ ] (Gate 2) `AUTOPLAY DONE ok=true` with migrations live (autoplay's
      incidental plaza shares may relocate elders; nothing in the autoplay
      pins elder positions).
- [ ] [screenshot] A mid-walk elder reads as a grandpa shuffling (upright,
      bobbing, clearly en route at a crosswalk or sidewalk), and the
      destination park shows the newly seated elder on its pinned bench.

## Verification

Gate 1 (import + 120-frame boot + `--check-only` on the touched scripts) +
Gate 1b full suite green with the two new scenarios in the `VERIFICATION.md`
table and the refreshed rows noted above (same change-set); explicitly
re-run `elder_relocates_after_share`, `elder_migration_deterministic`,
`elder_shares_bread_after_hangout`, `elder_placement_no_rng`,
`city_roofs_inhabited`, `city_park_trees_present`, `city_plaza_props_clear`,
`citizen_classes_spawn_deterministic`, `restart_resets` + Gate 2 + Gate 3
new line — "(T-137) After a share the elder stands, shuffles the route
(waits at a curb), and sits down in a different district [screenshot of a
mid-walk elder]".

## Implementation record

*(pending — pipeline route after T-136; parks-first is what gives the
migration somewhere to go)*

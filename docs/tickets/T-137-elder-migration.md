# T-137 — The grandpa shuffle: elders relocate after a share, walking there themselves

- **Milestone:** City identity follow-up (owner pitch 2026-10-24, forks picked
  same day) · **Status:** done · **Category:** worldbuilding ·
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

- [x] One pinned bench per T-135 park (fixed (0, 0, +3) offset, facing
      center, the ordinary `_add_bench` recipe: seat bread spot, `_counts`
      bookkeeping, zero RNG, zero `_fp`); its seat recorded in
      `elder_spots`; the boot population unchanged (4 elders, plaza ring
      spots 0/2/4/6).
- [x] After EVERY share the elder relocates: it stands, walks the route on
      sidewalk rings and crosswalks, and arrives SEATED at a bench whose
      district differs from its origin (plaza counts as district-less); two
      elders never share or double-reserve a bench; `elder_count` stays 4.
- [x] The pick is a deterministic hash of (run seed, share count) over the
      then-free different-district pool — no RNG stream draws anywhere in
      the migration path.
- [x] CURB_WAIT holds before every crossing: the elder does not enter a
      road while a car is within 15 m and closing; cars' behavior is
      untouched (no yield code lands).
- [x] Trust persists through the walk (sampled mid-walk), accrual is paused
      while not seated, and no decay wipe occurs; the elder ignores splats
      and buzzes as today.
- [x] (Gate 1b) new `elder_relocates_after_share` scenario on a real Main
      rig: staged trust → real share → the destination matches the
      scenario's own hash-chain recomputation (different district, free
      seat); the state machine walks SEATED → WALKING (CURB_WAIT observed
      when a car approaches) → SEATED at the picked park bench within a
      bounded window; `elder_relocated` fires exactly once with the right
      seats; `elder_count` stays 4; a pigeon parked mid-route does not
      corrupt the walk.
- [x] (Gate 1b) new `elder_migration_deterministic` scenario: two same-seed
      runs produce identical destination sequences (the hash chain), while
      the boot-path elder scenarios (`elder_shares_bread_after_hangout`,
      `elder_placement_no_rng`, T-078 legs) pass unchanged. *(The two
      share-path scenarios required the minimal T-137 amendments recorded in
      their VERIFICATION rows — the elder departs after a share, so the
      pre-shuffle "trust re-pins during the cooldown" read became "arm still
      pinned + state off SEATED + the reserved park seat in the book", and
      the cooldown leg follows him to the new bench. `elder_placement_no_rng`
      grew the mandated 12-spot legs; every pre-existing arm in all three
      still asserts.)*
- [x] (Gate 1b) `city_roofs_inhabited` (total ledger +4) and
      `city_park_trees_present` (re-measured tree-to-crumb distances) green
      with refreshed literals; FULL suite green, 0 failures.
- [x] (Gate 2) `AUTOPLAY DONE ok=true` with migrations live (autoplay's
      incidental plaza shares may relocate elders; nothing in the autoplay
      pins elder positions). *(The recorded run's pilot earned no plaza
      share — `shares=0 relocations=0`, the AC's "may" — the migration
      system itself is live and machine-proven by the two Gate 1b
      scenarios.)*
- [x] [screenshot] A mid-walk elder reads as a grandpa shuffling (upright,
      bobbing, clearly en route at a crosswalk or sidewalk), and the
      destination park shows the newly seated elder on its pinned bench.
      *(Agent grabs 2026-10-25, `.captures/t137_walk/` — the reviewer
      sign-off rides the Gate 3 line.)*

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

*(Reviewer sign-off landed 2026-10-26 — the Gate 3 line ticks on it; all
acceptance criteria above ticked on the recorded evidence.)* — Landed
2026-10-25, one commit on `feature/t-137`.*

Final tuned values as shipped:

- Elder shuffle exports: `walk_speed` 0.8 m/s (tourists stroll 1.3),
  `walk_turn_rate` 4.0 1/s, `waypoint_reach` 0.6 m, `rise_seconds` 0.6,
  `stand_off` 0.9 m, `bob_rate` 5.0 Hz, `bob_height` 0.035 m,
  `hunch_rate` 2.0 1/s (HUNCH_SEATED 0.18 ↔ HUNCH_WALKING 0.06),
  `curb_car_radius` 15.0 m, `stall_skip_seconds` 0.5.
- Trust/sharing exports unchanged from T-020/T-114: fill 1.0/s, decay 2.0/s,
  `trust_needed` 4.0, `share_cooldown` 25.0 s, 2 crumbs at 1.2 m ± 0.4,
  `elder_loaf_cost` 2 (a share spends 4 favor).
- Seats: park bench at block center + (0, 0, +3), yaw 0 (facing the center),
  seat top slab + 0.60; `elder_spots` 8–11 = `PARK_BLOCKS` order =
  districts 0,1,2,3; plaza seats 0–7 sentinel district −1.
- The pick: `hash(Vector2i(seed, share_number))`, folded once with the seed
  (`hash(h ^ seed)`), masked `& 0x7fffffff`, indexed into the
  different-district free pool — replayable from the seed alone.
- Measured: fingerprint pins held byte-identically (20260928 → 1103197745,
  424242 → 1411023184); bread spots 774 → 778 (GROUND 532 = 392 ring +
  140 bench); park-tree worst crumb distance exactly 2.00 m (d1 axial tree);
  worst bench-to-bread-ring spot 9.37 m; a full plaza↔park migration walks
  ≈ 20 s at the scenario's 6 m/s window pace (the shipped pace: ≈ 2 min
  of ambient shuffle, CURB_WAIT pauses on live traffic).

- **Seats (city):** `_build_park_elder_seats` (city.gd) appends one pinned
  bench per `PARK_BLOCKS` park after the block loop — the ordinary
  `_add_bench` with a new `pin_fingerprint` default-true parameter; the park
  benches pass `false`, the ticket's zero-`_fp` mandate, so every
  cross-version fingerprint pin held WITHOUT a re-derivation (seed 20260928
  → 1103197745, seed 424242 → 1411023184, re-proven green). `elder_spots`
  grows 8 → 12 (park seats 8–11, `PARK_BLOCKS` order = districts 0,1,2,3)
  and the new `elder_seat_districts` array carries the sentinel −1 for the
  plaza seats. Boot path unchanged: spots 0/2/4/6.
- **The pick (spawner):** `_reserve_destination` builds the
  different-district free pool and picks with `_migration_roll` —
  `hash(Vector2i(seed, share_count))` folded once with the seed, masked
  positive; zero RNG of any stream. Reservations live in `_reserved` and in
  the elder's `current_seat` (set synchronously in `begin_migration`), so a
  walking elder's destination is never re-picked; `relocation_count` rides
  the autoplay DONE line.
- **The walk (elder):** re-rooted StaticBody3D → CharacterBody3D (the
  tourist's exact body config: capsule r 0.25 / h 1.1 at y 0.55, layer 3
  `npc`, mask 1). States SEATED → RISING → WALKING (CURB_WAIT) → ARRIVING
  → SEATED. Routes are built as pure layout math: stand point → origin
  ring (`sidewalk_loop`'s square, corners in travel order) → X-then-Z
  per-block steps, each ONE road crossing at the pinned T-069 band of the
  shared corner node (the diagonal plaza↔park hop is two perpendicular
  crossings at one intersection) → destination ring → the bench's own
  forward lane (opposite ring point, through the block center, stopping at
  the stand point in front of the seat). Trust accrues only while SEATED;
  mid-walk the bank is frozen (no accrual, no decay). CURB_WAIT reads the
  static `Car._fleet`: hold while any car is within 15 m AND closing; cars
  untouched. A progress watchdog (`stall_skip_seconds` 0.5) skips a waypoint
  the shuffle cannot make ground on — an RNG edge bench can sit anywhere
  along a lane, and the shuffle must never strand; the ARRIVING lerp covers
  the last gap onto the seat, byte-exact via the seat transform.
- **Known deviation (recorded per the ticket's own arithmetic):** the
  ticket's placement note measured the bench crumb 4.24 m from the nearest
  tree using the corner trees; d1's axial tree at (0, +5) pins the true
  worst at exactly 2.00 m XZ from the (0, 0, +3) crumb — still green on
  the ≥ 2.0 m leg (exact in floating point), and the refreshed
  `city_park_trees_present` row records it. Lamp/bin/ring margins hold
  (worst bread-ring spot 9.37 m, ≥ 6.7 m as specified).
- **Verification:** Gate 1 import + 120-frame boot clean (one accepted
  godot_mcp teardown ERROR line per the VERIFICATION notice);
  `--check-only` on the touched scripts fails on autoload identifiers even
  for UNTOUCHED scripts in this worktree (verified on `tourist.gd`), so the
  import+boot legs carry Gate 1 here. Gate 1b FULL suite 158 SIM PASS / 0
  failures (`elder_relocates_after_share` and `elder_migration_deterministic`
  new; the named re-run set all green). Gate 2 `AUTOPLAY DONE ok=true
  restart=true` (fps 137, 0 shares that run — the AC's "may").
  Screenshots in `.captures/t137_walk/` (mid-walk shuffle at the corner
  crosswalk; the newly seated elder on the pinned park bench in district 2).

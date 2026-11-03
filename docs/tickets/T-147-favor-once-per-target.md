# T-147 — Favor pays once per target; spent cars churn out of the fleet at the recycle radius

- **Status:** done · **Category:** worldbuilding · **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-114 (the favor book this gates), T-128 (the sightline gate + the recycle machinery the churn rides), T-054 (the BandSpawner scan), T-113 (the citizen classes the like-for-like carry preserves) — all done
- **Refs:** owner idea (2026-11-02, dictation: first splat of a car or pedestrian books favor, repeats still honk and score but add zero favor; a splatted car becomes despawn-eligible at the 100 m car recycle radius and is freed-and-replaced by a fresh off-screen car, fleet count constant) · T-140's "Live proof" record (`docs/tickets/T-140-pilot-frame-step.md`: *"Parked visitor cars are re-splattable +6 fountains (cars never flee, splats never dedup)"*, parked as an open IDEAS.md B-6 question) — **this ticket is the owner's decision on that question's favor axis** · `docs/DESIGN.md` → Milestone 2 (the goal run: a session ends at favor-max or starvation, so the favor economy is the win condition this protects)

## What

Two changes on the splat→favor edge, one on the book side and one on the fleet side.
**References do not apply:** repeat-splat dedup and despawn churn are game-invented
affordances with no real-world counterpart to photograph (the T-114 precedent line),
so every criterion below is derived from repo constants and landed machinery.

### 1. The once-per-target favor book (`scripts/car.gd`, `scripts/tourist.gd`, `scripts/main.gd`)

Today every splat books favor unconditionally: `Tourist.on_splatted`
(`scripts/tourist.gd:155-166`) and `Car.on_splatted` (`scripts/car.gd:644-646`) emit
`splatted`, and Main's handlers call `Game.splat_favor(...)` beside the score call on
every relay (`scripts/main.gd:660`, `:671`) — the same parked visitor car pays
+`favor_visitor_car_splat` (6) on every poop, forever. The fix:

- **One flag per target node:** `var splatted_once: bool = false` on both `Car`
  (`scripts/car.gd`, beside `honk_count`) and `Tourist` (`scripts/tourist.gd`), docstring
  naming its two readers — Main (the favor gate) and `CarSpawner` (despawn eligibility).
- **One writer each:** the node's own `on_splatted` sets `splatted_once = true` AFTER the
  `splatted.emit(self)` line. The order is load-bearing and must be commented as such:
  Godot signals are synchronous, so Main's handler runs during the emit and reads
  `splatted_once == false` exactly on the first splat — that is the whole gate. The new
  Gate 1b scenario pins this (a regression that moves the set before the emit silently
  kills first-splat favor and fails that scenario).
- **Two readers in Main:** `_on_tourist_splatted` (`scripts/main.gd:656-660`) and
  `_on_car_splatted` (`:667-671`) wrap ONLY the favor call:

  ```gdscript
  Game.add_car_hit(car.global_position)
  if not car.splatted_once:
      Game.splat_favor(car.citizen_class, true)
  ```

  `Game.splat_favor(kind, vehicle)` keeps its signature (`scripts/game.gd:301-311`) —
  no autoload change, no per-run spent-set to reset (the flags are per-run state by
  construction: every node dies at the next `_populate`/restart, and `Game.reset_run()`
  is untouched).

**Uniform rule, all classes, both signs:** a repeat splat books 0 regardless of class —
including the negatives. A second hit on the same civilian car adds 0, not another
−2 (spam re-splats can't bleed extra debt); a second hit on the same superfan adds 0,
not another −8. **Everything else about a splat is byte-identical:** the honk and body
flash (`Car.honk`), the score (`Game.add_car_hit`/`add_tourist_hit` still called on
every splat — the 100/30 table, combos, style bonus all still chain on repeats), the
tourist panic/yelp/shout, the T-123 smug-coo parity (`Game.tourist_hits % 2`),
`CarSpawner.honk_count`'s splat-relay counting, and the hit marker.

**Tourists get the flag only** — no fleet change. The tourist spawner's recycle stays
teleport-the-same-node, so a spent tourist stays spent through `recycle_to`
(`scripts/tourist.gd:172-179` moves the same node; same node = same target = spent).

### 2. Spent cars churn out of the fleet (`scripts/car_spawner.gd`)

Today `_recycle_far` (`scripts/car_spawner.gd:207-232`) teleports EVERY car beyond
`recycle_radius` 100 flat (`_init` override, `scripts/car_spawner.gd:129`) back into
the band — including a car you just splatted and left behind, so the same spent node
waits at the new curb to be farmed again. The change — inside the existing scan
(`recycle_interval` 0.5 s, `scripts/band_spawner.gd:66-72`), zero new tunables:

- **Partition the far list:** a car beyond `recycle_radius` of the anchor
  (`_anchor_flat()`, the pigeon's XZ) that carries `splatted_once == true` is
  **despawn-eligible** → `_replace_car(car)`; every never-splatted far car takes
  TODAY's teleport arms byte-identical (parked → `_recycle_parked_to`, traffic →
  `_route_rejoin` + `_offscreen_route_rejoin` + `start_route`). Iterate a duplicate of
  the far list; apply each swap (`_cars.erase(spent)`, `_cars.append(fresh)`) only after
  the replacement stands.
- **`_replace_car(spent: Car) -> bool`** stages a FRESH node
  (`car_scene.instantiate()`, the `_spawn_traffic` field-assignment pattern,
  `scripts/car_spawner.gd:242-277`) with a **like-for-like identity**: the spent car's
  `citizen_class`, `body_color` (civilians keep their palette paint, visitors keep
  their black↔gold paint direction), and `pace` — then `_assign_tailgate` (cooler +
  bread service by class, `scripts/car_spawner.gd:296-298`), `traffic = traffic_ctrl`,
  and the `route_exhausted`/`splatted` connects (`:275-276`, `:288`). Like-for-like is
  a named decision, not convenience: it keeps every mid-run count stable (the 14 + 12
  fleet, the class multiset, the roundi(12 × 0.40) = 5 parked-visitor tailgate crumbs)
  without touching the populate-scoped `_begin_class_quota` machinery, and zero RNG —
  no draw on any stream.
- **Placement is strict-gate, no least-bad fallback.** The replacement must enter
  off-screen through the existing gate (`_sightline_ok`, `scripts/car_spawner.gd:664-673`)
  — that is the owner's sentence. Parked: draw the block with the existing
  `_pick_recycle_block(blocks)` (`:573-578`), then the strict finders only —
  `_offscreen_spot` (`:729-734`) on the drawn block, else `_offscreen_band_spot`
  (`:741-746`) — then `park_at`. Traffic: `_route_rejoin(block, fresh, true)`
  (`:543-550`), else `_offscreen_route_rejoin` (`:559-564`), then `start_route`. The
  one `_recycle_parked_to` behavior deliberately NOT reused is its final
  free-drawn-spot stand: for a replacement, an in-view stage is a pop, and unlike a
  recycle there is no count contract forcing the stage — see below.
- **Place-then-free, never starve:** only when the replacement's placement resolves
  does the fresh node `add_child` + stage, the swap land in `_cars`, and the spent car
  tear down (`release_tailgate()` first — the `_populate` free-loop precedent,
  `scripts/car_spawner.gd:140-143`, so a parked visitor's crumb never orphans — then
  `queue_free()`; its stop-ledger state releases in `_exit_tree`,
  `scripts/car.gd:786-790`). If no gate-passing placement exists this scan, free the
  staged node (if any) and keep the spent car: it is already >100 m out of reach, the
  fleet count never dipped, and the next 0.5 s scan retries. The fleet COUNT contract
  holds at every instant — exactly 26 cars, 14 TRAFFIC + 12 PARKED, before, during and
  after.
- **The loop this buys:** a fresh replacement is splat-fresh (`splatted_once == false`),
  so favor becomes renewable again — but only through travel (fly >100 m, let the churn
  run, come back to a new car) instead of stationary re-splats. That is the intended
  economy: the +6 jackpot requires finding fresh targets, and the city keeps supplying
  them.

**Pin-naming:** `recycle_radius` 100.0 flat is THE despawn threshold, read from the
existing export (no constant duplication); the pigeon ("the player anchor") is
`_anchor_flat()`, the same anchor the teleport path uses.

**What this does NOT claim:** no score change — repeat splats still pay the 100/30
table, still chain combos and style bonuses, still spawn popups and hit markers (score
farming of a parked car stays possible; score is not the win condition — only the
favor axis of the T-140 fountain note closes here); no honk/audio change of any kind;
no tourist fleet change — teleport recycle, walk loops, panics all untouched; no
change for never-splatted cars — the teleport path is byte-identical; no
`Game`/autoload change — `splat_favor`'s signature, `add_favor`'s cap semantics and
`reset_run()` untouched; no class re-roll and no populate/quota/RNG-stream change (the
seeded multisets and both pinned seed draws stand); no change to the sightline gate
itself (`sightline_gate_enabled`, `spawn_sightline_max` 80, `spawn_avoid_cone_deg` 55
as shipped); no new input action and no controls-table change; no City generation
change; no new tunables.

## Why

The owner's idea, aimed at a recorded degenerate loop: T-140's frame-step run won the
game (favor 100 → the T-115 victory screen) via 17 re-splats of ONE parked visitor
car, and the record explicitly flagged re-splattable +6 fountains as too easy
(`docs/tickets/T-140-pilot-frame-step.md`, "Live proof"), parked on IDEAS.md B-6. Until
this lands, the favor meter — the win condition (`docs/DESIGN.md` → Milestone 2, the
goal run) — measures patience, not hostility: sitting on one stationary car out-earns
hunting the whole city. Favor paying once per target makes the meter mean what the M2
pitch promised ("the town is yours" earned by making the town hostile, target by
target), and the despawn churn is what keeps the win attainable after the change: the
fleet continuously replaces spent cars with splat-fresh ones, so a run can still reach
favor-max — by moving, aiming, and reading the streets (the blinker tells, the black-
and-gold uniforms) instead of grinding one curb. Player value on both ends: repeats
still FEEL acknowledged (honk, flash, points, combo) so nothing reads as broken, and
long splat-heavy runs no longer leave a trail of identical spent cars — the city
renews. Value 4 not 5 because the score half of the fountain stays open by design
(IDEAS.md B-6's D4 weighting question is untouched). Risk 3 because the change sits
inside the load-bearing recycle machinery beside five pinned scenarios — mitigated by
place-then-free ordering, the strict-gate no-starve fallback (keep the spent car), the
like-for-like zero-RNG carry, and the untouched-by-construction pin list below.

## Acceptance criteria

- [x] The once-book is exactly as specified: `splatted_once` on `Car` and `Tourist`
      (default false, set in `on_splatted` after the emit, order-comment in place), and
      Main's two handlers gate ONLY the `Game.splat_favor` call on it — score, marker,
      honk and relay counting unconditional
- [x] *(Gate 1b)* `splat_favor_once_per_target` — through the real main scene (the
      instanced-Main pattern, `tests/sim_test.gd:244` neighbor): one real parked
      VISITOR car splatted twice via `on_splatted` moves `Game.favor` exactly
      +`favor_visitor_car_splat` ONCE (asserted against the export, never a literal)
      while `Game.car_hits` reads 2 and the combo chain shows both hits paid; one real
      tourist splatted twice pays its delta once and `Game.tourist_hits` reads 2; a
      CIVILIAN car splatted twice books −`favor_civilian_car_splat` exactly once (the
      second adds 0 — no negative bleed); the second splat still honks
      (`Car.honk_count == 2`); and a synthetic `Game.add_tourist_hit` stays
      favor-silent (the T-114 pin re-asserted)
- [x] *(Gate 1b)* `spent_car_despawn_replacement` — a real City + `CarSpawner` rig
      (the `cars_recycle_around_player` pattern): splat one parked car and one traffic
      car, teleport the player ~120 m west (the T-054 recipe, `tests/sim_test.gd:6579`),
      call `_recycle_far()` directly (the `citizen_classes_spawn_deterministic`
      pattern, `tests/sim_test.gd:7811`): the spent nodes are FREED (absent from
      `living_cars()`, invalid), the fleet still reads exactly `target_moving +
      target_parked` with the 14/12 mode mix, each replacement carries the freed
      car's `citizen_class` (and `body_color`/`pace` for the civilians' read), every
      replacement passes `_sightline_ok`, and a never-splatted far car is STILL THE
      SAME INSTANCE (instance id kept — the reuse contract survives for unspent cars)
- [x] *(Gate 1b)* the same scenario's no-pop leg: with the gate forced to reject every
      band candidate (`spawn_avoid_cone_deg` 180.0 → `_sightline_ok` false for
      everything within `spawn_sightline_max`), the spent far car SURVIVES the scan
      (not freed, fleet count constant) — and a follow-up scan with the cone restored
      replaces it, proving the retry path
- [x] *(Gate 1b)* a spent PARKED VISITOR car's replacement anchors a tailgate crumb
      (the visitor crumb count re-reads roundi(`target_parked` × `visitor_share`) = 5
      after the churn) — the released-then-re-dropped bread books stay clean
- [x] The pinned scenarios pass UNTOUCHED — each verified splat-blind or fresh-node by
      read this session: `cars_recycle_around_player` (no splats → all far cars
      teleport same-instance), `citizen_classes_spawn_deterministic` (its recycle leg
      splats nothing), `density_cpu_budget` (26 cars constant), `bread_steal_favor_deltas`
      (no splats), `splat_favor_follows_citizen_class` (every leg splats a node from a
      FRESH `_populate` once), `favor_max_ends_run_victory` (two DIFFERENT cars),
      `sfx_coos_and_stingers` + `audio_hit_sounds` + `car_splat_honk_and_continue`
      (bare rigs, no Main favor wiring); full suite green in one headless run, and
      VERIFICATION.md gains the two new Gate 1b rows in the same change-set
- [x] *(Gate 2)* autoplay green: the DONE line's honk/splat counts stay sane and no
      favor-dependent criterion regresses (autoplay reads no favor — verified by grep
      this session)
- [x] **(Gate 3 — human judgement)** The spent read at the curb: re-splatting the same
      car still honks, flashes and pays "+30 ×N" — it reads as a rude response, not a
      broken meter, and the favor note appears only on the first splat (accepted by
      reviewer sign-off 2026-11-02 — the reviewer played the branch build via the pilot
      harness and signed off; the machine arms live in the `splat_favor_once_per_target`
      Gate 1b row)
- [x] **(Gate 3 — human judgement)** The churn read in flight: after splatting a car
      and flying off beyond the radius, the streets never visibly thin or pop — fresh
      cars enter by driving/parking off-screen, and a long splat-heavy run still
      finds splat-fresh targets near where the pigeon is (accepted here when the
      owner's agent or the owner flies one such run and signs off) (accepted by
      reviewer sign-off 2026-11-02 via exactly that route; the machine arms live in
      the `spent_car_despawn_replacement` Gate 1b row)

## Verification

Gate 1 (`--import` + 120-frame boot, exit 0) · Gate 1b full suite
`godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn` with the two new
scenarios (`splat_favor_once_per_target` on the instanced-Main pattern,
`spent_car_despawn_replacement` on the car-recycle rig pattern; registered in
`_run_scenarios`, `tests/sim_test.gd:244` neighbor) and the pin list above re-asserted
green in the same run · Gate 2 autoplay (`AUTOPLAY DONE ok=true`, honk/splat counts
sane) · Gate 3: the two human lines above, added to VERIFICATION.md's Gate 3 checklist
in the same change-set. Tuned values (none expected — zero new exports; any retune of
`recycle_radius`/`recycle_interval` for churn feel is recorded here if made).

## Verification record (2026-11-02)

Tuned values: NONE — zero new exports; `recycle_radius` 100.0 and `recycle_interval`
0.5 stand as shipped. Gates: import + 120-frame boot exit 0; full Gate 1b suite green
in one headless run — 164 SIM PASS, 0 failures, both new scenarios plus every pinned
scenario re-asserted in the same run; Gate 2 autoplay `AUTOPLAY DONE ok=true` with the
DONE line byte-identical to a pre-change baseline run (deterministic replay — splats 8,
honks 0, no regression); autoplay reads no favor (grep over tests/autoplay.gd and
tests/tools/pilot.py: zero matches). Both Gate 3 lines accepted by the workflow
reviewer's sign-off after playing the branch build with the pilot harness.

Note for the implementer: `tests/tools/pilot_splat.py` (the T-140 worked example)
keeps working mechanically — its grind now yields favor on the first splat only. No
tooling change is in scope; the T-140 record stays as the honest history of the
pre-fix economy.

# T-181 — Ames R2 · pedestrian zones: people where Ames actually has people

- **Status:** doing · **Category:** worldbuilding · **Ring:** R2 The Life ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-177, T-180 (crossings to cross at)
- **Refs:** `census/BUILD-CENSUS.md` §5 (191.8 km footway — the reason
  zones, not coverage) · `community/REDDIT-RESONANCE.md` (Welch = the
  gathering street) · `venues/VENUES.md` Welch sequence · T-007
  (tourists), T-020 (elders), T-141..T-146 sit/rig work, T-165 (gait
  constants)

## What

Pedestrians move to activity zones — the sidewalks people actually
use — not the full 191 km of mapped footway:

1. **Zones** (pinned): the Welch Ave strip (Lincoln Way → 300 block),
   downtown Main Street, Central Campus paths, the LaVerne shore path,
   the MU corner. Each zone: sidewalk polyline set, population cap,
   bench/sit targets at real bench positions.
2. **Populations**: tourists cluster on Welch + downtown (the visitor
   premise), locals (elder class) on Central Campus + LaVerne — the
   favor economy's elder benches move with T-183, this ticket is
   placement + walking.
3. **Walking**: T-165's measured gait constants carry over unchanged;
   crossing at T-180's crosswalks only (no jaywalking simulation —
   the fence).
4. **No schedules** (the tone fence): zone presence is a density
   function (time-of-day may scale it LATER, only via an owner-picked
   R6 option) — nobody has an appointment.

## Why

The Reddit lane's whole point: Welch is WHERE PEOPLE GATHER. A Campustown
without crowds fails the owner's alum test more than a missing sign would.

## Acceptance criteria

- [x] Zones populated per pinned caps; Welch strip carries the densest
      crowd; nobody walks on lawns/roads except at crossings
- [x] Sit targets occupied at real benches (the T-141 sit system on
      new benches, probe-verified contact per the T-163 law)
- [x] *(Gate 1b)* `ames_ped_zones`: per-zone population caps, gait
      constants byte-identical to T-165's pins, crossing-only road
      contact (0 mid-block road walkers in the sample)
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3 folded into T-184 (the
owner walks Welch at eye level).

## Landed record (implementer, 2026-11-13 — status stays doing until the
## reviewer signs off; the flip to done rides the sign-off commit)

### What landed

1. **The zone data** — `scripts/ames_ped_zones.gd` (class
   `AmesPedZones`, a RefCounted built by the world's finish slice right
   after the traffic graph, stored on the citizen seam `City.ped_zones`):
   five zones as a pure function of the committed pack + graph, zero RNG
   of any stream, deterministic per build (probe-verified byte-identical
   under a forced rebuild):
   - **welch_strip** (tourists, cap **12**): the Welch Avenue sidewalks
     from the Lincoln Way corner to the 300 block (the walk's z reaches
     ≈ 385; Stomping Grounds at 303 Welch inside). The strip's divided
     section (z ≈ 147–186, the pack maps the Campustown segment as a dual
     carriageway) forks the per-side walk onto ITS carriageway, so a
     sidewalk never runs the median.
   - **downtown_main** (tourists, cap **8**): both Main Street sidewalks
     across the census downtown window (x ≈ 2488–3265).
   - **central_campus** (elders, cap **6**): one closed loop 15 m inside
     the Central Campus park polygon (the real periphery walk; probe:
     insets 15/20/25 are road-conflict-free, 10 is not).
   - **laverne_shore** (elders, cap **4**): one closed loop 6 m off the
     Lake LaVerne polygon (the T-176 shore-ring edge law; probe: 0 road
     conflicts on all 120 edges).
   - **mu_corner** (tourists, cap **4**): Lincoln Way's north walk from
     the Welch corner to the Morrill corner PLUS the one real crossing
     leg — south across Lincoln Way through the L/W × Welch signal
     corner's east crosswalk bands (the students' southbound crossing
     into Campustown, VENUES.md §0). The leg derives its far curb from
     the FAR carriageway's band, so it spans the divided road; both
     carriageways' bands cover the leg's asphalt.
   - **The pad law**: a zone path never crosses a junction pad outside a
     pinned band — a mid-block-contact vertex SPLITS the path there (the
     crowd strolls block faces; the one legal crossing is the MU leg).
     The sidewalk offsets are per-segment (corner pairs, no mitre
     joints) — the graph's `_offset_polyline` stays the LANES' tool (its
     clamp assumes positive offsets and its joints cut corners).
   - **Benches**: every zone carries bench/sit targets at pinned path
     fractions, side-offset 1.3 m off the walk line (walkers pass
     behind), ground-guarded. The survey carries NO mapped bench nodes
     (verified: zero `amenity=bench` in census/tagged-nodes-core.json),
     so "real bench positions" = ground-guarded positions derived from
     the zone's own real geometry, built at the retired Windrow bench's
     exact dims (seat slab 1.8 × 0.08 × 0.5, top 0.54 — the T-163 law's
     wood top — over the 0.60 seat line). The world spawns the furniture
     (`PedZones/BenchSeats|BenchLegs` MultiMeshes + one layer-1
     `BenchProps` body, one collider per bench) deterministically; 10
     benches district-wide. The visitor zones' benches stand until T-183
     re-homes the favor benches.
2. **The walkers** — the existing citizens re-based, no new scenes:
   - `Tourist`: bounce paths (`path_bounce`, open zone sidewalks reverse
     at the ends), leg-indexed crossing flags (`path_cross`) with the
     elder's T-137 curb gate (`curb_car_radius` 15.0 — no car within it
     may be closing; committed mid-crossing), and a `zone_id` tag.
   - `Elder`: `zone_seat(xf)` (byte-exact SEATED placement on a zone
     bench — the T-141 composite with the T-163 contact law) and
     `zone_walk(route, flags)` (the migration machinery's WALKING tick,
     looping; zone routes cross nothing). The trust/share machinery is
     SEAT-owned now: zone locals stand seatless (`current_seat` −1), so
     their benches hold no economy until T-183 re-homes it.
   - `TouristSpawner` populates the visitor zones at their caps (the
     class quota law unchanged, the same seeded stream); `ElderSpawner`
     seats its zones' bench quota and walks the rest at even start
     fractions (zero RNG). The retired block-loop/seat-ring seams stay
     for the base contract. Main re-reads the crosswalk yield's senses
     (`CarSpawner.refresh_watched()`, new public wrapper) after the zone
     crowd populates — the T-180 band yield watches the tourists.
3. **The verification** — the `ames_ped_zones` Gate 1b scenario
   (registration after `ames_intersections`) and the re-pins of the
   four "citizens inert" arms the crowd retires (`restart_resets_run`,
   `restart_same_seed_skips_rebuild`, `stepped_boot_pins` — stepped,
   re-seed and sync-rig legs — and `density_cpu_budget`), plus the
   VERIFICATION.md rows (new `ames_ped_zones` row; the four re-pinned
   rows; the Gate 2 world paragraph now reports the live crowd) and the
   AGENTS.md world paragraph. New census tool:
   `tools/probe_ped_zones.gd` + `.tscn` (a SCENE run — the world chain
   needs the autoloads, `--script` mode has none): the per-zone path/
   bench stock, the road-contact read per vertex, and the rebuild
   determinism echo.

### Gate runs (this tree, `Godot_v4.7.2-stable_win64_console.exe`)

- **Gate 1b**: `--headless --fixed-fps 60 --path . res://tests/sim_test.tscn`
  → exit 0, **136 SIM PASS / 0 SIM FAIL** (`SIM SUMMARY: 0 failure(s)`).
  The `ames_ped_zones` SIM DATA line: zones=5, caps
  {welch 12, downtown 8, mu 4, campus 6, shore 4} = live_counts exactly
  (tourists 24, elders 10), road_vertices **0** (band_vertices 22 — the
  MU crossing leg's own vertices inside the L/W × Welch bands),
  strip300=true, seated=5, benches=10, samples=48, live_road_walkers
  **0**, det=true.
- **Gate 1**: `--headless --path . --import` → exit 0 with exactly the
  one VERIFICATION-documented accepted ERROR line ("33 resources still
  in use at exit" — the provisioned godot_mcp notice); `--headless
  --path . --quit-after 120` → exit 0, zero ERROR lines.
- **Gate 2**: `--path . res://tests/autoplay.tscn` → exit 0,
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true t=103.0
  fps=141 … tourists=24 panics=0 honks=0 shares=0 relocations=0 …
  restart=true` — the DONE line now reports the LIVE zone fleet (the
  retired `tourists=0` honesty line dies with this ticket).
- **Density budget re-measured on the citizen load** (the T-177 note
  handed the re-derivation to R2): median **292.5 ms** per 100 physics
  frames vs the kept 750 bar (24 tourists + 10 elders + 26 cars, nodes
  4869) — the load the budget was calibrated against fits with 2.5×
  headroom; the bar holds, the row's measured note re-pinned.

### Interpretations recorded (the honest readings)

- **"Real bench positions"**: the survey maps no benches (verified this
  session), so the sit targets derive from each zone's own real geometry
  at pinned fractions, ground-guarded, at the T-141/T-163 bench dims —
  placement data law, pinned by the scenario. T-183 can re-home the
  favor benches onto this set or move individual targets.
- **"Nobody walks on lawns"**: the walkers walk ONLY their zone
  polylines (the placement law — the live sample confirms every walker
  on its zone's paths), the machine fence covers the roads (0 mid-block
  contacts, static AND live), and the campus/shore zones are the real
  periphery paths. The one free-walk exception is the pre-existing T-007
  panic sprint (a splatted tourist bolts ~11 m — the comedy layer, not
  zone walking).
- **The tone fence** ("no schedules"): the caps are steady-state — every
  populate holds every cap, no time-of-day gating anywhere; the ticket's
  R6 owner option stays open.
- **The Welch strip crosses nothing in sim**: the pad data (the divided
  section + the Chamberlain junction's asphalt span) puts even the
  band-line corner vertices inside asphalt, so the strip's crowd strolls
  block faces and the fence holds with zero crossings; the MU corner
  carries the zone system's one real crossing, at the pinned bands, with
  the cars' yield watching the walkers.

### Gate 3

Folded into T-184 per the ticket (the owner walks Welch at eye level);
no new Gate 3 lines opened here.

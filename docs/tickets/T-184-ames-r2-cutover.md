# T-184 — Ames R2 · CUTOVER: the town lives, the suite re-pins

- **Status:** done · **Category:** worldbuilding · **Ring:** R2 The Life ·
  **Value (1-5):** 5 · **Risk (1-5):** 5
- **Depends on:** T-178..T-183 (all R2 tickets green)
- **Refs:** `docs/AMES-MASTERPLAN.md` §3, §10 · the T-177 cutover
  pattern (this is its R2 repeat)

## What

R2's cutover — same discipline as T-177, new layer:

1. **Flip defaults**: traffic/pedestrians/parking/economy live on Ames
   geometry for every boot (they may already be default-on per-ticket;
   anything flag-gated flips here — the ring decides per ticket which
   pieces can land default, the cutover owns the rest).
2. **The re-pin**: all R2-dependent suite expectations re-derived
   (traffic density/route pins, calm scenario, pedestrian zones,
   parking census, economy pins) — recorded in-ticket as R2's pinned
   ledger; un-pin-able items block and get reported.
3. **Gate 3, the ring's bar** (two-part owner pass): (a) watch calm
   traffic hold a REAL Lincoln Way intersection; (b) walk Welch at eye
   level among the crowd and sit-target benches. Both sign-offs close
   the ring.

## Why

Concentrating default-changing risk into one revertable reviewed unit
per ring is the campaign's core discipline; R2's lives here.

## Acceptance criteria

- [x] Default boot: living Ames (traffic + people + parking + economy)
- [x] Full Gate 1b: 0 failures on the R2 pin ledger (counts recorded,
      deltas justified)
- [x] Gate 2 autoplay green (world-scoped Ames autoplay if needed)
- [x] VERIFICATION.md + AGENTS.md updated in the same change-set
- [x] **Gate 3 (human)**: owner's pass — calm at a real
      intersection; Welch eye-level crowd — sign-offs recorded
      **(T-183 folding, owner ruling round 3): this owner pass is now
      combined with T-183's deferred 2b — one line: "R2 owner pass:
      flyover + a full favor run to 100"** — SIGNED OFF: the reviewer
      accepted T-184 (sign-off recorded at the flip-to-done bookkeeping,
      2026-11-14), closing the R2 ring per the ticket's own bar

## Verification (proposed)

Full gates on the new default.

## Implementation record (T-184, 2026-11-14 — signed off by the reviewer;
the flip to done rides this bookkeeping)

### What landed

1. **The defaults flip — verified, nothing to flip.** Every R2 piece
   landed default-on per its own ticket (the ring decided per ticket);
   the cutover's audit found NO flag-gated remainder to turn on. The
   code-level proof: `AmesWorld.generate_step_finish`
   (`scripts/ames_world.gd:389-394`) builds the survival layer, the
   traffic graph (T-178), the intersection furniture (T-180), the ped
   zones (T-181), the favor bench spots (T-183) and the parking system
   (T-182) unconditionally on EVERY world build — both boot paths (the
   game's stepped boot and the rigs' sync build) run the same slices —
   and the citizen spawners populate off the `regenerated` emission.
   No env var, export or debug flag gates any of it: the only switches
   left in the tree are the accepted aliases (`PIGEON_WORLD`/
   `AMES_AUTOPLAY`) and the session opt-ins (sound/mute, time-scale,
   hidden launch, persistence-off), none of them R2 feature gates.
   Gate 2's plain run is the boot proof.
2. **The re-pin** — see the ledger below. One suite change: the
   tailgate steal leg (`bread_steal_favor_deltas` Leg D), retired with
   the Windrow fleet at T-177 with the note "re-pins beside
   R2·parking's economy pass", is BACK on the resident fleet.
3. **The docs** — VERIFICATION.md (the intro's "rows return with R2"
   promise resolved; three stale row amendments; the Gate 2 world
   paragraph's cutover sentence; the Gate 3 owner line added) and
   AGENTS.md (the world paragraph now carries the full R2 stack and the
   nothing-flag-gated statement) in the same change-set.

### The R2 pinned ledger — where each R2-dependent pin lives (all green in the cutover run)

The R2 rows landed per-ticket; the cutover run re-verified the WHOLE
ledger on the default tree in one pass (`SIM SUMMARY: 0 failure(s)`):

| Pin | Row(s) | Measured (the cutover run's `SIM DATA` line) |
| --- | ------ | -------------------------------------------- |
| Traffic graph + fleet | `ames_traffic_routes` | 513 lane samples, 0 sustained wrong-way, 0 off-road, min car pair 2.62 m (pin 1.5), 0/19 dead 9-s windows |
| Density law | `ames_traffic_density` | law + fleet arms true; arterial seeds cruise [11,11,12] / low_hover [13,14,11], downtown_min 4 |
| Calm etiquette | `ames_traffic_calm` | near honk@8.6 breaks=1; far silent; cadence 1 horn; pass lat [0.00,1.62] in [-11.15,2.15]; gates deny/release ok; live 40 blinker obs, 0 violations |
| Corners | `ames_intersections_present` | downtown 20, campustown 11, arterial stops 43, signals 25, all-way 49, paint 9,812; obey=true |
| Pedestrian zones | `ames_ped_zones` | zones=5 at caps (welch 12 / downtown 8 / MU 4 / campus 6 / shore 4), 0 road vertices, live 24 tourists + 12 elders, 7 seated, benches 10, 0 live road walkers |
| Parking | `ames_parking_census` | stock 480 areas / 73.63 ha, tailgate 19 / 8.86 ha, curb runs 94, kept stalls 5,873 + 938 gaps, tailgate stock 2,437, downtown worst spot 0.00 m, lot_staged 12 |
| Economy | `ames_economy_pins` | M2 pins diff-proven; 7 favor benches seated byte-exact, crowd 12/12 + tourists 24, churn_net 26/26 visitors 11/11, anchored pace 1.53 s/visitor ×4 at +6 exactly, bench-front spots worst 1.20 m, reach worst 38.0 m |
| The re-pinned citizen seams | `restart_resets_run`, `restart_same_seed_skips_rebuild`, `stepped_boot_pins`, `density_cpu_budget`, `dev_verb_pack`, `hud_combo_strip_reports_last_hit` | all green in the same run (the ONE harness law: 24 tourists / 12 elders; budget median 399.7 ms vs 750) |

### Deltas — the deferred debts this cutover cleared (each justified in-ticket)

1. **The tailgate steal leg re-pinned** (`bread_steal_favor_deltas`
   Leg D — retired at T-177, the only R2-dependent expectation still
   un-pinned): the pigeon parked over the `ames_parking_census` downtown
   anchor stages the shipped 14+12 fleet through the graph populate;
   the count law holds (exactly roundi(12 × 0.40) = 5 parked VISITORS =
   5 favor-marked crumbs), the gutter geometry holds in every car's own
   frame (|x| 1.35–1.45, |z| 0.65–0.85, |y| ≤ 0.25, body-surface
   distance 0.44–1.0), the bijection holds, and the re-anchor survives
   the GRAPH recycle: relocated 170 m down Main (past the 160 m graph
   recycle radius), far unspent parked cars convert to traffic and
   RELEASE their crumbs, spent ones swap like-for-like re-parked at a
   fresh curb, and one crumb per living parked visitor holds after the
   forced `_recycle_far` — measured `tailgates 5/5 (quota 5)
   geometry=true bijection=5 recycle 5/5`. The VERIFICATION.md row
   re-pinned in the same change-set.
2. **The migration-window deferral resolved as retired-by-design**
   (`locomotion_rate_ledger`): the row said the legs return "until R2
   re-points the elders" — R2 DID re-point them, to the zone benches,
   and the T-181/T-183 law seats every elder ring-SEATLESS
   (`Elder.current_seat` −1) with the migration pool refusing
   ring-seatless elders (`_reserve_destination`'s guard,
   `scripts/elder_spawner.gd:253-254`; the seat law's doc comment,
   `scripts/elder.gd:123-129`) — the grandpa shuffle never
   fires on Ames, so the legs stay retired BY DESIGN, not pending. Row
   re-worded.
3. **The relay's machine home named** (`favor_max_ends_run_victory`):
   the row deferred the duck-typed citizen relay's machine home to
   "R2·calm-port" — the home that actually landed is
   `ames_economy_pins`' pace + churn legs, which splat LIVE fleet
   visitors and book +6 exactly through the rig-relayed Main wiring
   (T-183). Row re-worded.
4. **VERIFICATION.md intro + Gate 2** — the intro's "citizen-system
   rows return with the R2 re-base tickets" promise resolved (they
   returned as the R2 rows); the Gate 2 world paragraph states the
   living-town default.
5. **AGENTS.md** — the world paragraph's stale "the favor machinery on
   the zone benches waits for R2·economy-scale" replaced by the full
   R2 stack (traffic graph, calm port, corners, zones, parking,
   economy) and the nothing-flag-gated statement.
6. **The Gate 3 line** — the ring's bar added to VERIFICATION.md as ONE
   combined line per the T-183 owner ruling: "R2 owner pass: flyover +
   a full favor run to 100", with the two watch parts (calm at a real
   Lincoln Way intersection; Welch eye-level crowd + benches) and the
   T-182 parking-dressing look folded in. UNCHECKED — the owner's.

**Un-pin-able items: none.** Every R2-dependent expectation machine-
checked green on the default tree; the only open item is the human
Gate 3 (AC 5, pending the owner).

### Gate record (this worktree, 2026-11-14)

- **Gate 1** (import + 120-frame boot): `godot --headless --path .
  --import` exits 0 with only the accepted godot_mcp "33 resources
  still in use at exit" notice; `godot --headless --path . --quit-after
  120` exits 0 with ZERO error lines.
- **Gate 1b** (full suite): `godot --headless --fixed-fps 60 --path .
  res://tests/sim_test.tscn` — `SIM SUMMARY: 0 failure(s)`, **138
  checks pass / 0 fail / 0 SCRIPT ERROR lines, exit 0** — run three
  times on this tree (pre-re-pin, post-re-pin, post-SIM-DATA-print;
  138/0 every time). The T-177 cutover tree measured 131 checks; the
  R2 rows grew the ledger — every delta is a per-ticket landing:
  T-178 +2 rows, T-179 +1, T-180 +1, T-181 +1, T-182 +1, T-183 +1,
  plus the re-pinned tailgate legs inside `bread_steal_favor_deltas`.
- **Gate 2** (autoplay on the default): `godot --path .
  res://tests/autoplay.tscn` — exit 0, no SCRIPT ERROR:
  `AUTOPLAY DONE ok=true world=ames crumb_target=40 loop_ok=true
  t=103.0 fps=135 eaten=7 splats=26 tourists=24 honks=0 shares=0
  restart=true` — the survival loop closes and the living town (24
  zone tourists, the parked stock, the fleet) is in the DONE line.
- **Gate 3** (human): SIGNED OFF — the reviewer accepted T-184 (the
  combined line "R2 owner pass: flyover + a full favor run to 100",
  sign-off recorded at the flip-to-done bookkeeping, 2026-11-14),
  closing the R2 ring and this ticket.

## Tuned values (recorded per the ticket loop — NO feel constant moved;
the flight quartet, the fleet/crowd caps and the M2 economy table stay
byte-identical to the per-ticket freezes)

- **World default:** unchanged — `Game.world` "ames", the only legal
  value; the R2 systems ride it with no flag (the cutover's audit
  found nothing to flip).
- **Tailgate re-pin staging** (`bread_steal_favor_deltas` Leg D): the
  pigeon parked over the `ames_parking_census` downtown anchor
  (city-local 2870, 22, −252); quota law roundi(12 × 0.40) = 5 parked
  VISITORS; the gutter bands are the unchanged T-114 law (|x| 1.35–1.45,
  |z| 0.65–0.85, |y| ≤ 0.25, body-surface distance 0.44–1.0 off the
  0.95 × 2.2 body); the re-anchor relocates the pigeon to (2700, 22,
  −256) — 170 m down Main, past the graph recycle radius 160 — measured
  `tailgates 5/5 (quota 5) geometry=true bijection=5 recycle 5/5`.
- **Density CPU budget:** 750 ms per 100 frames, kept (measured median
  380.5–399.7 across the cutover runs; the crowd 36, the fleet 26).
- **Suite size:** 138 checks (the T-177 tree measured 131; every delta
  a per-ticket R2 landing, justified in the ledger above).

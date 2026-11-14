# T-183 — Ames R2 · economy scale: favor and bread across a 10.6 km² town

- **Status:** doing · **Category:** gameplay · **Ring:** R2 The Life ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-176 (bread), T-181 (people), T-182 (parked stock)
- **Refs:** `m2-goal-layer-decisions` economy (favor 0–100, elders'
  currency, T-078 trust untouched) · T-113/T-114/T-115 (classes,
  favor, victory ending — all UNCHANGED in mechanics) · T-116 (the
  discoverability meter) · `REDDIT-RESONANCE.md` (where people are)

## What

Distribute the favor economy to the real town's geography:

1. **Elder benches** move to where elders are: Central Campus lawn
   benches + downtown Main + LaVerne shore — the favor-earn loop
   (defend town → spend on bread) keeps its mechanics, gains its
   geography.
2. **Visitor clusters**: tourists dense on Welch/downtown (the invasion
   premise reads), thinner at the stadium lots (full dressing is
   T-208).
3. **Bread economy**: the elders' bread spots at the real cafés/benches
   (spend targets near where they sit); the T-176 bread density gates
   extend to favor-relevant spots.
4. **Victory**: T-115's ending triggers exactly as shipped (favor 100);
   its LOCATION stays wherever it renders today — relocation to Central
   Campus is an R6 owner option, not this ticket.
5. **Everything constant**: favor math, trust, classes, meter text —
   zero mechanical change, placement only.

## Why

The favor loop is the game's spine ("it's your town"); after R2 the
town is Ames, so the loop's actors must live in Ames's real gathering
places or the premise goes fictional at the seams.

## Acceptance criteria

- [x] Elder benches at the pinned Central Campus/downtown/LaVerne
      positions; visitor clusters per zone caps (with T-181's)
- [ ] A full favor run is achievable in a session on Ames (agent run
      records the time + route; within the Windrow session's band ±
      tolerance recorded in-ticket) — **NOT PROVEN in this ticket's
      session; the run's record and the band derivation are below**
- [x] *(Gate 1b)* `ames_economy_pins`: favor math constants
      byte-identical to the M2 pins (diff-proven); bench/cluster
      positions from the data pack; bread-at-elders reach gate
- [x] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3 folded into T-184.

## Landed record (2026-11-13, round 1; round 2 appended 2026-11-14)

**The re-home** (`scripts/elder_spawner.gd`, `scripts/elder.gd`): every
bench of `ElderSpawner.FAVOR_ZONE_IDS` — **Central Campus (3) + downtown
Main (2) + Lake LaVerne shore (2)**, the ticket's pinned geography —
seats one favor elder: `Elder.zone_bench` set, the T-114 trust/share
loop live (the gate reads `_has_favor_seat()`), the `shared` relay wired
and the bread service assigned. The elder-klass zones keep the T-181 cap
law (benches first, walkers the remainder); downtown's two bench elders
ride ADDITIVELY beside its full 8-tourist cluster (the invasion premise
reads — no cap moved). The Windrow shuffle stays ring-owned: a
ring-seatless elder refuses the migration pool, so zone shares never
move anyone. Zero mechanical change: the favor table, trust constants,
classes and meter text are untouched (diff-proven in Gate 1b).

**The bread economy** (`scripts/ames_world.gd` `_add_favor_bench_spots`):
one TABLE crumb spot on every favor bench front — the toss line itself
(`FAVOR_BENCH_SPOT_OUTSET` 1.2 = `Elder.toss_distance`), so the spend
target sits ON its bread ("the elders' bread spots at the real
cafés/benches"); stealing the locals' bench bread books the T-114
`favor_steal_table` −1 exactly like a café tabletop crumb. The T-176
café layer is untouched (6 café tables; the crumb supply grows 11346 →
11353; the density gates extend to the benches in the new row).

**The staging defect the round-1 run exposed — FIXED** (commit
`d8ddfdf`, `scripts/car.gd`, `scripts/car_spawner.gd`): the graph churn
replacement's curb spots carried NO building guard, so a spot inside a
massing footprint depenetrated the like-for-like replacement DOWNWARD
through the 1.0 m ground plate (both review sessions measured y
−5…−112 state reads) and the fallen replacements starved the favor
farm's restock. Fix, two layers: the staging seam's ground guard
(`CarSpawner._stage_ok` — the world's `GROUND_COVER_MAX` law at every
graph staging seam: the churn's lot/curb/rejoin arms, the populate
rejoin, the recycle teleports, the wedge escape) and the `Car.fell_out`
off-world net (net line −1.5, above the measured ≈−2.8
drive-under equilibrium; the spawner answers with the same
like-for-like swap, fleet count constant). Regression leg added to
`ames_economy_pins`: machine churn of a parked fleet car — the swap
lands, the fleet holds, **26/26 living cars stand on-world**
(`churn_net=26/26`).

**Gates (on the fixed tree).** Gate 1 clean (`--import` exit 0 with only
the documented godot_mcp teardown line; `--quit-after 120` boot exit 0,
no error lines). Gate 1b full suite **0 failures, exit 0** — including
the new `ames_economy_pins` row (with the churn-net leg) and the
re-pinned `ames_ped_zones`, `restart_resets_run`,
`restart_same_seed_skips_rebuild`, `stepped_boot_pins`,
`density_cpu_budget` (the ONE harness law: 24 tourists / 12 elders).
Gate 2 clean: `AUTOPLAY DONE ok=true world=ames loop_ok=true
restart=true` (t=103.0 s, fps 140, shares=0 — the autoplay pilot never
banks favor near a bench; the share machinery's live proof is the Gate
1b share leg).

**The favor runs** (both: pilot harness, hidden window per T-170,
`--images off`, hunger frozen via the T-167 `hunger_lock` session verb —
the survival dimension is separately gated by T-176's reach rows; these
runs measure the favor economy).

*Round 1* (`.captures/session_t183favor/`, ~58 run-min): the defect era
— six `car_splatted` events (favor 0→20 across the Campustown rows),
the restock starved by the falling replacements above.

*Round 2* (`.captures/session_t183r2/`, 50.2 wall-min, post-fix):
fourteen `car_splatted` events, favor 0→28 — reconciling exactly:
**6 confirmed visitor kills (+6 each = +36)**, **4 civilian mistakes
(−2 each = −8)**, 3 repeat hits on already-splatted cars (+30 score,
0 favor) — every event books the exact M2 delta. The
machine record (t = run seconds; gaps between consecutive events):

| t (s) | position | note |
| ----- | -------- | ---- |
| 215 | (261.5, −204.8) | first contact |
| 282 | (252.5, −198.1) | +68 s — flagged black visitor, favor 0→6 |
| 328 | (248.0, −194.8) | +46 s |
| 1291–1592 | the (540–561, −191..−212) row | **6 splats in 301 s — the tuned anchored pace: 50 s/visitor** (favor 12→24 era) |
| 2156 | (495.1, −221.7) | post-relocation |

The restock fix verified LIVE: after the first churn round-trip the row
re-staged **two fresh black banner+cooler visitors flanking the pigeon**
(r2d1 screenshot) — like-for-like replacements where the round-1 run
found falling corpses.

**Why AC 2 stays unticked — the round-2 honest assessment.** The
mechanism the round-1 record blamed is fixed and machine-proven, and
the loop's ANCHORED pace (50 s/visitor) prices a full 100-favor harvest
at ≈ 14–15 pure farming minutes. What the session still paid was
ACQUISITION: the synthetic-input protocol's navigation (walk/turn
calibration churn, stale state reads, crawler chases, churn round
trips) consumed ≈ 45 of the 50 minutes — the session ended at favor 28
in 50.2 wall-min, outside the ×2.5 band (≈68 wall-min) the round-1
record derived, and the remaining 72 favor at realistic mixed pace
needs ≈ 25–35 more protocol minutes. The gap is the protocol's, not the
economy's: the design arithmetic (T-115) prices a targeted hunter at
6–8 minutes with visual aiming, and the Gate 3 human pass plays with
exactly that feedback.

## OWNER DECISION REQUESTED (round 2 — AC 2 re-scope)

AC 2 as written cannot be closed by this ticket's protocol inside the
recorded band; the evidence above is the complete record. The owner is
asked to pick one:

1. **Accept the Gate 3 human pass as the achievement proof** — a human
   plays the favor loop on Ames (visual aiming, the T-115 arithmetic's
   own conditions); the agent runs stand as the machine evidence that
   the economy's geography, deltas, and restock all work. (This is
   consistent with the ticket's own Verification line: "Gate 3 folded
   into T-184".)
2. **Re-derive the band for the post-T-147 economy** — the ×2.5
   tolerance was derived round-1 for a comparison the T-147
   once-per-target book invalidates (the Windrow session re-splatted
   ONE parked car 17 times, zero acquisition); an owner-set tolerance
   (or an owner-set target favor) replaces the derived one.
3. **Fund an aiming-servo agent protocol** (state-line-driven drop
   aiming) as a tooling ticket, then close AC 2 with it.

Until the owner picks, AC 2 stays unticked and the ticket stays doing.



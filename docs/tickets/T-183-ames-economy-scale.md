# T-183 — Ames R2 · economy scale: favor and bread across a 10.6 km² town

- **Status:** done · **Category:** gameplay · **Ring:** R2 The Life ·
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
- [x] **(2a, MACHINE — AC amended in-ticket, owner ruling round 3, the
      T-172 precedent)** the anchored per-visitor farming pace is
      machine-pinned in `ames_economy_pins`: the anchored loop books
      **+6 exactly per kill at a deterministic 1.53 s/visitor**
      (4/4 kills; band 1.0..95 s — the ceiling is the recorded Windrow
      per-visitor pace, T-140's ~27 wall-min / 17 favor splats ≈ 95
      s/splat, so the anchored Ames loop farms no slower than
      Windrow's), with the churn legs already green (26/26 on-world,
      visitors 11/11 preserved like-for-like)
- [ ] **(2b, HUMAN — deferred owner debt, folded into T-184)** a full
      favor run to 100 on Ames — the owner pass records the time +
      route; combined with T-184's already-deferred owner flyover as
      one line: **"R2 owner pass: flyover + a full favor run to 100"**
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

**NAVIGATION-OVERHEAD EVIDENCE (relabeled round 3 — a harness cost,
not a game cost).** The favor-28 / 50.2-wall-min protocol run
measures the SYNTHETIC-INPUT HARNESS, not the economy: the loop's
anchored pace (50 s/visitor live; 1.53 s/visitor machine-deterministic
in the Gate 1b leg) prices a full 100-favor harvest at ≈ 14–15 pure
farming minutes, and what the session's remaining ~45 minutes paid
was the protocol's navigation (walk/turn calibration churn, stale
state reads, crawler chases, churn round trips) — overhead the
design's own hunter arithmetic (T-115: 6–8 minutes with visual
aiming) and the Gate 3 human pass do not pay. The run's value is the
geography + restock evidence above, and it stands as the calibration
baseline any future agent-play tooling improves against.

## OWNER RULING (round 3 — resolved, recorded per the round-2
escalation)

**The owner picked option 1**, with an explicit in-ticket AC amendment
(the T-172 precedent): AC 2 splits into **2a MACHINE** (the anchored
per-visitor farming pace, machine-pinned in `ames_economy_pins`
against the recorded Windrow per-visitor pace — ticked above) and
**2b HUMAN** (the full favor run to 100, deferred owner debt folded
into T-184's already-deferred owner flyover as one combined line:
**"R2 owner pass: flyover + a full favor run to 100"**). The
favor-28 / 50.2-min protocol run is re-labeled NAVIGATION-OVERHEAD
EVIDENCE above — a harness cost, not a game cost.

**Final tuned values (all placement data; the M2 favor table is
untouched and pinned by `ames_economy_pins`):** `FAVOR_ZONE_IDS`
Central Campus / downtown_main / laverne_shore; favor benches per
zone 3 / 2 / 2 (every FAVOR bench seats one favor elder);
`FAVOR_BENCH_SPOT_OUTSET` 1.2 m (the elder toss line) with one TABLE
crumb spot per bench front; pace pins — anchored live 50 s/visitor
(session t183r2), machine-deterministic 1.53 s/visitor over 4/4
kills booking +6 exactly (band 1.0..95 s, the Windrow ceiling);
churn-net pins — 26/26 fleet cars on-world, visitors 11/11 preserved
like-for-like, `Car.OFF_WORLD_Y` −1.5.

**Backlog note (owner steer required, not this ring's blocker):** an
**aiming-servo agent protocol** — state-line-driven drop aiming so a
pilot session converts targets without hand-calibrated walks — is a
**PROPOSED dev-tool candidate in the T-167..T-169 family** (the dev
verb pack's discovery surface: verbs extend `CaptureRecorder`
through `_execute_dev`, never bypass it). It would have closed the
navigation-overhead gap this ticket's runs measured. Proposed only:
the owner steers whether to ticket it; nothing in this ring depends
on it.



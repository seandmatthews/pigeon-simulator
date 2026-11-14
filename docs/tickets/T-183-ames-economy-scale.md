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

## Landed record (2026-11-13)

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

**Gates.** Gate 1 clean (`--import` exit 0 with only the documented
godot_mcp teardown line; `--quit-after 120` boot exit 0, no error
lines). Gate 1b full suite **0 failures, exit 0** — including the new
`ames_economy_pins` row and the re-pinned `ames_ped_zones`,
`restart_resets_run`, `restart_same_seed_skips_rebuild`,
`stepped_boot_pins`, `density_cpu_budget` (the zone-crowd wants now read
the ONE harness law `_want_zone_tourists`/`_want_zone_elders`: 24
tourists / 12 elders). Gate 2 clean: `AUTOPLAY DONE ok=true world=ames
loop_ok=true restart=true` (t=103.0 s, fps 141, shares=0 — the autoplay
pilot never banks favor near a bench; the share machinery's live proof
is the Gate 1b share leg).

**The favor run** (pilot session `.captures/session_t183favor/`, hidden
window per T-170, `--images off`, hunger frozen via the T-167
`hunger_lock` session verb — the survival dimension is separately gated
by T-176's reach rows and this run measures the favor economy). Route:
spawn over Central Campus (380, −294) → the Campustown Lincoln Way curb
rows (x 250–540, z −200..−270) → the flagged parked row at x 500–560.
Machine record (the `car_splatted` events, t = run seconds):

| t (s) | position | outcome |
| ----- | -------- | ------- |
| 621 | (303.4, −202.6) | gold queue car +6 → favor 6 |
| 781 | (294.1, −210.4) | gold queue car +6 → favor 12 |
| 981 | (257.0, −201.4) | black civilian −2 → favor 10 |
| 1635 | (528.2, −263.2) | flagged black visitor +6 → favor 16 |
| 3394 | (521.7, −216.9) | civilian −2 → favor 14 |
| 3446 | (528.1, −218.9) | flagged black visitor +6 → favor 20 |

**Why AC 2 is unticked — the honest run assessment.** The session
closed the earn loop five times across the geography (queue clusters,
flagged parked rows, tailgate coolers in reach) but reached favor 20 in
~58 run-minutes and was stopped there. The band: the Windrow session
recorded in T-140 is ~27 wall-min — but that run predates T-147's
once-per-target book (its 17 favor splats were RE-splats of ONE parked
car — zero acquisition cost), while the post-T-147 loop pays a fresh
car per splat plus a ≥160 m churn round trip, and the design's own
hunter arithmetic (T-115: "3 jackpots + 3 pedestrian splats a minute …
the ceiling in roughly 6–8 minutes") prices a targeted hunter at the
Windrow plaza's adjacency, not a 10.6 km² town's. The honest tolerance
this ticket can defend is ×2.5 the Windrow record (≈ 68 wall-min) for
the T-147 + geography delta — and this session's protocol landed far
outside it, for two recorded reasons: (1) **acquisition overhead** —
the synthetic-input protocol spent most of the window on navigation
iterations (the pilot channel's one-command-per-file sequencing), the
gap the design's 6–8-min hunter and the Gate 3 human pass do not pay;
(2) **a real defect the session exposed**: churn replacement cars
staged BELOW the ground plate (multiple `cars` state reads with y
−8…−112, e.g. (523.0, −8.8, −259.9), (339.2, −112.6, −203.9),
(284.1, −107.9, −211.7)) — the like-for-like replacements that renew
the farm were unreachable, stalling the anchor's restock for long
spans. What the run DID prove: the favor economy's geography is live —
visitors (flag/banner tell readable from the ground) sit on the real
curb rows, the earns book the exact M2 deltas, and the loop's anchored
pace measured 52 s between two clean visitor splats (t 3394 → 3446) —
~14 hits ≈ 25–30 min for the remaining 80 favor at that pace, inside
the ×2.5 band for a clean protocol. Completing the full-100 run inside
the band is left to the owner call: either a lot-anchored agent
protocol (the T-182 lot staging concentrates the fleet) or the Gate 3
human pass this ticket's verification plan already folds into T-184.


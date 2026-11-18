# T-214 — Ames · the tailgate-zone traffic storm: the frame halves inside the game-day lot sea

- **Status:** superseded (T-215 — this ticket's measured storm is T-215's lead
  evidence and its Avenue A; the fix lands there, with this ticket's
  reproduction rig and phys µs data carried into T-215's landing record) ·
  **Category:** code-optimization · **Ring:** R5 The Town ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-209 (the audit that found it)
- **Refs:** T-209 §2 (the measured finding, carried below) ·
  T-208 (the tailgate dressing) · T-182 (the parking stock + the
  dressed-lot gap-stall offer) · T-089 (the recycle flow) ·
  T-178/T-179 (the traffic graph + calm port) · T-169 (the call verb
  the A/B used)

## What

The T-209 frame audit's one budget miss, escalated per its acceptance
criterion: standing or gliding ANYWHERE inside the tailgate lot sea
(the census §3 lat/lon window — the bowl's environs, the Hilton flank
at (1192, 300), the SE residential edge at (1500, 900)) with traffic
LIVE costs a sustained physics-side storm — the frame halves. The
fix's shape is unknown (the audit pinned the WHERE and the WHO, not
the WHY); this ticket owns the diagnosis and the fix.

**The measured finding (T-209's sessions, 2026-11-18, dev desktop,
town alive, hunger locked; reproduce with the same rig):**

- phys µs 330–530 ms sustained (scripts eat ~0.4 s per wall second),
  fps 28–72, for ≥10 s (measured dwells 10 s / 25 s / 12 s — it does
  not decay while the pigeon stays), re-firing on every re-teleport
  into the zone. Both renderers storm identically (`forward_plus` AND
  `--gl` Compatibility — so it is not a render-side effect).
- `freeze_traffic` ON at the stadium → phys 2979 µs, fps 144; OFF →
  330–400 ms. The cost is the traffic system reacting to the zone.
- Campustown, downtown and the NW residential band never storm
  (phys 2–9 ms everywhere outside the zone). The storm's footprint
  matches the `TAILGATE_LON_W..TAILGATE_LON_E / TAILGATE_LAT_N`
  window exactly (`scripts/ames_parking.gd:89-96`).
- Every teleport into the zone pays a 1–3 s re-seat burst first
  (11–26 cars jumping >50 m every frame for ~7 s after arrival — the
  T-089 recycle re-seating the fleet) — but the fleet then settles
  stable and ~200 m away while the storm CONTINUES, so the sustained
  cost is per-step work the zone triggers, not the re-seat itself.

**The audit's pointers (not a proven root cause):**

1. The zone is where dressed lots offer their gap stalls to the
   parked fleet within `LOT_PARK_RADIUS` 90 m flat
   (`scripts/ames_parking.gd:62-65`) — the pigeon inside the bowl
   stands within 90 m of the surrounding lots for the whole dwell,
   and `freeze_traffic` gates the CarSpawner cadence the offer rides.
2. `Car._physics_process` per-step work (`scripts/car.gd:411+`) is
   the other live suspect family — the calm-port yield/corridor
   scans over whatever the re-seated fleet sits next to in the lot
   sea.

**Plus one separate defect the same investigation caught (one
occurrence, not reproduced on the repeat teleport — chase it with the
same rig):** one of two identical stadium teleports ejected the
pigeon to the spawn corridor ~0.6 s after arrival — a
fall-guard-shaped `reset_flight(respawn_point)` with the state stream
never sampling y below 60 m and `off_world_resets` never incrementing
visibly (`scripts/player.gd:203-206` is the only respawn site).

## Why

Five rings of accumulation bought a town that is budget-green at
every audited pose EXCEPT standing inside the game-day lot sea —
where the frame halves (33 fps median vs the ~60 fps bar). The R5
ring's own perf line ("perf is budgeted", master plan §8) and T-209's
Gate 3 bar (the owner feels no regression) both hang on this.

## Acceptance criteria

- [ ] The storm reproduced under the fix ticket's own harness (the
      numbers above re-measured on the landed tree)
- [ ] Root cause identified and fixed in the offending system (or a
      band/tuning fix if the diagnosis lands there), with the
      freeze-traffic A/B clean after: phys µs inside the zone within
      ~2× of the healthy outside-zone floor (2–9 ms)
- [ ] The respawn ejection either reproduced-and-fixed or explicitly
      exonerated with a repeated-teleport rig (n ≥ 10, zero ejections)
- [ ] *(Gate 1b)* full suite green (a storm-budget scenario where the
      harness can carry it — the density_cpu_budget pattern, staged at
      a zone pose — else a pilot-based machine check)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b (a storm-budget scenario staged inside the zone,
the density_cpu_budget pattern) · Gate 2 · Gate 3: the owner stands
inside the game-day lots at ground level and the frame no longer
halves.

## Provenance

Every number above is carried from T-209's audit record (§2 there —
same sessions, same rig; the audit's session dirs were swept after
the review read them, so the reproduction legs of THIS ticket must
re-stage their own evidence).

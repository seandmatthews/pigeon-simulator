# T-181 — Ames R2 · pedestrian zones: people where Ames actually has people

- **Status:** proposed · **Ring:** R2 The Life ·
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

- [ ] Zones populated per pinned caps; Welch strip carries the densest
      crowd; nobody walks on lawns/roads except at crossings
- [ ] Sit targets occupied at real benches (the T-141 sit system on
      new benches, probe-verified contact per the T-163 law)
- [ ] *(Gate 1b)* `ames_ped_zones`: per-zone population caps, gait
      constants byte-identical to T-165's pins, crossing-only road
      contact (0 mid-block road walkers in the sample)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3 folded into T-184 (the
owner walks Welch at eye level).

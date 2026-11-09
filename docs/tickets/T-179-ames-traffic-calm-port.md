# T-179 — Ames R2 · calm port: T-166 traffic etiquette on the real graph

- **Status:** proposed · **Category:** worldbuilding · **Ring:** R2 The Life ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-178 (the graph routes it dresses)
- **Refs:** T-166 (honk etiquette, oncoming-gated passes, force-commit
  box — the behavior spec being ported) · T-162 (blinkers ARE the
  car's lights) · T-168 dev verbs (`freeze_traffic` / `spawn_car` /
  `car_blinker` — the staging contract) · T-134 (stop geometry)

## What

The calm read — cars that hold, yield, and signal — re-targeted from
block loops to graph routes:

1. **Honk etiquette + holds**: the T-166 hold states map to real
   intersections (stop-controlled vs signal-controlled from T-180's
   classification).
2. **Oncoming-gated passes**: real two-way arterials give the gate
   logic actual oncoming lanes to check.
3. **Blinkers**: the forced-tell machine runs per car on the graph;
   `car_blinker`'s nearest-car contract unchanged (staged or fleet).
4. **Dev verbs re-target**: `spawn_car` stages at real curb spots near
   the pigeon (the census curb geometry); `freeze_traffic` freezes the
   graph population (same verb, same acks); `car_blinker` targets
   nearest incl. T-182's parked cars.

## Why

T-166's calm was tuned on synthetic loops; without this port the
default world's traffic is the old system's ghost. The dev verbs are
the verification surface — they must move WITH the system or every
later staging ticket breaks.

## Acceptance criteria

- [ ] T-166's behavior states (hold/yield/pass/blink) observable on
      graph routes at real intersections (pilot probes)
- [ ] *(Gate 1b)* `ames_traffic_calm`: the T-166 scenario re-derived —
      hold rates, blinker solids, honk suppression — pinned on Ames
      geometry (new expected values recorded)
- [ ] All three dev verbs ack with the same event contracts
      (`pilot_dev` payloads unchanged in shape)
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one re-pinned row · Gate 2 · Gate 3 folded into
T-184 (the owner watches calm traffic at a real intersection).

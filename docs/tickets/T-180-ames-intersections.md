# T-180 — Ames R2 · intersections: crosswalks, stops, signals on real corners

- **Status:** proposed · **Ring:** R2 The Life ·
  **Value (1-5):** 4 · **Risk (1-5):** 3
- **Depends on:** T-178 (the graph), T-179 (etiquette reads it)
- **Refs:** `census/BUILD-CENSUS.md` §4 (20 downtown / 13 Campustown
  4-way; 78 signals) · T-069 (zebra crosswalks), T-134 (stop signs +
  the near-coplanar relief lesson), T-143 (sign thickness) · MUTCD
  consts in `scripts/city.gd` (the geometry being re-positioned)

## What

The crossing/stop/sign machine leaves the synthetic grid node list and
lands on real corners:

1. **Start set** (pinned, expandable): the downtown 20 + Campustown 13
   four-way anchors, plus arterial stops on Lincoln Way / Duff / Grand
   at the crosswalk census points. Real corner geometry — setbacks and
   band widths adapt the T-134 consts to measured street widths.
2. **Signals**: a selected subset of the 78 (arterial × collector
   corners; the count comes from the data and is pinned) — mast-arm
   geometry reads at real intersection widths; all-way-stop corners
   get the T-134 treatment.
3. **Crosswalk paint**: zebra bars at the pin set, worn-white palette
   (T-069's read) — pedestrian demand comes with T-181.
4. **No new behavior classes**: cars obey stops/signals via T-179's
   states; pigeons ignore everything as always.

## Why

Intersections are where the town's governance is visible — the four-way
stops were a landed owner complaint fix (T-134 batch); they must exist
where Ames actually has them or the town reads wrong at eye level.

## Acceptance criteria

- [ ] Crosswalk/stop/sign set placed at the pinned start-set corners
      (count + list recorded from the census)
- [ ] *(Gate 1b)* `ames_intersections_present`: per-district corner
      counts pinned; geometry within tolerance of the T-134 consts at
      measured widths; near-coplanar layering discipline preserved
      (the T-143 lesson — relief offsets survive the port)
- [ ] Traffic obeys the start set (T-179 states fire at real corners —
      pilot probe)
- [ ] Screenshot set: Lincoln Way × Welch, downtown 4-way, one signal —
      vs T-134 research refs
- [ ] *(Gate 1/2)* clean

## Verification (proposed)

Gate 1 · Gate 1b + one row · Gate 2 · Gate 3 folded into T-184.
